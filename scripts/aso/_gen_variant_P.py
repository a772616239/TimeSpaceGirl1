#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成变体 P：数字口径纠错 + 标题补品类长尾词（四语）。

为什么有这一版
--------------
N/O 四语正文都写「90 位角色 / 90 legends / 英雄90人」，但这个数字**没有任何配置表依据**：
  - `HeroConfig.xlsx` 共 **112** 行有效角色（`Id` 为数字的行）
  - 其中 `ShowHeroLocation=1`（图鉴里能看到、玩家数得到的）只有 **84**
  - `HeroSound` 有值的 **74** 行，落到这 84 位里是 **73**
N 的生成脚本注释写「110 行减 20 个克隆体 = 90」，实测表里没有同名克隆行（112 个名字全不重复），
这个 90 是推出来的，不是数出来的。⇒ 统一改成 **84 位可收集 / 73 位有专属语音**，
并顺手把「全阵容由声优演绎 / フルボイス / fully voiced」这类**全量断言**降级为具体数字。

SEO 侧改动（只动 title，四语里三语）
------------------------------------
2026-11-02 实测搜索可见性：ja 品牌词第 1、品类词第 3；zh-CN 简体品牌词第 1；
zh-TW 繁体原名搜不到；en 品牌词前 30 全无。⇒ 已验证有效的 ja 标题**不动**，
其余三语在标题里补一个当地真实搜索词：
  - en-US  + AFK（英文区放置类的核心检索词）
  - zh-CN  + 挂机
  - zh-TW  + 掛機

事实口径（全部可核）
--------------------
  - 84 位可收集角色 / 73 位有专属语音（HeroConfig：112 行、ShowHeroLocation=1 共 84、HeroSound 非空 73）
  - 9 格 5 席、6 套预设阵型（FormationConfig.pos 取值 1~9；阵型 6 行）
  - 84/84 全 Live2D（HeroConfig.Live 全部有独立 id）
  - 4 种职业、5 个阵营
  - 主线 2551 关（MainLevelConfig 有效行）
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "data_aso" / "variants" / "O"
OUT = ROOT / "data_aso" / "variants" / "P"

TITLES = {
    "en-US": "Starhost: AFK Idle Card RPG",
    "ja-JP": "群星の陣：放置カードRPG",
    "zh-CN": "群星列阵：放置挂机卡牌RPG",
    "zh-TW": "群星列陣：放置掛機卡牌RPG",
}

SHORTS = {
    "en-US": "Idle card RPG: 84 legends, 9 squares, 5 fighters. Misplace one, run ends.",
    "ja-JP": "歴史・神話・小説の英雄84人が同じ名簿に。9マス5枠、配置で生死が決まる放置カードRPG。",
    "zh-CN": "84 位跨时代角色，历史神话小说混编。九格五席，站错一格就团灭。",
    "zh-TW": "84 位跨時代角色，歷史神話小說混編。九格五席，站錯一格就團滅。",
}

# (旧, 新)；每条必须恰好命中一次，命中 0 次或多次都算脚本失效，直接抛错
REPL = {
    "en-US": [
        ("ninety characters from every century",
         "84 characters from every century"),
        ("every one of them Live2D-animated and fully voiced.",
         "all 84 of them Live2D-animated, 73 with voiced lines."),
        ("NINETY CHARACTERS, FOUR ROLES",
         "EIGHTY-FOUR CHARACTERS, FOUR ROLES"),
        ("Ninety names to fill a roster",
         "Eighty-four names to fill a roster"),
        ("every character breathes, blinks and speaks, all Live2D, all voiced.",
         "every character breathes, blinks and speaks — all Live2D, 73 of them with voiced lines."),
    ],
    "ja-JP": [
        ("歴史・神話・小説の英雄90人が同じ名簿に並ぶ、放置カードRPG。"
         "ガチャで集めて育成し、全キャラが Live2D で動き、フルボイス。",
         "歴史・神話・小説の英雄84人が同じ名簿に並ぶ、放置カードRPG。"
         "ガチャで集めて育成し、84人全員が Live2D で動き、73人に専用ボイス。"),
        ("90人・4職", "84人・4職"),
        ("全キャラクターに声優のボイスが入り、Live2D で動く——看板娘だけが動くゲームではない。",
         "84人のうち73人に声優のボイスが入り、全員が Live2D で動く——看板娘だけが動くゲームではない。"),
    ],
    "zh-CN": [
        ("一款九格五席的放置卡牌RPG：90 位跨时代角色，抽卡收集、挂机养成，"
         "全角色 Live2D 动态立绘，配中文配音。",
         "一款九格五席的放置卡牌RPG：84 位跨时代角色，抽卡收集、挂机养成，"
         "全角色 Live2D 动态立绘，其中 73 位配了专属语音。"),
        ("90 位角色，四种职业", "84 位角色，四种职业"),
        ("全阵容由声优演绎，中文配音同步——不是只有看板娘会动。",
         "84 位里 73 位有专属语音，中文配音同步——不是只有看板娘会动。"),
    ],
    "zh-TW": [
        ("一款九格五席的放置卡牌RPG：90 位跨時代角色，抽卡收集、掛機養成，"
         "全角色 Live2D 動態立繪，配中文配音。",
         "一款九格五席的放置卡牌RPG：84 位跨時代角色，抽卡收集、掛機養成，"
         "全角色 Live2D 動態立繪，其中 73 位配了專屬語音。"),
        ("90 位角色，四種職業", "84 位角色，四種職業"),
        ("全陣容由聲優演繹，中文配音同步——不是只有看板娘會動。",
         "84 位裡 73 位有專屬語音，中文配音同步——不是只有看板娘會動。"),
    ],
}

META = {
    "label": "数字口径纠错（90→84）+ 标题补品类词（en/zh 三语，ja 不动）",
    "role": "treatment",
    "parent": "O",
    "baseline": "A",
    "cycle": "20261102-fix84-P",
    "generated_by": "手工撰写 + 定点替换（scripts/aso/_gen_variant_P.py，每条替换命中次数强校验）",
    "hypothesis": (
        "① 事实层：N/O 的「90 位角色」无配置表依据（HeroConfig 112 行、图鉴可见 84、有配音 73），"
        "属于 Play 虚假宣传风险，必须改成 84/73；"
        "「全阵容由声优演绎」这类全量断言同步降级为具体数字。"
        "② SEO 层：2026-11-02 实测 ja 品牌词第 1、品类词第 3（不动），zh-CN 简体品牌词第 1，"
        "zh-TW 繁体原名搜不到，en 品牌词前 30 全无 ⇒ en/zh-CN/zh-TW 三语标题各补一个当地检索词"
        "（AFK / 挂机 / 掛機），把标题从「只有品牌」变成「品牌 + 品类」。"
    ),
    "variables": [
        "title: en-US / zh-CN / zh-TW 补品类词（ja-JP 不动）",
        "shortDescription: 四语重写（数字纠错 + 品类词前置）",
        "fullDescription: 四语定点纠错（90→84、全语音→73 位）",
    ],
    "keep": [
        "ja-JP 标题不动（品牌词第 1、品类词第 3，已验证有效，不重新洗索引）",
        "video / icon / featureGraphic / phoneScreenshots 不动",
        "包名、分类、定价、内购配置不动",
    ],
    "caveat": [
        "同一批次动了 title + short + full 三个元素，归因不纯；"
        "且该包日均商店页访问仅 16，任何转化率差异都读不出来 —— 本版目的是「纠正错误 + 覆盖词」，不是做 A/B",
        "zh-TW 繁体品牌词搜不到的原因未定（索引延迟 vs 繁简归一化），补 掛機 只能缓解，不能证明修复",
    ],
    "readout_window_days": 14,
    "supersedes_note": "O 的全文结构与关键词植入全部保留，只做数字与配音表述的定点修正；标题另加品类词",
}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    for loc in TITLES:
        src = json.loads((SRC / f"{loc}.json").read_text(encoding="utf-8"))
        full = src["fullDescription"]
        for old, new in REPL[loc]:
            n = full.count(old)
            if n != 1:
                raise SystemExit(f"[FAIL] {loc} 替换命中 {n} 次（应为 1）：{old[:40]}…")
            full = full.replace(old, new)
        # 兜底：改完不许再出现 90 / ninety / フルボイス / 全阵容
        for bad in ("90", "ninety", "Ninety", "NINETY", "フルボイス", "全阵容由声优", "全陣容由聲優"):
            if bad in full or bad in SHORTS[loc]:
                raise SystemExit(f"[FAIL] {loc} 仍残留「{bad}」")
        out = {
            "title": TITLES[loc],
            "shortDescription": SHORTS[loc],
            "fullDescription": full,
            "video": src.get("video", ""),
            "language": loc,
        }
        (OUT / f"{loc}.json").write_text(
            json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"[ok] {loc}  title={len(out['title'])}码位  short={len(out['shortDescription'])}码位  "
              f"full={len(full)}字符")

    (OUT / "meta.json").write_text(
        json.dumps(META, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"[ok] meta.json -> {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
