----- 东海寻仙-天官赐福 -----
local this = {}
local shopItemData
local conFigData
local itemRewardGrid = {}
local sortingOrder = 0

function this:InitComponent(gameObject)
    this.gameObject = gameObject
    this.panel=Util.GetGameObject(gameObject,"Panel")
    this.timeGo=Util.GetGameObject(this.panel,"Time")
    this.oldPurchaseText=Util.GetGameObject(this.panel,"downGo/purchase/old/oldPurchaseText"):GetComponent("Text")
    this.curPurchaseText=Util.GetGameObject(this.panel,"downGo/purchase/cur/curPurchaseText"):GetComponent("Text")
    this.itemRewardParent=Util.GetGameObject(this.panel,"downGo/itemRewardParent")
    this.buyBtn=Util.GetGameObject(this.panel,"downGo/BuyBtn")
    this.buyNumText=Util.GetGameObject(this.panel,"downGo/BuyBtn/buyNumText"):GetComponent("Text")
    this.buyText=Util.GetGameObject(this.panel,"downGo/BuyBtn/Text"):GetComponent("Text")
    for i = 1, 4 do
        itemRewardGrid[i] = SubUIManager.Open(SubUIConfig.ItemView, this.itemRewardParent.transform)
    end
    this.timeGo=Util.GetGameObject(this.panel,"downGo/Time")
    this.time=Util.GetGameObject(this.panel,"downGo/Time"):GetComponent("Text")
end

function this:BindEvent()

end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
end

function this:OnShow(_sortingOrder)
    sortingOrder = _sortingOrder
    this.OnShowPanelData()
end

function this.OnShowPanelData()
    local ids = FindFairyManager.GetGiftActiveBtnState(DirectBuyType.TGCF)
    if ids and #ids > 0 then
    else
        return
    end
    conFigData = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,ids[1] )
    shopItemData = OperatingManager.GetGiftGoodsInfo(conFigData.Type,conFigData.Id)
    if shopItemData == nil then  return end
    --> this.oldPurchaseText.text = GetLanguageStrById(10537)..conFigData.Price/(conFigData.IsDiscount/10)..GetLanguageStrById(10538)
    this.oldPurchaseText.text = GetLanguageStrById(10537)..MoneyUtil.GetCurrencyUnit() .. (MoneyUtil.GetPrice(conFigData.Price)/(conFigData.IsDiscount/10))
    --> this.curPurchaseText.text = GetLanguageStrById(10640)..conFigData.Price..GetLanguageStrById(10538)
    this.curPurchaseText.text = GetLanguageStrById(10640)..MoneyUtil.GetMoney(conFigData.Price)
    this.buyNumText.text = GetLanguageStrById(10556)..shopItemData.buyTimes.."/"..conFigData.Limit
    if shopItemData.buyTimes <= 0  then
        this.buyText.text = GetLanguageStrById(10641)
        this.buyBtn:GetComponent("Button").enabled = true
        Util.SetGray(this.buyBtn, false)
    else
        this.buyText.text = GetLanguageStrById(10526)
        this.buyBtn:GetComponent("Button").enabled = false
        Util.SetGray(this.buyBtn, true)
    end

    for i = 1, math.max(#conFigData.BaseReward, #itemRewardGrid) do
        local go = itemRewardGrid[i]
        if not go then
            if not go then
                go = SubUIManager.Open(SubUIConfig.ItemView, this.itemRewardParent.transform)
                itemRewardGrid[i] = go
            end
            go.gameObject:SetActive(false)
        end
    end
    for i = 1, #conFigData.BaseReward do
        itemRewardGrid[i].gameObject:SetActive(true)
        itemRewardGrid[i]:OnOpen(false,conFigData.BaseReward[i],1.1,false,false,false,sortingOrder)
    end
    Util.AddOnceClick(this.buyBtn, function()
        if shopItemData.buyTimes <= 0 then
            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = conFigData.Id }, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(conFigData.Id)
                    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, conFigData.Id)
                    this.OnShowPanelData()
                end)
            else
                NetManager.RequestBuyGiftGoods(conFigData.Id, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(conFigData.Id)
                    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, conFigData.Id)
                    this.OnShowPanelData()
                end)
            end
        end
    end)
    this.RemainTimeDown(this.timeGo,this.time,shopItemData.endTime - GetTimeStamp())
end

this.timer = Timer.New()
--刷新倒计时显示
function this.RemainTimeDown(_timeTextExpertgo,_timeTextExpert,timeDown)
    if timeDown > 0 then
        _timeTextExpertgo:SetActive(true)
        _timeTextExpert.text =   GetLanguageStrById(10028)..this.TimeStampToDateString(timeDown)
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            _timeTextExpert.text =   GetLanguageStrById(10028)..this.TimeStampToDateString(timeDown)
            if timeDown < 0 then
                _timeTextExpertgo:SetActive(false)
                this.timer:Stop()
                this.timer = nil
                if conFigData.DailyUpdate~=1 then --不是每日刷新 显示活动结束操作
                    PopupTipPanel.ShowTipByLanguageId(10029)
                    require("Modules/FindFairy/FindFairyPanel"):OnShow()
                else
                    this:OnShow(sortingOrder)
                end
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        _timeTextExpertgo:SetActive(false)
    end
end

function this.TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(10548),day, hour, minute, sec)
end

function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, id)
    this.OnShowPanelData()
end

function this:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

function this:OnDestroy()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

return this