--[[
 * @ClassName DailyRechargePanel
 * @Description 每日首充
 * @Date 2019/8/1 19:28
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class DailyRechargePanel
-- local DailyRechargePanel = quick_class("DailyRechargePanel", BasePanel)

local DailyRechargePanel = Inherit(BasePanel)
local this = DailyRechargePanel
local kMaxReward = 4
local cursortingOrder
local isFirstOpen = false
local curIndex
local img = {
    "cn2-X1_jinrishouchong_chongzhi",
    "cn2-X1_baridenglu_lingqu"
}
local type = ActivityTypeDef.DailyRecharge

function DailyRechargePanel:InitComponent()
    cursortingOrder = 0
    self.backBtn = Util.GetGameObject(self.transform, "btnBack")

    self.rewardContent = {}
    self.rewardContentEffect = {}
    self.rewardList = {}
    for i = 1, kMaxReward do
        self.rewardContent[i] = Util.GetGameObject(self.transform, "frame/bg/rewardContent/itemPos_" .. i)
        self.rewardContentEffect[i] = Util.GetGameObject(self.rewardContent[i], "Kuang")
        effectAdapte(self.rewardContentEffect[i])
        self.rewardList[i] = SubUIManager.Open(SubUIConfig.ItemView, self.rewardContent[i].transform)
        Util.GetGameObject(self.rewardList[i].gameObject,"item/num"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,127/255)
    end

    self.dealBtn = Util.GetGameObject(self.transform, "frame/bg/dealBtn")
    self.UI_effect_DailyRechargePanel_particle = Util.GetGameObject(self.transform, "frame/UI_effect_DailyRechargePanel_particle")
    self.NeedRechange = Util.GetGameObject(self.transform, "frame/bg/descbg/NeedRechange")
    self.NeedRechangeNum = Util.GetGameObject(self.transform,"frame/bg/descbg/NeedRechange/needNumTxt"):GetComponent("Text")
    self.CanReward = Util.GetGameObject(self.transform, "frame/bg/descbg/CanReward")

    self.smallAmount = Util.GetGameObject(self.transform, "frame/bg/choose/smallAmount")
    self.largeAmount = Util.GetGameObject(self.transform, "frame/bg/choose/largeAmount")

    self.received = Util.GetGameObject(self.transform, "frame/bg/Received")
    self.content = Util.GetGameObject(self.transform, "frame/bg/rewardContent")
end

function DailyRechargePanel:BindEvent()
    Util.AddClick(self.backBtn, function()
        if not isFirstOpen then
            self:ClosePanel()
        end
    end)
    Util.AddClick(self.dealBtn, function()
        if not isFirstOpen then
            if self.missionInfo.state == 1 then
                PopupTipPanel.ShowTipByLanguageId(10437)
            else
                if DailyRechargeManager.ReceivedEnabled(type) then
                    NetManager.GetActivityRewardRequest(self.missionInfo.missionId, self.activityId, function(_drop)
                        UIManager.OpenPanel(UIName.RewardItemPopup, _drop, 1)
                        DailyRechargeManager.SetRechargeState(type, 1)
                        
                        Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityOpenOrClose, {
                            type = ActivityTypeDef.DailyRecharge,
                            status = 0
                        })
                    end)
                else
                    if not ShopManager.SetMainRechargeJump() then
                        JumpManager.GoJump(36008)
                    else
                        JumpManager.GoJump(36006)
                    end
                    -- UIManager.OpenPanel(UIName.MainRechargePanel, 1)
                end
                self:ClosePanel()
            end
        end
    end)
    Util.AddClick(self.smallAmount, function ()
        Util.GetGameObject(self.largeAmount, "select"):SetActive(false)
        Util.GetGameObject(self.smallAmount, "select"):SetActive(true)
        self:RefreshPanel(1)
    end)
    Util.AddClick(self.largeAmount, function ()
        Util.GetGameObject(self.smallAmount, "select"):SetActive(false)
        Util.GetGameObject(self.largeAmount, "select"):SetActive(true)
        self:RefreshPanel(2)
    end)
end

function DailyRechargePanel:OnOpen()
    isFirstOpen = true
    self:RefreshPanel(1)
    Timer.New(function ()
        isFirstOpen = false
    end, 1):Start()

    local config = ActivityGiftManager.GetActivityTypeInfo2(ActivityTypeDef.DailyRecharge)
    Util.GetGameObject(self.smallAmount, "Text"):GetComponent("Text").text = GetLanguageStrById(config.ExpertDec)
    Util.GetGameObject(self.smallAmount, "select/Text"):GetComponent("Text").text = GetLanguageStrById(config.ExpertDec)
    config = ActivityGiftManager.GetActivityTypeInfo2(ActivityTypeDef.DailyRecharge_2)
    Util.GetGameObject(self.largeAmount, "Text"):GetComponent("Text").text = GetLanguageStrById(config.ExpertDec)
    Util.GetGameObject(self.largeAmount, "select/Text"):GetComponent("Text").text = GetLanguageStrById(config.ExpertDec)
end

function DailyRechargePanel:OnSortingOrderChange()
    Util.AddParticleSortLayer( self.UI_effect_DailyRechargePanel_particle, self.sortingOrder - cursortingOrder)
    for i = 1, #self.rewardContentEffect do
        Util.AddParticleSortLayer( self.rewardContentEffect[i], self.sortingOrder - cursortingOrder)
    end
    cursortingOrder = self.sortingOrder
end

function DailyRechargePanel:OnShow()
    -- Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose, self.RefreshPanel, self)
    Util.GetGameObject(self.largeAmount, "select"):SetActive(false)
    Util.GetGameObject(self.smallAmount, "select"):SetActive(true)
    self:RefreshPanel(1)
end

function DailyRechargePanel:OnClose()
    -- Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose, self.RefreshPanel, self)
end

function DailyRechargePanel:RefreshPanel(index)
    curIndex = index
    CheckRedPointStatus(RedPointType.DailyRecharge)
    Util.GetGameObject(self.smallAmount, "redpoint"):SetActive(DailyRechargeManager.RefreshRedpoint_type(1))
    Util.GetGameObject(self.largeAmount, "redpoint"):SetActive(DailyRechargeManager.RefreshRedpoint_type(2))
    if curIndex == 1 then
        type = ActivityTypeDef.DailyRecharge
    else
        type = ActivityTypeDef.DailyRecharge_2
    end
    dailyActInfo = ActivityGiftManager.GetActivityTypeInfo(type)
    self.activityId = dailyActInfo.activityId
    self.missionInfo = dailyActInfo.mission[1]

    if not self.missionInfo then
        self.NeedRechange:SetActive(false)
        self.CanReward:SetActive(true)
        self.received:SetActive(true)
        self.content:SetActive(false)
        Util.SetGray(self.dealBtn, true)
        return
    end

    local actRewardConfig = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig, self.missionInfo.missionId)

    if self.missionInfo.state == 0 then
        self.received:SetActive(false)
        self.content:SetActive(true)
        Util.SetGray(self.dealBtn, false)
        if DailyRechargeManager.GetRechargeValue(type) == 0 then
            self.NeedRechangeNum.text = actRewardConfig.Values[1][1] * 10

            DailyRechargePanel:SetUIState(1)
        else
            if DailyRechargeManager.ReceivedEnabled(type) then
                DailyRechargePanel:SetUIState(2)
            else
                local remainValue = actRewardConfig.Values[1][1] * 10 - DailyRechargeManager.GetRechargeValue(type)/100
                remainValue = remainValue < 0 and 0 or remainValue
                self.NeedRechangeNum.text = remainValue

                DailyRechargePanel:SetUIState(1)
            end
        end
    else
        self.NeedRechange:SetActive(false)
        self.CanReward:SetActive(true)
        self.received:SetActive(true)
        self.content:SetActive(false)
        Util.SetGray(self.dealBtn, true)
    end
    table.walk(self.rewardContent, function(rewardPosItem)
        rewardPosItem:SetActive(false)
    end)
    for i, rewardInfo in ipairs(actRewardConfig.Reward) do
        self.rewardList[i]:OnOpen(false, rewardInfo, 1.0)
        self.rewardContent[i]:SetActive(true)
    end
end

function DailyRechargePanel:SetUIState(state)
    self.dealBtn:GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont(img[state]))
    self.NeedRechange:SetActive(state == 1)
    self.CanReward:SetActive(state == 2)
end

return DailyRechargePanel