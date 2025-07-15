FightPointPassManager = {};
local this = FightPointPassManager
local mainLevelConfig = ConfigManager.GetConfig(ConfigName.MainLevelConfig)
local Huo_Dong_Diao_Luo = ConfigManager.GetConfig(ConfigName.ActivityDropReward)
local rewardGroupConfig = ConfigManager.GetConfig(ConfigName.RewardGroup)
local TaskConfig = ConfigManager.GetConfig(ConfigName.TaskConfig)
-- 挂机物品栏位对应vip数值加成特权
local _ItemIdToVipPrivilege = {
    [14] = 1,
    [3] = 1,
    [17] = 27,
}
-- 战斗胜利后是否已经更新过ID
local hadUpdate = false

local CHATER_OPEN = 1
local CHATER_CLOSE = 0
local CHATER_STATE = "CHATER_STATE"

local OLD_ID = "OLD_ID"
local isOpenRewardUpTip = false
function this.Initialize()
    this.curOpenFight = 1011 -- 当前开启的关卡
    this.lastPassFightId = 1011  -- 上一关的ID
    this.isBattleBack = false
    this.HangOnTime = 0 -- 关卡挂机时长
    this.curFightState = 0
    this.oldLevel = 0 -- 玩家关卡战斗之前的等级
    this.curFightMapId = 1011 -- 当前关卡对应的地图背景ID
    this.isOutFight = false
	this.isOpenNewChapter = false -- 是否开启新章节
    this.isMaxChapter = false --是否最大章节
    this.maxChapterNum = 15 --最大章节数
    this.isBeginFight = false
    this.enterFightBattle = false -- 进入关卡战斗
    this.ShowBtnJumpTime = ConfigManager.GetConfig(ConfigName.GameSetting)[1].JumpLevelTime
    this.boxState = 0 -- 当前需要显示的宝箱

    Game.GlobalEvent:AddEvent(GameEvent.Player.OnLevelChange, this.CheckFightRP)
    -- Game.GlobalEvent:AddEvent(GameEvent.Mission.OnOpenEnableFight, this.CheckFightRP)
    Game.GlobalEvent:AddEvent(GameEvent.Mission.OnOpenFight, this.CheckFightRP)

end

function this.CheckFightRP()
    CheckRedPointStatus(RedPointType.SecretTer_IsCanFight)
end

-- 初始化关卡状态, state , 1 已开启未通过 2 :已通过 -1 已开启等级未解锁
function this.InitAllFightPointState(msg)
    if msg.duration  < 0 then
    end

    this.HangOnTime = msg.duration
    this.curOpenFight = msg.fightId
    this.curFightState = msg.state
    this.adventrueEnemyList = msg.adventureBossInfo
    this.HangOnReward = msg.reward
    
    this.maxChapterNum = LengthOfTable(GameDataBase.SheetBase.GetKeys(ConfigManager.GetConfig(ConfigName.MainLevelSettingConfig)))
end

-- 获取某一关卡的状态， 小于当前关卡必定已通关，大于必定未解锁
function this.GetFightStateById(fightId)
    local curDiff = mainLevelConfig[this.curOpenFight].Difficulty
    local judgeDiff = mainLevelConfig[fightId].Difficulty

    --> id不递增 用sortid判断通关情况
    local curFightSortId = mainLevelConfig[this.curOpenFight].SortId
    local fightSortId = mainLevelConfig[fightId].SortId

    if curDiff == judgeDiff then
        -- if fightId < this.curOpenFight then
        --     return FIGHT_POINT_STATE.PASS
        -- elseif fightId == this.curOpenFight then
        --     if this.curFightState == 1 then
        --         return FIGHT_POINT_STATE.OPEN_NOT_PASS
        --     elseif this.curFightState == -1 then
        --         return FIGHT_POINT_STATE.OPEN_LOW_LEVEL
        --     elseif this.curFightState == 2 then
        --         return FIGHT_POINT_STATE.PASS
        --     end
        -- elseif fightId > this.curOpenFight then
        --     return FIGHT_POINT_STATE.LOCK
        -- end
        if fightSortId < curFightSortId then
            return FIGHT_POINT_STATE.PASS
        elseif fightSortId == curFightSortId then
            if this.curFightState == 1 then
                return FIGHT_POINT_STATE.OPEN_NOT_PASS
            elseif this.curFightState == -1 then
                return FIGHT_POINT_STATE.OPEN_LOW_LEVEL
            elseif this.curFightState == 2 then
                return FIGHT_POINT_STATE.PASS
            end
        elseif fightSortId > curFightSortId then
            return FIGHT_POINT_STATE.LOCK
        end
    elseif curDiff > judgeDiff then
        return FIGHT_POINT_STATE.PASS
    elseif curDiff < judgeDiff then
        return FIGHT_POINT_STATE.LOCK
    end
end

-- 获取某一关卡是否开启
function this.GetFightIsOpenById(fightId)
    local curDiff = mainLevelConfig[this.curOpenFight].Difficulty
    local judgeDiff = mainLevelConfig[fightId].Difficulty
    if curDiff == judgeDiff then
        return fightId <= this.curOpenFight
    elseif judgeDiff < curDiff then
        return true
    else
        return false
    end
end

-- 获取某一关卡是否通关
function this.IsFightPointPass(fightId)
    local isPass = false
    local curDiff = mainLevelConfig[this.curOpenFight].Difficulty
    local judgeDiff = mainLevelConfig[fightId].Difficulty
    if curDiff == judgeDiff then
        if fightId < this.curOpenFight then
            isPass = true
        elseif fightId == this.curOpenFight then
            if this.curFightState == 2 then -- 最后一章的最后一关
                isPass = true
            else
                isPass = false
            end
        else
            isPass = false
        end
    elseif curDiff > judgeDiff then
        isPass = true
    else
        isPass = false
    end

    return isPass
end

-- 战斗胜利后，刷新当前关卡的ID
function this.RefreshFightId(msg)
    --local data = mainLevelConfig[this.curOpenFight]
    --if data then
    local oldFight = this.curOpenFight
    this.lastPassFightId = oldFight
    PlayerPrefs.SetInt(PlayerManager.uid .. OLD_ID, oldFight)
    -- 最后一关更新
    --if data.NextLevel ~= -1 then

    -- 服务器更新关卡状态
    this.curOpenFight = msg.fightId
    this.curFightState = msg.state

    if this.curFightState == 1 then
        -- 解锁一个可以打的新关卡, 发送新关卡ID
        Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnOpenEnableFight, msg.fightId)
    end

    -- 章节开启
    local isOpen = mainLevelConfig[this.curOpenFight].PicShow == 1
    --开启新章节的表现处理
    if isOpen then
        this.SetChapterOpenState(true)
    end

    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnOpenFight, oldFight)

    --判断是否需要弹估计奖励提升界面
    local oldLevelConFig = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,this.lastPassFightId)
    local cirLevelConFig = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,this.curOpenFight)
    for i = 1, #cirLevelConFig.RewardShowMin do
        local oldsinglePro = oldLevelConFig.RewardShowMin[i]
        local cursinglePro = cirLevelConFig.RewardShowMin[i]
        if not isOpenRewardUpTip and cursinglePro[2] > oldsinglePro[2] then
            this.SetIsOpenRewardUpTip(true)
        end
    end

    -- 判断新解锁关卡的状态
    --if PlayerManager.level >= data.LevelLimit then
    --    this.curFightState = 1
    --if this.curFightState == 1 then
    --    -- 解锁一个可以打的新关卡, 发送新关卡ID
    --    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnOpenEnableFight, data.NextLevel)
    --end
    --else
    --    this.curFightState = -1
    --end

    ---- 章节开启
    --local isOpen = mainLevelConfig[this.curOpenFight].PicShow == 1
    ----开启新章节的表现处理
    --if isOpen then
    --    this.SetChapterOpenState(true)
    --end
    
    -- 发送关卡通关事件
--[[    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnOpenFight, oldFight)]]
    --else
    --    this.curFightState = 2
    --end
    --end
end
function this.GetIsOpenRewardUpTip()
    return isOpenRewardUpTip
end
function this.SetIsOpenRewardUpTip(_isOpenRewardUpTip)
    isOpenRewardUpTip = _isOpenRewardUpTip
end
function this.SetChapterOpenState(state)
    this.isOpenNewChapter = state
    local value = state and CHATER_OPEN or CHATER_CLOSE
    PlayerPrefs.SetInt(PlayerManager.uid .. CHATER_STATE, value)
end

function this.IsChapterClossState()
    if this.curOpenFight == 1011 then
        return true
    end

    this.isOpenNewChapter = PlayerPrefs.GetInt(PlayerManager.uid .. CHATER_STATE) < 1
    return this.isOpenNewChapter
end

-- 获取当前关卡的ID
function this.GetCurFightId()
    return this.curOpenFight
end

function this.GetLastFightID()
    if PlayerPrefs.GetInt(PlayerManager.uid .. OLD_ID) > 0 then
        this.lastPassFightId = PlayerPrefs.GetInt(PlayerManager.uid .. OLD_ID)
    end
end

-- 获取挂机奖励vip加成
function this.GetItemVipValue(itemId)
    local privilege = _ItemIdToVipPrivilege[itemId]
    if not privilege then return 0 end
    local value = PrivilegeManager.GetPrivilegeNumber(privilege)
    return value
end

-- 点击按钮是判断是否可以挑战
function this.IsCanFight(fightId)
    -- 是否有数据
    if not mainLevelConfig[this.curOpenFight] then
        return false, GetLanguageStrById(10597)
    end

    --章节解锁优先
    if this.IsChapterClossState() then
        -- 以防后端不校验，再来一次
        if PlayerManager.level < mainLevelConfig[this.curOpenFight].LevelLimit then
            return false, tostring(mainLevelConfig[this.curOpenFight].LevelLimit .. GetLanguageStrById(10062))
        else -- 等级不足未通关时设置一下
            if this.curFightState == -1 then
                this.curFightState = 1
            end
        end

        local state = this.GetFightStateById(fightId)
        if state == FIGHT_POINT_STATE.OPEN_NOT_PASS then
            return true, GetLanguageStrById(10599)
        elseif state == FIGHT_POINT_STATE.OPEN_LOW_LEVEL then
            return false, tostring(mainLevelConfig[this.curOpenFight].LevelLimit .. GetLanguageStrById(10062))
        elseif state == FIGHT_POINT_STATE.PASS then   -- 最后一关
            return false, GetLanguageStrById(10601)
        end
    else
        return true, GetLanguageStrById(10602)
    end
end

-- 判断是否显示关卡按钮红点
function this.IsShowFightRP()
    return this.IsCanFight(this.curOpenFight)
end

-- 挑战按钮的文字显示
function this.GetBtnText()
    -- 解锁新章节优先
    if this.IsChapterClossState() then
        -- 先判断等级
        local limitLevel = mainLevelConfig[this.curOpenFight].LevelLimit
        if PlayerManager.level < limitLevel then
            return limitLevel .. GetLanguageStrById(10062)
        end

        local offset = 1
        offset = mainLevelConfig[this.curOpenFight].Difficulty
        local newFightId = (tonumber(this.curOpenFight) - offset) / 10
        local isBoss = (newFightId % 5) == 0
        local str = isBoss and GetLanguageStrById(10476) or GetLanguageStrById(10603)

        -- 最后一关
        local state = this.GetFightStateById(this.curOpenFight)
        if state == FIGHT_POINT_STATE.PASS then   -- 最后一关
            str = GetLanguageStrById(10604)
        end
        return str
    else
        return GetLanguageStrById(10602)
    end
end

-- 是不是首领关卡
function this.IsFightBoss()
    local offset = 1
    offset = mainLevelConfig[this.curOpenFight].Difficulty
    local newFightId = (tonumber(this.curOpenFight) - offset) / 10
    local isBoss = (newFightId % 5) == 0
    return isBoss
end

-- 某一章节是否通关
function this.IsChapterPass(areaId)
    -- 当前关卡难度
    local curFightDiff = mainLevelConfig[this.curOpenFight].Difficulty
    -- 当前章节难度
    local curChapterId = math.floor(this.curOpenFight / 1000)
    if curFightDiff > 1 then
        return true
    elseif curFightDiff == 1 then
        return areaId < curChapterId
    end
end

--- =====================  战力相关的  =============================
---- 请求战斗
function this.ExecuteFightBattle(monsterGroupId, fightId, callBack)
    NetManager.LevelStarFightDataRequest(monsterGroupId, fightId, function (msg)
        hadUpdate = false
        UIManager.OpenPanel(UIName.BattleStartPopup, function ()
            local fightData = BattleManager.GetBattleServerData(msg, nil, fightId)
            UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.STORY_FIGHT, callBack)
        end)
    end)
end

function this.ExecuteFightBattleBefore(root)
    local isPass = FightPointPassManager.IsCanFight(FightPointPassManager.curOpenFight)
    if not isPass then
        PopupTipPanel.ShowTip(FightPointPassManager.GetBtnText())
        return
    end

    FightPointPassManager.oldLevel = PlayerManager.level
    local MonsterGroupId = FightPointPassManager.GetBattleMonsterGroup()
    --> fightInfo
    BattleManager.SetAgainstInfoAICommon(BATTLE_TYPE.STORY_FIGHT, MonsterGroupId)

    FightPointPassManager.enterFightBattle = true
    FightPointPassManager.ExecuteFightBattle(MonsterGroupId, FightPointPassManager.curOpenFight, function()
        if root then
            root:ClosePanel()
        end
        if RewardItemPopup then
            RewardItemPopup:ClosePanel()
        end
    end)
end

-- 获取当前章节数
function this.GetCurChapterIndex()
    local curChapterId = math.floor(this.curOpenFight / 1000)
    if not FightPointPassManager.isOpenNewChapter then
        curChapterId = curChapterId-1
        if curChapterId == 0 then
            curChapterId = 1
        end
    end
    return curChapterId
end

-- 战斗胜利
function this.OnBattleEnd(battleEnd)
    if not hadUpdate then
        hadUpdate = true
        if battleEnd.result == 0 then

        else
            this.isBattleBack = true
            --this.RefreshFightId()
        end
    end
end

-- 关卡战斗结束
function this.FightBattleEnd()
    this.enterFightBattle = false
end

function this.GetBattleMonsterGroup()
    return mainLevelConfig[this.curOpenFight].MonsterGroup
end
--通过难度和章节获取该章节是否通过
function this.GetDifficultAndChapter(Difficult,Chapter)
    -- 当前关卡难度
    local curFightDiff = mainLevelConfig[this.curOpenFight].Difficulty
    -- 当前章节难度
    local curChapterId = math.floor(this.curOpenFight / 1000)
    local state = 0--1 未开启 2 已开启 3 未通关 4 已通关
    if Difficult > curFightDiff then
        state = 1
    elseif Difficult == curFightDiff then
        if Chapter > curChapterId then
            state = 1
        elseif Chapter == curChapterId then
            state = 3
        elseif Chapter < curChapterId then
            state = 4
        end
    elseif Difficult < curFightDiff then
        state = 4
    end
    return state
end


--获取立绘角色奔跑方向
function this.GetRoleDirection()
    local data = {}
    if not FightPointPassManager.IsChapterClossState() then
        data = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,this.lastPassFightId)
    else
        data = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,this.curOpenFight)
    end
    return data.RoleDirection
end

--获取当前关卡位置坐标
function this.GetLevelPointPosition()
    local data = {}
    if not FightPointPassManager.IsChapterClossState() then
        data = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,this.lastPassFightId)
    else
        data = ConfigManager.GetConfigData(ConfigName.MainLevelConfig,this.curOpenFight)
    end
    return data.LevelPointPosition
end

--计算小地图节点坐标
function this.CalculateMapPointPos(parentPoint,sonPoint)
    local scaleValueX = parentPoint.localScale.x
    local scaleValueY = parentPoint.localScale.y
    
    local x = math.floor(sonPoint[1]*(-1)*scaleValueX)
    local y = math.floor(sonPoint[2]*(-1)*scaleValueY)
    return x,y
end

-- 活动期间关卡的总奖励预览
function this.GetExtralReward()
    local fightRewardId = 0
    local openNum = 0
    local rewardShow = {}
    local rewardGroupId = {}

    if mainLevelConfig[this.curOpenFight] then
        fightRewardId = mainLevelConfig[this.curOpenFight].RandomReward[1]
    end

    local ids = ActivityGiftManager.GetExpertActiveisAllOpenIds()

    --local ids = {30, 31}

    if #ids > 0 then
        for i = 1, #ids do
            for k, v in ConfigPairs(Huo_Dong_Diao_Luo) do
                if v.RewardGroup[1] == fightRewardId and v.ActivityId == ids[i] then
                    rewardGroupId[#rewardGroupId + 1] = v.ActivityReward[1]
                end
            end
        end

        for i = 1, #rewardGroupId do

        end
        for i = 1, #rewardGroupId do
            local shows = rewardGroupConfig[rewardGroupId[i]].ShowItem
            if shows then
                for j = 1, #shows do
                    rewardShow[#rewardShow + 1] = shows[j]
                end
            else
 
            end
        end
        return 1, rewardShow
    else
        return openNum, nil
    end
end

function this.SetBoxState(state)
    this.boxState = state
end

function this.GetBoxState()
    return this.boxState
end

-- 是否在关卡里屏蔽暂停按钮
function this.GetStopBtnState()
    local isShow = true
    if not this.enterFightBattle then
        return true
    else
        if this.curOpenFight == 1011 or this.curOpenFight == 1021 or this.curOpenFight == 1031
                or this.curOpenFight == 1041 or this.curOpenFight == 1051 then
            isShow = false
        else
            isShow = true
        end
    end
    return isShow
end

function this:GetHangOnTime()
    return this.HangOnTime
end

function this:RefreshQuickTrain()
    if AdventureManager.GetTrainStageLevel() > 0 and ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.QuickTrain) then
        local taskConfig = ConfigManager.GetConfigDataByKey(ConfigName.TrainTask, "Level", AdventureManager.GetTrainStageLevel())
        for i = 1, #taskConfig.TaskID do
            local taskData = TaskConfig[taskConfig.TaskID[i]]
            local severData = TaskManager.GetTypeTaskInfo(TaskTypeDef.Train, taskData.Id)
            if severData and severData.state == 1 then
                return true
            end
        end
    end

    local freeTimes = AdventureManager.GetSandFastBattleCount()
    return freeTimes > 0
end

return this