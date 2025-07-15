--- 触发战斗
local BHBattle = {}
local this = BHBattle

function this.Excute(arg, nextFunc, doneFunc)
    local monsterID = arg.monsterID
    MapManager.MapBattleExecute(monsterID, nil, function (result)
        if doneFunc then doneFunc(result.eventId) end
        if nextFunc then nextFunc(result) end
    end)
end
return this