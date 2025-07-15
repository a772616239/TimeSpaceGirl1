local this = {}
local challengeData = ConfigManager.GetConfig(ConfigName.ChallengeConfig)
local carBonMissionData = ConfigManager.GetConfig(ConfigName.ChallengeMissionConfig)
local eliteMissionView = require("Modules/Map/View/CarbonMissionTypeView")
local trialPanel = require("Modules/Map/TrialMapPanel")
local ctrlView = require("Modules/Map/View/MapControllView")
local pointHandleView = require("Modules/Map/View/PointHandleView")
-- 任务展开状态
local isExpand = false
local isMissionExpand = true
local MapPanel

local missionComp = {}
local exploreComp = {}
local starComp = {}

function this.InitComponent(gameObject, mapPanel)
    MapPanel = mapPanel

    this.DragCtrl = Util.GetGameObject(gameObject, "Ctrl")
    --this.btnSet = Util.GetGameObject(gameObject, "rightUp/btnSetting")

    -- 显示任务时间
    -- this.timeText = Util.GetGameObject(gameObject, "leftDown/timeRoot/Time"):GetComponent("Text")
    -- this.timeRoot = Util.GetGameObject(gameObject, "leftDown/timeRoot")
    -- 任务展开
    this.btnExpand = Util.GetGameObject(gameObject, "TargetRoot/btnExpand")
    this.imgUp = Util.GetGameObject(gameObject, "TargetRoot/btnExpand/imgUp")
    this.imgDown = Util.GetGameObject(gameObject, "TargetRoot/btnExpand/imgDown")
    --任务完成提示
    this.doneImg = Util.GetGameObject(gameObject, "TargetRoot/ImgDone")

    -- 副本任务组件
    for i = 1, 8 do
        missionComp[i] = Util.GetGameObject(gameObject, "TargetRoot/textShowRoot/missionRoot/MisPre" .. i)
    end

    -- 探索度组件
    for i = 1, 12 do
        exploreComp[i] = Util.GetGameObject(gameObject, "TargetRoot/textShowRoot/exploreRoot/expPre" .. i)
    end

    --地图探索度
    this.progressGo = Util.GetGameObject(gameObject, "leftUp/progressInfo")
    this.progressText = Util.GetGameObject(gameObject, "leftUp/progressInfo/progressText"):GetComponent("Text")
    this.progressBtn = Util.GetGameObject(gameObject, "leftUp/progressInfo/progressBtn")
    this.progressSlider = Util.GetGameObject(gameObject, "leftUp/progressInfo/progressSlider"):GetComponent("Slider")

    this.exploreRoot = Util.GetGameObject(gameObject, "TargetRoot/textShowRoot/exploreRoot")
    this.missionGrid = Util.GetGameObject(gameObject, "TargetRoot/textShowRoot")
    this.targetRoot = Util.GetGameObject(gameObject, "TargetRoot")

    -- 探索度进度
    this.explorePro = Util.GetGameObject(this.exploreRoot, "bg/Name"):GetComponent("Text")
    -- 设置三星条件
    this.conditionRoot = Util.GetGameObject(this.targetRoot, "textShowRoot/Condition")
    this.judgeText = Util.GetGameObject(this.conditionRoot, "judge2/context"):GetComponent("Text")
    for i = 1, 3 do
        starComp[i] = Util.GetGameObject(this.conditionRoot, "judge" .. i .. "/star")
    end

    eliteMissionView:InitComponent(gameObject)

end

function this.BindEvent()
    -- 展开任务
    Util.AddClick(this.btnExpand, function ()
        isExpand = not isExpand
        this.imgUp:SetActive(not isExpand)
        this.imgDown:SetActive(isExpand)

        this.RefreshMainMission(MissionManager.carBonMission, true)

        if challengeData[MapManager.curMapId].IsExplore == 1 then
            -- 刷新探索度显示
            this.RefreshExploreShow()
        end
    end)
    eliteMissionView:BindEvent()
end

function this.AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Mission.OnMissionAdd, this.OnMissionAdd)
    Game.GlobalEvent:AddEvent(GameEvent.Mission.OnMissionChange, this.OnMissionChange)
    Game.GlobalEvent:AddEvent(GameEvent.Mission.OnMissionEnd, this.OnMissionEnd)
    Game.GlobalEvent:AddEvent(GameEvent.Mission.OnTimeChange, this.OnMissionTimeChange)
    Game.GlobalEvent:AddEvent(GameEvent.Map.ProgressDataChange, this.MapProgressDataChange)
    Game.GlobalEvent:AddEvent(GameEvent.Map.OnForceGetOutMap, this.TimeToGetOut)
end

function this.RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Mission.OnMissionAdd, this.OnMissionAdd)
    Game.GlobalEvent:RemoveEvent(GameEvent.Mission.OnMissionChange, this.OnMissionChange)
    Game.GlobalEvent:RemoveEvent(GameEvent.Mission.OnMissionEnd, this.OnMissionEnd)
    Game.GlobalEvent:RemoveEvent(GameEvent.Mission.OnTimeChange, this.OnMissionTimeChange)
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.ProgressDataChange, this.MapProgressDataChange)
    Game.GlobalEvent:RemoveEvent(GameEvent.Map.OnForceGetOutMap, this.TimeToGetOut)
end

function this.Init()
    isExpand = false
    this.doneImg:SetActive(CarbonManager.difficulty ~= 2)
    this.SetExploreByType()
    -- 根据副本的类型显示是否显示任务组件
    this.SetTargetShow()
    this.DragCtrl:SetActive(true)
    if CarbonManager.difficulty == 1 or CarbonManager.difficulty == 3 then
        eliteMissionView:InitShow(CarbonManager.difficulty)
        this.InitMissionState()
    end
end

-- 初始化任务组件显示
function this.SetTargetShow()
    -- this.targetRoot:SetActive(CarbonManager.difficulty ~= 4)
    -- this.timeRoot:SetActive(false)
end

-- 设置副本任务时间
function this.OnMissionTimeChange(time)
    -- 无尽副本不显示时间
    if CarbonManager.difficulty ~= 4 then
        -- trialPanel.OnMissionTimeChange(time)
        if CarbonManager.difficulty ~= 2 then
            this.NormalShowTime(time)
        end
        -- this.timeRoot:SetActive(true)
    end
end

--========================== 普通精英副本处理方法==================================================
-- 试炼副本没有任务以及探索度
function this.InitMissionState()
    isExpand = false
    local isOpen = MapManager.isOpen
    -- 副本任务初始化
    if isOpen == false then
        this.DragCtrl:SetActive(false)
        -- this.timeText.text = ""
        -- 初始化任务显示
        this.InitComp()

        this.InitCarbonData()
        this.InitMissionTextPos()

    else
        this.DragCtrl:SetActive(true)
        local mission = MissionManager.carBonMission
        if mission then
            this.RefreshMainMission(mission, true)
        end
    end

    if MissionManager.carBonMission and CarbonManager.IsMissionDone() then
        this.OnMissionTimeChange(MissionManager.carBonMission.doneTime)
    end

    this.SetCondition()


end

-- 根据副本类型设置探索度
function this.SetExploreByType()
    if challengeData[MapManager.curMapId].IsExplore == 1 then
        --显示地图探索度
        this.InitExploreData()
        this.RefreshExploreShow()
        this.exploreRoot:SetActive(true)
        this.conditionRoot:SetActive(true)

    else
        this.exploreRoot:SetActive(false)
        this.conditionRoot:SetActive(false)
    end

    local isShowMission = CarbonManager.difficulty ~= 2
    this.btnExpand:SetActive(isShowMission)
end

function this.InitComp()
    if missionComp[1] then
        local context = Util.GetGameObject(missionComp[1], "context"):GetComponent("Text")
        local doneImg = Util.GetGameObject(missionComp[1], "imgDone")
        local doingImg = Util.GetGameObject(missionComp[1], "imgDoing")
        doneImg:SetActive(false)
        doingImg:SetActive(false)
        Util.GetGameObject(missionComp[1], "imgDoing"):SetActive(false)
        context.text = GetLanguageStrById(11307)
    end
end

-- 设置评星条件
function this.SetCondition()
    local limitDeads = challengeData[MapManager.curMapId].Deaths
    this.judgeText.text = GetLanguageStrById(11308) ..limitDeads.. GetLanguageStrById(10054)
end


-- 刚进图或者探索度100%时刷新显示
function this.RefreshCondition()
    local exploreDone = CarbonManager.ExplorationDone()
    if exploreDone then
        Util.SetGray(starComp[3], not exploreDone)
    else
        Util.SetGray(starComp[3], true)
    end
end

-- 副本任务弹窗
function this.InitCarbonData()
    local mission = MissionManager.carBonMission
    --设置完成图片
    local isDone = CarbonManager.IsMissionDone()
    this.doneImg:SetActive(isDone)

    -- 设置副本流程
    this.SetCarbonShowType(mission)

    if MapManager.curMapId == 100 then --序章特殊处理，默认不能跳过战斗
        CarbonManager.isPassFight = false
        --this.btnSet:SetActive(false)
        -- this.timeText.gameObject:SetActive(false)
    else
        CarbonManager.isPassFight = true
        -- this.timeText.gameObject:SetActive(true)
    end
end

local typeName = {
    [1] = GetLanguageStrById(11309),
    [3] = GetLanguageStrById(11310),
    [2] = GetLanguageStrById(11259),
}

function this.SetCarbonShowType(mission)

    if mission and mission.step == 0 then
        this.DragCtrl:SetActive(true)
        if MapManager.curMapId == 100 then
            -- 直接开始
            NetManager.CarbonMissionStartRequest(function(msg)
                local mission = MissionManager.carBonMission
                UIManager.OpenPanel(UIName.CurlingTipPanel, GetLanguageStrById(11312))

                if msg.leftTime > 0 then --开启任务
                    -- 刷新任务
                    Game.GlobalEvent:DispatchEvent(GameEvent.Mission.OnMissionAdd, mission)
                    started = true
                else
                    MapManager.isOpen = false
                end
            end)
        else
            UIManager.OpenPanel(UIName.CarbonMissionPopup, this)
        end

    end
end


function this.InitMissionTextPos()
    for i = 2, 8 do
        missionComp[i]:SetActive(false)
    end
end

-- 初始化探索度显示, 只显示一个
function this.InitExploreData()
    local doneImg = Util.GetGameObject(exploreComp[1], "imgDone")
    local doingImg = Util.GetGameObject(exploreComp[1], "imgDoing")
    local context = Util.GetGameObject(exploreComp[1], "context"):GetComponent("Text")
    context.text = ""
    if MapManager.curMapId > 10 then
        local data = MapManager.ExploreDataShow()
        this.ExCompState(1)
        doneImg:SetActive(data.info[1].isDone)
        doingImg:SetActive(not data.info[1].isDone)
        local str = string.format("%s%s  %s", data.info[1].progress, data.info[1].context, data.info[1].weight)
        context.text = str
        this.SetExCompPos(data.info[1].context, doneImg, doingImg)
        -- 设置总进度
        this.explorePro.text = GetLanguageStrById(11314) .. data.progress .. "%)"
    end
end

-- 探索组度组件展开收起状态, num是需要展开的个数
function this.ExCompState(num)
    for i = 1, 12 do
        local state = i <= num
        exploreComp[i]:SetActive(state)
    end
end

-- 设置任务组件数
function this.SetCompNum(stepNum)
    for i = 1, 8 do
        missionComp[i]:SetActive(i <= stepNum)
    end
end

-- 刷新探索度数据
function this.RefreshExploreShow()
    if CarbonManager.difficulty == 4 then return end
    if MapManager.curMapId > 1 then
        local exploreData = MapManager.ExploreDataShow()
        local dataNum = isExpand and #exploreData.info or 1
        --  设置组件状态
        this.ExCompState(dataNum)
        if dataNum == 1 then
            this.InitExploreData()
        else
            for i = 1, dataNum do
                local doneImg = Util.GetGameObject(exploreComp[i], "imgDone")
                local doingImg = Util.GetGameObject(exploreComp[i], "imgDoing")
                local context = Util.GetGameObject(exploreComp[i], "context"):GetComponent("Text")
                doneImg:SetActive(exploreData.info[i].isDone)
                doingImg:SetActive(not exploreData.info[i].isDone)
                context.text = string.format("%s%s  %s", exploreData.info[i].progress, exploreData.info[i].context, exploreData.info[i].weight)
                this.SetExCompPos(exploreData.info[i].context, doneImg, doingImg)
            end
        end

        -- 设置总探索度
        this.explorePro.text = GetLanguageStrById(11314) .. exploreData.progress .. "%)"

        this.RefreshCondition()

    end
end

-- 刷新副本任务显示
function this.RefreshMainMission(mission, isInit)
    if CarbonManager.difficulty == 4 or CarbonManager.difficulty == 2 then return end
    local missionDone = CarbonManager.IsMissionDone()
    --任务开启
    if MapManager.isOpen then
        if mission and mission.id ~= 0 then
            local missionInfo = MissionManager.GetMissionState()
            local stepNum = isExpand and #missionInfo or 1

            this.SetCompNum(stepNum)

            local missionInfo
            if stepNum == 1 then
                missionInfo = MissionManager.CurStepInfo()
            else
                missionInfo = MissionManager.GetMissionState()
            end
            for i = 1, stepNum do
                local item = missionComp[i]

                local doingIcon = Util.GetGameObject(item, "imgDoing")
                local doneIcon = Util.GetGameObject(item, "imgDone")
                local missionContext = Util.GetGameObject(item, "context"):GetComponent("Text")
                local isDone = false
                local missionStr = ""
                if stepNum == 1 then
                    isDone = missionInfo.isDone
                    missionStr = missionInfo.missionStr
                else
                    isDone = missionInfo[i].isDone
                    missionStr = missionInfo[i].missionStr
                end

                doneIcon:SetActive(isDone)
                doingIcon:SetActive(not isDone)
                missionContext.text = missionStr

                this.SetMissionCompPos(missionStr, doingIcon, doneIcon)

                -- 任务完成并且是收起的
                if stepNum  == 1 and missionDone then
                    doneIcon:SetActive(false)
                    doingIcon:SetActive(false)
                    missionContext.text = GetLanguageStrById(11315)
                    this.doneImg:SetActive(missionDone)
                else
                    this.doneImg:SetActive(false)
                end

                -- 显示任务提示文字, 进图初始化不显示
                if not isInit then
                    MissionManager.ShowDoneMissionStep()
                end
            end
        end
        pointHandleView.SetDirShinning(mission)

        -- 刷新第一个条件状态
        Util.SetGray(starComp[1], not missionDone)

        local isLimitDead = CarbonManager.LessThanDeadTimes(MapManager.curMapId)
        Util.SetGray(starComp[2], not isLimitDead)

        eliteMissionView:RefreshMission(missionDone)
    else

    end
end

function this.OnMissionAdd(mission)
    if not MapManager.isOpen then
        MapPanel.SetRoleShow(MapManager.mapScale, MapManager.roleInitPos)
        PlayerManager.startTime = PlayerManager.serverTime
        MissionManager.missionTime = 0
        MapManager.isOpen = true
        PlayerManager.isStart = true
    end
    this.RefreshMainMission(mission, false)
end

-- 任务显示规则，主线显示当前进度，支线显示所有支线当前任务
function this.OnMissionChange(mission)
    this.RefreshMainMission(mission, false)
end

-- 任务结束时做相应的行为表现
function this.OnMissionEnd(mission)
end


-- 精英普通副本的显示方法
function this.NormalShowTime(time)
    -- 如果任务完成，显示完成任务的时间
    if challengeData[MapManager.curMapId] then
        local data = challengeData[MapManager.curMapId]
        time = time >= data.MapTime and data.MapTime or time
        local newTime
        if CarbonManager.IsMissionDone() then
            newTime = MissionManager.carBonMission.doneTime
            PlayerManager.isStart = false
        else
            newTime = time
        end

        -- this.timeText.text = this.FormatTime(newTime)

        local isTimeToFuckOut = false
        if time >= data.MapTime then
            isTimeToFuckOut = true
        else
            isTimeToFuckOut = false
        end
        MapManager.isTimeOut = isTimeToFuckOut
        if isTimeToFuckOut then
            MapManager.isOpen = false
            PlayerManager.isStart = false
            if UIManager.IsOpen(UIName.MapOptionPanel) then
                UIManager.ClosePanel(UIName.MapOptionPanel)
                -- 普通副本，出图时间到，停止行走
                if CarbonManager.difficulty == 1 then
                    if MapManager.isTimeOut then
                        ctrlView.OnRoleDead()
                    end
                end

            end
            if not UIManager.IsOpen(UIName.MapStatsPanel) then
                UIManager.OpenPanel(UIName.MapStatsPanel)
            end
        end
    end
end

function this.TimeToGetOut()
    local isTimeToFuckOut = true
    MapManager.isTimeOut = isTimeToFuckOut
    if isTimeToFuckOut then
        MapManager.isOpen = false
        PlayerManager.isStart = false
        if UIManager.IsOpen(UIName.MapOptionPanel) then
            UIManager.ClosePanel(UIName.MapOptionPanel)
            -- 普通副本，出图时间到，停止行走
            if CarbonManager.difficulty == 1 then
                if MapManager.isTimeOut then
                    ctrlView.OnRoleDead()
                end
            end

        end

        -- if not UIManager.IsOpen(UIName.MapStatsPanel) then
        --     UIManager.OpenPanel(UIName.MapStatsPanel)
        -- end
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out,0)
    end
end

-- 转换时间
function this.FormatTime(time)
    local str = ""
    local ten_minute = math.modf(time / 600)
    local minute = math.modf(time / 60) % 10
    local ten_second =  math.modf( time / 10) % 6
    local second = time % 10
    str = ten_minute  ..minute .. ":" .. ten_second .. second
    return str
end


--地图探索度
function this.MapProgressDataChange()
    if CarbonManager.difficulty == 1 then
        this.RefreshExploreShow()
    elseif CarbonManager.difficulty == 3 or CarbonManager.difficulty == 2 then

    end
end

-- 设置图片位置
function this.SetExCompPos(str, doneImg, doingImg)
    local strLength = #str
    local y = 25
    local orgPos = doingImg.transform.localPosition
    if strLength > 21 then
        y = 40
    end
    doingImg.transform.localPosition = Vector3.New(orgPos.x, y, orgPos.z)
    doneImg.transform.localPosition = Vector3.New(orgPos.x, y, orgPos.z)
end
function this.SetMissionCompPos(str, doneImg, doingImg)
    local strLength = #str
    local y = 25
    local orgPos = doingImg.transform.localPosition
    if strLength > 33 then
        y = 40
    end
    doingImg.transform.localPosition = Vector3.New(orgPos.x, y, orgPos.z)
    doneImg.transform.localPosition = Vector3.New(orgPos.x, y, orgPos.z)
end

return this