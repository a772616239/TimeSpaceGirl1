-- GetLanguageStrById 传入非数字文本 ⇒ 去重表用 nil 当键崩（真机 Fatal 回归）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=<repo> LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_lang_id_nil_key.lua
--
-- 线上签名：
--   LuaException: Common/functions:2111: table index is nil
--   Common/functions:2111: in function 'GetLanguageStrById'
--   Modules/Popup/RewardItemSingleShowPopup:182: in function 'OnShow'
--   Base/BasePanel:56 / Framework/Manager/UIManager:421 / View/ItemView:300
--
-- 根因（两个，缺一不崩）：
--   1) RewardItemSingleShowPopup:182 把 this.getType() 的返回值又喂回 GetLanguageStrById；
--      getType() 内部已经查过一次表，返回的是「已翻译文本」（如 "道具"/"Item"），
--      再进来 tonumber("道具") == nil ⇒ languageID = nil。
--   2) 5f5333f1f 给缺失 id 加去重表后，`_missingLangLogged[nil] = 1` ⇒ table index is nil。
--      改之前这行只 LogRed，非数字串不会崩，所以是这次去重引入的回归。
--
-- 本测试从 Common/functions.lua 里抽出真实函数体（不加载整个 functions.lua，依赖太多），
-- 覆盖：数字 id / 数字字符串 / 非数字文本 / 表入参 / 缺 id 去重 / 语言回落，
-- 并用同一套断言跑一遍「修复前实现」，确认测试本身抓得到这个 bug。

local ROOT = os.getenv("TS_ROOT") or os.getenv("PWD")
local SRC = ROOT .. "/Assets/ManagedResources/~Lua/Common/functions.lua"

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
local fh = assert(io.open(SRC, "rb"), "找不到 functions.lua: " .. SRC)
local text = fh:read("*a")
fh:close()

local s = text:find("local _missingLangLogged = {}", 1, true)
check("functions.lua 仍存在去重表声明", s ~= nil)
local e = s and text:find("local originLanguage", s, true)
check("能截到函数结尾（local originLanguage）", e ~= nil)
local chunk = s and e and text:sub(s, e - 1)
check("抽出的函数体非空", chunk ~= nil and #chunk > 200, chunk and #chunk)

-- ================= 沙箱环境 =================
local redLogs = {}
local langDic = {
    [3]     = { zh = "道具",   en = "Item",        jp = "アイテム", kr = "아이템" },
    [10210] = { zh = "分解",   en = "Resolve",     jp = "分解",     kr = "분해" },
    [5]     = { zh = "数量",   en = "",            jp = "",         kr = "" },     -- en 空 ⇒ 回落 zh
    [6]     = { zh = "",       en = "OnlyEn",      jp = "",         kr = "" },     -- zh 空 ⇒ 回落 en
}
local curLan = 0

local function makeEnv()
    local env = setmetatable({}, { __index = _G })
    env.languageDic = langDic
    env.LogRed = function(msg) redLogs[#redLogs + 1] = tostring(msg) end
    env.GetLan = function() return curLan end
    return env
end

local function loadFn(body)
    local factory, err = loadstring(body .. "\nreturn GetLanguageStrById")
    if not factory then error(err) end
    setfenv(factory, makeEnv())
    return factory()
end

-- 修复前的实现（5f5333f1f 版）：用于证明测试能抓到 bug
local OLD_BODY = [[
local _missingLangLogged = {}
function GetLanguageStrById(zhStr)
    if zhStr == nil then return zhStr end
    local t = type(zhStr)
    local languageID = 0
    if t == "string" then
        languageID = tonumber(zhStr)
    else
        languageID = zhStr
    end
    if languageDic then
        if languageDic[languageID] then
            local result = nil
            if GetLan() == 0 then result = languageDic[languageID].zh
            elseif GetLan() == 1 then result = languageDic[languageID].en end
            if result == nil or result == "" then result = languageDic[languageID].en end
            if result == nil or result == "" then result = languageDic[languageID].zh end
            return result or languageDic[languageID].zh
        else
            if not _missingLangLogged[languageID] then
                _missingLangLogged[languageID] = 1
                LogRed("在language表内未找到 id："..zhStr)
            end
            return tostring(zhStr)
        end
    end
    return zhStr
end
]]

-- ================= 1. 修复前实现必须崩（回归证明） =================
do
    local oldFn = loadFn(OLD_BODY)
    local ok, err = pcall(oldFn, "道具")
    check("修复前：非数字文本会抛 table index is nil", not ok and tostring(err):find("table index is nil") ~= nil, err)
end

-- ================= 2. 修复后实现 =================
local GetLanguageStrById = loadFn(chunk)

-- 2.1 数字 id 正常查表
check("数字 id 命中中文", GetLanguageStrById(3) == "道具", GetLanguageStrById(3))
check("数字字符串 id 命中中文", GetLanguageStrById("10210") == "分解", GetLanguageStrById("10210"))
curLan = 1
check("英文语言取 en", GetLanguageStrById(3) == "Item", GetLanguageStrById(3))
check("en 为空回落中文", GetLanguageStrById(5) == "数量", GetLanguageStrById(5))
check("zh 为空回落英文", GetLanguageStrById(6) == "OnlyEn", GetLanguageStrById(6))
curLan = 0

-- 2.2 非数字文本：原样返回，不崩、不刷红字（这是本次崩的那条路径）
redLogs = {}
local ok1, r1 = pcall(GetLanguageStrById, "道具")
check("非数字文本不崩", ok1, r1)
check("非数字文本原样返回", ok1 and r1 == "道具", r1)
local ok2, r2 = pcall(GetLanguageStrById, "Item")
check("英文文本原样返回", ok2 and r2 == "Item", r2)
local ok3, r3 = pcall(GetLanguageStrById, "")
check("空串不崩", ok3, r3)
check("非数字文本不写红字", #redLogs == 0, #redLogs)

-- 2.3 异常入参（表）兜成文本，不崩
local ok4, r4 = pcall(GetLanguageStrById, { a = 1 })
check("表入参不崩", ok4, r4)
check("表入参返回字符串", ok4 and type(r4) == "string", r4 and type(r4))

-- 2.4 nil 透传
check("nil 透传", GetLanguageStrById(nil) == nil)

-- 2.5 缺 id：仍报红字，但同一 id 只报一条（去重逻辑保留）
redLogs = {}
local r5 = GetLanguageStrById(999999)
check("缺 id 返回 tostring", r5 == "999999", r5)
check("缺 id 报一条红字", #redLogs == 1, #redLogs)
GetLanguageStrById(999999)
GetLanguageStrById("999999")
check("同 id 重复调用不重复刷", #redLogs == 1, #redLogs)
GetLanguageStrById(888888)
check("不同 id 各自报一条", #redLogs == 2, #redLogs)

-- ================= 3. 调用点：RewardItemSingleShowPopup 不再二次查表 =================
do
    local popupSrc = ROOT .. "/Assets/ManagedResources/~Lua/Modules/Popup/RewardItemSingleShowPopup.lua"
    local ph = io.open(popupSrc, "rb")
    if ph then
        local ptxt = ph:read("*a")
        ph:close()
        check("弹窗不再对 getType() 结果二次查表",
            ptxt:find("GetLanguageStrById(this.getType())", 1, true) == nil)
        check("getType 有 itemConfig 空保护",
            ptxt:find("local cfg = itemConfig[itemSid]", 1, true) ~= nil)
    else
        check("能读到 RewardItemSingleShowPopup.lua", false, popupSrc)
    end
end

-- ================= 结果 =================
print(string.format("pass=%d fail=%d", pass, fail))
if fail > 0 then
    for _, name in ipairs(fails) do print("  FAIL: " .. name) end
    os.exit(1)
end
print("✅ GetLanguageStrById nil-key 回归全部通过")
