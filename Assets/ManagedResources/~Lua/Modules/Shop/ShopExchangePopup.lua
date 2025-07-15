require("Base/BasePanel")
local ShopExchangePopup = Inherit(BasePanel)
local this = ShopExchangePopup

--初始化组件（用于子类重写）
function ShopExchangePopup:InitComponent()
    this.title = Util.GetGameObject(self.gameObject, "tipImage/title"):GetComponent("Text")

    this.leftIcon = Util.GetGameObject(self.gameObject, "tipImage/item/left/icon"):GetComponent("Image")
    this.leftNum = Util.GetGameObject(self.gameObject, "tipImage/item/left/num"):GetComponent("Text")
    this.leftHaveNum = Util.GetGameObject(self.gameObject, "tipImage/item/left/haveNum"):GetComponent("Text")

    this.rightIcon = Util.GetGameObject(self.gameObject, "tipImage/item/right/icon"):GetComponent("Image")
    this.rightNum = Util.GetGameObject(self.gameObject, "tipImage/item/right/num"):GetComponent("Text")

    this.slider = Util.GetGameObject(self.gameObject, "tipImage/Slider"):GetComponent("Slider")
    this.leftBtn = Util.GetGameObject(this.slider.gameObject, "leftbtn")
    this.rightBtn = Util.GetGameObject(this.slider.gameObject, "rightbtn")
    this.buyNumLab = Util.GetGameObject(this.slider.gameObject, "count"):GetComponent("Text")

    this.backBtn = Util.GetGameObject(self.gameObject, "tipImage/btnReturn")
    this.cancelBtn = Util.GetGameObject(self.gameObject, "tipImage/op/btnLeft")
    this.confirmBtn = Util.GetGameObject(self.gameObject, "tipImage/op/btnRight")

    this.rateTip = Util.GetGameObject(self.gameObject, "tipImage/rateTip"):GetComponent("Text")
end

--绑定事件（用于子类重写）
function ShopExchangePopup:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.cancelBtn, function()
        self:ClosePanel()
    end)
    Util.AddClick(this.confirmBtn, function()
        local count = this.slider.value

        local itemLimitNum = ShopManager.GetShopItemMaxBuy(this.shopType, this.shopItemId)
        if itemLimitNum == 0 or itemLimitNum < count then
            local costId = this.shopItemInfo.Cost[1][1]
            NotEnoughPopup:Show(costId, function()
                this:ClosePanel()
            end)
            return
        end

        ShopManager.RequestBuyShopItem(this.shopType, this.shopItemId, count, function()
            if(this.shopItemId==10013) then
                CheckRedPointStatus(RedPointType.LuckyCat_GetReward)
                Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnLuckyCatRedRefresh)
            end
            self:ClosePanel()
        end)
    end)


    Util.AddSlider(this.slider.gameObject, function(go, value)
        this.OnSliderValueChange(value)
    end)


    Util.AddClick(this.leftBtn, function()
        local curCount = this.slider.value
        if curCount <= 1 then return end
        this.slider.value = curCount - 1
    end)
    Util.AddClick(this.rightBtn, function()
        local curCount = this.slider.value

        local itemLimitNum = ShopManager.GetShopItemMaxBuy(this.shopType, this.shopItemId)
        if itemLimitNum == 0 or itemLimitNum < curCount then
            local costId = this.shopItemInfo.Cost[1][1]
            NotEnoughPopup:Show(costId, function()
                this:ClosePanel()
            end)
            return
        end

        if this.maxNum <= 0 then
            PopupTipPanel.ShowTipByLanguageId(11931)
            return
        end
        if curCount >= 999 then
            PopupTipPanel.ShowTipByLanguageId(11697)
           return
        end
        if curCount >= this.maxNum then return end
        this.slider.value = curCount + 1
    end)
end

--添加事件监听（用于子类重写）
function ShopExchangePopup:AddListener()
end

--移除事件监听（用于子类重写）
function ShopExchangePopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ShopExchangePopup:OnOpen(shopType, shopItemId, titleName)
    this.title.text = titleName or GetLanguageStrById(11932)

    -- 获取数据
    this.shopType = shopType
    this.shopItemId = shopItemId
    this.shopItemInfo = ShopManager.GetShopItemInfo(shopItemId)
    this.shopItemData = ShopManager.GetShopItemData(shopType, shopItemId)

    -- 计算最大可购买的数量
    local countLimitNum = ShopManager.GetShopItemLimitBuyCount(shopItemId)
    local countLeftNum = countLimitNum >= 0 and countLimitNum - this.shopItemData.buyNum or math.huge
    local itemLimitNum = ShopManager.GetShopItemMaxBuy(shopType, shopItemId)
    -- 判断最大值
    this.maxNum = math.min(itemLimitNum, countLeftNum)
    this.maxNum = this.maxNum > 999 and 999 or this.maxNum

    -- 设置滑动范围
    this.slider.enabled = this.maxNum > 1
    this.slider.maxValue = this.maxNum
    this.slider.minValue = 0
    this.slider.value = this.maxNum > 0 and 1 or 0

    -- 刷新显示
    local costId = this.shopItemInfo.Cost[1][1]
    local goods = ShopManager.GetShopItemGoodsInfo(this.shopItemId)
    local goodsId = goods[1][1]
    this.leftIcon.sprite = SetIcon(costId)
    this.leftHaveNum.text = BagManager.GetItemCountById(costId)
    this.rightIcon.sprite = SetIcon(goodsId)

    -- 计算兑换比例
    local costNum = CalculateCostCount(0, this.shopItemInfo.Cost[2])
    local goodsNum = goods[1][2]
    local costName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, costId).Name)
    local goodsName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, goodsId).Name)
    this.rateTip.text = string.format(GetLanguageStrById(11933), costNum, costName, goodsNum, goodsName)

    -- 设置颜色
    this.buyNumLab.color = this.maxNum > 0 and Color.New(0.55,0.59,0.62,1) or UIColor.NOT_ENOUGH_RED
    Util.SetGray(this.confirmBtn, this.maxNum <= 0)

    --
    this.OnSliderValueChange(this.slider.value)
end

--- 滑动条值改变回调
function this.OnSliderValueChange(value)
    this.buyNumLab.text = value
    local count = value <= 0 and 1 or value
    local costId, discostnum, costnum = ShopManager.calculateBuyCost(this.shopType, this.shopItemId, count)
    local goods = ShopManager.GetShopItemGoodsInfo(this.shopItemId)
    local goodsNum = goods[1][2] * count
    this.leftNum.text = discostnum
    this.rightNum.text = goodsNum

end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ShopExchangePopup:OnShow()
end

--界面关闭时调用（用于子类重写）
function ShopExchangePopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function ShopExchangePopup:OnDestroy()
end

return ShopExchangePopup