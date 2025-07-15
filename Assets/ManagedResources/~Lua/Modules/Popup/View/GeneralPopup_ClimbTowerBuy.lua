local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0

local ItemConfig=ConfigManager.GetConfig(ConfigName.ItemConfig)
local SpecialConfig=ConfigManager.GetConfig(ConfigName.SpecialConfig)


function this:InitComponent(gameObject)
    this.FontImage = Util.GetGameObject(gameObject, "Root/Font/Image"):GetComponent("Image")
    this.FontText = Util.GetGameObject(gameObject, "Root/Font/Num"):GetComponent("Text")


    this.ConfirmBtn = Util.GetGameObject(gameObject, "ConfirmBtn")
    this.CancelBtn = Util.GetGameObject(gameObject, "CancelBtn")
end

function this:BindEvent()
    Util.AddClick(this.CancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.ConfirmBtn,function()
        if this.SureFunc then
            this.SureFunc()
        end
        parent:ClosePanel()
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
    this.SureFunc = _args[1]
    this.times = _args[2]


    self:Init()
end

function this:Init()
    local cost, itemid = ClimbTowerManager.GetBuyCost(ClimbTowerManager.ClimbTowerType.Normal, this.times)
    local itemData = ItemConfig[itemid]
    this.FontImage.sprite = Util.LoadSprite(GetResourcePath(itemData.ResourceID))
    this.FontText.text = string.format(GetLanguageStrById(12526), tostring(cost))

end

function this:OnClose()
    
end

function this:OnDestroy()

end

return this