-- 闪击战（BlitzStrikePanel）未开宝箱入场 —— 离线验证，不依赖 Unity：
--   ① 数据源       只收「还显示关闭态箱体」的宝箱（没达到的 + 达到没领的），已领的排除，
--                  顺序 = 路径顺序（Box1..5），缩放目标是 Bg/box（箱体图那层，不是 Box 根）
--   ② 手感         0.45 → 1，OutElastic 单段（duang），单箱 0.55s，相邻错开 0.08
--   ③ 生命周期     OnClose / OnDestroy 都 Kill + 复位（漏了 = 宝箱永久停在 0.45）
--   ④ 播的时机     只在 OnShow（玩家打开）播；UpdateMain（领奖后刷新）不播；
--                  没进难度（difficultyLevel = 0）走选难度弹窗那支，不播
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_blitzstrike_boxpopin.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/BlitzStrike/BlitzStrikePanel.lua"
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
    return math.abs(a - b) < 1e-6
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
Vector3 = { one = v3(1, 1, 1), zero = v3(0, 0, 0) }
Vector2 = { New = function(x, y) return { x = x, y = y } end }
Ease = { OutElastic = "OutElastic" }
IsNull = function(o) return o == nil end
local errors = {}
LogError = function(msg) errors[#errors + 1] = msg end
PlaySoundWithoutClick = function() end
SoundConfig = { Sound_INTERFACE_Button_Entergame = 1 }
ConfigName = { ItemConfig = "ItemConfig" }
ConfigManager = { GetConfig = function() return {} end }
Inherit = function() return {} end
UIName = { BlitzStrikeDifficultSelectPopup = "BlitzStrikeDifficultSelectPopup" }
HELP_TYPE = { BlitzStrikeDifficultSelect = 1 }
SHOP_TYPE = { BLITZ_STRIKE = 1 }
UpViewOpenType = { ShowRight = 1 }
PanelType = { BlitzStrikePanel = 1 }
local popInModule
local openedPanels = {}
UIManager = {
    OpenPanel = function(name)
        openedPanels[#openedPanels + 1] = name
    end,
}

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
        name = name,
        children = {},
        activeSelf = true,
        localScale = v3(1, 1, 1),
        rect = { width = 300, height = 120 },
    }
    n.gameObject = n
    n.transform = n
    n.comps = {}
    function n:GetComponent(kind)
        if not self.comps[kind] then
            self.comps[kind] = { localPosition = v3(0, 0, 0), text = "", sprite = "" }
        end
        return self.comps[kind]
    end
    function n:DOScale(v, dur) return newTween(self, v, dur) end
    function n:SetActive(v) self.activeSelf = v and true or false end
    return n
end

local function child(parent, name)
    local n = node(name)
    parent.children[name] = n
    return n
end

-- 按 "a/b/c" 走树（和 Util.GetGameObject 的路径语义一致）
local function walk(start, path)
    local cur = start
    for seg in path:gmatch("[^/]+") do
        cur = cur and cur.children and cur.children[seg] or nil
    end
    return cur
end

-- 按 "a/b/c" 建中间节点（已存在就复用）
local function mkdir(start, path)
    local cur = start
    for seg in path:gmatch("[^/]+") do
        cur = cur.children[seg] or child(cur, seg)
    end
    return cur
end

local root = node("BlitzStrikePanel")
child(root, "helpBtn")
child(mkdir(root, "Root/Bottom"), "backBtn")
local stageRoot = child(mkdir(root, "Root/Center"), "StageRoot")
local stageGo, boxGo, boxSkin = {}, {}, {}
for i = 1, 15 do
    local s = child(stageRoot, "Stage" .. i)
    local status = child(s, "Status")
    child(status, "Status1")
    child(status, "Status2")
    child(status, "Status3")
    child(s, "Click")
    stageGo[i] = s
end
for i = 1, 5 do
    local b = child(stageRoot, "Box" .. i)
    local bg = child(b, "Bg")
    local box = child(bg, "box")
    child(box, "O")
    child(box, "N")
    child(box, "box")
    boxGo[i] = b
    boxSkin[i] = box
end
local topRoot = mkdir(root, "Root/Top")
local titleMode = child(topRoot, "TitleMode")
for i = 1, 3 do child(titleMode, "Model" .. i) end
child(topRoot, "Btn_Shop")
child(topRoot, "Btn_Relive")
local todayGet = child(topRoot, "TodayGetReward")
child(todayGet, "Scroll")
child(todayGet, "RewardPre")

Util = {
    GetGameObject = function(parent, path) return walk(parent, path) end,
    LoadSprite = function(name) return name end,
    AddClick = function() end,
    AddOnceClick = function() end,
}
NetManager = {
    GetBlitzAllTankInfo = function(cb) if cb then cb() end end,
}
local scrollView = {
    moveTween = {},
    SetData = function(self, data, cb) self.data = data end,
    ForeachItemGO = function() end,
}
SubUIConfig = { PlayerHeadFrameView = "head", UpView = "up", ScrollCycleView = "scroll" }
SubUIManager = {
    Open = function(cfg)
        if cfg == SubUIConfig.ScrollCycleView then
            return scrollView
        end
        return { OnShow = function() end, OnOpen = function() end }
    end,
    Close = function() end,
}

-- ---------------- 关卡/宝箱配置 ----------------
-- 15 关，每 3 关一个宝箱 ⇒ BoxSignIdx = 第 3/6/9/12/15 关
local stageConfigs = {}
for i = 1, 15 do
    stageConfigs[i] = { Id = i, BoxAwards = (i % 3 == 0) and 1 or 0 }
end
BlitzStrikeManager = {
    StageNum = 15,
    BoxNum = 5,
    difficultyLevel = 1,
    curFightId = 10,                          -- 打到第 10 关：宝箱 3/6/9 已达标
    boxAwardedProgress = { [3] = true },      -- 宝箱 3 已领 ⇒ 唯一一个「已开」
    GetConfigDataByDiff = function() return stageConfigs end,
    GetRewardTotal = function() return {} end,
    RrefreshFormation = function() end,
}

-- ---------------- load ----------------
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
Panel:InitComponent()

local function resetAll()
    for i = 1, 5 do
        boxSkin[i].localScale = v3(1, 1, 1)
    end
end

-- ---------------- case 1: 还没数据时不播 ----------------
print("== case1 未开箱队列（空）时 Play 是 no-op ==")
tweens = {}
Check(Panel.boxPopIn ~= nil, "InitComponent 建了 boxPopIn")
Check(#Panel.unopenedBoxGo == 0, "InitComponent 后队列为空")
Check(Panel.boxPopIn:Play() == 0, "空队列 Play 返回 0")
Check(#tweens == 0, "没建任何 tween，实际 " .. #tweens)

-- ---------------- case 2: 采集未开宝箱 ----------------
print("== case2 采集（已领的排除、顺序 = 路径顺序）==")
Panel.UpdateMain()
local list = Panel.unopenedBoxGo
Check(#list == 4, "4 个未开（Box2/3/4/5，Box1 已领），实际 " .. #list)
Check(list[1] == boxSkin[2], "第 1 个是 Box2 的 Bg/box")
Check(list[2] == boxSkin[3] and list[3] == boxSkin[4] and list[4] == boxSkin[5], "顺序 = Box2→Box5")
local kept = true
for _, go in ipairs(list) do
    if go == boxSkin[1] then kept = false end
end
Check(kept, "已领的 Box1 不在队列里（它显示开箱图，不参与入场）")
Check(boxSkin[1].children["O"].activeSelf == true, "Box1 的已领角标 O 仍亮着（状态没被动画改掉）")
Check(boxSkin[2].children["N"].activeSelf == true, "Box2 可领角标 N 亮着")

-- ---------------- case 3: 手感 ----------------
print("== case3 从小到大的弹性（duang） ==")
resetAll()
tweens = {}
local n = Panel.boxPopIn:Play()
Check(n == 4, "4 个宝箱入队，实际 " .. n)
Check(#tweens == 4, "duang 单段 ⇒ 每箱 1 条 tween，共 4 条，实际 " .. #tweens)
local first = tweens[1]
Check(first.tf == boxSkin[2], "第一条是 Box2（队列顺序）")
Check(Near(first.endv.x, 1) and Near(first.dur, 0.55), "0.45 → 1 / 0.55s")
Check(first.ease == Ease.OutElastic, "OutElastic（弹性过冲自带，不设 peak）")
Check(Near(boxSkin[2].localScale.x, 0.45), "起点 0.45，实际 " .. boxSkin[2].localScale.x)
Check(Near(tweens[2].delay, 0.08) and Near(tweens[3].delay, 0.16) and Near(tweens[4].delay, 0.24),
    "相邻错开 0.08")
Check(Near(boxSkin[1].localScale.x, 1), "已领的 Box1 不动")
first:Complete()
Check(Near(boxSkin[2].localScale.x, 1), "落定回到 1（不留浮点残差）")

-- ---------------- case 4: 回收 ----------------
print("== case4 OnClose / OnDestroy 回收 ==")
resetAll()
tweens = {}
Panel.boxPopIn:Play()
Panel:OnClose()
local live = 0
for _, t in ipairs(tweens) do if not t.killed then live = live + 1 end end
Check(live == 0, "OnClose 后没有存活 tween，实际 " .. live)
local back = 0
for i = 2, 5 do if Near(boxSkin[i].localScale.x, 1) then back = back + 1 end end
Check(back == 4, "4 个宝箱都复位到 1（不会停在 0.45），实际 " .. back)

resetAll()
tweens = {}
Panel.boxPopIn:Play()
Panel:OnDestroy()
local live2 = 0
for _, t in ipairs(tweens) do if not t.killed then live2 = live2 + 1 end end
Check(live2 == 0, "OnDestroy 后没有存活 tween，实际 " .. live2)

-- ---------------- case 5: 播的时机 ----------------
print("== case5 打开播、刷新不播 ==")
resetAll()
tweens = {}
Panel:OnShow()
Check(#tweens == 4, "打开面板（OnShow）就弹 4 个，实际 " .. #tweens)

resetAll()
tweens = {}
Panel.UpdateMain()                     -- 领奖后走的是这条
Check(#tweens == 0, "UpdateMain（领奖/数据刷新）不重播，实际 " .. #tweens)

resetAll()
tweens = {}
BlitzStrikeManager.difficultyLevel = 0  -- 还没选难度：弹选难度面板，没有宝箱状态
openedPanels = {}
Panel:OnShow()
Check(openedPanels[1] == UIName.BlitzStrikeDifficultSelectPopup, "difficultyLevel = 0 时弹选难度面板")
Check(#tweens == 0, "这一支不播宝箱入场，实际 " .. #tweens)
BlitzStrikeManager.difficultyLevel = 1

Check(#errors == 0, "没有 LogError（异常兜底没被触发）" .. (#errors > 0 and ("：" .. errors[1]) or ""))

-- ---------------- case 6: 接线（源码断言）----------------
print("== case6 接线 ==")
local f = assert(io.open(SRC, "rb"))
local src = (f:read("*a")):gsub("\r\n", "\n")
f:close()

local function bodyOf(header)
    local i = src:find(header, 1, true)
    if not i then return nil end
    local rest = src:sub(i + #header)
    local j = rest:find("\nfunction ", 1, true) or #rest
    return rest:sub(1, j)
end

local show = bodyOf("function BlitzStrikePanel:OnShow()")
Check(show ~= nil, "找到 OnShow")
local updateIdx, playIdx = nil, nil
local idx = 0
for line in (show or ""):gmatch("[^\n]+") do
    idx = idx + 1
    if line:find("this.UpdateMain()", 1, true) then updateIdx = idx end
    if line:find("this.boxPopIn:Play()", 1, true) then playIdx = idx end
end
Check(updateIdx and playIdx and playIdx > updateIdx, "入场排在 UpdateMain 之后（队列已建好）")

local main = bodyOf("function BlitzStrikePanel.UpdateMain()")
Check(main ~= nil and main:find("boxPopIn:Play", 1, true) == nil, "UpdateMain 里没有 Play（数据刷新不重播）")

local close = bodyOf("function BlitzStrikePanel:OnClose()")
Check(close ~= nil and close:find("boxPopIn:Stop()", 1, true) ~= nil, "OnClose 里回收")
local destroy = bodyOf("function BlitzStrikePanel:OnDestroy()")
Check(destroy ~= nil and destroy:find("boxPopIn:Stop()", 1, true) ~= nil, "OnDestroy 里回收")

local plays = 0
for _ in src:gmatch("boxPopIn:Play%(%)") do plays = plays + 1 end
Check(plays == 1, "Play 全文件只有 1 处调用，实际 " .. plays)
Check(src:find('mode = "duang"', 1, true) ~= nil, "走 duang（单段弹性）")
Check(src:find("centerPivot = false", 1, true) ~= nil, "缩放原点保持箱体自身中心（不改 pivot）")

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
