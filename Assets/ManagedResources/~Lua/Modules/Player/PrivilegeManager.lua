PrivilegeManager = {}
local this = PrivilegeManager
this.dailyGemRandomTimes = 0--限时招募次数

function this.Initialize()
    this._PrivilegeInfoList = {}   --接收到的后端的特权列表
    this._PrivilegeTypeList = {}   --从前端特权表中读取的数据，以表中列PrivilegeType为键
end

-- 初始化数据
function PrivilegeManager.InitPrivilegeData(data)
    this._PrivilegeInfoList = {}
    for i = 1, #data do
        --[[data:从后端接受到的数据  data是个列表   列表元素的结构id与priviledge的id对应    usedTimes使用次数    endTime  有效时间]]
        this._PrivilegeInfoList[data[i].id] = {
            id = data[i].id,
            usedTimes = data[i].usedTimes,
            endTime = data[i].effectTime 
        }
    end

    this._PrivilegeTypeList = {}
    local configList = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
    for _, config in ConfigPairs(configList) do
        if not this._PrivilegeTypeList[config.PrivilegeType] then
            this._PrivilegeTypeList[config.PrivilegeType] = {}
        end
        table.insert(this._PrivilegeTypeList[config.PrivilegeType], config)
    end
end

--刷新从后端接收的到的特权表
function PrivilegeManager.FiveAMRefreshLocalData(privilegeList)
    this.InitPrivilegeData(privilegeList)
    Game.GlobalEvent:DispatchEvent(GameEvent.FunctionCtrl.NextDayRefresh)
end

--刷新从后端接收的到的特权表
function PrivilegeManager.OnPrivilegeUpdate(data)
    for i = 1, #data do
        this._PrivilegeInfoList[data[i].id] = {
            id = data[i].id,
            usedTimes = data[i].usedTimes,
            endTime = data[i].effectTime,
        }
        -- 发送特权解锁事件
        Game.GlobalEvent:DispatchEvent(GameEvent.Privilege.OnPrivilegeUpdate, data[i].id)
    end
end

-- 获取服务器数据
function PrivilegeManager.GetSerData(privilegeId)
    local data = this._PrivilegeInfoList[privilegeId]
    return data
end

-- 用于比较副本id的大小
local function _CarbonIdCompare(cId1, cId2)
    local len1 = string.len(cId1)
    local diff1 = tonumber(string.sub(cId1, len1, len1))
    local id1 = tonumber(string.sub(cId1, 1, len1-1))

    local len2 = string.len(cId2)
    local diff2 = tonumber(string.sub(cId1, len2, len2))
    local id2 = tonumber(string.sub(cId1, 1, len2-1))

    if diff1 == diff2 then
        return id1 - id2
    end
    return diff1 - diff2
end

-- 判断 cdv2 是否 在cdv1条件下可以解锁
--- type 解锁类型
--- condition 解锁条件
--- value 当前值
local function _CompareCondition(type, condition, value)
    assert(type, GetLanguageStrById(11511))
    assert(condition, GetLanguageStrById(11512))
    if type == 1 then        -- 玩家等级解锁
        value = value or PlayerManager.level
        return value >= condition
    elseif type == 2 then    -- 关卡解锁
        if value then
            return _CarbonIdCompare(value, condition) >= 0
        else
            return FightPointPassManager.GetFightStateById(condition) == FIGHT_POINT_STATE.PASS
        end
    elseif type == 3 then    -- vip等级解锁
        value = value or VipManager.GetVipLevel()
        return value >= condition
    elseif type == 4 then    -- 特殊类型
        return true
    elseif type == 5 then    -- 特殊类型
        return true
    elseif type == PRIVILEGE_UNLOCKTYPE.ClimbTower then
        return ClimbTowerManager.fightId >= condition
    elseif type == PRIVILEGE_UNLOCKTYPE.BlitzStrike then
        return DefenseTrainingManager.maxLastFinishedId >= condition
    elseif type == PRIVILEGE_UNLOCKTYPE.Map then
        return MapTrialManager.curTowerLevel >= condition
    elseif type == PRIVILEGE_UNLOCKTYPE.BattlePower then
        return FormationManager.GetFormationPower(FormationManager.curFormationIndex) > condition
    end
end


--获取特权次数或者收益相关值（纯前端读表）
--- value 自定义比较值，为空时使用玩家自己的默认值进行比较，
function PrivilegeManager.GetPrivilegeNumberById(privilegeId, value)
    local privilegeData = ConfigManager.GetConfigData(ConfigName.PrivilegeTypeConfig, privilegeId)
    local unlockType = privilegeData.UnlockType
    -- 特殊类型特殊处理
    if unlockType == 4 or unlockType == 5 then
        -- 4类型没有服务器数据不解锁
        local serData = this.GetSerData(privilegeId)
        if not serData then return 0 end
        -- 判断是否有持续时间
        -- 有结束时间，但不在时间范围内
        if serData.endTime ~= 0 and serData.endTime < GetTimeStamp() then return 0 end
    end

    -- 没有条件直接 直接永远存在
    if not privilegeData.Condition then return -1 end
    -- 判断解锁条件
    local tValue = 0
    for i = 1, #privilegeData.Condition do
        local condition = privilegeData.Condition[i]
        -- 没有条件了
        if not condition then break end
        -- 按照类型比较解锁条件
        if not _CompareCondition(unlockType, condition[1], value) then break end
        -- 保存当前值
        tValue = condition[2]
    end
    -- 根据类型返回相应得数值
    if privilegeData.IfFloat == 1 then
        return tValue
    elseif privilegeData.IfFloat == 2 then
        return tValue / 10000
    else
        return tValue / 100
    end
end

--获取特权次数或者收益相关值（纯前端读表）
--- value 自定义比较值，为空时使用玩家自己的默认值进行比较，
function PrivilegeManager.GetPrivilegeNumber(privilegeType, conValue)
    local privilegeList = this._PrivilegeTypeList[privilegeType]
    if not privilegeList then return 0 end
    local value = 0
    for _, config in ipairs(privilegeList) do
        local privilegeId = config.Id
        local v = this.GetPrivilegeNumberById(privilegeId, conValue)
        -- -1表示一直存在，无限次数
        if v < 0 then return v end
        -- 所有值相同类型值相加
        value = value + v
    end
    return value
end

--获取某权益已用次数
function PrivilegeManager.GetPrivilegeUsedTimes(privilegeType)
    local privilegeList = this._PrivilegeTypeList[privilegeType]
    if not privilegeList then return 0 end
    local usedTimes = 0
    for _, config in ipairs(privilegeList) do
        local privilegeId = config.Id
        local serData = this._PrivilegeInfoList[privilegeId]
        if serData then
            usedTimes = usedTimes + serData.usedTimes
        end
    end
    return usedTimes
end

--获取特权次数相关剩余值（前后端数值计算）
function PrivilegeManager.GetPrivilegeRemainValue(privilegeType)
    local originalValue = this.GetPrivilegeNumber(privilegeType)
    local usedTimes = this.GetPrivilegeUsedTimes(privilegeType)
    local remainNum = originalValue - usedTimes
    if remainNum < 0 then
        remainNum =0
    end
    return remainNum
end

--刷新文明遗迹红点
function PrivilegeManager.RefreshRelicsRedPoint()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.TRIAL) or not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ALAMEIN_WAR) then
        return false
    end

    local EpicBattleConfig = ConfigManager.GetConfig(ConfigName.EpicBattleConfig)
    local lotterySetting = ConfigManager.GetConfig(ConfigName.LotterySetting)
    local epicBattleConfigData = EpicBattleConfig[1]
    local awardTrueValue = epicBattleConfigData.AwardTrue
    local oneExpend = lotterySetting[awardTrueValue[1]]
    local oneFreeId = oneExpend.FreeTimes

    local free = PrivilegeManager.GetPrivilegeRemainValue(oneFreeId)
    if free > 0 then
        return true
    else
        return false
    end
end

--刷新已用次数
function PrivilegeManager.RefreshPrivilegeUsedTimes(privilegeType, times)
    local privilegeList = this._PrivilegeTypeList[privilegeType]
    if not privilegeList then return end
    for _, config in ipairs(privilegeList) do
        local privilegeId = config.Id
        local serData = this._PrivilegeInfoList[privilegeId]
        if serData then
            local maxTimes = this.GetPrivilegeNumberById(privilegeId)
            local curTimes = serData.usedTimes
            local finalTimes = curTimes + times
            times = finalTimes - maxTimes
            if times <= 0 then
                this._PrivilegeInfoList[privilegeId].usedTimes = finalTimes
                break
            else
                this._PrivilegeInfoList[privilegeId].usedTimes = maxTimes
            end
        end
    end
end

--前端重置特权次数
function PrivilegeManager.RefreshStarPrivilege(privilegeType)
    local privilegeList = this._PrivilegeTypeList[privilegeType]
    if not privilegeList then return end
    for _, config in ipairs(privilegeList) do
        local privilegeId = config.Id
        local serData = this._PrivilegeInfoList[privilegeId]
        if serData then
            this._PrivilegeInfoList[privilegeId].usedTimes = 0
        end
    end
end
--前端移除某特权
function PrivilegeManager.RemovePrivilege(privilegeType,_privilegeId)
    local privilegeList = this._PrivilegeTypeList[privilegeType]
    if not privilegeList then return end
    for _, config in ipairs(privilegeList) do
        local privilegeId = config.Id
        local serData = this._PrivilegeInfoList[privilegeId]
        if serData and privilegeId == _privilegeId then
            this._PrivilegeInfoList[privilegeId] = nil
        end
    end
end

--获取某权益是否解锁的状态
function PrivilegeManager.GetPrivilegeOpenStatus(privilegeType, value)
    -- 判断条件是否符合
    local num = this.GetPrivilegeNumber(privilegeType, value)
    return num ~= 0
end

--获取某权益是否解锁的状态
function PrivilegeManager.GetPrivilegeOpenStatusById(privilegeId, value)
    -- 判断条件是否符合
    local num = this.GetPrivilegeNumberById(privilegeId, value)
    return num ~= 0
end

--获取谋权益几级解锁
function PrivilegeManager.GetPrivilegeOpenTip(privilegeType)
    local privilegeList = this._PrivilegeTypeList[privilegeType]
    if not privilegeList or #privilegeList == 0 then
        return GetLanguageStrById(11513)..tostring(privilegeType)
    end

    --当存在多解锁类型时
    if #privilegeList > 1 then
        local infoList = {}
        --解锁2倍速的处理
        for i,v in ipairs(privilegeList) do
            if (v.UnlockType == 2 or v.UnlockType == 3) and privilegeType == PRIVILEGE_TYPE.DoubleTimesFight then
                for _, con in ipairs(v.Condition) do
                    if con[2] > 0 then
                         table.insert(infoList, con[1])
                    end
                end
            end
        end
        if privilegeType==PRIVILEGE_TYPE.DoubleTimesFight then
            local fightConfig = ConfigManager.GetConfigData(ConfigName.MainLevelConfig, infoList[1])
            return string.format(GetLanguageStrById(11514),fightConfig.Name,infoList[2])
        end

        for i,v in ipairs(privilegeList) do
            if (v.UnlockType == 1 or v.UnlockType == 3) and privilegeType == PRIVILEGE_TYPE.SkipFight then
                for _, con in ipairs(v.Condition) do
                    if con[2] > 0 then
                         table.insert(infoList, con[1])
                    end
                end
            end
        end
        if privilegeType == PRIVILEGE_TYPE.SkipFight then
            return string.format(GetLanguageStrById(50353),infoList[1],infoList[2])
        end
    end

    if privilegeType == PRIVILEGE_TYPE.ClimbTowerJump then
        return GetLanguageStrById(50001)
    elseif privilegeType == PRIVILEGE_TYPE.DefenseTrainingJump then
        return GetLanguageStrById(50002)
    elseif privilegeType == PRIVILEGE_TYPE.BlitzStrikeJump then
        return GetLanguageStrById(50003)
    elseif privilegeType == PRIVILEGE_TYPE.MapJump then
        return GetLanguageStrById(50004)
    elseif privilegeType == PRIVILEGE_TYPE.Carbon then
        return GetLanguageStrById(50005)
    end

    local privilegeData = privilegeList[1]
    -- 没有条件直接返回0
    if not privilegeData.Condition then
        return GetLanguageStrById(11515)
    end

    if privilegeData.Type ~= 1 then
        return GetLanguageStrById(11516)
    end

    local condition = privilegeData.Condition
    local v = nil
    for _, con in ipairs(condition) do
        if con[2] > 0 then
            v = con[1]
        end
    end
    if not v then
        return GetLanguageStrById(11517)
    end
    if privilegeData.UnlockType == 1 then
        return string.format(GetLanguageStrById(11518), v)
    elseif privilegeData.UnlockType == 2 then
        local fightConfig = ConfigManager.GetConfigData(ConfigName.MainLevelConfig, v)
        return string.format(GetLanguageStrById(11519), fightConfig.Name)
    elseif privilegeData.UnlockType == 3 then
        return string.format(GetLanguageStrById(11520), v)
    end
end



--功能解锁是否在当前等级
--function PrivilegeManager.IsPrivilegeOpenedCurrentLevel(privilegeId, level)
function PrivilegeManager.IsPrivilegeOpenedCurrentValue(privilegeId, value)
    local privilegeData = ConfigManager.GetConfigData(ConfigName.PrivilegeTypeConfig, privilegeId)
    assert(privilegeData, string.format("ConfigName.PrivilegeTypeConfig not find Id：%s", privilegeId))
    if not privilegeData.Condition then
        return false
    end
    if privilegeData.Condition[1][1] == value then
        return
    end
end

-- 通过vip等级获取相应等级会解锁的特权信息
-- return {
--    [1] = {
--        content = "",
--        value = 0 }
--    [2] = ...
--}
function PrivilegeManager.GetTipsByVipLv(vipLv)
    local list = {}
    local configList = ConfigManager.GetAllConfigsDataByKey(ConfigName.PrivilegeTypeConfig, "UnlockType", 3)
    for _, config in ipairs(configList) do
        if config.isShowName == 1 then
            for _, condition in ipairs(config.Condition) do
                if condition[1] == vipLv then
                    local tValue = condition[2]
                    -- 根据类型返回相应得数值
                    if config.IfFloat == 1 then
                        tValue = tValue
                    elseif config.IfFloat == 2 then
                        --tValue = tValue / 10000
                        tValue=(tValue-10000)/100
                    else
                        tValue = tValue / 100
                    end
                    -- 如果是功能解锁,且解锁
                    if config.Type == 1 and tValue ~= 0 then
                        tValue = ""
                    end
                    table.insert(list, {content = config.Name, value = tValue,id = config.Id, IfFloat = config.IfFloat})
                    break
                end
            end

        end
    end
    return list
end

-- 获取特权剩余时间(非计时特权返回0)
function PrivilegeManager.GetPrivilegeLeftTime(privilegeType)
    local isActive = this.GetPrivilegeOpenStatus(privilegeType)
    if isActive then
        local privilegeList = this._PrivilegeTypeList[privilegeType]
        if not privilegeList or #privilegeList == 0 then
            return 0
        end
        for _, pId in ipairs(privilegeList) do
            local serData = this.GetSerData(pId)
            if serData and serData > 0 then
                local leftTime = serData.endTime - GetTimeStamp()
                if leftTime > 0 then 
                    return leftTime
                end
            end
        end
    end
    return 0
end

-- 获取特权剩余时间(非计时特权返回0)
function PrivilegeManager.GetPrivilegeLeftTimeById(privilegeId)
    local serData = this.GetSerData(privilegeId)
    if serData and serData.endTime > 0 then
        local leftTime = serData.endTime - GetTimeStamp()
        if leftTime > 0 then 
            return leftTime
        end
    end
    return 0
end


------- 部分特殊特权处理 -----------------------
-- 检测是否是特殊特权
--function PrivilegeManager.CheckIsSpecialPrivilege(privilegeId)
--    for _, spId in pairs(SPECIAL_PRIVILEGE) do
--        if spId == privilegeId then
--            return true
--        end
--    end

--    return false
--end
-- 开放某些特权
--function PrivilegeManager.OpenSpecialPrivilege(privilegeId)
--    -- 检测是否是特殊特权
--    if not this.CheckIsSpecialPrivilege(privilegeId) then
--        return
--    end
--    -- 检测特权是否存在
--    local serData = this._PrivilegeInfoList[privilegeId]
--    if serData then return end
--    this._PrivilegeInfoList[privilegeId] = {
--        id = privilegeId,
--        usedTimes = 0,
--        endTime = 0
--    }
--end

-- 获取特权状态(true 开启，false 未开启)
--function PrivilegeManager.GetSpecialPrivilegeStatus(privilegeId)
--    -- 检测是否是特殊特权
--    if not this.CheckIsSpecialPrivilege(privilegeId) then
--        return false
--    end
--    --
--    local serData = this._PrivilegeInfoList[privilegeId]
--    if serData then
--        return true
--    end
--    return false
--end

return this