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

--============================== 选项卡入场（左滑入 + 淡入）==============================
-- 参考 Assets/Art/UIAni/cn2-X1_UI_TreasureStorePopup.anim（dump_clip.py 反解：Scale=1 + Float=9，
-- m_EditorCurves 镜像 12 条 = 3 + 9，全部读完）。分镜（总长 0.3667s，m_LoopTime=1）：
--   Panel                 m_AnchoredPosition.y   -125 → 0        0 → 0.3667s  ← 弹窗本体上移
--   Panel                 m_SizeDelta.y          -250 → 0        0 → 0.3667s  ← 弹窗本体现高（底边钉死）
--   Panel/Bg              m_LocalScale           1.1 → 1         0 → 0.3667s  ← 背景板回弹
--   Panel/Bg              m_Color.a              0.7765 → 1      0 → 0.3667s
--   grid/item1            m_AnchoredPosition.x   -200 → 0        0 → 0.05s     ← 单格最快
--   grid/item2            m_AnchoredPosition.x   -150 → 0        0.05 → 0.1667s
--   grid/item3            m_AnchoredPosition.x   -100 → 0        0.1833 → 0.2833s
--   grid/item1/Bg         m_Color.a              0.3647 → 1      0 → 0.2833s   ← 淡入比位移长
--   grid/item2/Bg         m_Color.a              0.3647 → 1      0.1333 → 0.25s
--   grid/item3/Bg         m_Color.a              0.3647 → 1      0.2333 → 0.3333s
-- 迁移到本页 13 个选项卡：位移方向保持不变（从左侧滑入，被 TabBox 的 RectMask2D 裁出边），
-- 淡入起点取参考的 0.3647，逐格错开 0.03s（参考两格之间 2 帧 @60）。
-- 参考前 4 条是「弹窗本体」的进出场（Panel/Bg 是带 sprite 的底板，不是全屏遮罩），本页是
-- BattlePassPanel 里的一个子页，没有对应节点、也不该整页位移 ⇒ 只复刻 6 条「列表项」曲线。
--
-- 🔴 位移写在 tab 的**子节点**上，不写 tab 根节点：
--   TabBox 把页签克隆进 box，box 挂 VerticalLayoutGroup + ContentSizeFitter ⇒ 布局组只接管
--   页签根节点的 anchoredPosition（每次布局重建都写回），而 tab 的子节点无人管。
--   写根节点会在重建那一帧被抹回原位（切一次页签就建一次布局），写子节点一次都不会被覆盖，
--   也因此不需要"延迟一帧再播"。
--   select 是 90° 旋转的板（本地 +y 才是屏幕 -x），所以它单独走 y 轴。
local kTabSlideFrom     = 140      -- 起点位移（px）。参考 200/150/100 = 203 宽的 73%/55%/37%，取 ~69%
local kTabSlideDuration = 0.16     -- 单格时长（参考单格 0.05~0.12s；13 格取 0.16 才连成一片）
local kTabSlideStep     = 0.03     -- 相邻错开（参考 2 帧 @60 = 0.033s）
local kTabSlideMaxSpan  = 0.4      -- 页签多时压缩错开，整体跨度不超过这个值
local kTabFadeFrom      = 0.3647   -- 参考 item/Bg 的 alpha 起点

-- tab 模板（prefab 实测：203×171，anchor 左上）的 6 个可视子节点
local kTabNodes = {
    { path = "select",         comp = "Image", axis = "y" },  -- 高亮板，z 轴 90° ⇒ 屏幕横向 = 本地 y
    { path = "title",          comp = "Image", axis = "x" },  -- 页签主图
    { path = "title/HighText", comp = "Text",  axis = "x" },  -- 选中态文字
    { path = "LockImage",      comp = "Image", axis = "x" },
    { path = "Redpot",         comp = "Image", axis = "x" },
    { path = "Text",           comp = "Text",  axis = "x" },
}

local tabSlideItems = {}   -- { rect, x, y, graphic, color, posTween, fadeTween }

-- tolua 的枚举/结构体都是运行期注册的：取不到就跳过，异常被 pcall 吃掉会整段静默不播
local function SetEaseSafe(tween, name)
    local enum = _G.Ease
    local value = enum and enum[name]
    if value ~= nil then
        tween:SetEase(value)
    end
    return tween
end

-- UnityEngine.Object 在 lua 侧是 userdata：Destroy 之后既不是 nil 也不能取字段
local function TabAlive(obj)
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
-- 🔴 漏复位 = 选项卡永久停在半截位置或半透明；重播 / OnClose / OnDestroy 都必须走这里。
function this.StopTabSlideIn()
    for i = #tabSlideItems, 1, -1 do
        local item = tabSlideItems[i]
        if TabAlive(item.posTween) then
            item.posTween:Kill(false)
        end
        if TabAlive(item.fadeTween) then
            item.fadeTween:Kill(false)
        end
        if TabAlive(item.rect) then
            item.rect.anchoredPosition = Vector2.New(item.x, item.y)
        end
        if TabAlive(item.graphic) then
            item.graphic.color = item.color
        end
        tabSlideItems[i] = nil
    end
end

-- 打开本页：13 个选项卡逐格从左侧滑入并淡入。
-- 页签由 TabBox.Init 一次性克隆（13 个固定，整局不重建）⇒ 每次 OnShow 重播都从起点起。
function this.PlayTabSlideIn()
    this.StopTabSlideIn()
    -- 🔴 不能用 this.TabCtrl:GetTabList()：InitComponent 第 84 行把 this.TabCtrl 换成了第二个
    -- 空实例（第二次 Init 传的 this.tabBoxData 是 nil，TabBox:Init 直接 return），那个实例的
    -- TabList 是类表上的空表 ⇒ GetTabList() 恒为空、动画静默不播。直接走 box 的子节点。
    local box = this.tabBox and Util.GetGameObject(this.tabBox, "box")
    if not TabAlive(box) then
        return 0
    end
    local boxTf = box.transform
    local total = boxTf.childCount or 0
    if total <= 0 then
        return 0
    end
    local step = kTabSlideStep
    if total > 1 and step * (total - 1) > kTabSlideMaxSpan then
        step = kTabSlideMaxSpan / (total - 1)
    end

    local order = 0
    local ok, err = pcall(function()
        for i = 0, total - 1 do
            local tabTf = boxTf:GetChild(i)
            if TabAlive(tabTf) and tabTf.gameObject.activeSelf then
                local tabGo = tabTf.gameObject
                local delay = order * step
                for j = 1, #kTabNodes do
                    local cfg = kTabNodes[j]
                    local go = Util.GetGameObject(tabGo, cfg.path)
                    -- 未激活的子节点（未选中的 select / HighText、无红点的 Redpot）不参与：
                    -- 它们被 SetActive 打开时本来就是终值，写它们只会让下一次打开从半截起
                    if TabAlive(go) and go.activeSelf then
                        local rect = go:GetComponent("RectTransform")
                        local graphic = go:GetComponent(cfg.comp)
                        if TabAlive(rect) and TabAlive(graphic) then
                            local pos = rect.anchoredPosition
                            local baseColor = graphic.color
                            -- 起点：屏幕左侧 kTabSlideFrom 之外
                            if cfg.axis == "y" then
                                rect.anchoredPosition = Vector2.New(pos.x, pos.y + kTabSlideFrom)
                            else
                                rect.anchoredPosition = Vector2.New(pos.x - kTabSlideFrom, pos.y)
                            end
                            graphic.color = WithAlpha(baseColor, kTabFadeFrom)

                            local posTween
                            if cfg.axis == "y" then
                                posTween = rect:DOAnchorPosY(pos.y, kTabSlideDuration)
                            else
                                posTween = rect:DOAnchorPosX(pos.x, kTabSlideDuration)
                            end
                            posTween:SetDelay(delay)
                            SetEaseSafe(posTween, "OutQuad")
                            posTween:OnComplete(function()
                                if TabAlive(rect) then
                                    rect.anchoredPosition = Vector2.New(pos.x, pos.y)
                                end
                            end)

                            local fadeTween = graphic:DOFade(baseColor.a, kTabSlideDuration)
                            fadeTween:SetDelay(delay)
                            SetEaseSafe(fadeTween, "OutQuad")
                            fadeTween:OnComplete(function()
                                if TabAlive(graphic) then
                                    graphic.color = baseColor
                                end
                            end)

                            tabSlideItems[#tabSlideItems + 1] = {
                                rect = rect, x = pos.x, y = pos.y,
                                graphic = graphic, color = baseColor,
                                posTween = posTween, fadeTween = fadeTween,
                            }
                        end
                    end
                end
                order = order + 1
            end
        end
    end)
    if not ok then
        -- DOTween 侧任何异常都不能把选项卡留在半截位置/半透明
        LogError("BattlePassPanel_Mission: 选项卡入场失败 " .. tostring(err))
        this.StopTabSlideIn()
        return 0
    end
    return order
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
    this.TabCtrl = TabBox.New()
    this.TabCtrl:SetTabAdapter(this.TabAdapter)
    this.TabCtrl:SetChangeTabCallBack(this.SwitchView)
    this.TabCtrl:Init(this.tabBox, this.tabBoxData, curIndex)

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

end
function this:OnSortingOrderChange(_sortingOrder)
    -- this.rewardPreview:GetComponent("Canvas").sortingOrder = sortingOrder + 30
    this.goals:GetComponent("Canvas").sortingOrder = sortingOrder + 30
end

function this:OnShow(panel,_sortingOrder)
    sortingOrder = _sortingOrder
    this.battlePanel = panel
    this.RefreshPassData()

    -- tabIndex = 1
    this.RefreshAllTaskBtn()
    this.TabCtrl:ChangeTab(tabIndex)

    -- 选项卡逐格滑入 + 淡入（页签只建一次、节点常驻 ⇒ 每次进本页重播）
    this.PlayTabSlideIn()

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
    this.SwitchView(tabIndex)
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
    this.StopTabSlideIn()
end

function this:OnDestroy()
    preview1 = nil
    preview2 = nil
    -- DestroyPanel 不走 OnClose，面板还会被 openedList 缓存复用 ⇒ 两处都要收
    this.StopTabSlideIn()
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