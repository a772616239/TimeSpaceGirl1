--[[
 * @ClassName SevenDayCarnivalManager
 * @Description 开服七天乐管理
 * @Date 2019/7/30 20:43
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
SevenDayCarnivalManager = {}
local this = SevenDayCarnivalManager

local currentScore = 0
local kScoreTaskType = 38
local activityFinalId = nil
local kMaxDay = 7

function this.Initialize()
end
function this.RefreshNextDayData(panelDayNum)
    
    if panelDayNum ~= this.GetCurrentDayNumber() then
        return true
    end
    return false
end
function this.GetSevenDayCarnivalRedPoint()
    local redPoint = false
    local isActivityOpen = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
    if isActivityOpen then
        local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SevenDayCarnival)
        local timeDown = activityInfo.endTime - GetTimeStamp()
        if timeDown  > 0 then-- - 86400
            local taskList = TaskManager.GetTypeTaskList(TaskTypeDef.SevenDayCarnival)
            table.walk(taskList, function(taskInfo)
                local treasureTaskConfig = ConfigManager.GetConfigData(ConfigName.TreasureTaskConfig, taskInfo.missionId)
                if this.GetCurrentDayNumber() >= treasureTaskConfig.DayNum then
                    redPoint = redPoint or (taskInfo.state == VipTaskStatusDef.CanReceive)
                end
            end)
            redPoint = redPoint or this.GetSevenDayHalfPriceRedPoint(this.GetCurrentDayNumber())
        end
        redPoint = redPoint or this.GetBoxRedPointStatus()
    end
    if not redPoint then
        local curDayIndex = SevenDayCarnivalManager.GetCurrentDayNumber()
        if curDayIndex and curDayIndex > 0 then
            for i = 1, curDayIndex do
                if this.GetSevenDayCarnivalRedPoint2(i) then
                    redPoint = true
                end
            end
        end
    end
    return redPoint
end
--添加另一组半价数据红点状态
function this.GetSevenDayCarnivalRedPoint2(curDayIndex)
    local curShopData = ConfigManager.TryGetConfigDataByDoubleKey(ConfigName.StoreTypeConfig,"StoreType",SHOP_TYPE.SEVENDAY_CARNIVAL_SHOP,"Sort",curDayIndex)
    if curShopData then
        local shopInfoList = ShopManager.GetShopDataByShopId(curShopData.Id)
        if shopInfoList and shopInfoList.storeItem then
            for i = 1, #shopInfoList.storeItem do
                local item,num,oldNum = ShopManager.CalculateCostCountByShopId(curShopData.Id, shopInfoList.storeItem[i].id, 1)
                local storeConfig = ConfigManager.GetConfigData(ConfigName.StoreConfig,shopInfoList.storeItem[i].id)
                if num <= 0 and (storeConfig.Limit - shopInfoList.storeItem[i].buyNum) > 0 then
                    return true
                end
            end
        end
    end
    return false
end
function this.InitSevenDayScore()
    local currentActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
    if currentActivityId then
        local treasureTaskConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.TreasureTaskConfig,
                "ActivityId", currentActivityId, "TaskType", kScoreTaskType)
        activityFinalId = treasureTaskConfig.Id
        local taskInfo = TaskManager.GetTypeTaskInfo(TaskTypeDef.SevenDayCarnival, treasureTaskConfig.Id)
        currentScore = 0--taskInfo.progress
    end
end

function this.CheckScoreChange(Id, progress)
    if activityFinalId == Id then
        currentScore = progress
    end
end

function this.GetSevenDayScore()
    return currentScore
end

function this.SetSevenDayScore(score)
    currentScore = score
end

function this.GetCurrentDayNumber()
    local sevenDayActInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SevenDayCarnival)
    if sevenDayActInfo then
        local startTime = sevenDayActInfo.startTime
        --local tab = os.date("*t", startTime)
        --tab.hour = 5
        --tab.min = 0
        --tab.sec = 0
        --local dayTimeStart = os.time(tab)
        --local needDayNumber = math.ceil((GetTimeStamp() - dayTimeStart) / 86400)
        --if startTime < dayTimeStart then
        --    needDayNumber = needDayNumber + 1
        --end
        --return needDayNumber > kMaxDay and kMaxDay or needDayNumber

        local needDayNumber = math.ceil((GetTimeStamp() - startTime) / 86400)
        return needDayNumber > kMaxDay and kMaxDay or needDayNumber
    end
end

--打开界面最先选中的天数
function this.GetPriorityDayNumber()
    local dayIndex
    for i = 1, kMaxDay do
        if this.GetDayNumberRedPointStatus(i) then
            dayIndex = i
            break
        end
    end
    local currentDay = this.GetCurrentDayNumber()
    if not dayIndex or dayIndex > currentDay then
        if currentDay >= kMaxDay then
            dayIndex = kMaxDay
        else
            dayIndex = currentDay
        end
    end
    return dayIndex
end

function this.GetSevenDayHalfPriceRedPoint(day)
    local redPoint = false
    if this.GetCurrentDayNumber() == day then
        local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
        local index = PlayerPrefs.GetInt(PlayerManager.uid .. "_SevenDay" .. "_" .. activityId .. "_" .. day, 0)
        redPoint = redPoint or index == 0
    end
    return redPoint
end

function this.GetDayNumberRedPointStatus(dayNumber)
    local redPoint = false
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
    if this.GetCurrentDayNumber() >= dayNumber then
        local sevenDayConfigs = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.SevenDaysActivity, "BelongDay", dayNumber, "ActivityId", activityId)
        for _, sevenDayInfo in ipairs(sevenDayConfigs) do
            redPoint = redPoint or this.GetGroupRedPointStatus(sevenDayInfo.Id)
        end
    end
    redPoint = redPoint or this.GetSevenDayHalfPriceRedPoint(dayNumber)
    if this.GetSevenDayCarnivalRedPoint2(dayNumber) then
        redPoint = true
    end
    return redPoint
end

function this.GetGroupRedPointStatus(groupId)
    local redPoint = false
    local sevenDayConfig = ConfigManager.GetConfigData(ConfigName.SevenDaysActivity, groupId)
    if this.GetCurrentDayNumber() >= sevenDayConfig.BelongDay then
        local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SevenDayCarnival)
        local timeDown = activityInfo.endTime - GetTimeStamp()
        if timeDown > 0 then-- - 86400
            local taskList = TaskManager.GetTypeTaskList(TaskTypeDef.SevenDayCarnival)
            for _, taskInfo in ipairs(taskList) do
                local treasureTaskConfig = ConfigManager.GetConfigData(ConfigName.TreasureTaskConfig, taskInfo.missionId)
                if treasureTaskConfig.TaskGroup == groupId then
                    redPoint = redPoint or taskInfo.state == 1
                end
            end
        end
    end
    return redPoint
end

function this.GetBoxRedPointStatus()
    local currentActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
    local treasureTaskConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.TreasureTaskConfig,
            "ActivityId", currentActivityId, "TaskType", kScoreTaskType)
    local taskInfo = TaskManager.GetTypeTaskInfo(TaskTypeDef.SevenDayCarnival, treasureTaskConfig.Id)
    if taskInfo then
        return taskInfo.state == 1
    else
        return false
    end
end

return this