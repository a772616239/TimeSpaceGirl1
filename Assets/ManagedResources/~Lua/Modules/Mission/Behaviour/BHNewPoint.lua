--- 删除事件点
local BHNewPoint = {}
local this = BHNewPoint

function this.Excute(arg, func)
    local pointList = arg.pointList
    local startIndex = arg.startIndex or 1
    local dynamicPoints = arg.dynamicPoints



    if not dynamicPoints or #dynamicPoints == 0 then
        -- 一般生成点的方式
        for i = startIndex, #pointList do
            local point = pointList[i]
            local mapId = point[1]
            --if mapId == MapManager.curMapId then
            local u = point[2]
            local v = point[3]
            local mapPointID = point[4]
            local pos = u * 256 + v
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointAdd, pos, mapPointID)
            --end
        end
    else
        -- 动态生成点的方式
        for i=1, #dynamicPoints do
            local cell = dynamicPoints[i]
            MapManager.mapPointList[cell.cellId] = cell.pointId

            Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointAdd, cell.cellId, cell.pointId)
        end
    end

    if func then func() end
end

return this