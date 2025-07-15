--[[
 * @ClassName SevenDayRewardPreviewPanel
 * @Description 七日奖励预览
 * @Date 2019/8/9 15:47
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class SevenDayRewardPreviewPanel
local SevenDayRewardPreviewPanel = quick_class("SevenDayRewardPreviewPanel", BasePanel)

local kScoreTaskType = 38

function SevenDayRewardPreviewPanel:InitComponent()
    self.closeBtn = Util.GetGameObject(self.transform, "bg/closeBtn")

    self.itemPos = Util.GetGameObject(self.transform, "bg/itemPos")
    self.itemView = nil

    self.taskProgress = Util.GetGameObject(self.transform, "bg/taskProgressBg/value"):GetComponent("Text")
    self.currentProgress = Util.GetGameObject(self.transform, "bg/currentProgressBg/value"):GetComponent("Text")
    self.canReceiveValue = Util.GetGameObject(self.transform, "bg/canReceiveBg/value"):GetComponent("Text")

    self.rewardPart = Util.GetGameObject(self.transform, "bg/finalTarget")
    self.remainTimes = Util.GetGameObject(self.rewardPart, "remainTimes"):GetComponent("Text")
    self.rewardProgress = Util.GetGameObject(self.rewardPart, "progressbar/progress"):GetComponent("Image")
    self.rewardValue = Util.GetGameObject(self.rewardPart, "progressbar/value"):GetComponent("Text")
    self.rewardPos = Util.GetGameObject(self.rewardPart, "rewardPos")
    self.rewardView = nil

    self.receiveBtn = Util.GetGameObject(self.transform, "bg/receiveBtn")
    self.receiveBtnText = Util.GetGameObject(self.receiveBtn, "Text"):GetComponent("Text")

    self.ruleTips = Util.GetGameObject(self.transform, "bg/ruleTips"):GetComponent("Text")
end

function SevenDayRewardPreviewPanel:BindEvent()
    Util.AddClick(self.closeBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(self.receiveBtn, function()
        self:OnReceivedBtnClicked()
    end)
end

function SevenDayRewardPreviewPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, self.RefreshPanel, self)
end

function SevenDayRewardPreviewPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, self.RefreshPanel, self)
end

function SevenDayRewardPreviewPanel:OnOpen()
    self:RefreshPanel()
end

function SevenDayRewardPreviewPanel:OnShow()
    self:SetRemainTimes()
end

function SevenDayRewardPreviewPanel:OnClose()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end

function SevenDayRewardPreviewPanel:OnReceivedBtnClicked()
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
    local treasureTaskConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.TreasureTaskConfig,
            "ActivityId", activityId, "TaskType", kScoreTaskType)
    NetManager.GetSevenDayCarnivalBoxReward(function(respond)
        self:ClosePanel()
        UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1)
        TaskManager.SetTypeTaskState(
                TaskTypeDef.SevenDayCarnival,
                treasureTaskConfig.Id,
                VipTaskStatusDef.Received,
                0,
                1
        )
    end)
end

function SevenDayRewardPreviewPanel:RefreshPanel()
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
    local globalActConfig = ConfigManager.GetConfigData(ConfigName.GlobalActivity, activityId)
    self.ruleTips.text = string.gsub(globalActConfig.ExpertDec, "\\n", "\n")
    local treasureTaskConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.TreasureTaskConfig,
            "ActivityId", activityId, "TaskType", kScoreTaskType)
    self:SetItemViews(treasureTaskConfig.Reward)
    local taskInfo = TaskManager.GetTypeTaskInfo(TaskTypeDef.SevenDayCarnival, treasureTaskConfig.Id)
    if taskInfo.state == VipTaskStatusDef.Received then
        self.receiveBtnText.text = GetLanguageStrById(10350)
        Util.SetGray(self.receiveBtn, true)
        self.receiveBtn:GetComponent("Button").interactable = false
    elseif taskInfo.state == VipTaskStatusDef.NotFinished then
        self.receiveBtnText.text = GetLanguageStrById(10022)
        Util.SetGray(self.receiveBtn, true)
        self.receiveBtn:GetComponent("Button").interactable = false
    else
        self.receiveBtn:GetComponent("Button").interactable = true
        self.receiveBtnText.text = GetLanguageStrById(10022)
        Util.SetGray(self.receiveBtn, false)
    end
    local currentScore = SevenDayCarnivalManager.GetSevenDayScore()
    self.rewardProgress.fillAmount = currentScore / treasureTaskConfig.TaskValue[2][1]
    self.rewardValue.text = currentScore .. "/" .. treasureTaskConfig.TaskValue[2][1]
    self.taskProgress.text = "（"..currentScore .. "/" .. treasureTaskConfig.TaskValue[2][1].."）"
    local percentValue = (currentScore / treasureTaskConfig.TaskValue[2][1]) * 100
    self.currentProgress.text = "（"..string.format("%d%%", percentValue).."）"
    self.canReceiveValue.text = "（"..currentScore .. GetLanguageStrById(10218).."）"
end

function SevenDayRewardPreviewPanel:SetItemViews(reward)
    if self.rewardView and self.itemView then
        local rewardList = table.clone(reward[1])
        rewardList[2] = 0
        self.itemView:OnOpen(false, rewardList, 1.2)
        self.rewardView:OnOpen(false, rewardList, 0.55)
        return
    end
    local rewardList = table.clone(reward[1])
    rewardList[2] = 0
    self.itemView = SubUIManager.Open(SubUIConfig.ItemView, self.itemPos.transform)
    self.itemView:OnOpen(false, rewardList, 1.2)
    self.rewardView = SubUIManager.Open(SubUIConfig.ItemView, self.rewardPos.transform)
    self.rewardView:OnOpen(false, rewardList, 0.55)
end

function SevenDayRewardPreviewPanel:SetRemainTimes()
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SevenDayCarnival)
    if not activityInfo then
        self:ClosePanel()
        return
    end
    local timeDown = activityInfo.endTime - GetTimeStamp()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    if timeDown < 1 then
        self:ClosePanel()
        return
    end
    self:SetRemainTimeFormat(timeDown)
    self.timer = Timer.New(function()
        self:SetRemainTimeFormat(timeDown)
        if timeDown < 1 then
            self.timer:Stop()
            self.timer = nil
            self:ClosePanel()
        end
        timeDown = timeDown - 1
    end, 1, -1, true)
    self.timer:Start()
end

function SevenDayRewardPreviewPanel:SetRemainTimeFormat(timeDown)
    if timeDown - 86400 > 0 then
        self.remainTimes.text = GetLanguageStrById(11925) .. DateUtils.GetTimeFormatV2(timeDown - 86400)
    else
        self.remainTimes.text = ""
    end
end

return SevenDayRewardPreviewPanel