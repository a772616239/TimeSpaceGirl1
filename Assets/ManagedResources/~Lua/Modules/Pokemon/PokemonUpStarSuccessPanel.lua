require("Base/BasePanel")
PokemonUpStarSuccessPanel = Inherit(BasePanel)
local this=PokemonUpStarSuccessPanel
this.skillConfig=ConfigManager.GetConfig(ConfigName.SpiritAnimalSkill)
local passiveSkillConfig=ConfigManager.GetConfig(ConfigName.PassiveSkillConfig)
local orginLayer = 20
local callBack = nil
local spiritAnimal = ConfigManager.GetConfig(ConfigName.SpiritAnimal)
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
this.roleStaticImg=nil
local curPro = {}
local curProImage = {}
local nextPro = {}
--初始化组件（用于子类重写）
function PokemonUpStarSuccessPanel:InitComponent()
    orginLayer = 20
    this.BtnBack = Util.GetGameObject(self.transform, "backBtn")
    this.mask = Util.GetGameObject(self.transform, "mask")
    this.live2dRoot=Util.GetGameObject(self.transform,"live2dRoot")
    this.starGrid = Util.GetGameObject(self.transform, "heroInfo/sartAndLvLayout")
    this.heroName=Util.GetGameObject(self.transform,"Pos/PosText"):GetComponent("Text")

   for i = 1, 4 do
        curPro[i] = Util.GetGameObject(self.transform,"proInfo/GameObject/proInfo/curPros/otherPro ("..i..")")
        curProImage[i] =  Util.GetGameObject(curPro[i],"Image"):GetComponent("Image")
        nextPro[i] = Util.GetGameObject(self.transform,"proInfo/GameObject/proInfo/nextPros/otherPro ("..i..")")
   end

    this.upLvShowGoText=Util.GetGameObject(self.transform,"proInfo/GameObject/proInfo/Text"):GetComponent("Text")
    this.upLvShowGoText.text = GetLanguageStrById(12281)

    this.starEndText=Util.GetGameObject(self.transform, "proInfo/starEndText")
    this.starEndText:GetComponent("Text").text = GetLanguageStrById(12484)

    this.skillImg=Util.GetGameObject(self.transform, "heroInfo/nameAndPossLayout/skill1"):GetComponent("Image")
    this.skillImg1=Util.GetGameObject(self.transform, "heroInfo/nameAndPossLayout/skill2"):GetComponent("Image")
    this.skillLvTxt1=Util.GetGameObject(self.transform, "heroInfo/nameAndPossLayout/lv1"):GetComponent("Text")
    this.skillLvTxt2=Util.GetGameObject(self.transform, "heroInfo/nameAndPossLayout/lv2"):GetComponent("Text")

    this.UI_Effect_choukaSSR = Util.GetGameObject(self.transform, "UI_Effect_chouka_SSR")
    this.UI_Effect_choukaSR = Util.GetGameObject(self.transform, "UI_Effect_chouka_SR")
    this.UI_Effect_choukaR = Util.GetGameObject(self.transform, "UI_Effect_chouka_R")
end

--绑定事件（用于子类重写）
function PokemonUpStarSuccessPanel:BindEvent()

    Util.AddClick(this.BtnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function PokemonUpStarSuccessPanel:AddListener()

end

--移除事件监听（用于子类重写）
function PokemonUpStarSuccessPanel:RemoveListener()

end


function PokemonUpStarSuccessPanel:OnSortingOrderChange()
    Util.AddParticleSortLayer(this.UI_Effect_choukaSSR, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.UI_Effect_choukaSR, self.sortingOrder - orginLayer)
    Util.AddParticleSortLayer(this.UI_Effect_choukaR, self.sortingOrder - orginLayer)
    this.mask:GetComponent("Canvas").overrideSorting = true
    this.mask:GetComponent("Canvas").sortingOrder = self.sortingOrder - 30
    orginLayer = self.sortingOrder
end

--界面打开时调用（用于子类重写）
function PokemonUpStarSuccessPanel:OnOpen(_curPokemonData)
    local curPokemonData = _curPokemonData
    local curPokeponConfig = spiritAnimal[curPokemonData.id]
    this.UI_Effect_choukaSSR:SetActive(curPokeponConfig.Quality == 5)
    this.UI_Effect_choukaSR:SetActive(curPokeponConfig.Quality == 4)
    this.UI_Effect_choukaR:SetActive(curPokeponConfig.Quality == 3)

    this.LiveName = curPokemonData.live
    if this.roleStaticImg~=nil then
        destroy(this.roleStaticImg)
    end
    -- this.LiveGO = poolManager:LoadLive(this.LiveName, this.live2dRoot.transform,
    --         Vector3.one * curPokemonData.scale, Vector3.New(curPokemonData.position[1],curPokemonData.position[2],0))
    this.roleStaticImg = poolManager:LoadAsset(this.LiveName, PoolManager.AssetType.GameObject)
    this.roleStaticImg.transform:SetParent(this.live2dRoot.transform)
    this.roleStaticImg.transform.localScale = Vector3.one --m5
    this.roleStaticImg.transform.localPosition = Vector3.zero
    this.roleStaticImg.name = "TestImg"
    SetHeroStars(this.starGrid, curPokemonData.star)
    
    this.heroName.text = curPokeponConfig.Name
    --如果是最大等级
    local nextUpStarConfig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.SpiritAnimalStar,"Quality", spiritAnimal[curPokemonData.id].Quality, "Star", curPokemonData.star + 1)
    if curPokemonData.star == curPokeponConfig.MaxStar then
        this.starEndText:SetActive(true)
    else
        this.starEndText:SetActive(false)
    end
    
    --计算面板属性old
    local oldLvAllAddProVal = PokemonManager.GetSinglePokemonAddProData(curPokemonData.dynamicId,curPokemonData.star - 1)
    --计算面板属性cur
    local curLvAllAddProVal = PokemonManager.GetSinglePokemonAddProData(curPokemonData.dynamicId,curPokemonData.star)


    local index = 0
    for key, value in pairs(oldLvAllAddProVal) do
        index = index + 1
        if curPro[index] then
            Util.GetGameObject(curPro[index],"curProName"):GetComponent("Text").text = propertyConfig[key].Info
            Util.GetGameObject(curPro[index],"curProVale"):GetComponent("Text").text = value
            Util.GetGameObject(curPro[index],"Image"):GetComponent("Image").sprite = Util.LoadSprite(PropertyTypeIconDef[index])
        end
    end
    local index2 = 0
    for key, value in pairs(curLvAllAddProVal) do
        index2 = index2 + 1
        if nextPro[index2] then
            Util.GetGameObject(nextPro[index2],"curProName"):GetComponent("Text").text = propertyConfig[key].Info
            Util.GetGameObject(nextPro[index2],"curProVale"):GetComponent("Text").text = value
        end
    end

    -- for i = 1, 4 do
    --     Util.GetGameObject(curPro[i],"curProName"):GetComponent("Text").text = propertyConfig[i].Info
    --     Util.GetGameObject(curPro[i],"curProVale"):GetComponent("Text").text = oldLvAllAddProVal[i]
    --     Util.GetGameObject(curPro[i],"Image"):GetComponent("Image").sprite = Util.LoadSprite(PropertyTypeIconDef[i])
    --     Util.GetGameObject(nextPro[i],"curProName"):GetComponent("Text").text = propertyConfig[i].Info
    --     Util.GetGameObject(nextPro[i],"curProVale"):GetComponent("Text").text = curLvAllAddProVal[i]
    -- end

    local curSkillId = 0
    local nextSkillId = 0
    local skillArray = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,curPokemonData.id).SkillArray
    for i = 1, #skillArray do
        
        if skillArray[i][1] == curPokemonData.star - 1 then
            curSkillId = skillArray[i][2]
        end
        if skillArray[i][1] == curPokemonData.star then
            nextSkillId = skillArray[i][2]
        end
    end 
    
    local curUpStarConfig = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSkill,curSkillId)
    local nextSkillConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSkill,nextSkillId)
    this.skillImg1.sprite = Util.LoadSprite(GetResourcePath(nextSkillConFig.Icon))
    this.skillLvTxt2.text = nextSkillConFig.Level
    this.skillImg.sprite = Util.LoadSprite(GetResourcePath(curUpStarConfig.Icon))
    this.skillLvTxt1.text = curUpStarConfig.Level
end

function PokemonUpStarSuccessPanel:GetEquipSkillData(skillId)
    return this.skillConfig[skillId]
end

--界面关闭时调用（用于子类重写）
function PokemonUpStarSuccessPanel:OnClose()

    if this.LiveName then
        poolManager:UnLoadLive(this.LiveName, this.LiveGO)
        this.LiveName = nil
    end
    if callBack then
        callBack()
        callBack = nil
    end
end

--界面销毁时调用（用于子类重写）
function PokemonUpStarSuccessPanel:OnDestroy()
    
end

return PokemonUpStarSuccessPanel