--[[
 * @ClassName SevenDayCarnivalPanel
 * @Description 开服七天狂欢
 * @Date 2019/7/30 20:42
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]

--去看SevenDayCarnivalPanelV2吧，应该不用了

local SevenDayCarnivalHalfPricePage = require("Modules/SevenDayCarnival/SevenDayCarnivalHalfPricePage")
local SevenDayCarnivalTaskItem = require("Modules/SevenDayCarnival/SevenDayCarnivalTaskItem")

---@class SevenDayCarnivalPanel
local SevenDayCarnivalPanel = quick_class("SevenDayCarnivalPanel", BasePanel)

local kDayNumber, kMaxTaskCount = 6, 20
local kScoreTaskType = 38

local TypeActDifIcon = {
    [10] = { bgIcon = "r_qrkh_BG", title = "r_qrkh_kfkh" },
    [25] = { bgIcon = "r_qrkh_BG_2", title = "r_qrkh_jlqd" }
}
local dayTabColor = {
    [1] = Color(106 / 255, 79 / 255, 62 / 255, 1),
    [2] = Color(250 / 255, 245 / 255, 215 / 255, 1)
}
local groupTabColor = {
    [1] = Color(156 / 255, 156 / 255, 156 / 255, 1),
    [2] = Color(252 / 255, 250 / 255, 237 / 255, 1)
}

function SevenDayCarnivalPanel:InitComponent()
    self.backBtn = Util.GetGameObject(self.transform, "bg/btnBack")

    --换期部分
    self.bg = Util.GetGameObject(self.transform, "bg"):GetComponent("Image")
    self.title = Util.GetGameObject(self.transform, "bg/title/Image"):GetComponent("Image")

    self.dayTabs = {}
    for i = 1, kDayNumber do
        self.dayTabs[i] = Util.GetGameObject(self.transform, "bg/daysTabBg/tabsGroup/day_" .. i)
    end
    self.selectDayTab = -1
    self.actRemainTime = Util.GetGameObject(self.transform, "bg/actRemainTime"):GetComponent("Text")

    self.finalTargetProgress = Util.GetGameObject(self.transform, "bg/finalTarget/progressbar/progress"):GetComponent("Image")
    self.finalTargetValue = Util.GetGameObject(self.transform, "bg/finalTarget/progressbar/value"):GetComponent("Text")
    self.rewardBoxBtn = Util.GetGameObject(self.transform, "bg/finalTarget/rewardBoxBtn")
    self.rewardBoxRedPoint = Util.GetGameObject(self.rewardBoxBtn, "redPoint")
    self.rewardBoxEffect = Util.GetGameObject(self.rewardBoxBtn, "effect_box")

    --taskList
    self.taskPart = Util.GetGameObject(self.transform, "bg/taskList")
    self.taskList = {}
    self.taskContent = Util.GetGameObject(self.taskPart, "viewPort/content"):GetComponent("RectTransform")
    self.taskItemPro = Util.GetGameObject(self.taskContent.transform, "itemPro")
    self.taskItemPro:SetActive(false)
    for i = 1, kMaxTaskCount do
        self.taskList[i] = SevenDayCarnivalTaskItem.create(self.taskItemPro, self.taskContent.transform)
    end
    self.sorting=0
    --halfPage
    self.halfPricePage = SevenDayCarnivalHalfPricePage.new(self, Util.GetGameObject(self.transform, "bg/halfPriceBuy"))

    self.tabsList = {}
    self.tabsContent = Util.GetGameObject(self.transform, "bg/bottomTabs/content")
    self.tabPro = Util.GetGameObject(self.tabsContent, "tabPro")
    self.tabPro:SetActive(false)
    self.tabIndex = -1

    ---  生成页签
    self:CreateTab()
    self.lastIndex = 1

    

    self.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowLeft })
end

function SevenDayCarnivalPanel:BindEvent()
    Util.AddClick(self.backBtn, function()
        self:ClosePanel()
    end)

    Util.AddClick(self.rewardBoxBtn, function()
        self:OnRewardBoxBtnClicked()
    end)

    for idx, dayTab in ipairs(self.dayTabs) do
        Util.AddClick(dayTab, function()
            self:OnDayTabClicked(idx)
        end)
    end

    for k, v in pairs(self.tabsList) do
        Util.AddClick(v.tabItem, function()
            self:ShowInfoByTab(v.type, v.tabItem)
        end)
        
    end
end

function SevenDayCarnivalPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, self.ChangeTaskList, self)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityProgressStateChange, self.SetFinalTarget, self)
end

function SevenDayCarnivalPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, self.ChangeTaskList, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityProgressStateChange, self.SetFinalTarget, self)
end

function SevenDayCarnivalPanel:OnOpen()
    self:SatisfyActivity()
    self.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.Main })
    --local currentDay = SevenDayCarnivalManager.GetCurrentDayNumber()
    --if currentDay >= kDayNumber then
    --    self.selectDayTab = kDayNumber
    --else
    --    self.selectDayTab = currentDay
    --end

    self.selectDayTab = SevenDayCarnivalManager.GetPriorityDayNumber()
    self:SetFinalTarget()

    self.enableReceive = true
    self.hadRequestState = false
end

function SevenDayCarnivalPanel:OnShow()
    self:OnDayTabChanged()
    self:ShowInfoByTab(1)
    self:SetRemainTimes()
    self:RefreshRedPoint()
    self:ClickBottomTab(self:GetPriorityGroup())
    -- 刷新天数文字显示
    self:RefreshDayShow()

    self:RefreshGroupTask()
end

function SevenDayCarnivalPanel:OnSortingOrderChange()
    for i = 1, #self.taskList do
        self.taskList[i]:OnSortingOrderChange(self.sortingOrder)
    end
    self.halfPricePage:OnSortingOrderChange(self.sortingOrder)
    Util.AddParticleSortLayer(Util.GetGameObject(self.transform, "bg/effect"), self.sortingOrder-self.sorting)
    Util.AddParticleSortLayer(self.rewardBoxEffect, self.sortingOrder-self.sorting)
    self.sorting=self.sortingOrder
end
function SevenDayCarnivalPanel:OnClose()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    self.lastIndex = 1
end

function SevenDayCarnivalPanel:OnDestroy()
    SubUIManager.Close(self.UpView)
    self.tabsList = {}
end

-- 刷新天数页签天数显示
function SevenDayCarnivalPanel:RefreshDayShow()
    local currentDay = SevenDayCarnivalManager.GetCurrentDayNumber()
    for day, tab in ipairs(self.dayTabs) do
        local txt = Util.GetGameObject(tab, "Text"):GetComponent("Text")
        if day <= currentDay then
            txt.text = string.format(GetLanguageStrById(11914), day)
        elseif day == currentDay + 1 then
            txt.text = GetLanguageStrById(11915)
        else
            txt.text = GetLanguageStrById(11916)
        end
    end
end


function SevenDayCarnivalPanel:OnDayTabClicked(index)
    local currentDay = SevenDayCarnivalManager.GetCurrentDayNumber()
    if index > currentDay + 1 then
        PopupTipPanel.ShowTipByLanguageId(11917)
        return
    end
    if index == self.selectDayTab then
        return
    end
    self.selectDayTab = index
    self:OnDayTabChanged()
    self:ClickBottomTab(self.lastIndex)
end

---生成下面的页签
function SevenDayCarnivalPanel:CreateTab()
    local tabItemTarget = newObjToParent(self.tabPro, self.tabsContent)
    local tabItem = newObjToParent(self.tabPro, self.tabsContent)

    table.insert(self.tabsList, { tabItem = tabItemTarget, groupTask = 1, type = 1, })
    table.insert(self.tabsList, { tabItem = tabItem, type = 2 })
end

function SevenDayCarnivalPanel:OnDayTabChanged()
    --- 这是为啥，为啥每次切换天数你都要删除
    -- table.walk(self.tabsList, function(tabInfo)
        -- destroy(tabInfo.tabItem.gameObject)
    -- end)
    -- self.tabsList = {}

    --- 设置天数的选中状态
    for idx, dayTabItem in ipairs(self.dayTabs) do
        Util.GetGameObject(dayTabItem, "selected"):SetActive(idx == self.selectDayTab)
        Util.GetGameObject(dayTabItem, "Text"):GetComponent("Text").color = idx == self.selectDayTab and dayTabColor[2] or dayTabColor[1]
    end


    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
    local sevenDaysConfigs = ConfigManager.GetAllConfigsDataByDoubleKey(ConfigName.SevenDaysActivity, "BelongDay", self.selectDayTab, "ActivityId", activityId)
   

    local name
    local id
    for _, dayInfo in ipairs(sevenDaysConfigs) do
        name = dayInfo.GroupShow
        id = dayInfo.Id
    end
    -- 更新页签ID以及更新显示
    for k, v in pairs(self.tabsList) do
       if v.type == 1 then 
            v.groupTask = id
            Util.GetGameObject(v.tabItem, "name"):GetComponent("Text").text = name
       else
            Util.GetGameObject(v.tabItem, "name"):GetComponent("Text").text = GetLanguageStrById(11918)
       end
    end
    self:RefreshGroupTask()
    self:ShowInfoByTab(self.lastIndex, self.tabsList[self.lastIndex].tabItem)


    -- for _, dayInfo in ipairs(sevenDaysConfigs) do
        -- local tabItem = newObjToParent(self.tabPro, self.tabsContent)
        -- Util.GetGameObject(tabItem, "name"):GetComponent("Text").text = dayInfo.GroupShow
        -- Util.AddClick(tabItem, function()
        --     self:SetBottomTabSelect(tabItem)
        --     self:SetTaskPartShow(true)
        --     self:OnBottomTabClicked(dayInfo.Id)
        -- end)
        -- table.insert(self.tabsList, { tabItem = tabItem, groupTask = dayInfo.Id, type = 1, })
    -- end

    -- local tabItem = newObjToParent(self.tabPro, self.tabsContent)
    -- Util.GetGameObject(tabItem, "name"):GetComponent("Text").text = "半价抢购"
    -- Util.AddClick(tabItem, function()
    --     self:SetBottomTabSelect(tabItem)
    --     self:SetTaskPartShow(false)
    --     -- local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
    --     PlayerPrefs.SetInt(PlayerManager.uid .. "_SevenDay" .. "_" .. activityId .. "_" .. self.selectDayTab, 1)

    --     Util.GetGameObject(tabItem, "redPoint"):SetActive(false)
    --     self:RefreshDayTabRedPoint(self.selectDayTab)
    --     CheckRedPointStatus(RedPointType.SevenDayCarnival)
    -- end)
    -- table.insert(self.tabsList, { tabItem = tabItem, type = 2 })

    -- self:RefreshGroupTask()
end

-- 根据选择的页签显示数据 1-->正常任务  2-->半价购买
function SevenDayCarnivalPanel:ShowInfoByTab(index, item)
    self.lastIndex = index
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)    
    local tabItem = item or self.tabsList[1].tabItem

    if index == 1 then 
        self:SetBottomTabSelect(tabItem)
        self:SetTaskPartShow(true)
        self:OnBottomTabClicked(self.tabsList[index].groupTask)
    else
        self:SetBottomTabSelect(tabItem)
        self:SetTaskPartShow(false)
        PlayerPrefs.SetInt(PlayerManager.uid .. "_SevenDay" .. "_" .. activityId .. "_" .. self.selectDayTab, 1)

        Util.GetGameObject(tabItem, "redPoint"):SetActive(false)
        self:RefreshDayTabRedPoint(self.selectDayTab)
        CheckRedPointStatus(RedPointType.SevenDayCarnival)
    end
end


function SevenDayCarnivalPanel:ClickBottomTab(index)
if index == self.lastIndex then return end 
    if index == 1 then
        self:SetTaskPartShow(true)
        local tabInfo = self.tabsList[index]
        self:SetBottomTabSelect(tabInfo.tabItem)
        self.tabIndex = tabInfo.groupTask
        self:OnBottomTabChanged()
    else
        local tabItemInfo = self.tabsList[#self.tabsList]
        self:SetBottomTabSelect(tabItemInfo.tabItem)
        self:SetTaskPartShow(false)
        local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
        PlayerPrefs.SetInt(PlayerManager.uid .. "_SevenDay_" .. activityId .. "_" .. self.selectDayTab, 1)
        Util.GetGameObject(tabItemInfo.tabItem, "redPoint"):SetActive(false)
        self:RefreshDayTabRedPoint(self.selectDayTab)
        CheckRedPointStatus(RedPointType.SevenDayCarnival)
    end
end

function SevenDayCarnivalPanel:SetBottomTabSelect(tabItem)
    for _, groupTabInfo in ipairs(self.tabsList) do
        Util.GetGameObject(groupTabInfo.tabItem, "selected"):SetActive(tabItem == groupTabInfo.tabItem)
        Util.GetGameObject(groupTabInfo.tabItem, "name"):GetComponent("Text").color = tabItem == groupTabInfo.tabItem and groupTabColor[2] or groupTabColor[1]
    end
end

function SevenDayCarnivalPanel:OnBottomTabClicked(taskGroup)
    if taskGroup == self.tabIndex then
        return
    end
    self.tabIndex = taskGroup
    self:OnBottomTabChanged()
end

function SevenDayCarnivalPanel:OnBottomTabChanged()
    self:SetTaskPartShow(true)

    table.walk(self.taskList, function(taskItem)
        taskItem:SetVisible(false)
    end)

    local GroupTaskList = {}
    self.serverTaskList = TaskManager.GetTypeTaskList(TaskTypeDef.SevenDayCarnival)
    table.walk(self.serverTaskList, function(taskInfo)
        local treasureConfig = ConfigManager.GetConfigData(ConfigName.TreasureTaskConfig, taskInfo.missionId)
        if treasureConfig.DayNum == self.selectDayTab and treasureConfig.TaskGroup == self.tabIndex then
            table.insert(GroupTaskList, { serverData = taskInfo, localData = treasureConfig })
        end
    end)
    table.sort(GroupTaskList, function(a, b)
        if a.serverData.state == b.serverData.state then
            return a.serverData.missionId < b.serverData.missionId
        else
            return TaskStateRankDef[a.serverData.state] < TaskStateRankDef[b.serverData.state]
        end
    end)
    local currentDay = SevenDayCarnivalManager.GetCurrentDayNumber()
    for i, treasureInfo in ipairs(GroupTaskList) do
        self.taskList[i]:Init(treasureInfo.localData,self.sortingOrder)
        self.taskList[i]:SetValue(self.selectDayTab <= currentDay)
        self.taskList[i]:SetVisible(true)
    end

    self.taskContent.anchoredPosition = Vector2(0, 0)
end

function SevenDayCarnivalPanel:SetTaskPartShow(flag)
    self.taskPart:SetActive(flag)
    if flag then
        self.halfPricePage:OnHide()
    else
        self.halfPricePage:OnShow()
    end
end

function SevenDayCarnivalPanel:SetFinalTarget()
    local currentActivityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
    local treasureTaskConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.TreasureTaskConfig,
            "ActivityId", currentActivityId, "TaskType", kScoreTaskType)
    local currentScore = SevenDayCarnivalManager.GetSevenDayScore()
    self.finalTargetProgress.fillAmount = currentScore / treasureTaskConfig.TaskValue[2][1]
    self.finalTargetValue.text = currentScore .. "/" .. treasureTaskConfig.TaskValue[2][1]
    self.rewardBoxRedPoint:SetActive(SevenDayCarnivalManager.GetBoxRedPointStatus())
    self.rewardBoxEffect:SetActive(SevenDayCarnivalManager.GetBoxRedPointStatus())
end

function SevenDayCarnivalPanel:OnRewardBoxBtnClicked()
    if self.enableReceive then
        UIManager.OpenPanel(UIName.SevenDayRewardPreviewPanel)
    else
        PopupTipPanel.ShowTipByLanguageId(11919)
    end
end

function SevenDayCarnivalPanel:ChangeTaskList()
    if self.halfPricePage:IsActive() then
        return
    end
    self:OnBottomTabChanged()
    self:RefreshDayTabRedPoint(self.selectDayTab)
    self:RefreshGroupTask()
    self:SetFinalTarget()
    CheckRedPointStatus(RedPointType.SevenDayCarnival)
end

function SevenDayCarnivalPanel:SetRemainTimes()
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SevenDayCarnival)
    local timeDown = activityInfo.endTime - GetTimeStamp()
    if self.timer then
        self.timer:Stop()
        self.timer = nil
    end
    self:SetTimeTipsFormat(timeDown)
    if timeDown <= 0 then
        return
    end
    self.timer = Timer.New(function()
        if timeDown <= 0 then
            self.timer:Stop()
            self.timer = nil
        end
        self:SetTimeTipsFormat(timeDown)
        timeDown = timeDown - 1
    end, 1, -1, true)
    self.timer:Start()
end

function SevenDayCarnivalPanel:SetTimeTipsFormat(timeDown)
    --#FFC054FF
    if timeDown <= 0 then
        self:SetTaskListDisable(false)
        self.enableReceive = false
        self.actRemainTime.text = GetLanguageStrById(11920)
    else
        self.actRemainTime.text = GetLanguageStrById(11921) .. DateUtils.GetTimeFormatV2(timeDown)
        if timeDown > 0 and timeDown <= 86400 then
            self:SetTaskListDisable(false)
            self:UpDateFinalRewardState()
        else
            self:SetTaskListDisable(true)
        end
    end
end

function SevenDayCarnivalPanel:UpDateFinalRewardState()
    if self.hadRequestState then
        return
    end
    local activityId = ActivityGiftManager.IsActivityTypeOpen(ActivityTypeDef.SevenDayCarnival)
    local treasureTaskConfig = ConfigManager.GetConfigDataByDoubleKey(ConfigName.TreasureTaskConfig,
            "ActivityId", activityId, "TaskType", kScoreTaskType)
    local taskInfo = TaskManager.GetTypeTaskInfo(TaskTypeDef.SevenDayCarnival, treasureTaskConfig.Id)
    if taskInfo.state == VipTaskStatusDef.NotFinished then
        self.hadRequestState = true
        NetManager.RequestUpDateState(UpDateTypeState.SevenDayCarnival)
    end
end

function SevenDayCarnivalPanel:RefreshRedPoint()
    for i = 1, kDayNumber do
        self:RefreshDayTabRedPoint(i)
    end
    self:RefreshGroupTask()
end

function SevenDayCarnivalPanel:RefreshDayTabRedPoint(dayNumber)
    local redPoint = SevenDayCarnivalManager.GetDayNumberRedPointStatus(dayNumber)
    Util.GetGameObject(self.dayTabs[dayNumber], "redPoint"):SetActive(redPoint)
end

function SevenDayCarnivalPanel:RefreshGroupTask()
    table.walk(self.tabsList, function(tabInfo)
        if tabInfo.groupTask then
            local redPoint = SevenDayCarnivalManager.GetGroupRedPointStatus(tabInfo.groupTask)
            Util.GetGameObject(tabInfo.tabItem, "redPoint"):SetActive(redPoint)
        else
            local status = SevenDayCarnivalManager.GetSevenDayHalfPriceRedPoint(self.selectDayTab)
            Util.GetGameObject(tabInfo.tabItem, "redPoint"):SetActive(status)
        end
    end)
end

function SevenDayCarnivalPanel:GetPriorityGroup()
    local index = 1
    for i, tabInfo in ipairs(self.tabsList) do
        if Util.GetGameObject(tabInfo.tabItem, "redPoint").activeSelf then
            index = i < #self.tabsList and i or nil
            break
        end
    end
    return index
end

function SevenDayCarnivalPanel:SetTaskListDisable(flag)
    if self.enableReceive then
        table.walk(self.taskList, function(taskItem)
            taskItem:SetDisabled(flag)
        end)
    end
end

function SevenDayCarnivalPanel:SatisfyActivity()
    local activityInfo = ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SevenDayCarnival)
    self.bg.sprite = Util.LoadSprite(TypeActDifIcon[activityInfo.activityId].bgIcon)
    self.title.sprite = Util.LoadSprite(TypeActDifIcon[activityInfo.activityId].title)
    self.title:SetNativeSize()
end

return SevenDayCarnivalPanel