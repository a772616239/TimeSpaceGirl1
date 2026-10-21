#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
月卡「每月限 1 次」—— 限量代替降价，保护 1.36 抽/元 这个全表最甜的参照点

背景（详见 docs/付费价值带重建-20261021.md 第 6 节与 docs/星级梯度与月卡月限-20261021.md）：

  月卡 12 元 = 每日 120 钻 × 30 天（`MonthcardConfig.BaseReward`）+ 购买即得 300 钻
  ⇒ ≈ 1.36–1.48 抽/元，是直充（0.059）的 **23–25 倍**，比 R10 之后最甜的
     648 元礼包（0.291）还甜 **4.7 倍**。

  这个锚点本身不该降 —— 它是留存/转化的钩子。真正的问题是**它可以被无限续**：
    1. `RechargeCommodityConfig` 里 9 / 10 / 11（月卡 / 月卡30元变体 / 豪华月卡）
       的 `Limit=0`，`DailyUpdate` 为空 ⇒ 服务端 `AbstractWelfareBag.buyOrder()`
       完全不拦，玩家可以在一天内把 12 元月卡连买 N 次；
    2. 真正的白送通道更隐蔽：**全表 830 个 SKU 的 `AccumulativeRecharge` 都是 1**，
       `BuyGoodsLogic` 里只要 `月累计充值额` 从 <12 跨到 ≥12 就 `putMonthCard()`，
       即「任意 12 元充值 = 送一张月卡」。这条是服务端行为，配置改不动。

  所以本脚本只做配置层能做的、也是「限量而不降价」正确落点的那一半：
  把三个 SKU 改成**自然 30 天刷新 + 限购 1 次**（复用 `Time=8/DailyUpdate=30/Limit=1`
  这套已有可用范式，见 SKU 3001–3010），价格、内容、天数一个字节都不动。

服务端语义（已逐行核对，勿凭印象改）：
  · `AbstractWelfareBag.buy()`      → buyTimes += 1（落库）
  · `AbstractWelfareBag.buyOrder()` → `limit != 0 && buyTimes >= limit` ⇒ 拒绝购买
  · `AbstractWelfareBag.refresh()`  → `Time=7` 自然周 / `Time=8` 自然月 重置 buyTimes=0
  · `PerpetualWelfareBag` 构造器     → `Time=8` ⇒ startTime=月初、refreshTime=下月初；
                                      `DailyUpdate>0` ⇒ refreshTime=今零+30 天（兜底）
  · `BuyGoodsLogic.refreshUnitWF()` → refreshTime 到点自动 refresh()
  · `SRechargeCommodityConfig.init()`→ `DailyUpdate>0` 的 SKU 会进 refreshItemInfo，
                                      由 `initOwernBagInfo()` 保证 refreshBagMap 有值

用法：
    python scripts/monetization_monthcard.py              # dry-run
    python scripts/monetization_monthcard.py --apply      # 备份 + 落表 + 自检（失败自动回滚）
    python scripts/monetization_monthcard.py --verify-only
    python scripts/monetization_monthcard.py --revert <dir>
    python scripts/monetization_monthcard.py --list-backups
"""
import argparse
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

BACKUP_ROOT = _bak_sub("_backup_before_monthcard")
F_RECHARGE = "RechargeCommodityConfig"
F_MONTHCARD = "MonthcardConfig"
DATA_START_ROW = 6

# 月卡家族：Type 1 = 月卡，Type 6 = 豪华月卡
TARGETS = {
    9: "月卡 12 元",
    10: "月卡 30 元变体",
    11: "豪华月卡 98 元",
}
MONTHCARD_TYPES = {1, 6}

# 落表值：自然月刷新 + 限购 1 次（与 SKU 3001–3010 的既有范式一致）
NEW_TIME = 8          # 8 = 自然月刷新（AbstractWelfareBag.refresh / PerpetualWelfareBag 构造器）
NEW_LIMIT = 1
NEW_LIMIT_SHOW = 1
NEW_DAILY_UPDATE = 30

TOUCH_COLS = ("Time", "Limit", "LimitShow", "DailyUpdate")
VALUE_COLS = ("Price", "ContiueDays", "BaseReward", "RewardShow",
              "ExtraReward", "FirstMultiple", "Name", "Type")


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


def collect(ws, idx):
    rows = {}
    for r, v in iter_rows(ws):
        rows[v[idx["Id"]]] = {
            "row": r,
            **{c: v[idx[c]] for c in TOUCH_COLS + VALUE_COLS if idx.get(c) is not None},
        }
    return rows


def plan(rows):
    """返回 [(id, 现状 dict, 目标 dict)]。"""
    out = []
    for sid, name in TARGETS.items():
        cur = rows.get(sid)
        if cur is None:
            sys.exit("配置表里找不到 SKU %s（%s）" % (sid, name))
        if cur.get("Type") not in MONTHCARD_TYPES:
            sys.exit("SKU %s 的 Type=%s，不是月卡类（期望 1/6）" % (sid, cur.get("Type")))
        want = {"Time": NEW_TIME, "Limit": NEW_LIMIT,
                "LimitShow": NEW_LIMIT_SHOW, "DailyUpdate": NEW_DAILY_UPDATE}
        out.append((sid, name, cur, want))
    return out


def print_report(rows, plans):
    print("=" * 88)
    print("月卡：限量（每月 1 次）而不是降价 —— 价格/内容/天数一个字节都不动")
    print("=" * 88)
    print("%-4s %-14s %-6s %-6s %-6s %-7s %-8s" % ("id", "名称", "Type", "Price", "Days", "Limit", "DailyUpdate"))
    for sid, name, cur, want in plans:
        print("%-4s %-14s %-6s %-6s %-6s %-7s %-8s"
              % (sid, name, cur.get("Type"), cur.get("Price"),
                 cur.get("ContiueDays"), cur.get("Limit"), cur.get("DailyUpdate")))
    print()
    print("改后：")
    print("%-4s %-14s %-6s %-8s %-9s %-10s" % ("id", "名称", "Time", "Limit", "LimitShow", "DailyUpdate"))
    for sid, name, cur, want in plans:
        print("%-4s %-14s %-6s %-8s %-9s %-10s"
              % (sid, name, want["Time"], want["Limit"], want["LimitShow"], want["DailyUpdate"]))
    print()
    print("价值口径（不动）：月卡 12 元 = 300 钻 + 120 钻/天 × 30 天 = 3900 钻 ≈ 17.7 抽")
    print("                  ⇒ 1.48 抽/元（直充 0.059 的 25 倍，仍是全表最甜参照点）")
    print("                  ⇒ 改成限量后，这个参照点从「可以随手续」变成「每月只有一次」")
    print()
    print("⚠ 服务端还有一条配置改不动的通道（需要另议，见文档第 3 节）：")
    print("  全表 830 个 SKU 的 AccumulativeRecharge=1，BuyGoodsLogic 只要")
    print("  月累计充值额从 <12 跨到 ≥12 就 putMonthCard() —— 即「任意 12 元充值 = 送月卡」。")
    print("  本脚本限的是「重复购买月卡 SKU」，那条赠送通道要靠服务端小改或抬 MonthcardConfig.Price。")


def snapshot(rows):
    """全表快照：除三个月卡 SKU 的四列外，任何单元格变了都算越界。"""
    return {sid: dict(v) for sid, v in rows.items()}


def verify(ws, idx, before, mc_md5_before=None, mc_path=None):
    msgs, ok = [], True
    rows = collect(ws, idx)

    def add(tag, cond, detail=""):
        nonlocal ok
        if not cond:
            ok = False
        msgs.append("%s %s%s" % ("✓" if cond else "✗", tag, ("：" + detail) if detail else ""))

    add("SKU 总数与改前一致", len(rows) == len(before), "%d / %d" % (len(rows), len(before)))

    # S1 三个目标行确实落了新值
    bad = []
    for sid in TARGETS:
        cur = rows.get(sid, {})
        if (cur.get("Limit") != NEW_LIMIT or cur.get("LimitShow") != NEW_LIMIT_SHOW
                or cur.get("DailyUpdate") != NEW_DAILY_UPDATE or cur.get("Time") != NEW_TIME):
            bad.append((sid, cur.get("Time"), cur.get("Limit"),
                        cur.get("LimitShow"), cur.get("DailyUpdate")))
    add("月卡三行 = Time 8 / Limit 1 / LimitShow 1 / DailyUpdate 30", not bad, "%s" % bad)

    # S2 价值字段零改动（价格、天数、内容、展示）
    changed = []
    for sid, cur in rows.items():
        old = before.get(sid)
        if not old:
            changed.append((sid, "新增行"))
            continue
        for c in VALUE_COLS:
            if cur.get(c) != old.get(c):
                changed.append((sid, c, old.get(c), cur.get(c)))
    add("价格/天数/内容/展示零改动（不降价）", not changed, "%s" % changed[:4])

    # S3 触碰列只在三个月卡行变化
    leaked = []
    for sid, cur in rows.items():
        old = before.get(sid)
        if not old:
            continue
        for c in TOUCH_COLS:
            if cur.get(c) != old.get(c) and sid not in TARGETS:
                leaked.append((sid, c, old.get(c), cur.get(c)))
    add("Limit/DailyUpdate/Time 未被其他 SKU 波及", not leaked, "%s" % leaked[:4])

    # S4 月卡类 SKU 全部限购（不留后门）
    open_ended = [(sid, r.get("Limit")) for sid, r in rows.items()
                  if r.get("Type") in MONTHCARD_TYPES and r.get("Limit") in (None, 0)]
    add("所有月卡类 SKU 都已限购", not open_ended, "%s" % open_ended)

    # S5 MonthcardConfig 未被动过
    if mc_path and mc_md5_before:
        import hashlib
        with open(mc_path, "rb") as f:
            now = hashlib.md5(f.read()).hexdigest()
        add("MonthcardConfig 零改动（120/360 钻每日不变）", now == mc_md5_before,
            "%s" % ("md5 一致" if now == mc_md5_before else "md5 变了"))
    return ok, msgs


def backup(paths):
    d = os.path.join(BACKUP_ROOT, time.strftime("%Y%m%d-%H%M%S"))
    os.makedirs(d, exist_ok=True)
    for p in paths:
        shutil.copy2(p, os.path.join(d, os.path.basename(p)))
    return d


def apply_plan(ws, idx, plans):
    for sid, _name, _cur, want in plans:
        r = _cur["row"]
        for c, v in want.items():
            if idx.get(c) is None:
                sys.exit("表里缺列 %s" % c)
            ws.cell(r, idx[c] + 1).value = v


def main():
    ap = argparse.ArgumentParser(add_help=True)
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--verify-only", action="store_true")
    ap.add_argument("--revert", metavar="DIR")
    ap.add_argument("--list-backups", action="store_true")
    args = ap.parse_args()

    if args.list_backups:
        if not os.path.isdir(BACKUP_ROOT):
            print("没有备份目录：%s" % BACKUP_ROOT)
            return 0
        for d in sorted(os.listdir(BACKUP_ROOT)):
            if os.path.isdir(os.path.join(BACKUP_ROOT, d)):
                print(os.path.join(BACKUP_ROOT, d))
        return 0

    if args.revert:
        if not os.path.isdir(args.revert):
            sys.exit("不是目录：%s" % args.revert)
        for f in sorted(os.listdir(args.revert)):
            if f.endswith(".xlsx"):
                shutil.copy2(os.path.join(args.revert, f), os.path.join(BASE, f))
                print("已回滚 %s" % f)
        return 0

    wb, path = load(F_RECHARGE)
    ws = wb.worksheets[0]
    idx = header_index(ws)
    rows = collect(ws, idx)
    plans = plan(rows)
    print_report(rows, plans)

    mc_path = os.path.join(BASE, F_MONTHCARD + ".xlsx")
    import hashlib
    mc_md5 = hashlib.md5(open(mc_path, "rb").read()).hexdigest() if os.path.exists(mc_path) else None

    if args.verify_only:
        ok, msgs = verify(ws, idx, snapshot(rows), mc_md5, mc_path)
        print("\n".join(msgs))
        return 0 if ok else 1

    todo = [p for p in plans if any(p[2].get(c) != p[3][c] for c in p[3])]
    if not todo:
        print("\n三个月卡 SKU 已是限购状态，无需改动。")
        return 0
    if not args.apply:
        print("\n[dry-run] 未写盘。确认无误后加 --apply。")
        return 0

    snap = snapshot(rows)
    bak = backup([path])
    print("\n备份：%s" % bak)
    apply_plan(ws, idx, plans)
    wb.save(path)
    wb.close()

    wb2, _ = load(F_RECHARGE)
    ws2 = wb2.worksheets[0]
    idx2 = header_index(ws2)
    ok, msgs = verify(ws2, idx2, snap, mc_md5, mc_path)
    print("\n自检：")
    print("\n".join(msgs))
    if not ok:
        print("\n❌ 自检失败，自动回滚…")
        for f in sorted(os.listdir(bak)):
            if f.endswith(".xlsx"):
                shutil.copy2(os.path.join(bak, f), os.path.join(BASE, f))
        print("已回滚到 %s" % bak)
        return 1
    print("\n✅ 落表完成。回滚：--revert %s" % bak)
    print("⚠ 需服务端重启（conf/server/RechargeCommodityConfig.txt 同步）后才生效；")
    print("  老玩家 Mongo 里的礼包袋 limit 仍是 0，见文档『上线顺序』第 2 步。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
