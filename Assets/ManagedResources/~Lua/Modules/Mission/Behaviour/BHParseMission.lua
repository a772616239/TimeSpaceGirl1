--- 新增任务
local BHParseMission = {}
local this = BHParseMission

function this.Excute(arg, func)
    local mission = arg.mission
    local isInit = arg.isInit or false
    local drop = arg.drop
    if not mission then return end
    MissionManager.ParseMissionState(mission, isInit)
    -- 判断任务是否完成
    local isMissionDone = MissionManager.MainMissionIsDone(mission.itemId)
    if not isMissionDone then
        -- 继续下一节点
        if func then func() end
        return
    end
    if OptionBehaviourManager.CurTriggerPanel then
        OptionBehaviourManager.CurTriggerPanel.gameObject:SetActive(false)
    end
    -- 任务结束
    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnMissionEnd, mission)
    if #drop.itemlist > 0 or #drop.equipId > 0 or #drop.Hero > 0 then
        --UIManager.OpenPanel(UIName.MissionRewardPanel, drop, 2, function()
        UIManager.OpenPanel(UIName.RewardItemPopup, drop, 2, function()
            -- 继续下一节点
            if func then func() end
        end, 2)
    else
        -- 继续下一节点
        if func then func() end
    end
end

return this