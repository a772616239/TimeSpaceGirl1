--[[
 * @ClassName DayRewardItem
 * @Description 首冲每日奖励
 * @Date 2019/6/3 14:41
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class DayRewardItem
local DayRewardItem = quick_class("DayRewardItem")

local kRewardCount = 2

---@param transform UnityEngine.Transform
function DayRewardItem:ctor(mainPanel,transform)
    self.mainPanel = mainPanel
    self.transform = transform
    self.title = Util.GetGameObject(self.transform, "title")
    self.title2 = Util.GetGameObject(self.transform, "title2")
    self.rewardContent = Util.GetGameObject(self.transform, "rewardList")
    self.rewardList = {}
    for i = 1, kRewardCount do
        self.rewardList[i] = SubUIManager.Open(SubUIConfig.ItemView, self.rewardContent.transform)
    end
    self.receiveBtn = Util.GetGameObject(self.transform, "receiveBtn"):GetComponent("Button")
    self.receiveBtn.onClick:AddListener(function()
        self:OnReceivedBtnClicked()
    end)
    self.receivedFlag = Util.GetGameObject(self.transform, "receivedFlag")
    self.redPoint = Util.GetGameObject(self.transform,"redPoint")
end
function DayRewardItem:OnSortingOrderChange(cursortingOrder)
    for i = 1, #self.rewardList do
        self.rewardList[i]:SetEffectLayer(cursortingOrder)
    end
end
function DayRewardItem:SetValue(context,_sortingOrder)
    local sortingOrder = _sortingOrder or 0
    self.context = context
    for i, rewardInfo in ipairs(context.Reward) do
        self.rewardList[i]:OnOpen(false, rewardInfo, 0.9,false,false,false,sortingOrder)
    end

    --if FirstRechargeManager.GetRechargeTime() == 0 then
    --    self.receiveBtn.gameObject:SetActive(true)
    --    self.receiveBtn.interactable = false
    --    self.receivedFlag:SetActive(false)
    --    --self.redPoint:SetActive(false)
    --else
        local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FirstRecharge)
        local AccumRecharge = 0
        for _, missInfo in pairs(activityInfo.mission) do
            if missInfo and missInfo.progress then
                AccumRecharge = missInfo.progress
            end
        end

        local itemView = Util.GetGameObject(self.transform,"rewardList")
        --如果充值大于6/100
        if AccumRecharge/1000 >= self.context.Values[1][1] then
            local day = GetTimePass(FirstRechargeManager.GetRechargeTime())--FirstRechargeManager.GetRechargeTime() 
            if self.context.Values[1][2] <=  day then
                --到天数
                local state = ActivityGiftManager.GetActivityInfo(context.ActivityId, context.Id).state
                self.receivedFlag:SetActive(state == 1)
                self.receiveBtn.gameObject:SetActive(state ~= 1)
                -- self.title.gameObject:SetActive(state == 1)
                self.redPoint:SetActive(state ~= 1)

                if state == 0 then
                    --可领取
                    self.title:SetActive(false)
                    self.title2:SetActive(true)
                    self.transform:GetComponent("Image").color = Color.New(254/255,210/255,55/255,1)
                    Util.GetGameObject(self.transform, "Image"):GetComponent("Image").color = Color.New(233/255,155/255,19/255,1)
                    for i = 1, itemView.transform.childCount do
                        Util.GetGameObject(itemView.transform:GetChild(i-1),"item/frame"):GetComponent("Image").color = Color.New(255/255,255/255,255/255,255/255)
                        Util.GetGameObject(itemView.transform:GetChild(i-1),"item/icon"):GetComponent("Image").color = Color.New(255/255,255/255,255/255,255/255)
                        Util.GetGameObject(itemView.transform:GetChild(i-1),"item/num"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,255/255)
                    end
                else
                    --已领取
                    self.title:SetActive(true)
                    self.title2:SetActive(false)
                    self.transform:GetComponent("Image").color = Color.New(163/255,124/255,228/255,127/255)
                    Util.GetGameObject(self.transform, "Image"):GetComponent("Image").color = Color.New(139/255,91/255,218/255,127/255)
                    for i = 1, itemView.transform.childCount do
                        Util.GetGameObject(itemView.transform:GetChild(i-1),"item/frame"):GetComponent("Image").color = Color.New(255/255,255/255,255/255,127/255)
                        Util.GetGameObject(itemView.transform:GetChild(i-1),"item/icon"):GetComponent("Image").color = Color.New(255/255,255/255,255/255,127/255)
                        Util.GetGameObject(itemView.transform:GetChild(i-1),"item/num"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,127/255)
                    end           
                end
            else
                --未到天数
                self.title:SetActive(true)
                self.title2:SetActive(false)
                Util.GetGameObject(self.transform, "Image"):GetComponent("Image").color = Color.New(139/255,91/255,218/255,1)
                self.transform:GetComponent("Image").color = Color.New(163/255,124/255,228/255,1)
                for i = 1, itemView.transform.childCount do
                    Util.GetGameObject(itemView.transform:GetChild(i-1),"item/frame"):GetComponent("Image").color = Color.New(255/255,255/255,255/255,1)
                    Util.GetGameObject(itemView.transform:GetChild(i-1),"item/icon"):GetComponent("Image").color = Color.New(255/255,255/255,255/255,1)
                    Util.GetGameObject(itemView.transform:GetChild(i-1),"item/num"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,1)
                end

                self.receiveBtn.gameObject:SetActive(false)
                self.title:SetActive(true)
                self.receivedFlag:SetActive(false)
                self.redPoint:SetActive(false)
            end
        else
            --充值不达标
            self.title:SetActive(true)
            self.title2:SetActive(false)
            Util.GetGameObject(self.transform, "Image"):GetComponent("Image").color = Color.New(139/255,91/255,218/255,1)
            self.transform:GetComponent("Image").color = Color.New(163/255,124/255,228/255,1)
            for i = 1, itemView.transform.childCount do
                Util.GetGameObject(itemView.transform:GetChild(i-1),"item/frame"):GetComponent("Image").color = Color.New(255/255,255/255,255/255,1)
                Util.GetGameObject(itemView.transform:GetChild(i-1),"item/icon"):GetComponent("Image").color = Color.New(255/255,255/255,255/255,1)
                Util.GetGameObject(itemView.transform:GetChild(i-1),"item/num"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,1)
            end
            
            self.receiveBtn.gameObject:SetActive(false)
            self.title.gameObject:SetActive(true)
            self.receivedFlag:SetActive(false)
            self.redPoint:SetActive(false)
        end
    --end
end

function DayRewardItem:OnReceivedBtnClicked()
    NetManager.GetActivityRewardRequest(self.context.Id,ActivityTypeDef.FirstRecharge, function(drop)
        local rewardItemPopup = UIManager.OpenPanel(UIName.RewardItemPopup, drop, 1)

        if drop.Hero ~= nil and #drop.Hero > 0 then
            local itemDataList = {}
            local itemDataStarList = {}
            rewardItemPopup.gameObject:SetActive(false)
            for i = 1, #drop.Hero do
                local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", drop.Hero[i].heroId)
                table.insert(itemDataList, heroData)
                table.insert(itemDataStarList, drop.Hero[i].star)
            end
            UIManager.OpenPanel(UIName.PublicGetHeroPanel,itemDataList,itemDataStarList,function ()
                rewardItemPopup.gameObject:SetActive(true)
            end)
        end

        ActivityGiftManager.SetActivityInfo(self.context.ActivityId, self.context.Id, 1)
        self.receiveBtn.gameObject:SetActive(false)

        self.title:SetActive(true)
        self.title2:SetActive(false)
        self.transform:GetComponent("Image").color = Color.New(163/255,124/255,228/255,127/255)
        local itemView = Util.GetGameObject(self.transform,"rewardList")
        Util.GetGameObject(self.transform, "Image"):GetComponent("Image").color = Color.New(139/255,91/255,218/255,127/255)
        for i = 1, itemView.transform.childCount do
            Util.GetGameObject(itemView.transform:GetChild(i-1),"item/frame"):GetComponent("Image").color = Color.New(255/255,255/255,255/255,127/255)
            Util.GetGameObject(itemView.transform:GetChild(i-1),"item/icon"):GetComponent("Image").color = Color.New(255/255,255/255,255/255,127/255)
            Util.GetGameObject(itemView.transform:GetChild(i-1),"item/num"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,127/255)
        end    

        self.receivedFlag:SetActive(true)
        self.redPoint:SetActive(false)
        self.mainPanel:SetTabRedPointStatus(IndexValueDef[self.context.Values[1][1]])
        CheckRedPointStatus(RedPointType.FirstRecharge)
        if FirstRechargeManager.GetReceiveAll() then
            Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityOpenOrClose, {
                type = ActivityTypeDef.FirstRecharge,
                status = 0 --关闭
            })
        end
    end)
end

return DayRewardItem