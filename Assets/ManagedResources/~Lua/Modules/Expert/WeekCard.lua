local WeekCard = quick_class("WeekCard")
local this = WeekCard
local weekCardItemViews = {}
local weekCardItemViewGos = {}

function WeekCard:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end
--初始化组件（用于子类重写）
function WeekCard:InitComponent(gameObject)

    --self.weekCardGrid =  Util.GetGameObject(gameObject, "")
    this.timeTextWeekCard = Util.GetGameObject(gameObject, "timeText"):GetComponent("Text")
    this.timeTextWeekCardGo = Util.GetGameObject(gameObject, "timeText")
    for i = 1, 3 do
        weekCardItemViews[i] = Util.GetGameObject(gameObject, "itemViewParent/itemViewParent ("..i..")")
        weekCardItemViewGos[i] = SubUIManager.Open(SubUIConfig.ItemView, weekCardItemViews[i].transform)
    end
    this.weekCardBuyNum = Util.GetGameObject(gameObject, "buyNum"):GetComponent("Text")
    this.weekCardBuyBtn = Util.GetGameObject(gameObject, "buyBtn")
end

--绑定事件（用于子类重写）
function WeekCard:BindEvent()

    Util.AddClick(self.weekCardBuyBtn, function()
        if AppConst.isSDKLogin then
            PayManager.Pay({ Id = 12 }, function()
                PopupTipPanel.ShowTipByLanguageId(10553)
                FirstRechargeManager.RefreshAccumRechargeValue(12)
                OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.WeekCard, 12)
                this:WeekCardShow()
            end)
        else
            NetManager.RequestBuyGiftGoods(12, function()
                PopupTipPanel.ShowTipByLanguageId(10553)
                FirstRechargeManager.RefreshAccumRechargeValue(12)
                OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.WeekCard, 12)
                this:WeekCardShow()
            end)
        end
    end)
end

--添加事件监听（用于子类重写）
function WeekCard:AddListener()

end

--移除事件监听（用于子类重写）
function WeekCard:RemoveListener()

end

--界面打开时调用（用于子类重写）
function WeekCard:OnOpen(...)

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function WeekCard:OnShow()

    this:WeekCardShow()
end
--周卡
function WeekCard:WeekCardShow()
    --self.timeTextWeekCard
    ActivityGiftManager.isOpenWeekCard = true
    RedpotManager.CheckRedPointStatus(RedPointType.Expert_WeekCard)
    local weekConFig = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, 12)
    local numStrList = {}
    for i = 1, #weekConFig.ExtraReward[1] do
        local rewardInfo = {}
        local curExtraReward = weekConFig.ExtraReward[1][i]
        if curExtraReward[1] == 0 then
            rewardInfo = {curExtraReward[2],0}
            table.insert(numStrList,curExtraReward[3])
        elseif curExtraReward[1] == 1 then
            --500*玩家等级10
            rewardInfo = {curExtraReward[2],0}
            --table.insert(numStrList,curExtraReward[3].. "X" .."玩家等级" .."<color=#97FEC5FF>".. PlayerManager.level.."</color>")
            table.insert(numStrList, GetLanguageStrById(10554) ..curExtraReward[3])
        elseif curExtraReward[1] == 2 then
            rewardInfo = {curExtraReward[2],0}
            --table.insert(numStrList,curExtraReward[3].. "X" .."特权等级" .."<color=#97FEC5FF>".. VipManager.GetVipLevel().."</color>")
            table.insert(numStrList, GetLanguageStrById(10555) ..curExtraReward[3])
        end
        weekCardItemViewGos[i]:OnOpen(false,rewardInfo,1.2)
        Util.GetGameObject(weekCardItemViews[i].gameObject, "numText"):GetComponent("Text").text = numStrList[i]
    end
    local weekCardData = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.WeekCard, 12)
    if weekCardData then
        PatFaceManager.RemainTimeDown2(self.timeTextWeekCardGo,self.timeTextWeekCard,weekCardData.endTime - GetTimeStamp())
        if weekCardData.buyTimes >0 then
            this.weekCardBuyBtn:GetComponent("Button").enabled=false
            this.weekCardBuyNum.text = GetLanguageStrById(10556)..weekConFig.Limit.."/"..weekConFig.Limit
            Util.GetGameObject(self.weekCardBuyBtn.gameObject, "Text"):GetComponent("Text").text = GetLanguageStrById(10526)
        else
            this.weekCardBuyBtn:GetComponent("Button").enabled=true
            this.weekCardBuyNum.text = GetLanguageStrById(10556)..weekCardData.buyTimes.."/"..weekConFig.Limit
            Util.GetGameObject(self.weekCardBuyBtn.gameObject, "Text"):GetComponent("Text").text = MoneyUtil.GetMoney(weekConFig.Price)
        end
    else
        this.weekCardBuyBtn:GetComponent("Button").enabled=false
        this.weekCardBuyNum.text = GetLanguageStrById(10556)..weekConFig.Limit.."/"..weekConFig.Limit
        Util.GetGameObject(self.weekCardBuyBtn.gameObject, "Text"):GetComponent("Text").text = GetLanguageStrById(10526)
    end
end
--界面关闭时调用（用于子类重写）
function WeekCard:OnClose()

end

--界面销毁时调用（用于子类重写）
function WeekCard:OnDestroy()

end

return WeekCard