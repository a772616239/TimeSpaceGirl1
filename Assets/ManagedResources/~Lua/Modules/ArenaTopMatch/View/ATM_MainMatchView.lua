local ATM_MainMatchView = {}
local this = ATM_MainMatchView
local commonInfo = require("Modules/ArenaTopMatch/View/ATM_CommonInfo")
local rewardView = require("Modules/ArenaTopMatch/ArenaTopMatchPanel")
--初始化组件（用于子类重写）
function ATM_MainMatchView:InitComponent()
    this.btnRecord = Util.GetGameObject(self.gameObject, "record")
    this.rewardBtn = Util.GetGameObject(self.gameObject,"rewardBtn")
    this.btnTeamRank = Util.GetGameObject(self.gameObject, "teamRank")

    this.btnFightDetail = Util.GetGameObject(self.gameObject, "btnDetail")

    this.containPanel = Util.GetGameObject(self.gameObject, "contain")
    this.lockPanel = Util.GetGameObject(self.gameObject, "contain/LockBg")
    this.lockContext = Util.GetGameObject(this.lockPanel, "context"):GetComponent("Text")

    this.lockTime = Util.GetGameObject(this.lockPanel, "JoinRoot/time"):GetComponent("Text")
    this.lockTip = Util.GetGameObject(this.lockPanel, "JoinRoot/tip"):GetComponent("Text")

    this.outTip = Util.GetGameObject(this.lockPanel, "OutRoot/Text"):GetComponent("Text")

    this.WeedOutText = Util.GetGameObject(this.lockPanel, "WeedOutRoot/Text"):GetComponent("Text")
    this.WeedOutMyRank = Util.GetGameObject(this.lockPanel, "WeedOutRoot/MyRank"):GetComponent("Text")
    this.WeedOutMyRankText = Util.GetGameObject(this.lockPanel, "WeedOutRoot/MyRank/Text"):GetComponent("Text")
    this.WeedOutBestRank = Util.GetGameObject(this.lockPanel, "WeedOutRoot/BestRank"):GetComponent("Text")
    this.WeedOutBestRankText = Util.GetGameObject(this.lockPanel, "WeedOutRoot/BestRank/Text"):GetComponent("Text")

    this.lockIn = Util.GetGameObject(this.lockPanel, "JoinRoot")
    this.lockOut = Util.GetGameObject(this.lockPanel, "OutRoot")
    this.WeedOutRoot = Util.GetGameObject(this.lockPanel, "WeedOutRoot")

    this.effect = Util.GetGameObject(self.gameObject, "bg/UI_effect_ArenaMainPanel_particle")

    this.orggroup =  Util.GetGameObject(this.lockPanel, "orggroup")
end

--绑定事件（用于子类重写）
function ATM_MainMatchView:BindEvent()
    commonInfo.BindEvent()

    Util.AddClick(this.rewardBtn, function ()       
        rewardView.SetRewardViewActive(5)
    end)

    Util.AddClick(this.btnRecord, function ()
        ArenaTopMatchManager.RequestBattleHistory(function()
            UIManager.OpenPanel(UIName.RecordPopup)
        end)
    end)

    Util.AddClick(this.btnTeamRank, function ()
        ArenaTopMatchManager.RequestMyTeamRank(function()
            UIManager.OpenPanel(UIName.ATMTeamRankPopup)
        end)
    end)

    Util.AddClick(this.btnFightDetail, function ()
        this.battleDetailBtnClick()
    end)

end
--添加事件监听（用于子类重写）
function ATM_MainMatchView:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.OnOpen, this)
    Game.GlobalEvent:AddEvent(GameEvent.ATM_RankView.OnOpenBattle, this.battleDetailBtnClick)
    Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnMyBattlePlayback, this.battleDetailBtnClick)
end

--移除事件监听（用于子类重写）
function ATM_MainMatchView:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.OnOpen, this)
    Game.GlobalEvent:RemoveEvent(GameEvent.ATM_RankView.OnOpenBattle, this.battleDetailBtnClick)
    Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnMyBattlePlayback, this.battleDetailBtnClick)
end

--界面打开时调用（用于子类重写）
function ATM_MainMatchView:OnOpen(...)
    local isActive = ArenaTopMatchManager.IsTopMatchActive()
    this.StateChange(isActive)
end

-- 状态切换
local isJoin = nil
local isOver = nil
function this.StateChange(isOpen)
    local baseData = ArenaTopMatchManager.GetBaseData()

    -- 没开启或者开启没参赛都属于未参赛
    isJoin = baseData.joinState == 1
    isOver = baseData.progress == -2
    -- LogGreen("isOpen        "..tostring(isOpen).."          "..tostring(isJoin).."           "..tostring(isOver).."        "..baseData.joinState)
    local battleInfo = ArenaTopMatchManager.GetBattleInfo()
    -- LogGreen("battleInfo.result        "..battleInfo.result.."       baseData.battleState       "..baseData.battleState)
    -- LogGreen("baseData.loser          "..tostring(baseData.loser))
    if isOpen then
        if isJoin then
            this.SetPlayerInfo()
            if baseData.loser then
                this.SetWeedOutRootInfo()
            end
        else
            this.SetNotJionInfo()
        end
        if isOver then
            this.SetOverInfo()
        end
    else
        if isOver then
            this.SetOverInfo()
        else
            this.SetLockInfo()
        end
    end
   
    this.containPanel:SetActive(not isOpen or not isJoin or baseData.loser or isOver)
    this.btnRecord:SetActive(isOpen and isJoin)
    this.btnTeamRank:SetActive(isOpen and isJoin)
    this.btnFightDetail:SetActive(isOpen and isJoin and baseData.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_END)
    this.orggroup:SetActive(true)

    Util.AddOnceClick(this.orggroup, function ()
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_TOP_MATCH, function()
            -- 重新获取战斗数据
            --ArenaTopMatchManager.RequestTopMatchBaseInfo()
        end)
    end)
end


function this.battleDetailBtnClick()
    if BattleManager.IsInBackBattle() then
        return
    end
    local battleInfo = ArenaTopMatchManager.GetBattleInfo()
    if not isJoin or (isJoin and isOver) then
        return
    end
    if battleInfo.result == -1 then
        PopupTipPanel.ShowTipByLanguageId(50234)
        return
    end
    if ArenaTopMatchManager.GetIsBattleEndState(1) then
        return
    end
    if UIManager.IsOpen(UIName.BattlePanel) then
        return
    end
    local nameStr = battleInfo.myInfo.name.."|"..battleInfo.enemyInfo.name

    local structA = {
        head = battleInfo.myInfo.head,
        headFrame = battleInfo.myInfo.headFrame,
        name = SetRobotName(battleInfo.myInfo.uid, battleInfo.myInfo.name),
        formationId = battleInfo.myInfo.teamFormation or 1,
        investigateLevel = battleInfo.myInfo.investigateLevel
    }
    local structB = {
        head = battleInfo.enemyInfo.head,
        headFrame = battleInfo.enemyInfo.headFrame,
        name = SetRobotName(battleInfo.enemyInfo.uid, battleInfo.enemyInfo.name),
        formationId = battleInfo.enemyInfo.teamFormation or 1,
        investigateLevel = battleInfo.enemyInfo.investigateLevel
    }
    BattleManager.SetAgainstInfoRecordCommon(structA, structB)

    -- BattleManager.SetAgainstInfoRecordCommon(battleInfo.myInfo, battleInfo.enemyInfo)
    ArenaTopMatchManager.RequestReplayRecord(battleInfo.result, battleInfo.fightData, nameStr, function()
        local blueInfo = battleInfo.myInfo
        local redInfo = battleInfo.enemyInfo
        --构建显示结果数据
        local arg = {}
        arg.result = battleInfo.result
        arg.blue = {}
        arg.blue.uid = blueInfo.uid
        arg.blue.name = blueInfo.name
        arg.blue.head = blueInfo.head
        arg.blue.frame = blueInfo.headFrame
        arg.blue.level = blueInfo.level
        arg.red = {}
        arg.red.uid = redInfo.uid
        arg.red.name = redInfo.name
        arg.red.head = redInfo.head
        arg.red.frame = redInfo.headFrame
        arg.red.level = redInfo.level
        UIManager.OpenPanel(UIName.ArenaResultPopup, arg)
    end)
end

function this.SetPlayerInfo()
    this.lockIn:SetActive(false)
    this.lockOut:SetActive(false)
    this.WeedOutRoot:SetActive(false)

    local battleInfo = ArenaTopMatchManager.GetBattleInfo()

    local attInfo = battleInfo.myInfo
    local defInfo = battleInfo.enemyInfo

    local myResult = -1
    local blueInfo = nil
    local redInfo = nil
    
    local battleEndResultSortState = true --true  战斗最终直接赋值 false 颠倒赋值 
    if attInfo.uid == PlayerManager.uid then
        blueInfo = attInfo
        redInfo = defInfo
        myResult = battleInfo.result
        battleEndResultSortState = true
    elseif defInfo.uid == PlayerManager.uid then
        blueInfo = defInfo
        redInfo = attInfo
        if battleInfo.result ~= -1 then
            myResult = (battleInfo.result + 1) % 2
        end
        battleEndResultSortState = false
    end

    --if battleInfo.result == 0 then  -- 如果进攻方失败，则如果我是进攻方则我失败，反之胜利
    --    myResult = attInfo.uid == PlayerManager.uid and 0 or 1
    --elseif battleInfo.result == 1 then -- 如果进攻方胜利，则如果我是进攻方则我胜利
    --    myResult = attInfo.uid == PlayerManager.uid and 1 or 0
    --end
    
    local baseData = ArenaTopMatchManager.GetBaseData()
    commonInfo.SetActive(true)

    commonInfo.SetInfoData(1, blueInfo, redInfo, myResult, baseData == TOP_MATCH_STAGE.CHOOSE,battleEndResultSortState)
end

function this.SetLockInfo()
    --加一套编队
    this.lockIn:SetActive(true)
    this.lockOut:SetActive(false)
    this.WeedOutRoot:SetActive(false)
    commonInfo.SetActive(false)

    this.lockContext.text = GetLanguageStrById(10169)
    this.lockTip.text = GetLanguageStrById(10170)

    if not this.lockTimer then
        local startTime = ArenaTopMatchManager.GetTopMatchTime()
        local during = startTime - PlayerManager.serverTime
        during = during <= 0 and 0 or during
        this.lockTime.text = TimeToHMS(during)

        this.lockTimer = Timer.New(function ()
            local startTime = ArenaTopMatchManager.GetTopMatchTime()
            local during = startTime - PlayerManager.serverTime
            during = during <= 0 and 0 or during
            local timeStr = TimeToHMS(during)
            this.lockTime.text = timeStr
        end, 1, -1, true)
        this.lockTimer:Start()
    end
    --this.FreshTeam()
    Util.AddOnceClick(this.orggroup, function ()
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_TOP_MATCH, function()
            -- 重新获取战斗数据
            --ArenaTopMatchManager.RequestTopMatchBaseInfo()
        end)
    end)
end

function this.FreshTeam()
    Util.AddOnceClick(this.orggroup, function ()
        UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.ARENA_TOP_MATCH, function()
            -- 重新获取战斗数据
            --ArenaTopMatchManager.RequestTopMatchBaseInfo()
        end)
    end)
end

--未参加
function this.SetNotJionInfo()
    this.lockIn:SetActive(false)
    this.lockOut:SetActive(true)
    this.WeedOutRoot:SetActive(false)
    commonInfo.SetActive(false)
    this.lockContext.text = GetLanguageStrById(10171)
    this.outTip.text = GetLanguageStrById(10172)
end
--结束
function this.SetOverInfo()
    this.lockIn:SetActive(false)
    this.lockOut:SetActive(true)
    this.WeedOutRoot:SetActive(false)
    commonInfo.SetActive(false)
    this.lockContext.text = GetLanguageStrById(10173)
    this.outTip.text = GetLanguageStrById(10174)
end
--淘汰
function this.SetWeedOutRootInfo()
    this.lockIn:SetActive(false)
    this.lockOut:SetActive(false)
    this.WeedOutRoot:SetActive(true)
    commonInfo.SetActive(false)
    local tmData = ArenaTopMatchManager.GetBaseData()
    this.WeedOutText.text = GetLanguageStrById(12208)
    this.WeedOutMyRank.text = GetLanguageStrById(10104)
    this.WeedOutMyRankText.text = tmData.myrank <= 0 and GetLanguageStrById(10041) or ArenaTopMatchManager.GetRankNameByRank(tmData.myrank)
    this.WeedOutBestRank.text = GetLanguageStrById(12245)
    this.WeedOutBestRankText.text = tmData.maxRank <= 0 and GetLanguageStrById(10094) or this.GetRankName(tmData.maxRank)
end

-- 获取我的排名信息
function this.GetRankName(rank)
    if rank == 1 then
        return GetLanguageStrById(10095)
    elseif rank == 2 then
        return GetLanguageStrById(10096)
    else
        local maxTurn = ArenaTopMatchManager.GetEliminationMaxRound()
        for i = 1, maxTurn do
            if i == maxTurn then
                local config = ConfigManager.GetConfigData(ConfigName.ChampionshipSetting, 1)
                return config.ChampionshipPlayer..GetLanguageStrById(10097)
            end
            if rank > math.pow(2, i) and rank <= math.pow(2, i+1) then
                return (i+1)..GetLanguageStrById(10097)
            end
        end
    end
end

-- 层级改变回调
local orginLayer = 0
function ATM_MainMatchView:OnSortingOrderChange(sort)
    --Util.AddParticleSortLayer(this.effect, sort - orginLayer)
    --orginLayer = sort
end

--界面关闭时调用（用于子类重写）
function ATM_MainMatchView:OnClose()
    if this.lockTimer then
        this.lockTimer:Stop()
        this.lockTimer = nil
    end
    commonInfo.SetEffectPopupShow(false)
end

--界面销毁时调用（用于子类重写）
function ATM_MainMatchView:OnDestroy()

end

return ATM_MainMatchView