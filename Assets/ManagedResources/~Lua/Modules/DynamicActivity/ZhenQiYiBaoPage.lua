local ZhenQiYiBaoPage = quick_class("ZhenQiYiBaoPage")
local allData={}
local itemsGrid = {}--item重复利用
local this=ZhenQiYiBaoPage
local parent
local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
function ZhenQiYiBaoPage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function ZhenQiYiBaoPage:InitComponent(gameObject)
    this.time = Util.GetGameObject(gameObject, "time/timeText"):GetComponent("Text")
    this.itemPre = Util.GetGameObject(gameObject, "ItemPre")
    this.scrollItem = Util.GetGameObject(gameObject, "scrollItem")
    local rootHight = this.scrollItem.transform.rect.height
    local width = this.scrollItem.transform.rect.width
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollItem.transform,
            this.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 5))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
end

--绑定事件（用于子类重写）
function ZhenQiYiBaoPage:BindEvent()
end

--添加事件监听（用于子类重写）
function ZhenQiYiBaoPage:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
end

--移除事件监听（用于子类重写）
function ZhenQiYiBaoPage:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
end

local sortingOrder = 0
--界面打开时调用（用于子类重写）
function ZhenQiYiBaoPage:OnOpen()

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ZhenQiYiBaoPage:OnShow(_sortingOrder,_parent)
    parent = _parent
    sortingOrder = _sortingOrder
    this:OnShowData()
    ZhenQiYiBaoPage:SetTime()
end

function ZhenQiYiBaoPage:OnShowData()
    allData = {}
    -- allData = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.RechargeCommodityConfig, "ShowType", 23, "Type", GoodsTypeDef.DirectPurchaseGift)
    local curActId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.DynamicAct_Treasure)
    for i = 1, #GlobalActivity[curActId].CanBuyRechargeId do
        local data = ConfigManager.GetConfigDataByKey(ConfigName.RechargeCommodityConfig, "Id", GlobalActivity[curActId].CanBuyRechargeId[i])
        table.insert(allData,data)
    end
    if allData then
        this.SortData(allData)
        -- local itemList = {}
        allData[#allData+1] = {}
        this.ScrollView:SetData(allData, function (index, go)
            if index == #allData then
                go:SetActive(false)
                return
            end
            go:SetActive(true)
            this.SingleDataShow(go, allData[index])
            -- itemList[index] = go
        end)
        -- DelayCreation(itemList)
    end
end

function ZhenQiYiBaoPage:SetTime()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    local endTime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.DynamicAct_Treasure)
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

function ZhenQiYiBaoPage:SortData()
    if allData == nil then
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
    if pre == nil or value == nil then
        return
    end
    -- pre:SetActive(true)
    --绑定组件
    local shopItemData = value
    local price = Util.GetGameObject(pre, "btnBuy/price"):GetComponent("Text")
    local buyInfo = Util.GetGameObject(pre, "buyInfo")
    local btnBuy = Util.GetGameObject(pre, "btnBuy")
    local grid = Util.GetGameObject(pre, "scrollView/grid")
    -- local shadow = Util.GetGameObject(pre, "shadow")
    --local  goodData = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.DirectPurchaseGift, value.Id)
    local boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, value.Id) or 0
    local shows = shopItemData.RewardShow
    buyInfo:GetComponent("Text").text =GetLanguageStrById(11454).." ".. shopItemData.Limit-boughtNum.."/".. shopItemData.Limit .." ".. GetLanguageStrById(10054) 
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
                itemsGrid[pre][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.65,false,false,false,sortingOrder)
                itemsGrid[pre][i].gameObject:SetActive(true)
            end
        end
    else
        itemsGrid[pre]={}
        for i = 1, 5 do
            itemsGrid[pre][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            itemsGrid[pre][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            itemsGrid[pre][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.65,false,false,false,sortingOrder)
            itemsGrid[pre][i].gameObject:SetActive(true)
        end
    end
    --local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FINDTREASURE_GIFT, data.id, 1)
    Util.AddOnceClick(btnBuy, function()
        if shopItemData.Limit <= boughtNum then
            PopupTipPanel.ShowTipByLanguageId(10540)
        else
            --直购商品
            if AppConst.isSDKLogin then
                PayManager.Pay({Id = value.Id}, function ()
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

function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    --OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.GiftBuy, id)
    this:OnShowData()
end

function ZhenQiYiBaoPage:OnClose()

end

--界面销毁时调用（用于子类重写）
function ZhenQiYiBaoPage:OnDestroy()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
end

function ZhenQiYiBaoPage:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end 
    sortingOrder = 0
end

return ZhenQiYiBaoPage