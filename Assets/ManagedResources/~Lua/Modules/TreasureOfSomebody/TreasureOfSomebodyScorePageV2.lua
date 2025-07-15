--[[
 * @ClassName TreasureOfSomebodyScorePageV2
 * @Description 戒灵秘宝积分Part
 * @Date 2019/9/21 11:22
 * @Author MagicianJoker, fengliudianshao@outlook.com
 * @Copyright  Copyright (c) 2019, MagicianJoker
--]]
---@class TreasureOfSomebodyScorePageV2
local TreasureOfSomebodyScorePageV2 = quick_class("TreasureOfSomebodyScorePageV2")

local kTabCount = 3
local groupTabColor = {
    [1] = Color(255 / 255, 251 / 255, 243 / 255, 1),
    [2] = Color(156 / 255, 156 / 255, 156 / 255, 1)
}
local TypeActDifIcon = {
    [1] = "r_qrkh_anniu_1",
    [2] = "r_qrkh_anniu_2"
}
local TaskGetBtnIcon = {
    [0] = "t_tequan_qianwang",
    [1] = "t_tequan_lingqu",
}

function TreasureOfSomebodyScorePageV2:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject

    self.scoreListContent = Util.GetGameObject(self.gameObject, "scoreList")
    self.scorePro = Util.GetGameObject(self.gameObject, "itemPro")
    self.scorePro:SetActive(false)
    self.timeText = Util.GetGameObject(self.gameObject, "timeImage/timeText"):GetComponent("Text")
    ---- 创建循环列表
    local v2 = self.scoreListContent:GetComponent("RectTransform").rect
    self.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, self.scoreListContent.transform,
            self.scorePro, nil, Vector2.New(-v2.x * 2, -v2.y * 2), 1, 1, Vector2.New(0, 12))
    self.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    self.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    self.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    self.ScrollView.moveTween.MomentumAmount = 1
    self.ScrollView.moveTween.Strength = 1

    ----tabs
    self.tabContents = {}
    for i = 1, kTabCount do
        self.tabContents[i] = {
            tabItem = Util.GetGameObject(self.gameObject, "tabGroup/tab_" .. i):GetComponent("Image"),
            tabText = Util.GetGameObject(self.gameObject, "tabGroup/tab_" .. i .. "/Text"):GetComponent("Text"),
            tabRedPoint = Util.GetGameObject(self.gameObject, "tabGroup/tab_" .. i .. "/redPoint")
        }
        Util.AddClick(self.tabContents[i].tabItem.gameObject, function()
            self:OnTabClicked(i)
        end)
    end
    self.selectTabIndex = -1

    --self.refreshTime = Util.GetGameObject(self.gameObject, "refreshTime"):GetComponent("Text")
end

function TreasureOfSomebodyScorePageV2:OnShow(extra)
    if not TaskManager.GetSLrefreshTime() then
        NetManager.RefreshTimeSLRequest(function (msg)
            TaskManager.SetSLrefreshTime(msg)
            self:GetRemainTime(extra and extra or 1)
        end)
    end
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionListRestChanged, self.RefreshTaskList, self)
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, self.RefreshFinishedTaskList,self)
    self:RefreshTabRedPoint()
    self.gameObject:SetActive(true)
    self:OnTabChanged(extra and extra or 1)
    --self:GetRemainTime(extra and extra or 1)
end

function TreasureOfSomebodyScorePageV2:OnHide()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionListRestChanged, self.RefreshTaskList, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged, self.RefreshFinishedTaskList,self)
    self.gameObject:SetActive(false)
    --if self.thread then
    --    coroutine.stop(self.thread)
    --    self.thread = nil
    --end
    if self.selectTabIndex ~= -1 then
        self.tabContents[self.selectTabIndex].tabItem.sprite = Util.LoadSprite(TypeActDifIcon[2])
        self.tabContents[self.selectTabIndex].tabText.color = groupTabColor[2]
    end
end

function TreasureOfSomebodyScorePageV2:OnDestroy()
    self.ScrollView = nil
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
end

function TreasureOfSomebodyScorePageV2:OnTabClicked(index)
    if self.selectTabIndex == index then
        return
    end
    self:OnTabChanged(index)
end

function TreasureOfSomebodyScorePageV2:OnTabChanged(index)
    local oldSelect
    oldSelect, self.selectTabIndex = self.selectTabIndex, index
    if oldSelect ~= -1 then
        self.tabContents[oldSelect].tabItem.sprite = Util.LoadSprite(TypeActDifIcon[2])
        self.tabContents[oldSelect].tabText.color = groupTabColor[2]
    end
    self.tabContents[self.selectTabIndex].tabItem.sprite = Util.LoadSprite(TypeActDifIcon[1])
    self.tabContents[self.selectTabIndex].tabText.color = groupTabColor[1]
    self:ShowTabContent(index)
end

function TreasureOfSomebodyScorePageV2:ShowTabContent(index)
    --self:SetRefreshTime(index)
    local taskList = self:GetTabTaskList(index)
    self.ScrollView:SetData(taskList, function(index, scoreItem)
        local itemData = taskList[index]
        self:SetScoreItemAdapter(scoreItem, itemData)
    end)
    self:GetRemainTime(index)
end

function TreasureOfSomebodyScorePageV2:GetTabTaskList(index)
    local conditionTaskList = {}
    local treasureTaskConfig = ConfigManager.GetConfig(ConfigName.TreasureSunLongTaskConfig)
    local itemList = TaskManager.GetTypeTaskList(TaskTypeDef.TreasureOfSomeBody)
    for _, taskInfo in ipairs(itemList) do
        if treasureTaskConfig[taskInfo.missionId].Type == index then
            table.insert(conditionTaskList, taskInfo)
        end
    end
    table.sort(conditionTaskList, function(a, b)
        if a.state == b.state then
            return a.missionId < b.missionId
        else
            return TaskStateRankDef[a.state] < TaskStateRankDef[b.state]
        end
    end)
    return conditionTaskList
end

function TreasureOfSomebodyScorePageV2:SetScoreItemAdapter(scoreItem, itemInfo)
    local treasureTaskConfig = ConfigManager.GetConfigData(ConfigName.TreasureSunLongTaskConfig, itemInfo.missionId)
    Util.GetGameObject(scoreItem, "taskDesc"):GetComponent("Text").text = GetLanguageStrById(treasureTaskConfig.Show)
    Util.GetGameObject(scoreItem, "scoreDesc"):GetComponent("Text").text = treasureTaskConfig.Integral[1][2] .. GetLanguageStrById(10147)
    local dealBtn = Util.GetGameObject(scoreItem, "btnDeal")
    dealBtn:SetActive(itemInfo.state ~= VipTaskStatusDef.Received)
    if dealBtn.activeSelf then
        dealBtn:GetComponent("Image").sprite = Util.LoadSprite(TaskGetBtnIcon[itemInfo.state])
    end
    Util.SetGray(dealBtn,TreasureOfSomebodyManagerV2.currentLv >= TreasureOfSomebodyManagerV2.treasureMaxLv)
    Util.AddOnceClick(dealBtn, function()
        if TreasureOfSomebodyManagerV2.currentLv >= TreasureOfSomebodyManagerV2.treasureMaxLv then
            PopupTipPanel.ShowTipByLanguageId(11960)
        else
            if itemInfo.state == VipTaskStatusDef.CanReceive then
                NetManager.TakeMissionRewardRequest(TaskTypeDef.TreasureOfSomeBody, itemInfo.missionId, function(respond)
                    TreasureOfSomebodyManagerV2.SetCurrentLevel(respond.treasureScore)
                    UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1)
                    TaskManager.SetMissionIdState(TaskTypeDef.TreasureOfSomeBody, treasureTaskConfig.Id, 2)
                    self.mainPanel:SetTreasureProgress()
                    self.mainPanel:SetRewardRedPoint()
                    dealBtn:SetActive(false)
                    Util.GetGameObject(scoreItem, "finished"):SetActive(true)
                    self:RefreshTabRedPoint()
                    RedpotManager.CheckRedPointStatus(RedPointType.TreasureOfSl)
                    self:ShowTabContent(self.selectTabIndex)
                end)
            else
                JumpManager.GoJump(treasureTaskConfig.Jump[1])
            end
        end
    end)
    Util.GetGameObject(scoreItem, "finished"):SetActive(itemInfo.state == VipTaskStatusDef.Received)
    Util.GetGameObject(scoreItem, "progress"):GetComponent("Text").text = itemInfo.progress .. "/" .. treasureTaskConfig.TaskValue[2][1]

end

function TreasureOfSomebodyScorePageV2:RefreshTabRedPoint()
    for i, tabInfo in ipairs(self.tabContents) do
        tabInfo.tabRedPoint:SetActive(TreasureOfSomebodyManagerV2.GetTaskTabRedPoint(i))
    end
end

function TreasureOfSomebodyScorePageV2:RefreshTaskList(context)
    if not table.indexof(context, self.selectTabIndex) then
        return
    end
    local taskList = self:GetTabTaskList(self.selectTabIndex)
    self.ScrollView:SetData(taskList, function(index, scoreItem)
        local itemData = taskList[index]
        self:SetScoreItemAdapter(scoreItem, itemData)
    end)
    self:GetRemainTime(self.selectTabIndex)
end

function TreasureOfSomebodyScorePageV2:RefreshFinishedTaskList()
    local taskList = self:GetTabTaskList(self.selectTabIndex)
    self.ScrollView:SetData(taskList, function(index, scoreItem)
        local itemData = taskList[index]
        self:SetScoreItemAdapter(scoreItem, itemData)
    end)
    self:GetRemainTime(self.selectTabIndex)
end

function TreasureOfSomebodyScorePageV2:MainPanelCallRefresh()
    local taskList = self:GetTabTaskList(self.selectTabIndex)
    self.ScrollView:SetData(taskList, function(index, scoreItem)
        local itemData = taskList[index]
        self:SetScoreItemAdapter(scoreItem, itemData)
    end)
    self:GetRemainTime(self.selectTabIndex)
end

--function TreasureOfSomebodyScorePageV2:SetRefreshTime(index)
--    if self.thread then
--        coroutine.stop(self.thread)
--        self.thread = nil
--    end
--    if index == 3 then
--        self.refreshTime.text = ""
--    else
--        local remainTime
--        if index == 1 then
--            remainTime = TreasureOfSomebodyManagerV2.GetDailyRemainTime()
--        else
--            remainTime = TreasureOfSomebodyManagerV2.GetWeekRemainTime()
--        end
--        self.thread = coroutine.start(function()
--            while true do
--                if remainTime < 1 then
--                    if index == 1 then
--                        remainTime = TreasureOfSomebodyManagerV2.GetDailyRemainTime()
--                    else
--                        remainTime = TreasureOfSomebodyManagerV2.GetWeekRemainTime()
--                    end
--                else
--                    self.refreshTime.text = "刷新时间：" .. DateUtils.GetTimeFormat(remainTime)
--                    coroutine.wait(1)
--                    remainTime = remainTime - 1
--                end
--            end
--        end)
--    end
--end
--每种礼包的剩余时间
function TreasureOfSomebodyScorePageV2:GetRemainTime(index)
    local localSelf = self
    local freshTime = 0
    local SLrefreshTime = TaskManager.GetSLrefreshTime()
    if not SLrefreshTime then return end
    if index == 1 then
        freshTime = SLrefreshTime.dayTime
    elseif index == 2 then
        freshTime = SLrefreshTime.weekTime
    elseif index == 3 then
        freshTime =  SLrefreshTime.monthTime
    end
    if not freshTime then return end
    local UpDate = function()
        if not localSelf.localTimer then
            return
        end
        local showfreshTime = freshTime - GetTimeStamp()
        if showfreshTime > 0 then
            -- 剩余小时
            local formatTime, leftHour = TimeToHMS(showfreshTime)
            if leftHour > 24 then
                self.timeText.text = GetLanguageStrById(10028)..TimeToDHMS(showfreshTime)
            else
                self.timeText.text = GetLanguageStrById(10028)..self:TimeToHMS(showfreshTime)
            end
        elseif showfreshTime == 0 then
            -- 时间到刷一下数据

            --self:GetRemainTime(index)
        elseif showfreshTime<0 then --不刷新显示内容
            self.timeText.text=""
        end
    end
    if self.localTimer then
        self.localTimer:Stop()
        self.localTimer = nil
    end
    if not self.localTimer then
        self.localTimer = Timer.New(UpDate, 1, -1, true)
        self.localTimer:Start()
    end
    UpDate()
end

-----------本模块特殊使用-----------
function TreasureOfSomebodyScorePageV2:TimeToHMS(t)
    if not t or t < 0 then
        return GetLanguageStrById(11463)
    end
    local _sec = t % 60
    local allMin = math.floor(t / 60)
    local _min = allMin % 60
    local _hour = math.floor(allMin / 60)
    return string.format(GetLanguageStrById(10503), _hour, _min, _sec), _hour, _min, _sec
end
------------------------------
return TreasureOfSomebodyScorePageV2