----- 日常任务弹窗 -----
local this = {}
--传入父脚本模块
-- local parent
--传入特效层级
local sortingOrder = 0
-- local fun
local SingleDailyMissionState = {
    NoFinish = 0,   --未完成
    Finish = 1,     --完成未领取
    GetFinish = 2,  --已领取
}
local SortDailyMissionState = {
    [1] = 1,
    [0] = 2,
    [2] = 3
}
-- local allAvailableTaskId = {}
local dailyTasksConfig = {}         --静态数据
local curDailyMissionData = {}      --每日任务条目
local curDailyMissionBoxData = {}   --宝箱
local boxList = {}                  --宝箱按钮
-- local allMissionDailyPres = {}
-- local allMissionDailyItemPres = {}
local allMissionDailyBoxItemPres = {}
-- local myGo
local allAvailableTask = {}

--============================== 任务卡入场（右滑入 + 淡入）==============================
-- 参考 Assets/Art/UIAni/cn2-X1_UI_TreasureStorePopup.anim（dump_clip.py 反解，m_EditorCurves 12 条全读）：
--   grid/item1..3     m_AnchoredPosition.x   -200 / -150 / -100 → 0   逐格错开（左侧滑入）
--   grid/item1..3/Bg  m_Color.a              0.3647 → 1             淡入比位移长
-- 本页按要求做**反向**：从右侧 +260 向左归位 0 —— 越靠下的卡起点越右、逐格错开，
-- 读起来是「整排卡从右侧陆续嵌进来」。
-- 前 4 条（Panel 的位移/现高、Panel/Bg 的回弹 + alpha）是弹窗本体进出场，本页是 MissionDailyPanel
-- 的子页、没有独立底板、整页位移会和父面板的打开动画打架 => 只复刻列表项那 6 条。
--
-- 作用对象：rect/ScrollCycleView/grid 下由 rewardPre 克隆出的任务卡 item1..itemN（prefab 实测 1078×275）。
--
-- 🔴 位移写卡的**直接子节点**，不写卡根节点：ScrollCycleView:SetData / SetItemIndex 每次都直接赋值
--    item.tran.anchoredPosition（换页、滚动都会），写根节点必被抹回原位。
-- 🔴 卡的底板就是**卡根节点自己那张 Image**（cn2-X1_chongzhi_goumaixiangdiban，整卡大小）；
--    rewardPre 里没有叫 bg 的子节点 => 淡入取 card:GetComponent("Image")，别去翻子节点。
-- 🔴 一屏 itemCount = ceil(视口高 1012 / 275.36 + 1) = 5 张 => 逐格错开生效；滚动时 item 池复用，
--    所以只在 OnShowData 末尾播一次，不放进每张卡的 updateFunc 里（滚动会逐张触发）。
-- 节奏分两套：打开面板一套、切页签一套。切页签是玩家反复触发的操作，位移小一截、时长拉长、
-- 整批晚 0.05s 起播（躲开 SetData 那一帧同步图标/排文本的卡顿）。
local kCardSlideFrom      = 260      -- 打开：起点位移（px），卡宽 1078 的 ~24%
local kCardSlideDuration  = 0.26     -- 打开：单卡时长
local kCardSlideStep      = 0.055    -- 打开：相邻卡错开
local kCardSwitchFrom     = 170      -- 切页签：起点位移（短一些，别一屏全在飞）
local kCardSwitchDuration = 0.30     -- 切页签：单卡时长（长一些，切换才看得清）
local kCardSwitchStep     = 0.05     -- 切页签：相邻卡错开
local kCardSwitchDelay    = 0.05     -- 切页签：整批晚起播
local kCardFadeFrom       = 0.3647   -- 参考 item/Bg 的 alpha 起点

-- 任务卡的可视子节点（一起右移 = 整卡滑入）。后三个按任务状态互斥显隐，
-- 所以每条 tween 都要先判 activeSelf，否则会把未解锁/已领取的按钮也拖一遍。
local kCardNodes = { "titleImage", "getRewardProgress", "content", "receiveBtn", "goBtn", "Received" }

local cardSlideItems   = {}     -- { rect, x, y, graphic, color, tween }，rect 与 graphic 二选一
local cardSlidePlaying = false  -- 这一轮还没播完（连点页签靠它判断，别叠着播）
local cardSlidePending = 0      -- 还有几条 tween 没完成；减到 0 才算播完
-- 播放节奏与抑制标记放模块表上：离线 harness 要能读写（见 scripts/lua-tests/test_missiondaily_cardslide.lua）
this.suppressCardAnim = false   -- 数据刷新路径置 true：只复位、不播
this.nextPlayIsSwitch = false   -- 本次入场是「切页签」还是「首次打开」
local shownOnce = false         -- 本面板是否已经入场过一次（OnShow 用它判打开/切页签）

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
-- 🔴 漏复位 = 任务卡永久停在半截位置或半透明；重播 / 关闭 / 销毁都必须走这里。
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

-- 收集当前可见的任务卡（ScrollCycleView 的 item 池，顺序即列表顺序）
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
            -- 淡入：只淡整卡那张底板（卡根节点自己的 Image）
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
        -- DOTween 侧任何异常都不能把任务卡留在半截位置/半透明
        LogError("MissionDailyPanel_Daily: 任务卡入场失败 " .. tostring(err))
        this.StopCardSlideIn()
        return 0
    end
    if cardSlidePending == 0 then
        cardSlidePlaying = false
    end
    return #cards
end

-- 播 / 不播：只有「打开面板」与「切页签」播，数据刷新不播（见 RefreshDailySilently）
function this.ApplyCardSlideIn()
    if this.suppressCardAnim then
        -- 🔴 抑制时也要 Stop，否则上一轮的 tween 会继续跑、停在半截
        this.StopCardSlideIn()
        return 0
    end
    return this.PlayCardSlideIn(this.nextPlayIsSwitch)
end

-- 数据刷新（领奖、一键领取、任务变更事件）：只刷新列表，不重播入场。
-- 用 pcall 只为保证复位 —— 标记卡在 true 会让后面所有入场永久失效。
function this.RefreshDailySilently()
    this.suppressCardAnim = true
    local ok, err = pcall(this.OnShowData)
    this.suppressCardAnim = false
    if not ok then
        LogError("MissionDailyPanel_Daily: 静默刷新失败 " .. tostring(err))
    end
end

-- 任务数据变更事件（AddListener 注册的是这个包装，别直接挂 OnShowData —— 那样会重播入场）
function this.OnMissionDailyChanged()
    this.RefreshDailySilently()
end

function this:InitComponent(gameObject)
    -- myGo = gameObject
    this.rectMask = Util.GetGameObject(gameObject,"rect"):GetComponent("Image")
    this.rewardPre = Util.GetGameObject(gameObject, "rewardPre")
    local v = Util.GetGameObject(gameObject, "rect"):GetComponent("RectTransform").rect
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, Util.GetGameObject(gameObject, "rect").transform,
            this.rewardPre, nil, Vector2.New(v.width, v.height), 1, 1, Vector2.New(0,0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 1
    this.NoviceItemList = {}--存储itemview 重复利用

    this.reward = Util.GetGameObject(gameObject, "rewardBg/reward")
    this.Slider = Util.GetGameObject(this.reward, "progress/Fill Area/Slider"):GetComponent("Slider")

    this.rewardPanel = Util.GetGameObject(this.reward, "RewardPanel")
    this.RewardPanelGetInfo = Util.GetGameObject(this.rewardPanel, "getInfo")
    this.boxItemGrid = Util.GetGameObject(this.rewardPanel, "ViewRect/grid").transform

    for i = 1, 4 do
        boxList[i] = Util.GetGameObject(this.reward, "btnList/BoxBtn"..i)
        allMissionDailyBoxItemPres[i] = SubUIManager.Open(SubUIConfig.ItemView, this.boxItemGrid)
    end
    this.rewardMaskBtn = Util.GetGameObject(this.rewardPanel, "rewardMaskBtn")
    this.activityText = Util.GetGameObject(this.reward, "activity/Text"):GetComponent("Text")

    this.receiveAllBtn = Util.GetGameObject(gameObject, "receiveAllBtn")
end

function this:BindEvent()
    Util.AddClick(this.rewardMaskBtn, function()
        this.rewardMaskBtn:SetActive(false)
        this.rewardPanel:SetActive(false)
    end)

    Util.AddClick(this.receiveAllBtn, function()
        NetManager.TakeMissionAllRewardRequest(TaskTypeDef.DayTask,function (msg)
            if msg.drop == nil then return end
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                for i = 1,#msg.missionIds do
                    TaskManager.SetTypeTaskState(TaskTypeDef.DayTask, msg.missionIds[i], SingleDailyMissionState.GetFinish)
                    -- 检测红点状态
                    CheckRedPointStatus(RedPointType.DailyTask)
                    CheckRedPointStatus(RedPointType.SecretTer)
                end
                this.RefreshDailySilently()
            end)
        end)
    end)
end
function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.OnMissionDailyChanged)
    Game.GlobalEvent:AddEvent(GameEvent.CloseUI.OnClose, this.ClosePanel)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged,this.OnMissionDailyChanged)
    Game.GlobalEvent:RemoveEvent(GameEvent.CloseUI.OnClose, this.ClosePanel)
end

function this:OnShow(_parent,...)
    -- parent = _parent
    sortingOrder = _parent.sortingOrder
    --不定参中包含的不定参 _args[1]为面板类型 _args[2]之后(包括)为打开面板后传入的不定参
    local args = {...}
    -- fun = args[1]
    this.rectMask.enabled = true
    -- 入场节奏：第一次 OnShow 是「打开面板」，之后每次都是「切页签」（见 PlayCardSlideIn）
    this.nextPlayIsSwitch = shownOnce
    shownOnce = true
    this.OnShowData()
end

function this:OnSortingOrderChange(sortingOrder)
    for i, v in pairs(this.NoviceItemList) do
        for j = 1, #this.NoviceItemList[i] do
            if this.NoviceItemList[i][j] and this.NoviceItemList[i][j].gameObject then
                this.NoviceItemList[i][j]:SetEffectLayer(sortingOrder)
            end
        end
    end
    --特效层级重设
    for i = 1,#boxList do
        Util.AddParticleSortLayer(boxList[i], sortingOrder)
    end
end

function this.OnShowData()
    dailyTasksConfig = ConfigManager.GetConfig(ConfigName.DailyTasksConfig)
    curDailyMissionData = {}
    curDailyMissionBoxData = {}
    allAvailableTask = {}
    for i, v in pairs(TaskManager.GetTypeTaskList(TaskTypeDef.DayTask)) do
        if v.missionId < 10000 then
            if dailyTasksConfig[v.missionId].OpenLevel  and ActTimeCtrlManager.SingleFuncState(dailyTasksConfig[v.missionId].OpenLevel) then
                table.insert(curDailyMissionData,v)
            end
        else
            if dailyTasksConfig[v.missionId].OpenLevel and ActTimeCtrlManager.SingleFuncState(dailyTasksConfig[v.missionId].OpenLevel) then
                table.insert(curDailyMissionBoxData,v)
            end
        end
    end
    table.sort(curDailyMissionData, function(a,b)
        if a.state == b.state then
            return a.missionId < b.missionId
        else
            return SortDailyMissionState[a.state] < SortDailyMissionState[b.state]
        end
    end)

    -- local allTask = {}
    this.ScrollView:SetData(curDailyMissionData, function (index, go)
        this.SingleMissionDatasDataShow(go,curDailyMissionData[index])
        -- allTask[index] = go
    end)
    this.SetDailyMissionBox(curDailyMissionBoxData)
    -- DelayCreation(allTask)

    --一键领取按钮状态
    Util.SetGray(this.receiveAllBtn,#allAvailableTask == 0)
    this.receiveAllBtn:GetComponent("Button").enabled = (#allAvailableTask ~= 0)
    -- 列表建完再播入场（放 SetData 之后、且不在每张卡的 updateFunc 里 —— 滚动会逐张触发）
    this.ApplyCardSlideIn()
end

function this.SingleMissionDatasDataShow(_go,_missionData)
    local missionData = _missionData
    local missionConfigData = dailyTasksConfig[missionData.missionId]
    local titleText = Util.GetGameObject(_go, "titleImage/titleText"):GetComponent("Text")
    titleText.text = string.format(GetLanguageStrById(missionConfigData.Desc),missionConfigData.Values[2][1])

    local itemGroup = Util.GetGameObject(_go, "content")
    --滚动条复用重设itemview
    if this.NoviceItemList[_go] then
        for i = 1, 4 do
            this.NoviceItemList[_go][i].gameObject:SetActive(false)
        end
        for i = 1, #missionConfigData.Reward do
            if this.NoviceItemList[_go][i] then
                this.NoviceItemList[_go][i]:OnOpen(false, {missionConfigData.Reward[i][1],missionConfigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
                this.NoviceItemList[_go][i].gameObject:SetActive(true)
            end
        end
    else
        this.NoviceItemList[_go] = {}
        for i = 1, 4 do
            this.NoviceItemList[_go][i] = SubUIManager.Open(SubUIConfig.ItemView, itemGroup.transform)
            this.NoviceItemList[_go][i].gameObject:SetActive(false)
        end
        for i = 1, #missionConfigData.Reward do
            this.NoviceItemList[_go][i]:OnOpen(false, {missionConfigData.Reward[i][1],missionConfigData.Reward[i][2]}, 0.55,false,false,false,sortingOrder)
            this.NoviceItemList[_go][i].gameObject:SetActive(true)
        end
    end

    local receiveBtn = Util.GetGameObject(_go.gameObject, "receiveBtn") --领取
    local goBtn = Util.GetGameObject(_go.gameObject, "goBtn")           --前往
    local Received = Util.GetGameObject(_go.gameObject, "Received")     --已领取
    local getRewardProgressSlider = Util.GetGameObject(_go.gameObject, "getRewardProgress")
    local getRewardProgress = Util.GetGameObject(_go.gameObject, "getRewardProgress/Txt")
    local state = missionData.state--0:未完成 1：完成未领取 2：已达成（已领取）

    receiveBtn:SetActive(state == SingleDailyMissionState.Finish)
    goBtn:SetActive(state == SingleDailyMissionState.NoFinish)
    Received:SetActive(state == SingleDailyMissionState.GetFinish)

    if state == SingleDailyMissionState.GetFinish then
        getRewardProgressSlider:SetActive(false)
    else
        getRewardProgressSlider:SetActive(true)
        getRewardProgressSlider:GetComponent("Slider").value = missionData.progress/missionConfigData.Values[2][1]
        if missionConfigData.Values[2][1] >= 10000 then
            local num = missionConfigData.Values[2][1]/10000
            getRewardProgress:GetComponent("Text").text = missionData.progress.. "/" .. num .. GetLanguageStrById(10042)
        else
            getRewardProgress:GetComponent("Text").text = missionData.progress.. "/" .. missionConfigData.Values[2][1]
        end
    end

    Util.AddOnceClick(goBtn, function()
        if missionConfigData.Jump then
            JumpManager.GoJump(missionConfigData.Jump)
            this.rectMask.enabled = UIManager.IsTopShow(UIName.MissionDailyPanel)
        end
    end)
    Util.AddOnceClick(receiveBtn, function()
        NetManager.TakeMissionRewardRequest(TaskTypeDef.DayTask,missionData.missionId,function (msg)
            UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1,function()
                TaskManager.SetTypeTaskState(TaskTypeDef.DayTask, missionData.missionId, SingleDailyMissionState.GetFinish)
                this.RefreshDailySilently()
                -- 检测红点状态
                CheckRedPointStatus(RedPointType.DailyTask)
                CheckRedPointStatus(RedPointType.SecretTer)
            end)
        end)
    end)

    if state == SingleDailyMissionState.Finish then
        if this.IsAvailableTask(missionData.missionId) then
            table.insert(allAvailableTask,missionData.missionId)
        end
    end
end

--判断是否含有这个已完成的任务
function this.IsAvailableTask(missionId)
    for i = 1,#allAvailableTask do
        if allAvailableTask[i] == missionId then
            return false
        end
    end
    return true
end

--每日任务宝箱赋值
function this.SetDailyMissionBox(_missionDatas)
    for i = 1, math.max(#_missionDatas, #boxList) do
        local go = boxList[i]
        if not go then
            go = newObject(boxList[4])
            go.transform:SetParent(this.btnList.transform)
            go.name = "BoxBtn"..i
            go.transform.localScale = Vector3.one
            go.transform.localPosition = Vector3.zero
            boxList[i] = go
        end
        go.gameObject:SetActive(false)
    end

    local curGetRewardNum = 0
    for i, v in pairs(curDailyMissionBoxData) do
        if v.progress > curGetRewardNum then
            curGetRewardNum = v.progress
        end
    end
    this.Slider.value = curGetRewardNum/dailyTasksConfig[_missionDatas[#_missionDatas].missionId].Values[2][1]
    this.activityText.text = curGetRewardNum
    for i, v in pairs(_missionDatas) do
        boxList[i]:SetActive(true)
        local missionConfigData = dailyTasksConfig[v.missionId]
        Util.GetGameObject(boxList[i], "num"):GetComponent("Text").text = missionConfigData.Values[2][1]
        Util.GetGameObject(boxList[i], "biaoxiang"):GetComponent("Image").enabled = (not (v.state == SingleDailyMissionState.Finish or  v.state == SingleDailyMissionState.GetFinish))
        Util.GetGameObject(boxList[i], "UI_Effect_BaoXiang_KaiQi"):SetActive(v.state == SingleDailyMissionState.GetFinish)
        Util.GetGameObject(boxList[i], "UI_Effect_BaoXiang_KaiQi/MeiKaiQi"):SetActive(false)
        Util.GetGameObject(boxList[i], "redPoint"):SetActive(v.state == SingleDailyMissionState.Finish)
        Util.GetGameObject(boxList[i], "UI_Effect_BaoXiang_KeKaiQi"):SetActive(v.state == SingleDailyMissionState.Finish)
        Util.GetGameObject(boxList[i], "getFinish"):SetActive(v.state == SingleDailyMissionState.GetFinish)

        if v.state == SingleDailyMissionState.Finish then
            if this.IsAvailableTask(v.missionId) then
                table.insert(allAvailableTask,v.missionId)
            end
        end

        Util.AddOnceClick(boxList[i], function()
            this.MissionBoxClick(boxList[i],v)
        end)
    end
end
function this.MissionBoxClick(btn,_singleData)
    if  _singleData.state == SingleDailyMissionState.NoFinish or _singleData.state == SingleDailyMissionState.GetFinish then
        local curConfig = dailyTasksConfig[_singleData.missionId]
        this.RewardPanelGetInfo:GetComponent("Text").text = GetLanguageStrById(11362)..curConfig.Values[2][1]..GetLanguageStrById(11363)

        local reward = dailyTasksConfig[_singleData.missionId]
        if reward then
            for i = 1, math.max(#allMissionDailyBoxItemPres, #reward.Reward) do
                local go = allMissionDailyBoxItemPres[i]
                if not go then
                    go = SubUIManager.Open(SubUIConfig.ItemView, this.boxItemGrid)
                    go.gameObject.name = "frame"..i
                    allMissionDailyBoxItemPres[i] = go
                end
                go.gameObject:SetActive(false)
            end
            for i = 1, #reward.Reward do
                allMissionDailyBoxItemPres[i].gameObject:SetActive(true)
                allMissionDailyBoxItemPres[i]:OnOpen(false,reward.Reward[i],0.55)
            end
        end

        this.rewardMaskBtn:SetActive(true)
        this.rewardPanel:SetActive(true)
    elseif _singleData.state == SingleDailyMissionState.Finish then
        Util.GetGameObject(btn, "UI_Effect_BaoXiang_KeKaiQi"):SetActive(false)
        Util.GetGameObject(btn, "UI_Effect_BaoXiang_KaiQi"):SetActive(true)
        Util.GetGameObject(btn, "UI_Effect_BaoXiang_KaiQi/MeiKaiQi"):SetActive(true)
        btn:GetComponent("Button").enabled = false
        this.timer = Timer.New(function()
            NetManager.TakeMissionRewardRequest(TaskTypeDef.DayTask,_singleData.missionId,function (msg)
                TaskManager.SetTypeTaskState(TaskTypeDef.DayTask, _singleData.missionId, SingleDailyMissionState.GetFinish)
                UIManager.OpenPanel(UIName.RewardItemPopup,msg.drop,1)
                this.RefreshDailySilently()
            end)
            this.timer:Stop()
            this.timer = nil
            btn:GetComponent("Button").enabled = true
        end, 1, 1, true)
        this.timer:Start()
    end
end

function this.GetCurIsOpen(LevelRegion)
    if LevelRegion[1] == 1 then--等级
        return PlayerManager.level >= LevelRegion[2]
    elseif LevelRegion[1] == 2 then--关卡
        return FightPointPassManager.GetFightIsOpenById(LevelRegion[2])
    end
end

--跳转显示新手提示圈
function this.ShowGuideGo()
end

--用于跳转回调
function this.ClosePanel()
    this.rectMask.enabled = true
end

function this:OnClose()
    -- 🔴 这里**不能**复位 shownOnce：切页签时 MissionDailyPanel.SwitchView 也会对旧页签调
    --    OnClose，复位了就把「切页签」误判成「首次打开」。复位只放 OnDestroy（真销毁）。
    this.StopCardSlideIn()
    FightPointPassManager.isBeginFight = false
    this.rectMask.enabled = true
end

function this:OnDestroy()
    this.StopCardSlideIn()
    shownOnce = false   -- 真销毁：下次打开重新按「首次打开」的节奏播
    -- allMissionDailyPres = {}
    -- allMissionDailyItemPres = {}
    boxList = {}
    allMissionDailyBoxItemPres = {}
end

return this