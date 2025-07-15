require("Base/BasePanel")
local CustomSuppliesShopPanel = Inherit(BasePanel)
local this = CustomSuppliesShopPanel
local TabBox = require("Modules/Common/TabBox")
local _ShopTypeConfig = ConfigManager.GetConfig(ConfigName.StoreTypeConfig)
local configData
--初始化组件（用于子类重写）
function CustomSuppliesShopPanel:InitComponent()
    this.tabbox = Util.GetGameObject(self.gameObject, "tabbox")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.content = Util.GetGameObject(self.gameObject, "content")

    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft})
end

--绑定事件（用于子类重写）
function CustomSuppliesShopPanel:BindEvent()
    this.ShopTabCtrl = TabBox.New()
    this.ShopTabCtrl:SetTabAdapter(this.ShopTabAdapter)
    this.ShopTabCtrl:SetTabIsLockCheck(this.ShopTabIsLockCheck)
    this.ShopTabCtrl:SetChangeTabCallBack(this.OnShopTabChange)

    Util.AddClick(this.btnBack, function ()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function CustomSuppliesShopPanel:AddListener()
    -- Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.updateIconNumber)
    Game.GlobalEvent:AddEvent(GameEvent.Shop.OnExchangeChange, this.SetScrollview)
end

--移除事件监听（用于子类重写）
function CustomSuppliesShopPanel:RemoveListener()
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Bag.BagGold, this.updateIconNumber)
    Game.GlobalEvent:RemoveEvent(GameEvent.Shop.OnExchangeChange, this.SetScrollview)
end

--界面打开时调用（用于子类重写）
function CustomSuppliesShopPanel:OnOpen(pageType,curIndex)
    this.pageType = pageType--商店类型

   local dataList=ConfigManager.GetAllConfigsDataByKey(ConfigName.StoreTypeConfig, "Pages", this.pageType)
   local tempList = {}
   for _, v in ipairs(dataList) do
        tempList[v.StoreType] = v.Sort
   end
   this.shoplist = {}
   for StoreType, _ in pairs(tempList) do
       table.insert(this.shoplist, StoreType)
   end
   table.sort(this.shoplist, function(a, b)
       return tempList[a] < tempList[b]
   end)

    this._CurShopIndex = nil
    this.ShopTabCtrl:Init(this.tabbox, this.shoplist)
end

function CustomSuppliesShopPanel:OnShow()
   if this.ShopTabCtrl then
       this._CurShopIndex = nil
       this.ShopTabCtrl:ChangeTab(1)
   end
end

--界面关闭时调用（用于子类重写）
function CustomSuppliesShopPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function CustomSuppliesShopPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
    this.ScrollView = nil
end

-- tab按钮自定义显示设置
function this.ShopTabAdapter(tab, index, status)
    local defaultName = Util.GetGameObject(tab, "default/Text"):GetComponent("Text")
    local selectName = Util.GetGameObject(tab, "select/Text"):GetComponent("Text")
    local redpot = Util.GetGameObject(tab, "redpot")

    local shopType = this.shoplist[index]
    local shopInfo = ShopManager.GetShopInfoByType(shopType)
    defaultName.text = GetLanguageStrById(shopInfo.Name)
    selectName.text = GetLanguageStrById(shopInfo.Name)

    Util.GetGameObject(tab, "default"):SetActive(status == "default")
    Util.GetGameObject(tab, "select"):SetActive(status == "select")
    -- 判断是否需要检测红点
    redpot:SetActive(false)
end

-- tab可用性检测
function this.ShopTabIsLockCheck(index)
    local shopType = this.shoplist[index]
    local isActive, errorTip = ShopManager.IsActive(shopType)
    if not isActive then
        local data = ConfigManager.GetConfigData(ConfigName.StoreTypeConfig,shopType)
        errorTip = errorTip or GetLanguageStrById(10528)
        return true, errorTip
    end
    return false
end

local ShopType
local ShopConfig
-- tab改变事件
function this.OnShopTabChange(index, lastIndex)
    if this._CurShopIndex == index then
        return
    end
    this._CurShopIndex = index
    ShopType = this.shoplist[index]

    this.SetScrollview()

    -- 货币界面
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = ShopConfig.ResourcesBar})
end

function this.SetScrollview()
    local v2 = this.content.gameObject:GetComponent("RectTransform").rect
    if not this.ScrollView then
        this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.content.transform,
            Util.GetGameObject(this.content, "shopItem"), nil, Vector2.New(v2.width, v2.height), 1, 2, Vector2.New(5, 10))
        this.ScrollView.moveTween.MomentumAmount = 1
        this.ScrollView.moveTween.Strength = 2
    end

    -- 获取配置
    local shopId = ShopManager.GetShopDataByType(ShopType).id
    ShopConfig = _ShopTypeConfig[shopId]

    this.data = {}
    this.ShopData = ShopManager.GetShopDataByType(ShopType)
    for k,v in ipairs(this.ShopData.storeItem) do
        local _id = v.id
        if ShopType == 8 and _id > 100000 then 
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
                end
            end
        else
            table.insert(this.data,v)
        end
    end

    if this.data and #this.data > 0 then
        table.sort(this.data, function(a, b)
            return a.id > b.id
        end)
    end
    local itemlist = this.data 
    local storeTypeConfigData = G_StoreTypeConfig[ShopType]
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
    this.ScrollView:SetData(itemlist, function(index, shopItem)
        local itemData = itemlist[index]
        this.ShopItemAdapter(shopItem, itemData)
    end)
end

local _GoodsItemList = {}
function this.ShopItemAdapter(shopItem, itemData)
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
    local costId, price = ShopManager.calculateBuyCost(ShopType, itemData.id, 1)
    local goods = ShopManager.GetShopItemGoodsInfo(itemData.id)
    itemName.text = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, goods[1][1]).Name)
    -- 折扣
    if price == 0 then
        discountbg:SetActive(true)
        discountText.text = GetLanguageStrById(10559)
    else
        local isDiscount = itemInfo.IsDiscount == 1
        discountbg:SetActive(isDiscount)
        if isDiscount then
            discountText.text = ((10-itemInfo.DiscountDegree)*10).."%"
        end
    end
    discountbg:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_shikongzhanchang_zhekou2"))
    -- 消耗物品的信息
    itemPrice.text = PrintWanNum2(tonumber(price))
    costIcon.sprite = SetIcon(costId)

    -- 判断商品栏位是否解锁
    local storeTypeConfigData = G_StoreTypeConfig[ShopType]
    local _IsUnLock = true
    if ShopType == SHOP_TYPE.GUILD_SHOP then
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
    itemName.gameObject:SetActive(_IsUnLock)

    -- 限购
    limitBg:SetActive(maxLimitCount ~= -1 and isVip == false)
    -- limitTimes.gameObject:SetActive(maxLimitCount ~= -1)
    vipBuyLimitbg:SetActive(isVip)
    if isVip  then
        Util.GetGameObject(vipBuyLimitbg, "tip"):GetComponent("Text").text = GetLanguageStrById(50334)
    end
    limitTip.text = this.GetLanguageStrById(ShopConfig.RefreshType[1])
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
        _GoodsItemList[shopItem]:OnOpen(false, goods[1], 0.7, false, false, false)
    else
        _GoodsItemList[shopItem]:OnOpen(false, goods[1], 0.7, false, false, false, this.sortingOrder)
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
        UIManager.OpenPanel(UIName.ShopBuyPopup, ShopType, itemData.id)
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

return CustomSuppliesShopPanel