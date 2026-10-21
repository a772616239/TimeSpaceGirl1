-- 离线验证 GrowthManual（成长手册）两个列表页的入场动画接线 —— 不依赖 Unity，直接 luajit 跑：
--   ① RewardPreview:OnShow   列表建好 → 逐格放大缩小（0.82 起，逐项错开）
--   ② refresh(isAni=false)   数据回调刷新不播（否则每次回调整列都弹一遍）
--   ③ TaskPreview:OnShow     同上
--   ④ 切页重播               再走一次 view:OnShow（TabBox 点击就是这条路径）会重新从 0.82 起
--   ⑤ 生命周期               OnClose / OnDestroy 必须 Kill + 复位
--   ⑥ 接线约束               面板 SwitchView 必须调 view:OnShow；Play 必须在 refresh 的 isAni 分支里
--
-- 说明：列表项由假 ScrollCycleView:SetData 灌入（SetData 的契约就是「克隆 item 并回调」
--       ——View/ScrollCycleView.lua:377-416），SingleTask 的取数逻辑与动画无关，这里用
--       通用假节点兜住，只验动画接线。
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_growthmanual_openanim.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local LUA = ROOT .. "Assets/ManagedResources/~Lua/"
local REWARD = LUA .. "Modules/GrowthManual/GrowthManual_RewardPreview.lua"
local TASK = LUA .. "Modules/GrowthManual/GrowthManual_TaskPreview.lua"
local PANEL = LUA .. "Modules/GrowthManual/GrowthManualPanel.lua"
local POPIN = LUA .. "Modules/Common/ItemPopIn.lua"

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
    if type(a) == "number" then
        a, b = b, a
    end
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

local tweens = {}
local function newTween(tf, endv, dur)
    local t = { tf = tf, endv = endv, dur = dur, delay = 0, ease = nil,
                onComplete = nil, killed = false }
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

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- 通用假节点：任何 GetGameObject 路径都拿得到，GetComponent 返回可写的假组件
local nodes = {}
local function getNode(path)
    local key = tostring(path)
    if nodes[key] then return nodes[key] end
    local n = { name = key, activeSelf = true, localScale = v3(1, 1, 1) }
    n.transform = n
    n.gameObject = n
    n.childCount = 0
    function n:GetComponent(cls)
        if cls == "RectTransform" then return self end
        return { text = "", fillAmount = 0, enabled = true, sprite = nil }
    end
    function n:SetActive(v) self.activeSelf = v and true or false end
    function n:SetParent() end
    function n:DOScale(v, dur) return newTween(self, v, dur) end
    function n:GetChild() return getNode(key .. "/child") end
    nodes[key] = n
    return n
end

Util = {
    GetGameObject = function(_, path) return getNode(path) end,
    LoadSprite = function() return nil end,
    AddOnceClick = function() end,
    AddClick = function() end,
    SetGray = function() end,
}
GetLanguageStrById = function() return "text" end
GetPictureFont = function() return "" end
CheckRedPointStatus = function() end
PlaySoundWithoutClick = function() end
SoundConfig = { Sound_UICancel = 1 }
RedPointType = { TreasureOfSl = 1, QinglongSerectTreasure = 2, QinglongSerectTreasureTrail = 3 }
PanelType = { Main = 1 }
UpViewOpenType = { ShowRight = 1 }
ActivityTypeDef = { TreasureOfSomeBody = 1 }
ConfigName = { ItemConfig = 1 }
ConfigManager = { GetConfig = function() return {} end }
ConfigManager.GetConfigDataByKey = function() return {} end
ActivityGiftManager = {
    IsActivityTypeOpen = function() return true end,
    IsQualifiled = function() return true end,
    GetTaskEndTime = function() return 3600 end,
}
GameEvent = { GrowthManual = { OnGrowthManualRedpointChange = 1 }, MoneyPay = {}, Bag = {},
              TreasureOfHeaven = {}, Activity = {} }
Game = { GlobalEvent = { AddEvent = function() end, RemoveEvent = function() end,
                         DispatchEvent = function() end } }
PopupTipPanel = { ShowTip = function() end, ShowTipByLanguageId = function() end }

function string.split(s) return { s } end
CalculateSecondsNowTo_N_OClock = function() return 3600 end
TimeToDHMS = function() return "01:00:00" end
TimeToHMS = TimeToDHMS
GetTimeStamp = function() return 0 end
Timer = { New = function() return { Start = function() end, Stop = function() end } end }

-- 成长手册数据（够 SingleTask / showTaskList 跑通即可）
local rewardData = {}
for i = 1, 4 do
    rewardData[i] = { level = i, state = 0, needScore = i * 100,
                      Reward = { { type = 1, item = { 16, 100 } }, { type = 2, item = { 3, 50 } } } }
end
local taskData = {}
for i = 1, 3 do
    taskData[i] = { id = i, state = 0, show = 1, progress = 1, taskValue = { { 1, 2 }, { 1, 3 } },
                    integral = { { 16, 10 } } }
end
GrowthManualManager = {
    GetAllRewardData = function() return rewardData end,
    GetQinglongTaskData = function() return taskData end,
    GetLevel = function() return 1 end,
    GetTreasureState = function() return false end,
    UpdateTreasureState2 = function() end,
    RefreshTeskRedpoint = function() return false end,
    RefreshRewardRedpoint = function() return false end,
    GetTrailWeekTime = function() return 3600 end,
}

-- 假 ItemView（子模块打开奖励图标用）
local function newItemView()
    local n = getNode("ItemView")
    return { gameObject = n, OnOpen = function() end, OnShow = function() end,
             OnClose = function() end }
end

-- 假 ScrollCycleView：SetData 克隆 item 并回调（真实现见 View/ScrollCycleView.lua:377）
local function newScrollView()
    local sv = { goItemList = {}, dataCount = 0 }
    function sv:SetData(dataList, updateFunc)
        self.goItemList = {}
        self.dataCount = #dataList
        for i = 1, #dataList do
            local go = getNode("item" .. i)
            go.localScale = v3(1, 1, 1)
            go.activeSelf = true
            self.goItemList[i] = go
            if updateFunc then updateFunc(i, go) end
        end
    end
    function sv:SetIndex() end
    function sv:ForeachItemGO(func)
        for i = 1, math.min(#self.goItemList, self.dataCount) do
            func(i, self.goItemList[i])
        end
    end
    return sv
end

SubUIManager = {
    Open = function(id) return newItemView() end,
    Close = function() end,
}
SubUIConfig = { ItemView = 1, PlayerHeadFrameView = 2, UpView = 3, ScrollCycleView = 4 }

local popInModule = assert(loadfile(POPIN))()
function require(path)
    if path == "Modules/Common/ItemPopIn" then return popInModule end
    return {}
end

-- 读数工具：清空 tween 记录，避免跨用例串味
local function resetTweens() tweens = {} end

-- =================== RewardPreview ===================
print("== case1 RewardPreview:OnShow ==")
local Reward = assert(loadfile(REWARD))()
Reward.ScrollView = newScrollView()
Reward.popIn = popInModule.New(function() return Reward.ScrollView end)
resetTweens()
Reward:OnShow({ sortingOrder = 0 })
Check(#tweens == 4, "4 条奖励档位应各起一条放大 tween，实际 " .. #tweens)
Check(Near(Reward.ScrollView.goItemList[1].localScale.x, 0.82), "第 1 档从 0.82 起")
Check(Near(tweens[2].delay, 0.055), "第 2 档错开 0.055，实际 " .. tweens[2].delay)
print("  4 档奖励：0.82 起，延迟 0/0.055/0.11/0.165")

print("== case2 数据回调刷新不播 ==")
resetTweens()
Reward.refresh(false, false)
Check(#tweens == 0, "isAni=false 不该建 tween，实际 " .. #tweens)
print("  领取奖励这类刷新（isAni=false）不弹")

print("== case3 RewardPreview 切页重播 ==")
resetTweens()
for _, t in ipairs(tweens) do t:Kill() end
Reward:OnShow({ sortingOrder = 0 })   -- 相当于 TabBox 点回第 1 个页签
Check(liveTweens() == 4, ("重播应只有一轮 4 条存活，实际 %d"):format(liveTweens()))
Check(Near(Reward.ScrollView.goItemList[1].localScale.x, 0.82), "重播起点仍为 0.82（不叠加）")

print("== case4 RewardPreview 生命周期 ==")
Reward:OnClose()
Check(liveTweens() == 0, "OnClose 后不应有存活 tween，实际 " .. liveTweens())
Check(Near(Reward.ScrollView.goItemList[1].localScale.x, 1), "OnClose 后复位到 1")
resetTweens()
Reward:OnShow({ sortingOrder = 0 })
Reward:OnDestroy()
Check(liveTweens() == 0, "OnDestroy 后不应有存活 tween，实际 " .. liveTweens())
Check(Near(Reward.ScrollView.goItemList[1].localScale.x, 1), "OnDestroy 后复位到 1")

-- =================== TaskPreview ===================
print("== case5 TaskPreview:OnShow ==")
local Task = assert(loadfile(TASK))()
Task.ScrollView = newScrollView()
Task.popIn = popInModule.New(function() return Task.ScrollView end)
Task.btnList = { getNode("btn1"), getNode("btn2"), getNode("btn3") }
Task.remainTime = getNode("remainTime")
Task.dayTrailBtn = getNode("dayTrailBtn")
Task.weekTrailBtn = getNode("weekTrailBtn")
Task.finalTrailBtn = getNode("finalTrailBtn")
resetTweens()
Task:OnShow({ sortingOrder = 0 })
Check(#tweens == 3, "3 条任务应各起一条放大 tween，实际 " .. #tweens)
Check(Near(Task.ScrollView.goItemList[1].localScale.x, 0.82), "第 1 条任务从 0.82 起")
Check(Near(tweens[3].delay, 0.11), "第 3 条错开 0.11，实际 " .. tweens[3].delay)
print("  3 条任务：0.82 起，延迟 0/0.055/0.11")

print("== case6 TaskPreview 数据回调刷新不播 ==")
resetTweens()
Task.refresh(false, false)
Check(#tweens == 0, "isAni=false 不该建 tween，实际 " .. #tweens)

print("== case7 TaskPreview 切页重播 + 生命周期 ==")
resetTweens()
Task:OnShow({ sortingOrder = 0 })
Check(liveTweens() == 3, ("重播应只有一轮 3 条存活，实际 %d"):format(liveTweens()))
Task:OnClose()
Check(liveTweens() == 0, "OnClose 后不应有存活 tween")
Check(Near(Task.ScrollView.goItemList[1].localScale.x, 1), "OnClose 后复位到 1")

-- =================== 接线约束 ===================
print("== case8 接线约束 ==")
local function readSource(path)
    local t = {}
    for line in io.lines(path) do t[#t + 1] = line end
    return t
end

local panelLines = readSource(PANEL)
local switchCallsView = false
for _, line in ipairs(panelLines) do
    if line:match("contentScripts%[index%]%.view:OnShow%(this%)") then
        switchCallsView = true
    end
end
Check(switchCallsView, "面板 SwitchView 必须调 view:OnShow —— TabBox 点击就是走这条路径重播")

for _, pair in ipairs({ { "RewardPreview", REWARD }, { "TaskPreview", TASK } }) do
    local lines = readSource(pair[2])
    local playCalls, gateIdx, playIdx = 0, nil, nil
    for i, line in ipairs(lines) do
        if line:match("^%s*if isAni then") then
            gateIdx = i
        end
        if line:match("^%s*this:PlayItemPopIn%(%)") then
            playCalls = playCalls + 1
            playIdx = i
        end
    end
    Check(playCalls == 1, pair[1] .. ": PlayItemPopIn 应只有 1 处调用，实际 " .. playCalls)
    Check(gateIdx and playIdx and playIdx > gateIdx and (playIdx - gateIdx) <= 3,
        pair[1] .. ": Play 必须紧跟在 if isAni then 分支里（数据回调刷新不播）")
end

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
