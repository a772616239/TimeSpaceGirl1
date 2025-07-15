require("Base/BasePanel")
local ShopBuyPopup = Inherit(BasePanel)
local this = ShopBuyPopup
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
--初始化组件（用于子类重写）
function ShopBuyPopup:InitComponent()
    this.itemBg = Util.GetGameObject(self.gameObject, "tipImage/item/bg"):GetComponent("Image")
    this.itemIcon = Util.GetGameObject(self.gameObject, "tipImage/item/bg/icon"):GetComponent("Image")
    this.itemNum = Util.GetGameObject(self.gameObject, "tipImage/item/num"):GetComponent("Text")
    this.itemCount = Util.GetGameObject(self.gameObject, "tipImage/item/count"):GetComponent("Text")
    this.itemName = Util.GetGameObject(self.gameObject, "tipImage/item/name"):GetComponent("Text")
    this.itemContent = Util.GetGameObject(self.gameObject, "tipImage/item/content"):GetComponent("Text")

    this.costNum = Util.GetGameObject(self.gameObject, "tipImage/cost/ncost"):GetComponent("Text")
    this.discostNum1 = Util.GetGameObject(self.gameObject, "tipImage/cost/discost1"):GetComponent("Text")
    this.discostNum2 = Util.GetGameObject(self.gameObject, "tipImage/cost/discost2"):GetComponent("Text")
    this.costIcon = Util.GetGameObject(self.gameObject, "tipImage/cost/icon"):GetComponent("Image")
	this.costIcon1 = Util.GetGameObject(self.gameObject, "tipImage/cost/discost2/icon"):GetComponent("Image")

    this.slider = Util.GetGameObject(self.gameObject, "tipImage/Slider"):GetComponent("Slider")
    this.leftBtn = Util.GetGameObject(this.slider.gameObject, "btn/leftbtn")
    this.rightBtn = Util.GetGameObject(this.slider.gameObject, "btn/rightbtn")
    this.buyNumLab = Util.GetGameObject(this.slider.gameObject, "count"):GetComponent("Text")

    this.minbtn = Util.GetGameObject(this.slider.gameObject,"btn/minbtn")
    this.maxbtn = Util.GetGameObject(this.slider.gameObject,"btn/maxbtn")

    -- m5 this.backBtn = Util.GetGameObject(self.gameObject, "tipImage/btnReturn")
    this.backMask = Util.GetGameObject(self.gameObject, "BgMask") -- m5
    this.cancelBtn = Util.GetGameObject(self.gameObject, "tipImage/op/btnLeft")
    this.confirmBtn = Util.GetGameObject(self.gameObject, "tipImage/op/btnRight")

    this.vipTip = Util.GetGameObject(self.gameObject, "tipImage/vipTips")
    this.costTip = Util.GetGameObject(self.gameObject, "tipImage/costTips")
end

--绑定事件（用于子类重写）
function ShopBuyPopup:BindEvent()
    Util.AddClick(this.backMask, function()
        self:ClosePanel()
    end)
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
            self:ClosePanel()
            Game.GlobalEvent:DispatchEvent(GameEvent.Shop.OnExchangeChange)
        end)
    end)


    Util.AddSlider(this.slider.gameObject, function(go, value)
        this.OnSliderValueChange(value)
    end)


    Util.AddClick(this.minbtn, function ()
        this.slider.value = 1
    end)
    Util.AddClick(this.maxbtn, function ()
        this.slider.value = this.maxNum
    end)

    Util.AddClick(this.leftBtn, function()
        local curCount = this.slider.value
        if curCount < 1 then return end
        this.slider.value = curCount - 1
    end)
    Util.AddClick(this.rightBtn, function()
        if this.maxNum <= 0 then
            PopupTipPanel.ShowTip(GetLanguageStrById(11931))
            return
        end
        local curCount = this.slider.value
        if curCount >= 999 then
            PopupTipPanel.ShowTip(GetLanguageStrById(11697))
            return
        end
        if curCount >= this.maxNum then return end
        this.slider.value = curCount + 1
    end)
end

--添加事件监听（用于子类重写）
function ShopBuyPopup:AddListener()
end

--移除事件监听（用于子类重写）
function ShopBuyPopup:RemoveListener()
end

--界面打开时调用（用于子类重写）
function ShopBuyPopup:OnOpen(shopType, shopItemId)
    -- 获取数据
    this.shopType = shopType
    this.shopItemId = shopItemId
    this.shopItemInfo = ShopManager.GetShopItemInfo(shopItemId)
    this.shopItemData = ShopManager.GetShopItemData(shopType, shopItemId)

    -- 商品基础信息显示
    -- this.itemName.text = this.shopItemInfo.GoodsName
    this.itemName.text = GetLanguageStrById(itemConfig[this.shopItemInfo.Goods[1][1]].Name)
    this.goods = ShopManager.GetShopItemGoodsInfo(this.shopItemId)
    local goodsId = this.goods[1][1]
    local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
    this.itemContent.text = string.gsub(itemConfig[goodsId].ItemDescribe, "\\n", "\n")
    this.itemIcon.sprite = SetIcon(goodsId)
    this.itemBg.sprite = SetFrame(goodsId)
    this.itemNum.text = this.goods[1][2]
    -- 计算最大可购买的数量
    local countLimitNum = ShopManager.GetShopItemLimitBuyCount(shopItemId)
    local countLeftNum = countLimitNum >= 0 and countLimitNum - this.shopItemData.buyNum or math.huge
    this.itemCount.text = countLimitNum == -1 and "" or string.format(GetLanguageStrById(11695), countLeftNum, countLimitNum)
    this.itemCount.gameObject:SetActive(this.itemCount.text ~= "")


    -- 判断最大值
    local itemLimitNum = ShopManager.GetShopItemMaxBuy(shopType, shopItemId)
    this.maxNum = math.min(itemLimitNum, countLeftNum)
    this.maxNum = this.maxNum > 999 and 999 or this.maxNum
    -- 设置滑动范围
    this.slider.enabled = this.maxNum > 1
    this.slider.maxValue = this.maxNum
    this.slider.minValue = 0
    this.slider.value = this.maxNum > 0 and 1 or 0

    -- 设置颜色
    this.buyNumLab.color = this.maxNum > 0 and Color.New(1,1,1,1) or UIColor.NOT_ENOUGH_RED
    Util.SetGray(this.confirmBtn, this.maxNum <= 0)

    local costId, discostnum, costnum = ShopManager.calculateBuyCost(this.shopType, this.shopItemId, 1)
    this.costNum.text = discostnum
    -- 刷新花费
    this.RefreshCostShow()
    -- this.itemNum.text = 

    -- 商店购买界面提示显示设置
    this.vipTip:SetActive(false)
    --this.vipTip:SetActive(this.shopItemInfo.RelatedtoVIP == 1)
    local abcd = this.shopItemInfo.Cost[2]-- 公式常数
    this.costTip:SetActive(this.shopItemInfo.PremiumType == 2 or abcd[1] > 0 or abcd[2] > 0 or abcd[3] > 0 )
end

--- 滑动条值改变回调
function this.OnSliderValueChange(value)
    this.RefreshCostShow()
end

--- 根据slider值刷新显示
function this.RefreshCostShow()
    -- 购买数量
    this.buyNumLab.text = this.slider.value
    local count
    -- 计算数据
    if this.slider.value > 0 then
        count = --[[this.slider.value == 0 and 1 or ]] this.slider.value
    else
        count = --[[this.slider.value == 0 and 1 or ]] 1
        this.slider.value = 1
    end
    local costId, discostnum, costnum = ShopManager.calculateBuyCost(this.shopType, this.shopItemId, count)
    -- 判断显示
    --local isDiscount = this.shopItemInfo.IsDiscount == 1
    --this.costNum.gameObject:SetActive(not isDiscount)
    --this.discostNum1.gameObject:SetActive(isDiscount)
    --this.discostNum2.gameObject:SetActive(isDiscount)
    -- 原价
    -- this.costNum.text = costnum / count
    -- this.discostNum1.text = costnum
    -- 折后价
    this.discostNum2.text = discostnum
    -- 物品icon
    this.costIcon.sprite = SetIcon(costId)
	this.costIcon1.sprite = SetIcon(costId)
    -- 物品获取数量
    this.itemNum.text = this.goods[1][2] * count
end



--界面关闭时调用（用于子类重写）
function ShopBuyPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function ShopBuyPopup:OnDestroy()
end

return ShopBuyPopup