-- 离线验证 LaddersTypePanel 的**入场卡**滑入动画（不依赖 Unity）：
-- 用假 Util / GetComponent / DOTween / ScrollCycleView 跑真源码，覆盖
--   ① PlaySlideIn        卡的可见子节点一起从右侧滑回原位 + Icon 底板淡入 0.3647
--                        （+260 / 0.26s / 错开 0.055）
--   ② 完成恢复           anchoredPosition 与 alpha 精确回到基准值（不是"差不多"）
--   ③ 中途 StopSlideIn   Kill 后必须全复位（不能停在半截位置/半透明）
--   ④ 多卡错开           相邻卡 delay = 0.055；nil 占位卡的 nil 节点一起动
--   ⑤ 跳过未激活         ScrollCycleView 池外的 item 不参与
--   ⑥ 空列表 / 无列表组件 返回 0，不报错
--   ⑦ 生命周期           OnClose / OnDestroy 都要回收
--   ⑧ OnOpen→OnShow 闸门 OnOpen 置 needSlideAnim；OnShow 消费一次；
--                        进子玩法返回（再 OnShow）不重播
--   ⑨ 连点保护           上一轮没播完时只复位、不重播；Stop / 播完之后能再触发
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_ladderstype_cardslide.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Ladders/LaddersTypePanel.lua"

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

-- 复刻 prefab 里 rewardPre 的子节点（dump_prefab_tree.py 实测）：
--   Index(100x100 辅助) / Bg(860x1121 INACTIVE 废弃遗留) / Icon(1080x488 可见卡) / nil(占位卡)
-- Icon 基准 (0,0)。nil 占位卡按 RefreshItem 的实际行为：nil:SetActive(true)，Icon 保持模板默认 active。
local function buildCard(name, opts)
    opts = opts or {}
    local card = newRect(name, true)
    card.anchoredPosition = { x = 0, y = opts.rootY or 0 }   -- ScrollCycleView 会写这个，动画不许碰
    local index = card:AddChild(newRect("Index", true))
    index.anchoredPosition = { x = 0, y = 0 }
    card:AddChild(newRect("Bg", false))
    local icon = card:AddChild(newRect("Icon", opts.iconActive ~= false))
    icon.anchoredPosition = { x = 0, y = 0 }
    icon.graphics.Image = newGraphic(opts.iconAlpha or 1)
    local nilNode = card:AddChild(newRect("nil", opts.nilActive == true))
    nilNode.anchoredPosition = { x = 0, y = 0 }
    return card
end

-- 真 ScrollCycleView:ForeachItemGO 的语义（View/ScrollCycleView.lua:466）
local function newSV(items)
    local sv = { goItemList = items, dataCount = #items }
    function sv:SetData() end   -- harness 不触发 RefreshItem（那是渲染层的事）
    function sv:ForeachItemGO(func)
        for i = 1, math.min(#self.goItemList, self.dataCount) do
            func(i, self.goItemList[i])
        end
    end
    return sv
end

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = { Linear = "Linear", OutQuad = "OutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
require = function() return {} end
Inherit = function() return {} end
BasePanel = {}

Util = {
    GetGameObject = function(root, path)
        local base = (type(root) == "table" and root.transform) or root
        if base and base.Find then return base:Find(path) end
        return nil
    end,
    AddClick = function() end,
}

-- 源文件顶层就会执行：type 表要 GetLanguageStrById + SpecialConfig[58].Value + RedPointType + FUNCTION_OPEN_TYPE
ConfigManager = { GetConfig = function() return { [58] = { Value = "resetTip" } } end }
ConfigName = { SpecialConfig = 1 }
GetLanguageStrById = function(id) return "L" .. id end
RedPointType = { LaddersChallenge = 101 }
FUNCTION_OPEN_TYPE = { laddersChallenge = 1, ChaosZZ = 2 }
SoundManager = { PlayMusic = function() end }
SoundConfig = { BGM_Carbon = 1 }
CarbonManager = { GetMissionLevelData = function() end }
UpViewOpenType = { ShowRight = 1 }
PanelType = { Main = 1 }

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

local function assertBase(card, tag)
    assert(card.children.Icon.anchoredPosition.x == 0 and card.children.Icon.anchoredPosition.y == 0,
           ("%s: Icon 应回到 (0,0)，实际 (%.2f,%.2f)"):format(tag,
               card.children.Icon.anchoredPosition.x, card.children.Icon.anchoredPosition.y))
    assert(card.children.Index.anchoredPosition.x == 0, tag .. ": Index 不该被动")
    assert(card.children.Bg.anchoredPosition.x == 0, tag .. ": Bg(废弃节点) 不该被动")
    if card.children["nil"] and card.children["nil"].activeSelf then
        assert(card.children["nil"].anchoredPosition.x == 0,
               tag .. ": nil 占位节点完成后应回 (0,0)")
    end
    assert(card.children.Icon.graphics.Image.color.a == 1, tag .. ": Icon 底板 alpha 应回 1")
    assert(card.anchoredPosition.y == (card.expectedRootY or card.anchoredPosition.y),
           tag .. ": item 根节点不能被动（ScrollCycleView 会重写）")
end

-- ---------------- case 1: 单卡滑入 + 底板淡入 ----------------
print("== case1 PlaySlideIn（单卡，左滑入右：右侧 +260 起步）==")
tweens = {}
local card1 = buildCard("item1")
Panel.ScrollView = newSV({ card1 })

local played = Panel.PlaySlideIn()
assert(played == 1, "应播 1 张卡，实际 " .. tostring(played))
-- Icon 位移 1 条 + Icon 底板淡入 1 条 = 2（nil 未激活被跳过）
assert(#tweens == 2, "tween 条数应为 2（Icon 位移 + 底板淡入），实际 " .. #tweens)
assert(card1.children.Icon.anchoredPosition.x == 260,
       "Icon 起点应为 x+260 = 260，实际 " .. card1.children.Icon.anchoredPosition.x)
assert(card1.children.Icon.anchoredPosition.y == 0, "Icon 的 y 不该被动")
assert(card1.children["nil"].activeSelf == false, "占位 nil 未激活不该被动")
assert(math.abs(card1.children.Icon.graphics.Image.color.a - 0.3647) < 1e-6,
       "底板淡入起点应为参考的 0.3647")
assert(card1.anchoredPosition.x == 0, "item 根不能被动（ScrollCycleView 的 SetData/SetItemIndex 会重写）")
for _, t in ipairs(tweens) do
    assert(t.dur == 0.26, "单卡时长应为 0.26")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
    assert(t.delay == 0, "单卡不该有延迟")
end
print("  Icon x+260（右侧起）+ 底板 0.3647，2 条 tween，y 与 item 根不动")

-- ---------------- case 2: 完成恢复 ----------------
print("== case2 完成后精确回基准值 ==")
for _, t in ipairs(tweens) do t:Complete() end
assertBase(card1, "完成后")
assert(card1.children.Icon.anchoredPosition.x == 0, "Icon 应精确回到 0")
print("  位置/颜色全复位")

-- ---------------- case 3: 中途 Stop ----------------
print("== case3 中途 Stop 全复位 ==")
tweens = {}
Panel.PlaySlideIn()
assert(card1.children.Icon.anchoredPosition.x == 260, "重播应从起点起")
Panel.StopSlideIn()
assert(liveTweens() == 0, "Stop 后不该有存活 tween，实际 " .. liveTweens())
assertBase(card1, "Stop 后")
print("  Kill + 位置/颜色全复位")

-- ---------------- case 4: 多卡错开 + 占位卡 ----------------
print("== case4 三卡错开 0.055，nil 占位卡的 nil 节点一起动 ==")
tweens = {}
local card2 = buildCard("item2", { rootY = -490 })
local card3 = buildCard("item3", { rootY = -980, nilActive = true })   -- 敬请期待占位卡
Panel.ScrollView = newSV({ card1, card2, card3 })
played = Panel.PlaySlideIn()
assert(played == 3, "应播 3 张卡，实际 " .. played)
-- card1/card2：Icon 位移 + 淡入 = 2；card3：Icon 位移 + nil 位移 + 淡入 = 3
assert(#tweens == 2 + 2 + 3, "tween 条数应为 7，实际 " .. #tweens)
local function delayOf(card, nodeName)
    for _, t in ipairs(tweens) do
        if t.tf == card.children[nodeName] then return t.delay end
    end
end
assert(math.abs(delayOf(card2, "Icon") - 0.055) < 1e-6,
       "第 2 张延迟应为 0.055，实际 " .. tostring(delayOf(card2, "Icon")))
assert(math.abs(delayOf(card3, "Icon") - 0.11) < 1e-6,
       "第 3 张延迟应为 0.11，实际 " .. tostring(delayOf(card3, "Icon")))
assert(math.abs(delayOf(card3, "nil") - 0.11) < 1e-6, "占位 nil 节点应与所在卡同 delay")
assert(card3.children["nil"].anchoredPosition.x == 260, "占位 nil 节点起点也应在 x+260")
print("  3 卡，延迟 0 / 0.055 / 0.11；占位卡 3 条 tween")
Panel.StopSlideIn()
assertBase(card2, "多卡 Stop 后 card2")
assertBase(card3, "多卡 Stop 后 card3")

-- ---------------- case 5: 跳过未激活 ----------------
print("== case5 未激活的 item 不参与 ==")
tweens = {}
local hidden = buildCard("itemX", { iconActive = false })
hidden.activeSelf = false
Panel.ScrollView = newSV({ card1, hidden })
played = Panel.PlaySlideIn()
assert(played == 1, "只应播 1 张（隐藏的被跳过），实际 " .. played)
assert(#tweens == 2, "tween 条数应为 2，实际 " .. #tweens)
print("  隐藏 item 整体跳过")
Panel.StopSlideIn()

-- ---------------- case 6: 空列表 / 无列表组件 ----------------
print("== case6 空数据不报错 ==")
Panel.ScrollView = newSV({})
assert(Panel.PlaySlideIn() == 0, "空列表应返回 0")
Panel.ScrollView = nil
assert(Panel.PlaySlideIn() == 0, "无列表组件应返回 0")
Panel.ScrollView = newSV({ card1 })
print("  返回 0，不报错")

-- ---------------- case 7: 生命周期回收 ----------------
print("== case7 OnClose / OnDestroy 回收 ==")
tweens = {}
Panel.PlaySlideIn()
Panel:OnClose()
assert(liveTweens() == 0, "OnClose 后不该有存活 tween")
assertBase(card1, "OnClose 后")
tweens = {}
Panel.PlaySlideIn()
Panel.ItemViews = {}
Panel.HeadFrameView = { OnShow = function() end }
-- OnDestroy 会摸 SubUIManager，只验 slide 回收部分：
Panel.StopSlideIn()
assert(liveTweens() == 0, "OnDestroy 路径（StopSlideIn）后不该有存活 tween")
assertBase(card1, "OnDestroy 路径后")
print("  两处都回收")

-- ---------------- case 8: OnOpen→OnShow 闸门 ----------------
print("== case8 OnOpen 置闸门；返回 OnShow 不重播 ==")
tweens = {}
Panel.UpView = { OnOpen = function() end }
Panel.HeadFrameView = { OnShow = function() end }
Panel.ScrollView = newSV({ card1, card2, card3 })
Panel:OnOpen()
assert(Panel.needSlideAnim == true, "OnOpen 应置 needSlideAnim")
Panel:OnShow()
assert(Panel.needSlideAnim == false, "OnShow 应消费掉标记")
assert(#tweens == 7, "OnShow 应起一轮入场（7 条 tween），实际 " .. #tweens)
Panel.StopSlideIn()
assertBase(card1, "OnShow 播完后")
-- 进无尽 PK 再返回：再走 OnShow（没有 OnOpen）不重播
tweens = {}
Panel:OnShow()
assert(#tweens == 0, "返回触发的 OnShow 不该重播，实际 " .. #tweens)
print("  打开播一次 / 返回不重播")

-- ---------------- case 9: 连点不叠播 ----------------
print("== case9 连点不叠播 ==")
tweens = {}
Panel.PlaySlideIn()
local before = #tweens
assert(Panel.PlaySlideIn() == 0, "上一轮没播完时不该重播")
assert(#tweens == before, "不该新建 tween，实际新增 " .. (#tweens - before))
assertBase(card1, "连点中断后")
print("  返回 0，直接复位到终值，0 条新 tween")

-- ---------------- case 10: Stop / 自然播完后能再触发 ----------------
print("== case10 之后还能再触发 ==")
assert(Panel.PlaySlideIn() == 3, "Stop 之后应能重新播")
Panel.StopSlideIn()
tweens = {}
assert(Panel.PlaySlideIn() == 3, "Stop 后应能重新播")
for _, t in ipairs(tweens) do t:Complete() end
tweens = {}
assert(Panel.PlaySlideIn() == 3, "自然播完之后应能重新播")
assert(#tweens == 7, "应新建满额 tween（7 条），实际 " .. #tweens)
print("  Stop 后 / 自然播完后都能重播")
Panel.StopSlideIn()

print("ALL OK")
