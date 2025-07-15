--[[
 * @ClassName CDKeyExchangePanel
 * @Description CDKey兑换
 * @Date 2019/9/17 10:53
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class CDKeyExchangePanel
local CDKeyExchangePanel = quick_class("CDKeyExchangePanel", BasePanel)

function CDKeyExchangePanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.transform, "frame/bg/closeBtn")

    self.cdKeyCode = Util.GetGameObject(self.transform, "frame/bg/CdKeyInput"):GetComponent("InputField")

    self.confirmBtn = Util.GetGameObject(self.transform, "frame/bg/confirmBtn")
end

function CDKeyExchangePanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(self.confirmBtn, function()
        self:OnConfirmBtnClicked()
    end)
end

function CDKeyExchangePanel:OnOpen()

end

function CDKeyExchangePanel:OnClose()
    self.cdKeyCode.text = ""
end

function CDKeyExchangePanel:OnConfirmBtnClicked()
    if self.cdKeyCode.text == "" then
        PopupTipPanel.ShowTipByLanguageId(11886)
    else
        local fun = function()
            NetManager.GetExchangeCdkRequest(self.cdKeyCode.text, function(respond)
                self.cdKeyCode.text = ""
                PopupTipPanel.ShowTipByLanguageId(11887)
            end)
        end
        if AppConst.isSDKLogin then
            if SDKMgr:IsCDKey() then
                local serverID = PlayerManager.serverInfo.server_id
                local roleID = tostring(PlayerManager.uid)
                SDKMgr:CDKey(self.cdKeyCode.text,serverID,roleID)
                self.cdKeyCode.text = ""
            else
                fun()
            end
        else
            fun()
        end
    end
end

return CDKeyExchangePanel