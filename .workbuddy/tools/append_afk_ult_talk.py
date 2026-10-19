#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给挂机气泡加「大招台词池」：

1. Language.xlsx 追加 N 行（中/英/日）
2. AfkSpeak.xlsx 追加 N 行

Type 约定（在原有 0 / 英雄id / 9900+地图 之外新增）：
    40000 + 英雄id = 该英雄开大招时的专属台词（每场最多 1 人，命中率 70%）
    9998           = 通用大招台词（英雄专属台词缺失 / 30% 混播）

台词口径：
    · 每句都落在「已经摆好架势、还没打出去」的前摇窗口里（CombatControl.KeyFrame 1.8~2.2s）
    · 一句玩技能名 / 技能描述的梗，一句玩角色性格 / 处境的梗
    · 中文 ≤ 16 字、英文 ≤ 34 字符、日文 ≤ 20 字（气泡 280x78、28 号字，最多两行）

为什么在 XML 层追加、不用 openpyxl 存盘：openpyxl 重存会把「空字符串」格子写成空单元格、
整包重压，diff 变成「整表重写」。这里只追加 <row> 与 sharedStrings 条目。

用法：
    python .workbuddy/tools/append_afk_ult_talk.py --dry-run
    python .workbuddy/tools/append_afk_ult_talk.py
    python .workbuddy/tools/append_afk_ult_talk.py --revert
"""
import argparse
import os
import re
import shutil
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
LANG_XLSX = os.path.join(ROOT, 'data_execl/base_data/Language.xlsx')
AFK_XLSX = os.path.join(ROOT, 'data_execl/base_data/AfkSpeak.xlsx')
BACKUP_DIR = os.path.join(ROOT, '.workbuddy/backup')

LANG_ID_START = 63010149
ULT_TYPE_BASE = 40000
ULT_TYPE_GENERIC = 9998

# 英雄 id -> [(中文, English, 日本語), ...]
# 取的是该英雄 OpenSkillRules 里槽位最高的主动技能（大招），见
# .workbuddy/backup/afk_hero_skills.txt
HERO_ULT = {
    10005: [  # 德雷克 / 环球远征（海盗）
        ('环球远征，先绕你一圈。', "World tour. You're stop one.", '世界遠征。最初の寄港地はお前だ。'),
        ('海盗的规矩：先收钱。', 'Pirate rule: payment first.', '海賊の掟。先に金だ。'),
    ],
    10007: [  # 瓦特 / 斧盾双持（肉盾）
        ('斧头谈事，盾牌收尾。', 'Axe talks. Shield closes.', '斧が話し、盾が締める。'),
        ('别急，盾先举好。', 'Hold on. Shield first.', '待て。まず盾を構える。'),
    ],
    10008: [  # 爱因斯坦 / 扭曲时空
        ('时空弯了，你也弯了。', 'Spacetime bends. So do you.', '時空が曲がる。お前もだ。'),
        ('相对论：你输得相对快。', 'Relativity: you lose fast.', '相対性理論。お前は早く負ける。'),
    ],
    10009: [  # 诺贝尔 / TNT爆炸
        ('新配方。连我都怕。', "New formula. Even I'm scared.", '新配合。私も怖い。'),
        ('这次不炸实验室，炸你。', 'Not the lab this time. You.', '今回は実験室じゃない。お前だ。'),
    ],
    10010: [  # 丹妮莉丝 / 龙焰
        ('龙焰。龙小，火不小。', 'Dragonfire. Small dragon, big fire.', '竜炎。竜は小さく、炎は大きい。'),
        ('一米五的龙，够烧你了。', 'A five-foot dragon is enough.', '1.5メートルの竜で十分だ。'),
    ],
    10011: [  # 居里夫人 / 同位素轰炸
        ('别怕，半衰期比你短。', 'Relax. Half-life beats you.', '安心しろ。半減期はお前より短い。'),
        ('放射线不认人，也不认我。', 'Radiation knows no friends.', '放射線に友達はいない。'),
    ],
    10012: [  # 俾斯麦 / 残忍镇压
        ('先敬礼，再镇压。', 'Salute first. Then suppress.', '敬礼してから、鎮圧だ。'),
        ('这不叫打人，叫秩序。', 'Not a beating. Order.', '暴力じゃない。秩序だ。'),
    ],
    10013: [  # 弗兰肯斯坦 / 过载
        ('过载警告？我的出场曲。', "Overload? That's my intro.", '過負荷？俺の入場曲だ。'),
        ('别碰开关，我自己来。', "Don't touch the switch. Mine.", 'スイッチに触るな。俺のだ。'),
    ],
    10014: [  # 亚森罗宾 / 致命魔术
        ('致命魔术。钱包先走。', 'Fatal magic. Wallet goes first.', '致命的な魔術。財布から消える。'),
        ('看左手，别看右手。', 'Watch the left hand. Not the right.', '左手を見ろ。右手は見るな。'),
    ],
    10015: [  # 乔 / 枪火洗礼
        ('拔枪吧，牛仔。洗礼到了。', 'Draw, cowboy. Baptism time.', '抜け、カウボーイ。洗礼だ。'),
        ('西部规矩：快的说话。', 'West rule: the fast one talks.', '西部の掟。速い奴が話す。'),
    ],
    10016: [  # 胡克 / 精密打击
        ('精准报价，精准打击。', 'Exact price. Exact hit.', '正確な値段、正確な一撃。'),
        ('本店不退不换，包括你。', 'No returns. Including you.', '返品不可。お前もな。'),
    ],
    10017: [  # 嘻哈青年 / 爆炸音波
        ('这段 beat 有点炸。字面意思。', 'This beat drops. Literally.', 'このビート、爆ぜる。物理的に。'),
        ('麦克风给我，地板给你。', "Mic's mine. Floor's yours.", 'マイクは俺、床はお前。'),
    ],
    10018: [  # 伐木工 / 砍伐
        ('砍树在行，砍你顺手。', "I chop trees. You'll do.", '木を切る。お前も切れる。'),
        ('这一斧，算加班。', 'This swing counts as overtime.', 'この一撃は残業だ。'),
    ],
    10019: [  # 真田幸村 / 赤斩关原
        ('关原没打完，今天补上。', 'Sekigahara: the rematch.', '関ヶ原の続きだ。'),
        ('运动服换战甲，一样快。', 'Jersey to armor. Same speed.', 'ユニフォームから甲冑。速さは同じ。'),
    ],
    10022: [  # 拉拉 / 一球入魂
        ('一球入魂。你就是篮筐。', "One shot. You're the hoop.", '一球入魂。お前がゴールだ。'),
        ('这球，我练了十年。', 'Ten years of practice. This one.', 'この一球に十年かけた。'),
    ],
    10023: [  # 服部半藏 / 绝影杀
        ('你先眨眼，你就输了。', 'Blink first. Lose first.', '先に瞬きした方が負けだ。'),
        ('忍者不喊招式。……绝影杀。', "Ninjas don't shout. ...Shadow Kill.", '忍は叫ばぬ。…絶影殺。'),
    ],
    10027: [  # 成吉思汗 / 箭雨
        ('箭雨免费，命不免费。', "Arrows free. Your life isn't.", '矢は無料。命は有料。'),
        ('我的鹰说：放箭。', 'My eagle says: loose.', '鷹が言う。放て、と。'),
    ],
    10029: [  # 佐罗 / 殖民者克星
        ('殖民者克星，顺便克你。', "Bane of colonizers. You'll do.", '入植者の天敵。お前もな。'),
        ('面罩不摘，规矩不改。', 'Mask stays. Rules stay.', 'マスクは外さない。掟もな。'),
    ],
    10030: [  # 斯巴达 / 希腊方阵
        ('方阵向前，概不退票。', 'Phalanx forward. No refunds.', 'ファランクス前進。返金なし。'),
        ('盾牌不是用来躲的。', "Shields aren't for hiding.", '盾は隠れる物じゃない。'),
    ],
    10031: [  # 土方岁三 / 嗜血袭杀
        ('武士道第一条：别挡路。', 'Bushido rule one: move.', '武士道第一条、道を空けろ。'),
        ('刀出鞘，话就少了。', 'Blade out. Talk less.', '刀を抜けば、口数は減る。'),
    ],
    10032: [  # 花木兰 / 摇旗助威
        ('旗举起来了，我还没出手。', "Flag's up. I haven't swung.", '旗は上げた。まだ振ってない。'),
        ('别谢我，谢队形。', "Don't thank me. Thank the ranks.", '私に礼はいい。陣形に言え。'),
    ],
    10033: [  # 齐格飞 / 屠龙
        ('屠龙？先拿你热身。', "Dragon slayer? You're warm-up.", '竜殺し？お前は準備運動だ。'),
        ('龙血洗过澡，别问。', 'Bathed in dragon blood. Don\'t ask.', '竜血を浴びた。聞くな。'),
    ],
    10034: [  # 运动员 / 撞击
        ('这不是犯规，是战术。', 'Not a foul. A tactic.', '反則じゃない。戦術だ。'),
        ('裁判没看见，继续。', "Ref didn't see it. Keep going.", '審判は見てない。続行。'),
    ],
    10035: [  # 农夫 / 野蛮生长
        ('种瓜得瓜，种你算了。', 'Sow wheat, reap wheat. You?', '麦は麦。お前は…やめとく。'),
        ('收成不好，拿你补。', "Bad harvest. You'll do.", '不作だ。お前で補う。'),
    ],
    10038: [  # 贝奥武夫 / 不屈的意志
        ('不屈的意志。翻译：没倒。', 'Unyielding will. Still standing.', '不屈の意志。まだ立ってる。'),
        ('拳头先讲，道理后讲。', 'Fists first. Talk later.', '拳が先、理屈は後。'),
    ],
    10039: [  # 荷马 / 奥德赛
        ('奥德赛。十章起步，别催。', 'Odyssey. Ten chapters. No rush.', 'オデュッセイア。十章からだ。'),
        ('这故事结局，你不太想听。', "You won't like this ending.", 'この結末は、聞きたくないだろう。'),
    ],
    10040: [  # 拉斐尔 / 圣礼之争
        ('圣礼之争。我站赢的那边。', 'Holy war. I pick the winner.', '聖礼の争い。勝つ側に付く。'),
        ('打之前，先构图。', 'Composition first. Then violence.', 'まず構図。それから暴力。'),
    ],
    10041: [  # 赫拉克勒斯 / 玩偶乐园
        ('玩偶乐园。十二试炼最凶。', 'Plushie hell. Worst trial yet.', 'ぬいぐるみ楽園。試練で最凶。'),
        ('别笑，熊会咬人。', "Don't laugh. The bear bites.", '笑うな。熊は噛む。'),
    ],
    10043: [  # 亚瑟 / 王者之剑
        ('王者之剑。先讲规矩。', "King's blade. Rules first.", '王者の剣。まず作法だ。'),
        ('湖里捞的剑，照样锋利。', 'Lake sword. Still sharp.', '湖の剣。今も鋭い。'),
    ],
    10044: [  # 薛定谔 / 薛定谔的猫
        ('猫在盒里，你在拳下。', 'Cat in a box. You in range.', '猫は箱、お前は射程内。'),
        ('开打之前，你两种结局。', 'Two outcomes. Neither good.', '二つの結末。どちらも悪い。'),
    ],
    10047: [  # 弗洛伊德 / 狂野治疗
        ('狂野治疗：先打晕再包扎。', 'Wild healing: knockout first.', '野性的治療。まず気絶させる。'),
        ('你的问题，出在骨头。', 'Your problem is in the bones.', 'お前の問題は骨にある。'),
    ],
    10048: [  # 雨果 / 乌鸦风暴
        ('乌鸦说，你今晚不走运。', 'Ravens say: bad night for you.', 'カラスが言う。今夜は厄日だ。'),
        ('我看见了。乌鸦也看见了。', 'I saw it. So did the ravens.', '俺も見た。カラスも見た。'),
    ],
    10049: [  # 肖邦 / 夜曲
        ('夜曲。适合永眠。', 'Nocturne. Good for eternal sleep.', '夜想曲。永眠に最適。'),
        ('这个音，你弹不了。', "You can't play this note.", 'この音は、お前には弾けない。'),
    ],
    10050: [  # 玛利亚 / 圣神感召
        ('圣神感召。剪刀很快。', 'Divine call. Scissors are sharp.', '聖なる召命。ハサミは鋭い。'),
        ('感召已到，剪刀只是配件。', 'Divine call. Scissors optional.', '召命は来た。ハサミはおまけ。'),
    ],
    10051: [  # 唐吉坷德 / 怜悯
        ('「怜悯」。别误会，是招式。', "'Mercy.' It's the move's name.", '「慈悲」。技の名前だ。'),
        ('骑士先礼后兵，我说了算。', 'Knightly courtesy. My version.', '騎士の礼儀。俺の解釈だ。'),
    ],
    10052: [  # 海明威 / 巨鲸之力
        ('巨鲸之力。我赢过海。', 'Whale strength. I beat the sea.', '巨鯨の力。海には勝った。'),
        ('这一拳，写成一章。', 'This punch gets a chapter.', 'この一撃は一章分だ。'),
    ],
    10053: [  # 服务员 / 巨力击
        ('您的菜：巨力击一份。', 'Your order: one mighty blow.', 'ご注文は怪力打撃一丁。'),
        ('小费可以后付。', 'Tip later. Optional.', 'チップは後払いでいい。'),
    ],
    10054: [  # 护士 / 毒针
        ('毒针。我数到三。', 'Poison needle. Count to three.', '毒針。三つ数える。'),
        ('别动，扎偏了更疼。', 'Hold still. Misses hurt more.', '動くな。外すと余計に痛い。'),
    ],
    10062: [  # 赫克托耳 / 圣焰守护
        ('圣焰守护。城在，我在。', 'Holy flame guard. City stands.', '聖炎の守り。城と共に。'),
        ('守城的人，不追人。', "Wall-holders don't chase.", '城を守る者は追わない。'),
    ],
    10066: [  # 瓦尔基里 / 毁灭战争
        ('毁灭战争。名单上有你。', "War of ruin. You're listed.", '破滅の戦争。名簿にお前がいる。'),
        ('胜利女神也收尸。', 'Victory goddess collects too.', '勝利の女神は遺体も集める。'),
    ],
    10067: [  # 帕里斯 / 裁决之箭
        ('裁决之箭。瞄了很久。', 'Judgment arrow. Aimed for ages.', '裁きの矢。長く狙った。'),
        ('这一箭，不谈判。', "This arrow doesn't negotiate.", 'この矢に交渉はない。'),
    ],
    10068: [  # 拿破仑 / 炮绝
        ('炮绝。先轰，再谈。', 'Final cannon. Fire, then talk.', '砲絶。撃ってから話す。'),
        ('我的字典里没有撤退。', 'No retreat in my dictionary.', '俺の辞書に撤退はない。'),
    ],
    10069: [  # 哥白尼 / 躁动全场
        ('躁动全场。包括你。', 'Rock the house. You too.', '会場を揺らす。お前もだ。'),
        ('音量最大，邻居报警。', 'Max volume. Neighbors called.', '最大音量。隣が通報した。'),
    ],
    10070: [  # 毕达哥拉斯 / 黄金分割
        ('黄金分割。你站错位了。', 'Golden ratio. Wrong spot, friend.', '黄金比。お前の位置は不正解。'),
        ('角度算好了，别乱动。', "Angle's calculated. Don't move.", '角度は計算済み。動くな。'),
    ],
    10071: [  # 罗宾汉 / 无声突袭
        ('无声突袭。穷人发财。', 'Silent raid. Poor get paid.', '無音の奇襲。貧者が報われる。'),
        ('富人少一点，你少很多。', 'Rich lose some. You lose more.', '金持ちは少し、お前はもっと。'),
    ],
    10085: [  # 伊丽莎白 / 灾祸降临
        ('灾祸降临。不是比喻。', 'Calamity falls. Not a metaphor.', '災厄降临。比喩ではない。'),
        ('咳嗽一声，你就倒了。', "One cough. You're down.", '咳一つで倒れるぞ。'),
    ],
    10087: [  # 弑君者詹姆 / 御林铁卫
        ('御林铁卫。王先，你后。', 'Kingsguard. King first, then you.', '王の護衛。王の次はお前だ。'),
        ('誓言很重，剑更重。', "Oaths are heavy. Sword's heavier.", '誓いは重い。剣はもっと重い。'),
    ],
    10088: [  # 开膛手杰克 / 魔之双刃
        ('魔之双刃。今晚一刀。', 'Demon blades. One cut tonight.', '魔の双刃。今夜は一太刀。'),
        ('别回头，我在前面。', "Don't look back. I'm ahead.", '振り向くな。俺は前だ。'),
    ],
    10089: [  # 尼禄 / 处决
        ('处决。掌声留到最后。', 'Execution. Save the applause.', '処刑。拍手は最後に。'),
        ('舞台搭好了，你上台。', "Stage is set. You're up.", '舞台は整った。上がれ。'),
    ],
    10090: [  # 霍恩海姆 / 炼金术
        ('你的命，换我的乐子。', 'Your life. My entertainment.', 'お前の命、俺の楽しみ。'),
        ('等价交换，你不等价。', "Equivalent exchange: not you.", '等価交換。お前は等価じゃない。'),
    ],
}

GENERIC_ULT = [
    ('看好了，这招只演一次。', 'Watch closely. One take only.', 'よく見ろ。一発限りだ。'),
    ('别眨眼，眨眼就错过。', "Don't blink. You'll miss it.", '瞬きするな。見逃すぞ。'),
    ('蓄力中，别催。', "Charging. Don't rush me.", '充填中。急かすな。'),
    ('这一招，练了很久。', 'Been practicing this one.', 'この技、ずっと練習した。'),
    ('退后，我要认真了。', "Step back. I'm trying now.", '下がれ。本気出す。'),
    ('大招要来了，站稳。', 'Ult incoming. Plant your feet.', '大技だ。足を踏ん張れ。'),
    ('抱歉，动静会有点大。', 'Sorry. This gets loud.', '悪い。ちょっと騒がしい。'),
    ('现在跑，还来得及。', 'Run now. Last chance.', '今なら逃げられる。'),
]


def xml_escape(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def plan_rows():
    """返回 [(lang_id, type, (zh,en,jp), tag)]"""
    out = []
    lid = LANG_ID_START
    for hero_id in sorted(HERO_ULT):
        for tri in HERO_ULT[hero_id]:
            out.append((lid, ULT_TYPE_BASE + hero_id, tri, 'hero%d' % hero_id))
            lid += 1
    for tri in GENERIC_ULT:
        out.append((lid, ULT_TYPE_GENERIC, tri, 'generic'))
        lid += 1
    return out


def rewrite_zip(src, replace_map):
    tmp = src + '.tmp'
    zin = zipfile.ZipFile(src)
    names = zin.namelist()
    zout = zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED)
    for n in names:
        info = zin.getinfo(n)
        if n in replace_map:
            zout.writestr(info, replace_map[n].encode('utf-8'))
        else:
            zout.writestr(info, zin.read(n))
    zout.close()
    zin.close()
    shutil.move(tmp, src)


def append_language(rows, dry):
    z = zipfile.ZipFile(LANG_XLSX)
    sheet = z.read('xl/worksheets/sheet1.xml').decode('utf-8')
    sst = z.read('xl/sharedStrings.xml').decode('utf-8')
    z.close()

    last_row = max(int(m) for m in re.findall(r'<row r="(\d+)"', sheet))
    si_count = len(re.findall(r'<si>', sst))
    mu = re.search(r'uniqueCount="(\d+)"', sst)
    old_u = int(mu.group(1))
    if si_count != old_u:
        print('!! sharedStrings 解析异常: si=%d uniqueCount=%d' % (si_count, old_u))
        return 2

    new_si, new_rows = [], []
    idx = old_u
    for k, (lid, _t, tri, _tag) in enumerate(rows):
        rn = last_row + 1 + k
        cells = ['<c r="B%d"><v>%d</v></c>' % (rn, lid)]
        for col, text in zip(('C', 'D', 'E'), tri):
            new_si.append('<si><t xml:space="preserve">%s</t></si>' % xml_escape(text))
            cells.append('<c r="%s%d" t="s"><v>%d</v></c>' % (col, rn, idx))
            idx += 1
        new_rows.append('<row r="%d" spans="2:5">%s</row>' % (rn, ''.join(cells)))

    print('Language: 现有 %d 行 -> 追加 %d 行 (r%d~r%d)'
          % (last_row, len(new_rows), last_row + 1, last_row + len(new_rows)))
    print('  sharedStrings uniqueCount %d -> %d' % (old_u, old_u + len(new_si)))

    sheet_new = sheet.replace('</sheetData>', ''.join(new_rows) + '</sheetData>')
    sheet_new = re.sub(r'<dimension ref="A1:E\d+"/>',
                       '<dimension ref="A1:E%d"/>' % (last_row + len(new_rows)), sheet_new, count=1)
    sst_new = sst.replace('</sst>', ''.join(new_si) + '</sst>')
    sst_new = sst_new.replace('uniqueCount="%d"' % old_u,
                              'uniqueCount="%d"' % (old_u + len(new_si)), 1)
    if 'uniqueCount="%d"' % (old_u + len(new_si)) not in sst_new:
        print('!! uniqueCount 未更新')
        return 2

    if dry:
        print('  [DRY-RUN] 未写入')
        return 0
    rewrite_zip(LANG_XLSX, {'xl/worksheets/sheet1.xml': sheet_new,
                            'xl/sharedStrings.xml': sst_new})
    return 0


def append_afk(rows, dry):
    z = zipfile.ZipFile(AFK_XLSX)
    sheet = z.read('xl/worksheets/sheet1.xml').decode('utf-8')
    z.close()

    last_row = max(int(m) for m in re.findall(r'<row r="(\d+)"', sheet))
    existing = [int(m) for m in re.findall(r'<c r="B\d+"><v>(\d+)</v></c>', sheet)]
    next_id = max(existing) + 1 if existing else 1

    new_rows = []
    for k, (lid, typ, _tri, _tag) in enumerate(rows):
        rn = last_row + 1 + k
        new_rows.append('<row r="%d" spans="2:4" x14ac:dyDescent="0.2">'
                        '<c r="B%d"><v>%d</v></c><c r="C%d"><v>%d</v></c><c r="D%d"><v>%d</v></c>'
                        '</row>' % (rn, rn, next_id + k, rn, typ, rn, lid))

    print('AfkSpeak: 现有 %d 行 -> 追加 %d 行 (Id %d~%d)'
          % (last_row, len(new_rows), next_id, next_id + len(new_rows) - 1))
    sheet_new = sheet.replace('</sheetData>', ''.join(new_rows) + '</sheetData>')
    sheet_new = re.sub(r'<dimension ref="A1:D\d+"/>',
                       '<dimension ref="A1:D%d"/>' % (last_row + len(new_rows)), sheet_new, count=1)
    if dry:
        print('  [DRY-RUN] 未写入')
        return 0
    rewrite_zip(AFK_XLSX, {'xl/worksheets/sheet1.xml': sheet_new})
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--revert', action='store_true')
    args = ap.parse_args()

    if args.revert:
        for src, name in ((LANG_XLSX, 'Language.xlsx'), (AFK_XLSX, 'AfkSpeak.xlsx')):
            bak = os.path.join(BACKUP_DIR, name + '.bak-ulttalk')
            if os.path.exists(bak):
                shutil.copy(bak, src)
                print('已还原 %s' % name)
        return 0

    rows = plan_rows()
    print('计划 %d 行：英雄 %d 位 / %d 条，通用 %d 条'
          % (len(rows), len(HERO_ULT), len(rows) - len(GENERIC_ULT), len(GENERIC_ULT)))

    if not args.dry_run:
        os.makedirs(BACKUP_DIR, exist_ok=True)
        for src, name in ((LANG_XLSX, 'Language.xlsx'), (AFK_XLSX, 'AfkSpeak.xlsx')):
            bak = os.path.join(BACKUP_DIR, name + '.bak-ulttalk')
            if not os.path.exists(bak):
                shutil.copy(src, bak)
                print('备份 %s -> %s' % (name, bak))

    rc = append_language(rows, args.dry_run)
    if rc:
        return rc
    rc = append_afk(rows, args.dry_run)
    if rc:
        return rc

    print('\n语言 id %d~%d' % (LANG_ID_START, LANG_ID_START + len(rows) - 1))
    if not args.dry_run:
        print('下一步：用 Unity 侧官方导表器重新导出 Language / AfkSpeak 两张表的 lua')
    return 0


if __name__ == '__main__':
    sys.exit(main())
