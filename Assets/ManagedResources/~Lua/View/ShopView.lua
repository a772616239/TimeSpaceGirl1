
local _ShopTypeConfig = ConfigManager.GetConfig(ConfigName.StoreTypeConfig)
-- 通用得商店逻辑
local ShopView = {}
local this = ShopView
this.sortingOrder = 0
-- 保存商品中的物品节点
local _GoodsItemList = {}
local _GoodsItemListBlack = {}

---===============================生命周期函数================================
function this:New(gameObject)
    local o = {}
    this.__index = this
    setmetatable(o, this)
    o.gameObject = gameObject
    o.transform = gameObject.transform
    o.parentGo = gameObject.transform.parent
    return o
end
--初始化组件（用于子类重写）
function this:InitComponent()
    self.basePanel = Util.GetGameObject(self.gameObject, "base")
    self.closeTimePanel = Util.GetGameObject(self.gameObject, "base/closeTime")
    self.closeTimeLab = Util.GetGameObject(self.closeTimePanel, "timelab")
    self.closeTime = Util.GetGameObject(self.closeTimePanel, "time")
    self.refreshTimePanel = Util.GetGameObject(self.gameObject, "base/refreshInfo/refreshTime")
    self.refreshTime = Util.GetGameObject(self.refreshTimePanel, "time")
    self.countTimePanel = Util.GetGameObject(self.gameObject, "base/refreshInfo/countTime")
    self.countTime = Util.GetGameObject(self.countTimePanel, "time")
    self.refreshCountPanel = Util.GetGameObject(self.gameObject, "base/refreshInfo/refreshCount")
    self.countLabTip = Util.GetGameObject(self.refreshCountPanel, "tip")
    self.countLab = Util.GetGameObject(self.refreshCountPanel, "count")
    self.refreshBtnPanel = Util.GetGameObject(self.gameObject, "base/refreshBtn")
    self.refreshBtn = Util.GetGameObject(self.refreshBtnPanel, "btn")
    self.refreshRedpot = Util.GetGameObject(self.refreshBtnPanel, "redpot")
    self.costIcon = Util.GetGameObject(self.refreshBtnPanel, "costIcon")
    self.costLab = Util.GetGameObject(self.refreshBtnPanel, "costLab")
    self.refreshText = Util.GetGameObject(self.refreshBtnPanel, "refreshText")

    self.scrollBg = Util.GetGameObject(self.gameObject, "scrollbg")
    self.scrollRoot = Util.GetGameObject(self.gameObject, "scrollbg/scrollroot")

    self.shopItem = Util.GetGameObject(self.gameObject, "scrollbg/scrollroot/shopItem")
    self.blackItem = Util.GetGameObject(self.gameObject, "scrollbg/scrollroot/blackItem")
    self.rechargeShopItem = Util.GetGameObject(self.gameObject, "scrollbg/scrollroot/rechargeShopItem")
end

--绑定事件（用于子类重写）
function this:BindEvent()
    local localSelf = self
    Util.AddOnceClick(self.refreshBtn, function()
        local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. localSelf.ShopType)
        local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
        local shopType = localSelf.ShopType
        local isAutoRecover = ShopManager.IsAutoRecoverCount(shopType)
        if (isPopUp ~= currentTime) and not isAutoRecover then
            local shopInfo = ShopManager.GetShopInfoByType(shopType)
            local costId, abcd = shopInfo.RefreshItem[1][1], shopInfo.RefreshItem[2]
            local refreshNum = PrivilegeManager.GetPrivilegeUsedTimes(shopInfo.RefreshPrivilege)
            local costNum = CalculateCostCount(refreshNum, abcd)
            local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
            local costName = GetLanguageStrById(itemConfig[costId].Name)
            local str = string.format(GetLanguageStrById(12087), costNum, costName)

            UIManager.OpenPanel(UIName.GeneralPopup, GENERAL_POPUP_TYPE.Buy, itemConfig[costId].ResourceID, str,function(isShow)
                if isShow then
                    local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                    RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. localSelf.ShopType, currentTime)
                end
                ShopManager.RequestRefreshShop(shopType, false)
            end)

            -- MsgPanel.ShowTwo(str, function()
            -- end, function(isShow)
            --     if isShow then
            --         local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
            --         RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .. localSelf.ShopType, currentTime)
            --     end
            --     ShopManager.RequestRefreshShop(shopType, false)
            -- end, GetLanguageStrById(10719), GetLanguageStrById(10720),nil,true)
        else
            ShopManager.RequestRefreshShop(localSelf.ShopType, false)
        end

        -- 重置商店刷新按钮点击状态
        ShopManager.SetShopRefreshBtnClickStatus(localSelf.ShopType, true)
    end)
end

--添加事件监听（用于子类重写）
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Shop.OnShopInfoChange, self.RefreshShopInfo, self)
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, self.RechargeSuccessFunc, self)
end
--移除事件监听（用于子类重写）
function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Shop.OnShopInfoChange, self.RefreshShopInfo, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, self.RechargeSuccessFunc, self)
end
--界面打开时调用（用于子类重写）
function this:OnOpen(parent)
    self.rect = parent.gameObject:GetComponent("RectTransform").rect
    local rect=self.rect
    self.scrollBg:GetComponent("RectTransform").sizeDelta = Vector2.New(rect.width, rect.height)

    if not self.ScrollView then
        self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scrollRoot.transform,
                self.shopItem, nil, Vector2.New(rect.width, rect.height), 1, 2, Vector2.New(5, 10))
        self.ScrollView.moveTween.MomentumAmount = 1
        self.ScrollView.moveTween.Strength = 2

        self.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
        self.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
        self.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
        self.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
        if Util.GetGameObject(self.ScrollView.transform,"grid").transform.childCount == 0 then
            self.ScrollView.gameObject:SetActive(false)
        end
    end

    if not self.RechargeScrollView then
        self.RechargeScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scrollRoot.transform,
                self.rechargeShopItem, nil, Vector2.New(rect.width, rect.height), 1, 3, Vector2.New(-10, 0))
        self.RechargeScrollView.moveTween.MomentumAmount = 1
        self.RechargeScrollView.moveTween.Strength = 2
        self.RechargeScrollView.elastic = false

        self.RechargeScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
        self.RechargeScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
        self.RechargeScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
        self.RechargeScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
        if Util.GetGameObject(self.RechargeScrollView.transform,"grid").transform.childCount == 0 then
            self.RechargeScrollView.gameObject:SetActive(false)
        end
    end

    if not self.BlackMarketScrollView then
        self.BlackMarketScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scrollRoot.transform,
                self.blackItem, nil, Vector2.New(1080, 970), 1, 3, Vector2.New(5, 5))
        self.BlackMarketScrollView.moveTween.MomentumAmount = 1
        self.BlackMarketScrollView.moveTween.Strength = 2
        self.BlackMarketScrollView.elastic = false

        self.BlackMarketScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
        self.BlackMarketScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
        self.BlackMarketScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
        self.BlackMarketScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
        if Util.GetGameObject(self.BlackMarketScrollView.transform,"grid").transform.childCount == 0 then
            self.BlackMarketScrollView.gameObject:SetActive(false)
        end
    end
end
--界面关闭时调用（用于子类重写）
function this:OnClose()
    if self._TimeCounter then
        self._TimeCounter:Stop()
        self._TimeCounter = nil
    end

    -- 物品节点回收
    if self.ShopType == SHOP_TYPE.GENERAL_SHOP then
        for _, item in pairs(_GoodsItemListBlack) do
            if not IsNull(item.gameObject) then
                Util.SetColor(item.gameObject, Color.New(1,1,1,1))
                SubUIManager.Close(item)
            end
        end
        _GoodsItemListBlack = {}
    elseif self.ShopType == SHOP_TYPE.QIANKUNBOX_SHOP then
        for _, item in pairs(_GoodsItemList) do
            if not IsNull(item.gameObject) then
                Util.SetColor(item.gameObject, Color.New(1,1,1,1))
                SubUIManager.Close(item)
            end
        end
        _GoodsItemList = {}
    end

    if self.ScrollView then
        GameObject.DestroyImmediate(self.ScrollView.gameObject)
        self.ScrollView = nil
    end

    if self.RechargeScrollView then
        GameObject.DestroyImmediate(self.RechargeScrollView.gameObject)
        self.RechargeScrollView = nil
    end
    if self.BlackMarketScrollView then
        GameObject.DestroyImmediate(self.BlackMarketScrollView.gameObject)
        self.BlackMarketScrollView = nil
    end
end

---=================================工具函数==========================================
-- 设置文本透明度
local function SetAlpha(text, a)
    local color = text.color
    color.a = a
    text.color = color
end

---===================================内部函数========================================
-- 刷新商店内容显示
function this:RefreshShopInfo(isRefresh, isTop)
    if self.ShopType == 50000 then
        self.RechargeShopData = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DemonCrystal)
    else
        this.data = {}
        self.ShopData = ShopManager.GetShopDataByType(self.ShopType)
        for k,v in ipairs(self.ShopData.storeItem) do
            local _id = v.id
            if self.ShopType == 8 and _id > 100000 then 
                _id = v.id % 100000
            end
            local acticityList = G_StoreConfig[_id].GlobalActivityId
            if acticityList ~= nil and #acticityList > 0 then
                for i,j in pairs(acticityList) do
                    local type = ActivityGiftManager.GetActivityTypeFromId(j)
                    local id = ActivityGiftManager.IsActivityTypeOpen(type)
                    if id ~= nil and id == j then
                        table.insert(this.data,v)
                        break
                    else
                    end
                end
            else
                table.insert(this.data,v)
            end
        end
    end

    if this.data and #this.data > 0 then
        table.sort(this.data, function(a, b) 
            return a.id < b.id
        end)
    end

    if self.ShopType ~= 50000 then
        self:RefreshBase()
    end
    self:RefreshItemList(isTop)

    -- 刷新商店的查看时间
    ShopManager.RefreshShopCheckTime(self.ShopType)

    if isRefresh then
        -- 物品节点播放特效
        for _, item in pairs(_GoodsItemList) do
            item:OnShowUIeffectItemViewSaoguang()
        end
    end
    if isRefresh then
        -- 物品节点播放特效
        for _, item in pairs(_GoodsItemListBlack) do
            item:OnShowUIeffectItemViewSaoguang()
        end
    end
end

-- 开始倒计时
function this:StartTimeCount()
    local localSelf = self
    local function _TimeUpdate()
        -- 检测计时器是否已销毁，避免计时器销毁后仍然会执行一次，导致报错的问题
        if not localSelf._TimeCounter then
            return
        end
        -- 刷新时间
        if localSelf.isShowRefreshTime then
            local refreshTime = ShopManager.GetShopRefreshLeftTime(localSelf.ShopType)
            if refreshTime >= 0 then
                localSelf.refreshTime:GetComponent("Text").text = TimeToHMS(refreshTime)
            end
        end
        -- 关闭时间
        if localSelf.isShowCloseTime then
            local closeTime = ShopManager.GetShopCloseTime(localSelf.ShopType)
            if closeTime >= 0 then
                local timeStr = ""
                -- if localSelf.ShopType == SHOP_TYPE.ACTIVITY_SHOP then
                --     timeStr = TimeToDHMS(closeTime)
                -- else
                    timeStr = TimeToHMS(closeTime)
                -- end
                localSelf.closeTime:GetComponent("Text").text = timeStr
            end
        end
        -- 次数恢复时间
        if localSelf.isShowCountTime then
            local refreshTime = ShopManager.GetShopRefreshCountRecoverTime(localSelf.ShopType)
            local maxTime = ShopManager.GetMaxRefreshCount(localSelf.ShopType)
            local isAutoRecover, leftTime = ShopManager.IsAutoRecoverCount(localSelf.ShopType)
            if refreshTime > 0 then
                localSelf.countTime:GetComponent("Text").text = TimeToHMS(refreshTime)
            elseif isAutoRecover and maxTime == leftTime and not localSelf.isMaxTime then
                -- localSelf:RefreshBase()
                localSelf.countTime:GetComponent("Text").text = "<color=#ff9900>"..GetLanguageStrById(12088).."</color>"
                localSelf.countLabTip:GetComponent("Text").text = GetLanguageStrById(12092)
                localSelf.countLab:GetComponent("Text").text = leftTime
                localSelf.isMaxTime = true
            elseif isAutoRecover and maxTime ~= leftTime and refreshTime == 0 then
                localSelf:RefreshBase()
                localSelf.isMaxTime = false
            end
        end
    end
    -- 开始吧
    if not self._TimeCounter then
        self._TimeCounter = Timer.New(_TimeUpdate, 1, -1, true)
        self._TimeCounter:Start()
    end
    -- 刷新一次
    _TimeUpdate()
end

-- 刷新时间及刷新按钮
function this:RefreshBase()
    -- 自动刷新时间倒计时
    local leftTime = ShopManager.GetShopRefreshLeftTime(self.ShopType)
    self.isShowRefreshTime = leftTime >= 0
    self.refreshTimePanel:SetActive(self.isShowRefreshTime)
    -- 商店关闭时间倒计时
    local closeTime = ShopManager.GetShopCloseTime(self.ShopType)
    self.isShowCloseTime = closeTime >= 0 and not self.isShowRefreshTime
    self.closeTimePanel:SetActive(self.isShowCloseTime)
    if self.isShowCloseTime then
        if self.ShopType == SHOP_TYPE.ARENA_SHOP or self.ShopType == SHOP_TYPE.TOP_MATCH_SHOP then
            self.closeTimeLab:GetComponent("Text").text = GetLanguageStrById(12089)
        else
            self.closeTimeLab:GetComponent("Text").text = GetLanguageStrById(12090)
        end
    end
    -- 次数恢复时间
    local countTime = ShopManager.GetShopRefreshCountRecoverTime(self.ShopType)
    self.isShowCountTime = countTime >= 0
    self.countTimePanel:SetActive(self.isShowCountTime)
    --开始倒计时
    if self.ShopType ~= 50000 then
        self:StartTimeCount()
    end
    -- 主动刷新按钮
    local leftCount = ShopManager.GetShopLeftRefreshCount(self.ShopType)
    if leftCount == -2 then
        -- 不支持刷新
        self.refreshCountPanel:SetActive(false)
        self.refreshBtnPanel:SetActive(false)
    else
        self.refreshBtnPanel:SetActive(true)
        if leftCount == -1 then
            -- 无限制次数刷新
            self.refreshCountPanel:SetActive(false)
        elseif leftCount >= 0 then
            -- 限制次数刷新
            self.refreshCountPanel:SetActive(true)
            self.countLab:GetComponent("Text").text = leftCount
        end

        local isAutoRecover = ShopManager.IsAutoRecoverCount(self.ShopType)
        if isAutoRecover then
            self.refreshText:SetActive(true)
            self.refreshText:GetComponent("Text").text = GetLanguageStrById(11144)
            self.costIcon:SetActive(false)
            self.costLab:SetActive(false)
            self.countLabTip:GetComponent("Text").text = GetLanguageStrById(12092)
            self.isMaxTime = false
        else
            self.refreshText:SetActive(false)
            self.costIcon:SetActive(true)
            self.costLab:SetActive(true)
            self.countLabTip:GetComponent("Text").text = GetLanguageStrById(12093)
            -- 刷新物品计算
            local shopInfo = ShopManager.GetShopInfoByType(self.ShopType)
            local costId, abcd = shopInfo.RefreshItem[1][1], shopInfo.RefreshItem[2]
            self.costIcon:GetComponent("Image").sprite = SetIcon(costId)
            -- 商店特权正确性检测
            -- if not shopInfo.RefreshPrivilege or shopInfo.RefreshPrivilege == 0 then
            -- end
            local refreshNum = PrivilegeManager.GetPrivilegeUsedTimes(shopInfo.RefreshPrivilege)
            self.costLab:GetComponent("Text").text = CalculateCostCount(refreshNum, abcd) .. GetLanguageStrById(11144)
        end
    end



    -- 商店标题
    if self.ShopConfig.Title and self.ShopConfig.Title ~= "" then
        --暂时用不到 Title应该是图片名字（用到的话需要改表）
        --self.titleImg:GetComponent("Image").sprite = Util.LoadSprite(self.ShopConfig.Title)
    end

    -- 对话显示
    -- if self.ShopConfig.content then
    --     self.contentBg:SetActive(true)
    --     self.content:GetComponent("Text").text = self.ShopConfig.content
    --     self.contentBg.transform.localPosition = Vector3(self.ShopConfig.contentPos[1], self.ShopConfig.contentPos[2], 0)
    -- else
        -- self.contentBg:SetActive(false)
    -- end

end

-- 刷新物品列表
function this:RefreshItemList(isTop)
    if self.ShopType == 50000 then
        self.ScrollView.gameObject:SetActive(false)
        self.RechargeScrollView.gameObject:SetActive(true)
        --self.BlackMarketScrollView.gameObject:SetActive(false)
        local itemlist = self.RechargeShopData

        self.RechargeScrollView:SetData(itemlist, function(index, shopItem)
            local itemData = itemlist[index]
            self:RechargeShopItemAdapter(shopItem, itemData)
        end)
        if isTop then
            self.RechargeScrollView:SetIndex(1)
        end
    elseif self.ShopType == SHOP_TYPE.GENERAL_SHOP then
          self.RechargeScrollView.gameObject:SetActive(false)
          self.ScrollView.gameObject:SetActive(false)
          self.BlackMarketScrollView.gameObject:SetActive(true)
          local itemlist = this.data
          self.BlackMarketScrollView:SetData(itemlist, function(index, shopItem)
              local itemData = itemlist[index]
              self:BlackShopItemAdapter(shopItem, itemData)
          end)
          if isTop then
              self.BlackMarketScrollView:SetIndex(1)
          end
    else
        self.RechargeScrollView.gameObject:SetActive(false)
        self.ScrollView.gameObject:SetActive(true)

        --单独处理遗忘之城商品可见
        local StoreList={}
        for index, value in ipairs(this.data) do
            if value.id~=nil then
                local Store= ConfigManager.GetConfigData(ConfigName.StoreConfig,value.id)

                local _OpenLv = Store.ShowLv[1]
                if  _OpenLv <= PlayerManager.level then
                    table.insert(StoreList, value)
                end 
            
            end
        end
        
        -- local itemlist = this.data
        local itemlist = StoreList

        -- 处理商店商品可见
        local storeTypeConfigData = G_StoreTypeConfig[self.ShopType]
        if storeTypeConfigData and storeTypeConfigData.Pages == SHOP_INDEPENDENT_PAGE.CLIMB_ADVANCE then
            local a = {}
            for i = 1, #this.data do
                local shopid = this.data[i].id
                if ClimbTowerManager.CheckShopItemIsVisible(shopid) then
                    table.insert(a, this.data[i])
                end
            end
            itemlist = a
        end
        -- 异端之战商店特殊处理
        if self.ShopType == SHOP_TYPE.TRIAL_SHOP then
            local a = {}
            local hideShopsNum = MapManager.GetShopHideCount()
            for i = 1, #this.data do
                if i > #this.data - hideShopsNum then
                    break
                end
                -- -- 后端100000 问题
                -- if self.ShopData.storeItem[i].id > 100000 then
                --     self.ShopData.storeItem[i].id = self.ShopData.storeItem[i].id % 100000
                -- end
                table.insert(a, self.ShopData.storeItem[i])
            end
            itemlist = a
        end
        self.ScrollView:SetData(itemlist, function(index, shopItem)
            local itemData = itemlist[index]
            self:ShopItemAdapter(shopItem, itemData)
        end)
        if isTop then
            self.ScrollView:SetIndex(1)
        end
    end
end

-- 商店物品数据匹配
function this:ShopItemAdapter(shopItem, itemData)
    -- 获取对象
    local bg = Util.GetGameObject(shopItem, "bg")
    local item = Util.GetGameObject(bg, "item")
    local itemName = Util.GetGameObject(bg, "itemName"):GetComponent("Text")
    local limitBg = Util.GetGameObject(bg, "buyLimitbg")
    local vipBuyLimitbg = Util.GetGameObject(bg, "vipBuyLimitbg")
    local limitTip = Util.GetGameObject(bg, "buyLimitbg/tip"):GetComponent("Text")
    local limitTimes = Util.GetGameObject(bg, "buyLimitbg/buyLimit"):GetComponent("Text")
    local priceBg = Util.GetGameObject(bg, "pricebg")
    local itemPrice = Util.GetGameObject(bg, "pricebg/price"):GetComponent("Text")
    local costIcon = Util.GetGameObject(bg, "pricebg/costIcon"):GetComponent("Image")
    local discountbg = Util.GetGameObject(shopItem, "discountbg")
    local discountText = Util.GetGameObject(shopItem, "discountbg/Text"):GetComponent("Text")
    local empty = Util.GetGameObject(shopItem, "empty")
	local emptypic = Util.GetGameObject(shopItem, "empty/empty")
    local lock = Util.GetGameObject(shopItem, "lock")
    local lockTip = Util.GetGameObject(shopItem, "lock/tip"):GetComponent("Text")
	emptypic:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_tongyong_yishouwan"))

    -- 计算数据
    local itemInfo = ShopManager.GetShopItemInfo(itemData.id)
    local curBuyCount = itemData.buyNum
    local maxLimitCount,isVip,isCanBuy = ShopManager.GetShopItemLimitBuyCount(itemData.id)
    local costId, price = ShopManager.calculateBuyCost(self.ShopType, itemData.id, 1)
    local goods = ShopManager.GetShopItemGoodsInfo(itemData.id)
    itemName.text = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,goods[1][1]).Name)--itemInfo.GoodsName
    -- 折扣
    if price == 0 then
        discountbg:SetActive(true)
        discountText.text = GetLanguageStrById(10559)
    else
        local isDiscount = itemInfo.IsDiscount == 1
        discountbg:SetActive(isDiscount)
        if isDiscount then
            discountText.text = ((10-itemInfo.DiscountDegree)*10).."%"--tostring(itemInfo.DiscountDegree)--..GetLanguageStrById(12664)
        end
    end
    discountbg:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_shikongzhanchang_zhekou2"))
    -- 消耗物品的信息
    itemPrice.text = price--PrintWanNum2(tonumber(price))--tostring(price)
    costIcon.sprite = SetIcon(costId)

    -- 判断商品栏位是否解锁
    local storeTypeConfigData = G_StoreTypeConfig[self.ShopType]
    local _IsUnLock = true
    if self.ShopType == SHOP_TYPE.GUILD_SHOP then
        local isUnLock, unLockLevel = MyGuildManager.GetGuildShopSortIsUnLock(itemInfo.Sort)
        if not isUnLock then
            _IsUnLock = false
            lockTip.text = string.format(GetLanguageStrById(12096), unLockLevel)
        end
    elseif storeTypeConfigData and storeTypeConfigData.Pages == SHOP_INDEPENDENT_PAGE.CLIMB_ADVANCE then
        local isUnLock, unLockLevel = ClimbTowerManager.CheckShopItemIsUnLock(itemData.id)
        if not isUnLock then
            _IsUnLock = false
            lockTip.text = GetLanguageStrById(50260) .. unLockLevel .. GetLanguageStrById(10488)
            --16010096
        end
    end
    lock:SetActive(not _IsUnLock)
    priceBg.gameObject:SetActive(_IsUnLock)
    itemName.gameObject:SetActive(_IsUnLock)

    -- 限购
    limitBg:SetActive(maxLimitCount ~= -1 and isVip == false)
    -- limitTimes.gameObject:SetActive(maxLimitCount ~= -1)
    vipBuyLimitbg:SetActive(isVip)
    if isVip  then
        Util.GetGameObject(vipBuyLimitbg, "tip"):GetComponent("Text").text = GetLanguageStrById(50334)
    end
    limitTip.text = this.GetLanguageStrById(self.ShopConfig.RefreshType[1])
    limitTimes.text = "("..curBuyCount .. "/" .. maxLimitCount..")"
    -- 售空 限购次数为-1 表示不限购
    local isEmpty = maxLimitCount ~= -1 and curBuyCount >= maxLimitCount 

    if isVip then
        if maxLimitCount > 0 then
            empty:SetActive(curBuyCount >= maxLimitCount)
            isEmpty = curBuyCount >= maxLimitCount
        else
            empty:SetActive(false)
            isEmpty = false
        end
    else
        empty:SetActive(isEmpty)
    end

    -- 数据匹配
    if not _GoodsItemList[shopItem] then
        _GoodsItemList[shopItem] = SubUIManager.Open(SubUIConfig.ItemView, item.transform)
    end
    Util.SetGray(_GoodsItemList[shopItem].gameObject, not _IsUnLock)
    if isEmpty or not _IsUnLock then    -- 物品空或者未解锁不现实物品特效
        _GoodsItemList[shopItem]:OnOpen(false, goods[1],0.7,false,false,false)
    else
        _GoodsItemList[shopItem]:OnOpen(false, goods[1],0.7,false,false,false,this.sortingOrder)
    end

    -- 购买事件
    Util.AddOnceClick(lock, function()
        PopupTipPanel.ShowTipByLanguageId(12097)
    end)
    Util.AddOnceClick(empty, function()
        PopupTipPanel.ShowTipByLanguageId(12098)
    end)
    Util.AddOnceClick(bg, function()
        -- 售空
        if isEmpty then
            PopupTipPanel.ShowTipByLanguageId(12098)
            return
        end
        if not _IsUnLock then
            PopupTipPanel.ShowTipByLanguageId(12097)
            return
        end
        if not isCanBuy then
            PopupTipPanel.ShowTip(GetLanguageStrById(50335))
            return
        end
        UIManager.OpenPanel(UIName.ShopBuyPopup, self.ShopType, itemData.id)
    end)
end

--限购
function this.GetLanguageStrById(_RefreshType)
    if _RefreshType == 2 then
        return GetLanguageStrById(50145)
    elseif _RefreshType == 4 then
        return GetLanguageStrById(50146)
    elseif _RefreshType == 5 then
        return GetLanguageStrById(50144)
    else
        return GetLanguageStrById(50144)
    end
end

-- 商店物品数据匹配
function this:BlackShopItemAdapter(shopItem, itemData)
    -- 获取对象
    local bg = Util.GetGameObject(shopItem, "bg")
    local item = Util.GetGameObject(bg, "item")
    local itemName = Util.GetGameObject(bg, "itemName"):GetComponent("Text")
    local limitTip = Util.GetGameObject(bg, "buyLimitbg/tip"):GetComponent("Text")
    local limitTimes = Util.GetGameObject(bg, "buyLimitbg/buyLimit"):GetComponent("Text")
    local priceBg = Util.GetGameObject(bg, "pricebg")
    local itemPrice = Util.GetGameObject(bg, "pricebg/price"):GetComponent("Text")
    local costIcon = Util.GetGameObject(bg, "pricebg/costIcon"):GetComponent("Image")
    local discountbg = Util.GetGameObject(shopItem, "discountbg")
    local discountText = Util.GetGameObject(shopItem, "discountbg/Text"):GetComponent("Text")
    local empty = Util.GetGameObject(shopItem, "empty")
    local lock = Util.GetGameObject(shopItem, "lock")
    local lockTip = Util.GetGameObject(shopItem, "lock/tip"):GetComponent("Text")

    -- 计算数据
    local itemInfo = ShopManager.GetShopItemInfo(itemData.id)
    local curBuyCount = itemData.buyNum
    local maxLimitCount = ShopManager.GetShopItemLimitBuyCount(itemData.id)
    local costId, price = ShopManager.calculateBuyCost(self.ShopType, itemData.id, 1)
    local goods = ShopManager.GetShopItemGoodsInfo(itemData.id)
    itemName.text = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,goods[1][1]).Name)
       
    -- 折扣
    if price == 0 then
        discountbg:SetActive(true)
        discountText.text = GetLanguageStrById(10559)
    else
        local isDiscount = itemInfo.IsDiscount == 1
        discountbg:SetActive(isDiscount)
        if isDiscount then
            discountText.text = ((10-itemInfo.DiscountDegree)*10).."%"--tostring(itemInfo.DiscountDegree)--..GetLanguageStrById(12664)
        end
    end

    -- 消耗物品的信息
    itemPrice.text = PrintWanNum2(tonumber(price))--tostring(price)
    costIcon.sprite = SetIcon(costId)

    -- 判断商品栏位是否解锁
    local storeTypeConfigData = G_StoreTypeConfig[self.ShopType]
    local _IsUnLock = true
    if self.ShopType == SHOP_TYPE.GUILD_SHOP then
        local isUnLock, unLockLevel = MyGuildManager.GetGuildShopSortIsUnLock(itemInfo.Sort)
        if not isUnLock then
            _IsUnLock = false
            lockTip.text = string.format(GetLanguageStrById(12096), unLockLevel)
        end
    elseif storeTypeConfigData and storeTypeConfigData.Pages == SHOP_INDEPENDENT_PAGE.CLIMB_ADVANCE then
        local isUnLock, unLockLevel = ClimbTowerManager.CheckShopItemIsUnLock(itemData.id)
        if not isUnLock then
            _IsUnLock = false
            lockTip.text = GetLanguageStrById(50260) .. unLockLevel .. GetLanguageStrById(10488)
        end
    end
    lock:SetActive(not _IsUnLock)
    priceBg.gameObject:SetActive(_IsUnLock)

    -- 售空 限购次数为-1 表示不限购
    local isEmpty = maxLimitCount ~= -1 and curBuyCount >= maxLimitCount
    --limitTimes.text = string.format(GetLanguageStrById(12082), maxLimitCount)
    if curBuyCount >= maxLimitCount then
        empty:SetActive(true)
    else
        empty:SetActive(false)
    end
    empty:SetActive(isEmpty)

    --  数据匹配
    if not _GoodsItemListBlack[shopItem] then
        _GoodsItemListBlack[shopItem] = SubUIManager.Open(SubUIConfig.ItemView, item.transform)
    end
    Util.SetGray(_GoodsItemListBlack[shopItem].gameObject, not _IsUnLock)
    if isEmpty or not _IsUnLock then    -- 物品空或者未解锁不现实物品特效
        _GoodsItemListBlack[shopItem]:OnOpen(false, goods[1],1,false,false,false)
    else
        _GoodsItemListBlack[shopItem]:OnOpen(false, goods[1],1,false,false,false,this.sortingOrder)
    end

    -- 商品颜色显示
    local imgColor = isEmpty and Color.New(0.5, 0.5, 0.5, 1) or Color.New(1, 1, 1, 1)
    local textA = isEmpty and 0.7 or 1
    Util.SetColor(bg, imgColor)
    SetAlpha(limitTip, textA)
    SetAlpha(limitTimes, textA)
    SetAlpha(itemPrice, textA)
    
    -- 购买事件
    Util.AddOnceClick(lock, function()
        PopupTipPanel.ShowTipByLanguageId(12097)
    end)
    Util.AddOnceClick(empty, function()
        PopupTipPanel.ShowTipByLanguageId(12098)
    end)
    Util.AddOnceClick(bg, function()
        -- 售空
        if isEmpty then
            PopupTipPanel.ShowTipByLanguageId(12098)
            return
        end
        if not _IsUnLock then
            PopupTipPanel.ShowTipByLanguageId(12097)
            return
        end
        UIManager.OpenPanel(UIName.ShopBuyPopup, self.ShopType, itemData.id)
    end)
end

-- 钻石商店物品数据匹配
function this:RechargeShopItemAdapter(shopItem, itemData)
    -- 获取对象
    local first = Util.GetGameObject(shopItem, "first")
    local firstNum = Util.GetGameObject(shopItem, "first/Image/num"):GetComponent("Text")
    local icon = Util.GetGameObject(shopItem, "icon"):GetComponent("Image")
    local num = Util.GetGameObject(shopItem, "itemName"):GetComponent("Text")
    local price = Util.GetGameObject(shopItem, "price/Text"):GetComponent("Text")
    local GP = Util.GetGameObject(shopItem, "GP"):GetComponent("Text")

    -- 计算数据
    local itemInfo = ShopManager.GetRechargeItemInfo(itemData.goodsId)

    icon.sprite = Util.LoadSprite(GetResourcePath(itemInfo.Resources))
    num.text = GetLanguageStrById(itemInfo.Desc)--数量读取商品表的Desc字段
    price.text = MoneyUtil.GetMoney(itemInfo.Price)
    GP.text = "+" .. GetLanguageStrById(itemInfo.Desc) * 1--数量读取商品表的Desc字段
    -- 判断首充赠送
    local curBuyCount = itemData.buyTimes
    first:SetActive(curBuyCount < 1)
    firstNum.text = itemInfo.FirstMultiple[1][2]

    -- 购买事件
    Util.AddOnceClick(shopItem, function()
        if AppConst.isSDKLogin then
            PayManager.Pay({ Id = itemData.goodsId }, function()
                self:RechargeSuccessFunc(itemData.goodsId)
                PlayerPrefs.SetInt(PlayerManager.uid.."czlb", 0)
                CheckRedPointStatus(RedPointType.GrowthPackage)--成长礼包红点检测
            end)
        else
            NetManager.RequestBuyGiftGoods(itemData.goodsId, function()
                self:RechargeSuccessFunc(itemData.goodsId)
                PlayerPrefs.SetInt(PlayerManager.uid.."czlb", 0)
                CheckRedPointStatus(RedPointType.GrowthPackage)--成长礼包红点检测
            end)
        end
    end)
end

-- 充值成功回调
function this:RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DemonCrystal, id)
    self:RefreshShopInfo(false, false)
end

---=====================================对外接口=============================----
-- 设置要显示的商店类型
function this:ShowShop(shopType,_sortingOrder)
    this.sortingOrder = _sortingOrder
    -- 红点销毁
    self.refreshRedpot:SetActive(false)

    -- 刷新显示
    self.ShopType = shopType

    --如果是黑市界面才会显示免费刷新倒计时
    if shopType ~= 50000 then
        self.basePanel.gameObject:SetActive(true)
    else
        self.basePanel.gameObject:SetActive(false)
    end

    if self.ShopType ~= 50000 then
        self.ShopId = ShopManager.GetShopDataByType(self.ShopType).id
        self.ShopConfig = _ShopTypeConfig[self.ShopId]
    end
    -- 显示帮助按钮
    self:RefreshShopInfo(false, true)
end

-- 设置商店物品栏位置
function this:SetItemContentPosition(pos)
    -- 计算位置
    if not pos then
        return
    end
end

-- 设置基础信息位置(刷新)
function this:SetBasePanelPostion(pos)
    self.basePanel:GetComponent("RectTransform").anchoredPosition = pos
end

-- 设置层级
function this:SetSortLayer(sortLayer)
    for _, item in pairs(_GoodsItemList) do
        item:SetEffectLayer(sortLayer)--this.sortingOrder)
    end

    for _, item in pairs(_GoodsItemListBlack) do
        item:SetEffectLayer(sortLayer)--this.sortingOrder)
    end

    -- 保存层级
    this.sortingOrder = sortLayer
end

function this:SetScrollSize(addHeight)

    if addHeight then
        self.ScrollView.rectTransform.sizeDelta = Vector2.New(self.rect.width, self.rect.height+155)
    else
        self.ScrollView.rectTransform.sizeDelta = Vector2.New(self.rect.width, self.rect.height)
    end
end

return this