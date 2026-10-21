-- 离线验证 ItemPopIn 的「页面级批量接入」（PlayPage / StopPage）——不依赖 Unity：
--   ① 实例字段         quick_class 的 `self.scrollView` 写在实例上，能扫到
--   ② 类表字段         `local this = Class` 把字段写在类上、实例只通过 __index 取，也要扫到
--   ③ 多列表           一页两个 ScrollCycleView（周/月礼包）都要播
--   ④ 无列表           固定版面页 / nil / 非 table：返回 0，不建 tween、不报错
--   ⑤ StopPage         Kill + 复位（漏调 = item 永久停在半截缩放）
--   ⑥ 容器模式         手工克隆的列表靠 GetPopInSource 声明，按 active 子节点播
--   ⑦ 绑定缓存         同一页第二次 PlayPage 复用第一次的 popIn，不重复扫描
--   ⑧ 重播             两次 PlayPage 不叠加
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_itempopin_page.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Common/ItemPopIn.lua"

local failed = 0
local function Check(cond, msg)
    if cond then
        print("  ✅ " .. msg)
    else
        failed = failed + 1
        print("  ❌ " .. msg)
    end
end

local function Near(a, b)
    return math.abs(a - b) < 1e-6
end

-- ---------------- stubs ----------------
local v3mt = {}
v3mt.__index = v3mt
v3mt.__mul = function(a, b)
    if type(a) == "number" then
        a, b = b, a
    end
    return setmetatable({ x = a.x * b, y = a.y * b, z = a.z * b }, v3mt)
end
local function v3(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, v3mt)
end
Vector3 = { one = v3(1, 1, 1), zero = v3(0, 0, 0), New = v3 }
Ease = { Linear = "Linear", InOutQuad = "InOutQuad", OutQuad = "OutQuad" }
IsNull = function() return false end
local errors = {}
LogError = function(msg) errors[#errors + 1] = msg end

local tweens = {}
local function newTween(tf, endv, dur)
    local t = { tf = tf, endv = endv, dur = dur, delay = 0, ease = nil,
                onComplete = nil, killed = false }
    function t:SetDelay(d) self.delay = d; return self end
    function t:SetEase(e) self.ease = e; return self end
    function t:OnComplete(cb) self.onComplete = cb; return self end
    function t:Kill() self.killed = true end
    function t:Complete()
        if self.killed then return end
        self.tf.localScale = self.endv
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

local function newItem(name, active)
    local o = { name = name, activeSelf = active ~= false, localScale = v3(1, 1, 1) }
    o.transform = o
    o.gameObject = o   -- 容器模式按 Transform 取，判定 active 要 gameObject.activeSelf
    function o:DOScale(v, dur) return newTween(self, v, dur) end
    return o
end

local function newScrollView(items)
    local sv = { goItemList = items, dataCount = #items }
    function sv:SetData() end
    function sv:ForeachItemGO(func)
        for i = 1, math.min(#self.goItemList, self.dataCount) do
            func(i, self.goItemList[i])
        end
    end
    return sv
end

-- 手工克隆列表的容器：只有 childCount / GetChild / activeSelf
local function newContainer(children)
    local c = { children = children, childCount = #children }
    function c:GetChild(i) return self.children[i + 1] end
    return c
end

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

local function countTweenOn(tf)
    local n = 0
    for _, t in ipairs(tweens) do
        if t.tf == tf and not t.killed then n = n + 1 end
    end
    return n
end

-- ---------------- load ----------------
local ItemPopIn = assert(loadfile(SRC))()

-- ---------------- case 1: 实例字段 ----------------
print("== case1 实例上的 scrollView ==")
tweens = {}
local items1 = { newItem("a"), newItem("b"), newItem("c") }
local page1 = { scrollView = newScrollView(items1) }
local n = ItemPopIn.PlayPage(page1)
Check(n == 1, "应接上 1 个列表，实际 " .. n)
Check(liveTweens() == 3, "应播 3 项，实际 " .. liveTweens())
Check(Near(items1[1].localScale.x, 0.82), "第一项从 0.82 起，实际 " .. items1[1].localScale.x)
Check(Near(tweens[3].delay, 0.11), "第三项延迟 0.11，实际 " .. tweens[3].delay)

-- ---------------- case 2: 类表字段 ----------------
print("== case2 类表字段（quick_class 的 local this = Class 写法）==")
tweens = {}
local items2 = { newItem("x"), newItem("y") }
local Cls = {}
Cls.__index = Cls
Cls.ScrollView = newScrollView(items2)      -- 字段写在类上
local inst = setmetatable({}, Cls)
inst.class = Cls
n = ItemPopIn.PlayPage(inst)
Check(n == 1, "类表上的 ScrollView 也要扫到，实际接上 " .. n)
Check(liveTweens() == 2, "应播 2 项，实际 " .. liveTweens())

-- ---------------- case 3: 一页两个列表 ----------------
print("== case3 周/月礼包：一页两个 ScrollView ==")
tweens = {}
local w1, w2 = { newItem("w1") }, { newItem("m1"), newItem("m2", false) }
local page3 = { scrollView = newScrollView(w1), scrollView2 = newScrollView(w2) }
n = ItemPopIn.PlayPage(page3)
Check(n == 2, "应接上 2 个列表，实际 " .. n)
Check(liveTweens() == 2, "两个列表各播可见项（第二个列表 1 项隐藏 ⇒ 共 2 条），实际 " .. liveTweens())

-- ---------------- case 4: 没有列表 ----------------
print("== case4 固定版面 / 异常入参 ==")
tweens = {}
errors = {}
Check(ItemPopIn.PlayPage({ btnBack = newItem("btn"), time = newItem("time") }) == 0, "无列表页返回 0")
Check(ItemPopIn.PlayPage(nil) == 0, "nil 返回 0")
Check(ItemPopIn.PlayPage(123) == 0, "非 table 返回 0")
ItemPopIn.StopPage(nil)
Check(#tweens == 0, "无列表页不该建 tween")
Check(#errors == 0, "无列表页不该报错")
print("  固定版面页（只有按钮/文本字段）→ no-op，面板可以对每个页签无脑调用")

-- ---------------- case 5: StopPage ----------------
print("== case5 StopPage 复位 ==")
tweens = {}
local items5 = {}
for i = 1, 4 do items5[i] = newItem("s" .. i) end
local page5 = { scrollView = newScrollView(items5) }
ItemPopIn.PlayPage(page5)
Check(liveTweens() == 4, "先播 4 条，实际 " .. liveTweens())
ItemPopIn.StopPage(page5)
Check(liveTweens() == 0, "StopPage 后不应有存活 tween，实际 " .. liveTweens())
local allReset = true
for i = 1, 4 do
    if not Near(items5[i].localScale.x, 1) then allReset = false end
end
Check(allReset, "StopPage 后全部复位到基准")

-- ---------------- case 6: 容器模式 ----------------
print("== case6 手工克隆的列表：GetPopInSource ==")
tweens = {}
local c1, c2, c3 = newItem("r1"), newItem("r2"), newItem("r3", false)   -- r3 是模板/隐藏行
local ContentPage = {}
ContentPage.__index = ContentPage
function ContentPage:GetPopInSource()
    return self.continuityTaskContent
end
local cp = setmetatable({ continuityTaskContent = newContainer({ c1, c2, c3 }) }, ContentPage)
cp.class = ContentPage
n = ItemPopIn.PlayPage(cp)
Check(n == 1, "容器算 1 个列表，实际 " .. n)
Check(liveTweens() == 2, "3 个子节点里 1 个 inactive ⇒ 播 2 项，实际 " .. liveTweens())
Check(Near(c1.localScale.x, 0.82) and Near(c2.localScale.x, 0.82), "容器项从 0.82 起")
Check(Near(c3.localScale.x, 1), "隐藏的模板行不该被动过")
ItemPopIn.StopPage(cp)
Check(Near(c1.localScale.x, 1), "StopPage 对容器同样复位")

-- tolua 的 GameObject 是 userdata：取**不存在**的字段会抛错（不是给 nil），只能取出真实存在的。
-- 用 newproxy 造一个同语义的替身，专治「按 table 写的代码在真机上一探字段就整段 pcall 失败」。
local function newGameObjectUdata(tf)
    local u = newproxy(true)
    local mt = getmetatable(u)
    mt.__index = function(_, k)
        if k == "transform" then return tf end
        error("field or property '" .. k .. "' does not exist", 2)
    end
    mt.__tostring = function() return "GameObject(userdata)" end
    return u
end

-- ---------------- case 6b: GetPopInSource 返回 GameObject（userdata） ----------------
-- 🔴 ExpertPanel 积天豪礼页真实形态：ContinuityRechargePage:GetPopInSource() 返回的是
--     Util.GetGameObject 出来的 GameObject，不是 table。旧代码直接 container.childCount
--     探字段 ⇒ tolua 抛 "field or property 'childCount' does not exist" ⇒ 整段 pcall 失败
--     ⇒ 那页永远没动画，日志里每次切页都刷一条错误。
print("== case6b GetPopInSource 返回 GameObject（userdata）==")
tweens = {}
errors = {}
local probeOk = pcall(function()
    return newGameObjectUdata(newContainer({})).childCount
end)
Check(not probeOk, "替身对不存在的字段抛错（与 tolua 行为一致，否则本用例无效）")

local u1, u2, u3 = newItem("u1"), newItem("u2"), newItem("u3", false)
local uContent = newContainer({ u1, u2, u3 })
local GoPage = {}
GoPage.__index = GoPage
function GoPage:GetPopInSource()
    return self.continuityTaskContent
end
local gp = setmetatable({ continuityTaskContent = newGameObjectUdata(uContent) }, GoPage)
gp.class = GoPage
n = ItemPopIn.PlayPage(gp)
Check(#errors == 0, "不该报错，实际：" .. tostring(errors[1]))
Check(n == 1, "userdata 容器算 1 个列表，实际 " .. n)
Check(liveTweens() == 2, "3 个子节点里 1 个 inactive ⇒ 播 2 项，实际 " .. liveTweens())
Check(Near(u1.localScale.x, 0.82) and Near(u2.localScale.x, 0.82), "userdata 容器项从 0.82 起")
Check(Near(u3.localScale.x, 1), "隐藏的模板行不该被动过")
ItemPopIn.StopPage(gp)
Check(Near(u1.localScale.x, 1), "StopPage 对 userdata 容器同样复位")

-- ---------------- case 7: 绑定缓存 ----------------
print("== case7 同一页复用绑定 ==")
tweens = {}
local items7 = { newItem("k1"), newItem("k2") }
local page7 = { scrollView = newScrollView(items7) }
Check(ItemPopIn.PlayPage(page7) == 1, "第一次接上 1 个")
page7.scrollView = nil    -- 之后再扫也扫不到
Check(ItemPopIn.PlayPage(page7) == 1, "第二次仍复用第一次的绑定，返回 1")
Check(liveTweens() == 2, "仍按原列表播 2 条（上一轮被 Kill），实际 " .. liveTweens())

-- ---------------- case 8: 重播不叠加 ----------------
print("== case8 重播不叠加 ==")
tweens = {}
local items8 = { newItem("p1") }
local page8 = { scrollView = newScrollView(items8) }
ItemPopIn.PlayPage(page8)
ItemPopIn.PlayPage(page8)
Check(countTweenOn(items8[1]) == 1, "同一时刻只有 1 条存活 tween，实际 " .. countTweenOn(items8[1]))
Check(Near(items8[1].localScale.x, 0.82), "重播起点仍是 0.82（不是 0.82²）")

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
