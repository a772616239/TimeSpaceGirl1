#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""店面 A/B：登记、快照、读数。

🔴 先说清楚 Play 的能力边界（2026-10-23 核对）
---------------------------------------------
Play 的「商店页实验（store listing experiments）」**没有公开 API**：
`edits.listings` / `edits.images` 能改文案和图片，但建实验、看实验结论只能在
Console 网页里做。所以本脚本做的是**能自动化的那一半**：

1. `snapshot`  把「此刻要上的那一版」的文案 + 素材哈希存下来（否则两周后没人知道当时测的是啥）
2. `start`     登记实验：变体、动的元素、语言、窗口天数、假设
3. `status`    看还有几天、该切哪个变体
4. `report`    吃 Console「商店分析」导出的 CSV，算两个窗口的转化率差
5. `close`     定胜负、写结论

读数纪律（和回测那条一样）
--------------------------
**窗口天数不足 / 曝光量不足 / 缺列 ⇒ 直接报「不下结论」，不输出 uplift 数字。**
宁可说「数据不够」，也不许编一个 +12%。

用法
----
    aso_experiment.py snapshot --variant B
    aso_experiment.py start --variant B --baseline A --element copy --days 14 \
        --hypothesis "修正 ja 错字与 zh-TW 简繁混排，转化率提升"
    aso_experiment.py status
    aso_experiment.py report --exp aso-20261023-copy --csv ~/Downloads/store_analysis.csv
    aso_experiment.py close --exp aso-20261023-copy --winner B --note "..."

退出码：0 正常 / 1 有阻断（数据不足等）/ 2 用法错
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aso_common as C  # noqa: E402

MIN_DAYS = 7              # 单窗口最短天数（Play 官方建议至少 7 天覆盖完整周周期）
MIN_VISITORS = 1000       # 单窗口最少商店页访问量，低于这个转化率噪声盖过信号


# --------------------------------------------------------------------------- #
def _exp_path(exp_id: str) -> Path:
    return C.EXPERIMENTS_DIR / f"{exp_id}.json"


def _new_id(variant: str, element: str) -> str:
    return f"aso-{datetime.now():%Y%m%d-%H%M}-{element}-{variant}".lower()


def _sha1(p: Path) -> str:
    h = hashlib.sha1()
    h.update(p.read_bytes())
    return h.hexdigest()


def cmd_snapshot(args) -> int:
    """当前变体的「证据快照」：文案全文 + 每张图哈希。"""
    snap = {"variant": args.variant, "at": datetime.now().isoformat(timespec="seconds"),
            "listings": {}, "assets": {}}
    for loc, listing in C.iter_listings(args.variant):
        snap["listings"][loc] = C.text_fields(listing)
    d = C.DERIVED_DIR / args.variant
    if d.is_dir():
        for f in sorted(d.rglob("*.png")):
            snap["assets"][str(f.relative_to(d))] = {"sha1": _sha1(f),
                                                     "bytes": f.stat().st_size}
    out_dir = C.ASO_ROOT / "snapshots"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{args.variant}-{datetime.now():%Y%m%d-%H%M%S}.json"
    out.write_text(json.dumps(snap, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[snapshot] {out}")
    print(f"  文案 {len(snap['listings'])} 语 / 素材 {len(snap['assets'])} 张")
    return 0


def cmd_start(args) -> int:
    exp_id = args.id or _new_id(args.variant, args.element)
    p = _exp_path(exp_id)
    if p.exists() and not args.force:
        print(f"实验已存在：{p}（要覆盖加 --force）")
        return 2
    C.EXPERIMENTS_DIR.mkdir(parents=True, exist_ok=True)
    today = date.today()
    exp = {
        "id": exp_id,
        "created": datetime.now().isoformat(timespec="seconds"),
        "status": "planned",
        "baseline": args.baseline,
        "variant": args.variant,
        "element": args.element,          # copy / screenshots / feature / icon
        "locales": C.parse_locales(args.locales),
        "hypothesis": args.hypothesis,
        "window_days": args.days,
        "windows": [
            {"variant": args.baseline, "start": str(today), "end": None},
            {"variant": args.variant,
             "start": str(today + timedelta(days=0)), "end": None},
        ],
        "readout": None,
        "note": args.note,
        "rules": [
            f"单窗口 ≥ {MIN_DAYS} 天且 ≥ {MIN_VISITORS} 次商店页访问才读数",
            "🔴 一次只动一个元素（文案/截图/图标分开测），否则分不清是谁的效果",
            "切变体时先在 Console 确认「上一版已生效」，再记窗口起点",
            "Play 原生实验没有 API ⇒ 若要严格随机分流，去 Console 手动建实验，本脚本只做记录",
        ],
    }
    p.write_text(json.dumps(exp, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[start] {exp_id}")
    print(f"  假设：{args.hypothesis}")
    print(f"  对照 {args.baseline} → 变体 {args.variant}，元素 {args.element}，"
          f"语言 {','.join(exp['locales'])}，窗口 {args.days} 天")
    print("  下一步：push 变体 → 在 Console 点「送审」→ 生效当天记窗口起点")
    return 0


def cmd_status(args) -> int:
    exps = sorted(C.EXPERIMENTS_DIR.glob("*.json")) if C.EXPERIMENTS_DIR.is_dir() else []
    if not exps:
        print("还没有实验。aso_experiment.py start --variant B …")
        return 0
    rows = []
    for f in exps:
        e = C.load_json(f)
        rows.append([e["id"], e["status"], f'{e["baseline"]}→{e["variant"]}',
                     e["element"], f'{e["window_days"]}d',
                     (e.get("readout") or {}).get("verdict", "-")])
    C.print_table(rows, ["实验", "状态", "变体", "元素", "窗口", "结论"])
    return 0


# --------------------------------------------------------------------------- #
# report
# --------------------------------------------------------------------------- #
def _norm(s: str) -> str:
    return s.strip().lower().replace(" ", "_")


DATE_KEYS = ("date", "日期", "day")
VISITOR_KEYS = ("store_listing_visitors", "visitors", "商店页访问者数", "访问者", "store_visitors")
INSTALL_KEYS = ("installers", "installs", "安装数", "安装者", "new_installers")
COUNTRY_KEYS = ("country", "country_code", "国家", "国家/地区")


def _pick(header: list[str], keys: tuple[str, ...]) -> str | None:
    for h in header:
        if _norm(h) in keys:
            return h
    for h in header:
        for k in keys:
            if k in _norm(h):
                return h
    return None


def cmd_report(args) -> int:
    e = C.load_json(_exp_path(args.exp)) if _exp_path(args.exp).is_file() else None
    if not e:
        print(f"没有这个实验：{args.exp}")
        return 2
    if not args.csv:
        print("没有给 --csv。Play 的商店页数据没有公开 API，只能在 Console：")
        print("  「商店分析」→ 右上「导出 CSV」→ 选时间范围（覆盖 A 窗口 + B 窗口）→ 下载")
        print("  然后：aso_experiment.py report --exp %s --csv <导出文件>" % args.exp)
        return 1
    p = Path(args.csv).expanduser()
    if not p.is_file():
        print(f"CSV 不存在：{p}")
        return 2

    with p.open(encoding="utf-8-sig", newline="") as fh:
        rd = csv.DictReader(fh)
        header = rd.fieldnames or []
        dk, vk, ik, ck = (_pick(header, DATE_KEYS), _pick(header, VISITOR_KEYS),
                          _pick(header, INSTALL_KEYS), _pick(header, COUNTRY_KEYS))
        if not dk or not vk or not ik:
            print("🔴 CSV 缺列，无法读数。需要：日期 + 商店页访问量 + 安装量")
            print(f"   实际表头：{header}")
            return 1
        rows = list(rd)

    wins = e["windows"]
    a_win, b_win = wins[0], wins[1]
    a_start = date.fromisoformat(a_win["start"])
    a_end = a_start + timedelta(days=e["window_days"])
    b_start = date.fromisoformat(args.b_start) if args.b_start else a_end
    b_end = b_start + timedelta(days=e["window_days"])
    buckets = {"A": {"visitors": 0, "installers": 0, "days": set()},
               "B": {"visitors": 0, "installers": 0, "days": set()}}
    for r in rows:
        raw = (r.get(dk) or "").strip()
        if not raw:
            continue
        try:
            d = date.fromisoformat(raw[:10])
        except ValueError:
            continue
        for tag, (s, t) in (("A", (a_start, a_end)), ("B", (b_start, b_end))):
            if s <= d < t:
                def num(k):
                    try:
                        return int(float(str(r.get(k) or "0").replace(",", "")))
                    except ValueError:
                        return 0
                buckets[tag]["visitors"] += num(vk)
                buckets[tag]["installers"] += num(ik)
                buckets[tag]["days"].add(d)

    def conv(b):
        return (b["installers"] / b["visitors"]) if b["visitors"] else None

    ca, cb = conv(buckets["A"]), conv(buckets["B"])
    print(f"实验 {e['id']}（{e['baseline']} → {e['variant']}，元素 {e['element']}）")
    print(f"  窗口 A {a_start}~{a_end}  {len(buckets['A']['days'])} 天  "
          f"访问 {buckets['A']['visitors']}  安装 {buckets['A']['installers']}  "
          f"转化 {('%.2f%%' % (ca * 100)) if ca is not None else '-'}")
    print(f"  窗口 B {b_start}~{b_end}  {len(buckets['B']['days'])} 天  "
          f"访问 {buckets['B']['visitors']}  安装 {buckets['B']['installers']}  "
          f"转化 {('%.2f%%' % (cb * 100)) if cb is not None else '-'}")

    blockers = []
    for tag, b in buckets.items():
        if len(b["days"]) < MIN_DAYS:
            blockers.append(f"窗口 {tag} 只有 {len(b['days'])} 天 < {MIN_DAYS} 天")
        if b["visitors"] < MIN_VISITORS:
            blockers.append(f"窗口 {tag} 访问量 {b['visitors']} < {MIN_VISITORS}")
    if ca is None or cb is None:
        blockers.append("某个窗口没有数据（转化率算不出来）")

    verdict, uplift = None, None
    if blockers:
        print("\n🔴 不下结论：")
        for x in blockers:
            print(f"   - {x}")
        verdict = "数据不足"
    else:
        uplift = (cb - ca) / ca * 100
        # 粗判：样本够但差异 <5% 一律按「无显著差异」处理，别拿噪声当战果
        if abs(uplift) < 5:
            verdict = "无显著差异"
        else:
            verdict = f"{e['variant']} 胜出 {uplift:+.1f}%" if uplift > 0 else \
                      f"{e['baseline']} 胜出 {-uplift:.1f}%"
        print(f"\n  相对变化：{uplift:+.2f}%  ⇒ {verdict}")
        print("  ⚠ 这是**顺序窗口对比**，不是随机分流：季节性、买量结构、审核变动都会污染，"
              "结论只当方向，不当定论。")

    if args.save:
        e["readout"] = {
            "at": datetime.now().isoformat(timespec="seconds"),
            "windows": {"A": [str(a_start), str(a_end)], "B": [str(b_start), str(b_end)]},
            "visitors": {"A": buckets["A"]["visitors"], "B": buckets["B"]["visitors"]},
            "installers": {"A": buckets["A"]["installers"], "B": buckets["B"]["installers"]},
            "conv": {"A": ca, "B": cb},
            "uplift_pct": None if uplift is None else round(uplift, 2),
            "verdict": verdict,
            "blockers": blockers,
        }
        _exp_path(e["id"]).write_text(json.dumps(e, ensure_ascii=False, indent=2) + "\n",
                                      encoding="utf-8")
        print(f"\n[report] 已写回 {_exp_path(e['id'])}")
    return 1 if blockers else 0


def cmd_close(args) -> int:
    p = _exp_path(args.exp)
    if not p.is_file():
        print(f"没有这个实验：{args.exp}")
        return 2
    e = C.load_json(p)
    e["status"] = "closed"
    e["winner"] = args.winner
    e["closed_at"] = datetime.now().isoformat(timespec="seconds")
    e["note"] = (e.get("note") or "") + (("\n" + args.note) if args.note else "")
    p.write_text(json.dumps(e, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[close] {e['id']} → 胜出 {args.winner}")
    print("  记得把胜出的变体目录复制成新的基线（A），否则下一轮没有干净的对照。")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="店面 A/B 登记与读数")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("snapshot")
    p.add_argument("--variant", required=True)
    p.set_defaults(func=cmd_snapshot)

    p = sub.add_parser("start")
    p.add_argument("--variant", required=True)
    p.add_argument("--baseline", default="A")
    p.add_argument("--element", choices=["copy", "screenshots", "feature", "icon"],
                   default="copy")
    p.add_argument("--locales", default="")
    p.add_argument("--days", type=int, default=14)
    p.add_argument("--hypothesis", default="")
    p.add_argument("--note", default="")
    p.add_argument("--id", default="")
    p.add_argument("--force", action="store_true")
    p.set_defaults(func=cmd_start)

    p = sub.add_parser("status")
    p.set_defaults(func=cmd_status)

    p = sub.add_parser("report")
    p.add_argument("--exp", required=True)
    p.add_argument("--csv", default="")
    p.add_argument("--b-start", default="", help="B 窗口起点（默认= A 窗口结束日）")
    p.add_argument("--save", action="store_true")
    p.set_defaults(func=cmd_report)

    p = sub.add_parser("close")
    p.add_argument("--exp", required=True)
    p.add_argument("--winner", required=True)
    p.add_argument("--note", default="")
    p.set_defaults(func=cmd_close)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
