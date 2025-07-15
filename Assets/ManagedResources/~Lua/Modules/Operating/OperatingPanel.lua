---@class OperatingPanel
OperatingPanel = Inherit(BasePanel)
local this = OperatingPanel

local WeekMonthGiftPackPage = require("Modules/Operating/WeekMonthGiftPackPage")--每日签到
local MonthCardPage = require("Modules/Operating/MonthCardPage")--周卡
local HighMonthCardPage = require("Modules/Operating/HighMonthCardPage")--月卡
local GrowthGiftPage = require("Modules/Operating/GrowthGiftPage")--成长礼金
local ContinuityRechargePage = require("Modules/Operating/ContinuityRechargePage")
local CumulativeSignIn = require("Modules/Operating/CumulativeSignInPage") --累计签到
local AttentionGiftPage = require("Modules/Operating/AttentionGiftPage")
local UpperMonthCard = require("Modules/Operating/UppperMonthCard")--镇魔计划
local LifelongLimitBuy = require("Modules/Operating/LifelongLimitBuy")--终身限购
local WeekendWelfare = require("Modules/Operating/WeekendWelfare")--周末福利
local LifeMember = require("Modules/Operating/LifeMember")--终身会员
local SuperLiftMember = require("Modules/Operating/SuperLiftMember")--超级终身会员
local WeekCard = require("Modules/Operating/WeekCard")--豪华周卡
local WarOrder = require("Modules/Operating/WarOrder")--战令

--显示类型  type 面板类型 body 显示页签索引
local ShowType = {
    Welfare = {
        type = 1,
        body = {
            1, 2, 5, 9, 3, 10, 11, 13
        }
    },--福利
    MonthFund = {
        type = 2,
        body = {
            7, 8, 12, 14, 15
        }
    }--激励计划
}

--tab 对应 page
local TabToContent = {
    [1] = 2,
    [2] = 1,
    [3] = 1,
    [4] = 3,
    [5] = 5,
    -- [6] = 6,
    [7] = 7,
    [8] = 7,
    [9] = 8,
    [10] = 9,
    [11] = 10,
    [12] = 11,
    [13] = 12,
    [14] = 13,
    [15] = 14,
    [16] = 14,
    [17] = 14,
    [18] = 14,
    [19] = 14,
}

local kMaxTab = #TabToContent
local curIndex = 0
local showType

function OperatingPanel:InitComponent()
    self.btnBack = Util.GetGameObject(self.gameObject, "bg/btnBack")

    self.tabsContent = Util.GetGameObject(self.gameObject, "bg/tabList/viewPort/tabsContent"):GetComponent("RectTransform")
    self.operateTabs = {}
    self.selectTabs = {}
    for i = 1, kMaxTab do
        self.operateTabs[i] = Util.GetGameObject(self.tabsContent.transform, "tabs_" .. i)
        self.selectTabs[i] = Util.GetGameObject(self.operateTabs[i], "selected")
    end
    self.selectTabIndex = -1
    self.operatingContents = {
        [1] = WeekMonthGiftPackPage.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_1")),
        [2] = MonthCardPage.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_2")),
        [3] = GrowthGiftPage.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_3")),
        [4] = ContinuityRechargePage.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_4")),
        [5] = CumulativeSignIn.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_5")),
        [6] = AttentionGiftPage.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_6")),
        [7] = UpperMonthCard:New(self, Util.GetGameObject(self.transform, "bg/pageContent/page_7")),
        [8] = HighMonthCardPage.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_8")),
        [9] = LifelongLimitBuy.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_9")),
        [10] = WeekendWelfare.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_10")),
        [11] = LifeMember.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_11")),
        [12] = WeekCard.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_12")),
        [13] = SuperLiftMember.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_13")),
        [14] = WarOrder.new(self, Util.GetGameObject(self.transform, "bg/pageContent/page_14")),
    }
    table.walk(self.operatingContents, function(content)
        content:OnHide()
    end)

    self.HeadFrameView = SubUIManager.Open(SubUIConfig.PlayerHeadFrameView, self.gameObject.transform)
    self.UpView = SubUIManager.Open(SubUIConfig.UpView, self.transform, { showType = UpViewOpenType.ShowRight })

    --暂时 白图 待修复
    Util.GetGameObject(self.operateTabs[14], "Image"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_zhizunhuiyuan_02"))
    Util.GetGameObject(self.operateTabs[14], "selected/Image"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_zhizunhuiyuan_01"))
    Util.GetGameObject(self.transform, "bg/pageContent/page_13/icon"):GetComponent("Image").sprite = Util.LoadSprite(GetPictureFont("cn2-X1_zhizunhuiyuan_peitu"))
end

function OperatingPanel:BindEvent()
    Util.AddClick(self.btnBack, function()
        PlaySoundWithoutClick(SoundConfig.Sound_UICancel)
        self:ClosePanel()
    end)

    for i = 1, kMaxTab do
        Util.AddClick(self.operateTabs[i], function()
            curIndex = i
            this:OnTabChanged()
        end)
    end

    this:BindRedPoint()
end

function OperatingPanel:OnOpen(data)
    for i = 1, #self.operatingContents do
        self.operatingContents[i]:OnHide()
    end
    data = data and data or {}

    showType = data.showType or 1
    this:RefreshTabStatus()
    if data and data.tabIndex then
        curIndex = data.tabIndex
    else
        this:GetPriorityIndex()
    end
end

function OperatingPanel:OnShow()
    self.HeadFrameView:OnShow()
    self.UpView:OnOpen({showType = UpViewOpenType.ShowRight, panelType = PanelType.Main })
    SoundManager.PlayMusic(SoundConfig.BGM_Main)

    this:CheckRedPoint()
    this:RefreshTabStatus()
    if not curIndex then
        this:GetPriorityIndex()
    end
    this:OnTabChanged()
end

function OperatingPanel:OnSortingOrderChange()
end

--添加事件监听（用于子类重写）
function OperatingPanel:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MonthCard.OnMonthCardUpdate, this.RefreshActivity)
    Game.GlobalEvent:AddEvent(GameEvent.Activity.OnActivityOpenOrClose, this.RefreshActivity)
    Game.GlobalEvent:AddEvent(GameEvent.WarOrder.UnLock, this.RefreshActivity)
end

--移除事件监听（用于子类重写）
function OperatingPanel:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MonthCard.OnMonthCardUpdate, this.RefreshActivity)
    Game.GlobalEvent:RemoveEvent(GameEvent.Activity.OnActivityOpenOrClose, this.RefreshActivity)
    Game.GlobalEvent:RemoveEvent(GameEvent.WarOrder.UnLock, this.RefreshActivity)
end

function OperatingPanel:OnClose()
    this:ClearRedPoint()
end

function OperatingPanel:OnDestroy()
    SubUIManager.Close(self.HeadFrameView)
    SubUIManager.Close(self.UpView)
end

--切换面板
function this:OnTabChanged()
    for i, select in ipairs(self.selectTabs) do
        select:SetActive(i == curIndex)
    end

    for i = 1, #self.operatingContents do
        self.operatingContents[i]:OnHide()
    end

    if curIndex == 2 then
        self.operatingContents[TabToContent[curIndex]]:OnShow(self.sortingOrder, 1)
    elseif curIndex == 3 then
        self.operatingContents[TabToContent[curIndex]]:OnShow(self.sortingOrder, 2)
    elseif curIndex == 7 or curIndex == 8 then
        self.operatingContents[TabToContent[curIndex]]:OnShow(self.sortingOrder, nil, curIndex)
    elseif curIndex == 15 or curIndex == 16 or curIndex == 17 or curIndex == 18 or curIndex == 19 then
        self.operatingContents[TabToContent[curIndex]]:OnShow(curIndex)
    else
        self.operatingContents[TabToContent[curIndex]]:OnShow()
    end
end

--刷新活动
function this:RefreshActivity()
    this:CheckRedPoint()
    this:RefreshTabStatus()
    if this.operateTabs[curIndex].gameObject.activeSelf then
        this:OnTabChanged()
    else
        this:GetPriorityIndex()
        this:OnTabChanged()
    end
end

--刷新活动
function this:RefreshTabStatus()
    for n = 1, #self.operateTabs do
        self.operateTabs[n]:SetActive(false)
    end

    if showType == ShowType.Welfare.type then
        for i = 1, #ShowType.Welfare.body do
            self.operateTabs[ShowType.Welfare.body[i]]:SetActive(true)
        end
        self.operateTabs[1]:SetActive(ActivityGiftManager.IsQualifiled(ActivityTypeDef.MonthCard))
        self.operateTabs[2]:SetActive(ActivityGiftManager.IsQualifiled(ActivityTypeDef.WeekGift))
        self.operateTabs[3]:SetActive(ActivityGiftManager.IsQualifiled(ActivityTypeDef.MonthGift))
        self.operateTabs[4]:SetActive(ActivityGiftManager.GrowthGift())
        self.operateTabs[5]:SetActive(ActivityGiftManager.IsQualifiled(ActivityTypeDef.MonthSign))
        self.operateTabs[9]:SetActive(ActivityGiftManager.IsQualifiled(ActivityTypeDef.MonthCard))
        self.operateTabs[10]:SetActive(ActivityGiftManager.IsQualifiled(ActivityTypeDef.LifeMemeber) and ActivityGiftManager.LifetimeIsBuyup())
        self.operateTabs[11]:SetActive(ActivityGiftManager.IsQualifiled(ActivityTypeDef.WeekendWelfare) and not not ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.WeekendWelfare))
        self.operateTabs[13]:SetActive(ActivityGiftManager.IsQualifiled(ActivityTypeDef.WeekCard) and not not ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.WeekCard) and ActivityGiftManager.WeekIsEndTime())
    elseif showType == ShowType.MonthFund.type then
        self.operateTabs[7]:SetActive(OperatingManager.IsBaseOpen(GoodsTypeDef.MONTHCARD_128))
        self.operateTabs[8]:SetActive(OperatingManager.IsBaseOpen(GoodsTypeDef.MONTHCARD_328))
        self.operateTabs[12]:SetActive(ActivityGiftManager.IsQualifiled(ActivityTypeDef.LifeMemebr) and not not ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.LifeMemebr))
        self.operateTabs[14]:SetActive(ActivityGiftManager.IsQualifiled(ActivityTypeDef.SuperLifeMemebr) and not not ActivityGiftManager.GetActivityTypeInfo(ActivityTypeDef.SuperLifeMemebr))
        self.operateTabs[15]:SetActive(not not OperatingManager.GetWarOrderForGlobalSystemId(WarOrderType[15]))--(true)
        self.operateTabs[16]:SetActive(not not OperatingManager.GetWarOrderForGlobalSystemId(WarOrderType[16]))--(true)
        self.operateTabs[17]:SetActive(not not OperatingManager.GetWarOrderForGlobalSystemId(WarOrderType[17]))--(true)
        self.operateTabs[18]:SetActive(not not OperatingManager.GetWarOrderForGlobalSystemId(WarOrderType[18]))--(true)
        self.operateTabs[19]:SetActive(not not OperatingManager.GetWarOrderForGlobalSystemId(WarOrderType[19]))--(true)
    end

    if not RECHARGEABLE then--（是否开启充值）
        self.operateTabs[1]:SetActive(false)
        self.operateTabs[2]:SetActive(false)
        self.operateTabs[9]:SetActive(false)
        self.operateTabs[3]:SetActive(false)
        self.operateTabs[7]:SetActive(false)
        self.operateTabs[8]:SetActive(false)
    end
end

--获取活动
function this:GetPriorityIndex()
    if showType == 1 then
        for i = 1, #ShowType.Welfare.body do
            if this.operateTabs[ShowType.Welfare.body[i]].gameObject.activeSelf then
                curIndex = ShowType.Welfare.body[i]
                return
            end
        end
    elseif showType == 2 then
        for i = 1, #ShowType.MonthFund.body do
            if this.operateTabs[ShowType.MonthFund.body[i]].gameObject.activeSelf then
                curIndex = ShowType.MonthFund.body[i]
                return
            end
        end
    end
end

function this:BindRedPoint()
    -- BindRedPointObject(RedPointType.GiftPage, Util.GetGameObject(self.operateTabs[1], "redPoint"))
    BindRedPointObject(RedPointType.NobilityMonthCard, Util.GetGameObject(self.operateTabs[1], "redPoint"))
    BindRedPointObject(RedPointType.EveryWeekPreference, Util.GetGameObject(self.operateTabs[2], "redPoint"))
    BindRedPointObject(RedPointType.EveryMonthPreference, Util.GetGameObject(self.operateTabs[3], "redPoint"))
    BindRedPointObject(RedPointType.GrowthGift, Util.GetGameObject(self.operateTabs[4], "redPoint"))
    -- BindRedPointObject(RedPointType.ContinuityRecharge, Util.GetGameObject(self.operateTabs[4], "redPoint"))
    BindRedPointObject(RedPointType.CumulativeSignIn, Util.GetGameObject(self.operateTabs[5], "redPoint"))
    BindRedPointObject(RedPointType.SpecialFunds, Util.GetGameObject(self.operateTabs[7], "redPoint"))
    BindRedPointObject(RedPointType.KingMonthCard, Util.GetGameObject(self.operateTabs[9], "redPoint"))
    BindRedPointObject(RedPointType.WeekendWelfare, Util.GetGameObject(self.operateTabs[11], "redPoint"))
    BindRedPointObject(RedPointType.LifeMemeber, Util.GetGameObject(self.operateTabs[12], "redPoint"))
    BindRedPointObject(RedPointType.WeekCard, Util.GetGameObject(self.operateTabs[13], "redPoint"))
    BindRedPointObject(RedPointType.SuperLiftMember, Util.GetGameObject(self.operateTabs[14], "redPoint"))
    BindRedPointObject(RedPointType.WarOrder_Tower, Util.GetGameObject(self.operateTabs[15], "redPoint"))
    BindRedPointObject(RedPointType.WarOrder_MagicTower, Util.GetGameObject(self.operateTabs[16], "redPoint"))
    BindRedPointObject(RedPointType.WarOrder_Heresy, Util.GetGameObject(self.operateTabs[17], "redPoint"))
    BindRedPointObject(RedPointType.WarOrder_DenseFog, Util.GetGameObject(self.operateTabs[18], "redPoint"))
    BindRedPointObject(RedPointType.WarOrder_Abyss, Util.GetGameObject(self.operateTabs[19], "redPoint"))
end

function this:ClearRedPoint()
    ClearRedPointObject(RedPointType.CumulativeSignIn)
    ClearRedPointObject(RedPointType.GrowthGift)
    -- ClearRedPointObject(RedPointType.GiftPage)
    ClearRedPointObject(RedPointType.NobilityMonthCard)
    ClearRedPointObject(RedPointType.KingMonthCard)
    ClearRedPointObject(RedPointType.EveryWeekPreference)
    ClearRedPointObject(RedPointType.EveryMonthPreference)
    ClearRedPointObject(RedPointType.WeekendWelfare)
    ClearRedPointObject(RedPointType.LifeMemeber)
    ClearRedPointObject(RedPointType.WeekCard)
    ClearRedPointObject(RedPointType.SuperLiftMember)
    ClearRedPointObject(RedPointType.WarOrder_Tower)
    ClearRedPointObject(RedPointType.WarOrder_MagicTower)
    ClearRedPointObject(RedPointType.WarOrder_Heresy)
    ClearRedPointObject(RedPointType.WarOrder_DenseFog)
    ClearRedPointObject(RedPointType.WarOrder_Abyss)
    ClearRedPointObject(RedPointType.SpecialFunds)
end

function this:CheckRedPoint()
    CheckRedPointStatus(RedPointType.NobilityMonthCard)
    CheckRedPointStatus(RedPointType.EveryWeekPreference)
    CheckRedPointStatus(RedPointType.EveryMonthPreference)
    CheckRedPointStatus(RedPointType.GrowthGift)
    CheckRedPointStatus(RedPointType.ContinuityRecharg)
    CheckRedPointStatus(RedPointType.CumulativeSignIn)
    CheckRedPointStatus(RedPointType.KingMonthCard)
    CheckRedPointStatus(RedPointType.WeekendWelfare)
    CheckRedPointStatus(RedPointType.LifeMemeberFree)
    CheckRedPointStatus(RedPointType.LifeMemeberEveryDay)
    CheckRedPointStatus(RedPointType.WeekCard)
    CheckRedPointStatus(RedPointType.SuperLiftMemberEveryDay)
    CheckRedPointStatus(RedPointType.SuperLiftMemberFree)
    CheckRedPointStatus(RedPointType.SpecialFunds)
    CheckRedPointStatus(RedPointType.WarOrder_Tower)
    CheckRedPointStatus(RedPointType.WarOrder_MagicTower)
    CheckRedPointStatus(RedPointType.WarOrder_Heresy)
    CheckRedPointStatus(RedPointType.WarOrder_DenseFog)
    CheckRedPointStatus(RedPointType.WarOrder_Abyss)
end

return OperatingPanel