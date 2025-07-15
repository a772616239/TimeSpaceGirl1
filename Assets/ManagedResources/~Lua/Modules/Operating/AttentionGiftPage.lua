--[[
 * @ClassName AttentionGiftPage
 * @Description 关注有礼
 * @Date 2019/8/8 14:12
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class AttentionGiftPage
local AttentionGiftPage = quick_class("AttentionGiftPage")

local kBindPhoneId = 2
local kTabCount = 3
local groupTabColor = {
    [1] = Color(156 / 255, 156 / 255, 156 / 255, 1),
    [2] = Color(252 / 255, 250 / 255, 237 / 255, 1)
}

function AttentionGiftPage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject

    self.rewardContent = Util.GetGameObject(self.gameObject, "bindPhonePart/rewardList")
    self.rewardList = {}

    self.dealBtn = Util.GetGameObject(self.gameObject, "bindPhonePart/dealBtn"):GetComponent("Button")
    self.dealBtn.onClick:AddListener(function()
        self:OnDealBtnClicked()
    end)
    self.dealBtnText = Util.GetGameObject(self.dealBtn.transform, "Text"):GetComponent("Text")

    self.tabContent = Util.GetGameObject(self.gameObject, "bottomTabs/content")
    self.tabs = {}
    for i = 1, kTabCount do
        self.tabs[i] = {
            tabItem = Util.GetGameObject(self.tabContent, "tab_" .. i),
            name = Util.GetGameObject(self.tabContent, "tab_" .. i .. "/name"):GetComponent("Text"),
            selected = Util.GetGameObject(self.tabContent, "tab_" .. i .. "/selected"),
            redPoint = Util.GetGameObject(self.tabContent, "tab_" .. i .. "/redPoint"),
        }
        self.tabs[i].tabItem:GetComponent("Button").onClick:AddListener(function()
            self:OnTabBtnClicked(i)
        end)
    end
end

function AttentionGiftPage:OnShow(extraParams)
    self.gameObject:SetActive(true)
    self:OnTabChanged(1)
    self:SetReward()
    self:SetBindStatus()
end

function AttentionGiftPage:OnHide()
    self.gameObject:SetActive(false)

end

function AttentionGiftPage:SetBindStatus()
    local bindInfo = BindPhoneNumberManager.GetBindInfo()
    if bindInfo.state == BindPhoneState.NoneBind then
        self.dealBtn.enabled = true
        Util.SetGray(self.dealBtn.gameObject, false)
        self.dealBtnText.text = GetLanguageStrById(11442)
    elseif bindInfo.state == BindPhoneState.BindedButNotAward then
        self.dealBtn.enabled = true
        Util.SetGray(self.dealBtn.gameObject, false)
        self.dealBtnText.text = GetLanguageStrById(11443)
    else
        self.dealBtn.enabled = false
        Util.SetGray(self.dealBtn.gameObject, true)
        self.dealBtnText.text = GetLanguageStrById(10350)
    end
end

function AttentionGiftPage:SetReward()
    if table.nums(self.rewardList) > 0 then
        return
    end
    local specialConfig = ConfigManager.GetConfigData(ConfigName.SpecialConfig, kBindPhoneId)
    local rewardGroupId = tonumber(specialConfig.Value)
    local rewardGroupConfig = ConfigManager.GetConfigData(ConfigName.RewardGroup, rewardGroupId)
    for _, rewardInfo in ipairs(rewardGroupConfig.ShowItem) do
        local rewardItem = SubUIManager.Open(SubUIConfig.ItemView, self.rewardContent.transform)
        rewardItem:OnOpen(false, rewardInfo)
        table.insert(self.rewardList, rewardItem)
    end
end

function AttentionGiftPage:OnDealBtnClicked()
    local bindInfo = BindPhoneNumberManager.GetBindInfo()
    if bindInfo.state == BindPhoneState.NoneBind then
        UIManager.OpenPanel(UIName.ConfirmBindPanel, {
            callback = function(state)
                BindPhoneNumberManager.SetBindState(state)
                self:SetBindStatus()
            end
        })
    elseif bindInfo.state == BindPhoneState.BindedButNotAward then
        NetManager.RequestGetPhoneBindReward(function(respond)
            UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1)
            BindPhoneNumberManager.SetBindState(BindPhoneState.BindedAndAwarded)
            self:SetBindStatus()
        end)
    end
end

function AttentionGiftPage:OnTabBtnClicked(index)
    if index ~= 1 then
        PopupTipPanel.ShowTipByLanguageId(11444)
        return
    end
    self:OnTabChanged(index)
end

function AttentionGiftPage:OnTabChanged(index)
    for i, tabInfo in ipairs(self.tabs) do
        tabInfo.selected:SetActive(i == index)
        tabInfo.name.color = i == index and groupTabColor[2] or groupTabColor[1]
    end

end

return AttentionGiftPage