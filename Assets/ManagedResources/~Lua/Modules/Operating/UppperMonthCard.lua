-- 基金
UpperMonthCard = {}
local chargeConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)

-- 本地枚举
local ImgType = {
    [128] = {
        bg = GetPictureFont("cn2-X1_jijin_diban"), 
        num = "66000",
        getNum = "1280",
        color = Color.New(72/255,54/255,120/255,255/255),
        color2 = Color.New(67/255,50/255,113/255,255/255),
    },
    [328] = {
        bg = GetPictureFont("cn2-X1_chaozhijj_diban"), 
        num = "166000",
        getNum = "3280",
        color = Color.New(190/255,75/255,96/255,255/255),
        color2 = Color.New(190/255,75/255,96/255,255/255),
    },
}

function UpperMonthCard:New(parent, gameObject)
    local _o 
    _o = _o or {}
    setmetatable(_o, self)
    self.__index = self
    _o:InitComponent(gameObject)
    _o:BindEvent()
    _o.gameObject = gameObject
    _o.parent = parent
    return _o
end

-- 初始化组件
function UpperMonthCard:InitComponent(gameObject)
    --- Common Part
    self.panel = Util.GetGameObject(gameObject, "Panel"):GetComponent("Image")
    self.Bg = Util.GetGameObject(gameObject, "Panel/Bg"):GetComponent("Image")

    self.btnPreview = Util.GetGameObject(gameObject,"Panel/reward/btnPreview")
    self.valueIcon = Util.GetGameObject(gameObject, "Panel/cost/icon"):GetComponent("Image")
    self.totalValue = Util.GetGameObject(gameObject, "Panel/cost/value"):GetComponent("Text")

    --- 不同的充值行为显示部分
    self.middlePart = Util.GetGameObject(gameObject, "Panel/reward/middle")
    self.grid = Util.GetGameObject( self.middlePart,  "grid")
    self.itemPre = Util.GetGameObject(self.middlePart, "itemPre")

    --- 未购买
    self.buyPanel = Util.GetGameObject(gameObject, "Panel/buyPart")
    self.tipIcon = Util.GetGameObject(self.buyPanel, "tip/Image"):GetComponent("Image")
    self.charmyNum = Util.GetGameObject(self.buyPanel, "tip/value"):GetComponent("Text")  -- 返利
    self.actLeftTime = Util.GetGameObject(self.buyPanel, "leftTime"):GetComponent("Text")  -- 活动剩余天数
    self.btnBuy = Util.GetGameObject(self.buyPanel, "btnBuy")
    self.textBuy = Util.GetGameObject(self.btnBuy, "Text"):GetComponent("Text")

    -- 已经购买，你先可以享受这你觉得还可以的服务了
    self.boughtPanel = Util.GetGameObject(gameObject, "Panel/purchased")
    self.totalLoginday = Util.GetGameObject(self.boughtPanel, "totalDay"):GetComponent("Text")
    self.boughtLeftTime = Util.GetGameObject(self.boughtPanel, "time"):GetComponent("Text")

    ---- 奖励列表
    self.rewardList = {}
    
    self.di = Util.GetGameObject(gameObject, "Panel/di")
    self.diwen = Util.GetGameObject(gameObject, "Panel/diwen")
end 

function UpperMonthCard:BindEvent()
    Util.AddClick(self.btnPreview, function() 
        UIManager.OpenPanel(UIName.MonthRewardPreviewPopup, self.baseType, self.chargerBaseType)
    end)

    Util.AddClick(self.btnBuy, function() 
        -- local isActive = VipManager.GetMonthCardOpenState()
        -- if --[[not isActive]] false then 
        --     MsgPanel.ShowTwo(GetLanguageStrById(11488), function()
        --     end, function(isShow)
        --         JumpManager.GoJump(36004)
        --     end, GetLanguageStrById(10719), GetLanguageStrById(10023),nil, false) 
        -- else
            if not OperatingManager.GetMonthCardIsOpen(MONTH_CARD_TYPE.LUXURYMONTHCARD) then
                PopupTipPanel.ShowTip(GetLanguageStrById(11488))
                return
            end
            if AppConst.isSDKLogin then
                PayManager.Pay({ Id = self.baseType }, function()
                    self:RechargeSuccessFunc(self.baseType)
                    if not GetChannerConfig().Rechargemode_Mail then
                        PopupTipPanel.ShowTipByLanguageId(50235)
                    end
                end)
            else
                NetManager.RequestBuyGiftGoods(self.baseType, function()
                    self:RechargeSuccessFunc(self.baseType)
                    if not GetChannerConfig().Rechargemode_Mail then
                        PopupTipPanel.ShowTipByLanguageId(50235)
                    end
                end)
            end
        -- end
    end)
end

function UpperMonthCard:AddEvent()
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, self.RechargeSuccessFunc, self)
end

function UpperMonthCard:RemoveEvent()
    Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, self.RechargeSuccessFunc, self)
end

function UpperMonthCard:OnShow(parentSorting, arg, pageIndex) 
    self:AddEvent()
    self.panelType = pageIndex == 7 and 128 or 328
    -- 基金类型
    self.chargerBaseType = pageIndex == 7 and GoodsTypeDef.MONTHCARD_128 or GoodsTypeDef.MONTHCARD_328

    -- 基金的商品ID
    -- 判断我是否购买过该商品
    local goodsId = OperatingManager.GetActiveGoodsIDByType(self.chargerBaseType)
    if not goodsId then
        -- 没有购买过判断是否在活动期间
        local gift = OperatingManager.GetGiftGoodsInfo(self.chargerBaseType)
        if not gift then

            return 
        end
        goodsId = gift.goodsId
    end

    self.baseType = goodsId

    self.gameObject:SetActive(true)
    OperatingManager.SetSerData(self.chargerBaseType)
    self:SetPanelType(self.panelType)
    self:SetRewardInfo(self.panelType)
    self.di:SetActive(self.panelType == 328)
    self:SetBuyState()
    OperatingManager.SetSpecialFundsFistOpen()
    CheckRedPointStatus(RedPointType.SpecialFunds)
end

-- 充值成功回调
function UpperMonthCard:RechargeSuccessFunc(id)
    local type = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, id).Type
    if type == 8 or type == 9 then
        FirstRechargeManager.RefreshAccumRechargeValue(id)
        OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.DemonCrystal, id)
        --- 设置购买成功数据
        OperatingManager.SetSignRewarDay(self.chargerBaseType, 438)
        local startTime = Today_N_OClockTimeStamp(0)
        OperatingManager.SetGoodsEndTime(self.baseType, startTime + 30 * 24 * 60 * 60 - 1)
        -- Today_N_OClockTimeStamp
        --- 刷新本地显示
        self:FreshBoughtShow()
    end
end

--- 设置不同的显示界面
function UpperMonthCard:SetPanelType(type) 
    self.valueIcon.sprite = SetIcon(16)
    self.Bg.sprite =  Util.LoadSprite(ImgType[type].bg)
    self.panel.color = ImgType[type].color
    self.diwen:GetComponent("Image").color = ImgType[type].color2

    -- self.middlePart:GetComponent("Image").sprite = Util.LoadSprite(ImgType[type].rewardBg)

    self.valueIcon.sprite = SetIcon(chargeConfig[self.baseType].BaseReward[1][1])
    self.tipIcon.sprite = SetIcon(chargeConfig[self.baseType].RewardShow[1][1])
    self.totalValue.text = ImgType[type].num--chargeConfig[self.baseType].RewardShow[1][2]
    self.charmyNum.text = chargeConfig[self.baseType].BaseReward[1][2]
    -- self.charmyNum.sprite = Util.LoadSprite(ImgType[type].getNum)
end

--- 设置不同界面的奖励信息
function UpperMonthCard:SetRewardInfo(type)
    local data = OperatingManager.GetPanelShowReward(self.baseType, false, true)
    local allData = OperatingManager.GetPanelShowReward2(self.baseType)
    for i = 1, #allData do
        if not self.rewardList[i] then
            self.rewardList[i] = {} 
            self.rewardList[i].go = newObjToParent(self.itemPre, self.grid)
            self.rewardList[i].item = SubUIManager.Open(SubUIConfig.ItemView, self.rewardList[i].go.transform)
            self.rewardList[i].name = Util.GetGameObject(self.rewardList[i].go, "name"):GetComponent("Text")
            -- Util.GetGameObject(self.rewardList[i].go, "name"):SetActive(false)
        end

        local rewardData = allData[i].reward[1]
        self.rewardList[i].item:OnOpen(false, {rewardData[1],rewardData[2]}, 0.8,false)
        -- self.rewardList[i].name.text = Util.GetGameObject(self.rewardList[i].item.gameObject,"name"):GetComponent("Text").text
        self.rewardList[i].name.text = string.format(GetLanguageStrById(10473), allData[i].Day)
    end
end

--- 购买成功刷新
function UpperMonthCard:FreshBoughtShow()
    self.boughtPanel:SetActive(true)
    self.buyPanel:SetActive(false)
    self.totalLoginday.text = GetLanguageStrById(11491) .. OperatingManager.GetRewardDay(self.chargerBaseType) .. GetLanguageStrById(10021)
    local startStr, endStr = OperatingManager.GetShowTime(OperatingManager.GetGoodsEndTime(self.chargerBaseType))
    self.boughtLeftTime.text = GetLanguageStrById(11492) ..startStr .. " — ".. endStr
end

--- 根据是否购买了显示信息
function UpperMonthCard:SetBuyState()
    local isActive = VipManager.GetMonthCardOpenState()
    local isBought = OperatingManager.IsBaseBuy(self.chargerBaseType)

    self.boughtPanel:SetActive(isBought)
    self.buyPanel:SetActive(not isBought)
    --Util.SetGray(self.btnBuy, not isActive)
    --> self.textBuy.text = isActive and self.panelType .. GetLanguageStrById(10538) or self.panelType .. GetLanguageStrById(10538)
    self.textBuy.text = MoneyUtil.GetMoney(self.panelType)

    if not isBought then 
        self:SetBuyPanelInfo()
    else
        self:SetBoughtPanelInfo()
    end
end

function UpperMonthCard:SetBuyPanelInfo()
    --- 未激活，在活动时间内
    local isOpen = OperatingManager.IsBaseOpen(self.chargerBaseType, self.baseType)
    self.buyTimer = nil
    if isOpen then 
        --- 获取剩余时间，结束时间为0表示不限时
        local data = OperatingManager.GetGiftGoodsInfo(self.chargerBaseType, self.baseType)
        local endTime = data.endTime
        if endTime <= 0 then 
            self.actLeftTime.gameObject:SetActive(false)
        else
            self.actLeftTime.gameObject:SetActive(false)

            self.buyTimer = Timer.New(function ()
                if endTime - GetTimeStamp() <= 0 then
                    self.buyTimer:Stop()
                    UIManager.OpenPanel(UIName.OperatingPanel)
                end
            end, 1, -1, true)
            self.buyTimer:Start()
            self.actLeftTime.text = GetLanguageStrById(11496) .. self:TimeFormat(endTime - PlayerManager.serverTime)
        end 
    else
        self.actLeftTime.gameObject:SetActive(false)
    end
end

function UpperMonthCard:TimeFormat(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(11497), day, hour, minute)
end

function UpperMonthCard:SetBoughtPanelInfo()
    local endTime = OperatingManager.GetGoodsEndTime(self.chargerBaseType)
    self.totalLoginday.text = GetLanguageStrById(11491) .. OperatingManager.GetRewardDay(self.chargerBaseType) .. GetLanguageStrById(10021)
    local startStr, endStr = OperatingManager.GetShowTime(endTime)
    self.boughtLeftTime.text = GetLanguageStrById(11492) ..startStr .. " — ".. endStr

    --- 购买后倒计时显示
    self.timer = nil
    self.timer = Timer.New(function() 
        if GetTimeStamp() > endTime then 
            --- 注销基金
            OperatingManager.RemoveEndTime(self.baseType)
            self:SetBuyState()
            self.timer:Stop()
        else
            OperatingManager.SetSerData(self.chargerBaseType)
            self.totalLoginday.text = GetLanguageStrById(11491) .. OperatingManager.GetRewardDay(self.chargerBaseType) .. GetLanguageStrById(10021)
        end
        end, 1, -1, true)
    self.timer:Start()
end

function UpperMonthCard:OnHide()
    self.gameObject:SetActive(false)
    self:RemoveEvent()
    if self.timer then 
        self.timer:Stop()
        self.timer = nil
    end

    if self.buyTimer then  
        self.buyTimer:Stop()
        self.buyTimer = nil
    end
end

return UpperMonthCard