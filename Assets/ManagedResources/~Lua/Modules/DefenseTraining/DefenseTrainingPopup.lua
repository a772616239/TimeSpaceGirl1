require("Base/BasePanel")
DefenseTrainingPopup = Inherit(BasePanel)
local this = DefenseTrainingPopup

local DefTrainingRanking = ConfigManager.GetConfig(ConfigName.DefTrainingRanking)
local isCanClick = false

--初始化组件（用于子类重写）
function DefenseTrainingPopup:InitComponent()
    this.HeadFrameView =SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform)

    this.BackMask = Util.GetGameObject(self.gameObject, "mask")
    this.btnClose = Util.GetGameObject(self.gameObject, "Bg/btnBack")

     --获取帮助按钮
    this.HelpBtn = Util.GetGameObject(self.gameObject,"helpBtn")
    this.helpPosition = this.HelpBtn:GetComponent("RectTransform").localPosition

    this.ScrollReward = Util.GetGameObject(self.gameObject, "Bg/reward/Reward/ScrollReward")
    this.RankUserPre = Util.GetGameObject(self.gameObject, "bg/RankUserPre")
    this.RewardItem = Util.GetGameObject(self.gameObject, "Bg/reward/Reward/Item")
    local w = this.ScrollReward.transform.rect.width
    local h = this.ScrollReward.transform.rect.height
    this.scrollViewReward = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.ScrollReward.transform, this.RewardItem, nil,
            Vector2.New(w, h), 2, 1, Vector2.New(0, 0))
    this.scrollViewReward.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0,0)
    this.scrollViewReward.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.scrollViewReward.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.scrollViewReward.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.scrollViewReward.moveTween.MomentumAmount = 1
    this.scrollViewReward.moveTween.Strength = 2
    this.scrollViewReward.elastic = false

    this.detail = Util.GetGameObject(self.gameObject, "Bg/reward/detail")
    this.Stages = {}
    for i = 1, 5 do
        this.Stages[i] = Util.GetGameObject(self.gameObject, "Bg/bg/Stage" .. tostring(i))
    end

    this.repeatItemView = {}

    this.btnReset = Util.GetGameObject(self.gameObject, "Bg/btnReset/btn")
    this.btnFight = Util.GetGameObject(self.gameObject, "Bg/btnFight/btn")
    this.btnFrind = Util.GetGameObject(self.gameObject, "Bg/btnFrind/btn")
    this.btnRank = Util.GetGameObject(self.gameObject, "Bg/center/btnRank/btn")
    this.ResetFont = Util.GetGameObject(self.gameObject, "Bg/btnReset/ResetFont")
    this.alreadyPassFont = Util.GetGameObject(self.gameObject, "Bg/btnFight/alreadyPassFont"):GetComponent("Text")
    this.Ranks = {}
    for i = 1, 3 do
        this.Ranks[i] = Util.GetGameObject(self.gameObject, "Bg/center/rank" .. tostring(i))
    end

    --left
    this.personalRecordText = Util.GetGameObject(self.gameObject, "Bg/personal/Text"):GetComponent("Text")
    this.bottomleft = Util.GetGameObject(self.gameObject, "Bg/bottom/left")
    this.rankValue = Util.GetGameObject(self.gameObject, "Bg/bottom/left/rankValue")
    this.weishangbang = Util.GetGameObject(self.gameObject, "Bg/bottom/left/weishangbang")
    this.rankReward = Util.GetGameObject(self.gameObject, "Bg/bottom/left/Reward/Grid/RewardGrid")
    this.Reward = Util.GetGameObject(self.gameObject, "Bg/bottom/left/Reward")

    --right
    this.bottomright = Util.GetGameObject(self.gameObject, "Bg/bottom/right")
    this.rankValue_R = Util.GetGameObject(self.gameObject, "Bg/bottom/right/rankValue")
    this.rankReward_R = Util.GetGameObject(self.gameObject, "Bg/bottom/right/CanGetReward/Reward/Grid/RewardGrid")
    this.Reward_R = Util.GetGameObject(self.gameObject, "Bg/bottom/right/CanGetReward/Reward")
    this.Reward_GetButton = Util.GetGameObject(self.gameObject, "Bg/bottom/right/CanGetReward/getBtn")
    -- this.FirstRewardPrompt = Util.GetGameObject(self.gameObject, "Bg/bottom/right/CanGetReward/text")
    -- this.FirstRewardImage = Util.GetGameObject(self.gameObject, "Bg/bottom/right/CanGetReward/Image")
    this.CanGetReward = Util.GetGameObject(self.gameObject, "Bg/bottom/right/CanGetReward")
    -- this.AllFinished = Util.GetGameObject(self.gameObject, "Bg/bottom/right/AllFinished")

    this.itemList = {}
end

--绑定事件（用于子类重写）
function DefenseTrainingPopup:BindEvent()
    Util.AddClick(this.BackMask, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.btnClose, function()
        self:ClosePanel()
    end)

    Util.AddClick(this.detail, function()
        UIManager.OpenPanel(UIName.DefenseTrainingRewardPopup)
    end)

    Util.AddClick(this.btnReset, function()
        if BattleManager.IsInBackBattle() and BattleManager.battleType == BATTLE_TYPE.DefenseTraining then
            return
        end
        NetManager.DefTrainingHandRest(function()
            PopupTipPanel.ShowTipByLanguageId(10383)
            NetManager.DefTrainingGetInfo(function(msg)
                NetManager.GetTankListFromFriendByModuleId(1, function(msg)--拉好友英雄数据
                    DefenseTrainingManager.SetFriendSupportHeroDatas(msg)
                    NetManager.TeamInfoRequest()
                    -- NetManager.GetTankInfoOfTeam(FormationTypeDef.DEFENSE_TRAINING, function()--拉剩余血量数据
                        this:OnShow()
                    -- end)
                end)
            end)
        end)
    end)

    Util.AddClick(this.btnFight, function()
        if BattleManager.IsInBackBattle() then
            PopupTipPanel.ShowTip(GetLanguageStrById(50014))
            return
        end
        if isCanClick then
            if DefenseTrainingManager.teamLock == 1 and DefenseTrainingManager.CheckIsAllDead() then
                PopupTipPanel.ShowTipByLanguageId(12554)
            else
                isCanClick = false
                if DefenseTrainingManager.teamLock == 1 then
                    FormationManager.curFormationIndex = FormationTypeDef.DEFENSE_TRAINING
                    DefenseTrainingManager.ExecuteFightBefore()
                else
                    UIManager.OpenPanel(UIName.FormationPanelV2, FORMATION_TYPE.DefenseTraining, DefenseTrainingManager.curFightId)
                end
            end
        end
    end)
    Util.AddClick(this.btnFrind, function()
        NetManager.GetTankListFromFriendByModuleId(1, function(msg)
            DefenseTrainingManager.SetFriendSupportHeroDatas(msg)
            UIManager.OpenPanel(UIName.DefenseTrainingSupportPopup)
        end)
    end)

    Util.AddClick(this.btnRank, function()
        UIManager.OpenPanel(UIName.DefenseTrainingRankPopup)
    end)
end

function DefenseTrainingPopup.RefreshHelpBtn()
    Util.AddOnceClick(this.HelpBtn, function()
        UIManager.OpenPanel(UIName.HelpPopup,HELP_TYPE.DefenseTraining,this.helpPosition.x,this.helpPosition.y) 
    end)
end


--添加事件监听（用于子类重写）
function DefenseTrainingPopup:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.DefenseTrainingPopup.RefreshBtnClick, this.RefreshBtnClick)
end

--移除事件监听（用于子类重写）
function DefenseTrainingPopup:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.DefenseTrainingPopup.RefreshBtnClick, this.RefreshBtnClick)
end

--界面打开时调用（用于子类重写）
function DefenseTrainingPopup:OnOpen()
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function DefenseTrainingPopup:OnShow()
    this.HeadFrameView:OnShow()
    this.UpView:OnOpen({ showType = UpViewOpenType.ShowRight, panelType = PanelType.AlameinWarPanel })

    -- NetManager.TeamInfoRequest(function()
        this.FirstRewardList = DefenseTrainingManager.GetFirstRewardList()
        NetManager.GetTankInfoOfTeam(FormationTypeDef.DEFENSE_TRAINING, function()    --< 拉剩余血量数据
            isCanClick = true
        end)
        this.RefreshHelpBtn()
        self:Init()
        self:UpdateMain()
    -- end)
end

function DefenseTrainingPopup:UpdateMain()
    DefenseTrainingPopup.UpdateStageUI()
    this:UpdateRank()
    this:UpdateFirstReward()
end

function DefenseTrainingPopup:Init()
    local data = DefenseTrainingManager.GetAllRewardNoRepeatIds()
    this.scrollViewReward:SetData(data, function(index, root)
        self:FillReward(root, data[index])
    end)
end

function DefenseTrainingPopup:FillReward(root, data)
    if not this.repeatItemView[root] then
        this.repeatItemView[root] = SubUIManager.Open(SubUIConfig.ItemView, root.transform)
    end

    this.repeatItemView[root]:OnOpen(false, {data, 0}, 0.7, nil, nil, nil, nil, nil)
end

function DefenseTrainingPopup.UpdateStageUI()
    local needFightId = DefenseTrainingManager.curFightId
    local maxNeedFightId = DefenseTrainingManager.maxLastFinishedId + 1

    local fiveNum = needFightId % 5
    fiveNum = fiveNum == 0 and 5 or fiveNum
    local originStageId = needFightId - (fiveNum - 1)
    local tempOriginStageId = originStageId
    for i = 1, 5 do
        local StageGo = this.Stages[i]
        -- Util.GetGameObject(StageGo, "stage/StageText"):GetComponent("Text").text = GetLanguageStrById(10311) .. tostring(tempOriginStageId) .. GetLanguageStrById(10622)
        Util.GetGameObject(StageGo, "stage/StageText"):GetComponent("Text").text = string.format(GetLanguageStrById(10484),tostring(tempOriginStageId))
        -- local buff = Util.GetGameObject(StageGo, "buff")
        -- buff:SetActive(false)
        -- if DefenseTrainingManager.todayStartFightId%5 == tempOriginStageId%5 then
        --     buff:SetActive(true)
        -- end
        local status = {}
        for i = 1, 4 do
            status[i] = Util.GetGameObject(StageGo, "status" .. tostring(i))
            status[i]:SetActive(false)
        end

        Util.GetGameObject(StageGo, "stage/StageText"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,255/255)
        --关卡状态显示优先度1>2>4>3
        if tempOriginStageId < needFightId then
            --完成
            status[1]:SetActive(true)
        elseif tempOriginStageId == needFightId then
            --攻击
            status[2]:SetActive(true)
        elseif tempOriginStageId >= maxNeedFightId then
            --未解锁
            status[4]:SetActive(true)
            Util.GetGameObject(StageGo, "stage/StageText"):GetComponent("Text").color = Color.New(255/255,255/255,255/255,153/255)
        else
            --未挑战
            status[3]:SetActive(true)
        end
        tempOriginStageId = tempOriginStageId + 1
    end

    --> 个人记录
    this.personalRecordText.text = string.format(GetLanguageStrById(10484), DefenseTrainingManager.maxLastFinishedId)

    --> 今日已通
    this.alreadyPassFont.text = string.format(GetLanguageStrById(12558), DefenseTrainingManager.todayPassCount)

    local fight
    if DefenseTrainingManager.maxLastFinishedId > 0 and DefenseTrainingManager.todayStartFightId > 1 then
        fight = DefenseTrainingManager.todayStartFightId
    else
        fight = DefenseTrainingManager.maxLastFinishedId - 9
    end
    if fight < 1 then fight = 1 end
    this.ResetFont:GetComponent("Text").text = fight .. GetLanguageStrById(10622)--string.format(GetLanguageStrById(12553), DefenseTrainingManager.todayStartFightId)
end

function DefenseTrainingPopup:UpdateRank()
    for i = 1, #this.Ranks do
        this.Ranks[i]:SetActive(false)
    end
    DefenseTrainingManager.UpdateRankingData(function()
        this:UpdateRankUI()
        this:UpdateRankReward()
    end)
end

function DefenseTrainingPopup:UpdateRankUI()
    for k, v in ipairs(DefenseTrainingManager.ranks) do
        if k > 3 then
            break
        else
            local rankGo = this.Ranks[k]
            rankGo:SetActive(true)

            Util.GetGameObject(rankGo, "name"):GetComponent("Text").text = v.userName
            Util.GetGameObject(rankGo, "guanqia"):GetComponent("Text").text = v.rankInfo.param1 .. GetLanguageStrById(10622)
        end
    end
end

function DefenseTrainingPopup:UpdateRankReward()
    this.rankValue:SetActive(false)
    this.weishangbang:SetActive(false)
    this.Reward:SetActive(false)
    if DefenseTrainingManager.myRankInfo and DefenseTrainingManager.myRankInfo.rank ~= -1 then
        this.rankValue:SetActive(true)
        this.rankValue:GetComponent("Text").text = "(" .. GetLanguageStrById(10030) .. ": " .. DefenseTrainingManager.myRankInfo.rank .. ")"

        --> reward
        local allConfigData = ConfigManager.GetAllConfigsData(ConfigName.DefTrainingRanking)
        table.sort(allConfigData, function(a, b)
            return a.Id < b.Id
        end)
        local rewardId = nil
        for i = 1, #allConfigData do
            if DefenseTrainingManager.myRankInfo.rank >= allConfigData[i].RankingMin and DefenseTrainingManager.myRankInfo.rank <= allConfigData[i].RankingMax then
                rewardId = allConfigData[i].Id
            end
        end
        if rewardId then
            this.Reward:SetActive(true)
            DefenseTrainingPopup:RewardCommon(1, this.rankReward, DefTrainingRanking[rewardId].RankingAward)
        end
    else
        this.weishangbang:SetActive(true)
    end

end

function DefenseTrainingPopup:UpdateFirstReward()
    this.CanGetReward:SetActive(false)
    this.rankValue_R:SetActive(false)
    this.Reward_GetButton:SetActive(false)
    if DefenseTrainingManager.firstAwardedProgress >= this.FirstRewardList[#this.FirstRewardList].Id then

    else
        this.CanGetReward:SetActive(true)
        this.rankValue_R:SetActive(true)

        local getFirstRewardConfigData = nil        --< 首通奖励可领取关表数据
        local noGetFirstRewardConfigData = nil      --< 首通奖励即将领取关表数据
        for k, v in ipairs(this.FirstRewardList) do
            if DefenseTrainingManager.maxLastFinishedId >= v.Id and DefenseTrainingManager.firstAwardedProgress < v.Id then
                getFirstRewardConfigData = v
                break
            end
        end
        for k, v in ipairs(this.FirstRewardList) do
            if DefenseTrainingManager.maxLastFinishedId < v.Id then
                noGetFirstRewardConfigData = v
                break
            end
        end
        if getFirstRewardConfigData then
            --可领
            this.Reward_GetButton:SetActive(true)

            Util.AddOnceClick(this.Reward_GetButton, function()
                NetManager.DefTrainingGetFirstAward(getFirstRewardConfigData.Id, function(msg)
                    if msg.drop then
                        UIManager.OpenPanel(UIName.RewardItemPopup, msg.drop, 1)
                    end

                    NetManager.DefTrainingGetInfo(function(msg) --< 拉数据
                        this:UpdateFirstReward()
                    end)
                end)
            end)

            this.rankValue_R:GetComponent("Text").text = " （" .. GetLanguageStrById(10311) .. getFirstRewardConfigData.Id .. GetLanguageStrById(10622) .. "）"

            DefenseTrainingPopup:RewardCommon(2, this.rankReward_R, {[1] = getFirstRewardConfigData.FirstAward})
        else
            --无可领
            this.rankValue_R:GetComponent("Text").text = " (" .. string.format(GetLanguageStrById(10484),noGetFirstRewardConfigData.Id) .. ")"

            local afterCanGetNum = math.max(noGetFirstRewardConfigData.Id - DefenseTrainingManager.maxLastFinishedId, 0)
            -- this.FirstRewardPrompt:GetComponent("Text").text = string.format(GetLanguageStrById(12559), afterCanGetNum)

            DefenseTrainingPopup:RewardCommon(2, this.rankReward_R, {[1]=noGetFirstRewardConfigData.FirstAward})
        end
    end
end

function DefenseTrainingPopup:RewardCommon(listId, rewardGo, rewardConfig)
    if this.itemList[listId] == nil then
        this.itemList[listId] = {}
        for i = 1, 4 do--目前最多支持四个item
            this.itemList[listId][i] = SubUIManager.Open(SubUIConfig.ItemView, rewardGo.transform)
        end
    end
 
    local itemData = rewardConfig
    for i = 1, 4 do
        local ItemView = this.itemList[listId][i]
        if i <= #itemData then
            ItemView.gameObject:SetActive(true)
            ItemView:OnOpen(false, {itemData[i][1], itemData[i][2]}, 0.55, nil, nil, nil, nil, nil)
        else
            ItemView.gameObject:SetActive(false)
        end
    end
end

--界面关闭时调用（用于子类重写）
function DefenseTrainingPopup:OnClose()
end

--界面销毁时调用（用于子类重写）
function DefenseTrainingPopup:OnDestroy()
    SubUIManager.Close(this.HeadFrameView)
    SubUIManager.Close(this.UpView)

    this.repeatItemView = {}
    this.itemList = {}
end

function this.RefreshBtnClick()
   isCanClick = true 
end

return DefenseTrainingPopup