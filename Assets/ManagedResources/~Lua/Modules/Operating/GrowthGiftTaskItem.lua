--[[
 * @ClassName GrowthGiftTaskItem
 * @Description 成长基金任务Item
 * @Date 2019/5/25 17:01
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class GrowthGiftTaskItem
local GrowthGiftTaskItem = quick_class("GrowthGiftTaskItem")
local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local GrowthRewardId = nil

function GrowthGiftTaskItem:ctor(prefab, parent)
    self.cloneObj = newObjToParent(prefab, parent)
    self.itemPos = Util.GetGameObject(self.cloneObj, "itemPos_1")
    self.giftInfo = SubUIManager.Open(SubUIConfig.ItemView, self.itemPos.transform)
    self.desc = Util.GetGameObject(self.cloneObj, "desc"):GetComponent("Text")
    self.receiveBtn = Util.GetGameObject(self.cloneObj, "btnDeal")
    self.receiveBtn:GetComponent("Button").onClick:AddListener(function()
        self:OnBtnDealClicked()
    end)
    self.finished = Util.GetGameObject(self.cloneObj, "finished")
    self.redPoint = Util.GetGameObject(self.cloneObj,"redPoint")
end
local sortingOrder = 0
function GrowthGiftTaskItem:Init(configData,_sortingOrder)
    GrowthRewardId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.GrowthReward)
    self.context = configData
    sortingOrder = _sortingOrder or 0
    self.giftInfo:OnOpen(false, configData.Reward[1], 0.8,false,false,false,sortingOrder)
    if configData.Values[1][1] == ConditionType.Level then
        self.desc.text = string.format(GetLanguageStrById(11472), configData.Values[1][2])
    else
        self.desc.text = string.format(GetLanguageStrById(11473), configData.Values[1][2])
    end
    self.finished:SetActive(false)
    Util.SetGray(self.receiveBtn, true)
end
function GrowthGiftTaskItem:OnSortingOrderChange(cursortingOrder)
    if self.giftInfo then
        self.giftInfo:OnOpen(false, self.context.Reward[1], 0.8,false,false,false,cursortingOrder)
    end
end
function GrowthGiftTaskItem:SetValue()
    local activityInfo = ActivityGiftManager.GetActivityInfo(GrowthRewardId, self.context.Id)--获取活动数据 self.context.Id
    local goods = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.GrowthReward, GlobalActivity[GrowthRewardId].CanBuyRechargeId)--判断当前礼包是否已投资
    
    if activityInfo then
        self.state = activityInfo.state
        self.finished:SetActive(self.state == 1)
        self.receiveBtn.gameObject:SetActive(self.state == 0)
        if self.state == 0 then --未领取
            self.receiveStatus = PlayerManager.level >= self.context.Values[1][2]
            Util.SetGray(self.receiveBtn, not self.receiveStatus)
            self.redPoint:SetActive(self.receiveStatus)
            -- if self.receiveStatus then--判断是否达到等级
                -- Util.SetGray(self.receiveBtn, not self.receiveStatus)
                -- if(GrowthRewardId == ActivityTypeDef.GrowthReward)then--吸引玩家点击
                --     self.redPoint:SetActive(true)
                --     self.receiveStatus = true
                -- else
                --     self.redPoint:SetActive(not goods)
                -- end
            -- else
            --     self.redPoint:SetActive(false)
            -- end
        else
            --已达成,领取完毕
            self.receiveStatus = false
            self.redPoint:SetActive(false)
        end
    else
        self.finished:SetActive(false)
        self.receiveStatus = false
        self.receiveBtn.gameObject:SetActive(true)
        Util.SetGray(self.receiveBtn, true)
    end
    --本地红点处理
    --OperatingManager.GetGrowthRedPointState(GrowthRewardId)
end

function GrowthGiftTaskItem:OnBtnDealClicked()
    
    local openStatus = ActivityGiftManager.GetActivityOpenStatus(GrowthRewardId)
    local goods = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.GrowthReward, GlobalActivity[GrowthRewardId].CanBuyRechargeId)
    if not openStatus or (goods and goods.buyTimes < 1) then
        PopupTipPanel.ShowTipByLanguageId(11474)
        return
    end
    if self.receiveStatus then
        NetManager.GetActivityRewardRequest(self.context.Id,GrowthRewardId, function(drop)
            UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)
            ActivityGiftManager.SetActivityInfo(self.context.ActivityId, self.context.Id, 1)
            self.receiveBtn.gameObject:SetActive(false)
            self.redPoint:SetActive(false)
            self.finished:SetActive(true)
            self.state = 1
            CheckRedPointStatus(RedPointType.GrowthGift)

            --检测奖励是否全部领完
            local t = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", GrowthRewardId)
            for i = 1, #t do
                local info = ActivityGiftManager.GetActivityInfo(GrowthRewardId, t[i].Id)
                if info.state ~= 1 then
                    Game.GlobalEvent:DispatchEvent(GameEvent.GrowGift.GetAllGift)
                    return
                end
            end
            if(GrowthRewardId == 16)then--16是最后一个礼包的ActivityId
                MsgPanel.ShowOne(GetLanguageStrById(11468))
            else
                MsgPanel.ShowOne(GetLanguageStrById(11469))
            end
            Game.GlobalEvent:DispatchEvent(GameEvent.GrowGift.GetAllGift)
        end)
    else
        PopupTipPanel.ShowTipByLanguageId(11475)
    end
end

return GrowthGiftTaskItem