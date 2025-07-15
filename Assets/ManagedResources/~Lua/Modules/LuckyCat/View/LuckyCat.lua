local LuckyCat = quick_class("LuckyCat")
function LuckyCat:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

local this = LuckyCat
local luckyCatConfig = ConfigManager.GetConfig(ConfigName.LuckyCatConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local listText = {}
local itemType = 0
local canRewardTime = 0
this.UpView = nil
local expertPanel = nil
function LuckyCat:InitComponent(gameObject)
    this.activityCountDownText = Util.GetGameObject(gameObject, "activityCountDownText"):GetComponent("Text")
    this.getRewardHighIcon = Util.GetGameObject(gameObject, "middle/startDraw/highImage/getRewardIcon"):GetComponent("Image")
    this.getRewardHighNumber = Util.GetGameObject(gameObject, "middle/startDraw/highImage/getRewardItemNumber"):GetComponent("Text")
    this.startDrawBtn = Util.GetGameObject(gameObject, "middle/startDraw/startDrawBtn")
    this.costIcon = Util.GetGameObject(gameObject, "middle/startDraw/highImage/costIcon"):GetComponent("Image")
    this.costItemNumber = Util.GetGameObject(gameObject, "middle/startDraw/highImage/costItemNumber"):GetComponent("Text")
    this.unitsText = Util.GetGameObject(gameObject, "middle/getRewardNumber/Image1/Text1"):GetComponent("Text") --个位
    this.tensText = Util.GetGameObject(gameObject, "middle/getRewardNumber/Image2/Text2"):GetComponent("Text") -- 十位
    this.hundredsText = Util.GetGameObject(gameObject, "middle/getRewardNumber/Image3/Text3"):GetComponent("Text") --百位
    this.thousandsText = Util.GetGameObject(gameObject, "middle/getRewardNumber/Image4/Text4"):GetComponent("Text") --千位
    this.tenThousandsText = Util.GetGameObject(gameObject, "middle/getRewardNumber/Image5/Text5"):GetComponent("Text") --万位
    this.popUpTextShow1 = Util.GetGameObject(gameObject, "popUpTextShow/Image/Text1"):GetComponent("Text")
    this.popUpTextShow2 = Util.GetGameObject(gameObject, "popUpTextShow/Image/Text2"):GetComponent("Text")
    this.popUpTextShow3 = Util.GetGameObject(gameObject, "popUpTextShow/Image/Text3"):GetComponent("Text")
    this.remainNumText = Util.GetGameObject(gameObject, "middle/startDraw/canRechargeTimebg/remainNumText"):GetComponent("Text")
    this.rechargeNumberText = Util.GetGameObject(gameObject, "middle/startDraw/canRechargeTimebg/rechargeNumberText"):GetComponent("Text")
    this.btnBack = Util.GetGameObject(gameObject, "btnBack")
    this.helpBtn=Util.GetGameObject(gameObject,"helpBtn")
    this.helpPosition=this.helpBtn:GetComponent("RectTransform").localPosition
    this.redPoint= Util.GetGameObject(gameObject, "middle/startDraw/startDrawBtn/redPoint")
    listText = { this.popUpTextShow1, this.popUpTextShow2, this.popUpTextShow3 }
    --this.UpView = SubUIManager.Open(SubUIConfig.UpView, gameObject.transform, { showType = UpViewOpenType.ShowLeft })
    this.textShow = Util.GetGameObject(gameObject, "middle/startDraw/canRechargeTimebg/text"):GetComponent("Text")
    ---页面初始数据显示

    this.anim = Util.GetGameObject(self.gameObject, "middle/getRewardNumber/anim")
    this.anim.transform.localPosition = Vector2.New(18, -58)
    this.popUpTextShow1.text = ""
    this.popUpTextShow2.text = ""
    this.popUpTextShow3.text = ""
    --this.NumView = SubUIManager.Open(SubUIConfig.NumberView, this.anim.transform, "r_fxgz_shuzi_", Vector2.New(80, 120), Vector2.New(50, 30), 0, 99999)

end

function LuckyCat:BindEvent()
    Util.AddClick(this.startDrawBtn, function()
        if expertPanel.isPlayingLackCatAni then return end
        local getRewardNumber = LuckyCatManager.getRewardNumber +1
        canRewardTime = LuckyCatManager.GetCanRewardTimes(LuckyCatManager.hasRechargeNum)
        if (getRewardNumber <= canRewardTime) then
        else
            getRewardNumber = canRewardTime
        end
        local haveItemNum = BagManager.GetItemCountById(itemType)
        local costItemNum = LuckyCatManager.consumeValue[ConfigManager.GetConfigDataByDoubleKey(ConfigName.LuckyCatConfig,"ActivityId",LuckyCatManager.activityId,"LuckyTime",getRewardNumber).Id]
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
function LuckyCat:OnRefreshRedPoint()
    local getRewardNumber = LuckyCatManager.getRewardNumber + 1
    local haveItemNum = BagManager.GetItemCountById(itemType)
    local costItemNum = LuckyCatManager.consumeValue[ConfigManager.GetConfigDataByDoubleKey(ConfigName.LuckyCatConfig,"ActivityId",LuckyCatManager.activityId,"LuckyTime",getRewardNumber).Id]
    if (haveItemNum >= costItemNum and LuckyCatManager.getRewardNumber < canRewardTime) then
        this.redPoint:SetActive(true)
    else
        this.redPoint:SetActive(false)
    end
end
function LuckyCat:OnOpen()

end
function LuckyCat:OnShow(_upView,_expertPanel)
    expertPanel = _expertPanel
    for i, v in ConfigPairs(luckyCatConfig) do
        if (LuckyCatManager.activityId == v.ActivityId) then
            itemType = v.LuckyType
        end
    end

    local curItemCon = itemConfig[itemType]
    if curItemCon == nil then return end
    this.getRewardHighIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemType].ResourceID))
    this.costIcon.sprite = Util.LoadSprite(GetResourcePath(itemConfig[itemType].ResourceID))


    -- 开始定时刷新数据
    this.UpView = _upView
    LuckyCatManager.StartLuckyCatDataUpdate()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = {14, 16, itemType}})
    this:OnRefresh()
    this.OnRefreshItemNumShow(false)
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LuckyCat)
    if activityInfo then
        if activityInfo.endTime ~= 0 then
            this:LuckyCatActivitCountDawn(activityInfo.endTime - GetTimeStamp())
        end
    end
    if(not LuckyCatManager.isOpenLuckyCat) then
        this:ClosePanel()
    end
    LuckyCatManager.isEnterLuckyCat=true
    CheckRedPointStatus(RedPointType.LuckyCat_GetReward)
end
function LuckyCat:OnRefresh()
    local getRewardNumber = LuckyCatManager.getRewardNumber + 1
    canRewardTime = LuckyCatManager.GetCanRewardTimes(LuckyCatManager.hasRechargeNum)
    if getRewardNumber > LengthOfTable(LuckyCatManager.valueUp) then getRewardNumber = LengthOfTable(LuckyCatManager.valueUp) end
    this.getRewardHighNumber.text = "×" .. LuckyCatManager.valueUp[ConfigManager.GetConfigDataByDoubleKey(ConfigName.LuckyCatConfig,"ActivityId",LuckyCatManager.activityId,"LuckyTime",getRewardNumber).Id]
    this.costItemNumber.text = "×" .. LuckyCatManager.consumeValue[ConfigManager.GetConfigDataByDoubleKey(ConfigName.LuckyCatConfig,"ActivityId",LuckyCatManager.activityId,"LuckyTime",getRewardNumber).Id]
    if (getRewardNumber <= canRewardTime) then
    else
        getRewardNumber = canRewardTime
    end
    this.remainNumText.text = GetLanguageStrById(11134) .. (canRewardTime - LuckyCatManager.getRewardNumber) .. GetLanguageStrById(11135)
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
    --local getRewardNumber = LuckyCatManager.getRewardNumber + 1
    --canRewardTime = LuckyCatManager.GetCanRewardTimes(LuckyCatManager.hasRechargeNum)
    --if (getRewardNumber <= canRewardTime) then
    --else
    --    getRewardNumber = canRewardTime
    --end
    local haveItemNum = BagManager.GetItemCountById(itemType)
    local costItemNum = LuckyCatManager.consumeValue[ConfigManager.GetConfigDataByDoubleKey(ConfigName.LuckyCatConfig,"ActivityId",LuckyCatManager.activityId,"LuckyTime",getRewardNumber).Id]
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
function LuckyCat:OnRefreshItemNumShow(playAnim)
    if (playAnim) then
        --刷新显示数据
        this.startDrawBtn:GetComponent("Button").enabled = false
        LuckyCatManager.isCanGetWorldMessage=false
        --ToDo动画显示
        -- this.NumView:SetNum(0)
        -- this.NumView:DOItemNum(LuckyCatManager.dropNumbers, function(index, num, item)
        --     item:Move(tostring(num), index * 0.5 + 2, true, 3)

        -- end)
        local timerEffect = Timer.New(function()
            UIManager.OpenPanel(UIName.RewardItemPopup, LuckyCatManager.drop, 1,function ()
                this:OnRefresh()
            end)
            this.startDrawBtn:GetComponent("Button").enabled = true
            LuckyCatManager.isCanGetWorldMessage=true
        end, 5, 1, true)
        timerEffect:Start()
    else
        this.unitsText.text = LuckyCatManager.unitsText --个位
        this.tensText.text = LuckyCatManager.tensText -- 十位
        this.hundredsText.text = LuckyCatManager.hundredsText --百位
        this.thousandsText.text = LuckyCatManager.thousandsText --千位
        this.tenThousandsText.text = LuckyCatManager.tenThousandsText --万位
    end

end
--界面关闭时调用（用于子类重写）
function LuckyCat:OnClose()
    if this.timer then
        this.timer:Stop()
    end
    LuckyCatManager.StopLuckyCatUpdate()
end

--活动时间倒计时
function LuckyCat:LuckyCatActivitCountDawn(timeDown)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    this.activityCountDownText.text = GetLanguageStrById(10028)..TimeToDHMS(timeDown)
    this.timer = Timer.New(function()
        if timeDown < 1 then
            
            this.timer:Stop()
            this.timer = nil
            return
            --this:ClosePanel()
        end
        timeDown = timeDown - 1
        this.activityCountDownText.text =  GetLanguageStrById(10028)..TimeToDHMS(timeDown)--DateUtils.GetTimeFormatV2
    end, 1, -1, true)
    this.timer:Start()
end
--跑马灯显示
function LuckyCat:OnShowWorldMessage()
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

--添加事件监听（用于子类重写）
function LuckyCat:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnLuckyCatRefresh, this.OnRefreshItemNumShow, true)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnLuckyCatWorldMessage, this.OnShowWorldMessage)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnLuckyCatRedRefresh, this.OnRefreshRedPoint)
end

--移除事件监听（用于子类重写）
function LuckyCat:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnLuckyCatRefresh, this.OnRefreshItemNumShow, true)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnLuckyCatWorldMessage, this.OnShowWorldMessage)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnLuckyCatRedRefresh, this.OnRefreshRedPoint)
end


function LuckyCat:OnDestroy()
    --SubUIManager.Close(this.UpView)
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    expertPanel = nil
end


return LuckyCat