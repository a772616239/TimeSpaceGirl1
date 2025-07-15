EliteMonsterManager = {}
local this = EliteMonsterManager

function this.Initialize()
end

-- 设置精英怪数据
function this.SetEliteData(monsterId, endTime, findMapId)
    this.MonsterId = monsterId
    this.EndTime = endTime
    this.MapId = findMapId
end

-- 判断是否遇到了精英怪
function this.HasEliteMonster()
    -- 判断怪
    if not this.MonsterId or this.MonsterId == 0 then
        return false
    end
    -- 判断时间
    if this.GetLeftTime() == 0 then
        return false
    end
    return true
end

-- 获取当前的怪物id
function this.GetMonsterGroupId()
    if this.HasEliteMonster() then
        return this.MonsterId
    end
    return
end

-- 获取精英怪剩余时间
function this.GetLeftTime()
    -- 判断是否有精英怪
    if not this.EndTime then
        return 0
    end
    -- 判断是否已经过时
    local curTimeStamp = GetTimeStamp()
    if curTimeStamp >= this.EndTime then
        return 0
    end
    -- 返回剩余时间
    return this.EndTime - curTimeStamp
end

-- 清楚精英怪
function this.ClearEliteMonster()
    this.MonsterId = 0
    this.EndTime = 0
    this.MapId = 0
end


return this