require("Base/BasePanel")
FindTreasureVipPopup = Inherit(BasePanel)
local MazeTreasureSetting = ConfigManager.GetConfig(ConfigName.MazeTreasureSetting)
--初始化组件（用于子类重写）
function FindTreasureVipPopup:InitComponent()

    self.btnBack = Util.GetGameObject(self.gameObject, "Button")
    self.descText1 = Util.GetGameObject(self.gameObject, "GameObject1/descText"):GetComponent("Text")
    self.jumpBtn1 = Util.GetGameObject(self.gameObject, "GameObject1/jumpBtn")
    self.finfsh1 = Util.GetGameObject(self.gameObject, "GameObject1/finish")

    self.descText2 = Util.GetGameObject(self.gameObject, "GameObject2/descText"):GetComponent("Text")
    self.jumpBtn2 = Util.GetGameObject(self.gameObject, "GameObject2/jumpBtn")
    self.finfsh2 = Util.GetGameObject(self.gameObject, "GameObject2/finish")
end

--绑定事件（用于子类重写）
function FindTreasureVipPopup:BindEvent()

    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.jumpBtn1, function()
        JumpManager.GoJump(MazeTreasureSetting[1].Jump)
    end)
    Util.AddClick(self.jumpBtn2, function()
        JumpManager.GoJump(MazeTreasureSetting[1].Jump)
    end)
end

--添加事件监听（用于子类重写）
function FindTreasureVipPopup:AddListener()

end

--移除事件监听（用于子类重写）
function FindTreasureVipPopup:RemoveListener()

end

--界面打开时调用（用于子类重写）
function FindTreasureVipPopup:OnOpen(...)

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FindTreasureVipPopup:OnShow()

    self.descText1.text = GetLanguageStrById(50229)--string.gsub(MazeTreasureSetting[1].DescDailyPrivilege[1],"|","#")
    self.descText2.text = GetLanguageStrById(50230)--string.gsub(MazeTreasureSetting[1].DescDailyPrivilege[2],"|","#")
    local gaoState = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.GoFindTreasure)
    local haoState = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.HaoFindTreasure)
    self.jumpBtn1:SetActive(not gaoState)
    self.finfsh1:SetActive(gaoState)
    self.jumpBtn2:SetActive(not haoState)
    self.finfsh2:SetActive(haoState)
end

--界面关闭时调用（用于子类重写）
function FindTreasureVipPopup:OnClose()

end

--界面销毁时调用（用于子类重写）
function FindTreasureVipPopup:OnDestroy()

end

return FindTreasureVipPopup