-- 技能名条（myRect_Skill / enemyRect_Skill）停留计时回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_skill_bar_timer.lua
--
-- 覆盖几处会让技能条「闪一下就没了」/「最后一下消失得很突兀」的老问题
-- （连带把大招小卡 HelpHeroMiniCard_Mine 一起带走）：
--   ① 定时器堆积：每放一次技能就 New 一个 3 秒 Timer 却不 Stop 旧的，
--      多个英雄接连放技能时，最先起的那个会到点把刚亮起来的条关掉（最短几十毫秒）。
--   ② 走了缩放时间：Timer 第 4 参数没给 true ⇒ 用 Time.deltaTime，
--      3 倍速下「3 秒」真实只剩 1 秒，比大招小卡的 2 秒还短。
--   ③ 收场必须滑出屏幕（0.16 秒）后再关，不能直接 SetActive(false)：
--      小卡是技能条的子节点，父节点瞬间关掉卡片就「啪」地消失。
--
-- 这里用虚拟时钟跑 BattlePanel:ShowSkillBar（真源码，require 全部打成空表）。

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ---- 虚拟时钟 + Timer 桩（语义对齐 System/Timer.lua）----
local now = 0            -- 真实时间（秒）
local timeScale = 3      -- 假装玩家开着 3 倍速
local timers = {}
local tweens = {}        -- 正在跑的收场补间（虚拟时钟推进）

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

    -- 补间按虚拟时钟推进（对应真实 DOTween 的 0.16 秒滑出）
    local aliveTweens = {}
    for _, tw in ipairs(tweens) do
        if not tw.killed and not tw.done then
            tw.t = tw.t + dt
            local dur = (tw.dur and tw.dur > 0) and tw.dur or 0.0001
            local k = math.min(1, tw.t / dur)
            local x = tw.from + (tw.to - tw.from) * k
            tw.bar.rt.localPosition = Vector3.New(x, tw.bar.rt.localPosition.y, tw.bar.rt.localPosition.z)
            if k >= 1 then
                tw.done = true
                if tw.cb then tw.cb() end
            else
                aliveTweens[#aliveTweens + 1] = tw
            end
        end
    end
    tweens = aliveTweens
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

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { New = function(x, y, z) return { x = x, y = y, z = z } end }
Ease = { InQuad = 2, OutQuad = 3, Linear = 1, OutBack = 4 }

_G.Inherit = function() return {} end
-- BattlePanel 里 require 的模块一律当空表；按名字缓存，方便测试注入/观察（如技能条收场要通知小卡）
local required = {}
_G.require = function(name)
    required[name] = required[name] or {}
    return required[name]
end

local BattlePanel = assert(loadfile(LUA_SRC .. "/Modules/Battle/View/BattlePanel.lua"))()
local BattleUltCard = required["Modules/Battle/View/BattleUltCard"]

-- ---- 假节点（带 RectTransform 与横向补间）----
local function NewBar(camp)
    local bar = {
        activeSelf = false,
        rt = {
            -- 静止位：我方贴左边（local x = -540）、敌方贴右边（+540）
            localPosition = Vector3.New(camp == 0 and -540 or 540, -215, 0),
            anchoredPosition = Vector2.New(0, -215),
        },
    }
    function bar:SetActive(v) self.activeSelf = v end
    function bar:GetComponent(kind)
        if kind == "RectTransform" then return self.rt end
        return nil
    end
    bar.transform = {
        DOLocalMoveX = function(_, to, dur)
            local tw = { bar = bar, from = bar.rt.localPosition.x, to = to, dur = dur, t = 0 }
            function tw:SetEase() return self end
            function tw:Kill() self.killed = true end
            function tw:OnComplete(cb) self.cb = cb; return self end
            tweens[#tweens + 1] = tw
            return tw
        end,
    }
    return bar
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

local function Near(a, b, eps) return math.abs(a - b) <= (eps or 0.5) end

print("== ① 连续放技能：技能条不能被先前的定时器提前关掉 ==")
do
    local bar = NewBar(0)
    -- 5 个英雄在 0.8 秒内接连放技能（真实时间）
    for i = 0, 4 do
        AdvanceTo(i * 0.2)
        BattlePanel:ShowSkillBar(bar, "myRect_SkillTimer")
        Check("第 " .. (i + 1) .. " 次显示后立刻可见", bar.activeSelf == true)
    end
    -- 最后一次是 t=0.8，理论上要亮到 t=3.8（再滑出 0.16）
    AdvanceTo(3.7)
    Check("t=3.7 仍在显示（不能被 t=3.0 的旧定时器关掉）", bar.activeSelf == true)
    AdvanceTo(4.15)
    Check("t=4.15 已按时滑出并收起", bar.activeSelf == false)
end

print("== ② 停留时长按真实秒算，不受 3 倍速影响 ==")
do
    local bar = NewBar(1)
    BattlePanel:ShowSkillBar(bar, "enemyRect_SkillTimer")
    AdvanceTo(now + 2.5)
    Check("3 倍速下 t=2.5 仍在显示（缩放计时会在 t=1.0 就关掉）", bar.activeSelf == true)
    AdvanceTo(now + 1.0)
    Check("3 倍速下 t=3.5 已收起", bar.activeSelf == false)
end

print("== ③ 敌我两条互不干扰 ==")
do
    local mine, enemy = NewBar(0), NewBar(1)
    BattlePanel:ShowSkillBar(mine, "myRect_SkillTimer")
    Advance(0.5)
    BattlePanel:ShowSkillBar(enemy, "enemyRect_SkillTimer")
    Advance(2.75)   -- 我方到点（3.0）并滑完（3.16），敌方还差 0.25 秒
    Check("我方已收起", mine.activeSelf == false)
    Check("敌方仍在显示", enemy.activeSelf == true)
end

print("== ④ 节点已被销毁时定时器不炸 ==")
do
    local bar = NewBar(0)
    BattlePanel:ShowSkillBar(bar, "myRect_SkillTimer")
    bar.__null = true   -- 模拟 GameObject 已被 Destroy
    local ok = pcall(function() AdvanceTo(now + 4) end)
    Check("销毁后回调不报错", ok)
end

print("== ⑤ 收场：先横向滑出屏幕（0.16s）再关，并通知小卡一起关 ==")
do
    Advance(4)   -- 让前面几组残留的定时器/补间都跑完
    local hiddenCamp, hiddenCount = nil, 0
    BattleUltCard.OnBarHidden = function(camp)
        hiddenCamp, hiddenCount = camp, hiddenCount + 1
    end

    local mine = NewBar(0)
    BattlePanel:ShowSkillBar(mine, "myRect_SkillTimer")   -- 我方
    AdvanceTo(now + 3.05)                                 -- 刚过 3 秒，正在滑
    Check("到点后不是立刻关，而是先开始滑", mine.activeSelf == true)
    Check("滑动中已经在往屏幕外（左）移动", mine.rt.localPosition.x < -540,
        string.format("x=%.1f", mine.rt.localPosition.x))

    Advance(0.2)
    Check("滑完才关掉节点", mine.activeSelf == false)
    Check("我方滑出距离 = 静止位 -700（整条出屏）", Near(mine.rt.localPosition.x, -1240, 1),
        string.format("x=%.1f", mine.rt.localPosition.x))
    Check("通知小卡一起关（camp=0）", hiddenCount == 1 and hiddenCamp == 0,
        string.format("count=%s camp=%s", tostring(hiddenCount), tostring(hiddenCamp)))

    hiddenCount, hiddenCamp = 0, nil
    local enemy = NewBar(1)
    BattlePanel:ShowSkillBar(enemy, "enemyRect_SkillTimer")
    AdvanceTo(now + 3.2)
    Check("敌方往右滑出（镜像方向）", Near(enemy.rt.localPosition.x, 1240, 1),
        string.format("x=%.1f", enemy.rt.localPosition.x))
    Check("敌方滑完才关", enemy.activeSelf == false)
    Check("通知小卡一起关（camp=1）", hiddenCount == 1 and hiddenCamp == 1,
        string.format("count=%s camp=%s", tostring(hiddenCount), tostring(hiddenCamp)))
end

print("== ⑥ 收场滑到一半又放技能：不关节点、位置回到静止位 ==")
do
    Advance(4)
    local bar = NewBar(0)
    BattlePanel:ShowSkillBar(bar, "myRect_SkillTimer")
    AdvanceTo(now + 3.05)
    Check("先确认在滑出中", bar.rt.localPosition.x < -540)

    BattlePanel:ShowSkillBar(bar, "myRect_SkillTimer")     -- 0.05 秒后又放了一次
    Check("被打断后仍然显示", bar.activeSelf == true)
    Check("位置回到静止位（不然会越放越偏）", Near(bar.rt.localPosition.x, -540, 0.5),
        string.format("x=%.1f", bar.rt.localPosition.x))

    Advance(0.5)
    Check("被掐掉的旧滑出不会再关节点", bar.activeSelf == true)
    Advance(3.0)
    Check("新的停留时间到点后照常收场", bar.activeSelf == false)
end

print("")
if failures == 0 then
    print("ALL PASS")
else
    print(failures .. " FAILED")
    os.exit(1)
end
