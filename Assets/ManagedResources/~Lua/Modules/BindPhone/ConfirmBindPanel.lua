--[[
 * @ClassName ConfirmBindPanel
 * @Description 确定关联手机
 * @Date 2019/8/30 16:17
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class ConfirmBindPanel
local ConfirmBindPanel = quick_class("ConfirmBindPanel", BasePanel)

local kMaxWaitTime = 10

function ConfirmBindPanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.transform, "frame/bg/closeBtn")

    self.phoneNumberInput = Util.GetGameObject(self.transform, "frame/bg/phoneNumberInput"):GetComponent("InputField")
    self.verifyCodeInput = Util.GetGameObject(self.transform, "frame/bg/verifyCodeInput"):GetComponent("InputField")

    self.getCodeBtn = Util.GetGameObject(self.transform, "frame/bg/getCodeBtn"):GetComponent("Button")
    self.getCodeBtnText = Util.GetGameObject(self.getCodeBtn.transform, "Text"):GetComponent("Text")

    self.confirmBtn = Util.GetGameObject(self.transform, "frame/bg/confirmBtn")

end

function ConfirmBindPanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.getCodeBtn.gameObject, function()
        self:OnGetCodeClicked()
    end)

    Util.AddClick(self.confirmBtn, function()
        self:OnConfirmBtnClicked()
    end)
end

function ConfirmBindPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.BindPhone.OnBindStatusChange, self.OnBindCallBack, self)
end

function ConfirmBindPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.BindPhone.OnBindStatusChange, self.OnBindCallBack, self)
end

function ConfirmBindPanel:OnOpen(context)
    self.context = context
end

function ConfirmBindPanel:OnShow()
    self.phoneNumberInput.text = ""
    self.verifyCodeInput.text = ""
    self.getCodeBtnText.text = GetLanguageStrById(10288)
    self.getCodeBtn.enabled = true
    self.bindType = BindType.GetCode
end

function ConfirmBindPanel:OnClose()
    if self.thread then
        coroutine.stop(self.thread)
        self.thread = nil
    end
end

function ConfirmBindPanel:OnGetCodeClicked()
    if self.phoneNumberInput.text == "" then
        PopupTipPanel.ShowTipByLanguageId(10289)
        return
    end
    self.bindType = BindType.GetCode
    BindPhoneNumberManager.DOGetBindPhone(BindType.GetCode, self.phoneNumberInput.text)
end

function ConfirmBindPanel:SetTimes()
    local countTime = kMaxWaitTime
    self.thread = coroutine.start(function()
        while true do
            if countTime < 1 then
                self.getCodeBtnText.text = GetLanguageStrById(10288)
                self.getCodeBtn.enabled = true
                coroutine.stop(self.thread)
                self.thread = nil
                return
            else
                self.getCodeBtnText.text = GetLanguageStrById(10286) .. countTime .. "s"
                self.getCodeBtn.enabled = false
                coroutine.wait(1)
                countTime = countTime - 1
            end
        end
    end)
end

function ConfirmBindPanel:OnConfirmBtnClicked()
    if self.phoneNumberInput.text == "" then
        PopupTipPanel.ShowTipByLanguageId(10289)
        return
    end
    if self.verifyCodeInput.text == "" then
        PopupTipPanel.ShowTipByLanguageId(10290)
        return
    end
    self.bindType = BindType.Confirm
    BindPhoneNumberManager.DOGetBindPhone(BindType.Confirm, self.phoneNumberInput.text, self.verifyCodeInput.text)
end

function ConfirmBindPanel:OnBindCallBack()
    if self.bindType == BindType.GetCode then
        self:SetTimes()
    else
        NetManager.RequestUpDataBindPhoneInfo(self.phoneNumberInput.text, function(respond)
            if self.context.callback then
                self.context.callback(respond.state)
                self:ClosePanel()
            end
        end)
    end

end

return ConfirmBindPanel