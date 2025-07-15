local SevenDayGift = quick_class("SevenDayGift")
local this = SevenDayGift
local selectIndex = 0
local jumpNeedBtn = 0
function SevenDayGift:ctor(mainPanel, gameObject)
    self.mainPanel = mainPanel
    self.gameObject = gameObject
    self:InitComponent(gameObject)
    self:BindEvent()
end

function SevenDayGift:InitComponent(gameObject)
    self.itemPre = Util.GetGameObject(gameObject, "Bg/ItemPre")
    this.btnBack = Util.GetGameObject(gameObject, "btnBack")
    this.remaindTimeText = Util.GetGameObject(gameObject, "downLayout/expertRewardGrid/remaindTimeText"):GetComponent("Text")
    this.item = Util.GetGameObject(gameObject, "item")
    this.onlineBtn = Util.GetGameObject(gameObject, "tabsContent/tabs_1")
    this.sevenDayBtn = Util.GetGameObject(gameObject, "tabsContent/tabs_2")
    this.chapterRewardBtn = Util.GetGameObject(gameObject, "tabsContent/tabs_3")
    this.selected1 = Util.GetGameObject(gameObject, "tabsContent/tabs_1/selected")
    this.selected2 = Util.GetGameObject(gameObject, "tabsContent/tabs_2/selected")
    this.selected3 = Util.GetGameObject(gameObject, "tabsContent/tabs_3/selected")
    this.viewRect = Util.GetGameObject(gameObject, "rect")
    this.titleBg = Util.GetGameObject(gameObject, "titleBg"):GetComponent("Image")
    this.onlineRedPoint = Util.GetGameObject(gameObject, "tabsContent/tabs_1/redPoint")
    this.sevenDayPoint = Util.GetGameObject(gameObject, "tabsContent/tabs_2/redPoint")
    this.chapterPoint = Util.GetGameObject(gameObject, "tabsContent/tabs_3/redPoint")

    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.viewRect.transform,
            this.item, nil, Vector2.New(940.6, 1220), 1, 1, Vector2.New(0, 0))
    this.ScrollView.gameObject:GetComponent("RectTransform").anchoredPosition = Vector2.New(-8, 0)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMin = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").anchorMax = Vector2.New(0.5, 0.5)
    this.ScrollView.gameObject:GetComponent("RectTransform").pivot = Vector2.New(0.5, 0.5)
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2
    this.viewCache = {}
    --this.UpView = SubUIManager.Open(SubUIConfig.UpView, self.gameObject.transform, { showType = UpViewOpenType.ShowLeft })
end

function SevenDayGift:BindEvent()
    Util.AddClick(self.btnBack, function()
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
        local activityType = ActivityTypeDef.SevenDayRegister
        local data = ActivityGiftManager.sevenDayData
        this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
        self.selected1:SetActive(false)
        self.selected2:SetActive(true)
        self.selected3:SetActive(false)
        selectIndex = ActivityTypeDef.SevenDayRegister
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

function SevenDayGift:OnOpen()
    --local data = { ... }
    --this.ActivityId = data[1]
    --this.hideBtns=data[2]
    --this.onlineBtn:SetActive(true)
    --this.sevenDayBtn:SetActive(true)
    --this.chapterRewardBtn:SetActive(true)
    --if(this.hideBtns) then
        this.onlineBtn:SetActive(false)
        this.sevenDayBtn:SetActive(false)
        this.chapterRewardBtn:SetActive(false)
    --end
end
local sortingOrder = 0
function SevenDayGift:OnShow(_sortingOrder)
    sortingOrder = _sortingOrder
    this:IsGetRewardAll(ActivityGiftManager.sevenDayGetRewardState, ActivityTypeDef.SevenDayRegister, false)
    this:IsGetRewardAll(ActivityGiftManager.onlineGetRewardState, ActivityTypeDef.OnlineGift, false)
    this:IsGetRewardAll(ActivityGiftManager.chapterGetRewardState, ActivityTypeDef.ChapterAward, false)
    this.SetDataSort()
    if (this.ActivityId == nil) then
        this:OpenActivityPage()
    else
        this:JumpOpenActivity()
    end
    this.ScrollView:SetIndex(1)
    --this.UpView:OnOpen({ showType = UpViewOpenType.ShowLeft, panelType = PanelType.RoleInfo})
end

function SevenDayGift:OnSortingOrderChange(cursortingOrder)
    if this.viewCache then
        for i, v in pairs(this.viewCache) do
            for j = 1, #v.views do
                v.views[j]:SetEffectLayer(cursortingOrder)
            end
        end
    end
end
--跳转打开页面
function SevenDayGift:JumpOpenActivity()
    if (this.ActivityId == ActivityTypeDef.SevenDayRegister) then
        local getRewardState = ActivityGiftManager.sevenDayGetRewardState
        local canRewardIndex = ActivityGiftManager.canRewardDay
        local activityType = ActivityTypeDef.SevenDayRegister
        local data = ActivityGiftManager.sevenDayData
        this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
        selectIndex = ActivityTypeDef.SevenDayRegister
        self.selected1:SetActive(false)
        self.selected2:SetActive(true)
        self.selected3:SetActive(false)
    elseif (this.ActivityId == ActivityTypeDef.OnlineGift) then
        local getRewardState = ActivityGiftManager.onlineGetRewardState
        local canRewardIndex = ActivityGiftManager.currentTimeIndex
        local activityType = ActivityTypeDef.OnlineGift
        local data = ActivityGiftManager.onlineData
        this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
        selectIndex = ActivityTypeDef.OnlineGift
        self.selected1:SetActive(true)
        self.selected2:SetActive(false)
        self.selected3:SetActive(false)
    elseif (this.ActivityId == ActivityTypeDef.ChapterAward) then
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
function SevenDayGift :OpenActivityPage()
        if (ActivityGiftManager.sevenDayOpen) then
            local getRewardState = ActivityGiftManager.sevenDayGetRewardState
            local canRewardIndex = ActivityGiftManager.canRewardDay
            local activityType = ActivityTypeDef.SevenDayRegister
            local data = ActivityGiftManager.sevenDayData
            this:OnShowActivityData(data, activityType, getRewardState, canRewardIndex)
            selectIndex = ActivityTypeDef.SevenDayRegister
        end
end
--展示活动数据
function SevenDayGift:OnShowActivityData(activityData, activityType, getRewardState, isCanReward)
    if (activityType == ActivityTypeDef.SevenDayRegister) then
        this.titleBg.sprite = Util.LoadSprite("r_huodong_qitian")
    elseif (activityType == ActivityTypeDef.OnlineGift) then
        this.titleBg.sprite = Util.LoadSprite("r_huodong_zaixian")
    elseif (activityType == ActivityTypeDef.ChapterAward) then
        this.titleBg.sprite = Util.LoadSprite("r_huodong_tongguan")
    end
    this.ScrollView:SetData(activityData, function(index, item)
        local shows = activityData[index].Reward
        if this.viewCache[item] then
            local viewCacheNum
            local viewCacheItem = { views = {} }
            viewCacheNum = table.nums(this.viewCache[item].views)
            if (viewCacheNum < #shows) then
                for i = 1, viewCacheNum do
                    this.viewCache[item].views[i].gameObject:SetActive(true)
                    this.viewCache[item].views[i]:OnOpen(false, { shows[i][1], shows[i][2] }, 1,false,false,false,sortingOrder)
                    viewCacheItem.views[i] = this.viewCache[item].views[i]
                end
                for i = viewCacheNum + 1, #shows do
                    --his.viewCache[item].views[i].gameObject:SetActive(true)
                    local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetTransform(item, "content").transform)
                    view:OnOpen(false, { shows[i][1], 0 },1,false,false,false,sortingOrder)
                    viewCacheItem.views[i] = view
                end
                this.viewCache[item] = viewCacheItem
            else
                for i = 1, #shows do
                    this.viewCache[item].views[i].gameObject:SetActive(true)
                    this.viewCache[item].views[i]:OnOpen(false, { shows[i][1], shows[i][2] }, 1,false,false,false,sortingOrder)
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
                view:OnOpen(false, { shows[i][1], shows[i][2] }, 1,false,false,false,sortingOrder)
                viewCacheItem.views[i] = view
            end
            this.viewCache[item] = viewCacheItem
            this:ScrollActivityDataShow(item, index, activityData[index], activityType, getRewardState, isCanReward)
        end
        --this:ScrollActivityDataShow(item, index, activityData[index], activityType, getRewardState, isCanReward)
    end)
end
--循环滚动活动数据
function SevenDayGift:ScrollActivityDataShow(item, index, data, activityType, getRewardState, isCanReward)
    --Util.ClearChild(Util.GetTransform(item, "content").transform)
    --for i, v in ipairs(data.Reward) do
    --    local view = SubUIManager.Open(SubUIConfig.ItemView, Util.GetTransform(item, "content").transform)
    --    view:OnOpen(false, { v[1], v[2] }, 1)
    --end
    local getRewardProgressValue = 0
    for i, v in pairs(getRewardState) do
        if (v == 1) then
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
    if (activityType == ActivityTypeDef.SevenDayRegister) then
        titleText.text = GetLanguageStrById(10020) .. data.Sort .. GetLanguageStrById(10021)
        nextOpenBtn:GetComponent("Image").sprite = Util.LoadSprite("s_slbz_1anniuhuise")
        nextOpenBtnText.text = GetLanguageStrById(10022)
        --this.remaindTimeText.text = ""
    elseif (activityType == ActivityTypeDef.OnlineGift) then
        titleText.text = GetLanguageStrById(10035) .. data.Values[1][1] .. GetLanguageStrById(10036)
        nextOpenBtn:GetComponent("Image").sprite = Util.LoadSprite("s_slbz_1anniuhuise")
        nextOpenBtnText.text = GetLanguageStrById(10022)
    elseif (activityType == ActivityTypeDef.ChapterAward) then
        titleText.text =data.ContentsShow
        nextOpenBtn:GetComponent("Image").sprite = Util.LoadSprite("s_slbz_1anniuhuangse")
        nextOpenBtnText.text = GetLanguageStrById(10023)
        --this.remaindTimeText.text = ""
    end

    if (activityType ~= ActivityTypeDef.ChapterAward) then
        if (data.Sort >= isCanReward) then
            getRewardBtn:SetActive(false)
            getFinishText:SetActive(false)
            nextOpenBtn:SetActive(true)
            getRewardProgress .text = "(0/1)"
        end
        if (data.Sort <= isCanReward and getRewardState[data.Id] == 0) then
            getRewardBtn:SetActive(true)
            getFinishText:SetActive(false)
            nextOpenBtn:SetActive(false)
            --redPoint:SetActive(true)
            getRewardProgress .text = "(1/1)"
            if (index == 1) then
                jumpNeedBtn = getRewardBtn
            end
        end
        if (data.Sort <= isCanReward and getRewardState[data.Id] == 1) then
            getRewardBtn:SetActive(false)
            getFinishText:SetActive(true)
            nextOpenBtn:SetActive(false)
            getRewardProgress .text = "(1/1)"
        end
    else
        if (FightPointPassManager.IsChapterPass(data.Sort) and getRewardState[data.Id] == 0) then
            getRewardBtn:SetActive(true)
            getFinishText:SetActive(false)
            nextOpenBtn:SetActive(false)
            getRewardProgress .text = "(1/1)"
            if (index == 1) then
                jumpNeedBtn = getRewardBtn
            end
        elseif (FightPointPassManager.IsChapterPass(data.Sort) and getRewardState[data.Id] == 1) then
            getRewardBtn:SetActive(false)
            getFinishText:SetActive(true)
            nextOpenBtn:SetActive(false)
            getRewardProgress .text = "(1/1)"
        elseif (not FightPointPassManager.IsChapterPass(data.Sort)) then
            getRewardBtn:SetActive(false)
            getFinishText:SetActive(false)
            nextOpenBtn:SetActive(true)
            getRewardProgress .text = "(0/1)"
        end
    end
    Util.AddOnceClick(getRewardBtn, function()
        if (activityType == ActivityTypeDef.SevenDayRegister) then
            ActivityGiftManager.GetActivityRewardRequest(ActivityTypeDef.SevenDayRegister, data.Id)
        elseif (activityType == ActivityTypeDef.OnlineGift) then
            ActivityGiftManager.GetActivityRewardRequest(ActivityTypeDef.OnlineGift, data.Id)
        elseif (activityType == ActivityTypeDef.ChapterAward) then
            ActivityGiftManager.GetActivityRewardRequest(ActivityTypeDef.ChapterAward, data.Id)
        end
    end)
    Util.AddOnceClick(nextOpenBtn, function()
        if (activityType == ActivityTypeDef.ChapterAward) then
            --前往跳转
            JumpManager.GoJump(data.Jump[1])
        end
    end)
end
-- 在线奖励倒计时
function SevenDayGift:OnlineCountDown(remainTime, activityData)
    local hour = 0
    local min = 0
    local sec = 0
    sec = math.floor(remainTime % 60)
    hour = math.floor(remainTime / 3600)
    min = 0
    if (hour >= 1) then
        min = math.floor((remainTime - hour * 3600) / 60)
    else
        min = math.floor(remainTime / 60)
    end
    if (selectIndex == ActivityTypeDef.OnlineGift) then
        this.remaindTimeText.text = GetLanguageStrById(10037) .. string.format("%02d:%02d:%02d", hour, min, sec)
        if (ActivityGiftManager.currentTimeIndex == #ActivityGiftManager.onlineData) then
            this.remaindTimeText.text = ""
        end
        local getRewardState = ActivityGiftManager.onlineGetRewardState
        if (remainTime == 0) then
            this:OnShowActivityData(activityData, selectIndex, getRewardState, ActivityGiftManager.currentTimeIndex)
        end
    end

end
--领取奖励刷新页面数据
function SevenDayGift:OnRefreshPageDataShow()
    local canRewardIndex = 0
    local getRewardState = 0
    selectIndex = ActivityTypeDef.SevenDayRegister
    if (selectIndex == ActivityTypeDef.SevenDayRegister) then
        canRewardIndex = ActivityGiftManager.canRewardDay
        getRewardState = ActivityGiftManager.sevenDayGetRewardState
    elseif (selectIndex == ActivityTypeDef.OnlineGift) then
        canRewardIndex = ActivityGiftManager.currentTimeIndex
        getRewardState = ActivityGiftManager.onlineGetRewardState
    elseif (selectIndex == ActivityTypeDef.ChapterAward) then
        getRewardState = ActivityGiftManager.chapterGetRewardState
    end
    this:OnShowActivityData(ActivityGiftManager.sevenDayData, selectIndex, getRewardState, canRewardIndex)
    this:IsGetRewardAll(getRewardState, selectIndex, true)

end
--判断奖励是否领取完毕
function SevenDayGift:IsGetRewardAll(getRewardState, activityType, isInActivityPage)
    local isGetAllReward = true
    for i, v in pairs(getRewardState) do
        if (v == 0) then
            isGetAllReward = false
        end
    end
    if (activityType == ActivityTypeDef.SevenDayRegister and isGetAllReward) then
        this.sevenDayBtn:SetActive(false)
        ActivityGiftManager.sevenDayOpen = false
        if (isInActivityPage) then
            --UIManager.OpenPanel(UIName.MainPanel)
        end
    elseif (activityType == ActivityTypeDef.OnlineGift and isGetAllReward) then
        this.onlineBtn:SetActive(false)
        ActivityGiftManager.onlineOpen = false
        if (isInActivityPage) then
            --UIManager.OpenPanel(UIName.MainPanel)
        end
    elseif (activityType == ActivityTypeDef.ChapterAward and isGetAllReward) then
        this.chapterRewardBtn:SetActive(false)
        ActivityGiftManager.chapterOpen = false
        if (isInActivityPage) then
            --UIManager.OpenPanel(UIName.MainPanel)
        end
    end
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

    table.sort(ActivityGiftManager.sevenDayData, function(a, b)
        if ActivityGiftManager.sevenDayGetRewardState[a.Id] == ActivityGiftManager.sevenDayGetRewardState[b.Id] then
            return a.Id < b.Id
        else
            return ActivityGiftManager.sevenDayGetRewardState[a.Id] < ActivityGiftManager.sevenDayGetRewardState[b.Id]
        end
    end)
    table.sort(ActivityGiftManager.chapterGiftData, function(a, b)
        if ActivityGiftManager.chapterGetRewardState[a.Id] and ActivityGiftManager.chapterGetRewardState[b.Id] then
            if ActivityGiftManager.chapterGetRewardState[a.Id] == ActivityGiftManager.chapterGetRewardState[b.Id] then
                return a.Id < b.Id
            else
                return ActivityGiftManager.chapterGetRewardState[a.Id] < ActivityGiftManager.chapterGetRewardState[b.Id]
            end
        else
            return ActivityGiftManager.chapterGetRewardState[a.Id] and not ActivityGiftManager.chapterGetRewardState[b.Id]
        end
    end)
end

--添加事件监听（用于子类重写）
function SevenDayGift:AddListener()
    --Game.GlobalEvent:AddEvent(GameEvent.Activity.OnlineState, this.OnlineCountDown, self)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.GetRewardRefresh, this.OpenActivityPage, self)
end

--移除事件监听（用于子类重写）
function SevenDayGift:RemoveListener()
    --Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnlineState, this.OnlineCountDown, self)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.GetRewardRefresh, this.OpenActivityPage, self)
end
--跳转显示新手提示圈
function SevenDayGift.ShowGuideGo()
    if jumpNeedBtn ~= 0 then
        JumpManager.ShowGuide(UIName.CourtesyDressPanel, jumpNeedBtn)
    end
end

function SevenDayGift:OnDestroy()
    ClearRedPointObject(RedPointType.CourtesyDress_Online)
    ClearRedPointObject(RedPointType.CourtesyDress_SevenDay)
    ClearRedPointObject(RedPointType.CourtesyDress_Chapter)
    --SubUIManager.Close(this.UpView)
    this.ScrollView = nil
    sortingOrder = 0
end


return SevenDayGift