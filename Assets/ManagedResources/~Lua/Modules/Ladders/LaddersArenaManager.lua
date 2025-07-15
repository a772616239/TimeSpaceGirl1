LaddersArenaManager = {};
local this = LaddersArenaManager
local specialConfig = ConfigManager.GetConfig(ConfigName.SpecialConfig)
function this.Initialize()

end
this.drop = nil
this.newScore = nil
this.defchange = nil
local challeageTimeToday = 0

local ArenaInfo = {}
local EnemyList = {}
local stage
local endTime
local enterable
local isGroup
local maxRank

-- 接受服务器竞技场基础数据
function this.ReceiveBaseArenaData(msg)
    ArenaInfo = msg.arenaInfo
    EnemyList = msg.arenaInfo.arenaEnemys
    stage = msg.stage
    endTime = msg.endTime
    enterable = msg.enterable
    isGroup = msg.isGroup
    maxRank = msg.maxRank
    challeageTimeToday = msg.ackTimes
end

function this.FreeChallengeCount()
    local freeCount = specialConfig[109].Value
end

-- 获取跨服竞技场剩余时间
function this.GetLeftTime()
    local leftTime = ActTimeCtrlManager.GetActLeftTime(FUNCTION_OPEN_TYPE.laddersChallenge)
    leftTime = leftTime < 0 and 0 or leftTime
    return leftTime
end

-- 请求挑战
function this.RequestArenaChallenge(index, isSkip, func)
    -- 判断剩余时间
    if this.GetLeftTime() <= 0 then
        PopupTipPanel.ShowTip(GetLanguageStrById(10083))
        return
    end
    -- 获取挑战队伍，检测挑战队伍是否可用
    local teamId = FormationTypeDef.FORMATION_NORMAL--FormationTypeDef.FORMATION_ARENA_ATTACK
    local formationList = FormationManager.GetFormationByID(teamId)
    if #formationList.teamHeroInfos == 0 then
        PopupTipPanel.ShowTip(GetLanguageStrById(10084))
        return
    end

    -- 获取敌方uid
    if not EnemyList[index] then return end
    this.enemy = EnemyList[index]
    
    -- fightInfo
    local structA = {
        head = PlayerManager.head,
        headFrame = PlayerManager.frame,
        name = PlayerManager.nickName,
        formationId = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_NORMAL).formationId,
        investigateLevel = FormationCenterManager.GetInvestigateLevel()
    }
    local structB = {
        head = this.enemy.personInfo.head,
        headFrame = this.enemy.personInfo.headFrame,
        name = this.enemy.personInfo.name,
        formationId = this.enemy.personInfo.formationId or 1,
        investigateLevel = this.enemy.personInfo.investigateLevel
    }
    BattleManager.SetAgainstInfoData(nil, structA, structB)

    -- 请求挑战
    NetManager.GetWorldArenaChallengeRequest(teamId, this.enemy.personInfo.uid, this.enemy.personInfo.rank,ArenaInfo.score,0, function(msg)
        if msg.err == -1 then
            PopupTipPanel.ShowTip(GetLanguageStrById(50298))
            return
        end
        this.drop = msg.drop
        this.newScore = msg.arenaInfo.score
        this.defchange = msg.defchange
        this.fightResult = msg.fightResult
        -- 新的敌人数据

        --调用回调事件，关闭编队界面
        if func then func(msg) end

        --- 判断是否要播放战斗回放
        local fightData = msg.fightData
        if isSkip == 0 then
            -- 播放完成后，打开结果界面
            this.RequestReplayRecord(msg.fightResult, fightData, nil,function()
                BattleRecordManager.SetBattleBothNameStr(PlayerManager.nickName.."|"..this.enemy.personInfo.name)
            end)
        else
            -- 设置战斗数据用于统计战斗
            local _fightData = BattleManager.GetBattleServerData({fightData = fightData}, 1)
            BattleRecordManager.SetBattleRecord(_fightData)
            BattleRecordManager.SetBattleBothNameStr(PlayerManager.nickName.."|"..this.enemy.personInfo.name)
        end
        -- EnemyList = msg.arenaInfo.arenaEnemys
        -- ArenaInfo = msg.arenaInfo

        local formation = FormationManager.GetFormationByID(FormationTypeDef.LADDERS_DEFEND)
        if #formation.teamHeroInfos == 0 then
            FormationManager.RefreshFormationData(function()end)
        end
    end)
end

--获取状态
function this.GetStage()
    return stage
end

--获取竞技场基础数据
function this.GetArenaBaseData()
    return ArenaInfo
end

--获取敌人数据
function this.GetEnemyList()
    return EnemyList
end

--获取自身排名
function this.GetMyRank()
    return ArenaInfo.score
end

--获取最高成绩
function this.GetMaxRank()
    return maxRank
end

function  this.Enterable()
    return enterable
end
function this.GetGightResult()
    return this.fightResult
end

--获取免费次数
function this.GetFreeCount()
    --两部分构成 免费次数&道具个数
    local freeTime = tonumber(G_SpecialConfig[109].Value)
    local storeData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig,"StoreId",7,"Limit",PRIVILEGE_TYPE.BuyLADDERS)
    local itemNum = BagManager.GetTotalItemNum(storeData.Goods[1][1])
    if challeageTimeToday - freeTime >= 0 then
        return 0 + itemNum
    else
        return freeTime - challeageTimeToday + itemNum
    end
end

function this.GetCost()
    local storeData = ConfigManager.GetConfigDataByDoubleKey(ConfigName.StoreConfig,"StoreId",7,"Limit",PRIVILEGE_TYPE.BuyLADDERS)
    local count = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.BuyLADDERS)
    local ary = storeData.Cost[2]
    local addValue = ary[#ary-count+1]
    return storeData.Cost[1][1],addValue
end

function this.GetLaddarsAckTimes()
    return challeageTimeToday
end

function this.RefreshLaddarsAckTimes(time)
    challeageTimeToday = challeageTimeToday + time
end

--- 请求开始播放回放
--- isWin 战斗结果 1 胜利 0 失败
--- fightData 战斗数据
--- nameStr 交战双方名称
--- doneFunc 战斗播放完成要回调的事件
function this.RequestReplayRecord(isWin, fightData, nameStr, doneFunc)
    local fightData = BattleManager.GetBattleServerData({fightData = fightData}, 1)
    local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.Ladders_Challenge, doneFunc)
    battlePanel:ShowNameShow(isWin, nameStr)
    --firstCamp
end

-- 请求新的对手数据
this._RefreshTimeStemp = 0
function this.RequestNewArenaEnemy(func)
    -- 判断剩余时间
    if this.GetLeftTime() <= 0 then
        PopupTipPanel.ShowTip(GetLanguageStrById(10083))
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
    NetManager.GetWorldArenaInfoRequest(false,true,function(msg)
        EnemyList = msg.arenaInfo.arenaEnemys
        func()
        PopupTipPanel.ShowTip(GetLanguageStrById(10088))
    end)
end
return this