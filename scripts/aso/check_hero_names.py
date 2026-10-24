#!/usr/bin/env python3
"""校验 ASO 文案里的人名，是否都能在游戏内语言表里查到。

为什么需要它：商店页写了游戏里并不存在的名字，用户下载后搜不到人 ⇒
「虚假宣传 + 找不到角色」双重差评。上一版英文文案就犯过：写了
King Arthur / Li Bai / Napoleon / Qin Shi Huang，而游戏内实际是
Arthur / Li Taipo / Napoleone / Ying Zheng。

做法（不用切分，避免日文名自带的「・」造成误判）：
对每一行，把官方名按长度降序做子串消解，剩下的非分隔符字符即为
「无法归属的片段」——它要么是人名写法不一致，要么是写错了。

真源：
    data_execl/base_data/Language.xlsx   (id, Chinese, English, Japanese)
    data_execl/base_data/HeroConfig.xlsx (Id, Name_txt, Quality)

用法：
    python scripts/aso/check_hero_names.py --variant N
退出码：0 全部可归属；1 存在无法归属的片段（上线前必修）
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import openpyxl

try:  # 简→繁只在核对 zh-TW 时用；缺库时降级为跳过
    from opencc import OpenCC
    _s2t = OpenCC("s2t").convert
except Exception:  # pragma: no cover
    _s2t = None

ROOT = Path(__file__).resolve().parents[2]
LANG_XLSX = ROOT / "data_execl/base_data/Language.xlsx"
HERO_XLSX = ROOT / "data_execl/base_data/HeroConfig.xlsx"

LANG_SRC = {"zh-CN": "zh-CN", "zh-TW": "zh-CN", "en-US": "en-US", "ja-JP": "ja-JP"}
# 游戏内只有 Chinese / English / Japanese 三列，zh-TW 是繁体商店页专供，
# 繁体人名允许台湾/香港的通行异译（不属于错，属于本地化）。
ZH_TW_ALIAS = {"亞森羅蘋", "唐吉訶德", "莫札特", "蕭邦", "邱吉爾", "米開朗基羅"}
SEP_CHARS = "·・、/,|｜:：;；　 \t　–—-"


def load_heroes():
    """返回 [(hero_id, quality, {locale: 游戏内官方名})]，已剔除克隆体。"""
    wb = openpyxl.load_workbook(LANG_XLSX, read_only=True, data_only=True)
    rows = list(wb[wb.sheetnames[0]].iter_rows(values_only=True))[3:]
    by_zh: dict[str, dict[str, str]] = {}
    for r in rows:
        zh, en, ja = r[2], r[3], r[4]
        if not (isinstance(zh, str) and isinstance(en, str) and en.strip()):
            continue
        by_zh.setdefault(zh.strip(), {
            "zh-CN": zh.strip(),
            "en-US": en.strip(),
            "ja-JP": (ja or "").strip(),
        })

    wb2 = openpyxl.load_workbook(HERO_XLSX, read_only=True, data_only=True)
    hr = list(wb2["HeroConfig"].iter_rows(values_only=True))
    head = hr[0]
    i_id, i_name, i_q = head.index("Id"), head.index("Name_txt"), head.index("Quality")
    out = []
    for r in hr[4:]:
        if not isinstance(r[i_id], int) or r[i_id] < 10000:
            continue
        name = r[i_name]
        if not isinstance(name, str) or "克隆" in name:
            continue
        names = by_zh.get(name.strip())
        if names is not None:
            out.append((r[i_id], r[i_q], names))
    return out


def roster_lines(full_text: str) -> list[str]:
    """只挑出「名单行」：含 ≥2 个列举分隔符、且不含句末标点。

    正文里人名也密集出现（「关羽和凯撒站在同一排，居里夫人…」），但它带
    句号/逗号，不是名单；标题行「90人・4職」分隔符不足 2 个，也不是。
    """
    out = []
    for line in full_text.split("\n"):
        s = line.strip()
        if not s or len(s) > 140:
            continue
        if any(p in s for p in "。！？.!?"):
            continue
        if sum(s.count(c) for c in "·・") >= 2:
            out.append(s)
    return out


def residue(line: str, official: set[str]) -> tuple[list[str], str]:
    """用官方名消解该行，返回 (命中的官方名, 无法归属的残余字符)。"""
    rest, hits = line, []
    for name in sorted(official, key=len, reverse=True):
        if name and name in rest:
            hits.append(name)
            rest = rest.replace(name, "")
    for ch in SEP_CHARS:
        rest = rest.replace(ch, "")
    return hits, rest


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", required=True)
    args = ap.parse_args()

    heroes = load_heroes()
    print(f"游戏内可玩角色（非克隆）: {len(heroes)}")

    vdir = ROOT / "data_aso/variants" / args.variant
    if not vdir.is_dir():
        print(f"❌ 变体不存在: {vdir}")
        return 1

    bad = 0
    for locale, src in LANG_SRC.items():
        f = vdir / f"{locale}.json"
        if not f.exists():
            print(f"⚠️  {locale}: 无文案，跳过")
            continue
        full = json.loads(f.read_text(encoding="utf-8"))["fullDescription"]
        official = {h[2][src] for h in heroes if h[2].get(src)}
        blocking = True
        if locale == "zh-TW":
            # 游戏内没有繁体列，客户端走简→繁；繁体人名按台湾通行译法比对
            if _s2t is None:
                print("⚠️  zh-TW: 缺 opencc，跳过繁体核对")
                continue
            official = {_s2t(n) for n in official} | ZH_TW_ALIAS
            blocking = False
        hit_all, problems = set(), []
        for line in roster_lines(full):
            hits, rest = residue(line, official)
            hit_all.update(hits)
            if rest.strip():
                problems.append((line[:60], rest.strip()[:40]))
        status = "✅" if not problems else ("🔴" if blocking else "⚠️ ")
        print(f"{status} {locale}: 命中官方名 {len(hit_all)} 个，问题行 {len(problems)}")
        for line, rest in problems:
            tag = "✗" if blocking else "△ 异译/待判"
            print(f"      {tag} 残余 {rest!r}  ←  {line}")
            if blocking:
                bad += 1

    if bad:
        print(f"\n🔴 合计 {bad} 行含游戏内查不到的人名 —— 上线前必修")
        return 1
    print("\n✅ 各语种文案里的人名，全部能在游戏内语言表查到")
    return 0


if __name__ == "__main__":
    sys.exit(main())
