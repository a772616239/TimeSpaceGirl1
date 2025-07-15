local this = {}
--传入父脚本模块
local parent
local func

function this:InitComponent(gameObject)
    this.titleText = Util.GetGameObject(gameObject,"title"):GetComponent("Text")
    this.cancelBtn = Util.GetGameObject(gameObject,"CancelBtn")
    this.confirmBtn = Util.GetGameObject(gameObject,"ConfirmBtn")
end

function this:BindEvent()
    Util.AddClick(this.cancelBtn,function()
        parent:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn,function()
        parent:ClosePanel()
        func()
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent, _func)
    parent = _parent
    func = _func
    this.titleText.text = GetLanguageStrById(50155)
end

function this:OnClose()
end

function this:OnDestroy()
end

return this