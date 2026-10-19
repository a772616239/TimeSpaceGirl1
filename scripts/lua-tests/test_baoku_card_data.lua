-- 易经宝库「卡位数据」回归测试（不依赖 Unity，直接用 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_baoku_card_data.lua
--
-- 背景：线上崩溃 YiJingBaoKu:171 attempt to index field '?' (a nil value)
--   服务器用 SubRewardPoolInfo.lay 下发 missionId=100 的 progress，活动未初始化时为 0 或整条缺失。
--   原实现直接 BasicPoolId[progress] 取池 ⇒ 取到 nil ⇒ 该层奖池查空 ⇒ initCardDatas 为空
--   ⇒ InitSetAllCard 第一次循环就索引 nil。
--
-- 覆盖点：
--   · 正常层数 1/3 → 卡片数与坑位一致（35 奖励 + 1 个空位 = 36）
--   · progress=0（未初始化）/ 整条记录缺失 / progress 越界 → 不抛异常，且卡片数仍为 36
--   · 第 18 位是空位（rewardId=0、reward=nil），用于放最终大奖展示
--   · 异常场景必须打 LogRed，便于线上定位「是服务器没初始化」而不是「客户端算错」

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ---- 最小环境桩 ----
local redLogs = {}
Log = function() end
LogRed = function(s) redLogs[#redLogs + 1] = tostring(s) end
LogGreen = Log
LogWarn = Log
LogError = Log
ConfigPairs = pairs
ConfigName = setmetatable({}, { __index = function(_, k) return k end })
ActivityTypeDef = { YiJingBaoKu = 30 }

local failCount = 0
local function check(name, cond, extra)
    if cond then
        print(string.format("  ✅ %s", name))
    else
        failCount = failCount + 1
        print(string.format("  ❌ %s %s", name, extra or ""))
    end
end

-- 与线上 BlessingRewardPoolNew 的 PoolId 1/2/3 一致：InitializeNum 合计 35
local INIT_NUMS = { 5, 5, 5, 1, 5, 10, 1, 3 }
local ACTIVITY_ID = 35004

local function poolRows(poolId)
    local list = {}
    for i, n in ipairs(INIT_NUMS) do
        list[i] = { Id = (poolId - 1) * 10 + i, PoolId = poolId, Reward = { 6000110, 500 }, InitializeNum = n }
    end
    return list
end

ConfigManager = {}
ConfigManager.GetConfig = function() return {} end
ConfigManager.GetConfigDataByKey = function(_, _, value)
    if value == ACTIVITY_ID then
        return { Id = 3, ActivityId = ACTIVITY_ID, FloorCount = 3, BasicPoolId = { 1, 2, 3 }, FinalPoolId = 8 }
    end
    return nil
end
ConfigManager.GetAllConfigsDataByKey = function(_, key, value)
    if key == "PoolId" and type(value) == "number" and value >= 1 and value <= 3 then
        return poolRows(value)
    end
    LogRed(string.format("表：BlessingRewardPoolNew|找不到字段：%s |值：%s", tostring(key), tostring(value)))
    return {}
end

local levelProgress
local function buildMission()
    local m = {}
    for i = 1, #INIT_NUMS do
        m[#m + 1] = { missionId = i, progress = 0 }
    end
    -- 35 张抽取记录之后是层数记录；"absent" 表示服务器压根没建
    if levelProgress ~= "absent" then
        m[#m + 1] = { missionId = 100, progress = levelProgress }
    end
    return m
end
ActivityGiftManager = {
    GetActivityTypeInfo = function()
        return { activityId = ACTIVITY_ID, mission = buildMission(), value = 0, endTime = 0 }
    end,
}

dofile(LUA_SRC .. "/Modules/DynamicActivity/DynamicActivityManager.lua")

-- ---- 用例 ----
local CASES = {
    { value = 1,        expectLevel = 1, expectRedLog = false, desc = "正常第 1 层" },
    { value = 3,        expectLevel = 3, expectRedLog = false, desc = "正常第 3 层" },
    { value = 0,        expectLevel = 1, expectRedLog = true,  desc = "progress=0（活动未初始化）" },
    { value = "absent", expectLevel = 1, expectRedLog = true,  desc = "层数记录整条缺失" },
    { value = 4,        expectLevel = 3, expectRedLog = true,  desc = "progress 越界（4 > FloorCount）" },
}

print("易经宝库卡片数据回归：")
for _, case in ipairs(CASES) do
    levelProgress = case.value
    redLogs = {}
    local ok, data = pcall(DynamicActivityManager.GetBaoKuData)
    print(string.format("· %s", case.desc))
    check("不抛异常", ok, tostring(data))
    if ok then
        check("卡片数 = 36（坑位对齐）", #data.initCardDatas == 36, "实际 " .. #data.initCardDatas)
        check("层数收敛到 " .. case.expectLevel, data.curLevel == case.expectLevel, "实际 " .. tostring(data.curLevel))
        check("奖池已定位", data.curBasicPool == case.expectLevel, "实际 " .. tostring(data.curBasicPool))
        local hole = data.initCardDatas[18]
        check("第 18 位是空位", hole and hole.rewardId == 0 and hole.reward == nil)
        local first = data.initCardDatas[1]
        check("第 1 位有奖励", first and first.rewardId ~= 0 and first.reward ~= nil)
        local hasRed = #redLogs > 0
        check(case.expectRedLog and "异常已打 LogRed" or "正常数据不打 LogRed", hasRed == case.expectRedLog)
    end
end

print("")
if failCount == 0 then
    print("全部通过")
    os.exit(0)
else
    print(string.format("失败 %d 项", failCount))
    os.exit(1)
end
