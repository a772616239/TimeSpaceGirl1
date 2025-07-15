PlayerManager = {}
local this = PlayerManager
local gameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
local HeroConfig = ConfigManager.GetConfig(ConfigName.HeroConfig)
this.userLevelData = ConfigManager.GetConfig(ConfigName.PlayerLevelConfig)
this.globalSystemConfig = ConfigManager.GetConfig(ConfigName.GlobalSystemConfig)
local TitleConfig = ConfigManager.GetConfig(ConfigName.TitleConfig)
this.serverTime = 0
this.maxEnergy = 0
this.singleAddEnergy = gameSetting[1].EnergyRecoverSpeed[1]
this.singleAddTimeGap = gameSetting[1].EnergyRecoverSpeed[2]
this.exp = 0
this.level = 0
this.maxForce = 0
-- 每次重置的时间
this.startTime = 0
-- 已经计时的时间
this.durationTime = 0
-- 设置计时状态
this.isStart = false
--图鉴
this.heroHandBook = {}
this.equipHandBook = {}
this.talismanHandBook = {}
this.heroHandBookListData = {}
--移动速度 和  视野范围
this.MapSpeed = 0
this.MapView = 0
--性别
this.sex = 0
--称号队列
this.titList = {}
this.receivedList = {}
this.isShowVip = false
local update = function()
    local dt = Time.unscaledDeltaTime
    this.serverTime = this.serverTime + dt
    this.UpdateEnergyData()
end
function this.Initialize()
    Game.GlobalEvent:AddEvent(GameEvent.Network.OnReceiveHeartBeat, function(network, time)
        if network.type == SocketType.LOGIN then
            this.serverTime = time
        end
    end)
    Game.GlobalEvent:AddEvent(GameEvent.Player.OnGoldChange, this.OnGoldChange)
end

function this.InitServerTime()
    UpdateBeat:Add(update, this)
end

function this.OnGoldChange()
end

--每间隔一段时间恢复精力
function this.UpdateEnergyData()
    -- 一个计时器

    if MapManager.isOpen then
        local dt = this.serverTime - this.startTime
        dt = math.floor(dt)
        if dt ~= this.durationTime then
            -- 数值更新
            this.durationTime = dt
            Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnTimeChange, this.durationTime)
        end
    end

    -- 截取服务器时间
    ActTimeCtrlManager.Updata()
    ActTimeCtrlManager.serTime = math.floor(this.serverTime)
    -- 刷新需要刷新的道具
    -- this.RefreshItemNumBySerTime()
end
local needRefreshItemTabs = {1,44, 53,54}
local isAddItem = {
    [1] = true,
    --[2] = true,
    [44] = true,
    [53] = true,
    [54] = true,
}
-- 刷新需要刷新的道具
function this.RefreshItemNumBySerTime()
    for i, itemId in pairs(needRefreshItemTabs) do
        --一些类型的特殊判断
        if itemId == 1 then--行动力
            if not EndLessMapManager.isTrigger and not EndLessMapManager.EnergyEnough() then-- 已经是行动力的上限不再刷新-- 正在正在触发事件不刷新
                this.RefreshItemNumById(itemId)
            end
        elseif  itemId == 44 then--外敌挑战券
            if BagManager.GetItemCountById(itemId) then
                this.RefreshItemNumById(itemId)
            end
        elseif  itemId == 53 then--兽潮入场券
            this.RefreshItemNumById(itemId)
        elseif  itemId == 54 then-- 召唤外敌次数
            this.RefreshItemNumById(itemId)

        end
    end
end

--获取称号列表
function this.GetTitleList()
    return this.titList
end

--设置称号列表
function this.SetTitleList(data)
    this.titList = data
end

--当前佩戴的称号倒计时
function this.TimeDownTitle()
    local time = 0
    if PlayerManager.designation > 0 then
        for index, value in ipairs(this.titList) do
            if PlayerManager.designation == value.tid then
                local configTime = TitleConfig[value.tid].Time
                if configTime ~= 0 then
                    time = value.insertDateTime/1000 + configTime
                    -- LogError(value.insertDateTime/1000 .. "   "..configTime)
                    break
                end
            end
        end
    end

    if this.titleTimer then
        this.titleTimer:Stop()
        this.titleTimer = nil
    end
    if time <= 0 or time == nil then
        return
    end

    this.titleTimer = Timer.New(function()
        if time - GetTimeStamp() <= 0 then
            this.titleTimer:Stop()
            this.titleTimer = nil
            local msg = {
                type = 2,
                tid = PlayerManager.designation,
            }
            this.RefreshTitle(msg)
        end
    end, 1, -1, true)
    this.titleTimer:Start()
end

--推送称号
function this.RefreshTitle(msg)
    local oldPower = FormationManager.GetFormationPower(1)

    local list = {}
    --失去称号
    if msg.type == 2 then
        if PlayerManager.designation > 0 then
            if PlayerManager.designation == msg.tid then
                PlayerManager.SetPlayerDesignation(0)
            end
        end

        for i, v in ipairs(this.titList) do
            if v.tid ~= msg.tid then
                table.insert(list, v)
            end
        end
    elseif msg.type == 1 then --获得称号
        list = this.titList
        local _list = {}
        _list.tid = msg.tid
        -- _list.insertDateTime = 
        -- _list.curUseTitileId = 
        table.insert(list, _list)
    end

    this.SetTitleList(list)

    FormationManager.FlutterPower(oldPower)

    Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnPlayTitleChange)
end

local nextRefreshTime = 0
function this.RefreshItemNumById(itemId)
    if not BagManager.bagDatas[itemId] then return end
    nextRefreshTime = BagManager.bagDatas[itemId].nextFlushTime
    if nextRefreshTime then
        if this.serverTime >= nextRefreshTime and nextRefreshTime ~= 0 then
            if isAddItem[itemId] then
                isAddItem[itemId] = false
                --地图里需要特殊处理  其他正常
                if itemId == 1 and CarbonManager.difficulty == CARBON_TYPE.ENDLESS and MapManager.isInMap then
                    if #MapManager.stepList > 0 then
                        MapManager.MapUpdateEvent(-1000, function ()
                            NetManager.RefreshEnergyRequest({itemId},function()
                                isAddItem[itemId] = true
                                EndLessMapManager.isUpdateOnClose = true
                            end)
                        end)
                    else
                        NetManager.RefreshEnergyRequest({itemId},function()
                            isAddItem[itemId] = true
                            EndLessMapManager.isUpdateOnClose = true
                        end)
                    end
                else
                    NetManager.RefreshEnergyRequest({itemId},function()
                        isAddItem[itemId] = true
                    end)
                end
            end
        end

    end
end
this.curLevelAndExp = {}
function this.BcakUpdateUserExp(_msg)
    if not UIManager.IsOpen(UIName.FightMopUpEndPanel) then
        this.exp = _msg.exp
        local oldLevel = this.level
        this.level = _msg.level

        if this.level > oldLevel then
            CheckRedPointStatus(RedPointType.HeroExplore)
            -- CheckRedPointStatus(RedPointType.HeroExplore_OpenMap)
            CheckRedPointStatus(RedPointType.EpicExplore)
            --FightManager.SetAndGetSingleFightState3(this.level)
            RedPointManager.SetExploreRedPoint({ level = this.level })
        end
        Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnPlayerLvChange)
        this.maxEnergy = this.userLevelData[this.level].MaxEnergy
    else
        this.curLevelAndExp = _msg
    end
end
--根据经验进行升级
function this.PromoteLevel(exp)
    local maxPlayerLv = GameDataBase.SheetBase.GetKeys(this.userLevelData)
    this.exp = this.exp + exp
    while this.exp >= this.userLevelData[this.level].Exp and this.level < #maxPlayerLv do
        this.exp = this.exp - this.userLevelData[this.level].Exp
        this.level = this.level + 1
        this.level = this.level >= #maxPlayerLv and #maxPlayerLv or this.level
        CheckRedPointStatus(RedPointType.HeroExplore)
        CheckRedPointStatus(RedPointType.EpicExplore)
        CheckRedPointStatus(RedPointType.SecretTer_NewHourseOpen)
        --FightManager.SetAndGetSingleFightState3(this.level)
        RedPointManager.SetExploreRedPoint({ level = this.level })
    end
    this.maxEnergy = this.userLevelData[this.level].MaxEnergy

    -- 看看这个玩家是否升级了
    --if PlayerManager.level > FightManager.oldLevel then
    --    Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnLevelChange)
    --end
    -- 打点数据
    -- TapDBManager.SetLevel(this.level)
    -- ThinkingAnalyticsManager.SetSuperProperties({

    -- })
end
function this.SetMaxEnergy()
    this.maxEnergy = this.userLevelData[this.level].MaxEnergy
end
--获取单个英雄装备被动技能累计评分
function this.GetSingHeroAllEquipSkillListScore(_curHeroData)
    local Score = 0
    local curHeroData = _curHeroData
    if curHeroData and curHeroData.equipIdList then
        for i = 1, #curHeroData.equipIdList do
            local curEquip = EquipManager.GetSingleEquipData(curHeroData.equipIdList[i])
            if curEquip then
                --if curEquip.skillId and curEquip.skillId > 0 then
                    Score = Score + curEquip.equipConfig.Score
                --end
            end
        end
    end
    return Score
end

--图鉴更新
function this.InitHandBookData(heroHandBook, talismanHandBook)
    --根据后端传的有过的所有英雄的数据更新本地英雄图鉴数据
    if heroHandBook and #heroHandBook > 0 then
        for n,m in ipairs(heroHandBook) do
            if not PlayerManager.heroHandBook then
                PlayerManager.heroHandBook = {}
                if HeroConfig[m.heroId].Material == 1 then--材料英雄
                    PlayerManager.heroHandBook[m.heroId] = {maxStar = 0, status = 1}
                else
                    PlayerManager.heroHandBook[m.heroId] = {maxStar = 0, status = 0}
                end
            end
            if not PlayerManager.heroHandBook[m.heroId] then
                if HeroConfig[m.heroId].Material == 1 then
                    PlayerManager.heroHandBook[m.heroId] = {maxStar = 0, status = 1}
                else
                    PlayerManager.heroHandBook[m.heroId] = {maxStar = 0, status = 0}
                end
            end
            if HeroConfig[m.heroId].Material == 1 then
                PlayerManager.heroHandBook[m.heroId].status = 1
            else
                PlayerManager.heroHandBook[m.heroId].status = m.status
            end
        end
    end
    --根据后端传的有过的所有装备的数据更新本地装备图鉴数据
    if talismanHandBook and #talismanHandBook > 0 then
        for i = 1, #talismanHandBook do
            PlayerManager.talismanHandBook[talismanHandBook[i]] = talismanHandBook[i]
        end
    end
end

--领取了英雄图鉴奖励
function this.ReceivedHandBookData(heroSId)
    if this.heroHandBook[heroSId] == nil then
        LogError("还未获得该英雄，请排查错误！！！")
    else
        this.heroHandBook[heroSId].status = 1
    end
end

--获得新英雄
function this.SetHeroHandBookListData(heroSId,heroStar)
    if this.heroHandBook[heroSId] == nil or next(this.heroHandBook[heroSId]) == nil then
        local state = 0
        if HeroConfig[heroSId].Material == 1 then
            state = 1
        end
        this.heroHandBook[heroSId] = {maxStar = heroStar, status = state}
    else
        if this.heroHandBook[heroSId].maxStar < heroStar then
            this.heroHandBook[heroSId].maxStar = heroStar
        end
    end
    CheckRedPointStatus(RedPointType.General)
end
function this.SetEquipHandBookListData(equipSId)
    if this.equipHandBook[equipSId] == nil then
        this.equipHandBook[equipSId] = equipSId
    end
end
--------------------------------------------

-- 切磋
function this.RequestPlayWithSomeOne(uid, teamId, tname, func)
    if uid == PlayerManager.uid then
        PopupTipPanel.ShowTipByLanguageId(11509)
        return
    end
    BattleManager.GotoFight(function()
        NetManager.RequestPlayWithSomeOne(uid, teamId, function(msg)
            local fightData = BattleManager.GetBattleServerData({fightData = msg.fightData}, 1)
            if tname then
                tname = PlayerManager.nickName .."|" .. tname
            end
            BattleRecordManager.SetBattleRecord(fightData)
            BattleRecordManager.SetBattleBothNameStr(tname)
            UIManager.OpenPanel(UIName.BattleStartPopup, function()
            BattleRecordManager.GetBattleRecord()
            local battlePanel = UIManager.OpenPanel(UIName.BattlePanel, fightData, BATTLE_TYPE.BACK, func, nil, BATTLE_TYPE_BACK.BACK_WITH_SB)
            battlePanel:SetResult(BattleLogic.Result)
            end)
        end)
    end)
end

-----------------------------------玩家坐骑 皮肤 称号ID推送

--设置玩家称号
function this.SetPlayerDesignation(value)
    PlayerManager.designation = value
    NetManager.chenghaoRequest(function (msg)
        this.TimeDownTitle()
    end)
end
--设置玩家皮肤
function this.SetPlayerSkin(value)
    PlayerManager.skin = value
end
--设置玩家坐骑
function this.SetPlayerRide(value)
    PlayerManager.ride = value
end
--设置玩家坐骑等级
function this.SetPlayerRideLv(value)
    PlayerManager.rideLevel = value
end
--设置当前玩家 视野范围 和 移动速度
function this.SetMoveSpeedAndMapView()
    if PlayerManager.ride > 0 then
        local playerMountLevelUpConFig = ConfigManager.GetConfigData(ConfigName.PlayerMountLevelUp,PlayerManager.rideLevel)
        if playerMountLevelUpConFig then
            this.MapSpeed = playerMountLevelUpConFig.MapSpeed
            this.MapView = playerMountLevelUpConFig.MapView
        end
    end
end
--计算 称号 皮肤 坐骑战力加成
function this.CalculatePlayerDcorateProAddVal()
    local addAllProVal = {}

    --称号
    if this.titList and #this.titList > 0 then
        for k,v in ipairs(this.titList)do
            local TitleConfigData = ConfigManager.GetConfigData("TitleConfig", v.tid)
            if TitleConfigData then
                if TitleConfigData.Time ~= 0 then
                   local endtime = v.insertDateTime/1000 + TitleConfigData.Time - PlayerManager.serverTime
                    if endtime <= 0 then
                       break
                   end
                end
                for j = 1, #TitleConfigData.Attr do
                    if addAllProVal[TitleConfigData.Attr[j][1]] then
                        addAllProVal[TitleConfigData.Attr[j][1]] = addAllProVal[TitleConfigData.Attr[j][1]] + TitleConfigData.Attr[j][2]
                    else
                        addAllProVal[TitleConfigData.Attr[j][1]] = TitleConfigData.Attr[j][2]
                    end
                end
            end
        end
    end

    -- if PlayerManager.designation and PlayerManager.designation > 0 then
    --     local TitleConfigData=ConfigManager .GetConfigData("TitleConfig",PlayerManager.designation)
    --     if TitleConfigData then
    --         for j = 1, #TitleConfigData.Attr do
    --             if addAllProVal[TitleConfigData.Attr[j][1]] then
    --                 addAllProVal[TitleConfigData.Attr[j][1]] = addAllProVal[TitleConfigData.Attr[j][1]] + TitleConfigData.Attr[j][2]
    --             else
    --                 addAllProVal[TitleConfigData.Attr[j][1]] = TitleConfigData.Attr[j][2]
    --             end
    --         end
    --     end
    -- end
    -- --皮肤
    -- if PlayerManager.skin and PlayerManager.skin > 0 then
    --     local playerAppearance = ConfigManager.GetConfigData(ConfigName.PlayerAppearance,PlayerManager.skin)
    --     if playerAppearance then
    --         for j = 1, #playerAppearance.Property do
    --             if addAllProVal[playerAppearance.Property[j][1]] then
    --                 addAllProVal[playerAppearance.Property[j][1]] = addAllProVal[playerAppearance.Property[j][1]] + playerAppearance.Property[j][2]
    --             else
    --                 addAllProVal[playerAppearance.Property[j][1]] = playerAppearance.Property[j][2]
    --             end
    --         end
    --     end
    -- end
    -- --坐骑
    -- if PlayerManager.ride and PlayerManager.ride > 0 then
    --     local playerMountLevelUpConFig = ConfigManager.GetConfigData(ConfigName.PlayerMountLevelUp,PlayerManager.rideLevel)
    --     if playerMountLevelUpConFig then
    --         for j = 1, #playerMountLevelUpConFig.Property do
    --             if addAllProVal[playerMountLevelUpConFig.Property[j][1]] then
    --                 addAllProVal[playerMountLevelUpConFig.Property[j][1]] = addAllProVal[playerMountLevelUpConFig.Property[j][1]] + playerMountLevelUpConFig.Property[j][2]
    --             else
    --                 addAllProVal[playerMountLevelUpConFig.Property[j][1]] = playerMountLevelUpConFig.Property[j][2]
    --             end
    --         end
    --     end
    -- end
    return addAllProVal
end

function this.GetHeroDataByStar(star,staticid)
    if PlayerManager.heroHandBook and PlayerManager.heroHandBook[staticid] and PlayerManager.heroHandBook[staticid].maxStar >= star then 
        return true
    end
    return false
end

local battleUpLvTipTime = Timer.New()
local curMianPanleLoginShowTipNum = 0
local curLevelPanleLoginShowTipNum = 0
local noShowBattleUpLvTipMaxLv = 100
function this.StarBattleUpLvTipTime(type)
    local curSecound = 0
    if PlayerManager.level >= noShowBattleUpLvTipMaxLv then
        return
    end
    if not FightPointPassManager.IsShowFightRP() then
        return
    end
    if GuideManager.IsInMainGuide() then
        return
    end
    if battleUpLvTipTime then
        battleUpLvTipTime:Stop()
        battleUpLvTipTime = nil
    end
    if type == 1 and curMianPanleLoginShowTipNum < 3 then--主界面
            battleUpLvTipTime = Timer.New(function()
                curSecound = curSecound + 1
                if curSecound >= 10 then
                    if battleUpLvTipTime then
                        battleUpLvTipTime:Stop()
                        battleUpLvTipTime = nil
                    end
                    Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnShowBattleUpLvTip)
                    curMianPanleLoginShowTipNum = curMianPanleLoginShowTipNum + 1
                end
            end, 1, -1, true)
            battleUpLvTipTime:Start()
    elseif type == 2 and curLevelPanleLoginShowTipNum < 3 then--关卡界面
        battleUpLvTipTime = Timer.New(function()
            curSecound = curSecound + 1
            if curSecound >= 10 then
                if battleUpLvTipTime then
                    battleUpLvTipTime:Stop()
                    battleUpLvTipTime = nil
                end
                Game.GlobalEvent:DispatchEvent(GameEvent.Player.OnShowBattleUpLvTip)
                curLevelPanleLoginShowTipNum = curLevelPanleLoginShowTipNum + 1
            end
        end, 1, -1, true)
        battleUpLvTipTime:Start()
    end
end
function this.StopBattleUpLvTipTime()
    if battleUpLvTipTime then
        battleUpLvTipTime:Stop()
        battleUpLvTipTime = nil
    end
end

--阵容推荐已领取情况
function this.RefreshreceivedList(func)
    NetManager.HeroCollectRewardInfo(function (msg)
          this.receivedList = msg.infos
          if func then func() end
    end)
end

--阵容推荐红点
function this.LineupRecommendRedpoint()
    local state = false
    local list = ConfigManager.GetAllConfigsDataByKey(ConfigName.BeStronger, "Type", 5)
    for _, data in ipairs(list) do
        local haveNum = 0--拥有英雄数量
        for i, v in ipairs(data.ItemId) do
            local isHave = PlayerManager.heroHandBook and PlayerManager.heroHandBook[v]--是否拥有英雄
            if isHave then
                haveNum = haveNum + 1
            end
        end
        local receivedNum = 0--已领取数量
        for i = 1, #this.receivedList do
            if data.Id == this.receivedList[i].id then
                receivedNum = #this.receivedList[i].indexArray
            end
        end
        if haveNum > receivedNum then
            state = true
        end
    end
    return state
end
return this