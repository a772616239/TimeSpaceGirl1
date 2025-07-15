GuildBattleManager = {}
local this = GuildBattleManager
local guildSetting = ConfigManager.GetConfig(ConfigName.GuildSetting)
local guildWarSetting = ConfigManager.GetConfig(ConfigName.GuildWarSetting)

function this.Initialize()
    this.overTime = 0--活动结束时间，剩余时间
    this.challengeCount = 0--已挑战次数
    this.buyCount = 0--购买次数
    this.guildBattleInfos = {}--公会战信息
    this.guildBattleState = 0 --公会战状态 0：未开启 1：开启
    this.allowChallange = 0--1：允许挑战 0：开启时加入本次不许挑战
    this.rewardInfo = {}--所有宝箱信息
    this.myHurtRank = 0--我的伤害排名信息
    this.allHurtRank = {}--所有伤害排名信息
    this.myGuildRank = 0--本公会排名
    this.guildType = 0--0=单服公会战，1=跨服公会战
    this.serverInfo = {}
end

function this.InitData(func)
    this.GetGuildBattleInfo()
    this.GetGuildBattleState()
    this.GetAllRewardInfo()
    this.GetTotalDamageRankRequest()
    this.GetMyGuildRank()
    this.GetGuildBattleStartTime()
    CheckRedPointStatus(RedPointType.GuildBattle_BoxReward)
    CheckRedPointStatus(RedPointType.GuildBattle_FreeTime)
    if func then
        func()
    end
end

function this.InitData2(func)
    local count = 0;
    this.GetGuildBattleInfo(function()
        count = count + 1
        if count == 6 then
            func()
        end
    end)
    this.GetGuildBattleState(function()
        count = count + 1
        if count == 6 then
            func()
        end
    end)
    this.GetAllRewardInfo(function()
        count = count + 1
        if count == 6 then
            func()
        end
    end)
    this.GetTotalDamageRankRequest(function()
        count = count + 1
        if count == 6 then
            func()
        end
    end)
    this.GetMyGuildRank(function()
        count = count + 1
        if count == 6 then
            func()
        end
    end)
    this.GetGuildBattleStartTime(function()
        count = count + 1
        if count == 6 then
            func()
        end
    end)
end

--获取公会战基础信息
function this.GetGuildBattleInfo(func)
    NetManager.GetDeathPathInfoResponse(function (msg)
        GuildBattleManager.GetGuildBattleState()
        this.overTime = msg.overTime
        this.challengeCount = msg.challengeCount
        this.buyCount = msg.buyCount
        this.guildBattleInfos = msg.infos
        this.guildType = msg.typeID
        this.serverInfo = msg.serverInfo
        --[[
            infos = {
                [1] = {
                    pathId
                    guildName
                    gid
                    serverName
                }
            }

            serverInfo = {
                [1] = {
                    serverId
                    serverName
                }
            }
        ]]
        -- LogError("--------基础信息---------")
        -- LogError("活动结束时间，剩余时间:"..this.overTime)
        -- LogError("已挑战次数:"..this.challengeCount)
        -- LogError("购买次数:"..this.buyCount)
        -- LogError("公会战信息:"..#this.guildBattleInfos)
        -- LogError("类型："..this.guildType)
        -- LogError("服务器ID组："..#this.serverInfo)
        -- LogError("-------------------------")
        CheckRedPointStatus(RedPointType.GuildBattle_BoxReward)
        CheckRedPointStatus(RedPointType.GuildBattle_FreeTime)
        if func then
            func()
        end
    end)
end

--购买公会战挑战次数
function this.BuyBattleCount(func)
    NetManager.DeathPathBuyCountRequest(function (msg)
        this.challengeCount = msg.battleCount
        this.buyCount = msg.battleBuyCount
        -- LogError("-----------购买-----------")
        -- LogError("已挑战次数:"..this.challengeCount)
        -- LogError("购买次数:"..this.buyCount)
        -- LogError("-------------------------")
        if func then
            func()
        end
    end)
end

--获取公会战状态信息
function this.GetGuildBattleState(func)
    NetManager.GetDeathPathStatusResponse(function (msg)
        this.guildBattleState = msg.status
        this.allowChallange = msg.allowChallange
        -- if msg.status == 0 then
        --     LogError("公会战未开启")
        -- else
        --     LogError("公会战已开启")
        -- end
        -- if msg.allowChallange == 0 then
        --     LogError("公会战开启时加入本次不许挑战")
        -- else
        --     LogError("公会战可以挑战")
        -- end
        if func then
            func()
        end
    end)
end

--发起公会战挑战
--pathId:当前阵Id
-- function this.ChallengeRequest(pathId, func)
--     NetManager.ChallengeDeathPathRequest(pathId, function (msg)
--         -- msg.fightData--战斗信息
--         -- msg.damage--伤害
--         -- msg.drop--奖励
--         -- msg.historyMax--历史最高伤害
--         if func then
--             func()
--         end
--     end)
-- end

--获取所有宝箱信息
function this.GetAllRewardInfo(func)
    NetManager.GetAllDeathPathRewardInfoResponse(function (msg)
        this.rewardInfo = msg.info
        --[[
        LogError("获取所有宝箱信息--------------------------")
        for _, value in ipairs(this.rewardInfo) do
            LogError("position:"..value.position.."  username:"..value.username.."   itemId:"..value.items[1].itemId)
        end
        ]]
       
        --[[
            info = {
                [1] = {
                    uid
                    items = {
                        itemId
                        itemNum
                        endingTime
                        nextFlushTime //下次刷新时间 0 不刷新
                    }
                    position
                    username
                }
            }
        ]]
        -- LogError("宝箱信息:"..#this.rewardInfo)
        if func then
            func()
        end
    end)
end

--领取公会战宝箱
function this.ReceiveRewardRequest(position, func)
    NetManager.DoRewardDeathPathRequest(position, function (msg)
        GuildBattleManager.GetAllRewardInfo(function ()
            UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
            CheckRedPointStatus(RedPointType.GuildBattle_BoxReward)
            CheckRedPointStatus(RedPointType.GuildBattle_FreeTime)
            if func then
                func()
            end
        end)
    end)
end

--[[
    rankInfo = {
        [1] = {
            userId = 用户ID/公会ID
            rank = 排名
            username = 名字
            score = 伤害值
            head = 头像
            headFrame = 头像框
            serverId = 服务器Id
            serverName = 服务器名称
        }
    }
]]
--公会战玩家总伤害排行
function this.GetTotalDamageRankRequest(func)
    NetManager.DeathPathTotalPersonRankRequest(function (msg)
        this.allHurtRank = msg.rankInfo
        -- LogError("排名数量："..#msg.rankInfo)
        -- LogError("我的uid："..PlayerManager.uid)
        for index, value in ipairs(msg.rankInfo) do
            -- LogError(value.userId.."|"..value.rank.."|"..value.username.."|"..value.score)
            if value.userId == PlayerManager.uid then
                this.myHurtRank = value.rank
                -- LogError("我的排名："..this.myHurtRank)
            end
        end
        if func then
            func()
        end
    end)
end

--公会战当前阵玩家伤害排行
--pathId:当前阵Id  type:1=个人排行，2=公会排行，3=本会排行
function this.GetCurrentDamageRankRequest(pathId, type, func)
    NetManager.DeathPathPersonRankRequest(pathId, type, function (msg)
        if func then
            func(msg)
        end
    end)
end

--本公会排名
function this.GetMyGuildRank(func)
    NetManager.DeathPathSelfGuildRankRequest(function (msg)
        this.myGuildRank = msg.rank
        if func then
            func()
        end
    end)
end

--推送设置宝箱奖励
function this.SetRewardInfo(info)
    for index, value in ipairs(this.rewardInfo) do
        if value.position == info.position then
            --LogError("推送设置宝箱奖励 position:"..value.position.." itemId:"..value.items[1].itemId)
            value = info
        end
    end
    CheckRedPointStatus(RedPointType.GuildBattle_BoxReward)
    CheckRedPointStatus(RedPointType.GuildBattle_FreeTime)
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildBattleReward)
end

--推送城市排名第一
function this.SetFirstRank(info)
    for index, value in ipairs(this.guildBattleInfos) do
        if value.pathId == info.pathId then
            value.guildName = info.guildName
            value.gid = info.gid
        end
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildCityRank)
end

--推送改变公会战状态
function this.ChangeGuildState(func)
    --LogError("推送改变公会战状态")
    this.InitData2(function()
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildBattleState)
        --LogError("推送改变公会战状态--消息推送")
        CheckRedPointStatus(RedPointType.GuildBattle_BoxReward)
        CheckRedPointStatus(RedPointType.GuildBattle_FreeTime)
        if func then
            func()
        end
    end)
end

--获取公会战开启时间
function this.GetGuildBattleStartTime(func)
    NetManager.DeathPathStartTimeRequest(function (msg)
        this.startTime = msg.startTime
        if func then
            func()
        end
    end)
end

--公会战免费次数红点
function this.GuildBattleTimeRedPoint()
    if GuildBattleManager.guildBattleState == 0 then
        return false
    end
    if GuildBattleManager.allowChallange == 0 then
        return false
    end
    return guildWarSetting[1].Section+GuildBattleManager.buyCount-GuildBattleManager.challengeCount > 0
end

--公会战宝箱红点
function this.GuildBattleRewardRedPoint()
    if #GuildBattleManager.rewardInfo == 0 then
        return false
    end
    if GuildBattleManager.allowChallange == 0 then
        return false
    end
    if GuildBattleManager.guildBattleState == 1 then
        return false
    end
    for i = 1, #this.rewardInfo do
        if this.rewardInfo[i].uid == PlayerManager.uid then
            return false
        end
    end
    return true
end

return this