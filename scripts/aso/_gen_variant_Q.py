#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成变体 Q：把「有量的词」放回标题 + 补声优覆盖 + 修首屏品类前置（四语）。

为什么有这一版（依据 2026-11-06 实测，见 docs/aso_diag_20261106.md）
------------------------------------------------------------------
1. **改名后访问量腰斩**：10-01~10-23 商店页访问 17.9/天 → 10-27~10-30 7.5/天
   （泊松 z=-4.9），而转化率 5.84%→5.56% 无差异 ⇒ 掉的是曝光不是文案质量。
2. **品类词 0 命中**：`放置`/`放置卡牌`/`二次元放置`/`美少女`/`少女`（zh）、
   `放置`/`美少女`/`放置ゲーム`（ja）、`idle card rpg`/`afk idle`/`anime idle rpg`（en）
   在各自语言面全部进不了前 30；只有**品牌词**能命中（群星列阵第 1、群星の陣第 1）。
3. ⇒ P 那轮补的 AFK / 挂机 一个品类曝光都没换来。**无安装信号的包，标题里没有需求词的
   支撑就排不上去**；反过来，把旧名里真正带量的 token（美少女）放回标题，是唯一还能
   靠文案拿到的召回。
4. zh-CN/zh-TW 长描述缺 `声优 / 聲優`（P 是 13/14）⇒ 本轮补满 14/14。

改了什么
--------
- zh-CN 标题：`群星列阵：放置挂机卡牌RPG`(14) → `群星列阵：放置挂机美少女卡牌RPG`(17)
- zh-TW 标题：`群星列陣：放置掛機卡牌RPG`(14) → `群星列陣：放置掛機美少女卡牌RPG`(17)
- ja-JP 标题：**不动**（品牌词第 1、唯一已验证有效的正面结果；美少女改由短描述承载）
- en-US 标题：**不动**（27/30 已顶格，且 en 面品牌词本来就没有信号，再洗一次只是重置索引）
- 四语短描述：品类词前置（二次元/アニメ/idle），保留 84 位 / 九格五席 的可核对数字
- zh 长描述：`中文配音同步` → `中文配音由声优录制`（补 声优 覆盖，且不丢 `中文配音` 这个词，14/14）

事实口径（全部可核，与 P 一致，未新增任何断言）
----------------------------------------------
  - 84 位可收集角色 / 73 位有专属语音（HeroConfig：112 行、ShowHeroLocation=1 共 84、HeroSound 非空 73）
  - 9 格 5 席、6 套预设阵型；84/84 全 Live2D；4 种职业
  - 人名名单段完全沿用 P，未增删（check_hero_names 闸门口径不变）

用法
----
    python3 scripts/aso/_gen_variant_Q.py            # 生成 data_aso/variants/Q/
    python3 scripts/aso/_gen_variant_Q.py --dry-run  # 只打印 diff
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "data_aso" / "variants" / "P"
OUT = ROOT / "data_aso" / "variants" / "Q"

TITLES = {
    "en-US": "Starhost: AFK Idle Card RPG",
    "ja-JP": "群星の陣：放置カードRPG",
    "zh-CN": "群星列阵：放置挂机美少女卡牌RPG",
    "zh-TW": "群星列陣：放置掛機美少女卡牌RPG",
}

# 若用户认为「美少女」与名册（关羽/凯撒等男角）不符，改用下面这组：
TITLES_ALT = {
    "zh-CN": "群星列阵：二次元放置挂机卡牌RPG",
    "zh-TW": "群星列陣：二次元放置掛機卡牌RPG",
}

SHORTS = {
    "en-US": "Anime idle card RPG: 84 legends, 9 squares, 5 fighters. Misplace one, run ends.",
    "ja-JP": "歴史・神話・小説の美少女と英雄84人が同じ名簿に。9マス5枠、配置で生死が決まる放置カードRPG。",
    "zh-CN": "二次元放置卡牌RPG。84 位跨时代角色，九格五席，站错一格就团灭。",
    "zh-TW": "二次元放置卡牌RPG。84 位跨時代角色，九格五席，站錯一格就團滅。",
}

# (旧, 新)；每条必须**恰好命中一次**，0 次或多次都算脚本失效
REPL = {
    "zh-CN": [("中文配音同步", "中文配音由声优录制")],
    "zh-TW": [("中文配音同步", "中文配音由聲優錄製")],
    "en-US": [],
    "ja-JP": [],
}

LIMITS = {"title": 30, "shortDescription": 80, "fullDescription": 4000}


def patch(locale: str, text: str) -> str:
    for old, new in REPL[locale]:
        n = text.count(old)
        if n != 1:
            raise SystemExit(f"[{locale}] 替换命中 {n} 次（要求恰好 1 次）：{old!r}")
        text = text.replace(old, new)
    return text


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--alt-title", action="store_true",
                    help="[已否决 2026-11-06] 中文标题用「二次元」替代「美少女」"
                         "：实测 二次元 搭不上强 token 少女、且意图混入漫画类，不再使用")
    args = ap.parse_args()

    titles = dict(TITLES)
    if args.alt_title:
        titles.update(TITLES_ALT)

    for f in sorted(SRC.glob("*.json")):
        if f.name == "meta.json":
            continue
        loc = f.stem
        d = json.loads(f.read_text(encoding="utf-8"))
        new = dict(d)
        new["title"] = titles[loc]
        new["shortDescription"] = SHORTS[loc]
        new["fullDescription"] = patch(loc, d["fullDescription"])

        for k, lim in LIMITS.items():
            if len(new[k]) > lim:
                raise SystemExit(f"[{loc}] {k} 超限：{len(new[k])} > {lim}")

        print(f"\n=== {loc}")
        for k in ("title", "shortDescription"):
            if d.get(k) != new[k]:
                print(f"  {k}: {d.get(k)!r}\n      → {new[k]!r}  ({len(new[k])} 字符)")
            else:
                print(f"  {k}: 不变  ({new[k]!r})")
        if d["fullDescription"] != new["fullDescription"]:
            print(f"  fullDescription: {len(new['fullDescription'])} 字符（有改动）")

        if not args.dry_run:
            OUT.mkdir(parents=True, exist_ok=True)
            (OUT / f.name).write_text(
                json.dumps(new, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if not args.dry_run:
        meta = {
            "variant": "Q",
            "baseline": "P",
            "created": "2026-11-06",
            "element": "copy",
            "hypothesis": (
                "改名后只有品牌词能命中（品类词全 0），且访问量在改名公开当天腰斩、转化率不变 ⇒ "
                "把旧名里带量的 token（美少女）放回中文标题、品类词前置到短描述，"
                "应把中文面的非品牌曝光拉回来；en/ja 标题不动以隔离变量。"),
            "changes": ["zh-CN/zh-TW title +美少女", "四语 shortDescription 品类前置",
                        "zh 长描述补 声优 覆盖（13/14→14/14）"],
            "risk": ("「美少女」与名册含男角（关羽/凯撒等）存在轻微不符，但该词在此品类是风格标签"
                     "（对照 `末日戰姬-日系美少女策略卡牌`）。2026-11-06 实测已否决 --alt-title 的「二次元」版："
                     "二次元 前10含词仅 2/10 且第 1 条为漫画 App，无法搭上强 token 少女(8/10)"),
        }
        (OUT / "meta.json").write_text(
            json.dumps(meta, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"\n已写入 {OUT}")


if __name__ == "__main__":
    main()
