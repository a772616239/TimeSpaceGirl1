GuildTranscriptManager = {};
local this = GuildTranscriptManager
local guildCheckpointConfig = ConfigManager.GetConfig(ConfigName.GuildCheckpointConfig)
local allChapterConfigData = {}
local curBoss = 1--当前bossId
local blood = 0--剩余血量万分比
local canSweep = 0--是否能扫荡，今天是否挑战过这个boss
local isKill = 0 --当场战斗boss 是否击杀
local isKillShowTip = false --当场战斗boss 是否击杀
local buffCount = 0--当前buff到多少索引
local buffTime = 0--buff结束时间

this.damage = 0
this.drop = nil--当场战斗掉落
this.shopGoodId = 10031--公会副本挑战价格
local refreshedBoss = {}

local endBossId = 0
function this.Initialize()
    for _, configInfo in ConfigPairs(guildCheckpointConfig) do
       table.insert(allChapterConfigData,configInfo)
       if configInfo.Id > endBossId then
            endBossId = configInfo.Id
       end
    end
end
function this.GetAllConFigData()
    return allChapterConfigData
end
--请求当前副本章节
function this.GetGuildChallengeInfoRequest(fun)
    NetManager.GetGuildChallengeInfoRequest(function (msg)
        curBoss = msg.curBoss--当前bossId
        blood = msg.blood--剩余血量万分比
        canSweep = msg.canSweep--是否能扫荡，今天是否挑战过这个boss
        buffCount = msg.buffCount
        buffTime = msg.buffTime
        this.damage = msg.sweepDamage--上次挑战或扫荡的伤害
        for i = 1, #msg.refreshedBoss do
            refreshedBoss[msg.refreshedBoss[i]] = msg.refreshedBoss[i]
        end
        if msg.isRefresh == 1 then
            PrivilegeManager.RemovePrivilege(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BATTLENUM,3013)
            PrivilegeManager.RefreshStarPrivilege(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BATTLENUM)
            PrivilegeManager.RefreshStarPrivilege(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM)
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildTranscript)
        Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildTranscriptBuff)
    end)
end
--请求战斗
local attackTypeShotTime
function this.GuildChallengeRequest(attackType,callBack)
    attackTypeShotTime = attackType
    if attackType == 0 then
        --> fightInfo
        BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.GuildTranscript, G_GuildCheckpointConfig[this.GetCurBoss()].MonsterId)

        canSweep = 1
        NetManager.GuildChallengeRequest(this.GetCurBoss(),attackType,function (msg)
            UIManager.OpenPanel(UIName.BattleStartPopup, function ()
                local fightData = BattleManager.GetBattleServerData(msg)
                this.damage = msg.damage
                this.drop = msg.drop
                UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.GuildTranscript, callBack)
                CheckRedPointStatus(RedPointType.Guild_Transcript)
            end)
        end)
    elseif attackType == 1 then--快速战斗 扫荡
        NetManager.GuildChallengeRequest(this.GetCurBoss(),attackType,function (msg)
            this.damage = msg.damage
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop, 1,function()
                if callBack then
                    callBack()
                end
            end, 6,true,true)
            CheckRedPointStatus(RedPointType.Guild_Transcript)
        end)
    end
end
    local oldBossId = 0
function this.RefreshGuildTranscriptInfo(msg)
    oldBossId = curBoss
    curBoss = msg.curBoss--当前bossId
    blood = msg.blood--剩余血量万分比
    isKill = msg.isKill--是否击杀
    isKillShowTip = false
    if  msg.isKill == 1 then
        isKillShowTip = true
        if attackTypeShotTime == 1 and endBossId ~= oldBossId then
            local monsterData = this.GetMonsterConfigDataById(oldBossId)
            PopupTipPanel.ShowTip( string.format(GetLanguageStrById(12346),GetLanguageStrById(monsterData.ReadingName)) ) 
        end
    end
    if oldBossId ~= curBoss then--前后ID不等认为是击杀
        canSweep = 0
        isKill = 1
        if not refreshedBoss[oldBossId] then
            refreshedBoss[oldBossId] = oldBossId
            if endBossId ~= oldBossId then
                PrivilegeManager.RemovePrivilege(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BATTLENUM,3013)
                PrivilegeManager.RefreshStarPrivilege(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BATTLENUM)
                PrivilegeManager.RefreshStarPrivilege(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM)
            end
        end
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildTranscript)
end
function this.IsKillShowTip()
    if isKillShowTip and attackTypeShotTime == 0 and endBossId ~= oldBossId then
        local monsterData = this.GetMonsterConfigDataById(oldBossId)
        PopupTipPanel.ShowTip( string.format(GetLanguageStrById(12346),GetLanguageStrById(monsterData.ReadingName) )) 
    end
end
function this.RefreshGuildTranscriptBuffInfo(msg)
    buffCount = msg.buffCount
    buffTime = msg.buffTime
    Game.GlobalEvent:DispatchEvent(GameEvent.Guild.RefreshGuildTranscriptBuff)
end

function this.GetMonsterConfigDataById(chapterId)
    local MonsterId = ConfigManager.GetConfigData(ConfigName.GuildCheckpointConfig,chapterId).MonsterId
    local monsterConFig = nil
    local monsterGrip = ConfigManager.GetConfigData(ConfigName.MonsterGroup,MonsterId)
    if not monsterGrip then return nil end
    local monsterId = 0
    for i = 1, #monsterGrip.Contents do
        if monsterId <= 0 then
            for j = 1, #monsterGrip.Contents[i] do
                if monsterGrip.Contents[i][j] > 0 then
                    monsterId =  monsterGrip.Contents[i][j]
                    break
                end
            end
        end
    end
    if monsterId <= 0 then return nil end
    local monsterData = ConfigManager.GetConfigData(ConfigName.MonsterConfig,monsterId)
    return monsterData
end
-- 获取剩余挑战次数 特权
function this.GetCanBattleCount()
    return PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BATTLENUM)

    -- PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BATTLENUM)
    --return PrivilegeManager.GetPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM) + PrivilegeManager.GetPrivilegeNumber(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BATTLENUM) - PrivilegeManager.GetPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BATTLENUM)
end
-- 获取剩余挑战购买次数 特权
function this.GetCanBuyBattleCount()
    return PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BUY_BATTLENUM)
end
function this.GetRedPointState()
    if PlayerManager.familyId == 0 then return false end
    return PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.GUILDTRANSCRIPT_BATTLENUM) > 0
end
function this.GetCurBoss()
    return curBoss
end
function this.GetBlood()
    if blood < 0 then
        blood = 10000
    end
    return blood
end
function this.GetCanSweep()
    return canSweep
end
function this.GetbuffTime()
    return buffTime
end
function this.GetbuffCount()
    return buffCount
end
function this.GetCurBattleIsSkillBoss()
    return isKill == 1
end
function this.GetRefreshedBoss()
return refreshedBoss
end
return this