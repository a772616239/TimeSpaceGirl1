-- 红点树（RedPointData / RedpotManager 关系配置）回归
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=<repo> LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_redpoint_tree.lua
--
-- 背景（2026-10-21）：
--   症状「LogisticsMainPanel/page4 外面有红点，点进 LeadPanel 一个红点都没有」。
--   父红点状态 = 子红点按位或，而 Lead 有 5 个子红点，其中 Lead_SpeedLvUp 的落点只在
--   研发面板（LeadRAndDPanel/btnUpLv）里，LeadPanel 上没有任何节点表示它 ⇒ 外面亮、里面空。
--   修法：Lead_SpeedLvUp 不再挂到 Lead 名下（只保留研发面板内的局部红点）。
--
--   顺带把「检测函数抛错会把整棵树冻在旧值」也钉住：CheckRedPoint 现在用 pcall 兜底，
--   抛错按不显示处理并落日志，父节点因此能正常回落。

local ROOT = os.getenv("TS_ROOT") or os.getenv("PWD")
local SRC = ROOT .. "/Assets/ManagedResources/~Lua/Modules/Player/RedPointData.lua"

--==================== 桩 ====================
local bit = require("bit")
BitMath = {
    lShiftOp = function(a, b) return bit.lshift(a, b) end,
    orOp     = function(a, b) return bit.bor(a, b) end,
    andOp    = function(a, b) return bit.band(a, b) end,
    notOp    = function(a) return bit.bnot(a) end,
}
Log = function() end
local redLogs = {}
LogRed = function(s) redLogs[#redLogs + 1] = tostring(s) end
ActTimeCtrlManager = { SingleFuncState = function() return true end }

local RP = dofile(SRC)

--==================== 断言 ====================
local pass, fail = 0, 0
local fails = {}
local function check(name, got, want)
    if got == want then
        pass = pass + 1
    else
        fail = fail + 1
        fails[#fails + 1] = string.format("%s  got=%s want=%s", name, tostring(got), tostring(want))
    end
end

--==================== 场景 1：修复后的 Lead 树（4 个可见子红点） ====================
-- LeadPanel 里能看到的：装配 / 普通研发 / 特权研发 / 主角升级
local VISIBLE = { "Lead_Assembly", "Lead_Normal", "Lead_Privilege", "Lead_UpLv" }
local state = {}
for _, k in ipairs(VISIBLE) do
    RP:SetParent(k, "Lead")
    RP:AddCheckFunc(k, function() return state[k] == true end)
end
-- 研发等级红点：不在 Lead 名下，只有一个局部落点（研发面板）
RP:AddCheckFunc("Lead_SpeedLvUp", function() return state["Lead_SpeedLvUp"] == true end)

local function refreshAll()
    for _, k in ipairs(VISIBLE) do RP:CheckRedPoint(k) end
    RP:CheckRedPoint("Lead_SpeedLvUp")
end

state = {}
refreshAll()
check("全灭 → 神眷者入口红点灭", RP:GetRedValue("Lead"), 0)

state = { Lead_SpeedLvUp = true }
refreshAll()
check("只有研发等级可升级 → 入口红点灭（LeadPanel 里看不到它）", RP:GetRedValue("Lead"), 0)
check("研发等级自身的局部红点仍然亮", RP:GetRedValue("Lead_SpeedLvUp"), 1)

state = { Lead_Normal = true }
refreshAll()
check("普通研发可做 → 入口红点亮", RP:GetRedValue("Lead") ~= 0, true)

state = { Lead_UpLv = true }
refreshAll()
check("主角可升级 → 入口红点亮", RP:GetRedValue("Lead") ~= 0, true)

state = {}
refreshAll()
check("状态回落 → 入口红点灭（不会残留）", RP:GetRedValue("Lead"), 0)

--==================== 场景 2：父节点不能自己注册检测函数 ====================
-- 这也是「研发等级红点不能挂到 Lead_Normal 名下」的原因：一旦成为父节点，
-- AddCheckFunc(Lead_Normal, ...) 会被静默丢弃，普通研发红点就永远不刷新了。
local before = RP:GetCheckList()["Lead_Normal"]
RP:AddCheckFunc("Lead_Normal", function() return true end)
check("父节点注册检测函数被拒绝（普通研发不会被顶掉）", RP:GetCheckList()["Lead_Normal"], before)
check("父节点也不能被直接 SetRedValue", RP:SetRedValue("Lead", 1), false)

--==================== 场景 3：检测函数抛错不冻结整棵树 ====================
local throwNode = "Throw_Leaf"
RP:SetParent(throwNode, "Lead")
RP:AddCheckFunc(throwNode, function() error("模拟检测函数崩溃") end)
state = { Lead_Privilege = true }
refreshAll()
RP:CheckRedPoint("Throw_Leaf")   -- 不能向外抛异常
check("抛错的叶子节点按不显示处理", RP:GetRedValue(throwNode), 0)
check("同轮其它子红点照常生效（特权研发仍亮）", RP:GetRedValue("Lead_Privilege"), 1)
check("抛错有落日志（LogRed 被调用）", #redLogs > 0, true)

print(string.format("红点树回归：%d 通过，%d 失败", pass, fail))
for _, f in ipairs(fails) do print("  ❌ " .. f) end
os.exit(fail == 0 and 0 or 1)
