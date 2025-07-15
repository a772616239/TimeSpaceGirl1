MatchDataManager = {};
local this = MatchDataManager
local rankConfig = ConfigManager.GetConfig(ConfigName.BloodyRankConfig)

MAP_FIGHT_REWARD_STATE = {
    UN_FINISH = -1,
    GET_1 = 0,
    GET_2 = 1,
    FINISH = 2
}

function this.Initialize()
    this.myScore = 0
    this.myLevel = ""
    this.gameEndTime = 0

    this.RewardScore = 0
    this.hadBuy = 0
    this.RewardData = {}
end

-- 获得积分对应的称号
function this.GetNickNameByScore(score)
    local name = GetLanguageStrById(10755)
    for k, v in ConfigPairs(rankConfig) do
        -- 没有段位的不管
        if score >= rankConfig[1].Score then
            -- 去掉第一项跟最后一项
            if score == rankConfig[1].Score then
                name = rankConfig[1].Name
                break
            elseif score >= rankConfig[29].Score then
                name =  rankConfig[29].Name
                break
            else
                if score - v.Score < 0 then
                    name = rankConfig[k - 1].Name
                    break
                end
            end
        end
    end
    return name
end

-- 设置我的积分
function MatchDataManager.SetMyScore(score)
    assert(score, GetLanguageStrById(10756))
    this.myScore = score
end

-- 获取我的积分
function MatchDataManager.GetMyScore()
    return this.myScore or 0
end

----=====================  奖励相关=====================
-- 设置我的奖励数据
function MatchDataManager.SetScoreRewardData(msg)
    this.RewardScore = msg.score
    this.hadBuy = msg.hadBuy
    this.RewardData = {}
    for _, data in ipairs(msg.bloodyScoreItemInfo) do
        local status = data.status
        if status == MAP_FIGHT_REWARD_STATE.GET_1 then -- 将未领取拆分为，可以领取第一个奖励和不可以领取两个状态
            local rewardInfo = ConfigManager.GetConfigData(ConfigName.BloodyBattleTreasure, data.id)
            if msg.score < rewardInfo.SeasonPass then
                status = MAP_FIGHT_REWARD_STATE.UN_FINISH
            end
        end
        this.RewardData[data.id] = {
            id = data.id,
            status = status
        }
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.ScoreRewardUpdate)
end

-- 刷新奖励状态
function MatchDataManager.UpdateScoreRewardData(datalist)
    for _, data in ipairs(datalist) do
        if not this.RewardData[data.id] then
            this.RewardData[data.id] = {
                id = data.id
            }
        end
        local status = data.status
        if status == MAP_FIGHT_REWARD_STATE.GET_1 then     -- 将未领取拆分为，可以领取第一个奖励和不可以领取两个状态
            local rewardInfo = ConfigManager.GetConfigData(ConfigName.BloodyBattleTreasure, data.id)
            if this.RewardScore < rewardInfo.SeasonPass then
                status = MAP_FIGHT_REWARD_STATE.UN_FINISH
            end
        end
        this.RewardData[data.id].status = status
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.ScoreRewardUpdate)
end

-- 设置奖励积分
function MatchDataManager.SetRewardScore(score)
    this.RewardScore = score
end
-- 获取奖励积分
function MatchDataManager.GetRewardScore()
    return this.RewardScore or 0
end
-- 获取奖励数据
function MatchDataManager.GetScoreRewardData()
    return this.RewardData or {}
end
-- 获取最终奖励数据
function MatchDataManager.GetFinalScoreRewardData()
    return this.RewardData[#this.RewardData]
end
-- 获取奖励数据
function MatchDataManager.IsBuyExtra()
    return this.hadBuy == 1
end
-- 判断是否有可以领取的奖励
function MatchDataManager.HasCanGetScoreReward()
    local isCanGet = false
    for _, reward in pairs(this.RewardData) do
        if reward.status == MAP_FIGHT_REWARD_STATE.GET_1 or (this.hadBuy == 1 and reward.status == MAP_FIGHT_REWARD_STATE.GET_2) then
            isCanGet = true
            break
        end
    end
    return isCanGet
end
-- 判断当前第一个未领奖阶段积分
function MatchDataManager.GetCurStageRewardScore()
    local curStage = nil
    for id, data in ipairs(this.RewardData) do
        curStage = id
        if data.status <= MAP_FIGHT_REWARD_STATE.GET_1 then
            break
        end
    end
    local stage = ConfigManager.GetConfigData(ConfigName.BloodyBattleTreasure, curStage)
    return stage.SeasonPass or 0
end

-- 请求领取奖励
function MatchDataManager.RequestGetScoreReward(id, func)
    -- 判断是否可以领取
    if id ~= -1 then
        local reward = this.RewardData[id]
        if reward.status == MAP_FIGHT_REWARD_STATE.UN_FINISH    -- 未完成
           or reward.status == MAP_FIGHT_REWARD_STATE.FINISH    -- 已完成
           or (reward.status == MAP_FIGHT_REWARD_STATE.GET_2 and this.hadBuy == 0)-- 可以领额外奖励，但是没有令牌
        then
            PopupTipPanel.ShowTipByLanguageId(10757)
            return
        end
    else
        local isCanGet = this.HasCanGetScoreReward()
        if not isCanGet then
            PopupTipPanel.ShowTipByLanguageId(10758)
            return
        end
    end

    -- 请求获取奖励数据
    NetManager.RequestGetScoreRewardData(id, function(msg)
        UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
        this.UpdateScoreRewardData(msg.changeItemInfo)
        if func then func()end
    end)
end
-- 刷新奖励状态
function MatchDataManager.RequestBuyExtraReward(func)
    if this.hadBuy == 1 then
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10759)))
        return
    end
    --判断购买物品是否足够
    local BloodyBattleSetting = ConfigManager.GetConfigData(ConfigName.BloodyBattleSetting, 1)
    local costId, costNum = BloodyBattleSetting.Price[1], BloodyBattleSetting.Price[2]
    local haveNum = BagManager.GetItemCountById(costId)
    if haveNum < costNum then
        local costName = GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig, costId).Name)
        PopupTipPanel.ShowTip(string.format(GetLanguageStrById(10760), costName))
        return
    end
    NetManager.RequestBuyExtraReward(function ()
        this.hadBuy = 1
        Game.GlobalEvent:DispatchEvent(GameEvent.MapFight.ScoreRewardUpdate)
        if func then func() end
    end)
end



return this