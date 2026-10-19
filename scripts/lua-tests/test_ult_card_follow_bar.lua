-- 大招小卡（HelpHeroMiniCard_Mine）与技能名条（myRect_Skill）收场时序回归测试
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_ult_card_follow_bar.lua
--
-- 覆盖的回归点：卡片不许比技能栏先消失。历史 bug 是卡片自带一个 2.0s 定时器、
-- 技能栏亮 3.0s，于是卡片稳定早 1 秒收掉；带特写的大招更严重——前摇 0.5s +
-- CloseupDuration（战斗暂停）这段里技能栏根本没亮，卡片的 2 秒却照走，等技能栏
-- 亮起来时卡片已经没了。现在卡片只有一个时钟：跟随技能栏。

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"

-- ---- 虚拟时钟 ----
local now = 0
local timers = {}
local events = {}   -- { t = 触发时刻, fn = 回调 }

Time = setmetatable({}, {
    __index = function(_, k)
        if k == "realtimeSinceStartup" then return now end
        if k == "deltaTime" then return 0.01 end
        if k == "unscaledDeltaTime" then return 0.01 end
        return nil
    end,
})

Timer = {}
function Timer.New(func, duration, loop, unscaled)
    local t = {
        func = func, duration = duration, time = duration,
        loop = loop or 1, unscaled = unscaled and true or false, running = false,
    }
    function t:Start() self.running = true; timers[#timers + 1] = self end
    function t:Stop() self.running = false end
    return t
end

local function Step()
    local dt = 0.01
    now = now + dt
    for _, e in ipairs(events) do
        if not e.done and now + 1e-9 >= e.t then
            e.done = true
            e.fn()
        end
    end
    local alive = {}
    for _, t in ipairs(timers) do
        if t.running then
            t.time = t.time - (t.unscaled and dt or dt)
            if t.time <= 0 then
                t.func()
                if t.loop > 0 then
                    t.loop = t.loop - 1
                    t.time = t.time + t.duration
                end
                if t.loop == 0 then
                    t:Stop()
                elseif t.loop < 0 then
                    t.time = t.time + t.duration
                end
            end
            if t.running then alive[#alive + 1] = t end
        end
    end
    timers = alive
end

local function AdvanceTo(target) while now + 1e-9 < target do Step() end end
local function Advance(sec) AdvanceTo(now + sec) end
local function At(t, fn) events[#events + 1] = { t = t, fn = fn } end

-- 每个用例都以自己开始的时刻为 0，避免用例之间共享绝对时间
local blockStart = 0
local function BeginBlock() blockStart = now; events = {} end
local function RAt(dt, fn) At(blockStart + dt, fn) end
local function RTo(dt) AdvanceTo(blockStart + dt) end

-- ---- 最小环境桩 ----
Log = function() end
LogRed = Log
LogError = Log
LogWarn = Log
function IsNull(o) return o == nil or o.__null == true end

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { New = function(x, y, z) return { x = x, y = y, z = z } end }
Ease = { OutBack = 1, InQuad = 2 }

function GetLanguageStrById(id) return tostring(id) end

local function NewTween()
    local tw = {}
    function tw:SetEase() return self end
    function tw:Kill() end
    -- 直接结算：测试里只关心「收起后节点是否关掉」，不等补间时长
    function tw:OnComplete(cb) cb(); return self end
    return tw
end

local function NewGo(name)
    local go = { name = name, activeSelf = false, links = {}, sibling = 0 }
    function go:SetActive(v) self.activeSelf = v end
    function go:GetComponent(kind)
        if kind == "RectTransform" then return self.rt end
        return nil
    end
    go.transform = {
        gameObject = go,
        DOScale = function() return NewTween() end,
        SetSiblingIndex = function(_, i) go.sibling = i end,
        GetSiblingIndex = function() return go.sibling end,
    }
    return go
end

-- 卡片根节点（能取到 RectTransform）
local function NewCardGo()
    local go = NewGo("HelpHeroMiniCard_Mine")
    go.rt = {
        pivot = Vector2.New(0.5, 0.5),
        sizeDelta = Vector2.New(0, 0),
        anchorMin = Vector2.New(0, 0),
        anchorMax = Vector2.New(0, 0),
        anchoredPosition = Vector2.New(0, 0),
        localScale = Vector3.New(1, 1, 1),
    }
    go.links["live"] = (function()
        local l = NewGo("live")
        return l
    end)()
    return go
end

local cardCount = 0
GameObject = {
    Instantiate = function() cardCount = cardCount + 1; return NewCardGo() end,
    Destroy = function(go) if go then go.__null = true end end,
}

Util = {
    GetGameObject = function(root, path)
        local go = root and (root.gameObject or root) or nil
        if not go then return nil end
        return go.links and go.links[path] or nil
    end,
    ClearChild = function() end,
}

LoadHerolive = function() return { live = true } end
UnLoadHerolive = function() end

-- ---- 被测模块 ----
local BattleUltCard = assert(loadfile(LUA_SRC .. "/Modules/Battle/View/BattleUltCard.lua"))()

-- ---- 假视图：技能栏 myRect_Skill ----
local function NewView()
    local bar = { name = "myRect_Skill", activeInHierarchy = false }
    bar.rt = {
        pivot = Vector2.New(0, 0.5),
        sizeDelta = Vector2.New(400, 120),
        anchoredPosition = Vector2.New(30, -480),
        anchorMin = Vector2.New(0, 0.5),
        anchorMax = Vector2.New(0, 0.5),
    }
    function bar:GetComponent(kind)
        if kind == "RectTransform" then return self.rt end
        return nil
    end
    bar.transform = {
        gameObject = bar,
        GetSiblingIndex = function() return 5 end,
    }

    local tpl = NewGo("HelpHeroShow")
    local viewGo = NewGo("BattlePanel")
    viewGo.links["myRect_Skill"] = bar

    local view = {
        gameObject = viewGo,
        transform = { gameObject = viewGo },
        HelpHeroShow = tpl,
    }
    return view, bar
end

local HERO = { Id = 1001, ReadingName = 0, HeroLocation = 0 }

local failures = 0
local function Check(name, cond, detail)
    if cond then
        print("  [PASS] " .. name)
    else
        failures = failures + 1
        print("  [FAIL] " .. name .. (detail and ("  -> " .. detail) or ""))
    end
end

local function CardActive(camp)
    local s = BattleUltCard.slots[camp]
    return s ~= nil and s.go ~= nil and s.go.activeSelf == true
end

-- ① 常规：卡片和技能栏同帧亮起，技能栏亮 3 秒 → 卡片不许先走
print("== ① 技能栏亮 3 秒：卡片跟到底，不许早于技能栏消失 ==")
do
    BeginBlock()
    BattleUltCard.ResetForBattle(NewView())
    local view, bar = NewView()
    BattleUltCard.ResetForBattle(view)

    RAt(0.00, function() BattleUltCard.Show(view, HERO, 0, "a") end)
    RAt(0.00, function() bar.activeInHierarchy = true end)   -- ShowRect_Skill 同帧亮条
    RAt(3.00, function() bar.activeInHierarchy = false end)  -- 技能栏 3 秒到点

    RTo(2.90)
    Check("t=2.9 卡片仍在（旧逻辑 t=2.0 就没了）", CardActive(0))
    RTo(3.35)
    Check("t=3.35 卡片已跟随技能栏收起", not CardActive(0))
end

-- ② 带特写的大招：卡片先于技能栏 2.5 秒弹出（前摇 0.5 + 特写 2.0）
print("== ② 特写前摇：技能栏晚 2.5 秒才亮，卡片照样等它 ==")
do
    BeginBlock()
    local view, bar = NewView()
    BattleUltCard.ResetForBattle(view)

    RAt(0.00, function() BattleUltCard.Show(view, HERO, 0, "b") end)
    RAt(2.50, function() bar.activeInHierarchy = true end)
    RAt(5.50, function() bar.activeInHierarchy = false end)

    RTo(1.50)
    Check("t=1.5 卡片仍在（技能栏还没亮，不能算消失）", CardActive(0))
    RTo(2.60)
    Check("t=2.6 技能栏亮起后卡片仍在", CardActive(0))
    RTo(5.40)
    Check("t=5.4 卡片仍在（技能栏还亮着）", CardActive(0))
    RTo(5.80)
    Check("t=5.8 卡片跟随技能栏收起", not CardActive(0))
end

-- ③ 技能栏被别处提前关掉 → 卡片跟着早点收（跟随时序，不是自己的固定时长）
print("== ③ 技能栏提前关掉：卡片跟着一起收 ==")
do
    BeginBlock()
    local view, bar = NewView()
    BattleUltCard.ResetForBattle(view)

    RAt(0.00, function() BattleUltCard.Show(view, HERO, 0, "c") end)
    RAt(0.00, function() bar.activeInHierarchy = true end)
    RAt(1.50, function() bar.activeInHierarchy = false end)

    RTo(1.45)
    Check("t=1.45 卡片仍在", CardActive(0))
    RTo(1.90)
    Check("t=1.9 卡片已跟随收起", not CardActive(0))
end

-- ④ 技能栏始终不亮（极端情况）→ 兜底上限收场，不能挂死
print("== ④ 技能栏一直不亮：走兜底上限 ==")
do
    BeginBlock()
    local view, bar = NewView()
    BattleUltCard.ResetForBattle(view)
    bar.activeInHierarchy = false

    RAt(0.00, function() BattleUltCard.Show(view, HERO, 0, "d") end)

    RTo(5.80)
    Check("t=5.8 兜底前仍在", CardActive(0))
    RTo(6.30)
    Check("t=6.3 兜底收起", not CardActive(0))
end

-- ⑤ 同一阵营连放大招：第二次重新计时，不能被第一次的时钟提前切掉
print("== ⑤ 同一阵营连放两次大招：第二次重新起算 ==")
do
    BeginBlock()
    local view, bar = NewView()
    BattleUltCard.ResetForBattle(view)

    RAt(0.00, function() BattleUltCard.Show(view, HERO, 0, "e1") end)
    RAt(0.00, function() bar.activeInHierarchy = true end)
    RAt(1.00, function() BattleUltCard.Show(view, HERO, 0, "e2") end)  -- 第二个英雄的大招
    RAt(1.00, function() bar.activeInHierarchy = true end)             -- 技能栏重新计时
    RAt(3.90, function() bar.activeInHierarchy = false end)            -- 第二次的 3 秒

    RTo(2.10)
    Check("t=2.1 第二次的卡片仍在（不被第一次的 3 秒切掉）", CardActive(0))
    RTo(4.30)
    Check("t=4.3 已跟随收起", not CardActive(0))
    Check("同阵营只复用一个卡节点", cardCount >= 1)
end

-- ⑥ 位置锁定（ParentConstraint 的等价语义）：卡片存活期间技能栏位置一变，卡片跟着走
print("== ⑥ 卡片位置锁在技能栏上（存活期间跟着重算） ==")
do
    BeginBlock()
    local view, bar = NewView()
    BattleUltCard.ResetForBattle(view)

    RAt(0.00, function() BattleUltCard.Show(view, HERO, 0, "f") end)
    RAt(0.00, function() bar.activeInHierarchy = true end)
    RAt(3.00, function() bar.activeInHierarchy = false end)

    RTo(0.50)
    local y0 = BattleUltCard.slots[0].go.rt.anchoredPosition.y
    -- 技能栏整体上移 100（换分辨率 / 面板位移都会这样）
    RAt(1.03, function() bar.rt.anchoredPosition = Vector2.New(bar.rt.anchoredPosition.x, bar.rt.anchoredPosition.y + 100) end)
    -- 50Hz（0.02s）跟随：移动后 0.04s 内卡片必须已经跟到位；
    -- 旧节拍 0.1s 时下一次 tick 在 1.10，这里会读不到（就是「跟着移动」要修的那种顿挫）
    RTo(1.07)
    local y1 = BattleUltCard.slots[0].go.rt.anchoredPosition.y
    Check("技能栏上移 100 后 0.04s 内卡片跟着上移 100", math.abs((y1 - y0) - 100) < 1,
        string.format("y0=%.1f y1=%.1f", y0, y1))
    Check("卡片仍在显示", CardActive(0))

    -- 继续移动也要继续跟（不是只在第一次重算）
    RAt(1.20, function() bar.rt.anchoredPosition = Vector2.New(bar.rt.anchoredPosition.x, bar.rt.anchoredPosition.y - 40) end)
    RTo(1.30)
    local y2 = BattleUltCard.slots[0].go.rt.anchoredPosition.y
    Check("再次下移 40 后卡片继续跟着走", math.abs((y2 - y0) - 60) < 1,
        string.format("y0=%.1f y2=%.1f", y0, y2))
end

print("")
if failures == 0 then
    print("ALL PASS")
else
    print(failures .. " FAILED")
    os.exit(1)
end
