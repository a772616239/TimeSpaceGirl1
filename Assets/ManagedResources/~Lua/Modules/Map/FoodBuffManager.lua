-- 管理地图中的buff效果
FoodBuffManager = {}
local exploreData = ConfigManager.GetConfig(ConfigName.ExploreFunctionConfig)
local this = FoodBuffManager

-- 探索相关的默认视野范围
this.fogSize = exploreData[2].Value
-- 驱散迷雾的半径
this.fogRange = 0
-- 驱散迷雾的中心点
this.fogCenter = 0

this.StayBuff = {}
this.StepBuff = {}
function this.Initialize()
    this.StayBuff = {}
    this.StepBuff = {}
end

-- buff效果, 参数：id -> buff id, AddObj -> 作用对象, effects ->效果参数, type -> 效果类型
function this.ShowBuff(id, AddObj, effects, type, func, eventId)
    local existAsyncBehaivor = false
    for i = 1, #effects do
        local effectId = effects[i][1]
        local effectNum = effects[i][2]

        if AddObj == 1 then -- 全部单体效果
            this.AddForEach(type, effectId, effectNum)
        elseif AddObj == 2 then -- 全体效果
            this.AddForWhole(type, effectId, effectNum)
            if type == 2 and effectId == 6 then
                existAsyncBehaivor = true
                Game.GlobalEvent:DispatchEvent(GameEvent.Map.DisperseFog, func, eventId)
            end
        elseif AddObj == 2 then -- 异妖效果

        end
    end
    if not existAsyncBehaivor then
        if func then
            func(eventId)
        end
    end
end

-- 整体效果增加
function this.AddForWhole(type, effectId, effectNum)
    if type == 1 then --修改人物属性

    elseif type == 2 then -- 修改地图数据
        -- 判断buff增加类型
        if effectId == 1 then -- 修改移动速度
        elseif effectId == 2  then -- 修改视野范围
            this.fogSize = this.fogSize + effectNum
        elseif effectId == 3  then -- 修改扎营次数

        elseif effectId == 4  then -- 修改采矿暴击率

        elseif effectId == 5  then -- 增加行动力
            local leftStep = MapManager.leftStep
            leftStep = leftStep + effectNum
            MapManager.leftStep = leftStep
        elseif effectId == 6 then  -- 驱散迷雾
            local fogRange = exploreData[effectId].Value
            this.fogRange = fogRange
            this.fogCenter = MapManager.GetPosByMapPointId(effectNum)
        else
           
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.MapDataChange, effectId)
    else

    end

end

-- 每个人的效果增加
function this.AddForEach(type, effectId, effectNum)
    -- 读取所有的参数值
   
   

    if type == 1 then --修改人物属性
        local changeType = 0
        if effectNum > 0 then -- 加数值
            changeType = 1
        else --减数值
            changeType = 0
            effectNum = Mathf.Abs(effectNum)
        end
        MapManager.RefreshFormationProListVal(effectId, changeType, effectNum)
    elseif type == 2 then -- 修改地图数据

    else

    end
end

-- 消除人物身上的buff
function this.EraseBuff(buffId)

end

-- 两种类型的buff
local BuffClassModules = {
    [1] = require("Modules/Map/FoodBuff/Buff/foodbuff_fight"),
    [2] = require("Modules/Map/FoodBuff/Buff/foodbuff_map")
}
--- 创建一个探索Buff
---id                buffId
---isShowTip        是否显示Tip
---isWork           buff是否立即生效，由于buff在副本初始化时获取的加血buff不必再次触发效果，此字段用于控制加血的时机
function this.CreateFoodBuff(id, isShowTip, isWork)
    --- 判断buff是否存在, 如果存在重置步数
    local buff = this.GetStepBuff(id)
    if buff then
        buff:ResetLeftStep()
        if isShowTip and buff.desc ~= "" then
            this.ShowTip(buff.desc)
        end
        -- 更新事件
        if isWork then
            Game.GlobalEvent:DispatchEvent(GameEvent.FoodBuff.OnFoodBuffStart, buff.ID)
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.FoodBuff.OnFoodBuffStateChanged)
        return buff
    end
    --- 不存在则创建
    local buffTblData = ConfigManager.GetConfigData(ConfigName.FoodsConfig, id)
    local buffclass = BuffClassModules[buffTblData.Type]
    local buff = buffclass:new(id, isWork)
    -- 判断buff类型进行保存
    if buff.totalStep <= 0 then
        table.insert(this.StayBuff, buff)
    else
        table.insert(this.StepBuff, buff)
    end
    -- 判断是否显示buff提示
    if isShowTip and buff.desc ~= "" then
        this.ShowTip(buff.desc)
    end
    -- 更新事件
    if isWork then
        Game.GlobalEvent:DispatchEvent(GameEvent.FoodBuff.OnFoodBuffStart, buff.ID)
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.FoodBuff.OnFoodBuffStateChanged)
    return buff
end


--- 根据id获取相应的步数buff
function this.GetStepBuff(id)
    for _, buff in ipairs(this.StepBuff) do
        if buff.id == id then
            return buff
        end
    end
end

--- 每次移动调用
function this.OnMoveStep()
    local isSyncServer = false
    local tempStepBuff = {}
    for _, buff in ipairs(this.StepBuff) do
        if buff then
            -- 调用buff的更新方法
            buff:MoveStep()
            -- 判断buff是否销毁
            if buff.isDestroy then
                -- 显示销毁提示
                if buff.desc ~= "" then
                    this.ShowTip(buff.desc .. GetLanguageStrById(11185))
                end
                -- buff消失，要与数据库同步状态
                isSyncServer = true
                -- buff消失广播事件
                Game.GlobalEvent:DispatchEvent(GameEvent.FoodBuff.OnFoodBuffEnd, buff.ID)
            else
                -- 没有销毁，保存
                table.insert(tempStepBuff, buff)
            end
        end
    end
    -- 保存刷新后的buff
    this.StepBuff = tempStepBuff
    -- 同步数据库数据
    if isSyncServer then
        -- 非事件点触发
        NetManager.MapUpdateEvent(-1000)
    end
    -- 更新事件
    Game.GlobalEvent:DispatchEvent(GameEvent.FoodBuff.OnFoodBuffStateChanged)
end

-- 播放buff提示
function this.ShowTip(content)
    if not content then return end
    PopupText({GetLanguageStrById(content)}, 0.5, 1)
end

-- 获取当前buff列表
function this.GetAllBuffList()
    local buffList = {}
    -- 常驻buff
    for _, buff in ipairs(this.StayBuff) do
        if not buff.isDestroy then
            table.insert(buffList, buff)
        end
    end
    -- 步数buff
    for _, buff in ipairs(this.StepBuff) do
        if not buff.isDestroy then
            table.insert(buffList, buff)
        end
    end
    -- 按时间排序
    table.sort(buffList, function(a, b)
        return a.initTime > b.initTime
    end)
    return buffList
end

-- 计算buff对基础数值的加成
function this.CalBuffPropValue(fightPropList)
    -- 属性拷贝
    local propList = {}
    for id, value in ipairs(fightPropList) do
        propList[id] = value
    end

    -- 计算属性
    local function calProp(prop, val)
        local propInfo = ConfigManager.GetConfigData(ConfigName.PropertyConfig, prop)
        if not propInfo then return end
        -- 如果没有目标属性就对当前属性id进行加成
        local fightPropID = nil
        if not propInfo.TargetPropertyId or propInfo.TargetPropertyId <= 0 then
            fightPropID = GetProIndexByProId(prop)
            if not fightPropID then return end
            if fightPropID == 2 then return end -- 加血的属性不计算
            propList[fightPropID] = propList[fightPropID] + val
        else
            fightPropID = GetProIndexByProId(propInfo.TargetPropertyId)
            if not fightPropID then return end
            if fightPropID == 2 then return end -- 加血的属性不计算
            if propInfo.Style == 1 then
                propList[fightPropID] = propList[fightPropID] + val
            elseif propInfo.Style == 2 then
                propList[fightPropID] = propList[fightPropID] + (val / 10000 * propList[fightPropID])
            end
        end
    end

    -- 计算buff
    local function calBuff(buff)
        if buff.isDestroy then return end
        if buff.type ~= 1 then return end
        if not buff.effectPara then return end
        for _, v in ipairs(buff.effectPara) do
            calProp(v[1], v[2])
        end
    end

    -- buff 属性计算
    local buffList = this.GetAllBuffList()
    for _, buff in ipairs(buffList) do
        calBuff(buff)
    end

    return propList
end

-- 获取当前buff所加的属性
function this.GetBuffPropList()
    local propList = {}
    -- 固定buff属性计算
    local stayPropList = {}
    for _, buff in ipairs(this.StayBuff) do
        if not buff.isDestroy and buff.type == 1 and buff.effectPara then
            for _, v in ipairs(buff.effectPara) do
                local propId = v[1]
                local val = v[2]
                if not stayPropList[propId] then
                    stayPropList[propId] = {}
                    stayPropList[propId].id = propId
                    stayPropList[propId].value = val
                    stayPropList[propId].step = -1
                    stayPropList[propId].totalStep = buff.totalStep
                    stayPropList[propId].time = buff.initTime
                else
                    stayPropList[propId].value = stayPropList[propId].value + val
                    stayPropList[propId].time = buff.initTime
                end
            end
        end
    end
    for id, prop in pairs(stayPropList) do
        if prop.value ~= 0 then
            table.insert(propList, prop)
        end
    end
    -- 步数buff属性计算
    for _, buff in ipairs(this.StepBuff) do
        if not buff.isDestroy and buff.type == 1 and buff.effectPara then
            for _, v in ipairs(buff.effectPara) do
                if v[2] ~= 0 then
                    local prop = {}
                    prop.id = v[1]
                    prop.value = v[2]
                    prop.step = buff.leftStep
                    prop.totalStep = buff.totalStep
                    prop.time = buff.initTime
                    table.insert(propList, prop)
                end
            end
        end
    end
    -- 按时间排序
    table.sort(propList, function(a, b)
        return a.time < b.time
    end)
    return propList
end

return this