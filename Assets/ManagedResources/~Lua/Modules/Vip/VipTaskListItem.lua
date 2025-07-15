--[[
 * @ClassName VipTaskListItem
 * @Description Vip特权任务Item
 * @Date 2019/5/27 11:11
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class VipTaskListItem
local VipTaskListItem = quick_class("VipTaskListItem")

---@param prefab UnityEngine.GameObject
---@param parent UnityEngine.GameObject
function VipTaskListItem:ctor(prefab, parent)
    self.cloneObj = newObjToParent(prefab, parent)
    self:SetVisible(false)
    self.itemPos = Util.GetGameObject(self.cloneObj, "content/itemPos")
    self.giftInfo = SubUIManager.Open(SubUIConfig.ItemView, self.itemPos.transform)
    self.desc = Util.GetGameObject(self.cloneObj, "content/desc"):GetComponent("Text")
    self.progressBar = Util.GetGameObject(self.cloneObj, "content/progressBar"):GetComponent("Slider")
    self.progressValue = Util.GetGameObject(self.cloneObj, "content/dealBtn/value"):GetComponent("Text")
    self.dealBtn = Util.GetGameObject(self.cloneObj, "content/dealBtn")
    self.dealBtn:GetComponent("Button").onClick:AddListener(function()
        self:OnDealBtnClicked()
    end)
    self.finishFlag = Util.GetGameObject(self.cloneObj, "content/finished")
    self.redPoint = Util.GetGameObject(self.cloneObj,"content/redPoint")
end

function VipTaskListItem:Init(taskId)
    self.data = nil
    self.taskConfigInfo = ConfigManager.GetConfigData(ConfigName.TaskConfig, taskId)
    self.giftInfo:OnOpen(false, self.taskConfigInfo.Reward[1], 0.8)
    --if self.taskConfigInfo.TaskValue[1] == 0 then
    --    self.desc.text = string.format(self.taskConfigInfo.Desc, self.taskConfigInfo.TaskValue[2])
    --else
    --    self.desc.text = string.format(self.taskConfigInfo.Desc, unpack(self.taskConfigInfo.TaskValue))
    --end
    self.desc.text = GetLanguageStrById(self.taskConfigInfo.Desc)
    self.progressBar.value = 0
    self.progressValue.text = "0/" .. self.taskConfigInfo.TaskValue[2][1]
    self.dealBtn:SetActive(false)
    self.finishFlag:SetActive(false)
    self.redPoint:SetActive(false)
end

--taskInfo:{missionId,progress,state,type}
function VipTaskListItem:SetValue(taskInfo)
    self.data = taskInfo
    self.progressBar.value = taskInfo.progress / self.taskConfigInfo.TaskValue[2][1]
    self.progressValue.text = string.format("%s/%s", taskInfo.progress, self.taskConfigInfo.TaskValue[2][1])
    self.dealBtn:SetActive(taskInfo.state == VipTaskStatusDef.NotFinished or taskInfo.state == VipTaskStatusDef.CanReceive)
    if self.dealBtn.activeSelf then
        self.dealBtn:GetComponent("Image").sprite = Util.LoadSprite(TaskGetBtnIconDef[taskInfo.state])
    end
    self.finishFlag:SetActive(taskInfo.state == VipTaskStatusDef.Received)
    self.redPoint:SetActive(taskInfo.state == VipTaskStatusDef.CanReceive)
end

function VipTaskListItem:OnDealBtnClicked()
    if self.data.state == VipTaskStatusDef.NotFinished then
        JumpManager.GoJump(self.taskConfigInfo.Jump[1])
    else
        NetManager.TakeMissionRewardRequest(TaskTypeDef.VipTask, self.taskConfigInfo.Id, function(respond)
            UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1)
            TaskManager.SetTypeTaskState(TaskTypeDef.VipTask, self.taskConfigInfo.Id, VipTaskStatusDef.Received)
            Game.GlobalEvent:DispatchEvent(GameEvent.Vip.OnVipTaskStatusChanged, self.taskConfigInfo.Id)
        end)
    end
end

function VipTaskListItem:SetVisible(visible)
    self.cloneObj:SetActive(visible)
end

function VipTaskListItem:destroy()
    destroy(self.cloneObj)
end

return VipTaskListItem