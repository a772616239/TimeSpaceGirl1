local FoodBuff = require("Modules/Map/FoodBuff/FoodBuff")
local foodbuff_fight = Inherit(FoodBuff)
local this = foodbuff_fight

-- 构造方法
function this:new(id, isWork)
    local o = {}
    this.__index = this
    setmetatable(o, this)
    o.ID = id
    o.IsWork = isWork
    o:ctor()
    return o
end

-- 持续buff，开始回调
function this:onStart()
    if not self.IsWork then return end
    for _, v in ipairs(self.effectPara) do
        -- 加血相关的属性要立即生效
        if GetProIndexByProId(v[1]) == 2 then
            MapManager.RefreshFormationProListVal(v[1], 1, v[2])
        end
    end
end

-- 持续buff，结束回调，取消buff效果
function this:onEnd()
    --for _, v in ipairs(self.effectPara) do
    --    MapManager.RefreshFormationProListVal(v[1], 0, v[2])
    --end
end



-- 如果是一次性触发的buff，回调此事件，本次副本永久性增加，
function this:onOnceBuff()
    if not self.IsWork then return end
    for _, v in ipairs(self.effectPara) do
        -- 加血相关的属性要立即生效
        if GetProIndexByProId(v[1]) == 2 then
            MapManager.RefreshFormationProListVal(v[1], 1, v[2])
        end
    end
end


return this