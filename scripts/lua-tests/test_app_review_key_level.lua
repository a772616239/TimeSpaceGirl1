-- 诱导评分（Google Play 内评价）关键关卡弹窗闸门测试（不依赖 Unity，luajit 直跑）
--
-- 被测对象：Assets/ManagedResources/~Lua/Common/functions.lua 末尾的
--   AppReview_TryShowOnKeyLevel / AppReview_IsKeyLevelDone
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_app_review_key_level.lua

local ROOT = os.getenv("TS_ROOT") or "../../.."
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

-- 服务器时间可控（冷却用服务器时间，这里模拟推进）
PlayerManager = { uid = 10000004, serverTime = 1700000000 }

-- 平台桩：默认 Android
UnityEngine = {
    Application = { platform = "Android" },
    RuntimePlatform = { Android = "Android", IPhonePlayer = "iPhonePlayer" },
}

local reviewCalls = 0
ReviewMgr = {
    AllInOneFlowClick = function(self) reviewCalls = reviewCalls + 1 end,
}

-- functions.lua 顶层只有函数定义，无副作用，可安全整文件加载
assert(loadfile(LUA_SRC .. "/Common/functions.lua"))()
assert(type(AppReview_TryShowOnKeyLevel) == "function", "AppReview_TryShowOnKeyLevel 未定义")

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

print("\n[1] 首次命中关键关卡 → 弹")
do
    reviewCalls = 0
    local shown = AppReview_TryShowOnKeyLevel("climb_tower_10")
    check("返回 true", shown == true)
    check("底层被调用一次", reviewCalls == 1, reviewCalls)
    check("key 已登记", AppReview_IsKeyLevelDone("climb_tower_10") == true)
end

print("\n[2] 同一条关键关卡只弹一次")
do
    reviewCalls = 0
    local shown = AppReview_TryShowOnKeyLevel("climb_tower_10")
    check("返回 false", shown == false)
    check("没有再调用底层", reviewCalls == 0, reviewCalls)
end

print("\n[3] 24h 冷却：换一条关键关卡也拦住")
do
    reviewCalls = 0
    PlayerManager.serverTime = PlayerManager.serverTime + 3600 -- 只过 1 小时
    local shown = AppReview_TryShowOnKeyLevel("daily_carbon_1")
    check("1 小时后返回 false", shown == false)
    check("底层未被调用", reviewCalls == 0, reviewCalls)
    check("该 key 未被误登记", AppReview_IsKeyLevelDone("daily_carbon_1") == false)
end

print("\n[4] 冷却到期 → 可以再弹，且合计次数累加")
do
    reviewCalls = 0
    PlayerManager.serverTime = PlayerManager.serverTime + DAY
    local shown = AppReview_TryShowOnKeyLevel("daily_carbon_1")
    check("返回 true", shown == true)
    check("底层被调用一次", reviewCalls == 1, reviewCalls)
end

print("\n[5] 累计 3 次上限")
do
    reviewCalls = 0
    PlayerManager.serverTime = PlayerManager.serverTime + DAY
    local shown = AppReview_TryShowOnKeyLevel("climb_tower_20")
    check("第 3 次仍可弹", shown == true)
    check("底层被调用一次", reviewCalls == 1, reviewCalls)

    reviewCalls = 0
    PlayerManager.serverTime = PlayerManager.serverTime + DAY
    local shown2 = AppReview_TryShowOnKeyLevel("climb_tower_30")
    check("第 4 次被上限拦住", shown2 == false)
    check("底层未被调用", reviewCalls == 0, reviewCalls)
    check("被拦的 key 未登记", AppReview_IsKeyLevelDone("climb_tower_30") == false)
end

print("\n[6] 非 Android 平台不弹（不走 Play 内评价）")
do
    -- 换账号，绕开上面的历史计数
    PlayerManager.uid = 10000005
    PlayerManager.serverTime = PlayerManager.serverTime + DAY
    UnityEngine.Application.platform = "iPhonePlayer"
    reviewCalls = 0
    local shown = AppReview_TryShowOnKeyLevel("climb_tower_10")
    check("iOS 返回 false", shown == false)
    check("底层未被调用", reviewCalls == 0, reviewCalls)
    UnityEngine.Application.platform = "Android"
end

print("\n[7] 计数按 uid 隔离，不串号")
do
    reviewCalls = 0
    PlayerManager.serverTime = PlayerManager.serverTime + DAY
    local shown = AppReview_TryShowOnKeyLevel("climb_tower_10")
    check("新账号同 key 仍可弹", shown == true)
    check("底层被调用一次", reviewCalls == 1, reviewCalls)
end

print("\n[8] nil key 安全")
do
    reviewCalls = 0
    local shown = AppReview_TryShowOnKeyLevel(nil)
    check("返回 false 不报错", shown == false)
    check("底层未被调用", reviewCalls == 0, reviewCalls)
end

print(string.format("\n== 结果：%d 通过 / %d 失败 ==", pass, fail))
if fail > 0 then
    os.exit(1)
end
