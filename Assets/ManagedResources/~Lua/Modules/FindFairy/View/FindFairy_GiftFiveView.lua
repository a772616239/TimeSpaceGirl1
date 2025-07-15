----- 东海寻仙-限时豪礼 -----
local this = {}
local sortingOrder
-- local activeData
local configData
local itemList={}
local ids

--按钮图片
local StateImageName={
    "s_slbz_1anniuongse","s_slbz_1anniuhuangse"
}

function this:InitComponent(gameObject)
    this.gameObject = gameObject
    this.panel=Util.GetGameObject(gameObject,"Panel")
    this.rewardPre=Util.GetGameObject(this.panel,"RewardPre")
    this.scrollRoot=Util.GetGameObject(this.panel,"ScrollRoot")
    this.timeText=Util.GetGameObject(this.panel,"TimeText"):GetComponent("Text")
    this.timer = Timer.New()

    this.scrollView=SubUIManager.Open(SubUIConfig.ScrollCycleView,this.scrollRoot.transform,
            this.rewardPre,nil,Vector2.New(this.scrollRoot.transform.rect.width,this.scrollRoot.transform.rect.height),
            1,1,Vector2.New(0,4))
    this.scrollView.moveTween.MomentumAmount = 1
    this.scrollView.moveTween.Strength = 2
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
    ids = FindFairyManager.GetGiftActiveBtnState(DirectBuyType.XSHL)
    this.OnShowPanelData()
end

function this:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

function this:OnDestroy()
    this.scrollView=nil
end

--显示面板
function this.OnShowPanelData()
    local activeData = FindFairyManager.GetGiftBtnState()
    this.RemainTimeDown(this.timeText,activeData[1].server.endTime - GetTimeStamp())
    if #activeData == 0 then return end

    this.scrollView:SetData(activeData,function(index,root)
        this.SetShow(root,activeData[index])
    end)
    this.scrollView:SetIndex(1)
end

--显示每条数据
function this.SetShow(root,data)
    local title=Util.GetGameObject(root,"Title"):GetComponent("Text")
    local content=Util.GetGameObject(root,"Content")
    local stateBtn=Util.GetGameObject(root,"StateBtn")
    local stateBtnImage=Util.GetGameObject(root,"StateBtn"):GetComponent("Image")
    local stateBtnText=Util.GetGameObject(root,"StateBtn/Text"):GetComponent("Text")
    local progress=Util.GetGameObject(root,"Progress"):GetComponent("Text")

    title.text=data.native.Name
    FindFairyManager.ResetItemView(root,content.transform,itemList,4,0.9,sortingOrder,false,data.native.RewardShow)

    stateBtn:GetComponent("Button").interactable=data.server.buyTimes< data.native.Limit
    if data.server.buyTimes< data.native.Limit then--未购买
        stateBtnImage.sprite=Util.LoadSprite(StateImageName[1])
        --> stateBtnText.text=data.native.Price..GetLanguageStrById(10538)
        stateBtnText.text=MoneyUtil.GetMoney(data.native.Price)
        
    else
        Util.SetGray(stateBtn,true)
        stateBtnText.text=GetLanguageStrById(10638)
    end
    Util.AddOnceClick(stateBtn,function()
        if AppConst.isSDKLogin then
            PayManager.Pay({ Id = data.native.Id }, function()
                FirstRechargeManager.RefreshAccumRechargeValue(data.native.Id)
                OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, data.native.Id)
                this.OnShowPanelData()
            end)
        else
            NetManager.RequestBuyGiftGoods(data.native.Id, function()
                FirstRechargeManager.RefreshAccumRechargeValue(data.native.Id)
                OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, data.native.Id)
                this.OnShowPanelData()
            end)
        end
    end)

    if data.native.Limit-data.server.buyTimes==0 then
        progress.text=GetLanguageStrById(10639)
    else
        progress.text=GetLanguageStrById(10535)..(data.native.Limit-data.server.buyTimes)
    end
end

--刷新倒计时显示
function this.RemainTimeDown(_timeTextExpert,timeDown)
    if timeDown > 0 then
        _timeTextExpert.enabled=true
        _timeTextExpert.text =   GetLanguageStrById(10028)..this.TimeStampToDateString(timeDown)
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            _timeTextExpert.text =   GetLanguageStrById(10028)..this.TimeStampToDateString(timeDown)
            if timeDown < 0 then
                _timeTextExpert.enabled=false
                this.timer:Stop()
                this.timer = nil
                configData=ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, ids[1])
                if configData.DailyUpdate~=1 then
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
        _timeTextExpert.enabled=false
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
return this