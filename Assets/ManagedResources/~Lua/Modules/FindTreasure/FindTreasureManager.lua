FindTreasureManager = {};
local this = FindTreasureManager
local allMissionUpHeros = {}
this.refreshTicketItemId = ConfigManager.GetConfigData(ConfigName.MazeTreasureSetting,1).TakeOrder[1]--83迷宫寻宝免费刷新次数
this.FindTreasureGaoId = 81--高级寻宝
this.FindTreasureHaoId = 82--豪华寻宝
this.materialItemId = 79--情报（Language 1010671）。注意：不是「寻龙玦」，全表没有这个道具名
--寻宝特权引导红点：按账号 + 按天（服务器 5 点刷新）只亮一次。
--以前是模块级变量 `isShowFindTreasureVipRedPoint = true`，不落盘不按天重置 ⇒ 每次启动必亮一颗指向充值页的红点。
local kFindTreasureVipRedKey = "FindTreasureVipRed"
local function GetVipRedPrefKey()
    return tostring(PlayerManager.uid or 0) .. kFindTreasureVipRedKey
end
--与服务器 5 点刷新对齐的「天序号」
local function GetVipRedDayIndex()
    local t = PlayerManager.serverTime or GetTimeStamp()
    return math.floor((t - 5 * 3600) / 86400)
end
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
--🔴 这个红点只表达「有奖励可领」，必须与 FindTreasureMainPanel 里 getButton 的显隐口径一致（state == 1）。
--不要把下面两类混进来，否则就是「外面亮、点进去无奖可领」：
--  a) 情报数量 >= MazeTreasureMax：面板里只有派遣/刷新，没有「领取」（原分支 2，已移除）
--  b) 寻宝特权引导：落点是 FindTreasureVipPopup -> GoJump -> 充值面板（原分支 3，已移除）
--如需材料溢出提示，请在面板里给材料条加高亮/角标，不要挂在这颗红点上。
function this.RefreshFindTreasureRedPoint()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.FINDTREASURE) then
        return false
    end
    TaskManager.SetFindTreasureDataState()
    local missionInfo = TaskManager.GetTypeTaskList(TaskTypeDef.FindTreasure)
    if missionInfo == nil then
        return false
    end
    for i = 1, #missionInfo do
       if missionInfo[i].state == 1 then
           return true
        end
    end
    return false
end
function this.SetShowFindTreasureVipRedPoint(isShow)
    if isShow then
        PlayerPrefs.DeleteKey(GetVipRedPrefKey())
    else
        PlayerPrefs.SetString(GetVipRedPrefKey(), tostring(GetVipRedDayIndex()))
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.FindTreasure.RefreshFindTreasureRedPot)
    CheckRedPointStatus(RedPointType.SecretTer_FindTreasure)
end
function this.GetShowFindTreasureVipRedPoint()
    --当天没看过才亮（每天最多一次；点过 VIP 按钮 / 双特权都开了就记下当天）
    return PlayerPrefs.GetString(GetVipRedPrefKey(), "") ~= tostring(GetVipRedDayIndex())
end
return this