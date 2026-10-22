-- 离线验证 LineupRecommend（阵容推荐）的两层入场动画（不依赖 Unity）：
--   目标：UIRoot/UIRoot/UINode/LineupRecommend/Scroll View/Viewport/Content
--   ① 卡层   iconPanel 的**所有直接子节点**从右侧 +240 滑回原位（0.22s / 相邻卡错开 0.055）
--   ② item 层 hero 实例的所有直接子节点（card / location）从右侧 +80 跟进
--            （0.18s / 同卡内错开 0.04 / 相对自己的卡晚 0.06）
--   ③ 🔴 回归：iconPanel 的 anchoredPosition 必须一动不动 —— 卡根挂着 VerticalLayoutGroup，
--      写它会被布局抹回，现象是「第一次打开只有第一张卡滑动」（第 2..N 张在 delay 期间被拉回原位）
--   ④ 回归：卡根 / grid / hero 根节点也不动（分别由 Content、grid 的布局组管）
--   ⑤ 完成精确复位 / 中途 Stop 全复位 / 卡数超过 kAnimCards 时后面几张不起 tween
--   ⑥ 从弹窗返回（只走 OnShow）不播；OnClose 停并清标记；连点不叠播；无可见卡返回 0
--   ⑦ 🔴 重开不闪原位：卡是缓存实例 + HeroCollectRewardInfo 异步回来才播 ⇒ 会先渲染若干帧
--      终值位置的卡，然后才跳到屏幕外（「原地闪一帧再跳出去」）。现在起播收口在 OnOpen：
--      case10 用「扣住网络回调」证明 OnOpen 那一帧就已经在起点，回调晚到不重播、不复位。
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_lineuprecommend_slidein.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Power/LineupRecommend.lua"

-- ---------------- stubs ----------------
local tweens = {}
local FAIL_AFTER = nil      -- 调试用：让第 N+1 条 tween 创建时抛错（验 pcall 兜底复位）
local holdNet = false       -- 扣住 HeroCollectRewardInfo 回调（模拟网络延迟）
local pendingNet = nil

local function newTween(tf, endv, dur)
    if FAIL_AFTER and #tweens >= FAIL_AFTER then error("boom: DOAnchorPosX 不可用") end
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

-- 万能节点：GetGameObject 找不到就按路径自动建（真 prefab 里的节点比这里需要的多得多）
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
    function o:GetChild(i) return self.order[i + 1] end
    function o:Find(path)
        local cur = self
        for nm in path:gmatch("[^/]+") do
            local nxt = cur.children and cur.children[nm]
            if not nxt then
                nxt = newRect(nm, true)
                cur:AddChild(nxt)
                if nm == "hero" then          -- 英雄卡模板（prefab 里是 INACTIVE）+ card/location 两个孩子
                    nxt:SetActive(false)
                    nxt:AddChild(newRect("card", true))
                    local loc = nxt:AddChild(newRect("location", true))
                    loc.anchoredPosition = { x = 0, y = -215 }
                end
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

-- 真 prefab 实测：iconPanel(1040x423) 的 7 个直接子节点
local CARD_CHILDREN = {
    { "imgDeco", 0, 36, false },        -- 1080x885 装饰层，INACTIVE
    { "imgBg", 0, 0, true },
    { "imgFrame", 0, 0, true },
    { "imgTitleBg", 0, 206, true },
    { "title", 0, 205.5, true },
    { "btnPreview", 440, 206, true },
    { "grid", -2.4, -29.3, true },
}
local HERO_CHILDREN = { { "card", 0, 0 }, { "location", 0, -215 } }
local ICON_POS = { x = 540, y = -211.5 }
local CARD_NODE_COUNT = #CARD_CHILDREN     -- 7
local HERO_NODE_COUNT = #HERO_CHILDREN     -- 2
local KANIM = 4                            -- 面板的 kAnimCards：只前 4 张赋入场

local function buildTemplate()
    local tpl = newRect("prefab", false)
    local icon = tpl:AddChild(newRect("iconPanel", true))
    icon.anchoredPosition = { x = ICON_POS.x, y = ICON_POS.y }
    for _, c in ipairs(CARD_CHILDREN) do
        local n = icon:AddChild(newRect(c[1], c[4]))
        n.anchoredPosition = { x = c[2], y = c[3] }
    end
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

local HERO_CFG = { Quality = 1, Star = 1, Painting = 1, PropertyName = 1, HeroValue = 0, HeroLocationDesc1 = 1 }
local heroConfig = setmetatable({}, { __index = function() return HERO_CFG end })
ConfigManager = {
    GetConfig = function() return heroConfig end,
    GetAllConfigsDataByKey = function() return {} end,
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

NetManager = {
    HeroCollectRewardInfo = function(cb)
        if holdNet then
            pendingNet = function(msg) pendingNet = nil; cb(msg) end
        else
            cb({ infos = {} })
        end
    end,
    HeroCollectRewardRequest = function() end,
}

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()

local root = newRect("LineupRecommend", true)
root:Find("btnBack")
local content = root:Find("Scroll View/Viewport/Content")
local tpl = buildTemplate()
content:AddChild(tpl)
Panel.gameObject = root
Panel.InitComponent(Panel)

local function setLineupCount(n, heroCount)
    heroCount = heroCount or 3
    local list = {}
    for i = 1, n do
        local ids = {}
        for k = 1, heroCount do ids[k] = 100 + k end
        list[i] = { Id = i, DescFirst = 1, ItemId = ids }
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

local function cardNodes(card)
    local icon = Util.GetGameObject(card, "iconPanel")
    local out = {}
    for i = 1, icon.childCount do out[#out + 1] = icon:GetChild(i - 1) end
    return out, icon
end

local function heroNodes(card)
    local grid = Util.GetGameObject(card, "iconPanel/grid")
    local out = {}
    for i = 1, grid.childCount do
        local hero = grid:GetChild(i - 1)
        if not hero.activeSelf then goto continue end   -- 跳过 hero 模板
        local hs = {}
        for j = 1, hero.childCount do hs[#hs + 1] = hero:GetChild(j - 1) end
        out[#out + 1] = { hero = hero, nodes = hs }
        ::continue::
    end
    return out, grid
end

local function delayOf(rect)
    for _, t in ipairs(tweens) do
        if t.tf == rect then return t.delay end
    end
    return nil
end

-- ---------------- case 1: 首次打开，卡层 + item 层同时编排 ----------------
print("== case1 首次打开：每张卡都滑（不只是第一张）+ 卡内英雄逐张跟进 ==")
tweens = {}
setLineupCount(3, 3)
Panel:OnOpen()
Panel:OnShow()
local cs = cards()
assert(#cs == 3, "应建 3 张卡，实际 " .. #cs)

for ci, card in ipairs(cs) do
    local cn, icon = cardNodes(card)
    assert(#cn == CARD_NODE_COUNT, "卡下应有 " .. CARD_NODE_COUNT .. " 个可视子节点，实际 " .. #cn)
    for i, node in ipairs(cn) do
        local base = CARD_CHILDREN[i]
        assert(node.anchoredPosition.x == base[2] + 240,
               ("第 %d 张卡 %s 起点应为 %.1f，实际 %.2f（只有第一张滑动 = 位移写到了被布局组管的 iconPanel）")
                   :format(ci, node.name, base[2] + 240, node.anchoredPosition.x))
        assert(node.anchoredPosition.y == base[3], node.name .. " 的 y 不该被动")
        assert(delayOf(node) and math.abs(delayOf(node) - (ci - 1) * 0.055) < 1e-9,
               ("第 %d 张卡 %s 的 delay 应为 %.3f"):format(ci, node.name, (ci - 1) * 0.055))
    end
    -- 🔴 回归断言：iconPanel 自己（布局组直接管的那层）一动都不能动
    assert(icon.anchoredPosition.x == ICON_POS.x and icon.anchoredPosition.y == ICON_POS.y,
           "第 " .. ci .. " 张卡的 iconPanel 根节点被动了 —— 布局组会把它抹回，必须写子节点")
    -- 卡根同理
    assert(card.anchoredPosition.x == 0 and card.anchoredPosition.y == 0,
           "第 " .. ci .. " 张卡的根节点被动了（Content 的 VerticalLayoutGroup 会抹回）")

    local hs, grid = heroNodes(card)
    assert(#hs == 3, "第 " .. ci .. " 张卡应有 3 个英雄，实际 " .. #hs)
    -- grid 本身是 iconPanel 的子节点，跟着卡层走（-2.4 + 240）；它的布局组只影响 hero 根节点
    assert(grid.anchoredPosition.x == -2.4 + 240, "grid 应随卡层一起右移 240")
    for k, h in ipairs(hs) do
        assert(h.hero.anchoredPosition.x == 0, "hero 根节点不该被动（grid 的布局组会抹回）")
        for j, node in ipairs(h.nodes) do
            local base = HERO_CHILDREN[j]
            assert(node.anchoredPosition.x == base[2] + 80,
                   ("第 %d 张卡第 %d 个英雄 %s 起点应为 x+80，实际 %.2f"):format(ci, k, node.name, node.anchoredPosition.x))
            local want = (ci - 1) * 0.055 + 0.06 + (k - 1) * 0.04
            assert(math.abs(delayOf(node) - want) < 1e-9,
                   ("第 %d 张卡第 %d 个英雄 delay 应为 %.3f，实际 %s"):format(ci, k, want, tostring(delayOf(node))))
        end
    end
end
for _, t in ipairs(tweens) do
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
end
print(("  3 卡 x (%d 卡节点 + 3x%d 英雄节点) = %d 条 tween"):format(CARD_NODE_COUNT, HERO_NODE_COUNT, #tweens))
print("  iconPanel / 卡根 / grid / hero 根全部没动（回归）")

-- ---------------- case 2: 完成精确复位 ----------------
print("== case2 完成后精确回基准值 ==")
for _, t in ipairs(tweens) do t:Complete() end
for ci, card in ipairs(cs) do
    local cn = cardNodes(card)
    for i, node in ipairs(cn) do
        local base = CARD_CHILDREN[i]
        assert(node.anchoredPosition.x == base[2] and node.anchoredPosition.y == base[3],
               ("完成后第 %d 张卡 %s 应回 (%.1f,%.1f)"):format(ci, node.name, base[2], base[3]))
    end
    local hs = heroNodes(card)
    for k, h in ipairs(hs) do
        for j, node in ipairs(h.nodes) do
            local base = HERO_CHILDREN[j]
            assert(node.anchoredPosition.x == base[2] and node.anchoredPosition.y == base[3],
                   ("完成后第 %d 张卡第 %d 英雄 %s 应回基准"):format(ci, k, node.name))
        end
    end
end
print("  卡层 + item 层全部精确复位")

-- ---------------- case 3: 中途 Stop ----------------
print("== case3 中途 Stop 全复位 ==")
tweens = {}
Panel:OnOpen(); Panel:OnShow()
assert(#tweens == 3 * (CARD_NODE_COUNT + 3 * HERO_NODE_COUNT), "重播应重建满额 tween，实际 " .. #tweens)
Panel.StopSlideIn()
assert(liveTweens() == 0, "Stop 后不该有存活 tween，实际 " .. liveTweens())
for ci, card in ipairs(cs) do
    local cn = cardNodes(card)
    assert(cn[1].anchoredPosition.x == CARD_CHILDREN[1][2], "Stop 后第 " .. ci .. " 张卡应复位")
    local hs = heroNodes(card)
    assert(hs[1].nodes[1].anchoredPosition.x == 0, "Stop 后第 " .. ci .. " 张卡英雄应复位")
end
print("  Kill + 两层全复位")

-- ---------------- case 4: 从弹窗返回不播 ----------------
print("== case4 只走 OnShow（IsBackOpen）不播 ==")
tweens = {}
Panel:OnShow()
assert(#tweens == 0, "从弹窗返回不该重播，实际起了 " .. #tweens .. " 条")
local cn1 = cardNodes(cs[1])
assert(cn1[1].anchoredPosition.x == CARD_CHILDREN[1][2], "位置应保持在终值")
print("  0 条 tween")

-- ---------------- case 5: OnClose 停 + 晚到的 OnShow 不播 ----------------
print("== case5 OnClose 停并清标记 ==")
tweens = {}
Panel:OnOpen(); Panel:OnShow()
assert(#tweens > 0, "应播起来")
Panel:OnClose()
assert(liveTweens() == 0, "OnClose 后不该有存活 tween")
tweens = {}
Panel:OnShow()
assert(#tweens == 0, "关闭后晚到的 OnShow 不该播")
print("  关闭即停，晚到不播")

-- ---------------- case 6: 连点不叠播 ----------------
print("== case6 连点不叠播 ==")
tweens = {}
Panel:OnOpen(); Panel:OnShow()
local before = #tweens
assert(Panel.PlaySlideIn() == 0, "上一轮没播完时不该重播")
assert(#tweens == before, "不该新建 tween")
print("  返回 0，0 条新 tween")

-- ---------------- case 7: 播完再播 + OnDestroy ----------------
print("== case7 播完后能再播 + OnDestroy 回收 ==")
for _, t in ipairs(tweens) do t:Complete() end
tweens = {}
assert(Panel.PlaySlideIn() == 3, "自然播完之后应能重新播")
Panel:OnDestroy()
assert(liveTweens() == 0, "OnDestroy 后不该有存活 tween")
print("  重播正常；OnDestroy 回收干净")

-- ---------------- case 8: 卡数超过 kAnimCards ----------------
print("== case8 超过 4 张时只给前 4 张赋入场 ==")
tweens = {}
-- 模拟「面板被真销毁后重开」：旧卡的 GameObject 随面板一起没了（harness 手动清 Content）
content.order, content.children, content.childCount = {}, {}, 0
content:AddChild(tpl)
setLineupCount(6, 3)
Panel:OnOpen(); Panel:OnShow()
cs = cards()
assert(#cs == 6, "应建 6 张卡，实际 " .. #cs)
local per = CARD_NODE_COUNT + 3 * HERO_NODE_COUNT
assert(#tweens == 4 * per, ("只应给前 4 张起 tween = %d，实际 %d"):format(4 * per, #tweens))
for ci = 5, 6 do
    local cn = cardNodes(cs[ci])
    assert(cn[1].anchoredPosition.x == CARD_CHILDREN[1][2], "第 " .. ci .. " 张卡不该被动")
    assert(delayOf(cn[1]) == nil, "第 " .. ci .. " 张卡不该有 tween")
end
print("  前 4 张 " .. #tweens .. " 条，第 5/6 张 0 条")
Panel.StopSlideIn()

-- ---------------- case 9: 没有可见卡 ----------------
print("== case9 没有可见卡时不报错 ==")
tweens = {}
for _, c in ipairs(cs) do c:SetActive(false) end
assert(Panel.PlaySlideIn() == 0, "没有可见卡应返回 0")
assert(#tweens == 0, "不该起 tween")
for _, c in ipairs(cs) do c:SetActive(true) end
print("  返回 0，不报错")

-- ---------------- case 10: 重开不闪原位（起播收口在 OnOpen） ----------------
print("== case10 重开：数据回调迟到时，OnOpen 那一帧就已经在起点 ==")
Panel.StopSlideIn()
for ci, card in ipairs(cs) do
    assert(cardNodes(card)[1].anchoredPosition.x == CARD_CHILDREN[1][2], "前置：第 " .. ci .. " 张卡应在终值")
end
tweens = {}
holdNet = true
Panel:OnOpen()                      -- 面板刚 SetActive，还没渲染：这一帧必须已经在起点
assert(#tweens > 0, "重开应在 OnOpen 里就起播，实际 0 条（会先渲染一帧终值位置的卡）")
for ci = 1, math.min(#cs, KANIM) do
    local card = cs[ci]
    local cn = cardNodes(card)
    for i, node in ipairs(cn) do
        assert(node.anchoredPosition.x == CARD_CHILDREN[i][2] + 240,
               ("重开后第 %d 张卡 %s 应已在起点 %.1f，实际 %.2f"):format(ci, node.name, CARD_CHILDREN[i][2] + 240, node.anchoredPosition.x))
    end
end
for ci = KANIM + 1, #cs do
    assert(cardNodes(cs[ci])[1].anchoredPosition.x == CARD_CHILDREN[1][2],
           "屏幕外第 " .. ci .. " 张卡不该被动")
end
Panel:OnShow()                      -- 发请求，回调被扣住
assert(pendingNet ~= nil, "HeroCollectRewardInfo 应已被调用")
local before10 = #tweens
local pos10 = cardNodes(cs[1])[1].anchoredPosition.x
pendingNet({ infos = {} })          -- 回调晚到
assert(#tweens == before10, "回调晚到不该新建 tween，实际多 " .. (#tweens - before10) .. " 条")
assert(cardNodes(cs[1])[1].anchoredPosition.x == pos10, "回调晚到不该复位位置（复位=瞬间跳到终值）")
print("  OnOpen 即起播；回调晚到 0 条新 tween、位置不动")

-- ---------------- case 11: 播完之后回调才到，不重播 ----------------
print("== case11 播完之后回调才到 → 不重播 ==")
for _, t in ipairs(tweens) do t:Complete() end
tweens = {}
Panel:OnOpen()                      -- 正常播一轮并播完
for _, t in ipairs(tweens) do t:Complete() end
tweens = {}
holdNet = true
Panel:OnShow()
assert(pendingNet ~= nil)
pendingNet({ infos = {} })
assert(#tweens == 0, "播完之后回调到达不该再播，实际 " .. #tweens .. " 条")
print("  0 条 tween")
holdNet = false

-- ---------------- case 12: 起播中途抛错 → 已挪位但没起 tween 的也要复位 ----------------
print("== case12 tween 创建中途抛错 → 全部复位（含只挪位没起 tween 的） ==")
tweens = {}
FAIL_AFTER = 5
Panel:OnOpen()
FAIL_AFTER = nil
assert(liveTweens() == 0, "失败后不该留存活 tween，实际 " .. liveTweens())
for ci, card in ipairs(cs) do
    local cn, icon = cardNodes(card)
    for i, node in ipairs(cn) do
        assert(node.anchoredPosition.x == CARD_CHILDREN[i][2] and node.anchoredPosition.y == CARD_CHILDREN[i][3],
               ("失败后第 %d 张卡 %s 应回基准，实际 %.2f"):format(ci, node.name, node.anchoredPosition.x))
    end
    assert(icon.anchoredPosition.x == ICON_POS.x, "失败后 iconPanel 不该被动")
end
print("  抛错被 pcall 兜住，两层全部回基准")

-- ---------------- case 13: 预挪后立刻关闭（回调没回来）也复位 ----------------
print("== case13 起播中 OnClose → 复位，晚到回调不播 ==")
tweens = {}
holdNet = true
Panel:OnOpen()
Panel:OnShow()                      -- 请求已发出，回调被扣住
Panel:OnClose()                     -- 回调还没回来就被关掉
assert(liveTweens() == 0, "OnClose 后不该有存活 tween")
for ci, card in ipairs(cs) do
    assert(cardNodes(card)[1].anchoredPosition.x == CARD_CHILDREN[1][2], "OnClose 后第 " .. ci .. " 张卡应复位")
end
local before13 = #tweens
pendingNet({ infos = {} })
assert(#tweens == before13, "关闭后回调到达不该起 tween")
holdNet = false
print("  关闭即复位，晚到不播")

print("ALL OK")
