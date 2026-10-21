-- 离线验证 Modules/Common/ItemPopIn（逐格放大缩小）——不依赖 Unity，直接 luajit 跑：
--   ① Play            每格 基准 → from → peak → 基准，相邻错开 step
--   ② 回落段          由放大段的 OnComplete 建，被 Kill 后不再建
--   ③ 跳过隐藏项      滚出可视区的 item 是 SetActive(false) 的，不占错开时间
--   ④ 压缩错开        item 多时整体跨度压到 maxSpan
--   ⑤ Stop            Kill + 复位（漏复位 = item 永久停在半截缩放）
--   ⑥ 重播            不叠加缩放（from 而不是 from²），同一时刻只有一轮
--   ⑦ 基准缩放        ScrollCycleView 的 itemGoScale≠1 时按基准缩放算，不写死 1
--   ⑧ 异常兜底        ForeachItemGO 抛错 / ScrollView 为 nil 都不炸、不留半截
--   ⑨ 自定义配方      New 的第二参覆盖缺省值
--   ⑩ 数组数据源      { go1, go2, go3 }（固定几格，如千抽的三张卡）/ 元素也可以是 transform
--   ⑪ duang 模式      单段 from→基准 + OutElastic，只建 1 条 tween；Play(n) 只弹第 n 格
--   ⑫ 整批延迟        cfg.delay 让第二批复用同一配方、错开起播（卡片先、数字后）
--   ⑬ phases 模式     按关键帧逐段播（浮起—按回—落定），段数/峰值/时长/缓动全由调用方给
--   ⑭ 偏心 pivot      pivot≠(0.5,0.5) 的 item 临时居中再缩放（位置补偿 ½ 尺寸），Stop 还原
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_itempopin.lua

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
Vector2 = { New = function(x, y) return { x = x, y = y } end }
Ease = { Linear = "Linear", InOutQuad = "InOutQuad", OutQuad = "OutQuad",
         OutCubic = "OutCubic", OutElastic = "OutElastic" }
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

local function newItem(name, active, baseScale)
    local o = { name = name, activeSelf = active ~= false,
                localScale = v3(baseScale or 1, baseScale or 1, baseScale or 1),
                -- RectTransform 四件套：pivot / rect / anchoredPosition 供「居中缩放」用
                pivot = { x = 0.5, y = 0.5 },
                anchoredPosition = { x = 0, y = 0 },
                rect = { width = 100, height = 50 } }
    o.transform = o
    function o:DOScale(v, dur) return newTween(self, v, dur) end
    return o
end

local function newScrollView(items)
    local sv = { goItemList = items, dataCount = #items }
    function sv:ForeachItemGO(func)
        for i = 1, math.min(#self.goItemList, self.dataCount) do
            func(i, self.goItemList[i])
        end
    end
    return sv
end

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- ---------------- load ----------------
local ItemPopIn = assert(loadfile(SRC))()

local function newPlayer(sv, cfg)
    return ItemPopIn.New(function() return sv end, cfg)
end

-- ---------------- case 1: 逐格放大 ----------------
print("== case1 Play 逐格放大 ==")
tweens = {}
local items = {}
for i = 1, 4 do items[i] = newItem("i" .. i) end
local p = newPlayer(newScrollView(items))
p:Play()
Check(#tweens == 4, "应创建 4 条放大 tween，实际 " .. #tweens)
for i, t in ipairs(tweens) do
    Check(t.tf == items[i], ("第 %d 条应绑定第 %d 项"):format(i, i))
    Check(Near(t.delay, (i - 1) * 0.055), ("第 %d 项延迟应为 %.3f，实际 %.3f"):format(i, (i - 1) * 0.055, t.delay))
    Check(t.dur == 0.14, "放大段时长应为 0.14")
    Check(t.ease == Ease.OutQuad, "放大段 ease 应为 OutQuad")
    Check(Near(t.endv.x, 1.02), "放大段终点应为 1.02，实际 " .. t.endv.x)
    Check(Near(items[i].localScale.x, 0.82), ("第 %d 项起始应为 0.82，实际 %s"):format(i, items[i].localScale.x))
end
print("  4 项：0.82 → 1.02，延迟 0/0.055/0.11/0.165")

-- ---------------- case 2: 回落段 ----------------
print("== case2 回落段由 OnComplete 建 ==")
local rises = { unpack(tweens) }
for _, t in ipairs(rises) do t:Complete() end
Check(#tweens == 8, "放大完成后应补 4 条回落，实际 " .. #tweens)
for i = 1, 4 do
    local fall = tweens[4 + i]
    Check(fall.dur == 0.12, "回落时长应为 0.12")
    Check(fall.ease == Ease.InOutQuad, "回落 ease 应为 InOutQuad")
    Check(Near(fall.endv.x, 1), "回落终点应为基准 1")
    Check(Near(items[i].localScale.x, 1.02), "回落起点应停在峰值 1.02")
end
for i = 5, 8 do tweens[i]:Complete() end
for i = 1, 4 do
    Check(Near(items[i].localScale.x, 1), ("第 %d 项最终应落回 1"):format(i))
end

-- ---------------- case 3: 跳过隐藏项 ----------------
print("== case3 跳过隐藏项 ==")
tweens = {}
local mixed = { newItem("a"), newItem("b", false), newItem("c"), newItem("d", false) }
p = newPlayer(newScrollView(mixed))
p:Play()
Check(#tweens == 2, "只有 2 项可见，实际 " .. #tweens)
Check(Near(mixed[1].localScale.x, 0.82) and Near(mixed[3].localScale.x, 0.82), "可见项从 0.82 起")
Check(Near(mixed[2].localScale.x, 1) and Near(mixed[4].localScale.x, 1), "隐藏项不该被动过")
Check(Near(tweens[2].delay, 0.055), "错开只按可见项计数（第 2 项 0.055），实际 " .. tweens[2].delay)
print("  4 项里 2 项隐藏 → 只有 2 条 tween，延迟 0/0.055")

-- ---------------- case 4: 压缩错开 ----------------
print("== case4 压缩错开 ==")
tweens = {}
local many = {}
for i = 1, 20 do many[i] = newItem("m" .. i) end
p = newPlayer(newScrollView(many))
p:Play()
Check(#tweens == 20, "应有 20 条，实际 " .. #tweens)
Check(Near(tweens[20].delay, 0.55), "末项延迟应压到 0.55，实际 " .. tweens[20].delay)
print(("  20 项：step 从 0.055 压到 %.4f，末项 %.2f"):format(0.55 / 19, tweens[20].delay))

-- ---------------- case 5: Stop 复位 ----------------
print("== case5 Stop ==")
Check(liveTweens() > 0, "Stop 前应有存活 tween")
p:Stop()
Check(liveTweens() == 0, "Stop 后不应有存活 tween，实际 " .. liveTweens())
for i = 1, 20 do
    if not Near(many[i].localScale.x, 1) then
        Check(false, "Stop 后第 " .. i .. " 项应复位")
        break
    end
end
Check(Near(many[1].localScale.x, 1) and Near(many[20].localScale.x, 1), "Stop 后全部复位到基准")

-- 被 Kill 的放大段不会建回落段
tweens = {}
p = newPlayer(newScrollView(many))
p:Play()
local risen = { unpack(tweens) }
p:Stop()
for _, t in ipairs(risen) do t:Complete() end
Check(#tweens == #risen, "被 Kill 的放大段不该补建回落段，实际多出 " .. (#tweens - #risen))

-- ---------------- case 6: 重播不叠加 ----------------
print("== case6 重播 ==")
tweens = {}
items = {}
for i = 1, 3 do items[i] = newItem("i" .. i) end
p = newPlayer(newScrollView(items))
p:Play()
p:Play()
Check(liveTweens() == 3, ("重播后应只剩 3 条存活，实际 %d"):format(liveTweens()))
Check(Near(items[1].localScale.x, 0.82), "重播起点仍是 0.82（不是 0.82²），实际 " .. items[1].localScale.x)
print("  上一轮被 Kill，起点重新从 0.82 起")

-- ---------------- case 7: 基准缩放 ----------------
print("== case7 基准缩放 itemGoScale≠1 ==")
tweens = {}
local scaled = { newItem("s1", true, 0.8), newItem("s2", true, 0.8) }
p = newPlayer(newScrollView(scaled))
p:Play()
Check(Near(scaled[1].localScale.x, 0.8 * 0.82), "起点应按基准缩放算（0.8*0.82），实际 " .. scaled[1].localScale.x)
Check(Near(tweens[1].endv.x, 0.8 * 1.02), "峰值应按基准缩放算（0.8*1.02），实际 " .. tweens[1].endv.x)
tweens[1]:Complete()
Check(Near(scaled[1].localScale.x, 0.8 * 1.02), "回落起点为峰值")
tweens[#tweens]:Complete()
Check(Near(scaled[1].localScale.x, 0.8), "最终落回基准 0.8，不是 1")
p:Stop()
Check(Near(scaled[1].localScale.x, 0.8), "Stop 也复位到基准 0.8")

-- ---------------- case 8: 异常兜底 ----------------
print("== case8 异常兜底 ==")
tweens = {}
errors = {}
-- ScrollView 还没建（getScrollView 返 nil）
local pNil = ItemPopIn.New(function() return nil end)
pNil:Play()
Check(#tweens == 0, "ScrollView 为 nil 时不该建 tween")
-- 没有 ForeachItemGO（比如面板传错了对象）
local pBad = ItemPopIn.New(function() return {} end)
pBad:Play()
Check(#tweens == 0, "没有 ForeachItemGO 时不该建 tween")
-- 遍历里抛错
local boom = { goItemList = { newItem("x") }, dataCount = 1,
               ForeachItemGO = function() error("boom") end }
local pBoom = ItemPopIn.New(function() return boom end)
pBoom:Play()
Check(#errors == 1, "遍历抛错应 LogError 一次，实际 " .. #errors)
Check(Near(boom.goItemList[1].localScale.x, 1), "抛错后 item 不该停在半截")
print("  nil / 无 ForeachItemGO / 抛错 都不炸，也不留半截缩放")

-- ---------------- case 9: 自定义配方 ----------------
print("== case9 自定义配方 ==")
tweens = {}
items = {}
for i = 1, 3 do items[i] = newItem("c" .. i) end
p = newPlayer(newScrollView(items), { from = 0.9, peak = 1.05, step = 0.1, maxSpan = 1 })
p:Play()
Check(Near(items[1].localScale.x, 0.9), "起点应为自定义 0.9，实际 " .. items[1].localScale.x)
Check(Near(tweens[1].endv.x, 1.05), "峰值应为自定义 1.05，实际 " .. tweens[1].endv.x)
Check(Near(tweens[3].delay, 0.2), "间隔应为自定义 0.1（第 3 项 0.2），实际 " .. tweens[3].delay)
print("  from/peak/step 可覆盖（窄 item 允许更大的峰值）")

-- ---------------- case 10: 数组数据源 ----------------
print("== case10 数组数据源（固定几格）==")
tweens = {}
local cards = { newItem("card1"), newItem("card2"), newItem("card3") }
p = ItemPopIn.New(function() return cards end)
p:Play()
Check(#tweens == 3, "数组源应建 3 条 tween，实际 " .. #tweens)
Check(tweens[1].tf == cards[1] and tweens[3].tf == cards[3], "数组顺序就是版面顺序")
Check(Near(cards[1].localScale.x, 0.82), "数组源也按 from 起")
-- 元素是 Transform（只有 gameObject、没有 transform）也认
tweens = {}
local trItems = { newItem("tr1"), newItem("tr2") }
for _, it in ipairs(trItems) do
    it.gameObject = it
    it.transform = nil      -- 模拟 Transform：有 gameObject，没有 transform
end
p = ItemPopIn.New(function() return trItems end)
p:Play()
Check(#tweens == 2, "Transform 数组也能收集，实际 " .. #tweens)
-- 隐藏项跳过
tweens = {}
local mixedArr = { newItem("v1"), newItem("v2", false), newItem("v3") }
p = ItemPopIn.New(function() return mixedArr end, { mode = "duang" })
p:Play()
Check(#tweens == 2, "数组里隐藏项跳过，实际 " .. #tweens)
Check(Near(mixedArr[2].localScale.x, 1), "隐藏项不该被动过")
print("  card1..3 这种显式数组能播；顺序/隐藏项同 ScrollCycleView 语义")

-- ---------------- case 11: duang 模式 ----------------
print("== case11 duang 模式 ==")
tweens = {}
items = {}
for i = 1, 3 do items[i] = newItem("d" .. i) end
p = ItemPopIn.New(function() return items end,
    { mode = "duang", from = 0.5, duangDuration = 0.55, ease = "OutElastic", step = 0.09 })
p:Play()
Check(#tweens == 3, "duang 每格只建 1 条 tween（不是两段），实际 " .. #tweens)
Check(tweens[1].ease == Ease.OutElastic, "duang 的 ease 应为 OutElastic")
Check(tweens[1].dur == 0.55, "duang 时长应取 duangDuration，实际 " .. tostring(tweens[1].dur))
Check(Near(tweens[1].endv.x, 1), "duang 终点是基准 1，实际 " .. tweens[1].endv.x)
Check(Near(items[1].localScale.x, 0.5), "duang 起点 0.5，实际 " .. items[1].localScale.x)
Check(Near(tweens[3].delay, 0.18), "duang 的错开 0.09（第 3 格 0.18），实际 " .. tweens[3].delay)
tweens[1]:Complete()
Check(Near(items[1].localScale.x, 1), "duang 结束落回基准")
Check(#tweens == 3, "duang 不补建回落段，实际多出 " .. (#tweens - 3))
-- Play(n) 只弹第 n 格
tweens = {}
p:Play(2)
Check(#tweens == 1, "Play(2) 只弹 1 格，实际 " .. #tweens)
Check(tweens[1].tf == items[2], "Play(2) 弹的是第 2 格")
Check(Near(items[1].localScale.x, 1) and Near(items[3].localScale.x, 1), "其余两格不动")
Check(Near(tweens[1].delay, 0), "单格播放没有错开延迟，实际 " .. tweens[1].delay)
p:Stop()
Check(Near(items[2].localScale.x, 1), "Stop 复位到基准")
print("  单段 0.5→1 + OutElastic；Play(2) 只弹抽到的那一格")

-- ---------------- case 12: 整批延迟 ----------------
print("== case12 整批延迟 cfg.delay ==")
tweens = {}
items = {}
for i = 1, 4 do items[i] = newItem("n" .. i) end
p = ItemPopIn.New(function() return items end,
    { mode = "duang", from = 0.6, delay = 0.26, step = 0.05, maxSpan = 1 })
p:Play()
Check(Near(tweens[1].delay, 0.26), "第 1 格延迟应含 delay=0.26，实际 " .. tweens[1].delay)
Check(Near(tweens[4].delay, 0.26 + 0.15), "第 4 格 0.26+0.15，实际 " .. tweens[4].delay)
print("  数字格排在卡片之后：同一配方 + delay 即可")

-- ---------------- case 13: phases 模式（多段关键帧）----------------
print("== case13 phases 模式 ==")
tweens = {}
local phItems = { newItem("p1"), newItem("p2") }
local kPhases = {
    { scale = 1.05, duration = 0.38, ease = "OutCubic" },
    { scale = 0.985, duration = 0.24, ease = "InOutQuad" },
    { scale = 1, duration = 0.18, ease = "OutQuad" },
}
p = ItemPopIn.New(function() return phItems end,
    { mode = "phases", from = 0.78, phases = kPhases, step = 0.11, maxSpan = 1 })
p:Play()
Check(#tweens == 2, "每格先建第一段，共 2 条，实际 " .. #tweens)
Check(Near(phItems[1].localScale.x, 0.78), "起点取 cfg.from，实际 " .. phItems[1].localScale.x)
Check(Near(tweens[1].endv.x, 1.05) and tweens[1].dur == 0.38, "第一段 → 1.05 / 0.38s")
Check(tweens[1].ease == Ease.OutCubic, "第一段 ease 取 phases 里给的 OutCubic")
Check(Near(tweens[2].delay, 0.11), "第二格错开 0.11，实际 " .. tweens[2].delay)
tweens[1]:Complete()
Check(#tweens == 3 and Near(tweens[3].endv.x, 0.985), "第二段在上一段的 OnComplete 里建")
tweens[3]:Complete()
Check(#tweens == 4 and Near(tweens[4].endv.x, 1), "第三段落回基准")
tweens[4]:Complete()
Check(Near(phItems[1].localScale.x, 1), "末段收尾吸附到基准")
-- 缺 phases 时退回 surge，不能炸
tweens = {}
p = ItemPopIn.New(function() return phItems end, { mode = "phases", from = 0.9 })
p:Play()
Check(#tweens == 2 and Near(tweens[1].endv.x, 1.02), "phases 空 → 退回 surge 配方")
p:Stop()
print("  三段关键帧逐段建、末段吸附；phases 缺失时退回 surge")

-- ---------------- case 14: 偏心 pivot 也要居中缩放 ----------------
print("== case14 偏心 pivot（居中缩放） ==")
tweens = {}
-- 终身限购 page_9 的 rewardPre：pivot (0,1)、871×265、摆位 (5,-10)
local offc = newItem("rewardPre")
offc.pivot = { x = 0, y = 1 }
offc.rect = { width = 871, height = 265 }
offc.anchoredPosition = { x = 5, y = -10 }
p = ItemPopIn.New(function() return { offc } end)
p:Play()
Check(Near(offc.pivot.x, 0.5) and Near(offc.pivot.y, 0.5), "播放时 pivot 临时挪到中心")
Check(Near(offc.anchoredPosition.x, 5 + 0.5 * 871) and Near(offc.anchoredPosition.y, -10 - 0.5 * 265),
    ("位置反向补偿 ½ 尺寸，实际 (%s, %s)"):format(offc.anchoredPosition.x, offc.anchoredPosition.y))
p:Stop()
Check(Near(offc.pivot.x, 0) and Near(offc.pivot.y, 1), "Stop 后 pivot 还原成 (0,1)")
Check(Near(offc.anchoredPosition.x, 5) and Near(offc.anchoredPosition.y, -10), "Stop 后位置还原（不累计偏移）")
Check(Near(offc.localScale.x, 1), "Stop 后缩放还原")

-- case14b：动画**正常播完**就要还原 pivot，不能等 Stop。
-- ScrollCycleView 的 SetData 会按模板 pivot 用绝对值重写 anchoredPosition，
-- 居中着的 item 被重写就少了 ½ 尺寸补偿 ⇒ 整排跳半个卡宽（限定珍藏页签 25 踩过）。
tweens = {}
p = ItemPopIn.New(function() return { offc } end)
p:Play()
Check(Near(offc.pivot.x, 0.5), "播放中 pivot 在中心")
tweens[1]:Complete()   -- 放大段
tweens[2]:Complete()   -- 回落段
Check(Near(offc.pivot.x, 0) and Near(offc.pivot.y, 1), "播完就有还原 pivot（不等 Stop）")
Check(Near(offc.anchoredPosition.x, 5) and Near(offc.anchoredPosition.y, -10),
    ("播完位置也回到原处，实际 (%s, %s)"):format(offc.anchoredPosition.x, offc.anchoredPosition.y))
p:Stop()
Check(Near(offc.anchoredPosition.x, 5) and Near(offc.anchoredPosition.y, -10),
    "已经还原过的不再重复减补偿（否则会越 Stop 越偏）")

-- case14c：动画期间被滚动过，还原要「相对撤」，不能写回开播时的老位置
-- （ScrollCycleView 换格是 anchoredPosition 加偏移，写回老位置会把它拽回上一格）
tweens = {}
offc.pivot = { x = 0, y = 1 }
offc.anchoredPosition = { x = 5, y = -10 }
p = ItemPopIn.New(function() return { offc } end)
p:Play()
offc.anchoredPosition = { x = offc.anchoredPosition.x, y = offc.anchoredPosition.y - 270 } -- 滚动换到下一格
tweens[1]:Complete()
tweens[2]:Complete()
Check(Near(offc.pivot.y, 1), "滚动后播完同样还原 pivot")
Check(Near(offc.anchoredPosition.y, -10 - 270),
    ("滚动量要保住，实际 y = %s（应为 -280）"):format(offc.anchoredPosition.y))
p:Stop()
Check(Near(offc.anchoredPosition.y, -10 - 270), "Stop 不再动已经还原过的位置")

-- case14d：滚动换格后再重播（Play 会先 Stop），不能把 item 拽回上一格
-- ScrollCycleView 复用 item：同一个 GO 会换到别的数据下标，位置由 SetData 用绝对值重写。
tweens = {}
offc.pivot = { x = 0, y = 1 }
offc.anchoredPosition = { x = 5, y = -10 }
p = ItemPopIn.New(function() return { offc } end)
p:Play()
tweens[1]:Complete()
tweens[2]:Complete()                                     -- 播完：pivot 已还原
offc.anchoredPosition = { x = 0, y = -415 }              -- 换到第 2 格（SetData 写的绝对值）
p:Play()                                                 -- 重播 → 内部先 Stop
Check(Near(offc.pivot.x, 0.5) and Near(offc.pivot.y, 0.5), "重播时重新居中")
Check(Near(offc.anchoredPosition.x, 0 + 0.5 * 871) and Near(offc.anchoredPosition.y, -415 - 0.5 * 265),
    ("Stop 只撤自己的补偿、按当前格算，实际 (%s, %s)"):format(offc.anchoredPosition.x, offc.anchoredPosition.y))
p:Stop()
-- 中心 pivot 不该被动过
tweens = {}
local centered = newItem("centered")
p = ItemPopIn.New(function() return { centered } end)
p:Play()
Check(Near(centered.anchoredPosition.x, 0) and Near(centered.anchoredPosition.y, 0), "本来居中的 item 不动位置")
p:Stop()
-- cfg.centerPivot = false 时保持模板原点
tweens = {}
offc.pivot = { x = 0, y = 1 }
offc.anchoredPosition = { x = 5, y = -10 }
p = ItemPopIn.New(function() return { offc } end, { centerPivot = false })
p:Play()
Check(Near(offc.pivot.x, 0) and Near(offc.pivot.y, 1), "centerPivot=false 时不改 pivot")
Check(Near(offc.anchoredPosition.x, 5), "centerPivot=false 时不动位置")
p:Stop()
-- plain Transform（没有 pivot 字段）不能炸
tweens = {}
errors = {}
local plain = { name = "plain", activeSelf = true, localScale = v3(1, 1, 1) }
plain.transform = plain
plain.gameObject = plain
function plain:DOScale(v, dur) return newTween(self, v, dur) end
p = ItemPopIn.New(function() return { plain } end)
p:Play()
Check(#errors == 0 and #tweens == 1, "非 UI 节点（无 pivot）跳过居中处理，照常缩放")
p:Stop()
print("  偏心 pivot 临时居中 + 位置补偿，Stop 全部还原")

-- 取数据源抛错也不炸
tweens = {}
errors = {}
local pThrow = ItemPopIn.New(function() error("no grid") end)
pThrow:Play()
Check(#tweens == 0 and #errors == 1, "取数据源抛错应 LogError 一次且不建 tween")

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
