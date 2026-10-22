require("Base/BasePanel")
CourtesyDressPanel = Inherit(BasePanel)
local this = CourtesyDressPanel
local chapterList = { GetLanguageStrById(10005), GetLanguageStrById(10006), GetLanguageStrById(10007), GetLanguageStrById(10008), GetLanguageStrById(10009), GetLanguageStrById(10010), GetLanguageStrById(10011), GetLanguageStrById(10012), GetLanguageStrById(10013), GetLanguageStrById(10014), GetLanguageStrById(10015), GetLanguageStrById(10016), GetLanguageStrById(10017), GetLanguageStrById(10018), GetLanguageStrById(10019) }
local selectIndex = 0
local jumpNeedBtn = 0
local isFirstOn = true--是否首次打开页面

--初始化组件（用于子类重写）
--============================== 奖励卡入场（右滑入 + 淡入）==============================
-- 按 docs/ui_item_slide_in_skill.md 的配方（第五个落地）。
-- 参考 Assets/Art/UIAni/cn2-X1_UI_TreasureStorePopup.anim：列表项 m_AnchoredPosition.x 逐格错开
-- 回到 0，底板 m_Color.a 0.3647 → 1（淡入比位移长）。本页按要求做**反向**：
-- 从右侧 +260 向左归位 0，越靠下的卡起点越右、逐格错开 ⇒ 整排卡从右侧陆续嵌进来。
--
-- 作用对象：rect/ScrollCycleView/grid 下由 item 克隆出的奖励卡 item1..itemN（prefab 实测 1080×230）。
--
-- 🔴 位移写卡的**直接子节点**，不写卡根节点：ScrollCycleView:SetData / SetItemIndex 每次都直接赋值
--    item.tran.anchoredPosition（滚动、换页都会），写根节点必被抹回原位。
-- 🔴 本卡的底板是**名为 Image 的第一个直接子节点**（1060×230 满幅），卡根节点自己没有 Image
--    ⇒ 淡入写 `Image` 那层。这条依赖 Util.GetGameObject 的实现（先 root.Find 直接子节点、
--    再 DFS 递归），所以直接子节点里的那个 Image 会先命中；若将来 prefab 调序导致命中错的 Image，
--    现象是「底板不淡入 / 淡错了块」，改法是把 fade 改成显式 transform:GetChild(0)。
-- 🔴 一屏 itemCount = ceil(rect 高 990 / (230+5) + 1) = 6 张 ⇒ 逐格错开生效；滚动时 item 池复用，
--    所以只在 OnShowActivityData 末尾播一次，不放进每张卡的 updateFunc 里（滚动会逐张触发）。
-- 节奏分两套：打开面板一套、切页签一套。切页签是玩家反复触发的操作，位移小一截、时长拉长、
-- 整批晚 0.05s 起播（躲开 SetData 那一帧同步图标/排文本的卡顿）。
local kCardSlideFrom      = 260      -- 打开：起点位移（px），卡宽 1080 的 ~24%
local kCardSlideDuration  = 0.26     -- 打开：单卡时长
local kCardSlideStep      = 0.055    -- 打开：相邻卡错开
local kCardSwitchFrom     = 170      -- 切页签：起点位移（短一些，别一屏全在飞）
local kCardSwitchDuration = 0.30     -- 切页签：单卡时长（长一些，切换才看得清）
local kCardSwitchStep     = 0.05     -- 切页签：相邻卡错开
local kCardSwitchDelay    = 0.05     -- 切页签：整批晚起播
local kCardFadeFrom       = 0.3647   -- 参考 item/Bg 的 alpha 起点
local kCardFadeNode       = "Image"  -- 满幅底板（卡根节点没有 Image，见上面第二条注释）

-- 奖励卡的可视子节点（一起右移 = 整卡滑入）。后四个按「可领 / 未开启 / 已领完」互斥显隐，
-- 所以每条 tween 都要先判 activeSelf，否则会把不相关的按钮也拖一遍。
local kCardNodes = { "Image", "titleImage", "content", "getRewardProgress", "getRewardBtn", "nextDayOpenBtn", "getFinishText" }

local cardSlideItems   = {}     -- { rect, x, y, graphic, color, tween }，rect 与 graphic 二选一
local cardSlidePlaying = false  -- 这一轮还没播完（连点页签靠它判断，别叠着播）
local cardSlidePending = 0      -- 还有几条 tween 没完成；减到 0 才算播完
-- 播放节奏与抑制标记放模块表上：离线 harness 要能读写（见 scripts/lua-tests/test_courtesydress_cardslide.lua）
this.suppressCardAnim = false   -- 数据刷新路径置 true：只复位、不播
this.nextPlayIsSwitch = false   -- 本次入场是「切页签」还是「首次打开」

-- tolua 的枚举是运行期注册的：取不到就跳过，异常被 pcall 吃掉会整段静默不播
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能取字段
local function Alive(obj)
    if obj == nil then
        return false
    end
    if type(obj) == "userdata" then
        return not IsNull(obj)
    end
    return true
end

local function WithAlpha(color, a)
    return Color.New(color.r, color.g, color.b, a)
end

-- 回收：Kill 掉所有 tween 并把位置/颜色复位。
-- 🔴 漏复位 = 奖励卡永久停在半截位置或半透明；重播 / 关闭 / 销毁都必须走这里。
function this.StopCardSlideIn()
    -- Kill 不会回调 OnComplete => 播中标记必须在这里自己清，否则一次 Stop 之后
    -- 后面所有入场都会被「连点保护」当成播中而跳过
    cardSlidePlaying = false
    cardSlidePending = 0
    for i = #cardSlideItems, 1, -1 do
        local item = cardSlideItems[i]
        if Alive(item.tween) then
            item.tween:Kill(false)
        end
        if item.rect and item.x and Alive(item.rect) then
            item.rect.anchoredPosition = Vector2.New(item.x, item.y)
        end
        if item.graphic and item.color and Alive(item.graphic) then
            item.graphic.color = item.color
        end
        cardSlideItems[i] = nil
    end
end

-- 收集当前可见的奖励卡（ScrollCycleView 的 item 池，顺序即列表顺序）
local function CollectCards()
    local cards = {}
    local sv = this.ScrollView
    if type(sv) == "table" and type(sv.ForeachItemGO) == "function" then
        sv:ForeachItemGO(function(_, go)
            if Alive(go) and go.activeSelf then
                cards[#cards + 1] = go
            end
        end)
    end
    return cards
end

-- 起播：每张卡从右侧滑回原位，底板 alpha 0.3647 → 1。
-- isSwitch=true 走切页签那套（位移更短、时长更长、整批晚 0.05s 起播）。
function this.PlayCardSlideIn(isSwitch)
    -- 连点页签：上一轮还没播完就只复位、不再重播 —— 重播等于列表刚重建完又堆一批 tween。
    -- 复位到终值本身就是「立刻到位」，观感上不比重播差。
    local interrupted = cardSlidePlaying
    this.StopCardSlideIn()
    if interrupted then
        return 0
    end
    local cards = CollectCards()
    if #cards <= 0 then
        return 0
    end
    local from, duration, step, baseDelay
    if isSwitch then
        from, duration, step, baseDelay = kCardSwitchFrom, kCardSwitchDuration, kCardSwitchStep, kCardSwitchDelay
    else
        from, duration, step, baseDelay = kCardSlideFrom, kCardSlideDuration, kCardSlideStep, 0
    end
    -- 每完成一条减一，减到 0 才算这一轮播完（Kill 不会回调 OnComplete，见 StopCardSlideIn）
    local function Done()
        cardSlidePending = cardSlidePending - 1
        if cardSlidePending <= 0 then
            cardSlidePending = 0
            cardSlidePlaying = false
        end
    end
    cardSlidePlaying = true
    local ok, err = pcall(function()
        for ci = 1, #cards do
            local card = cards[ci]
            local delay = baseDelay + (ci - 1) * step
            -- 位移：卡的可见子节点一起走
            for i = 1, #kCardNodes do
                local go = Util.GetGameObject(card, kCardNodes[i])
                if Alive(go) and go.activeSelf then
                    local rect = go:GetComponent("RectTransform")
                    if Alive(rect) then
                        local pos = rect.anchoredPosition
                        -- 从右侧滑入：起点在右边，向左归位（要改回左侧只需把这里的 + 改成 -）
                        rect.anchoredPosition = Vector2.New(pos.x + from, pos.y)
                        local tween = rect:DOAnchorPosX(pos.x, duration)
                        tween:SetDelay(delay)
                        SetEaseSafe(tween, "OutQuad")
                        cardSlidePending = cardSlidePending + 1
                        tween:OnComplete(function()
                            if Alive(rect) then
                                rect.anchoredPosition = Vector2.New(pos.x, pos.y)
                            end
                            Done()
                        end)
                        cardSlideItems[#cardSlideItems + 1] = { rect = rect, x = pos.x, y = pos.y, tween = tween }
                    end
                end
            end
            -- 淡入：只淡满幅底板（参考里就是 item/Bg，装饰图跟着底板走但不透明）
            local bg = Util.GetGameObject(card, kCardFadeNode)
            if Alive(bg) then
                local image = bg:GetComponent("Image")
                if Alive(image) then
                    local color = image.color
                    image.color = WithAlpha(color, kCardFadeFrom)
                    local tween = image:DOFade(color.a, duration)
                    tween:SetDelay(delay)
                    SetEaseSafe(tween, "OutQuad")
                    cardSlidePending = cardSlidePending + 1
                    tween:OnComplete(function()
                        if Alive(image) then
                            image.color = color
                        end
                        Done()
                    end)
                    cardSlideItems[#cardSlideItems + 1] = { graphic = image, color = color, tween = tween }
                end
            end
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把奖励卡留在半截位置/半透明
        LogError("CourtesyDressPanel: 奖励卡入场失败 " .. tostring(err))
        this.StopCardSlideIn()
        return 0
    end
    if cardSlidePending == 0 then
        cardSlidePlaying = false
    end
    return #cards
end

-- 播 / 不播：只有「打开面板」与「切页签」播，数据刷新不播（见 RefreshActivityDataSilently）
function this.ApplyCardSlideIn()
    if this.suppressCardAnim then
        -- 🔴 抑制时也要 Stop，否则上一轮的 tween 会继续跑、停在半截
        this.StopCardSlideIn()
        return 0
    end
    return this.PlayCardSlideIn(this.nextPlayIsSwitch)
end

-- 数据刷新（领奖后刷新 / 在线奖励到点 / 倒计时推进）：只刷新列表，不重播入场。
-- 用 pcall 只为保证复位 —— 标记卡在 true 会让后面所有入场永久失效。
function this.RefreshActivityDataSilently(activityData, activityType, getRewardState, isCanReward)
    this.suppressCardAnim = true
    local ok, err = pcall(this.OnShowActivityData, this, activityData, activityType, getRewardState, isCanReward)
    this.suppressCardAnim = false
    if not ok then
        LogError("CourtesyDressPanel: 静默刷新失败 " .. tostring(err))
    end
end

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
    -- 入场节奏：OnShow 是「打开面板」；切页签走下面 3 个按钮，各自把它置 true
    this.nextPlayIsSwitch = false

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
    -- 列表建完再播入场（放 SetData 之后、且不在每张卡的 updateFunc 里 —— 滚动会逐张触发）
    this.ApplyCardSlideIn()

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
        this.nextPlayIsSwitch = true   -- 切页签走更慢更柔的那套（见 PlayCardSlideIn）
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
        this.nextPlayIsSwitch = true   -- 切页签走更慢更柔的那套（见 PlayCardSlideIn）
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
        this.nextPlayIsSwitch = true   -- 切页签走更慢更柔的那套（见 PlayCardSlideIn）
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
            this:RefreshActivityDataSilently(activityData, selectIndex, getRewardState, ActivityGiftManager.currentTimeIndex)
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
    this:RefreshActivityDataSilently(activityData, selectIndex, getRewardState, canRewardIndex)
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
    this.StopCardSlideIn()
    if  self.timer then
        self.timer:Stop()
        self.timer = nil
    end
end

--界面销毁时调用（用于子类重写）
function CourtesyDressPanel:OnDestroy()
    this.StopCardSlideIn()
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
    
    if not IsNull(this.remaindTimeText) then
        this.remaindTimeText.text =   GetLanguageStrById(10024)..TimeToHMS(timeNum)
    end

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
        this:RefreshActivityDataSilently(ActivityGiftManager.onlineData, ActivityTypeDef.OnlineGift, ActivityGiftManager.onlineGetRewardState, ActivityGiftManager.currentTimeIndex)
    end
end
return CourtesyDressPanel