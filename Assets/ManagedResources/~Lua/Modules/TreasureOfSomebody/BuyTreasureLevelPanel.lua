--[[
 * @ClassName BuyTreasureLevelPanel
 * @Description 购买宝藏等级
 * @Date 2019/9/21 16:02
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class BuyTreasureLevelPanel
local BuyTreasureLevelPanel = quick_class("BuyTreasureLevelPanel", BasePanel)

local calculateParams, costPropId = {}

function BuyTreasureLevelPanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.transform, "frame/bg/closeBtn")

    self.rewardTips = Util.GetGameObject(self.transform, "frame/bg/rewardPart/rewardTips"):GetComponent("Text")
    self.rewardContent = Util.GetGameObject(self.transform, "frame/bg/rewardPart/rewardList/rewardContent")
    self.rewardList = {}

    self.currentLv = Util.GetGameObject(self.transform, "frame/bg/treasureLvPart/currentLvBg/value"):GetComponent("Text")
    self.nextLv = Util.GetGameObject(self.transform, "frame/bg/treasureLvPart/nextLvBg/value"):GetComponent("Text")

    self.costIcon = Util.GetGameObject(self.transform, "frame/bg/costTypeIcon"):GetComponent("Image")
    self.costValue = Util.GetGameObject(self.transform, "frame/bg/costValue"):GetComponent("Text")

    self.minusBtn = Util.GetGameObject(self.transform, "frame/bg/minusBtn")
    self.progressBar = Util.GetGameObject(self.transform, "frame/bg/progressBar"):GetComponent("Slider")
    self.addBtn = Util.GetGameObject(self.transform, "frame/bg/addBtn")

    self.buyLevelValue = Util.GetGameObject(self.transform, "frame/bg/buyLevel"):GetComponent("Text")

    self.dealBtn = Util.GetGameObject(self.transform, "frame/bg/dealBtn")

end

function BuyTreasureLevelPanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)
    Util.AddSlider(self.progressBar.gameObject, function()
        self:OnSliderValueChanged()
    end)
    Util.AddClick(self.minusBtn, function()
        self:OnMinusBtnClicked()
    end)
    Util.AddClick(self.addBtn, function()
        self:OnAddBtnClicked()
    end)
    Util.AddClick(self.dealBtn, function()
        self:OnDealBtnClicked()
    end)
end

function BuyTreasureLevelPanel:OnOpen(context)
    self.context = context
    self:SetBasicValues()
    self.progressBar.maxValue = self:GetLvMaxValue()
    self.progressBar.minValue = 1
end

function BuyTreasureLevelPanel:OnShow()
    if self.progressBar.value == 1 then
        self:OnValueChanged()
    else
        self.progressBar.value = 1
    end
end

function BuyTreasureLevelPanel:OnHide()
    table.walk(self.rewardList, function(rewardItem)
        if rewardItem.gameObject.activeSelf then
            rewardItem.gameObject:SetActive(false)
        end
    end)
end

function BuyTreasureLevelPanel:SetBasicValues()
    self.currentLv.text = TreasureOfSomebodyManagerV2.currentLv
    local specialConfig = ConfigManager.GetConfigData(ConfigName.SpecialConfig, 18)
    local costPropResult = string.split(specialConfig.Value, "|")
    costPropId = tonumber(costPropResult[1])
    self.costIcon.sprite = SetIcon(tonumber(costPropResult[1]))
    local values = string.split(costPropResult[2], "#")
    for i = 1, #values do
        table.insert(calculateParams, tonumber(values[i]))
    end
end

function BuyTreasureLevelPanel:OnMinusBtnClicked()
    if self.progressBar.value <= self.progressBar.minValue then
        return
    end
    self.progressBar.value = self.progressBar.value - 1
end

function BuyTreasureLevelPanel:OnAddBtnClicked()
    if TreasureOfSomebodyManagerV2.currentLv + self.progressBar.value >= TreasureOfSomebodyManagerV2.treasureMaxLv then
        PopupTipPanel.ShowTipByLanguageId(11960)
        return
    end
    if self.progressBar.value >= self.progressBar.maxValue then
        PopupTipPanel.ShowTipByLanguageId(11698)
        return
    end
    self.progressBar.value = self.progressBar.value + 1
end

function BuyTreasureLevelPanel:OnDealBtnClicked()
    local ownNumberValue = BagManager.GetTotalItemNum(costPropId)
    local costNumber = tonumber(self.costValue.text)
    if costNumber > ownNumberValue then
        PopupTipPanel.ShowTipByLanguageId(11698)
        return
    end
    CostConfirmPopup.Show(costPropId, costNumber, GetLanguageStrById(11990), nil, function()
        local levelMoveTo = TreasureOfSomebodyManagerV2.currentLv + self.progressBar.value
        NetManager.RequestBuyTreasureLevel(levelMoveTo, function()
            TreasureOfSomebodyManagerV2.SetCurrentLevel(levelMoveTo)
            CheckRedPointStatus(RedPointType.TreasureOfSl)
            PopupTipPanel.ShowTipByLanguageId(10545)
            if self.context.callBack then
                self.context.callBack()
            end
            self:ClosePanel()
        end)
    end, COST_CONFIRM_TYPE.BUYTREASURE_LEVEL)
end

function BuyTreasureLevelPanel:OnSliderValueChanged()
    self:OnValueChanged()
end

function BuyTreasureLevelPanel:OnValueChanged()
    self:SetRewardContent()
    local currentLv = TreasureOfSomebodyManagerV2.currentLv
    local maxLv = TreasureOfSomebodyManagerV2.treasureMaxLv
    if currentLv + self.progressBar.value == maxLv then
        self.buyLevelValue.text = GetLanguageStrById(11802)
    else
        self.buyLevelValue.text = self.progressBar.value .. GetLanguageStrById(10072)
    end
    self.rewardTips.text = string.format(GetLanguageStrById(11991),
            self.progressBar.value, table.nums(self:GetRewardList()))
    self.costValue.text = self:GetNeedCostValue()
    self.nextLv.text = currentLv + self.progressBar.value
end

function BuyTreasureLevelPanel:GetLvMaxValue()
    local currentLv = TreasureOfSomebodyManagerV2.currentLv
    local maxLv = TreasureOfSomebodyManagerV2.treasureMaxLv
    local ownNumberValue = BagManager.GetTotalItemNum(costPropId)
    for i = currentLv + 1, maxLv do
        if self:GetLevelCostMoney(i) > ownNumberValue then
            return (i - currentLv - 1) > 1 and (i - currentLv - 1) or 1
        end
    end
    return maxLv - currentLv
end

function BuyTreasureLevelPanel:GetLevelCostMoney(level)
    local CostNum = 0
    local currentLv = TreasureOfSomebodyManagerV2.currentLv
    for i = currentLv + 1, level do
        CostNum = CostNum + CalculateCostCount(i, calculateParams)
    end
    return CostNum
end

function BuyTreasureLevelPanel:GetNeedCostValue()
    local currentLv = TreasureOfSomebodyManagerV2.currentLv
    return self:GetLevelCostMoney(currentLv + self.progressBar.value)
end

function BuyTreasureLevelPanel:GetRewardList()
    local rewardList = {}
    local currentLv = TreasureOfSomebodyManagerV2.currentLv
    for i = currentLv + 1, currentLv + self.progressBar.value do
        local treasureConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.TreasureSunLongConfig,
                "ActivityId", TreasureOfSomebodyManagerV2.activityId, "Level", i)
        if treasureConfig.Reward then
            for _, rewardInfo in ipairs(treasureConfig.Reward) do
                table.insert(rewardList, rewardInfo)
            end
        end
        if TreasureOfSomebodyManagerV2.hadBuyTreasure then
            if treasureConfig.TreasureReward then
                for _, rewardInfo in ipairs(treasureConfig.TreasureReward) do
                    table.insert(rewardList, rewardInfo)
                end
            end
        end
    end
    return rewardList
end

function BuyTreasureLevelPanel:SetRewardContent()
    table.walk(self.rewardList, function(rewardItem)
        if rewardItem.gameObject.activeSelf then
            rewardItem.gameObject:SetActive(false)
        end
    end)
    local rewardInfoList = self:GetRewardList()
    if #rewardInfoList > #self.rewardList then
        for i = 1, #rewardInfoList - #self.rewardList do
            local item = SubUIManager.Open(SubUIConfig.ItemView, self.rewardContent.transform)
            item.gameObject:SetActive(false)
            table.insert(self.rewardList, item)
        end
        for i, rewardInfo in ipairs(rewardInfoList) do
            self.rewardList[i]:OnOpen(false, rewardInfo)
            self.rewardList[i].gameObject:SetActive(true)
        end
    else
        for i, rewardInfo in ipairs(rewardInfoList) do
            self.rewardList[i]:OnOpen(false, rewardInfo)
            self.rewardList[i].gameObject:SetActive(true)
        end
    end
end

return BuyTreasureLevelPanel