require("Base/BasePanel")
SettingPopup = Inherit(BasePanel)
local this = SettingPopup
local passFight = false
--初始化组件（用于子类重写）
function SettingPopup:InitComponent()

    this.btnPassFight = Util.GetGameObject(self.gameObject, "bg/btnChoose")
    this.imgPassFight = Util.GetGameObject(self.gameObject, "bg/btnChoose/imgYep")
    this.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")
    this.btnSure = Util.GetGameObject(self.gameObject, "bg/btnSure")

end

--绑定事件（用于子类重写）
function SettingPopup:BindEvent()

    Util.AddClick(this.btnPassFight, function ()
        passFight = not passFight
        this.imgPassFight:SetActive(passFight)
    end)


    Util.AddClick(this.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        SettingPopup:ClosePanel()
    end)

    Util.AddClick(this.btnSure, function ()
        CarbonManager.isPassFight = passFight
        EndLessMapManager.isSkipFight = passFight and 1 or 0
        local type = passFight and 1 or 0
        NetManager.RequestSaveSkipFight(type, function ()
            SettingPopup:ClosePanel()
        end)

    end)

end

--添加事件监听（用于子类重写）
function SettingPopup:AddListener()

end

--移除事件监听（用于子类重写）
function SettingPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function SettingPopup:OnOpen(...)

    passFight = EndLessMapManager.isSkipFight == 1
    this.imgPassFight:SetActive(passFight)
end

--界面关闭时调用（用于子类重写）
function SettingPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function SettingPopup:OnDestroy()

end

return SettingPopup