require("Base/BasePanel")
LeadGeneEvolutionPanel = Inherit(BasePanel)
local this = LeadGeneEvolutionPanel
local SkillConfig = ConfigManager.GetConfig(ConfigName.SkillConfig)
local cost = nil--消耗
local costSkill = nil
local selectId = nil

--初始化组件（用于子类重写）
function LeadGeneEvolutionPanel:InitComponent()
    this.mask = Util.GetGameObject(this.gameObject, "mask")
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.btnUpLv = Util.GetGameObject(this.gameObject, "btnUpLv")
    this.curInfo = Util.GetGameObject(this.gameObject, "curInfo")
    this.nextInfo = Util.GetGameObject(this.gameObject, "nextInfo")
    this.cost = Util.GetGameObject(this.gameObject, "cost")
    this.costSkill = Util.GetGameObject(this.gameObject, "costSkill")
end

--绑定事件（用于子类重写）
function LeadGeneEvolutionPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnUpLv, function ()
        AircraftCarrierManager.SkillLevelUp(selectId, function ()
            local curConfigId = AircraftCarrierManager.GetSingleSkillData(selectId).cfgId
            local nextConfig = AircraftCarrierManager.GetSkillNextIdForConfigId(curConfigId)
            if not nextConfig then
                self:ClosePanel()
                UIManager.OpenPanel(UIName.LeadGeneTopLevelPanel, selectId, curConfigId)
            else
                this:OnShow()
            end
            Game.GlobalEvent:DispatchEvent(GameEvent.Lead.RefreshInfo)
            Game.GlobalEvent:DispatchEvent(GameEvent.Bag.OnRefreshRune)
        end)
    end)
end

--添加事件监听（用于子类重写）
function LeadGeneEvolutionPanel:AddListener()
end

--移除事件监听（用于子类重写）
function LeadGeneEvolutionPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function LeadGeneEvolutionPanel:OnOpen(id)
    selectId = id
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LeadGeneEvolutionPanel:OnShow()
    this.SetCurInfo()
    this.SetNextInfo()
    this.SetCost()
end

--界面关闭时调用（用于子类重写）
function LeadGeneEvolutionPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function LeadGeneEvolutionPanel:OnDestroy()
    cost = nil
    costSkill = nil
    selectId = nil
end

--设置消耗
function this.SetCost()
    if not cost then
        cost = SubUIManager.Open(SubUIConfig.ItemView, this.cost.transform)
    end
    local configId = AircraftCarrierManager.GetSingleSkillData(selectId).cfgId
    local config = AircraftCarrierManager.GetSkillLvImgForId(configId)
    cost:OnOpen(false, config.config.CostItem, 0.6)
    cost:SetNum(GetNumUnenoughColor(BagManager.GetItemCountById(config.config.CostItem[1]), config.config.CostItem[2]))

    if not costSkill then
        costSkill = SubUIManager.Open(SubUIConfig.ItemView, this.costSkill.transform)
    end
    costSkill:OnOpen(false, config.config.CostPlane, 0.6)
    local ownConditionCnt = AircraftCarrierManager.GetSkillSimilarCount(config.config.CostPlane[1], selectId)
    costSkill:SetNum(GetNumUnenoughColor(ownConditionCnt, config.config.CostPlane[2]))
end

--设置当前技能属性
function this.SetCurInfo()
    local configId = AircraftCarrierManager.GetSingleSkillData(selectId).cfgId
    this.SetPro(this.curInfo, configId)
end

--设置下一级技能属性
function this.SetNextInfo()
    local curConfigId = AircraftCarrierManager.GetSingleSkillData(selectId).cfgId
    local nextConfigId = AircraftCarrierManager.GetSkillNextIdForConfigId(curConfigId).Id
    this.SetPro(this.nextInfo, nextConfigId)
end

function this.SetPro(item, configId)
    local frame = Util.GetGameObject(item, "frame"):GetComponent("Image")
    local icon = Util.GetGameObject(item, "frame/icon"):GetComponent("Image")
    local level = Util.GetGameObject(item, "frame/level"):GetComponent("Image")
    local name = Util.GetGameObject(item, "name"):GetComponent("Text")
    local skillName = Util.GetGameObject(item, "skillName"):GetComponent("Text")
    local type = Util.GetGameObject(item, "type"):GetComponent("Text")
    local desc = Util.GetGameObject(item, "desc"):GetComponent("Text")
    local skillGrid = Util.GetGameObject(item, "skill")

    local config = AircraftCarrierManager.GetSkillLvImgForId(configId)
    frame.sprite = Util.LoadSprite(GetQuantityImageByquality(config.config.Quality))
    icon.sprite = SetIcon(configId)
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

    local skillPro = AircraftCarrierManager.GetMainProList(configId)
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

return LeadGeneEvolutionPanel