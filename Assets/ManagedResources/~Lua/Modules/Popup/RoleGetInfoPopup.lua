require("Base/BasePanel")
RoleGetInfoPopup = Inherit(BasePanel)
local this = RoleGetInfoPopup
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artResourcesConfig = ConfigManager.GetConfig(ConfigName.ArtResourcesConfig)
local SkillLogicConfig = ConfigManager.GetConfig(ConfigName.SkillLogicConfig)
local PassiveSkillLogicConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillLogicConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local passiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local HeroRankupConfig = ConfigManager.GetConfig(ConfigName.HeroRankupConfig)
local heroBackData
local isGet
local heroSId
local heroStar
local heroRunkup -- 英雄品阶
local breakId
local allSkillDatas = {}
local heroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
local _heroData

--初始化组件（用于子类重写）
function RoleGetInfoPopup:InitComponent()
    this.BtnBack = Util.GetGameObject(self.transform, "btnBack")
    this.liveRoot = Util.GetGameObject(self.transform, "RoleInfo/liveRoot")
    this.heroName = Util.GetGameObject(self.transform, "RoleInfo/name/heroName"):GetComponent("Text")
    this.starGrid = Util.GetGameObject(self.transform, "RoleInfo/name/starGrid")
    -- this.starPre = Util.GetGameObject(self.transform, "bg/NameButtom/starPre")
    -- this.starGrid = Util.GetGameObject(self.transform, "RoleInfo/sartAndLvLayout")
    
    --定位描述
    this.posText = Util.GetGameObject(self.transform,"RoleInfo/proIcon/Text"):GetComponent("Text")
    this.profession = Util.GetGameObject(self.transform, "RoleInfo/proIcon"):GetComponent("Image")
    this.proImage = Util.GetGameObject(self.transform, "RoleInfo/name/proImage"):GetComponent("Image")
    -- this.recommend = Util.GetGameObject(self.transform, "recommend")
    -- this.qualityImage = Util.GetGameObject(self.transform,"quality"):GetComponent("Image")
    -- this.quality = Util.GetGameObject(self.transform,"quality/qualityText")
    -- this.doubleQuality = Util.GetGameObject(self.transform,"quality/qualityDoubleText")
    -- this.heroTypeText = Util.GetGameObject(self.transform,"RoleInfo/heroTypeText"):GetComponent("Text")

    -- Util.GetGameObject(self.transform,"bg/RoleInfo/pro/atk/proName"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[2].Info)
    -- Util.GetGameObject(self.transform,"bg/RoleInfo/pro/hp/proName"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[1].Info)
    -- Util.GetGameObject(self.transform,"bg/RoleInfo/pro/phyDef/proName"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[3].Info)
    -- Util.GetGameObject(self.transform,"bg/RoleInfo/pro/magDef/proName"):GetComponent("Text").text = GetLanguageStrById(propertyConfig[4].Info)
    -- Util.GetGameObject(self.transform,"bg/RoleInfo/pro/speed/proName"):GetComponent("Text").text = propertyConfig[5].Info
    this.atk = Util.GetGameObject(self.transform, "RoleInfo/pro/atk/proValue"):GetComponent("Text")
    this.hp = Util.GetGameObject(self.transform, "RoleInfo/pro/hp/proValue"):GetComponent("Text")
    this.phyDef = Util.GetGameObject(self.transform, "RoleInfo/pro/phyDef/proValue"):GetComponent("Text")
    -- this.magDef = Util.GetGameObject(self.transform, "RoleInfo/pro/magDef/proValue"):GetComponent("Text")
    this.speed = Util.GetGameObject(self.transform, "RoleInfo/pro/speed/proValue"):GetComponent("Text")

    this.skillPanel = Util.GetGameObject(self.transform, "RoleInfo/skill")
    -- this.skill1 = Util.GetGameObject(self.transform, "bg/RoleInfo/skill/s1")
    -- this.skill2 = Util.GetGameObject(self.transform, "bg/RoleInfo/skill/s2")
    -- this.selsectSkillImage = Util.GetGameObject(self.transform, "selsectSkillImage")

    -- this.radar = Util.GetGameObject(self.transform, "bg/RoleInfo/proRadarImage/radar"):GetComponent("RadarChart")
    -- self.skillName = Util.GetGameObject(self.transform,"RoleInfo/skillName")
    -- self.skillLine = Util.GetGameObject(self.transform,"RoleInfo/skillLine")

    this.skillGrid = Util.GetGameObject(self.transform,"RoleInfo/skill/skillGroup")
    -- this.skill1 = Util.GetGameObject(this.skillGrid, "sBg1/SkillTypeImage")
    -- this.skill2 = Util.GetGameObject(this.skillGrid, "sBg2/SkillTypeImage")
    this.skill1 = Util.GetGameObject(this.skillGrid, "Skill1")
    this.skill2 = Util.GetGameObject(this.skillGrid, "Skill2")
    this.skill3 = Util.GetGameObject(this.skillGrid, "Skill3")
    this.skill4 = Util.GetGameObject(this.skillGrid, "Skill4")
    -- this.selsectSkillImage = Util.GetGameObject(self.transform,"RoleInfo/selsectSkillImage")
    -- this.talismanBtn = Util.GetGameObject(self.transform,"RoleInfo/Panel/Other/TalismanBtn")
    -- this.talismanFrame = Util.GetGameObject(self.transform,"RoleInfo/Panel/Other/TalismanBtn"):GetComponent("Image")
    -- this.talismanIcon = Util.GetGameObject(self.transform,"RoleInfo/Panel/Other/TalismanBtn/Icon"):GetComponent("Image")
    -- this.talentBtn = Util.GetGameObject(self.transform,"RoleInfo/Panel/Other/talentBtn")
    -- this.talentProgress = Util.GetGameObject(self.transform,"RoleInfo/Panel/Other/talentBtn/progress"):GetComponent("Text")
    this.btnGet = Util.GetGameObject(self.transform, "RoleInfo/btnGet")

    this.core = Util.GetGameObject(self.transform, "RoleInfo/core")

    this.btnComment = Util.GetGameObject(self.transform, "CommentBtn")
end

local heroSData
local triggerCallBack
--绑定事件（用于子类重写）
function RoleGetInfoPopup:BindEvent()
    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)

    Util.AddClick(this.btnGet, function ()
        UIManager.OpenPanel(UIName.JumpSelectPopup, false, heroSId)
    end)

    -- Util.AddClick(this.skill1, function()
    --     if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
    --         Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --     end
    --     this:SetSkillSelectImage(this.skill1.transform,true)
    --     local skillData=allSkillDatas[1]
    --     local maxLv= HeroManager.GetHeroSkillMaxLevel(heroSId, skillData.skillConfig.Type)
    --     local panel = UIManager.OpenPanel(UIName.SkillInfoPopup,skillData,3,10,maxLv,1)
    --     this.skillGrid:GetComponent("Canvas").sortingOrder = panel.sortingOrder + 1
    --     triggerCallBack = function (panelType, p)
    --         if panelType == UIName.SkillInfoPopup and p == panel then --监听到SkillInfoPopup关闭，把层级设回去
    --             this.skillGrid:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
    --             Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --             this:SetSkillSelectImage(self.transform,false)
    --         end
    --     end
    --     Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    -- end)
    -- Util.AddClick(this.skill2, function()
    --     if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
    --         Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --     end
    --     this:SetSkillSelectImage(this.skill2.transform,true)
    --     local skillData=allSkillDatas[2]
    --     local maxLv= HeroManager.GetHeroSkillMaxLevel(heroSId, skillData.skillConfig.Type)
    --     local panel = UIManager.OpenPanel(UIName.SkillInfoPopup,skillData,3,10,maxLv,2)
    --     this.skillGrid:GetComponent("Canvas").sortingOrder = panel.sortingOrder + 1
    --     triggerCallBack = function (panelType, p)
    --         if panelType == UIName.SkillInfoPopup and p == panel then --监听到SkillInfoPopup关闭，把层级设回去
    --             this.skillGrid:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
    --             Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --             this:SetSkillSelectImage(self.transform,false)
    --         end
    --     end
    --     Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    -- end)
    Util.AddClick(this.btnComment, function ()
        UIManager.OpenPanel(UIName.CommentPanel, heroSData)
    end)
end
--添加事件监听（用于子类重写）
function RoleGetInfoPopup:AddListener()

end

--移除事件监听（用于子类重写）
function RoleGetInfoPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function RoleGetInfoPopup:OnOpen(...)
    local data = {...}
    isGet = data[1]
    if isGet then
        heroBackData = data[2]
        heroSId = heroBackData.heroId
        heroStar = heroBackData.star
        --heroRunkup = HeroRankupConfig[heroBackData.breakId].Phase[2]
        breakId = heroBackData.breakId
    else
        heroSId = data[2]
        heroStar = data[3]
        if heroStar > 6 then
            local heroRankupConfigs = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.HeroRankupConfig,"Type",2,"OpenStar",heroStar)
            if #heroRankupConfigs > 0 then
                local max = heroRankupConfigs[#heroRankupConfigs]
                breakId = max.Id
            else
                breakId = heroRankupConfigs[1].Id
            end
        else
            local heroRankupConfigs = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.HeroRankupConfig,"Type",1,"OpenStar",heroStar)
            if #heroRankupConfigs > 0 then
                local max = heroRankupConfigs[#heroRankupConfigs]
                breakId = max.Id
            end
        end
    end
    LogGreen("英雄ID："..heroSId)
    heroSData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroSId)
end

function RoleGetInfoPopup:OnShow()
    local isZero = ConfigManager.GetConfigData("HeroConfig",heroSId).PropertyName
    if isZero == 0 then
        this.skillPanel:SetActive(false)
        local heroSData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroSId)
        this.ShowHeroLive(heroSData)
        SetHeroStars(this.starGrid, heroStar)
        --属性
        this.atk.text = 1
        this.hp.text = 1
        this.phyDef.text = 1
        -- this.magDef.text = 1
        this.speed.text = 1
        return
    end
    this.skillPanel:SetActive(true)
    allSkillDatas = HeroManager.GetCurHeroSidAndCurStarAllSkillDatas(heroSId,heroStar)
    heroSData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroSId)
    if isGet then
        this.GetShowPanelData()
            --天赋
        -- this.talentBtn:SetActive(heroSData.OpenPassiveSkillRules ~= nil)
        -- if heroSData.OpenPassiveSkillRules then
        --     local openlists,compoundOpenNum,compoundNum = HeroManager.GetAllPassiveSkillIds(heroSData,0,0)
        --     this.talentProgress.text = #openlists - compoundOpenNum .."/"..#heroSData.OpenPassiveSkillRules - compoundNum
        -- end
        -- Util.AddOnceClick(this.talentBtn,function()
        --     UIManager.OpenPanel(UIName.RoleTalentPopup,heroSData,0,0)
        -- end)
    else
        this.NoGetShowPanelData()
    end

    --技能 布局变动
    -- self.skillLine.gameObject:SetActive(not (heroSData.OpenPassiveSkillRules == nil and heroSData.EquipTalismana==nil))
    -- if heroSData.OpenPassiveSkillRules == nil and heroSData.EquipTalismana==nil then
    --     -- Util.GetGameObject(self.transform,"RoleInfo/Panel/Skill"):GetComponent("LayoutElement").minWidth=500
    --     -- Util.GetGameObject(self.transform,"RoleInfo/Panel/Skill/skill"):GetComponent("GridLayoutGroup").startAxis=0
    --     self.skillName.transform:DOAnchorPos(Vector3.New(230,158,0),0)
    -- else
    --     -- Util.GetGameObject(self.transform,"RoleInfo/Panel/Skill"):GetComponent("LayoutElement").minWidth=150
    --     -- Util.GetGameObject(self.transform,"RoleInfo/Panel/Skill/skill"):GetComponent("GridLayoutGroup").startAxis=1
    --     self.skillName.transform:DOAnchorPos(Vector3.New(90,158,0),0)
    -- end

    --技能点击特殊处理
    -- this.selsectSkillImage:SetActive(false)
    -- this.skillGrid:GetComponent("Canvas").sortingOrder = self.sortingOrder + 1
    -- local triggerCallBack
    -- local skillList = HeroManager.GetCurHeroSidAndCurStarAllSkillDatas(heroSData.Id,heroSData.Star)
    -- for i = 1, this.skillGrid.transform.childCount do
    --     this.skillGrid.transform:GetChild(i-1).gameObject:SetActive(false)
    -- end
    -- for i = 1, #skillList do
    --     if skillList[i] and skillList[i].skillConfig and skillList[i].skillConfig.Name then
    --         local go = this.skillGrid.transform:GetChild(i-1).gameObject
    --         go:SetActive(true)
    --         Util.GetGameObject(go.transform,"Icon"):GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(skillList[i].skillConfig.Icon))
    --         Util.GetGameObject(go.transform,"skillNameTx"):GetComponent("Text").text=skillList[i].skillConfig.Name--GetLanguageStrById(10470).. 1(skillList[i].skillConfig.Id % 10)
    --         -- Util.GetGameObject(go.transform,"SkillTypeImage"):GetComponent("Image").sprite=Util.LoadSprite(GetSkillType(allSkillDatas[i]))
    --         if SkillLogicConfig[skillList[i].skillConfig.Id]~=nil then
    --             Util.GetGameObject(go.transform,"Lv/LvTx"):GetComponent("Text").text = SkillLogicConfig[skillList[i].skillConfig.Id].Level
    --         else
    --             Util.GetGameObject(go.transform,"Lv/LvTx"):GetComponent("Text").text = PassiveSkillLogicConfig[skillList[i].skillConfig.Id].Level
    --         end
    --         Util.AddOnceClick(Util.GetGameObject(go.transform,"frame"), function()
    --             if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
    --                 Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --             end
    --             this.selsectSkillImage:SetActive(true)
    --             this.selsectSkillImage.transform.position=Util.GetGameObject(go.transform,"s").transform.position
    --             local skillData = {}
    --             skillData.skillConfig = skillList[i].skillConfig
    --             local maxLv= HeroManager.GetHeroSkillMaxLevel(heroSData.Id,skillData.skillConfig.Type)
    --             local panel =  UIManager.OpenPanel(UIName.SkillInfoPopup,skillData,1,10,maxLv,i)
    --             this.skillGrid:GetComponent("Canvas").sortingOrder = panel.sortingOrder + 1
    --             triggerCallBack = function (panelType, p)
    --                 if panelType == UIName.SkillInfoPopup and panel == p then --监听到SkillInfoPopup关闭，把层级设回去
    --                     this.skillGrid:GetComponent("Canvas").sortingOrder = self.sortingOrder + 1
    --                     Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
    --                     this.selsectSkillImage:SetActive(false)
    --                 end
    --             end
    --             Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    --         end)
    --     end
    -- end

    this.SkillInfo()

    --法宝
    -- self.talismanBtn.gameObject:SetActive(heroSData.EquipTalismana~=nil)
    -- if heroSData.EquipTalismana~=nil then
    --     -- self.talismanFrame.sprite=Util.LoadSprite(TalismanBubble[itemConfig[heroSData.EquipTalismana[2]].Quantity])
    --     this.talismanIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[heroSData.EquipTalismana[2]].ResourceID))
    -- end
    -- Util.AddOnceClick(this.talismanBtn.gameObject,function()
    --     UIManager.OpenPanel(UIName.TalismanInfoPopup,heroSData,1,1)
    -- end)
end

function this.SkillInfo()
    local heroSData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroSId)
    local oldSkillList = HeroManager.GetSkillIdsByHeroRulesRole(heroSData.OpenSkillRules,heroStar,breakId)
    local oldOpenPassiveSkillRules = HeroManager.GetPassiveSkillIdsByHeroRuleslock(heroSData.OpenPassiveSkillRules,heroStar,breakId)
    for key, value in pairs(oldOpenPassiveSkillRules) do
        table.insert(oldSkillList, value)
    end
    table.sort(oldSkillList,function(a,b)
        return a.skillConfig.Id < b.skillConfig.Id
    end)
    this.core:SetActive(heroSData.HeroValue == 1)
    this.SetSkillInfo(oldSkillList[2],this.skill1)
    this.SetSkillInfo(oldSkillList[3],this.skill2)
    this.SetSkillInfo(oldSkillList[4],this.skill3)
    this.SetSkillInfo(oldSkillList[5],this.skill4)
end

function this.SetSkillInfo(skillData,skillGo)
    if skillData and skillData.skillConfig and skillData.skillConfig.Name then
        skillGo:SetActive(true)
        local skillLevel = 0
        Util.GetGameObject(skillGo.transform,"icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(skillData.skillConfig.Icon))
        Util.GetGameObject(skillGo.transform,"skillName"):GetComponent("Text").text = GetLanguageStrById(skillData.skillConfig.Name)--GetLanguageStrById(10470).. 1(skillList[i].skillConfig.Id % 10)
        --Util.GetGameObject(skillGo.transform, "Text"):GetComponent("Text").text = skillData.skillConfig.Name--"lv." .. (skillData.skillId % 10)
        --Util.GetGameObject(skillGo.transform,"SkillTypeImage"):GetComponent("Image").sprite=Util.LoadSprite(GetSkillType(skillData))
        if SkillLogicConfig[skillData.skillConfig.Id] ~= nil then
            skillLevel = SkillLogicConfig[skillData.skillConfig.Id].Level
        else
            skillLevel = PassiveSkillLogicConfig[skillData.skillConfig.Id].Level
        end

        Util.GetGameObject(skillGo.transform,"Lv/LvTx"):GetComponent("Text").text = skillLevel
        Util.SetGray(Util.GetGameObject(skillGo.transform,"icon"),skillData.lock)
        if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
            Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
        end
        this:SetSkillSelectImage(skillGo.transform, true)

        Util.AddOnceClick(Util.GetGameObject(skillGo.transform,"frame"), function()
            if Game.GlobalEvent:HasEvent(GameEvent.UI.OnClose, triggerCallBack) then
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
            end
            -- this.selsectSkillImage:SetActive(true)
            -- this.selsectSkillImage.transform.position=Util.GetGameObject(skillGo.transform,"icon").transform.position
            -- local skillData = {}
            -- skillData.skillConfig = skillData.skillConfig
            local skillLogicConfig_
            local isPassive
            local skillPos
            if skillLogicConfig_ == nil then
                skillLogicConfig_ = ConfigManager.TryGetConfigDataByKey(ConfigName.SkillLogicConfig,"Id",skillData.skillConfig.Id)
                isPassive = false
            end
            if skillLogicConfig_ == nil then
                skillLogicConfig_ = ConfigManager.TryGetConfigDataByKey(ConfigName.PassiveSkillLogicConfig,"Id",skillData.skillConfig.Id)
                isPassive = true
            end
            local heroSData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroSId)
            if isPassive then
                for i = 1, #heroSData.OpenPassiveSkillRules do
                    if heroSData.OpenPassiveSkillRules[i][2] == skillLogicConfig_.Group then
                        skillPos = heroSData.OpenPassiveSkillRules[i][1]
                        break
                    end
                end
            else
                for i=1, #heroSData.OpenSkillRules do
                    if heroSData.OpenSkillRules[i][2] == skillLogicConfig_.Group then
                        skillPos=heroSData.OpenSkillRules[i][1]
                        break
                    end
                end
            end
            local maxLv= HeroManager.GetHeroSkillMaxLevel(heroSId,skillPos)
            local panel = UIManager.OpenPanel(UIName.SkillInfoPopup,skillData,1,10,maxLv,skillPos,skillLevel)
            -- this.skillGrid:GetComponent("Canvas").sortingOrder = panel.sortingOrder + 1
            triggerCallBack = function (panelType, p)
                if panelType == UIName.SkillInfoPopup and panel == p then --监听到SkillInfoPopup关闭，把层级设回去
                    -- this.skillGrid:GetComponent("Canvas").sortingOrder = self.sortingOrder + 1
                    Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
                    -- this.selsectSkillImage:SetActive(false)
                end
            end
            Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
        end)

        -- Util.AddOnceClick(Util.GetGameObject(skillGo.transform,"frame"), function()
        --     local maxLv = HeroManager.GetHeroSkillMaxLevel(heroSId, skillData.skillConfig.Type)
        --     local panel = UIManager.OpenPanel(UIName.SkillInfoPopup, skillData, 4, 10, maxLv, 1)
        --     --this.skillGrid:GetComponent("Canvas").overrideSorting=true
        --     --this.skillGrid:GetComponent("Canvas").sortingOrder = panel.sortingOrder + 1
        --     triggerCallBack = function(panelType, p)
        --         if panelType == UIName.SkillInfoPopup and p == panel then
        --             --监听到SkillInfoPopup关闭，把层级设回去
        --             --this.skillGrid:GetComponent("Canvas").overrideSorting=false
        --             --this.skillGrid:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
        --             Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
        --             this:SetSkillSelectImage(self.transform, false)
        --         end
        --     end
        --     Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
        -- end)
    else
        skillGo:SetActive(false)
    end
end

function this.ShowHeroLive(_heroSConfigData)

    _heroData = _heroSConfigData
    if _heroSConfigData.HeroSound then
        SoundManager.PlaySound(_heroSConfigData.HeroSound)
    end

    this.liveName = GetResourcePath(_heroSConfigData.RoleImage)
    this.liveObj = LoadHerolive(_heroSConfigData, this.liveRoot.transform)
    -- this.liveNode = poolManager:LoadFrame(this.liveName, this.liveRoot.transform, Vector3.one * _heroSConfigData.Scale, Vector3.New(_heroSConfigData.Position[1], _heroSConfigData.Position[2]))
    -- this.liveNode.transform.sizeDelta = Vector2.New(1000, 1000)
    -- local SkeletonGraphic = this.liveNode:GetComponent("SkeletonGraphic")
    --资质相关
    -- this.qualityImage.sprite=GetQuantityImage(_heroSConfigData.Natural)
    -- this.quality:SetActive(_heroSConfigData.Natural < 10)
    -- this.doubleQuality:SetActive(_heroSConfigData.Natural >= 10)
    -- this.quality:GetComponent("Text").text = _heroSConfigData.Natural
    -- this.doubleQuality:GetComponent("Text").text = _heroSConfigData.Natural
    --定位描述相关
    -- this.posBgImage.sprite=Util.LoadSprite(GetHeroPosBgStr(_heroSConfigData.Profession))
    -- this.posImage.sprite=Util.LoadSprite(GetHeroPosStr(_heroSConfigData.Profession))
    this.posText.text = GetLanguageStrById(_heroSConfigData.HeroLocation)
    this.heroName.text = GetLanguageStrById(_heroSConfigData.ReadingName)
    -- this.posText.text = HeroOccupationDef[_heroSConfigData.Profession]
    -- this.posImage.sprite = Util.LoadSprite(GetJobSpriteStrByJobNum(_heroSConfigData.Profession))
    this.profession.sprite = Util.LoadSprite(GetBigProStrImageByProNum(_heroSConfigData.PropertyName))
    this.proImage.sprite = Util.LoadSprite(GetBigProStrImageByProNum(_heroSConfigData.PropertyName))
    -- for i = 1, 4, 1 do
    --     Util.GetGameObject(this.recommend, "Image"..i):GetComponent("Image").sprite = Util.LoadSprite("N1_img_tanke_mingjiahui")
    -- end
    -- if _heroData.HeroValue > 0 then
    --     this.recommend:SetActive(true)
    --     for i = 1, _heroSConfigData.HeroValue, 1 do
    --         Util.GetGameObject(this.recommend, "Image"..i):GetComponent("Image").sprite=  Util.LoadSprite("N1_img_tanke_mingjia")
    --     end
    -- else
    --     this.recommend:SetActive(false)
    -- end
end
function this.GetShowPanelData()
    local heroSData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroBackData.heroId)
    -- _heroData = heroBackData[heroSId]
    this.ShowHeroLive(heroSData)
    --星级
    SetHeroStars(this.starGrid, heroBackData.star)
    --属性
    local allAddProVal = HeroManager.CalculateHeroAllProValList(1,heroBackData.id,false)
    this.atk.text = allAddProVal[HeroProType.Attack]
    this.hp.text = allAddProVal[HeroProType.Hp]
    this.phyDef.text =allAddProVal[HeroProType.PhysicalDefence]
    -- this.magDef.text = allAddProVal[HeroProType.MagicDefence]
    this.speed.text = allAddProVal[HeroProType.Speed]
    --技能
    -- this.selsectSkillImage:SetActive(false)
    -- this.skillGrid:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
    -- if allSkillDatas[1] and allSkillDatas[1].skillConfig and allSkillDatas[1].skillConfig.Name then
    --     this.skill1:SetActive(true)
    --     this.skill1.transform:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(allSkillDatas[1].skillConfig.Icon))
    --     Util.GetGameObject(this.skill1.transform,"Text"):GetComponent("Text").text = "等级"..(allSkillDatas[1].skillId % 10)
    -- else
    --     this.skill1:SetActive(false)
    -- end
    -- if allSkillDatas[2] and allSkillDatas[2].skillConfig and allSkillDatas[2].skillConfig.Name then
    --     this.skill2:SetActive(true)
    --     this.skill2.transform:GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(allSkillDatas[2].skillConfig.Icon))
    --     Util.GetGameObject(this.skill2.transform,"Text"):GetComponent("Text").text = "等级"..(allSkillDatas[2].skillId % 10)
    -- else
    --     this.skill2:SetActive(false)
    -- end
end

function this.NoGetShowPanelData()
    local heroSData = ConfigManager.GetConfigData(ConfigName.HeroConfig, heroSId)
    -- _heroData = heroConfig[heroSId]
    this.ShowHeroLive(heroSData)
    --星级
    --Util.ClearChild(this.starGrid.transform)
    SetHeroStars(this.starGrid, heroStar)
    --属性
    local allAddProVal = this.CalculateHeroAllProValList(heroSData,heroStar,heroStar ~= heroSData.Star)
    this.atk.text = allAddProVal[HeroProType.Attack]
    this.hp.text = allAddProVal[HeroProType.Hp]
    this.phyDef.text = allAddProVal[HeroProType.PhysicalDefence]
    -- this.magDef.text = allAddProVal[HeroProType.MagicDefence]
    this.speed.text = heroSData.Speed
    --技能
    
    -- this.selsectSkillImage:SetActive(false)
    -- this.skillGrid:GetComponent("Canvas").sortingOrder = this.sortingOrder + 1
    -- if allSkillDatas[1] and allSkillDatas[1].skillConfig and allSkillDatas[1].skillConfig.Name then
    --     this.skill1:SetActive(true)
    --     this.skill1.transform:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(allSkillDatas[1].skillConfig.Icon))
    --     Util.GetGameObject(this.skill1.transform,"Text"):GetComponent("Text").text="等级"..(allSkillDatas[1].skillId % 10)
    -- else
    --     this.skill1:SetActive(false)
    -- end
    -- if allSkillDatas[2] and allSkillDatas[2].skillConfig and allSkillDatas[2].skillConfig.Name then
    --     this.skill2:SetActive(true)
    --     this.skill2.transform:GetComponent("Image").sprite=Util.LoadSprite(GetResourcePath(allSkillDatas[2].skillConfig.Icon))
    --     Util.GetGameObject(this.skill2.transform,"Text"):GetComponent("Text").text="等级"..(allSkillDatas[2].skillId % 10)
    -- else
    --     this.skill2:SetActive(false)
    -- end

end
function this:SetSkillSelectImage(_goTran,_type)--_goTran父级   _type==true  显示 =false 隐藏
    -- this.selsectSkillImage:SetActive(_type)
    --this.selsectSkillImage.transform:SetParent(_goTran)
    --this.selsectSkillImage.transform.localScale = Vector3.one
    --this.selsectSkillImage.transform.localPosition=Vector3.zero
    -- this.selsectSkillImage.transform.position=_goTran.position
end
local heroLevelConfig = ConfigManager.GetConfig(ConfigName.HeroLevelConfig)
--计算英雄属性   1 初始 2 满星
function this.CalculateHeroAllProValList(heroConFigData,_starNum,isCalculateStarVal)
    local allAddProVal = {}
    for i, v in ConfigPairs(propertyConfig) do
        allAddProVal[i] = 0
    end
    -- local heroRankupConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroRankupConfig, "Star", heroConFigData.Star, "OpenStar", _starNum)
    -- local curLvNum = 1
    -- local breakId = 0
    -- local upStarId = 0
    -- if isCalculateStarVal then
    --     curLvNum = heroLevelConfig[heroRankupConfig.OpenLevel].CharacterLevelPara
    --     for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.HeroRankupConfig)) do
    --         if v.Star == heroConFigData.Star then
    --             if v.Type == 1 then
    --                 breakId = v.Id
    --             end
    --             if v.Type == 2 then
    --                 upStarId = v.Id
    --             end
    --         end
    --     end
    -- end
    local heroRankupConfig
    if heroConFigData.Star == _starNum then
       local  heroRankuplist = ConfigManager.GetAllConfigsDataByKey(ConfigName.HeroRankupConfig,"Star",heroConFigData.Star)
       local starlv = 1
       for key, value in pairs(heroRankuplist) do
        if value.OpenLevel > starlv then
            starlv = value.OpenLevel
            heroRankupConfig = value
        end
       end
    else
        heroRankupConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.HeroRankupConfig, "Star", heroConFigData.Star, "OpenStar", _starNum)
    end
    local curLvNum = 1
    local breakId = 0
    local upStarId = 0
    if isCalculateStarVal then
        --等级
        curLvNum = heroRankupConfig.OpenLevel
        --解锁天赋
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.HeroRankupConfig)) do
            if v.OpenStar == _starNum and v.Star==heroConFigData.Star then
                if v.Type == 1 then
                    breakId = v.Id
                end
                if v.Type == 2 then
                    upStarId = v.Id
                end
            end
        end
        if breakId == 0 then
            breakId = 6
        end
    end
    allAddProVal[HeroProType.Attack] = HeroManager.CalculateProVal(heroConFigData.Attack, curLvNum, breakId,upStarId,HeroProType.Attack,heroConFigData)
    allAddProVal[HeroProType.Hp] = HeroManager.CalculateProVal(heroConFigData.Hp, curLvNum, breakId,upStarId,HeroProType.Hp,heroConFigData)
    allAddProVal[HeroProType.PhysicalDefence] = HeroManager.CalculateProVal(heroConFigData.PhysicalDefence, curLvNum, breakId,upStarId,HeroProType.PhysicalDefence,heroConFigData)
    -- allAddProVal[HeroProType.MagicDefence] = HeroManager.CalculateProVal(heroConFigData.MagicDefence, curLvNum, breakId,upStarId,HeroProType.MagicDefence,heroConFigData)
    --allAddProVal[HeroProType.Speed]= math.floor(((curSpeedFormulaData[1] * math.pow(breakId, 3) + curSpeedFormulaData[2] * math.pow(breakId, 2) + curSpeedFormulaData[3] * breakId + curSpeedFormulaData[4]) + heroConFigData.Speed * speedNum))
    -- for i = 1, #heroConFigData.SecondaryFactor do
    --     local proId = heroConFigData.SecondaryFactor[i][1]
    --     if propertyConfig[proId].Style ==2 then
    --         allAddProVal[heroConFigData.SecondaryFactor[i][1]] = heroConFigData.SecondaryFactor[i][2]/10000
    --     else
    --         allAddProVal[heroConFigData.SecondaryFactor[i][1]] = heroConFigData.SecondaryFactor[i][2]
    --     end
    -- end
    -- Util.AddOnceClick(this.talentBtn,function()
    --     UIManager.OpenPanel(UIName.RoleTalentPopup,heroConFigData,breakId,upStarId)
    -- end)
    -- if heroConFigData.OpenPassiveSkillRules then
    --     local openlists,compoundOpenNum,compoundNum = HeroManager.GetAllPassiveSkillIds(heroConFigData,breakId,upStarId)
    --     this.talentProgress.text = #openlists - compoundOpenNum .."/"..#heroConFigData.OpenPassiveSkillRules - compoundNum
    -- end
    return allAddProVal
end

--界面关闭时调用（用于子类重写）
function RoleGetInfoPopup:OnClose()
    -- if this.liveNode then
    --     poolManager:UnLoadFrame(this.liveName, this.liveNode)
    --     this.liveNode = nil
    -- end
    UnLoadHerolive(_heroData,this.liveObj)
    Util.ClearChild(this.liveRoot.transform)
    _heroData = nil
end

--界面销毁时调用（用于子类重写）
function RoleGetInfoPopup:OnDestroy()

end

return RoleGetInfoPopup