NiuQiChongTianManager = {}
local this = NiuQiChongTianManager
this.rewardData = {}
this.configData = {}
local curScore = 0
local itemId = 0

function this.Initialize()
    this.InitAllRewardData()
    Game.GlobalEvent:AddEvent(GameEvent.Mission.NiuQiChongTianTask,this.UpdateStatus)
end

--服务器发来的活动进度条数据
function this.GetActData()
    return ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.NiuQi)
end

--牛气值
function this.GetScore()
    local ActData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.NiuQi)
    if not (ActData and ActData.activityId) then return end
    if #this.configData == 0 then
        local config = ConfigManager.GetAllConfigsDataByKey(ConfigName.ActivityRewardConfig,"ActivityId",ActData.activityId)
        for i = 1, #config do
            local data = {}
            itemId = config[i].Values[1][1]
            data.missionId = config[i].Id
            data.reward = config[i].Reward
            data.value = config[i].Values
            data.activityId = ActData.activityId
            data.state = 0
            table.insert(this.configData,data)
        end
    end
    curScore = BagManager.GetTotalItemNum(itemId)
    for i = 1, #this.configData do
        if curScore >= this.configData[i].value[2][1] then
            for key, value in pairs(ActData.mission) do
                if value.missionId and value.missionId == this.configData[i].missionId then
                    if value.state == 0 then
                        this.configData[i].state = 1--可领的
                    else
                        this.configData[i].state = 2--领完的
                    end
                end
            end
        else
            this.configData[i].state = 0--不可领的
        end
    end
    return curScore
end

--所有的任务信息数据
function this.InitAllRewardData()
    local ArroGantFly = ConfigManager.GetConfig(ConfigName.ArroGantFly)
    for k,v in ConfigPairs(ArroGantFly) do
        table.insert(this.rewardData,this.CreatSingleData(v))
    end
end

function this.UpdateStatus()
    local temp = TaskManager.GetTypeTaskList(TaskTypeDef.NiuQiChongTian)
    for k,v in pairs(this.rewardData) do
        v.state = temp[v.id].state
    end
    CheckRedPointStatus(RedPointType.NiuQiChongTian_1)
    CheckRedPointStatus(RedPointType.NiuQiChongTian_2)
    CheckRedPointStatus(RedPointType.NiuQiChongTian_3)
end

function this.CreatSingleData(sData)
    local data = {}
    data.id = sData.Id
    data.Text = sData.Text
    data.Reward = sData.Reward
    data.Sort = sData.Sort
    data.Type = sData.Type
    data.ActivityId = sData.ActivityId
    data.state = 0
    data.SortI = sData.SortI
    return data
end


--需要显示的任务数据
function this.GetNeedRewardData(sort)
    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.NiuQi)
    local needData = {}
    for i = 1, 2 do
        local tempdata = {}
        for k, v in pairs(this.rewardData) do
            if v.Sort == sort and v.Type == i and id == v.ActivityId then
                --if #tempdata < 1 then
                    --table.insert(tempdata,v)
                --else
                    table.insert(tempdata,v)
                    --break
                --end
            end
        end
        -- if #tempdata < 2 then
        --     for k = #this.rewardData, 1 , -1 do
        --         local v = this.rewardData[k]
        --         local data = nil
        --         if #tempdata == 0 then
        --             if v.Sort == sort and v.Type == i then
        --                 data = v
        --             end
        --         else
        --             for j = 1, #tempdata do
        --                 if tempdata[j].id ~= v.id and v.Sort == sort and v.Type == i then
        --                     data = v
        --                     break
        --                 end
        --             end
        --         end
        --         if data then
        --             table.insert(tempdata,data)
        --             if #tempdata >= 2 then
        --                 break
        --             end
        --         end
        --     end
        -- end

        for j = 1,#tempdata do
            table.insert(needData,tempdata[j])
        end
    end
    table.sort(needData,function (a,b)
        return a.id < b.id
    end)
    return needData
end

function this.CheckNiuQiChongTianRedPoint(index)
    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.NiuQi)
    if not id or id < 1 then
        return false
    end
    
    local isShow = false 
    if index == RedPointType.NiuQiChongTian_4 then
        isShow = this.NiuQiCheckRedPoint4()
    else
        local n = 0
        if index == RedPointType.NiuQiChongTian_1 then
            n = 1
        elseif index == RedPointType.NiuQiChongTian_2 then
            n = 2
        elseif index == RedPointType.NiuQiChongTian_3 then
            n = 3
        end
        isShow = this.NiuQiCheckRedPoint1(n)
    end
    return isShow
end

function this.NiuQiCheckRedPoint1(index)
    local id = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.NiuQi)
    for k,v in pairs(this.rewardData) do
        if v.ActivityId == id then
            if v.state == 1 and (not index or v.Sort == index) then
                return true
            end
        end
    end
    return false
end

function this.NiuQiCheckRedPoint4()
    this.GetScore()
    for key, value in pairs(this.configData) do
        if value.state == 1 then
            return true
        end
    end
    return false
end

return this