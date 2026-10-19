-- 国家旗帜选择面板：重复开关不叠格子 / 同时只允许一个选中
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_country_flag_select_popup.lua
--
-- 复现的线上问题：选完国家关闭面板，再次打开发现多个国家同时高亮。
-- 根因：面板 GameObject 被 UIManager.openedList 缓存复用（noDestory=false ⇒
-- ClosePanel 里 isDestroy 为 false，只 SetActive(false)），grid 下克隆出来的格子
-- 不销毁；而 BuildCells 用来防重入的 `#this.cells > 0` 对「国家码为键的 map」恒为 0，
-- 于是每次 OnShow 又克隆一整套叠在同一坐标，旧格子的 selected 高亮无人重置。

local ROOT = os.getenv("TS_ROOT") or "."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path

-- ================= 最小环境桩 =================
local logs = {}
Log = function(s) logs[#logs + 1] = tostring(s) end
LogRed, LogGreen, LogWarn, LogPink, LogError = Log, Log, Log, Log, Log
function GetLan() return 0 end
function GetLanguageStrByStr(zh) return zh end
function GetLanguageStrById(id) return tostring(id) end

local prefs = {}
PlayerPrefs = {
    GetString = function(k, d) local v = prefs[k]; if v == nil then return d end; return v end,
    SetString = function(k, v) prefs[k] = v end,
    GetInt = function(k, d) local v = prefs[k]; if v == nil then return d end; return v end,
    SetInt = function(k, v) prefs[k] = v end,
    Save = function() end,
}
PlayerManager = { uid = 10000004, name = "Tester", country = "" }

-- 真实 Inherit（Common/functions.lua）只做「父表当元表」，这里同名同义
function Inherit(tbParent)
    local tb = {}
    tbParent.__index = tbParent
    setmetatable(tb, { __index = tbParent })
    return tb
end

Vector2 = {}
function Vector2.New(x, y) return { x = x, y = y } end

-- ---- 伪 GameObject 树（够本面板用即可）----
local ALL_GO = {}
local goCount = 0

local function newGo(name)
    goCount = goCount + 1
    local go = {
        name = name,
        active = true,
        children = {},
        components = {},
        __destroyed = false,
        __pending = false,
    }
    ALL_GO[#ALL_GO + 1] = go

    go.SetActive = function(self, v) self.active = v and true or false end
    go.GetComponent = function(self, cls)
        local c = self.components[cls]
        if not c then
            c = {}
            self.components[cls] = c
        end
        return c
    end

    local tr
    tr = setmetatable({ go = go }, {
        __index = function(_, k)
            if k == "childCount" then
                return #go.children
            elseif k == "GetChild" then
                return function(_, i) return go.children[i + 1].transform end
            elseif k == "SetParent" then
                return function(_, parent, worldPositionStays)
                    local pt = parent.go or parent
                    for i = #pt.children, 1, -1 do
                        if pt.children[i] == go then table.remove(pt.children, i) end
                    end
                    pt.children[#pt.children + 1] = go
                end
            elseif k == "gameObject" then
                return go
            end
        end,
    })
    go.transform = tr
    return go
end

-- GameObject.Destroy：与 Unity 一致，延迟到「帧末」生效（flush 模拟）
GameObject = {
    Destroy = function(target)
        local go = target.go or target
        if go and not go.__destroyed then go.__pending = true end
    end,
}

function IsNull(v)
    if v == nil then return true end
    if type(v) == "table" and v.__destroyed then return true end
    return false
end

local function flush()
    for _, go in ipairs(ALL_GO) do
        if go.__pending and not go.__destroyed then
            go.__pending = false
            go.__destroyed = true
            for _, pgo in ipairs(ALL_GO) do
                for i = #pgo.children, 1, -1 do
                    if pgo.children[i] == go then table.remove(pgo.children, i) end
                end
            end
        end
    end
end

function newObject(prefab)
    local function clone(src)
        local go = newGo(src.name)
        go.active = src.active
        for _, ch in ipairs(src.children) do
            local c = clone(ch)
            c.transform:SetParent(go.transform, false)
        end
        return go
    end
    return clone(prefab)
end

local function childByName(go, name)
    for _, ch in ipairs(go.children) do
        if ch.name == name then return ch end
    end
    return nil
end

local function getByPath(root, path)
    local cur = root.go or root
    for part in string.gmatch(path, "[^/]+") do
        cur = childByName(cur, part)
        if cur == nil then return nil end
    end
    return cur
end

Util = {
    GetGameObject = function(root, path)
        if root == nil then return nil end
        return getByPath(root, path)
    end,
    AddClick = function(go, fn) if go then go.__click = fn end end,
    LoadSprite = function(name) return { name = name } end,
}

-- ================= 载入被测模块 =================
assert(loadfile(LUA_SRC .. "/Modules/CountryRank/CountryConfig.lua"))()
assert(loadfile(LUA_SRC .. "/Modules/CountryRank/CountryRankManager.lua"))()
package.loaded["Modules/CountryRank/CountryConfig"] = true
package.loaded["Modules/CountryRank/CountryRankManager"] = true

CountryFlagUtil = { RefreshSelfFlags = function() end }
package.loaded["Modules/CountryRank/CountryFlagUtil"] = true

-- ---- 搭 prefab 层级（与 CountryFlagSelectPopup.prefab 同名即可）----
local function buildPrefabTree()
    local root = newGo("CountryFlagSelectPopup")
    local mask = newGo("mask");        mask.transform:SetParent(root.transform, false)
    local board = newGo("board");      board.transform:SetParent(root.transform, false)
    local title = newGo("title");      title.transform:SetParent(board.transform, false)
    local tip = newGo("tip");          tip.transform:SetParent(board.transform, false)
    local btnClose = newGo("btnClose"); btnClose.transform:SetParent(board.transform, false)
    local scroll = newGo("scroll");    scroll.transform:SetParent(board.transform, false)
    local viewport = newGo("viewport"); viewport.transform:SetParent(scroll.transform, false)
    local grid = newGo("grid");        grid.transform:SetParent(viewport.transform, false)
    local cellPre = newGo("cellPre");  cellPre.transform:SetParent(grid.transform, false)
    cellPre:SetActive(false)
    for _, n in ipairs({ "flag", "nameText", "selected" }) do
        local c = newGo(n); c.transform:SetParent(cellPre.transform, false)
        c:SetActive(n ~= "selected")
    end
    local current = newGo("current");  current.transform:SetParent(board.transform, false)
    for _, n in ipairs({ "flag", "nameText" }) do
        local c = newGo(n); c.transform:SetParent(current.transform, false)
    end
    return root
end

assert(loadfile(LUA_SRC .. "/Modules/CountryRank/CountryFlagSelectPopup.lua"))()

local PRE_ROOT = buildPrefabTree()

local panel = CountryFlagSelectPopup
local TOTAL = #CountryConfig.List

local function cells()
    local grid = Util.GetGameObject(panel.gameObject, "board/scroll/viewport/grid")
    local list = {}
    for _, ch in ipairs(grid.children) do
        if string.sub(ch.name, 1, 5) == "cell_" then list[#list + 1] = ch end
    end
    return list
end

local function selectedCells()
    local out = {}
    for _, ch in ipairs(cells()) do
        local sel = childByName(ch, "selected")
        if sel and sel.active then out[#out + 1] = ch.name end
    end
    return out
end

local pass, fail = 0, 0
local function check(desc, cond, extra)
    if cond then
        pass = pass + 1
        print(string.format("  ✅ %s", desc))
    else
        fail = fail + 1
        print(string.format("  ❌ %s%s", desc, extra and (" → " .. tostring(extra)) or ""))
    end
end

-- ================= 用例 =================
print("\n[1] 首次打开：格子数 = 国家数，且只有一个选中")
do
    panel.uiConfig = nil -- 让 BasePanel.ClosePanel 走空实现（真机由 UIManager 接管）
    -- 等价于 BasePanel.CreateUI 里那两句
    panel.gameObject = PRE_ROOT
    panel.transform = PRE_ROOT.transform
    panel:InitComponent()
    panel:BindEvent()
    panel:OnOpen(nil)
    panel:OnShow()
    flush()
    check("格子数 = " .. TOTAL, #cells() == TOTAL, #cells())
    check("grid 子节点 = 格子数 + cellPre", #Util.GetGameObject(panel.gameObject, "board/scroll/viewport/grid").children == TOTAL + 1)
    local sel = selectedCells()
    check("只有一个国家高亮", #sel == 1, table.concat(sel, ","))
end

print("\n[2] 选日本 → 关闭 → 再打开：不叠格子，仍只有一个高亮")
do
    local cellJp = nil
    for _, ch in ipairs(cells()) do if ch.name == "cell_jp" then cellJp = ch end end
    check("找到 cell_jp", cellJp ~= nil)
    cellJp.__click()
    panel:OnClose()  -- 真机由 UIManager.ClosePanel → CloseUI → OnClose
    flush()
    check("选中值已落到 jp", panel._selected == "jp", panel._selected)

    panel:OnOpen(nil)
    panel:OnShow()
    flush()
    check("格子数仍是 " .. TOTAL, #cells() == TOTAL, #cells())
    local sel = selectedCells()
    check("只有一个国家高亮", #sel == 1, table.concat(sel, ","))
    check("高亮的是 jp", sel[1] == "cell_jp", sel[1])
    check("当前展示旗子同步", panel.curFlag.sprite.name == "cn2-guoqi_jp", panel.curFlag.sprite.name)
end

print("\n[3] 连续开合三次（每次换一个国家）：格子不增长、高亮唯一")
do
    local seq = { "us", "de", "cn" }
    for _, code in ipairs(seq) do
        local cell = nil
        for _, ch in ipairs(cells()) do if ch.name == "cell_" .. code then cell = ch end end
        cell.__click()
        panel:OnClose()
        flush()
        panel:OnOpen(nil)
        panel:OnShow()
        flush()
    end
    check("格子数仍是 " .. TOTAL, #cells() == TOTAL, #cells())
    local sel = selectedCells()
    check("只有一个国家高亮", #sel == 1, table.concat(sel, ","))
    check("高亮的是最后选的 cn", sel[1] == "cell_cn", sel[1])
    -- 名字唯一性（防重名叠层）
    local seen, dup = {}, nil
    for _, ch in ipairs(cells()) do
        if seen[ch.name] then dup = ch.name end
        seen[ch.name] = true
    end
    check("没有重名格子", dup == nil, dup)
end

print(string.format("\n结果：%d 通过 / %d 失败\n", pass, fail))
if fail > 0 then os.exit(1) end
