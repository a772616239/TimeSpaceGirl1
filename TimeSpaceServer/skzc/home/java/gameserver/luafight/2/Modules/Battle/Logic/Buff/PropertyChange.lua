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

    if self.changeType == 1 then --加算
        self.isBuff = true
    elseif self.changeType == 2 then --乘加算（百分比属性加算）
        self.isBuff = true
    elseif self.changeType == 3 then --减算
        self.isDeBuff = true
    elseif self.changeType == 4 then --乘减算（百分比属性减算）
        self.isDeBuff = true
    end
    -- 刷新排序等级
    self.sort = 4

    self.isEveryRound = false
end

--初始化后调用一次
function PropertyChange:OnStart()

    if self.changeType == 1 then --加算
        self.delta = self.target.data:AddValue(self.propertyName, self.Value)
    elseif self.changeType == 2 then --乘加算（百分比属性加算）
        self.delta = self.target.data:AddPencentValue(self.propertyName, self.Value)
    elseif self.changeType == 3 then --减算
        self.delta = self.target.data:SubValue(self.propertyName, self.Value)
    elseif self.changeType == 4 then --乘减算（百分比属性减算）
        self.delta = self.target.data:SubPencentValue(self.propertyName, self.Value)
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
function PropertyChange:OnEnd()

    if self.changeType == 3 or self.changeType == 4 then
        self.target.data:AddValue(self.propertyName, self.delta)
    else
        self.target.data:SubDeltaValue(self.propertyName, self.delta)
    end

    --> 冰封触发冰冻
    if self.propertyChangeType == 4 then
        
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

-- 比较buff
function PropertyChange:OnCompare(buff)
    return self.changeType == buff.changeType and self.propertyName == buff.propertyName and self.duration == buff.duration
end

return PropertyChange   