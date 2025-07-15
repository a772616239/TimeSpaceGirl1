--- ===========  这个面板只系统执行方法和提供入口 =======
--- =========== 具体的逻辑处理放在各个模块中执行 ========

require("Base/BasePanel")
MapFightPanel = Inherit(BasePanel)
local this = MapFightPanel
local ctrlView = require("Modules/MapFight/View/MapFightControllView")
local mapUiView = require("Modules/MapFight/View/UICtrlView")

--初始化组件（用于子类重写）
function MapFightPanel:InitComponent()

    ctrlView.InitComponent(self.gameObject)
    mapUiView.InitComponent(self.gameObject, MapFightPanel)
end

--绑定事件（用于子类重写）
function MapFightPanel:BindEvent()
    mapUiView.BindEvent()

end

--添加事件监听（用于子类重写）
function MapFightPanel:AddListener()

    ctrlView.AddListener()
    mapUiView.AddListener()

end

--移除事件监听（用于子类重写）
function MapFightPanel:RemoveListener()

    ctrlView.RemoveListener()
    mapUiView.RemoveListener()

end

-- 系统的Start 方法
--界面打开时调用（用于子类重写）
function MapFightPanel:OnOpen(...)

    ctrlView.Init()
    mapUiView.OnOpen()
end


--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MapFightPanel:OnShow()

    mapUiView.OnShow()
end

--界面关闭时调用（用于子类重写）
function MapFightPanel:OnClose()

end

function this.Dispose()
    ctrlView.Dispose()
    mapUiView.Dispose()
    poolManager:ClearPool()
end

--界面销毁时调用（用于子类重写）
function MapFightPanel:OnDestroy()

end

return MapFightPanel