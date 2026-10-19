-- 技能名条（myRect_Skill / enemyRect_Skill）停留计时回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_skill_bar_timer.lua
--
-- 覆盖两处会让技能条「闪一下就没了」的老问题（连带把大招小卡 HelpHeroMiniCard_Mine 一起带走）：
--   ① 定时器堆积：每放一次技能就 New 一个 3 秒 Timer 却不 Stop 旧的，
--      多个英雄接连放技能时，最先起的那个会到点把刚亮起来的条关掉（最短几十毫秒）。
--   ② 走了缩放时间：Timer 第 4 参数没给 true ⇒ 用 Time.deltaTime，
--      3 倍速下「3 秒」真实只剩 1 秒，比大招小卡的 2 秒还短。
--
-- 这里用虚拟时钟跑 BattlePanel:ShowSkillBar（真源码，require 全部打成空表）。

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ---- 虚拟时钟 + Timer 桩（语义对齐 System/Timer.lua）----
local now = 0            -- 真实时间（秒）
local timeScale = 3      -- 假装玩家开着 3 倍速
local timers = {}

Time = setmetatable({}, {
    __index = function(_, k)
        if k == "realtimeSinceStartup" then return now end
        if k == "deltaTime" then return timeScale * 0.01 end
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
    local alive = {}
    for _, t in ipairs(timers) do
        if t.running then
            t.time = t.time - (t.unscaled and dt or dt * timeScale)
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

local function AdvanceTo(target)
    while now + 1e-9 < target do Step() end
end

local function Advance(seconds) AdvanceTo(now + seconds) end

-- ---- 最小环境桩 ----
Log = function() end
LogRed = Log
LogError = Log
LogWarn = Log
function IsNull(o) return o == nil or o.__null == true end

_G.Inherit = function() return {} end
_G.require = function() return {} end   -- BattlePanel 里 require 的模块一律当空表

local BattlePanel = assert(loadfile(LUA_SRC .. "/Modules/Battle/View/BattlePanel.lua"))()

-- ---- 假节点 ----
local function NewBar()
    return {
        activeSelf = false,
        SetActive = function(self, v) self.activeSelf = v end,
    }
end

-- ---- 用例 ----
local failures = 0
local function Check(name, cond, detail)
    if cond then
        print("  [PASS] " .. name)
    else
        failures = failures + 1
        print("  [FAIL] " .. name .. (detail and ("  -> " .. detail) or ""))
    end
end

print("== ① 连续放技能：技能条不能被先前的定时器提前关掉 ==")
do
    local bar = NewBar()
    -- 5 个英雄在 0.8 秒内接连放技能（真实时间）
    for i = 0, 4 do
        AdvanceTo(i * 0.2)
        BattlePanel:ShowSkillBar(bar, "myRect_SkillTimer")
        Check("第 " .. (i + 1) .. " 次显示后立刻可见", bar.activeSelf == true)
    end
    -- 最后一次是 t=0.8，理论上要亮到 t=3.8
    AdvanceTo(3.7)
    Check("t=3.7 仍在显示（不能被 t=3.0 的旧定时器关掉）", bar.activeSelf == true)
    AdvanceTo(3.95)
    Check("t=3.95 已按时收起", bar.activeSelf == false)
end

print("== ② 停留时长按真实秒算，不受 3 倍速影响 ==")
do
    local bar = NewBar()
    BattlePanel:ShowSkillBar(bar, "enemyRect_SkillTimer")
    AdvanceTo(now + 2.5)
    Check("3 倍速下 t=2.5 仍在显示（缩放计时会在 t=1.0 就关掉）", bar.activeSelf == true)
    AdvanceTo(now + 1.0)
    Check("3 倍速下 t=3.5 已收起", bar.activeSelf == false)
end

print("== ③ 敌我两条互不干扰 ==")
do
    local mine, enemy = NewBar(), NewBar()
    BattlePanel:ShowSkillBar(mine, "myRect_SkillTimer")
    Advance(0.5)
    BattlePanel:ShowSkillBar(enemy, "enemyRect_SkillTimer")
    Advance(2.55)   -- 我方到点（0.5+2.55 > 3），敌方还有 0.45 秒
    Check("我方已收起", mine.activeSelf == false)
    Check("敌方仍在显示", enemy.activeSelf == true)
end

print("== ④ 节点已被销毁时定时器不炸 ==")
do
    local bar = NewBar()
    BattlePanel:ShowSkillBar(bar, "myRect_SkillTimer")
    bar.__null = true   -- 模拟 GameObject 已被 Destroy
    local ok = pcall(function() AdvanceTo(now + 4) end)
    Check("销毁后回调不报错", ok)
end

print("")
if failures == 0 then
    print("ALL PASS")
else
    print(failures .. " FAILED")
    os.exit(1)
end
