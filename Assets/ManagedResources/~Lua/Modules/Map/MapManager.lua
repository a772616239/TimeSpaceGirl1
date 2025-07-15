MapManager = {};
local this = MapManager
local OptionAddConfig = ConfigManager.GetConfig(ConfigName.OptionAddCondition)
local PropConfig = ConfigManager.GetConfig(ConfigName.PropertyConfig)
local missionConfig = ConfigManager.GetConfig(ConfigName.MissionEventsConfig)
local ChallengeData = ConfigManager.GetConfig(ConfigName.ChallengeConfig)
local MapConfig = ConfigManager.GetConfig(ConfigName.ChallengeMapConfig)
local MapPointConfig = ConfigManager.GetConfig(ConfigName.MapPointConfig)
local accomplishmentConfig = ConfigManager.GetConfig(ConfigName.AccomplishmentConfig)
local exploreData = ConfigManager.GetConfig(ConfigName.ExploreFunctionConfig)
local challengeConfig = ConfigManager.GetConfig(ConfigName.ChallengeConfig)
local optionConfig = ConfigManager.GetConfig(ConfigName.OptionConfig)
local ItemData = ConfigManager.GetConfig(ConfigName.ItemConfig)


function this.Initialize()
    this.InitVar()
    Game.GlobalEvent:AddEvent(GameEvent.EliteAchieve.OnAchieveDone, this.OnEliteAchieveDone)
    Game.GlobalEvent:AddEvent(GameEvent.Map.ProgressChange, this.UpdateMapProgressDatas)
    Game.GlobalEvent:AddEvent(GameEvent.Map.PointAdd, function (pos, pointId)
        this.mapPointList[pos] = pointId
    end)
    Game.GlobalEvent:AddEvent(GameEvent.Map.PointRemove, function (pos)
        local mapPointId = MapManager.mapPointList[pos]
        if MapManager.curCarbonType==CarBonTypeId.TRIAL then
            MapManager.mapPointList[pos] = nil
        end
        if MapPointConfig[mapPointId].Style == 7 then --宝箱点被删
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChange, 7,0)
        end
        --MapManager.mapPointList[pos] = nil
    end)

    --TrialManager:Initialize()
end

-- 初始化变量
function this.InitVar()
    this.isJump = false  --是否跳过战斗
    this.isAutoJian = false --自动拾取
    this.allOnClickEvent ={}   --自动拾取点击事件   --宝箱
    this.buffOnClickEvent={}    --buff自动点击
    this.BossId={}
    this.curAreaId = 1  -- 当前区域ID
    this.curMapId = 0   -- 当前地图ID
    this.curPos = 0     -- 当前位置信息值, curPos = u * 256 + v
    this.curTriggerPos = 0     -- 当前触发位置信息值, curTriggerPos = u * 256 + v
    this.mapPointList = {}
    this.formationList = {}
    this.stepList = {} --探索步骤记录
    this.mapPointId = 0  -- 当前地图点ID
    this.curAreaName = ""
    this.curMapName = ""
    this.curMapPointName = ""
    this.totalEnergy = 0   -- 总行动力
    this.leftStep = 0     -- 剩余行动力
    this.curMapBornPos = 0    -- 当前地图出身点
    this.allMapProgressList = {} --所有地图探索度信息
    this.mapPointIdCurEventId = {} -- 地图点对应的事件点
    this.leaderMoveSpeed = 1 / exploreData[1].Value   -- 移动速度
    this.fogSize = exploreData[2].Value    -- 探索相关的默认视野范围
    this.fogRange = 0   -- 驱散迷雾的半径
    this.fogCenter = 0  -- 驱散迷雾的中心点
    this.buffInfo = {}  -- 记录吃了buff之后剩余的步数, 数据结构：buff id ,剩余步数，总作用步数，buff名字
    this.isCarbonEnter =false  -- 是否是从副本进的地图
    this.isOpen = false   -- 副本是否开启
    this.totalTime = 0    -- 地图总时间
    this.deadTime = 0  -- 死亡剩余时间
    this.deadCount = 0   -- 死亡次数
    this.lastPos = 0 -- 角色死亡前位置
    this.isPoping = false  -- 事件节点是否正在弹栈
    this.isTimeOut = false  -- 地图时间是否到了
    -- this.mapPointList = {}
    this.leftStep = 0
    this.isStopDying = false -- 是否立刻停止死亡
    this.isInMap = false -- 是否在地图里
    this.mapScale = 0
    this.fightCount = 0 -- 已经战斗的次数
    this.isRemoving = false -- 正在删点
    this.progressFull = false -- 探索100%
    this.roleInitPos = 0 -- 换层时的出生位置
    this.pointAtkPower = {} -- 每个事件点的战力
    
    this.FirstEnter = false -- 刚进图，区别OnShow

    this.PlayedMapTypes = {}  -- 已经进入过的副本类型（用与判断是否时第一次进入某类型的副本）

    -- 是否是重登后进的图
    this.isReloadEnter = true

    this.trialHeroInfo = {}--试炼阵容信息
    this.curHero = ""--试炼副本当前上阵英雄
    this.addHpCount = 0 --回春散已使用次数

    this.curCarbonType = 0--当前副本玩法类型(副本很多东西不用了，慢慢删，进图只用传 编队、玩法 之后服务器返回mapId)
    this.Mapping = false
    this.endlessEnter = false
    this.openmapid = 1


    --> 
    this.TrialMaxU = 5
    this.TrialMaxV = 11
end

function this.InitData(msg)
    this.mapList = msg.mapList
    this.curPos = msg.curXY
    this.roleInitPos = msg.curXY
    local u, v = Map_Pos2UV(msg.curXY)


    if u == 0 and v == 0 then
        PopupTipPanel.ShowTipByLanguageId(11189)
    end
    this.wakeCells = msg.wakeCells
    --this.totalEnergy = this.leftStep - 5
    --===================== 副本数据初始化 =========================
    
    -- if this.curMapId > 0 then
    --     -- 判断一下服务器返回的初始位置
    --     local size = MapConfig[this.curMapId].Size
    --     if u > size[1] or v > size[2] then
    
    --     end
    --     CarbonManager.difficulty = ChallengeData[this.curMapId].Type
    -- end

    -- if challengeConfig[this.curMapId] then
    --     this.totalTime = challengeConfig[this.curMapId].MapTime
    -- end
    

    -- -- 复活剩余时间]
    -- if msg.reviveTime then
    --     this.deadTime = msg.reviveTime
    --     

    -- end

    -- -- 死亡次数
    -- if msg.dieCount then
    --     this.deadCount = msg.dieCount
    --     
    -- end


    -- local time = msg.leftTime
    -- if time < 0 then
    --     this.isOpen = false
    -- else
        this.isOpen = true
        -- 已经计时的时间
    --     local durationTime = this.totalTime - msg.leftTime
    --     PlayerManager.startTime = PlayerManager.serverTime - durationTime
    -- end
    -- 调用MissionManager初始化副本任务
    MissionManager.InitMissionInfo(msg)
    --=============================================
    this.pointAtkPower = {}
    
    for i = 1, #msg.mapList do
        local cell = msg.mapList[i]
        this.mapPointList[cell.cellId] = cell.pointId  -- cell.cellId == Pos, Pos作为Key
        this.pointAtkPower[cell.cellId] = cell.monsterForce -- 每个事件点可能存在的战力
    end

    this.totalEnergy = 0
    -- this.formationList = {}--请滚

    -- for i=1, #msg.heroInfos do
    --     local heroDid = msg.heroInfos[i].heroId
    --     local curHeroData = HeroManager.GetSingleHeroData(heroDid)
    --     local lv = ConfigManager.GetConfigData(ConfigName.HeroLevelConfig, curHeroData.lv).CharacterLevelPara
    --     local allEquipAddProVal= HeroManager.CalculateWarAllProVal(heroDid)
    --     allEquipAddProVal[2] = msg.heroInfos[i].heroHp
    --     allEquipAddProVal[3] = msg.heroInfos[i].heroMaxHp
    --     this.totalEnergy=this.totalEnergy+curHeroData.actionPower
    --     this.formationList[i] = {
    --         heroId = heroDid,
    --         allProVal = allEquipAddProVal,
    --     }
    -- end


    -- 如果是重登，则进图时请求一次血量数据
    if this.isReloadEnter and CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        NetManager.RequestAllHeroHp(function ()

        end)
    end

    -- this.UpdateMaoShotTimeBagData(msg.temporaryItems)

    -- 获得所有的buff效果
    
    FoodBuffManager.Initialize()
    for i = 1, #msg.foodBuffers do
        local bufferId = msg.foodBuffers[i].bufferId
        local leftStep = msg.foodBuffers[i].leftStep

        if leftStep < 0 then
            -- 剩余步数小于0，表示永久buff，步数的绝对值表是这个buff的数量
            for i = 1, math.abs(leftStep) do
                local buffer = FoodBuffManager.CreateFoodBuff(bufferId)
                buffer:SetLeftStep(-1)
            end
        else
            local buffer = FoodBuffManager.CreateFoodBuff(bufferId)
            buffer:SetLeftStep(leftStep)
        end
    end

    -- 试炼副本的Buff信息
    if msg.buf then
        MapTrialManager.SetBuffList(msg.buf)
    end

    -- 无尽副本
    if msg.signs then
        
        -- EndLessMapManager.InitMapNoteData(msg.signs)
    end

    -- 时间点的刷新时间
    if msg.refreshInfo then
        EndLessMapManager.InitRefreshPoint(msg.refreshInfo)
    end

    -- 跳过战斗设置
    if msg.skipFight then
        -- 是否跳过了战斗
        --EndLessMapManager.isSkipFight = msg.skipFight
    end

    -- 探索度限制条件初始化
    this.progressFull = false

    if msg.infos then
        this.trialHeroInfo=msg.infos
    end

    if msg.curHero then
        this.curHero=msg.curHero
    end

    if msg.addHpCount then
        this.addHpCount=msg.addHpCount
    end
end

-- 判断某类型副本是否已经进入过
function this.IsPlayedByMapType(mapType)
    if not this.PlayedMapTypes then return false end
    if table.indexof(this.PlayedMapTypes, mapType) then
        return true
    end
    return false
end
-- 设置某类型副本已经进入过
function this.SetMapTypePlayed(mapType)
    if not this.PlayedMapTypes then
        this.PlayedMapTypes = {}
    end
    if table.indexof(this.PlayedMapTypes, mapType) then return end
    table.insert(this.PlayedMapTypes, mapType)
end

-- 计算角色死亡总时间
function this.RoleTotalDeadTime()
    local deadTimes = this.deadCount
    local curTotalTime = 0
    local data = challengeConfig[this.curMapId].ReviveTime
    curTotalTime = math.pow(deadTimes, 3) * data[1] + math.pow(deadTimes, 2) * data[2]
            + deadTimes * data[3] + data[4]
    return curTotalTime
end
local trialPanel = require("Modules/Map/TrialMapPanel")
-- 根据地图点删除多个位置
function this.DeletePos(mapPointId)
    for i, v in pairs(MapManager.mapPointList) do
        if v then
            if v == mapPointId then
                Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, i)
            end
        end
    end
end

-- 设置探索的视野范围
function this.SetViewSize(size)
    this.fogSize = size
end

-- 设置人物移动速度
function this.SetMoveSpeed(speed)
    this.leaderMoveSpeed = exploreData[1].Value / speed
end

--初始化所有地图探索度
function this.InitAllMapPgData()
    this.allMapProgressList = {}
    local MapConfigKeys = GameDataBase.SheetBase.GetKeys(MapConfig)
    for i=1, #MapConfigKeys do
        local curMapData={}

        if MapConfig[MapConfigKeys[i]].MapId ~= 10 then
            curMapData.mapId=MapConfig[MapConfigKeys[i]].MapId
            curMapData.totalWeight=0
            curMapData.maxTotalWeight=0
            curMapData.progressData={}
            local accomplishmentConfigKeys = GameDataBase.SheetBase.GetKeys(accomplishmentConfig)
            for i = 1, #accomplishmentConfigKeys do
                if accomplishmentConfig[accomplishmentConfigKeys[i]].MapId == curMapData.mapId then
                    local ExploreDetail={}
                    ExploreDetail.id=accomplishmentConfig[accomplishmentConfigKeys[i]].id
                    ExploreDetail.proressNum=0
                    ExploreDetail.configData=accomplishmentConfig[accomplishmentConfigKeys[i]]
                    curMapData.maxTotalWeight=curMapData.maxTotalWeight+accomplishmentConfig[accomplishmentConfigKeys[i]].Score
                    table.insert(curMapData.progressData,ExploreDetail)
                end
            end
            this.allMapProgressList[curMapData.mapId]=curMapData
        --this.InitAllMapProgressData(curMapData)
        end
    end
    table.sort(this.allMapProgressList, function(a,b) return a.mapId < b.mapId end)
end

--获取所有地图探索度信息
function this.InitAllMapProgressData(_curMapData)
    local singleMapProgressData={}
    --地图id
    if this.allMapProgressList[MapManager.curMapId] then
        singleMapProgressData=this.allMapProgressList[MapManager.curMapId]
        singleMapProgressData.totalWeight=0
        for i = 1, #singleMapProgressData.progressData do
            for j = 1, #_curMapData do
                if singleMapProgressData.progressData[i].id==_curMapData[j].id then
                    singleMapProgressData.progressData[i].proressNum=_curMapData[j].progress
                    if _curMapData[j].progress>=singleMapProgressData.progressData[i].configData.Values[2][1] then
                        singleMapProgressData.totalWeight=singleMapProgressData.totalWeight+singleMapProgressData.progressData[i].configData.Score
                    end
                end
            end
        end
    end
end

-- function this.UpdateMaoShotTimeBagData(_temporaryItems)
--     if _temporaryItems.itemlist~=nil and #_temporaryItems.itemlist>0 then
--         for i = 1, #_temporaryItems.itemlist do
--             BagManager.InitMapShotTimeBagData(_temporaryItems.itemlist[i])
--         end
--     end
--     if _temporaryItems.equipId~=nil and #_temporaryItems.equipId>0  then
--         for i = 1, #_temporaryItems.equipId do
--             EquipManager.InitMapShotTimeEquipBagData(_temporaryItems.equipId[i])
--         end
--     end
--     if _temporaryItems.Hero~=nil and #_temporaryItems.Hero>0  then
--         for i = 1, #_temporaryItems.Hero do
--             HeroManager.InitMapShotTimeHeroBagData(_temporaryItems.Hero[i])
--         end
--     end
--     if _temporaryItems.soulEquip~=nil and #_temporaryItems.soulEquip>0  then
--         for i = 1, #_temporaryItems.soulEquip do
--             SoulPrintManager.InitMapShotTimeSoulPrintBagData(_temporaryItems.soulEquip[i])
--         end
--     end

    -- if _temporaryItems.especialEquipId~=nil and #_temporaryItems.especialEquipId>0  then
    --     for i = 1, #_temporaryItems.especialEquipId do
    --         TalismanManager.InitMapShotTimeTalismanBagData(_temporaryItems.especialEquipId[i])
    --     end
    -- end
-- end

--前端更新地图进度   _type  2/3 怪物组id#次数/本次地图获得战斗胜利次数  4/8  行脚商人id#物品id /行脚商人id#物品类型   5 本地图采矿都少次   6 消耗行动力数量  7 宝箱
function this.UpdateMapProgressDatas(_type,_eventId,_monsterId,_num,_isSend)--没有数据可传0
    if _monsterId then
    end
    if _num then
    end
    if  this.allMapProgressList[this.curMapId] then
        for i = 1, #this.allMapProgressList[this.curMapId].progressData do
            local curMapSinleProgressData = this.allMapProgressList[this.curMapId].progressData[i]
            if _type == 2 or _type == 3 then--2/3 怪物组id#次数/本次地图获得战斗胜利次数
                if curMapSinleProgressData.configData.Logic == 2 then
                    for j = 1, #curMapSinleProgressData.configData.Values[1] do
                        if curMapSinleProgressData.configData.Values[1][j] == _monsterId then
                            this.UpdateMapProgressData(_type,curMapSinleProgressData,1)
                        end
                    end
                elseif curMapSinleProgressData.configData.Logic == 3  then
                    this.UpdateMapProgressData(_type,curMapSinleProgressData,1)
                end
            elseif _type == 4 or _type == 8 then--4/8  行脚商人id#物品id /行脚商人id#物品类型

            elseif _type == 5 then-- 5 本地图采矿都少次
                if curMapSinleProgressData.configData.Logic == 5  then
                    this.UpdateMapProgressData(_type,curMapSinleProgressData,1)
                end
            --elseif _type == 6 then--6 消耗行动力数量
            --    if curMapSinleProgressData.configData.Logic==6  then
            --        this.UpdateMapProgressData(_type,curMapSinleProgressData,_num,_isSend)
            --    end
            elseif _type == 7 then--7 宝箱
                if curMapSinleProgressData.configData.Logic == 7  then
                    this.UpdateMapProgressData(_type,curMapSinleProgressData,1)
                end
            end
            --事件点id#次数
            if curMapSinleProgressData.configData.Logic == 1 then
                for j = 1, #curMapSinleProgressData.configData.Values[1] do
                    if curMapSinleProgressData.configData.Values[1][j] == _eventId then

                        this.UpdateMapProgressData(_type,curMapSinleProgressData,1)
                    end
                end
            end
        end
    end
end
function this.UpdateMapProgressData(_type, _data, _num, _isSend)
    if this.curMapId == 0 or ChallengeData[this.curMapId].IsExplore == 0 then return end
    if _data.proressNum < _data.configData.Values[2][1] then
        _data.proressNum = _data.proressNum + _num
        if _data.proressNum >= _data.configData.Values[2][1] then
            if _type == 6 and _isSend then
                NetManager.MapUpdateEvent(-1000)
            end
            this.allMapProgressList[this.curMapId].totalWeight = this.allMapProgressList[this.curMapId].totalWeight + _data.configData.Score
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChangeUpdateShow)
            local weight =  this.allMapProgressList[this.curMapId].totalWeight
            if weight >= 100 then
                --if not UIManager.IsOpen(UIName.MissionRewardPanel) then
                this.progressFull = true
                if not UIManager.IsOpen(UIName.RewardItemPopup) then
                    UIManager.OpenPanel(UIName.MapStatsPanel)
                end
            else
                this.progressFull = false
            end
            -- 调整显示顺序，任务完成提示显示在副本结束界面上面
            --PopupTipPanel.ShowTip(_data.configData.Info)
            if _data.configData.Info~=nil and _data.configData.Info~="" then
                UIManager.OpenPanel(UIName.CurlingTipPanel, _data.configData.Info)
            end
        end
    end

    Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressDataChange)

end

--通过地图探索度 得到当前事件点是否通过
function this.GetCurPointEventIsPass(_pointEventId)
    local isPass = false
    local mapId = tonumber(string.sub(tostring(_pointEventId), 1, 3))
    if  this.allMapProgressList[mapId] then
        for i = 1, #this.allMapProgressList[mapId].progressData do
            if this.allMapProgressList[mapId].progressData[i].configData then
                for j = 1, #this.allMapProgressList[mapId].progressData[i].configData.Values[1] do
                    if this.allMapProgressList[mapId].progressData[i].configData.Values[1][j] == _pointEventId then
                        if this.allMapProgressList[mapId].progressData[i].proressNum>=this.allMapProgressList[mapId].progressData[i].configData.Values[2][1] then
                            isPass = true
                        end
                    end
                end
            end
        end
    end
    return isPass
end

-- 通过地图点ID获得地图上的位置
function this.GetPosByMapPointId(mapPointId)
    for i, v in pairs(this.mapPointList) do
        if v == mapPointId then
            return i
        end
    end
end

-- 设置血量的初始状态
function this.InitFormationHp()
    for i = 1, #MapManager.formationList do
        MapManager.formationList[i].allProVal[2] = MapManager.formationList[i].allProVal[3]
    end
end

function this.MapUpdateEvent(pos, func)
    NetManager.MapUpdateEvent(pos, function (eventId)
        -- 试炼召唤Boss需要向服务器同步一次，发送-1000， 此时不赋值
        if pos ~= -1000 then
            MapManager.curTriggerPos = pos
        end
        MapManager.mapPointId = MapManager.mapPointList[pos]
        if eventId ~= 0 then
            MissionManager.EventPointTrigger(eventId)
        elseif eventId == 0 and MapManager.curCarbonType == CarBonTypeId.TRIAL then
            local style = MapPointConfig[MapManager.mapPointId].Style
            MissionManager.MapPointTrigger(style,pos)
        end
        if func then
            func()
        end
    end)
end

function this.MapUpdateEvent2(pos, func)
    NetManager.MapUpdateEvent2(pos, function (eventId)
        -- 试炼召唤Boss需要向服务器同步一次，发送-1000， 此时不赋值
        if pos ~= -1000 then
            MapManager.curTriggerPos = pos
        end
        MapManager.mapPointId = MapManager.mapPointList[pos]
        if eventId ~= 0 then
            MissionManager.EventPointTrigger(eventId, pos)
        elseif eventId == 0 and MapManager.curCarbonType == CarBonTypeId.TRIAL then
            if MapManager.mapPointId  then
                local style = MapPointConfig[MapManager.mapPointId].Style
                MissionManager.MapPointTrigger(style, pos)
            end
        end
        if func then
            func()
        end
    end)
end

function this.GetBattleData(formationId, monsterGroupId)
    local fightData = BattleManager.GetBattleData(formationId, monsterGroupId)
    local i = 1
    while i <= #fightData.playerData do
        fightData.playerData[i].property[2] = this.formationList[i].allProVal[2]
        if fightData.playerData[i].property[2] == 0 then
            table.remove(fightData.playerData, i)
        end
        i = i + 1
    end
    return fightData
end

function this.MapBattleExecute(monsterGroupId, optionid, callBack)
    NetManager.QuickFightRequest(function (msg)--QuickFightRequest
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg)
            local triggerCallBack
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.MAP_FIGHT, function (result)
                triggerCallBack = function (panelType, panel)
                    if panelType == UIName.MapPanel then --监听到MapPanel重新打开，再抛对应事件，否则接收不到
                        if result.result == 0 then --战斗失败回
                            if OptionBehaviourManager.CurTriggerPanel then
                                OptionBehaviourManager.CurTriggerPanel:ClosePanel()
                            end

                            -- 失败接受一下后端返回的位置
                            local lastPos = result.lastPos
                            Game.GlobalEvent:DispatchEvent(GameEvent.Map.DeadOut, 0, lastPos)
                        else  -- 地图连续事件点的战斗胜利
                            this.VictoryHandler(result, callBack)
                        end
                        Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnOpen, triggerCallBack)
                    end
                    Timer.New(function()
                        -- 刷新数据
                        CarbonManager.InitQuickFightData(monsterGroupId, nil, msg)
                    end,
                    0.2
                    ):Start()
                end
                Timer.New(function()
                -- 刷新数据
                CarbonManager.InitQuickFightData(monsterGroupId, nil, msg)
                end,
                0.2):Start()
            end)
            Game.GlobalEvent:AddEvent(GameEvent.UI.OnOpen, triggerCallBack)
        end)
    end)
end

-- 战斗胜利的处理
function this.VictoryHandler(result, callBack)
    -- 试炼副本
    if result.lastTowerTime then
        MapTrialManager.bossDeadTime = result.lastTowerTime
    end

    -- 先刷一次战斗后的血量
    this.RefreshFormationHp(result)
    if callBack then
        callBack(result)
    end
    -- 试炼副本最后一层
    if MapTrialManager.IsFinalLevel() then
        this.PanelCloseCallBack(UIName.MapOptionPanel, function ()
            UIManager.OpenPanel(UIName.MapStatsPanel)
        end)
    end

end

function this.RefreshFormationHp(result)
    if result.result == 0 then
        return
    end
    for i = 1, #this.formationList do
        this.formationList[i].allProVal[2] = result.hpList[i]
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.FormationHpChange)
end


--给队伍所有人加特定属性值, 0 是减少，1 是增加
function this.RefreshFormationProListVal(proId, changeType, _val)
    -- 获取战斗属性
    local _proType = GetProIndexByProId(proId)
    if not _proType or _proType == 0 then return end
    -- 确认数值方向
    changeType = changeType / 0.5 - 1
    -- 开始加属性
    for i=1, #this.formationList do
        -- 获取当前值
        local value = this.formationList[i].allProVal[_proType]
        --- 加血需要特殊处理
        if _proType == 2 then
            -- 判断人物是否死亡，死亡不再加血
            if value > 0 then
                local maxHp = this.formationList[i].allProVal[GetProIndexByProId(1)]
                if proId == 67 then -- 最大生命值百分比加血
                    value = value + (_val / 10000 * maxHp) * changeType
                elseif proId == 68 then -- 当前剩余血量百分比加血
                    value = value + (_val / 10000 * value) * changeType
                else
                    value = value + _val * changeType
                end
                -- 不能超出最大值
                value = value >= maxHp and maxHp or value
                -- 不能一下子就死掉了
                --value = value <= 0 and 1 or value
            end
        else
            value = value + _val * changeType
        end
        -- 人物属性不能小于0
        value = value < 0 and 0 or value
        this.formationList[i].allProVal[_proType] = value
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.FormationHpChange)
end

-- 根据附加条件判断结果做相应的表现
function this.AddContionType(AddCondtionID, eventId, option, panel, func)
    local conditiontype = OptionAddConfig[AddCondtionID].Type

   
    if conditiontype == 1 then -- 判断完成事件点进度

        OptionBehaviourManager.JumpEventPoint(eventId, option, panel)

    elseif conditiontype == 2 then  -- 判断物品数量
        local isPass = this.IsAddContionPass(AddCondtionID, 2)

        if not isPass then
            MsgPanel.ShowOne(GetLanguageStrById(11197))
        else
            OptionBehaviourManager.JumpEventPoint(eventId, option, panel)
        end

    elseif conditiontype == 3 then  -- 判断角色属
        local isPass = this.IsAddContionPass(AddCondtionID, 3)
        if isPass then
            OptionBehaviourManager.JumpEventPoint(eventId, option, panel)
        else
            MsgPanel.ShowOne(OptionAddConfig[AddCondtionID].Info .. GetLanguageStrById(11198) .. GetLanguageStrById(11199) .. PropConfig[propId])
        end
    elseif conditiontype == 4  then  --完成某个任务的第几步
        local isPass = this.IsAddContionPass(AddCondtionID, 4)
        if isPass then
            OptionBehaviourManager.JumpEventPoint(eventId, option, panel)
        else
            MsgPanel.ShowOne(GetLanguageStrById(11200) .. missionConfig[missionId].MainTitle ..GetLanguageStrById(11201) .. stepNeed)
        end
    elseif conditiontype == 5 then  -- 判断物品数量小于指定数量
        local isPass = this.IsAddContionPass(AddCondtionID, 5)
        if isPass then
            OptionBehaviourManager.JumpEventPoint(eventId, option, panel)
        else
            PopupTipPanel.ShowTipByLanguageId(11202)
        end
    elseif conditiontype == 6 then  -- 判断属性
        local isPass = this.IsAddContionPass(AddCondtionID, 6)
       
        if isPass then
            OptionBehaviourManager.JumpEventPoint(eventId, option, panel)
        else
            MsgPanel.ShowOne(GetLanguageStrById(11203))
        end
    elseif conditiontype == 8 then  -- 显示提示文字
        OptionBehaviourManager.JumpEventPoint(eventId, option, panel)
    elseif conditiontype == 9 then -- 显示行动力
        local isPass = this.IsAddContionPass(AddCondtionID, 9)
        if isPass then
            OptionBehaviourManager.JumpEventPoint(eventId, option, panel)
        else
            PopupTipPanel.ShowTipByLanguageId(11204)
        end
    end

    if func then func() end 
end


-- 根据附加条件判断结果决定按钮显示状态
function this.IsShowOptionBtn(addConditionId, btnShowType)
    if addConditionId == nil or addConditionId == 0 then
        return true
    else
        if btnShowType == 1 then
            return true
        elseif btnShowType == 2 then
            -- 判断附加条件是否通过
            local addIsDone, secondResult = this.IsAddContionPass(addConditionId, 0)
            if secondResult then
                return addIsDone, secondResult
            else
                return addIsDone
            end
        elseif btnShowType == 3 then
        elseif btnShowType == 0 or btnShowType == nil then

        end
    end
end


-- 判断附件的条件是否通关，通过附加的ID和类型返回判断值， 0或空返回所有的判断结果
function this.IsAddContionPass(addConditionId, _type)
    local AddConditionType = OptionAddConfig[addConditionId].Type
    local ConditionValues = OptionAddConfig[addConditionId].Values

    if _type == 0 or _type == nil then
        _type = AddConditionType
    end

    if _type == 1 then -- 事件点进度
        return true

    elseif _type == 2 then  -- 判断指定物品数量大于
        local haveEnoughItem = false

        for i = 1, #ConditionValues do
            local itemId = ConditionValues[i][1]
            local numNeed = ConditionValues[i][2]

            if BagManager.GetTotalItemNum(itemId) < numNeed then
                haveEnoughItem = false
                return haveEnoughItem
            else
                haveEnoughItem = true
            end
        end
        return haveEnoughItem

    elseif _type == 3 then -- 验证全员属性
        local propEnough = false
        local JudgeRange = ConditionValues[1][1]
        local propId = ConditionValues[1][2]  -- 属性ID
        local threhold = ConditionValues[1][3] -- 判断阈值
        -- 获取全队员需要判断的属性
        for i = 1, #this.formationList do
            local heroId = this.formationList[i].heroId
            local prop = HeroManager.CalculateProValMap(heroId, propId)
            if JudgeRange == 0 then -- 最高属性
                if prop > threhold then
                    propEnough = true
                end
            else   -- 全队属性
                if prop < threhold then
                    propEnough = false
                else
                    propEnough = true
                end
            end
        end
        return propEnough

    elseif _type == 4 then -- 完成任务的第几步
        local stepIsDone = false
        --当前开启条件，需要完成某个任务的第几步
        local missionId = ConditionValues[1][1]
        local stepNeed = ConditionValues[1][2]

        local curMissionStep = 0
        --任务未开启，此时为空
        if not MissionManager.MissionState[missionId] then
            curMissionStep = 0
        else
            curMissionStep = MissionManager.MissionState[missionId].step
        end
        stepIsDone = curMissionStep + 1 >= stepNeed
        return stepIsDone

    elseif _type == 5 then -- 判断物品数量小于指定数量
        local isLess = false
        for i = 1, #ConditionValues do
            local itemId = ConditionValues[1][1]
            local numNeed = ConditionValues[1][2]
            if BagManager.GetTotalItemNum(itemId) >= numNeed then
                isLess = false
                return isLess
            else
                isLess = true
            end
        end
        return isLess
    elseif _type == 6 then -- 某个任务是否处于第几步
        local finalResult = true
        -- 记录所有判断结果
        local result = {}
        for i = 1, #ConditionValues do
            local isOnStep = false
            local jude = ConditionValues[i][1]
            local missionId = ConditionValues[i][2]
            local stepNeed = ConditionValues[i][3]
            if MissionManager.MissionState[missionId] then
                local curStep = MissionManager.MissionState[missionId].step -- 指定任务的当前进度
                if jude == 0 then
                    if curStep == stepNeed then  -- 某个任务是否处于第几步
                        isOnStep = true
                    else
                        isOnStep = false
                    end
                elseif jude == 1 then  -- 不处于任务的第几步
                    if curStep == stepNeed then
                        isOnStep = false
                    else
                        isOnStep = true
                    end
                end
            else

            end
            result[i] = isOnStep
        end

        -- 有一个没有达到要求，都是false
        for i, v in pairs(result) do
            if v == false then
                finalResult = false
            end
        end
        return finalResult
    elseif  _type == 8 then -- 显示提示文字
        return true
    elseif _type == 9 then -- 判断行动力
        local curEnergy = EndLessMapManager.leftEnergy
        local distMapId = ConditionValues[1][1]
        local energyNeed = EndLessMapManager.EnergyCostEnterMap(distMapId)
        return curEnergy >= energyNeed

    end
end


-- 返回当前区域名
function this.GetCurAreaName()
    return ChallengeData[this.curMapId].Name
end
-- 返回当前地图名
function this.GetCurMapName()
    return MapConfig[this.curMapId].Info
end

-- 返回当前地图点名
function this.GetCurMapPointName()
    return MapPointConfig[this.mapPointList[this.curTriggerPos]].Desc
end
PointType = {
    [1] = GetLanguageStrById(11207),
    [2] = GetLanguageStrById(11208),
    [3] = GetLanguageStrById(11209),
    [4] = GetLanguageStrById(11210),
    [5] = GetLanguageStrById(11211),
    [6] = GetLanguageStrById(11212),
    [7] = GetLanguageStrById(11213),
    [8] = GetLanguageStrById(11214),
    [10] = GetLanguageStrById(11215),
}


-- 探索度显示数据
function this.ExploreDataShow()
    -- 序章无探索度
    local mapData = this.allMapProgressList[this.curMapId]
    local exploreData = {}
    exploreData.info = {}
    if not mapData then
        return 
    end
    -- 探索度进度
    exploreData.progress = mapData.totalWeight
    -- 百分比进度
    exploreData.percent = mapData.totalWeight / mapData.maxTotalWeight
    -- 数据排序
    table.sort(mapData.progressData, function(a,b) return a.id < b.id end)
    -- 重组数据
    for i = 1, #mapData.progressData do
        local data = {}
        local proDat = mapData.progressData[i]
        -- 探索内容条
        data.context =proDat.configData.Info
      
        data.id = proDat.id

        local curProgress = proDat.proressNum
        local totalProgress = proDat.configData.Values[2][1]
        -- 单体进度, 显示使用，string型
        data.progress = string.format("(%s/%s)", curProgress, totalProgress)
        -- 探索度权重值，显示使用
        data.weight = string.format("+%s", proDat.configData.Score)

        -- 探索度完成状态
        data.isDone = curProgress >= totalProgress
        exploreData.info[i] = data
    end

    -- 重新排序， 已完成的丢后面，ID小优先
    local doneData = {}
    local doingData = {}
    for i = 1, #exploreData.info do
        if exploreData.info[i].isDone == false then
            doingData[#doingData + 1] = exploreData.info[i]
        else
            doneData[#doneData + 1] = exploreData.info[i]
        end
    end

    if #doingData > 1 then
        table.sort(doingData, function (a, b)
            return a.id < b.id
        end)
    end

    if #doneData > 1 then
        table.sort(doneData, function (a, b)
            return a.id < b.id
        end)
    end

    exploreData.info = {}
    for i = 1, #doingData do
        table.insert(exploreData.info, doingData[i])
    end
    for i = 1, #doneData do
        table.insert(exploreData.info, doneData[i])
    end
    return exploreData
end

-- 获取当前地图对应的副本id
function this.GetCurCarbonId()
    return challengeConfig[this.curMapId].MapId
end

-- 精英副本成就完成会调事件
function this.OnEliteAchieveDone(taskId)
    local curCarbonId = this.GetCurCarbonId()
    local achieve = accomplishmentConfig[taskId]
    if achieve and achieve.MapId == curCarbonId then
        UIManager.OpenPanel(UIName.CurlingTipPanel, achieve.Info .. GetLanguageStrById(11217))
    end
end

-- 返回道具数量判断的东西
function this.ItemNumJudge(optionId)
    local addId = optionConfig[optionId].AddConditionID
    local isPass = this.IsAddContionPass(addId, 2)
    return isPass
end

function this.ItemColorStr(optionId)
    local addId = optionConfig[optionId].AddConditionID
    if not addId or addId == 0 then
        return 
    end
    local values = OptionAddConfig[addId].Values

    local colorStr = ""
    if not values or #values == 0 then return end
    for i, v in pairs(values) do
        local id = v[1]
        local itemNeed = v[2]
        local itemHave = BagManager.GetTotalItemNum(id)
        local name = ItemData[id].Name
        local color = itemHave >= itemNeed and "#FFFFFFFF" or "#FF0000FF"
        colorStr = colorStr .. string.format(" %s: <color=%s>%s</color>/%d ", name, color, itemHave, itemNeed)
    end
    return colorStr
end

-- 检测面板关闭再执行回调
function this.PanelCloseCallBack(uiPanel, func)
    if UIManager.IsOpen(uiPanel) then
        local triggerCallBack
        triggerCallBack = function (panelType, panel)
            if panelType == uiPanel then
                if func then func() end
                Game.GlobalEvent:RemoveEvent(GameEvent.UI.OnClose, triggerCallBack)
            end
        end
        Game.GlobalEvent:AddEvent(GameEvent.UI.OnClose, triggerCallBack)
    else
        if func then func() end
    end
end

-- 计算地图编队战力
function this.GetMapTeamPower()
    local curFormation = MapManager.formationList
    local powerNum = 0
    for i = 1, 5 do
        local heroData
        if curFormation[i] then
            heroData = HeroManager.GetSingleHeroData(curFormation[i].heroId)
            if not heroData then
               
                return
            end

            if curFormation[i].allProVal[2] > 0 then
                local allEquipAddProVal = 0
                allEquipAddProVal = HeroManager.CalculateHeroAllProValList(1, heroData.dynamicId, false)
                powerNum = powerNum + allEquipAddProVal[HeroProType.WarPower]
            end
        end
    end
    return powerNum
end

--存入临时背包
function this.DropAddShotTimeBag(_drop)
    local drop = BagManager.GetItemListFromTempBag(_drop)
    for i = 1, #drop do
        local itemdata = drop[i]
        if itemdata.itemType==2 then
            EquipManager.InitMapShotTimeEquipBagData(itemdata.backData)
        elseif itemdata.itemType==3 then
            HeroManager.InitMapShotTimeHeroBagData(itemdata.backData)
        elseif itemdata.itemType==4 then
            TalismanManager.InitMapShotTimeTalismanBagData(itemdata.backData)
        elseif itemdata.itemType==5 then
            SoulPrintManager.InitMapShotTimeSoulPrintBagData(itemdata.backData)
            SoulPrintManager.StoreData(itemdata.data)
        end
    end
end

--> 获取奥廖尔商店中不显示商品的数量（从后面去 后端说不能做 前端屏蔽 无商品id 按商品返回顺序）
function this.GetShopHideCount()
    local cnt = 0
    if MapManager.mapPointList and LengthOfTable(MapManager.mapPointList) > 0 then
        local id = 2000007  --< 商店id 固定
        for k, v in pairs(MapManager.mapPointList) do
            if v == id then
                cnt = cnt + 1
            end
        end
        
        local function set(vb, ve)
            for u = 1, 5 do
                for v = vb, ve do
                    local uv_p = Map_UV2Pos(u, v)
                    if MapManager.mapPointList[uv_p] == id then
                        cnt = cnt - 1
                    end
                end
            end
        end
        local pos = Map_UV2Pos(3, 3)
        if MapManager.mapPointList[pos] ~= nil then
            --> unfight
        else
            set(2, 4)
        end
        
        pos = Map_UV2Pos(3, 5)
        if MapManager.mapPointList[pos] ~= nil then
            --> unfight
        else
            set(5, 6)
        end
        
        pos = Map_UV2Pos(3, 7)
        if MapManager.mapPointList[pos] ~= nil then
            --> unfight
        else
            set(7, 8)
        end
        
        pos = Map_UV2Pos(3, 9)
        if MapManager.mapPointList[pos] ~= nil then
            --> unfight
        else
            set(9, 11)
        end
    end

    return math.max(0, cnt)
end

function this.RefreshRedPoint()
    if not ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.TRIAL)
        or not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.TRIAL) then
        return false
    end
    if #MapManager.trialHeroInfo == 0 then
        return true
    end
    return false
end

return this