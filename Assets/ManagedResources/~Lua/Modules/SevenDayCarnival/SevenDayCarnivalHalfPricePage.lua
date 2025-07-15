--[[
 * @ClassName SevenDayCarnivalHalfPricePage
 * @Description 半价抢购
 * @Date 2019/7/31 10:01
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class SevenDayCarnivalHalfPricePage
local SevenDayCarnivalHalfPricePage = quick_class("SevenDayCarnivalHalfPricePage")
local btnBackGround = {
    [1] = "s_slbz_1anniuongse",
    [2] = "s_slbz_1anniuhuise"
}

---@param gameObject UnityEngine.GameObject
function SevenDayCarnivalHalfPricePage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    --self.itemBg = Util.GetGameObject(self.gameObject, "goodsItem/frame"):GetComponent("Image")
    --self.itemIcon = Util.GetGameObject(self.gameObject, "goodsItem/icon"):GetComponent("Image")
    --self.itemNumber = Util.GetGameObject(self.gameObject, "goodsItem/number"):GetComponent("Text")
    self.EffectOrginLayerQu=0
    self.halfPriceRoot = Util.GetGameObject(self.gameObject, "halfPriceBuy")
    self.itemName = Util.GetGameObject(self.halfPriceRoot, "goodsItem/name"):GetComponent("Text")
    self.giftPos = Util.GetGameObject(self.halfPriceRoot, "goodsItem/itemPos")
    self.giftInfo = SubUIManager.Open(SubUIConfig.ItemView, self.giftPos.transform)
    self.itemEffect=Util.GetGameObject(self.halfPriceRoot,"goodsItem/itemPos/UI_Effect_Kuang_JinSe")

    self.originalPrice = Util.GetGameObject(self.halfPriceRoot, "priceRoot/originalPrice/value"):GetComponent("Text")
    self.originalIcon = Util.GetGameObject(self.halfPriceRoot, "priceRoot/originalPrice/icon"):GetComponent("Image")
    self.discountPrice = Util.GetGameObject(self.halfPriceRoot, "priceRoot/discountPrice/value"):GetComponent("Text")
    self.discountIcon = Util.GetGameObject(self.halfPriceRoot, "priceRoot/discountPrice/icon"):GetComponent("Image")

    self.purChaseBtn = Util.GetGameObject(self.halfPriceRoot, "purchaseBtn"):GetComponent("Button")
    self.purChaseBtn.onClick:AddListener(function()
        self:OnPurChaseBtnClicked()
    end)
    self.purchaseText = Util.GetGameObject(self.purChaseBtn.transform, "Text"):GetComponent("Text")
end

function SevenDayCarnivalHalfPricePage:OnShow()
    self.gameObject:SetActive(true)
    self:SetSellGoods()
    --self:OnSortingOrderChange(sorting)
    self.isShow = true

end

function SevenDayCarnivalHalfPricePage:OnSortingOrderChange(sorting)
    Util.AddParticleSortLayer(self.itemEffect, sorting-self.EffectOrginLayerQu)--ItemView不能显示紫色特效 只能在Itemview同级重设个橙色特效 绑死在预设上
    self.EffectOrginLayerQu=sorting
end

function SevenDayCarnivalHalfPricePage:SetSellGoods()
    local shopInfoList = ShopManager.GetShopDataByType(SHOP_TYPE.SEVENDAY_CARNIVAL_SHOP)
    self.storeConfig = ConfigManager.GetConfigData(ConfigName.StoreConfig,shopInfoList.storeItem[self.mainPanel.selectDayTab].id)
    --self.storeConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig,
    --        "StoreId", SHOP_TYPE.SEVENDAY_CARNIVAL_SHOP, "Sort", self.mainPanel.selectDayTab)
    local goods = ShopManager.GetShopItemGoodsInfo(self.storeConfig.Id)
    self.giftInfo:OnOpen(false, goods[1], 1.35)
    local itemConfigData = ConfigManager.GetConfigData(ConfigName.ItemConfig, goods[1][1])

    --self.itemBg.sprite = Util.LoadSprite(QualityBgDef[itemConfigData.Quantity])
    --self.itemIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfigData.ResourceID))
    --self.itemNumber.text = goods[1][2]

    self.itemName.text = GetStringByEquipQua(itemConfigData.Quantity, itemConfigData.Name)
    local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.SEVENDAY_CARNIVAL_SHOP, self.storeConfig.Id, 1)

    self.originalPrice.text = oriCostNum
    self.originalIcon.sprite = SetIcon(costId)
    self.discountPrice.text = finalNum
    self.discountIcon.sprite = SetIcon(costId)

    self:SetPurChaseBtnStatus()
end

function SevenDayCarnivalHalfPricePage:SetPurChaseBtnStatus()
    local currentDay = SevenDayCarnivalManager.GetCurrentDayNumber()
    if self.mainPanel.selectDayTab > currentDay then
        self.purChaseBtn:GetComponent("Image").sprite = Util.LoadSprite(btnBackGround[2])
        self.purchaseText.text = GetLanguageStrById(11911)
        self.purChaseBtn.enabled = false
        Util.SetGray(self.purChaseBtn.gameObject, false)
        return
    end
    self.purChaseBtn:GetComponent("Image").sprite = Util.LoadSprite(btnBackGround[1])
    local remainBuyTimes = ShopManager.GetShopItemRemainBuyTimes(SHOP_TYPE.SEVENDAY_CARNIVAL_SHOP, self.storeConfig.Id)
    if remainBuyTimes == -1 or remainBuyTimes > 0 then
        self.purchaseText.text = GetLanguageStrById(11912)
        self.purChaseBtn.enabled = true
        Util.SetGray(self.purChaseBtn.gameObject, false)
    else
        self.purchaseText.text = GetLanguageStrById(11913)
        self.purChaseBtn.enabled = false
        Util.SetGray(self.purChaseBtn.gameObject, true)
    end
end

function SevenDayCarnivalHalfPricePage:OnHide()
    self.gameObject:SetActive(false)
    self.isShow = false
end

function SevenDayCarnivalHalfPricePage:IsActive()
    return self.isShow
end

function SevenDayCarnivalHalfPricePage:OnPurChaseBtnClicked()
    ShopManager.RequestBuyShopItem(SHOP_TYPE.SEVENDAY_CARNIVAL_SHOP, self.storeConfig.Id, 1, function()
        self:SetPurChaseBtnStatus()
    end)
end

return SevenDayCarnivalHalfPricePage