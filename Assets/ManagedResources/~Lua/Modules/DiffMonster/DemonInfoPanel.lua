require("Base/BasePanel")
DemonInfoPanel = Inherit(BasePanel)
local this = DemonInfoPanel
local demonDataConfig = ConfigManager.GetConfig(ConfigName.DifferDemonsConfig)
local skillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)

local skillConfigItem
-- 当前界面异妖信息
local pokeMon = {}
--异妖立绘信息数据表, 索引值是异妖的ID
local demonImgInfo = {
    [1] = "live2d_s_jieling_dlg_3010",
    [2] = "live2d_s_jieling_zlz_3001",
    [3] = "live2d_s_jieling_hg_3002",
    [4] = "live2d_s_jieling_jhj_3003",
    [5] = "live2d_s_jieling_hs_3006",
    [6] = "live2d_s_jieling_lms_3009",
    [7] = "live2d_s_jieling_sl_3005",
    [8] = "live2d_s_jieling_md_3007",
    [9] = "live2d_s_jieling_fl_3008",
    [10] = "live2d_s_jieling_tl_3004",
}

--初始化组件（用于子类重写）
function DemonInfoPanel:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.helpBtn = Util.GetGameObject(self.gameObject, "helpBtn")
    this.helpPosition = this.helpBtn:GetComponent("RectTransform").localPosition
    -- 异妖信息面板
    this.live2dRoot = Util.GetGameObject(self.gameObject, "Live2dRoot")
    this.textName = Util.GetGameObject(self.gameObject, "NameImg/NameText"):GetComponent("Text")
    -- 配件预设
    this.compIconPrefab = Util.GetGameObject(self.gameObject, "CompList/CompPrefab")
    this.compParent = Util.GetGameObject(self.gameObject, "CompList/CompViewRect/Content")
    -- 异妖进阶信息面板
    this.proPer = Util.GetGameObject(self.gameObject, "DemonInfoRoot/proPer")
    this.proGrid = Util.GetGameObject(self.gameObject, "DemonInfoRoot/proRect/proGrid")
    this.SkillIcon = Util.GetGameObject(self.gameObject, "DemonInfoRoot/SkillInfoRoot/SkillIcon"):GetComponent("Image")
    this.SkillLevel = Util.GetGameObject(self.gameObject, "DemonInfoRoot/SkillInfoRoot/skillLevel"):GetComponent("Text")
    this.skillName = Util.GetGameObject(self.gameObject, "DemonInfoRoot/SkillInfoRoot/skillName"):GetComponent("Text")
    this.skillInfoText = Util.GetGameObject(self.gameObject, "DemonInfoRoot/SkillInfoRoot/skillDesc/skillInfoText"):GetComponent("Text")
    this.btnSkillIcon = Util.GetGameObject(self.gameObject, "DemonInfoRoot/SkillInfoRoot/SkillIcon")
    this.btnLevelUp = Util.GetGameObject(self.gameObject, "DemonInfoRoot/BtnLevelUp")

    this.qualityImage=Util.GetGameObject(self.gameObject,"intelligenceBg"):GetComponent("Image")
    this.intelligenceValue = Util.GetGameObject(self.gameObject, "intelligenceBg/value"):GetComponent("Text")

    --可升阶提示
    this.upGradFlag = Util.GetGameObject(self.gameObject, "DemonInfoRoot/BtnLevelUp/upGradFlag")

    --this.BtView = SubUIManager.Open(SubUIConfig.BtView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

end

--绑定事件（用于子类重写）
function DemonInfoPanel:BindEvent()

    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.DiffMonsterPanel)
    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup, HELP_TYPE.DiffMonster, this.helpPosition.x, this.helpPosition.y)
    end)

    Util.AddClick(this.btnSkillIcon, function()
        local skillData = {}
        skillData.skillConfig = skillConfigItem
        local maxLv = DiffMonsterManager.GetDifferSkillMaxLevel(1)
        UIManager.OpenPanel(UIName.SkillInfoPopup, skillData, 1, 100, maxLv, 3)
    end)
    Util.AddClick(this.btnLevelUp, function()
        if pokeMon.stage < #pokeMon.pokemonUpLvConfigList then
            UIManager.OpenPanel(UIName.DemonUpGradePanel, pokeMon)
            --this.PokemonUpStarDataShow()
        else
            PopupTipPanel.ShowTipByLanguageId(10445)
        end
    end)
end

--界面打开时调用（用于子类重写）
--context = {pokemon}
function DemonInfoPanel:OnOpen(context)

    pokeMon = context.pokemon
    this.ShowCompByPokemon(pokeMon)
    this.JudgeUpGradCondition(pokeMon)

    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.DiffMonster })
    --this.BtView:OnOpen({ sortOrder = self.sortingOrder, panelType = PanelTypeView.DiffMonsterPanel })

end

function DemonInfoPanel:OnShow()
    this.LoadLive2d(pokeMon.id)
end

--界面关闭时调用（用于子类重写）
function DemonInfoPanel:OnClose()

    if this.LiveName then
        poolManager:UnLoadLive(this.LiveName, this.LiveGO)
        this.LiveName = nil
    end
end

--界面销毁时调用（用于子类重写）
function DemonInfoPanel:OnDestroy()

    --SubUIManager.Close(this.BtView)
    SubUIManager.Close(this.UpView)
end

-- 初始异妖信息
function this.LoadLive2d(demonId)
    if this.LiveName then
        poolManager:UnLoadLive(this.LiveName, this.LiveGO)
        this.LiveName = nil
    end

    this.LiveName = demonImgInfo[demonId]
    local Scale = Vector3(demonDataConfig[demonId].Scale, demonDataConfig[demonId].Scale, demonDataConfig[demonId].Scale)
    this.LiveGO = poolManager:LoadLive(this.LiveName, this.live2dRoot.transform, Scale, Vector3.zero)
    local position = demonDataConfig[demonId].Position
    this.LiveGO:GetComponent("RectTransform").anchoredPosition = Vector2.New(position[1], position[2]) 
    -- 设置名字
    this.textName.text = demonDataConfig[demonId].Name
    this.qualityImage.sprite=GetQuantityImage(demonDataConfig[demonId].Aptitude)
    this.intelligenceValue.text = demonDataConfig[demonId].Aptitude
end
-- 异妖信息显示
function this.ShowCompByPokemon(pokemon)
    --属性
    local allProVal = DiffMonsterManager.CalculatePokemonPeiJiAllProAddVal(pokemon.id)
    Util.ClearChild(this.proGrid.transform)
    for k, v in pairs(allProVal) do
        if v > 0 then
            local go = newObject(this.proPer)
            go.transform:SetParent(this.proGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            go:SetActive(true)
            if PropertyTypeIconDef[k] then
                Util.GetGameObject(go, "icon"):GetComponent("Image").sprite = Util.LoadSprite(PropertyTypeIconDef[k])
            end
            Util.GetGameObject(go, "icon"):GetComponent("Image"):SetNativeSize()
            Util.GetGameObject(go, "proName"):GetComponent("Text").text = ConfigManager.GetConfigData(ConfigName.PropertyConfig, k).Info .. ":"
            Util.GetGameObject(go, "proValue"):GetComponent("Text").text = GetPropertyFormatStr(ConfigManager.GetConfigData(ConfigName.PropertyConfig, k).Style, v)
        end
    end
    --技能
    local skillId = pokemon.pokemonUpLvConfigList[pokemon.stage].configData.SkillId
    skillConfigItem = skillConfig[skillId]
    if skillConfigItem then
        this.SkillIcon.sprite = Util.LoadSprite(GetResourcePath(skillConfigItem.Icon))
        this.SkillLevel.text = pokemon.stage
        this.skillName.text = skillConfigItem.Name
        this.skillInfoText.text = GetSkillConfigDesc(skillConfigItem)
    end
    --配件
    Util.ClearChild(this.compParent.transform)
    for i = 1, #pokemon.pokemoncomonpentList do
        --初始化配件数
        local item = pokemon.pokemoncomonpentList[i]
        local comp = newObjToParent(this.compIconPrefab, this.compParent)
        Util.GetGameObject(comp, "Get"):GetComponent("Image").sprite =  SetFrame(item.id)
        Util.GetGameObject(comp, "icon"):GetComponent("Image").sprite = SetIcon(item.id)
        Util.GetGameObject(comp, "levelBg/value"):GetComponent("Text").text = "+" .. item.level
        Util.GetGameObject(comp, "upGradFlag").gameObject:SetActive(this.JudgeComponentCanBeUpData(item))
        Util.AddOnceClick(comp, function()
            UIManager.OpenPanel(UIName.DemonPartsUpStarPanel, pokemon, 2, i)
        end)
    end
end

--判断部件是否可以升级
function this.JudgeComponentCanBeUpData(componentInfo)
    local maxLv = #componentInfo.upLvMateriaConfiglList
    local currentLv = componentInfo.level + 1
    if currentLv >= maxLv then
        return false
    else
        local materialEnough = true
        local costMaterials = componentInfo.upLvMateriaConfiglList[currentLv].Cost
        for idx = 1, #costMaterials do
            materialEnough = materialEnough and this.MaterialEnoughOrNot(costMaterials[idx][1], costMaterials[idx][2])
        end
        return materialEnough
    end
end

function this.MaterialEnoughOrNot(propId, needNumber)
    local ownNumber = BagManager.GetItemCountById(propId)
    return ownNumber >= needNumber
end

--判断异妖是否可升阶
function this.JudgeUpGradCondition(pokemon)
    local meetCondition = this.GetUpGradLevelCondition(pokemon)
    meetCondition = meetCondition and this.GetUpGradMaterialCondition(pokemon)
    this.upGradFlag.gameObject:SetActive(meetCondition)
end

--异妖升阶配件等级是否满足
function this.GetUpGradLevelCondition(pokemon)
    local meetCondition = true
    table.walk(pokemon.pokemoncomonpentList, function(componentInfo)
        meetCondition = meetCondition and componentInfo.level > pokemon.stage
    end)
    return meetCondition
end

--异妖进阶材料是否满足
function this.GetUpGradMaterialCondition()
    local meetConditon = true
    local upStarMaterial = pokeMon.pokemonUpLvConfigList[pokeMon.stage + 1].configData.Cost
    for i = 1, #upStarMaterial do
        if upStarMaterial[i][1] == 14 then
            meetConditon = meetConditon and BagManager.GetItemCountById(upStarMaterial[i][1]) >= upStarMaterial[i][2]
        else
            if upStarMaterial[i][2] > 0 then
                meetConditon = meetConditon and BagManager.GetItemCountById(upStarMaterial[i][1]) >= upStarMaterial[i][2]
            end
        end
    end
    return meetConditon
end

return DemonInfoPanel