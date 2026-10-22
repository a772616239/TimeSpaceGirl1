#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""导表服务端同步（table_sync）：把本次导表改动的服务端 txt 同步到各套服务端。

## 为什么需要它

客户端 lua（`Assets/ManagedResources/~Lua/Config/Data/*.lua`）与服务端 txt
（`conf/server/*.txt`）由**同一次导表**从 `data_execl/base_data/*.xlsx` 产生，
但 `DataConfigSetting.serverOutputDir` 只写本地影子目录：

    TimeSpaceServer/skzc/home/java/gameserver/conf/server      ← 导表写这里（git 里）
    ~/home/java/gameserver/conf/server                         ← 本机测试服真正读这里
    gs:/home/java/gameserver/conf/server                       ← 线上服真正读这里

这条链从来没被打通 ⇒ 客户端显示一套数值、服务端校验另一套（「显示 0 还能领」、
历史 `NoSuchMethodError` 都是这个结构问题的症状）。

## 两个同步目标（都要，只改一边等于没改）

| 目标 | 位置 | 谁在用 |
|---|---|---|
| `local` 本机测试服 | `~/home/java/gameserver/{conf,assets/conf}/server` | Unity 编辑器 / 测试包（192.168.3.x:8081 + 游戏服 16081） |
| `gs` 线上服 | `gs:/home/java/gameserver/{conf,assets/conf}/server` | 现网 129.226.213.65 |

## 为什么不能整目录 rsync（2026-10-22 审计结论，必须尊重）

    · Language.txt            线上/测试服都是 5 列（含 Korean），仓库只有 4 列 → 覆盖后韩语全空
    · EncourageTaskConfig     线上独有 16001~16025 → 覆盖等于删掉线上 25 条任务
    · 30+ 张表是未发布内容（随机奖励 / 觉醒属性 / 新道具段）→ 覆盖等于给线上玩家开新数值

所以本工具只做「增量 + 体检」，绝不整目录覆盖：

  1. **只推本次导表真正改过的表** —— 用「语义指纹」和上次同步基线比对
     （指纹 = 表头 + 按主键排序的行 + 单元格归一化后的 md5，
     所以尾随 TAB、`nil`↔`null`、`0.0`↔`0`、行序变化都不算改动）。
     没有基线时用 `git status` 的工作区差异当基线；**第一次跑只建基线，不推任何表**。
  2. **每张候选表、每个目标先做结构体检** —— 列丢失 / 行丢失 / 表头错位 / nil 空值 /
     人工复核名单，命中任意一条该目标就跳过（拦下的表连 `--force` 都要显式点名才推）。
  3. **推前整目录备份、推后双向 md5 校验** —— 各目标 `tar.gz` 落本地 backups/。
  4. **默认只体检**，`--apply` 才写；线上服重启会踢线，非交互环境还要 `--yes`。

## 用法

    python3 scripts/table_sync.py                          # 体检（默认，不改任何服务端）
    python3 scripts/table_sync.py --apply                  # 推「本次改动」且通过体检的表（两个目标）
    python3 scripts/table_sync.py --apply --targets gs     # 只推线上服
    python3 scripts/table_sync.py --apply --targets local  # 只推本机测试服
    python3 scripts/table_sync.py --apply --only A,B       # 只推指定表（仍过体检）
    python3 scripts/table_sync.py --apply --only A --force # 点名强推（体检红灯也推）
    python3 scripts/table_sync.py --apply --include-drift  # 连历史漂移一起推（危险，需 --yes）
    python3 scripts/table_sync.py --apply --restart        # 推完重启（线上会踢线，需 --yes）
    python3 scripts/table_sync.py --status                 # 只打印基线与候选

退出码：0 正常 / 2 参数或环境错误 / 3 同步失败（传输或校验不过）
       4 存在被拦下的表（仅 --strict 时）/ 5 需要 --yes 但未提供

依赖：`gs` 目标依赖本机 ssh 别名（~/.ssh/config + tencent-gameserver.pem），
      与 scripts/server_health_check.py 共用同一个别名。
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
SSH_HOST = os.environ.get('TSG_TABLE_SSH_HOST', 'gs')
SSH_TIMEOUT = 300

BASE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BASE_DIR.parent

# 导表产物（影子目录，git 跟踪）
DEFAULT_LOCAL_DIR = PROJECT_ROOT / 'TimeSpaceServer/skzc/home/java/gameserver/conf/server'

# 各服务端根目录 + 要写的子目录（运行时读的那份 + 资源目录里那份，两份独立文件都要写）
DEFAULT_DIRS = ['conf/server', 'assets/conf/server']
LOCAL_BASE = Path.home() / 'home/java/gameserver'          # 本机测试服
GS_BASE = '/home/java/gameserver'                          # 线上服
LOCAL_RESTART_LABEL = 'com.ts.localserver.gameserver'
GS_RESTART_SCRIPT = '/home/java/gameserver/RESTART-GAMESERVER.sh'

# 本地真实服务端仓（打 jar 用），默认同步过去，避免仓库继续落后
DEFAULT_MIRROR_DIR = PROJECT_ROOT / 'TimeSpaceServer/Server_x1tag1.2.2/server_game/conf/server'

# 打包环境地址表（Jenkins SERVER_ENV 下拉框的 key 就是这里的 envs key）：
#   环境 → 该环境的服务端表同步目标。正式服（103.151.173.99）实测已死，tableTargets 为空。
ENVS_FILE = BASE_DIR / 'build_envs.json'

WORK_DIR = PROJECT_ROOT / 'build/table_sync'
STATE_FILE = WORK_DIR / 'state.json'
BACKUP_DIR = WORK_DIR / 'backups'
REPORT_DIR = WORK_DIR / 'reports'
CACHE_DIR = WORK_DIR / 'cache'

# 人工复核名单：结构体检可能全绿，但语义上必须产品确认才能动服务端
REVIEW_ONLY = {
    'Language.txt': '多语言表：线上/测试服都是 5 列（含 Korean），导出只有 4 列，需先在导出器补列',
    'MultiLanguage.txt': '线上有仓库没有的 id（10301），需确认',
    'EncourageTaskConfig.txt': '线上独有 25 条任务（16001~16025），覆盖即删除',
    'EncouragePlanConfig.txt': '线上独有 id=16',
    'RewardItemConfig.txt': '仓库多 103 个 990000+ 段道具，属未发布内容',
}

OK_VERDICTS = {'VALUE_DIFF', 'ROW_ADD', 'COL_GAIN', 'NEW'}
BLOCK_VERDICTS = {'COL_LOSS', 'ROW_LOSS', 'HEADER_DIFF', 'REMOTE_ONLY', 'REVIEW', 'PARSE_FAIL',
                  'NIL_CELLS', 'PARSE_BAD'}

VERDICT_TEXT = {
    'SAME': '一致',
    'VALUE_DIFF': '值差异（同主键）',
    'ROW_ADD': '新增行',
    'COL_GAIN': '本地多列',
    'NEW': '本地新表',
    'COL_LOSS': '🔴 本地列数少于目标（覆盖会丢列）',
    'ROW_LOSS': '🔴 目标有仓库没有的主键（覆盖会删数据）',
    'HEADER_DIFF': '🔴 表头字段名/顺序不一致（覆盖会串列）',
    'REMOTE_ONLY': '🔴 目标有、本地没有（本工具永不删目标文件）',
    'REVIEW': '🔴 人工复核名单（语义需产品确认）',
    'PARSE_FAIL': '🔴 解析失败（列数不齐）',
    'NIL_CELLS': '🔴 数值列空值写成 nil（服务端解析会抛异常）',
    'PARSE_BAD': '🔴 数值列有服务端解析不了的值（小数/超 int32/非数字）',
}

# 服务端 StringUtil.parseFiledInt 会 Integer.parseInt 的类型：这些列里出现 "nil" 必炸
NUMERIC_TYPES = {'int', 'long', 'short', 'byte', 'float', 'double', 'uint', 'ulong'}

# 空值字面量：客户端空串 / 服务端 null（2026-10-21 把 "nil" 改成 "null" 那次的教训）
NULL_TOKENS = {'', 'null', 'nil', 'NULL', 'NIL', 'None', '-'}


# ---------------------------------------------------------------------------
# 基础工具
# ---------------------------------------------------------------------------
def log(msg=''):
    print(msg, flush=True)


def run(cmd, timeout=SSH_TIMEOUT):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def md5_bytes(data: bytes) -> str:
    return hashlib.md5(data).hexdigest()


def md5_file(path: Path) -> str:
    h = hashlib.md5()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()


def read_text(path: Path) -> str:
    raw = path.read_bytes()
    for enc in ('utf-8-sig', 'utf-8', 'gb18030'):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode('utf-8', 'replace')


def norm_cell(cell: str) -> str:
    """归一化单元格：去空白、空值字面量统一为空、整数型数字去尾零（0.0 == 0）。"""
    s = cell.strip()
    if s in NULL_TOKENS:
        return ''
    body = s.replace('.', '', 1)
    if body[:1] in '+-':
        body = body[1:]
    if body.isdigit():
        try:
            f = float(s)
            if f == int(f):
                return str(int(f))
        except (ValueError, OverflowError):
            pass
    return s


# ---------------------------------------------------------------------------
# 表解析与语义指纹
# ---------------------------------------------------------------------------
class Table:
    __slots__ = ('name', 'header', 'types', 'rows', 'dup_keys', 'padding', 'sig', 'err')

    def __init__(self, name):
        self.name = name
        self.header = []
        self.types = []
        self.rows = {}
        self.dup_keys = 0
        self.padding = 0
        self.sig = ''
        self.err = ''


def parse_txt(name: str, text: str) -> Table:
    t = Table(name)
    lines = [ln.rstrip('\r') for ln in text.split('\n')]
    while lines and not lines[-1].strip():
        lines.pop()
    # 空表（整文件只有空行）：两侧都是空表就等价，不算解析失败
    if not lines:
        t.sig = md5_bytes(b'')
        return t

    def cells_of(line):
        cs = [c.strip() for c in line.split('\t')]
        while cs and cs[-1] == '':
            cs.pop()
        return cs

    t.header = cells_of(lines[0])
    t.types = cells_of(lines[1]) if len(lines) > 1 else []
    width = len(t.header)

    for idx, line in enumerate(lines[2:], start=3):
        if not line.strip():
            continue
        cs = cells_of(line)
        # 🔴 尾随空单元格被削掉是**正常**的（导出器把 null 写成空串），补空即可；
        #    只有「列数超过表头」才是真异常（串列/多写了字段）。
        if len(cs) > width:
            t.err = '第 %d 行有 %d 列，超过表头 %d 列（串列风险）' % (idx, len(cs), width)
            return t
        cs += [''] * (width - len(cs))
        key = norm_cell(cs[0])
        # 零值填充行：目标 txt 里有一批这类尾巴，不算内容
        if key == '' or (key == '0' and all(norm_cell(c) in ('', '0') for c in cs[1:])):
            t.padding += 1
            continue
        if key in t.rows:
            t.dup_keys += 1
            continue
        t.rows[key] = cs

    # 语义指纹：表头 + 按主键排序的行（行序不算改动）+ 单元格归一化
    parts = ['\x01'.join(t.header)]
    for key in sorted(t.rows, key=lambda k: (len(k), k)):
        parts.append('\x01'.join(norm_cell(c) for c in t.rows[key]))
    t.sig = md5_bytes('\n'.join(parts).encode('utf-8'))
    return t


def _is_numeric_type(ty: str) -> bool:
    """类型行形如 `int` / `mut,int#int,2` / `mut,int#int,1`，取出基础类型判断。"""
    for tok in re.split(r'[#,|]', ty):
        if tok.strip().lower() in NUMERIC_TYPES:
            return True
    return False


def count_nil_numeric(t: Table) -> int:
    """数值列里字面量 "nil" 的个数。

    🔴 服务端 StringUtil.parseFiledInt/2/3 只认 "null"/空串/空格，其余直接
    Integer.parseInt ⇒ 数值列写 "nil" 会让整张表加载中断（2026-10-21 实测
    RechargeCommodityConfig 起不来）。导出器 2026-10-21 已改成写 "null"，
    但**旧的导表产物（影子目录）里还是 nil**，直接推上去就是事故。
    """
    if not t.types:
        return 0
    idx = [i for i, ty in enumerate(t.types) if _is_numeric_type(ty)]
    if not idx:
        return 0
    n = 0
    for row in t.rows.values():
        for i in idx:
            if i < len(row) and row[i].strip().lower() == 'nil':
                n += 1
    return n


INT32_MIN, INT32_MAX = -2147483648, 2147483647
_INT_RE = re.compile(r'^-?\d+$')


def _base_type(ty: str):
    """类型行 → (基础类型, 'scalar'|'list')；不认识的返回 (None, '')。"""
    ty = ty.strip().lower()
    if ty in ('int', 'long', 'float', 'double'):
        return ty, 'scalar'
    if ty.startswith('ref'):
        return 'int', 'scalar'          # dealParams: startsWith("ref") → Integer.parseInt
    if ty.startswith('mut'):
        parts = ty.split(',')
        if len(parts) > 1:
            base = parts[1].split('#')[0].strip()
            if base in ('int', 'float'):
                return base, 'list'     # intField/floatField → parseFiledInt/2/3
    return None, ''


def server_parse_issues(t: Table, limit=3):
    """找出服务端按类型解析会抛异常的单元格，返回 (count, samples)。

    🔴 2026-10-22 实测：把导出表推到测试服后重启，3 张表直接抛 NumberFormatException，
    整张表没加载进去 —— 全是 xlsx 里的脏数据，跟同步逻辑无关：
      SupremacyLevelConfig.Hit = 740.000000000001（Excel 浮点误差，列是 int）
      ChallengeConfig.MapTime   = 9999999999（超 int32）
      RunesPoolConfig.Max       = 1.25（整数列写小数）
    服务端 STableManager.dealParams 对 int 列直接 Integer.parseInt，没有任何容错，
    抛了还会 throw e 把整张表的加载打断 ⇒ 必须在推之前拦下来。
    """
    if not t.types:
        return 0, []
    count, samples = 0, []
    for i, ty in enumerate(t.types):
        base, kind = _base_type(ty)
        if base is None:
            continue
        for key, row in t.rows.items():
            if i >= len(row):
                continue
            cell = row[i].strip()
            if cell in NULL_TOKENS:
                continue
            bad = False
            if base == 'int':
                toks = [cell] if kind == 'scalar' else re.split(r'[|#,;]', cell)
                for tok in toks:
                    tok = tok.strip()
                    if not tok:
                        continue
                    if not _INT_RE.match(tok):
                        bad = True
                        break
                    v = int(tok)
                    if not (INT32_MIN <= v <= INT32_MAX):
                        bad = True
                        break
            elif base == 'long':
                if not _INT_RE.match(cell):
                    bad = True
                else:
                    try:
                        int(cell)
                    except ValueError:
                        bad = True
            else:                       # float / double
                toks = [cell] if kind == 'scalar' else re.split(r'[|#,;]', cell)
                for tok in toks:
                    tok = tok.strip()
                    if not tok:
                        continue
                    try:
                        float(tok)
                    except ValueError:
                        bad = True
                        break
            if bad:
                count += 1
                if len(samples) < limit:
                    name = t.header[i] if i < len(t.header) else str(i)
                    samples.append('%s(id=%s)=%s' % (name, key, cell[:24]))
    return count, samples


def _norm_int_token(tok: str):
    """把 int 列的单元格归一化成服务端 Integer.parseInt 能吃的形式。

    规则 = Java `(int)` 强制转换语义 + int32 夹取（不是取模回绕）：
      '740.000000000001' → '740'        （Excel 浮点误差，截断）
      '1.25' / '7.5'     → '1' / '7'    （整数列写了小数，向零截断）
      '9999999999'       → '2147483647' （超 int32，夹到上限）
    这套规则不是拍脑袋：发包树 TimeSpaceServer/Server_x1tag1.2.2/server_game
    里这三处现存值正好就是 740 / 2147483647 / 1，说明历史上的导表链路就是这么归一的，
    现在这条链路丢了 ⇒ 归一化只是把口径补回来，不改变服务端行为（int 列本来也存不下 1.25）。
    返回 None 表示不是数字（无法自动修）。
    """
    s = tok.strip()
    if _INT_RE.match(s):
        v = int(s)
        if INT32_MIN <= v <= INT32_MAX:
            return s
        return str(max(INT32_MIN, min(INT32_MAX, v)))
    try:
        f = float(s)
    except ValueError:
        return None
    if f != f or f in (float('inf'), float('-inf')):
        return None
    v = int(f)                       # Python int() 就是向零截断，与 Java (int) 一致
    return str(max(INT32_MIN, min(INT32_MAX, v)))


def fix_numeric(path: Path, t: Table, dry=False):
    """把 int 列里服务端解析不了的值就地归一化，返回 (改写数, 样例, 修不了的样例)。"""
    if not t.types:
        return 0, [], []
    cols = []
    for i, ty in enumerate(t.types):
        base, kind = _base_type(ty)
        if base == 'int':
            cols.append((i, kind))
    if not cols:
        return 0, [], []
    raw = path.read_bytes()
    enc = 'utf-8'
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError:
        enc, text = 'gb18030', raw.decode('gb18030', 'replace')
    lines = text.split('\n')
    changed, samples, unfixable = 0, [], []
    for li in range(2, len(lines)):
        if not lines[li].strip():
            continue
        cr = lines[li].endswith('\r')
        cells = (lines[li][:-1] if cr else lines[li]).split('\t')
        hit = False
        for i, kind in cols:
            if i >= len(cells):
                continue
            cell = cells[i]
            if cell.strip().lower() in NULL_TOKENS:
                continue
            if kind == 'scalar':
                new = _norm_int_token(cell)
                if new is None:
                    if len(unfixable) < 5:
                        unfixable.append('%s(id=%s)=%s' % (t.header[i] if i < len(t.header) else i,
                                                           cells[0], cell[:20]))
                    continue
                if new != cell:
                    if len(samples) < 5:
                        samples.append('%s(id=%s) %s→%s' % (t.header[i] if i < len(t.header) else i,
                                                            cells[0], cell[:20], new))
                    cells[i] = new
                    changed += 1
                    hit = True
            else:
                toks = re.split(r'([|#,;])', cell)      # 保留分隔符
                col_hit = False
                for k in range(0, len(toks), 2):
                    if not toks[k].strip():
                        continue
                    new = _norm_int_token(toks[k])
                    if new is None:
                        if len(unfixable) < 5:
                            unfixable.append('%s(id=%s)=%s' % (t.header[i] if i < len(t.header) else i,
                                                               cells[0], cell[:20]))
                        continue
                    if new != toks[k]:
                        if len(samples) < 5:
                            samples.append('%s(id=%s) %s→%s' % (t.header[i] if i < len(t.header) else i,
                                                                cells[0], toks[k][:20], new))
                        toks[k] = new
                        changed += 1
                        col_hit = True
                if col_hit:
                    cells[i] = ''.join(toks)
                    hit = True
        if hit:
            lines[li] = '\t'.join(cells) + ('\r' if cr else '')
    if changed and not dry:
        path.write_bytes('\n'.join(lines).encode(enc))
    return changed, samples, unfixable


def rewrite_nil(path: Path, t: Table) -> int:
    """把数值列里的 `nil` 就地改写成 `null`，返回改写个数。

    等价于「修复后的导出器重新导出一次」的结果（DataHelper.GetValByDefault 现在写 null），
    只是不用重开 Unity 跑 20 分钟导表。行尾风格原样保留。
    """
    if not t.types:
        return 0
    idx = {i for i, ty in enumerate(t.types) if _is_numeric_type(ty)}
    if not idx:
        return 0
    raw = path.read_bytes()
    enc = 'utf-8'
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError:
        enc, text = 'gb18030', raw.decode('gb18030', 'replace')
    lines = text.split('\n')
    changed = 0
    for li in range(2, len(lines)):
        if not lines[li].strip():
            continue
        cr = lines[li].endswith('\r')
        cells = (lines[li][:-1] if cr else lines[li]).split('\t')
        hit = False
        for i in idx:
            if i < len(cells) and cells[i].strip().lower() == 'nil':
                cells[i] = 'null'
                changed += 1
                hit = True
        if hit:
            lines[li] = '\t'.join(cells) + ('\r' if cr else '')
    if changed:
        path.write_bytes('\n'.join(lines).encode(enc))
    return changed


def classify(local: Table, target: Table, name: str):
    """返回 (verdict, notes)。verdict 见 VERDICT_TEXT。"""
    notes = []
    if local.err:
        return 'PARSE_FAIL', ['本地：' + local.err]
    if target.err:
        return 'PARSE_FAIL', ['目标：' + target.err]

    lh, rh = local.header, target.header
    if lh == rh:
        pass
    elif lh and rh and lh == rh[:len(lh)] and len(lh) < len(rh):
        return 'COL_LOSS', ['目标 %d 列 / 本地 %d 列，本地缺列：%s'
                            % (len(rh), len(lh), ', '.join(rh[len(lh):]))]
    elif lh and rh and rh == lh[:len(rh)] and len(lh) > len(rh):
        notes.append('本地多列：%s（服务端按字段名反射注入，需确认 S*Config 已有该字段）'
                     % ', '.join(lh[len(rh):]))
    else:
        diff = [(i, a, b) for i, (a, b) in enumerate(zip(lh, rh)) if a != b]
        return 'HEADER_DIFF', ['表头字段名/顺序不一致，首个差异：%s' % (diff[:3],)]

    if name in REVIEW_ONLY:
        notes.insert(0, REVIEW_ONLY[name])

    lost = [k for k in target.rows if k not in local.rows]
    if lost:
        sample = ', '.join(lost[:6]) + (' …' if len(lost) > 6 else '')
        return 'ROW_LOSS', ['目标有 %d 个主键本地没有（覆盖会删数据）：%s' % (len(lost), sample)]

    added = [k for k in local.rows if k not in target.rows]
    changed_rows, changed_cells, common = [], 0, 0
    for key, lrow in local.rows.items():
        rrow = target.rows.get(key)
        if rrow is None:
            continue
        common += 1
        n = sum(1 for i in range(min(len(lrow), len(rrow)))
                if norm_cell(lrow[i]) != norm_cell(rrow[i]))
        if n:
            changed_cells += n
            changed_rows.append(key)

    if changed_rows:
        sample = ', '.join(changed_rows[:6]) + (' …' if len(changed_rows) > 6 else '')
        notes.append('%d/%d 行有值变动，共 %d 个单元格（主键样例：%s）'
                     % (len(changed_rows), common, changed_cells, sample))
    if added:
        sample = ', '.join(added[:6]) + (' …' if len(added) > 6 else '')
        notes.append('本地新增 %d 行：%s' % (len(added), sample))
    if local.dup_keys or target.dup_keys:
        notes.append('重复主键：本地 %d / 目标 %d（只比首次出现）' % (local.dup_keys, target.dup_keys))

    if name in REVIEW_ONLY:
        return 'REVIEW', notes
    if changed_rows:
        verdict = 'VALUE_DIFF'
    elif added:
        verdict = 'ROW_ADD'
    elif local.sig == target.sig:
        return 'SAME', ['归一化后逐格一致（字节差异来自换行/尾随空列/0.0/nil 之类）']
    else:
        verdict = 'COL_GAIN'

    nil = count_nil_numeric(local)
    if nil:
        notes.insert(0, '本地数值列有 %d 个空值写成 "nil"：服务端 parseFiledInt 直接 Integer.parseInt '
                        '⇒ NumberFormatException，整表加载中断（2026-10-21 实测）。'
                        '这份产物是导出器修复前的旧表，先重跑导表再同步' % nil)
        return 'NIL_CELLS', notes
    bad, samples = server_parse_issues(local)
    if bad:
        notes.insert(0, '本地有 %d 个单元格服务端解析不了（int 列写了小数/超 int32/非数字）：%s。'
                        '推上去会 NumberFormatException 并中断整表加载（2026-10-22 实测），'
                        '先在 xlsx 里改掉' % (bad, '；'.join(samples)))
        return 'PARSE_BAD', notes
    return verdict, notes


# ---------------------------------------------------------------------------
# 同步目标
# ---------------------------------------------------------------------------
class Target:
    """一套服务端配置目录。kind = local（本机） / ssh（远端）。"""

    def __init__(self, name: str, kind: str, base, dirs: list, restart_hint: str):
        self.name = name
        self.kind = kind
        self.base = base
        self.dirs = list(dirs)
        self.restart_hint = restart_hint

    @property
    def label(self) -> str:
        return ('本机测试服' if self.kind == 'local' else '线上服') + '(%s)' % self.name

    def where(self, rdir: str) -> str:
        if self.kind == 'local':
            return str(Path(self.base) / rdir)
        return '%s:%s/%s' % (SSH_HOST, str(self.base).rstrip('/'), rdir)

    # ---- 读取 ----
    def md5s(self) -> dict:
        if self.kind == 'local':
            out = {}
            for rd in self.dirs:
                d = Path(self.base) / rd
                out[rd] = {p.name: md5_file(p) for p in sorted(d.glob('*.txt'))} if d.is_dir() else {}
            return out
        # 一次 ssh 拿多个目录的清单（每次握手 2~3 秒，别逐目录调）
        parts = []
        for rd in self.dirs:
            parts.append('echo "@@%s"' % rd)
            parts.append('cd %s 2>/dev/null && md5sum *.txt 2>/dev/null'
                         % shlex.quote('%s/%s' % (str(self.base).rstrip('/'), rd)))
        p = run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', SSH_HOST, '; '.join(parts)])
        out = {rd: {} for rd in self.dirs}
        cur = None
        for line in p.stdout.splitlines():
            if line.startswith('@@'):
                cur = line[2:].strip()
                continue
            bits = line.split()
            if cur in out and len(bits) == 2:
                out[cur][bits[1]] = bits[0]
        return out

    def snapshot(self, rdir: str, md5map: dict, refresh=False):
        """拿到该目标某目录的本地可读副本（本机就是原目录，远端整包 tar 拉取并缓存）。"""
        if self.kind == 'local':
            d = Path(self.base) / rdir
            return d if d.is_dir() else None
        return _ssh_snapshot(self, rdir, md5map, refresh)

    # ---- 写入 ----
    def backup(self, dest: Path) -> bool:
        BACKUP_DIR.mkdir(parents=True, exist_ok=True)
        if self.kind == 'local':
            cmd = ['tar', 'czf', str(dest), '-C', str(self.base)] + self.dirs
            p = run(cmd)
            if p.returncode != 0 or not dest.exists() or dest.stat().st_size < 512:
                return False
        else:
            script = 'tar czf - -C %s %s' % (shlex.quote(str(self.base)),
                                             ' '.join(shlex.quote(d) for d in self.dirs))
            with open(dest, 'wb') as f:
                p = subprocess.run(['ssh', '-o', 'BatchMode=yes', SSH_HOST, script],
                                   stdout=f, stderr=subprocess.PIPE, timeout=SSH_TIMEOUT)
            if p.returncode != 0 or dest.stat().st_size < 512:
                return False
        return run(['tar', 'tzf', str(dest)]).returncode == 0   # 备份必须可解

    def push(self, local_path: Path, rdir: str, name: str) -> bool:
        if self.kind == 'local':
            try:
                (Path(self.base) / rdir / name).write_bytes(local_path.read_bytes())
                return True
            except OSError as e:
                log('   ✗ %s → %s 写入失败：%s' % (name, rdir, e))
                return False
        p = run(['scp', '-q', str(local_path),
                 '%s:%s/%s/%s' % (SSH_HOST, str(self.base).rstrip('/'), rdir, name)])
        return p.returncode == 0

    def restart(self) -> bool:
        if self.kind == 'local':
            p = run(['launchctl', 'kickstart', '-k',
                     'gui/%d/%s' % (os.getuid(), LOCAL_RESTART_LABEL)])
            if p.returncode != 0:
                log('   ✗ launchctl kickstart 失败：%s' % (p.stderr.strip()[:200]))
                return False
            return True
        p = run(['ssh', '-o', 'BatchMode=yes', SSH_HOST, 'bash %s 2>&1 | tail -30' % GS_RESTART_SCRIPT],
                timeout=600)
        log(p.stdout.strip() or p.stderr.strip())
        return p.returncode == 0


def _ssh_snapshot(target: Target, rdir: str, md5map: dict, refresh: bool):
    """把远端某个配置目录整包拉到本地缓存（一次 tar 传输，按 md5 清单判新旧）。"""
    # 🔴 缓存键必须带上 base：否则拿 --gs-base 指向测试目录跑一次，
    #    会把生产快照缓存覆盖掉（实测踩过，下次比对直接解包失败）
    key = '%s_%s' % (md5_bytes(('%s|%s' % (target.base, rdir)).encode())[:8],
                     rdir.strip('/').replace('/', '_'))
    snap = CACHE_DIR / ('snap_' + key)
    index = snap / '.md5index.json'
    if not refresh and index.exists():
        try:
            if json.loads(index.read_text(encoding='utf-8')) == md5map:
                return snap
        except (json.JSONDecodeError, OSError):
            pass

    log('   下载 %s 快照 %s（%d 个 txt）…' % (target.name, rdir, len(md5map)))
    script = 'tar czf - -C %s %s' % (shlex.quote(str(target.base)), shlex.quote(rdir))
    blob = b''
    for attempt in (1, 2):
        p = subprocess.run(['ssh', '-o', 'BatchMode=yes', SSH_HOST, script],
                           capture_output=True, timeout=SSH_TIMEOUT)
        if p.returncode == 0 and p.stdout:
            blob = p.stdout
            break
        log('   ⚠ tar 拉取失败（第 %d 次）：%s'
            % (attempt, p.stderr.decode('utf-8', 'replace')[:200]))
    if not blob:
        return None

    tmp = CACHE_DIR / ('tmp_' + key)
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True, exist_ok=True)
    try:
        with tarfile.open(fileobj=io.BytesIO(blob), mode='r:gz') as tf:
            try:
                tf.extractall(tmp, filter='data')     # py3.12+
            except TypeError:
                tf.extractall(tmp)
    except (tarfile.TarError, EOFError, OSError) as e:
        log('   ⚠ 解包失败（传输被截断？）：%s' % e)
        shutil.rmtree(tmp, ignore_errors=True)
        return None

    src = tmp / rdir
    if not src.is_dir():
        log('   ⚠ 解包后找不到目录：%s' % src)
        return None
    shutil.rmtree(snap, ignore_errors=True)
    shutil.move(str(src), str(snap))
    shutil.rmtree(tmp, ignore_errors=True)
    (snap / '.md5index.json').write_text(json.dumps(md5map, ensure_ascii=False), encoding='utf-8')
    return snap


def env_table_targets(env_name: str) -> list:
    """把 Jenkins 的 SERVER_ENV（如「现网-129.226.213.65」）映射成同步目标。

    🔴 映射写在 scripts/build_envs.json 的 tableTargets 里，不写死在 job / 脚本：
       出包环境与「表该推给谁」是同一件事，分两处写迟早会漂。
    返回 [] 表示该环境没有可推的服务端（例如正式服 103.151.173.99 已下线）——
    这是**正常跳过**，不是错误。
    """
    try:
        data = json.loads(ENVS_FILE.read_text(encoding='utf-8'))
    except (OSError, json.JSONDecodeError) as e:
        raise SystemExit('✗ 读不到环境表 %s：%s' % (ENVS_FILE, e))
    envs = data.get('envs') or {}
    if env_name not in envs:
        raise SystemExit('✗ build_envs.json 里没有环境「%s」（可选：%s）'
                         % (env_name, ' / '.join(envs)))
    if 'tableTargets' not in envs[env_name]:
        raise SystemExit('✗ 环境「%s」缺 tableTargets 字段（在 scripts/build_envs.json 里补上，'
                         '例如 ["gs"]；没有可推的服务端就写 []）' % env_name)
    out = [t.strip() for t in envs[env_name]['tableTargets'] if t.strip()]
    return out


def build_targets(names: list, dirs: list, local_base: str, gs_base: str) -> list:
    out = []
    for n in names:
        if n == 'local':
            out.append(Target('local', 'local', Path(local_base).expanduser(), dirs,
                              'launchctl kickstart -k gui/%d/%s' % (os.getuid(), LOCAL_RESTART_LABEL)))
        elif n == 'gs':
            out.append(Target('gs', 'ssh', gs_base, dirs,
                              'ssh %s "bash %s"' % (SSH_HOST, GS_RESTART_SCRIPT)))
        else:
            raise SystemExit('✗ 未知目标：%s（可选 local / gs）' % n)
    return out


# ---------------------------------------------------------------------------
# 基线状态
# ---------------------------------------------------------------------------
def load_state() -> dict:
    if not STATE_FILE.exists():
        return {}
    try:
        st = json.loads(STATE_FILE.read_text(encoding='utf-8'))
    except (json.JSONDecodeError, OSError):
        log('⚠ 基线文件损坏，按首次运行处理：%s' % STATE_FILE)
        return {}
    # v1 → v2：v1 只有单一 remote，把它的 sig 提成全局基线
    if st and 'tables' in st and 'sig' not in st:
        sig = {k: v.get('sig') for k, v in st.get('tables', {}).items() if v.get('sig')}
        st = {'version': 2, 'sig': sig,
              'targets': {'gs': {'last_sync_at': st.get('last_sync_at', ''),
                                 'base': st.get('remote', '')}}}
    return st


def save_state(state: dict):
    WORK_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2, sort_keys=True),
                          encoding='utf-8')


def git_changed_tables(local_dir: Path):
    """用 git 工作区差异判断「本次导表改过哪些表」；不在 git 里返回 None。"""
    try:
        rel = local_dir.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return None
    p = run(['git', '-C', str(PROJECT_ROOT), 'status', '--porcelain', '--', rel])
    if p.returncode != 0:
        return None
    names = set()
    for line in p.stdout.splitlines():
        path = line[3:].strip().strip('"')
        if path.endswith('.txt'):
            names.add(os.path.basename(path))
    return names


def _names(raw: str) -> set:
    """'A,B' → {'A.txt','B.txt'}（表名可不带扩展名）。"""
    out = set()
    for n in raw.split(','):
        n = n.strip()
        if n:
            out.add(n if n.endswith('.txt') else n + '.txt')
    return out


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
def main() -> int:
    global STATE_FILE
    ap = argparse.ArgumentParser(description='导表服务端同步（增量 + 结构体检，多目标）',
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--local-dir', default=str(DEFAULT_LOCAL_DIR), help='导表产物目录（默认影子目录）')
    ap.add_argument('--targets', default=None,
                    help='同步目标，逗号分隔：local（本机测试服）/ gs（线上服），默认两个都做')
    ap.add_argument('--env', default='',
                    help='按打包环境决定目标（取 scripts/build_envs.json 的 tableTargets），'
                         '例如「现网-129.226.213.65」→ gs、「测试服」→ local。'
                         '给了 --env 就忽略 --targets；该环境没有可推服务端时直接跳过（rc=0）')
    ap.add_argument('--dirs', default=','.join(DEFAULT_DIRS),
                    help='目标里的子目录，逗号分隔（默认 conf/server,assets/conf/server）')
    ap.add_argument('--local-base', default=str(LOCAL_BASE), help='本机测试服根目录')
    ap.add_argument('--gs-base', default=GS_BASE, help='线上服根目录（默认 %s）' % GS_BASE)
    ap.add_argument('--mirror-dir', default=str(DEFAULT_MIRROR_DIR), help='本地真实服务端仓配置目录')
    ap.add_argument('--no-mirror-repo', action='store_true', help='不写本地服务端仓')
    ap.add_argument('--state-file', default=str(STATE_FILE), help='基线文件（默认 %s）' % STATE_FILE)
    ap.add_argument('--apply', action='store_true', help='真正写目标（默认只体检）')
    ap.add_argument('--only', default='', help='只处理这些表（逗号分隔，忽略基线）')
    ap.add_argument('--include-drift', action='store_true',
                    help='把所有与目标不同的表纳入候选（危险：会带上未发布内容）')
    ap.add_argument('--force', action='store_true', help='点名表即使体检红灯也推（仅配合 --only）')
    ap.add_argument('--restart', action='store_true', help='推完重启（线上会踢线，非交互需 --yes）')
    ap.add_argument('--strict', action='store_true', help='存在被拦下的表时退出码 4')
    ap.add_argument('--yes', action='store_true', help='跳过危险操作的交互确认')
    ap.add_argument('--status', action='store_true', help='只打印基线/候选，不做体检')
    ap.add_argument('--refresh', action='store_true', help='强制重新下载远端快照')
    ap.add_argument('--fix-nil', action='store_true',
                    help='推送前把数值列的 nil 就地改写成 null（等价于重跑一次导表，会改 git 工作区文件）')
    ap.add_argument('--fix-numeric', action='store_true',
                    help='把 int 列里服务端解析不了的值（小数/超 int32）就地归一化，需配合 --apply-fix 落盘')
    ap.add_argument('--json-out', default='', help='额外写一份结构化结果 JSON')
    ap.add_argument('--apply-fix', action='store_true',
                    help='配合 --fix-numeric：真正改写本地 txt（不加只报告）')
    args = ap.parse_args()

    STATE_FILE = Path(args.state_file).resolve()
    local_dir = Path(args.local_dir).resolve()
    mirror_dir = Path(args.mirror_dir).resolve()
    dirs = [d.strip() for d in args.dirs.split(',') if d.strip()]

    if args.env:
        names = env_table_targets(args.env)
        if not names:
            log('=' * 88)
            log('导表服务端同步  环境：%s' % args.env)
            log('该环境没有配置同步目标（build_envs.json 的 tableTargets 为空）⇒ 跳过，不动任何服务端')
            log('=' * 88)
            return 0
        if args.targets:
            log('⚠ 同时给了 --env 与 --targets，按 --env 走（%s → %s）'
                % (args.env, ','.join(names)))
    else:
        names = [t.strip() for t in (args.targets or 'local,gs').split(',') if t.strip()]
    targets = build_targets(names, dirs, args.local_base, args.gs_base)

    log('=' * 88)
    log('导表服务端同步  %s' % time.strftime('%Y-%m-%d %H:%M:%S'))
    if args.env:
        log('  打包环境：%s ⇒ 目标 %s' % (args.env, ','.join(names)))
    log('  本地导出：%s' % local_dir)
    for t in targets:
        log('  目标 %-6s：%s  (%s)' % (t.name, t.where(dirs[0]), ', '.join(dirs)))
    log('  基线文件：%s' % STATE_FILE)
    log('=' * 88)

    if not local_dir.is_dir():
        log('✗ 本地导出目录不存在：%s' % local_dir)
        return 2
    local_files = {p.name: p for p in sorted(local_dir.glob('*.txt'))}
    if not local_files:
        log('✗ 本地导出目录里没有 txt：%s' % local_dir)
        return 2
    log('本地 txt：%d 个，解析中 …' % len(local_files))
    local_tables = {n: parse_txt(n, read_text(p)) for n, p in local_files.items()}
    local_md5 = {n: md5_file(p) for n, p in local_files.items()}

    if args.fix_nil:
        n_tab = n_cell = 0
        for name, lt in list(local_tables.items()):
            if not count_nil_numeric(lt):
                continue
            c = rewrite_nil(local_files[name], lt)
            if c:
                local_tables[name] = parse_txt(name, read_text(local_files[name]))
                local_md5[name] = md5_file(local_files[name])
                n_tab += 1
                n_cell += c
        if n_tab:
            log('🔧 --fix-nil：%d 张表、%d 个数值列 nil → null（等价于修复后导出器的输出）'
                % (n_tab, n_cell))
            log('   这些文件在 git 工作区已有改动，记得和导表产物一起提交')
        else:
            log('--fix-nil：没有需要改写的 nil')

    if args.fix_numeric:
        dry = not args.apply_fix
        n_tab = n_cell = 0
        for name, lt in list(local_tables.items()):
            bad, _ = server_parse_issues(lt)
            if not bad:
                continue
            c, samples, unfix = fix_numeric(local_files[name], lt, dry=dry)
            if c:
                n_tab += 1
                n_cell += c
                log('  %-32s %4d 处  %s' % (name, c, '；'.join(samples)))
            if unfix:
                log('  ⚠ %-30s 这些不是数字，自动改不了：%s' % (name, '；'.join(unfix)))
            if c and not dry:
                local_tables[name] = parse_txt(name, read_text(local_files[name]))
                local_md5[name] = md5_file(local_files[name])
        if n_tab:
            log('🔧 --fix-numeric：%d 张表、%d 个单元格归一化（int 列截断 + int32 夹取，'
                '与发包树 Server_x1tag1.2.2 现存口径一致）%s'
                % (n_tab, n_cell, '' if not dry else '  —— 只报告，加 --apply-fix 才落盘'))
            if not dry:
                log('   这些文件在 git 工作区已有改动，记得和导表产物一起提交')
        else:
            log('--fix-numeric：没有需要归一化的 int 单元格')

    # ---- 各目标现状 ------------------------------------------------------
    log('读取各目标现状 …')
    tgt_md5, tgt_tables = {}, {}
    for t in targets:
        m = t.md5s()
        if not any(m.get(d) for d in dirs):
            log('✗ 读不到目标 %s（%s）—— 路径/ssh 别名/权限问题？' % (t.name, t.where(dirs[0])))
            return 2
        tgt_md5[t.name] = m
        first = m[dirs[0]]
        extra = ' / '.join('%s:%d' % (d, len(m.get(d, {}))) for d in dirs[1:])
        log('  %-6s %s  %d 个 txt%s' % (t.name, t.where(dirs[0]), len(first),
                                        ('  (' + extra + ')') if extra else ''))
        snap = t.snapshot(dirs[0], first, refresh=args.refresh)
        if snap is None:
            log('✗ %s 快照获取失败，无法做语义比对' % t.name)
            return 2
        parsed = {}
        for name, md in first.items():
            rp = Path(snap) / name
            if not rp.exists():
                continue
            if md5_file(rp) != md:
                log('  ⚠ %s/%s 快照与目标 md5 不符（刚被改过？加 --refresh 重试）' % (t.name, name))
                continue
            parsed[name] = parse_txt(name, read_text(rp))
        tgt_tables[t.name] = parsed
        log('         解析完成 %d 张' % len(parsed))

    # ---- 基线 ------------------------------------------------------------
    state = load_state()
    state.setdefault('version', 3)
    sig = state.setdefault('sig', {})
    first_run = not sig

    # 每个目标记一份「上次同步到哪个指纹」。第一次接触某目标时，以它**当前内容**建基线，
    # 这样「历史漂移」不会被当成「本次改动」自动推上去（要推必须显式 --include-drift）。
    for t in targets:
        rec = state.setdefault('targets', {}).setdefault(t.name, {})
        if 'sig' not in rec:
            rec['sig'] = {n: tb.sig for n, tb in tgt_tables[t.name].items()}
            log('  %s 首次接触：以其当前内容建基线（%d 张）' % (t.name, len(rec['sig'])))

    changed, src = set(), ''
    if args.only:
        changed = _names(args.only)
        src = '--only'
    elif not first_run:
        for name, lt in local_tables.items():
            if sig.get(name) != lt.sig:
                changed.add(name)
        # 已推过某个目标、但另一个目标还停在旧指纹的表，也要重新纳入
        for t in targets:
            tsig = state['targets'][t.name].get('sig', {})
            for name, lt in local_tables.items():
                if name in tsig and tsig[name] != lt.sig:
                    changed.add(name)
        src = '基线差异'
    else:
        git_set = git_changed_tables(local_dir)
        if git_set:
            changed = {n for n in git_set if n in local_tables}
            src = 'git 工作区差异'
        else:
            src = '首次运行（只建基线）'

    if args.include_drift:
        drift_all = set()
        for t in targets:
            for name, lt in local_tables.items():
                rt = tgt_tables[t.name].get(name)
                if rt is not None and rt.sig != lt.sig:
                    drift_all.add(name)
        changed = drift_all
        src = '--include-drift 全量漂移'

    # ---- 逐表 × 逐目标体检 -----------------------------------------------
    result, remote_only = {}, {t.name: set() for t in targets}
    for name, lt in local_tables.items():
        result[name] = {}
        for t in targets:
            rt = tgt_tables[t.name].get(name)
            if rt is None:
                nil = count_nil_numeric(lt)
                bad, samples = server_parse_issues(lt)
                if nil:
                    v, nt = 'NIL_CELLS', ['本地数值列有 %d 个 "nil" 空值，先重跑导表' % nil]
                elif bad:
                    v, nt = 'PARSE_BAD', ['本地有 %d 个单元格服务端解析不了：%s'
                                          % (bad, '；'.join(samples))]
                else:
                    v, nt = 'NEW', ['目标没有这张表（新增）']
                result[name][t.name] = {'verdict': v, 'notes': nt, 'rows': '',
                                        'pushable': v == 'NEW'}
                continue
            verdict, notes = classify(lt, rt, name)
            result[name][t.name] = {'verdict': verdict, 'notes': notes,
                                    'rows': '%d→%d' % (len(rt.rows), len(lt.rows)),
                                    'pushable': verdict in OK_VERDICTS}
    for t in targets:
        for name in tgt_md5[t.name][dirs[0]]:
            if name not in local_tables:
                remote_only[t.name].add(name)
                result.setdefault(name, {})[t.name] = {
                    'verdict': 'REMOTE_ONLY',
                    'notes': ['目标有、本地导出没有：可能纯后端表或已下线表，本工具不删目标文件'],
                    'rows': '', 'pushable': False}

    drift = {n for n, per in result.items()
             if any(per.get(t.name, {}).get('verdict') not in (None, 'SAME') for t in targets)}

    log('')
    log('基线：%s（记录 %d 张）｜候选来源：%s → %d 张'
        % ('首次运行' if first_run else '已存在', len(sig), src, len(changed)))
    for t in targets:
        d = sum(1 for n in result if result[n].get(t.name, {}).get('verdict') not in (None, 'SAME'))
        log('  %-6s 语义漂移 %3d 张｜目标独有 %d 张（永不删除）' % (t.name, d, len(remote_only[t.name])))

    if args.status:
        log('')
        for n in sorted(changed):
            if n not in result:
                continue
            log('  %-38s %s' % (n, '  '.join(
                '%s=%s' % (t.name, result[n].get(t.name, {}).get('verdict', '-')) for t in targets)))
        return 0

    missing = sorted(n for n in changed if n not in result)
    if missing:
        log('⚠ 找不到这些表（检查表名/是否已导出）：%s' % ', '.join(missing))

    # 候选表 × 目标 → 可推 / 拦下
    plan = {}
    for name in sorted(changed):
        if name not in result:
            continue
        plan[name] = {t.name: result[name].get(t.name, {}).get('pushable', False) for t in targets}
    if args.force and args.only:
        for name in _names(args.only):
            if name in plan:
                for t in targets:
                    if not plan[name][t.name] and result[name].get(t.name, {}).get('verdict') in BLOCK_VERDICTS:
                        plan[name][t.name] = True
                        result[name][t.name]['notes'].append('⚠ --force 点名强推')

    # ---- 打印 ------------------------------------------------------------
    if plan:
        log('')
        w = max(30, max(len(n) for n in plan) + 2)
        log('%-*s %s' % (w, '表', '  '.join('%-24s' % t.name for t in targets)))
        log('-' * (w + 26 * len(targets)))
        for name in sorted(plan):
            cells = []
            for t in targets:
                v = result[name].get(t.name, {}).get('verdict', '-')
                cells.append('%-24s' % ('%s%s' % (v, '' if plan[name][t.name] else ' ✗')))
            log('%-*s %s' % (w, name, '  '.join(cells)))
        log('-' * (w + 26 * len(targets)))
        tot = sum(1 for n in plan for t in targets if plan[n][t.name])
        log('候选 %d 张，可推 %d 个（表×目标），拦下 %d 个'
            % (len(plan), tot, len(plan) * len(targets) - tot))
    else:
        log('')
        log('本次没有候选表。')

    if drift and not changed:
        log('')
        log('ℹ 本次没检测到改动，但目标与仓库有 %d 张语义漂移（多为未发布内容，不自动推）：' % len(drift))
        for t in targets:
            stat = {}
            for n in drift:
                v = result[n].get(t.name, {}).get('verdict')
                if v and v != 'SAME':
                    stat[v] = stat.get(v, 0) + 1
            if stat:
                log('  %-6s %s' % (t.name, '  '.join('%s %d' % (k, c) for k, c in
                                                     sorted(stat.items(), key=lambda kv: -kv[1]))))
        log('    明细见报告；要推具体几张用 --only 表名（逗号分隔）')

    # ---- 落地 ------------------------------------------------------------
    if not args.apply:
        if any(plan[n][t.name] for n in plan for t in targets):
            log('')
            log('（体检模式，未写任何服务端。要推上面可推的：加 --apply）')
        if first_run:
            log('')
            log('首次运行只建基线，不推任何表。下次改表导表后会自动只推改动的那几张。')
            for name, lt in local_tables.items():
                sig[name] = lt.sig
            save_state(state)
        _write_report(targets, result, plan, {}, {}, drift, {}, dirs)
        return 0

    todo = {n: [t for t in targets if plan[n][t.name]] for n in plan}
    todo = {n: ts for n, ts in todo.items() if ts}
    if not todo:
        log('')
        log('没有可推的表，目标保持不变。')
        if first_run:
            for name, lt in local_tables.items():
                sig[name] = lt.sig
            save_state(state)
            log('基线已建立（%d 张表）。' % len(local_tables))
            _write_report(targets, result, plan, {}, {}, drift, {}, dirs)
        return 0

    if args.include_drift and not args.yes and not sys.stdin.isatty():
        log('')
        log('✗ --include-drift 会把所有历史漂移（含未发布内容）推到目标，非交互环境必须加 --yes')
        return 5

    pushed, failed, backups = {}, {}, {}
    for t in targets:
        names = [n for n in todo if t in todo[n]]
        if not names:
            continue
        log('')
        log('== %s：推 %d 张 %s' % (t.label, len(names), '=' * 40))
        backup = BACKUP_DIR / ('%s_%s.tar.gz' % (t.name, time.strftime('%Y%m%d_%H%M%S')))
        log('==> 备份 %s → %s' % (t.where(dirs[0]), backup.name))
        if not t.backup(backup):
            log('✗ %s 备份失败，跳过该目标（不做没有回滚点的推送）' % t.name)
            failed[t.name] = names
            continue
        mb = backup.stat().st_size / 1048576
        log('    备份完成 %s（已校验可解包）' % ('%.1f MB' % mb if mb >= 1 else '%.0f KB' % (mb * 1024)))
        backups[t.name] = backup

        ok_names = []
        for name in names:
            ok = True
            for rd in dirs:
                if not t.push(local_files[name], rd, name):
                    ok = False
                    log('   ✗ %s → %s 传输失败' % (name, rd))
            if ok:
                ok_names.append(name)
                log('   ✓ %s' % name)
        bad = [n for n in names if n not in ok_names]
        if bad:
            failed[t.name] = bad

        log('==> 双向 md5 校验')
        after = t.md5s()
        for rd in dirs:
            now = after.get(rd) or {}
            wrong = [n for n in ok_names if now.get(n) != local_md5[n]]
            if wrong:
                log('   ✗ %s 校验不过：%s' % (rd, ', '.join(wrong)))
                failed.setdefault(t.name, []).extend(wrong)
                ok_names = [n for n in ok_names if n not in wrong]
            else:
                log('   ✓ %s  %d/%d 一致' % (rd, len(ok_names), len(ok_names)))
        pushed[t.name] = ok_names

        # 远端快照对齐，下次体检不用再下 20MB
        if t.kind == 'ssh' and ok_names:
            snap = CACHE_DIR / ('snap_%s_%s' % (
                md5_bytes(('%s|%s' % (t.base, dirs[0])).encode())[:8],
                dirs[0].strip('/').replace('/', '_')))
            try:
                for n in ok_names:
                    (snap / n).write_bytes(local_files[n].read_bytes())
                (snap / '.md5index.json').write_text(
                    json.dumps(after.get(dirs[0], {}), ensure_ascii=False), encoding='utf-8')
            except OSError:
                pass

    # ---- 本地服务端仓 ----------------------------------------------------
    all_pushed = sorted({n for v in pushed.values() for n in v})
    if not args.no_mirror_repo and mirror_dir.is_dir() and all_pushed:
        log('')
        log('==> 同步本地服务端仓：%s' % mirror_dir)
        copied = 0
        for name in all_pushed:
            try:
                (mirror_dir / name).write_bytes(local_files[name].read_bytes())
                copied += 1
            except OSError as e:
                log('   ⚠ %s 写入失败：%s' % (name, e))
        log('   ✓ %d 张（未提交，记得在服务端仓 git add/commit）' % copied)
    elif not args.no_mirror_repo and not mirror_dir.is_dir():
        log('⚠ 本地服务端仓目录不存在，跳过：%s' % mirror_dir)

    # ---- 基线：只有「所有已知目标都到位」的表才前移 ----------------------
    now_ts = time.strftime('%Y-%m-%d %H:%M:%S')
    for t in targets:
        rec = state.setdefault('targets', {}).setdefault(t.name, {})
        rec['base'] = t.where(dirs[0])
        if pushed.get(t.name):
            rec['last_sync_at'] = now_ts
        for name in pushed.get(t.name, []):
            rec.setdefault('sig', {})[name] = local_tables[name].sig

    # 全局指纹只在「每个已知目标都已经到这个版本」时才前移。
    # 否则「只推了测试服」会让线上服永远漏掉这批表（本次就是要修的坑）。
    done = []
    for name, lt in local_tables.items():
        if name in plan and not (name in pushed.get(targets[0].name, []) or
                                 result[name].get(targets[0].name, {}).get('verdict') == 'SAME'):
            continue      # 第一个目标都没到位，别急着前移
        all_ok = True
        for tname, rec in state['targets'].items():
            tsig = rec.get('sig')
            if tsig is None:
                continue
            if tsig.get(name) != lt.sig:
                all_ok = False
                break
        if all_ok:
            if sig.get(name) != lt.sig:
                done.append(name)
            sig[name] = lt.sig
        else:
            sig.setdefault(name, lt.sig)
    state['version'] = 3
    state['last_sync_at'] = now_ts
    save_state(state)
    log('')
    log('==> 基线已更新：%s（本次前移 %d 张）' % (STATE_FILE, len(done)))

    _write_report(targets, result, plan, pushed, failed, drift, backups, dirs)
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')

    rc = 0
    if failed:
        log('')
        for tname, names in failed.items():
            log('✗ %s 失败 %d 张：%s' % (tname, len(names), ', '.join(names)))
        rc = 3

    blocked = [n for n in plan if not all(plan[n][t.name] for t in targets)]
    if blocked:
        log('')
        log('🔴 有表被拦下（对应目标未推）：')
        for n in blocked:
            for t in targets:
                v = result[n].get(t.name, {}).get('verdict')
                if not plan[n][t.name] and v:
                    log('   %-34s %-6s %s' % (n, t.name, VERDICT_TEXT.get(v, v)))
        if args.strict:
            rc = rc or 4

    # ---- 重启 ------------------------------------------------------------
    if args.restart and pushed:
        for t in targets:
            if not pushed.get(t.name):
                continue
            if t.kind == 'ssh' and not args.yes:
                if sys.stdin.isatty():
                    ans = input('⚠ 重启线上服会踢线（%s），继续？[y/N] ' % t.name).strip().lower()
                    if ans != 'y':
                        log('   跳过重启 %s' % t.name)
                        continue
                else:
                    log('⚠ 线上服 %s 未重启（非交互环境需加 --yes），新数值下次重启才生效' % t.name)
                    continue
            log('==> 重启 %s' % t.label)
            if not t.restart():
                log('✗ %s 重启失败，请手工处理：%s' % (t.name, t.restart_hint))
                rc = rc or 3
            else:
                log('   ✓ 已重启')
    elif pushed:
        log('')
        log('⚠ 表已落盘但服务端未重启，新数值要重启后才生效：')
        for t in targets:
            if pushed.get(t.name):
                log('   %-6s %s' % (t.name, t.restart_hint))

    log('')
    log('完成：%s；拦下 %d 张。' % (
        '，'.join('%s 推 %d 张' % (k, len(v)) for k, v in pushed.items()) or '没推任何表',
        len(blocked)))
    return rc


def _write_report(targets, result, plan, pushed, failed, drift, backups, dirs):
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    path = REPORT_DIR / ('sync_%s.md' % time.strftime('%Y%m%d_%H%M%S'))
    head = ['# 导表服务端同步报告 %s' % time.strftime('%Y-%m-%d %H:%M:%S'), '',
            '| 项 | 值 |', '|---|---|']
    for t in targets:
        head.append('| %s | `%s` |' % (t.label, t.where(dirs[0])))
    head.append('| 推送目录 | %s |' % ', '.join(dirs))
    for t in targets:
        b = backups.get(t.name)
        head.append('| %s 备份 | %s |' % (t.name, b.name if b else '（未写，无备份）'))
    for t in targets:
        head.append('| %s 已推 / 失败 | %d / %d |'
                    % (t.name, len(pushed.get(t.name, [])), len(failed.get(t.name, []))))
    head.append('| 语义漂移（未推） | %d 张 |' % len(drift))
    head.append('')

    cols = ' | '.join('`%s`' % t.name for t in targets)
    sep = '|---' * (len(targets) + 1) + '|'
    lines = head + ['## 候选表逐表判定', '', '| 表 | %s |' % cols, sep]
    for name in sorted(plan):
        cells = []
        for t in targets:
            r = result[name].get(t.name, {})
            mark = '✅' if plan[name][t.name] else '✗'
            cells.append('%s %s' % (r.get('verdict', '-'), mark))
        lines.append('| `%s` | %s |' % (name, ' | '.join(cells)))

    if drift:
        lines += ['', '## 语义漂移明细（本次未纳入候选）', '']
        for t in targets:
            rows = [(n, result[n].get(t.name, {})) for n in sorted(drift)
                    if result[n].get(t.name, {}).get('verdict') not in (None, 'SAME')]
            if not rows:
                continue
            lines += ['### %s' % t.label, '', '| 表 | 判定 | 行数(目标→本地) | 说明 |', '|---|---|---|---|']
            for n, r in rows:
                lines.append('| `%s` | %s | %s | %s |' % (n, r.get('verdict', ''), r.get('rows', ''),
                                                          '<br>'.join(r.get('notes', [])).replace('|', '\\|')))
            lines.append('')

    for t in targets:
        if pushed.get(t.name):
            lines += ['## %s 本次推送' % t.name, ''] + ['- `%s`' % n for n in pushed[t.name]] + ['']
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    log('报告：%s' % path)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        log('\n已中断')
        sys.exit(130)
