require("Base/BasePanel")
PokemonGetInfoPopup = Inherit(BasePanel)
local this=PokemonGetInfoPopup
local propertyConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local pokemonBackData
local pokemonSid
local isGet
local proList = {}
--初始化组件（用于子类重写）
function PokemonGetInfoPopup:InitComponent()

    this.BtnBack=Util.GetGameObject(self.transform, "bg/btnBack")
    this.liveRoot=Util.GetGameObject(self.transform, "bg/liveRoot")
    this.heroName = Util.GetGameObject(self.transform, "bg/nameInfo/nameText"):GetComponent("Text")
    this.starGrid = Util.GetGameObject(self.transform, "bg/PokemonInfo/starGrid(Clone)")

     --属性
     for i = 0, 4 do
        proList[i] = Util.GetGameObject(self.transform,"bg/PokemonInfo/pro/singlePro ("..i..")")
    end

    this.skillName=Util.GetGameObject(self.transform,"bg/PokemonInfo/skill/nameText"):GetComponent("Text")
    this.skillLv=Util.GetGameObject(self.transform,"bg/PokemonInfo/skill/skillImage/skillLv"):GetComponent("Text")
    this.skillIcon=Util.GetGameObject(self.transform,"bg/PokemonInfo/skill/icon"):GetComponent("Image")
    this.skillBtn=Util.GetGameObject(self.transform,"bg/PokemonInfo/skill/icon")
end
local triggerCallBack
--绑定事件（用于子类重写）
function PokemonGetInfoPopup:BindEvent()

    Util.AddClick(this.BtnBack, function()
        self:ClosePanel()
    end)
end
--添加事件监听（用于子类重写）
function PokemonGetInfoPopup:AddListener()

end

--移除事件监听（用于子类重写）
function PokemonGetInfoPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function PokemonGetInfoPopup:OnOpen(_isGet,data)--data 未获得的时候为灵兽静态ID  获得的时候为本地数据

    isGet=_isGet
    if isGet then
        pokemonBackData = data
    else
        pokemonSid = data
    end
end
function PokemonGetInfoPopup:OnShow()
    if isGet then
        this.GetShowPanelData()
    else
        this.NoGetShowPanelData()
    end
end
function this.GetShowPanelData()
    local pokemonSData=ConfigManager.GetConfigData(ConfigName.SpiritAnimal, pokemonBackData.tempId)
    this.heroName.text = GetStringByEquipQua(pokemonSData.Quality, pokemonSData.Name)
    this.ShowPokemonLive(pokemonSData)
    --星级
    PokemonManager.SetHeroStars(this.starGrid, pokemonBackData.star)
    --属性
    local  allAddProVal=PokemonManager.GetSinglePokemonAddProDataByLvAndStar(pokemonBackData.tempId,pokemonBackData.level,pokemonBackData.star)
    proList[0]:SetActive(true)
    Util.GetGameObject(proList[0].transform,"proName"):GetComponent("Text").text =GetLanguageStrById(10470)
    Util.GetGameObject(proList[0].transform,"proValue"):GetComponent("Text").text = pokemonBackData.level
    Util.GetGameObject(proList[0].transform,"Image"):GetComponent("Image").sprite =  Util.LoadSprite(PropertyTypeIconDef[1])
    local index = 0
    for key, value in pairs(allAddProVal) do
        index = index + 1
        if proList[index] then
            Util.GetGameObject(proList[index].transform,"proName"):GetComponent("Text").text = ConfigManager.GetConfigData(ConfigName.PropertyConfig,key).Info
            Util.GetGameObject(proList[index].transform,"proValue"):GetComponent("Text").text = value
            Util.GetGameObject(proList[index].transform,"Image"):GetComponent("Image").sprite =  Util.LoadSprite(PropertyTypeIconDef[index + 1])
        end
    end
    -- for i = 1, 4 do
    --     Util.GetGameObject(proList[i].transform,"proName"):GetComponent("Text").text = ConfigManager.GetConfigData(ConfigName.PropertyConfig,i).Info
    --     Util.GetGameObject(proList[i].transform,"proValue"):GetComponent("Text").text = allAddProVal[i]
    --     Util.GetGameObject(proList[i].transform,"Image"):GetComponent("Image").sprite =  Util.LoadSprite(PropertyTypeIconDef[i + 1])
    -- end
    local curSkillId = 0
    local skillArray = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,pokemonBackData.tempId).SkillArray
    for i = 1, #skillArray do
        if skillArray[i][1] == pokemonBackData.star then
            curSkillId = skillArray[i][2]
        end
    end
    local curSkillConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSkill,curSkillId)
    this.skillName.text = curSkillConFig.Name
    this.skillLv.text = curSkillConFig.Level
    this.skillIcon.sprite = Util.LoadSprite(GetResourcePath(curSkillConFig.Icon))
    Util.AddOnceClick(this.skillBtn, function()
        UIManager.OpenPanel(UIName.PokemonSkillInfoPopup,pokemonBackData.tempId,pokemonBackData.level,pokemonBackData.star)
    end)
end
function this.NoGetShowPanelData()
    local pokemonSData=ConfigManager.GetConfigData(ConfigName.SpiritAnimal, pokemonSid)
    this.heroName.text = GetStringByEquipQua(pokemonSData.Quality, pokemonSData.Name)
    this.ShowPokemonLive(pokemonSData)
    --星级
    PokemonManager.SetHeroStars(this.starGrid, 0)
    --属性
    local  allAddProVal = PokemonManager.GetSinglePokemonAddProDataBySid(pokemonSid) --this.CalculateHeroAllProValList(heroSData,heroStar,heroStar ~= heroSData.Star)
    proList[0]:SetActive(false)
    local index = 0
    for key, value in pairs(allAddProVal) do
        index = index + 1
        if proList[index] then
            Util.GetGameObject(proList[index].transform,"proName"):GetComponent("Text").text = ConfigManager.GetConfigData(ConfigName.PropertyConfig,key).Info
            Util.GetGameObject(proList[index].transform,"proValue"):GetComponent("Text").text = value
            Util.GetGameObject(proList[index].transform,"Image"):GetComponent("Image").sprite = Util.LoadSprite(PropertyTypeIconDef[index + 1])
        end
    end
    -- for i = 1, 4 do
    --     Util.GetGameObject(proList[i].transform,"proName"):GetComponent("Text").text = ConfigManager.GetConfigData(ConfigName.PropertyConfig,i).Info
    --     Util.GetGameObject(proList[i].transform,"proValue"):GetComponent("Text").text = allAddProVal[i]
    --     Util.GetGameObject(proList[i].transform,"Image"):GetComponent("Image").sprite = Util.LoadSprite(PropertyTypeIconDef[i + 1])
    -- end
    local curSkillId = 0
    local skillArray = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,pokemonSid).SkillArray
    for i = 1, #skillArray do
        if skillArray[i][1] == 0 then
            curSkillId = skillArray[i][2]
        end
    end
    local curSkillConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSkill,curSkillId)
    this.skillName.text = curSkillConFig.Name
    this.skillLv.text = curSkillConFig.Level
    this.skillIcon.sprite = Util.LoadSprite(GetResourcePath(curSkillConFig.Icon))
    Util.AddOnceClick(this.skillBtn, function()
        UIManager.OpenPanel(UIName.PokemonSkillInfoPopup,pokemonSid,1,0)
    end)
end

function this.ShowPokemonLive(_heroSConfigData)
    
    -- this.testLiveGO = poolManager:LoadLive(GetResourcePath(_heroSConfigData.Live), this.liveRoot.transform,
    --         Vector3.one * _heroSConfigData.Scale * 0.7, Vector3.New(_heroSConfigData.Position[1], _heroSConfigData.Position[2], 0))
    -- local SkeletonGraphic = this.testLiveGO:GetComponent("SkeletonGraphic")
    -- local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
    -- SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
    -- poolManager:SetLiveClearCall(GetResourcePath(_heroSConfigData.Live), this.testLiveGO, function ()
    --     SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
    -- end)
    local curData = PokemonManager.GetSinglePokemonData( _heroSConfigData)
    if Util.GetGameObject(this.liveRoot.transform, "TestImg") then
        destroy(Util.GetGameObject(this.liveRoot.transform, "TestImg"))
    end
    local roleStaticImg = poolManager:LoadAsset(GetResourcePath(_heroSConfigData.Live), PoolManager.AssetType.GameObject)
    roleStaticImg.transform:SetParent(this.liveRoot.transform)
    roleStaticImg.transform.localScale = Vector3.one --m5
    roleStaticImg.transform.localPosition = Vector3.zero
    roleStaticImg.name = "TestImg"
end
--界面关闭时调用（用于子类重写）
function PokemonGetInfoPopup:OnClose()

    -- poolManager:UnLoadLive(this.testLiveGO.name, this.testLiveGO)
    this.testLiveGO = nil
end

--界面销毁时调用（用于子类重写）
function PokemonGetInfoPopup:OnDestroy()

end

return PokemonGetInfoPopup