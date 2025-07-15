SupportManager = {}
local this = SupportManager
local artifactConfig = ConfigManager.GetConfig(ConfigName.ArtifactConfig)
local artifactLevelConfig = ConfigManager.GetConfig(ConfigName.ArtifactLevelConfig)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local artifactRefineConfig = ConfigManager.GetConfig(ConfigName.ArtifactRefineConfig)
local artifactSoulConfig = ConfigManager.GetConfig(ConfigName.ArtifactSoulConfig)

local SupportDatas = {}
local MaxSupport = 0

this.ArtifactDataArray = {}
function this.Initialize()
    for _, configInfo in ConfigPairs(artifactConfig) do
        if configInfo["ArtifactType"] == 1 then
            MaxSupport = MaxSupport + 1
        end
    end
end

function SupportManager.InitData(_msg)
    SupportDatas = {}
    
    for i = 1, #_msg.supportInfo do
        local wd = {}
        wd.artifactid = _msg.supportInfo[i].supportId
        wd.openStatus = _msg.supportInfo[i].openStatus
        wd.skillLevel = _msg.supportInfo[i].skillLevel
        SupportDatas[wd.artifactid] = wd
    end
    SupportDatas.level = _msg.supportDate.level
    SupportDatas.exp = _msg.supportDate.exp
    SupportDatas.hp = _msg.supportDate.hp
    SupportDatas.att = _msg.supportDate.att
    SupportDatas.refineLevel = _msg.supportDate.refineLevel --< 改造
    SupportDatas.soulNum = _msg.supportDate.soulNum         --< 改良

    SupportDatas.isactive =_msg.supportDate.isactive  --< 支援全解锁

    this.UpdateData()
end

function SupportManager.RefreshLevelData(msg)
    SupportDatas.exp = msg.exp
    SupportDatas.hp = msg.hp
    SupportDatas.att = msg.att
    SupportDatas.level = msg.level
end
function SupportManager.SetStatus(artifactid, status)
    if SupportDatas[artifactid] then
        SupportDatas[artifactid].openStatus = status
    end
end

function SupportManager.GetDataById(id)
    return SupportDatas[id]
end
function SupportManager.SetDataById(id, value)
    SupportDatas[id] = value
    this.UpdateData()
end
function SupportManager.UpdateSkillLv(id)
    SupportDatas[id].skillLevel = SupportDatas[id].skillLevel + 1
    this.UpdateData()
end

function SupportManager.UpdateProData(msg)
    SupportDatas.exp = msg.exp
    SupportDatas.hp = msg.hp
    SupportDatas.att = msg.att
    SupportDatas.level = msg.level
    SupportDatas.refineLevel = msg.refineLevel --< 改造
    SupportDatas.soulNum = msg.soulNum         --< 改良
end

function SupportManager.UpdateArray(artifactid)
    SupportManager.AddData(artifactid)
    SupportManager.UpdateData()
end

function SupportManager.AddData(artifactid)
    local wd = {}
    wd.artifactid = artifactid
    wd.openStatus = 0
    wd.skillLevel = 1
    SupportDatas[wd.artifactid] = wd
end

function SupportManager.UpdateData()

    local unlockFactor = 0
    local isBreak = false
    this.ArtifactDataArray = {}
    repeat
        local artifactConfig = ConfigManager.GetConfigDataByKey(ConfigName.ArtifactConfig, "UnlockFactor", unlockFactor)
        if not artifactConfig then
            isBreak = true
        end
        if artifactConfig.ArtifactType == 1 then
            if SupportDatas[artifactConfig.ArtifactId] then
                table.insert(this.ArtifactDataArray, {sData = SupportDatas[artifactConfig.ArtifactId], bData = artifactConfig})
            else
                isBreak = true
            end
        elseif artifactConfig.ArtifactType == 2 then
            isBreak = true
        end
        unlockFactor = unlockFactor + 1
    until isBreak
    
    for k, v in ipairs(this.ArtifactDataArray) do
        v.openStatus = v.sData.openStatus
    end
end

function SupportManager.GetTaskData(artifactid)
    local singleTasks = {}
    local taskDatas = TaskManager.GetTypeTaskList(TaskTypeDef.SupportTask)
    for k = 1, #artifactConfig[artifactid].UnlockTaskID do
        for j = 1, #taskDatas do
            if taskDatas[j].missionId == artifactConfig[artifactid].UnlockTaskID[k] then
                table.insert(singleTasks, taskDatas[j])
                break
            end
        end
    end
    -- if #singleTasks ~= #artifactConfig[artifactid].UnlockTaskID then
    
    -- end

    return singleTasks
end

function SupportManager.CheckIsAllFinish(artifactid)
    local taskdatas = SupportManager.GetTaskData(artifactid)
    local ret = true
    for i = 1, #taskdatas do
        if taskdatas[i].state ~= 2 then
            return false
        end
    end
    return ret
end


function SupportManager.GetArtifactDataArray()
    return this.ArtifactDataArray
end

--> 是否全部激活
function SupportManager.CheckIsAllActivate()
    for k, v in ipairs(this.ArtifactDataArray) do
        if v.openStatus == 0 then
            return false
        end
    end
    if #this.ArtifactDataArray < MaxSupport then
        return false
    end
    
    return true
end

function SupportManager.GetSupportDatas()
    return SupportDatas
end

function SupportManager.GetMaxSupport()
    return MaxSupport
end

function SupportManager.CheckLevelUpIsEnough()

    local curLvData = artifactLevelConfig[SupportDatas.level]

    for i = 1, 2 do
        local itemId = curLvData.ConsumeItem[i][1]
        local itemData = itemConfig[itemId]
        if BagManager.GetItemCountById(itemId) < curLvData.ConsumeItem[i][2] then
            return false
        end
    end
    return true
end

--未解锁状态时是否能领奖
function SupportManager.RedPointCheckIsFinish()
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUPPORT) then
        if #this.ArtifactDataArray > 0 then
            local ArtifactDataArray = SupportManager.GetArtifactDataArray()
            local curArtifactData = ArtifactDataArray[#ArtifactDataArray]
            local config = artifactConfig[curArtifactData.sData.artifactid]
            
            local taskdatas = SupportManager.GetTaskData(config.ArtifactId)
            local ret = false
            
            for i = 1, #taskdatas do
                if taskdatas[i].state == 1 then
                    return true
                -- else
                --     return false
                end
            end
            return ret
        else
            return false
        end
    else
        return false
    end
end

--支援是否能升级
function SupportManager.CheckLevelUpIsEnough()
    if SupportManager.CheckIsAllActivate() == false then
        return false
    end
    local curLvData = artifactLevelConfig[SupportDatas.level]
    if curLvData == nil then
        return false
    end
    if curLvData.ConsumeItem == nil then
        return false
    end

    for i = 1, 2 do
        if curLvData.ConsumeItem[i][1] == nil or curLvData.ConsumeItem[i][2] == nil then
            return false
        end
        local itemId = curLvData.ConsumeItem[i][1]
        local itemData = itemConfig[itemId]
        if BagManager.GetItemCountById(itemId) < curLvData.ConsumeItem[i][2] then
            return false
        end
    end
    return true
end

--技能是否能升级
function SupportManager.CheckSkillIsEnough(curArtifactData)
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUPPORT) then
        if curArtifactData then
            local artifactId = curArtifactData.sData.artifactid
            local artifactSkillLv = curArtifactData.sData.skillLevel

            local supportLv = SupportManager.GetDataById("level")
            local configData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ArtifactSkillConfig, "ArtifactId", artifactId, "SkillLevel", artifactSkillLv)
            if configData == nil then
                return false
            end
            if configData.ConsumeItem == nil then
                return false
            end
            if supportLv >= configData.UnlockFactor then
            for i = 1, 2 do
                if configData.ConsumeItem[i][1] == nil or configData.ConsumeItem[i][2] == nil then
                    return false
                end
                local itemId = configData.ConsumeItem[i][1]
                if BagManager.GetItemCountById(itemId) < configData.ConsumeItem[i][2] then
                    return false
                    end
                end
                return true
            else 
                return false
            end
        else
            return false
        end
    end

    return false
end

--是否可以改造
function SupportManager.CheckRemouldIsEnough()
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUPPORT) then
        local refineLevel = SupportManager.GetDataById("refineLevel")
        local refineData = ConfigManager.GetConfigDataByKey(ConfigName.ArtifactRefineConfig, "RefineLevel", refineLevel)
        if refineData == nil then
            return false
        end
        local supportLv = SupportManager.GetDataById("level")
        if supportLv >= refineData.UnlockFactor then
            for i = 1, 2 do
                if refineData.ConsumeItem[i][1] == nil or refineData.ConsumeItem[i][2] == nil then
                    return false
                end
                local itemId = refineData.ConsumeItem[i][1]
                if BagManager.GetItemCountById(itemId) < refineData.ConsumeItem[i][2] then
                    return false
                end
            end
            return true  
        else
            return false
        end
    end
    return false
end

-- 是否可以超频
function SupportManager.CheckImproveIsEnough()
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUPPORT) then
        local usedTimes = SupportManager.GetDataById("soulNum")
        local soulData = artifactSoulConfig[1]
        local supportLv = SupportManager.GetDataById("level")
        
        local artifactConfig = G_ArtifactLevelConfig[supportLv]
        if artifactConfig == nil then
            return false
        end
        local upLimitTimes = artifactConfig.SoulLimit

        local materialTimes = BagManager.GetItemCountById(soulData.ConsumeItem[1]) / soulData.ConsumeItem[2]
        if materialTimes < 1 then
            return false
        end

        local canUseTimesMax = upLimitTimes - usedTimes
        if canUseTimesMax < 1 then
            return false
        end
        return true
    end
    return false
end

-- 支援选择数据
function SupportManager.UpdateSelectData(_msg)
    this.selectData = {}
    for k, v in ipairs(_msg.supportInfo) do
        table.insert(this.selectData, v)
    end
end
function SupportManager.GetSelectData()
    return this.selectData
end
function SupportManager.SetFormationSupportId(teamId, supportId)
    if this.supportId == nil then
        this.supportId = {}
    end
    this.supportId[teamId] = supportId
end
function SupportManager.GetFormationSupportId(teamId)
    return this.supportId[teamId] or 0
end

function SupportManager.GetRemouldPropertyValue(remouldLv, propertyId)
    local totalPro = 0
    for _, value in ConfigPairs(ConfigManager.GetConfig(ConfigName.ArtifactRefineConfig)) do
        if value.RefineLevel <= remouldLv then
            if value.PropertyId == propertyId then
                totalPro = totalPro + value.Value
            end
        end
    end
    return totalPro
end

function SupportManager.GetRemouldPropertyAllValue(remouldLv) 
    local temp = {}
    for _, value in ConfigPairs(ConfigManager.GetConfig(ConfigName.ArtifactRefineConfig)) do
        if value.RefineLevel <= remouldLv then
            if temp[value.PropertyId] == nil then
                temp[value.PropertyId] = 0
            end
            temp[value.PropertyId] = temp[value.PropertyId] + value.Value
        end
    end

    local ret = {}
    for i = 1, #SupportRemouldSysMap do
        table.insert(ret, temp[SupportRemouldSysMap[i]] or 0)
    end
    return ret
end

function SupportManager.GetAllPropertyAdd()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUPPORT) then
        return {}
    end
    local addAllProVal = {}

    --> 升级
    local hp = SupportManager.GetDataById("hp") or 0
    local att = SupportManager.GetDataById("att") or 0

    if addAllProVal[HeroProType.Hp] == nil then
        addAllProVal[HeroProType.Hp] = 0
    end
    if addAllProVal[HeroProType.Attack] == nil then
        addAllProVal[HeroProType.Attack] = 0
    end
    addAllProVal[HeroProType.Hp] = addAllProVal[HeroProType.Hp] + hp
    addAllProVal[HeroProType.Attack] = addAllProVal[HeroProType.Attack] + att

    --> 改造
    local remouldLv = SupportManager.GetDataById("refineLevel")
    local temp = {}
    for _, value in ConfigPairs(ConfigManager.GetConfig(ConfigName.ArtifactRefineConfig)) do
        if value.RefineLevel <= remouldLv then
            if temp[value.PropertyId] == nil then
                temp[value.PropertyId] = 0
            end
            temp[value.PropertyId] = temp[value.PropertyId] + value.Value
        end
    end
    SupportManager.DoubleTableCompound(addAllProVal, temp)
    
    --> 改良
    temp = {}
    local addProTimes = SupportManager.GetDataById("soulNum")
    this.soulData = artifactSoulConfig[1]
    local proid1 = this.soulData.PropertyAdd[1][1]
    local provalue1 = this.soulData.PropertyAdd[1][2]
    local proid2 = this.soulData.PropertyAdd[2][1]
    local provalue2 = this.soulData.PropertyAdd[2][2]
    provalue1 = provalue1 * addProTimes
    provalue2 = provalue2 * addProTimes
    temp[proid1] = provalue1
    temp[proid2] = provalue2
    SupportManager.DoubleTableCompound(addAllProVal, temp)

    return addAllProVal
end

function SupportManager.DoubleTableCompound(allProVal, addProVal)
    if addProVal and LengthOfTable(addProVal) > 0 then
        for k, v in pairs(addProVal) do
            if v > 0 then
                if allProVal[k] then
                    allProVal[k] = allProVal[k] + v
                else
                    allProVal[k] = v
                end
            end
        end
    end
end

--> 获取对应支援id 最大技能等级
function SupportManager.GetSkillMaxLvById(artifactId)
    return #ConfigManager.GetAllConfigsDataByKey(ConfigName.ArtifactSkillConfig, "ArtifactId", artifactId)
end

--> 获取服务端支援数据
function SupportManager.GetServerData(func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.SUPPORT) then
        if func then
            func()
        end
        return
    end
    NetManager.GetSupportInfos(func)
end

--> 红点
function SupportManager.CheckRedPoint()
    if SupportDatas and next(SupportDatas) ~= nil then
        local isAllActive = SupportManager.CheckIsAllActivate()
        if isAllActive then --< 任务全部激活
            local array = SupportManager.GetArtifactDataArray()
            for i = 1, #array do
                if SupportManager.CheckSkillIsEnough(array[i]) then
                    return true
                end
            end
            return SupportManager.CheckLevelUpIsEnough() or SupportManager.CheckImproveIsEnough() or SupportManager.CheckRemouldIsEnough()
        else
            return SupportManager.RedPointCheckIsFinish()
        end
    else
        return false
    end

    return false
end
return this