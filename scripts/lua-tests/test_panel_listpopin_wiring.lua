-- 三面板「长列表入场」接线回归（纯文本断言，不依赖 Unity）：
--   ExpertPanel / OperatingPanel / AdjutantActivityPanel 的页签内容页
--   ① 打开面板：OnShow（或 OnPageTabChange）里有播 ⇒ 首次打开就是列表页也会播
--   ② 切页签：点击回调里有播
--   ③ 数据回调刷新（RefreshActivity）里不播，否则每次服务端推送都整列重弹
--   ④ OnClose / OnDestroy 都回收（漏了 = item 永久停在半截缩放）
--   ⑤ 手工克隆的列表（积天豪礼）声明了 GetPopInSource
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_panel_listpopin_wiring.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local BASE = ROOT .. "Assets/ManagedResources/~Lua/Modules/"
local EXPERT = BASE .. "Expert/ExpertPanel.lua"
local OPERATING = BASE .. "Operating/OperatingPanel.lua"
local ADJUTANT = BASE .. "AdjutantActivity/AdjutantActivityPanel.lua"
local CONTINUITY = BASE .. "Operating/ContinuityRechargePage.lua"

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

-- 只数「调用」，不数定义行（function this:PlayContentPopIn()）
local function countCalls(src, call)
    local n = 0
    for line in src:gmatch("[^\n]+") do
        local trimmed = line:gsub("^%s+", "")
        if trimmed == call or trimmed:sub(1, #call) == call and trimmed:sub(1, 6) ~= "function" then
            n = n + 1
        end
    end
    return n
end

-- ---------------- 三个面板的共同约束 ----------------
for _, case in ipairs({
    { name = "ExpertPanel", path = EXPERT, requires = true },
    { name = "OperatingPanel", path = OPERATING, requires = true },
    { name = "AdjutantActivityPanel", path = ADJUTANT, requires = false },
}) do
    print("== " .. case.name .. " ==")
    local src = readSource(case.path)
    if case.requires then
        Check(src:find('require("Modules/Common/ItemPopIn")', 1, true) ~= nil, "引了 ItemPopIn")
    end

    local onShow = bodyOf(src, "function " .. case.name .. ":OnShow()")
    -- 直接播，或者经 TabBox:ChangeTab 的回调播（Adjutant 是后者）
    local playDirect = onShow ~= nil and
        (onShow:find("PlayContentPopIn", 1, true) ~= nil or onShow:find("ItemPopIn.PlayPage", 1, true) ~= nil)
    local playViaTab = onShow ~= nil and onShow:find("ChangeTab(", 1, true) ~= nil
        and src:find("ItemPopIn.PlayPage", 1, true) ~= nil
    Check(playDirect or playViaTab, "OnShow 里有播（首次打开就是列表页也会播）")

    local onClose = bodyOf(src, "function " .. case.name .. ":OnClose()")
    Check(onClose ~= nil and (onClose:find("StopContentPopIn", 1, true) or onClose:find("StopPage", 1, true)) ~= nil,
        "OnClose 里回收（Kill + 复位）")

    local onDestroy = bodyOf(src, "function " .. case.name .. ":OnDestroy()")
    Check(onDestroy ~= nil and (onDestroy:find("StopContentPopIn", 1, true) or onDestroy:find("StopPage", 1, true)) ~= nil,
        "OnDestroy 里回收")

    local refresh = bodyOf(src, "function this:RefreshActivity()")
        or bodyOf(src, "function this.RefreshActivity()")
        or bodyOf(src, "function " .. case.name .. ":RefreshActivity()")
    if refresh then
        Check(refresh:find("PlayContentPopIn", 1, true) == nil and refresh:find("ItemPopIn.PlayPage", 1, true) == nil,
            "RefreshActivity 不播（服务端推送/5点刷新不整列重弹）")
    else
        print("  · 没有 RefreshActivity，跳过「数据回调不播」")
    end
end

-- ---------------- 切页签也要播 ----------------
print("== 切页签 ==")
local expert = readSource(EXPERT)
Check(countCalls(expert, "this:PlayContentPopIn()") == 2,
    "ExpertPanel：OnShow + 页签点击各播一次，实际 " .. countCalls(expert, "this:PlayContentPopIn()"))

local operating = readSource(OPERATING)
Check(countCalls(operating, "this:PlayContentPopIn()") == 2,
    "OperatingPanel：OnShow + 页签点击各播一次，实际 " .. countCalls(operating, "this:PlayContentPopIn()"))

local adjutant = readSource(ADJUTANT)
local tabChange = bodyOf(adjutant, "function this.OnPageTabChange(index)")
Check(tabChange ~= nil and tabChange:find("ItemPopIn.PlayPage", 1, true) ~= nil,
    "AdjutantActivityPanel：PageTabChange 里播（首次打开也走这条）")

-- ---------------- 手工克隆的列表声明 ----------------
print("== 积天豪礼（手工克隆的列表）==")
local continuity = readSource(CONTINUITY)
local getter = bodyOf(continuity, "function ContinuityRechargePage:GetPopInSource()")
Check(getter ~= nil, "声明了 GetPopInSource")
Check(getter ~= nil and getter:find("continuityTaskContent", 1, true) ~= nil,
    "GetPopInSource 返回 taskList 的 content 容器")

-- ---------------- OperatingPanel 的两个「漏页」 ----------------
-- page_3 = GrowthGiftPage（成长礼金）、page_9 = LifelongLimitBuy（终身限购）。
-- 这两页当初都接不上：一个被 DelayCreation 把 item 预先 SetActive(false)（工具收不到），
-- 一个是手工克隆、数据源不是 ScrollCycleView（工具扫不到）。
print("== 成长礼金 page_3 ==")
local growth = readSource(BASE .. "Operating/GrowthGiftPage.lua")
Check(growth:find("SubUIConfig.ScrollCycleView", 1, true) ~= nil, "列表是 ScrollCycleView（会被 PlayPage 自动扫到）")
Check(growth:find("DelayCreation(", 1, true) == nil,
    "不再调 DelayCreation（它会把 item 全部隐藏，逐格入场就一个都收不到）")
Check(growth:find("self.scrollView", 1, true) ~= nil, "scrollView 挂在实例上（PlayPage 扫实例字段）")

print("== 终身限购 page_9 ==")
local lifelong = readSource(BASE .. "Operating/LifelongLimitBuy.lua")
local lifelongGetter = bodyOf(lifelong, "function LifelongLimitBuy:GetPopInSource()")
Check(lifelongGetter ~= nil, "声明了 GetPopInSource（手工克隆的列表）")
Check(lifelongGetter ~= nil and lifelongGetter:find("self.preList", 1, true) ~= nil,
    "返回 preList 数组，而不是 grid 容器（rewardPre 模板挂在 grid 下，按容器扫会把模板也算进去）")
Check(lifelong:find("go:SetActive(true)", 1, true) ~= nil, "克隆项填完数据是 active 的（否则会被跳过）")

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
