-- 离线验证 OpenSeverWelfarePanel（开服福利）的列表入场动画（不依赖 Unity，直接 luajit 跑）：
-- 形态 = 「单 ScrollCycleView（1 列）+ OnShow 同步 SetData」，走 ItemPopIn A 方案 +
-- 一次性标记（docs/ui_item_pop_in_skill.md 3.2 节）。本面板首开原本走 DelayCreation
-- （skill 坑 #8：先把 item 全部 SetActive(false) 再每 10ms 开一个 ⇒ 动画一格都收不到），
-- 本次删掉它，逐格放大缩小本身就是逐行冒出来。覆盖：
--   ① 接线           require 唯一实现 / popIn 只建一处 / OnShow 置位 → SetData 后消费
--                    / OnClose + OnDestroy 都 Stop / 不再调 DelayCreation（坑 #8）
--   ② 首轮播一次     打开面板 → 逐格 0.82 起跳、错开 0.055、顺序 = 版面顺序（单列）
--   ③ 消费一次       领奖回调直接调 OnShowPanelData 的刷新不重播（「数据回来了」不播）
--   ④ 重新打开       再走 OnShow → 再播（玩家主动换屏）
--   ⑤ 多行压 span    行数多时末行延迟仍压进 maxSpan 0.55
--   ⑥ 空活动         activityData 为 nil 不炸、标记照常消费（不会在下次刷新时突然补弹）
--   ⑦ 生命周期       OnClose / OnDestroy 必须回收（Kill + 复位到 1）
--   ⑧ 峰值几何       prefab 实测 rewardPre 1060 / 视口（rect 拉伸）1080 ⇒ 缺省 peak 1.02
--                    卡面每侧出视口 0.6px（与 ValuePackPanel 同口径，屏边裁掉不可见）
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_openseverwelfare_listpopin.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/ActivityGift/OpenSeverWelfarePanel.lua"
local PREFAB = ROOT .. "Assets/ManagedResources/Prefabs/UI/ActivityGift/OpenSeverWelfarePanel.prefab"
local POPIN = ROOT .. "Assets/ManagedResources/~Lua/Modules/Common/ItemPopIn.lua"

local failed = 0
local function Check(cond, msg)
    if cond then
        print("  ✅ " .. msg)
    else
        failed = failed + 1
        print("  ❌ " .. msg)
    end
end
local function Near(a, b)
    return math.abs(a - b) < 1e-6
end

-- ---------------- stubs ----------------
local v3mt = {}
v3mt.__index = v3mt
v3mt.__mul = function(a, b)
    if type(a) == "number" then a, b = b, a end
    return setmetatable({ x = a.x * b, y = a.y * b, z = a.z * b }, v3mt)
end
local function v3(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, v3mt)
end
Vector3 = { one = v3(1, 1, 1), zero = v3(0, 0, 0), New = v3 }
Vector2 = { zero = { x = 0, y = 0 }, New = function(x, y) return { x = x, y = y } end }
Ease = { Linear = "Linear", InOutQuad = "InOutQuad", OutQuad = "OutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
Log = function() end
BasePanel = {}
function Inherit(base) return setmetatable({}, { __index = base }) end

local popInModule
function require(path)
    if path == "Modules/Common/ItemPopIn" then
        if not popInModule then popInModule = assert(loadfile(POPIN))() end
        return popInModule
    end
    return {}
end

-- DelayCreation 一旦被调就记下来（坑 #8：本面板必须删掉这个调用）
local delayCreationCalls = 0
DelayCreation = function() delayCreationCalls = delayCreationCalls + 1 end

-- 配置表 / 管理器桩
local activityRewardConfig = {}
ConfigName = { ActivityRewardConfig = "ActivityRewardConfig" }
ConfigManager = { GetConfig = function(_, name) return activityRewardConfig end }
ActivityTypeDef = { OpenSeverWelfare = 1 }
local activityTypeInfo = nil
ActivityGiftManager = {
    GetActivityTypeInfo = function() return activityTypeInfo end,
    OpenSeverWelfareRewardTabsSort = function() end,
}
FightPointPassManager = { IsFightPointPass = function() return true end }
GetTimeStamp = function() return 1000 end
GetLanguageStrById = function(id) return "L" .. id end
GetLeftTimeStrByDeltaTime2 = function(t) return tostring(t) .. "s" end
Timer = {
    New = function(...)
        return { Stop = function() end, Start = function() end }
    end,
}
-- 点击/网络/UI 桩：离线只走到「接线」层，回调内容不触发
Util = {
    GetGameObject = function(root, path)
        return root and root._probe or { SetActive = function() end, GetComponent = function() return { text = "" } end }
    end,
    AddClick = function() end,
    AddOnceClick = function() end,
}
SubUIConfig = { ItemView = "ItemView", ScrollCycleView = "ScrollCycleView" }
SubUIManager = {
    Open = function()
        return { gameObject = { SetActive = function() end }, OnOpen = function() end }
    end,
}
UIManager = { OpenPanel = function() return { gameObject = { SetActive = function() end } } end }
NetManager = { GetActivityRewardRequest = function() end }
JumpManager = { GoJump = function() end }
PopupTipPanel = { ShowTipByLanguageId = function() end }
Game = { GlobalEvent = { DispatchEvent = function() end } }

local tweens = {}
local function newTween(tf, endv, dur)
    local t = { tf = tf, endv = endv, dur = dur, delay = 0, ease = nil, onComplete = nil, killed = false }
    function t:SetDelay(d) self.delay = d; return self end
    function t:SetEase(e) self.ease = e; return self end
    function t:OnComplete(cb) self.onComplete = cb; return self end
    function t:Kill() self.killed = true end
    function t:Complete()
        if self.killed then return end
        self.tf.localScale = self.endv
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

-- 奖励行根节点（rewardPre 克隆）：prefab 实测无 Animator ⇒ 可以安全缩放
local function newRow(name)
    local o = { name = name, activeSelf = true, localScale = v3(1, 1, 1) }
    o.gameObject = o
    o.transform = o
    o._probe = { SetActive = function() end, GetComponent = function() return { text = "" } end }
    function o:DOScale(v, dur) return newTween(self, v, dur) end
    function o:SetActive(v) self.activeSelf = v and true or false end
    function o:GetComponent() return { text = "" } end
    return o
end

-- 复刻 ScrollCycleView:SetData（同步克隆 item）+ ForeachItemGO
local function newScrollView()
    local sv = { goItemList = {}, dataCount = 0 }
    function sv:ForeachItemGO(func)
        if not func then return end
        for i = 1, math.min(#self.goItemList, self.dataCount) do
            func(i, self.goItemList[i])
        end
    end
    function sv:SetData(datas, cb)
        self.goItemList = {}
        self.dataCount = #datas
        for i = 1, #datas do
            self.goItemList[i] = newRow("row" .. i)
            if cb then cb(i, self.goItemList[i]) end
        end
    end
    function sv:SetIndex(i) self.index = i end
    return sv
end

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- 配置行：Values[1][1] = 关卡门槛（离线一律判 pass），Reward 给两条
local function addConfig(missionId)
    activityRewardConfig[missionId] = {
        ContentsShow = 100 + missionId,
        Reward = { { 3, 100 }, { 14, 50 } },
        Values = { { 1 } },
        Jump = { 1 },
    }
end

local function missions(n)
    local datas = {}
    for i = 1, n do
        addConfig(i)
        datas[i] = { missionId = i, state = 0 }
    end
    return datas
end

local function liveTweensCount() return liveTweens() end

-- ---------------- load 真面板源码 ----------------
local srcLines = {}
for line in io.lines(SRC) do srcLines[#srcLines + 1] = line end
local text = table.concat(srcLines, "\n")
local function countLines(pat)
    local n = 0
    for _, l in ipairs(srcLines) do if l:match(pat) then n = n + 1 end end
    return n
end

local Panel = assert(loadfile(SRC))()
Panel.ScrollView = newScrollView()
Panel.popIn = require("Modules/Common/ItemPopIn").New(function() return Panel.ScrollView end)
Panel.NoviceItemList = {}   -- InitComponent 在离线不跑（要 Unity），这里补上它建的字典
Panel.titleText = { text = "" }
Panel.timeTextGo = { SetActive = function() end }
Panel.timeText = { text = "" }

-- ---------------- case1: 接线扫描 ----------------
print("== case1 接线 ==")
Check(text:find("local ItemPopIn = require%(\"Modules/Common/ItemPopIn\"%)") ~= nil,
    "应 require 唯一实现（不复制配方）")
Check(countLines("^%s*this%.popIn = ItemPopIn%.New") == 1, "popIn 创建应只有 1 处（InitComponent）")
Check(countLines("^%s*this%.listPopPending = true") == 1,
    "listPopPending 置位应只有 1 处（OnShow）")
Check(countLines("^%s*this%.popIn:Stop%(%)") == 2,
    "popIn:Stop 应有 2 处（OnClose + OnDestroy），实际 " .. countLines("^%s*this%.popIn:Stop%(%)"))
Check(text:find("function this%.TryPlayListPopIn") ~= nil, "TryPlayListPopIn 应有定义")
Check(text:find("DelayCreation%(") == nil, "本面板不再调 DelayCreation（坑 #8：它把 item 全藏起来，动画一格都收不到）")
Check(text:find("isFirstOn", 1, true) == nil, "isFirstOn 标记已随 DelayCreation 一并移除")
-- OnShowPanelData 里 TryPlayListPopIn 必须排在 SetData 之后（SetData 之后才认得到 item）
local dataBody = text:match("function this%.OnShowPanelData%(%)%s*\n(.-)\nend")
local posSetData = dataBody and dataBody:find("SetData", 1, true)
local posTry = dataBody and dataBody:find("TryPlayListPopIn", 1, true)
Check(posSetData ~= nil and posTry ~= nil and posTry > posSetData,
    "OnShowPanelData 里 TryPlayListPopIn 必须在 SetData 之后")
Check(delayCreationCalls == 0, "整轮跑下来 DelayCreation 不应被调")

-- ---------------- case2: 首轮播一次 ----------------
print("== case2 首轮播一次 ==")
tweens = {}
activityTypeInfo = { endTime = 2000, mission = missions(5), activityId = 1 }
Panel:OnShow()   -- 置位 → OnShowPanelData → SetData（同步克隆）→ TryPlayListPopIn
Check(Panel.listPopPending == false, "首轮应消费掉一次性标记")
Check(#tweens == 5, "应创建 5 条放大 tween，实际 " .. #tweens)
Check(liveTweens() == 5, "5 条都应在跑，实际 " .. liveTweens())
for i, t in ipairs(tweens) do
    Check(t.tf == Panel.ScrollView.goItemList[i], ("第 %d 条应绑定第 %d 行（顺序=版面顺序，单列）"):format(i, i))
    Check(Near(t.delay, (i - 1) * 0.055), ("第 %d 行延迟应为 %.3f，实际 %.3f"):format(i, (i - 1) * 0.055, t.delay))
    Check(Near(Panel.ScrollView.goItemList[i].localScale.x, 0.82),
          ("第 %d 行起始缩放应为 0.82，实际 %s"):format(i, Panel.ScrollView.goItemList[i].localScale.x))
end

-- ---------------- case3: 消费一次（领奖刷新不重播） ----------------
print("== case3 领奖刷新不重播 ==")
for _, t in ipairs(tweens) do t:Complete() end
Check(Near(Panel.ScrollView.goItemList[1].localScale.x, 1), "播完第 1 行应落回 1")
tweens = {}
activityTypeInfo = { endTime = 2000, mission = missions(20), activityId = 1 }
Panel.OnShowPanelData()   -- 领奖回调直接调这条刷新，不经 OnShow
Check(#tweens == 0, "领奖回调刷新不应重播，实际 " .. #tweens)
for i = 1, 5 do
    Check(Near(Panel.ScrollView.goItemList[i].localScale.x, 1), ("刷新后第 %d 行应保持基准 1"):format(i))
end

-- ---------------- case4: 重新打开会再播 ----------------
print("== case4 重新打开 ==")
tweens = {}
activityTypeInfo = { endTime = 2000, mission = missions(8), activityId = 1 }
Panel:OnShow()
Check(#tweens == 8, "重新打开应再播 8 条，实际 " .. #tweens)
local last = tweens[#tweens]
print(("  8 行：首行 0 / 末行 %.3f / 含单张总时长 %.3f"):format(last.delay, last.delay + last.dur + 0.12))

-- ---------------- case5: 多行压进 maxSpan ----------------
print("== case5 多行压 span ==")
tweens = {}
activityTypeInfo = { endTime = 2000, mission = missions(30), activityId = 1 }
Panel:OnShow()
local tail = tweens[#tweens]
Check(tail.delay <= 0.55 + 1e-6, ("30 行末行延迟应压进 maxSpan 0.55，实际 %.3f"):format(tail.delay))
for _, t in ipairs(tweens) do t:Complete() end

-- ---------------- case6: 空活动 ----------------
print("== case6 空活动 ==")
tweens = {}
Panel.ScrollView:SetData({}, nil)   -- 清掉上一轮的行
activityTypeInfo = nil
Panel:OnShow()
Check(#tweens == 0, "空活动不应建 tween")
Check(Panel.listPopPending == false, "空活动也把标记消费掉（不会在下次刷新时突然补弹）")

-- ---------------- case7: 生命周期回收 ----------------
print("== case7 生命周期 ==")
tweens = {}
activityTypeInfo = { endTime = 2000, mission = missions(5), activityId = 1 }
Panel:OnShow()
Check(liveTweens() > 0, "Stop 前应有存活 tween")
Panel:OnClose()
Check(liveTweens() == 0, "OnClose 后不应有存活 tween，实际 " .. liveTweens())
Check(Panel.listPopPending == false, "OnClose 后标记应清掉")
for i = 1, 5 do
    Check(Near(Panel.ScrollView.goItemList[i].localScale.x, 1),
          ("OnClose 后第 %d 行必须复位到 1，否则永久停在半截"):format(i))
end

tweens = {}
Panel:OnShow()
Check(liveTweens() > 0, "重开后应有存活 tween")
Panel:OnDestroy()
Check(liveTweens() == 0, "OnDestroy 后不应有存活 tween，实际 " .. liveTweens())

-- ---------------- case8: 峰值几何（skill 第 4 节公式） ----------------
print("== case8 峰值几何 ==")
local f = io.open(PREFAB, "r")
if f then
    local raw = f:read("*a")
    f:close()
    -- rewardPre = 1060×200（卡面）；rect 拉伸满宽 ⇒ 视口/屏宽 = 根节点 1080
    local itemW = tonumber(raw:match("m_SizeDelta: {x: (1060), y: 200}"))
    local viewW = tonumber(raw:match("m_SizeDelta: {x: (1080), y: 2160}"))
    Check(itemW ~= nil and Near(itemW, 1060), "rewardPre 宽应为 1060，实际 " .. tostring(itemW))
    Check(viewW ~= nil and Near(viewW, 1080), "面板根宽应为 1080，实际 " .. tostring(viewW))
    if itemW and viewW then
        local edge = (itemW * 1.02 - viewW) / 2
        Check(edge <= 2, ("缺省 peak=1.02 时卡面每侧出视口 %.1fpx（≤2px 与 ValuePackPanel 同口径，屏边裁掉不可见）"):format(edge))
        print(("  严格不越界的几何上限 peak = %.4f"):format(viewW / itemW))
    end
else
    Check(false, "读不到 prefab：" .. PREFAB)
end

print("")
print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
