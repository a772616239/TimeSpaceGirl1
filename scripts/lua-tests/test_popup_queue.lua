-- 主动弹窗队列（弹框列表）单元测试（纯逻辑，不依赖 Unity）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_popup_queue.lua
--
-- 复现的线上问题：登录进主界面，首充 / 拍脸 / 国家选择 / 至尊英雄四个主动弹窗
-- 各自 OpenPanel，UIManager 只递增 sortingOrder ⇒ 四层叠在一起。
-- 现在的约定：同一时刻只允许一个「主动弹窗」在屏；前一个关掉才开下一个。

local ROOT = os.getenv("TS_ROOT") or "."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ================= 最小环境桩 =================
local logs, errors = {}, {}
Log = function(s) logs[#logs + 1] = tostring(s) end
LogError = function(s) errors[#errors + 1] = tostring(s) end

-- ---- Timer（手动 pump 驱动，只实现 PopupQueue 用到的部分）----
Time = { realtimeSinceStartup = 0 }
local timers = {}
Timer = {}
function Timer.New(fn, delay)
    local t = { fn = fn, delay = delay, time = 0, stopped = false }
    function t:Start() timers[#timers + 1] = self end
    function t:Stop() self.stopped = true end
    return t
end
local function pump(seconds)
    local step = 0.05
    local elapsed = 0
    while elapsed < seconds - 1e-9 do
        elapsed = elapsed + step
        Time.realtimeSinceStartup = Time.realtimeSinceStartup + step
        local snapshot = {}
        for i = 1, #timers do snapshot[i] = timers[i] end
        for i = 1, #snapshot do
            local t = snapshot[i]
            if not t.stopped then
                t.time = t.time + step
                if t.time >= t.delay - 1e-9 then
                    t.stopped = true
                    t.fn()
                end
            end
        end
        local alive = {}
        for i = 1, #timers do
            if not timers[i].stopped then alive[#alive + 1] = timers[i] end
        end
        timers = alive
    end
end

-- ---- UIManager 桩：维护「哪些面板开着」+ 同屏违规统计 ----
local CONFIG = {
    [1] = { id = 1, assetName = "FirstRechargePanel" },
    [2] = { id = 2, assetName = "PatFacePanel" },
    [3] = { id = 3, assetName = "CountryFlagSelectPopup" },
    [4] = { id = 4, assetName = "SupremeHeroPopup" },
}
local openPanels = {}
local openSeq = {}       -- 打开顺序
local coexist = {}       -- 同屏记录
local failOpenId = nil
local lastArgs = nil
local topPanelName = nil -- 栈顶界面名（nil = 屏幕上什么都没开，老行为）

UIManager = {}
function UIManager.GetConfig(id) return CONFIG[id] end
function UIManager.IsOpen(id) return openPanels[id] == true end
function UIManager.SetPopupQueue(q) UIManager.popupQueue = q end
-- 栈顶界面：主动弹窗队列靠它判断「现在是不是回到了主界面」
function UIManager.GetTopStackPanel()
    if topPanelName == nil then return nil end
    return { uiConfig = { name = topPanelName } }
end

local function doOpen(id, ...)
    if failOpenId == id then return nil end
    -- 同屏检查：此时若已经有别的面板开着，就是重叠
    for other in pairs(openPanels) do
        coexist[#coexist + 1] = string.format("%s 叠在 %s 之上", CONFIG[id].assetName, CONFIG[other].assetName)
    end
    openPanels[id] = true
    openSeq[#openSeq + 1] = CONFIG[id].assetName
    lastArgs = { n = select("#", ...), ... }
    return { id = id }
end
function UIManager.OpenPanel(id, ...) return doOpen(id, ...) end
function UIManager.OpenPanelWithSound(id, ...) return doOpen(id, ...) end
-- ClosePanel 模拟 UIManager.ClosePanel → CloseStackPanel 收尾后通知队列
function UIManager.ClosePanel(id)
    if not openPanels[id] then return end
    openPanels[id] = nil
    if UIManager.popupQueue then
        UIManager.popupQueue.OnPanelClosed(id)
    end
end

-- ---- 载入被测模块 ----
assert(loadfile(LUA_SRC .. "/Modules/Popup/PopupQueue.lua"))()

local pass, fail = 0, 0
local function check(desc, cond, extra)
    if cond then
        pass = pass + 1
        print(string.format("  ✅ %s", desc))
    else
        fail = fail + 1
        print(string.format("  ❌ %s %s", desc, extra and ("→ " .. tostring(extra)) or ""))
    end
end

local function reset()
    logs, errors = {}, {}
    openPanels, openSeq, coexist = {}, {}, {}
    failOpenId, lastArgs = nil, nil
    topPanelName = nil
    timers = {}
    PopupQueue.Clear()
end

print("\n[1] 串行：四个主动弹窗排队，关一个才开下一个")
do
    reset()
    PopupQueue.Push(1)
    PopupQueue.Push(2)
    PopupQueue.Push(3)
    PopupQueue.Push(4)
    check("只有第一个开出来", #openSeq == 1 and openSeq[1] == "FirstRechargePanel", table.concat(openSeq, ","))
    check("另外三个还在队列里", PopupQueue.Count() == 3, PopupQueue.Count())

    UIManager.ClosePanel(1)
    check("关闭当下不抢跑", #openSeq == 1, table.concat(openSeq, ","))
    pump(0.2)
    check("关掉后开第二个", #openSeq == 2 and openSeq[2] == "PatFacePanel", table.concat(openSeq, ","))

    UIManager.ClosePanel(2)
    pump(0.2)
    UIManager.ClosePanel(3)
    pump(0.2)
    check("四个依次开完", #openSeq == 4, table.concat(openSeq, ","))
    check("队列已清空", PopupQueue.Count() == 0 and PopupQueue.IsShowing(4) == true)

    UIManager.ClosePanel(4)
    pump(0.5)
    check("全程没有同屏", #coexist == 0, coexist[1])
    check("全程没有报错", #errors == 0, errors[1])
end

print("\n[2] 去重：同一界面重复请求只排一次")
do
    reset()
    PopupQueue.Push(1)
    PopupQueue.Push(1)
    PopupQueue.Push(1)
    check("只开一次", #openSeq == 1, table.concat(openSeq, ","))
    check("展示中再 Push 不进队列", PopupQueue.Count() == 0, PopupQueue.Count())
    check("IsShowing 为真", PopupQueue.IsShowing(1) == true)
    UIManager.ClosePanel(1)
    pump(0.3)
    check("关掉之后也不会补开", #openSeq == 1, table.concat(openSeq, ","))
end

print("\n[3] 已在屏的界面不重复入队")
do
    reset()
    UIManager.OpenPanel(3)  -- 别处已经直接打开了
    openSeq = {}
    PopupQueue.Push(3)
    check("不重复打开", #openSeq == 0, table.concat(openSeq, ","))
    check("也不进队列", PopupQueue.Count() == 0)
end

print("\n[4] 参数保真：nil 占位与回调都要原样传给面板")
do
    reset()
    local cb = function() end
    PopupQueue.Push(1, nil, cb)
    check("参数个数为 2", lastArgs ~= nil and lastArgs.n == 2, lastArgs and lastArgs.n)
    check("第一个参数是 nil", lastArgs[1] == nil)
    check("第二个参数是回调", lastArgs[2] == cb)
end

print("\n[5] 兜底：某个界面打不开不能把整条队列卡死")
do
    reset()
    failOpenId = 1
    PopupQueue.Push(1)
    PopupQueue.Push(2)
    check("坏界面被跳过，后一个顶上", #openSeq == 1 and openSeq[1] == "PatFacePanel", table.concat(openSeq, ","))
    check("记录了错误日志", #errors == 1, errors[1])
end

print("\n[6] Clear：切场景/退出时清空，不会在已销毁的 UIRoot 上开界面")
do
    reset()
    PopupQueue.Push(1)
    PopupQueue.Push(2)
    UIManager.ClosePanel(1)
    PopupQueue.Clear()
    pump(0.5)
    check("清空后不再开下一个", #openSeq == 1, table.concat(openSeq, ","))
    check("队列为空", PopupQueue.Count() == 0)
end

print("\n[7] 底屏闸门：弹窗里点「前往」跳走，下一个不压在功能界面上")
do
    reset()
    topPanelName = "MainPanel"
    PopupQueue.Push(1)
    PopupQueue.Push(2)
    check("主界面上正常弹第一个", #openSeq == 1 and openSeq[1] == "FirstRechargePanel", table.concat(openSeq, ","))

    -- 复现线上：SupremeHeroPopup 里点 Button_Go → 先跳 OperatingPanel，再关掉弹窗
    topPanelName = "OperatingPanel"
    UIManager.ClosePanel(1)
    pump(0.5)
    check("跳到功能界面后不抢弹", #openSeq == 1, table.concat(openSeq, ","))
    check("队列压着没丢", PopupQueue.Count() == 1 and PopupQueue.IsHolding() == true)
    check("没有同屏", #coexist == 0, coexist[1])

    -- 玩家把功能界面关回主界面
    topPanelName = "MainPanel"
    PopupQueue.OnPanelClosed(999)
    pump(0.5)
    check("回到主界面继续弹下一个", #openSeq == 2 and openSeq[2] == "PatFacePanel", table.concat(openSeq, ","))
    check("闸门已放开", PopupQueue.IsHolding() == false and PopupQueue.Count() == 0)
end

print("\n[8] 兜底：弹窗被全屏界面顶掉、没自己 ClosePanel，队列也不会卡死")
do
    reset()
    topPanelName = "MainPanel"
    PopupQueue.Push(1)
    PopupQueue.Push(2)
    -- 只派发 UI.OnClose（BasePanel:CloseUI 那条），不经过 UIManager 收尾通知
    topPanelName = "OperatingPanel"
    PopupQueue.OnPanelClosed(1)
    pump(0.5)
    check("被顶掉也认了关闭", PopupQueue.IsShowing(1) == false)
    check("跳到别处仍然不抢弹", #openSeq == 1, table.concat(openSeq, ","))

    topPanelName = nil   -- 回到主城但一时没有界面在屏
    PopupQueue.OnPanelClosed(112)
    pump(0.5)
    check("屏幕空了就放行", #openSeq == 2 and openSeq[2] == "PatFacePanel", table.concat(openSeq, ","))
end

print(string.format("\n结果：通过 %d，失败 %d", pass, fail))
if fail > 0 then
    os.exit(1)
end
