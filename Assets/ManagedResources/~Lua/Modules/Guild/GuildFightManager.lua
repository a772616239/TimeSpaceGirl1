--- 公会战管理
GuildFightManager = {}
local this = GuildFightManager

-- 公会战防守数据
this._DefendStageData = {}  -- 只有我的数据
this._AttackStageData = {}

this._GuildFightBaseData = nil
this._EnemyBaseData = {}

--
this._TimeCounter = nil
this._IsRefresh = false


-- 英雄剩余血量数据
local _HeroBloodData = nil

function GuildFightManager.Initialize()

end

-- 初始化数据
function GuildFightManager.InitBaseData(func)
--[[    if PlayerManager.familyId == 0 then
        if func then func() end
        return
    end]]
    NetManager.RequestGuildFightBaseData(function(msg)
        this._GuildFightBaseData = {
            startTime = msg.startTime,
            type = msg.type,
            roundStartTime = msg.roundStartTime,
            roundEndTime = msg.roundEndTime,
            joinType = msg.joinType,
            attackCount = msg.attackCount,
        }
        if func then func() end
    end)

    if not this._TimeCounter then
        this._TimeCounter = Timer.New(this._TimeUpdate, 1, -1, true)
        this._TimeCounter:Start()
    end
end
-- 初始化数据
function GuildFightManager.InitData(func)
    if PlayerManager.familyId == 0 then
        if func then func() end
        return
    end
    -- 有公会刷新一遍数据
    this.RequestGuildFightBaseData(func)

    if not this._TimeCounter then
        this._TimeCounter = Timer.New(this._TimeUpdate, 1, -1, true)
        this._TimeCounter:Start()
    end
end

-- 每秒回调
function this._TimeUpdate()
    -- 不再公会中了
    if PlayerManager.familyId == 0 then
        if this._TimeCounter then
            this._TimeCounter:Stop()
            this._TimeCounter = nil
        end
        return
    end
    -- 正在刷新不执行
    if this._IsRefresh then return end

    -- 公会战时间判断，
    local baseData = this.GetGuildFightData()
    if not baseData then return end

    -- startTime 小于等于0 表是公会战关闭
    if baseData.startTime <= 0 then return end

    local curTime = GetTimeStamp()
    if baseData.type == GUILD_FIGHT_STAGE.UN_START then
        if curTime < baseData.startTime then
            return
        end
    --elseif baseData.type == GUILD_FIGHT_STAGE.EMPTEY then
    --    return
    else
        if curTime < baseData.roundEndTime then
            return
        end
    end

    -- 延时1秒刷新数据
    this._IsRefresh = true
    Timer.New(function()
        this.RequestGuildFightBaseData(function()
            this._IsRefresh = false
        end)
    end, 1, 1, true):Start()
end


-- 获取公会战阶段信息
function GuildFightManager.RequestGuildFightBaseData(func)
    NetManager.RequestGuildFightBaseData(function(msg)
        -- 保存旧阶段
        local oldStage = this.GetCurFightStage()
        -- 新阶段数据
        this._GuildFightBaseData = {
            startTime = msg.startTime,
            type = msg.type,
            roundStartTime = msg.roundStartTime,
            roundEndTime = msg.roundEndTime,
            joinType = msg.joinType,
            attackCount = msg.attackCount,
        }
        -- 设置敌人数据
        this.SetEnemyBaseData(msg.enemy)
        
        if func then func() end

        -- 刷新一遍对应阶段的数据
        if msg.type == GUILD_FIGHT_STAGE.DEFEND then
            this.RequestDefendStageData()
        elseif msg.type == GUILD_FIGHT_STAGE.ATTACK then
            this.RequestAttackStageDefendData()
        elseif msg.type == GUILD_FIGHT_STAGE.COUNTING then
            this.RequestGuildFightResultData()
        end

        -- 发送数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.GuildFight.FightBaseDataUpdate)
        -- 阶段切换事件
        local curStage = this.GetCurFightStage()
        if oldStage ~= curStage then
            -- 发送数据更新事件
            Game.GlobalEvent:DispatchEvent(GameEvent.GuildFight.OnStageChanged, curStage)
            --检测拍脸
            Game.GlobalEvent:DispatchEvent(GameEvent.PatFace.PatFaceSend,FacePanelType.GuildFight)
        end
    end)
end

-- 获取当前公会战基础数据
function GuildFightManager.GetGuildFightData()
    return this._GuildFightBaseData
end

-- 获取当前阶段
function GuildFightManager.GetCurFightStage()
    -- 公会战关闭
    if not this._GuildFightBaseData or this._GuildFightBaseData.startTime <= 0 or this._GuildFightBaseData.joinType == 1 then
        return GUILD_FIGHT_STAGE.CLOSE
    end
    -- 公会解散
    local guildData = MyGuildManager.GetMyGuildInfo()
    if guildData and guildData.levelTime ~= 0 then
        return GUILD_FIGHT_STAGE.DISSMISS
    end
    return this._GuildFightBaseData.type
end

-- 判断当前是否在公会战中
function GuildFightManager.IsInGuildFight()
    local curStage = this.GetCurFightStage()
    if curStage == GUILD_FIGHT_STAGE.CLOSE
        or curStage == GUILD_FIGHT_STAGE.DISSMISS
        or curStage == GUILD_FIGHT_STAGE.UN_START then
        return false
    end
    return true
end

-- 获取剩余进攻次数
function GuildFightManager.GetLeftAttackCount()
    if not this._GuildFightBaseData then return end
    local attackCount = this._GuildFightBaseData.attackCount
    local maxCount = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).AttackNum
    local leftCount = maxCount - attackCount
    leftCount = leftCount < 0 and 0 or leftCount
    return leftCount
end


---============================布防阶段=================================
-- 请求获取布防阶段防守数据
function GuildFightManager.RequestDefendStageData(func)
    NetManager.RequestDefendStageData(function(msg)
        this._DefendStageData = {}
        for _, data in ipairs(msg.info) do
            this._DefendStageData[data.uid] = data
        end
        -- 公会防守编队正确性检测
        FormationManager.CheckGuildFightDefendFormation()
        -- 发送数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.GuildFight.DefendDataUpdate)
        if func then func() end
    end)
end

-- 公会战防守数据刷新
function GuildFightManager.UpdateDefendStageData(msg)
    if not this._DefendStageData then
        this._DefendStageData = {}
    end
    -- 建筑为0表示删除
    if msg.buildId == 0 then
        this._DefendStageData[msg.uid] = nil
    else
        this._DefendStageData[msg.uid] = msg
    end
    -- 数据更新
    Game.GlobalEvent:DispatchEvent(GameEvent.GuildFight.DefendDataUpdate)
end

-- 重置防守阵容战斗力
function GuildFightManager.ResetDefendStageDataForce(uid, force)
    if not uid then return end
    if not this._DefendStageData then return end
    if not this._DefendStageData[uid] then return end
    -- 修改数据
    this._DefendStageData[uid].curForce = force
    -- 发送数据更新事件
    Game.GlobalEvent:DispatchEvent(GameEvent.GuildFight.DefendDataUpdate)
end

-- 请求防守
function GuildFightManager.RequestDefend(buildType, func)
    NetManager.RequestGuildFightDefend(PlayerManager.uid, buildType, function(msg)
        -- 修改我的建筑
        if not this._DefendStageData or not this._DefendStageData[PlayerManager.uid] then
            this.RequestDefendStageData(func)
            return
        end
        this._DefendStageData[PlayerManager.uid].buildId = buildType
        -- 刷新数据
        if func then func() end
    end)
end

-- 请求改变队员的防守建筑
function GuildFightManager.RequestChangeMemDefend(uid, buildType, func)
    if this.GetCurFightStage() ~= GUILD_FIGHT_STAGE.DEFEND then
        PopupTipPanel.ShowTipByLanguageId(10874)
        return
    end
    local pos = MyGuildManager.GetMyPositionInGuild()
    if pos ~= GUILD_GRANT.MASTER and pos ~= GUILD_GRANT.ADMIN then
        PopupTipPanel.ShowTipByLanguageId(10875)
        return
    end
    local oriBuildType = this.GetDefendStagePlayerBuildType(uid)
    if oriBuildType == buildType then
        PopupTipPanel.ShowTipByLanguageId(10876)
        return
    end
    NetManager.RequestGuildFightDefend(uid, buildType, function(msg)
        PopupTipPanel.ShowTipByLanguageId(10877)
        -- 刷新数据
        if func then func() end
    end)
end

-- 获取公会战防守数据
function GuildFightManager.GetDefendStageBuildDefendData(buildType)
    local list = {}
    if not this._DefendStageData then
        return list
    end
    for _, data in pairs(this._DefendStageData) do
        if buildType == data.buildId then
            table.insert(list, data)
        end
    end
    table.sort(list, function(a, b)
        local ad = MyGuildManager.GetMemInfo(a.uid)
        local bd = MyGuildManager.GetMemInfo(b.uid)
        if ad.position == bd.position then
            return a.curForce > b.curForce
        end
        return ad.position < bd.position
    end)
    return list
end

-- 获取玩家防守阶段处于哪一个建筑
function GuildFightManager.GetDefendStagePlayerBuildType(uid)
    if not this._DefendStageData then
        return
    end
    local data = this._DefendStageData[uid]
    if not data then
        return
    end
    return data.buildId
end

---===============================匹配阶段数据==========================

-- 设置敌方公会基础信息
function this.SetEnemyBaseData(data)
    local _CurStage = this._GuildFightBaseData.type
    local _JoinType = this._GuildFightBaseData.joinType
    -- 轮空，未开始，防守阶段无敌方数据
    if _JoinType == 1 or _CurStage == GUILD_FIGHT_STAGE.UN_START or _CurStage == GUILD_FIGHT_STAGE.DEFEND then
        this._EnemyBaseData = nil
    else
        this._EnemyBaseData = data
    end
    -- 发送数据更新事件
    Game.GlobalEvent:DispatchEvent(GameEvent.GuildFight.EnemyBaseDataUpdate)
end
-- 获取敌方公会基础信息
function GuildFightManager.GetEnemyBaseData()
    local _CurStage = this._GuildFightBaseData.type
    if _CurStage == GUILD_FIGHT_STAGE.EMPTEY or _CurStage == GUILD_FIGHT_STAGE.UN_START or _CurStage == GUILD_FIGHT_STAGE.DEFEND then
        return
    end
    if not this._EnemyBaseData or this._EnemyBaseData.id == 0 then
        return
    end
    return this._EnemyBaseData
end

-- 获取我方公会基础信息
function GuildFightManager.GetMyBaseData()
    local data = {}
    local baseData = MyGuildManager.GetMyGuildInfo()
    data.name = baseData.name
    data.level = baseData.levle
    data.pictureId = baseData.icon
    data.totalStar = this._EnemyBaseData and this._EnemyBaseData.myTotalStar or this.GetLeftStarNum(GUILD_FIGHT_GUILD_TYPE.MY)
    return data
end

---=========================== 进攻阶段数据 ============================
local _GuildBuffList = {}   -- 公会buff属性数据
-- 请求获取公会战防守数据
function GuildFightManager.RequestAttackStageDefendData(func)
    NetManager.RequestAttackStageDefendData(function(msg)
        this._AttackStageData = {}
        for _, guildBuildData in ipairs(msg.info) do
            -- 判断公会类型
            local guildType = GUILD_FIGHT_GUILD_TYPE.MY
            if guildBuildData.gid ~= PlayerManager.familyId then
                guildType = GUILD_FIGHT_GUILD_TYPE.ENEMY
            end

            -- 保存公会数据
            this._AttackStageData[guildType] = guildBuildData
            -- 清空属性数据
            _GuildBuffList = {}
            -- 发送数据更新事件
            Game.GlobalEvent:DispatchEvent(GameEvent.GuildFight.AttackStageDefendDataUpdate, guildType)
        end

        if func then func() end
    end)
end
-- 获取某建筑防守信息数据
function GuildFightManager.GetAttackStageBuildDefendData(guildType, buildType)
    local list = {}
    if not this._AttackStageData or not this._AttackStageData[guildType] then
        return list
    end
    for _, data in ipairs(this._AttackStageData[guildType].user) do
        if buildType == data.buildId then
            table.insert(list, data)
        end
    end
    return list
end

-- 获取公会战中战力排名前三的玩家数据
function GuildFightManager.GetAttackStageFirstThreeMem(guildType)
    local list = {}
    if not this._AttackStageData or not this._AttackStageData[guildType] then
        return list
    end
    table.sort(this._AttackStageData[guildType].user, function(a, b)
        return a.userInfo.soulForce > b.userInfo.soulForce
    end)
    local index = 0
    for _, data in ipairs(this._AttackStageData[guildType].user) do
        table.insert(list, data)
        index = index + 1
        if index >= 3 then break end
    end
    return list
end

-- 获取某建筑buff信息
function GuildFightManager.GetAttackStageBuildBuffData(guildType, buildType)
    if not this._AttackStageData or not this._AttackStageData[guildType] then
        return
    end

    local list = {}
    for _, data in ipairs(this._AttackStageData[guildType].buildBuff) do
        if buildType == data.buildId then
            for _, id in ipairs(data.buffId) do
                local config = ConfigManager.GetConfigData(ConfigName.FoodsConfig, id)
                if config and config.EffectPara then
                    for _, prop in ipairs(config.EffectPara) do
                        local pid = prop[1]
                        local pv = prop[2]
                        if not list[pid] then
                            list[pid] = 0
                        end
                        list[pid] = list[pid] + pv
                    end
                end
            end
        end
    end

    local propList = {}
    for id, value in pairs(list) do
        table.insert(propList, {id = id, value = value})
    end
    table.sort(propList, function(a, b)
        return a.id < b.id
    end)
    return propList
end

-- 获取公会建筑所有buff表（相同buff数值合并）
function GuildFightManager.GetGuildBuffList(guildType)
    if not _GuildBuffList[guildType] then
        local list = {}
        if not this._AttackStageData or not this._AttackStageData[guildType] then
            return list
        end
        for _, data in ipairs(this._AttackStageData[guildType].buildBuff) do
            for _, id in ipairs(data.buffId) do
                local config = ConfigManager.GetConfigData(ConfigName.FoodsConfig, id)
                if config and config.EffectPara then
                    for _, prop in ipairs(config.EffectPara) do
                        local pid = prop[1]
                        local pv = prop[2]
                        if not list[pid] then
                            list[pid] = 0
                        end
                        list[pid] = list[pid] + pv
                    end
                end
            end
        end

        local propList = {}
        for id, value in pairs(list) do
            table.insert(propList, {id = id, value = value})
        end
        table.sort(propList, function(a, b)
            return a.id < b.id
        end)

        _GuildBuffList[guildType] = propList
    end
    return _GuildBuffList[guildType]
end



-- 获取某人的防守信息数据
function GuildFightManager.GetAttackStagePlayerDefendData(guildType, uid)
    local list = {}
    if not this._AttackStageData or not this._AttackStageData[guildType] then
        return list
    end
    for _, data in ipairs(this._AttackStageData[guildType].user) do
        if uid == data.userInfo.roleUid then
            return data
        end
    end
end


-- 请求进攻
function GuildFightManager.RequestAttack(uid, func)
    if this.GetCurFightStage() ~= GUILD_FIGHT_STAGE.ATTACK then
        PopupTipPanel.ShowTipByLanguageId(10878)
        return
    end

    local leftCount = this.GetLeftAttackCount()
    if not leftCount or leftCount <= 0 then
        PopupTipPanel.ShowTipByLanguageId(10734)
        return
    end

    local enemyGuild = this.GetEnemyBaseData()
    if not enemyGuild.id then return end

    NetManager.RequestGuildFightAttackEnemy(enemyGuild.id, uid, function(msg)
        this._GuildFightBaseData.attackCount = this._GuildFightBaseData.attackCount + 1
        _HeroBloodData = nil
        this.RequestMyHeroBloodData()
        if func then func(msg) end
    end)
end

-- 公会战某人被kill
function GuildFightManager.KillSomeBody(msg)
    for guildType, data in pairs(this._AttackStageData) do
        for _, user in ipairs(data.user) do
            if user.userInfo.roleUid == msg.uid then

                if user.starCount > msg.teamLostStar then
                    user.starCount = user.starCount - msg.teamLostStar
                else
                    user.starCount = 0
                end
                -- 发送数据更新事件
                Game.GlobalEvent:DispatchEvent(GameEvent.GuildFight.AttackStageDefendDataUpdate, guildType)
                return
            end
        end
    end
end

-- 请求我的妖灵师的血量数据
function GuildFightManager.RequestMyHeroBloodData(func)
    --if not _HeroBloodData then
        NetManager.RequestMyHeroBloodData(function(msg)
            local lostBloodList = {}
            for _, data in ipairs(msg.blood) do
               
               
                lostBloodList[data.heroId] = data.lostBlood
            end
            local heroHPList = {}
            local allHero = HeroManager.GetAllHeroDatas()
            for _, hero in ipairs(allHero) do
                local lostHp = lostBloodList[hero.dynamicId] or 0
                local leftHp = 1 - lostHp/100
                leftHp = leftHp < 0 and 0 or leftHp
                heroHPList[hero.dynamicId] = leftHp
            end
            _HeroBloodData = heroHPList

            if func then func() end
        end)
    --end
    --
    --if func then func() end
end

-- 获取英雄血量数据
function GuildFightManager.GetMyHeroBloodData()
    return _HeroBloodData or {}
end

-- 获取双方剩余的总星数
local _PosMaxStar = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).StarNum
local _BuildStar = ConfigManager.GetConfigData(ConfigName.GuildSetting, 1).BuildingStar
function GuildFightManager.GetLeftStarNum(guildType)
    local curStage = this.GetCurFightStage()
    -- 计算公会失去的星数
    local function GetLeftStar(guildType)
        -- 获取数据
        local userList = nil
        if curStage == GUILD_FIGHT_STAGE.ATTACK then
            if not this._AttackStageData or not this._AttackStageData[guildType] then
                return 0
            end
            userList = this._AttackStageData[guildType].user
        elseif curStage == GUILD_FIGHT_STAGE.MATCHING and guildType == GUILD_FIGHT_GUILD_TYPE.MY then
            userList = this._DefendStageData
        end
        -- 没有数据返回0
        if not userList then return 0 end
        -- 开始计算星数
        local allLeftStar = 0
        local buildLeftStar = {}
        -- 计算布防人员失去的总星数
        for _, user in ipairs(userList) do
            local leftStar = user.starCount
            allLeftStar = allLeftStar + leftStar
            buildLeftStar[user.buildId] = (buildLeftStar[user.buildId] or 0) + leftStar
        end
        -- 判断建筑是否失守
        for _, buildType in pairs(GUILD_BUILD_TYPE) do
            if buildLeftStar[buildType] and buildLeftStar[buildType] > 0 then
                allLeftStar = allLeftStar + _BuildStar[buildType]
            end
        end
        return allLeftStar
    end
    return GetLeftStar(guildType)
end
-- 获取双方获得星数
function GuildFightManager.GetBothGetStarNum()
    local curStage = GuildFightManager.GetCurFightStage()
    if curStage == GUILD_FIGHT_STAGE.ATTACK then
        -- 没有数据返回0
        if not this._AttackStageData then
            return 0, 0
        end
        -- 计算公会失去的星数
        local function GetLostStar(guildType)
            local data = this._AttackStageData[guildType]
            if not data then
                return 0
            end
            local allLostStar = 0
            local buildLeftStar = {}
            -- 计算布防人员失去的总星数
            for _, user in ipairs(data.user) do

                local maxStar = _PosMaxStar[user.userInfo.position]
                local leftStar = user.starCount
                local lostStar = maxStar - leftStar
                allLostStar = allLostStar + lostStar

                --if not buildLeftStar[user.buildId] then
                --    buildLeftStar[user.buildId] = 0
                --end
                buildLeftStar[user.buildId] = (buildLeftStar[user.buildId] or 0) + leftStar
            end
            -- 判断建筑是否失守
            for _, buildType in pairs(GUILD_BUILD_TYPE) do
                if not buildLeftStar[buildType] or buildLeftStar[buildType] == 0 then
                    allLostStar = allLostStar + _BuildStar[buildType]
                end
            end
            return allLostStar
        end
        -- 我失去的就是敌人得到的，我得到就是敌人失去的
        local myGetStar = GetLostStar(GUILD_FIGHT_GUILD_TYPE.ENEMY)
        local enemyGetStar = GetLostStar(GUILD_FIGHT_GUILD_TYPE.MY)
        return myGetStar, enemyGetStar

    elseif curStage == GUILD_FIGHT_STAGE.COUNTING then
        if not this._GuildFightResultData then
            return 0, 0
        end
        local myGetStar, enemyGetStar = 0, 0
        for index, starNum in ipairs(this._GuildFightResultData.star) do
            local exStarNum = this._GuildFightResultData.extraStar[index]
            if index <= 3 then
                myGetStar = myGetStar + starNum + exStarNum
            else
                enemyGetStar = enemyGetStar + starNum + exStarNum
            end
        end
        return myGetStar, enemyGetStar
    end
end


---================================结算数据==========================
-- 请求公会战结果
function GuildFightManager.RequestGuildFightResultData(func)
    NetManager.RequestGuildFightResultData(function(msg)
        this._GuildFightResultData = msg
        -- 发送数据更新事件
        Game.GlobalEvent:DispatchEvent(GameEvent.GuildFight.ResultDataUpdate)
        if func then func() end
    end)
end
-- 获取公会战结果
function GuildFightManager.GetGuildFightResultData()
    return this._GuildFightResultData
end
-- 请求公会战排名
function GuildFightManager.RequestGuildFightAttackLogData(type, func)
    NetManager.RequestGuildFightAttackLogData(type, function(msg)
        if not this._GuildFightAttackLogData then
            this._GuildFightAttackLogData = {}
        end
        this._GuildFightAttackLogData[type] = msg.result
        if func then func() end
    end)
end
-- 获取公会战排名数据
function GuildFightManager.GetGuildFightAttackLogData(type)
    if not this._GuildFightAttackLogData then
        return
    end
    return this._GuildFightAttackLogData[type]
end

-- 获取公会战排名奖励
local _RewardList = nil
function GuildFightManager.GetGuildFightRewardData()
    if not _RewardList or #_RewardList == 0 then
        _RewardList = {}
        local rewardList = ConfigManager.GetConfig(ConfigName.GuildRewardConfig)
        for id, data in ConfigPairs(rewardList) do
            table.insert(_RewardList, data)
        end
    end
    return _RewardList
end


--- =============== 阶段tip提示状态设置
this._CurTipStage = nil
function GuildFightManager.SetCurTipStage(stage)
    this._CurTipStage = stage
end
function GuildFightManager.GetCurTipStage()
    return this._CurTipStage
end



return GuildFightManager