--任务系统，包括事件系统的通用处理
require("Modules/Map/TrialMiniGame/TrialMiniGameManager")
MissionManager = {}
local this = MissionManager
local EventPointConfig = ConfigManager.GetConfig(ConfigName.EventPointConfig)
local carBonMissionData = ConfigManager.GetConfig(ConfigName.ChallengeMissionConfig)
local MapPointConfig = ConfigManager.GetConfig(ConfigName.MapPointConfig)
local FoodsConfig = ConfigManager.GetConfig(ConfigName.FoodsConfig)
-- 精英怪panel
local monsterPanel = require("Modules/EliteMonster/MonsterShowPanel")
this.MissionState = {} -- 已经开启的任务
this.MainMission = {}  --正在进行的主线任务
this.CanGoNext = false

-- 副本任务
this.carBonMission = {}
-- 副本任务已经计时的时间
this.missionTime = 0
--
this.curStepInfo = {}

function this.Initialize()
    TrialMiniGameManager.Init()
end
function this.InitMissionInfo(msg)
    this.ParseMissionState(msg.missions, true)
end

-- 任务处理系统 --
--解析并更新任务数据，state字段以字符串格式传入，以id为类型分别判定解析，以便适应不同的state格式
function this.ParseMissionState(missions, isInit)
    if not missions then
        return 
    end 
    this.missionShow = {}
    if missions.itemId == 0 then

    end
    local missionItem = missions
    local id = missionItem.itemId -- 任务索引值
    local curMission = {}
    curMission.step = missionItem.missionStep
    curMission.id = id
    curMission.state = missionItem.state
    curMission.doneTime = missionItem.time > 0 and missionItem.time or 0

    if missionItem.deadTimes then
        CarbonManager.RoleDeadTimes = missionItem.deadTimes
    end
    -- 副本任务
    this.carBonMission = curMission

    local refreshType = 0 -- 0 不抛刷新事件 1抛新增任务事件 2抛任务状态刷新事件
    if not isInit then
        if not this.MissionState[id] then
            refreshType = 1
        else
            refreshType = 2
        end
    end

    if id == 1 then

    elseif id == 2 then --格式 pos#pointId|pos#pointId|...
        local state = {}
        local ss = string.split(missionItem.state, "|")
        for i = 1, #ss do
            local ss2 = string.split(ss[i], "#")
            table.insert(state, {
                pos = tonumber(ss2[1]),
                pointId = tonumber(ss2[2]),
            })
        end

        curMission.state = state
        if refreshType == 1 then
            for i = 1, #state do
                Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointAdd, state[i].pos, state[i].pointId)
            end
        end
    end

    if refreshType == 1 then
        Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnMissionAdd, curMission)
    elseif refreshType == 2 then
        Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnMissionChange, curMission)
    end

    if this.MissionState[id] then
        this.MissionState[id].step = curMission.step
    else
        this.MissionState[id] = curMission
    end
end

--手动往下推一步任务
function this.SetMissionGoNext()
    local mission = {}
    mission.itemId = this.carBonMission.id
    mission.state = this.carBonMission.state
    mission.missionStep = this.carBonMission.step + 1
    mission.time = -1

    this.ParseMissionState(mission, false)
end

-- 判断副本任务是否完成
function this.MainMissionIsDone(missionId)
    if CarbonManager.difficulty == CARBON_TYPE.ENDLESS or CarbonManager.difficulty ==CARBON_TYPE.TRIAL then
        return false
    end
    if missionId then
        local isDone = false
        local contents = string.split(carBonMissionData[missionId].Content, "#")

        local str = contents[this.carBonMission.step + 1]
        if str ~= "" and str ~= nil then
            isDone = false
        else
            isDone = true
        end
        return isDone
    end
end

-- 副本任务所有步骤状态，显示使用
function this.GetMissionState()
    local missionInfo = {}
    local curStep = this.carBonMission.step + 1
    local missionId = this.carBonMission.id

    local childStart = 0
    local childEnd = 0

    local childStep = carBonMissionData[missionId].ChildMission
    local MissionConText = string.split(carBonMissionData[missionId].Content, "#")


    for i = 1, #MissionConText do
        local context = MissionConText[i]
        if childStep[i] then
            childStart = childStep[i][1]
            childEnd = childStep[i][2]
        end
        local diff = childEnd - childStart + 1

        if i > childStart and i <= childEnd then

        else
            -- 需要替换的文字内容
            local step = curStep - childStart <= 0 and 0 or curStep - childStart
            step = step >= diff and diff or step

            local missionStr = string.format(context, step)
            --当前的任务步骤不在子任务范围内
            local b = false
            if i < childStart or i > childEnd then
                b = i < curStep
            else -- 重新定义任务完成判断
                b = curStep > childEnd
            end

            local t = {}
            t.missionStr = missionStr
            t.isDone = b

            missionInfo[#missionInfo + 1] = t
        end
    end

    -- 已经完成步骤
    local doneStep = {}
    -- 未完成步骤
    local doingStep = {}
    for i = 1, #missionInfo do
        if missionInfo[i].isDone then
            doneStep[#doneStep + 1] = missionInfo[i]
        else
            doingStep[#doingStep + 1] = missionInfo[i]
        end
    end

    local info = {}
    if #doingStep > 0 then
        for i = 1, #doingStep do
            table.insert(info, doingStep[i])
        end
    end

    if  #doneStep > 0 then
        for i = 1, #doneStep do
            table.insert(info, doneStep[i])
        end
    end

    return info
end

function this.CurStepInfo()
    local curMission = {}
    local mission = this.carBonMission
    local contents = string.split(carBonMissionData[mission.id].Content, "#")
    local str = contents[mission.step + 1]
    local childStart = 0
    local childEnd = 0
    local curStep = mission.step + 1
    local childStep = carBonMissionData[mission.id].ChildMission
    if childStep[curStep] then
        childStart = childStep[curStep][1]
        childEnd = childStep[curStep][2]
    end

    local diff = childEnd - childStart + 1
    local step = curStep - childStart <= 0 and 0 or curStep - childStart
    step = step >= diff and diff or step

    if str ~= "" and str then -- 任务尚未完成
        local missionStr = string.format(str, step)
        curMission.missionStr = missionStr
        curMission.isDone = false
    else -- 任务已经完成
        curMission.missionStr = GetLanguageStrById(11315)
        curMission.isDone = true
    end
    return curMission
end

-- 任务提示文字
function this.ShowDoneMissionStep()
    local str = ""
    local contents = string.split(carBonMissionData[this.carBonMission.id].Content, "#")
    local missionStr = contents[this.carBonMission.step]
    if not missionStr or missionStr == "" then return end
    local lastStep = this.carBonMission.step
    local childStart = 0
    local childEnd = 0
    local childStep = carBonMissionData[this.carBonMission.id].ChildMission
    if childStep[lastStep] then
        childStart = childStep[lastStep][1]
        childEnd = childStep[lastStep][2]
    end


    -- 在子任务之外直接弹
    if lastStep > childEnd or lastStep < childStart then
        str = missionStr
        UIManager.OpenPanel(UIName.CurlingTipPanel, str)
    else
        if lastStep == childEnd then
            str = string.format(missionStr, childEnd - childStart + 1)
            UIManager.OpenPanel(UIName.CurlingTipPanel, str)
        end
    end
end

--触发EventPointConfig表事件
-- 事件处理系统--
-- 通过事件id触发类型， showType选择显示面板，面板的具体内容由 options决定
local showString = {
    [1] = GetLanguageStrById(11370),
    [2] = GetLanguageStrById(11371),
    [3] = GetLanguageStrById(11372),
    [4] = GetLanguageStrById(11373),
    [6] = GetLanguageStrById(11374),
}

-- 不做处理
local noHandle = function(showType, eventId, showValues, options)
    Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
end

-- 前往下一层界面
local mapDialoguePanel = function(showType, eventId, showValues, options)
    --现已做成三级弹窗
    if MapManager.curCarbonType == CarBonTypeId.ENDLESS then
        if not UIManager.IsOpen(UIName.MapOptionPanel) then
            UIManager.OpenPanel(UIName.MapOptionPanel,showType, eventId, showValues, options)
        end
    else
        if not UIManager.IsOpen(UIName.GeneralPopup) then
            UIManager.OpenPanel(UIName.GeneralPopup,GENERAL_POPUP_TYPE.TrialToNextFloor, showType, eventId, showValues, options)
        end
    end

end

-- 进度条界面
local processPanel = function(showType, eventId, showValues, options)
    if not UIManager.IsOpen(UIName.ProgressPanel) then
        UIManager.OpenPanel(UIName.ProgressPanel, showValues)
    end
end

-- 直接战斗
local directFight = function(showType, eventId, showValues, options)
    local monsterGroupId = options[1]
    --遇到怪就停在原处
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.StopWalk)
    --获取自动战斗
    local t = (PlayerPrefs.HasKey(PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..1)
        and PlayerPrefs.GetInt(PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..1) == 1) and 1 or 0
    if t == 0 then --非快速战斗，打开二级弹窗
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.ShowEnemyInfo, monsterGroupId,eventId,showValues)
    else--快速战斗
        -- --如果英雄阵亡 无法选择其进行战斗
        --先保存编队
        if MapManager.curCarbonType == CarBonTypeId.ENDLESS then--无尽副本
            -- body

            -- local curFormation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_ENDLESS_MAP)
            local curFormation = MapManager.formationList

            -- FormationManager.RefreshFormation(FormationTypeDef.FORMATION_ENDLESS_MAP,curFormation,
            -- FormationManager.formationList[FormationTypeDef.FORMATION_ENDLESS_MAP].teamPokemonInfos)

            NetManager.QuickFightRequest(function(msg)
                CarbonManager.InitQuickFightData(monsterGroupId, eventId, msg)
                -- MapTrialManager.SetHeroHp(msg.remainHpList,MapTrialManager.selectHeroDid)
            end)
        else
            local curFormation = FormationManager.GetFormationByID(FormationTypeDef.FORMATION_DREAMLAND)
            local choosedList = {}
            table.insert(choosedList, {heroId = MapTrialManager.selectHeroDid, position = 2})
            FormationManager.RefreshFormation(FormationTypeDef.FORMATION_DREAMLAND,choosedList,"",
                FormationManager.formationList[FormationTypeDef.FORMATION_DREAMLAND].teamPokemonInfos)
    
            NetManager.QuickFightRequest(function(msg)
                --更新英雄HP
                --战斗赢了 击杀小怪数量+1（包括BOSS吗）
                if msg.result == 1 then
                    MapTrialManager.SetKillCount(MapTrialManager.GetKilCount()+1)
                end
                MapTrialManager.SetHeroHp(msg.remainHpList,MapTrialManager.selectHeroDid)
                CarbonManager.InitQuickFightData(monsterGroupId, eventId, msg)
                --更新精气值
                MapTrialManager.powerValue = msg.essenceValue
                -- --召唤Boss
                if CarbonManager.difficulty == CARBON_TYPE.TRIAL and MapTrialManager.powerValue >= 100 then
                    MapTrialManager.isHaveBoss = true
                    MapTrialManager.UpdatePowerValue(0)
                end
            end)
        end

    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Map.RefreshHeroHp,false,nil,false)
end

-- 起名字界面
local createNamePanel = function(showType, eventId, showValues, options)
    UIManager.OpenPanel(UIName.CreateNamePopup, showType, eventId, showValues, options)
end

-- 云游商店
local walkingShop = function(showType, eventId, showValues, options)
    -- 重新获取商店数据
    ShopManager.RequestAllShopData(function()
        local curTimeStamp = GetTimeStamp()
        local shopData = ShopManager.GetShopDataByType(SHOP_TYPE.ROAM_SHOP)
        UIManager.OpenPanel(UIName.MapShopPanel, SHOP_TYPE.ROAM_SHOP)
    end)
end

-- 精英怪
local elitePanel = function(showType, eventId, showValues, options)
    -- 如果未拥有精英怪则触发
    local isShowWarning = false
    if not EliteMonsterManager.HasEliteMonster() then
        -- 触发精英怪
        local monsterGroupId = options[1]
        local GameSetting = ConfigManager.GetConfig(ConfigName.GameSetting)
        local endTime = GetTimeStamp() + GameSetting[1].IncidentalBossSave
        -- 保存精英怪数据
        EliteMonsterManager.SetEliteData(monsterGroupId, endTime)
        isShowWarning = true
    end
    -- 打开精英怪界面
    UIManager.OpenPanel(UIName.EliteMonsterPanel, 2, isShowWarning)
end

-- 试炼商店
local trailMapShop = function(showType, eventId, showValues, options)
    -- 重新获取商店数据
    ShopManager.RequestAllShopData(function()
        UIManager.OpenPanel(UIName.MapShopPanel, SHOP_TYPE.TRIAL_SHOP, eventId, options)
    end)
end

-- 试炼Boss界面
local trialBossPanel = function(showType, eventId, showValues, options)
    -- 显示类型16的ShowValue字段都是怪物组Id
    local fightFunc = function()
        OptionBehaviourManager.JumpEventPoint(eventId, options[1], monsterPanel)
    end

    local closeFunc = function()
        OptionBehaviourManager.JumpEventPoint(eventId, options[2], monsterPanel)
    end

    UIManager.OpenPanel(UIName.MonsterShowPanel, tonumber(showValues[1]), fightFunc, closeFunc, true, 2)
end

-- 试炼Buff界面
local trailBuffPanel = function(showType, eventId, showValues, options)
    NetManager.EventUpdateRequest(eventId, options[1], function ()
        Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.ProgressChange, 1, options[1])
    end)
end

-- 无尽商店
local EndLessMapShop = function(showType, eventId, showValues, options)
    -- 重新获取商店数据
    ShopManager.RequestAllShopData(function()
        UIManager.OpenPanel(UIName.MapShopPanel, SHOP_TYPE.ENDLESS_SHOP, eventId, options)
    end)
end

-- 注册方法
local funcList = {
    [1] = noHandle,
    [2] = noHandle,
    [3] = mapDialoguePanel,
    [4] = mapDialoguePanel,
    [5] = processPanel,
    [6] = directFight,
    [7] = noHandle,
    [8] = noHandle,
    [9] = noHandle,
    [10] = createNamePanel,
    [13] = walkingShop,
    [14] = elitePanel,
    [15] = trailMapShop,
    [16] = trialBossPanel,
    [17] = trailBuffPanel,
    [18] = EndLessMapShop,
}

--事件点触发
function this.EventPointTrigger(eventId,pos)
    MyPCall(function ()
        if eventId == 0 or eventId < 0 then
            return
        end
        if not EventPointConfig[eventId].Id then

            return
        end
        local showType = EventPointConfig[eventId].ShowType
        local options = EventPointConfig[eventId].Option
        local showValues = string.split(EventPointConfig[eventId].ShowValues, "|")

        Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTrigger, showType, eventId, showValues, options,pos)
        if showType==3 or showType==4 then
            LogGreen("EventPointTrigger中得到的事件ID " .. eventId)
        end
        -- 根据不同的显示类型执行方法
        if funcList[showType] then funcList[showType](showType, eventId, showValues, options)
            Game.GlobalEvent:DispatchEvent(GameEvent.Guide.EventTriggered, eventId)
        end 
        if MapManager.BossId then
            for index, value in ipairs(MapManager.BossId) do
                if value == eventId then
                    if (MapManager.curCarbonType == CarBonTypeId.TRIAL and #MapManager.allOnClickEvent > 0 and MapManager.isAutoJian) or
                        (MapManager.curCarbonType == CarBonTypeId.TRIAL and #MapManager.buffOnClickEvent > 0 and MapManager.isAutoJian) then
                            Game.GlobalEvent:DispatchEvent(GameEvent.YiDuan.AutoGetBaoXiang)
                    end
                end
            end
        end
        
    end)
end

function this.GameDoneFunc()
    if TrialMiniGameManager.IsGameDone() then
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, MapManager.curTriggerPos)--删除宝箱点
    end
    Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
    -- Timer.New(function()
    --     -- 刷新数据
    --     Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
    -- end, 0.5):Start()
end

--注册事件
local funcList2 = {
    [7] = function(pos) --踩宝箱只发0
        NetManager.GetTrialBoxRewardRequest(0, function(msg)
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove, pos)--删除宝箱点
            local data = TrialMiniGameManager.IdToNameIconNum(msg.boxDrop.itemlist[1].itemId,msg.boxDrop.itemlist[1].itemNum)
            PopupTipPanel.ShowColorTip(data[1],data[2],data[3])
            Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
            Timer.New(function()
                -- 刷新数据
                Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointUiClear)
            end, 1):Start()
        end)
    end,
    [13] = function() -- 试炼副本答题游戏1
        TrialMiniGameManager.StartGame(13, this.GameDoneFunc)
    end,
    [14] = function() -- 试炼副本答题游戏2
        TrialMiniGameManager.StartGame(14, this.GameDoneFunc)
    end,
    [15] = function() -- 试炼副本答题游戏3
        TrialMiniGameManager.StartGame(15, this.GameDoneFunc)
    end,
    [16] = function() -- 试炼副本roll游戏1
        TrialMiniGameManager.StartGame(16, this.GameDoneFunc)
    end,
    [17] = function() -- 试炼副本roll游戏2
        TrialMiniGameManager.StartGame(17, this.GameDoneFunc)
    end,
    [18] = function() -- 试炼副本roll游戏3
        TrialMiniGameManager.StartGame(18, this.GameDoneFunc)
    end,
}
--地图点触发
function this.MapPointTrigger(style,pos)
    local i = 0
    for k, v in pairs(MapManager.mapPointList) do
        if MapPointConfig[v] and MapPointConfig[v].Style == style then
            i = style
        end
    end

    if funcList2[i] then
        funcList2[i](pos)
    end
end

--设置自动拾取道具 获取全部奖励
function this.GetAllRewardTrigger()
    --若存在该设置参数并为已勾选状态 =1 否则=0
    local var = PlayerManager.uid.."GeneralPopup_TrialSettingBtn"..3
    local t = (PlayerPrefs.HasKey(var)
        and PlayerPrefs.GetInt(var) == 1) and 1 or 0
    if t == 0 then return end
    NetManager.GetTrialBoxRewardRequest(t,function(msg)
        Timer.New(function ()
            for key, value in pairs(MapManager.mapPointList) do
                if value == 2000000 then
                    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove,key)--删除全部宝箱点
                end
                if MapPointConfig[value].Style == 9 then
                    Game.GlobalEvent:DispatchEvent(GameEvent.Map.PointRemove,key)--删除所有的buff点
                end
            end
            local thread = coroutine.start(function()
                --宝箱奖励掉落
                for i = 1, #msg.boxDrop.itemlist do
                    local data = TrialMiniGameManager.IdToNameIconNum(msg.boxDrop.itemlist[i].itemId,msg.boxDrop.itemlist[i].itemNum)
                    PopupTipPanel.ShowColorTip(data[1],data[2],data[3])
                    coroutine.wait(0.1)
                end
                --buff奖励掉落
                for i = 1, #msg.buffIds do
                    PopupTipPanel.ShowTip(GetLanguageStrById(FoodsConfig[msg.buffIds[i]].Desc))
                    coroutine.wait(0.1)
                end
            end)
            Game.GlobalEvent:DispatchEvent(GameEvent.Event.PointTriggerEnd)
        end , 3):Start()
    end)
end

return this