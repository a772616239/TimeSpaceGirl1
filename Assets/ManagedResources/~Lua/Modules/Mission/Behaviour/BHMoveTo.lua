--- 移动
local BHMoveTo = {}
local this = BHMoveTo

function this.Excute(arg, func)
    local mapID = arg.mapID
    local point = arg.point
    if not point and arg.u and arg.v then
        point = arg.u * 256 + arg.v
    end
    
    --if mapID and mapID ~= MapManager.curMapId then
    --    Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out, mapID)
    --end
    if point then
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.Transport, point)
    end
    if func then func() end
end

return this