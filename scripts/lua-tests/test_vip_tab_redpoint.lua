-- VIP 页签红点口径回归测试（不依赖 Unity，直接 lua 跑）
--
-- 用法：
--   TS_ROOT=. lua scripts/lua-tests/test_vip_tab_redpoint.lua
--
-- 背景（2026-10-22 线上表现）：
--   UIRoot/.../MainRechargePanel/content/VipPanel/btnScrollBg/btnScroll/grid/VIP1|VIP2|VIP3/redPoint
--   三颗红点同时亮，点进去没有任何「领取」，只有价格 + 购买按钮。
--
-- 根因：
--   VipPanel:SetBtnRedState 用的是 VipManager.GetBtnListRed(level)，
--   语义是「这档礼包**还能买**且没点开看过」（PlayerPrefs 记一次，看过即灭），
--   是纯购买引导；而 StoreConfig 里 StoreId=20 的各档 Cost 全是钻石
--   （Sort1=240 / Sort2=800 / Sort3=3450 / Sort4=4950 …），一分钱免费的都没有
--   ⇒ 点亮时玩家永远找不到「领取」。
--
-- 修复口径：
--   页签红点只认 VipManager.HasFreeVipGift(level)：剩余次数够（-1 不限购）且实付为 0。
--   「可购买」语义保留在 GetBtnListRed 里（本测试第 8 项锁住两者不同），但不再驱动页签红点。
--
-- 覆盖：
--   ① 付费档位（800 / 3450）→ 不亮
--   ② 免费档位（0 元）→ 亮；未解锁 → 不亮
--   ③ 次数用尽 → 不亮；-1 不限购 → 亮
--   ④ 配置缺失（vipShopData 无该档）→ 不亮且不抛错（旧 GetBtnListRed 在这里会 data.Id 崩）
--   ⑤ 「可购买」与「可领」是两个口径：同一档 GetBtnListRed=true 而 HasFreeVipGift=false

local ROOT = os.getenv("TS_ROOT") or "."
local LUA_SRC = ROOT .. "/Assets/ManagedResources/~Lua"

local failed = 0
local function Check(cond, msg)
    if cond then
        print("  [PASS] " .. msg)
    else
        failed = failed + 1
        print("  [FAIL] " .. msg)
    end
end

----------------------------------------------------------------------
-- 1) 全局桩
----------------------------------------------------------------------
package.path = LUA_SRC .. "/?.lua;" .. package.path

ConfigName = { VipLevelConfig = "VipLevelConfig", StoreConfig = "StoreConfig" }
ConfigManager = {
    GetConfig = function(name) return {} end,
    GetConfigData = function(name, id) return nil end,
}

SHOP_TYPE = { VIP_GIFT = 20 }

PlayerManager = { uid = 10001, level = 1 }
PlayerPrefs = {
    GetInt = function(k, d) if d == nil then return 0 end return d end,
    SetInt = function(k, v) end,
}

-- ShopManager 桩：次数 / 价格都由用例表驱动
local leftMap = {}   -- itemId -> 剩余购买次数（-1 = 不限购）
local costMap = {}   -- itemId -> 实付
local origMap = {}   -- itemId -> 原价
ShopManager = {
    GetShopItemRemainBuyTimes = function(shopType, itemId) return leftMap[itemId] end,
    calculateBuyCost = function(shopType, itemId, count)
        return 16, costMap[itemId], origMap[itemId] or costMap[itemId]
    end,
}

----------------------------------------------------------------------
-- 2) 加载被测模块（真实文件）
----------------------------------------------------------------------
dofile(LUA_SRC .. "/Modules/Vip/VipManager.lua")
local VM = VipManager

-- vipLevel 是模块局部变量，SetVipLevel 会连带刷新一堆别的管理器 ⇒ 测试里直接替掉 getter
local vlevel = 0
VM.GetVipLevel = function() return vlevel end

----------------------------------------------------------------------
-- 3) 造商店数据：VIP0=240 / VIP1=800 / VIP2=3450 / VIP3=0（模拟 0 元购）
----------------------------------------------------------------------
VM.vipShopData = {
    [1] = { Id = 1101, Sort = 1 },
    [2] = { Id = 1102, Sort = 2 },
    [3] = { Id = 1103, Sort = 3 },
    [4] = { Id = 9001, Sort = 4 }, -- 假想「0 元」档，用来验证免费分支
}
leftMap = { [1101] = 1, [1102] = 1, [1103] = 1, [9001] = 1 }
costMap = { [1101] = 240, [1102] = 800, [1103] = 3450, [9001] = 0 }
origMap = { [1101] = 240, [1102] = 800, [1103] = 3450, [9001] = 0 }

----------------------------------------------------------------------
-- 4) ① 付费档位不点亮
----------------------------------------------------------------------
print("[1] 付费档位（VIP1=800 钻）→ 页签不亮")
vlevel = 3
Check(VM.HasFreeVipGift(1) == false, "HasFreeVipGift(1)=false（实付 800）")

print("[2] 付费档位（VIP2=3450 钻）→ 页签不亮")
Check(VM.HasFreeVipGift(2) == false, "HasFreeVipGift(2)=false（实付 3450）")

print("[3] 这就是线上那三颗：VIP1/2/3 全付费 → 必须全灭（0 档-2 档，第 3 档是免费档，见下一项）")
local litCount = 0
for lv = 0, 2 do
    if VM.HasFreeVipGift(lv) then litCount = litCount + 1 end
end
Check(litCount == 0, "0 档-2 档全付费时点亮数=" .. litCount)

----------------------------------------------------------------------
-- 5) ② 免费档位 / 未解锁
----------------------------------------------------------------------
print("[4] 0 元档且已解锁 → 亮")
Check(VM.HasFreeVipGift(3) == true, "HasFreeVipGift(3)=true（实付 0）")

print("[5] 0 元档但未解锁（vipLevel=2 < 3）→ 不亮")
vlevel = 2
Check(VM.HasFreeVipGift(3) == false, "未解锁时不亮")
vlevel = 3

----------------------------------------------------------------------
-- 6) ③ 次数用尽 / 不限购
----------------------------------------------------------------------
print("[6] 0 元档但次数用尽（leftNum=0）→ 不亮")
leftMap[9001] = 0
Check(VM.HasFreeVipGift(3) == false, "leftNum=0 → false")

print("[7] 0 元档且不限购（leftNum=-1）→ 亮")
leftMap[9001] = -1
Check(VM.HasFreeVipGift(3) == true, "leftNum=-1 → true")
leftMap[9001] = 1

----------------------------------------------------------------------
-- 7) ④ 配置缺失不崩
----------------------------------------------------------------------
print("[8] vipShopData 没有该档（level=5）→ 两个函数都返回 false 且不抛错")
local okA, resA = pcall(VM.HasFreeVipGift, 5)
local okB, resB = pcall(VM.GetBtnListRed, 5)
Check(okA and resA == false, "HasFreeVipGift 安全返回 false（ok=" .. tostring(okA) .. "）")
Check(okB and resB == false, "GetBtnListRed 不再 data.Id 崩（旧代码这里会抛错）")

----------------------------------------------------------------------
-- 8) ⑤ 「可购买」与「可领」是两个口径
----------------------------------------------------------------------
print("[9] 同一付费档：GetBtnListRed=true（可买）但 HasFreeVipGift=false（不可领）")
Check(VM.GetBtnListRed(1) == true and VM.HasFreeVipGift(1) == false,
    "GetBtnListRed(1)=true / HasFreeVipGift(1)=false ⇒ 页签用后者，不会再骗人")

----------------------------------------------------------------------
print("")
if failed == 0 then
    print("ALL PASS")
    os.exit(0)
else
    print(string.format("%d FAILED", failed))
    os.exit(1)
end
