CombatPlanManager = {}
local this = CombatPlanManager
local LuckCombatPlanConfig = ConfigManager.GetConfig(ConfigName.CombatPlanConfig)
function this.Initialize()
    this.allPlanData = {}
    this.compoundExp = 0
    this.luckyNum = {}
end

function CombatPlanManager.InitData(_msg)
end

function CombatPlanManager.UpdatePlanData(_msg)
    for k, v in ipairs(_msg.plan) do
        if this.allPlanData[v.id] == nil then
            this.allPlanData[v.id] = this.CreateEmptyTable()
        end
        this.CopyValue(this.allPlanData[v.id], v)
    end
end

function CombatPlanManager.GetAllPlanData()
    return this.allPlanData
end

function CombatPlanManager.CreateEmptyTable()
    local a = {}
    a.id = nil
    a.combatPlanId = nil
    a.property = {}
    a.skill = {}
    a.quality = nil
    a.isLocked = nil
    a.promotionLevel = nil
    a.upHeroDid = nil
    return a
end

function CombatPlanManager.CopyValue(plan, sPlan)
    plan.id = sPlan.id
    plan.combatPlanId = sPlan.combatPlanId
    plan.property = {}
    for i = 1, #sPlan.property do
        plan.property[i] = {}
        plan.property[i].id = sPlan.property[i].id
        plan.property[i].value = sPlan.property[i].value
    end
    plan.skill = {}
    for i = 1, #sPlan.skill do
        plan.skill[i] = sPlan.skill[i]
    end
    plan.quality = G_CombatPlanConfig[plan.combatPlanId].Quality    --后端quality暂时没用
    plan.isLocked = sPlan.isLocked
    plan.promotionLevel = sPlan.promotionLevel
    if sPlan.upHeroDid then     --< 替换时 如果没有upHeroDid 不替换
        plan.upHeroDid = sPlan.upHeroDid
    end
end

function CombatPlanManager.UpdateSinglePlanData(sPlan)
    if sPlan == nil then
        LogError("### UpdateSinglePlanData Error!!!")
        return
    end
    if this.allPlanData[sPlan.id] == nil then
        this.allPlanData[sPlan.id] = this.CreateEmptyTable()
    end
    this.CopyValue(this.allPlanData[sPlan.id], sPlan)
end

function CombatPlanManager.DelSinglePlanData(planDid)
    if this.allPlanData[planDid] == nil then
        LogError("### DelSinglePlanData Error!!!")
        return
    end
    this.allPlanData[planDid] = nil
end

function CombatPlanManager.DelSinglePlanDatas(planDids)
    for i = 1, #planDids do
        CombatPlanManager.DelSinglePlanData(planDids[i])
    end
end

function CombatPlanManager.GetPlanData(planDid)
    if not this.allPlanData[planDid] then
        -- LogError("### GetPlanData planDid not found!!!")
        return nil
    end
    return this.allPlanData[planDid]
end

function CombatPlanManager.UpPlanData(heroDid, planDid)
    if this.allPlanData[planDid] then
        this.allPlanData[planDid].upHeroDid = heroDid
    else
        LogError("### HeroUp planDid Error!!!")
    end
end

function CombatPlanManager.DownPlanData(heroDid, planDid)
    if this.allPlanData[planDid] and this.allPlanData[planDid].upHeroDid == heroDid then
        this.allPlanData[planDid].upHeroDid = nil
    else
        LogError("### HeroDown planDid Error!!!")
    end
end

function CombatPlanManager.RequestAllPlanData(func)
    -- 是否解锁
    -- if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.COMBAT_PLAN) then
    --     if func then
    --         func()
    --     end
    --     return
    -- end

    NetManager.CombatPlanGetAllRequest(function(_msg)
        this.UpdatePlanData(_msg)
        if func then
            func()
        end
    end)
end

-- 1 up 2 down 3 all
function CombatPlanManager.GetPlanByType(type)
    local type = type or 3
    local ret = {}
    for k, v in pairs(this.allPlanData) do
        if type == 1 then
            if v.upHeroDid then
               table.insert(ret, v) 
            end
        elseif type == 2 then
            if not v.upHeroDid then
                table.insert(ret, v) 
            end
        else
            table.insert(ret, v) 
        end
    end
    table.sort(ret, function(a, b)
        return a.quality > b.quality
    end)
    return ret
end

-- 一键添加红点
function CombatPlanManager.RefreshRingcompoundRedpoint()
    --local allPlans = CombatPlanManager.GetAllCanCompoundPlans()
     local luckTab={}  --可合成戒指id表
    -- local item = {{},{},{},{}}
    -- for index, value in ipairs(allPlans) do
    --     table.insert(item[value.quality],value)
    -- end
    -- for i = 1, 4 do
    --     if #item[i] >= 5 then
    --         return true
    --     end
    -- end
    for _, configInfo in ConfigPairs(LuckCombatPlanConfig) do
        if  PlayerManager.level >= configInfo.PlayerLevelLimit then
            table.insert(luckTab,configInfo.ID)
        end
    end
    local luckyNum = 0
    local luckDataId = 0
    local luckData=CombatPlanManager.GetBagAllDatas()
    local itemData = CombatPlanManager.GetBagAllDatas()
    for index, value in ipairs(itemData) do
       for k, v in ipairs(luckData) do
            if value.itemConfig.Name == v.itemConfig.Name and v.quality<5 and value.quality<5 then
                luckyNum = luckyNum + 1
                luckDataId =  v.combatPlanId
            end
       end

       
       if luckyNum>=5 then
            for _index, _value in ipairs(luckTab) do
                if _value == luckDataId then
                    return true
                end
            end
       end
       luckyNum = 0
       luckDataId = 0
    end
    return false
end

-- 穿
function CombatPlanManager.UpPlan(heroDid, planDid, pos, func)
    if pos ~= 1 and pos ~= 2 then
        LogError("### pos error1")
        return
    end
    NetManager.CombatPlanWearRequest(heroDid, planDid, pos, function()
        if func then
            func()
        end
    end)
end

-- 脱
function CombatPlanManager.DownPlan(heroDid, planDid, pos, func)
    if pos ~= 1 and pos ~= 2 then
        LogError("### pos error2")
        return
    end
    NetManager.CombatPlanUnloadRequest(heroDid, planDid, pos, function()
        if func then
            func()
        end
    end)
end

-- 替
function CombatPlanManager.ReplacePlan(heroDid, oldPlanDid, newPlanDid, pos, func)
    if pos ~= 1 and pos ~= 2 then
        LogError("### pos error3")
        return
    end
    NetManager.CombatPlanReplaceRequest(heroDid, oldPlanDid, newPlanDid, pos, function()
        if func then
            func()
        end
    end)
end

-- 分解
function CombatPlanManager.DecomposePlan(planDid, func)
    NetManager.CombatPlanSellRequest(planDid, function(msg)
        if func then
            func(msg)
        end
    end)
end

-- 重铸
function CombatPlanManager.RebuildPlan(planDid, func)
    NetManager.CombatPlanRebuildRequest(planDid, function(msg)
        if func then
            func(msg)
        end
    end)
end

-- 重铸确认
function CombatPlanManager.RebuildConfirmPlan(planDid, func)
    NetManager.CombatPlanConfirmRequest(planDid, function()
        if func then
            func()
        end
    end)
end

-- 合成方案
function CombatPlanManager.CompoundPlan(planDids, compoundQuality, func)
    NetManager.CombatPlanMergeRequest(planDids, compoundQuality, function(msg)
        if func then
            func(msg)
        end
    end)
end

-- 请求相关数据
function CombatPlanManager.RequestEgData(func)
    NetManager.CombatPlanReBuildNumRequest(function(msg)
        local ex = msg.exp-this.compoundExp
        this.compoundExp = msg.exp
        this.luckyNum = {}
        for i = 1, #msg.luckyNum do
            table.insert(this.luckyNum, msg.luckyNum[i])
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.CombatPlan.CompoundPlanExpPush)
        Game.GlobalEvent:DispatchEvent(GameEvent.CombatPlan.RebuildPlan)
        if func then
            func(msg,ex)
        end
    end)
end

function CombatPlanManager.CalPlanPower(planDid)
    if not this.allPlanData[planDid] then
        LogError("### CalPlanPower Error!!!")
        return
    end
    local allPro = {}

    for k, v in ipairs(this.allPlanData[planDid].property) do
        allPro[v.id] = v.value  -- 应该无重复 不用合了
    end

    local powerEndVal = 0
    for i, v in pairs(allPro) do
        if v > 0 then
            powerEndVal = powerEndVal + v * HeroManager.heroPropertyScore[i]
        end
    end
    return math.floor(powerEndVal)
end

function CombatPlanManager.GetMainProList(planDid)
    if not this.allPlanData[planDid] then
        LogError("### GetMainProList Error!!!")
        return
    end
    local propList = {}
    for k, v in ipairs(this.allPlanData[planDid].property) do
        propList[k] = {}
        propList[k].propertyId = v.id
        propList[k].propertyValue = v.value
        propList[k].PropertyConfig = G_PropertyConfig[v.id]
    end
    return propList
end

-- 解耦属性
function CombatPlanManager.CalPlanPowerByProperty(property)
    local allPro = {}

    for k, v in ipairs(property) do
        allPro[v.id] = v.value  --< 应该无重复 不用合了
    end

    local powerEndVal = 0
    for i, v in pairs(allPro) do
        if v > 0 then
            powerEndVal = powerEndVal + v * HeroManager.heroPropertyScore[i]
        end
    end
    return math.floor(powerEndVal)
end
-- 解耦属性
function CombatPlanManager.GetMainProListByProperty(property)
    local propList = {}
    for k, v in ipairs(property) do
        propList[k] = {}
        propList[k].propertyId = v.id
        propList[k].propertyValue = v.value
        propList[k].PropertyConfig = G_PropertyConfig[v.id]
    end
    return propList
end

-- 获取所有可合成plan
function CombatPlanManager.GetAllCanCompoundPlans()
    -- 品质1~4
    local ret = {}
    for k, v in pairs(this.allPlanData) do
        if v.quality <= 4 and v.upHeroDid == nil then
            local retv = CombatPlanManager.CreateEmptyTable()
            CombatPlanManager.CopyValue(retv, v)
            table.insert(ret, retv)
        end
    end
    table.sort(ret, function(a, b)
        return a.quality < b.quality
    end)
    return ret
end

-- 获取所有可晋级plan
function CombatPlanManager.GetAllCanPromotionPlans()
    local ret = {}
    for k, v in pairs(this.allPlanData) do
        if G_CombatPlanConfig[v.combatPlanId].CanPromotion==1 then
            local retv = CombatPlanManager.CreateEmptyTable()
            CombatPlanManager.CopyValue(retv, v)
            table.insert(ret, retv)
        end
    end
    return ret
end

-- 支持背包的数据
function CombatPlanManager.GetBagAllDatas()
    local ret = {}
    for k, v in pairs(this.allPlanData) do
        if v.upHeroDid == nil then
            local retv = CombatPlanManager.CreateEmptyTable()
            CombatPlanManager.CopyValue(retv, v)
            local quatilyId= CombatPlanManager.SetQuality(retv.quality)

            retv.itemConfig = G_ItemConfig[retv.combatPlanId]
            retv.frame = GetQuantityImageByquality(quatilyId)
            retv.icon = GetResourcePath(retv.itemConfig.ResourceID)
            table.insert(ret, retv)
        end
    end
    table.sort(ret, function(a, b)
        return a.quality > b.quality
    end)
    return ret
end

function CombatPlanManager.SetQuality(qualityId)
    local id = 0
    if qualityId ~= 6 then
        id = qualityId + 1
    else
        id = qualityId
    end
    return id
end

return this