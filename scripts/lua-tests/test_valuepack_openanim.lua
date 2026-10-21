-- 离线验证 ValuePackPanel 卡片入场动画（不依赖 Unity，直接 luajit 跑）：
-- 用假 Util / ScrollCycleView / Vector3 / DOTween 跑真源码 + 真播放逻辑，覆盖
--   ① OnShow          先 SetDataList 再入场（顺序反了卡片还没建，一格都不会动）
--   ② PlayItemPopIn   逐格 0.82 → 1.02 → 1，间隔 0.055s，放大 OutQuad / 回落 InOutQuad
--   ③ 压缩错开        卡片多时整体跨度压到 0.55s
--   ④ 跳过隐藏卡      滚出可视区的卡是 SetActive(false) 的，不占错开时间
--   ⑤ StopItemPopIn   中途回收必须 Kill + 复位（否则卡片永久停在 0.82 / 1.02）
--   ⑥ 重播            不叠加缩放（0.82 而不是 0.82²），同一时刻只有一轮 tween
--   ⑦ 生命周期        OnClose / OnDestroy 必须回收
--   ⑧ 接线            购买后的 SetDataList 刷新不经过 PlayItemPopIn（不整墙重播）
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_valuepack_openanim.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/ValuePack/ValuePackPanel.lua"
local POPIN = ROOT .. "Assets/ManagedResources/~Lua/Modules/Common/ItemPopIn.lua"

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
Vector2 = { zero = { x = 0, y = 0 }, New = function(x, y) return { x = x, y = y } end }
Ease = { Linear = "Linear", InOutQuad = "InOutQuad", OutQuad = "OutQuad" }
IsNull = function() return false end
LogError = function(msg) print("  [LogError] " .. msg) end
function Inherit(base) return setmetatable({}, { __index = base }) end
-- 「逐格放大缩小」的公共模块：这里跑真源码（面板只是薄封装）
local popInModule
function require(path)
    if path == "Modules/Common/ItemPopIn" then
        if not popInModule then
            popInModule = assert(loadfile(POPIN))()
        end
        return popInModule
    end
    return {}
end

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

-- 卡片根节点：只有 Image（无 Animator），与 ValuePackPanel.prefab 的 prefab 节点一致
local function newCard(name, active)
    local o = { name = name, activeSelf = active ~= false, localScale = v3(1, 1, 1) }
    o.transform = o
    function o:DOScale(v, dur) return newTween(self, v, dur) end
    function o:SetActive(v) self.activeSelf = v and true or false end
    return o
end

-- 复刻真 ScrollCycleView:ForeachItemGO（View/ScrollCycleView.lua:466）
local function newScrollView()
    local sv = { goItemList = {}, dataCount = 0 }
    function sv:ForeachItemGO(func)
        if not func or not self.goItemList then return end
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
local chunk = assert(loadfile(SRC))
local Panel = chunk()

local scrollView = newScrollView()
Panel.ScrollView = scrollView
Panel.popIn = require("Modules/Common/ItemPopIn").New(function() return Panel.ScrollView end)
Panel.time = { text = "" }
Panel.HeadFrameView = { OnShow = function() end }
Panel.UpView = { OnOpen = function() end }
Panel.GetData = function() return {} end
UpViewOpenType = { ShowRight = 1 }
PanelType = { Main = 1 }
GetLanguageStrById = function() return "" end
TimeToHMS = function() return "00:00:00" end
CalculateSecondsNowTo_N_OClock = function() return 0 end
PlaySoundWithoutClick = function() end
SoundConfig = { Sound_UICancel = 1 }
Timer = { New = function() return { Start = function() end, Stop = function() end } end }
SubUIManager = { Open = function() return { OnShow = function() end } end, Close = function() end }

-- 数据层用假的：SetDataList 只负责把卡片建进 ScrollView（真机由 ScrollView:SetData 做）
local buildCount = 0
local buildHidden = 0
Panel.SetDataList = function()
    scrollView.goItemList = {}
    for i = 1, buildCount do
        -- 末尾 buildHidden 张模拟被滚出可视区（ScrollCycleView 会 SetActive(false)）
        scrollView.goItemList[i] = newCard("card" .. i, i <= buildCount - buildHidden)
    end
    scrollView.dataCount = buildCount
end

local function cards()
    return scrollView.goItemList
end

-- ---------------- case 1: OnShow 先建卡再入场 ----------------
print("== case1 OnShow 顺序 ==")
tweens = {}
buildCount, buildHidden = 5, 0
Panel:OnShow()
Check(#tweens == 5, "应创建 5 条放大 tween，实际 " .. #tweens)
Check(liveTweens() == 5, "5 条都应在跑，实际 " .. liveTweens())
for i, t in ipairs(tweens) do
    Check(t.tf == cards()[i], ("第 %d 条应绑定第 %d 张卡"):format(i, i))
end

-- ---------------- case 2: 逐格放大缩小 ----------------
print("== case2 逐格放大缩小 ==")
for i, t in ipairs(tweens) do
    Check(Near(t.delay, (i - 1) * 0.055), ("第 %d 张延迟应为 %.3f，实际 %.3f"):format(i, (i - 1) * 0.055, t.delay))
    Check(t.dur == 0.14, "放大段时长应为 0.14，实际 " .. t.dur)
    Check(t.ease == Ease.OutQuad, "放大段 ease 应为 OutQuad")
    Check(Near(t.endv.x, 1.02), "放大段终点应为 1.02（受卡宽/画布边距限制），实际 " .. t.endv.x)
    Check(Near(cards()[i].localScale.x, 0.82), ("第 %d 张起始缩放应为 0.82，实际 %s"):format(i, cards()[i].localScale.x))
end
print(("  5 张，延迟 0 / %.3f / %.3f / 末张 %.3f，单张 0.14+0.12")
    :format(tweens[2].delay, tweens[3].delay, tweens[5].delay))

-- 放大段完成 → 建回落段
local riseTweens = { unpack(tweens) }
for _, t in ipairs(riseTweens) do t:Complete() end
Check(#tweens == 10, "放大完成后应补 5 条回落 tween，实际 " .. #tweens)
for i = 1, 5 do
    local fall = tweens[5 + i]
    Check(fall.dur == 0.12, "回落时长应为 0.12")
    Check(fall.ease == Ease.InOutQuad, "回落 ease 应为 InOutQuad")
    Check(Near(fall.endv.x, 1), "回落终点应为原尺寸 1")
    Check(Near(cards()[i].localScale.x, 1.02), "回落段起始应停在峰值 1.02")
end
for i = 6, 10 do tweens[i]:Complete() end
for i = 1, 5 do
    Check(Near(cards()[i].localScale.x, 1), ("第 %d 张最终应精确落回 1，实际 %s"):format(i, cards()[i].localScale.x))
end

-- ---------------- case 3: 卡片多时压缩错开 ----------------
print("== case3 压缩错开 ==")
Panel:StopItemPopIn()
tweens = {}
buildCount, buildHidden = 12, 0
Panel:OnShow()
Check(#tweens == 12, "应有 12 条，实际 " .. #tweens)
local last = tweens[#tweens]
Check(Near(last.delay, 0.55), ("12 张时末张延迟应压到 0.55，实际 %.4f"):format(last.delay))
print(("  12 张：首张 0 / 末张 %.3f / 含单张总时长 %.3f"):format(last.delay, last.delay + last.dur + 0.12))

-- ---------------- case 4: 跳过隐藏卡 ----------------
print("== case4 跳过隐藏卡 ==")
Panel:StopItemPopIn()
tweens = {}
buildCount, buildHidden = 5, 2          -- 后 2 张被滚出可视区（SetActive(false)）
Panel:OnShow()
Check(#tweens == 3, "只有 3 张可见卡应参与动画，实际 " .. #tweens)
Check(Near(tweens[3].delay, 0.11), "末张延迟应为 0.11，实际 " .. tweens[3].delay)
Check(Near(cards()[4].localScale.x, 1) and Near(cards()[5].localScale.x, 1), "隐藏卡不该被动过")
print("  隐藏卡跳过：3 张可见 → 延迟 0/0.055/0.11")

-- ---------------- case 5: 中途 Stop 必须复位 ----------------
print("== case5 中途 Stop ==")
Check(liveTweens() > 0, "Stop 前应有存活 tween")
Panel:StopItemPopIn()
Check(liveTweens() == 0, "Stop 后不应有存活 tween，实际 " .. liveTweens())
for i = 1, 5 do
    Check(Near(cards()[i].localScale.x, 1), ("Stop 后第 %d 张必须复位到 1，否则永久停在半截"):format(i))
end

-- ---------------- case 6: 重播不叠加 ----------------
print("== case6 重播 ==")
Panel:StopItemPopIn()
tweens = {}
buildCount, buildHidden = 5, 0
Panel:OnShow()
Panel:OnShow()                            -- 再次 OnShow（从别的界面切回来）
Check(liveTweens() == 5, ("重播后应只剩一轮 5 条存活，实际 %d"):format(liveTweens()))
Check(Near(cards()[1].localScale.x, 0.82), ("重播起点必须是 0.82（不是 0.82²），实际 %s"):format(cards()[1].localScale.x))
print("  重播：上一轮被 Kill，起点重新从 0.82 起")

-- ---------------- case 7: OnClose / OnDestroy 必须回收 ----------------
print("== case7 生命周期 ==")
Panel:OnClose()
Check(liveTweens() == 0, "OnClose 后不应有存活 tween，实际 " .. liveTweens())
for i = 1, 5 do
    Check(Near(cards()[i].localScale.x, 1), ("OnClose 后第 %d 张应复位 %s"):format(i, cards()[i].localScale.x))
end

tweens = {}
Panel:OnShow()
Panel:OnDestroy()
Check(liveTweens() == 0, "OnDestroy 后不应有存活 tween，实际 " .. liveTweens())
for i = 1, 5 do
    Check(Near(cards()[i].localScale.x, 1), ("OnDestroy 后第 %d 张应复位"):format(i))
end
print("  OnClose / OnDestroy 都回收到位")

-- ---------------- case 8: 接线 —— 购买刷新不重播 ----------------
print("== case8 接线 ==")
local callCount, defCount = 0, 0
for line in io.lines(SRC) do
    if line:match("^%s*this:PlayItemPopIn%(%)") then callCount = callCount + 1 end
    if line:match("^function ValuePackPanel:PlayItemPopIn") then defCount = defCount + 1 end
end
Check(defCount == 1, "PlayItemPopIn 应只有 1 处定义，实际 " .. defCount)
Check(callCount == 1, "PlayItemPopIn 应只在 OnShow 里被调 1 次（SetDataList 刷新不重播），实际 " .. callCount)
print("  唯一调用点在 OnShow")

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
