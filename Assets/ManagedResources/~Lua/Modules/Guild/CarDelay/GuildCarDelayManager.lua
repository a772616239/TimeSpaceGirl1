GuildCarDelayManager = {};
local this = GuildCarDelayManager
this.ChallengeCdTime = 0
this.LootCdTime = 0
this.totalHurt = 0
this.bossIndexId = 1

function this.Initialize()
end

function this.InitBaseData(func)
    if func then func() end

    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MINSKBATTLE) then
        GuildCarDelayManager.GetBuyChallengeCountData()
    end
end

--后端更新梦魇进度
function this.SetProgressData(msg)
    this.progress = msg.progress--阶段 -1：未开 1：挑战
    this.endTime = msg.endTime--结束时间
    -- this.bossIndexId  = msg.bossIndexId--boss索引id
    this.battleStartTime = msg.battleStartTime--挑战boss开启时间
    this.totalHurt = msg.totalHurt--全服累计伤害
    --this.grabStartTime  = msg.grabStartTime--抢夺开启时间

    if this.timer2 then
        this.timer2:Stop()
        this.timer2 = nil
    end
    this.ChallengeCdTime = 0
    this.LootCdTime = 0
    GuildCarDelayManager.GetBuyChallengeCountData()
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.CarDelayProgressChanged)
    CheckRedPointStatus(RedPointType.Guild_CarDeleay)
end

--开始战斗
this.score = 0
this.hurt = 0
this.heroDid = 0--抢夺是向后端传的id
function this.SetheroDid(_heroDid)
    this.heroDid = _heroDid
end
function this.FightBattle(callBack)
    local type = 0
    local fightType = 0
    local monsterId = 0
    if this.progress == GuildCarDelayProType.Challenge then
        local worldBossConfig = ConfigManager.GetConfigData(ConfigName.WorldBossConfig,GuildCarDelayManager.bossIndexId)
        if worldBossConfig and worldBossConfig.MonsterId then
            monsterId = worldBossConfig.MonsterId
        end
        fightType = 0
        type = 1
        PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILD_CAR_DELEAY_CHALLENGE, 1)
    elseif this.progress == GuildCarDelayProType.Loot then
        monsterId = this.heroDid
        fightType = 1
        type = 2
        PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILD_CAR_DELEAY_LOOT, 1)
    end

    BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.GUILD_CAR_DELAY, monsterId)
    NetManager.FastFightChallengeRequest(type, monsterId, false, function (msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            this.score = msg.score
            if msg.hurt > this.hurt then
                this.hurt = msg.hurt
            end
            this.totalHurt = msg.totalHurt
            local fightData = BattleManager.GetBattleServerData(msg,fightType)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.GUILD_CAR_DELAY, callBack)
        end)
    end)

    GuildCarDelayManager.GetBuyChallengeCountData()
end

--扫荡
function this.FastFightBattle(callBack)
    local monsterId = 0
    local worldBossConfig =  ConfigManager.GetConfigData(ConfigName.WorldBossConfig,GuildCarDelayManager.bossIndexId)
    if worldBossConfig and worldBossConfig.MonsterId then
        monsterId = worldBossConfig.MonsterId
    end

    NetManager.FastFightChallengeRequest(1, monsterId, true, function (msg)
        UIManager.OpenPanel(UIName.RewardItemPopup, nil, 1, function()
            this.score = msg.score
            this.hurt = msg.hurt
            this.totalHurt = msg.totalHurt
            Game.GlobalEvent:DispatchEvent(GameEvent.Guild.CarDelayProgressChanged)
            if callBack then
                callBack()
            end
        end, 3, true, true, nil, true, nil, BATTLE_TYPE.GUILD_CAR_DELAY)
    end)

    GuildCarDelayManager.GetBuyChallengeCountData()
end

function this.SetCdTime(progress)
    if progress == GuildCarDelayProType.Challenge then
        this.ChallengeCdTime =  ConfigManager.GetConfigData(ConfigName.WorldBossSetting,1).CDTime[1]
        this.RemainTimeDown2(this.ChallengeCdTime)
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.CarDelayChallengeCdStar)
    -- elseif progress == GuildCarDelayProType.Loot then
    --     this.LootCdTime = ConfigManager.GetConfigData(ConfigName.WorldBossSetting,1).CDTime[2]
    --     this.RemainTimeDown2(this.LootCdTime)
    --     Game.GlobalEvent:DispatchEvent(GameEvent.Guild.CarDelayLootCdStar)
    end
    CheckRedPointStatus(RedPointType.Guild_CarDeleay)
end

this.timer2 = Timer.New()
--刷新倒计时显示
function this.RemainTimeDown2(timeDown)
    if timeDown > 0 then
        if this.timer2 then
            this.timer2:Stop()
            this.timer2 = nil
        end
        this.timer2 = Timer.New(function()
            if GuildCarDelayManager.progress == GuildCarDelayProType.Challenge then
                GuildCarDelayManager.ChallengeCdTime = timeDown
            -- elseif GuildCarDelayManager.progress == GuildCarDelayProType.Loot then
            --     GuildCarDelayManager.LootCdTime = timeDown
            end
            if timeDown < 0 then
                this.timer2:Stop()
                this.timer2 = nil
                CheckRedPointStatus(RedPointType.Guild_CarDeleay)
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer2:Start()
    end
end

function this.RefreshAllRedPoint()
    return this.RefreshRedPoint()

    -- return this.RefreshRedPoint(GuildCarDelayProType.Challenge) or this.RefreshRedPoint(GuildCarDelayProType.Loot)
end

--红点检测
function this.RefreshRedPoint(progress)
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.MINSKBATTLE) then
        if this.progress == GuildCarDelayProType.Challenge then
            if this.challengeNumber > 0 then
                return true
            end
        end
    end
    return false

    -- if progress ~= GuildCarDelayManager.progress then
    --     return false
    -- end
    -- if GuildCarDelayManager.progress == GuildCarDelayProType.Challenge then
    --     if PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.GUILD_CAR_DELEAY_CHALLENGE) > 0 and this.ChallengeCdTime <= 0 then
    --         return true
    --     else
    --         return false
    --     end
    -- elseif GuildCarDelayManager.progress == GuildCarDelayProType.Loot then
    --     if PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.GUILD_CAR_DELEAY_LOOT) > 0 and this.LootCdTime <= 0 then
    --         return true
    --     else
    --         return false
    --     end
    -- end
end

function this.SetCarPlayTimeData(time)
    if this.progress == GuildCarDelayProType.Challenge then
        this.ChallengeCdTime =  (time + ConfigManager.GetConfigData(ConfigName.WorldBossSetting,1).CDTime[1]) - GetTimeStamp()
        this.RemainTimeDown2(this.ChallengeCdTime)
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.CarDelayChallengeCdStar)
    -- elseif this.progress == GuildCarDelayProType.Loot then
    --     this.LootCdTime = (time + ConfigManager.GetConfigData(ConfigName.WorldBossSetting,1).CDTime[1]) - GetTimeStamp()
    --     this.RemainTimeDown2(this.LootCdTime)
    --     Game.GlobalEvent:DispatchEvent(GameEvent.Guild.CarDelayLootCdStar)
    end
    CheckRedPointStatus(RedPointType.NightmareInvasion)
end

--获取已购买次数和剩余挑战次数
function this.GetBuyChallengeCountData(fun)
    NetManager.GET_CAR_CHALLENGE_MY_INFO_REQUEST( function(msg)
        this.BuyCount = msg.battleBuyCount
        this.challengeNumber = msg.battleCount
        Game.GlobalEvent:DispatchEvent(GameEvent.WorldBoss.RefreshChallengeInfo)
        if fun then
            fun()
        end
    end)
end

function this.RefreshCout(msg, func)
    this.BuyCount = msg.battleBuyCount
    this.challengeNumber = msg.battleCount
    Game.GlobalEvent:DispatchEvent(GameEvent.WorldBoss.RefreshChallengeInfo)
    if func then
        func()
    end
end

return this