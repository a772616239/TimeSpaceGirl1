local FestivalStorePage = quick_class("FestivalStorePage")
local allData={}
local itemsGrid = {}--item重复利用
local this=FestivalStorePage
local parent
local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
function FestivalStorePage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function FestivalStorePage:InitComponent(gameObject)
    this.time = Util.GetGameObject(gameObject, "tiao/time"):GetComponent("Text")
    this.itemPre = Util.GetGameObject(gameObject, "ItemPre3")
    this.scrollItem = Util.GetGameObject(gameObject, "scrollItem")
    local rootHight = this.scrollItem.transform.rect.height
    local width = this.scrollItem.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollItem.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function FestivalStorePage:BindEvent()
end

--添加事件监听（用于子类重写）
function FestivalStorePage:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
end

--移除事件监听（用于子类重写）
function FestivalStorePage:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
end
local sortingOrder = 0
--界面打开时调用（用于子类重写）
function FestivalStorePage:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function FestivalStorePage:OnShow(_sortingOrder,_parent)
    parent = _parent
    sortingOrder = _sortingOrder
    this:OnShowData()
    FestivalStorePage:SetTime()
end
function FestivalStorePage:OnShowData()
    allData={}
    -- allData = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.RechargeCommodityConfig, "ShowType", 23, "Type", GoodsTypeDef.DirectPurchaseGift)
    local curActId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.FestivalActivity_recharge)
    for i = 1, #GlobalActivity[curActId].CanBuyRechargeId do
        local data = ConfigManager.GetConfigDataByKey(ConfigName.RechargeCommodityConfig, "Id", GlobalActivity[curActId].CanBuyRechargeId[i])
        table.insert(allData,data)
    end
    if allData then
        this.SortData(allData)
        this.ScrollView:SetData(allData, function (index, go)
            this.SingleDataShow(go, allData[index])
        end)  
    end
    
end

function FestivalStorePage:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    local endTime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.FestivalActivity_recharge)
    local timeDown = endTime - GetTimeStamp()
    this.time.text = GetLanguageStrById(12321)..TimeToDHMS(timeDown)
    self.timer = Timer.New(function()
        timeDown = timeDown - 1
        if timeDown < 1 then
            parent:ClosePanel()
        end
        this.time.text = GetLanguageStrById(12321)..TimeToDHMS(timeDown)
    end, 1, -1, true)
    self.timer:Start()
end

function FestivalStorePage:SortData()
    if allData==nil then
        return
    end
    table.sort(allData, function(a,b)
        local aboughtNum = a.Limit - OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, a.Id) > 0 and 2 or 1
        local bboughtNum = b.Limit - OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, b.Id) > 0 and 2 or 1
        if aboughtNum ==  bboughtNum then
            if a.Sequence == b.Sequence then
                return a.Price < b.Price
            else
                return a.Sequence < b.Sequence
            end
        else
            return aboughtNum > bboughtNum
        end
    end)
end
--刷新每一条的显示数据
function this.SingleDataShow(pre,value)
    if pre==nil or value==nil then
        return
    end
    --绑定组件
    local shopItemData = value
    local price = Util.GetGameObject(pre, "btnBuy/price"):GetComponent("Text")
    local buyInfo = Util.GetGameObject(pre, "buyInfo")
    local btnBuy = Util.GetGameObject(pre, "btnBuy")
    local grid = Util.GetGameObject(pre, "scrollView/grid")
    local shadow = Util.GetGameObject(pre, "shadow")
    --local  goodData = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.DirectPurchaseGift, value.Id)
    local boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, value.Id) or 0
    local shows = shopItemData.RewardShow
    buyInfo:GetComponent("Text").text =GetLanguageStrById(11454).. shopItemData.Limit-boughtNum.."/".. shopItemData.Limit..GetLanguageStrById(10054) ..")"
    if shopItemData.Limit - boughtNum > 0 then
        price.text = MoneyUtil.GetMoney(shopItemData.Price)
        btnBuy:GetComponent("Button").enabled = true
        Util.SetGray(btnBuy, false)
    else
        price.text = GetLanguageStrById(10526)
        btnBuy:GetComponent("Button").enabled = false
        Util.SetGray(btnBuy, true)
    end
    --滚动条复用重设itemview
    if itemsGrid[pre] then
        for i = 1, 5 do
            itemsGrid[pre][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            if itemsGrid[pre][i] then
                itemsGrid[pre][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.9,false,false,false,sortingOrder)
                itemsGrid[pre][i].gameObject:SetActive(true)
            end
        end
    else
        itemsGrid[pre]={}
        for i = 1, 5 do
            itemsGrid[pre][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            itemsGrid[pre][i].gameObject:SetActive(false)
            local obj= newObjToParent(shadow,itemsGrid[pre][i].transform)
            obj.transform:SetAsFirstSibling()
            obj.transform:DOAnchorPos(Vector3(0,-3,0),0)
            obj:GetComponent("RectTransform").transform.localScale=Vector3.one*1.1
            obj.gameObject:SetActive(true)
        end
        for i = 1, #shows do
            itemsGrid[pre][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.9,false,false,false,sortingOrder)
            itemsGrid[pre][i].gameObject:SetActive(true)
        end
    end
    --local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FINDTREASURE_GIFT, data.id, 1)
    Util.AddOnceClick(btnBuy, function()
        if shopItemData.Limit <= boughtNum then
            PopupTipPanel.ShowTip(GetLanguageStrById(10540))
        else
            --直购商品
            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = value.Id }, function ()
                    FirstRechargeManager.RefreshAccumRechargeValue(value.Id)
                    this:OnShowData()
                end)
            else
                NetManager.RequestBuyGiftGoods(value.Id, function(msg)
                    FirstRechargeManager.RefreshAccumRechargeValue(value.Id)
                    -- OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, data.goodsId) -- 改成后端推了
                    this:OnShowData()
                end)
            end
        end
    end)
end

--界面打开时调用（用于子类重写）
function FestivalStorePage:OnOpen()

end

function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    --OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.GiftBuy, id)
    this:OnShowData()
end

function FestivalStorePage:OnClose()

end

--界面销毁时调用（用于子类重写）
function FestivalStorePage:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
end

function FestivalStorePage:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
end

return FestivalStorePage