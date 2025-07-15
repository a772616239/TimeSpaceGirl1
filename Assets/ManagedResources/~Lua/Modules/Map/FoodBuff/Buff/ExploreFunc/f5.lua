---
--- 行动力
---
local ExploreFunc_Active = {}
local this = ExploreFunc_Active

-- buff开始回调
function this:Start(active)
    -- 判断是否增加行动力
    if active then
        MapManager.leftStep = MapManager.leftStep + active
    end
end

--- buff结束时，减少相应的行动力
---TODO: 行动力应该是只增不减的，如果有特殊情况再处理
function this:End()
end

return this