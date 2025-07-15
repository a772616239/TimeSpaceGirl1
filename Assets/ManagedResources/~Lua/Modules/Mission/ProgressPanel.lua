require("Base/BasePanel")
ProgressPanel = Inherit(BasePanel)
local this= ProgressPanel
--初始化组件（用于子类重写）
function ProgressPanel:InitComponent()

    this.nameText=Util.GetGameObject (self.transform, "title/nameText")
    this.nameInfoText=Util.GetGameObject (self.transform, "title/nameInfoText")
    this.expText=Util.GetGameObject (self.transform, "middle/exp/expText")
    this.expSlider=Util.GetGameObject (self.transform, "middle/exp")
    this.infoText=Util.GetGameObject (self.transform, "middle/infoText")
    this.heroGrid=Util.GetGameObject (self.transform,"heroRect/heroGrid")
    this.closeBtn=Util.GetGameObject (self.transform,"bg")
    this.mask=Util.GetGameObject (self.transform,"mask")
    this.mask:SetActive(false)
end

--绑定事件（用于子类重写）
function ProgressPanel:BindEvent()

    Util.AddClick(this.closeBtn, function ()
        self:ClosePanel()
        UIManager.OpenPanel(UIName.MapAwardPanel,2)
    end)
end

--添加事件监听（用于子类重写）
function ProgressPanel:AddListener()

end

--移除事件监听（用于子类重写）
function ProgressPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function ProgressPanel:OnOpen(...)

    Util.ClearChild(this.heroGrid.transform)
    local data={...}
    local showInfo = data[1]
    local second = data[3]

    this.nameText:GetComponent("Text").text= MapManager.GetCurAreaName()
    this.nameInfoText:SetActive(false)
    this.nameInfoText:GetComponent("Text").text= ""
    this.mask:SetActive(true)
    DoTween.To(DG.Tweening.Core.DOGetter_float( function () return 0 end),
            DG.Tweening.Core.DOSetter_float(function (t)
                this.expSlider:GetComponent("Slider").value=t
                this.expText:GetComponent("Text").text=math.floor(t*100).."%"
            end), 1, second):SetEase(Ease.Linear):OnComplete(function ()
        this.mask:SetActive(false)
        self:ClosePanel()
        if data[2] then
            data[2]()
        end
        --UIManager.OpenPanel(UIName.MapAwardPanel,data)
    end )
    this.infoText:GetComponent("Text").text=showInfo[1]
end

--界面关闭时调用（用于子类重写）
function ProgressPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function ProgressPanel:OnDestroy()

end

return ProgressPanel