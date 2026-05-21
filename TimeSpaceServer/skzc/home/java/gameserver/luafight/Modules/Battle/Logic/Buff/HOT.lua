HOT = Buff:New()

--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function HOT:SetData(...)

    self.interval,
    self.healValue = ...

    -- 刷新排序等级
    self.sort = 1   -- 最先计算回血

    self.isBuff = true
end

--初始化后调用一次
function HOT:OnStart()

    self.target.Event:DispatchEvent(BattleEventName.RoleBeHealed, self.caster)
end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function HOT:OnTrigger()

    if not self.target.ctrl_noheal or self.target:IsDead() then --禁疗和死亡无法加血
        BattleUtil.ApplyTreat(self.caster, self.target, self.healValue)
    end
    return true
end

--效果结束时调用一次
function HOT:OnEnd()

end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function HOT:OnCover(newBuff)

    return true
end

return HOT