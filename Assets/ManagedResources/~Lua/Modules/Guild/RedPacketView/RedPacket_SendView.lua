----- 公会红包-发红包 -----
local this = {}
local sortingOrder = 0
--按钮类型
local BtnType = {
    Left = 1,
    Right = 2,
}
--红包资源名
-- local RedPacketName = {"cn2-X1_gonghui_hongbao_01_zh","cn2-X1_gonghui_hongbao_02_zh","cn2-X1_gonghui_hongbao_03_zh"}
local RedPacketBg = {"cn2-X1_gonghui_hongbao_01_zh","cn2-X1_gonghui_hongbao_02_zh","cn2-X1_gonghui_hongbao_03_zh"}

local index = {42,43,44}--直购表红包索引，因表没有区分红包列，故暂时写死
local curIndex = 1 --当前选中红包索引

function this:InitComponent(gameObject)
    this.sendBtn = Util.GetGameObject(gameObject,"SendBtn")
    this.sendBtnText = Util.GetGameObject(gameObject,"SendBtn/Text"):GetComponent("Text")
    this.leftBtn = Util.GetGameObject(gameObject,"LeftBtn")
    this.rightBtn = Util.GetGameObject(gameObject,"RightBtn")

    this.surplusNum = Util.GetGameObject(gameObject,"SurplusNum/num"):GetComponent("Text")--今日还可发

    this.numText = Util.GetGameObject(gameObject,"Num/NumText"):GetComponent("Text")--红包金额
    this.numIcon = Util.GetGameObject(gameObject,"Num/Icon"):GetComponent("Image")--消耗道具

    this.countText = Util.GetGameObject(gameObject,"Count/CountText"):GetComponent("Text")--红包个数
    this.message = Util.GetGameObject(gameObject,"Message/MessageText"):GetComponent("Text")--红包寄语

    this.rewardRoot = Util.GetGameObject(gameObject,"Reward/RewardRoot")--发放者奖励根节点
    this.itemList = {} --奖励容器

     --- 红包选择 ---
    this.dragView = Util.GetGameObject(gameObject, "Dragview")
    this.dragViewGrid = Util.GetGameObject(this.dragView, "Grid")

    this.scaleCurve = this.dragViewGrid:GetComponent(typeof(AnimationCurveContainer)).AnimDatas[0]
    this.posYCurve = this.dragViewGrid:GetComponent(typeof(AnimationCurveContainer)).AnimDatas[1]--

    this.dragViewItem = Util.GetGameObject(this.dragView, "Item")--预设

    this.moveWidth = 494
    this.count = 3

    this.ItemList = {}
    this.SortLayerList = {}


    for i = 1, this.count do
        local go = newObject(this.dragViewItem)
        go.name = "Item"..i
        go.transform:SetParent(this.dragViewGrid.transform)
        go.transform.localScale = Vector3.one
        go.transform.localPosition = Vector3.zero

        local off = i / this.count - 0.5
        local tran = go:GetComponent("RectTransform")

        go:GetComponent("RectTransform").anchoredPosition = Vector2.New(off * this.moveWidth , this.posYCurve:Evaluate(i / this.count) * 500)
        tran.localScale = Vector3.one * this.scaleCurve:Evaluate(i / this.count)

        this.ItemList[i] = {go = go, tran = tran, off = off}
        this.SortLayerList[i] = {index = i, off = this.ItemList[i].off}

        --  local nameImage = Util.GetGameObject(go,"NameImage"):GetComponent("Image")
        --  local desc=Util.GetGameObject(go,"Desc"):GetComponent("Text")--描述
        local icon = Util.GetGameObject(go,"Icon"):GetComponent("Image")
        local config = ConfigManager.GetConfigData(ConfigName.GuildRedPackConfig,i)
        --  nameImage.sprite=Util.LoadSprite(RedPacketName[i])
         icon.sprite = Util.LoadSprite(RedPacketBg[i])
        --  desc.text=config.Desc
    end
    this.dragViewItem:SetActive(false)

    this.trigger = Util.GetEventTriggerListener(this.dragViewGrid) --触摸事件
    this.trigger.onBeginDrag = this.trigger.onBeginDrag + this.OnBeginDrag
    this.trigger.onDrag = this.trigger.onDrag + this.OnDrag
    this.trigger.onEndDrag = this.trigger.onEndDrag + this.OnEndDrag


    this.moveTween = this.dragViewGrid:GetComponent(typeof(UITweenSpring))
    if not this.moveTween then
        this.moveTween = this.dragViewGrid:AddComponent(typeof(UITweenSpring))
    end
    this.moveTween.enabled = false
    this.moveTween.OnUpdate = this.SetPos
    this.moveTween.OnMoveEnd = this.MoveTo
    this.moveTween.MomentumAmount = 0.5
    this.moveTween.Strength = 1

    --  Util.AddClick(Util.GetGameObject(this.dragView, "lBtn"), function()
    --      this.MoveTween(-1/this.count)
    --  end)
    --  Util.AddClick(Util.GetGameObject(this.dragView, "rBtn"), function()
    --      this.MoveTween(1/this.count)
    --  end)
     --红包选择 end---
end

function this:BindEvent()
    --右按钮
    Util.AddClick(this.leftBtn,function()
        this:SwitchPacketShow(BtnType.Left)
    end)
    --左按钮
    Util.AddClick(this.rightBtn,function()
        this:SwitchPacketShow(BtnType.Right)
    end)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
    Game.GlobalEvent:AddEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, this.InitView)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, this.RechargeSuccessFunc)
    Game.GlobalEvent:RemoveEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, this.InitView)
end

function this:OnShow(_sortingOrder)
    sortingOrder = _sortingOrder
    this:InitView()
end

function this:OnClose()
end

function this:OnDestroy()
end

---初始化面板
function this:InitView()
    curIndex = 1
    this.SetInfo(1)
    this.MoveTween(-this.ItemList[1].off)
end

---点击按钮 切换红包
function this:SwitchPacketShow(type)
    if type == BtnType.Left then
        curIndex = curIndex-1
        if curIndex < 1 then curIndex = 3 end
        this.MoveTween(1 / this.count)
    elseif type == BtnType.Right then
        curIndex = curIndex+1
        if curIndex > 3 then curIndex = 1 end
        this.MoveTween(-1 / this.count)
    end
    this.SetInfo(curIndex)
end

---设置红包信息 id-红包Id
function this.SetInfo(id)
    local redpack = ConfigManager.GetConfigData(ConfigName.GuildRedPackConfig,id)
    local recharge = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,index[id])

    local surplusNum = OperatingManager.GetLeftBuyTime(GoodsTypeDef.GuildRedPacket,index[id])--今日可发数
    if surplusNum > 0 then
        this.surplusNum.text = surplusNum --GetLanguageStrById(11075)..surplusNum.."</color>)"
    else
        this.surplusNum.text = surplusNum --GetLanguageStrById(11076)..surplusNum.."</color>)"
    end

    this.numText.text = redpack.TotalMoney[2]
    this.numIcon.sprite = SetIcon(redpack.TotalMoney[1])
    this.countText.text = redpack.Num
    this.message.text = GetLanguageStrById(redpack.SendWord)

    FindFairyManager.ResetItemView(this.rewardRoot,this.rewardRoot.transform,this.itemList,4,0.8,sortingOrder,false,recharge.BaseReward)

    this.sendBtn:GetComponent("Button").interactable = surplusNum > 0
    Util.SetGray(this.sendBtn, surplusNum < 1)
    
    this.sendBtnText.text = MoneyUtil.GetMoney(recharge.Price) .. " " .. GetLanguageStrById(11062)

    --发红包按钮
    Util.AddOnceClick(this.sendBtn,function()
        if surplusNum < 1 then return end
        local recharge = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig,index[id])
        if AppConst.isSDKLogin then
            PayManager.Pay({ Id = recharge.Id}, function()
                FirstRechargeManager.RefreshAccumRechargeValue(recharge.Id)
                OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.GuildRedPacket, recharge.Id)
                this.SetInfo(curIndex)
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11078), GetLanguageStrById(redpack.Name)))
                ChatManager.RequestSendRedPacket(curIndex)
            end)
        else
            NetManager.RequestBuyGiftGoods(recharge.Id, function()
                FirstRechargeManager.RefreshAccumRechargeValue(recharge.Id)
                OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.GuildRedPacket, recharge.Id)
                this.SetInfo(curIndex)
                PopupTipPanel.ShowTip(string.format(GetLanguageStrById(11078), GetLanguageStrById(redpack.Name)))
                ChatManager.RequestSendRedPacket(curIndex)
            end)
        end
    end)
end

function this.OnBeginDrag(Pointgo, data)
    this.moveTween.enabled = true
    this.moveTween.Momentum = Vector3.zero
    this.moveTween.IsUseCallBack = false
end
function this.OnDrag(Pointgo, data)
    this.moveTween:LerpMomentum(data.delta)
    this.SetPos(data.delta)
end
function this.OnEndDrag(Pointgo, data)
    this.SetPos(data.delta)
    this.moveTween.IsUseCallBack = true
end
---设置位置
function this.SetPos(v2)
    for i = 1, this.count do
        local item = this.ItemList[i]
        item.off = item.off + v2.x / this.moveWidth
        if item.off > 0.5 then
            item.off = item.off - 1
            this.SortLayerList[i].off = item.off
            this.SetSortLayer()
        elseif item.off < -0.5 then
            item.off = item.off + 1
            this.SortLayerList[i].off = item.off
            this.SetSortLayer()
        else
            this.SortLayerList[i].off = item.off
        end
        item.tran.anchoredPosition = Vector2.New(item.off * this.moveWidth , this.posYCurve:Evaluate(item.off + 0.5) * 500)
        item.tran.localScale = Vector3.one * this.scaleCurve:Evaluate(item.off + 0.5)
    end
end
---设置层级
function this.SetSortLayer()
    table.sort(this.SortLayerList, function(i1,i2) return math.abs(i1.off) > math.abs(i2.off) end)
    for i = 1, this.count do
        local index = this.SortLayerList[i].index
        local item = this.ItemList[index]
        item.tran:SetAsLastSibling()
    end
    table.sort(this.SortLayerList, function(i1,i2) return i1.index < i2.index end)
end
---手指拖动结束 ui归位
function this.MoveTo()
    local d = 1
    local targetIdx
    for i = 1, this.count do
        local item = this.ItemList[i]

        local dd = math.abs(this.ItemList[i].off)
        if dd < d then
            targetIdx = i
            d = dd
        end
    end
    curIndex=targetIdx
    this.MoveTween(-this.ItemList[targetIdx].off)
    this.SetInfo(targetIdx)
end
---动画移动
function this.MoveTween(moveDelta)
    local lastProgress = 0
    DoTween.To(DG.Tweening.Core.DOGetter_float( function () return 0 end),
    DG.Tweening.Core.DOSetter_float(function (progress)
        local d = progress - lastProgress
        lastProgress = progress
        this.SetPos(Vector2.New(d * this.moveWidth, 0))
    end), moveDelta, 0.2):SetEase(Ease.Linear):OnComplete(this.SetSortLayer)
end

---直购成功回调
function this:RechargeSuccessFunc(id)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DirectPurchaseGift, id)
    local redpack = ConfigManager.GetConfigData(ConfigName.GuildRedPackConfig,curIndex)
    this.SetInfo(curIndex)
    PopupTipPanel.ShowTip(string.format( GetLanguageStrById(11078), GetLanguageStrById(redpack.Name)))
    ChatManager.RequestSendRedPacket(curIndex)
end

return this