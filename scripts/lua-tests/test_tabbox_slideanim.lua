-- 离线验证 TabBox 的「页签选中底板滑动动画」（不依赖 Unity）：
-- 用假 Util / DOTween / GameObject + **真 TabBox**（真克隆流程）跑真源码，覆盖
--   ① opt-in 闸门     默认 ChangeTab 不产生任何 tween（其他 60+ 面板零影响）
--   ② 打开后滑动      ChangeTab 克隆新 select 做滑块，从旧 tab 位置 tween 到新 tab 位置
--                     期间新 select 被隐藏、旧 select 已按 adapter 置 default
--   ③ 克隆体射线      克隆体上所有 Image/Text 的 raycastTarget 必须被关掉（不挡页签点击）
--   ④ 完成还原        OnComplete 后新 select 复显、克隆体被 Destroy、无存活 tween
--   ⑤ 连点防叠播      动画中再切页签：上一条 tween 被 Kill、旧克隆体被销毁，最终态正确
--   ⑥ KillTabSlide    finish=false 只回收不显示（面板关闭语义）；finish=true 复显选中态
--   ⑦ 重入安全        动画中重新 Init（面板 OnShow 重开）：旧 tween/克隆体被回收，无报错
--   ⑧ 同位护栏        新旧 tab x 相同时不建 tween
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_tabbox_slideanim.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local TABBOX = ROOT .. "Assets/ManagedResources/~Lua/Modules/Common/TabBox.lua"

-- ---------------- stubs ----------------
local tweens = {}
local function newTween(getter, setter, endv, dur)
    local t = { getter = getter, setter = setter, endv = endv, dur = dur,
                ease = nil, onComplete = nil, killed = false }
    function t:SetEase(e) self.ease = e; return self end
    function t:OnComplete(cb) self.onComplete = cb; return self end
    function t:Kill() self.killed = true end
    function t:Complete()
        if self.killed then return end
        self.setter(self.endv)
        self.killed = true -- 对齐真 DOTween：自然完成的 tween 不再算存活
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- 简化 RectTransform/GameObject 三合一桩：position/localPosition 可写，
-- InverseTransformPoint = 世界坐标减父节点世界坐标（足以覆盖滑块位移计算）
local function newRect(name, active)
    local o = { name = name, activeSelf = active ~= false, childCount = 0,
                position = { x = 0, y = 0, z = 0 },
                localPosition = { x = 0, y = 0, z = 0 },
                localScale = { x = 1, y = 1, z = 1 },
                parent = nil, children = {}, order = {}, graphics = {},
                destroyed = false }
    o.transform = o
    o.gameObject = o
    function o:SetActive(v) self.activeSelf = v and true or false end
    function o:AddChild(c)
        c.parent = self
        self.children[c.name] = c
        self.order[#self.order + 1] = c
        self.childCount = #self.order
        return c
    end
    function o:RemoveChild(c)
        for k, v in pairs(self.children) do
            if v == c then self.children[k] = nil end
        end
        for i, v in ipairs(self.order) do
            if v == c then table.remove(self.order, i) break end
        end
        self.childCount = #self.order
    end
    function o:Find(path)
        local cur = self
        for n in path:gmatch("[^/]+") do
            cur = cur.children[n]
            if not cur then return nil end
        end
        return cur
    end
    function o:GetChild(i) return self.order[i + 1] end
    function o:SetParent(p)
        if self.parent then self.parent:RemoveChild(self) end
        p:AddChild(self)
    end
    function o:InverseTransformPoint(wp)
        local pw = self.parent and self.parent.position or { x = 0, y = 0, z = 0 }
        return { x = wp.x - pw.x, y = wp.y - pw.y, z = wp.z - pw.z }
    end
    function o:GetComponent(cls) return self.graphics[cls] end
    function o:GetComponentsInChildren(cls, includeInactive)
        local out = { Length = 0 }
        local function walk(node)
            local g = node.graphics[cls]
            if g and (includeInactive or node.activeSelf) then
                out[out.Length] = g
                out.Length = out.Length + 1
            end
            for _, c in ipairs(node.order) do walk(c) end
        end
        walk(self)
        return out
    end
    return o
end

local function cloneRect(src)
    local c = newRect(src.name, src.activeSelf)
    c.position = { x = src.position.x, y = src.position.y, z = src.position.z }
    c.localPosition = { x = src.localPosition.x, y = src.localPosition.y, z = src.localPosition.z }
    for cls, g in pairs(src.graphics) do
        c.graphics[cls] = { raycastTarget = g.raycastTarget }
    end
    for _, ch in ipairs(src.order) do
        c:AddChild(cloneRect(ch))
    end
    return c
end

-- 模板 tab：select（高亮板，带 Image/Text）+ bg
newObjToParent = function(tpl, parent)
    local c = newRect(tpl.name, tpl.activeSelf)
    local sel = c:AddChild(newRect("select", true))
    sel.graphics.Image = { raycastTarget = true }
    sel.graphics.Text = { raycastTarget = true }
    local bg = c:AddChild(newRect("default", true))
    bg.graphics.Image = { raycastTarget = true }
    parent:AddChild(c)
    return c
end

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { one = { x = 1, y = 1, z = 1 }, zero = { x = 0, y = 0, z = 0 },
            New = function(x, y, z) return { x = x, y = y, z = z } end }
Ease = { Linear = "Linear", OutQuad = "OutQuad", InOutQuad = "InOutQuad" }
GameObject = {
    Instantiate = function(go) return cloneRect(go) end,
    Destroy = function(go) go.destroyed = true end,
}
typeof = function(t) return t end
UnityEngine = { UI = { Image = "Image", Text = "Text" } }
DoTween = {
    To = function(getter, setter, endv, dur)
        return newTween(getter, setter, endv, dur)
    end,
}
DG = { Tweening = { Core = {
    DOGetter_float = function(f) return f end,
    DOSetter_float = function(f) return f end,
} } }

Util = {
    GetGameObject = function(root, path)
        local base = (type(root) == "table" and root.transform) or root
        if base and base.Find then return base:Find(path) end
        return nil
    end,
    ClearChild = function(t) t.children = {}; t.order = {}; t.childCount = 0 end,
    AddClick = function() end,
}

function Inherit(base) return setmetatable({}, { __index = base }) end
LogError = function(msg) print("  [LogError] " .. msg) end

-- ---------------- helpers ----------------
local failures = 0
local function check(cond, msg)
    if cond then
        print("  ok - " .. msg)
    else
        failures = failures + 1
        print("  FAIL - " .. msg)
    end
end

-- 搭一个 2 页签的 tabbox；tabX 为各 tab 的世界坐标 x
local function buildTabBox(tab1x, tab2x)
    local tabbox = newRect("TabBox", true)
    local template = newRect("tab", true)
    local box = newRect("box", true)
    tabbox:AddChild(template)
    tabbox:AddChild(box)
    box.position = { x = 0, y = 0, z = 0 }

    local TabBox = assert(loadfile(TABBOX))()
    local ctrl = TabBox.New()
    ctrl:SetTabAdapter(function(tab, index, status)
        Util.GetGameObject(tab, "default"):SetActive(status == "default")
        Util.GetGameObject(tab, "select"):SetActive(status == "select")
    end)
    local switched = nil
    ctrl:SetChangeTabCallBack(function(idx) switched = idx end)
    ctrl:Init(tabbox, { {}, {} }, 1)
    ctrl.TabList[1].position = { x = tab1x, y = 0, z = 0 }
    ctrl.TabList[2].position = { x = tab2x, y = 0, z = 0 }
    -- 克隆体继承模板位置，也要跟上真实布局
    for i = 1, 2 do
        local sel = ctrl.TabList[i].children["select"]
        sel.position = { x = tab1x and (i == 1 and tab1x or tab2x) or 0, y = 0, z = 0 }
    end
    -- 初始态：tab1 选中
    ctrl.TabList[1].children["select"].activeSelf = true
    ctrl.TabList[2].children["select"].activeSelf = false
    return ctrl, box, tab1x or 0, tab2x or 0
end

-- ---------------- tests ----------------
print("== ① 默认 opt-in 关闭：ChangeTab 不产生 tween ==")
do
    local ctrl = buildTabBox(0, 100)
    ctrl:ChangeTab(2)
    check(#tweens == 0, "未打开开关时不建 tween")
    check(ctrl.TabList[2].children["select"].activeSelf == true, "选中态直接切换（原行为不变）")
end

print("== ② 打开后滑动：克隆滑块 + 隐藏新 select ==")
local ctrl, box
do
    tweens = {}
    ctrl, box = buildTabBox(0, 100)
    ctrl:SetTabSlideAnim(true)
    ctrl:ChangeTab(2)
    check(#tweens == 1 and liveTweens() == 1, "建了 1 条存活 tween")
    check(ctrl.TabList[2].children["select"].activeSelf == false, "动画期间新 select 被隐藏")
    check(ctrl.TabList[1].children["select"].activeSelf == false, "旧 select 已按 adapter 置 default")
    check(ctrl.slideClone ~= nil and ctrl.slideClone.activeSelf, "克隆滑块存在且激活")
    check(ctrl.slideClone.localPosition.x == 0, "滑块从旧 tab 位置起步")
    check(tweens[1].endv == 100, "tween 终点是新 tab 位置")
    check(tweens[1].dur == 0.15, "时长 0.15s")
end

print("== ③ 克隆体射线全关 ==")
do
    local n = 0
    local arr = ctrl.slideClone:GetComponentsInChildren("Image", true)
    for i = 0, arr.Length - 1 do
        n = n + 1
        check(arr[i].raycastTarget == false, "Image#" .. i .. " raycastTarget=false")
    end
    check(n == 1, "克隆体含 1 个 Image")
    local txt = ctrl.slideClone:GetComponentsInChildren("Text", true)
    check(txt.Length == 1 and txt[0].raycastTarget == false, "克隆体 Text raycastTarget=false")
end

print("== ④ 完成还原 ==")
do
    tweens[1]:Complete()
    check(ctrl.TabList[2].children["select"].activeSelf == true, "完成后新 select 复显")
    check(ctrl.slideClone == nil, "克隆体引用清空")
    check(ctrl.slideCloneRef == nil, "无残留")
    check(liveTweens() == 0, "无存活 tween")
end

print("== ⑤ 连点防叠播 ==")
do
    tweens = {}
    local c2 = buildTabBox(0, 100)
    c2:SetTabSlideAnim(true)
    c2:ChangeTab(2)
    local firstClone = c2.slideClone
    local firstTween = tweens[1]
    c2:ChangeTab(1)
    check(firstTween.killed, "第一条 tween 被 Kill")
    check(firstClone.destroyed, "旧克隆体被销毁")
    check(c2.slideClone ~= nil and c2.slideClone ~= firstClone, "新滑块是另一个克隆体")
    check(c2.slideTab == c2.TabList[1], "滑动目标回到 tab1")
    tweens[#tweens]:Complete()
    check(c2.TabList[1].children["select"].activeSelf == true, "最终 tab1 选中态复显")
    check(liveTweens() == 0, "无存活 tween")
end

print("== ⑥ KillTabSlide finish 语义 ==")
do
    tweens = {}
    local c3 = buildTabBox(0, 100)
    c3:SetTabSlideAnim(true)
    c3:ChangeTab(2)
    c3:KillTabSlide(false)
    check(c3.TabList[2].children["select"].activeSelf == false, "finish=false 不复显（面板关闭语义）")
    check(c3.slideClone == nil and liveTweens() == 0, "tween/克隆体已回收")

    tweens = {}
    local c4 = buildTabBox(0, 100)
    c4:SetTabSlideAnim(true)
    c4:ChangeTab(2)
    c4:KillTabSlide(true)
    check(c4.TabList[2].children["select"].activeSelf == true, "finish=true 立即复显选中态")
    check(c4.slideClone == nil and liveTweens() == 0, "tween/克隆体已回收")
end

print("== ⑦ 动画中重新 Init（重入） ==")
do
    tweens = {}
    local tabbox = newRect("TabBox", true)
    local template = newRect("tab", true)
    local bx = newRect("box", true)
    tabbox:AddChild(template)
    tabbox:AddChild(bx)
    bx.position = { x = 0, y = 0, z = 0 }
    local TabBox = assert(loadfile(TABBOX))()
    local c5 = TabBox.New()
    c5:SetTabAdapter(function() end)
    c5:Init(tabbox, { {}, {} }, 1)
    c5.TabList[1].position = { x = 0, y = 0, z = 0 }
    c5.TabList[2].position = { x = 100, y = 0, z = 0 }
    c5.TabList[1].children["select"].position = { x = 0, y = 0, z = 0 }
    c5.TabList[2].children["select"].position = { x = 100, y = 0, z = 0 }
    c5:SetTabSlideAnim(true)
    c5:ChangeTab(2)
    check(liveTweens() == 1, "动画进行中")
    -- 面板重开：OnShow 会再次 Init（内部 ClearChild 重建 box 子节点）
    c5:Init(tabbox, { {}, {} }, 1)
    check(liveTweens() == 0, "重入后旧 tween 已回收")
    check(c5.slideClone == nil, "旧克隆体引用清空")
    check(c5.TabList[1].children["select"].activeSelf == true, "重建后 tab1 为选中态")
end

print("== ⑧ 同位护栏 ==")
do
    tweens = {}
    local c6 = buildTabBox(50, 50)
    c6:SetTabSlideAnim(true)
    c6:ChangeTab(2)
    check(#tweens == 0, "新旧 tab 同 x 时不建 tween")
    check(c6.TabList[2].children["select"].activeSelf == true, "选中态仍正确切换")
end

print("")
if failures == 0 then
    print("ALL PASS")
else
    print("FAILED: " .. failures)
    os.exit(1)
end
