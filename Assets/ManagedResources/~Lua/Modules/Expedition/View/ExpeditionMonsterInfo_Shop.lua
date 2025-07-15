----- 远征商店节点弹窗 -----
local this = {}
--传入父脚本模块
local parent
local sortingOrder=0
local fun
local type = 1 --1 前往 2 放弃
local itemViewList = {}
function this:InitComponent(gameObject)
    this.titleText=Util.GetGameObject(gameObject,"TitleText"):GetComponent("Text")
    local v2 = Util.GetGameObject(gameObject, "Root"):GetComponent("RectTransform").rect
    this.ShopItem = Util.GetGameObject(gameObject, "ShopItem")
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "Root").transform,
            this.ShopItem, nil, Vector2.New(-v2.x*2, -v2.y*2), 1, 4, Vector2.New(40,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.ScrollView.elastic = false
    --self.elastic = true --支持超框拖动
    this.sureBtn=Util.GetGameObject(gameObject,"sureBtn")
    this.sureBtnText=Util.GetGameObject(gameObject,"sureBtn/Text"):GetComponent("Text")
    this.backBtn=Util.GetGameObject(gameObject,"BackBtn")
end

function this:BindEvent()
    Util.AddClick(this.sureBtn, function()
        this:BtnClickEvent()
        if fun then
            fun()
            fun = nil
        end
    end)
    Util.AddClick(this.backBtn, function()
        this:BtnClickEvent()
    end)
end
function this:BtnClickEvent()
        if type == 3 then
            local shopInfoList
            local curShopData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.StoreTypeConfig,"StoreType",SHOP_TYPE.EXPEDITION_SHOP,"Sort",1)
            if curShopData then
                shopInfoList = ShopManager.GetShopDataByShopId(curShopData.Id)
            end
            local isBuyShop = true
            for i = 1, #shopInfoList.storeItem do
                if shopInfoList.storeItem[i].buyNum <= 0 then
                    isBuyShop = false
                end
            end
            if isBuyShop then
                parent:ClosePanel()
            else
                MsgPanel.ShowTwo(GetLanguageStrById(10518), function()
                end, function()
                    parent:ClosePanel()
                end)
            end
            if fun then
                fun()
                fun = nil
            end
        else
            parent:ClosePanel()
        end
end


function this:AddListener()
end

function this:RemoveListener()
end

function this:OnShow(_parent,...)
    parent=_parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local args = {...}
    type = args[2]
    fun = args[3]
    this:OnShowPanel()
end
function this:OnShowPanel()
    this.titleText.text=GetLanguageStrById(10519)
    if type == 1 then
        this.sureBtnText.text = GetLanguageStrById(10508)
    elseif type == 2 then
        this.sureBtnText.text = GetLanguageStrById(10509)
    elseif type == 3 then
        this.sureBtnText.text = GetLanguageStrById(10520)
    end
    local shopInfoList
    local curShopData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.StoreTypeConfig,"StoreType",SHOP_TYPE.EXPEDITION_SHOP,"Sort",1)
    if curShopData then
        shopInfoList = ShopManager.GetShopDataByShopId(curShopData.Id)
    end
    if shopInfoList then
        this.ScrollView:SetData(shopInfoList.storeItem, function (index, go)
            this.SingleItemDataShow2(go, shopInfoList.storeItem[index],curShopData.Id)
        end)
    end
end
--半价购买
function this.SingleItemDataShow2(go, data,curShopDataId)
    local storeConfig = ConfigManager.GetConfigData(ConfigName.StoreConfig,data.id)
    if not storeConfig then return end
    local item,num,oldNum = ShopManager.CalculateCostCountByShopId(curShopDataId, data.id, 1)
    --Util.GetGameObject(go, "item/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,storeConfig.Goods[1][1]).ResourceID))
    Util.GetGameObject(go, "item/itemName"):GetComponent("Text").text = GetLanguageStrById(storeConfig.GoodsName)
    --Util.GetGameObject(go, "item/buyLimit/Text"):GetComponent("Text").text = storeConfig.Limit - data.buyNum

    if itemViewList[go] then
        itemViewList[go]:OnOpen(false, {storeConfig.Goods[1][1],storeConfig.Goods[1][2]}, 0.8)
    else
        itemViewList[go] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(go, "item").transform)
        itemViewList[go]:OnOpen(false, {storeConfig.Goods[1][1],storeConfig.Goods[1][2]}, 0.8)
    end

    Util.GetGameObject(go, "zhe"):SetActive(storeConfig.IsDiscount > 0)
    Util.GetGameObject(go, "zhe"):GetComponent("Image").sprite = Util.LoadSprite("s_shop_zhekou_0"..storeConfig.DiscountDegree)
    
    Util.GetGameObject(go, "price/costIcon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.ItemConfig,item).ResourceID))
    Util.GetGameObject(go, "price/Text"):GetComponent("Text").text = num
    local buyBtn = Util.GetGameObject(go,"price/btnBuy")
    
    if type == 3 then
        Util.GetGameObject(go, "price/over"):SetActive(storeConfig.Limit - data.buyNum <= 0)
        Util.GetGameObject(go, "price/Text"):SetActive(storeConfig.Limit - data.buyNum > 0)
        Util.GetGameObject(go, "price/costIcon"):SetActive(storeConfig.Limit - data.buyNum > 0)
    else
        Util.GetGameObject(go, "price/over"):SetActive(false)
        Util.GetGameObject(go, "price/Text"):SetActive(true)
        Util.GetGameObject(go, "price/costIcon"):SetActive(true)
    end
    Util.AddOnceClick(buyBtn,function()
        if type ~= 3 then
            PopupTipPanel.ShowTipByLanguageId(10521)
            return
        end
        if storeConfig.Limit - data.buyNum < 1 then
            PopupTipPanel.ShowTipByLanguageId(10523)
            return
        end
        if BagManager.GetItemCountById(item) < num then
            --UIManager.OpenPanel(  UIName.QuickPurchasePanel,{ type = item })
            PopupTipPanel.ShowTip("【"..GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,item).Name)..GetLanguageStrById(10522))
            return
        end
        ShopManager.RequestBuyItemByShopId(curShopDataId, storeConfig.Id, 1, function ()
            
            this:OnShowPanel()
        end)
    end)
end
function this:OnClose()

end

function this:OnDestroy()
end

return this