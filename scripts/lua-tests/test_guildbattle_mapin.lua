-- 公会战地图据点入场（GuildBattlePanel/challengePanel 下的 map/city1..10）—— 离线验证，不依赖 Unity：
--   ① 数据源       10 个据点（map/city1..10），顺序 = 离地图中心由近到远（7,4,3,6,8,5,9,10,1,2）
--   ② 起点/错开    首帧 0.65（baseScale 1.2 ⇒ 0.78），相邻错开 0.05、整批 0.45 内全起播
--   ③ 弹性关键帧   0.65 → 1.05（0.28s）→ 0.985（0.14s）→ 1（0.10s），落定吸附回 1.2
--   ④ 播的时机     RequestCityPopIn + OnShow 播；同屏刷新（再调 OnShow）不播；再置位再播
--   ⑤ 生命周期     OnClose / OnDestroy 都 Kill + 复位（漏了 = 据点永久停在 0.65）
--   ⑥ 接线与选型   父面板 OnOpen 置位、OnShow 在 ShowCity 之后播、phases + centerPivot=false、
--                  不许退回 duang / OutElastic（大块头会「闪一下」）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_guildbattle_mapin.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Guild/Battle/ChallengePanel.lua"
local PARENT_SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Guild/Battle/GuildBattlePanel.lua"
local POPIN = ROOT .. "Assets/ManagedResources/~Lua/Modules/Common/ItemPopIn.lua"

local failed = 0
local function Check(cond, msg)
    if cond then
        print("  ✅ " .. msg)
    else
        failed = failed + 1
        print("  ❌ " .. msg)
    end
end

local function Near(a, b)
    return a ~= nil and math.abs(a - b) < 1e-6
end

-- ---------------- stubs ----------------
local v3mt = {}
v3mt.__index = v3mt
v3mt.__mul = function(a, b)
    if type(a) == "number" then
        a, b = b, a
    end
    return setmetatable({ x = a.x * b, y = a.y * b, z = a.z * b }, v3mt)
end
local function v3(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, v3mt)
end
Vector3 = { one = v3(1, 1, 1), zero = v3(0, 0, 0), New = v3 }
Vector2 = {
    New = function(x, y)
        return { x = x, y = y }
    end,
}
Ease = {
    Linear = "Linear", InOutQuad = "InOutQuad", OutQuad = "OutQuad",
    OutCubic = "OutCubic", OutElastic = "OutElastic",
}
IsNull = function(o) return o == nil end
local errors = {}
LogError = function(msg) errors[#errors + 1] = msg end
GetLanguageStrById = function() return "" end
PrintWanNum3 = function(v) return tostring(v) end
TimeToDHMS = function(v) return tostring(v) end
GetTimeStamp = function() return 0 end
CheckRedPointStatus = function() end
ClearRedPointObject = function() end
BindRedPointObject = function() end
RedPointType = { GuildBattle_FreeTime = 1, GuildBattle_BoxReward = 2 }
UIColor = { WHITE = "white", GRAY = "gray" }
UIColorNew = { RED = "red" }
UITextFontStyle = { NORMAL = 1, BOLD = 2 }
newObjToParent = function(pre) return pre end
Timer = { New = function(fn) return { Start = function() end, Stop = function() end } end }
PopupTipPanel = { ShowTip = function() end, ShowTipByLanguageId = function() end }
UIManager = { OpenPanel = function() end, IsOpen = function() return false end }
UIName = { GuildChallengeInfoPanel = 1, ChatPanel = 2, GeneralPopup = 3, GuildBattleRankPanel = 4 }
GENERAL_POPUP_TYPE = { Buy = 1 }
HELP_TYPE = { GuildBattle = 1 }
BagManager = { GetItemCountById = function() return 0 end }

-- 快速建类：真 quick_class 会设 __index=cls，这里只要「类表当单例用」的语义
quick_class = function(classname, super)
    local cls = {}
    if super then
        setmetatable(cls, { __index = super })
    end
    cls.__cname = classname
    return cls
end

-- 配置表：公会战设置 / 据点配置 / 道具
local guildWarSettingCfg = { { Section = 5, PurchaseTime = 3, Price = { 10, 100 } } }
local guildWarConfigCfg = {}
for i = 1, 10 do
    guildWarConfigCfg[100 + i] = { Name = 50000 + i }
end
ConfigName = { GuildWarSetting = 1, GuildWarConfig = 2, ItemConfig = 3 }
ConfigManager = {
    GetConfig = function(name)
        if name == ConfigName.GuildWarSetting then return guildWarSettingCfg end
        if name == ConfigName.GuildWarConfig then return guildWarConfigCfg end
        return {}
    end,
}
Util = {
    AddClick = function(go, fn) end,
    LoadSprite = function(name) return name end,
    SetGray = function() end,
}
GuildBattleManager = {
    guildBattleState = 0,
    guildType = 0,
    guildBattleInfos = {},
    allHurtRank = {},
    serverInfo = {},
    buyCount = 0,
    challengeCount = 0,
    allowChallange = 1,
    startTime = 0,
    overTime = 0,
    GetTotalDamageRankRequest = function(cb) if cb then cb() end end,
}
for i = 1, 10 do
    GuildBattleManager.guildBattleInfos[i] = { pathId = 100 + i, guildName = "" }
end

-- ---------------- 假节点树 ----------------
local tweens = {}
local function newTween(tf, endv, dur)
    local t = { tf = tf, endv = endv, dur = dur, delay = 0, ease = nil, onComplete = nil, killed = false }
    function t:SetDelay(d) self.delay = d; return self end
    function t:SetEase(e) self.ease = e; return self end
    function t:OnComplete(cb) self.onComplete = cb; return self end
    function t:Kill() self.killed = true end
    function t:Complete()
        if self.killed then return end
        self.tf.localScale = self.endv
        if self.onComplete then self.onComplete() end
    end
    tweens[#tweens + 1] = t
    return t
end

local function node(name)
    local n = {
        name = name, children = {}, activeSelf = true,
        localScale = v3(1, 1, 1),
        rect = { width = 315, height = 257 },
        pivot = { x = 0.5, y = 0.5 },
        anchoredPosition = { x = 0, y = 0 },
        localPosition = v3(0, 0, 0),
        text = "", color = nil, fontStyle = nil,
    }
    n.gameObject = n
    n.transform = n
    local comps = {}
    function n:GetComponent(kind)
        if not comps[kind] then
            local c = {}
            -- 转发到节点本体：这样先建节点、后改 anchoredPosition 也读得到最新值
            setmetatable(c, { __index = function(_, k) return n[k] end })
            comps[kind] = c
        end
        return comps[kind]
    end
    function n:SetActive(v) self.activeSelf = v end
    function n:DOScale(v, dur) return newTween(self, v, dur) end
    return n
end

local root = node("challengePanel")
root.localScale = v3(1, 1, 1)
local function walk(start, path)
    local cur = start
    for seg in path:gmatch("[^/]+") do
        if not cur.children[seg] then
            cur.children[seg] = node(seg)
        end
        cur = cur.children[seg]
    end
    return cur
end
Util.GetGameObject = function(parent, path) return walk(parent, path) end

-- 据点坐标取自 GuildBattlePanel.prefab（map/city1..10 的 anchoredPosition）
local kCityPos = {
    { -285, 550 }, { 255, 605 }, { 10, 330 }, { -245, 180 }, { 345, 220 },
    { -350, -95 }, { 40, -165 }, { 375, -100 }, { -215, -355 }, { 250, -385 },
}
local cities = {}
for i = 1, 10 do
    local c = walk(root, "map/city" .. i)
    c.anchoredPosition = { x = kCityPos[i][1], y = kCityPos[i][2] }
    c.localScale = v3(1.2, 1.2, 1)     -- prefab 里据点的基准缩放是 1.2
    cities[i] = c
    walk(c, "cityName")
    walk(c, "guildName")
    walk(c, "btn")
end
walk(root, "time/time")
walk(root, "rank")
walk(root, "chanageTimes/chanageTimes")
walk(root, "chanageTimes/buyTimes")
walk(root, "chanageTimes/btnBuy")
walk(root, "btnHelp")
walk(root, "btnChange")
walk(root, "btnChat")
walk(root, "rank/btnRank")
walk(root, "crossService")
walk(root, "crossService/grid")
walk(root, "crossService/grid/pre")

local popInModule
function require(path)
    if path == "Modules/Common/ItemPopIn" then
        if not popInModule then
            popInModule = assert(loadfile(POPIN))()
        end
        return popInModule
    end
    return {}
end

local Panel = assert(loadfile(SRC))()
Panel.gameObject = root
Panel.transform = root
Panel:InitComponent(root)      -- 真实调用来自 GuildBattlePanel:InitComponent，会把子面板节点传进来
Panel:BindEvent()

-- ---------------- 小工具 ----------------
local BASE = 1.2
local function resetAll()
    for i = 1, 10 do
        cities[i].localScale = v3(BASE, BASE, 1)
    end
end
local function liveTweens()
    local n = 0
    for _, t in ipairs(tweens) do if not t.killed then n = n + 1 end end
    return n
end

-- ---------------- case 1: 数据源与顺序 ----------------
print("== case1 数据源（10 个据点，从地图中心往外）==")
Check(Panel.cityPopIn ~= nil, "InitComponent 建好了 cityPopIn")
local items = Panel.cityPopIn:_Collect()
Check(#items == 10, "收集到 10 个据点，实际 " .. #items)
local expectOrder = { 7, 4, 3, 6, 8, 5, 9, 10, 1, 2 }
local nameOk = true
for i = 1, #expectOrder do
    if items[i] ~= cities[expectOrder[i]] then
        nameOk = false
        print("     第 " .. i .. " 个是 " .. tostring(items[i] and items[i].name) ..
            "，期望 city" .. expectOrder[i])
    end
end
Check(nameOk, "顺序 = 由近到远：city7,4,3,6,8,5,9,10,1,2")

-- ---------------- case 2: 起点与错开 ----------------
print("== case2 起点 0.65 + 错开 0.05 ==")
resetAll()
tweens = {}
Panel:PlayCityPopIn()
Check(#tweens == 10, "10 个据点各建 1 条，实际 " .. #tweens)
Check(Near(cities[7].localScale.x, BASE * 0.65), "首帧缩到 0.65（1.2 → 0.78），实际 " .. cities[7].localScale.x)
Check(Near(tweens[1].endv.x, BASE * 1.05) and Near(tweens[1].dur, 0.28), "第一段 1.05 / 0.28s")
Check(tweens[1].ease == Ease.OutCubic, "第一段 OutCubic（冲出峰值）")
Check(Near(tweens[1].delay, 0) and Near(tweens[2].delay, 0.05) and Near(tweens[10].delay, 0.45),
    "错开 0.05，末项 0.45 起播")
Check(#errors == 0, "播放过程没有 LogError，实际 " .. #errors)

-- ---------------- case 3: 弹性关键帧链 ----------------
print("== case3 三段弹性关键帧 ==")
resetAll()
tweens = {}
Panel:PlayCityPopIn()
local chain = { { 1.05, 0.28, Ease.OutCubic }, { 0.985, 0.14, Ease.InOutQuad }, { 1, 0.10, Ease.OutQuad } }
local total, cursor = 0, 1
for i, expect in ipairs(chain) do
    local t = tweens[cursor]
    Check(Near(t.endv.x, BASE * expect[1]) and Near(t.dur, expect[2]),
        "第 " .. i .. " 段目标 " .. expect[1] .. " / " .. expect[2] .. "s")
    Check(t.ease == expect[3], "第 " .. i .. " 段 " .. tostring(expect[3]))
    total = total + t.dur
    t:Complete()
    cursor = #tweens
end
Check(Near(total, 0.52), "单据点总时长 0.52s，实际 " .. total)
Check(Near(cities[7].localScale.x, BASE), "落定吸附在 1.2（不留浮点残差），实际 " .. tostring(cities[7].localScale.x))

-- ---------------- case 4: 播的时机 ----------------
print("== case4 播的时机（打开播 / 同屏刷新不播）==")
resetAll()
tweens = {}
Panel:RequestCityPopIn()      -- GuildBattlePanel:OnOpen 干的事
Panel:OnShow()
Check(#tweens == 10, "打开面板那一轮播（10 条），实际 " .. #tweens)

-- 点「刷新」：回调里直接调 this:OnShow()，同屏数据刷新 ⇒ 不重播
Panel:StopCityPopIn()
resetAll()
tweens = {}
Panel:OnShow()
Check(#tweens == 0, "刷新 / 战斗返回的 OnShow 不重播，实际 " .. #tweens .. " 条")

-- 关掉再打开（父面板重新 OnOpen）⇒ 要播
Panel:StopCityPopIn()
resetAll()
tweens = {}
Panel:RequestCityPopIn()
Panel:OnShow()
Check(#tweens == 10, "重新打开面板重新播，实际 " .. #tweens)

-- ---------------- case 5: 回收 ----------------
print("== case5 回收（OnClose / OnDestroy）==")
Panel:StopCityPopIn()
resetAll()
tweens = {}
Panel:PlayCityPopIn()
Panel:OnClose()
Check(liveTweens() == 0, "OnClose 后没有存活 tween，实际 " .. liveTweens())
Check(Near(cities[7].localScale.x, BASE) and Near(cities[2].localScale.x, BASE), "关闭时复位到 1.2（不会停在 0.65）")

resetAll()
tweens = {}
Panel:PlayCityPopIn()
Panel:OnDestroy()
Check(liveTweens() == 0, "OnDestroy 后没有存活 tween，实际 " .. liveTweens())
Check(Near(cities[5].localScale.x, BASE), "销毁时复位到 1.2")

-- ---------------- case 6: 源码断言（接线 + 选型）----------------
print("== case6 接线与选型 ==")
local function readAll(path)
    local f = assert(io.open(path, "rb"))
    local s = (f:read("*a")):gsub("\r\n", "\n")
    f:close()
    return s
end
local src = readAll(SRC)
local parentSrc = readAll(PARENT_SRC)

local function bodyOf(text, header)
    local i = text:find(header, 1, true)
    if not i then return nil end
    local rest = text:sub(i + #header)
    local j = rest:find("\nfunction ", 1, true) or #rest
    return rest:sub(1, j)
end

local show = bodyOf(src, "function this:OnShow()")
Check(show ~= nil, "找到 ChallengePanel 的 OnShow")
local iCity = show and show:find("this.ShowCity()", 1, true)
local iPlay = show and show:find("this:PlayCityPopIn()", 1, true)
Check(iCity ~= nil and iPlay ~= nil and iPlay > iCity, "据点入场排在 ShowCity（贴图/文字已刷）之后")
Check(show ~= nil and show:find("playCityInOnShow", 1, true) ~= nil, "OnShow 消费 playCityInOnShow 一次性标记")

Check((bodyOf(src, "function this:OnClose()") or ""):find("StopCityPopIn", 1, true) ~= nil, "OnClose 里回收")
Check((bodyOf(src, "function this:OnDestroy()") or ""):find("StopCityPopIn", 1, true) ~= nil, "OnDestroy 里回收")
Check((bodyOf(parentSrc, "function this:OnOpen(index)") or ""):find("RequestCityPopIn", 1, true) ~= nil,
    "父面板 OnOpen 置位（战斗返回不含 OnOpen）")

Check(src:find('mode = "phases"', 1, true) ~= nil, "用 phases 关键帧")
Check(src:find('mode = "duang"', 1, true) == nil and src:find('ease = "OutElastic"', 1, true) == nil,
    "没有退回 duang / OutElastic（大块头会「闪一下」，见 skill 1.1）")
Check(src:find('from = 0.65', 1, true) ~= nil, "起点 0.65（从小到大）")
Check(src:find('centerPivot = false', 1, true) ~= nil, "centerPivot=false（据点图就在根节点 pivot 中心）")

local _, wiring = src:gsub("ItemPopIn%.New", "")
Check(wiring == 1, "只有一处 ItemPopIn.New（没有复制第二份实现），实际 " .. wiring)

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
