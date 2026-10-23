#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""充值全量扫描后的定点修复（R15）。

背景：R10 把 Type=5 直购礼包带做成了 0.258–0.353 抽/元的单调阶梯，
但礼包带以外的 4 条产品线从没进过修复范围，一直是「直充价」：

    成长手册   Type=11  198 元 →  9.0 抽  0.045
    终身会员   Type=20  128 元 → 12.6 抽  0.098
    终身会员   Type=20  288 元 → 28.2 抽  0.098
    豪华周卡   Type=21   68 元 →  3.1 抽  0.045   ← 同价同名的 70003 有 13.1 抽
    俱乐部礼包 Type=22   30 元 →  4.4 抽  0.145

本轮只做三件事，全部「只加券，不动价格/钻石/门控/计费点」：
    1) 活动 7002 补抽卡券，使两张 ¥68 周卡等值（70002 从 3.1 → 13.1）
    2) 四条产品线补到同价地板 0.150 抽/元
    3) 周卡补到 68 元档带 0.266（订阅类应优于一次性）

用法：
    python3 scripts/monetization_scan_fix.py            # dry-run
    python3 scripts/monetization_scan_fix.py --apply    # 备份 + 落表 + 自检 + 失败回滚
    python3 scripts/monetization_scan_fix.py --revert <备份目录>
"""
from __future__ import annotations

import argparse
import os
import shutil
import sys
import time

import openpyxl

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from backup_paths import sub as _bak_sub  # noqa: E402
from monetization_audit import (  # noqa: E402
    BASE, DP_PER_PULL, TICKETS, header_index, load_skus, load_fund_totals,
    load_activity_tracks, sku_total_pull, live_skus, pairs, pull_value,
)

BACKUP_ROOT = _bak_sub("_backup_before_scan_fix")
F_RECHARGE = "RechargeCommodityConfig"
F_ACTREWARD = "ActivityRewardConfig"
TICKET = "19"          # 特殊招募券，R10 起统一补这一种
FLOOR = 0.150          # 同价地板：3.3x 直充，R10 自检口径


# ─────────────────────────── 奖励串读写 ───────────────────────────

def fmt_pairs(pairs_list) -> str:
    return "|".join("%s#%d" % (k, n) for k, n in pairs_list if n)


def add_items(text, delta):
    """按 id 累加；已有就地改，没有就追加末尾。"""
    lst = []
    for chunk in str(text or "").split("|"):
        if "#" not in chunk:
            continue
        k, _, n = chunk.partition("#")
        try:
            lst.append([k.strip(), int(float(n))])
        except (TypeError, ValueError):
            lst.append([k.strip(), 0])
    pos = {k: i for i, (k, _) in enumerate(lst)}
    for k, n in delta.items():
        if k in pos:
            lst[pos[k]][1] += n
        else:
            lst.append([k, n])
            pos[k] = len(lst) - 1
    return fmt_pairs([(k, n) for k, n in lst])


# ─────────────────────────── 改动计划 ───────────────────────────

def build_plan():
    """返回 (SKU 券补充, 活动行券补充)。金额/条数在这里集中定义，方便复核。"""
    sku_add = {}
    # 成长手册 9 行：198 元 → 30 抽（+21）
    for sid in range(5001, 5010):
        sku_add[sid] = 21
    # 终身会员
    sku_add[30000] = 7     # 128 元 12.6 → 19.2
    sku_add[30001] = 16    # 288 元 28.2 → 44.2（地板 43.2，取整留余量）
    # 俱乐部礼包
    sku_add[4001] = 1      # 30 元 4.4 → 4.5
    # 豪华周卡（两行同价同名，补到 68 元档带 0.266）
    sku_add[70002] = 5
    sku_add[70003] = 5

    # 活动 7002：按 7003 的券节奏补（不删原有戒圈）
    act_add = {70022: 2, 70023: 3, 70024: 2, 70025: 3}
    return sku_add, act_add


# ─────────────────────────── 备份 ───────────────────────────

def backup(names):
    ts = time.strftime("%Y%m%d-%H%M%S")
    d = os.path.join(BACKUP_ROOT, ts)
    os.makedirs(d, exist_ok=True)
    for n in names:
        shutil.copy2(os.path.join(BASE, n + ".xlsx"), os.path.join(d, n + ".xlsx"))
    return d


def revert(src):
    n = 0
    for f in sorted(os.listdir(src)):
        if f.endswith(".xlsx"):
            shutil.copy2(os.path.join(src, f), os.path.join(BASE, f))
            n += 1
    print("已从 %s 回滚 %d 张表" % (src, n))


# ─────────────────────────── 报告 ───────────────────────────

def snapshot_values():
    skus, _, _ = load_skus()
    funds = load_fund_totals()
    tracks, s2a = load_activity_tracks()
    out = {}
    for s in live_skus(skus):
        out[s["id"]] = round(sku_total_pull(s, funds, tracks, s2a), 2)
    return out, skus


def print_plan(sku_add, act_add, before):
    print("SKU 券补充（只加 %s 券）" % TICKET)
    print("  %-7s %-5s %7s %8s %8s %7s" % ("id", "价格", "券+", "抽(前)", "抽(后)", "抽/元后"))
    for sid in sorted(sku_add):
        s = SKUS[sid]
        p = s["price"]
        b = before.get(sid, 0.0)
        a = b + sku_add[sid]
        print("  %-7s %-5s %7d %8.1f %8.1f %7.3f" %
              (sid, p, sku_add[sid], b, a, a / p if p else 0))
    print("\n活动行券补充（ActivityRewardConfig）")
    for rid, n in sorted(act_add.items()):
        print("  %-7s +%s#%d" % (rid, TICKET, n))


# ─────────────────────────── 落表 ───────────────────────────

def apply_sku(ws, idx, sku_add):
    c_base, c_show, c_id = idx["BaseReward"], idx["RewardShow"], idx["Id"]
    touched = 0
    for row in ws.iter_rows(min_row=6):
        sid = row[c_id].value
        if sid not in sku_add:
            continue
        delta = {TICKET: sku_add[sid]}
        base = row[c_base].value or ""
        row[c_base].value = add_items(base, delta)
        show = row[c_show].value or ""
        if str(show).strip():
            row[c_show].value = add_items(show, delta)
        touched += 1
    return touched


def apply_activity(ws, idx, act_add):
    c_id, c_reward = idx["Id"], idx["Reward"]
    touched = 0
    for row in ws.iter_rows(min_row=8):
        rid = row[c_id].value
        if rid not in act_add:
            continue
        row[c_reward].value = add_items(row[c_reward].value or "",
                                            {TICKET: act_add[rid]})
        touched += 1
    return touched


# ─────────────────────────── 自检 ───────────────────────────

def verify(before, sku_add):
    msgs, ok = [], True

    def chk(cond, text):
        nonlocal ok
        msgs.append(("  ✓ " if cond else "  ✗ ") + text)
        if not cond:
            ok = False

    after, skus = snapshot_values()
    # 1 SKU 数量不变
    chk(len(after) == len(before), "在售 SKU 数不变：%d / %d" % (len(after), len(before)))
    # 2 目标 SKU 达到地板
    bad = [i for i in sku_add
           if after.get(i, 0) / (skus[i]["price"] or 1) < FLOOR - 1e-6]
    chk(not bad, "目标 SKU 全部达到地板 %.3f 抽/元：未达标 %s" % (FLOOR, bad or "无"))
    # 3 钻石零改动
    wb = openpyxl.load_workbook(os.path.join(BASE, F_RECHARGE + ".xlsx"), data_only=True)
    ws = wb.worksheets[0]
    idx = header_index(ws)
    dia_bad, show_bad = [], []
    for row in ws.iter_rows(min_row=6):
        sid = row[idx["Id"]].value
        if sid not in sku_add:
            continue
        base, show = row[idx["BaseReward"]].value or "", row[idx["RewardShow"]].value or ""
        bp, sp = pairs(base), pairs(show)
        if bp.get("16", 0) != skus[sid]["base"].get("16", 0) + skus[sid]["extra"].get("16", 0):
            dia_bad.append(sid)
        if str(show).strip():
            tb = sum(bp.get(k, 0) for k in TICKETS)
            ts = sum(sp.get(k, 0) for k in TICKETS)
            if tb != ts:
                show_bad.append((sid, tb, ts))
    chk(not dia_bad, "钻石数量零改动：%s" % (dia_bad or "无"))
    chk(not show_bad, "BaseReward 与 RewardShow 券数一致：%s" % (show_bad or "无"))
    # 4 价格 / 门控 / 限购未触碰
    wb.close()
    chk(True, "价格、OnSaleRule、Limit 列本轮未写入（脚本只写 BaseReward/RewardShow）")
    # 5 两张周卡等值
    chk(abs(after.get(70002, 0) - after.get(70003, 0)) < 0.01,
        "70002 与 70003 抽等值相等：%.1f / %.1f" % (after.get(70002, 0), after.get(70003, 0)))
    # 6 礼包带没有被拉低（Type=5 地板不回退）
    t5 = [after[i] / skus[i]["price"] for i in after
          if skus[i]["type"] == 5 and skus[i]["price"] >= 68]
    chk(min(t5) >= 0.20, "Type=5 复购带最低抽/元未回退：%.3f" % min(t5))
    return ok, msgs, after


# ─────────────────────────── main ───────────────────────────

def main():
    global SKUS
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--revert", metavar="DIR")
    args = ap.parse_args()

    if args.revert:
        revert(args.revert)
        return 0

    before, SKUS = snapshot_values()
    sku_add, act_add = build_plan()
    print_plan(sku_add, act_add, before)

    if not args.apply:
        print("\n[dry-run] 未写盘。确认无误后加 --apply。")
        return 0

    bak = backup([F_RECHARGE, F_ACTREWARD])
    print("\n备份：%s" % bak)

    p1 = os.path.join(BASE, F_RECHARGE + ".xlsx")
    wb = openpyxl.load_workbook(p1)
    ws = wb.worksheets[0]
    n1 = apply_sku(ws, header_index(ws), sku_add)
    wb.save(p1)
    wb.close()

    p2 = os.path.join(BASE, F_ACTREWARD + ".xlsx")
    wb = openpyxl.load_workbook(p2)
    ws = wb.worksheets[0]
    n2 = apply_activity(ws, header_index(ws), act_add)
    wb.save(p2)
    wb.close()
    print("落表：%s %d 行 / %s %d 行" % (F_RECHARGE, n1, F_ACTREWARD, n2))

    ok, msgs, _ = verify(before, sku_add)
    print("\n自检：")
    print("\n".join(msgs))
    if not ok:
        print("\n❌ 自检失败，自动回滚…")
        revert(bak)
        return 1
    print("\n✅ 落表完成，自检通过。回滚：--revert %s" % bak)
    return 0


if __name__ == "__main__":
    sys.exit(main())
