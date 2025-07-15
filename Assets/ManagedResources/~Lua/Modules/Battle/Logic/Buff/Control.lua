Control = Buff:New()

--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function Control:SetData(...)

    self.ctrlType = ...
    self.cover = true --控制效果可被覆盖
    -- 刷新排序等级
    self.sort = 4

    self.isDeBuff = true
end

--初始化后调用一次
function Control:OnStart()

    if self.ctrlType == 1 then --眩晕
        self.target.ctrl_dizzy = true
    elseif self.ctrlType == 2 then --沉默
        self.target.ctrl_slient = true
    elseif self.ctrlType == 3 then --嘲讽（包括沉默）
        self.target.lockTarget = self.caster
        self.target.ctrl_slient = true
    elseif self.ctrlType == 4 then --禁疗
        self.target.ctrl_noheal = true
    elseif self.ctrlType == 5 then --致盲
        self.target.ctrl_blind = true
        
    elseif self.ctrlType == 7 then --麻痹
        self.target.ctrl_palsy = true
    elseif self.ctrlType == 8 then  --< 冰冻
        self.target.ctrl_frozen = true
        self.frozen_beHitTimes = 0
        self.onRoleBeHit = function(caster)
            self.frozen_beHitTimes = self.frozen_beHitTimes + 1
            if self.frozen_beHitTimes == 3 then
                BattleLogic.BuffMgr:ClearBuff(self.target, function(buff)
                    return buff.type == BuffName.Control and buff.ctrlType == ControlType.Frozen
                end)
            end
        end
        self.target.Event:AddEvent(BattleEventName.RoleBeHit, self.onRoleBeHit)
    elseif self.ctrlType == 9 then  --< 混乱
        self.target.ctrl_chaos = true
    elseif self.ctrlType == 10 then  --< 封印
        self.target.ctrl_seal = true
    end

    self.target.ctrltimes = self.target.ctrltimes + 1
end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function Control:OnTrigger()

    return true
end

--效果结束时调用一次
function Control:OnEnd()

    if self.ctrlType == 1 then --眩晕
        self.target.ctrl_dizzy = false
    elseif self.ctrlType == 2 then --沉默
        self.target.ctrl_slient = false
    elseif self.ctrlType == 3 then --嘲讽（包括沉默）
        self.target.lockTarget = nil
        self.target.ctrl_slient = false
    elseif self.ctrlType == 4 then --禁疗
        self.target.ctrl_noheal = false
    elseif self.ctrlType == 5 then --致盲
        self.target.ctrl_blind = false

    elseif self.ctrlType == 7 then --麻痹
        self.target.ctrl_palsy = false
    elseif self.ctrlType == 8 then  --< 冰冻
        self.target.ctrl_frozen = false
        self.target.Event:RemoveEvent(BattleEventName.RoleBeHit, self.onRoleBeHit)
    elseif self.ctrlType == 9 then  --< 混乱
        self.target.ctrl_chaos = false
    elseif self.ctrlType == 10 then  --< 封印
        self.target.ctrl_seal = false
    end
end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function Control:OnCover(newBuff)

    -- LogError("new:"..newBuff.duration.." old:"..self.duration)
    if newBuff.ctrlType == self.ctrlType then 
        if newBuff.duration < self.duration then
            newBuff.duration = self.duration
            newBuff.roundDuration  = self.roundDuration
        end
        if newBuff.ctrlType == 8 then --冰冻 击碎次数不刷新
            newBuff.frozen_beHitTimes = self.frozen_beHitTimes 
        end
    end
    return newBuff.ctrlType == self.ctrlType
end

-- 比较buff
function Control:OnCompare(buff)
    return self.ctrlType == buff.ctrlType
end


return Control