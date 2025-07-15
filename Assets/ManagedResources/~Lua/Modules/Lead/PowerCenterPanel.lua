require("Base/BasePanel")
PowerCenterPanel = Inherit(BasePanel)
local this = PowerCenterPanel

--初始化组件（用于子类重写）
function PowerCenterPanel:InitComponent()
end

--绑定事件（用于子类重写）
function PowerCenterPanel:BindEvent()
end

--添加事件监听（用于子类重写）
function PowerCenterPanel:AddListener()
end

--移除事件监听（用于子类重写）
function PowerCenterPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function PowerCenterPanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function PowerCenterPanel:OnShow()
end

--界面关闭时调用（用于子类重写）
function PowerCenterPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function PowerCenterPanel:OnDestroy()
end

return PowerCenterPanel