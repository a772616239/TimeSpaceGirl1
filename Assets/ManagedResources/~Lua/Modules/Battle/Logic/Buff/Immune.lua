-- 免疫效果
Immune = Buff:New()

local immune0 = function(buff)
    return buff.type == BuffName.Control or buff.isDeBuff or buff.type == BuffName.DOT
end
local immune1 = function(buff)
    return buff.type == BuffName.Control
end
local immune2 = function(buff)
    return buff.type == BuffName.DOT
end
local immune3 = function(buff)
    return buff.type == BuffName.Shield and buff.shieldType == ShieldTypeName.AllReduce
end

--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function Immune:SetData(...)

    self.immuneType = ...
    self.isBuff = true
    self.IsOnlyImmune = false --唯一免疫不叠加
    -- 刷新排序等级
    self.sort = 4
end

--初始化后调用一次
function Immune:OnStart()  
    if self.IsOnlyImmune then
        local immune
        if self.immuneType == 0 then --免疫负面状态（控制状态、减益状态和持续伤害状态）
            immune = immune0
        elseif self.immuneType == 1 then --免疫控制状态
            immune = immune1
        elseif self.immuneType == 2 then --免疫dot
            immune = immune2
        elseif self.immuneType == 3 then --免疫无敌盾
            immune = immune3
        end
        for i = 1, self.target.buffFilter.size do
            if self.target.buffFilter.buffer[i] == immune then
                self.target.buffFilter:Remove(i)
                break
            end
        end
    end
    if self.immuneType == 0 then --免疫负面状态（控制状态、减益状态和持续伤害状态）
        self.target.buffFilter:Add(immune0)
    elseif self.immuneType == 1 then --免疫控制状态
        self.target.buffFilter:Add(immune1)
    elseif self.immuneType == 2 then --免疫dot
        self.target.buffFilter:Add(immune2)
    elseif self.immuneType == 3 then --免疫无敌盾
        self.target.buffFilter:Add(immune3)
    end
end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function Immune:OnTrigger()
    return true
end

function Immune:OnImmuneTrigger()
    self.target.Event:DispatchEvent(BattleEventName.ImmuneTrigger, self)
    BattleLogic.Event:DispatchEvent(BattleEventName.ImmuneTrigger, self)
end

--效果结束时调用一次
function Immune:OnEnd()
    local immune
    if self.immuneType == 0 then --免疫负面状态（控制状态、减益状态和持续伤害状态）
        immune = immune0
    elseif self.immuneType == 1 then --免疫控制状态
        immune = immune1
    elseif self.immuneType == 2 then --免疫dot
        immune = immune2
    elseif self.immuneType == 3 then --免疫无敌盾
        immune = immune3
    end
    for i = 1, self.target.buffFilter.size do
        if self.target.buffFilter.buffer[i] == immune then
            self.target.buffFilter:Remove(i)
            -- LogError("removed1!!!")
            break
        end
    end
end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function Immune:OnCover(newBuff)

    return true
end

-- 比较buff
function Immune:OnCompare(buff)
    return buff.immuneType == self.immuneType
end

return Immune