--[[
 * @ClassName TreasureOfSomebodyRewardPageV2
 * @Description 戒灵秘宝奖励Part
 * @Date 2019/9/21 13:39
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class TreasureOfSomebodyRewardPageV2
local TreasureOfSomebodyRewardPageV2 = quick_class("TreasureOfSomebodyRewardPageV2")

function TreasureOfSomebodyRewardPageV2:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject

    self.treasureListContent = Util.GetGameObject(self.gameObject, "treasureList")
    self.treasurePro = Util.GetGameObject(self.gameObject, "itemPro")
    self.treasurePro:SetActive(false)

    ---- 创建循环列表
    local v2 = self.treasureListContent:GetComponent("RectTransform").rect
    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.treasureListContent.transform,
            self.treasurePro, nil, Vector2.New(-v2.x * 2, -v2.y * 2), 1, 1, Vector2.New(0, 25))
    self.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    self.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 1

    self.treasureFinalReward = {
        level = Util.GetGameObject(self.gameObject, "finalReward/level"):GetComponent("Text"),
        GiftItemList = {}
    }
    for i = 1, 4 do
        self.treasureFinalReward.GiftItemList[i] = SubUIManager.Open(SubUIConfig.ItemView,
                Util.GetGameObject(self.gameObject, "finalReward/itemPos_" .. i).transform)
    end

    self.finalBtnDeal = Util.GetGameObject(self.gameObject, "finalReward/btnDeal")
    Util.AddClick(self.finalBtnDeal, function()
        self:OnOneKeyDealBtnClicked()
    end)
    self.finalFinishFlag = Util.GetGameObject(self.gameObject, "finalReward/finished")

    --Util.AddClick(Util.GetGameObject(self.gameObject, "gainScoreBtn"), function()
    --    self.mainPanel:OnPageChanged(1)
    --end)

    --戒灵秘宝 查看宝藏界面购买点击
    self.unlockBtn = Util.GetGameObject(self.gameObject, "unlockBtn")
    self.unlockBtn:GetComponent("Button").onClick:AddListener(function()
        if TreasureOfSomebodyManagerV2.hadBuyTreasure then
            PopupTipPanel.ShowTipByLanguageId(11992)
            return
        end
        UIManager.OpenPanel(UIName.UnlockExtraRewardPanel,5001, {
            callBack = function()
                self:RefreshTreasureBuy()
            end
        })
    end)

    self.unlockCost = Util.GetGameObject(self.unlockBtn, "unlockCost")
    -- self.unlockCostIcon = Util.GetGameObject(self.unlockCost, "icon"):GetComponent("Image")
    self.unlockCostValue = Util.GetGameObject(self.unlockCost, "value"):GetComponent("Text")

    self.unlock = Util.GetGameObject(self.unlockBtn, "unlock")

    self:InitUnlockCost()

    self.rewardItemList = {}
end

function TreasureOfSomebodyRewardPageV2:OnShow()
    Game.GlobalEvent:AddEvent(GameEvent.TreasureOfSomeBody.OpenTreasureAward, self.OnOpenTreasure, self)
    self.gameObject:SetActive(true)
    self:RefreshPageStatus()
    self:SetScrollViewIndexShow()
end

function TreasureOfSomebodyRewardPageV2:OnHide()
    Game.GlobalEvent:RemoveEvent(GameEvent.TreasureOfSomeBody.OpenTreasureAward, self.OnOpenTreasure, self)
    if self.index then
        self.ScrollView:SetIndex(1)
    end
    self.gameObject:SetActive(false)
end

function TreasureOfSomebodyRewardPageV2:OnDestroy()
    self.ScrollView = nil
    self.index = nil
end

function TreasureOfSomebodyRewardPageV2:RefreshPageStatus()
    local treasureConfigs = TreasureOfSomebodyManagerV2.rewardConfigInfoList
    self.ScrollView:SetData(treasureConfigs, function(index, rewardItem)
        self:SetBottomRewardInfo(index, treasureConfigs)
        local itemData = treasureConfigs[index]
        self:SetScoreItemAdapter(rewardItem, itemData)
    end)
    self:SetFinalStatus()
end

function TreasureOfSomebodyRewardPageV2:SetScrollViewIndexShow()
    local desireIndex
    local treasureConfigs = TreasureOfSomebodyManagerV2.rewardConfigInfoList
    for _, itemInfo in pairs(treasureConfigs) do
        local activityIdInfo = ActivityGiftManager.GetActivityInfo(itemInfo.ActivityId, itemInfo.Level)
        if TreasureOfSomebodyManagerV2.hadBuyTreasure then
            if activityIdInfo.state == 0 or activityIdInfo.state == 1 then
                if TreasureOfSomebodyManagerV2.currentLv >= itemInfo.Level then
                    desireIndex = itemInfo.Level
                    break
                end
            end
        else
            if activityIdInfo.state == 0 then
                if TreasureOfSomebodyManagerV2.currentLv >= itemInfo.Level then
                    desireIndex = itemInfo.Level
                    break
                end
            end
        end
    end
    if desireIndex then
        self.ScrollView:SetIndex(desireIndex)
    end
end

function TreasureOfSomebodyRewardPageV2:SetBottomRewardInfo(index, configsInfo)
    local dataIndex
    if not self.index then
        self.index = index
    else
        if index < self.index  then
            dataIndex = index + 8
        else
            dataIndex = index
        end
        self.index = index
    end
    if not dataIndex then
        return
    end
    local maxLv = TreasureOfSomebodyManagerV2.treasureMaxLv
    dataIndex = (math.floor((dataIndex - 1) / 10) + 1) * 10
    dataIndex = dataIndex < maxLv and dataIndex or maxLv
    local bottomRewardInfo = configsInfo[dataIndex]
    self.treasureFinalReward.level.text = bottomRewardInfo.Level .. GetLanguageStrById(10072)
    self:HideFinalGiftRewards()
    self:RefreshFinalGiftItem(bottomRewardInfo)
end

function TreasureOfSomebodyRewardPageV2:HideFinalGiftRewards()
    table.walk(self.treasureFinalReward.GiftItemList, function(giftItem)
        if giftItem.gameObject.activeSelf then
            giftItem.gameObject:SetActive(false)
        end
    end)
end
function TreasureOfSomebodyRewardPageV2:RefreshFinalGiftItem(configInfo)
    for i, v in ipairs(configInfo.Reward) do
        local giftItem = self.treasureFinalReward.GiftItemList[i]
        giftItem:OnOpen(false, v, 0.75)
        giftItem.gameObject:SetActive(true)
    end
    for i, v in ipairs(configInfo.TreasureReward) do
        local giftItem = self.treasureFinalReward.GiftItemList[i + 2]
        giftItem:OnOpen(false, v, 0.75)
        giftItem.gameObject:SetActive(true)
    end
end

function TreasureOfSomebodyRewardPageV2:OnDealBtnClicked()
    if TreasureOfSomebodyManagerV2.hadBuyTreasure then
        PopupTipPanel.ShowTipByLanguageId(11996)
        return
    end
    local gameSettingConfig = ConfigManager.GetConfigData(ConfigName.GameSetting, 1)
    local ownValue = BagManager.GetItemCountById(gameSettingConfig.TreasurePrice[1])
    if ownValue < gameSettingConfig.TreasurePrice[2] then
        if not ShopManager.IsActive(SHOP_TYPE.SOUL_STONE_SHOP) then
            PopupTipPanel.ShowTipByLanguageId(10438)
            return
        end
        UIManager.OpenPanel(UIName.MainRechargePanel, 1)
    else
        NetManager.BuyTreasureOfSomeBody()
    end
end

function TreasureOfSomebodyRewardPageV2:SetScoreItemAdapter(rewardItem, itemInfo)
    Util.GetGameObject(rewardItem, "level"):GetComponent("Text").text = itemInfo.Level .. GetLanguageStrById(10072)
    local activityIdInfo = ActivityGiftManager.GetActivityInfo(itemInfo.ActivityId, itemInfo.Level)
    Util.GetGameObject(rewardItem, "finished"):SetActive(activityIdInfo.state == -1)
    local btnDeal = Util.GetGameObject(rewardItem, "btnDeal")
    btnDeal:SetActive(activityIdInfo.state ~= -1)
    if btnDeal.activeSelf then
        local hadBuyState = TreasureOfSomebodyManagerV2.hadBuyTreasure and -1 or 1
        local ReceivedReward = function()
            NetManager.GetActivityRewardRequest(itemInfo.Level, itemInfo.ActivityId, function(drop)
                UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
                ActivityGiftManager.SetActivityInfo(itemInfo.ActivityId, itemInfo.Level, hadBuyState)
                self:SetScoreItemAdapter(rewardItem, itemInfo)
                self.mainPanel:SetRewardRedPoint()
                RedpotManager.CheckRedPointStatus(RedPointType.TreasureOfSl)
                self:SetFinalStatus()
            end)
        end
        if activityIdInfo.state == 0 then
            Util.GetGameObject(btnDeal, "Text"):GetComponent("Text").text = GetLanguageStrById(10022)
            local status = TreasureOfSomebodyManagerV2.currentLv >= itemInfo.Level
            btnDeal:GetComponent("Button").enabled = status
            Util.SetGray(btnDeal, not status)
            if status then
                Util.AddOnceClick(btnDeal, function()
                    ReceivedReward()
                end)
            end
        elseif activityIdInfo.state == 1 then
            Util.GetGameObject(btnDeal, "Text"):GetComponent("Text").text = GetLanguageStrById(10752)
            btnDeal:GetComponent("Button").enabled = true
            Util.SetGray(btnDeal, false)
            Util.AddOnceClick(btnDeal, function()
                if TreasureOfSomebodyManagerV2.hadBuyTreasure then
                    ReceivedReward()
                else
                    UIManager.OpenPanel(UIName.UnlockExtraRewardPanel, {
                        callBack = function()
                            self:RefreshTreasureBuy()
                        end
                    })
                end
            end)
        end
    end
    if self.rewardItemList[rewardItem] then
        --已经创建过的奖励
        self:HideAllGiftItem(rewardItem)
    else
        --没有创建过的奖励
        self.rewardItemList[rewardItem] = {
            rewardList = {}
        }
        for i = 1, 4 do
            local giftItem = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(rewardItem, "itemPos_" .. i).transform)
            giftItem.gameObject:SetActive(false)
            giftItem.transform:SetAsFirstSibling()
            self.rewardItemList[rewardItem].rewardList[i] = giftItem
        end
    end
    self:RefreshGiftItem(rewardItem, itemInfo)
end

function TreasureOfSomebodyRewardPageV2:RefreshGiftItem(rewardItem, configInfo)
    for i, v in ipairs(configInfo.Reward) do
        local giftItem = self.rewardItemList[rewardItem].rewardList[i]
        giftItem:OnOpen(false, v, 0.75)
        giftItem.gameObject:SetActive(true)
    end
    for i, v in ipairs(configInfo.TreasureReward) do
        local giftItem = self.rewardItemList[rewardItem].rewardList[i + 2]
        giftItem:OnOpen(false, v, 0.75)
        giftItem.gameObject:SetActive(true)
    end
end

function TreasureOfSomebodyRewardPageV2:HideAllGiftItem(rewardItem)
    table.walk(self.rewardItemList[rewardItem].rewardList, function(giftItem)
        if giftItem.gameObject.activeSelf then
            giftItem.gameObject:SetActive(false)
        end
    end)
end

--初始化解锁按钮
function TreasureOfSomebodyRewardPageV2:InitUnlockCost()
    self.unlockCost:SetActive(not TreasureOfSomebodyManagerV2.hadBuyTreasure)
    self.unlock:SetActive(TreasureOfSomebodyManagerV2.hadBuyTreasure)
    if not TreasureOfSomebodyManagerV2.hadBuyTreasure then
        local gameSettingConfig = ConfigManager.GetConfigData(ConfigName.GameSetting, 1)
        -- self.unlockCostIcon.sprite = SetIcon(gameSettingConfig.TreasurePrice[1])
        --> self.unlockCostValue.text = gameSettingConfig.TreasurePrice[2]..GetLanguageStrById(10538)
        self.unlockCostValue.text = MoneyUtil.GetMoney(gameSettingConfig.TreasurePrice[2])
        
    end
end

function TreasureOfSomebodyRewardPageV2:OnOpenTreasure()
    TreasureOfSomebodyManagerV2.SetTreasureBuyStatus(1)
    self.unlockCost:SetActive(false)
    RedpotManager.CheckRedPointStatus(RedPointType.TreasureOfSl)
end

function TreasureOfSomebodyRewardPageV2:SetFinalStatus()
    local allStatus = TreasureOfSomebodyManagerV2.GetFinalReceivedStatus()
    self.finalFinishFlag:SetActive(allStatus == -1)
    self.finalBtnDeal:SetActive(allStatus ~= -1)
    if self.finalBtnDeal.activeSelf then
        self.finalBtnDeal:GetComponent("Button").enabled = allStatus == 1
        Util.SetGray(self.finalBtnDeal, allStatus ~= 1)
    end
end

function TreasureOfSomebodyRewardPageV2:OnOneKeyDealBtnClicked()
    local status = TreasureOfSomebodyManagerV2.GetFinalReceivedStatus()
    if status == 0 then
        PopupTipPanel.ShowTipByLanguageId(11997)
        return
    end
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody)
    NetManager.GetActivityRewardRequest(-1, activityId, function(drop)
        UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
        self:RefreshRewardList()
        self.mainPanel:SetRewardRedPoint()
        RedpotManager.CheckRedPointStatus(RedPointType.TreasureOfSl)
    end)
end

function TreasureOfSomebodyRewardPageV2:RefreshRewardList()
    local currentLevel = TreasureOfSomebodyManagerV2.currentLv
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody)
    local state = TreasureOfSomebodyManagerV2.hadBuyTreasure and -1 or 1
    for i = 1, currentLevel do
        ActivityGiftManager.SetActivityInfo(activityId, i, state)
    end
    self:RefreshPageStatus()
end

function TreasureOfSomebodyRewardPageV2:RefreshTreasureBuy()
    self:InitUnlockCost()
    self:RefreshPageStatus()
end

return TreasureOfSomebodyRewardPageV2