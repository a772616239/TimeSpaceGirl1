-- 离线验证 OperatingPanel 开启动画（不依赖 Unity）：
-- 用假 Util / Vector3 / Vector2 / DOTween 跑真源码，覆盖
--   ① PlayTabFlipIn      可见页签按 sibling 顺序逐格翻入（跳过未激活）
--   ② PlayTabSelectFlip  高亮板翻入
--   ③ PlayPageDropIn     内容区 bg/pageContent 从上往下落 110px
--   ④ StopOpenAnims      统一回收（Kill + 复位 + 恢复 Animator）
--   ⑤ 顺序约束           先 flip 再 drop（flip 内部会 Stop 掉一切）
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_operating_openanim.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Operating/OperatingPanel.lua"

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

local function newRect(name, active, hasAnimator)
    local o = { name = name, activeSelf = active ~= false, children = {},
                localScale = { x = 1, y = 1, z = 1 }, anchoredPosition = { x = 0, y = 0 } }
    o.transform = o
    o.gameObject = o
    local anim = hasAnimator and { enabled = true } or nil
    o.anim = anim
    function o:GetComponent(cls)
        if cls == "Animator" then return anim end
        if cls == "RectTransform" then return self end
        return nil
    end
    function o:DOScale(v, dur) return newTween(self, v, dur, "scale") end
    function o:DOAnchorPos(v, dur) return newTween(self, v, dur, "pos") end
    return o
end

local function newContent(specs)
    local c = newRect("tabsContent", true, false)
    for _, s in ipairs(specs) do
        c.children[#c.children + 1] = newRect(s[1], s[2], s[3])
    end
    c.transform.childCount = #c.children
    function c.transform:GetChild(i) return self.children[i + 1] end
    return c
end

-- 真实 prefab 里 tabsContent 的 sibling 顺序就是 12,5,11,1,9,4,13,10,2,3,...（不是 1..19），
-- 这里故意保持乱序：动画顺序必须跟「版面顺序」一致，而不是 tabs_N 的下标。
local content = newContent({
    { "tabs_12", true, true }, { "tabs_5", true, true }, { "tabs_11", true, true },
    { "tabs_1", true, true }, { "tabs_9", false, true }, { "tabs_4", true, true },
    { "tabs_13", true, true }, { "tabs_10", true, true }, { "tabs_2", true, true },
    { "tabs_3", true, true }, { "tabs_7", true, true }, { "tabs_8", true, true },
    { "tabs_6", false, true }, { "tabs_14", true, true }, { "tabs_15", true, true },
})
local pageContent = newRect("pageContent", true, false)

Vector3 = { one = { x = 1, y = 1, z = 1 }, zero = { x = 0, y = 0, z = 0 },
    New = function(x, y, z) return { x = x, y = y, z = z } end }
Vector2 = { New = function(x, y) return { x = x, y = y } end }
Ease = { Linear = "Linear", InOutQuad = "InOutQuad", OutQuad = "OutQuad" }
Util = { GetGameObject = function(_, path)
    if path == "bg/pageContent" then return pageContent end
    return content
end }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
LogRed = function() end
function Inherit(base) return setmetatable({}, { __index = base }) end
BasePanel = {}
local fakePage = setmetatable({
    new = function() return { gameObject = newRect("page", true), OnShow = function() end,
                              OnHide = function() end } end,
    New = function() return { gameObject = newRect("page", true), OnShow = function() end,
                              OnHide = function() end } end,
}, { __index = function() return function() end end })
function require(_) return fakePage end

-- ---------------- load ----------------
local chunk = assert(loadfile(SRC))
chunk()
local Panel = OperatingPanel

-- 真机上这两样由 InitComponent 赋值；这里手工注入
Panel.gameObject = newRect("OperatingPanel")
Panel.tabsContent = content
Panel.selectTabs = {}
for i = 1, 19 do Panel.selectTabs[i] = newRect("selected" .. i, true, false) end

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- ---------------- case 1: 打开时按版面顺序逐格翻入 ----------------
print("== case1 PlayTabFlipIn ==")
Panel:PlayTabFlipIn()
local visible = {}
for _, n in ipairs(content.children) do
    if n.activeSelf then visible[#visible + 1] = n end
end
assert(#tweens == #visible, ("tween 数 %d != 可见页签 %d"):format(#tweens, #visible))
for _, n in ipairs(content.children) do
    if not n.activeSelf then
        assert(n.localScale.x == 1, "未激活页签不该被动: " .. n.name)
        assert(n.anim.enabled == true, "未激活页签的 Animator 不该被关: " .. n.name)
    else
        assert(n.localScale.x == 0, "可见页签应置 0: " .. n.name)
        assert(n.anim.enabled == false, "翻入期间应关掉 CommonButton 的 Animator: " .. n.name)
    end
end
for i, t in ipairs(tweens) do
    local want = (i - 1) * 0.033
    assert(math.abs(t.delay - want) < 1e-6, ("第 %d 个延迟 %s != %s"):format(i, t.delay, want))
    assert(t.dur == 0.167, "时长应为 0.167")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
    assert(t.tf.name == visible[i].name, ("第 %d 个 tween 应绑定 %s，实际 %s")
        :format(i, visible[i].name, t.tf.name))
end
print(("  %d/%d 格，顺序 %s → %s，延迟 0 / %.3f / ... / %.3f"):format(
    #tweens, #content.children, tweens[1].tf.name, tweens[#tweens].tf.name,
    tweens[2].delay, tweens[#tweens].delay))

for _, t in ipairs(tweens) do t:Complete() end
for _, n in ipairs(visible) do
    assert(n.localScale.x == 1, "结束后 scale 应回 1: " .. n.name)
    assert(n.anim.enabled == true, "结束后 Animator 应恢复: " .. n.name)
end
print("  全部完成后 scale=1 / Animator 已恢复")

-- ---------------- case 2: 中途 StopOpenAnims 必须回滚 ----------------
print("== case2 StopOpenAnims ==")
tweens = {}
Panel:PlayTabFlipIn()
Panel:PlayPageDropIn()
Panel:StopOpenAnims()
for _, n in ipairs(content.children) do
    assert(n.localScale.x == 1, "Stop 后 scale 应为 1: " .. n.name)
    assert(n.anim.enabled == true, "Stop 后 Animator 应恢复: " .. n.name)
end
assert(pageContent.anchoredPosition.y == 0, "Stop 后内容区必须复位到 0")
assert(liveTweens() == 0, "Stop 后不应有存活 tween，实际 " .. liveTweens())
print("  全部 Kill + scale/Animator/落位复位")

-- ---------------- case 3: 可见页签多时压缩错开 ----------------
print("== case3 压缩错开 ==")
tweens = {}
local big = newContent({})
for i = 1, 24 do big.children[i] = newRect("tabs_" .. i, true, true) end
big.transform.childCount = #big.children
Panel.tabsContent = big
Panel:PlayTabFlipIn()
local last = tweens[#tweens]
assert(math.abs(last.delay - 0.5) < 1e-6, ("24 格时末格延迟应压到 0.5，实际 %s"):format(last.delay))
print(("  24 格：首格 0 / 末格 %.3f / 含单格总时长 %.3f"):format(last.delay, last.delay + last.dur))
Panel.tabsContent = content
tweens = {}

-- ---------------- case 4: 高亮板翻入 ----------------
print("== case4 PlayTabSelectFlip ==")
tweens = {}
local sel = newRect("selected", true, false)
Panel.selectTabs[7] = sel
Panel:PlayTabSelectFlip(7)
assert(#tweens == 1, "应创建一个高亮 tween")
assert(sel.localScale.x == 0, "高亮板应从 0 起")
assert(tweens[1].dur == 0.167, "高亮时长应为 0.167")
tweens[1]:Complete()
assert(sel.localScale.x == 1, "高亮板应回到 1")
Panel:PlayTabSelectFlip(7)
assert(tweens[1].killed == true, "重播前应 Kill 上一个")
print("  高亮板翻入 + 重播 Kill 正常")

-- ---------------- case 5: 内容区从上往下落 110px ----------------
print("== case5 PlayPageDropIn ==")
tweens = {}
pageContent.anchoredPosition = { x = 0, y = 0 }
Panel:PlayPageDropIn()
assert(#tweens == 1, "应创建一条落位 tween，实际 " .. #tweens)
local dt = tweens[1]
assert(pageContent.anchoredPosition.y == 110, "起点应在 +110，实际 " .. pageContent.anchoredPosition.y)
assert(dt.endv.y == 0 and dt.endv.x == 0, "终点应回 (0,0)")
assert(math.abs(dt.dur - 0.3667) < 1e-6, "时长应为 0.3667，实际 " .. dt.dur)
assert(dt.ease == Ease.InOutQuad, "ease 应为 InOutQuad（参考两端切线都是 0）")
dt:Complete()
assert(pageContent.anchoredPosition.y == 0, "完成后应精确落在 0")
print("  +110 -> 0，0.3667s，InOutQuad")

-- ---------------- case 6: 落位中途 Stop 必须复位 ----------------
print("== case6 落位中途 Stop ==")
tweens = {}
pageContent.anchoredPosition = { x = 0, y = 0 }
Panel:PlayPageDropIn()
Panel:StopPageDropIn()
assert(tweens[1].killed == true, "Stop 应 Kill 落位 tween")
assert(pageContent.anchoredPosition.y == 0, "Stop 后必须复位到 0，否则永久停在半空")
print("  Kill + 复位到 0")

-- ---------------- case 7: 重播（面板缓存复用）不能叠加 ----------------
print("== case7 重播 ==")
tweens = {}
pageContent.anchoredPosition = { x = 0, y = 45 }   -- 模拟上一轮停在中途
Panel:PlayPageDropIn()
assert(pageContent.anchoredPosition.y == 110, "重播必须从 110 重新起，不能接在 45 上")
Panel:PlayPageDropIn()
assert(liveTweens() == 1, "同一时刻只应有一条落位 tween，实际 " .. liveTweens())
print("  从 110 重起，且只有 1 条存活")

-- ---------------- case 8: 顺序约束 —— 先 flip 再 drop ----------------
-- PlayTabFlipIn 第一行会 StopOpenAnims（内含 StopPageDropIn）。如果 OnShow 里先 drop 再 flip，
-- 落位会被立刻杀掉（现象：页签翻了、内容不动）。这里把这条约束钉成断言。
print("== case8 顺序约束 ==")
tweens = {}
pageContent.anchoredPosition = { x = 0, y = 0 }
Panel:PlayPageDropIn()
assert(liveTweens() == 1, "drop 应已起")
local dropTween = tweens[1]
Panel:PlayTabFlipIn()                      -- 先 drop 再 flip ⇒ drop 被杀
assert(dropTween.killed == true, "flip 内部 Stop 必须回收先起的落位 tween")
assert(pageContent.anchoredPosition.y == 0, "被回收的落位要复位")

tweens = {}
pageContent.anchoredPosition = { x = 0, y = 0 }
Panel:PlayTabFlipIn()
Panel:PlayPageDropIn()                     -- 正确顺序：flip 先，drop 后
assert(liveTweens() > 1, "正确顺序下 flip 与 drop 应同时存活")
assert(pageContent.anchoredPosition.y == 110, "drop 起点应为 110")
print(("  反序会被杀（%d 条存活）；正序并存（%d 条存活）"):format(1, liveTweens()))

print("ALL OK")
