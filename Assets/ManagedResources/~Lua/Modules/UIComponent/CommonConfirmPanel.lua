--[[
 * @Classname CommonConfirmPanel
 * @Description TODO
 * @Date 2019/7/25 14:18
 * @Created by MagicianJoker
--]]

---@class CommonConfirmPanel
local CommonConfirmPanel = quick_class("CommonConfirmPanel", BasePanel)

function CommonConfirmPanel:InitComponent()

    self.title = Util.GetGameObject(self.transform, "frame/bg/title"):GetComponent("Text")
    self.content = Util.GetGameObject(self.transform, "frame/bg/content"):GetComponent("Text")

    self.doublePart = Util.GetGameObject(self.transform, "frame/bg/doublepart")
    self.confirmBtn = Util.GetGameObject(self.doublePart, "confirmBtn")
    self.confirmText = Util.GetGameObject(self.confirmBtn, "Text"):GetComponent("Text")
    self.cancelBtn = Util.GetGameObject(self.doublePart, "cancelBtn")
    self.cancelText = Util.GetGameObject(self.cancelBtn, "Text"):GetComponent("Text")

    self.singlePart = Util.GetGameObject(self.transform, "frame/bg/singlepart")
    self.singleConfirmBtn = Util.GetGameObject(self.singlePart, "confirmBtn")
    self.singleConfirmText = Util.GetGameObject(self.singleConfirmBtn, "Text"):GetComponent("Text")
end

function CommonConfirmPanel:BindEvent()
    Util.AddClick(self.confirmBtn, function()
        self:OnConfirmBtnClicked()
    end)

    Util.AddClick(self.singleConfirmBtn, function()
        self:OnConfirmBtnClicked()
    end)

    Util.AddClick(self.cancelBtn, function()
        self:OnCancelBtnClicked()
    end)

end

function CommonConfirmPanel:OnOpen(context)
    self.context = context
    self.title.text = context.title or GetLanguageStrById(11351)
    self.content.text = context.content
    self.confirmText.text = context.confirmText or GetLanguageStrById(11999)
    self.cancelText.text = context.cancelText or GetLanguageStrById(10719)
    self.singleConfirmText.text = context.confirmText or GetLanguageStrById(11999)
    if context.type then
        self.singlePart:SetActive(context.type == 1)
        self.doublePart:SetActive(context.type == 2)
    else
        self.singlePart:SetActive(false)
        self.doublePart:SetActive(true)
    end
end

function CommonConfirmPanel:OnShow()

end

function CommonConfirmPanel:OnClose()

end

function CommonConfirmPanel:OnConfirmBtnClicked()
    self:ClosePanel()
    if self.context.extra then
        self.context.extra()
        return
    end
    if self.context.confirmCallback then
        self.context.confirmCallback()
    end
end

function CommonConfirmPanel:OnCancelBtnClicked()
    self:ClosePanel()
    if self.context.cancelCallback then
        self.context.cancelCallback()
    end
end

return CommonConfirmPanel