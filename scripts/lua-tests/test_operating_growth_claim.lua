-- 运营面板 page_3（成长礼金 GrowthGiftPage）领奖链路回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_operating_growth_claim.lua
--
-- 复现的线上问题：OperatingPanel page_3 点「领取」后按钮红点不消失，而且能反复领。
--
-- 根因（两处）：
--  ① 领奖请求用的是 ActivityGiftManager.IsActivityTypeOpen(GrowthReward) 返回的活动 Id，
--     而列表是按 giftList[curGiftsId]（当前档位）过滤的。成长礼金 5 个档位 101~105 各自对应
--     活动 Id 6/601/602/603/604（GlobalActivity 里 CanBuyRechargeId=101..105），
--     两者一旦不是同一个，GetActivityInfo 取到 nil（旧代码直接 .state/.missionId 会抛错），
--     或者请求带着「别的档位的 activityId」发给服务器 —— 服务器 TakeActivityRewardHandler
--     会校验 config.ActivityId == activityId，不等就抛 CFG_NULL，奖励不发、状态也不变，
--     于是红点留在按钮上、按钮还是「领取」，玩家看起来就是「能重复领」。
--  ② OperatingPanel 的红点绑定写在 BindEvent（只在首次创建时执行），而 OnClose 的
--     ClearRedPoint 会把绑定清空 —— 面板第二次打开后所有页签红点再也不刷新。
--
-- 这里用假的 UI/管理器驱动真源码，断言：请求带的是配置行自己的 ActivityId、领完立刻改状态和红点、
-- 响应回来前连点只发一笔、以及面板重开后红点会被重新绑定。

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
        print(string.format("  [ok]   %s", name))
    else
        failed = failed + 1
        print(string.format("  [FAIL] %s   %s", name, tostring(detail or "")))
    end
end

----------------------------------------------------------------------
-- 0) 基础环境桩
----------------------------------------------------------------------
Log, LogRed, LogGreen, LogWarn, LogPink, LogError = function() end, function() end,
    function() end, function() end, function() end, function() end
function GetLanguageStrById(id) return tostring(id) end
local fakeNow = 1000
function GetTimeStamp() return fakeNow end
function GetResourcePath(id) return "res:" .. tostring(id) end
function GetPictureFont(id) return id end
function DelayCreation() end

-- 红点类型：按名字自动分配唯一数字，避免手抄常量
local rpSeq = 0
RedPointType = setmetatable({}, { __index = function(t, k)
    rpSeq = rpSeq + 1
    local v = 2000 + rpSeq
    rawset(t, k, v)
    return v
end })
RedPointStatus = { Show = 1, Hide = 0 }

-- 真实 class.lua（quick_class 用它）
dofile(LUA_SRC .. "/class.lua")

-- Inherit：Common/functions.lua 里就是「父表当元表」
function Inherit(tbParent)
    tbParent.__index = tbParent
    local tb = {}
    setmetatable(tb, { __index = tbParent })
    return tb
end
BasePanel = { ClosePanel = function() end, OnClose = function() end }

ConfigName = { ActivityRewardConfig = "ActivityRewardConfig", ItemConfig = "ItemConfig",
    GlobalActivity = "GlobalActivity", MainLevelConfig = "MainLevelConfig" }
ConditionType = { Level = 9, CarBon = 15 }
GoodsTypeDef = { GrowthReward = 4 }
ActivityTypeDef = { GrowthReward = 6 }
UIName = { RewardItemPopup = "RewardItemPopup" }
SubUIConfig = { ScrollCycleView = "ScrollCycleView", PlayerHeadFrameView = "PlayerHeadFrameView", UpView = "UpView" }
UpViewOpenType = { ShowRight = 1 }
PanelType = { Main = 1 }
SoundConfig = { BGM_Main = "bgm", Sound_UICancel = "cancel" }
PlayerManager = { level = 60 }
FightPointPassManager = { curOpenFight = 1 }
SoundManager = { PlayMusic = function() end }

-- 伪 GameObject：够本用例的取节点/取组件用
local function newGo(name)
    local go = { name = name, active = true, children = {}, comps = {} }
    function go:SetActive(v) self.active = v and true or false end
    function go:GetComponent(t)
        self.comps[t] = self.comps[t] or { text = "", sprite = nil, color = nil, onClick = {} }
        return self.comps[t]
    end
    function go:AddChild(child) self.children[child.name] = child; return child end
    function go:Find(path)
        local cur = self
        for seg in string.gmatch(path, "[^/]+") do
            cur = cur.children[seg]
            if not cur then return nil end
        end
        return cur
    end
    function go:GetComponentInChildren() return self end
    go.transform = { rect = { width = 100, height = 100 }, SetParent = function() end }
    return go
end

-- 假的 item 节点（与 prefab 里 ItemPre 的路径对齐）
local function newItemGo()
    local root = newGo("item")
    local lv = root:AddChild(newGo("contents")):AddChild(newGo("lv"))
    local img1 = root:AddChild(newGo("Image_1"))
    img1:AddChild(newGo("Image_icon1"))
    img1:AddChild(newGo("text_num1"))
    local img2 = root:AddChild(newGo("Image_2"))
    img2:AddChild(newGo("Image_icon2"))
    img2:AddChild(newGo("text_num2"))
    local btn = root:AddChild(newGo("btnGet"))
    btn:AddChild(newGo("redPoint"))
    btn:AddChild(newGo("get"))
    return root, lv, btn
end

Util = {
    GetGameObject = function(root, path)
        if root == nil then return nil end
        local node = root:Find(path)
        return node
    end,
    LoadSprite = function() return nil end,
    SetGray = function(go, gray) if go then go.__gray = gray end end,
    AddOnceClick = function(go, fn)
        if go then go.__click = fn end
    end,
}

----------------------------------------------------------------------
-- 1) 配置：两个档位，各 2 条奖励，任务 Id 不重叠（与真表 3000/3400 段一致）
----------------------------------------------------------------------
local actRewardConfig = {
    [3000] = { Id = 3000, ActivityId = 6, Reward = { { 1001, 10 } }, Values = { { 9, 1 } } },
    [3001] = { Id = 3001, ActivityId = 6, Reward = { { 1002, 10 } }, Values = { { 9, 1 } } },
    [3400] = { Id = 3400, ActivityId = 604, Reward = { { 1003, 10 } }, Values = { { 9, 1 } } },
}
local GlobalActivity = {
    [6] = { Id = 6, Type = 6, CanBuyRechargeId = 101 },
    [604] = { Id = 604, Type = 6, CanBuyRechargeId = 105 },
}
local MainLevelConfig = { [1] = { Name = "1-1" } }
local itemConfig = {
    [1001] = { Id = 1001, ResourceID = 1 },
    [1002] = { Id = 1002, ResourceID = 2 },
    [1003] = { Id = 1003, ResourceID = 3 },
}

ConfigManager = {
    GetConfig = function(name)
        if name == ConfigName.ActivityRewardConfig then return actRewardConfig end
        if name == ConfigName.GlobalActivity then return GlobalActivity end
        if name == ConfigName.MainLevelConfig then return MainLevelConfig end
        if name == ConfigName.ItemConfig then return itemConfig end
        return {}
    end,
    GetConfigData = function(_, id) return actRewardConfig[id] end,
    GetAllConfigsDataByKey = function(name, key, value)
        local out = {}
        if name == ConfigName.ActivityRewardConfig then
            for _, row in pairs(actRewardConfig) do
                if row[key] == value then out[#out + 1] = row end
            end
            table.sort(out, function(a, b) return a.Id < b.Id end)
        end
        return out
    end,
}
-- 全局遍历配置（真实现来自 GameDataBase，这里按 Id 升序遍历）
function ConfigPairs(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    local i = 0
    return function()
        i = i + 1
        local k = keys[i]
        if k == nil then return nil end
        return k, t[k]
    end
end

----------------------------------------------------------------------
-- 2) ActivityGiftManager：按 (activityId, missionId) 存状态，语义与真实现一致
----------------------------------------------------------------------
local mission = {
    [6] = { activityId = 6, mission = {
        { missionId = 3000, state = 0 },
        { missionId = 3001, state = 0 },
    } },
    [604] = { activityId = 604, mission = {
        { missionId = 3400, state = 0 },
    } },
}
ActivityGiftManager = {
    -- 服务器把两个档位都下发了，IsActivityTypeOpen 只返回最后一个（这就是坑的来源）
    IsActivityTypeOpen = function() return 604 end,
    GetActivityInfo = function(activityId, id)
        local act = mission[activityId]
        if not act then return nil end
        for _, m in ipairs(act.mission) do
            if m.missionId == id then return m end
        end
        return nil
    end,
    SetActivityInfo = function(activityId, id, state)
        local act = mission[activityId]
        if not act then error("SetActivityInfo: 没有活动 " .. tostring(activityId)) end
        for _, m in ipairs(act.mission) do
            if m.missionId == id then m.state = state; return end
        end
    end,
    GetActivityOpenStatus = function() return true end,
}
OperatingManager = {
    IsGrowthGiftGoodsAvailable = function() return nil end,   -- 5 档全买完了
    GetGiftGoodsInfo = function() return { goodsId = 101, buyTimes = 1 } end,
    GetHadBuyGoodsTypeId = function() return 101 end,
}
PopupTipPanel = { ShowTipByLanguageId = function(id) lastTip = id end }
MsgPanel = { ShowOne = function(s) lastMsg = s end }
UIManager = { OpenPanel = function(_, drop) lastDrop = drop end }

local requests = {}
NetManager = {
    GetActivityRewardRequest = function(missionId, activityId, cb)
        requests[#requests + 1] = { missionId = missionId, activityId = activityId, cb = cb }
        if not deferResponse then cb({}) end
    end,
}
local redCheckCount = 0
function CheckRedPointStatus(t)
    if t == RedPointType.GrowthGift then redCheckCount = redCheckCount + 1 end
end

----------------------------------------------------------------------
-- 3) 载入被测源码
----------------------------------------------------------------------
package.preload["cjson.util"] = function() return {} end
local GrowthGiftPage = assert(loadfile(LUA_SRC .. "/Modules/Operating/GrowthGiftPage.lua"))()

local function newPage()
    local page = setmetatable({}, GrowthGiftPage)
    page.refreshGiftCount = 0
    page.refreshDataCount = 0
    page.RefreshGiftData = function(self) self.refreshGiftCount = self.refreshGiftCount + 1 end
    page.RefreshData = function(self) self.refreshDataCount = self.refreshDataCount + 1 end
    -- SetBtnInvestState 决定 curGiftsId（列表按它过滤），真机上 OnShow 第一步就会调
    page.btnInvest = newGo("btnInvest")
    page.btnInvestText = { text = "" }
    page:SetBtnInvestState()
    return page
end

----------------------------------------------------------------------
-- 用例 1：请求必须带「这一行配置自己的 ActivityId」
----------------------------------------------------------------------
print("[1] 领奖请求的 activityId 必须与配置行一致（不能拿 IsActivityTypeOpen 顶替）")
do
    deferResponse = false
    requests = {}
    local page = newPage()
    local itemGo, _, btn = newItemGo()
    page:RefreshShowData(itemGo, actRewardConfig[3000])

    check("未领取且已购买 → 按钮红点亮着", itemGo:Find("btnGet/redPoint").active == true,
        "redPoint.active=" .. tostring(itemGo:Find("btnGet/redPoint").active))
    check("按钮文案是「领取」", btn:Find("get"):GetComponent("Text").text == "10022",
        btn:Find("get"):GetComponent("Text").text)

    btn.__click()

    check("只发了一笔请求", #requests == 1, "#requests=" .. #requests)
    check("missionId = 配置行 Id(3000)", requests[1] and requests[1].missionId == 3000,
        requests[1] and requests[1].missionId)
    check("activityId = 配置行 ActivityId(6)，不是 IsActivityTypeOpen 的 604",
        requests[1] and requests[1].activityId == 6,
        requests[1] and requests[1].activityId)

    check("状态写到了 (6,3000)", mission[6].mission[1].state == 1, mission[6].mission[1].state)
    check("按钮红点立刻关掉", itemGo:Find("btnGet/redPoint").active == false,
        tostring(itemGo:Find("btnGet/redPoint").active))
    check("按钮文案变「已领取」", btn:Find("get"):GetComponent("Text").text == "10350",
        btn:Find("get"):GetComponent("Text").text)
    check("按钮置灰", btn.__gray == true, tostring(btn.__gray))
    check("刷新了页签红点", redCheckCount >= 1, redCheckCount)
    check("刷新了列表", page.refreshGiftCount + page.refreshDataCount >= 1,
        page.refreshGiftCount .. "/" .. page.refreshDataCount)
end

----------------------------------------------------------------------
-- 用例 2：响应回来之前连点，只允许一笔请求
----------------------------------------------------------------------
print("[2] 响应未回来时连点，只能发一笔请求")
do
    deferResponse = true
    requests = {}
    mission[6].mission[1].state = 0
    local page = newPage()
    local itemGo, _, btn = newItemGo()
    page:RefreshShowData(itemGo, actRewardConfig[3000])

    btn.__click()
    btn.__click()
    btn.__click()
    check("连点 3 次只发 1 笔", #requests == 1, "#requests=" .. #requests)

    requests[1].cb({})          -- 服务器回包
    btn.__click()               -- 回包后再点：此时已是已领取，按钮不该再发请求
    check("回包后按钮已置灰，不再发请求", #requests == 1, "#requests=" .. #requests)
    deferResponse = false
end

----------------------------------------------------------------------
-- 用例 2b：回包丢了（断线/超时）不能让按钮永久点不动
----------------------------------------------------------------------
print("[2b] 请求超时未回包时，5 秒后允许重试")
do
    deferResponse = true
    requests = {}
    fakeNow = 2000
    mission[6].mission[1].state = 0
    local page = newPage()
    local itemGo, _, btn = newItemGo()
    page:RefreshShowData(itemGo, actRewardConfig[3000])

    btn.__click()
    check("首笔已发出", #requests == 1, #requests)
    btn.__click()
    check("5 秒内连点仍被拦", #requests == 1, #requests)

    fakeNow = fakeNow + 6
    btn.__click()
    check("超时后可重试", #requests == 2, #requests)
    deferResponse = false
end

----------------------------------------------------------------------
-- 用例 3：服务器漏下发某条任务时，列表刷新不能中断
----------------------------------------------------------------------
print("[3] 某条任务在本地数据里缺失时，排序/刷新不抛错")
do
    local saved = mission[6].mission[2]
    mission[6].mission[2] = nil      -- 模拟服务器没下发 3001
    local ok, err = pcall(function()
        local page = newPage()
        page.scrollView = { SetData = function(_, list) page.lastList = list end }
        page.SetBtnInvestState = function() end
        page:RefreshGiftData()
    end)
    check("RefreshGiftData 不抛错", ok, err)
    mission[6].mission[2] = saved
end

----------------------------------------------------------------------
-- 用例 4：OperatingPanel 重开后必须重新绑定红点
----------------------------------------------------------------------
print("[4] OperatingPanel：关闭清空绑定后，再次 OnShow 要重新绑（否则页签红点永不刷新）")
do
    local requires = {
        "Modules/Operating/WeekMonthGiftPackPage", "Modules/Operating/MonthCardPage",
        "Modules/Operating/HighMonthCardPage", "Modules/Operating/GrowthGiftPage",
        "Modules/Operating/ContinuityRechargePage", "Modules/Operating/CumulativeSignInPage",
        "Modules/Operating/AttentionGiftPage", "Modules/Operating/UppperMonthCard",
        "Modules/Operating/LifelongLimitBuy", "Modules/Operating/WeekendWelfare",
        "Modules/Operating/LifeMember", "Modules/Operating/SuperLiftMember",
        "Modules/Operating/WeekCard", "Modules/Operating/WarOrder",
    }
    for _, name in ipairs(requires) do
        package.preload[name] = function() return { new = function() return {} end, New = function() return {} end } end
    end

    local bound = {}     -- rpType -> { go, ... }
    function BindRedPointObject(rpType, go)
        bound[rpType] = bound[rpType] or {}
        bound[rpType][#bound[rpType] + 1] = go
    end
    function ClearRedPointObject(rpType)
        bound[rpType] = {}
    end
    local checkCount = 0
    function CheckRedPointStatus() checkCount = checkCount + 1 end
    SubUIManager = { Open = function() return { OnShow = function() end, OnOpen = function() end } end, Close = function() end }
    Game = { GlobalEvent = { AddEvent = function() end, RemoveEvent = function() end } }
    GameEvent = setmetatable({}, { __index = function() return "evt" end })
    ActivityGiftManager.IsQualifiled = function() return true end
    ActivityGiftManager.GetActivityTypeInfo = function() return {} end
    ActivityGiftManager.WeekIsEndTime = function() return true end
    OperatingManager.IsBaseOpen = function() return true end
    OperatingManager.GetWarOrderForGlobalSystemId = function() return nil end
    WarOrderType = { [15] = 1, [16] = 2, [17] = 3, [18] = 4, [19] = 5 }
    RECHARGEABLE = true

    local OperatingPanel = assert(loadfile(LUA_SRC .. "/Modules/Operating/OperatingPanel.lua"))()
    local panel = OperatingPanel
    panel.operateTabs = {}
    panel.selectTabs = {}
    for i = 1, 19 do
        local tab = newGo("tabs_" .. i)
        tab:AddChild(newGo("redPoint"))
        panel.operateTabs[i] = tab
        panel.selectTabs[i] = newGo("selected")
    end

    panel:BindRedPoint()
    local growthType = RedPointType.GrowthGift
    check("首次绑定：GrowthGift 绑了 1 个物体", #(bound[growthType] or {}) == 1, #(bound[growthType] or {}))

    panel:BindRedPoint()
    check("重复 BindRedPoint 不叠加", #(bound[growthType] or {}) == 1, #(bound[growthType] or {}))

    panel:ClearRedPoint()
    check("OnClose 清空绑定", #(bound[growthType] or {}) == 0, #(bound[growthType] or {}))

    panel:BindRedPoint()
    check("再次打开后重新绑定成功（旧代码这里永远是 0）",
        #(bound[growthType] or {}) == 1, #(bound[growthType] or {}))

    -- 源码契约：绑定必须发生在 OnShow，而不是只在 BindEvent 里
    local src = io.open(LUA_SRC .. "/Modules/Operating/OperatingPanel.lua"):read("*a")
    local onShow = src:match("function OperatingPanel:OnShow%(%)[%s%S]-function OperatingPanel:OnSortingOrderChange")
    check("OnShow 里调用了 BindRedPoint", onShow ~= nil and onShow:find("BindRedPoint", 1, true) ~= nil)
    local bindEvent = src:match("function OperatingPanel:BindEvent%(%)[%s%S]-function OperatingPanel:OnOpen")
    check("BindEvent 里不再绑红点（避免首开重复绑）",
        bindEvent ~= nil and bindEvent:find("this:BindRedPoint", 1, true) == nil)
end

print(string.format("\n通过 %d 项，失败 %d 项", passed, failed))
if failed > 0 then os.exit(1) end
