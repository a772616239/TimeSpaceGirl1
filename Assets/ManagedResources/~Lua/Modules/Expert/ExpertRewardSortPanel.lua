require("Base/BasePanel")
ExpertRewardSortPanel = Inherit(BasePanel)
local itemConfig = ConfigManager.GetConfig(ConfigName.ItemConfig)
local this = ExpertRewardSortPanel
local activeId = 0
local type = 0
local activityType = 0  --活动类型
local expertSortDataTabs = {}--排行
local expertRewardSortTabs = {}--排行奖励
-- 头像对象管理
local _PlayerHeadList = {}
--初始化组件（用于子类重写）
function ExpertRewardSortPanel:InitComponent()
    self.btnBack = Util.GetGameObject(self.gameObject, "btnBack")

    --排名
    -- self.titleTextExpert = Util.GetGameObject(self.gameObject, "Title"):GetComponent("Text")
    self.content2 = Util.GetGameObject(self.gameObject, "content2")
    self.myRank = Util.GetGameObject(self.gameObject, "content2/bottom/info/myRank"):GetComponent("Text")
    self.myValue = Util.GetGameObject(self.gameObject, "content2/bottom/info/myValue"):GetComponent("Text")
    self.sortPre = Util.GetGameObject(self.gameObject, "content2/item")
    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(self.gameObject, "content2/scrollRect").transform,
            self.sortPre, nil, Vector2.New(916, 1124.7), 1, 1, Vector2.New(15, 0))
    self.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 1

    --奖励
    self.content3 = Util.GetGameObject(self.gameObject, "content3")
    self.expertRewardSortGrid = Util.GetGameObject(self.gameObject, "content3/scrollRect/grid")
    self.expertRewardSortPre = Util.GetGameObject(self.gameObject, "content3/item")
    for i = 1, 1 do
        expertRewardSortTabs[i] = Util.GetGameObject(self.gameObject, "content3/scrollRect/grid/item")
    end
    this.myActivityRewardGo = Util.GetGameObject(self.gameObject, "content3/Record")
end

--绑定事件（用于子类重写）
function ExpertRewardSortPanel:BindEvent()
    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
end

--添加事件监听（用于子类重写）
function ExpertRewardSortPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.RankingList.OnGoldExperSortChange,this.SetGoldExperSortInfo)
end

--移除事件监听（用于子类重写）
function ExpertRewardSortPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.RankingList.OnGoldExperSortChange,this.SetGoldExperSortInfo)
end

--界面打开时调用（用于子类重写）
function ExpertRewardSortPanel:OnOpen(_activeId,_type, _activityType)
    RankingManager.ClearData()
    activeId = _activeId
    type = _type
    activityType = _activityType
    --设置信息方法的列表
    this.SetInfoFuncList = {
        [FUNCTION_OPEN_TYPE.EXPERT] = this.SetGoldExperSortInfo,
    }
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function ExpertRewardSortPanel:OnShow()
    if type == 1 then
        self.content2:SetActive(true)
        self.content3:SetActive(false)
        self:OnShowExperSort()
        local conFigData = ConfigManager.GetConfigData(ConfigName.GlobalActivity,activeId)
        if  conFigData then
            local ExpertDec = string.split(conFigData.ExpertDec, "#")
            -- self.titleTextExpert.text = ExpertDec[2]
        end
    else
        self.content2:SetActive(false)
        self.content3:SetActive(true)
        self:ActivitySortRewardShow()
        -- self.titleTextExpert.text = GetLanguageStrById(10531)
    end
end

--排名
function ExpertRewardSortPanel:OnShowExperSort()
    NetManager.RequestGetExpertInfoData(activeId, function (msg)
        expertSortDataTabs = msg
        self.myValue.text = expertSortDataTabs.myScore
        if expertSortDataTabs.myRank <= 0 then
            self.myRank.text = GetLanguageStrById(10041)
        else
            self.myRank.text = expertSortDataTabs.myRank
        end

        self.ScrollView:SetData(expertSortDataTabs.expert, function (index, go)
            self:OnShowSingleExperSort(go, expertSortDataTabs.expert[index])
        end)
    end)
end
--排名2
function ExpertRewardSortPanel:OnShowSingleExperSort(activityRewardGo,sortData)
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(activityRewardGo, "sortNum/sortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if sortData.rank < 4 then
        sortNumTabs[sortData.rank]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        Util.GetGameObject(sortNumTabs[4], "rankNumberText"):GetComponent("Text").text = sortData.rank
    end
    --Util.GetGameObject(activityRewardGo, "userHeadQuality/Image/levelText"):GetComponent("Text").text = sortData.level
    Util.GetGameObject(activityRewardGo, "userNameText"):GetComponent("Text").text = sortData.name
    Util.GetGameObject(activityRewardGo, "injuryNumber"):GetComponent("Text").text = sortData.score
    local head = Util.GetGameObject(activityRewardGo, "userHeadQuality")
    if not _PlayerHeadList[activityRewardGo] then
        _PlayerHeadList[activityRewardGo] = SubUIManager.Open(SubUIConfig.PlayerHeadView, head.transform)
    end
    _PlayerHeadList[activityRewardGo]:Reset()
    _PlayerHeadList[activityRewardGo]:SetHead(sortData.head)
    _PlayerHeadList[activityRewardGo]:SetFrame(sortData.headFrame)
    _PlayerHeadList[activityRewardGo]:SetScale(Vector3.one * 0.63)
    _PlayerHeadList[activityRewardGo]:SetLevel(sortData.level)

end

--排名奖励1
function ExpertRewardSortPanel:ActivitySortRewardShow()
    local rewardTabs = {}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ActivityRankingReward)) do
        if v.ActivityId == activeId then
            table.insert(rewardTabs,v)
        end
    end
    for i = 1, math.max(#rewardTabs, #expertRewardSortTabs) do
        local go = expertRewardSortTabs[i]
        if not go then
            go = newObject(expertRewardSortTabs[1])
            go.transform:SetParent(self.expertRewardSortGrid.transform)
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            expertRewardSortTabs[i] = go
        end
        go.gameObject:SetActive(false)
    end
    for i = 1, #rewardTabs do
        self:ActivityRewardSingleShow(expertRewardSortTabs[i],rewardTabs[i])
    end
    --
    --RankingManager.InitData(type, this.SetInfoFuncList[RankKingList[5].Id], activeId)--算是半个策略模式吧
end
function this.SetGoldExperSortInfo()
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(this.myActivityRewardGo, "SortNum/SortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    local data,myData = RankingManager.GetGoldExperSortInfo()
    local rewardData = nil
    if not myData.myRank or myData.myRank < 0 then
        sortNumTabs[4]:SetActive(true)
        Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = GetLanguageStrById(10041)
    else
        rewardData = {}
        for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ActivityRankingReward)) do
            if v.ActivityId == activeId then
                if  myData.myRank >= v.MinRank and  myData.myRank <= v.MaxRank then
                    rewardData = v
                end
            end
        end
        if rewardData.MinRank == rewardData.MaxRank then
            if rewardData.MaxRank < 4 then
                sortNumTabs[rewardData.MinRank]:SetActive(true)
            else
                sortNumTabs[4]:SetActive(true)
                Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rewardData.MaxRank
            end
        else
            sortNumTabs[4]:SetActive(true)
            if rewardData.MaxRank < 0 then
                Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rewardData.MinRank .."+"
            else
                Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rewardData.MinRank .."-".. rewardData.MaxRank
            end
        end
        local content = Util.GetGameObject(this.myActivityRewardGo, "Demons")
        -- Util.ClearChild(content.transform)
        for i = 1, #rewardData.RankingReward do
            -- SubUIManager.Open(SubUIConfig.ItemView, content.transform):OnOpen(false,rewardData.RankingReward[i],0.55)
            Util.GetGameObject(content,"Item"..i):SetActive(true)
            Util.GetGameObject(content,"Item"..i):GetComponent("Image").sprite = Util.LoadSprite(GetQuantityImageByquality(itemConfig[rewardData.RankingReward[i][1]].Quantity))
            Util.GetGameObject(content,"Item"..i .. "/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetResourcePath(itemConfig[rewardData.RankingReward[i][1]].ResourceID))
            Util.GetGameObject(content,"Item"..i .. "/Text"):GetComponent("Text").text = rewardData.RankingReward[i][2]
        end
    end
end

--排名奖励2
function ExpertRewardSortPanel:ActivityRewardSingleShow(activityRewardGo,rewardData)
    activityRewardGo:SetActive(true)
    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(activityRewardGo, "SortNum/SortNum"..i)
        sortNumTabs[i]:SetActive(false)
    end
    if rewardData.MinRank == rewardData.MaxRank then
        if rewardData.MaxRank < 4 then
            sortNumTabs[rewardData.MinRank]:SetActive(true)
        else
            sortNumTabs[4]:SetActive(true)
            Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rewardData.MaxRank
        end
    else
        sortNumTabs[4]:SetActive(true)
        if rewardData.MaxRank < 0 then
            Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rewardData.MinRank .."+"
        else
            Util.GetGameObject(sortNumTabs[4], "TitleText"):GetComponent("Text").text = rewardData.MinRank .."~".. rewardData.MaxRank
        end
    end
    local content = Util.GetGameObject(activityRewardGo, "content")
    Util.ClearChild(content.transform)
    for i = 1, #rewardData.RankingReward do
        SubUIManager.Open(SubUIConfig.ItemView, content.transform):OnOpen(false,rewardData.RankingReward[i],0.7)
    end
end
--界面关闭时调用（用于子类重写）
function ExpertRewardSortPanel:OnClose()
    RankingManager.ClearData()
    RankingManager.isRequest = 0
end

--界面销毁时调用（用于子类重写）
function ExpertRewardSortPanel:OnDestroy()
    for _, playerHead in pairs(_PlayerHeadList) do
        playerHead:Recycle()
    end
    _PlayerHeadList = {}
    self.ScrollView = nil
    expertRewardSortTabs = {}
end

return ExpertRewardSortPanel