require("Base/BasePanel")
HegemonyPopup = Inherit(BasePanel)
local this = HegemonyPopup
local posInfo--位置信息
local players--对应位置上的人物uid

local SupremacyConfig = ConfigManager.GetConfig(ConfigName.SupremacyConfig)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local ArtResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local SkillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local PassiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local PropertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local PassiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)

--上一子模块索引
local curIndex = 0
--Title资源名
local heroEndBtns = {}
local playerHead
local evolveBtn = {}
local evolveNum
local oldSelect
local HeroConfigData
local _liveObj

function HegemonyPopup:InitComponent()
    this.backBtn = Util.GetGameObject(self.gameObject, "BackBtn")

    this.tip = Util.GetGameObject(self.gameObject, "BG/Tips/Text"):GetComponent("Text")

    this.btns = Util.GetGameObject(self.gameObject, "btns")
    this.arenaBtn = Util.GetGameObject(this.btns, "arenaBtn")
    this.alreadyChallenge = Util.GetGameObject(this.btns, "alreadyChallenge")
    this.challengeBtn = Util.GetGameObject(this.btns, "challengeBtn")

    this.hint = Util.GetGameObject(this.btns, "hint"):GetComponent("Text")

    --boss展示
    this.bossIcon = Util.GetGameObject(self.gameObject, "bossIcon/pos")
    this.recordBtn = Util.GetGameObject(self.gameObject, "bossIcon/recordBtn")

    this.sklls = Util.GetGameObject(self.gameObject, "skills")
    this.skill = Util.GetGameObject(this.sklls, "skillPre")

    --称号信息
    this.pros = Util.GetGameObject(self.gameObject, "Pros")
    this.pro1 = Util.GetGameObject(this.pros, "pros/pro1")
    this.pro2 = Util.GetGameObject(this.pros, "pros/pro2")
    this.titleGrade = Util.GetGameObject(this.pros, "titleGrade"):GetComponent("Image")

    --占有者头像
    this.head = Util.GetGameObject(this.pros, "possessorHead")
    playerHead = SubUIManager.Open(SubUIConfig.PlayerHeadView, this.head.transform)
    this.name = Util.GetGameObject(this.pros, "possessorHead/name")
    this.noPlayer = Util.GetGameObject(this.pros, "possessorHead/noPlayer")

    local count = {1,5,10}
    evolveBtn = {}
    --进化次数按钮
    for i = 1, 3 do
        table.insert(evolveBtn,{Util.GetGameObject(this.pros, "evolveBtns/evolveBtn"..i),count[i]})
    end

    --主动技能 被动技能
    local Scroll = Util.GetGameObject(self.gameObject, "Scroll/SkillShow").transform
    this.ScrollView1 = SubUIManager.Open(SubUIConfig.ScrollCycleView, Scroll,
            this.skill, nil, Vector2.New(Scroll.rect.width, Scroll.rect.height), 2, 1, Vector2.New(5,0))
    this.ScrollView1.moveTween.MomentumAmount = 1
    this.ScrollView1.moveTween.Strength = 1


    local PassiveSkillScroll = Util.GetGameObject(self.gameObject, "PassiveSkillScroll/PassiveSkillShow").transform
    this.ScrollView2 = SubUIManager.Open(SubUIConfig.ScrollCycleView, PassiveSkillScroll,
            this.skill, nil, Vector2.New(PassiveSkillScroll.rect.width, PassiveSkillScroll.rect.height), 2, 1, Vector2.New(5,0))
    this.ScrollView2.moveTween.MomentumAmount = 1
    this.ScrollView2.moveTween.Strength = 1
end

function HegemonyPopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.recordBtn,function()
        NetManager.GetSupremacyBattleRecordRequest(posInfo.rank,posInfo.pos,function(msg) 
            UIManager.OpenPanel(UIName.HegemonyChallengePopup,msg,posInfo.rank,posInfo.pos, posInfo.id)
        end)
    end)
    Util.AddClick(this.arenaBtn,function()
        UIManager.OpenPanel(UIName.ArenaMainPanel)
    end)
    Util.AddClick(this.challengeBtn,function()
        if this.isOccupy then
            UIManager.OpenPanel(UIName.HegemonyTipPopup,FORMATION_TYPE.CONTEND_HEGEMONY,posInfo.id,posInfo.rank,posInfo.pos,evolveNum)
        else
            UIManager.OpenPanel(UIName.FormationPanelV2,FORMATION_TYPE.CONTEND_HEGEMONY,posInfo.id,posInfo.rank,posInfo.pos,evolveNum)--root fightid 三强争霸层级 三强争霸位置，加强等级
        end
    end)

    for i = 1, #evolveBtn do
        Util.AddClick(evolveBtn[i][1],function()
            local select = Util.GetGameObject(evolveBtn[i][1], "Image")
            evolveNum = evolveBtn[i][2]
            oldSelect:SetActive(false)
            oldSelect = select
            select:SetActive(true)
        end)
    end
end

function HegemonyPopup:AddListener()
end

function HegemonyPopup:RemoveListener()

end

function HegemonyPopup:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end

function HegemonyPopup:OnOpen(...)
    local arg = {...}
    posInfo = arg[1]
    players = arg[2]

    this.challengeBtn:SetActive(true)
    this.alreadyChallenge:SetActive(false)
    this.recordBtn:SetActive(false)
    HegemonyPopup:SetData(posInfo)
    for i = 1, #players do
        if players[i] == PlayerManager.uid then
           this.isOccupy = true
           return
        else
            this.isOccupy = false
        end
    end
end

function HegemonyPopup:OnShow()
    HegemonyManager.GetFightId(posInfo.id)
    oldSelect = Util.GetGameObject(evolveBtn[1][1], "Image")
    oldSelect:SetActive(true)
    evolveNum = 1
    HegemonyPopup:SetData(posInfo)
end

function HegemonyPopup:OnClose()
    oldSelect:SetActive(false)
    evolveNum = 1
    this.challengeBtn:SetActive(true)
    this.alreadyChallenge:SetActive(false)
    this.recordBtn:SetActive(false)

    UnLoadHerolive(HeroConfigData,_liveObj)
    Util.ClearChild(this.bossIcon.transform)
    HeroConfigData = nil
    _liveObj = nil
end

function HegemonyPopup:OnDestroy()

end

function HegemonyPopup:SetData(posInfo)
    --posInfo 位置信息
    local _,myRank = ArenaManager.GetRankInfo()
    local rank = myRank.personInfo.rank
    local SupremacyConfigData = SupremacyConfig[posInfo.id]
    HeroConfigData = HeroConfig[SupremacyConfigData.BossShow] 
    this.tip.text = posInfo.level --GetLanguageStrById(12620)..posInfo.level..GetLanguageStrById(12621)
    this.hint.text = GetLanguageStrById(12622)..SupremacyConfigData.NeedArenaRank..GetLanguageStrById(12623)..rank.."</color> )"
    this.titleGrade.sprite = Util.LoadSprite(SupremacyConfigData.Title)
    local playerData = posInfo.personInfo

    playerHead:Reset()
    playerHead:SetScale(Vector3.one * 0.65)
    playerHead:SetHead(playerData.head)
    playerHead:SetFrame(playerData.headFrame)
    if posInfo.uid ~= 0 then
        playerHead.gameObject:SetActive(true)
        this.name:SetActive(true)
        this.recordBtn:SetActive(true)
        this.noPlayer:SetActive(false)
        this.name:GetComponent("Text").text = playerData.name
       if posInfo.uid == PlayerManager.uid then
          this.challengeBtn:SetActive(false)
          this.alreadyChallenge:SetActive(true)
       end
    else
        this.noPlayer:SetActive(true)
        playerHead.gameObject:SetActive(false)
        this.name:SetActive(false)
    end

    Util.GetGameObject(this.pro1,"name"):GetComponent("Text").text = GetLanguageStrById(PropertyConfig[posInfo.props[1].key].Info)
    Util.GetGameObject(this.pro2,"name"):GetComponent("Text").text = GetLanguageStrById(PropertyConfig[posInfo.props[2].key].Info)
    Util.GetGameObject(this.pro1,"value"):GetComponent("Text").text =  "+" .. GetPropertyFormatStr(posInfo.props[1].key,posInfo.props[1].value)
    Util.GetGameObject(this.pro2,"value"):GetComponent("Text").text =  "+" .. GetPropertyFormatStr(posInfo.props[2].key,posInfo.props[2].value)

    local skills = SupremacyConfigData.SkillShow
    this.ScrollView1:SetData(skills, function (index, go)
        HegemonyPopup:ShowSkillData(go, skills[index],SkillConfig,SkillLogicConfig)
    end)

    local skills2 = SupremacyConfigData.PassiveSkillShow
    this.ScrollView2:SetData(skills2, function (index, go)
        HegemonyPopup:ShowSkillData(go, skills2[index],PassiveSkillConfig,PassiveSkillLogicConfig)
    end)

    if HeroConfigData and _liveObj then
        UnLoadHerolive(HeroConfigData,_liveObj)
        Util.ClearChild(this.bossIcon.transform)
    end
    _liveObj = LoadHerolive(HeroConfigData,this.bossIcon.transform)
end

function HegemonyPopup:ShowSkillData(gameObject,data,config,LogicConfig)
    gameObject:SetActive(true)
    -- local frame = Util.GetGameObject(gameObject, "frame")
    local icon = Util.GetGameObject(gameObject, "icon"):GetComponent("Image")
    local resId = config[data].Icon
    icon.sprite = Util.LoadSprite(ArtResourcesConfig[resId].Name)
    Util.AddClick(gameObject, function()
       -- if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
        --    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
        --end
        local heroSkill = {}
        heroSkill.skillConfig = config[data]
        heroSkill.lock = true
        --TODO打开技能面板信息
        local panel = UIManager.OpenPanel(UIName.SkillInfoPopup,heroSkill,1,10,1,1,LogicConfig[data].Level)

        --Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    end)
end

return HegemonyPopup