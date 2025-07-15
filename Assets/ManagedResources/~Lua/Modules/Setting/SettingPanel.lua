require("Base/BasePanel")
local SettingPanel = Inherit(BasePanel)
local this = SettingPanel
local funIndex = 1
-- local tabBtns = {}

local SettingInfo = require("Modules/Setting/SettingInfo")
-- local SettingPlayerTitle = require("Modules/Setting/SettingPlayerTitle")
-- local SettingPlayerRide = require("Modules/Setting/SettingPlayerRide")
-- local SettingPlayerSkin = require("Modules/Setting/SettingPlayerSkin")
--初始化组件（用于子类重写）
function SettingPanel:InitComponent()
    -- for i = 1, 4 do
    --     tabBtns[i] = Util.GetGameObject(this.transform, "btnList/btn"..i)
    -- end
    -- this.selectBtn = Util.GetGameObject(this.transform, "selectBtn")
    this.btnBackSetting = Util.GetGameObject(this.transform, "settingInfo/btnBack")
    this.BackMask = Util.GetGameObject(this.transform, "BackMask")

    this.settingInfo = SettingInfo.new(self, Util.GetGameObject(self.transform, "layout/settingInfo"))
    -- this.settingPlayerBg = Util.GetGameObject(self.transform, "layout/settingPlayerBgImage")
    -- this.settingPlayerTitle = SettingPlayerTitle.new(self, Util.GetGameObject(self.transform, "layout/settingPlayerTitle"))
    -- this.settingPlayerRide = SettingPlayerRide.new(self, Util.GetGameObject(self.transform, "layout/settingPlayerRide"))
    -- this.settingPlayerSkin = SettingPlayerSkin.new(self, Util.GetGameObject(self.transform, "layout/settingPlayerSkin"))

    this.settingInfoGo = Util.GetGameObject(this.gameObject, "layout/settingInfo")
    -- this.settingPlayerTitleGo = Util.GetGameObject(this.gameObject, "layout/settingPlayerTitle")
    -- this.settingPlayerRideGo = Util.GetGameObject(this.gameObject, "layout/settingPlayerRide")
    -- this.settingPlayerSkinGo = Util.GetGameObject(this.gameObject, "layout/settingPlayerSkin")
end

--绑定事件（用于子类重写）
function SettingPanel:BindEvent()
    Util.AddClick(this.btnBackSetting, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)
    -- for i = 1, 4 do
    --     if i == 1 then
    --         Util.AddClick(tabBtns[i], function()
    --             this.OnShowPanelData(i)
    --         end)
    --     else
    --         Util.AddClick(tabBtns[i], function()
    --             PopupTipPanel.ShowTipByLanguageId(11902)
    --         end)
    --     end
    -- end
    this.settingInfo.BindEvent()
    -- this.settingPlayerTitle.BindEvent()
    -- this.settingPlayerRide.BindEvent()
    -- this.settingPlayerSkin.BindEvent()
end

--添加事件监听（用于子类重写）
function SettingPanel:AddListener()
    this.settingInfo.AddListener()
    -- this.settingPlayerTitle.AddListener()
    -- this.settingPlayerRide.AddListener()
    -- this.settingPlayerSkin.AddListener()
end

--移除事件监听（用于子类重写）
function SettingPanel:RemoveListener()
    this.settingInfo.RemoveListener()
    -- this.settingPlayerTitle.RemoveListener()
    -- this.settingPlayerRide.RemoveListener()
    -- this.settingPlayerSkin.RemoveListener()
end

--界面打开时调用（用于子类重写）
function SettingPanel:OnOpen(index)
    funIndex = index or 1
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function SettingPanel:OnShow()
    this.OnShowPanelData(funIndex)
end
function this.OnShowPanelData(_funIndex)
    funIndex = _funIndex
    this.settingInfoGo:SetActive(false)
    -- this.settingPlayerTitleGo:SetActive(false)
    -- this.settingPlayerRideGo:SetActive(false)
    -- this.settingPlayerSkinGo:SetActive(false)
    -- this.settingPlayerBg:SetActive(true)
    -- this.SetSelectBtn(funIndex)
    -- if funIndex == 1 then--信息
    --     this.settingPlayerBg:SetActive(false)
        this.settingInfoGo:SetActive(true)
        this.settingInfo.OnShow()
    -- elseif funIndex == 2 then--称号
    --     this.settingPlayerTitleGo:SetActive(true)
    --     this.settingPlayerTitle.OnShow()
    -- elseif funIndex == 3 then--坐骑
    --     this.settingPlayerRideGo:SetActive(true)
    --     this.settingPlayerRide.OnShow()
    -- elseif funIndex == 4 then--皮肤
    --     this.settingPlayerSkinGo:SetActive(true)
    --     this.settingPlayerSkin.OnShow()
    -- end
end
-- function this.SetSelectBtn(index)
--     this.selectBtn.transform:SetParent(tabBtns[index].transform)
--     this.selectBtn.transform.localScale = Vector3.one
--     this.selectBtn.transform.localPosition = Vector3.zero
--     Util.GetGameObject(this.selectBtn.transform, "Text"):GetComponent("Text").text = Util.GetGameObject(tabBtns[index].transform, "Text"):GetComponent("Text").text
-- end
--界面关闭时调用（用于子类重写）
function SettingPanel:OnClose()
    this.settingInfo.OnClose()
    -- this.settingPlayerTitle.OnClose()
    -- this.settingPlayerRide.OnClose()
    -- this.settingPlayerSkin.OnClose()
end

--界面销毁时调用（用于子类重写）
function SettingPanel:OnDestroy()
    this.settingInfo.OnDestroy()
    -- this.settingPlayerTitle.OnDestroy()
    -- this.settingPlayerRide.OnDestroy()
    -- this.settingPlayerSkin.OnDestroy()
end

return SettingPanel