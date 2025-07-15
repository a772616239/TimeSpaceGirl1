local GiftBuy = quick_class("GiftBuy")
local this = GiftBuy
local itemsGrid = {}--item重复利用
local allData = {}
local rechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local cursortingOrder
local endTime = 0
-- local isFirstOn = true--是否首次打开页面

function GiftBuy:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function GiftBuy:InitComponent(gameObject)
    this.itemPre = Util.GetGameObject(gameObject, "ItemPre")
    this.endTime = Util.GetGameObject(gameObject, "Image/endTime"):GetComponent("Text")
    this.endTimeBg = Util.GetGameObject(gameObject, "Image")
    this.scrollItem = Util.GetGameObject(gameObject, "scroll")
    local rootHight = this.scrollItem.transform.rect.height
    local width = this.scrollItem.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollItem.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function GiftBuy:BindEvent()
end

--添加事件监听（用于子类重写）
function GiftBuy:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
end

--移除事件监听（用于子类重写）
function GiftBuy:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
end
local sortingOrder = 0
--界面打开时调用（用于子类重写）
function GiftBuy:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function GiftBuy:OnShow(_sortingOrder)
    -- CustomEventManager.PayCustomEvent("限时特惠购买页面弹出")
    sortingOrder = _sortingOrder
    this:OnShowData()
end

function GiftBuy:OnSortingOrderChange(_cursortingOrder)
    cursortingOrder = _cursortingOrder
    for i, v in pairs(itemsGrid) do
        for j = 1, #v do
            v[j]:SetEffectLayer(cursortingOrder)
        end
    end
end

function GiftBuy:OnShowData()
    allData = {}
    local data = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.RechargeCommodityConfig, "ShowType", 20, "Type", GoodsTypeDef.DirectPurchaseGift)   
    for i = 1, #data do
        local  curgoodData = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.DirectPurchaseGift, data[i].Id)
        if curgoodData then
            if curgoodData.endTime - GetTimeStamp() > 0 or curgoodData.endTime == 0 then
                table.insert(allData,data[i])
            end
        end
    end
    this.SortData(allData)
    allData[#allData + 1] = {}
    this.ScrollView:SetData(allData, function (index, go)
        if index == #allData then
            go:SetActive(false)
            return
        end
        go:SetActive(true)
        this.SingleDataShow(go, allData[index], index)
    end)

    -- PatFaceManager.RemainTimeDown2(this.endTimeBg,this.endTime,endTime - GetTimeStamp(),GetLanguageStrById(12547))

    CardActivityManager.TimeDown(this.endTime, endTime - GetTimeStamp())
end

--刷新每一条的显示数据
function this.SingleDataShow(go, data, index)
    --绑定组件
    local shopItemData = data
    local name = Util.GetGameObject(go, "context/text"):GetComponent("Text")
    local price = Util.GetGameObject(go, "btnBuy/price"):GetComponent("Text")
    local buyInfo = Util.GetGameObject(go, "buyInfo")
    local btnBuy = Util.GetGameObject(go, "btnBuy")
    local grid = Util.GetGameObject(go, "scrollView/Mask/grid")
    local shadow = Util.GetGameObject(go, "shadow")
    local tipImageText = Util.GetGameObject(go,"tip/tip1/text2"):GetComponent("Text")

    local  goodData = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.DirectPurchaseGift, data.Id)
    local boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, data.Id) or 0
    local shows = shopItemData.RewardShow
    name.text = GetLanguageStrById(shopItemData.Name)
    tipImageText.text = "( "..boughtNum.." / "..shopItemData.Limit.." )"
    buyInfo:SetActive( shopItemData.IsDiscount ~= 0 )
    if shopItemData.IsDiscount and shopItemData.IsDiscount > 0 then
        buyInfo:GetComponent("Text").text = GetLanguageStrById(10537)..  MoneyUtil.GetCurrencyUnit() .. (MoneyUtil.GetPrice(shopItemData.Price) / (shopItemData.IsDiscount/10))
    end
    if goodData then
        endTime = goodData.endTime
    end
    if shopItemData.Limit - boughtNum > 0 then
        price.text = MoneyUtil.GetMoney(shopItemData.Price)
        btnBuy:GetComponent("Button").enabled = true
        Util.SetGray(btnBuy, false)
    else
        price.text = GetLanguageStrById(10539)
        btnBuy:GetComponent("Button").enabled = false
        Util.SetGray(btnBuy, true)
    end
    --滚动条复用重设itemview
    if itemsGrid[go] then
        for i = 1, 5 do
            itemsGrid[go][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            if itemsGrid[go][i] then
                itemsGrid[go][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.6,false,false,false,cursortingOrder)
                itemsGrid[go][i].gameObject:SetActive(true)
            end
        end
    else
        itemsGrid[go] = {}
        for i = 1, 5 do
            itemsGrid[go][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            itemsGrid[go][i].gameObject:SetActive(false)
            local obj = newObjToParent(shadow,itemsGrid[go][i].transform)
            obj.transform:SetAsFirstSibling()
            obj:GetComponent("RectTransform").transform.localScale = Vector3.one*1.1
            obj.gameObject:SetActive(true)
        end
        for i = 1, #shows do
            itemsGrid[go][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.6,false,false,false,cursortingOrder)
            itemsGrid[go][i].gameObject:SetActive(true)
        end
    end

    Util.AddOnceClick(btnBuy, function()
        if shopItemData.Limit <= boughtNum then
            PopupTipPanel.ShowTipByLanguageId(10540)
        else
            --直购商品
            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = data.Id }, function(msg)
                    FirstRechargeManager.RefreshAccumRechargeValue(data.Id)
                    -- OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, data.goodsId) -- 改成后端推了
                    GiftBuy:OnShowData()
                end)
            else
                NetManager.RequestBuyGiftGoods(data.Id, function(msg)
                    FirstRechargeManager.RefreshAccumRechargeValue(data.Id)
                    -- OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, data.goodsId) -- 改成后端推了
                    GiftBuy:OnShowData()
                end)
            end
        end
    end)
end

function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    --OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.GiftBuy, id)
    GiftBuy:OnShowData()
end

function this.SortData(allData)
    table.sort(allData, function(a,b)
        local aboughtNum = a.Limit - OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, a.Id) > 0 and 2 or 1
        local bboughtNum = b.Limit - OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, b.Id) > 0 and 2 or 1
        if aboughtNum ==  bboughtNum then
            return a.Id < b.Id
        else
            return aboughtNum > bboughtNum
        end
    end)
end

--界面关闭时调用（用于子类重写）
function GiftBuy:OnClose()
    CardActivityManager.StopTimeDown()
end

--界面销毁时调用（用于子类重写）
function GiftBuy:OnDestroy()
    sortingOrder = 0
end

return GiftBuy