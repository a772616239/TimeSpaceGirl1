ShopItemView = {}
local itemId = 0
local shopType = 0
-- 当前物品的信息
local itemInfo = {}
function ShopItemView:New(gameObject)
    local _o = {}
    _o.gameObject = gameObject
    _o.transform = gameObject.transform
    setmetatable(_o, { __index = ShopItemView })
    return _o
end

--初始化组件（用于子类重写）
function ShopItemView:InitComponent()
    self.itemFrame = Util.GetGameObject(self.gameObject, "item"):GetComponent("Image")
    self.itemIcon = Util.GetGameObject(self.gameObject, "item/icon"):GetComponent("Image")
    self.itemName = Util.GetGameObject(self.gameObject, "item/itemName"):GetComponent("Text")
    self.limitTimes = Util.GetGameObject(self.gameObject, "item/buyLimit/Text"):GetComponent("Text")
    self.itemPrice = Util.GetGameObject(self.gameObject, "price/Text"):GetComponent("Text")
    self.costIcon = Util.GetGameObject(self.gameObject, "price/costIcon"):GetComponent("Image")
    self.btnBuy = Util.GetGameObject(self.gameObject, "price/btnBuy")

end

--绑定事件（用于子类重写）
function ShopItemView:BindEvent()
    Util.AddClick(self.btnBuy, function ()
        self:ShowBuyPanel()
    end)
end

--添加事件监听（用于子类重写）
function ShopItemView:AddListener()

end

--移除事件监听（用于子类重写）
function ShopItemView:RemoveListener()

end


--界面打开时调用（用于子类重写）
function ShopItemView:OnOpen(id, type)
    if id then
        self:ShowItemInfo(id)
        itemId = id
        shopType = type
    end
end

-- 显示单个物品的信息
function ShopItemView:ShowItemInfo(id)
    --设置可以购买的物品信息
    local itemName = ShopManager.GetGoodsName(id)
    local itemId, itemNum = ShopManager.BoughtInfo(id)
    self.itemName.text = itemName
    self.itemIcon.sprite = SetIcon(itemId)


    -- 消耗物品的信息
    local costId, price = ShopManager.CostInfo(id)
    local limitCount = ShopManager.LimitBuyCount(id)

    self.limitTimes.text = string.format(GetLanguageStrById(12082), limitCount)
    self.itemPrice.text = tostring(price)
    self.costIcon.sprite = SetIcon(costId)

    itemInfo.getId = itemId
    itemInfo.getNum = itemNum
    itemInfo.costId = costId
    itemInfo.costPrice = price

end

-- 商店类型
local SHOP_TYPE = {
    [1] = "",                 -- GetLanguageStrById(12083)
    [2] = UIName.BazzarPopup, -- GetLanguageStrById(12084)
    [3] = "",                 -- GetLanguageStrById(12085)
}
-- 根据商店类型弹出不同的购买界面
function ShopItemView:ShowBuyPanel()
    if shopType == 0 or not shopType then

        return
    else
        UIManager.OpenPanel(SHOP_TYPE[shopType], itemInfo, itemId)
    end
end

--界面关闭时调用（用于子类重写）
function ShopItemView:OnClose()

end

--界面销毁时调用（用于子类重写）
function ShopItemView:OnDestroy()

end

return ShopItemView