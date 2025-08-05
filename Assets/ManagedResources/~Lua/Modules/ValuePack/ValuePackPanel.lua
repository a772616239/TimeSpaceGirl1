require("Base/BasePanel")
ValuePackPanel = Inherit(BasePanel)
local this = ValuePackPanel

local shopType = {
    801,--契约
    802,--守护
    803,--金钱
    804,--英雄培养
    805
}
local boxImage = {
    "cn2-X1_chaozhilibao_qiyuejingshen",
    "cn2-X1_chaozhilibao_shouhuqianghua",
    "cn2-X1_chaozhilibao_jinqianduoduo",
    "cn2-X1_chaozhilibao_yingxiongpeiyang",
    "cn2-X1_chaozhilibao_jiyinpeiyang",
}
this.ItemList = {}

function ValuePackPanel:InitComponent()
    this.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform)

    this.backBtn = Util.GetGameObject(this.gameObject, "Bg/down/backBtn")
    this.prefab = Util.GetGameObject(this.gameObject, "Bg/prefab")
    this.scroll = Util.GetGameObject(this.gameObject, "Bg/scroll")

    local rootWidth = this.scroll.transform.rect.width
    local rootHeight = this.scroll.transform.rect.height
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.scroll.transform,this.prefab, nil, Vector2.New(rootWidth, rootHeight), 1, 1, Vector2.New(0,10))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2

    this.sellOut = Util.GetGameObject(this.gameObject, "Bg/sellOut")--售罄
    this.time = Util.GetGameObject(this.gameObject, "Bg/down/time"):GetComponent("Text")
end

function ValuePackPanel:BindEvent()
    Util.AddClick(this.backBtn, function()
        self:ClosePanel()
    end)
end

function ValuePackPanel:OnOpen()

end

function ValuePackPanel:OnShow()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })
    ValuePackPanel:SetDataList()
    this.time.text = GetLanguageStrById(10028) .. TimeToHMS(CalculateSecondsNowTo_N_OClock(24))
    ValuePackPanel:CountDown()
end

--设置数据
function ValuePackPanel:SetDataList()
    CheckRedPointStatus(RedPointType.ValuePack)
    local dataList = {}
    for _i, v in ipairs(shopType) do
        repeat
        local config = ConfigManager.GetConfigDataByKey(ConfigName.StoreTypeConfig, "Id", v)
        if config.OpenLevel and config.OpenLevel[1] == 3 then
            if not ActTimeCtrlManager.SingleFuncState(config.OpenLevel[2]) then
                break
            end
        end

        local storeData = ConfigManager.GetAllConfigsDataByKey(ConfigName.StoreConfig, "StoreId", v)
        table.sort(storeData, function(a,b)
            return a.Sort < b.Sort
        end)
        local data = ValuePackPanel:GetData(storeData)
        table.insert(dataList, data)
        until true
    end

    this.ScrollView:SetData(dataList, function (index, go)
        this.SetItemInfo(go, dataList[index], index)
    end)

    this.sellOut:SetActive(#dataList == 0)
end

--若没购买则显示 每一类型礼包显示一个
function ValuePackPanel:GetData(storeData)
    for index, value in ipairs(storeData) do
        local buyNum = ShopManager.GetShopItemData(value.StoreId, value.Id).buyNum
        if buyNum == 0 then
            return value
        end
    end
end

--设置每一条信息
function ValuePackPanel.SetItemInfo(go, data, index)
    local name = Util.GetGameObject(go, "title/name"):GetComponent("Text")
    local limit = Util.GetGameObject(go, "title/limit/Text"):GetComponent("Text")
    local box = Util.GetGameObject(go, "boxImage"):GetComponent("Image")
    local discount = Util.GetGameObject(go, "boxImage/discount"):GetComponent("Text")--折扣
    local ItemGrid = Util.GetGameObject(go, "ItemGrid")
    local curPrice = Util.GetGameObject(go, "curPrice/price"):GetComponent("Text")--初始价格
    local buyBtn = Util.GetGameObject(go, "buyBtn")
    local price = Util.GetGameObject(go, "buyBtn/price"):GetComponent("Text")
    local discountBg = Util.GetGameObject(go, "boxImage/discountBg")
    local redpoint = Util.GetGameObject(go, "buyBtn/redpoint")

    name.text = GetLanguageStrById(data.GoodsName)
    limit.text = GetLanguageStrById(data.Desc)
    box.sprite = Util.LoadSprite(boxImage[index])

    curPrice.text = data.Rebate
    price.text = data.Cost[2][4]
    -- 折扣为0时不显示
    if data.Cost[2][4] == 0 then
        discountBg:SetActive(false)
        discount.text = ""
        redpoint:SetActive(true)
    else
        discountBg:SetActive(true)
        discount.text = 100-string.format("%.0f",(data.Cost[2][4]/data.Rebate)*100).."%"
        redpoint:SetActive(false)
    end
    if this.ItemList[go] then
        for i = 1, #this.ItemList[go] do
            if this.ItemList[go][i] then
                this.ItemList[go][i].gameObject:SetActive(false)
            end
        end
        for i = 1, #data.Goods do
            if this.ItemList[go][i] then
                this.ItemList[go][i]:OnOpen(false, {data.Goods[i][1], data.Goods[i][2]}, 0.8)
                this.ItemList[go][i].gameObject:SetActive(true)
            end
        end
    else
        this.ItemList[go] = {}
        for i = 1, #data.Goods do
            this.ItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, ItemGrid.transform)
            this.ItemList[go][i]:OnOpen(false, {data.Goods[i][1], data.Goods[i][2]}, 0.8)
        end
    end

    Util.AddOnceClick(buyBtn, function ()
        ShopManager.RequestBuyShopItem(data.StoreId, data.Id, 1, function ()
            ValuePackPanel:SetDataList()
        end)
    end)
end

--重置时间倒计时
function ValuePackPanel:CountDown()
    if this.localTimer then
        this.localTimer:Stop()
        this.localTimer = nil
    end
    if not this.localTimer then
        this.localTimer = Timer.New(function ()
            local t = CalculateSecondsNowTo_N_OClock(24)
            this.time.text = GetLanguageStrById(10028) .. TimeToHMS(t)
        end, 1, -1, true)
        this.localTimer:Start()
    end
end

function ValuePackPanel:OnClose()
    PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
end

function ValuePackPanel:OnDestroy()
    if this.localTimer then
        this.localTimer:Stop()
        this.localTimer = nil
    end
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)
end

return ValuePackPanel