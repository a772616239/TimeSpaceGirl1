----- 社稷大典检查是否加入公会 -----
local this = {}
local showType
local parent

function this:InitComponent(gameObject)
    this.bodyText = Util.GetGameObject(gameObject,"BodyText"):GetComponent("Text")
    this.btnSure = Util.GetGameObject(gameObject,"ConfirmBtn")
    this.btnCancel = Util.GetGameObject(gameObject,"CancelBtn")
end

function this:BindEvent()
    Util.AddClick(this.btnCancel,function()
        parent:ClosePanel()
        UIManager.OpenPanel(UIName.DynamicActivityPanel,1)
    end)

    Util.AddClick(this.btnSure,function()
        JumpManager.GoJump(4001)
    end)
end

function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(this,_showType)
    parent = this
    showType = _showType
end

function this:OnClose()
end

function this:OnDestroy()
end

return this