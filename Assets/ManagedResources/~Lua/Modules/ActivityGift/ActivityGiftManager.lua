ActivityGiftManager = {};
local this = ActivityGiftManager
local ActivityRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
local GlobalActivity = ConfigManager.GetConfig(ConfigName.GlobalActivity)
local nowStageTime = 0
local giftData = {}
local luckyCatConfig = ConfigManager.GetConfig(ConfigName.LuckyCatConfig)
local chargeConfig = ConfigManager.GetConfig(ConfigName.RechargeCommodityConfig)
local luxuryConfig = ConfigManager.GetConfig(ConfigName.LuxuryFundConfig)
this.mainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local isFirstTime = true
this.isFirstForSupremeHero = false--剑影仙踪是否每日第一次登陆

function this.Initialize()
    --UpdateBeat:Add(this.update, this)
    this.sevenDayOpen = false
    this.onlineOpen = false
    this.chapterOpen = false
    ----新数据
    --在线礼包数据
    this.onlineData = {}
    this.onlineDataTime = {}
    this.onlineGetRewardState = {}
    this.haveOnlineTime = 0
    this.onlineTime = 0  --已经在线时长
    this.currentTimeIndex = 0--当前可领取阶段
    this.cuOnLineTimestamp = 0--当前在线奖励时间戳  从什么时候开始计时
    --七日礼包数据
    this.sevenDayData = {}
    this.sevenDayGetRewardState = {}
    this.sevenDayTime = 0
    this.canRewardDay = 0
    --章节礼包数据
    this.chapterGiftData = {}
    this.chapterGetRewardState = {}
    this.isOpenWeekCard = false--今天是否打开过周卡
    --扭蛋
    this.boxPoolId = 0
    this.boxPoolRewardList = {}--被抽过的奖
    this.autoResetCount = 0--自动重置次数
    this.manualResetCount = 0--手动重置次数
    this.lotteryId = 0--卡池ID
    this.boxPoolConfig = {}

    Game.GlobalEvent:AddEvent(GameEvent.Player.OnLevelChange, function()
        CheckRedPointStatus(RedPointType.Expert_UpLv)
    end)
end

-- 开始在线计时
function this.StartOnlineUpdate()
    -- 开始定时刷新
    if not this._CountDownTimer then
        this._CountDownTimer = Timer.New(this.TimeCountDown, 1, -1, true)
        this._CountDownTimer:Start()
    end
end
function this.TimeCountDown()
    if not NetManager.IsConnect() then
        return
    end
    this.haveOnlineTime = this.haveOnlineTime - 1
    this.onlineTime = this.onlineTime+1
    if this.haveOnlineTime <= 0 and this.currentTimeIndex < #this.onlineDataTime - 1 then

        this.currentTimeIndex = this.currentTimeIndex + 1
        Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnlineState, this.haveOnlineTime, this.onlineData,this.onlineTime)
        this.haveOnlineTime = this.onlineDataTime[this.currentTimeIndex + 1].Values[1][1] * 60 - this.onlineDataTime[this.currentTimeIndex].Values[1][1] * 60
        CheckRedPointStatus(RedPointType.CourtesyDress_Online)
        --CheckRedPointStatus(RedPointType.SecretTer)
        Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnRefreshRedShow)
    else

        Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnlineState, this.haveOnlineTime, this.onlineData,this.onlineTime)
    end
end
function this.InitActivityData()
    for i, v in ConfigPairs(ActivityRewardConfig) do
        --获取在线礼包数据
        if v.ActivityId == ActivityTypeDef.OnlineGift then
            table.insert(this.onlineData, v)
            table.insert(this.onlineDataTime, v)
        end
        --获取七日礼包数据
        if v.ActivityId == ActivityTypeDef.EightDayGift then
            table.insert(this.sevenDayData, v)
        end
        --获取章节礼包数据
        if v.ActivityId == ActivityTypeDef.ChapterAward then
            table.insert(this.chapterGiftData, v)
        end
    end
end

function this.GetActivityRewardRequest(type, index)
    --local rewardId = 0
    --向服务器发送领取在线奖励请求
    NetManager.GetActivityRewardRequest(index, type, function(_drop)
        UIManager.OpenPanel(UIName.RewardItemPopup, _drop, 1)
        if type == ActivityTypeDef.OnlineGift then
            this.onlineGetRewardState[index] = 1
            CheckRedPointStatus(RedPointType.CourtesyDress_Online)
            table.sort(this.onlineData, function(a, b)
                    return a.Id < b.Id
            end)
            Game.GlobalEvent:DispatchEvent(GameEvent.Activity.GetRewardRefresh, this.onlineData)
        elseif type == ActivityTypeDef.EightDayGift then
            this.sevenDayGetRewardState[index] = 1
            CheckRedPointStatus(RedPointType.CourtesyDress_SevenDay)
            table.sort(this.sevenDayData, function(a, b)
                if this.sevenDayGetRewardState[a.Id] == this.sevenDayGetRewardState[b.Id] then
                    return a.Id < b.Id
                else
                    return this.sevenDayGetRewardState[a.Id] < this.sevenDayGetRewardState[b.Id]
                end
            end)
            Game.GlobalEvent:DispatchEvent(GameEvent.Activity.GetRewardRefresh, this.sevenDayData)
        elseif type == ActivityTypeDef.ChapterAward then
            this.chapterGetRewardState[index] = 1
            CheckRedPointStatus(RedPointType.CourtesyDress_Chapter)
            table.sort(this.chapterGiftData, function(a, b)
                if this.chapterGetRewardState[a.Id] == this.chapterGetRewardState[b.Id] then
                    return a.Id < b.Id
                else
                    return this.chapterGetRewardState[a.Id] < this.chapterGetRewardState[b.Id]
                end
            end)
            Game.GlobalEvent:DispatchEvent(GameEvent.Activity.GetRewardRefresh, this.chapterGiftData)
        end
        --CheckRedPointStatus(RedPointType.SecretTer)
        Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnRefreshRedShow)
    end)
end

-- 获取服务器活动领取进度数据
function this.InitActivityServerData(msg, isUpdate)
    --[[
        msg.activityInfo = {
            [1] = {
                mission = {
                    missionId--任务ID
                    progress--任务进度
                    state--任务状态，0：未领奖，1：已领奖 -1：领取花费奖励
                }
                activityId--活动id
                value--活动记录值
                startTime--任务开始时间
                endTime--活动结束时间
                reallyOpen--0:假开启 1：真开启
            }
        }
    ]]

    if not isUpdate then
        this.mission = {}
    end
    for i, v in ipairs(msg.activityInfo) do
        this.mission[v.activityId] = v 
        for n, m in ipairs(v.mission) do
            if v.activityId == ActivityTypeDef.OnlineGift then
                this.onlineOpen = true
                this.onlineGetRewardState[m.missionId] = m.state
                this.haveOnlineTime = m.progress
                this.onlineTime = m.progress
                this.cuOnLineTimestamp = GetTimeStamp() -  m.progress
                --this.StartOnlineUpdate()
            elseif v.activityId == ActivityTypeDef.EightDayGift then
                this.sevenDayOpen = true
                this.sevenDayGetRewardState[n] = m.state
                this.canRewardDay = m.progress
            elseif v.activityId == ActivityTypeDef.ChapterAward then
                this.chapterOpen = true
                this.chapterGetRewardState[m.missionId] = m.state
            end
        end
        if v.activityId == ActivityTypeDef.EightDayGift then
            this.sevenDayTime = v.endTime - GetTimeStamp()
            this.dayTime = GetTimeStamp() - v.startTime
        end
        for m, n in ConfigPairs(luckyCatConfig) do
            if v.activityId == n.ActivityId then
                LuckyCatManager.isOpenLuckyCat = true
                LuckyCatManager.GetRewardProgress(v.mission, v.activityId, v.value)
            end
        end
        this.CheckActiveIsOpen(v)
    end
    TreasureOfSomebodyManagerV2.SetTreasureLocalData()
    this.OnlineStartCountDown()
    FindFairyManager.SetActivityData()

    RecruitManager.InitPreData()
end

--倒计时逻辑处理
function this.OnlineStartCountDown()
    nowStageTime = 0
    for i, v in ipairs(this.onlineData) do
        if v.Values[1][1] >= this.haveOnlineTime / 60 then
            nowStageTime = v.Values[1][1] * 60
            break
        end
        if this.haveOnlineTime / 60 <= this.onlineData[1].Values[1][1] then
            nowStageTime = this.onlineData[1].Values[1][1] * 60
        end
    end
    for i, v in pairs(this.onlineData) do
        if this.haveOnlineTime / 60 >= v.Values[1][1] then
            this.currentTimeIndex = v.Sort
        end
    end
    this.haveOnlineTime = nowStageTime - this.haveOnlineTime
end

--检测七日礼包红点
function this.CheckSevenDayRed()
    local sevenDayRed = this.CheckRedFunc(RedPointType.CourtesyDress_SevenDay)
    return sevenDayRed
end

--检测在线礼包红点
function this.CheckOnlineRed()
    local onlineRed = this.CheckRedFunc(RedPointType.CourtesyDress_Online)
    return onlineRed
end

--检测章节礼包红点
function this.CheckChapterRed()
    local chapterRed = this.CheckRedFunc(RedPointType.CourtesyDress_Chapter)
    return chapterRed
end

function this.CheckEightRedPoint()
    local curDay = math.ceil((CalculateSecondsNowTo_N_OClock(24) + GetTimeStamp() - PlayerManager.userCreateTime)/86400)
    if curDay > 8 then
        curDay = 8
    end
    local isActivityOpen = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.EightDayGift)
    if isActivityOpen then
        local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.EightDayGift)
        for i = 1, #activityInfo.mission do
            local isCanGet = activityInfo.mission[i].state--是否可领取
            if isCanGet == 0 then
                if curDay >= i then
                    return true
                end
            end
        end
    end
    return false
end

function this.CheckEightRedPoint_2()
    local isActivityOpen = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SignInDays)
    if not isActivityOpen then
        return false
    end
    local rewardData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SignInDays)
    local curDay = math.ceil((CalculateSecondsNowTo_N_OClock(24) +  GetTimeStamp() - rewardData.startTime)/86400)
    if isActivityOpen then
        local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SignInDays)
        for i = 1, #activityInfo.mission do
            local isCanGet = activityInfo.mission[i].state--是否可领取
            if isCanGet == 0 then
                if curDay == i then
                    return true
                end
            end
        end
    end
    return false
end


--- 记录神秘军火商按钮点击红点
function this.GetRedState()
    if PlayerManager.uid==nil then
        return
    end

    return PlayerPrefs.GetInt(PlayerManager.uid .. "MunitionsMerchant") == 0
end

function this.SetRedState(value)
    if PlayerManager.uid==nil then
        return
    end
    
    PlayerPrefs.SetInt(PlayerManager.uid .. "MunitionsMerchant", value)
end

--监测云梦祈福等活动是否开启  并请求数据
function this.CheckActiveIsOpen(data)
    local globalActivityData = GlobalActivity[data.activityId]
    if globalActivityData then
        if globalActivityData.Type == ActivityTypeDef.Pray then
            --云梦活动开启 请求数据
            NetManager.InitPrayDataRequest()
        end
    end
end

--通过活动类型获取活动信息 返回的是一个列表 同一类型可能会有多个活动
function this.GetActivityTypeInfoList(type)
    local globalActConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.GlobalActivity, "Type", type)
    local missionData = {}
    table.walk(globalActConfigs, function(actConfigInfo)
        if this.mission[actConfigInfo.Id] then
            table.insert(missionData, this.mission[actConfigInfo.Id])
        end
    end)
    return missionData
end

--通过活动类型获取活动信息
function this.GetActivityTypeInfo(type)
    local globalActConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.GlobalActivity, "Type", type)
    local missionData = nil
    table.walk(globalActConfigs, function(actConfigInfo)
        if this.mission~=nil and this.mission[actConfigInfo.Id] then
            missionData = this.mission[actConfigInfo.Id]
        end
    end)
    return missionData
end

function this.GetActivityTypeInfo2(type)
    local globalActConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.GlobalActivity, "Type", type)
    local config = {}
    table.walk(globalActConfigs, function(actConfigInfo)
        if this.mission[actConfigInfo.Id] then
            config = actConfigInfo
        end
    end)
    return config
end

function this.GetActivityIdByType(type)
    local globalActConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.GlobalActivity, "Type", type)
    local id = 0
    local missionData = nil
    table.walk(globalActConfigs, function(actConfigInfo)
        if this.mission[actConfigInfo.Id] then
            id = actConfigInfo.Id
        end
    end)
    return id
end

function this.GetActivityIdByZq(type)
    local missionDataZq = nil
    if this.mission and this.mission[type] then
        missionDataZq = this.mission[type]
    end
    return missionDataZq
end

function this.GetActivityValueInfo(type, Id)
    if this.mission[type] then
        return this.mission[type].value
    end
end
function this.GetActivityInfo(type, Id)
    if this.mission[type] then
        for _, missInfo in pairs(this.mission[type].mission) do
            if missInfo.missionId == Id then
                return missInfo
            end
        end
    else
        return nil,0
    end
end

function this.TryGetActivityInfoByType(type)
    for id , v in pairs(this.mission) do
        if id == type then
            return v
        end
    end
    return nil
end

function this.GetActivityInfoByType(type)
    if this.mission[type] then
        return this.mission[type]
    end
end
function this.SetActivityInfo(type, Id, state)
    for _, missInfo in pairs(this.mission[type].mission) do
        if missInfo.missionId == Id then
            missInfo.state = state
            break
        end
    end
end

function this.GetActivityOpenStatus(type)
    if this.mission[type] then
        return this.mission[type].reallyOpen == 1
    else
        return false
    end
end
function this.SetActivityOpenStatus(type)
    if this.mission[type] then
        this.mission[type].reallyOpen = 1
    else
    end
end

-- 红点检测监听方法
function this.CheckRedFunc(redType)
    if redType == RedPointType.CourtesyDress_SevenDay then
        if this.mission[ActivityTypeDef.EightDayGift] then
            local number = 0
            for i, v in pairs(this.sevenDayGetRewardState) do
                if v == 1 then
                    number = number + 1
                end
            end
            local curDay =  math.ceil((CalculateSecondsNowTo_N_OClock(24) + GetTimeStamp() - PlayerManager.userCreateTime)/86400)
            if number < curDay then
                return true
            else
                return false
            end
        else
            return false
        end
    elseif redType == RedPointType.CourtesyDress_Chapter then
        local isShowRed = false
        for i = 1, table.nums(this.chapterGetRewardState) do
            for j, v in pairs(this.chapterGiftData) do
                if i == v.Sort then
                    if FightPointPassManager.GetFightStateById(v.Values[1][1]) == FIGHT_POINT_STATE.PASS and this.chapterGetRewardState[v.Id] == 0 then
                        isShowRed = true
                        return isShowRed
                    end
                end
            end
        end
        return isShowRed
    elseif redType == RedPointType.CourtesyDress_Online then
        local number = 0
        for i, v in pairs(this.onlineGetRewardState) do
            if v == 1 then
                number = number + 1
            end
        end

        --当活动未开或奖励全部领取完毕
        if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.Online_Reward)==false then
            return false
        else--当活动开启或奖励未领取完毕
           local timeNum = GetTimeStamp() - this.cuOnLineTimestamp
            local currentTimeIndex = 0
            for i = 1, #this.onlineData do
                if this.onlineGetRewardState[this.onlineData[i].Id] == 0 then
                    if (math.floor(timeNum)) >= (this.onlineData[i].Values[1][1]*60)  then
                        currentTimeIndex = this.onlineData[i].Sort
                    end
                end
            end
            
            if number < currentTimeIndex then --当已领取数小于未领取数
                return true
            else
                return false
            end
        end
    end
end

function this.RefreshActivityData(respond)
    if respond.closeActivityId then
        for i = 1, #respond.closeActivityId do
            if this.mission[respond.closeActivityId[i]] then
                this.mission[respond.closeActivityId[i]] = nil
                local activityType = this.GetActivityTypeFromId(respond.closeActivityId[i])
                if activityType == ActivityTypeDef.SevenDayCarnival then
                    Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnCloseSevenDayGift)
                    SevenDayCarnivalManager.SetSevenDayScore(0)
                    TaskManager.ResetTaskData(TaskTypeDef.SevenDayCarnival)
                elseif activityType == ActivityTypeDef.TreasureOfSomeBody then
                    TreasureOfSomebodyManagerV2.ResetActivityData()
                    TaskManager.ResetTaskData(TaskTypeDef.TreasureOfSomeBody)
                elseif activityType == ActivityTypeDef.LuckyCat then
                    LuckyCatManager.isOpenLuckyCat = false
                end
                Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityOpenOrClose, {
                    type = activityType,
                    status = 0 --关闭
                })
                if ActivityTypePanel[activityType] then
                    local openStatus = UIManager.IsOpen(ActivityTypePanel[activityType])
                    if openStatus then
                        UIManager.ClosePanel(ActivityTypePanel[activityType])
                    end
                end
            end
        end
    end
    --newOpen
    if respond.activityInfo then
        for i = 1, #respond.activityInfo do
            this.mission[respond.activityInfo[i].activityId] = respond.activityInfo[i]
            local activityType = this.GetActivityTypeFromId(respond.activityInfo[i].activityId)
            if activityType == ActivityTypeDef.LuckyCat then --招财猫
                LuckyCatManager.isOpenLuckyCat = true
                LuckyCatManager.GetRewardProgress(respond.activityInfo[i].mission, respond.activityInfo[i].activityId, respond.activityInfo[i].value)
            elseif activityType == ActivityTypeDef.TreasureOfSomeBody then --孙龙的宝藏
                TreasureOfSomebodyManagerV2.SetCurrentLevel(0)
                TreasureOfSomebodyManagerV2.SetTreasureLocalData()
                --CheckRedPointStatus(RedPointType.TreasureOfSl)
            end
            this.CheckActiveIsOpen(respond.activityInfo[i])
            Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityOpenOrClose, {
                type = this.GetActivityTypeFromId(respond.activityInfo[i].activityId),
                status = 1 --开启
            })
        end
    end
    this.InitActivityServerData(respond, true)
    this.RefreshActivityRedPoint()
end

function this.GetActivityTypeFromId(activityId)
    local globalActConfig = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity, "Id", activityId)
    return globalActConfig.Type
end

function this.IsActivityTypeOpen(type)
    local globalActConfigs = ConfigManager.GetAllConfigsDataByKey(ConfigName.GlobalActivity, "Type", type)
    local activityId = nil
    table.walk(globalActConfigs, function(actConfigInfo)
        if this.mission and this.mission[actConfigInfo.Id] then
            activityId = actConfigInfo.Id
        end
    end)

    return activityId
end

function this.IsActivityTypeOpenByFrontEnd(type)
    local globalActConfig = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity, "Type", type)
    local activityId = nil
    if globalActConfig then
        activityId = globalActConfig.Id
    end
    return activityId
end

-------------------------------
--五点凌晨刷新
function this.FiveAMRefreshActivityProgress(msg)
    for i = 1, #msg.activityInfo do
        if not this.mission[msg.activityInfo[i].activityId] then
            Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityOpenOrClose, {
                type = this.GetActivityTypeFromId(msg.activityInfo[i].activityId),
                status = 1 --开启
            })
        end
        this.mission[msg.activityInfo[i].activityId] = msg.activityInfo[i]
    end

    --重新赋值活动
    for i, v in ipairs(msg.activityInfo) do
        for n, m in ipairs(v.mission) do
            if v.activityId == ActivityTypeDef.OnlineGift then
                this.onlineOpen = true
                this.onlineGetRewardState[m.missionId] = m.state
                this.haveOnlineTime = m.progress
                this.onlineTime = m.progress
                this.cuOnLineTimestamp = GetTimeStamp() - m.progress
                --this.StartOnlineUpdate()
            elseif v.activityId == ActivityTypeDef.EightDayGift then
                this.sevenDayOpen = true
                this.sevenDayGetRewardState[n] = m.state
                this.canRewardDay = m.progress
            elseif v.activityId == ActivityTypeDef.ChapterAward then
                this.chapterOpen = true
                this.chapterGetRewardState[m.missionId] = m.state
            end
        end
    end

    Game.GlobalEvent:DispatchEvent(GameEvent.Activity.GetRewardRefresh)
    this.RefreshActivityRedPoint()
end

--刷新某个活动的数据进度
function this.RefreshActivityProgressData(msg)
    if this.mission and this.mission[msg.activityInfo.activityId] then
        this.mission[msg.activityInfo.activityId].value = msg.activityInfo.value
        for i = 1, #msg.activityInfo.mission do
            for _, missionInfo in pairs(this.mission[msg.activityInfo.activityId].mission) do
                if missionInfo.missionId == msg.activityInfo.mission[i].missionId then
                    missionInfo.state = msg.activityInfo.mission[i].state
                    missionInfo.progress = msg.activityInfo.mission[i].progress
                end
            end
        end
        this.RefreshActivityRedPoint()
        Game.GlobalEvent:DispatchEvent(GameEvent.Activity.OnActivityProgressStateChange)
        --断线重连时 在线奖励活动 数据刷新
        this.CutUpLineUpdateOnLineData(msg)
    end
end

function this.RefreshActivityRedPoint()
    Game.GlobalEvent:DispatchEvent(GameEvent.MissionDaily.OnMissionDailyChanged)
    CheckRedPointStatus(RedPointType.FirstRecharge)
    CheckRedPointStatus(RedPointType.ContinuityRecharge)
    CheckRedPointStatus(RedPointType.SevenDayCarnival)
    CheckRedPointStatus(RedPointType.EightTheLogin)
    CheckRedPointStatus(RedPointType.EightTheLogin_2)

    --限时活动
    CheckRedPointStatus(RedPointType.Expert_AdventureExper)
    CheckRedPointStatus(RedPointType.Expert_AreaExper)
    CheckRedPointStatus(RedPointType.Expert_UpStarExper)
    CheckRedPointStatus(RedPointType.Expert_EquipExper)
    CheckRedPointStatus(RedPointType.Expert_GoldExper)
    CheckRedPointStatus(RedPointType.Expert_FightExper)
    CheckRedPointStatus(RedPointType.Expert_EnergyExper)
    CheckRedPointStatus(RedPointType.Expert_Talisman)
    CheckRedPointStatus(RedPointType.Expert_SoulPrint)
    CheckRedPointStatus(RedPointType.Expert_AccumulativeRecharge)
    CheckRedPointStatus(RedPointType.CourtesyDress_SevenDay)
    CheckRedPointStatus(RedPointType.LuckyCat_GetReward)
    CheckRedPointStatus(RedPointType.Expert_LuckyTurn)
    CheckRedPointStatus(RedPointType.Expert_FindTreasure)
    CheckRedPointStatus(RedPointType.Expert_Recruit)
    CheckRedPointStatus(RedPointType.Expert_SecretBox)
    CheckRedPointStatus(RedPointType.Expert_Heresy)
    --战力排行
    CheckRedPointStatus(RedPointType.WarPowerSort_Sort)
    --东海寻仙
    CheckRedPointStatus(RedPointType.FindFairy_OneView)
    CheckRedPointStatus(RedPointType.FindFairy_ThreeView)
    CheckRedPointStatus(RedPointType.FindFairy_FourView)
end

function this.GetContinuityRechargeRedPoint()
    local redPoint = false
    if this.IsActivityTypeOpen(ActivityTypeDef.ContinuityRecharge) then
        local continuityRechargeList = this.GetActivityTypeInfo(ActivityTypeDef.ContinuityRecharge)
        for i = 1, #continuityRechargeList.mission do
            local rechargeInfo = continuityRechargeList.mission[i]
            redPoint = redPoint or (rechargeInfo.progress == 1 and rechargeInfo.state == 0)
        end
    end
    return redPoint
end

function this.GetGrowthRechargeExist()
    if this.IsGetAllGrowthReward() or this.IsActivityTypeOpen(ActivityTypeDef.GrowthReward) == nil then
        return false
    end
    return true
end

function this.IsGetAllGrowthReward()
    local isGetAll = true
    if this.IsActivityTypeOpen(ActivityTypeDef.GrowthReward) then
        local activityInfo = this.GetActivityTypeInfo(ActivityTypeDef.GrowthReward)
        for i = 1, #activityInfo.mission do
            isGetAll = isGetAll and activityInfo.mission[i].state == 1
        end
    end
    return isGetAll
end
--检测限时活动红点
function this.ExpterActivityIsShowRedPoint(activeIndex)
    local activeType = 0
    --注意 红点枚举id %100  就是按钮顺序
    activeType = NumExChange[math.floor(activeIndex % 100)]

    local expertRewardTabs = this.GetActivityTypeInfo(activeType)
    if expertRewardTabs then
        for i = 1, #expertRewardTabs.mission do
            while true
            do
                local conFigData = ConfigManager.TryGetConfigData(ConfigName.ActivityRewardConfig, expertRewardTabs.mission[i].missionId)
                if not conFigData then --加老号活动红点保护 无数据的继续
                    break
                end
                local value = 0
                --限时累计活动特殊数值读取处理
                if activeType == ActivityTypeDef.AccumulativeRechargeExper then
                    value = conFigData.Values[1][1]
                else
                    value = conFigData.Values[2][1]
                end
                if expertRewardTabs.mission[i].state == 0 then
                    if activeType == ActivityTypeDef.UpStarExper or activeType == ActivityTypeDef.Talisman
                            or activeType == ActivityTypeDef.SoulPrint or activeType == ActivityTypeDef.EquipExper
                            or activeType == ActivityTypeDef.FindTreasureExper then
                        --进阶因为每个都不一样 特殊判断
                        if expertRewardTabs.mission[i].progress >= value then
                            return true
                        end
                    elseif activeType == ActivityTypeDef.UpLvAct then
                        if expertRewardTabs.value >= value and expertRewardTabs.mission[i].progress >= 0 then
                            return true
                        end
                    elseif activeType == ActivityTypeDef.AccumulativeRechargeExper then
                        if expertRewardTabs.value/100 >= value then
                            return true
                        end
                    else
                        if expertRewardTabs.value >= value then
                            return true
                        end
                    end
                end
                break
            end
        end
    end
    return false
end
--检测升级限时礼包活动红点
function this.ExperyUpLvActivityIsShowRedPoint()
   local activeData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.UpLvAct)
    if activeData and activeData.mission then
        for i = 1, #activeData.mission do
            local curConfigData = ConfigManager.TryGetConfigData(ConfigName.ActivityRewardConfig,activeData.mission[i].missionId)
            if curConfigData and activeData.mission[i].state == 0 and activeData.value >= curConfigData.Values[2][1]  then
                return true
            end
        end
    end
    return false
end
--检测周卡活动红点
function this.WeedCardActivityIsShowRedPoint()
    local weekCardData = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.WeekCard, 12)
    if weekCardData then
        if weekCardData.buyTimes <= 0 and PatFaceManager.isFirstLog == 0 and this.isOpenWeekCard == false then
            return true
        end
    end

    return false
end
--检测战力排行活动红点
function this.WarPowerSortActivityIsShowRedPoint()
    local expertRewardTabs = this.GetActivityTypeInfo(ActivityTypeDef.WarPowerReach)
    if expertRewardTabs then
        for i = 1, #expertRewardTabs.mission do
            local conFigData = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig, expertRewardTabs.mission[i].missionId)
            local value = conFigData.Values[1][1]
            if expertRewardTabs.mission[i].state == 0 then
                if expertRewardTabs.value >= value then
                    return true
                end
            end
        end
    end
    return false
end
--限时活动里是否有活动开启 > 0  说明有开启的活动
function this.GetExpertActiveisOpen()
    --所有达人
    for i, v in pairs(NumExChange) do
        local curActiveData = ActivityGiftManager.GetActivityTypeInfo(v)
        if curActiveData then
            if curActiveData.endTime - GetTimeStamp() > 0 then
                return i
            end
        end
    end
    local LimitExchange = this.GetActivityTypeInfo(ActivityTypeDef.LimitExchange)
    if LimitExchange then
        if LimitExchange.endTime - GetTimeStamp() > 0 then
            return ActivityTypeDef.LimitExchange
        end
    end

    local weekCardData = OperatingManager.GetGiftGoodsInfo(GoodsTypeDef.WeekCard, 12)
    if weekCardData then
        if weekCardData.endTime - GetTimeStamp() > 0 then
            return ExperType.WeekCard
        end
    end
    local patFaceAllData = nil--{ConfigManager.GetConfigData(ConfigName.LoginPosterConfig,1)}--PatFaceManager.GetPatFaceAllDataTabs()
    if RecruitManager.isTenRecruit == 0 then
        patFaceAllData = { ConfigManager.GetConfigData(ConfigName.LoginPosterConfig, 1) }
    end
    if patFaceAllData and #patFaceAllData > 0 then
        return ExperType.PatFace
    end
    --异妖直购
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.LoginPosterConfig)) do
        if v.Type == 2 then
            --异妖直购特殊处理
            if v.OpenRules[1] == 1 then
                if PlayerManager.level >= v.OpenRules[2] and PlayerManager.level <= v.CloseRules[2] then
                    local conFigData = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, v.ShopId)
                    local shopItemData = OperatingManager.GetGiftGoodsInfo(conFigData.Type, v.ShopId)
                    if shopItemData then
                        return ExperType.DiffMonster
                    end
                end
            end
        end
    end
    --幸运探宝
    --local curActiveData = not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LuckyTurnTable_One)
    --if curActiveData then
    --    return 6
    --end
    --福星高照
    local curActiveData = not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LuckyCat)
    if curActiveData then
        return ExperType.LuckyCat
    end
    --  七日
    local curActiveData = not not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.EightDayGift)
    if curActiveData then
        return ExperType.SevenDay
    end
    --星级成长礼
    if OperatingManager.IsHeroGiftActive() then
        return ExperType.StarGrowGift
    end
    return 0
end
--判断七日，在线，章节是否全部领取完了
function this.ActivityIsHaveGetFinally(state)
    local isGetAllReward = true
    for i, v in pairs(state) do
        if v == 0 then
            isGetAllReward = false
        end
    end
    return isGetAllReward
end

-- 获取所有开启的显示活动ID
function this.GetExpertActiveisAllOpenIds()
    local activityIds = {}
    for i, v in pairs(NumExChange) do
        local curActiveData = ActivityGiftManager.GetActivityTypeInfo(v)
        if curActiveData then
            if curActiveData.endTime - GetTimeStamp() > 0 then
                table.insert(activityIds,curActiveData.activityId)
            end
        end
    end
    local LimitExchange = this.GetActivityTypeInfo(ActivityTypeDef.LimitExchange)
    if LimitExchange then
        if LimitExchange.endTime - GetTimeStamp() > 0 then
            table.insert(activityIds,LimitExchange.activityId)
        end
    end
    local patFaceAllData = nil
    if RecruitManager.isTenRecruit == 0 then
        patFaceAllData = { ConfigManager.GetConfigData(ConfigName.LoginPosterConfig, 1) }
    end
    if patFaceAllData and #patFaceAllData > 0 then
        table.insert(activityIds,ActivityTypeDef.PatFace)
    end
    --幸运探宝
    local luckyTurnTable_One = 0
    luckyTurnTable_One = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LuckyTurnTable_One)
    local upper_Two = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LuckyTurnTable_Two)
    if luckyTurnTable_One then
        if luckyTurnTable_One > 0 then
            table.insert(activityIds, luckyTurnTable_One)
        end
    end

    if upper_Two then
        if upper_Two > 0 then
            table.insert(activityIds, upper_Two)
        end
    end

    --福星高照
    local luckyCat = 0
    luckyCat =  ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.LuckyCat)
    if luckyCat then
        if luckyCat > 0 then
            table.insert(activityIds, luckyCat)
        end
    end
    --  七日
    local sevenDay = 0
    sevenDay =  ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.EightDayGift)
    if sevenDay then
        if sevenDay > 0 then
            table.insert(activityIds, sevenDay)
        end
    end
    return activityIds
end
--断线重连时 在线奖励活动 数据刷新
function this.CutUpLineUpdateOnLineData(msg)
    if msg.activityInfo.activityId == ActivityTypeDef.OnlineGift then
        for i = 1, #msg.activityInfo.mission do
            this.onlineOpen = true
            this.onlineGetRewardState[ msg.activityInfo.mission[i].missionId] =  msg.activityInfo.mission[i].state
            this.haveOnlineTime = msg.activityInfo.mission[i].progress
            this.onlineTime = msg.activityInfo.mission[i].progress
            this.cuOnLineTimestamp = GetTimeStamp() - msg.activityInfo.mission[i].progress
        end
    end
end

---关卡通关豪礼相关---
--根据当前关数 获取最近下一关卡橙色角色
function this.GetNextHeroInfo()
    local allData = {}
    local heroData = {}
    
    -- local startIndex=5001
    -- local mainLevelEndId=ConfigManager.TryGetConfigDataByKey(ConfigName.MainLevelConfig,"NextLevel",-1).Id--最高关卡
    -- local endIndex=this.GetConfigForValues(ConfigName.ActivityRewardConfig,mainLevelEndId).Id

    --> 修改获取方式
    local adapterData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", 3)
    table.sort(adapterData, function(a, b)
        return a.Id < b.Id
    end)

    local startIndex = adapterData[1].Id
    local endIndex = adapterData[#adapterData].Id

    --活动表处于开始结束索引之间的全部数据
    for i = startIndex, endIndex do
        local reward = ConfigManager.TryGetConfigData(ConfigName.ActivityRewardConfig,i)
        if reward then
            table.insert(allData, reward)
        end
    end

    --输出ActivityRewardConfig里下一关的索引
    local index
    for i = 1, #allData do
        if ConfigManager.GetConfigData(ConfigName.MainLevelConfig,FightPointPassManager.curOpenFight).SortId-1 < ConfigManager.GetConfigData(ConfigName.MainLevelConfig,allData[i].Values[1][1]).SortId then
            index= this.GetConfigForValues(ConfigName.ActivityRewardConfig,allData[i].Values[1][1]).Id
            break
        end
    end

    --剩余数据
    local residueData = {}
    for i = index, endIndex do
        local reward = ConfigManager.TryGetConfigData(ConfigName.ActivityRewardConfig,i)
        if reward then
            table.insert(residueData, reward)
        end
    end

    --剩余数据中将立绘数据存入
    for i = 1, #residueData do
        local itemData = ConfigManager.GetConfigData(ConfigName.ItemConfig,residueData[i].Reward[1][1])
        if itemData.ItemType == 1 and (itemData.Quantity == 5 or itemData.Quantity == 4)then --and allData[i].Reward[1][2]==1
            table.insert(heroData,residueData[i])
        end
    end
    
    if #heroData > 0 then --如果有数据
        return heroData[1].Reward[1][1], heroData[1].Values[1][1] --返回目标立绘id 关卡id
    else
        return #heroData ,#heroData--如果没数据 返回0
    end
end

--根据双重key的value锁定id value为2维数组（目前没有这种接口）
function this.GetConfigForValues(configName,pointId)
    local data = {}
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(configName)) do
        if configInfo.ActivityId == 3 and configInfo.Values[1][1] == pointId then
            data = configInfo
            break
        end
    end
    return data
end
---------------------
--- 根据活动ID获取表格中相同活动ID第一项的数据
function this.GetActivityDataById(id)
    for k, v in ConfigPairs(ActivityRewardConfig) do
        if v and v.ActivityId == id then
            return v
        end
    end
end


---剑影仙踪相关---
--获取剑影仙踪任务数据
function this.GetTaskData()
    local taskList = {}
    local taskValue = 0

    local data = this.GetActivityTypeInfo(ActivityTypeDef.SupremeHero)

    if not data then
        return 0, taskList
    end

    table.sort(data.mission,function(a,b)
        return a.missionId < b.missionId
    end)
    for i = 1, #data.mission do
        table.insert(taskList,i, data.mission[i].state)
        if data.mission[i].state >= 1 then
            taskValue = taskValue + 1
        end
    end

    return taskValue,taskList
end

--剑影仙踪红点检测   差一个通关完毕 符合要求的红点检测 点击领取红点未检测
function this.CheckSupremeHeroRedPoint()
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SupremeHero) then
        return
    end
    local isOpen
    local num, list = this.GetTaskData()

    local complete = 0 --任务是否完成
    local receive = 0 --任务是否领取
    for i = 1, #list do
        if list[i] > 0 then
            complete = complete + 1
        end
        if list[i] == 2 then
            receive = receive + 1
        end
    end

    if complete < 3 then--任务未完成
        isOpen = PatFaceManager.isFirstLog == 0 and not this.isFirstForSupremeHero
    else
        isOpen = receive < 3
    end

    return isOpen
end

--获取活动结束时间
function this.GetTaskEndTime(activityType)
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(activityType)

    local endTime = 0
    if activityInfo then
        endTime = activityInfo.endTime
    end
    return endTime
end

--获取活动开始时间
function this.GetTaskStartTime(activityType)
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(activityType)

    local startTime = 0
    if activityInfo then
        startTime = activityInfo.startTime
    end
    return startTime
end

--获取活动剩余时间
function this.GetTaskRemainTime(activityType)
    local remainTime = 0
        remainTime = this.GetTaskEndTime(activityType)- this.GetTaskEndTime(activityType)
    return remainTime
end

function this.GetRewardState()
    local taskValue,missionData = this.GetTaskData()
    local doneNum = 0
    for i = 1, 3 do
        if missionData[i] == 2 then
            doneNum = doneNum + 1
        end
    end
    local state = doneNum == 3 and 3 or 2
    return state
end

----------------
-- 获取下一个每日奖励的时间
function this.GetNextOnlineRewardData()
    for _, data in ipairs(this.onlineData) do
        local state = this.onlineGetRewardState[data.Id]
        if state ~= 1 then  -- 如果不是已完成状态则返回数据
            if state == 0 then
                local curOnlineTime = GetTimeStamp() - ActivityGiftManager.cuOnLineTimestamp
                local needTime = data.Values[1][1]*60
                if curOnlineTime < needTime then
                    state = -1
                end
            end
            return data, state
        end
    end
end

--达人获取id
function this.GetOpenExpertIdByActivityType(activityType)
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(activityType)
    if activityInfo then
        return activityInfo.activityId
    end
    return 0
end

--------------------------------------------
--主动刷新 置本地数据
function this.RefreshAcitvityData(acitvityIds,fun)
    NetManager.RefreshAcitvityData(acitvityIds,function (msg)
        for i = 1, #msg.activityInfo do
            if this.mission[msg.activityInfo[i].activityId] then
                this.mission[msg.activityInfo[i].activityId].value = msg.activityInfo[i].value
                for j = 1, #msg.activityInfo[i].mission do
                    for _, missionInfo in pairs(this.mission[msg.activityInfo[i].activityId].mission) do
                        if missionInfo.missionId == msg.activityInfo[i].mission[j].missionId then
                            missionInfo.state = msg.activityInfo[i].mission[j].state
                            missionInfo.progress = msg.activityInfo[i].mission[j].progress
                        end
                    end
                end
            end
        end
        if fun then fun() end
        CheckRedPointStatus(RedPointType.Expert_UpLv)
    end)
end

--获取活动已开启的时间
function this.GetCurrentDayNumber(type)
    local DayActInfo = ActivityGiftManager.GetActivityTypeInfo(type)
    local startTime = DayActInfo.startTime
    local needDayNumber = math.ceil((GetTimeStamp() - startTime) / 86400)
    return needDayNumber
end

--章节检测距离下次领奖还有几关
function this.GetRewardNeedLevel()
    for i = 1, table.nums(this.chapterGetRewardState) do
        for j, v in pairs(this.chapterGiftData) do
            if i == v.Sort then
                if FightPointPassManager.GetFightStateById(v.Values[1][1]) ~= FIGHT_POINT_STATE.PASS and this.chapterGetRewardState[v.Id] == 0 then
                   return this.mainLevelConfig[v.Values[1][1]].SortId - this.mainLevelConfig[FightPointPassManager.curOpenFight].SortId + 1
                end
            end
        end
    end
    return 0
end
--开服福利排序
local OpenSeverWelfareSortTable = {
    [0] = 1,
    [1] = 0,
}
function this.OpenSeverWelfareRewardTabsSort(missions)
    table.sort(missions,function(a,b)
        if a.state == b.state then
            return a.missionId < b.missionId
        else
            return OpenSeverWelfareSortTable[a.state] > OpenSeverWelfareSortTable[b.state]
        end
    end)
end

-- 玩家是否有资格开启
function this.IsQualifiled(type)
    -- 相同类型活动解锁类型相同，所以只判断第一个
    local data = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity,"Type",type)
    if not data then return false end

    -- 当前玩家等级
    local qualifiled = false
    local playerLv = PlayerManager.level
    local openRule = data.OpenRules
    if openRule[1] == 1 then  -- 关卡开启
        qualifiled = FightPointPassManager.IsFightPointPass(openRule[2])
    elseif openRule[1] == 2 then-- 等级开启
        qualifiled = playerLv >= openRule[2]
    elseif openRule[1] == 3 then-- 工坊等级开启
        qualifiled = WorkShopManager.WorkShopData.lv >= openRule[2]
    elseif openRule[1] == 4 then--vip等级开启
        qualifiled = VipManager.GetVipLevel() >= openRule[2]
    end
    return qualifiled
end

function this.GetTimeStartToEnd(type)
    local info = ActivityGiftManager.GetActivityTypeInfo(type)
    local startTime = this.GetTimeShow(info.startTime)
    local endtime = this.GetTimeShow(info.endTime)
    return startTime.."~"..endtime
end

---时间格式化接口
function this.GetTimeShow(data)
    local year = math.floor(os.date("%Y", data))
    local month = math.floor(os.date("%m", data))
    local day = math.floor(os.date("%d", data))
    local time = year .. "-" .. month .. "-" .. day
    return time
end

--扭蛋
function this.InitBoxPoolInfo(func)
    NetManager.BoxPoolListRequest(function (msg)
        local activityId = this.IsActivityTypeOpen(ActivityTypeDef.BoxPool)
        for i, v in ipairs(msg.boxPoolInfos) do
            local config = ConfigManager.GetConfigDataByKey(ConfigName.BoxPoolConfig, "Id", v.id)
            if config.ActivityId == activityId then
                this.boxPoolId = v.id
                this.lotteryId = v.lotteryId
                this.boxPoolRewardList = v.rewardList
                this.autoResetCount = v.autoResetCount
                this.manualResetCount = v.manualResetCount
                -- this.boxPoolConfig = config
            end
        end
        if func then
            func()
        end
    end)
end

--抽卡/重置
function this.ResetBoxPoolInfo(isReset, func)
    NetManager.BoxPoolOperateRequest(this.boxPoolId, isReset, function (msg)
        this.boxPoolId = msg.info.id
        this.lotteryId = msg.info.lotteryId
        this.boxPoolRewardList = msg.info.rewardList
        this.autoResetCount = msg.info.autoResetCount
        this.manualResetCount = msg.info.manualResetCount
        if func then
            func(msg.drop)
        end
    end)
end

--扭蛋是否抽过
function this.BoxPoolIsDraw(id)
    for i = 1, #this.boxPoolRewardList do
        if id == this.boxPoolRewardList[i] then
            return true
        end
    end
    return false
end

--免费抽取
function this.BoxPoolFreeTime()
    local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
    local freeTimesId = lotterySetting[ActivityTypeDef.BoxPool].FreeTimes
    local freeTime = 0
    if freeTimesId > 0 then
        freeTime = PrivilegeManager.GetPrivilegeRemainValue(freeTimesId)
        RecruitManager.freeUseTimeList[freeTimesId] = freeTime
        return freeTime and freeTime >= 1
    end
    return false
end

--扭蛋是否可以抽取
function this.BoxPoolCanDraw()
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.BoxPool) then
        return false
    end
    local LotterId = ActivityGiftManager.lotteryId
    if LotterId == 0 then
        return false
    end
    local costDraw = ConfigManager.GetConfigDataByDoubleKey(ConfigName.LotterySetting,"Id",LotterId).CostItem--扭蛋消耗
    return BagManager.GetItemCountById(costDraw[1][1]) >= costDraw[1][2]
end

--终身会员红点
function this.LifeMemberRedPoint()
    return this.RedPointForType(ActivityTypeDef.LifeMemebr, false)
end

--终身会员免费红点
function this.LifeMemberFreeRedPoint()
    return this.RedPointForType(ActivityTypeDef.LifeMemebr, true)
end

--超级终身会员红点
function this.SuperLifeMemberRedPoint()
    return this.RedPointForType(ActivityTypeDef.SuperLifeMemebr, false)
end

--超级终身会员免费红点
function this.SuperLifeMemberFreeRedPoint()
    return this.RedPointForType(ActivityTypeDef.SuperLifeMemebr, true)
end

function this.RedPointForType(type, isfree)
    local state = false
    if ActivityGiftManager.IsQualifiled(type) then
        local data = this.GetActivityTypeInfo(type)
        if data and data.mission then
            if isfree then
                state = data.mission[2].state == 0
            else
                if data.value == 1 then
                    state = data.mission[1].state == 0
                end
            end
        end
    end
    -- LogError(type..":"..tostring(state))
    return state
end

--周末福利红点
function this.WeekendWelfareRedPoint()
    if not ActivityGiftManager.IsQualifiled(ActivityTypeDef.WeekendWelfare) then
        return false
    end
    local config = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
    local data = this.GetActivityTypeInfo(ActivityTypeDef.WeekendWelfare)
    local curWeek = GetSeverWeek()
    if data then
        for i, v in ipairs(data.mission) do
            if config[v.missionId].Values[2][1] == curWeek then
                if v.state == 0 then
                    return true
                end
            end
        end
    end
    return false
end

--周卡红点
function this.WeekCardRedPoint()
    if not ActivityGiftManager.IsQualifiled(ActivityTypeDef.WeekCard) then
        return false
    end
    if PlayerPrefs.GetInt(PlayerManager.uid .. "WeekCardFirstOpen") ~= 1 then
        return true
    end
    local data = this.GetActivityTypeInfo(ActivityTypeDef.WeekCard)
    if data then
        local activityId = data.activityId
        local rewardConfig = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig, "ActivityId", activityId)
        if data.value > 0 then
            local time = math.floor((GetTimeStamp() - data.startTime) / (24 * 3600))
            if time < 1 then time = 1 end
            for i, v in ipairs(data.mission) do
                for index = 1, #rewardConfig do
                    if rewardConfig[index].Id == v.missionId then
                        if v.state == 0 and rewardConfig[index].Values[2][1] <= time then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

--周卡是否结束
function this.WeekIsEndTime()
    local data = this.GetActivityTypeInfo(ActivityTypeDef.WeekCard)
    if data then
        if data.endTime - GetTimeStamp() < 0 then
            return false
        end
        return true
    end
    return false
end

--判断成长基金活动是否开启或结束（16是最后一档活动ActivityId）
function this.GrowthGift()
    local state = false
    local GrowthRewardId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.GrowthReward)
    local singleRewardData
    if GrowthRewardId then--是否开启
        state = true
    end
    if GrowthRewardId == 16 then--是否结束
        singleRewardData = ActivityGiftManager.GetActivityInfo(GrowthRewardId, 5324)
        if not singleRewardData then
            state = false
        else
            if singleRewardData.state == 1 then
                state = false
            end
        end
    end
    return state
end

--判断终身限购礼包是否购买完
function this.LifetimeIsBuyup()
    local state = true
    local canBuyRechargeId = ConfigManager.GetConfigDataByKey(ConfigName.GlobalActivity, "Type", ActivityTypeDef.LifeMemeber).CanBuyRechargeId
    for i = 1, #canBuyRechargeId do
        local config = ConfigManager.GetConfigData(ConfigName.RechargeCommodityConfig, canBuyRechargeId[i])
        local boughtNum = OperatingManager.GetGoodsBuyTime(config.Type, config.Id) or 0
        local isCanBuy = config.Limit - boughtNum > 0
        if state == false then
            state = isCanBuy
        end
    end
    return state
end

--开服热卖红点
function this.OpenSeverShopRedpoint()
    local curActId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.OpenServiceShop)
    if not curActId then
        return false
    end
    local data = GlobalActivity[curActId].CanBuyRechargeId
    for i = 1, #data do
        local data = ConfigManager.GetConfigDataByKey(ConfigName.RechargeCommodityConfig, "Id", data[i])
        local boughtNum = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.DirectPurchaseGift, data.Id) or 0
        if data.Price == 0 and data.Limit - boughtNum > 0 then
            return true
        end
    end
    return false
end

return this