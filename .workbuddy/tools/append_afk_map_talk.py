#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
给挂机气泡加「场景抱怨池」：

1. Language.xlsx 追加 40 行（id 63010109~63010148，中/英/日）
2. AfkSpeak.xlsx 追加 40 行（Type = 9900 + 地图编号，Id 从 107 起）

Type 约定（新增，原来只有 0=通用池 / 英雄配置 id=专属）：
    9901 = Map1  霓虹都市夜景
    9902 = Map2  雪地废墟
    9905 = Map5  机械基地
    9907 = Map7  古树森林
    9908 = Map8  室内实验室

为什么在 XML 层追加、不用 openpyxl 存盘：openpyxl 重存会把 56 个「空字符串」格子写成空单元格、
整包重压，diff 变成「整表重写」。这里只追加 <row> 与 sharedStrings 条目。
追加完必须用 Unity 侧官方导表器（DataToOptimizeLuaExporter）重新导出 lua —— 已用「导表器
对未改动表重跑一次、输出与原文件字节相同」验证过这条路是安全的。

用法：
    python .workbuddy/tools/append_afk_map_talk.py --dry-run
    python .workbuddy/tools/append_afk_map_talk.py
    python .workbuddy/tools/append_afk_map_talk.py --revert   # 回滚（用备份）
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

LANG_ID_START = 63010109
AFK_ROW_ID_START = 107

# 地图编号 -> (说明, [8 条 (中文, English, 日本語)])
MAPS = {
    1: ('霓虹都市夜景', [
        ('到处霓虹，还是看不见。', 'Neon everywhere. Still blind.', 'ネオンだらけで見えない。'),
        ('凌晨三点谁看广告牌？', 'Nobody reads signs at 3 a.m.', '深夜に看板を読む奴。'),
        ('每个街角都有警察。真好。', 'Cops on every corner. Great.', '角ごとに警官。最高。'),
        ('灯全亮着，一个人没有。', 'City lights. Nobody home.', '街は光る。人はいない。'),
        ('我的影子比我上镜。', 'My shadow looks better than me.', '影の方がマシだ。'),
        ('雨、霓虹、糟糕的决定。', 'Rain, neon, bad decisions.', '雨、ネオン、悪い判断。'),
        ('这条路从来没干过。', 'This street never dries.', 'この道は乾かない。'),
        ('谁能关掉一块招牌。', 'Somebody turn off one sign.', '看板を一つ消してくれ。'),
    ]),
    2: ('雪地废墟', [
        ('冷。靴子先投降了。', 'Cold. My boots gave up.', '寒い。ブーツが降参。'),
        ('脸没知觉了。挺好。', "Can't feel my face. Fine.", '顔の感覚がない。まあいい。'),
        ('又下雪。谁点的？', 'Snow again. Who ordered it?', 'また雪。誰の注文だ。'),
        ('我讨厌白色。全部。', 'I hate white. All of it.', '白が嫌いだ。全部。'),
        ('画这图的人先冻死了。', 'Whoever mapped this froze.', '地図を描いた奴が凍った。'),
        ('冰不错。不推荐。', 'Nice ice. Would not recommend.', 'いい氷だ。勧めない。'),
        ('我的手指投诉了。', 'My fingers filed a complaint.', '指が苦情を出した。'),
        ('这天气不归我管。', 'This weather is not my job.', '天気は担当外だ。'),
    ]),
    5: ('机械基地', [
        ('这里什么都嗡嗡响。', 'Everything here hums.', 'ここは全部唸ってる。'),
        ('安全员看到会哭。', 'OSHA would cry right now.', '安全担当が泣くぞ。'),
        ('谁在这装楼梯？没道理。', 'Who puts stairs here? Nobody.', 'なぜここに階段を。'),
        ('地上有油。免费滑梯。', 'Oil on the floor. Free slide.', '床に油。無料滑り台。'),
        ('这塔的塔也太多了。', 'This tower has too many towers.', 'この塔、塔が多すぎる。'),
        ('工会会喜欢这地方。', 'The union would love this.', '労組が喜びそうだ。'),
        ('铁轨通向没有。经典。', 'Rail to nowhere. Classic.', '行き止まりの線路。定番。'),
        ('不归我管，也不是我的油。', 'Not my oil, not my problem.', '俺の油じゃない。知らん。'),
    ]),
    7: ('古树森林', [
        ('这树比地图还老。', 'This tree is older than the map.', 'この木は地図より古い。'),
        ('树根。每一步都是树根。', 'Roots. Every step. Roots.', '根ばかり。一歩ごとに根。'),
        ('这里的虫子有工会。', 'Bugs have a union here.', '虫に労組があるらしい。'),
        ('石头地板，一件家具没有。', 'Stone floor, zero furniture.', '石の床。家具はゼロ。'),
        ('谁来修剪这林子？没人。', 'Who mows this? Nobody.', '誰が手入れしてる。誰も。'),
        ('我踩到活的东西了。', 'I stepped on something alive.', '生き物を踏んだ気がする。'),
        ('大自然。我最怕的老板。', 'Nature. My least favorite boss.', '自然。苦手な上司だ。'),
        ('到处是树荫。可疑。', 'Shade everywhere. Suspicious.', '日陰だらけ。怪しい。'),
    ]),
    8: ('室内实验室', [
        ('进屋了。终于。还是瘆人。', 'Indoors. Finally. Still creepy.', '屋内だ。やっと。まだ不気味。'),
        ('谁把空调调到北极？', 'Who set the AC to arctic?', '誰が空調を北極にした。'),
        ('走廊一股漂白水味。', 'This hallway smells like bleach.', '廊下が漂白剤の匂いだ。'),
        ('屏幕都亮着，没人看。', 'Monitors on. Nobody watching.', '画面は点く。誰も見ない。'),
        ('九扇门，一扇都不开。', 'Nine doors. None of them open.', '扉が九つ。どれも開かない。'),
        ('发件白大褂吧。就一次。', 'Lab coats would help. Once.', '白衣をくれ。一度だけ。'),
        ('全在闪。我信不过。', "All blinking. I don't trust it.", '全在点滅。信用しない。'),
        ('紫光。不祥。', 'Purple light. Bad vibes.', '紫の光。嫌な予感。'),
    ]),
}


def xml_escape(s):
    return s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


def plan_rows():
    """返回 [(lang_id, type, (zh,en,jp), map_num, idx)]"""
    out = []
    lid = LANG_ID_START
    for m in sorted(MAPS):
        _, lines = MAPS[m]
        for i, tri in enumerate(lines, 1):
            out.append((lid, 9900 + m, tri, m, i))
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
    for k, (lid, _t, tri, _m, _i) in enumerate(rows):
        rn = last_row + 1 + k
        cells = ['<c r="B%d"><v>%d</v></c>' % (rn, lid)]
        for col, text in zip(('C', 'D', 'E'), tri):
            new_si.append('<si><t xml:space="preserve">%s</t></si>' % xml_escape(text))
            cells.append('<c r="%s%d" t="s"><v>%d</v></c>' % (col, rn, idx))
            idx += 1
        new_rows.append('<row r="%d" spans="2:5">%s</row>' % (rn, ''.join(cells)))

    print('Language: 现有 %d 行 -> 追加 %d 行 (r%d~r%d)' % (last_row, len(new_rows), last_row + 1, last_row + len(new_rows)))
    print('  sharedStrings uniqueCount %d -> %d' % (old_u, old_u + len(new_si)))

    sheet_new = sheet.replace('</sheetData>', ''.join(new_rows) + '</sheetData>')
    sheet_new = re.sub(r'<dimension ref="A1:E\d+"/>', '<dimension ref="A1:E%d"/>' % (last_row + len(new_rows)), sheet_new, count=1)
    sst_new = sst.replace('</sst>', ''.join(new_si) + '</sst>')
    sst_new = sst_new.replace('uniqueCount="%d"' % old_u, 'uniqueCount="%d"' % (old_u + len(new_si)), 1)
    if 'uniqueCount="%d"' % (old_u + len(new_si)) not in sst_new:
        print('!! uniqueCount 未更新')
        return 2

    if dry:
        print('  [DRY-RUN] 未写入')
        return 0
    rewrite_zip(LANG_XLSX, {'xl/worksheets/sheet1.xml': sheet_new, 'xl/sharedStrings.xml': sst_new})
    return 0


def append_afk(rows, dry):
    z = zipfile.ZipFile(AFK_XLSX)
    sheet = z.read('xl/worksheets/sheet1.xml').decode('utf-8')
    z.close()

    last_row = max(int(m) for m in re.findall(r'<row r="(\d+)"', sheet))
    existing = [int(m) for m in re.findall(r'<c r="B\d+"><v>(\d+)</v></c>', sheet)]
    next_id = max(existing) + 1 if existing else 1
    if next_id != AFK_ROW_ID_START:
        print('!! AfkSpeak 下一个 Id 应为 %d，实际 %d' % (AFK_ROW_ID_START, next_id))
        return 2

    new_rows = []
    for k, (lid, typ, _tri, _m, _i) in enumerate(rows):
        rn = last_row + 1 + k
        new_rows.append('<row r="%d" spans="2:4" x14ac:dyDescent="0.2">'
                        '<c r="B%d"><v>%d</v></c><c r="C%d"><v>%d</v></c><c r="D%d"><v>%d</v></c>'
                        '</row>' % (rn, rn, next_id + k, rn, typ, rn, lid))

    print('AfkSpeak: 现有 %d 行 -> 追加 %d 行 (Id %d~%d)' % (last_row, len(new_rows), next_id, next_id + len(new_rows) - 1))
    sheet_new = sheet.replace('</sheetData>', ''.join(new_rows) + '</sheetData>')
    sheet_new = re.sub(r'<dimension ref="A1:D\d+"/>', '<dimension ref="A1:D%d"/>' % (last_row + len(new_rows)), sheet_new, count=1)
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
            bak = os.path.join(BACKUP_DIR, name + '.bak-maptalk')
            if os.path.exists(bak):
                shutil.copy(bak, src)
                print('已还原 %s' % name)
        return 0

    rows = plan_rows()
    if len(rows) != 40:
        print('!! 计划 %d 条，应为 40' % len(rows))
        return 2

    if not args.dry_run:
        os.makedirs(BACKUP_DIR, exist_ok=True)
        for src, name in ((LANG_XLSX, 'Language.xlsx'), (AFK_XLSX, 'AfkSpeak.xlsx')):
            bak = os.path.join(BACKUP_DIR, name + '.bak-maptalk')
            if not os.path.exists(bak):
                shutil.copy(src, bak)
                print('备份 %s -> %s' % (name, bak))

    rc = append_language(rows, args.dry_run)
    if rc:
        return rc
    rc = append_afk(rows, args.dry_run)
    if rc:
        return rc

    print('\n语言 id 63010109~%d，40 条 / 中英日各 40' % (LANG_ID_START + 39))
    if not args.dry_run:
        print('下一步：用 Unity 侧官方导表器重新导出 Language / AfkSpeak 两张表的 lua')
    return 0


if __name__ == '__main__':
    sys.exit(main())
