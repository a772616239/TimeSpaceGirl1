-- 「选择国家」弹窗 与 新手引导 的先后顺序测试（纯逻辑，不依赖 Unity）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_country_popup_vs_guide.lua
--
-- 复现的线上问题：首次进主界面，CountryFlagSelectPopup 延时 0.6s 才弹，
-- 而强制引导（openType==4）监听的是 MainPanel 的 UI.OnOpen —— 那个事件在
-- OnShow 之后立刻派发，于是 GuidePanel 先开、选择国家面板 0.6s 后压在上面
-- （GuidePanel 是全屏面板，还会把栈内的选择面板一起关掉）。
--
-- 现在的约定：选择国家面板优先，引导排队；两者任何时刻都不允许同屏。

local ROOT = os.getenv("TS_ROOT") or "."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ================= 最小环境桩 =================
local logs, errors = {}, {}
Log = function(s) logs[#logs + 1] = tostring(s) end
LogRed, LogGreen, LogWarn, LogPink = Log, Log, Log, Log
LogError = function(s) errors[#errors + 1] = tostring(s) end
function GetLan() return 0 end
function GetLanguageStrById(id) return tostring(id) end
function GetLanguageStrByStr(zh) return zh end

GuideType = { Force = 1, Function = 2 }
ConfigName = {
    GuideConfig = "GuideConfig",
    GlobalSystemConfig = "GlobalSystemConfig",
    PlayerLevelConfig = "PlayerLevelConfig",
}
UIName = { MainPanel = 1, GuidePanel = 10, CountryFlagSelectPopup = 1011 }

local guideConfig = {
    [1001] = { Type = GuideType.Force, Next = 0, ServerNext = 0 },
}
ConfigManager = {
    GetConfig = function(name)
        if name == ConfigName.GuideConfig then return guideConfig end
        return {}
    end,
    GetAllConfigsData = function() return {} end,
}

-- cjson 是引擎侧的 C 模块，纯 luajit 下没有，预填占位即可（GuideManager 只在别处用）
package.loaded.cjson = { encode = function() return "{}" end, decode = function() return {} end }

local prefs = {}
PlayerPrefs = {
    GetString = function(k, d) local v = prefs[k]; if v == nil then return d end; return v end,
    SetString = function(k, v) prefs[k] = v end,
    GetInt = function(k, d) local v = prefs[k]; if v == nil then return d end; return v end,
    SetInt = function(k, v) prefs[k] = v end,
    Save = function() end,
}
PlayerManager = { uid = 10000004, name = "Tester", country = "" }
DataCenterManager = { CommitClickStatus = function() end }
NetManager = { SaveGuideDataRequest = function() end, SetPlayerCountry = function() end }

-- ---- 事件总线（够用版：派发时对回调列表做快照，允许回调里增删监听）----
local listeners = {}
GameEvent = { UI = { OnOpen = "UI.OnOpen", OnClose = "UI.OnClose", OnFocus = "UI.OnFocus" } }
Game = {}
Game.GlobalEvent = {
    AddEvent = function(_, key, fn)
        listeners[key] = listeners[key] or {}
        table.insert(listeners[key], fn)
    end,
    RemoveEvent = function(_, key, fn)
        local list = listeners[key]
        if not list then return end
        for i = #list, 1, -1 do
            if list[i] == fn then table.remove(list, i) end
        end
    end,
    DispatchEvent = function(_, key, ...)
        local list = listeners[key]
        if not list then return end
        local snapshot = {}
        for i = 1, #list do snapshot[i] = list[i] end
        for i = 1, #snapshot do snapshot[i](...) end
    end,
}

-- ---- Timer（手动 pump 驱动）----
Time = { realtimeSinceStartup = 0 }
local timers = {}
Timer = {}
function Timer.New(fn, delay)
    local t = { fn = fn, delay = delay, time = 0, stopped = false }
    function t:Start() timers[#timers + 1] = self end
    function t:Stop() self.stopped = true end
    return t
end
local function pump(seconds)
    local step = 0.05
    local elapsed = 0
    while elapsed < seconds - 1e-9 do
        elapsed = elapsed + step
        Time.realtimeSinceStartup = Time.realtimeSinceStartup + step
        local snapshot = {}
        for i = 1, #timers do snapshot[i] = timers[i] end
        for i = 1, #snapshot do
            local t = snapshot[i]
            if not t.stopped then
                t.time = t.time + step
                if t.time >= t.delay - 1e-9 then
                    t.stopped = true
                    t.fn()
                end
            end
        end
        local alive = {}
        for i = 1, #timers do
            if not timers[i].stopped then alive[#alive + 1] = timers[i] end
        end
        timers = alive
    end
end

-- ---- UIManager 桩：维护「哪些面板开着」+ 同屏违规统计 ----
local openPanels = {}
local failOpenId = nil
local coexist = {}
UIManager = {}
function UIManager.IsOpen(id) return openPanels[id] == true end
function UIManager.OpenPanel(id, ...)
    if failOpenId == id then return nil end
    if id == UIName.GuidePanel and openPanels[UIName.CountryFlagSelectPopup] then
        coexist[#coexist + 1] = "GuidePanel 开在选择国家面板之上"
    end
    if id == UIName.CountryFlagSelectPopup and openPanels[UIName.GuidePanel] then
        coexist[#coexist + 1] = "选择国家面板 开在 GuidePanel 之上"
    end
    openPanels[id] = true
    -- 与 BasePanel:OpenUI 一致：OnOpen/OnShow 之后再派发 UI.OnOpen
    Game.GlobalEvent:DispatchEvent(GameEvent.UI.OnOpen, id, nil)
    return { id = id }
end
function UIManager.ClosePanel(id)
    if not openPanels[id] then return end
    openPanels[id] = nil
    -- 与 BasePanel:CloseUI 一致：关掉之后再派发 UI.OnClose
    Game.GlobalEvent:DispatchEvent(GameEvent.UI.OnClose, id, nil)
end

-- ---- 载入被测模块 ----
assert(loadfile(LUA_SRC .. "/Modules/CountryRank/CountryConfig.lua"))()
assert(loadfile(LUA_SRC .. "/Modules/CountryRank/CountryRankManager.lua"))()
assert(loadfile(LUA_SRC .. "/Modules/Guide/GuideManager.lua"))()

local pass, fail = 0, 0
local function check(desc, cond, extra)
    if cond then
        pass = pass + 1
        print(string.format("  ✅ %s", desc))
    else
        fail = fail + 1
        print(string.format("  ❌ %s %s", desc, extra and ("→ " .. tostring(extra)) or ""))
    end
end

local function reset()
    prefs = {}
    openPanels = {}
    coexist = {}
    failOpenId = nil
    timers = {}
    listeners = {}
    CountryRankManager.Initialize()
end

local POPUP = UIName.CountryFlagSelectPopup
local GUIDE = UIName.GuidePanel

print("\n[1] 正常时序：选择国家先弹，引导排队等它关")
do
    reset()
    CountryRankManager.TryShowFirstEnterGuide()
    check("占屏标记同步置上", CountryRankManager.IsFirstEnterPopupShowing() == true)
    check("面板还没弹（延时 0.6s）", UIManager.IsOpen(POPUP) == false)

    -- MainPanel 的 UI.OnOpen 在 OnShow 之后派发 ⇒ 强制引导此刻触发
    GuideManager.ShowGuide(1001)
    check("引导被排队，没有立刻开 GuidePanel", UIManager.IsOpen(GUIDE) == false)

    pump(0.7)
    check("0.6s 后选择国家面板弹出", UIManager.IsOpen(POPUP) == true)
    check("引导仍在排队", UIManager.IsOpen(GUIDE) == false)

    UIManager.ClosePanel(POPUP)
    check("关窗后解除占屏", CountryRankManager.IsFirstEnterPopupShowing() == false)
    check("关窗当下引导还没抢跑", UIManager.IsOpen(GUIDE) == false)
    pump(0.3)
    check("引导随后正常弹出", UIManager.IsOpen(GUIDE) == true)
    check("全程没有同屏", #coexist == 0, coexist[1])
end

print("\n[2] 反向时序：引导已经开着时，选择国家面板等它关掉")
do
    reset()
    UIManager.OpenPanel(GUIDE) -- 模拟序章强制引导正在跑
    CountryRankManager.TryShowFirstEnterGuide()
    pump(0.7)
    check("引导开着时不抢屏", UIManager.IsOpen(POPUP) == false)
    UIManager.ClosePanel(GUIDE)
    pump(0.4)
    check("引导关掉后选择国家面板才弹", UIManager.IsOpen(POPUP) == true)
    check("全程没有同屏", #coexist == 0, coexist[1])
end

print("\n[3] 兜底：面板打不开也不能把引导永久卡住")
do
    reset()
    failOpenId = POPUP
    CountryRankManager.TryShowFirstEnterGuide()
    GuideManager.ShowGuide(1001)
    check("引导被排队", UIManager.IsOpen(GUIDE) == false)
    pump(1.2)
    check("面板确实没开起来", UIManager.IsOpen(POPUP) == false)
    check("打开失败立刻解除占屏", CountryRankManager.IsFirstEnterPopupShowing() == false)
    check("排队的引导随后被放行", UIManager.IsOpen(GUIDE) == true)
    check("全程没有同屏", #coexist == 0, coexist[1])
end

print("\n[4] 兜底：占屏标记超时后自动失效")
do
    reset()
    -- 模拟「标记置上了但弹窗链路整段没跑起来」：超时后必须让引导过去
    CountryRankManager.MarkFirstEnterPopupShowing(true)
    GuideManager.ShowGuide(1001)
    check("延时窗口内引导仍然排队", UIManager.IsOpen(GUIDE) == false)
    pump(2.5)
    GuideManager.FlushPendingGuidesNow()
    check("超时后不再拦引导", UIManager.IsOpen(GUIDE) == true)
end

print(string.format("\n结果：%d 通过 / %d 失败", pass, fail))
if fail > 0 then os.exit(1) end
