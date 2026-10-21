-- 契约（GeneralInfoPanel）红点口径回归
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=<repo> LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_general_redpoint.lua
--
-- 背景（2026-10-21）：
--   症状「GeneralInfoPanel 里没有材料，5 个契约页签也一直显示红点」。
--   两个成因一起修：
--   1) 页签红点口径原来含 IsCanUnlock（只看「有没有可献祭的 5 星同系英雄」，与材料无关），
--      而 btns/btnN/redpoint 在 prefab 里 m_IsActive=1（默认亮）⇒ 一旦刷新链路被中途打断，
--      红点就永远停在「亮」。现在口径改为只认 IsCanUpLevel/IsCanAdvanced（材料够不够），
--      可解锁改挂 roleInfolockLayout/unLockBtn 上的红点；prefab 默认值也不再参与（InitComponent 先全灭）。
--   2) 判定函数在循环里裸调用，任何一次抛错都会让后面的页签/按钮轮不到 SetActive ⇒
--      统一走 SafeCheck(pcall) 兜底。
--   逻辑回归用桩跑（ConfigManager / BagManager / HeroManager 三个只读接口）。

local ROOT = os.getenv("TS_ROOT") or os.getenv("PWD")
local SRC = ROOT .. "/Assets/ManagedResources/~Lua/Modules/General/GeneralManager.lua"

--==================== 桩 ====================
local G = {
    general = {
        [1] = { GeneralId = 1, LockHero = { 5, 1, 1 } },
        [2] = { GeneralId = 2, LockHero = { 5, 1, 2 } },
    },
    level = {
        { GeneralId = 1, Lev = 1, TotalExp = 20, AddExp = 10, UpgradeExpend = { { 17002, 5 }, { 14, 49000 } } },
        { GeneralId = 1, Lev = 2, TotalExp = 20, AddExp = 10, UpgradeExpend = { { 17002, 6 }, { 14, 78400 } } },
        { GeneralId = 1, Lev = 3, TotalExp = 20, AddExp = 10, UpgradeExpend = { { 17002, 7 }, { 14, 107800 } } },
    },
    step = {
        { GeneralId = 1, StepLev = 1, GeneralLev = 10, UpgradeExpend = { { 17012, 2 }, { 17011, 10 } } },
        { GeneralId = 1, StepLev = 2, GeneralLev = 10, UpgradeExpend = { { 17012, 2 }, { 17011, 10 } } },
    },
}

ConfigName = {
    GeneralConfig = "GeneralConfig",
    GeneralLevelConfig = "GeneralLevelConfig",
    GeneralStepConfig = "GeneralStepConfig",
    PropertyConfig = "PropertyConfig",
}

local function filterEq(rows, key, value)
    local out = {}
    for _, r in ipairs(rows) do
        if r[key] == value then out[#out + 1] = r end
    end
    return out
end

ConfigManager = {
    GetConfig = function(name)
        if name == ConfigName.GeneralLevelConfig then return G.level end
        if name == ConfigName.GeneralStepConfig then return G.step end
        return G.general
    end,
    GetAllConfigsDataByKey = function(name, key, value)
        return filterEq(ConfigManager.GetConfig(name), key, value)
    end,
    TryGetConfigDataByDoubleKey = function(name, k1, v1, k2, v2)
        for _, r in ipairs(ConfigManager.GetConfig(name)) do
            if r[k1] == v1 and r[k2] == v2 then return r end
        end
        return nil
    end,
}

G_GeneralConfig = G.general
local redLogs = {}
LogRed = function(s) redLogs[#redLogs + 1] = tostring(s) end
ActTimeCtrlManager = { SingleFuncState = function() return true end }
FUNCTION_OPEN_TYPE = { GENERAL = 1 }

-- 背包（可调）
local bag, bagThrows = {}, false
BagManager = {
    GetItemCountById = function(id)
        if bagThrows and id == 14 then error("模拟背包数据异常") end
        return bag[id] or 0
    end,
}
local function setBag(t) bag = t or {} end

-- 英雄（可调）：每项 {dynamicId, star, property, inFormation}
local spareHeroes = {}
HeroManager = {
    GetUpStarHeroListData = function(_, heroData)
        local list = {}
        for _, h in ipairs(spareHeroes) do
            if h.star == 5 and h.property == heroData.property then
                list[#list + 1] = h
            end
        end
        return { heroList = list }
    end,
    GetAllHeroDatas = function()
        local list = {}
        for _, h in ipairs(spareHeroes) do
            list[#list + 1] = { id = h.dynamicId, star = h.star, property = h.property }
        end
        return list
    end,
    GetAllFormationByHeroId = function(dynamicId)
        local t = {}
        for _, h in ipairs(spareHeroes) do
            if h.dynamicId == dynamicId and h.inFormation then t[#t + 1] = 1 end
        end
        return t
    end,
}

--==================== 载入被测文件 ====================
dofile(SRC)
GeneralManager.SetAllGeneralDatas({ generalDate = {
    { id = 1, level = 1, rankUpLevel = 1, exp = 0 },
} })

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

-- 1) 页签口径：只认材料
setBag({})
check("空背包 → 契约1 页签红点灭", GeneralManager.CanUpgradeOrRank(1), false)
setBag({ [17002] = 5, [14] = 49000 })
check("材料恰好够 → 契约1 页签红点亮", GeneralManager.CanUpgradeOrRank(1), true)
setBag({ [17002] = 4, [14] = 49000 })
check("道具差 1 个 → 契约1 页签红点灭", GeneralManager.CanUpgradeOrRank(1), false)
setBag({ [17002] = 5, [14] = 48999 })
check("金钱差 1 → 契约1 页签红点灭", GeneralManager.CanUpgradeOrRank(1), false)

-- 2) 可解锁不再点亮页签，只落在解锁按钮
spareHeroes = { { dynamicId = 901, star = 5, property = 1 } }
setBag({})
check("有可献祭英雄但没材料 → 契约1 页签红点灭", GeneralManager.CanUpgradeOrRank(1), false)
check("已解锁的契约 → 解锁按钮红点灭", GeneralManager.CanUnlockNow(1), false)

spareHeroes = { { dynamicId = 902, star = 5, property = 2 } }
check("未解锁契约2 + 有 5 星同系 → 解锁按钮红点亮", GeneralManager.CanUnlockNow(2), true)
spareHeroes = {}
check("没有可用英雄 → 契约2 解锁按钮红点灭", GeneralManager.CanUnlockNow(2), false)
spareHeroes = { { dynamicId = 903, star = 5, property = 2, inFormation = true } }
check("同系 5 星都在编队 → 契约2 解锁按钮红点灭", GeneralManager.CanUnlockNow(2), false)

-- 3) 单条判定抛错不打断整轮刷新
setBag({ [17002] = 5, [14] = 49000 })
bagThrows = true
local ok = pcall(function()
    check("背包接口抛错 → 按不可升级处理", GeneralManager.SafeCheck(GeneralManager.IsCanUpLevel, 1), false)
    check("抛错后同轮仍能继续算别的判定", GeneralManager.SafeCheck(GeneralManager.IsCanAdvanced, 1), false)
end)
bagThrows = false
check("整轮刷新没有向外抛异常", ok, true)
check("抛错有落日志（LogRed 被调用）", #redLogs > 0, true)

print(string.format("契约红点回归：%d 通过，%d 失败", pass, fail))
for _, f in ipairs(fails) do print("  ❌ " .. f) end
os.exit(fail == 0 and 0 or 1)
