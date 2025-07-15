ChanagePanel = quick_class("GuildBattlePanel")
local this = ChanagePanel
local guildWarSetting = ConfigManager.GetConfig(ConfigName.GuildWarSetting)
local guildWarConfig = ConfigManager.GetConfig(ConfigName.GuildWarConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local cityImg = {
    "cn2-X1_gonghui_dibiao_wuguishu",
    "cn2-X1_gonghui_dibiao_youguishu",
    "cn2-X1_gonghui_dibiao_zhandouzhong"
}
local server = {}--跨服

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
        this.city[i] = {
            cityBg = Util.GetGameObject(this.gameObject, "map/city"..i):GetComponent("Image"),
            cityName = Util.GetGameObject(this.gameObject, "map/city"..i.."/cityName"):GetComponent("Text"),
            guildName = Util.GetGameObject(this.gameObject, "map/city"..i.."/guildName"):GetComponent("Text"),
            btn = Util.GetGameObject(this.gameObject, "map/city"..i.."/btn"),
            data = {}
        }
    end

    --跨服
    this.crossService = Util.GetGameObject(this.gameObject, "crossService")
    this.serverGrid = Util.GetGameObject(this.crossService, "grid")
    this.serverPre = Util.GetGameObject(this.crossService, "grid/pre")
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
    CheckRedPointStatus(RedPointType.GuildBattle_FreeTime)
    GuildBattleManager.GetTotalDamageRankRequest(function ()
        this.RefreshRank()
    end)
    this.RefreshTimes()
    this.RemainTimeDown()
    this.ShowCity()
    this.crossService:SetActive(GuildBattleManager.guildType == 1)
    this.SetCrossServerList()
end

--界面关闭时调用（用于子类重写）
function this:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()
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