-- CardActivityPanel 五页签「长列表入场」接线回归（纯文本断言，不依赖 Unity）：
--   ① 面板：OnPageTabChange 里有播（首开 OnShow → ChangeTab 也走这条）⇒ 每个页签都会播
--   ② 面板：OnClose / OnDestroy 都回收（漏了 = item 永久停在半截缩放）
--   ③ 🔴 page_1（DrawCardPanel）被批量跳过 —— 它唯一的长列表挂在 ChangeWishPanel
--      弹窗里、平时整窗隐藏，PlayPage 会把动画播在看不见的弹窗里
--   ④ DrawCardPanel：弹窗打开（btnChange 点击）播、OnShow 不播（列表看不见）、
--      OnClose / OnDestroy 回收
--   ⑤ 四个列表页的数据刷新路径（this.Refresh / 领奖回调 / 计时器）里不播
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_cardactivity_listpopin.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local BASE = ROOT .. "Assets/ManagedResources/~Lua/Modules/"
local PANEL = BASE .. "CardActivity/CardActivityPanel.lua"
local DRAW = BASE .. "CardActivity/DrawCardPanel.lua"

local failed = 0
local function Check(cond, msg)
    if cond then
        print("  ✅ " .. msg)
    else
        failed = failed + 1
        print("  ❌ " .. msg)
    end
end

local function readSource(path)
    local f = assert(io.open(path, "rb"))
    local s = f:read("*a")
    f:close()
    return (s:gsub("\r\n", "\n"))
end

-- 取出「函数头之后到下一个顶层 function」之间的函数体（够用于接线断言）
local function bodyOf(src, header)
    local i = src:find(header, 1, true)
    if not i then return nil end
    local rest = src:sub(i + #header)
    local j = rest:find("\nfunction ", 1, true) or #rest
    return rest:sub(1, j)
end

-- 只数「调用」，不数定义行（function this.PlayContentPopIn(index)）
local function countCalls(src, call)
    local n = 0
    for line in src:gmatch("[^\n]+") do
        local trimmed = line:gsub("^%s+", "")
        if trimmed:sub(1, #call) == call and trimmed:sub(1, 8) ~= "function" then
            n = n + 1
        end
    end
    return n
end

-- ---------------- 面板：页面级批量接入 ----------------
print("== CardActivityPanel ==")
local src = readSource(PANEL)
Check(src:find('require("Modules/Common/ItemPopIn")', 1, true) ~= nil, "引了 ItemPopIn")

local tabChange = bodyOf(src, "function this.OnPageTabChange(index)")
Check(tabChange ~= nil and tabChange:find("PlayContentPopIn", 1, true) ~= nil,
    "OnPageTabChange 里播（首开 OnShow → ChangeTab 也走这条）")
Check(tabChange ~= nil and tabChange:find("view:OnShow", 1, true) ~= nil
        and tabChange:find("view:OnShow", 1, true) < tabChange:find("PlayContentPopIn", 1, true),
    "播在页内容 OnShow（= SetData）之后")

local playFn = bodyOf(src, "function this.PlayContentPopIn(index)")
Check(playFn ~= nil and playFn:find("DrawCardPanel", 1, true) ~= nil,
    "批量播里显式跳过 page_1（DrawCardPanel：列表在隐藏的弹窗里）")
Check(playFn ~= nil and playFn:find("ItemPopIn.PlayPage", 1, true) ~= nil, "其余页走 ItemPopIn.PlayPage")

local stopFn = bodyOf(src, "function this.StopContentPopIn()")
Check(stopFn ~= nil and stopFn:find("ItemPopIn.StopPage", 1, true) ~= nil, "有整批回收 StopContentPopIn")

local onClose = bodyOf(src, "function CardActivityPanel:OnClose()")
Check(onClose ~= nil and onClose:find("StopContentPopIn", 1, true) ~= nil, "OnClose 里回收")
local onDestroy = bodyOf(src, "function CardActivityPanel:OnDestroy()")
Check(onDestroy ~= nil and onDestroy:find("StopContentPopIn", 1, true) ~= nil, "OnDestroy 里回收")

Check(countCalls(src, "this:PlayContentPopIn(") == 1,
    "播的调用只有 OnPageTabChange 一处（其它路径 = 数据刷新，不播），实际 " .. countCalls(src, "this:PlayContentPopIn("))

-- ---------------- page_1：切换心愿弹窗（A 方案）----------------
print("== DrawCardPanel（page_1 切换心愿弹窗）==")
local draw = readSource(DRAW)
Check(draw:find('require("Modules/Common/ItemPopIn")', 1, true) ~= nil, "引了 ItemPopIn")
Check(draw:find("ItemPopIn.New(function() return this.ScrollView end)", 1, true) ~= nil,
    "数据源是切换心愿的 ScrollView（ScrollCycleView）")

local click = bodyOf(draw, "Util.AddClick(this.btnChange, function ()")
Check(click ~= nil and click:find("PlayWishPopIn", 1, true) ~= nil,
    "弹窗打开（btnChange 点击）播 —— 玩家主动换屏才播")
local onShow = bodyOf(draw, "function DrawCardPanel:OnShow(sortingOrder, parent)")
Check(onShow ~= nil and onShow:find("PlayWishPopIn", 1, true) == nil and onShow:find("popIn:Play", 1, true) == nil,
    "OnShow 不播（列表随弹窗整窗隐藏，播了也看不见）")

local drawClose = bodyOf(draw, "function DrawCardPanel:OnClose()")
Check(drawClose ~= nil and drawClose:find("popIn:Stop", 1, true) ~= nil, "OnClose 里回收")
local drawDestroy = bodyOf(draw, "function DrawCardPanel:OnDestroy()")
Check(drawDestroy ~= nil and drawDestroy:find("popIn:Stop", 1, true) ~= nil, "OnDestroy 里回收")

-- ---------------- 四个列表页：数据刷新路径不播 ----------------
print("== 数据刷新路径不播 ==")
for _, case in ipairs({
    { name = "TaskPanel", file = "TaskPanel.lua" },
    { name = "GiftPanel", file = "GiftPanel.lua" },
    { name = "WishPanel", file = "WishPanel.lua" },
    { name = "CollectPanel", file = "CollectPanel.lua" },
}) do
    local s = readSource(BASE .. "CardActivity/" .. case.file)
    Check(s:find("ItemPopIn", 1, true) == nil and s:find("popIn", 1, true) == nil,
        case.name .. " 自身不接动画（播的时机全在面板 OnPageTabChange，领奖/买礼包/计时器刷新天然不重播）")
end

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
