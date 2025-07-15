Aura = Buff:New()

--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function Aura:SetData(...)

    self.action = ...
    -- 刷新排序等级
    self.sort = 4
end

--初始化后调用一次
function Aura:OnStart()

end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function Aura:OnTrigger()

    if self.action then
        self.action(self.target)
    end
    return true
end

--效果结束时调用一次
function Aura:OnEnd()

end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function Aura:OnCover(newBuff)

    return true
end

return Aura