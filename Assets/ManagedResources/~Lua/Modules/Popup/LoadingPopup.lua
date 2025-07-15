require("Base/BasePanel")
LoadingPopup = Inherit(BasePanel)
local this = LoadingPopup

local TransTime = 1.5
--初始化组件（用于子类重写）
function LoadingPopup:InitComponent()
    self.BgMask = Util.GetGameObject(self.gameObject, "BgMask")
    self.Slider = Util.GetGameObject(self.gameObject, "Slider"):GetComponent("Slider")
end

--绑定事件（用于子类重写）
function LoadingPopup:BindEvent()
    Util.AddClick(self.BgMask, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function LoadingPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Battle.OnBattleUIEnd, this.BattleEnd)
end

--移除事件监听（用于子类重写）
function LoadingPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Battle.OnBattleUIEnd, this.BattleEnd)
end

--界面打开时调用（用于子类重写）
function LoadingPopup:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LoadingPopup:OnShow()
    this.isUpdate = true
    this.curTime = 0
    this.TotalTime = TransTime
end

function LoadingPopup.BattleEnd()
    this:ClosePanel()
    this.isUpdate = false
    this.TotalTime = TransTime
    this.curTime = 0
end

function LoadingPopup:Update()
    if this.isUpdate then
        this.curTime = this.curTime + Time.deltaTime
        if this.curTime >= this.TotalTime then
            this.curTime = 0
            this.isUpdate = false
            self:ClosePanel()
            UIManager.OpenPanel(UIName.BattlePanel)
        end

        this.Slider.value = this.curTime / this.TotalTime
    end
    
end

--界面关闭时调用（用于子类重写）
function LoadingPopup:OnClose()
    this.isUpdate = false
    this.TotalTime = TransTime
    this.curTime = 0
end

--界面销毁时调用（用于子类重写）
function LoadingPopup:OnDestroy()

end

return LoadingPopup