local GiftView = quick_class("GiftView")
local shopItemConfig = ConfigManager.GetConfig(ConfigName.StoreConfig)
local rechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local rechargeNum 

local DataType = {
    Shop = 1,--商品
    Direct = 2,--直购
}
local timerList = {}--时间预设容器

local Title_BG_NAME = {
    [DirectBuyType.DAILY_GIFT] = GetPictureFont("cn2-X1_chongzhi_meirilibao_banner"),
    [DirectBuyType.FINDTREASURE_GIFT] = GetPictureFont("cn2-X1_chongzhi_tequanshangcheng_banner"),
    [SHOP_TYPE.VIP_GIFT] = GetPictureFont("cn2-X1_chongzhi_banner"),--成长礼包
}

function GiftView:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
    self.ItemList = {}
end

function GiftView:InitComponent(gameObject)
    self.itemPre = Util.GetGameObject(gameObject, "Bg/ItemPre")
    self.itemPre2 = Util.GetGameObject(gameObject, "Bg/ItemPre2")
    self.itemPre3 = Util.GetGameObject(gameObject, "Bg/ItemPre3")--成长礼包
    self.bg = Util.GetGameObject(gameObject, "Bg")
    self.titleBg = Util.GetGameObject(gameObject, "Bg/bg"):GetComponent("Image")
    self.dayGiftIcon = Util.GetGameObject(gameObject,"Bg/freeBtn/yilingqu")
    self.freeBtn = Util.GetGameObject(gameObject,"Bg/freeBtn")
    self.redPoint = Util.GetGameObject(gameObject,"Bg/freeBtn/redPoint")
    self.endTime = Util.GetGameObject(gameObject, "Bg/endTime"):GetComponent("Text")
    self.endTimeBg = Util.GetGameObject(gameObject, "Bg/endTime")
    self.scroll = Util.GetGameObject(gameObject, "Bg/scroll")
    self.tip3 = Util.GetGameObject(gameObject, "Bg/tip3")
    self.buyAllBtn = Util.GetGameObject(gameObject, "Bg/buyAll/buyAllBtn")
    self.originalPrice = Util.GetGameObject(gameObject,"Bg/buyAll/originalPrice/price"):GetComponent("Text")
    self.price = Util.GetGameObject(gameObject,"Bg/buyAll/totalPrice/price"):GetComponent("Text")
    Util.SetGray(self.buyAllBtn,false)
    self.buyAllBtn:GetComponent("Button").interactable = true

    -- 设置循环滚动，万一礼包内容不停地加
    local rootHight = self.scroll.transform.rect.height
    local width = self.scroll.transform.rect.width
    self.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scroll.transform,
            self.itemPre, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 0))
    self.scrollView.moveTween.MomentumAmount = 1
    self.scrollView.moveTween.Strength = 2

    self.scrollView2 = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scroll.transform,
            self.itemPre2, nil, Vector2.New(width, rootHight), 1, 2, Vector2.New(0, 0))
    self.scrollView2.moveTween.MomentumAmount = 1
    self.scrollView2.moveTween.Strength = 2
    --成长礼包的滚动条
    self.scrollView3 = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scroll.transform,
            self.itemPre3, nil, Vector2.New(width, rootHight), 1, 1, Vector2.New(0, 0))
    self.scrollView3.moveTween.MomentumAmount = 1
    self.scrollView3.moveTween.Strength = 2
end

local ids = {
    [1004] = {
        1001,1002,1003,1005
    },
    [1024] = {
        1021,1022,1023,1025
    }
}

function GiftView:BindEvent()
    Util.AddClick(self.buyAllBtn,function ()
        local id = GiftView:GetBuyAllId()
        if AppConst.isSDKLogin then
            PayManager.Pay({ Id = id }, function()
                FirstRechargeManager.RefreshAccumRechargeValue(id)
                PlayerPrefs.SetInt(PlayerManager.uid.."czlb", 0)
                CheckRedPointStatus(RedPointType.DailyGift)
                CheckRedPointStatus(RedPointType.GrowthPackage)
                timerList = {}
                for i = 1, 4 do
                    OperatingManager.MyRefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, ids[id][i], 1)
                end
                self:RefreshGiftData()
            end)
        else
            NetManager.RequestBuyGiftGoods(id, function()
                FirstRechargeManager.RefreshAccumRechargeValue(id)
                PlayerPrefs.SetInt(PlayerManager.uid.."czlb", 0)
                CheckRedPointStatus(RedPointType.DailyGift)
                CheckRedPointStatus(RedPointType.GrowthPackage)
                for i = 1, 4 do
                    OperatingManager.MyRefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, ids[id][i], 1)
                end
                self:RefreshGiftData()
            end)
        end
    end)
end

function GiftView:GetBuyAllId()
    local lv = PlayerManager.level
    local config = G_RechargeCommodityConfig[1004]
    if config and lv >= config.LevelLinit[1] and lv <= config.LevelLinit[2] then
        return 1004
    end
    return 1024
end

function GiftView:OnShow(_sortingOrder, buyType)
    rechargeNum = VipManager.GetChargedNum()--已经充值的金额
    local id = GiftView:GetBuyAllId()
    self.originalPrice.text = MoneyUtil.GetMoney(ConfigManager.TryGetConfigData(ConfigName.RechargeCommodityConfig,id).Rebate)
    self.price.text = MoneyUtil.GetMoney(ConfigManager.TryGetConfigData(ConfigName.RechargeCommodityConfig,id).Price)
    self:RefreshData(buyType)
end

function GiftView:AddListener()
end

function GiftView:RemoveListener()
end

function GiftView:OnSortingOrderChange(cursortingOrder)
    for i, v in pairs(self.ItemList) do
        for j = 1, #self.ItemList[i] do
            self.ItemList[i][j]:SetEffectLayer(cursortingOrder)
        end
    end
end

------日周月礼包------
-- 根据选择的页签刷新数据
function GiftView:RefreshData(buyType)
    -- 当前选中的页签
    self.buyType = buyType
    self.titleBg.sprite = Util.LoadSprite(Title_BG_NAME[buyType])
    CheckRedPointStatus(RedPointType.GrowthPackage)
    -- 刷新商品数据
    self:RefreshGiftData()
    -- 刷新剩余时间
    self:GetRemainTime()
end

-- 刷新礼包的数据
function GiftView:RefreshGiftData()
    self:isBought()
    self.scrollView.gameObject:SetActive(false)
    self.scrollView2.gameObject:SetActive(false)
    self.scrollView3.gameObject:SetActive(false)--成长礼包
    local shopData = {}
    if self.buyType ~= DirectBuyType.FINDTREASURE_GIFT and self.buyType ~= SHOP_TYPE.VIP_GIFT then--充值+每日礼包界面
        --这个界面  普通商品只有  GoodsTypeDef.DirectPurchaseGift
        shopData = self:ResetShopData(OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift), self.buyType, DataType.Direct)

        table.sort(shopData,function(a,b)
            if a.sortId == b.sortId then
                return a.data.goodsId < b.data.goodsId
            else
                return a.sortId > b.sortId
            end
        end)

        self.scrollView:SetData(shopData, function (index, item)
            self:RefreshShowData(item, shopData[index].data, self.buyType, shopData[index].DataType)
        end)
        self.scrollView.gameObject:SetActive(true)

    elseif self.buyType == DirectBuyType.FINDTREASURE_GIFT then--特权礼包界面
        --两部分组成 寻宝特权在商品里 极速探索礼包在直购里
        --（24暂时关闭）
        local topspeedData = self:ResetShopData(ShopManager.GetShopDataByType(SHOP_TYPE.FINDTREASURE_GIFT).storeItem, self.buyType, DataType.Shop)
        if RECHARGEABLE then--（是否开启充值）
            shopData = self:ResetShopData(OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift), self.buyType, DataType.Direct)
            
            --俱乐部礼包
            local data = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.ClubGiftPack)
            if data and #data > 0 then
                local boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.ClubGiftPack, data[1].goodsId)
                local limitNum = rechargeCommodityConfig[data[1].goodsId].Limit
                local curSortId = 0--临时一个数值 只用做排序用
                if limitNum == -1 then
                    curSortId = 2
                elseif limitNum - boughtNum  > 0 then
                    curSortId = 1
                end
                shopData[#shopData + 1] = {data = data[1], DataType = DataType.Direct, sortId = curSortId}
            end
        end

        for i = 1, #topspeedData do
            table.insert(shopData,topspeedData[i])
        end
        table.sort(shopData,function(a,b)
            if a.DataType == DataType.Shop and b.DataType == DataType.Shop then
                local dataA = a.data
                local boughtNumA = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FINDTREASURE_GIFT, dataA.id)
                local limitNumA = ShopManager.GetShopItemLimitBuyCount(dataA.id)
                local canBuyA = limitNumA - boughtNumA > 0
                local dataB = b.data
                local boughtNumB =  ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FINDTREASURE_GIFT, dataB.id)
                local limitNumB =  ShopManager.GetShopItemLimitBuyCount(dataB.id)
                local canBuyB = limitNumB - boughtNumB > 0
                if canBuyA and canBuyB then
                    return a.sortId > b.sortId
                else
                    return a.sortId > b.sortId
                end
            elseif (a.DataType == DataType.Shop and b.DataType ~= DataType.Shop) or (a.DataType ~= DataType.Shop and b.DataType == DataType.Shop)then
                if a.DataType == DataType.Shop then
                    local dataA = a.data
                    local boughtNumA = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FINDTREASURE_GIFT, dataA.id)
                    local limitNumA = ShopManager.GetShopItemLimitBuyCount(dataA.id)
                    local canBuyA = limitNumA - boughtNumA > 0

                    local dataB = b.data
                    local boughtNumB = OperatingManager.GetGoodsBuyTime(rechargeCommodityConfig[dataB.goodsId].Type, dataB.goodsId)
                    local limitNumB = rechargeCommodityConfig[dataB.goodsId].Limit
                    local canBuyB = limitNumB - boughtNumB > 0
                    if canBuyA and canBuyB then
                        return a.sortId < b.sortId
                    else
                        return a.sortId > b.sortId
                    end
                else
                    local dataA = a.data
                    local boughtNumB = OperatingManager.GetGoodsBuyTime(rechargeCommodityConfig[dataA.goodsId].Type, dataA.goodsId)
                    local limitNumB = rechargeCommodityConfig[dataA.goodsId].Limit
                    local canBuyA = limitNumB - boughtNumB > 0

                    local dataB = b.data
                    local boughtNumB = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FINDTREASURE_GIFT, dataB.id)
                    local limitNumB = ShopManager.GetShopItemLimitBuyCount(dataB.id)
                    local canBuyB = limitNumB - boughtNumB > 0

                    if canBuyA and canBuyB then
                        return a.sortId < b.sortId
                    else
                        return a.sortId > b.sortId
                    end
                end
            else
                if a.sortId == b.sortId then
                    return a.data.goodsId < b.data.goodsId
                else
                    return a.sortId > b.sortId
                end
            end
        end)

        self.scrollView2:SetData(shopData, function (index,item)
            self:RefreshShowData(item, shopData[index].data, self.buyType, shopData[index].DataType)
        end)
        GiftView:TimeCountDown()
        self.scrollView2.gameObject:SetActive(true)
    elseif self.buyType == SHOP_TYPE.VIP_GIFT then--成长礼包界面
        --每次重新登录会显示红点
        PlayerPrefs.SetInt(PlayerManager.uid.."czlb", 1)
        shopData = self:ResetShopData(ShopManager.GetShopDataByType(SHOP_TYPE.VIP_GIFT).storeItem, self.buyType, DataType.Shop)

        --如果未达到充值要求不显示某些档位商品
        for i = 1, #shopData do
            if rechargeNum < shopItemConfig[shopData[i].data.id].ShowRule[2] then
                shopData[i] = nil
            end
        end
        --(礼包类型-成长礼包，页面的类型-SHOP_TYPE.VIP_GIFT，商品)
        table.sort(shopData,function(a,b)
            if a.sortId == b.sortId then
                return a.data.id < b.data.id
            end
        end)
        self.scrollView3:SetData(shopData, function (index, item)
            self:RefreshShowData(item, shopData[index].data, self.buyType, shopData[index].DataType)
        end)
        self.scrollView3.gameObject:SetActive(true)
    end

    self:RefreshFreeData()
end

-- 商店数据重组
function GiftView:ResetShopData(shopData, buyType, DataTypeIndex)
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
            newData[#newData + 1] = {data = shopData[i],DataType = DataTypeIndex,sortId = curSortId}
        elseif DataTypeIndex == DataType.Direct then
            --所有直购 进行筛选 类型一致的取出
            if rechargeCommodityConfig[shopData[i].goodsId].ShowType == buyType then
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
function GiftView:GetRemainTime()
    local localSelf = self
    local freshTime = 0--剩余时间

    --成长礼包不显示时间
    local isGrowthGift = self.buyType == SHOP_TYPE.VIP_GIFT
    self.endTimeBg:SetActive(not isGrowthGift)--成长礼包 没有倒计时
    if isGrowthGift then--特权商城界面+成长礼包
        if self.localTimer then
            self.localTimer:Stop()
            self.localTimer = nil
        end
        self.endTime.text = ""
        return
    end

    --特权礼包计时器写入item刷新中了,计时器就停了
    local isPrivilegeGift = self.buyType == DirectBuyType.FINDTREASURE_GIFT
    if isPrivilegeGift then
        self.endTimeBg:SetActive(not isPrivilegeGift)
        self.endTime.text = ""
        self.buyAllBtn:SetActive(not isPrivilegeGift)
    end

    --每日礼包
    local isDailyGift = self.buyType == DirectBuyType.DAILY_GIFT
    if isDailyGift then
        local  datalist = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)
        for i = 1, #datalist do
            if rechargeCommodityConfig[datalist[i].goodsId].ShowType == self.buyType then
                if freshTime <= 0 then
                    freshTime = datalist[i].endTime
                end
            end
        end
    end

    if freshTime and freshTime > 0 then--时间已经耗尽
    else
        return
    end

    local UpDate = function()
        if not localSelf.localTimer then
            return
        end
       local showfreshTime = freshTime - GetTimeStamp()
        if showfreshTime > 0 then
            -- 剩余小时
            local formatTime, leftHour = TimeToHMS(showfreshTime)
            if leftHour > 24 then
                self.endTime.text = GetLanguageStrById(11449)..TimeToDHMS(showfreshTime)--天时分秒
            else
                self.endTime.text = GetLanguageStrById(11449)..self:TimeToHMS(showfreshTime)--时分秒
            end
        elseif showfreshTime == 0 then
            -- 时间到刷一下数据
            self:RefreshGiftData()
        elseif showfreshTime == -1 then --不刷新显示内容
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

--刷新每日免费礼包
function GiftView:RefreshFreeData()
    local isDaily = self.buyType == DirectBuyType.DAILY_GIFT
    self.freeBtn:SetActive(isDaily)
    self.buyAllBtn:SetActive(isDaily)

    local freeData = ShopManager.GetShopDataByType(SHOP_TYPE.FREE_GIFT).storeItem
    local boughtNum = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FREE_GIFT, freeData[1].id)
    local limitNum = ShopManager.GetShopItemLimitBuyCount(freeData[1].id)
    local isCanBuy = limitNum - boughtNum >= 1
    -- self.dayGiftIcon:SetActive(isCanBuy)
    self.redPoint:SetActive(isCanBuy)

    local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FREE_GIFT, freeData[1].id, 1)
    CheckRedPointStatus(RedPointType.DailyGift)
    CheckRedPointStatus(RedPointType.GrowthPackage)

    if isCanBuy then
        self.freeBtn:GetComponent("Image").color = Color.New(255/255,255/255,255/255,255/255)
        self.dayGiftIcon:SetActive(false)
    else
        self.freeBtn:GetComponent("Image").color = Color.New(255/255,255/255,255/255,127/255)
        self.dayGiftIcon:SetActive(true)
    end

    Util.AddOnceClick(self.freeBtn,function()
        -- 商品的剩余购买次数
        if isCanBuy then
            self:BuyAction(costId, finalNum, SHOP_TYPE.FREE_GIFT, freeData[1].id)
            self.freeBtn:GetComponent("Image").color = Color.New(255/255,255/255,255/255,127/255)
        else
            PopupTipPanel.ShowTipByLanguageId(23106)
        end
    end)
end

--刷新每一条的显示数据
function GiftView:RefreshShowData(item, data, buyType, DataTypeIndex)
    local name = Util.GetGameObject(item, "context/text"):GetComponent("Text")
    local icon = Util.GetGameObject(item, "btnBuy/icon")
    local price = Util.GetGameObject(item, "btnBuy/price"):GetComponent("Text")
    local buyInfo = Util.GetGameObject(item, "buyInfo"):GetComponent("Text")
    local btnBuy = Util.GetGameObject(item, "btnBuy")
    local grid = Util.GetGameObject(item, "scrollView/grid")
    local tip = Util.GetGameObject(item,"tip")

    -- 设置tip显示
    self:SetTipShow(tip, data, buyType, DataTypeIndex)
    -- 物品Item
    local shows
    local shopItemData
    -- 购买数量与限购数量
    local rechargeNum = VipManager.GetChargedNum()--已经充值的金额
    local boughtNum = 0--已购买数量
    local limitNum = 0--限购
    local costId, finalNum, oriCostNum --ID 现价 原价
    local isPrivilegeGift = buyType == DirectBuyType.FINDTREASURE_GIFT --特权商城
    local isGrowthGift = buyType == SHOP_TYPE.VIP_GIFT --成长礼包
    --道具商品 和 直购商品  获取数据的地方不一致
    if DataTypeIndex == DataType.Shop then
        if isPrivilegeGift then
            shopItemData = shopItemConfig[data.id]
            shows = shopItemData.Goods
            name.text = GetLanguageStrById(shopItemData.GoodsName)
            boughtNum = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.FINDTREASURE_GIFT, data.id)
            limitNum = ShopManager.GetShopItemLimitBuyCount(data.id)
            costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FINDTREASURE_GIFT, data.id, 1)
        elseif isGrowthGift then
            shopItemData = shopItemConfig[data.id]
            shows = shopItemData.Goods--奖励数据
            boughtNum = ShopManager.GetShopItemHadBuyTimes(SHOP_TYPE.VIP_GIFT, data.id)
            limitNum = ShopManager.GetShopItemLimitBuyCount(data.id)
            costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.VIP_GIFT, data.id, 1)
        end
    else
        shopItemData = rechargeCommodityConfig[data.goodsId]
        shows = shopItemData.RewardShow
        name.text = GetLanguageStrById(shopItemData.Name)
        boughtNum = OperatingManager.GetGoodsBuyTime(rechargeCommodityConfig[data.goodsId].Type, data.goodsId)
        limitNum = shopItemData.Limit
        costId, finalNum, oriCostNum = nil, shopItemData.Price, nil
    end

    --为特权商城加的倒计时
    if DataTypeIndex == DataType.Direct and isPrivilegeGift then
        local refreshTime = Util.GetGameObject(item, "time"):GetComponent("Text")
        local freshTime = 0
        local datalist = OperatingManager.GetGiftGoodsInfoList(rechargeCommodityConfig[data.goodsId].Type)

        for i = 1, #datalist do
            if rechargeCommodityConfig[datalist[i].goodsId].Id == data.goodsId then
                if freshTime <= 0 then
                    freshTime = datalist[i].endTime
                    table.insert(timerList,{pre = refreshTime,freshTime = freshTime})
                end
            end
            refreshTime.gameObject:SetActive(freshTime - GetTimeStamp() > 0)
            refreshTime.text = GetLanguageStrById(10561) .. self:SpecialTime(freshTime - GetTimeStamp())
        end
    end

    local scale = 0.5--道具缩放
    if self.buyType == SHOP_TYPE.SOUL_PRINT_SHOP then
        scale = 0.6
    end

    --滚动条复用重设itemview
    if self.ItemList[item] then
        for i = 1, #self.ItemList[item] do
            self.ItemList[item][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            if self.ItemList[item][i] then
                self.ItemList[item][i]:OnOpen(false, {shows[i][1], shows[i][2]}, scale)
                self.ItemList[item][i].gameObject:SetActive(true)
            end
        end
    else
        self.ItemList[item] = {}
        for i = 1, 6 do
            self.ItemList[item][i] = SubUIManager.Open(SubUIConfig.ItemView, grid.transform)
            self.ItemList[item][i].gameObject:SetActive(false)
        end
        for i = 1, #shows do
            self.ItemList[item][i]:OnOpen(false, {shows[i][1], shows[i][2]}, scale)
            self.ItemList[item][i].gameObject:SetActive(true)
        end
    end

    -- 设置按钮状态
    local isCanBuy = limitNum - boughtNum > 0
    btnBuy:GetComponent("Button").interactable = isCanBuy
    Util.SetGray(btnBuy,not isCanBuy)
    icon:GetComponent("Image").enabled = isCanBuy
    icon:SetActive(isCanBuy)
    local nowNum = limitNum - boughtNum
    if nowNum < 0 then nowNum = 0 end

    self.SetTxt = function (_id, _haveColor)
        if _haveColor then
            buyInfo.text = string.format(GetLanguageStrById(_id).." <color=#F94441FF>%s</color> / %s", nowNum, limitNum)
        else
            buyInfo.text = string.format(GetLanguageStrById(_id).." %s / %s", nowNum, limitNum)
        end
    end

    if isPrivilegeGift then
        local commodityIcon = Util.GetGameObject(item, "icon"):GetComponent("Image")
        if DataTypeIndex == DataType.Shop then
            commodityIcon.sprite = Util.LoadSprite(GetResourcePath(shopItemData.ResID))
        else
            commodityIcon.sprite = Util.LoadSprite(GetResourcePath(rechargeCommodityConfig[data.goodsId].Resources))
        end
    end

    if isCanBuy then
        if DataTypeIndex == DataType.Shop then--商品类按钮上的文字位置
            icon:SetActive(true)
            icon:GetComponent("Image").sprite = SetIcon(shopItemData.Cost[1][1])
            price.text = finalNum
            self.SetTxt(11451, false)
        else
            icon:SetActive(false)
            price.text = MoneyUtil.GetMoney(finalNum)
            self.SetTxt(11454, false)
            if isPrivilegeGift then
                if shopItemData.DailyUpdate == 7 then
                    self.SetTxt(11747, false)
                elseif shopItemData.DailyUpdate == 30 then
                    self.SetTxt(11452, false)
                end
            end
            price.text = MoneyUtil.GetMoney(finalNum)
        end
    else
        price.alignment = "MiddleCenter"
        price.text = GetLanguageStrById(10526)
        self.SetTxt(11454, true)
        if DataTypeIndex == DataType.Shop then
            self.SetTxt(11451, true)
        else
            if isPrivilegeGift then
                if shopItemData.DailyUpdate == 7 then
                    self.SetTxt(11747, true)
                elseif shopItemData.DailyUpdate == 30 then
                    self.SetTxt(11452, true)
                end
            end
        end
    end

    if DataTypeIndex == DataType.Shop then
        if limitNum - boughtNum <= 0 then
            Util.GetGameObject(item, "time"):SetActive(false)
        end
    end
    -- 请求购买
    Util.AddOnceClick(btnBuy, function()
        if not isCanBuy then
            PopupTipPanel.ShowTipByLanguageId(10540)
        else
            --道具商品
            if DataTypeIndex == DataType.Shop then
                if buyType == SHOP_TYPE.VIP_GIFT then
                    if rechargeNum >= shopItemConfig[data.id].BuyRule[2] then--充值金额达到要求
                        self:BuyAction(costId, finalNum, SHOP_TYPE.VIP_GIFT, data.id)--成长礼包
                    else--充值金额未达到要求
                        PopupTipPanel.ShowTipByLanguageId(11748)
                    end
                elseif buyType == DirectBuyType.FINDTREASURE_GIFT then
                    self:BuyAction(costId, finalNum, SHOP_TYPE.FINDTREASURE_GIFT, data.id)--特权商城
                end
                CheckRedPointStatus(RedPointType.GrowthPackage)
            else
                --直购商品
                if AppConst.isSDKLogin then
                    PayManager.Pay({ Id = data.goodsId }, function()
                        FirstRechargeManager.RefreshAccumRechargeValue(data.goodsId)
                        PlayerPrefs.SetInt(PlayerManager.uid.."czlb", 0)
                        CheckRedPointStatus(RedPointType.DailyGift)
                        CheckRedPointStatus(RedPointType.GrowthPackage)
                        timerList = {}
                        self:RefreshGiftData()
                    end)
                else
                    NetManager.RequestBuyGiftGoods(data.goodsId, function()
                        FirstRechargeManager.RefreshAccumRechargeValue(data.goodsId)
                        PlayerPrefs.SetInt(PlayerManager.uid.."czlb", 0)
                        CheckRedPointStatus(RedPointType.DailyGift)
                        CheckRedPointStatus(RedPointType.GrowthPackage)
                        timerList = {}
                        self:RefreshGiftData()
                    end)
                end
            end
        end
    end)
end

function GiftView:SetTipShow(tipRoot, data, buyType, DataTypeIndex)
    if buyType == DirectBuyType.DAILY_GIFT then
        local Text1 = Util.GetGameObject(tipRoot, "text1"):GetComponent("Text")
        local Text2 = Util.GetGameObject(tipRoot, "text2"):GetComponent("Text")
        --道具商品 和 直购商品  获取数据的地方不一致
        if DataTypeIndex == DataType.Shop then
            local shopItemData = shopItemConfig[data.id]
            -- 设置立赠提示
            Text1.text = shopItemData.Goods[1][2]
            Text2.text = shopItemData.Rebate
            tipRoot.gameObject:SetActive(shopItemData.Goods[1][1] == 16 )
        else
            local shopItemData = rechargeCommodityConfig[data.goodsId]
            -- 设置立赠提示
            Text1.text = shopItemData.RewardShow[1][2]
            Text2.text = shopItemData.Rebate
            tipRoot.gameObject:SetActive(shopItemData.RewardShow[1][1] == 16 )
        end
    elseif buyType == SHOP_TYPE.VIP_GIFT then
    elseif buyType == DirectBuyType.FINDTREASURE_GIFT then
        local tipText = tipRoot:GetComponent("Text")
        if DataTypeIndex == DataType.Shop then
            local shopItemData = shopItemConfig[data.id]
            if data.id == 20091 then
                tipText.text = GetLanguageStrById(shopItemData.Desc)
            elseif data.id == 20092 then
                tipText.text = GetLanguageStrById(shopItemData.Desc)
            end
        elseif DataTypeIndex == DataType.Direct then
            local shopItemData = rechargeCommodityConfig[data.goodsId]
            if data.goodsId == (4000) or (4001) or (4002) or (4003) or (4004) or (4005) then
                tipText.text = GetLanguageStrById(shopItemData.Desc)
            end
        end
    end
end

--购买点击事件
function GiftView:BuyAction(costId, costNum, shopType, itemId)
    local haveNum = BagManager.GetItemCountById(costId)
    local costName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, costId).Name)
    local icon = ConfigManager.GetConfigData(ConfigName.ItemConfig, costId).ResourceID

    if haveNum < costNum then
        NotEnoughPopup:Show(costId)
    else
        local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. shopType)
        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
        if (isPopUp ~= currentTime and costNum ~= 0) or (shopType == SHOP_TYPE.VIP_GIFT and isPopUp ~= currentTime and costNum ~= 0) then
            local str = string.format(GetLanguageStrById(11457), costNum, costName)
            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Buy, icon,str,function(isShow)
                if isShow then
                    local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                    RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. shopType, currentTime)
                end
                ShopManager.RequestBuyShopItem(shopType, itemId, 1, function()
                    self:RefreshGiftData()
                    CheckRedPointStatus(RedPointType.DailyGift)
                    CheckRedPointStatus(RedPointType.GrowthPackage)
                end)
            end)
            -- MsgPanel.ShowTwo(str, function()
            -- end, function(isShow)
            --     if (isShow) then
            --         local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
            --         RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. shopType, currentTime)
            --     end
            --     ShopManager.RequestBuyShopItem(shopType, itemId, 1, function()
            --         self:RefreshGiftData()
            --         CheckRedPointStatus(RedPointType.DailyGift)
            --         CheckRedPointStatus(RedPointType.GrowthPackage)

            --     end) end, GetLanguageStrById(10719), GetLanguageStrById(10720),nil,true)
        else
            ShopManager.RequestBuyShopItem(shopType, itemId, 1, function()
                self:RefreshGiftData()
                CheckRedPointStatus(RedPointType.DailyGift)
                CheckRedPointStatus(RedPointType.GrowthPackage)
            end)
        end
    end
end

function GiftView:OnHide()
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
    if self.localTimerV2 then
        self.localTimerV2:Stop()
        self.localTimerV2 = nil
    end
    timerList = {}
end

function GiftView:OnDestroy()
    self.scrollView = nil
    self.scrollView2 = nil
    self.scrollView3 = nil

    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end

    ClearRedPointObject(RedPointType.GrowthPackage)
end
---------------------

-----------本模块特殊使用-----------
function GiftView:TimeToHMS(t)
    if not t or t < 0 then
        return GetLanguageStrById(11463)
    end
    local _sec = t % 60
    local allMin = math.floor(t / 60)
    local _min = allMin % 60
    local _hour = math.floor(allMin / 60)
    return string.format(GetLanguageStrById(10503), _hour, _min, _sec), _hour, _min, _sec
end

--特权商城专属
function GiftView:SpecialTime(t)
    if not t or t < 0 then
        return GetLanguageStrById(11749)
    end
    local _sec = t % 60
    local allMin = math.floor(t / 60)
    local _min = allMin % 60
    local allHour = math.floor(t / 3600)
    local _hour = allHour % 24
    local allDays = math.floor(t / 86400)

    if allDays >= 1 then
        return string.format(GetLanguageStrById(11750),allDays),allDays
    else
        if _hour >= 1 then
            return string.format(GetLanguageStrById(11751), _hour), _hour
        else
            if _min >= 1 then
                return string.format(GetLanguageStrById(11752), _min), _min
            end
        end
    end
end

function GiftView:TimeCountDown()
    if self.localTimerV2 ~= nil then
        self.localTimerV2:Stop()
        self.localTimerV2 = nil
    end

    if RECHARGEABLE then--（是否开启充值）
        self.localTimerV2 = Timer.New(function()
            local t1,t2 = timerList[1].freshTime, timerList[2].freshTime
            t1 = t1-1
            t2 = t2-1
            if t1 < 0 then
                -- body刷新
                -- self:RefreshGiftData()
            end
            if t2 < 0 then
                -- body刷新
                -- self:RefreshGiftData()
            end

            timerList[1].pre.text = GetLanguageStrById(10561) .. self:SpecialTime(t1-GetTimeStamp())
            timerList[2].pre.text = GetLanguageStrById(10561) .. self:SpecialTime(t2-GetTimeStamp())
        end,1,-1,true)
        self.localTimerV2:Start()
    end
end

function GiftView:isBought()
    -- local data = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DirectPurchaseGift)
    -- for i = 1, #data do
    --     if rechargeCommodityConfig[data[i].goodsId].ShowType == 14 then
    --         if data[i].buyTimes > 0 then
    --             Util.SetGray(self.buyAllBtn,true)
    --             self.buyAllBtn:GetComponent("Button").interactable = false
    --             break
    --         end
    --     end
    -- end

    local state = true
    local id = GiftView:GetBuyAllId()
    for i = 1, 4 do
        local boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, ids[id][i])
        if boughtNum then
            local limitNum = rechargeCommodityConfig[ids[id][i]].Limit
            local isCanBuy = limitNum - boughtNum > 0
            if not isCanBuy then
                state = false
            end
        end
    end
    Util.SetGray(self.buyAllBtn, not state)
    self.buyAllBtn:GetComponent("Button").interactable = state
end

------------------------------
return GiftView