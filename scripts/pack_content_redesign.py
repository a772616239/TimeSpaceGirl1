#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
纯钻石礼包 → 主题化内容包（独占内容改造）

问题：203 个 Type=5 礼包的 BaseReward 只有 `16#钻石`，没有任何内容。
      ratio(感知价值/直充) 仅 1.14，而其它礼包中位 2.66 —— 它们是货架上最差的一排，
      且【同价同内容】大量复制（限时商市 117 个纯钻包里，128 元档 45 个内容完全一样）。

解法：不删（删了会打空货架、StoreTypeConfig.Number 对不上），而是
      ① 按价格档注入【玩家认的硬通货/独占内容】
      ② 同一价格档内的多个复制品分配【不同主题】，让货架第一次"有得选"

内容选择依据（真实消费数据，m5_x1_game_10001 storeLog / 209 玩家）：
      紫晶卡      28/40 笔、渗透 13.4%、成交 144 钻/张  ← 唯一有情绪价值的硬通货
      金钱/进化药剂 高频刚需（115 笔 / 31 笔）
      参赛券       竞技刚需

用法：
    python scripts/pack_content_redesign.py              # dry-run
    python scripts/pack_content_redesign.py --apply      # 落表 + 自检 + 失败回滚
    python scripts/pack_content_redesign.py --revert <dir>
"""
import argparse
import collections
import json
import os
import shutil
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import openpyxl
import monetization_sim as SIM

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "data_execl", "base_data")
# 备份必须落在工程外（base_data 是导表输入目录，放进去会被当成表扫到）
from backup_paths import sub as _bak_sub  # noqa: E402

BACKUP_ROOT = _bak_sub("_backup_before_monetization_content")
F_RECHARGE = "RechargeCommodityConfig"
DATA_START_ROW = 6

# 目标：改造后整包 ratio 落在 1.75 左右（原 1.14 → 接近其它礼包中位 2.66 的下沿，
# 既补上内容又不至于把礼包做成通胀源头）
TARGET_RATIO = 1.75

# 主题定义：name -> [(itemId, 权重)]，权重用于把内容感知值拆到多个道具
# 单件官方钻值见 SIM.ITEM_VALUE
THEMES = [
    ("抽卡",   [("19", 1.0)]),
    ("招募",   [("20", 1.0)]),
    ("养成",   [("4", 1.0)]),
    ("材料",   [("60403", 0.7), ("72001", 0.3)]),
    ("竞技",   [("23", 0.6), ("61", 0.4)]),
    ("幸运",   [("60", 0.6), ("1004", 0.4)]),
]
# 高价位追加「限定」主题（单价高、独占感强，避免高价包塞几十张紫晶卡）
THEME_LIMITED = ("限定", [("50007", 1.0)])
BIG_TIER = 328   # ≥328 元的档位额外启用「限定」主题


def load(name):
    path = os.path.join(BASE, name + ".xlsx")
    wb = openpyxl.load_workbook(path)
    ws = wb.worksheets[0]
    idx = {((c.value or "") if isinstance(c.value, str) else ""): i for i, c in enumerate(ws[1])}
    return wb, ws, idx


def valid_items():
    """从服务端 ItemConfig 取合法道具 id，避免写入不存在的道具。"""
    p = os.path.join(ROOT, "TimeSpaceServer", "skzc", "home", "java", "gameserver",
                     "conf", "server", "ItemConfig.txt")
    ids = set()
    if os.path.exists(p):
        for line in open(p, encoding="utf-8", errors="ignore"):
            a = line.split("\t")
            if a and a[0].strip().isdigit():
                ids.add(a[0].strip())
    return ids


VALID_IDS = valid_items()


def fmt_reward(items):
    return "|".join("%s#%d" % (k, v) for k, v in items if v > 0)


def planned_content(price, dia, theme):
    """按主题把「需要补的内容感知值」换算成各道具数量

    以【价格】驱动而不是以【钻石】驱动：有些包 diamond 极少（如 id=7000 68 元只给 60 钻），
    按钻石比例加内容救不回来，必须按价格档定目标总价值。
    """
    total_target = price * 10 * TARGET_RATIO
    content_perceived = max(total_target - dia, price * 10 * 0.30)
    out = []
    for item, w in theme:
        unit = SIM.ITEM_VALUE.get(item, 50.0)
        perceived_unit = unit * SIM.PERCEIVED
        if perceived_unit <= 0:
            continue
        qty = int(round(content_perceived * w / perceived_unit))
        # 数量取整到「好看的档」（避免 2317 这种数字）
        if qty >= 1000:
            qty = int(round(qty / 100.0)) * 100
        elif qty >= 100:
            qty = int(round(qty / 10.0)) * 10
        if qty > 0:
            out.append((item, qty))
    # 低价档（6 元）算出来会取整成 0，至少给 1 件，否则又是"纯钻石"
    if not out and theme:
        out.append((theme[0][0], 1))
    return out


def plan():
    wb, ws, idx = load(F_RECHARGE)
    c_id, c_type = idx["Id"], idx["Type"]
    c_show, c_price = idx["ShowType"], idx["Price"]
    c_base, c_rshow = idx["BaseReward"], idx["RewardShow"]

    rows = []
    pure = []
    for r in range(DATA_START_ROW, ws.max_row + 1):
        v = [c.value for c in ws[r]]
        if not v or v[1] is None:
            continue
        if v[c_type] != 5:
            continue
        price = v[c_price] or 0
        if price <= 0:
            continue
        rw = SIM.parse_reward(v[c_base])
        dia = rw.get("16", 0)
        others = [k for k in rw if k not in ("16", "6000124")]
        rec = dict(row=r, sid=v[c_id], show=v[c_show], price=price, dia=dia,
                   raw=v[c_base], raw_show=v[c_rshow])
        rows.append(rec)
        if dia > 0 and not others:
            pure.append(rec)

    # 按 (货架, 价格) 分组，组内轮换主题 —— 让同价复制品变成不同内容
    groups = collections.defaultdict(list)
    for rec in pure:
        groups[(rec["show"], rec["price"])].append(rec)

    changes = []
    plan_rows = []
    for (show, price), recs in sorted(groups.items()):
        pool = list(THEMES)
        if price >= BIG_TIER:
            pool.append(THEME_LIMITED)
        for i, rec in enumerate(sorted(recs, key=lambda x: x["sid"])):
            name, theme = pool[i % len(pool)]
            dia = rec["dia"]
            # 已经够值的包（钻石本身 ≥1.5 倍直充）保持纯钻，硬塞内容会顶到性价比上限
            if dia >= price * 10 * 1.5:
                plan_rows.append(dict(show=show, price=price, sid=rec["sid"], theme="保留",
                                      dia=dia, content=[], fixed_dia=False, keep=True))
                continue
            # 先修「钻石本身严重不足」的包（如闯关礼包 68 元只给 60 钻 = 0.88 钻/元，
            # 不到直充的 1/10，疑似配置漏填），否则加多少内容都被 DILUTE_CAP 压住
            fixed_dia = False
            if dia < price * 10 * 0.9:
                dia = int(round(price * 10 * 0.9 / 10.0)) * 10
                fixed_dia = True
            content = planned_content(price, dia, theme)
            bad = [c for c in content if VALID_IDS and c[0] not in VALID_IDS]
            if bad:
                raise SystemExit("非法道具 id: %s" % bad)
            items = [("16", dia)] + content
            new_base = fmt_reward(items)
            new_show = new_base
            changes.append((rec["row"], "BaseReward", rec["raw"], new_base, "内容改造"))
            if str(rec["raw_show"]) != new_show:
                changes.append((rec["row"], "RewardShow", rec["raw_show"], new_show, "内容改造"))
            plan_rows.append(dict(show=show, price=price, sid=rec["sid"], theme=name,
                                  dia=dia, content=content, fixed_dia=fixed_dia, keep=False))
    return wb, ws, idx, changes, plan_rows, pure


def evaluate(plan_rows):
    """用 sim 的估值口径算改造后的 ratio / 内容占比"""
    out = []
    for p in plan_rows:
        rw = collections.Counter({"16": p["dia"]})
        for k, n in p["content"]:
            rw[k] += n
        sku = SIM.Sku(p["sid"], 5, p["show"], p["price"], rw, 1, None)
        content_val = sku.value - p["dia"]
        share = content_val / sku.value if sku.value else 0
        out.append((sku.ratio, share, p))
    return out


def verify(plan_rows):
    msgs, ok = [], True
    ev = [x for x in evaluate(plan_rows) if not x[2].get("keep")]
    kept = [x for x in evaluate(plan_rows) if x[2].get("keep")]
    ratios = [x[0] for x in ev]
    shares = [x[1] for x in ev]
    over = [x for x in ev if x[0] > SIM.RATIO_CAP + 1e-6]
    low = [x for x in ev if x[0] < 1.45]
    zero_content = [x for x in ev if x[1] < 0.15]

    avg_r = sum(ratios) / len(ratios) if ratios else 0
    avg_s = sum(shares) / len(shares) if shares else 0
    msgs.append("%s 改造 %d 个包，平均 ratio = %.2f（原 1.14，其它礼包中位 2.66）"
                % ("✓" if 1.5 <= avg_r <= 2.4 else "✗", len(ev), avg_r))
    msgs.append("%s 内容占感知价值 平均 %.0f%%（目标 ≥30%%）" % ("✓" if avg_s >= 0.30 else "✗", avg_s * 100))
    msgs.append("%s 超出性价比上限(%.1f) 的包 = %d" % ("✓" if not over else "✗", SIM.RATIO_CAP, len(over)))
    msgs.append("%s 内容不足(<15%%) 的包 = %d" % ("✓" if not zero_content else "✗", len(zero_content)))
    msgs.append("%s ratio < 1.45 的包 = %d" % ("✓" if not low else "✗", len(low)))
    if kept:
        kr = [x[0] for x in kept]
        msgs.append("· %d 个包钻石本身已 ≥1.5 倍直充，保留纯钻不加内容（均 ratio %.2f）"
                    % (len(kept), sum(kr) / len(kr)))
        if min(kr) < 1.45:
            ok = False
            msgs.append("  ✗ 其中有 ratio < 1.45 的")
    if over or zero_content or low or not (1.5 <= avg_r <= 2.4) or avg_s < 0.30:
        ok = False
    return ok, msgs


def print_plan(plan_rows):
    ev = evaluate(plan_rows)
    print("=" * 96)
    print("纯钻石礼包 → 主题化内容包 · DRY-RUN")
    print("=" * 96)
    print("目标：%d 个纯钻包，按 (货架, 价格) 分组轮换 %d 个主题" % (len(plan_rows), len(THEMES)))
    print()
    by_show = collections.defaultdict(list)
    for x in ev:
        by_show[x[2]["show"]].append(x)
    SHOWN = {20: "礼包抢购", 22: "限时商市", 23: "珍奇宝阁", 25: "闯关礼包",
             26: "心魔试炼", 27: "皮肤礼包", 28: "灵兽宝阁", 17: "特权礼包"}
    print("%-10s %5s %10s %10s %10s" % ("货架", "数量", "均ratio", "内容占比", "主题分布"))
    for show, xs in sorted(by_show.items(), key=lambda kv: -len(kv[1])):
        th = collections.Counter(x[2]["theme"] for x in xs)
        print("%-10s %5d %10.2f %9.0f%% %s" % (
            SHOWN.get(show, show), len(xs),
            sum(x[0] for x in xs) / len(xs),
            100 * sum(x[1] for x in xs) / len(xs),
            dict(th)))
    print()
    print("样例（限时商市 128 元档，改造前后）：")
    sample = [x for x in ev if x[2]["show"] == 22 and x[2]["price"] == 128][:6]
    for ratio, share, p in sample:
        content = "+".join("%s×%d" % kv for kv in p["content"])
        print("  id=%-5s %-4s  1,472钻 → 1,472钻 + %-28s ratio %.2f 内容%.0f%%"
              % (p["sid"], p["theme"], content, ratio, share * 100))


def do_apply(wb, ws, idx, changes, plan_rows):
    ts = time.strftime("%Y%m%d-%H%M%S")
    bdir = os.path.join(BACKUP_ROOT, ts)
    os.makedirs(bdir, exist_ok=True)
    shutil.copy2(os.path.join(BASE, F_RECHARGE + ".xlsx"),
                 os.path.join(bdir, F_RECHARGE + ".xlsx"))
    print("备份 -> %s" % bdir)

    for row, cname, old, new, tag in changes:
        ws.cell(row=row, column=idx[cname] + 1).value = new
    wb.save(os.path.join(BASE, F_RECHARGE + ".xlsx"))
    print("写盘 %s.xlsx (%d 处)" % (F_RECHARGE, len(changes)))

    ok, msgs = verify(plan_rows)
    print("\n自检:")
    for m in msgs:
        print("  " + m)
    if not ok:
        print("\n✗ 自检未通过，自动回滚")
        shutil.copy2(os.path.join(bdir, F_RECHARGE + ".xlsx"),
                     os.path.join(BASE, F_RECHARGE + ".xlsx"))
        sys.exit(1)
    with open(os.path.join(bdir, "_manifest.json"), "w") as f:
        json.dump([{k: v for k, v in p.items() if k != "content"} for p in plan_rows],
                  f, indent=1, ensure_ascii=False)
    print("\n✓ 自检通过。备份: %s" % bdir)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--revert", metavar="DIR")
    args = ap.parse_args()

    if args.revert:
        src = os.path.join(args.revert, F_RECHARGE + ".xlsx")
        shutil.copy2(src, os.path.join(BASE, F_RECHARGE + ".xlsx"))
        print("还原 %s" % F_RECHARGE)
        return

    wb, ws, idx, changes, plan_rows, pure = plan()
    print_plan(plan_rows)
    ok, msgs = verify(plan_rows)
    print("\n预检:")
    for m in msgs:
        print("  " + m)
    if args.apply:
        print()
        do_apply(wb, ws, idx, changes, plan_rows)
    else:
        print("\n（dry-run，未写盘。加 --apply 落表）")


if __name__ == "__main__":
    main()
