-- RedPointType 枚举重号回归
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=<repo> LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_redpoint_ids.lua
--
-- 背景（2026-10-21）：
--   Lead_UpLv=99895 / Lead_SpeedLvUp=99894 与扭蛋的 BoxPoolCanDraw=99895 / BoxPool=99894 撞号。
--   99894 是扭蛋父节点 ⇒ 父节点不能注册检测函数（静默丢弃）⇒ 研发等级红点永远不刷新；
--   99895 的 SetParent 先执行 ⇒ BoxPoolCanDraw 挂不上扭蛋父节点，扭蛋状态直接写进神眷者入口位掩码。
--   表现就是「LogisticsMainPanel/page4 外面亮，点进去 LeadPanel 里没有红点」。
--   这里直接在源码层面守住：RedPointType 内不允许重复数值（历史遗留的 2027 例外白名单）。

local ROOT = os.getenv("TS_ROOT") or os.getenv("PWD")
local SRC = ROOT .. "/Assets/ManagedResources/~Lua/Common/GlobalDefine.lua"

local f = assert(io.open(SRC, "rb"))
local src = f:read("*a")
f:close()

-- 只取 RedPointType 表体
local body = src:match("RedPointType%s*=%s*{(.-)\n}")
assert(body and #body > 1000, "没找到 RedPointType 表，检查 GlobalDefine.lua")

-- 去掉行尾注释，避免读到被注释掉的老条目
body = body:gsub("%-%-[^\n]*", "")

local WHITELIST = {
    [2027] = "MunitionsMerchant / FuXingGaoZhao（历史遗留，不在本次范围）",
}

local seen, dups, count = {}, {}, 0
for name, val in body:gmatch("([A-Za-z_][%w_]*)%s*=%s*(%d+)") do
    count = count + 1
    local v = tonumber(val)
    if seen[v] then
        dups[#dups + 1] = string.format("%d -> %s / %s", v, seen[v], name)
    else
        seen[v] = name
    end
end

local bad = {}
for _, d in ipairs(dups) do
    local v = tonumber(d:match("^(%d+)"))
    if not WHITELIST[v] then bad[#bad + 1] = d end
end

print(string.format("扫描 RedPointType 条目 %d 个，重复值 %d 组，其中未白名单 %d 组", count, #dups, #bad))
for _, d in ipairs(bad) do print("  ❌ 重号: " .. d) end
for v, why in pairs(WHITELIST) do
    for _, d in ipairs(dups) do
        if tonumber(d:match("^(%d+)")) == v then print("  ⚠ 白名单内重号: " .. d .. "  (" .. why .. ")") end
    end
end

os.exit(#bad == 0 and 0 or 1)
