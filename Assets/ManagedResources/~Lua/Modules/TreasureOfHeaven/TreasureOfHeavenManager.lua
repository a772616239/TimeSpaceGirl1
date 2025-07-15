TreasureOfHeavenManger = {}
local this = TreasureOfHeavenManger
local WorldBossTreasureConfig = ConfigManager.GetConfig(ConfigName.WorldBossTreasureConfig)

local curScore--当前分数
local limitTime--倒计时
local rewardStateData = {}--各个任务状态数据
local rewardData = {}--表内活动任务数据
this.TreasrueState = nil--礼包购买状态

function this.Initialize()
    rewardData = {}
    for i, v in ConfigPairs(WorldBossTreasureConfig) do
        table.insert(rewardData, v)
    end
end

function this.GetTreasureState()
    this.TreasrueState = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.TreasureOfHeaven,106)
    return this.TreasrueState
end

function this.SetTreasureState()
    this.TreasrueState = 1
    return this.TreasrueState
end

function this.SetScore(score)
    curScore = score
end
function this.GetScore()
    return curScore
end

function this.SetLimitTime(time)
    limitTime = time
end
function this.GetLimitTime()
    return limitTime
end

function this.SetState(treasureRewardState)
    rewardStateData = {}
    for i, v in ipairs(treasureRewardState) do
        table.insert(rewardStateData, v)
    end
end
function this.GetState()
    return rewardStateData
end

function this.SetSingleRewardState(id,state)
    for i = 1, #rewardStateData do
        if(rewardStateData[i].id == id)then
            rewardStateData[i].state = state
        end
    end
    CheckRedPointStatus(RedPointType.Expedition_Treasure)
end

function this.GetAllRewardData()
    return rewardData
end
--红点检测
function this.RedPointState(singleRewardData,TreasrueState)
    if curScore >= rewardData[singleRewardData.id].Integral then
        if singleRewardData.state==0 and this.TreasrueState==1 or
            singleRewardData.state==1 and this.TreasrueState==1 or
            singleRewardData.state==0 and this.TreasrueState==0 then
            return true
        end
        return false
    end
    return false
end

function this.RedPoint()
    for i =1, #rewardStateData do
        local curTreasrueState = OperatingManager.GetGoodsBuyTime(GoodsTypeDef.TreasureOfHeaven,106)
        if curScore >= rewardData[rewardStateData[i].id].Integral then
            if rewardStateData[i].state==0 and curTreasrueState==1 or
            rewardStateData[i].state==1 and curTreasrueState==1 or
            rewardStateData[i].state==0 and curTreasrueState==0 then
                return true
            end
        end
    end
    return false
end

return this