-- 离线验证 CourtesyDressPanel 的**奖励卡**入场动画（不依赖 Unity）：
-- 用假 Util / GetComponent / DOTween / ScrollCycleView 跑真源码，覆盖
--   ① PlayCardSlideIn   卡的可见子节点一起从右侧滑回原位 + 满幅底板 Image 淡入 0.3647
--                       （打开：+260 / 0.26s / 错开 0.055；切页签：+170 / 0.30s / 错开 0.05 + 整批晚 0.05）
--   ② 完成恢复          anchoredPosition 与 alpha 精确回到基准值（不是"差不多"）
--   ③ 中途 StopCardSlideIn Kill 后必须全复位（不能停在半截位置/半透明）
--   ④ 多卡错开          相邻卡 delay = 步长
--   ⑤ 跳过未激活        未激活的卡 / 三态互斥的按钮（getRewardProgress|getRewardBtn|nextDayOpenBtn|getFinishText）
--   ⑥ 空数据 / 无列表   返回 0，不报错
--   ⑦ 生命周期          OnClose / OnDestroy 都要回收
--   ⑧ 抑制标记          RefreshActivityDataSilently 期间不播，且异常也要复位标记
--   ⑨ 真实入口          OnShowActivityData 末尾确实会播（不是只在 harness 里调 Play）
--   ⑩ 打开 vs 切页签    OnShow 置 false，3 个页签按钮置 true
--   ⑪ 连点保护          上一轮没播完时只复位、不重播；Stop / 播完之后能再触发
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_courtesydress_cardslide.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/ActivityGift/CourtesyDressPanel.lua"

-- ---------------- stubs ----------------
local tweens = {}

local function newTween(tf, endv, dur, kind)
    local t = { tf = tf, endv = endv, dur = dur, kind = kind,
                delay = 0, ease = nil, onComplete = nil, killed = false }
    function t:SetDelay(d) self.delay = d; return self end
    function t:SetEase(e) self.ease = e; return self end
    function t:OnComplete(cb) self.onComplete = cb; return self end
    function t:Kill() self.killed = true end
    function t:Complete()
        if self.killed then return end
        if self.kind == "posx" then
            self.tf.anchoredPosition = { x = self.endv, y = self.tf.anchoredPosition.y }
        else
            self.tf.color = { r = self.tf.color.r, g = self.tf.color.g,
                              b = self.tf.color.b, a = self.endv }
        end
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

local function newGraphic(a)
    local g = { color = { r = 1, g = 1, b = 1, a = a or 1 } }
    function g:DOFade(v, dur) return newTween(self, v, dur, "fade") end
    return g
end

local function newRect(name, active)
    local o = { name = name, activeSelf = active ~= false, childCount = 0,
                anchoredPosition = { x = 0, y = 0 }, graphics = {} }
    o.children, o.order = {}, {}
    o.transform = o
    o.gameObject = o
    function o:GetComponent(cls)
        if cls == "RectTransform" then return self end
        return self.graphics[cls]
    end
    function o:SetActive(v) self.activeSelf = v and true or false end
    function o:DOAnchorPosX(v, dur) return newTween(self, v, dur, "posx") end
    function o:AddChild(c)
        self.children[c.name] = c
        self.order[#self.order + 1] = c
        self.childCount = #self.order
        return c
    end
    function o:Find(path)
        local cur = self
        for name in path:gmatch("[^/]+") do
            cur = cur.children and cur.children[name]
            if not cur then return nil end
        end
        return cur
    end
    return o
end

-- 复刻 prefab 里 item（1080×230）的可视子节点，坐标取 prefab 实测值
local POS = { Image = { 0, 0 }, titleImage = { 40, 75 }, content = { -170, -15 },
              getRewardProgress = { -40, 70 }, getRewardBtn = { -25, 0 },
              nextDayOpenBtn = { -25, 0 }, getFinishText = { -75, 0 } }
local CARD_NODES = { "Image", "titleImage", "content", "getRewardProgress",
                     "getRewardBtn", "nextDayOpenBtn", "getFinishText" }
-- prefab 里 getRewardProgress / nextDayOpenBtn / getFinishText 是 INACTIVE，getRewardBtn 激活（可领态）
local DEFAULT_HIDDEN = { getRewardProgress = true, nextDayOpenBtn = true, getFinishText = true }

local function buildCard(index, active, hidden)
    hidden = hidden or DEFAULT_HIDDEN
    local card = newRect("item" .. (index or 1), active)
    for _, name in ipairs(CARD_NODES) do
        local n = card:AddChild(newRect(name, not hidden[name]))
        n.anchoredPosition = { x = POS[name][1], y = POS[name][2] }
        if name == "Image" then n.graphics.Image = newGraphic(1) end   -- 满幅底板
    end
    return card
end

local function activeNodeCount(card)
    local n = 0
    for _, name in ipairs(CARD_NODES) do
        if card.children[name].activeSelf then n = n + 1 end
    end
    return n
end

local function newListView(items)
    local sv = { items = items }
    function sv:ForeachItemGO(fn)
        for i, go in ipairs(self.items) do fn(i, go) end
    end
    function sv:SetData() end
    function sv:SetIndex() end
    return sv
end

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = { Linear = "Linear", OutQuad = "OutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
function Inherit(base) return setmetatable({}, { __index = base }) end
table.nums = function(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
GetLanguageStrById = function(id) return "L" .. tostring(id) end
TimeToHMS = function(v) return tostring(v) end
GetTimeStamp = function() return 0 end
PlaySoundWithoutClick = function() end
SoundConfig = { Sound_UICancel = 1 }
BindRedPointObject = function() end
ClearRedPointObject = function() end
RedPointType = { CourtesyDress_Online = 1, CourtesyDress_SevenDay = 2, CourtesyDress_Chapter = 3 }
UIName = { CourtesyDressPanel = 1 }
JumpManager = { ShowGuide = function() end, GoJump = function() end }
FIGHT_POINT_STATE = { PASS = 1 }
FightPointPassManager = { GetFightStateById = function() return 0 end }
Timer = { New = function() return { Start = function() end, Stop = function() end } end }
NetManager = { IsConnect = function() return true end }

local clicks = {}
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
    AddClick = function(go, fn) clicks[#clicks + 1] = { go = go, fn = fn } end,
    AddOnceClick = function() end,
    LoadSprite = function() return nil end,
}
SubUIManager = { Open = function() return { OnOpen = function() end, gameObject = newRect("sub") } end }
SubUIConfig = { ScrollCycleView = 1, ItemView = 2 }
ActivityTypeDef = { EightDayGift = 1, OnlineGift = 2, ChapterAward = 3 }
ActivityGiftManager = {
    sevenDayGetRewardState = {}, onlineGetRewardState = {}, chapterGetRewardState = {},
    sevenDayData = {}, onlineData = {}, chapterGiftData = {},
    CheckOnlineRed = function() return false end, CheckSevenDayRed = function() return false end,
    CheckChapterRed = function() return false end,
    onlineOpen = false, sevenDayOpen = false, chapterOpen = false,
    canRewardDay = 0, currentTimeIndex = 0, cuOnLineTimestamp = 0,
}
Game = { GlobalEvent = { AddEvent = function() end, RemoveEvent = function() end } }
GameEvent = { Activity = { GetRewardRefresh = 1 }, CloseUI = { OnClose = 2 } }

local fakeModule = setmetatable({}, { __index = function() return function() end end })
function require(path) return fakeModule end

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()
Panel.ScrollView = nil
Panel.viewCache = {}

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

local function nodesOf(card)
    local out = {}
    for _, name in ipairs(CARD_NODES) do out[name] = Util.GetGameObject(card, name) end
    return out
end

local function assertBase(card, tag)
    local ns = nodesOf(card)
    for _, name in ipairs(CARD_NODES) do
        local b = POS[name]
        assert(ns[name].anchoredPosition.x == b[1] and ns[name].anchoredPosition.y == b[2],
               ("%s: %s 应回到 (%s,%s)，实际 (%.2f,%.2f)"):format(tag, name, b[1], b[2],
                   ns[name].anchoredPosition.x, ns[name].anchoredPosition.y))
    end
    assert(card.children.Image.graphics.Image.color.a == 1, tag .. ": 满幅底板 alpha 应回 1")
end

-- ---------------- case 1: 单卡滑入 + 底板淡入 ----------------
print("== case1 PlayCardSlideIn（单卡 / 打开节奏）==")
tweens = {}
local card1 = buildCard(1, true)
Panel.ScrollView = newListView({ card1 })

local played = Panel.PlayCardSlideIn()
assert(played == 1, "应播 1 张卡，实际 " .. tostring(played))
local per = activeNodeCount(card1) + 1
assert(#tweens == per, ("tween 条数应为 %d，实际 %d"):format(per, #tweens))
local ns = nodesOf(card1)
for _, name in ipairs(CARD_NODES) do
    local b = POS[name]
    if card1.children[name].activeSelf then
        assert(ns[name].anchoredPosition.x == b[1] + 260,
               ("%s 起点应为 x+260 = %s，实际 %.2f"):format(name, b[1] + 260, ns[name].anchoredPosition.x))
        assert(ns[name].anchoredPosition.y == b[2], name .. " 的 y 不该被动")
    else
        assert(ns[name].anchoredPosition.x == b[1], name .. " 未激活，不该被动")
    end
end
assert(math.abs(card1.children.Image.graphics.Image.color.a - 0.3647) < 1e-6,
       "满幅底板淡入起点应为参考的 0.3647")
assert(card1.anchoredPosition.x == 0, "卡根节点不能被动（ScrollCycleView 每次重写它）")
for _, t in ipairs(tweens) do
    assert(t.dur == 0.26, "打开的单卡时长应为 0.26")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
    assert(t.delay == 0, "单卡不该有延迟")
end
print(("  %d 个可见节点 x+260（右侧起）+ 底板 0.3647，共 %d 条 tween")
    :format(activeNodeCount(card1), #tweens))

-- ---------------- case 2: 完成恢复 ----------------
print("== case2 完成后精确回基准值 ==")
for _, t in ipairs(tweens) do t:Complete() end
assertBase(card1, "完成后")
print("  位置/颜色全复位")

-- ---------------- case 3: 中途 Stop ----------------
print("== case3 中途 Stop 全复位 ==")
tweens = {}
Panel.PlayCardSlideIn()
assert(ns.titleImage.anchoredPosition.x == POS.titleImage[1] + 260, "重播应从起点起")
Panel.StopCardSlideIn()
assert(liveTweens() == 0, "Stop 后不该有存活 tween，实际 " .. liveTweens())
assertBase(card1, "Stop 后")
print("  Kill + 位置/颜色全复位")

-- ---------------- case 4: 多卡错开 ----------------
print("== case4 多卡错开 0.055 ==")
tweens = {}
local card2 = buildCard(2, true)
local card3 = buildCard(3, true)
Panel.ScrollView = newListView({ card1, card2, card3 })
played = Panel.PlayCardSlideIn()
assert(played == 3, "应播 3 张卡，实际 " .. played)
assert(#tweens == per * 3, ("3 卡 × %d = %d 条，实际 %d"):format(per, per * 3, #tweens))
local function delayOf(card, node)
    for _, t in ipairs(tweens) do
        if t.tf == card.children[node] then return t.delay end
    end
end
assert(math.abs(delayOf(card2, "content") - 0.055) < 1e-6,
       "第 2 张延迟应为 0.055，实际 " .. tostring(delayOf(card2, "content")))
assert(math.abs(delayOf(card3, "content") - 0.11) < 1e-6,
       "第 3 张延迟应为 0.11，实际 " .. tostring(delayOf(card3, "content")))
print("  3 卡，延迟 0 / 0.055 / 0.11")
Panel.StopCardSlideIn()
assertBase(card2, "多卡 Stop 后 card2")
assertBase(card3, "多卡 Stop 后 card3")

-- ---------------- case 5: 跳过未激活 ----------------
print("== case5 未激活的卡 / 互斥按钮不参与 ==")
tweens = {}
local hidden = buildCard(4, false)
-- 未开启态：getRewardBtn 关闭，只有 nextDayOpenBtn 激活
local notOpen = buildCard(5, true, { getRewardBtn = true, getRewardProgress = true, getFinishText = true })
Panel.ScrollView = newListView({ card1, hidden, notOpen })
played = Panel.PlayCardSlideIn()
assert(played == 2, "只应播 2 张（隐藏的被跳过），实际 " .. played)
local expect5 = (activeNodeCount(card1) + 1) + (activeNodeCount(notOpen) + 1)
assert(#tweens == expect5, ("tween 条数应为 %d，实际 %d"):format(expect5, #tweens))
assert(hidden.children.content.anchoredPosition.x == POS.content[1], "隐藏卡不该被动")
assert(notOpen.children.getRewardBtn.anchoredPosition.x == POS.getRewardBtn[1], "未激活的 getRewardBtn 不该被动")
assert(notOpen.children.nextDayOpenBtn.anchoredPosition.x == POS.nextDayOpenBtn[1] + 260, "激活的 nextDayOpenBtn 应参与")
print("  隐藏卡整体跳过；未激活按钮单独跳过")

-- ---------------- case 6: 空数据 / 无列表 ----------------
print("== case6 空数据不报错 ==")
Panel.ScrollView = newListView({})
assert(Panel.PlayCardSlideIn() == 0, "空列表应返回 0")
Panel.ScrollView = nil
assert(Panel.PlayCardSlideIn() == 0, "无列表应返回 0")
Panel.ScrollView = newListView({ card1 })
print("  返回 0，不报错")

-- ---------------- case 7: 生命周期回收 ----------------
print("== case7 OnClose / OnDestroy 回收 ==")
tweens = {}
Panel.PlayCardSlideIn()
Panel:OnClose()
assert(liveTweens() == 0, "OnClose 后不该有存活 tween")
assertBase(card1, "OnClose 后")
tweens = {}
Panel.PlayCardSlideIn()
Panel:OnDestroy()
assert(liveTweens() == 0, "OnDestroy 后不该有存活 tween")
assertBase(card1, "OnDestroy 后")
Panel.ScrollView = newListView({ card1 })
print("  两处都回收")

-- ---------------- case 8: 数据刷新不播（含异常也要复位标记） ----------------
print("== case8 RefreshActivityDataSilently 不播且异常也复位标记 ==")
local realShowData = Panel.OnShowActivityData
Panel.OnShowActivityData = function() end
tweens = {}
Panel:RefreshActivityDataSilently({}, ActivityTypeDef.ChapterAward, {}, nil)
assert(#tweens == 0, "静默刷新不该起 tween，实际 " .. #tweens)
assert(Panel.suppressCardAnim == false, "静默刷新后标记必须复位")
Panel.OnShowActivityData = function() error("boom") end
Panel:RefreshActivityDataSilently({}, ActivityTypeDef.ChapterAward, {}, nil)
assert(Panel.suppressCardAnim == false, "抛错后标记也必须复位")
Panel.OnShowActivityData = realShowData
print("  0 条 tween；正常/抛错两条路径标记都复位")

-- ---------------- case 9: 真实入口（OnShowActivityData 末尾会播） ----------------
print("== case9 OnShowActivityData 末尾确实会播 ==")
tweens = {}
Panel.ScrollView = newListView({ card1 })
Panel.nextPlayIsSwitch = false
Panel:OnShowActivityData({}, ActivityTypeDef.ChapterAward, {}, nil)
assert(#tweens == per, ("真实入口应起 %d 条 tween，实际 %d"):format(per, #tweens))
Panel.suppressCardAnim = true
Panel:OnShowActivityData({}, ActivityTypeDef.ChapterAward, {}, nil)
assert(liveTweens() == 0, "抑制期间真实入口也不该起 tween")
Panel.suppressCardAnim = false
print(("  真实入口 %d 条；抑制时 0 条"):format(per))

-- ---------------- case 10: 打开 vs 切页签（按钮真实接线） ----------------
print("== case10 OnShow 置「打开」，3 个页签按钮置「切页签」==")
Panel.IsGetRewardAll = function() end
Panel.SetDataSort = function() end
Panel.OpenActivityPage = function() end
Panel.JumpOpenActivity = function() end
Panel.ScrollView = newListView({ card1 })
Panel.ActivityId = nil
Panel:OnShow()
assert(Panel.nextPlayIsSwitch == false, "OnShow 应置「打开」(false)")

-- BindEvent 里 AddClick 的顺序：btnBack / BackMask / onlineBtn / sevenDayBtn / chapterRewardBtn
local called = 0
Panel.OnShowActivityData = function() called = called + 1 end
local function fakeGo(name) return newRect(name, true) end
Panel.btnBack, Panel.BackMask = fakeGo("btnBack"), fakeGo("BackMask")
Panel.onlineBtn, Panel.sevenDayBtn, Panel.chapterRewardBtn = fakeGo("onlineBtn"), fakeGo("sevenDayBtn"), fakeGo("chapterRewardBtn")
Panel.selected1, Panel.selected2, Panel.selected3 = fakeGo("s1"), fakeGo("s2"), fakeGo("s3")
Panel.onlineRedPoint, Panel.sevenDayPoint, Panel.chapterPoint = fakeGo("rp1"), fakeGo("rp2"), fakeGo("rp3")
clicks = {}
Panel:BindEvent()
assert(#clicks == 5, "BindEvent 应注册 5 个点击，实际 " .. #clicks)
for i = 3, 5 do
    Panel.nextPlayIsSwitch = false
    clicks[i].fn()
    assert(Panel.nextPlayIsSwitch == true, "第 " .. i .. " 个按钮（页签）应置「切页签」(true)")
end
assert(called == 3, "3 个页签都应刷新一次数据，实际 " .. called)
print("  OnShow=false；3 个页签按钮都置 true 并刷新数据")

-- ---------------- case 11: 切页签节奏 ----------------
print("== case11 切页签节奏（x+170 / 0.30s / 错开 0.05 / 整批晚 0.05）==")
tweens = {}
Panel.ScrollView = newListView({ card1, card2 })
played = Panel.PlayCardSlideIn(true)
assert(played == 2, "应播 2 张，实际 " .. played)
local ns11 = nodesOf(card1)
for _, name in ipairs(CARD_NODES) do
    if card1.children[name].activeSelf then
        local b = POS[name]
        assert(ns11[name].anchoredPosition.x == b[1] + 170,
               ("%s 切页签起点应为 x+170 = %s，实际 %.2f"):format(name, b[1] + 170, ns11[name].anchoredPosition.x))
    end
end
for _, t in ipairs(tweens) do
    assert(t.dur == 0.30, "切页签单卡时长应为 0.30，实际 " .. tostring(t.dur))
end
assert(math.abs(delayOf(card1, "content") - 0.05) < 1e-6, "首卡应晚 0.05 起播")
assert(math.abs(delayOf(card2, "content") - 0.10) < 1e-6, "次卡应为 0.05 + 0.05")
print("  x+170 / 0.30s / 延迟 0.05 与 0.10")

-- ---------------- case 12: 连点不叠播 ----------------
print("== case12 连点不叠播 ==")
local before = #tweens
assert(Panel.PlayCardSlideIn(true) == 0, "上一轮没播完时不该重播")
assert(#tweens == before, "不该新建 tween，实际新增 " .. (#tweens - before))
assertBase(card1, "连点中断后")
print("  返回 0，直接复位到终值，0 条新 tween")

-- ---------------- case 13: Stop / 自然播完后能再触发 ----------------
print("== case13 之后还能再触发 ==")
tweens = {}
assert(Panel.PlayCardSlideIn(true) == 2, "Stop 之后应能重新播")
for _, t in ipairs(tweens) do t:Complete() end
tweens = {}
assert(Panel.PlayCardSlideIn(true) == 2, "自然播完之后应能重新播")
assert(#tweens == per * 2, "应新建满额 tween")
print("  Stop 后 / 自然播完后都能重播")
Panel.StopCardSlideIn()

print("ALL OK")
