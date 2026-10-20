-- 离线验证 MainRechargePanel 开启动画（不依赖 Unity）：
-- 用假 Util / TabBox 依赖 / Vector3 / Vector2 / DOTween 跑真源码 + 真 TabBox，覆盖
--   ① PlayTabFlipIn      页签按 GetTabList 顺序逐格翻入，跳过未激活
--   ② PlayTabSelectFlip  高亮板翻入，且被 animReady 闸门挡掉「初始化那次回调」
--   ③ PlayDropIn         内容区 content 从上往下落 110px
--   ④ StopOpenAnims      统一回收（Kill + 复位 + 恢复 Animator + 高亮板复位）
--   ⑤ 压缩错开           页签数多时整体跨度压到 0.5s
--   ⑥ 顺序约束           先 flip 再 drop（flip 内部会 Stop 掉一切）
--   ⑦ 生命周期           OnClose / OnDestroy 必须回收
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_mainshop_openanim.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Recharge/MainRechargePanel.lua"
local TABBOX = ROOT .. "Assets/ManagedResources/~Lua/Modules/Common/TabBox.lua"

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
    local o = { name = name, activeSelf = active ~= false, childCount = 0,
                localScale = { x = 1, y = 1, z = 1 }, anchoredPosition = { x = 0, y = 0 } }
    o.children = {}          -- 按名索引，供假 Util.GetGameObject 用
    o.order = {}             -- 按挂载顺序
    o.transform = o
    o.gameObject = o
    local anim = hasAnimator and { enabled = true } or nil
    o.anim = anim
    function o:GetComponent(cls)
        if cls == "Animator" then return anim end
        if cls == "RectTransform" then return self end
        return nil
    end
    function o:SetActive(v) self.activeSelf = v and true or false end
    function o:DOScale(v, dur) return newTween(self, v, dur, "scale") end
    function o:DOAnchorPos(v, dur) return newTween(self, v, dur, "pos") end
    function o.transform:GetChild(i) return self.order[i + 1] end
    o.transform.childCount = 0
    function o:AddChild(c)
        self.children[c.name] = c
        self.order[#self.order + 1] = c
        self.childCount = #self.order
        self.transform.childCount = self.childCount
    end
    return o
end

-- tabbox / tab（模板，激活态 1，但 TabBox:Init 会 SetActive(false)）/ box / content
local tabbox = newRect("tabbox", true, false)
local template = newRect("tab", true, true)      -- 模板：每个克隆体都挂 CommonButton 的 Animator
local box = newRect("box", true, false)
tabbox:AddChild(template)
tabbox:AddChild(box)
local content = newRect("content", true, false)

local function findChild(root, path)
    local cur = root
    for name in path:gmatch("[^/]+") do
        cur = cur.children and cur.children[name]
        if not cur then return nil end
    end
    return cur
end

Vector3 = { one = { x = 1, y = 1, z = 1 }, zero = { x = 0, y = 0, z = 0 },
    New = function(x, y, z) return { x = x, y = y, z = z } end }
Vector2 = { New = function(x, y) return { x = x, y = y } end }
Ease = { Linear = "Linear", InOutQuad = "InOutQuad", OutQuad = "OutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
LogRed = function() end
function Inherit(base) return setmetatable({}, { __index = base }) end

-- 真 TabBox 用到的三个入口
newObjToParent = function(tpl, parent)
    local c = newRect(tpl.name, tpl.activeSelf, tpl.anim ~= nil)
    c:AddChild(newRect("Select", true, false))     -- 高亮板：没有 Animator
    c:AddChild(newRect("UnSelect", true, false))
    c:AddChild(newRect("redpot", false, false))
    c:AddChild(newRect("lock", false, false))
    parent:AddChild(c)
    return c
end
Util = {
    GetGameObject = function(root, path)
        if path == "content" then return content end
        local base = (type(root) == "table" and root.transform) or root
        return findChild(base, path)
    end,
    ClearChild = function(t) t.order = {}; t.children = {}; t.childCount = 0 end,
    AddClick = function() end,
    AddOnceClick = function() end,
    LoadSprite = function() return nil end,
    LogError = LogError,
}
SubUIManager = { Open = function() return { OnShow = function() end } end,
                 Close = function() end }
SubUIConfig = { PlayerHeadFrameView = 1, UpView = 2, BtView = 3 }
SoundManager = { PlayMusic = function() end }
SoundConfig = { BGM_Shop = 1, Sound_UICancel = 2 }
JumpManager = { GoJump = function() end }
RedPointType = { Shop_Page_Recharge = 1, VipPanel = 2, DailyGift = 3 }
GetLanguageStrById = function() return "" end
SHOP_TYPE = { VIP_GIFT = 1 }
DirectBuyType = { DAILY_GIFT = 1, FINDTREASURE_GIFT = 2 }
RECHARGEABLE = true
CheckRedPointStatus = function() end
BindRedPointObject = function() end
ClearRedPointObject = function() end
PopupTipPanel = { ShowTip = function() end }
PlaySoundWithoutClick = function() end

local fakeModule = setmetatable({
    new = function() return { gameObject = newRect("page", true), OnShow = function() end,
                              OnHide = function() end, OnDestroy = function() end,
                              AddListener = function() end, RemoveListener = function() end } end,
    New = function() return { gameObject = newRect("page", true), OnShow = function() end,
                              OnHide = function() end, OnDestroy = function() end,
                              AddListener = function() end, RemoveListener = function() end } end,
}, { __index = function() return function() end end })

local realRequire = require
function require(path)
    if path == "Base/BasePanel" then return {} end
    if path == "Modules/Common/TabBox" then
        local chunk = assert(loadfile(TABBOX))
        return chunk()
    end
    return fakeModule
end

-- ---------------- load ----------------
local chunk = assert(loadfile(SRC))
local Panel = chunk()

-- 真机上由 InitComponent / BindEvent 赋值，这里手工注入
Panel.gameObject = newRect("MainRechargePanel")
Panel.content = content
Panel.PageTabCtrl = require("Modules/Common/TabBox").New()
Panel.PageTabCtrl:SetTabIsLockCheck(function() return false end)

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- TabBox:Init 会克隆页签（真机在 OnOpen 里调，只调一次）
Panel.PageTabCtrl:Init(tabbox, { {}, {}, {}, {} })
local tabs = Panel.PageTabCtrl:GetTabList()
assert(#tabs == 4, "应克隆 4 个页签，实际 " .. #tabs)
assert(template.activeSelf == false, "模板 tab 必须被 TabBox 藏起来")

-- ---------------- case 1: 打开时逐格翻入 ----------------
print("== case1 PlayTabFlipIn ==")
tweens = {}
Panel:PlayTabFlipIn()
assert(#tweens == 4, "应有 4 条翻入 tween，实际 " .. #tweens)
assert(template.localScale.x == 1, "模板 tab 不该被动")
for i, go in ipairs(tabs) do
    assert(go.localScale.x == 0, "页签应置 0: " .. go.name .. i)
    assert(go.anim.enabled == false, "翻入期间应关掉 CommonButton 的 Animator: " .. i)
end
for i, t in ipairs(tweens) do
    local want = (i - 1) * 0.033
    assert(math.abs(t.delay - want) < 1e-6, ("第 %d 个延迟 %s != %s"):format(i, t.delay, want))
    assert(t.dur == 0.167, "时长应为 0.167")
    assert(t.ease == Ease.OutQuad, "ease 应为 OutQuad")
    assert(t.tf == tabs[i], "tween 应按 GetTabList 顺序绑定")
end
print(("  4 格，延迟 0 / %.3f / %.3f / %.3f"):format(tweens[2].delay, tweens[3].delay, tweens[4].delay))

for _, t in ipairs(tweens) do t:Complete() end
for i, go in ipairs(tabs) do
    assert(go.localScale.x == 1, "结束后 scale 应回 1: " .. i)
    assert(go.anim.enabled == true, "结束后 Animator 应恢复: " .. i)
end
print("  全部完成后 scale=1 / Animator 已恢复")

-- ---------------- case 2: 中途 StopOpenAnims 必须回滚 ----------------
print("== case2 StopOpenAnims ==")
tweens = {}
Panel:PlayTabFlipIn()
Panel:PlayDropIn()
Panel:StopOpenAnims()
for i, go in ipairs(tabs) do
    assert(go.localScale.x == 1, "Stop 后 scale 应为 1: " .. i)
    assert(go.anim.enabled == true, "Stop 后 Animator 应恢复: " .. i)
end
assert(content.anchoredPosition.y == 0, "Stop 后内容区必须复位到 0")
assert(liveTweens() == 0, "Stop 后不应有存活 tween，实际 " .. liveTweens())
print("  全部 Kill + scale/Animator/落位复位")

-- ---------------- case 3: 页签多时压缩错开 ----------------
print("== case3 压缩错开 ==")
tweens = {}
local saved = Panel.PageTabCtrl
Panel.PageTabCtrl = { GetTabList = function()
    local list = {}
    for i = 1, 24 do list[i] = newRect("tab" .. i, true, true) end
    return list
end }
Panel:PlayTabFlipIn()
local last = tweens[#tweens]
assert(#tweens == 24, "应有 24 条，实际 " .. #tweens)
assert(math.abs(last.delay - 0.5) < 1e-6, ("24 格时末格延迟应压到 0.5，实际 %s"):format(last.delay))
print(("  24 格：首格 0 / 末格 %.3f / 含单格总时长 %.3f"):format(last.delay, last.delay + last.dur))
Panel:StopOpenAnims()
Panel.PageTabCtrl = saved
tweens = {}

-- ---------------- case 4: 高亮板 + animReady 闸门 ----------------
print("== case4 PlayTabSelectFlip ==")
tweens = {}
-- 未起过开启动画（TabBox:Init 那次回调）⇒ 不该翻
Panel:PlayTabSelectFlip(1)
assert(#tweens == 0, "animReady=false 时不该创建 tween，实际 " .. #tweens)
print("  闸门：初始化那次回调被挡掉")

Panel:PlayDropIn()
tweens = {}
Panel:PlayTabSelectFlip(2)
assert(#tweens == 1, "应创建一条高亮 tween，实际 " .. #tweens)
local sel = Util.GetGameObject(tabs[2], "Select")
assert(sel.localScale.x == 0, "高亮板应从 0 起")
assert(tweens[1].dur == 0.167, "高亮时长应为 0.167")
assert(tweens[1].ease == Ease.OutQuad, "ease 应为 OutQuad")
tweens[1]:Complete()
assert(sel.localScale.x == 1, "高亮板应回到 1")
Panel:PlayTabSelectFlip(3)
assert(tweens[1].killed == true, "重播前应 Kill 上一个")
print("  高亮板翻入 + 重播 Kill 正常")

-- ---------------- case 5: 中途 Stop 必须复位高亮板 ----------------
print("== case5 高亮板中途 Stop ==")
tweens = {}
local sel3 = Util.GetGameObject(tabs[3], "Select")
Panel:PlayTabSelectFlip(3)
assert(sel3.localScale.x == 0, "应从 0 起")
Panel:StopOpenAnims()
assert(sel3.localScale.x == 1, "Kill 后必须复位到 1，否则那块板永久停在半截")
print("  Kill + 复位到 1")

-- ---------------- case 6: 内容区从上往下落 110px ----------------
print("== case6 PlayDropIn ==")
tweens = {}
content.anchoredPosition = { x = 0, y = 0 }
Panel:PlayDropIn()
assert(#tweens == 1, "应创建一条落位 tween，实际 " .. #tweens)
local dt = tweens[1]
assert(content.anchoredPosition.y == 110, "起点应在 +110，实际 " .. content.anchoredPosition.y)
assert(dt.endv.y == 0 and dt.endv.x == 0, "终点应回 (0,0)")
assert(math.abs(dt.dur - 0.3667) < 1e-6, "时长应为 0.3667，实际 " .. dt.dur)
assert(dt.ease == Ease.InOutQuad, "ease 应为 InOutQuad（参考两端切线都是 0）")
dt:Complete()
assert(content.anchoredPosition.y == 0, "完成后应精确落在 0")
print("  +110 -> 0，0.3667s，InOutQuad")

-- ---------------- case 7: 落位中途 Stop / 重播不叠加 ----------------
print("== case7 落位 Stop 与重播 ==")
tweens = {}
content.anchoredPosition = { x = 0, y = 0 }
Panel:PlayDropIn()
Panel:StopDropIn()
assert(tweens[1].killed == true, "Stop 应 Kill 落位 tween")
assert(content.anchoredPosition.y == 0, "Stop 后必须复位到 0，否则永久停在半空")

tweens = {}
content.anchoredPosition = { x = 0, y = 45 }   -- 模拟上一轮停在中途
Panel:PlayDropIn()
assert(content.anchoredPosition.y == 110, "重播必须从 110 重新起，不能接在 45 上")
Panel:PlayDropIn()
assert(liveTweens() == 1, "同一时刻只应有一条落位 tween，实际 " .. liveTweens())
print("  Kill + 复位；重播从 110 重起且只有 1 条存活")

-- ---------------- case 8: 顺序约束 —— 先 flip 再 drop ----------------
print("== case8 顺序约束 ==")
tweens = {}
content.anchoredPosition = { x = 0, y = 0 }
Panel:PlayDropIn()
local dropTween = tweens[1]
Panel:PlayTabFlipIn()                      -- 先 drop 再 flip ⇒ drop 被杀
assert(dropTween.killed == true, "flip 内部 Stop 必须回收先起的落位 tween")
assert(content.anchoredPosition.y == 0, "被回收的落位要复位")

tweens = {}
content.anchoredPosition = { x = 0, y = 0 }
Panel:PlayTabFlipIn()
Panel:PlayDropIn()                         -- 正确顺序：flip 先，drop 后
assert(liveTweens() > 1, "正确顺序下 flip 与 drop 应同时存活")
assert(content.anchoredPosition.y == 110, "drop 起点应为 110")
print(("  反序会被杀；正序并存（%d 条存活）"):format(liveTweens()))

-- ---------------- case 9: OnClose / OnDestroy 必须回收 ----------------
print("== case9 生命周期 ==")
tweens = {}
Panel:PlayTabFlipIn()
Panel:PlayDropIn()
Panel:PlayTabSelectFlip(2)
Panel._CurPageIndex = nil                 -- 跳过页隐藏分支，只验证动画回收
Panel.PageList = {}
Panel:OnClose()
assert(liveTweens() == 0, "OnClose 后不应有存活 tween，实际 " .. liveTweens())
for i, go in ipairs(tabs) do
    assert(go.localScale.x == 1, "OnClose 后 scale 应为 1: " .. i)
    assert(go.anim.enabled == true, "OnClose 后 Animator 应恢复: " .. i)
end
assert(content.anchoredPosition.y == 0, "OnClose 后内容区应复位")

tweens = {}
Panel:PlayTabFlipIn()
Panel:PlayDropIn()
Panel:OnDestroy()
assert(liveTweens() == 0, "OnDestroy 后不应有存活 tween，实际 " .. liveTweens())
assert(content.anchoredPosition.y == 0, "OnDestroy 后内容区应复位")
print("  OnClose / OnDestroy 都回收到位")

print("ALL OK")
