-- 成就页「领奖后列表整体变空」回归测试
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=<repo> LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_missiondaily_achv_list_never_empty.lua
--
-- 症状：
--   成就页领完奖励（尤其「一键领取」）后，整页列表突然全空。
--
-- 根因：
--   Modules/Task/TaskManager.lua 的 GetCurShowAllAchievementData 里有两个过滤条件：
--     ② PreId 链门：PreId == -1 或「上一步已领取」才放行
--     ① if curTaskData.state ~= 2 then -- 已领取的整条剔除
--   领奖链路（单张 :361 / 一键 :233）做的事就是把 state 置 2 ⇒ 每个被领的条目
--   立刻从列表消失；一键领取把全部当前档同时置 2 ⇒ 可见 0 条。
--   面板侧 MissionDailyPanel_Achievement 本来就有已领取态渲染
--   （Received:SetActive(state == 2)，:330）与拖底排序（sortTable[2] = 0，:384-388），
--   说明 state==2 本该留在列表里 —— 那两个分支在原实现下永远走不到。
--
-- 修复：
--   去掉条件 ①（保留链门 ②）。列表只增不减，已领取的条目显示「已领取」并沉底。
--
-- 本测试从 TaskManager.lua 里抽出真实函数体跑，并保留一份「修复前实现」做对照，
-- 确保测试本身抓得到这个 bug（否则修完再犯也测不出来）。

local ROOT = os.getenv("TS_ROOT") or os.getenv("PWD")
local SRC = ROOT .. "/Assets/ManagedResources/~Lua/Modules/Task/TaskManager.lua"

local pass, fail = 0, 0
local fails = {}
local function check(name, cond, extra)
    if cond then
        pass = pass + 1
    else
        fail = fail + 1
        fails[#fails + 1] = name .. (extra ~= nil and (" [" .. tostring(extra) .. "]") or "")
    end
end

-- ================= 抽取真实函数体 =================
local fh = assert(io.open(SRC, "rb"), "找不到 TaskManager.lua: " .. SRC)
local text = fh:read("*a")
fh:close()

local s = text:find("local achievementConfig = ConfigManager.GetConfig(ConfigName.AchievementConfig)", 1, true)
check("TaskManager.lua 仍存在 achievementConfig 声明", s ~= nil)
local e = s and text:find("--获取混乱之治任务", s, true)
check("能截到函数结尾（获取混乱之治任务注释）", e ~= nil)
local chunk = s and e and text:sub(s, e - 1)
check("抽出的函数体非空", chunk ~= nil and #chunk > 300, chunk and #chunk)
check("函数体内仍含 GetCurShowAllAchievementData", chunk ~= nil and chunk:find("GetCurShowAllAchievementData", 1, true) ~= nil)

-- 抽出真实函数体后必须能运行（语法错误会在这里炸）
local loaderOk, loaderErr = pcall(loadstring, chunk)
check("抽出的函数体语法合法", loaderOk, loaderErr)

-- ================= 沙箱 =================
-- 合成配置：链1 = 1→2→3（RefSysId 1）；链2 = 4→5（RefSysId 2）；链3 = 6（RefSysId 3，单档）
local CONFIG = {
    [1] = { Id = 1, PreId = -1, RefSysId = 1 },
    [2] = { Id = 2, PreId = 1,  RefSysId = 1 },
    [3] = { Id = 3, PreId = 2,  RefSysId = 1 },
    [4] = { Id = 4, PreId = -1, RefSysId = 2 },
    [5] = { Id = 5, PreId = 4,  RefSysId = 2 },
    [6] = { Id = 6, PreId = -1, RefSysId = 3 },
}
local ALL_IDS = { 1, 2, 3, 4, 5, 6 }

local ACHIEVEMENT = 5  -- TaskTypeDef.Achievement（type 只作为表 key，值不影响逻辑）

-- states: {[missionId] = 0/1/2} 缺省 0；gate: {[RefSysId] = false} 表示功能未开
local function runReal(states, gate)
    gate = gate or {}
    local tasks = {}
    for i, id in ipairs(ALL_IDS) do
        tasks[i] = { missionId = id, state = states[id] or 0, type = ACHIEVEMENT }
    end
    local this = {}
    local env = {
        ConfigManager = { GetConfig = function() return CONFIG end },
        ConfigName = { AchievementConfig = "AchievementConfig" },
        ActTimeCtrlManager = {
            SingleFuncState = function(refSysId) return gate[refSysId] ~= false end,
        },
        TypeTaskData = { [ACHIEVEMENT] = tasks },
        this = this,
    }
    local f = assert(loadstring(chunk, "=TaskManager.extracted"))
    setfenv(f, env)
    f()
    return this.GetCurShowAllAchievementData(ACHIEVEMENT)
end

-- 「修复前实现」冻结副本（用于证明测试抓得住这个 bug）
local function runOld(states, gate)
    gate = gate or {}
    local okData, shown = {}, {}
    for _, id in ipairs(ALL_IDS) do
        if (states[id] or 0) == 2 then okData[id] = true end
    end
    for _, id in ipairs(ALL_IDS) do
        local cfg = CONFIG[id]
        if gate[cfg.RefSysId] ~= false then
            if cfg.PreId == -1 or okData[cfg.PreId] then
                if (states[id] or 0) ~= 2 then
                    shown[id] = true
                end
            end
        end
    end
    return shown
end

local function visibleIds(shown)
    local out = {}
    for id in pairs(shown) do out[#out + 1] = id end
    table.sort(out)
    return out
end
local function eq(list)
    local t = {}
    for _, v in ipairs(list) do t[v] = true end
    return t
end
local function sameSet(shown, list, name)
    local got = visibleIds(shown)
    local ok = #got == #list
    if ok then
        for i, v in ipairs(list) do if got[i] ~= v then ok = false break end end
    end
    check(name, ok, table.concat(got, ","))
end
local function count(shown)
    local n = 0
    for _ in pairs(shown) do n = n + 1 end
    return n
end

-- ================= 用例 1：全未完成，只有每条链的首档可见 =================
local s1 = {}
for _, id in ipairs(ALL_IDS) do s1[id] = 0 end
sameSet(runReal(s1), { 1, 4, 6 }, "全未完成 ⇒ 每条链只露首档")

-- ================= 用例 2：链门仍生效（父未领则子不可见，即使子 state==1） =================
local s2 = { [1] = 0, [2] = 1 }
sameSet(runReal(s2), { 1, 4, 6 }, "父未领 ⇒ 子(可领取)也不可见")

-- ================= 用例 3：领一张 —— 该张留在列表，下一档顶上来 =================
local s3 = { [1] = 2 }
sameSet(runReal(s3), { 1, 2, 4, 6 }, "领掉第1档 ⇒ 第1档仍在 + 第2档出现")

-- ================= 用例 4（核心回归）：一键领取（全部已领取）⇒ 列表不为空 =================
local s4 = {}
for _, id in ipairs(ALL_IDS) do s4[id] = 2 end
local shown4 = runReal(s4)
check("全领完 ⇒ 列表不为空（核心回归）", count(shown4) > 0, count(shown4))
sameSet(shown4, ALL_IDS, "全领完 ⇒ 全部条目留在列表（显示已领取）")

-- 对照：修复前实现全领完必然是 0 条（证明本测试抓得住这个 bug）
check("修复前实现：全领完 ⇒ 0 条（对照）", count(runOld(s4)) == 0, count(runOld(s4)))

-- ================= 用例 5：功能门关闭时整链隐藏（与本次修复无关，防误伤） =================
local shown5 = runReal(s1, { [2] = false })
sameSet(shown5, { 1, 6 }, "RefSysId=2 功能未开 ⇒ 链2 整链隐藏")

-- 全领完 + 功能门关闭：仍然不能出现「全空」
local g6 = {}
for _, id in ipairs(ALL_IDS) do g6[id] = 2 end
local shown6 = runReal(g6, { [2] = false, [3] = false })
sameSet(shown6, { 1, 2, 3 }, "全领完且只剩一条链开门 ⇒ 该链全部留着")

-- ================= 用例 6：返回表是「missionId → 任务」且不重复 =================
local shown7 = runReal({ [1] = 2, [2] = 2 })
local dup = false
local n = 0
for id, task in pairs(shown7) do
    n = n + 1
    if task.missionId ~= id then dup = true end
end
check("返回表以 missionId 为键且任务自洽", not dup, n)
check("同一 missionId 不出现在两个槽位", n == count(shown7))

-- ================= 用例 7：源码里不能再把 state==2 的条目剔掉 =================
-- 防止有人「顺手优化」把过滤加回来：函数体内不许出现「state ~= 2」的剔除分支
local body = chunk:match("function this%.GetCurShowAllAchievementData%b()(.*)")
check("已取到 GetCurShowAllAchievementData 函数体", body ~= nil)
if body then
    local bad = body:find("state%s*~=%s*2", 1)
    check("函数体内不再有 state ~= 2 剔除分支", bad == nil, bad)
    local keep = body:find("curShowAllAchievementData[curTaskData.missionId] = curTaskData", 1, true)
    check("仍在无条件写入 curShowAllAchievementData", keep ~= nil)
end

-- ================= 用例 8：面板侧「已领取沉底 + 已领取态」仍在位 =================
local PANEL = ROOT .. "/Assets/ManagedResources/~Lua/Modules/Mission/MissionDailyPanel_Achievement.lua"
local ph = io.open(PANEL, "rb")
check("能找到成就面板源码", ph ~= nil, PANEL)
if ph then
    local ptext = ph:read("*a")
    ph:close()
    check("面板保留 Received:SetActive(state == 2)", ptext:find("Received:SetActive%(state%s*==%s*2%)") ~= nil)
    check("排序表保留 state==2 沉底权重", ptext:find("%[2%]%s*=%s*0") ~= nil)
    check("领奖回调仍走静默刷新（不重播入场）", ptext:find("RefreshAchievementSilently") ~= nil)
end

-- ================= 结果 =================
print(("="):rep(60))
if fail == 0 then
    print(("PASS  %d/%d"):format(pass, pass))
else
    print(("FAIL  %d failed / %d total"):format(fail, pass + fail))
    for _, f in ipairs(fails) do print("  ✗ " .. f) end
    os.exit(1)
end
