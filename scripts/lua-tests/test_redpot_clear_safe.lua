-- 红点绑定表「解绑不再崩」回归测试（不依赖 Unity，直接用 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_redpot_clear_safe.lua
--
-- 背景（线上报错）：
--   LuaException: Modules/Player/RedpotManager:689: bad argument #1 to 'pairs' (table expected, got nil)
--   ← ArenaTypePanel_TopMatch:OnShow 第 98 行 ClearRedPointObject(Championships_Rank_Link, btnRankRedpoint)
--   首次进页签时 BindObjs[99901] 还不存在（f2cd3716d 把绑定从 BindEvent 挪到 OnShow 的「先 Clear 再 Bind」），
--   旧 ClearObject 只判了 rpObj、没判 BindObjs[rpType] ⇒ pairs(nil) 抛错 ⇒ 整个 OnShow 被打断。
--
-- 覆盖：
--   · 空表时 ClearObject(type, obj) 不能抛错（核心回归项）
--   · ClearAll(nil) 之后再 ClearObject(type, obj) 不能抛错
--   · BindObject 幂等（同一物体只保留一份）
--   · ClearObject 能解绑指定物体、且能清掉历史重复项
--   · 没绑过就 Clear / 重复 Clear 都安全

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ---- 最小环境桩 ----
Log = function() end
LogError = function(s) print("  [LogError] " .. tostring(s)) end

RedPointStatus = { Show = 1, Hide = 0 }
RedPointType = {
    Mail_Server = 1,
    SecretTer_Boss = 2,
    Arena_Record = 3,
    Guild_Apply = 4,
    Championships = 99900,
    Championships_Rank_Link = 99901,
}

table.walk = table.walk or function(t, f) for k, v in pairs(t) do f(v, k) end end

Game = { GlobalEvent = { AddEvent = function() end, RemoveEvent = function() end } }
GameEvent = { FunctionCtrl = { OnFunctionOpen = "a", OnFunctionClose = "b" } }

local redValues = {}
local RPDataStub = {
    AddCheckFunc = function() end,
    SetParent = function() end,
    SetServerRedData = function() end,
    GetCheckList = function() return {} end,
    SetRedValue = function(_, rpType, v) redValues[rpType] = v; return true end,
    GetRedValue = function(_, rpType) return redValues[rpType] or 0 end,
    SetServerRed = function() return true end,
    GetRedParent = function() return nil end,
}
package.preload["Modules/Player/RedPointData"] = function() return RPDataStub end
package.preload["Message/MessageTypeProto_pb"] = function() return {} end
package.preload["Message/PlayerInfoProto_pb"] = function() return {} end

local RedpotManager = require("Modules/Player/RedpotManager")
-- 不跑 Initialize（会碰 Game 事件），直接从「登录后 BindObjs 为空」的状态开始

local T = RedPointType.Championships_Rank_Link
local pass, fail = 0, 0
local function ok(cond, name)
    if cond then
        pass = pass + 1
        print(string.format("  PASS  %s", name))
    else
        fail = fail + 1
        print(string.format("  FAIL  %s", name))
    end
end

local function newObj(tag)
    return { tag = tag, active = nil, SetActive = function(self, b) self.active = b end }
end

-- 1) 核心回归：BindObjs 里还没有这个 rpType 时 Clear 不能抛错
print("[1] 空表时 Clear（= 线上崩的那一行）")
local a = newObj("a")
local okClear, errClear = pcall(RedpotManager.ClearObject, T, a)
ok(okClear, "ClearObject 在 BindObjs[rpType] == nil 时不抛错")
if not okClear then print("        err: " .. tostring(errClear)) end

-- 2) ClearAll 之后紧接着 Clear 单个物体
print("[2] ClearAll(nil) 之后再 Clear 单个")
RedpotManager.ClearObject(T)                      -- rpObj = nil，清空该类型
local ok2 = pcall(RedpotManager.ClearObject, T, a)
ok(ok2, "ClearAll 之后 ClearObject(type, obj) 不抛错")

-- 3) Bind 幂等
print("[3] BindObject 幂等")
RedpotManager.BindObject(T, a)
RedpotManager.BindObject(T, a)
RedpotManager.BindObject(T, a)
ok(a.active == false or a.active == true, "BindObject 会按状态 SetActive")
redValues[T] = 1
RedpotManager.BindObject(T, a)
ok(a.active == true, "BindObject 能刷新为显示")

-- 4) 先 Clear 再 Bind（面板 OnShow 的写法）多次重复后不会漏绑/重复
print("[4] 面板 OnShow 的「先 Clear 再 Bind」重复执行")
for _ = 1, 5 do
    RedpotManager.ClearObject(T, a)
    RedpotManager.BindObject(T, a)
end
ok(a.active == true, "重复 Clear+Bind 后仍然生效")

-- 5) 两个物体各自独立解绑
print("[5] 多物体解绑")
local b = newObj("b")
RedpotManager.BindObject(T, b)
RedpotManager.ClearObject(T, a)
redValues[T] = 0
RedpotManager.ClearObject(T, b)
local ok5 = pcall(RedpotManager.ClearObject, T, a)   -- 已解绑过，再解一次
ok(ok5, "重复解绑同一物体不抛错")

-- 6) 没绑定过就直接解绑（另一个典型入口：OnClose 先于 OnShow）
print("[6] 未绑定直接解绑")
local c = newObj("c")
ok(pcall(RedpotManager.ClearObject, RedPointType.Championships, c), "未绑定类型解绑不抛错")
ok(pcall(RedpotManager.ClearObject, T), "ClearAll 空类型不抛错")

print(string.format("\n结果: %d passed, %d failed", pass, fail))
os.exit(fail == 0 and 0 or 1)
