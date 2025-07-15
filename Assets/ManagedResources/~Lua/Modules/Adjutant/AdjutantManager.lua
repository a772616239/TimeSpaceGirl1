AdjutantManager = {}
local this = AdjutantManager
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local adjutantChatConfig = ConfigManager.GetConfig(ConfigName.AdjutantChatConfig)
local adjutantConfig = ConfigManager.GetConfig(ConfigName.AdjutantConfig)
local adjutantHandselConfig = ConfigManager.GetConfig(ConfigName.AdjutantHandselConfig)
local adjutantSkillConfig = ConfigManager.GetConfig(ConfigName.AdjutantSkillConfig)
local adjutantTeachConfig = ConfigManager.GetConfig(ConfigName.AdjutantTeachConfig)

local curSelectAdjutantId = 1

function this.Initialize()
end

function AdjutantManager.InitData(_msg)
    this.adjutantData = {}
    this.adjutantData.vigorTotal = _msg.vigorTotal
    this.adjutantData.addVigorTime = _msg.addVigorTime
    
    this.adjutantData.adjutants = {}
    for i = 1, #_msg.adjutant do
        table.insert(this.adjutantData.adjutants, this.GetAdjutantCopyData(_msg.adjutant[i]))
    end
end

function AdjutantManager.GetAdjutantCopyData(protoAdjutantData)
    local adjutant = {}
    adjutant.id = protoAdjutantData.id
    adjutant.chatLevel = protoAdjutantData.chatLevel
    adjutant.exp = protoAdjutantData.exp
    adjutant.handselNum = protoAdjutantData.handselNum
    adjutant.teachLevel = protoAdjutantData.teachLevel
    adjutant.skillLevel = protoAdjutantData.skillLevel
    adjutant.modulePropertys = {}

    for i, moduleProperty in ipairs(protoAdjutantData.moduleProperty) do
        local modulePropertyValue = {}
        modulePropertyValue.id = moduleProperty.id
        modulePropertyValue.property = {}
        local propertys = {}
        for j, propertyValue in ipairs(moduleProperty.property) do
            local property = {}
            property.id = propertyValue.id
            property.value = propertyValue.value
            table.insert(modulePropertyValue.property, property)
        end
        
        table.insert(adjutant.modulePropertys, modulePropertyValue)
    end
    return adjutant
end

function AdjutantManager.GetAdjutantData()
    return this.adjutantData
end

function AdjutantManager.CheckUnlockAdjutant(func)
    -- 等级解锁
    local adjutantDatas = ConfigManager.GetAllConfigsDataByKey(ConfigName.AdjutantConfig, "UnlockType", 1)
    local ids = {}
    for _, v in ipairs(adjutantDatas) do
        if PlayerManager.level >= v.Cost[1] then
            local isHave = false
            for _, w in ipairs(this.adjutantData.adjutants) do
                if v.AdjutantId == w.id then
                    isHave = true
                    break
                end
            end
            if not isHave then
                table.insert(ids, v.AdjutantId)
            end
        end
    end
    -- 道具解锁
    local adjutantDatasItem = ConfigManager.GetAllConfigsDataByKey(ConfigName.AdjutantConfig, "UnlockType", 2)
    for _, v in ipairs(adjutantDatasItem) do
        local ownNum = BagManager.GetItemCountById(v.Cost[1])
        if ownNum >= v.Cost[2] then
            local isHave = false
            for _, w in ipairs(this.adjutantData.adjutants) do
                if v.AdjutantId == w.id then
                    isHave = true
                    break
                end
            end
            if not isHave then
                table.insert(ids, v.AdjutantId)
            end
        end
    end

    if #ids > 0 then
        --没有已解锁的副官 刷新
        NetManager.GetAdjutantUnlock(ids, function()
            NetManager.GetAllAdjutantInfo(function()
                if func then
                    func()
                end
            end)
        end)
    else
        --开界面都刷一遍数据 可以优化
        NetManager.GetAllAdjutantInfo(function()
            if func then
                func()
            end
        end)
    end
end

function AdjutantManager.GetAllAdjutantArchiveData()
    local ret = {}
    for _, configInfo in ConfigPairs(ConfigManager.GetConfig(ConfigName.AdjutantConfig)) do
        table.insert(ret, configInfo)
    end
    return ret
end

function AdjutantManager.GetAllAdjutantsPro(modelId)
    local ret = {}
    if not this.adjutantData then
        return
    end
    for i, adjutant in ipairs(this.adjutantData.adjutants) do      
        if adjutant.modulePropertys then
            for j, model in ipairs(adjutant.modulePropertys) do
                if model.property and (model.id == modelId or modelId == nil) then
                    for k, pro in ipairs(model.property) do
                        if ret[pro.id] == nil then
                            ret[pro.id] = 0
                        end
                        ret[pro.id] = ret[pro.id] + pro.value
                    end
                end
            end
        end
    end
    return ret
end

function AdjutantManager.GetAllAdjutantsProWithModel(modelId)
    local ret = {}
    local allPro = AdjutantManager.GetAllAdjutantsPro(modelId)
    local tempRet = {}
    for key, value in pairs(allPro) do
        table.insert(tempRet, {id = key, value = value})
    end
    return tempRet
end

function AdjutantManager.GetAllAdjutantsProBase()
    local ret = {}
    local allPro = AdjutantManager.GetAllAdjutantsPro()
    for proid, value in pairs(allPro) do
        if proid == HeroProType.Attack or proid == HeroProType.Hp or proid == HeroProType.PhysicalDefence or proid == HeroProType.Speed then
            ret[proid] = value
        end
    end
    local tempRet = {}
    for key, value in pairs(ret) do
        table.insert(tempRet, {id = key, value = value})
    end
    return tempRet
end

function AdjutantManager.GetAllAdjutantsProPer()
    local ret = {}
    local allPro = AdjutantManager.GetAllAdjutantsPro()
    for proid, value in pairs(allPro) do
        if proid ~= HeroProType.Attack and proid ~= HeroProType.Hp and proid ~= HeroProType.PhysicalDefence and proid ~= HeroProType.Speed then
            ret[proid] = value
        end
    end
    local tempRet = {}
    for key, value in pairs(ret) do
        table.insert(tempRet, {id = key, value = value})
    end
    return tempRet
end

function AdjutantManager.SetCurSelectAdjutantId(id)
    curSelectAdjutantId = id
    AdjutantManager.CheckAllRedPoint()
end

function AdjutantManager.CheckAllRedPoint()
    CheckRedPointStatus(RedPointType.Adjutant_Btn_Chat)
    CheckRedPointStatus(RedPointType.Adjutant_Btn_Skill)
    CheckRedPointStatus(RedPointType.Adjutant_Btn_Handsel)
    CheckRedPointStatus(RedPointType.Adjutant_Btn_Teach)
    CheckRedPointStatus(RedPointType.Adjutant_FreeButton)
end

function AdjutantManager.GetCurSelectAdjutantId()
    return curSelectAdjutantId
end

--> modelId 对于副官四个模块 1沟通 2送礼 3特训   没技能
function AdjutantManager.GetOnePro(proId, adjutantId, modelId)
    local ret = {}
    for i, adjutant in ipairs(this.adjutantData.adjutants) do
        if adjutant.modulePropertys and adjutant.id == adjutantId then
            for j, model in ipairs(adjutant.modulePropertys) do
                if model.property and model.id == modelId then
                    for k, pro in ipairs(model.property) do
                        if pro.id == proId then
                            if ret[pro.id] == nil then
                                ret[pro.id] = 0
                            end
                            ret[pro.id] = ret[pro.id] + pro.value
                        end
                    end
                end
            end
        end
    end
    if next(ret) ~= nil then
        return proId, ret[proId]
    else
        return proId, 0
    end
end

function AdjutantManager.GetOneAdjutantDataById(adjutantId)
    for i, adjutant in ipairs(this.adjutantData.adjutants) do
        if adjutant.id == adjutantId then
            return adjutant
        end
    end
    
    return nil
end

function AdjutantManager.SetFormationAdjutantId(teamId, adjutantId)
    if this.adjutantId == nil then
        this.adjutantId = {}
    end
    this.adjutantId[teamId] = adjutantId
end
function AdjutantManager.GetFormationAdjutantId(teamId)
    return this.adjutantId[teamId] or 0
end

function AdjutantManager.GetConfigAdjutants()
    local ret = {}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.AdjutantConfig)) do
        table.insert(ret, v)
    end
    return ret
end

--获取各模块 上限值
function AdjutantManager.GetMaxLimit(adjutantid, model)
    local max = 0
    if model == 1 then
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.AdjutantChatConfig)) do
            if v.AdjutantId == adjutantid then
                max = math.max(max, v.Lvl)
            end
        end
    elseif model == 2 then
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.AdjutantSkillConfig)) do
            if v.AdjutantId == adjutantid then
                max = math.max(max, v.SkillLvl)
            end
        end
    elseif model == 3 then
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.AdjutantChatConfig)) do
            if v.AdjutantId == adjutantid then
                max = math.max(max, v.UpgradeLimit)
            end
        end
    elseif model == 4 then
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.AdjutantTeachConfig)) do
            if v.AdjutantId == adjutantid then
                max = math.max(max, v.TeachLvl)
            end
        end
    end

    return max
end

function AdjutantManager.GetAllPropertyAdd()
    return AdjutantManager.GetAllAdjutantsPro()
end

-----以下方法用于副官红点，但刷新有问题，暂时先不用了
--自由沟通剩余精力红点
function AdjutantManager.IsVigorTotal()
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ADJUTANT) then
        local count = this.adjutantData.vigorTotal
        return count > 0
    end
end

--沟通红点
function AdjutantManager.IsChatEnough()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ADJUTANT) then
        return false
    end
    if curSelectAdjutantId then
        local data = AdjutantManager.GetOneAdjutantDataById(curSelectAdjutantId)
        if data == nil then
            return false
        end
        local lv = data.chatLevel
        local curLvData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantChatConfig, "AdjutantId", curSelectAdjutantId, "Lvl", lv)
        
        if lv >= AdjutantManager.GetMaxLimit(curSelectAdjutantId, 1) then
            return false
        end
        local enough = true
        for i = 1, 2 do
            local itemId = curLvData.Cost[i][1]
            local itemData = itemConfig[itemId]
            local bagNum = BagManager.GetItemCountById(itemId)
            if bagNum < curLvData.Cost[i][2] then
                enough = false
            end
        end
        return enough
    end
    return false
end

--技能红点
function AdjutantManager.IsSkillEnough()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ADJUTANT) then
        return false
    end
    if curSelectAdjutantId then
        local data = AdjutantManager.GetOneAdjutantDataById(curSelectAdjutantId)
        if data == nil then
            return false
        end
        local curLv = data.skillLevel
        if curLv >= AdjutantManager.GetMaxLimit(curSelectAdjutantId, 2) then
            return false
        end
        local curLvData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantSkillConfig, "AdjutantId", curSelectAdjutantId, "SkillLvl", curLv)
        local enough = true
        for i = 1, 2 do
            local itemId = curLvData.Cost[i][1]
            local bagNum = BagManager.GetItemCountById(itemId)
            if bagNum < curLvData.Cost[i][2] then
                enough = false
            end
        end
        if enough then
            if data.chatLevel < curLvData.LimitLvl then
                return false
            else
                return true
            end
        else
            return false
        end
    end
    return false
end

--礼物红点
function AdjutantManager.IsHandselEnough()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ADJUTANT) then
        return false
    end
    if curSelectAdjutantId then
        local data = AdjutantManager.GetOneAdjutantDataById(curSelectAdjutantId)
        if data == nil then
            return false
        end
        this.usedTimes = data.handselNum
        this.handselData = adjutantHandselConfig[1]
        this.addProTimes = math.floor(this.usedTimes / this.handselData.Bout)
        if data.chatLevel >= AdjutantManager.GetMaxLimit(curSelectAdjutantId, 3) then
            return false
        end
        local adjutantChatData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantChatConfig, "AdjutantId", curSelectAdjutantId, "Lvl",data.chatLevel)
        
        this.upLimitTimes = adjutantChatData.UpgradeLimit
        this.canUseTimesMax = this.upLimitTimes - this.usedTimes
        local materialTimes = BagManager.GetItemCountById(this.handselData.ConsumeItem[1]) / this.handselData.ConsumeItem[2]
        this.maxNum = math.min(this.canUseTimesMax, materialTimes)
        local value = this.maxNum > 0 and 1 or 0
        if value == 0 then
            return false
        end
        return true
    end
    return false
end

--特训红点
function AdjutantManager.IsTeachEnough()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ADJUTANT) then
        return false
    end
    if curSelectAdjutantId then
        local data = AdjutantManager.GetOneAdjutantDataById(curSelectAdjutantId)
        if data == nil then
            return false
        end
        local chatLv = data.chatLevel
        local curLv = data.teachLevel
        if curLv >= AdjutantManager.GetMaxLimit(curSelectAdjutantId, 4) then
            return false
        end
        local curLvData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.AdjutantTeachConfig, "AdjutantId", curSelectAdjutantId, "TeachLvl", curLv)
    
        local enough = true
        for i = 1, 2 do
            local itemId = curLvData.Cost[i][1]
            local itemData = itemConfig[itemId]
            local bagNum = BagManager.GetItemCountById(itemId)
            if bagNum < curLvData.Cost[i][2] then
                enough = false
            end
    
        end
        if enough then
            if chatLv < curLvData.NeedLvl then
                return false
            else
                return true
            end
        else
            return false
        end
    end
    return false
end

function AdjutantManager.IsRoleHaveRedPoint(AdjutantId)
    if AdjutantId then
        return AdjutantManager.IsChatEnough(AdjutantId)
            or AdjutantManager.IsSkillEnough(AdjutantId)
            or AdjutantManager.IsHandselEnough(AdjutantId)
            or AdjutantManager.IsTeachEnough(AdjutantId)
    end
    return false
end

--红点
function AdjutantManager.CheckRedPoint()
    local adjutantData = AdjutantManager.GetAdjutantData()
    if adjutantData and #adjutantData.adjutants > 0 then
    else
        return false
    end
    local redPoint = false
    for i = 1, #adjutantData.adjutants do
        if AdjutantManager.IsRoleHaveRedPoint(adjutantData.adjutants[i].id) then
            redPoint = true
        end
    end
    if redPoint or AdjutantManager.IsVigorTotal() then
        return true
    end

    return false
end

return this