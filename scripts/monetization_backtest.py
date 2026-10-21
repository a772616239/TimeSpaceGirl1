#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""付费设计回测台（多快照 A/B · 目标达成断言 · 套利探针 · 预算曲线）

为什么要有这个工具
────────────────────────────────────────────────────────────────
R7–R14 每一轮都是「改表 → 手工跑 audit → 肉眼看数字」，代价有三个：
  1) 旧值靠文档/记忆，改完没法一键回退再跑一遍，方案之间不可比；
  2) 每轮都要重新解释口径（抽等值 / 可售 / 组 / 中位），重复烧掉大量 token；
  3) 「设计有没有达到目的」没有可执行判据，只能"看着差不多"。
本工具把三件事固化：快照解析 → 同一口径取指标 → 目标逐条 PASS/FAIL →
多方案横向对比 → 预算曲线（玩家侧代价）。

⚠️ 口径声明（必须随结论一起引用）
   生产库 m5_x1_game_10001 只有 209 个玩家、**没有充值流水**（见 monetization_sim.py
   顶部的前提声明）。因此本工具做的是「**同一口径下的相对比较**」：
   改前 vs 改后、方案 A vs 方案 B，**不输出"预计月流水 X 元"这类绝对预测**。
   所有行为参数（预算、弹性）都是行业先验，不是本作实测。

快照（--at）支持三种来源
   work            当前工作区 data_execl/base_data
   <git rev>       任意提交，如 r10 / 0e4ababfb / HEAD~3
   <目录路径>      备份快照目录（只覆盖它里面有的表，其余用工作区补齐）

用法
   python scripts/monetization_backtest.py                  # 默认：orig/r10/r13/work 四方案
   python scripts/monetization_backtest.py --goals          # 只看目标达成度（当前表）
   python scripts/monetization_backtest.py --at work --at r13
   python scripts/monetization_backtest.py --arbitrage      # 套利/支配探针
   python scripts/monetization_backtest.py --budget         # 玩家预算曲线
   python scripts/monetization_backtest.py --json out.json  # 机器可读结果
"""
import argparse
import collections
import json
import os
import shutil
import statistics
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BASE = os.path.join(ROOT, "data_execl", "base_data")
CACHE_ROOT = os.path.join(ROOT, "_output", "backtest")
sys.path.insert(0, HERE)

import backup_paths as _bp          # noqa: E402
import monetization_audit as audit  # noqa: E402  复用取数口径，避免两套口径漂移


# ─────────────────────────── 快照解析 ───────────────────────────

# 回测要用到的表（少一张就会算错价值，但**不报错**，所以必须显式列 + 校验）
REQUIRED = (
    "RechargeCommodityConfig",   # SKU 全量
    "ChannelRechargeIdConfig",   # 计费点（能不能真的付钱）
    "LuxuryFund",                # 基金日领
    "ActivityRewardConfig",      # 活动轨道（成长基金的价值全在这）
    "GlobalActivity",            # SKU ↔ 活动 反查
    "LuckyCatConfig",            # 招财猫
    "MonthcardConfig",           # 月卡门槛
    "StoreConfig",               # 商店券价 / 道具钻价
    "BattlePassReward",          # 战令轨道
)

PRESETS = {
    "work": "work",
    "orig": _bp.sub("_backup_before_monetize") + "/20261020-205817",
    "r8": "7a4416851",     # 首充补钻 + 星级礼
    "r9": "4fada3bc5",     # 星级补券 + 月卡月限
    "r10": "45f44c91b",    # 价值带重建（单调阶梯）
    "r13": "0e4ababfb",    # 落差收窄 + 券价归位 + 328 拉平
    "r14": "HEAD",         # 档内削峰 + 招财猫
}

DEFAULT_PLAN = ("orig", "r10", "r13", "work")


def _slug(spec):
    return "".join(c if (c.isalnum() or c in "-_") else "_" for c in str(spec))[:60]


def _git_show_bytes(rev, relpath):
    p = subprocess.run(["git", "-C", ROOT, "show", "%s:%s" % (rev, relpath)],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return p.stdout if p.returncode == 0 and p.stdout else None


def materialize(spec):
    """把快照落成一个可直接被 audit.load() 使用的目录，返回 (目录, 覆盖了哪些表)。"""
    spec = PRESETS.get(spec, spec)

    if spec == "work" or os.path.abspath(str(spec)) == os.path.abspath(BASE):
        return BASE, ["(工作区全量)"]

    cache = os.path.join(CACHE_ROOT, _slug(spec))
    manifest = os.path.join(cache, "_overlay.json")
    if os.path.exists(manifest):
        with open(manifest, "r", encoding="utf-8") as f:
            return cache, json.load(f)

    if not (os.path.isdir(spec) or _git_show_bytes(spec, "README.md") is not None
            or _git_show_bytes(spec, "data_execl/base_data/RechargeCommodityConfig.xlsx")):
        sys.exit("找不到快照：%s（既不是目录，也不是含配置表的 git 提交）" % spec)

    if os.path.isdir(cache):
        shutil.rmtree(cache)
    os.makedirs(cache)

    # 1) 先用工作区所有表铺底（软链，几乎零成本）
    for fn in sorted(os.listdir(BASE)):
        if fn.endswith(".xlsx"):
            os.symlink(os.path.join(BASE, fn), os.path.join(cache, fn))

    overlaid = []
    if os.path.isdir(spec):
        # 2a) 备份目录：只覆盖它里面真实存在的表
        for fn in sorted(os.listdir(spec)):
            if not fn.endswith(".xlsx"):
                continue
            dst = os.path.join(cache, fn)
            if os.path.lexists(dst):
                os.unlink(dst)
            shutil.copy2(os.path.join(spec, fn), dst)
            overlaid.append(fn[:-5])
    else:
        # 2b) git 提交：按需从对象库取
        for name in REQUIRED:
            blob = _git_show_bytes(spec, "data_execl/base_data/%s.xlsx" % name)
            if blob is None:
                continue
            dst = os.path.join(cache, name + ".xlsx")
            if os.path.lexists(dst):
                os.unlink(dst)
            with open(dst, "wb") as f:
                f.write(blob)
            overlaid.append(name)

    with open(manifest, "w", encoding="utf-8") as f:
        json.dump(overlaid, f, ensure_ascii=False)
    return cache, overlaid


# ─────────────────────────── 取指标 ───────────────────────────

BUDGETS = (6, 12, 30, 68, 98, 198, 328, 648)


def measure(spec):
    """在指定快照上，用 audit 的口径算出一整套指标（纯数据，不打印）。"""
    base, overlaid = materialize(spec)
    missing = [t for t in REQUIRED if not os.path.exists(os.path.join(base, t + ".xlsx"))]
    if missing:
        sys.exit("快照 %s 缺表：%s" % (spec, missing))

    audit.BASE = base
    skus, _channels, _cov = audit.load_skus()
    funds = audit.load_fund_totals()
    tracks, sku_to_act = audit.load_activity_tracks()
    live = audit.live_skus(skus)

    rows = []
    for s in live:
        pull = audit.sku_total_pull(s, funds, tracks, sku_to_act)
        if s["price"]:
            rows.append({
                "id": s["id"], "price": s["price"], "type": s["type"],
                "show": s["show_type"], "name": s["name"], "limit": s["limit"],
                "pull": pull, "rate": pull / s["price"],
            })

    pack = [r for r in rows if r["type"] == 5]          # 直购礼包：可复购主力
    dia = [r for r in rows if r["type"] == 3]

    # ── 价格档中位（礼包带）──
    by_price = collections.defaultdict(list)
    for r in pack:
        by_price[r["price"]].append(r)
    tier = {p: (statistics.median([x["rate"] for x in xs]), len(xs))
            for p, xs in by_price.items()}

    # ── 同价离散（口径同 audit.E：Type=5，>=3 个才算）──
    disp = []
    for p, xs in by_price.items():
        if len(xs) < 3:
            continue
        rates = [x["rate"] for x in xs]
        lo, hi = min(rates), max(rates)
        if lo > 0:
            disp.append({"price": p, "spread": hi / lo, "lo": lo, "hi": hi, "n": len(xs)})
    disp.sort(key=lambda d: -d["spread"])

    # ── 同族倒挂（口径同 audit.D：同一 ShowType，相邻价格档中位下跌）──
    fam = collections.defaultdict(list)
    for r in rows:
        fam[r["show"]].append(r)
    inv = []
    for st, xs in fam.items():
        bp = collections.defaultdict(list)
        for r in xs:
            bp[r["price"]].append(r)
        prices = sorted(bp)
        med = {p: statistics.median([r["rate"] for r in bp[p]]) for p in prices}
        for a, b in zip(prices, prices[1:]):
            if med[b] < med[a] - 1e-9:
                inv.append({"show": st, "p1": a, "p2": b,
                            "drop": 1 - med[b] / med[a],
                            "r1": med[a], "r2": med[b]})
    inv.sort(key=lambda x: -x["drop"])

    # ── 同族累计跌幅（同一 ShowType 从最低价档到最高价档）──
    # 比「相邻档逐对比较」更贴近玩家感知：玩家问的是「买最大档比买最小档亏多少」
    fam_cum = []
    for st, xs in fam.items():
        bp = collections.defaultdict(list)
        for r in xs:
            bp[r["price"]].append(r["rate"])
        if len(bp) < 2:
            continue
        ps = sorted(bp)
        a, b = statistics.median(bp[ps[0]]), statistics.median(bp[ps[-1]])
        if a > 0:
            fam_cum.append({"show": st, "p1": ps[0], "p2": ps[-1],
                            "r1": a, "r2": b, "drop": 1 - b / a})
    fam_cum.sort(key=lambda x: -x["drop"])

    # ── 招财猫：期望 = (下限+上限)/2，服务端 random(ValueDown, ValueUp) ──
    cat = {}
    wb, ws = audit.load("LuckyCatConfig")
    for r in ws.iter_rows(min_row=8, values_only=True):
        if r[2] is None or r[5] is None:
            continue
        act, consume, up, down = r[2], float(r[5]), float(r[6] or 0), float(r[7] or 0)
        e = cat.setdefault(act, {"consume": 0.0, "up": 0.0, "down": 0.0, "rounds": 0})
        e["consume"] += consume
        e["up"] += up
        e["down"] += down
        e["rounds"] += 1
    wb.close()
    for e in cat.values():
        e["exp"] = (e["down"] + e["up"]) / 2.0
        e["up_x"] = e["up"] / e["consume"] if e["consume"] else 0
        e["exp_x"] = e["exp"] / e["consume"] if e["consume"] else 0
        e["down_x"] = e["down"] / e["consume"] if e["consume"] else 0

    # ── 月卡（真实形态是累充赠送）──
    cards = []
    wb, ws = audit.load("MonthcardConfig")
    for r in ws.iter_rows(min_row=8, values_only=True):
        if r[1] is None or not r[4] or not r[6]:
            continue
        total = audit.pull_value(audit.pairs(r[5])) * int(r[6])
        cards.append({"name": r[2], "gate": r[4], "pull": total,
                      "rate": total / float(r[4])})
    wb.close()

    # ── 商店券价（对照直抽 220 钻/抽）──
    shop = []
    wb, ws = audit.load("StoreConfig")
    hidx = audit.header_index(ws)
    for r in audit.iter_data(ws):
        g, c = r[hidx.get("Goods")], r[hidx.get("Cost")] if hidx.get("Cost") is not None else None
        if not g or not c or "#" not in str(g) or "|" not in str(c):
            continue
        gid, _, gq = str(g).partition("#")
        if gid not in audit.TICKETS:
            continue
        ctype, _, rest = str(c).partition("|")
        if ctype != audit.DIAMOND:
            continue
        try:
            amount = float(rest.split("#")[-1])
            qty = int(float(gq))
        except (ValueError, IndexError):
            continue
        if qty > 0 and amount > 0:
            shop.append({"item": gid, "qty": qty, "price": amount / qty})
    wb.close()

    anchors = {}
    for sid, label in audit.ANCHOR_SKUS.items():
        s = skus.get(sid)
        if not s or not s["price"]:
            continue
        tot = s["pull_first"] if sid == 1 else audit.sku_total_pull(s, funds, tracks, sku_to_act)
        if sid == 72001:
            wb, ws = audit.load("BattlePassReward")
            track = collections.Counter()
            for r in audit.iter_data(ws):
                if r[1] is not None:
                    track += audit.pairs(r[3])
            wb.close()
            tot += audit.pull_value(track)
        anchors[label] = {"price": s["price"], "pull": tot, "rate": tot / s["price"]}

    best_rate = max((x["rate"] for x in rows), default=0)

    # 覆盖标记：快照没含某张表时，对应指标是「拿工作区补齐算出来的」，
    # 不能当历史值用（否则会出现「改之前招财猫就已经 1.06x」这种假结论）
    ov = set(overlaid) if overlaid != ["(工作区全量)"] else set(REQUIRED)
    cov = {
        "sku": {"RechargeCommodityConfig", "ChannelRechargeIdConfig", "LuxuryFund",
                "ActivityRewardConfig", "GlobalActivity"} <= ov,
        "cat": "LuckyCatConfig" in ov,
        "shop": "StoreConfig" in ov,
        "cards": "MonthcardConfig" in ov,
    }
    return {
        "spec": str(spec), "overlaid": overlaid, "base": base, "cov": cov,
        "n_total": len(skus), "n_live": len(rows),
        "n_gated": sum(1 for s in skus.values() if s["gated"]),
        "n_pack": len(pack), "n_dia": len(dia),
        "rows": rows, "tier": tier, "disp": disp, "inv": inv, "fam_cum": fam_cum,
        "cat": cat, "cards": cards, "shop": shop, "anchors": anchors,
        "pack_mid": statistics.median([r["rate"] for r in pack]) if pack else 0,
        "best_rate": best_rate,
        "best": sorted(rows, key=lambda r: -r["rate"])[:5],
        "budget": budget_curve(rows, BUDGETS),
        "stacks": stacks({"rows": rows}),
    }


def budget_curve(rows, budgets):
    """玩家预算曲线：给定预算，按「抽/元」从高到低贪心买，算能买到多少抽。

    这是一条**玩家侧代价**指标（不是收入预测）：同一个 30 元玩家，改版前后
    能买到的抽数差多少。收紧太多会直接表现为差评/流失，是和「阶梯合理」对冲的代价。
    ⚠️ 它对**离群行极敏感** —— 谁家有一个 7 倍于同档的错价包，曲线就整段被它抬高。
    所以看这条曲线要配合 `print_tiers`（同档中位）一起看：中位没动 = 正常玩家没受损。
    """
    # 单次决策：礼包按限购（Limit=0 视为不限）各买 1 份；直充不限次
    pool = sorted(rows, key=lambda r: -r["rate"])
    out = {}
    for b in budgets:
        left, pulls, spend = float(b), 0.0, 0.0
        for r in pool:
            if r["rate"] <= 0 or r["price"] > left:
                continue
            if r["type"] == 3:
                n = int(left // r["price"])
            else:
                n = 1
            if n <= 0:
                continue
            left -= n * r["price"]
            spend += n * r["price"]
            pulls += n * r["pull"]
        out[b] = {"pulls": pulls, "spend": spend}
    return out


def stacks(m):
    """同一产品被拆成多个可同时购买的行 —— 「叠买倍数」。

    典型病理：成长基金 5 个 SKU（101–105）挂 5 个同期开放的活动（6/601–604），
    每个 Limit=1、每个都算满整套轨道 ⇒ 玩家能连买 5 次，等效把该产品的
    抽/元 复制 5 份。按 SKU 看每一条都合规，只有按「可购买组合」看才暴露。
    """
    grp = collections.defaultdict(list)
    for r in m["rows"]:
        grp[(r["show"], r["name"], r["price"])].append(r)
    out = []
    for (show, name, price), xs in grp.items():
        same = [x for x in xs if (x["limit"] or 0) > 0 or x["type"] == 3]
        if len(same) >= 2 and len(set(round(x["rate"], 6) for x in same)) == 1:
            out.append({"show": show, "name": name, "price": price,
                        "unit_rate": same[0]["rate"], "unit_pull": same[0]["pull"],
                        "mult": len(same),
                        "total_spend": price * len(same),
                        "total_pull": same[0]["pull"] * len(same),
                        "ids": [x["id"] for x in same]})
    # 按「单份抽/元」排 —— 设计问题是「最高价值的产品能被买几次」，
    # 不是「哪个产品的重复条目最多」（后者只是货架冗余，不改变单份性价比）
    out.sort(key=lambda x: (-x["unit_rate"], -x["mult"]))
    return out


# ─────────────────────────── 目标断言 ───────────────────────────

# 阈值说明放这里，改阈值必须同时改注释，否则下次没人知道为什么是这个数
LIM_DISP = 1.60      # 档内 max/min。券粒度 1 张 = 6 元档 16.7%，理论下限 ≈1.5
LIM_INV_DROP = 0.15  # 同族累计跌幅（最低价档 → 最高价档），<=15% 视为感知不出
LIM_INV_BIG = 3      # 相邻档跌幅 >10% 的处数上限
LIM_CAT_EXP = 1.15   # 招财猫期望倍数（返利口，不能当产出口）
LIM_CAT_UP = 1.20    # 招财猫上限倍数
LIM_TICKET = 220.0   # 商店单张券的钻价上限 = 直抽价
LIM_DOMINATE = 1.35  # 同档内最高值 / 中位，超过就是「只买这一个就够」


def _na(ok, value, cov, table=""):
    """覆盖不足时把指标标成 n/a，不计入达标率 —— 不允许用补齐的表冒充历史值。"""
    if cov:
        return value, ok
    return "n/a：快照缺 %s" % (table or "相关表"), None


def goals(m):
    out = []

    if m["cov"]["sku"]:
        worst = m["disp"][0] if m["disp"] else {"spread": 0, "price": 0}
        out.append(("G1 档内价值收敛", "同价档 max/min ≤ %.1fx" % LIM_DISP,
                    "%.2fx @ %d 元" % (worst["spread"], worst["price"]),
                    worst["spread"] <= LIM_DISP))

        cum = m["fam_cum"][0] if m["fam_cum"] else {"drop": 0, "show": 0, "p1": 0, "p2": 0}
        out.append(("G2 同族累计不亏", "最低→最高价档跌幅 ≤ %.0f%%" % (LIM_INV_DROP * 100),
                    "%.1f%%（ST%d %d→%d 元）" % (cum["drop"] * 100, cum["show"], cum["p1"], cum["p2"]),
                    cum["drop"] <= LIM_INV_DROP))

        big = sum(1 for x in m["inv"] if x["drop"] > 0.10)
        out.append(("G3 相邻档倒挂处数", "跌幅 >10%% 的处数 ≤ %d" % LIM_INV_BIG,
                    "%d 处（共 %d 处倒挂）" % (big, len(m["inv"])), big <= LIM_INV_BIG))
    else:
        out.append(("G1 档内价值收敛", "同价档 max/min ≤ %.1fx" % LIM_DISP, "n/a 快照缺 SKU 表", None))
        out.append(("G2 同族累计不亏", "跌幅 ≤ %.0f%%" % (LIM_INV_DROP * 100), "n/a", None))
        out.append(("G3 相邻档倒挂处数", "≤ %d 处" % LIM_INV_BIG, "n/a", None))

    if m["cat"]:
        ex = max(e["exp_x"] for e in m["cat"].values())
        up = max(e["up_x"] for e in m["cat"].values())
        v, ok = _na(ex <= LIM_CAT_EXP and up <= LIM_CAT_UP,
                    "期望 %.2fx / 上限 %.2fx" % (ex, up), m["cov"]["cat"], "LuckyCatConfig")
        out.append(("G4 招财猫返利", "期望 ≤ %.2fx 且上限 ≤ %.2fx" % (LIM_CAT_EXP, LIM_CAT_UP), v, ok))
    else:
        out.append(("G4 招财猫返利", "期望 ≤ %.2fx" % LIM_CAT_EXP, "n/a 无活动行", None))

    if m["shop"]:
        # 只对「与钻石直抽同池」的券 19 断言：LotterySetting Id=12 单抽 = 19#1|16#220，
        # 所以商店里的券 19 卖超过 220 钻就是「买券不如直接抽」。
        # 券 20/87/50007 是别的卡池（不消耗钻石），没有可比价，只能列为观察项。
        same_pool = [s for s in m["shop"] if s["item"] == "19"]
        other = [s for s in m["shop"] if s["item"] != "19"]
        bad = [s for s in same_pool if s["price"] > LIM_TICKET + 1e-6]
        worst = max((s["price"] for s in same_pool), default=0)
        note = ("；券%s 最高 %.0f 钻（异池，待确认）"
                % ("/".join(sorted({s["item"] for s in other})),
                   max(s["price"] for s in other))) if other else ""
        v, ok = _na(not bad, "券19 最贵 %.0f 钻（%d 个超价）%s" % (worst, len(bad), note),
                    m["cov"]["shop"] and bool(same_pool), "StoreConfig")
        out.append(("G5 同池券价不高于直抽", "券19 单张 ≤ %.0f 钻" % LIM_TICKET, v, ok))
    else:
        out.append(("G5 同池券价不高于直抽", "券19 单张 ≤ %.0f 钻" % LIM_TICKET, "n/a 无券售", None))

    card_rate = max((c["rate"] for c in m["cards"]), default=0)
    v, ok = _na(card_rate > 0 and m["best_rate"] <= card_rate * 1.001,
                "最高 %.3f vs 月卡 %.3f 抽/元" % (m["best_rate"], card_rate),
                m["cov"]["cards"] and m["cov"]["sku"], "MonthcardConfig/SKU")
    out.append(("G6 月卡仍是价值天花板", "任一非月卡 ≤ 月卡抽/元", v, ok))

    if m["cov"]["sku"] and m["tier"]:
        lo_p, hi_p = min(m["tier"]), max(m["tier"])
        lo_r, hi_r = m["tier"][lo_p][0], m["tier"][hi_p][0]
        out.append(("G7 买越多越值", "最高价档中位 ≥ 最低价档中位",
                    "%d 元 %.3f vs %d 元 %.3f" % (hi_p, hi_r, lo_p, lo_r), hi_r >= lo_r))
    else:
        out.append(("G7 买越多越值", "最高价档 ≥ 最低价档", "n/a", None))

    if m["cov"]["sku"]:
        dom, by_price = 0, collections.defaultdict(list)
        for r in m["rows"]:
            if r["type"] == 5:
                by_price[r["price"]].append(r["rate"])
        for p, rates in by_price.items():
            if len(rates) < 3:
                continue
            med = statistics.median(rates)
            if med > 0 and max(rates) / med > LIM_DOMINATE:
                dom += 1
        out.append(("G8 无单点支配", "同档最高 ≤ 中位 %.2fx" % LIM_DOMINATE,
                    "%d 个档位超标" % dom, dom == 0))
    else:
        out.append(("G8 无单点支配", "同档最高 ≤ 中位", "n/a", None))
    return out


# ─────────────────────────── 打印 ───────────────────────────

def hr(ch="─", n=96):
    print(ch * n)


def print_goals(m):
    gs = goals(m)
    lack = [k for k, v in m["cov"].items() if not v]
    print("目标达成度 · %s%s" % (m["spec"], ("   ⚠ 快照缺表：%s" % ",".join(lack)) if lack else ""))
    print("%-22s %-34s %-26s %s" % ("目标", "判据", "实测", "结论"))
    hr()
    for name, crit, val, ok in gs:
        verdict = "— n/a" if ok is None else ("✓ PASS" if ok else "✗ FAIL")
        print("%-22s %-34s %-26s %s" % (name, crit, val, verdict))
    n_ok = sum(1 for g in gs if g[3] is True)
    n_app = sum(1 for g in gs if g[3] is not None)
    hr()
    print("  合计 %d/%d 达标%s" % (n_ok, n_app,
                                  ("（%d 项因快照缺表不计）" % (len(gs) - n_app)) if n_app < len(gs) else ""))


def print_compare(ms):
    print("多方案横向对比（同一口径：抽等值 = 券张数 + 钻石/220）")
    hr()
    print("%-6s %-16s %5s %5s %7s %7s %7s %7s %6s %6s" % (
        "方案", "覆盖表", "可售", "礼包", "带中位", "6元档", "30元档", "648元档", "离散", "倒挂"))
    for m in ms:
        t = m["tier"] if m["cov"]["sku"] else {}
        cov = "工作区" if m["overlaid"] == ["(工作区全量)"] else "%d 张" % len(m["overlaid"])
        print("%-6s %-16s %5d %5d %7s %7s %7s %7s %6s %6s" % (
            m["spec"][:6], cov, m["n_live"], m["n_pack"],
            "%.3f" % m["pack_mid"] if t else "—",
            ("%.3f" % t[6][0]) if 6 in t else "—",
            ("%.3f" % t[30][0]) if 30 in t else "—",
            ("%.3f" % t[648][0]) if 648 in t else "—",
            ("%.1fx" % m["disp"][0]["spread"]) if t and m["disp"] else "—",
            ("%d处" % len(m["inv"])) if t else "—"))
    hr()
    print("  %-6s %-12s %-11s %-11s %-12s %s" % (
        "方案", "招财猫期望", "月卡抽/元", "最高抽/元", "礼包带/月卡", "同族累计跌幅"))
    for m in ms:
        ex = max((e["exp_x"] for e in m["cat"].values()), default=0)
        cr = max((c["rate"] for c in m["cards"]), default=0)
        cum = m["fam_cum"][0]["drop"] if m["fam_cum"] else 0
        print("  %-6s %-12s %-11s %-11s %-12s %s" % (
            m["spec"][:6],
            ("%.2f" % ex) if m["cov"]["cat"] else "—",
            ("%.3f" % cr) if m["cov"]["cards"] else "—",
            "%.3f" % m["best_rate"] if m["cov"]["sku"] else "—",
            ("%.0f%%" % (100 * m["pack_mid"] / cr)) if cr else "—",
            ("%.1f%%" % (cum * 100)) if m["cov"]["sku"] else "—"))
    hr()
    for m in ms:
        if m["overlaid"] != ["(工作区全量)"]:
            print("  %-6s 覆盖：%s" % (m["spec"][:6], ", ".join(m["overlaid"])))


def print_tiers(ms):
    """分档中位（正常玩家的选择）—— 和预算曲线的「最优路线」互补。

    预算曲线看最优选，会被离群行整段抬高；中位看的是「货架上摆得最多的那种包」，
    才是绝大多数玩家的真实体验。削峰有没有伤到正常玩家，只看这一张表。
    """
    print("分档中位（礼包带 Type=5，抽/元）—— 正常玩家视角，对离群行不敏感")
    hr()
    prices = sorted({p for m in ms if m["cov"]["sku"] for p in m["tier"]})
    print("%-8s %s" % ("价位", "  ".join("%-16s" % m["spec"][:6] for m in ms)))
    # 基准取「第一个真正覆盖了 SKU 表的快照」，否则 orig 那种缺表快照会让整列显示 +0.0%
    base = next((m for m in ms if m["cov"]["sku"]), None)
    for p in prices:
        cells = []
        for m in ms:
            if not m["cov"]["sku"] or p not in m["tier"]:
                cells.append("%-16s" % "—")
                continue
            v = m["tier"][p][0]
            b = base["tier"].get(p, (0,))[0] if base else 0
            d = (v / b - 1) * 100 if b else 0
            cells.append("%.4f %+6.1f%%" % (v, d))
        print("%-8s %s" % ("%d 元" % p, "  ".join("%-16s" % c for c in cells)))
    hr()


def print_stacks(m):
    """叠买倍数：同一产品被拆成 N 个可同时购买的行。"""
    print("叠买探针 · %s（同一产品拆成多个可同购行 = 把抽/元 复制 N 份）" % m["spec"])
    hr()
    ss = m["stacks"]
    if not ss:
        print("  无")
        return
    for x in ss[:8]:
        print("  ST%-4s %-10s %4d 元 ×%d  → 单份 %.3f 抽/元 × %d = 合计 %.0f 元 %.0f 抽（%.3f 抽/元）ids=%s"
              % (x["show"], x["name"], x["price"], x["mult"], x["unit_rate"], x["mult"],
                 x["total_spend"], x["total_pull"],
                 x["total_pull"] / x["total_spend"] if x["total_spend"] else 0,
                 ",".join(str(i) for i in x["ids"][:6])))
    hr()
    print("  → 这些条目单看每一条都合规（Limit=1），只有按「可购买组合」才看得出倍数；")
    print("    若本意是分期/分章节解锁，解锁条件必须在活动表里（OpenRules/ResetGrade），不能靠玩家自律。")


def dominance(m, budget=30):
    """同预算下「最优单包 / 该档中位」的倍数 —— 档内还剩多少可套利空间。

    不用「贪心装包」做分母：贪心会把预算切碎、末端剩零头，结果依赖遍历顺序，
    跨方案比不稳定。这里用「预算内最贵那一档的中位」当分母，口径固定、可比。
    """
    if not m["cov"]["sku"]:
        return None
    cand = [r["rate"] for r in m["rows"] if r["price"] <= budget]
    tiers = [p for p in m["tier"] if p <= budget]
    if not cand or not tiers:
        return None
    med = m["tier"][max(tiers)][0]
    return max(cand) / med if med else None


def print_budget(ms):
    print("玩家预算曲线（同一预算能买到多少抽 —— 这是「收紧」的直接代价，不是收入预测）")
    print("  「最优」= 按抽/元 贪心买（对离群行敏感）；末行「同档最优/中位」= 档内还剩多少可套利空间")
    hr()
    b0 = ms[0]
    print("%-8s %s" % ("预算", "  ".join("%-18s" % m["spec"][:6] for m in ms)))
    for b in BUDGETS:
        cells = []
        for m in ms:
            v = m["budget"].get(b, {"pulls": 0})
            base = b0["budget"].get(b, {"pulls": 0})["pulls"]
            d = (v["pulls"] / base - 1) * 100 if base else 0
            cells.append("%6.1f 抽 %+6.1f%%" % (v["pulls"], d))
        print("%-8s %s" % ("%d 元" % b, "  ".join("%-18s" % c for c in cells)))
    cells = []
    for m in ms:
        d = dominance(m, 30)
        cells.append("%-18s" % ("%.2fx" % d if d else "—"))
    print("%-8s %s" % ("同档最优/中位", "  ".join(cells)))
    hr()


def print_arbitrage(m):
    print("套利 / 支配探针 · %s" % m["spec"])
    hr()
    cr = max((c["rate"] for c in m["cards"]), default=0)
    ex = max((e["exp_x"] for e in m["cat"].values()), default=0)
    dia = [r for r in m["rows"] if r["type"] == 3]
    dia_best = max((r["rate"] for r in dia), default=0)
    routes = [
        ("月卡（累充赠送）", cr),
        ("礼包带中位", m["pack_mid"]),
        ("礼包带最高", max((r["rate"] for r in m["rows"] if r["type"] == 5), default=0)),
        ("直充钻石（最优档）", dia_best),
        ("直充 → 招财猫放大 %.2fx" % ex if ex else "直充 → 招财猫", dia_best * ex),
        ("全部 SKU 最高", m["best_rate"]),
    ]
    print("%-30s %10s %14s" % ("路线", "抽/元", "相对礼包带"))
    for name, rate in routes:
        print("%-30s %10.4f %13.1fx" % (name, rate, rate / m["pack_mid"] if m["pack_mid"] else 0))
    hr()
    if dia_best and ex:
        gain = dia_best * ex / dia_best - 1
        print("  → 招财猫只把钻石路线抬高 %.1f%%，放大后仍只有礼包带的 %.0f%%：" % (
            gain * 100, 100 * dia_best * ex / m["pack_mid"]) if m["pack_mid"] else "")
        print("    说明「返利倍数」本身不构成套利路线，真正的杠杆是钻石底价（直充 10 钻/元）。")
    over = [r for r in m["rows"] if cr and r["rate"] > cr * 1.001]
    print("  → 超过月卡抽/元的 SKU：%d 个%s" % (
        len(over), ("：" + ", ".join("%s(%.2f)" % (r["id"], r["rate"]) for r in over[:5])) if over else ""))


def print_detail(m):
    print("明细 · %s%s" % (m["spec"], "" if all(m["cov"].values()) else
                          "   ⚠ 缺表项已用工作区补齐，不可当历史值：%s"
                          % ",".join(k for k, v in m["cov"].items() if not v)))
    hr()
    print("  同价离散 Top5：%s" % (", ".join(
        "%d元 %.2fx(%.4f~%.4f,n=%d)" % (d["price"], d["spread"], d["lo"], d["hi"], d["n"])
        for d in m["disp"][:5]) or "无"))
    print("  同族倒挂 Top5：%s" % (", ".join(
        "ST%d %d→%d元 -%.1f%%" % (x["show"], x["p1"], x["p2"], x["drop"] * 100)
        for x in m["inv"][:5]) or "无"))
    if m["cat"]:
        print("  招财猫：%s" % (", ".join(
            "%d 满次 %.0f→期望 %.0f(%.2fx)" % (a, e["consume"], e["exp"], e["exp_x"])
            for a, e in sorted(m["cat"].items())) or "无"))
    print("  商店券价：%s" % (", ".join(
        "券%s @%.0f钻×%d档" % (k[0], k[1], n)
        for k, n in sorted(collections.Counter((s["item"], round(s["price"])) for s in m["shop"]).items(),
                           key=lambda x: (x[0][0], x[0][1]))) or "无"))
    print("  最高 5 个 SKU：%s" % (", ".join(
        "%s(%s元 %.3f)" % (r["id"], r["price"], r["rate"]) for r in m["best"]) or "无"))


# ─────────────────────────── 入口 ───────────────────────────

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--at", action="append", default=None,
                    help="快照：work / git rev / 备份目录。可重复")
    ap.add_argument("--goals", action="store_true", help="只看当前表的目标达成度")
    ap.add_argument("--compare", action="store_true", help="多方案横向对比（默认）")
    ap.add_argument("--budget", action="store_true", help="玩家预算曲线")
    ap.add_argument("--tiers", action="store_true", help="分档中位（正常玩家视角）")
    ap.add_argument("--stacks", action="store_true", help="叠买倍数探针")
    ap.add_argument("--arbitrage", action="store_true", help="套利/支配探针")
    ap.add_argument("--detail", action="store_true", help="明细 Top5")
    ap.add_argument("--json", default="", help="结果写 JSON")
    ap.add_argument("--keep", action="store_true", help="保留快照缓存目录")
    args = ap.parse_args()

    specs = args.at or list(DEFAULT_PLAN)
    cache_before = set(os.listdir(CACHE_ROOT)) if os.path.isdir(CACHE_ROOT) else set()

    ms = [measure(s) for s in specs]

    do_all = not (args.goals or args.budget or args.arbitrage or args.compare)
    hr("=")
    print("付费设计回测台 · %d 个方案 · 抽等值口径（券 + 钻石/220）· 无真实流水，只做相对比较" % len(ms))
    hr("=")

    if args.goals or do_all:
        for m in ([ms[-1]] if args.goals else ms):
            print_goals(m)
            print()
    if args.compare or do_all:
        print_compare(ms)
        print()
    if args.arbitrage:
        for m in ms[-1:]:
            print_arbitrage(m)
        print()
    if args.tiers or do_all:
        print_tiers(ms)
        print()
    if args.stacks:
        for m in ms[-1:]:
            print_stacks(m)
        print()
    if args.budget or do_all:
        print_budget(ms)
        print()
    if args.detail:
        for m in ms:
            print_detail(m)

    if args.json:
        os.makedirs(os.path.dirname(os.path.abspath(args.json)) or ".", exist_ok=True)
        slim = []
        for m in ms:
            x = {k: v for k, v in m.items() if k not in ("rows",)}
            x["goals"] = [{"name": n, "crit": c, "value": v, "pass": ok}
                          for n, c, v, ok in goals(m)]
            slim.append(x)
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(slim, f, ensure_ascii=False, indent=2, default=str)
        print("JSON → %s" % args.json)

    if not args.keep and os.path.isdir(CACHE_ROOT):
        for d in set(os.listdir(CACHE_ROOT)) - cache_before:
            shutil.rmtree(os.path.join(CACHE_ROOT, d), ignore_errors=True)
        if not os.listdir(CACHE_ROOT):
            os.rmdir(CACHE_ROOT)


if __name__ == "__main__":
    main()
