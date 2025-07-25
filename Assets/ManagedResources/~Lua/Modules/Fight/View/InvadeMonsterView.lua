InvadeMonsterView = {}
local this = InvadeMonsterView
local StoreConfig = ConfigManager.GetConfig(ConfigName.StoreConfig)
local TaskConfig = ConfigManager.GetConfig(ConfigName.TaskConfig)
local orginLayer = 0
-- 上一个宝箱的状态
local lastBoxState = 0
-- 是否已经点击了宝箱
local hadClicked = false

--初始化组件（用于子类重写）
function InvadeMonsterView:InitComponent(gameObject, fightPointPassMainPanel)
    self.gameObject = gameObject
    this.adventureMainPanel = fightPointPassMainPanel

    this.rewardBox = Util.GetGameObject(self.gameObject, "Bg/getBoxReward/btn")--宝箱
    this.btnFastExplore = Util.GetGameObject(self.gameObject, "Bg/btnDown/btnFastExplore")--快速训练
    this.expeditionRedPoint = Util.GetGameObject(self.gameObject, "Bg/btnDown/btnFastExplore/redPoint")--快速训练红点
    this.trainTask = Util.GetGameObject(self.gameObject, "Bg/btnDown/btnFastExplore/task")--快速训练任务

    this.btnRewardChapter = Util.GetGameObject(self.gameObject, "Bg/btnRewardChapter")--通关奖励
    this.chapterRedPoint = Util.GetGameObject(self.gameObject, "Bg/btnRewardChapter/redPoint")--通关奖励红点
    this.btnRewardChapterText = Util.GetGameObject(self.gameObject, "Bg/btnRewardChapter/Text"):GetComponent("Text")

    --在线奖励
    this.btnRewardOnline = Util.GetGameObject(self.gameObject, "Bg/box/btnRewrdOnline")
    this.onlineRedPoint = Util.GetGameObject(this.btnRewardOnline, "redPoint")
    this.onlineRewardQuality = Util.GetGameObject(this.btnRewardOnline, "quality"):GetComponent("Image")
    this.onlineRewardIcon = Util.GetGameObject(this.btnRewardOnline, "icon"):GetComponent("Image")
    this.onlineRewardNum = Util.GetGameObject(this.btnRewardOnline, "num"):GetComponent("Text")
    this.onlineRewardTime = Util.GetGameObject(this.btnRewardOnline, "time"):GetComponent("Text")
    this.onlineRewardEffect = Util.GetGameObject(this.btnRewardOnline, "effect")
    this.onlineRewardGetEffect = Util.GetGameObject(this.btnRewardOnline, "getEffect")
    effectAdapte(Util.GetGameObject(this.onlineRewardEffect, "ziti mask (1)"))
    this.onlineRewardData = nil
    this.onlineRewardState = nil
end

--绑定事件（用于子类重写）
function InvadeMonsterView:BindEvent()
    --点击宝箱领取奖励
    Util.AddClick(this.rewardBox, function()
        if not hadClicked then
            hadClicked = true
            FightPointPassManager.oldLevel = PlayerManager.level
            local boxState = this.GetBoxShowState()

            if boxState > 0 then
                local isPopUp = RedPointManager.PlayerPrefsGetStr(PlayerManager.uid .. "mazeTreasureMax")
                local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                local mazeTreasureMax = ConfigManager.GetConfigData(ConfigName.PlayerLevelConfig,PlayerManager.level).MazeTreasureMax
                local str = GetLanguageStrById(10562)..BagManager.GetItemCountById(FindTreasureManager.materialItemId).."/"..mazeTreasureMax..
                        GetLanguageStrById(10563)..GetLanguageStrById(ConfigManager.GetConfigData(ConfigName.ItemConfig,FindTreasureManager.materialItemId).Name)..
                        GetLanguageStrById(10619)

                if BagManager.GetItemCountById(FindTreasureManager.materialItemId) >= mazeTreasureMax and isPopUp ~= currentTime then
                    MsgPanel.ShowTwo(str, nil, function(isShow)
                        if (isShow) then
                            local currentTime = os.date("%Y%m%d", PlayerManager.serverTime)
                            RedPointManager.PlayerPrefsSetStr(PlayerManager.uid .."mazeTreasureMax", currentTime)
                        end
                        FightPointPassManager.isBeginFight = true
                        AdventureManager.GetAventureRewardRequest(2, false, false)
                        -- this.InitBoxShow()
                    end,nil,nil,nil,true)
                else
                    FightPointPassManager.isBeginFight = true
                    AdventureManager.GetAventureRewardRequest(2, false, false)
                    -- this.InitBoxShow()
                end
                -- Game.GlobalEvent:DispatchEvent(GameEvent.GetBoxReward.OnUpdateTime)
            else
                PopupTipPanel.ShowTipByLanguageId(10620)
            end
 
            hadClicked = false
        end
    end)
    -- 在线奖励
    Util.AddClick(this.btnRewardOnline, function()
        --UIManager.OpenPanel(UIName.CourtesyDressPanel, ActivityTypeDef.OnlineGift, true)
        UIManager.OpenPanel(UIName.OnlineRewardPanel, ActivityTypeDef.OnlineGift, true)
    end)
    Util.AddClick(this.btnFastExplore, function()
        FightPointPassManager.isBeginFight = true
        UIManager.OpenPanel(UIName.FastExploreInfoPopup)
    end)
    -- 通关奖励
    Util.AddClick(this.btnRewardChapter, function()
        UIManager.OpenPanel(UIName.CourtesyDressPanel, ActivityTypeDef.ChapterAward, true)
    end)

    BindRedPointObject(RedPointType.QuickTrain,this.expeditionRedPoint)
end

----@param hangupTime 已经挂机时长
function this.GetBoxShowState()
    local hangupTime = AdventureManager.stateTime
    local state = 0
    if hangupTime < AdventureManager.adventureRefresh then
        state = 0
    elseif hangupTime >= AdventureManager.adventureRefresh and AdventureManager.adventureBoxShow[1] ~= nil and hangupTime < AdventureManager.adventureBoxShow[1] then
        state = 1
    elseif hangupTime >= AdventureManager.adventureRefresh and AdventureManager.adventureBoxShow[2] ~= nil and hangupTime < AdventureManager.adventureBoxShow[2] then
        state = 2
    elseif hangupTime >= AdventureManager.adventureRefresh and AdventureManager.adventureBoxShow[3] ~= nil and hangupTime < AdventureManager.adventureBoxShow[3] then
        state = 3
    elseif hangupTime >= AdventureManager.adventureRefresh and AdventureManager.adventureBoxShow[4] ~= nil and hangupTime < AdventureManager.adventureBoxShow[4] then
        state = 4
    elseif hangupTime >= AdventureManager.adventureRefresh and AdventureManager.adventureBoxShow[5] ~= nil and hangupTime < AdventureManager.adventureBoxShow[5] then
        state = 5
    else
        state = 6
    end
    return state
end

function InvadeMonsterView:OnSortingOrderChange()
end

--添加事件监听（用于子类重写）
function InvadeMonsterView:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnRefeshBoxRewardShow, this.GetBoxShowState)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnRefreshRedShow, this.OnRefreshRedPoint)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.OnFastBattleChanged, this.OnRefreshRedPoint)
    Game.GlobalEvent:AddEvent(GameEvent.OnlineGift.GetOnlineRewardSuccess, this.RefreshOnlineRewardShow)
    Game.GlobalEvent:AddEvent(GameEvent.OnlineGift.GetOnlineRewardSuccess, this.OnRefreshRedPoint)
    Game.GlobalEvent:AddEvent(GameEvent.RedPoint.TrainTask, this.SetTrainTaskState)
    Game.GlobalEvent:AddEvent(GameEvent.Adventure.UpdateMultiUI,this.SetImgNative)
end

--移除事件监听（用于子类重写）
function InvadeMonsterView:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnRefeshBoxRewardShow, this.GetBoxShowState)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnRefreshRedShow, this.OnRefreshRedPoint)
    Game.GlobalEvent:RemoveEvent(GameEvent.Adventure.OnFastBattleChanged, this.OnRefreshRedPoint)
    Game.GlobalEvent:RemoveEvent(GameEvent.OnlineGift.GetOnlineRewardSuccess, this.RefreshOnlineRewardShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.OnlineGift.GetOnlineRewardSuccess, this.OnRefreshRedPoint)
    Game.GlobalEvent:RemoveEvent(GameEvent.RedPoint.TrainTask, this.SetTrainTaskState)
end

function this.SetImgNative()
    Log("InvadeMonsterView")
    this.btnRewardChapterImg = Util.GetGameObject(this.btnRewardChapter, "Image"):GetComponent("Image")
    this.btnRewardChapterImg:SetNativeSize()
end

--界面打开时调用（用于子类重写）
function InvadeMonsterView:OnShow(...)
    lastBoxState = 0
    this:OnRefreshRedPoint()
    this:GetBoxShowState()
    -- 在线奖励
    this.RefreshOnlineRewardShow()
    --判断章节奖励是全部领完
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.Chapter_Reward) then
        if not ActivityGiftManager.chapterOpen or ActivityGiftManager.ActivityIsHaveGetFinally(ActivityGiftManager.chapterGetRewardState) then
            this.btnRewardChapter:SetActive(false)
        else
            this.btnRewardChapter:SetActive(true)
        end
    else
        this.btnRewardChapter:SetActive(false)
    end
    this.SetTrainTaskState()

end

function this.SetTrainTaskState()
    local taskIsOpen = ActTimeCtrlManager.IsQualifiled(FUNCTION_OPEN_TYPE.QuickTrain)
    this.trainTask:SetActive(taskIsOpen and AdventureManager.GetTrainStageLevel() > -1)
    if not taskIsOpen then
        return
    end
    if AdventureManager.GetTrainStageLevel() == -1 then
        return
    end
    local taskConfig = ConfigManager.GetConfigDataByKey(ConfigName.TrainTask, "Level", AdventureManager.GetTrainStageLevel())
    local finishNum = 0
    for i = 1, #taskConfig.TaskID do
        local taskData = TaskConfig[taskConfig.TaskID[i]]
        local severData = TaskManager.GetTypeTaskInfo(TaskTypeDef.Train, taskData.Id)
        if severData.state == 2 then
            finishNum = finishNum + 1
        end
    end
    for i = 1, 3 do
        this.trainTask.transform:GetChild(i-1).gameObject:SetActive(i <= finishNum)
    end
end

-- 刷新在线奖励显示
function this.RefreshOnlineRewardShow()
    --判断在线礼包是全部领完
    if ActTimeCtrlManager.SingleFuncState(FUNCTION_OPEN_TYPE.Online_Reward) then
        if not ActivityGiftManager.onlineOpen or ActivityGiftManager.ActivityIsHaveGetFinally(ActivityGiftManager.onlineGetRewardState) then
            this.btnRewardOnline:SetActive(false)
        else
            -- this.btnRewardOnline.transform.position = this.btnRewardOnlinePos
            this.btnRewardOnline:SetActive(true)
            CheckRedPointStatus(RedPointType.CourtesyDress_Online)
        end
    else
        this.btnRewardOnline:SetActive(false)
    end
    -- 获取在线奖励状态
    this.onlineRewardData, this.onlineRewardState = ActivityGiftManager.GetNextOnlineRewardData()
    this.CheckOnlineRewardShow()

    this.adventureMainPanel.UpdateOpenSeverWelfare()

end

--倒计时时间格式化
function this.ForamtionCountDownTime(remainTime)
    local hour = 0
    local min = 0
    local sec = 0
    sec = math.floor(remainTime % 60)
    hour = math.floor(remainTime / 3600)
    min = 0
    if hour >= 1 then
        min = math.floor((remainTime - hour * 3600) / 60)
    else
        min = math.floor(remainTime / 60)
    end
    return string.format("%02d:%02d:%02d", hour, min, sec)
end

-----============================ 外敌相关 ==============================

--刷新红点
function this:OnRefreshRedPoint()
    -- 探索红点
    -- local hadExplore = AdventureManager.GetSandFastBattleCount() ~= 0
    -- 在线红点
    local hadOnline = ActivityGiftManager.CheckOnlineRed()
    -- 章节红点
    local hadChpater = ActivityGiftManager.CheckChapterRed()
    -- this.editionRedPoint:SetActive(hadExplore)
    this.onlineRedPoint:SetActive(hadOnline)
    this.chapterRedPoint:SetActive(hadChpater)
    this.btnRewardChapterText.gameObject:SetActive(true)
    if hadChpater then
        this.btnRewardChapterText.text = GetLanguageStrById(10471)
    else
        local needLevelNum = ActivityGiftManager.GetRewardNeedLevel()
        local str = ""
        if needLevelNum > 0 then
            str = GetLanguageStrById(10621)..needLevelNum..GetLanguageStrById(10622)
            this.btnRewardChapterText.text = str
        else
            this.btnRewardChapterText.gameObject:SetActive(false)
        end
    end
end

-- 检测在线奖励状态
function this.CheckOnlineRewardShow()
    if not this.onlineRewardData then
        this.onlineRewardEffect:SetActive(false)
        this.onlineRewardGetEffect:SetActive(false)
        this.onlineRewardTime.text = GetLanguageStrById(10370)
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
    else
        local itemId = this.onlineRewardData.Reward[1][1]
        this.onlineRewardQuality.sprite = SetFrame(itemId)
        this.onlineRewardIcon.sprite = SetIcon(itemId)
        this.onlineRewardNum.text = this.onlineRewardData.Reward[1][2]
        if this.onlineRewardState == 0 then
            this.onlineRewardEffect:SetActive(true)
            this.onlineRewardGetEffect:SetActive(true)
            this:OnRefreshRedPoint()
            this.onlineRewardTime.text = GetLanguageStrById(10471)
            if this.timer then
                this.timer:Stop()
                this.timer = nil
            end
        elseif this.onlineRewardState == -1 then
            this.onlineRewardEffect:SetActive(false)
            this.onlineRewardGetEffect:SetActive(false)
            if not this.timer then
                this.TimeUpdate()
                this.timer = Timer.New(this.TimeUpdate, 1, -1, true)
                this.timer:Start()
            end
        end
    end
end

-- 定时器回调
function this.TimeUpdate()
    if this.onlineRewardState == -1 then
        local curOnlineTime = GetTimeStamp() - ActivityGiftManager.cuOnLineTimestamp
        local needTime = this.onlineRewardData.Values[1][1]*60
        local remainTime = needTime - curOnlineTime
        if remainTime >= 0 then
            this.onlineRewardTime.text = TimeToMS(remainTime)
        else
            this.RefreshOnlineRewardShow()
        end
    else
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
    end
end

--界面关闭时调用（用于子类重写）
function InvadeMonsterView:OnClose()
    if this.timerEffect then
        this.timerEffect:Stop()
    end

    this.timerEffect = nil

    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end

end

--界面销毁时调用（用于子类重写）
function InvadeMonsterView:OnDestroy()
    ClearRedPointObject(RedPointType.QuickTrain, this.expeditionRedPoint)
end

return InvadeMonsterView