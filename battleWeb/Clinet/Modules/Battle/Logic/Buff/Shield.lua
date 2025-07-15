Shield = Buff:New()
-- 无敌吸血盾的免疫状态
local immune0 = function(buff)
    return buff.type == BuffName.Control or buff.isDeBuff or buff.type == BuffName.DOT
end
--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function Shield:SetData(...)

    self.shieldType,    -- 护盾类型(1 固定减伤盾    2 百分比减伤盾     3 无敌盾)
    self.shieldValue,   -- 护盾值（固定减伤盾：减伤值    百分比减伤盾：减伤百分比   无敌盾：吸血率）
    self.dmgReboundFactor = ... --伤害反弹系数
    self.damageSum = 0 --记录承受的伤害
    self.isBuff = true
    self.atk=nil --每次扣除护盾时，记录破盾的对象
    self.isValueCover = false  --是否是护盾值对比覆盖
    
    self.cover = self.shieldType ~= ShieldTypeName.NormalReduce   -- 除固定减伤盾外都不能叠加
    -- 刷新排序等级
    self.sort = 4
end

--初始化后调用一次
function Shield:OnStart()

    self.target.shield:Add(self)
    if self.shieldType == ShieldTypeName.AllReduce then
        self.target.buffFilter:Add(immune0)
        -- 清除所有负面buff
        BattleLogic.BuffMgr:ClearBuff(self.target, function (buff)
            return buff.type == BuffName.Control or buff.type == BuffName.DOT
        end)
    end
end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function Shield:OnTrigger()

    return true
end

-- 计算护盾
function Shield:CountShield(damage, atkRole)
    self.atk = atkRole
    local finalDamage = 0
    if self.shieldType == ShieldTypeName.NormalReduce then

        if damage < self.shieldValue then
            self.shieldValue = self.shieldValue - damage
            self.damageSum = self.damageSum + damage
        else
            self.damageSum = self.damageSum + self.shieldValue
            finalDamage = damage - self.shieldValue
            self.shieldValue = 0
            self.disperse = true
        end

    elseif self.shieldType == ShieldTypeName.RateReduce then
        local reduceDamage = math.floor(BattleUtil.ErrorCorrection(damage * self.shieldValue))
        finalDamage = damage - reduceDamage
        self.damageSum = self.damageSum + reduceDamage

    elseif self.shieldType == ShieldTypeName.AllReduce then
        finalDamage = 0
        --TODO  计算吸血 
        if self.shieldValue ~= 0 then
            local treatValue = math.floor(BattleUtil.ErrorCorrection(damage * self.shieldValue))
            BattleUtil.ApplyTreat(self.target, self.target, treatValue)
        end
    end

    -- 
    -- self.caster.Event:DispatchEvent(BattleEventName.ShildTrigger, self)
    self.target.Event:DispatchEvent(BattleEventName.ShildTrigger, self)
    BattleLogic.Event:DispatchEvent(BattleEventName.ShildTrigger, self)

    return math.floor(finalDamage)
end
-- 提前计算护盾吸收伤害
function Shield:PreCountShield(damage)
    local finalDamage = 0
    if self.shieldType == ShieldTypeName.NormalReduce then
        if damage > self.shieldValue then
            finalDamage = damage - self.shieldValue
        end
    elseif self.shieldType == ShieldTypeName.RateReduce then
        local reduceDamage = math.floor(BattleUtil.ErrorCorrection(damage * self.shieldValue))
        finalDamage = damage - reduceDamage

    elseif self.shieldType == ShieldTypeName.AllReduce then
        finalDamage = 0
    end
    return math.floor(finalDamage)
end


-- 改变护盾值（固定减伤盾：减伤值    百分比减伤盾：减伤百分比   无敌盾：吸血率）
function Shield:ChangeShieldValue(type, value)
    -- 计算
    local finalValue = BattleUtil.ErrorCorrection(BattleUtil.CountValue(self.shieldValue, value, type))
    self.shieldValue = finalValue
    -- 发送事件
    self.caster.Event:DispatchEvent(BattleEventName.ShildValueChange, self)
end

--效果结束时调用一次
function Shield:OnEnd()

    -- 计算反伤
    if self.shieldType == ShieldTypeName.NormalReduce then
        for i = 1, self.target.shield.size do
            if self.target.shield.buffer[i] == self then
                local dd = math.floor(self.dmgReboundFactor * self.damageSum)
                if dd > 0 and self.atk then
                    BattleUtil.ApplyDamage(nil, self.target, self.atk, dd)
                end
                -- local arr = RoleManager.Query(function (r) return r.camp ~= self.target.camp end)
                -- for j = 1, #arr do
                -- end
                self.target.shield:Remove(i)
                break
            end
        end

    elseif self.shieldType == ShieldTypeName.RateReduce then
        for i = 1, self.target.shield.size do
            if self.target.shield.buffer[i] == self then
                self.target.shield:Remove(i)
                break
            end
        end

    elseif self.shieldType == ShieldTypeName.AllReduce then
        for i = 1, self.target.shield.size do
            if self.target.shield.buffer[i] == self then
                self.target.shield:Remove(i)
                break
            end
        end
        -- 移除免疫效果
        for i = 1, self.target.buffFilter.size do
            if self.target.buffFilter.buffer[i] == immune0 then
                self.target.buffFilter:Remove(i)
                break
            end
        end
    end
end

--比较护盾值
function Shield:OnCompareShielValue(buff)
    return self.shieldValue < buff.shieldValue
end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function Shield:OnCover(newBuff)
    return true      
end

-- 比较buff
function Shield:OnCompare(buff)
    return self.shieldType == buff.shieldType
end

return Shield