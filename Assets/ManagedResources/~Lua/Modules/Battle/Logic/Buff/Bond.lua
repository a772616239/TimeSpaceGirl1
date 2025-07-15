Bond = Buff:New()

--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function Bond:SetData(...)
    self.sort = 2
    self.damageFactor = ...
    LogError(self.damageFactor)
end

--初始化后调用一次
function Bond:OnStart()
    BattleLogic.Event:AddEvent(BattleEventName.TriggerBeDamaging, self.ShareDamageTrigger, self)
end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function Bond:OnTrigger()
end

--效果结束时调用一次
function Bond:OnEnd()
    BattleLogic.Event:RemoveEvent(BattleEventName.TriggerBeDamaging, self.ShareDamageTrigger, self)
end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function Bond:OnCover(newBuff)
    return true
end

function Bond:ShareDamageTrigger(damagingFunc, atkRole, defRole, damage, skill, dotType, bCrit, damageType)
    LogError(math.floor(damage*self.damageFactor))
    -- BattleUtil.ApplyDamage(skill, atkRole, defRole, 100)--math.floor(damage*self.damageFactor))
end

return Bond