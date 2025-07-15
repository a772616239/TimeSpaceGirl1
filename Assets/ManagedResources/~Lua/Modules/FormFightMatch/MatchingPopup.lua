require("Base/BasePanel")
MatchingPopup = Inherit(BasePanel)
local this = MatchingPopup

--初始化组件（用于子类重写）
function MatchingPopup:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "Mask/btnBack")
    this.matchNum = Util.GetGameObject(self.gameObject, "Mask/root/joinNum"):GetComponent("Text")
    this.Text = Util.GetGameObject(self.gameObject, "Mask/root/Text")
    this.textMatchhing = Util.GetGameObject(self.gameObject, "Mask/root/circle/minCircle/Str")
    this.textMatched = Util.GetGameObject(self.gameObject, "Mask/root/circle/minCircle/success")


end

--绑定事件（用于子类重写）
function MatchingPopup:BindEvent()

    Util.AddClick(this.btnBack, function ()
        RoomManager.RoomCancelMatchRequest(1, function ()
            self:ClosePanel()
        end)
    end)
end

--添加事件监听（用于子类重写）
function MatchingPopup:AddListener()

end

--移除事件监听（用于子类重写）
function MatchingPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MatchingPopup:OnOpen()
    this.matchNum.gameObject:SetActive(false)
    this.Text:SetActive(false)

    -- 发送匹配请求
    if RoomManager.IsMatch == 0 then
        --请求匹配房间
        RoomManager.RoomMatchRequest(1, function ()
            this.textMatchhing:SetActive(true)
            this.textMatched:SetActive(false)
        end)
    end

end

--界面关闭时调用（用于子类重写）
function MatchingPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function MatchingPopup:OnDestroy()

end

return MatchingPopup