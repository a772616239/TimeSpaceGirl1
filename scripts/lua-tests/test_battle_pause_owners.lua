-- 战斗暂停锁（多源暂停 / 反复切暂停）回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   TS_ROOT=. lua scripts/lua-tests/test_battle_pause_owners.lua
--   或：cd LuaEncoder/luajit_mac/64 && TS_ROOT=../../.. ./luajit ../../../scripts/lua-tests/test_battle_pause_owners.lua
--
-- 背景（2026-10-22）：
--   战斗暂停原来是 BattleManager 里的 IsPlay 三态（0 停战 / 1 播放 / 2 暂停），
--   PauseBattle / ResumeBattle 都是幂等的「置位」。全项目 15+ 个暂停源共用这一个布尔位：
--   回合剧情、助战/替补入场、大招特写、技能 PV、战斗位移、支援/副官/航母演出、宠物技、
--   新手引导、退出确认、结算。于是必然出现两类症状：
--     ① 该停的没停：A 暂停中，B 也暂停（被吞），B 先 Resume ⇒ 战斗在 A 的演出下继续跑；
--     ② 该恢复的停死：Resume 挂在 tween / DelayFunc 的 OnComplete 上，单位中途被移除
--        （阵亡/替补/战斗结束）时回调永不执行 ⇒ 永久暂停，只能重开战斗。
--   典型复现：战斗中反复点「退出」（btnExit）—— 每次点击都 PauseBattle + ShowTwo，
--   上一份 cancelFunc 被顶掉，它那把锁永远放不掉；旧倒计时还在跑，31s 后自动退出战斗。
--
-- 覆盖：
--   A. 锁本体：嵌套、同源重复上锁、未知源释放、强放、Stop 清场、反复切平衡、OwnerStr
--   B. BattleManager 代理：IsPlay 镜像、反复点退出、StopBattle 清锁、看门狗红字

local ROOT = os.getenv("TS_ROOT") or "."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"

local failed = 0
local function Check(cond, msg)
    if cond then
        print("  [PASS] " .. msg)
    else
        failed = failed + 1
        print("  [FAIL] " .. msg)
    end
end

----------------------------------------------------------------------
-- 1) 全局桩
----------------------------------------------------------------------
package.path = LUA_SRC .. "/?.lua;" .. package.path

ConfigName = setmetatable({}, { __index = function(_, k) return k end })
ConfigManager = {
    GetConfig = function() return {} end,
    GetConfigData = function() return nil end,
}

local logLines = {}
local function PushLog(msg)
    logLines[#logLines + 1] = tostring(msg)
end
Log = PushLog
LogError = PushLog
LogRed = PushLog

-- Timer 桩：只记录注册的 timer，回调由用例手动 tick（看门狗用例要用）
local timers = {}
Timer = {}
function Timer.New(func, duration, loop, unscaled)
    local t = { func = func, duration = duration, loop = loop, unscaled = unscaled, running = false }
    function t:Start()
        self.running = true
        timers[#timers + 1] = self
    end
    function t:Stop()
        self.running = false
    end
    return t
end
Time = { realtimeSinceStartup = 0 }

local BattlePauseLock = require("Modules/Battle/BattlePauseLock")
require("Modules/Battle/BattleManager")
local BM = BattleManager

local function NewLock()
    return BattlePauseLock.New()
end

----------------------------------------------------------------------
-- A. 锁本体
----------------------------------------------------------------------
print("[A1] 新建锁 = 停战态，不可操作")
local l = NewLock()
Check(l:GetState() == 0 and l:IsPlaying() == false and l:IsCanOperate() == false,
    "state=" .. tostring(l:GetState()))

print("[A2] 未开战时上锁被忽略（与旧 PauseBattle 只在 IsPlay==1 生效一致）")
Check(l:Pause("guide") == false and l:GetState() == 0 and l:OwnerCount() == 0,
    "state=" .. tostring(l:GetState()) .. " owners=" .. tostring(l:OwnerCount()))

print("[A3] 开战 → 暂停 → 恢复")
l:Start()
Check(l:IsPlaying() and l:IsCanOperate(), "Start 后应为播放且可操作")
l:Pause("guide")
Check(l:IsPaused() and not l:IsPlaying(), "Pause 后应为暂停")
l:Resume("guide")
Check(l:IsPlaying(), "唯一源释放后应恢复播放")

print("[A4] 嵌套：A 暂停中 B 也暂停，B 先释放不能把战斗放跑（旧实现的核心 bug）")
l:Pause("guide")
l:Pause("story")
Check(l:IsPaused(), "两个源都在，应为暂停")
l:Resume("story")
Check(l:IsPaused() and l:GetOwnerCount("guide") == 1,
    "story 释放后 guide 仍持锁 ⇒ 必须还是暂停，owners=" .. l:OwnersStr())
l:Resume("guide")
Check(l:IsPlaying(), "全部释放后才恢复")

print("[A5] 同一 owner 上锁 N 次要释放 N 次（反复触发同一演出不会一放全放）")
l:Pause("closeup")
l:Pause("closeup")
Check(l:GetOwnerCount("closeup") == 2, "计数=" .. tostring(l:GetOwnerCount("closeup")))
l:Resume("closeup")
Check(l:IsPaused(), "只释放一次仍应暂停")
l:Resume("closeup")
Check(l:IsPlaying(), "释放两次才恢复")

print("[A6] 释放未持有的 owner：不改状态、返回 false")
l:Pause("guide")
Check(l:Resume("not_exist") == false and l:IsPaused(), "未知源释放应无效")
l:Resume("guide")

print("[A7] ReleaseOwner 强放（tween/timer 被 Kill、单位 Dispose 的兜底）")
l:Pause("role:0x1:fight_move")
l:Pause("role:0x1:closeup")
Check(l:IsPaused() and l:OwnerCount() == 2, "owners=" .. l:OwnersStr())
l:ReleaseOwner("role:0x1:fight_move")
Check(l:IsPaused() and l:OwnerCount() == 1, "强放一个后仍暂停")
l:ReleaseOwner("role:0x1:closeup")
Check(l:IsPlaying(), "强放全部后恢复")

print("[A8] ReleaseOwnerPrefix 批量强放（单位 Dispose 一次清干净）")
l:Pause("role:0x1:fight_move")
l:Pause("role:0x1:pv")
l:Pause("guide")
Check(l:OwnerCount() == 3, "owners=" .. l:OwnersStr())
local n = l:ReleaseOwnerPrefix("role:0x1:")
Check(n == 2 and l:GetOwnerCount("guide") == 1 and l:IsPaused(),
    "只清掉本单位的两把，guide 仍持锁，n=" .. tostring(n))
l:Resume("guide")

print("[A9] Stop 清场：锁全清、状态归 0，且再 Pause 无效")
l:Pause("guide")
l:Stop()
Check(l:GetState() == 0 and l:OwnerCount() == 0, "Stop 后 owners=" .. l:OwnersStr())
Check(l:Pause("guide") == false and l:GetState() == 0, "停战后上锁应被忽略")
l:Start()
Check(l:IsPlaying(), "重新开战从干净状态开始")

print("[A10] 反复切 200 次（同源 pause/resume 配对）后必须回到播放且无残留")
for _ = 1, 200 do
    l:Pause("exit_confirm")
    l:Resume("exit_confirm")
end
Check(l:IsPlaying() and l:OwnerCount() == 0,
    "state=" .. tostring(l:GetState()) .. " owners=" .. l:OwnersStr())

print("[A11] 三源交错 100 轮，任意顺序释放后仍能正确收敛")
for i = 1, 100 do
    l:Pause("guide")
    l:Pause("story")
    l:Pause("fight_move")
    if i % 3 == 0 then
        l:Resume("story"); l:Resume("guide"); l:Resume("fight_move")
    elseif i % 3 == 1 then
        l:Resume("fight_move"); l:Resume("story"); l:Resume("guide")
    else
        l:Resume("guide"); l:Resume("fight_move"); l:Resume("story")
    end
    if not l:IsPlaying() or l:OwnerCount() ~= 0 then
        break
    end
end
Check(l:IsPlaying() and l:OwnerCount() == 0, "state=" .. tostring(l:GetState()))

print("[A12] 漏一次 Resume（模拟 tween 被 Kill）→ 保持暂停；强放后恢复")
l:Pause("fight_move")
l:Pause("closeup")
l:Resume("closeup")            -- closeup 正常收尾
-- fight_move 的 OnComplete 永远不来了
Check(l:IsPaused(), "仍应暂停，owners=" .. l:OwnersStr())
l:ReleaseOwner("fight_move")
Check(l:IsPlaying(), "强放漏掉的那把后恢复")

print("[A13] OwnersStr 输出顺序与计数")
l:Pause("guide")
l:Pause("guide")
l:Pause("story")
Check(l:OwnersStr() == "guide x2, story", "实际=" .. l:OwnersStr())
l:Stop()

----------------------------------------------------------------------
-- B. BattleManager 代理
----------------------------------------------------------------------
print("[B1] StopBattle → StartBattle 的镜像与初始态")
BM.StopBattle()
Check(BM.IsPlay == 0 and BM.IsBattlePlaying() == false, "IsPlay=" .. tostring(BM.IsPlay))
BM.StartBattle()
Check(BM.IsPlay == 1 and BM.IsBattlePlaying() and BM.IsCanOperate(), "IsPlay=" .. tostring(BM.IsPlay))

print("[B2] 两个源交错：IsPlay 镜像跟着锁走")
BM.PauseBattle(BM.PAUSE_OWNER.STORY)
Check(BM.IsPlay == 2 and BM.IsBattlePaused(), "剧情暂停后 IsPlay=" .. tostring(BM.IsPlay))
BM.PauseBattle(BM.PAUSE_OWNER.GUIDE)
BM.ResumeBattle(BM.PAUSE_OWNER.STORY)
Check(BM.IsPlay == 2, "只释放剧情，引导还在 ⇒ 必须仍暂停，owners=" .. BM.GetPauseOwnersStr())
BM.ResumeBattle(BM.PAUSE_OWNER.GUIDE)
Check(BM.IsPlay == 1, "全部释放后 IsPlay=" .. tostring(BM.IsPlay))

print("[B3] 反复点退出：同源上锁两次只释放一次 → 仍暂停（旧实现会卡死在这里）")
BM.PauseBattle(BM.PAUSE_OWNER.EXIT_CONFIRM)
BM.PauseBattle(BM.PAUSE_OWNER.EXIT_CONFIRM)
BM.ResumeBattle(BM.PAUSE_OWNER.EXIT_CONFIRM)
Check(BM.IsPlay == 2, "还剩一把锁，IsPlay=" .. tostring(BM.IsPlay) .. " owners=" .. BM.GetPauseOwnersStr())
BM.ReleasePauseOwner(BM.PAUSE_OWNER.EXIT_CONFIRM)   -- 走退出流程：强放
Check(BM.IsPlay == 1, "强放后 IsPlay=" .. tostring(BM.IsPlay))

print("[B4] 战斗结束 StopBattle 必须把没释放的锁一起清掉，下一场不受影响")
BM.PauseBattle(BM.PAUSE_OWNER.CLOSEUP)
BM.PauseBattle(BM.PAUSE_OWNER.STORY)
BM.StopBattle()
Check(BM.IsPlay == 0 and BM.pauseLock:OwnerCount() == 0, "StopBattle 后 owners=" .. BM.GetPauseOwnersStr())
BM.StartBattle()
Check(BM.IsPlay == 1, "下一场开战应为播放，IsPlay=" .. tostring(BM.IsPlay))

print("[B5] 看门狗：暂停超时把「谁还持着锁」打红字，恢复后自动停")
logLines = {}
timers = {}
BM.StopBattle(); BM.StartBattle()
Time.realtimeSinceStartup = 0
BM.PauseBattle(BM.PAUSE_OWNER.GUIDE)
BM.PauseBattle(BM.PAUSE_OWNER.HELP_HERO)
Check(#timers == 1, "只应注册一个看门狗 timer，实际=" .. tostring(#timers))
Time.realtimeSinceStartup = 10
timers[1].func()
Check(#logLines == 0, "10s 未超阈值不应报警，log=" .. tostring(#logLines))
Time.realtimeSinceStartup = 46
timers[1].func()
local hit = false
for _, line in ipairs(logLines) do
    if string.find(line, "已暂停", 1, true) and string.find(line, "guide", 1, true)
        and string.find(line, "help_hero", 1, true) then
        hit = true
    end
end
Check(hit, "应报出未释放的源：" .. tostring(logLines[#logLines]))
BM.ResumeBattle(BM.PAUSE_OWNER.GUIDE)
BM.ResumeBattle(BM.PAUSE_OWNER.HELP_HERO)
Check(BM.IsPlay == 1 and BM.pauseWatchdog == nil, "恢复后看门狗应停止")

print("[B6] 停战态下 PauseBattle 返回 false 且不记账")
BM.StopBattle()
Check(BM.PauseBattle(BM.PAUSE_OWNER.GUIDE) == false and BM.pauseLock:OwnerCount() == 0,
    "owners=" .. BM.GetPauseOwnersStr())

print("[B7] 未指定 owner 的老调用落到 default，仍能配对释放")
BM.StartBattle()
BM.PauseBattle()
Check(BM.IsPlay == 2 and BM.pauseLock:HasOwner("default"), "owners=" .. BM.GetPauseOwnersStr())
BM.ResumeBattle()
Check(BM.IsPlay == 1, "IsPlay=" .. tostring(BM.IsPlay))
BM.StopBattle()

print("[B8] 切后台强放「演出型」锁，逻辑态锁（剧情/引导）必须保留")
BM.StartBattle()
BM.PauseBattle(BM.PAUSE_OWNER.CLOSEUP)          -- 大招特写（演出型）
BM.PauseBattle("role:0x1:pv")                   -- 技能 PV（演出型，每单位）
BM.PauseBattle(BM.PAUSE_OWNER.STORY)            -- 剧情（逻辑态）
local released = BM.ReleaseTransientPauseOwners("test")
Check(released == 2 and BM.IsPlay == 2 and BM.pauseLock:HasOwner(BM.PAUSE_OWNER.STORY),
    "released=" .. tostring(released) .. " owners=" .. BM.GetPauseOwnersStr())
BM.ResumeBattle(BM.PAUSE_OWNER.STORY)
Check(BM.IsPlay == 1, "剧情释放后应恢复，IsPlay=" .. tostring(BM.IsPlay))

print("[B9] 反复「切出→重进」10 轮（每轮都在演出中切出）不会把战斗按死")
for i = 1, 10 do
    BM.PauseBattle(BM.PAUSE_OWNER.CLOSEUP)
    BM.PauseBattle("role:0x" .. i .. ":fight_move")
    BM.ReleaseTransientPauseOwners("round" .. i)     -- btnFightBack 的动作
    if not BM.IsBattlePlaying() then
        break
    end
end
Check(BM.IsPlay == 1 and BM.pauseLock:OwnerCount() == 0,
    "IsPlay=" .. tostring(BM.IsPlay) .. " owners=" .. BM.GetPauseOwnersStr())
BM.StopBattle()

----------------------------------------------------------------------
print("")
if failed == 0 then
    print("ALL PASS")
    os.exit(0)
else
    print(string.format("%d FAILED", failed))
    os.exit(1)
end
