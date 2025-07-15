require("Base/BasePanel")
MinskShopPanel = Inherit(BasePanel)
local this = MinskShopPanel

--初始化组件（用于子类重写）
function MinskShopPanel:InitComponent()

end

--绑定事件（用于子类重写）
function MinskShopPanel:BindEvent()

end

--添加事件监听（用于子类重写）
function MinskShopPanel:AddListener()
end

--移除事件监听（用于子类重写）
function MinskShopPanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function MinskShopPanel:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MinskShopPanel:OnShow()

    
end
function MinskShopPanel:OnSortingOrderChange()
end


--界面关闭时调用（用于子类重写）
function MinskShopPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function MinskShopPanel:OnDestroy()

end

return MinskShopPanel