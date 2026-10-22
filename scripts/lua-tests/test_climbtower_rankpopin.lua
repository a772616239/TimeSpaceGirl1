-- 离线验证爬塔两个排行榜弹窗的列表入场动画（不依赖 Unity，直接 luajit 跑）：
--   ClimbTowerRankPopup      普通爬塔排行榜
--   ClimbTowerEliteRankPopup 高级爬塔排行榜（同一份代码形态）
-- 形态 = 「单 ScrollCycleView + 打开前已请求好数据、OnShow 同步 SetData」，
-- 走 ItemPopIn A 方案 + 一次性标记（docs/ui_item_pop_in_skill.md 3.1 节）。覆盖：
--   ① 接线           OnOpen 置位 / InitComponent 建 popIn（唯一一处）/ OnShow 在 RefreshScroll 之后消费
--                    / OnClose + OnDestroy 都 Stop
--   ② 首轮播一次     打开面板 → 逐格 0.82 起跳、错开 0.055、顺序 = 版面顺序
--   ③ 消费一次       OnShow 再被调（数据回调刷新 / 同屏刷新）不重播
--   ④ 重新打开       OnOpen 重新置位 → 再播（玩家主动换屏）
--   ⑤ 空榜           没有 item 时 Play no-op、不炸、不空耗标记
--   ⑥ 生命周期       OnClose / OnDestroy 必须回收（Kill + 复位到 1）
--   ⑦ 峰值几何       prefab 实测 item 1034 / 视口 1080 ⇒ 缺省 peak 1.02 不越界（skill 第 4 节公式）
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_climbtower_rankpopin.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local PANELS = {
    { name = "ClimbTowerRankPopup",
      src = ROOT .. "Assets/ManagedResources/~Lua/Modules/ClimbTower/ClimbTowerRankPopup.lua",
      prefab = ROOT .. "Assets/ManagedResources/Prefabs/UI/ClimbTower/ClimbTowerRankPopup.prefab",
      rankField = "serverRankData" },
    { name = "ClimbTowerEliteRankPopup",
      src = ROOT .. "Assets/ManagedResources/~Lua/Modules/ClimbTower/ClimbTowerEliteRankPopup.lua",
      prefab = ROOT .. "Assets/ManagedResources/Prefabs/UI/ClimbTower/ClimbTowerEliteRankPopup.prefab",
      rankField = "serverRankData_Advance" },
}
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
    if type(a) == "number" then a, b = b, a end
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

local popInModule
function require(path)
    if path == "Modules/Common/ItemPopIn" then
        if not popInModule then popInModule = assert(loadfile(POPIN))() end
        return popInModule
    end
    return {}
end

local tweens = {}
local function newTween(tf, endv, dur)
    local t = { tf = tf, endv = endv, dur = dur, delay = 0, ease = nil, onComplete = nil, killed = false }
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

-- 榜单行根节点：prefab 里 ItemPre 只挂 224（纯 RectTransform），无 Animator/Image ⇒ 可以安全缩放
local function newRow(name)
    local o = { name = name, activeSelf = true, localScale = v3(1, 1, 1) }
    o.transform = o
    function o:DOScale(v, dur) return newTween(self, v, dur) end
    function o:SetActive(v) self.activeSelf = v and true or false end
    return o
end

-- 复刻 ScrollCycleView:SetData（同步克隆 item）+ ForeachItemGO
local function newScrollView()
    local sv = { goItemList = {}, dataCount = 0 }
    function sv:ForeachItemGO(func)
        if not func then return end
        for i = 1, math.min(#self.goItemList, self.dataCount) do
            func(i, self.goItemList[i])
        end
    end
    function sv:SetData(datas, cb)
        self.goItemList = {}
        self.dataCount = #datas
        for i = 1, #datas do
            self.goItemList[i] = newRow("row" .. i)
            if cb then cb(i, self.goItemList[i]) end
        end
    end
    function sv:SetIndex(i) self.index = i end
    return sv
end

local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- ---------------- 逐面板跑一遍 ----------------
local function RunPanel(cfg)
    print(("\n==== %s ===="):format(cfg.name))

    local srcLines = {}
    for line in io.lines(cfg.src) do srcLines[#srcLines + 1] = line end
    local text = table.concat(srcLines, "\n")
    local function countLines(pat)
        local n = 0
        for _, l in ipairs(srcLines) do if l:match(pat) then n = n + 1 end end
        return n
    end

    -- ---------------- case1: 接线扫描 ----------------
    print("== case1 接线 ==")
    Check(countLines("^%s*this%.listPopPending = true") == 1, "listPopPending 置位应只有 1 处（OnOpen）")
    Check(countLines("^%s*this%.popIn = ItemPopIn%.New") == 1, "popIn 创建应只有 1 处（InitComponent）")
    Check(countLines("^%s*this%.popIn:Stop%(%)") == 2,
          "popIn:Stop 应有 2 处（OnClose + OnDestroy），实际 " .. countLines("^%s*this%.popIn:Stop%(%)"))
    Check(text:find("function this%.TryPlayListPopIn") ~= nil, "TryPlayListPopIn 应有定义")
    Check(text:find("local ItemPopIn = require%(\"Modules/Common/ItemPopIn\"%)") ~= nil, "应 require 唯一实现（不复制配方）")
    -- OnShow 里 TryPlayListPopIn 必须排在 RefreshScroll 之后（SetData 之后才认得到 item）
    local showBody = text:match("function " .. cfg.name .. ":OnShow%(%)%s*\n(.-)\nend")
    local posRefresh = showBody and showBody:find("this:RefreshScroll", 1, true)
    local posPlay = showBody and showBody:find("this:TryPlayListPopIn", 1, true)
    Check(posRefresh ~= nil and posPlay ~= nil and posPlay > posRefresh,
          "OnShow 里 TryPlayListPopIn 必须在 RefreshScroll 之后")

    -- ---------------- load 真面板源码 ----------------
    local Panel = assert(loadfile(cfg.src))()
    Panel.scrollView = newScrollView()
    Panel.popIn = require("Modules/Common/ItemPopIn").New(function() return Panel.scrollView end)
    Panel.noneImage = { SetActive = function() end }
    Panel.SetRankingMyItemInfo = function() end  -- 底部「我的排名」行，与列表动画无关
    Panel.SetRankingItemInfo = function() end    -- 行内容渲染（头像/名次/立绘），离线不需要
    ClimbTowerManager = {
        ClimbTowerType = { Normal = 1, Advance = 2 },  -- Elite 的 OnShow 传 Advance 取高级榜
        serverRankData = { myRankInfo = {} },
        serverRankData_Advance = { myRankInfo = {} },
        GetSortRanks = function() return Panel.rankDatas end,
    }

    local function rows(n)
        local datas = {}
        for i = 1, n do datas[i] = { rankInfo = { rank = i } } end
        return datas
    end

    -- ---------------- case2: 首轮播一次 ----------------
    print("== case2 首轮播一次 ==")
    tweens = {}
    Panel.rankDatas = rows(5)
    Panel:OnOpen()   -- 玩家主动打开
    Panel:OnShow()   -- SetRankingMyItemInfo → GetSortRanks → RefreshScroll(SetData) → TryPlayListPopIn
    Check(Panel.listPopPending == false, "首轮应消费掉一次性标记")
    Check(Panel.scrollView.index == 1, "RefreshScroll(1) 应把列表回第一页")
    Check(#tweens == 5, "应创建 5 条放大 tween，实际 " .. #tweens)
    Check(liveTweens() == 5, "5 条都应在跑，实际 " .. liveTweens())
    for i, t in ipairs(tweens) do
        Check(t.tf == Panel.scrollView.goItemList[i], ("第 %d 条应绑定第 %d 行（顺序=版面顺序）"):format(i, i))
        Check(Near(t.delay, (i - 1) * 0.055), ("第 %d 行延迟应为 %.3f，实际 %.3f"):format(i, (i - 1) * 0.055, t.delay))
        Check(Near(Panel.scrollView.goItemList[i].localScale.x, 0.82),
              ("第 %d 行起始缩放应为 0.82，实际 %s"):format(i, Panel.scrollView.goItemList[i].localScale.x))
    end

    -- ---------------- case3: 消费一次（同屏刷新不重播） ----------------
    print("== case3 同屏刷新不重播 ==")
    for _, t in ipairs(tweens) do t:Complete() end
    Check(Near(Panel.scrollView.goItemList[1].localScale.x, 1), "播完第 1 行应落回 1")
    tweens = {}
    Panel.rankDatas = rows(20)
    Panel:OnShow()   -- 数据回调刷新 / 从子面板返回：只走 OnShow，不经 OnOpen
    Check(#tweens == 0, "不经 OnOpen 的 OnShow 不应重播，实际 " .. #tweens)
    for i = 1, 5 do
        Check(Near(Panel.scrollView.goItemList[i].localScale.x, 1), ("刷新后第 %d 行应保持基准 1"):format(i))
    end

    -- ---------------- case4: 重新打开会再播 ----------------
    print("== case4 重新打开 ==")
    tweens = {}
    Panel.rankDatas = rows(8)
    Panel:OnOpen()
    Panel:OnShow()
    Check(#tweens == 8, "重新置位后应再播 8 条，实际 " .. #tweens)
    local last = tweens[#tweens]
    Check(Near(last.delay, 7 * 0.055), ("8 行未超 maxSpan，末行延迟应=%.3f，实际 %.4f"):format(7 * 0.055, last.delay))
    print(("  8 行：首行 0 / 末行 %.3f / 含单张总时长 %.3f"):format(last.delay, last.delay + last.dur + 0.12))

    -- 多行会压进 maxSpan（0.55）
    tweens = {}
    Panel.rankDatas = rows(30)
    Panel:OnOpen()
    Panel:OnShow()
    local tail = tweens[#tweens]
    Check(tail.delay <= 0.55 + 1e-6, ("30 行末行延迟应压进 maxSpan 0.55，实际 %.3f"):format(tail.delay))

    -- ---------------- case5: 空榜 ----------------
    print("== case5 空榜 ==")
    tweens = {}
    Panel.rankDatas = {}
    Panel:OnOpen()
    Panel:OnShow()
    Check(#tweens == 0, "空榜不应建 tween")
    Check(Panel.listPopPending == false, "空榜也把标记消费掉（不会在下次刷新时突然补弹）")

    -- ---------------- case6: 生命周期回收 ----------------
    print("== case6 生命周期 ==")
    tweens = {}
    Panel.rankDatas = rows(5)
    Panel:OnOpen()
    Panel:OnShow()
    Check(liveTweens() > 0, "Stop 前应有存活 tween")
    Panel:OnClose()
    Check(liveTweens() == 0, "OnClose 后不应有存活 tween，实际 " .. liveTweens())
    Check(Panel.listPopPending == false, "OnClose 后标记应清掉")
    for i = 1, 5 do
        Check(Near(Panel.scrollView.goItemList[i].localScale.x, 1),
              ("OnClose 后第 %d 行必须复位到 1，否则永久停在半截"):format(i))
    end

    tweens = {}
    Panel.rankDatas = rows(3)
    Panel:OnOpen()
    Panel:OnShow()
    Panel:OnDestroy()
    Check(liveTweens() == 0, "OnDestroy 后不应有存活 tween，实际 " .. liveTweens())

    -- ---------------- case7: 峰值几何（skill 第 4 节公式） ----------------
    print("== case7 峰值几何 ==")
    local f = io.open(cfg.prefab, "r")
    if f then
        local raw = f:read("*a")
        f:close()
        -- ItemPre = 1034 宽；ScrollParentView = 1080 宽（sizeDelta.x）
        local itemW = tonumber(raw:match("m_SizeDelta: {x: (1034%.?%d*), y: 19[46]"))
        local viewW = tonumber(raw:match("m_SizeDelta: {x: (1080), y: %-860"))
        Check(itemW ~= nil and Near(itemW, 1034), "ItemPre 宽应为 1034，实际 " .. tostring(itemW))
        Check(viewW ~= nil and Near(viewW, 1080), "ScrollParentView 宽应为 1080，实际 " .. tostring(viewW))
        if itemW and viewW then
            local edge = (itemW * 1.02 - viewW) / 2
            Check(edge <= 0, ("缺省 peak=1.02 时每侧余量 %.1fpx（≤0 即不越界），列表无 Mask 也安全"):format(-edge))
            local maxPeak = viewW / itemW
            print(("  几何上限 peak = %.4f（再高就画出屏幕外）"):format(maxPeak))
        end
    else
        Check(false, "读不到 prefab：" .. cfg.prefab)
    end
end

for _, cfg in ipairs(PANELS) do
    RunPanel(cfg)
end

print("")
print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
