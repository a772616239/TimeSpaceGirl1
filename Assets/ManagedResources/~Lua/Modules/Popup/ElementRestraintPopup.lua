require("Base/BasePanel")
ElementRestraintPopup = Inherit(BasePanel)
local this=ElementRestraintPopup
local data=ConfigManager.GetConfigData(ConfigName.GameSetting,1)
--初始化组件（用于子类重写）
function ElementRestraintPopup:InitComponent()
    this.backBtn=Util.GetGameObject(self.gameObject, "content/backBtn")
    this.content=Util.GetGameObject(self.gameObject,"content/content"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function ElementRestraintPopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ElementRestraintPopup:AddListener()

end

--移除事件监听（用于子类重写）
function ElementRestraintPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function ElementRestraintPopup:OnOpen(...)

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ElementRestraintPopup:OnShow()
    this.content.text=GetLanguageStrById(11554)..data.ElementHurt.."%"
end

--界面关闭时调用（用于子类重写）
function ElementRestraintPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function ElementRestraintPopup:OnDestroy()

end

return ElementRestraintPopup