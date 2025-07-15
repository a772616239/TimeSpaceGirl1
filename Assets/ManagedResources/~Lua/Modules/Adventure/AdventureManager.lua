AdventureManager = {}
local this = AdventureManager
local GameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local AdventureReward = ConfigManager.GetConfig(ConfigName.AdventureReward)
local AdventureConfig = ConfigManager.GetConfig(ConfigName.AdventureConfig)
local VipLevelConfig = ConfigManager.GetConfig(ConfigName.VipLevelConfig)
local StoreConfig = ConfigManager.GetConfig(ConfigName.StoreConfig)
local privilegeTypeConfig = ConfigManager.GetConfig(ConfigName.PrivilegeTypeConfig)
local TaskConfig = ConfigManager.GetConfig(ConfigName.TaskConfig)
local TrainTask = ConfigManager.GetAllConfigsData(ConfigName.TrainTask)

function this.Initialize()
    this.curOpenFight = 1011 -- 当前开启的关卡
    --奖励名次下限
    this.minRank = {}
    --奖励名次上限
    this.maxRank = {}
    --冒险每日玩家外敌入侵攻打次数
    this.canAttackBossTimes = 0
    --宝箱能出现的时间(60秒加一次收益)
    this.adventureRefresh = 0
    --冒险每日玩家外敌入侵攻打次数，每隔多长时间恢复
    --this.invasionBossTimesAdd = 0
    --宝箱不领取最多能增长奖励的时间(10个小时)
    this.adventureOffline = 0
    --冒险快速战斗计算的收益时长（s）
    this.adventureFastBattle = 0
    --冒险伤害排行榜我的数据
    this.myInfo = 0
    --请求服务刷新Boss时间
    --this.nextBossFlushTime=0
    --已消耗快速领取奖励次数
    this.buyTimsPerDay = 0
    --每日已消耗挑战次数
    this.dayChallengeTimes = 0
    --冒险战斗结果
    this.fightResult = 1
    --Boss请求进入
    this.canBossRequest = true
    --每日奖励
    this.dailyReward = {}
    --冒险伤害排行榜数据
    this.adventureRankItemInfo = {}
    --冒险战斗数据
    this.FightData = {}
    --领取宝箱基础奖励
    this.Drop = {}
    --宝箱展示控制
    this.adventureBoxShow = {}
    --冒险挂机状态信息
    this.adventureStateInfoList = {}
    --领取宝箱随机奖励
    this.randomDrop = {}
    --进攻次数恢复时间
    this.attackTimesRecover = 0
    -- 外敌入侵数据
    this.adventrueEnemyList = {}
    -- 世界聊天
    this.adventureChatList = {}
    this.IsChatListNew = false
    --请求极速探险成功
    this.isSuccess = false
    --显示外敌红点
    this.isCanShowAlianInvasion = false
    --召唤外敌次数
    this.callAlianInvasionTime = 0
    --召唤外敌倒计时时间
    this.callAlianInvasionCountDownTime = 0
    --已击杀外敌Id
    this.hasKilledId = {}
    --是否进入过秘境
    this.isEnterAdventure = false
    --宝箱存在时间
    this.stateTime = 0
    -- 登录时展示的可以获得的挂机奖励
    this.HangOnReward = {}
    --初始化表相关数据
    this.GetTableStaticData()
    --快速训练任务阶段
    this.trainStageLevel = 0

    -- 通关新关卡，时间不够一分钟
    Game.GlobalEvent:AddEvent(GameEvent.Mission.OnOpenFight, function()
        if this.stateTime < 60 then
            this.stateTime = 60
        end
    end)

    -- 删除好友，同时删除其外敌消息
    Game.GlobalEvent:AddEvent(GameEvent.Friend.OnFriendDelete, function(friendId)
        if not this.adventureChatList then return end
        local list = {}
        local isDelete = false
        for _, chat in ipairs(this.adventureChatList) do
            if chat.findUid == friendId then
                isDelete = true
            else
                table.insert(list, chat)
            end
        end
        this.adventureChatList = list
        if isDelete then
            this.IsChatListNew = true
            -- 聊天数据刷新
            Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnChatListChanged)
            -- 刷新外敌列表
            this.RequestAdventureEnemyList()
        end
    end)

    -- 外敌功能解锁，刷新外敌数据
    Game.GlobalEvent:AddEvent(GameEvent.FunctionCtrl.OnFunctionOpen, function(funcId)
        if funcId == FUNCTION_OPEN_TYPE.FIGHT_ALIEN then
            local countDownTime = BagManager.GetItemRecoveryTime(GameSetting[1].AdventureItem)
            if countDownTime ~= nil then
                this.callAlianInvasionRecoverTime = countDownTime
                this.callAlianInvasionTime = BagManager.GetItemCountById(GameSetting[1].AdventureItem)
                CheckRedPointStatus(RedPointType.SecretTer_CallAlianInvasionTime)
            end
        end
    end)

    -- 挂机特权解锁重置挂机时间
    Game.GlobalEvent:AddEvent(GameEvent.Privilege.OnPrivilegeUpdate, function(PrivilegeId)
        -- if PrivilegeId == PRIVILEGE_TYPE.ADVENTURE_EXPLORE then
        --     this.stateTime = 0
        -- end
    end)
end

--冒险所有时间总的倒计时
function this.StartCountDown()
    -- 开始定时刷新
    if not this._CountDownTimer then
        this._CountDownTimer = Timer.New(this.TimeCountDown, 1, -1, true)
        this._CountDownTimer:Start()
    end
end

--读取表的数据进行数据初始化
function this.GetTableStaticData()
    --召唤外敌倒计时总时间
    this.callAlianInvasionCountDownTime = GameSetting[1].ItemAdd[5][3]
    --宝箱能出现的时间(60秒加一次收益)
    this.adventureRefresh = GameSetting[1].AdventureRefresh
    --宝箱不领取最多能增长奖励的时间(10个小时)
    this.adventureOffline = GameSetting[1].AdventureOffline + PrivilegeManager.GetPrivilegeNumber(2002)
    --this.adventureFastBattle = GameSetting[1].AdventureFastBattle
    --冒险宝箱显示的三种状态(达到多少时间显示什么宝箱)
    --每日奖励
    this.adventureBoxShow = GameSetting[1].AdventureBoxShow
    for k, v in ConfigPairs(AdventureReward) do
        this.minRank[k] = v.MinRank
        this.maxRank[k] = v.MaxRank
        table.insert(this.dailyReward, v.DailyReward)
    end
end

function this.TimeCountDown()
    --召唤外敌倒计时恢复
    if this.callAlianInvasionRecoverTime then
        this.callAlianInvasionRecoverTime = this.callAlianInvasionRecoverTime - 1
        this.callAlianInvasionTime = BagManager.GetItemCountById(GameSetting[1].AdventureItem)
        if this.callAlianInvasionTime >= this.callAlianInvasionTotalTime then
            this.callAlianInvasionRecoverTime = 0
        elseif this.callAlianInvasionRecoverTime < 0 then
            this.callAlianInvasionRecoverTime = this.callAlianInvasionCountDownTime
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.CallAlianInvasionTime, this.callAlianInvasionRecoverTime)
    end

    --宝箱产生收益的时间进行时间叠加
    this.stateTime = this.stateTime + 1
    Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnRefeshBoxRewardShow)
    --外敌列表外敌进行倒计时，用于控制分享外敌的逃跑置灰
    if this.adventrueEnemyList then
        local isChanged = false
        for i, v in ipairs(this.adventrueEnemyList) do
            if v.levelTime == GetTimeStamp() then
                this.hasKilledId[v.bossId] = v.bossId
                this.IsChatListNew = true
                isChanged = true
            end
        end
        if isChanged then
            -- 对外敌列表进行排序
            this.SortEnemyList()
            Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnChatListChanged)
            Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnEnemyListChanged)
        end
    end
end

--接收服务器返回的冒险数据
function this.GetAdventureData()
    -- 能够攻打外敌次数
    this.canAttackBossTimes = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.ADVENTURE_BOSS)
    --能够召唤外敌的总次数
    this.callAlianInvasionTotalTime = PrivilegeManager.GetPrivilegeNumber(24)
    --当前拥有的召唤外敌次数
    this.callAlianInvasionTime = BagManager.GetItemCountById(GameSetting[1].AdventureItem)
    -- 简单外敌数据
    this.adventrueEnemyList = FightPointPassManager.adventrueEnemyList
    this.SortEnemyList()

    this.stateTime = FightPointPassManager.HangOnTime

    local rewardList = {}
    if FightPointPassManager.HangOnReward ~= "" then
        local list = string.split(FightPointPassManager.HangOnReward, "|")
        for i = 1, #list do
            local r = string.split(list[i], "#")
            table.insert(rewardList, {tonumber(r[1]), tonumber(r[2])})
        end
    end
    this.HangOnReward = rewardList

    local countDownTime = BagManager.GetItemRecoveryTime(GameSetting[1].AdventureItem)

    if countDownTime ~= nil then
        this.callAlianInvasionRecoverTime = countDownTime
    end
    this.StartCountDown()
    Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnRefreshData)

    this.GetTableStaticData()
end

-- 获取钻石快速训练次数
function this.GetStoneFastBattleCount()
    return ShopManager.GetShopItemData(SHOP_TYPE.FUNCTION_SHOP, 10015).buyNum
end

-- 获取快速训练免费次数
function this.GetSandFastBattleCount()
    return PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.EXPLORE_REWARD)
end

this.fightAreaMax = true
--根据宝箱奖励时间判断是否已经达到最大时长
function this.GetIsMaxTime()
    if UIManager.IsOpen(UIName.GuidePanel) then
        return
    end
    if this.stateTime >= (this.adventureOffline - 1) * 3600 then
        if not UIManager.IsOpen(UIName.SupremeHeroPopup) then
            UIManager.OpenPanel(UIName.FightAreaRewardReminderPopup)
            --UIManager.OpenPanel(UIName.FightAreaRewardFullPopup)
        end
    end
end

--请求Boss伤害排行榜数据
function this.GetAdventurnInjureRankRequest()
    local injuerData = {}
    this.adventureRankItemInfo = {}
    NetManager.GetAdventurnInjureRankRequest(injuerData, 1, function(msg)
        for i, v in ipairs(msg) do
            for m, n in ipairs(v.adventureRankItemInfo) do
                table.insert(this.adventureRankItemInfo, n)
            end
            this.myInfo = v.myInfo
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnInjureRank)
    end)
end

---Boss被击杀刷新数据
function this.GetAdventureBossFlushRequest(msg)
    this.hasKilledId[msg.bossId] = msg.bossId
    this.IsChatListNew = true
    Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnChatListChanged)
end

--- 请求外敌入侵敌人数据
function this.RequestAdventureEnemyList(func)
    NetManager.RequestAdventureEnemyList(function(msg)
        -- 保存数据刷新
        this.adventrueEnemyList = msg.adventureBossInfo
        -- 排序
        this.SortEnemyList()
        if func then
            func()
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnEnemyListChanged)
        -- 重置外敌红点显示
        ResetServerRedPointStatus(RedPointType.SecretTer_Boss)
    end)
end

--保存Boss信息
function this.saveBossInfo()
    this.bossInfo = this.adventrueEnemyList
end

--- 通过动态bossId获取boss数据
function this.GetBossId(bossId)
    local data = nil
    for i, v in ipairs(this.bossInfo) do
        if v.bossId == bossId then
            data = v
        end
    end
    return data
end

--- 获取剩余挑战外敌次数
function this.GetLeftChallengeTimes()
    --TODO: 外敌挑战次数与vip有关
    local leftTimes = this.canAttackBossTimes
    return leftTimes < 0 and 0 or leftTimes
end
--- 获取外敌数据
function this.GetAdventureEnemyList()
    local list = {}
    -- 数据不存在
    if not this.adventrueEnemyList then
        return list
    end
    -- 不显示剩余时间为0的敌人
    for i, v in ipairs(this.adventrueEnemyList) do
        if v.levelTime > GetTimeStamp() then
            table.insert(list, v)
        end
    end
    return list
end

--- 对外敌列表进行排序
function this.SortEnemyList()
    if not this.adventrueEnemyList then return end

    --for index, enemy in ipairs(this.adventrueEnemyList) do
    --end
    table.sort(this.adventrueEnemyList, function(a, b)
        -- 我发现的放在前面
        if a.findUid ~= b.findUid then
            if a.findUid == PlayerManager.uid then return true end
            if b.findUid == PlayerManager.uid then return false end
            return a.findUid < b.findUid
        end
        -- 按时间排序
        if a.levelTime ~= b.levelTime then
            return a.levelTime < b.levelTime
        end
        -- 按bossid排序
        return a.bossId < b.bossId
    end)

    --for index, enemy in ipairs(this.adventrueEnemyList) do
    --end
end

--- 通过动态bossId获取boss数据
function this.GetEnemyDataByBossId(bossId)
    local data = nil
    for i, v in ipairs(this.adventrueEnemyList) do
        if v.bossId == bossId then
            data = v
        end
    end
    return data
end

-- 判断外敌是否被击杀
function this.IsEnemyKilled(id)
    if not this.hasKilledId then
        return false
    end
    if not this.hasKilledId[id] then
        return false
    end
    return true
end

--外敌界面Boss分享请求
this._ShareTimeFlag = 0
function this.GetAdventureBossShareRequest(bossId)
    -- 分享冷却时间5秒
    local curTimeStamp = GetTimeStamp()
    if curTimeStamp - this._ShareTimeFlag < 5 then
        PopupTipPanel.ShowTipByLanguageId(10070)
        return
    end
    this._ShareTimeFlag = curTimeStamp
    -- 请求分享
    NetManager.GetAdventureBossShareRequest(function()
        --TODO: 此处需要好友系统支持，策划说暂时弹出tips提示分享成功。
        PopupTipPanel.ShowTipByLanguageId(10071)
    end, bossId)
end

--外敌界面Boss挑战请求
function this.GetAdventurenBossChallengeRequest(bossData, teamId, fightTimes, skipFight, callBack)
    local isSkip = skipFight
    FightPointPassManager.oldLevel = PlayerManager.level
    NetManager.GetAdventurenBossChallengeRequest(function(msg)
        --if callBack then callBack() end
        this.saveBossInfo()
        this.hurtNums = msg.hurtNums
        local fightResult = msg.fightResult
        --- 发现者名字有两种可能，一个是我和好友的敌人数据，另一种是世界聊天发过来的数据（两种数据结构不同）
        local findName = bossData.findName
        -- if fightResult == 1 and findName == PlayerManager.nickName then
            -- this.Data[bossData.arenaId].bossRemainTime = -1
        -- end
        if isSkip == 0 then
            local fightData = BattleManager.GetBattleServerData(msg)
            this.consumeFightTimes = msg.consumeFightTimes
            if callBack then
                callBack(fightResult)
            end
            UIManager.OpenPanel(UIName.BattleStartPopup, function ()
                local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, function()
                    UIManager.OpenPanel(UIName.AdventureGetRewardPopup, bossData.bossGroupId, msg.consumeFightTimes, msg.hurtNums, fightResult, msg.killRewards, msg.bossTotalHp, msg.bossRemainHp)
                end)
                battlePanel:SetResult(fightResult)  -- 回放战斗必须调用次接口
            end)
        else
            if callBack then
                callBack(fightResult)
            end
            -- 设置战斗数据用于统计战斗
            local _fightData = BattleManager.GetBattleServerData(msg)
            BattleRecordManager.SetBattleRecord(_fightData)
            --打完外敌Boss弹出领取奖励
            UIManager.OpenPanel(UIName.AdventureGetRewardPopup, bossData.bossGroupId, msg.consumeFightTimes, msg.hurtNums, fightResult, msg.killRewards, msg.bossTotalHp, msg.bossRemainHp)
        end
        PrivilegeManager.RefreshPrivilegeUsedTimes(PRIVILEGE_TYPE.ADVENTURE_BOSS, msg.consumeFightTimes)
        this.canAttackBossTimes = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.ADVENTURE_BOSS)
        --BagManager.UpdateItemsNum(44,msg.consumeFightTimes)
        Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnRefreshData)
        -- 重新获取敌人数据
        this.RequestAdventureEnemyList()
    end, bossData.bossId, teamId, fightTimes, skipFight)
end

-- 获取聊天数据
function this.GetChatList()
    this.IsChatListNew = false
    return this.adventureChatList
end

--vip提升更新宝箱时间
function this.UpdateStateTime()
    this.stateTime = 0
end

--解锁跳过战斗功能
function this.IsUnlockBattlePass()
    return PrivilegeManager.GetPrivilegeOpenStatus(PRIVILEGE_TYPE.SkipFight)
end

--Vip等级提升时刷新数据
function this.RefreshAttachVipData()
    this.canAttackBossTimes = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.ADVENTURE_BOSS)
end

--是否进入过秘境
function this.IsEnterAdventure()
    return this.isEnterAdventure
end

--- 召唤外敌请求
function this.CallAlianInvasionRequest(func)
    NetManager.CallAlianInvasionRequest(function(msg)
        local adventureBossInfo = {}
        adventureBossInfo = msg.adventureBossInfo
        -- 刷新召唤外敌次数
        this.callAlianInvasionTime = BagManager.GetItemCountById(GameSetting[1].AdventureItem)
        CheckRedPointStatus(RedPointType.SecretTer_CallAlianInvasionTime)
        -- 计算次数恢复时间
        local counDownTime = BagManager.GetItemRecoveryTime(GameSetting[1].AdventureItem)
        this.callAlianInvasionRecoverTime = counDownTime
        -- 外敌展示界面
        UIManager.OpenPanel(UIName.MonsterShowPanel, adventureBossInfo.bossGroupId, function()
            UIManager.OpenPanel(UIName.FormationPanel, FORMATION_TYPE.ADVENTURE_BOSS, adventureBossInfo)
        end, function()end, true, 4)
        -- 回调
        if func then func() end
    end)
end

--快速训练 type：1-快速训练；2-领取宝箱 position：无用 isCostDemonCrystal：是否花费钻石
function this.GetAventureRewardRequest(type, position, isCostDemonCrystal, isFastBattle, func)
    NetManager.GetAventureRewardRequest(function(msg)
        if type == 2 then
            this.Drop = msg.Drop
            this.randomDrop = msg.randomDrop
            UIManager.OpenPanel(UIName.AdventureExploreRewardPanel, this.Drop, this.randomDrop)
        end
        if isFastBattle then
            if isCostDemonCrystal then
                PrivilegeManager.RefreshPrivilegeUsedTimes(GameSetting[1].AdventureFastBattlePrivilege, 1)
                ShopManager.AddShopItemBuyNum(SHOP_TYPE.FUNCTION_SHOP, 10015, 1)
            else
                local times = AdventureManager.GetSandFastBattleCount()
                local freeTimes = PrivilegeManager.GetPrivilegeRemainValue(PRIVILEGE_TYPE.EXPLORE_REWARD)
                if times <= 0 then
                    if BagManager.GetItemCountById(105) > 0 then
                    else
                        if freeTimes > 0 then
                            PrivilegeManager.RefreshPrivilegeUsedTimes(4, 1)
                        end
                    end
                else
                    if freeTimes > 0 then
                        PrivilegeManager.RefreshPrivilegeUsedTimes(4, 1)
                    end
                end
            end
            Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnFastBattleChanged)
        else
            if this.stateTime >= this.adventureRefresh then
                if this.stateTime >= this.adventureBoxShow[2] then
                    this.stateTime = this.adventureBoxShow[2]
                end
                this.stateTime = this.stateTime % this.adventureRefresh
                -- CheckRedPointStatus(RedPointType.SecretTer_MaxBoxReward)
                Game.GlobalEvent:DispatchEvent(GameEvent.Adventure.OnRefeshBoxRewardShow)
            end
        end
        if func then
            func(msg)
        end
    end, type, position)
end

--快速训练有免费次数时，有免费次数时红点
function this.HaveFreeTime()
    return this.GetSandFastBattleCount() > 0
end

--有召唤外敌次数时显示红点
function this.HaveCallAlianInvasionTime()
    local callAlianInvasionTime = 0
    callAlianInvasionTime = BagManager.GetItemCountById(GameSetting[1].AdventureItem)
    if callAlianInvasionTime >= 1 then
        return true
    else
        return false
    end
end

--宝箱收益最大红点
function this.BoxMaxReward()
    local isMaxReward = false
        if this.stateTime >= this.adventureOffline * 3600 then
            isMaxReward = true
        end
    return isMaxReward
end

--获取快速训练任务阶段
function this.GetTrainStageLevel()
    return this.trainStageLevel
end

--快速训练红点
function this.TrainRedPoint()
    local taskIsOpen = ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.QuickTrain)
    if not taskIsOpen then
        return false
    end
    local taskConfig = ConfigManager.GetConfigDataByKey(ConfigName.TrainTask, "Level", this.GetTrainStageLevel())
    for i = 1, #taskConfig.TaskID do
        local taskData = TaskConfig[taskConfig.TaskID[i]]
        local severData = TaskManager.GetTypeTaskInfo(taskData.TaskType, taskData.Id)
        if severData.state == 1 then
            return true
        end
    end

    return false
end

return this