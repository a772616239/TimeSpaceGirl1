--[[
 * @ClassName SevenDayCarnivalTaskItem
 * @Description 开服七日狂欢任务Item
 * @Date 2019/7/31 14:45
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class SevenDayCarnivalTaskItem
local SevenDayCarnivalTaskItem = quick_class("SevenDayCarnivalTaskItem")

local kMaxReward = 2

function SevenDayCarnivalTaskItem:ctor(prefab, parent)
    self.cloneObj = newObjToParent(prefab, parent)

    self.taskDesc = Util.GetGameObject(self.cloneObj, "content/desc"):GetComponent("Text")

    self.rewardContent = Util.GetGameObject(self.cloneObj, "content/itemContent")
    self.rewardList = {}
    for i = 1, kMaxReward do
        self.rewardList[i] = SubUIManager.Open(SubUIConfig.ItemView, self.rewardContent.transform)
    end

    self.currentPart = Util.GetGameObject(self.cloneObj, "content/current")
    self.progress = Util.GetGameObject(self.currentPart, "progress"):GetComponent("Text")
    self.dealBtn = Util.GetGameObject(self.currentPart, "dealBtn")
    self.dealBtn:GetComponent("Button").onClick:AddListener(function()
        self:OnDealBtnClicked()
    end)
    self.finished = Util.GetGameObject(self.currentPart, "finished")
    --self.redPoint = Util.GetGameObject(self.currentPart, "redPoint")

    self.advancePart = Util.GetGameObject(self.cloneObj, "content/advance")

end

function SevenDayCarnivalTaskItem:Init(context,sortingOrder)
    self.localContext = context
    self.taskDesc.text = context.Show
    self.dealBtn:SetActive(false)
    self.finished:SetActive(false)
    --self.redPoint:SetActive(false)
    table.walk(self.rewardList, function(rewardItem)
        rewardItem.gameObject:SetActive(false)
    end)
    for i, rewardInfo in ipairs(context.Reward) do
        self.rewardList[i]:OnOpen(false, rewardInfo, 0.8,false,false,false,sortingOrder)
        self.rewardList[i].gameObject:SetActive(true)
    end
end
function SevenDayCarnivalTaskItem:OnSortingOrderChange(cursortingOrder)
    for i = 1, #self.rewardList do
        self.rewardList[i]:SetEffectLayer(cursortingOrder)
    end
end
function SevenDayCarnivalTaskItem:SetValue(flag)
    self.currentPart:SetActive(flag)
    self.advancePart:SetActive(not flag)
    if not flag then
        return
    end
    self.serverContext = TaskManager.GetTypeTaskInfo(TaskTypeDef.SevenDayCarnival, self.localContext.Id)
    if self.localContext.Jump[1] then
        self.dealBtn:SetActive(self.serverContext.state ~= VipTaskStatusDef.Received)
    else
        self.dealBtn:SetActive(self.serverContext.state == VipTaskStatusDef.CanReceive)
    end
    if self.dealBtn.activeSelf then
        self.dealBtn:GetComponent("Image").sprite = Util.LoadSprite(TaskGetBtnIconDef[self.serverContext.state])
    end
    local targetTime = self.localContext.TaskValue[2][1]
    targetTime = targetTime > 0 and targetTime or 1
    self.progress.text = self.serverContext.progress + self.serverContext.takeTimes .. "/" .. targetTime
    --self.redPoint:SetActive(self.serverContext.state == VipTaskStatusDef.CanReceive)
    self.finished:SetActive(self.serverContext.state == VipTaskStatusDef.Received)
end

function SevenDayCarnivalTaskItem:OnDealBtnClicked()
    if self.serverContext.state == VipTaskStatusDef.NotFinished then
        JumpManager.GoJump(self.localContext.Jump[1])
    else
        NetManager.TakeMissionRewardRequest(TaskTypeDef.SevenDayCarnival, self.localContext.Id, function(respond)
            UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1)
            --TaskManager.SetTypeTaskState(
            --        TaskTypeDef.SevenDayCarnival,
            --        self.localContext.Id,
            --        VipTaskStatusDef.Received,
            --        0,
            --        self.serverContext.progress + self.serverContext.takeTimes
            --)
        end)
    end
end

function SevenDayCarnivalTaskItem:SetVisible(flags)
    self.cloneObj:SetActive(flags)
end

function SevenDayCarnivalTaskItem:SetDisabled(flag)
    self.dealBtn:GetComponent("Button").interactable = flag
    Util.SetGray(self.dealBtn, not flag)
    --self.redPoint:SetActive(false)
end

return SevenDayCarnivalTaskItem