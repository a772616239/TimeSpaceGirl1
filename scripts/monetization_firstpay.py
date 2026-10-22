#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
首充 / 进阶充值 数值优化（R7-R9）

背景（完整数据与推理见 docs/首充与进阶充值数值优化-20261021.md）：

  · 首充活动（GlobalActivity Id=5「超值首充」，Type=5=RechargeTotal）**已经接线且常开**：
    累计充值 6 元 → 连领 3 天 `超值首充自选箱+紫晶卡×5` / `无畏之杖+无畏战靴` / `无畏手套+无畏战甲`
    累计充值 100 元 → 连领 3 天 `光辉之剑+紫晶卡×5` / `光辉手套+招募卡×1` / `光辉战甲+光辉战靴`
    问题是**一颗钻石都没有**：钻石招募十连要 `19#10|16#2000`（LotterySetting Id=11），
    首充给的 5 张紫晶卡既凑不够 10 张、也没有 2000 钻 ⇒ **首充当天一次都抽不了**，
    开完箱体验就断档。这是"首充体验"真正的断点。
  · 星级成长礼（ShowType=8，模拟口径下收入最高的货架）152 个在架 SKU 的钻石/元
    全部落在 11.2–12.0，**低于同价钻石直充**（198→12.0 / 328→12.5 / 648→13.0）——
    "限时成长礼"比直接充钻石还亏；且 5星→13星 完全拉平，进阶没有回报。

硬约束（改之前先确认过，别踩）：
  · `DayRewardItem.lua: kRewardCount = 2` —— 首充每天**只有 2 个奖励格**，
    往 Reward 里加第 3 项会让 `self.rewardList[3]:OnOpen` 索引 nil 直接报错。
    所以首充活动只能**改数量/替换**，不能新增奖励项。
  · `FirstRechargePanel.lua: kMaxTab = 2 / IndexValueDef = {[1]=6,[2]=100}` ——
    6 元 / 100 元两档写死在 Lua 里，改档位门槛会让整页空白。

本脚本只改配置（不动 Java/Lua）：
  R7  首充活动：紫晶卡 5→10（凑满十连的券），100 元档招募卡 1→3
  R8  SKU 首购：6 元档首购补钻（与首充活动的券配平；R16 起为 600 ⇒ 合计 660 钻）
  R9  星级成长礼按星级做钻/元阶梯（直充同档 +0.5，每星 +0.25），修倒挂 + 建梯度

R16（2026-10-22 复核后的回退，别再加回去）：
  10-21 的 R8 把 id=1 首购设成 1100 ⇒ 6 元合计 1160 钻，**比 30 元档首购 660 还高 76%**，
  且首充 5 券 + 1160 钻 = 1.712 抽/元，超过月卡 1.364 成为全表第一（R13/R14 刚把落差压到
  2.83x，被这一格拉回 4.85x）。现改为：首购 600 ⇒ 合计 660 钻 = 30 元档持平（不倒挂），
  首充活动 6 元档券 5→3 ⇒ 3 张券 × 220 钻 恰好被 660 钻吃完，**零死券**；名义抽等值
  3 + 660/220 = 6.0 抽 / 6 元 = 1.000 抽/元（＝成长基金，< 月卡 1.364）。
  另：R8 里「12 元月卡首购 +300」是空改 —— id=9 的 OnSaleRule 是 1#999#999 已永久关停，
  玩家买不到，月卡实际只有「累充 12 元白送」通道。已从 SKU_FIRST_MULTIPLE 移除。

用法：
    python scripts/monetization_firstpay.py            # dry-run
    python scripts/monetization_firstpay.py --apply    # 备份 + 落表 + 自检（失败自动回滚）
    python scripts/monetization_firstpay.py --revert <backup_dir>
    python scripts/monetization_firstpay.py --list-backups
    python scripts/monetization_firstpay.py --verify-only
    python scripts/monetization_firstpay.py --star-bonus 0.15   # 调梯度斜率（默认 0.25）
"""
import argparse
import collections
import json
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

BACKUP_ROOT = _bak_sub("_backup_before_firstpay")
DATA_START_ROW = 6

F_RECHARGE = "RechargeCommodityConfig"
F_ACTREWARD = "ActivityRewardConfig"
F_PACKPUSH = "PackPush"

# ─────────────────────────── 规则参数 ───────────────────────────

FIRSTPAY_ACTIVITY_ID = 5

# R7 首充活动：只改「已有道具的数量」（不新增奖励项 —— 客户端每天只有 2 格）
#     键 = (累计充值元, 第几天)，值 = {道具id: 数量}
#     6 元档 day1：紫晶卡 3（与 SKU 首购的 660 钻配平成 3 次单抽，零死券）
#     100 元档 day1：紫晶卡 10（凑满十连的券）；day2：招募卡 1 → 3（多给 2 抽）
FIRSTPAY_SET = {
    (6, 1): {"19": 3},
    (100, 1): {"19": 10},
    (100, 2): {"20": 3},
}

# 首充面板每天固定 2 个奖励格（DayRewardItem.kRewardCount）
FIRSTPAY_SLOTS = 2
# 单抽 `19#1|16#220`（LotterySetting Id=12）/ 十连 `19#10|16#2000`（Id=11）
SINGLE_PULL_DIAMONDS = 220
# 6 元档能配平几次单抽 = 首充活动给的紫晶卡张数（券和钻必须同进同出，券多出来的就是死库存）
SINGLE_PULLS_6YUAN = FIRSTPAY_SET[(6, 1)]["19"]
TEN_PULL_DIAMONDS = 2000

# R8 SKU 首购（RechargeCommodityConfig.FirstMultiple，买该 SKU 第 1 次时额外发放）
#     id=1  6 元钻石档：1100 → 600 ⇒ 首购合计 60+600 = 660 钻
#           ① 与 30 元档首购合计 660 钻**持平**（1100 时是 1160，倒挂 1.76x，同屏角标一眼可见）
#           ② 正好被 3 张紫晶卡吃完（3×220=660），不多不少，零死券
#     月卡 id=9 已永久关停（OnSaleRule=1#999#999），不放进来 —— 那条改动永远不会到账
SKU_FIRST_MULTIPLE = {1: 600}

# R9 星级成长礼阶梯：目标钻/元 = 直充同价档 + BONUS_BASE + BONUS_STAR × (星级-5)
BONUS_BASE = 0.5
BONUS_STAR = 0.25
STAR_SHOW_TYPE = 8
DEAD_ONSALE = "1#999#999"        # 2021 年那批未接线的遗留行（docs/星级成长礼遗留13行核查）


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


def iter_rows(ws):
    for r in range(DATA_START_ROW, ws.max_row + 1):
        v = [c.value for c in ws[r]]
        if not v or v[1] is None:
            continue
        yield r, v


def get(v, i):
    return v[i] if i < len(v) else None


def parse_pairs(s):
    """'16#300|19#5' -> [('16',300), ('19',5)]，保留顺序"""
    out = []
    for part in str(s or "").split("|"):
        part = part.strip()
        if not part or "#" not in part:
            continue
        a = part.split("#")
        try:
            out.append((a[0].strip(), int(float(a[1]))))
        except (ValueError, IndexError):
            out.append((part, None))
    return out


def parse_ints(s):
    """ActivityRewardConfig.Values / PackPush.ConditionId 是**扁平 int 数组**：
    '6#1' -> [6, 1]（累计充值元 # 第几天），不是 道具#数量。"""
    out = []
    for part in str(s or "").split("#"):
        part = part.strip()
        if not part:
            continue
        try:
            out.append(int(float(part)))
        except ValueError:
            out.append(None)
    return out


def fmt_pairs(pairs):
    return "|".join("%s#%d" % (k, n) if n is not None else k for k, n in pairs)


def diamonds(pairs):
    return sum(n for k, n in pairs if k == "16" and n)


def set_cell(ws, row, cidx, value):
    ws.cell(row=row, column=cidx + 1).value = value


# ─────────────────────────── 数据推导 ───────────────────────────

def direct_ratio_table(ws, idx):
    """从 Type=3 钻石直充档现读「钻/元」，作为进阶阶梯的基准（不写死）"""
    c_type, c_price, c_base = col(idx, "Type"), col(idx, "Price"), col(idx, "BaseReward")
    tbl = {}
    for r, v in iter_rows(ws):
        if get(v, c_type) != 3:
            continue
        price = get(v, c_price) or 0
        dia = diamonds(parse_pairs(get(v, c_base)))
        if price > 0 and dia > 0:
            tbl[price] = dia / price
    return tbl


def direct_ratio_at(tbl, price):
    """线性插值取任意价格档的直充钻/元"""
    if not tbl:
        return 10.0
    ps = sorted(tbl)
    if price <= ps[0]:
        return tbl[ps[0]]
    if price >= ps[-1]:
        return tbl[ps[-1]]
    for a, b in zip(ps, ps[1:]):
        if a <= price <= b:
            t = (price - a) / float(b - a)
            return tbl[a] + t * (tbl[b] - tbl[a])
    return tbl[ps[-1]]


def star_map():
    """PackPush 的 `4#星级` 条件 → 该星级推送的礼包 id，得到 packId -> 星级"""
    wb, ws, idx = load(F_PACKPUSH)
    c_cond, c_packs = col(idx, "ConditionId"), col(idx, "Packs")
    out = {}
    for r, v in iter_rows(ws):
        cond = parse_ints(get(v, c_cond))
        if len(cond) < 2 or cond[0] != 4:
            continue
        star = cond[1]
        if not star:
            continue
        for p in str(get(v, c_packs) or "").split("#"):
            p = p.strip()
            if p.isdigit():
                out[int(p)] = max(out.get(int(p), 0), star)
    return out


# ─────────────────────────── 三个改动 ───────────────────────────

F_MONTHCARD = "MonthcardConfig"


def monthcard_pull_per_yuan():
    """月卡（MonthcardConfig id=1）的抽/元 = 每日钻 × 天数 / 220 / 激活门槛。
    现读表，不写死 —— 它是「复购型产品必须压住首充」的锚点。"""
    try:
        wb, ws, idx = load(F_MONTHCARD)
    except Exception:
        return None
    c_id, c_price, c_reward, c_days = (col(idx, "Id"), col(idx, "Price"),
                                       col(idx, "BaseReward"), col(idx, "ContiueDays"))
    for r, v in iter_rows(ws):
        if get(v, c_id) != 1:
            continue
        price = get(v, c_price) or 0
        days = get(v, c_days) or 0
        dia = diamonds(parse_pairs(get(v, c_reward)))
        wb.close()
        if price > 0 and days > 0 and dia > 0:
            return dia * days / float(SINGLE_PULL_DIAMONDS) / price
        return None
    wb.close()
    return None


def plan_firstpay_activity():
    """R7：首充活动改数量（不新增奖励项）"""
    wb, ws, idx = load(F_ACTREWARD)
    c_act, c_id, c_val, c_rew = (col(idx, "ActivityId"), col(idx, "Id"),
                                 col(idx, "Values"), col(idx, "Reward"))
    changes, report = [], []
    for r, v in iter_rows(ws):
        if get(v, c_act) != FIRSTPAY_ACTIVITY_ID:
            continue
        key = parse_ints(get(v, c_val))
        if len(key) < 2:
            continue
        tier, day = key[0], key[1]
        want = FIRSTPAY_SET.get((tier, day))
        if not want:
            continue
        pairs = parse_pairs(get(v, c_rew))
        names = [k for k, _ in pairs]
        missing = [k for k in want if k not in names]
        if missing:                       # 不允许新增格子
            raise SystemExit("✗ 首充 (%d元,D%d) 想设置 %s 但该行没有此道具，会多占一格"
                             % (tier, day, missing))
        new_pairs = [(k, want.get(k, n)) for k, n in pairs]
        old_raw, new_raw = get(v, c_rew), fmt_pairs(new_pairs)
        if new_raw != str(old_raw):
            changes.append((r, "Reward", old_raw, new_raw, "R7-首充券数"))
        report.append((tier, day, get(v, c_id), pairs, new_pairs))
    return wb, ws, idx, changes, report


def plan_sku_first_multiple():
    """R8：SKU 首购赠礼（6 元档补钻到 2000 / 月卡首月双倍）"""
    wb, ws, idx = load(F_RECHARGE)
    c_id, c_fm = col(idx, "Id"), col(idx, "FirstMultiple")
    changes, report = [], []
    for r, v in iter_rows(ws):
        sid = get(v, c_id)
        if sid not in SKU_FIRST_MULTIPLE:
            continue
        old_raw = get(v, c_fm)
        old_dia = diamonds(parse_pairs(old_raw))
        new_dia = SKU_FIRST_MULTIPLE[sid]
        new_raw = "16#%d" % new_dia
        if old_dia != new_dia:
            changes.append((r, "FirstMultiple", old_raw, new_raw, "R8-首购"))
        report.append((sid, old_dia, new_dia))
    return wb, ws, idx, changes, report


def plan_star_ladder(star_bonus):
    """R9：星级成长礼钻/元阶梯（只升不降，修倒挂）"""
    wb, ws, idx = load(F_RECHARGE)
    c_id, c_show_type = col(idx, "Id"), col(idx, "ShowType")
    c_price, c_base, c_sale = col(idx, "Price"), col(idx, "BaseReward"), col(idx, "OnSaleRule")
    c_show = col(idx, "RewardShow")

    direct = direct_ratio_table(ws, idx)
    smap = star_map()
    changes, report = [], []

    for r, v in iter_rows(ws):
        if get(v, c_show_type) != STAR_SHOW_TYPE:
            continue
        if DEAD_ONSALE in str(get(v, c_sale) or ""):
            continue
        price = get(v, c_price) or 0
        if price <= 0:
            continue
        base_pairs = parse_pairs(get(v, c_base))
        cur_dia = diamonds(base_pairs)
        if cur_dia <= 0:
            continue
        sid = get(v, c_id)
        star = smap.get(sid, 5)
        target_ratio = direct_ratio_at(direct, price) + BONUS_BASE + star_bonus * max(0, star - 5)
        target_dia = int(round(price * target_ratio))
        new_dia = max(cur_dia, target_dia)
        report.append((sid, price, star, cur_dia, cur_dia / price,
                       new_dia, new_dia / price, target_ratio))
        # 抬升不足 1% 的不动：避免为了 2 颗钻刷一堆无意义的单元格改动
        if new_dia < cur_dia * 1.01:
            continue
        nb = [(k, (new_dia if k == "16" else n)) for k, n in base_pairs]
        changes.append((r, "BaseReward", get(v, c_base), fmt_pairs(nb), "R9-星级阶梯"))
        show_pairs = parse_pairs(get(v, c_show))
        if any(k == "16" for k, _ in show_pairs):
            ns = [(k, (new_dia if k == "16" else n)) for k, n in show_pairs]
            changes.append((r, "RewardShow", get(v, c_show), fmt_pairs(ns), "R9-星级阶梯"))
    return wb, ws, idx, changes, report


# ─────────────────────────── 自检 ───────────────────────────

def verify(check_star=True):
    """自检范围 = 本次改动范围。`--only firstpay` 时不该被星级礼的历史倒挂拦住
    （50 元神之塔 / 488 档那 4 处是 R9 之前就存在的存量，另行处理）。"""
    msgs, ok = [], True

    # 1) 首充活动：每天 ≤2 项（客户端硬限制）+ 券数够十连
    wb, ws, idx = load(F_ACTREWARD)
    c_act, c_val, c_rew = col(idx, "ActivityId"), col(idx, "Values"), col(idx, "Reward")
    days = collections.defaultdict(list)
    for r, v in iter_rows(ws):
        if get(v, c_act) != FIRSTPAY_ACTIVITY_ID:
            continue
        key = parse_ints(get(v, c_val))
        if len(key) < 2:
            continue
        days[key[0]].append((key[1], parse_pairs(get(v, c_rew))))

    for tier in (6, 100):
        rows = sorted(days.get(tier, []))
        if len(rows) != 3:
            msgs.append("✗ 首充 %d 元档天数 = %d（应为 3）" % (tier, len(rows)))
            ok = False
            continue
        over = [(d, len(p)) for d, p in rows if len(p) > FIRSTPAY_SLOTS]
        msgs.append("%s 首充 %d 元档每天奖励项 ≤ %d 格 %s"
                    % ("✓" if not over else "✗", tier, FIRSTPAY_SLOTS, over if over else ""))
        if over:
            ok = False
        card19 = sum(n for _, p in rows for k, n in p if k == "19")
        card20 = sum(n for _, p in rows for k, n in p if k == "20")
        total_dia = sum(diamonds(p) for _, p in rows)
        need_card = SINGLE_PULLS_6YUAN if tier == 6 else 10
        msgs.append("%s 首充 %d 元档: 紫晶卡×%d（需 %d）· 招募卡×%d · 三天钻石 %d"
                    % ("✓" if card19 >= need_card else "✗", tier, card19, need_card,
                       card20, total_dia))
        if card19 < need_card:
            ok = False

    # 2) 6 元档：券与钻必须配平（券多于能配的钻 = 死库存），且抽等值不得压过月卡
    wb, ws, idx = load(F_RECHARGE)
    (c_id, c_fm, c_price, c_base, c_show_type,
     c_sale, c_show, c_type) = (col(idx, "Id"), col(idx, "FirstMultiple"), col(idx, "Price"),
                                col(idx, "BaseReward"), col(idx, "ShowType"),
                                col(idx, "OnSaleRule"), col(idx, "RewardShow"), col(idx, "Type"))
    got6 = 0
    for r, v in iter_rows(ws):
        if get(v, c_id) != 1:
            continue
        base = diamonds(parse_pairs(get(v, c_base)))
        fm = diamonds(parse_pairs(get(v, c_fm)))
        price = get(v, c_price) or 0
        got6 = base + fm
        card6 = sum(n for _, p in days.get(6, []) for k, n in p if k == "19")
        pulls = got6 // SINGLE_PULL_DIAMONDS
        dead = card6 - pulls
        nominal = card6 + got6 / float(SINGLE_PULL_DIAMONDS)
        per_yuan = nominal / price if price else 0
        mc = monthcard_pull_per_yuan()
        head = "✓" if dead <= 0 and (mc is None or per_yuan <= mc + 1e-9) else "✗"
        msgs.append("%s 6 元档首购合计 %d 钻（基础 %d + 首购 %d）· 紫晶卡×%d ⇒ 可抽 %d 次，死券 %d 张"
                    % (head, got6, base, fm, card6, pulls, dead))
        msgs.append("%s 6 元档名义 %.2f 抽 = %.3f 抽/元%s"
                    % ("✓" if head == "✓" else "✗", nominal, per_yuan,
                       "" if mc is None else ("（月卡 %.3f，上限）" % mc)))
        if head != "✓":
            ok = False

    # 2b) 直充首购总钻按价格单调不减 —— R16 的病根就是 6 元被单独抬到 30 元之上
    ladder = []
    for r, v in iter_rows(ws):
        if get(v, c_type) != 3:
            continue
        price = get(v, c_price) or 0
        if price <= 0:
            continue
        ladder.append((price, diamonds(parse_pairs(get(v, c_base)))
                       + diamonds(parse_pairs(get(v, c_fm)))))
    ladder.sort()
    drop = [("%d元" % p0, g0, "%d元" % p1, g1)
            for (p0, g0), (p1, g1) in zip(ladder, ladder[1:]) if g1 < g0]
    msgs.append("%s 直充首购总钻按价格单调不减（倒挂 %d 处）%s"
                % ("✓" if not drop else "✗", len(drop), drop[:4] if drop else ""))
    if drop:
        ok = False

    # 3) 首购赠礼写入一致
    per_sku = {}
    for r, v in iter_rows(ws):
        if get(v, c_id) in SKU_FIRST_MULTIPLE:
            per_sku[get(v, c_id)] = diamonds(parse_pairs(get(v, c_fm)))
    bad = {k: per_sku.get(k) for k, want in SKU_FIRST_MULTIPLE.items() if per_sku.get(k) != want}
    msgs.append("%s 首购赠礼：%s %s" % ("✓" if not bad else "✗", per_sku, bad if bad else ""))
    if bad:
        ok = False

    # 3b) 月卡 SKU 是否还活着（关停 ⇒ 首购赠永远到不了账，别再写进成果清单）
    for r, v in iter_rows(ws):
        if get(v, c_id) != 9:
            continue
        alive = DEAD_ONSALE not in str(get(v, c_sale) or "")
        msgs.append("%s 月卡 SKU id=9 首购赠 %d 钻%s"
                    % ("✓" if not alive else "✗",
                       diamonds(parse_pairs(get(v, c_fm))),
                       "（OnSaleRule=%s 永久关停，该赠礼不可达）" % get(v, c_sale)
                       if not alive else "可购买"))

    if not check_star:
        msgs.append("· 星级礼检查已跳过（本次 --only firstpay，未改动 R9 的相关行）")
        return ok, msgs

    # 4) 星级礼：不低于直充 + 星级单调
    direct = direct_ratio_table(ws, idx)
    smap = star_map()
    rows = []
    for r, v in iter_rows(ws):
        if get(v, c_show_type) != STAR_SHOW_TYPE or DEAD_ONSALE in str(get(v, c_sale) or ""):
            continue
        price = get(v, c_price) or 0
        dia = diamonds(parse_pairs(get(v, c_base)))
        if price <= 0 or dia <= 0:
            continue
        rows.append((smap.get(get(v, c_id), 5), price, dia / price, get(v, c_id)))

    under = [(sid, p, round(q, 2)) for _, p, q, sid in rows if q + 1e-9 < direct_ratio_at(direct, p)]
    msgs.append("%s 星级礼 钻/元 不低于直充同档（倒挂 %d 个）%s"
                % ("✓" if not under else "✗", len(under), under[:4] if under else ""))
    if under:
        ok = False

    by_price = collections.defaultdict(list)
    for star, price, q, sid in rows:
        if sid not in smap:      # 等级礼/通关礼/神之塔同属 ShowType=8，但没有星级维度
            continue
        by_price[price].append((star, q, sid))
    bad_mono = []
    for price, lst in by_price.items():
        lst.sort()
        for (s1, q1, _), (s2, q2, _) in zip(lst, lst[1:]):
            if s2 > s1 and q2 + 1e-9 < q1:
                bad_mono.append((price, s1, round(q1, 2), s2, round(q2, 2)))
    msgs.append("%s 星级礼 同价档按星级单调不降 %s"
                % ("✓" if not bad_mono else "✗", bad_mono[:4] if bad_mono else ""))
    if bad_mono:
        ok = False

    # 5) RewardShow 与 BaseReward 的钻石一致（仅 ShowType=8；基金类刻意不等）
    mism = []
    for r, v in iter_rows(ws):
        if get(v, c_show_type) != STAR_SHOW_TYPE:
            continue
        b = diamonds(parse_pairs(get(v, c_base)))
        s = diamonds(parse_pairs(get(v, c_show)))
        if b and s and b != s:
            mism.append((get(v, c_id), b, s))
    msgs.append("%s RewardShow 钻石与 BaseReward 一致（不一致 %d 个）%s"
                % ("✓" if not mism else "✗", len(mism), mism[:4] if mism else ""))
    if mism:
        ok = False

    ladder = collections.defaultdict(list)
    for star, price, q, sid in rows:
        if sid in smap:
            ladder[star].append((price, q))
    msgs.append("   星级礼 钻/元 阶梯（按星级）：")
    for star in sorted(ladder):
        msgs.append("     %2d星  %s" % (star, "  ".join("%d元→%.2f" % (p, q)
                                                       for p, q in sorted(ladder[star]))))
    return ok, msgs


# ─────────────────────────── 主流程 ───────────────────────────

def plan_all(star_bonus, do_firstpay=True, do_star=True):
    changes = collections.OrderedDict()
    report = {"firstpay": [], "first": [], "star": []}
    wb, ws, idx, ch, rep = plan_firstpay_activity()
    changes[F_ACTREWARD] = (wb, ws, idx, ch if do_firstpay else [])
    if do_firstpay:
        report["firstpay"] = rep
    wb2, ws2, idx2, ch2, rep2 = plan_sku_first_multiple()
    ch3, rep3 = [], []
    if do_star:
        wb3, ws3, idx3, ch3, rep3 = plan_star_ladder(star_bonus)
    changes[F_RECHARGE] = (wb2, ws2, idx2, (ch2 if do_firstpay else []) + ch3)
    if do_firstpay:
        report["first"] = rep2
    report["star"] = rep3
    return changes, report


def print_plan(changes, report):
    print("=" * 96)
    print("首充 / 进阶充值 数值优化 · DRY-RUN")
    print("=" * 96)

    print("\n【R7 首充活动（ActivityRewardConfig · ActivityId=5 · 每天最多 2 格）】")
    print("  %-6s %-4s %-5s %-30s %s" % ("档位", "天", "行Id", "改前", "改后"))
    for tier, day, rid, before, after in sorted(report["firstpay"]):
        print("  %-6s %-4s %-5s %-30s %s" % ("%d元" % tier, day, rid,
                                            fmt_pairs(before), fmt_pairs(after)))

    print("\n【R8 SKU 首购赠礼（RechargeCommodityConfig.FirstMultiple）】")
    for sid, before, after in report["first"]:
        print("  id=%-4s 首购赠 %d → %d 钻" % (sid, before, after))

    print("\n【R9 星级成长礼阶梯（ShowType=8）】")
    star_rows = report["star"]
    smap = star_map()
    changed = [x for x in star_rows if x[5] > x[3] * 1.01]
    print("  在架 SKU %d 个，其中 %d 个抬钻" % (len(star_rows), len(changed)))
    by_star = collections.defaultdict(list)
    for sid, price, star, cur, q0, new, q1, _ in star_rows:
        if sid in smap:
            by_star[star].append((price, q0, q1))
    print("  %-5s %-6s %-10s %-10s" % ("星级", "价格", "改前钻/元", "改后钻/元"))
    for star in sorted(by_star):
        for price, q0, q1 in sorted(by_star[star]):
            print("  %-5s %-6s %-10.2f %-10.2f%s" % ("%d星" % star, price, q0, q1,
                                                     "  *" if q1 > q0 * 1.01 else ""))

    total = sum(len(v[3]) for v in changes.values())
    print("\n合计改动单元格 %d 个：%s" % (total, {k: len(v[3]) for k, v in changes.items()}))


def do_apply(changes, star_bonus, check_star=True):
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

    ok, msgs = verify(check_star)
    print("\n自检:")
    for m in msgs:
        print("  " + m)
    if not ok:
        print("\n✗ 自检未通过，自动回滚")
        do_revert(bdir)
        sys.exit(1)
    with open(os.path.join(bdir, "_manifest.json"), "w") as f:
        json.dump({"star_bonus": star_bonus,
                   "cells": {k: len(v[3]) for k, v in changes.items()}},
                  f, indent=2, ensure_ascii=False)
    print("\n✓ 自检通过。备份目录: %s" % bdir)
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
    ap.add_argument("--star-bonus", type=float, default=BONUS_STAR,
                    help="每升 1 星增加的钻/元（默认 %.2f）" % BONUS_STAR)
    ap.add_argument("--verify-only", action="store_true", help="只跑自检，不改表")
    ap.add_argument("--only", choices=("all", "firstpay", "star"), default="all",
                    help="只做首充（R7+R8）/ 只做星级阶梯（R9）/ 全做")
    args = ap.parse_args()

    if args.list_backups:
        if os.path.isdir(BACKUP_ROOT):
            for d in sorted(os.listdir(BACKUP_ROOT)):
                print(os.path.join(BACKUP_ROOT, d))
        return
    if args.revert:
        do_revert(args.revert)
        return
    if args.verify_only:
        ok, msgs = verify(args.only != "firstpay")
        print("自检: %s" % ("通过" if ok else "未通过"))
        for m in msgs:
            print("  " + m)
        sys.exit(0 if ok else 1)

    changes, report = plan_all(args.star_bonus,
                               do_firstpay=args.only in ("all", "firstpay"),
                               do_star=args.only in ("all", "star"))
    print_plan(changes, report)
    if args.apply:
        print("\n" + "=" * 96)
        do_apply(changes, args.star_bonus, check_star=args.only != "firstpay")
    else:
        print("\n（dry-run，未写盘。加 --apply 落表）")


if __name__ == "__main__":
    main()
