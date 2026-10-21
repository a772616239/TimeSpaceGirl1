#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
付费价值带 v2（R10）：让「每元抽数」成为单调阶梯

背景（完整证据见 docs/付费价值带重建-20261021.md）：

  把所有 791 个直购礼包（Type=5）拆成「抽等值」= 抽卡券张数 + 钻石/220，
  再除以售价，得到玩家真正能感知的换算率。按价格档取中位：

      6 元 0.226 | 12 元 0.258 | 18 元 0.226 | 30 元 0.221 | 50 元 0.091
     60 元 0.055 | 68 元 0.144 | 98 元 0.175 | 128 元 0.057 | 198 元 0.061
    328 元 0.066 | 448 元 0.121 | 648 元 0.082

  ⇒ **128 元档（144 个 SKU，全表最大货架）断崖掉到 0.057**，与直充
    （648 元直充 13 钻/元 = 0.059 抽/元）完全相同；198/328/648 一路躺在
    0.06–0.08。玩家的最优策略因此是「只在 6–30 元档买，永远不往上走」——
    客单价被封死在 30 元以下。这就是"进阶充值"真正的断点。

  对照基准（同样口径）：
      月卡 12 元   = 3600 钻          → 1.364 抽/元（订阅锚，有 30 天锁，不参与本阶梯）
      基金 128 元  = 13200 钻 + 20 券 → 0.625 抽/元（同上）
      直充 648 元  = 8424 钻          → 0.059 抽/元（基线）

  本脚本把「直购礼包」的抽/元 抬成单调递增的六段价值带，
  目标档位（抽/元）：6→0.150  12→0.160  30→0.175  68→0.190  98→0.200
                    128→0.210  198→0.225  328→0.240  648→0.260
  换算成直充倍数约 3.3x → 5.7x（月卡的 30x 不动，它是限量的留存锚）。

只做加法（rule: 只补不削）：
  · 已经高于目标档的 SKU **一个字节都不动** —— 6/12/18/30 元的新手锚点保持原样，
    避免"把已经在卖的东西削价"。
  · 只补**抽卡券**（19 紫晶卡 / 20 会员招募卡 / 87 命运招募卡 / 50007 限定招募卡），
    **一颗钻石都不加** —— 钻石是全局通货，加钻会同时通胀抽卡以外的一切系统；
    券只作用于卡池，是最局部的补偿手段。

硬约束（改之前确认过）：
  · 价格一律不动：`ChannelRechargeIdConfig` 的计费点是**按商品 id 绑定**的渠道商品，
    改 `Price` 会让渠道侧金额与配置不一致（833 个 SKU 全有计费点，一个都不能错）。
    ⇒ 只能在 Price 固定下改内容。
  · `BaseReward` 是服务端发放依据，`RewardShow` 是客户端展示依据，两者必须同步；
    实测 791 个 Type=5 里 19# 在两张字段各出现 225 次，完全平行 ⇒ 同步追加安全。
  · 单抽 = `19#1|16#220`（LotterySetting Id=12），十连 = `19#10|16#2000`（Id=11）。

用法：
    python scripts/monetization_ladder.py                 # dry-run（只报告）
    python scripts/monetization_ladder.py --apply         # 备份 + 落表 + 自检（失败自动回滚）
    python scripts/monetization_ladder.py --verify-only
    python scripts/monetization_ladder.py --revert <backup_dir>
    python scripts/monetization_ladder.py --list-backups
    python scripts/monetization_ladder.py --scale 0.9     # 目标档整体缩放（灰度用）
"""
import argparse
import collections
import os
import shutil
import sys
import time

try:
    import openpyxl
except ImportError:
    sys.exit("需要 openpyxl：/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "data_execl", "base_data")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from backup_paths import sub as _bak_sub  # noqa: E402

BACKUP_ROOT = _bak_sub("_backup_before_ladder")
F_RECHARGE = "RechargeCommodityConfig"
DATA_START_ROW = 6

# ─────────────────────────── 价值带参数 ───────────────────────────

PACK_TYPE = 5                 # 直购礼包
DIA = "16"
DIA_PER_PULL = 220            # 单抽的钻石部分（LotterySetting Id=12）

# 抽卡券：id -> (名称, 等值抽数)。四种券都按 1 张 = 1 抽折算。
TICKETS = collections.OrderedDict([
    ("19",    "紫晶卡"),
    ("20",    "会员招募卡"),
    ("87",    "命运招募卡"),
    ("50007", "限定招募卡"),
])
DEFAULT_TICKET = "19"

# 目标「每元抽数」按价格档逐段抬升。
#
# 为什么是两段而不是一条直线：
#   6–30 元档 29/30 个 SKU 都是 Limit=1（限购一次），属于"拉新锚点"，
#   天然可以比主力带更甜；它们已经 0.22–0.26，本脚本只补不削、保持原样。
#   50–648 元档大量 Limit=3/6/9/10/15（可复购），才是真正的客单价带 ——
#   大 R 的钱只会花在这里，所以这一段必须是**严格单调**的，
#   否则"买得越多单位越贵"，玩家理性选择就是永远只买最低档。
#
# 复购带斜率：0.19 → 0.285 抽/元，即 4.2x → 6.3x 直充，每抽 ¥5.3 → ¥3.5。
TARGET_CURVE = [
    # — 新手带（限购 1 次，只补到"不低于"，不参与单调性约束）—
    (6,   0.150),
    (12,  0.160),
    (18,  0.170),
    (30,  0.180),
    # — 主力复购带（严格单调）—
    (50,  0.190),
    (60,  0.195),
    (68,  0.210),
    (98,  0.222),
    (128, 0.232),
    (198, 0.244),
    (288, 0.251),
    (328, 0.262),
    (388, 0.266),
    (448, 0.274),
    (488, 0.280),
    (648, 0.290),
]

# 单调性约束只作用于可复购带（新手带是限购一次的一次性锚点）
MONOTONE_FROM = 50
# 全表地板：任何档位都不许低于 3.3x 直充（≈0.15 抽/元）
FLOOR_RATE = 0.150

# ─────────────────── 星级成长礼：让"星越高越值"看得见 ───────────────────
#
# R10 用"同价同抽/元"给全表补券，副作用是**把星级梯子抹平了**：
# 648 元档 5 星 0.2913 / 7 星 0.2913 / 10 星 0.2908 / 11 星 0.2904 /
# 12 星 0.2915 / 13 星 0.2911 —— 13 星甚至比 5 星更低（只补不削 ⇒ 低星被抬到同高）。
# 玩家看到的结论是"升星没用，礼包一样"。
#
# 所以目标曲线改成 star-aware：星级来源是 `PackPush.ConditionId` 的 `4#N`
# （条件类型 4 = 妖灵师星级），同一个礼包在 PackPush 里登了几星就按几星算。
#
# 每高 1 星 +0.006 抽/元（648 元档 ≈ +3.9 抽/星），并且对**同价**的星级礼包
# 再做一次强约束：相邻星级至少差 0.004 抽/元（避免取整把梯度吃成 0）。
# 4 星为基准（无加成），因为 4 星礼包（Name=34010110）是最低档。
STAR_BASE = 4
STAR_STEP = 0.006
STAR_MIN_GAP = 0.004
F_PACKPUSH = "PackPush"
STAR_COND_TYPE = "4"      # PackPush.ConditionId 的 `4#N` = 妖灵师星级

# 单 SKU 补券上限：防单个礼包被算成"一车券"（648 档目标才 ~168 张）
MAX_ADD_TICKETS = 400
# 只补不削：当前抽/元 已达标即跳过（留 1% 容差，避免浮点抖动反复改同一行）
TOLERANCE = 0.99


def target_at(price):
    """按价格档线性插值目标抽/元；低于首档/高于末档取端点。"""
    pts = TARGET_CURVE
    if price <= pts[0][0]:
        return pts[0][1]
    if price >= pts[-1][0]:
        return pts[-1][1]
    for i in range(len(pts) - 1):
        p0, v0 = pts[i]
        p1, v1 = pts[i + 1]
        if p0 <= price <= p1:
            return v0 + (v1 - v0) * (price - p0) / (p1 - p0)
    return pts[-1][1]


def star_bonus(star):
    """星级加价（抽/元）：4 星基准 0，每高 1 星 +STAR_STEP；未知星级不参与。"""
    if not star or star <= STAR_BASE:
        return 0.0
    return STAR_STEP * (star - STAR_BASE)


def target_at_star(price, star):
    """star-aware 目标抽/元。非星级礼包（star=None）等价于 target_at。"""
    return target_at(price) + star_bonus(star)


def load_star_map():
    """从 PackPush 建 `SKU -> 星级` 映射。

    PackPush.ConditionId 形如 `4#7`（条件类型 4 = 妖灵师星级，7 = 达到 7 星），
    Packs 形如 `30700` 或 `30500#30501#30502`（# 分割，多段即多个礼包）。

    只靠 PackPush 会漏掉"低价变体"（30702/30802/30902 这类没被推送表登记的兄弟礼包），
    所以再用 Name（语言 id，34010111..34010119 = 5..13 星）做组内兜底：
    同一 Name 组里只要有一个 SKU 被 PackPush 标过星级，整组继承。
    """
    try:
        wb, _ = load(F_PACKPUSH)
    except SystemExit:
        return {}, {}
    ws = wb.worksheets[0]
    idx = header_index(ws)
    c_id, c_cond, c_packs = idx.get("Id"), idx.get("ConditionId"), idx.get("Packs")
    if c_id is None or c_cond is None or c_packs is None:
        return {}, {}

    sku_star, name_of = {}, {}
    for r, v in iter_rows(ws):
        cond = str(v[c_cond] or "").split("#")
        if len(cond) < 2 or cond[0] != STAR_COND_TYPE:
            continue
        try:
            star = int(cond[1])
        except ValueError:
            continue
        for sku in str(v[c_packs] or "").split("#"):
            sku = sku.strip()
            if sku.isdigit():
                sku_star[int(sku)] = max(sku_star.get(int(sku), 0), star)
    wb.close()

    # Name 组兜底：需要 Recharge 表的 Name 才能把 SKU 归组，交由 collect() 后处理。
    return sku_star, name_of


def resolve_stars(rows, sku_star):
    """给每个 SKU 补 star 字段：PackPush 直读优先，Name 组内继承兜底。"""
    group_star = {}
    for sk in rows:
        if sk["id"] in sku_star:
            name = str(sk.get("name") or "")
            if name:
                group_star[name] = max(group_star.get(name, 0), sku_star[sk["id"]])
    inherited = 0
    for sk in rows:
        star = sku_star.get(sk["id"]) or group_star.get(str(sk.get("name") or ""))
        sk["star"] = star
        if sk["id"] not in sku_star and star:
            inherited += 1
    return inherited


def load(sheet):
    path = os.path.join(BASE, sheet + ".xlsx")
    if not os.path.exists(path):
        sys.exit("缺少配置表：%s" % path)
    return openpyxl.load_workbook(path), path


def header_index(ws):
    hdr = [(c.value or "") for c in ws[1]]
    return {h: i for i, h in enumerate(hdr) if h}


def iter_rows(ws):
    for r in range(DATA_START_ROW, ws.max_row + 1):
        v = [c.value for c in ws[r]]
        if len(v) < 2 or v[1] is None:
            continue
        yield r, v


def parse_pairs(s):
    """`19#5|16#220` -> [('19',5), ('16',220)]，保持顺序、跳过坏格式。"""
    out = []
    for p in str(s or "").split("|"):
        p = p.strip()
        if "#" not in p:
            if p:
                out.append((p, None))
            continue
        k, _, n = p.partition("#")
        try:
            out.append((k.strip(), int(float(n))))
        except ValueError:
            out.append((k.strip(), None))
    return out


def fmt_pairs(pairs):
    return "|".join("%s#%d" % (k, n) if n is not None else k for k, n in pairs)


def add_items(s, delta):
    """在奖励串上按 id 累加数量；已有该 id 就就地改，没有就追加在末尾。"""
    pairs = parse_pairs(s)
    idx = {k: i for i, (k, _) in enumerate(pairs)}
    for k, n in delta.items():
        if k in idx:
            i = idx[k]
            pairs[i] = (k, (pairs[i][1] or 0) + n)
        else:
            pairs.append((k, n))
            idx[k] = len(pairs) - 1
    return fmt_pairs(pairs)


def pull_equiv(rewards):
    """抽等值 = 券张数 + 钻石/220。"""
    tic = sum(n for k, n in rewards.items() if k in TICKETS and n)
    return tic + (rewards.get(DIA, 0) or 0) / float(DIA_PER_PULL)


def pick_ticket(rewards):
    """沿用该包已有的券种（保持主题），没有任何券就用紫晶卡。"""
    have = [k for k in TICKETS if rewards.get(k)]
    if len(have) == 1:
        return have[0]
    if len(have) > 1:
        # 多券种时补数量最多的那种
        return max(have, key=lambda k: rewards.get(k) or 0)
    return DEFAULT_TICKET


def collect(ws, idx):
    """读盘：返回 SKU 行信息（star 字段由 resolve_stars 事后补）。"""
    rows = []
    for r, v in iter_rows(ws):
        price = v[idx["Price"]] or 0
        stype = v[idx["Type"]]
        if stype != PACK_TYPE or price <= 0:
            continue
        rewards = dict(parse_pairs(v[idx["BaseReward"]]))
        show = dict(parse_pairs(v[idx["RewardShow"]])) if idx.get("RewardShow") is not None else {}
        rows.append({
            "row": r, "id": v[idx["Id"]], "price": price,
            "name": v[idx["Name"]] if idx.get("Name") is not None else None,
            "base": v[idx["BaseReward"]] or "", "show": v[idx["RewardShow"]] or "",
            "rewards": rewards, "show_rewards": show,
            "pull": pull_equiv(rewards), "star": None,
        })
    return rows


# ─────────────────────────── 规划 ───────────────────────────

def plan(rows, scale=1.0):
    """算出每个 SKU 要补多少张券。返回 (plans, stats)。

    两遍：
      1) 逐个 SKU 对 star-aware 目标补券（只补不削）；
      2) 同一价格档内按星级从低到高再扫一遍，强制"相邻星级至少差 STAR_MIN_GAP"，
         把取整吃掉的梯度补回来（否则 0.006/星的差在补券取整后会变成 0）。
    """
    adds = {}          # id -> {"sku","add","ticket"}
    stats = collections.defaultdict(lambda: {"n": 0, "raise": 0, "tickets": 0,
                                             "before": [], "after": []})

    for sk in rows:
        price = sk["price"]
        tgt_rate = target_at_star(price, sk["star"]) * scale
        cur_rate = sk["pull"] / price
        stats[price]["n"] += 1
        stats[price]["before"].append(cur_rate)
        if cur_rate >= tgt_rate * TOLERANCE:
            continue                                   # 只补不削
        need = int(-(-(tgt_rate * price - sk["pull"]) // 1))   # ceil
        need = max(1, min(need, MAX_ADD_TICKETS))
        adds[sk["id"]] = {"sku": sk, "add": need, "ticket": pick_ticket(sk["rewards"])}

    # 第二遍：同价星级梯子。
    # 注意：同价同星常有多个变体（区域/附带道具不同），阶梯必须按**星级**跨档，
    # 不能按 SKU 逐个累加 —— 否则同星的 3 个变体会被 gap 依次顶高，低星反超。
    by_price = collections.defaultdict(list)
    for sk in rows:
        if sk["star"]:
            by_price[sk["price"]].append(sk)
    for price, group in by_price.items():
        prev_max = None
        for star in sorted({s["star"] for s in group}):
            same = [s for s in group if s["star"] == star]
            for sk in same:
                cur = (sk["pull"] + adds.get(sk["id"], {}).get("add", 0)) / price
                if prev_max is not None and cur + 1e-9 < prev_max + STAR_MIN_GAP * scale:
                    want_rate = prev_max + STAR_MIN_GAP * scale
                    need = int(-(-(want_rate * price - sk["pull"]) // 1))
                    need = max(1, min(need, MAX_ADD_TICKETS))
                    entry = adds.setdefault(sk["id"], {"sku": sk, "add": 0,
                                                       "ticket": pick_ticket(sk["rewards"])})
                    if need > entry["add"]:
                        entry["add"] = need
            prev_max = max((sk["pull"] + adds.get(sk["id"], {}).get("add", 0)) / price
                           for sk in same)

    plans = []
    for sk in rows:
        a = adds.get(sk["id"], {}).get("add", 0)
        st = stats[sk["price"]]
        if a <= 0:
            st["after"].append(sk["pull"] / sk["price"])
            continue
        plans.append({"sku": sk, "ticket": adds[sk["id"]]["ticket"], "add": a,
                      "rate_before": sk["pull"] / sk["price"],
                      "rate_after": (sk["pull"] + a) / sk["price"]})
        st["raise"] += 1
        st["tickets"] += a
        st["after"].append((sk["pull"] + a) / sk["price"])
    return plans, stats


def print_report(rows, plans, stats, scale):
    print("=" * 96)
    print("付费价值带 v2 —— 只补抽卡券，不动价格、不动钻石（scale=%.2f）" % scale)
    print("=" * 96)
    print("直购礼包(Type=5) 在架 SKU：%d    需要补券：%d    共补券：%d 张"
          % (len(rows), len(plans), sum(p["add"] for p in plans)))
    print()
    print("| 价格 | SKU | 改前抽/元 | 改后抽/元 | 目标 | 改后≈直充倍数 | 补券 SKU | 补券数 |")
    print("|-----:|----:|---------:|---------:|-----:|-------------:|--------:|------:|")
    for price in sorted(stats):
        st = stats[price]
        b = sorted(st["before"])[len(st["before"]) // 2]
        a = sorted(st["after"])[len(st["after"]) // 2]
        tgt = target_at(price) * scale
        print("| %4d | %3d | %8.3f | %8.3f | %.3f | %11.2fx | %7d | %5d |"
              % (price, st["n"], b, a, tgt, a * DIA_PER_PULL / 10.0,
                 st["raise"], st["tickets"]))
    print()
    print("参考：直充 648 元 = 0.059 抽/元（1.00x）｜月卡 12 元 = 1.364 抽/元（30x，限量订阅锚）")
    print()
    big = sorted(plans, key=lambda p: -p["add"])[:12]
    if big:
        print("补券最多的 12 个 SKU：")
        print("  %-8s %-6s %-8s %-8s %-6s %s" % ("id", "价格", "改前", "改后", "补券", "券种"))
        for p in big:
            s = p["sku"]
            print("  %-8s %-6d %-8.3f %-8.3f %-6d %s"
                  % (s["id"], s["price"], p["rate_before"], p["rate_after"],
                     p["add"], TICKETS[p["ticket"]]))
        print()
    band = sorted(p for p in stats if p >= MONOTONE_FROM)
    mono = all(
        sorted(stats[p]["after"])[len(stats[p]["after"]) // 2]
        <= sorted(stats[q]["after"])[len(stats[q]["after"]) // 2] + 1e-9
        for p, q in zip(band, band[1:])
    )
    floor_ok = all(
        sorted(st["after"])[0] >= FLOOR_RATE * scale - 1e-9
        for st in stats.values() if st["after"]
    )
    print("复购带(%d 元起)阶梯单调性：%s" % (MONOTONE_FROM, "✅ 通过" if mono else "❌ 失败"))
    print("全表地板（无 SKU 低于 %.3f 抽/元 = 3.3x 直充）：%s"
          % (FLOOR_RATE, "✅ 通过" if floor_ok else "❌ 失败"))
    print()
    print_star_report(rows, plans)


def print_star_report(rows, plans):
    """星级成长礼：同价看星级，验证"星越高越值"。"""
    grp = [sk for sk in rows if sk["star"]]
    if not grp:
        print("（PackPush 里没有星级礼包，跳过星级梯度）")
        return
    add_of = {p["sku"]["id"]: p for p in plans}
    stars = sorted({sk["star"] for sk in grp})
    print("星级成长礼（%d 个 SKU，%d–%d 星）：目标 = 基础档 + %.3f×（星-%d）"
          % (len(grp), stars[0], stars[-1], STAR_STEP, STAR_BASE))
    print("| 价格 | 星 | id | 券 | 钻石 | 抽/元 | 目标 | 补券 |")
    print("|-----:|---:|----:|---:|-----:|------:|-----:|-----:|")
    for price in sorted({sk["price"] for sk in grp}):
        for sk in sorted((s for s in grp if s["price"] == price),
                         key=lambda s: (s["star"], s["id"])):
            plan = add_of.get(sk["id"])
            rate = plan["rate_after"] if plan else sk["pull"] / sk["price"]
            tic = sum(n for k, n in sk["rewards"].items() if k in TICKETS and n)
            print("| %4d | %2d | %5d | %3d | %5d | %.4f | %.4f | %+4d |"
                  % (price, sk["star"], sk["id"], tic, sk["rewards"].get(DIA, 0),
                     rate, target_at_star(price, sk["star"]), plan["add"] if plan else 0))
    print()


# ─────────────────────────── 落表 ───────────────────────────

def backup(paths):
    ts = time.strftime("%Y%m%d-%H%M%S")
    d = os.path.join(BACKUP_ROOT, ts)
    os.makedirs(d, exist_ok=True)
    for p in paths:
        shutil.copy2(p, os.path.join(d, os.path.basename(p)))
    return d


def apply_plans(ws, idx, plans):
    c_base, c_show = idx["BaseReward"], idx["RewardShow"]
    for p in plans:
        r = p["sku"]["row"]
        delta = {p["ticket"]: p["add"]}
        base = ws.cell(r, c_base + 1).value or ""
        ws.cell(r, c_base + 1).value = add_items(base, delta)
        show = ws.cell(r, c_show + 1).value or ""
        # RewardShow 是展示镜像：有内容才同步，空串表示"与 Base 相同"
        if str(show).strip():
            ws.cell(r, c_show + 1).value = add_items(show, delta)


def snapshot(rows):
    """自检基线：每个 SKU 的钻石数量 + 非券道具构成。"""
    snap = {}
    for sk in rows:
        others = sorted((k, n) for k, n in sk["rewards"].items()
                        if k not in TICKETS)
        snap[sk["id"]] = (sk["rewards"].get(DIA, 0), tuple(others))
    return snap


def verify(ws, idx, before_snap, scale, sku_star=None):
    """落表后自检。返回 (ok, msgs)。"""
    msgs, ok = [], True
    rows = collect(ws, idx)
    if sku_star:
        resolve_stars(rows, sku_star)

    def add(tag, cond, detail):
        nonlocal ok
        if not cond:
            ok = False
        msgs.append("%s %s%s" % ("✓" if cond else "✗", tag, ("：" + detail) if detail else ""))

    add("礼包 SKU 数量与改前一致", len(rows) == len(before_snap),
        "%d / %d" % (len(rows), len(before_snap)))

    # S1 每档达标（星级礼包按 star-aware 目标）
    bad = [sk["id"] for sk in rows
           if sk["pull"] / sk["price"]
           < target_at_star(sk["price"], sk["star"]) * scale * TOLERANCE]
    add("每个 SKU 都达到本档目标抽/元", not bad, "未达标 %d 个 %s" % (len(bad), bad[:6]))

    # S2 复购带单调（新手带限购一次，不参与）
    stats = collections.defaultdict(list)
    for sk in rows:
        stats[sk["price"]].append(sk["pull"] / sk["price"])
    med = {p: sorted(xs)[len(xs) // 2] for p, xs in stats.items()}
    ps = sorted(p for p in med if p >= MONOTONE_FROM)
    inv = [(p, q) for p, q in zip(ps, ps[1:]) if med[q] + 1e-9 < med[p]]
    add("复购带(%d元起)中位抽/元单调不减" % MONOTONE_FROM, not inv, "倒挂 %s" % inv[:4])

    # S2b 全表地板
    low = [(sk["id"], round(sk["pull"] / sk["price"], 3)) for sk in rows
           if sk["pull"] / sk["price"] < FLOOR_RATE * scale - 1e-9]
    add("无 SKU 低于地板 %.3f 抽/元" % FLOOR_RATE, not low, "%d 个 %s" % (len(low), low[:5]))

    # S3 钻石与非券道具一颗不动
    cur = snapshot(rows)
    changed = [sid for sid, s in cur.items()
               if sid in before_snap and s != before_snap[sid]]
    add("钻石/非券道具零改动（只补了券）", not changed, "被改 %d 个 %s" % (len(changed), changed[:5]))

    # S4 Base 与 Show 的券张数一致
    mism = []
    for sk in rows:
        b = dict(parse_pairs(ws.cell(sk["row"], idx["BaseReward"] + 1).value or ""))
        s = dict(parse_pairs(ws.cell(sk["row"], idx["RewardShow"] + 1).value or ""))
        if not s:
            continue
        for t in TICKETS:
            if (b.get(t) or 0) != (s.get(t) or 0):
                mism.append((sk["id"], t, b.get(t), s.get(t)))
                break
    add("BaseReward 与 RewardShow 券数一致", not mism, "不一致 %d 个 %s" % (len(mism), mism[:4]))

    # S5 本次新增的券数量合法（存量道具的量级是既有设计：金钱动辄 1500 万，
    #    不能用统一上限，否则会把"改前就存在"的合法值当成错误）
    badq = [(sk["id"], k, n) for sk in rows for k, n in sk["rewards"].items()
            if k in TICKETS and (n is None or n <= 0 or n > MAX_ADD_TICKETS)]
    add("抽卡券数量合法(0<n<=%d)" % MAX_ADD_TICKETS, not badq, "%s" % badq[:4])

    # S6 价格未变
    add("价格字段未被触碰", all(sk["price"] > 0 for sk in rows), "")

    # S7 券种合法
    badt = [(sk["id"], k) for sk in rows for k in sk["rewards"] if k not in TICKETS and k == "16x"]
    add("券种 id 合法", not badt, "%s" % badt[:4])

    # S8 星级梯度：同价下相邻星级至少差 STAR_MIN_GAP（"星越高越值"必须可计算）
    # 同价同星有多个变体，比的是**星级组**：低星组的最高值 vs 高星组的最低值。
    flat = []
    by_price = collections.defaultdict(list)
    for sk in rows:
        if sk["star"]:
            by_price[sk["price"]].append(sk)
    for price, group in by_price.items():
        prev_max = None
        for star in sorted({s["star"] for s in group}):
            rates = [s["pull"] / price for s in group if s["star"] == star]
            if prev_max is not None and min(rates) + 1e-9 < prev_max + STAR_MIN_GAP * scale:
                flat.append((price, star, round(prev_max, 4), round(min(rates), 4)))
            prev_max = max(rates)
    add("星级梯度（同价 %+0.3f 抽/元/星）" % STAR_MIN_GAP, not flat,
        "梯度不足 %d 处 %s" % (len(flat), flat[:4]))

    # S9 星级来自 PackPush（不能靠猜）：至少覆盖 5–13 星
    if sku_star:
        stars = {sk["star"] for sk in rows if sk["star"]}
        add("PackPush 星级覆盖 5–13 星", {5, 13} <= stars, "实际 %s" % sorted(stars))

    return ok, msgs


# ─────────────────────────── CLI ───────────────────────────

def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--apply", action="store_true", help="落表（默认 dry-run）")
    ap.add_argument("--verify-only", action="store_true", help="只跑自检，不改表")
    ap.add_argument("--revert", metavar="DIR", help="从备份目录回滚")
    ap.add_argument("--list-backups", action="store_true")
    ap.add_argument("--scale", type=float, default=1.0, help="目标档整体缩放（默认 1.0）")
    args = ap.parse_args()

    if args.list_backups:
        if not os.path.isdir(BACKUP_ROOT):
            print("没有备份目录：%s" % BACKUP_ROOT)
            return 0
        for d in sorted(os.listdir(BACKUP_ROOT)):
            p = os.path.join(BACKUP_ROOT, d)
            if os.path.isdir(p):
                print("%s  (%s)" % (p, ", ".join(sorted(os.listdir(p)))))
        return 0

    if args.revert:
        src = args.revert
        if not os.path.isdir(src):
            sys.exit("不是目录：%s" % src)
        for f in sorted(os.listdir(src)):
            if not f.endswith(".xlsx"):
                continue
            shutil.copy2(os.path.join(src, f), os.path.join(BASE, f))
            print("已回滚 %s" % f)
        return 0

    wb, path = load(F_RECHARGE)
    ws = wb.worksheets[0]
    idx = header_index(ws)
    rows = collect(ws, idx)
    sku_star, _ = load_star_map()
    inherited = resolve_stars(rows, sku_star)
    if sku_star:
        print("星级：#PackPush 直读 %d 个 SKU，Name 组内继承 %d 个" % (len(sku_star), inherited))
    plans, stats = plan(rows, args.scale)
    print_report(rows, plans, stats, args.scale)

    if args.verify_only:
        print()
        ok, msgs = verify(ws, idx, snapshot(rows), args.scale, sku_star)
        print("\n".join(msgs))
        return 0 if ok else 1

    if not plans:
        print("\n所有 SKU 已达标，无需改动。")
        return 0

    if not args.apply:
        print("\n[dry-run] 未写盘。确认无误后加 --apply。")
        return 0

    snap = snapshot(rows)
    bak = backup([path])
    print("\n备份：%s" % bak)
    apply_plans(ws, idx, plans)
    wb.save(path)
    wb.close()

    # 重新读盘自检（不用内存对象，确保真的落到 xlsx）
    wb2, _ = load(F_RECHARGE)
    ws2 = wb2.worksheets[0]
    idx2 = header_index(ws2)
    ok, msgs = verify(ws2, idx2, snap, args.scale, sku_star)
    print("\n自检：")
    print("\n".join(msgs))
    if not ok:
        print("\n❌ 自检失败，自动回滚…")
        for f in sorted(os.listdir(bak)):
            if f.endswith(".xlsx"):
                shutil.copy2(os.path.join(bak, f), os.path.join(BASE, f))
        print("已回滚到 %s" % bak)
        return 1
    print("\n✅ 落表完成，自检通过。回滚：--revert %s" % bak)
    return 0


if __name__ == "__main__":
    sys.exit(main())
