---
--- 采矿暴击率
---     TODO: 未找到使用
---
local ExploreFunc_DigCrit = {}
local this = ExploreFunc_DigCrit
-- buff开始回调
function this:Start(crit)
    if crit then
        MapManager.digcrit = MapManager.digcrit + crit
    end
end

-- buff结束时,减去增益
function this:End(crit)
    if crit then
        MapManager.digcrit = MapManager.digcrit - crit
    end
end

return this