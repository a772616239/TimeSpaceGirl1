-- 红点绑定生命周期：静态契约回归
--
-- 用法：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=<repo> LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_redpoint_binding_lifecycle.lua
--
-- 为什么用静态断言而不是跑逻辑：
--   这条契约（绑定必须写在「每次打开都会走」的函数里 + 先 Clear 再 Bind）跨了
--   BasePanel / UIManager / SubUIManager / TabBox 四个模块的时序，
--   用桩跑要模拟整套 UI 生命周期，成本远大于收益；而违反契约的写法在源码里
--   是可直接识别的特征。逻辑回归见 test_operating_growth_claim.lua。
--
-- 背景（详见 .workbuddy-ai/skills/redpoint-and-activityid-audit/）：
--   BasePanel 初次打开 Awake→InitComponent→BindEvent→AddListener→OnOpen→OnShow，
--   再次打开只走 AddListener→OnShow；CloseUI 只调 OnClose，面板对象留在 openedList。
--   ⇒ 「BindEvent 里绑 + OnClose 里清」= 第一次关闭后 BindObjs 被清空且永不补回，
--     红点值怎么变都刷不到 UI（OperatingPanel page_3 的原始 bug）。
--   ⇒ 子视图（contents 表驱动）的 InitComponent 由宿主只调一次，同理
--     （ArenaTypePanel_TopMatch 的原始 bug）。
--   ⇒ RedpotManager.BindObject 是 table.insert，不幂等，重复绑会堆 N 份。

local ROOT = os.getenv("TS_ROOT") or os.getenv("PWD")
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"

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

local function read(rel)
    local p = LUA_SRC .. "/" .. rel
    local f = assert(io.open(p, "rb"), "读不到文件：" .. p)
    local s = f:read("*a")
    f:close()
    return s
end

local function lines_of(s)
    local out = {}
    for line in (s .. "\n"):gmatch("([^\n]*)\n") do
        out[#out + 1] = line
    end
    return out
end

-- 和审计脚本同一套切块规则：用「下一个 function 定义」当块尾
local function split_functions(s)
    local blocks = {}
    local cur = nil
    for i, line in ipairs(lines_of(s)) do
        local name = line:match("^%s*local%s+function%s+([%w_%.:]+)%s*%(")
            or line:match("^%s*function%s+([%w_%.:]+)%s*%(")
        if name then
            if cur then cur.to = i - 1 end
            cur = { name = name:gsub("^.*[:.]", ""), from = i, to = #lines_of(s) }
            blocks[#blocks + 1] = cur
        end
    end
    return blocks
end

local function enclosing(blocks, ln)
    for _, b in ipairs(blocks) do
        if ln >= b.from and ln <= b.to then return b.name end
    end
    return "<module>"
end

local function find_calls(s, api)
    local out = {}
    for i, line in ipairs(lines_of(s)) do
        if line:find(api, 1, true) and not line:match("^%s*%-%-") then
            out[#out + 1] = i
        end
    end
    return out
end

-- 只跑一次的初始化函数：绑在这里 = 缓存复用后不再执行
local ONCE = { InitComponent = true, BindEvent = true, Awake = true, ctor = true, CreateUI = true }

-- 两种合法写法，按文件登记：
--   guard     = 批量绑 + 幂等守卫（self._redPointBound）+ 批量清（不传 obj）
--   clearbind = 逐行「先 Clear 再 Bind」，且禁止不传 obj 的清空
local PANELS = {
    { path = "Modules/Operating/OperatingPanel.lua", mode = "guard" },
    { path = "Modules/Arena/View/ArenaTypePanel_TopMatch.lua", mode = "clearbind" },
    { path = "Modules/ArenaTopMatch/ArenaTopMatchPanel.lua", mode = "clearbind" },
}

-- ============ 1. 面板：绑定不能落在一次性初始化函数里 ============
for _, p in ipairs(PANELS) do
    local rel = p.path
    local s = read(rel)
    local blocks = split_functions(s)
    local binds = find_calls(s, "BindRedPointObject")
    check(rel .. " 有红点绑定（用例本身有效性）", #binds > 0, #binds)
    for _, ln in ipairs(binds) do
        local fn = enclosing(blocks, ln)
        check(rel .. ":" .. ln .. " 绑定不在一次性初始化函数里", not ONCE[fn], fn)
    end
end

-- ============ 2. guard 模式：必须有幂等守卫，否则重复 OnShow 会重复 table.insert ============
for _, p in ipairs(PANELS) do
    if p.mode == "guard" then
        local s = read(p.path)
        check(p.path .. " 使用幂等守卫 _redPointBound", s:find("_redPointBound", 1, true) ~= nil)
        check(p.path .. " 守卫在 Clear 里被复位",
            s:find("_redPointBound%s*=%s*false") ~= nil)
    end
end

-- ============ 3. clearbind 模式：每处 Bind 前必须有同参数 Clear；禁止单参 Clear ============
for _, p in ipairs(PANELS) do
    if p.mode == "clearbind" then
        local rel = p.path
        local s = read(rel)
        local ls = lines_of(s)

        for _, ln in ipairs(find_calls(s, "BindRedPointObject")) do
            local line = ls[ln]
            local args = line:match("BindRedPointObject%s*%((.*)%)")
            check(rel .. ":" .. ln .. " Bind 带两个参数", args ~= nil and args:find(",") ~= nil, line)
            local ok = false
            for k = ln - 1, math.max(1, ln - 4), -1 do
                local prev = ls[k]
                if prev and prev:find("ClearRedPointObject", 1, true) then
                    local cargs = prev:match("ClearRedPointObject%s*%((.*)%)")
                    if cargs and args and cargs:gsub("%s", "") == args:gsub("%s", "") then
                        ok = true
                    end
                    break
                end
            end
            check(rel .. ":" .. ln .. " Bind 前有同参数的 Clear", ok, line)
        end

        for _, ln in ipairs(find_calls(s, "ClearRedPointObject")) do
            local line = ls[ln]
            local args = line:match("ClearRedPointObject%s*%((.-)%)%s*$")
                or line:match("ClearRedPointObject%s*%((.-)%)%s*%-%-")
            check(rel .. ":" .. ln .. " Clear 必须带 obj（否则清全局）",
                args ~= nil and args:find(",") ~= nil, line)
        end
    end
end

-- ============ 4. 成长礼金领奖：activityId 必须优先取行自带的档位 ============
do
    local s = read("Modules/Operating/GrowthGiftPage.lua")
    local blocks = split_functions(s)
    local body = {}
    for _, b in ipairs(blocks) do
        if b.name == "RefreshShowData" then
            local ls = lines_of(s)
            for i = b.from, b.to do body[#body + 1] = ls[i] end
        end
    end
    local text = table.concat(body, "\n")
    check("RefreshShowData 存在", #body > 0)
    check("RefreshShowData 用行自带的 ActivityId", text:find("data.ActivityId", 1, true) ~= nil)
    check("RefreshShowData 不再裸用 IsActivityTypeOpen 当档位",
        text:find("data.ActivityId%s*or") ~= nil)
    -- 领奖请求的第二个参数必须是 activityId 变量
    check("领奖请求带 activityId",
        s:find("GetActivityRewardRequest%s*%(%s*data.Id%s*,%s*activityId") ~= nil)
end

-- ============ 5. 运营面板 page_3 页签红点在 OnShow 里补绑 ============
do
    local s = read("Modules/Operating/OperatingPanel.lua")
    local blocks = split_functions(s)
    local bindInShow = false
    for _, ln in ipairs(find_calls(s, "BindRedPoint")) do
        local line = lines_of(s)[ln]
        if line:match("BindRedPoint%s*%(") or line:match("BindRedPoint%s*$") then
            if enclosing(blocks, ln) == "OnShow" then bindInShow = true end
        end
    end
    check("OperatingPanel 在 OnShow 里调 BindRedPoint", bindInShow)
end

-- ============ 汇总 ============
print(("结果：%d 通过，%d 失败"):format(pass, fail))
if fail > 0 then
    for _, f in ipairs(fails) do print("  ❌ " .. f) end
    os.exit(1)
end
print("  ✅ 红点绑定生命周期契约全部满足")
