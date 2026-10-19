-- 挂机气泡「台词去重」回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_afk_talk_dedupe.lua
--
-- 背景：
--   挂机里 HeroTalk 一次最多让 2 个人同帧冒泡，两人各自从「英雄专属 + 通用池」里独立抽，
--   于是出现过两个人同一秒说同一句的情况（线上实例："Real goods are in the wild."，通用池的第 13 条）。
--   现在所有冒泡都走 Hook.PickFreshTalk(pool, recent)：
--     · 同一次 HeroTalk 的两个气泡共用一个 recent，第一句挑完立刻入表 => 第二句必然不同；
--     · recent 跨场保留（先进先出，上限 Hook.TALK_RECENT_CAP）=> 相邻几场也不会重复。
--
-- 覆盖：
--   ① 边界：nil 池 / 空池 / 单元素池
--   ② 整池遍历：池里 N 条，连续取 N 次互不重复；第 N+1 次才允许开始重复
--   ③ 同帧双人：同一 recent 连取两次永不相等（真实通用池 + 真实大招通用池）
--   ④ recent 容量：不超过上限，且最老的先被丢弃
--   ⑤ 真实池容量：通用池 20 条、大招通用池 8 条确实能撑满一轮不重复

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
-- 1) 用游戏自己的解码器把配置读成「按 Id 索引」的表
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

function ConfigPairs(t)
    local keys = SheetBase.GetKeys(t)
    local i = 0
    return function()
        i = i + 1
        local key = keys[i]
        if key == nil then
            return nil
        end
        return i, t[key]
    end
end

ConfigName = {
    AfkSpeak = "AfkSpeak",
    Language = "Language",
}
ConfigManager = {
    GetConfig = function(name)
        if name == ConfigName.AfkSpeak then
            return afkSpeak
        end
        return {}
    end,
}

----------------------------------------------------------------------
-- 2) 加载被测模块
----------------------------------------------------------------------
Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { New = function(x, y, z) return { x = x, y = y, z = z } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end, white = {} }
Time = { deltaTime = 0.033, realtimeSinceStartup = 0 }

local Hook = require("Modules/Fight/View/FightPointMapOnHook")
local PickFreshTalk = Hook.PickFreshTalk
local CAP = Hook.TALK_RECENT_CAP

print("== ① 边界 ==")
Check(PickFreshTalk(nil, {}) == nil, "nil 池返回 nil")
Check(PickFreshTalk({}, {}) == nil, "空池返回 nil")
Check(PickFreshTalk({ 42 }, {}) == 42, "单元素池直接返回该元素")
local oneRecent = {}
PickFreshTalk({ 42 }, oneRecent)
PickFreshTalk({ 42 }, oneRecent)
Check(#oneRecent == 2, "单元素池被掏空后仍会返回（宁可重复也别不说话）")

print("== ② 整池遍历不重复 ==")
local N = 10
local pool = {}
for i = 1, N do
    pool[i] = 9000 + i
end
local recent = {}
local seen, dupAt = {}, nil
for round = 1, N do
    local id = PickFreshTalk(pool, recent)
    if seen[id] ~= nil then
        dupAt = round
    end
    seen[id] = true
end
Check(dupAt == nil, string.format("连续 %d 次抽 10 条池，前 %d 次无重复", N, N))
Check(#recent == N, string.format("recent 记录了 %d 条（实际 %d）", N, #recent))
local after = PickFreshTalk(pool, recent)
Check(after ~= nil and pool[1] ~= nil and seen[after] == true, "第 N+1 次允许开始重复，但仍从池里出")

print("== ③ 同帧双人不同句（真实池） ==")
local HERO_ID = 10001
local talkPool = Hook.BuildTalkPool(afkSpeak, HERO_ID, nil, nil)
local ultPool = Hook.BuildUltPool(afkSpeak, HERO_ID, nil)
Check(#talkPool == 21, string.format("通用池规模 21（英雄 1 + 通用 20），实际 %d", #talkPool))
Check(#ultPool >= 2, string.format("大招池不少于 2 条，实际 %d", #ultPool))

local function SameMomentCollision(p, rounds)
    local r = {}
    local hit = 0
    for _ = 1, rounds do
        -- 同一时刻的两个气泡：共用 recent，且第二个人用 avoid 避开第一个人
        local shown = {}
        local a = PickFreshTalk(p, r, shown)
        shown[a] = true
        local b = PickFreshTalk(p, r, shown)
        if a == b then
            hit = hit + 1
        end
    end
    return hit
end
Check(SameMomentCollision(talkPool, 500) == 0, "通用池 500 轮同帧双人，0 次撞句")
Check(SameMomentCollision(ultPool, 500) == 0, "大招池 500 轮同帧双人，0 次撞句")

print("== ③b 池子被历史掏空时也不撞 ==")
-- 2 条池：两条都进过 recent，第一个人又正在显示另一条，第二个人也不能拿到同一条
local tinyPool = { 7001, 7002 }
local tinyRecent = { 7001, 7002 }
local tinyShown = {}
local first = PickFreshTalk(tinyPool, tinyRecent, tinyShown)
tinyShown[first] = true
local second = PickFreshTalk(tinyPool, tinyRecent, tinyShown)
Check(first ~= second, string.format("2 条池耗尽时同帧仍不同句（%s vs %s）", tostring(first), tostring(second)))

print("== ④ recent 容量与淘汰顺序 ==")
local many = {}
for i = 1, CAP + 10 do
    many[i] = 1000 + i
end
local rec = { 1, 2, 3 }
for i = 1, CAP + 10 do
    PickFreshTalk(many, rec)
end
Check(#rec == CAP, string.format("recent 长度被裁到上限 %d（实际 %d）", CAP, #rec))
Check(rec[1] ~= 1 and rec[1] ~= 2 and rec[1] ~= 3, "最老的记录先被淘汰")

print("== ⑤ 真实池能撑满一轮 ==")
-- 线上撞句的那句就在通用池里，验证：通用池 20 条连续说 20 次不重复
local genericPool = {}
for _, v in ConfigPairs(afkSpeak) do
    if v.Type == 0 then
        table.insert(genericPool, v.AfkDialogue)
    end
end
Check(#genericPool == 20, string.format("通用池 20 条（实际 %d）", #genericPool))
local r2, dupRound = {}, 0
local seen2 = {}
for round = 1, #genericPool do
    local id = PickFreshTalk(genericPool, r2)
    if seen2[id] then
        dupRound = round
    end
    seen2[id] = true
end
Check(dupRound == 0, "通用池 20 条连续 20 次全部不同")

local ultGeneric = {}
for _, v in ConfigPairs(afkSpeak) do
    if v.Type == Hook.ULT_TALK_TYPE_GENERIC then
        table.insert(ultGeneric, v.AfkDialogue)
    end
end
Check(#ultGeneric == 8, string.format("大招通用池 8 条（实际 %d）", #ultGeneric))
local r3, dup3 = {}, 0
local seen3 = {}
for round = 1, #ultGeneric do
    local id = PickFreshTalk(ultGeneric, r3)
    if seen3[id] then
        dup3 = round
    end
    seen3[id] = true
end
Check(dup3 == 0, "大招通用池 8 条连续 8 次全部不同")

print("")
if failed == 0 then
    print("全部通过")
else
    print(string.format("失败 %d 项", failed))
    os.exit(1)
end
