FightUnitManager = {}
local this = FightUnitManager

local removeObjList = BattleList.New()


local unitArray = {[FightUnitType.UnitSupport] = {}, [FightUnitType.UnitAircraftCarrier] = {}}

local unitPool = BattleObjectPool.New(function ()
    return FightUnitLogic.New()
end)


function this.Init()
    this.Clear()
end

function FightUnitManager.AddUnit(unitData)
    local unit = unitPool:Get()
    unit:Init(unitData)
    unitArray[unitData.type][unitData.camp] = unit


    BattleLogic.Event:DispatchEvent(BattleEventName.AddUnit, unit)
end

function FightUnitManager.GetUnit(type, camp)
    return unitArray[type][camp]
end

function this.Clear()
    for _, unitsByType in pairs(unitArray) do
        for _, unit in pairs(unitsByType) do
            unit:Dispose()
            removeObjList:Add(unit)
        end
    end
    unitArray = {[FightUnitType.UnitSupport] = {}, [FightUnitType.UnitAircraftCarrier] = {}}
    

    while removeObjList.size > 0 do
        unitPool:Put(removeObjList.buffer[removeObjList.size])
        removeObjList:Remove(removeObjList.size)
    end

end

return this   