-- 探索/寻宝入口红点「亮但无奖可领」回归测试（不依赖 Unity，直接 lua 跑）
--
-- 用法：
--   TS_ROOT=. lua scripts/lua-tests/test_findtreasure_redpoint.lua
--
-- 背景（2026-10-22 线上表现）：
--   UIRoot/.../FightPointPassMainPanel/Bg/RightUpVertical/btnFindTreasure/redPoint 常亮，
--   点进 FindTreasureMainPanel 却没有任何「领取」按钮。
--
-- 根因：
--   FindTreasureManager.RefreshFindTreasureRedPoint 有三个 return true 分支，只有第一个
--   （missionInfo[i].state == 1）在面板里有对应 UI（getButton）。另两个是假阳性：
--     ② BagManager.GetItemCountById(79 情报) >= PlayerLevelConfig.MazeTreasureMax
--        —— 面板里只有派遣/刷新，没有「领取」
--     ③ isShowFindTreasureVipRedPoint 模块级变量，加载即 true、不落盘不按天重置
--        —— 落点 FindTreasureVipPopup -> JumpManager.GoJump -> MainRechargePanel（充值页）
--   日志定案：19:32:26 玩家点 VIP 按钮把 ③ 置 false 后紧接着 CheckRedPointStatus(1093)
--   仍 func_result=true ⇒ 亮的是 ②；而面板无领奖按钮 ⇒ 就是 ② 在骗人。
--
-- 覆盖：
--   ① 红点只认 state == 1，与 getButton 显隐同口径
--   ② 情报满但无任务可领 → 必须 false
--   ③ VIP 引导不再影响入口红点
--   ④ VIP 引导本身按账号 + 按天（服务器 5 点）只亮一次
--   ⑤ 任务数据未下发时 SetFindTreasureDataState 不抛错（旧代码 pairs(nil) 会被 pcall 吞成 func_result=nil）

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

ConfigName = {
    MazeTreasureSetting = "MazeTreasureSetting",
    PlayerLevelConfig = "PlayerLevelConfig",
    AchievementConfig = "AchievementConfig",
}

local mazeTreasureSetting = { TakeOrder = { 83 }, RefreshVIP = 1, RefreshItem = { 80 } }
ConfigManager = {
    GetConfig = function(name)
        if name == ConfigName.AchievementConfig then return {} end
        return {}
    end,
    GetConfigData = function(name, id)
        if name == ConfigName.MazeTreasureSetting then return mazeTreasureSetting end
        if name == ConfigName.PlayerLevelConfig then return { MazeTreasureMax = 18000 } end
        return nil
    end,
}

TaskTypeDef = { FindTreasure = 7 }

FUNCTION_OPEN_TYPE = { FINDTREASURE = 39 }

RedPointType = { SecretTer_FindTreasure = 1093 }

GameEvent = {
    FiveAMRefresh = { ServerNotifyRefresh = "FiveAMRefresh.ServerNotifyRefresh" },
    FindTreasure = {
        RefreshFindTreasureRedPot = "FindTreasure.RefreshFindTreasureRedPot",
        RefreshFindTreasure = "FindTreasure.RefreshFindTreasure",
    },
}

local dispatched = {}
Game = {
    GlobalEvent = {
        AddEvent = function(_, name, fn) end,
        RemoveEvent = function(_, name, fn) end,
        DispatchEvent = function(_, name) dispatched[name] = (dispatched[name] or 0) + 1 end,
    },
}

local funcOpen = true
ActTimeCtrlManager = {
    SingleFuncState = function(t) return funcOpen end,
}

local checkRedPointCalls = 0
CheckRedPointStatus = function(t) checkRedPointCalls = checkRedPointCalls + 1 end

-- PlayerPrefs 桩：只实现本用例用到的四个接口
local prefStore = {}
PlayerPrefs = {
    GetString = function(k, d) local v = prefStore[k]; if v == nil then return d end; return v end,
    SetString = function(k, v) prefStore[k] = v end,
    GetInt = function(k, d) local v = prefStore[k]; if v == nil then return d end; return tonumber(v) end,
    SetInt = function(k, v) prefStore[k] = tostring(v) end,
    DeleteKey = function(k) prefStore[k] = nil end,
}

local NOW = 1761135000 -- 2026-10-22 19:30 附近
PlayerManager = { uid = 10001, level = 1, serverTime = NOW }
GetTimeStamp = function() return NOW end
PrivilegeManager = { GetPrivilegeUsedTimes = function() return 0 end }

----------------------------------------------------------------------
-- 2) 加载被测模块（真实文件）
----------------------------------------------------------------------
dofile(LUA_SRC .. "/Modules/Task/TaskManager.lua")
dofile(LUA_SRC .. "/Modules/FindTreasure/FindTreasureManager.lua")

local TM = TaskManager
local FTM = FindTreasureManager

----------------------------------------------------------------------
-- 3) ⑤ 任务数据未下发：SetFindTreasureDataState 必须静默返回
----------------------------------------------------------------------
print("[1] 任务数据未下发时 SetFindTreasureDataState 不抛错")
local ok1, err1 = pcall(TM.SetFindTreasureDataState)
Check(ok1, "pairs(nil) 已加 guard（err=" .. tostring(err1) .. "）")

print("[2] 任务数据未下发时 RefreshFindTreasureRedPoint 返回 false 而不是报错")
local ok2, v2 = pcall(FTM.RefreshFindTreasureRedPoint)
Check(ok2 and v2 == false, "返回 false（ok=" .. tostring(ok2) .. " v=" .. tostring(v2) .. "）")

----------------------------------------------------------------------
-- 4) 灌任务数据
----------------------------------------------------------------------
local function SetTasks(list)
    TM.SetTypeTaskList(TaskTypeDef.FindTreasure, list)
end

----------------------------------------------------------------------
-- 5) ① 可领任务 → true
----------------------------------------------------------------------
print("[3] 有 state==1 可领任务 → 红点亮")
SetTasks({
    { missionId = 40001, progress = 0, state = 1, type = 1, takeTimes = 0, heroId = { 1 } },
})
Check(FTM.RefreshFindTreasureRedPoint() == true, "state==1 返回 true")

print("[4] 只有已派遣未到期（state==0）→ 红点灭")
SetTasks({
    { missionId = 40001, progress = NOW + 600, state = 0, type = 1, takeTimes = 0, heroId = { 1 } },
})
Check(FTM.RefreshFindTreasureRedPoint() == false, "state==0 未到期返回 false")

print("[5] 已派遣且到期（state==0 但 progress 已过）→ 本地推进成 1，红点亮")
SetTasks({
    { missionId = 40001, progress = NOW - 60, state = 0, type = 1, takeTimes = 0, heroId = { 1 } },
})
Check(FTM.RefreshFindTreasureRedPoint() == true, "到期由 SetFindTreasureDataState 推进为 1")

print("[6] 全部已领取（state==2）→ 红点灭")
SetTasks({
    { missionId = 40001, progress = NOW - 60, state = 2, type = 1, takeTimes = 1, heroId = {} },
})
Check(FTM.RefreshFindTreasureRedPoint() == false, "state==2 返回 false")

----------------------------------------------------------------------
-- 6) ② 情报满不再点亮红点（回归：这次线上就是它）
----------------------------------------------------------------------
print("[7] 情报已达上限但无任务可领 → 红点必须灭（原分支 2 已移除）")
local bagNum = 99999 -- >= MazeTreasureMax 18000
BagManager = { GetItemCountById = function(id) return bagNum end }
SetTasks({
    { missionId = 40001, progress = 0, state = 2, type = 1, takeTimes = 1, heroId = {} },
})
Check(FTM.RefreshFindTreasureRedPoint() == false, "情报满(99999/18000) 且无可领任务 → false")

print("[8] 情报满 + 有可领任务 → 仍然亮（该亮的还是亮）")
SetTasks({
    { missionId = 40001, progress = 0, state = 1, type = 1, takeTimes = 0, heroId = { 1 } },
})
Check(FTM.RefreshFindTreasureRedPoint() == true, "情报满 + state==1 → true")

print("[9] 功能未开启 → 红点灭")
funcOpen = false
Check(FTM.RefreshFindTreasureRedPoint() == false, "SingleFuncState=false → false")
funcOpen = true

----------------------------------------------------------------------
-- 7) ③ VIP 引导与入口红点解耦 + ④ 按天只亮一次
----------------------------------------------------------------------
print("[10] VIP 引导默认未看过 → true（首次进面板仍会看到那颗引导红点）")
prefStore = {}
Check(FTM.GetShowFindTreasureVipRedPoint() == true, "首次 GetShow 返回 true")

print("[11] VIP 引导不再影响入口红点")
SetTasks({
    { missionId = 40001, progress = 0, state = 2, type = 1, takeTimes = 1, heroId = {} },
})
Check(FTM.GetShowFindTreasureVipRedPoint() == true and FTM.RefreshFindTreasureRedPoint() == false,
    "GetShow=true 但入口红点=false（已解耦）")

print("[12] 点过 VIP 按钮后当天不再亮")
FTM.SetShowFindTreasureVipRedPoint(false)
Check(FTM.GetShowFindTreasureVipRedPoint() == false, "置 false 后同一天返回 false")

print("[13] 跨天（+86400s）后重新亮一次")
PlayerManager.serverTime = NOW + 86400
Check(FTM.GetShowFindTreasureVipRedPoint() == true, "跨天后返回 true")
PlayerManager.serverTime = NOW

print("[14] 5 点边界：凌晨 4:59 仍算前一天，5:01 算新一天")
-- NOW 当天的游戏日序号 D 与它的 5:00 起点
local D = math.floor((NOW - 5 * 3600) / 86400)
local dayStart = D * 86400 + 5 * 3600
-- 玩家在前一天（D-1）看过
prefStore = { [tostring(10001) .. "FindTreasureVipRed"] = tostring(D - 1) }
PlayerManager.serverTime = dayStart - 60 -- 04:59，仍属 D-1
Check(FTM.GetShowFindTreasureVipRedPoint() == false, "04:59 仍属前一天 D-1 → false")
PlayerManager.serverTime = dayStart + 60 -- 05:01，进入 D
Check(FTM.GetShowFindTreasureVipRedPoint() == true, "05:01 属新一天 D → true")
PlayerManager.serverTime = NOW

print("[15] SetShowFindTreasureVipRedPoint 会派发面板刷新事件")
dispatched = {}
FTM.SetShowFindTreasureVipRedPoint(false)
Check((dispatched[GameEvent.FindTreasure.RefreshFindTreasureRedPot] or 0) == 1,
    "DispatchEvent(RefreshFindTreasureRedPot) 被调用一次")

----------------------------------------------------------------------
print("")
if failed == 0 then
    print("ALL PASS")
    os.exit(0)
else
    print(string.format("%d FAILED", failed))
    os.exit(1)
end
