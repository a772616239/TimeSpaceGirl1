DOT = Buff:New()

--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function DOT:SetData(...)

    self.interval,
    self.damageType, --1 燃烧 2 中毒 3 流血  4 灼烧
    self.damagePro, --1 物理 2 魔法  (真实伤害时 为伤害值)
    self.damageFactor = ... --伤害系数
    self.isRealDamage = false
    --if self.damageType == 2 then
    --    self.cover = true
    --    self.layer = 1
    --else
    --    self.cover = false
    --    self.layer = nil
    --end

    -- 刷新排序等级
    self.sort = 2
    if self.damageType == 3 then    -- 流血buff在行动之后刷新
        self.sort = 3
    end
end

--初始化后调用一次
function DOT:OnStart()
    if self.caster.isTeam then
        self.isRealDamage = true
    end
end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function DOT:OnTrigger()

    if self.isRealDamage then
        BattleUtil.ApplyDamage(nil, self.caster, self.target, self.damagePro, nil, nil, self.damageType)
    else
        BattleUtil.CalDamage(nil, self.caster, self.target, self.damagePro, self.damageFactor, 0, self.damageType)
    end
    return true
end

--效果结束时调用一次
function DOT:OnEnd()

end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function DOT:OnCover(newBuff)

    --if self.damageType == 2 then
    --    newBuff.layer = self.layer + 1
    --    newBuff.damageFactor =
    --end
    return true
end

-- 比较buff
function DOT:OnCompare(buff)
    return buff.damageType == self.damageType
end

return DOT   