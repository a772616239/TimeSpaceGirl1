----- 灵兽羁绊 -----
local this = {}
local sortingOrder=0
local isHeroUpStar=false--是否可升星
local isUpStarMaterials=0--升星 材料是否充足
local upStarMaterialsPre = {}
local curPokemonData = {}
local parent
local spiritAnimal = ConfigManager.GetConfig(ConfigName.SpiritAnimal)
function this:InitComponent(gameObject)
    Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/Image (1)/Text"):GetComponent("Text").text = GetLanguageStrById(12489)--m5
    Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/Image (2)/Text"):GetComponent("Text").text = GetLanguageStrById(12490)
    Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarProInfo/lvUp/Text"):GetComponent("Text").text = GetLanguageStrById(12491)
    Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarProInfo/skillUp/Text"):GetComponent("Text").text = GetLanguageStrById(12492)

    this.curStarGrid = Util.GetGameObject(gameObject, "PokemonInfoPanel_UpStar/upStar/upStarProInfo/curStarGrid")
    this.nextStarGrid = Util.GetGameObject(gameObject, "PokemonInfoPanel_UpStar/upStar/upStarProInfo/nextStarGrid")

    this.curLvEnd = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarProInfo/lvUp/curLvEnd"):GetComponent("Text")
    this.nextLvEnd = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarProInfo/lvUp/nextLvEnd"):GetComponent("Text")

    this.skill1Btn = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarProInfo/skillUp/Skill1/icon")
    this.skill1Icon = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarProInfo/skillUp/Skill1/icon"):GetComponent("Image")
    this.skill1Lv = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarProInfo/skillUp/Skill1/skillImage/skillLv"):GetComponent("Text")
    this.skill2Btn = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarProInfo/skillUp/Skill2/icon")
    this.skill2Icon = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarProInfo/skillUp/Skill2/icon"):GetComponent("Image")
    this.skill2Lv = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarProInfo/skillUp/Skill2/skillImage/skillLv"):GetComponent("Text")

    this.skillTip = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/tip"):GetComponent("Text")
    Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/tip"):SetActive(false)

    this.upStarBtn = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/upStarBtn")
    this.upStarBtnRedPoint = Util.GetGameObject(this.upStarBtn,"redPoint")
    this.upStar = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar")
    this.noUpStarText = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/noUpStarText")

    for i = 1, 2 do
        upStarMaterialsPre[i] = Util.GetGameObject(gameObject,"PokemonInfoPanel_UpStar/upStar/grid/upStarPre ("..i..")")
    end
end

function this:BindEvent()
   --升星
   Util.AddClick(this.upStarBtn, function()
    this.StarUpClick()
end)
end

function this:AddListener()
    -- Game.GlobalEvent:AddEvent(GameEvent.Pokemon.PokemonMainPanelRefresh,  this.OnShowData)
end

function this:RemoveListener()
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Pokemon.PokemonMainPanelRefresh,  this.OnShowData)
end

local sortingOrder = 0
function this:OnSortingOrderChange(_sortingOrder)
    sortingOrder = _sortingOrder
end
function this:OnShow(_parent,_pokemonData)
    parent = _parent
    curPokemonData = _pokemonData
    this.OnShowData()
end


function this.OnUpdate()

end
local curUpStarSelectPokemonData = {}
--进阶属性提升
function this.OnShowData()
    --curPokemonData
    local curUpStarConfig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.SpiritAnimalStar,"Quality", spiritAnimal[curPokemonData.id].Quality, "Star", curPokemonData.star)
    local nextUpStarConfig = nil
    if curPokemonData.star < spiritAnimal[curPokemonData.id].MaxStar then
        nextUpStarConfig = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.SpiritAnimalStar,"Quality", spiritAnimal[curPokemonData.id].Quality, "Star", curPokemonData.star + 1)
    end
    if not nextUpStarConfig then
        this.upStar:SetActive(false)
        this.noUpStarText:SetActive(true)
        parent.RefreshRedPoint(2,false)
        this.upStarBtnRedPoint:SetActive(false)
        return
    else
        this.upStar:SetActive(true)
        this.noUpStarText:SetActive(false)
    end
    SetHeroStars(this.curStarGrid, curPokemonData.star)
    SetHeroStars(this.nextStarGrid, curPokemonData.star + 1)
    this.curLvEnd.text = curUpStarConfig.StarPara / 100 .. "%"
    this.nextLvEnd.text = nextUpStarConfig.StarPara / 100 .. "%"

    local curSkillId = 0
    local nextSkillId = 0
    local nextSkillConFig
    local skillArray = ConfigManager.GetConfigData(ConfigName.SpiritAnimal,curPokemonData.id).SkillArray
    for i = 1, #skillArray do
        if skillArray[i][1] == curUpStarConfig.Star then
            curSkillId = skillArray[i][2]
        end
        if skillArray[i][1] == nextUpStarConfig.Star then
            nextSkillId = skillArray[i][2]
            nextSkillConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSkill,nextSkillId)
            this.skill2Icon.sprite = Util.LoadSprite(GetResourcePath(nextSkillConFig.Icon))
            this.skill2Lv.text = nextSkillConFig.Level
            Util.AddOnceClick(this.skill2Btn, function()
                UIManager.OpenPanel(UIName.PokemonSkillInfoPopup,curPokemonData.id,curPokemonData.lv,curPokemonData.star + 1)
            end)
        end
    end
    local curSkillConFig = ConfigManager.GetConfigData(ConfigName.SpiritAnimalSkill,curSkillId)
    this.skill1Icon.sprite = Util.LoadSprite(GetResourcePath(curSkillConFig.Icon))
    this.skill1Lv.text = curSkillConFig.Level
    Util.AddOnceClick(this.skill1Btn, function()
        UIManager.OpenPanel(UIName.PokemonSkillInfoPopup,curPokemonData.id,curPokemonData.lv,curPokemonData.star)
    end)
    -- if nextSkillId > 0 then
    --     this.skillTip.text = "提升预览："..nextSkillConFig.Name
    -- else
    --     this.skillTip.text = "已满星"
    -- end

    local upStarMaterialsData = {{curPokemonData.id,curUpStarConfig.ConsumeItemNum}}
    for i = 1, #curUpStarConfig.ConsumeRes do
        table.insert(upStarMaterialsData,curUpStarConfig.ConsumeRes[i])
    end
    isUpStarMaterials = 0
    for i = 1, #upStarMaterialsPre do
        local itemParent = Util.GetGameObject(upStarMaterialsPre[i],"itemParent")
        local num = Util.GetGameObject(upStarMaterialsPre[i],"num"):GetComponent("Text")
        if upStarMaterialsData[i] then
            upStarMaterialsPre[i]:SetActive(true)
            local configMaterialId = upStarMaterialsData[i][1]
            local configMaterialNum = upStarMaterialsData[i][2]
            SubUIManager.Open(SubUIConfig.ItemView, itemParent.transform):OnOpen(false, {configMaterialId,0}, 1.3)
            local curMaterialBagNum = 0
            if i == 1 then--需要的灵兽
                curUpStarSelectPokemonData = {}
                local NoUpLvPokemonData = PokemonManager.GetNoUpLvPokemonData(curPokemonData.id,curPokemonData.dynamicId)
                curMaterialBagNum = LengthOfTable(NoUpLvPokemonData) 
                for i = 1, #NoUpLvPokemonData do
                    if i <= configMaterialNum then
                        
                        table.insert(curUpStarSelectPokemonData,NoUpLvPokemonData[i].dynamicId)
                    end
                end
            elseif  i >= 2 then--需要的材料
                curMaterialBagNum = BagManager.GetItemCountById(upStarMaterialsData[i][1])
            end
            if curMaterialBagNum < configMaterialNum then
                if isUpStarMaterials <= 0 then
                    isUpStarMaterials = configMaterialId
                end
                -- go.transform:Find("Image").gameObject:SetActive(true)--显示加号
                num.text=string.format("<color=#FF0000FF>%s/%s</color>",PrintWanNum2(curMaterialBagNum),PrintWanNum2(configMaterialNum))
            else
                -- go.transform:Find("Image").gameObject:SetActive(false)--隐藏加号
                num.text=string.format("<color=#FFFFFFFF>%s/%s</color>",PrintWanNum2(curMaterialBagNum),PrintWanNum2(configMaterialNum))
            end
        else
            upStarMaterialsPre[i]:SetActive(false)
        end
    end

    if isUpStarMaterials ~= 0 then
        parent.RefreshRedPoint(2,false)
        this.upStarBtnRedPoint:SetActive(false)
    else
        parent.RefreshRedPoint(2,true)
        this.upStarBtnRedPoint:SetActive(true)
    end

end

--扣除升星 消耗的材料  更新英雄数据
function this.DeleteUpStarMaterials()
    if curUpStarSelectPokemonData then
        for i = 1, #curUpStarSelectPokemonData do
            PokemonManager.RemoveSinglePokemonData(curUpStarSelectPokemonData[i])
        end
    end
end


--进阶按钮点击事件处理
function this.StarUpClick()
    
    if isUpStarMaterials ~= 0 then
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(12488), ConfigManager.GetConfigData(ConfigName.ItemConfig,isUpStarMaterials).Name))
        return
    end
    local oldWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
    NetManager.UpPokemonStarRequest(curPokemonData.dynamicId,curUpStarSelectPokemonData, function()
        PokemonManager.UpdateSinglePokemonData(curPokemonData.dynamicId,curPokemonData.lv,curPokemonData.star + 1)
        curPokemonData = PokemonManager.GetSinglePokemonData(curPokemonData.dynamicId)
        this.DeleteUpStarMaterials()
        UIManager.OpenPanel(UIName.PokemonUpStarSuccessPanel,curPokemonData)
        this.OnShowData()
        local newWarPower = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_NORMAL)
        PokemonManager.PiaoWarPowerChange(oldWarPower,newWarPower)
        FormationManager.CheckHeroIdExist()
    end)
end


function this:OnClose()
end

function this:OnDestroy()
end

return this