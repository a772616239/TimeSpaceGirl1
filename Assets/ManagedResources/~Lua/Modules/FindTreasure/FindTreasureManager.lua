FindTreasureManager = {};
local this = FindTreasureManager
local allMissionUpHeros = {}
this.refreshTicketItemId = ConfigManager.GetConfigData(ConfigName.MazeTreasureSetting,1).TakeOrder[1]--83迷宫寻宝免费刷新次数
this.FindTreasureGaoId = 81--高级寻宝
this.FindTreasureHaoId = 82--豪华寻宝
this.materialItemId = 79--寻龙玦
this.isShowFindTreasureVipRedPoint = true
function this.Initialize()
    allMissionUpHeros = {}
    Game.GlobalEvent:AddEvent(GameEvent.FiveAMRefresh.ServerNotifyRefresh, this.RefreshUsedTimes)
end
function this.GetAllUpHeros()
    allMissionUpHeros = {}
    this.RefreshAllMissionUpHeros()
   
    return allMissionUpHeros
end
function this.RefreshAllMissionUpHeros()
    local missionInfo = TaskManager.GetTypeTaskList(TaskTypeDef.FindTreasure)
    for i = 1, #missionInfo do
        for j = 1, #missionInfo[i].heroId do
            allMissionUpHeros[missionInfo[i].heroId[j]] = missionInfo[i].heroId[j]
           
        end
    end
end
function this.RefreshUsedTimes()
     PlayerManager.missingRefreshCount = PrivilegeManager.GetPrivilegeUsedTimes(ConfigManager.GetConfigData(ConfigName.MazeTreasureSetting,1).RefreshVIP)
    Game.GlobalEvent:DispatchEvent(GameEvent.FindTreasure.RefreshFindTreasure,true)
end
function this.RefreshFindTreasureRedPoint()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.FINDTREASURE) then
        return false
    end
    TaskManager.SetFindTreasureDataState()
    local missionInfo = TaskManager.GetTypeTaskList(TaskTypeDef.FindTreasure)
    for i = 1, #missionInfo do
       if missionInfo[i].state == 1 then
           return true
        end
    end
    local mazeTreasureMax = ConfigManager.GetConfigData(ConfigName.PlayerLevelConfig,PlayerManager.level).MazeTreasureMax
    if BagManager.GetItemCountById(FindTreasureManager.materialItemId) >= mazeTreasureMax then
        return true
    end
    if this.GetShowFindTreasureVipRedPoint() then
        return true
    end
    return false
end
function this.SetShowFindTreasureVipRedPoint(isShow)
    this.isShowFindTreasureVipRedPoint = isShow
    Game.GlobalEvent:DispatchEvent(GameEvent.FindTreasure.RefreshFindTreasureRedPot)
    CheckRedPointStatus(RedPointType.SecretTer_FindTreasure)
end
function this.GetShowFindTreasureVipRedPoint()
    return this.isShowFindTreasureVipRedPoint
end
return this