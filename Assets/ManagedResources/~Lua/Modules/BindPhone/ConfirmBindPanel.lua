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

-- 与 FirstRechargePanel 同款：tolua 里被 Destroy 的 UnityEngine.Object 在 Lua 侧仍是非 nil
-- userdata，`if self.getCodeBtnText then`拦不住，必须 tolua.isnull 判活；
-- 否则会抛 toluaL_exception 的兜底文案 "attempt to index text on a nil value"。
local function Alive(obj)
    return obj ~= nil and not IsNull(obj)
end

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
    if Alive(self.getCodeBtnText) then
        self.getCodeBtnText.text = GetLanguageStrById(10288)
    end
    if Alive(self.getCodeBtn) then
        self.getCodeBtn.enabled = true
    end
    self.bindType = BindType.GetCode
end

-- 停倒计时：OnClose / OnDestroy 共用
function ConfirmBindPanel:StopCountdown()
    if self.thread then
        coroutine.stop(self.thread)
        self.thread = nil
    end
end

function ConfirmBindPanel:OnClose()
    self:StopCountdown()
end

-- UIManager.DestroyPanel 只走 DestroyUI→OnDestroy、不调 OnClose（面板还会被 openedList 缓存复用），
-- 不在这里兜底，倒计时协程会拿着已销毁的 getCodeBtnText 继续写 text。
function ConfirmBindPanel:OnDestroy()
    self:StopCountdown()
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
    -- 重复点「获取验证码」会重启倒计时：先停旧的，只保留一个在跑
    self:StopCountdown()
    local countTime = kMaxWaitTime
    self.thread = coroutine.start(function()
        -- 用 running() 记自己，别用一个可能被下一次 SetTimes 覆盖的 self.thread 去停：
        -- 重复点「获取验证码」时旧协程会把新协程停掉。
        local selfCo = coroutine.running()
        local function Finish()
            if self.thread == selfCo then
                self.thread = nil
            end
            coroutine.stop(selfCo)
        end

        while true do
            -- 面板已销毁（DestroyPanel 不走 OnClose）或节点已回收：协程自行退出
            if not Alive(self.getCodeBtnText) or not Alive(self.getCodeBtn) then
                Finish()
                return
            end
            if countTime < 1 then
                self.getCodeBtnText.text = GetLanguageStrById(10288)
                self.getCodeBtn.enabled = true
                Finish()
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