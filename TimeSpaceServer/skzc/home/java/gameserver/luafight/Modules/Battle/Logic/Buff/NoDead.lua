NoDead = Buff:New()

--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function NoDead:SetData(...)
    self.damageFactor, 
    self.factorCT,
    self.isCanRelive = ...   -- buff期间的增伤系数
    self.cover = true --控制效果可被覆盖
    -- 刷新排序等级
    self.sort = 4
end

-- 伤害降低
function NoDead:onPassiveDamaging(func, target, damage, skill)
    if skill and skill.type == BattleSkillType.Special then
        local dd = BattleUtil.CountValue(damage, self.damageFactor, self.factorCT) - damage
        if func then func(-math.floor(BattleUtil.ErrorCorrection(dd))) end
    end
end

--初始化后调用一次
function NoDead:OnStart()
    -- 
    self.target.Event:AddEvent(BattleEventName.PassiveDamaging, self.onPassiveDamaging, self)
    self.target:SetDeadFilter(false)
    
    self.target:SetReliveFilter(self.isCanRelive)

    self.target:SetIsCanAddSkill(false)
end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function NoDead:OnTrigger()
    return true
end

--效果结束时调用一次
function NoDead:OnEnd()
    self.target.Event:AddEvent(BattleEventName.PassiveDamaging, self.onPassiveDamaging, self)
    self.target:SetDeadFilter(true)

    -- self.target:SetIsCanAddSkill(false)
end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function NoDead:OnCover(newBuff)

    return true
end

-- 比较buff
function NoDead:OnCompare(buff)
    return true
end


return NoDead