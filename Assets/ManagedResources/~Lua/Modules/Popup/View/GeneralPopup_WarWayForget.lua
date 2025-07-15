local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0

local ItemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local WarWaySkillConfig=ConfigManager.GetConfig(ConfigName.WarWaySkillConfig)


function this:InitComponent(gameObject)
    this.FontConsumeImage = Util.GetGameObject(gameObject, "Root/FontConsume/Image"):GetComponent("Image")
    this.FontBackImage = Util.GetGameObject(gameObject, "Root/FontBack/Image"):GetComponent("Image")

    this.FontConsumeText = Util.GetGameObject(gameObject, "Root/FontConsume/Num"):GetComponent("Text")
    this.FontBackText = Util.GetGameObject(gameObject, "Root/FontBack/Num"):GetComponent("Text")

    this.ConfirmBtn = Util.GetGameObject(gameObject, "ConfirmBtn")
    this.CancelBtn = Util.GetGameObject(gameObject, "CancelBtn")
end

function this:BindEvent()
    Util.AddClick(this.CancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.ConfirmBtn,function()
        NetManager.WarWayForget(this.heroData.dynamicId, this.warWaySlotId, this.slot, function()
            HeroManager.UpdateWarWayData(this.heroData.dynamicId, this.slot, this.warWaySlotId, false)
            RoleInfoPanel:UpdatePanelData()

            parent:ClosePanel()
            if this.parentRoot then
                this.parentRoot:ClosePanel()
            end
        end)
    end)
    
end

function this:AddListener()

end

function this:RemoveListener()

end

function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder = _parent.sortingOrder
    local _args = {...}
    this.heroData = _args[1]
    this.slot = _args[2]
    this.warWaySlotId = _args[3]
    this.parentRoot = _args[4]

    self:Init()
end

function this:Init()
    local warWayConfig = WarWaySkillConfig[this.warWaySlotId]
    local costId = warWayConfig.ForgetCost[1]
    local costNum = warWayConfig.ForgetCost[2]
    local itemConfigConsume = ItemConfig[costId]
    this.FontConsumeImage.sprite = Util.LoadSprite(GetResourcePath(itemConfigConsume.ResourceID))
    this.FontConsumeText.text = tostring(costNum)

    local backId = warWayConfig.Forget[1]
    local backNum = warWayConfig.Forget[2]
    local itemConfigBack = ItemConfig[backId]
    this.FontBackImage.sprite = Util.LoadSprite(GetResourcePath(itemConfigBack.ResourceID))
    this.FontBackText.text = tostring(backNum)
end

function this:OnClose()
    
end

function this:OnDestroy()

end

return this