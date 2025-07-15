--- 显示奖励
local BHShowReward = {}
local this = BHShowReward

function this.Excute(arg, func)
    local drop = arg.drop
    if drop then
        if #drop.itemlist > 0 or #drop.equipId > 0 or #drop.Hero > 0 then
            UIManager.OpenPanel(UIName.RewardItemPopup, drop, 2, function ()
                if func then func() end
            end)
            return
        end
    end
    if func then func() end
end

return this