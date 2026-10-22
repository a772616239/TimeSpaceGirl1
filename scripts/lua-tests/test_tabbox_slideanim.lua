-- 离线验证 TabBox 的「页签选中底板滑动动画」v2（不克隆节点、Timer 驱动，不依赖 Unity）：
-- 用假 Util / UpdateBeat / Time + **真 TabBox + 真 Timer.lua** 跑真源码，覆盖
--   ① opt-in 闸门     默认 ChangeTab 不启动任何 Timer（其他 60+ 面板零影响）
--   ② 打开后滑动      ChangeTab 后新 select 被偏移到旧页签位置，逐帧插值回原位
--   ③ 完成复位        动画结束 select.localPosition **精确等于原值**（反「错位」硬闸门）
--   ④ 连点防叠播      动画中再切页签：旧 Timer 停、旧 select 复位、新 select 从旧位置起步
--   ⑤ KillTabSlide    任何中断（面板关闭语义）都必须把 select 复位，不留错位
--   ⑥ 重入安全        动画中重新 Init：Timer 回收、位置复位、重建后状态正确
--   ⑦ 同位护栏        新旧 tab 同位时不建 Timer
--   ⑧ 纵向位移        dy 同样生效（TabBox 支持纵向布局）
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_tabbox_slideanim.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local TABBOX = ROOT .. "Assets/ManagedResources/~Lua/Modules/Common/TabBox.lua"
local TIMER = ROOT .. "Assets/ManagedResources/~Lua/System/Timer.lua"

-- ---------------- stubs ----------------
local DT = 1 / 60

-- 真 Timer.lua 依赖 UpdateBeat / Time / CoUpdateBeat —— 打桩后加载真源码
local beat = {}
UpdateBeat = {
    CreateListener = function(self, fn, obj) return { fn = fn, obj = obj } end,
    AddListener = function(self, h) beat[#beat + 1] = h end,
    RemoveListener = function(self, h)
        for i, v in ipairs(beat) do
            if v == h then table.remove(beat, i) break end
        end
    end,
}
CoUpdateBeat = { CreateListener = UpdateBeat.CreateListener, AddListener = function() end,
                 RemoveListener = function() end }
Time = { unscaledDeltaTime = DT, deltaTime = DT, frameCount = 0 }
assert(loadfile(TIMER))()

local function tickFrames(n)
    for _ = 1, n do
        Time.frameCount = Time.frameCount + 1
        for _, h in ipairs(beat) do h.obj:Update() end
    end
end

local function newRect(name, active)
    local o = { name = name, activeSelf = active ~= false, childCount = 0,
                localPosition = { x = 0, y = 0, z = 0 }, children = {}, order = {} }
    o.transform = o
    o.gameObject = o
    function o:SetActive(v) self.activeSelf = v and true or false end
    function o:AddChild(c)
        self.children[c.name] = c
        self.order[#self.order + 1] = c
        self.childCount = #self.order
        return c
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
    return o
end

-- 模板 tab：select（高亮板）+ default
newObjToParent = function(tpl, parent)
    local c = newRect(tpl.name, tpl.activeSelf)
    c:AddChild(newRect("select", true))
    c:AddChild(newRect("default", true))
    parent:AddChild(c)
    return c
end

Vector3 = { one = { x = 1, y = 1, z = 1 }, zero = { x = 0, y = 0, z = 0 },
            New = function(x, y, z) return { x = x, y = y, z = z } end }

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

local function posEq(a, b)
    return math.abs(a.x - b.x) < 1e-6 and math.abs(a.y - b.y) < 1e-6
end

-- 搭一个 2 页签的 tabbox；tab1/tab2 为各 tab 的 box 局部坐标
local function buildTabBox(tab1, tab2)
    local tabbox = newRect("TabBox", true)
    local template = newRect("tab", true)
    local box = newRect("box", true)
    tabbox:AddChild(template)
    tabbox:AddChild(box)

    local TabBox = assert(loadfile(TABBOX))()
    local ctrl = TabBox.New()
    ctrl:SetTabAdapter(function(tab, index, status)
        Util.GetGameObject(tab, "default"):SetActive(status == "default")
        Util.GetGameObject(tab, "select"):SetActive(status == "select")
    end)
    ctrl:SetChangeTabCallBack(function() end)
    ctrl:Init(tabbox, { {}, {} }, 1)
    ctrl.TabList[1].transform.localPosition = tab1
    ctrl.TabList[2].transform.localPosition = tab2
    return ctrl, box
end

-- ---------------- tests ----------------
print("== ① 默认 opt-in 关闭：ChangeTab 不启动 Timer ==")
do
    local ctrl = buildTabBox({ x = 0, y = 0, z = 0 }, { x = 100, y = 0, z = 0 })
    ctrl:ChangeTab(2)
    check(#beat == 0, "未打开开关时无任何 Timer")
    check(ctrl.TabList[2].children["select"].activeSelf == true, "选中态直接切换（原行为不变）")
    check(posEq(ctrl.TabList[2].children["select"].localPosition, { x = 0, y = 0, z = 0 }), "select 位置未被改动")
end

print("== ② 打开后滑动：select 先偏移到旧页签位置 ==")
local ctrl, sel2
do
    beat = {}
    ctrl, _ = buildTabBox({ x = 0, y = 0, z = 0 }, { x = 100, y = 0, z = 0 })
    ctrl:SetTabSlideAnim(true)
    sel2 = ctrl.TabList[2].children["select"]
    ctrl:ChangeTab(2)
    check(#beat == 1, "启动了 1 个驱动 Timer")
    check(ctrl.slideSelect == sel2, "动画目标是新 select")
    check(math.abs(sel2.localPosition.x - (-100)) < 1e-6, "首帧 select 位于旧页签 x(=-100)")
    tickFrames(1)
    local p = sel2.localPosition.x
    check(p > -100 and p < 0, "逐帧插值中（x 在 -100→0 之间，实际 " .. string.format("%.2f", p) .. "）")
end

print("== ③ 完成复位：localPosition 精确还原（反错位硬闸门） ==")
do
    tickFrames(30)
    check(posEq(sel2.localPosition, { x = 0, y = 0, z = 0 }), "动画结束 select 回到原位 (0,0,0)")
    check(#beat == 0, "Timer 自动停止")
    check(ctrl.slideSelect == nil and ctrl.slideOrig == nil, "引用清空")
end

print("== ④ 连点防叠播 ==")
do
    beat = {}
    local c2 = buildTabBox({ x = 0, y = 0, z = 0 }, { x = 100, y = 0, z = 0 })
    c2:SetTabSlideAnim(true)
    local s1, s2 = c2.TabList[1].children["select"], c2.TabList[2].children["select"]
    c2:ChangeTab(2)
    local firstTimer = c2.slideTimer
    c2:ChangeTab(1)
    check(firstTimer.running == false, "旧 Timer 已停")
    check(posEq(s2.localPosition, { x = 0, y = 0, z = 0 }), "被打断的 select 已复位")
    check(math.abs(s1.localPosition.x - 100) < 1e-6, "新动画从旧选中位（tab2, x=+100）起步")
    tickFrames(30)
    check(posEq(s1.localPosition, { x = 0, y = 0, z = 0 }), "最终 tab1 select 精确回原位")
    check(#beat == 0, "无残留 Timer")
end

print("== ⑤ KillTabSlide 中断必须复位（反错位） ==")
do
    beat = {}
    local c3 = buildTabBox({ x = 0, y = 0, z = 0 }, { x = 100, y = 0, z = 0 })
    c3:SetTabSlideAnim(true)
    local s2 = c3.TabList[2].children["select"]
    c3:ChangeTab(2)
    tickFrames(3) -- 滑到一半
    c3:KillTabSlide(false) -- 面板关闭语义
    check(c3.slideTimer == nil, "Timer 已回收")
    check(posEq(s2.localPosition, { x = 0, y = 0, z = 0 }), "半途 select 已复位到原位")
    check(#beat == 0, "beat 清空")
end

print("== ⑥ 动画中重新 Init（重入） ==")
do
    beat = {}
    local tabbox = newRect("TabBox", true)
    local template = newRect("tab", true)
    local bx = newRect("box", true)
    tabbox:AddChild(template)
    tabbox:AddChild(bx)
    local TabBox = assert(loadfile(TABBOX))()
    local c4 = TabBox.New()
    c4:SetTabAdapter(function() end)
    c4:Init(tabbox, { {}, {} }, 1)
    c4.TabList[1].transform.localPosition = { x = 0, y = 0, z = 0 }
    c4.TabList[2].transform.localPosition = { x = 100, y = 0, z = 0 }
    c4:SetTabSlideAnim(true)
    c4:ChangeTab(2)
    check(#beat == 1, "动画进行中")
    c4:Init(tabbox, { {}, {} }, 1) -- 面板重开，OnShow 再次 Init
    check(#beat == 0, "重入后旧 Timer 已回收")
    check(c4.slideSelect == nil, "引用清空")
    check(posEq(c4.TabList[1].children["select"].localPosition, { x = 0, y = 0, z = 0 }), "重建后位置干净")
end

print("== ⑦ 同位护栏 ==")
do
    beat = {}
    local c5 = buildTabBox({ x = 50, y = 0, z = 0 }, { x = 50, y = 0, z = 0 })
    c5:SetTabSlideAnim(true)
    c5:ChangeTab(2)
    check(#beat == 0, "新旧 tab 同位时不建 Timer")
    check(c5.TabList[2].children["select"].activeSelf == true, "选中态仍正确切换")
end

print("== ⑧ 纵向位移（dy） ==")
do
    beat = {}
    local c6 = buildTabBox({ x = 0, y = 0, z = 0 }, { x = 0, y = 80, z = 0 })
    c6:SetTabSlideAnim(true)
    local s2 = c6.TabList[2].children["select"]
    c6:ChangeTab(2)
    check(math.abs(s2.localPosition.y - (-80)) < 1e-6, "首帧 select 位于旧页签 y(=-80)")
    tickFrames(30)
    check(posEq(s2.localPosition, { x = 0, y = 0, z = 0 }), "纵向滑动后精确回原位")
end

print("")
if failures == 0 then
    print("ALL PASS")
else
    print("FAILED: " .. failures)
    os.exit(1)
end
