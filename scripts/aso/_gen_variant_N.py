#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成变体 N：改名《群星列阵》+ 文案事实纠错（4 语）。

事实口径（全部可由配置表核）：
  - 90 个可玩角色（HeroConfig 110 行减去 20 个克隆体）
  - 9 格 5 席、6 套预设阵型（FormationConfig.pos 只到 9；阵型 6 行）
  - 全部 Live2D 动态立绘（HeroConfig.Live 每个角色都有独立 id）
  - 4 种职业（HeroConfig.Profession 取值 1~4）
删掉的说法：7x7 战棋 / 赛博少女 / 主线与 PvP 零付费墙 / 100+。
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data_aso" / "variants" / "N"
VIDEO = "https://youtu.be/CS-5XZsJxbI"

ZH_CN_SHORT = "关羽和凯撒同队？90位跨时代角色等你召唤。九格五席，站错一格就团灭。离线也在变强。"

ZH_CN_FULL = """「关公战秦琼」在这里不是段子。

关羽和凯撒站在同一排，居里夫人给特斯拉补位，开膛手杰克蹲在角落等收割。90 位来自不同时代、不同文明的人被同一场时空错乱卷到一处——全都有 Live2D 动态立绘，各有各的脾气。

九格五席：站错一格就没了
战场只有九个格子，你只能上五个人。前排扛不住，后排就是活靶子；辅助塞错位置，整队输出塌一半。游戏内置六套阵型预设，随等级解锁，一键切换——从双坦顶前排，到全员速攻。
这里不只看战力数字，也看你怎么排。

为什么只有九个格子
因为规则越少，选择越重。你不需要背十几套克制表，三分钟就能上手；但换一个站位，结局可能完全不同。前排少一个肉盾，辅助就得拿命去换输出；把收割位挪到角落，等对面技能交完再进场，一场必输的仗就翻了。
简单到不会劝退，深到值得天天琢磨——这是九格五席想做的事。

90 位角色，四种职业
历史名将、神话英雄、小说里的反派，混编在一支队伍里：
关羽 · 白起 · 韩信 · 嬴政 · 织田信长 · 真田幸村
凯撒 · 拿破仑 · 亚历山大 · 成吉思汗 · 贞德
特斯拉 · 爱因斯坦 · 居里夫人 · 莫扎特 · 肖邦 · 李白
雅典娜 · 亚瑟 · 齐格飞 · 开膛手杰克 · 亚森罗宾 · 唐吉坷德
四种职业分工明确。谁上阵不是你抽到了谁，而是你怎么排这九格。

挂机也在变强
离线收益照常结算。上班、上课、睡觉，队伍都在打。回来收一波资源，升星、换阵、再推一章。

每天十分钟，够用
不逼你定点上线，也不靠签到惩罚留人。早上花两分钟收菜、换阵型，晚上推两章主线，进度照样往前走。想肝的时候有竞技场和排行可打，不想肝的时候挂机也不会掉队。

主线 + 竞技场
主线按章节推进，每章一个新时空；竞技场和真人玩家对排，看谁的九格排得更狠。

现在就下载，看看你能把多少人塞进这九个格子。"""

ZH_TW_SHORT = "關羽和凱撒同隊？90位跨時代角色等你召喚。九格五席，站錯一格就團滅。離線也在變強。"

ZH_TW_FULL = """「關公戰秦瓊」在這裡不是段子。

關羽和凱撒站在同一排，居里夫人幫特斯拉補位，開膛手傑克蹲在角落等收割。90 位來自不同時代、不同文明的人被同一場時空錯亂捲到一處——全都有 Live2D 動態立繪，各有各的脾氣。

九格五席：站錯一格就沒了
戰場只有九個格子，你只能上五個人。前排扛不住，後排就是活靶子；輔助塞錯位置，整隊輸出塌一半。遊戲內建六套陣型預設，隨等級解鎖，一鍵切換——從雙坦頂前排，到全員速攻。
這裡不只看戰力數字，也看你怎麼排。

為什麼只有九個格子
因為規則越少，選擇越重。你不需要背十幾套剋制表，三分鐘就能上手；但換一個站位，結局可能完全不同。前排少一個肉盾，輔助就得拿命去換輸出；把收割位挪到角落，等對面技能交完再進場，一場必輸的仗就翻了。
簡單到不會勸退，深到值得天天琢磨——這是九格五席想做的事。

90 位角色，四種職業
歷史名將、神話英雄、小說裡的反派，混編在一支隊伍裡：
關羽 · 白起 · 韓信 · 嬴政 · 織田信長 · 真田幸村
凱撒 · 拿破崙 · 亞歷山大 · 成吉思汗 · 貞德
特斯拉 · 愛因斯坦 · 居里夫人 · 莫札特 · 蕭邦 · 李白
雅典娜 · 亞瑟 · 齊格飛 · 開膛手傑克 · 亞森羅蘋 · 唐吉訶德
四種職業分工明確。誰上陣不是你抽到了誰，而是你怎麼排這九格。

掛機也在變強
離線收益照常結算。上班、上課、睡覺，隊伍都在打。回來收一波資源，升星、換陣、再推一章。

每天十分鐘，夠用
不逼你定點上線，也不靠簽到懲罰留人。早上花兩分鐘收菜、換陣型，晚上推兩章主線，進度照樣往前走。想肝的時候有競技場和排行可打，不想肝的時候掛機也不會掉隊。

主線 + 競技場
主線按章節推進，每章一個新時空；競技場和真人玩家對排，看誰的九格排得更狠。

現在就下載，看看你能把多少人塞進這九個格子。"""

JA_SHORT = "関羽とカエサルが同じ隊に。90人の歴史的人物を召喚し、9マス5枠の配置で生死が決まる放置カードRPG。"

JA_FULL = """「関羽 vs. カエサル」は、ここでは居酒屋の与太話じゃない。

関羽とカエサルが同じ前列に並び、キュリー夫人がテスラの穴を埋める。ジャック・ザ・リッパーは隅で刈り取りを待っている。時代も文明も違う90人が、同じ時空の裂け目に放り込まれた——全員が Live2D で動き、全員に性格がある。

9マス・5人。置き場所を間違えたら、そこで終わり。
戦場は9マスしかなく、出せるのは5人だけ。前衛が崩れれば後衛は的になる。サポートを1マス遠くに置けば、火力は半分消える。レベルに応じて6種類の陣形が解放され、ワンタップで切り替え——鉄壁のダブルタンクから、全員速攻まで。
数字が大きい方が勝つゲームじゃない。どこに立たせるかが、戦いの半分を決める。

なぜ9マスなのか
ルールが少ないほど、選択は重くなる。覚える相性表は十数種類じゃなくていい。3分で触れて、配置をひとつ変えるだけで結末が変わる。前衛をひとり減らせば、サポートは火力と引き換えに前に出る。回収役を隅に置き、相手のスキルが切れたところで入れれば、負けるはずの戦いがひっくり返る。
始めやすいのに、毎日考えたくなる——それが9マス5人の設計だ。

90人・4職
武将、科学者、作曲家、神話の英雄、小説の悪役——同じ名簿に並ぶ。
関羽・白起・韓信・始皇帝・織田信長・真田幸村
カエサル・ナポレオン・アレクサンダー・チンギス・ハン・ジャンヌ・ダルク
テスラ・アインシュタイン・キュリー夫人・モーツァルト・ショパン・李白
アテナ・アーサー王・ジークフリート・ジャック・ザ・リッパー・アルセーヌ・ルパン・ドン・キホーテ
4つの職能が役割を分ける。誰を引いたかより、どこに置くか。

留守中も勝ち続ける
オフライン報酬はそのまま加算される。仕事中も授業中も、寝ている間も、部隊は戦っている。戻って受け取り、星を上げ、陣形を組み替えて、また1章進める。

1日10分で足りる
決まった時間に縛られない。ログインを強要するペナルティもない。朝に2分だけ受け取って陣形を変え、夜に2章進める——それでも先へ進める。がっつり遊びたい日はアリーナとランキングへ、遊べない日は放置で置いていかれない。

メインストーリー＋アリーナ
メインは章ごとに進み、1章ごとに新しい時代へ。アリーナでは実際のプレイヤーと組み合わせを競う。9マスをうまく使ったのはどっちか。

さあ、9マスに何人詰め込めるか、試してみてください。"""

EN_SHORT = "Guan Yu and Caesar on one team. 90 historical heroes, 9 slots, pick 5."

EN_FULL = """\"Guan Yu vs. Caesar\" isn't a barstool argument here. It's Tuesday.

Guan Yu and Caesar hold the same front line. Marie Curie covers for Tesla. Jack the Ripper waits in the corner for the cleanup. Ninety people from different centuries and different civilizations got pulled into the same tear in time — every one of them Live2D-animated, every one of them with an attitude.

NINE SLOTS. FIVE FIGHTERS. WRONG SQUARE, DEAD UNIT.
The battlefield is exactly nine squares and you can only field five. If your front line folds, your back line is target practice. Drop a support one square too far and half your damage evaporates. Six preset formations unlock as you level — from a double-tank wall to all-out aggression — and you swap them with one tap.
This is not a game where the bigger number wins on its own. Where you stand is half the fight.

WHY ONLY NINE SQUARES
Because fewer rules make every choice heavier. You don't memorize a dozen counter tables — you're playing in three minutes. But move one unit and the ending changes. Pull a tank off the front and your support pays for your damage with its life. Slide your finisher into the corner, let the enemy burn their skills, then walk in — and a lost fight flips.
Easy enough to start, deep enough to think about every day. That's the whole design.

NINETY CHARACTERS, FOUR ROLES
Warlords, scientists, composers, mythological heroes and literary villains, all on one roster:
Guan Yu · Bai Qi · Han Xin · Qin Shi Huang · Oda Nobunaga · Sanada Yukimura
Caesar · Napoleon · Alexander · Genghis Khan · Joan of Arc
Tesla · Einstein · Marie Curie · Mozart · Chopin · Li Bai
Athena · King Arthur · Siegfried · Jack the Ripper · Arsene Lupin · Don Quixote
Four roles, clearly divided. It's not who you pulled — it's how you fill those nine squares.

IT KEEPS WINNING WHILE YOU'RE GONE
Idle income settles offline. Work, class, sleep — the squad keeps fighting. Come back, collect, star up, reshuffle the grid, push one more chapter.

TEN MINUTES A DAY IS ENOUGH
No login timers, no punishment for missing a day. Two minutes in the morning to collect and re-arrange, two chapters at night, and you still move forward. When you want to sweat, the arena and the rankings are there. When you can't log in, idle progression keeps your seat.

STORY + ARENA
The main story runs chapter by chapter, a new era every chapter. The arena puts you against real players to see whose nine squares are arranged better.

Download now and find out how many legends you can cram into nine squares."""

LOCALES = {
    "zh-CN": ("群星列阵：放置卡牌RPG", ZH_CN_SHORT, ZH_CN_FULL),
    "zh-TW": ("群星列陣：放置卡牌RPG", ZH_TW_SHORT, ZH_TW_FULL),
    "ja-JP": ("群星の陣：放置カードRPG", JA_SHORT, JA_FULL),
    "en-US": ("Starhost: Idle Card RPG", EN_SHORT, EN_FULL),
}

META = {
    "label": "改名《群星列阵》+ 文案事实纠错（四语全量）",
    "role": "treatment",
    "parent": "L",
    "baseline": "A",
    "cycle": "push-20261024-rename",
    "generated_by": "手工撰写（非规则替换、非机器翻译）",
    "hypothesis": (
        "现名《时空群英》是通用词堆叠，不可注册、不可独占，且整条「时空+裂隙+赛博霓虹」赛道"
        "已被《时隙之旅/时之裂隙》占满；同时线上简介含三处与工程事实不符的说法"
        "（7x7 战棋 / 赛博少女 / 零付费墙）。本轮把名字换成能同时编码「跨时代角色」与「九格站位」的"
        "《群星列阵》，并把文案改成可核实的口径：90 位角色、9 格 5 席、6 套阵型、全 Live2D。"
        "预期：搜索词不再被误导向战棋品类，商店页访问→安装转化提升；口碑侧减少「说好的战棋呢」。"
    ),
    "variables": [
        "title: 时空群英：放置阵型RPG → 群星列阵：放置卡牌RPG（zh-CN）",
        "title: 時空群英：放置陣型RPG → 群星列陣：放置卡牌RPG（zh-TW）",
        "title: 時空を旅する美少女：放置タクティクスRPG → 群星の陣：放置カードRPG（ja-JP）",
        "title: Neon Valkyries: Anime Idle RPG → Starhost: Idle Card RPG（en-US）",
        "shortDescription / fullDescription: 四语全部重写（去 7x7 战棋、赛博少女、零付费墙、100+）",
    ],
    "keep": [
        "icon / featureGraphic / phoneScreenshots / video 一律不动（图是另一条线，缺 en 图是已知阻塞）",
        "包名、分类、定价、内购配置不动",
    ],
    "caveat": [
        "改名无法做 A/B（标题不能随机分流，改完 24-72h 索引刷新会污染并行窗口）⇒ 它是一次「定位重置」，不是实验",
        "因与文案纠错同批，本轮只能回答「整体是否更好」，不能归因到名字单变量",
        "aso-20261024-title-zh-M 的中文窗口只存活 16 分钟，本批上线后应标 superseded",
    ],
    "readout_window_days": 14,
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    bad = []
    for loc, (title, short, full) in LOCALES.items():
        rec = {
            "title": title,
            "shortDescription": short,
            "fullDescription": full,
            "video": VIDEO,
            "language": loc,
        }
        line = f"{loc}: title={len(title)} short={len(short)} full={len(full)}"
        if len(title) > 30 or len(short) > 80 or len(full) > 4000:
            bad.append(line)
        print(("  ✗ " if len(title) > 30 or len(short) > 80 or len(full) > 4000 else "  ✓ ") + line)
        (OUT / f"{loc}.json").write_text(
            json.dumps(rec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    (OUT / "meta.json").write_text(
        json.dumps(META, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print("\n写入", OUT)
    if bad:
        raise SystemExit("超限：" + "; ".join(bad))


if __name__ == "__main__":
    main()
