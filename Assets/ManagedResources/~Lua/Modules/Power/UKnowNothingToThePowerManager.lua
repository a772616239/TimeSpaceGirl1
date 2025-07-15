UKnowNothingToThePowerManager = {}
local this = UKnowNothingToThePowerManager

function this.Initialize()

end

-- 我要变强数据中各项对应当前英雄的各模块类型和等级表中的推荐值字段
local _PowerListForceConfig = {
    [1] = {mType = 7, key = "HeroPower"},
    [2] = {mType = 1, key = "EquipPower"},
    [3] = {mType = 2, key = "DifferDemonsPower"},
    [4] = {mType = 3, key = "RingsPower"},
    [5] = {mType = 4, key = "GiftPower"},
    [6] = {mType = 5, key = "SoulPower"},
    [7] = {mType = 6, key = "TreasurePower"},
}

--- 计算英雄评分数据
local _HeroGrade = {}
function UKnowNothingToThePowerManager.GetHeroGrade(heroDId)
    if not _HeroGrade[heroDId] then
        _HeroGrade[heroDId] = {}
        local tCurScore = 0
        local tMaxScore = 0
        for id, data in ipairs(_PowerListForceConfig) do
            local list = {}
            list.curScore = HeroManager.CalculateSingleModuleProPower(data.mType, heroDId)
           
            list.maxScore = ConfigManager.GetConfigData(ConfigName.PlayerLevelConfig, PlayerManager.level)[data.key]
            _HeroGrade[heroDId][id] = list
            tCurScore = tCurScore + list.curScore
            tMaxScore = tMaxScore + list.maxScore
        end
        _HeroGrade[heroDId].tCurScore = tCurScore
        _HeroGrade[heroDId].tMaxScore = tMaxScore
    end
    return _HeroGrade[heroDId]
end
function UKnowNothingToThePowerManager.ClearHeroGrade()
    _HeroGrade = {}
end



-- 获取英雄变强的数据
function UKnowNothingToThePowerManager.GetHeroPowerList(heroDId)
    if not this.HeroStrongerData then
        this.HeroStrongerData = ConfigManager.GetAllConfigsDataByKey(ConfigName.BeStronger, "Type", 1)
    end

    local list = {}
    for _, data in ipairs(this.HeroStrongerData) do
        -- 功能是否解锁
        local isOpen = not data.FunctionId or data.FunctionId == 0 or ActTimeCtrlManager.SingleFuncState(data.FunctionId)
        -- 如果是魂印，判断该英雄是否可以穿戴魂印
        local isSoulPrint = data.Id ~= 5 or HeroManager.IsHeroHaveSoulPrintFunc(heroDId)
        -- 如果是法宝，判断该英雄是否可以穿戴法宝
        local isTalisman = data.Id ~= 6 or HeroManager.IsHeroHaveTalismanFunc(heroDId)
        --
        if isOpen and isTalisman and isSoulPrint then
            table.insert(list, data)
        end
    end
    table.sort(list, function(a, b)
        return a.Sort < b.Sort
    end)
    return list
end

-- 构建资源获取方式的数据
function this.BuildResGetList()
    this.ResGetParentList = {}
    this.ResGetChildList = {}
    local dataList = ConfigManager.GetAllConfigsDataByKey(ConfigName.BeStronger, "Type", 2)
    local tempList = {}
    for _, data in ipairs(dataList) do
        local itemId = data.ItemId[1]
        -- 父节点数据
        if not tempList[itemId] then
            local DescFirst = string.split(GetLanguageStrById(data.DescFirst), "#")
            tempList[itemId] = {
                Sort = data.Sort,
                ItemId = itemId,
                Title = DescFirst[1],
                Content = DescFirst[2]
            }
            table.insert(this.ResGetParentList, tempList[itemId])
        end
        -- 子节点数据
        local DescSecond = string.split(GetLanguageStrById(data.DescSecond), "#")
        if not this.ResGetChildList[itemId] then
            this.ResGetChildList[itemId] = {}
        end
        table.insert(this.ResGetChildList[itemId], {
            Sort = data.Sort,
            Title = DescSecond[1],
            Content = DescSecond[2],
            Jump = data.Jump
        })
    end

    -- 排序
    table.sort(this.ResGetParentList, function(a, b)
        return a.Sort < b.Sort
    end)
    for _, list in pairs(this.ResGetChildList) do
        table.sort(list, function(a, b)
            return a.Sort < b.Sort
        end)
    end
end
-- 获取资源大类数据
function UKnowNothingToThePowerManager.GetResGetParentList()
    if not this.ResGetParentList then
        this.BuildResGetList()
    end
    return this.ResGetParentList
end
-- 获取资源小类数据
function UKnowNothingToThePowerManager.GetResGetChildList(itemId)
    if not this.ResGetChildList then
        this.BuildResGetList()
    end
    return this.ResGetChildList[itemId]
end

-- 获取推荐数据
function UKnowNothingToThePowerManager.GetRmdList()
    if not this.RmdList then
        this.RmdList = ConfigManager.GetAllConfigsDataByKey(ConfigName.BeStronger, "Type", 3)
    end
    return this.RmdList
end

-- 获取常见问题数据
function UKnowNothingToThePowerManager.GetQAList()
    if not this.QAList then
        this.QAList = ConfigManager.GetAllConfigsDataByKey(ConfigName.BeStronger, "Type", 4)
        this.QADetailList = {}
        for _, data in ipairs(this.QAList) do
            this.QADetailList[data.Id] = {}
            local strList = string.split(GetLanguageStrById(data.DescSecond), "#")
            for i = 1, math.floor(#strList/2) do
                table.insert(this.QADetailList[data.Id], {q = strList[i * 2 - 1], a = strList[2 * i]})
            end
        end
    end
    return this.QAList
end
-- 获取常见问题详细数据
function UKnowNothingToThePowerManager.GetQADetailList(QAId)
    if not this.QADetailList then
        this.GetQAList()
    end
    return this.QADetailList[QAId]
end

-- 触发我要变强任务完成
function UKnowNothingToThePowerManager.CheckTask()
    local taskInfo = ConfigManager.TryGetConfigDataByKey(ConfigName.BeginnerTask, "TaskType", 58)
    if not taskInfo then return end
    local taskData = TaskManager.GetTypeTaskInfo(TaskTypeDef.MainTask, taskInfo.Id)
    if taskData.state == VipTaskStatusDef.NotFinished then
        NetManager.CheckGiveMePowerTask()
    end
end

return this