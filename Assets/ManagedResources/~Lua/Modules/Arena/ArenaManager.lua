ArenaManager = {};
local this = ArenaManager
local ArenaReward = ConfigManager.GetConfig(ConfigName.ArenaReward)
local ArenaSetting = ConfigManager.GetConfig(ConfigName.ArenaSetting)
function this.Initialize()
    this.arenaRewardKey = GameDataBase.SheetBase.GetKeys(ArenaReward)
    this.minRank = {}
    this.maxRank = {}
    this.dailyReward = {}
    this.seasonReward = {}
    this.GetArenaData()
    -- 是否跳过战斗
    this._IsSkipFight = nil
    -- 监听赛季结束事件
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionClose, function(openType)
        if openType == FUNCTION_OPEN_TYPE.ARENA then
            this.OnArenaClose()
        end
    end)
end

-- 竞技场赛季结束回调
function this.OnArenaClose()
    -- 重置红点
    ResetServerRedPointStatus(RedPointType.Arena_Record)
end

-- 获得竞技场奖励数据
function this.GetArenaData()
    for k, v in ConfigPairs(ArenaReward) do
        this.minRank[k] = v.MinRank
        this.maxRank[k] = v.MaxRank
        table.insert(this.dailyReward, v.DailyReward)
        table.insert(this.seasonReward, v.SeasonReward)
    end
end

this.ArenaInfo = {}
this.EnemyList = {}
this.hadTakeBox = {}--竞技场宝箱数据
-- 接受服务器竞技场基础数据
function this.ReceiveBaseArenaData(msg)
    this.ArenaInfo = msg.arenaInfo
    this.EnemyList = msg.arenaInfo.arenaEnemys
    for i = 1, #msg.arenaInfo.hadTakeBox do
        this.hadTakeBox[msg.arenaInfo.hadTakeBox[i]] = msg.arenaInfo.hadTakeBox[i]
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Arena.OnBaseDataChange)
end

this.ArenaRank = {}
this.MyRank = {}
this._CurPage = 0
-- 接受服务器竞技场排行基础数据
function this.ReceiveArenaRankData(page, msg)
    -- 初始竞技场排行数据时，同时请求排行榜点赞数据
    this.RequestTodayAlreadyLikeUids_Arena()

    this._CurPage = page
    if page == 1 then
        this.ArenaRank = {}
    end
    -- 构建自身排名数据
    this.MyRank.rank = msg.myRank
    this.MyRank.score = msg.myscore

    -- 计算排名数据列表
    local length = #this.ArenaRank
    for i, rank in ipairs(msg.rankInfos) do
        this.ArenaRank[length + i] = rank
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Arena.OnRankDataChange)
end

-- 请求下一页数据
-- forceRefresh 强制刷新数据会直接请求第一页数据
function this.RequestNextPageRank(forceRefresh)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
        PopupTipPanel.ShowTipByLanguageId(10082)
        return
    end
    -- 强制刷新第一页数据
    if forceRefresh then
        NetManager.RequestArenaRankData(1)
        return
    end
    --判断是否符合刷新条件
    local rankNum = #this.ArenaRank
    -- 最多显示
    local config = ConfigManager.GetConfigData(ConfigName.SpecialConfig, 4)
    local MaxNum = config and tonumber(config.Value) or 100
    if rankNum >= MaxNum then return end
    -- 上一页数据少于20条，则没有下一页数，不再刷新
    if rankNum % 20 > 0 then return end
    -- 请求下一页
    NetManager.RequestArenaRankData(this._CurPage + 1)
end

-- 请求挑战
function this.RequestArenaChallenge(index, isSkip, func)
    -- 判断剩余时间
    if this.GetLeftTime() <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10083)
        return
    end
    -- 获取挑战队伍，检测挑战队伍是否可用
    local teamId = FormationTypeDef.FORMATION_NORMAL--FormationTypeDef.FORMATION_ARENA_ATTACK
    local formationList = FormationManager.GetFormationByID(teamId)
    if #formationList.teamHeroInfos == 0 then
        PopupTipPanel.ShowTipByLanguageId(10084)
        return
    end
    -- 判断物品是否够
    local leftTimes = this.GetArenaChallengeTimes()
    if leftTimes <= 0 then
        local itemId, needNum = this.GetArenaChallengeCost()
        local haveNum = BagManager.GetItemCountById(itemId)
        if haveNum < needNum then
            UIManager.OpenPanel(UIName.QuickPurchasePanel, { type = UpViewRechargeType.ChallengeTicket })
            PopupTipPanel.ShowTipByLanguageId(10085)
            return
        end
    end

    -- 获取敌方uid
    if not this.EnemyList[index] then return end
    local enemy = this.EnemyList[index]

    -- 战斗信息
    local structA = {
        head = PlayerManager.head,
        headFrame = PlayerManager.frame,
        name = PlayerManager.nickName,
        formationId = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_NORMAL).formationId,
        investigateLevel = FormationCenterManager.GetInvestigateLevel()
    }
    local structB = {
        head = enemy.personInfo.head,
        headFrame = enemy.personInfo.headFrame,
        name = enemy.personInfo.name,
        formationId = enemy.personInfo.formationId or 1,
        investigateLevel = enemy.personInfo.investigateLevel
    }
    BattleManager.SetAgainstInfoData(nil, structA, structB)

    -- 请求挑战
    NetManager.RequestArenaChallenge(teamId, enemy.personInfo.uid, isSkip, function(msg)
        -- 基础数据变化
        this.ArenaInfo.score = this.ArenaInfo.score + msg.myScoreChange
        if msg.fightResult == 1 then
            this.ArenaInfo.successNums = this.ArenaInfo.successNums + 1
        else
            this.ArenaInfo.failNums = this.ArenaInfo.failNums + 1
        end
        -- 挑战次数变化
        if leftTimes > 0 then
            local privilege = ArenaSetting[1].BattleFree
            PrivilegeManager.RefreshPrivilegeUsedTimes(privilege, 1)
        else
            -- 刷新物品数量
            --改为后端刷新了
            --local itemId, needNum = this.GetArenaChallengeCost()
            --BagManager.UpdateItemsNum(itemId, needNum)
        end
        -- 新的敌人数据
        this.EnemyList = msg.arenaEnemys

        -- 刷新界面
        Game.GlobalEvent:DispatchEvent(GameEvent.Arena.OnBaseDataChange)
        --调用回调事件，关闭编队界面
        if func then func(msg) end

         --构建显示结果数据
        local arg = {}
        arg.result = msg.fightResult
        arg.blue = {}
        arg.blue.uid = PlayerManager.uid
        arg.blue.name = PlayerManager.nickName
        arg.blue.head = PlayerManager.head
        arg.blue.frame = PlayerManager.frame
        arg.blue.deltaScore = msg.myScoreChange
        arg.red= {}
        arg.red.uid = enemy.personInfo.uid
        arg.red.name = enemy.personInfo.name
        arg.red.head = enemy.personInfo.head
        arg.red.frame = enemy.personInfo.headFrame
        arg.red.deltaScore = msg.defScoreChange

        --- 判断是否要播放战斗回放
        local fightData = msg.fightData
        if isSkip == 0 then
            -- 播放完成后，打开结果界面
            this.RequestReplayRecord(msg.fightResult, fightData, nil,function()
                BattleRecordManager.SetBattleBothNameStr(PlayerManager.nickName.."|"..enemy.personInfo.name)
                UIManager.OpenPanel(UIName.ArenaResultPopup, arg, function ()
                    UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
                end)
            end)
        else
            -- 设置战斗数据用于统计战斗
            local _fightData = BattleManager.GetBattleServerData({fightData = fightData}, 1)
            BattleRecordManager.SetBattleRecord(_fightData)
            BattleRecordManager.SetBattleBothNameStr(PlayerManager.nickName.."|"..enemy.personInfo.name)
            -- 不用回放直接显示结果
            UIManager.OpenPanel(UIName.ArenaResultPopup, arg, function ()
                UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
            end)
        end
    end)
end

-- 请求新的对手数据
this._RefreshTimeStemp = 0
function this.RequestNewArenaEnemy()
    -- 判断剩余时间
    if this.GetLeftTime() <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10083)
        return
    end
    local curTimeStemp = GetTimeStamp()
    local limitTime = 3
    -- 计算距离下一次刷新剩余时间
    local lastTime = math.floor(limitTime - (curTimeStemp - this._RefreshTimeStemp))
    if this._RefreshTimeStemp ~= 0 and lastTime > 0 then
        PopupTipPanel.ShowTip(lastTime..GetLanguageStrById(10087))
        return
    end
    this._RefreshTimeStemp = curTimeStemp
    -- 请求刷新数据，并刷新显示
    NetManager.RequestNewArenaEnemy(function(msg)
        this.EnemyList = msg.arenaEnemys
        Game.GlobalEvent:DispatchEvent(GameEvent.Arena.OnBaseDataChange)
        PopupTipPanel.ShowTipByLanguageId(10088)
    end)
end

-- 请求获取竞技场防守数据  挑战数据
this.ArenaRecords = {}
-- this.ArenaRecordsChallenge = {}
function this.RequestArenaRecord()
    -- 请求刷新数据，并刷新显示
    NetManager.RequestArenaRecord(function(msg)
        this.ArenaRecords = msg.arenaRecordInfo
        table.sort(this.ArenaRecords, function(a,b)
            return a.attackTime > b.attackTime
        end)
        Game.GlobalEvent:DispatchEvent(GameEvent.Arena.OnRecordDataChange)
    end)

    --  -- 请求刷新数据，并刷新显示
    --  NetManager.RequestArenaRecordChallenge(function(msg)
    --     this.ArenaRecordsChallenge = msg.arenaRecordInfo
    --     table.sort(this.ArenaRecordsChallenge, function(a,b)
    --         return a.attackTime > b.attackTime
    --     end)
    --     Game.GlobalEvent:DispatchEvent(GameEvent.Arena.OnRecordDataChange)
    -- end)
end

-- 请求回放数据
function this.RequestRecordFightData(isWin, fightId, nameStr, func)
    NetManager.FightRePlayRequest(1, fightId, function(msg)
        local fightData = msg.fightData
        if not fightData then
            PopupTipPanel.ShowTipByLanguageId(10089)
            return
        end
        this.RequestReplayRecord(isWin, fightData, nameStr, func)
    end)
end

--- 请求开始播放回放
--- isWin 战斗结果 1 胜利 0 失败
--- fightData 战斗数据
--- nameStr 交战双方名称
--- doneFunc 战斗播放完成要回调的事件
function this.RequestReplayRecord(isWin, fightData, nameStr, doneFunc)
    BattleManager.GotoFight(function()
        UIManager.OpenPanel(UIName.BattleStartPopup, function()
            local fightData = BattleManager.GetBattleServerData({fightData = fightData}, 1)
            local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, doneFunc)
            battlePanel:ShowNameShow(isWin, nameStr)
        end)
    end)
end

-- 获取竞技场基础数据
function this.GetArenaBaseData()
    return this.ArenaInfo
end

-- 获取敌人数据
function this.GetEnemyList()
    return this.EnemyList
end

-- 获取排行榜信息
function this.GetRankInfo()
    local myRank = {}
    myRank.personInfo = {}
    myRank.personInfo.rank = this.MyRank.rank or -1
    myRank.personInfo.score = this.MyRank.score or this.ArenaInfo.score
    myRank.personInfo.level = PlayerManager.level
    myRank.personInfo.name = PlayerManager.nickName
    myRank.personInfo.head = PlayerManager.head
    myRank.personInfo.totalForce = FormationManager.GetFormationPower(FormationTypeDef.FORMATION_ARENA_DEFEND)
    myRank.team = {}
    myRank.team.heroTid = {}
    local formationList = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_ARENA_DEFEND)
    for i, hero in pairs(formationList.teamHeroInfos) do
        local heroTid = HeroManager.GetSingleHeroData(hero.heroId).id
        myRank.team.heroTid[i] = heroTid
    end
    return this.ArenaRank, myRank, this._CurPage
end

-- 获取竞技场剩余时间
function this.GetLeftTime()
    local leftTime = ActTimeCtrlManager.GetActLeftTime(8)
    leftTime = leftTime < 0 and 0 or leftTime
    return leftTime
end

-- 获取竞技场赛季名称
function this.GetArenaName()
    return ArenaSetting[1].AreanName
end

-- 获取竞技场剩余挑战次数
function this.GetArenaChallengeTimes()
    local privilege = ArenaSetting[1].BattleFree
    local allTimes = PrivilegeManager.GetPrivilegeNumber(privilege)
    local leftTimes = PrivilegeManager.GetPrivilegeRemainValue(privilege)
    return leftTimes, allTimes
end

-- 获取竞技场挑战消耗
function this.GetArenaChallengeCost()
    local itemId = ArenaSetting[1].Cost[1]
    local itemNum = ArenaSetting[1].Cost[2]
    return itemId, itemNum
end

-- 获取防守和挑战记录
function this.GetRecordList()
    return this.ArenaRecords--,this.ArenaRecordsChallenge
end

-- 判断是否要跳过战斗
function this.SetIsSkipFight(isSkip)
    this._IsSkipFight = isSkip or false
    PlayerPrefs.SetString(PlayerManager.uid .. "_Arena_IsSkipFight", tostring(this._IsSkipFight))
end
function this.IsSkipFight()
    if not this.CheckSkipFight() then
        return false
    end
    if not this._IsSkipFight then
        local isSkipStr = PlayerPrefs.GetString(PlayerManager.uid .. "_Arena_IsSkipFight")
        this._IsSkipFight = isSkipStr ~= "false" and true
    end
    return this._IsSkipFight
end
-- 检测跳过战斗是否可用
function this.CheckSkipFight()
    local isOpen = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.ArenaJump)
    return isOpen
end

-- 竞技场宝箱数据获取
function this.GetHadTakeBoxData()
    return this.hadTakeBox
end
-- 竞技场宝箱数据获取
function this.SetHadTakeBoxData(boxId)
    this.hadTakeBox[boxId] = boxId
end

this.TodayAlreadyLikeNum = 0
-- 当日已点赞uids
this.TodayAlreadyLikeUids_Arena = {}
function this.RequestTodayAlreadyLikeUids_Arena(func)
    NetManager.ArenaGetAllSendLikeResponse(function(msg)
        this.TodayAlreadyLikeUids_Arena = msg.uid
        this.TodayAlreadyLikeNum = #this.TodayAlreadyLikeUids_Arena
        if func then
            func(msg)
        end
     end)
end
function this.AddTodayAlreadyLikeUids_Arena(uid)
    if this.TodayAlreadyLikeUids_Arena[uid] then
        LogRed("已经点赞过了")
    else
        table.insert(this.TodayAlreadyLikeUids_Arena,uid)
        this.TodayAlreadyLikeNum = #this.TodayAlreadyLikeUids_Arena
    end
end
function this.GetTodayAlreadyLikeUids_Arena()
    return this.TodayAlreadyLikeUids_Arena
end
-- 当日是否已经点赞
function this.CheckTodayIsAlreadyLike(uid)
    for i = 1, #this.TodayAlreadyLikeUids_Arena do
        if this.TodayAlreadyLikeUids_Arena[i] == uid then
            return true
        end
    end
    return false
end
local isFistOpen = true
-- 点赞红点
function this.RefreshAlreadyLikeRedpoint()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
        return false
    end
    if isFistOpen then
        isFistOpen = false
        return true
    end
    local arenaData, myRankData = RankingManager.GetArenaInfo()
    local num = #arenaData
    if num > 10 then num = 10 end
    return this.TodayAlreadyLikeNum < num
end
return this