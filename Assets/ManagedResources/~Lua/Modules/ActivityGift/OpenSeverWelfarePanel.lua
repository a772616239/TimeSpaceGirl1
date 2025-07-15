require("Base/BasePanel")
OpenSeverWelfarePanel = Inherit(BasePanel)
local this = OpenSeverWelfarePanel
local activityRewardConfig = ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)
local sortingOrder
local isFirstOn = true--是否首次打开页面

--初始化组件（用于子类重写）
function OpenSeverWelfarePanel:InitComponent()
    this.closeBtn = Util.GetGameObject(self.transform, "closeBtn")
    this.titleText = Util.GetGameObject(self.transform, "BG/Text"):GetComponent("Text")
    this.timeText = Util.GetGameObject(self.transform, "timeText"):GetComponent("Text")
    this.timeTextGo = Util.GetGameObject(self.transform, "timeText")
    this.rewardPre = Util.GetGameObject(self.gameObject, "rewardPre")
    local v = Util.GetGameObject(self.gameObject, "rect"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "rect").transform,
            this.rewardPre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,10))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.NoviceItemList = {}--存储itemview 重复利用
end

--绑定事件（用于子类重写）
function OpenSeverWelfarePanel:BindEvent()
    Util.AddClick(this.closeBtn, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function OpenSeverWelfarePanel:AddListener()
end

--移除事件监听（用于子类重写）
function OpenSeverWelfarePanel:RemoveListener()
end

--界面打开时调用（用于子类重写）
function OpenSeverWelfarePanel:OnOpen(...)

end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function OpenSeverWelfarePanel:OnShow()
    isFirstOn = true
    this.OnShowPanelData()
end
function OpenSeverWelfarePanel:OnSortingOrderChange()
    sortingOrder = self.sortingOrder
    for i, v in pairs(this.NoviceItemList) do
        for j = 1, #this.NoviceItemList[i] do
            if this.NoviceItemList[i][j] and this.NoviceItemList[i][j].gameObject then
                this.NoviceItemList[i][j]:SetEffectLayer(self.sortingOrder)
            end
        end
    end
end
local isShowNeedGetUpTextId = 0
local activityData = {}

function this.OnShowPanelData()
    this.titleText.text = GetLanguageStrById(10026)
    activityData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.OpenSeverWelfare)
    isShowNeedGetUpTextId = 0

    local allActivity = {}
    if activityData then
        this.RemainTimeDown(this.timeTextGo,this.timeText,activityData.endTime - GetTimeStamp())
        ActivityGiftManager.OpenSeverWelfareRewardTabsSort(activityData.mission)
        this.ScrollView:SetData(activityData.mission, function (index, go)
            this.SingleDataShow(go, activityData.mission[index])
            allActivity[index] = go
        end)
    end

    if isFirstOn then
        isFirstOn = false
        DelayCreation(allActivity)
    end
end

function this.SingleDataShow(go,rewardData)
    local activityRewardGo = go
    -- activityRewardGo:SetActive(true)
    local sConFigData = activityRewardConfig[rewardData.missionId]
    local titleText = Util.GetGameObject(activityRewardGo, "titleImage/titleText"):GetComponent("Text")
    titleText.text = GetLanguageStrById(sConFigData.ContentsShow)
    local itemGroup = Util.GetGameObject(activityRewardGo, "content")
    --滚动条复用重设itemview
    if this.NoviceItemList[go] then
        for i = 1, 4 do
            this.NoviceItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #sConFigData.Reward do
            if this.NoviceItemList[go][i] then
                this.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.65,false,false,true,sortingOrder)
                this.NoviceItemList[go][i].gameObject:SetActive(true)
            end
        end
    else
        this.NoviceItemList[go] = {}
        for i = 1, 4 do
            this.NoviceItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
            this.NoviceItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #sConFigData.Reward do
            this.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.65,false,false,true,sortingOrder)
            this.NoviceItemList[go][i].gameObject:SetActive(true)
        end
    end
    local lingquButton = Util.GetGameObject(activityRewardGo.gameObject, "lingquButton")
    Util.GetGameObject(lingquButton.gameObject, "redPoint"):SetActive(false)
    local qianwangButton = Util.GetGameObject(activityRewardGo.gameObject, "qianwangButton")
    local getFinishText = Util.GetGameObject(activityRewardGo.gameObject, "getFinishText")
    local getRewardProgress = Util.GetGameObject(activityRewardGo.gameObject, "getRewardProgress")
    local needGetUpText = Util.GetGameObject(activityRewardGo.gameObject, "needGetUpText")
    local state = rewardData.state
    local value = sConFigData.Values[1][1]
    local isPass = FightPointPassManager.IsFightPointPass(value)
    lingquButton:SetActive(state == 0 and isPass)
    qianwangButton:SetActive(state == 0 and not isPass)
    getFinishText:SetActive(state == 1)
    needGetUpText:SetActive(state == 0)
    if isShowNeedGetUpTextId == 0 and state == 0 or isShowNeedGetUpTextId == rewardData.missionId then
        isShowNeedGetUpTextId = rewardData.missionId
        needGetUpText:SetActive(false)
    end
    getRewardProgress:SetActive(state == 0)
    if state == 0 and isPass then
        getRewardProgress:GetComponent("Text").text = "(1/1)"
    else
        getRewardProgress:GetComponent("Text").text = "(0/1)"
    end
    Util.AddOnceClick(qianwangButton, function()
        if sConFigData.Jump then
            JumpManager.GoJump(sConFigData.Jump[1])
        end
    end)
    Util.AddOnceClick(lingquButton, function()
        if isShowNeedGetUpTextId ~= rewardData.missionId then
            PopupTipPanel.ShowTipByLanguageId(10027)
            return
        end
        NetManager.GetActivityRewardRequest(rewardData.missionId, activityData.activityId,  function(drop)
        --ActivityGiftManager.GetActivityRewardRequest(ActivityTypeDef.OpenSeverWelfare,rewardData.missionId,  function(msg)
            local rewardItemPopup = UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                this.OnShowPanelData()
                Game.GlobalEvent:DispatchEvent(GameEvent.Mission.GetOpenServerRewardRefreshFightPoint)
            end)
            --获得英雄表现
            if drop.Hero ~= nil and #drop.Hero > 0 then
                local itemDataList = {}
                local itemDataStarList = {}
                rewardItemPopup.gameObject:SetActive(false)
                this.gameObject:SetActive(false)
                local box = Util.GetGameObject(this.gameObject.transform.parent,"FightPointPassMainPanel/Bg/getBoxReward")
                box:SetActive(false)
                for i = 1, #drop.Hero do
                    local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", drop.Hero[i].heroId)
                    table.insert(itemDataList, heroData)
                    table.insert(itemDataStarList, drop.Hero[i].star)
                end
                UIManager.OpenPanel(UIName.PublicGetHeroPanel,itemDataList,itemDataStarList,function ()
                    box:SetActive(true)
                    this.gameObject:SetActive(true)
                    rewardItemPopup.gameObject:SetActive(true)
                end)
            end
        end)
    end)
end
this.timer = Timer.New()
--刷新倒计时显示
function this.RemainTimeDown(_timeTextExpertgo,_timeTextExpert,timeDown)
    if timeDown > 0 then
        if _timeTextExpertgo then
            _timeTextExpertgo:SetActive(true)
        end
        if _timeTextExpert then
            _timeTextExpert.text =   GetLanguageStrById(50012)..GetLeftTimeStrByDeltaTime2(timeDown)
        end
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            if _timeTextExpert then
                _timeTextExpert.text =   GetLanguageStrById(50012)..GetLeftTimeStrByDeltaTime2(timeDown)
            end
            if timeDown < 0 then
                if _timeTextExpertgo then
                    _timeTextExpertgo:SetActive(false)
                end
                this.timer:Stop()
                this.timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        if _timeTextExpertgo then
            _timeTextExpertgo:SetActive(false)
        end
    end
end

--界面关闭时调用（用于子类重写）
function OpenSeverWelfarePanel:OnClose()
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function OpenSeverWelfarePanel:OnDestroy()
end

return OpenSeverWelfarePanel