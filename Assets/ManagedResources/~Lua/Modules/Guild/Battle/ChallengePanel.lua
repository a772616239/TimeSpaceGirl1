ChanagePanel = quick_class("GuildBattlePanel")
local this = ChanagePanel
local ItemPopIn = require("Modules/Common/ItemPopIn")--地图据点入场（从小到大的弹性）
local guildWarSetting = ConfigManager.GetConfig(ConfigName.GuildWarSetting)
local guildWarConfig = ConfigManager.GetConfig(ConfigName.GuildWarConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local cityImg = {
    "cn2-X1_gonghui_dibiao_wuguishu",
    "cn2-X1_gonghui_dibiao_youguishu",
    "cn2-X1_gonghui_dibiao_zhandouzhong"
}
local server = {}--跨服

--==================== 地图据点入场（从小到大的弹性）====================
-- map/city1..10 不是列表，是散在地图上的 10 个固定据点 ⇒ 用数组数据源 + phases 关键帧
-- （配方与坑见 docs/ui_item_pop_in_skill.md，列表项一律走公共模块，别在这儿复写第二份）。
-- 不用 duang / OutElastic：单个据点的画面是 315x257（根节点 baseScale 1.2），属「大块头」，
-- OutElastic 在 0.5s 内抖 3 个来回、观感是「闪一下」（同 skill 1.1）。
--   0.65 → 1.05（0.28s OutCubic，冲出峰值）
--        → 0.985（0.14s InOutQuad，被拉回）
--        → 1.00（0.10s OutQuad，落定）           单据点 ≈ 0.52s
-- 相邻错开 0.05（0.45s 内 10 个全起播），整批 ≈ 0.97s。
-- 峰值只到 1.05：city5 的 x=345，右边缘本来就贴着画布边（345 + 315*1.2/2 = 534，半屏 540），
-- 再往上冲会把据点顶出屏幕。
-- centerPivot 关掉：据点图就是根节点自己的 Image、pivot 本来在图的中心；而 cityName/guildName/btn
-- 全挂在中心**上方**，让模块去「按内容并集居中」会把缩放原点抬到那串文字上 ⇒ 看起来像「从文字往下长」。
local kCityPhases = {
    { scale = 1.05,  duration = 0.28, ease = "OutCubic" },
    { scale = 0.985, duration = 0.14, ease = "InOutQuad" },
    { scale = 1,     duration = 0.10, ease = "OutQuad" },
}
local kCityPopInCfg = {
    mode = "phases",
    from = 0.65,
    phases = kCityPhases,
    centerPivot = false,
    step = 0.05,
    maxSpan = 0.45,
}
-- 只播「这一屏第一次被看到」那一轮：面板打开时 GuildBattlePanel:OnOpen 调 RequestCityPopIn 置位、
-- 本文件的 OnShow 消费。点「刷新」（回调里直接调 OnShow）与战斗返回都只走 OnShow ⇒ 不重播
-- （判据见 docs/ui_item_pop_in_skill.md 第 3 节）。
local playCityInOnShow = false

function this:InitComponent(go)
    this.gameObject = go

    this.chanageTimes = Util.GetGameObject(this.gameObject, "chanageTimes/chanageTimes"):GetComponent("Text")--可挑战次数
    this.buyTimes = Util.GetGameObject(this.gameObject, "chanageTimes/buyTimes"):GetComponent("Text")--剩余购买次数
    this.btnBuy = Util.GetGameObject(this.gameObject, "chanageTimes/btnBuy")--购买次数
    this.btnHelp = Util.GetGameObject(this.gameObject, "btnHelp")--帮助
    this.btnChange = Util.GetGameObject(this.gameObject, "btnChange")--刷新
    this.btnChat = Util.GetGameObject(this.gameObject, "btnChat")--聊天

    this.time = Util.GetGameObject(this.gameObject, "time/time"):GetComponent("Text")--剩余挑战时间
    this.rank = Util.GetGameObject(this.gameObject, "rank")--排行
    this.btnRank = Util.GetGameObject(this.gameObject, "rank/btnRank")

    this.city = {}
    for i = 1, 10 do
        local cityGo = Util.GetGameObject(this.gameObject, "map/city"..i)
        this.city[i] = {
            go = cityGo,--据点根节点：入场动画的缩放目标（图就画在它自己身上）
            cityBg = cityGo:GetComponent("Image"),
            cityName = Util.GetGameObject(this.gameObject, "map/city"..i.."/cityName"):GetComponent("Text"),
            guildName = Util.GetGameObject(this.gameObject, "map/city"..i.."/guildName"):GetComponent("Text"),
            btn = Util.GetGameObject(this.gameObject, "map/city"..i.."/btn"),
            data = {}
        }
    end
    --地图据点入场：显式数组数据源（ItemPopIn 认 Lua 数组），顺序 = 从地图中心往外，见 BuildCityPopInList
    this.cityPopInList = this:BuildCityPopInList()
    this.cityPopIn = ItemPopIn.New(function() return this.cityPopInList end, kCityPopInCfg)

    --跨服
    this.crossService = Util.GetGameObject(this.gameObject, "crossService")
    this.serverGrid = Util.GetGameObject(this.crossService, "grid")
    this.serverPre = Util.GetGameObject(this.crossService, "grid/pre")
end

--入场顺序：按「离地图中心远近」由内向外一圈圈弹开 —— 比按 city1..10 顺着弹更像地图在展开，
--也免得美术挪过节点之后顺序变得莫名其妙。读的是 anchoredPosition（据点都是 map 的直接子节点，
--map 四边拉满、pivot 0.5 ⇒ 原点就是地图中心）；量不到就保持 1..10，别让一次取组件失败毁掉整批。
function this:BuildCityPopInList()
    local list, allOk = {}, true
    for i = 1, #this.city do
        local dist = 0
        local ok = pcall(function()
            local pos = this.city[i].go:GetComponent("RectTransform").anchoredPosition
            dist = pos.x * pos.x + pos.y * pos.y--只比大小，不用开根号
        end)
        if not ok then
            allOk = false
        end
        list[i] = { go = this.city[i].go, dist = dist }
    end
    if allOk then
        table.sort(list, function(a, b) return a.dist < b.dist end)
    end
    local out = {}
    for i = 1, #list do
        out[i] = list[i].go
    end
    return out
end

--置位（GuildBattlePanel:OnOpen 调）：下一次 OnShow 播一轮据点入场
function this:RequestCityPopIn()
    playCityInOnShow = true
end

--整批入场：10 个据点从 0.65 弹到原大小（ShowCity 把贴图/文字刷完之后调）
function this:PlayCityPopIn()
    if this.cityPopIn then
        this.cityPopIn:Play()
    end
end

--回收：Kill + 复位。🔴 漏调 = 据点永久停在 0.65
function this:StopCityPopIn()
    if this.cityPopIn then
        this.cityPopIn:Stop()
    end
end

function this:BindEvent()
    Util.AddClick(this.btnBuy, function ()
        if GuildBattleManager.guildBattleState == 0 then
            return
        end
        if GuildBattleManager.allowChallange == 0 then
            return
        end
        if GuildBattleManager.buyCount >= guildWarSetting[1].PurchaseTime then
            return
        end
        if BagManager.GetItemCountById(guildWarSetting[1].Price[1]) < guildWarSetting[1].Price[2] then
            PopupTipPanel.ShowTip(GetLanguageStrById(10060))--道具不足
            return
        end
        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Buy, itemConfig[guildWarSetting[1].Price[1]].ResourceID, string.format(GetLanguageStrById(12526), guildWarSetting[1].Price[2]), function ()
            GuildBattleManager.BuyBattleCount(function ()
                this.RefreshTimes()
            end)
        end, false)
    end)
    Util.AddClick(this.btnHelp, function ()
        UIManager.OpenPanel(
            UIName.HelpPopup,
            HELP_TYPE.GuildBattle,
            this.btnHelp:GetComponent("RectTransform").localPosition.x,
            this.btnHelp:GetComponent("RectTransform").localPosition.y+1000)
    end)
    Util.AddClick(this.btnChange, function ()
        GuildBattleManager.GetGuildBattleInfo(function ()
            GuildBattleManager.GetGuildBattleState(function ()
                GuildBattleManager.GetTotalDamageRankRequest(function ()
                    PopupTipPanel.ShowTip(GetLanguageStrById(10088))--刷新成功
                    this:OnShow()
                end)
            end)
        end)
    end)
    Util.AddClick(this.btnChat, function ()
        UIManager.OpenPanel(UIName.ChatPanel)
    end)
    for i = 1, #this.city do
        Util.AddClick(this.city[i].btn, function ()
            UIManager.OpenPanel(UIName.GuildChallengeInfoPanel, 1, this.city[i].data)
        end)
    end
    Util.AddClick(this.btnRank, function ()
        UIManager.OpenPanel(UIName.GuildBattleRankPanel)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshGuildCityRank, this.Push)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.RefreshGuildBattleState, this.Push)
end

--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshGuildCityRank, this.Push)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.RefreshGuildBattleState, this.Push)
end

-- 打开时调用
function this:OnOpen()
end

--界面打开时调用（用于子类重写）
function this:OnShow()
    local playCityIn = playCityInOnShow
    playCityInOnShow = false--一次性标记：这次不管播不播都清掉，别漏给下一次

    CheckRedPointStatus(RedPointType.GuildBattle_FreeTime)
    GuildBattleManager.GetTotalDamageRankRequest(function ()
        this.RefreshRank()
    end)
    this.RefreshTimes()
    this.RemainTimeDown()
    this.ShowCity()
    this.crossService:SetActive(GuildBattleManager.guildType == 1)
    this.SetCrossServerList()
    --据点入场放在最后：上面已经把据点数据（ShowCity）和显隐都摆好了
    if playCityIn then
        this:PlayCityPopIn()
    end
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    this:StopCityPopIn()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
    this:StopCityPopIn()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    server = {}
end

--推送
function this.Push()
    this.ShowCity()
    GuildBattleManager.GetTotalDamageRankRequest(function ()
        this.RefreshRank()
    end)
    this.RefreshTimes()
    this.RemainTimeDown()
end

function this.ShowCity()
    local info = GuildBattleManager.guildBattleInfos
    local state = GuildBattleManager.guildBattleState
    for i = 1, #info do
        this.city[i].cityName.text = GetLanguageStrById(guildWarConfig[info[i].pathId].Name)
        if state == 1 then
            this.city[i].cityName.color = UIColorNew.RED
            this.city[i].cityBg.sprite = Util.LoadSprite(cityImg[3])
            if info[i].guildName == "" then
                this.city[i].guildName.text = GetLanguageStrById(50261)--争夺中
                this.city[i].guildName.color = UIColor.GRAY
                this.city[i].guildName.fontStyle = UITextFontStyle.NORMAL
            else
                this.city[i].guildName.text = info[i].guildName
                this.city[i].guildName.color = UIColor.WHITE
                this.city[i].guildName.fontStyle = UITextFontStyle.BOLD
            end
        else
            this.city[i].cityName.color = UIColor.WHITE
            if info[i].guildName == "" then
                this.city[i].cityBg.sprite = Util.LoadSprite(cityImg[1])
                this.city[i].guildName.text = GetLanguageStrById(50251)--"无归属"
                this.city[i].guildName.color = UIColor.GRAY
                this.city[i].guildName.fontStyle = UITextFontStyle.NORMAL
            else
                this.city[i].cityBg.sprite = Util.LoadSprite(cityImg[2])
                this.city[i].guildName.text = info[i].guildName
                this.city[i].guildName.color = UIColor.WHITE
                this.city[i].guildName.fontStyle = UITextFontStyle.BOLD
            end
        end
        this.city[i].data = info[i]
    end
end

--刷新次数
function this.RefreshTimes()
    CheckRedPointStatus(RedPointType.GuildBattle_FreeTime)
    this.chanageTimes.text = GetLanguageStrById(91000044)..guildWarSetting[1].Section+GuildBattleManager.buyCount-GuildBattleManager.challengeCount.."/"..guildWarSetting[1].Section--+GuildBattleManager.buyCount
    this.buyTimes.text = GetLanguageStrById(91000045)..guildWarSetting[1].PurchaseTime-GuildBattleManager.buyCount.."/"..guildWarSetting[1].PurchaseTime
    Util.SetGray(this.btnBuy, GuildBattleManager.buyCount >= guildWarSetting[1].PurchaseTime)
end

--刷新排行
function this.RefreshRank()
    local rankDatas = GuildBattleManager.allHurtRank
    for i = 1, 3 do
        local rankGo = Util.GetGameObject(this.rank, "user/user" .. tostring(i))
        if rankDatas[i] then
            rankGo:SetActive(true)
            Util.GetGameObject(rankGo, "name"):GetComponent("Text").text = rankDatas[i].username
            Util.GetGameObject(rankGo, "hurt"):GetComponent("Text").text = PrintWanNum3(rankDatas[i].score)
        else
            rankGo:SetActive(false)
        end
    end
end

--刷新时间
function this.RemainTimeDown()
    local timeDown
    local des
    if GuildBattleManager.guildBattleState == 0 then
        des = GetLanguageStrById(10179).."："
        timeDown = GuildBattleManager.startTime
    else
        des = GetLanguageStrById(91000842)
        timeDown = GuildBattleManager.overTime
    end

    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    this.time.text = des..TimeToDHMS(timeDown-GetTimeStamp())
    if timeDown > 0 then
        this.time.text = des..TimeToDHMS(timeDown-GetTimeStamp())
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            if timeDown-GetTimeStamp() <= 0 then
                this.time.text = ""
                this.timer:Stop()
                this.timer = nil
                return
            end
            this.time.text = des..TimeToDHMS(timeDown-GetTimeStamp())

        end, 1, -1, true)
        this.timer:Start()
    else
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end

        this.time.text = ""
    end
end

--设置跨服列表
function this.SetCrossServerList()
    if GuildBattleManager.guildType == 0 then
        return
    end
    for i = 1, #server do
        server[i]:SetActive(false)
    end
    for i = 1, #GuildBattleManager.serverInfo do
        if not server[i] then
            server[i] = newObjToParent(this.serverPre, this.serverGrid)
        end
        Util.GetGameObject(server[i], "Text"):GetComponent("Text").text = GuildBattleManager.serverInfo[i].serverName
        Util.GetGameObject(server[i], "line"):SetActive(i ~= #GuildBattleManager.serverInfo)
        server[i]:SetActive(true)
    end
end

return this