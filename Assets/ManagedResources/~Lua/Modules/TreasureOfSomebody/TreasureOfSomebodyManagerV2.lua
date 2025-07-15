--[[
 * @ClassName TreasureOfSomebodyManagerV2
 * @Description 戒灵秘宝管理
 * @Date 2019/9/24 10:01
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
TreasureOfSomebodyManagerV2 = {}
local this = TreasureOfSomebodyManagerV2

local kScorePropId = 68

function this.Initialize()

end

function this.SetTreasureLocalData()
    this.activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody)
    if not this.activityId then
        return
    end
    local treasureConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.TreasureSunLongConfig, "ActivityType", this.activityId)
    this.treasureMaxLv = treasureConfigs[#treasureConfigs].Level
    this.rewardConfigInfoList = {}
    for _, configInfo in ipairs(treasureConfigs) do
        if configInfo.Reward then
            table.insert(this.rewardConfigInfoList, configInfo)
        end
    end
end

function this.SetTreasureBuyStatus(hadBuy)
    this.hadBuyTreasure = hadBuy == 1
end

function this.SetCurrentLevel(level)
    this.currentLv = level
end

function this.ResetActivityData()
    this.currentLv = 0
    this.hadBuyTreasure = false
    this.SetTreasureLocalData()
end

function this.GetTreasureScore()
    return BagManager.GetItemCountById(kScorePropId)
end

function this.GetTreasureRedPointState()
    local redPoint = false
    -- if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
    --     redPoint = redPoint or this.GetTaskPageRedPointStatus()
    --     redPoint = redPoint or this.GetRewardPageRedPointStatus()
    -- end
    redPoint = GrowthManualManager.RefreshRewardRedpoint()
    for i = 1, 3 do
        if redPoint == false then
            redPoint = GrowthManualManager.RefreshTeskRedpoint(i - 1)
        end
    end

    return redPoint
end

function this.GetTaskPageRedPointStatus()
    local redPoint = false
    if this.currentLv < this.treasureMaxLv then
        local taskList = TaskManager.GetTypeTaskList(TaskTypeDef.TreasureOfSomeBody)
        for _, v in pairs(taskList) do
            if v.state == VipTaskStatusDef.CanReceive then
                redPoint = true
                break
            end
        end
    end
    return redPoint
end
function this.GetTaskTabRedPoint(tabIndex)
    local redPoint = false
    if this.currentLv < this.treasureMaxLv then
        local taskList = TaskManager.GetTypeTaskList(TaskTypeDef.TreasureOfSomeBody)
        local treasureTaskConfig = ConfigManager.GetConfig(ConfigName.TreasureSunLongTaskConfig)
        for _, taskInfo in pairs(taskList) do
            if treasureTaskConfig[taskInfo.missionId].Type == tabIndex and
                    taskInfo.state == VipTaskStatusDef.CanReceive then
                redPoint = true
                break
            end
        end
    end
    return redPoint
end

function this.GetRewardPageRedPointStatus()
    return this.GetFinalReceivedStatus() == 1
end

function this.GetFinalReceivedStatus()
    local allGetStatus = true
    local finalStatus = false
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.TreasureOfSomeBody)
    for _, treasureInfo in ipairs(activityInfo.mission) do
        local state = false
        local stateValue = treasureInfo.state
        if stateValue == 0 then
            allGetStatus = false
            state = this.currentLv >= treasureInfo.missionId
        elseif stateValue == 1 then
            allGetStatus = false
            if this.hadBuyTreasure then
                state = this.currentLv >= treasureInfo.missionId
            end
        end
        finalStatus = finalStatus or state
    end
    if allGetStatus then
        return -1 --当前所有其它已经全部领取
    else
        --1有可以领取0无可领取
        return finalStatus and 1 or 0
    end
end

function this.GetTreasureRedPointShow()
    local page, extraTab
    if this.GetTaskPageRedPointStatus() then
        page = 1
        for i = 1, 3 do
            if this.GetTaskTabRedPoint(i) then
                extraTab = i
                break
            end
        end
    elseif this.GetRewardPageRedPointStatus() then
        page = 2
    end
    return page, extraTab
end

--function this.GetDailyRemainTime()
--    local curTime, zeroTimeStamp, RefreshTimeStamp = math.floor(GetTimeStamp())
--
--    local zeroTab = os.date("*t", curTime)
--    zeroTab.hour = 0
--    zeroTab.min = 0
--    zeroTab.sec = 0
--    zeroTimeStamp = os.time(zeroTab)
--
--    local refreshTab = os.date("*t", curTime)
--    refreshTab.hour = 5
--    refreshTab.min = 0
--    refreshTab.sec = 0
--    RefreshTimeStamp = os.time(refreshTab)
--
--    if curTime > zeroTimeStamp and curTime < RefreshTimeStamp then
--        return RefreshTimeStamp - curTime
--    else
--        return RefreshTimeStamp + 86400 - curTime
--    end
--end
--
--function this.GetWeekRemainTime()
--
--end

return this