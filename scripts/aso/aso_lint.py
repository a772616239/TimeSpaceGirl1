#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""商店文案闸门：长度、缺字段、简繁/日文串味、夸大措辞、与基线的差异。

    aso_lint.py --variant B                 # 默认对照 A 基线
    aso_lint.py --variant B --baseline A --json
    aso_lint.py --all                       # 所有变体都过一遍

判定口径
--------
- **阻断（红）**：超 Play 硬上限、字段缺失、ja/繁中出现明确简体字、长描述过短。
- **提醒（黄）**：夸大/不可验证措辞、重复空格、与基线无差异（实验无意义）、
  标题顶格且无可替换空间。
- 简繁/日文检测是**启发式字符表**，不是词典 —— 命中要人看一眼再改，
  但漏检比误检危险，所以只把「简体专用字」当红。

退出码：0 全绿 / 1 有阻断 / 2 用法错
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aso_common as C  # noqa: E402

# 简 → 繁 对照（只收「形不同且不会误伤日文」的字）。
# 🔴 上一版把这些字拼成大字符串，把「体/数/点/用/特/值」也塞进去了 ⇒
#    日文正文（体・数・点 全是日文正字）和繁体正文（用・特・值 通用）直接红成一片。
#    现在用显式映射表达「简体的这个字，繁体/日文必须写成那个字」，
#    只有左边那个简化形才算出错。
SIMPLIFIED_MAP = {
    "时": "時", "们": "們", "这": "這", "说": "說", "间": "間", "动": "動",
    "战": "戰", "术": "術", "级": "級", "统": "統", "结": "結", "网": "網",
    "优": "優", "从": "從", "开": "開", "无": "無", "组": "組", "种": "種",
    "让": "讓", "对": "對", "应": "應", "报": "報", "奖": "獎", "励": "勵",
    "队": "隊", "员": "員", "费": "費", "买": "買", "卖": "賣", "门": "門",
    "长": "長", "见": "見", "观": "觀", "爱": "愛", "欢": "歡", "觉": "覺",
    "认": "認", "识": "識", "语": "語", "话": "話", "计": "計", "设": "設",
    "备": "備", "单": "單", "双": "雙", "边": "邊", "际": "際", "处": "處",
    "图": "圖", "标": "標", "荐": "薦", "触": "觸", "输": "輸", "赢": "贏",
    "顾": "顧", "选": "選", "择": "擇", "击": "擊", "敌": "敵", "装": "裝",
    "联": "聯", "简": "簡", "杂": "雜", "转": "轉", "达": "達", "领": "領",
    "导": "導", "东": "東", "确": "確", "细": "細", "节": "節", "记": "記",
    "录": "錄", "习": "習", "惯": "慣", "问": "問", "题": "題", "势": "勢",
    "营": "營", "销": "銷", "验": "驗", "测": "測", "据": "據", "个": "個",
    "关": "關", "价": "價", "点": "點", "体": "體", "数": "數", "网": "網",
}
# 这些字虽然简体写成简化形，但**日文正字也用同一个形** ⇒ 不能在日文里判红
JP_USES_SIMPLIFIED_FORM = {"温", "体", "数", "点"}
SIMPLIFIED_ONLY = set(SIMPLIFIED_MAP) - JP_USES_SIMPLIFIED_FORM
# 繁体专用形（简中不会用），用于反向提示 zh-CN 里混了繁体
TRADITIONAL_ONLY = set(SIMPLIFIED_MAP.values())
# 夸大/不可验证措辞（Play 的「虚假陈述」条款常见踩点）
HYPE_PATTERNS = [
    ("100%", "绝对化表述"),
    ("No.1", "排名性表述"),
    ("No. 1", "排名性表述"),
    ("best game", "最高级表述"),
    ("最强", "绝对化表述"),
    ("第一", "排名性表述"),
    ("唯一", "绝对化表述"),
    ("保证中奖", "赌博性承诺"),
    ("guaranteed win", "赌博性承诺"),
    ("무료", "韩文混入"),
]

MIN_FULL = 200          # 长描述低于这个字数，商店页信息量不足
WARN_FULL = 600


def check_one(variant: str, locale: str) -> tuple[list[str], list[str], dict]:
    """返回 (阻断项, 提醒项, 摘要)。"""
    red: list[str] = []
    yellow: list[str] = []
    path = C.VARIANTS_DIR / variant / f"{locale}.json"
    if not path.is_file():
        return [f"缺少文案文件：{path}"], [], {}

    d = C.load_json(path)
    fields = C.text_fields(d)
    summary = {"variant": variant, "locale": locale, "chars": {}}

    for f in ("title", "shortDescription", "fullDescription"):
        val = fields.get(f, "")
        n = C.char_count(val)
        limit = C.LIMITS[f]
        summary["chars"][f] = n
        if not val:
            red.append(f"{f} 为空")
            continue
        if n > limit:
            red.append(f"{f} 超限 {n}/{limit}（超 {n - limit} 字）")
        if val != val.strip():
            yellow.append(f"{f} 首尾有空白")
        if "  " in val:
            yellow.append(f"{f} 含连续空格")
        if f == "title" and n >= limit:
            yellow.append(f"title 顶格 {n}/{limit}，任何加字都要先减字")
    if summary["chars"].get("fullDescription", 0) < MIN_FULL:
        red.append(f"长描述仅 {summary['chars']['fullDescription']} 字，< {MIN_FULL}，商店页信息量不足")
    elif summary["chars"].get("fullDescription", 0) < WARN_FULL:
        yellow.append(f"长描述偏短 {summary['chars']['fullDescription']} 字（参考值 ≥ {WARN_FULL}）")

    # 串味检测：排除 video 字段（URL 里不该有中文）
    body = "\n".join(fields[f] for f in ("title", "shortDescription", "fullDescription"))
    if locale in ("ja-JP", "zh-TW"):
        # 🔴 日文和繁体要用不同的表：日文正字里 体/数/点/温 就是简化形，
        #    拿繁体表去判日文会满屏误报；反过来繁体正文里出现「体」确实该改成「體」。
        bad_set = SIMPLIFIED_ONLY if locale == "ja-JP" else set(SIMPLIFIED_MAP)
        bad = sorted({ch for ch in body if ch in bad_set})
        if bad:
            red.append(f"{'日文' if locale == 'ja-JP' else '繁体'}文案里出现简体专用字："
                       f"{''.join(bad)}")
    if locale == "zh-CN":
        bad = sorted({ch for ch in body if ch in TRADITIONAL_ONLY})
        if bad:
            yellow.append(f"简中文案里出现繁体字：{''.join(bad)}（若非刻意用港台词，建议改回简体）")
    if locale == "zh-TW":
        trad = sum(1 for ch in body if ch in TRADITIONAL_ONLY)
        simp = sum(1 for ch in body if ch in SIMPLIFIED_ONLY)
        summary["trad_ratio"] = f"{trad}繁/{simp}简"
        if simp == 0 and trad < 15:
            yellow.append(f"繁体特征字仅 {trad} 个 —— 可能只是把简体套了字形，人眼过一遍")

    for pat, why in HYPE_PATTERNS:
        if pat.lower() in body.lower():
            yellow.append(f"含「{pat}」（{why}），Play 虚假陈述条款容易被追问")

    video = fields.get("video", "")
    if video and not video.startswith("https://"):
        yellow.append(f"video 不是 https 链接：{video}")

    return red, yellow, summary


def diff_against_baseline(variant: str, baseline: str, locales: list[str]) -> list[str]:
    out = []
    for loc in locales:
        p = C.VARIANTS_DIR / variant / f"{loc}.json"
        b = C.VARIANTS_DIR / baseline / f"{loc}.json"
        if not p.is_file() or not b.is_file():
            continue
        new, old = C.text_fields(C.load_json(p)), C.text_fields(C.load_json(b))
        same = [f for f in ("title", "shortDescription", "fullDescription")
                if new.get(f) == old.get(f)]
        changed = [f for f in ("title", "shortDescription", "fullDescription")
                   if new.get(f) != old.get(f)]
        if not changed:
            out.append(f"{loc}: 与基线 {baseline} 完全一致 —— 这个语言参与实验没有意义")
        else:
            out.append(f"{loc}: 改 {','.join(changed)}"
                       + (f"；未改 {','.join(same)}" if same else ""))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="商店文案闸门")
    ap.add_argument("--variant", default="", help="要检查的变体（与 --all 二选一）")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--baseline", default="A", help="对照基线变体（默认 A；查 A 自己时自动跳过）")
    ap.add_argument("--locales", default="")
    ap.add_argument("--json", action="store_true", help="输出机器可读 JSON")
    args = ap.parse_args()

    locales = C.parse_locales(args.locales)
    variants = C.list_variants() if args.all else [args.variant]
    if not variants or variants == [""]:
        print("要么 --variant X，要么 --all")
        return 2

    all_red = 0
    report = {"variants": [], "blocking": 0}
    for v in variants:
        rows, detail = [], []
        vred = 0
        for loc in locales:
            red, yellow, summary = check_one(v, loc)
            vred += len(red)
            c = summary.get("chars", {})
            rows.append([
                loc, C.LOCALES[loc]["label"],
                f"{c.get('title', 0)}/{C.LIMITS['title']}",
                f"{c.get('shortDescription', 0)}/{C.LIMITS['shortDescription']}",
                f"{c.get('fullDescription', 0)}/{C.LIMITS['fullDescription']}",
                "红 %d 黄 %d" % (len(red), len(yellow)),
            ])
            detail.append({"locale": loc, "red": red, "yellow": yellow, "summary": summary})
        print(f"\n=== 变体 {v} ===")
        C.print_table(rows, ["locale", "语言", "标题", "短描述", "长描述", "问题"])
        for dd in detail:
            for r in dd["red"]:
                print(f"  🔴 {dd['locale']}: {r}")
            for y in dd["yellow"]:
                print(f"  🟡 {dd['locale']}: {y}")
        if v != args.baseline and (C.VARIANTS_DIR / args.baseline).is_dir():
            print(f"  -- 与基线 {args.baseline} 的差异 --")
            for line in diff_against_baseline(v, args.baseline, [d["locale"] for d in detail]):
                print(f"     {line}")
        all_red += vred
        report["variants"].append({"variant": v, "blocking": vred, "locales": detail})
    report["blocking"] = all_red

    if args.json:
        out = C.ASO_ROOT / "reports" / "listing_lint.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"\n[json] {out}")

    print(f"\n合计阻断 {all_red} 项")
    return 0 if all_red == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
