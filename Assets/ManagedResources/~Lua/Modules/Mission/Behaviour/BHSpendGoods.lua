--- 消耗物品
local BHSpendGoods = {}
local this = BHSpendGoods

function this.Excute(arg, func)
    local itemList = arg.itemList
    for _, v in ipairs(itemList) do
        local itemId = v[1]
        local count = v[2]
        BagManager.SpendBagItem(itemId, count)
    end
    if func then func() end
end

return this