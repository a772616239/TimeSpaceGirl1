# -*- coding: utf-8 -*-
"""
挂机奖励配置优化工具（FightAreaRewardFullPopup / 秘境挂机收益）

背景
----
挂机收益每分钟结算一次（GameSetting.AdventureRefresh=60），最多累积
AdventureOffline=12 小时 => 单次领取最多 times=720 次结算。每次结算会把
MainLevelConfig.RandomReward 里的**所有**掉落组各 roll 一次。

噩梦难度该列表有 23 个组，其中：
  * 1 个是纯空转组（id=1，只有一条 item14 chance=1 / min=0 / max=0，永远不出货）
  * 13 个是装备品质组（20004~20017），每组都是「11200 空 + 11300 空 + 4×真物品」

18 条 RandomReward 取值其实是**按难度开装备组前缀**（简单只开 20004，噩梦开满 13 个）。

本工具做三件事：
  1. 剔除空转组 1（零风险，12h 白跑 720 次）；
  2. 把装备组按「难度组合」合并（等值换算权重池，RewardMaxNum 仍为 1）：
       20101 绿蓝   <- 20004~20007             （困难/噩梦共用）
       20102 紫橙红 <- 20008~20010,20012~20017 （噩梦）
       20103 困难档 <- 20004~20010,20012~20016 （困难）
     => 噩梦 23 组 -> 11 组，困难 22 组 -> 11 组；
  3. 装备掉率按难度分层缩放（默认 ×1/3）：简单/普通**不动**（新手期靠挂机出装备），
     困难/地狱/噩梦降到 1/3 —— 32 件/12h -> 11 件/12h，道具种类 27 -> 17。

用法
----
    python scripts/adventure_reward_tune.py                            # dry-run
    python scripts/adventure_reward_tune.py --apply                    # 写回（先备份，落表后自检）
    python scripts/adventure_reward_tune.py --apply --equip-scale 0.5  # 只降一半

写完 xlsx 后需要在 Unity 里用 Assets/Scripts/Editor/ExcelTool/DataConfig 重新导表。
"""

from __future__ import annotations

import argparse
import os
import shutil
from collections import Counter, OrderedDict

import openpyxl

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "data_execl", "base_data")

F_MAIN = os.path.join(BASE, "MainLevelConfig.xlsx")
F_GROUP = os.path.join(BASE, "RewardGroup.xlsx")
F_ITEM = os.path.join(BASE, "RewardItemConfig.xlsx")

NOOP_GROUPS = {1}          # 永远不出货的占位组

# 13 个装备品质组（按品质从低到高）
EQUIP_ALL = [20004, 20005, 20006, 20007, 20008, 20009, 20010,
             20012, 20013, 20014, 20015, 20016, 20017]
EQUIP_HARD = [g for g in EQUIP_ALL if g != 20017]          # 困难：缺红2星

MERGE_PLANS = OrderedDict([
    (20101, dict(src=[20004, 20005, 20006, 20007], name="绿蓝")),
    (20102, dict(src=[20008, 20009, 20010, 20012, 20013, 20014, 20015, 20016, 20017],
                 name="紫橙红")),
    (20103, dict(src=EQUIP_HARD, name="困难档")),
])

MERGE_TOTAL_WEIGHT = 1_000_000
NEW_RID_BASE = 990000
TOL = 1e-5
HEADER_ROWS = 6


def _num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def load_groups():
    wb = openpyxl.load_workbook(F_GROUP)
    ws = wb.worksheets[0]
    groups = {}
    for row_idx in range(HEADER_ROWS + 1, ws.max_row + 1):
        gid = ws.cell(row_idx, 2).value
        if gid is None:
            continue
        try:
            gid = int(float(gid))
        except (TypeError, ValueError):
            continue
        groups[gid] = {
            "row": row_idx,
            "info": ws.cell(row_idx, 3).value,
            "rule": ws.cell(row_idx, 4).value,
            "items": [int(float(x)) for x in str(ws.cell(row_idx, 5).value).split("#") if x.strip()],
            "max_kinds": ws.cell(row_idx, 6).value,
        }
    return wb, ws, groups


def load_items():
    wb = openpyxl.load_workbook(F_ITEM)
    ws = wb.worksheets[0]
    items = {}
    for row_idx in range(HEADER_ROWS + 1, ws.max_row + 1):
        rid = ws.cell(row_idx, 2).value
        if rid is None:
            continue
        try:
            rid = int(float(rid))
        except (TypeError, ValueError):
            continue
        item_id = _num(ws.cell(row_idx, 3).value)
        if item_id is None:
            continue
        items[rid] = {
            "row": row_idx,
            "item_id": int(item_id),
            "chance": float(ws.cell(row_idx, 4).value or 0),
            "grow": ws.cell(row_idx, 5).value,
            "min": ws.cell(row_idx, 6).value,
            "max": ws.cell(row_idx, 7).value,
            "addition": ws.cell(row_idx, 8).value,
            "chance_addition": ws.cell(row_idx, 9).value,
            "info": ws.cell(row_idx, 10).value,
            "note1": ws.cell(row_idx, 11).value,
            "note2": ws.cell(row_idx, 12).value,
        }
    return wb, ws, items


def load_levels():
    wb = openpyxl.load_workbook(F_MAIN)
    ws = wb.worksheets[0]
    hdr = [c.value for c in ws[1]]
    col_id = hdr.index("Id") + 1
    col_rr = hdr.index("RandomReward") + 1
    levels = []
    for row_idx in range(HEADER_ROWS + 1, ws.max_row + 1):
        fid = ws.cell(row_idx, col_id).value
        if fid is None:
            continue
        levels.append({
            "row": row_idx,
            "id": int(float(fid)),
            "random_reward": str(ws.cell(row_idx, col_rr).value or ""),
        })
    return wb, ws, levels, col_rr


def group_pool(group, items):
    out = []
    for rid in group["items"]:
        it = items.get(rid)
        if not it:
            continue
        out.append((it["item_id"], it["chance"], int(float(it["min"] or 0)), int(float(it["max"] or 0))))
    return out


def expected_per_tick(gids, groups, items):
    exp = Counter()
    for gid in gids:
        g = groups.get(gid)
        if not g:
            continue
        pool = group_pool(g, items)
        total = sum(p[1] for p in pool)
        if total <= 0:
            continue
        if int(float(g["rule"] or 0)) == 1:
            for item_id, chance, lo, hi in pool:
                if hi > 0:
                    exp[item_id] += lo
            continue
        for item_id, chance, lo, hi in pool:
            if hi > 0:
                exp[item_id] += chance / total * lo
    return exp


def build_merged_group(src_gids, groups, items, scale):
    """把 src_gids 合并成新组；装备掉率整体乘 scale。"""
    per_item = OrderedDict()
    meta = {}
    for gid in src_gids:
        g = groups[gid]
        pool = group_pool(g, items)
        total = sum(p[1] for p in pool)
        if total <= 0:
            continue
        for rid in g["items"]:
            it = items.get(rid)
            if not it:
                continue
            per_item[rid] = per_item.get(rid, 0.0) + it["chance"] / total
            meta[rid] = it

    real = [(rid, p) for rid, p in per_item.items() if int(float(meta[rid]["max"] or 0)) > 0]
    weights = [(rid, max(1, int(round(p * MERGE_TOTAL_WEIGHT)))) for rid, p in real]
    used = sum(w for _, w in weights)
    if used >= MERGE_TOTAL_WEIGHT:
        raise SystemExit("合并后权重溢出，请调大 MERGE_TOTAL_WEIGHT")

    # 原概率 = used/T；目标 = scale*used/T
    # used/(used+F') = scale*used/T  =>  F' = T/scale - used
    filler = int(round(MERGE_TOTAL_WEIGHT / scale)) - used
    if filler <= 0:
        raise SystemExit("空位权重计算异常")
    return weights, filler, meta


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="写回 xlsx（默认 dry-run）")
    ap.add_argument("--equip-scale", type=float, default=1.0 / 3.0,
                    help="困难及以上的装备掉率倍数，默认 1/3；1.0 表示只合并不降掉率")
    args = ap.parse_args()
    scale = args.equip_scale

    gw, gws, groups = load_groups()
    iw, iws, items = load_items()
    mw, mws, levels, col_rr = load_levels()
    print(f"RewardGroup {len(groups)} 组 / RewardItemConfig {len(items)} 条 / 关卡 {len(levels)} 行 / "
          f"装备掉率 x{scale:.3f}")

    for new_gid, plan in MERGE_PLANS.items():
        missing = [g for g in plan["src"] if g not in groups]
        if missing:
            raise SystemExit(f"{new_gid} 源组缺失 {missing}")
        if new_gid in groups:
            raise SystemExit(f"{new_gid} 已存在，请换号")

    # ---- 逐条列表决定合并方式 ----
    all_set = set(EQUIP_ALL)
    hard_set = set(EQUIP_HARD)
    mapping = {}
    stat = Counter()
    for old in {lv["random_reward"] for lv in levels}:
        gids = [int(float(t)) for t in old.split("#") if t.strip()]
        s = set(gids)
        if all_set.issubset(s):
            repl, kind = [20101, 20102], "噩梦/地狱"
        elif hard_set.issubset(s):
            repl, kind = [20103], "困难"
        else:
            repl, kind = None, "不动"
        stat[kind] += 1

        new_tokens = []
        for gid in gids:
            if gid in NOOP_GROUPS:
                continue
            if repl is not None and gid in (all_set | hard_set):
                continue          # 装备组统一由 repl 顶替
            tok = str(gid)
            if tok not in new_tokens:
                new_tokens.append(tok)
        if repl is not None:
            new_tokens.extend(str(g) for g in repl)
        mapping[old] = "#".join(new_tokens)

    print("\n=== 列表分类 ===")
    for k, v in stat.items():
        print(f"  {k}: {v} 种列表")

    # ---- 期望值校验 ----
    print("\n=== 期望产出对比 ===")
    bad = 0
    ratios = {True: [], False: []}      # True=该列表做了合并（装备应按 scale 缩放）
    for old, new in mapping.items():
        merged = any(int(float(t)) in MERGE_PLANS for t in new.split('#') if t.strip())
        before = expected_per_tick([int(float(t)) for t in old.split("#") if t.strip()], groups, items)
        after = Counter()
        for gid in [int(float(t)) for t in new.split("#") if t.strip()]:
            if gid in MERGE_PLANS:
                for src in MERGE_PLANS[gid]["src"]:
                    for k, v in expected_per_tick([src], groups, items).items():
                        after[k] += v * (scale if 60001 <= k <= 60200 else 1.0)
            else:
                after.update(expected_per_tick([gid], groups, items))
        for k in set(before) | set(after):
            b, a = before.get(k, 0.0), after.get(k, 0.0)
            if 60001 <= k <= 60200:
                if b > 0:
                    ratios[merged].append(a / b)
            elif abs(b - a) > TOL:
                bad += 1
                if bad <= 5:
                    print(f"  非装备项异常 item {k}: {b:.6f} -> {a:.6f}")
    for flag, label, target in ((True, "合并列表", scale), (False, "未合并列表", 1.0)):
        rs = ratios[flag]
        if rs:
            print(f"  {label}装备倍率: {min(rs):.3f} ~ {max(rs):.3f}（目标 {target:.3f}）")
            if not (target * 0.85 <= min(rs) and max(rs) <= target * 1.15):
                raise SystemExit(f"{label}装备倍率偏离目标，已中止")
    print(f"  非装备项偏差超限: {bad}")
    if bad:
        raise SystemExit("非装备期望值异常，已中止")

    sample = max(mapping, key=lambda s: len([t for t in s.split('#') if t.strip()]))
    print(f"\n  最长列表: {len([t for t in sample.split('#') if t.strip()])} 组 -> "
          f"{len([t for t in mapping[sample].split('#') if t.strip()])} 组")

    if not args.apply:
        print("\n[dry-run] 未写入。加 --apply 落表。")
        return

    # ---------------- 写入 ----------------
    bak = os.path.join(BASE, "_backup_before_tune")
    if not os.path.isdir(bak):
        os.makedirs(bak)
    for f in (F_MAIN, F_GROUP, F_ITEM):
        shutil.copy2(f, os.path.join(bak, os.path.basename(f)))
    print(f"\n已备份到 {bak}")

    rid_next = NEW_RID_BASE
    while rid_next in items or (rid_next + 300) in items:
        rid_next += 300
    new_rows = []
    group_items_str = {}
    for new_gid, plan in MERGE_PLANS.items():
        weights, filler, meta = build_merged_group(plan["src"], groups, items, scale)
        filler_rid = rid_next
        rid_next += 1
        new_rows.append(dict(id=filler_rid, item_id=14, chance=filler, grow=0, min=0, max=0,
                             addition=None, chance_addition=None,
                             info="挂机随机-合并空位", note1=None, note2=None))
        rids = [filler_rid]
        for rid, w in weights:
            it = meta[rid]
            new_rows.append(dict(id=rid_next, item_id=it["item_id"], chance=w, grow=it["grow"],
                                 min=it["min"], max=it["max"], addition=it["addition"],
                                 chance_addition=it["chance_addition"],
                                 info="挂机随机-装备(合并)", note1=it["note1"], note2=it["note2"]))
            rids.append(rid_next)
            rid_next += 1
        group_items_str[new_gid] = "#".join(str(r) for r in rids)

    start_row = iws.max_row + 1
    for i, r in enumerate(new_rows):
        row = start_row + i
        for col, key in ((2, "id"), (3, "item_id"), (4, "chance"), (5, "grow"), (6, "min"),
                         (7, "max"), (8, "addition"), (9, "chance_addition"),
                         (10, "info"), (11, "note1"), (12, "note2")):
            iws.cell(row, col, r[key])
    print(f"RewardItemConfig 新增 {len(new_rows)} 行（id {NEW_RID_BASE} 起）")

    gstart = gws.max_row + 1
    for offset, (new_gid, plan) in enumerate(MERGE_PLANS.items()):
        row = gstart + offset
        gws.cell(row, 2, new_gid)
        gws.cell(row, 3, f"挂机随机-装备(合并{plan['name']})")
        gws.cell(row, 4, 2)
        gws.cell(row, 5, group_items_str[new_gid])
        gws.cell(row, 6, 1)
        gws.cell(row, 7, None)
        gws.cell(row, 8, None)
    print(f"RewardGroup 追加 {len(MERGE_PLANS)} 个新组（行 {gstart}~{gstart + len(MERGE_PLANS) - 1}），"
          f"旧装备组保留给未合并的前缀列表")

    n = 0
    for lv in levels:
        new = mapping.get(lv["random_reward"])
        if new and new != lv["random_reward"]:
            mws.cell(lv["row"], col_rr, new)
            n += 1
    print(f"MainLevelConfig 改写 {n} 行 RandomReward")

    gw.save(F_GROUP)
    iw.save(F_ITEM)
    mw.save(F_MAIN)

    ok, detail = verify(bak, scale)
    if not ok:
        for f in (F_MAIN, F_GROUP, F_ITEM):
            shutil.copy2(os.path.join(bak, os.path.basename(f)), f)
        raise SystemExit(f"自检失败，已回滚：{detail}")
    print("自检通过：" + detail)
    print("\n已写回 3 个 xlsx。请到 Unity 用 DataConfig 重新导表。")


def _dangling(levels, groups, items):
    out = set()
    for lv in levels:
        for t in lv["random_reward"].split("#"):
            if not t.strip():
                continue
            if int(float(t)) not in groups:
                out.add((lv["id"], "group", t))
    for gid, g in groups.items():
        for rid in g["items"]:
            if rid not in items:
                out.add((gid, "rid", rid))
    return out


def verify(bak_dir, scale):
    global F_GROUP, F_ITEM, F_MAIN
    g_new, _, groups_new = load_groups()
    _, _, items_new = load_items()
    _, _, levels_new, _ = load_levels()

    saved = (F_GROUP, F_ITEM, F_MAIN)
    F_GROUP = os.path.join(bak_dir, "RewardGroup.xlsx")
    F_ITEM = os.path.join(bak_dir, "RewardItemConfig.xlsx")
    F_MAIN = os.path.join(bak_dir, "MainLevelConfig.xlsx")
    _, _, groups_old = load_groups()
    _, _, items_old = load_items()
    _, _, levels_old, _ = load_levels()
    F_GROUP, F_ITEM, F_MAIN = saved

    new_bad = _dangling(levels_new, groups_new, items_new) - _dangling(levels_old, groups_old, items_old)
    if new_bad:
        return False, f"新增悬空引用 {len(new_bad)} 处，例如 {sorted(new_bad)[:3]}"

    old_map = {lv["id"]: lv["random_reward"] for lv in levels_old}
    worst_non_equip = 0.0
    ratios = {True: [], False: []}
    for lv in levels_new:
        old = old_map.get(lv["id"])
        if old is None:
            continue
        eo = expected_per_tick([int(float(t)) for t in old.split("#") if t.strip()], groups_old, items_old)
        en = expected_per_tick([int(float(t)) for t in lv["random_reward"].split("#") if t.strip()],
                               groups_new, items_new)
        merged = any(int(float(t)) in MERGE_PLANS for t in lv["random_reward"].split("#") if t.strip())
        for k in set(eo) | set(en):
            b, a = eo.get(k, 0.0), en.get(k, 0.0)
            if 60001 <= k <= 60200:
                if b > 0:
                    ratios[merged].append(a / b)
            else:
                worst_non_equip = max(worst_non_equip, abs(b - a))
    if worst_non_equip > TOL:
        return False, f"非装备期望偏差 {worst_non_equip:.3e}"
    for flag, label, target in ((True, "合并列表", scale), (False, "未合并列表", 1.0)):
        rs = ratios[flag]
        if rs and not (target * 0.85 <= min(rs) and max(rs) <= target * 1.15):
            return False, f"{label}装备倍率 {min(rs):.3f}~{max(rs):.3f} 偏离目标 {target:.3f}"

    m = ratios[True]
    return True, (f"引用完整；{len(levels_new)} 关非装备偏差 < {TOL}；"
                  f"合并列表装备倍率 {min(m):.3f}~{max(m):.3f}")


if __name__ == "__main__":
    main()
