-- 管理副本的一些通用数据
-- 副本ID就是地图Id
CarbonManager = {};
local this = CarbonManager
local DifficultyData = ConfigManager.GetConfig(ConfigName.ChallengeConfig)
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
this.gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
-- 副本难度数据管理
this.levelNormal = {}
this.levelHero = {}
this.levelLegend = {}
this.levelEpic = {}
-- 当前选择的副本难度
this.difficulty = 0
-- 副本完成情况
this.CarbonInfo = {}
-- 是否在副本中的小怪跳过战斗
this.isPassFight = true
-- 三星总数
local starNum = 0
this.remainTime = 0
this.hasGetRewardCostStar = 0
this.degreeDetailListText = {}
this.currentPlies = 0
this.historyMaxPlies = 0
this.canResetTimes = 0
this.difficultyMask = {}
this.difficultyId = {}
this.ownEliteCarbonTicket = nil
this.unlockDifficultyId = {}
-- 普通副本被玩！过的地图ID
this.playedMapId = {}
-- 完成地图任务时角色死亡次数
this.RoleDeadTimes = 0
--推荐战力
this.recommendFightAbility={}
--每日副本
this.dailyChallengeInfo={}

this.dailyCarbons={}

CARBON_TYPE = {
    NORMAL = 1,
    TRIAL = 2,
    HERO = 3,
    ENDLESS = 4,
}
local update = function()
    if this.remainTime > 0 then
        this.UpdateEliteCarbonTicketData()
    end
end

function this.Initialize()
    Game.GlobalEvent:AddEvent(GameEvent.Bag.BagGold, this.OnEliteCarbonTicketChange)
    this.GetMissionLevelData()
    UpdateBeat:Add(update, this)
    for k, v in ConfigPairs(DifficultyData) do
        if(v.Type == 3) then
            this.difficultyMask[v.MapId]=-1
        end
    end
    -- 监听关卡通关事件
    Game.GlobalEvent:AddEvent(GameEvent.Mission.OnOpenFight, function(fightId)
        -- 检测副本解锁红点
        CheckRedPointStatus(RedPointType.NormalExplore_OpenMap)
    end)
end

-- 判断每日副本是否已经通过
function this.IsDailyCarbonPass(id)
    if this.dailyChallengeInfo~=nil then
        for i = 1, #this.dailyChallengeInfo do
            if id == this.dailyChallengeInfo[i] then
                return true
            end
        end
    end
    return false
end

function this.UpdateEliteCarbonTicketData()
    local dt = Time.fixedDeltaTime
    this.remainTime = this.remainTime - dt
    if this.remainTime < 0 then
        local ownNumber = BagManager.GetItemCountById(UpViewRechargeType.EliteCarbonTicket)
        if ownNumber < this.gameSetting[1].HeroTimes then
            this.UpdateEliteCarbonTicketRequest({28})
        end
    end
end

--请求刷新副本次数
function this.UpdateEliteCarbonTicketRequest(itemIdList)
    local data = PlayerInfoProto_pb.RefreshItemNumRequest()
    for i = 1, #itemIdList do
        data.itemId:append(itemIdList[i])
    end
    local msg = data:SerializeToString()
    local network = SocketManager.GetNetwork(SocketType.LOGIN)
    network:SendMessageWithCallBack(MessageTypeProto_pb.REFRESH_ITEM_NUM_REQUEST, MessageTypeProto_pb.REFRESH_ITEM_NUM_RESPONSE, msg, function(buffer)
        local data = buffer:DataByte()
        local msg = PlayerInfoProto_pb.RefreshItemNumResponse()
        msg:ParseFromString(data)
        this.RefreshEliteCarbonTicket(msg.itemInfo)
    end)
end


function this.RefreshEliteCarbonTicket(itemData)
    if itemData and #itemData > 0 then
        for i = 1, #itemData do
            if itemData[i].templateId == UpViewRechargeType.EliteCarbonTicket then
                BagManager.UpDataBagItemIdNumber({
                    itemId = UpViewRechargeType.EliteCarbonTicket,
                    itemNum = itemData[i].overlap,
                    endingTime = itemData[i].nextRefreshTime - this.gameSetting[1].RecoveryTime
                })
            end
        end
    end
end

function this.OnEliteCarbonTicketChange()
    local ownNumber = BagManager.GetItemCountById(UpViewRechargeType.EliteCarbonTicket)
    if this.ownEliteCarbonTicket then
        if ownNumber == this.ownEliteCarbonTicket then
            return
        end
    end
    if ownNumber >= this.gameSetting[1].HeroTimes then
        this.remainTime = 0
        return
    end
    if BagManager.bagDatas[UpViewRechargeType.EliteCarbonTicket] then
        this.ownEliteCarbonTicket = BagManager.GetItemCountById(UpViewRechargeType.EliteCarbonTicket)
        local lastGainTime = BagManager.bagDatas[UpViewRechargeType.EliteCarbonTicket].endingTime
        local currentTime = math.floor(GetTimeStamp())
        this.remainTime = this.gameSetting[1].RecoveryTime - (currentTime - lastGainTime)
    else
        this.ownEliteCarbonTicket = 0
        this.remainTime = this.gameSetting[1].RecoveryTime
    end
end

function this.InitCountDownProcess()
    this.OnEliteCarbonTicketChange()
end

-- 初始化已经打过的副本状态
function this.InitCarbonState(mapInfos)
    if mapInfos then
        
        for i = 1, #mapInfos do
            local data = {}
            data.stars = {}
            data.stars[1] = 0
            data.stars[2] = 0
            data.stars[3] = 0

            for j = 1, #mapInfos[i].stars do
                local star = mapInfos[i].stars[j]
                if not star then
                    star = 0
                end

                
                data.stars[j] = star
            end
            data.mapId = mapInfos[i].mapId
            for k, v in ConfigPairs(DifficultyData) do
                if (v.Id == data.mapId and v.Type == 3) then
                    this.difficultyMask[v.MapId] = v.DifficultType

                end
            end
            data.leastTime = mapInfos[i].leastTime
            --data.stars = mapInfos[i].stars
            this.CarbonInfo[data.mapId] = data
        end
    end
end

-- 任务完成的时候更新一下副本数据， 第一次打的副本没有信息
function this.Refresh(newestTime)
    local data = {}
    data.stars = {}
    data.mapId = 0
    data.leastTime = 0
    data.stars[1] = 0
    data.stars[2] = 0
    data.stars[3] = 0

    local mapId = MapManager.curMapId
    if this.CarbonInfo[mapId] then
        local lastTime = this.CarbonInfo[mapId].leastTime
        if newestTime ~= 0 and lastTime > 0 then
            data.leastTime = newestTime < lastTime and newestTime or lastTime
        else
            if lastTime > 0 then
                data.leastTime = lastTime
            else
                data.leastTime = newestTime
            end
        end
    else
        if newestTime > 0 then
            data.leastTime = newestTime
        end
    end

    data.mapId = mapId

    -- 当前完成的星数
    local curStars = 0
    -- ==========三星判断条件 ======================================
    -- 條件1
    if this.IsMissionDone() then
        data.stars[1] = 1
    else
        data.stars[1] = 0
    end

    -- 条件2
    if this.ExplorationDone() then
        data.stars[2] = 2
    else
        data.stars[2] = 0
    end

    -- 条件3
    if this.LessThanDeadTimes(mapId) then
        data.stars[3] = 3
    else
        data.stars[3] = 0
    end

    --===========================================================
    for i = 1, #data.stars do
        if data.stars[i] > 0 then
            curStars = curStars + 1
        end
    end

    -- 上一完成的星数
    local lastStars = 0
    if this.CarbonInfo[mapId] then
        -- 如果不是第一次图
        for i, v in pairs(this.CarbonInfo[mapId].stars) do
           
            if v > 0 then
                lastStars = lastStars + 1
            end
        end
    end

    local stars = curStars > lastStars and curStars or lastStars

    if not this.CarbonInfo[mapId] then
        this.CarbonInfo[mapId] = {}
        this.CarbonInfo[mapId].stars = {}
    end

    this.CarbonInfo[mapId].mapId = data.mapId
    this.CarbonInfo[mapId].leastTime = data.leastTime
    for i = 1, 3 do
        this.CarbonInfo[mapId].stars[i] = 0
    end

    for i = 1, stars do
       
        this.CarbonInfo[mapId].stars[i] = i
    end
    starNum = stars


end

-- 初始化普通副本状态
function this.InitNormalState(playedMapIds)
    if #playedMapIds == 0 then
        
    end
    for i = 1, #playedMapIds do
        
        this.playedMapId[playedMapIds[i]] = playedMapIds[i]
    end
end

-- 获取普通副本是否被玩过
function this.GetNormalState(mapId)
    local isPass = false
    if this.playedMapId[mapId] and this.playedMapId[mapId] ~= 0 then
        isPass = true
    else
        isPass = false
    end
    return isPass
end


--检查英雄副本是否解锁
function this.CheckCarbonUnLock(mapId)
    local openFight = DifficultyData[mapId].OpenRule[1][1]
    local openLevel = DifficultyData[mapId].OpenRule[1][2]
    if FightPointPassManager.IsFightPointPass(openFight) and PlayerManager.level >= openLevel then
        return true
    end
    return false
end
--检查英雄副本大副本是否解锁(传入MapId)
function this.CheckHeroCarbonUnLock(id,mapId)
    local mission={}
    mission = this.levelHero
    local unlockIndex=0
    if this.difficultyMask[id] == -1 then
        unlockIndex=1
    elseif this.difficultyMask[id] == 1 then
        unlockIndex=2
    elseif this.difficultyMask[id] == 2 then
        unlockIndex=3
    elseif this.difficultyMask[id] == 3 then
        unlockIndex=4
    elseif this.difficultyMask[id] == 4 then
        unlockIndex=4
    end
    local type=0
    for i,v in ipairs(mission) do
        if(mapId==v.Id) then
            type=v.DifficultType
        end
    end
    if(unlockIndex>=type) then
        return true
    else
        return false
    end
end

--得到最新开放的英雄本难度
function this.GetNewestMapId()
    local mission={}
    mission = this.levelHero
    local mapId=0
    for i,v in ipairs(mission) do
        if(this.CheckHeroCarbonUnLock(v.MapId,v.Id)) then
            mapId=v.Id
        end
    end
    return mapId
end







--检查剧情副本是否解锁
function this.CheckNormalUnLock(mapId)
    local isUnLock=false
    if mapId ~= 100 then
        if FightPointPassManager.IsFightPointPass(DifficultyData[mapId].OpenRule[1][1]) then
            isUnLock=true
            return isUnLock
        end
    end
    return isUnLock
end
--通过副本Id判断英雄的难度地图是否解锁
function this.CheckMapIdUnLock(mapId)
    for k, v in ConfigPairs(DifficultyData) do
        if(mapId==v.Id and (this.difficultyMask[v.MapId])==v.DifficultType-1 and v.DifficultType~=1) then
            return true
        end

        if(mapId==v.Id and this.difficultyMask[v.MapId]==-1 and v.DifficultType==1) then
            return true
        end
    end
    return false
end

--返回解锁ID
--mapId指每一个难度地图单独Id，id指英雄本大地图id(四个难度相同的哪个Id，其他剧情本等可不传入)
function this.NeedLockId(mapId,type,id)
    --剧情副本
    if(type==1) then
        local mapFinalId
        if mapId ~= -1 then
            if this.CheckNormalUnLock(mapId) then
                return mapId
            else
                for k, v in ConfigPairs(DifficultyData) do
                    if(v.Type==1 and  this.CheckNormalUnLock(v.Id)) then
                        mapFinalId=v.Id
                    end
                end
                return mapFinalId
            end
        else
            for k, v in ConfigPairs(DifficultyData) do
                if(v.Type==1 and  this.CheckNormalUnLock(v.Id)) then
                    mapFinalId=v.Id
                end
            end
            return mapFinalId
        end
    end
    --精英副本
    if(type==3) then
        if mapId ~= -1 then
            if this.CheckHeroCarbonUnLock(id,mapId) then
               
                return mapId
            else
                return this.GetNewestMapId()
            end
        else
            return this.GetNewestMapId()
        end
    end
end




-- 判断某一副本是否3星通关
function this.IsPerfectPass(mapId)
    local isPerfect = false
    if not this.CarbonInfo[mapId] then
        return
    end
    local starsNum = 0
    for i, v in pairs(this.CarbonInfo[mapId].stars) do
        if v and v ~= 0 then
            starsNum = starsNum + 1
        end
    end

    isPerfect = starsNum == 3
    return isPerfect
end

-- 副本中快速战斗数据解析
function this.InitQuickFightData(monsterGroupId, eventId, msg)
    local data = {}

    data.drop = msg.enventDrop
    data.missionDrop = msg.missionDrop
    data.result = msg.result
    data.mission = msg.mission
    if msg.lastXY then
        data.lastPos = msg.lastXY
    else
        data.lastPos = 0
    end

    if data.mission and data.mission.itemId > 0 then
        MissionManager.ParseMissionState(data.mission, false)
    end

    data.hpList = {}
    if msg.remainHpList then
        for i = 1, #msg.remainHpList do
            data.hpList[i] = msg.remainHpList[i]
        end
    end


    if msg.result == 0 then
        --战斗失败回城
        if OptionBehaviourManager.CurTriggerPanel then
            OptionBehaviourManager.CurTriggerPanel:ClosePanel()
        end

        -- 失败接受一下后端返回的位置
        local lastPos = data.lastPos
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.DeadOut, 0, lastPos)
        -- battledHp = 0
        if MapManager.curCarbonType == CarBonTypeId.ENDLESS then
            local teamData=FormationManager.GetFormationByID(FormationTypeDef.FORMATION_ENDLESS_MAP)  -- 核实关卡是否需要替补 参量偏移bug
            FormationManager.RefreshFormation(FormationTypeDef.FORMATION_ENDLESS_MAP,{},"",{supportId = SupportManager.GetFormationSupportId(FormationTypeDef.FORMATION_ENDLESS_MAP),
            adjutantId = AdjutantManager.GetFormationAdjutantId(FormationTypeDef.FORMATION_ENDLESS_MAP)},nil,teamData.formationId,function ()
                EndLessMapManager.RrefreshFormation()
            end)
        end
    else
        MapManager.RefreshFormationHp(data)
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChange, 2, 0, monsterGroupId)

        local strShow = {}
        this.ShowReward(data.drop, strShow)

        -- 如果掉落了奖励任务
        if this.IsMissionDone then
            if #data.missionDrop.itemlist > 0 or #data.missionDrop.equipId > 0 or #data.missionDrop.Hero > 0 then
                --UIManager.OpenPanel(UIName.MissionRewardPanel, data.missionDrop, 2, function()
                UIManager.OpenPanel(UIName.RewardItemPopup, data.missionDrop, 2, function()

                end, 2)
            end
        end

        -- 普通精英弹浮窗，其他弹恶心的结算界面
        local func = function()
            Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
            -- 试炼副本才有的字段
            if msg.essenceValue then
                -- 判断是否可寻路标志
                if msg.essenceValue >= 100 then
                    MapTrialManager.canMove = false
                else
                    MapTrialManager.canMove = true
                end
                -- -1添加Boss点 -2添加传送门点
                if MapTrialManager.powerValue >= 100 or MapTrialManager.powerValue == -1 or MapTrialManager.powerValue == -2 then
                    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointAdd, MapTrialManager.cell.cellId, MapTrialManager.cell.pointId)
                    Timer.New(function()
                        -- 刷新数据
                        Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
                    end, 0.5):Start()
                end
                MapTrialManager.UpdatePowerValue(msg.essenceValue)
            end
        end



        if this.difficulty == 1 or this.difficulty == 3 or this.difficulty == 4 then
            PopupText(strShow, 0.5, 2)
            for i = 1, #strShow do
                if strShow[i].configData.ItemType==30 and strShow[i].num~=0 then
                    local data= ConfigManager.GetConfigDataByKey(ConfigName.ExpeditionTotemConfig,"ItemId",strShow[i].configData.Id) 
                    local newTotemData={["totemId"]=data.Id,["heroServiceId"]=nil}
                    TotemManager.AddTotem(newTotemData)
                  end
            end
          
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, MapManager.curTriggerPos)
        elseif this.difficulty == 2 then
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, MapManager.curTriggerPos)
            UIManager.OpenPanel(UIName.RewardItemPopup,data.drop,1,func)
        end
        func = nil
        -- 试炼副本不能直接结束事件点
        if this.difficulty ~= 2 then
            Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
        end
    end

        -- 战前血量
        -- 战后血量 
        if MapManager.curCarbonType ~= CarBonTypeId.ENDLESS then
            local oldHp = this.GetMapTotalBlood()
            local battledHp = 0
            battledHp = this.GetMapTotalBlood()
    
            Game.GlobalEvent:DispatchEvent(GameEvent.Formation.OnMapTeamHpReduce, oldHp - battledHp)
        end
        Timer.New(function()
            -- 刷新数据
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
        end, 1):Start()
end

-- 判断某一类型副本得到的总星数
function this.GetStarNumByType(type)
   

    local starNum = 0
    for i, v in pairs(this.CarbonInfo) do


        if DifficultyData[i].Type == type then
            starNum = starNum + this.GetMapStars(i)
        end
    end
    return starNum
end
-- 某一副本的星数
function this.GetMapStars(mapId)
    local stars = 0
    for i = 1, 3 do
        if this.CarbonInfo[mapId].stars[i] > 0 then
            stars = stars + 1
        end
    end
    return stars
end

-- 获得道具
function this.ShowReward(drop, strTabel, callBack)
    local itemList = BagManager.GetItemListFromTempBag(drop, true)
    for i = 1, #itemList do
        local str = {}
        str.name = GetLanguageStrById(itemList[i].name)
        str.icon = Util.LoadSprite(itemList[i].icon)
        str.num = itemList[i].num
        str.configData=itemList[i].configData
        strTabel[#strTabel + 1] = str
    end

    if callBack then
        callBack()
    end
end

-- 游戏登录时获取所有的数据
function this.GetMissionLevelData()
    -- 初始化表数据额
    this.levelNormal = {}
    this.levelTrial = {}
    this.levelHero = {}
    this.levelLegend = {}

    --local datas = GameDataBase.SheetBase.GetKeys(DifficultyData)
    --local index=0
    for i, v in ConfigPairs(DifficultyData) do
        local type = v.Type
        if type == 1 then
            this.carbonType = type
            --index=index+1
            --this.levelNormal[index]= v
            if(v.Id~=100) then
                table.insert(this.levelNormal, v)
            end
        elseif type == 2 then
            table.insert(this.levelTrial, v)
        elseif type == 3 then
            table.insert(this.levelHero, v)
        elseif type == 4 then
            table.insert(this.levelLegend, v)
        else

        end
    end
    --for i = 1, #datas
    --
    --end
end

function this.GetCarBonMission()
    if this.difficulty == 1 then
        if this.levelNormal then
            return this.levelNormal
        end
    elseif this.difficulty == 2 then
        if this.levelTrial then
            return this.levelTrial
        end
    elseif this.difficulty == 3 then
        if this.levelHero then
            return this.levelHero
        end
    elseif this.difficulty == 4 then
        if this.levelLegend then
            return this.levelLegend
        end
    else


    end
end
--==================== 三星条件判定方法 ====================
-- 副本任务是否完成
function this.IsMissionDone()
    local isDone = MissionManager.MainMissionIsDone(MissionManager.carBonMission.id)
    return isDone
end

-- 任务是否在规定时间内完成
function this.DoneAtLimitTime()
    local isLimit = false
    -- 当前副本的ID， 就是当前地图的ID
    local id = MapManager.curMapId
    -- 通关限定时间
    local LimitTime = DifficultyData[id].Time

    local isMissionDone = this.IsMissionDone()
    if isMissionDone then
        local finishTime = MissionManager.carBonMission.doneTime
        if finishTime > LimitTime then
            isLimit = false
        else
            isLimit = true
        end
    end
    return isLimit
end

-- 探索度是否在100%
function this.ExplorationDone()
    local isDone = false
    if MapManager.allMapProgressList[MapManager.curMapId] then
        local exploreProgress = MapManager.allMapProgressList[MapManager.curMapId].totalWeight
        if exploreProgress >= 100 then
            isDone = true
        else
            isDone = false
        end
    end
    return isDone
end

-- 死亡次数小于某个地图的限定次数
function this.LessThanDeadTimes(mapId)
    local limitTimes = 0
    limitTimes = DifficultyData[mapId].Deaths
    local isDone = false
    if CarbonManager.difficult == 2 then
        -- 试炼副本
        isDone = true
    else
        isDone = this.IsMissionDone()
    end

    --local isFilled = MapManager.deadCount < limitTimes
    local isFilled = this.RoleDeadTimes < limitTimes
    isFilled = isFilled and isDone
    return isFilled
end

--= = = = = = = = = = = = = = = = = = = = = = = = = = = =

-- 将地图内的道具按新的方式存储
function this.GetMapItem()
    local mapItemList = {}
    local itemList = BagManager.mapShotTimeItemData
    local equipList = EquipManager.mapShotTimeItemData
    local heroList = HeroManager.mapShotTimeItemData

    -- 物品
    for i, v in pairs(itemList) do
        local item = {}
        item.id = v.itemId
        item.num = v.itemNum
        table.insert(mapItemList, item)
    end

    -- 装备
    for i = 1, #equipList do
        local item = {}
        item.id = equipList[i].equipId
        item.num = 1
        table.insert(mapItemList, item)
    end

    -- 英雄
    for i = 1, #heroList do
        local item = {}
        item.id = heroList[i].heroId
        item.num = 1
        table.insert(mapItemList, item)
    end

    return mapItemList
end

-- 判断某个副本地图是否被玩过
function this.IsMapPlayed(mapId)
   
    local isPlayed = false
    if this.CarbonInfo[mapId] then
        -- 地图玩过没通关
        if this.CarbonInfo[mapId].stars[1] > 0 or starNum > 0 then
            isPlayed = true
        else
            isPlayed = false
        end
    else
        -- 地图第一次玩
        isPlayed = false
    end
    return isPlayed
end

--领取副本星级奖励
function this.FbStarRewardRequest()
    NetManager.RequestFbStarReward(function(_drop)
        UIManager.OpenPanel(UIName.RewardItemPopup, _drop, 1)
        Game.GlobalEvent:DispatchEvent(GameEvent.Bag.BagGold)
        this.hasGetRewardCostStar = this.hasGetRewardCostStar + 3
        CheckRedPointStatus(RedPointType.NormalExplore_GetStarReward)
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.OnRefreshStarReward)
    end)
end

--将英雄副本的状态存到本地
function this.HeroCopyStateSetStr(_str, val)
    PlayerPrefs.SetString("heroCopy" .. _str, val)
end

--
--获得本地存储字符串
function this.HeroCopyStateGetStr(_str)
    return PlayerPrefs.GetString("heroCopy" .. _str, 0)
end

-- 检测精英副本红点状态, carbonId 为空时检测全部副本
function this.CheckEliteCarbonRedpot(carbonId)
    -- 检测副本红点的方法
    local function checkSingleCarbon(id)
        local taskInfoList = ConfigManager.GetAllConfigsDataByKey(ConfigName.AccomplishmentConfig, "MapId", id)
        for _, data in ipairs(taskInfoList) do
            local taskData = TaskManager.GetTypeTaskInfo(TaskTypeDef.EliteCarbonTask, data.id)
            if taskData and taskData.state == VipTaskStatusDef.CanReceive then
                return true
            end
        end
        return false
    end

    -- 检测单个副本
    if carbonId then
        return checkSingleCarbon(carbonId)
    end

    -- 检测整个精英副本
    if not this.levelHero then
        return false
    end
    for _, carbon in ipairs(this.levelHero) do
        if checkSingleCarbon(carbon.MapId) then
            return true
        end
    end
    return false
end

-- 红点检测方法
function this. CarbonRedCheck(redType)
    if not ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.DAILYCHALLENGE_COIN) then
        return false
    end
    --物资收集
    if redType == RedPointType.HeroExplore then    
        for k,v in pairs(this.GetDailyCarbons(0)) do 
            if v and v.state then
                return true
            end
        end
        return false
    --深渊试炼
    elseif redType == RedPointType.EpicExplore then
        -- if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.DAILYCHALLENGE_COIN) then 
           
        -- else
        --     return false
        -- end
        if DefenseTrainingManager.todayPassCount == 0 then
            return true
        end
        return false
    --遗忘之城
    elseif redType == RedPointType.ForgottenCity then
        -- if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.EXPEDITION) then 
        --     return TreasureOfHeavenManger.RedPoint()
        -- end
        -- return false
        -- return TreasureOfHeavenManger.RedPoint() or BlitzStrikeManager.difficultyLevel == nil
        return BlitzStrikeManager.difficultyLevel == nil or BlitzStrikeManager.difficultyLevel == 0
    --破碎王座
    elseif redType == RedPointType.LegendExplore then
        return HegemonyManager.isFirstOn

        -- if ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.Hegemony)
        -- and PlayerManager.familyId ~= 0
        -- and (GuildCarDelayManager.RefreshRedPoint(GuildCarDelayProType.Challenge) or GuildCarDelayManager.RefreshRedPoint(GuildCarDelayProType.Loot))
        -- then
        --     return true
        -- end
        -- return false
    end
end


--日常副本红点数据
--1 金币副本   2 经验副本   3角色碎片副本  4 每日法宝副本  5每日魂印副本   0全部
function this.GetDailyCarbons(index)
    if not this.dailyCarbons then
        this.dailyCarbons = {}
    end
    if index == 0 then
        for i = 1, 4 do
            this.GetCarBonState(i)
        end
        return this.dailyCarbons
    else
        this.GetCarBonState(index)
        return this.dailyCarbons[index]
    end  
end

function this.GetCarBonState(index)
    if not this.dailyCarbons[index] then
        this.dailyCarbons[index] = {}
        this.dailyCarbons[index].id = index + 66
    end
    local curData=ConfigManager.GetAllConfigsDataByKey(ConfigName.DailyChallengeConfig,"Type",index)
    --local buyTimeId= curData[1].PrivilegeId[1]
    local freeTimeId=curData[1].PrivilegeId[2]
    --local storeData=ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig,"StoreId",7,"Limit",buyTimeId)--商店表数据   
    --local buyTime= ShopManager.GetShopItemRemainBuyTimes(SHOP_TYPE.FUNCTION_SHOP,storeData.Id) --购买次数
    local freeTime=PrivilegeManager.GetPrivilegeRemainValue(freeTimeId) --免费次数
    if freeTime > 0 and ActTimeCtrlManager.SingleFuncState(this.dailyCarbons[index].id) then
        this.dailyCarbons[index].state = true 
    else
        this.dailyCarbons[index].state = false
    end
end
--普通副本红点进入地图入口检测方法
function this.CarbonRedShow()
    local isShow = false
    local mission = this.levelNormal
    if ActTimeCtrlManager.SingleFuncState(17) then
        for i = 1, #mission do
            local carbonId = mission[i].Id
            if (DifficultyData[carbonId].Type == 1) then
                local isCanShowRedPoint = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "normal" .. mission[i].MapId)
                if (isCanShowRedPoint == "0" and mission[i].MapId ~= 100 and this.CheckNormalUnLock(mission[i].MapId)) then
                    isShow = true
                end
            end
        end
        --local isCanShowNormalRedPoint = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "Normal")
        --if (isCanShowNormalRedPoint == "0") then
        --    isShow = true
        --end
    end
    return isShow
end
--普通副本红点领取星级奖励入口检测方法
function this.CarbonGetRewardRedShow()
    local isShow = false
    local mission = this.levelNormal
    local hasGetStarNumber=0
    if ActTimeCtrlManager.SingleFuncState(17) then
        for i = 1, #mission do
            local carbonId = mission[i].Id
            if (DifficultyData[carbonId].Type ==  1 and  this.CarbonInfo[carbonId]) and carbonId~=100 then
                for i = 1, #this.CarbonInfo[carbonId].stars do
                    local star = this.CarbonInfo[carbonId].stars[i]
                    if star ~= 0 then
                        hasGetStarNumber = hasGetStarNumber + 1
                    end
                end
            end
        end
        if ((hasGetStarNumber - this.hasGetRewardCostStar) >= 3) then
            isShow = true
        end
    end
    return isShow
end

--试炼副本开启红点检测
function  this.CarbonTrialOpen()
    local isShow = false
    if ActTimeCtrlManager.SingleFuncState(30) then
        local isCanShowTrialRedPoint = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "Trial")
        if(isCanShowTrialRedPoint=="0") then
            isShow=true
        end
    end
    return isShow
end
--英雄副本红点入口检测方法
function this.CarbonHeroRedShow()
    local isShow = false
    local mission = this.levelHero
    if ActTimeCtrlManager.SingleFuncState(18) then
        for i = 1, #mission do
            local carbonId = mission[i].Id
            if (DifficultyData[carbonId].Type == 3) then
                local isCanShowRedPoint = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "hero" .. carbonId)
                if isCanShowRedPoint == "0" and mission[i].MapId ~= 100 and this.CheckMapIdUnLock(carbonId) and this.CheckCarbonUnLock(carbonId) then
                    isShow = true
                end
            end
        end
    end
    return isShow
end

--精英副本功绩红点检测
function this.CheckHeroRedPoint()
    local isShow=this.CheckEliteCarbonRedpot()
    return isShow
end


-- 判断当前地图是否可以扫荡
function this.GetMapSweepState(mapId)
    local isPass = false
    if this.difficulty == 1 then -- 普通副本3星通过
        isPass = CarbonManager.IsPerfectPass(mapId)
    elseif this.difficulty == 3 then -- 精英副本功绩
        local MapDataId = DifficultyData[mapId].MapId
        local achiveNum, totalAchive = TaskManager.GetAchiveNum(MapDataId)
        if not DifficultyData[mapId].SweepingOpenRule then 

            return false 
        end
        isPass = achiveNum >= DifficultyData[mapId].SweepingOpenRule[2] and this.IsMapPass(mapId)
    end
    return isPass
end

-- 检测某一副本是否通关
function this.IsMapPass(mapId)
    local stars = this.GetMapStars(mapId)
    return stars > 0
end


-- 精英副本扫荡条件
function this.EliteSweepCondition(mapId)
    if not DifficultyData[mapId].SweepingOpenRule then 
        return
    end
    return DifficultyData[mapId].SweepingOpenRule[2]
end

-- 检测试炼副本层数奖励红点
function this.CheckTrialRedPoint()
    local haveRed = false
    local num = 0
    local rewardData = MapTrialManager.GetLevelReward()
    for i = 1, #rewardData do
        if rewardData[i].state == 1 then
            num = num + 1
        end
    end
    if num <= 0 then
        haveRed = false
    else
        haveRed = true
    end

    return haveRed
end

-- 是否是无尽副本
function this.IsEndlessCarbon()
    return this.difficulty == CARBON_TYPE.ENDLESS
end

-- 获取副本中编队的总血量
function this.GetMapTotalBlood()
    local totalHp = 0
    local curFormation = MapManager.formationList
    for i = 1, 5 do
        local heroData
        if curFormation[i] then
            heroData = HeroManager.GetSingleHeroData(curFormation[i].heroId)
            if not heroData then
               
                return
            end

            if curFormation[i].allProVal[2] > 0 then
                totalHp = totalHp + curFormation[i].allProVal[2]
            end
        end
    end
    return totalHp
end


--- 每日副本相关 ---
-- 增加计数
function this.AddDailyChallengeInfo(data)
    table.insert(this.dailyChallengeInfo,data)
end


return this