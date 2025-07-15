require("Base/BasePanel")
CurlingTipPanel = Inherit(BasePanel)
local this = CurlingTipPanel

--初始化组件（用于子类重写）
function CurlingTipPanel:InitComponent()

    this.missionText = Util.GetGameObject(self.gameObject, "MissionDone/image/ziti/context"):GetComponent("Text")
    this.missionRecieve = Util.GetGameObject(self.gameObject, "MissionDone")
end

--绑定事件（用于子类重写）
function CurlingTipPanel:BindEvent()

end

--添加事件监听（用于子类重写）
function CurlingTipPanel:AddListener()

end

--移除事件监听（用于子类重写）
function CurlingTipPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function CurlingTipPanel:OnOpen(...)

    local args = {...}
    local str = args[1]
    this.ShowTip(str)
end

--界面关闭时调用（用于子类重写）
function CurlingTipPanel:OnClose()

end

--界面销毁时调用（用于子类重写）
function CurlingTipPanel:OnDestroy()

end

function this.ShowTip(str)
    this.missionText.text = str
    this.missionRecieve:SetActive(true)
    Timer.New(function()
        this.missionRecieve:SetActive(false)
        this:ClosePanel()
    end, 3):Start()
end

return CurlingTipPanel