-- 管理需要UI表现得的数据
FightUIManager = {};
local this = FightUIManager

function this.Initialize()
    this.rankInfo = {}  -- 实时排行数据
    this.lastRankInfo = {} -- 刷新前的排行数据
    this.playerInfo = {}  -- 玩家们
    this._FightResultScoreData = nil        -- 血战结束后分数变化数据
    this.remainTime = 0  -- 在血战地图里呆的时间
end

-- 格式化玩家排名信息
function this.ReStoreRankInfo()
    local newData = {}
    for i, v in pairs(this.playerInfo) do
        newData[#newData + 1] = v
    end


    table.sort(newData, function(a, b)
        if a.nineralNum == b.nineralNum then
            if a.killNum == b.killNum then
                return a.id < b.id
            else
                return a.killNum > b.killNum
            end
        else
            return a.nineralNum > b.nineralNum
        end
    end)


    return newData
end

-- 更新玩家的排名信息
function this.UpDateRankInfo(agentInfo)
    if agentInfo.type == 1 then
        local playerInfo = {}
        playerInfo.id = agentInfo.id
        playerInfo.name = agentInfo.userName
        playerInfo.nineralNum = agentInfo.Creature.mineral
        playerInfo.killNum = agentInfo.Creature.killNums
        this.playerInfo[agentInfo.id] = playerInfo
    end

    Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.RankInfoChange)
end

-- 返回排序好的玩家信息
function this.GetPlayerInfo()
    return this.ReStoreRankInfo()
end

-- 获取血战结束后的积分数据
function FightUIManager.SetFightResultScoreData(dataList)
    this._FightResultScoreData = {}
    for _, data in ipairs(dataList) do
        this._FightResultScoreData[data.uid] = data
        -- 刷新我的积分
        if data.uid == PlayerManager.uid then
            MatchDataManager.SetMyScore(data.score)
        end
    end
end
function FightUIManager.GetFightResultScoreData(uid)
    if not this._FightResultScoreData or not this._FightResultScoreData[uid] then

    end
    return this._FightResultScoreData[uid]
end

return this