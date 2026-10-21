#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""R13 结构性定价修复：把「一次性档 / 进度档」的价值落差从 5.6 倍收到 2.9 倍。

四个改动项（--only 可单选，默认全做）：

  fund    成长基金 活动 6/601/602/603/604 的 10 个节点统一 16#2156
          30,160 钻/98 元（1.399 抽/元）→ 21,560 钻/98 元（1.000 抽/元）
  pack    Type=5 直购礼包整体 ×1.21（**只加券，一颗钻石不加**）
          648 档 0.2915 → ≈0.353 抽/元
  store   商店里以钻石标价的 19#N 券，单价从 250 → 220（10 连 2500 → 2000）
          修正「买券比直接抽卡还贵」的价格倒挂
  lux328  豪华基金 328 元：LuxuryFund Type=79 的 17 天 16#2080 → 16#2540
          0.7184 → 0.8268 抽/元，与 128 元档 0.8267 持平

R14 加的两项（同样是 --only 单选）：

  cap     削峰。R10/R13 只做「补到地板」，远高于曲线的礼包一件没动，
          30 元档 56 个条目横跨 0.2212~0.9242（4.2 倍）。
          cap 按「本档中位 +20%」削高，再按「同族/同产品线 小额档最多
          比大额档高 15%」做单调削平 —— 两刀都是一次算完再落表，
          避免重复跑出递减式误伤。**只从 BaseReward/RewardShow 里扣券和钻石**。
  cat     招财猫（LuckyCatConfig 901–904）满次数 22,704 钻换 37,990 钻 = 1.67x，
          是一台钻石印钞机，会把任何付费钻石放大 1.67 倍。
          改成「保底返本 1.00x + 上限 1.12x」（期望 1.06x），充值门槛不动。

不变的东西（自检逐条守）：
  · `Price` 一律不动 —— 计费点按商品 id 绑定，改价会让渠道侧金额与配置不符。
  · 钻石产出不动（fund 项除外，那是它的本体）—— 钻石是全局通货。
  · 任何 SKU 的「非券道具构成」不动 —— 只往 BaseReward/RewardShow 里加券。
  · 商店只降价不涨价。

用法：
    python3 scripts/monetization_rebalance.py                  # dry-run
    python3 scripts/monetization_rebalance.py --apply          # 备份+落表+自检（失败自动回滚）
    python3 scripts/monetization_rebalance.py --verify-only
    python3 scripts/monetization_rebalance.py --only fund,store
    python3 scripts/monetization_rebalance.py --revert <backup_dir>
    python3 scripts/monetization_rebalance.py --list-backups
"""

from __future__ import annotations

import argparse
import collections
import math
import os
import re
import shutil
import statistics
import sys
import time

try:
    import openpyxl
except ImportError:
    sys.exit("需要 openpyxl：/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "data_execl", "base_data")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from backup_paths import sub as _bak_sub              # noqa: E402
from monetization_ladder import (                     # noqa: E402
    DIA, DIA_PER_PULL, TICKETS, add_items, fmt_pairs,
    header_index, parse_pairs, pick_ticket, pull_equiv,
)

BACKUP_ROOT = _bak_sub("_backup_before_rebalance")
# 幂等锁：本脚本的 pack 项是**乘法**，连跑两次会把礼包带乘到 1.21²。
# 每项落表成功后写一条记录，再次 --apply 同一项必须先 --force。
MARKER = os.path.join(BACKUP_ROOT, "_applied.json")

F_REWARD = "ActivityRewardConfig"
F_RECHARGE = "RechargeCommodityConfig"
F_STORE = "StoreConfig"
F_FUND = "LuxuryFund"
F_CAT = "LuckyCatConfig"
F_ACT = "GlobalActivity"

# 各表的数据起始行（与导表工具的约定一致：Recharge 是 6，其余是 8）
ROW_START = {F_RECHARGE: 6, F_REWARD: 8, F_STORE: 8, F_FUND: 8, F_CAT: 8, F_ACT: 8}

# ─────────────────────────── fund ───────────────────────────
# 成长基金：SKU id -> 活动 Id（OnSaleRule 的 `3#N` 就是活动号，verify 会核对）
FUND_SKU_ACT = {101: 6, 102: 601, 103: 602, 104: 603, 105: 604}
FUND_NODE_DIA = 2156          # 每节点钻石数；10 节点 = 21,560 = 98 抽 = 1.00 抽/元
FUND_PRICE = 98

# ─────────────────────────── pack ───────────────────────────
PACK_TYPE = 5
PACK_MULT = 1.21
# 券的最小粒度就是 1 张。低价包上补 1 张等于 +65%（6 元）/+32%（12 元），
# 会造成"6 元包比 648 元包值"的反向阶梯 —— 所以只有实际增幅落在
# [MULT-TOL, MULT+TOL] 内的 SKU 才动，其余如实标注"粒度不足"。
PACK_REL_TOL = 0.10
# 整档中位抽数低于此值就不动：补 1 张券的相对误差会超过 20%。
PACK_MIN_TIER_PULL = 5.0
# 战令：Type=5 但价值大头在 BattlePassReward 任务轨道（不受本脚本控制），
# 单独乘 1.21 会让「SKU 值」和「轨道值」脱节，故排除，由战令自己定档。
PACK_EXCLUDE = {72001}

# ─────────────────────────── store ───────────────────────────
TICKET_GOODS = "19"           # 只修紫晶卡：它是唯一有「直抽钻石价」可比的券
STORE_UNIT = 220              # 单抽直耗钻（LotterySetting Id=12：19#1|16#220）
STORE_TEN_UNIT = 200          # 十连均摊（Id=11：19#10|16#2000）

# ─────────────────────────── lux328 ───────────────────────────
LUX_TYPE_OLD = 79
LUX_DAY_OLD = 2080
LUX_DAY_NEW = 2540
LUX_SKU = 79
LUX_SKU_SHOW = "16#38640"

# ─────────────────────────── cap（削峰）───────────────────────────
# 同价档内允许比中位高 20%（audit 的收敛建议就是 ±20%）。
CAP_TOL = 0.20
# 同族（ShowType 页签）/同产品线（Name）内，小额档允许比大额档高 15% ——
# 这一档溢价是「新手带」的既有设计，超过 15% 就变成"买小包更划算"。
MONO_TOL = 0.15
# 小于 0.08 抽（≈18 钻）的调整不做：券是 1 张、钻石按 10 取整，
# 再细的刀只会给 xlsx 刷无意义的 diff。
MIN_DROP_PULL = 0.08
# 地板守卫：任何一刀都不许把 SKU 削到「本档中位 -20%」以下。
FLOOR_TOL = 0.20
# 单调削平同时按两个口径算：页签（st=ShowType）+ 产品线（line=Name）。
CAP_GROUP_KEYS = ("st", "line")
# 削峰覆盖的 Type：5 = 直购礼包（507 个可售），10 = 钻石/资源大包（3 个，ShowType 5）。
# Type=10 那三个（12/98/648 元）跟礼包带不是一条曲线，而是贴着直充走的钻石包，
# 但它们自己内部 98 元 0.1475 → 648 元 0.0640（-57%）也是倒挂，一起收。
# Type=3 直充 / 78,79 基金 / 8,9 战令 的价值不在 SKU 行里，不能这么削，故排除。
CAP_TYPES = (5, 10)

# ─────────────────────────── cat（招财猫）───────────────────────────
CAT_ACTS = (901, 902, 903, 904)
CAT_DOWN = 1.00       # 保底返本
CAT_UP = 1.12         # 上限 +12%
# ShowMax 是「最高可得」的展示值，原来是 8888/21888 这种虚标（真实上限才 18,510）。
# 直接等于上限，避免界面上写一个永远拿不到的数。


# ─────────────────────────── 通用 ───────────────────────────

def path_of(name):
    p = os.path.join(BASE, name + ".xlsx")
    if not os.path.exists(p):
        sys.exit("缺少配置表：%s" % p)
    return p


def load(name, sheet=None):
    wb = openpyxl.load_workbook(path_of(name))
    ws = wb[sheet] if sheet and sheet in wb.sheetnames else wb.worksheets[0]
    return wb, ws


def iter_data(ws, start):
    for r in range(start, ws.max_row + 1):
        v = [c.value for c in ws[r]]
        if len(v) < 2 or v[1] is None:
            continue
        yield r, v


def pairs_dict(text):
    return {k: (n or 0) for k, n in parse_pairs(text)}


def sub_items(s, delta):
    """按 id 扣减奖励串；扣到 0 的条目整条删掉（不能留 `19#0`）。"""
    pairs = parse_pairs(s)
    pos = {k: i for i, (k, _) in enumerate(pairs)}
    for k, n in delta.items():
        if k not in pos:
            sys.exit("奖励串里没有 %s，扣不动：%r" % (k, s))
        i = pos[k]
        left = (pairs[i][1] or 0) - n
        if left < 0:
            sys.exit("%s 只有 %s 个，扣不掉 %s：%r" % (k, pairs[i][1], n, s))
        pairs[i] = (k, left)
    touched = set(delta)
    return fmt_pairs([(k, n) for k, n in pairs if not (k in touched and n == 0)])


def backup(paths):
    ts = time.strftime("%Y%m%d-%H%M%S")
    d = os.path.join(BACKUP_ROOT, ts)
    os.makedirs(d, exist_ok=True)
    for p in paths:
        shutil.copy2(p, os.path.join(d, os.path.basename(p)))
    return d


def _restore(bak):
    for f in os.listdir(bak):
        shutil.copy2(os.path.join(bak, f), os.path.join(BASE, f))
    print("   已回滚 ← %s" % bak)


def load_marker():
    import json
    if not os.path.exists(MARKER):
        return {}
    try:
        with open(MARKER, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def save_marker(items, bak_dir):
    import json
    data = load_marker()
    for it in items:
        data[it] = {"applied_at": time.strftime("%Y-%m-%dT%H:%M:%S"), "backup": bak_dir}
    os.makedirs(os.path.dirname(MARKER), exist_ok=True)
    with open(MARKER, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)


def guard(items, force):
    """只有**乘法项**重复落表会重复加息（pack ×1.21 连跑两次 = ×1.21²）。

    其余项（fund/store/lux328/cap/cat）每次都是按当前值重算的绝对量或收敛量，
    重跑不会叠加；只有它们才需要 --force 才能重做。
    """
    done = load_marker()
    risky = [it for it in items if it in done and it in {"pack"}]
    if risky and not force:
        sys.exit("❌ %s 已经落过表了（%s）。\n"
                 "   pack 是乘法项，再跑一次会再乘一次 1.21。\n"
                 "   确认要重做请先 --revert <备份目录> 再 --apply --force。"
                 % (",".join(risky), ", ".join(done[h]["applied_at"] for h in risky)))
    again = [it for it in items if it in done and it not in {"pack"}]
    if again:
        print("   （%s 之前落过表；本项按当前值重算，重复执行幂等）"
              % ", ".join(again))


class Checker:
    def __init__(self):
        self.msgs, self.ok = [], True

    def add(self, tag, cond, detail=""):
        if not cond:
            self.ok = False
        self.msgs.append("%s %s%s" % ("✓" if cond else "✗", tag, ("：" + detail) if detail else ""))

    def dump(self):
        print("\n".join("   " + m for m in self.msgs))
        return self.ok


# ─────────────────────────── fund ───────────────────────────

def plan_fund():
    wb, ws = load(F_REWARD)
    idx = header_index(ws)
    out = []
    for r, v in iter_data(ws, ROW_START[F_REWARD]):
        act = v[idx["ActivityId"]]
        if act not in FUND_SKU_ACT.values():
            continue
        reward = v[idx["Reward"]] or ""
        d = pairs_dict(reward)
        if DIA not in d:
            sys.exit("活动 %s 第 %d 行的 Reward 里没有钻石：%r" % (act, r, reward))
        out.append({"row": r, "act": act, "old": reward,
                    "old_dia": d[DIA], "keep": [k for k in d if k != DIA]})
    wb.close()
    if not out:
        sys.exit("没找到成长基金的奖励行，检查 ActivityId 是否被改过")
    return out


def apply_fund(plans):
    wb, ws = load(F_REWARD)
    idx = header_index(ws)
    c = idx["Reward"]
    for p in plans:
        base = pairs_dict(ws.cell(p["row"], c + 1).value)
        base[DIA] = FUND_NODE_DIA
        # 保持原有顺序，只改钻石数值
        order = [(k, (FUND_NODE_DIA if k == DIA else base[k])) for k in base]
        ws.cell(p["row"], c + 1).value = fmt_pairs(order)
    # TotalValues 只做展示（客户端 Lua 与服务端都不读），同步成真实总量免得虚标
    if "TotalValues" in idx:
        tv = idx["TotalValues"]
        for p in plans:
            if ws.cell(p["row"], tv + 1).value:
                ws.cell(p["row"], tv + 1).value = FUND_NODE_DIA * 10
    wb.save(path_of(F_REWARD))
    wb.close()


def verify_fund():
    ck = Checker()
    wb, ws = load(F_REWARD)
    idx = header_index(ws)
    per_act = {}
    for r, v in iter_data(ws, ROW_START[F_REWARD]):
        act = v[idx["ActivityId"]]
        if act not in FUND_SKU_ACT.values():
            continue
        d = pairs_dict(v[idx["Reward"]])
        per_act.setdefault(act, []).append((r, d))

    ck.add("五个成长基金活动的节点数都是 10",
           all(len(x) == 10 for x in per_act.values()) and len(per_act) == 5,
           str({k: len(v) for k, v in per_act.items()}))

    bad = [(r, d.get(DIA)) for lst in per_act.values() for r, d in lst
           if d.get(DIA) != FUND_NODE_DIA]
    ck.add("每个节点都是 %d 钻" % FUND_NODE_DIA, not bad, str(bad[:5]))

    extra = [(r, sorted(k for k in d if k != DIA)) for lst in per_act.values() for r, d in lst
             if any(k != DIA for k in d)]
    ck.add("节点里没有混入钻石以外的道具", not extra, str(extra[:4]))

    wb.close()

    # 抽/元：活动总量 / 98 元
    rates = {}
    for sku, act in FUND_SKU_ACT.items():
        total = FUND_NODE_DIA * 10
        rates[sku] = total / DIA_PER_PULL / FUND_PRICE
    ck.add("五个成长基金都是 1.000 抽/元",
           all(abs(x - 1.0) < 1e-6 for x in rates.values()),
           str({k: round(v, 4) for k, v in rates.items()}))

    # SKU 的 OnSaleRule 必须仍指向同一个活动（防止改错行）；dup 项关停 102-105 是允许的
    wb2, ws2 = load(F_RECHARGE)
    idx2 = header_index(ws2)
    mismatch, gated_fund = [], []
    for r, v in iter_data(ws2, ROW_START[F_RECHARGE]):
        sid = v[idx2["Id"]]
        if sid not in FUND_SKU_ACT:
            continue
        rule = str(v[idx2["OnSaleRule"]] or "").replace(" ", "")
        if rule == DUP_OFF:
            gated_fund.append(sid)
        elif not rule.startswith("3#%d" % FUND_SKU_ACT[sid]):
            mismatch.append((sid, rule))
        if v[idx2["Price"]] != FUND_PRICE:
            mismatch.append((sid, "price=%s" % v[idx2["Price"]]))
    wb2.close()
    ck.add("SKU 101 仍指向活动 6；102-105 要么指向自己的活动、要么已被 dup 关停",
           not mismatch and 101 not in gated_fund,
           str(mismatch + [("关停", gated_fund)]))
    return ck


# ─────────────────────────── pack ───────────────────────────

def _live_packs(ws, idx, billing):
    for r, v in iter_data(ws, ROW_START[F_RECHARGE]):
        sid = v[idx["Id"]]
        if sid is None or v[idx["Type"]] != PACK_TYPE:
            continue
        if not billing.get(sid, False):
            continue
        if str(v[idx["OnSaleRule"]] or "").replace(" ", "").startswith("1#999#999"):
            continue
        if (v[idx["Price"]] or 0) <= 0:
            continue
        yield r, v, sid


def _billing_map():
    wb, ws = load("ChannelRechargeIdConfig")
    out = {}
    for r, v in iter_data(ws, 8):
        out[v[1]] = any(x not in (None, "", 0) for x in v[3:])
    wb.close()
    return out


def plan_pack():
    """按价格档整体 ×1.21。

    两道闸门（都是粒度问题，不是设计选择）：
      1) 档位闸：整档中位抽数 < PACK_MIN_TIER_PULL 时整档不动 ——
         6 元档中位 1.55 抽，补 1 张就是 +65%，会把 6 元包顶到全表最甜，
         直接造出「小额比大额值」的反向阶梯。
      2) SKU 闸：算出来的实际增幅必须落在 MULT±TOL，否则这个 SKU 不动
         （同档里抽数极低的离群件补 1 张就 +50%，留到「削峰补谷」那一步处理）。
    """
    billing = _billing_map()
    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)

    tiers = collections.defaultdict(list)
    for r, v, sid in _live_packs(ws, idx, billing):
        if sid in PACK_EXCLUDE:
            continue
        rewards = pairs_dict(v[idx["BaseReward"]])
        for k, n in pairs_dict(v[idx["ExtraReward"]]).items():
            rewards[k] = rewards.get(k, 0) + n
        tiers[v[idx["Price"]]].append({
            "row": r, "id": sid, "price": v[idx["Price"]],
            "rewards": rewards, "pull": pull_equiv(rewards),
            "base": v[idx["BaseReward"]] or "", "show": v[idx["RewardShow"]] or "",
        })
    wb.close()

    plans, skipped = [], collections.Counter()
    for price in sorted(tiers):
        rows = tiers[price]
        pulls = [x["pull"] for x in rows if x["pull"] > 0]
        empty = [x for x in rows if x["pull"] <= 0]
        if empty:
            skipped["纯资源包（无券无钻，乘不了）"] += len(empty)
        if not pulls:
            continue
        med = statistics.median(pulls)
        if med < PACK_MIN_TIER_PULL:
            skipped["整档不动（%s 元中位 %.2f 抽，补 1 张 = +%.0f%%）"
                    % (price, med, 100.0 / med)] += len(pulls)
            continue
        for x in rows:
            if x["pull"] <= 0:
                continue
            add = int(round(x["pull"] * (PACK_MULT - 1)))
            ratio = (x["pull"] + add) / x["pull"]
            if add < 1 or not (PACK_MULT - PACK_REL_TOL <= ratio <= PACK_MULT + PACK_REL_TOL):
                skipped["档内离群件（%s 元 / %.2f 抽，补 1 张 = +%.0f%%）"
                        % (price, x["pull"], 100.0 / x["pull"])] += 1
                continue
            plans.append(dict(x, ticket=pick_ticket(x["rewards"]), add=add,
                              pull_after=x["pull"] + add))
    return plans, skipped


def apply_pack(plans):
    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)
    c_base, c_show = idx["BaseReward"], idx["RewardShow"]
    for p in plans:
        delta = {p["ticket"]: p["add"]}
        base = ws.cell(p["row"], c_base + 1).value or ""
        ws.cell(p["row"], c_base + 1).value = add_items(base, delta)
        show = ws.cell(p["row"], c_show + 1).value or ""
        if str(show).strip():
            ws.cell(p["row"], c_show + 1).value = add_items(show, delta)
    wb.save(path_of(F_RECHARGE))
    wb.close()


def verify_pack(plans_before):
    """plans_before: apply 之前算出的 plan（含 pull / add / price）。"""
    ck = Checker()
    billing = _billing_map()
    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)
    cur = {}
    n_pack = 0
    for r, v, sid in _live_packs(ws, idx, billing):
        n_pack += 1
        rewards = pairs_dict(v[idx["BaseReward"]])
        for k, n in pairs_dict(v[idx["ExtraReward"]]).items():
            rewards[k] = rewards.get(k, 0) + n
        cur[sid] = {"pull": pull_equiv(rewards), "price": v[idx["Price"]],
                    "rewards": rewards, "base": v[idx["BaseReward"]],
                    "show": v[idx["RewardShow"]],
                    "ticket_tot": sum(rewards.get(k, 0) for k in TICKETS)}
    wb.close()

    ck.add("可售礼包数量与计划一致", n_pack >= len(plans_before), "%d" % n_pack)

    low, high, bad_dia, bad_other = [], [], [], []
    before = {p["id"]: p for p in plans_before}
    for sid, p in before.items():
        c = cur.get(sid)
        if c is None:
            low.append((sid, "missing"))
            continue
        ratio = c["pull"] / p["pull"] if p["pull"] else 0
        if not (PACK_MULT - PACK_REL_TOL - 1e-9 <= ratio <= PACK_MULT + PACK_REL_TOL + 1e-9):
            low.append((sid, round(ratio, 4)))
        if c["price"] != p["price"]:
            bad_dia.append((sid, p["price"], c["price"]))
    ck.add("每个被改的礼包增幅落在 %.2f±%.0f%%" % (PACK_MULT, PACK_REL_TOL * 100),
           not low, str(low[:5]))
    ck.add("礼包价格一个字没动", not bad_dia, str(bad_dia[:5]))

    # 钻石数量、非券道具构成必须与改前一致
    wb2, ws2 = load(F_RECHARGE)
    idx2 = header_index(ws2)
    drift = []
    for r, v, sid in _live_packs(ws2, idx2, billing):
        if sid not in before:
            continue
        now = pairs_dict(v[idx2["BaseReward"]])
        old = pairs_dict(before[sid]["base"] or "")
        if now.get(DIA, 0) != old.get(DIA, 0):
            drift.append((sid, DIA, old.get(DIA, 0), now.get(DIA, 0)))
        ok_keys = {k for k in old if k not in TICKETS}
        nk_keys = {k for k in now if k not in TICKETS}
        if ok_keys != nk_keys:
            drift.append((sid, "keys", sorted(ok_keys), sorted(nk_keys)))
    wb2.close()
    ck.add("钻石与非券道具构成零漂移", not drift, str(drift[:5]))

    # 奖励串不能出现非数字 id（fmt_pairs 出错的典型症状）
    illegal = [(sid, k) for sid, c in cur.items() for k in c["rewards"] if not k.isdigit()]
    ck.add("奖励串 id 全为数字", not illegal, str(illegal[:4]))

    # RewardShow 与 BaseReward 的券数量必须平行（一个给奖一个展示）
    diverge = []
    for sid, c in cur.items():
        show = str(c["show"] or "").strip()
        if not show:
            continue
        if sum(pairs_dict(show).get(k, 0) for k in TICKETS) != c["ticket_tot"]:
            diverge.append(sid)
    ck.add("RewardShow 券数量与 BaseReward 一致", not diverge, str(diverge[:5]))
    return ck


# ─────────────────────────── cap ───────────────────────────
# 基准取「实测中位」而不是 TARGET_CURVE：R13 之后各档中位已被「补到地板」
# 顶高了 2–17%（30 元档中位 0.2545 vs 曲线×1.21 的 0.2178），用曲线当基准
# 会把半个档都判成超限，削错人。玩家看到的"同价差 4 倍"是同价横向比的，
# 所以基准就该是本档中位。

def _iter_cap_rows(ws, idx, billing):
    """削峰口径的 SKU：Type ∈ CAP_TYPES、有计费点、未 999 关停、有价格。"""
    for r, v in iter_data(ws, ROW_START[F_RECHARGE]):
        sid = v[idx["Id"]]
        if sid is None or v[idx["Type"]] not in CAP_TYPES:
            continue
        if not billing.get(sid, False):
            continue
        if str(v[idx["OnSaleRule"]] or "").replace(" ", "").startswith("1#999#999"):
            continue
        if (v[idx["Price"]] or 0) <= 0:
            continue
        yield r, v, sid


def _live_pack_rows():
    """可售礼包（有计费点、未 999 关停、有价格）的抽等值快照。"""
    billing = _billing_map()
    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)
    rows = []
    for r, v, sid in _iter_cap_rows(ws, idx, billing):
        if sid in PACK_EXCLUDE:      # 战令：价值大头在任务轨道，不参与削
            continue
        rewards = pairs_dict(v[idx["BaseReward"]])
        for k, n in pairs_dict(v[idx["ExtraReward"]]).items():
            rewards[k] = rewards.get(k, 0) + n
        price = v[idx["Price"]]
        pull = pull_equiv(rewards)
        rows.append({
            "row": r, "id": sid, "price": price, "pull": pull,
            "rate": pull / price if price else 0.0, "type": v[idx["Type"]],
            "st": v[idx["ShowType"]], "line": str(v[idx["Name"]] or ""),
            "limit": v[idx["Limit"]], "rewards": rewards,
            "tickets": sum(rewards.get(k, 0) for k in TICKETS),
            "dia": rewards.get(DIA, 0) or 0,
            "base": v[idx["BaseReward"]] or "", "show": v[idx["RewardShow"]] or "",
            "extra": v[idx["ExtraReward"]] or "",
        })
    wb.close()
    return rows


def _tier_center(rows):
    """价格档中位，只统计 Type=5 礼包。

    Type=10 那三个钻石包（12/98/648 元）走的是直充那条 0.05 左右的线，
    混进来会把 98 元档的下界拉到 0.15、648 元档拉到 0.064，
    "同价离散"直接变成 6 倍 —— 那是两条不同的经济，不是同一个货架。
    """
    center = {}
    for p in sorted({x["price"] for x in rows}):
        mem = [x["rate"] for x in rows
               if x["price"] == p and x["pull"] > 0 and x.get("type", PACK_TYPE) == PACK_TYPE]
        if mem:
            center[p] = statistics.median(mem)
    return center


def _removal_plan(x, tgt_rate, cap_rate, floor_rate):
    """把「削到 tgt_rate」折成 {道具: 扣减数}，返回 (delta, pull_after)。

    券的粒度是 1 张，在 6 元档上就是 16.7% 一档 —— 截断取整经常会「想削 0.69 抽
    却一张也削不动」，结果 SKU 还杵在 +20% 以上。所以：
      · 先按「不削过头」取整数张券；
      · 若这样仍高于 cap，而多削 1 张不会破地板，就多削那 1 张。
    宁可在档内偏下一点，也不留一个破档的离群件。
    """
    price = x["price"]
    want = x["pull"] - tgt_rate * price
    cap_pull, floor_pull = cap_rate * price, floor_rate * price
    order = sorted([k for k in TICKETS if x["rewards"].get(k)], key=lambda k: -x["rewards"][k])
    n_avail = sum(x["rewards"][k] for k in order)
    t = min(int(want + 1e-9), n_avail)
    if (x["pull"] - t > cap_pull + 1e-9 and t < n_avail
            and x["pull"] - (t + 1) >= floor_pull):
        t += 1
    delta, left = {}, t
    for k in order:
        n = min(left, x["rewards"][k])
        if n > 0:
            delta[k] = n
            left -= n
    rest = want - t
    # 多削过一张（rest<0）时不再动钻石，避免双重超额
    if rest > 0.005 and x["rewards"].get(DIA):
        dia = min(int(round(rest * DIA_PER_PULL / 10.0) * 10), x["rewards"][DIA])
        if dia > 0:
            delta[DIA] = dia
    after = x["pull"] - sum(n for k, n in delta.items() if k in TICKETS) \
        - delta.get(DIA, 0) / float(DIA_PER_PULL)
    return delta, after


def _rewards_after(rewards, delta):
    out = {}
    for k, n in rewards.items():
        left = n - delta.get(k, 0)
        if left:
            out[k] = left
    return out


def plan_cap():
    """迭代到稳定：每轮按「当前（已扣过的）值」重新取中位、重算目标，再累加扣减。

    为什么要迭代：削峰会把某些件削到中位附近，档中位本身会小幅移动，
    那一轮算达标、下一轮又冒出几个 +21% 的。单轮方案在落表后还能剩 9 个
    "待削"，而这条路每轮只看**累计扣减后的真实值**，天然收敛。

    每轮两刀：
      档内削峰  rate ≤ 本档中位 × (1+CAP_TOL)
      单调削平  同页签 / 同产品线里，小额档 rate ≤ 大额档中位 × (1+MONO_TOL)
                （地板守卫：不削到本档中位 × (1-FLOOR_TOL) 以下）
    """
    rows = _live_pack_rows()
    acc = {x["id"]: {} for x in rows}
    hit_band, hit_mono = set(), set()
    skipped = []
    center = _tier_center(rows)

    for _ in range(6):
        cur = []
        for x in rows:
            r = dict(x)
            r["rewards"] = _rewards_after(x["rewards"], acc[x["id"]])
            r["pull"] = pull_equiv(r["rewards"])
            r["rate"] = r["pull"] / x["price"] if x["price"] else 0.0
            cur.append(r)
        center = _tier_center(cur)
        tgt = {r["id"]: r["rate"] for r in cur}
        for r in cur:
            if r["pull"] <= 0 or r["type"] != PACK_TYPE:
                continue          # 档内削峰只针对礼包带（Type=10 走单调那一刀）
            cap = center[r["price"]] * (1 + CAP_TOL)
            if tgt[r["id"]] > cap + 1e-9:
                tgt[r["id"]] = cap
                hit_band.add(r["id"])

        for _ in range(6):
            moved = 0
            for key in CAP_GROUP_KEYS:
                grp = collections.defaultdict(lambda: collections.defaultdict(list))
                for r in cur:
                    if r["pull"] > 0:
                        grp[r[key]][r["price"]].append(r)
                for g in grp.values():
                    ps = sorted(g)
                    if len(ps) < 2:
                        continue
                    med = {p: statistics.median([tgt[r["id"]] for r in g[p]]) for p in ps}
                    for a, b in zip(ps, ps[1:]):
                        # 地板只在「这档本来就在地板之上」时设限。
                        # Type=10 那三个钻石包整条线都在礼包带地板以下（贴着直充走），
                        # 拿礼包带的地板去卡它，就永远削不动内部 −57% 的倒挂。
                        floor_a = center[a] * (1 - FLOOR_TOL)
                        lim = med[b] * (1 + MONO_TOL)
                        if med[a] >= floor_a:
                            lim = max(lim, floor_a)
                        if med[a] <= lim + 1e-9:
                            continue
                        for r in g[a]:
                            if tgt[r["id"]] > lim + 1e-9:
                                tgt[r["id"]] = lim
                                hit_mono.add(r["id"])
                                moved += 1
            if not moved:
                break

        rounds = 0
        for r in cur:
            if r["pull"] <= 0:
                continue
            want = r["pull"] - tgt[r["id"]] * r["price"]
            if want < MIN_DROP_PULL:      # 粒度不足，动了也是噪音
                continue
            floor_r = center[r["price"]] * (1 - FLOOR_TOL)
            if r["rate"] < floor_r:       # 本来就在地板以下（钻石包线），不设限
                floor_r = 0.0
            delta, _ = _removal_plan(r, tgt[r["id"]],
                                     center[r["price"]] * (1 + CAP_TOL), floor_r)
            if not delta:
                continue
            for k, n in delta.items():
                acc[r["id"]][k] = acc[r["id"]].get(k, 0) + n
            rounds += 1
        if not rounds:
            break

    cuts = []
    for x in rows:
        delta = {k: n for k, n in acc[x["id"]].items() if n > 0}
        if not delta:
            continue
        after = x["pull"] - sum(n for k, n in delta.items() if k in TICKETS) \
            - delta.get(DIA, 0) / float(DIA_PER_PULL)
        cuts.append(dict(x, delta=delta,
                         dt=sum(n for k, n in delta.items() if k in TICKETS),
                         dd=delta.get(DIA, 0), pull_after=after,
                         rate_after=after / x["price"],
                         band=x["id"] in hit_band, mono=x["id"] in hit_mono))
    return cuts, {"center": center, "rows": rows, "skipped": skipped,
                  "band": len(hit_band), "mono": len(hit_mono)}


def apply_cap(cuts):
    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)
    c_base, c_show = idx["BaseReward"], idx["RewardShow"]
    for c in cuts:
        base = ws.cell(c["row"], c_base + 1).value or ""
        ws.cell(c["row"], c_base + 1).value = sub_items(base, c["delta"])
        show = ws.cell(c["row"], c_show + 1).value or ""
        if str(show).strip():
            have = pairs_dict(show)
            delta = {k: n for k, n in c["delta"].items() if k in have}
            if delta:
                ws.cell(c["row"], c_show + 1).value = sub_items(show, delta)
    wb.save(path_of(F_RECHARGE))
    wb.close()


def verify_cap(cuts, skipped=None):
    ck = Checker()
    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)
    billing = _billing_map()
    cur, zero, parallel = {}, [], []
    for r, v, sid in _iter_cap_rows(ws, idx, billing):
        if sid in PACK_EXCLUDE:
            continue
        base_raw = v[idx["BaseReward"]] or ""
        show_raw = v[idx["RewardShow"]] or ""
        rewards = pairs_dict(base_raw)
        for k, n in pairs_dict(v[idx["ExtraReward"]]).items():
            rewards[k] = rewards.get(k, 0) + n
        pull = pull_equiv(rewards)
        price = v[idx["Price"]]
        cur[sid] = {"row": r, "price": price, "pull": pull,
                    "rate": pull / price if price else 0.0, "type": v[idx["Type"]],
                    "rewards": rewards, "base": base_raw, "show": show_raw,
                    "tickets": sum(rewards.get(k, 0) for k in TICKETS)}
        for raw in (base_raw, show_raw):
            for k, n in parse_pairs(raw):
                if n == 0 and k in TICKETS:
                    zero.append((sid, raw))
        show_t = sum(pairs_dict(show_raw).get(k, 0) for k in TICKETS) if str(show_raw).strip() else None
        if show_t is not None and show_t != cur[sid]["tickets"]:
            parallel.append((sid, show_t, cur[sid]["tickets"]))
    wb.close()

    ck.add("可售礼包数量与计划一致", len(cur) >= len(cuts), "%d" % len(cur))
    ck.add("奖励串里没有 0 数量条目（`19#0`）", not zero, str(zero[:4]))
    ck.add("RewardShow 券数与 BaseReward 一致", not parallel, str(parallel[:4]))

    # 用**当前**数据重算中位：削峰不动中位（削的都是峰），基准应当稳定
    rows_now = [{"price": x["price"], "rate": x["rate"], "pull": x["pull"],
                 "type": x["type"]} for x in cur.values()]
    center_now = _tier_center(rows_now)

    # 粒度豁免：券最小 1 张，6 元档上就是 16.7% 的台阶 —— 券只够/钻石不够的包
    # 物理上削不到 +20% 以内，plan 阶段已记进 skipped，这里不重复报警。
    skipped = set(skipped or ())
    over = [(sid, round(c["rate"], 4), round(center_now.get(c["price"], 0) * (1 + CAP_TOL), 4))
            for sid, c in cur.items()
            if c["pull"] > 0 and c["type"] == PACK_TYPE and c["price"] in center_now
            and sid not in skipped
            and c["rate"] > center_now[c["price"]] * (1 + CAP_TOL) + 0.02]
    ck.add("没有 SKU 仍高于本档中位 +%.0f%%（留 2%% 取整余量，粒度受限 %d 个）"
           % (CAP_TOL * 100, len(skipped)), not over, str(over[:5]))

    # 地板只看「我们削下去的」：本来就低于地板的低价离群件（12 元档 0.1742 那种）
    # 不是这一刀造成的，不该由这条自检背锅。
    floor_bad = []
    for c in cuts:
        n = cur.get(c["id"])
        if n is None or n["pull"] <= 0 or n["type"] != PACK_TYPE:
            continue          # Type=10 走直充线，量级不同，不适用礼包带地板
        floor = center_now.get(n["price"], 0) * (1 - FLOOR_TOL)
        if n["rate"] < floor - 1e-9 < c["rate"]:
            floor_bad.append((c["id"], round(c["rate"], 4), round(n["rate"], 4), round(floor, 4)))
    ck.add("没有 SKU 被削到本档中位 -%.0f%% 以下" % (FLOOR_TOL * 100),
           not floor_bad, str(floor_bad[:5]))

    # 逐 SKU 比对：只准券/钻石减少，其他道具构成必须一字不差
    drift, price_bad, grow = [], [], []
    for c in cuts:
        n = cur.get(c["id"])
        if n is None:
            drift.append((c["id"], "missing"))
            continue
        if n["price"] != c["price"]:
            price_bad.append((c["id"], c["price"], n["price"]))
        if n["pull"] > c["pull"] + 1e-9:
            grow.append((c["id"], round(c["pull"], 2), round(n["pull"], 2)))
        old = pairs_dict(c["base"])
        new = pairs_dict(n["base"])
        for k in set(old) | set(new):
            if k in TICKETS or k == DIA:
                continue
            if old.get(k, 0) != new.get(k, 0):
                drift.append((c["id"], k, old.get(k, 0), new.get(k, 0)))
    if cuts:
        ck.add("被削的 SKU 一个都没变贵", not grow, str(grow[:5]))
        ck.add("价格零漂移", not price_bad, str(price_bad[:5]))
        ck.add("非券非钻道具零漂移", not drift, str(drift[:6]))
    return ck


def print_cap_report(cuts, meta):
    rows, center = meta["rows"], meta["center"]
    cmap = {c["id"]: c["rate_after"] for c in cuts}
    print("   基准=本档中位；档内上限 中位+%.0f%%，同族小额档上限 大额档中位+%.0f%%"
          % (CAP_TOL * 100, MONO_TOL * 100))
    print("   命中：档内削峰 %d 个 / 单调削平 %d 个 / 实际落刀 %d 个（微调跳过 %d 个）"
          % (meta["band"], meta["mono"], len(cuts), len(meta["skipped"])))
    if not cuts:
        print("   全部达标，无需改动。")
        return
    print("   合计削掉：券 %d 张、钻石 %d"
          % (sum(c["dt"] for c in cuts), sum(c["dd"] for c in cuts)))
    print("   %-6s %-5s %-17s %-17s %s" % ("价格", "件数", "改前区间", "改后区间", "跨度"))
    for p in sorted(center):
        mem = [x for x in rows if x["price"] == p and x["pull"] > 0
               and x.get("type", PACK_TYPE) == PACK_TYPE]
        if len(mem) < 2:
            continue
        before = [x["rate"] for x in mem]
        after = [cmap.get(x["id"], x["rate"]) for x in mem]
        print("   %-6s %-5d %.4f~%.4f    %.4f~%.4f    %.2fx → %.2fx"
              % (p, len(mem), min(before), max(before), min(after), max(after),
                 max(before) / min(before), max(after) / min(after)))
    print("   削幅最大的 8 个：")
    for c in sorted(cuts, key=lambda c: c["rate_after"] / c["rate"])[:8]:
        print("     id=%-6s %-4s元 %.4f → %.4f (-%.0f%%)  券-%-2d 钻-%-5d %s%s st=%-4s %s"
              % (c["id"], c["price"], c["rate"], c["rate_after"],
                 (1 - c["rate_after"] / c["rate"]) * 100, c["dt"], c["dd"],
                 "档内 " if c["band"] else "", "单调 " if c["mono"] else "",
                 c["st"], c["line"]))


# ─────────────────────────── store ───────────────────────────

def _ticket_target(n):
    return STORE_TEN_UNIT * n if n >= 10 else STORE_UNIT * n


def plan_store():
    wb, ws = load(F_STORE)
    idx = header_index(ws)
    plans, already = [], 0
    c_goods, c_cost = idx["Goods"], idx["Cost"]
    for r, v in iter_data(ws, ROW_START[F_STORE]):
        goods = str(v[c_goods] or "").strip()
        cost = str(v[c_cost] or "").strip()
        if goods.count("|") or "#" not in goods:
            continue                                  # 组合包不动
        gid, _, gnum = goods.partition("#")
        if gid.strip() != TICKET_GOODS:
            continue
        try:
            n = int(float(gnum))
        except ValueError:
            continue
        head, _, tail = cost.partition("|")
        if head.strip() != DIA or "#" not in tail:
            continue                                  # 非钻石货币不动
        parts = tail.split("#")
        try:
            old = int(float(parts[-1]))
        except ValueError:
            continue
        new = _ticket_target(n)
        if new >= old:
            already += 1
            continue
        plans.append({"row": r, "id": v[idx["Id"]], "n": n,
                      "old": old, "new": new, "raw": cost})
    wb.close()
    return plans, already


def apply_store(plans):
    wb, ws = load(F_STORE)
    idx = header_index(ws)
    c = idx["Cost"]
    for p in plans:
        parts = p["raw"].split("|")
        tail = parts[-1].split("#")
        tail[-1] = str(p["new"])
        parts[-1] = "#".join(tail)
        ws.cell(p["row"], c + 1).value = "|".join(parts)
    wb.save(path_of(F_STORE))
    wb.close()


def verify_store(plans_before):
    ck = Checker()
    wb, ws = load(F_STORE)
    idx = header_index(ws)
    over, raised, kept = [], [], 0
    c_goods, c_cost = idx["Goods"], idx["Cost"]
    for r, v in iter_data(ws, ROW_START[F_STORE]):
        goods = str(v[c_goods] or "").strip()
        cost = str(v[c_cost] or "").strip()
        if goods.count("|") or "#" not in goods:
            continue
        gid, _, gnum = goods.partition("#")
        if gid.strip() != TICKET_GOODS:
            continue
        head, _, tail = cost.partition("|")
        if head.strip() != DIA or "#" not in tail:
            continue
        try:
            n = int(float(gnum))
            price = int(float(tail.split("#")[-1]))
        except ValueError:
            continue
        unit = price / float(n)
        if unit > STORE_UNIT + 1e-9:
            over.append((v[idx["Id"]], goods, price, round(unit, 1)))
        kept += 1
    wb.close()

    ck.add("卖券单价不再高于单抽 220 钻", not over, str(over[:6]))

    before = {p["id"]: p for p in plans_before}
    dry = load(F_STORE)[0]
    ws2 = dry[F_STORE] if F_STORE in dry.sheetnames else dry.worksheets[0]
    idx2 = header_index(ws2)
    for r, v in iter_data(ws2, ROW_START[F_STORE]):
        sid = v[idx2["Id"]]
        if sid not in before:
            continue
        p = before[sid]
        now = str(v[idx2["Cost"]] or "")
        if int(float(now.split("|")[-1].split("#")[-1])) > p["old"]:
            raised.append((sid, p["old"], now))
        if str(v[idx2["Goods"]]) != "%s#%d" % (TICKET_GOODS, p["n"]):
            raised.append((sid, "goods changed", v[idx2["Goods"]]))
    dry.close()
    ck.add("只降价、不涨价，且商品数量未变", not raised, str(raised[:6]))

    # 19#10 必须等于十连直抽价 2000；19#1 必须等于单抽钻石价 220
    probe = []
    wb3, ws3 = load(F_STORE)
    idx3 = header_index(ws3)
    for r, v in iter_data(ws3, ROW_START[F_STORE]):
        goods = str(v[idx3["Goods"]] or "").strip()
        cost = str(v[idx3["Cost"]] or "").strip()
        if goods in ("19#1", "19#10") and cost.startswith(DIA + "|"):
            n = 1 if goods == "19#1" else 10
            price = int(float(cost.split("|")[-1].split("#")[-1]))
            if price != _ticket_target(n):
                probe.append((v[idx3["Id"]], goods, price))
    wb3.close()
    ck.add("19#1=220 / 19#10=2000 全部对齐", not probe, str(probe[:6]))
    ck.add("扫到的钻石券行数", kept > 0, "%d 行" % kept)
    return ck


# ─────────────────────────── lux328 ───────────────────────────

def _fund_total(fund_type):
    """返回 (钻石合计, 券合计, 天数)。"""
    wb, ws = load(F_FUND)
    idx = header_index(ws)
    dia = tic = 0
    days = 0
    for r, v in iter_data(ws, ROW_START[F_FUND]):
        if v[idx["Type"]] != fund_type:
            continue
        days += 1
        d = pairs_dict(v[idx["reward"]])
        dia += d.get(DIA, 0)
        tic += sum(d.get(k, 0) for k in TICKETS)
    wb.close()
    return dia, tic, days


def plan_lux():
    wb, ws = load(F_FUND)
    idx = header_index(ws)
    plans = []
    for r, v in iter_data(ws, ROW_START[F_FUND]):
        if v[idx["Type"]] != LUX_TYPE_OLD:
            continue
        d = pairs_dict(v[idx["reward"]])
        if d.get(DIA) != LUX_DAY_OLD:
            continue
        plans.append({"row": r, "raw": v[idx["reward"]], "old": LUX_DAY_OLD})
    wb.close()
    # SKU 79 的 RewardShow 是「总共给多少钻」的展示镜像，要跟着改
    wb2, ws2 = load(F_RECHARGE)
    idx2 = header_index(ws2)
    show = None
    for r, v in iter_data(ws2, ROW_START[F_RECHARGE]):
        if v[idx2["Id"]] != LUX_SKU:
            continue
        if str(v[idx2["RewardShow"]] or "").strip() == LUX_SKU_SHOW:
            show = {"row": r, "old": LUX_SKU_SHOW}
    wb2.close()
    return plans, show


def apply_lux(plans, show):
    wb, ws = load(F_FUND)
    idx = header_index(ws)
    c = idx["reward"]
    for p in plans:
        d = pairs_dict(p["raw"])
        d[DIA] = LUX_DAY_NEW
        ws.cell(p["row"], c + 1).value = fmt_pairs([(k, d[k]) for k in d])
    wb.save(path_of(F_FUND))
    wb.close()
    if show:
        wb2, ws2 = load(F_RECHARGE)
        idx2 = header_index(ws2)
        new_total = LUX_DAY_NEW * len(plans) + (int(LUX_SKU_SHOW.split("#")[1]) - LUX_DAY_OLD * len(plans))
        ws2.cell(show["row"], idx2["RewardShow"] + 1).value = "%s#%d" % (DIA, new_total)
        wb2.save(path_of(F_RECHARGE))
        wb2.close()
        show["new"] = new_total


def verify_lux():
    ck = Checker()
    dia79, tic79, days79 = _fund_total(LUX_TYPE_OLD)
    dia78, tic78, _ = _fund_total(78)

    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)
    base = {}
    for r, v in iter_data(ws, ROW_START[F_RECHARGE]):
        if v[idx["Id"]] in (78, 79):
            d = pairs_dict(v[idx["BaseReward"]])
            base[v[idx["Id"]]] = d.get(DIA, 0)
    wb.close()

    rate79 = (dia79 + base.get(79, 0)) / DIA_PER_PULL + tic79
    rate79 /= 328.0
    rate78 = (dia78 + base.get(78, 0)) / DIA_PER_PULL + tic78
    rate78 /= 128.0

    ck.add("Type=79 仍是 30 天", days79 == 30, str(days79))
    ck.add("328 元档 ≥ 128 元档（倒挂消除）", rate79 + 1e-9 >= rate78,
           "%.4f vs %.4f" % (rate79, rate78))
    ck.add("两档差距 ≤ 0.5%", abs(rate79 - rate78) <= 0.005 * rate78,
           "差 %.2f%%" % ((rate79 / rate78 - 1) * 100))
    ck.add("Type=78 未被波及", dia78 == 13200, str(dia78))

    # 展示镜像必须等于真实总量
    wb2, ws2 = load(F_RECHARGE)
    idx2 = header_index(ws2)
    bad = []
    for r, v in iter_data(ws2, ROW_START[F_RECHARGE]):
        if v[idx2["Id"]] in (78, 79):
            d = pairs_dict(v[idx2["RewardShow"]])
            real = base[v[idx2["Id"]]] + _fund_total(v[idx2["Id"]])[0]
            if d.get(DIA) != real:
                bad.append((v[idx2["Id"]], d.get(DIA), real))
    wb2.close()
    ck.add("SKU 78/79 的 RewardShow = 真实钻石总量", not bad, str(bad))
    return ck


# ─────────────────────────── cat（招财猫）───────────────────────────
# 现状：8 轮共消耗 22,704 钻，保底下限返 30,298、上限返 37,990 ——
# 服务端是 `MathUtils.random(ValueDown, ValueUp)` 均匀取，期望 34,144 = **1.50x**。
# 也就是说玩家拿任何一笔充值买的钻石来摇一次，出门就多 50%，
# 所有 0.2~0.35 抽/元的定价全被这一个活动放大 1.5 倍，前面的阶梯全白做。
#
# 改成「保底返本、上限 +12%」：它是充值门槛解锁的福利（RmbValue 6~198 元），
# 该给点彩头，但不该是印钞机。期望 1.06x，相当于给付费玩家的 6% 钻石返利。

def plan_cat():
    # 必须读**缓存值**：本表 C24:C39 是 `=C16+1` 这类公式，
    # 直接 load_workbook（不带 data_only）拿到的是公式字符串 '=C16+1'，
    # ActivityId 一比对就全落空，903/904 两个活动会被静默跳过。
    wb = openpyxl.load_workbook(path_of(F_CAT), data_only=True)
    ws = wb[F_CAT] if F_CAT in wb.sheetnames else wb.worksheets[0]
    idx = header_index(ws)
    plans = []
    for r, v in iter_data(ws, ROW_START[F_CAT]):
        act = v[idx["ActivityId"]]
        if act not in CAT_ACTS:
            continue
        cons = v[idx["ConsumeValue"]] or 0
        if cons <= 0:
            continue
        plans.append({
            "row": r, "act": act, "id": v[idx["Id"]], "time": v[idx["LuckyTime"]],
            "lucky_type": v[idx["LuckyType"]], "consume": cons,
            "old_up": v[idx["ValueUp"]], "old_down": v[idx["ValueDown"]],
            "old_show": v[idx["ShowMax"]],
            "new_up": int(round(cons * CAT_UP)),
            "new_down": int(round(cons * CAT_DOWN)),
            "rmb": v[idx["RmbValue"]],
        })
    wb.close()
    if not plans:
        sys.exit("LuckyCatConfig 里没找到活动 %s 的行" % (CAT_ACTS,))
    return plans


def apply_cat(plans):
    """直接改 xlsx 里的 sheet XML，不用 openpyxl 整体另存。

    openpyxl 保存时会把公式单元格的**缓存值**丢掉（只留 <f>），
    之后任何 `data_only=True` 的读取（导表工具、audit 脚本）都会得到 None，
    结果是 903/904 两个活动的 16 行凭空少掉一个字段。逐单元格改 <v> 没这问题。
    """
    import re
    import zipfile
    p = path_of(F_CAT)
    zin = zipfile.ZipFile(p)
    names = zin.namelist()
    xml = zin.read("xl/worksheets/sheet1.xml").decode("utf-8")
    for pl in plans:
        for col, val in (("G", pl["new_up"]), ("H", pl["new_down"]), ("J", pl["new_up"])):
            ref = "%s%d" % (col, pl["row"])
            pat = re.compile(r'(<c r="%s"[^>]*>)(.*?)(</c>)' % ref, re.S)
            m = pat.search(xml)
            if not m:
                sys.exit("sheet XML 里找不到单元格 %s（表结构变了？）" % ref)
            if "<f" in m.group(2):
                sys.exit("单元格 %s 是公式，拒绝覆盖：%r" % (ref, m.group(2)))
            xml = (xml[:m.start()] + m.group(1) + ("<v>%d</v>" % val)
                   + m.group(3) + xml[m.end():])
    tmp = p + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        for n in names:
            data = xml.encode("utf-8") if n == "xl/worksheets/sheet1.xml" else zin.read(n)
            zout.writestr(n, data)
    zin.close()
    os.replace(tmp, p)


def verify_cat(plans_before):
    ck = Checker()
    before = {(p["act"], p["id"]): p for p in plans_before}
    wb = openpyxl.load_workbook(path_of(F_CAT), data_only=True)
    ws = wb[F_CAT] if F_CAT in wb.sheetnames else wb.worksheets[0]
    idx = header_index(ws)
    bad_val, bad_cons, bad_act, seen = [], [], [], set()
    for r, v in iter_data(ws, ROW_START[F_CAT]):
        act = v[idx["ActivityId"]]
        key = (act, v[idx["Id"]])
        if key not in before:
            continue
        seen.add(key)
        p = before[key]
        cons = v[idx["ConsumeValue"]] or 0
        up, down = v[idx["ValueUp"]] or 0, v[idx["ValueDown"]] or 0
        show = v[idx["ShowMax"]] or 0
        if (up != int(round(cons * CAT_UP)) or down != int(round(cons * CAT_DOWN))
                or down > up or show != up):
            bad_val.append((key, cons, down, up, show))
        if cons != p["consume"]:
            bad_cons.append((key, p["consume"], cons))
        if act != p["act"]:
            bad_act.append((key, p["act"], act))
    wb.close()
    ck.add("每轮 ValueUp/ValueDown/ShowMax 与消耗对齐（下限 ≤ 上限 = 展示值）",
           not bad_val, str(bad_val[:4]))
    ck.add("消耗（ConsumeValue）零漂移", not bad_cons, str(bad_cons[:4]))
    ck.add("ActivityId 仍读得到（公式缓存未被抹掉）", not bad_act, str(bad_act[:4]))
    ck.add("落表行数与计划一致", len(seen) == len(before),
           "%d / %d" % (len(seen), len(before)))
    return ck


def print_cat_report(plans):
    by = collections.defaultdict(lambda: {"c": 0, "up": 0, "down": 0,
                                          "old_up": 0, "old_down": 0})
    for p in plans:
        s = by[p["act"]]
        s["c"] += p["consume"]
        s["up"] += p["new_up"]
        s["down"] += p["new_down"]
        s["old_up"] += p["old_up"] or 0
        s["old_down"] += p["old_down"] or 0
    print("   %-6s %-8s %-9s %-18s %-12s %s"
          % ("活动", "轮数", "满次消耗", "改前 下限/上限", "改前期望", "改后 下限/上限 → 期望"))
    for act in sorted(by):
        s = by[act]
        n = len([p for p in plans if p["act"] == act])
        old_exp = (s["old_down"] + s["old_up"]) / 2.0
        new_exp = (s["down"] + s["up"]) / 2.0
        print("   %-6s %-8d %-9d %-18s %-12s %s"
              % (act, n, s["c"],
                 "%d/%d = %.2fx" % (s["old_down"], s["old_up"], s["old_up"] / s["c"]),
                 "%d (%.2fx)" % (old_exp, old_exp / s["c"]),
                 "%d/%d = %.2fx → 期望 %d (%.2fx)"
                 % (s["down"], s["up"], s["up"] / s["c"], new_exp, new_exp / s["c"])))
    print("   单轮明细（活动 %s）：" % plans[0]["act"])
    for p in [x for x in plans if x["act"] == plans[0]["act"]]:
        print("     第 %d 轮 消耗 %-6d 原 %-6s → 新 %d/%d（充 %s 元解锁）"
              % (p["time"], p["consume"],
                 "%d~%d" % (p["old_down"], p["old_up"]),
                 p["new_down"], p["new_up"], p["rmb"]))


# ─────────────────────────── dup（同窗口重复条目）───────────────────────────
# 「同价同内容重复 N 行」不一定是 bug：68 元档有 11 个副本，各挂一章商店活动
# （3#20005 → 3#21005 → 3#30005 …，窗口一周接一周、互不重叠），那是**轮换上架**。
# 唯一可靠的判据是「开放窗口」：窗口一模一样的副本，任何时刻都同时可见、
# 各自 Limit=1 ⇒ 限购语义失效、货架重复占位。窗口互斥的副本保持原样。
DUP_OFF = "1#999#999"


def _gate_act(rule):
    """OnSaleRule 里的 `3#<activityId>`（其余条件类型不管）。"""
    m = re.search(r"(?:^|\|)3#(\d+)", str(rule or "").replace(" ", ""))
    return int(m.group(1)) if m else None


def _act_windows():
    """activityId -> (StartTime, Endtime) 原始字符串；skuId -> activityId 反查。"""
    wb, ws = load(F_ACT)
    idx = header_index(ws)
    win, buy = {}, {}
    for r, v in iter_data(ws, ROW_START[F_ACT]):
        aid = v[idx["Id"]]
        if aid is None:
            continue
        win[aid] = (str(v[idx["StartTime"]] or ""), str(v[idx["Endtime"]] or ""))
        b = str(v[idx["CanBuyRechargeId"]] or "").strip()
        if b.isdigit():
            buy[int(b)] = aid
    wb.close()
    return win, buy


def _all_live_rows():
    """不分 Type 的可售行（dup 要连基金 type=4 一起看）。"""
    billing = _billing_map()
    win, buy = _act_windows()
    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)
    rows = []
    for r, v in iter_data(ws, ROW_START[F_RECHARGE]):
        sid = v[idx["Id"]]
        if sid is None or not billing.get(sid, False):
            continue
        rule = str(v[idx["OnSaleRule"]] or "")
        if rule.replace(" ", "").startswith(DUP_OFF):
            continue
        price = v[idx["Price"]] or 0
        if price <= 0:
            continue
        rewards = pairs_dict(v[idx["BaseReward"]])
        for k, n in pairs_dict(v[idx["ExtraReward"]]).items():
            rewards[k] = rewards.get(k, 0) + n
        act = _gate_act(rule) or buy.get(sid)
        rows.append({
            "row": r, "id": sid, "price": price, "type": v[idx["Type"]],
            "st": v[idx["ShowType"]], "limit": v[idx["Limit"]], "rule": rule,
            "act": act, "win": win.get(act) if act else None,
            "sig": (v[idx["Type"]], price, v[idx["ShowType"]], v[idx["Limit"]],
                    tuple(sorted(rewards.items()))),
        })
    wb.close()
    return rows


def plan_dup():
    """同一 (内容, 价格, 页签, 限购, 开放窗口) 的副本只留最 id 小的一行。"""
    rows = _all_live_rows()
    groups = collections.defaultdict(list)
    for x in rows:
        groups[(x["sig"], x["win"])].append(x)
    gates, out = [], []
    for (sig, win), xs in groups.items():
        if len(xs) < 2:
            continue
        xs = sorted(xs, key=lambda x: x["id"])
        out.append({"keep": xs[0], "drop": xs[1:], "win": win})
        for x in xs[1:]:
            gates.append({"row": x["row"], "id": x["id"], "price": x["price"],
                          "type": x["type"], "st": x["st"], "rule": x["rule"],
                          "keep": xs[0]["id"]})
    out.sort(key=lambda g: -len(g["drop"]))
    return gates, out


def apply_dup(gates):
    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)
    col = idx["OnSaleRule"]
    for g in gates:
        ws.cell(g["row"], col + 1).value = DUP_OFF
    wb.save(path_of(F_RECHARGE))
    wb.close()


def verify_dup(gates, groups):
    ck = Checker()
    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)
    col = idx["OnSaleRule"]
    want = {g["id"]: g for g in gates}
    cur = {}
    for r, v in iter_data(ws, ROW_START[F_RECHARGE]):
        sid = v[idx["Id"]]
        if sid in want:
            cur[sid] = (r, str(v[idx["OnSaleRule"]] or "").replace(" ", ""), v[idx["Price"]])
    wb.close()

    ck.add("落表行数与计划一致", len(cur) == len(gates), "%d / %d" % (len(cur), len(gates)))
    bad = [sid for sid, (_r, rule, _p) in cur.items() if rule != DUP_OFF]
    ck.add("重复行已改为 %s" % DUP_OFF, not bad, str(bad[:5]))
    drift = [(sid, want[sid]["price"], p) for sid, (_r, _rule, p) in cur.items()
             if p != want[sid]["price"]]
    ck.add("价格零漂移", not drift, str(drift[:5]))

    again, _ = plan_dup()
    ck.add("再跑一次规划应无待关停", not again, "%d 行" % len(again))

    live = _all_live_rows()
    fund = [x for x in live if x["type"] == 4 and x["price"] == FUND_PRICE]
    ck.add("成长基金同刻只剩 1 个可买（原 5 个）", len(fund) == 1,
           str([x["id"] for x in fund]))

    by_group = collections.Counter()
    sig_of = {x["id"]: (x["sig"], x["win"]) for x in live}
    for x in live:
        by_group[sig_of[x["id"]]] += 1
    ck.add("同窗口同内容最多 1 行在售", max(by_group.values() or [0]) <= 1,
           "最大 %d" % max(by_group.values() or [0]))
    print("   货架：%d → %d 行（关停 %d 行）"
          % (len(live) + len(gates), len(live), len(gates)))
    return ck


def print_dup_report(gates, groups):
    print("   判据：同 (内容, 价格, 页签, 限购, 开放窗口) ⇒ 任何时刻同时可见")
    print("   %-5s %-6s %-4s %-22s %s" % ("价格", "副本", "页签", "开放窗口", "保留/关停"))
    for g in groups:
        k = g["keep"]
        win = "无活动绑定" if not g["win"] else "%s~%s" % g["win"]
        print("   %-5s ×%-5d %-4s %-22s 留 %s / 关 %s"
              % (k["price"], len(g["drop"]) + 1, k["st"], win[:22], g["keep"]["id"],
                 ",".join(str(x["id"]) for x in g["drop"])[:46]))
    print("   合计关停 %d 行，货架无价值损失（重复行内容完全相同）" % len(gates))


# ─────────────────────────── mono（族内阶梯单调）───────────────────────────
# R14 的 cap 只收「同价档内」的离群件。「同族里大额档反而比小额档差」是另一条轴，
# 上一轮一件没动，还剩 15 处（最深 -13.3%）。
#
# 逐个补价补不干净：抬了 12 元就顶到 6 元，抬了 18 元又顶到 30 元，一路连锁抬高整条带
# （R12 那次估的 A 案要一次性多给 1.03 万钻 = 11% 让利，就是这么来的）。
#
# 正确做法是 PAVA（pool adjacent violators）：在「每档中位抽/元」这条阶梯上做
# **加权最小二乘的保序回归**，权重 = 该档条目数。一次同时算出「抬谁、削谁」：
#   · 净价值变化接近 0 —— 削下来的正好付了抬上去的，不往经济里灌通胀；
#   · 移动量最小 —— 只把错位的档掰正，不动整条带的水平。
# 两个硬约束：每个族的最低价档**只许涨不许削**（新手带是刻意的转化锚）；
# 单档调整幅度 >15% 就跳过并报告（那不是错位，是两条产品线的形态差异）。
MONO2_TOL = 0.015          # 收敛判据：跌幅 ≤1.5% 视为已平
MONO2_MAX_MOVE = 0.35      # 单档最大调整幅度（18 元档这种「谷」需要 +27% 才回到带上）
MONO2_MIN_PULL = 0.05      # 小于 0.05 抽（11 钻）不动，免得刷无意义 diff
MONO2_ROUNDS = 5


def _pava(vals, wts):
    """保序回归（非递减）。返回等长拟合值。"""
    stack = []
    for v, w in zip(vals, wts):
        stack.append([v, w, 1])
        while len(stack) > 1 and stack[-2][0] > stack[-1][0] + 1e-12:
            v2, w2, c2 = stack.pop()
            v1, w1, c1 = stack.pop()
            tw = w1 + w2
            stack.append([(v1 * w1 + v2 * w2) / tw, tw, c1 + c2])
    out = []
    for v, _w, c in stack:
        out.extend([v] * c)
    return out


def _levels(rows):
    """ShowType -> [{price, rate(中位), rows}]，价格升序；单档族不参与。"""
    fam = collections.defaultdict(lambda: collections.defaultdict(list))
    for x in rows:
        fam[x["st"]][x["price"]].append(x)
    out = {}
    for st, byp in fam.items():
        lv = []
        for p in sorted(byp):
            mem = [x["rate"] for x in byp[p] if x["pull"] > 0]
            if mem:
                lv.append({"price": p, "rate": statistics.median(mem), "rows": byp[p]})
        if len(lv) >= 2:
            out[st] = lv
    return out


def _level_moves(levels):
    med = [x["rate"] for x in levels]
    if all(med[i + 1] >= med[i] * (1 - MONO2_TOL) for i in range(len(med) - 1)):
        return [], []
    wts = [len(x["rows"]) for x in levels]
    fit = [math.exp(v) for v in _pava([math.log(max(m, 1e-9)) for m in med], wts)]
    fit[0] = max(fit[0], med[0])                 # 最低价档只许涨
    for i in range(1, len(fit)):
        fit[i] = max(fit[i], fit[i - 1])
    moves, skipped = [], []
    for i, lv in enumerate(levels):
        if not med[i]:
            continue
        chg = fit[i] / med[i] - 1
        if abs(chg) <= 1e-9:
            continue
        if abs(chg) > MONO2_MAX_MOVE:
            skipped.append({"price": lv["price"], "chg": chg, "rate": med[i]})
            continue
        if abs(chg) * lv["price"] < MONO2_MIN_PULL:
            continue
        moves.append({"price": lv["price"], "from": med[i], "to": fit[i],
                      "chg": chg, "rows": lv["rows"]})
    return moves, skipped


def plan_mono():
    rows = _live_pack_rows()
    for x in rows:
        x["pull0"] = x["pull"]
        x["shift"] = 0.0
    skipped, trail, filled = [], [], []
    for _ in range(MONO2_ROUNDS):
        for x in rows:
            x["pull"] = x["pull0"] + x["shift"]
            x["rate"] = x["pull"] / x["price"] if x["price"] else 0.0
        moved = 0
        # ① 补谷：R14 的 cap 只削峰，被压到「本档中位 -20%」以下的没人管。
        # 这些行落在「单价位族」里（PAVA 不覆盖），成了档内的下界，
        # 会把「同价离散」撑大（18 元 0.1702 vs 0.2813 = 1.65x）。
        center = _tier_center(rows)
        for x in rows:
            if x["type"] != PACK_TYPE or x["price"] not in center:
                continue
            floor = center[x["price"]] * (1 - FLOOR_TOL)
            if x["rate"] >= floor - 1e-9:
                continue
            dpull = (floor - x["rate"]) * x["price"]
            # 取整必须向上：round() 会少给 ≤5 钻，12 元档就是 0.023 抽（0.2%），
            # 落表后仍然踩在本档中位 −20% 线下方，自检必红。
            # 同一类问题和 cap 的「券只能整张」一样：粒度决定方向，宁可偏上。
            dia = int(math.ceil(dpull * DIA_PER_PULL / 10.0 - 1e-9) * 10)
            # 补谷也不许越过单档幅度上限，否则一个离群件会把整档形态带歪。
            room = int(math.floor((MONO2_MAX_MOVE * x["pull0"] - x["shift"])
                                  * DIA_PER_PULL / 10.0) * 10)
            dia = min(dia, max(room, 0))
            if dpull < MONO2_MIN_PULL or dia <= 0:
                continue
            x["shift"] += dia / float(DIA_PER_PULL)
            filled.append({"id": x["id"], "price": x["price"], "dia": dia,
                           "from": x["rate"],
                           "to": (x["pull0"] + x["shift"]) / float(x["price"])})
            moved += 1
        # ② 阶梯
        for st, levels in sorted(_levels(rows).items()):
            moves, sk = _level_moves(levels)
            skipped.extend([dict(s, st=st) for s in sk])
            for m in moves:
                dia = int(round(m["chg"] * m["from"] * m["price"]
                                * DIA_PER_PULL / 10.0) * 10)
                if dia == 0:
                    continue
                for x in m["rows"]:
                    x["shift"] += dia / float(DIA_PER_PULL)
                trail.append({"st": st, "price": m["price"], "from": m["from"],
                              "to": m["to"], "dia": dia, "n": len(m["rows"])})
                moved += 1
        if not moved:
            break

    edits, blocked = [], []
    for x in rows:
        dia = int(round(x["shift"] * DIA_PER_PULL / 10.0) * 10)
        if dia == 0:
            continue
        have = pairs_dict(x["base"]).get(DIA, 0) or 0
        if dia < 0 and have < -dia:
            blocked.append({"id": x["id"], "price": x["price"],
                            "need": -dia, "have": have})
            continue
        base = add_items(x["base"], {DIA: dia}) if dia > 0 else sub_items(x["base"], {DIA: -dia})
        show = x["show"]
        if str(show).strip() and DIA in pairs_dict(show):
            show = add_items(show, {DIA: dia}) if dia > 0 else sub_items(show, {DIA: -dia})
        edits.append({"row": x["row"], "id": x["id"], "price": x["price"], "st": x["st"],
                      "dia": dia, "before": x["pull0"],
                      "after": x["pull0"] + dia / float(DIA_PER_PULL),
                      "base": base, "show": show,
                      "base_old": x["base"], "show_old": x["show"]})
    return edits, {"trail": trail, "skipped": skipped, "blocked": blocked,
                   "filled": filled, "rows": rows,
                   "gated": set(x["id"] for x in rows) - set(e["id"] for e in edits)}


def apply_mono(edits):
    wb, ws = load(F_RECHARGE)
    idx = header_index(ws)
    c_base, c_show = idx["BaseReward"], idx["RewardShow"]
    for e in edits:
        ws.cell(e["row"], c_base + 1).value = e["base"]
        if str(e["show_old"]).strip():
            ws.cell(e["row"], c_show + 1).value = e["show"]
    wb.save(path_of(F_RECHARGE))
    wb.close()


def verify_mono(edits, meta):
    ck = Checker()
    before = {x["id"]: x for x in meta["rows"]}
    cur = {x["id"]: x for x in _live_pack_rows()}

    ck.add("落表行数与计划一致", len(edits) <= len(cur),
           "%d / %d（可售 %d）" % (len(edits), len(meta["rows"]), len(cur)))
    missing = [e["id"] for e in edits if e["id"] not in cur]
    ck.add("被改的行都还在可售列表里", not missing, str(missing[:5]))

    drift_p = [e["id"] for e in edits
               if e["id"] in cur and cur[e["id"]]["price"] != e["price"]]
    ck.add("价格零漂移", not drift_p, str(drift_p[:5]))

    drift, grow = [], []
    for e in edits:
        n = cur.get(e["id"])
        if n is None:
            continue
        old = {k: v for k, v in before[e["id"]]["rewards"].items() if k != DIA}
        new = {k: v for k, v in n["rewards"].items() if k != DIA}
        if old != new:
            drift.append((e["id"], sorted(set(old) ^ set(new))[:3]))
    ck.add("券与其他道具构成零漂移（只动钻石）", not drift, str(drift[:5]))

    zero = []
    for e in edits:
        for raw in (e["base"], e["show"]):
            for k, n in parse_pairs(raw):
                if n == 0:
                    zero.append((e["id"], k))
    ck.add("没有 *0 的残留条目", not zero, str(zero[:5]))

    worst, where = 0.0, ""
    for st, levels in _levels(list(cur.values())).items():
        for a, b in zip(levels, levels[1:]):
            drop = 1 - b["rate"] / a["rate"] if a["rate"] else 0
            if drop > worst:
                worst, where = drop, "ST%s %d→%d 元" % (st, a["price"], b["price"])
    ck.add("同族阶梯无跌幅 >%.1f%% 的倒挂" % (MONO2_TOL * 100), worst <= MONO2_TOL + 1e-9,
           "最深 %.1f%% %s" % (worst * 100, where))

    center = _tier_center([{"price": x["price"], "rate": x["rate"], "pull": x["pull"],
                            "type": x["type"]} for x in cur.values()])
    under = [(sid, round(x["rate"], 4), round(center[x["price"]] * (1 - FLOOR_TOL), 4))
             for sid, x in cur.items()
             if x["type"] == PACK_TYPE and x["price"] in center and x["pull"] > 0
             and x["rate"] < center[x["price"]] * (1 - FLOOR_TOL) - 0.01]
    ck.add("没有 SKU 仍低于本档中位 -%.0f%%（补谷）" % (FLOOR_TOL * 100),
           not under, str(under[:5]))

    big = [(e["id"], round(e["after"] / e["before"] - 1, 4)) for e in edits
           if e["before"] and abs(e["after"] / e["before"] - 1) > MONO2_MAX_MOVE + 1e-6]
    ck.add("单行调整幅度 ≤%.0f%%" % (MONO2_MAX_MOVE * 100), not big, str(big[:5]))

    low_cut = []
    for st, levels in _levels(meta["rows"]).items():
        ids = set(x["id"] for x in levels[0]["rows"])
        for e in edits:
            if e["id"] in ids and e["dia"] < 0:
                low_cut.append((st, levels[0]["price"], e["id"]))
    ck.add("每个族的最低价档只涨不削", not low_cut, str(low_cut[:5]))

    # 通胀核算的分母必须是「抽等值」而不是钻存量：礼包价值大头是券和道具，
    # 只拿钻石当分母会把一次 +66 抽的微调算成 4% 通胀（其实是 1.x%）。
    # 也不能拿「被改的这几行自己」当分母：补谷只碰 6 行、共 18 抽，
    # +2 抽就成了 +11%，但相对受影响的两个档位（85 抽）只有 +2.4%。
    tiers = set(e["price"] for e in edits)
    mass = sum(x["pull"] for x in cur.values()
               if x["price"] in tiers and x["type"] == PACK_TYPE) or 0
    net = sum(e["dia"] for e in edits) / float(DIA_PER_PULL)
    ck.add("净增价值 ≤ 受影响档位存量的 3%（不灌通胀）",
           net <= max(0.03 * mass, 1.0),
           "净 %+.1f 抽 / %s 档存量 %.0f 抽（%+.2f%%）"
           % (net, "/".join(str(p) for p in sorted(tiers)), mass,
              100.0 * net / mass if mass else 0))
    return ck


def print_mono_report(edits, meta):
    print("   口径：PAVA 保序回归（权重=条数），最低价档只涨不削，单档上限 ±%.0f%%"
          % (MONO2_MAX_MOVE * 100))
    if meta["skipped"]:
        uniq = {}
        for s in meta["skipped"]:
            uniq[(s["st"], s["price"])] = s
        print("   ⚠ 超幅跳过 %d 档（形态差异，不是错位）：%s"
              % (len(uniq),
                 ", ".join("ST%s %s元 %+.0f%%" % (s["st"], s["price"], s["chg"] * 100)
                           for s in list(uniq.values())[:6])))
    if meta["blocked"]:
        print("   ⚠ 钻石不够扣、未执行 %d 行：%s"
              % (len(meta["blocked"]),
                 ", ".join("%s 需%d有%d" % (b["id"], b["need"], b["have"])
                           for b in meta["blocked"][:5])))
    if not edits:
        print("   全部达标，无需改动。")
        return
    by = collections.defaultdict(lambda: {"n": 0, "dia": 0})
    for e in edits:
        k = e["st"]
        by[k]["n"] += 1
        by[k]["dia"] += e["dia"]
    print("   共改 %d 行：净钻石 %+d（抬 %d 行 / 削 %d 行），其中补谷 %d 行"
          % (len(edits), sum(e["dia"] for e in edits),
             sum(1 for e in edits if e["dia"] > 0),
             sum(1 for e in edits if e["dia"] < 0),
             len(set(f["id"] for f in meta.get("filled") or []))))
    for st in sorted(by):
        print("      ST%-4s %3d 行  净 %+6d 钻" % (st, by[st]["n"], by[st]["dia"]))
    top = sorted(edits, key=lambda e: -abs(e["after"] / e["before"] - 1))[:8]
    print("   %-6s %-5s %-4s %-9s %-9s %s" % ("id", "价格", "页签", "改前抽", "改后抽", "幅度"))
    for e in top:
        print("   %-6s %-5s %-4s %-9.2f %-9.2f %+.1f%%"
              % (e["id"], e["price"], e["st"], e["before"], e["after"],
                 (e["after"] / e["before"] - 1) * 100 if e["before"] else 0))


# ─────────────────────────── 报告 ───────────────────────────

def print_pack_report(plans, skipped):
    if not plans:
        print("   （无需要补券的礼包）")
        return
    by = {}
    for p in plans:
        by.setdefault(p["price"], []).append(p)
    print("   %-6s %-5s %-9s %-9s %-6s %-8s" % ("价格", "件数", "改前中位", "改后中位", "补券", "实际倍数"))
    tot = 0
    for price in sorted(by):
        rows = by[price]
        b = statistics.median([x["pull"] / price for x in rows])
        a = statistics.median([x["pull_after"] / price for x in rows])
        add = sum(x["add"] for x in rows)
        tot += add
        print("   %-6s %-5d %-9.4f %-9.4f %-6d x%.3f"
              % (price, len(rows), b, a, add, a / b))
    print("   合计补券 %d 张 / %d 个礼包" % (tot, len(plans)))
    for reason, n in skipped.items():
        print("   跳过 %-4d 个：%s" % (n, reason))


def print_store_report(plans, already):
    if not plans:
        print("   （无需要改价的券）")
        return
    print("   %-6s %-8s %-7s %-7s %-8s" % ("行 id", "商品", "改前", "改后", "折扣"))
    for p in sorted(plans, key=lambda x: (x["n"], x["id"])):
        print("   %-6s %-8s %-7d %-7d -%.1f%%"
              % (p["id"], "19#%d" % p["n"], p["old"], p["new"],
                 (1 - p["new"] / float(p["old"])) * 100))
    print("   共 %d 行降价；已合规跳过 %d 行" % (len(plans), already))


def print_lux_report(plans, show):
    dia79, tic79, days = _fund_total(LUX_TYPE_OLD)
    new_dia = dia79 + (LUX_DAY_NEW - LUX_DAY_OLD) * len(plans)
    print("   Type=79 日领 %d → %d，%d 天" % (LUX_DAY_OLD, LUX_DAY_NEW, len(plans)))
    print("   30 天钻石 %d → %d（+%d），券 %d 张不变" % (dia79, new_dia, new_dia - dia79, tic79))
    if show:
        sku_base = int(LUX_SKU_SHOW.split("#")[1]) - LUX_DAY_OLD * len(plans)
        print("   SKU 79 的 RewardShow 同步 → 16#%d（= 底包 %d + 日领 %d）"
              % (new_dia + sku_base, sku_base, new_dia))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--force", action="store_true",
                    help="强制执行已经落过表的项（会叠加乘数，慎用）")
    ap.add_argument("--verify-only", action="store_true")
    ap.add_argument("--only", default="fund,pack,store,lux328,dup,cap,mono,cat",
                    help="逗号分隔：fund,pack,store,lux328,dup,cap,mono,cat")
    ap.add_argument("--revert", metavar="DIR")
    ap.add_argument("--list-backups", action="store_true")
    args = ap.parse_args()

    if args.list_backups:
        if not os.path.isdir(BACKUP_ROOT):
            print("没有备份")
            return 0
        for d in sorted(os.listdir(BACKUP_ROOT)):
            print(os.path.join(BACKUP_ROOT, d))
        return 0

    if args.revert:
        d = args.revert
        if not os.path.isdir(d):
            sys.exit("备份目录不存在：%s" % d)
        for f in os.listdir(d):
            shutil.copy2(os.path.join(d, f), os.path.join(BASE, f))
        print("已回滚 %d 个文件 ← %s" % (len(os.listdir(d)), d))
        return 0

    items = [x.strip() for x in args.only.split(",") if x.strip()]
    unknown = set(items) - {"fund", "pack", "store", "lux328", "cap", "cat",
                            "mono", "dup"}
    if unknown:
        sys.exit("未知选项：%s" % unknown)

    print("=" * 62)
    print("R13/R14/R15 结构性定价修复  items=%s  mode=%s"
          % (",".join(items),
             "verify" if args.verify_only else ("apply" if args.apply else "dry-run")))
    print("=" * 62)

    if args.apply:
        guard(items, args.force)

    ok = True

    # ── fund ──────────────────────────────────────────────
    if "fund" in items:
        plans = plan_fund()
        print("\n[fund] 成长基金节点统一")
        by_act = {}
        for p in plans:
            by_act.setdefault(p["act"], []).append(p)
        for act in sorted(by_act):
            rows = by_act[act]
            old = sum(x["old_dia"] for x in rows)
            print("   活动 %-4s 节点 %2d 个  %5d 钻 → %5d 钻   %.3f → %.3f 抽/元"
                  % (act, len(rows), old, FUND_NODE_DIA * 10,
                     old / DIA_PER_PULL / FUND_PRICE,
                     FUND_NODE_DIA * 10 / DIA_PER_PULL / FUND_PRICE))
        if args.apply:
            bak = backup([path_of(F_REWARD)])
            print("   备份 → %s" % bak)
            apply_fund(plans)
            c = verify_fund()
            if not c.dump():
                _restore(bak)
                sys.exit("❌ fund 自检失败，已自动回滚")
            save_marker(["fund"], bak)
            ok &= c.ok
        elif args.verify_only:
            c = verify_fund()
            ok &= c.dump()

    # ── pack ──────────────────────────────────────────────
    plans_pack = []
    if "pack" in items:
        plans_pack, skipped = plan_pack()
        print("\n[pack] 礼包带 ×%.2f（只加券，钻石不动）" % PACK_MULT)
        print_pack_report(plans_pack, skipped)
        if args.apply and plans_pack:
            bak = backup([path_of(F_RECHARGE)])
            print("   备份 → %s" % bak)
            apply_pack(plans_pack)
            c = verify_pack(plans_pack)
            if not c.dump():
                _restore(bak)
                sys.exit("❌ pack 自检失败，已自动回滚")
            save_marker(["pack"], bak)
            ok &= c.ok
        elif not args.apply:
            print("   示例（前 6 个）：")
            for p in plans_pack[:6]:
                print("     id=%-6s %s 元  +%s#%d → %.3f 抽/元"
                      % (p["id"], p["price"], p["ticket"], p["add"],
                         p["pull_after"] / p["price"]))
        elif args.verify_only:
            print("   （verify-only 不做逐项比对，用 audit 脚本核对结果）")

    # ── store ─────────────────────────────────────────────
    if "store" in items:
        plans_store, already = plan_store()
        print("\n[store] 紫晶卡钻石标价 → 单抽 220 / 十连 2000")
        print_store_report(plans_store, already)
        if args.apply and plans_store:
            bak = backup([path_of(F_STORE)])
            print("   备份 → %s" % bak)
            apply_store(plans_store)
            c = verify_store(plans_store)
            if not c.dump():
                _restore(bak)
                sys.exit("❌ store 自检失败，已自动回滚")
            save_marker(["store"], bak)
            ok &= c.ok
        elif args.verify_only:
            c = verify_store([])
            ok &= c.dump()

    # ── lux328 ────────────────────────────────────────────
    if "lux328" in items:
        lux_plans, lux_show = plan_lux()
        print("\n[lux328] 豪华基金 328 元拉平")
        print_lux_report(lux_plans, lux_show)
        if args.apply:
            bak = backup([path_of(F_FUND), path_of(F_RECHARGE)])
            print("   备份 → %s" % bak)
            apply_lux(lux_plans, lux_show)
            c = verify_lux()
            if not c.dump():
                _restore(bak)
                sys.exit("❌ lux328 自检失败，已自动回滚")
            save_marker(["lux328"], bak)
            ok &= c.ok
        elif args.verify_only:
            c = verify_lux()
            ok &= c.dump()

    # ── dup ───────────────────────────────────────────────
    if "dup" in items:
        gates, groups = plan_dup()
        print("\n[dup] 同窗口重复条目关停（限购 1 语义复原）")
        print_dup_report(gates, groups)
        if args.apply and gates:
            bak = backup([path_of(F_RECHARGE)])
            print("   备份 → %s" % bak)
            with open(os.path.join(bak, "_dup_rule_originals.json"), "w",
                      encoding="utf-8") as fh:
                import json
                json.dump([{"id": g["id"], "row": g["row"], "rule": g["rule"]}
                           for g in gates], fh, ensure_ascii=False, indent=2)
            apply_dup(gates)
            c = verify_dup(gates, groups)
            if not c.dump():
                _restore(bak)
                sys.exit("❌ dup 自检失败，已自动回滚")
            save_marker(["dup"], bak)
            ok &= c.ok
        elif args.verify_only:
            c = verify_dup(gates, groups)
            ok &= c.dump()
            print("   （verify-only：再跑一次规划应无待关停）%s"
                  % ("✅" if not gates else "✗ 仍有 %d 行" % len(gates)))

    # ── cap ───────────────────────────────────────────────
    if "cap" in items:
        cuts, meta = plan_cap()
        print("\n[cap] 削峰：档内收敛 + 同族单调")
        print_cap_report(cuts, meta)
        if args.apply and cuts:
            bak = backup([path_of(F_RECHARGE)])
            print("   备份 → %s" % bak)
            apply_cap(cuts)
            c = verify_cap(cuts, meta["skipped"])
            if not c.dump():
                _restore(bak)
                sys.exit("❌ cap 自检失败，已自动回滚")
            save_marker(["cap"], bak)
            ok &= c.ok
        elif args.verify_only:
            # 削完之后再跑一次 plan 应该是空的；再核一遍硬约束
            c = verify_cap([], meta["skipped"])
            ok &= c.dump()
            print("   （verify-only：再跑一次规划应无落刀）%s"
                  % ("✅" if not cuts else "✗ 仍有 %d 个待削" % len(cuts)))

    # ── mono ──────────────────────────────────────────────
    if "mono" in items:
        edits, meta = plan_mono()
        print("\n[mono] 同族阶梯单调（PAVA 保序回归，抬低档 / 削高档联动）")
        print_mono_report(edits, meta)
        if args.apply and edits:
            bak = backup([path_of(F_RECHARGE)])
            print("   备份 → %s" % bak)
            apply_mono(edits)
            c = verify_mono(edits, meta)
            if not c.dump():
                _restore(bak)
                sys.exit("❌ mono 自检失败，已自动回滚")
            save_marker(["mono"], bak)
            ok &= c.ok
        elif args.verify_only:
            c = verify_mono(edits, meta)
            ok &= c.dump()
            print("   （verify-only：再跑一次规划应无待掰档）%s"
                  % ("✅" if not edits else "✗ 仍有 %d 行" % len(edits)))

    # ── cat ───────────────────────────────────────────────
    if "cat" in items:
        cat_plans = plan_cat()
        print("\n[cat] 招财猫：保底返本 + 上限 +%.0f%%（现 1.33~1.67x → 1.00~%.2fx）"
              % ((CAT_UP - 1) * 100, CAT_UP))
        print_cat_report(cat_plans)
        if args.apply:
            bak = backup([path_of(F_CAT)])
            print("   备份 → %s" % bak)
            apply_cat(cat_plans)
            c = verify_cat(cat_plans)
            if not c.dump():
                _restore(bak)
                sys.exit("❌ cat 自检失败，已自动回滚")
            save_marker(["cat"], bak)
            ok &= c.ok
        elif args.verify_only:
            c = verify_cat(cat_plans)
            ok &= c.dump()

    if not args.apply and not args.verify_only:
        print("\n[dry-run] 未写盘。确认无误后加 --apply。")
    elif args.apply:
        print("\n✅ 落表完成。回滚：--revert <backup_dir>（--list-backups 查看）")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
