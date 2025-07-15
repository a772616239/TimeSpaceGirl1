require("Base/BasePanel")
PatFaceDiffMonsterInfoPanel = Inherit(BasePanel)
local pokemonId = 0
--初始化组件（用于子类重写）
function PatFaceDiffMonsterInfoPanel:InitComponent()

    self.btnBack = Util.GetGameObject(self.transform, "btnBack")
    self.SkillIcon = Util.GetGameObject(self.transform, "DemonInfoRoot/SkillInfoRoot/skillIconBg/SkillIcon"):GetComponent("Image")
    self.skillLevel = Util.GetGameObject(self.transform, "DemonInfoRoot/SkillInfoRoot/skillLevel"):GetComponent("Text")
    self.skillName = Util.GetGameObject(self.transform, "DemonInfoRoot/SkillInfoRoot/skillName"):GetComponent("Text")
    self.skillDesc = Util.GetGameObject(self.transform, "DemonInfoRoot/SkillInfoRoot/skillDesc/skillInfoText"):GetComponent("Text")
    self.proPer = Util.GetGameObject(self.transform, "DemonInfoRoot/proPer")
    self.proGrid = Util.GetGameObject(self.transform, "DemonInfoRoot/proRect/proGrid")
end

--绑定事件（用于子类重写）
function PatFaceDiffMonsterInfoPanel:BindEvent()

    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function PatFaceDiffMonsterInfoPanel:AddListener()

end

--移除事件监听（用于子类重写）
function PatFaceDiffMonsterInfoPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function PatFaceDiffMonsterInfoPanel:OnOpen(_pokemonId)

    pokemonId = _pokemonId
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PatFaceDiffMonsterInfoPanel:OnShow()

    local differDemonsStageConfigId = 0
    local differDemonsStageConfig = {}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.DifferDemonsStageConfig)) do
        if math.floor(v.ID/100) == pokemonId then
            if differDemonsStageConfigId < v.ID then
                differDemonsStageConfigId = v.ID
                differDemonsStageConfig = v
            end
        end
    end
    local skillConFig = ConfigManager.GetConfigData(ConfigName.SkillConfig,differDemonsStageConfig.SkillId)
    self.SkillIcon.sprite = Util.LoadSprite(GetResourcePath(skillConFig.Icon))
    self.skillLevel.text = differDemonsStageConfigId % 100
    self.skillName.text = GetLanguageStrById(skillConFig.Name)
    self.skillDesc.text = GetSkillConfigDesc(skillConFig)
    local  allProVal = DiffMonsterManager.CalculatePokemonProValue(pokemonId)
    Util.ClearChild(self.proGrid.transform)
    for k, v in pairs(allProVal) do
        if v > 0 then
            local go = newObject(self.proPer)
            go.transform:SetParent(self.proGrid.transform)
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
end

--界面关闭时调用（用于子类重写）
function PatFaceDiffMonsterInfoPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function PatFaceDiffMonsterInfoPanel:OnDestroy()

end

return PatFaceDiffMonsterInfoPanel