require("Base/BasePanel")
WarPowerSortPanel = Inherit(BasePanel)
local activityRewardGrid = {}
local activityRewardGridItemView = {}
local warPowerRewardGrid = {}
local warPowerRewardGridItemView = {}
local tabsBtn = {}
local WarPowerRewardTabs = {}
local page = 1

local warPowerSortbackData = {}
local myWarPower = 0
local myWarPowerSortNum = 0

local heroSId = 0
--初始化组件（用于子类重写）
function WarPowerSortPanel:InitComponent()

    self.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    self.heroIcon = Util.GetGameObject(self.gameObject, "downGo/heroInfoBtn/heroIcon"):GetComponent("Image")
    self.activityRewardGo = Util.GetGameObject(self.gameObject, "downGo/activityRewardGo")
    self.activityRewardGridGo = Util.GetGameObject(self.gameObject, "downGo/activityRewardGo/rect/rect (1)/grid")
    self.activityRewardPre = Util.GetGameObject(self.gameObject, "downGo/activityRewardGo/rewardPre")

    self.timeTextActivityRewardGo = Util.GetGameObject(self.gameObject, "downGo/activityRewardGo/timeText")
    self.timeTextActivityReward = Util.GetGameObject(self.gameObject, "downGo/activityRewardGo/timeText/timeText"):GetComponent("Text")
    self.timeTextWarPowerRewardGo = Util.GetGameObject(self.gameObject, "downGo/warPowerRewardGo/timeText")
    self.timeTextWarPowerReward = Util.GetGameObject(self.gameObject, "downGo/warPowerRewardGo/timeText/timeText"):GetComponent("Text")

    self.warPowerRewardGo = Util.GetGameObject(self.gameObject, "downGo/warPowerRewardGo")
    self.warPowerRewardGridGo = Util.GetGameObject(self.gameObject, "downGo/warPowerRewardGo/rect/rect (1)/grid")
    self.warPowerRewardPre = Util.GetGameObject(self.gameObject, "downGo/warPowerRewardGo/rewardPre")
    activityRewardGrid = {}
    warPowerRewardGrid = {}
    activityRewardGridItemView = {}
    warPowerRewardGridItemView = {}
    for i = 1, 5 do
        activityRewardGrid[i] = Util.GetGameObject(self.activityRewardGo, "rect/rect (1)/grid/rewardPre ("..i..")")
        warPowerRewardGrid[i] = Util.GetGameObject(self.warPowerRewardGo, "rect/rect (1)/grid/rewardPre ("..i..")")
        activityRewardGridItemView[i] = {}
        warPowerRewardGridItemView[i] = {}
        for j = 1, 3 do --初始缓存3个
            activityRewardGridItemView[i][j] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(activityRewardGrid[i], "content").transform)
            warPowerRewardGridItemView[i][j] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(warPowerRewardGrid[i], "content").transform)
        end
    end
    for i = 1, 3 do
        tabsBtn[i] = Util.GetGameObject(self.gameObject, "downGo/Tabs/Btn ("..i..")")
    end
    self.selectBtn = Util.GetGameObject(self.gameObject, "downGo/Tabs/selectBtn")



    self.activitySortGo = Util.GetGameObject(self.gameObject, "downGo/activitySortGo")
    self.activitySortGrid = Util.GetGameObject(self.gameObject, "downGo/activitySortGo/rect")
    self.sortPre =  Util.GetGameObject(self.gameObject, "downGo/activitySortGo/sortPre")

    -- 创建循环列表
    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.activitySortGrid.transform,
            self.sortPre, nil, Vector2.New(986.21, 945.24), 1, 1, Vector2.New(15, 0))
    self.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 1
    self.myWarPower = Util.GetGameObject(self.gameObject, "downGo/activitySortGo/info/warPower/warPower"):GetComponent("Text")
    self.mysortNum = Util.GetGameObject(self.gameObject, "downGo/activitySortGo/info/sortNum/sortNum"):GetComponent("Text")
    self.heroInfoBtn = Util.GetGameObject(self.gameObject, "downGo/heroInfoBtn")
    self.Btn2RedPoint = Util.GetGameObject(self.gameObject, "downGo/Tabs/Btn (2)/redPoint")
end

--绑定事件（用于子类重写）
function WarPowerSortPanel:BindEvent()

    Util.AddClick(self.btnBack, function()
        self:ClosePanel()
    end)
    for i = 1, #tabsBtn do
        Util.AddClick(tabsBtn[i], function()
            self:OnShowData(i)
        end)
    end
    Util.AddClick(self.heroInfoBtn, function()
        if heroSId > 0 then
            UIManager.OpenPanel(UIName.RoleGetInfoPopup,false,heroSId,10)
        end
    end)
    BindRedPointObject(RedPointType.WarPowerSort_Sort, self.Btn2RedPoint)
end

--添加事件监听（用于子类重写）
function WarPowerSortPanel:AddListener()

    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose, self.RefreshActivityBtn,self)
end

--移除事件监听（用于子类重写）
function WarPowerSortPanel:RemoveListener()

    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose, self.RefreshActivityBtn,self)
end

--界面打开时调用（用于子类重写）
function WarPowerSortPanel:OnOpen(...)

    SoundManager.PlayMusic(SoundConfig.BGM_Rank)
end

--界面打开或者重新打开后，界面刷新时调用（用于子类重写）
function WarPowerSortPanel:OnShow()

    page = self:GetPriorityIndex()
    self:OnShowData(page)
    self:SetSelectBtn(page)
    warPowerSortbackData = {}
    self:RequestWarPowerSortDatas(true)
end
function WarPowerSortPanel:OnShowData(_type)
    self.activityRewardGo:SetActive(false)
    self.warPowerRewardGo:SetActive(false)
    self.activitySortGo:SetActive(false)
    local activityRewardConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.ActivityRewardConfig, "ActivityId", ActivityTypeDef.WarPowerSort,
            "Sort", 1)
    heroSId = activityRewardConfig.Drawing
    self.heroIcon.sprite = Util.LoadSprite(GetResourcePath(ConfigManager.GetConfigData(ConfigName.HeroConfig,heroSId).Icon))
    if _type == 1 then
        self:ActivityRewardShow()
    elseif _type == 2 then
        self:WarPowerRewardShow()
    elseif _type == 3 then
        self:ActivitySortShow()
        self.activitySortGo:SetActive(true)
        end

end
function WarPowerSortPanel:OnSortingOrderChange()
    --特效穿透特殊处理
    for i = 1, #activityRewardGridItemView do
        for j = 1, #activityRewardGridItemView[i] do
            activityRewardGridItemView[i][j]:SetEffectLayer(self.sortingOrder)
        end
    end
    for i = 1, #warPowerRewardGridItemView do
        for j = 1, #warPowerRewardGridItemView[i] do
            warPowerRewardGridItemView[i][j]:SetEffectLayer(self.sortingOrder)
        end
    end
end
--活动奖励1
function WarPowerSortPanel:ActivityRewardShow()
    local rewardTabs = {}
    for i, v in ConfigPairs(ConfigManager.GetConfig(ConfigName.ActivityRewardConfig)) do
        if v.ActivityId == ActivityTypeDef.WarPowerSort then
            table.insert(rewardTabs,v)
        end
    end
    local WarPowerSort = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.WarPowerSort)
    if WarPowerSort then
        self:SetSelectBtn(1)
        self.activityRewardGo:SetActive(true)
        self:RemainTimeDown(WarPowerSort.endTime - GetTimeStamp(),self.timeTextActivityRewardGo,self.timeTextActivityReward)
        for i = 1, math.max(#rewardTabs, #activityRewardGrid) do
            local go = activityRewardGrid[i]
            if not go then
                go = newObject(self.activityRewardPre)
                go.transform:SetParent(self.activityRewardGridGo.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero
                activityRewardGrid[i] = go
                activityRewardGridItemView[i] = {}
                for j = 1, 3 do --初始缓存3个
                    activityRewardGridItemView[i][j] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(activityRewardGrid[i], "content").transform)
                end
            end
            go.gameObject:SetActive(false)
        end
        for i = 1, #rewardTabs do
            self:ActivityRewardSingleShow(activityRewardGrid[i],rewardTabs[i],i)
        end
    else
        PopupTipPanel.ShowTipByLanguageId(10029)
    end
end
--活动奖励2
function WarPowerSortPanel:ActivityRewardSingleShow(activityRewardGo,rewardData,index)
    activityRewardGo:SetActive(true)
    local titleText = Util.GetGameObject(activityRewardGo, "titleText"):GetComponent("Text")
    if rewardData.Values[1][1] == rewardData.Values[1][2] then
        titleText.text = GetLanguageStrById(10030)..rewardData.Values[1][1]..GetLanguageStrById(10031)..rewardData.Values[1][3]
    else
        titleText.text = GetLanguageStrById(10030)..rewardData.Values[1][1]..GetLanguageStrById(10032)..rewardData.Values[1][2]..GetLanguageStrById(10031)..rewardData.Values[1][3]
    end
    
    local content = Util.GetGameObject(activityRewardGo, "content")

    for i = 1, math.max(#activityRewardGridItemView[index], #rewardData.Reward) do
        local go = activityRewardGridItemView[index][i]
        if not go then
            go = SubUIManager.Open(SubUIConfig.ItemView, content.transform)
            activityRewardGridItemView[index][i] = go
        end
        go:OnOpen(false,rewardData.Reward[i],0.9,false,false,false,self.sortingOrder)
    end
    --Util.ClearChild(content.transform)
    --for i = 1, #rewardData.Reward do
    --    SubUIManager.Open(SubUIConfig.ItemView, content.transform):OnOpen(false,rewardData.Reward[i],0.9,false,false,false,self.sortingOrder)
    --end
end
--战力奖励1
function WarPowerSortPanel:WarPowerRewardShow()
    WarPowerRewardTabs = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.WarPowerReach)
    if WarPowerRewardTabs then
        self:SetSelectBtn(2)
        self.warPowerRewardGo:SetActive(true)
        self:RemainTimeDown(WarPowerRewardTabs.endTime - GetTimeStamp(),self.timeTextWarPowerRewardGo,self.timeTextWarPowerReward)
        for i = 1, math.max(#WarPowerRewardTabs.mission, #warPowerRewardGrid) do
            local go = warPowerRewardGrid[i]
            if not go then
                go = newObject(self.warPowerRewardPre)
                go.transform:SetParent(self.warPowerRewardGridGo.transform)
                go.transform.localScale = Vector3.one
                go.transform.localPosition = Vector3.zero
                warPowerRewardGrid[i] = go
                warPowerRewardGridItemView[i] = {}
                for j = 1, 3 do --初始缓存3个
                    warPowerRewardGridItemView[i][j] = SubUIManager.Open(SubUIConfig.ItemView, Util.GetGameObject(warPowerRewardGrid[i], "content").transform)
                end
            end
            go.gameObject:SetActive(false)
        end
        self:WarPowerRewardTabsChangState()
        self:WarPowerRewardTabsSort(WarPowerRewardTabs.mission)
        for i = 1, #WarPowerRewardTabs.mission do
            self:WarPowerRewardSingleShow(warPowerRewardGrid[i],WarPowerRewardTabs.mission[i],i)
        end
    else
        PopupTipPanel.ShowTipByLanguageId(10029)
    end
end
function WarPowerSortPanel:WarPowerRewardTabsChangState()
    for i = 1, #WarPowerRewardTabs.mission do
        local conFigData = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig,WarPowerRewardTabs.mission[i].missionId)
        local value = conFigData.Values[1][1]
        if WarPowerRewardTabs.mission[i].state == 0 then
            if WarPowerRewardTabs.value < value then
                WarPowerRewardTabs.mission[i].state = 10
            else
                WarPowerRewardTabs.mission[i].state = 0
            end
        elseif WarPowerRewardTabs.mission[i].state == 1 then
            WarPowerRewardTabs.mission[i].state = 20
        end
    end
end
function WarPowerSortPanel:WarPowerRewardTabsSort(missions)
    table.sort(missions,function(a,b)
        if a.state < b.state then
            return a.state < b.state
        elseif a.state == b.state then
            return a.missionId < b.missionId
        end
    end)
end
--战力奖励2
function WarPowerSortPanel:WarPowerRewardSingleShow(activityRewardGo,rewardData,index)
    activityRewardGo:SetActive(true)
    local sConFigData = ConfigManager.GetConfigData(ConfigName.ActivityRewardConfig,rewardData.missionId)
    local titleText = Util.GetGameObject(activityRewardGo, "titleText"):GetComponent("Text")
    titleText.text = GetLanguageStrById(10033)..sConFigData.Values[1][1]

    local content = Util.GetGameObject(activityRewardGo, "content")
    for i = 1, math.max(#warPowerRewardGridItemView[index], #sConFigData.Reward) do
        local go = warPowerRewardGridItemView[index][i]
        if not go then
            go = SubUIManager.Open(SubUIConfig.ItemView, content.transform)
            warPowerRewardGridItemView[index][i] = go
        end
        go:OnOpen(false,sConFigData.Reward[i],0.9,false,false,false,self.sortingOrder)
    end
    --Util.ClearChild(content.transform)
    --for i = 1, #sConFigData.Reward do
    --    SubUIManager.Open(SubUIConfig.ItemView, content.transform):OnOpen(false,sConFigData.Reward[i],0.9,false,false,false,self.sortingOrder)
    --end
    local lingquButton = Util.GetGameObject(activityRewardGo.gameObject, "lingquButton")
    Util.GetGameObject(lingquButton.gameObject, "redPoint"):SetActive(false)
    local qianwangButton = Util.GetGameObject(activityRewardGo.gameObject, "qianwangButton")
    local getFinishText = Util.GetGameObject(activityRewardGo.gameObject, "getFinishText")
    local state = rewardData.state
    qianwangButton:SetActive(state == 10)
    lingquButton:SetActive(state == 0)
    getFinishText:SetActive(state == 20)
    Util.AddOnceClick(qianwangButton, function()
        --JumpManager.GoJump(sConFigData.Jump[1])
    end)
    Util.AddOnceClick(lingquButton, function()
        NetManager.GetActivityRewardRequest(rewardData.missionId, WarPowerRewardTabs.activityId, function(drop)
           UIManager.OpenPanel(UIName.RewardItemPopup,drop,1,function()
               self:WarPowerRewardShow()
           end)
        end)
    end)
end
--活动排名1
function WarPowerSortPanel:ActivitySortShow()
    self.myWarPower.text = myWarPower
    self.mysortNum.text = myWarPowerSortNum
    self:SetSelectBtn(3)
    -- 节点数据匹配
    local rankAdapterFunc = function (index, go)
        self:ActivitySortSingleShow(go, warPowerSortbackData[index])
        -- 如果显示到最后一个，刷新下一页数据
        --if index == #warPowerSortbackData then
        --    self:RequestWarPowerSortDatas(false,page)
        --end
    end

    -- 第一页需要重置，其他刷新就好
    --if page <= 1 then
    --    -- 重置排行列表
        self.ScrollView:SetData(warPowerSortbackData, rankAdapterFunc)
    --else
    --    -- 刷新排行列表
    --    self.ScrollView:SetData(warPowerSortbackData, rankAdapterFunc)
    --end
end
--活动排名2
function WarPowerSortPanel:ActivitySortSingleShow(activityRewardGo,rewardData)
    Util.AddOnceClick(activityRewardGo,function()
        UIManager.OpenPanel(UIName.PlayerInfoPopup, rewardData.uid)
    end)
    --设置表现背景
    if myWarPowerSortNum==rewardData.rankInfo.rank then
        Util.GetGameObject(activityRewardGo,"selfBg").gameObject:SetActive(true)
    else
        Util.GetGameObject(activityRewardGo,"selfBg").gameObject:SetActive(false)
    end

    local sortNumTabs = {}
    for i = 1, 4 do
        sortNumTabs[i] =  Util.GetGameObject(activityRewardGo, "sortNum/sortNum ("..i..")")
        sortNumTabs[i]:SetActive(false)
    end
    if rewardData.rankInfo.rank < 4 then
        sortNumTabs[rewardData.rankInfo.rank]:SetActive(true)
    else
        sortNumTabs[4]:SetActive(true)
        Util.GetGameObject(sortNumTabs[4], "titleText"):GetComponent("Text").text = rewardData.rankInfo.rank
    end
    Util.GetGameObject(activityRewardGo, "name"):GetComponent("Text").text = rewardData.userName
    Util.GetGameObject(activityRewardGo, "lv"):GetComponent("Text").text = rewardData.level
    Util.GetGameObject(activityRewardGo, "warPowerImage/warPower"):GetComponent("Text").text = rewardData.force
end

function WarPowerSortPanel:SetSelectBtn(index)
        self.selectBtn.transform.localPosition = tabsBtn[index].transform.localPosition
        Util.GetGameObject(self.selectBtn.transform, "Text"):GetComponent("Text").text = Util.GetGameObject(tabsBtn[index], "Text"):GetComponent("Text").text
end
function WarPowerSortPanel:RequestWarPowerSortDatas(isOnePage,_page)
    local curPageSortDatas = {}
    if isOnePage then
        NetManager.RequestRankInfo(RANK_TYPE.FORCE_RANK, function(msg)
           
           
           
            warPowerSortbackData = msg.ranks
            myWarPower = msg.myRankInfo.param1
            myWarPowerSortNum =  msg.myRankInfo.rank
        end, ActivityTypeDef.WarPowerSort)
        return
    end
    --判断是否符合刷新条件
    local rankNum = #warPowerSortbackData
    -- 最多显示200
    if rankNum >= tonumber(ConfigManager.GetConfigData(ConfigName.SpecialConfig,8).Value) then return end
    -- 上一页数据少于20条，则没有下一页数，不再刷新
    if rankNum % 20 > 0 then return end
    -- 请求下一页
    page = _page + 1
    NetManager.RequestRankInfo(RANK_TYPE.FORCE_RANK, function(msg)
       
       
       
        curPageSortDatas = msg.ranks
        myWarPower = msg.myRankInfo.param1
        myWarPowerSortNum =  msg.myRankInfo.rank
        if curPageSortDatas and #curPageSortDatas > 0 then
            for i = 1, #curPageSortDatas do
                table.insert(warPowerSortbackData,curPageSortDatas[i])
            end
           
            self:ActivitySortShow()
        end
    end, ActivityTypeDef.WarPowerSort)
end

--刷新倒计时显示
function WarPowerSortPanel:RemainTimeDown(timeDown,timeTextGo,timeText)
    if timeDown > 0 then
        timeTextGo:SetActive(true)
        timeText.text =   self:TimeStampToDateString(timeDown)
        if self.timer then
            self.timer:Stop()
            self.timer = nil
        end
        self.timer = Timer.New(function()
            timeText.text =   self:TimeStampToDateString(timeDown)
            if timeDown < 0 then
                timeTextGo:SetActive(false)
                self.timer:Stop()
                self.timer = nil
            end
            timeDown = timeDown - 1
        end, 1, -1, true)
        self.timer:Start()
    else
        timeTextGo:SetActive(false)
    end
end
function WarPowerSortPanel:TimeStampToDateString(second)
    local day = math.floor(second / (24 * 3600))
    local minute = math.floor(second / 60) % 60
    local sec = second % 60
    local hour = math.floor(math.floor(second - day * 24 * 3600 - sec - minute * 60) / 3600)
    return string.format(GetLanguageStrById(10034),day, hour, minute, sec)
end
--界面关闭时调用（用于子类重写）
function WarPowerSortPanel:OnClose()

    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end
function WarPowerSortPanel:RefreshActivityBtn(context)
    if context.type == ActivityTypeDef.WarPowerSort then
        if context.status == 0 then
            MsgPanel.ShowOne(GetLanguageStrById(10029), function ()
                self:ClosePanel()
            end)
        end
    end
end
--界面销毁时调用（用于子类重写）
function WarPowerSortPanel:OnDestroy()

    ClearRedPointObject(RedPointType.WarPowerSort_Sort)
    self.ScrollView = nil
end
function WarPowerSortPanel:GetPriorityIndex()
    local index = 1
    if Util.GetGameObject(tabsBtn[2], "redPoint").activeSelf then
        index = 2
    end
    return index
end
return WarPowerSortPanel