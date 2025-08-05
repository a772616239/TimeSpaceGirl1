---- 旅行商人 ----
require("Base/BasePanel")
local TreasureStorePopup = Inherit(BasePanel)
local this = TreasureStorePopup
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local itemsGrid = {}
local isPlayAnim = true

function TreasureStorePopup:InitComponent()
    this.Mask = Util.GetGameObject(this.gameObject,"Mask")
	this.panel = Util.GetGameObject(this.gameObject,"Panel")
    this.bg = Util.GetGameObject(this.panel,"Bg"):GetComponent("Image")
    this.backBtn = Util.GetGameObject(this.panel,"backBtn")
    this.time = Util.GetGameObject(this.panel,"Time"):GetComponent("Text")

    this.scroll = Util.GetGameObject(this.panel,"Scroll")
    this.scrollPre = Util.GetGameObject(this.scroll,"Pre")
    this.scrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scroll.transform,this.scrollPre, nil,
        Vector2.New(this.scroll.transform.rect.width,this.scroll.transform.rect.height),1,1,Vector2.New(0,20))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
end

function TreasureStorePopup:BindEvent()
    Util.AddClick(this.backBtn,function()
        self:ClosePanel()
    end)
    Util.AddClick(this.Mask,function()
        self:ClosePanel()
    end)
end

function TreasureStorePopup:AddListener()
end

function TreasureStorePopup:RemoveListener()
end

function TreasureStorePopup:OnOpen(type)
    this.type = type
    if this.type == ActivityTypeDef.TreasureStore then
        this.bg.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_lvxingshangren_diban"))
    elseif this.type == ActivityTypeDef.OpenServiceShop then
        this.bg.sprite = Util.LoadSprite(GetPictureFont("cn2-X1_xinfuremai_diban"))
    end
end

function TreasureStorePopup:OnShow()
    this:RefreshPanel()
    this:TimeCountDown()
    isPlayAnim = true
end

function TreasureStorePopup:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    CheckRedPointStatus(RedPointType.OpenServiceShop)
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

function TreasureStorePopup:OnDestroy()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    this.scrollView = nil
    itemsGrid = nil
end

--刷新面板
function TreasureStorePopup:RefreshPanel()
    local allData = {}
    local curActId = ActivityGiftManager.IsActivityTypeOpen(this.type)
    if not curActId then
        return
    end
    Util.GetGameObject(this.gameObject, "Panel/Bg/Image/Text"):GetComponent("Text").text = GetLanguageStrById(GlobalActivity[curActId].ExpertDec)
    local data = GlobalActivity[curActId].CanBuyRechargeId
    for i = 1, #data do
        local data = ConfigManager.GetConfigDataByKey(ConfigName.RechargeCommodityConfig, "Id", data[i])
        table.insert(allData,data)
    end
    if allData then
        allData = this.SortData(allData)
        local itemList = {}
        this.scrollView:SetData(allData, function (index, go)
            this:SetScrollPre(go, allData[index])
            itemList[index] = go
        end)
        DelayCreation(itemList)
    end
    if isPlayAnim then
        SecTorPlayAnimByScroll(this.scrollView)
        isPlayAnim = false
    end
    this.scrollView:SetIndex(1)
end

function this.SortData(allData)
    if allData == nil then
        return
    end
    table.sort(allData, function(a,b)
        local aboughtNum = a.Limit - OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, a.Id) > 0 and 2 or 1
        local bboughtNum = b.Limit - OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, b.Id) > 0 and 2 or 1
        if aboughtNum ==  bboughtNum then
            return a.Id < b.Id
        else
            return aboughtNum > bboughtNum
        end
    end)
    return allData
end

--设置每一条
function this:SetScrollPre(root,data)
    if isPlayAnim then
        root.gameObject:SetActive(false)
    else
        root.gameObject:SetActive(true)
    end
    local title = Util.GetGameObject(root,"Title/Title"):GetComponent("Text")
    local iRoot = Util.GetGameObject(root,"ItemRoot")
    local oldNum = Util.GetGameObject(root,"OldNum")
    oldNum:SetActive(false)
    local buyBtn = Util.GetGameObject(root,"BuyBtn")
    local buyNum = Util.GetGameObject(root,"BuyBtn/BuyNum"):GetComponent("Text")
    local tip = Util.GetGameObject(root,"Tip"):GetComponent("Text")
    local redpoint = Util.GetGameObject(root,"BuyBtn/redpoint")

    title.text = GetLanguageStrById(data.Name)
    local rewardArray = data.RewardShow
    if not itemsGrid then
        itemsGrid = {}
    end
    --滚动条复用重设itemview
    if not itemsGrid[root] then
        itemsGrid[root] = {}
    end
    for i = 1, #itemsGrid[root] do
        itemsGrid[root][i].gameObject:SetActive(false)
    end
    for i = 1, #rewardArray do
        if not itemsGrid[root][i] then
            itemsGrid[root][i] = SubUIManager.Open(SubUIConfig.ItemView, iRoot.transform)
        end
        itemsGrid[root][i]:OnOpen(false, {rewardArray[i][1],rewardArray[i][2]}, 0.7)
        itemsGrid[root][i].gameObject:SetActive(true)
    end

    local boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, data.Id) or 0

    tip.text = GetLanguageStrById(11454).." ".. ( data.Limit-boughtNum) .."/".. data.Limit
    if data.Limit - boughtNum > 0 then
        buyNum.text = MoneyUtil.GetMoney(data.Price)
        buyBtn:GetComponent("Button").enabled = true
        Util.SetGray(buyBtn, false)
    else
        buyNum.text = GetLanguageStrById(10526)
        buyBtn:GetComponent("Button").enabled = false
        Util.SetGray(buyBtn, true)
    end
    redpoint:SetActive(data.Price == 0 and data.Limit - boughtNum > 0)

    --local costId, finalNum, oriCostNum = ShopManager.calculateBuyCost(SHOP_TYPE.FINDTREASURE_GIFT, data.id, 1)
    Util.AddOnceClick(buyBtn, function()
        if data.Limit <= boughtNum then
            PopupTipPanel.ShowTipByLanguageId(10540)
        else
            --直购商品
            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = data.Id }, function(id)
                    this.RechargeSuccessFunc(id)
                end)
            else
                NetManager.RequestBuyGiftGoods(data.Id,function()
                    this.RechargeSuccessFunc(data.Id)
                end)
            end
        end
    end)
end

function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    this:RefreshPanel()
end

--倒计时
function this.TimeCountDown()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    local endtime = ActivityGiftManager.GetTaskEndTime(this.type)
    local timeDown = endtime - GetTimeStamp()
    this.time.text = GetLanguageStrById(50182)..TimeToHMS(timeDown)
    this.timer = Timer.New(function()
        if timeDown <= 0 then
            this.timer:Stop()
            this.timer = nil
            this.timer = Timer.New(function()
                this:RefreshPanel()
                this:TimeCountDown()
            end,1):Start()
            return
        end
        timeDown = timeDown - 1
        this.time.text =  GetLanguageStrById(50182)..TimeToHMS(timeDown)
    end, 1, -1, true)
    this.timer:Start()
end

return TreasureStorePopup