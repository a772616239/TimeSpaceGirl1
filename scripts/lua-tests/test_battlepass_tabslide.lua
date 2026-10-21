-- 离线验证 BattlePassPanel_Mission 的选项卡入场动画（不依赖 Unity）：
-- 用假 Util / getComponent / DOTween 跑真源码 + 真 TabBox，覆盖
--   ① PlayTabSlideIn     13 个选项卡按 box 子节点顺序逐格滑入（x 轴 -140 / select 走 y 轴 +140）+ 淡入 0.3647
--   ② 完成恢复           anchoredPosition 与 alpha 精确回到基准值
--   ③ 中途 StopTabSlideIn Kill 后必须全复位（不能停在半截位置/半透明）
--   ④ 数量压缩           页签多时错开压到 kTabSlideMaxSpan，整体跨度 ≤ 0.4s
--   ⑤ 跳过未激活         未激活的 tab / 子节点不参与（否则下次打开会从半截起）
--   ⑥ 生命周期           OnClose / OnDestroy 都要回收
--   ⑦ GetTabList 陷阱    this.TabCtrl 指向空实例，GetTabList() 恒为空，动画不能依赖它
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_battlepass_tabslide.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/BattlePass/BattlePassPanel_Mission.lua"
local TABBOX = ROOT .. "Assets/ManagedResources/~Lua/Modules/Common/TabBox.lua"

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
        elseif self.kind == "posy" then
            self.tf.anchoredPosition = { x = self.tf.anchoredPosition.x, y = self.endv }
        else -- fade
            self.tf.color = { r = self.tf.color.r, g = self.tf.color.g,
                              b = self.tf.color.b, a = self.endv }
        end
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

-- graphic（Image / Text）替身：只需要 color + DOFade
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
    function o:DOAnchorPosY(v, dur) return newTween(self, v, dur, "posy") end
    function o.transform:GetChild(i) return self.order[i + 1] end
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

-- 复刻 prefab 里的 tab 模板：select(z 90°) / title(+HighText) / LockImage / Redpot / Text
local function buildTemplate()
    local tab = newRect("tab", true)
    local sel = tab:AddChild(newRect("select", true))
    sel.graphics.Image = newGraphic("Image", 1)
    sel.anchoredPosition = { x = 13.5, y = 0 }

    local title = tab:AddChild(newRect("title", true))
    title.graphics.Image = newGraphic("Image", 1)
    local high = title:AddChild(newRect("HighText", true))
    high.graphics.Text = newGraphic("Text", 1)
    high.anchoredPosition = { x = -3.47, y = -48.5 }

    local lock = tab:AddChild(newRect("LockImage", true))
    lock.graphics.Image = newGraphic("Image", 1)

    -- 红点默认关着（真机由 RefreshAllTaskBtn 按数据开关）⇒ 专门验"跳过未激活"
    local red = tab:AddChild(newRect("Redpot", false))
    red.graphics.Image = newGraphic("Image", 1)
    red.anchoredPosition = { x = -27, y = -27 }

    local txt = tab:AddChild(newRect("Text", true))
    txt.graphics.Text = newGraphic("Text", 0.7019608)
    txt.anchoredPosition = { x = -3.47, y = -48.5 }
    return tab
end

-- 深拷贝（TabBox 克隆 = Instantiate，子节点一起带走）
local function deepCopy(src)
    local o = newRect(src.name, src.activeSelf)
    o.anchoredPosition = { x = src.anchoredPosition.x, y = src.anchoredPosition.y }
    for cls, g in pairs(src.graphics) do
        o.graphics[cls] = newGraphic(g.cls, g.color.a)
    end
    for _, c in ipairs(src.order) do
        o:AddChild(deepCopy(c))
    end
    return o
end

local tabBox = newRect("TabBox", true)          -- Poor/Panel/TabBox
local template = buildTemplate()
local box = newRect("box", true)
tabBox:AddChild(template)
tabBox:AddChild(box)

local panelRoot = newRect("BattlePassPanel_Mission", true)

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = { Linear = "Linear", OutQuad = "OutQuad", InOutQuad = "InOutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end

function Inherit(base) return setmetatable({}, { __index = base }) end

newObjToParent = function(tpl, parent)
    local c = deepCopy(tpl)
    parent:AddChild(c)
    return c
end

Util = {
    GetGameObject = function(root, path)
        local base = (type(root) == "table" and root.transform) or root
        if path == "box" and base == tabBox then
            return box
        end
        if base.Find then return base:Find(path) end
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

local realRequire = require
function require(path)
    if path == "Modules/Common/TabBox" then
        return assert(loadfile(TABBOX))()
    end
    return fakeModule
end

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()

-- 真机上 tabBox 由 InitComponent 赋值；TabCtrl 则是那个"空实例"（见 case7）
Panel.tabBox = tabBox
Panel.gameObject = panelRoot

local TabBoxMod = require("Modules/Common/TabBox")
Panel.TabCtrl = TabBoxMod.New()
Panel.TabCtrl:Init(tabBox, { {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {} })

local TAB_COUNT = 13
assert(#box.order == TAB_COUNT, "应克隆 13 个选项卡，实际 " .. #box.order)
assert(template.activeSelf == false, "模板 tab 必须被 TabBox 藏起来")

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

local function nodesOf(tab)
    return Util.GetGameObject(tab, "select"), Util.GetGameObject(tab, "title"),
           Util.GetGameObject(tab, "title/HighText"), Util.GetGameObject(tab, "LockImage"),
           Util.GetGameObject(tab, "Text")
end

-- 颜色在 Graphic 上（Image / Text），不在 RectTransform 上
local function alphaOf(rect, cls)
    return rect.graphics[cls].color.a
end

-- ---------------- case 1: 逐格滑入 + 淡入 ----------------
print("== case1 PlayTabSlideIn ==")
tweens = {}
local played = Panel.PlayTabSlideIn()
assert(played == TAB_COUNT, "应播 13 个选项卡，实际 " .. tostring(played))
-- 每个选项卡 5 个可视子节点（Redpot 未激活被跳过）× 2 条 tween
assert(#tweens == TAB_COUNT * 5 * 2, "tween 条数应为 130，实际 " .. #tweens)
assert(template.anchoredPosition.x == 0 and template.anchoredPosition.y == 0,
       "模板 tab 不该被动")

local firstTab = box.order[1]
local sel, title, high, lock, txt = nodesOf(firstTab)
assert(sel.anchoredPosition.y == 140, "select 是 90° 旋转 ⇒ 起点走本地 +y，实际 " .. sel.anchoredPosition.y)
assert(title.anchoredPosition.x == -140, "title 起点应为 -140，实际 " .. title.anchoredPosition.x)
assert(math.abs(alphaOf(high, "Text") - 0.3647) < 1e-6, "淡入起点应为参考的 0.3647")
assert(math.abs(alphaOf(txt, "Text") - 0.3647) < 1e-6, "Text 淡入起点应被覆盖成 0.3647")
-- 第 2 个选项卡的延迟 = 0.03，第 13 个 = 0.36
local function firstDelayOf(tab)
    for _, t in ipairs(tweens) do
        if t.tf == tab.children.title then return t.delay end
    end
end
assert(math.abs(firstDelayOf(box.order[2]) - 0.03) < 1e-6, "相邻错开应为 0.03")
assert(math.abs(firstDelayOf(box.order[13]) - 0.36) < 1e-6, "末格延迟应为 0.36")
for _, t in ipairs(tweens) do
    assert(t.dur == 0.16, "单格时长应为 0.16")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
end
print(("  13 格 × 5 节点 × 2 通道 = %d 条；延迟 0 → %.2f"):format(#tweens, firstDelayOf(box.order[13])))

-- ---------------- case 2: 完成恢复 ----------------
print("== case2 完成后精确回基准值 ==")
for _, t in ipairs(tweens) do t:Complete() end
for i, tab in ipairs(box.order) do
    local s, ti, h, l, tx = nodesOf(tab)
    assert(s.anchoredPosition.x == 13.5 and s.anchoredPosition.y == 0, "select 应回到 (13.5,0): " .. i)
    assert(ti.anchoredPosition.x == 0 and ti.anchoredPosition.y == 0, "title 应回到 (0,0): " .. i)
    assert(alphaOf(ti, "Image") == 1 and alphaOf(s, "Image") == 1 and alphaOf(l, "Image") == 1,
           "Image alpha 应回 1: " .. i)
    assert(math.abs(alphaOf(tx, "Text") - 0.7019608) < 1e-6, "Text 应回 prefab 的 0.7019608: " .. i)
    assert(math.abs(alphaOf(h, "Text") - 1) < 1e-6, "HighText alpha 应回 1: " .. i)
end
print("  位置/颜色全部回基准（Text 0.702、其余 1）")

-- ---------------- case 3: 中途 Stop 必须全复位 ----------------
print("== case3 中途 StopTabSlideIn ==")
tweens = {}
Panel.PlayTabSlideIn()
Panel.StopTabSlideIn()
assert(liveTweens() == 0, "Stop 后不应有存活 tween，实际 " .. liveTweens())
local s1, t1, h1, l1, x1 = nodesOf(box.order[1])
assert(t1.anchoredPosition.x == 0, "Stop 后 title 必须复位到 0，否则永久偏在左边")
assert(s1.anchoredPosition.y == 0, "Stop 后 select 必须复位到 0")
assert(math.abs(alphaOf(x1, "Text") - 0.7019608) < 1e-6, "Stop 后 Text 必须回 0.702，不能停在半透明")
print("  Kill + 位置/颜色全复位")

-- ---------------- case 4: 重播从起点起、只有一批存活 ----------------
print("== case4 重播不叠加 ==")
tweens = {}
Panel.PlayTabSlideIn()
local firstBatch = #tweens
Panel.PlayTabSlideIn()
assert(liveTweens() == firstBatch, ("重播后应只剩 %d 条存活，实际 %d"):format(firstBatch, liveTweens()))
print(("  重播前 %d 条全部 Kill，新一轮 %d 条"):format(#tweens - firstBatch, firstBatch))
Panel.StopTabSlideIn()

-- ---------------- case 5: 数量压缩 ----------------
print("== case5 压缩错开 ==")
local savedBox = Panel.tabBox
local bigBox = newRect("TabBox", true)
local bigTemplate = buildTemplate()
local bigInner = newRect("box", true)
bigBox:AddChild(bigTemplate)
bigBox:AddChild(bigInner)
for i = 1, 24 do
    local c = deepCopy(bigTemplate)
    c.name = "tab" .. i
    bigInner:AddChild(c)
end
Panel.tabBox = bigBox
tweens = {}
Panel.PlayTabSlideIn()
local lastTabDelay
for _, t in ipairs(tweens) do
    if t.tf == bigInner.order[24].children.title then lastTabDelay = t.delay end
end
assert(math.abs(lastTabDelay - 0.4) < 1e-6, ("24 格时末格延迟应压到 0.4，实际 %s"):format(lastTabDelay))
assert(#tweens == 24 * 5 * 2, "24 格应为 240 条，实际 " .. #tweens)
print(("  24 格：末格 %.2f，单格时长仍 0.16，总长 %.2f"):format(lastTabDelay, lastTabDelay + 0.16))
Panel.StopTabSlideIn()
Panel.tabBox = savedBox

-- ---------------- case 6: 跳过未激活 ----------------
print("== case6 跳过未激活 ==")
tweens = {}
box.order[3]:SetActive(false)
Panel.PlayTabSlideIn()
assert(#tweens == (TAB_COUNT - 1) * 5 * 2, "未激活的选项卡应被跳过，实际 " .. #tweens)
box.order[3]:SetActive(true)
Panel.StopTabSlideIn()
print("  未激活 tab 与未激活 Redpot 都不参与")

-- ---------------- case 7: GetTabList 陷阱 ----------------
print("== case7 GetTabList 陷阱 ==")
local emptyCtrl = TabBoxMod.New()
local emptyList = emptyCtrl:GetTabList()
assert(#emptyList == 0, "第二个 TabCtrl 实例的 GetTabList 必须为空（Init 传 nil 直接 return）")
Panel.TabCtrl = emptyCtrl        -- 复刻 InitComponent 第 84~87 行的覆盖
tweens = {}
assert(Panel.PlayTabSlideIn() == TAB_COUNT, "动画不能依赖 GetTabList，必须走 box 子节点")
Panel.StopTabSlideIn()
print("  TabCtrl 为空时动画照常（读 box 子节点）")

-- ---------------- case 8: OnClose / OnDestroy 回收 ----------------
print("== case8 生命周期 ==")
tweens = {}
Panel.PlayTabSlideIn()
Panel:OnClose()
assert(liveTweens() == 0, "OnClose 后不应有存活 tween，实际 " .. liveTweens())

tweens = {}
Panel.PlayTabSlideIn()
Panel:OnDestroy()
assert(liveTweens() == 0, "OnDestroy 后不应有存活 tween，实际 " .. liveTweens())
local s9, t9 = nodesOf(box.order[1])
assert(t9.anchoredPosition.x == 0 and s9.anchoredPosition.y == 0, "OnDestroy 后必须复位")
print("  OnClose / OnDestroy 都回收到位")

print("ALL OK")
