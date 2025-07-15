require("Base/BasePanel")
local ShopConfig = require("Modules/Shop/ShopConfig")
local ShopPanel = Inherit(BasePanel)
local this = ShopPanel

--初始化组件（用于子类重写）
function ShopPanel:InitComponent()
    this.btnBack = Util.GetGameObject(self.gameObject, "rightUp/btnBack")

    this.live = Util.GetGameObject(self.transform, "live")

    -- 晶魂
    this.scrollRoot = Util.GetGameObject(self.transform, "jinghunRoot/scrollroot")
    this.shopItem = Util.GetGameObject(this.scrollRoot, "item")

    -- 创建循环列表
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scrollRoot.transform,
            this.shopItem, nil, Vector2.New(1000, 1015), 1, 3, Vector2.New(15, 0))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2

    -- 上部货币显示
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft })
end

--绑定事件（用于子类重写）
function ShopPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
end

--界面打开时调用（用于子类重写）
function ShopPanel:OnOpen(...)
    this.ShopType = SHOP_TYPE.SOUL_STONE_SHOP
    SoundManager.PlayMusic(SoundConfig.BGM_Shop)

    this:RefreshLive()
    this.InitItems()

    -- 货币界面
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
end

-- 刷新立绘显示
function this:RefreshLive()
    --TODO:动态加载立绘
    if this.testLiveGO then
        poolManager.UnLoadLive(this.testLiveGO.name, this.testLiveGO)
    end
    --Util.ClearChild(this.live.transform)
    local liveConfig = ShopConfig[this.ShopType]
    this.testLiveGO = poolManager:LoadLive(liveConfig.liveName, this.live.transform,
            Vector3.one * liveConfig.liveScale, Vector3.New(liveConfig.livePos[1], liveConfig.livePos[2], 0))

    local SkeletonGraphic = Util.GetGameObject(this.live, liveConfig.liveName):GetComponent("SkeletonGraphic")
    local idle = function() SkeletonGraphic.AnimationState:SetAnimation(0, "idle", true) end
    SkeletonGraphic.AnimationState:SetAnimation(0, "come", false)
    SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete + idle
    poolManager:SetLiveClearCall(liveConfig.liveName, this.testLiveGO, function ()
        SkeletonGraphic.AnimationState.Complete = SkeletonGraphic.AnimationState.Complete - idle
    end)
end
-- 初始化商品
function this.InitItems()
    -- 晶魂
    --local itemlist = ShopManager.GetShopDataByType(this.ShopType).storeItem
    local itemlist = OperatingManager.GetGiftGoodsInfoList(GoodsTypeDef.DemonCrystal)
    -- 重置列表
    this.ScrollView:SetData(itemlist, function(index, shopItem)
        local itemData = itemlist[index]
        this:ShopItemAdapter(shopItem, itemData)
    end)
end

-- 商店物品数据匹配
function this:ShopItemAdapter(shopItem, itemData)
    -- 获取对象
    local first = Util.GetGameObject(shopItem, "first")
    local firstNum = Util.GetGameObject(shopItem, "first/Text"):GetComponent("Text")
    local icon = Util.GetGameObject(shopItem, "icon"):GetComponent("Image")
    local num = Util.GetGameObject(shopItem, "box/jinghunNum"):GetComponent("Text")
    local price = Util.GetGameObject(shopItem, "price/Text"):GetComponent("Text")

    -- 计算数据
    local itemInfo = ShopManager.GetRechargeItemInfo(itemData.goodsId)
    icon.sprite = Util.LoadSprite(GetResourcePath(itemInfo.Resources))
    num.text = itemInfo.BaseReward[1][2]
    price.text = "¥" .. itemInfo.Price
    -- 判断首充赠送
    local curBuyCount = itemData.buyTimes
    first:SetActive(curBuyCount < 1)
    firstNum.text = itemInfo.FirstMultiple[1][2]

    -- 购买事件
    Util.AddOnceClick(shopItem, function()
        NetManager.RequestBuyGiftGoods(itemData.goodsId, function()
            FirstRechargeManager.RefreshAccumRechargeValue(itemData.goodsId)
            OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DemonCrystal, itemData.goodsId)
            this.InitItems()
        end)
    end)
end

--界面关闭时调用（用于子类重写）
function ShopPanel:OnClose()
end
--界面销毁时调用（用于子类重写）
function ShopPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
end

return ShopPanel