local GiftPackPage = quick_class("GiftPackPage")
local shopItemConfig = ConfigManager.GetConfig(ConfigName.StoreConfig)
local rechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local giftType = {
    [1] = DirectBuyType.DAILY_GIFT,
    [2] = DirectBuyType.WEEK_GIFT,
    [3] = DirectBuyType.MONTH_GIFT,
    [4] = DirectBuyType.FINDTREASURE_GIFT,--SHOP_TYPE.FINDTREASURE_GIFT 第四个页签是由 两个道具商品 和 一个直购商品组成 数据不一样
}
local DataType = {
    Shop = 1,--商品
    Direct = 2,--直购
}

local parent
local noviceScrollViewIndex = 0
local ItemListIndex = 0
--新手礼包标题图片名
local NoviceGiftTitle={"l_lb_mengxin","l_lb_yuanqi","l_lb_chengzahng","l_lb_wushaung","l_lb_rongyao","l_lb_dengfeng"}

function GiftPackPage:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    parent = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
    self.ItemList = {}
    self.NoviceItemList={}
end

function GiftPackPage:InitComponent(gameObject)
    self.itemPre = Util.GetGameObject(gameObject, "rzyBg/ItemPre")
    self.bg = Util.GetGameObject(gameObject, "rzyBg")
    self.dayGiftIcon = Util.GetGameObject(gameObject,"rzyBg/bg/Image (1)")
    self.freeBtn = Util.GetGameObject(gameObject,"rzyBg/freeBtn")
    self.freeBtnAnim = Util.GetGameObject(gameObject,"rzyBg/freeBtn/UI_effect_TanSuo_Box"):GetComponent("Animator")
    self.redPoint = Util.GetGameObject(gameObject,"rzyBg/freeBtn/redPoint")
    self.endTime = Util.GetGameObject(gameObject, "rzyBg/endTime"):GetComponent("Text")
    self.endTimeBg = Util.GetGameObject(gameObject, "rzyBg/bg/Image")
    self.scrollItem = Util.GetGameObject(gameObject, "rzyBg/scrollItem")
    self.lightList = {
        Util.GetGameObject(self.freeBtnAnim.transform,"bg_ray"),
        Util.GetGameObject(self.freeBtnAnim.transform,"yinying/ray 1"),
        Util.GetGameObject(self.freeBtnAnim.transform,"yinying/ray 2"),
        Util.GetGameObject(self.freeBtnAnim.transform,"yinying/ray 3"),
        Util.GetGameObject(self.freeBtnAnim.transform,"yinying/ray 4"),
    }

    self.btnDaily = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/daily")
    self.dailyUnchoose = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/daily/unchoose")
    self.dailyChoose = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/daily/choose")
    self.dailyText = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/daily/Text"):GetComponent("Text")

    self.btnWeek = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/week")
    self.WeekUnchoose = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/week/unchoose")
    self.WeekChoose = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/week/choose")
    self.WeekText = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/week/Text"):GetComponent("Text")

    self.btnMonth = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/month")
    self.MonthUnchoose = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/month/unchoose")
    self.MonthChoose = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/month/choose")
    self.MonthText = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/month/Text"):GetComponent("Text")

    self.btnShop=Util.GetGameObject(gameObject,"rzyBg/btnTypeGroup/shop")
    self.shopUnchoose = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/shop/unchoose")
    self.shopChoose = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/shop/choose")
    self.shopText = Util.GetGameObject(gameObject, "rzyBg/btnTypeGroup/shop/Text"):GetComponent("Text")

    -- 设置循环滚动，万一礼包内容不停地加
    local rootHight = self.scrollItem.transform.rect.height
    local width = self.scrollItem.transform.rect.width
    self.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scrollItem.transform,
            self.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 35))
    self.scrollView.moveTween.MomentumAmount = 1
    self.scrollView.moveTween.Strength = 2

    self.cardTypeBtn = {
        [1] = { btn = self.btnDaily, choose = self.dailyChoose, unchoose = self.dailyUnchoose, text = self.dailyText },
        [2] = { btn = self.btnWeek, choose = self.WeekChoose, unchoose = self.WeekUnchoose, text = self.WeekText },
        [3] = { btn = self.btnMonth, choose = self.MonthChoose, unchoose = self.MonthUnchoose, text = self.MonthText },
        [4] = {btn=self.btnShop,choose=self.shopChoose,unchoose=self.shopUnchoose,text=self.shopText}
    }

    ---新手礼包---
    self.noviceBg=Util.GetGameObject(gameObject,"noviceBg")
    self.giftsGroup=Util.GetGameObject(self.noviceBg,"giftsGroup")
    self.noviceItemPre=Util.GetGameObject(self.noviceBg,"itemPre")
    self.countDown=Util.GetGameObject(self.noviceBg,"countDown"):GetComponent("Text")

    self.noviceScrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,self.giftsGroup.transform,self.noviceItemPre,
    nil,Vector2.New(self.giftsGroup.transform.rect.width,self.giftsGroup.transform.rect.height),1,1,Vector2.New(0,25))
    self.noviceScrollView.moveTween.MomentumAmount = 1
    self.noviceScrollView.moveTween.Strength = 2
end

function GiftPackPage:BindEvent()
    for type = 1, 4 do
        Util.AddClick(self.cardTypeBtn[type].btn, function()
            -- 选择的直购没开，则直接返回    4 时有商品和直购
            local curDataIsActive = false
            local allDatas = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)
            for i = 1, #allDatas do
                if rechargeCommodityConfig[allDatas[i].goodsId].ShowType == giftType[type] then
                    curDataIsActive = true
                end
            end
            if type ~= 4 then
                if not curDataIsActive then
                    PopupTipPanel.ShowTipByLanguageId(11448)
                    return
                end
            else
                if not ShopManager.IsActive(SHOP_TYPE.FINDTREASURE_GIFT) and not curDataIsActive then
                    PopupTipPanel.ShowTipByLanguageId(11448)
                    return
                end
            end
            -- 点击已经选择的界面，则不刷新
            if type == self.choooseTab then
                return
            end
            self:RefreshData(type)
            -- 刷新页签
            self:RefreshBtnShow(type)
            self.scrollView:SetIndex(1)
        end)
    end
end

local sortingOrder = 0
local extra=nil
function GiftPackPage:OnShow(_sortingOrder,extraTab)
    sortingOrder = _sortingOrder
    extra=extraTab
    self:OnShowPanelData()
end

function GiftPackPage:OnShowPanelData()
    self.gameObject:SetActive(true)
    ShopManager.isOpenNoviceGift=true
    CheckRedPointStatus(RedPointType.DailyGift)
    if ShopManager.IsActive(SHOP_TYPE.NOVICE_GIFT_SHOP) and ShopManager.CheckNoviceGiftData() then
        --新手礼包
        self.bg:SetActive(false)
        self.noviceBg:SetActive(true)
        self:SetNoviceGiftData()
        self.noviceScrollView:SetIndex(1)
    else
        --日周月礼包
        BindRedPointObject(RedPointType.DailyGift, Util.GetGameObject(self.btnDaily, "redPoint"))
        self.bg:SetActive(true)
        self.noviceBg:SetActive(false)
        self:RefreshData(extra and extra or 1)
        self:RefreshBtnShow(extra and extra or 1)
    end
end

function GiftPackPage:OnSortingOrderChange(cursortingOrder)
    for i, v in pairs(self.ItemList) do
        for j = 1, #self.ItemList[i] do
            self.ItemList[i][j]:SetEffectLayer(cursortingOrder)
        end
    end
    for i, v in pairs(self.NoviceItemList) do
        for j = 1, #self.NoviceItemList[i] do
            self.NoviceItemList[i][j]:SetEffectLayer(cursortingOrder)
        end
    end
end

-- 根据选择的页签刷新数据
function GiftPackPage:RefreshData(type)
    -- 当前选中的页签
    self.choooseTab = type
    CheckRedPointStatus(RedPointType.GrowthPackage)
    -- 刷新商品数据
    self:RefreshGiftData(type)
    -- 刷新剩余时间
    self:GetRemainTime()
end

-- 刷新礼包的数据
function GiftPackPage:RefreshGiftData(type)
    local shopData = {}
    if type ~= 4 then
        --这个界面  普通商品只有  GoodsTypeDef.DirectPurchaseGift
        shopData = self:ResetShopData(OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift), type,DataType.Direct)
        table.sort(shopData,function(a,b)
            if a.sortId == b.sortId then
                return a.data.goodsId < b.data.goodsId
            else
                return a.sortId > b.sortId
            end
        end)
    else
        --两部分组成 寻宝特权在商品里 极速探索礼包在直购里
        local topspeedData = self:ResetShopData(ShopManager.GetShopDataByType(SHOP_TYPE.FINDTREASURE_GIFT).storeItem, type,DataType.Shop)
         shopData = self:ResetShopData(OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift), type,DataType.Direct)
        for i = 1, #topspeedData do
            table.insert(shopData,topspeedData[i])
        end
        table.sort(shopData,function(a,b)
            return a.sortId < b.sortId
        end)
    end
    local callBack = function(index, item)
        ItemListIndex = index
        self:RefreshShowData(item, shopData[index].data, type, shopData[index].DataType)
    end
    self.scrollView:SetData(shopData, callBack)

    self:RefreshFreeData(type)
end

-- 商店数据重组
function GiftPackPage:ResetShopData(shopData, type,DataTypeIndex)
    local newData = {}
    local boughtNum = 0
    local limitNum = 0
    for i = 1, #shopData do
        if DataTypeIndex == DataType.Shop then
            boughtNum = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FINDTREASURE_GIFT, shopData[i].id)
            limitNum = ShopManager.GetShopItemLimitBuyCount(shopData[i].id)
            local curSortId = 0--临时一个数值 只用做排序用
            if limitNum == -1 then
                curSortId = 3
            elseif limitNum - boughtNum  > 0 then
                curSortId = 2
            end
            --DataTypeIndex  1 商品 2 直购商品
            newData[#newData + 1] = {data = shopData[i],DataType = DataTypeIndex,sortId = curSortId}
        elseif DataTypeIndex == DataType.Direct then
            --所有直购 进行筛选 类型一致的取出
            if rechargeCommodityConfig[shopData[i].goodsId].ShowType == giftType[type] then
                boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, shopData[i].goodsId)
                limitNum = rechargeCommodityConfig[ shopData[i].goodsId].Limit
                local curSortId = 0--临时一个数值 只用做排序用
                if limitNum == -1 then
                    curSortId = 2
                elseif limitNum - boughtNum  > 0 then
                    curSortId = 1
                end
                --DataTypeIndex  1 商品 2 直购商品
                newData[#newData + 1] = {data = shopData[i],DataType = DataTypeIndex,sortId = curSortId}
            end
        end
    end
    return newData
end

--每种礼包的剩余时间
function GiftPackPage:GetRemainTime()
    self.endTimeBg:SetActive(self.choooseTab ~= 4)--页签四 没有倒计时
    if self.choooseTab == 4 then
        if self.localTimer then
            self.localTimer:Stop()
            self.localTimer = nil
        end
        self.endTime.text= ""
        return
    end--特权不显示时间
    local localSelf = self
    local freshTime = 0
    --所有直购在一起  取相应类型直购第一个时间显示倒计时
    local  datalist = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)
    for i = 1, #datalist do
        if rechargeCommodityConfig[datalist[i].goodsId].ShowType == giftType[self.choooseTab] then
            if freshTime <= 0 then
                freshTime = datalist[i].endTime
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
       local showfreshTime = freshTime - GetTimeStamp()
        --if freshType == 1 then
        --    freshTime = ShopManager.GetShopCloseTime(shopType)
        --else
        --    freshTime = ShopManager.GetShopRefreshLeftTime(shopType)
        --end
        if showfreshTime > 0 then
            -- 剩余小时
            local formatTime, leftHour = TimeToHMS(showfreshTime)
            if leftHour > 24 then
                self.endTime.text = GetLanguageStrById(11449)..TimeToDHMS(showfreshTime)
            else
                self.endTime.text = GetLanguageStrById(11449)..self:TimeToHMS(showfreshTime)
            end
        elseif showfreshTime == 0 then
            -- 时间到刷一下数据

            self:RefreshGiftData(self.choooseTab)
        elseif showfreshTime==-1 then --不刷新显示内容
            self.endTime.text=""
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

--刷新每日免费礼包
function GiftPackPage:RefreshFreeData(type)

    local isDaily = type == DirectBuyType.DAILY_GIFT
    self.freeBtn:SetActive(isDaily)
    self.dayGiftIcon:SetActive(isDaily)
    

    local freeData=ShopManager.GetShopDataByType(SHOP_TYPE.FREE_GIFT).storeItem
    local boughtNum = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FREE_GIFT, freeData[1].id)
    local limitNum = ShopManager.GetShopItemLimitBuyCount(freeData[1].id)
    local isCanBuy = false--limitNum - boughtNum >= 1
    self.freeBtnAnim.enabled=isCanBuy
    self.redPoint:SetActive(isCanBuy)
    -- 光效显隐
    for _, light in ipairs(self.lightList) do
        light:SetActive(isCanBuy)
    end

    local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FREE_GIFT, freeData[1].id, 1)
    CheckRedPointStatus(RedPointType.DailyGift)
    Util.AddOnceClick(self.freeBtn,function()
        if isCanBuy then
            self:BuyAction(costId, finalNum, SHOP_TYPE.FREE_GIFT, freeData[1].id, type)
        end
    end)
end

--刷新每一条的显示数据
function GiftPackPage:RefreshShowData(item, data, type, DataTypeIndex)
    --绑定组件
    local name = Util.GetGameObject(item, "context/text"):GetComponent("Text")
    local tip1=Util.GetGameObject(item,"tip/tip1"):GetComponent("Image")
    local tip1Text1=Util.GetGameObject(item,"tip/tip1/text1"):GetComponent("Text")
    local tip1Text2=Util.GetGameObject(item,"tip/tip1/text2"):GetComponent("Text")
    local tip2=Util.GetGameObject(item,"tip/tip2"):GetComponent("Image")
    local tip2Text=Util.GetGameObject(item,"tip/tip2/text"):GetComponent("Text")
    local icon = Util.GetGameObject(item, "btnBuy/icon")
    local price = Util.GetGameObject(item, "btnBuy/price"):GetComponent("Text")
    local buyInfo = Util.GetGameObject(item, "buyInfo"):GetComponent("Text")
    local btnBuy = Util.GetGameObject(item, "btnBuy")
    local grid = Util.GetGameObject(item, "scrollView/grid")
    local shadow=Util.GetGameObject(item,"shadow")
    local tipImage=Util.GetGameObject(item,"tipImage")
    local tipImageText=Util.GetGameObject(item,"tipImage/Text"):GetComponent("Text")
    --local redPoint = Util.GetGameObject(btnBuy, "redPoint")

    -- 物品Item
    local shows
    local shopItemData
    -- 购买数量与限购数量
    local boughtNum = 0
    local limitNum = 0
    local costId, finalNum, oriCostNum
    --道具商品 和 直购商品  获取数据的地方不一致
    if DataTypeIndex == DataType.Shop then
        shopItemData = shopItemConfig[data.id]
        --shows = ShopManager.GetShopItemGoodsInfo(data.id)
        shows = shopItemData.Goods
        name.text = GetLanguageStrById(shopItemData.GoodsName)
        -- 设置立赠提示
        tip1.gameObject:SetActive(shopItemData.Goods[1][1] == 16 )
        tip2.gameObject:SetActive(shopItemData.Goods[1][1] ~= 16)
        tip1Text1.text=shopItemData.Goods[1][2]
        tip1Text2.text=shopItemData.Rebate
        tip2Text.text=shopItemData.Rebate
        boughtNum = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FINDTREASURE_GIFT, data.id)
        limitNum = ShopManager.GetShopItemLimitBuyCount(data.id)
        costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FINDTREASURE_GIFT, data.id, 1)
        tipImage:SetActive(type == 4)
        if type == 4 then
            tipImageText.text = GetLanguageStrById(11451)
        end
    else
        shopItemData = rechargeCommodityConfig[data.goodsId]
        --shows = OperatingManager.GetGiftGoodsInfo(giftType[type], data.id)
        shows = shopItemData.RewardShow
        name.text = shopItemData.Name
        -- 设置立赠提示
        tip1.gameObject:SetActive(shopItemData.RewardShow[1][1] == 16 )
        tip2.gameObject:SetActive(shopItemData.RewardShow[1][1] ~= 16)
        tip1Text1.text=shopItemData.RewardShow[1][2]
        tip1Text2.text=shopItemData.Rebate
        tip2Text.text=shopItemData.Rebate
        boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, data.goodsId)
        limitNum = shopItemData.Limit
        --limitNum = OperatingManager.GetLeftBuyTime(GoodsTypeDef.DirectPurchaseGift,data.goodsId)
        costId, finalNum, oriCostNum = nil,shopItemData.Price,nil
        tipImage:SetActive(type == 4)
        if type == 4 then
            tipImageText.text = GetLanguageStrById(11452)
        end
    end

    --滚动条复用重设itemview
    if self.ItemList[item] then
        for i = 1, 4 do
            self.ItemList[item][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            if self.ItemList[item][i] then
                self.ItemList[item][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.9,false,false,false,sortingOrder)
                self.ItemList[item][i].gameObject:SetActive(true)
            end
        end
    else
        self.ItemList[item]={}
        for i = 1, 4 do
            self.ItemList[item][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            self.ItemList[item][i].gameObject:SetActive(false)
            local obj= newObjToParent(shadow,self.ItemList[item][i].transform)
            obj.transform:SetAsFirstSibling()
            obj.transform:DOAnchorPos(Vector3(0,-3,0),0)
            obj:GetComponent("RectTransform").transform.localScale=Vector3.one*1.1
            obj.gameObject:SetActive(true)
        end
        for i = 1, #shows do
            self.ItemList[item][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.9,false,false,false,sortingOrder)
            self.ItemList[item][i].gameObject:SetActive(true)
        end
    end


    -- 设置按钮状态
    local isCanBuy = limitNum - boughtNum >0
    btnBuy:GetComponent("Button").interactable = isCanBuy
    Util.SetGray(btnBuy,not isCanBuy)
    icon:GetComponent("Image").enabled=isCanBuy
    icon:SetActive(isCanBuy)
    if isCanBuy then
        if DataTypeIndex == DataType.Shop then
            icon:SetActive(true)
            icon:GetComponent("Image").sprite = SetIcon(shopItemData.Cost[1][1])
            price.alignment="MiddleRight"
            --根据数字位数做效果适配
            local str=""
            local index= string.len(tostring(finalNum))
            if index<=2 then
                str="   "
            elseif index>2 and index<=4 then
                str="  "
            else
                str=" "
            end
            price.text = finalNum--..str
        else
            local str=""
            local index= string.len(tostring(finalNum))
            if index<=1 then
                str="   "
            elseif index>=2 and index<4 then
                str="  "
            else
                str=" "
            end
            icon:SetActive(false)
            price.text = finalNum..GetLanguageStrById(11453)--..str
        end
        buyInfo.text = GetLanguageStrById(11454)..limitNum - boughtNum .. "/" .. limitNum..GetLanguageStrById(11455) --limitNum == -1 and "" or limitNum - boughtNum .. "/" .. limitNum
    else
        price.alignment="MiddleCenter"
        price.text=GetLanguageStrById(10526)
        buyInfo.text=GetLanguageStrById(11454).."<color=red>"..limitNum - boughtNum.."</color>".. "/" .. limitNum..GetLanguageStrById(11455)
    end
    -- 红点
    --redPoint:SetActive(finalNum == 0 and isCanBuy)
    -- 请求购买
    Util.AddOnceClick(btnBuy, function()
        if not isCanBuy then
            PopupTipPanel.ShowTipByLanguageId(10540)
        else
            --道具商品
            if DataTypeIndex == DataType.Shop then
                self:BuyAction(costId, finalNum, SHOP_TYPE.FINDTREASURE_GIFT, data.id, type)
            else
                --直购商品
                if AppConst.isSDKLogin then
                    PayManager.Pay({ Id = data.goodsId }, function()
                        FirstRechargeManager.RefreshAccumRechargeValue(data.goodsId)
                        OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, data.goodsId)
                        self:RefreshGiftData(type)
                        CheckRedPointStatus(RedPointType.DailyGift)
                    end)
                else
                    NetManager.RequestBuyGiftGoods(data.goodsId, function()
                        FirstRechargeManager.RefreshAccumRechargeValue(data.goodsId)
                        OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, data.goodsId)
                        self:RefreshGiftData(type)
                        CheckRedPointStatus(RedPointType.DailyGift)
                    end)
                end
            end
        end
    end)
end


--购买点击事件
function GiftPackPage:BuyAction(costId, costNum, shopType, itemId, tabType)
    local haveNum = BagManager.GetItemCountById(costId)
    local costName = ConfigManager.GetConfigData(ConfigName.ItemConfig, costId).Name

    if haveNum < costNum then
        NotEnoughPopup:Show(costId)
    else
        local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. shopType)
        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
        if (isPopUp ~= currentTime and costNum ~= 0) then
            local str = string.format(GetLanguageStrById(11457), costNum, costName)
            MsgPanel.ShowTwo(str, function()
            end, function(isShow)
                if (isShow) then
                    local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                    RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. shopType, currentTime)
                end
                ShopManager.RequestBuyShopItem(shopType, itemId, 1, function()
                    self:RefreshGiftData(tabType)
                    CheckRedPointStatus(RedPointType.DailyGift)

                end) end, GetLanguageStrById(10719), GetLanguageStrById(10720),nil,true)
        else
            ShopManager.RequestBuyShopItem(shopType, itemId, 1, function()
                self:RefreshGiftData(tabType)
                CheckRedPointStatus(RedPointType.DailyGift)
            end)
        end

    end
end

local btnText = {
    [1] = GetLanguageStrById(11458),
    [2] = GetLanguageStrById(11459),
    [3] = GetLanguageStrById(11460),
    [4] = GetLanguageStrById(11461),
}

-- 刷新页签按钮显示
function GiftPackPage:RefreshBtnShow(type)
    for i = 1, 4 do
        local btnInfo = self.cardTypeBtn[i]
        btnInfo.choose:SetActive(i == type)
        btnInfo.unchoose:SetActive(i ~= type)
        local color = i == type and "D7D7BF" or "473F3C"
        btnInfo.text.text = string.format("<color=#%s>%s</color>", color, btnText[i])
    end
end

function GiftPackPage:OnHide()
    self.gameObject:SetActive(false)
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
    if self.noviceTimer then
        self.noviceTimer:Stop()
        self.noviceTimer = nil
    end
end

function GiftPackPage:OnDestroy()
    ClearRedPointObject(RedPointType.DailyGift)
    self.scrollView=nil
    self.noviceScrollView=nil
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
end
---------------------

-------新手礼包-------
--打开界面设置新手礼包数据
function GiftPackPage:SetNoviceGiftData()
    --倒计时
    local time=1
    time=ShopManager.GetShopCloseTime(SHOP_TYPE.NOVICE_GIFT_SHOP)
    self.countDown.text=TimeToDHMS(time)..GetLanguageStrById(11462)
    if not self.noviceTimer then
        self.noviceTimer=Timer.New(function()
            if time<1 then
                time=0
                self.noviceTimer:Stop()
                self.noviceBg:SetActive(false)
                self.bg:SetActive(true)
            end
            time=ShopManager.GetShopCloseTime(SHOP_TYPE.NOVICE_GIFT_SHOP)
            self.countDown.text=TimeToDHMS(time)..GetLanguageStrById(11462)
        end,1,-1,true)
    end
    self.noviceTimer:Start()

    --重组数据
    local noviceData = {}
    local data=self:ResetNoviceGiftData(ShopManager.GetShopDataByType(SHOP_TYPE.NOVICE_GIFT_SHOP).storeItem,SHOP_TYPE.NOVICE_GIFT_SHOP)

    for i, v in ipairs(data) do
        table.insert(noviceData,{shopItemConfig[v.id],v.buyNum})--组装数据
    end

    --设置滚动条数据
    self.noviceScrollView:SetData(noviceData,function(index,root)
        noviceScrollViewIndex = index
        self:ShowNoviceGiftData(root,noviceData[index],index)
    end)
end

--显示每一条数据
function GiftPackPage:ShowNoviceGiftData(root,data,index)
    local bg=Util.GetGameObject(root,"bg"):GetComponent("Image")
    local title=Util.GetGameObject(root,"title"):GetComponent("Image")
    local itemGroup=Util.GetGameObject(root,"itemGroup")
    local returnProportion=Util.GetGameObject(root,"returnProportion/Text"):GetComponent("Text")
    local buyBtn=Util.GetGameObject(root,"buyBtn")
    local icon=Util.GetGameObject(buyBtn,"icon"):GetComponent("Image")
    local price=Util.GetGameObject(buyBtn,"price"):GetComponent("Text")
    local shows = ShopManager.GetShopItemGoodsInfo(data[1].Id)
    local shadow=Util.GetGameObject(root,"shadow")

    for i = 1, #NoviceGiftTitle do
        if data[1].Sort==i then
            bg.sprite=Util.LoadSprite("l_lb_"..i)
            title.sprite=Util.LoadSprite(NoviceGiftTitle[i])
            title:SetNativeSize()
        end
    end
    returnProportion.text=data[1].Rebate

    --滚动条复用重设itemview
    if self.NoviceItemList[root] then
        for i = 1, 4 do
            self.NoviceItemList[root][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            if self.NoviceItemList[root][i] then
                self.NoviceItemList[root][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.9,false,false,false,sortingOrder)
                self.NoviceItemList[root][i].gameObject:SetActive(true)
            end
        end
    else
        self.NoviceItemList[root]={}
        for i = 1, 4 do
            self.NoviceItemList[root][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
            self.NoviceItemList[root][i].gameObject:SetActive(false)
            local obj= newObjToParent(shadow,self.NoviceItemList[root][i].transform)
            obj.transform:SetAsFirstSibling()
            obj.transform:DOAnchorPos(Vector3(0,-3,0),0)
            obj:GetComponent("RectTransform").transform.localScale=Vector3.one*1.15
            obj.gameObject:SetActive(true)
        end
        for i = 1, #shows do
            self.NoviceItemList[root][i]:OnOpen(false, {shows[i][1],shows[i][2]}, 0.9,false,false,false,sortingOrder)
            self.NoviceItemList[root][i].gameObject:SetActive(true)
        end
    end

    if data[2]==0 then
        buyBtn:GetComponent("Button").interactable=true
        icon.sprite=SetIcon(data[1].Cost[1][1])
        price.text="   "..CalculateCostCount(1,data[1].Cost[2])
    else
        buyBtn:GetComponent("Button").interactable=false
        icon.gameObject:SetActive(false)
        price.text=GetLanguageStrById(10526)
    end

    Util.AddOnceClick(buyBtn,function()
        self:NoviceBuyAction(data[1].Cost[1][1],CalculateCostCount(1,data[1].Cost[2]),SHOP_TYPE.NOVICE_GIFT_SHOP,data[1].Id)
    end)
end
--新手礼包购买事件
function GiftPackPage:NoviceBuyAction(costId, costNum, shopType, itemId)
    local haveNum = BagManager.GetItemCountById(costId)
    local costName = ConfigManager.GetConfigData(ConfigName.ItemConfig, costId).Name
    
    if haveNum < costNum then
        NotEnoughPopup:Show(costId)
    else
        local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. shopType)
        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
        if (isPopUp ~= currentTime and costNum ~= 0) then
            local str = string.format(GetLanguageStrById(11457), costNum, costName)
            MsgPanel.ShowTwo(str, function()
            end, function(isShow)
                if (isShow) then
                    local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                    RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. shopType, currentTime)
                end
                ShopManager.RequestBuyShopItem(shopType, itemId, 1, function()
                    self:SetNoviceGiftData()
                    self:RefreshPanel()
                    --CheckRedPointStatus(RedPointType.DailyGift)
                end) end, GetLanguageStrById(10719), GetLanguageStrById(10720),nil,true)
        else
            ShopManager.RequestBuyShopItem(shopType, itemId, 1, function()
                self:SetNoviceGiftData()
                self:RefreshPanel()
                --CheckRedPointStatus(RedPointType.DailyGift)
            end)
        end

    end
end

-- 商店数据重组
function GiftPackPage:ResetNoviceGiftData(shopData, shopType)
    local canBuyData = {}
    local noBuyData = {}
    local newData = {}
    for i = 1, #shopData do
        local boughtNum = ShopManager.GetShopItemHadBuyTimes(shopType, shopData[i].id)
        local limitNum = ShopManager.GetShopItemLimitBuyCount(shopData[i].id)
        if limitNum == -1 or limitNum - boughtNum > 0 then
            canBuyData[#canBuyData + 1] = shopData[i]
        else
            noBuyData[#noBuyData + 1] = shopData[i]
        end
    end

    for i = 1, #canBuyData do
        newData[#newData + 1] = canBuyData[i]
    end

    for i = 1, #noBuyData do
        newData[#newData + 1] = noBuyData[i]
    end
    return newData
end

-- 刷新面板 当新手礼包购买完毕时 刷新到日周月礼包
function GiftPackPage:RefreshPanel()
    if not ShopManager.IsActive(SHOP_TYPE.NOVICE_GIFT_SHOP) or not ShopManager.CheckNoviceGiftData() then
        self:OnShowPanelData()
    end
end

-----------本模块特殊使用-----------
function GiftPackPage:TimeToHMS(t)
    if not t or t < 0 then
        return GetLanguageStrById(11463)
    end
    local _sec = t % 60
    local allMin = math.floor(t / 60)
    local _min = allMin % 60
    local _hour = math.floor(allMin / 60)
    return string.format(GetLanguageStrById(10503), _hour, _min, _sec), _hour, _min, _sec
end
------------------------------
return GiftPackPage