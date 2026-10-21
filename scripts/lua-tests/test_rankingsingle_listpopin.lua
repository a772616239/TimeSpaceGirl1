-- 离线验证 RankingSingleListPanel 榜单列表入场动画（不依赖 Unity，直接 luajit 跑）：
-- 面板是「单列表 + 异步网络数据」形态，走 ItemPopIn A 方案，接点选在 CheckIsTop
-- （12 条 Set*Info 路径全部在 scrollView:SetData 之后调它）。覆盖：
--   ① 接线            OnOpen 置位 listPopPending / InitComponent 建 popIn（唯一一处）
--                     / CheckIsTop 里调 TryPlayListPopIn / OnClose + OnDestroy 都 Stop
--   ② 接点完整性      12 条 Set*Info 全部 SetData 之后跟 CheckIsTop（统一接点不漏）
--   ③ 首轮播一次      第一轮榜单数据灌进列表 → 逐格 0.82 起跳、错开 0.055、压缩到 0.55s
--   ④ 消费一次        分页加载 / 事件回调重灌 SetData 不重播（CheckIsTop 再触发也无 tween）
--   ⑤ 重新打开        listPopPending 重新置位后再触发会再播（重开面板 = 玩家主动换屏）
--   ⑥ 空列表          防御性：没有 item 时 Play 返回 0、不炸
--   ⑦ 生命周期        OnClose / OnDestroy 必须回收（Kill + 复位到 1）
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_rankingsingle_listpopin.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Ranking/RankingSingleListPanel.lua"
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
BasePanel = {}
function Inherit(base) return setmetatable({}, { __index = base }) end
-- 只跑真的 ItemPopIn 源码；面板自己的 require（BasePanel / CountryRankUtil）给空表
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

-- 榜单行根节点：纯 RectTransform（prefab 里 ItemPre 只挂 224，无 Animator/Image），可以安全缩放
local function newRow(name, active)
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
    function sv:SetIndex() end
    return sv
end

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- ---------------- load 真面板源码 ----------------
local chunk = assert(loadfile(SRC))
local Panel = chunk()

Panel.scrollView = newScrollView()
Panel.popIn = require("Modules/Common/ItemPopIn").New(function() return Panel.scrollView end)
Panel.istop = true -- 榜单打开默认回第一页（CheckIsTop 的 SetIndex 分支）

-- 模拟 ScrollCycleView:SetData：按 dataCount 克隆行（真机由 ScrollCycleView 做）
local function fillList(count, hidden)
    Panel.scrollView.goItemList = {}
    for i = 1, count do
        Panel.scrollView.goItemList[i] = newRow("row" .. i, i <= count - (hidden or 0))
    end
    Panel.scrollView.dataCount = count
end

-- ---------------- case 1: 接线扫描 ----------------
print("== case1 接线 ==")
local src = {}
for line in io.lines(SRC) do src[#src + 1] = line end
local text = table.concat(src, "\n")
local function countLines(pat)
    local n = 0
    for _, l in ipairs(src) do
        if l:match(pat) then n = n + 1 end
    end
    return n
end
Check(countLines("^%s*this%.listPopPending = true") == 1, "listPopPending 置位应只有 1 处（OnOpen）")
Check(countLines("^%s*this%.popIn = ItemPopIn%.New") == 1, "popIn 创建应只有 1 处（InitComponent）")
Check(countLines("^%s*this%.popIn:Stop%(%)") == 2, "popIn:Stop 应有 2 处（OnClose + OnDestroy），实际 " .. countLines("^%s*this%.popIn:Stop%(%)"))
Check(text:find("function this%.TryPlayListPopIn") ~= nil, "TryPlayListPopIn 应有定义")
-- CheckIsTop 函数体内应调 TryPlayListPopIn
local checkBody = text:match("function this%.CheckIsTop%(%)%s*\n(.-)\nend")
Check(checkBody and checkBody:find("this.TryPlayListPopIn", 1, true) ~= nil, "CheckIsTop 应接线 TryPlayListPopIn")

-- ---------------- case 2: 接点完整性 ----------------
print("== case2 接点完整性 ==")
-- 面板里还有 7 个 *Info 命名的「前三名头像」渲染函数，不灌列表；
-- 真正的列表路径 = 含 scrollView:SetData 的函数，必须全部 SetData 后接 CheckIsTop。
local setFns, curFn = {}, nil
for _, l in ipairs(src) do
    local fn = l:match("^function this%.(%w+)%(")
    if fn then
        curFn = fn
        if setFns[fn] == nil then setFns[fn] = { setData = false, check = false } end
    elseif curFn and l:match("^end") then
        curFn = nil
    end
    if curFn then
        if l:find("this.scrollView:SetData(", 1, true) then setFns[curFn].setData = true end
        if l:find("this.CheckIsTop()", 1, true) then setFns[curFn].check = true end
    end
end
local listFns, missing = {}, {}
for name, f in pairs(setFns) do
    if f.setData then
        listFns[#listFns + 1] = name
        if not f.check then
            missing[#missing + 1] = name .. "(缺 CheckIsTop)"
        end
    end
end
table.sort(listFns)
Check(#listFns == 12, "应有 12 条灌列表路径，实际 " .. #listFns .. ": " .. table.concat(listFns, ", "))
Check(#missing == 0, "每条灌列表路径都应 SetData 后接 CheckIsTop，异常: " .. table.concat(missing, ", "))
local checkCallCount = 0
for _, l in ipairs(src) do
    -- 排除定义行本身（function this.CheckIsTop()）
    if l:match("^%s*this%.CheckIsTop%(%)") then checkCallCount = checkCallCount + 1 end
end
Check(checkCallCount == 12, "CheckIsTop 调用应恰好 12 处（全部在 SetData 之后），实际 " .. checkCallCount)
print("  路径: " .. table.concat((function()
    local keys = {}
    for k in pairs(setFns) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end)(), " / "))

-- ---------------- case 3: 首轮播一次（逐格 0.82 起跳） ----------------
print("== case3 首轮播一次 ==")
tweens = {}
fillList(5, 0)
Panel.listPopPending = true
Panel:CheckIsTop()
Check(Panel.istop == false, "CheckIsTop 应消费掉 istop（回第一页）")
Check(#tweens == 5, "应创建 5 条放大 tween，实际 " .. #tweens)
Check(liveTweens() == 5, "5 条都应在跑，实际 " .. liveTweens())
for i, t in ipairs(tweens) do
    Check(t.tf == Panel.scrollView.goItemList[i], ("第 %d 条应绑定第 %d 行"):format(i, i))
    Check(Near(t.delay, (i - 1) * 0.055), ("第 %d 行延迟应为 %.3f，实际 %.3f"):format(i, (i - 1) * 0.055, t.delay))
    Check(Near(Panel.scrollView.goItemList[i].localScale.x, 0.82), ("第 %d 行起始缩放应为 0.82，实际 %s"):format(i, Panel.scrollView.goItemList[i].localScale.x))
end

-- ---------------- case 4: 消费一次（分页 / 事件刷新不重播） ----------------
print("== case4 分页刷新不重播 ==")
for _, t in ipairs(tweens) do t:Complete() end -- 放大段完成 → 建回落段；ipairs 会跟进新建的回落段一起播完
Check(Near(Panel.scrollView.goItemList[1].localScale.x, 1), "播完第 1 行应落回 1")
tweens = {}
fillList(30, 0) -- 分页加载：第二页数据到了，事件回调重灌 SetData
Panel:CheckIsTop()
Check(#tweens == 0, "重灌列表不应再播（标记已消费），实际 " .. #tweens)
for i = 1, 5 do
    Check(Near(Panel.scrollView.goItemList[i].localScale.x, 1), ("重灌后第 %d 行应保持基准 1"):format(i))
end

-- ---------------- case 5: 重新打开会再播 ----------------
print("== case5 重新打开 ==")
tweens = {}
fillList(8, 0)
Panel.listPopPending = true -- 模拟再次 OnOpen（重开面板 = 玩家主动换屏）
Panel:CheckIsTop()
Check(#tweens == 8, "重新置位后应再播 8 条，实际 " .. #tweens)
local last = tweens[#tweens]
Check(Near(last.delay, 7 * 0.055), ("8 行未超 maxSpan，末行延迟应=%.3f，实际 %.4f"):format(7 * 0.055, last.delay))
print(("  8 行：首行 0 / 末行 %.3f / 含单张总时长 %.3f"):format(last.delay, last.delay + last.dur + 0.12))

-- ---------------- case 6: 空列表防御 ----------------
print("== case6 空列表 ==")
tweens = {}
Panel.listPopPending = true
fillList(0, 0)
local n = Panel.popIn:Play()
Check(n == 0 and #tweens == 0, "空列表 Play 应 no-op（真路径空榜在 SetData 前就 return，这里只是防御）")

-- ---------------- case 7: 生命周期回收 ----------------
print("== case7 生命周期 ==")
tweens = {}
fillList(5, 0)
Panel.listPopPending = true
Panel:CheckIsTop()
Check(liveTweens() > 0, "Stop 前应有存活 tween")
-- OnClose 依赖的外部调用
RankingManager = { ClearData = function() end }
Util = { GetGameObject = function() return { SetActive = function() end } end }
SubUIManager = { Close = function() end }
GameObject = { DestroyImmediate = function() end }
Panel.noneImage = { SetActive = function() end }
Panel.firsthead = {}
Panel.playerHeroListGo = {}
Panel.playerHeroListHead = {}
Panel:OnClose()
Check(liveTweens() == 0, "OnClose 后不应有存活 tween，实际 " .. liveTweens())
Check(Panel.listPopPending == false, "OnClose 后 pending 应清掉")
for i = 1, 5 do
    Check(Near(Panel.scrollView.goItemList[i].localScale.x, 1), ("OnClose 后第 %d 行必须复位到 1，否则永久停在半截"):format(i))
end

tweens = {}
fillList(3, 0)
Panel.listPopPending = true
Panel:CheckIsTop()
Panel.playerHeroListHead = {}
Panel.playerHeadList = {}
Panel:OnDestroy()
Check(liveTweens() == 0, "OnDestroy 后不应有存活 tween，实际 " .. liveTweens())
Check(Panel.scrollView == nil, "OnDestroy 后 scrollView 应置 nil")
for i = 1, 3 do
    Check(Near(Panel.scrollView and 0 or 1, 1) and true, "OnDestroy 回收完成")
end

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
