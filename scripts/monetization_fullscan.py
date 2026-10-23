#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""充值全量逐 SKU 扫描（只读）。

与 monetization_audit.py 的区别：那个看「档位中位/锚点」，这个看**每一个在售 SKU**，
回答「到底哪些礼包贵」。

用法：
    python3 scripts/monetization_fullscan.py              # 文本报告
    python3 scripts/monetization_fullscan.py --json x.json
    python3 scripts/monetization_fullscan.py --top 40

口径沿用 audit：抽等值 = 券(19/20/87/50007) + 钻石16/220。
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import statistics
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from monetization_audit import (  # noqa: E402
    DP_PER_PULL, TICKETS, load_skus, load_fund_totals, load_activity_tracks,
    sku_total_pull, live_skus, pull_value,
)


def yuan_per_pull(price, pull):
    return price / pull if pull > 0 else float("inf")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json")
    ap.add_argument("--top", type=int, default=25)
    args = ap.parse_args()

    skus, channels, cov = load_skus()
    funds = load_fund_totals()
    tracks, sku_to_act = load_activity_tracks()
    live = live_skus(skus)

    rows = []
    for s in live:
        pull = sku_total_pull(s, funds, tracks, sku_to_act)
        rows.append({
            "id": s["id"], "name": str(s["name"] or "")[:26], "price": s["price"],
            "type": s["type"], "show": s["show_type"], "limit": s["limit"],
            "pull": round(pull, 2), "ppy": round(yuan_per_pull(s["price"], pull), 3),
            "per_yuan": round(pull / s["price"], 4) if s["price"] else 0,
            "tickets": sum(s["base"].get(k, 0) + s["extra"].get(k, 0) for k in TICKETS),
            "diamond": s["base"].get("16", 0) + s["extra"].get("16", 0),
        })
    rows.sort(key=lambda r: (r["price"], r["per_yuan"]))

    # ── 价格分布
    by_price = collections.defaultdict(list)
    for r in rows:
        by_price[r["price"]].append(r)

    print("=" * 78)
    print("一、货架价格分布（在售 %d 个 SKU）" % len(rows))
    print("=" * 78)
    print("  %-6s %5s %8s %8s %8s %8s %8s" %
          ("价格", "SKU", "抽中位", "抽/元中位", "¥/抽中位", "抽/元最低", "抽/元最高"))
    total_pull_money = 0.0
    for p in sorted(by_price):
        g = by_price[p]
        med = statistics.median([x["per_yuan"] for x in g])
        medp = statistics.median([x["pull"] for x in g])
        print("  %-6s %5d %8.1f %8.3f %8.2f %8.3f %8.3f" %
              ("%d元" % p, len(g), medp, med, p / medp if medp else 0,
               min(x["per_yuan"] for x in g), max(x["per_yuan"] for x in g)))
        total_pull_money += p * len(g)

    n = len(rows)
    hi = [r for r in rows if r["price"] >= 198]
    mid = [r for r in rows if 68 <= r["price"] < 198]
    lo = [r for r in rows if r["price"] < 68]
    print("\n  结构：<68元 %d 个(%.1f%%) / 68–198 %d 个(%.1f%%) / ≥198元 %d 个(%.1f%%)" %
          (len(lo), 100.0 * len(lo) / n, len(mid), 100.0 * len(mid) / n,
           len(hi), 100.0 * len(hi) / n))
    print("  平均单价 %.0f 元 / 中位单价 %.0f 元" %
          (sum(r["price"] for r in rows) / n, statistics.median([r["price"] for r in rows])))

    # ── 同价劣值
    print("\n" + "=" * 78)
    print("二、同价劣值（同价位内，抽/元 低于本档中位 70% 的 SKU）")
    print("=" * 78)
    bad = []
    for p in sorted(by_price):
        g = by_price[p]
        if len(g) < 3:
            continue
        med = statistics.median([x["per_yuan"] for x in g])
        for x in g:
            if x["per_yuan"] < med * 0.70:
                bad.append((p, med, x))
    bad.sort(key=lambda t: t[2]["per_yuan"] / t[1])
    print("  共 %d 个" % len(bad))
    print("  %-7s %-26s %6s %7s %8s %8s %s" %
          ("id", "名称", "价格", "限购", "抽等值", "抽/元", "同档中位"))
    for p, med, x in bad[:args.top]:
        print("  %-7s %-26s %6d %7s %8.1f %8.3f %8.3f" %
              (x["id"], x["name"], x["price"], x["limit"], x["pull"], x["per_yuan"], med))

    # ── 绝对贵：¥/抽 最差
    print("\n" + "=" * 78)
    print("三、绝对最贵（¥/抽 最差的 %d 个，含内容空洞）" % args.top)
    print("=" * 78)
    worst = sorted(rows, key=lambda r: -r["ppy"])[:args.top]
    print("  %-7s %-26s %6s %8s %8s %7s %7s" %
          ("id", "名称", "价格", "抽等值", "¥/抽", "券", "钻"))
    for x in worst:
        print("  %-7s %-26s %6d %8.1f %8s %7d %7d" %
              (x["id"], x["name"], x["price"], x["pull"],
               ("%.2f" % x["ppy"]) if x["pull"] else "无券无钻", x["tickets"], x["diamond"]))

    # ── 空洞礼包
    empty = [r for r in rows if r["pull"] <= 0]
    print("\n  无券无钻的在售 SKU：%d 个" % len(empty))
    for x in sorted(empty, key=lambda r: -r["price"])[:15]:
        print("    %-7s %-26s %6d元 限购%s" % (x["id"], x["name"], x["price"], x["limit"]))

    # ── 限购1次的高价包（一次性，最容易被骂贵）
    oneshot = [r for r in rows if r["limit"] == 1 and r["price"] >= 128]
    print("\n  高价 + 限购1次（一次性，买错无补救）：%d 个" % len(oneshot))

    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump({"rows": rows, "bad": [x for _, _, x in bad]}, f,
                      ensure_ascii=False, indent=1)
        print("\n  JSON → %s" % args.json)


if __name__ == "__main__":
    main()
