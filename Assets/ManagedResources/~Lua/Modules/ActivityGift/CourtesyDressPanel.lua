require("Base/BasePanel")
CourtesyDressPanel = Inherit(BasePanel)
local this = CourtesyDressPanel
local chapterList = { GetLanguageStrById(10005), GetLanguageStrById(10006), GetLanguageStrById(10007), GetLanguageStrById(10008), GetLanguageStrById(10009), GetLanguageStrById(10010), GetLanguageStrById(10011), GetLanguageStrById(10012), GetLanguageStrById(10013), GetLanguageStrById(10014), GetLanguageStrById(10015), GetLanguageStrById(10016), GetLanguageStrById(10017), GetLanguageStrById(10018), GetLanguageStrById(10019) }
local selectIndex = 0
local jumpNeedBtn = 0
local isFirstOn = true--是否首次打开页面

--初始化组件（用于子类重写）
function CourtesyDressPanel:InitComponent()
    this.BackMask = Util.GetGameObject(self.gameObject, "BackMask")
    this.btnBack = Util.GetGameObject(self.gameObject, "btnBack")
    this.remaindTimeText = Util.GetGameObject(self.gameObject, "downLayout/expertRewardGrid/remaindTimeText"):GetComponent("Text")
    this.item = Util.GetGameObject(self.gameObject, "item")
    this.onlineBtn = Util.GetGameObject(self.gameObject, "tabsContent/tabs_1")
    this.sevenDayBtn = Util.GetGameObject(self.gameObject, "tabsContent/tabs_2")
    this.chapterRewardBtn = Util.GetGameObject(self.gameObject, "tabsContent/tabs_3")
    this.selected1 = Util.GetGameObject(self.gameObject, "tabsContent/tabs_1/selected")
    this.selected2 = Util.GetGameObject(self.gameObject, "tabsContent/tabs_2/selected")
    this.selected3 = Util.GetGameObject(self.gameObject, "tabsContent/tabs_3/selected")
    this.viewRect = Util.GetGameObject(self.gameObject, "rect")
    -- this.titleBg = Util.GetGameObject(self.gameObject, "titleBg"):GetComponent("Image")
    this.onlineRedPoint = Util.GetGameObject(self.gameObject, "tabsContent/tabs_1/redPoint")
    this.sevenDayPoint = Util.GetGameObject(self.gameObject, "tabsContent/tabs_2/redPoint")
    this.chapterPoint = Util.GetGameObject(self.gameObject, "tabsContent/tabs_3/redPoint")

    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.viewRect.transform,
            this.item, nil, Vector2.New(this.viewRect.transform.rect.width, this.viewRect.transform.rect.height), 1, 1, Vector2.New(0, 5))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(0, 0)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
    this.viewCache = {}
    --this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
end

function CourtesyDressPanel:OnOpen(...)
    local data = { ... }
    this.ActivityId = data[1]
    this.hideBtns = data[2]
    this.onlineBtn:SetActive(true)
    this.sevenDayBtn:SetActive(true)
    this.chapterRewardBtn:SetActive(true)
    if this.hideBtns then
        this.onlineBtn:SetActive(false)
        this.sevenDayBtn:SetActive(false)
        this.chapterRewardBtn:SetActive(false)
    end
end

function CourtesyDressPanel:OnShow()
    isFirstOn = true

    this:IsGetRewardAll(ActivityGiftManager.sevenDayGetRewardState, ActivityTypeDef.EightDayGift, false)
    this:IsGetRewardAll(ActivityGiftManager.onlineGetRewardState, ActivityTypeDef.OnlineGift, false)
    this:IsGetRewardAll(ActivityGiftManager.chapterGetRewardState, ActivityTypeDef.ChapterAward, false)
    this.SetDataSort()
    if this.ActivityId == nil then
        this:OpenActivityPage()
    else
        this:JumpOpenActivity()
    end
    this.ScrollView:SetIndex(1)
    --this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.RoleInfo})
end

function CourtesyDressPanel:OnSortingOrderChange()
    if this.viewCache then
        for i, v in pairs(this.viewCache) do
        --for i = 1, #this.viewCache do
            for j = 1, #v.views do
                v.views[j]:SetEffectLayer(self.sortingOrder)
            end
        end
    end
end

--跳转打开页面
function CourtesyDressPanel:JumpOpenActivity()
    if this.ActivityId == ActivityTypeDef.EightDayGift then
        local getRewardState = ActivityGiftManager.sevenDayGetRewardState
        local canRewardIndex = ActivityGiftManager.canRewardDay
        local activityType = ActivityTypeDef.EightDayGift
        local data = ActivityGiftManager.sevenDayData
        this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
        selectIndex = ActivityTypeDef.EightDayGift
        self.selected1:SetActive(false)
        self.selected2:SetActive(true)
        self.selected3:SetActive(false)
    elseif this.ActivityId == ActivityTypeDef.OnlineGift then
        local getRewardState = ActivityGiftManager.onlineGetRewardState
        local canRewardIndex = ActivityGiftManager.currentTimeIndex
        local activityType = ActivityTypeDef.OnlineGift
        local data = ActivityGiftManager.onlineData
        this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
        selectIndex = ActivityTypeDef.OnlineGift
        self.selected1:SetActive(true)
        self.selected2:SetActive(false)
        self.selected3:SetActive(false)
    elseif this.ActivityId == ActivityTypeDef.ChapterAward then
        local getRewardState = ActivityGiftManager.chapterGetRewardState
        local activityType = ActivityTypeDef.ChapterAward
        local data = ActivityGiftManager.chapterGiftData
        this:OnShowActivityData(data, activityType, getRewardState, nil)
        selectIndex = ActivityTypeDef.ChapterAward
        self.selected1:SetActive(false)
        self.selected2:SetActive(false)
        self.selected3:SetActive(true)
    end
end

--主城打开页面
function CourtesyDressPanel:OpenActivityPage()
    if ActivityGiftManager.CheckOnlineRed() or ActivityGiftManager.CheckSevenDayRed() or ActivityGiftManager.CheckChapterRed() then
        if ActivityGiftManager.onlineOpen and ActivityGiftManager.CheckOnlineRed() then
            local getRewardState = ActivityGiftManager.onlineGetRewardState
            local canRewardIndex = ActivityGiftManager.currentTimeIndex
            local activityType = ActivityTypeDef.OnlineGift
            local data = ActivityGiftManager.onlineData
            this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
            selectIndex = ActivityTypeDef.OnlineGift
            self.selected1:SetActive(true)
            self.selected2:SetActive(false)
            self.selected3:SetActive(false)
        elseif ActivityGiftManager.sevenDayOpen and ActivityGiftManager.CheckSevenDayRed() then
            local getRewardState = ActivityGiftManager.sevenDayGetRewardState
            local canRewardIndex = ActivityGiftManager.canRewardDay
            local activityType = ActivityTypeDef.EightDayGift
            local data = ActivityGiftManager.sevenDayData
            this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
            selectIndex = ActivityTypeDef.EightDayGift
            self.selected1:SetActive(false)
            self.selected2:SetActive(true)
            self.selected3:SetActive(false)
        elseif ActivityGiftManager.chapterOpen and ActivityGiftManager.CheckChapterRed() then
            local getRewardState = ActivityGiftManager.chapterGetRewardState
            local activityType = ActivityTypeDef.ChapterAward
            local data = ActivityGiftManager.chapterGiftData
            this:OnShowActivityData(data, activityType, getRewardState, nil)
            selectIndex = ActivityTypeDef.ChapterAward
            self.selected1:SetActive(false)
            self.selected2:SetActive(false)
            self.selected3:SetActive(true)
        end
    else
        if ActivityGiftManager.onlineOpen then
            local getRewardState = ActivityGiftManager.onlineGetRewardState
            local canRewardIndex = ActivityGiftManager.currentTimeIndex
            local activityType = ActivityTypeDef.OnlineGift
            local data = ActivityGiftManager.onlineData
            this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
            selectIndex = ActivityTypeDef.OnlineGift
            self.selected1:SetActive(true)
            self.selected2:SetActive(false)
            self.selected3:SetActive(false)
        elseif ActivityGiftManager.sevenDayOpen then
            local getRewardState = ActivityGiftManager.sevenDayGetRewardState
            local canRewardIndex = ActivityGiftManager.canRewardDay
            local activityType = ActivityTypeDef.EightDayGift
            local data = ActivityGiftManager.sevenDayData
            this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
            selectIndex = ActivityTypeDef.EightDayGift
            self.selected1:SetActive(false)
            self.selected2:SetActive(true)
            self.selected3:SetActive(false)
        elseif ActivityGiftManager.chapterOpen then
            local getRewardState = ActivityGiftManager.chapterGetRewardState
            local activityType = ActivityTypeDef.ChapterAward
            local data = ActivityGiftManager.chapterGiftData
            this:OnShowActivityData(data, activityType, getRewardState, nil)
            selectIndex = ActivityTypeDef.ChapterAward
            self.selected1:SetActive(false)
            self.selected2:SetActive(false)
            self.selected3:SetActive(true)
        end
    end
end

--展示活动数据
function CourtesyDressPanel:OnShowActivityData(activityData, activityType, getRewardState, isCanReward)
    -- if (activityType == ActivityTypeDef.EightDayGift) then
    --     this.titleBg.sprite = Util.LoadSprite("r_huodong_qitian")
    -- elseif (activityType == ActivityTypeDef.OnlineGift) then
    --     this.titleBg.sprite = Util.LoadSprite("r_huodong_zaixian")
    -- elseif (activityType == ActivityTypeDef.ChapterAward) then
    --     this.titleBg.sprite = Util.LoadSprite("r_huodong_tongguan")
    -- end
    -- local itemList = {}
    this.ScrollView:SetData(activityData, function(index, item)
        -- itemList[index] = item
        local shows = activityData[index].Reward
        if this.viewCache[item] then
            local viewCacheNum
            local viewCacheItem = { views = {} }
            viewCacheNum = table.nums(this.viewCache[item].views)
            if viewCacheNum < #shows then
                for i = 1, viewCacheNum do
                    this.viewCache[item].views[i].gameObject:SetActive(true)
                    this.viewCache[item].views[i]:OnOpen(false, { shows[i][1], shows[i][2] }, 1,false,false,true,self.sortingOrder)
                    viewCacheItem.views[i] = this.viewCache[item].views[i]
                end
                for i = viewCacheNum + 1, #shows do
                    --his.viewCache[item].views[i].gameObject:SetActive(true)
                    local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetTransform(item, "content").transform)
                    view:OnOpen(false, { shows[i][1], 0 }, 1,false,false,true,self.sortingOrder)
                    viewCacheItem.views[i] = view
                end
                this.viewCache[item] = viewCacheItem
            else
                for i = 1, #shows do
                    this.viewCache[item].views[i].gameObject:SetActive(true)
                    this.viewCache[item].views[i]:OnOpen(false, { shows[i][1], shows[i][2] }, 1,false,false,true,self.sortingOrder)
                end
                for i = #shows + 1, viewCacheNum do
                    this.viewCache[item].views[i].gameObject:SetActive(false)
                end
            end
            this:ScrollActivityDataShow(item, index, activityData[index], activityType, getRewardState, isCanReward)
        else
            local viewCacheItem = { views = {} }
            for i = 1, #shows do
                local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetTransform(item, "content").transform)
                view:OnOpen(false, { shows[i][1], shows[i][2] }, 1,false,false,true,self.sortingOrder)
                viewCacheItem.views[i] = view
            end
            this.viewCache[item] = viewCacheItem
            this:ScrollActivityDataShow(item, index, activityData[index], activityType, getRewardState, isCanReward)
        end
        --this:ScrollActivityDataShow(item, index, activityData[index], activityType, getRewardState, isCanReward)
    end)
    if activityType == ActivityTypeDef.OnlineGift then--写在这的原因是先实例化完毕之后再在线奖励再计时显示
        self:RemainTimeDown()
    end

    -- if isFirstOn then
    --     DelayCreation(itemList)
    --     isFirstOn = false
    -- end
end



--循环滚动活动数据
function CourtesyDressPanel:ScrollActivityDataShow(item, index, data, activityType, getRewardState, isCanReward)
    --Util.ClearChild(Util.GetTransform(item, "content").transform)
    --for i, v in ipairs(data.Reward) do
    --    local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetTransform(item, "content").transform)
    --    view:OnOpen(false, { v[1], v[2] }, 1)
    --end
    local getRewardProgressValue = 0
    for i, v in pairs(getRewardState) do
        if v == 1 then
            getRewardProgressValue = getRewardProgressValue + 1
        end
    end
    local titleText = Util.GetGameObject(item, "titleImage/titleText"):GetComponent("Text")
    local nextOpenBtn = Util.GetGameObject(item, "nextDayOpenBtn")
    local nextOpenBtnText = Util.GetGameObject(item, "nextDayOpenBtn/Text"):GetComponent("Text")
    local getRewardBtn = Util.GetGameObject(item, "getRewardBtn")
    local getFinishText = Util.GetGameObject(item, "getFinishText")
    local getRewardProgress = Util.GetGameObject(item, "getRewardProgress"):GetComponent("Text")
    --local redPoint = Util.GetGameObject(item, "getRewardBtn/redPoint")
    if activityType == ActivityTypeDef.EightDayGift then
        titleText.text = GetLanguageStrById(10020) .. GetLanguageStrById(data.Sort) .. GetLanguageStrById(10021)
        -- nextOpenBtn:GetComponent("Image").sprite = Util.LoadSprite("s_slbz_1anniuhuise") --n1
        nextOpenBtnText.text = GetLanguageStrById(10022)
        this.remaindTimeText.text = ""
    elseif activityType == ActivityTypeDef.OnlineGift then
        local onlineData = ActivityGiftManager.onlineData
        for i, v in ipairs(onlineData) do
            if v.Sort == data.Sort then
                titleText.text = GetLanguageStrById(tostring(v.ContentsShow))
            end
        end
        nextOpenBtnText.text = GetLanguageStrById(10022)
    elseif activityType == ActivityTypeDef.ChapterAward then
        titleText.text = GetLanguageStrById(data.ContentsShow)
        -- nextOpenBtn:GetComponent("Image").sprite = Util.LoadSprite("s_slbz_1anniuhuangse") --n1
        nextOpenBtnText.text = GetLanguageStrById(10023)
        this.remaindTimeText.text = ""
    end
    if activityType ~= ActivityTypeDef.ChapterAward then
        if data.Sort >= isCanReward then
            getRewardBtn:SetActive(false)
            getFinishText:SetActive(false)
            nextOpenBtn:SetActive(true)
            getRewardProgress.text = "(0/1)"
        end
        if data.Sort <= isCanReward and getRewardState[data.Id] == 0 then
            getRewardBtn:SetActive(true)
            getFinishText:SetActive(false)
            nextOpenBtn:SetActive(false)
            --redPoint:SetActive(true)
            getRewardProgress.text = "(1/1)"
            if index == 1 then
                jumpNeedBtn = getRewardBtn
            end
        end
        if  getRewardState[data.Id] == 1 then--data.Sort <= isCanReward and
            getRewardBtn:SetActive(false)
            getFinishText:SetActive(true)
            nextOpenBtn:SetActive(false)
            getRewardProgress.text = "(1/1)"
        end
    else
        local isPass = FightPointPassManager.GetFightStateById(data.Values[1][1]) == FIGHT_POINT_STATE.PASS
        if isPass and getRewardState[data.Id] == 0 then
            getRewardBtn:SetActive(true)
            getFinishText:SetActive(false)
            nextOpenBtn:SetActive(false)
            getRewardProgress.text = "(1/1)"
            if index == 1 then
                jumpNeedBtn = getRewardBtn
            end
        elseif isPass and getRewardState[data.Id] == 1 then
            getRewardBtn:SetActive(false)
            getFinishText:SetActive(true)
            nextOpenBtn:SetActive(false)
            getRewardProgress.text = "(1/1)"
        else
            getRewardBtn:SetActive(false)
            getFinishText:SetActive(false)
            nextOpenBtn:SetActive(true)
            getRewardProgress.text = "(0/1)"
        end
    end
    Util.AddOnceClick(getRewardBtn, function()
        if activityType == ActivityTypeDef.EightDayGift then
            ActivityGiftManager.GetActivityRewardRequest(ActivityTypeDef.EightDayGift, data.Id)
        elseif activityType == ActivityTypeDef.OnlineGift then
            ActivityGiftManager.GetActivityRewardRequest(ActivityTypeDef.OnlineGift, data.Id)
        elseif activityType == ActivityTypeDef.ChapterAward then
            ActivityGiftManager.GetActivityRewardRequest(ActivityTypeDef.ChapterAward, data.Id)
        end
    end)
    Util.AddOnceClick(nextOpenBtn, function()
        if activityType == ActivityTypeDef.ChapterAward then
            --前往跳转
            JumpManager.GoJump(data.Jump[1])
        end
    end)
end
--绑定事件（用于子类重写）
function CourtesyDressPanel:BindEvent()
    Util.AddClick(self.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(self.BackMask, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)
    Util.AddClick(self.onlineBtn, function()
        local getRewardState = ActivityGiftManager.onlineGetRewardState
        local canRewardIndex = ActivityGiftManager.currentTimeIndex
        local activityType = ActivityTypeDef.OnlineGift
        local data = ActivityGiftManager.onlineData
        this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
        self.selected1:SetActive(true)
        self.selected2:SetActive(false)
        self.selected3:SetActive(false)
        selectIndex = ActivityTypeDef.OnlineGift
        this.ScrollView:SetIndex(1)
    end)
    Util.AddClick(self.sevenDayBtn, function()
        local getRewardState = ActivityGiftManager.sevenDayGetRewardState
        local canRewardIndex = ActivityGiftManager.canRewardDay
        local activityType = ActivityTypeDef.EightDayGift
        local data = ActivityGiftManager.sevenDayData
        this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
        self.selected1:SetActive(false)
        self.selected2:SetActive(true)
        self.selected3:SetActive(false)
        selectIndex = ActivityTypeDef.EightDayGift
        this.ScrollView:SetIndex(1)
    end)
    Util.AddClick(self.chapterRewardBtn, function()
        local getRewardState = ActivityGiftManager.chapterGetRewardState
        local activityType = ActivityTypeDef.ChapterAward
        local data = ActivityGiftManager.chapterGiftData
        this:OnShowActivityData(data, activityType, getRewardState, nil)
        self.selected1:SetActive(false)
        self.selected2:SetActive(false)
        self.selected3:SetActive(true)
        selectIndex = ActivityTypeDef.ChapterAward
        this.ScrollView:SetIndex(1)
    end)
    BindRedPointObject(RedPointType.CourtesyDress_Online, this.onlineRedPoint)
    BindRedPointObject(RedPointType.CourtesyDress_SevenDay, this.sevenDayPoint)
    BindRedPointObject(RedPointType.CourtesyDress_Chapter, this.chapterPoint)
end
-- 在线奖励倒计时
function CourtesyDressPanel:OnlineCountDown(remainTime, activityData,onlineTime)
    --local hour = 0
    --local min = 0
    --local sec = 0
    --sec = math.floor(remainTime % 60)
    --hour = math.floor(remainTime / 3600)
    --min = 0
    --if (hour >= 1) then
    --    min = math.floor((remainTime - hour * 3600) / 60)
    --else
    --    min = math.floor(remainTime / 60)
    --end
    if selectIndex == ActivityTypeDef.OnlineGift then
        this.remaindTimeText.text = GetLanguageStrById(10024) ..TimeToHMS(onlineTime) --string.format("%02d:%02d:%02d", hour, min, sec)
        if ActivityGiftManager.currentTimeIndex == #ActivityGiftManager.onlineData then
            this.remaindTimeText.text = ""
        end
        local getRewardState = ActivityGiftManager.onlineGetRewardState
        if remainTime == 0 then
            this:OnShowActivityData(activityData, selectIndex, getRewardState, ActivityGiftManager.currentTimeIndex)
        end
    end
end

--领取奖励刷新页面数据
function CourtesyDressPanel:OnRefreshPageDataShow(activityData)
    local canRewardIndex = 0
    local getRewardState = 0
    if selectIndex == ActivityTypeDef.EightDayGift then
        canRewardIndex = ActivityGiftManager.canRewardDay
        getRewardState = ActivityGiftManager.sevenDayGetRewardState
    elseif selectIndex == ActivityTypeDef.OnlineGift then
        canRewardIndex = ActivityGiftManager.currentTimeIndex
        getRewardState = ActivityGiftManager.onlineGetRewardState
    elseif selectIndex == ActivityTypeDef.ChapterAward then
        getRewardState = ActivityGiftManager.chapterGetRewardState
    end
    this:OnShowActivityData(activityData, selectIndex, getRewardState, canRewardIndex)
    this:IsGetRewardAll(getRewardState, selectIndex, true)

end

--判断奖励是否领取完毕
function CourtesyDressPanel:IsGetRewardAll(getRewardState, activityType, isInActivityPage)
    local isGetAllReward = true
    for i, v in pairs(getRewardState) do
        if v == 0 then
            isGetAllReward = false
        end
    end
    if activityType == ActivityTypeDef.EightDayGift and isGetAllReward then
        this.sevenDayBtn:SetActive(false)
        ActivityGiftManager.sevenDayOpen = false
        if (isInActivityPage) then
            --UIManager.OpenPanel(UIName.MainPanel)
        end
    elseif activityType == ActivityTypeDef.OnlineGift and isGetAllReward then
        this.onlineBtn:SetActive(false)
        ActivityGiftManager.onlineOpen = false
        if isInActivityPage then
            --UIManager.OpenPanel(UIName.MainPanel)
            self:ClosePanel()
        end
    elseif activityType == ActivityTypeDef.ChapterAward and isGetAllReward then
        this.chapterRewardBtn:SetActive(false)
        ActivityGiftManager.chapterOpen = false
        if (isInActivityPage) then
            --UIManager.OpenPanel(UIName.MainPanel)
        end
    end
end

--刷新循环滚动数据
function this.RefreshScrollData()
    this.ScrollView:SetData(activityData, function(index, item)
        this:ScrollActivityDataShow(item, index, activityData[index], activityType, getRewardState, isCanReward)
    end)
end
--进行数据排序
function this.SetDataSort()
    table.sort(ActivityGiftManager.onlineData, function(a, b)
        if ActivityGiftManager.onlineGetRewardState[a.Id] == ActivityGiftManager.onlineGetRewardState[b.Id] then
            return a.Id < b.Id
        else
            return ActivityGiftManager.onlineGetRewardState[a.Id] < ActivityGiftManager.onlineGetRewardState[b.Id]
        end
    end)

    -- table.sort(ActivityGiftManager.sevenDayData, function(a, b)
    --     if ActivityGiftManager.sevenDayGetRewardState[a.Id] == ActivityGiftManager.sevenDayGetRewardState[b.Id] then
    --         return a.Id < b.Id
    --     else
    --         return ActivityGiftManager.sevenDayGetRewardState[a.Id] < ActivityGiftManager.sevenDayGetRewardState[b.Id]
    --     end
    -- end)
    table.sort(ActivityGiftManager.chapterGiftData, function(a, b)
        if ActivityGiftManager.chapterGetRewardState[a.Id] == ActivityGiftManager.chapterGetRewardState[b.Id] then
            return a.Id < b.Id
        else
            return ActivityGiftManager.chapterGetRewardState[a.Id] < ActivityGiftManager.chapterGetRewardState[b.Id]
        end
    end)
end

--提供跳转的领取按钮
function this.GetRewardBtn()
    return jumpNeedBtn
end

--添加事件监听（用于子类重写）
function CourtesyDressPanel:AddListener()
    --Game.GlobalEvent:AddEvent(GameEvent.Activity.OnlineState, this.OnlineCountDown, self)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.GetRewardRefresh, this.OnRefreshPageDataShow, self)
end

--移除事件监听（用于子类重写）
function CourtesyDressPanel:RemoveListener()
    --Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnlineState, this.OnlineCountDown, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.GetRewardRefresh, this.OnRefreshPageDataShow, self)
end


--界面关闭时调用（用于子类重写）
function CourtesyDressPanel:OnClose()
    if  self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function CourtesyDressPanel:OnDestroy()
    ClearRedPointObject(RedPointType.CourtesyDress_Online)
    ClearRedPointObject(RedPointType.CourtesyDress_SevenDay)
    ClearRedPointObject(RedPointType.CourtesyDress_Chapter)
    --SubUIManager.Close(this.UpView)
    this.ScrollView = nil
end

--跳转显示新手提示圈
function this.ShowGuideGo()
    if jumpNeedBtn ~= 0 then
        JumpManager.ShowGuide(UIName.CourtesyDressPanel, jumpNeedBtn)
    end
end
--在线奖励刷新
--刷新倒计时显示
function CourtesyDressPanel:RemainTimeDown()
    self:RemainTimeDownUpdata()
    if ActivityGiftManager.currentTimeIndex == #ActivityGiftManager.onlineData then
        this.remaindTimeText.text = ""
    end
        if self.timer then
            self.timer:Stop()
            self.timer = nil
        end
        self.timer = Timer.New(function()
            if NetManager.IsConnect() then--是否在线状态
                self:RemainTimeDownUpdata()
            end
            if ActivityGiftManager.currentTimeIndex == #ActivityGiftManager.onlineData then
                self.timer:Stop()
                self.timer = nil
                this.remaindTimeText.text = ""
            end
        end, 1, -1, true)
        self.timer:Start()
end
function CourtesyDressPanel:RemainTimeDownUpdata()
    local timeNum = GetTimeStamp() - ActivityGiftManager.cuOnLineTimestamp
    this.remaindTimeText.text =   GetLanguageStrById(10024)..TimeToHMS(timeNum)

    local newSort = 0
    for i = 1, #ActivityGiftManager.onlineData do
        if ActivityGiftManager.onlineGetRewardState[ActivityGiftManager.onlineData[i].Id] == 0 then
            local curValue = ActivityGiftManager.onlineData[i].Values[1][1]*60
            local curSort = ActivityGiftManager.onlineData[i].Sort
            if math.floor(timeNum) >= curValue and newSort < curSort then
                newSort = curSort
            end
        end
    end

    if newSort ~= ActivityGiftManager.currentTimeIndex then
        ActivityGiftManager.currentTimeIndex = newSort
        this:OnShowActivityData(ActivityGiftManager.onlineData, ActivityTypeDef.OnlineGift, ActivityGiftManager.onlineGetRewardState, ActivityGiftManager.currentTimeIndex)
    end
end
return CourtesyDressPanel