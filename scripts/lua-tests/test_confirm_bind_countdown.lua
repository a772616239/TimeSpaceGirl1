-- 绑定手机（ConfirmBindPanel）验证码倒计时协程生命周期回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_confirm_bind_countdown.lua
--
-- 背景：这是首充面板那条 "attempt to index transform on a nil value" 的同款坑——
--   while true 的倒计时协程只在 OnClose 里停，而 UIManager.DestroyPanel 只走 OnDestroy、
--   面板还会被 openedList 缓存复用；协程残留下来就会拿着已销毁的 getCodeBtnText 写 .text。
--   另外旧实现用 self.thread 当停止目标，重复点「获取验证码」时旧协程会把新协程停掉。
--
-- 这里用虚拟时钟 + 假节点（Destroy 后 IsNull 为真、索引字段会抛错）驱动真源码。

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"

----------------------------------------------------------------------
-- 1) 虚拟协程调度器
----------------------------------------------------------------------
local now = 0
local queue = {}
local runningSet = {}

local realCo = coroutine
local coCreate, coResume, coStatus, coYield = realCo.create, realCo.resume, realCo.status, realCo.yield

local function schedule(co, delay)
    queue[#queue + 1] = { co = co, at = now + (delay or 0.01) }
end

local function resumeCo(co)
    local ok, waitTime = coResume(co)
    if not ok then
        error(waitTime, 0)
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
-- 2) 假节点
----------------------------------------------------------------------
local function NewNode(name)
    local node = { __name = name, __destroyed = false, text = "", enabled = true }
    return setmetatable(node, {
        __index = function(t, k)
            if t.__destroyed then
                -- 只要对已销毁节点做任何字段访问，就复刻 tolua 的兜底报错
                error("attempt to index " .. tostring(k) .. " on a nil value", 2)
            end
            if k == "transform" or k == "gameObject" then
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
Util = {
    GetGameObject = function()
        return NewNode("go")
    end,
    AddClick = function() end,
    LogError = function() end,
}
BasePanel = {}
function quick_class(name, base)
    return setmetatable({}, { __index = base })
end
BindType = { GetCode = 1, Confirm = 2 }
PopupTipPanel = {
    ShowTipByLanguageId = function() end,
}
BindPhoneNumberManager = {
    DOGetBindPhone = function() end,
}
NetManager = { RequestUpDataBindPhoneInfo = function() end }
function GetLanguageStrById(id)
    return tostring(id)
end
function Log() end
function LogError() end

local Panel = assert(loadfile(LUA_SRC .. "/Modules/BindPhone/ConfirmBindPanel.lua"))()

----------------------------------------------------------------------
-- 4) 断言
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
    Panel.thread = nil
    Panel.bindType = BindType.GetCode
    Panel.context = {}
    Panel.phoneNumberInput = NewNode("phoneNumberInput")
    Panel.verifyCodeInput = NewNode("verifyCodeInput")
    Panel.getCodeBtn = NewNode("getCodeBtn")
    Panel.getCodeBtnText = NewNode("getCodeBtnText")
    while #queue > 0 do
        table.remove(queue)
    end
    for co in pairs(runningSet) do
        runningSet[co] = nil
    end
end

print("[1] 倒计时正常走完：一个协程，结束后自清 thread 并恢复按钮")
ResetPanel()
Panel:SetTimes()
Check(ActiveCoCount() == 1, "启动后活跃协程 = 1（实际 " .. ActiveCoCount() .. "）")
local ok, err = pcall(Tick, 1, 12)
Check(ok, "倒计时推进不抛异常" .. (ok and "" or ("（" .. tostring(err) .. "）")))
Check(ActiveCoCount() == 0, "倒计时结束后协程归零（实际 " .. ActiveCoCount() .. "）")
Check(Panel.thread == nil, "结束后 self.thread 已清空")
Check(Panel.getCodeBtn.enabled == true, "结束后按钮恢复可点")

print("[2] DestroyPanel 只走 OnDestroy（不走 OnClose）")
ResetPanel()
Panel:SetTimes()
Tick(1, 2)
DestroyNode(Panel.getCodeBtn)
DestroyNode(Panel.getCodeBtnText)
ok, err = pcall(Panel.OnDestroy, Panel)
Check(ok, "OnDestroy 可安全调用（旧版没有这个方法）" .. (ok and "" or ("（" .. tostring(err) .. "）")))
Check(ActiveCoCount() == 0, "OnDestroy 后协程已停（实际 " .. ActiveCoCount() .. "）")
Check(Panel.thread == nil, "OnDestroy 后 self.thread 已清空")

print("[3] 节点先被销毁、协程还没停：不抛异常且自行退出")
ResetPanel()
Panel:SetTimes()
Tick(1, 2)
DestroyNode(Panel.getCodeBtn)
DestroyNode(Panel.getCodeBtnText)
ok, err = pcall(Tick, 1, 12)
Check(ok, "继续走时钟不抛异常" .. (ok and "" or ("（" .. tostring(err) .. "）")))
Check(ActiveCoCount() == 0, "节点消失后协程自行退出（实际 " .. ActiveCoCount() .. "）")

print("[4] 重复请求验证码：只保留一个倒计时，旧协程不会停掉新协程")
ResetPanel()
Panel:SetTimes()
Tick(1, 1)
Panel:SetTimes()
Check(ActiveCoCount() == 1, "重复 SetTimes 后活跃协程 = 1（实际 " .. ActiveCoCount() .. "）")
ok, err = pcall(Tick, 1, 3)
Check(ok, "新倒计时继续推进不抛异常" .. (ok and "" or ("（" .. tostring(err) .. "）")))
Check(ActiveCoCount() == 1, "旧协程没把新协程停掉（仍在跑，" .. ActiveCoCount() .. " 个）")
Panel:OnClose()
Check(ActiveCoCount() == 0, "OnClose 后协程已停（实际 " .. ActiveCoCount() .. "）")

print("")
if failed > 0 then
    print("❌ 失败 " .. failed .. " 项")
    os.exit(1)
end
print("✅ 全部通过")
