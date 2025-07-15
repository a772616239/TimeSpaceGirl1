GuildBossManager = {}
local this = GuildBossManager

function this.Initialize()
    this.bossId = 0
    this.maxBossHurt = 0
    this.lastBossHurt = 0
    this._BossAttackLog = {}

    -- 查看时间，用于红点检测
    this._CheckTime = nil

    -- 监听功能开启事件，检测红点
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionOpen, function(id)
        if id == FUNCTION_OPEN_TYPE.GUILD_BOSS then
            CheckRedPointStatus(RedPointType.Guild_Boss)
            -- 刷新公会信息获取boss数据
            if PlayerManager.familyId ~= 0 then
                NetManager.RequestMyGuildInfo()
            end
        end
    end)
end

function this.SetBossData(msg)
    this.bossId = msg.guildBossId
    this.maxBossHurt = msg.familyUserInfo.maxBossHurt
    this.lastBossHurt = msg.familyUserInfo.lastHurt
    
    Game.GlobalEvent:DispatchEvent(GameEvent.GuildBoss.OnBaseDataChanged)
end

-- 获取最大伤害量
function this.GetMyMaxBossHurt()
    return this.maxBossHurt
end
-- 设置最大伤害
function this.SetMyMaxBossHurt(hurt)
    if hurt > this.maxBossHurt then
        this.maxBossHurt = hurt
        Game.GlobalEvent:DispatchEvent(GameEvent.GuildBoss.OnMaxDamageChanged)
    end
end
-- 获取上次伤害
function this.GetLastHurt()
    return this.lastBossHurt
end
-- 设置上次伤害
function this.SetLastHurt(hurt)
    this.lastBossHurt = hurt
    Game.GlobalEvent:DispatchEvent(GameEvent.GuildBoss.OnLastDamageChanged)
end



-- 获取当前公会bossID
function this.GetBossId()
    return this.bossId
end
function this.GetBossGroupId()
    local GuildBossData = ConfigManager.GetConfigData(ConfigName.GuildBossConfig, this.bossId)
    return GuildBossData.MonsterId
end

-- 获取当前宝箱等级
function this.GetCurBossRewardLevel(damage)
    local curDamage = damage or this.maxBossHurt
    local bossRewardConfig = ConfigManager.GetConfig(ConfigName.GuildBossRewardConfig)
    local curLevel, curLevelData 
    for level, data in ConfigPairs(bossRewardConfig) do
        if data.Damage > curDamage then
            break
        end
        curLevel = level
        curLevelData = data
    end
    return curLevel, curLevelData
end

-- 获取boss剩余时间
function this.GetLeftTime()
    return 0
end

-- 获取剩余挑战次数
function this.GetLeftAttackTimes()
    local originalValue = PrivilegeManager.GetPrivilegeNumber(PRIVILEGE_TYPE.GUILD_BOSS_ATTACK)
    local usedTimes = PrivilegeManager.GetPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILD_BOSS_ATTACK)
    local remainNum = originalValue - usedTimes
    return remainNum, originalValue, usedTimes
end

-- 请求攻击公会boss
function this.RequestAttackBoss(func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD_BOSS) then
        PopupTipPanel.ShowTipByLanguageId(10778)
        return
    end
    local leftTimes = this.GetLeftAttackTimes()
    if leftTimes <= 0 then
        PopupTipPanel.ShowTipByLanguageId(11018)
        return 
    end
    local monsterGroupId = this.GetBossGroupId()
    NetManager.RequestAttackGuildBoss(function(msg)
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.GUILD_BOSS, function(result)
                -- 刷新挑战次数
                if result.result ~= -1 then
                    PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILD_BOSS_ATTACK, 1)
                    -- 
                    Game.GlobalEvent:DispatchEvent(GameEvent.GuildBoss.OnBaseDataChanged)
                end
                if func then func() end
            end)
        end)
    end)
end


-- 请求公会boss进攻日志
function this.RequestGuildBossAttackLog(func)
    NetManager.RequestRankInfo(RANK_TYPE.GUILD_BOSS, function (msg)--请求数据
        this._BossAttackLog = msg.ranks
        if func then func() end
    end)
end

-- 获取进攻日志数据
function this.GetBossAttackLog()
    return this._BossAttackLog
end

-- 请求回放数据
function this.RequestRecordData(uid, func)
    NetManager.FightRePlayRequest(3, tostring(uid), function(msg)
        local fightData = msg.fightData
        if not fightData then
            PopupTipPanel.ShowTipByLanguageId(10089)
            return
        end
        if func then func(fightData) end
    end)
end

-- 请求扫荡
function this.RequestSweepBoss(func)
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD_BOSS) then
        PopupTipPanel.ShowTipByLanguageId(10778)
        return
    end
    local leftTimes, _, usedTimes = this.GetLeftAttackTimes()
    if usedTimes == 0 then
        PopupTipPanel.ShowTipByLanguageId(11019)
        return
    end
    if leftTimes <= 0 then
        PopupTipPanel.ShowTipByLanguageId(11018)
        return 
    end
    local isOpenSweep = PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.GUILD_BOSS_JUMP)
    if not isOpenSweep then
        PopupTipPanel.ShowTip(PrivilegeManager.GetPrivilegeOpenTip(PRIVILEGE_TYPE.GUILD_BOSS_JUMP))
        return 
    end
    NetManager.RequestSweepGuildBoss(function(msg)
        -- 刷新挑战次数
        PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.GUILD_BOSS_ATTACK, 1)
        -- 
        Game.GlobalEvent:DispatchEvent(GameEvent.GuildBoss.OnBaseDataChanged)
        if func then func(msg) end
    end)

end


-- 
local _BoxIconConfig = {
    [0] = "i_act_nwsdyy_box1",
    [1] = "i_act_nwsdyy_box1",
    [2] = "i_act_nwsdyy_box2",
    [3] = "i_act_nwsdyy_box3",
    [4] = "i_act_nwsdyy_box4",
    [5] = "i_act_nwsdyy_box5",
}
function this.GetBoxSpriteByLevel(level)
    if level ~= 0 then        
        local config = ConfigManager.GetConfigData(ConfigName.GuildBossRewardConfig, level)
        local iconType = config.Icon
        return Util.LoadSprite(_BoxIconConfig[iconType])
    else
        return Util.LoadSprite(_BoxIconConfig[0])
    end
end

-- 检测公会boss红点显示
function this.CheckGuildBossRedPoint()
    if not ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.GUILD_BOSS) then
        return false
    end
    if PlayerManager.familyId == 0 then
        return false
    end
    if not this._CheckTime then
        this._CheckTime = PlayerPrefs.GetInt(PlayerManager.uid.."_GuildBoss")
    end
    local checkTime = this._CheckTime
    local serData = ActTimeCtrlManager.GetSerDataByTypeId(FUNCTION_OPEN_TYPE.GUILD_BOSS)
    local refreshTimeStamp = serData.startTime
    -- 上次查看时间距离今天刷新时间大于一天
    if refreshTimeStamp - checkTime > 86400 then
        return true
    end
    -- 查看时间小于今天的刷新时间，且刷新时间已经过去
    if checkTime < refreshTimeStamp and GetTimeStamp() > refreshTimeStamp then
        return true
    end
    return false
end
-- 设置今天已查看过
function this.SetGuildBossChecked()
    local curTimeStamp = GetTimeStamp()
    PlayerPrefs.SetInt(PlayerManager.uid.."_GuildBoss", curTimeStamp)
    this._CheckTime = curTimeStamp
    -- 检测一遍公会boss红点
    CheckRedPointStatus(RedPointType.Guild_Boss)
end

return this