require("Base/BasePanel")
HegemonyChallengePopup = Inherit(BasePanel)
local this = HegemonyChallengePopup
local posInfo--位置信息
local ScrollView2 = {}
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local FormationConfig = ConfigManager.GetConfig(ConfigName.FormationConfig)

function HegemonyChallengePopup:InitComponent()
    this.scrollShow = Util.GetGameObject(self.gameObject, "ScrollShow")
    this.itemPre = Util.GetGameObject(self.gameObject, "itemPre")
    this.item = Util.GetGameObject(self.gameObject,"item")
    this.backBtn = Util.GetGameObject(self.gameObject, "backBtn")

    local rect = this.scrollShow.transform.rect
    this.ScrollView1 = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollShow.transform,
            this.itemPre, nil, Vector2.New(rect.width, rect.height), 1, 1, Vector2.New(0,5))
    this.ScrollView1.moveTween.MomentumAmount = 1
    this.ScrollView1.moveTween.Strength = 1
end

function HegemonyChallengePopup:BindEvent()
    Util.AddClick(this.backBtn,function()
            self:ClosePanel()
    end)
end

function HegemonyChallengePopup:AddListener()
end

function HegemonyChallengePopup:RemoveListener()

end

function HegemonyChallengePopup:OnSortingOrderChange()
    this.sortingOrder = self.sortingOrder
end

function HegemonyChallengePopup:OnOpen(...)
    local arg = {...}
    local msg = arg[1]
    this.rank = arg[2]
    this.pos = arg[3]
    this.fightId = arg[4]
    this.dataInfo = msg.personInfo

    if this.dataInfo ~= nil then
        this.ScrollView1:SetData(this.dataInfo, function (index, go)
            HegemonyChallengePopup:SetItemPreData(go, this.dataInfo[index])
        end)
    else
        --TODO提示空记录
    end

end

function HegemonyChallengePopup:OnShow()
    
end

function HegemonyChallengePopup:OnClose()
end

function HegemonyChallengePopup:OnDestroy()
    ScrollView2 = {}
end

function HegemonyChallengePopup:SetItemPreData(gameObject,data)
    gameObject:SetActive(true)
    this.challengeName = Util.GetGameObject(gameObject, "ChallengeName/Text")
    this.challengeTime = Util.GetGameObject(gameObject, "ChallengeTime")
    this.battle = Util.GetGameObject(gameObject, "InfoShow/battle/Text")
    this.formationName = Util.GetGameObject(gameObject, "InfoShow/formationName/Text")
    this.challengeResNum = Util.GetGameObject(gameObject, "InfoShow/challengeRes/Text")
    this.scroll = Util.GetGameObject(gameObject, "Scroll")
    this.playbackBtn = Util.GetGameObject(gameObject, "playbackBtn")

    this.challengeName:GetComponent("Text").text = data.name
    this.challengeTime:GetComponent("Text").text = GetTimeStrBySeconds(data.time) 
    this.battle:GetComponent("Text").text = data.allHeroForce
    this.formationName:GetComponent("Text").text = GetLanguageStrById(FormationConfig[data.formationId].name)

    this.challengeRes = Util.GetGameObject(gameObject, "InfoShow/challengeRes")
    if data.resultCode == 1 then
        this.challengeRes:GetComponent("Text").text = GetLanguageStrById(12613)
        this.challengeResNum:GetComponent("Text").text = data.level
    else
        this.challengeRes:GetComponent("Text").text = GetLanguageStrById(12614)
        this.challengeResNum:GetComponent("Text").text = data.level
    end
    local heroInfos = data.heros

    local rect = this.scroll.transform.rect
    if ScrollView2[gameObject] == nil then
       ScrollView2[gameObject] = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scroll.transform,
       this.item, nil, Vector2.New(rect.width, rect.height), 2, 1, Vector2.New(0,0))
       ScrollView2[gameObject].moveTween.MomentumAmount = 1
       ScrollView2[gameObject].moveTween.Strength = 1
    end
    ScrollView2[gameObject]:SetData(heroInfos, function (index, go)
        HegemonyChallengePopup:ShowItemData(go, heroInfos[index])
    end)

    Util.AddClick(this.playbackBtn,function()
        BattleManager.GotoFight(function()
            --> fightInfo
            local structA = {
                head = data.head,
                headFrame = data.headFrame,
                name = data.name,
                formationId = data.formationId,
                investigateLevel=data.investigateLevel
            }
            local _monsterGroupId = G_SupremacyConfig[this.fightId].Monster
            local monsterShowId = GetMonsterGroupFirstEnemy(_monsterGroupId)
            local heroid = G_MonsterConfig[monsterShowId].MonsterId
            local image = GetResourcePath(G_HeroConfig[heroid].Icon)
            local structB = {
                head = tostring(image),
                headFrame = nil,
                name = nil,
                formationId = G_MonsterGroup[_monsterGroupId].Formation,
                investigateLevel=1
            }
            BattleManager.SetAgainstInfoData(BATTLE_TYPE.BACK, structA, structB)

            HegemonyManager.RequestRecordFightData(data.resultCode,data.time,this.rank,this.pos, nameStr, function()
            end)
        end)
        
    end)
end

function HegemonyChallengePopup:ShowItemData(gameObject,data)
    gameObject:SetActive(true)
    local heroConfigData = HeroConfig[data.heroId]
    this.frame = Util.GetGameObject(gameObject, "frame"):GetComponent("Image")
    this.icon = Util.GetGameObject(gameObject, "icon"):GetComponent("Image")
    this.proIconBg = Util.GetGameObject(gameObject, "proIconBg"):GetComponent("Image")
    this.proIcon = Util.GetGameObject(gameObject, "proIconBg/proIcon"):GetComponent("Image")
    -- this.name = Util.GetGameObject(gameObject, "name"):GetComponent("Text")
    this.lvBg = Util.GetGameObject(gameObject, "lv"):GetComponent("Image")
    this.lv = Util.GetGameObject(gameObject, "lv/Text"):GetComponent("Text")
    this.star = Util.GetGameObject(gameObject, "star")

    this.frame.sprite = Util.LoadSprite(GetHeroQuantityImageByquality(heroConfigData.Quality,data.star))
    this.icon.sprite = Util.LoadSprite(GetResourcePath(heroConfigData.Icon))
    this.proIcon.sprite = Util.LoadSprite(GetProStrImageByProNum(heroConfigData.PropertyName))
    -- this.name.text = GetLanguageStrById(heroConfigData.ReadingName)
    this.lv.text = data.level
    SetHeroStars(this.star, data.star)
    this.proIconBg.sprite = Util.LoadSprite(GetQuantityProBgImageByquality(heroConfigData.Quality,data.star))
    this.lvBg.sprite = Util.LoadSprite(GetQuantityImageByqualityHexagon(heroConfigData.Quality,data.star))
end

return HegemonyChallengePopup