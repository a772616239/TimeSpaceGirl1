-- 公告面板：迟到的 HTTP 回调撞上已销毁的 Text（线上 Fatal Exception 回归）
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=<repo> LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_notice_popup_destroyed_text.lua
--
-- 线上签名：
--   LuaException : attempt to index text on a nil value
--   [C]: in function '__newindex'
--   Modules/Login/NoticePopup: in function <Modules/Login/NoticePopup:0>
--   GameLogic.<HttpGet_Co>d__10:MoveNext
--
-- 根因：
--   UIConfig[177].noDestory == 0 ⇒ ClosePanel 会走 DelayDestroyPanel(15s*openNum)，
--   到点 UIManager.DestroyPanel ⇒ panel:DestroyUI() 再 GameObject.Destroy(panel.gameObject)。
--   lua 侧 this.ContentText 仍是「非 nil 但 C# 已销毁」的 userdata ⇒ 原来的
--   `if not this.ContentText then return end` 完全拦不住；赋值进入
--   UnityEngine_UI_TextWrap.set_text，NRE 被 catch 后统一抛
--   "attempt to index text on a nil value" ⇒ 抛穿 HttpGet_Co 协程 = Fatal Exception。
--
-- 本测试用 newproxy 造 tolua 风格 userdata（tolua.isnull 可控），覆盖：
--   存活写入 / 语言回落 / 纯文本 / 已销毁 / 已销毁+空响应 / 组件缺失 /
--   OnDestroy 清引用 / 过期回调 / 坏 JSON / 赋值抛 NRE。

local ROOT = os.getenv("TS_ROOT") or os.getenv("PWD")
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"
package.path = LUA_SRC .. "/?.lua;" .. package.path
-- 允许只替换被测文件（用来对修复前的版本跑同一套断言，验证测试本身能抓到 bug）
local NOTICE_SRC = os.getenv("TS_NOTICE_SRC") or (LUA_SRC .. "/Modules/Login/NoticePopup.lua")

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

-- ================= 最小环境桩 =================
Log = function() end
function GetLanguageStrById(id) return "L" .. tostring(id) end
local curLang = 10001
function GetCurLanguage() return curLang end

function Inherit(tbParent)
    local tb = {}
    tbParent.__index = tbParent
    setmetatable(tb, tbParent)
    return tb
end

BasePanel = { ClosePanel = function() end }
package.loaded["Base/BasePanel"] = BasePanel

VersionManager = { GetVersionInfo = function() return "http://127.0.0.1:9000/" end }
Time = { realtimeSinceStartup = 0 }
setmetatable(Time, { __index = function() return function() return 0 end end })
LoginManager = { sign = "sign" }
Util = { MD5Encrypt = function() return "md5" end, AddClick = function() end }

-- ---- tolua 风格 userdata（可控销毁态）----
local destroyed = setmetatable({}, { __mode = "k" })
local values = setmetatable({}, { __mode = "k" })
local function newText()
    local u = newproxy(true)
    values[u] = {}
    local mt = getmetatable(u)
    mt.__index = function(t, k) return values[t][k] end
    mt.__newindex = function(t, k, v)
        if destroyed[t] then
            -- 与 tolua 生成代码 set_text 的 catch 分支同款文案
            error("attempt to index " .. tostring(k) .. " on a nil value", 2)
        end
        if k == "text" and type(v) ~= "string" then
            error("attempt to index text on a nil value", 2)
        end
        values[t][k] = v
    end
    return u
end
tolua = { isnull = function(o) return type(o) == "userdata" and destroyed[o] == true end }
-- 与 Common/functions.lua:1561 同义
function IsNull(obj) return obj == nil or tolua.isnull(obj) end

-- ---- 伪面板节点 ----
local nodeText -- 当前面板的 Text userdata（nil = 预制体缺 Text 组件）
Util.GetGameObject = function(_, _, path)
    local go = { path = path }
    function go:GetComponent(comp)
        if comp == "Text" then return nodeText end
        return nil
    end
    return go
end

RequestPanel = { Hide = function() end }
Game = { GlobalEvent = { DispatchEvent = function() end } }
GameEvent = { NoticePanel = { OnOpen = "NoticePanel.OnOpen" } }

local pendingCb
networkMgr = { SendGetHttp = function(_, url, cb) pendingCb = cb end }

local decodeImpl = function(str) error("unexpected json: " .. tostring(str)) end
package.preload["cjson"] = function()
    return { decode = function(s) return decodeImpl(s) end }
end

-- ================= 每个场景一个全新面板实例 =================
local function fresh(withText)
    nodeText = withText and newText() or nil
    local panel = dofile(NOTICE_SRC)
    panel.uiConfig = { id = 177, name = "NoticePopup" }
    panel:InitComponent()
    pendingCb = nil
    return panel, nodeText
end

-- 1) 存活 + 多语言命中当前语言
local p1, t1 = fresh(true)
decodeImpl = function() return { parms = { title = "10001:中文公告|10101:English notice" } } end
p1:GetNotice()
check("存活：发出请求", type(pendingCb) == "function")
pendingCb('{"ok":1}')
check("存活：写入当前语言", values[t1].text == "中文公告", values[t1].text)

-- 2) 未命中语言的回退（日文 → 回落中文）
curLang = 10201
local p2, t2 = fresh(true)
decodeImpl = function() return { parms = { title = "10001:中文公告|10101:English notice" } } end
p2:GetNotice()
pendingCb('{"ok":1}')
check("未命中语言回落中文", values[t2].text == "中文公告", values[t2].text)
curLang = 10001

-- 3) 纯文本公告（后端没有 langId 前缀）
local p3, t3 = fresh(true)
decodeImpl = function() return { parms = { title = "服务器维护公告" } } end
p3:GetNotice()
pendingCb('{"ok":1}')
check("纯文本整段显示", values[t3].text == "服务器维护公告", values[t3].text)

-- 4) 面板已销毁（15s 后被 Destroy）→ 迟到回调必须静默返回
local p4, t4 = fresh(true)
decodeImpl = function() return { parms = { title = "迟到的公告" } } end
p4:GetNotice()
local cb4 = pendingCb
destroyed[t4] = true -- UIManager.DestroyPanel 之后
local ok4, err4 = pcall(cb4, '{"ok":1}')
check("已销毁：不抛错", ok4, err4)
check("已销毁：不写 UI", values[t4].text == nil, values[t4].text)
check("已销毁：丢弃死引用", p4.ContentText == nil)

-- 5) 已销毁后重开面板（同一实例复用缓存，不再发请求）
nodeText = newText()
p4:InitComponent()
p4:GetNotice()
check("重开：命中缓存不发请求", pendingCb == cb4)
check("重开：缓存内容秒显示", values[nodeText].text == "迟到的公告", values[nodeText].text)

-- 6) 已销毁 + 空响应（服务器无公告）
local p6, t6 = fresh(true)
p6:GetNotice()
local cb6 = pendingCb
destroyed[t6] = true
local ok6, err6 = pcall(cb6, "")
check("已销毁+空响应：不抛错", ok6, err6)
check("已销毁+空响应：不写 UI", values[t6].text == nil, values[t6].text)

-- 7) ContentText 为 nil（预制体缺 Text 组件）
local p7 = fresh(false)
decodeImpl = function() return { parms = { title = "x" } } end
p7:GetNotice()
local ok7, err7 = pcall(pendingCb, '{"ok":1}')
check("组件缺失：不抛错", ok7, err7)

-- 8) OnDestroy 清引用后再回调（DestroyUI → OnDestroy → GameObject.Destroy 真实顺序）
local p8, t8 = fresh(true)
p8:GetNotice()
local cb8 = pendingCb
p8:OnDestroy()
check("OnDestroy 断开引用", p8.ContentText == nil)
destroyed[t8] = true
local ok8, err8 = pcall(cb8, '{"ok":1}')
check("OnDestroy 后回调：不抛错", ok8, err8)

-- 9) 过期回调：连发两次请求，先返回的老响应不能覆盖新面板
local p9, t9 = fresh(true)
p9:GetNotice()
local oldCb = pendingCb
p9:GetNotice()
local newCb = pendingCb
check("连发两次请求：回调不是同一个", oldCb ~= newCb)
decodeImpl = function() return { parms = { title = "新公告" } } end
newCb('{"ok":1}')
check("新响应写入", values[t9].text == "新公告", values[t9].text)
decodeImpl = function() return { parms = { title = "老公告" } } end
oldCb('{"ok":1}')
check("老响应被丢弃", values[t9].text == "新公告", values[t9].text)

-- 10) 坏 JSON → 降级到「暂无消息」，不抛错
local p10, t10 = fresh(true)
p10:GetNotice()
decodeImpl = function() error("bad json") end
local ok10, err10 = pcall(pendingCb, "not a json")
check("坏 JSON：不抛错", ok10, err10)
check("坏 JSON：降级文案", values[t10].text == "L11130", values[t10].text)

-- 11) 赋值本身抛 NRE（Destroy 与回调同帧竞争）→ pcall 兜住并清引用
local p11, t11 = fresh(true)
p11:GetNotice()
decodeImpl = function() return { parms = { title = "x" } } end
local mt11 = getmetatable(t11)
local origSet = mt11.__newindex
mt11.__newindex = function() error("NullReferenceException", 0) end
local ok11, err11 = pcall(pendingCb, '{"ok":1}')
mt11.__newindex = origSet
check("赋值抛错：不冒泡", ok11, err11)
check("赋值抛错：清掉死引用", p11.ContentText == nil)

-- ================= 汇总 =================
print(string.format("\n%d passed, %d failed", pass, fail))
for _, f in ipairs(fails) do print("  x " .. f) end
os.exit(fail == 0 and 0 or 1)
