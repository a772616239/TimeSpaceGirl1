#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
付费数值改版（RechargeCommodityConfig / MonthcardConfig / LuxuryFund / VipLevelConfig[New]）

背景：全表 823 个有价 SKU 里 85% 的「钻石/元」= 10（等于直充单价），
      礼包名义折扣是假的；大额档无阶梯溢价；成长基金展示 25,600 钻实发 7,880 钻。

用法：
    python scripts/monetization_retune.py            # dry-run，只打印对比
    python scripts/monetization_retune.py --apply    # 写盘（自动备份 + 自检 + 失败回滚）
    python scripts/monetization_retune.py --revert <backup_dir>
    python scripts/monetization_retune.py --list-backups

不改：RewardShow 以外的展示字段、ShowType/货架结构、Price（价格锚点保持）、
      渠道计费点（ChannelRechargeIdConfig）、档位数量。
"""
import argparse
import json
import os
import shutil
import sys
import time
import collections

try:
    import openpyxl
except ImportError:
    sys.exit("需要 openpyxl：/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "data_execl", "base_data")
# 备份必须落在工程外（base_data 是导表输入目录，放进去会被当成表扫到）
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from backup_paths import sub as _bak_sub  # noqa: E402

BACKUP_ROOT = _bak_sub("_backup_before_monetize")

F_RECHARGE = "RechargeCommodityConfig"
F_MONTHCARD = "MonthcardConfig"
F_FUND = "LuxuryFund"
F_VIP = "VipLevelConfig"
F_VIPNEW = "VipLevelConfigNew"

DATA_START_ROW = 6  # r1 表头 / r2 类型 / r3 导出类型 / r4 注释 / r5 默认值

# ─────────────────────────── 改版规则 ───────────────────────────

# R1 钻石直充阶梯：base 10 钻/元 + 阶梯加赠（大额才有溢价）
#     id -> (price, new_diamond)
#     钻石数量一律取整十（设计规范），故 11.5/12.0/13.0 钻/元的理论值
#     1127/2376/8424 就近取整十到 1130/2380/8420。
DIAMOND_TIERS = {
    10: (30, 750),     # 30 元「月卡」SKU 给 300 钻（10 钻/元），与 12 元档重复且完全无效 -> 750
    2: (30, 330),      # 300 -> 330   (11.0 钻/元)
    3: (98, 1130),     # 980 -> 1130  (11.53, 整十)
    4: (198, 2380),    # 1980 -> 2380 (12.02, 整十)
    5: (328, 4100),    # 3280 -> 4100 (12.50)
    6: (648, 8420),    # 6480 -> 8420 (12.99, 整十)
}

# R2 直购礼包（Type=5）钻石加赠系数，按价格档；修 388/448 档低于直充的倒挂
def pack_scale(price):
    if price <= 18:
        return 1.30
    if price <= 68:
        return 1.20
    if price <= 128:
        return 1.15
    if price <= 328:
        return 1.12
    if price <= 648:
        return 1.15   # 388/448/488/648：先修倒挂再统一给 15%
    return 1.15


# R3 月卡：激活门槛 30 -> 12（买 12 元月卡当场生效，不再"买了没月卡"）
MONTHCARD_ACTIVATE = {1: 12}
# R4 月卡日返：豪华月卡 200 -> 360（原比基础月卡性价比低 4.6 倍）
MONTHCARD_DAILY = {2: 360}

# R5 成长基金：LuxuryFund 30 天钻石总量放大倍数 + RewardShow 对齐实发
FUND_MULT = {78: 2.0, 79: 2.6}
FUND_SKU = {78: 128, 79: 328}          # RechargeCommodityConfig id -> price
FUND_SKU_ALIAS = {7801: 78, 7901: 79, 7802: 78, 7902: 79}

# R6 VIP 日礼曲线（16# 值），按累计充值做回本曲线
VIP_DAILY = {
    0: 10, 1: 60, 2: 110, 3: 160, 4: 220, 5: 290,
    6: 360, 7: 400, 8: 460, 9: 550, 10: 700,
    11: 820, 12: 1000, 13: 1200, 14: 1450,
    15: 1700, 16: 1950, 17: 2200, 18: 2600,
}


# ─────────────────────────── 工具 ───────────────────────────

def load(name):
    path = os.path.join(BASE, name + ".xlsx")
    wb = openpyxl.load_workbook(path)
    ws = wb.worksheets[0]
    hdr = [(c.value or "") for c in ws[1]]
    idx = {h: i for i, h in enumerate(hdr)}
    return wb, ws, idx


def col(idx, name):
    if name not in idx:
        raise KeyError("缺列 %s" % name)
    return idx[name]


def iter_rows(ws, idx):
    for r in range(DATA_START_ROW, ws.max_row + 1):
        v = [c.value for c in ws[r]]
        if not v or v[1] is None:
            continue
        yield r, v


def parse_reward(s):
    out = []
    for part in str(s or "").split("|"):
        if "#" in part:
            a = part.split("#")
            out.append([a[0], int(float(a[1]))])
    return out


def fmt_reward(items):
    return "|".join("%s#%d" % (k, v) for k, v in items)


def set_cell(ws, row, cidx, value):
    # 保留单元格样式，只改值
    ws.cell(row=row, column=cidx + 1).value = value


def get_cell(v, cidx):
    return v[cidx] if cidx < len(v) else None


# ─────────────────────────── 各规则 ───────────────────────────

def plan_recharge():
    """返回 [(row, col_name, old, new, tag)]"""
    wb, ws, idx = load(F_RECHARGE)
    c_id = col(idx, "Id")
    c_type = col(idx, "Type")
    c_price = col(idx, "Price")
    c_base = col(idx, "BaseReward")
    c_show = col(idx, "RewardShow")
    changes = []
    stats = []

    for r, v in iter_rows(ws, idx):
        sid = get_cell(v, c_id)
        stype = get_cell(v, c_type)
        price = get_cell(v, c_price) or 0
        base = parse_reward(get_cell(v, c_base))
        dia = sum(n for k, n in base if k == "16")

        # R1 钻石直充阶梯
        if sid in DIAMOND_TIERS:
            _, new_dia = DIAMOND_TIERS[sid]
            if new_dia != dia:
                nb = [[k, (new_dia if k == "16" else n)] for k, n in base]
                changes.append((r, "BaseReward", get_cell(v, c_base), fmt_reward(nb), "R1-阶梯"))
                cur_show = parse_reward(get_cell(v, c_show))
                if any(k == "16" for k, _ in cur_show):
                    ns = [[k, (new_dia if k == "16" else n)] for k, n in cur_show]
                    changes.append((r, "RewardShow", get_cell(v, c_show), fmt_reward(ns), "R1-阶梯"))
                # 首充赠送同步到新基础值，否则「首充双倍」文案不成立（赠 6480 < 基础 8424）
                c_fm = col(idx, "FirstMultiple")
                fm = parse_reward(get_cell(v, c_fm))
                if any(k == "16" for k, _ in fm):
                    nf = [[k, (new_dia if k == "16" else n)] for k, n in fm]
                    changes.append((r, "FirstMultiple", get_cell(v, c_fm), fmt_reward(nf), "R1-首充同步"))
                stats.append(("直充 %d元" % price, dia, new_dia))
            continue

        # R2 Type5 直购礼包钻石加赠（只补「优惠不足」的，已 ≥15 钻/元的不动）
        if stype == 5 and price > 0 and dia > 0 and (dia / price) <= 15:
            k = pack_scale(price)
            new_dia = int(round(dia * k))
            if new_dia <= dia:
                continue
            nb = [[key, (new_dia if key == "16" else n)] for key, n in base]
            changes.append((r, "BaseReward", get_cell(v, c_base), fmt_reward(nb), "R2-礼包加赠"))
            cur_show = parse_reward(get_cell(v, c_show))
            if any(key == "16" for key, _ in cur_show):
                ns = [[key, (new_dia if key == "16" else n)] for key, n in cur_show]
                changes.append((r, "RewardShow", get_cell(v, c_show), fmt_reward(ns), "R2-礼包加赠"))
            stats.append(("礼包 %d元#%s" % (price, sid), dia, new_dia))
        elif stype == 5 and price > 0 and dia == 0:
            stats.append(("礼包 %d元#%s(无钻石)" % (price, sid), 0, 0))

    return wb, ws, idx, changes, stats


def fund_actual(wb_fund, ws_fund, idx_fund, ftype, mult):
    """LuxuryFund 30 天累计（按倍数放大后的钻石总量）"""
    c_type = col(idx_fund, "Type")
    c_rew = col(idx_fund, "reward")
    total = collections.Counter()
    rows = []
    for r, v in iter_rows(ws_fund, idx_fund):
        if get_cell(v, c_type) != ftype:
            continue
        items = parse_reward(get_cell(v, c_rew))
        rows.append((r, items, get_cell(v, c_rew)))
        for k, n in items:
            total[k] += n
    new_total = collections.Counter()
    new_rows = []
    for r, items, raw in rows:
        ni = [[k, (int(round(n * mult)) if k == "16" else n)] for k, n in items]
        new_rows.append((r, raw, fmt_reward(ni)))
        for k, n in ni:
            new_total[k] += n
    return total, new_total, new_rows


def plan_all():
    changes = collections.defaultdict(list)
    report = {}

    wb, ws, idx, ch, stats = plan_recharge()
    changes[F_RECHARGE] = (wb, ws, idx, ch)
    report["recharge_stats"] = stats

    # 月卡
    wb, ws, idx = load(F_MONTHCARD)
    ch = []
    c_id = col(idx, "Id")
    c_price = col(idx, "Price")
    c_daily = col(idx, "BaseReward")
    mc_detail = []
    for r, v in iter_rows(ws, idx):
        sid = get_cell(v, c_id)
        if sid in MONTHCARD_ACTIVATE:
            old = get_cell(v, c_price)
            new = MONTHCARD_ACTIVATE[sid]
            if old != new:
                ch.append((r, "Price", old, new, "R3-月卡门槛"))
            mc_detail.append(("月卡激活门槛", old, new))
        if sid in MONTHCARD_DAILY:
            old_raw = get_cell(v, c_daily)
            items = parse_reward(old_raw)
            new_dia = MONTHCARD_DAILY[sid]
            ni = [[k, (new_dia if k == "16" else n)] for k, n in items]
            if fmt_reward(ni) != str(old_raw):
                ch.append((r, "BaseReward", old_raw, fmt_reward(ni), "R4-豪华月卡日返"))
                for k, n in items:
                    if k == "16":
                        mc_detail.append(("豪华月卡日返", n, new_dia))
    changes[F_MONTHCARD] = (wb, ws, idx, ch)
    report["monthcard"] = mc_detail

    # 成长基金
    wb_f, ws_f, idx_f = load(F_FUND)
    ch = []
    fund_info = {}
    for ftype, mult in FUND_MULT.items():
        old_tot, new_tot, new_rows = fund_actual(wb_f, ws_f, idx_f, ftype, mult)
        for r, old_raw, new_raw in new_rows:
            if str(old_raw) != new_raw:
                ch.append((r, "reward", old_raw, new_raw, "R5-基金发放"))
        fund_info[ftype] = (old_tot.get("16", 0), new_tot.get("16", 0))
    changes[F_FUND] = (wb_f, ws_f, idx_f, ch)

    # 基金商品 RewardShow 对齐
    wb_r, ws_r, idx_r, ch_r = changes[F_RECHARGE][0], changes[F_RECHARGE][1], changes[F_RECHARGE][2], changes[F_RECHARGE][3]
    c_id = col(idx_r, "Id")
    c_show = col(idx_r, "RewardShow")
    c_base = col(idx_r, "BaseReward")
    fund_show = {}
    for r, v in iter_rows(ws_r, idx_r):
        sid = get_cell(v, c_id)
        base_type = FUND_SKU_ALIAS.get(sid, sid)
        if base_type not in FUND_MULT:
            continue
        base_dia = sum(n for k, n in parse_reward(get_cell(v, c_base)) if k == "16")
        total = base_dia + fund_info[base_type][1]
        old_show = get_cell(v, c_show)
        new_show = "16#%d" % total
        if str(old_show) != new_show:
            ch_r.append((r, "RewardShow", old_show, new_show, "R5-基金展示对齐"))
        fund_show[sid] = (get_cell(v, col(idx_r, "Price")), str(old_show), new_show)
    report["fund"] = {"info": fund_info, "show": fund_show}

    # VIP 日礼
    for fname in (F_VIP, F_VIPNEW):
        wb, ws, idx = load(fname)
        ch = []
        c_lv = col(idx, "VipLevel")
        c_daily = col(idx, "VipBoxDailyReward")
        for r, v in iter_rows(ws, idx):
            lv = get_cell(v, c_lv)
            if lv not in VIP_DAILY:
                continue
            old_raw = get_cell(v, c_daily)
            items = parse_reward(old_raw)
            if not items:
                continue
            new_dia = VIP_DAILY[lv]
            ni = [[k, (new_dia if k == "16" else n)] for k, n in items]
            if fmt_reward(ni) != str(old_raw):
                ch.append((r, "VipBoxDailyReward", old_raw, fmt_reward(ni), "R6-VIP日礼"))
        changes[fname] = (wb, ws, idx, ch)

    return changes, report


# ─────────────────────────── 自检 ───────────────────────────

def verify_after(changes):
    """写盘后重新读盘校验；返回 (ok, msgs)

    注意：Type=5 直购礼包的主价值常在 ExtraReward/道具里，BaseReward 的钻石只是零头，
    不能用「钻石/元」单独判优劣，因此倒挂校验只针对 Type=3（钻石直充）与月卡类 SKU。
    """
    msgs = []
    ok = True

    wb, ws, idx = load(F_RECHARGE)
    c_id = col(idx, "Id")
    c_type = col(idx, "Type")
    c_price = col(idx, "Price")
    c_base = col(idx, "BaseReward")

    # 1) 钻石直充档：钻/元必须单调不降（大额才有溢价）
    #    id=10 是 30 元「月卡」SKU，不是钻石档，排除在阶梯之外
    tier = []
    for r, v in iter_rows(ws, idx):
        sid = get_cell(v, c_id)
        if sid not in DIAMOND_TIERS or sid == 10:
            continue
        price = get_cell(v, c_price) or 0
        dia = sum(n for k, n in parse_reward(get_cell(v, c_base)) if k == "16")
        if price:
            tier.append((price, dia / price, sid))
    tier.sort()
    mono = all(tier[i][1] <= tier[i + 1][1] + 1e-9 for i in range(len(tier) - 1))
    msgs.append("%s 钻石直充阶梯钻/元单调不降: %s" % ("✓" if mono else "✗", [(p, round(q, 2)) for p, q, _ in tier]))
    if not mono:
        ok = False

    # 2) 钻石直充(Type=3)：不得低于 10 钻/元
    bad = []
    for r, v in iter_rows(ws, idx):
        if get_cell(v, c_type) != 3:
            continue
        price = get_cell(v, c_price) or 0
        if price <= 0:
            continue
        dia = sum(n for k, n in parse_reward(get_cell(v, c_base)) if k == "16")
        if dia / price < 10:
            bad.append((get_cell(v, c_id), price, round(dia / price, 2)))
    msgs.append("%s 钻石直充档无倒挂（均 ≥ 10 钻/元）%s" % ("✓" if not bad else "✗", bad[:5] if bad else ""))
    if bad:
        ok = False

    # 2b) 首充赠送不得小于基础钻石（否则「首充双倍」不成立）
    c_fm = col(idx, "FirstMultiple")
    bad_fm = []
    for r, v in iter_rows(ws, idx):
        base_dia = sum(n for k, n in parse_reward(get_cell(v, c_base)) if k == "16")
        fm_dia = sum(n for k, n in parse_reward(get_cell(v, c_fm)) if k == "16")
        if fm_dia == 0 or base_dia == 0:
            continue
        if fm_dia < base_dia:
            bad_fm.append((get_cell(v, c_id), base_dia, fm_dia))
    msgs.append("%s 首充赠送 ≥ 基础钻石 %s" % ("✓" if not bad_fm else "✗", bad_fm[:5] if bad_fm else ""))
    if bad_fm:
        ok = False

    # 3) 月卡类 SKU（Type 1/2/6/7）：base 里带钻石的，即时钻石不得低于 10 钻/元
    weak = []
    for r, v in iter_rows(ws, idx):
        if get_cell(v, c_type) not in (1, 2, 6, 7):
            continue
        price = get_cell(v, c_price) or 0
        if price <= 0:
            continue
        dia = sum(n for k, n in parse_reward(get_cell(v, c_base)) if k == "16")
        if dia == 0:
            continue
        if dia / price < 10:
            weak.append((get_cell(v, c_id), price, round(dia / price, 2)))
    msgs.append("%s 月卡类 SKU 即时钻石 ≥ 10 钻/元 %s" % ("✓" if not weak else "✗", weak if weak else ""))
    if weak:
        ok = False

    # 3b) 月卡 / 豪华月卡 30 天总价值（base + 日返 × 天数）
    wb_m, ws_m, idx_m = load(F_MONTHCARD)
    c_mid = col(idx_m, "Id")
    c_mprice = col(idx_m, "Price")
    c_mdaily = col(idx_m, "BaseReward")
    c_days = col(idx_m, "ContiueDays")
    mc = {}
    for r, v in iter_rows(ws_m, idx_m):
        mc[get_cell(v, c_mid)] = (
            get_cell(v, c_mprice),
            sum(n for k, n in parse_reward(get_cell(v, c_mdaily)) if k == "16"),
            get_cell(v, c_days) or 30,
        )
    sku_map = {}
    for r, v in iter_rows(ws, idx):
        if get_cell(v, c_type) not in (1, 2, 6, 7):
            continue
        sku_map[get_cell(v, c_id)] = (
            get_cell(v, c_price) or 0,
            sum(n for k, n in parse_reward(get_cell(v, c_base)) if k == "16"),
        )
    for sid, mid, label in [(9, 1, "月卡"), (11, 2, "豪华月卡")]:
        if sid not in sku_map or mid not in mc:
            continue
        price, base_dia = sku_map[sid]
        _, daily, days = mc[mid]
        total = base_dia + daily * days
        per_yuan = total / price if price else 0
        need = 250 if mid == 1 else 100
        flag = "✓" if per_yuan >= need else "✗"
        msgs.append("%s %s %s元: %d 钻 + %d/天×%d = %d 钻 = %.0f 钻/元（要求 ≥%d）"
                    % (flag, label, price, base_dia, daily, days, total, per_yuan, need))
        if per_yuan < need:
            ok = False

    # 4) 全表分布（信息项，不判失败）
    msgs.append("   全表分布（改后）: %s" % dict(ratio_histogram(ws, idx)))

    # 5) 月卡门槛
    wb, ws, idx = load(F_MONTHCARD)
    c_lv = col(idx, "Id")
    c_price = col(idx, "Price")
    for r, v in iter_rows(ws, idx):
        if get_cell(v, c_lv) == 1:
            v2 = get_cell(v, c_price)
            msgs.append("%s 月卡激活门槛 = %s（应为 12）" % ("✓" if v2 == 12 else "✗", v2))
            if v2 != 12:
                ok = False

    # 基金展示 == 实发
    wb_f, ws_f, idx_f = load(F_FUND)
    c_type = col(idx_f, "Type")
    c_rew = col(idx_f, "reward")
    for ftype in FUND_MULT:
        tot = 0
        for r, v in iter_rows(ws_f, idx_f):
            if get_cell(v, c_type) != ftype:
                continue
            tot += sum(n for k, n in parse_reward(get_cell(v, c_rew)) if k == "16")
        msgs.append("   基金 %s 30 天钻石合计 = %d" % (ftype, tot))
    return ok, msgs


# ─────────────────────────── 主流程 ───────────────────────────

def ratio_histogram(ws, idx):
    """按「钻石/元」给有价且带钻石的 SKU 分档计数"""
    c_type = col(idx, "Type")
    c_price = col(idx, "Price")
    c_base = col(idx, "BaseReward")
    b = collections.Counter()
    for r, v in iter_rows(ws, idx):
        price = get_cell(v, c_price) or 0
        if price <= 0:
            continue
        dia = sum(n for k, n in parse_reward(get_cell(v, c_base)) if k == "16")
        if dia == 0:
            b["无钻石"] += 1
            continue
        q = dia / price
        if q <= 10.5:
            b["≈直充(≤10.5)"] += 1
        elif q <= 15:
            b["弱优惠(10.5-15)"] += 1
        elif q <= 30:
            b["中优惠(15-30)"] += 1
        else:
            b["高优惠(>30)"] += 1
    return b


def print_plan(changes, report):
    print("=" * 74)
    print("付费数值改版 · DRY-RUN")
    print("=" * 74)

    # 改前/改后性价比分布（RechargeCommodityConfig）
    wb_r, ws_r, idx_r, ch_r = changes[F_RECHARGE]
    before = ratio_histogram(ws_r, idx_r)
    for row, cname, old, new, tag in ch_r:
        set_cell(ws_r, row, col(idx_r, cname), new)
    after = ratio_histogram(ws_r, idx_r)
    print("\n【全表 SKU 性价比分布】")
    print("  %-18s %8s %8s" % ("档位", "改前", "改后"))
    for k in ["≈直充(≤10.5)", "弱优惠(10.5-15)", "中优惠(15-30)", "高优惠(>30)", "无钻石"]:
        print("  %-18s %8d %8d" % (k, before.get(k, 0), after.get(k, 0)))
    tot = sum(before.values())
    print("  %-18s %8d %8d" % ("合计", tot, sum(after.values())))

    total = 0
    print()
    for fname, (wb, ws, idx, ch) in changes.items():
        tags = collections.Counter(c[4] for c in ch)
        total += len(ch)
        print("\n[%s] 改动 %d 处  %s" % (fname, len(ch), dict(tags)))
        for row, cname, old, new, tag in ch[:6]:
            print("   r%-4d %-20s %s -> %s   (%s)" % (row, cname, old, new, tag))
        if len(ch) > 6:
            print("   … 其余 %d 处" % (len(ch) - 6))
    print("\n合计改动单元格 %d 个" % total)

    print("\n" + "-" * 74)
    print("成长基金（30 天）")
    for ftype, (old, new) in report["fund"]["info"].items():
        print("   LuxuryFund Type %-3d 钻石 %6d -> %6d" % (ftype, old, new))
    for sid, (price, old_show, new_show) in sorted(report["fund"]["show"].items()):
        print("   商品 %-5s %3s元  展示 %-12s -> %-12s" % (sid, price, old_show, new_show))
    print("\n月卡")
    for name, old, new in report["monthcard"]:
        print("   %-12s %s -> %s" % (name, old, new))


def do_apply(changes):
    ts = time.strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(BACKUP_ROOT, ts)
    os.makedirs(bdir, exist_ok=True)
    for fname in changes:
        shutil.copy2(os.path.join(BASE, fname + ".xlsx"), os.path.join(bdir, fname + ".xlsx"))
    print("备份 -> %s" % bdir)

    for fname, (wb, ws, idx, ch) in changes.items():
        for row, cname, old, new, tag in ch:
            set_cell(ws, row, col(idx, cname), new)
        wb.save(os.path.join(BASE, fname + ".xlsx"))
        print("写盘 %s.xlsx (%d 处)" % (fname, len(ch)))

    ok, msgs = verify_after(changes)
    print("\n自检:")
    for m in msgs:
        print("  " + m)
    if not ok:
        print("\n✗ 自检未通过，自动回滚")
        do_revert(bdir)
        sys.exit(1)
    print("\n✓ 自检通过。备份目录: %s" % bdir)
    with open(os.path.join(bdir, "_manifest.json"), "w") as f:
        json.dump({k: len(v[3]) for k, v in changes.items()}, f, indent=2, ensure_ascii=False)
    print("\n下一步（未执行，需确认）：导表 -> 同步 CRC -> LuaBytes -> 服务端 conf/server/*.txt")


def do_revert(bdir):
    for f in os.listdir(bdir):
        if f.endswith(".xlsx"):
            shutil.copy2(os.path.join(bdir, f), os.path.join(BASE, f))
            print("还原 %s" % f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--revert", metavar="BACKUP_DIR")
    ap.add_argument("--list-backups", action="store_true")
    args = ap.parse_args()

    if args.list_backups:
        if os.path.isdir(BACKUP_ROOT):
            for d in sorted(os.listdir(BACKUP_ROOT)):
                print(os.path.join(BACKUP_ROOT, d))
        return
    if args.revert:
        do_revert(args.revert)
        return

    changes, report = plan_all()
    print_plan(changes, report)
    if args.apply:
        print("\n" + "=" * 74)
        do_apply(changes)
    else:
        print("\n（dry-run，未写盘。加 --apply 落表）")


if __name__ == "__main__":
    main()
