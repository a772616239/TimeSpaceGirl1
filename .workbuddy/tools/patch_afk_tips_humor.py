#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AfkSpeak Type=0 通用池（63010089~63010108）文案改写：把当前值换成新值。

场景：挂机地图上队伍左右跑图找怪（FightPointMapOnHook.startFindEnemy -> HeroTalk），
气泡只显示 2.5 秒；文本盒 280x78 / 字号 28 / Wrap。所以：短句、口语、能一眼读完。

流程：
  1. 从 Language.xlsx 读当前 (中/英/日) 作为 old
  2. 在 Language.lua 里把 old 的字面量替换成 new（每个必须恰好出现 1 次）
  3. 调 patch_language_xlsx_xml.py 在 XML 层改 xlsx（只动 60 个格子，不重写整包）

用法：
  python .workbuddy/tools/patch_afk_tips_humor.py --dry-run
  python .workbuddy/tools/patch_afk_tips_humor.py
  python .workbuddy/tools/patch_afk_tips_humor.py --revert   # 从首次备份还原
"""
import argparse
import io
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
XLSX = os.path.join(ROOT, 'data_execl/base_data/Language.xlsx')
LUA = os.path.join(ROOT, 'Assets/ManagedResources/~Lua/Config/Data/Language.lua')
BAK_DIR = os.path.join(ROOT, '.workbuddy/backup')
PLAN = os.path.join(BAK_DIR, 'afk_tips_plan.json')

# 实测（Unity TextGenerator，文本盒 280x78 / 字号 28 / Wrap）：
#   两行 = 74px，三行 = 111px 溢出 => 英文 <=34 字符、中日 <=18 全角
# 语气：队伍在路上随口说话。约一半是发牢骚（走路/没怪/没掉落/腿酸），
#       另一半把系统当笑话讲（升级、升星、阵营、黑市……），别再写成规则说明书。
NEW = {
    63010089: ('还是饿。还是没怪。',
               'Still hungry. Still no monsters.',
               'まだ腹ペコ。敵はまだ。'),
    63010090: ('冲！……又是雾。',
               'Charge! ...Into more fog.',
               '突撃！…また霧か。'),
    63010091: ('宝气味？那是靴子味。',
               "Treasure smell? That's my boots.",
               '宝の匂い？それ、ブーツだ。'),
    63010092: ('升了级，没那么废了。',
               'Level up. Less useless now.',
               'レベル上げ。少しマシに。'),
    63010093: ('升星，技能更凶了。',
               'Star up. Skills hit meaner.',
               '星上げ。スキルが凶暴に。'),
    63010094: ('我们到底打不打？',
               'Do we fight, or just run?',
               '戦うのか、走るだけか。'),
    63010095: ('胃又罢工了。',
               "Stomach's on strike. Again.",
               '胃がまたストライキ。'),
    63010096: ('守护能加属性。据说。',
               'Guardians buff you. Allegedly.',
               '守護で属性アップ。噂だが。'),
    63010097: ('先挑阵营，再招人。',
               'Pick a camp, then recruit.',
               '陣営を選んで募集。'),
    63010098: ('我的腿已经不想走了。',
               'My feet are done with this.',
               'もう足が限界だ。'),
    63010099: ('到处是雾。遗迹？呵呵。',
               'Fog everywhere. Relic? Sure.',
               '霧だらけ。遺跡？ああ、はい。'),
    63010100: ('芯片加属性。凑满套。',
               'Chips boost stats. Full set.',
               'チップで強化。セットで。'),
    63010101: ('黑市。不开发票。',
               'Black market. No receipts.',
               '闇市。領収書なし。'),
    63010102: ('神之塔：经验和金币。',
               'Tower of God: EXP and gold.',
               '神の塔：経験値と金貨。'),
    63010103: ('阵营契约。看清小字。',
               'Camp deal. Read small print.',
               '陣営契約。小さい字を読め。'),
    63010104: ('全队都靠先驱扛着。',
               'Pioneers carry this squad.',
               '部隊は先駆者頼み。'),
    63010105: ('人事处清理混子。',
               'HR fires the dead weight.',
               '人事部が足手まといを切る。'),
    63010106: ('有掉落才算打了怪。',
               "Loot, or it didn't happen.",
               'ドロップなしは戦闘じゃない。'),
    63010107: ('这地图是谁画的？',
               'Who even drew this map?',
               'この地図、誰が描いた？'),
    63010108: ('星级重置。别问原因。',
               "Stars reset. Don't ask why.",
               '星リセット。理由は聞くな。'),
}


def lua_escape(s):
    return (s or '').replace('\\', '\\\\').replace("'", "\\'")


def read_current():
    import openpyxl
    wb = openpyxl.load_workbook(XLSX, data_only=True)
    ws = wb['Language']
    cur = {}
    for r in ws.iter_rows(min_row=5, values_only=True):
        if isinstance(r[1], int) and r[1] in NEW:
            cur[r[1]] = (r[2] or '', r[3] or '', r[4] or '')
    return cur


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--revert', action='store_true')
    ap.add_argument('--skip-xlsx', action='store_true')
    args = ap.parse_args()

    os.makedirs(BAK_DIR, exist_ok=True)
    for src, name in ((XLSX, 'Language.xlsx.bak-afk-humor'), (LUA, 'Language.lua.bak-afk-humor')):
        dst = os.path.join(BAK_DIR, name)
        if not os.path.exists(dst):
            shutil.copy2(src, dst)
            print('备份 -> %s' % dst)

    if args.revert:
        shutil.copy2(os.path.join(BAK_DIR, 'Language.xlsx.bak-afk-humor'), XLSX)
        shutil.copy2(os.path.join(BAK_DIR, 'Language.lua.bak-afk-humor'), LUA)
        print('已还原（记得重编 LuaBytes）')
        return 0

    cur = read_current()
    if len(cur) != len(NEW):
        print('!! 只读到 %d 个目标 id' % len(cur))
        return 2

    lua_text = io.open(LUA, encoding='utf-8').read()
    problems = []
    for pid in sorted(NEW):
        for old_s, new_s in zip(cur[pid], NEW[pid]):
            if not old_s:
                problems.append('id %d 当前值为空' % pid)
                continue
            limit = 34 if new_s.isascii() else 18
            if len(new_s) > limit:
                problems.append('id %d 超长 %d>%d: %s' % (pid, len(new_s), limit, new_s))
            lit = "'%s'" % lua_escape(old_s)
            n = lua_text.count(lit)
            if n != 1:
                problems.append('lua 中当前值出现 %d 次（期望 1），跳过：%s' % (n, old_s[:20]))
                continue
            lua_text = lua_text.replace(lit, "'%s'" % lua_escape(new_s))

    for p in problems:
        print(' !', p)
    if problems and not args.dry_run:
        print('有问题，中止')
        return 2

    plan = [{'id': pid, 'new': list(NEW[pid])} for pid in sorted(NEW)]
    json.dump(plan, open(PLAN, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

    if args.dry_run:
        print('DRY-RUN：%d 条，lua 已模拟替换，未写盘' % len(NEW))
        return 0

    io.open(LUA, 'w', encoding='utf-8', newline='').write(lua_text)
    print('已写入 %s' % LUA)

    if not args.skip_xlsx:
        r = subprocess.run([sys.executable, os.path.join(ROOT, '.workbuddy/tools/patch_language_xlsx_xml.py'),
                            '--from-json', PLAN], capture_output=True, text=True)
        print(r.stdout.strip())
        if r.returncode != 0:
            print(r.stderr.strip())
            return r.returncode

    print('下一步：scripts/lua-bytes-sync.sh Assets/ManagedResources/~Lua/Config/Data/Language.lua')
    return 0


if __name__ == '__main__':
    sys.exit(main())
