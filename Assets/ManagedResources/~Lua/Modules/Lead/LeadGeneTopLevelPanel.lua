require("Base/BasePanel")
LeadGeneTopLevelPanel = Inherit(BasePanel)
local this = LeadGeneTopLevelPanel
local SkillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local singleId = nil
local cfgId = nil
local isShowBtn = false
local showType = 1
--1-分解 2-进化 3-配置 4-卸下
local btnType = {
    [1] = {1, 2, 3},
    [2] = {1, 3},
    [3] = {4},
}

--初始化组件（用于子类重写）
function LeadGeneTopLevelPanel:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.mask = Util.GetGameObject(this.gameObject, "mask")

    this.btns = {}
    for i = 1, 4 do
        this.btns[i] = Util.GetGameObject(this.gameObject, "btns").transform:GetChild(i-1).gameObject
    end
end

--绑定事件（用于子类重写）
function LeadGeneTopLevelPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function ()
        self:ClosePanel()
    end)
    for i = 1, 4 do
        Util.AddClick(this.btns[i], function ()
            self:ClosePanel()
            this.Jump(i)
        end)
    end
end

--添加事件监听（用于子类重写）
function LeadGeneTopLevelPanel:AddListener()
end

--移除事件监听（用于子类重写）
function LeadGeneTopLevelPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function LeadGeneTopLevelPanel:OnOpen(id, cfgid, showBtn, type)
    singleId = id
    cfgId = cfgid
    isShowBtn = showBtn
    showType = type or 0
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LeadGeneTopLevelPanel:OnShow()
    this.SetPro()
    local nextConfig = AircraftCarrierManager.GetSkillNextIdForConfigId(cfgId)
    this.btns[2]:SetActive(not not nextConfig)
    Util.GetGameObject(this.gameObject, "btns"):SetActive(isShowBtn)

    if showType > 0 then
        for i = 1, #this.btns do
            this.btns[i]:SetActive(false)
            for j = 1, #btnType[showType] do
                if i == btnType[showType][j] then
                    this.btns[i]:SetActive(true)
                end
            end
        end
    end
end

--界面关闭时调用（用于子类重写）
function LeadGeneTopLevelPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function LeadGeneTopLevelPanel:OnDestroy()
    singleId = nil
    isShowBtn = false
end

function this.SetPro()
    local frame = Util.GetGameObject(this.gameObject, "frame"):GetComponent("Image")
    local icon = Util.GetGameObject(this.gameObject, "frame/icon"):GetComponent("Image")
    local level = Util.GetGameObject(this.gameObject, "frame/level"):GetComponent("Image")
    local name = Util.GetGameObject(this.gameObject, "name"):GetComponent("Text")
    local skillName = Util.GetGameObject(this.gameObject, "skillName"):GetComponent("Text")
    local type = Util.GetGameObject(this.gameObject, "type"):GetComponent("Text")
    local desc = Util.GetGameObject(this.gameObject, "desc"):GetComponent("Text")
    local skillGrid = Util.GetGameObject(this.gameObject, "skill")
    local lv = Util.GetGameObject(this.gameObject, "lv")

    local config = AircraftCarrierManager.GetSkillLvImgForId(cfgId)
    local nextConfig = AircraftCarrierManager.GetSkillNextIdForConfigId(cfgId)
    lv:SetActive(not nextConfig)
    frame.sprite = Util.LoadSprite(GetQuantityImageByquality(config.config.Quality))
    icon.sprite = SetIcon(cfgId)
    name.text = GetLanguageStrById(config.config.Name)
    local skillData = SkillConfig[config.config.Skill]
    skillName.text = GetLanguageStrById(skillData.Name)
    type.text = skillData.Type
    if skillData.Type == SkillType.Jue then
        type.text = GetLanguageStrById(12500)
    elseif skillData.Type == SkillType.Bei then
        type.text = GetLanguageStrById(12501)
    end
    desc.text = GetSkillConfigDesc(skillData)
    level.sprite = Util.LoadSprite(config.lvImg)

    local skillPro = AircraftCarrierManager.GetMainProList(cfgId)
    for i = 1, #skillPro do
        local skill = skillGrid.transform:GetChild(i-1)
        local icon = Util.GetGameObject(skill, "icon"):GetComponent("Image")
        local name = Util.GetGameObject(skill, "name"):GetComponent("Text")
        local value = Util.GetGameObject(skill, "value"):GetComponent("Text")

        icon.sprite = Util.LoadSprite(skillPro[i].PropertyConfig.BuffShow)
        name.text = GetLanguageStrById(skillPro[i].PropertyConfig.Info)
        value.text = skillPro[i].propertyValue
    end
end

function this.Jump(i)
    if i == 1 then
        if AircraftCarrierManager.GetSkillIsEquipForId(singleId) then
            PopupTipPanel.ShowTipByLanguageId(50368)
            return
        end
        UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.GeneDecompose, singleId, function()
        end)
    elseif i == 2 then
        AircraftCarrierManager.GetLeadData(function()
            AircraftCarrierManager.GetAllPlaneReq(function()
                UIManager.OpenPanel(UIName.LeadGeneEvolutionPanel, singleId)
            end)
        end)
    elseif i == 3 then
        AircraftCarrierManager.GetLeadData(function()
            AircraftCarrierManager.GetAllPlaneReq(function()
                UIManager.OpenPanel(UIName.LeadAssemblyPanel)
            end)
        end)
    elseif i == 4 then
        AircraftCarrierManager.EquipOrDowmSkill(singleId, function ()
        end)
    end
end

return LeadGeneTopLevelPanel