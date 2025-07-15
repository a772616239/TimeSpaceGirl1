local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder=0

function this:InitComponent(gameObject)
    this.FontImage = Util.GetGameObject(gameObject, "font/Image"):GetComponent("Image")
    this.FontText = Util.GetGameObject(gameObject, "font/num"):GetComponent("Text")


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
    this.costItemId = _args[2]
    this.endStr = _args[3]

    self:Init()
end

function this:Init()
    this.FontImage.sprite = SetIcon(this.costItemId)
    this.FontText.text = this.endStr
end

function this:OnClose()
    
end

function this:OnDestroy()

end

return this