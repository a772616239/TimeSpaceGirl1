-- 离线验证 ExpertPanel 开启动画（不依赖 Unity）：
-- 用假 Util / Vector3 / Vector2 / DOTween 跑真源码，覆盖
--   ① PlayTabFlipIn   页签逐格翻入
--   ② PlayTabSelectFlip 高亮板翻入
--   ③ PlayDropIn      内容区从上往下落 110px
--   ④ StopOpenAnims   统一回收（Kill + 复位）
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_expert_openanim.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Expert/ExpertPanel.lua"

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
        if cls == "RectTransform" then return self end   -- downLayout 走这条
        return nil
    end
    function o:DOScale(v, dur) return newTween(self, v, dur, "scale") end
    function o:DOAnchorPos(v, dur) return newTween(self, v, dur, "pos") end
    return o
end

local content = newRect("tabsContent", true, false)
local specs = {
    { "tabs_2", true, true }, { "tabs_1", true, true }, { "btn", true, true },
    { "tabs_3", false, true }, { "tabs_4", true, true }, { "tabs_5", true, false },
}
for _, s in ipairs(specs) do
    content.children[#content.children + 1] = newRect(s[1], s[2], s[3])
end
content.transform.childCount = #content.children
function content.transform:GetChild(i) return self.children[i + 1] end

local downLayout = newRect("downLayout", true, false)
local target = content   -- PlayTabFlipIn 里 GetGameObject(...,"tabs/viewPort/tabsContent") 拿到它

Vector3 = { one = { x = 1, y = 1, z = 1 }, zero = { x = 0, y = 0, z = 0 },
    New = function(x, y, z) return { x = x, y = y, z = z } end }
Vector2 = { New = function(x, y) return { x = x, y = y } end }
Ease = { Linear = "Linear", InOutQuad = "InOutQuad", OutQuad = "OutQuad" }
ConfigName = setmetatable({}, { __index = function() return "cfg" end })
ConfigManager = { GetConfig = function() return {} end, TryGetConfigDataByKey = function() return nil end }
ActivityTypeDef = setmetatable({}, { __index = function() return 0 end })
Util = { GetGameObject = function(_, path)
    if path == "downLayout" then return downLayout end
    return target
end }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
LogRed = function() end
function Inherit(base) return setmetatable({}, { __index = base }) end
BasePanel = {}
function require(name)
    return setmetatable({ new = function() return { gameObject = newRect(name, true), OnShow = function() end } end },
        { __index = function() return function() end end })
end

-- ---------------- load ----------------
local chunk = assert(loadfile(SRC))
chunk()
local Panel = ExpertPanel

-- ---------------- case 1: 打开时逐格翻入 ----------------
print("== case1 PlayTabFlipIn ==")
Panel.PlayTabFlipIn()
local started = {}
for _, n in ipairs(content.children) do
    if n.name ~= "btn" and n.activeSelf then started[#started + 1] = n end
end
assert(#tweens == #started, ("tween 数 %d != 可见页签 %d"):format(#tweens, #started))
for _, n in ipairs(content.children) do
    if n.name == "btn" then
        assert(n.localScale.x == 1, "模板 btn 不该被动")
    elseif not n.activeSelf then
        assert(n.localScale.x == 1, "未激活页签不该被动: " .. n.name)
    else
        assert(n.localScale.x == 0, "可见页签应置 0: " .. n.name)
        if n.anim then assert(n.anim.enabled == false, "翻入期间应关掉 Animator: " .. n.name) end
    end
end
for i, t in ipairs(tweens) do
    local want = (i - 1) * 0.033
    assert(math.abs(t.delay - want) < 1e-6, ("第 %d 个延迟 %s != %s"):format(i, t.delay, want))
    assert(t.dur == 0.167, "时长应为 0.167")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
end
print(("  %d 格，延迟 0 / %.3f / ... / %.3f"):format(#tweens, tweens[2].delay, tweens[#tweens].delay))

for _, t in ipairs(tweens) do t:Complete() end
for _, n in ipairs(started) do
    assert(n.localScale.x == 1, "结束后 scale 应回 1: " .. n.name)
    if n.anim then assert(n.anim.enabled == true, "结束后 Animator 应恢复: " .. n.name) end
end
print("  全部完成后 scale=1 / Animator 已恢复")

-- ---------------- case 2: 中途 StopOpenAnims 必须回滚 ----------------
print("== case2 StopOpenAnims ==")
tweens = {}
Panel.PlayTabFlipIn()
Panel.StopOpenAnims()
for _, n in ipairs(content.children) do
    assert(n.localScale.x == 1, "Stop 后 scale 应为 1: " .. n.name)
    if n.anim then assert(n.anim.enabled == true, "Stop 后 Animator 应恢复: " .. n.name) end
end
local killed = 0
for _, t in ipairs(tweens) do if t.killed then killed = killed + 1 end end
assert(killed == #tweens, "Stop 应 Kill 掉全部 tween")
print(("  已 Kill %d 个 tween 并恢复 %d 个节点"):format(killed, #content.children))

-- ---------------- case 3: 可见页签多时压缩错开 ----------------
print("== case3 压缩错开 ==")
tweens = {}
local big = newRect("tabsContent", true, false)
for i = 1, 24 do big.children[i] = newRect("tab" .. i, true, true) end
big.transform.childCount = #big.children
function big.transform:GetChild(i) return self.children[i + 1] end
target = big
Panel.PlayTabFlipIn()
local last = tweens[#tweens]
assert(math.abs(last.delay - 0.5) < 1e-6, ("24 格时末格延迟应压到 0.5，实际 %s"):format(last.delay))
print(("  24 格：首格 0 / 末格 %.3f / 总时长 %.3f"):format(last.delay, last.delay + last.dur))

-- ---------------- case 4: 高亮板翻入 ----------------
print("== case4 PlayTabSelectFlip ==")
tweens = {}
local sel = newRect("selected", true, false)
for i = 1, 20 do
    local name, val = debug.getupvalue(Panel.PlayTabSelectFlip, i)
    if not name then break end
    if name == "tabSelectBtns" and type(val) == "table" then val[7] = sel end
end
Panel.PlayTabSelectFlip(7)
assert(#tweens == 1, "应创建一个高亮 tween")
assert(sel.localScale.x == 0, "高亮板应从 0 起")
assert(tweens[1].dur == 0.167, "高亮时长应为 0.167")
tweens[1]:Complete()
assert(sel.localScale.x == 1, "高亮板应回到 1")
Panel.PlayTabSelectFlip(7)
assert(tweens[1].killed == true, "重播前应 Kill 上一个")
print("  高亮板翻入 + 重播 Kill 正常")

-- ---------------- case 5: 内容区从上往下落 110px ----------------
print("== case5 PlayDropIn ==")
tweens = {}
downLayout.anchoredPosition = { x = 0, y = 0 }
Panel.PlayDropIn()
assert(#tweens == 1, "应创建一条落位 tween，实际 " .. #tweens)
local dt = tweens[1]
assert(downLayout.anchoredPosition.y == 110, "起点应在 +110，实际 " .. downLayout.anchoredPosition.y)
assert(dt.endv.y == 0 and dt.endv.x == 0, "终点应回 (0,0)")
assert(math.abs(dt.dur - 0.3667) < 1e-6, "时长应为 0.3667，实际 " .. dt.dur)
assert(dt.ease == Ease.InOutQuad, "ease 应为 InOutQuad（参考两端切线都是 0）")
dt:Complete()
assert(downLayout.anchoredPosition.y == 0, "完成后应精确落在 0")
print("  +110 -> 0，0.3667s，InOutQuad")

-- ---------------- case 6: 落位中途 StopOpenAnims 必须复位 ----------------
print("== case6 落位中途 Stop ==")
tweens = {}
downLayout.anchoredPosition = { x = 0, y = 0 }
Panel.PlayDropIn()
Panel.StopOpenAnims()
assert(tweens[1].killed == true, "Stop 应 Kill 落位 tween")
assert(downLayout.anchoredPosition.y == 0, "Stop 后必须复位到 0，否则永久停在半空")
print("  Kill + 复位到 0")

-- ---------------- case 7: 重播（面板缓存复用）不能叠加 ----------------
print("== case7 重播 ==")
tweens = {}
downLayout.anchoredPosition = { x = 0, y = 45 }   -- 模拟上一轮停在中途
Panel.PlayDropIn()
assert(downLayout.anchoredPosition.y == 110, "重播必须从 110 重新起，不能接在 45 上")
Panel.PlayDropIn()
local alive = 0
for _, t in ipairs(tweens) do if not t.killed then alive = alive + 1 end end
assert(alive == 1, "同一时刻只应有一条落位 tween，实际 " .. alive)
print("  从 110 重起，且只有 1 条存活")

print("ALL OK")
