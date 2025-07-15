 --[[
 * @ClassName QuickCommonPurchasePart
 * @Description 单项购买
 * @Date 2019/5/17 20:29
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
local QuickCommonPurchasePart = quick_class("QuickCommonPurchasePart")

--蛋疼的购买Id写死
local purChaseTypeIdDef = {
    [UpViewRechargeType.Energy] = 10006,
    [UpViewRechargeType.Gold] = 10005,
    [UpViewRechargeType.ChallengeTicket] = 10007,
    [UpViewRechargeType.EliteCarbonTicket] = 10010,
    [UpViewRechargeType.AdventureAlianInvasionTicket] = 10012,
    [UpViewRechargeType.DemonCrystal] = 10013,
    [UpViewRechargeType.LightRing] = 10014,
    [UpViewRechargeType.ActPower] = 10016,
    [UpViewRechargeType.MonsterCampTicket] = 10017,
    [UpViewRechargeType.ChangeNameCard] = 10018,
    [UpViewRechargeType.HourGlass] = 10008,
    [UpViewRechargeType.XingYao] = 10029,
    [UpViewRechargeType.ChatHorn] = 90111,
}

function QuickCommonPurchasePart:ctor(mainPanel, transform)
    self.mainPanel = mainPanel
    self.transform = transform
    --topPart
    self.iconBg = self.transform:Find("item/frame"):GetComponent("Image")
    self.icon = self.transform:Find("item/icon"):GetComponent("Image")
    self.numberValueText = self.transform:Find("item/number"):GetComponent("Text")
    self.itemName = self.transform:Find("item/name"):GetComponent("Text")
    self.itemDesc = self.transform:Find("item/box/desc"):GetComponent("Text")
    self.itemAdd = self.transform:Find("item/box/add"):GetComponent("Text")
--midPart
    self.countDownTime = self.transform:Find("countDownTime"):GetComponent("Text")

    self.transform:Find("minusBtn"):GetComponent("Button").onClick:AddListener(function()
        self:OnMinusBtnClicked()
    end)
    self.progressBar = self.transform:Find("progressBar"):GetComponent("Slider")
    self.progressBar.onValueChanged:AddListener(function(value)
        self:OnSliderValueChanged(value)
    end)
    self.transform:Find("addBtn"):GetComponent("Button").onClick:AddListener(function()
        self:OnAddBtnClicked()
    end)
    self.buyCountText = self.transform:Find("buyCount"):GetComponent("Text")
    self.remainBuyTimesText = self.transform:Find("remainBuyTimes"):GetComponent("Text")
    self.vipTipsText = self.transform:Find("vipTips"):GetComponent("Text")
    self.costTipsText = self.transform:Find("costTips").gameObject
    --bottomPart
    self.confirmBtn = self.transform:Find("confirmBtn"):GetComponent("Button")
    self.confirmBtnText = self.confirmBtn.transform:Find("costValue"):GetComponent("Text")
    self.confirmBtn.onClick:AddListener(function()
        self:OnConfirmBtnClicked()
    end)

    self.disPart = self.transform:Find("priceRoot/disPart")
    self.originalCostValueText = self.disPart:Find("orgPrice"):GetComponent("Text")
    self.disCostValueText = self.disPart:Find("discPrice"):GetComponent("Text")

    self.noneDisPart = self.transform:Find("priceRoot/noneDisPart")
    self.costValueText = self.noneDisPart:Find("price"):GetComponent("Text")

    self.currencyIcon = self.transform:Find("priceRoot/icon"):GetComponent("Image")
end

function QuickCommonPurchasePart:OnShow(context)
    self.remainBuyTimes = self.mainPanel:GetRemainBuyTimes(purChaseTypeIdDef[context.type])
    local canBuyMaxValue = ShopManager.GetShopItemMaxBuy(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[context.type])
    self.maxValue = math.min(self.remainBuyTimes, canBuyMaxValue)
    if self.maxValue <= 0 then
        UIManager.ClosePanel(UIName.QuickPurchasePanel)
        PopupTipPanel.ShowTipByLanguageId(10060)
    else
        self.transform.gameObject:SetActive(true)
        self.context = context
        self:SpecialDeal()
        self:Init()
        self:SetBasicInfo(context)
    end
end

function QuickCommonPurchasePart:OnHide()
    self.transform.gameObject:SetActive(false)
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end

function QuickCommonPurchasePart:SpecialDeal()
    self.countDownTime.text = ""
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    local itemId = self.context.type
    if AutoRecoverManager.IsAutoRecover(itemId) then
        local function update()
            local remainTime = AutoRecoverManager.GetRecoverTime(itemId)
            if remainTime < 0 then
                self.countDownTime.text = GetLanguageStrById(11691)
            else
                if itemId == UpViewRechargeType.Energy then
                    self.countDownTime.text = string.format(GetLanguageStrById(11692), DateUtils.GetTimeFormat(remainTime))
                else
                    self.countDownTime.text = string.format(GetLanguageStrById(11693), DateUtils.GetTimeFormat(remainTime))
                end
            end
        end
        update()
        self.timer = Timer.New(update, 1, -1, true)
        self.timer:Start()
    end
end

function QuickCommonPurchasePart:Init()
    self.remainBuyTimes = self.mainPanel:GetRemainBuyTimes(purChaseTypeIdDef[self.context.type])
    local canBuyMaxValue = ShopManager.GetShopItemMaxBuy(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[self.context.type])
    self.maxValue = math.min(self.remainBuyTimes, canBuyMaxValue)
    self.maxValue = self.maxValue > 999 and 999 or self.maxValue
    self.progressBar.enabled = self.maxValue > 1
    self.progressBar.maxValue = self.maxValue
    self.progressBar.minValue = 1
    self.buyCountValue = self.maxValue > 0 and 1 or 0
    -- 设置颜色
    self:OnBuyValueChanged()
    self.buyCountText.color = self.maxValue > 0 and Color.New(0.55,0.59,0.62,1) or UIColor.NOT_ENOUGH_RED
    Util.SetGray(self.confirmBtn.gameObject, self.maxValue <= 0)
    self.confirmBtn.enabled = self.maxValue > 0
end

function QuickCommonPurchasePart:SetBasicInfo(context)
    local itemConfigData = ConfigManager.GetConfigData(ConfigName.ItemConfig, context.type)
    self.iconBg.sprite = Util.LoadSprite(QualityBgDef[itemConfigData.Quantity])
    self.icon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    local storeConfig = self.mainPanel:GetConfigData(purChaseTypeIdDef[self.context.type])
    local goods, allAdd, vipAdd = ShopManager.GetShopItemGoodsInfo(purChaseTypeIdDef[self.context.type])
    self.goods = goods
    self.numberValueText.text = self.goods[1][2]
    self.itemName.text = GetStringByEquipQua(itemConfigData.Quantity, GetLanguageStrById(itemConfigData.Name))
    self.itemDesc.text = GetLanguageStrById(itemConfigData.ItemDescribe)
    if not vipAdd then vipAdd = 0 end
    self.itemAdd.gameObject:SetActive(vipAdd > 0)
    if vipAdd > 0 then
        self.itemAdd.text = string.format(GetLanguageStrById(11694), vipAdd * 100)
    end
    self:SetVariationInfo(storeConfig)
end

function QuickCommonPurchasePart:SetVariationInfo(configData)
    local itemConfigData = ConfigManager.GetConfigData(ConfigName.ItemConfig, configData.Cost[1][1])
    self.currencyIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    if self.remainBuyTimes == math.huge then
        self.remainBuyTimesText.text = ""
    else
        local Id = purChaseTypeIdDef[self.context.type]
        self.remainBuyTimesText.text = string.format(GetLanguageStrById(11695), self.remainBuyTimes, ShopManager.GetShopItemLimitBuyCount(Id))
        --string.format("今日购买剩余%s次", self.remainBuyTimes)
    end
    -- 判断是否和vip挂钩
    if configData.RelatedtoVIP == 1 then
        self.vipTipsText.text = GetLanguageStrById(11696)
    else
        self.vipTipsText.text = ""
    end
    --local costId, originalPrice, currentPrice = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[self.context.type], 1)
    --self:SetCostTextColor(costId, currentPrice)
    --self:SetPriceStatus(originalPrice, currentPrice)

    local abcd = configData.Cost[2]-- 公式常数
    self.costTipsText:SetActive(configData.PremiumType == 2 or abcd[1] > 0 or abcd[2] > 0 or abcd[3] > 0 )
end

function QuickCommonPurchasePart:OnSliderValueChanged(value)
    self.buyCountValue = value
    self:OnBuyValueChanged()
end

function QuickCommonPurchasePart:OnMinusBtnClicked()
    if self.buyCountValue < 1 then
        return
    end
    self.buyCountValue = self.buyCountValue - 1
    if self.buyCountValue < 1 then
        self.buyCountValue = 1
    end
    self:OnBuyValueChanged()
end

function QuickCommonPurchasePart:OnAddBtnClicked()
    if self.buyCountValue >= 999 then
        PopupTipPanel.ShowTipByLanguageId(11697)
        return
    end
    if self.buyCountValue < self.maxValue then
        self.buyCountValue = self.buyCountValue + 1
        self:OnBuyValueChanged()
    else
        if self.remainBuyTimes == 0 then
            PopupTipPanel.ShowTipByLanguageId(10540)
            return
        end
        if self.remainBuyTimes == self.buyCountValue then
            PopupTipPanel.ShowTipByLanguageId(10540)
        else
            PopupTipPanel.ShowTipByLanguageId(11698)
        end
    end
end

function QuickCommonPurchasePart:OnConfirmBtnClicked()
    if self.remainBuyTimes == 0 then
        PopupTipPanel.ShowTipByLanguageId(10540)
        return
    end
    -- 判断所需物品是否足够
    local canBuyMaxValue = ShopManager.GetShopItemMaxBuy(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[self.context.type])
    if canBuyMaxValue <= 0 or canBuyMaxValue < self.buyCountValue then
        local itemInfo = ShopManager.GetShopItemInfo(purChaseTypeIdDef[self.context.type])
        local costId = itemInfo.Cost[1][1]
        NotEnoughPopup:Show(costId, function()
            self.mainPanel:ClosePanel()
        end)
        return
    end
    if self.buyCountValue == 0 then
        PopupTipPanel.ShowTipByLanguageId(11699)
        return
    end
    ShopManager.RequestBuyShopItem(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[self.context.type], self.buyCountValue, function()
        self.mainPanel:ClosePanel()
    end)
end

function QuickCommonPurchasePart:OnBuyValueChanged()
    self.buyCountText.text = self.buyCountValue
    self.progressBar.value = self.buyCountValue

    if not self.goods then
        self.goods = ShopManager.GetShopItemGoodsInfo(purChaseTypeIdDef[self.context.type])
    end
    local count = self.buyCountValue <= 0 and 1 or self.buyCountValue
    self.numberValueText.text = self.goods[1][2] * count

    local costId, originalPrice, currentPrice = ShopManager.calculateBuyCost(SHOP_TYPE.FUNCTION_SHOP, purChaseTypeIdDef[self.context.type], count)
    --self:SetCostTextColor(costId, currentPrice)
    self:SetPriceStatus(originalPrice, currentPrice)

    if self.buyCountValue > 0 and currentPrice == 0 then
        self.confirmBtnText.text = GetLanguageStrById(11700)
    else
        self.confirmBtnText.text = GetLanguageStrById(10729)
    end
end

function QuickCommonPurchasePart:SetPriceStatus(originalPrice, currentPrice)
    self.noneDisPart.gameObject:SetActive(originalPrice == currentPrice)
    self.disPart.gameObject:SetActive(originalPrice ~= currentPrice)
    if originalPrice == currentPrice then
        self.costValueText.text = originalPrice
    else
        self.originalCostValueText.text = originalPrice
        self.disCostValueText.text = currentPrice
    end
end

--function QuickCommonPurchasePart:SetCostTextColor(costId, currentPrice)
--    local ownValue = BagManager.GetItemCountById(costId)
--    local colorValue = self.mainPanel:GetCostTextColor(ownValue >= currentPrice)
--    self.disCostValueText.text = string.format("<color=%s>%s</color>", colorValue, currentPrice)
--end

return QuickCommonPurchasePart