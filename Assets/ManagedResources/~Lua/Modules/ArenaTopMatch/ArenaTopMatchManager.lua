ArenaTopMatchManager = {}
local this = ArenaTopMatchManager
this.CurTabIndex = 0
this.curIsShowDoGuessPopup = false
local isChange = false
local stageNameTable = {
    [1] = 32 .. GetLanguageStrById(10097),--强
    [2] = 16 .. GetLanguageStrById(10097),--强
    [3] = 8 .. GetLanguageStrById(10097),--强
    [4] = 4 .. GetLanguageStrById(10097),--强
    [5] = GetLanguageStrById(10126),
    [8] = 32 .. GetLanguageStrById(10097),--强
    [9] = 16 .. GetLanguageStrById(10097),--强
    [10] = 8 .. GetLanguageStrById(10097),--强
    [11] = 4 .. GetLanguageStrById(10097),--强
    [12] = GetLanguageStrById(10126),
}
function this.Initialize()
    this.baseInfo = {}
    this.myBattleInfo = {}
    this.battleHistoryInfo = {}
    this.myTeamRankInfo = {}
    --- 竞猜数据
    this.isCanBet = false  -- 是否可以竞猜
    this.betBattleInfo = {}
    this.betRateInfo = {}
    this.myBetTarget = nil
    this.myBetCoins = 0
    this.process = nil
    this.betHistoryInfo = {}
    this.coinNum = 0 --竞猜币临时数据
    -- this.isGuessTipView=false--是否打开竞猜提示面板

    -- 淘汰赛数据
    this.EliminationData_32 = {}
    this.EliminationData_4 = {}

    --倍率
    this.rate = 1.5
    --奖励数据
    this.rewardData={}
    for k, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ChampionshipReward)) do
        table.insert(this.rewardData, v)
    end

    -- 拍脸完成，获取一次基础数据，判断是否需要弹出巅峰赛拍脸
    Game.GlobalEvent:AddEvent(GameEvent.PatFace.PatFaceSendFinish, function()
        this.RequestTopMatchBaseInfo()
    end)
    -- 赛季结束时获取下一赛季的数据
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionClose, function(typeId)
        if typeId == FUNCTION_OPEN_TYPE.TOP_MATCH then
            this.RequestTopMatchBaseInfo()
        end
    end)
end

--- 判断巅峰战是否激活
function this.IsTopMatchActive()
    return ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.TOP_MATCH)
end

--- 获取时间
function this.GetTopMatchTime()
    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.TOP_MATCH)
    if serData then
        return serData.startTime, serData.endTime
    end
    return
end

---=============巅峰战基础信息========================

-- 向服务器请求基础信息
function this.RequestTopMatchBaseInfo(func)
    -- 获取巅峰战信息
    NetManager.GetTopMatchBaseInfo(function(msg)
        if not this.baseInfo then
            this.baseInfo = {}
        end
        this.baseInfo.joinState = msg.joinState
        this.baseInfo.progress = msg.progress
        this.baseInfo.endTime = msg.endTime
        this.baseInfo.myrank = msg.myrank
        this.baseInfo.maxRank = msg.maxRank
        this.baseInfo.myscore = msg.myscore
        this.baseInfo.process = msg.process--2 胜 3 负 4 胜负 5 负胜 
        this.baseInfo.loser = msg.loser--是否被淘汰 

        this.myBattleInfo = msg.championBattleInfo
        
        isChange = false
        this.BaseDataEndTimeCountDown()
        this.RefreshBaseInfo()
        -- 发送更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.TopMatch.OnTopMatchDataUpdate)
        
        if func then func() end
    end)
end

-- 阶段信息刷新
function this.UpdateTopMatchStage(msg)
    -- 没有数据或者未开启时重新获取数据
    if not this.baseInfo or not this.baseInfo.progress or this.baseInfo.progress <= 0 then
        this.RequestTopMatchBaseInfo()
        return
    end

    -- 获取新的阶段信息
    this.baseInfo.progress = msg.progress
    this.baseInfo.endTime = msg.endTime
    this.BaseDataEndTimeCountDown()
    --         this.baseInfo.joinState, this.baseInfo.progress, this.baseInfo.endTime, this.baseInfo.myrank))

    -- 刷新基础信息
    this.RefreshBaseInfo()
    -- Game.GlobalEvent:DispatchEvent(GameEvent.TopMatch.OnTopMatchDataUpdate)
    -- --刷新排行信息
    -- Game.GlobalEvent:DispatchEvent(GameEvent.ATM_RankView.OnRankChange)
    
    
    -- 切换到准备阶段刷新一遍数据
    -- if this.baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_READY then
    --     this.RequestTopMatchBaseInfo()
    --     --this.RequestBetBaseInfo()
    --     -- 竞猜阶段刷新竞猜数据
    -- else
    if this.baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS then
        this.RequestTopMatchBaseInfo()
        this.RequestBetBaseInfo()
    -- 竞猜阶段刷新竞猜数据
    elseif this.baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS then
        this.RequestBetBaseInfo()
        -- 战斗阶段不刷新
        --elseif this.baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS then
        -- 切换到结算阶段刷新一遍所有数据
    elseif this.baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_END then
        this.RequestTopMatchBaseInfo()
        this.RequestBetBaseInfo(nil,true)
    end
    
    Game.GlobalEvent:DispatchEvent(GameEvent.TopMatch.OnTopMatchDataUpdate)
    --刷新排行信息
    Game.GlobalEvent:DispatchEvent(GameEvent.ATM_RankView.OnRankChange)
end

-- 获取战斗记录
function this.RequestBattleHistory(func)
    -- 获取巅峰赛战斗记录
    NetManager.GetTopMatchHistoryBattle(function(msg)
        this.battleHistoryInfo = msg.enemyPairInfo
        -- 对历史记录排序
        table.sort(this.battleHistoryInfo, function(a, b)
            return a.roundTimes > b.roundTimes
        end)

        if func then func() end

    end)
end

-- 获取选拔赛小组排名数据
function this.RequestMyTeamRank(func)
    -- 
    NetManager.GetTopMatchMyTeamRank(function(msg)
        this.myTeamRankInfo = msg.rankInfos
        -- 对历史记录排序
        table.sort(this.myTeamRankInfo, function(a, b)
            return a.personInfo.rank < b.personInfo.rank
        end)

        if func then func() end

    end)
end

-- 刷新基础信息
function this.RefreshBaseInfo()
    if this.baseInfo.progress == -1 then    -- 未开始
        this.baseInfo.battleStage = TOP_MATCH_STAGE.CLOSE
        this.baseInfo.battleTurn = -1
        this.baseInfo.battleState = TOP_MATCH_TIME_STATE.CLOSE

    elseif this.baseInfo.progress == -2 then    -- 已结束
        this.baseInfo.battleStage = TOP_MATCH_STAGE.OVER
        this.baseInfo.battleTurn = -2
        this.baseInfo.battleState = TOP_MATCH_TIME_STATE.OVER

    elseif this.baseInfo.progress > 0 then
        local oldState = this.baseInfo.battleState
        this.baseInfo.battleStage = tonumber(string.sub(this.baseInfo.progress, 1, 1))
        this.baseInfo.battleTurn = tonumber(string.sub(this.baseInfo.progress, 2, 2))
        this.baseInfo.battleState = tonumber(string.sub(this.baseInfo.progress, 3, 3))
        

        -- 判断阶段切换，并检测是否需要弹窗提示
        if UIManager.IsOpen(UIName.ArenaTopMatchPanel) then return end
        if not this.IsTopMatchActive() then return end
        if oldState ~= this.baseInfo.battleState then
            if this.baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_READY and this.baseInfo.joinState == 1 then
                --检测拍脸

                Game.GlobalEvent:DispatchEvent(GameEvent.PatFace.PatFaceSend,FacePanelType.Championship)
            elseif this.baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS then
                --检测拍脸

                Game.GlobalEvent:DispatchEvent(GameEvent.PatFace.PatFaceSend,FacePanelType.Championship)
            end
        end
    end

end


-- 获取巅峰战基础信息
function this.GetBaseData()
    this.ChangeData(this.CurTabIndex)
    return this.baseInfo
end

-- 获取对战信息
function this.GetBattleInfo()
    this.ChangeData(this.CurTabIndex)
    return this.myBattleInfo
end

-- 获取历史战斗记录
function this.GetBattleHistory()
    return this.battleHistoryInfo
end

-- 获取小组赛排名
function this.GetMyTeamRankInfo()
    return this.myTeamRankInfo
end

---  =================== end ==========================

---  ====================竞猜相关=======================
--- 获取竞猜基础数据   isPlayBattle  是否自动播放战斗
function this.RequestBetBaseInfo(func,isPlayBattle)
    -- 未开启
    if not this.IsTopMatchActive() then
        this.isCanBet = false
        if func then func() end
        return
    end
    -- 第一个准备阶段无竞猜信息
    if this.baseInfo.battleStage == TOP_MATCH_STAGE.CHOOSE
        and this.baseInfo.battleTurn == 1
        and this.baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_READY then
            this.isCanBet = false
            if func then func() end
            return
    end
    -- 积分赛不设置竞猜环节 32强才显示
    if this.baseInfo.battleStage~=TOP_MATCH_STAGE.ELIMINATION then
        this.isCanBet = false
        if func then func() end
        return
    end
    -- 获取巅峰战信息
    NetManager.GetBetMatchInfo(0, function(msg)
        this.betBattleInfo = msg.championBattleInfo
        isChange = false
        
        this.betRateInfo = msg.championBetInfo
        this.myBetTarget = msg.winUid
        this.myBetCoins = msg.myBetCoins
        
        this.process = msg.process
        
        

        -- 可以竞猜了
        this.isCanBet = true
        
        --
        Game.GlobalEvent:DispatchEvent(GameEvent.TopMatch.OnGuessDataUpdate)
        Game.GlobalEvent:DispatchEvent(GameEvent.TopMatch.OnGuessRateUpdate)
        
        if this.baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_END and isPlayBattle then
            
            --当历史战斗记录以决出胜负 说明此时是第三场  不需要自动播放战斗动画
            if not ArenaTopMatchManager.GetIsBattleEndState(this.CurTabIndex) then
                --推送信息的not时候判断是否需要播放动画
                Game.GlobalEvent:DispatchEvent(GameEvent.ATM_RankView.OnOpenBattle)
            end
        end
        if func then func() end
    end)
end

-- 刷新赔率信息
function this.RequestBetRateInfo(func)
    -- 未开启
    if not this.IsTopMatchActive() then
        return
    end
    -- 不在竞猜阶段不刷新
    if this.baseInfo.battleState ~= TOP_MATCH_TIME_STATE.OPEN_IN_GUESS then
        return
    end
    -- 积分赛不设置竞猜环节 32强才显示
    if this.baseInfo.battleStage~=TOP_MATCH_STAGE.ELIMINATION then return end
    -- 获取巅峰战信息
    NetManager.GetBetMatchInfo(1, function(msg)
        this.betRateInfo = msg.championBetInfo
        
        --
        Game.GlobalEvent:DispatchEvent(GameEvent.TopMatch.OnGuessRateUpdate)
        if func then func() end
    end)
end

-- 请求下注
function this.RequestBet(uid, coins, func)
    -- 未开启
    if not this.IsTopMatchActive() then
        return
    end
    -- 第一个准备阶段无竞猜信息
    if this.baseInfo.battleState ~= TOP_MATCH_TIME_STATE.OPEN_IN_GUESS then
        PopupTipPanel.ShowTipByLanguageId(10116)
        return
    end
    -- 判断竞猜币是否足够
    if coins == 0 then
        PopupTipPanel.ShowTipByLanguageId(10117)
        return
    end
    local guessCoinId = ArenaTopMatchManager.GetGuessCoinID()
    local haveNum = BagManager.GetItemCountById(guessCoinId)
    if coins > haveNum then
        PopupTipPanel.ShowTipByLanguageId(10118)
        return
    end
    -- 判断是否已经参与过竞猜
    if this.myBetTarget and this.myBetTarget ~= 0 then
        -- 已经参与过竞猜
        PopupTipPanel.ShowTipByLanguageId(10119)
        return
    end
    -- 获取巅峰战信息
    NetManager.RequestBet(uid, coins, function()
        -- 保存下注对象
        this.myBetTarget = uid
        -- 刷新
        Game.GlobalEvent:DispatchEvent(GameEvent.TopMatch.OnGuessDataUpdate)
        if func then func() end
    end)
end

function this.BetPlayerUid()
    if this.myBetTarget ~= 0 then
        return this.myBetTarget
    end
    return 0
end

-- 获取历史竞猜信息
function this.RequestBetHistory(func)

    -- 获取我得竞猜信息
    NetManager.GetBetHistoryInfo(function(msg)
        this.betHistoryInfo = msg.championMyBetDetails
        -- 对历史记录排序
        table.sort(this.betHistoryInfo, function(a, b)
            return a.enemyPairInfo.roundTimes > b.enemyPairInfo.roundTimes
        end)

        if func then func() end
    end)
end

-- 竞猜成功回调
-- function this.OnGuessSuccess(msg)
    
    -- if this.isLogin then return end--上来就弹新关卡界面 所以不弹
    -- if MapManager.isInMap or UIManager.IsOpen(UIName.BattlePanel) or UIManager.IsOpen(UIName.ArenaTopMatchPanel) then return end--在关卡里 副本里不弹 新加巅峰赛界面不弹
    -- UIManager.OpenPanel(UIName.GuessCoinDropPopup, msg.roundTimes, msg.itemId, msg.itemNum)
-- end

-- 判断是否可以竞猜
function this.IsCanBet()
    return this.isCanBet
end

--- 获取竞猜战斗信息
function this.GetBetBattleInfo()
    this.ChangeData(this.CurTabIndex)
    return this.betBattleInfo
end
--- 获取赔率信息
function this.GetBetRateInfo()
    return this.betRateInfo
end
--- 获取我下注的对象
function this.GetMyBetTarget()
    return this.myBetTarget
end
--- 获取我下注的竞猜币数量
function this.GetMyBetCoins()
    return this.myBetCoins
end
--- 获取竞猜三局两胜数据
function this.GetProcess()
    return this.process
end
-- 获取历史竞猜记录
function this.GetBetHistory()
    return this.betHistoryInfo
end

-- 设置竞猜币数量
function this.SetCoinNum(num)
    this.coinNum=num
end

-- 获取竞猜币数量
function this.GetCoinNum()
    return this.coinNum
end
---  =================== end ==========================

--- ======================32强赛数据=====================

--- 请求淘汰赛数据(32强)
function this.Request_32_EliminationData(func)
    -- 未开启
    if not this.IsTopMatchActive() then return end
    --
    if this.baseInfo.battleStage ~= TOP_MATCH_STAGE.ELIMINATION and this.baseInfo.battleStage ~= TOP_MATCH_STAGE.OVER then return end

    NetManager.GetTopMatchEliminationInfo(1, function(msg)

        -- for i = 1, #msg.championBattlePairInfo do
            -- LogError("attackInfo.uid:".. msg.championBattlePairInfo[i].attackInfo.uid..
            -- "    defInfo.uid:".. msg.championBattlePairInfo[i].defInfo.uid..
            -- "    fightResult:".. msg.championBattlePairInfo[i].fightResult)
            -- LogError("attackInfo.head:".. msg.championBattlePairInfo[i].attackInfo.head)
        -- end

        this.EliminationData_32 = this.RequestEliminationDataMerge(msg.championBattlePairInfo)
        -- this.EliminationData_32 = msg.championBattlePairInfo
        if func then func() end
    end)
end

--- 请求淘汰赛数据（4强）
function this.Request_4_EliminationData(func)
    -- 未开启
    if not this.IsTopMatchActive() then return end
    --
    if this.baseInfo.battleStage ~= TOP_MATCH_STAGE.ELIMINATION and this.baseInfo.battleStage ~= TOP_MATCH_STAGE.OVER then return end

    NetManager.GetTopMatchEliminationInfo(2, function(msg)
        -- this.EliminationData_4 = msg.championBattlePairInfo
        
        for i = 1, #msg.championBattlePairInfo do
            
        end
        this.EliminationData_4 = this.RequestEliminationDataMerge(msg.championBattlePairInfo)
        
        if func then func() end
    end)
end
--32 16 8 4 强数据合并
--三局两胜  需要将三局 或者两局数据  合并 算出战斗结果  胜利 失败 未打   和  竞猜结果  只要有过1就等于1
function this.RequestEliminationDataMerge(EliminationData)
    local newEliminationData = {}
    for EliminationDataI, EliminationDataV in ipairs(EliminationData) do
        local curKey = tonumber(tostring(EliminationDataV.roundTImes)..tostring(EliminationDataV.teamId)..tostring(EliminationDataV.position))
        if newEliminationData[curKey] then
            table.insert(newEliminationData[curKey],EliminationDataV)
        else
            newEliminationData[curKey] = {}
            table.insert(newEliminationData[curKey],EliminationDataV)
        end
    end
    
    local datas = {}
    for newEliminationDataI, newEliminationDataV in pairs(newEliminationData) do
        
        if newEliminationDataV and #newEliminationDataV > 0 then
            local singledata = newEliminationDataV[1]
            -- singledata.dataList = newEliminationDataV
            local fightResult = -1 ---1 无记录 0前两场负 1 前两场胜 2 胜 3 负 4 胜负 5 负胜 
            if #newEliminationDataV >= 2 then 
                for i = 1, #newEliminationDataV do
                    if i == 1 and newEliminationDataV[i].fightResult == 0 then
                        fightResult = 3
                    elseif i == 1 and newEliminationDataV[i].fightResult == 1 then
                        fightResult = 2
                    elseif i == 1 and newEliminationDataV[i].fightResult == -1 then
                        fightResult = -1
                    end
                    if i == 2 and newEliminationDataV[i].fightResult == 0 then
                        if fightResult == 3 then
                            fightResult = 0
                        elseif fightResult == 2 then
                            fightResult = 4
                        end
                    elseif i == 2 and newEliminationDataV[i].fightResult == 1 then
                        if fightResult == 3 then
                            fightResult = 5
                        elseif fightResult == 2 then
                            fightResult = 1
                        end
                    elseif i == 2 and newEliminationDataV[i].fightResult == -1 then
                        fightResult = -1
                    end
                    if i == 3  then
                        if fightResult == 4 then
                            fightResult = newEliminationDataV[i].fightResult
                        elseif fightResult == 5 then
                            fightResult = newEliminationDataV[i].fightResult
                        end
                    elseif i == 3 and newEliminationDataV[i].fightResult == -1 then
                        if fightResult == 4 or fightResult == 5 then
                            fightResult = -1
                        end
                    end
                    if newEliminationDataV[i].isGUess <= 0 then
                        singledata.isGUess = newEliminationDataV[i].isGUess
                    end
                end
            end
            singledata.fightResult = fightResult
            
            
            -- newEliminationData_32V = singledata
            table.insert(datas,{_singleData = singledata,_listData = newEliminationDataV})
        end
    end
    table.sort(datas, function(a, b)
        if a._singleData.roundTImes == b._singleData.roundTImes then
            if a._singleData.teamId == b._singleData.teamId then
                return a._singleData.position < b._singleData.position
            else
                return a._singleData.teamId < b._singleData.teamId
            end
        else
            return a._singleData.roundTImes < b._singleData.roundTImes
        end
    end)
    return     datas
end
--- 获取32强数据
function this.Get_32_EliminationData()
    -- body
    return this.EliminationData_32
end
-- 获取4强数据
function this.Get_4_EliminationData()
    -- body
    return this.EliminationData_4
end


---  =================== end ==========================


-- ==================== 其他接口==========================
-- 请求回放数据
function this.RequestRecordFightData(result, fightId, nameStr, func)
    NetManager.FightRePlayRequest(2, fightId, function(msg)
        local fightData = msg.fightData
        if not fightData then
            PopupTipPanel.ShowTipByLanguageId(10089)
            return
        end
        -- local nameStr = fight.attackName.."|"..fight.defName
        this.RequestReplayRecord(result, fightData, nameStr, func)
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

-- 获取当前阶段名称
function this.GetCurTopMatchName()
    -- LogPink("```````````````````````````````````````````````````")
    -- LogPink("this.baseInfo.progress                "..this.baseInfo.progress)
    local titleName = GetLanguageStrById(10121)--逐胜之巅
    local stageName = ""
    if this.baseInfo.progress == -1 then
        return titleName, GetLanguageStrById(10122), GetLanguageStrById(10123)--未开始  即将开始
    elseif this.baseInfo.progress == -2 then
        return titleName, GetLanguageStrById(10124), GetLanguageStrById(10124)--已结束
    end

    if this.baseInfo.battleStage == TOP_MATCH_STAGE.CHOOSE then
        stageName = GetLanguageStrById(10125)..NumToSimplenessFont[this.baseInfo.battleTurn]--选拔赛
    else
        local maxTurn = this.GetEliminationMaxRound()
        local curTurn = this.baseInfo.battleTurn
        
        local opTurn = maxTurn - curTurn + 1 --- 将服务器发过来的轮数倒序，方便计算
        
        if opTurn == 1 then
            stageName = GetLanguageStrById(10126)--决赛
        else
            stageName = math.pow(2, opTurn) .. GetLanguageStrById(10097)--强
        end
        -- stageName = stageNameTable[this.baseInfo.battleTurn] or GetLanguageStrById(12243)..this.baseInfo.battleTurn
    end
    local stateName = TOP_MATCH_STATE_NAME[this.baseInfo.battleState] or GetLanguageStrById(10127)--未知
    return titleName, stageName, stateName
end

-- 通过总轮数获取当前阶段名称
function this.GetTurnNameByRoundTimes(roundTimes,curTurn)
    
    if not roundTimes or roundTimes <= 0 then
        return GetLanguageStrById(10122)
    end
    -- 选拔赛
    local maxRound = this.GetChooseMaxRound()
    if roundTimes <= maxRound then
        return GetLanguageStrById(10125)..NumToSimplenessFont[roundTimes]
    else
        -- 淘汰赛
        return stageNameTable[roundTimes]  or GetLanguageStrById(12243)..this.baseInfo.battleTurn
    end
    
    -- local curTurn = roundTimes - maxRound   -- 当前淘汰赛轮数
    -- local maxTurn = this.GetEliminationMaxRound()
    -- local opTurn = maxTurn - curTurn + 1 --- 将服务器发过来的轮数倒序，方便计算
    
    -- if opTurn == 1 then
    --     return GetLanguageStrById(10126)
    -- else
    --     return math.pow(2, opTurn) .. GetLanguageStrById(10097)
    -- end
    return GetLanguageStrById(10127)
end

-- 获取选拔赛最大轮数
local CHOOSE_MAX_ROUND
function this.GetChooseMaxRound()
    if not CHOOSE_MAX_ROUND then
        CHOOSE_MAX_ROUND = ConfigManager.GetConfigData(ConfigName.ChampionshipSetting, 1).TrialsGroup - 1--选拔赛最大轮数 = 每组人数 - 1
    end
    return CHOOSE_MAX_ROUND
end
-- 获取淘汰赛最大轮数
local ELIMINATION_MAX_ROUND
function this.GetEliminationMaxRound()
    if not ELIMINATION_MAX_ROUND then
        local config = ConfigManager.GetConfigData(ConfigName.ChampionshipSetting, 1)
        local eliminationNum = config.ChampionshipPlayer/config.TrialsGroup*config.TrialsGroupWinner    -- 参与淘汰赛得人数
        ELIMINATION_MAX_ROUND = math.log(eliminationNum, 2)
    end
    return ELIMINATION_MAX_ROUND
end

-- 获取选拔赛每场积分变化值常量
function this.GetMatchDeltaIntegral()
    return ConfigManager.GetConfigData(ConfigName.ChampionshipSetting, 1).WinnerIntegral
end

-- 通过排名获取相应的排名位置
function this.GetRankNameByRank(rank)
    --
    
    if rank <= 0 then return GetLanguageStrById(10041) end--未上榜
    local curStage = this.baseInfo.battleStage
    local curTurn = this.baseInfo.battleTurn
    local curState = this.baseInfo.battleState
    
    --- 未获取到数据
    if curStage == -1 or curTurn == -1 or curState == -1 then
        return GetLanguageStrById(10041)
    end
    --- 选拔赛阶段都是相应得强数
    -- if curStage == 1 then
    --     local config = ConfigManager.GetConfigData(ConfigName.ChampionshipSetting, 1)
    --     return config.ChampionshipPlayer..GetLanguageStrById(10097)
    -- -- 判断淘汰赛阶段的轮数
    -- elseif curStage == 2 or  curStage == -2 then
    --     -- if curState == TOP_MATCH_TIME_STATE.OPEN_IN_END or curState == TOP_MATCH_TIME_STATE.OVER then
    --     if rank == 1 then
    --         return GetLanguageStrById(10095)--冠军
    --     elseif rank == 2 then
    --         return GetLanguageStrById(10096)--亚军
    --     end
    --     return rank..GetLanguageStrById(10097)--几强
    -- elseif curStage == -1 then
    --     return  GetLanguageStrById(10041)
    -- end
    -- 选拔赛阶段都是相应得强数
    if curStage == 1 then
        local config = ConfigManager.GetConfigData(ConfigName.ChampionshipSetting, 1)
        return config.ChampionshipPlayer..GetLanguageStrById(10097)
    end
    --- 判断淘汰赛阶段的轮数
    local maxTurn = this.GetEliminationMaxRound()
    
    if curTurn <= 0 then curTurn = maxTurn end
    local opTurn = maxTurn - curTurn + 1 --- 将服务器发过来的轮数倒序，方便计算
    --- 如果是结算状态，按下一轮处理
    
    if curState == TOP_MATCH_TIME_STATE.OPEN_IN_END or curState == TOP_MATCH_TIME_STATE.OVER then
        opTurn = opTurn - 1
    end
    
    --- 轮数为0表示决赛的结算阶段
    if opTurn == 0 then
        if rank == 1 then
            return GetLanguageStrById(10095)--冠军
        elseif rank == 2 then
            return GetLanguageStrById(10096)--亚军
        end
    end
    --- 如果大于淘汰赛最大轮数的最大名次
    if rank > math.pow(2, maxTurn) then
        local config = ConfigManager.GetConfigData(ConfigName.ChampionshipSetting, 1)
        
        return config.ChampionshipPlayer..GetLanguageStrById(10097)--几强
    end
    --- 如果小于当前轮数的最大排名，则返回当前轮数的名称
    local opTurnMaxRank = math.pow(2, opTurn)
    if rank <= opTurnMaxRank then
        
        return tonumber(opTurnMaxRank) ..GetLanguageStrById(10097)
    end
    --- 如果大于当前的轮数，则可能已被淘汰，返回相应的被淘汰轮数的名称
    for turn = opTurn + 1, maxTurn do
        local turnMaxRank = math.pow(2, turn)
        if rank <= turnMaxRank then
            
            return tonumber(turnMaxRank)..GetLanguageStrById(10097)
        end
    end
    -- 数据没错的情况下不会出现这种情况
    return GetLanguageStrById(10041)
end

-- 竞猜币ID
function this.GetGuessCoinID()
    return 77
end

-- -- 是否可换阵容
function this.CanChangeTeam()
    if this.myBattleInfo.result ~= -1 then
        return false
    end
    local state = this.baseInfo.battleState -- 当前阶段状态
    local isJoin = this.baseInfo.joinState == 1 -- 参与状态
    if isJoin and state == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS then
        return true
    end
    return false
end
---  =================== end ==========================

-----淘汰赛相关-----


-------------------

-----巅峰战排名相关-----
this.rankData={}--排行滚动数据
this.myRankData={} --我的数据
this.requestCountDown=1--允许请求倒计时
this.requestTimer=nil--允许请求计时器
this.CurPage=0

--请求排名数据
function this.RequestRankData(page,func)
    -- if this.CurPage >= page or #this.rankData>128 then return end
    -- this.CurPage=page

    --防连续切标签不断请求数据
    --if this.requestTimer~=nil then return end
    --this.requestTimer = Timer.New(function()
    --    this.requestCountDown=this.requestCountDown-1
    --    if this.requestCountDown<0 then
    --        this.requestCountDown=0
    --        this.requestTimer:Stop()
    --        this.requestTimer=nil
    --        this.requestCountDown=1
    --    end
    --end, 1,-1)
    --this.requestTimer:Start()

    --if this.baseInfo.battleStage== TOP_MATCH_STAGE.ELIMINATION
    --        and this.baseInfo.battleTurn > 0
    --        or this.baseInfo.battleStage == TOP_MATCH_STAGE.OVER then
    NetManager.GetTopMatchRankInfo(page,function(msg)
        this.myRankData=msg.myInfo.personInfo
        if page==1 then
            this.rankData={}
        end
        local length=#this.rankData
        for i, v in ipairs(msg.rankInfos) do
            if v.personInfo.rank<=8 then
                
                this.rankData[length+i]=v.personInfo
            end
        end
        if func then
            func()
        end
        -- for i, v in pairs(this.rankData) do
        
        -- end
        
        -- Game.GlobalEvent:DispatchEvent(GameEvent.ATM_RankView.OnRankChange)
    end)
    --end
end
--获取排行数据
function this.GetRankData()
    return this.rankData,this.myRankData
end
--请求下页数据
function this.GetNextRankData()
   
    --判断是否符合刷新条件
    local MaxNum =  128
    if #this.rankData >= MaxNum then return end
    --上一页数据少于20条，则没有下一页数，不再刷新
    if #this.rankData % 20 > 0 then
        return
    end
    this.RequestRankData(this.CurPage + 1)
end
----------------------

-----巅峰战奖励相关-----
--获取奖励数据
function this.GetRewardData()
    return this.rewardData
end
--三局两胜获取显示数据
function this.GetTwoOutOfThreeInfo(type)
    local oldTwoOutOfThreeIndex = nil---历史记录(上次的结果 当前胜负根据战斗结果判断)  -1 无记录 0前两场负 1 前两场胜 2 胜 3 负 4 胜负 5 负胜 
    local curBattleResult = nil--当前胜负 -1 未开始 0 负 1 胜
    if type == 1 then--我的
        oldTwoOutOfThreeIndex = this.GetBaseData().process
        curBattleResult = this.GetBattleInfo().result
    elseif type == 2 then--竞猜
        oldTwoOutOfThreeIndex = this.GetProcess()
        curBattleResult = this.GetBetBattleInfo().result
    end
    
    if curBattleResult then
        
    end
    if oldTwoOutOfThreeIndex == -1 then--无记录
        if not curBattleResult then  
            
            return 0,0
        else
            if curBattleResult == -1 then
                
                return 0,0
            elseif curBattleResult == 0 then
                
                return 0,1
            elseif curBattleResult == 1 then
                
                return 1,0
            end
        end
    elseif oldTwoOutOfThreeIndex == 2 then--胜
        if not curBattleResult then  
            
            return 1,0
        else
            if curBattleResult == -1 then
                
                return 1,0
            elseif curBattleResult == 0 then
                
                return 1,1
            elseif curBattleResult == 1 then
                
                return 2,0
            end
        end
    elseif  oldTwoOutOfThreeIndex == 3  then--负
        if not curBattleResult then  
            
            return 0,1
        else
            if curBattleResult == -1 then
                
                return 0,1
            elseif curBattleResult == 0 then
                
                return 0,2
            elseif curBattleResult == 1 then
                
                return 1,1
            end
        end
    elseif  oldTwoOutOfThreeIndex == 4  then--胜负
        if not curBattleResult then  
            
            return 1,1
        else
            if curBattleResult == -1 then
                
                return 1,1
            elseif curBattleResult == 0 then
                
                return 1,2
            elseif curBattleResult == 1 then
                
                return 2,1
            end
        end
    elseif  oldTwoOutOfThreeIndex == 5  then--负胜
        if not curBattleResult then  
            
            return 1,1
        else
            if curBattleResult == -1 then
                
                return 1,1
            elseif curBattleResult == 0 then
                
                return 1,2
            elseif curBattleResult == 1 then
                
                return 2,1
            end
        end
    elseif  oldTwoOutOfThreeIndex == 0  then--负负
        
        return 0,2
    elseif  oldTwoOutOfThreeIndex == 1  then--胜胜
        
        return 2,0
    end
    return 0,0
end
--获取当前三局两胜是否结束
function this.GetIsBattleEndState(type)
    local oldTwoOutOfThreeIndex = nil---历史记录(上次的结果 当前胜负根据战斗结果判断)  -1 无记录 0前两场负 1 前两场胜 2 胜 3 负 4 胜负 5 负胜 
    if type == 1 then--我的
        oldTwoOutOfThreeIndex = this.GetBaseData().process
    elseif type == 2 then--竞猜
        oldTwoOutOfThreeIndex = this.GetProcess()
    end
    
    local baseData = ArenaTopMatchManager.GetBaseData()
    -- 没开启或者开启没参赛都属于未参赛
    local isJoin = baseData.joinState == 1
    local isOver = baseData.progress == -2
    if (oldTwoOutOfThreeIndex == 0 or oldTwoOutOfThreeIndex == 1) and isJoin and not isOver then
        return true
    else
        return false
    end
end
--屏幕索引  没啥用了
function this.SetCurTabIndex(index)
    this.CurTabIndex = index
end
function this.GetCurTabIndex()
    return this.CurTabIndex
end
--是否显示竞猜结果
function this.SetcurIsShowDoGuessPopup(isShow)
    
    this.curIsShowDoGuessPopup = isShow
end
function this.GetcurIsShowDoGuessPopup()
    return this.curIsShowDoGuessPopup
end


local old_baseInfo_battleState = 0--状态 准备 还是  战斗
local old_baseInfo_endTime = 0--倒计时时间戳
local old_myBattleInfo_result = 0--我的当前战斗结果
local old_betBattleInfo_result = 0--竞猜当前战斗结果
--当第三场不需要时  需要先端自己改变数据
function this.ChangeData(type)
    -- if true then return end
    if not type then return end
    local isJoin = this.baseInfo.joinState == 1
    local isOver = this.baseInfo.progress == -2
    if not isJoin or isOver or this.baseInfo.battleStage ~= TOP_MATCH_STAGE.ELIMINATION or this.baseInfo.loser then return end
    local oldTwoOutOfThreeIndex = nil---历史记录(上次的结果 当前胜负根据战斗结果判断)  -1 无记录 0前两场负 1 前两场胜 2 胜 3 负 4 胜负 5 负胜 
    if type == 1 then--我的
        oldTwoOutOfThreeIndex = this.baseInfo.process
    elseif type == 2 then--竞猜
        oldTwoOutOfThreeIndex = this.GetProcess()
    end
    if oldTwoOutOfThreeIndex == 0 or oldTwoOutOfThreeIndex == 1 then
        if not isChange then
            old_baseInfo_battleState = this.baseInfo.battleState
            old_baseInfo_endTime = this.baseInfo.endTime

            this.baseInfo.battleState = TOP_MATCH_TIME_STATE.OPEN_IN_END
            this.baseInfo.endTime = PlayerManager.serverTime
            if type == 1 then--我的
                old_myBattleInfo_result = this.myBattleInfo.result
                this.myBattleInfo.result = oldTwoOutOfThreeIndex--1
            elseif type == 2 then--竞猜
                old_betBattleInfo_result = this.betBattleInfo.result
                this.betBattleInfo.result = oldTwoOutOfThreeIndex--1
            end
            isChange = true
        else
            --不动
        end
    else
        if not isChange then
            --不动
        else
            this.baseInfo.battleState = old_baseInfo_battleState
            this.baseInfo.endTime = old_baseInfo_endTime

            if type == 1 then--我的
                this.myBattleInfo.result = old_myBattleInfo_result
            elseif type == 2 then--竞猜
                this.betBattleInfo.result = old_betBattleInfo_result
            end
            isChange = false
        end
    end
end
this.timer =  Timer.New() 
--计时弹竞猜结果
function this.BaseDataEndTimeCountDown()
    -- 计时器
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    if not this.timer then
        local function _UpdateTime()
            local isOpen = ArenaTopMatchManager.IsTopMatchActive()
            if this.baseInfo.progress == -2 then
                return
            end
            if isOpen then
                local leftTime = this.baseInfo.endTime - PlayerManager.serverTime
                if leftTime <= 3 then
                    -- Game.GlobalEvent:DispatchEvent(GameEvent.TopMatch.OnGuessDataUpdateShowTip) 
                    this.RefreshGuessTipView()
                end
                if leftTime <= 0 then
                    if this.timer then
                        this.timer:Stop()
                        this.timer = nil
                    end
                end
            end
        end
        _UpdateTime()
        this.timer = Timer.New(_UpdateTime, 1 , -1, true)
        this.timer:Start()
    end
end
--刷新竞猜提示
function this.RefreshGuessTipView()
    if this.isLogin then return end--上来就弹新关卡界面 所以不弹
    if MapManager.isInMap or UIManager.IsOpen(UIName.BattlePanel) then return end--在关卡里 副本里不弹 
    local IsCanBet = ArenaTopMatchManager.IsCanBet()
    if IsCanBet then   -- 判断是否有竞猜信息
        local myBetTarget = ArenaTopMatchManager.GetMyBetTarget()
        local IsBeted = myBetTarget and myBetTarget ~= 0
        local isShow = ArenaTopMatchManager.GetcurIsShowDoGuessPopup()

        local upWinNum,downWinNum = ArenaTopMatchManager.GetTwoOutOfThreeInfo(2)
        local isBattleEnd = (upWinNum >= 2 or downWinNum >= 2)

        --打开竞猜提示(处于秋后算账)
        if IsBeted and isShow and (isBattleEnd and this.baseInfo.battleStage == TOP_MATCH_STAGE.ELIMINATION or this.baseInfo. battleStage == TOP_MATCH_STAGE.CHOOSE)  then
            if this.baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_END then
                ArenaTopMatchManager.SetcurIsShowDoGuessPopup(false)
                UIManager.OpenPanel(UIName.ArenaTopMatchGuessTipViewPopup)
                -- matchPanel.OpenView(6)
            end
        end
    end
end

--> 当日已点赞uids
this.TodayAlreadyLikeUids_TopMatch = {}
function this.RequestTodayAlreadyLikeUids_TopMatch(func)
    NetManager.ArenaTopMatchGetAllSendLikeResponse(function(msg)
        this.TodayAlreadyLikeUids_TopMatch = msg.uid
        if func then
            func(msg)
        end
     end)
end
function this.GetTodayAlreadyLikeUids_TopMatch()
    return this.TodayAlreadyLikeUids_TopMatch
end
--> 当日是否已经点赞
function this.CheckTodayIsAlreadyLike(uid)
    for i = 1, #this.TodayAlreadyLikeUids_TopMatch do
        if this.TodayAlreadyLikeUids_TopMatch[i] == uid then
            return true
        end
    end
    return false
end

function this.RefreshRankRedpoint()
    -- if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.ARENA) then
    --     return false
    -- end
    if not ArenaTopMatchManager.IsTopMatchActive() then
        Log("ArenaTopMatchManager.RefreshRankRedpoint: Not active")
        return false
    end
    if this.baseInfo.battleStage ~= TOP_MATCH_STAGE.CLOSE 
    -- and this.baseInfo.battleStage ~= TOP_MATCH_STAGE.OVER 
    then
        -- LogError("ArenaTopMatchManager.RefreshRankRedpoint: Not in close or over stage"..
        --     "  battleStage: "..tostring(this.baseInfo.battleStage))
        return false
    end

    return #this.TodayAlreadyLikeUids_TopMatch < 3
end
----------------------
return this