--- 删除事件点
local BHDeletePoint = {}
local this = BHDeletePoint

function this.Excute(arg, func)
    local pos = arg.pos

    if not pos then
        for i = 1, #arg.pointID do
            local pointID = arg.pointID[i]
            if pointID then
                for i, v in pairs(MapManager.mapPointList) do
                    if v == pointID then
                        Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, i)
                    end
                end
               
            end
        end
    else
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, pos)
    end
    --if not pos then
    
    --    return
    --end
    --Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, pos)
    if func then func() end
end

return this