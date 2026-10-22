-- 离线验证「特权礼包卡片说明文字」限行截断（不依赖 Unity）：
--   GiftView.lua 里 FitTipText 的三条红线
--     ① 不超过 kTipMaxLine 行（按 em 宽度估算，独立复算一遍，不复用被测实现）
--     ② 截断必须补「…」且只补一个，不能切坏 UTF-8（字符数只减不增）
--     ③ 本来就不超长的文案原样返回（中文 30~60 字不许被截）
--   顺带覆盖 \n、恰好 N 行、超 1 字、纯 ASCII 这几个边界。
--
-- 实现方式：直接从真源码里抽出「特权礼包卡片说明文字」到 ctor 之间那一段来跑，
-- 避免测试里复制一份实现（复制品会和线上漂移）。
--
-- 用法（与其他 lua-tests 一致）：
--   cd LuaEncoder/luajit_mac/64
--   TS_ROOT=../../.. LUA_PATH="./?.lua;;" ./luajit ../../../scripts/lua-tests/test_recharge_tip_fit.lua

local ROOT = (os.getenv("TS_ROOT") or ".") .. "/"
local SRC = ROOT .. "Assets/ManagedResources/~Lua/Modules/Recharge/View/GiftView.lua"

local f = assert(io.open(SRC, "rb"))
local src = f:read("*a")
f:close()
src = src:gsub("\r\n", "\n")

local function slice(from, to)
    local i = src:find(from, 1, true)
    local j = src:find(to, 1, true)
    assert(i and j and j > i, "GiftView.lua 结构变了，找不到切片标记：" .. from .. " / " .. to)
    return src:sub(i, j - 1)
end

local helper = slice("--============================== 特权礼包卡片说明文字",
    "function GiftView:ctor")

local loader = loadstring or load
local M = assert(loader(helper .. "\nreturn { FitTipText = FitTipText, kTipLineWidth = kTipLineWidth, " ..
    "kTipMaxLine = kTipMaxLine, kTipFontSize = kTipFontSize }\n"))()
local FitTipText = M.FitTipText

local fail = 0
local function ok(cond, fmt, ...)
    if not cond then
        fail = fail + 1
        print("  ❌ " .. string.format(fmt, ...))
    end
end

-- 独立复算行数（宽度模型与实现一致，但循环自己写，避免自证）
local function renderLines(s)
    local lines, w = 1, 0
    for ch in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do
        if ch == "\n" then
            lines, w = lines + 1, 0
        else
            local b = string.byte(ch, 1)
            local cw = (b and b < 128) and 0.5 or 1.0
            if w + cw > M.kTipLineWidth + 0.001 then
                lines, w = lines + 1, cw
            else
                w = w + cw
            end
        end
    end
    return lines
end

local function countChars(s)
    local n = 0
    for _ in string.gmatch(s, "[%z\1-\127\194-\244][\128-\191]*") do n = n + 1 end
    return n
end

-- 判据
local function verify(name, text, expect_truncate)
    local out = FitTipText(text)
    local truncated = (out ~= text)
    local lines = renderLines(out)
    ok(lines <= M.kTipMaxLine, "%s：截断后 %d 行 > 上限 %d", name, lines, M.kTipMaxLine)
    ok(countChars(out) <= countChars(text), "%s：输出字符数比原文多（切坏了 UTF-8）", name)
    if truncated then
        -- 注意用模式匹配而不是 sub(-1)：UTF-8 的「…」是 3 字节，sub(-1) 只取到最后 1 字节
        ok(out:match("…$") ~= nil, "%s：截断了但没补省略号", name)
        ok(not out:find("……", 1, true), "%s：出现双省略号", name)
        ok(countChars(out) < countChars(text), "%s：截断标记与实际长度不符", name)
    end
    if expect_truncate ~= nil then
        ok(truncated == expect_truncate, "%s：期望%s，实际%s",
            name, expect_truncate and "截断" or "原样", truncated and "截断" or "原样")
    end
    print(string.format("  %-28s %-6s %3d→%3d 字  %d 行", name,
        truncated and "截断" or "原文", countChars(text), countChars(out), lines))
end

print("[1] 线上真实 Desc（Ref 34010176 / 34010177 中日英原样）")
-- 中文：30~60 字必须原样保留（这是玩家看到的完整卖点）
verify("zh 会员招募卡", "获取强力英雄必购礼包！超值优惠，购买后每日额外获得1张会员招募卡（邮件发放），每周限购1次！", false)
verify("zh 快速训练特权", "快速升级必备特权，每日额外增加2次快速训练免费次数，和4次快速训练次数，有效期30天，同时再送十连抽！", false)
verify("zh 基因研究特权", "开启基因研究特权，可额外增加1个基因研究栏位，每周限购1次", false)
verify("zh 新人嘉奖礼包", "新人嘉奖礼包！超值十连招募，50级前可购买！", false)
-- 英文/日文同一条文案长度近 2 倍，必须截断（旧版靠 Text 硬切会切在半行）
verify("en 会员招募卡", "Get a must-buy gift pack for Powerful Heroes! Great value discount, you can get an additional membership recruitment card every day after purchase (email is issued), and you can purchase once a week!", true)
verify("jp 快速训练特权", "迅速なアップグレードには必須の特権であり、30日間有効な2つの無料クイックトレーニング時間と4つのクイックトレーニング時間を追加し、同時に10連ガチャもプレゼント！", true)

print("[2] 边界")
verify("空串", "", false)
verify("单字", "赐", false)
verify("恰好 1 行", string.rep("赐", math.floor(M.kTipLineWidth)), false)
verify("恰好上限行", string.rep("赐", math.floor(M.kTipLineWidth) * M.kTipMaxLine), false)
verify("超上限 1 字", string.rep("赐", math.floor(M.kTipLineWidth) * M.kTipMaxLine + 1), true)
verify("含显式换行", "第一行\n第二行\n第三行\n第四行", true)
verify("长 ASCII 无空格", string.rep("A", 400), true)

print("[3] 幂等：截断结果再喂一次必须原样返回")
local once = FitTipText("Get a must-buy gift pack for Powerful Heroes! Great value discount, you can get an additional membership recruitment card every day after purchase (email is issued), and you can purchase once a week!")
ok(FitTipText(once) == once, "幂等性：二次截断又变了")

if fail == 0 then
    print("\nALL PASS")
    os.exit(0)
else
    print("\nFAILED " .. fail)
    os.exit(1)
end
