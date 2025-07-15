GrowthManualManager = {}
local this = GrowthManualManager
local TreasureSunlongConfig = ConfigManager.GetConfig(ConfigName.TreasureSunLongConfig)
local TreasureSunLongTaskConfig = ConfigManager.GetConfig(ConfigName.TreasureSunLongTaskConfig)
this.rewardData = {}--表内活动任务数据
local taskData = {}
this.scoreId = 0
this.score = 0
this.traiWeekTime = 0
this.level = 0
this.hadBuyTreasure = false

function this.Initialize()
    this.InitializeData()
end

function this.InitializeData()
    this.rewardData = {}
    taskData = {}
    this.scoreId = TreasureSunlongConfig[1].Integral[1][1]
    for i, v in ConfigPairs(TreasureSunlongConfig) do
        if not this.rewardData[v.ActivityType] then
            this.rewardData[v.ActivityType] = {}
        end
        if not this.rewardData[v.ActivityType][v.Level] then
            this.rewardData[v.ActivityType][v.Level] = {}
        end
        this.rewardData[v.ActivityType][v.Level].level = v.Level
        this.rewardData[v.ActivityType][v.Level].activityId = v.ActivityType
        if v.Integral then
            this.rewardData[v.ActivityType][v.Level].needScore = v.Integral[1][2]
        else
            this.rewardData[v.ActivityType][v.Level].needScore = 0
        end
        this.rewardData[v.ActivityType][v.Level].state = -2
        this.rewardData[v.ActivityType][v.Level].Reward = {}
        local temp = {}
        this.rewardData[v.ActivityType][v.Level].type = 2
        if v.Reward then
            for n,m in ipairs(v.Reward) do
                table.insert(temp,{ type = 1,item = { m[1] , m[2] } })
            end
        else
            this.rewardData[v.ActivityType][v.Level].type = 1
        end
        if v.TreasureReward then
            for n,m in ipairs(v.TreasureReward) do
                table.insert(temp,{ type = 2,item = { m[1] , m[2] } })
            end
        end
        this.rewardData[v.ActivityType][v.Level].Reward = temp
        this.rewardData[v.ActivityType][v.Level].LevelCondLimit = v.LevelCond[1]

    end
    for i, v in ConfigPairs(TreasureSunLongTaskConfig) do
        if not taskData[v.ActivityId] then
            taskData[v.ActivityId] = {}
        end
        if not taskData[v.ActivityId][v.Type] then
            taskData[v.ActivityId][v.Type] = {}
        end
        taskData[v.ActivityId][v.Type][v.Id] = {}
        taskData[v.ActivityId][v.Type][v.Id].id = v.Id
        taskData[v.ActivityId][v.Type][v.Id].show = v.Show
        taskData[v.ActivityId][v.Type][v.Id].taskValue = v.TaskValue
        taskData[v.ActivityId][v.Type][v.Id].integral = v.Integral
        taskData[v.ActivityId][v.Type][v.Id].jump = v.Jump
        taskData[v.ActivityId][v.Type][v.Id].ActivityId = v.ActivityId
    end
end

function this.UpdateTreasureState()
    local level = this.GetLevel()
    local activityId = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
    if this.rewardData[activityId] then
        for k,v in pairs(this.rewardData[activityId]) do
            if level < v.level  then
                v.state = -2
            end
        end
        local TreasureRewardState = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.TreasureOfSomeBody)
        if TreasureRewardState and TreasureRewardState.mission then
            --state -2 未达成   -1  普通和额外全部领取  0未领取  1激活秘宝，可以再次领取 
            for k,v in ipairs(TreasureRewardState.mission) do 
                if v and level >= v.missionId then
                    this.rewardData[activityId][v.missionId].state = v.state
                end
            end  
        end
    end
end

function this.UpdateTreasureState2()
    local level = this.GetLevel()
    local activityId = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
    if this.rewardData[activityId] then
        for k,v in pairs(this.rewardData[activityId]) do
            if level < k or (level >= k and (not this.GetTreasureState()) and v.type == 1) then
                v.state = -2
            elseif v.state == -2 then
                v.state = 0
            end
        end
    end
end

function this.GetUnlockReward()
    local activityId = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
    local id = ConfigManager.GetConfigData(ConfigName.GlobalActivity, activityId).CanBuyRechargeId[1]
    local reward = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, id).RewardShow
    return reward
end

function this.UpdateTrailWeekTime(msg)
    this.traiWeekTime = msg.weekTime
end

function this.GetTrailWeekTime(msg)
    return this.traiWeekTime
end

function this.GetTimeStartToEnd()
    local info = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.TreasureOfSomeBody)
    if info then
        local startTime= this.GetTimeShow(info.startTime)
        local endtime = this.GetTimeShow(info.endTime)
        return startTime,endtime,info.endTime
    end
end

---时间格式化接口
function this.GetTimeShow(data)
    local year = math.floor(os.date("%Y", data))
    local month = math.floor(os.date("%m", data))
    local day = math.floor(os.date("%d", data))
    local time = month .. GetLanguageStrById(12360) .. day .. GetLanguageStrById(12303)
    return time
end

function this.GetTreasureState()
    return this.hadBuyTreasure
end

function this.GetScore()
    return BagManager.GetItemCountById(this.scoreId)
end

function this.SetSingleRewardState(id,state)
    local activityId = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
    this.rewardData[activityId][id].state = state
end

function this.GetAllRewardData()
    local temp = {}
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
        return temp
    end
    local activityId = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
    if not this.rewardData[activityId] then
        return temp
    end
    for i, v in pairs(this.rewardData[activityId]) do
        if i ~= 0 then
            table.insert(temp,v)
        end
    end
    return temp
end

function this.GetRewardData(lv)
    local activityId = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
    return this.rewardData[activityId][lv]
end

function this.SetLevel(_level)
    this.level = _level
end
function this.SetTreasureBuyStatus(hadBuy)
    this.hadBuyTreasure = (hadBuy == 1)
end
function this.GetLevel()
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
        return 0
    end
    local activityId = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
    local level = this.rewardData[activityId][LengthOfTable(this.rewardData[activityId])-1].level
    if this.level >  level then
        this.level = level
    end
    return this.level
end

function this.GetQinglongTaskData(_curtype)
    local curtype = _curtype + 1
    local temp = TaskManager.GetTypeTaskList(TaskTypeDef.TreasureOfSomeBody)
    local task = {}
    if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
        local activityId = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
        for k,v in ipairs(temp) do
            if taskData[activityId] and taskData[activityId][curtype] and taskData[activityId][curtype][v.missionId] then
                if taskData[activityId][curtype][v.missionId] then
                    taskData[activityId][curtype][v.missionId].progress = v.progress
                    taskData[activityId][curtype][v.missionId].state = v.state
                    table.insert(task, taskData[activityId][curtype][v.missionId])
                end
            end
        end 
    end
    
    return task
end

function this.RefreshRewardRedpoint()
    local state = GrowthManualManager.GetTreasureState()
    local rewardData = GrowthManualManager.GetAllRewardData()
    for i, v in ipairs(rewardData) do
        if v.state == 0 or (v.state == 1 and state) then
            return true
        end
    end
    return false
end

function this.RefreshTeskRedpoint(type)
    local taskData = GrowthManualManager.GetQinglongTaskData(type)
    for i, v in ipairs(taskData) do
        if v.state == 1 then
            return true
        end
    end
    return false
end

function this.GetQinglongSerectTreasureRedPot()
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
        return false
    end
    local state = this.GetTreasureState()
    local activityId = ActivityGiftManager.GetActivityIdByType(ActivityTypeDef.TreasureOfSomeBody)
    for i, v in pairs(this.rewardData[activityId]) do
        if i ~= 0 then
            if v.state == 0 or (v.state == 1 and state) then
                return true
            end
        end
    end
    return false
end

function this.GetSerectTreasureTrailRedPot()
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
        return false
    end
    for i = 1,2 do
        local task = this.GetQinglongTaskData(i)
        for i, v in pairs(task) do
            if v.state == 1 then
                return true
            end
        end
    end
    return false
end

function this.GetSerectTreasureTrailSingleRedPot(_type)
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.TreasureOfSomeBody) then
        return false
    end
    local task = this.GetQinglongTaskData(_type)
    for i, v in pairs(task) do
        if v.state == 1 then
            return true
        end
    end     
    return false
end

return this