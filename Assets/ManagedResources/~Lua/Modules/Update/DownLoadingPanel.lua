require("Base/BasePanel")
DownLoadingPanel = Inherit(BasePanel)
local this = DownLoadingPanel
--初始化组件（用于子类重写）
function this:InitComponent()

    this.tipText = self:GetComponent("Text","Panel/LoadingSlider/Tip");
    this.daXiaoTxt = self:GetComponent("Text","Panel/LoadingSlider/DaXiao");
    this.slider = self:GetComponent("Slider","Panel/LoadingSlider/LoadingSlider");
end

--绑定事件（用于子类重写）
function this:BindEvent()

end

--添加事件监听（用于子类重写）
function this:AddListener()

end

--移除事件监听（用于子类重写）
function this:RemoveListener()

end

--界面打开时调用（用于子类重写）
function this:OnOpen(...)

end

function this:OnShow()

end

--界面关闭时调用（用于子类重写）
function this:OnClose()

end

--界面销毁时调用（用于子类重写）
function this:OnDestroy()

end

return DownLoadingPanel