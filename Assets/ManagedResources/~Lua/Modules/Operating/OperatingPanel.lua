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

--==================== 开启动画：页签逐格翻入 + 内容区从上往下落位 ====================
-- 参考 Assets/Art/UIAni/cn2-X1_UI_SevenDayCarnivalPanelV2.anim（9 条曲线）：
--   ① bg/daysTabBg/tabsGroup/day_1..7 的 m_LocalScale.x 0→1，0.1667s/格，相邻错开 0.0333s；
--   ② bg 上还有两条 m_FloatCurves：m_SizeDelta.y 110→0 + m_AnchoredPosition.y 55→0，
--      合起来是「底边钉死、顶边从上方落下 110px」的前摇（参考里 bg 是全屏纯色遮罩、
--      自身位移看不见，看得见的是 bg 下承内容的那一层；本面板落到同样四边拉满、pivot 0.5、
--      基准 (0,0) 的 bg/pageContent 上，几何等价且看得见）。
--
-- 为什么不用静态 clip（流程判据见 docs/ui_anim_reproduce_skill.md §3）：
--   ① 哪些页签可见由 RefreshTabStatus 按活动开放状态 SetActive 决定（福利 9 个 / 激励计划 5 个，且会变），
--      未激活节点不参与动画求值 ⇒ 静态曲线会白写、还可能卡在 scale 0；
--   ② 面板被 openedList 缓存复用，legacy Animation 只在 enable 时自动播一次 ⇒ 第二次打开不复播；
--   ③ 切页签要单独翻高亮板，是事件驱动的。
local kTabFlipDuration = 0.167
local kTabFlipStep = 0.033
local kTabFlipMaxSpan = 0.5     -- 可见页签多时压缩错开间隔，整体跨度不超过 0.5s
local kPageDropDuration = 0.3667
local kPageDropOffsetY = 110
local tabFlipItems = {}         -- { tween = , tf = , anim = }
local tabSelectTween = nil      -- 高亮板翻入
local pageDropTween = nil       -- 内容区落位

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能直接取字段
-- （tolua fake-null），必须先 IsNull 判活。
local function FlipAlive(obj)
    if obj == nil then
        return false
    end
    if type(obj) == "userdata" then
        return not IsNull(obj)
    end
    return true
end

-- tolua 的枚举表是运行期注册的，取不到就不设：否则整段被 pcall 吃掉、什么都不动
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

-- DOAnchorPos 是 RectTransform 的扩展方法；直接拿 transform 得到的是 Transform 类型，
-- 那种 userdata 上没有这个方法。
function this.GetPageContent()
    local go = Util.GetGameObject(this.gameObject, "bg/pageContent")
    if not FlipAlive(go) then
        return nil
    end
    return go:GetComponent("RectTransform")
end

-- 回收落位 tween 并把位置复位。重播 / 关闭 / 销毁 / 出错都必须走这里：
-- 中途关掉再打开会从半截位置起，漏复位则永久停在 +110。
function this.StopPageDropIn()
    if FlipAlive(pageDropTween) then
        pageDropTween:Kill(false)
    end
    pageDropTween = nil
    local rt = this.GetPageContent()
    if FlipAlive(rt) then
        rt.anchoredPosition = Vector2.New(0, 0)
    end
end

-- 打开面板：内容区从上方落下 110px 落到原位（一次性，0.367s，两端缓入缓出）。
function this.PlayPageDropIn()
    this.StopPageDropIn()
    local rt = this.GetPageContent()
    if not FlipAlive(rt) then
        return
    end
    local ok, err = pcall(function()
        rt.anchoredPosition = Vector2.New(0, kPageDropOffsetY)
        local tween = rt:DOAnchorPos(Vector2.New(0, 0), kPageDropDuration)
        SetEaseSafe(tween, "InOutQuad")
        tween:OnComplete(function()
            if FlipAlive(rt) then
                rt.anchoredPosition = Vector2.New(0, 0)
            end
        end)
        pageDropTween = tween
    end)
    if not ok then
        LogError("OperatingPanel: 内容区落位失败 " .. tostring(err))
        if FlipAlive(rt) then
            rt.anchoredPosition = Vector2.New(0, 0)
        end
    end
end


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
    -- 红点绑定不要放在这里：BindEvent 只在面板首次创建时执行一次，
    -- 而 OnClose 里的 ClearRedPoint 会把绑定清空，第二次打开后页签红点就再也不刷新了。
    -- 改到 OnShow 里每次打开重新绑（见 BindRedPoint 的幂等保护）。
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

    -- 先绑红点再检测：面板是缓存复用的，再次打开只走 AddListener→OnShow，
    -- 而上次 OnClose 已经 ClearRedPoint 把绑定清空了，不重新绑就永远刷不出红点。
    this:BindRedPoint()
    this:CheckRedPoint()
    this:RefreshTabStatus()
    if not curIndex then
        this:GetPriorityIndex()
    end
    this:OnTabChanged()
    -- 页签逐格翻入（放在 OnTabChanged 之后：这时才确定哪些页签开着、哪块高亮板被选中）
    this:PlayTabFlipIn()
    -- 内容区从上往下落位（与翻入同时起，和参考一致）
    this:PlayPageDropIn()
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
    -- 翻到一半被关掉：必须把临时禁用的按钮 Animator 恢复、内容区落位复位，
    -- 否则那颗页签以后没按下反馈、下次打开从半截位置起。
    this:StopOpenAnims()
    this:ClearRedPoint()
end

function OperatingPanel:OnDestroy()
    this:StopOpenAnims()
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
    -- 选中的高亮板翻一次（首次打开时会被随后的 PlayTabFlipIn 整格翻入接管）
    this:PlayTabSelectFlip(curIndex)
end

-- 回收所有开启动画 tween，并把临时关掉的按钮 Animator 恢复。
-- 🔴 漏恢复 = 那颗页签从此没有按下反馈；重播 / 关闭 / 销毁都必须走这里。
function this.StopOpenAnims()
    for i = #tabFlipItems, 1, -1 do
        local item = tabFlipItems[i]
        if FlipAlive(item.tween) then
            item.tween:Kill(false)
        end
        if FlipAlive(item.tf) then
            item.tf.localScale = Vector3.one
        end
        if FlipAlive(item.anim) then
            item.anim.enabled = true
        end
        tabFlipItems[i] = nil
    end
    if FlipAlive(tabSelectTween) then
        tabSelectTween:Kill(false)
    end
    tabSelectTween = nil
    -- 落位同属开启动画，一起回收
    this.StopPageDropIn()
end

-- 打开面板：可见页签按「版面上的顺序」逐格 scaleX 0→1 翻入。
-- 顺序取 tabsContent 的子节点顺序（VerticalLayoutGroup 按 sibling 排版），不能用 tabs_N 的下标：
-- 只有 UI 实际摆出来的顺序才是眼睛看到的顺序。
function this.PlayTabFlipIn()
    this.StopOpenAnims()
    if not FlipAlive(this.tabsContent) then
        return
    end
    local content = this.tabsContent.transform
    local total = content.childCount
    local visible = 0
    for i = 0, total - 1 do
        local tf = content:GetChild(i)
        if FlipAlive(tf) and tf.gameObject.activeSelf then
            visible = visible + 1
        end
    end
    if visible <= 0 then
        return
    end
    local step = kTabFlipStep
    if visible > 1 and step * (visible - 1) > kTabFlipMaxSpan then
        step = kTabFlipMaxSpan / (visible - 1)
    end

    local order = 0
    local started = {}   -- 出错回滚用：{ tf, anim }
    local ok, err = pcall(function()
        for i = 0, total - 1 do
            local tf = content:GetChild(i)
            -- 未激活页签不参与动画：SetActive 打开时不会补播，写了只会卡在 scale 0
            if FlipAlive(tf) and tf.gameObject.activeSelf then
                local anim = tf:GetComponent("Animator")
                -- 🔴 每个页签都挂 CommonButton 的 Animator，Normal 状态是单帧 clip、照样写
                -- m_LocalScale=1，而且 Animator 在 Update 之后求值 ⇒ 不关掉它，下面的
                -- DOTween 缩放会被每帧盖回去（现象：脚本跑完了但页签没动）。
                if FlipAlive(anim) then
                    anim.enabled = false
                end
                started[#started + 1] = { tf = tf, anim = anim }
                tf.localScale = Vector3.New(0, 1, 1)
                local tween = tf:DOScale(Vector3.one, kTabFlipDuration):SetDelay(order * step)
                SetEaseSafe(tween, "OutQuad")
                tween:OnComplete(function()
                    if FlipAlive(tf) then
                        tf.localScale = Vector3.one
                    end
                    if FlipAlive(anim) then
                        anim.enabled = true
                    end
                end)
                tabFlipItems[#tabFlipItems + 1] = { tween = tween, tf = tf, anim = anim }
                order = order + 1
            end
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把页签留在 scale 0 / Animator 禁用态
        LogError("OperatingPanel: 页签翻入失败 " .. tostring(err))
        for i = 1, #started do
            local item = started[i]
            if FlipAlive(item.tf) then
                item.tf.localScale = Vector3.one
            end
            if FlipAlive(item.anim) then
                item.anim.enabled = true
            end
        end
        tabFlipItems = {}
    end
end

-- 切换页签：高亮板翻一次。selected 节点没有 Animator，不会和 CommonButton 抢缩放通道。
function this:PlayTabSelectFlip(index)
    local go = self.selectTabs and self.selectTabs[index]
    if not FlipAlive(go) then
        return
    end
    if FlipAlive(tabSelectTween) then
        tabSelectTween:Kill(false)
    end
    local tf = go.transform
    tf.localScale = Vector3.New(0, 1, 1)
    local ok, err = pcall(function()
        tabSelectTween = tf:DOScale(Vector3.one, kTabFlipDuration)
        SetEaseSafe(tabSelectTween, "OutQuad")
        tabSelectTween:OnComplete(function()
            if FlipAlive(tf) then
                tf.localScale = Vector3.one
            end
        end)
    end)
    if not ok then
        LogError("OperatingPanel: 高亮板翻入失败 " .. tostring(err))
        if FlipAlive(tf) then
            tf.localScale = Vector3.one
        end
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
    this._needRefreshRedAfterTab = true

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
    -- 幂等：OnShow 可能被重复调用（重设层级/回栈再显示），重复 table.insert 会让同一个物体被绑多次
    if self._redPointBound then
        return
    end
    self._redPointBound = true

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
    self._redPointBound = false
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