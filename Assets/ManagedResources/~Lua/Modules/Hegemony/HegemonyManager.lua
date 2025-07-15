---三强争霸
HegemonyManager = {}
local this = HegemonyManager
local posInfo = {}
local challeageInfo

this.isFirstOn = true

function this.Initialize()
    this.data = {}
    this.data[ClimbTowerManager.ClimbTowerType.Normal] = {}
    this.data[ClimbTowerManager.ClimbTowerType.Advance] = {}
end


--初始化英雄数据
function this.InitHeroData(_msg)
    posInfo = {}
    for i, v in ipairs(_msg.boss) do
        table.insert(posInfo,v)
    end
    NetManager.RequestArenaRankData(1, function()
        local _,myRank= ArenaManager.GetRankInfo()
        this.myRank = myRank.personInfo.rank
    end)
end

function this.GetFightId(fightId)
    HegemonyManager.curFightId = fightId
end

function HegemonyManager.UpdateData(fightId)

end

function HegemonyManager.UpdateFightIdData(_msg)
end

-- 请求回放数据
function this.RequestRecordFightData(isWin, fightId,rank,pos, nameStr, func)
    NetManager.FightRePlayRequest(4, tostring(fightId), function(msg)
        local fightData = msg.fightData
        if not fightData then
            PopupTipPanel.ShowTipByLanguageId(10089)
            return
        end
        this.RequestReplayRecord(isWin, fightData, nameStr, func)
    end,rank,pos)
end

--- 请求开始播放回放
--- isWin 战斗结果 1 胜利 0 失败
--- fightData 战斗数据
--- nameStr 交战双方名称
--- doneFunc 战斗播放完成要回调的事件
function this.RequestReplayRecord(isWin, fightData, nameStr, doneFunc)
    BattleManager.GotoFight(function()
        UIManager.OpenPanel(UIName.BattleStartPopup, function()
        local fightData = BattleManager.GetBattleServerData({fightData = fightData}, 0)
        local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, doneFunc)
        battlePanel:ShowNameShow(isWin, nameStr)
        end)
    end)
end

--获得神位基本数据
function HegemonyManager.GetBaseInfo()
   return posInfo
end

--获取个人在竞技场内排名
function HegemonyManager.GetMyRank()
    return this.myRank
end

--开始战斗
function HegemonyManager.ExecuteFight(fightId,rank,pos,level,callBack)
    -- fightInfo
    BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.CONTEND_HEGEMONY, G_SupremacyConfig[fightId].Monster)

    NetManager.ContendHegemonyFightDataRequest(fightId,rank,pos,level,function(msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg, nil)
            BattleRecordManager.SetBattleRecord(fightData)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.CONTEND_HEGEMONY, callBack)
        end)
    end)
end

return this