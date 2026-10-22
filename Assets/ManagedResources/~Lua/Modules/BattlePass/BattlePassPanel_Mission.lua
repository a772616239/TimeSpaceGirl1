local this = {}
local sortingOrder = 0
local battlePassReward = ConfigManager.GetConfig(ConfigName.BattlePassReward)
local battlePassConfig = ConfigManager.GetConfig(ConfigName.BattlePassConfig)
local TabBox = require("Modules/Common/TabBox")
local typeIndex = {
    [0] = 1,
    [1] = 0,
    [2] = 2,
}
-- 🔴 别叫 type：这个局部名会遮住 Lua 的 type()，本文件后面任何 type(obj) 都会变成"调用一张表"
local btnStyle = {
    [0] = {color = Color.New(255/255,174/255,53/255,1),text = string.format("<color=#53360A>%s</color>",GetLanguageStrById(10023))},
    [1] = {color = Color.New(255/255,209/255,43/255,1),text = string.format("<color=#544307>%s</color>",GetLanguageStrById(10022))},
    [2] = {color = Color.New(255/255,209/255,43/255,1),text = string.format("<color=#FFFFFFFF>%s</color>",GetLanguageStrById(10350))},
}
local _TabData = {
    [1] = { default = "cn2-X1_shouzha_yeqian_01", select = "cn2-X1_shouzha_yeqianxuanzhong_01"},
    [2] = { default = "cn2-X1_shouzha_yeqian_02", select = "cn2-X1_shouzha_yeqianxuanzhong_02"},
    [3] = { default = "cn2-X1_shouzha_yeqian_03", select = "cn2-X1_shouzha_yeqianxuanzhong_03"},
    [4] = { default = "cn2-X1_shouzha_yeqian_04", select = "cn2-X1_shouzha_yeqianxuanzhong_04"},
    [5] = { default = "cn2-X1_shouzha_yeqian_05", select = "cn2-X1_shouzha_yeqianxuanzhong_05"},
    [6] = { default = "cn2-X1_shouzha_yeqian_06", select = "cn2-X1_shouzha_yeqianxuanzhong_06"},
    [7] = { default = "cn2-X1_shouzha_yeqian_07", select = "cn2-X1_shouzha_yeqianxuanzhong_07"},
    [8] = { default = "cn2-X1_shouzha_yeqian_08", select = "cn2-X1_shouzha_yeqianxuanzhong_08"},
    [9] = { default = "cn2-X1_shouzha_yeqian_09", select = "cn2-X1_shouzha_yeqianxuanzhong_09"},
    [10] = { default = "cn2-X1_shouzha_yeqian_10", select = "cn2-X1_shouzha_yeqianxuanzhong_10"},
    [11] = { default = "cn2-X1_shouzha_yeqian_11", select = "cn2-X1_shouzha_yeqianxuanzhong_11"},
    [12] = { default = "cn2-X1_shouzha_yeqian_12", select = "cn2-X1_shouzha_yeqianxuanzhong_12"},
    [13] = { default = "cn2-X1_shouzha_yeqian_13", select = "cn2-X1_shouzha_yeqianxuanzhong_13"},
}
this.pross = 0
local tabIndex = 1

--============================== 任务卡入场（左滑入 + 淡入）==============================
-- 参考 Assets/Art/UIAni/cn2-X1_UI_TreasureStorePopup.anim（dump_clip.py 反解，m_EditorCurves 12 条全读）：
--   grid/item1..3     m_AnchoredPosition.x   -200 / -150 / -100 → 0   逐格错开（左侧滑入）
-- 本页做**反向**：从右侧 +260 向左归位 0。
--   grid/item1..3/Bg  m_Color.a              0.3647 → 1             淡入比位移长
-- 前 4 条（Panel 的位移/现高、Panel/Bg 的回弹 + alpha）是弹窗本体进出场，
-- 本页是 BattlePassPanel 的子页，没有对应节点、也不该整页位移 ⇒ 只复刻列表项那 6 条。
--
-- 作用对象是右侧任务列表的**任务卡**（itempre 由 ScrollCycleView 克隆成 item1..itemN）。
--
-- 🔴 位移写卡的**直接子节点**，不写卡根节点：ScrollCycleView:SetData / SetItemIndex 每次都把
--    item 根的 anchoredPosition 直接重写（换页、滚动都会），写根节点必被抹回原位。
-- 🔴 本列表 Open 时传的是 fixedCount=1 / itemCount=1 ⇒ 一屏只有 1 张卡，item 池反复复用，
--    所以每次 SetData 之后都要在终值上重新起播（PlayTaskSlideIn 开头先 Stop 复位）。
local kCardSlideFrom     = 260      -- 起点位移（px）：卡宽 870 的 ~30%；参考是 203 宽的 73%~98%
-- 方向：从**右侧**滑入（起点 x + kCardSlideFrom，向左归位）。参考 clip 是左侧滑入（-200 → 0），
-- 这里按要求做反向；要改回左侧只需把 PlayTaskSlideIn 里的 + 改成 -（见该处注释）。
local kCardSlideDuration = 0.22     -- 单卡时长
local kCardSlideStep     = 0.05     -- 多卡时相邻错开（当前一屏 1 张，实际不起作用）
local kCardFadeFrom      = 0.3647   -- 参考 item/Bg 的 alpha 起点
local kCardFadeNode      = "bg"     -- 只有底板是整卡大小的 Image，参考也只淡底板

-- 任务卡的可视子节点（prefab 实测 itempre 870×200）：这 6 个一起左移 = 整卡滑入
local kCardNodes = { "bg", "title", "reward", "mission", "Slider", "receiveOrGo" }

local cardSlideItems = {}   -- { rect, x, y, graphic, color, tween }，rect 与 graphic 二选一

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
function this.StopTaskSlideIn()
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
    local sv = this.scrollViewList
    if type(sv) == "table" and type(sv.ForeachItemGO) == "function" then
        sv:ForeachItemGO(function(_, go)
            if Alive(go) and go.activeSelf then
                cards[#cards + 1] = go
            end
        end)
    end
    return cards
end

-- 起播：每张卡从右侧 260px 向左滑回原位，底板 alpha 0.3647 → 1。
function this.PlayTaskSlideIn()
    this.StopTaskSlideIn()
    local cards = CollectCards()
    if #cards <= 0 then
        return 0
    end
    local ok, err = pcall(function()
        for ci = 1, #cards do
            local card = cards[ci]
            local delay = (ci - 1) * kCardSlideStep
            -- 位移：卡片的 6 个可视子节点一起走
            for i = 1, #kCardNodes do
                local go = Util.GetGameObject(card, kCardNodes[i])
                if Alive(go) and go.activeSelf then
                    local rect = go:GetComponent("RectTransform")
                    if Alive(rect) then
                        local pos = rect.anchoredPosition
                        -- 从右侧滑入：起点在右边，向左归位（反向 = 把这里的 + 改回 -）
                        rect.anchoredPosition = Vector2.New(pos.x + kCardSlideFrom, pos.y)
                        local tween = rect:DOAnchorPosX(pos.x, kCardSlideDuration)
                        tween:SetDelay(delay)
                        SetEaseSafe(tween, "OutQuad")
                        tween:OnComplete(function()
                            if Alive(rect) then
                                rect.anchoredPosition = Vector2.New(pos.x, pos.y)
                            end
                        end)
                        cardSlideItems[#cardSlideItems + 1] = { rect = rect, x = pos.x, y = pos.y, tween = tween }
                    end
                end
            end
            -- 淡入：只淡底板（参考里就是 item/Bg，装饰图跟着底板走但不透明）
            local bg = Util.GetGameObject(card, kCardFadeNode)
            if Alive(bg) then
                local image = bg:GetComponent("Image")
                if Alive(image) then
                    local color = image.color
                    image.color = WithAlpha(color, kCardFadeFrom)
                    local tween = image:DOFade(color.a, kCardSlideDuration)
                    tween:SetDelay(delay)
                    SetEaseSafe(tween, "OutQuad")
                    tween:OnComplete(function()
                        if Alive(image) then
                            image.color = color
                        end
                    end)
                    cardSlideItems[#cardSlideItems + 1] = { graphic = image, color = color, tween = tween }
                end
            end
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把任务卡留在半截位置/半透明
        LogError("BattlePassPanel_Mission: 任务卡入场失败 " .. tostring(err))
        this.StopTaskSlideIn()
        return 0
    end
    return #cards
end

function this:InitComponent(gameObject)
    this.panel = Util.GetGameObject(gameObject, "BattlePassPanel_Mission")
    this.backBtn = Util.GetGameObject(this.panel, "btnBg/BackBtn")
    this.bgScrol = Util.GetGameObject(this.panel, "bg/bgScrol")

    this.goals = Util.GetGameObject(this.panel, "bg/goals")

    --购买
    this.buyBattlePass = Util.GetGameObject(this.goals, "BuyBattlePass")
    --当前完成任务
    this.goalTxt = Util.GetGameObject(this.goals, "GoalTxt"):GetComponent("Text")
    this.targetReward = Util.GetGameObject(this.panel, "Passpre")

    --目标奖励
    this.ScrollView = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.bgScrol.transform,
        this.targetReward, nil, Vector2.New(this.bgScrol.transform.rect.width, this.bgScrol.transform.rect.height), 2, 1, Vector2.New(5, 0))
    this.ScrollView.moveTween.MomentumAmount = 1
    this.ScrollView.moveTween.Strength = 2

    --任务
    this.itemPre = Util.GetGameObject(this.panel, "itempre")
    this.tastScrol = Util.GetGameObject(this.panel, "Poor/Panel/scroll")
    local w = this.tastScrol.transform.rect.width
    local h = this.tastScrol.transform.rect.height

    -- this.scrollViewList = {}
    -- for i = 1, battlePassConfig[1].TaskTabCount, 1 do
    --     this.scrollViewList[i] = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.tastScrol.transform,
    --     this.itemPre, nil, Vector2.New(w, h), 1, 1, Vector2.New(0, 10))
    -- end

    this.scrollViewList = SubUIManager.Open(SubUIConfig.ScrollCycleView, this.tastScrol.transform,
        this.itemPre, nil, Vector2.New(w, h), 1, 1, Vector2.New(0, 10))

    this.tabBox = Util.GetGameObject(this.panel, "Poor/Panel/TabBox")
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, _TabData)

    --奖励预览
    this.rewardPreview = Util.GetGameObject(this.panel, "bg/rewardPreview")
    this.reward1 = Util.GetGameObject(this.rewardPreview, "reward1")
    this.reward2 = Util.GetGameObject(this.rewardPreview, "reward2")
    this.rewardGoal = Util.GetGameObject(this.rewardPreview, "Text"):GetComponent("Text")

    --解锁
    this.unlock = Util.GetGameObject(this.panel, "Poor/Unlock")
    this.unlockBtn = Util.GetGameObject(this.unlock, "Button")
    this.taskPanel = Util.GetGameObject(this.panel, "Poor/Panel")

    this.btnTaskAllReceive = Util.GetGameObject(this.panel, "btnBg/taskAllReceive")
end

function this:BindEvent()
    Util.AddOnceClick(this.backBtn, function()
        this.battlePanel.SwitchView(1)
    end)
    Util.AddOnceClick(this.unlockBtn, function() 
        this.battlePanel.Opendetail()
    end)
    Util.AddOnceClick(this.btnTaskAllReceive, function()
        NetManager.TakeLetterMissionRewardAllRequest(function(respond)    
            UIManager.OpenPanel(UIName.RewardItemPopup,respond.drop,1,function()
                for i = 1, #respond.missionIds do
                    TaskManager.SetTypeTaskState(TaskTypeDef.BattlePass,respond.missionIds[i],2)
                end

                this.RefreshAllTaskBtn()
                this.RefreshTaskAllReceiveState()
                this.RefreshPassData()

                CheckRedPointStatus(RedPointType.BattlePassMission)
            end)
        end)
    end)
end

function this:AddListener()
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshPassData)
    Game.GlobalEvent:AddEvent(GameEvent.MissionDaily.OnMissionDailyChanged, this.RefreshAllTaskBtn)
end

function this:RemoveListener()
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged,this.RefreshPassData)
    Game.GlobalEvent:RemoveEvent(GameEvent.MissionDaily.OnMissionDailyChanged,this.RefreshAllTaskBtn)
end
local indexName={
        [1]="战队", -- 默认状态
        [2]="基础",  -- 选中状态
        [3]="招募",     -- 锁定状态
        [4]="装备大师",
        [5]="戒指芯片",
        [6]="培养",
        [7]="竞技",
        [8]="探索",
        [9]="物资收集",
        [10]="神之塔",
        [11]="公会",
        [12]="试炼",
        [13]="时空战场",
}
function this.TabAdapter(tab, index, status)
    local title = Util.GetGameObject(tab, "title"):GetComponent("Image")
    title.sprite = Util.LoadSprite(GetPictureFont(_TabData[index][status]))
    local select = Util.GetGameObject(tab, "select")
    select:SetActive(status == "select")

    local txt = Util.GetGameObject(tab, "Text"):GetComponent("Text")
    local HighText = Util.GetGameObject(tab, "title/HighText"):GetComponent("Text")
    txt.text=GetLanguageStrByStr(indexName[index]) or ("Tab"..index)
    HighText.text=GetLanguageStrByStr(indexName[index]) or ("Tab"..index)
    HighText.gameObject:SetActive(status == "select")
    txt.gameObject:SetActive(status ~= "select")
end

function this.SwitchView(index)
    tabIndex = index
    if this.scrollData then
        this.scrollViewList:SetData(this.scrollData[index],function (_index,go)
            this.SetScrollData(go,this.scrollData[index][_index])
        end)
    end
    -- 任务卡入场：领奖等数据刷新触发的重建不播，只有玩家主动换屏才播
    if this.suppressTaskAnim then
        this.StopTaskSlideIn()
    else
        this.PlayTaskSlideIn()
    end
end
function this:OnSortingOrderChange(_sortingOrder)
    -- this.rewardPreview:GetComponent("Canvas").sortingOrder = sortingOrder + 30
    this.goals:GetComponent("Canvas").sortingOrder = sortingOrder + 30
end

-- 找到第一个带红点的页签序号（box 下第 i 个子节点即第 i 个页签）；无红点返回 nil
function this:GetFirstRedPointTab()
    local box = Util.GetGameObject(this.tabBox, "box")
    if not box or IsNull(box) then
        return nil
    end
    local tf = box.transform
    for i = 1, tf.childCount do
        local child = tf:GetChild(i - 1)
        if child and not IsNull(child) then
            local red = Util.GetGameObject(child.gameObject, "Redpot")
            if red and red.activeSelf then
                return i
            end
        end
    end
    return nil
end

-- 把第 index 个页签滚动进可视区（TabBox 自带纵向 ScrollRect，content = box；
-- tolua 下 ScrollRect 类成员未绑定，直接移动 box.anchoredPosition 实现，
-- ScrollRect 会在下次交互时按 content 位置重新夹紧）
function this:ScrollTabIntoView(index)
    local box = Util.GetGameObject(this.tabBox, "box")
    if not box or IsNull(box) then
        return
    end
    local boxTf = box:GetComponent("RectTransform")
    if not boxTf then
        return
    end
    local tf = box.transform
    if index < 1 or index > tf.childCount then
        return
    end
    local child = tf:GetChild(index - 1)
    if not child or IsNull(child) then
        return
    end
    local childTf = child:GetComponent("RectTransform")
    if not childTf then
        return
    end
    local viewTf = this.tabBox:GetComponent("RectTransform")
    local viewH = viewTf and viewTf.rect.height or 0
    local contentH = boxTf.rect.height
    -- 子节点在 content 局部空间里位于顶部之下（localPosition.y 为负），距内容顶 = -localPosition.y
    -- 想让该页签顶部贴近视口顶部（留 20px 间距），content 需上移 topDist
    local desired = childTf.localPosition.y + 20
    -- 纵向滚动范围：anchoredPosition.y ∈ [-(contentH - viewH), 0]
    local minY = (contentH > viewH) and -(contentH - viewH) or 0
    if desired > 0 then desired = 0 end
    if desired < minY then desired = minY end
    boxTf.anchoredPosition = Vector2.New(boxTf.anchoredPosition.x, desired)
end

function this:OnShow(panel,_sortingOrder)
    sortingOrder = _sortingOrder
    this.battlePanel = panel
    this.RefreshPassData()

    -- tabIndex = 1
    this.RefreshAllTaskBtn()

    -- 进入「有红点」的界面：自动把 tab 列表定位到第一个带红点的页签
    local redIndex = this:GetFirstRedPointTab()
    if redIndex then
        tabIndex = redIndex
    end
    this.TabCtrl:ChangeTab(tabIndex)
    this:ScrollTabIntoView(tabIndex)

    -- 任务卡左滑入 + 底板淡入（RefreshAllTaskBtn 里已抑制过一轮，这里补播一次）
    this.PlayTaskSlideIn()

    this:OnSortingOrderChange(sortingOrder)

    this.RefreshTaskAllReceiveState()
end

--刷新进度表
function this.RefreshPassData()
    this.passReward = {}
    local passData
    NetManager.BattlePassRequest(function(msg)
        if PrivilegeManager.GetPrivilegeOpenStatusById(92001) then
            this.buyBattlePass:SetActive(false)
            this.unlock:SetActive(false)
            this.taskPanel:GetComponent("RectTransform").offsetMax = Vector2.New(0,0)
        else
            this.buyBattlePass:SetActive(true)
            this.unlock:SetActive(true)
            this.taskPanel:GetComponent("RectTransform").offsetMax = Vector2.New(0,-145)
        end
        local v2 = Vector2.New(this.tastScrol.transform.rect.width,this.tastScrol.transform.rect.height)

        this.scrollViewList.gameObject:GetComponent("RectTransform").sizeDelta = v2

        passData = msg
        this.pross = msg.pross
        this.goalTxt.text = msg.pross
        for index, value in ConfigPairs(battlePassReward) do
            local data = {}
            data[1] = value
            if passData then
                for pindx, pvalue in ipairs(passData.info) do
                    if pvalue.missionId == value.Id then
                        data[2] = pvalue
                    end
                end
            end
            this.passReward[value.Id] = data
        end
        this.ScrollView:SetData(this.passReward,function (index,go)
            this.PassScroll(go,this.passReward[index],index)
        end)
        if passData and passData.info then
            this.ScrollView:SetIndex(#passData.info)
        end
    end)
end

--刷新整体任务表
function this.RefreshAllTaskBtn()
    this.taskData = TaskManager.GetTypeTaskList(TaskTypeDef.BattlePass)

    this.scrollData = {}
    local redPointList = {}
    for i = 1, Util.GetGameObject(this.tabBox,"box").transform.childCount do
        redPointList[i] = Util.GetGameObject(Util.GetGameObject(this.tabBox,"box").transform:GetChild(i-1).gameObject,"Redpot")
        redPointList[i]:SetActive(false)
    end
    for index, value in ipairs(this.taskData) do
        if not this.scrollData[ConfigManager.GetConfigData(ConfigName.BattlePassTask, value.missionId).Tab] then
            this.scrollData[ConfigManager.GetConfigData(ConfigName.BattlePassTask, value.missionId).Tab] = {}
        end
        table.insert(this.scrollData[ConfigManager.GetConfigData(ConfigName.BattlePassTask, value.missionId).Tab],value)
        if value.state == 1 then
            redPointList[ConfigManager.GetConfigData(ConfigName.BattlePassTask, value.missionId).Tab]:SetActive(true)
        end
    end
    for i = 1, #this.scrollData, 1 do
        this.scrollData[i] = this.SortData(this.scrollData[i])
    end

    this.RefreshTaskAllReceiveState()
    -- 数据刷新（领奖 / 红点变化）重建列表时不播入场，避免卡片闪一下
    this.suppressTaskAnim = true
    this.SwitchView(tabIndex)
    this.suppressTaskAnim = false
end

--刷新任务列表数据
function this.SetScrollData(pre,data)
    if pre == nil or data == nil then
        return
    end
    this.SetActive(pre,true)
    local value = ConfigManager.GetConfigData(ConfigName.BattlePassTask, data.missionId)
    local activityRewardGo = pre
    local sConFigData = value
    --任务标题
    local titleText = Util.GetGameObject(activityRewardGo, "title"):GetComponent("Text")
    titleText.text = GetLanguageStrById(value.Desc)
    --进度
    local missionText = Util.GetGameObject(activityRewardGo, "mission"):GetComponent("Text")
    missionText.text = data.progress.."/"..value.Values[2][1]
    --奖励
    local reward = Util.GetGameObject(activityRewardGo, "reward")
    --进度条
    local slider = Util.GetGameObject(activityRewardGo, "Slider")
    slider:GetComponent("Slider").value = data.progress/value.Values[2][1]

    if not itemGrid then
        itemGrid = {}
    end
    if not itemGrid[pre] then
        itemGrid[pre] = SubUIManager.Open(SubUIConfig.ItemView,reward.transform)
    end
    itemGrid[pre]:OnOpen(false, sConFigData.Reward[1], 0.55, false)

    --领取或者前往
    local receiveOrGo = Util.GetGameObject(activityRewardGo, "receiveOrGo")
    --0-未完成，1-完成未领取  2-已领取
    local state = data.state
    --红点
    this.SetActive(Util.GetGameObject(receiveOrGo.gameObject, "redPoint"),state == 1)
    this.SetActive(slider,value.ShowProgress == 1)
    this.SetActive(missionText.gameObject,value.ShowProgress == 1)
    --领取或者前往按钮
    local receiveOrGoBtn = Util.GetGameObject(receiveOrGo, "Button")
    Util.GetGameObject(receiveOrGoBtn, "Text"):GetComponent("Text").text = btnStyle[state].text
    receiveOrGoBtn:GetComponent("Image").color = btnStyle[state].color

    this.SetActive(Util.GetGameObject(receiveOrGo, "Button").gameObject,state ~= 2)
    this.SetActive(Util.GetGameObject(receiveOrGo, "received").gameObject,state == 2)

    Util.AddOnceClick(receiveOrGoBtn, function()
        if state == 1 then
            NetManager.TakeMissionRewardRequest(TaskTypeDef.BattlePass,sConFigData.Id, function(respond)    
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 1,function ()
                    this.RefreshAllTaskBtn()
                    CheckRedPointStatus(RedPointType.BattlePassMission)
                end)
            end)
        elseif state == 0 then
            if sConFigData.Jump then
                JumpManager.GoJump(sConFigData.Jump)
            end
        end
    end)
end

--刷新进度数据
function this.PassScroll(go, data, index)
    go:SetActive(true)
    if not itemsGrid1 then
        itemsGrid1 = {}
    end
    if not itemsGrid2 then
        itemsGrid2 = {}
    end
    local item1 = Util.GetGameObject(go, "reward1/itemMask/item")
    if not itemsGrid1[go] then
        itemsGrid1[go] = SubUIManager.Open(SubUIConfig.ItemView,item1.transform)
    end
    local item2 = Util.GetGameObject(go, "reward2/itemMask/item")
    if not itemsGrid2[go] then
        itemsGrid2[go] = SubUIManager.Open(SubUIConfig.ItemView,item2.transform)
    end

    itemsGrid1[go]:OnOpen(false, data[1].FreeReward, 0.65, false, false, false, sortingOrder + 10)
    itemsGrid2[go]:OnOpen(false, data[1].BattleReward, 0.65, false, false, false, sortingOrder + 10)

    local lvLock2 = Util.GetGameObject(go, "reward2/lvlock")--vip等级锁
    this.SetActive(Util.GetGameObject(go,"reward1/numBg"), Util.GetGameObject(item1,"ItemView/item/num").activeSelf)
    this.SetActive(Util.GetGameObject(go,"reward2/numBg"), Util.GetGameObject(item2,"ItemView/item/num").activeSelf)
    local isActive = PrivilegeManager.GetPrivilegeOpenStatusById(92001)--是否进阶
    local lock1 = Util.GetGameObject(go, "reward1/lock")--普遍锁
    local lock2 = Util.GetGameObject(go, "reward2/lock")--进阶锁
    local getbtn1 = Util.GetGameObject(go, "reward1/getbtn")--普通领取
    local getbtn2 = Util.GetGameObject(go, "reward2/getbtn")--进阶领取
    local received1 = Util.GetGameObject(go, "reward1/received")--普通已领取
    local received2 = Util.GetGameObject(go, "reward2/received")--进阶已领取
    local Slider1 = Util.GetGameObject(go, "Slider1")

    --需要完成的任务数
    Util.GetGameObject(go, "num"):GetComponent("Text").text = data[1].TaskCount

    this.RefreshRightReward(data[1].TaskCount)

    --设置普通状态
    local setState = function(state)
        this.SetActive(Util.GetGameObject(go,"reward1/mask"), not state)

        if data[2] then
            local isCan = data[2].takTime == 0
            this.SetActive(received1,not isCan)
            this.SetActive(getbtn1,isCan and state)
            this.SetActive(lock1,not isCan and state and not received1.activeSelf)
        else
            this.SetActive(received1,false)
            this.SetActive(getbtn1,state)
            this.SetActive(lock1,false)
        end
    end

    --设置进阶状态
    local setVipState = function(state)
        this.SetActive(Util.GetGameObject(go,"reward2/mask"), not state)
        this.SetActive(lvLock2, data[1].NeedVIP ~= 0)

        local isVip = VipManager.GetVipLevel() >= data[1].NeedVIP--如果玩家VIP >= 奖励需要的VIP
        if data[2] then
            local isCan = data[2].viptakTime == 0--若奖励可领取
            this.SetActive(received2,not isCan)
            this.SetActive(getbtn2,isVip and isCan and isActive and state)
            if not PrivilegeManager.GetPrivilegeOpenStatusById(92001) then
                this.SetActive(lock2, true)
            else
                this.SetActive(lock2,not isVip and isCan and state and not received2.activeSelf)
            end
        else
            this.SetActive(getbtn2,isVip and isActive and state == 0)
            this.SetActive(lock2, not isActive)
            this.SetActive(received2,false)
        end
    end

    local state = false
    if this.pross >= data[1].TaskCount then
        state = true
    end

    setState(state)
    setVipState(state)

    --设置进度条
    local value = 0
    if this.pross > data[1].TaskCount then
        value = 1
    elseif this.pross == data[1].TaskCount then
        value = 0.5 + 0.04
    else
        value = 0
    end
    Util.GetGameObject(Slider1, "Fill Area/Fill"):GetComponent("Image").fillAmount = value

    -- Util.AddOnceClick(go, function()
    --     if this.pross >= data[1].TaskCount then
    --         this.RewardAllReceive()
    --     end
    -- end)
    Util.AddOnceClick(getbtn1, function()
        if this.pross >= data[1].TaskCount then
            this.RewardAllReceive()
        end
    end)
    Util.AddOnceClick(getbtn2, function()
        if this.pross >= data[1].TaskCount then
            this.RewardAllReceive()
        end
    end)
end

--奖励一键领取
function this.RewardAllReceive()
    NetManager.BattlePassGetRequest(0,4, function(respond)
        --获得英雄表现
        if respond.drop.Hero ~= nil and #respond.drop.Hero > 0 then
            local itemDataList = {}
            local itemDataStarList = {}
            Util.GetGameObject(this.panel, "bg"):SetActive(false)
            for i = 1, #respond.drop.Hero do
                local singHeroData = respond.drop.Hero[i]
                HeroManager.UpdateHeroDatas(singHeroData)
                local heroData = ConfigManager.TryGetConfigDataByKey(ConfigName.HeroConfig, "Id", respond.drop.Hero[i].heroId)
                table.insert(itemDataList, heroData)
                table.insert(itemDataStarList, respond.drop.Hero[i].star)
            end
            UIManager.OpenPanel(UIName.PublicGetHeroPanel, itemDataList, itemDataStarList, function ()
                UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 2)
                Util.GetGameObject(this.panel, "bg"):SetActive(true)
            end)
        else
            UIManager.OpenPanel(UIName.RewardItemPopup, respond.drop, 2)
            this.RefreshPassData()
        end
    end)
end

function this.SetActive(go, value)
    if go then
        if value and not go.activeSelf then
            go:SetActive(value)
        elseif not value and go.activeSelf then
            go:SetActive(value)
        end
    end
end

local minNun = 0
local maxNum = 1
--刷新右侧奖励预览
function this.RefreshRightReward(value)
    if value < minNun then
        minNun = value
        if minNun + 6 < maxNum then
            maxNum = minNun + 6
        end
    end
    if value > maxNum then
        maxNum = value
        if value > minNun + 6 then
            minNun = maxNum - 6
        end
    end
    if maxNum == 14 then maxNum = 12 end

    local item1 = Util.GetGameObject(this.reward1, "item")
    if not preview1 then
        preview1 = SubUIManager.Open(SubUIConfig.ItemView,item1.transform)
    end
    local item2 = Util.GetGameObject(this.reward2, "item")
    if not preview2 then
        preview2 = SubUIManager.Open(SubUIConfig.ItemView,item2.transform)
    end

    local value = 0
    local data = battlePassConfig[1].StageSection

    this.SetActive(this.rewardPreview, true)
    for i = 1, #data do
        if i == 1 then
            if maxNum < (data[i] - 1) * 2 then
                value = data[i]
            elseif maxNum > data[i] * 2 and maxNum <= (data[i + 1] - 1) * 2 then
                value = data[i + 1]
            end
        elseif i == (#data - 1) then
            if maxNum > data[i] * 2 then
                value = data[i]
                this.SetActive(this.rewardPreview, false)
            end
        else
            if maxNum > data[i] * 2 and maxNum <= (data[i + 1] - 1) * 2 then
                value = data[i + 1]
            end
        end
    end

    for i = 1, #data do
        if value == data[i] then
            this.rewardGoal.text = value * 2
            preview1:OnOpen(false, this.passReward[value][1].FreeReward, 0.65, false)
            preview2:OnOpen(false, this.passReward[value][1].BattleReward, 0.65, false)

            this.SetActive(Util.GetGameObject(this.reward1,"numBg"), Util.GetGameObject(this.reward1,"item/ItemView/item/num").activeSelf)
            this.SetActive(Util.GetGameObject(this.reward2,"numBg"), Util.GetGameObject(this.reward2,"item/ItemView/item/num").activeSelf)
        end
    end
end

--排序逻辑
function this.SortData(allData)
    if allData == nil then
        return
    end
    table.sort(allData, function(a,b)
        if typeIndex[a.state] == typeIndex[b.state] then
            if a.type == b.type then
                return a.missionId < b.missionId
            else
                return a.type < b.type
            end
        else
            return typeIndex[a.state] < typeIndex[b.state]
        end
    end)
    return allData
end
function this:OnClose()
    this.StopTaskSlideIn()
end

function this:OnDestroy()
    preview1 = nil
    preview2 = nil
    -- DestroyPanel 不走 OnClose，面板还会被 openedList 缓存复用 ⇒ 两处都要收
    this.StopTaskSlideIn()
end

--刷新任务全部领取按钮状态
function this.RefreshTaskAllReceiveState()
    for i, v in ipairs(this.scrollData) do
        for index, value in ipairs(v) do
            if value.state == 1 then
                Util.SetGray(this.btnTaskAllReceive,false)
                return
            end
        end
    end
    Util.SetGray(this.btnTaskAllReceive,true)
end

return this