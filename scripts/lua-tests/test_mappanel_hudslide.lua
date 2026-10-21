-- 离线验证 MapPanel 的「HUD 环绕入场」（不依赖 Unity）：
-- 用假 Util / Vector2 / Vector3 / DOTween 跑真源码，覆盖
--   ① PlayHudSlideIn     可见容器按表顺序从各自那条边滑回原位
--   ② 方向               up=+y / down=-y / left=-x / right=+x（起点在屏幕外那侧）
--   ③ 缩放通道           自带 Animator(CommonButton) 的节点只写位置，不碰 scale
--   ④ 未激活容器         不参与（不占错开位、不动它）
--   ⑤ StopHudSlideIn     中途回收：Kill + 位置/缩放双复位
--   ⑥ 重播               从基准重新起，不叠加、不漂移
--   ⑦ OnShow 闸门        只有 OnOpen 之后那一次播；弹窗返回（只走 OnShow）不播
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_mappanel_hudslide.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Map/MapPanel.lua"

-- ---------------- stubs ----------------
local tweens = {}
local function newTween(tf, endv, dur, kind)
    local t = { tf = tf, endv = endv, dur = dur, kind = kind or "scale",
                delay = 0, ease = nil, onComplete = nil, killed = false }
    function t:SetDelay(d) self.delay = d; return self end
    function t:SetEase(e) self.ease = e; return self end
    function t:OnComplete(cb) self.onComplete = cb; return self end
    function t:Kill() self.killed = true end
    function t:Complete()
        if self.killed then return end
        if self.kind == "pos" then
            self.tf.anchoredPosition = self.endv
        else
            self.tf.localScale = self.endv
        end
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

local function newRect(name, active, hasAnimator, x, y)
    local o = { name = name, activeSelf = active ~= false,
                anchoredPosition = { x = x or 0, y = y or 0 },
                localScale = { x = 1, y = 1, z = 1 } }
    o.transform = o
    o.gameObject = o
    local anim = hasAnimator and { enabled = true } or nil
    function o:GetComponent(cls)
        if cls == "Animator" then return anim end
        if cls == "RectTransform" then return self end
        return nil
    end
    function o:SetActive(v) self.activeSelf = v end
    function o:DOScale(v, dur) return newTween(self, v, dur, "scale") end
    function o:DOAnchorPos(v, dur) return newTween(self, v, dur, "pos") end
    return o
end

-- 基准位置照抄 prefab（dump_prefab_tree --rect）：锚点不同，方向也不同
local basePos = {
    leftUp = { 0, -190 }, endLessTitle = { 0, -50 }, rightUp = { 446, -213 },
    leftCenter = { -80, 638 }, helpBtn = { -109.5, -255 }, rightDown = { -28, -1242 },
    centerDown = { 0, 0 }, btnJump = { 265, 420 }, btnAutoJian = { 265, 520 },
}
local nodes = {
    leftUp       = newRect("leftUp",       true,  false, 0,      -190),
    endLessTitle = newRect("endLessTitle", false, false, 0,      -50),   -- prefab 里未激活
    rightUp      = newRect("rightUp",      true,  false, 446,    -213),
    leftCenter   = newRect("leftCenter",   true,  false, -80,    638),
    helpBtn      = newRect("helpBtn",      true,  true,  -109.5, -255),  -- 自带 CommonButton
    rightDown    = newRect("rightDown",    true,  false, -28,    -1242),
    centerDown   = newRect("centerDown",   true,  false, 0,      0),
    btnJump      = newRect("btnJump",      true,  true,  265,    420),   -- 自带 CommonButton
    btnAutoJian  = newRect("btnAutoJian",  true,  true,  265,    520),   -- 自带 CommonButton
}
local visibleNames = { "leftUp", "rightUp", "leftCenter", "helpBtn",
                       "rightDown", "centerDown", "btnJump", "btnAutoJian" }
local offsets = { leftUp = { 0, 64 }, rightUp = { 96, 0 }, leftCenter = { -88, 0 },
                  helpBtn = { 88, 0 }, rightDown = { 96, 0 }, centerDown = { 0, -88 },
                  btnJump = { 0, -56 }, btnAutoJian = { 0, -56 } }
local animated = { helpBtn = true, btnJump = true, btnAutoJian = true }
-- 体量分档（与 MapPanel.lua 的 kHudWeight 对齐）：大件慢/起幅大，小按钮快/起幅小
local weight = { leftUp = "big", endLessTitle = "big", rightUp = "big", leftCenter = "big",
                 rightDown = "big", centerDown = "big",
                 helpBtn = "small", btnJump = "small", btnAutoJian = "small" }
local W = { big = { dur = 0.30, from = 0.90 }, mid = { dur = 0.26, from = 0.94 },
            small = { dur = 0.22, from = 0.96 } }

local root = { name = "MapPanel" }
root.transform = root
root.gameObject = root

Util = { GetGameObject = function(_, path) return nodes[path] end }
Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { one = { x = 1, y = 1, z = 1 }, zero = { x = 0, y = 0, z = 0 },
            New = function(x, y, z) return { x = x, y = y, z = z } end }
Ease = { Linear = "Linear", OutCubic = "OutCubic", InOutQuad = "InOutQuad", OutQuad = "OutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
function Inherit(base) return setmetatable({}, { __index = base }) end
BasePanel = {}
ConfigName = setmetatable({}, { __index = function(_, k) return k end })
ConfigManager = { GetConfig = function()
    return setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return 0 end }) end })
end }
local fake = setmetatable({}, { __index = function() return function() end end })
function require(_) return fake end

-- OnShow 用到的全局
CameraClearFlags = { Depth = 2 }
UIManager = { camera = {} }
SoundConfig = {}
SoundManager = { PlayMusic = function() end, PlayAmbient = function() end,
                 PauseAmbient = function() end }
CarBonTypeId = { TRIAL = 2, ENDLESS = 4 }
UIName = setmetatable({}, { __index = function(_, k) return k end })
MapManager = { curMapId = 1, curCarbonType = 2 }
EndLessMapManager = { GetLeftEnergy = function() end }
MapTrialManager = {}

-- ---------------- load ----------------
assert(loadfile(SRC))()
local Panel = MapPanel

Panel.gameObject = root
Panel.endLessTitle = nodes.endLessTitle
Panel.btnXingYao = newRect("btnXingYao", true)
Panel.btnBomb = newRect("btnBomb", true)
Panel.btnBuff = newRect("btnBuff", true)
Panel.btnShop = newRect("btnShop", true)
Panel.btnReset = newRect("btnReset", true)
Panel.btnFormat = newRect("btnFormat", true)
Panel.btnNode = newRect("btnNode", true)

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end
local function resetNodes()
    for name, n in pairs(nodes) do
        n.anchoredPosition = { x = basePos[name][1], y = basePos[name][2] }
        n.localScale = { x = 1, y = 1, z = 1 }
    end
end
resetNodes()

-- ---------------- case 1: 起点方向 + 缩放通道 ----------------
print("== case1 PlayHudSlideIn 起点 ==")
tweens = {}
local count = Panel:PlayHudSlideIn()
assert(count == #visibleNames, ("可见组数 %d != 应有 %d（endLessTitle 未激活不该算）")
    :format(count, #visibleNames))
for _, name in ipairs(visibleNames) do
    local n, off, b = nodes[name], offsets[name], basePos[name]
    assert(n.anchoredPosition.x == b[1] + off[1],
        ("%s 起点 x=%s，应为 %s"):format(name, n.anchoredPosition.x, b[1] + off[1]))
    assert(n.anchoredPosition.y == b[2] + off[2],
        ("%s 起点 y=%s，应为 %s"):format(name, n.anchoredPosition.y, b[2] + off[2]))
    if animated[name] then
        assert(n.localScale.x == 1, ("%s 自带 Animator，不该写 scale"):format(name))
    else
        local want = W[weight[name]].from
        assert(math.abs(n.localScale.x - want) < 1e-6,
            ("%s（%s）起始缩放应为 %s，实际 %s"):format(name, weight[name], want, n.localScale.x))
    end
end
assert(nodes.endLessTitle.anchoredPosition.y == -50, "未激活容器不该被移动")
assert(nodes.endLessTitle.localScale.x == 1, "未激活容器不该被缩放")
print(("  %d 组：位置各从自己那条边起、纯容器 %d 个 + 按钮 %d 个只写位置")
    :format(count, count - 3, 3))

-- ---------------- case 2: 错开顺序 ----------------
print("== case2 错开 ==")
local posTweens = {}
for _, t in ipairs(tweens) do
    if t.kind == "pos" then posTweens[#posTweens + 1] = t end
end
assert(#posTweens == #visibleNames, ("位置 tween 数 %d != %d"):format(#posTweens, #visibleNames))
local lastEnd = 0
for i, t in ipairs(posTweens) do
    local name = visibleNames[i]
    local wantDur = W[weight[name]].dur
    local want = (i - 1) * 0.05
    assert(math.abs(t.delay - want) < 1e-6, ("第 %d 组延迟 %s != %s"):format(i, t.delay, want))
    assert(t.dur == wantDur, ("%s 时长应为 %s，实际 %s"):format(name, wantDur, t.dur))
    assert(t.ease == Ease.OutCubic, "ease 应为 OutCubic")
    assert(t.tf.name == name, ("第 %d 组应绑 %s，实际 %s"):format(i, name, t.tf.name))
    lastEnd = math.max(lastEnd, t.delay + t.dur)
end
assert(lastEnd < 1.0, ("整批必须收在 1s 镜头缩放内，实际 %.2fs"):format(lastEnd))
assert(#tweens == #visibleNames + 5, ("tween 总数 %d != 位置 %d + 缩放 %d"):format(#tweens, #visibleNames, 5))
print(("  延迟 0 / %.2f / ... / %.2f，大件 %.2fs 小按钮 %.2fs，末组收在 %.2fs"):format(
    posTweens[2].delay, posTweens[#posTweens].delay, W.big.dur, W.small.dur, lastEnd))

-- ---------------- case 3: 完成后精确回基准 ----------------
print("== case3 完成复位 ==")
for _, t in ipairs(tweens) do t:Complete() end
for _, name in ipairs(visibleNames) do
    local n, b = nodes[name], basePos[name]
    assert(n.anchoredPosition.x == b[1] and n.anchoredPosition.y == b[2],
        ("%s 应精确回到 %s,%s，实际 %s,%s"):format(name, b[1], b[2], n.anchoredPosition.x, n.anchoredPosition.y))
    assert(n.localScale.x == 1, ("%s 缩放应回 1，实际 %s"):format(name, n.localScale.x))
end
print("  位置 / 缩放全部精确回基准")

-- ---------------- case 4: 中途 Stop 必须双复位 ----------------
print("== case4 StopHudSlideIn ==")
tweens = {}
Panel:PlayHudSlideIn()
Panel:StopHudSlideIn()
assert(liveTweens() == 0, "Stop 后不应有存活 tween，实际 " .. liveTweens())
for _, name in ipairs(visibleNames) do
    local n, b = nodes[name], basePos[name]
    assert(n.anchoredPosition.x == b[1] and n.anchoredPosition.y == b[2],
        ("%s Stop 后位置必须复位，实际 %s,%s"):format(name, n.anchoredPosition.x, n.anchoredPosition.y))
    assert(n.localScale.x == 1, ("%s Stop 后缩放必须复位（否则永久 0.94），实际 %s"):format(name, n.localScale.x))
end
print("  Kill + 位置/缩放双复位")

-- ---------------- case 5: 重播不叠加 ----------------
print("== case5 重播 ==")
tweens = {}
Panel:PlayHudSlideIn()             -- 第一轮起播（不 Complete，模拟停在中途）
Panel:PlayHudSlideIn()             -- 面板缓存复用后重播：基准必须仍取自"入场前"的 -190
assert(nodes.leftUp.anchoredPosition.y == -126, ("重播必须从基准 -190 +64 重起，实际 y=%s"):format(nodes.leftUp.anchoredPosition.y))
assert(math.abs(nodes.leftUp.localScale.x - W.big.from) < 1e-6,
    ("重播的起始缩放应为 %s（大件）"):format(W.big.from))
Panel:PlayHudSlideIn()
local livePos = 0
for _, t in ipairs(tweens) do if not t.killed and t.kind == "pos" then livePos = livePos + 1 end end
assert(livePos == #visibleNames, ("同一时刻只应有一套位置 tween，实际 %d"):format(livePos))
print("  从基准重起，旧的整套被 Kill，不叠加")

-- ---------------- case 6: OnShow 闸门（进图播一次，返回不播） ----------------
print("== case6 OnShow 闸门 ==")
tweens = {}
Panel.needHudAnim = true           -- OnOpen 置位
Panel:OnShow()
assert(#tweens > 0, "进图那次 OnShow 应播 HUD 入场")
assert(Panel.needHudAnim == false, "播完必须清标记")
local first = #tweens
tweens = {}
Panel:OnShow()                     -- 从弹窗返回：只有 OnShow，没有 OnOpen
assert(#tweens == 0, ("返回地图不该重播，实际起了 %d 条 tween"):format(#tweens))
print(("  进图播 %d 条，返回 0 条"):format(first))

-- ---------------- case 7: 空面板 / 找不到节点不抛错 ----------------
print("== case7 找不到节点 ==")
tweens = {}
nodes.leftCenter:SetActive(true)   -- OnShow 会把 leftCenter 关掉，这里复原
local saved = nodes.leftUp
nodes.leftUp = nil
local n2 = Panel:PlayHudSlideIn()
assert(n2 == #visibleNames - 1, ("缺一个节点应只播 %d 组，实际 %d"):format(#visibleNames - 1, n2))
nodes.leftUp = saved
Panel:StopHudSlideIn()
print("  缺节点跳过，不抛错")

print("ALL OK")
