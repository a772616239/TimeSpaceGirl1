--[[
 * @ClassName TaskManager
 * @Description 任务管理系统
 * @Date 2019/6/5 10:54
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
TaskManager = {}
local this = TaskManager

local TypeTaskData = {}

local SLrefreshTime = {}
--初始化
function this.Initialize()
    for _, v in pairs(TaskTypeDef) do
        TypeTaskData[v] = {}
    end
end

--missionId = 1;
--progress = 2; //进度
--state = 3; //0:未完成 1：完成未领取 2：已达成（已领取）
--type = 4 ;// 任务类型 1：vip任务 2：每日任务 3: 4:孙龙的宝藏
function this.InitTypeTaskList(_userMissionList)
    for i = 1, #_userMissionList do
        local userMissionList ={}
        userMissionList.missionId = _userMissionList[i].missionId
        userMissionList.progress = _userMissionList[i].progress
        userMissionList.state = _userMissionList[i].state
        userMissionList.type = _userMissionList[i].type
        userMissionList.takeTimes = _userMissionList[i].takeTimes
        userMissionList.heroId = _userMissionList[i].heroId
        if not TypeTaskData[_userMissionList[i].type] then
            TypeTaskData[_userMissionList[i].type] = {}
        end
        table.insert(TypeTaskData[_userMissionList[i].type], userMissionList)
        --this.AddTypeData(_userMissionList[i].type, userMissionList)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.NiuQiChongTianTask)
end

--引导任务数据（服务器返回）
function this.RequestGuideTaskData(_userMissionList)
    for i = 1, #_userMissionList do
        if _userMissionList[i].type == TaskTypeDef.GuideTask then
            local userMissionList ={}
            userMissionList.missionId = _userMissionList[i].missionId
            userMissionList.progress = _userMissionList[i].progress
            userMissionList.state = _userMissionList[i].state
            userMissionList.type = _userMissionList[i].type
            userMissionList.takeTimes = _userMissionList[i].takeTimes
            userMissionList.heroId = _userMissionList[i].heroId
            if not TypeTaskData[_userMissionList[i].type] then
                TypeTaskData[_userMissionList[i].type] = {} 
            end
            table.insert(TypeTaskData[_userMissionList[i].type], userMissionList)
        end
    end
end

--function this.AddTypeData(type, data)
--    if TypeTaskData[type] then
--        table.insert(TypeTaskData[type], data)
--    end
--end

--任务数据重置
function this.ResetTaskData(type)
    TypeTaskData[type] = {}
end

--初始化拉去并设定本地type类型的任务数据
function this.SetTypeTaskList(type, data)
    TypeTaskData[type] = {}
    for i = 1, #data do
        local t = {}
        t.missionId = data[i].missionId
        t.progress = data[i].progress
        t.state = data[i].state
        t.type = data[i].type
        t.takeTimes = data[i].takeTimes
        t.heroId = data[i].heroId
        table.insert(TypeTaskData[type], t)

    end
    this.ChangeVipRedPointState()
end

local achievementConfig = ConfigManager.GetConfig(ConfigName.AchievementConfig)
local curShowAllAchievementData = {}
local curShowAllOkAchievementData = {}
--获取本地存储的type任务类型数据 前端展示用 红点检测用  飘弹窗提示用
function this.GetCurShowAllAchievementData(type)
    curShowAllAchievementData = {}
    curShowAllOkAchievementData = {}
    if TypeTaskData[type] then
        for i = 1, #TypeTaskData[type] do
            local curTaskData = TypeTaskData[type][i]
            if TypeTaskData[type][i].state == 2 then
                curShowAllOkAchievementData[curTaskData.missionId] = curTaskData
            end
        end
        for i = 1, #TypeTaskData[type] do
            local curTaskData = TypeTaskData[type][i]
            local curTaskConFigData = achievementConfig[curTaskData.missionId]
            if ActTimeCtrlManager.SingleFuncState(curTaskConFigData.RefSysId) then
                if curTaskConFigData.PreId == -1 or curShowAllOkAchievementData[curTaskConFigData.PreId]  then
                    if curTaskData.state ~= 2 then
                        curShowAllAchievementData[curTaskData.missionId] = curTaskData
                    end
                end
            end
        end
        return curShowAllAchievementData
    else
    end
end
--获取混乱之治任务
function this.GetChaosTaskData(type)
    -- curShowAllAchievementData = {}
    if TypeTaskData[type] then
        -- for i = 1, #TypeTaskData[type] do
        --     curShowAllAchievementData[i] = TypeTaskData[type][i]
        -- end
        return TypeTaskData[type]
    end
    return nil
end

--获取本地存储的type任务类型数据
function this.GetTypeTaskList(type)
    if TypeTaskData[type] then
        return TypeTaskData[type]
    else

    end
end

--获取对应type类型任务和对应Id的数据信息
function this.GetTypeTaskInfo(type, Id)
    for _, taskInfo in pairs(TypeTaskData[type]) do
        if taskInfo.missionId == Id then
            return taskInfo
        end
    end
    return nil
end

--(客户端领取任务奖励调用)设定对应type类型任务和对应Id的状态信息state,不存在progress的设定情况
function this.SetTypeTaskState(type, Id, state, progress, takeTimes, heroId)
    for _, taskInfo in pairs(TypeTaskData[type]) do
        if taskInfo.missionId == Id then
            taskInfo.state = state
            if progress then
                taskInfo.progress = progress
            end
            if takeTimes then
                taskInfo.takeTimes = takeTimes
            end
            taskInfo.heroId = heroId
        end
    end
    this.ChangeVipRedPointState()
    Game.GlobalEvent:DispatchEvent(GameEvent.MissionDaily.OnMissionDailyChanged)
    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.NiuQiChongTianTask)
end

function this.SetMissionIdState(type, Id, state)
    for _, taskInfo in pairs(TypeTaskData[type]) do
        if taskInfo.missionId == Id then
            taskInfo.state = state
        end
    end
end

--(后台推送刷新调用)
function this.SetTypeTaskInfo(type, Id, state, progress, takeTimes,heroId)
    local index = table.keyvalueindexof(TypeTaskData[type], "missionId", Id)
    if not index then
        --整体清空重载数据
        table.insert(TypeTaskData[type], {
            missionId = Id,
            progress = progress,
            state = state,
            type = type,
            takeTimes = takeTimes,
            heroId = heroId,
        })
    else
        --部分数据刷新
        for _, taskInfo in pairs(TypeTaskData[type]) do
            if taskInfo.missionId == Id then
                -- 发送副本成就完成事件
                if type == TaskTypeDef.EliteCarbonTask then
                    if taskInfo.state == VipTaskStatusDef.NotFinished and state == VipTaskStatusDef.CanReceive then
                        Game.GlobalEvent:DispatchEvent(GameEvent.EliteAchieve.OnAchieveDone, Id)
                    end
                end
                taskInfo.state = state
                taskInfo.progress = progress
                taskInfo.takeTimes = takeTimes
                --taskInfo.heroId = heroId
                --taskInfo.heroId = {}
                --for i = 1, #heroId do
                --    table.insert(taskInfo.heroId,heroId[i])
                --end
            end
        end
    end
    if type == TaskTypeDef.SevenDayCarnival then
        SevenDayCarnivalManager.CheckScoreChange(Id, progress)
    elseif type == TaskTypeDef.DayTask or type == TaskTypeDef.Achievement then--推送时检测 是否达成 飘弹窗提示
        this.SetAllShowTipMission(type, Id, state)
    elseif type == TaskTypeDef.BattlePass then
        this.SetAllShowTipMission(type, Id, state)
    -- elseif type == 15 then
    --     this.SetAllShowTipMission(type, Id, state)
    elseif type == TaskTypeDef.Train then
        Game.GlobalEvent:DispatchEvent(GameEvent.RedPoint.TrainTask)
    end
    --this.ChangeVipRedPointState()
end

--刷新本地的任务数据
function this.RefreshTypeTaskInfo(taskInfoList)
    for i = 1, #taskInfoList do
        local taskInfo = taskInfoList[i]
        this.SetTypeTaskInfo(taskInfo.type, taskInfo.missionId, taskInfo.state, taskInfo.progress, taskInfo.takeTimes,taskInfo.heroId)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.MissionDaily.OnMissionDailyChanged)
    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.NiuQiChongTianTask)
    this.ChangeVipRedPointState()
end

-- 返回已经完成的成就数量和总数量
function this.GetAchiveNum(mapId)
    local totalNum = 0
    local doneNum = 0
    local taskInfoList = ConfigManager.GetAllConfigsDataByKey(ConfigName.AccomplishmentConfig, "MapId", mapId)
    for _, data in ipairs(taskInfoList) do
        local taskData = TaskManager.GetTypeTaskInfo(TaskTypeDef.EliteCarbonTask, data.id)
        if taskData then
            totalNum = totalNum + 1
            if taskData.state > 0 then
                doneNum = doneNum + 1
            end
        end
    end
    return doneNum, totalNum
end

-- 检测红点状态
function this.ChangeVipRedPointState()
    CheckRedPointStatus(RedPointType.VipPrivilege)
    CheckRedPointStatus(RedPointType.DailyTask)
    CheckRedPointStatus(RedPointType.TreasureOfSl)
    CheckRedPointStatus(RedPointType.SevenDayCarnival)
    CheckRedPointStatus(RedPointType.Achievement_Main)
    --CheckRedPointStatus(RedPointType.Support_Gift)
    --CheckRedPointStatus(RedPointType.Achievement_One)
    --CheckRedPointStatus(RedPointType.Achievement_Two)
    --CheckRedPointStatus(RedPointType.Achievement_Three)
    --CheckRedPointStatus(RedPointType.Achievement_Four)
    --CheckRedPointStatus(RedPointType.Achievement_Five)
    --CheckRedPointStatus(RedPointType.HeroExplore)

    -- AircraftCarrierManager.RedPointCheckStatus_CV()
    CheckRedPointStatus(RedPointType.Support)
    CheckRedPointStatus(RedPointType.Adjutant)
    CheckRedPointStatus(RedPointType.BattlePassMission)
    CheckRedPointStatus(RedPointType.Chaos_Task)
    CheckRedPointStatus(RedPointType.Chaos_Tab_Chanllege)
end

--引导任务红点状态
function this.CheckGuideTaskRedPoint()
    local curGuideTaskData = TaskManager.GetCurrentGuideTask(TaskTypeDef.GuideTask)
    if curGuideTaskData and curGuideTaskData.state == 1 then
        return true
    end

    return false
end

function this.GetVipRedPointState()
    local redPointStatus = false
    local taskListInfo = this.GetTypeTaskList(TaskTypeDef.VipTask)
    local taskFinishNum = 0

    for i = 1, #taskListInfo do
        if taskListInfo[i].state == VipTaskStatusDef.CanReceive then
            redPointStatus = redPointStatus or true
        elseif taskListInfo[i].state == VipTaskStatusDef.Received then
            taskFinishNum = taskFinishNum + 1
        end
    end
    redPointStatus = redPointStatus or taskFinishNum >= #taskListInfo
    if taskFinishNum==0 and #taskListInfo==0 then --特殊处理
        redPointStatus=false
    end
    if VipManager.GetTakeLevelBoxStatus() == GiftReceivedStatus.NotReceive then
        redPointStatus = redPointStatus or true
    end
    if VipManager.GetTakeDailyBoxStatus() == -1 then
        redPointStatus = redPointStatus or true
    end
    return redPointStatus
end

--获取当前主线任务数据
function this.GetMianTaskCurActiveTaskData()
    local allMainTask = TypeTaskData[TaskTypeDef.MainTask]
    if not allMainTask then
        return
    end
    table.sort(allMainTask, function(a, b)
        return a.missionId < b.missionId
    end)
    for _, taskInfo in pairs(TypeTaskData[TaskTypeDef.MainTask]) do
        if taskInfo.state == 0 or taskInfo.state == 1 then
            return taskInfo
        end
    end
    return nil
end
function this.ResetTreasureTaskInfo(taskList)
    local refreshTypeList = {}
    --type,tasks
    for i = 1, #taskList do
        local taskInfoList = TypeTaskData[TaskTypeDef.TreasureOfSomeBody]
        for k = #taskInfoList, 1, -1 do
            local taskConfig = ConfigManager.GetConfigData(ConfigName.TreasureSunLongTaskConfig, taskInfoList[k].missionId)
            if taskConfig.Type == taskList[i].type then
                table.remove(TypeTaskData[TaskTypeDef.TreasureOfSomeBody], k)
            end
        end
        for j = 1, #taskList[i].tasks do
            table.insert(TypeTaskData[TaskTypeDef.TreasureOfSomeBody], taskList[i].tasks[j])
        end
        table.insert(refreshTypeList,taskList[i].type)
        this.SetSLrefreshTime2(taskList[i].type,taskList[i].refreshTime)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.MissionDaily.OnMissionListRestChanged,refreshTypeList)
end

--迷宫寻宝前端刷新任务自行赋值
function this.RefreshFindTreasureData(msg)
    TypeTaskData[TaskTypeDef.FindTreasure] = {}
        --整体清空重载数据
    for i = 1, #msg.infos do
        table.insert(TypeTaskData[TaskTypeDef.FindTreasure], {
            missionId = msg.infos[i].missionId,
            progress = msg.infos[i].progress,
            state = msg.infos[i].state,
            type = msg.infos[i].type,
            takeTimes = msg.infos[i].takeTimes,
            heroId = msg.infos[i].heroId,
        })
    end
end
--迷宫寻宝前端派遣自行赋值
function this.RefreshFindTreasureHerosData(missionId,heroIds,progress)
    for _, taskInfo in pairs(TypeTaskData[TaskTypeDef.FindTreasure]) do
        if taskInfo.missionId == missionId then
            --for i = 1, #heroIds do
            --    taskInfo.heroId:append(heroIds[i])
            --end
            taskInfo.heroId = heroIds
            taskInfo.progress = GetTimeStamp() + progress
        end
    end
end
--迷宫寻宝前端派遣自行赋值
function this.RefreshFindTreasureStatrData(missionId,state)
    for _, taskInfo in pairs(TypeTaskData[TaskTypeDef.FindTreasure]) do
        if taskInfo.missionId == missionId then
            taskInfo.state = state
            if state == 2 then--已领取
                taskInfo.heroId = {}
            end
        end
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.FindTreasure.RefreshFindTreasureRedPot)
    CheckRedPointStatus(RedPointType.SecretTer_FindTreasure)
end
--刷新下可领取状态
function this.SetFindTreasureDataState()
    for _, taskInfo in pairs(TypeTaskData[TaskTypeDef.FindTreasure]) do
        if taskInfo.state == 0 and #taskInfo.heroId > 0  then--未完成 已派遣
            local timeDown  = taskInfo.progress - GetTimeStamp()
            if timeDown <= 0 then
                taskInfo.state = 1
            end
        end
    end
end
--孙龙宝藏时间数据
function this.SetSLrefreshTime(msg)
    SLrefreshTime = {dayTime = msg.dayTime,weekTime = msg.weekTime}--,monthTime = msg.monthTime}  月时间就是活动结束时间
end
function this.SetSLrefreshTime2(type,refreshTime)
    if type == 1 then
        SLrefreshTime.dayTime = refreshTime
    elseif type == 2 then
        SLrefreshTime.weekTime = refreshTime
    end
end
function this.GetSLrefreshTime()
    if LengthOfTable(SLrefreshTime) <=0 then
        return nil
    end
    local actInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.TreasureOfSomeBody)
    if not actInfo then
        return nil
    end
    SLrefreshTime.monthTime = actInfo.endTime
   return SLrefreshTime
end

--检测成就红点
function this.GetAchievementState()
    local AllData = TaskManager.GetCurShowAllAchievementData(TaskTypeDef.Achievement)
    for i, v in pairs(AllData) do
        if v  then
            if v.state == 1 then
                return true
            end
        end
    end
    return false
end

local allShowTipMission = {}
function this.SetAllShowTipMission(_type, _Id, _state)
    if _state == 1 then--刚刚完成
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.Achiecement) and ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MISSIONDAILY) then
            if _type == TaskTypeDef.DayTask then
                local curConfig = ConfigManager.TryGetConfigData(ConfigName.DailyTasksConfig,_Id)
                if curConfig and curConfig.SortId ~= 2 then       
                    table.insert(allShowTipMission,{type = _type,Id = _Id,state = _state})
                    this.RefreshShowDailyMissionTipPanel()
                end
            end
            if _type == TaskTypeDef.Achievement then
                table.insert(allShowTipMission,{type = _type,Id = _Id,state = _state})
                this.RefreshShowDailyMissionTipPanel()
            end
        end
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.BattlePass) then
            if _type == TaskTypeDef.BattlePass then
                table.insert(allShowTipMission,{type = _type,Id = _Id,state = _state})
                this.RefreshShowDailyMissionTipPanel()
            end
        end
        -- if ActivityGiftManager.GrowthGift() then
        --     if _type == 15 then
        --         table.insert(allShowTipMission,{type = _type,Id = _Id,state = _state})
        --         this.RefreshShowDailyMissionTipPanel()
        --     end
        -- end
    end
end

function this.RefreshShowDailyMissionTipPanel()
    if #allShowTipMission > 0 and not UIManager.IsOpen(UIName.BattlePanel)
            and not UIManager.IsOpen(UIName.MissionDailyTipPanel)
            and not UIManager.IsOpen(UIName.FormationPanelV2)
            and not UIManager.IsOpen(UIName.RewardItemPopup)
            and not UIManager.IsOpen(UIName.TenRecruitPanel)
            and not UIManager.IsOpen(UIName.PublicGetHeroPanel)
            and not UIManager.IsOpen(UIName.SingleRecruitPanel)
            then
        this.ShowDailyAndAchievementTipPanel(allShowTipMission[1])
    end
end

--推送时检测 是否达成 飘弹窗提示
function this.ShowDailyAndAchievementTipPanel(data)
    if AppConst.isOpenGM then
        return
    end
    if data.type == TaskTypeDef.DayTask then
        local curConfig = ConfigManager.TryGetConfigData(ConfigName.DailyTasksConfig,data.Id)
        if curConfig and curConfig.SortId ~= 2 then
            MissionDailyTipPanel.ShowInfo(1, string.format(GetLanguageStrById(curConfig.Desc), curConfig.Values[2][1]))
            this.DelAllShowTipMissionOne()
        end
    elseif data.type == TaskTypeDef.Achievement then
        local curConfig = ConfigManager.TryGetConfigData(ConfigName.AchievementConfig,data.Id)
        if curConfig then
            MissionDailyTipPanel.ShowInfo(2, curConfig.ContentsShow)
            this.DelAllShowTipMissionOne()
        end
    elseif data.type == TaskTypeDef.BattlePass then
        local curConfig = ConfigManager.TryGetConfigData(ConfigName.BattlePassTask,data.Id)
        if curConfig then
            MissionDailyTipPanel.ShowInfo(3, curConfig.Desc)
            this.DelAllShowTipMissionOne()
        end
    -- elseif data.type == 15 then
    --     local curConfig = ConfigManager.TryGetConfigData(ConfigName.ActivityRewardConfig, data.Id)
    --     if curConfig then
    --         MissionDailyTipPanel.ShowInfo(4, string.format(GetLanguageStrById(50366), curConfig.Reward[1][2]))
    --         this.DelAllShowTipMissionOne()
    --     end
    end
end
function this.GetAllShowTipMission()
    return allShowTipMission
end
function this.DelAllShowTipMissionOne()
    table.remove(allShowTipMission,1)
end
--获取当前正在进行的指引任务
function this.GetCurrentGuideTask(type)
    local guideTaskList = this.GetTypeTaskList(type)
    -- table.sort(guideTaskList, function(a, b)
    --     return a.missionId < b.missionId
    -- end)
    local taskData
    for i = 1, #guideTaskList do
        if guideTaskList[i].state ~= 2 then
            taskData = guideTaskList[i]
            break
        end
    end
    return taskData
end
function this.OnTriggerGuideTaskGuide(type)
    local taskData = this.GetCurrentGuideTask(type)
    if taskData then
        local guideTaskConfig = ConfigManager.GetConfigData(ConfigName.GuideTaskConfig,taskData.missionId) 
        if guideTaskConfig.RefSysId == 0 then
        else
        end
        --任务没有完成
        if taskData.state == 0 then
            if guideTaskConfig.RefSysId == 0 or ActTimeCtrlManager.CheckFuncIsActive(guideTaskConfig.RefSysId) then
                Game.GlobalEvent:DispatchEvent(GameEvent.GuideTask.OnGuideTaskChange, guideTaskConfig.GuideId)
            end
        end
    end
end
function this.ResetEndlessMissionState()
    for k,v in ipairs(TypeTaskData[TaskTypeDef.wujinfuben]) do
        v.progress = 0
        v.state = 0
    end
end

--手札红点
function this.BattlePasssTask()
    local isRedpoint = false
    local taskData = TaskManager.GetTypeTaskList(TaskTypeDef.BattlePass)
    for index, value in ipairs(taskData) do
        if value.state == 1 then
            isRedpoint = true
            return isRedpoint
        end
    end
    return isRedpoint
end
return this