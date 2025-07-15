require("Base/BasePanel")
MapStatsPanel = Inherit(BasePanel)
local this = MapStatsPanel
local ItemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local challengeConfig = ConfigManager.GetConfig(ConfigName.ChallengeConfig)
this.selfsortingOrder = 0
--初始化组件（用于子类重写）
function MapStatsPanel:InitComponent()

    this.btnBack = Util.GetGameObject(self.gameObject, "Bg/btnBack")
    this.btnClosePanel = Util.GetGameObject(self.gameObject, "Mask")
    this.goOnTip = Util.GetGameObject(self.gameObject, "Image")

    -- 地图任务
    this.missionRoot = Util.GetGameObject(self.gameObject, "Bg/statsRoot/mission")
    -- 最高层数
    this.maxLevelRoot = Util.GetGameObject(self.gameObject, "Bg/statsRoot/maxLevel")
    -- 探索进度
    this.exploreRoot = Util.GetGameObject(self.gameObject, "Bg/statsRoot/progress")
    -- 功绩
    this.achiveRoot = Util.GetGameObject(self.gameObject, "Bg/statsRoot/AchiveStatic")
    -- 通关时间
    this.passTimeRoot = Util.GetGameObject(self.gameObject, "Bg/statsRoot/throughTime")
    -- 复活次数
    this.reviveRoot = Util.GetGameObject(self.gameObject, "Bg/statsRoot/reviveTime")
    -- 剩余复活次数
    this.leftLifeRoot = Util.GetGameObject(self.gameObject, "Bg/statsRoot/leftLife")
    -- 地图名字
    this.mapName = Util.GetGameObject(self.gameObject, "Bg/statsRoot/mapName")
    -- 战斗场次
    this.fightTimes = Util.GetGameObject(self.gameObject, "Bg/statsRoot/fightTimes")
    -- 行动力消耗
    this.energyCost = Util.GetGameObject(self.gameObject, "Bg/statsRoot/energyCost")

    -- 地图任务的小点点
    this.xiaodiandian = Util.GetGameObject(self.gameObject, "Bg/statsRoot/mission/Text ")

    -- 物品掉落信息
    this.itemPre = Util.GetGameObject(self.gameObject, "Bg/Image/ViewRect/ItemFrame")
    this.grid = Util.GetGameObject(self.gameObject, "Bg/Image/ViewRect/grid")

    this.panel = Util.GetGameObject(self.gameObject, "Bg")
    this.effect = Util.GetGameObject(self.gameObject, "effect")
end

--绑定事件（用于子类重写）
function MapStatsPanel:BindEvent()

    Util.AddClick(this.btnBack, function ()
        this.MapOutType(CarbonManager.difficulty)
    end)
    Util.AddClick(this.btnClosePanel, function ()
        self:ClosePanel()
    end)
    
end

-- 出图协议选择
function this.MapOutType(type)
    if type == 1 or type == 3 then
        -- 出图刷新一次地图任务信息
        local doneTime = MissionManager.carBonMission.doneTime

        CarbonManager.Refresh(doneTime)

        -- 先放特效
        this.panel:SetActive(false)
        this.effect:SetActive(true)
        local timer
        timer = Timer.New(function()
            Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out, 1, 0)
        end, 1.5):Start()
    elseif type == 2 then --试炼副本
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out, 1, 0)

    elseif type == 4 then
        Game.GlobalEvent:DispatchEvent(GameEvent.Map.Out, 1, 0)
    end
end

--添加事件监听（用于子类重写）
function MapStatsPanel:AddListener()

end

--移除事件监听（用于子类重写）
function MapStatsPanel:RemoveListener()

end

--界面打开时调用（用于子类重写）
function MapStatsPanel:OnOpen(isShowTip)

    this.selfsortingOrder = self.sortingOrder
    this.PanelShow()
    if isShowTip then 
        this.btnClosePanel:GetComponent("Button").enabled = true
        this.goOnTip:SetActive(true)
    else
        this.btnClosePanel:GetComponent("Button").enabled = false
        this.goOnTip:SetActive(false)
    end

end

function this.PanelShow()
    this.panel:SetActive(true)
    this.effect:SetActive(false)
    this.InitStatsInfo()
    this.InitItemInfo()
    this.SetShowCondition()
end

function this.SetShowCondition()
    local type = CarbonManager.difficulty
    this.missionRoot:SetActive(type ~= 2 and type ~= 4)
    this.maxLevelRoot:SetActive(type == 1)
    this.exploreRoot:SetActive(type == 1)
    this.achiveRoot:SetActive(type == 3)
    this.passTimeRoot:SetActive(type ~= 1 and type ~=4 and type~=2)
    this.reviveRoot:SetActive(type == 1)
    this.leftLifeRoot:SetActive(type == 1)
    this.xiaodiandian:SetActive(type == 3)
    this.mapName:SetActive(type == 4)
    this.fightTimes:SetActive(type == 4)
    this.energyCost:SetActive(type == 4)
end

-- 初始化统计信息
function this.InitStatsInfo()
    local achiveNum = 0
    local totalAchive = 0
    -- 精英副本功績
    if CarbonManager.difficulty == 3 then
        local mapId = challengeConfig[MapManager.curMapId].MapId
        achiveNum, totalAchive = TaskManager.GetAchiveNum(mapId)
    end


    if CarbonManager.difficulty ~= 2 and CarbonManager.difficulty ~= 4 then
        this.SetMissionState()
        this.SetExploreState()
        -- 复活次数
        local showTip
        if CarbonManager.IsMissionDone() then
            showTip = tostring(CarbonManager.RoleDeadTimes)
        else
            showTip = GetLanguageStrById(10366)
        end

        this.SetCondition(this.reviveRoot, CarbonManager.LessThanDeadTimes(MapManager.curMapId), showTip)
    end

    local levelNum
    -- if  MapTrialManager.IsFinalLevel() then
    --     levelNum = MapTrialManager.curTowerLevel
    -- else
        levelNum = MapTrialManager.curTowerLevel - 1
    -- end
    if levelNum <= 0 or MapTrialManager.doneTime == 0 then
        levelNum = GetLanguageStrById(10318)
    else
        levelNum = tostring(levelNum) .. GetLanguageStrById(10319)
    end

    this.SetCondition(this.maxLevelRoot, false, levelNum)
    this.SetCondition(this.achiveRoot, false, string.format(GetLanguageStrById(10367), achiveNum, totalAchive))
    if CarbonManager.difficulty == 3 then
        this.SetCondition(this.passTimeRoot, CarbonManager.DoneAtLimitTime(), this.ShowPassTime(MissionManager.carBonMission.doneTime))
    elseif CarbonManager.difficulty == 2 then
        local context = ""

        if MapTrialManager.IsFinalLevel() then

            if MapTrialManager.bossDeadTime == 0 then
                context = GetLanguageStrById(10366)
            else
                context = this.ShowPassTime(MapTrialManager.bossDeadTime)
            end
        elseif not MapTrialManager.doneTime or MapTrialManager.doneTime == 0 then
            context = GetLanguageStrById(10366)
        else
            context = this.ShowPassTime(MapTrialManager.doneTime)
        end
        this.SetCondition(this.passTimeRoot, false, context)
    end
    this.SetCondition(this.leftLifeRoot, false, MapTrialManager.leftLife)

    -- 无尽副本
    if CarbonManager.difficulty == CARBON_TYPE.ENDLESS then
        this.SetDoneInfoShow(this.mapName, EndLessMapManager.curMapName)
        this.SetDoneInfoShow(this.fightTimes, EndLessMapManager.mapFightTimes)
        this.SetDoneInfoShow(this.energyCost, EndLessMapManager.energyCost)
    end




end

-- 任务是否完成
function this.SetMissionState()
    -- 设置任务状态
    local isDone = MissionManager.MainMissionIsDone(MissionManager.carBonMission.id)
    local str = ""
    if isDone then
        str = string.format("<color=#538A6BFF>%s</color>",GetLanguageStrById(10370))
    else
        str = string.format("<color=#D55E64FF>%s</color>",GetLanguageStrById(10366))
    end

    local missionState = Util.GetGameObject(this.missionRoot, "state"):GetComponent("Text")
    local missionDone = Util.GetGameObject(this.missionRoot, "star_done")
    local missionDoing = Util.GetGameObject(this.missionRoot, "star_doing")
    missionState.text = str

    if CarbonManager.difficulty == 1 then
        missionDone:SetActive(isDone)
        missionDoing:SetActive(not isDone)
        Util.SetGray(missionDoing, not isDone)
    else
        missionDone:SetActive(false)
        missionDoing:SetActive(false)
    end
end

function this.SetExploreState()
    -- 探索度设置
    local curMapId = MapManager.curMapId
    if MapManager.allMapProgressList[curMapId] then
        local weight = MapManager.allMapProgressList[curMapId].totalWeight
        local progress = Util.GetGameObject(this.exploreRoot, "down/pro"):GetComponent("Image")
        local proText = Util.GetGameObject(this.exploreRoot, "Text"):GetComponent("Text")
        local proDone = Util.GetGameObject(this.exploreRoot, "star_done")
        local proDoing = Util.GetGameObject(this.exploreRoot, "star_doing")

        progress.fillAmount = weight / 100
        proText.text = weight .. " %"
        local isproDone = false
        if weight >= 100 then
            isproDone = true
        else
            isproDone = false
        end
        proDone:SetActive(isproDone)
        proDoing:SetActive(not isproDone)
        Util.SetGray(proDoing, not isDone)
    else

    end
end

-- 通用条件显示
function this.SetCondition(root, isDone, condition)
    local stateText = Util.GetGameObject(root, "state"):GetComponent("Text")
    local doneStar = Util.GetGameObject(root, "star_done")
    local doingStar = Util.GetGameObject(root, "star_doing")
    stateText.text = condition

    if CarbonManager.difficulty == 1 then
        doneStar:SetActive(isDone)
        doingStar:SetActive(not isDone)
        Util.SetGray(doingStar, not isDone)
    else
        doneStar:SetActive(false)
        doingStar:SetActive(false)
    end
end

-- 无极副本显示
function this.SetDoneInfoShow(root, condition)
    local stateText = Util.GetGameObject(root, "state"):GetComponent("Text")
    stateText.text = condition
end

-- 解析时间显示
function this.ShowPassTime(time)
    local ten_minute = math.modf(time / 600)
    local minute = math.modf(time / 60) % 10
    local ten_second =  math.modf( time / 10) % 6
    local second = time % 10
    local str = ten_minute  ..minute .. " : " .. ten_second .. second
    return str
end

-- 初始化物品掉落
function this.InitItemInfo()
    ClearChild(this.grid)

    local dropItem = BagManager.GetAllTempBagData()
    for i = 1, #dropItem do
        local item = dropItem[i]
        if item then
            -- 不进背包的不显示
            local isSave = 1
            --if item.itemType ~= 4 then
            --    isSave  = item.configData.IsSave
            --else
            --    isSave = ConfigManager.GetConfigData(ConfigName.ItemConfig,item.backData.equipId).IsSave
            --end
            isSave  = ConfigManager.GetConfigData(ConfigName.ItemConfig,item.sId).IsSave
            if isSave and isSave > 0 and item.num > 0 then
                local go = SubUIManager.Open(SubUIConfig.ItemView, this.grid.transform)
                go:OnOpen(true, item, 1, true, true,false,this.selfsortingOrder)
            else
               
            end
        end
    end
end

--界面关闭时调用（用于子类重写）
function MapStatsPanel:OnClose()

    this.effect:SetActive(false)
    this.panel:SetActive(true)
    MapManager.progressFull = false
end

--界面销毁时调用（用于子类重写）
function MapStatsPanel:OnDestroy()

end

return MapStatsPanel