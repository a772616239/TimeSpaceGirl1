-- 离线验证 FightRecordPopup 的**战斗记录卡**入场动画（不依赖 Unity）：
-- 用假 Util / GetComponent / DOTween / VerticalLayoutGroup 场景跑真源码，覆盖
--   ① PlaySlideIn        卡的可见子节点一起从右侧滑回原位 + 整卡底板淡入 0.3647
--                        （+260 / 0.26s / 错开 0.055）
--   ② 完成恢复           anchoredPosition 与 alpha 精确回到基准值（不是"差不多"）
--   ③ 中途 StopSlideIn   Kill 后必须全复位（不能停在半截位置/半透明）
--   ④ 多卡错开           相邻卡 delay = 0.055
--   ⑤ 跳过未激活         OnOpen 未激活的 RewardInfoGroupPre 不参与
--   ⑥ 空数据 / 无卡      返回 0，不报错
--   ⑦ 生命周期           OnClose / OnDestroy 都要回收
--   ⑧ OnOpen→OnShow 闸门 OnOpen 有效数据才置 needSlideAnim；OnShow 消费一次；
--                        战斗回显返回（再 OnShow）不重播；空数据（NoPeople）不置标记
--   ⑨ 连点保护           上一轮没播完时只复位、不重播；Stop / 播完之后能再触发
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_fightrecord_cardslide.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Fight/FightRecordPopup.lua"

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

-- 复刻 prefab 里 RewardInfoGroupPre1（1080×260）的 7 个可视子节点，坐标取 prefab 实测值
local POS = { titleImage = { -150, 70 }, type = { -140, 70 }, Name = { -140, 0 },
              Image = { -180, -55 }, desc = { -135, -55 },
              headPos = { -430, -42 }, GoFightBtn = { 415, 0 } }
local CARD_NODES = { "titleImage", "type", "Name", "Image", "desc", "headPos", "GoFightBtn" }

local function buildCard(name, active)
    local card = newRect(name, active)
    card.graphics.Image = newGraphic(1)          -- 整卡底板 = 卡根节点自己的 Image（形态二）
    for _, node in ipairs(CARD_NODES) do
        local n = card:AddChild(newRect(node, true))
        n.anchoredPosition = { x = POS[node][1], y = POS[node][2] }
        if node == "desc" or node == "Name" then
            n.graphics.Text = { text = "" }       -- OnOpen 会写 Text.text
        end
        if node == "headPos" then
            local icon = newRect("headIcon", true)
            icon.graphics.Image = newGraphic(1)   -- GetPlayerHeadSprite 赋值的目标
            n:AddChild(icon)
        end
    end
    return card
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
    AddOnceClick = function() end,
}

ConfigManager = { GetConfig = function() return {} end }
ConfigName = { MainLevelConfig = 1 }
GetLanguageStrById = function(id) return "L" .. id end
GetPlayerHeadSprite = function() return "head" end
UIManager = { OpenPanel = function() end }
UIName = { FightPointPassMainPanel = 1, BattleStartPopup = 2, BattlePanel = 3 }
BattleManager = { GotoFight = function() end, GetBattleServerData = function() return {} end,
                  SetAgainstInfoData = function() end }
FightPointPassManager = { curOpenFight = 1 }
G_MainLevelConfig = { [1] = { MonsterGroup = 1 } }
G_MonsterConfig = { [1] = { MonsterId = 1 } }
G_HeroConfig = { [1] = { Icon = "icon" } }
G_MonsterGroup = { [1] = { Formation = 1 } }
GetMonsterGroupFirstEnemy = function() return 1 end
GetResourcePath = function(s) return s end
BATTLE_TYPE = { BACK = 1 }

-- ---------------- load ----------------
local Panel = assert(loadfile(SRC))()

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

local function setCards(c1, c2, c3)
    Panel.rewInfo1 = c1
    Panel.rewInfo2 = c2
    Panel.rewInfo3 = c3
end

-- ---------------- case 1: 单卡滑入 + 底板淡入 ----------------
print("== case1 PlaySlideIn（单卡）==")
tweens = {}
local card1 = buildCard("RewardInfoGroupPre1", true)
setCards(card1, nil, nil)

local played = Panel.PlaySlideIn()
assert(played == 1, "应播 1 张卡，实际 " .. tostring(played))
-- 7 个可见子节点各 1 条位移 + 底板 1 条淡入 = 8
assert(#tweens == #CARD_NODES + 1,
       ("tween 条数应为 %d，实际 %d"):format(#CARD_NODES + 1, #tweens))
local ns = nodesOf(card1)
for _, name in ipairs(CARD_NODES) do
    local b = POS[name]
    assert(ns[name].anchoredPosition.x == b[1] + 260,
           ("%s 起点应为 x+260 = %s，实际 %.2f"):format(name, b[1] + 260, ns[name].anchoredPosition.x))
    assert(ns[name].anchoredPosition.y == b[2], name .. " 的 y 不该被动")
end
assert(math.abs(card1.graphics.Image.color.a - 0.3647) < 1e-6, "底板淡入起点应为参考的 0.3647")
assert(card1.anchoredPosition.x == 0, "卡根节点不能被动（VerticalLayoutGroup 重建会抹回）")
for _, t in ipairs(tweens) do
    assert(t.dur == 0.26, "单卡时长应为 0.26")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
    assert(t.delay == 0, "单卡不该有延迟")
end
print(("  7 个可见节点 x+260（右侧起）+ 底板 0.3647，共 %d 条 tween"):format(#tweens))

-- ---------------- case 2: 完成恢复 ----------------
print("== case2 完成后精确回基准值 ==")
for _, t in ipairs(tweens) do t:Complete() end
assertBase(card1, "完成后")
print("  位置/颜色全复位")

-- ---------------- case 3: 中途 Stop ----------------
print("== case3 中途 Stop 全复位 ==")
tweens = {}
Panel.PlaySlideIn()
assert(ns.titleImage.anchoredPosition.x == POS.titleImage[1] + 260, "重播应从起点起")
Panel.StopSlideIn()
assert(liveTweens() == 0, "Stop 后不该有存活 tween，实际 " .. liveTweens())
assertBase(card1, "Stop 后")
print("  Kill + 位置/颜色全复位")

-- ---------------- case 4: 多卡错开 ----------------
print("== case4 三卡错开 0.055 ==")
tweens = {}
local card2 = buildCard("RewardInfoGroupPre2", true)
local card3 = buildCard("RewardInfoGroupPre3", true)
setCards(card1, card2, card3)
played = Panel.PlaySlideIn()
assert(played == 3, "应播 3 张卡，实际 " .. played)
assert(#tweens == (#CARD_NODES + 1) * 3,
       ("3 卡 × %d = %d 条，实际 %d"):format(#CARD_NODES + 1, (#CARD_NODES + 1) * 3, #tweens))
local function delayOf(card, node)
    for _, t in ipairs(tweens) do
        if t.tf == card.children[node] then return t.delay end
    end
end
assert(math.abs(delayOf(card2, "desc") - 0.055) < 1e-6,
       "第 2 张延迟应为 0.055，实际 " .. tostring(delayOf(card2, "desc")))
assert(math.abs(delayOf(card3, "desc") - 0.11) < 1e-6,
       "第 3 张延迟应为 0.11，实际 " .. tostring(delayOf(card3, "desc")))
print("  3 卡，延迟 0 / 0.055 / 0.11")
Panel.StopSlideIn()
assertBase(card2, "多卡 Stop 后 card2")
assertBase(card3, "多卡 Stop 后 card3")

-- ---------------- case 5: 跳过未激活 ----------------
print("== case5 未激活的卡不参与 ==")
tweens = {}
local hidden = buildCard("RewardInfoGroupPre2", false)
setCards(card1, hidden, card3)
played = Panel.PlaySlideIn()
assert(played == 2, "只应播 2 张（隐藏的被跳过），实际 " .. played)
assert(#tweens == (#CARD_NODES + 1) * 2, "tween 条数应为 " .. (#CARD_NODES + 1) * 2)
assert(hidden.children.desc.anchoredPosition.x == POS.desc[1], "隐藏卡不该被动")
print("  隐藏卡整体跳过")
Panel.StopSlideIn()

-- ---------------- case 6: 空数据 / 无卡 ----------------
print("== case6 空数据不报错 ==")
setCards(nil, nil, nil)
assert(Panel.PlaySlideIn() == 0, "无卡应返回 0")
setCards(buildCard("RewardInfoGroupPre1", false), nil, nil)
assert(Panel.PlaySlideIn() == 0, "全隐藏应返回 0")
setCards(card1, nil, nil)
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
Panel:OnDestroy()
assert(liveTweens() == 0, "OnDestroy 后不该有存活 tween")
assertBase(card1, "OnDestroy 后")
print("  两处都回收")

-- ---------------- case 8: OnOpen→OnShow 闸门 ----------------
print("== case8 OnOpen 有效数据才播；返回 OnShow 不重播 ==")
tweens = {}
-- OnOpen 会摸 rewInfo1/2/3 与 self.gameObject（真实面板由 InitComponent 赋值）
local pg = newRect("FightRecordPopup", true)
pg:AddChild(newRect("NoPeople", false))
Panel.gameObject = pg
setCards(card1, buildCard("RewardInfoGroupPre2", false), buildCard("RewardInfoGroupPre3", false))
local msg = { levelData = { { dataID = 1, curFormationIndex = 2, playName = "p", headId = 1 } } }
Panel:OnOpen(msg)
assert(Panel.needSlideAnim == true, "有效数据应置 needSlideAnim")
Panel:OnShow()
assert(Panel.needSlideAnim == false, "OnShow 应消费掉标记")
assert(#tweens == #CARD_NODES + 1, "OnShow 应起一轮入场，实际 " .. #tweens)
Panel.StopSlideIn()
assertBase(card1, "OnShow 播完后")
-- 战斗回显返回：再走 OnShow（没有 OnOpen）不重播
tweens = {}
Panel:OnShow()
assert(#tweens == 0, "返回触发的 OnShow 不该重播，实际 " .. #tweens)
-- 空数据：NoPeople 分支不置标记
Panel:OnOpen({ levelData = nil })
assert(Panel.needSlideAnim == false, "空数据不该置 needSlideAnim")
Panel:OnShow()
assert(#tweens == 0, "空数据后的 OnShow 不该播")
print("  打开播一次 / 返回不重播 / 空数据不播")

-- ---------------- case 9: 连点不叠播 ----------------
print("== case9 连点不叠播 ==")
setCards(card1, card2, card3)
tweens = {}
Panel.PlaySlideIn()
local before = #tweens
assert(Panel.PlaySlideIn() == 0, "上一轮没播完时不该重播")
assert(#tweens == before, "不该新建 tween，实际新增 " .. (#tweens - before))
assertBase(card1, "连点中断后")
print("  返回 0，直接复位到终值，0 条新 tween")

-- ---------------- case 10: Stop / 自然播完后能再触发 ----------------
print("== case10 之后还能再触发 ==")
tweens = {}
assert(Panel.PlaySlideIn() == 3, "Stop 之后应能重新播")
Panel.StopSlideIn()
tweens = {}
assert(Panel.PlaySlideIn() == 3, "Stop 后应能重新播")
for _, t in ipairs(tweens) do t:Complete() end
tweens = {}
assert(Panel.PlaySlideIn() == 3, "自然播完之后应能重新播")
assert(#tweens == (#CARD_NODES + 1) * 3, "应新建满额 tween")
print("  Stop 后 / 自然播完后都能重播")
Panel.StopSlideIn()

print("ALL OK")
