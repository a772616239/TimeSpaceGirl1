FightUnitManager = {}
local this = FightUnitManager

local removeObjList = BattleList.New()


local unitArray = {[FightUnitType.UnitSupport] = {},
                   [FightUnitType.UnitAircraftCarrier] = {},
                   [FightUnitType.UnitAdjutant] = {}}

local unitPool = BattleObjectPool.New(function ()
    return FightUnitLogic.New()
end)


function this.Init()
    this.Clear()
end

function FightUnitManager.AddUnit(unitData)
    local unit = unitPool:Get()
    unit:Init(unitData)
    
    
    unitArray[tonumber(unitData.type)][tonumber(unitData.camp)] = unit

    BattleLogic.Event:DispatchEvent(BattleEventName.AddUnit, unit)
end

function FightUnitManager.GetUnit(type, camp)
    
    
    return unitArray[type][camp]
end

local _RoundBeginFrame = 2
local _RoundEndFrame = 2
local _RoundBeginCallBack = nil
local _RoundEndCallBack = nil
function FightUnitManager.UpdateRoundBegin()
    if _RoundBeginFrame == 2 then
        return
    end
    _RoundBeginFrame = _RoundBeginFrame + 1
    if _RoundBeginFrame == 2 then
        FightUnitManager.ProcessRoundBegin()
    end
end

function FightUnitManager.UpdateRoundEnd()
    if _RoundEndFrame == 2 then
        return
    end
    _RoundEndFrame = _RoundEndFrame + 1
    if _RoundEndFrame == 2 then
        FightUnitManager.ProcessRoundEnd()
    end
end

function FightUnitManager.ProcessRoundBeginNextFrame(func)
    _RoundBeginFrame = 0
    _RoundBeginCallBack = func
end

function FightUnitManager.ProcessRoundEndNextFrame(func)
    _RoundEndFrame = 0
    _RoundEndCallBack = func
end

function FightUnitManager.ProcessRoundBegin()
    --> 支援 等
    local processQueue = nil
    if RoleManager.GetFastCamp() == 0 then  --< 最快我方
        processQueue = {{FightUnitType.UnitAircraftCarrier, 0}, {FightUnitType.UnitSupport, 0}, {FightUnitType.UnitAircraftCarrier, 1}, {FightUnitType.UnitSupport, 1}}
    else
        processQueue = {{FightUnitType.UnitAircraftCarrier, 1}, {FightUnitType.UnitSupport, 1}, {FightUnitType.UnitAircraftCarrier, 0}, {FightUnitType.UnitSupport, 0}}
    end
    if processQueue == nil then
        LogError("### processQueue nil")
    end

    local index = 1
    local next = nil
    local processFunc = nil
    next = function()
        if index == #processQueue then
            if _RoundBeginCallBack then
                _RoundBeginCallBack()
            else
                LogError("### ProcessRoundBegin callback error")
            end
            -- func()
        else
            index = index + 1
            processFunc()
        end
    end

    processFunc = function()
        local unit = FightUnitManager.GetUnit(processQueue[index][1], processQueue[index][2])
        if not unit then
            next()
            return
        end
        -- local release = unit.skill[8].release
        -- local cd = unit.skill[8].cd
        
        -- local CurRound, MaxRound = BattleLogic.GetCurRound()
        -- if CurRound == release or (CurRound - release) % (cd + 1) == 0 then
        --     if unit then
                local haveSkill = unit:CastSkill(function()
                    next()
                end)
                if not haveSkill then
                    next()
                end
        --     else
        --         next()
        --     end
        -- else
        --     next()
        -- end
    end
    processFunc()
end

function FightUnitManager.ProcessRoundEnd()
    --> 支援 等
    local processQueue = nil
    if RoleManager.GetFastCamp() == 0 then  --< 最快我方
        processQueue = {{FightUnitType.UnitAdjutant, 0}, {FightUnitType.UnitAdjutant, 1}}
    else
        processQueue = {{FightUnitType.UnitAdjutant, 1}, {FightUnitType.UnitAdjutant, 0}}
    end
    if processQueue == nil then
        LogError("### processQueue nil")
    end

    local index = 1
    local next = nil
    local processFunc = nil
    next = function()
        if index == #processQueue then
            if _RoundEndCallBack then
                _RoundEndCallBack()
            else
                LogError("### ProcessRoundBegin callback error")
            end
            -- func()
        else
            index = index + 1
            processFunc()
        end
    end

    processFunc = function()
        local unit = FightUnitManager.GetUnit(processQueue[index][1], processQueue[index][2])
        if not unit then
            next()
            return
        end
        -- local release = unit.skill[8].release
        -- local cd = unit.skill[8].cd
        
        -- local CurRound, MaxRound = BattleLogic.GetCurRound()
        -- if CurRound == release or (CurRound - release) % (cd + 1) == 0 then
        --     if unit then
                local haveSkill = unit:CastSkill(function()
                    next()
                end)
                if not haveSkill then
                    next()
                end
        --     else
        --         next()
        --     end
        -- else
        --     next()
        -- end
    end
    processFunc()
end

function this.Clear()
     _RoundBeginFrame = 2
     _RoundEndFrame = 2
     _RoundBeginCallBack = nil
     _RoundEndCallBack = nil
    for _, unitsByType in pairs(unitArray) do
        for _, unit in pairs(unitsByType) do
            unit:Dispose()
            removeObjList:Add(unit)
        end
    end
    unitArray = {[FightUnitType.UnitSupport] = {},
                   [FightUnitType.UnitAircraftCarrier] = {},
                   [FightUnitType.UnitAdjutant] = {}}
    

    while removeObjList.size > 0 do
        unitPool:Put(removeObjList.buffer[removeObjList.size])
        removeObjList:Remove(removeObjList.size)
    end

end

return this