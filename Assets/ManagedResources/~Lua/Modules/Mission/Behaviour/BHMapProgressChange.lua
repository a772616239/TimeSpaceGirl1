--- 消耗物品
local BHMapProgressChange = {}
local this = BHMapProgressChange

function this.Excute(arg, func)
    local type = arg.type
    local curEventID = arg.curEventID
    local monsterID = arg.monsterID

    --对话界面打开的话，先关闭再抛事件
    if UIManager.IsOpen(UIName.MapOptionPanel) then
        local triggerCallBack
        triggerCallBack = function (panelType, panel)
            if panelType == UIName.MapOptionPanel then
                Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChange, type, curEventID, monsterID)
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    else
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChange, type, curEventID, monsterID)
    end

    if func then func() end
end

return this