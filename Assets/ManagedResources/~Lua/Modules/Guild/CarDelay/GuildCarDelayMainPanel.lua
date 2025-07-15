require("Base/BasePanel")
GuildCarDelayMainPanel = Inherit(BasePanel)
local this = GuildCarDelayMainPanel
local testLiveGO
local curIndex = 1
local orginLayer
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local curMonsterId = 1
local curProgress = -1
local curMonsterIdConFig = {}
local TabBox = require("Modules/Common/TabBox")
local _TabData={ [1] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(11032) },
                 [2] = { default = "r_hero_xuanze_002", select = "r_hero_xuanze_001", name = GetLanguageStrById(11033) }, }
local _TabFontColor = { default = Color.New(130 / 255, 128 / 255, 120 / 255, 1),
                        select = Color.New(243 / 255, 235 / 255, 202 / 255, 1)}
this.timer = Timer.New()
local challengeNum = 0
local lootNum = 0
--初始化组件（用于子类重写）
function GuildCarDelayMainPanel:InitComponent()
    this.live2dRoot = Util.GetGameObject(self.gameObject, "live2dRoot")
    this.name = Util.GetGameObject(self.gameObject, "nameAndTime/name"):GetComponent("Text")
    this.proImage = Util.GetGameObject(self.gameObject, "nameAndTime/proImage"):GetComponent("Image")
    this.timeText = Util.GetGameObject(self.gameObject, "nameAndTime/timeGo/timeText"):GetComponent("Text")
    this.timeText2 = Util.GetGameObject(self.gameObject, "nameAndTime/timeGo/timeText (1)"):GetComponent("Text")
    this.timeNumText = Util.GetGameObject(self.gameObject, "nameAndTime/timeGo/timeNumText"):GetComponent("Text")
    this.timeTextGo = Util.GetGameObject(self.gameObject, "nameAndTime/timeGo")

    this.BackBtn = Util.GetGameObject(self.gameObject, "BackBtn")
    this.rewardSortBtn = Util.GetGameObject(self.gameObject, "rewardSortBtn")
    this.lootRecordBtn = Util.GetGameObject(self.gameObject, "lootRecordBtn")
    this.HelpBtn = Util.GetGameObject(self.gameObject, "HelpBtn")
    this.helpPosition=this.HelpBtn:GetComponent("RectTransform").localPosition
    this.challengeBtn = Util.GetGameObject(self.gameObject, "challengeBtn")
    this.challengeNum = Util.GetGameObject(self.gameObject, "challengeBtn/num/num"):GetComponent("Text")
    this.challengeCDTimeNum = Util.GetGameObject(self.gameObject, "challengeBtn/timeNum/num"):GetComponent("Text")
    this.challengeCDTimeNumGo = Util.GetGameObject(self.gameObject, "challengeBtn/timeNum")
    this.lootBtn = Util.GetGameObject(self.gameObject, "lootBtn")
    this.lootNum = Util.GetGameObject(self.gameObject, "lootBtn/num/num"):GetComponent("Text")
    this.lootCDTimeNum = Util.GetGameObject(self.gameObject, "lootBtn/timeNum/num"):GetComponent("Text")
    this.lootCDTimeNumGo = Util.GetGameObject(self.gameObject, "lootBtn/timeNum")

    this.tabBox = Util.GetGameObject(self.gameObject, "TabBox")
    this.TabCtrl = TabBox.New()

    this.ScrollTitleRootName = Util.GetGameObject(self.gameObject, "RankList/ScrollTitleRoot/Name"):GetComponent("Text")
    this.mySortNum = Util.GetGameObject(self.gameObject, "RankList/Record/SortNum")
    this.myGuildName = Util.GetGameObject(self.gameObject, "RankList/Record/Rank0"):GetComponent("Text")
    this.mySore = Util.GetGameObject(self.gameObject, "RankList/Record/Rank1"):GetComponent("Text")
    this.RankListPre = Util.GetGameObject(self.gameObject, "RankList/ItemPre")
    local v2 = Util.GetGameObject(self.gameObject, "RankList/ScrollParentView"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "RankList/ScrollParentView").transform,
            this.RankListPre, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 1, Vector2.New(50,8))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function GuildCarDelayMainPanel:BindEvent()
    Util.AddClick(this.BackBtn, function()
        this:ClosePanel()
    end)
    --奖励排行
    Util.AddClick(this.rewardSortBtn, function()
        UIManager.OpenPanel(UIName.GuildCarDelayRewardSortPopup)
    end)
    --抢夺记录
    Util.AddClick(this.lootRecordBtn, function()
        NetManager.CarGrapRecordResponse(function (msg)
            --for i = 1, #msg.carChallengeItem do
            
            --end
            UIManager.OpenPanel(UIName.GuildCarDelayLootRecordPopup,msg)
        end)
    end)
    --挑战
    Util.AddClick(this.challengeBtn, function()
        if curProgress ~= 1 then
            PopupTipPanel.ShowTipByLanguageId(11034)
            return
        end
        if challengeNum <= 0 then
            PopupTipPanel.ShowTipByLanguageId(11035)
            return
        end
        if GuildCarDelayManager.ChallengeCdTime > 0 then
            PopupTipPanel.ShowTip(this.TimeStampToDateString2(GuildCarDelayManager.ChallengeCdTime) .. GetLanguageStrById(11036))
            return
        end
        if curProgress == 1 then
            UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.GUILD_CAR_DELEAY)
        end
    end)
    --抢夺
    Util.AddClick(this.lootBtn, function()
        if curProgress ~= 3 then
            PopupTipPanel.ShowTipByLanguageId(11037)
            return
        end
        if lootNum <= 0 then
            PopupTipPanel.ShowTipByLanguageId(11038)
            return
        end

        if GuildCarDelayManager.LootCdTime > 0 then
            PopupTipPanel.ShowTip(this.TimeStampToDateString2(GuildCarDelayManager.LootCdTime) .. GetLanguageStrById(11039))
            return
        end
        if curProgress == 3 then
            UIManager.OpenPanel(UIName.GuildCarDelayLootPopup)
        end
    end)
    --帮助按钮
    Util.AddClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.GuildCarDelay,this.helpPosition.x,this.helpPosition.y)
    end)
    -- --boss详情
    -- Util.AddClick(this.live2dRoot, function()
    --     UIManager.OpenPanel(UIName.GuildCarDelayFindBossPopup)
    -- end)
end

--添加事件监听（用于子类重写）
function GuildCarDelayMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.CarDelayProgressChanged,this.IndicationRefreshPanel)
    -- Game.GlobalEvent:AddEvent(GameEvent.Guild.CarDelayChallengeCdStar,this.CarDelayChallengeCdStar)
    -- Game.GlobalEvent:AddEvent(GameEvent.Guild.CarDelayLootCdStar,this.CarDelayLootCdStar)
end

--移除事件监听（用于子类重写）
function GuildCarDelayMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.CarDelayProgressChanged, this.IndicationRefreshPanel)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Guild.CarDelayChallengeCdStar, this.CarDelayChallengeCdStar)
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Guild.CarDelayLootCdStar, this.CarDelayLootCdStar)
end

--界面打开时调用（用于子类重写）
function GuildCarDelayMainPanel:OnOpen(_curIndex)
    curIndex = _curIndex or 1
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildCarDelayMainPanel:OnShow()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData, curIndex)
    this.ShowTitleAllData()
    this.CarDelayChallengeCdStar()
    this.CarDelayLootCdStar()
    if GuildCarDelayManager.progress == GuildCarDelayProType.Challenge then
        this.CarDelayChallengeCdStar()
    elseif GuildCarDelayManager.progress == GuildCarDelayProType.Loot then
        this.CarDelayLootCdStar()
    end
    this.RefrePanelRedPoint()
    -- 音效
    SoundManager.PlayMusic(SoundConfig.BGM_Carbon)
end
function this.IndicationRefreshPanel()
    this.SwitchView()
    this.ShowTitleAllData()
    this.CarDelayChallengeCdStar()
    this.CarDelayLootCdStar()
    if GuildCarDelayManager.progress == GuildCarDelayProType.Challenge then
        this.CarDelayChallengeCdStar()
    elseif GuildCarDelayManager.progress == GuildCarDelayProType.Loot then
        this.CarDelayLootCdStar()
    end
    this.RefrePanelRedPoint()
end
function GuildCarDelayMainPanel:OnSortingOrderChange()
    --self.live2dRoot:GetComponent("Canvas").sortingOrder =  self.sortingOrder
    orginLayer = self.sortingOrder
end
function this.ShowTitleAllData()
    curMonsterId = GuildCarDelayManager.bossIndexId
    curMonsterIdConFig = ConfigManager.GetConfigData(ConfigName.WorldBossConfig,curMonsterId)
    this.name.text = GetLanguageStrById(heroConfig[curMonsterIdConFig.Boss].ReadingName)
    this.proImage.sprite=Util.LoadSprite(GetProStrImageByProNum(heroConfig[curMonsterIdConFig.Boss].PropertyName))
    curProgress = GuildCarDelayManager.progress
    Util.SetGray(this.challengeBtn,curProgress ~= 1)
    challengeNum = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.GUILD_CAR_DELEAY_CHALLENGE)
    lootNum = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.GUILD_CAR_DELEAY_LOOT)
    this.challengeNum.text = challengeNum
    this.lootNum.text = lootNum
    Util.SetGray(this.lootBtn,curProgress ~= 3)
    local timeText = ""
    this.timeNumText.text = ""
    this.timeText.text = ""
    this.timeText2.text = ""
    if curProgress == -5 then
        
        --if GuildCarDelayManager.battleStartTime < Today_N_OClockTimeStamp(5) + 86400 then
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timeTextGo:SetActive(true)
        this.timeText2.text = GetLanguageStrById(11040)
        --else
    elseif curProgress == -1 then
        timeText = GetLanguageStrById(11041)
        this.RemainTimeDown(this.timeTextGo,this.timeText,this.timeNumText,GuildCarDelayManager.battleStartTime - GetTimeStamp(),timeText)
        --end
    elseif curProgress == 1 then
        timeText = GetLanguageStrById(11042)
        this.RemainTimeDown(this.timeTextGo,this.timeText,this.timeNumText,GuildCarDelayManager.endTime - GetTimeStamp(),timeText)
    elseif curProgress == 2 then
        timeText = GetLanguageStrById(11043)
        this.RemainTimeDown(this.timeTextGo,this.timeText,this.timeNumText,GuildCarDelayManager.grabStartTime - GetTimeStamp(),timeText)
    elseif curProgress == 3 then
        timeText = GetLanguageStrById(11044)
        this.RemainTimeDown(this.timeTextGo,this.timeText,this.timeNumText,GuildCarDelayManager.endTime - GetTimeStamp(),timeText)
    end
        if testLiveGO then
            poolManager:UnLoadLive(GetResourcePath(heroConfig[curMonsterIdConFig.Boss].Live), testLiveGO)
        end
        testLiveGO = poolManager:LoadLive(GetResourcePath(heroConfig[curMonsterIdConFig.Boss].Live), this.live2dRoot.transform, Vector3.one*heroConfig[curMonsterIdConFig.Boss].Scale, Vector3.zero)
        this.RefrePanelRedPoint()
    end
-- tab节点显示自定义
function this.TabAdapter(tab, index, status)
    local tabLab = Util.GetGameObject(tab, "Text")
    Util.GetGameObject(tab,"Image"):GetComponent("Image").sprite = Util.LoadSprite(_TabData[index][status])
    tabLab:GetComponent("Text").text = _TabData[index].name
    tabLab:GetComponent("Text").color = _TabFontColor[status]
end
--切换视图
function this.SwitchView(index)
    curIndex = index or curIndex
    if curIndex == 2 then
        NetManager.RequestRankInfo(RANK_TYPE.GUILD_CAR_DELEAY_SINGLE, function(msg)
            this.SetRankDataShow(msg)
            --repeated UserRank ranks = 1;
            --optional RankInfo myRankInfo = 2;
            this.myGuildName.text = PlayerManager.nickName
        end)
    elseif curIndex == 1 then
        NetManager.RequestRankInfo(RANK_TYPE.GUILD_CAR_DELEAY_GUILD, function(msg)
            this.SetRankDataShow(msg)
            this.myGuildName.text = MyGuildManager.MyGuildInfo.name
        end)
    end
end
function this.SetRankDataShow(msg)
    if msg.myRankInfo.rank > 0 then
        this.mySortNum:SetActive(true)
        local sortNumTabs = {}
        for i = 1, 4 do
            sortNumTabs[i] =  Util.GetGameObject(this.mySortNum, "SortNum ("..i..")")
            sortNumTabs[i]:SetActive(false)
        end
        if msg.myRankInfo.rank < 4 then
            sortNumTabs[msg.myRankInfo.rank]:SetActive(true)
        else
            sortNumTabs[4]:SetActive(true)
            Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = msg.myRankInfo.rank
        end
    else
        this.mySortNum:SetActive(false)
    end
    this.mySore.text = msg.myRankInfo.param1 > 0 and PrintWanNum3(msg.myRankInfo.param1) or GetLanguageStrById(10148)
    this.ScrollView:SetData(msg.ranks, function (index, go)
        this.SingleRankDataShow(go, msg.ranks[index])
    end)
end
function this.SingleRankDataShow(go,userRank)
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(go, "SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if userRank.rankInfo.rank < 4 then
        sortNumTabs[userRank.rankInfo.rank]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = userRank.rankInfo.rank
    end
    if curIndex == 2 then
        Util.GetGameObject(go, "Value0"):GetComponent("Text").text = userRank.userName
        this.ScrollTitleRootName.text = GetLanguageStrById(11045)
    elseif curIndex == 1 then
        this.ScrollTitleRootName.text = GetLanguageStrById(11046)
        Util.GetGameObject(go, "Value0"):GetComponent("Text").text = userRank.guildName.."("..userRank.rankInfo.param2..")"
    end
    Util.GetGameObject(go, "Value1"):GetComponent("Text").text = PrintWanNum3(userRank.rankInfo.param1)
end
--刷新倒计时显示
function this.RemainTimeDown(_timeTextExpertgo,_timeTextExpert,timeNumText,timeDown,timeText)
    if timeDown > 0 then
        if _timeTextExpertgo then
            _timeTextExpertgo:SetActive(true)
        end
        if _timeTextExpert then
            _timeTextExpert.text =  timeText
        end
        if timeNumText then
            timeNumText.text =  this.TimeStampToDateString(timeDown)
        end
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            if _timeTextExpert then
                _timeTextExpert.text =  timeText
            end
            if timeNumText then
                timeNumText.text =  this.TimeStampToDateString(timeDown)
            end
            if timeDown < 0 then
                if _timeTextExpertgo then
                    _timeTextExpertgo:SetActive(false)
                end
                this.timer:Stop()
                this.timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        if _timeTextExpertgo then
            _timeTextExpertgo:SetActive(false)
        end
    end
end
function this.TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format("%02d:%02d:%02d", hour, minute, sec)
end
--挑战cd
function this.CarDelayChallengeCdStar()
    this.lootCDTimeNumGo:SetActive(false)
    this.challengeCDTimeNumGo:SetActive(false)
    if challengeNum > 0 then
        this.RemainTimeDown2(this.challengeCDTimeNumGo,this.challengeCDTimeNum,GuildCarDelayManager.ChallengeCdTime)
    end
end
--抢夺cd
function this.CarDelayLootCdStar()
    this.lootCDTimeNumGo:SetActive(false)
    this.challengeCDTimeNumGo:SetActive(false)
    if lootNum > 0 then
        this.RemainTimeDown2(this.lootCDTimeNumGo,this.lootCDTimeNum,GuildCarDelayManager.LootCdTime)
    end
end
this.timer2 = Timer.New()
--刷新倒计时显示
function this.RemainTimeDown2(_timeTextExpertgo,timeNumText)
    local timeDown = 0
    if GuildCarDelayManager.progress == GuildCarDelayProType.Challenge then
        timeDown = GuildCarDelayManager.ChallengeCdTime
    elseif GuildCarDelayManager.progress == GuildCarDelayProType.Loot then
        timeDown = GuildCarDelayManager.LootCdTime
    end
    if timeDown > 0 then
        if _timeTextExpertgo then
            _timeTextExpertgo:SetActive(true)
        end
        if timeNumText then
            timeNumText.text =  this.TimeStampToDateString2(timeDown)
        end
        if this.timer2 then
            this.timer2:Stop()
            this.timer2 = nil
        end
        this.timer2 = Timer.New(function()
            if timeNumText then
                timeNumText.text =  this.TimeStampToDateString2(timeDown)
            end
            if timeDown < 0 then
                if _timeTextExpertgo then
                    _timeTextExpertgo:SetActive(false)
                end
                this.timer2:Stop()
                this.timer2 = nil
            end
            if GuildCarDelayManager.progress == GuildCarDelayProType.Challenge then
                timeDown = GuildCarDelayManager.ChallengeCdTime
            elseif GuildCarDelayManager.progress == GuildCarDelayProType.Loot then
                timeDown = GuildCarDelayManager.LootCdTime
            end
        end, 1, -1, true)
        this.timer2:Start()
    else
        if _timeTextExpertgo then
            _timeTextExpertgo:SetActive(false)
        end
    end
end
function this.TimeStampToDateString2(second)
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    return string.format("%02d:%02d", minute, sec)
end
--界面关闭时调用（用于子类重写）
function GuildCarDelayMainPanel:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    if this.timer2 then
        this.timer2:Stop()
        this.timer2 = nil
    end
    poolManager:UnLoadLive(GetResourcePath(heroConfig[curMonsterIdConFig.Boss].Live), testLiveGO)
    testLiveGO = nil
end
function this.RefrePanelRedPoint()
    Util.GetGameObject(this.challengeBtn,"redPoint"):SetActive(GuildCarDelayManager.RefreshRedPoint(GuildCarDelayProType.Challenge))
    Util.GetGameObject(this.lootBtn,"redPoint"):SetActive(GuildCarDelayManager.RefreshRedPoint(GuildCarDelayProType.Loot))
    --CheckRedPointStatus(RedPointType.LegendExplore)
    Util.SetGray(Util.GetGameObject(this.challengeBtn,"redPoint"),false)
    Util.SetGray(Util.GetGameObject(this.lootBtn,"redPoint"),false)
end
--界面销毁时调用（用于子类重写）
function GuildCarDelayMainPanel:OnDestroy()
end

return GuildCarDelayMainPanel