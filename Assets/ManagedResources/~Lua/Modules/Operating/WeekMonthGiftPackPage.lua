local WeekMonthGiftPackPage = quick_class("WeekMonthGiftPackPage")
local rechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local sortingOrder = 0
local extra = nil--判断周、月礼包
local weekSprite = "N1_bg_fuli_zhouhui"
local monthSprite = "N1_bg_fuli_yuehui"
local weekSpriteText = GetPictureFont("cn2-X1_fuli_banner_02")
local monthSpriteText = GetPictureFont("cn2-X1_fuli_banner_03")
local isFirstOn = true--是否首次打开页面

function WeekMonthGiftPackPage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
    self.ItemList = {}
    self.scrollList = {}
    self.newItemList = {}
end

function WeekMonthGiftPackPage:InitComponent(gameObject)
    self.itemPre = Util.GetGameObject(gameObject, "rzyBg/ItemPre")
    --self.bg = Util.GetGameObject(gameObject, "rzyBg")
    self.titleBg = Util.GetGameObject(gameObject, "rzyBg/bg"):GetComponent("Image")
    self.titleTxt = Util.GetGameObject(gameObject,"rzyBg/bg/title"):GetComponent("Image")
    self.redPoint = Util.GetGameObject(gameObject,"rzyBg/freeBtn/redPoint")
    self.endTime = Util.GetGameObject(gameObject, "rzyBg/bg/endTime"):GetComponent("Text")
    --self.endTimeBg = Util.GetGameObject(gameObject, "rzyBg/Image")
    self.scrollItem = Util.GetGameObject(gameObject, "rzyBg/scrollItem")
    -- self.tip1 = Util.GetGameObject(gameObject, "rzyBg/tip1")
    -- self.tip2 = Util.GetGameObject(gameObject, "rzyBg/tip2")

    local rootHight = self.scrollItem.transform.rect.height
    local width = self.scrollItem.transform.rect.width

    self.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scrollItem.transform,
            self.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 0))
    self.scrollView.moveTween.MomentumAmount = 1
    self.scrollView.moveTween.Strength = 2
end

function WeekMonthGiftPackPage:BindEvent()
end

function WeekMonthGiftPackPage:OnShow(_sortingOrder,extraTab)
    isFirstOn = true
    sortingOrder = _sortingOrder
    extra = extraTab
    self:RefreshData()
    self.gameObject:SetActive(true)
end

function WeekMonthGiftPackPage:RefreshData()
    -- 刷新商品数据
    self:RefreshGiftData()
    -- 刷新剩余时间
    self:GetRemainTime()
end

function WeekMonthGiftPackPage:RefreshGiftData()
    local shopData = {}

    if extra == 1 then--周礼包
        -- self.titleBg.sprite = Util.LoadSprite(weekSprite)
        self.titleTxt.sprite = Util.LoadSprite(weekSpriteText)
        -- self.tip1:SetActive(true)
        -- self.tip2:SetActive(false)
    elseif extra == 2 then--月礼包
        -- self.titleBg.sprite = Util.LoadSprite(monthSprite)
        self.titleTxt.sprite = Util.LoadSprite(monthSpriteText)
        -- self.tip1:SetActive(false)
        -- self.tip2:SetActive(true)
    end

    shopData = self:ResetShopData(OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift))
    --#OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift == 27
    table.sort(shopData,function(a,b)
        if a.sortId == b.sortId then
            if a.Sequence == b.Sequence then
                return a.data.goodsId < b.data.goodsId
            else
                return a.Sequence < b.Sequence
            end
        else
            return a.sortId > b.sortId
        end
    end)

    -- local itemList = {}

    local callBack = function(index, item)
        if index == #shopData then
            item:SetActive(false)
            return
        end
        item:SetActive(true)
        self:RefreshShowData(item, shopData[index].data)
        -- itemList[index] = item
    end
    shopData[#shopData + 1] = {}
    self.scrollView:SetData(shopData, callBack)
    CheckRedPointStatus(RedPointType.EveryWeekPreference)
    CheckRedPointStatus(RedPointType.EveryMonthPreference)

    -- if isFirstOn then
    --     isFirstOn = false
    --     DelayCreation(itemList)
    -- end
end

function WeekMonthGiftPackPage:RefreshShowData(item, data)
    local grid = Util.GetGameObject(item, "scrollview/Viewport/grid")
    local btnBuy = Util.GetGameObject(item, "btnBuy")
    local icon = Util.GetGameObject(btnBuy, "icon")
    local price = Util.GetGameObject(btnBuy, "price"):GetComponent("Text")
    local redPoint = Util.GetGameObject(btnBuy, "redPoint")
    local buyInfo = Util.GetGameObject(item, "buyInfo"):GetComponent("Text")
    local shadow = Util.GetGameObject(item,"shadow")
    local scrollview = Util.GetGameObject(item, "scrollview")
    local itemRoot = Util.GetGameObject(item, "scrollview/itemRoot")

    -- 物品Item
    local shows
    local shopItemData
    local boughtNum = 0
    local limitNum = 0
    local costId, finalNum, oriCostNum

    shopItemData = rechargeCommodityConfig[data.goodsId]
    shows = shopItemData.RewardShow
    --name.text = shopItemData.Name
    boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, data.goodsId)
    limitNum = shopItemData.Limit
    --limitNum = OperatingManager.GetLeftBuyTime(GoodsTypeDef.DirectPurchaseGift,data.goodsId)
    costId, finalNum, oriCostNum = nil,shopItemData.Price,nil

    if extra == 1  then
        if finalNum == 0 then
           BindRedPointObject(RedPointType.EveryWeekPreference, redPoint)
        else
            redPoint:SetActive(false)
        end
    else
        if finalNum == 0 then
            BindRedPointObject(RedPointType.EveryMonthPreference,redPoint)
        else
            redPoint:SetActive(false)
        end
    end
    --滚动条复用重设itemview
    if self.ItemList[item] then
        for i = 1, 5 do
            self.ItemList[item][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            if self.ItemList[item][i] then
                self.ItemList[item][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 1,false,false,false,self.mainPanel.sortingOrder)
                self.ItemList[item][i].gameObject:SetActive(true)
            end
        end
    else
        self.ItemList[item] = {}
        for i = 1, 5 do
            self.ItemList[item][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            self.ItemList[item][i].gameObject:SetActive(false)
            local obj = newObjToParent(shadow,self.ItemList[item][i].transform)
            obj.transform:SetAsFirstSibling()
            obj.transform:DOAnchorPos(Vector3(0,-3,0),0)
            obj:GetComponent("RectTransform").transform.localScale = Vector3.one*1.1
            obj.gameObject:SetActive(true)
        end
        for i = 1, #shows do
            self.ItemList[item][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 1,false,false,false,self.mainPanel.sortingOrder)
            self.ItemList[item][i].gameObject:SetActive(true)
        end
    end

    -- if self.scrollList[item] then

    -- else
    --     local rootHight = scrollview.transform.rect.height
    --     local width = scrollview.transform.rect.width
    --     self.scrollList[item] = SubUIManager.Open(SubUIConfig.ScrollCycleView, scrollview.transform,
    --         itemRoot, nil, Vector2.New(width, rootHight), 2, 1, Vector2.New(0, 5), nil, nil, self.scrollView)
    --     self.scrollList[item].moveTween.MomentumAmount = 1
    --     self.scrollList[item].moveTween.Strength = 2
    -- end

    -- self.scrollList[item]:SetData(shows, function(index, item)
    --     self:RefreshItem(item, shows[index])
    -- end)

    -- 设置按钮状态
    local isCanBuy = limitNum - boughtNum > 0
    btnBuy:GetComponent("Button").interactable = isCanBuy
    Util.SetGray(btnBuy,not isCanBuy)
    icon:GetComponent("Image").enabled = isCanBuy
    if isCanBuy then
        --> price.text = finalNum..GetLanguageStrById(10538)
        price.text = MoneyUtil.GetMoney(finalNum)
        buyInfo.text = GetLanguageStrById(10535)..limitNum - boughtNum --.. "/" .. limitNum..GetLanguageStrById(11455) --limitNum == -1 and "" or limitNum - boughtNum .. "/" .. limitNum
    else
        price.alignment = "MiddleCenter"
        price.text = GetLanguageStrById(10526)
        buyInfo.text = GetLanguageStrById(10535).."<color=red>"..limitNum - boughtNum.."</color>"--.. "/" .. limitNum..GetLanguageStrById(11455)
    end

    Util.AddOnceClick(btnBuy, function()
        if not isCanBuy then
            PopupTipPanel.ShowTipByLanguageId(10540)
        else
            --直购商品
            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = data.goodsId }, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(data.goodsId)
                    CheckRedPointStatus(RedPointType.EveryWeekPreference)
                    CheckRedPointStatus(RedPointType.EveryMonthPreference)
                    self:RefreshGiftData()
                    CheckRedPointStatus(RedPointType.DailyGift)                   
                end)
            else
                NetManager.RequestBuyGiftGoods(data.goodsId, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(data.goodsId)                   
                    self:RefreshGiftData()
                    CheckRedPointStatus(RedPointType.DailyGift)                   
                end)
            end    
        end
    end)
end

function WeekMonthGiftPackPage:RefreshItem(go, data)
    if self.newItemList[go] then
    else
        self.newItemList[go] = SubUIManager.Open(SubUIConfig.ItemView, go.transform)
    end
    self.newItemList[go]:OnOpen(false, {data[1],data[2]}, 1,false,false,false,self.mainPanel.sortingOrder)
    self.newItemList[go].gameObject:SetActive(true)
end

--数据重组
function WeekMonthGiftPackPage:ResetShopData(shopData)
    local newData = {}
    local boughtNum = 0
    local limitNum = 0
    if extra == 1 then
        for i = 1, #shopData do
            if rechargeCommodityConfig[shopData[i].goodsId].ShowType == DirectBuyType.WEEK_GIFT then
                boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, shopData[i].goodsId)
                limitNum = rechargeCommodityConfig[ shopData[i].goodsId].Limit
                local curSortId = 0--临时一个数值 只用做排序用
                if limitNum == -1 then
                    curSortId = 2
                elseif limitNum - boughtNum  > 0 then
                    curSortId = 1
                end
                newData[#newData + 1] = {data = shopData[i],sortId = curSortId,sequence=rechargeCommodityConfig[shopData[i].goodsId].Sequence}
            end
        end
    elseif extra == 2 then
        for i = 1, #shopData do
            if rechargeCommodityConfig[shopData[i].goodsId].ShowType == DirectBuyType.MONTH_GIFT then
                boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, shopData[i].goodsId)
                limitNum = rechargeCommodityConfig[ shopData[i].goodsId].Limit
                local curSortId = 0--临时一个数值 只用做排序用
                if limitNum == -1 then
                    curSortId = 2
                elseif limitNum - boughtNum  > 0 then
                    curSortId = 1
                end
                newData[#newData + 1] = {data = shopData[i],sortId = curSortId,sequence=rechargeCommodityConfig[shopData[i].goodsId].Sequence}
            end
        end
    end
    return newData
end

--每种礼包的剩余时间
function WeekMonthGiftPackPage:GetRemainTime()
    local localSelf = self
    local freshTime = 0
    --所有直购在一起  取相应类型直购第一个时间显示倒计时
    local  datalist = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)
    if extra == 1 then
        for i = 1, #datalist do
            if rechargeCommodityConfig[datalist[i].goodsId].ShowType == DirectBuyType.WEEK_GIFT then
                if freshTime <= 0 then
                    freshTime = datalist[i].endTime
                end
            end
        end
    elseif extra == 2 then
        for i = 1, #datalist do
            if rechargeCommodityConfig[datalist[i].goodsId].ShowType == DirectBuyType.MONTH_GIFT then
                if freshTime <= 0 then
                    freshTime = datalist[i].endTime
                end
            end
        end
    end

    if freshTime and freshTime > 0 then
    else
        return
    end

    local UpDate = function()
        if not localSelf.localTimer then
            return
        end
        if IsNull(self.endTime) then
            return
        end
       local showfreshTime = freshTime - GetTimeStamp()
        if showfreshTime > 0 then
            -- 剩余小时
            local formatTime, leftHour = TimeToHMS(showfreshTime)
            if leftHour > 24 then
                self.endTime.text = GetLanguageStrById(10028)..TimeToDH(showfreshTime)
            else
                self.endTime.text = GetLanguageStrById(10028)..TimeToMS(showfreshTime)
            end
        elseif showfreshTime <= 0 then
            -- 时间到刷一下数据
            self:RefreshGiftData(self.choooseTab)
            self.endTime.text = ""
        end
    end
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
    if not self.localTimer then
        self.localTimer = Timer.New(UpDate, 1, -1, true)
        self.localTimer:Start()
    end

    UpDate()
end

function WeekMonthGiftPackPage:OnHide()
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
    self.gameObject:SetActive(false)
end

function WeekMonthGiftPackPage:OnDestroy()
    self.scrollView = nil
    self.scrollView2 = nil
    ClearRedPointObject(RedPointType.EveryWeekPreference)
    ClearRedPointObject(RedPointType.EveryMonthPreference)
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
end
---------------------

function WeekMonthGiftPackPage:OnSortingOrderChange(cursortingOrder)
    for i, v in pairs(self.ItemList) do
        for j = 1, #self.ItemList[i] do
            self.ItemList[i][j]:SetEffectLayer(cursortingOrder)
        end
    end
end

-----------本模块特殊使用-----------
function WeekMonthGiftPackPage:TimeToHMS(t)
    if not t or t < 0 then
        return GetLanguageStrById(11463)
    end
    local _sec = t % 60
    local allMin = math.floor(t / 60)
    local _min = allMin % 60
    local _hour = math.floor(allMin / 60)
    return string.format(GetLanguageStrById(10503), _hour, _min, _sec), _hour, _min, _sec
end

return WeekMonthGiftPackPage