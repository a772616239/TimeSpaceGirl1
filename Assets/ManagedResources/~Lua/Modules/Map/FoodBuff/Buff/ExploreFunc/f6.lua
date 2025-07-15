---
--- 驱散某区域迷雾
---
local ExploreFunc_ClearFog = {}
local this = ExploreFunc_ClearFog

-- buff开始回调
function this:Start(center, value)
    -- 计算驱散迷雾的数据
    local fogRange = value
    local fogCenter = MapManager.GetPosByMapPointId(center)
    if not fogCenter then

        return
    end
    --调用驱散迷雾的方法
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.DisperseFog, fogCenter, fogRange)
end

-- buff结束时
function this:End()

end

return this