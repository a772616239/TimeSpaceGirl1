require("Base/BasePanel")
BattleOfMinskMainPanel = Inherit(BasePanel)
local this = BattleOfMinskMainPanel

local orginLayer
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local SkillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local PassiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local PassiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local WorldHurtRewardConfig = ConfigManager.GetConfig(ConfigName.WorldHurtRewardConfig)
local ArtResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)

local curMonsterId = 1  --初始怪物ID
local curProgress = -1  --初始进度
local curMonsterIdConFig = {}   --怪物信息
local challengeNumber = 0   --挑战次数
local BuyCountNumber = 0    --可购买次数
this.timer = Timer.New()
this.timer2 = Timer.New()

--初始化组件（用于子类重写）
function BattleOfMinskMainPanel:InitComponent()
    --EnemyInfo
    this.name = Util.GetGameObject(self.gameObject, "Bg/EnemyInfo/enemyName"):GetComponent("Text")
    this.challengeTimeObj = Util.GetGameObject(self.gameObject, "Bg/EnemyInfo/challengeTime")
    this.challengeTime = Util.GetGameObject(self.gameObject, "Bg/EnemyInfo/challengeTime/Text"):GetComponent("Text")
    this.enemyIcon = Util.GetGameObject(self.gameObject, "Bg/enemyIcon")

    --RankList
    this.ranks = {}
    for i = 1, 3 do
        table.insert(this.ranks,Util.GetGameObject(self.gameObject, "Bg/RankList/rank" .. i))
    end
    this.rankBtn = Util.GetGameObject(self.gameObject, "Bg/RankList/rankBtn")

    --BossSkillList
    this.bossSkillScroll = Util.GetGameObject(self.gameObject, "BossSkillList/scroll")
    this.skillPrefab = Util.GetGameObject(self.gameObject, "BossSkillList/skillPrefab")
    local rootWidth = this.bossSkillScroll.transform.rect.width
    local rootHeight = this.bossSkillScroll.transform.rect.height
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.bossSkillScroll.transform,
            this.skillPrefab, nil, Vector2.New(rootWidth, rootHeight), 2, 1, Vector2.New(5,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.ScrollView.elastic = false

    this.storeBtn = Util.GetGameObject(self.gameObject, "StoreBtn")
    this.originBtn = Util.GetGameObject(self.gameObject, "OriginBtn")

    --FullServerHurt
    this.helpBtn = Util.GetGameObject(self.gameObject, "FullServerHurt/helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition

    this.slider = Util.GetGameObject(self.gameObject, "FullServerHurt/hurtBg/Slider"):GetComponent("Slider")
    this.fullSeverHurt = Util.GetGameObject(this.slider.gameObject, "num"):GetComponent("Text")

    this.challengeBtn = Util.GetGameObject(self.gameObject, "FullServerHurt/challengeBtn")
    this.challengeCD = Util.GetGameObject(self.gameObject, "FullServerHurt/challengeBtn/cdTime"):GetComponent("Text")
    this.mopUpBtn = Util.GetGameObject(self.gameObject, "FullServerHurt/mopUpBtn")

    this.rewardSortBtn = Util.GetGameObject(self.gameObject, "FullServerHurt/rewardSortBtn")

    this.myMaxHurt = Util.GetGameObject(self.gameObject, "FullServerHurt/myMaxHurt/hurtNum"):GetComponent("Text")

    --down
    this.challengeNum = Util.GetGameObject(self.gameObject, "FullServerHurt/down/count/num"):GetComponent("Text")
    this.challengeAddNumBtn = Util.GetGameObject(self.gameObject, "FullServerHurt/down/count/addtBtn")
    this.buyChallengeNum = Util.GetGameObject(self.gameObject, "FullServerHurt/down/buyCount/num"):GetComponent("Text")
    this.backBtn = Util.GetGameObject(self.gameObject, "FullServerHurt/down/backBtn")


    this.allHurts = {}
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.WorldHurtRewardConfig)) do
        table.insert(this.allHurts,configInfo.Hurt)
    end

    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowRight})
end

--绑定事件（用于子类重写）
function BattleOfMinskMainPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        this:ClosePanel()
    end)
    --伤害排名和奖励
    Util.AddClick(this.rankBtn, function()
        UIManager.OpenPanel(UIName.BattleOfMinskHurtSortPopup)
    end)
    --伤害奖励预览
    Util.AddClick(this.rewardSortBtn, function()
        UIManager.OpenPanel(UIName.BattleOfMinskHurtRewardSortPopup)
    end)
    --梦魇起源
    Util.AddClick(this.originBtn, function()
        UIManager.OpenPanel(UIName.BattleOfMinskDocumentPopup, GuildCarDelayManager.bossIndexId)
    end)
    --梦魇商城
    Util.AddClick(this.storeBtn, function() 
        UIManager.OpenPanel(UIName.MainShopPanel,65)
    end)

    --挑战
    Util.AddClick(this.challengeBtn, function()
        if curProgress ~= 1 then
            PopupTipPanel.ShowTipByLanguageId(11034)
            return
        end
        if challengeNumber <= 0 then
            -- PopupTipPanel.ShowTipByLanguageId(11035)
            if GuildCarDelayManager.BuyCount >= BuyCountNumber then
                -- PopupTipPanel.ShowTipByLanguageId(23085)
                PopupTipPanel.ShowTipByLanguageId(11035)
            else
                --打开购买界面
                UIManager.OpenPanel(UIName.BattleOfMinskBuyCountPopup)
            end
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

    --一键扫荡
    Util.AddClick(this.mopUpBtn, function()
        if challengeNumber <= 0 then --今日已无剩余次数！
            PopupTipPanel.ShowTipByLanguageId(12326)
        else
            if GuildCarDelayManager.hurt <= 0 then
                PopupTipPanel.ShowTipByLanguageId(23083)
                return
            end
            MsgPanel.ShowTwo(string.format(GetLanguageStrById(12331),GuildCarDelayManager.hurt), nil, function()
                GuildCarDelayManager.FastFightBattle(function ()
                    this.ShowHurtData()
                end)
            end)
        end
    end)

    --购买次数
    Util.AddClick(this.challengeAddNumBtn, function()
        --[[
        if challengeNumber > 0 then
            PopupTipPanel.ShowTipByLanguageId(23084)
        else]]if GuildCarDelayManager.BuyCount >= BuyCountNumber then
            PopupTipPanel.ShowTipByLanguageId(23085)
        else
            --打开购买界面
            UIManager.OpenPanel(UIName.BattleOfMinskBuyCountPopup)
        end
    end)

    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.BattleOfMinsk, this.helpPosition.x, this.helpPosition.y - 100)
    end)
end

--添加事件监听（用于子类重写）
function BattleOfMinskMainPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Guild.CarDelayProgressChanged,this.SetRankData)
    Game.GlobalEvent:AddEvent(GameEvent.Guild.CarDelayChallengeCdStar,this.CarDelayChallengeCdStar)
    Game.GlobalEvent:AddEvent(GameEvent.WorldBoss.RefreshChallengeInfo,this.SetChallengeData)
end

--移除事件监听（用于子类重写）
function BattleOfMinskMainPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.CarDelayProgressChanged, this.SetRankData)
    Game.GlobalEvent:RemoveEvent(GameEvent.Guild.CarDelayChallengeCdStar, this.CarDelayChallengeCdStar)
    Game.GlobalEvent:RemoveEvent(GameEvent.WorldBoss.RefreshChallengeInfo,this.SetChallengeData)
end

--界面打开时调用（用于子类重写）
function BattleOfMinskMainPanel:OnOpen()
    GuildCarDelayManager.Initialize()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function BattleOfMinskMainPanel:OnShow()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight,panelType = PanelType.Main })

    this.RefreshPanel()
    GuildCarDelayManager.GetBuyChallengeCountData()
end

function this.RefreshPanel()
    this:SetRankData()
    this.SetBossData()
    this.ShowHurtData()
    -- this.SetChallengeData()
end

function BattleOfMinskMainPanel:OnSortingOrderChange()
    orginLayer = self.sortingOrder
end

--设置排行及个人今日最高伤害
function this:SetRankData()
    --获取已购买次数和剩余挑战次数
    -- GuildCarDelayManager.GetBuyChallengeCountData()

    -- 音效
    SoundManager.PlayMusic(SoundConfig.BGM_Carbon)

    --个人伤害排行
    NetManager.RequestRankInfo(RANK_TYPE.GUILD_CAR_DELEAY_SINGLE, function(msg)
        local userRanks = msg.ranks
        if #userRanks > 0 then
            for i = 1, #this.ranks do
                local name = Util.GetGameObject(this.ranks[i], "name")
                local hurt = Util.GetGameObject(this.ranks[i], "hurt")
                local value = Util.GetGameObject(this.ranks[i], "hurt/value")
                local null = Util.GetGameObject(this.ranks[i], "null")

                name:SetActive(userRanks[i] ~= nil)
                hurt:SetActive(userRanks[i] ~= nil)
                null:SetActive(userRanks[i] == nil)
                if userRanks[i] ~= nil then
                    name:GetComponent("Text").text = userRanks[i].userName
                    value:GetComponent("Text").text = userRanks[i].rankInfo.param1
                else
                    null:GetComponent("Text").text = GetLanguageStrById(12406)
                end
            end
        end
        --个人今日最高伤害
        this.myMaxHurt.text = msg.myRankInfo.param2
        GuildCarDelayManager.hurt = msg.myRankInfo.param2
    end)
end

--设置Boss信息
function this.SetBossData()
    curMonsterId = GuildCarDelayManager.bossIndexId
    curProgress = GuildCarDelayManager.progress
    curMonsterIdConFig = ConfigManager.GetConfigData(ConfigName.WorldBossConfig, curMonsterId)

    this.name:GetComponent("Text").text = GetLanguageStrById(curMonsterIdConFig.Name)

    --boss技能
    local skills = {}
    for i, v in ipairs(curMonsterIdConFig.BossSkill) do
        skills[v[1]] = v[2]
    end
    for i, v in ipairs(curMonsterIdConFig.BossPassiveSkill) do
        skills[v[1]] = v[2]
    end
    this.ScrollView:SetData(skills, function (index, go)
        if index % 2 == 0 then
            this.ShowSkillData(go, skills[index], PassiveSkillConfig, PassiveSkillLogicConfig)
        else
            this.ShowSkillData(go, skills[index], SkillConfig, SkillLogicConfig)
        end
    end)

    if not this.liveObj then
        this.liveObj = LoadHerolive(heroConfig[curMonsterIdConFig.Boss], this.enemyIcon)
    end
end

--显示怪物技能信息
function this.ShowSkillData(go, data, config, LogicConfig)
    local icon = Util.GetGameObject(go, "icon"):GetComponent("Image")
    local resId = config[data].Icon
    icon.sprite = Util.LoadSprite(ArtResourcesConfig[resId].Name)
    Util.AddClick(go, function()
        local heroSkill = {}
        heroSkill.skillConfig = config[data]
        heroSkill.lock = true
        UIManager.OpenPanel(UIName.SkillInfoPopup,heroSkill,1,10,1,1,LogicConfig[data].Level)
    end)
end

--设置挑战信息
function this.SetChallengeData()
    challengeNumber = GuildCarDelayManager.challengeNumber
    BuyCountNumber = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.GUILD_CAR_DELEAY_BuyCount)

    Util.SetGray(this.challengeBtn,curProgress ~= 1)
    this.challengeNum.text = challengeNumber
    this.buyChallengeNum.text = BuyCountNumber - GuildCarDelayManager.BuyCount
    -- 可购买次数
    Util.SetGray(this.challengeAddNumBtn, --[[challengeNumber > 0 or]]  BuyCountNumber - GuildCarDelayManager.BuyCount <= 0)
    --一键扫荡
    Util.SetGray(this.mopUpBtn, GuildCarDelayManager.hurt <= 0 or challengeNumber <= 0)
end

function this.ShowHurtData()
    --全服累计伤害
    local _allHurts = 0
    local _fullSeverHurt = GuildCarDelayManager.totalHurt
    local dataLength = LengthOfTable(this.allHurts)
    for i = 1, dataLength  do
        if _fullSeverHurt < this.allHurts[dataLength+1-i] then
            _allHurts = this.allHurts[dataLength+1-i]
        end
    end
    this.slider.value = _fullSeverHurt/_allHurts
    this.fullSeverHurt.text = _fullSeverHurt .. "/" .. _allHurts

    --时间倒计时
    local time = ""
    this.challengeTime.text = ""
    -- if curProgress == -1 then
    --     --挑战开启时间
    --     local week = GetTimeWeekBySeconds(GetTimeStamp())
    --     time = string.format(GetLanguageStrById(23087), GetLanguageStrById(curMonsterIdConFig.Name), week)
    --     this.RemainTimeDown(
    --         this.challengeTimeObj,
    --         this.challengeTime,
    --         GuildCarDelayManager.battleStartTime - GetTimeStamp(),
    --         time
    --     )
    -- elseif curProgress == 1 then
        --挑战剩余时间
        -- time = GetLanguageStrById(curMonsterIdConFig.Name)..GetLanguageStrById(11042)
        this.RemainTimeDown(
            this.challengeTimeObj,
            this.challengeTime,
            GuildCarDelayManager.endTime - GetTimeStamp()
        )
    -- end
end

--刷新挑战BOSS倒计时显示
function this.RemainTimeDown(_timeObj, _timeTxt, _timeDown)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    if _timeDown > 0 then
        _timeObj:SetActive(true)
        _timeTxt.text = TimeToHMS(_timeDown)
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            _timeTxt.text = TimeToHMS(_timeDown)
            if _timeDown < 0 then
                _timeObj:SetActive(false)
                this.timer:Stop()
                this.timer = nil
            end
            _timeDown = _timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        _timeObj:SetActive(false)
    end
end

--挑战CD
function this.CarDelayChallengeCdStar()
    this.challengeCD.gameObject:SetActive(false)
    if challengeNumber > 0 then
        this.RemainTimeDown2(this.this.challengeCD)
    else
        this.challengeCD.gameObject:SetActive(true)
    end
end

--刷新挑战CD倒计时显示
function this.RemainTimeDown2(_timeTxt)
    local timeDown = 0
    if GuildCarDelayManager.progress == GuildCarDelayProType.Challenge then
        timeDown = GuildCarDelayManager.ChallengeCdTime
    end
    if timeDown > 0 then
        this.challengeCD.gameObject:SetActive(true)
        _timeTxt.text = this.TimeStampToDateString2(timeDown)

        if this.timer2 then
            this.timer2:Stop()
            this.timer2 = nil
        end
        this.timer2 = Timer.New(function()
            _timeTxt.text = this.TimeStampToDateString2(timeDown)

            if timeDown < 0 then
                this.challengeCD.gameObject:SetActive(false)
                this.timer2:Stop()
                this.timer2 = nil
            end
            if GuildCarDelayManager.progress == GuildCarDelayProType.Challenge then
                timeDown = GuildCarDelayManager.ChallengeCdTime
            end
        end, 1, -1, true)
        this.timer2:Start()
    else
        this.challengeCD.gameObject:SetActive(false)
    end
end

function this.TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format("%02d:%02d:%02d", hour, minute, sec)
end

function this.TimeStampToDateString2(second)
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    return string.format("%02d:%02d", minute, sec)
end

function this.QuickWar()
    GuildCarDelayManager.FastFightBattle()
end

--界面关闭时调用（用于子类重写）
function BattleOfMinskMainPanel:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    if this.timer2 then
        this.timer2:Stop()
        this.timer2 = nil
    end

    if this.liveObj and heroConfig[curMonsterIdConFig.Boss] then
        UnLoadHerolive(heroConfig[curMonsterIdConFig.Boss],this.enemyIcon)
        this.liveObj = nil
    end
end

--界面销毁时调用（用于子类重写）
function BattleOfMinskMainPanel:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
end

return BattleOfMinskMainPanel