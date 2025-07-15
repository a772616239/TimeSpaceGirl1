--[[
 * @ClassName QuickSpecialPurchasePart
 * @Description 双项购买
 * @Date 2019/5/17 20:30
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]

local QuickSpecialPurchasePart = quick_class("QuickSpecialPurchasePart")

local kPurchaseCount = 2

--蛋疼的购买Id写死
local purChaseTypeIdDef = {
    [UpViewRechargeType.SpiritTicket] = { 10001, 10002 },
    [UpViewRechargeType.GhostRing] = { 10003, 10004 },
}
local MAX_BUY_COUNT = {
    [UpViewRechargeType.SpiritTicket] = { 999, 99 },
    [UpViewRechargeType.GhostRing] = { 999, 99 },
} 

function QuickSpecialPurchasePart:ctor(mainPanel, transform)
    self.mainPanel = mainPanel
    self.transform = transform
    self.purChasePart = {}
    self.remainBuyTimes = {}
    for i = 1, kPurchaseCount do
        self.purChasePart[i] = {}
        self.purChasePart[i].transform = self.transform:Find("part_" .. i)
        self:InitPurChasePart(self.purChasePart[i].transform, i)
    end
    self.remainBuyTimesText = self.transform:Find("remainBuyTimes"):GetComponent("Text")
    self.vipTips = self.transform:Find("vipTips").gameObject
end

function QuickSpecialPurchasePart:InitPurChasePart(transform, index)
    self.purChasePart[index].itemFrame = transform:Find("item/frame"):GetComponent("Image")
    self.purChasePart[index].itemIcon = transform:Find("item/icon"):GetComponent("Image")
    self.purChasePart[index].itemNumberText = transform:Find("item/number"):GetComponent("Text")
    self.purChasePart[index].itemName = transform:Find("item/name"):GetComponent("Text")
    transform:Find("minusBtn"):GetComponent("Button").onClick:AddListener(function()
        self:OnMinusBtnClicked(index)
    end)
    self.purChasePart[index].progressBar = transform:Find("progressBar"):GetComponent("Slider")
    self.purChasePart[index].progressBar.onValueChanged:AddListener(function(value)
        self:OnSliderValueChanged(index, value)
    end)
    transform:Find("addBtn"):GetComponent("Button").onClick:AddListener(function()
        self:OnAddBtnClicked(index)
    end)
    self.purChasePart[index].buyCountText = transform:Find("buyCount"):GetComponent("Text")

    self.purChasePart[index].confirmBtn = transform:Find("confirmBtn"):GetComponent("Button")
    self.purChasePart[index].confirmBtn.onClick:AddListener(function()
        self:OnConfirmBtnClicked(index)
    end)
    local confirmBtn = self.purChasePart[index].confirmBtn
    self.purChasePart[index].currencyIcon = confirmBtn.transform:Find("currencyIcon"):GetComponent("Image")
    self.purChasePart[index].costValueText = confirmBtn.transform:Find("costValue"):GetComponent("Text")
end

function QuickSpecialPurchasePart:OnShow(context)
    self.transform.gameObject:SetActive(true)
    self.context = context
    self:Init()
    self:SetBasicInfo(context)
    self:SetVipTip()
end

function QuickSpecialPurchasePart:SetVipTip()
    local shopItemConfig = ShopManager.GetShopItemInfo(purChaseTypeIdDef[self.context.type][1])
    self.vipTips:SetActive(shopItemConfig.RelatedtoVIP == 1)
end

function QuickSpecialPurchasePart:OnHide()
    self.transform.gameObject:SetActive(false)
end

function QuickSpecialPurchasePart:GetRemainBuyTimesByType(type)
    local limitBuyTimes = ShopManager.GetShopItemLimitBuyCount(purChaseTypeIdDef[type][1])
    if limitBuyTimes == -1 then
        limitBuyTimes = math.huge
    else
        for i = 1, kPurchaseCount do
            if not self.goods then
                self.goods = {}
            end
            if not self.goods[i] then
                self.goods[i] = ShopManager.GetShopItemGoodsInfo(purChaseTypeIdDef[type][i])
            end
            local hadBuyTimes = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[type][i])
            limitBuyTimes = limitBuyTimes - hadBuyTimes * self.goods[i][1][2]
        end
    end
    return limitBuyTimes
end


function QuickSpecialPurchasePart:Init()
    local MaxBuyCount = MAX_BUY_COUNT[self.context.type]
    for i = 1, kPurchaseCount do
        local remainBuyTimes = self:GetRemainBuyTimesByType(self.context.type)
        if i == 2 then
            remainBuyTimes = math.floor(remainBuyTimes/10)
        end
        self.purChasePart[i].remainBuyTimes = remainBuyTimes
        local canBuyMaxValue = ShopManager.GetShopItemMaxBuy(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[self.context.type][i])
        self.purChasePart[i].maxValue = math.min(self.purChasePart[i].remainBuyTimes, canBuyMaxValue)
        self.purChasePart[i].maxValue = self.purChasePart[i].maxValue > MaxBuyCount[i] and MaxBuyCount[i] or self.purChasePart[i].maxValue
        self.purChasePart[i].progressBar.minValue = 0
        self.purChasePart[i].progressBar.maxValue = self.purChasePart[i].maxValue
        self.purChasePart[i].progressBar.enabled = self.purChasePart[i].maxValue >= 1
        self.purChasePart[i].progressBar.value = self.purChasePart[i].maxValue > 0 and 1 or 0
        --self.purChasePart[i].confirmBtn.enabled = self.purChasePart[i].maxValue > 0
        self:OnBuyValueChanged(i)
    end
end

function QuickSpecialPurchasePart:SetBasicInfo(context)
    local purChaseTable = purChaseTypeIdDef[context.type]
    local itemConfigData = ConfigManager.GetConfigData(ConfigName.ItemConfig, context.type)
    for idx = 1, table.nums(purChaseTable) do
        self.purChasePart[idx].itemFrame.sprite = Util.LoadSprite(QualityBgDef[itemConfigData.Quantity])
        self.purChasePart[idx].itemIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
        self.purChasePart[idx].itemName.text = GetStringByEquipQua(itemConfigData.Quantity, itemConfigData.Name)
        local storeConfig = self.mainPanel:GetConfigData(purChaseTypeIdDef[self.context.type][idx])
        if not self.goods then
            self.goods = {}
        end
        self.goods[idx] = ShopManager.GetShopItemGoodsInfo(purChaseTypeIdDef[self.context.type][idx])
        self.purChasePart[idx].sellCount = self.goods[idx][1][2]
        self.purChasePart[idx].itemNumberText.text = self.goods[idx][1][2]
        self:SetVariationInfo(idx, storeConfig)
    end
end

function QuickSpecialPurchasePart:SetVariationInfo(index, configData)
    local itemConfigData = ConfigManager.GetConfigData(ConfigName.ItemConfig, configData.Cost[1][1])
    self.purChasePart[index].currencyIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    local costId, currentPrice = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[self.context.type][index], 1)
    self:SetCostTextColor(costId, currentPrice, index)
end

function QuickSpecialPurchasePart:OnSliderValueChanged(index, value)
    self.purChasePart[index].buyCountValue = value
    self:OnBuyValueChanged(index)
end

function QuickSpecialPurchasePart:OnMinusBtnClicked(index)
    if self.purChasePart[index].buyCountValue <= 1 then
        return
    end
    self.purChasePart[index].buyCountValue = self.purChasePart[index].buyCountValue - 1
    self:OnBuyValueChanged(index)
end

function QuickSpecialPurchasePart:OnAddBtnClicked(index)
    local MaxBuyCount = MAX_BUY_COUNT[self.context.type]
    if self.purChasePart[index].buyCountValue >= MaxBuyCount[index] then
        PopupTipPanel.ShowTipByLanguageId(11697)
        return
    end
    --if not self.wholeRemainTimes then
        if self.purChasePart[index].buyCountValue < self.purChasePart[index].maxValue then
            self.purChasePart[index].buyCountValue = self.purChasePart[index].buyCountValue + 1
            self:OnBuyValueChanged(index)
        else
            if not self.purChasePart[index].remainBuyTimes
                or self.purChasePart[index].remainBuyTimes == 0 then
                PopupTipPanel.ShowTipByLanguageId(10540)
            elseif self.purChasePart[index].buyCountValue == self.purChasePart[index].remainBuyTimes then
                PopupTipPanel.ShowTipByLanguageId(11703)
            else
                PopupTipPanel.ShowTipByLanguageId(11704)
            end
            --if self.purChasePart[index].remainBuyTimes == self.purChasePart[index].buyCountValue then
            --    PopupTipPanel.ShowTip("剩余购买次数不足")
            --end
        end
    --else
    --    if self.purChasePart[index].sellCount*self.purChasePart[index].buyCountValue < self.wholeRemainTimes then
    --        self.purChasePart[index].buyCountValue = self.purChasePart[index].buyCountValue + 1
    --        self:OnBuyValueChanged(index)
    --    else
    --        if self.wholeRemainTimes == 0 then
    --            PopupTipPanel.ShowTip("剩余购买个数不足")
    --            return
    --        end
    --        if self.wholeRemainTimes <= self.purChasePart[index].sellCount*self.purChasePart[index].buyCountValue then
    --            PopupTipPanel.ShowTip("剩余购买个数不足")
    --        end
    --    end
    --end
end

function QuickSpecialPurchasePart:OnConfirmBtnClicked(index)
    -- 判断所需物品是否足够
    local goodsId = purChaseTypeIdDef[self.context.type][index]
    local canBuyMaxValue = ShopManager.GetShopItemMaxBuy(SHOP_TYPE.FUNCTION_SHOP, goodsId)
    if canBuyMaxValue <= 0 or canBuyMaxValue < self.purChasePart[index].buyCountValue then
        local itemInfo = ShopManager.GetShopItemInfo(goodsId)
        local costId = itemInfo.Cost[1][1]
        NotEnoughPopup:Show(costId, function()
            self.mainPanel:ClosePanel()
        end)
        return
    end
    if self.purChasePart[index].remainBuyTimes == 0 then
        PopupTipPanel.ShowTipByLanguageId(11705)
        return
    end
    if self.wholeRemainTimes then
        if self.purChasePart[index].sellCount*self.purChasePart[index].buyCountValue > self.wholeRemainTimes then
            PopupTipPanel.ShowTipByLanguageId(11706)
            return
        end
    end
    ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[self.context.type][index], self.purChasePart[index].buyCountValue, function()
        CheckRedPointStatus(RedPointType.LuckyCat_GetReward)
        Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnLuckyCatRedRefresh)
        self.mainPanel:ClosePanel()
    end)
end

function QuickSpecialPurchasePart:OnBuyValueChanged(index)
    local limitCount = self.purChasePart[index].remainBuyTimes
    local value = self.purChasePart[index].buyCountValue
    if not limitCount or limitCount == math.huge then
        self.purChasePart[index].buyCountText.text = value
    else
        if limitCount == 0 then
            local colorValue = self.mainPanel:GetCostTextColor(false)
            self.purChasePart[index].buyCountText.text = string.format("<color=#D36161FF>%s/%s</color>", value, limitCount)
        else
            self.purChasePart[index].buyCountText.text = value.."/"..limitCount
        end
    end
    self.purChasePart[index].progressBar.value = value

    if not self.goods then
        self.goods = {}
    end
    if not self.goods[index] then
        self.goods[index] = ShopManager.GetShopItemGoodsInfo(purChaseTypeIdDef[self.context.type][index])
    end
    local count = value <= 0 and 1 or value
    self.purChasePart[index].itemNumberText.text = self.goods[index][1][2] * count

    local costId, currentPrice = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[self.context.type][index], count)
    self:SetCostTextColor(costId, currentPrice, index)
end

function QuickSpecialPurchasePart:SetCostTextColor(costId, currentPrice, index)
    local ownValue = BagManager.GetItemCountById(costId)
    local colorValue = self.mainPanel:GetCostTextColor(ownValue >= currentPrice)
    self.purChasePart[index].costValueText.text = string.format("<color=%s>%s</color>", colorValue, currentPrice)
end

return QuickSpecialPurchasePart