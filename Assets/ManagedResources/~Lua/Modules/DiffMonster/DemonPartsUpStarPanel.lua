require("Base/BasePanel")
DemonPartsUpStarPanel = Inherit(BasePanel)
local this = DemonPartsUpStarPanel
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local pokemoncomonpentList
local pokemonId
local curPokemoncomonpentData
local index = 0
local isHaveMaterial
local maxLv
local openPanelType--1 返回DiffMonsterPanel  21 返回DemonInfoPanel

--初始化组件（用于子类重写）
function DemonPartsUpStarPanel:InitComponent()

    this.compPrefab = Util.GetGameObject(self.gameObject, "CompPrefab")
    this.compScroll = Util.GetGameObject(self.gameObject, "CompScroll")

    this.compCurrentLv = Util.GetGameObject(self.gameObject, "CompMes/currentLevel"):GetComponent("Text")
    this.compNextLv = Util.GetGameObject(self.gameObject, "CompMes/nextLevel"):GetComponent("Text")

    this.bg = Util.GetGameObject(self.gameObject, "bg")
    this.proPer = Util.GetGameObject(self.gameObject, "proPer")
    this.proGrid = Util.GetGameObject(self.gameObject, "proRect/proGrid")

    --高星超能力
    this.extraProContent = Util.GetGameObject(self.gameObject, "extraProList/viewPort/extraContent")
    this.extraItem = Util.GetGameObject(self.gameObject, "extraItem")

    this.itemPre = Util.GetGameObject(self.gameObject, "material/itemPre")
    this.itemScroll = Util.GetGameObject(self.gameObject, "material/itemScroll")
    this.costIcon = Util.GetGameObject(self.gameObject, "material/costIcon")
    this.costCount = Util.GetGameObject(self.gameObject, "material/costIcon/costCount"):GetComponent("Text")
    this.material = Util.GetGameObject(self.gameObject, "material")
    this.noMaterialTishiText = Util.GetGameObject(self.gameObject, "noMaterialTishiText")
    this.btnUp = Util.GetGameObject(self.gameObject, "btnUp")
    this.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
end

--绑定事件（用于子类重写）
function DemonPartsUpStarPanel:BindEvent()

    Util.AddClick(this.btnBack, function()
        self:ClosePanel()
        if openPanelType == 2 then
            UIManager.OpenPanel(UIName.DemonInfoPanel, { pokemon = DiffMonsterManager.GetSinglePokemonData(pokemonId) })
        end
    end)
    Util.AddClick(this.btnUp, function()
        if curPokemoncomonpentData.level < maxLv then
            if isHaveMaterial then
                NetManager.DemonCompUpRequest(pokemonId, curPokemoncomonpentData.id, function()
                    this.UpdatePokemonPeiJianData()
                end)
            else
                PopupTipPanel.ShowTipByLanguageId(10446)
            end
        else
            PopupTipPanel.ShowTipByLanguageId(10447)
        end
    end)
end

--界面打开时调用（用于子类重写）
function DemonPartsUpStarPanel:OnOpen(...)

    local data = { ... }
    pokemoncomonpentList = data[1].pokemoncomonpentList
    openPanelType = data[2]
    pokemonId = data[1].id
    index = data[3]
    this.UpdataPokemoncomonpentList()
    this.UpdataPeiJianProData(pokemoncomonpentList[index])
    curPokemoncomonpentData = pokemoncomonpentList[index]
    this.SetExtraPropList()
end

function this.UpdataPokemoncomonpentList()
    --配件
    Util.ClearChild(this.compScroll.transform)
    --初始化配件数
    local comp = newObjToParent(this.compPrefab, this.compScroll)
    local item = pokemoncomonpentList[index]
    comp:SetActive(true)
    Util.GetGameObject(comp, "mask"):SetActive(true)
    if item.level > 0 then
        --配件已激活
        Util.GetGameObject(comp, "mask"):SetActive(false)
        this.compCurrentLv.text = GetLanguageStrById(itemConfig[item.id].Name) .. " " .. item.level
        local maxLv = #item.upLvMateriaConfiglList
        this.compNextLv.text = maxLv ~= item.level and item.level + 1 or item.level
        Util.GetGameObject(comp, "iconBg"):GetComponent("Image").sprite = SetFrame(item.id)
        Util.GetGameObject(comp, "iconBg/icon"):GetComponent("Image").sprite = SetIcon(item.id)
        Util.GetGameObject(comp, "upLvFlag"):SetActive(this.JudgeComponentCanBeUpData(item))
    else
        Util.GetGameObject(comp, "mask"):SetActive(true)
        this.compCurrentLv.text = GetLanguageStrById(itemConfig[item.id].Name) .. " " .. 0
        this.compNextLv.text = "1"
        Util.GetGameObject(comp, "iconBg/icon"):GetComponent("Image").sprite = SetFrame(item.id)
        Util.GetGameObject(comp, "iconBg/icon"):GetComponent("Image").sprite = SetIcon(item.id)
    end
    Util.AddOnceClick(comp, function()
        if item.level > 0 then
            --配件已激活
            this.UpdataPeiJianProData(item)
            curPokemoncomonpentData = item
            this.SetExtraPropList()
        else
            PopupTipPanel.ShowTipByLanguageId(10448)
        end
    end)
end

function this.UpdataComponenExtraEffect()
    local targetConfigs = {}
    for _, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.DifferDemonsComonpentsConfig)) do
        if v.ComonpentsId == curPokemoncomonpentData.id and v.ExtraAdd then
            table.insert(targetConfigs, v)
        end
    end
    return targetConfigs
end

function this.SetExtraPropList()
    Util.ClearChild(this.extraProContent.transform)
    local item = pokemoncomonpentList[index]
    local compConfigs = this.UpdataComponenExtraEffect()
    table.walk(compConfigs, function(configInfo)
        local go = newObjToParent(this.extraItem, this.extraProContent)
        local lvText = Util.GetGameObject(go, "lv"):GetComponent("Text")
        if curPokemoncomonpentData.level < configInfo.Stage then
            lvText.text = string.format("<color=#635D4AFF>%s+%s</color>", GetLanguageStrById(itemConfig[item.id].Name), configInfo.Stage)
        else
            lvText.text = string.format("%s+%s", GetLanguageStrById(itemConfig[item.id].Name), configInfo.Stage)
        end

        local str, name, propName, propValue = ""
        for i = 1, #configInfo.ExtraAdd do
            name, propName, propValue = this.GetDescAssociate(configInfo.ExtraAdd[i])
            local activeStr
            if item.level >= configInfo.Stage then
                activeStr = GetLanguageStrById(10449)
                str = str .. "\t" .. string.format("%s%s<color=#34B936FF>+%s</color>%s", name, propName, propValue, activeStr)
            else
                activeStr = GetLanguageStrById(10450)
                str = str .. "\t" .. string.format("<color=#635D4AFF>%s%s<color=#1C4B15FF>+%s</color>%s</color>", name, propName, propValue, activeStr)
            end
        end
        Util.GetGameObject(go, "effect"):GetComponent("Text").text = str
    end)
end

function this.GetDescAssociate(context)
    local name, propName, propValue
    name = HeroOccupationDef[context[1]]
    local propConfig = ConfigManager.GetConfigData(ConfigName.PropertyConfig, context[2])
    propName = propConfig.Info
    propValue = GetPropertyFormatStr(propConfig.Style, context[3])
    return name, propName, propValue
end

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

--刷新配件信息
function this.UpdataPeiJianProData(_pokemoncomonpent)
    --属性
    maxLv = #_pokemoncomonpent.upLvMateriaConfiglList
    local allProValCur = _pokemoncomonpent.upLvMateriaConfiglList[_pokemoncomonpent.level].BaseAttribute
    local nextLv = _pokemoncomonpent.level ~= maxLv and _pokemoncomonpent.level + 1 or _pokemoncomonpent.level
    local allProVal = _pokemoncomonpent.upLvMateriaConfiglList[nextLv].BaseAttribute
    Util.ClearChild(this.proGrid.transform)
    for j = 1, #allProVal do
        local go = newObjToParent(this.proPer, this.proGrid.transform)
        local propertyConfig = ConfigManager.GetConfigData(ConfigName.PropertyConfig, allProVal[j][1])
        Util.GetGameObject(go, "proName"):GetComponent("Text").text = propertyConfig.Info .. "\t" .. GetPropertyFormatStrOne(propertyConfig.Style, allProValCur[j][2])
        Util.GetGameObject(go, "proValue"):GetComponent("Text").text = GetPropertyFormatStrOne(propertyConfig.Style, allProVal[j][2])
    end
    --消耗
    if _pokemoncomonpent.level < maxLv then
        this.material:SetActive(true)
        this.noMaterialTishiText:SetActive(false)
        isHaveMaterial = true
        this.costIcon:SetActive(false)
        Util.ClearChild(this.itemScroll.transform)
        for i = 1, #_pokemoncomonpent.upLvMateriaConfiglList[_pokemoncomonpent.level].Cost do
            --初始化配件数
            local materialInfo = _pokemoncomonpent.upLvMateriaConfiglList[_pokemoncomonpent.level].Cost[i]
            if materialInfo[1] == 14 then
                this.costIcon:SetActive(true)
                this.costCount.text = materialInfo[2]
                if BagManager.GetItemCountById(materialInfo[1]) < materialInfo[2] then
                    isHaveMaterial = false
                    this.costCount.text = string.format("<color=#FF0000FF>%s</color>", materialInfo[2])
                else
                    this.costCount.text = string.format("<color=#FFFFFFFF>%s</color>", materialInfo[2])
                end
            else
                if materialInfo[2] > 0 then
                    local comp = newObjToParent(this.itemPre, this.itemScroll)
                    comp:SetActive(true)
                    Util.GetGameObject(comp, "frame"):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[materialInfo[1]].Quantity))
                    Util.GetGameObject(comp, "icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[materialInfo[1]].ResourceID))
                    Util.AddClick(Util.GetGameObject(comp, "icon"), function()
                        UIManager.OpenPanel(UIName.RewardItemSingleShowPopup, itemConfig[materialInfo[1]].Id)
                    end)
                    if BagManager.GetItemCountById(materialInfo[1]) < materialInfo[2] then
                        isHaveMaterial = false
                        Util.GetGameObject(comp, "num"):GetComponent("Text").text = string.format("<color=#FF0000FF>%s/%s</color>", BagManager.GetItemCountById(materialInfo[1]), materialInfo[2])
                    else
                        Util.GetGameObject(comp, "num"):GetComponent("Text").text = string.format("<color=#FFFFFFFF>%s/%s</color>", BagManager.GetItemCountById(materialInfo[1]), materialInfo[2])
                    end
                end
            end
        end
    else
        this.material:SetActive(false)
        this.noMaterialTishiText:SetActive(true)
    end
end

function this.UpdatePokemonPeiJianData()
    --更新异妖配件等级
    DiffMonsterManager.UpdatePokemonPeiJianLv(pokemonId, curPokemoncomonpentData.id, curPokemoncomonpentData.level + 1)
    --更新界面数据
    pokemoncomonpentList = DiffMonsterManager.GetSinglePokemonData(pokemonId).pokemoncomonpentList
    isHaveMaterial = true
    this.UpdataPokemoncomonpentList()
    for i = 1, #pokemoncomonpentList do
        if pokemoncomonpentList[i].id == curPokemoncomonpentData.id then
            this.UpdataPeiJianProData(pokemoncomonpentList[i])
            curPokemoncomonpentData = pokemoncomonpentList[i]
        end
    end
    this.SetExtraPropList()
    --打开配件进阶成功界面
    UIManager.OpenPanel(UIName.DemonPartsUpStarSuccessPanel, curPokemoncomonpentData)

    FormationManager.UserPowerChanged()
end

return DemonPartsUpStarPanel