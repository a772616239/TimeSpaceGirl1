ClimbTowerManager = {}
local this = ClimbTowerManager
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local VirtualBattle = ConfigManager.GetConfig(ConfigName.VirtualBattle)
local VirtualTargetReward = ConfigManager.GetConfig(ConfigName.VirtualTargetReward)

ClimbTowerManager.ClimbTowerType = {
    Normal = 1,
    Advance = 2
}

ClimbTowerManager.RewardType = {
    Normal = 1,
    Vip = 2
}

ClimbTowerManager.ReportId = {
    LowestPower = 1,
    FastTime = 2,
    Mine = 3,
}

ClimbTowerManager.FirstShowNum = 5 --< 首通奖励显示个数
ClimbTowerManager.fightId = 1   --< 关卡id 就是层数
ClimbTowerManager.curFightId = 1   --< 当前执行关卡id 就是层数

ClimbTowerManager.serverReportData = nil    --< 战报服务端数据
ClimbTowerManager.serverRankData = nil      --< 排行数据

ClimbTowerManager.fightId_Advance = 1   --< 关卡id 就是层数 高级
ClimbTowerManager.curFightId_Advance = 1   --< 当前执行关卡id 就是层数 高级

ClimbTowerManager.serverReportData_Advance = nil    --< 战报服务端数据 高级
ClimbTowerManager.serverRankData_Advance = nil      --< 排行数据 高级
ClimbTowerManager.fight_isPVP = false

function this.Initialize()
    this.data = {}
    this.data[ClimbTowerManager.ClimbTowerType.Normal] = {}
    this.data[ClimbTowerManager.ClimbTowerType.Advance] = {}
    this.starArray = {}
    this.virtualEliteBossArray = {} --< 擂主信息

    this.StarLimitConditionArray = {} --< 爬塔商店条件数组 key商品id
    ClimbTowerManager.SetShopStarData()
end

function ClimbTowerManager.UpdateData(_msg, type)
    --type低高模式 count剩余次数 hasBuyCount已经购买过的次数
    if type == ClimbTowerManager.ClimbTowerType.Normal then
        this.fightId = _msg.fightId
    elseif type == ClimbTowerManager.ClimbTowerType.Advance then
        this.fightId_Advance = _msg.fightId
        this.starArray = {}
        if _msg.virtualStarList then
            for i = 1, #_msg.virtualStarList do
                local fightid = _msg.virtualStarList[i].fightId
                this.starArray[fightid] = {}
                if _msg.virtualStarList[i].star and #_msg.virtualStarList[i].star > 0 then
                    for j = 1, #_msg.virtualStarList[i].star do
                        this.starArray[fightid][_msg.virtualStarList[i].star[j]] = _msg.virtualStarList[i].star[j]
                    end
                    
                end
            end
        end
        
        
        this.virtualEliteBossArray = {}
        if _msg.virtualEliteBoss then
            for i = 1, #_msg.virtualEliteBoss do
                this.virtualEliteBossArray[_msg.virtualEliteBoss[i].fightId] = _msg.virtualEliteBoss[i]
            end
        end
        
    end
    
    
    this.SetCount(_msg.virtualBattleCount.type, _msg.virtualBattleCount.count)
    this.SetHasBuyCount(_msg.virtualBattleCount.type, _msg.virtualBattleCount.hasBuyCount)
end

function ClimbTowerManager.UpdateFightIdData(_msg, type)
    
    
    if type == ClimbTowerManager.ClimbTowerType.Normal then
        this.fightId = _msg.fightId
    elseif type == ClimbTowerManager.ClimbTowerType.Advance then
        this.fightId_Advance = _msg.fightId
    end
end

function ClimbTowerManager.SetCount(_type, count)
    this.data[_type].count = count
end
function ClimbTowerManager.GetCount(_type)
    return this.data[_type].count
end
function ClimbTowerManager.SetHasBuyCount(_type, hasBuyCount)
    this.data[_type].hasBuyCount = hasBuyCount
end
function ClimbTowerManager.GetHasBuyCount(_type)
    return this.data[_type].hasBuyCount
end

--> times第几次购买
function ClimbTowerManager.GetBuyCost(_type, times)
    local specialConfig = nil
    if _type == ClimbTowerManager.ClimbTowerType.Normal then
        specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "VirtualChallengeBuyCost")
    elseif _type == ClimbTowerManager.ClimbTowerType.Advance then
        specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "VirtualEliteChallengeBuyCost")
    end
    
    local cost = 0
    local itemid = nil
    local valueArray = string.split(specialConfig.Value, "|")
    if valueArray[times] == nil then
        local a = string.split(valueArray[#valueArray], "#")
        cost = a[2]
        itemid = a[1]
    else
        local a = string.split(valueArray[times], "#")
        cost = a[2]
        itemid = a[1]
    end

    return tonumber(cost), tonumber(itemid)
end

--> 检测是否可买 是否达到今日购买上线
function ClimbTowerManager.CheckCanBuy(_type)
    local hasBuyCount = ClimbTowerManager.GetHasBuyCount(_type)
    local num = ClimbTowerManager.GetBuyTimesUp(_type)
    if hasBuyCount >= num then
        return false
    end
    return true
end

--> 免费次数上限
function ClimbTowerManager.GetFreeTimesUp(_type)
    local specialConfig = nil
    if _type == ClimbTowerManager.ClimbTowerType.Normal then
        specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "VirtualChallengeTimes")
    elseif _type == ClimbTowerManager.ClimbTowerType.Advance then
        specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "VirtualEliteChallengeTimes")
    end
    return tonumber(specialConfig.Value)
end

--> 购买次数上限
function ClimbTowerManager.GetBuyTimesUp(_type)
    local specialConfig = nil
    if _type == ClimbTowerManager.ClimbTowerType.Normal then
        specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "VirtualChallengeBuyTimes")
    elseif _type == ClimbTowerManager.ClimbTowerType.Advance then
        specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "VirtualEliteChallengeBuyTimes")
    end
    return tonumber(specialConfig.Value)
end

function ClimbTowerManager.GetTowerConfigData(type)
    local type = type or ClimbTowerManager.ClimbTowerType.Normal
    local data = {}
    local configDatas
    if type == ClimbTowerManager.ClimbTowerType.Normal then
        configDatas = ConfigManager.GetConfig(ConfigName.VirtualBattle)
    elseif type == ClimbTowerManager.ClimbTowerType.Advance then
        configDatas = ConfigManager.GetConfig(ConfigName.VirtualEliteBattle)
    end
    for key, value in ConfigPairs(configDatas) do
        table.insert(data, value)
    end
    table.sort(data, function(a, b)
        return a["Id"] > b["Id"]
    end)
    return data
end

--> 用于scroll 填充首尾无用信息（因为滚动问题）
function ClimbTowerManager.GetTowerScrollData(type)
    local type = type or ClimbTowerManager.ClimbTowerType.Normal
    local data = {}
    local config = ClimbTowerManager.GetTowerConfigData(type)
    -- table.insert(data, {idx = 1, data = nil})
    -- for i = 1, #config do
    --     table.insert(data, {idx = i + 1, data = config[i]})
    -- end
    -- table.insert(data, {idx = #config + 2, data = nil})

    for i = 1, #config do
        table.insert(data, {idx = i, data = config[i]})
    end

    return data
end

function ClimbTowerManager.GetChallengeConfigNormalData(type)
    local type = type or ClimbTowerManager.ClimbTowerType.Normal
    local data = {}
    local configDatas
    if type == ClimbTowerManager.ClimbTowerType.Normal then
        configDatas = ConfigManager.GetConfig(ConfigName.VirtualTargetReward)
        for k, v in ConfigPairs(configDatas) do
            if v.TargetReward and #v.TargetReward > 0 then
                table.insert(data, v)
            end
        end
    elseif type == ClimbTowerManager.ClimbTowerType.Advance then
        configDatas = ConfigManager.GetConfig(ConfigName.VirtualStarReward)
        for k, v in ConfigPairs(configDatas) do
            if v.StarReward and #v.StarReward > 0 then
                table.insert(data, v)
            end
        end
    end
    
    
    return data
end

function ClimbTowerManager.GetChallengeConfigVipData(type)
    local type = type or ClimbTowerManager.ClimbTowerType.Normal
    local data = {}
    local configDatas
    if type == ClimbTowerManager.ClimbTowerType.Normal then
        configDatas = ConfigManager.GetConfig(ConfigName.VirtualTargetReward)
    elseif type == ClimbTowerManager.ClimbTowerType.Advance then
        configDatas = ConfigManager.GetConfig(ConfigName.VirtualStarReward)
    end
    for k, v in ConfigPairs(configDatas) do
        if v.PurchaseLevelReward and #v.PurchaseLevelReward > 0 then
            table.insert(data, v)
        end
    end
    return data
end

--> 战斗
function ClimbTowerManager.ExecuteFight(_fightId, callBack)
    --> fightInfo
    BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.Climb_Tower, G_VirtualBattle[_fightId].Monster)

    NetManager.FightStartRequest(BATTLE_TYPE.Climb_Tower, _fightId, function(msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg, nil)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.Climb_Tower, callBack)
        end)
    end)
end

--> 战斗
function ClimbTowerManager.ExecuteFightAdvance(_fightId, callBack, isPVP)
    local type = 1  --< 1打电脑 2打擂主
    local isFightPlayer = 0
    if isPVP then
        type = 2
        isFightPlayer = 1
    end
    if type == 1 then
        --> fightInfo
        ClimbTowerManager.curFightId_Advance = _fightId
        BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.Climb_Tower_Advance, G_VirtualEliteBattle[_fightId].Monster)
        ClimbTowerManager.fight_isPVP = false
    else
        --> fightInfo
        --> out set
        ClimbTowerManager.curFightId_Advance = _fightId --< 打擂主 未进prefight界面  直接设置验算fightid
        ClimbTowerManager.fight_isPVP = true
    end

    NetManager.FightStartRequest(BATTLE_TYPE.Climb_Tower_Advance, _fightId, function(msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function () 
            local fightData = BattleManager.GetBattleServerData(msg, isFightPlayer)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.Climb_Tower_Advance, callBack)
        end)
    end, nil, type)
end

--> 扫荡
function ClimbTowerManager.ExecuteSweep(type, _fightId, callBack)
    NetManager.VirtualBattleSweep(type, _fightId, function(msg)
        if callBack then
            callBack(msg)
        end
    end)
end

--> 获取reward 任务信息（后端用任务处理的 所以前端也跟着用任务系统）
function ClimbTowerManager.GetTaskData(_rewardType, type)
    local type = type or ClimbTowerManager.ClimbTowerType.Normal
    local taskList = nil
    if _rewardType == ClimbTowerManager.RewardType.Normal then
        if type == ClimbTowerManager.ClimbTowerType.Normal then
            taskList = TaskManager.GetTypeTaskList(TaskTypeDef.ClimbTowerNormalTask)
        elseif type == ClimbTowerManager.ClimbTowerType.Advance then
            taskList = TaskManager.GetTypeTaskList(TaskTypeDef.ClimbTowerNormalTaskAdvance)
        end
        
    elseif _rewardType == ClimbTowerManager.RewardType.Vip then
        if type == ClimbTowerManager.ClimbTowerType.Normal then
            taskList = TaskManager.GetTypeTaskList(TaskTypeDef.ClimbTowerVipTask)
        elseif type == ClimbTowerManager.ClimbTowerType.Advance then
            taskList = TaskManager.GetTypeTaskList(TaskTypeDef.ClimbTowerVipTaskAdvance)
        end
    end

    local task = {}
    for i = 1, #taskList do
        task[taskList[i].missionId] = taskList[i]
    end

    return task
end

--免费扫荡红点
function ClimbTowerManager.RefreshFreeRedpoint()
    local value = 0
    if ClimbTowerManager.GetCount(ClimbTowerManager.ClimbTowerType.Normal) then
        value = ClimbTowerManager.GetCount(ClimbTowerManager.ClimbTowerType.Normal)
    end
    if value > 0 then
        return true
    end
    return false
end


--刷新神之塔奖励红点
function ClimbTowerManager.RefreshTaskRewardRedpoint()
    local redpoint = false
    local RewardTaskData = ClimbTowerManager.GetTaskData(ClimbTowerManager.RewardType.Normal)
    local configDataNormal = ClimbTowerManager.GetChallengeConfigNormalData()
    for i = 1, #configDataNormal do
        local data = RewardTaskData[configDataNormal[i].Condition]
        if data then
            if data.state == 1 then
                if redpoint == false then
                    redpoint = true
                end
            end
        end
    end

    local isOpen = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.ClimbTowerUnlockAdvanceVip)
    if isOpen then
        local RewardvipTaskData = ClimbTowerManager.GetTaskData(ClimbTowerManager.RewardType.Vip)
        local configDataVip = ClimbTowerManager.GetChallengeConfigVipData()
        for i = 1, #configDataVip do
            local data = RewardvipTaskData[configDataVip[i].Condition]
            if data then
                if data.status == 1 then
                    if redpoint == false then
                        redpoint = true
                    end
                end
            end
        end
    end

    return redpoint
end

--刷新高级神之塔奖励红点
function ClimbTowerManager.RefreshTaskAdvanceRewardRedpoint()
    local RewardTaskData = ClimbTowerManager.GetTaskData(ClimbTowerManager.RewardType.Normal, ClimbTowerManager.ClimbTowerType.Advance)
    local configDataNormal = ClimbTowerManager.GetChallengeConfigNormalData(ClimbTowerManager.ClimbTowerType.Advance)
    for i = 1, #configDataNormal do
        local tData = RewardTaskData[configDataNormal[i].Star]
        if tData then
            if tData.state == 1 then
                return true
            end
        end
    end

    local isOpen = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.ClimbTowerUnlockAdvanceVip)
    if isOpen then
        local RewardvipTaskData =  ClimbTowerManager.GetTaskData(ClimbTowerManager.RewardType.Vip, ClimbTowerManager.ClimbTowerType.Advance)
        local configDataVip = ClimbTowerManager.GetChallengeConfigVipData(ClimbTowerManager.ClimbTowerType.Advance)
        for i = 1, #configDataVip do
            local data = RewardvipTaskData[configDataVip[i].Condition]
            if data then
                if data.status == 1 then
                    return true
                end
            end
        end
    end

    return false
end

-- 请求战报数据
function ClimbTowerManager.GetReportData(fightId, uid, callback, type)
    local type = type or ClimbTowerManager.ClimbTowerType.Normal
    if type == ClimbTowerManager.ClimbTowerType.Normal then
        NetManager.VirtualBattleFightRePlay(fightId, uid, function(msg)
            this.serverReportData = msg
            if callback then
                callback(msg)
            end
        end)
    elseif type == ClimbTowerManager.ClimbTowerType.Advance then
        NetManager.VirtualElitBattleFightRePlay(fightId, uid, function(msg)
            this.serverReportData_Advance = msg
            if callback then
                callback(msg)
            end
        end)
    end
    
end

function ClimbTowerManager.GetReportDataByDataId(id, type)
    local type = type or ClimbTowerManager.ClimbTowerType.Normal
    if type == ClimbTowerManager.ClimbTowerType.Normal then
        if this.serverReportData then
            for i = 1, #this.serverReportData.data do
                if this.serverReportData.data[i].dataID == tonumber(id) then
                    return this.serverReportData.data[i]
                end
            end
        end
    elseif type == ClimbTowerManager.ClimbTowerType.Advance then
        if this.serverReportData_Advance then
            for i = 1, #this.serverReportData_Advance.data do
                if this.serverReportData_Advance.data[i].dataID == tonumber(id) then
                    return this.serverReportData_Advance.data[i]
                end
            end
        end
    end
    

    return nil
end

--> 请求排行数据
function ClimbTowerManager.GetRankData(callback, type)
    local type = type or ClimbTowerManager.ClimbTowerType.Normal
    if type == ClimbTowerManager.ClimbTowerType.Normal then
        NetManager.RequestRankInfo(RANK_TYPE.CLIMB_TOWER, function(msg)
            this.serverRankData = msg
            if callback then
                callback()
            end
        end)
    elseif type == ClimbTowerManager.ClimbTowerType.Advance then
        NetManager.RequestRankInfo(RANK_TYPE.CLIMB_TOWER_ADVANCE, function(msg)
            this.serverRankData_Advance = msg
            if callback then
                callback()
            end
        end)
    end
    
end

function ClimbTowerManager.GetSortRanks(type)
    local ranks = {}
    local type = type or ClimbTowerManager.ClimbTowerType.Normal
    if type == ClimbTowerManager.ClimbTowerType.Normal then
        for i = 1, #this.serverRankData.ranks do
            table.insert(ranks, this.serverRankData.ranks[i])
        end
    elseif type == ClimbTowerManager.ClimbTowerType.Advance then
        for i = 1, #this.serverRankData_Advance.ranks do
            table.insert(ranks, this.serverRankData_Advance.ranks[i])
        end
    end

    table.sort(ranks, function(a, b)
        return a.rankInfo.rank < b.rankInfo.rank
    end)

    return ranks
end

--> 检测高级是否开启
function ClimbTowerManager.CheckEliteModeIsOpen()
    local specialConfig = ConfigManager.GetConfigDataByKey(ConfigName.SpecialConfig, "Key", "VirtualEliteUnlock")
    local valueArray = string.split(specialConfig.Value, "#")
    
    local isVisible = false
    local isOpen = false
    if this.fightId >= tonumber(valueArray[1]) then
        isVisible = true
    end
    if this.fightId >= tonumber(valueArray[2]) then
        isOpen = true
    end
    return isVisible, isOpen
end
--> 获取关卡星数
function ClimbTowerManager.GetStageStar(fightId)
    if this.starArray and fightId then
        if this.starArray[fightId] then
            return LengthOfTable(this.starArray[fightId])
        else
            return 0
        end
    end
    return 0
end
--> 获取关卡星任务array   no sequence
function ClimbTowerManager.GetStageStarIds(fightId)
    if this.starArray and fightId then
        if this.starArray[fightId] then
            return this.starArray[fightId]
        else
            return {}
        end
    end
    return {}
end
--> 获取精英总星数
function ClimbTowerManager.GetStageAllStarsNum()
    local cnt = 0
    if this.starArray then
        for k, v in pairs(this.starArray) do
            if v then
                local starNum = LengthOfTable(v)
                if starNum > 0 then
                    cnt = cnt + starNum
                end
            end
        end
    end
    -- return 105
    return cnt
end

--> 获取未达到三星的关卡ids
function ClimbTowerManager.GetStarUnfinishListByStar(starNum)
    local ret = {}
    if this.starArray then
        for k, v in pairs(this.starArray) do
            if v and LengthOfTable(v) == starNum then
                table.insert(ret, k)
            end
        end
    end
    return ret
end


function ClimbTowerManager.SetShopStarData()
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.VirtualEliteShopDisplayControl)) do
        this.StarLimitConditionArray[configInfo.StoreId] = configInfo
    end
end

function ClimbTowerManager.CheckShopItemIsVisible(shopId)
    local nowStarNum = ClimbTowerManager.GetStageAllStarsNum()
    if this.StarLimitConditionArray[shopId] and nowStarNum >= this.StarLimitConditionArray[shopId].VisibleStar then
        return true
    end
    return false
end

function ClimbTowerManager.CheckShopItemIsUnLock(shopId)
    local nowStarNum = ClimbTowerManager.GetStageAllStarsNum()
    if this.StarLimitConditionArray[shopId] and nowStarNum >= this.StarLimitConditionArray[shopId].BuyStar then
        return true, 0
    end
    return false, this.StarLimitConditionArray[shopId].BuyStar
end

return this