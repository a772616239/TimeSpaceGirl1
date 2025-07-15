require("Base/BasePanel")
PublicGetHeroPanel = Inherit(BasePanel)
local this = PublicGetHeroPanel
local passiveSkillConfig = ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)

local isFirst = false--是否第一次进入
local index--当前展示下标
local allHeroNum--英雄数量
local allHeroStar--全部英雄星级
local curHeroData--当前英雄
local allHeroData = {}--全部英雄
local curHeroStar--当前英雄星级
local curHeroStaticData--当前英雄的的表数据
local lastHeroStaticData--上个英雄的表数据(为卸载Live使用)
--初始化组件（用于子类重写）
function PublicGetHeroPanel:InitComponent()
    this.closeBtn = Util.GetGameObject(this.gameObject, "closeBtn")
    this.mask = Util.GetGameObject(this.gameObject,"mask")

    this.huode = Util.GetGameObject(this.gameObject, "huode"):GetComponent("Animator")
    this.ColorChange = Util.GetGameObject(this.gameObject, "ColorChange"):GetComponent("MeshRenderer")

    this.hero = Util.GetGameObject(this.gameObject,"hero")
    this.liveRoot = Util.GetGameObject(this.hero,"move")
    this.effects = Util.GetGameObject(this.hero,"effect")
    this.effectList = {}
    for i = 1, 7 do
        local effect = Util.GetGameObject(this.effects,"EF0" .. i)
        table.insert(this.effectList,effect)
    end

    this.heroInfo = Util.GetGameObject(this.hero,"UI/title")
    this.heroName = Util.GetGameObject(this.heroInfo,"Text"):GetComponent("Text")
    this.heroTip = Util.GetGameObject(this.heroInfo,"Text/Image/Text"):GetComponent("Text")
    this.heroSkillGroup = Util.GetGameObject(this.heroInfo,"skillGroup")
    this.skillPrefab = Util.GetGameObject(this.heroInfo,"skillPre")
    this.heroPro = Util.GetGameObject(this.heroInfo,"proImage"):GetComponent("Image")
    this.starGrid = Util.GetGameObject(this.heroInfo,"star")

    this._material = poolManager:LoadAsset("cn2-X1_UIChouKa_mat_032", PoolManager.AssetType.Other)
    this.core = Util.GetGameObject(this.hero, "UI/top/core")
end

--绑定事件（用于子类重写）
function PublicGetHeroPanel:BindEvent()
    Util.AddClick(this.closeBtn, function()
        if index > allHeroNum then
            this.CloseGetHero()
        else
            curHeroData = allHeroData[index]
            curHeroStar = allHeroStar[index]
            this.GetHero()
        end
    end)
end

--添加事件监听（用于子类重写）
function PublicGetHeroPanel:AddListener()

end

--移除事件监听（用于子类重写）
function PublicGetHeroPanel:RemoveListener()

end

local orginLayer = 0
function PublicGetHeroPanel:OnSortingOrderChange()
    this.gameObject:GetComponent("Canvas").sortingOrder = self.sortingOrder + 5

    for i = 1, this.huode.gameObject.transform.childCount do
        local go = this.huode.gameObject.transform:GetChild(i - 1).gameObject
        Util.SetParticleSortLayer(go, self.sortingOrder + 5)
    end
    Util.SetParticleSortLayer(this.ColorChange.gameObject, self.sortingOrder + 10)
    for index, value in ipairs(this.effectList) do
        Util.SetParticleSortLayer(value, self.sortingOrder + 5)
    end

    this.liveRoot:GetComponent("Canvas").sortingOrder = self.sortingOrder + 17
    Util.GetGameObject(this.hero,"UI"):GetComponent("Canvas").sortingOrder = self.sortingOrder + 20

    orginLayer = self.sortingOrder * 2
end


--界面打开时调用（用于子类重写）
function PublicGetHeroPanel:OnOpen(...)
    local data = {...}
    allHeroData = data[1]
    allHeroNum = #allHeroData
    curHeroData = allHeroData[1]
    allHeroStar = data[2]
    curHeroStar = allHeroStar[1]
    this.fun = data[3]
end

function PublicGetHeroPanel:OnShow()
    index = 1
    isFirst = true
    this.GetHero()
end

function PublicGetHeroPanel:OnClose()
    if this.liveObj then
        UnLoadHerolive(lastHeroStaticData,this.liveObj)
        Util.ClearChild(this.liveRoot.transform)
    end
    isFirst = false
    index = 1
    allHeroData = {}
    allHeroNum = 0
    curHeroData = nil
    allHeroStar = {}
    curHeroStar = nil
    curHeroStaticData = nil
    lastHeroStaticData = nil
    this.liveObj = nil

    PublicGetHeroPanel:OnSortingOrderChange()
    orginLayer = 0
end

function PublicGetHeroPanel:OnDestroy()
    orginLayer = 0
end

function this.GetHero()
    this.mask:SetActive(true)
    this.core:SetActive(false)
    curHeroStaticData = curHeroData
    this.ColorChange.material.color = GetColorByHeroQua(curHeroStar)
    local tempTime = 0
    if not isFirst then
        tempTime = 0.3
    else
        isFirst = false
    end

    Timer.New(function()  
        Timer.New(function()
            if not curHeroStaticData then
                return
            end

            this.hero.gameObject:SetActive(false)
            this.hero.gameObject:SetActive(true)
            this.core:SetActive(curHeroStaticData.HeroValue == 1)
            this.effectList[curHeroStaticData.Quality]:SetActive(true)

            if curHeroStaticData.Quality < 4 then
                SoundManager.PlaySound(SoundConfig.Sound_Recruit_GetHero_1)
            elseif curHeroStaticData.Quality > 4 then
                SoundManager.PlaySound(SoundConfig.Sound_Recruit_GetHero_3)
            else
                SoundManager.PlaySound(SoundConfig.Sound_Recruit_GetHero_2)
            end

            if this.liveObj then
                UnLoadHerolive(lastHeroStaticData,this.liveObj)
                Util.ClearChild(this.liveRoot.transform)
            end
            lastHeroStaticData = curHeroStaticData
            this.liveObj = LoadHerolive(curHeroStaticData,this.liveRoot.transform)                
            if curHeroStaticData.RoleImage ~= 0 and this.liveObj:GetComponent("SkeletonGraphic") then
                this.liveObj:GetComponent("SkeletonGraphic").material = this._material
                this.liveObj:GetComponent("SkeletonGraphic").color = GetColorByHeroEnterQua(curHeroStaticData.Quality)
                this.liveObj:GetComponent("SkeletonGraphic"):DOFade(1,0)
            else
                this.liveObj:GetComponent("Image").material = this._material
                this.liveObj:GetComponent("Image").color = GetColorByHeroEnterQua(curHeroStaticData.Quality) 
                this.liveObj:GetComponent("Image"):DOFade(1,0)
            end

            this.heroName.text = GetLanguageStrById(curHeroStaticData.ReadingName)
            this.heroTip.text = GetLanguageStrById(curHeroStaticData.HeroLocationDesc1)

            Util.ClearChild(this.heroSkillGroup.transform)
            if curHeroStaticData.OpenSkillRules then
                local skillCount1 = #curHeroStaticData.OpenSkillRules
                for i = 1, skillCount1 do
                    if curHeroStaticData.OpenSkillRules[i][1] ~= 0 then
                        local go = newObject(this.skillPrefab)
                        go.gameObject:SetActive(true)
                        go.transform:SetParent(this.heroSkillGroup.transform)
                        go.transform.localScale = Vector3.one
                        local skillGonfigData = ConfigManager.GetConfigDataByDoubleKey("SkillLogicConfig","Group",curHeroStaticData.OpenSkillRules[i][2],"Level",1)
                        local resid = skillConfig[tonumber(skillGonfigData.Id)].Icon
                        Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(resid))
                    end
                end
            end

            if curHeroStaticData.OpenPassiveSkillRules then
                local skillCount2 = #curHeroStaticData.OpenPassiveSkillRules
                for i = 1, skillCount2 do
                    local gameObject = newObject(this.skillPrefab)
                    gameObject.gameObject:SetActive(true)
                    gameObject.transform:SetParent(this.heroSkillGroup.transform)
                    gameObject.transform.localScale = Vector3.one
                    local skillGonfigData = ConfigManager.GetConfigDataByDoubleKey("PassiveSkillLogicConfig","Group",curHeroStaticData.OpenPassiveSkillRules[i][2],"Level",1)
                    local resid = passiveSkillConfig[tonumber(skillGonfigData.Id)].Icon
                    Util.GetGameObject(gameObject, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(resid))
                end
            end

            SetHeroStars(this.starGrid, curHeroStar)
            this.heroPro.sprite = Util.LoadSprite(GetProStrImageByProNum(curHeroStaticData.PropertyName))
        end,0.5):Start()
    
        Timer.New(function()
            index = index + 1
            this.mask:SetActive(false)
        end,2):Start()
    end,tempTime):Start()
end

function this.CloseGetHero(backAction)
    this.huode:SetTrigger("out")
    this.hero.gameObject:SetActive(false)
    this.mask:SetActive(true)
    
    Timer.New(function()
        isFirst = true
        if this.fun then
            this.fun()
        end
        this:ClosePanel()
        if backAction then
            backAction()
        end
    end,1):Start()
end

return PublicGetHeroPanel