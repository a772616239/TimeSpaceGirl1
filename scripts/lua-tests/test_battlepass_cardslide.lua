-- 离线验证 BattlePassPanel_Mission 的**任务卡**入场动画（不依赖 Unity）：
-- 用假 Util / getComponent / DOTween / ScrollCycleView 跑真源码，覆盖
--   ① PlayTaskSlideIn   卡的 6 个可视子节点一起从右侧 260px 向左滑回原位 + 底板 bg 淡入 0.3647
--   ② 完成恢复          anchoredPosition 与 alpha 精确回到基准值（不是"差不多"）
--   ③ 中途 StopTaskSlideIn Kill 后必须全复位（不能停在半截位置/半透明）
--   ④ 多卡错开          相邻卡 delay = 0.05
--   ⑤ 跳过未激活        未激活的卡不参与（item 池复用，隐藏项不能白占一轮）
--   ⑥ 空数据 / 无列表   返回 0，不报错
--   ⑦ 生命周期          OnClose / OnDestroy 都要回收
--   ⑧ 抑制标记          RefreshAllTaskBtn 触发的重建（suppressTaskAnim）不播
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_battlepass_cardslide.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/BattlePass/BattlePassPanel_Mission.lua"

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

-- 复刻 prefab 里的任务卡 itempre（870×200）：bg / title / reward / mission / Slider / receiveOrGo
local function buildCard(index, active)
    local card = newRect("item" .. (index or 1), active)
    local bg = card:AddChild(newRect("bg", true))
    bg.graphics.Image = newGraphic("Image", 1)
    bg.anchoredPosition = { x = 0, y = 0 }

    local title = card:AddChild(newRect("title", true))
    title.graphics.Image = newGraphic("Image", 1)
    title.anchoredPosition = { x = -80, y = 40 }

    local reward = card:AddChild(newRect("reward", true))
    reward.anchoredPosition = { x = -365, y = 15 }

    local mission = card:AddChild(newRect("mission", true))
    mission.graphics.Text = newGraphic("Text", 1)
    mission.anchoredPosition = { x = 145, y = -30 }

    local slider = card:AddChild(newRect("Slider", true))
    slider.anchoredPosition = { x = -80, y = 45 }

    local rog = card:AddChild(newRect("receiveOrGo", true))
    rog.anchoredPosition = { x = 325, y = 0 }
    return card
end

local CARD_NODES = { "bg", "title", "reward", "mission", "Slider", "receiveOrGo" }
local BASE = {
    bg = { 0, 0 }, title = { -80, 40 }, reward = { -365, 15 },
    mission = { 145, -30 }, Slider = { -80, 45 }, receiveOrGo = { 325, 0 },
}

-- ScrollCycleView 替身：只实现 ForeachItemGO（PlayTaskSlideIn 只认这个接口）
local function newListView(items)
    local sv = { items = items }
    function sv:ForeachItemGO(fn)
        for i, go in ipairs(self.items) do fn(i, go) end
    end
    return sv
end

local panelRoot = newRect("BattlePassPanel_Mission", true)

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = { Linear = "Linear", OutQuad = "OutQuad", InOutQuad = "InOutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
function Inherit(base) return setmetatable({}, { __index = base }) end
newObjToParent = function(tpl, parent)
    local c = tpl
    parent:AddChild(c)
    return c
end

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

ConfigManager = {
    GetConfig = function() return {} end,
    GetConfigData = function() return {} end,
    TryGetConfigDataByKey = function() return {} end,
}
ConfigName = { BattlePassReward = 1, BattlePassConfig = 2, BattlePassTask = 3 }
SubUIManager = { Open = function() return { SetData = function() end, OnShow = function() end } end }
SubUIConfig = { ScrollCycleView = 1, ItemView = 2 }
GetLanguageStrById = function() return "" end
GetLanguageStrByStr = function() return "" end
Game = { GlobalEvent = { AddEvent = function() end, RemoveEvent = function() end } }
GameEvent = { MissionDaily = { OnMissionDailyChanged = 1 } }
NetManager = { BattlePassRequest = function() end }
TaskManager = { GetTypeTaskList = function() return {} end }
PrivilegeManager = { GetPrivilegeOpenStatusById = function() return false end }
CheckRedPointStatus = function() end
RedPointType = { BattlePassMission = 1 }
UIName = { RewardItemPopup = 1, PublicGetHeroPanel = 2 }
TaskTypeDef = { BattlePass = 1 }
PopupTipPanel = { ShowTip = function() end }

local fakeModule = setmetatable({}, { __index = function() return function() end end })
function require(path) return fakeModule end

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()
Panel.gameObject = panelRoot

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
        local b = BASE[name]
        assert(ns[name].anchoredPosition.x == b[1] and ns[name].anchoredPosition.y == b[2],
               ("%s: %s 应回到 (%d,%d)，实际 (%.2f,%.2f)"):format(tag, name, b[1], b[2],
                   ns[name].anchoredPosition.x, ns[name].anchoredPosition.y))
    end
    assert(ns.bg.graphics.Image.color.a == 1, tag .. ": bg alpha 应回 1")
end

-- ---------------- case 1: 单卡滑入 + 底板淡入 ----------------
print("== case1 PlayTaskSlideIn（单卡）==")
tweens = {}
local card1 = buildCard(1, true)
Panel.scrollViewList = newListView({ card1 })

local played = Panel.PlayTaskSlideIn()
assert(played == 1, "应播 1 张卡，实际 " .. tostring(played))
-- 6 个子节点各 1 条位移 + bg 1 条淡入 = 7
assert(#tweens == 7, "tween 条数应为 7，实际 " .. #tweens)
local ns = nodesOf(card1)
for _, name in ipairs(CARD_NODES) do
    local b = BASE[name]
    assert(ns[name].anchoredPosition.x == b[1] + 260,
           ("%s 起点应为 x+260 = %d，实际 %.1f"):format(name, b[1] + 260, ns[name].anchoredPosition.x))
    assert(ns[name].anchoredPosition.y == b[2], name .. " 的 y 不该被动")
end
assert(math.abs(ns.bg.graphics.Image.color.a - 0.3647) < 1e-6,
       "底板淡入起点应为参考的 0.3647")
assert(card1.anchoredPosition.x == 0, "卡根节点不能被动（ScrollCycleView 每次重写它）")
for _, t in ipairs(tweens) do
    assert(t.dur == 0.22, "单卡时长应为 0.22")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
    assert(t.delay == 0, "单卡不该有延迟")
end
print("  6 节点 x+260（右侧起）+ bg 0.3647，共 7 条 tween")

-- ---------------- case 2: 完成恢复 ----------------
print("== case2 完成后精确回基准值 ==")
for _, t in ipairs(tweens) do t:Complete() end
assertBase(card1, "完成后")
print("  位置/颜色全复位")

-- ---------------- case 3: 中途 Stop ----------------
print("== case3 中途 Stop 全复位 ==")
tweens = {}
Panel.PlayTaskSlideIn()
assert(ns.title.anchoredPosition.x == 180, "重播应从起点起（-80 + 260 = 180）")
Panel.StopTaskSlideIn()
assert(liveTweens() == 0, "Stop 后不该有存活 tween，实际 " .. liveTweens())
assertBase(card1, "Stop 后")
print("  Kill + 位置/颜色全复位")

-- ---------------- case 4: 多卡错开 ----------------
print("== case4 多卡错开 0.05 ==")
tweens = {}
local card2 = buildCard(2, true)
local card3 = buildCard(3, true)
Panel.scrollViewList = newListView({ card1, card2, card3 })
played = Panel.PlayTaskSlideIn()
assert(played == 3, "应播 3 张卡，实际 " .. played)
assert(#tweens == 21, "3 卡 × 7 = 21 条，实际 " .. #tweens)
local function delayOf(card, node)
    for _, t in ipairs(tweens) do
        if t.tf == card.children[node] then return t.delay end
    end
end
assert(delayOf(card2, "bg") == 0.05, "第 2 张延迟应为 0.05，实际 " .. tostring(delayOf(card2, "bg")))
assert(delayOf(card3, "bg") == 0.10, "第 3 张延迟应为 0.10，实际 " .. tostring(delayOf(card3, "bg")))
print("  3 卡 × 7 条，延迟 0 / 0.05 / 0.10")
Panel.StopTaskSlideIn()
assertBase(card2, "多卡 Stop 后 card2")
assertBase(card3, "多卡 Stop 后 card3")

-- ---------------- case 5: 跳过未激活 ----------------
print("== case5 未激活的卡不参与 ==")
tweens = {}
local hidden = buildCard(4, false)
Panel.scrollViewList = newListView({ card1, hidden })
played = Panel.PlayTaskSlideIn()
assert(played == 1, "只应播 1 张（隐藏的被跳过），实际 " .. played)
assert(#tweens == 7, "tween 条数应为 7，实际 " .. #tweens)
assert(hidden.children.bg.anchoredPosition.x == 0, "隐藏卡不该被动")
print("  隐藏卡跳过，不白占一轮")
Panel.StopTaskSlideIn()

-- ---------------- case 6: 空数据 / 无列表 ----------------
print("== case6 空数据不报错 ==")
Panel.scrollViewList = newListView({})
assert(Panel.PlayTaskSlideIn() == 0, "空列表应返回 0")
Panel.scrollViewList = nil
assert(Panel.PlayTaskSlideIn() == 0, "无列表应返回 0")
Panel.scrollViewList = newListView({ card1 })
print("  返回 0，不报错")

-- ---------------- case 7: 生命周期回收 ----------------
print("== case7 OnClose / OnDestroy 回收 ==")
tweens = {}
Panel.PlayTaskSlideIn()
Panel:OnClose()
assert(liveTweens() == 0, "OnClose 后不该有存活 tween")
assertBase(card1, "OnClose 后")
tweens = {}
Panel.PlayTaskSlideIn()
Panel:OnDestroy()
assert(liveTweens() == 0, "OnDestroy 后不该有存活 tween")
assertBase(card1, "OnDestroy 后")
print("  两处都回收")

-- ---------------- case 8: 数据刷新不播 ----------------
print("== case8 suppressTaskAnim 时不播 ==")
tweens = {}
Panel.scrollData = nil            -- SwitchView 里的 SetData 分支跳过，只验播放判定
Panel.suppressTaskAnim = true
Panel.SwitchView(1)
assert(#tweens == 0, "抑制时不该起 tween，实际 " .. #tweens)
Panel.suppressTaskAnim = false
Panel.SwitchView(1)
assert(#tweens == 7, "不抑制时应起 7 条，实际 " .. #tweens)
print("  抑制时 0 条，放开后 7 条")
Panel.StopTaskSlideIn()

print("ALL OK")
