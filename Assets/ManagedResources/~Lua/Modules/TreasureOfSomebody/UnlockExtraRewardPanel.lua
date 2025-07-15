--[[
 * @ClassName UnlockExtraRewardPanel
 * @Description 解锁额外奖励
 * @Date 2019/9/21 16:01
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class UnlockExtraRewardPanel
local UnlockExtraRewardPanel = quick_class("UnlockExtraRewardPanel", BasePanel)
--直购表
local rechargeCommodityConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)

function UnlockExtraRewardPanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.transform, "frame/bg/closeBtn")
    self.directRewardContent = Util.GetGameObject(self.transform, "frame/bg/rewardPart/Viewport/Content/box1")
    self.extraRewardContent = Util.GetGameObject(self.transform, "frame/bg/rewardPart/Viewport/Content/box2")

    self.dealBtn = Util.GetGameObject(self.transform, "frame/bg/dealBtn")
    self.costIcon = Util.GetGameObject(self.dealBtn, "icon"):GetComponent("Image")
    self.costValue = Util.GetGameObject(self.dealBtn, "value"):GetComponent("Text")

    self.rewardList = {}
end

function UnlockExtraRewardPanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        Game.GlobalEvent:RemoveEvent(GameEvent.MoneyPay.OnPayResultSuccess, self.RechargeSuccessFunc, self)
        self:ClosePanel()
    end)
    Util.AddClick(self.dealBtn, function()
        self:OnDealBtnClicked()
    end)
end

function UnlockExtraRewardPanel:OnOpen(goodsId,context)
    self.goodsId=goodsId
    self.context = context
    if table.nums(self.rewardList) > 0 then
        return
    end
    self:SetRewardList()
end

function UnlockExtraRewardPanel:OnShow()
    Game.GlobalEvent:AddEvent(GameEvent.MoneyPay.OnPayResultSuccess, self.RechargeSuccessFunc, self)
    self:SetCostValues()
end

function UnlockExtraRewardPanel:OnHide()

end

function UnlockExtraRewardPanel:OnDealBtnClicked()
    -- if not self.enoughStatus then
    --     UIManager.OpenPanel(UIName.MainRechargePanel, 1)
    --     return
    -- end
    -- local gameSettingConfig = ConfigManager.GetConfigData(ConfigName.GameSetting, 1)
    -- CostConfirmPopup.Show(gameSettingConfig.TreasurePrice[1], gameSettingConfig.TreasurePrice[2], "解锁额外奖励吗？", nil, function()
    --     NetManager.BuyTreasureOfSomeBody(function()
    --         PopupTipPanel.ShowTip("购买成功,请前往邮件查收")
    --         TreasureOfSomebodyManagerV2.SetTreasureBuyStatus(1)
    --         if self.context.callBack then
    --             self.context.callBack()
    --         end
    --         self:ClosePanel()
    --     end)
    -- end)
    if AppConst.isSDKLogin then
        PayManager.Pay({ Id = self.goodsId }, function()
            self:RechargeSuccessFunc(self.goodsId)
        end)
    else
        NetManager.RequestBuyGiftGoods(self.goodsId, function()
            self:RechargeSuccessFunc(self.goodsId)
        end)
    end
end

--充值成功的回调
function UnlockExtraRewardPanel:RechargeSuccessFunc(id)
    PopupTipPanel.ShowTipByLanguageId(11998)
    FirstRechargeManager.RefreshAccumRechargeValue(id)
    OperatingManager.RefreshGiftGoodsBuyTimes(GoodsTypeDef.FindBaby,id)
    TreasureOfSomebodyManagerV2.SetTreasureBuyStatus(1)
    if self.context.callBack then
        self.context.callBack()
    end
    self:ClosePanel()
end


function UnlockExtraRewardPanel:SetRewardList()
    --直接获得的
    local directRewardList = {}
    local specialConfig = ConfigManager.GetConfigData(ConfigName.SpecialConfig, 19)
    local rewardInfoList = string.split(specialConfig.Value, "|")
    for _, rewardInfo in ipairs(rewardInfoList) do
        local rewardItem = string.split(rewardInfo, "#")
        table.insert(directRewardList, { rewardItem[1], rewardItem[2] })
    end
    for _, rewardInfo in ipairs(directRewardList) do
        local item = SubUIManager.Open(SubUIConfig.ItemView, self.directRewardContent.transform)
        item:OnOpen(false, rewardInfo)
        table.insert(self.rewardList, item)
    end
    --额外获得的
    for _, rewardInfo in ipairs(self:MergeRewardList()) do
        local item = SubUIManager.Open(SubUIConfig.ItemView, self.extraRewardContent.transform)
        item:OnOpen(false, rewardInfo)
        table.insert(self.rewardList, item)
    end
end

function UnlockExtraRewardPanel:GetRewardList()
    local rewardList = {}
    local treasureConfigInfoList = TreasureOfSomebodyManagerV2.rewardConfigInfoList
    for _, treasureInfo in pairs(treasureConfigInfoList) do
        for _, rewardInfo in ipairs(treasureInfo.TreasureReward) do
            table.insert(rewardList, rewardInfo)
        end
    end
    return rewardList
end

function UnlockExtraRewardPanel:MergeRewardList()
    local MergeRewardList, DesireRewardList = {}, {}
    for _, v in ipairs(self:GetRewardList()) do
        if MergeRewardList[v[1]] then
            MergeRewardList[v[1]] = MergeRewardList[v[1]] + v[2]
        else
            MergeRewardList[v[1]] = v[2]
        end
    end
    for k, v in pairs(MergeRewardList) do
        table.insert(DesireRewardList, { k, v })
    end
    return DesireRewardList
end

function UnlockExtraRewardPanel:SetCostValues()
    local gameSettingConfig = ConfigManager.GetConfigData(ConfigName.GameSetting, 1)
    local propId = gameSettingConfig.TreasurePrice[1]
    -- self.costIcon.sprite = SetIcon(propId)
    self.costValue.text = gameSettingConfig.TreasurePrice[2]..GetLanguageStrById(10538)
    self.enoughStatus = BagManager.GetItemCountById(propId) >= gameSettingConfig.TreasurePrice[2]
end

return UnlockExtraRewardPanel