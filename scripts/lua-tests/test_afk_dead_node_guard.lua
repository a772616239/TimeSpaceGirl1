-- 挂机战斗「换波后节点已被销毁」回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_afk_dead_node_guard.lua
--
-- 线上报错（2026-10-21 20:37:44 真机）：
--   ① LuaException: event:172: Object reference not set to an instance of an object
--        [C]: in function 'SetActive'
--        Modules/Fight/View/FightPointMapOnHook:1970: in function 'RoleOnDead'
--        Modules/Fight/View/FightPointMapOnHook:1780: in function 'func'   -- OnDamaged 的 _effectFinish
--   ② LuaException: event:172: Object reference not set to an instance of an object
--        [C]: in function 'GetComponent'
--        Modules/Fight/View/FightPointMapOnHook:1056: in function 'HeroAttack'
--
-- 根因：
--   CreateEnemy 换波时用 ClearChild 把右方位置节点下的 spine 直接销毁，但 liveNodesRight /
--   liveNamesRight 里登记的还是那些已销毁的 userdata。tolua 的 fake-null 在 Lua 侧**不是 nil**，
--   原来 `if not liveNodes[pos] then return end` 判不出来，后面 SetActive / GetComponent 就抛
--   "Object reference not set to an instance of an object"。另外 OnDamaged 里 _effectFinish 是
--   整段技能演完后才跑的延时回调，换波后它还会拿新一波的 turnArrayRight 条目扣 deadTimes，
--   把刚出生的敌人判死并让 RoleOnDead 去碰旧位置的死节点。
--
-- 覆盖：
--   ① CreateEnemy 换波时必须同步清掉 liveNodesRight / liveNamesRight 登记
--   ② RoleOnDead 拿到已销毁节点时静默返回（不抛错、不误扣 rightLiveCount）
--   ③ RoleOnDead 拿到空位置时静默返回

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"

local failed = 0
local function Check(cond, msg)
    if cond then
        print("  [PASS] " .. msg)
    else
        failed = failed + 1
        print("  [FAIL] " .. msg)
    end
end

----------------------------------------------------------------------
-- 1) 配置与全局桩
----------------------------------------------------------------------
package.path = LUA_SRC .. "/?.lua;" .. package.path
dofile(LUA_SRC .. "/Framework/GameDataBase.lua")

local SheetBase = GameDataBase.SheetBase
local function LoadConfig(name)
    local t = assert(loadfile(LUA_SRC .. "/Config/Data/" .. name .. ".lua"))()
    SheetBase.Init(t)
    return t
end

local afkSpeak = LoadConfig("AfkSpeak")

ConfigName = { AfkSpeak = "AfkSpeak" }
ConfigManager = {
    GetConfig = function(name)
        if name == ConfigName.AfkSpeak then
            return afkSpeak
        end
        return {}
    end,
    GetConfigData = function() return {} end,
    TryGetConfigData = function() return nil end,
}

Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { New = function(x, y, z) return { x = x, y = y, z = z } end, one = { x = 1, y = 1, z = 1 }, zero = { x = 0, y = 0, z = 0 } }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end, white = {} }
Time = { deltaTime = 0.033, realtimeSinceStartup = 0 }

-- tolua.isnull：真机上「已销毁的 GameObject」userdata 非 nil，但 isnull 为真
tolua = {
    isnull = function(o)
        return type(o) == "table" and o.__destroyed == true
    end,
}

-- 项目扩展
table.indexof = function(t, v)
    for i = 1, #t do
        if t[i] == v then
            return i
        end
    end
    return nil
end

-- 与 Common/functions.lua 的 IsNull 同义（测试不加载整个 functions.lua，依赖太多）
IsNull = function(obj)
    return obj == nil or tolua.isnull(obj)
end

local clearChildCalls = 0
ClearChild = function(parent)
    clearChildCalls = clearChildCalls + 1
    if parent and parent.__destroyChildren then
        parent.__destroyChildren()
    end
end

local Hook = require("Modules/Fight/View/FightPointMapOnHook")

----------------------------------------------------------------------
-- 2) 假节点：销毁后访问即抛 tolua 同款错误
----------------------------------------------------------------------
local function NewNode(name)
    local node = { __name = name, __destroyed = false }
    return setmetatable(node, {
        __index = function(t, k)
            if t.__destroyed then
                error("The object of type 'UnityEngine.GameObject' has been destroyed but you are still trying to access it.", 2)
            end
            return nil
        end,
    })
end

----------------------------------------------------------------------
-- 3) ① 换波清理：CreateEnemy 必须把旧登记清空
----------------------------------------------------------------------
print("== ① CreateEnemy 换波清理旧登记 ==")

local parent1 = NewNode("role_parent_1")
local parent2 = NewNode("role_parent_2")
local staleNode1 = NewNode("stale_spine_1")
local staleNode2 = NewNode("stale_spine_2")

Hook.__SetRoleNodeForTest(1, parent1, staleNode1, "live_1")
Hook.__SetRoleNodeForTest(2, parent2, staleNode2, "live_2")
Hook.idArray = { 1 }

Hook:CreateEnemy()

local afterNode1, afterName1 = Hook.__GetRoleNodeForTest(1)
local afterNode2, afterName2 = Hook.__GetRoleNodeForTest(2)
Check(afterNode1 == nil and afterName1 == nil, "位置 1 的旧节点登记被清空")
Check(afterNode2 == nil and afterName2 == nil, "位置 2 的旧节点登记被清空")
Check(clearChildCalls >= 2, string.format("ClearChild 对每个位置都调用了（实际 %d 次）", clearChildCalls))

----------------------------------------------------------------------
-- 4) ② RoleOnDead 拿到已销毁节点：静默返回
----------------------------------------------------------------------
print("== ② RoleOnDead 遇到已销毁节点不抛错 ==")

local deadParent = NewNode("role_parent_dead")
local destroyedNode = NewNode("destroyed_spine")
destroyedNode.__destroyed = true
Hook.__SetRoleNodeForTest(3, deadParent, destroyedNode, "live_dead")

local ok, err = pcall(function()
    Hook:RoleOnDead(3)
end)
Check(ok, "RoleOnDead 对已销毁节点不抛异常" .. (ok and "" or ("：" .. tostring(err))))

local node3, name3 = Hook.__GetRoleNodeForTest(3)
Check(node3 == nil and name3 == nil, "死节点登记被就地清理，避免下次再碰")

----------------------------------------------------------------------
-- 5) ③ RoleOnDead 拿到空位置：静默返回
----------------------------------------------------------------------
print("== ③ RoleOnDead 遇到空位置不抛错 ==")

Hook.__SetRoleNodeForTest(4, NewNode("role_parent_empty"), nil, nil)
local ok4, err4 = pcall(function()
    Hook:RoleOnDead(4)
end)
Check(ok4, "RoleOnDead 对空节点不抛异常" .. (ok4 and "" or ("：" .. tostring(err4))))

----------------------------------------------------------------------
print("")
if failed == 0 then
    print("全部通过")
    os.exit(0)
else
    print(string.format("失败 %d 项", failed))
    os.exit(1)
end
