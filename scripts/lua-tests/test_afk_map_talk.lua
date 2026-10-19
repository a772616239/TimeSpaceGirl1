-- 挂机气泡「场景吐槽池」回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_afk_map_talk.lua
--
-- 背景：
--   AfkSpeak 表原来只有两种 Type —— 0（通用池，任何英雄都念）和英雄配置 Id（专属台词）。
--   现在新增第三种：9900 + 地图编号（Map2 -> 9902），放「当前场景的抱怨」，
--   由 FightPointMapOnHook:UpdateMap(map, mapName) 传入的地图名决定，命中率 40%。
--
-- 这个测试只覆盖纯逻辑 + 配置正确性，不碰 UI：
--   ① 地图名 -> 池 Type 的解析（Map2/Map5/Map7/Map8/Map1、非 MapN 形态、nil）
--   ② 池选取：命中场景池、未命中回退「英雄专属 + 通用池」、场景池缺失时自动回退
--   ③ 配置本身：5 个池各 8 条，40 条台词中/英/日都有，语言 Id 不重复

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
-- 1) 用游戏自己的解码器（纯 Lua）把配置读成「按 Id 索引」的表
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
local language = LoadConfig("Language")

-- ConfigPairs：游戏里的全局遍历辅助；这里按 Id 升序产出 (序号, 行)
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
-- 2) 加载被测模块（require 只缓存一次，整个文件只跑一遍）
----------------------------------------------------------------------
-- 模块在文件顶部就会调 Vector3.New 之类，给最小桩即可，不参与断言
Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { New = function(x, y, z) return { x = x, y = y, z = z } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end, white = {} }
Time = { deltaTime = 0.033, realtimeSinceStartup = 0 }

local Hook = require("Modules/Fight/View/FightPointMapOnHook")

print("== ① 地图名 -> 场景池 Type ==")
Check(Hook.MapTalkTypeFromName("Map1") == 9901, "Map1 -> 9901")
Check(Hook.MapTalkTypeFromName("Map2") == 9902, "Map2 -> 9902（雪地）")
Check(Hook.MapTalkTypeFromName("Map5") == 9905, "Map5 -> 9905（机械基地）")
Check(Hook.MapTalkTypeFromName("Map7") == 9907, "Map7 -> 9907（古树森林）")
Check(Hook.MapTalkTypeFromName("Map8") == 9908, "Map8 -> 9908（室内实验室）")
Check(Hook.MapTalkTypeFromName("gonghui") == nil, "非 MapN（公会地图）-> nil")
Check(Hook.MapTalkTypeFromName("Map") == nil, "没有数字 -> nil")
Check(Hook.MapTalkTypeFromName(nil) == nil, "nil -> nil")
Check(Hook.MapTalkTypeFromName(9902) == nil, "非字符串 -> nil")

print("== ② 池选取 ==")
local HERO_ID = 10001
local genOnly = Hook.BuildTalkPool(afkSpeak, HERO_ID, nil, 1)
local snowHit = Hook.BuildTalkPool(afkSpeak, HERO_ID, 9902, 1)
local snowMiss = Hook.BuildTalkPool(afkSpeak, HERO_ID, 9902, Hook.MAP_TALK_PERCENT + 1)
local unknownHit = Hook.BuildTalkPool(afkSpeak, HERO_ID, 9999, 1)

Check(#snowHit == 8, string.format("命中场景池只返回该地图 8 条（实际 %d）", #snowHit))
Check(#genOnly == 21, string.format("无场景时 = 英雄专属 1 + 通用 20（实际 %d）", #genOnly))
Check(#snowMiss == #genOnly, "未命中概率时回退到英雄专属 + 通用池")
Check(#unknownHit == #genOnly, "配了不存在的地图池时回退，不会不说话")

-- 命中场景池时，文本必须全部来自该地图
local function EnglishOf(lid)
    local row = language[tonumber(lid) or lid]
    return row and row.English or nil
end
local mapTexts = {}
for _, lid in ipairs(snowHit) do
    mapTexts[EnglishOf(lid)] = true
end
Check(mapTexts["Cold. My boots gave up."] == true, "Map2 命中池里确实是雪地台词")
Check(mapTexts["Neon everywhere. Still blind."] == nil, "Map2 池里不会混进霓虹都市台词")

-- 概率边界：roll == 40 命中、41 不命中
local atBound = Hook.BuildTalkPool(afkSpeak, HERO_ID, 9902, Hook.MAP_TALK_PERCENT)
local overBound = Hook.BuildTalkPool(afkSpeak, HERO_ID, 9902, Hook.MAP_TALK_PERCENT + 1)
Check(#atBound == 8 and #overBound == 21, "40% 边界：<=40 命中，41 回退")

print("== ③ 配置完整性 ==")
local byType, ids = {}, {}
for _, row in ConfigPairs(afkSpeak) do
    byType[row.Type] = (byType[row.Type] or 0) + 1
    if row.Type >= 9901 and row.Type <= 9908 then
        ids[#ids + 1] = tonumber(row.AfkDialogue) or row.AfkDialogue
    end
end
for _, t in ipairs({ 9901, 9902, 9905, 9907, 9908 }) do
    Check(byType[t] == 8, string.format("Type %d 有 8 条（实际 %d）", t, byType[t] or 0))
end
Check(#ids == 40, string.format("场景台词共 40 条（实际 %d）", #ids))

local seen, dup = {}, 0
local missing = 0
for _, lid in ipairs(ids) do
    if seen[lid] then
        dup = dup + 1
    end
    seen[lid] = true
    local row = language[lid]
    if not (row and row.Chinese and row.English and row.Japanese
        and #row.Chinese > 0 and #row.English > 0 and #row.Japanese > 0) then
        missing = missing + 1
        print(string.format("     (缺翻译) %s", tostring(lid)))
    end
end
Check(dup == 0, "40 条语言 Id 不重复")
Check(missing == 0, "40 条中/英/日都有翻译")

print("")
if failed == 0 then
    print("全部通过")
    os.exit(0)
else
    print(string.format("%d 项失败", failed))
    os.exit(1)
end
