--[[
 * @ClassName OperatingPanel
 * @Description 特权描述二级弹窗
 * @Date 2019/5/27 11:14
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class VipTipPopup
local VipTipPopup = quick_class("VipPanel", BasePanel)

function VipTipPopup:InitComponent()
    self.backBtn = self.transform:Find("bg/btnBack").gameObject

    self.vipLv = self.transform:Find("bg/title/Text"):GetComponent("Text")

    self.privilegeContent = self.transform:Find("bg/privilegeList/viewPort/content")
    self.privilegeItem = self.privilegeContent:Find("itemPro").gameObject
    self.privilegeItem:SetActive(false)
    self.privilegeList = {}

    self.leftBtn = self.transform:Find("bg/leftBtn").gameObject
    self.rightBtn = self.transform:Find("bg/rightBtn").gameObject

end

function VipTipPopup:BindEvent()
    Util.AddClick(self.backBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(self.leftBtn, function()
        self:OnLeftBtnClicked()
    end)
    Util.AddClick(self.rightBtn, function()
        self:OnRightBtnClicked()
    end)

end

function VipTipPopup:OnOpen(notShowArrow)
    self.notShowArrow = false

    self.previewLv = VipManager.GetVipLevel()
    self:SetPanelStatus()

    if notShowArrow then
        self.notShowArrow = notShowArrow
        self:SetInitShow()
    end


end

function VipTipPopup:SetInitShow()
    self.leftBtn:SetActive(not self.notShowArrow)
    self.rightBtn:SetActive(not self.notShowArrow)
end

function VipTipPopup:OnClose()

end

function VipTipPopup:SetPrivilegeList()
    self:HideAllPrivileges()
    self.vipLv.text = self.previewLv
    local vipConfig = ConfigManager.GetConfigData(ConfigName.VipLevelConfig, self.previewLv)
    local tempNumber = 0
    for _, privilegeInfo in ipairs(vipConfig.Privileges) do
        if privilegeInfo[2] > 0 then
            local PrivilegeConfig = ConfigManager.GetConfigData(ConfigName.PrivilegeTypeConfig, privilegeInfo[1])
            if PrivilegeConfig.isShowName ~= 0 then
                if PrivilegeConfig.Type == 0 then
                    tempNumber = tempNumber + 1
                    local item = self:GetPrivilegeItem(tempNumber)
                    item.gameObject:SetActive(true)
                    local privilegeType = PrivilegeConfig.IfFloat
                    local str = "<size=45><color=#7bb15bFF> </color></size>"
                    if PrivilegeConfig.IfFloat == 2 then
                        str = string.format("<size=45><color=#7bb15bFF>%s</color></size>", GetPropertyFormatStr(privilegeType, privilegeInfo[2]))
                    else
                        str = string.format("<size=45><color=#7bb15bFF>+%s</color></size>", GetPropertyFormatStr(privilegeType, privilegeInfo[2]))
                    end
                    Util.GetGameObject(item, "title"):GetComponent("Text").text = PrivilegeConfig.Name .. str
                else
                    local state = PrivilegeManager.IsPrivilegeOpenedCurrentLevel(privilegeInfo[1],self.previewLv)
                    if state then
                        tempNumber = tempNumber + 1
                        local item = self:GetPrivilegeItem(tempNumber)
                        item.gameObject:SetActive(true)
                        local str = "<size=45><color=#7bb15bFF> </color></size>"
                        Util.GetGameObject(item, "title"):GetComponent("Text").text = PrivilegeConfig.Name .. str
                    end
                end
            end
        end
    end
    self:SetExtraPrivilege(tempNumber + 1, vipConfig)
end

function VipTipPopup:SetExtraPrivilege(index, configData)
    local item = self:GetPrivilegeItem(index)
    item.gameObject:SetActive(true)
    local str = GetLanguageStrById(10106)
    for _, rewardInfo in ipairs(configData.VipBoxDailyReward) do
        local itemConfig = ConfigManager.GetConfigData(ConfigName.ItemConfig, rewardInfo[1])
        --assert(itemConfig, string.format("ConfigName.ItemConfig not find Id:%s", rewardInfo[1]))
        str = str .. string.format("%s<size=45><color=#7bb15bFF>%s</color></size>", GetLanguageStrById(itemConfig.Name), rewardInfo[2])
    end
    Util.GetGameObject(self.privilegeList[index], "title"):GetComponent("Text").text = str
end

function VipTipPopup:GetPrivilegeItem(index)
    if self.privilegeList[index] then
        return self.privilegeList[index]
    else
        local newItem = newObjToParent(self.privilegeItem, self.privilegeContent)
        table.insert(self.privilegeList, newItem)
        return newItem
    end
end

function VipTipPopup:HideAllPrivileges()
    table.walk(self.privilegeList, function(privilegeItem)
        privilegeItem.gameObject:SetActive(false)
    end)
end

function VipTipPopup:OnLeftBtnClicked()
    self.previewLv = self.previewLv - 1
    self:SetPanelStatus()
end

function VipTipPopup:OnRightBtnClicked()
    self.previewLv = self.previewLv + 1
    self:SetPanelStatus()
end

function VipTipPopup:SetTurnBtnStatus()
    self.leftBtn.gameObject:SetActive(self.previewLv > 0)
    self.rightBtn.gameObject:SetActive(self.previewLv < VipManager.GetMaxVipLevel())
end

function VipTipPopup:SetPanelStatus()
    self:SetTurnBtnStatus()
    self:SetPrivilegeList()
end

return VipTipPopup