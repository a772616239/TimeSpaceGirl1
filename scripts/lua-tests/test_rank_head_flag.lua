-- 排行榜「前三名国家小旗」回归测试（不依赖 Unity，直接用 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_rank_head_flag.lua
--
-- 覆盖的是**旗子归属**这个容易回归的点：
--   · 战力类榜单：三名玩家三个国家 → 三面旗必须各就各位
--   · 英雄战力榜：换一批玩家后旗子必须跟着换（旧实现压根不写旗 ⇒ 保留上一屏的旧旗）
--   · 公会榜：没有玩家国籍概念 → 三面旗全部隐藏
--   · 名次不足 3 人 → 该位旗子隐藏（不能留着上一屏的）
--   · 竞技场：rankInfos 的元素是 ArenaEnemy，玩家在 personInfo 里

local ROOT = os.getenv("TS_ROOT") or "../../.."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ---- 最小环境桩 ----
Log = function() end
LogRed = Log
LogError = function(s) print("  [LogError] " .. tostring(s)) end
LogGreen = Log
LogWarn = Log
LogPink = Log

local prefs = {}
PlayerPrefs = {
    GetString = function(k, d) local v = prefs[k]; if v == nil then return d end; return v end,
    SetString = function(k, v) prefs[k] = v end,
    GetInt = function(k, d) local v = prefs[k]; if v == nil then return d end; return v end,
    SetInt = function(k, v) prefs[k] = v end,
    Save = function() end,
}

PlayerManager = { uid = 123456, nickName = "我", country = "cn", head = 1, frame = 1, level = 88 }
Selection = { activeSelf = true }

RANK_TYPE = {
    FIGHT_LEVEL_RANK = 1, FORCE_RANK = 2, FORCE_CURR_RANK = 3, CLIMB_TOWER = 4,
    HERO_FORCE_RANK = 5, TRIAL_RANK = 6, MONSTER_RANK = 7, GOLD_EXPER = 8,
    GUILD_FORCE_RANK = 9, ARENA_RANK = 10, CELEBRATION_GUILD = 11,
    ALAMEIN_WAR = 12, FIGHT_ALIEN_RANK = 13,
}
FUNCTION_OPEN_TYPE = {
    ALLRANKING = 21, ARENA = 22, TRIAL = 23, MONSTER_COMING = 24, FIGHT_ALIEN = 25,
    CUSTOMSPASS = 26, GUILD = 27, EXPERT = 28, CLIMB_TOWER = 29, ALAMEIN_WAR = 30,
}
POOL_ITEM_TYPE = { PLAYER_HEAD = 1 }
SubUIConfig = { ItemView = 1, ScrollCycleView = 2 }
SoundConfig = { BGM_Rank = 1, Sound_UICancel = 1 }
SoundManager = { PlayMusic = function() end }
UIName = { PlayerInfoPopup = 1 }
UIManager = { OpenPanel = function() end }
GameEvent = { RankingList = {} }
Game = { GlobalEvent = { AddEvent = function() end, RemoveEvent = function() end, DispatchEvent = function() end } }
ConfigManager = { GetConfig = function() return {} end, GetConfigData = function() end }
G_AlameinLevel = {}
ActivityTypeDef = {}
RankingManager = {
    CurPage = 0,
    ClearData = function() end,
    InitData = function() end,
    GetTabTextData = function() return {} end,
}

Vector3 = setmetatable({}, { __call = function(_, a, b, c)
    return { x = a or 0, y = b or 0, z = c or 0 }
end })
Vector2 = Vector3
Vector3.New = function(a, b, c) return { x = a or 0, y = b or 0, z = c or 0 } end
Vector2.New = Vector3.New
local V3MT = { __mul = function(a, k)
    return { x = a.x * k, y = a.y * k, z = a.z * k }
end }
Vector3.one = setmetatable({ x = 1, y = 1, z = 1 }, V3MT)
Vector3.zero = { x = 0, y = 0, z = 0 }

GetLanguageStrById = function(id) return tostring(id) end
SetHeroStars = function() end
newObjToParent = function(a, b) return a end

-- ---- 假 GameObject ----
local function newGO(name)
    local go = { name = name, _children = {}, _comps = {}, active = true, activeSelf = true }
    go.gameObject = go
    go.transform = { parent = nil, parentGO = nil }
    function go:SetActive(v) self.active = v; self.activeSelf = v end
    function go.GetComponent(self, cls)
        -- 桩：任意组件都返回一个惰性占位（sprite / text / anchoredPosition 随便写）
        local c = self._comps[cls]
        if c == nil then
            c = { sprite = nil, text = "", anchoredPosition = nil, raycastTarget = false, enabled = true }
            self._comps[cls] = c
        end
        return c
    end
    function go:AddChild(child)
        child.transform.parent = self.transform
        child.transform.parentGO = self
        table.insert(self._children, child)
        return child
    end
    return go
end

local function newFlag(name)
    local go = newGO(name)
    go._comps["Image"] = { sprite = nil, raycastTarget = false }
    return go
end

local function newText(name)
    local go = newGO(name)
    go._comps["Text"] = { text = "" }
    return go
end

local function findDeep(go, name)
    if go.name == name then return go end
    for _, c in ipairs(go._children) do
        local r = findDeep(c, name)
        if r then return r end
    end
end

local sink = newGO("__sink")
InvalidObj = function() end
IsNull = function(o) return o == nil or o == false end

Util = {
    GetGameObject = function(root, name)
        if root == nil then return nil end
        local go = root.gameObject or root
        return findDeep(go, name) or sink
    end,
    LoadSprite = function(n) return n end,
    AddClick = function() end,
    AddOnceClick = function() end,
}

-- 头像节点桩：只要不报错即可
CommonPool = {
    CreateNode = function()
        local node = {}
        node.Reset = function() end
        node.SetHead = function() end
        node.SetFrame = function() end
        node.SetLevel = function() end
        node.SetParent = function() end
        node.SetPosition = function() end
        node.SetScale = function() end
        node.Recycle = function() end
        return node
    end,
}

SubUIManager = {
    Open = function()
        local holder = newGO("ItemView")
        holder._comps["RectTransform"] = { anchoredPosition = nil }
        return {
            gameObject = holder,
            OnOpen = function() end,
        }
    end,
    Close = function() end,
}

package.preload["Base/BasePanel"] = function()
    BasePanel = { ClosePanel = function() end }
end
Inherit = function(base)
    return setmetatable({}, { __index = base })
end

-- ---- 载入被测模块 ----
dofile(LUA_SRC .. "/Modules/CountryRank/CountryConfig.lua")
dofile(LUA_SRC .. "/Modules/CountryRank/CountryFlagUtil.lua")
dofile(LUA_SRC .. "/Modules/CountryRank/CountryRankManager.lua")
dofile(LUA_SRC .. "/Modules/Ranking/RankingSingleListPanel.lua")

local P = RankingSingleListPanel

-- 立绘区三件套 + 各自的旗
local flags = {}
local function buildHead(goName, key)
    local head = newGO(goName)
    head:AddChild(newGO("Head"))
    head:AddChild(newGO("HeroHead"))
    head:AddChild(newGO("click"))
    head:AddChild(newGO("livePrefab"))
    head:AddChild(newGO("infoGo"))
    head:AddChild(newText("nameText"))
    local flag = newFlag("countryFlag")
    head:AddChild(flag)
    flags[key] = flag
    return head
end

P.firsthead = buildHead("firstHead", 1)
P.secondhead = buildHead("secondHead", 2)
P.thirdhead = buildHead("thirdHead", 3)
P.firstHeadName = Util.GetGameObject(P.firsthead, "nameText")._comps["Text"]
P.secondHeadName = Util.GetGameObject(P.secondhead, "nameText")._comps["Text"]
P.thirdHeadName = Util.GetGameObject(P.thirdhead, "nameText")._comps["Text"]
P.name = newText("name")
P.TextTopEnd = newText("TextTopEnd")._comps["Text"]
P.myRank = newText("myRank")._comps["Text"]
P.myRankName = newText("myRankName")
P.MyRankHead = newGO("Head")
P.MyRankHeroHead = newGO("Head")
P.infoGo = newGO("infoGo")
P.playerHeadList = {}
P.playerHeroListHead = {}
P.lvPre = newGO("lvtext")
P.playerHeroListGo = {}

-- 「我的排名」行
local record = newGO("Record")
record:AddChild(newGO("infoGo"))
record:AddChild(newFlag("countryFlag"))
record:AddChild(newGO("Head"))
record:AddChild(newGO("HeroHead"))
record:AddChild(newText("nameText"))
P.record = record
P.myRecordFlag = Util.GetGameObject(record, "countryFlag")

local pass, fail = 0, 0
local function check(desc, cond, extra)
    if cond then
        pass = pass + 1
        print("  ✅ " .. desc)
    else
        fail = fail + 1
        print("  ❌ " .. desc .. (extra and ("  → " .. tostring(extra)) or ""))
    end
end

local function spriteOf(key)
    local img = flags[key]._comps["Image"]
    return img and img.sprite
end

local function openWith(rankType)
    P:OnOpen({ Id = 1, name = "榜单", rankType = rankType })
    P.SetInfoFuncList = P.SetInfoFuncList or {}
end

-- ============ 1. 战力类榜单 ============
print("\n[1] 战力榜：三名玩家 → 三面旗各就各位")
openWith(RANK_TYPE.FORCE_CURR_RANK)
P.SetHeadsInfo({ uid = 1001, country = "cn", head = 1, headFrame = 1 }, "r1", 1, "夜航星", 90)
P.SetHeadsInfo({ uid = 1002, country = "us", head = 1, headFrame = 1 }, "r2", 2, "赤羽", 89)
P.SetHeadsInfo({ uid = 1003, country = "jp", head = 1, headFrame = 1 }, "r3", 3, "白鲸", 88)
check("第一名 = cn", spriteOf(1) == "cn2-guoqi_cn", spriteOf(1))
check("第二名 = us", spriteOf(2) == "cn2-guoqi_us", spriteOf(2))
check("第三名 = jp", spriteOf(3) == "cn2-guoqi_jp", spriteOf(3))
check("三面旗都可见", flags[1].active and flags[2].active and flags[3].active)

-- ============ 2. 英雄战力榜（旧实现不写旗 → 保留旧旗）============
print("\n[2] 英雄榜：换一批玩家，旗子必须跟着换")
openWith(RANK_TYPE.HERO_FORCE_RANK)
P.SetHeadsHeroInfo({ uid = 2001, country = "kr", heroTemplateId = 1, heroLevel = 30, heroStar = 5, userName = "a" }, "h1", 1, "a", 30)
P.SetHeadsHeroInfo({ uid = 2002, country = "de", heroTemplateId = 1, heroLevel = 30, heroStar = 5, userName = "b" }, "h2", 2, "b", 30)
P.SetHeadsHeroInfo({ uid = 2003, country = "fr", heroTemplateId = 1, heroLevel = 30, heroStar = 5, userName = "c" }, "h3", 3, "c", 30)
check("第一名 = kr（不是上一次的 cn）", spriteOf(1) == "cn2-guoqi_kr", spriteOf(1))
check("第二名 = de（不是上一次的 us）", spriteOf(2) == "cn2-guoqi_de", spriteOf(2))
check("第三名 = fr（不是上一次的 jp）", spriteOf(3) == "cn2-guoqi_fr", spriteOf(3))

print("\n[3] 英雄榜「我的排名」行也要刷自己的旗")
P.SetHeroNotRollingInfo("战力", 7, { heroTemplateId = 1, heroLevel = 30, heroStar = 5, userName = "我" }, 20)
local myFlag = P.myRecordFlag
check("我的排名旗 = 自己的国家 cn",
    myFlag._comps["Image"].sprite == "cn2-guoqi_cn", myFlag._comps["Image"].sprite)
check("我的排名旗可见", myFlag.active ~= false)

-- ============ 4. 公会榜 ============
print("\n[4] 公会榜：没有玩家国籍 → 三面旗隐藏")
openWith(RANK_TYPE.GUILD_FORCE_RANK)
P.SetHeadsInfo({ uid = 3001, guildName = "公会A" }, "g1", 1, "公会A", 1)
P.SetHeadsInfo({ uid = 3002, guildName = "公会B" }, "g2", 2, "公会B", 1)
check("第一名旗隐藏", flags[1].active == false)
check("第二名旗隐藏", flags[2].active == false)

-- ============ 5. 名次不足 3 人 ============
print("\n[5] 榜单只有 2 人：第三名旗必须隐藏，不能留上一屏的")
openWith(RANK_TYPE.FORCE_CURR_RANK)
P.SetHeadsInfo({ uid = 4001, country = "cn", head = 1, headFrame = 1 }, "r1", 1, "甲", 90)
P.SetHeadsInfo({ uid = 4002, country = "us", head = 1, headFrame = 1 }, "r2", 2, "乙", 89)
P.SetHeadFlag(3, nil)
check("第三名旗隐藏（sprite 不清空也无所谓，父节点隐藏就看不见）", flags[3].active == false)

-- ============ 6. 竞技场包装对象 ============
print("\n[6] 竞技场：玩家在 personInfo 里，直接用 personInfo 画旗")
openWith(RANK_TYPE.ARENA_RANK)
local enemy3 = { personInfo = { uid = 5003, country = "es", head = 1, headFrame = 1, level = 70, name = "丙" } }
local info3 = enemy3.personInfo or enemy3
P.SetHeadsInfo(info3, "a3", 3, info3.name, info3.level)
check("第三名 = es（取 personInfo 而不是包装）", spriteOf(3) == "cn2-guoqi_es", spriteOf(3))
check("包装对象本身没有 country（proto 事实）", enemy3.country == nil and enemy3.uid == nil)

-- ============ 7. 空榜（NoneImage 显示）============
print("\n[7] 空榜：NoneImage 显示时「我的排名」旗必须跟着隐藏")
P.noneImage = newGO("NoneImage")
P.noneImage:SetActive(true)   -- 模拟空榜
P.SetHeroNotRollingInfo("战力", 0, { heroTemplateId = 1, heroLevel = 30, heroStar = 5, userName = "我" }, 0)
check("空榜时我的排名旗隐藏", myFlag.active == false)
P.noneImage:SetActive(false)  -- 数据恢复
P.SetHeroNotRollingInfo("战力", 7, { heroTemplateId = 1, heroLevel = 30, heroStar = 5, userName = "我" }, 20)
check("数据恢复后我的排名旗重新可见", myFlag.active ~= false)
check("恢复后旗 sprite = 自己的国家 cn",
    myFlag._comps["Image"].sprite == "cn2-guoqi_cn", myFlag._comps["Image"].sprite)
P.noneImage = nil  -- 还原桩，避免影响后续用例

print(string.format("\n结果：%d 通过，%d 失败", pass, fail))
os.exit(fail == 0 and 0 or 1)
