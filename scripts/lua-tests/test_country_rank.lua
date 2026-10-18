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

print("\n[8] 旗帜只认服务端数据（不再按 uid 编造）")
do
    IsNull = function(x) return x == nil end
    Util = Util or {}
    Util.LoadSprite = function(n) return n end
    assert(loadfile(LUA_SRC .. "/Modules/CountryRank/CountryFlagUtil.lua"))()

    prefs = { player_country = "jp" }
    PlayerManager.uid = 777
    CountryRankManager.Initialize()

    check("服务端下发的国家优先", CountryFlagUtil.ResolveCountry(777, "br") == "br",
            CountryFlagUtil.ResolveCountry(777, "br"))
    check("自己没有服务端值→用本地选择", CountryFlagUtil.ResolveCountry(777, nil) == "jp",
            CountryFlagUtil.ResolveCountry(777, nil))

    -- 其他玩家没有服务端数据时解析层返回 nil（调用方显示问号占位旗）
    check("其他玩家无数据 → nil(占位语义)", CountryFlagUtil.ResolveCountry(12345, nil) == nil,
            tostring(CountryFlagUtil.ResolveCountry(12345, nil)))
    -- Apply 层：nil → 显示问号占位旗（cn2-guoqi_xx），名字旁不留空
    local shown = { active = nil, sprite = nil }
    local img = { sprite = nil }   -- 模拟 Image 组件，sprite 可直接赋值
    local fakeGo = setmetatable({}, {
        __index = {
            GetComponent = function(_, t)
                if t == "Image" then return img end
                return nil
            end,
            SetActive = function(_, on) shown.active = on end,
        },
    })
    -- Util.LoadSprite 已被桩为返回 "SPRITE:"..name
    CountryFlagUtil.Apply(fakeGo, 12345, nil)
    check("无数据时显示占位旗(节点激活)", shown.active == true, tostring(shown.active))
    check("占位旗是问号(cn2-guoqi_xx)",
            img.sprite == "cn2-guoqi_xx", tostring(img.sprite))
    -- 有数据时显示真实国旗
    CountryFlagUtil.Apply(fakeGo, 12345, "us")
    check("有数据时显示真旗", img.sprite == "cn2-guoqi_us", tostring(img.sprite))
    check("其他玩家有数据 → 用服务端值", CountryFlagUtil.ResolveCountry(12345, "us") == "us",
            tostring(CountryFlagUtil.ResolveCountry(12345, "us")))
    check("uid 为 nil 也不编造", CountryFlagUtil.ResolveCountry(nil, nil) == nil,
            tostring(CountryFlagUtil.ResolveCountry(nil, nil)))
end

print("\n[9] 模块 return 约定（Game.InitManagers 靠 require 返回值）")
do
    -- 项目里所有 Modules/*.lua 都以 return <表> 结尾；漏掉会让 require 返回 true，
    -- 进而 InitManagers 里 manager.Initialize() 报 "attempt to index local 'manager'"
    local expected = {
        ["Modules/CountryRank/CountryConfig"] = "CountryConfig",
        ["Modules/CountryRank/CountryRankManager"] = "CountryRankManager",
        ["Modules/CountryRank/CountryFlagUtil"] = "CountryFlagUtil",
        ["Modules/CountryRank/UIConfigExtension"] = "UIConfigExtension",
    }
    for mod, name in pairs(expected) do
        local ok, ret = pcall(require, mod)
        check(mod .. " 返回表", ok and type(ret) == "table", type(ret))
    end
    -- 面板类模块需要 BasePanel，这里只做静态检查：文件末尾必须有 return
    for _, f in ipairs({"CountryRankPanel", "CountryFlagSelectPopup"}) do
        local path = LUA_SRC .. "/Modules/CountryRank/" .. f .. ".lua"
        local fh = io.open(path, "r")
        local tail = fh and fh:read("*a") or ""
        if fh then fh:close() end
        check(f .. ".lua 末尾有 return", tail:match("return%s+" .. f .. "%s*$") ~= nil)
    end
    -- 真正模拟 InitManagers 的那一行
    local mgr = require("Modules/CountryRank/CountryRankManager")
    local ok2, err2 = pcall(function() mgr.Initialize() end)
    check("manager.Initialize() 可调用（复现原崩溃点）", ok2, err2)
end

print("\n[10] 首次进主界面的一次性引导（只弹一次）")
do
    prefs = {}
    CountryRankManager.Initialize()
    check("初始未弹过", CountryRankManager.HasShownGuide() == false)

    -- 记录标记后永远不再弹
    CountryRankManager.MarkGuideShown()
    check("标记后标记位为真", CountryRankManager.HasShownGuide() == true)
    check("PlayerPrefs 真的写入了", prefs.country_rank_guide_done == 1,
            prefs.country_rank_guide_done)

    -- 幂等：重复调用不报错、不重复写
    CountryRankManager.MarkGuideShown()
    check("重复 MarkGuideShown 幂等", CountryRankManager.HasShownGuide() == true)

    -- 模拟"玩家已自选国家"也不影响：引导标记是独立维度
    CountryRankManager.SetPlayerCountry("jp")
    check("自选国家后仍记得已弹过", CountryRankManager.HasShownGuide() == true)

    -- 模拟全新安装（清空所有 Prefs）→ 应重新可弹
    prefs = {}
    check("全新安装后可以再弹", CountryRankManager.HasShownGuide() == false)
end

print("\n[11] UIConfigExtension 路径（UIManager 会拼 Modules/..script）")
do
    IsNull = function(x) return x == nil end
    BasePanel = BasePanel or {}
    if type(Inherit) ~= "function" then
        Inherit = function(b) local o={} setmetatable(o,{__index=b}) o.__index=o return o end
    end
    package.preload["Base/BasePanel"] = function() return BasePanel end
    ConfigName = ConfigName or { UIConfig = "UIConfig" }

    local fakeCfg = setmetatable({}, { __newindex = function() end })  -- 模拟只读元表
    if not ConfigManager then
        ConfigManager = { GetConfig = function() return fakeCfg end }
    end
    local ext = require("Modules/CountryRank/UIConfigExtension")
    ext.Register()
    check("1010 用 rawset 注入成功", rawget(fakeCfg, 1010) ~= nil)
    check("1011 用 rawset 注入成功", rawget(fakeCfg, 1011) ~= nil)
    for _, id in ipairs({1010, 1011}) do
        local cfg = rawget(fakeCfg, id)
        if cfg then
            -- 这是本次真实崩溃点：script 里不能再带 Modules/
            check(("id=%d script 无 Modules/ 前缀"):format(id),
                    not cfg.script:find("^Modules/"), cfg.script)
            local ok, mod = pcall(require, "Modules/" .. cfg.script)
            check(("id=%d 拼出的路径可 require"):format(id), ok and type(mod) == "table")
        end
    end
end

print("\n[12] 选了国旗后的解析（PlayerInfoPopup）")
do
    local FlagUtil2 = require("Modules/CountryRank/CountryFlagUtil")

    prefs = { player_country = "jp" }
    PlayerManager.uid = 10000248
    CountryRankManager.Initialize()

    -- 服务端下发的 teamInfo 没有 country 字段 → 自己用本地值
    local code = FlagUtil2.ResolveCountry(10000248, nil)
    check("自己（teamInfo 无 country）用本地所选", code == "jp", tostring(code))
    check("旗帜 sprite 是日本旗", CountryConfig.GetFlagSprite(code) == "cn2-guoqi_jp",
            CountryConfig.GetFlagSprite(code))

    -- 别人没有服务端数据 → nil，UI 层显示问号占位旗（名字旁不留空）
    local otherCode = FlagUtil2.ResolveCountry(10009999, nil)
    check("别人无数据 → nil(占位语义)", otherCode == nil, tostring(otherCode))
    check("占位旗为问号版本", CountryConfig.GetFlagSprite(CountryConfig.FALLBACK_CODE)
            == "cn2-guoqi_xx", CountryConfig.GetFlagSprite(CountryConfig.FALLBACK_CODE))
end

print(string.format("\n==== 通过 %d / 失败 %d ====", pass, fail))
os.exit(fail == 0 and 0 or 1)
