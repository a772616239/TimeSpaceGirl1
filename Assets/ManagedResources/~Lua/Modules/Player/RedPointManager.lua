--[[
 * @Classname RedPointManager
 * @Description 红点控制
 * @Date 2019/5/18 10:48
 * @Created by MagicianJoker
--]]
require "Message/MessageTypeProto_pb"
require "Message/PlayerInfoProto_pb"

RedPointManager = {}
local this = RedPointManager

local RedPointData = {}
local BindObjs = {}

local ChallengeMapConfig = ConfigManager.GetConfig(ConfigName.ChallengeMapConfig)
local AreaConfig = ConfigManager.GetConfig(ConfigName.AreaConfig)
local MissionConfig = ConfigManager.GetConfig(ConfigName.MissionEventsConfig)
local ChallengeConfig = ConfigManager.GetConfig(ConfigName.ChallengeConfig)

local kServerRedPointBorder = 100

function this.Initialize()
    this.InitRedPointData()
end

function this.InitRedPointData()
    for _, v in pairs(RedPointType) do
        RedPointData[v] = RedPointStatus.Hide
    end
end

--服务器推送红点信息
function this.ReceiveRedPoint(buffer)
    local data = buffer:DataByte()
    local msg = PlayerInfoProto_pb.RedPointInfo()
    msg:ParseFromString(data)
    if msg.type == RedPointType.Mail then
        this.ChangeRedPointStatus(RedPointType.Mail, RedPointStatus.Show)
    end
end

function this.BindObject(rpType, rpObj)
    -- BindObjs[rpType] = BindObjs[rpType] or {}
    -- rpObj:SetActive(RedPointData[rpType] == RedPointStatus.Show)
    -- table.insert(BindObjs[rpType], rpObj)
end

function this.UnBindObject(rpType, rpObj)
    for k, v in pairs(BindObjs[rpType]) do
        if rpObj == v then
            BindObjs[rpType][k] = nil
        end
    end
end

function this.GetRedPointStatus(rpType)
    if RedPointData[rpType] then
        return RedPointData[rpType]
    end
    return RedPointStatus.Hide
end

function this.SetRedPointStatus(rpType, status)
    this.ChangeRedPointStatus(rpType, status)
    this.SetRedPointAllRelate()
end

function this.ChangeRedPointStatus(rpType, status)
    -- if RedPointData[rpType] then
    --     if RedPointData[rpType] ~= status and BindObjs[rpType] then
    --         table.walk(BindObjs[rpType], function(bindObj)
    --             bindObj.gameObject:SetActive(status == RedPointStatus.Show)
    --         end)
    --     end
    --     RedPointData[rpType] = status
    -- end
end

function this.RefreshRedPointData(context)
    this.ClearNullReference()
    if context then
        local infoList = {}
        for _, v in pairs(context) do
            infoList[v.type] = v.state
        end
        for _, v in pairs(RedPointType) do
            if v < kServerRedPointBorder then
                this.ChangeRedPointStatus(v, infoList[v] and infoList[v] or RedPointStatus.Hide)
            end
        end
    end
    this.SetRedPointAllRelate()
end

function this.ClearNullReference()
    for _, objs in pairs(BindObjs) do
        local indexToKill = {}
        for k, obj in pairs(objs) do
            if IsNull(obj) then
                table.insert(indexToKill, k)
            end
        end
        for _, index in ipairs(indexToKill) do
            objs[index] = nil
        end
    end
end

function this.SetRedPointAllRelate()
    this.SetRedPointRelate(RedPointType.JieLing, {
        RedPointType.Refining,
        RedPointType.Arena,
        RedPointType.Adventure,
    })
    this.SetRedPointRelate(RedPointType.ExploreMain, {
        RedPointType.ForgottenCity,
        RedPointType.HeroExplore,
        RedPointType.EpicExplore,
        RedPointType.LegendExplore,
    })
    --this.SetRedPointRelate(RedPointType.Operating, {
    --    RedPointType.MonthCard,
    --    RedPointType.GrowthGift,
    --    RedPointType.GiftPack,
    --})
    --this.SetRedPointRelate(RedPointType.Role, {
    --    RedPointType.Talent,
    --    RedPointType.Friend,
    --})
end

--function this.RefreshPointData()
--    RedPointData[RedPointType.JieLing] = (RedPointData[RedPointType.Refining] == RedPointStatus.Show or
--            RedPointData[RedPointType.Arena] == RedPointStatus.Show or
--            RedPointData[RedPointType.Adventure] == RedPointStatus.Show) and RedPointStatus.Show or RedPointStatus.Hide
--    RedPointData[RedPointType.ExploreMain] = (RedPointData[RedPointType.ForgottenCity] == RedPointStatus.Show or
--            RedPointData[RedPointType.HeroExplore] == RedPointStatus.Show or
--            RedPointData[RedPointType.EpicExplore] == RedPointStatus.Show or
--            RedPointData[RedPointType.EpicExplore] == RedPointStatus.Show) and RedPointStatus.Show or RedPointStatus.Hide
--    RedPointData[RedPointType.Operating] = (RedPointData[RedPointType.MonthCard] == RedPointStatus.Show or
--            RedPointData[RedPointType.GrowthGift] == RedPointStatus.Show or
--            RedPointData[RedPointType.GiftPack] == RedPointStatus.Show) and RedPointStatus.Show or RedPointStatus.Hide
--    RedPointData[RedPointType.Role] = (RedPointData[RedPointType.Talent] == RedPointStatus.Show or
--            RedPointData[RedPointType.Friend] == RedPointStatus.Show) and RedPointStatus.Show or RedPointStatus.Hide
--end

function this.SetRedPointRelate(rpType, rpList)
    local state = false
    for _, rpSType in pairs(rpList) do
        state = state or (RedPointData[rpSType] == RedPointStatus.Show)
    end
    state = state and RedPointStatus.Show or RedPointStatus.Hide
    this.ChangeRedPointStatus(rpType, state)
end




--副本红点（关卡，level双限制）
function this.SetExploreRedPoint(context)
    --{fightId,level}
    --local data = {}
    --for _, challengeInfo in ConfigPairs(ChallengeConfig) do
    --    local condition = context.fightId and context.fightId or context.level
    --    local pos = context.fightId and 1 or 2
    --    if challengeInfo.OpenRule[1][pos] == condition then
    --        local index = table.keyvalueindexof(data, "Id", challengeInfo.Id)
    --        if not index then
    --            table.insert(data, challengeInfo)
    --        end
    --    end
    --end
    --table.walk(data, function(dataInfo)
    --    local fightIdPos = dataInfo.OpenRule[1][1]
    --    local levelPos = dataInfo.OpenRule[1][2]
    --    if FightManager.SetAndGetSingleFightState(fightIdPos, 2) >= 4 and PlayerManager.level >= levelPos then
    --        if dataInfo.Type == 1 then
    --            ChangeRedPointStatus(RedPointType.ForgottenCity, RedPointStatus.Show)
    --        elseif dataInfo.Type == 2 then
    --            ChangeRedPointStatus(RedPointType.HeroExplore, RedPointStatus.Show)
    --        elseif dataInfo.Type == 3 then
    --            ChangeRedPointStatus(RedPointType.EpicExplore, RedPointStatus.Show)
    --        else
    --            ChangeRedPointStatus(RedPointType.LegendExplore, RedPointStatus.Show)
    --        end
    --    end
    --end)
end






------------待处理--------------
--检测背包红点
function this.RedPointBagPanel()
    local itemData = BagManager.GetBagItemData()
    local time = tonumber(RedPointManager.PlayerPrefsGetStr("OpenBagPanel"))
    for i = 1, #itemData do
        --if RedPointManager.PlayerPrefsGetStrItemId(itemData[i].id) == 0 then
        --2 为体力   体力获得时间用做特殊处理 把体力排除
        if itemData[i].id ~= 2 and itemData[i].endingTime and time then
            if tonumber(itemData[i].endingTime) > time then
                return  true
            end
        end
    end
    local allEquipData = {}
    allEquipData = BagManager.GetEquipDataByEquipPosition()
    for i = 1, #allEquipData do
        table.insert(itemData, allEquipData[i])
        --if RedPointManager.PlayerPrefsGetStrItemId(allEquipData[i].did) == 0 then
        if tonumber(allEquipData[i].endingTime) > time then
            return  true
        end
    end

    return false
end

--检测单个地图探索度红点(是否有可领取宝箱)
function this.RedPointMapProgress(_mapId)
    local isShow = false
    if MapManager.allMapProgressList[_mapId] then
        for i = 1, #MapManager.allMapProgressList[_mapId].boxData.allBoxInfoData do
            if MapManager.allMapProgressList[_mapId].boxData.curTotalWeight >= MapManager.allMapProgressList[_mapId].boxData.allBoxInfoData[i].num and
                    MapManager.allMapProgressList[_mapId].boxData.allBoxInfoData[i].isGet == false then
                isShow = true
                break
            end
        end
    end
    return isShow
end
--检测该区域所有地图探索度是否有红点(是否有可领取宝箱)
function this.RedPointAreaMapProgress(_area)
    local isShow = false
    local mapIds = AreaConfig[_area].Include
    for i = 1, #mapIds do
        isShow = this.RedPointMapProgress(mapIds[i])
        if isShow then
            break
        end
    end
    return isShow
end
--检测所有地图探索度是否有红点(是否有可领取宝箱)
function this.RedPointAllMapProgress()
    local isShow = false
    local MapConfigKeys = GameDataBase.SheetBase.GetKeys(ChallengeMapConfig)
    for i = 1, #MapConfigKeys do
        local mapId = ChallengeMapConfig[MapConfigKeys[i]].Id
        isShow = this.RedPointMapProgress(mapId)
        if isShow then
            break
        end
    end
    return isShow
end
--检测主线任务是否有可领取的奖励
function this.RedPointSingleMission()
    local isShow = false
    for i, v in pairs(MissionManager.MissionState) do
        if MissionConfig[i].Type == 1 then
            isShow = MissionManager.MainMissionIsDone(v.id)
            if isShow then
                break
            end
        end
    end
    return isShow
end
--检测主线任务是否有可领取的奖励
function this.GetRedPointMissionDaily()
    local isShow = false
    if ActTimeCtrlManager.SingleFuncState(JumpType.DailyTasks) then
        for i, v in pairs(TaskManager.GetTypeTaskList(TaskTypeDef.DayTask)) do
            if v.state == 1 then
                isShow = true
            end
        end
    end
    return isShow
end
--检测成员是否有红点
function this.GetRedPointRoleIsUpEquip()
   --local teamHero=FormationManager.GetAllFormationHeroId()
   local teamHero=FormationManager.GetWuJinFormationHeroIds(FormationTypeDef.FORMATION_NORMAL)
    for i, v in pairs(teamHero) do
       local isUpEquip = HeroManager.GetHeroIsUpEquip(i)
        if isUpEquip and #isUpEquip > 0 then

            return isUpEquip
        end
    end
    -- for i, v in pairs(teamHero) do
    --     local isUpTalisman = HeroManager.GetHeroIsUpTalisman(i)
    --     if isUpTalisman and #isUpTalisman > 0 then
    
    --         return isUpTalisman
    --     end
    -- end
    --local tarHero=HeroManager.GetAllHeroDatas()
    --for i, v in pairs(teamHero) do
    --    SoulPrintManager.UnLockSoulPrintPos(tarHero[v])
    --    local  soulPrintIsOpen = table.nums(SoulPrintManager.hasUnlockPos)>=1
    --    local isCanShowSoulPrintPoint = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. tarHero[v].dynamicId)
    --    local soulPrintData = SoulPrintManager.GetSoulPrintAndSort(SoulPrintManager.soulPrintData)
    --    if(isCanShowSoulPrintPoint=="0" and #soulPrintData>=1 and soulPrintIsOpen) then
    --        return soulPrintData
    --    end
    --end
    return {}
end
--本地存储字符串
function this.PlayerPrefsSetStr(_str, val)
    PlayerPrefs.SetString(PlayerManager.uid..PlayerManager.serverInfo.server_id.._str, val)
end
--获得本地存储字符串
function this.PlayerPrefsGetStr(_str)
    return PlayerPrefs.GetString(PlayerManager.uid..PlayerManager.serverInfo.server_id.._str, 0)
end
--删除存储本地存储字符串
function this.PlayerPrefsDeleteStr(_str)
    return PlayerPrefs.DeleteKey(PlayerManager.uid..PlayerManager.serverInfo.server_id.._str)
end
--设置红点存储本地
function this.PlayerPrefsSetStrItemId(_iteemId, val)
    PlayerPrefs.SetInt(PlayerManager.uid.._iteemId, val)
end
--获得红点信息
function this.PlayerPrefsGetStrItemId(_iteemId)
    return PlayerPrefs.GetInt(PlayerManager.uid.._iteemId, 0)--1 已经查看过不需要显示新红点  0 显示红点
end
--删除存储本地红点信息(吞装备)
function this.PlayerPrefsDeleteStrItemId(_iteemId)
    return PlayerPrefs.DeleteKey(PlayerManager.uid.._iteemId)
end

return this