--[[
 * @ClassName ContinuityRechargeItem
 * @Description 每日充值Item
 * @Date 2019/8/2 16:49
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class ContinuityRechargeItem
local ContinuityRechargeItem = quick_class("ContinuityRechargeItem")

local kMaxReward = 5
-- function ContinuityRechargeItem:ctor(prefab, parent)
function ContinuityRechargeItem:ctor(prefab)
    -- self.cloneObj = newObjToParent(prefab, parent)
    self.cloneObj = prefab

    self.taskDesc = Util.GetGameObject(self.cloneObj, "titleImage/titleText"):GetComponent("Text")
    self.slider = Util.GetGameObject(self.cloneObj, "titleImage/slider/Image"):GetComponent("Image")

    self.rewardContent = Util.GetGameObject(self.cloneObj, "itemContent")
    self.rewardList = {}
    for i = 1, kMaxReward do
        self.rewardList[i] = SubUIManager.Open(SubUIConfig.ItemView, self.rewardContent.transform)
    end

    self.progress = Util.GetGameObject(self.cloneObj, "progress"):GetComponent("Text")
    self.dealBtn = Util.GetGameObject(self.cloneObj, "dealBtn")
    self.dealBtn:GetComponent("Button").onClick:AddListener(function()
        self:OnDealBtnClicked()
    end)
    self.finished = Util.GetGameObject(self.cloneObj, "finished")
    self.redPoint = Util.GetGameObject(self.cloneObj, "redPoint")

end

function ContinuityRechargeItem:Init(context,sortingOrder)
    self.localContext = context
    self.taskDesc.text = string.format(GetLanguageStrById(11445), context.Sort)
    self.dealBtn:SetActive(true)
    self.finished:SetActive(false)
    self.redPoint:SetActive(false)
    self.progress.text = "0/1"
    self.slider.fillAmount = 0
    table.walk(self.rewardList, function(rewardItem)
        rewardItem.gameObject:SetActive(false)
    end)
    for i, rewardInfo in ipairs(context.Reward) do
        self.rewardList[i]:OnOpen(false, rewardInfo, 0.55,false,false,false,sortingOrder)
        self.rewardList[i].gameObject:SetActive(true)
    end
end

--层级重设 防特效穿透
function ContinuityRechargeItem:OnSortingOrderChange(cursortingOrder)
    for j = 1,#self.rewardList do
        self.rewardList[j]:SetEffectLayer(cursortingOrder)
    end
end

function ContinuityRechargeItem:SetValue()
    self.serverContext = ActivityGiftManager.GetActivityInfo(ActivityTypeDef.ContinuityRecharge, self.localContext.Id)

    local dealBtnTxt = Util.GetGameObject(self.dealBtn, "Text"):GetComponent("Text")
    dealBtnTxt.text = UIBtnText.get
    self.dealBtn:GetComponent("Image").color = UIColorNew.YELLOW
    if self.serverContext.state == 1 then
        self.dealBtn:SetActive(false)
        self.finished:SetActive(true)
        self.redPoint:SetActive(false)
        self.progress.text = "1/1"
        self.serverContext.progress  = 1
    else
        self.finished:SetActive(false)
        self.dealBtn:SetActive(true)
        -- self.dealBtn:GetComponent("Image").sprite = Util.LoadSprite(TaskGetBtnIconDef[self.serverContext.progress])
        self.redPoint:SetActive(self.serverContext.progress == 1)
        self.progress.text = self.serverContext.progress .. "/1"
        self.slider.fillAmount = self.serverContext.progress /1
        if self.serverContext.progress == 1 then
            self.dealBtn:GetComponent("Button").interactable = true
            Util.SetGray(self.dealBtn, false)
        else
            self.dealBtn:GetComponent("Button").interactable = self:IsCurrentSortEnable()
            Util.SetGray(self.dealBtn, not self:IsCurrentSortEnable())

            if self:IsCurrentSortEnable() then
                self.dealBtn:GetComponent("Image").color = UIColorNew.ORANGE
                dealBtnTxt.text = GetLanguageStrById(10436)--立即充值
            end
        end
    end
end

function ContinuityRechargeItem:OnDealBtnClicked()
    if self.serverContext.progress == 0 then
        -- if not ShopManager.IsActive(SHOP_TYPE.SOUL_STONE_SHOP) then
        --     PopupTipPanel.ShowTipByLanguageId(10438)
        --     return
        -- end
        if not ShopManager.SetMainRechargeJump() then
            JumpManager.GoJump(36008)
        else
            JumpManager.GoJump(36006)
        end
        -- UIManager.OpenPanel(UIName.MainRechargePanel, 1)
    else
        NetManager.GetActivityRewardRequest(self.localContext.Id, self.localContext.ActivityId, function(_drop)
            UIManager.OpenPanel(UIName.RewardItemPopup, _drop, 1)
            ActivityGiftManager.SetActivityInfo(
                    ActivityTypeDef.ContinuityRecharge,
                    self.localContext.Id,
                    1
            )
            self.dealBtn:SetActive(false)
            self.finished:SetActive(true)
            self.redPoint:SetActive(false)
            self.cloneObj.transform:SetAsLastSibling()
            CheckRedPointStatus(RedPointType.ContinuityRecharge)
            Game.GlobalEvent:DispatchEvent(GameEvent.Activity.ContinueRechargeRefresh)
        end)
    end
end

--是否轮到当天可充了
function ContinuityRechargeItem:IsCurrentSortEnable()
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.ContinuityRecharge)
    return activityInfo.value + 1 == self.localContext.Sort
end

function ContinuityRechargeItem:TrySetLastSibling()
    if self.serverContext.state == 1 then
        self.cloneObj.transform:SetAsLastSibling()
    end
end

return ContinuityRechargeItem