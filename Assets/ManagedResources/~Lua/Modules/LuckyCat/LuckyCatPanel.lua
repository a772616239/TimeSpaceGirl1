require("Base/BasePanel")
LuckyCatPanel = Inherit(BasePanel)
local luckyCatConfig = ConfigManager.GetConfig(ConfigName.LuckyCatConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local this = LuckyCatPanel
local listText = {}
local itemType = 0
local canRewardTime = 0
--初始化组件（用于子类重写）
function LuckyCatPanel:InitComponent()
    --this.rechargeContent=Util.GetGameObject(self.gameObject, "left/content")
    --this.rechargeText=Util.GetGameObject(self.gameObject, "left/rechargeText"):GetComponent("Text")
    --this.rechargeCurrentMoneyText=Util.GetGameObject(self.gameObject, "left/rechargeMoneyText"):GetComponent("Text")
    this.activityCountDownText = Util.GetGameObject(self.gameObject, "activityCountDownText"):GetComponent("Text")
    --this.getRewardLowIcon=Util.GetGameObject(self.gameObject, "middle/startDraw/lowImage/getRewardIcon"):GetComponent("Image")
    --this.getRewardLowNumber=Util.GetGameObject(self.gameObject, "middle/startDraw/lowImage/getRewardItemNumber"):GetComponent("Text")
    this.getRewardHighIcon = Util.GetGameObject(self.gameObject, "middle/startDraw/highImage/getRewardIcon"):GetComponent("Image")
    this.getRewardHighNumber = Util.GetGameObject(self.gameObject, "middle/startDraw/highImage/getRewardItemNumber"):GetComponent("Text")
    this.startDrawBtn = Util.GetGameObject(self.gameObject, "middle/startDraw/startDrawBtn")
    this.costIcon = Util.GetGameObject(self.gameObject, "middle/startDraw/highImage/costIcon"):GetComponent("Image")
    this.costItemNumber = Util.GetGameObject(self.gameObject, "middle/startDraw/highImage/costItemNumber"):GetComponent("Text")
    this.unitsText = Util.GetGameObject(self.gameObject, "middle/getRewardNumber/Image1/Text1"):GetComponent("Text") --个位
    this.tensText = Util.GetGameObject(self.gameObject, "middle/getRewardNumber/Image2/Text2"):GetComponent("Text") -- 十位
    this.hundredsText = Util.GetGameObject(self.gameObject, "middle/getRewardNumber/Image3/Text3"):GetComponent("Text") --百位
    this.thousandsText = Util.GetGameObject(self.gameObject, "middle/getRewardNumber/Image4/Text4"):GetComponent("Text") --千位
    this.tenThousandsText = Util.GetGameObject(self.gameObject, "middle/getRewardNumber/Image5/Text5"):GetComponent("Text") --万位
    this.popUpTextShow1 = Util.GetGameObject(self.gameObject, "popUpTextShow/Image/Text1"):GetComponent("Text")
    this.popUpTextShow2 = Util.GetGameObject(self.gameObject, "popUpTextShow/Image/Text2"):GetComponent("Text")
    this.popUpTextShow3 = Util.GetGameObject(self.gameObject, "popUpTextShow/Image/Text3"):GetComponent("Text")
    this.remainNumText = Util.GetGameObject(self.gameObject, "middle/startDraw/canRechargeTimebg/remainNumText"):GetComponent("Text")
    this.rechargeNumberText = Util.GetGameObject(self.gameObject, "middle/startDraw/canRechargeTimebg/rechargeNumberText"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.helpBtn=Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    this.redPoint= Util.GetGameObject(self.gameObject, "middle/startDraw/startDrawBtn/redPoint")
    listText = { this.popUpTextShow1, this.popUpTextShow2, this.popUpTextShow3 }
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    this.textShow = Util.GetGameObject(self.gameObject, "middle/startDraw/canRechargeTimebg/text"):GetComponent("Text")
    ---页面初始数据显示
    for i, v in ConfigPairs(luckyCatConfig) do
        if (LuckyCatManager.activityId == v.ActivityId) then
            --if(LuckyCatManager.rmbValue[i]>0) then
            --    local go = newObject(this.rechargeText)
            --    go.name = "rechargeText" .. i
            --    go.transform:SetParent(this.rechargeContent.transform)
            --    go.transform.localScale = Vector3.one
            --    go.transform.localPosition = Vector3.zero
            --    go.text="充值"..LuckyCatManager.rmbValue[i].."元可招财"..LuckyCatManager.luckyTime[i].."次"
            --end
            itemType = v.LuckyType
        end
    end
    --this.getRewardLowIcon.sprite= Util.LoadSprite(GetResourcePath(itemConfig[itemType].ResourceID))
    this.getRewardHighIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemType].ResourceID))
    this.costIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemType].ResourceID))
    this.anim = Util.GetGameObject(self.gameObject, "middle/getRewardNumber/anim")
    this.anim.transform.localPosition = Vector2.New(18, -58)
    this.popUpTextShow1.text = ""
    this.popUpTextShow2.text = ""
    this.popUpTextShow3.text = ""
    --this.NumView = SubUIManager.Open(SubUIConfig.NumberView, this.anim.transform, "r_fxgz_shuzi_", Vector2.New(80, 120), Vector2.New(50, 30), 0, 99999)
end

--绑定事件（用于子类重写）
function LuckyCatPanel:BindEvent()
    Util.AddClick(this.startDrawBtn, function()
        local getRewardNumber = LuckyCatManager.getRewardNumber + 1
        local haveItemNum = BagManager.GetItemCountById(itemType)
        local costItemNum = LuckyCatManager.consumeValue[getRewardNumber]
        if(costItemNum==nil or this.isEnter == false and (canRewardTime - LuckyCatManager.getRewardNumber)<=0) then
            PopupTipPanel.ShowTipByLanguageId(11133)
            return
        end
        if (LuckyCatManager.getRewardNumber >= canRewardTime) then
            --PopupTipPanel.ShowTip("剩余购买次数不足")
            if not ShopManager.IsActive(SHOP_TYPE.SOUL_STONE_SHOP) then
                PopupTipPanel.ShowTipByLanguageId(10438)
                return
            end
            UIManager.OpenPanel(UIName.MainRechargePanel, 1)
        else
            if (haveItemNum >= costItemNum) then
                LuckyCatManager.GetLuckyCatRequest()
            else
                --PopupTipPanel.ShowTip("道具不足")
                if(itemType==UpViewRechargeType.DemonCrystal) then
                    UIManager.OpenPanel(UIName.ShopExchangePopup, SHOP_TYPE.FUNCTION_SHOP, 10013, GetLanguageStrById(10646))
                elseif(itemType==20) then
                    UIManager.OpenPanel(UIName.OperatingPanel,{tabIndex =1,extraParam =2})
                else
                    UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = itemType })
                end
            end
        end
    end)
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    --帮助按钮
    Util.AddClick(this.helpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.FuXingGaoZhao,this.helpPosition.x,this.helpPosition.y)
    end)
end

function LuckyCatPanel:OnRefreshRedPoint()
    local getRewardNumber = LuckyCatManager.getRewardNumber + 1
    local haveItemNum = BagManager.GetItemCountById(itemType)
    local costItemNum = LuckyCatManager.consumeValue[getRewardNumber]
    if (haveItemNum >= costItemNum and LuckyCatManager.getRewardNumber < canRewardTime) then
        this.redPoint:SetActive(true)
    else
        this.redPoint:SetActive(false)
    end
end

--添加事件监听（用于子类重写）
function LuckyCatPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnLuckyCatRefresh, this.OnRefreshItemNumShow, true)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnLuckyCatWorldMessage, this.OnShowWorldMessage)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnLuckyCatRedRefresh, this.OnRefreshRedPoint)

end

--移除事件监听（用于子类重写）
function LuckyCatPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnLuckyCatRefresh, this.OnRefreshItemNumShow, true)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnLuckyCatWorldMessage, this.OnShowWorldMessage)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnLuckyCatRedRefresh, this.OnRefreshRedPoint)

end

--界面打开时调用（用于子类重写）
function LuckyCatPanel:OnOpen(...)


end
--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function LuckyCatPanel:OnShow()
    -- 开始定时刷新数据
    LuckyCatManager.StartLuckyCatDataUpdate()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = {14, 16, itemType}})
    this:OnRefresh()
    --this.rechargeCurrentMoneyText.text="当前已充值"..LuckyCatManager.hasRechargeNum.."元"
    this.OnRefreshItemNumShow(false)
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LuckyCat)
    if activityInfo then
        if activityInfo.endTime ~= 0 then
            self:LuckyCatActivitCountDawn(activityInfo.endTime - GetTimeStamp())
        end
    end
    if(not LuckyCatManager.isOpenLuckyCat) then
        self:ClosePanel()
    end
    LuckyCatManager.isEnterLuckyCat=true
    CheckRedPointStatus(RedPointType.LuckyCat_GetReward)
end

function LuckyCatPanel:OnRefresh()
    local getRewardNumber = LuckyCatManager.getRewardNumber + 1
    canRewardTime = LuckyCatManager.GetCanRewardTimes(LuckyCatManager.hasRechargeNum)
    if (getRewardNumber <= canRewardTime) then
    else
        getRewardNumber = canRewardTime
    end
    --this.getRewardLowNumber.text=LuckyCatManager.valueDown[getRewardNumber]
    this.getRewardHighNumber.text = "×" .. LuckyCatManager.valueUp[getRewardNumber]
    this.remainNumText.text = GetLanguageStrById(11134) .. (canRewardTime - LuckyCatManager.getRewardNumber) .. GetLanguageStrById(11135)
    this.costItemNumber.text = "×" .. LuckyCatManager.consumeValue[getRewardNumber]
    local againRechargeMoney = 0
    local canGetTime = 0
    this.isEnter = false
    for i, v in ConfigPairs(luckyCatConfig) do
        if (LuckyCatManager.activityId == v.ActivityId) then
            if (LuckyCatManager.rmbValue[i] > LuckyCatManager.hasRechargeNum) then
                againRechargeMoney = LuckyCatManager.rmbValue[i]-LuckyCatManager.hasRechargeNum
                canGetTime = LuckyCatManager.luckyTime[i] - LuckyCatManager.luckyTime[i - 1]
                this.isEnter = true
                break
            end
        end
    end
    this.rechargeNumberText.text = string.format("<color=#FDC257>%s</color>", againRechargeMoney) .. GetLanguageStrById(11136) .. string.format(GetLanguageStrById(11137), canGetTime)
    if (this.isEnter == false) then
        this.rechargeNumberText.text = ""
        this.textShow.text = ""
    end
    if(this.isEnter == false and (canRewardTime - LuckyCatManager.getRewardNumber)<=0) then
        Util.SetGray(this.startDrawBtn, true)
    end

    local getRewardNumber = LuckyCatManager.getRewardNumber + 1
    local haveItemNum = BagManager.GetItemCountById(itemType)
    local costItemNum = LuckyCatManager.consumeValue[getRewardNumber]
    if(costItemNum) then
        if (haveItemNum >= costItemNum and LuckyCatManager.getRewardNumber < canRewardTime) then
            this.redPoint:SetActive(true)
        else
            this.redPoint:SetActive(false)
        end
    else
        this.redPoint:SetActive(false)
    end
end

--刷新获取物品数量显示
function LuckyCatPanel:OnRefreshItemNumShow(playAnim)
    if (playAnim) then
        --刷新显示数据
        this:OnRefresh()
        this.startDrawBtn:GetComponent("Button").enabled = false
        LuckyCatManager.isCanGetWorldMessage=false
        --ToDo动画显示
        --this.NumView:SetNum(0)
        -- this.NumView:DOItemNum(LuckyCatManager.dropNumbers, function(index, num, item)
        --     item:Move(tostring(num), index * 0.5 + 2, true, 3)

        -- end)
        local timerEffect = Timer.New(function()
            UIManager.OpenPanel(UIName.RewardItemPopup, LuckyCatManager.drop, 1)
            this.startDrawBtn:GetComponent("Button").enabled = true
            LuckyCatManager.isCanGetWorldMessage=true
        end, 5, 1, true)
        timerEffect:Start()


        --this.unitsText.text=LuckyCatManager.unitsText --个位
        --this.tensText.text=LuckyCatManager.tensText -- 十位
        --this.hundredsText.text=LuckyCatManager.hundredsText --百位
        --this.thousandsText.text=LuckyCatManager.thousandsText --千位
        --this.tenThousandsText.text=LuckyCatManager.tenThousandsText --万位
    else
        this.unitsText.text = LuckyCatManager.unitsText --个位
        this.tensText.text = LuckyCatManager.tensText -- 十位
        this.hundredsText.text = LuckyCatManager.hundredsText --百位
        this.thousandsText.text = LuckyCatManager.thousandsText --千位
        this.tenThousandsText.text = LuckyCatManager.tenThousandsText --万位
    end

end


--界面关闭时调用（用于子类重写）
function LuckyCatPanel:OnClose()
    if self.timer then
        self.timer:Stop()
    end
    LuckyCatManager.StopLuckyCatUpdate()
end

--活动时间倒计时
function LuckyCatPanel:LuckyCatActivitCountDawn(timeDown)
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    this.activityCountDownText.text = DateUtils.GetTimeFormatV2(timeDown)
    self.timer = Timer.New(function()
        this.activityCountDownText.text = DateUtils.GetTimeFormatV2(timeDown)
        if timeDown <= 0 then
            self.timer:Stop()
            self.timer = nil
            self:ClosePanel()
        end
        timeDown = timeDown - 1
    end, 1, -1, true)
    self.timer:Start()
end

--跑马灯显示
function LuckyCatPanel:OnShowWorldMessage()
    local messageList = {}
    messageList = LuckyCatManager.worldMessageData
    for i, v in ipairs(listText) do
        if (messageList[i] ~= nil) then
            listText[i].text = messageList[i]
        else
            listText[i].text = ""
        end
    end
end


--界面销毁时调用（用于子类重写）
function LuckyCatPanel:OnDestroy()
    SubUIManager.Close(this.UpView)
end

return LuckyCatPanel