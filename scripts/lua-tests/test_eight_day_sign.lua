-- 八日礼包签到制测试（不依赖 Unity，lua 直跑）
--
-- 被测对象：Assets/ManagedResources/~Lua/Common/functions.lua 末尾的
--   EightDaySignTodayZero / EightDaySignTodayIndex / EightDaySignHasSignedToday
--   EightDaySignMarkSigned / EightDaySignProgress / EightDaySignCanRewardDay
--
-- 覆盖的规则（活动 Type = 56 EightDayGift）：
--   1. 天数只由玩家主动签到推进，不再跟建号自然日绑定；
--   2. 每天最多签一次（按服务器时间的自然日判重）；
--   3. 允许断签：断签不重置、不补签，回来接着上一次继续 +1；
--   4. 离线期间天数不动。
--
-- 用法：
--   cd <repo>
--   lua scripts/lua-tests/test_eight_day_sign.lua

local ROOT = os.getenv("TS_ROOT") or (os.getenv("PWD") or ".")
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ---- 最小环境桩 ----
local logs = {}
Log = function(s) table.insert(logs, tostring(s)) end
LogError = Log
LogWarn = Log

local prefs = {}
PlayerPrefs = {
    GetString = function(k, d) local v = prefs[k]; if v == nil then return d end; return v end,
    SetString = function(k, v) prefs[k] = tostring(v) end,
    GetInt = function(k, d) local v = prefs[k]; if v == nil then return d end; return v end,
    SetInt = function(k, v) prefs[k] = v end,
    Save = function() end,
}

-- 服务器时间可控（签到按服务器时间的自然日判重）
PlayerManager = { uid = 10000004, serverTime = 1700000000 }

-- functions.lua 顶层只有函数定义，无副作用，可安全整文件加载
assert(loadfile(LUA_SRC .. "/Common/functions.lua"))()
assert(type(EightDaySignProgress) == "function", "EightDaySignProgress 未定义")
assert(type(EightDaySignMarkSigned) == "function", "EightDaySignMarkSigned 未定义")

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

local DAY = 24 * 3600

-- 造一份「8 天全部未领」的服务端 activityInfo
local function makeActivity(states, startId)
    local mission = {}
    for i = 1, 8 do
        mission[i] = { missionId = (startId or 1) + i - 1, state = (states and states[i]) or 0, progress = 0 }
    end
    return { activityId = 56, mission = mission }
end

-- 跨天
local function nextDay()
    PlayerManager.serverTime = PlayerManager.serverTime + DAY
end

print("\n[1] 全新账号：第 1 天可签，离线多久都不会自己涨")
do
    local act = makeActivity()
    local d, signed, canSign = EightDaySignProgress(act)
    check("nextDay = 1", d == 1, d)
    check("signedDays = 0", signed == 0, signed)
    check("今天可签", canSign == true)
    check("可领天数 = 1", EightDaySignCanRewardDay(act) == 1, EightDaySignCanRewardDay(act))

    -- 离线 10 天：状态没变（没有服务端 state 变化），天数不能自己涨
    for i = 1, 10 do nextDay() end
    local d2, _, canSign2 = EightDaySignProgress(act)
    check("离线 10 天后 nextDay 仍是 1（不再按自然日推进）", d2 == 1, d2)
    check("离线回来仍可签", canSign2 == true)
end

print("\n[2] 每天最多签一次")
do
    EightDaySignMarkSigned()
    check("今天已签到", EightDaySignHasSignedToday() == true)
    local act = makeActivity()
    local _, _, canSign = EightDaySignProgress(act)
    check("同一天不能再签", canSign == false)
    check("同一天可领天数回到 0", EightDaySignCanRewardDay(act) == 0, EightDaySignCanRewardDay(act))
end

print("\n[3] 领到第 1 天后再签到 → 推进到第 2 天")
do
    nextDay()
    local act = makeActivity({ 1 })-- 第 1 天已领
    local d, signed, canSign = EightDaySignProgress(act)
    check("nextDay = 2", d == 2, d)
    check("signedDays = 1", signed == 1, signed)
    check("新的一天可签", canSign == true)
    EightDaySignMarkSigned()
    local _, _, canSignAfter = EightDaySignProgress(act)
    check("签到后当天不可再签", canSignAfter == false)
end

print("\n[4] 断签：漏签 5 天回来，进度继续而不是重置/补签")
do
    local act = makeActivity({ 1 })-- 仍然只领了第 1 天
    for i = 1, 5 do nextDay() end
    local d, signed, canSign = EightDaySignProgress(act)
    check("nextDay 仍是 2（没补签、没重置）", d == 2, d)
    check("signedDays 仍是 1（断签不扣天数）", signed == 1, signed)
    check("回来可以续签一天", canSign == true)
    check("一次只能领 1 天（可领天数 = 2）", EightDaySignCanRewardDay(act) == 2, EightDaySignCanRewardDay(act))
end

print("\n[5] 全部领完 → 不能签")
do
    local act = makeActivity({ 1, 1, 1, 1, 1, 1, 1, 1 })
    local d, signed, canSign = EightDaySignProgress(act)
    check("nextDay = 9（越过最后一天）", d == 9, d)
    check("signedDays = 8", signed == 8, signed)
    check("不可再签", canSign == false)
    check("可领天数 = 8", EightDaySignCanRewardDay(act) == 8, EightDaySignCanRewardDay(act))
end

print("\n[6] 旧数据乱序（跳过了第 2 天）：从第一个没领的那天补")
do
    local act = makeActivity({ 1, 0, 1, 1 })
    local d, _, canSign = EightDaySignProgress(act)
    check("nextDay 指到第一个没领的第 2 天", d == 2, d)
    check("可以签", canSign == true)
end

print("\n[7] 缺数据兜底")
do
    local d, signed, canSign = EightDaySignProgress(nil)
    check("nil 数据 → nextDay 1 / 不可签", d == 1 and signed == 0 and canSign == false)
    d, signed, canSign = EightDaySignProgress({ mission = {} })
    check("空 mission → nextDay 1 / 不可签", d == 1 and signed == 0 and canSign == false)
end

print("\n[8] 签到日期按 uid 隔离")
do
    nextDay()
    EightDaySignMarkSigned()
    local uidA = PlayerManager.uid
    check("A 号已签到", EightDaySignHasSignedToday() == true)
    PlayerManager.uid = 99999999
    check("B 号没签到记录（不串号）", EightDaySignHasSignedToday() == false)
    PlayerManager.uid = uidA
    check("切回 A 号记录还在", EightDaySignHasSignedToday() == true)
end

print(string.format("\n结果：%d 通过 / %d 失败\n", pass, fail))
if fail > 0 then os.exit(1) end
