#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""数值迭代优化引擎（货币化价值带域）—— 把 R7→R16 的「改表→回测→看目标→再改」
从**人工肉眼看数**变成**可复跑的坐标下降**。

为什么要有这个工具
────────────────────────────────────────────────────────────────
R7-R16 每一轮的流程是同一套，但每次都要人做四件事：
  1) 从一堆指标里判断「这一轮该动哪里」（补谷？削峰？还是修倒挂）；
  2) 算每个 SKU 该补几张券（除不尽、一张券 = +65% 的低档要跳过）；
  3) 改完重新跑回测，靠肉眼看 8 个目标是不是都绿；
  4) 记住旧值，否则下一轮没法比、也没法回退。
本工具把这四件事固化成一个循环：**给一组设计旋钮 → 生成候选表 → 用同一口径度量
→ 打分 → 只保留更好的那一组 → 缩小步长再来一轮**。

三条不能碰的红线（写死在生成器与校验器里，不是"建议"）
────────────────────────────────────────────────────────────
  · `Price` / `Type` / `ShowType` / `OnSaleRule` / 计费点 一个字节都不动
    （计费点是按 SKU id 绑定的渠道商品，改价会让渠道金额与配置不符）；
  · 钻石(16) 数量不动（钻石是全局通货，加钻会同时通胀抽卡以外的一切系统）；
  · 非券道具构成不动 ⇒ 只允许改 `BaseReward` / `RewardShow` 里的**券**
    （19 紫晶卡 / 20 会员招募卡 / 87 命运招募卡 / 50007 限定招募卡）。

优化目标（J 越小越好，口径必须随结论一起引用）
────────────────────────────────────────────────────────────
    J = -1000×实际陡度 + 100×未达标目标数 + 20×价值带误差 + 60×倒挂深度
        + 40×离散超标 + 1000×新手带跌幅 + 1e4×通胀超限（硬约束）
  · 实际陡度：**表真的变陡了多少** = 最高价档相对父本的抬升 ÷ 最低价档相对父本
    的抬升 - 1。为什么不直接奖励旋钮里的 slope：旋钮不是结果，直接奖励会让
    「什么都不做」也拿满分。什么都不做 = 0 分；
  · 未达标目标数：`monetization_backtest.goals()` 的 8 条 PASS/FAIL 里 FAIL 的条数
    （n/a 不计 —— 快照缺表时那条本来就不该算分）；
  · 价值带误差：各价格档中位与**设计目标带**的相对偏差，按档内 SKU 数加权。
    目标带 = 单调化后的档位中位 × (1 + slope × 档位相对位置)：
    slope=0.10 表示「最高档要比最低档再甜 10%」。slope 只是"想去哪"，
    能不能到由通胀硬约束裁决；
  · 倒挂深度：同族相邻档中位下跌的幅度之和（8 处浅倒挂 5% = 0.40 当量）。
    这是连续量而不是布尔 —— G3 只数「跌幅 >10% 的处数」，达标了也可能还剩一堆浅倒挂；
  · 离散超标：同价档 max/min 超出 1.6x 的部分之和（G1 的连续版）；
  · 新手带跌幅：≤30 元档中位相对父本的最大跌幅。低价档 29/30 个都是 Limit=1 的
    拉新锚点，削它能把「陡度」刷上去，那是拿新玩家体验换指标 ⇒ 与陡度同权判罚；
  · 通胀超限：全表加权「抽/元」相对父本涨幅超过 MAX_INFL 的部分。**硬约束**：
    惩罚 1e4，任何陡度收益都抵不掉（软权重实测把 +9.3% 通胀判成"更优"，
    那正是 R7 烧掉两年数值空间的同一类错觉）。
  ⇒ 于是这个循环真正回答的问题是：**在 +5% 通胀预算内，价值带能推多陡、
    倒挂能压到多浅**。这比「再全表 +20%」是两码事。


⚠️ 前提没有变：生产库 209 玩家、无充值流水（见 monetization_sim.py 顶部）。
   本工具输出的是**同一口径下的相对比较**，不是「预计月流水」。

用法
────────────────────────────────────────────────────────────
    PY=/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python

    $PY scripts/numeric_optimize.py measure            # 当前表：8 目标 + 分档中位
    $PY scripts/numeric_optimize.py measure --json x.json
    $PY scripts/numeric_optimize.py search --rounds 6  # 迭代寻优（只读，产物在 _output/）
    $PY scripts/numeric_optimize.py search --rounds 3 --slope 0.2 --max-infl 0.03
    $PY scripts/numeric_optimize.py promote --run <run-id>                        # 体检，不写
    $PY scripts/numeric_optimize.py promote --run <run-id> --apply                # 落表（备份+回滚）
    $PY scripts/numeric_optimize.py ledger             # 历史轮次

    `search` **绝不写** base_data；落表只有一个入口 `promote --apply`。
"""
from __future__ import annotations

import argparse
import collections
import json
import os
import shutil
import statistics
import sys
import time

try:
    import openpyxl
except ImportError:
    sys.exit("需要 openpyxl：/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python")

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BASE_DIR = os.path.join(ROOT, "data_execl", "base_data")
STATE_DIR = os.path.join(ROOT, "data_execl", "numeric_opt")     # 账本/状态（入库）
RUN_ROOT = os.path.join(ROOT, "_output", "numeric_opt")          # 候选表（不入库）
sys.path.insert(0, HERE)

import monetization_audit as audit                      # noqa: E402
import monetization_backtest as BT                      # noqa: E402
from backup_paths import sub as bak_sub                 # noqa: E402
from monetization_ladder import (                       # noqa: E402
    DIA, TICKETS, add_items, fmt_pairs, header_index, parse_pairs, pick_ticket,
    pull_equiv,
)

F_RECHARGE = "RechargeCommodityConfig"
F_MONTHCARD = "MonthcardConfig"
PACK_TYPE = 5
DATA_ROW_START = 6

# ── 设计旋钮（搜索空间）──────────────────────────────────────────
# slope     价值带斜率：目标 = 档中位 × (1 + slope × 档位相对位置)。
#           0 = 现状即目标；0.3 = 最高档要比最低档甜 30%（真正被寻优的东西）
# gap       每轮吃掉的缺口比例：0.5 = 只走一半（保守迭代），1.0 = 一步到位
# cap_tol   削峰容忍：同档中位 ×(1+cap_tol) 以上的才削
# mono      是否把目标带做单调化（PAVA）：开 = 自动补掉凹陷档，关 = 保留档位原样
# cut       是否允许削峰（只能扣券，绝不扣钻石；有地板守卫）
KNOBS = {
    "slope": 0.00,      # 价值带斜率：高档该比低档甜多少
    "band_tol": 0.20,   # 收敛带下沿：低于 目标×(1-band_tol) 的算离群低值，要补
    "cap_tol": 0.20,    # 收敛带上沿：高于 目标×(1+cap_tol) 的算离群高值，要削
    "gap": 1.00,        # 每轮吃掉缺口比例（0.5 = 只走一半）
    "mono": True,
    "cut": True,
}
STEP = {"slope": 0.10, "band_tol": 0.05, "cap_tol": 0.05, "gap": 0.25}
STEP_FLOOR = {"slope": 0.01, "band_tol": 0.01, "cap_tol": 0.01, "gap": 0.05}

# ── 生成器闸门 ────────────────────────────────────────────────
# 一张券引起超过 15% 的跳变就不动这个 SKU：6 元档中位 1.5 抽，补 1 张 = +65%，
# 会把拉新锚点顶成全表最甜（ladder 的 PACK_MIN_TIER_PULL 闸门，同一件事）。
OVERSHOOT_TOL = 0.15
# 削峰地板：任何一刀不许把 SKU 削到「本档中位 -20%」以下
FLOOR_TOL = 0.20

# ── 打分权重（见文件头，改这里就等于改设计取向，务必同步文档）──────
W_STEEP = 1000.0   # 每 1% 实际陡度 = 10 分（掉 1 个目标 = 100 分 ⇒ 值 10% 陡度）
W_FAIL = 100.0
W_ERR = 20.0
W_INV = 60.0
W_DISP = 40.0
W_ANCHOR = 1000.0  # 新手带档中位每跌 1% = 10 分，等于陡度收益，别拿新玩家换指标
# 通胀是**硬约束**，不是可交易的权重：超了就直接判不可行（惩罚大到没有任何
# 陡度收益能抵消）。软权重会让「陡度 +20% 换通胀 +9%」被判优 —— 实测过一次，
# 那正是 R7 烧掉两年数值空间的同一类错觉。
W_INFEASIBLE = 1e4
MAX_INFL = 0.05          # 单轮：全表加权抽/元 相对父本允许的涨幅上限
# 跨轮累计上限。为什么必须有：每轮预算都是**相对当前父本**算的，不改的话
# 「每轮 +5%」会一路复利下去（跑十次 = +63%），而每次单看都在"预算内"。
CUM_INFL = 0.25
# 锚点 = 第一次跑这个 job 时的加权抽/元，之后**粘住不自动重置**：
# 落表后若自动重置，等于「每落一次表再送 25% 复利空间」，那就白设了这个闸。
# 想把它当新基准，必须人显式 `promote --apply --reanchor`（要对着设计复核过的版本才做）。
CUM_ANCHOR = None
LIM_DISP = 1.6           # 同价档 max/min 容忍（与 G1 同一判据）


# ─────────────────────────── 基础工具 ───────────────────────────

def _p(name):
    return os.path.join(BASE_DIR, name + ".xlsx")


def _now():
    return time.strftime("%Y%m%d-%H%M%S")


def _pairs_dict(text):
    return {k: (n or 0) for k, n in parse_pairs(text)}


def _reset_audit_base():
    """BT.measure() 会把 audit.BASE 指到临时快照目录；自己取数前必须切回工作区。"""
    audit.BASE = BASE_DIR


def load_packs():
    """可售 Type=5 礼包（有计费点 + 未门控 + Price>0）+ 可编辑字段定位。

    返回的 `pull` 与 audit 口径一致（= 券张数 + 钻石/220），因此「补 N 张券」
    对回测指标的影响是可精确预测的 +N 抽。
    """
    _reset_audit_base()
    skus, _ch, _cov = audit.load_skus()
    live = {s["id"] for s in audit.live_skus(skus) if s["type"] == PACK_TYPE}

    wb = openpyxl.load_workbook(_p(F_RECHARGE))
    ws = wb.active
    idx = header_index(ws)
    need = ("Id", "Type", "Price", "ShowType", "BaseReward", "ExtraReward", "RewardShow", "Name")
    lack = [k for k in need if k not in idx]
    if lack:
        wb.close()
        sys.exit("RechargeCommodityConfig 缺列：%s（表结构变了，先核对再改口径）" % lack)

    out = []
    for r in range(DATA_ROW_START, ws.max_row + 1):
        row = [c.value for c in ws[r]]
        if len(row) <= idx["Id"]:
            continue
        sid = row[idx["Id"]]
        if sid is None or sid not in live:
            continue
        if row[idx["Type"]] != PACK_TYPE:
            continue
        rewards = _pairs_dict(row[idx["BaseReward"]])
        for k, n in _pairs_dict(row[idx["ExtraReward"]]).items():
            rewards[k] = rewards.get(k, 0) + n
        out.append({
            "row": r,
            "id": sid,
            "name": row[idx["Name"]],
            "price": row[idx["Price"]] or 0,
            "show": row[idx["ShowType"]],
            "base": row[idx["BaseReward"]] or "",
            "showtext": row[idx["RewardShow"]] or "",
            "rewards": rewards,
            "pull": pull_equiv(rewards),
            "tickets": sum(rewards.get(k, 0) or 0 for k in TICKETS),
            "dia": rewards.get(DIA, 0) or 0,
        })
    wb.close()
    return out


def base_band(tier, mono=True):
    """把「各价格档中位抽/元」变成一条单调不减的基准带（PAVA 加权合并）。

    为什么不用 ladder 里那张 TARGET_CURVE：那是 R10 的设计稿，现在是 R16 之后的
    局面（整体已经 0.26~0.35）。从**父本自身**推基准带，迭代才是在改进现状，
    而不是把现状拽回三周前的稿子。真正的设计意图由 `slope_targets()` 叠上去。
    """
    prices = sorted(p for p, v in tier.items() if v[1] > 0 and v[0] > 0)
    if not prices:
        return {}
    vals = [tier[p][0] for p in prices]
    wts = [max(1, tier[p][1]) for p in prices]
    if mono:
        blocks = []      # [sum_w, sum_wv, count]
        for v, w in zip(vals, wts):
            blocks.append([w, v * w, 1])
            while len(blocks) > 1:
                a, b = blocks[-2], blocks[-1]
                if a[1] / a[0] <= b[1] / b[0] + 1e-12:
                    break
                blocks.pop()
                blocks.pop()
                blocks.append([a[0] + b[0], a[1] + b[1], a[2] + b[2]])
        vals = []
        for bw, bv, bc in blocks:
            vals.extend([bv / bw] * bc)
    return dict(zip(prices, vals))


def slope_targets(base, slope):
    """基准带 × (1 + slope × 档位相对位置) —— 这才是「设计目标」，slope 是寻优对象。"""
    if not base:
        return {}
    ps = sorted(base)
    lo, hi = ps[0], ps[-1]
    if hi <= lo:
        return dict(base)
    return {p: base[p] * (1.0 + slope * (p - lo) / float(hi - lo)) for p in ps}


def _cut_tickets(text, amount):
    """从奖励串里扣券（只认 TICKETS），返回 (新串, 实际扣掉张数)。"""
    pairs = parse_pairs(text)
    picked = sorted([(i, k, n) for i, (k, n) in enumerate(pairs) if k in TICKETS and n],
                    key=lambda t: -t[2])
    left = amount
    for i, k, n in picked:
        if left <= 0:
            break
        take = min(n, left)
        pairs[i] = (k, n - take)
        left -= take
    return fmt_pairs([(k, n) for k, n in pairs if not (k in TICKETS and not n)]), amount - left


# ─────────────────────────── 候选生成 ───────────────────────────

def plan_changes(packs, targets, knobs, ref):
    """把每个 SKU 拉进「目标带 ± tol」区间：低于下沿补券，高于上沿削峰，中间不动。

    为什么不是「低于档中位就补」：实测那样会把 473 个包全部推一遍，档中位被整体
    抬高、倒挂深度从 0.005 涨到 0.256、J 从 0.31 恶化到 15.43 —— 这不是优化，
    是把「收敛」误当成「抬全线」。只动带外的离群件，才既收敛离散又不改档位结构。

    🔴 单位陷阱（已踩过）：`monetization_backtest` 的 `m["tier"]` 存的是
    **抽/元（rate）**，而这里的 `pk["pull"]` 是**券张数**。把两者直接比较会让
    每个包都变成"离群高值"，生成器会把全表 473 个包的券全扣光
    （实测：加权抽/元 0.3178 → 0.0663，-79%）。所以统一在「抽」空间算，
    只有绝对偏差乘 `price` 换算。
    """
    changes, skipped = [], collections.Counter()
    band_tol = knobs["band_tol"]
    cap_tol = knobs["cap_tol"]
    for pk in packs:
        price, cur = pk["price"], pk["pull"]
        if cur <= 0:
            skipped["纯资源包（无券无钻，加券会改商品身份）"] += 1
            continue
        tgt_rate = targets.get(price)
        if tgt_rate is None:
            skipped["该价位不在 Type5 档位表里"] += 1
            continue
        tgt_pull = tgt_rate * price
        hi_pull = tgt_pull * (1 + cap_tol)
        # 两种动作分开判：
        #   推陡（目标比现状高 2% 以上）→ 把该档所有低于目标的件补上去，档中位才会跟着抬；
        #   收敛（目标≈现状）→ 只动落在 ±band_tol 之外的离群件，不许动结构。
        # 合成一条规则会把「收敛档内离散」误用成「抬全线」（实测 J 0.31→15.43）。
        ref_rate = ref.get(price, 0) or 0
        pushing = tgt_rate > ref_rate * 1.02
        lo_pull = tgt_pull if pushing else tgt_pull * (1 - band_tol)

        # ① 削峰：高于上沿才动，只扣券，扣到上沿为止（R14 的口径）
        if knobs["cut"] and cur > hi_pull:
            cut = int(round(min(cur - hi_pull, pk["tickets"])))
            if cut <= 0:
                skipped["削峰算下来不足 1 张券"] += 1
                continue
            new_base, got = _cut_tickets(pk["base"], cut)
            if got <= 0:
                skipped["券不在 BaseReward 里（在 ExtraReward，不能动）"] += 1
                continue
            new_show = pk["showtext"]
            if str(new_show).strip():
                new_show, _ = _cut_tickets(new_show, got)
            changes.append({"row": pk["row"], "id": pk["id"], "price": price,
                            "kind": "cut", "delta": -got, "pull_before": cur,
                            "pull_after": cur - got, "base": new_base, "show": new_show})
            continue

        # ② 补谷：低于下沿才补，补到目标（不是补到上沿）
        if cur >= lo_pull:
            skipped["在带内（不推陡时 ±%.0f%%）" % (band_tol * 100)] += 1
            continue
        need = (tgt_pull - cur) * knobs["gap"]
        add = int(round(need))
        if add < 1:
            skipped["缺口不足 1 张券"] += 1
            continue
        after = cur + add
        if after / price > tgt_rate * (1 + cap_tol):
            skipped["档位粗粒度（补 1 张会冲过上沿）"] += 1
            continue
        delta = {pick_ticket(pk["rewards"]): add}
        new_base = add_items(pk["base"], delta)
        new_show = pk["showtext"]
        if str(new_show).strip():
            new_show = add_items(new_show, delta)
        changes.append({"row": pk["row"], "id": pk["id"], "price": price,
                        "kind": "add", "delta": add, "pull_before": cur,
                        "pull_after": after, "base": new_base, "show": new_show})
    return changes, skipped


def build_candidate(run_dir, changes):
    """把候选写进**唯一一个**草稿目录并返回它（每轮原地覆盖，从不删除）。

    为什么要拷全量而不是只拷一张：`monetization_backtest.measure()` 用
    「目录里出现了哪些表」判断快照覆盖率，只放一张会让 G1/G2/G3/G7/G8 全变 n/a，
    于是打分永远看不到设计目标有没有达成（静默失真，比报错难查）。

    🔴 为什么不做「每个候选一个目录 + 用完删掉」：沙箱的批量删除闸门按**每轮累计
    文件数**算（阈值 50），40 个候选 × 9 张表 = 360 个文件，清理阶段会把进程直接
    干掉，而且**不留 traceback**（表现为「跑完第 4 轮就没了」，极难定位）。
    改成单草稿目录 + 只留赢家，整个搜索零删除。
    """
    d = os.path.join(run_dir, "scratch")
    os.makedirs(d, exist_ok=True)
    for name in BT.REQUIRED:
        src = _p(name)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(d, name + ".xlsx"))

    wb = openpyxl.load_workbook(os.path.join(d, F_RECHARGE + ".xlsx"))
    ws = wb.active
    idx = header_index(ws)
    for ch in changes:
        ws.cell(ch["row"], idx["BaseReward"] + 1).value = ch["base"]
        if str(ch["show"]).strip():
            ws.cell(ch["row"], idx["RewardShow"] + 1).value = ch["show"]
    wb.save(os.path.join(d, F_RECHARGE + ".xlsx"))
    wb.close()
    return d


# ─────────────────────────── 度量与打分 ───────────────────────────

def _install_materialize_bypass():
    """让 `monetization_backtest.measure()` 直接读候选目录，不走它的快照缓存。

    为什么必须绕开缓存（两个坑，都踩过）：
      1) 缓存键 = `_slug(路径)`，而 `_slug` 把路径**截断到 60 字符**、命中即返回旧
         缓存。候选目录同属一个 run、前缀相同 ⇒ 全部撞键 ⇒ 「147 个 SKU 改动」与
         「什么都不做」量出来一模一样（抽/元 都是 0.3178），搜索在拿同一张表比来比去，
         而且**不报错**；
      2) 想靠「每次先删缓存」绕过，会撞上沙箱的批量删除闸门（一次 rmtree 320 个
         软链）⇒ 整个搜索静默中断。
    候选目录本来就含全部 9 张必需表（覆盖率为全量），所以直接返回它即可。
    """
    if getattr(BT, "_no_cache_patched", False):
        return
    orig = BT.materialize

    def materialize(spec):
        d = str(spec)
        if os.path.isdir(d) and os.path.abspath(d).startswith(os.path.abspath(RUN_ROOT)):
            present = sorted(n[:-5] for n in os.listdir(d) if n.endswith(".xlsx"))
            if present:
                return d, present
        return orig(spec)

    BT.materialize = materialize
    BT._no_cache_patched = True


def measure_dir(d):
    """在候选目录上跑与工作区完全同口径的度量，返回 (metrics, goals)。"""
    _install_materialize_bypass()
    m = BT.measure(d)
    return m, BT.goals(m)


def weighted_rate(m):
    """全表加权「抽/元」= Σ抽 / Σ价（可售全部 SKU，不只礼包）。

    这是**通胀**的粗口径：同样的钱被换走多少抽。比「人均发钻」更稳
    （后者依赖 monetization_sim 的玩家行为先验，寻优里不该引入第二套假设）。
    """
    num = sum(r["pull"] for r in m["rows"])
    den = sum(r["price"] for r in m["rows"])
    return num / den if den else 0.0


def band_error(m, targets):
    """各价格档中位 vs 设计目标带的相对偏差，按档内 SKU 数加权。"""
    tot_w, acc = 0.0, 0.0
    for p, (med, n) in m["tier"].items():
        tgt = targets.get(p)
        if not tgt or n <= 0 or med <= 0:
            continue
        acc += n * abs(med - tgt) / tgt
        tot_w += n
    return acc / tot_w if tot_w else 0.0


def inv_depth(m):
    """倒挂深度之和：8 处浅倒挂（各 5%）算 0.40 当量，不是 0。

    G3 只数「跌幅 >10% 的处数」，所以它 PASS 之后还能剩一堆浅倒挂；
    寻优需要一个连续量，否则「已达标」就没有改进空间了。
    """
    return sum(max(0.0, x["drop"]) for x in m["inv"])


def disp_excess(m):
    """离散超标：同价档 max/min 超出 LIM_DISP 的部分之和（G1 的连续版）。"""
    return sum(max(0.0, d["spread"] - LIM_DISP) for d in m["disp"])


def achieved_steepness(m, ref):
    """实际达成的陡度：最高价档相对基线的抬升 ÷ 最低价档相对基线的抬升 - 1。

    为什么不直接奖励旋钮里的 slope：**旋钮不是结果**。直接奖励 knob 会让
    「什么都不做」也拿到斜率分（J 里 -1000×slope 与表格无关）。这里量的是
    「表真的变陡了多少」，什么都不做就是 0 分。
    """
    ps = sorted(p for p in m["tier"] if p in ref and ref[p] > 0 and m["tier"][p][0] > 0)
    if len(ps) < 2:
        return 0.0
    lo, hi = ps[0], ps[-1]
    r_lo = m["tier"][lo][0] / ref[lo]
    r_hi = m["tier"][hi][0] / ref[hi]
    if r_lo <= 0:
        return 0.0
    return r_hi / r_lo - 1.0


ANCHOR_MAX_PRICE = 30      # 「新手带」上限：这一带的档中位只许升不许降


def anchor_drop(m, ref):
    """≤30 元档的中位相对基线的最大跌幅（负数取 0）。

    低价档 29/30 个 SKU 都是 Limit=1 的拉新锚点（docs/付费价值带重建 第 3 节），
    削这些档能把「陡度」指标刷上去，但那是拿新玩家体验换指标 —— 直接判罚。
    """
    worst = 0.0
    for p, (med, _n) in m["tier"].items():
        if p > ANCHOR_MAX_PRICE or p not in ref or ref[p] <= 0:
            continue
        worst = max(worst, (ref[p] - med) / ref[p])
    return max(0.0, worst)


def score(m, gs, ref, targets, parent_rate):
    """ref = 父本各价格档中位（陡度与新手工带的参照系，不是 PAVA 平滑带）。"""
    fails = [g[0] for g in gs if g[3] is False]
    steep = achieved_steepness(m, ref)
    err = band_error(m, targets)
    idep = inv_depth(m)
    dexc = disp_excess(m)
    adrop = anchor_drop(m, ref)
    rate = weighted_rate(m)
    over = max(0.0, (rate / parent_rate - 1.0) - MAX_INFL) if parent_rate else 0.0
    cum_over = 0.0
    if CUM_ANCHOR:
        cum_over = max(0.0, rate / CUM_ANCHOR - 1.0 - CUM_INFL)
    j = (-W_STEEP * steep + W_FAIL * len(fails) + W_ERR * err
         + W_INV * idep + W_DISP * dexc + W_ANCHOR * adrop
         + W_INFEASIBLE * (over + cum_over))
    return {
        "J": round(j, 4),
        "fails": len(fails),
        "fail_names": fails,
        "steepness": round(steep, 5),
        "band_err": round(err, 5),
        "inv_depth": round(idep, 5),
        "disp_excess": round(dexc, 5),
        "anchor_drop": round(adrop, 5),
        "rate": round(rate, 5),
        "rate_ratio": round(rate / parent_rate, 5) if parent_rate else 1.0,
        "infl_over": round(over, 5),
        "cum_over": round(cum_over, 5),
    }


# ─────────────────────────── 输出 ───────────────────────────

def print_goals(gs, title):
    print("目标达成度 · %s" % title)
    print("%-24s %-38s %-30s %s" % ("目标", "判据", "实测", "结论"))
    print("─" * 110)
    for name, crit, val, ok in gs:
        verdict = "— n/a" if ok is None else ("✓ PASS" if ok else "✗ FAIL")
        print("%-24s %-38s %-30s %s" % (name, crit, val, verdict))
    n_ok = sum(1 for g in gs if g[3] is True)
    n_app = sum(1 for g in gs if g[3] is not None)
    print("─" * 110)
    print("  合计 %d/%d 达标" % (n_ok, n_app))


def print_tiers(m, targets=None):
    print("分档中位（Type=5 礼包，抽/元）")
    print("%-8s %6s %10s %12s %s" % ("价位", "SKU", "中位", "目标带", "偏差"))
    for p in sorted(m["tier"]):
        med, n = m["tier"][p]
        tgt = (targets or {}).get(p)
        dev = ("%+.1f%%" % (100 * (med - tgt) / tgt)) if tgt else "—"
        print("%-8s %6d %10.4f %12s %s" % (
            p, n, med, ("%.4f" % tgt) if tgt else "—", dev))


def write_report(path, ctx, rows, best, goals_final, m_final, changes):
    L = []
    L.append("# 数值迭代优化报告 · %s\n" % ctx["run"])
    L.append("> 域：货币化价值带（`RechargeCommodityConfig` Type=5 礼包）  ")
    L.append("> 生成：%s　工程 `%s`  \n" % (time.strftime("%Y-%m-%d %H:%M:%S"), ctx.get("head", "-")))
    L.append("## 0. 口径（必须随结论一起引用）\n")
    L.append("抽等值 = 券张数 + 钻石/220；可售 = 有计费点 + 未 `1#999#999` 门控 + Price>0。")
    L.append("生产库 209 玩家、无充值流水 ⇒ 这里只有**同口径相对比较**，不产出预计流水。\n")
    L.append("打分：`J = -1000×实际陡度 + 100×未达标目标数 + 20×价值带误差 + 60×倒挂深度 "
             "+ 40×离散超标 + 1000×新手带跌幅 + 1e4×通胀超限`；通胀是**硬约束**"
             "（上限为父本的 `+%.0f%%`）。\n" % (MAX_INFL * 100))
    L.append("## 1. 父本基线\n")
    for name, crit, val, ok in ctx["goals_parent"]:
        L.append("- %-22s %-34s **%s** → %s" % (
            name, crit, val, "n/a" if ok is None else ("PASS" if ok else "FAIL")))
    L.append("\n父本加权抽/元：**%.4f**\n" % ctx["rate_parent"])
    L.append("## 2. 迭代轨迹\n")
    L.append("| 轮 | slope | band | cap | gap | mono | cut | J | 陡度 | 未达标 | 带误差 | 倒挂 | 抽/元 | 相对父本 | 改动SKU |")
    L.append("|---:|---:|---:|---:|---:|:--:|:--:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for r in rows:
        k = r["knobs"]
        L.append("| %s | %.3f | %.2f | %.2f | %.2f | %s | %s | %.2f | %+.1f%% | %d | %.2f%% | %.3f | %.4f | %+.1f%% | %d |" % (
            r["tag"], k["slope"], k["band_tol"], k["cap_tol"], k["gap"],
            "Y" if k["mono"] else "n", "Y" if k["cut"] else "n", r["score"]["J"],
            r["score"]["steepness"] * 100, r["score"]["fails"],
            r["score"]["band_err"] * 100, r["score"]["inv_depth"],
            r["score"]["rate"], (r["score"]["rate_ratio"] - 1) * 100, r["n_changes"]))
    L.append("\n## 3. 最优方案\n")
    L.append("```\n%s\n```\n" % json.dumps(best["knobs"], ensure_ascii=False))
    L.append("未达标：%s\n" % ("（无）" if not best["score"]["fail_names"]
                              else "、".join(best["score"]["fail_names"])))
    for name, crit, val, ok in goals_final:
        L.append("- %-22s %-34s **%s** → %s" % (
            name, crit, val, "n/a" if ok is None else ("PASS" if ok else "FAIL")))
    L.append("\n## 4. 分档中位（最优方案 vs 目标带）\n")
    L.append("| ¥ | SKU | 中位 | 目标带 | 偏差 |")
    L.append("|---:|---:|---:|---:|---:|")
    targets = best["targets"]
    for p in sorted(m_final["tier"]):
        med, n = m_final["tier"][p]
        tgt = targets.get(p, med)
        L.append("| %d | %d | %.4f | %.4f | %+.1f%% |" % (p, n, med, tgt, 100 * (med - tgt) / tgt))
    L.append("\n## 5. 改动清单（%d 个 SKU）\n" % len(changes))
    if changes:
        L.append("| id | ¥ | 动作 | 券数 | 抽 改前→改后 |")
        L.append("|---:|---:|:--:|---:|---:|")
        for c in sorted(changes, key=lambda x: (-abs(x["delta"]), x["id"]))[:60]:
            L.append("| %d | %d | %s | %+d | %.2f → %.2f |" % (
                c["id"], c["price"], "削峰" if c["kind"] == "cut" else "补券",
                c["delta"], c["pull_before"], c["pull_after"]))
        if len(changes) > 60:
            L.append("\n（只列前 60 条，全量见 `changes.json`）")
    L.append("\n## 6. 下一步\n")
    L.append("- 落表：`numeric_optimize.py promote --run %s --apply`（不带 --apply 只体检）" % ctx["run"])
    L.append("- 落表后仍需 **导表 + 推表** 才生效（`TS-Table-Sync`；客户端走 git，服务端走 txt）")
    L.append("- 未达标项不是数值能修的（例如缺券种/产品线结构问题），要在报告里单列，别指望再跑一轮")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(L) + "\n")


def append_ledger(rec):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(os.path.join(STATE_DIR, "ledger.jsonl"), "a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    st = {}
    if os.path.exists(os.path.join(STATE_DIR, "state.json")):
        try:
            st = json.load(open(os.path.join(STATE_DIR, "state.json"), encoding="utf-8"))
        except (OSError, ValueError):
            st = {}
    st.update({"last_run": rec["run"], "best_knobs": rec["knobs"],
               "best_score": rec["score"], "at": rec["at"]})
    if rec.get("anchor_rate"):
        st.setdefault("anchor_rate", rec["anchor_rate"])
    with open(os.path.join(STATE_DIR, "state.json"), "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False, indent=2)


def set_anchor(rate):
    """人显式把当前加权抽/元立为新基准（累计预算从这一刻重新算）。

    只有 `promote --apply --reanchor` 会调它。别在落表成功时顺手调 —— 那等于
    每落一次表就再送 25% 复利空间，闸就形同没有。
    """
    p = os.path.join(STATE_DIR, "state.json")
    st = {}
    if os.path.exists(p):
        try:
            st = json.load(open(p, encoding="utf-8"))
        except (OSError, ValueError):
            st = {}
    old = st.get("anchor_rate")
    st["anchor_rate"] = round(rate, 5)
    st["reanchored_at"] = time.strftime("%Y%m%d-%H%M%S")
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(p, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False, indent=2)
    return old


# ─────────────────────────── 命令：measure ───────────────────────────

def cmd_measure(args):
    _reset_audit_base()
    m = BT.measure(args.at or "work")
    gs = BT.goals(m)
    print("=" * 110)
    print("当前表度量 · %s（可售 %d / 礼包 %d / 加权抽/元 %.4f）"
          % (m["spec"], m["n_live"], m["n_pack"], weighted_rate(m)))
    print("=" * 110)
    print_goals(gs, m["spec"])
    print()
    band = base_band(m["tier"], mono=True)
    print_tiers(m, band)
    sc = score(m, gs, {p: v[0] for p, v in m["tier"].items()}, band, weighted_rate(m))
    print("\nJ = %.2f（未达标 %d / 带误差 %.2f%% / 倒挂深度 %.3f / 离散超标 %.3f / 通胀 %+.1f%%）"
          % (sc["J"], sc["fails"], sc["band_err"] * 100, sc["inv_depth"],
             sc["disp_excess"], (sc["rate_ratio"] - 1) * 100))
    if args.json:
        out = {"spec": m["spec"], "rate": weighted_rate(m),
               "tier": {str(k): v for k, v in m["tier"].items()},
               "targets": {str(k): v for k, v in band.items()},
               "goals": [{"name": n, "crit": c, "value": v, "pass": ok} for n, c, v, ok in gs],
               "score": sc}
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=2)
        print("\n已写出 %s" % args.json)
    return 0


# ─────────────────────────── 命令：search ───────────────────────────

def _eval_knobs(knobs, packs, base, ref, parent_rate, run_dir, tag):
    targets = slope_targets(base, knobs["slope"])
    changes, skipped = plan_changes(packs, targets, knobs, ref)
    d = build_candidate(run_dir, changes)
    m, gs = measure_dir(d)
    sc = score(m, gs, ref, targets, parent_rate)
    return {"tag": tag, "knobs": dict(knobs), "score": sc, "n_changes": len(changes),
            "skipped": dict(skipped), "m": m, "gs": gs, "changes": changes,
            "dir": d, "targets": targets, "base": base, "ref": ref}


def save_best(run_dir, r):
    """把赢家固化到 best/。

    🔴 不能直接拷草稿目录：草稿是**所有候选共用**的，等搜索结束它装的是最后一个
    被评估的候选（实测存出来和基线一模一样）。这里用 `changes` **确定性重建**一遍，
    保证 best/ 与打分时那张表逐字节一致；顺带避开「种子本身就是最优 ⇒ 全程没有
    「改进」事件 ⇒ 根本没存过」这个更隐蔽的坑（第二轮验收就是死在这里）。
    """
    d = os.path.join(run_dir, "best")
    os.makedirs(d, exist_ok=True)
    scratch = build_candidate(run_dir, r["changes"])
    shutil.copy2(os.path.join(scratch, F_RECHARGE + ".xlsx"),
                 os.path.join(d, F_RECHARGE + ".xlsx"))
    with open(os.path.join(d, "changes.json"), "w", encoding="utf-8") as f:
        json.dump(r["changes"], f, ensure_ascii=False, indent=2)


def cmd_search(args):
    global CUM_ANCHOR
    seed = dict(KNOBS)
    state = os.path.join(STATE_DIR, "state.json")
    if not args.reset and os.path.exists(state):
        try:
            prev = json.load(open(state, encoding="utf-8")).get("best_knobs") or {}
            seed.update({k: prev[k] for k in seed if k in prev})
            print("（沿用上次最优旋钮：%s）" % json.dumps(seed, ensure_ascii=False))
        except (OSError, ValueError):
            pass
    for k, v in (("slope", args.slope), ("band_tol", args.band_tol),
                 ("cap_tol", args.cap_tol), ("gap", args.gap)):
        if v is not None:
            seed[k] = v
    if args.cut is not None:
        seed["cut"] = args.cut
    if args.mono is not None:
        seed["mono"] = args.mono

    run = args.run_id or ("opt-" + _now())
    run_dir = os.path.join(RUN_ROOT, run)
    os.makedirs(run_dir, exist_ok=True)
    # 同 run-id 重跑时先清掉旧赢家，否则「本轮无可改进」也可能被 promote 拿到旧表。
    for stale in (os.path.join(run_dir, "best", F_RECHARGE + ".xlsx"),
                  os.path.join(run_dir, "best", "changes.json"),
                  os.path.join(run_dir, "no-improvement.flag")):
        if os.path.exists(stale):
            os.remove(stale)

    # 父本：工作区（不算候选，只为拿到 baseline 目标与通胀基准）
    _reset_audit_base()
    m_parent = BT.measure("work")
    gs_parent = BT.goals(m_parent)
    rate_parent = weighted_rate(m_parent)
    try:
        prev_state = json.load(open(state, encoding="utf-8")) if os.path.exists(state) else {}
    except (OSError, ValueError):
        prev_state = {}
    CUM_ANCHOR = prev_state.get("anchor_rate") or rate_parent
    print("=" * 110)
    print("父本：可售 %d / 礼包 %d / 加权抽/元 %.4f / 未达标 %d 条"
          % (m_parent["n_live"], m_parent["n_pack"], rate_parent,
             sum(1 for g in gs_parent if g[3] is False)))
    print("=" * 110)
    print_goals(gs_parent, "父本（工作区）")
    print()

    base = base_band(m_parent["tier"], mono=seed["mono"])
    ref = {p: v[0] for p, v in m_parent["tier"].items()}   # 父本档中位（抽/元）
    print("基准带（%s）：%s" % ("单调化 PAVA" if seed["mono"] else "保留档位原样",
                            " ".join("%d:%.3f" % (p, base[p]) for p in sorted(base))))
    print("目标带 = 基准带 × (1 + slope × 档位相对位置)；通胀预算 +%.0f%%，slope 就是本轮要寻的那个「陡度」\n"
          % (MAX_INFL * 100))

    # 「什么都不做」的分数：所有分数都跟它比。候选必须**严格更好**才值得落表，
    # 否则这一轮就该报「无需改动」——一个只会加数值的 job 比没有 job 更危险。
    j_nothing = score(m_parent, gs_parent, ref, base, rate_parent)["J"]
    cum_head = rate_parent / CUM_ANCHOR - 1.0 if CUM_ANCHOR else 0.0
    print("累计通胀锚点 %.4f（粘住的首次基准，不随落表自动重置）→ 当前 %+.1f%%，头寸 %.0f%%"
          % (CUM_ANCHOR, cum_head * 100, CUM_INFL * 100))
    print("什么都不做：J=%.2f（这就是本轮候选必须超过的门槛）\n" % j_nothing)

    rows, cache = [], {}
    budget = args.budget or (args.rounds * 10 + 1)

    def ev(knobs, tag):
        # 一样的旋钮不重复算（坐标下降里上下邻域会撞回来）
        key = json.dumps(knobs, sort_keys=True)
        if key in cache:
            return cache[key]
        if len(cache) >= budget:
            return None
        r = _eval_knobs(knobs, packs, base, ref, rate_parent, run_dir, tag)
        cache[key] = r
        s = r["score"]
        print("  [%-7s] slope=%.3f band=%.2f cap=%.2f gap=%.2f %s%s J=%9.2f 未达标=%d "
              "带误差=%5.2f%% 倒挂深度=%.3f 抽/元=%.4f(%+.1f%%) 改动=%d"
              % (tag, knobs["slope"], knobs["band_tol"], knobs["cap_tol"], knobs["gap"],
                 "mono" if knobs["mono"] else "----", " cut" if knobs["cut"] else "    ",
                 s["J"], s["fails"], s["band_err"] * 100, s["inv_depth"], s["rate"],
                 (s["rate_ratio"] - 1) * 100, r["n_changes"]))
        if s["infl_over"] > 0:
            print("           🔴 通胀超出预算 %.2f%%（硬约束，不可行）" % (s["infl_over"] * 100))
        if s["fail_names"]:
            print("           未达标：%s" % "、".join(s["fail_names"]))
        rows.append({"tag": tag, "knobs": dict(knobs), "score": s,
                     "n_changes": r["n_changes"]})
        return r

    packs = load_packs()
    print("可售 Type=5 礼包 %d 个（生成器只看这一批，其它产品线一行不碰）\n" % len(packs))

    best = ev(seed, "r00")
    if best is None:
        sys.exit("无法评估初始旋钮")
    step = {k: (args.step * STEP[k] / STEP["slope"] if args.step else STEP[k]) for k in STEP}

    for rnd in range(1, args.rounds + 1):
        improved = False
        cands = []
        for k in ("slope", "band_tol", "cap_tol", "gap"):
            for sign in (+1, -1):
                kn = dict(best["knobs"])
                kn[k] = round(kn[k] + sign * step[k], 4)
                if kn[k] <= 0:
                    continue
                if k == "gap" and kn[k] > 1.0:
                    continue
                cands.append(("r%02d%s%s" % (rnd, k[0], "p" if sign > 0 else "m"), kn))
        for k in ("mono", "cut"):
            kn = dict(best["knobs"])
            kn[k] = not kn[k]
            cands.append(("r%02d%s" % (rnd, k[0]), kn))

        for tag, kn in cands:
            r = ev(kn, tag)
            if r and r["score"]["J"] < best["score"]["J"] - 1e-9:
                best, improved = r, True

        if improved:
            print("  → 第 %d 轮改进，J 降到 %.2f（%s）\n"
                  % (rnd, best["score"]["J"], json.dumps(best["knobs"], ensure_ascii=False)))
        else:
            for k in step:
                step[k] *= 0.5
            print("  → 第 %d 轮无改进，步长减半：%s\n"
                  % (rnd, {k: round(v, 4) for k, v in step.items()}))
            if all(step[k] <= STEP_FLOOR[k] for k in step):
                print("  步长已到底，提前收工\n")
                break

    improved_enough = best["score"]["J"] < j_nothing - 1e-9

    ctx = {"run": run, "head": os.popen("git -C %s rev-parse --short HEAD" % ROOT).read().strip(),
           "goals_parent": gs_parent, "rate_parent": rate_parent}
    if not improved_enough:
        with open(os.path.join(run_dir, "no-improvement.flag"), "w", encoding="utf-8") as f:
            f.write("本轮没有任何候选优于「什么都不做」\n")
        with open(os.path.join(run_dir, "report.md"), "w", encoding="utf-8") as f:
            f.write("# 数值迭代优化 · %s\n\n**本轮没有可改进的方案。**\n\n"
                    "- 什么都不做 J=%.2f（未达标 %d 条、倒挂深度 %.3f、离散超标 %.3f）\n"
                    "- 最好候选 J=%.2f（陡度 %+.2f%%、未达标 %d 条）\n\n"
                    "说明当前价值带已经在「目标达成 + 通胀预算」的约束内接近最优，"
                    "再动只会把通胀推上去。这不是失败，是**结论**。\n"
                    % (run, j_nothing, sum(1 for g in gs_parent if g[3] is False),
                       inv_depth(m_parent), disp_excess(m_parent),
                       best["score"]["J"], best["score"]["steepness"] * 100,
                       best["score"]["fails"]))
        append_ledger({"run": run, "at": time.strftime("%Y-%m-%dT%H:%M:%S"),
                       "knobs": best["knobs"], "score": best["score"],
                       "parent_rate": round(rate_parent, 5), "n_changes": 0,
                       "rounds": len(rows), "note": args.note or "无改进",
                       "anchor_rate": round(CUM_ANCHOR, 5)})
        print("=" * 110)
        print("无可改进：什么都不做 J=%.2f，最好候选 J=%.2f（陡度 %+.2f%%）"
              % (j_nothing, best["score"]["J"], best["score"]["steepness"] * 100))
        print("报告：%s/report.md" % run_dir)
        print("=" * 110)
        return 4

    save_best(run_dir, best)
    # 用草稿目录度量到的那份（best/ 里只留一张表，覆盖率会掉，不能直接量它）
    m_final, gs_final = best["m"], best["gs"]

    write_report(os.path.join(run_dir, "report.md"), ctx, rows, best, gs_final, m_final,
                 best["changes"])
    with open(os.path.join(run_dir, "metrics.json"), "w", encoding="utf-8") as f:
        json.dump({
            "run": run, "parent": {"rate": rate_parent,
                                   "fails": [g[0] for g in gs_parent if g[3] is False]},
            "best": {"knobs": best["knobs"], "score": best["score"],
                     "n_changes": best["n_changes"], "skipped": best["skipped"]},
            "rounds": rows,
            "tier_final": {str(k): v for k, v in m_final["tier"].items()},
            "targets": {str(k): v for k, v in best["targets"].items()},
            "goals_final": [{"name": n, "crit": c, "value": v, "pass": ok}
                            for n, c, v, ok in gs_final],
        }, f, ensure_ascii=False, indent=2)

    append_ledger({"run": run, "at": time.strftime("%Y-%m-%dT%H:%M:%S"),
                   "knobs": best["knobs"], "score": best["score"],
                   "parent_rate": round(rate_parent, 5), "n_changes": best["n_changes"],
                   "rounds": len(rows), "note": args.note,
                   "anchor_rate": round(CUM_ANCHOR, 5)})

    print("=" * 110)
    print("最优旋钮：%s" % json.dumps(best["knobs"], ensure_ascii=False))
    print("父本 J=%.2f（未达标 %d）→ 最优 J=%.2f（未达标 %d）  加权抽/元 %.4f → %.4f (%+.1f%%)"
          % (j_nothing,
             sum(1 for g in gs_parent if g[3] is False),
             best["score"]["J"], best["score"]["fails"], rate_parent,
             best["score"]["rate"], (best["score"]["rate_ratio"] - 1) * 100))
    print("=" * 110)
    print_goals(gs_final, "最优方案")
    print()
    print("产物：%s" % run_dir)
    print("      report.md / metrics.json / best/%s.xlsx / best/changes.json" % F_RECHARGE)
    print("落表：numeric_optimize.py promote --run %s --apply（不带 --apply 只体检）" % run)
    return 0


# ─────────────────────────── 不变式校验 ───────────────────────────

IMMUTABLE = ("Id", "Type", "Price", "ShowType", "OnSaleRule", "Time", "Limit")


def diff_check(old_path, new_path):
    """逐行逐列比对：只允许 BaseReward / RewardShow 变，且只允许券数变。"""
    problems = []
    wb_a = openpyxl.load_workbook(old_path)
    ws_a = wb_a.active
    wb_b = openpyxl.load_workbook(new_path)
    ws_b = wb_b.active
    ia, ib = header_index(ws_a), header_index(ws_b)
    if ia != ib:
        problems.append("表头变了（列集合不同）")
    if ws_a.max_row != ws_b.max_row:
        problems.append("行数变了：%d → %d" % (ws_a.max_row, ws_b.max_row))

    allowed = {"BaseReward", "RewardShow"}
    n_changed = 0
    for r in range(1, min(ws_a.max_row, ws_b.max_row) + 1):
        ra = [c.value for c in ws_a[r]]
        rb = [c.value for c in ws_b[r]]
        for col, i in ia.items():
            va = ra[i] if i < len(ra) else None
            vb = rb[i] if i < len(rb) else None
            if va == vb:
                continue
            if col in allowed:
                continue
            problems.append("第 %d 行 %s 被改：%r → %r（禁止）" % (r, col, va, vb))
            if len(problems) > 20:
                break
        if r < DATA_ROW_START:
            continue
        pa = _pairs_dict(ra[ia["BaseReward"]])
        pb = _pairs_dict(rb[ib["BaseReward"]])
        for k in set(pa) | set(pb):
            if pa.get(k, 0) == pb.get(k, 0):
                continue
            if k not in TICKETS:
                problems.append("第 %d 行道具 %s 数量变了：%s → %s（只允许改券）"
                                % (r, k, pa.get(k, 0), pb.get(k, 0)))
        if ra[ia["BaseReward"]] != rb[ib["BaseReward"]]:
            n_changed += 1
        if len(problems) > 20:
            break
    wb_a.close()
    wb_b.close()
    return problems, n_changed


# ─────────────────────────── 命令：promote ───────────────────────────

def cmd_promote(args):
    run_dir = os.path.join(RUN_ROOT, args.run)
    if os.path.exists(os.path.join(run_dir, "no-improvement.flag")):
        sys.exit("这个 run 的结论是「无可改进」，没有可落表的候选（见 %s/report.md）" % run_dir)
    cand = os.path.join(run_dir, "best", F_RECHARGE + ".xlsx")
    if not os.path.exists(cand):
        sys.exit("找不到候选表：%s（先跑 search）" % cand)

    problems, n_changed = diff_check(_p(F_RECHARGE), cand)
    print("不变式校验：改动 SKU %d 个" % n_changed)
    if problems:
        print("🔴 有 %d 处越界改动，拒绝落表：" % len(problems))
        for p in problems[:20]:
            print("   - " + p)
        return 2
    print("   ✓ Price/Type/ShowType/OnSaleRule/计费点/非券道具 全部未变")

    _reset_audit_base()
    m_before = BT.measure("work")
    gs_before = BT.goals(m_before)
    n_fail_before = sum(1 for g in gs_before if g[3] is False)
    if not args.apply:
        print("\n（dry-run：以上是体检结论，没有写任何文件；加 --apply 才落表）")
        print("父本未达标 %d 条，候选见 %s" % (n_fail_before, cand))
        return 0

    bak_dir = os.path.join(bak_sub("_backup_before_numeric_opt"), _now())
    os.makedirs(bak_dir, exist_ok=True)
    shutil.copy2(_p(F_RECHARGE), os.path.join(bak_dir, F_RECHARGE + ".xlsx"))
    print("\n已备份 → %s" % bak_dir)

    shutil.copy2(cand, _p(F_RECHARGE))
    _reset_audit_base()
    m_after = BT.measure("work")
    gs_after = BT.goals(m_after)
    n_fail_after = sum(1 for g in gs_after if g[3] is False)
    print_goals(gs_after, "落表后")

    if n_fail_after > n_fail_before and not args.force:
        shutil.copy2(os.path.join(bak_dir, F_RECHARGE + ".xlsx"), _p(F_RECHARGE))
        print("\n🔴 落表后未达标项从 %d 涨到 %d，已自动回滚（要保留请 --force）"
              % (n_fail_before, n_fail_after))
        return 3

    print("\n✓ 已落表（未达标 %d → %d）。回滚：cp '%s/%s.xlsx' '%s'"
          % (n_fail_before, n_fail_after, bak_dir, F_RECHARGE, BASE_DIR))
    new_rate = weighted_rate(m_after)
    if args.reanchor:
        old = set_anchor(new_rate)
        print("锚点已重置：%s → %.4f（累计预算从这里重新起算 %.0f%%）"
              % ("%.4f" % old if old else "（无）", new_rate, CUM_INFL * 100))
    else:
        print("累计通胀锚点**没有**跟着变（仍是旧基准）。落表不会自动送你新的 +%.0f%% 空间；"
              "确认这一版可以当新基准，才加 --reanchor。" % (CUM_INFL * 100))
    print("🔴 表还没生效：先导表再推服务端 —— TS-Table-Sync（EXPORT=true），"
          "客户端表走 git、服务端 txt 走影子目录。")
    return 0


# ─────────────────────────── 命令：ledger ───────────────────────────

def cmd_ledger(args):
    p = os.path.join(STATE_DIR, "ledger.jsonl")
    if not os.path.exists(p):
        print("（还没有账本：%s）" % p)
        return 0
    recs = [json.loads(l) for l in open(p, encoding="utf-8") if l.strip()]
    print("%-22s %-19s %8s %6s %8s %7s  %s"
          % ("run", "时间", "J", "未达标", "抽/元", "改动", "旋钮"))
    print("─" * 120)
    for r in recs[-args.n:]:
        s = r.get("score") or {}
        print("%-22s %-19s %8.2f %6d %8.4f %7d  %s"
              % (r.get("run", "-"), r.get("at", "-"), s.get("J", 0), s.get("fails", 0),
                 s.get("rate", 0), r.get("n_changes", 0),
                 json.dumps(r.get("knobs") or {}, ensure_ascii=False)))
    return 0


# ─────────────────────────── main ───────────────────────────

def main():
    global MAX_INFL
    ap = argparse.ArgumentParser(description="数值迭代优化引擎（货币化价值带域）")
    sub = ap.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("measure", help="当前/指定快照的 8 目标 + 分档中位")
    a.add_argument("--at", default="work", help="work | <git rev> | <备份目录>")
    a.add_argument("--json")
    a.set_defaults(fn=cmd_measure)

    b = sub.add_parser("search", help="迭代寻优（只读；产物在 _output/numeric_opt/）")
    b.add_argument("--rounds", type=int, default=6)
    b.add_argument("--budget", type=int, default=0, help="最多评估多少个候选（默认 rounds×8）")
    b.add_argument("--slope", type=float, default=None)
    b.add_argument("--gap", type=float, default=None)
    b.add_argument("--cap-tol", dest="cap_tol", type=float, default=None)
    b.add_argument("--band-tol", dest="band_tol", type=float, default=None,
                   help="收敛带下沿（默认 0.20 = 低于目标 20% 才补）")
    b.add_argument("--cut", type=lambda s: s.lower() in ("1", "true", "yes"), default=None)
    b.add_argument("--mono", type=lambda s: s.lower() in ("1", "true", "yes"), default=None)
    b.add_argument("--step", type=float, default=0.0, help="初始步长倍数（1.0 = 默认）")
    b.add_argument("--run-id", dest="run_id", default="")
    b.add_argument("--reset", action="store_true", help="不沿用上次最优旋钮")
    b.add_argument("--max-infl", dest="max_infl", type=float, default=MAX_INFL)
    b.add_argument("--note", default="")
    b.set_defaults(fn=cmd_search)

    c = sub.add_parser("promote", help="把候选表落进 base_data（备份 + 不变式校验 + 回滚）")
    c.add_argument("--run", required=True)
    c.add_argument("--apply", action="store_true")
    c.add_argument("--force", action="store_true")
    c.add_argument("--reanchor", action="store_true",
                   help="落表成功后把当前值立为累计通胀新基准（人对着设计确认过才用）")
    c.set_defaults(fn=cmd_promote)

    d = sub.add_parser("ledger", help="历史轮次")
    d.add_argument("--n", type=int, default=20)
    d.set_defaults(fn=cmd_ledger)

    args = ap.parse_args()
    if getattr(args, "max_infl", None):
        MAX_INFL = args.max_infl
    return args.fn(args) or 0


if __name__ == "__main__":
    sys.exit(main())
