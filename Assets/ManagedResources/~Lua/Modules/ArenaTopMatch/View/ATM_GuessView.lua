local ATM_GuessView = {}
local this = ATM_GuessView
local commonInfo = require("Modules/ArenaTopMatch/View/ATM_CommonInfo")
local matchPanel = require("Modules/ArenaTopMatch/ArenaTopMatchPanel")
local GUESS_COIN = ArenaTopMatchManager.GetGuessCoinID()
local battleStage = 0
local isCanGuessByBattleEndState = true
--初始化组件（用于子类重写）
function ATM_GuessView:InitComponent()
    this.guessPanel = Util.GetGameObject(this.transform, "guessbox")
    this.guessBox = Util.GetGameObject(this.transform, "guessbox/guess")
    this.coinIcon = Util.GetGameObject(this.guessBox, "itemIcon"):GetComponent("Image")
    this.coinNum = Util.GetGameObject(this.guessBox, "itemNum"):GetComponent("Text")

    this.blueName = Util.GetGameObject(this.guessBox, "leftName"):GetComponent("Text")
    this.blueRate = Util.GetGameObject(this.guessBox, "leftValue"):GetComponent("Text")
    this.blueBtn = Util.GetGameObject(this.guessBox, "leftBtn")
    this.blueGuess = Util.GetGameObject(this.guessBox, "leftGuess")
    this.blueProgress = Util.GetGameObject(this.guessBox, "progress/blue")

    this.redName = Util.GetGameObject(this.guessBox, "rightName"):GetComponent("Text")
    this.redRate = Util.GetGameObject(this.guessBox, "rightValue"):GetComponent("Text")
    this.redBtn = Util.GetGameObject(this.guessBox, "rightBtn")
    this.redGuess = Util.GetGameObject(this.guessBox, "rightGuess")
    this.redProgress = Util.GetGameObject(this.guessBox, "progress/red")

    this.battleDetailBtn = Util.GetGameObject(this.transform, "guessbox/btnbox/btn1")
    this.myGuessBtn = Util.GetGameObject(this.transform, "guessbox/btnbox/btn2")

    this.emptyPanel = Util.GetGameObject(this.transform, "empty")
end

-- 竞猜状态检测
local function _CheckGuess()
    local baseInfo = ArenaTopMatchManager.GetBaseData()
    if baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_READY then
        PopupTipPanel.ShowTipByLanguageId(10165)
        return false
    end
    if baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_END then
        PopupTipPanel.ShowTipByLanguageId(10166)
        return false
    end
    local myBetTarget = ArenaTopMatchManager.GetMyBetTarget()
    local IsBeted = myBetTarget and myBetTarget ~= 0
    if IsBeted then
        PopupTipPanel.ShowTipByLanguageId(10167)
        return false
    end
    if baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_BATTLE then
        PopupTipPanel.ShowTipByLanguageId(10166)
        return false
    end

    if baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS and isCanGuessByBattleEndState then
        return true
    end
    PopupTipPanel.ShowTipByLanguageId(10116)
    return false
end

--绑定事件（用于子类重写）
function ATM_GuessView:BindEvent()
    Util.AddClick(this.blueBtn, function()
        if _CheckGuess() then
            UIManager.OpenPanel(UIName.DoGuessPopup, 1)
        end
    end)

    Util.AddClick(this.redBtn, function()
        if _CheckGuess() then
            UIManager.OpenPanel(UIName.DoGuessPopup, 2)
        end
    end)

    Util.AddClick(this.myGuessBtn, function()
        ArenaTopMatchManager.RequestBetHistory(function()
            UIManager.OpenPanel(UIName.ATMMyGuessHistoryPopup)
        end)
    end)
    Util.AddClick(this.battleDetailBtn, function()
        this.battleDetailBtnClick(false)
    end)
end
function this.battleDetailBtnClick(isShowTip)
    if UIManager.IsOpen(UIName.DoGuessPopup) then
        UIManager.ClosePanel(UIName.DoGuessPopup)
    end
    local betBattleInfo = ArenaTopMatchManager.GetBetBattleInfo()
    if betBattleInfo.result == -1 then
        return
    end
    if ArenaTopMatchManager.GetIsBattleEndState(2) then
        return
    end
    if UIManager.IsOpen(UIName.BattlePanel) then
        return
    end
    local nameStr = betBattleInfo.myInfo.name.."|"..betBattleInfo.enemyInfo.name

    local structA = {
        head = betBattleInfo.myInfo.head,
        headFrame = betBattleInfo.myInfo.headFrame,
        name = SetRobotName(betBattleInfo.myInfo.uid, betBattleInfo.myInfo.name),
        formationId = betBattleInfo.myInfo.teamFormation or 1,
        investigateLevel = betBattleInfo.myInfo.investigateLevel
    }
    local structB = {
        head = betBattleInfo.enemyInfo.head,
        headFrame = betBattleInfo.enemyInfo.headFrame,
        name = SetRobotName(betBattleInfo.enemyInfo.uid, betBattleInfo.enemyInfo.name),
        formationId = betBattleInfo.enemyInfo.teamFormation or 1,
        investigateLevel = betBattleInfo.enemyInfo.investigateLevel
    }
    BattleManager.SetAgainstInfoRecordCommon(structA, structB)
    ArenaTopMatchManager.RequestReplayRecord(betBattleInfo.result, betBattleInfo.fightData, nameStr, function()

        --构建显示结果数据
        local arg = {}
        arg.panelType = 1
        arg.result = betBattleInfo.result
        arg.blue = {}
        arg.blue.uid = betBattleInfo.myInfo.uid
        arg.blue.name = betBattleInfo.myInfo.name
        arg.blue.head = betBattleInfo.myInfo.head
        arg.blue.frame = betBattleInfo.myInfo.headFrame
        arg.red = {}
        arg.red.uid = betBattleInfo.enemyInfo.uid
        arg.red.name = betBattleInfo.enemyInfo.name
        arg.red.head = betBattleInfo.enemyInfo.head
        arg.red.frame = betBattleInfo.enemyInfo.headFrame
        UIManager.OpenPanel(UIName.ArenaResultPopup, arg
        -- ,function()
        --     Game.GlobalEvent:DispatchEvent(GameEvent.TopMatch.OnGuessDataUpdateShowTip) 
        -- end
    )
    end)
end

--添加事件监听（用于子类重写）
function ATM_GuessView:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshBaseShow)
    Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnGuessDataUpdate, this.RefreshBaseShow)
    Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnGuessDataUpdateShowTip, this.RefreshGuessTipView)
    Game.GlobalEvent:AddEvent(GameEvent.TopMatch.OnGuessRateUpdate, this.RefreshBetRateShow)
    Game.GlobalEvent:AddEvent(GameEvent.ATM_RankView.OnOpenBattle, this.battleDetailBtnClick)

end

--移除事件监听（用于子类重写）
function ATM_GuessView:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnTopMatchDataUpdate, this.RefreshBaseShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnGuessDataUpdate, this.RefreshBaseShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnGuessDataUpdateShowTip, this.RefreshGuessTipView)
    Game.GlobalEvent:RemoveEvent(GameEvent.TopMatch.OnGuessRateUpdate, this.RefreshBetRateShow)
    Game.GlobalEvent:RemoveEvent(GameEvent.ATM_RankView.OnOpenBattle, this.battleDetailBtnClick)
end


--界面打开时调用（用于子类重写）
function ATM_GuessView:OnOpen(...)
    -- local emptyText=Util.GetGameObject(this.emptyPanel,"talkImage/Text"):GetComponent("Text")
    -- local oldNum=125
    -- local tempNum=oldNum
    -- local newNum=989
    -- local duration=2
    -- local interval=0.1

    -- if this.testTimer then
    --     this.testTimer:Stop()
    --     this.testTimer=nil
    -- end
    -- if not this.testTimer then
    --     this.testTimer=Timer.New(function()
    --         oldNum=oldNum+math.floor(tonumber((newNum-tempNum)/(duration/interval)))
    --         if oldNum>=newNum then
    --             oldNum=newNum
    --             this.testTimer:Stop()
    --         end
    --     emptyText.text=oldNum end,interval,-1,true)

    --     this.testTimer:Start()
    -- end
    local isActive = ArenaTopMatchManager.IsTopMatchActive()
    battleStage = ArenaTopMatchManager.GetBaseData().battleStage
    local isShow = isActive and (battleStage == TOP_MATCH_STAGE.ELIMINATION or battleStage == TOP_MATCH_STAGE.CHOOSE)
    
    this.guessPanel:SetActive(isShow)
    this.emptyPanel:SetActive(not isShow)
    if not isShow then return end

    -- 获取数据
    ArenaTopMatchManager.RequestBetBaseInfo(function()
        this.RefreshBaseShow()
    end,false)
    -- 刷新时间显示
    -- local function _TimeUpdate()
    --     -- 每秒刷新赔率
    --     ArenaTopMatchManager.RequestBetRateInfo()
    -- end
    -- if not this.timer then
    --     _TimeUpdate()
    --     this.timer = Timer.New(_TimeUpdate, 1 , -1, true)
    --     this.timer:Start()
    -- end
    -- this.RefreshGuessTipView()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ATM_GuessView:OnShow()
end

function this.RefreshBaseShow()
    local IsCanBet = ArenaTopMatchManager.IsCanBet()
    if IsCanBet then   -- 判断是否有竞猜信息
        local betBattleInfo = ArenaTopMatchManager.GetBetBattleInfo()
        this.emptyPanel:SetActive(false)
        this.guessPanel:SetActive(true)
        commonInfo.SetActive(true)
        commonInfo.SetInfoData(2, betBattleInfo.myInfo, betBattleInfo.enemyInfo, betBattleInfo.result, false,true)
        -- this.blueName.text = betBattleInfo.myInfo.name
        -- this.redName.text = betBattleInfo.enemyInfo.name

        -- if betBattleInfo.myInfo.uid < 10000 then
        --     this.blueName.text = GetLanguageStrById(tonumber(betBattleInfo.myInfo.name))
        -- else
        --     this.blueName.text = betBattleInfo.myInfo.name
        -- end
        this.blueName.text = SetRobotName(betBattleInfo.myInfo.uid)

        -- if betBattleInfo.enemyInfo.uid < 10000 then
        --     this.redName.text = GetLanguageStrById(tonumber(betBattleInfo.enemyInfo.name))
        -- else
        --     this.redName.text = betBattleInfo.enemyInfo.name
        -- end
        this.redName.text = SetRobotName(betBattleInfo.enemyInfo.uid)

        -- 刷新赔率显示
        this.RefreshBetRateShow()
        -- 有战斗结果了就显示查看详细按钮
        this.battleDetailBtn:SetActive(betBattleInfo.result ~= -1)

        local myBetTarget = ArenaTopMatchManager.GetMyBetTarget()
        local IsBeted = myBetTarget and myBetTarget ~= 0
        local upWinNum,downWinNum = ArenaTopMatchManager.GetTwoOutOfThreeInfo(2)
        isCanGuessByBattleEndState = true
        if battleStage == TOP_MATCH_STAGE.ELIMINATION then
            if upWinNum ~= 0 or downWinNum ~= 0 then 
                isCanGuessByBattleEndState = false 
            end
        end
        local blueColor = Color.New(136/255,228/255,255/255,255/255)
        local redColor = Color.New(255/255,104/255,104/255,255/255)

        if IsBeted or not isCanGuessByBattleEndState then
            local isBetRed = myBetTarget == betBattleInfo.enemyInfo.uid
            local isBetBlue = myBetTarget == betBattleInfo.myInfo.uid
            Util.GetGameObject(this.blueBtn,"Image"):GetComponent("Image").color = blueColor
            Util.GetGameObject(this.redBtn,"Image"):GetComponent("Image").color = redColor
            this.redGuess:SetActive(isBetRed)
            this.blueGuess:SetActive(isBetBlue)
        elseif isCanGuessByBattleEndState then
            local baseInfo = ArenaTopMatchManager.GetBaseData()
            local isInGuess = baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS
            Util.GetGameObject(this.blueBtn,"Image"):GetComponent("Image").color = blueColor
            Util.GetGameObject(this.redBtn,"Image"):GetComponent("Image").color = redColor
            this.redGuess:SetActive(false)
            this.blueGuess:SetActive(false)
        end
    else
        this.emptyPanel:SetActive(true)
        this.guessPanel:SetActive(false)
        commonInfo.SetActive(false)
    end
end

-- 刷新赔率显示
function this.RefreshBetRateShow()
    -- local betRateInfo = ArenaTopMatchManager.GetBetRateInfo()
    -- -- 避免除数为0的错误
    -- if betRateInfo.redCoins <= 0 then betRateInfo.redCoins = 1 end
    -- if betRateInfo.blueCoins <= 0 then betRateInfo.blueCoins = 1 end
    --
    -- local allCoin = betRateInfo.redCoins + betRateInfo.blueCoins
    -- 下注比例
    local redRate = 0.5--betRateInfo.redCoins/allCoin
    local blueRate = 0.5--betRateInfo.blueCoins/allCoin
    this.redProgress.transform.localScale = Vector3.New(redRate, 1, 1)
    this.blueProgress.transform.localScale = Vector3.New(blueRate, 1, 1)

    -- 赔率
    local redWinRate = ArenaTopMatchManager.rate--allCoin/betRateInfo.redCoins
    local blueWinRate =  ArenaTopMatchManager.rate--allCoin/betRateInfo.blueCoins
    this.redRate.text = GetLanguageStrById(50275)..": <color=F94441>".. string.format("%0.2f", redWinRate).."</color>"
    this.blueRate.text = GetLanguageStrById(50275)..": <color=3F8AE3>".. string.format("%0.2f", blueWinRate).."</color>"

    -- 竞猜币
    this.coinIcon.sprite = SetIcon(GUESS_COIN)
    this.coinNum.text = BagManager.GetItemCountById(GUESS_COIN)

    local battleState = ArenaTopMatchManager.GetBaseData().battleState
    --当竞猜完 记下当前竞猜币
    local myBetTarget = ArenaTopMatchManager.GetMyBetTarget()
    if battleState == TOP_MATCH_TIME_STATE.OPEN_IN_GUESS and myBetTarget and myBetTarget ~= 0 then
        ArenaTopMatchManager.SetCoinNum(BagManager.GetItemCountById(GUESS_COIN))
        
    end
end

-- --刷新竞猜提示
-- function this.RefreshGuessTipView()
--     local IsCanBet = ArenaTopMatchManager.IsCanBet()
--     if IsCanBet then   -- 判断是否有竞猜信息
--         local myBetTarget = ArenaTopMatchManager.GetMyBetTarget()
--         local IsBeted = myBetTarget and myBetTarget ~= 0
--         local isShow = ArenaTopMatchManager.GetcurIsShowDoGuessPopup()

--         -- if 
--         local upWinNum,downWinNum = ArenaTopMatchManager.GetTwoOutOfThreeInfo(2)
--         local isBattleEnd = (upWinNum >= 2 or downWinNum >= 2)

--         --打开竞猜提示(处于秋后算账)
--         if IsBeted and isShow and (isBattleEnd and battleStage == TOP_MATCH_STAGE.ELIMINATION or battleStage == TOP_MATCH_STAGE.CHOOSE)  then
--             local baseInfo = ArenaTopMatchManager.GetBaseData()
--             if baseInfo.battleState == TOP_MATCH_TIME_STATE.OPEN_IN_END then

--                 ArenaTopMatchManager.SetcurIsShowDoGuessPopup(false)
--                 matchPanel.OpenView(6)
--             end
--         end
--     end
-- end

--界面关闭时调用（用于子类重写）
function ATM_GuessView:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
    commonInfo.SetEffectPopupShow(false)
end

--界面销毁时调用（用于子类重写）
function ATM_GuessView:OnDestroy()

end

return ATM_GuessView