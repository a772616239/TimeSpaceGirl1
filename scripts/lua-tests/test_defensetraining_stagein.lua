-- 防守训练面板（DefenseTrainingPopup）关卡节点入场 —— 离线验证，不依赖 Unity：
--   ① 数据源       5 个关卡节点（Bg/bg/Stage1..5），数组顺序 = 关卡顺序
--   ② 起点/错开    首帧 0.5（从小到大），相邻错开 0.06、整批跨度上限 0.24
--   ③ 弹性关键帧   0.5 → 1.06（0.26s）→ 0.97（0.13s）→ 1.01（0.09s）→ 1（0.07s），落定吸附
--   ④ 播的时机     OnShow 播；点「重置关卡」是同屏数据刷新 ⇒ 不重播；再打开面板 ⇒ 播
--   ⑤ 生命周期     OnClose / OnDestroy 都 Kill + 复位（漏了 = 关卡节点永久停在 0.5）
--   ⑥ 手感选型     不能退回 duang / OutElastic（单节点画面 260x163，属大块头）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_defensetraining_stagein.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/DefenseTraining/DefenseTrainingPopup.lua"
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
    return a ~= nil and math.abs(a - b) < 1e-6
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
Vector2 = {
    New = function(x, y)
        return { x = x, y = y, anchorMin = nil, anchorMax = nil, pivot = nil }
    end,
}
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = {
    Linear = "Linear", InOutQuad = "InOutQuad", OutQuad = "OutQuad",
    OutCubic = "OutCubic", OutElastic = "OutElastic",
}
IsNull = function(o) return o == nil end
local errors = {}
LogError = function(msg) errors[#errors + 1] = msg end
GetLanguageStrById = function() return "" end
Inherit = function() return {} end
ConfigName = {}
ConfigManager = {
    GetConfig = function() return {} end,
    GetAllConfigsData = function() return {} end,
}
SubUIConfig = { PlayerHeadFrameView = 1, UpView = 2, ScrollCycleView = 3, ItemView = 4 }
UpViewOpenType = { ShowRight = 1 }
PanelType = { AlameinWarPanel = 1 }
FormationTypeDef = { DEFENSE_TRAINING = 1 }
BATTLE_TYPE = { DefenseTraining = 1 }
BattleManager = {
    battleType = 0,
    IsInBackBattle = function() return false end,
}
SubUIManager = { Open = function() return nil end, Close = function() end }
UIManager = { OpenPanel = function() end }
PopupTipPanel = { ShowTip = function() end, ShowTipByLanguageId = function() end }
PopupTipPanel.ShowTip = function() end
AppReview_TryShowOnKeyLevel = function() end

-- 记录每个节点的点击回调，用来模拟「点重置关卡」
local clickHandlers = {}
Util = {
    AddClick = function(go, fn) clickHandlers[go] = fn end,
    AddOnceClick = function(go, fn) clickHandlers[go] = fn end,
}
PlaySoundWithoutClick = function() end

-- ---------------- 假节点树 ----------------
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

local function node(name)
    local n = {
        name = name, children = {}, activeSelf = true,
        localScale = v3(1, 1, 1),
        rect = { width = 100, height = 100 },
        pivot = { x = 0.5, y = 0.5 },
        anchoredPosition = { x = 0, y = 0 },
        localPosition = v3(0, 0, 0),
    }
    n.gameObject = n
    n.transform = n
    local comps = {}
    function n:GetComponent(kind)
        if not comps[kind] then
            comps[kind] = {
                text = "", color = nil,
                localPosition = v3(0, 0, 0),
                anchoredPosition = self.anchoredPosition,
                anchorMin = { x = 0.5, y = 0.5 }, anchorMax = { x = 0.5, y = 0.5 },
                pivot = self.pivot, rect = self.rect,
            }
        end
        return comps[kind]
    end
    function n:SetActive(v) self.activeSelf = v end
    function n:DOScale(v, dur) return newTween(self, v, dur) end
    return n
end

local root = node("DefenseTrainingPopup")
-- 按 "a/b/c" 走树，缺的自动补出来（和 Util.GetGameObject 的路径语义一致，省得抄整棵树）
local function walk(start, path)
    local cur = start
    for seg in path:gmatch("[^/]+") do
        if not cur.children[seg] then
            cur.children[seg] = node(seg)
        end
        cur = cur.children[seg]
    end
    return cur
end
Util.GetGameObject = function(parent, path) return walk(parent, path) end

local scrollViews = {}
SubUIManager.Open = function(cfg, parent)
    local n = node("view")
    local view = {
        gameObject = n, transform = n, moveTween = {}, elastic = true,
        OnShow = function() end, OnOpen = function() end, OnClose = function() end,
    }
    function view:SetData(data, cb) end
    scrollViews[#scrollViews + 1] = view
    return view
end

-- ---------------- 面板依赖 ----------------
local managerState = {
    curFightId = 7, maxLastFinishedId = 6, todayStartFightId = 1, todayPassCount = 2,
    teamLock = 0, firstAwardedProgress = 0, ranks = {}, myRankInfo = nil,
}
DefenseTrainingManager = setmetatable(managerState, {
    __index = function(_, k)
        if k == "GetFirstRewardList" then
            return function() return { { Id = 10, FirstAward = { { 1001, 1 } } } } end
        end
        if k == "GetAllRewardNoRepeatIds" then
            return function() return {} end
        end
        if k == "UpdateRankingData" then
            return function() end          -- 不回调 ⇒ 不碰排行榜 UI
        end
        if k == "SetFriendSupportHeroDatas" then
            return function() end
        end
        return 0
    end,
})

local netCalls = { info = 0, rest = 0 }
NetManager = {
    GetTankInfoOfTeam = function(_, cb) end,
    TeamInfoRequest = function() end,
    DefTrainingGetInfo = function(cb) netCalls.info = netCalls.info + 1; if cb then cb() end end,
    DefTrainingHandRest = function(cb) netCalls.rest = netCalls.rest + 1; if cb then cb() end end,
    GetTankListFromFriendByModuleId = function(_, cb) if cb then cb() end end,
}

local popInModule
function require(path)
    if path == "Modules/Common/ItemPopIn" then
        if not popInModule then
            popInModule = assert(loadfile(POPIN))()
        end
        return popInModule
    end
    return {}
end

local Panel = assert(loadfile(SRC))()

-- ---------------- 小工具 ----------------
Panel.gameObject = root
Panel.transform = root
Panel:InitComponent()
Panel:BindEvent()          -- BasePanel 的桩不会替我们调，测试里显式绑一下（要拿重置按钮的回调）

local stages = {}
for i = 1, 5 do
    stages[i] = walk(root, "Bg/bg/Stage" .. tostring(i))
end

local function resetAll()
    for i = 1, 5 do
        stages[i].localScale = v3(1, 1, 1)
    end
end

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- ---------------- case 1: 数据源 ----------------
print("== case1 数据源（5 个关卡节点）==")
Check(Panel.stageIn ~= nil, "InitComponent 建好了 stageIn")
local items = Panel.stageIn:_Collect()
Check(#items == 5, "收集到 5 个关卡节点，实际 " .. #items)
Check(items[1] == stages[1] and items[5] == stages[5], "数组顺序 = Stage1..Stage5")

-- ---------------- case 2: 起点与错开 ----------------
print("== case2 起点 0.5 + 错开 0.06 ==")
resetAll()
tweens = {}
Panel:PlayStagePopIn()
Check(#tweens == 5, "5 个节点各建 1 条，实际 " .. #tweens)
Check(Near(stages[1].localScale.x, 0.5), "首帧缩到 0.5（从小到大），实际 " .. stages[1].localScale.x)
Check(Near(tweens[1].endv.x, 1.06) and Near(tweens[1].dur, 0.26), "第一段 0.5 → 1.06 / 0.26s")
Check(tweens[1].ease == Ease.OutCubic, "第一段 OutCubic（冲出峰值）")
Check(Near(tweens[1].delay, 0) and Near(tweens[2].delay, 0.06) and Near(tweens[5].delay, 0.24),
    "错开 0.06，末项 0.24 起播")
Check(#errors == 0, "播放过程没有 LogError，实际 " .. #errors)

-- ---------------- case 3: 弹性关键帧链 ----------------
print("== case3 四段弹性关键帧 ==")
resetAll()
tweens = {}
Panel:PlayStagePopIn()
local chain = { { 1.06, 0.26, Ease.OutCubic }, { 0.97, 0.13, Ease.InOutQuad },
                { 1.01, 0.09, Ease.InOutQuad }, { 1, 0.07, Ease.OutQuad } }
local total = 0
local cursor = 1               -- 从 Stage1 的第一段开始走链
for i, expect in ipairs(chain) do
    local t = tweens[cursor]
    Check(Near(t.endv.x, expect[1]) and Near(t.dur, expect[2]), "第 " .. i .. " 段目标 " .. expect[1] .. " / " .. expect[2] .. "s")
    Check(t.ease == expect[3], "第 " .. i .. " 段 " .. tostring(expect[3]))
    total = total + t.dur
    t:Complete()   -- 收尾会吸附到基准，所以要先记下这一段再走进下一段
    cursor = #tweens
end
Check(Near(total, 0.55), "单节点总时长 0.55s，实际 " .. total)
Check(Near(stages[1].localScale.x, 1), "落定吸附在 1（不留浮点残差），实际 " .. tostring(stages[1].localScale.x))

-- ---------------- case 4: 播的时机 ----------------
print("== case4 播的时机（打开播 / 返回与重置不播）==")
resetAll()
tweens = {}
Panel:OnOpen()          -- 从外面打开面板
Panel:OnShow()
Check(#tweens == 5, "打开面板播一轮（5 条），实际 " .. #tweens)

-- 战斗返回（BasePanel 走 IsBackOpen 分支：只调 OnShow，不调 OnOpen）⇒ 不重播
Panel:StopStagePopIn()
resetAll()
tweens = {}
Panel:OnShow()
Check(#tweens == 0, "战斗返回的 OnShow 不重播，实际 " .. #tweens .. " 条")

-- 点「重置关卡」：回调链最后调 this:OnShow()，同屏数据刷新 ⇒ 也不重播
resetAll()
tweens = {}
local resetBtn = walk(root, "Bg/btnReset/btn")
Check(clickHandlers[resetBtn] ~= nil, "重置按钮绑上了回调")
clickHandlers[resetBtn]()
Check(netCalls.rest == 1, "重置请求发出去了")
Check(#tweens == 0, "重置后不重播，实际 " .. #tweens .. " 条")

-- 关掉再打开（OnOpen + OnShow）⇒ 要播
Panel:StopStagePopIn()
resetAll()
tweens = {}
Panel:OnOpen()
Panel:OnShow()
Check(#tweens == 5, "重新打开面板重新播，实际 " .. #tweens)

-- ---------------- case 5: 回收 ----------------
print("== case5 回收（OnClose / OnDestroy）==")
Panel:StopStagePopIn()
resetAll()
tweens = {}
Panel:PlayStagePopIn()
Panel:OnClose()
Check(liveTweens() == 0, "OnClose 后没有存活 tween，实际 " .. liveTweens())
Check(Near(stages[1].localScale.x, 1) and Near(stages[5].localScale.x, 1), "关闭时复位到 1（不会停在 0.5）")

resetAll()
tweens = {}
Panel:PlayStagePopIn()
Panel:OnDestroy()
Check(liveTweens() == 0, "OnDestroy 后没有存活 tween，实际 " .. liveTweens())
Check(Near(stages[3].localScale.x, 1), "销毁时复位到 1")

-- ---------------- case 6: 源码断言（接线 + 选型）----------------
print("== case6 接线与选型 ==")
local f = assert(io.open(SRC, "rb"))
local src = (f:read("*a")):gsub("\r\n", "\n")
f:close()

local function bodyOf(header)
    local i = src:find(header, 1, true)
    if not i then return nil end
    local rest = src:sub(i + #header)
    local j = rest:find("\nfunction ", 1, true) or #rest
    return rest:sub(1, j)
end

local show = bodyOf("function DefenseTrainingPopup:OnShow()")
Check(show ~= nil, "找到 OnShow")
local updateMain, play = nil, nil
local idx = 0
for line in (show or ""):gmatch("[^\n]+") do
    idx = idx + 1
    if line:find("self:UpdateMain()", 1, true) then updateMain = idx end
    if line:find("this:PlayStagePopIn()", 1, true) then play = idx end
end
Check(updateMain and play and play > updateMain, "关卡入场排在 UpdateMain（status 节点已激活）之后")
Check((show or ""):find("playStageInOnShow", 1, true) ~= nil, "OnShow 消费 playStageInOnShow 的一次性标记")

Check(((bodyOf("function DefenseTrainingPopup:OnOpen()") or ""):find("playStageInOnShow = true", 1, true) ~= nil), "OnOpen 置位（战斗中返回不含 OnOpen）")
Check((bodyOf("function DefenseTrainingPopup:OnClose()") or ""):find("StopStagePopIn", 1, true) ~= nil, "OnClose 里回收")
Check((bodyOf("function DefenseTrainingPopup:OnDestroy()") or ""):find("StopStagePopIn", 1, true) ~= nil, "OnDestroy 里回收")
Check(src:find('mode = "phases"', 1, true) ~= nil, "用 phases 关键帧")
Check(src:find('mode = "duang"', 1, true) == nil and src:find('ease = "OutElastic"', 1, true) == nil,
    "没有退回 duang / OutElastic（大块头会「闪一下」，见 skill 1.1）")
Check(src:find('from = 0.5', 1, true) ~= nil, "起点 0.5（从小到大）")

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
