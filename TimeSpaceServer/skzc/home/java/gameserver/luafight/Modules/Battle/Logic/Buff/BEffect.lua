BEffect = Buff:New()

--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function BEffect:SetData(...)

    self.bEffectType,
    self.startFunc,
    self.endFunc = ...
    self.cover = true

    -- 刷新排序等级
    self.sort = 4
end

--初始化后调用一次
function BEffect:OnStart()
    if self.startFunc then
        self.startFunc()
        self.startFunc = nil
    end
end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function BEffect:OnTrigger()

    return true
end

--效果结束时调用一次
function BEffect:OnEnd()

    if self.endFunc then
        self.endFunc()
        self.endFunc = nil
    end
end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function BEffect:OnCover(newBuff)

    return true
end

-- 比较buff
function BEffect:OnCompare(buff)
    return true
end

return BEffect