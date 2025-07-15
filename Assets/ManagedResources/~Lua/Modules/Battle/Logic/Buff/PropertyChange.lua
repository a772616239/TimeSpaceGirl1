PropertyChange = Buff:New()

--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function PropertyChange:SetData(...)

    self.propertyName,
    self.Value,
    self.changeType,
    self.propertyChangeType = ...   --< 属性状态
    self.cover = false --
    self.layer = 1
    self.maxLayer = 0
    self.probability = 0    --< 特殊概率
    self.probaFrozenFix = 0    --< 冰封结界修订参数
    -- LogError("propertyName "..self.propertyName.." changeType"..self.changeType.." propertyChangeType"..self.propertyChangeType)
    if self.changeType == 1 then --加算
        self.isBuff = true
        if  self.Value < 0 then 
            self.isBuff =false
            self.isDeBuff = true
        else
            self.isBuff=true
            self.isDeBuff=false
        end
    elseif self.changeType == 2 then --乘加算（百分比属性加算）
        self.isBuff = true
        self.isDeBuff =false
    elseif self.changeType == 3 then --减算
        self.isDeBuff = true
        if  self.Value < 0 then 
            self.isDeBuff =false
            self.isBuff = true
        else
            self.isBuff =false
            self.isDeBuff=true
        end
    elseif self.changeType == 4 then --乘减算（百分比属性减算）
        self.isDeBuff = true
        self.isBuff =false
    end
    -- 刷新排序等级
    self.sort = 4
    self.isEveryRound = false
end

--初始化后调用一次
function PropertyChange:OnStart()
    BattleLogManager.Log(
        "propstart",
        "self.propertyName:",self.propertyName
    )
    if self.changeType == 1 then --加算
        self.delta = self.target.data:AddValue(self.propertyName, self.Value)
    elseif self.changeType == 2 then --乘加算（百分比属性加算）
        self.delta = self.target.data:AddPencentValue(self.propertyName, self.Value)
    elseif self.changeType == 3 then --减算
        self.delta = self.target.data:SubValue(self.propertyName, self.Value)
    elseif self.changeType == 4 then --乘减算（百分比属性减算）
        self.delta = self.target.data:SubPencentValue(self.propertyName, self.Value)
    end


    --> 4 冰封结界（修改22攻击加成，如果BUFF自然消失50%概率在下回合开始直接对其冰冻1回合）
    if self.propertyName == RoleDataName.AttackAddition and self.propertyChangeType == PropertyChangeType.Icebound then
        self.probability  = 0.5

        local OnBuffPropertyChangeIcebound = function(_probability)
            self.probability = self.probability - _probability
        
            if self.probability + self.probaFrozenFix >= 1 then
                self.disperse = true
                BattleUtil.RandomControl(1, ControlType.Frozen, self.caster, self.target, 1)
            end
        end
        self.target.Event:AddEvent(BattleEventName.BuffPropertyChangeIcebound, OnBuffPropertyChangeIcebound)
    end
end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function PropertyChange:OnTrigger()
    if self.isEveryRound then
        self:OnStart()
    end
    return true
end

--效果结束时调用一次
--> isPass 是否过期调用
function PropertyChange:OnEnd(isPass)

    if self.changeType == 3 or self.changeType == 4 then
        self.target.data:AddValue(self.propertyName, self.delta)
    else
        self.target.data:SubDeltaValue(self.propertyName, self.delta)
    end

    --> 冰封触发冰冻    4 冰封结界（修改22攻击加成，如果BUFF自然消失50%概率在下回合开始直接对其冰冻1回合）
    if isPass and self.propertyName == RoleDataName.AttackAddition and self.propertyChangeType == PropertyChangeType.Icebound then
        BattleUtil.RandomControl(self.probability + self.probaFrozenFix, ControlType.Frozen, self.caster, self.target, 1)
    end
end

--只有当Cover字段为true时触发，返回true则被新效果覆盖
function PropertyChange:OnCover(newBuff)

    local b = self:OnCompare(newBuff)
    if b then
        if newBuff.maxLayer == 0 then
            newBuff.layer = newBuff.layer + self.layer
            newBuff.Value = newBuff.Value + self.Value
        else
            if self.layer < newBuff.maxLayer then
                newBuff.Value = newBuff.Value + self.Value
            else
                newBuff.Value = self.Value
            end
            newBuff.layer = math.min(newBuff.layer + self.layer, newBuff.maxLayer)
        end
    end
    return b
end

-- 不叠加增加数量
-- 只有当Cover字段为true时触发，返回true则被新效果覆盖 且数值不会叠加 
-- 仅在层数一样的时候
function PropertyChange:SetAsOnly(maxlayerid)
    if self.isCover then
        self.layer=maxlayerid
    end
end 

-- 比较buff
function PropertyChange:OnCompare(buff)
    return self.changeType == buff.changeType and self.propertyName == buff.propertyName and self.duration == buff.duration and self.propertyChangeType == buff.propertyChangeType
end

return PropertyChange