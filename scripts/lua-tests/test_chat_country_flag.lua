-- 聊天框「国家小旗」回归测试（不依赖 Unity，直接用 luajit 跑）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_chat_country_flag.lua
--
-- 覆盖的口径（用户 2026-10-20）：
--   · 没选国旗的玩家在**聊天框**里不画问号占位旗 → countryFlag 直接隐藏，名字归位
--   · 有真实国旗（服务端下发 / 自己本地已选）→ 正常显示，名字让开 52px
--   · 「选了其他地区（xx）」≠「没选」→ 仍然显示那面灰旗
--   · 系统消息 / 广播（senderId 为 0）→ 隐藏
--   · 面板开着时改旗 → 自己的旗从隐藏变显示，且名字跟着让位（不能压在旗上）
--   · 排行榜/玩家信息面板口径不变：CountryFlagUtil.Apply 仍然画 xx 占位（回归保护）

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

local MY_UID = 1001
PlayerManager = {
    uid = MY_UID, nickName = "我", country = "", head = 1, frame = 1, level = 88,
    familyId = 0, designation = 0, isShowVip = false,
}

Vector3 = setmetatable({}, { __call = function(_, a, b, c)
    return { x = a or 0, y = b or 0, z = c or 0 }
end })
Vector2 = Vector3
Vector3.New = function(a, b, c) return { x = a or 0, y = b or 0, z = c or 0 } end
Vector2.New = Vector3.New

GetLanguageStrById = function(id) return tostring(id) end
GetLanguageStrByStr = function(s) return s end
GetMailConfigDesc = function(msg) return msg end
TimeStampToDateStr = function(t) return tostring(t) end
GetPlayerHeadSprite = function(h) return "head_" .. tostring(h) end
GetPlayerHeadFrameSprite = function(f) return "frame_" .. tostring(f) end
newObject = function(go) return go end

CHAT_CHANNEL = { FRIEND = 1, FAMILY = 2, GLOBAL = 3, CrossRealm = 4, SYSTEM = 5 }
GLOBAL_CHAT_TYPE = { COMMON = 1, GUILD_INVITE = 2, GUILD_REDPACKET = 3, GUILD_AID = 4 }
GUILD_JOIN_TYPE = { NO_LIMIT = 1, LIMIT = 2, FORBID = 3 }
JobString = {}
RedPointType = { Chat_Friend = 1 }
Color = { New = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end }
UIName = { PlayerInfoPopup = 1, MainPanel = 2 }
UIManager = { OpenPanel = function() end }
VipManager = { GetVipLevel = function() return 0 end }
GoodFriendManager = { friendAllData = {} }
GuildManager = { RequestJoinGuild = function() end, RequestApplyManyGuilds = function() end }
JumpManager = { GoJump = function() end }
PopupTipPanel = { ShowTip = function() end }
MsgPanel = { ShowTwo = function() end }
ConfigName = { ItemConfig = "ItemConfig", ArtResourcesConfig = "ArtResourcesConfig" }
ConfigManager = {
    GetConfig = function() return {} end,
    GetConfigData = function() return nil end,
}
SoundManager = { PlayMusic = function() end }
SoundConfig = {}
SubUIConfig = { ItemView = 1, ScrollCycleView = 2 }
SubUIManager = { Open = function() return { OnOpen = function() end } end, Close = function() end }
Game = { GlobalEvent = { AddEvent = function() end, RemoveEvent = function() end, DispatchEvent = function() end } }
GameEvent = { CountryRank = { OnCountryChanged = "OnCountryChanged" } }
Selection = { activeSelf = true }

-- ---- 假 GameObject ----
local function newGO(name)
    local go = { name = name, _children = {}, _comps = {}, active = true, activeSelf = true }
    go.gameObject = go
    go.transform = { parent = nil, gameObject = go }
    function go:SetActive(v) self.active = v; self.activeSelf = v end
    function go:GetComponent(cls)
        local c = self._comps[cls]
        if c == nil then
            if cls == "RectTransform" then
                -- y 给个非零值：验证「只改 x，不动 y」
                c = { anchoredPosition = { x = 0, y = 7 }, gameObject = self }
            elseif cls == "Text" then
                c = { text = "", gameObject = self }
            elseif cls == "Image" then
                c = { sprite = nil, raycastTarget = false, gameObject = self }
            else
                c = { gameObject = self }
            end
            self._comps[cls] = c
        end
        return c
    end
    function go:AddChild(child)
        child.transform.parent = self.transform
        table.insert(self._children, child)
        return child
    end
    function go:FindChild(name)
        for _, c in ipairs(self._children) do
            if c.name == name then return c end
        end
    end
    return go
end

--- 按 "a/b/c" 建/取节点
local function ensurePath(root, path)
    local cur = root
    for seg in string.gmatch(path, "[^/]+") do
        local nxt = cur:FindChild(seg)
        if nxt == nil then nxt = cur:AddChild(newGO(seg)) end
        cur = nxt
    end
    return cur
end

local sink = newGO("__sink")
IsNull = function(o) return o == nil or o == false end

local function findDeep(go, path)
    local cur = go
    for seg in string.gmatch(path, "[^/]+") do
        cur = cur:FindChild(seg)
        if cur == nil then return nil end
    end
    return cur
end

Util = {
    GetGameObject = function(root, path)
        if root == nil then return nil end
        local go = root.gameObject or root
        return findDeep(go, path) or sink
    end,
    LoadSprite = function(n) return n end,
    AddClick = function() end,
    AddOnceClick = function() end,
}

-- TabBox / BasePanel 用桩替换，避免拉进一整个 UI 模块树
package.preload["Modules/Common/TabBox"] = function() return {} end
package.preload["Base/BasePanel"] = function()
    BasePanel = {
        ClosePanel = function() end,
        SetActive = function(self, go, v) if go ~= nil then go:SetActive(v) end end,
    }
    return BasePanel
end
Inherit = function(base) return setmetatable({}, { __index = base }) end

-- ChatManager：只需要 GetPlayerCountry（老消息兜底）和 AnalysisGlobalChat
ChatManager = {
    PlayerCountryCache = {},
    GetPlayerCountry = function(uid) return ChatManager.PlayerCountryCache[tonumber(uid)] end,
    AnalysisGlobalChat = function(msg) return { content = msg, type = GLOBAL_CHAT_TYPE.COMMON } end,
}

-- ---- 载入被测模块 ----
dofile(LUA_SRC .. "/Modules/CountryRank/CountryConfig.lua")
dofile(LUA_SRC .. "/Modules/CountryRank/CountryFlagUtil.lua")
dofile(LUA_SRC .. "/Modules/CountryRank/CountryRankManager.lua")
local ChatPanel = dofile(LUA_SRC .. "/Modules/Chat/ChatPanel.lua")

-- ---- 气泡节点树（结构与 prefab 一致）----
local BUBBLE_PATHS = {
    "time/Text",
    "contentroot/bg/content",
    "base/head",
    "base/headkuang",
    "base/vip",
    "contentroot/bg/info/name/name",
    "contentroot/bg/info/name/countryFlag",
    "contentroot/bg/info/pos",
    "contentroot/bg/info/pos/pos/Text",
    "contentroot/bg/info/title/title",
    "contentroot/bg/info/title",
}

local function newBubble()
    local root = newGO("ItemPre")
    local sides = {}
    for _, side in ipairs({ "leftchat", "rightchat" }) do
        local s = root:AddChild(newGO(side))
        for _, p in ipairs(BUBBLE_PATHS) do ensurePath(s, p) end
        sides[side] = s
    end
    return {
        root = root,
        left = sides.leftchat,
        right = sides.rightchat,
        -- side: "leftchat" / "rightchat"
        flag = function(side) return sides[side]:FindChild("contentroot"):FindChild("bg")
                :FindChild("info"):FindChild("name"):FindChild("countryFlag") end,
        nameRt = function(side) return sides[side]:FindChild("contentroot"):FindChild("bg")
                :FindChild("info"):FindChild("name"):FindChild("name"):GetComponent("RectTransform") end,
    }
end

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

local function spriteOf(go)
    local img = go:GetComponent("Image")
    return img and img.sprite
end

--- 跑一次 ChatPanel 的气泡适配
local function render(data)
    local b = newBubble()
    ChatPanel.ChatItemAdapter(b.root, data, false, false)
    return b
end

local function baseData(extra)
    local d = {
        senderId = 2002, senderName = "别人", senderlevel = 70, head = 3, frame = 2,
        sendervip = 0, showVip = false, chenghao = 0, msg = "hi", times = 0,
    }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

-- 每个用例前清掉本地国家选择（PlayerPrefs + PlayerManager），避免用例互相污染
local function resetMyCountry()
    prefs["player_country"] = nil
    prefs["device_country"] = nil
    PlayerManager.country = ""
end

-- ============ 1. 别人有国旗 → 正常显示 ============
print("\n[1] 别人有国旗（服务端下发 us）→ 显示 us，名字让开 52px")
resetMyCountry()
local b1 = render(baseData({ senderId = 2002, country = "us" }))
check("旗子可见", b1.flag("leftchat").active == true)
check("旗 = cn2-guoqi_us", spriteOf(b1.flag("leftchat")) == "cn2-guoqi_us", spriteOf(b1.flag("leftchat")))
check("名字 x = 1.1 + 52", b1.nameRt("leftchat").anchoredPosition.x == 53.1,
        b1.nameRt("leftchat").anchoredPosition.x)
check("名字 y 不动", b1.nameRt("leftchat").anchoredPosition.y == 7,
        b1.nameRt("leftchat").anchoredPosition.y)

-- ============ 2. 别人没选国旗 → 隐藏，不画问号 ============
print("\n[2] 别人没选国旗（country 空 + 无缓存）→ 隐藏 countryFlag，名字归位")
local b2 = render(baseData({ senderId = 2003, country = "" }))
check("旗子隐藏", b2.flag("leftchat").active == false)
check("没有画成问号旗 xx", spriteOf(b2.flag("leftchat")) ~= "cn2-guoqi_xx",
        spriteOf(b2.flag("leftchat")))
check("名字 x 归位 1.1", b2.nameRt("leftchat").anchoredPosition.x == 1.1,
        b2.nameRt("leftchat").anchoredPosition.x)

-- 连 country 字段都没有（老消息且缓存空）
local b2b = render(baseData({ senderId = 2004 }))
check("country 字段缺失 → 同样隐藏", b2b.flag("leftchat").active == false)

-- ============ 3. 自己没选过 → 隐藏（不能落到 GetPlayerCountry 的 xx 兜底）============
print("\n[3] 自己没选过国旗 → 隐藏（旧实现这里会画问号旗）")
resetMyCountry()
local b3 = render(baseData({ senderId = MY_UID, country = "" }))
check("自己的旗隐藏", b3.flag("rightchat").active == false)
check("没有画成问号旗 xx", spriteOf(b3.flag("rightchat")) ~= "cn2-guoqi_xx",
        spriteOf(b3.flag("rightchat")))
check("名字 x 归位 0", b3.nameRt("rightchat").anchoredPosition.x == 0,
        b3.nameRt("rightchat").anchoredPosition.x)

-- ============ 4. 自己选过 → 显示（右侧镜像，名字往左让）============
print("\n[4] 自己选过 kr → 显示 kr，名字 x = -52")
prefs["player_country"] = "kr"
PlayerManager.country = "kr"
local b4 = render(baseData({ senderId = MY_UID, country = "kr" }))
check("旗子可见", b4.flag("rightchat").active == true)
check("旗 = cn2-guoqi_kr", spriteOf(b4.flag("rightchat")) == "cn2-guoqi_kr", spriteOf(b4.flag("rightchat")))
check("名字 x = -52", b4.nameRt("rightchat").anchoredPosition.x == -52,
        b4.nameRt("rightchat").anchoredPosition.x)

-- ============ 5. 选了「其他地区」xx ≠ 没选 ============
print("\n[5] 自己选的是「其他地区」xx → 仍然显示（选了就不是没选）")
prefs["player_country"] = "xx"
PlayerManager.country = "xx"
local b5 = render(baseData({ senderId = MY_UID, country = "xx" }))
check("旗子可见", b5.flag("rightchat").active == true)
check("旗 = cn2-guoqi_xx", spriteOf(b5.flag("rightchat")) == "cn2-guoqi_xx", spriteOf(b5.flag("rightchat")))

-- ============ 6. 系统消息 / 广播 → 隐藏 ============
print("\n[6] 系统消息（senderId = 0）→ 隐藏")
resetMyCountry()
local b6 = render(baseData({ senderId = 0, country = "cn" }))
check("系统消息不画旗（即使 data.country 有值）", b6.flag("leftchat").active == false)
local b6b = render(baseData({ senderId = nil }))
check("senderId 缺失 → 隐藏", b6b.flag("leftchat").active == false)

-- ============ 7. 面板开着时改旗：隐藏 → 显示，名字要让位 ============
print("\n[7] 面板开着时改旗：隐藏的自己的旗要出现，且名字跟着让开")
resetMyCountry()
local b7 = render(baseData({ senderId = MY_UID }))
check("初始：旗隐藏", b7.flag("rightchat").active == false)
check("初始：名字 x = 0", b7.nameRt("rightchat").anchoredPosition.x == 0)
-- 玩家选了 us（走唯一收口 SetPlayerCountry，skipServer 避免拉网络）
CountryRankManager.SetPlayerCountry("us", true)
check("改旗后：旗出现", b7.flag("rightchat").active == true)
check("改旗后：旗 = us", spriteOf(b7.flag("rightchat")) == "cn2-guoqi_us", spriteOf(b7.flag("rightchat")))
check("改旗后：名字让开 -52（不能压在旗上）", b7.nameRt("rightchat").anchoredPosition.x == -52,
        b7.nameRt("rightchat").anchoredPosition.x)

-- ============ 8. 老消息兜底：data.country 空但 ChatManager 缓存有 ============
print("\n[8] 老消息没带 country，但同一 uid 别的消息带过 → 用缓存显示")
ChatManager.PlayerCountryCache[2005] = "de"
local b8 = render(baseData({ senderId = 2005, country = "" }))
check("旗子可见", b8.flag("leftchat").active == true)
check("旗 = cn2-guoqi_de", spriteOf(b8.flag("leftchat")) == "cn2-guoqi_de", spriteOf(b8.flag("leftchat")))

-- ============ 9. 回归保护：榜单口径不变（没数据仍画 xx 占位）============
print("\n[9] 回归：排行榜/玩家信息面板仍画 xx 占位（只有聊天框隐藏）")
local rankFlag = newGO("countryFlag")
CountryFlagUtil.Apply(rankFlag, 2006, nil)
check("榜单旗可见", rankFlag.active == true)
check("榜单旗 = xx 占位", spriteOf(rankFlag) == "cn2-guoqi_xx", spriteOf(rankFlag))

-- 自己的榜单旗（没选过）也仍是 xx 占位，不受聊天改动影响
resetMyCountry()
local myRankFlag = newGO("countryFlag")
CountryFlagUtil.ApplySelf(myRankFlag)
check("榜单里自己的旗仍可见", myRankFlag.active == true)
check("榜单里自己的旗 = xx 占位", spriteOf(myRankFlag) == "cn2-guoqi_xx", spriteOf(myRankFlag))

-- ============ 10. 三个聊天面板都走同一个入口 ============
print("\n[10] 三份聊天面板都接 CountryFlagUtil.ApplyToChat（不再各抄一遍）")
local function readFile(p)
    local f = io.open(p, "r")
    if f == nil then return "" end
    local s = f:read("*a")
    f:close()
    return s
end
local panels = {
    "/Modules/Chat/ChatPanel.lua",
    "/Modules/Chat/BattleChatPanel.lua",
    "/Modules/Fight/View/FightPointMapChatPanel.lua",
}
for _, p in ipairs(panels) do
    local src = readFile(LUA_SRC .. p)
    check(p .. " 调 ApplyToChat", string.find(src, "CountryFlagUtil.ApplyToChat", 1, true) ~= nil)
    check(p .. " 不再调 CountryFlagUtil.Apply(", string.find(src, "CountryFlagUtil.Apply(", 1, true) == nil)
end

print(string.format("\n结果：%d 通过，%d 失败", pass, fail))
os.exit(fail == 0 and 0 or 1)
