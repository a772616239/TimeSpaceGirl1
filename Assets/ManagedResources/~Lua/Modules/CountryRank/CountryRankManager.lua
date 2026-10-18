require("Modules/CountryRank/CountryConfig")

--[[
 * 国家排行榜 —— 数据与状态管理
 *
 * 职责：
 *   1. 玩家所属国家（本地）：玩家自选 > 设备地区 > 兜底
 *   2. 全服/本国两个榜单的数据来源
 *   3. 榜单数据的排序与「我的排名」定位
 *
 * ⚠️ 关于服务端：
 *   当前协议（proto/protos/*.proto）里没有任何「玩家国家」字段，服务端排行榜
 *   （RankingManager 里的 GetWarPowerRank 等）也只下发 uid/name/head/level。
 *   因此这一步在客户端用 **本地生成的可复现数据** 把 UI 与交互跑通；
 *   接真数据时只需要替换 CountryRankManager.RequestRank 内部这一段，
 *   面板与选择逻辑不用动（见函数上的 TODO 标注）。
--]]

CountryRankManager = {}
local this = CountryRankManager

local PLAYER_COUNTRY_KEY = "player_country"
local DEVICE_COUNTRY_KEY = "device_country"

-- 榜单类型
CountryRankManager.RankType = {
    All = 1,    -- 全服（所有国家一起排）
    Local = 2,  -- 本国（只看自己国家）
}

-- 一页显示多少条（面板可视区约 976 高 / 条目 112，留一屏余量）
local ROW_HEIGHT = 104
local ROW_GAP = 8
local VISIBLE_COUNT = 8

function CountryRankManager.Initialize()
    this._curType = CountryRankManager.RankType.All
    this._allRank = nil
    this._localRank = nil
    this._myRankInfo = nil
end

---------------------------------------------------------------- 玩家国家
--- 玩家当前所属国家码（已规整）
function CountryRankManager.GetPlayerCountry()
    local saved = PlayerPrefs.GetString(PLAYER_COUNTRY_KEY, "")
    if saved ~= nil and saved ~= "" then
        return CountryConfig.Normalize(saved)
    end
    local device = PlayerPrefs.GetString(DEVICE_COUNTRY_KEY, "")
    if device ~= nil and device ~= "" then
        return CountryConfig.Normalize(device)
    end
    return CountryConfig.FALLBACK_CODE
end

--- 玩家是否主动选过国家（决定首次进入是否弹选择面板）
function CountryRankManager.HasChosenCountry()
    local saved = PlayerPrefs.GetString(PLAYER_COUNTRY_KEY, "")
    return saved ~= nil and saved ~= ""
end

--- 保存玩家所选国家
function CountryRankManager.SetPlayerCountry(code)
    local normalized = CountryConfig.Normalize(code)
    PlayerPrefs.SetString(PLAYER_COUNTRY_KEY, normalized)
    PlayerPrefs.Save()
    Log("[CountryRank] player_country=" .. normalized)
    -- 榜单里"本国"部分需要重算
    this._localRank = nil
    this._myRankInfo = nil
    return normalized
end

---------------------------------------------------------------- 榜单数据
--- 伪随机（按种子稳定），保证同一玩家每次看到的数值一致
local function seededScore(seedStr, base, span)
    local h = 5381
    for i = 1, #seedStr do
        h = (h * 33 + string.byte(seedStr, i)) % 2147483647
    end
    return base + h % span
end

--- 玩家名池（数据接入服务端前，用于让榜单看起来完整）
local NAME_POOL = {
    "指挥官", "夜航星", "赤羽", "白鲸", "铁幕", "雾都", "银翼", "苍蓝",
    "北境", "织梦", "星屑", "深海", "雷暴", "黎明", "凋零", "极光",
}

--- 生成一条榜单记录
local function makeEntry(uid, countryCode, index)
    local name = NAME_POOL[(uid % #NAME_POOL) + 1] .. tostring(uid % 97 + 1)
    return {
        uid = uid,
        name = name,
        country = countryCode,
        level = 120 - (index % 40),
        score = seededScore("uid" .. uid .. "c" .. countryCode, 620000, 680000),
    }
end

--- 生成一份全服榜单（按国家分布）
local function buildAllRank()
    local list = {}
    local uid = 100000
    local lanCount = #CountryConfig.List
    -- 每个国家 4 个玩家，保证「本国排行」切过去也有内容
    for ci = 1, lanCount do
        local info = CountryConfig.List[ci]
        for k = 1, 4 do
            uid = uid + 137
            list[#list + 1] = makeEntry(uid, info.code, #list)
        end
    end
    table.sort(list, function(a, b)
        return a.score > b.score
    end)
    for i = 1, #list do
        list[i].rank = i
    end
    return list
end

--- 本国榜单：从全服榜里筛出自己国家
local function buildLocalRank(allRank, myCountry)
    local list = {}
    for _, v in ipairs(allRank) do
        if v.country == myCountry then
            list[#list + 1] = v
        end
    end
    table.sort(list, function(a, b)
        return a.score > b.score
    end)
    for i = 1, #list do
        list[i].rank = i
    end
    return list
end

--- 取当前榜单
-- TODO(接服务端): 换成 Network 请求（需要协议先补 player.country + 国家聚合榜）。
--   替换点只有这里：返回同样的 { {rank, uid, name, country, level, score}, ... } 结构即可。
function CountryRankManager.GetRankList(rankType)
    if not this._curType then
        this._curType = rankType or CountryRankManager.RankType.All
    end
    rankType = rankType or this._curType
    if not this._allRank then
        this._allRank = buildAllRank()
    end
    if rankType == CountryRankManager.RankType.Local then
        if not this._localRank then
            this._localRank = buildLocalRank(this._allRank, CountryRankManager.GetPlayerCountry())
        end
        return this._localRank
    end
    return this._allRank
end

--- 设置当前榜单类型（切页签）
function CountryRankManager.SetRankType(rankType)
    this._curType = rankType
end

function CountryRankManager.GetRankType()
    return this._curType or CountryRankManager.RankType.All
end

---------------------------------------------------------------- 我的排名
--- 取"我的排名"展示数据（未上榜时 rank 为 nil）
function CountryRankManager.GetMyRankInfo(rankType)
    local list = CountryRankManager.GetRankList(rankType)
    local myCountry = CountryRankManager.GetPlayerCountry()
    -- 「自己的 uid」在 PlayerManager 里，未登录时可能为 0；未登录就展示一个占位记录
    local myUid = PlayerManager and PlayerManager.uid or 0
    if myUid and myUid > 0 then
        for _, v in ipairs(list) do
            if v.uid == myUid then
                return v
            end
        end
    end
    -- 未上榜：给一条"我的国家"摘要，分数取榜单中位数附近，保证 UI 有内容
    local best = nil
    for _, v in ipairs(list) do
        if v.country == myCountry then
            best = v
            break
        end
    end
    return {
        uid = myUid or 0,
        name = PlayerManager and PlayerManager.name or "",
        country = myCountry,
        level = PlayerManager and PlayerManager.lv or 0,
        score = best and math.floor(best.score * 0.62) or 0,
        rank = nil,
    }
end

--- 国家维度统计（未上榜时用于"我国共有 N 位指挥官在榜"之类展示，当前未使用，留接口）
function CountryRankManager.GetCountryStat(rankType)
    local list = CountryRankManager.GetRankList(rankType)
    local stat = {}
    for _, v in ipairs(list) do
        local s = stat[v.country]
        if not s then
            s = { count = 0, score = 0 }
            stat[v.country] = s
        end
        s.count = s.count + 1
        s.score = s.score + v.score
    end
    return stat
end

--- 可视条目数量（面板排版用，避免 Lua / prefab 两边各写一份魔数）
function CountryRankManager.GetVisibleCount()
    return VISIBLE_COUNT
end

function CountryRankManager.GetRowMetrics()
    return ROW_HEIGHT, ROW_GAP
end

CountryRankManager.Initialize()

return CountryRankManager
