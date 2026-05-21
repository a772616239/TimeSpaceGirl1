Curse = Buff:New()


--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function Curse:SetData(curseType, ...)
    self.curseType = curseType 
    self.args = {...} --标记，结束回调
    self.cover = true

    -- 刷新排序等级
    self.sort = 4
end
-- 
function Curse:ShareDamageTrigger(damagingFunc, atkRole, defRole, damage, skill, dotType, bCrit, damageType)
    if skill and defRole.camp == self.target.camp then
        -- 没有此印记的队友收到伤害
        if not BattleLogic.BuffMgr:HasBuff(defRole, BuffName.Curse, function(buff) return buff.curseType == CurseTypeName.ShareDamage end) then
             -- 计算拥有此印记人的数量
            local sdList = RoleManager.Query(function(role)
                return role.camp == self.target.camp and BattleLogic.BuffMgr:HasBuff(role, BuffName.Curse, function(buff) return buff.curseType == CurseTypeName.ShareDamage end)
            end)
            if sdList and #sdList ~= 0 then
                -- 计算收到的伤害
                local f1 = self.args[1] --平分伤害的百分比
                local sd = math.floor(BattleUtil.ErrorCorrection(damage * f1 / #sdList))
                if sd ~= 0 then
                    BattleUtil.ApplyDamage(nil, atkRole, self.target, sd)
                end
            end
        end
    end
end


--初始化后调用一次
function Curse:OnStart()
    if self.curseType == CurseTypeName.ShareDamage then
        BattleLogic.Event:AddEvent(BattleEventName.FinalDamage, self.ShareDamageTrigger, self)
    end
end


--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function Curse:OnTrigger()
    return true
end

--效果结束时调用一次
function Curse:OnEnd()
    if self.curseType == CurseTypeName.ShareDamage then
        BattleLogic.Event:RemoveEvent(BattleEventName.FinalDamage, self.ShareDamageTrigger, self)
    end
end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function Curse:OnCover(newBuff)
    return self.curseType == newBuff.curseType
end

-- 比较buff
function Curse:OnCompare(buff)
    return self.curseType == newBuff.curseType
end
return Curse