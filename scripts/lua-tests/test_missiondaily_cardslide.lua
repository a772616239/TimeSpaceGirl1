-- 离线验证 MissionDailyPanel_Daily 的**任务卡**入场动画（不依赖 Unity）：
-- 用假 Util / GetComponent / DOTween / ScrollCycleView 跑真源码，覆盖
--   ① PlayCardSlideIn   卡的可见子节点一起从右侧滑回原位 + 整卡底板淡入 0.3647
--                       （打开：+260 / 0.26s / 错开 0.055；切页签：+170 / 0.30s / 错开 0.05 + 整批晚 0.05）
--   ② 完成恢复          anchoredPosition 与 alpha 精确回到基准值（不是"差不多"）
--   ③ 中途 StopCardSlideIn Kill 后必须全复位（不能停在半截位置/半透明）
--   ④ 多卡错开          相邻卡 delay = 步长
--   ⑤ 跳过未激活        未激活的卡 / 三态互斥的按钮（receiveBtn|goBtn|Received）不参与
--   ⑥ 空数据 / 无列表   返回 0，不报错
--   ⑦ 生命周期          OnClose / OnDestroy 都要回收，且复位 shownOnce
--   ⑧ 抑制标记          suppressCardAnim 时 ApplyCardSlideIn 只复位不播；RefreshDailySilently 期间置标记
--   ⑨ 打开 vs 切页签    OnShow 首次算打开、之后算切页签
--   ⑩ 连点保护          上一轮没播完时只复位、不重播；Stop / 播完之后能再触发
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_missiondaily_cardslide.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Mission/MissionDailyPanel_Daily.lua"

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

-- 复刻 prefab 里 rewardPre（1078×275）的 6 个可视子节点，坐标取 prefab 实测值
local POS = { titleImage = { -101.79, 72.33 }, getRewardProgress = { -200, 50 },
              content = { -510, -43.1 }, receiveBtn = { 401.9, 0.44 },
              goBtn = { 401.9, 0.44 }, Received = { 404.1, 0 } }
local CARD_NODES = { "titleImage", "getRewardProgress", "content", "receiveBtn", "goBtn", "Received" }
-- prefab 里 goBtn / Received 是 INACTIVE，receiveBtn 激活（未领取态）
local DEFAULT_HIDDEN = { goBtn = true, Received = true }

local function buildCard(index, active, hidden)
    hidden = hidden or DEFAULT_HIDDEN
    local card = newRect("item" .. (index or 1), active)
    card.graphics.Image = newGraphic(1)          -- 整卡底板 = 卡根节点自己的 Image
    for _, name in ipairs(CARD_NODES) do
        local n = card:AddChild(newRect(name, not hidden[name]))
        n.anchoredPosition = { x = POS[name][1], y = POS[name][2] }
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
    return sv
end

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = { Linear = "Linear", OutQuad = "OutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
newObjToParent = function(tpl, parent) parent:AddChild(tpl); return tpl end

Util = {
    GetGameObject = function(root, path)
        local base = (type(root) == "table" and root.transform) or root
        if base and base.Find then return base:Find(path) end
        return nil
    end,
    AddClick = function() end,
    AddOnceClick = function() end,
    SetGray = function() end,
    AddParticleSortLayer = function() end,
}

ConfigManager = {
    GetConfig = function() return setmetatable({}, { __index = function() return nil end }) end,
}
ConfigName = { DailyTasksConfig = 1 }
GetLanguageStrById = function() return "" end
SubUIManager = { Open = function() return { SetData = function() end } end, Close = function() end }
SubUIConfig = { ScrollCycleView = 1, ItemView = 2 }
TaskManager = { GetTypeTaskList = function() return {} end, SetTypeTaskState = function() end }
TaskTypeDef = { DayTask = 1 }
ActTimeCtrlManager = { SingleFuncState = function() return true end }
NetManager = {}
UIManager = { OpenPanel = function() end, IsTopShow = function() return false end }
UIName = { RewardItemPopup = 1, MissionDailyPanel = 2 }
RedPointType = { DailyTask = 1, SecretTer = 2 }
CheckRedPointStatus = function() end
Game = { GlobalEvent = { AddEvent = function() end, RemoveEvent = function() end } }
GameEvent = { MissionDaily = { OnMissionDailyChanged = 1 }, CloseUI = { OnClose = 2 } }
JumpManager = { GoJump = function() end }
FightPointPassManager = { isBeginFight = false }
PlayerManager = { level = 1 }

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()
Panel.ScrollView = nil
Panel.rectMask = { enabled = true }   -- OnClose 会写它（真实面板由 InitComponent 赋值）

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
    assert(card.graphics.Image.color.a == 1, tag .. ": 整卡底板 alpha 应回 1")
end

-- ---------------- case 1: 单卡滑入 + 底板淡入 ----------------
print("== case1 PlayCardSlideIn（单卡 / 打开节奏）==")
tweens = {}
local card1 = buildCard(1, true)
Panel.ScrollView = newListView({ card1 })

local played = Panel.PlayCardSlideIn()
assert(played == 1, "应播 1 张卡，实际 " .. tostring(played))
-- 4 个激活子节点各 1 条位移 + 底板 1 条淡入 = 5
local expect1 = activeNodeCount(card1) + 1
assert(#tweens == expect1, ("tween 条数应为 %d，实际 %d"):format(expect1, #tweens))
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
assert(math.abs(card1.graphics.Image.color.a - 0.3647) < 1e-6, "底板淡入起点应为参考的 0.3647")
assert(card1.anchoredPosition.x == 0, "卡根节点不能被动（ScrollCycleView 每次重写它）")
for _, t in ipairs(tweens) do
    assert(t.dur == 0.26, "打开的单卡时长应为 0.26")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
    assert(t.delay == 0, "单卡不该有延迟")
end
print(("  %d 个可见节点 x+260（右侧起）+ 底板 0.3647，共 %d 条 tween"):format(activeNodeCount(card1), #tweens))

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
local per = activeNodeCount(card1) + 1
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
print("== case5 未激活的卡 / 三态互斥按钮不参与 ==")
tweens = {}
local hidden = buildCard(4, false)
-- 已领取态：receiveBtn / goBtn 关闭，只有 Received 激活
local received = buildCard(5, true, { receiveBtn = true, goBtn = true })
Panel.ScrollView = newListView({ card1, hidden, received })
played = Panel.PlayCardSlideIn()
assert(played == 2, "只应播 2 张（隐藏的被跳过），实际 " .. played)
local expect5 = (activeNodeCount(card1) + 1) + (activeNodeCount(received) + 1)
assert(#tweens == expect5, ("tween 条数应为 %d，实际 %d"):format(expect5, #tweens))
assert(hidden.children.content.anchoredPosition.x == POS.content[1], "隐藏卡不该被动")
assert(received.children.receiveBtn.anchoredPosition.x == POS.receiveBtn[1], "未激活的 receiveBtn 不该被动")
assert(received.children.Received.anchoredPosition.x == POS.Received[1] + 260, "激活的 Received 应参与")
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

-- ---------------- case 8: 数据刷新不播 ----------------
print("== case8 suppressCardAnim 时只复位不播 ==")
tweens = {}
assert(Panel.ApplyCardSlideIn() == 1, "正常应播 1 张")
assert(#tweens == activeNodeCount(card1) + 1, "正常应起 5 条")
Panel.StopCardSlideIn()
Panel.suppressCardAnim = true
assert(Panel.ApplyCardSlideIn() == 0, "抑制时应返回 0")
assert(liveTweens() == 0, "抑制时不该有存活 tween")
assertBase(card1, "抑制后")
Panel.suppressCardAnim = false
tweens = {}
assert(Panel.ApplyCardSlideIn() == 1, "放开后应正常播")
assert(#tweens == activeNodeCount(card1) + 1, "放开后应起 5 条")
Panel.StopCardSlideIn()
print("  抑制时 0 条且已复位，放开后 5 条")

-- ---------------- case 9: 打开 vs 切页签 ----------------
print("== case9 OnShow 首次算打开、之后算切页签 ==")
-- 用假 OnShowData 顶掉真实现，只验「OnShow 怎么判节奏 + 会走到播放入口」
local realOnShowData = Panel.OnShowData
local seen = {}
Panel.OnShowData = function() seen[#seen + 1] = Panel.nextPlayIsSwitch end
local parentStub = { sortingOrder = 1 }
Panel.OnMissionDailyChanged()   -- 数据刷新：走静默，仍会调 OnShowData，且标记要复位
assert(#seen == 1, "静默刷新也应只调一次 OnShowData，实际 " .. #seen)
assert(Panel.suppressCardAnim == false, "静默刷新后标记必须复位")
Panel:OnShow(parentStub)
assert(#seen == 2 and seen[2] == false, "第一次 OnShow 应是「打开」(false)")
-- 🔴 切页签真实链路：MissionDailyPanel.SwitchView 先对旧页签 OnClose，再对新页签 OnShow
--    ⇒ OnClose 不能复位 shownOnce，否则切回本页会被当成「首次打开」
Panel:OnClose()
Panel:OnShow(parentStub)
assert(seen[3] == true, "切页签（旧页签先 OnClose）后仍是「切页签」(true)")
-- 真销毁之后重新打开：回到「打开」节奏
Panel:OnDestroy()
Panel:OnShow(parentStub)
assert(seen[4] == false, "销毁后重新打开应回到「打开」(false)")
Panel.OnShowData = realOnShowData
print("  首次 false / 切页签 true（即便走过 OnClose）/ 销毁后重新打开 false")

-- ---------------- case 10: 切页签节奏 ----------------
print("== case10 切页签节奏（x+170 / 0.30s / 错开 0.05 / 整批晚 0.05）==")
tweens = {}
Panel.ScrollView = newListView({ card1, card2 })
played = Panel.PlayCardSlideIn(true)
assert(played == 2, "应播 2 张，实际 " .. played)
local ns10 = nodesOf(card1)
for _, name in ipairs(CARD_NODES) do
    if card1.children[name].activeSelf then
        local b = POS[name]
        assert(ns10[name].anchoredPosition.x == b[1] + 170,
               ("%s 切页签起点应为 x+170 = %s，实际 %.2f"):format(name, b[1] + 170, ns10[name].anchoredPosition.x))
    end
end
for _, t in ipairs(tweens) do
    assert(t.dur == 0.30, "切页签单卡时长应为 0.30，实际 " .. tostring(t.dur))
    assert(t.ease == Ease.OutQuad, "ease 仍为 OutQuad")
end
assert(math.abs(delayOf(card1, "content") - 0.05) < 1e-6, "首卡应晚 0.05 起播")
assert(math.abs(delayOf(card2, "content") - 0.10) < 1e-6, "次卡应为 0.05 + 0.05")
print("  x+170 / 0.30s / 延迟 0.05 与 0.10")

-- ---------------- case 11: 连点不叠播 ----------------
print("== case11 连点不叠播 ==")
local before = #tweens
assert(Panel.PlayCardSlideIn(true) == 0, "上一轮没播完时不该重播")
assert(#tweens == before, "不该新建 tween，实际新增 " .. (#tweens - before))
assertBase(card1, "连点中断后")
print("  返回 0，直接复位到终值，0 条新 tween")

-- ---------------- case 12: Stop / 自然播完后能再触发 ----------------
print("== case12 之后还能再触发 ==")
tweens = {}
assert(Panel.PlayCardSlideIn(true) == 2, "Stop 之后应能重新播")
for _, t in ipairs(tweens) do t:Complete() end
tweens = {}
assert(Panel.PlayCardSlideIn(true) == 2, "自然播完之后应能重新播")
assert(#tweens == (activeNodeCount(card1) + 1) * 2, "应新建满额 tween")
print("  Stop 后 / 自然播完后都能重播")
Panel.StopCardSlideIn()

print("ALL OK")
