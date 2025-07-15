---
--- 移动速度buff
---
local ExploreFunc_MoveSpeed = {}
local this = ExploreFunc_MoveSpeed

-- buff开始回调
function this:Start(moveSpeed)
    if moveSpeed then
        MapManager.leaderMoveSpeed = MapManager.leaderMoveSpeed + moveSpeed
    end
end

-- buff结束时回到默认
function this:End(moveSpeed)
    if moveSpeed then
        MapManager.leaderMoveSpeed = MapManager.leaderMoveSpeed - moveSpeed
    end
end

return this