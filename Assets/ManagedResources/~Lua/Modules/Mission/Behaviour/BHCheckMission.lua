--- 移动
local BHMoveTo = {}
local this = BHMoveTo

function this.Excute(arg, func)
    local mission = arg.mission
    local drop = arg.drop
    local isMissionDone = MissionManager.MainMissionIsDone(mission.itemId)
    if isMissionDone then
        Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnMissionEnd, mission)
        if #drop.itemlist > 0 or #drop.equipId > 0 or #drop.Hero > 0 then
            --UIManager.OpenPanel(UIName.MissionRewardPanel, drop, 2)
            UIManager.OpenPanel(UIName.RewardItemPopup, drop, 2, nil, 2)
        end
    end
    if func then func() end
end

return this