Brand = Buff:New()

--初始化Buff，通过传入一些自定义参数控制成长相关的数值
function Brand:SetData(...)

    self.flag, self.endFunc = ... --标记，结束回调
    self.cover = true
    self.layer = 1
    self.maxLayer = 0
    -- 刷新排序等级
    self.sort = 4
end

--初始化后调用一次
function Brand:OnStart()

end

--间隔N帧触发，返回true时表示继续触发，返回false立刻触发OnEnd
function Brand:OnTrigger()

    return true
end

--效果结束时调用一次
function Brand:OnEnd()

    if self.endFunc then
        self.endFunc()
        self.endFunc = nil
    end
    self.coverFunc = nil
end

--只有当cover字段为true时触发，返回true则被新效果覆盖
function Brand:OnCover(newBuff)

    local b = newBuff.flag == self.flag
    if b then
        if newBuff.maxLayer == 0 then
            newBuff.layer = newBuff.layer + self.layer
        else
            newBuff.layer = math.min(newBuff.layer + self.layer, newBuff.maxLayer)
        end
        if newBuff.coverFunc then
            newBuff.coverFunc(self)
        end
    end
    return b
end

-- 比较buff
function Brand:OnCompare(buff)
    return buff.flag == self.flag
end
return Brand   