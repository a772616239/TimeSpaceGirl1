---
--- 视野范围buff
---
local ExploreFunc_ViewSize = {}
local this = ExploreFunc_ViewSize
this.funcType = 2

-- buff开始回调
function this:Start(viewSize)
    if viewSize then
        -- 视野范围改变
        MapManager.fogSize = MapManager.fogSize + viewSize
        -- 立即刷新一次视野范围
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.MapDataChange, this.funcType)
    end
end

-- buff结束时,视野范围回到默认值
function this:End(viewSize, defaultValue)
    -- 设置默认值
    if viewSize then
        MapManager.fogSize = MapManager.fogSize - viewSize
        return
    end
    MapManager.fogSize = defaultValue
end

return this