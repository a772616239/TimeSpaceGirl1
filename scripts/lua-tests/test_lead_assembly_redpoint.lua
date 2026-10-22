-- 神眷者「装配」红点 与 装配面板 同口径回归测试（不依赖 Unity，直接用 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_lead_assembly_redpoint.lua
--
-- 背景：LeadPanel/btnAssembly 亮红点、点进去却「没有材料可装」。
--   红点(CheckRedPointForSkill) 和面板(GetBagAllDatas) 各自算一套「能不能装」，
--   口径一旦分叉就必然出现「外面亮、里面没东西」。
--   现在两边都走 GetEquippableSkillList()：有空槽 + 未装配 + 类型不冲突。
--
-- 覆盖点：
--   · 测试号实况（lv1 / 1 个酒神基因 101003 / 未装配）→ 可装 1 个，红点亮
--   · 空槽占满（lv1 装 1 个）→ 不可装，红点灭
--   · 类型冲突（已装 Type3，背包也是 Type3）→ 不可装，红点灭（服务端会报 SAME_TYPE）
--   · 有槽但背包为空 → 不可装，红点灭
--   · 多类型时可装列表按类型去重（同类型只留一个候选）
--   · 功能未开启 → 不可装，红点灭

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ---- 最小环境桩 ----
Log = function() end
LogRed = Log
LogGreen = Log
LogWarn = Log
LogError = Log
FUNCTION_OPEN_TYPE = { AIRCRAFT_CARRIER = 60 }
local funcOpen = true
ActTimeCtrlManager = {
    SingleFuncState = function(t) return funcOpen end,
}

-- 表桩：键就是 Id
local MotherShipConfig = {}
local MotherShipPlaneConfig = {}
local EmptyConfig = {}
ConfigName = setmetatable({}, { __index = function(_, k) return k end })
ConfigManager = {
    GetConfig = function(name)
        if name == "MotherShipConfig" then return MotherShipConfig end
        if name == "MotherShipPlaneConfig" then return MotherShipPlaneConfig end
        return EmptyConfig
    end,
    GetAllConfigDataByDoubleKey = function() return {} end,
    GetAllConfigsDataByKey = function() return {} end,
}

local failCount = 0
local function check(name, cond, extra)
    if cond then
        print(string.format("  ✅ %s", name))
    else
        failCount = failCount + 1
        print(string.format("  ❌ %s %s", name, extra or ""))
    end
end

-- ---- 基础表：lv1 只开 1 个基因栏位；101003 是 Type3 的 1 星基因 ----
local function resetTables()
    for k in pairs(MotherShipConfig) do MotherShipConfig[k] = nil end
    for k in pairs(MotherShipPlaneConfig) do MotherShipPlaneConfig[k] = nil end
    -- Id == motherShipLevel
    MotherShipConfig[1] = { Id = 1, Level = 1, UnlockSite = 1 }
    MotherShipConfig[2] = { Id = 2, Level = 2, UnlockSite = 1 }
    MotherShipConfig[11] = { Id = 11, Level = 10, UnlockSite = 2 }
    -- 基因：Type 3/4/5 各一个，Lvl 1
    MotherShipPlaneConfig[101003] = { Id = 101003, Type = 3, Lvl = 1, Skill = 910311 }
    MotherShipPlaneConfig[101004] = { Id = 101004, Type = 4, Lvl = 1, Skill = 910411 }
    MotherShipPlaneConfig[101005] = { Id = 101005, Type = 5, Lvl = 1, Skill = 910511 }
end

resetTables()
local Manager = require("Modules/AircraftCarrier/AircraftCarrierManager")

-- ---- 场景构造 ----
-- owned: {{id, cfgId}, ...}  equipped: {{id, cfgId, sort}, ...}
local function setState(lv, owned, equipped)
    Manager.LeadData = { lv = lv, skill = {} }
    for i = 1, #equipped do
        Manager.LeadData.skill[i] = {
            id = equipped[i][1], cfgId = equipped[i][2], sort = equipped[i][3],
        }
    end
    Manager.allSkillData = {}
    for i = 1, #owned do
        Manager.allSkillData[owned[i][1]] = {
            id = owned[i][1], cfgId = owned[i][2], sort = 0,
        }
    end
    Manager.lastEquipStat = nil
end

print("1) 测试号实况：lv1 / 1 个 101003 / 未装配")
setState(1, { { "p1", 101003 } }, {})
local list = Manager.GetEquippableSkillList()
check("可装 1 个", #list == 1, "实际 " .. #list)
check("红点亮", Manager.CheckRedPointForSkill() == true)
check("候选 cfgId=101003", list[1] and list[1].cfgId == 101003)
check("诊断 stat: max=1 equip=0 bag=1",
    Manager.lastEquipStat and Manager.lastEquipStat.max == 1
    and Manager.lastEquipStat.equip == 0 and Manager.lastEquipStat.bag == 1,
    Manager.lastEquipStat and string.format("max=%s equip=%s bag=%s",
        tostring(Manager.lastEquipStat.max), tostring(Manager.lastEquipStat.equip),
        tostring(Manager.lastEquipStat.bag)) or "nil")

print("2) 空槽占满：lv1 已装 1 个")
setState(1, { { "p1", 101003 } }, { { "p1", 101003, 1 } })
check("可装 0 个", #Manager.GetEquippableSkillList() == 0)
check("红点灭", Manager.CheckRedPointForSkill() == false)

print("3) 类型冲突：已装 Type3，背包也是 Type3")
setState(11, { { "p1", 101003 }, { "p2", 101003 } }, { { "p1", 101003, 1 } })
check("可装 0 个（同类型不能再装）", #Manager.GetEquippableSkillList() == 0)
check("红点灭", Manager.CheckRedPointForSkill() == false)

print("4) 背包为空")
setState(11, {}, {})
check("可装 0 个", #Manager.GetEquippableSkillList() == 0)
check("红点灭", Manager.CheckRedPointForSkill() == false)

print("5) 多类型去重：lv 开 2 槽，装 1 个 Type3，背包 Type4 x2 + Type5 x1")
setState(11,
    { { "p1", 101003 }, { "p2", 101004 }, { "p3", 101004 }, { "p4", 101005 } },
    { { "p1", 101003, 1 } })
local l5 = Manager.GetEquippableSkillList()
check("可装 2 个（Type4 + Type5 各一）", #l5 == 2, "实际 " .. #l5)
check("红点亮", Manager.CheckRedPointForSkill() == true)

print("6) 功能未开启")
funcOpen = false
setState(1, { { "p1", 101003 } }, {})
check("可装 0 个", #Manager.GetEquippableSkillList() == 0)
check("红点灭", Manager.CheckRedPointForSkill() == false)
funcOpen = true

print("7) LeadData 未加载（登录早期）")
Manager.LeadData = nil
Manager.lastEquipStat = nil
check("可装 0 个且不抛错", #Manager.GetEquippableSkillList() == 0)
check("红点灭", Manager.CheckRedPointForSkill() == false)

print("")
if failCount == 0 then
    print("全部通过")
else
    print(string.format("失败 %d 项", failCount))
    os.exit(1)
end
