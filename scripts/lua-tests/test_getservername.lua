-- GetServerName 字节码行为测试（吃 LuaBytes 里的预编译字节码，与真机同路径）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   LUA_PATH="./?.lua;;" ./luajit <本文件> <Common_functions_64.bytes 绝对路径>

local bytes = assert(arg[1], "缺少参数：Common_functions_64.bytes 路径")

-- ---- 最小环境桩 ----
-- GetCurLanguage() 把结果缓存在 upvalue 里，所以「每换一种语言就重新 load 一次字节码」，
-- 用全新的 upvalue 跑，才能真实模拟不同语言的真机状态。
local redLogs = {}
LogRed = function(s) table.insert(redLogs, tostring(s)) end
Log = function() end
LogError = function() end
LogWarn = function() end
errorLog = Log
languageDicStr = {}      -- 由 Language.xlsx + AddManualTranslation 构建
languageDic = {}         -- 按 id 索引的字典
AppConst = { originLan = 1 }

local langId = 1
PlayerPrefs = {
    GetInt = function(key, default)
        if key == "multi_language" then return langId end
        return default
    end,
    SetInt = function() end,
    GetString = function(key, default) return default end,
    SetString = function() end,
    DeleteKey = function() end,
}

-- 语言 id 编码：10001 2 3 位代表语言 ⇒ floor(id/100)%100 即 lan（0=zh 1=en 2=jp 3=kr）
local LAN_ID = { zh = 1, en = 101, jp = 201, kr = 301 }

local function loadFor(langKey)
    langId = LAN_ID[langKey]
    assert(loadfile(bytes))()
    assert(type(GetServerName) == "function", "字节码里没有 GetServerName")
    assert(type(GetLanguageStrByStr) == "function", "既有函数 GetLanguageStrByStr 丢失了")
    -- 自证语言确实切过去了
    local lan = GetLan()
    return lan
end

local pass, fail = 0, 0
local function check(desc, langKey, info, expect, expectRedLog)
    local lan = loadFor(langKey)
    redLogs = {}
    local ok, got = pcall(GetServerName, info)
    local red = #redLogs > 0
    if not ok then
        fail = fail + 1
        print(string.format("  ❌ %-44s -> 抛错：%s", desc, tostring(got)))
        return
    end
    if got == expect and red == (expectRedLog or false) then
        pass = pass + 1
        print(string.format("  ✅ %-44s [lan=%d] -> %q", desc, lan, tostring(got)))
    else
        fail = fail + 1
        print(string.format("  ❌ %-44s [lan=%d] -> got=%s expect=%s (红字=%s 期望=%s)",
            desc, lan, tostring(got), tostring(expect), tostring(red), tostring(expectRedLog or false)))
    end
end

-- 模拟 LanguageManager.lua 末尾的 AddManualTranslation("庇护所九号", "Shelter No. 9")
languageDicStr["庇护所九号"] = { zh = "庇护所九号", en = "Shelter No. 9", jp = "庇护所九号", kr = "庇护所九号" }

print("== 1) 服务端下发分语言字段：命中即用，不走翻译表、不刷红字 ==")
check("en 命中 name_en", "en", { name = "庇护所九号", name_en = "Shelter No. 9" }, "Shelter No. 9")
check("jp 命中 name_jp", "jp", { name = "庇护所九号", name_jp = "シェルター9号" }, "シェルター9号")
check("kr 命中 name_kr", "kr", { name = "庇护所九号", name_kr = "쉘터 9호" }, "쉘터 9호")
check("zh 直接用中文原名（即使带 name_en）", "zh",
      { name = "庇护所九号", name_en = "Shelter No. 9" }, "庇护所九号")

print("== 2) 老区服没有分语言字段：回落既有翻译表 ==")
check("en 缺字段 -> 翻译表", "en", { name = "庇护所九号" }, "Shelter No. 9")
check("jp 缺字段 -> 翻译表命中(值即中文)，无红字", "jp", { name = "庇护所九号" }, "庇护所九号")

print("== 3) 边界：空串/异常类型按缺字段处理；未登记则红字并回落中文 ==")
check("en 字段为空串 -> 回落翻译表", "en", { name = "庇护所九号", name_en = "" }, "Shelter No. 9")
check("en 字段为数字 -> 回落翻译表", "en", { name = "庇护所九号", name_en = 123 }, "Shelter No. 9")
check("en 字段为 table -> 回落翻译表", "en", { name = "庇护所九号", name_en = {} }, "Shelter No. 9")
check("en 未登记 -> 红字 + 中文原名", "en", { name = "未翻译的服" }, "未翻译的服", true)
check("name 为空串", "en", { name = "" }, "")
check("serverInfo 为 nil", "en", nil, "")
check("serverInfo 没有 name 键", "en", {}, "")
check("en 字段为空白串 -> 照用（非空即可）", "en",
      { name = "X", name_en = "Y " }, "Y ")

print("== 4) 回归：既有函数未被破坏 ==")
loadFor("en")
assert(GetLanguageStrByStr("庇护所九号") == "Shelter No. 9", "GetLanguageStrByStr 行为被改坏")
assert(HasLanguageStrKey("庇护所九号") == true, "HasLanguageStrKey 行为被改坏")
assert(HasLanguageStrKey("不存在") == false, "HasLanguageStrKey 行为被改坏")
assert(GetLan() == 1, "GetLan 行为被改坏")
loadFor("zh")
assert(GetLan() == 0, "zh 下 GetLan 应为 0")
assert(GetLanguageStrByStr("庇护所九号") == "庇护所九号", "zh 下应返回中文")
print("  ✅ GetLanguageStrByStr / HasLanguageStrKey / GetLan 行为正常")
pass = pass + 6

print()
print(string.format("结果：%d 通过 / %d 失败", pass, fail))
os.exit(fail == 0 and 0 or 1)
