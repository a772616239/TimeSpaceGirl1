CardActivityManager = {}
local this = CardActivityManager
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
function this.Initialize()
    this.wishPool = 0
    this.wishRewardList = {}
    this.lotteryId = {}
    this.changeWishCost = {}
    this.wishTimes = 0--保底次数
    this.wishRewardTimes = 0--心愿奖励次数
    this.freeHaoli = {}
end

--请求心愿数据
function this.InitWish(func)
    if not ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Draw) then
        if func then
            func()
        end
        return
    end
    this.activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Draw)
    NetManager.CardSubjectInitRequest(this.activityId, function (msg)
        this.wishPool = msg.wishId
        this.wishRewardTimes = msg.wishTimes
        this.wishTimes = msg.times
        this.InitWishReward()
        this.InitFreeHaoli()

        CheckRedPointStatus(RedPointType.CardActivity_Collect)
        CheckRedPointStatus(RedPointType.CardActivity_Task)
        CheckRedPointStatus(RedPointType.CardActivity_Draw)
        CheckRedPointStatus(RedPointType.CardActivity_Haoli)
        if func then
            func()
        end
    end)
end

--初始化心愿英雄奖励
function this.InitWishReward()
    this.wishRewardList = {}
    local wishPoolConfig = ConfigManager.GetConfigDataByKey(ConfigName.WishPoolConfig, "ActivityId", this.activityId)
    table.insert(this.wishRewardList, wishPoolConfig.WishReward1)
    table.insert(this.wishRewardList, wishPoolConfig.WishReward2)
    table.insert(this.wishRewardList, wishPoolConfig.WishReward3)
    table.insert(this.wishRewardList, wishPoolConfig.WishReward4)
    table.insert(this.wishRewardList, wishPoolConfig.WishReward5)
    this.lotteryId = wishPoolConfig.LotteryId
    this.changeWishCost = wishPoolConfig.ChangeWishCost
end

--获取当前选中的心愿英雄ID
function this.GetCurHeroConfig()
    return this.wishRewardList[this.wishPool][1]
end

--招募
function this.Recruit(type, func)
    local Id
    if type == 1 then
        Id = this.lotteryId[1]
    elseif type == 2 then
        Id = this.lotteryId[2]
    end
    NetManager.CardSubjectHeroGetActivityRequest(Id, function (msg)
        this.wishTimes = msg.times
        this.wishRewardTimes = msg.wishRewardTimes

        if msg.drop.Hero ~= nil and #msg.drop.Hero > 0 then
            local itemDataList = {}
            local itemDataStarList = {}
            for i = 1, #msg.drop.Hero do
                local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", msg.drop.Hero[i].heroId)
                table.insert(itemDataList, heroData)
                table.insert(itemDataStarList, msg.drop.Hero[i].star)
            end
            UIManager.OpenPanel(UIName.PublicGetHeroPanel, itemDataList, itemDataStarList, function ()
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
                this.InitFreeHaoli()
                CheckRedPointStatus(RedPointType.CardActivity_Haoli)
                CheckRedPointStatus(RedPointType.CardActivity_Collect)
            end)
        else
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
        end

        if func then
            func()
        end
    end)
end

local state = {
    [1] = 0,
    [0] = 1,
    [2] = 2
}
--获取任务
function this.GetTask(activityId, type)
    local allData = {}
    local allListData = ConfigManager.GetAllConfigsDataByKey(ConfigName.ThemeActivityTaskConfig, "ActivityId", activityId)
    local allMissionData = TaskManager.GetTypeTaskList(type)
    if allListData and allMissionData then
        for i = 1,#allListData do
            for j = 1,#allMissionData do
                if allListData[i].Id == allMissionData[j].missionId then
                    local data = {}
                    data.id = allMissionData[j].missionId
                    data.progress = allMissionData[j].progress 
                    data.title = GetLanguageStrById(allListData[i].Show)
                    data.value = allListData[i].TaskValue[2][1]
                    data.state = allMissionData[j].state
                    data.type = allListData[i].Type
                    data.reward = allListData[i].Integral--{allListData[i].Integral[1][1], allListData[i].Integral[1][2]}
                    data.jump = allListData[i].Jump[1]
                    table.insert(allData, data)
                end
            end
        end
    end

    table.sort(allData, function (a, b)
        if a.state == b.state then
            return a.id < b.id
        else
            return state[a.state] < state[b.state]
        end
    end)

    return allData
end

--获取豪礼奖励
function this.GetHaoliReward()
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Haoli)
    local allListData = ConfigManager.GetAllConfigsDataByKey(ConfigName.WishTaskRewardConfig, "ActivityId", activityId)
    return allListData
end

--初始化豪礼免费奖励
function this.InitFreeHaoli()
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Haoli)
    NetManager.CardSubjectHeroLuxuryGetRequest(activityId, function (msg)
        this.wishRewardTimes = msg.times
        this.freeHaoli = msg.heroLuxury
    end)
end

--获取豪礼免费状态
function this.GetHaoliState(id)
    for index, value in ipairs(this.freeHaoli) do
        if value.id == id then
            return value.freeStatus
        end
    end
    return 0
end

--设置豪礼免费状态
function this.SetHaoliState(id)
    for index, value in ipairs(this.freeHaoli) do
        if value.id == id then
            value.freeStatus = 2
        end
    end
end

--招募红点
function this.RecruitRedPoint()
    if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Draw) then
        --单抽
        if this.lotteryId[1] ~= nil then
            local config1 = ConfigManager.GetConfigData(ConfigName.LotterySetting, this.lotteryId[1])
            local myCount = BagManager.GetItemCountById(ItemConfig[config1.CostItem[1][1]].Id)
            if myCount >= config1.CostItem[1][2] then
                return true
            end
        end
        --十抽
        if this.lotteryId[2] ~= nil then
            local config10 = ConfigManager.GetConfigData(ConfigName.LotterySetting, this.lotteryId[2])
            local myCount2 = BagManager.GetItemCountById(ItemConfig[config10.CostItem[1][1]].Id)
            if myCount2 >= config10.CostItem[1][2] then
                return true
            end
        end
    end
    return false
end

--神秘指令红点
function this.TaskRedPoint()
    if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Task) then
        local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Task)
        local alldata = this.GetTask(activityId, TaskTypeDef.CardActivity_Task)
        for index, value in ipairs(alldata) do
            if value.state == 1 then
                return true
            end
        end
    end
    return false
end

--英雄收集红点
function this.CollectRedPoint()
    if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Collect) then
        local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Collect)
        local allData = CardActivityManager.GetTask(activityId, TaskTypeDef.CardActivity_Collect)
        for index, value in ipairs(allData) do
            if value.state == 1 then
                return true
            end
        end
    end
    return false
end

--英雄豪礼红点
function this.HaoliRedPoint()
    if ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.CardActivity_Haoli) then
        for index, value in ipairs(this.freeHaoli) do
            if value.freeStatus == 1 then
                return true
            end
        end
    end
    return false
end

function this.TimeDown(txt, timeDown)
    if txt then
        txt.text = GetLanguageStrById(12321) .. TimeToDHMS(timeDown)
    end
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    this.timer = Timer.New(function()
        if txt then
            txt.text = GetLanguageStrById(12321) .. TimeToDHMS(timeDown)
        end
        if timeDown < 0 then
            this.timer:Stop()
            this.timer = nil
            if  not IsNull(txt) then
                txt.text = ""
            end
        end
        timeDown = timeDown - 1
    end, 1, -1, true)
    this.timer:Start()
end

function this.StopTimeDown()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

return this