--[[
 * 排行榜 / 玩家信息 里的「国家小旗」绘制
 *
 * 为什么单独抽一个模块：
 *   通用排行榜有 10+ 个榜单类型、每类走各自的 ShowXxxInfo，但最终都落到
 *   SetInfoShow / SetHeadsInfo。旗帜逻辑集中在这里，各个榜单不必各写一遍。
 *
 * 数据来源（唯一真源 = 服务端下发的 country）：
 *   1. data.country —— 服务端记录，玩家自己选的
 *   2. 自己 && 服务端还没下发 → 用本地记录（刚选完、响应还没回来的短暂窗口）
 *
 * 显示规则（用户 2026-10-18 确认）：
 *    - 有国家（服务端记录 / 自己本地已选）→ 显示对应国旗
 *    - 没有国家数据 → 显示 cn2-guoqi_xx「问号旗」占位，避免名字旁空白
 *    - ⚠️ 刻意**没有**「按 uid 随机映射」：那会让人人都有真旗，但全是编的
--]]

CountryFlagUtil = {}
local this = CountryFlagUtil

local requireOk = pcall(require, "Modules/CountryRank/CountryConfig")
if not CountryConfig then
    -- CountryConfig 会自动注册全局表；真出错时给出可读日志而不是崩在 nil 上
    LogError("[CountryFlagUtil] CountryConfig 未加载")
    return
end

--- 解析某个玩家应显示的国家码；取不到返回 nil（= 由调用方决定占位/隐藏）
-- @param uid     玩家 uid（可为 nil）
-- @param country 服务端下发的国家码（可为 nil / ""）
function CountryFlagUtil.ResolveCountry(uid, country)
    -- 1. 服务端有记录就用服务端的（唯一真源）
    if country ~= nil and country ~= "" then
        return CountryConfig.Normalize(country)
    end

    -- 2. 自己没有服务端值时，允许用本地已选值做临时显示
    --    （玩家刚在面板里选完、服务端响应还没回来的窗口）
    local myUid = PlayerManager and PlayerManager.uid or 0
    if uid ~= nil and myUid ~= nil and myUid ~= 0
            and tonumber(uid) == tonumber(myUid) and CountryRankManager then
        local localCode = CountryRankManager.GetPlayerCountry()
        if localCode ~= nil and localCode ~= "" then
            return localCode
        end
    end

    -- 3. 其他玩家且服务端没记录 → nil（调用方显示问号占位旗）
    return nil
end

--- 给一个 Image 设置国旗 sprite
-- 取不到国家码时显示 cn2-guoqi_xx 问号旗占位（名字旁不空一块）
-- @param go   countryFlag 节点的 GameObject
-- @param uid  玩家 uid
-- @param country 服务端国家码（可选）
function CountryFlagUtil.Apply(go, uid, country)
    if go == nil or IsNull(go) then
        return
    end
    local code = CountryFlagUtil.ResolveCountry(uid, country)
    if code == nil then
        -- 没有真实数据：显示问号占位旗（用户 2026-10-18 要求，不要留空）
        go:SetActive(true)
        local img = go:GetComponent("Image")
        if img ~= nil then
            img.sprite = Util.LoadSprite(CountryConfig.GetFlagSprite(CountryConfig.FALLBACK_CODE))
        end
        return
    end
    local img = go:GetComponent("Image")
    if img == nil then
        return
    end
    go:SetActive(true)
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

return CountryFlagUtil
