-- 首充面板（FirstRechargePanel）立绘轮播协程生命周期回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_first_recharge_live_loop.lua
--
-- 线上报错：
--   LuaException: ...FirstRechargePanel:142: in function 'SetHeroData'
--   System/coroutine:71: attempt to index transform on a nil value
-- 142 行是 Util.ClearChild(this.lihui.transform)。tolua 里被 Destroy 的 UnityEngine.Object
-- 仍然是 userdata（Lua 侧非 nil），直接 .transform 抛出来的就是这句文案（toluaL_exception
-- 的兜底文案，见 Assets/Source/Generate/UnityEngine_GameObjectWrap.cs:853）。
--
-- 根因：while true 的轮播协程没有随面板销毁停掉——
--   ① thread 是模块级单槽，OnShow 每次都覆盖 ⇒ 面板是缓存复用的（UIManager.openedList），
--      重复 Open 不经过 OnClose，旧协程被顶掉后再也没人停它；
--   ② 销毁路径 UIManager.DestroyPanel 只调 DestroyUI→OnDestroy，根本不会调 OnClose；
--   面板销毁后残留协程继续跑：this.liveNode（Lua 侧非 nil，if 判断拦不住）+ 已销毁的 this.lihui
--   ⇒ 下一轮 SetHeroData 就崩在 142。
--
-- 这里用虚拟时钟 + 假节点（Destroy 后 IsNull 为真、索引 transform 会抛错）驱动真源码。

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"

----------------------------------------------------------------------
-- 1) 虚拟协程调度器：实现 coroutine.start / wait / stop 的真实契约
----------------------------------------------------------------------
local now = 0
local queue = {}      -- { co = ..., at = 秒 }
local runningSet = {} -- co -> true（未结束、未 stop）

local realCo = coroutine
local coCreate, coResume, coStatus, coYield = realCo.create, realCo.resume, realCo.status, realCo.yield

local function schedule(co, delay)
    queue[#queue + 1] = { co = co, at = now + (delay or 0.01) }
end

local function resumeCo(co)
    local ok, waitTime = coResume(co)
    if not ok then
        error(waitTime, 0) -- 协程内抛错 = 测试失败
    end
    if coStatus(co) ~= "dead" then
        schedule(co, waitTime)
    end
end

coroutine = {
    create = coCreate,
    resume = coResume,
    status = coStatus,
    running = realCo.running,
    yield = coYield,
    start = function(f)
        local co = coCreate(f)
        runningSet[co] = true
        resumeCo(co)
        return co
    end,
    wait = function(t)
        return coYield(t or 0.01)
    end,
    stop = function(co)
        if co then
            runningSet[co] = nil
        end
    end,
}

local function ActiveCoCount()
    local n = 0
    for co in pairs(runningSet) do
        if coStatus(co) == "dead" then
            runningSet[co] = nil
        else
            n = n + 1
        end
    end
    return n
end

local function Tick(step, times)
    for _ = 1, (times or 1) do
        now = now + step
        local fire = {}
        for i = #queue, 1, -1 do
            if queue[i].at <= now then
                fire[#fire + 1] = queue[i].co
                table.remove(queue, i)
            end
        end
        for _, co in ipairs(fire) do
            if runningSet[co] then
                if coStatus(co) == "dead" then
                    runningSet[co] = nil
                else
                    resumeCo(co)
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- 2) 假节点：Destroy 后 IsNull 为真，索引 transform 抛 tolua 同款错误
----------------------------------------------------------------------
local function NewNode(name)
    local node = { __name = name, __destroyed = false, localPosition = nil }
    return setmetatable(node, {
        __index = function(t, k)
            -- 已 Destroy：读字段/取方法一律复刻 tolua 的兜底报错（SetActive 之类也一样）
            if t.__destroyed and k ~= "__destroyed" then
                error("attempt to index " .. tostring(k) .. " on a nil value", 2)
            end
            if k == "transform" then
                return t
            end
            if k == "gameObject" then
                return t
            end
            if k == "SetActive" then
                return function() end
            end
            if k == "GetComponent" then
                return function(_, comp)
                    return NewNode(comp)
                end
            end
            if k == "Find" then
                return function(_, path)
                    return NewNode(path)
                end
            end
            return nil
        end,
    })
end

local function DestroyNode(node)
    if node then
        node.__destroyed = true
    end
end

function IsNull(obj)
    if obj == nil then
        return true
    end
    if type(obj) == "table" and obj.__destroyed ~= nil then
        return obj.__destroyed
    end
    return false
end

----------------------------------------------------------------------
-- 3) 其余依赖桩
----------------------------------------------------------------------
local heroCfg = {}
for _, id in ipairs({ 10003, 10019, 10042 }) do
    heroCfg[id] = {
        ReadingName = 1,
        PropertyName = 1,
        Position = { 0, 0 },
        Scale = 1,
        RoleImage = 1,
    }
end

ConfigName = { HeroConfig = "HeroConfig", ActivityRewardConfig = "ActivityRewardConfig", ArtResourcesConfig = "ArtResourcesConfig" }
ConfigManager = {
    GetConfig = function()
        return {}
    end,
    GetConfigData = function(_, id)
        return heroCfg[id]
    end,
}
ActivityTypeDef = { FirstRecharge = 1 }
ActivityGiftManager = {
    GetActivityTypeInfo = function()
        return { mission = {} }
    end,
}
FirstRechargeManager = {
    GetSixMoneyTabRedPointStatus = function()
        return false
    end,
    GetHundredTabRedPointStatus = function()
        return false
    end,
}
Color = {
    New = function()
        return {}
    end,
}
Vector3 = {
    New = function(x, y, z)
        return { x = x, y = y, z = z }
    end,
}
Ease = { InQuad = 1 }
DoTween = {
    To = function()
        return { SetEase = function()
            return {}
        end }
    end,
}
DG = {
    Tweening = {
        Core = {
            DOGetter_UnityEngine_Vector3 = function(f)
                return f
            end,
            DOSetter_UnityEngine_Vector3 = function(f)
                return f
            end,
        },
    },
}
local nodeMap = {} -- path -> false 表示该节点不存在
Util = {
    ClearChild = function() end,
    LoadSprite = function()
        return nil
    end,
    AddClick = function() end,
    AddParticleSortLayer = function() end,
    LogError = function() end,
    -- 默认每个路径都拿得到节点；nodeMap 里显式给 false 的路径模拟「节点不存在」
    GetGameObject = function(_, path)
        if nodeMap[path] == false then
            return nil
        end
        return NewNode(path)
    end,
}
SoundConfig = { Sound_UICancel = 1 }
Inherit = function(base)
    return setmetatable({}, { __index = base })
end
BasePanel = {}
function ConfigPairs(t)
    return pairs(t or {})
end
IndexValueDef = { 1, 2 }

local loadLiveCount = 0
function LoadHerolive()
    loadLiveCount = loadLiveCount + 1
    return NewNode("live")
end
function UnLoadHerolive() end
function GetLanguageStrById(id)
    return tostring(id)
end
function GetProStrImageByProNum()
    return ""
end
function Log() end
function LogError() end
function PlaySoundWithoutClick() end

-- 这个 luajit 构建下 package.loaded 覆盖不了 require（实测 require 只看 package.preload），
-- 所以用 preload 打桩。
package.preload["Modules/FirstRecharge/DayRewardItem"] = function()
    return { new = function()
        return {}
    end }
end

----------------------------------------------------------------------
-- 4) 载入真源码
----------------------------------------------------------------------
local Panel = assert(loadfile(LUA_SRC .. "/Modules/FirstRecharge/FirstRechargePanel.lua"))()

----------------------------------------------------------------------
-- 5) 断言
----------------------------------------------------------------------
local failed = 0
local function Check(cond, msg)
    if cond then
        print("  ✅ " .. msg)
    else
        failed = failed + 1
        print("  ❌ " .. msg)
    end
end

local function ResetPanel()
    Panel.transform = NewNode("root")
    Panel.lihui = NewNode("lihuis")
    Panel.oneLihui = NewNode("lihui")
    Panel.lihuiInfo = NewNode("lihuiInfo")
    Panel.oneLihuiInfo = NewNode("oneLihuiInfo")
    Panel.name = NewNode("name")
    Panel.pro = NewNode("pro")
    Panel.liveNode = nil
    Panel.Onelive = nil
    Panel.heroData = heroCfg[10003]
    Panel.oneHeroData = heroCfg[10042]
    -- OnShow/OnTabChanged 需要的外观件
    Panel.selectTabIndex = 1
    Panel.selectTabs = { NewNode("selected1"), NewNode("selected2") }
    Panel.tabTitles = { NewNode("title1"), NewNode("title2") }
    Panel.tabRedPoint = { NewNode("red1"), NewNode("red2") }
    Panel.reChargeTips = NewNode("tips")
    Panel.reChargeBtn = NewNode("rechargeBtn")
    Panel.dayRewardList = {}
    nodeMap = {}
end

print("[1] SetHeroData：lihui 已销毁时不能再索引 transform")
ResetPanel()
DestroyNode(Panel.lihui)
local ok, err = pcall(SetHeroData, 10019)
Check(ok, "面板销毁后 SetHeroData 不抛异常" .. (ok and "" or ("（" .. tostring(err) .. "）")))

print("[2] liveNode 已销毁（fake-null）+ lihui 存活：回收流程不抛异常")
ResetPanel()
Panel.liveNode = NewNode("live")
DestroyNode(Panel.liveNode)
-- SetHeroData 成功路径里有 coroutine.wait，必须在协程里跑
ok, err = pcall(coroutine.start, function()
    SetHeroData(10003)
end)
Check(ok, "liveNode 是 fake-null 时 SetHeroData 不抛异常" .. (ok and "" or ("（" .. tostring(err) .. "）")))
-- 让这条一次性协程自然跑完，别污染后面的协程计数
for _ = 1, 200 do
    if ActiveCoCount() == 0 and #queue == 0 then
        break
    end
    Tick(1, 1)
end

print("[3] StartHeroLoop 幂等：重复调用只有一个协程")
ResetPanel()
Panel:StartHeroLoop()
local firstCo = Panel and nil
Panel:StartHeroLoop()
Panel:StartHeroLoop()
Check(ActiveCoCount() == 1, "重复 StartHeroLoop 后活跃协程数 = 1（实际 " .. ActiveCoCount() .. "）")

print("[4] 面板销毁（不走 OnClose）后轮播协程自行结束")
ResetPanel()
Panel:StartHeroLoop()
Tick(0.1, 3) -- 让第一轮跑起来并挂到 wait 上
DestroyNode(Panel.lihui)
DestroyNode(Panel.liveNode)
ok, err = pcall(Tick, 0.5, 12)
Check(ok, "销毁后继续走时钟不抛异常" .. (ok and "" or ("（" .. tostring(err) .. "）")))
Check(ActiveCoCount() == 0, "销毁后活跃协程数归零（实际 " .. ActiveCoCount() .. "）")

print("[5] OnClose 停协程并回收立绘")
ResetPanel()
Panel:StartHeroLoop()
Tick(0.1, 2)
Check(ActiveCoCount() == 1, "打开后有一个协程在跑")
Panel:OnClose()
Check(ActiveCoCount() == 0, "OnClose 后协程已停")
Check(Panel.liveNode == nil, "OnClose 后 liveNode 已清空")

print("[6] OnDestroy 兜底（UIManager.DestroyPanel 只走这条，不走 OnClose）")
ResetPanel()
Panel:StartHeroLoop()
Tick(0.1, 2)
DestroyNode(Panel.lihui)
Panel:OnDestroy()
Check(ActiveCoCount() == 0, "OnDestroy 后协程已停（实际 " .. ActiveCoCount() .. "）")

print("[7] OnShow：oneLihui 已销毁（fake-null）时不再裸取 .transform")
ResetPanel()
DestroyNode(Panel.oneLihui)
-- 只测 OnShow 里的「静态立绘」这一段：把 tab 切换临时打空，避免 305 行的报错抢在前面
-- （305 由用例 [8] 单独覆盖），这样旧版就能精确复现 149 行那句
-- "attempt to index transform on a nil value"。
local realOnTabChanged = Panel.OnTabChanged
Panel.OnTabChanged = function() end
ok, err = pcall(Panel.OnShow, Panel)
Panel.OnTabChanged = realOnTabChanged
Check(ok, "OnShow 不抛异常" .. (ok and "" or ("（" .. tostring(err) .. "）")))
-- 轮播协程第一轮会自己 LoadHerolive（挂到 liveNode 上），所以这里只看静态立绘这一个槽位
Check(Panel.Onelive == nil, "节点已销毁时跳过加载静态立绘（Onelive 保持 nil，未多挂一张）")
Panel:OnDestroy()

print("[8] OnTabChanged：oneLihui/oneLihuiInfo/lihuiInfo 已销毁时不再裸 :SetActive")
ResetPanel()
DestroyNode(Panel.oneLihui)
DestroyNode(Panel.oneLihuiInfo)
DestroyNode(Panel.lihuiInfo)
ok, err = pcall(Panel.OnTabChanged, Panel, 2)
Check(ok, "OnTabChanged 不抛异常" .. (ok and "" or ("（" .. tostring(err) .. "）")))

print("[9] InitComponent：缺 hero 节点时只记日志，不抛异常")
ResetPanel()
nodeMap["hero"] = false
ok, err = pcall(Panel.InitComponent, Panel)
Check(ok, "InitComponent 不抛异常" .. (ok and "" or ("（" .. tostring(err) .. "）")))
Check(Panel.lihui == nil and Panel.oneLihui == nil and Panel.name == nil,
        "hero 相关引用全部为 nil（下游整块走跳过分支）")
nodeMap["hero"] = nil

print("")
if failed > 0 then
    print("❌ 失败 " .. failed .. " 项")
    os.exit(1)
end
print("✅ 全部通过")
