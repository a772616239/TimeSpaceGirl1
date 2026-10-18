-- 国家排行榜纯逻辑测试（不依赖 Unity，直接在 luajit 下跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_country_rank.lua

local ROOT = os.getenv("TS_ROOT") or "."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
-- 让模块里的 require("Modules/...") 能在仓库源码树里解析
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ---- 最小环境桩 ----
local logs, reds, errors = {}, {}, {}
Log = function(s) table.insert(logs, tostring(s)) end
LogRed = function(s) table.insert(reds, tostring(s)) end
LogError = function(s) table.insert(errors, tostring(s)) end
LogGreen = Log
LogWarn = Log
LogPink = Log
languageDic, languageDicStr = {}, {}

local lan = 0
function GetLan() return lan end
function GetLanguageStrById(id) return tostring(id) end
function GetLanguageStrByStr(zh)
    local d = languageDicStr[zh]
    if not d then return zh end
    return d[lan == 0 and "zh" or (lan == 1 and "en" or (lan == 2 and "jp" or "kr"))] or zh
end

local prefs = {}
PlayerPrefs = {
    GetString = function(k, d) local v = prefs[k]; if v == nil then return d end; return v end,
    SetString = function(k, v) prefs[k] = v end,
    GetInt = function(k, d) local v = prefs[k]; if v == nil then return d end; return v end,
    SetInt = function(k, v) prefs[k] = v end,
    Save = function() end,
}
PlayerManager = { uid = 123456, name = "Tester", lv = 88 }

-- ---- 载入被测模块 ----
assert(loadfile(LUA_SRC .. "/Modules/CountryRank/CountryConfig.lua"))()
assert(loadfile(LUA_SRC .. "/Modules/CountryRank/CountryRankManager.lua"))()

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

print("\n[1] 国家码规整")
do
    check("大写归一小写", CountryConfig.Normalize("CN") == "cn", CountryConfig.Normalize("CN"))
    check("空串落兜底", CountryConfig.Normalize("") == "xx")
    check("nil 落兜底", CountryConfig.Normalize(nil) == "xx")
    check("未知码落兜底", CountryConfig.Normalize("zz") == "xx")
    check("别名 uk→gb", CountryConfig.Normalize("uk") == "gb")
    check("已有码保持不变", CountryConfig.Normalize("jp") == "jp")
    check("带空格容错", CountryConfig.Normalize(" US ") == "us")
end

print("\n[2] 旗帜 sprite 与显示名")
do
    check("sprite 名拼接", CountryConfig.GetFlagSprite("jp") == "cn2-guoqi_jp",
            CountryConfig.GetFlagSprite("jp"))
    check("兜底 sprite", CountryConfig.GetFlagSprite("zz") == "cn2-guoqi_xx")
    lan = 0
    check("中文名", CountryConfig.GetName("cn") == "中国", CountryConfig.GetName("cn"))
    lan = 1
    check("英文名", CountryConfig.GetName("cn") == "China", CountryConfig.GetName("cn"))
    lan = 2
    check("日文名", CountryConfig.GetName("kr") == "韓国", CountryConfig.GetName("kr"))
    lan = 3
    check("韩文名", CountryConfig.GetName("jp") == "일본", CountryConfig.GetName("jp"))
    lan = 0
    check("未知码有显示名", CountryConfig.GetName("zz") == "其他地区", CountryConfig.GetName("zz"))
end

print("\n[3] 玩家国家的默认与优先级")
do
    prefs = {}
    check("都为空 → 兜底", CountryRankManager.GetPlayerCountry() == "xx",
            CountryRankManager.GetPlayerCountry())
    check("未选过国家", CountryRankManager.HasChosenCountry() == false)

    prefs.device_country = "jp"
    check("只有设备地区 → 用它", CountryRankManager.GetPlayerCountry() == "jp")

    prefs.player_country = "br"
    check("玩家自选优先于设备", CountryRankManager.GetPlayerCountry() == "br",
            CountryRankManager.GetPlayerCountry())
    check("已选过国家", CountryRankManager.HasChosenCountry() == true)

    CountryRankManager.SetPlayerCountry("KR")
    check("保存会规整大小写", prefs.player_country == "kr", prefs.player_country)
    check("换国家后本国榜失效重算", CountryRankManager._localRank == nil)
end

print("\n[4] 榜单生成与排序")
do
    prefs = { player_country = "cn" }
    CountryRankManager.Initialize()
    local all = CountryRankManager.GetRankList(CountryRankManager.RankType.All)
    check("全服榜非空", #all > 0, #all)
    local sorted = true
    for i = 2, #all do
        if all[i - 1].score < all[i].score then sorted = false; break end
    end
    check("按分数降序", sorted)
    local rankOk = true
    for i = 1, #all do
        if all[i].rank ~= i then rankOk = false; break end
    end
    check("名次连续且从 1 开始", rankOk)

    local localRank = CountryRankManager.GetRankList(CountryRankManager.RankType.Local)
    check("本国榜非空", #localRank > 0, #localRank)
    local onlyCN = true
    for _, v in ipairs(localRank) do
        if v.country ~= "cn" then onlyCN = false; break end
    end
    check("本国榜只含本国玩家", onlyCN)

    -- 稳定性：同一份数据两次求值一致
    local a1 = CountryRankManager.GetRankList(CountryRankManager.RankType.All)[1].score
    CountryRankManager._allRank = nil
    local a2 = CountryRankManager.GetRankList(CountryRankManager.RankType.All)[1].score
    check("榜单可复现（同种子同分）", a1 == a2, a1 .. " vs " .. a2)
end

print("\n[5] 我的排名")
do
    prefs = { player_country = "cn" }
    CountryRankManager.Initialize()
    local mine = CountryRankManager.GetMyRankInfo(CountryRankManager.RankType.All)
    check("有我的排名对象", mine ~= nil)
    check("带所属国家", mine.country == "cn", mine.country)
    check("未上榜时 rank 为空", mine.rank == nil, tostring(mine.rank))
    check("分数非负", (mine.score or -1) >= 0, mine.score)

    -- 切换国家后本国榜跟着变
    CountryRankManager.SetPlayerCountry("us")
    local localUS = CountryRankManager.GetRankList(CountryRankManager.RankType.Local)
    local allUS = true
    for _, v in ipairs(localUS) do
        if v.country ~= "us" then allUS = false; break end
    end
    check("换国家后本国榜跟着变", allUS and #localUS > 0, #localUS)
end

print("\n[6] 页签状态")
do
    CountryRankManager.SetRankType(CountryRankManager.RankType.Local)
    check("设置页签", CountryRankManager.GetRankType() == CountryRankManager.RankType.Local)
    CountryRankManager.SetRankType(CountryRankManager.RankType.All)
    check("切回全服", CountryRankManager.GetRankType() == CountryRankManager.RankType.All)
end

print("\n[7] 国家表完整性")
do
    local seen = {}
    local dup = nil
    local missingSpriteName = {}
    for _, info in ipairs(CountryConfig.List) do
        if seen[info.code] then dup = info.code end
        seen[info.code] = true
        if not info.zh then table.insert(missingSpriteName, info.code) end
    end
    check("国家码无重复", dup == nil, dup)
    check("每个国家都有中文名", #missingSpriteName == 0, table.concat(missingSpriteName, ","))
    check("兜底国家在表内", CountryConfig.BY_CODE[CountryConfig.FALLBACK_CODE] ~= nil)
    check("国家数量合理(>=20)", #CountryConfig.List >= 20, #CountryConfig.List)
end

print("\n[8] 通用排行榜的旗帜映射（CountryFlagUtil）")
do
    IsNull = function(x) return x == nil end
    Util = Util or {}
    Util.LoadSprite = function(n) return n end
    -- 载入辅助模块（它 require 了 CountryConfig，已在上文载入）
    assert(loadfile(LUA_SRC .. "/Modules/CountryRank/CountryFlagUtil.lua"))()

    prefs = { player_country = "jp" }
    PlayerManager.uid = 777
    CountryRankManager.Initialize()

    check("服务端下发的国家优先", CountryFlagUtil.ResolveCountry(777, "br") == "br",
            CountryFlagUtil.ResolveCountry(777, "br"))
    check("自己的记录用本地国家", CountryFlagUtil.ResolveCountry(777, nil) == "jp",
            CountryFlagUtil.ResolveCountry(777, nil))
    check("nil uid 落兜底", CountryFlagUtil.ResolveCountry(nil, nil) == "xx")

    -- 其他玩家：同一 uid 必须稳定映射
    local c1 = CountryFlagUtil.ResolveCountry(12345, nil)
    local c2 = CountryFlagUtil.ResolveCountry(12345, nil)
    check("同一 uid 映射稳定", c1 == c2, c1 .. " vs " .. c2)
    check("映射结果合法", CountryConfig.BY_CODE[c1] ~= nil, c1)

    -- 不同 uid 应分散到多个国家（不是全同一个）
    local distinct = {}
    for i = 1, 60 do
        distinct[CountryFlagUtil.ResolveCountry(1000 + i * 37, nil)] = true
    end
    local cnt = 0
    for _ in pairs(distinct) do cnt = cnt + 1 end
    check("不同 uid 能分散到多个国家", cnt >= 5, cnt)
end

print(string.format("\n==== 通过 %d / 失败 %d ====", pass, fail))
os.exit(fail == 0 and 0 or 1)
