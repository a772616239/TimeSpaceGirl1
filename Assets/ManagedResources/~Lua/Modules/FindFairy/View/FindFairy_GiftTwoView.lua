----- 东海寻仙-每日仙缘礼 -----
local this = {}

local preGrid = {}
local itemRewardGrid = {}
local sortingOrder = 0

function this:InitComponent(gameObject)
    this.gameObject = gameObject
    this.panel=Util.GetGameObject(gameObject,"Panel")
    this.timeGo=Util.GetGameObject(this.panel,"Time")
    this.time=Util.GetGameObject(this.panel,"Time"):GetComponent("Text")
    for i = 1, 3 do
        preGrid[i] = Util.GetGameObject(self.gameObject, "downGo/grid/pre ("..i..")")
        local curexpertRewardItemsGri = {}
        for j = 1, 3 do
            curexpertRewardItemsGri[j] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(preGrid[i], "itemRewardParent").transform)
        end
        itemRewardGrid[i] = curexpertRewardItemsGri
    end
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
    this.OnShowPanel()
end

local ids
function this.OnShowPanel()
    
    ids = FindFairyManager.GetGiftActiveBtnState(DirectBuyType.MRXY)
    for i = 1, #ids do
        this.OnShowPanelData(i)
    end
end

function this.OnShowPanelData(i)
    if not preGrid[i] then
        return
    end
    local conFigData = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, ids[i])
    local shopItemData = OperatingManager.GetGiftGoodsInfo(conFigData.Type,conFigData.Id)
    if shopItemData == nil then  return end
    
    this.RemainTimeDown(this.timeGo,this.time,shopItemData.endTime - GetTimeStamp())
    local oldPurchaseText=Util.GetGameObject(preGrid[i],"oldPurchase/oldPurchaseText"):GetComponent("Text")
    local curPurchaseText=Util.GetGameObject(preGrid[i],"BuyBtn/curPurchaseText"):GetComponent("Text")
    local itemRewardParent=Util.GetGameObject(preGrid[i],"itemRewardParent")
    local buyBtn=Util.GetGameObject(preGrid[i],"BuyBtn")
    local buyNumText=Util.GetGameObject(preGrid[i],"buyNumText"):GetComponent("Text")
    --> oldPurchaseText.text = GetLanguageStrById(10643)..conFigData.Price/(conFigData.IsDiscount/10)..GetLanguageStrById(10538)
    oldPurchaseText.text = GetLanguageStrById(10643).. MoneyUtil.GetCurrencyUnit() .. (MoneyUtil.GetPrice(conFigData.Price)/(conFigData.IsDiscount/10))

    buyNumText.text = GetLanguageStrById(10556)..shopItemData.buyTimes.."/"..conFigData.Limit
    
    if shopItemData.buyTimes <= 0  then
        --> curPurchaseText.text = conFigData.Price..GetLanguageStrById(10538)
        curPurchaseText.text = MoneyUtil.GetMoney(conFigData.Price)
        
        buyBtn:GetComponent("Button").enabled = true
        Util.SetGray(buyBtn, false)
    else
        curPurchaseText.text = GetLanguageStrById(10526)
        buyBtn:GetComponent("Button").enabled = false
        Util.SetGray(buyBtn, true)
    end

    for j = 1, math.max(#conFigData.BaseReward, #itemRewardGrid[i]) do
        local go = itemRewardGrid[i][j]
        if not go then
            if not go then
                go = SubUIManager.Open(SubUIConfig.ItemView, itemRewardParent.transform)
                itemRewardGrid[i][j] = go
            end
            go.gameObject:SetActive(false)
        end
    end
    for j = 1, #conFigData.BaseReward do
        itemRewardGrid[i][j].gameObject:SetActive(true)
        itemRewardGrid[i][j]:OnOpen(false,conFigData.BaseReward[j],0.75,false,false,false,sortingOrder)
    end

    Util.AddOnceClick(buyBtn, function()
        if shopItemData.buyTimes <= 0 then
            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = conFigData.Id }, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(conFigData.Id)
                    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, conFigData.Id)
                    this.OnShowPanel()
                end)
            else
                NetManager.RequestBuyGiftGoods(conFigData.Id, function()
                    FirstRechargeManager.RefreshAccumRechargeValue(conFigData.Id)
                    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, conFigData.Id)
                    this.OnShowPanel()
                end)
            end
        end
    end)
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
            if this.TimeStampToOneDay(timeDown) <= 1 then
                _timeTextExpertgo:SetActive(false)
                this.timer:Stop()
                this.timer = nil
                local config = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, ids[1])
                -- if config.DailyUpdate~=1 then --不是每日刷新 显示活动结束操作
                --     PopupTipPanel.ShowTip("活动已结束！")
                --     require("Modules/FindFairy/FindFairyPanel"):OnShow()
                -- else
                if(timeDown<=1) then
                    PopupTipPanel.ShowTipByLanguageId(10029)
                    FindFairyManager.isOver=true
                    require("Modules/FindFairy/FindFairyPanel"):OnShow()
                else
                    this:OnShow(sortingOrder)
                end
                -- end
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        _timeTextExpertgo:SetActive(false)
    end
end

function this.TimeStampToOneDay(second)
    local day = math.floor(second / (24 * 3600))
    local sec = second % 60
    local minute = math.floor(second / 60) % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    local sum=hour*3600+minute*60+sec
    return sum
end

function this.TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format("%02d:%02d:%02d", hour, minute, sec)
end
function this.RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, id)
    this.OnShowPanel()
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