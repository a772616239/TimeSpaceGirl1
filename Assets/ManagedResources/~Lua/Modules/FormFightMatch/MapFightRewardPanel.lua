local RewardItem = {}
function RewardItem:New(gameObject)
    local b = {}
    b.gameObject = gameObject
    b.transform = gameObject.transform
    setmetatable(b, { __index = RewardItem })
    b:Init()
    return b
end
-- 初始化节点
function RewardItem:Init()
    self.score = Util.GetGameObject(self.transform, "score"):GetComponent("Text")
    self.items = {}
    for i = 1, 2 do
        self.items[i] = {}
        for j = 1, 2 do
            self.items[i][j] = {}
            local go = Util.GetGameObject(self.transform, "itembox_"..i.."/item_"..j)
            local itemRoot = Util.GetGameObject(go, "root").transform
            self.items[i][j].go = go
            self.items[i][j].item = SubUIManager.Open(SubUIConfig.ItemView, itemRoot)
            self.items[i][j].received = Util.GetGameObject(go, "received")
        end
    end
    self.btnDeal = Util.GetGameObject(self.transform, "btnDeal")
    self.btnText = Util.GetGameObject(self.btnDeal, "Text"):GetComponent("Text")
    self.btnRedpot = Util.GetGameObject(self.btnDeal, "redPoint")
    self.finished = Util.GetGameObject(self.transform, "finished")

    Util.AddOnceClick(self.btnDeal, function()
        self:OnDealBtnClick()
    end)
end
-- 设置奖励数据
function RewardItem:SetData(data)
    self.data = data
    -- 积分
    self.score.text = data.SeasonPass
    -- 奖励显示
    for i = 1, 2 do
        local rewardList = i == 1 and data.SeasonReward or data.SeasonTokenReward
        for j = 1, 2 do
            local item = self.items[i][j]
            if item then
                local reward = rewardList[j]
                if not reward then
                    item.go:SetActive(false)
                else
                    item.go:SetActive(true)
                    item.item:OnOpen(false, reward, 0.75)
                end
            end
        end
    end
end
-- 设置状态
function RewardItem:SetState(state)
    self.state = state

    -- 奖励显示
    for i = 1, 2 do
        for j = 1, 2 do
            local item = self.items[i][j]
            if item then
                if i == 1 then
                    item.received:SetActive(state > MAP_FIGHT_REWARD_STATE.GET_1)
                    Util.SetGray(item.item.gameObject, state > MAP_FIGHT_REWARD_STATE.GET_1)
                else
                    item.received:SetActive(state > MAP_FIGHT_REWARD_STATE.GET_2)
                    Util.SetGray(item.item.gameObject, state > MAP_FIGHT_REWARD_STATE.GET_2)
                end
            end
        end
    end

    -- 按钮显示设置
    self.btnDeal:SetActive(state < MAP_FIGHT_REWARD_STATE.FINISH)
    self.btnDeal:GetComponent("Button").interactable = state > MAP_FIGHT_REWARD_STATE.UN_FINISH
    Util.SetGray(self.btnDeal, state == MAP_FIGHT_REWARD_STATE.UN_FINISH)
    self.btnText.text = state <= MAP_FIGHT_REWARD_STATE.GET_1 and GetLanguageStrById(10022) or GetLanguageStrById(10752)

    -- 是否完成
    self.finished:SetActive(state == MAP_FIGHT_REWARD_STATE.FINISH)

end
-- 回收item
function RewardItem:OnDealBtnClick()
    assert(self.state, GetLanguageStrById(10753))
    if self.state == MAP_FIGHT_REWARD_STATE.UN_FINISH then
    elseif self.state == MAP_FIGHT_REWARD_STATE.GET_1 then
        MatchDataManager.RequestGetScoreReward(self.data.Id)
    elseif self.state == MAP_FIGHT_REWARD_STATE.GET_2 then
        if MatchDataManager.IsBuyExtra() then
            MatchDataManager.RequestGetScoreReward(self.data.Id)
        else
            UIManager.OpenPanel(UIName.MapFightBuyExtraPopup)
        end
    elseif self.state == MAP_FIGHT_REWARD_STATE.FINISH then
    end
end

-- 回收item
function RewardItem:Recycle()
    for _, list in ipairs(self.items) do
        for _, item in ipairs(list) do
            Util.SetGray(item.item.gameObject, false)
            SubUIManager.Close(item.item)
        end
    end
end



require("Base/BasePanel")
local MapFightRewardPanel = Inherit(BasePanel)
local this = MapFightRewardPanel

local _BloodyBattleTreasure = ConfigManager.GetConfig(ConfigName.BloodyBattleTreasure)

--初始化组件（用于子类重写）
function MapFightRewardPanel:InitComponent()
    this.curScore = Util.GetGameObject(self.transform, "bg/pageContent/topBar/currentScore"):GetComponent("Text")
    this.remainTime = Util.GetGameObject(self.transform, "bg/pageContent/topBar/remainTime"):GetComponent("Text")

    this.itemRoot = Util.GetGameObject(self.transform, "bg/pageContent/page/treasureList/viewPort/content")
    this.item = Util.GetGameObject(this.itemRoot, "itemPro")

    this.btnUnlock = Util.GetGameObject(self.transform, "bg/pageContent/page/unlockBtn")
    this.unlockCost = Util.GetGameObject(this.btnUnlock, "unlockCost")
    this.unlockCostIcon = Util.GetGameObject(this.unlockCost, "icon"):GetComponent("Image")
    this.unlockCostValue = Util.GetGameObject(this.unlockCost, "value"):GetComponent("Text")
    this.unlockDone = Util.GetGameObject(this.btnUnlock, "unlock")

    this.btnBack = Util.GetGameObject(self.transform, "bg/btnBack")

    this.bottom = Util.GetGameObject(self.transform, "bg/pageContent/bottom")
    this.btnAll = Util.GetGameObject(this.bottom, "btnAll")
    this.rpAll = Util.GetGameObject(this.bottom, "btnAll/redPoint")

    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)

    this.RewardItemList = {}
    this.lastData = nil
    for id, data in ConfigPairs(_BloodyBattleTreasure) do
        local go = newObjToParent(this.item, this.itemRoot)
        this.RewardItemList[id] = RewardItem:New(go)
        this.RewardItemList[id]:SetData(data)
        this.lastData = data
    end

    this.finalRewardItem = RewardItem:New(this.bottom)
    this.finalRewardItem:SetData(this.lastData)

end

--绑定事件（用于子类重写）
function MapFightRewardPanel:BindEvent()
    Util.AddClick(this.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        this:ClosePanel()
    end)
    --
    Util.AddClick(this.btnAll, function()
        MatchDataManager.RequestGetScoreReward(-1, function()
            this.RefreshShow()
        end)
    end)
    Util.AddClick(this.btnUnlock, function()
        UIManager.OpenPanel(UIName.MapFightBuyExtraPopup)
    end)
end

--添加事件监听（用于子类重写）
function MapFightRewardPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MapFight.ScoreRewardUpdate, this.RefreshShow)
end

--移除事件监听（用于子类重写）
function MapFightRewardPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MapFight.ScoreRewardUpdate, this.RefreshShow)
end

--界面打开时调用（用于子类重写）
function MapFightRewardPanel:OnOpen(...)

    this.RefreshShow()

    if not this.timer then
        this.timer = Timer.New(this._Update, 1, -1 , true)
        this.timer:Start()
    end
    this._Update()

    this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
end

-- 刷新一遍显示
function this.RefreshShow()
    local rewardData = MatchDataManager.GetScoreRewardData()
    for id, rewardItem in pairs(this.RewardItemList) do
        rewardItem:SetState(rewardData[id].status)
    end

    this.RefreshFinalReward()

    this.curScore.text = MatchDataManager.GetRewardScore()

    -- 刷新额外奖励显示
    local isBuyExtra = MatchDataManager.IsBuyExtra()
    this.btnUnlock:SetActive(not isBuyExtra)
    if not isBuyExtra then
        -- 购买令牌消耗
        local BloodyBattleSetting = ConfigManager.GetConfigData(ConfigName.BloodyBattleSetting, 1)
        local costId, costNum = BloodyBattleSetting.Price[1], BloodyBattleSetting.Price[2]
        this.unlockCostIcon.sprite = SetIcon(costId)
        this.unlockCostValue.text = costNum
    end
end

--
function this._Update()
    -- 定时器清除后，仍然会调用一次
    local serData = ActTimeCtrlManager.GetSerDataByTypeId(47)
    local endTime = serData.endTime
    local curTime = GetTimeStamp()
    if curTime > endTime then
        this.remainTime.text = ""
    else
        this.remainTime.text = TimeToDHMS(endTime - curTime)
    end
end

-- 刷新最终奖励显示
function this.RefreshFinalReward()
    local lastData = MatchDataManager.GetFinalScoreRewardData()
    this.finalRewardItem:SetState(lastData.status)
    this.finalRewardItem.score.text = GetLanguageStrById(10754)
    this.finalRewardItem.btnDeal:SetActive(false)
    this.finalRewardItem.finished:SetActive(lastData.status == MAP_FIGHT_REWARD_STATE.FINISH)
    this.btnAll:SetActive(lastData.status ~= MAP_FIGHT_REWARD_STATE.FINISH)
    local isCanGet = MatchDataManager.HasCanGetScoreReward()
    Util.SetGray(this.btnAll, not isCanGet)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function MapFightRewardPanel:OnShow()
    this.RefreshShow()
end

--界面关闭时调用（用于子类重写）
function MapFightRewardPanel:OnClose()
end

--界面销毁时调用（用于子类重写）
function MapFightRewardPanel:OnDestroy()
    for _, rewardItem in pairs(this.RewardItemList) do
        rewardItem:Recycle()
    end
    this.RewardItemList = {}

    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end

    SubUIManager.Close(this.UpView)
end

return MapFightRewardPanel