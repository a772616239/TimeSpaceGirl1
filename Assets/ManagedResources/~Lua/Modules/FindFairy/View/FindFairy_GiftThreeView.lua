----- 东海寻仙-进阶 -----
local this = {}
local sortingOrder = 0
local rewardGrid = {}
local rewardItemsGrid = {}
local activeData
function this:InitComponent(gameObject)
    this.gameObject = gameObject
    this.titleInfoText1 = Util.GetGameObject(gameObject, "Panel/Bg/Image/Text")
    this.titleInfoText2 = Util.GetGameObject(gameObject, "Panel/Bg/Image/Text (1)")
    this.live2dRoot=Util.GetGameObject(gameObject,"Panel/Live")
    this.timeTextGo = Util.GetGameObject(gameObject, "Panel/timeText")
    this.timeText = Util.GetGameObject(gameObject, "Panel/timeText"):GetComponent("Text")
    for i = 1, 5 do
        rewardGrid[i] = Util.GetGameObject(gameObject, "Panel/rect/rect (1)/grid/rewardPre ("..i..")")
        local curexpertRewardItemsGri = {}
        for j = 1, 4 do
            curexpertRewardItemsGri[j] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(rewardGrid[i], "content").transform)
        end
        rewardItemsGrid[i] = curexpertRewardItemsGri
    end
end

function this:BindEvent()

end

function this:AddListener()

end

function this:RemoveListener()

end

function this:OnShow(_sortingOrder)
    sortingOrder = _sortingOrder
    self:OnShowPanelData()
end

function this:OnShowPanelData()
    activeData = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.FindFairyUpStar)
    local globalActivity = ConfigManager.GetConfigData(ConfigName.GlobalActivity,activeData.activityId )
    if globalActivity == nil or activeData == nil then return end
    for i = 1, math.max(#activeData.mission, #rewardGrid) do
        local go = rewardGrid[i]
        if not go then
            go = newObject(rewardGrid[1])
            go.transform:SetParent(this.expertRewardGridGo.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            rewardGrid[i] = go
        end
        go.gameObject:SetActive(false)
    end
    if  globalActivity then
        local strDec = string.split(globalActivity.ExpertDec, "#")
        if globalActivity.ExpertDec then
            this.titleInfoText1:SetActive(true)
            this.titleInfoText2:SetActive(true)
            this.titleInfoText1:GetComponent("Text").text = strDec[1]
            this.titleInfoText2:GetComponent("Text").text = strDec[2]
        else
            this.titleInfoText1:SetActive(false)
            this.titleInfoText2:SetActive(false)
        end
    end
    if not activeData.mission[1] then return end
    local sConFigData = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig,activeData.mission[1].missionId)
    local sConFigHeroData = ConfigManager.GetConfigData(ConfigName.HeroConfig,sConFigData.Values[1][1])
    this.LiveName = GetResourcePath(sConFigHeroData.Live)
    this.LiveGO = poolManager:LoadLive(this.LiveName, this.live2dRoot.transform,
            Vector3.one * sConFigHeroData.Scale, Vector3.New(sConFigHeroData.Position[1],sConFigHeroData.Position[2],0))
    self:RemainTimeDown(this.timeTextGo,this.timeText,activeData.endTime - GetTimeStamp())
    self:ActivityRewardSingleSort(activeData.mission)
    for i = 1, #activeData.mission do
        self:ActivityRewardSingleShow(i,activeData.mission[i])
    end
end
--活动奖励2
function this:ActivityRewardSingleShow(index,rewardData)
    local activityRewardGo = rewardGrid[index]
    activityRewardGo:SetActive(true)
    local sConFigData = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig,rewardData.missionId)
    local titleText = Util.GetGameObject(activityRewardGo, "titleImage/titleText"):GetComponent("Text")
    titleText.text = sConFigData.ContentsShow
    local content = Util.GetGameObject(activityRewardGo, "content")
    for i = 1, math.max(#sConFigData.Reward, #rewardItemsGrid[index]) do
        local go = rewardItemsGrid[index][i]
        if not go then
            go = SubUIManager.Open(SubUIConfig.ItemView, content.transform)
            rewardItemsGrid[index][i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #sConFigData.Reward do
        rewardItemsGrid[index][i].gameObject:SetActive(true)
        rewardItemsGrid[index][i]:OnOpen(false,sConFigData.Reward[i],0.9,false,false,false,sortingOrder)
    end

    local lingquButton = Util.GetGameObject(activityRewardGo.gameObject, "lingquButton")
    Util.GetGameObject(lingquButton.gameObject, "redPoint"):SetActive(false)
    local qianwangButton = Util.GetGameObject(activityRewardGo.gameObject, "qianwangButton")
    local getFinishText = Util.GetGameObject(activityRewardGo.gameObject, "getFinishText")
    local getRewardProgress = Util.GetGameObject(activityRewardGo.gameObject, "getRewardProgress")
    getRewardProgress:SetActive(false)
    local state = rewardData.state
    local value = sConFigData.Values[2][1]
    lingquButton:SetActive(state == 0 and rewardData.progress >= value)
    qianwangButton:SetActive(state == 0 and rewardData.progress < value)
    getFinishText:SetActive(state == 1)
    --getRewardProgress:SetActive(state == 10)
    --getRewardProgress:GetComponent("Text").text = rewardData.progress .."/"..value
    Util.AddOnceClick(qianwangButton, function()
        JumpManager.GoJump(sConFigData.Jump[1])
    end)
    Util.AddOnceClick(lingquButton, function()

        NetManager.GetActivityRewardRequest(rewardData.missionId, activeData.activityId, function(drop)
            UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
                self:OnShowPanelData()
            end)
        end)
    end)
end
--排序
function this:ActivityRewardSingleSort(mission)
    table.sort(mission, function(a,b)
        if a.state == b.state then
            return a.missionId < b.missionId
        else
            return self:SortFun(a) < self:SortFun(b)
        end
    end)
end
--state任务状态，0：未领奖，1：已领奖
function this:SortFun(mission)
    if mission.state == 1 then
        return 3--已领奖
    else
        local sConFigData = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig,mission.missionId)
        local value = sConFigData.Values[2][1]
        if mission.state == 0 and mission.progress >= value then
            return 1--可领奖
        else
            return 2--未达成
        end
    end
end

this.timer = Timer.New()
--刷新倒计时显示
function this:RemainTimeDown(_timeTextExpertgo,_timeTextExpert,timeDown)
    if timeDown > 0 then
        _timeTextExpertgo:SetActive(true)
        _timeTextExpert.text =   GetLanguageStrById(10028)..self:TimeStampToDateString(timeDown)
        if this.timer then
            this.timer:Stop()
            this.timer = nil
        end
        this.timer = Timer.New(function()
            _timeTextExpert.text =   GetLanguageStrById(10028)..self:TimeStampToDateString(timeDown)
            if timeDown < 0 then
                _timeTextExpertgo:SetActive(false)
                this.timer:Stop()
                this.timer = nil
                -- PopupTipPanel.ShowTip("活动已结束！")
                -- require("Modules/FindFairy/FindFairyPanel"):OnShow()
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        this.timer:Start()
    else
        _timeTextExpertgo:SetActive(false)
    end
end

function this:TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(10548),day, hour, minute, sec)
end

function this:OnClose()
    if this.LiveName then
        poolManager:UnLoadLive(this.LiveName, this.LiveGO)
        this.LiveName = nil
    end
    if this.timer then
        this.timer:Stop()
        this.timer = nil
    end
end

function this:OnDestroy()

end

return this