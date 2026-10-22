-- 离线验证 SettingPanel 的**开关滑动**（不依赖 Unity）：
-- 用假 BasePanel / Util / RectTransform / DOTween / Timer 跑真源码，覆盖
--   ① 打开      底板与内容容器一起从 baseX-770 滑回 baseX，遮罩 alpha 0 → 0.8
--   ② 位移量    现场量内容最右边缘（本 fixture 内容右边缘 = 740）⇒ travel = 740 + 30
--   ③ 关闭      OnCloseBefore 播完才回调，回调恰好 1 次；tween 未完成前不得回调
--   ④ 排队      播放中再次 OnCloseBefore ⇒ 两个 callback 都各被调用 1 次
--   ⑤ 复位      ResetSlide Kill 全部 tween 并精确回到 baseX / 0.8
--   ⑥ 回显      关闭后停在"屏外"，不经 OnOpen 的 OnShow（被新面板盖住后回头）也要滑回
--   ⑦ 不空播    已在原位且没有 OnOpen 的 OnShow 不播
--   ⑧ 缺节点    slideItems 为空时不报错，关闭回调立即放行
--   ⑨ 兜底      tween 被 Kill（不回调）时，超时 timer 仍放行关闭回调
--  ⑩ 兜底宽度  量不到宽度时 travel = 屏宽 × 0.75 + 30
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_settingpanel_slide.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Setting/SettingPanel.lua"

local fails, passes = 0, 0
local function ok(cond, name, extra)
    if cond then
        passes = passes + 1
    else
        fails = fails + 1
        print("  ✗ " .. name .. (extra and ("  [" .. tostring(extra) .. "]") or ""))
    end
end
local function eq(actual, expect, name)
    ok(math.abs((actual or -99999) - expect) < 0.001, name, "actual=" .. tostring(actual) .. " expect=" .. tostring(expect))
end

-- ---------------- stubs: unity maths ----------------
local nearest = 0
local function round(v) return math.floor(v + 0.5) end

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { New = function(x, y, z) return { x = x, y = y, z = z or 0 } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
Ease = { OutQuad = 1, InQuad = 2, Linear = 3 }
LogError = function(msg) print("  (LogError) " .. tostring(msg)) end
IsNull = function(o) return o == nil or (type(o) == "table" and o.__destroyed == true) end

-- ---------------- stubs: Timer（手动驱动） ----------------
local timers = {}
Timer = {}
function Timer.New(func, duration, loop, unscaled)
    local t = { func = func, duration = duration, running = false, stopped = false }
    function t:Start() self.running = true; timers[#timers + 1] = self end
    function t:Stop() self.running = false; self.stopped = true end
    return t
end
local function RunTimers()
    local snapshot = timers
    timers = {}
    for _, t in ipairs(snapshot) do
        if t.running then
            t.running = false
            t.func()
        end
    end
end

-- ---------------- stubs: DOTween ----------------
local tweens = {}
local function newTween(kind, node, endv, dur)
    local t = { kind = kind, node = node, endv = endv, dur = dur, ease = nil,
                onComplete = nil, killed = false, completed = false }
    function t:SetEase(e) self.ease = e; return self end
    function t:SetDelay() return self end
    function t:OnComplete(cb) self.onComplete = cb; return self end
    function t:Kill() self.killed = true; self.onComplete = nil end
    function t:Complete()
        if self.killed or self.completed then return end
        self.completed = true
        if self.kind == "posx" then
            self.node.anchoredPosition = { x = self.endv, y = self.node.anchoredPosition.y }
        else
            self.node.color = { r = self.node.color.r, g = self.node.color.g,
                                b = self.node.color.b, a = self.endv }
        end
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

-- ---------------- stubs: 节点 ----------------
-- 原点在 root 中心；width 为 rect 宽，centerX 为该节点中心相对 root 中心的坐标
local function mkNode(name, width, centerX, parent, opts)
    opts = opts or {}
    local n = {
        name = name, width = width, centerX = centerX, parent = parent,
        activeSelf = opts.activeSelf ~= false,
        anchoredPosition = { x = opts.baseX or 0, y = opts.baseY or 0 },
        __graphic = opts.graphic,
        children = {}, order = {}, childCount = 0,
    }
    n.rect = { xMax = width * 0.5, width = width }
    n.pivot = { x = 0.5, y = 0.5 }
    n.gameObject = n
    n.transform = n
    if opts.image then
        n.image = { color = { r = 0, g = 0, b = 0, a = opts.image.alpha } }
        function n.image:DOFade(v, dur) return newTween("fade", self, v, dur) end
    end
    function n:GetComponent(cls)
        if cls == "RectTransform" then
            if self.__noRect then return nil end
            return self
        end
        if cls == "CanvasRenderer" then return self.__graphic and {} or nil end
        if cls == "Image" then return self.image end
        return nil
    end
    function n:DOAnchorPosX(v, dur) return newTween("posx", self, v, dur) end
    function n:TransformPoint(v) return { x = self.centerX + v.x, y = 0, z = 0 } end
    function n:InverseTransformPoint(v)
        local rootNode = self
        while rootNode.parent do rootNode = rootNode.parent end
        return { x = v.x - rootNode.centerX, y = 0, z = 0 }
    end
    function n:SetActive(v) self.activeSelf = v and true or false end
    function n:GetChild(i) return self.order[i + 1] end
    function n:AddChild(c)
        self.order[#self.order + 1] = c
        self.children[c.name] = c
        self.childCount = #self.order
        return c
    end
    if parent then parent:AddChild(n) end
    return n
end

-- 用真源码里的 Util.GetGameObject 语义（单名 DFS，斜杠走路径）
local function findChild(tf, name)
    local c = tf.children[name]
    if c then return c end
    for _, v in ipairs(tf.order) do
        local found = findChild(v, name)
        if found then return found end
    end
    return nil
end
Util = {
    GetGameObject = function(tf, path)
        if tf == nil then return nil end
        local cur = tf
        for seg in string.gmatch(path, "[^/]+") do
            if cur == nil then return nil end
            cur = findChild(cur, seg)
        end
        return cur
    end,
    AddClick = function() end,
}

-- ---------------- stubs: BasePanel / SettingInfo / Inherit ----------------
local FakeBasePanel = {}
package.preload["Base/BasePanel"] = function() return FakeBasePanel end
local SettingInfoStub = {
    new = function()
        return {
            BindEvent = function() end, AddListener = function() end,
            RemoveListener = function() end, OnShow = function() end,
            OnClose = function() end, OnDestroy = function() end,
        }
    end,
}
package.preload["Modules/Setting/SettingInfo"] = function() return SettingInfoStub end
function Inherit(_) return {} end

-- ---------------- 载入真源码 ----------------
local SettingPanel = dofile(SRC)

-- ---------------- fixture ----------------
-- 结构对齐 prefab 实测：底板 405 贴左边缘；内容最右 740（duanWei）
local TRAVEL_EXPECT = 740 + 30

local function NewPanel(opts)
    opts = opts or {}
    tweens = {}
    timers = {}
    local root = mkNode("SettingPanel", 1080, 0, nil)
    local mask = mkNode("BackMask", 1080, 0, root, { image = { alpha = 0.8 } })
    if opts.withNodes ~= false then
        -- 底板：贴左边缘 ⇒ 中心 -540 + 202.5 ≈ -337.5，基准 x = 202
        local bgNode = mkNode("bg", 405, -337.5, mask, { baseX = 202, image = { alpha = 1 }, graphic = not opts.noGraphics })
        local layout = mkNode("layout", 1080, 0, root, { baseX = 0 })
        if opts.breakRect then
            bgNode.__noRect = true
            layout.__noRect = true
        end
        local info = mkNode("settingInfo", 405.5, -337.25, layout)
        mkNode("btnBack", 99, 117.75, info, { graphic = not opts.noGraphics })
        -- 内容最右边缘：绝对 740 ⇒ 相对 root 中心 200
        mkNode("duanWei", 200, 100, info, { graphic = not opts.noGraphics })
        local duan = info.children["duanWei"]
        if duan then duan.centerX = 100 end
    end
    -- 本项目的面板是"类即实例"（BasePanel:CreateUI 直接写 self.*，SettingPanel 里用的是 this.*）
    local inst = SettingPanel
    inst.transform = root
    inst.gameObject = root
    inst.pendingSlideOpen = nil
    inst:InitComponent()
    return inst, root
end

-- ================= ① 打开：滑入 + 遮罩淡入 =================
do
    local inst, root = NewPanel()
    inst:OnOpen()
    inst:OnShow()
    local bg = Util.GetGameObject(root, "BackMask/bg")
    local layout = Util.GetGameObject(root, "layout")
    eq(bg.anchoredPosition.x, 202 - TRAVEL_EXPECT, "① 打开瞬间底板在屏外")
    eq(layout.anchoredPosition.x, 0 - TRAVEL_EXPECT, "① 打开瞬间内容在屏外")
    eq(root.children["BackMask"].image.color.a, 0, "① 遮罩从 0 起")
    for _, t in ipairs(tweens) do t:Complete() end
    eq(bg.anchoredPosition.x, 202, "① 播完底板精确回 baseX")
    eq(layout.anchoredPosition.x, 0, "① 播完内容精确回 baseX")
    eq(root.children["BackMask"].image.color.a, 0.8, "① 播完遮罩回到 0.8")
    ok(#tweens == 3, "① 只有 2 条位移 + 1 条淡入", #tweens)
end

-- ================= ② 位移量 = 内容右边缘 + 30 =================
do
    local inst, root = NewPanel()
    inst:OnOpen(); inst:OnShow()
    local bg = Util.GetGameObject(root, "BackMask/bg")
    eq(202 - bg.anchoredPosition.x, TRAVEL_EXPECT, "② travel = 740 + 30（现场量，不写死 405）")
end

-- ================= ③ 关闭：播完才回调，且只回调 1 次 =================
do
    local inst, root = NewPanel()
    inst:OnOpen(); inst:OnShow()
    for _, t in ipairs(tweens) do t:Complete() end
    tweens = {}
    local n = 0
    inst:OnCloseBefore(function() n = n + 1 end)
    eq(n, 0, "③ tween 未完成前不得回调")
    local bg = Util.GetGameObject(root, "BackMask/bg")
    -- DOAnchorPosX 是"从当前位置补到目标"，t=0 不会瞬移 ⇒ 查 tween 的终点
    local target = nil
    for _, t in ipairs(tweens) do
        if t.kind == "posx" and t.node == bg then target = t.endv end
    end
    eq(target or -99999, 202 - TRAVEL_EXPECT, "③ 关闭 tween 终点 = 屏外")
    for _, t in ipairs(tweens) do t:Complete() end
    eq(n, 1, "③ 播完回调恰好 1 次")
    for _, t in ipairs(tweens) do t:Complete() end
    eq(n, 1, "③ 重复 Complete 不重复回调")
    RunTimers()
    eq(n, 1, "③ 兜底 timer 触发后也不重复回调")
end

-- ================= ④ 播放中再次请求关闭 ⇒ 两个回调都放行 =================
do
    local inst = NewPanel()
    inst:OnOpen(); inst:OnShow()
    for _, t in ipairs(tweens) do t:Complete() end
    tweens = {}
    local a, b = 0, 0
    inst:OnCloseBefore(function() a = a + 1 end)
    inst:OnCloseBefore(function() b = b + 1 end)
    eq(a, 0, "④ 首个回调未触发")
    for _, t in ipairs(tweens) do t:Complete() end
    eq(a, 1, "④ 回调 A 恰好 1 次")
    eq(b, 1, "④ 排队回调 B 也恰好 1 次")
end

-- ================= ⑤ ResetSlide：Kill + 精确复位 =================
do
    local inst, root = NewPanel()
    inst:OnOpen(); inst:OnShow()
    local bg = Util.GetGameObject(root, "BackMask/bg")
    local layout = Util.GetGameObject(root, "layout")
    inst.ResetSlide()
    eq(bg.anchoredPosition.x, 202, "⑤ 底板复位")
    eq(layout.anchoredPosition.x, 0, "⑤ 内容复位")
    eq(root.children["BackMask"].image.color.a, 0.8, "⑤ 遮罩 alpha 复位")
    -- 复位后再走一次关闭：必须还能正常播（状态没卡在 moving）
    tweens = {}
    local n = 0
    inst:OnCloseBefore(function() n = n + 1 end)
    ok(#tweens > 0, "⑤ 复位后仍能起播关闭动画", #tweens)
    for _, t in ipairs(tweens) do t:Complete() end
    eq(n, 1, "⑤ 复位后关闭回调正常")
end

-- ================= ⑥ 关闭后不经 OnOpen，直接 OnShow 也要滑回 =================
do
    local inst, root = NewPanel()
    inst:OnOpen(); inst:OnShow()
    for _, t in ipairs(tweens) do t:Complete() end
    inst:OnCloseBefore(function() end)
    for _, t in ipairs(tweens) do t:Complete() end
    local bg = Util.GetGameObject(root, "BackMask/bg")
    eq(bg.anchoredPosition.x, 202 - TRAVEL_EXPECT, "⑥ 关闭后停在屏外")
    tweens = {}
    inst:OnShow()   -- 模拟"被新面板盖住后回头显示"（OpenUI(true)，不走 OnOpen）
    ok(#tweens > 0, "⑥ 从屏外回来的 OnShow 要重新滑入", #tweens)
    for _, t in ipairs(tweens) do t:Complete() end
    eq(bg.anchoredPosition.x, 202, "⑥ 滑回 baseX")
end

-- ================= ⑦ 已在原位且没有 OnOpen 的 OnShow 不播 =================
do
    local inst = NewPanel()
    inst:OnOpen(); inst:OnShow()
    for _, t in ipairs(tweens) do t:Complete() end
    tweens = {}
    inst:OnShow()
    ok(#tweens == 0, "⑦ 原位重复 Show 不空播", #tweens)
end

-- ================= ⑧ 缺节点：不报错，关闭回调立即放行 =================
do
    -- 树是完整的（settingInfo 取得到），但两个滑动节点的 RectTransform 取不到 ⇒ slideItems 为空
    local inst = NewPanel({ breakRect = true })
    inst:OnOpen()
    local okOpen = pcall(function() inst:OnShow() end)
    ok(okOpen, "⑧ 缺滑动节点时打开不报错")
    local n = 0
    local okClose = pcall(function() inst:OnCloseBefore(function() n = n + 1 end) end)
    ok(okClose, "⑧ 缺滑动节点时关闭不报错")
    eq(n, 1, "⑧ 关闭回调立即放行（不能把面板卡死在打开状态）")
end

-- ================= ⑨ tween 被 Kill 不回调 ⇒ 兜底 timer 放行 =================
do
    local inst = NewPanel()
    inst:OnOpen(); inst:OnShow()
    for _, t in ipairs(tweens) do t:Complete() end
    tweens = {}
    local n = 0
    inst:OnCloseBefore(function() n = n + 1 end)
    for _, t in ipairs(tweens) do t:Kill() end   -- 模拟 DOTween.KillAll / 切场景
    eq(n, 0, "⑨ Kill 后 tween 不再回调")
    RunTimers()
    eq(n, 1, "⑨ 超时 timer 兜底放行关闭回调")
end

-- ================= ⑩ 量不到宽度 ⇒ 屏宽 × 0.75 + 30 =================
do
    -- 子树里没有任何 CanvasRenderer ⇒ 量出 0 ⇒ 走兜底宽度
    local inst, root = NewPanel({ noGraphics = true })
    ok(inst ~= nil, "⑩ 前提：量不到可见内容")
    inst:OnOpen(); inst:OnShow()
    local bg = Util.GetGameObject(root, "BackMask/bg")
    eq(202 - bg.anchoredPosition.x, 1080 * 0.75 + 30, "⑩ 兜底 travel = 屏宽 × 0.75 + 30")
end

print(string.format("\n设置面板开关滑动：%d passed, %d failed", passes, fails))
if fails > 0 then os.exit(1) end
