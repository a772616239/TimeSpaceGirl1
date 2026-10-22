-- 回归：装扮页（CourtesyDressPanel）的「数据刷新」链路不能把列表刷空。
--
-- 现象（用户报）：rect/ScrollCycleView/grid/item1/nextDayOpenBtn 点完，整个 grid 空了；
--   面板还在、页签也没了；再打开还是空。
--
-- 根因（本用例锁定）：ActivityGiftManager 有两处派发 GameEvent.Activity.GetRewardRefresh
--   ① GetActivityRewardRequest 带的是「刚领的那个页签」的列表；
--   ② FiveAMRefreshActivityProgress（服务器 0 点刷新推送 RefreshUpdateIndication）**完全不带参数**。
--   面板把事件参数直接转给 ScrollCycleView:SetData ⇒ 收到 ② 时是 SetData(nil) ⇒
--   dataCount = 0 ⇒ 池里每张卡 item.go:SetActive(false) ⇒ grid 空了。
--   全程不抛错（SetData 自己 `dataList or {}` 吃掉 nil），EventManager 又是 xpcall 静默吞异常，
--   所以日志里一条错误都没有。
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_courtesydress_refresh.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local PANEL_SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/ActivityGift/CourtesyDressPanel.lua"
local SV_SRC    = ROOT .. "Assets/ManagedResources/~Lua/View/ScrollCycleView.lua"

------------------------------------------------------------------
-- 数学类型
------------------------------------------------------------------
local V2 = {}
V2.__index = V2
local function Vec2(x, y) return setmetatable({ x = x or 0, y = y or 0 }, V2) end
V2.__add = function(a, b) return Vec2(a.x + b.x, a.y + b.y) end
V2.__sub = function(a, b) return Vec2(a.x - b.x, a.y - b.y) end
V2.__mul = function(a, b)
    if type(b) == "number" then return Vec2(a.x * b, a.y * b) end
    if type(a) == "number" then return Vec2(b.x * a, b.y * a) end
end
Vector2 = {
    New = Vec2,
    zero = Vec2(0, 0),
    Lerp = function(a, b, t) return Vec2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t) end,
}
local V3 = {}
V3.__index = V3
V3.__mul = function(a, b)
    if type(b) == "number" then return setmetatable({ x = a.x * b, y = a.y * b, z = a.z * b }, V3) end
    return a
end
local function Vec3(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V3) end
Vector3 = { New = Vec3, one = Vec3(1, 1, 1), zero = Vec3(0, 0, 0) }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Quaternion = { identity = {} }
Ease = { Linear = "Linear", OutQuad = "OutQuad" }
Mathf = { Abs = math.abs }
math.clamp = function(v, lo, hi) if v < lo then return lo elseif v > hi then return hi else return v end end
math.round = function(v) return math.floor(v + 0.5) end
table.reverse = function(list, i, j)
    i = i or 1
    j = j or #list
    while i < j do
        list[i], list[j] = list[j], list[i]
        i = i + 1
        j = j - 1
    end
end
table.nums = function(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
function typeof(x) return x end
IsNull = function() return false end
local logs = { error = {}, red = {} }
LogError = function(msg) logs.error[#logs.error + 1] = tostring(msg) end
Log = function(msg) end
LogRed = function(msg) logs.red[#logs.red + 1] = tostring(msg) end

------------------------------------------------------------------
-- 假 GameObject
------------------------------------------------------------------
local GO = {}
GO.__index = GO
local function NewGO(name, active)
    local o = setmetatable({
        name = name, activeSelf = active ~= false,
        children = {}, order = {}, childCount = 0, comps = {},
    }, GO)
    o.gameObject = o
    local t = setmetatable({}, { __index = o })
    t.localScale = Vec3(1, 1, 1)
    t.localPosition = Vec3(0, 0, 0)
    o.transform = t
    o.comps.Transform = t
    return o
end
function GO:AddChild(c)
    c.parent = self
    self.children[c.name] = c
    self.order[#self.order + 1] = c
    self.childCount = #self.order
    return c
end
function GO:Find(path)
    local cur = self
    for part in path:gmatch("[^/]+") do
        local nxt
        for _, c in ipairs(cur.order) do
            if c.name == part then nxt = c break end
        end
        if not nxt then return nil end
        cur = nxt
    end
    return cur
end
function GO:SetParent(p)
    if self.parent then
        local po = self.parent
        for i, c in ipairs(po.order) do
            if c == self then table.remove(po.order, i) break end
        end
        po.children[self.name] = nil
        po.childCount = #po.order
    end
    if p then p:AddChild(self) end
end
function GO:SetAsLastSibling() end
function GO:GetComponent(cls) return self.comps[cls] end
function GO:AddComponent(cls)
    local c = { __cls = cls }
    self.comps[cls] = c
    return c
end
function GO:SetActive(v) self.activeSelf = v and true or false end
local function Rect(name, w, h, active)
    local go = NewGO(name, active)
    local t = go.transform
    t.anchoredPosition = Vec2(0, 0)
    t.anchoredPosition3D = Vec3(0, 0, 0)
    t.sizeDelta = Vec2(w or 1080, h or 230)
    t.anchorMin = Vec2(0.5, 0.5)
    t.anchorMax = Vec2(0.5, 0.5)
    t.pivot = Vec2(0.5, 0.5)
    t.rect = { width = w or 1080, height = h or 230 }
    -- DOTween 的扩展方法挂在 RectTransform 上（tolua 侧就是方法调用），假对象补一个
    t.DOAnchorPosX = function(self, x, dur) return FakeTween(self, x, "posx") end
    go.comps.RectTransform = t
    return go
end
local function WithText(name, active)
    local go = Rect(name, 200, 40, active)
    go:AddComponent("Text")
    go.comps.Text = { text = "" }
    return go
end
local function WithImage(name, active)
    local go = Rect(name, 1080, 230, active)
    go:AddComponent("Image")
    go.comps.Image = { color = { r = 1, g = 1, b = 1, a = 1 }, sprite = nil }
    function go.comps.Image:DOFade(v, dur) return FakeTween(self, v, "fade") end
    return go
end

------------------------------------------------------------------
-- 假 tween
------------------------------------------------------------------
local tweens = {}
function FakeTween(target, endv, kind)
    local t = { target = target, endv = endv, kind = kind, delay = 0, killed = false }
    function t:SetDelay(d) self.delay = d return self end
    function t:SetEase() return self end
    function t:OnComplete(cb) self.onComplete = cb return self end
    function t:OnUpdate() return self end
    function t:Kill() self.killed = true return self end
    function t:Complete()
        if self.killed then return end
        if self.kind == "fade" then
            self.target.color = { r = 1, g = 1, b = 1, a = self.endv }
        elseif self.kind == "posx" then
            self.target.anchoredPosition = Vec2(self.endv, self.target.anchoredPosition.y)
        end
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

local Delegate = {}
Delegate.__add = function(a, b) return a end
local function NewDelegate()
    local d = setmetatable({}, Delegate)
    d.onBeginDrag = setmetatable({}, Delegate)
    d.onDrag = setmetatable({}, Delegate)
    d.onEndDrag = setmetatable({}, Delegate)
    return d
end

------------------------------------------------------------------
-- 全局桩
------------------------------------------------------------------
function Inherit(base) return setmetatable({}, { __index = base }) end
GetLanguageStrById = function(id) return "L" .. tostring(id) end
TimeToHMS = function(v) return tostring(v) end
GetTimeStamp = function() return 0 end
PlaySoundWithoutClick = function() end
SoundConfig = { Sound_UICancel = 1 }
BindRedPointObject = function() end
ClearRedPointObject = function() end
RedPointType = { CourtesyDress_Online = 1, CourtesyDress_SevenDay = 2, CourtesyDress_Chapter = 3 }
UIName = { CourtesyDressPanel = 1, FightPointPassMainPanel = 2 }
FIGHT_POINT_STATE = { PASS = 1 }
FightPointPassManager = { GetFightStateById = function() return 0 end }
Timer = { New = function() return { Start = function() end, Stop = function() end } end }
NetManager = { IsConnect = function() return true end }
UITweenSpring = "UITweenSpring"

-- 真 EventManager 语义：v.func(v.obj, ...)，并且 xpcall 静默吞异常（游戏里就是这样）
local listeners = {}
GameEvent = { Activity = { GetRewardRefresh = "Activity.GetRewardRefresh", OnlineState = "Activity.OnlineState" } }
Game = {
    GlobalEvent = {
        AddEvent = function(_, name, fn, obj)
            listeners[name] = listeners[name] or {}
            table.insert(listeners[name], { func = fn, obj = obj })
        end,
        RemoveEvent = function(_, name, fn, obj)
            local list = listeners[name]
            if not list then return end
            for i = 1, #list do
                if list[i].func == fn and list[i].obj == obj then table.remove(list, i) break end
            end
        end,
        DispatchEvent = function(_, name, ...)
            local list = listeners[name]
            if not list then return end
            local args = { ... }
            local n = table.maxn(args)
            for _, v in ipairs(list) do
                local ok, err = xpcall(function()
                    v.func(v.obj, unpack(args, 1, n))
                end, function(e) return e end)
                if not ok then logs.error[#logs.error + 1] = "DISPATCH-SWALLOWED: " .. tostring(err) end
            end
        end,
    },
}

local jumped = {}
JumpManager = {
    ShowGuide = function() end,
    GoJump = function(id) jumped[#jumped + 1] = id end,
}

Util = {
    GetGameObject = function(root, path)
        local base = (type(root) == "table" and root.transform) or root
        if base and base.Find then return base:Find(path) end
        return nil
    end,
    GetTransform = function(root, path)
        local base = (type(root) == "table" and root.transform) or root
        if base and base.Find then return base:Find(path) end
        return nil
    end,
    GetEventTriggerListener = function() return NewDelegate() end,
    AddClick = function() end,
    AddOnceClick = function(go, fn) if go then go.onceClick = fn end end,
    LoadSprite = function() return nil end,
    SetGray = function() end,
}

local function Clone(src)
    local isRect = src.comps.RectTransform ~= nil
    local go
    if isRect then
        local st = src.transform
        go = Rect(src.name, st.rect.width, st.rect.height, src.activeSelf)
        local dt = go.transform
        dt.anchoredPosition = Vec2(st.anchoredPosition.x, st.anchoredPosition.y)
        dt.sizeDelta = Vec2(st.sizeDelta.x, st.sizeDelta.y)
        dt.anchorMin = Vec2(st.anchorMin.x, st.anchorMin.y)
        dt.anchorMax = Vec2(st.anchorMax.x, st.anchorMax.y)
        dt.pivot = Vec2(st.pivot.x, st.pivot.y)
    else
        go = NewGO(src.name, src.activeSelf)
    end
    for k, v in pairs(src.comps) do
        if k ~= "Transform" and k ~= "RectTransform" then
            if type(v) == "table" then
                local c = {}
                for kk, vv in pairs(v) do c[kk] = vv end
                if c.color then c.color = { r = c.color.r, g = c.color.g, b = c.color.b, a = c.color.a } end
                go.comps[k] = c
            else
                go.comps[k] = v
            end
        end
    end
    for _, child in ipairs(src.order) do
        go:AddChild(Clone(child))
    end
    return go
end
newObject = Clone

local ScrollCycleView = assert(loadfile(SV_SRC))()

SubUIManager = {
    Open = function(config, parent, itemGO, scrollBar, sizeV2, dragType, fixedCount, spacingV2, itemGoScale, onUpdate, parentScroll)
        if config == "ScrollCycleView" then
            local go = Rect("ScrollCycleView", 1080, 990, true)
            local grid = Rect("grid", 1080, 0, true)
            grid.comps.RectTransform.anchorMin = Vec2(0.5, 1)
            grid.comps.RectTransform.anchorMax = Vec2(0.5, 1)
            grid.comps.RectTransform.pivot = Vec2(0.5, 1)
            go:AddChild(grid)
            parent:AddChild(go)
            local sv = ScrollCycleView:New(go)
            sv:InitComponent()
            sv:OnOpen(itemGO, scrollBar, sizeV2, dragType, fixedCount, spacingV2, itemGoScale, onUpdate, parentScroll)
            return sv
        end
        return {
            gameObject = NewGO("ItemView", true),
            OnOpen = function() end,
            SetEffectLayer = function() end,
        }
    end,
}
SubUIConfig = { ScrollCycleView = "ScrollCycleView", ItemView = "ItemView" }

ActivityTypeDef = { EightDayGift = 1, OnlineGift = 2, ChapterAward = 3 }

-- 章节礼包：15 条（未通关 ⇒ 显示 nextDayOpenBtn「前往」）
local function BuildChapterData(n)
    local list = {}
    for i = 1, n do
        list[i] = {
            Id = 5000 + i,
            ActivityId = 3,
            Sort = i,
            Values = { { 1000 + i } },
            Reward = { { 1001, 1 }, { 1002, 2 } },
            ContentsShow = "L" .. tostring(1000 + i),
            Jump = { 26082 },
        }
    end
    return list
end
local function BuildChapterState(n)
    local st = {}
    for i = 1, n do st[5000 + i] = 0 end
    return st
end

-- 在线礼包（另一页签的数据，用来模拟「领了在线奖励却派发给章节页」）
local onlineData = {}
for i = 1, 4 do
    onlineData[i] = {
        Id = 7000 + i, ActivityId = 1, Sort = i,
        Values = { { 5 * i } },
        Reward = { { 2001, 1 } },
        ContentsShow = "OL" .. tostring(i),
    }
end
local onlineState = {}
for i = 1, 4 do onlineState[7000 + i] = 0 end

ActivityGiftManager = {
    sevenDayGetRewardState = {}, onlineGetRewardState = onlineState,
    chapterGetRewardState = BuildChapterState(15),
    sevenDayData = {}, onlineData = onlineData, chapterGiftData = BuildChapterData(15),
    CheckOnlineRed = function() return false end,
    CheckSevenDayRed = function() return false end,
    CheckChapterRed = function() return true end,
    onlineOpen = false, sevenDayOpen = false, chapterOpen = true,
    canRewardDay = 0, currentTimeIndex = 0, cuOnLineTimestamp = 0,
}

local fakeModule = setmetatable({}, { __index = function() return function() end end })
function require(path) return fakeModule end

------------------------------------------------------------------
-- 面板 prefab 结构
------------------------------------------------------------------
local function BuildPanelGO()
    local root = Rect("CourtesyDressPanel", 1080, 1920, true)
    root:AddChild(NewGO("BackMask", true))
    root:AddChild(NewGO("btnBack", true))

    local down = NewGO("downLayout", true)
    local grid = NewGO("expertRewardGrid", true)
    grid:AddChild(WithText("remaindTimeText", true))
    down:AddChild(grid)
    root:AddChild(down)

    local item = Rect("item", 1080, 230, true)
    item:AddChild(WithImage("Image", true))
    local titleImage = Rect("titleImage", 400, 40, true)
    titleImage:AddChild(WithText("titleText", true))
    item:AddChild(titleImage)
    item:AddChild(Rect("content", 700, 150, true))
    item:AddChild(WithText("getRewardProgress", true))
    item:AddChild(WithImage("getRewardBtn", true))
    local nextBtn = WithImage("nextDayOpenBtn", true)
    nextBtn:AddComponent("Button")
    nextBtn.comps.Button = { onClick = { RemoveAllListeners = function() end, AddListener = function() end } }
    nextBtn:AddChild(WithText("Text", true))
    item:AddChild(nextBtn)
    item:AddChild(WithText("getFinishText", true))
    root:AddChild(item)

    local tabs = NewGO("tabsContent", true)
    for i = 1, 3 do
        local t = NewGO("tabs_" .. i, true)
        t:AddChild(NewGO("selected", false))
        t:AddChild(NewGO("redPoint", false))
        tabs:AddChild(t)
    end
    root:AddChild(tabs)

    root:AddChild(Rect("rect", 1080, 990, true))
    return root
end

local Panel = assert(loadfile(PANEL_SRC))()

local function Setup()
    listeners = {}
    local go = BuildPanelGO()
    Panel.gameObject = go
    Panel.transform = go.transform
    Panel.canvas = nil
    Panel.openNum = 0
    Panel.isOpened = false
    Panel:InitComponent()
    Panel:BindEvent()
end

local function OpenChapter()
    Panel:AddListener()
    Panel.isOpened = true
    Panel:OnOpen(ActivityTypeDef.ChapterAward, true)   -- InvadeMonsterView「通关奖励」入口
    Panel:OnShow()
end

local function Grid()
    return Panel.gameObject:Find("rect/ScrollCycleView/grid")
end

local function Cards()
    local g = Grid()
    local total, active, titles = 0, 0, {}
    if not g then return 0, 0, titles end
    for _, c in ipairs(g.order) do
        total = total + 1
        if c.activeSelf then
            active = active + 1
            local tt = c:Find("titleImage/titleText")
            titles[#titles + 1] = tt and tt.comps.Text.text or "?"
        end
    end
    return total, active, titles
end

local pass, fail = 0, 0
local function Check(name, cond, detail)
    if cond then
        pass = pass + 1
        print(("  [OK]   %s"):format(name))
    else
        fail = fail + 1
        print(("  [FAIL] %s   %s"):format(name, detail or ""))
    end
end

------------------------------------------------------------------
-- 用例
------------------------------------------------------------------
print("== 1. 首次打开（章节页签，hideBtns=true）==")
Setup()
OpenChapter()
local total, active, titles = Cards()
print(("  grid 子节点=%d 激活=%d 首卡标题=%s"):format(total, active, tostring(titles[1])))
Check("首次打开有卡", active > 0, "active=" .. active)

print("== 2. 点 item1 的 nextDayOpenBtn（前往跳转）==")
local item1 = Grid():Find("item1")
local nextBtn = item1 and item1:Find("nextDayOpenBtn")
Check("item1 有 nextDayOpenBtn 且绑了回调", nextBtn ~= nil and nextBtn.onceClick ~= nil)
if nextBtn and nextBtn.onceClick then nextBtn.onceClick(nextBtn) end
print("  GoJump 收到: " .. tostring(jumped[#jumped]))
Check("前往跳转透传 Jump[1]=26082", jumped[#jumped] == 26082, tostring(jumped[#jumped]))
local _, activeAfterClick = Cards()
Check("点完「前往」列表还在", activeAfterClick == active, ("点前=%d 点后=%d"):format(active, activeAfterClick))

print("== 3. 服务器 0 点刷新推送：DispatchEvent(GetRewardRefresh) 不带参数 ==")
-- 对应 ActivityGiftManager.FiveAMRefreshActivityProgress 末尾那行
Game.GlobalEvent:DispatchEvent(GameEvent.Activity.GetRewardRefresh)
local _, activeNoArg = Cards()
print(("  无参刷新后 激活=%d"):format(activeNoArg))
Check("无参刷新不能清空列表", activeNoArg == active, ("期望=%d 实际=%d"):format(active, activeNoArg))

print("== 4. 领了在线奖励，事件带的是 onlineData，但当前页签是章节 ==")
Game.GlobalEvent:DispatchEvent(GameEvent.Activity.GetRewardRefresh, ActivityGiftManager.onlineData)
local _, activeWrongTab, titlesWrongTab = Cards()
print(("  错页签刷新后 激活=%d 首卡标题=%s"):format(activeWrongTab, tostring(titlesWrongTab[1])))
Check("错页签刷新不能把章节列表换掉/清空",
    activeWrongTab == active and titlesWrongTab[1] == titles[1],
    ("激活=%d 首卡=%s"):format(activeWrongTab, tostring(titlesWrongTab[1])))

print("== 5. 领章节奖励（事件带 chapterGiftData）==")
-- 先确认监听器是活的：正常刷新必须真的走一次 SetData（否则 case3 的「没被清空」可能是假的）
local setDataCalls = 0
local realSetData = Panel.ScrollView.SetData
Panel.ScrollView.SetData = function(self, ...)
    setDataCalls = setDataCalls + 1
    return realSetData(self, ...)
end
Game.GlobalEvent:DispatchEvent(GameEvent.Activity.GetRewardRefresh, ActivityGiftManager.chapterGiftData)
Panel.ScrollView.SetData = realSetData
Check("正常刷新确实重建了列表", setDataCalls == 1, "SetData 调用次数=" .. setDataCalls)
local _, activeChapter = Cards()
Check("正常刷新后列表还在", activeChapter == active, ("激活=%d"):format(activeChapter))

print("== 5b. 静默刷新必须把「数据」传下去（定义用 . 但调用用 : 的回归）==")
-- 原来 RefreshActivityDataSilently 用 `function this.X(activityData, ...)` 定义，
-- 3 个调用点却都是 `this:X(...)` ⇒ activityData 收到的是面板表本身，真实数据被挤到 activityType，
-- SetData(面板表) ⇒ #面板表==0 ⇒ 池里所有卡 SetActive(false)。这条用例钉死这个坑。
local seenData, seenType
local realShow2 = Panel.OnShowActivityData
Panel.OnShowActivityData = function(self, d, t, s, c)
    seenData, seenType = d, t
    return realShow2(self, d, t, s, c)
end
Panel:RefreshActivityDataSilently(ActivityGiftManager.chapterGiftData, ActivityTypeDef.ChapterAward,
    ActivityGiftManager.chapterGetRewardState, 0)
Panel.OnShowActivityData = realShow2
Check("静默刷新第 1 个实参就是数据列表", seenData == ActivityGiftManager.chapterGiftData,
    "收到的是 " .. tostring(seenData))
Check("静默刷新第 2 个实参是活动类型", seenType == ActivityTypeDef.ChapterAward, tostring(seenType))
local _, activeSilent = Cards()
Check("静默刷新后列表还在", activeSilent == active, ("激活=%d"):format(activeSilent))

print("== 6. 章节数据暂时为空（配置未加载 / 活动未下发）==")
-- 注意：本入口 hideBtns=true，页签本来就是隐藏的。这里先人为点亮页签，
-- 专门验证「空状态表不会让 IsGetRewardAll 把它永久关掉」。
Panel.chapterRewardBtn:SetActive(true)
local backupData, backupState = ActivityGiftManager.chapterGiftData, ActivityGiftManager.chapterGetRewardState
ActivityGiftManager.chapterGiftData = {}
ActivityGiftManager.chapterGetRewardState = {}
Panel:OnShow()
local _, activeEmpty = Cards()
local tabVisible = Panel.chapterRewardBtn.activeSelf
print(("  空数据 OnShow 后 激活=%d 章节页签可见=%s"):format(activeEmpty, tostring(tabVisible)))
Check("空数据不能清空列表", activeEmpty == active, ("期望=%d 实际=%d"):format(active, activeEmpty))
Check("空数据不能把页签永久隐藏", tabVisible == true, "chapterRewardBtn 被 SetActive(false)")
Check("空数据不能把 chapterOpen 置 false", ActivityGiftManager.chapterOpen == true,
    tostring(ActivityGiftManager.chapterOpen))
ActivityGiftManager.chapterGiftData, ActivityGiftManager.chapterGetRewardState = backupData, backupState

print("== 6b. 状态表非空但全是 1（真的全领完了）⇒ 页签该隐藏 ==")
local allDone = {}
for i = 1, 15 do allDone[5000 + i] = 1 end
ActivityGiftManager.chapterGetRewardState = allDone
Panel:OnShow()
Check("全领完时页签隐藏", Panel.chapterRewardBtn.activeSelf == false)
Check("全领完时 chapterOpen=false", ActivityGiftManager.chapterOpen == false)
ActivityGiftManager.chapterGetRewardState = backupState
ActivityGiftManager.chapterOpen = true
Panel.chapterRewardBtn:SetActive(true)

print("== 7. 章节状态表有 nil（服务器只下发部分 missionId）==")
local partial = {}
partial[5001] = 0
partial[5002] = 1
ActivityGiftManager.chapterGetRewardState = partial
local okSort, sortErr = pcall(Panel.SetDataSort, Panel)
Check("排序函数不能被 nil 状态打挂", okSort, tostring(sortErr))
Panel:OnShow()
local _, activePartial = Cards()
Check("部分状态 OnShow 后列表还在", activePartial == active, ("激活=%d"):format(activePartial))

print("== 8. 再打开（UIManager 回退：CloseUI → SetActive → OpenUI(true) 只走 OnShow）==")
Panel:OnClose()
Panel.gameObject:SetActive(false)
Panel.gameObject:SetActive(true)
Panel:AddListener()
Panel.isOpened = true
Panel:OnShow()
local _, activeReopen = Cards()
Check("再次打开列表还在", activeReopen == active, ("激活=%d"):format(activeReopen))

print("== 9. 刷新链路不能抛错（EventManager 会静默吞掉，这里必须零错误）==")
local errCount = #logs.error
for i = 1, errCount do print("  ! " .. logs.error[i]) end
Check("全程没有吞掉的异常", errCount == 0, errCount .. " 条")

print(("== 结果：%d 通过 / %d 失败 =="):format(pass, fail))
if fail > 0 then os.exit(1) end
print("ALL OK")
