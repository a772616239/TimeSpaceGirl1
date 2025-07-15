GiftPanel = quick_class("CardActivityPanel")
local this = GiftPanel
local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local allData = {}
local itemsGrid = {}
--初始化组件（用于子类重写）
function GiftPanel:InitComponent(parent)
    this.gameObject = parent

    this.time = Util.GetGameObject(this.gameObject,"time/Text"):GetComponent("Text")
    this.pre = Util.GetGameObject(this.gameObject, "itemPre")
    this.scroll = Util.GetGameObject(this.gameObject, "scroll")

    local v = this.scroll:GetComponent("RectTransform").rect
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,
            this.pre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0, 0))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 1
end

--绑定事件（用于子类重写）
function GiftPanel:BindEvent()
end

--添加事件监听（用于子类重写）
function GiftPanel:AddListener()
end

--移除事件监听（用于子类重写）
function GiftPanel:RemoveListener()
end

function GiftPanel:OnShow(sortingOrder,parent)
    this.Refresh()
    this.SetTime()
end

--界面关闭时调用（用于子类重写）
function GiftPanel:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function GiftPanel:OnDestroy()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

function this.Refresh()
    allData = {}
    local curActId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Gift)
    for i = 1, #GlobalActivity[curActId].CanBuyRechargeId do
        local data = ConfigManager.GetConfigDataByKey(ConfigName.RechargeCommodityConfig, "Id", GlobalActivity[curActId].CanBuyRechargeId[i])
        table.insert(allData,data)
    end
    if allData then
        this.SortData()
        allData[#allData + 1] = {}
        this.scrollView:SetData(allData, function (index, go)
            if index == #allData then
                go:SetActive(false)
                return
            end
            go:SetActive(true)
            this.SetItemData(go, allData[index])
        end)
    end
end

function this.SortData()
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

function this.SetItemData(go, data)
    local price = Util.GetGameObject(go, "btn/price"):GetComponent("Text")
    local buyInfo = Util.GetGameObject(go, "buyInfo"):GetComponent("Text")
    local btnBuy = Util.GetGameObject(go, "btn")
    local grid = Util.GetGameObject(go, "scrollview/Viewport/grid")
    local boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, data.Id) or 0
    local shows = data.RewardShow

    local num = data.Limit - boughtNum
    if num < 0 then
        num = 0
    end
    buyInfo.text = GetLanguageStrById(11454)..num.."/"..data.Limit..GetLanguageStrById(10054)
    if data.Limit - boughtNum > 0 then
        price.text = MoneyUtil.GetMoney(data.Price)
        btnBuy:GetComponent("Button").enabled = true
        Util.SetGray(btnBuy, false)
    else
        price.text = GetLanguageStrById(10526)
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
                itemsGrid[go][i]:OnOpen(false, {shows[i][1], shows[i][2]}, 1)
                itemsGrid[go][i].gameObject:SetActive(true)
            end
        end
    else
        itemsGrid[go] = {}
        for i = 1, 5 do
            itemsGrid[go][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            itemsGrid[go][i].gameObject:SetActive(false)
            local obj = newObjToParent(grid, itemsGrid[go][i].transform)
            obj.gameObject:SetActive(false)
        end
        for i = 1, #shows do
            itemsGrid[go][i]:OnOpen(false, {shows[i][1], shows[i][2]}, 1)
            itemsGrid[go][i].gameObject:SetActive(true)
        end
    end

    Util.AddOnceClick(btnBuy, function()
        if data.Limit <= boughtNum then
            PopupTipPanel.ShowTip(GetLanguageStrById(10540))
        else
            --直购商品
            if AppConst.isSDKLogin then
                PayManager.Pay({Id = data.Id}, function ()
                    FirstRechargeManager.RefreshAccumRechargeValue(data.Id)
                    this.Refresh()
                end)
            else
                NetManager.RequestBuyGiftGoods(data.Id, function(msg)
                    FirstRechargeManager.RefreshAccumRechargeValue(data.Id)
                    this.Refresh()
                end)
            end
        end
    end)
end

function this.SetTime()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    local endTime = ActivityGiftManager.GetTaskEndTime(ActivityTypeDef.CardActivity_Gift)
    local timeDown = endTime - GetTimeStamp()
    this.time.text = GetLanguageStrById(12321)..TimeToDHMS(timeDown)
    this.timer = Timer.New(function()
        timeDown = timeDown - 1
        if timeDown < 1 then
            this:ClosePanel()
        end
        this.time.text = GetLanguageStrById(12321)..TimeToDHMS(timeDown)
    end, 1, -1, true)
    this.timer:Start()
end

return GiftPanel