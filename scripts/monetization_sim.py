#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
付费数值策划工作台（估值引擎 + 需求模型 + 回测 + 参数寻优）

⚠️ 前提声明（重要）：
    生产库 `m5_x1_game_10001` 只有 209 个玩家、且**没有真实付费流水**
    （无 recharge/order 集合，gameserver.log 中无可用的充值记录）。
    因此本工具做的是「**相对比较**」——在统一的估值口径下比较不同数值方案
    的收入结构、付费率与通胀贡献，**不输出"预计月流水 X 元"这种绝对预测**。
    所有行为参数均为行业先验，通过蒙特卡洛给出排序稳健性，而不是点估计。

核心口径：
    SKU 价值 = Σ(道具数 × 道具钻价)          ← 道具钻价来自 StoreConfig 官方钻石定价
    性价比   = SKU 价值 / (价格 × 10)        ← 相对直充（10 钻/元）的倍数
    需求     = logit(性价比, 绝对价格, 分段预算)
    通胀     = 单次购买发放的钻石 / 玩家免费日产出（380 钻/天，由 itemLog 实测）

用法：
    python scripts/monetization_sim.py                    # 回测当前表
    python scripts/monetization_sim.py --compare          # 对比 原始 / 当前改后 / 备选方案
    python scripts/monetization_sim.py --optimize         # 网格搜索最优参数
    python scripts/monetization_sim.py --sku-report       # 输出 SKU 估值明细
"""
import argparse
import collections
import json
import math
import os
import random
import statistics
import sys

try:
    import openpyxl
except ImportError:
    sys.exit("需要 openpyxl")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "data_execl", "base_data")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from backup_paths import sub as _bak_sub  # noqa: E402

# 改版前基准（备份在工程外，见 backup_paths.py）
BACKUP_ORIG = os.path.join(_bak_sub("_backup_before_monetize"), "20261020-205817")

DATA_START_ROW = 6

# 免费玩家钻石日产出：由 itemLog（reason 11/1011/1018 等）+ 每日任务 350 实测推算
FREE_DIAMOND_PER_DAY = 380

# 感知价值校准（见 value_of 注释）
PERCEIVED = 0.35      # 非钻石道具的感知折扣
DILUTE_CAP = 2.0      # 非钻石部分 ≤ 钻石部分 × 2
RATIO_CAP = 3.0       # 整包性价比上限（行业礼包折扣天花板）

# ───────────── 道具有效价值兜底表（钻/个），StoreConfig 提取失败时使用 ─────────────
FALLBACK_VALUE = {
    "16": 1.0,        # 钻石
    "14": 1 / 1200,   # 金钱      14#60000 = 50 钻
    "3": 1 / 240,     # 英雄经验  3#50000  = 250000 金钱 ≈ 208 钻
    "4": 1.0,         # 进化药剂  4#500    = 500 钻
    "19": 200.0,      # 紫晶卡    官方 250 / 实测成交 144 → 取 200
    "20": 300.0,      # 会员招募卡
    "87": 400.0,      # 命运招募卡
    "50007": 600.0,   # 限定招募卡
    "61": 120.0,      # 高级幸运币
    "60": 40.0,       # 幸运币
    "60403": 150.0,   # 珍稀材料自选箱
    "60402": 80.0,    # 稀有材料自选箱
    "60431": 120.0,   # 高级养成箱
    "60430": 60.0,    # 中级养成箱
    "60412": 130.0,   # 珍稀成长自选包
    "60411": 70.0,    # 稀有成长自选包
    "6000110": 2.0,   # 戒圈
    "50005": 90.0,    # 心愿石
    "6000115": 60.0,  # 仪式水晶
    "72001": 30.0,    # 超强合金
    "72003": 40.0,    # 超频矩阵
    "6000089": 150.0, # 超绝戒指
    "81148": 80.0,    # 5星精英英雄碎片
    "17014": 100.0,   # 铸神精华
    "17009": 60.0,    # 自选契约箱
    "17012": 90.0,    # 契约之魂
    "1004": 120.0,    # 愿望十字
    "1002": 100.0,    # 盲盒秘钥
    "6000094": 80.0,  # 通灵宝物
    "23": 60.0,       # 参赛券
    "80": 20.0,       # 情报线索
    "65": 0.2,        # 公会贡献
    "6000124": 0.0,   # GP（累计充值积分，非资产）
}


def load(name, base=BASE):
    path = os.path.join(base, name + ".xlsx")
    wb = openpyxl.load_workbook(path)
    ws = wb.worksheets[0]
    idx = {((c.value or "") if isinstance(c.value, str) else ""): i for i, c in enumerate(ws[1])}
    return wb, ws, idx


def iter_rows(ws):
    for r in range(DATA_START_ROW, ws.max_row + 1):
        v = [c.value for c in ws[r]]
        if not v or v[1] is None:
            continue
        yield r, v


def parse_reward(s):
    out = collections.Counter()
    for part in str(s or "").split("|"):
        if "#" in part:
            a = part.split("#")
            try:
                out[a[0]] += int(float(a[1]))
            except (ValueError, IndexError):
                pass
    return out


# ─────────────────────────── 估值引擎 ───────────────────────────

def build_item_values():
    """从 StoreConfig 的官方钻石定价反推每个道具的「钻/个」，中位数去极值。"""
    samples = collections.defaultdict(list)
    try:
        wb, ws, idx = load("StoreConfig")
    except Exception:
        return dict(FALLBACK_VALUE), {}
    c_goods = idx.get("Goods")
    c_cost = idx.get("Cost")
    c_prem = idx.get("PremiumType")
    if c_goods is None or c_cost is None:
        return dict(FALLBACK_VALUE), {}
    for r, v in iter_rows(ws):
        goods = str(v[c_goods] or "")
        cost = str(v[c_cost] or "")
        if "#" not in goods or "|" not in cost:
            continue
        gid, _, gqty = goods.partition("#")
        try:
            gqty = int(float(gqty))
        except ValueError:
            continue
        ctype, _, rest = cost.partition("|")
        if ctype != "16" or gid == "16":
            continue
        parts = rest.split("#")
        try:
            amount = float(parts[-1])
        except (ValueError, IndexError):
            continue
        if gqty <= 0 or amount <= 0:
            continue
        unit = amount / gqty
        if unit > 5000:      # 剔除明显异常（价格公式未展开等）
            continue
        samples[gid].append(unit)

    values, meta = dict(FALLBACK_VALUE), {}
    for gid, xs in samples.items():
        if len(xs) >= 2:
            med = statistics.median(xs)
            # 与兜底值偏离 3 倍以上视为公式未展开，保留兜底
            fb = FALLBACK_VALUE.get(gid)
            if fb is None or 0.33 <= med / fb <= 3.0:
                values[gid] = med
                meta[gid] = (len(xs), round(med, 3))
    return values, meta


ITEM_VALUE, ITEM_META = build_item_values()


def value_of(rewards, values=None):
    """奖励包 -> 玩家「感知价值」（钻等值）

    🔴 关键校准：不能直接用官方标价加总。
    礼包里动辄 3000 万金钱、200 万英雄经验，按 StoreConfig 单价折算是几万钻，
    会比礼包价格还高十几倍 —— 但玩家对这些可量产道具的感知价值远低于官方牌价。
    处理：
      1. 非钻石道具按 PERCEIVED 折扣计入（玩家知道这些能从游戏里刷）
      2. 非钻石部分不得高于钻石部分的 DILUTE_CAP 倍（防"钻石少道具多"的包虚高）
      3. 整包感知价值封顶 ratio 3.0（行业礼包折扣上限）
    """
    values = values or ITEM_VALUE
    dia = rewards.get("16", 0) * values.get("16", 1.0)
    other = 0.0
    for k, n in rewards.items():
        if k in ("16", "6000124"):
            continue
        v = values.get(k)
        if v is None:
            v = 50.0
        other += n * v
    other *= PERCEIVED

    if dia > 0:
        other = min(other, dia * DILUTE_CAP)
    total = dia + other
    return total, 0


# ─────────────────────────── SKU 评估 ───────────────────────────

class Sku(object):
    __slots__ = ("sid", "stype", "show", "price", "rewards", "value", "ratio",
                 "raw_ratio", "dia", "other_cnt", "limit", "first")

    def __init__(self, sid, stype, show, price, rewards, limit, first):
        self.sid, self.stype, self.show, self.price = sid, stype, show, price
        self.rewards = rewards
        self.limit = limit
        self.first = first
        self.value, _ = value_of(rewards)
        self.dia = rewards.get("16", 0)
        self.other_cnt = len([k for k in rewards if k not in ("16", "6000124")])
        raw = self.value / (price * 10.0) if price else 0.0
        self.ratio = min(raw, RATIO_CAP)
        self.raw_ratio = raw


def load_skus(base=BASE):
    wb, ws, idx = load("RechargeCommodityConfig", base)
    out = []
    for r, v in iter_rows(ws):
        price = v[idx["Price"]] or 0
        if price <= 0:
            continue
        rewards = parse_reward(v[idx["BaseReward"]])
        if not rewards:
            continue
        out.append(Sku(v[idx["Id"]], v[idx["Type"]], v[idx["ShowType"]], price,
                       rewards, v[idx["Limit"]] or 0, v[idx["FirstMultiple"]]))
    return out


# ─────────────────────────── 需求模型 ───────────────────────────

# 玩家分段（行业先验，非本作实测）
SEGMENTS = [
    # name,     占比,   单周期预算上限(元), 敏感性, 本期付费激活率, 说明
    ("free",    0.700, 0,    0.0,  0.00, "免费玩家，只买 0 元档"),
    ("minnow",  0.170, 30,   1.40, 0.25, "首充/月卡型，6-30 元"),
    ("dolphin", 0.085, 200,  1.15, 0.35, "小 R，98-198"),
    ("whale",   0.032, 800,  0.85, 0.45, "中 R，328-648"),
    ("kraken",  0.011, 5000, 0.55, 0.55, "鲸鱼，648+ 反复买"),
]

SHELF_VISIT = 0.55   # 每段玩家每周期访问某个货架的概率

P = {
    "u0": -4.40,         # 基准效用（校准到月付费率 3-6%、ARPPU 200-400 元量级）
    "ratio_w": 1.30,     # 性价比弹性（乘分段敏感度）
    "price_w": 0.35,     # 绝对价格阻力（log 尺度）
    "budget_pen": 2.40,  # 超预算惩罚
    # 选择过载（Iyengar & Lepper 2000）：选项越多，「不买」的相对效用越高。
    # 限时商市 163 格、128 元档 45 个内容完全一样的包 —— 正是这个效应的病理场景。
    "overload": 0.35,
}


def utility(sku, seg_budget, seg_sens, params=None):
    p = params or P
    r = max(sku.ratio, 0.05)
    return (p["u0"]
            + p["ratio_w"] * seg_sens * math.log(r)
            - p["price_w"] * math.log(1 + sku.price)
            - p["budget_pen"] * max(0.0, sku.price / max(seg_budget, 1) - 0.45))


def simulate(skus, pop=10000, params=None, dedupe=True):
    """货架选择模型：玩家按货架浏览，每个货架在「买其中一个 / 不买」之间做 softmax。

    🔴 dedupe=True（默认）：按 (价格, 奖励指纹) 去重后再算。
    因为「45 个 128 元 1,472 钻的包」在玩家眼里就是同一件商品摆了 45 遍，
    不是 45 个可选项。不去重会让「复制粘贴越多 = 收入越高」，与事实相反。
    """
    p = params or P
    shelves = collections.defaultdict(list)
    for s in skus:
        shelves[s.show].append(s)
    if dedupe:
        for show in shelves:
            seen, uniq = set(), []
            for s in shelves[show]:
                fp = (s.price, tuple(sorted(s.rewards.items())))
                if fp in seen:
                    continue
                seen.add(fp)
                uniq.append(s)
            shelves[show] = uniq

    revenue = 0.0
    buyers = 0.0
    diamonds_out = 0.0
    per_seg_rev, per_seg_buyers = collections.Counter(), collections.Counter()
    per_sku = collections.Counter()

    for name, share, budget, sens, activate, _ in SEGMENTS:
        n = pop * share
        if budget <= 0 or activate <= 0:
            continue
        n_act = n * activate
        seg_rev = 0.0
        p_no_pay = 1.0        # 该段「一次都不买」的累积概率
        for show, shelf in shelves.items():
            cands = [s for s in shelf if 0 < s.price <= budget * 1.15]
            if len(cands) < 2:
                continue
            visits = n_act * SHELF_VISIT
            us = [utility(s, budget, sens, p) for s in cands]
            none_u = p.get("overload", 0.35) * math.log(len(cands))   # 选择过载抬升「不买」效用
            m = max(us + [none_u])
            exps = [math.exp(u - m) for u in us] + [math.exp(none_u - m)]
            Z = sum(exps)
            p_none = exps[-1] / Z
            p_no_pay *= p_none
            for s, e in zip(cands, exps[:-1]):
                pr = e / Z
                if pr < 1e-6:
                    continue
                times = 1
                if s.limit == 0:
                    times = max(1, min(2, int(budget / s.price)))
                rev = visits * pr * times * s.price
                seg_rev += rev
                diamonds_out += visits * pr * times * s.dia
                per_sku[s.sid] += visits * pr * times
        per_seg_rev[name] = seg_rev
        per_seg_buyers[name] = n_act * (1.0 - p_no_pay)   # 「至少买一次」的人数
        revenue += seg_rev
        buyers += n_act * (1.0 - p_no_pay)

    pay_rate = min(buyers, pop) / pop if pop else 0
    arppu = revenue / buyers if buyers else 0
    arpu = revenue / pop if pop else 0
    dia_per_player = diamonds_out / pop if pop else 0
    return {
        "pay_rate": pay_rate,
        "arppu": arppu,
        "arpu": arpu,
        "revenue": revenue,
        "diamonds_per_player": dia_per_player,
        "inflation_days": dia_per_player / FREE_DIAMOND_PER_DAY,
        "seg_rev": per_seg_rev,
        "seg_buyers": per_seg_buyers,
        "top_skus": per_sku.most_common(8),
    }


# ─────────────────────────── 方案定义 ───────────────────────────

def scenario_baseline():
    """改版前（备份原件）"""
    return load_skus(BACKUP_ORIG)


def scenario_current():
    """当前工作区（R1-R6 已落表）"""
    return load_skus(BASE)


def rescale(skus, k):
    """按比例缩放礼包性价比（用于灵敏度/寻优）"""
    out = []
    for s in skus:
        if s.stype != 5:
            out.append(s)
            continue
        rw = collections.Counter(s.rewards)
        rw["16"] = int(round(rw.get("16", 0) * k))
        out.append(Sku(s.sid, s.stype, s.show, s.price, rw, s.limit, s.first))
    return out


def thin(skus, keep_per_tier=4, shows=(22, 23)):
    """每个（货架, 价格档）只保留性价比最高的 N 个 —— 模拟「下架重复礼包」

    这是"下架 vs 改造"的量化对照：货架越长，每个 SKU 的曝光概率越被摊薄
    （限时商市 163 格 / 128 元档 45 个内容完全一样的包）。
    """
    buckets = collections.defaultdict(list)
    out = []
    for s in skus:
        if s.show in shows and s.stype == 5:
            buckets[(s.show, s.price)].append(s)
        else:
            out.append(s)
    removed = 0
    for _, v in buckets.items():
        v.sort(key=lambda x: -x.ratio)
        out.extend(v[:keep_per_tier])
        removed += max(0, len(v) - keep_per_tier)
    return out, removed


def summarize(name, res):
    return "%-16s 付费率 %5.2f%%   ARPPU %7.1f   ARPU %6.2f   人均发钻 %7.0f (%.1f 天产出)" % (
        name, res["pay_rate"] * 100, res["arppu"], res["arpu"],
        res["diamonds_per_player"], res["inflation_days"])


def monte_carlo(skus_map, trials=400, seed=7):
    """在参数不确定下比较方案排序稳健性"""
    rnd = random.Random(seed)
    wins = collections.Counter()
    for _ in range(trials):
        p = {
            "u0": rnd.uniform(-5.6, -3.4),
            "ratio_w": rnd.uniform(0.85, 1.85),
            "price_w": rnd.uniform(0.22, 0.50),
            "budget_pen": rnd.uniform(1.5, 3.2),
        }
        best, best_rev = None, -1
        for nm, sk in skus_map.items():
            r = simulate(sk, pop=4000, params=p)["revenue"]
            if r > best_rev:
                best, best_rev = nm, r
        wins[best] += 1
    return wins


# ─────────────────────────── 主流程 ───────────────────────────

def print_sku_report(skus, top=25):
    print("【SKU 估值明细 · 按「钻等值/元」排序】")
    print("%-6s %-5s %-5s %6s %10s %10s %7s %s" % ("id", "type", "货架", "价格", "钻石", "总价值", "倍数", "内容"))
    ranked = sorted(skus, key=lambda s: -s.ratio)
    for s in ranked[:top]:
        content = ",".join("%s×%d" % (k, n) for k, n in list(s.rewards.items())[:3])
        print("%-6s %-5s %-5s %6d %10d %10.0f %7.2f %s" % (
            s.sid, s.stype, s.show, s.price, s.dia, s.value, s.ratio, content[:26]))
    print("…")
    for s in ranked[-6:]:
        content = ",".join("%s×%d" % (k, n) for k, n in list(s.rewards.items())[:3])
        print("%-6s %-5s %-5s %6d %10d %10.0f %7.2f %s" % (
            s.sid, s.stype, s.show, s.price, s.dia, s.value, s.ratio, content[:26]))

    pure = [s for s in skus if s.other_cnt == 0 and s.dia > 0]
    print("\n纯钻石（无任何其它内容）SKU: %d 个 / 有价 %d 个 = %.1f%%" % (
        len(pure), len(skus), 100.0 * len(pure) / max(len(skus), 1)))
    by_show = collections.Counter(s.show for s in pure)
    print("  按货架:", dict(by_show.most_common()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--compare", action="store_true")
    ap.add_argument("--optimize", action="store_true")
    ap.add_argument("--sku-report", action="store_true")
    ap.add_argument("--mc", type=int, default=0, help="蒙特卡洛次数")
    ap.add_argument("--shelves", action="store_true", help="下架 vs 改造对照")
    args = ap.parse_args()

    print("=" * 92)
    print("付费数值工作台 · 道具估值 %d 项（StoreConfig 反推 %d 项）· 免费日产出 %d 钻"
          % (len(ITEM_VALUE), len(ITEM_META), FREE_DIAMOND_PER_DAY))
    print("=" * 92)

    cur = scenario_current()

    if args.sku_report:
        print_sku_report(cur)
        return

    if args.compare or not (args.optimize or args.mc or args.shelves):
        base = scenario_baseline()
        print("\n【A. 改版前后对比】（同口径：道具有效价值 / 价格×10）")
        print(summarize("改版前(原始表)", simulate(base)))
        print(summarize("改版后(当前表)", simulate(cur)))
        vb = [s.ratio for s in base if s.price > 0]
        va = [s.ratio for s in cur if s.price > 0]
        print("  性价比中位数 %.2f → %.2f ；≤1.05（不划算）占比 %.1f%% → %.1f%%"
              % (statistics.median(vb), statistics.median(va),
                 100 * sum(1 for x in vb if x <= 1.05) / len(vb),
                 100 * sum(1 for x in va if x <= 1.05) / len(va)))

    if args.optimize:
        print("\n【B. 礼包加赠系数寻优】（Type5 整体缩放，其余不变）")
        print("%-8s %-10s %-10s %-10s %-10s" % ("k", "付费率", "ARPPU", "ARPU", "通胀(天)"))
        best = None
        for k in [1.0, 1.15, 1.3, 1.5, 1.75, 2.0, 2.4, 3.0]:
            r = simulate(rescale(cur, k))
            print("%-8.2f %-10.2f %-10.1f %-10.2f %-10.2f"
                  % (k, r["pay_rate"] * 100, r["arppu"], r["arpu"], r["inflation_days"]))
            # 目标：ARPU 最大化，同时通胀不超 30 天产出
            if r["inflation_days"] <= 30 and (best is None or r["arpu"] > best[1]):
                best = (k, r["arpu"])
        print("  → 在「人均通胀 ≤30 天免费产出」约束下，ARPU 最优 k = %s" % (best[0] if best else "无可行解"))

    if args.shelves:
        print("\n【D. 「下架 vs 改造」对照】")
        print("  限时商市(22) 163 格 / 珍奇宝阁(23) 123 格，按 (货架, 价格档) 只留性价比最高的 N 个")
        print("%-28s %6s %10s %10s %8s" % ("方案", "SKU数", "ARPU", "ARPPU", "付费率"))
        base_r = simulate(cur)
        print("%-28s %6d %10.2f %10.1f %7.2f%%" % ("改造后(现有货架)", len(cur), base_r["arpu"], base_r["arppu"], base_r["pay_rate"] * 100))
        for k in (8, 6, 4, 3, 2):
            th, rm = thin(cur, k)
            r = simulate(th)
            print("%-28s %6d %10.2f %10.1f %7.2f%%   (下架 %d)" % (
                "改造 + 瘦身(每档留 %d)" % k, len(th), r["arpu"], r["arppu"], r["pay_rate"] * 100, rm))
        raw = scenario_baseline()
        for k in (4, 2):
            th, rm = thin(raw, k)
            r = simulate(th)
            print("%-28s %6d %10.2f %10.1f %7.2f%%   (下架 %d)" % (
                "仅下架不改造(每档留 %d)" % k, len(th), r["arpu"], r["arppu"], r["pay_rate"] * 100, rm))

    if args.mc:
        print("\n【C. 蒙特卡洛排序稳健性】(%d 次参数扰动)" % args.mc)
        raw = scenario_baseline()
        th4, _ = thin(cur, 4)
        cand = {
            "改版前": raw,
            "只加数值(k=1.3)": rescale(raw, 1.3),
            "改造内容(当前)": cur,
            "改造+瘦身(留4)": th4,
        }
        wins = monte_carlo(cand, trials=args.mc)
        print("%-18s %10s" % ("方案", "胜出概率"))
        for nm, w in wins.most_common():
            print("  %-16s %9.1f%%" % (nm, 100.0 * w / args.mc))


if __name__ == "__main__":
    main()
