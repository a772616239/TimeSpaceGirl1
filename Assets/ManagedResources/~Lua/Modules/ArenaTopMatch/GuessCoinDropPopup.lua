require("Base/BasePanel")
local GuessCoinDropPopup = Inherit(BasePanel)
local this = GuessCoinDropPopup
--初始化组件（用于子类重写）
function GuessCoinDropPopup:InitComponent()
    this.btnBack = Util.GetGameObject(this.transform, "btnBack")

    this.tip = Util.GetGameObject(this.transform, "content/tip"):GetComponent("Text")
    this.item = Util.GetGameObject(this.transform, "content/item")
end

--绑定事件（用于子类重写）
function GuessCoinDropPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuessCoinDropPopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuessCoinDropPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuessCoinDropPopup:OnOpen(roundTimes, itemId, itemNum)
    local titleName = ArenaTopMatchManager.GetCurTopMatchName()
    local turnName = ArenaTopMatchManager.GetTurnNameByRoundTimes(roundTimes)
    this.tip.text = string.format(GetLanguageStrById(10142), titleName, turnName)
    if not this._ItemView then
        this._ItemView = SubUIManager.Open(SubUIConfig.ItemView,this.item.transform)
    end
    this._ItemView:OnOpen(false,{itemId, itemNum},1,true)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuessCoinDropPopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function GuessCoinDropPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function GuessCoinDropPopup:OnDestroy()
    if this._ItemView then
        SubUIManager.Close(this._ItemView)
    end
end

return GuessCoinDropPopup