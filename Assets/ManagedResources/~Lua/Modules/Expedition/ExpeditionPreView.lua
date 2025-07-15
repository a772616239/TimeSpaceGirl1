ExpeditionPreView = {}
function ExpeditionPreView:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b,{ __index = ExpeditionPreView })
    return b
end
--初始化组件（用于子类重写）
function ExpeditionPreView:InitComponent()

    self.info = Util.GetGameObject(self.gameObject, "info"):GetComponent("Text")
    self.btnSure = Util.GetGameObject(self.gameObject, "btnSure")
    self.btnSureText = Util.GetGameObject(self.gameObject, "btnSure/Text"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function ExpeditionPreView:BindEvent()

end

--添加事件监听（用于子类重写）
function ExpeditionPreView:AddListener()

end

--移除事件监听（用于子类重写）
function ExpeditionPreView:RemoveListener()

end

--界面打开时调用（用于子类重写）
function ExpeditionPreView:OnOpen()

end

--界面关闭时调用（用于子类重写）
function ExpeditionPreView:OnClose()

end

--界面销毁时调用（用于子类重写）
function ExpeditionPreView:OnDestroy()

end

return ExpeditionPreView