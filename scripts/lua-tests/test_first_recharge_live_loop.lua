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
            if k == "transform" then
                if t.__destroyed then
                    error("attempt to index transform on a nil value", 2)
                end
                return t
            end
            if k == "gameObject" then
                return t
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
Util = {
    ClearChild = function() end,
    LoadSprite = function()
        return nil
    end,
    AddClick = function() end,
    AddParticleSortLayer = function() end,
    LogError = function() end,
}
SoundConfig = { Sound_UICancel = 1 }
Inherit = function(base)
    return setmetatable({}, { __index = base })
end
BasePanel = {}

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
    Panel.lihui = NewNode("lihuis")
    Panel.oneLihui = NewNode("lihui")
    Panel.name = NewNode("name")
    Panel.pro = NewNode("pro")
    Panel.liveNode = nil
    Panel.Onelive = nil
    Panel.heroData = heroCfg[10003]
    Panel.oneHeroData = heroCfg[10042]
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

print("")
if failed > 0 then
    print("❌ 失败 " .. failed .. " 项")
    os.exit(1)
end
print("✅ 全部通过")
