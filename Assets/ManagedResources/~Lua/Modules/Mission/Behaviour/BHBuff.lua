--- 吃buff
local BHBuff = {}
local this = BHBuff

function this.Excute(arg, func)
    -- Buff id
    local id = arg.buffID
    if id ~= 0 then
        -- 初始化buff数据
        FoodBuffManager.CreateFoodBuff(id, true, true)
    end
    if func then func() end
end

return this