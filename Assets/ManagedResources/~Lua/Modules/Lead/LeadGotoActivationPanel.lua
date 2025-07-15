require("Base/BasePanel")
LeadGotoActivationPanel = Inherit(BasePanel)
local this = LeadGotoActivationPanel

--初始化组件（用于子类重写）
function LeadGotoActivationPanel:InitComponent()
    this.btnBack = Util.GetGameObject(this.gameObject, "btnBack")
    this.mask = Util.GetGameObject(this.gameObject, "mask")
    this.btnGotoActivation = Util.GetGameObject(this.gameObject, "btnGotoActivation")
end

--绑定事件（用于子类重写）
function LeadGotoActivationPanel:BindEvent()
    Util.AddClick(this.btnBack, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.mask, function ()
        self:ClosePanel()
    end)
    Util.AddClick(this.btnGotoActivation, function ()
        self:ClosePanel()
        JumpManager.GoJump(36006)
    end)
end

--添加事件监听（用于子类重写）
function LeadGotoActivationPanel:AddListener()
end

--移除事件监听（用于子类重写）
function LeadGotoActivationPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function LeadGotoActivationPanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LeadGotoActivationPanel:OnShow()
end

--界面关闭时调用（用于子类重写）
function LeadGotoActivationPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function LeadGotoActivationPanel:OnDestroy()

end

return LeadGotoActivationPanel