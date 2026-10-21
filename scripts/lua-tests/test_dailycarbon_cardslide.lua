-- 离线验证 DailyCarbonPanel 的**副本卡**入场动画（不依赖 Unity）：
-- 用假 Util / getComponent / DOTween / ScrollCycleView 跑真源码，覆盖
--   ① PlayCardSlideIn   卡的 6 个可视子节点一起从右侧 260px 向左滑回原位 + 底板 Bg 淡入 0.3647
--   ② 完成恢复          anchoredPosition 与 alpha 精确回到基准值（不是"差不多"）
--   ③ 中途 StopCardSlideIn Kill 后必须全复位（不能停在半截位置/半透明）
--   ④ 多卡错开          相邻卡 delay = 0.05
--   ⑤ 跳过未激活        未激活的卡 / 未激活的子节点（Tip|Consume|GoBtn）不参与
--   ⑥ 空数据 / 无列表   返回 0，不报错
--   ⑦ 生命周期          OnClose / OnDestroy 都要回收
--   ⑧ 抑制标记          suppressOpenAnim（战斗结算 / 扫荡 / 5 点刷新）时 SetScroll 不播
--
-- 用真源码的 SetScroll 验证 ⑧：curData 初始为空表 ⇒ 循环跳过，只剩 SetData + 播放判定。
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_dailycarbon_cardslide.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Carbon/DailyCarbonPanel.lua"

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
        else -- fade
            self.tf.color = { r = self.tf.color.r, g = self.tf.color.g,
                              b = self.tf.color.b, a = self.endv }
        end
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

local function newGraphic(cls, a)
    local g = { cls = cls, color = { r = 1, g = 1, b = 1, a = a or 1 } }
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
        self.transform.childCount = self.childCount
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

-- 复刻 prefab 里 Pre（882×275）的 6 个可视子节点，坐标取 prefab 实测值
local ADD = { Bg = { 0, 0 }, Title = { -150, 78 }, Reward = { -130, -42 },
              GoBtn = { 310, 0 }, Consume = { 829.02, -83.4 }, Tip = { 310, -70 } }
local CARD_NODES = { "Bg", "Title", "Reward", "GoBtn", "Consume", "Tip" }

local function buildCard(index, active, hideNodes)
    local card = newRect("item" .. (index or 1), active)
    for _, name in ipairs(CARD_NODES) do
        local hide = hideNodes and hideNodes[name]
        local n = card:AddChild(newRect(name, not hide))
        n.anchoredPosition = { x = ADD[name][1], y = ADD[name][2] }
        if name == "Bg" then n.graphics.Image = newGraphic("Image", 1) end
    end
    return card
end

local function newListView(items)
    local sv = { items = items }
    function sv:ForeachItemGO(fn)
        for i, go in ipairs(self.items) do fn(i, go) end
    end
    function sv:SetData() end
    return sv
end

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = { Linear = "Linear", OutQuad = "OutQuad", InOutQuad = "InOutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
function Inherit(base) return setmetatable({}, { __index = base }) end
newObjToParent = function(tpl, parent) parent:AddChild(tpl); return tpl end

Util = {
    GetGameObject = function(root, path)
        local base = (type(root) == "table" and root.transform) or root
        if base and base.Find then return base:Find(path) end
        return nil
    end,
    ClearChild = function(t) t.order = {}; t.children = {}; t.childCount = 0 end,
    AddClick = function() end,
    AddOnceClick = function() end,
    LoadSprite = function() return nil end,
    SetGray = function() end,
}

-- 配置表按需返回带缺省字段的行，避免 specialConfig[41].Value 在 load 阶段就炸
local function configRow()
    return setmetatable({}, { __index = function() return 0 end })
end
ConfigManager = {
    GetConfig = function() return setmetatable({}, { __index = function() return configRow() end }) end,
    GetConfigData = function() return configRow() end,
    GetAllConfigsDataByKey = function() return {} end,
    GetConfigDataByKey = function() return configRow() end,
    GetConfigDataByDoubleKey = function() return configRow() end,
}
ConfigName = { DailyChallengeConfig = 1, MainLevelConfig = 2, ItemConfig = 3,
               SpecialConfig = 4, StoreConfig = 5 }
FUNCTION_OPEN_TYPE = setmetatable({}, { __index = function() return 0 end })
GetLanguageStrById = function() return "" end
SubUIManager = { Open = function() return { SetData = function() end } end,
                 Close = function() end }
SubUIConfig = { ScrollCycleView = 1, PlayerHeadFrameView = 2, UpView = 3 }
Game = { GlobalEvent = { AddEvent = function() end, RemoveEvent = function() end } }
GameEvent = { FiveAMRefresh = { ServerNotifyRefresh = 1 } }
CarbonManager = { GetDailyCarbons = function() return {} end, IsDailyCarbonPass = function() return false end }
SoundManager = { PlayMusic = function() end }
SoundConfig = { Sound_UICancel = 1, BGM_Carbon = 2 }
CheckRedPointStatus = function() end
RedPointType = { HeroExplore = 1 }
PopupTipPanel = { ShowTip = function() end, ShowTipByLanguageId = function() end }
UpViewOpenType = { ShowRight = 1 }
PanelType = { Main = 1 }

local fakeModule = setmetatable({}, { __index = function() return function() end end })
function require(path) return fakeModule end

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()
Panel.scrollView = nil

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
        local b = ADD[name]
        assert(ns[name].anchoredPosition.x == b[1] and ns[name].anchoredPosition.y == b[2],
               ("%s: %s 应回到 (%s,%s)，实际 (%.2f,%.2f)"):format(tag, name, b[1], b[2],
                   ns[name].anchoredPosition.x, ns[name].anchoredPosition.y))
    end
    assert(ns.Bg.graphics.Image.color.a == 1, tag .. ": Bg alpha 应回 1")
end

-- ---------------- case 1: 单卡滑入 + 底板淡入 ----------------
print("== case1 PlayCardSlideIn（单卡）==")
tweens = {}
local card1 = buildCard(1, true)
Panel.scrollView = newListView({ card1 })

local played = Panel.PlayCardSlideIn()
assert(played == 1, "应播 1 张卡，实际 " .. tostring(played))
-- 6 个子节点各 1 条位移 + Bg 1 条淡入 = 7
assert(#tweens == 7, "tween 条数应为 7，实际 " .. #tweens)
local ns = nodesOf(card1)
for _, name in ipairs(CARD_NODES) do
    local b = ADD[name]
    assert(ns[name].anchoredPosition.x == b[1] + 260,
           ("%s 起点应为 x+260 = %s，实际 %.1f"):format(name, b[1] + 260, ns[name].anchoredPosition.x))
    assert(ns[name].anchoredPosition.y == b[2], name .. " 的 y 不该被动")
end
assert(math.abs(ns.Bg.graphics.Image.color.a - 0.3647) < 1e-6,
       "底板淡入起点应为参考的 0.3647")
assert(card1.anchoredPosition.x == 0, "卡根节点不能被动（ScrollCycleView 每次重写它）")
for _, t in ipairs(tweens) do
    assert(t.dur == 0.22, "单卡时长应为 0.22")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
    assert(t.delay == 0, "单卡不该有延迟")
end
print("  6 节点 x+260（右侧起）+ Bg 0.3647，共 7 条 tween")

-- ---------------- case 2: 完成恢复 ----------------
print("== case2 完成后精确回基准值 ==")
for _, t in ipairs(tweens) do t:Complete() end
assertBase(card1, "完成后")
print("  位置/颜色全复位")

-- ---------------- case 3: 中途 Stop ----------------
print("== case3 中途 Stop 全复位 ==")
tweens = {}
Panel.PlayCardSlideIn()
assert(ns.Title.anchoredPosition.x == 110, "重播应从起点起（-150 + 260 = 110）")
Panel.StopCardSlideIn()
assert(liveTweens() == 0, "Stop 后不该有存活 tween，实际 " .. liveTweens())
assertBase(card1, "Stop 后")
print("  Kill + 位置/颜色全复位")

-- ---------------- case 4: 多卡错开 ----------------
print("== case4 多卡错开 0.05 ==")
tweens = {}
local card2 = buildCard(2, true)
local card3 = buildCard(3, true)
Panel.scrollView = newListView({ card1, card2, card3 })
played = Panel.PlayCardSlideIn()
assert(played == 3, "应播 3 张卡，实际 " .. played)
assert(#tweens == 21, "3 卡 × 7 = 21 条，实际 " .. #tweens)
local function delayOf(card, node)
    for _, t in ipairs(tweens) do
        if t.tf == card.children[node] then return t.delay end
    end
end
assert(delayOf(card2, "Bg") == 0.05, "第 2 张延迟应为 0.05，实际 " .. tostring(delayOf(card2, "Bg")))
assert(delayOf(card3, "Bg") == 0.10, "第 3 张延迟应为 0.10，实际 " .. tostring(delayOf(card3, "Bg")))
print("  3 卡 × 7 条，延迟 0 / 0.05 / 0.10")
Panel.StopCardSlideIn()
assertBase(card2, "多卡 Stop 后 card2")
assertBase(card3, "多卡 Stop 后 card3")

-- ---------------- case 5: 跳过未激活 ----------------
print("== case5 未激活的卡 / 子节点不参与 ==")
tweens = {}
local hidden = buildCard(4, false)
local partly = buildCard(5, true, { Tip = true, Consume = true })  -- 已通关卡：无 Tip、无 Consume
Panel.scrollView = newListView({ card1, hidden, partly })
played = Panel.PlayCardSlideIn()
assert(played == 2, "只应播 2 张（隐藏的被跳过），实际 " .. played)
-- card1: 7 条；partly: 4 个激活节点位移 + Bg 淡入 = 5 条
assert(#tweens == 12, "tween 条数应为 12，实际 " .. #tweens)
assert(hidden.children.Bg.anchoredPosition.x == 0, "隐藏卡不该被动")
assert(partly.children.Tip.anchoredPosition.x == 310, "未激活的 Tip 不该被动")
assert(partly.children.Consume.anchoredPosition.x == 829.02, "未激活的 Consume 不该被动")
print("  隐藏卡整体跳过；未激活子节点单独跳过（7 + 5 = 12）")
Panel.StopCardSlideIn()

-- ---------------- case 6: 空数据 / 无列表 ----------------
print("== case6 空数据不报错 ==")
Panel.scrollView = newListView({})
assert(Panel.PlayCardSlideIn() == 0, "空列表应返回 0")
Panel.scrollView = nil
assert(Panel.PlayCardSlideIn() == 0, "无列表应返回 0")
Panel.scrollView = newListView({ card1 })
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
Panel.scrollView = newListView({ card1 })
print("  两处都回收")

-- ---------------- case 8: 数据刷新不播 ----------------
print("== case8 suppressOpenAnim 时 SetScroll 不播 ==")
tweens = {}
Panel.SetScroll()
assert(#tweens == 7, "正常 SetScroll 应起 7 条，实际 " .. #tweens)
Panel.StopCardSlideIn()
Panel.suppressOpenAnim = true
Panel.SetScroll()
assert(liveTweens() == 0, "抑制时不该有存活 tween，实际 " .. liveTweens())
assertBase(card1, "抑制后")
Panel.suppressOpenAnim = false
tweens = {}
Panel.SetScroll()
assert(#tweens == 7, "放开后应起 7 条，实际 " .. #tweens)
print("  抑制时 0 条且已复位，放开后 7 条")
Panel.StopCardSlideIn()

print("ALL OK")
