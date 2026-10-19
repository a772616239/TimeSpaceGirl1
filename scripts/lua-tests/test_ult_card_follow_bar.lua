-- 大招小卡（HelpHeroMiniCard_Mine）挂到技能栏子节点下的回归测试
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_ult_card_follow_bar.lua
--
-- 覆盖的回归点（本轮改动）：
--   ① 卡片生成时直接是 myRect_Skill / enemyRect_Skill 的子节点，不再挂面板下；
--   ② 落点按「技能栏当前世界坐标」算：贴外缘 + 整块压在技能栏【上方】；
--   ③ 技能栏 1.2 缩放 / 敌方 -1.2 镜像必须被反算，否则卡片放大 1.2 倍、敌方左右翻转；
--   ④ 父子关系天然跟随：技能栏一动卡片世界坐标就跟着动，不需要（也不再创建）每帧重算计时器；
--   ⑤ 卡片不再自己隐藏：技能栏灭掉由父节点带走，卡片 activeSelf 不动；
--   ⑥ 卡片矩形与技能栏矩形【不相交】（技能底板 280x90 + SkillName 不能被盖住）。
--
-- 历史 bug（上一版，已删除的实现）：卡片自带 2.0s 定时器而技能栏亮 3.0s，卡片必然早 1 秒消失；
-- 靠 50Hz 计时器重算位置模拟 ParentConstraint，技能栏一动就顿挫。

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"

-- ---- 环境桩 ----
local now = 0
Time = setmetatable({}, {
    __index = function(_, k)
        if k == "realtimeSinceStartup" then return now end
        if k == "deltaTime" then return 0.01 end
        if k == "unscaledDeltaTime" then return 0.01 end
        return nil
    end,
})

-- 计时器：本次改动后模块不该再创建任何计时器，这里只负责计数
local timerCount = 0
Timer = {}
function Timer.New(func, duration, loop, unscaled)
    timerCount = timerCount + 1
    local t = {}
    function t:Start() end
    function t:Stop() end
    return t
end

Log = function() end
LogRed = Log
LogError = Log
LogWarn = Log
function IsNull(o) return o == nil or o.__null == true end

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { New = function(x, y, z) return { x = x, y = y, z = z } end }
Ease = { OutBack = 1, InQuad = 2 }
function GetLanguageStrById(id) return tostring(id) end

local function NewTween()
    local tw = {}
    function tw:SetEase() return self end
    function tw:Kill() end
    function tw:OnComplete(cb) if cb then cb() end; return self end
    return tw
end

local function NewRect(xmin, xmax, ymin, ymax)
    return { xMin = xmin, xMax = xmax, yMin = ymin, yMax = ymax }
end

local function NewGo(name)
    local go = { name = name, activeSelf = true, links = {}, parent = nil }
    function go:SetActive(v) self.activeSelf = v end
    function go:GetComponent(kind)
        if kind == "RectTransform" then return self.rt end
        return nil
    end
    go.transform = {
        gameObject = go,
        -- DOScale 在测试里直接结算成目标缩放（只关心最终值，不等补间时长）
        DOScale = function(self, v)
            if go.rt then go.rt.localScale = v end
            return NewTween()
        end,
        SetParent = function(_, p) go.parent = p end,
        SetSiblingIndex = function() end,
        GetSiblingIndex = function() return 0 end,
    }
    return go
end

local cardCount = 0
local function NewCardGo()
    local go = NewGo("HelpHeroMiniCard_Mine")
    go.rt = {
        pivot = Vector2.New(0.5, 0.5),
        sizeDelta = Vector2.New(0, 0),
        anchorMin = Vector2.New(0, 0),
        anchorMax = Vector2.New(0, 0),
        anchoredPosition = Vector2.New(0, 0),
        localPosition = Vector3.New(0, 0, 0),
        localScale = Vector3.New(1, 1, 1),
    }
    go.links["live"] = NewGo("live")
    return go
end

GameObject = {
    Instantiate = function(tpl, parent)
        cardCount = cardCount + 1
        local go = NewCardGo()
        go.parent = parent
        return go
    end,
    Destroy = function(go) if go then go.__null = true end end,
}

Util = {
    GetGameObject = function(root, path)
        local go = root and (root.gameObject or root) or nil
        if not go then return nil end
        return go.links and go.links[path] or nil
    end,
    ClearChild = function() end,
}

LoadHerolive = function() return { live = true } end
UnLoadHerolive = function() end

-- ---- 被测模块 ----
local BattleUltCard = assert(loadfile(LUA_SRC .. "/Modules/Battle/View/BattleUltCard.lua"))()

-- ---- 假视图：技能栏（世界坐标 + 父链缩放 + 本地矩形）----
local function NewBar(name, worldPos, lossy)
    local bar = { name = name, activeInHierarchy = false }
    bar.rt = {
        -- pivot (0, 0.5)、size 529x90 ⇒ 本地矩形 x 0..529 / y -45..45（与 prefab 一致）
        rect = NewRect(0, 529, -45, 45),
        pivot = Vector2.New(0, 0.5),
        sizeDelta = Vector2.New(529, 90),
        anchoredPosition = Vector2.New(0, -215),
    }
    function bar:GetComponent(kind)
        if kind == "RectTransform" then return self.rt end
        return nil
    end
    bar.transform = {
        gameObject = bar,
        position = worldPos,
        lossyScale = lossy,
        GetSiblingIndex = function() return 5 end,
    }
    return bar
end

local function NewView()
    local viewGo = NewGo("BattlePanel")
    viewGo.transform.lossyScale = Vector3.New(1, 1, 1)
    viewGo.transform.position = Vector3.New(540, 960, 0)
    local tpl = NewGo("HelpHeroShow")

    local myBar = NewBar("myRect_Skill", Vector3.New(0, -260, 0), Vector3.New(1.2, 1.2, 1))
    -- 敌方那条是镜像副本：localScale.x = -1.2，锚在右边，pivot 在右边缘
    local enemyBar = NewBar("enemyRect_Skill", Vector3.New(1080, -260, 0), Vector3.New(-1.2, 1.2, 1))

    viewGo.links["myRect_Skill"] = myBar
    viewGo.links["enemyRect_Skill"] = enemyBar

    local view = {
        gameObject = viewGo,
        transform = viewGo.transform,
        HelpHeroShow = tpl,
    }
    return view, myBar, enemyBar
end

local HERO = { Id = 1001, ReadingName = 0, HeroLocation = 0 }

-- 面板像素量纲 ⇒ 世界单位（面板缩放为 1 时相等）
local MARGIN_X_W = 140
local CARD_HALF_W = 140.4                          -- 0.26 缩放后卡宽 280.8 的一半
local CARD_HALF_H = 628.5 * 0.26                   -- 163.41：卡片中心到底边的距离
local GAP_Y = 8                                    -- 卡片底边与技能栏上沿的间隙
local LIFT_W = GAP_Y + CARD_HALF_H                 -- 171.41：卡片中心相对技能栏【上沿】的高度

local failures = 0
local function Check(name, cond, detail)
    if cond then
        print("  [PASS] " .. name)
    else
        failures = failures + 1
        print("  [FAIL] " .. name .. (detail and ("  -> " .. detail) or ""))
    end
end

local function Near(a, b, eps) return math.abs(a - b) <= (eps or 0.5) end

-- 子节点本地坐标 -> 世界坐标（无旋转，纯缩放 + 平移）
local function CardWorld(go)
    local bar = go.parent
    assert(bar ~= nil, "卡片没有父节点")
    local s = bar.lossyScale
    local p = bar.position
    local lp = go.rt.localPosition
    return p.x + lp.x * s.x, p.y + lp.y * s.y
end

local function CardBar(slot)
    return slot and slot.go and slot.go.parent or nil
end

-- ① 生成即挂到技能栏下
print("== ① 生成时直接是技能栏的子节点 ==")
do
    local view, myBar = NewView()
    BattleUltCard.ResetForBattle(view)
    timerCount = 0

    BattleUltCard.Show(view, HERO, 0, "a")
    local s = BattleUltCard.slots[0]
    Check("卡片父节点 = myRect_Skill", CardBar(s) == myBar.transform)
    Check("卡片父节点不是面板根节点", CardBar(s) ~= view.gameObject)
    Check("没有创建任何计时器（不再自己计时）", timerCount == 0, "timerCount=" .. timerCount)
    Check("卡片处于显示状态", s.go.activeSelf == true)
end

-- ② 落点按技能栏当前世界坐标算
print("== ② 落点 = 贴外缘 + 整块压在技能栏上方（世界坐标） ==")
do
    local view, myBar = NewView()
    BattleUltCard.ResetForBattle(view)
    BattleUltCard.Show(view, HERO, 0, "b")
    local s = BattleUltCard.slots[0]

    local left = myBar.transform.position.x + myBar.transform.lossyScale.x * myBar.rt.rect.xMin   -- 0
    local top  = myBar.transform.position.y + myBar.transform.lossyScale.y * myBar.rt.rect.yMax   -- -206
    local wx, wy = CardWorld(s.go)
    Check("X = 技能栏左边界 + 140", Near(wx, left + MARGIN_X_W), string.format("wx=%.2f want=%.2f", wx, left + MARGIN_X_W))
    Check("Y = 技能栏上沿 + 171.41", Near(wy, top + LIFT_W), string.format("wy=%.2f want=%.2f", wy, top + LIFT_W))
    -- 本地坐标同样对得上（子节点位置口径）
    Check("本地 localPosition.x = 140/1.2", Near(s.go.rt.localPosition.x, 140 / 1.2, 0.01),
        string.format("lp.x=%.4f", s.go.rt.localPosition.x))
    -- 关键：卡片底边必须落在技能栏上沿之上（否则会盖住技能底板 280x90 与 SkillName）
    local cardBottom = wy - CARD_HALF_H
    Check("卡片底边与技能栏上沿的间隙 = 8（不压技能栏）", Near(cardBottom - top, GAP_Y, 0.01),
        string.format("bottom=%.2f top=%.2f gap=%.2f", cardBottom, top, cardBottom - top))
    Check("卡片矩形与技能栏矩形竖向不相交", cardBottom >= top, string.format("bottom=%.2f top=%.2f", cardBottom, top))
end

-- ③ 缩放反算：技能栏 1.2 / 敌方 -1.2 镜像
print("== ③ 子节点缩放反算（1.2 放大、敌方镜像翻回来） ==")
do
    local view, myBar, enemyBar = NewView()
    BattleUltCard.ResetForBattle(view)
    BattleUltCard.Show(view, HERO, 0, "c0")
    local mine = BattleUltCard.slots[0]
    Check("我方卡本地缩放 = 0.26/1.2", Near(mine.go.rt.localScale.x, 0.26 / 1.2, 0.001),
        string.format("scale=%.4f", mine.go.rt.localScale.x))
    Check("我方卡世界缩放 = 0.26", Near(math.abs(mine.go.rt.localScale.x * myBar.transform.lossyScale.x), 0.26, 0.001))

    BattleUltCard.Show(view, HERO, 1, "c1")
    local enemy = BattleUltCard.slots[1]
    Check("敌方卡挂在 enemyRect_Skill 下", CardBar(enemy) == enemyBar.transform)
    Check("敌方卡本地缩放 x 为负（抵消父节点镜像）", enemy.go.rt.localScale.x < 0,
        string.format("scale.x=%.4f", enemy.go.rt.localScale.x))
    Check("敌方卡世界缩放 |x| = 0.26（没被翻转/放大）",
        Near(math.abs(enemy.go.rt.localScale.x * enemyBar.transform.lossyScale.x), 0.26, 0.001))
    -- 敌方那条 localScale.x 是负的，右边界要取两个角的世界坐标里大的那个（= 1080）
    local ex0 = enemyBar.transform.position.x + enemyBar.transform.lossyScale.x * enemyBar.rt.rect.xMin
    local ex1 = enemyBar.transform.position.x + enemyBar.transform.lossyScale.x * enemyBar.rt.rect.xMax
    local right = math.max(ex0, ex1)
    local ex = CardWorld(enemy.go)
    Check("敌方卡 X = 技能栏右边界 - 140", Near(ex, right - MARGIN_X_W),
        string.format("ex=%.2f want=%.2f", ex, right - MARGIN_X_W))
    -- 敌方那条上沿与 Y 同口径，镜像只影响 x，竖向必须在技能栏上方
    local eTop = enemyBar.transform.position.y + enemyBar.transform.lossyScale.y * enemyBar.rt.rect.yMax
    local _, ey = CardWorld(enemy.go)
    Check("敌方卡底边也在技能栏上沿之上（不压技能栏）", ey - CARD_HALF_H >= eTop,
        string.format("bottom=%.2f top=%.2f", ey - CARD_HALF_H, eTop))
end

-- ④ 父子关系天然跟随：技能栏一动卡片就动，不需要重算
print("== ④ 技能栏移动 → 卡片跟着动（无每帧重算） ==")
do
    local view, myBar = NewView()
    BattleUltCard.ResetForBattle(view)
    timerCount = 0
    BattleUltCard.Show(view, HERO, 0, "d")
    local s = BattleUltCard.slots[0]
    local x0, y0 = CardWorld(s.go)

    -- 入场动画把技能栏整体推上去 100、右移 30（改世界坐标，不改子节点）
    myBar.transform.position = Vector3.New(myBar.transform.position.x + 30, myBar.transform.position.y + 100, 0)
    local x1, y1 = CardWorld(s.go)
    Check("技能栏右移 30，卡片世界 X 也 +30", Near(x1 - x0, 30), string.format("dx=%.2f", x1 - x0))
    Check("技能栏上移 100，卡片世界 Y 也 +100", Near(y1 - y0, 100), string.format("dy=%.2f", y1 - y0))
    Check("跟随过程中没有起任何计时器", timerCount == 0, "timerCount=" .. timerCount)
end

-- ⑤ 不再自己隐藏：技能栏灭掉由父节点带走
print("== ⑤ 卡片不再自己隐藏 ==")
do
    local view, myBar = NewView()
    BattleUltCard.ResetForBattle(view)
    BattleUltCard.Show(view, HERO, 0, "e")
    local s = BattleUltCard.slots[0]
    myBar.activeInHierarchy = true
    myBar.activeInHierarchy = false      -- 技能栏 3 秒到点自己关掉
    now = now + 5                        -- 再怎么等，模块都不会去 SetActive(false)
    Check("技能栏灭掉后卡片 activeSelf 仍为 true（跟随父节点隐藏）", s.go.activeSelf == true)
    Check("卡片仍挂在技能栏下", CardBar(s) == myBar.transform)
end

-- ⑥ 同一阵营复用同一节点 + 同发大招去重
print("== ⑥ 同阵营复用 / 同发大招去重 ==")
do
    local view = NewView()
    BattleUltCard.ResetForBattle(view)
    cardCount = 0
    BattleUltCard.Show(view, HERO, 0, "f")
    local first = BattleUltCard.slots[0].go
    BattleUltCard.Show(view, HERO, 0, "f")          -- 同一发（多段技能重复调用）
    Check("同一发大招不重复建卡", cardCount == 1, "cardCount=" .. cardCount)
    Check("复用同一节点", BattleUltCard.slots[0].go == first)
    BattleUltCard.Show(view, HERO, 0, "f2")         -- 下一次大招
    Check("下一次大招仍复用节点", BattleUltCard.slots[0].go == first and cardCount == 1)
end

-- ⑦ 技能栏几何变了（换分辨率/换缩放）→ 下一次 Show 按新几何重算
print("== ⑦ 技能栏几何变化后下一次 Show 重算 ==")
do
    local view, myBar = NewView()
    BattleUltCard.ResetForBattle(view)
    BattleUltCard.Show(view, HERO, 0, "g1")

    -- 换成另一套分辨率：整体缩放 1.44、位置也变
    myBar.transform.lossyScale = Vector3.New(1.44, 1.44, 1)
    myBar.transform.position = Vector3.New(0, -200, 0)
    BattleUltCard.Show(view, HERO, 0, "g2")

    local s = BattleUltCard.slots[0]
    local top = -200 + 1.44 * 45                        -- -135.2
    local wx, wy = CardWorld(s.go)
    Check("X 仍是外侧 +140（世界单位）", Near(wx, 140), string.format("wx=%.2f", wx))
    Check("Y 跟随新的上沿", Near(wy, top + LIFT_W), string.format("wy=%.2f want=%.2f", wy, top + LIFT_W))
    Check("换缩放后卡片仍不压技能栏", wy - CARD_HALF_H >= top, string.format("bottom=%.2f top=%.2f", wy - CARD_HALF_H, top))
    Check("本地缩放按新父链缩放反算 = 0.26/1.44", Near(s.go.rt.localScale.x, 0.26 / 1.44, 0.001),
        string.format("scale=%.4f", s.go.rt.localScale.x))
end

-- ⑧ 找不到技能栏：兜底挂在面板下，不崩
print("== ⑧ 找不到技能栏时的兜底 ==")
do
    local viewGo = NewGo("BattlePanel")
    viewGo.transform.lossyScale = Vector3.New(1, 1, 1)
    viewGo.transform.position = Vector3.New(540, 960, 0)
    local tpl = NewGo("HelpHeroShow")
    local view = { gameObject = viewGo, transform = viewGo.transform, HelpHeroShow = tpl }
    BattleUltCard.ResetForBattle(view)
    BattleUltCard.Show(view, HERO, 0, "h")
    local s = BattleUltCard.slots[0]
    Check("兜底：卡片挂在面板下", s.go.parent == viewGo.transform)
    Check("兜底：给了 anchoredPosition", s.go.rt.anchoredPosition ~= nil)
    Check("兜底：卡片可见", s.go.activeSelf == true)
end

print("")
if failures == 0 then
    print("ALL PASS")
else
    print(failures .. " FAILED")
    os.exit(1)
end
