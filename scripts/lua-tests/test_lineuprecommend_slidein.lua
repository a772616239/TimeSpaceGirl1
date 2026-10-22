-- 离线验证 LineupRecommend（阵容推荐）列表的**入场滑入**动画（不依赖 Unity）：
-- 目标节点 UIRoot/UIRoot/UINode/LineupRecommend/Scroll View/Viewport/Content
--   ① 首次打开          OnOpen 置标记 -> OnShow 网络回调建好列表后，每张卡的 iconPanel 从右侧 +240 滑回原位
--                       （0.22s / 相邻错开 0.055 / OutQuad）
--   ② 完成恢复          anchoredPosition 精确回到基准值（== 而不是约等于）
--   ③ 中途 Stop         Kill 后全复位，不留半截位置
--   ④ 卡根节点不动      Content 上挂着 VerticalLayoutGroup，写根节点必被抹回 => 只许写子节点
--   ⑤ 从弹窗返回不播    只走 OnShow（IsBackOpen）时不播，位置保持在终值
--   ⑥ 关闭时停止        OnClose 里 Stop + 清标记（网络回调可能晚到，不能播在已隐藏的面板上）
--   ⑦ 连点保护          上一轮没播完时只复位、不重播；Stop / 播完之后能再触发
--   ⑧ 空数据            0 张卡返回 0，不报错
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_lineuprecommend_slidein.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Power/LineupRecommend.lua"

-- ---------------- stubs ----------------
local tweens = {}

local function newTween(tf, endv, dur)
    local t = { tf = tf, endv = endv, dur = dur, delay = 0, ease = nil,
                onComplete = nil, killed = false }
    function t:SetDelay(d) self.delay = d; return self end
    function t:SetEase(e) self.ease = e; return self end
    function t:OnComplete(cb) self.onComplete = cb; return self end
    function t:Kill() self.killed = true end
    function t:Complete()
        if self.killed then return end
        self.tf.anchoredPosition = { x = self.endv, y = self.tf.anchoredPosition.y }
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

-- 万能节点：GetGameObject 找不到就按路径自动建（真 prefab 里的节点比测试需要多得多）
local function newRect(name, active)
    local o = { name = name, activeSelf = active ~= false, childCount = 0,
                anchoredPosition = { x = 0, y = 0 },
                localScale = nil, graphics = {} }
    o.children, o.order = {}, {}
    o.transform = o
    o.gameObject = o
    function o:GetComponent(cls)
        local cached = self.graphics[cls]
        if cached then return cached end
        if cls == "RectTransform" then return self end
        local c
        if cls == "Text" then
            c = { text = "" }
        elseif cls == "Slider" then
            c = { value = 0 }
        elseif cls == "Image" then
            c = { color = { r = 1, g = 1, b = 1, a = 1 }, sprite = nil }
        else
            c = {}
        end
        self.graphics[cls] = c
        return c
    end
    function o:SetActive(v) self.activeSelf = v and true or false end
    function o:SetParent(parent)
        if parent and parent ~= self then parent:AddChild(self) end
    end
    function o:DOAnchorPosX(v, dur) return newTween(self, v, dur) end
    function o:AddChild(c)
        self.children[c.name] = c
        self.order[#self.order + 1] = c
        self.childCount = #self.order
        return c
    end
    function o:Find(path)
        local cur = self
        for name in path:gmatch("[^/]+") do
            local nxt = cur.children and cur.children[name]
            if not nxt then
                nxt = newRect(name, true)
                cur:AddChild(nxt)
            end
            cur = nxt
        end
        return cur
    end
    return o
end

local function deepCopy(node)
    local c = newRect(node.name, node.activeSelf)
    c.anchoredPosition = { x = node.anchoredPosition.x, y = node.anchoredPosition.y }
    for _, child in ipairs(node.order or {}) do
        c:AddChild(deepCopy(child))
    end
    return c
end

-- iconPanel 在 prefab 里的基准（卡根 pivot 0.5/0.5，iconPanel 锚点左上）
local ICON_POS = { x = 540, y = -211.5 }

local function buildTemplate()
    local tpl = newRect("prefab", false)
    local icon = tpl:AddChild(newRect("iconPanel", true))
    icon.anchoredPosition = { x = ICON_POS.x, y = ICON_POS.y }
    tpl:AddChild(newRect("descPanel", false))
    return tpl
end

-- BasePanel 用桩替身：本用例只验 LineupRecommend 自己的入场逻辑
package.preload["Base/BasePanel"] = function()
    local BasePanel = {}
    function BasePanel:OnShow() end
    function BasePanel:OnClose() end
    function BasePanel:OnDestroy() end
    function BasePanel:ClosePanel() end
    return BasePanel
end
Inherit = function(base)
    return setmetatable({}, { __index = base })
end

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { one = 1, New = function(x, y, z) return { x = x, y = y, z = z } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = { Linear = "Linear", OutQuad = "OutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
newObject = function(tpl) return deepCopy(tpl) end

Util = {
    GetGameObject = function(root, path)
        local base = (type(root) == "table" and root.transform) or root
        if base and base.Find then return base:Find(path) end
        return nil
    end,
    AddClick = function() end,
    AddOnceClick = function() end,
    SetGray = function() end,
    LoadSprite = function() return nil end,
}

local HERO = { Quality = 1, Star = 1, Painting = 1, PropertyName = 1, HeroValue = 0, HeroLocationDesc1 = 1 }
local heroConfig = setmetatable({}, { __index = function() return HERO end })
ConfigManager = {
    GetConfig = function() return heroConfig end,
    GetAllConfigsDataByKey = function() return {} end,   -- 由用例按需替换
}
ConfigName = { HeroConfig = 1, ItemConfig = 2, BeStronger = 3 }
GetLanguageStrById = function() return "" end
GetResourcePath = function() return "" end
GetProStrImageByProNum = function() return "" end
GetQuantityImageByquality = function() return "" end
SetHeroBg = function() end
CheckRedPointStatus = function() end
RedPointType = { LineupRecommend = 1 }
PlayerManager = { heroHandBook = {} }
UIManager = { OpenPanel = function() end }
UIName = { RoleGetInfoPopup = 1, RewardItemPopup = 2 }

-- 网络桩：同步回调，模拟「打开面板 -> 拉数据 -> 建卡」这条真实链路
local netInfos = {}
local netCallbacks = 0
NetManager = {
    HeroCollectRewardInfo = function(cb)
        netCallbacks = netCallbacks + 1
        cb({ infos = netInfos })
    end,
    HeroCollectRewardRequest = function() end,
}

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()

local root = newRect("LineupRecommend", true)
root:Find("btnBack")
local content = root:Find("Scroll View/Viewport/Content")
local tpl = buildTemplate()
content:AddChild(tpl)          -- 先挂好模板，InitComponent 才找得到它
Panel.gameObject = root
Panel.InitComponent(Panel)

local function setLineupCount(n)
    local list = {}
    for i = 1, n do
        list[i] = { Id = i, DescFirst = 1, ItemId = { 101, 102, 103 } }
    end
    ConfigManager.GetAllConfigsDataByKey = function() return list end
    return list
end

-- newObject 出来的卡名字仍是 "prefab"，所以按「active 且不是模板」判
local function cards()
    local out = {}
    for _, child in ipairs(content.order) do
        if child ~= tpl and child.activeSelf then out[#out + 1] = child end
    end
    return out
end

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

local function iconOf(card)
    return Util.GetGameObject(card, "iconPanel")
end

local function assertBase(card, tag)
    local icon = iconOf(card)
    assert(icon.anchoredPosition.x == ICON_POS.x and icon.anchoredPosition.y == ICON_POS.y,
           ("%s: iconPanel 应回 (%.1f,%.1f)，实际 (%.2f,%.2f)"):format(tag, ICON_POS.x, ICON_POS.y,
               icon.anchoredPosition.x, icon.anchoredPosition.y))
    assert(card.anchoredPosition.x == 0 and card.anchoredPosition.y == 0,
           tag .. ": 卡根节点不该被动（VerticalLayoutGroup 会抹回）")
end

-- ---------------- case 1: 首次打开，逐张从右滑入 ----------------
print("== case1 首次打开：OnOpen -> OnShow 建卡后逐张滑入 ==")
tweens = {}
setLineupCount(3)
Panel:OnOpen()
assert(netCallbacks == 0, "OnOpen 不该自己去拉数据")
Panel:OnShow()
assert(netCallbacks == 1, "OnShow 应拉一次奖励信息")
local cs = cards()
assert(#cs == 3, "应建 3 张卡，实际 " .. #cs)
assert(#tweens == 3, "3 张卡各 1 条位移 tween，实际 " .. #tweens)
for i, card in ipairs(cs) do
    local icon = iconOf(card)
    assert(icon.anchoredPosition.x == ICON_POS.x + 240,
           ("第 %d 张起点应为 x+240 = %.1f，实际 %.2f"):format(i, ICON_POS.x + 240, icon.anchoredPosition.x))
    assert(icon.anchoredPosition.y == ICON_POS.y, "y 不该被动（竖向列表上下滑会读成列表在跳）")
    assert(card.anchoredPosition.x == 0, "卡根节点不能被动")
end
assert(math.abs(tweens[1].delay - 0) < 1e-9, "第 1 张 delay 应为 0")
assert(math.abs(tweens[2].delay - 0.055) < 1e-9, "第 2 张 delay 应为 0.055")
assert(math.abs(tweens[3].delay - 0.11) < 1e-9, "第 3 张 delay 应为 0.11")
for _, t in ipairs(tweens) do
    assert(t.dur == 0.22, "单卡时长应为 0.22，实际 " .. tostring(t.dur))
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
end
print("  3 张卡 x+240 / 0.22s / 延迟 0 / 0.055 / 0.11")

-- ---------------- case 2: 完成精确复位 ----------------
print("== case2 完成后精确回基准值 ==")
for _, t in ipairs(tweens) do t:Complete() end
for i, card in ipairs(cs) do assertBase(card, "完成后 card" .. i) end
print("  位置全复位，卡根节点始终没动")

-- ---------------- case 3: 中途 Stop ----------------
print("== case3 中途 Stop 全复位 ==")
tweens = {}
Panel:OnOpen()
Panel:OnShow()
assert(#tweens == 3, "重播应重新起 3 条")
assert(iconOf(cs[1]).anchoredPosition.x == ICON_POS.x + 240, "重播应从起点起")
Panel.StopSlideIn()
assert(liveTweens() == 0, "Stop 后不该有存活 tween，实际 " .. liveTweens())
for i, card in ipairs(cs) do assertBase(card, "Stop 后 card" .. i) end
print("  Kill + 位置全复位")

-- ---------------- case 4: 从弹窗返回（只 OnShow）不播 ----------------
print("== case4 只走 OnShow（IsBackOpen）不播 ==")
tweens = {}
Panel:OnShow()   -- 玩家从英雄信息弹窗返回：框架走 OpenUI(true) -> 只 OnShow
assert(#tweens == 0, "从弹窗返回不该重播入场，实际起了 " .. #tweens .. " 条")
for i, card in ipairs(cs) do assertBase(card, "back-open 后 card" .. i) end
print("  0 条 tween，位置保持在终值")

-- ---------------- case 5: 关闭时停止 + 清标记 ----------------
print("== case5 OnClose 里 Stop 并清标记 ==")
tweens = {}
Panel:OnOpen()
Panel:OnShow()                       -- 播起来
assert(#tweens == 3, "应播 3 条")
Panel:OnClose()                      -- 播到一半玩家关掉
assert(liveTweens() == 0, "OnClose 后不该有存活 tween")
for i, card in ipairs(cs) do assertBase(card, "OnClose 后 card" .. i) end
tweens = {}
Panel:OnShow()                       -- 关掉后网络回调才到 / 面板被复用再次 OnShow
assert(#tweens == 0, "关闭后残留的 OnShow 不该播，实际 " .. #tweens .. " 条")
print("  关闭即停，之后晚到的 OnShow 不播")

-- ---------------- case 6: 连点保护 ----------------
print("== case6 连点不叠播 ==")
tweens = {}
Panel:OnOpen(); Panel:OnShow()
assert(#tweens == 3, "应播 3 条")
local before = #tweens
assert(Panel.PlaySlideIn() == 0, "上一轮没播完时不该重播")
assert(#tweens == before, "不该新建 tween，实际新增 " .. (#tweens - before))
for i, card in ipairs(cs) do assertBase(card, "连点中断后 card" .. i) end
print("  返回 0，直接复位到终值，0 条新 tween")

-- ---------------- case 7: 自然播完后能再触发 / OnDestroy 回收 ----------------
print("== case7 播完后能再播 + OnDestroy 回收 ==")
for _, t in ipairs(tweens) do t:Complete() end
tweens = {}
assert(Panel.PlaySlideIn() == 3, "自然播完之后应能重新播")
assert(#tweens == 3, "应新建 3 条")
Panel:OnDestroy()
assert(liveTweens() == 0, "OnDestroy 后不该有存活 tween")
for i, card in ipairs(cs) do assertBase(card, "OnDestroy 后 card" .. i) end
print("  重播正常；OnDestroy 回收干净")

-- ---------------- case 8: 没有可见卡 ----------------
print("== case8 没有可见卡时不报错 ==")
tweens = {}
for _, c in ipairs(cs) do c:SetActive(false) end
assert(Panel.PlaySlideIn() == 0, "没有可见卡应返回 0，实际 " .. tostring(Panel.PlaySlideIn()))
assert(#tweens == 0, "不该起 tween")
for _, c in ipairs(cs) do c:SetActive(true) end
print("  返回 0，不报错")

print("ALL OK")
