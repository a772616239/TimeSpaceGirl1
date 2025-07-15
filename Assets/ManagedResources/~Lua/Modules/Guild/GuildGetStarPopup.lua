require("Base/BasePanel")
local GuildGetStarPopup = Inherit(BasePanel)
local this = GuildGetStarPopup

--初始化组件（用于子类重写）
function GuildGetStarPopup:InitComponent()

    this.btnBack = Util.GetGameObject(self.transform, "btnBack")
    this.ScrollView = Util.GetGameObject(self.transform, "ScrollView")
    this.starPanel = Util.GetGameObject(self.transform, "star")
    this.starNum = Util.GetGameObject(this.starPanel, "num")

end

--绑定事件（用于子类重写）
function GuildGetStarPopup:BindEvent()
    Util.AddClick(this.btnBack, function()
        this:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function GuildGetStarPopup:AddListener()
end

--移除事件监听（用于子类重写）
function GuildGetStarPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function GuildGetStarPopup:OnOpen(starNum)
    this.starNum:GetComponent("Text").text = starNum
    this.starPanel:SetActive(true)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GuildGetStarPopup:OnShow()
    --this.ScrollView:SetActive(false)
end

--界面关闭时调用（用于子类重写）
function GuildGetStarPopup:OnClose()
    --this.ScrollView:SetActive(true)
    this.starPanel:SetActive(false)
end

--界面销毁时调用（用于子类重写）
function GuildGetStarPopup:OnDestroy()
end

return GuildGetStarPopup