-- 千抽面板（ThousandDrawPanel）卡片 / 数字格 duang —— 离线验证，不依赖 Unity：
--   ① 数据源          三张卡（card1..3）+ 剩余抽数四位（千/百/十/个），按版面顺序
--   ② 整版 duang      卡片先弹（0.5 → 1 + OutElastic），数字靠 cfg.delay 排在后面
--   ③ 单卡 duang      PlayCardDuang(n) 只弹抽中的那一张，其余不动
--   ④ 生命周期        StopDuang / OnClose / OnDestroy 都 Kill + 复位（漏了 = 卡永久停在 0.5）
--   ⑤ 接线            数据到位（Init 回调）才整版 duang；抽中一张只弹那一格
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_thousanddraw_duang.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/ThousandDraw/ThousandDrawPanel.lua"
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
Vector3 = { one = v3(1, 1, 1), zero = v3(0, 0, 0), New = v3 }
Vector2 = { New = function(x, y) return { x = x, y = y } end }
Ease = { Linear = "Linear", InOutQuad = "InOutQuad", OutQuad = "OutQuad", OutElastic = "OutElastic" }
IsNull = function(o) return o == nil end
local errors = {}
LogError = function(msg) errors[#errors + 1] = msg end
PlaySoundWithoutClick = function() end
SoundConfig = { Sound_UICancel = 1 }
GetPictureFont = function(name) return name end
ConfigName = { ThousandDrawConfig = "ThousandDrawConfig" }
ConfigManager = { GetAllConfigsData = function() return {} end }
Inherit = function() return {} end
local popInModule

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
    local n = { name = name, children = {}, activeSelf = true, localScale = v3(1, 1, 1) }
    n.gameObject = n
    n.transform = n
    function n:GetComponent()
        return { localPosition = v3(0, 0, 0), text = "" }
    end
    function n:DOScale(v, dur) return newTween(self, v, dur) end
    return n
end

local function child(parent, name)
    local n = node(name)
    parent.children[name] = n
    return n
end

local root = node("ThousandDrawPanel")
child(root, "mask")
child(root, "btnBack")
local bg = child(root, "bg")
child(bg, "btnHelp")
child(bg, "limit")
local number = child(bg, "number")
child(number, "title")
local numberGrid = child(number, "grid")
local numberNames = { "thousand", "hundred", "ten", "unit" }
for _, n in ipairs(numberNames) do child(numberGrid, n) end
local cardGrid = child(bg, "grid")
local cardNames = { "card1", "card2", "card3" }
local cardNodes = {}
for _, n in ipairs(cardNames) do cardNodes[n] = child(cardGrid, n) end

-- 按 "a/b/c" 走树（和 Util.GetGameObject 的路径语义一致）
local function walk(start, path)
    local cur = start
    for seg in path:gmatch("[^/]+") do
        cur = cur and cur.children and cur.children[seg] or nil
    end
    return cur
end
Util = { GetGameObject = function(parent, path) return walk(parent, path) end }

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

-- ---------------- case 1: 数据源 ----------------
print("== case1 数据源（卡 + 数字）==")
Panel.gameObject = root
Panel:InitComponent()
local cards = Panel:GetCardDuangItems()
Check(#cards == 3, "三张卡都应收集到，实际 " .. #cards)
Check(cards[1] == cardNodes["card1"] and cards[3] == cardNodes["card3"], "数组顺序 = card1..card3")
local digits = Panel:GetNumberDuangItems()
Check(#digits == 4, "四位数字都应收集到，实际 " .. #digits)
Check(digits[1] == numberGrid.children["thousand"] and digits[4] == numberGrid.children["unit"],
    "数字顺序 = 千/百/十/个")

-- ---------------- case 2: 整版 duang ----------------
print("== case2 整版 duang ==")
tweens = {}
Panel:PlayDuang()
Check(#tweens == 7, "3 张卡 + 4 位数字 = 7 条 tween，实际 " .. #tweens)
local cardTween = tweens[1]
Check(cardTween.tf == cardNodes["card1"], "第一条是 card1")
Check(cardTween.ease == Ease.OutElastic, "卡片用 OutElastic（自带回弹过冲）")
Check(Near(cardTween.endv.x, 1), "卡片弹回 1")
Check(Near(cardNodes["card1"].localScale.x, 0.5), "卡片起点 0.5，实际 " .. cardNodes["card1"].localScale.x)
Check(Near(tweens[2].delay, 0.09) and Near(tweens[3].delay, 0.18), "卡片错开 0.09")
local firstDigit = tweens[4]
Check(Near(firstDigit.delay, 0.26), "数字整批排在 0.26 之后，实际 " .. firstDigit.delay)
Check(Near(tweens[7].delay, 0.26 + 3 * 0.05), "末位数字 0.26+0.15，实际 " .. tweens[7].delay)
Check(Near(numberGrid.children["thousand"].localScale.x, 0.6), "数字起点 0.6")
print("  卡片 0/0.09/0.18 起，数字 0.26 起 0.05 错开")

-- ---------------- case 3: 单卡 duang ----------------
print("== case3 只弹抽中的那张 ==")
tweens = {}
Panel:PlayCardDuang(2)
Check(#tweens == 1, "只建 1 条 tween，实际 " .. #tweens)
Check(tweens[1].tf == cardNodes["card2"], "弹的是 card2")
Check(Near(cardNodes["card1"].localScale.x, 1) and Near(cardNodes["card3"].localScale.x, 1), "其余两张不动")
Check(Near(tweens[1].delay, 0), "单卡没有错开延迟")
-- 抽完落回 1
tweens[1]:Complete()
Check(Near(cardNodes["card2"].localScale.x, 1), "弹完落回 1")

-- ---------------- case 4: 回收 ----------------
print("== case4 回收 ==")
tweens = {}
Panel:PlayDuang()
Panel:StopDuang()
local live = 0
for _, t in ipairs(tweens) do if not t.killed then live = live + 1 end end
Check(live == 0, "StopDuang 后没有存活 tween，实际 " .. live)
Check(Near(cardNodes["card1"].localScale.x, 1) and Near(numberGrid.children["unit"].localScale.x, 1),
    "全部复位到 1（不会停在 0.5/0.6）")

-- ---------------- case 5: 接线（源码断言）----------------
print("== case5 接线 ==")
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

local initBody = bodyOf("function this.Init(msg)")
Check(initBody ~= nil, "找到 Init")
local setInfo, play = nil, nil
local idx = 0
for line in (initBody or ""):gmatch("[^\n]+") do
    idx = idx + 1
    if line:find("this.SetInfo()", 1, true) then setInfo = idx end
    if line:find("this:PlayDuang()", 1, true) then play = idx end
end
Check(setInfo and play and play > setInfo, "整版 duang 排在 SetInfo 之后（数据到位才弹）")

local close = bodyOf("function this:OnClose()")
Check(close ~= nil and close:find("StopDuang", 1, true) ~= nil, "OnClose 里回收")
local destroy = bodyOf("function this:OnDestroy()")
Check(destroy ~= nil and destroy:find("StopDuang", 1, true) ~= nil, "OnDestroy 里回收")

local ok = src:find("this.SetCard(Util.GetGameObject(this.cardGrid, \"card\" .. msg.number), msg)", 1, true)
local single = src:find("this:PlayCardDuang(msg.number)", 1, true)
Check(ok ~= nil and single ~= nil and single > ok, "抽中一张：SetCard 之后只弹那一格")

print(failed == 0 and "ALL OK" or ("FAILED: " .. failed))
if failed > 0 then os.exit(1) end
