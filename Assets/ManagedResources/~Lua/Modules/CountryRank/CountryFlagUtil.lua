--[[
 * 排行榜 / 玩家信息 里的「国家小旗」绘制
 *
 * 为什么单独抽一个模块：
 *   通用排行榜有 10+ 个榜单类型、每类走各自的 ShowXxxInfo，但最终都落到
 *   SetInfoShow / SetHeadsInfo。旗帜逻辑集中在这里，各个榜单不必各写一遍。
 *
 * 数据来源优先级（与 PlayerInfoPopup 一致）：
 *   1. data.country —— 服务端将来下发玩家国家时直接使用
 *   2. 自己（uid == 当前玩家）→ CountryRankManager.GetPlayerCountry()
 *   3. 其他玩家且未下发 → 按 uid 稳定映射到已支持的国家（占位，保证同一玩家每次一致）
 *
 * ⚠️ 占位策略说明：协议目前没有 player.country 字段。补上之后第 1 条自动生效，
 *    这里的第 3 条只对"服务端没给国家"的记录兜底。
--]]

CountryFlagUtil = {}
local this = CountryFlagUtil

local requireOk = pcall(require, "Modules/CountryRank/CountryConfig")
if not CountryConfig then
    -- CountryConfig 会自动注册全局表；真出错时给出可读日志而不是崩在 nil 上
    LogError("[CountryFlagUtil] CountryConfig 未加载")
    return
end

--- 解析某个玩家应显示的国家码
-- @param uid     玩家 uid（可为 nil）
-- @param country 服务端下发的国家码（可为 nil / ""）
function CountryFlagUtil.ResolveCountry(uid, country)
    if country ~= nil and country ~= "" then
        return CountryConfig.Normalize(country)
    end
    local myUid = PlayerManager and PlayerManager.uid or 0
    if uid ~= nil and myUid ~= 0 and uid == myUid then
        return CountryRankManager and CountryRankManager.GetPlayerCountry() or CountryConfig.FALLBACK_CODE
    end
    if uid == nil then
        return CountryConfig.FALLBACK_CODE
    end
    -- 占位：按 uid 稳定映射（跳过最后一个兜底项，避免整榜都是"其他地区"）
    local list = CountryConfig.List
    local span = #list - 1
    if span < 1 then
        return CountryConfig.FALLBACK_CODE
    end
    local idx = (tonumber(uid) or 0) % span + 1
    return list[idx].code
end

--- 给一个 Image 设置国旗 sprite；go 为 nil 时静默跳过（兼容旧 prefab）
-- @param go   countryFlag 节点的 GameObject
-- @param uid  玩家 uid
-- @param country 服务端国家码（可选）
function CountryFlagUtil.Apply(go, uid, country)
    if go == nil or IsNull(go) then
        return
    end
    local img = go:GetComponent("Image")
    if img == nil then
        return
    end
    local code = CountryFlagUtil.ResolveCountry(uid, country)
    img.sprite = Util.LoadSprite(CountryConfig.GetFlagSprite(code))
end

--- 直接在父节点下按名字取 countryFlag 再设置
function CountryFlagUtil.ApplyTo(parent, uid, country)
    if parent == nil or IsNull(parent) then
        return
    end
    local go = Util.GetGameObject(parent, "countryFlag")
    CountryFlagUtil.Apply(go, uid, country)
end
