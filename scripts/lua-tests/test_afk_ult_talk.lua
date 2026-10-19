-- 挂机「大招前摇台词」回归测试（不依赖 Unity，直接 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_afk_ult_talk.lua
--
-- 背景：
--   挂机战斗原来只打普攻。现在每场开场前抽签，至多 1 个我方单位的第一招改成大招，
--   出手前在它的气泡位上冒一句「大招台词」——正好压在大招的前摇（KeyFrame 1.8~2.2s）里。
--   大招 = 该英雄 OpenSkillRules 里槽位最高、CombatControl.SkillType == 2 的技能
--   （挂机是演出，不卡 UnlockSkill 的突破门槛；见 FightPointMapOnHook.ResolveLoadout 注释）。
--
-- 覆盖：
--   ① PickUltSlot：只认已解锁 + 高槽位 + SkillType==2，普攻槽（0）不参与
--   ② MakeHookCombat：多段大招压到 3 段，其余字段仍回落到原配置
--   ③ ResolveLoadout：槽位 / 等级 / 技能 id / 掉落兜底（缺 SkillConfig 就放弃）
--   ④ BuildUltPool：英雄专属 70% / 通用 30% / 缺失回退
--   ⑤ PickOpenUltPos：55% 闸门边界 + 只返回候选位置
--   ⑥ 配置完整性：50 位英雄 × 2 条 + 8 条通用，中/英/日齐全，英雄 id 都存在

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
-- 1) 用游戏自己的解码器读配置
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
local heroConfig = LoadConfig("HeroConfig")

function ConfigPairs(t)
    local keys = SheetBase.GetKeys(t)
    if keys == nil then
        -- 纯 Lua 表（空池测试用）：按数组下标遍历
        local i = 0
        return function()
            i = i + 1
            local v = t[i]
            if v == nil then
                return nil
            end
            return i, v
        end
    end
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
    HeroConfig = "HeroConfig",
    SkillLogicConfig = "SkillLogicConfig",
    CombatControl = "CombatControl",
    SkillConfig = "SkillConfig",
}
ConfigManager = {
    GetConfig = function(name)
        if name == ConfigName.AfkSpeak then
            return afkSpeak
        end
        return {}
    end,
    GetConfigData = function() return nil end,
    GetConfigDataByDoubleKey = function() return nil end,
}
HeroManager = {
    GetSkillUnlockLv = function() return -1 end,
}

----------------------------------------------------------------------
-- 2) 加载被测模块（顶部会取 AfkSpeak，所以桩必须先就位）
----------------------------------------------------------------------
Vector2 = { New = function(x, y) return { x = x, y = y } end }
Vector3 = { New = function(x, y, z) return { x = x, y = y, z = z } end }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end, white = {} }
Time = { deltaTime = 0.033, realtimeSinceStartup = 0 }

local Hook = require("Modules/Fight/View/FightPointMapOnHook")

print("== ① PickUltSlot：槽位 / 解锁 / 技能类型 ==")
local rules = { { 0, 2040 }, { 1, 2041 }, { 3, 2043 } }
local unlocked = { [2041] = true, [2043] = true }
local displays = { [2041] = 2041, [2043] = 2043 }
local combats = {
    [2040] = { SkillType = 1, Id = 2040 },  -- 普攻
    [2041] = { SkillType = 2, Id = 2041 },
    [2043] = { SkillType = 2, Id = 2043 },
}
local slot, group, combat = Hook.PickUltSlot(rules, unlocked, displays, combats)
Check(slot == 3 and group == 2043 and combat.Id == 2043, "取槽位最高的 SkillType==2（3#2043）")

local slot2 = Hook.PickUltSlot(rules, { [2041] = true }, displays, combats)
Check(slot2 == 1, "高槽位未解锁时退回 1#2041")

local onlyNormal = { { 0, 2040 } }
Check(Hook.PickUltSlot(onlyNormal, { [2040] = true }, { [2040] = 2040 }, combats) == nil,
    "只有普攻槽 -> nil（普攻不算大招）")

local typeOne = { { 1, 2041 } }
Check(Hook.PickUltSlot(typeOne, { [2041] = true }, displays, { [2041] = { SkillType = 1 } }) == nil,
    "SkillType==1 不算大招")

Check(Hook.PickUltSlot(nil, {}, {}, {}) == nil, "rules 为 nil 不报错")

print("== ② MakeHookCombat：段数收敛 ==")
local longCombat = {
    Id = 9001, SkillType = 2, SkillNumber = 12,
    SkillDuration = { 150, 150, 150, 150, 150, 150, 150, 150, 150, 150, 300 },
    Bullet = "eff_x", Animation = "Skill_01",
}
local capped = Hook.MakeHookCombat(longCombat)
Check(capped.SkillNumber == Hook.ULT_HIT_CAP, "12 段压到 3 段")
Check(#capped.SkillDuration == Hook.ULT_HIT_CAP - 1, "SkillDuration 只剩 2 个间隔")
Check(capped.Id == 9001 and capped.Bullet == "eff_x" and capped.Animation == "Skill_01",
    "其它字段仍回落到原配置")
Check(capped.SkillDuration[1] == 150, "间隔沿用原配置")
local shortCombat = { SkillNumber = 1 }
Check(Hook.MakeHookCombat(shortCombat) == shortCombat, "本来就 <=3 段时原样返回（不复制）")

print("== ③ ResolveLoadout：配置拼装 ==")
local logicRows = {
    [2040] = { [1] = { Id = 20401, SkillDisplay = 2040, Group = 2040, Level = 1 } },
    [2041] = { [1] = { Id = 20411, SkillDisplay = 2041, Group = 2041, Level = 1 } },
    [2043] = { [1] = { Id = 20431, SkillDisplay = 2043, Group = 2043, Level = 1 } },
}
local skillCfg = {
    [20401] = { Id = 20401, Type = 1 },
    [20411] = { Id = 20411, Type = 2 },
    [20431] = { Id = 20431, Type = 2 },
}
ConfigManager.GetConfigDataByDoubleKey = function(_name, _k1, group, _k2, level)
    return logicRows[group] and logicRows[group][level]
end
ConfigManager.GetConfigData = function(name, id)
    if name == ConfigName.CombatControl then
        return combats[id]
    end
    if name == ConfigName.HeroConfig then
        return { Id = id, Star = 1, OpenSkillRules = rules }
    end
    return nil
end
ConfigManager.GetConfig = function(name)
    if name == ConfigName.SkillConfig then
        return skillCfg
    end
    if name == ConfigName.AfkSpeak then
        return afkSpeak
    end
    return {}
end
HeroManager.GetSkillUnlockLv = function(slotPos) return slotPos <= 3 and 1 or -1 end

local ult = Hook.ResolveLoadout({ Star = 1, OpenSkillRules = rules })
Check(ult ~= nil, "能解析出大招")
Check(ult and ult.slot == 3 and ult.group == 2043, "选中的是 3#2043")
Check(ult and ult.combat.Id == 2043 and ult.combat.SkillType == 2, "combat 指向 2043")
Check(ult and ult.skill.Id == 20431, "skill 指向 20431（受击判定用）")

-- 缺 SkillConfig：必须整招放弃，绝不能带着 nil skill 去 OnDamaged
local oldSkillCfg = skillCfg
skillCfg = {}
local noSkillUlt = Hook.ResolveLoadout({ Star = 1, OpenSkillRules = rules })
Check(noSkillUlt == nil, "缺 SkillConfig -> 放弃大招（不返回半成品）")
skillCfg = oldSkillCfg

-- 锁到只剩 1 槽也不影响：挂机是演出，大招固定取槽位最高的主动技能，
-- 不受 UnlockSkill（槽位 3 要 Rank>=3）限制，否则台词里的技能名全对不上
HeroManager.GetSkillUnlockLv = function(slotPos) return slotPos == 1 and 1 or -1 end
local slotOneUlt = Hook.ResolveLoadout({ Star = 1, OpenSkillRules = rules })
Check(slotOneUlt and slotOneUlt.slot == 3, "突破不足也取槽位 3（演出不卡养成）")
HeroManager.GetSkillUnlockLv = function(slotPos) return slotPos <= 3 and 1 or -1 end

print("== ④ BuildUltPool：专属 / 通用 ==")
local HERO_ID = 10005
local heroPool = Hook.BuildUltPool(afkSpeak, HERO_ID, 1)
Check(#heroPool == 2, string.format("10005 有 2 条专属大招台词（实际 %d）", #heroPool))
local heroText = {}
for _, lid in ipairs(heroPool) do
    local row = language[tonumber(lid) or lid]
    heroText[row and row.English or ""] = true
end
Check(heroText["World tour. You're stop one."] == true, "专属池里是德雷克自己的台词")

local genericPool = Hook.BuildUltPool(afkSpeak, HERO_ID, Hook.ULT_HERO_PERCENT + 1)
Check(#genericPool == 8, string.format("超过 70%% 走通用池 8 条（实际 %d）", #genericPool))
local genericText = {}
for _, lid in ipairs(genericPool) do
    local row = language[tonumber(lid) or lid]
    genericText[row and row.English or ""] = true
end
Check(genericText["World tour. You're stop one."] == nil, "通用池里不会混进英雄专属台词")
Check(genericText["Watch closely. One take only."] == true, "通用池内容是通用大招台词")

local unknownHero = Hook.BuildUltPool(afkSpeak, 99999, 1)
Check(#unknownHero == 8, "没配专属的英雄走通用池")

local noGeneric = Hook.BuildUltPool({}, HERO_ID, 1)
Check(#noGeneric == 0, "配置为空时返回空池（调用方不说话）")

print("== ⑤ PickOpenUltPos：55% 闸门 ==")
local candidates = { 2, 5, 7 }
Check(Hook.PickOpenUltPos({}, 1) == 0, "没有候选 -> 0")
Check(Hook.PickOpenUltPos(candidates, Hook.ULT_OPEN_PERCENT + 1) == 0, "roll 56 -> 这场没人放大招")
local hit = Hook.PickOpenUltPos(candidates, Hook.ULT_OPEN_PERCENT)
Check(hit == 2 or hit == 5 or hit == 7, "roll 55 命中且只返回候选位置")
local seen = {}
for r = 1, Hook.ULT_OPEN_PERCENT do
    local pos = Hook.PickOpenUltPos(candidates, r)
    seen[pos] = true
end
Check(seen[2] and seen[5] and seen[7], "1~55 能覆盖到全部候选位置（不会永远同一个人）")

print("== ⑥ 配置完整性 ==")
local byType, ultLids = {}, {}
local heroRows, genericRows = 0, 0
for _, row in ConfigPairs(afkSpeak) do
    byType[row.Type] = (byType[row.Type] or 0) + 1
    if row.Type == Hook.ULT_TALK_TYPE_GENERIC then
        genericRows = genericRows + 1
        ultLids[#ultLids + 1] = tonumber(row.AfkDialogue) or row.AfkDialogue
    elseif row.Type >= Hook.ULT_TALK_TYPE_BASE then
        heroRows = heroRows + 1
        ultLids[#ultLids + 1] = tonumber(row.AfkDialogue) or row.AfkDialogue
    end
end
Check(heroRows == 100, string.format("英雄专属大招台词 100 条（实际 %d）", heroRows))
Check(genericRows == 8, string.format("通用大招台词 8 条（实际 %d）", genericRows))

local heroWithUlt = 0
for _, row in ConfigPairs(afkSpeak) do
    if row.Type >= Hook.ULT_TALK_TYPE_BASE and row.Type ~= Hook.ULT_TALK_TYPE_GENERIC then
        local hid = row.Type - Hook.ULT_TALK_TYPE_BASE
        if heroConfig[hid] ~= nil then
            heroWithUlt = heroWithUlt + 1
        else
            print(string.format("     (英雄不存在) Type=%d", row.Type))
        end
    end
end
Check(heroWithUlt == 100, "100 条台词对应的英雄 id 都在 HeroConfig 里")

local seenLid, dup, missing = {}, 0, 0
for _, lid in ipairs(ultLids) do
    if seenLid[lid] then
        dup = dup + 1
    end
    seenLid[lid] = true
    local row = language[lid]
    if not (row and row.Chinese and row.English and row.Japanese
        and #row.Chinese > 0 and #row.English > 0 and #row.Japanese > 0) then
        missing = missing + 1
        print(string.format("     (缺翻译) %s", tostring(lid)))
    end
end
Check(#ultLids == 108, string.format("大招台词共 108 条（实际 %d）", #ultLids))
Check(dup == 0, "108 条语言 Id 不重复")
Check(missing == 0, "108 条中/英/日都有翻译")

-- 日文不能直接照抄中文（之前的坑：韩文表整列回落中文没人发现）
local sameZhJp = 0
for _, lid in ipairs(ultLids) do
    local row = language[lid]
    if row and row.Chinese == row.Japanese then
        sameZhJp = sameZhJp + 1
    end
end
Check(sameZhJp == 0, "日文不是中文原样照抄")

print("== ⑦ ShowTalk：同位置定时器互斥 / 收起 / 清场 ==")
-- 最小 UI 桩：只验证「文本写进去了、旧定时器先停、收尾能关气泡」
Timer = {
    New = function(fn, delay)
        local t = { fn = fn, delay = delay, stopped = false, started = false }
        function t:Start() self.started = true end
        function t:Stop() self.stopped = true end
        return t
    end,
}
local animPlayed = false
local textComp = {}
local textObj = {
    GetComponent = function() return textComp end,
}
local fakeNode = {
    active = false,
    SetActive = function(self, v) self.active = v end,
    GetComponent = function(self, name)
        if name == "Animation" then
            return {
                Play = function() animPlayed = true end,
                clip = { length = 0.2 },
            }
        end
        return nil
    end,
}
IsNull = function(o) return o == nil end
Util = {
    GetGameObject = function(node, name)
        if name == "Text" then return textObj end
        return nil
    end,
}
GetLanguageStrById = function(id) return "L" .. tostring(id) end
Hook.talkList = { [1] = fakeNode }
Hook.talkTimers = nil

Check(Hook:ShowTalk(1, 101, 2.5) == true, "ShowTalk 正常返回 true")
Check(fakeNode.active == true, "气泡被激活")
Check(textComp.text == "L101", "文案写入 Text")
local firstTimer = Hook.talkTimers[1]
Check(firstTimer ~= nil and firstTimer.started, "登记并启动了收起定时器")

Hook:ShowTalk(1, 102, 2.5)
Check(firstTimer.stopped == true, "同位置再冒泡时先停掉旧定时器")
Check(textComp.text == "L102", "文案被后一条覆盖")

-- 让定时器到点：先播收起动画，再生成隐藏定时器
Hook.talkTimers[1].fn()
Check(animPlayed == true, "到点播放收起动画")
local hideTimer = Hook.talkTimers[1]
Check(hideTimer ~= nil and hideTimer.started, "动画结束后登记隐藏定时器")
hideTimer.fn()
Check(fakeNode.active == false, "动画结束把气泡 SetActive(false)")

Hook:ShowTalk(1, 103, 2.5)
Hook:ClearTalkTimers()
Check(Hook.talkTimers[1] == nil, "ClearTalkTimers 清空登记")
Check(Hook:ShowTalk(1, nil, 2.5) == false, "langId 为 nil 不冒泡")
if failed == 0 then
    print("全部通过")
    os.exit(0)
else
    print(string.format("%d 项失败", failed))
    os.exit(1)
end
