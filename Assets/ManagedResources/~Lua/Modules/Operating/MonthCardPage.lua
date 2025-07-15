local util = require "cjson.util"
local MonthCardPage = quick_class("MonthCardPage")
local addTimeNum = 30 * 24 * 60 * 60

local monthCardConFig  = ConfigManager.GetConfig(ConfigName.MonthcardConfig)
function MonthCardPage:ctor(mainPanel,gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject

    --未激活
    self.activation = Util.GetGameObject(self.gameObject, "bg/activation")
    self.btnActivation = Util.GetGameObject(self.activation, "btn")
    self.btnActivationRedpoint = Util.GetGameObject(self.btnActivation, "redPoint")
    self.slider = Util.GetGameObject(self.activation, "slider/Image"):GetComponent("Image")
    self.progress = Util.GetGameObject(self.activation, "slider/progress"):GetComponent("Text")

    --领取
    self.receive = Util.GetGameObject(self.gameObject,"bg/receive")
    self.btnReceive = Util.GetGameObject(self.receive, "btn")
    self.btnReceiveText = Util.GetGameObject(self.btnReceive,"Text"):GetComponent("Text")
    self.receiveTime = Util.GetGameObject(self.receive, "time"):GetComponent("Text")

    self.rewardContent = Util.GetGameObject(self.receive,"rewardContent")

    self.smallDay1 = Util.GetGameObject(self.gameObject, "bg/day/Text1"):GetComponent("Text")
    self.smallDay2 = Util.GetGameObject(self.gameObject, "bg/day/Text2"):GetComponent("Text")

    --倒计时
    self.time = Util.GetGameObject(self.gameObject, "time/Text"):GetComponent("Text")

    self.itemList = {}
    --豪华月卡   
end

function MonthCardPage:OnShow()
    self.gameObject:SetActive(true)
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, self.RefreshStoneShow, self)

    OperatingManager.RefreshMonthCardEnd()
    self:RefreshStoneShow()
end

-- 妖晶数量显示
function MonthCardPage:RefreshStoneShow()
    local curAllMonthCardData = OperatingManager.GetMonthCardData()
    --月卡
    local curMonthCardOpenState = curAllMonthCardData[MONTH_CARD_TYPE.MONTHCARD] and curAllMonthCardData[MONTH_CARD_TYPE.MONTHCARD].endingTime ~= 0
    self.smallDay1.text = GetLanguageStrById(11476) .. monthCardConFig[MONTH_CARD_TYPE.MONTHCARD].Price*10 .. GetLanguageStrById(11477)
    self.smallDay2.text = GetLanguageStrById(11478) .. monthCardConFig[MONTH_CARD_TYPE.MONTHCARD].BaseReward[1][2] .. GetLanguageStrById(12635) .. "</color>"
    
    local MonthCardEndTime= OperatingManager.EndTimejudgment(MONTH_CARD_TYPE.MONTHCARD)

    self.btnActivationRedpoint:SetActive(OperatingManager.RefreshMonthCardRedPoint(MONTH_CARD_TYPE.MONTHCARD))
   
    if not curMonthCardOpenState then
        self.smallDay1.gameObject:SetActive(true)
        self.receive:SetActive(false)
        self.activation:SetActive(true)
        self.time.text = ""
        self.progress.text = GetLanguageStrById(12564)..OperatingManager.GetmonthSaveAmt()*10 .."/"..monthCardConFig[MONTH_CARD_TYPE.MONTHCARD].Price*10
        self.slider.fillAmount = OperatingManager.GetmonthSaveAmt()/monthCardConFig[MONTH_CARD_TYPE.MONTHCARD].Price
        Util.SetGray(self.btnActivation, false)
    else
        self.smallDay1.gameObject:SetActive(false)
        self.receive:SetActive(true)
        self.activation:SetActive(false)
        self.btnReceiveText.text = GetLanguageStrById(11481)

        local residueTimeNum = MonthCardEndTime- GetTimeStamp()

        local dayNum = math.floor(residueTimeNum / (24 * 3600))
        local startDate = os.date(GetLanguageStrById(11030),curAllMonthCardData[MONTH_CARD_TYPE.MONTHCARD].endingTime)
        local endDate = os.date(GetLanguageStrById(11030),MonthCardEndTime-1)   

        if dayNum > 0 then
            self.time.text = GetLanguageStrById(11492)..startDate.."-"..endDate
            if dayNum>=30 then
                dayNum=29
            end
            self.receiveTime.text = string.format(GetLanguageStrById(11480), dayNum, GetLanguageStrById(10021))
        else
            self.receiveTime.text = ""
            if self.timer then
                self.timer:Stop()
                self.timer = nil
            end
            self.timer = Timer.New(function()
                self.time.text = GetLanguageStrById(10028)..TimeStampToDateStr3(residueTimeNum)
                if residueTimeNum < 0 then
                    OperatingManager.RefreshMonthCardEnd()
                    self:RefreshStoneShow()
                    self.timer:Stop()
                    self.timer = nil
                end
                residueTimeNum = residueTimeNum - 1
            end, 1, -1, true)
            self.timer:Start()
        end
        if  curAllMonthCardData[MONTH_CARD_TYPE.MONTHCARD].state == 0 then
            Util.SetGray(self.btnReceive, false)
            self.btnReceive:GetComponent("Button").enabled = true
            self.btnReceiveText.text = GetLanguageStrById(11481)
        elseif curAllMonthCardData[MONTH_CARD_TYPE.MONTHCARD].state == 1 then
            Util.SetGray(self.btnReceive, true)
            self.btnReceive:GetComponent("Button").enabled = false
            self.btnReceiveText.text = GetLanguageStrById(10350)
        end
    end

    if self.itemList[self.gameObject] then
        self.itemList[self.gameObject]:OnOpen(false, {monthCardConFig[MONTH_CARD_TYPE.MONTHCARD].BaseReward[1][1],monthCardConFig[MONTH_CARD_TYPE.MONTHCARD].BaseReward[1][2]}, 1,false,false,false,self.mainPanel.sortingOrder)
        self.itemList[self.gameObject].gameObject:SetActive(true)
     else
        self.itemList[self.gameObject] = {}
        self.itemList[self.gameObject] = SubUIManager.Open(SubUIConfig.ItemView, self.rewardContent.transform)
        self.itemList[self.gameObject].gameObject:SetActive(true)
        self.itemList[self.gameObject]:OnOpen(false, {monthCardConFig[MONTH_CARD_TYPE.MONTHCARD].BaseReward[1][1],monthCardConFig[MONTH_CARD_TYPE.MONTHCARD].BaseReward[1][2]}, 1,false,false,false,self.mainPanel.sortingOrder)
    end
    Util.AddOnceClick(self.btnActivation, function()
        -- JumpManager.GoJump(27001)
        JumpManager.GoJump(36006)
    end)

    Util.AddOnceClick(self.btnReceive,function ()
        if curAllMonthCardData[MONTH_CARD_TYPE.MONTHCARD].state == 0 then
            NetManager.MonthCardTakeDailyRequest(MONTH_CARD_TYPE.MONTHCARD, function(drop)
                OperatingManager.SetMonthCardGetStateData(MONTH_CARD_TYPE.MONTHCARD,1)
                UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                    self:RefreshStoneShow()
                end)
            end)
        end
    end)
end

function MonthCardPage:OnHide()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    self.gameObject:SetActive(false)
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, self.RefreshStoneShow, self)
end

return MonthCardPage