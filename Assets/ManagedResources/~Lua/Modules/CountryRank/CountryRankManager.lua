require("Modules/CountryRank/CountryConfig")
require("Modules/Popup/PopupQueue")

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
    -- 首次进主界面的国家选择面板是否正在占屏（GuideManager 据此把新手引导排队）
    this._firstEnterPopupShowing = false
    this._firstEnterPopupDeadline = 0
end

---------------------------------------------------------------- 玩家国家
--- 玩家当前所属国家码（已规整）
--- 优先级：服务端记录 > 本地自选 > 设备地区 > 兜底
--- （服务端有值时以它为准，换机/重装后本地 PlayerPrefs 已经丢了，靠服务端恢复）
function CountryRankManager.GetPlayerCountry()
    if PlayerManager ~= nil then
        local server = PlayerManager.country
        if server ~= nil and server ~= "" then
            return CountryConfig.Normalize(server)
        end
    end
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

--- 玩家「自己选过」的国家码；没选过返回 nil
--- 与 GetPlayerCountry 的区别：这里**不看** PlayerManager.country（服务端回包），
--- 只认本地 player_country —— 即「玩家最后一次选择/或登录时与服务端同步的值」。
--- 用途：改完旗到服务端落值之间有一段窗口，榜单回包还是旧 country，
---       此时「自己」的旗要以这份本地值为准（见 CountryFlagUtil.ResolveCountry）。
function CountryRankManager.GetChosenCountry()
    local saved = PlayerPrefs.GetString(PLAYER_COUNTRY_KEY, "")
    if saved ~= nil and saved ~= "" then
        return CountryConfig.Normalize(saved)
    end
    return nil
end

--- 玩家是否主动选过国家（决定首次进入是否弹选择面板）
function CountryRankManager.HasChosenCountry()
    if PlayerManager ~= nil and PlayerManager.country ~= nil and PlayerManager.country ~= "" then
        return true
    end
    local saved = PlayerPrefs.GetString(PLAYER_COUNTRY_KEY, "")
    return saved ~= nil and saved ~= ""
end

--- 保存玩家所选国家（本地 + 上报服务端）
--- @param code 国家码
--- @param skipServer 可选；true 时只写本地（内部补调用，避免回环）
function CountryRankManager.SetPlayerCountry(code, skipServer)
    local normalized = CountryConfig.Normalize(code)
    PlayerPrefs.SetString(PLAYER_COUNTRY_KEY, normalized)
    PlayerPrefs.Save()
    if PlayerManager ~= nil then
        PlayerManager.country = normalized
    end
    if not skipServer and NetManager ~= nil and NetManager.SetPlayerCountry ~= nil then
        NetManager.SetPlayerCountry(normalized, function(resultCode, serverCode)
            if resultCode == 0 and serverCode ~= nil and serverCode ~= "" and serverCode ~= normalized then
                -- 服务端做了归一（理论上不会），以服务端为准
                PlayerManager.country = serverCode
                PlayerPrefs.SetString(PLAYER_COUNTRY_KEY, serverCode)
                PlayerPrefs.Save()
            end
        end)
    end
    Log("[CountryRank] player_country=" .. normalized)
    -- 榜单里"本国"部分需要重算
    this._localRank = nil
    this._myRankInfo = nil

    --[[
     * 改旗后的**唯一广播点**
     *
     * 以前把「派发 OnCountryChanged + 重画自己的旗」写在各入口里，结果：
     *   - 设置页的旗、聊天点开的玩家信息面板、国家榜的「我的排名」都以为
     *     别人会发事件，实际没人发 ⇒ 改完旗不关掉重开就一直是旧旗；
     *   - 任何新增入口（引导、静默补传）都得自己再写一遍，必漏。
     * 收口到这里后，所有路径都只走一次，且时序正确：PlayerManager.country
     * 与本地 player_country 已更新，CountryFlagUtil 立刻解析出新值。
     *]]
    if Game ~= nil and Game.GlobalEvent ~= nil and GameEvent ~= nil and GameEvent.CountryRank ~= nil then
        Game.GlobalEvent:DispatchEvent(GameEvent.CountryRank.OnCountryChanged, normalized)
    end
    -- 已经画出来的「自己的旗」就地重画（排行榜/竞技场/玩家信息/设置页都登记在这里）
    if CountryFlagUtil ~= nil and CountryFlagUtil.RefreshSelfFlags ~= nil then
        CountryFlagUtil.RefreshSelfFlags()
    end

    return normalized
end

--- 登录拿到 GetPlayerInfoResponse 后调用：
--- 服务端没有记录但本地选过 → 补传一次，让历史玩家也进服务端（只补传，不改本地展示）
function CountryRankManager.OnPlayerInfoLoaded()
    if PlayerManager ~= nil and PlayerManager.country ~= nil and PlayerManager.country ~= "" then
        -- 服务端已有记录：把本地缓存对齐（避免两边不一致时面板显示漂移）
        local serverCode = CountryConfig.Normalize(PlayerManager.country)
        PlayerPrefs.SetString(PLAYER_COUNTRY_KEY, serverCode)
        PlayerPrefs.Save()
        return
    end
    local saved = PlayerPrefs.GetString(PLAYER_COUNTRY_KEY, "")
    if saved ~= nil and saved ~= "" then
        if NetManager ~= nil and NetManager.SetPlayerCountry ~= nil then
            NetManager.SetPlayerCountry(CountryConfig.Normalize(saved))
        end
    end
end

---------------------------------------------------------------- 首次进主界面的一次性引导

-- 标记键：玩家是否已经「被引导选过国家」
-- 与 HasChosenCountry 的区别：玩家可能被设备地区自动定好国家（player_country 为空），
-- 但引导弹窗仍应只弹一次 —— 所以单独记一个"已提示过"的标记。
local GUIDE_DONE_KEY = "country_rank_guide_done"

--- 引导弹窗是否已经弹过（永久，写 PlayerPrefs）
function CountryRankManager.HasShownGuide()
    return PlayerPrefs.GetInt(GUIDE_DONE_KEY, 0) == 1
end

--- 标记引导已弹过（调用后永不再弹）
function CountryRankManager.MarkGuideShown()
    if CountryRankManager.HasShownGuide() then
        return
    end
    PlayerPrefs.SetInt(GUIDE_DONE_KEY, 1)
    PlayerPrefs.Save()
    Log("[CountryRank] guide done, will never popup again")
end

--[[
 * 进主界面后调用：第一次弹出国家旗帜选择，之后永不再弹。
 *
 * 与新手引导的先后顺序（两者绝不能同屏）：
 *   主界面 OnShow 末尾（本函数）先置「占屏」标记，再延时弹窗；
 *   MainPanel 的 UI.OnOpen 是 OnShow **之后**才派发的，强制引导的 openType==4
 *   正是监听这个事件 —— 那一刻 GuideManager.ShowGuide 会看到占屏标记，
 *   把引导排进队列，等本面板关闭后再放行（见 GuideManager.FlushPendingGuides）。
 *   反过来，如果此刻 GuidePanel 已经开着，本面板就等它关掉再弹。
 *
 * 用 Timer 延后一小段再弹，避免和主界面开场动画抢焦点（延时期间引导会被排队，不会插队）。
 *]]
function CountryRankManager.TryShowFirstEnterGuide()
    -- 整段用 pcall 包住：这是挂在主界面 OnShow 上的附带功能，
    -- 任何异常都不该影响主界面与角色数据加载。
    local ok, err = pcall(function()
        if CountryRankManager.HasShownGuide() then
            return
        end
        if UIManager.IsOpen(UIName.CountryFlagSelectPopup) then
            return
        end
        -- 先落标记再弹窗：即使弹窗过程中玩家强退，也不会下次重复弹
        CountryRankManager.MarkGuideShown()
        -- 占屏标记必须**同步**置上：引导在本函数返回后的同一帧就会尝试弹出
        CountryRankManager.MarkFirstEnterPopupShowing(true)
        local timer
        timer = Timer.New(function()
            pcall(function()
                timer:Stop()
                CountryRankManager.ShowFirstEnterPopup()
            end)
        end, 0.6, 1, true)
        timer:Start()
    end)
    if not ok then
        CountryRankManager.MarkFirstEnterPopupShowing(false)
        LogError("[CountryRank] guide failed, ignored: " .. tostring(err))
    end
end

--- 首次进主界面的国家选择面板是否正占着屏（新手引导据此排队）
---
--- 两种情况都算占屏：
---   1. 面板已经真的开出来了 —— 一直算，直到它关闭；
---   2. 面板还在等那 0.6s 延时 —— 也算，否则引导会在这个空档里抢在前面弹出来。
--- 第 2 种带超时（POPUP_PENDING_TIMEOUT）：万一弹窗链路整段失败（资源缺失、异常），
--- 标记不能把新手引导永久堵死。
local POPUP_PENDING_TIMEOUT = 2 -- 秒（远大于 0.6s 延时，又短到不会让玩家干等）

local function nowSeconds()
    if Time ~= nil and Time.realtimeSinceStartup ~= nil then
        return Time.realtimeSinceStartup
    end
    return 0
end

function CountryRankManager.IsFirstEnterPopupShowing()
    if this._firstEnterPopupShowing ~= true then
        return false
    end
    -- 已经真开出来了：以 UI 状态为准，直到关窗
    if UIManager ~= nil and UIManager.IsOpen ~= nil
            and UIManager.IsOpen(UIName.CountryFlagSelectPopup) then
        return true
    end
    -- 还在等延时弹窗的空档
    if this._firstEnterPopupDeadline ~= nil and nowSeconds() <= this._firstEnterPopupDeadline then
        return true
    end
    -- 已经进了弹窗队列、只是前面还有别的主动弹窗没关完：
    -- 队列里排队同样算占屏，否则超时后引导会插到它前面去
    if PopupQueue ~= nil and PopupQueue.IsQueued ~= nil
            and PopupQueue.IsQueued(UIName.CountryFlagSelectPopup) then
        return true
    end
    return false
end

--- 置/清「占屏」标记；清除时立刻放行排队中的新手引导
function CountryRankManager.MarkFirstEnterPopupShowing(showing)
    this._firstEnterPopupShowing = showing and true or false
    this._firstEnterPopupDeadline = showing and (nowSeconds() + POPUP_PENDING_TIMEOUT) or 0
    if not this._firstEnterPopupShowing and GuideManager ~= nil and GuideManager.FlushPendingGuides ~= nil then
        GuideManager.FlushPendingGuides()
    end
end

--- 真正弹出面板（内部处理「引导正开着就先等它」与「打开失败要解除占屏」）
function CountryRankManager.ShowFirstEnterPopup()
    -- 新手引导已经开着：等它关掉再弹，避免两个界面压在一起
    if UIManager.IsOpen(UIName.GuidePanel) then
        local onGuideClose
        onGuideClose = function(panelType)
            if panelType ~= UIName.GuidePanel then
                return
            end
            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, onGuideClose)
            -- 延后一点：本回调还在 UIManager.CloseStackPanel 的收尾流程里（还会重开/聚焦栈内面板），
            -- 此刻直接 OpenPanel 会被它接着改层级
            local timer
            timer = Timer.New(function()
                timer:Stop()
                pcall(function()
                    CountryRankManager.ShowFirstEnterPopup()
                end)
            end, 0.2, 1, true)
            timer:Start()
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, onGuideClose)
        return
    end

    -- 关窗（选完 / 点遮罩 / 点关闭）时解除占屏标记，排队的新手引导随即放行
    local onClose
    onClose = function(panelType)
        if panelType ~= UIName.CountryFlagSelectPopup then
            return
        end
        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, onClose)
        CountryRankManager.MarkFirstEnterPopupShowing(false)
    end
    Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, onClose)

    -- 走弹窗队列：前面若还有首充/拍脸/至尊英雄没关，就排在它们后面
    local accepted = PopupQueue.PushSilent(UIName.CountryFlagSelectPopup, function(code)
        Log("[CountryRank] first-enter country picked: " .. tostring(code))
    end)
    if not accepted then
        -- 入队/打开失败（缺资源等）：立刻解除占屏，别把新手引导永久卡在队列里
        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, onClose)
        CountryRankManager.MarkFirstEnterPopupShowing(false)
    end
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
