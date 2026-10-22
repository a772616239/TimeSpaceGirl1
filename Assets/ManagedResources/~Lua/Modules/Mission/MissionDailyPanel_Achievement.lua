----- 日常任务弹窗 -----
local this = {}
--传入父脚本模块
local parent
--传入特效层级
local sortingOrder = 0
local fun
--item容器
local itemList = {}
local curAllData = {}
local achievementConfig = ConfigManager.GetConfig(ConfigName.AchievementConfig)
local itemGrid = {}
local allAvailableAchievement = {}

--============================== 成就卡入场（右滑入 + 淡入，与 Daily 页同款）==============================
-- 参考 Assets/Art/UIAni/cn2-X1_UI_TreasureStorePopup.anim；实现镜像 MissionDailyPanel_Daily.lua
-- （同面板姊妹页，配方见 docs/ui_item_slide_in_skill.md 第四/六落地）。
-- prefab 实测：成就 rewardPre（1078×275）与 Daily 的 rewardPre 完全同构 —— 同一组 6 个可视子节点、
-- 卡根自己就是满幅 Image（形态二），所以常量与节点名单直接照抄 Daily。
-- 🔴 位移写卡的**直接子节点**：ScrollCycleView:SetData/SetItemIndex 每次直接赋值 item 根的
--    anchoredPosition，写根必被抹回。淡入写在卡根的 **Image 组件**上（不动位置，不受重写波及）。
-- 🔴 只在「打开面板 / 切页签」播：领奖、一键领取、Task.Achievement 事件都是数据回调刷新，
--    重播会闪一下 —— 全部收口进 RefreshAchievementSilently（suppress + pcall 保复位）。
local kCardSlideFrom      = 260      -- 打开：起点位移（px）
local kCardSlideDuration  = 0.26     -- 打开：单卡时长
local kCardSlideStep      = 0.055    -- 打开：相邻卡错开
local kCardSwitchFrom     = 170      -- 切页签：起点位移（短一些）
local kCardSwitchDuration = 0.30     -- 切页签：单卡时长（长一些）
local kCardSwitchStep     = 0.05     -- 切页签：相邻卡错开
local kCardSwitchDelay    = 0.05     -- 切页签：整批晚起播，躲开 SetData 重建帧
local kCardFadeFrom       = 0.3647   -- 参考 item/Bg 的 alpha 起点

-- 成就卡的可视子节点（一起右移 = 整卡滑入）。receiveBtn/goBtn/Received 三态互斥显隐，
-- 每条 tween 都要先判 activeSelf，否则会把未激活的按钮也拖一遍。
local kCardNodes = { "titleImage", "getRewardProgress", "content", "receiveBtn", "goBtn", "Received" }

local cardSlideItems   = {}     -- { rect, x, y, graphic, color, tween }
local cardSlidePlaying = false  -- 这一轮还没播完（连点保护）
local cardSlidePending = 0      -- 还有几条 tween 没完成
this.suppressAchvAnim = false   -- 数据刷新路径置 true：只复位、不播
this.nextPlayIsSwitch = false   -- 本次入场是「切页签」还是「首次打开」
local shownOnce = false         -- OnShow 用它判打开/切页签；OnClose 不能复位（切页签走 OnClose）

-- tolua 的枚举是运行期注册的：取不到就跳过（DOTween 默认缓动），异常被 pcall 吃掉会整段静默不播
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

-- tolua fake-null：userdata（含已 Destroy）用 IsNull 判，纯 table 直接算活着
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

-- 回收：Kill 所有 tween 并把位置/颜色复位。重播 / OnClose / OnDestroy 都必须走这里。
function this.StopAchvSlideIn()
    -- Kill 不会回调 OnComplete => 播中标记必须在这里自己清
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

-- 收集当前可见的成就卡（ScrollCycleView 的 item 池，顺序即列表顺序）
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

-- 起播：每张卡从右侧滑回原位，卡根底板 alpha 0.3647 → 1。
-- isSwitch=true 走切页签那套（位移更短、时长更长、整批晚 0.05s 起播）。
function this.PlayAchvSlideIn(isSwitch)
    -- 连点保护：上一轮没播完就只复位、不重播（复位到终值本身就是「立刻到位」）
    local interrupted = cardSlidePlaying
    this.StopAchvSlideIn()
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
                        -- 从右侧滑入：起点在右，向左归位（与 Daily 页同方向）
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
            -- 淡入：只淡整卡那张底板（卡根节点自己的 Image，prefab 实测形态二）
            if Alive(card) then
                local image = card:GetComponent("Image")
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
        LogError("MissionDailyPanel_Achievement: 成就卡入场失败 " .. tostring(err))
        this.StopAchvSlideIn()
        return 0
    end
    if cardSlidePending == 0 then
        cardSlidePlaying = false
    end
    return #cards
end

-- 播 / 不播：只有「打开面板」与「切页签」播，数据刷新不播
function this.ApplyAchvSlideIn()
    if this.suppressAchvAnim then
        -- 抑制时也要 Stop，否则上一轮的 tween 会继续跑、停在半截
        this.StopAchvSlideIn()
        return 0
    end
    return this.PlayAchvSlideIn(this.nextPlayIsSwitch)
end

-- 数据刷新（领奖、一键领取、成就变更事件）：只刷新列表，不重播入场。
-- pcall 只为保证复位 —— 标记卡在 true 会让后面所有入场永久失效。
function this.RefreshAchievementSilently()
    this.suppressAchvAnim = true
    local ok, err = pcall(this.OnShowPanelData)
    this.suppressAchvAnim = false
    if not ok then
        LogError("MissionDailyPanel_Achievement: 静默刷新失败 " .. tostring(err))
    end
end

-- 成就数据变更事件（AddListener 注册的是这个包装，别直接挂 OnShowPanelData —— 那样会重播入场）
function this.OnAchievementChanged()
    this.RefreshAchievementSilently()
end

function this:InitComponent(gameObject)
    this.rewardPre = Util.GetGameObject(gameObject, "rewardPre")
    local v = Util.GetGameObject(gameObject, "rect"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "rect").transform,
            this.rewardPre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.NoviceItemList = {}--存储itemview 重复利用

    this.receiveAllBtn = Util.GetGameObject(gameObject, "receiveAllBtn")
end

function this:BindEvent()
    Util.AddClick(this.receiveAllBtn, function()
        NetManager.TakeMissionAllRewardRequest(TaskTypeDef.Achievement,function (msg)
            if msg.drop == nil then return end
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                for i = 1,#msg.missionIds do
                    TaskManager.SetTypeTaskState(TaskTypeDef.Achievement, msg.missionIds[i], 2)
                end
                this.RefreshAchievementSilently()
            end)
        end)
    end)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.Task.Achievement, this.OnAchievementChanged)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.Task.Achievement, this.OnAchievementChanged)
end

function this:OnShow(_parent,...)
    parent = _parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local args = {...}
    fun = args[1]
    -- 入场节奏：第一次 OnShow 是「打开面板」，之后每次都是「切页签」（与 Daily 页同判法）
    this.nextPlayIsSwitch = shownOnce
    shownOnce = true
    this.OnShowPanelData()
end

function this:OnSortingOrderChange(sortingOrder)
    for i, v in pairs(this.NoviceItemList) do
        for j = 1, #this.NoviceItemList[i] do
            if this.NoviceItemList[i][j] and this.NoviceItemList[i][j].gameObject then
                this.NoviceItemList[i][j]:SetEffectLayer(sortingOrder)
            end
        end
    end
end

function this.OnShowPanelData()
    local curAllData = TaskManager.GetCurShowAllAchievementData(TaskTypeDef.Achievement)
    local AllData = {}
    -- local allAchievement = {}
    allAvailableAchievement = {}
    for i, v in pairs(curAllData) do
        table.insert(AllData,v)
    end
    this.RewardTabsSort(AllData)
    this.ScrollView:SetData(AllData, function (index, go)
        this.SingleDataShow(go, AllData[index])
        -- allAchievement[index] = go
    end)

    Util.SetGray(this.receiveAllBtn,#allAvailableAchievement == 0)
    this.receiveAllBtn:GetComponent("Button").enabled = (#allAvailableAchievement ~= 0)

    -- 列表建完再播入场（放 SetData 之后、且不在每张卡的 updateFunc 里 —— 滚动会逐张触发）
    this.ApplyAchvSlideIn()
end

function this.SingleDataShow(go,rewardData)
    -- go:SetActive(true)
    local sConFigData = achievementConfig[rewardData.missionId]
    local titleText = Util.GetGameObject(go, "titleImage/titleText"):GetComponent("Text")
    titleText.text = GetLanguageStrById(sConFigData.ContentsShow)
    local itemGroup = Util.GetGameObject(go, "content")

    --滚动条复用重设itemview
    if this.NoviceItemList[go] then
        for i = 1, 4 do
            this.NoviceItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #sConFigData.Reward do
            if this.NoviceItemList[go][i] then
                this.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                this.NoviceItemList[go][i].gameObject:SetActive(true)
            end
        end
    else
        this.NoviceItemList[go] = {}
        for i = 1, 4 do
            this.NoviceItemList[go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
            this.NoviceItemList[go][i].gameObject:SetActive(false)
        end
        for i = 1, #sConFigData.Reward do
            this.NoviceItemList[go][i]:OnOpen(false, {sConFigData.Reward[i][1],sConFigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
            this.NoviceItemList[go][i].gameObject:SetActive(true)
        end
    end
    local receiveBtn = Util.GetGameObject(go.gameObject, "receiveBtn")
    local goBtn = Util.GetGameObject(go.gameObject, "goBtn")
    local Received = Util.GetGameObject(go.gameObject, "Received")
    local getRewardProgressSlider = Util.GetGameObject(go.gameObject, "getRewardProgress")
    local getRewardProgress = Util.GetGameObject(go.gameObject, "getRewardProgress/Txt")
    local state = rewardData.state
    local value = sConFigData.Values[2][1]
    receiveBtn:SetActive(state == 1)
    goBtn:SetActive(state == 0)
    Received:SetActive(state == 2)

    if state == 2 then
        getRewardProgressSlider:SetActive(false)
        -- TaskManager.SetTypeTaskState(TaskTypeDef.Achievement, rewardData.missionId, 2)
        -- go:SetActive(false)
    else
        local str = PrintWanNum4(math.abs(rewardData.progress)).."/"..PrintWanNum4(math.abs(value))
        local value = math.abs(rewardData.progress)/math.abs(value)
        if sConFigData.Type == 37 then
            if state == 0 then
                value = 0
                str = "0/"..1
            elseif state == 1 then
                value = 1
                str = "1/"..1
            end
        end
        getRewardProgressSlider:SetActive(true)
        getRewardProgressSlider:GetComponent("Slider").value = value
        getRewardProgress:GetComponent("Text").text = str
    end

    Util.AddOnceClick(goBtn, function()
        if sConFigData.Jump then
            JumpManager.GoJump(sConFigData.Jump[1])
        end
    end)
    Util.AddOnceClick(receiveBtn, function()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.Achievement,rewardData.missionId,  function(msg)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                       TaskManager.SetTypeTaskState(TaskTypeDef.Achievement, rewardData.missionId, 2)
            this.RefreshAchievementSilently()
        end)
    end)
    end)

    if state == 1 then
        if this.IsAvailableAchievement(rewardData.missionId) then
            table.insert(allAvailableAchievement,rewardData.missionId)
        end
    end
end

--判断是否含有这个已完成的成就
function this.IsAvailableAchievement(missionId)
    for i = 1,#allAvailableAchievement do
        if allAvailableAchievement[i] == missionId then
            return false
        end
    end
    return true
end

local sortTable = {
    [1] = 2,
    [2] = 0,
    [0] = 1,
}
function this.RewardTabsSort(missions)
    table.sort(missions,function(a,b)
        if a.state == b.state then
            return a.missionId < b.missionId
        else
            return sortTable[a.state] > sortTable[b.state]
        end
    end)
end
function this:OnClose()
    -- 🔴 不能在这里复位 shownOnce：切页签时父面板 SwitchView 会先对旧页签调 OnClose，
    --    复位了就把「切页签」误判成「首次打开」。复位只放 OnDestroy。
    this.StopAchvSlideIn()
end
function this:OnDestroy()
    this.StopAchvSlideIn()
    shownOnce = false   -- 真销毁：下次打开重新按「首次打开」的节奏播
end

return this