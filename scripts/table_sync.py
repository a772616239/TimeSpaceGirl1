#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""导表服务端同步（table_sync）：把本次导表改动的服务端 txt 安全推到线上服。

## 为什么需要它

客户端 lua（`Assets/ManagedResources/~Lua/Config/Data/*.lua`）与服务端 txt
（`conf/server/*.txt`）由**同一次导表**从 `data_execl/base_data/*.xlsx` 产生，
但 `DataConfigSetting.serverOutputDir` 只写本地影子目录：

    TimeSpaceServer/skzc/home/java/gameserver/conf/server      ← 导表写这里（git 里）
    gs:/home/java/gameserver/conf/server                       ← 线上真正读这里

这条链从来没被打通 ⇒ 客户端显示一套数值、服务端校验另一套（「显示 0 还能领」、
历史 `NoSuchMethodError` 都是这个结构问题的症状）。

## 为什么不能整目录 rsync（2026-10-22 审计结论，必须尊重）

    · Language.txt            线上 5 列（含 Korean），仓库 4 列 → 覆盖后韩语全空
    · EncourageTaskConfig     线上独有 16001~16025 → 覆盖等于删掉线上 25 条任务
    · 30+ 张表是未发布内容（随机奖励 / 觉醒属性 / 新道具段）→ 覆盖等于给线上玩家开新数值

所以本工具只做「增量 + 体检」，绝不整目录覆盖：

  1. **只推本次导表真正改过的表** —— 用「语义指纹」和上次同步基线比对
     （指纹 = 表头 + 按主键排序的行 + 单元格归一化后的 md5，
     所以尾随 TAB、`nil`↔`null`、`0.0`↔`0`、行序变化都不算改动）。
     没有基线时用 `git status` 的工作区差异当基线；**第一次跑只建基线，不推任何表**。
  2. **每张候选表先做结构体检** —— 列丢失 / 行丢失 / 表头错位 / 人工复核名单，
     命中任意一条直接拦下（拦下的表连 `--force` 都要显式点名才推）。
  3. **推前整目录备份、推后双向 md5 校验** —— 线上 `tar.gz` 落本地 backups/。
  4. **默认 `--plan` 只体检不改线上**；`--apply` 才写。

## 用法

    python3 scripts/table_sync.py                          # 体检（默认，不改线上）
    python3 scripts/table_sync.py --apply                  # 推「本次改动」且通过体检的表
    python3 scripts/table_sync.py --apply --only A,B       # 只推指定表（仍过体检）
    python3 scripts/table_sync.py --apply --only A --force # 点名强推（体检红灯也推）
    python3 scripts/table_sync.py --apply --include-drift  # 连历史漂移一起推（危险，需 --yes）
    python3 scripts/table_sync.py --status                 # 只打印基线与候选
    python3 scripts/table_sync.py --apply --restart        # 推完重启游戏服

退出码：0 正常 / 2 参数或环境错误 / 3 同步失败（传输或校验不过）
       4 存在被拦下的表（仅 --strict 时）/ 5 需要 --yes 但未提供

依赖：本机 ssh 已配置 Host gs（~/.ssh/config + tencent-gameserver.pem），
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

# 线上服：运行时读的第一份 + 资源目录里的那份，两份都要一致（2026-10-21 实测两个目录都要覆盖）
REMOTE_BASE = '/home/java/gameserver'
DEFAULT_REMOTE_DIRS = ['conf/server', 'assets/conf/server']

# 本地真实服务端仓（打 jar 用），默认同步过去，避免仓库继续落后于线上
DEFAULT_MIRROR_DIR = PROJECT_ROOT / 'TimeSpaceServer/Server_x1tag1.2.2/server_game/conf/server'

WORK_DIR = PROJECT_ROOT / 'build/table_sync'
STATE_FILE = WORK_DIR / 'state.json'
BACKUP_DIR = WORK_DIR / 'backups'
REPORT_DIR = WORK_DIR / 'reports'
CACHE_DIR = WORK_DIR / 'cache'

# 人工复核名单：结构体检可能全绿，但语义上必须产品确认才能动线上
REVIEW_ONLY = {
    'Language.txt': '多语言表：线上多 Korean 列，且英文/日文有数千行内容变动，需单独合并',
    'MultiLanguage.txt': '线上有仓库没有的 id（10301），需确认',
    'EncourageTaskConfig.txt': '线上独有 25 条任务（16001~16025），覆盖即删除',
    'EncouragePlanConfig.txt': '线上独有 id=16',
    'RewardItemConfig.txt': '仓库多 103 个 990000+ 段道具，属未发布内容',
}

OK_VERDICTS = {'VALUE_DIFF', 'ROW_ADD', 'COL_GAIN', 'NEW'}
BLOCK_VERDICTS = {'COL_LOSS', 'ROW_LOSS', 'HEADER_DIFF', 'REMOTE_ONLY', 'REVIEW', 'PARSE_FAIL', 'NIL_CELLS'}

VERDICT_TEXT = {
    'SAME': '一致',
    'VALUE_DIFF': '值差异（同主键）',
    'ROW_ADD': '新增行',
    'COL_GAIN': '本地多列',
    'NEW': '本地新表',
    'COL_LOSS': '🔴 本地列数少于线上（覆盖会丢列）',
    'ROW_LOSS': '🔴 线上有仓库没有的主键（覆盖会删线上数据）',
    'HEADER_DIFF': '🔴 表头字段名/顺序不一致（覆盖会串列）',
    'REMOTE_ONLY': '🔴 线上有、本地没有（本工具永不删线上表）',
    'REVIEW': '🔴 人工复核名单（语义需产品确认）',
    'PARSE_FAIL': '🔴 解析失败（列数不齐）',
    'NIL_CELLS': '🔴 数值列空值写成 nil（服务端解析会抛异常）',
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


def ssh(script, timeout=SSH_TIMEOUT):
    return run(['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', SSH_HOST, script],
               timeout=timeout)


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


def remote_path(remote_dir: str) -> str:
    """相对目录（conf/server）→ 线上绝对路径。"""
    return remote_dir if remote_dir.startswith('/') else '%s/%s' % (REMOTE_BASE, remote_dir)


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
        # 零值填充行：线上 txt 里有一批这类尾巴，不算内容
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


def classify(local: Table, remote: Table, name: str):
    """返回 (verdict, notes)。verdict 见 VERDICT_TEXT。"""
    notes = []
    if local.err:
        return 'PARSE_FAIL', ['本地：' + local.err]
    if remote.err:
        return 'PARSE_FAIL', ['线上：' + remote.err]

    lh, rh = local.header, remote.header
    if lh == rh:
        pass
    elif lh and rh and lh == rh[:len(lh)] and len(lh) < len(rh):
        return 'COL_LOSS', ['线上 %d 列 / 本地 %d 列，本地缺列：%s'
                            % (len(rh), len(lh), ', '.join(rh[len(lh):]))]
    elif lh and rh and rh == lh[:len(rh)] and len(lh) > len(rh):
        notes.append('本地多列：%s（服务端按字段名反射注入，需确认 S*Config 已有该字段）'
                     % ', '.join(lh[len(rh):]))
    else:
        diff = [(i, a, b) for i, (a, b) in enumerate(zip(lh, rh)) if a != b]
        return 'HEADER_DIFF', ['表头字段名/顺序不一致，首个差异：%s' % (diff[:3],)]

    if name in REVIEW_ONLY:
        notes.insert(0, REVIEW_ONLY[name])

    lost = [k for k in remote.rows if k not in local.rows]
    if lost:
        sample = ', '.join(lost[:6]) + (' …' if len(lost) > 6 else '')
        return 'ROW_LOSS', ['线上有 %d 个主键本地没有（覆盖会删线上数据）：%s' % (len(lost), sample)]

    added = [k for k in local.rows if k not in remote.rows]
    changed_rows, changed_cells, common = [], 0, 0
    for key, lrow in local.rows.items():
        rrow = remote.rows.get(key)
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
    if local.dup_keys or remote.dup_keys:
        notes.append('重复主键：本地 %d / 线上 %d（只比首次出现）' % (local.dup_keys, remote.dup_keys))

    if name in REVIEW_ONLY:
        return 'REVIEW', notes
    if changed_rows:
        verdict = 'VALUE_DIFF'
    elif added:
        verdict = 'ROW_ADD'
    elif local.sig == remote.sig:
        return 'SAME', ['归一化后逐格一致（字节差异来自换行/尾随空列/0.0/nil 之类）']
    else:
        verdict = 'COL_GAIN'

    nil = count_nil_numeric(local)
    if nil:
        notes.insert(0, '本地数值列有 %d 个空值写成 "nil"：服务端 parseFiledInt 直接 Integer.parseInt '
                        '⇒ NumberFormatException，整表加载中断（2026-10-21 实测）。'
                        '这份产物是导出器修复前的旧表，先重跑导表再同步' % nil)
        return 'NIL_CELLS', notes
    return verdict, notes


# ---------------------------------------------------------------------------
# 线上交互
# ---------------------------------------------------------------------------
def remote_md5s(remote_dir: str) -> dict:
    return remote_md5s_multi([remote_dir]).get(remote_dir, {})


def remote_md5s_multi(remote_dirs) -> dict:
    """一次 ssh 拿多个目录的 md5 清单（每次 ssh 握手在本机要几秒，别逐目录调）。"""
    parts = []
    for d in remote_dirs:
        parts.append('echo "@@%s"' % d)
        parts.append('cd %s 2>/dev/null && md5sum *.txt 2>/dev/null' % shlex.quote(remote_path(d)))
    p = ssh('; '.join(parts))
    out = {d: {} for d in remote_dirs}
    cur = None
    for line in p.stdout.splitlines():
        if line.startswith('@@'):
            cur = line[2:].strip()
            continue
        bits = line.split()
        if cur in out and len(bits) == 2:
            out[cur][bits[1]] = bits[0]
    return out


def ensure_snapshot(remote_dir: str, md5map: dict, refresh=False):
    """把线上某个配置目录整包拉到本地缓存（一次 tar 传输，按 md5 清单判新旧）。"""
    # 🔴 缓存键必须带上 remote_base：否则拿 --remote-base 指向测试目录跑一次，
    #    会把生产快照缓存覆盖掉（实测踩过，下次比对直接解包失败）
    key = '%s_%s' % (md5_bytes((REMOTE_BASE + '|' + remote_dir).encode())[:8],
                     remote_dir.strip('/').replace('/', '_'))
    snap = CACHE_DIR / ('snap_' + key)
    index = snap / '.md5index.json'
    if not refresh and index.exists():
        try:
            if json.loads(index.read_text(encoding='utf-8')) == md5map:
                return snap, True
        except (json.JSONDecodeError, OSError):
            pass

    log('   下载线上快照 %s（%d 个 txt）…' % (remote_dir, len(md5map)))
    script = 'tar czf - -C %s %s' % (shlex.quote(REMOTE_BASE), shlex.quote(remote_dir))
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
        return None, False

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
        return None, False

    src = tmp / remote_dir
    if not src.is_dir():
        log('   ⚠ 解包后找不到目录：%s' % src)
        return None, False
    shutil.rmtree(snap, ignore_errors=True)
    shutil.move(str(src), str(snap))
    shutil.rmtree(tmp, ignore_errors=True)
    (snap / '.md5index.json').write_text(json.dumps(md5map, ensure_ascii=False), encoding='utf-8')
    return snap, False


def backup_remote(dirs, dest: Path) -> bool:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    script = 'tar czf - -C %s %s' % (shlex.quote(REMOTE_BASE),
                                     ' '.join(shlex.quote(d) for d in dirs))
    with open(dest, 'wb') as f:
        p = subprocess.run(['ssh', '-o', 'BatchMode=yes', SSH_HOST, script],
                           stdout=f, stderr=subprocess.PIPE, timeout=SSH_TIMEOUT)
    if p.returncode != 0 or dest.stat().st_size < 1024:
        return False
    return run(['tar', 'tzf', str(dest)]).returncode == 0   # 备份必须可解


def push_one(local_path: Path, remote_dir: str, name: str) -> bool:
    p = run(['scp', '-q', str(local_path), '%s:%s/%s' % (SSH_HOST, remote_path(remote_dir), name)])
    return p.returncode == 0


def restart_server() -> bool:
    log('==> 重启游戏服（RESTART-GAMESERVER.sh）')
    p = ssh('bash %s/RESTART-GAMESERVER.sh 2>&1 | tail -30' % REMOTE_BASE, timeout=600)
    log(p.stdout.strip() or p.stderr.strip())
    return p.returncode == 0


# ---------------------------------------------------------------------------
# 基线状态
# ---------------------------------------------------------------------------
def load_state() -> dict:
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text(encoding='utf-8'))
        except (json.JSONDecodeError, OSError):
            log('⚠ 基线文件损坏，按首次运行处理：%s' % STATE_FILE)
    return {}


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


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
def main() -> int:
    global REMOTE_BASE, STATE_FILE
    ap = argparse.ArgumentParser(description='导表服务端同步（增量 + 结构体检）',
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--local-dir', default=str(DEFAULT_LOCAL_DIR), help='导表产物目录（默认影子目录）')
    ap.add_argument('--remote-dir', action='append', default=None,
                    help='线上配置目录（相对 %s，可重复；默认两份都推）' % REMOTE_BASE)
    ap.add_argument('--mirror-dir', default=str(DEFAULT_MIRROR_DIR), help='本地真实服务端仓配置目录')
    ap.add_argument('--no-mirror-repo', action='store_true', help='不写本地服务端仓')
    ap.add_argument('--apply', action='store_true', help='真正写线上（默认只体检）')
    ap.add_argument('--only', default='', help='只处理这些表（逗号分隔，忽略基线）')
    ap.add_argument('--include-drift', action='store_true',
                    help='把所有与线上不同的表纳入候选（危险：会带上未发布内容）')
    ap.add_argument('--force', action='store_true', help='点名表即使体检红灯也推（仅配合 --only）')
    ap.add_argument('--restart', action='store_true', help='推完重启游戏服')
    ap.add_argument('--strict', action='store_true', help='存在被拦下的表时退出码 4')
    ap.add_argument('--yes', action='store_true', help='跳过危险操作的交互确认')
    ap.add_argument('--status', action='store_true', help='只打印基线/候选，不做体检')
    ap.add_argument('--state-file', default=str(STATE_FILE), help='基线文件（默认 %s）' % STATE_FILE)
    ap.add_argument('--remote-base', default=REMOTE_BASE, help='线上服务端根目录（默认 %s）' % REMOTE_BASE)
    ap.add_argument('--refresh', action='store_true', help='强制重新下载线上快照')
    ap.add_argument('--fix-nil', action='store_true',
                    help='推送前把数值列的 nil 就地改写成 null（等价于重跑一次导表，会改 git 工作区文件）')
    ap.add_argument('--json-out', default='', help='额外写一份结构化结果 JSON')
    args = ap.parse_args()

    REMOTE_BASE = args.remote_base.rstrip('/') or '/'
    STATE_FILE = Path(args.state_file).resolve()
    local_dir = Path(args.local_dir).resolve()
    mirror_dir = Path(args.mirror_dir).resolve()
    remote_dirs = args.remote_dir or DEFAULT_REMOTE_DIRS
    primary = remote_dirs[0]

    log('=' * 78)
    log('导表服务端同步  %s' % time.strftime('%Y-%m-%d %H:%M:%S'))
    log('  本地导出：%s' % local_dir)
    log('  线上服  ：%s:%s  (%s)' % (SSH_HOST, REMOTE_BASE, ', '.join(remote_dirs)))
    log('  基线文件：%s' % STATE_FILE)
    log('=' * 78)

    if not local_dir.is_dir():
        log('✗ 本地导出目录不存在：%s' % local_dir)
        return 2
    local_files = {p.name: p for p in sorted(local_dir.glob('*.txt'))}
    if not local_files:
        log('✗ 本地导出目录里没有 txt：%s' % local_dir)
        return 2
    log('本地 txt：%d 个，解析中 …' % len(local_files))
    local_tables = {}
    for name, p in local_files.items():
        local_tables[name] = parse_txt(name, read_text(p))
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

    # ---- 线上快照 --------------------------------------------------------
    log('拉取线上 md5 清单 …')
    remote_md5 = remote_md5s_multi(remote_dirs)
    for rd in remote_dirs:
        m = remote_md5.get(rd) or {}
        if not m:
            log('✗ 读不到线上目录 %s:%s（ssh 别名或权限问题？）' % (SSH_HOST, rd))
            return 2
        log('  %-20s %d 个 txt' % (rd, len(m)))

    snap, cached = ensure_snapshot(primary, remote_md5[primary], refresh=args.refresh)
    if snap is None:
        log('✗ 线上快照获取失败，无法做语义比对')
        return 2
    log('  快照：%s（%s）' % (snap, '命中缓存' if cached else '刚下载'))

    remote_tables = {}
    for name, md in remote_md5[primary].items():
        rp = snap / name
        if not rp.exists():
            continue
        if md5_file(rp) != md:
            log('  ⚠ %s 快照与线上 md5 不符（线上刚被改过？加 --refresh 重试）' % name)
            continue
        remote_tables[name] = parse_txt(name, read_text(rp))
    log('线上 txt 解析完成：%d 张' % len(remote_tables))

    # ---- 基线 ------------------------------------------------------------
    state = load_state()
    tables = state.setdefault('tables', {})
    first_run = not tables

    changed = set()
    src = ''
    if args.only:
        changed = _names(args.only)
        src = '--only'
    elif not first_run:
        for name, lt in local_tables.items():
            rec = tables.get(name)
            if rec is None or rec.get('sig') != lt.sig:
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
        changed = {n for n in local_tables if n in remote_tables
                   and local_tables[n].sig != remote_tables[n].sig}
        src = '--include-drift 全量漂移'

    # ---- 全量体检（顺带产出漂移清单）------------------------------------
    all_results = {}
    for name, lt in local_tables.items():
        rt = remote_tables.get(name)
        if rt is None:
            nil = count_nil_numeric(lt)
            all_results[name] = {
                'table': name,
                'verdict': 'NIL_CELLS' if nil else 'NEW',
                'notes': (['本地数值列有 %d 个 "nil" 空值，先重跑导表' % nil] if nil
                          else ['线上没有这张表（新增）']),
                'rows': '', 'pushable': not nil}
            continue
        verdict, notes = classify(lt, rt, name)
        all_results[name] = {'table': name, 'verdict': verdict, 'notes': notes,
                             'rows': '%d→%d' % (len(rt.rows), len(lt.rows)),
                             'pushable': verdict in OK_VERDICTS}
    for name in remote_md5[primary]:
        if name not in local_tables:
            all_results[name] = {'table': name, 'verdict': 'REMOTE_ONLY',
                                 'notes': ['线上有、本地导出没有：可能纯后端表或已下线表，本工具不删线上文件'],
                                 'rows': '', 'pushable': False}

    drift = {n for n, r in all_results.items() if r['verdict'] != 'SAME'}
    remote_only = {n for n, r in all_results.items() if r['verdict'] == 'REMOTE_ONLY'}

    log('')
    log('基线：%s（记录 %d 张）｜候选来源：%s → %d 张'
        % ('首次运行' if first_run else '已存在', len(tables), src, len(changed)))
    log('线上漂移（语义）：%d 张｜线上独有：%d 张（永不删除）' % (len(drift), len(remote_only)))

    missing = sorted(n for n in changed if n not in all_results)
    if missing:
        log('⚠ 找不到这些表（检查表名/是否已导出）：%s' % ', '.join(missing))

    if args.status:
        log('')
        for n in sorted(changed):
            if n in all_results:
                log('  %-40s %s' % (n, VERDICT_TEXT.get(all_results[n]['verdict'], '')))
        return 0

    results = [all_results[n] for n in sorted(changed) if n in all_results]
    pushable = [r for r in results if r['pushable']]
    blocked = [r for r in results if r['verdict'] in BLOCK_VERDICTS]

    if args.force and args.only:
        forced = _names(args.only)
        for r in results:
            if r['table'] in forced and not r['pushable']:
                r['pushable'] = True
                r['notes'].append('⚠ --force 点名强推')
                pushable.append(r)
        blocked = [r for r in results if r['verdict'] in BLOCK_VERDICTS and not r['pushable']]

    # ---- 打印 ------------------------------------------------------------
    log('')
    log('-' * 96)
    log('%-34s %-8s %-12s %s' % ('表', '判定', '行数(线上→本地)', '说明'))
    log('-' * 96)
    for r in results:
        log('%-34s %-8s %-12s %s' % (r['table'], r['verdict'], r['rows'],
                                     (r['notes'][0] if r['notes'] else '')[:64]))
    log('-' * 96)
    log('候选 %d 张：可推 %d / 拦下 %d' % (len(results), len(pushable), len(blocked)))

    if drift and not changed:
        log('')
        log('ℹ 本次没检测到改动，但线上与仓库有 %d 张语义漂移（多为未发布内容，不自动推）：' % len(drift))
        stat = {}
        for n in drift:
            stat[all_results[n]['verdict']] = stat.get(all_results[n]['verdict'], 0) + 1
        for v, c in sorted(stat.items(), key=lambda kv: -kv[1]):
            log('    %-12s %3d 张  %s' % (v, c, VERDICT_TEXT.get(v, '')))
        log('    明细见报告；要推具体几张用 --only 表名（逗号分隔）')

    # ---- 落地 ------------------------------------------------------------
    if not args.apply:
        if pushable:
            log('')
            log('（体检模式，未写线上。要推上面「可推」的表：加 --apply）')
        if first_run:
            log('')
            log('首次运行只建基线，不推任何表。下次改表导表后会自动只推改动的那几张。')
            _seed(tables, local_tables, remote_tables)
            save_state(state)
            _write_report(all_results, [], [], [], drift, None, remote_dirs)
        return 0

    if not pushable:
        log('')
        log('没有可推的表，线上保持不变。')
        if first_run:
            _seed(tables, local_tables, remote_tables)
            save_state(state)
            log('基线已建立（%d 张表）。' % len(local_tables))
            _write_report(all_results, [], [], blocked, drift, None, remote_dirs)
        return 0

    if args.include_drift and not args.yes and not sys.stdin.isatty():
        log('')
        log('✗ --include-drift 会把所有历史漂移（含未发布内容）推到线上，非交互环境必须加 --yes')
        return 5

    log('')
    log('开始推送 %d 张表 …' % len(pushable))
    backup = BACKUP_DIR / ('conf_server_%s.tar.gz' % time.strftime('%Y%m%d_%H%M%S'))
    log('==> 备份线上配置目录 → %s' % backup)
    if not backup_remote(remote_dirs, backup):
        log('✗ 线上备份失败，中止（不做没有回滚点的推送）')
        return 3
    mb = backup.stat().st_size / 1048576
    log('    备份完成 %s（已校验可解包）' % ('%.1f MB' % mb if mb >= 1 else '%.0f KB' % (mb * 1024)))

    pushed, failed = [], []
    for r in pushable:
        name = r['table']
        lp = local_files[name]
        ok = True
        for rd in remote_dirs:
            if not push_one(lp, rd, name):
                ok = False
                log('   ✗ %s → %s 传输失败' % (name, rd))
        if ok:
            pushed.append(name)
            log('   ✓ %s' % name)
        else:
            failed.append(name)

    log('==> 双向 md5 校验')
    rc = 0
    after = remote_md5s_multi(remote_dirs)
    for rd in remote_dirs:
        now = after.get(rd) or {}
        bad = [n for n in pushed if now.get(n) != local_md5[n]]
        if bad:
            log('   ✗ %s 校验不过：%s' % (rd, ', '.join(bad)))
            rc = 3
        else:
            log('   ✓ %s  %d/%d 一致' % (rd, len(pushed), len(pushed)))

    # 推送后把本地快照对齐到线上现状，下次体检不用再下 20MB
    if pushed:
        touched = 0
        for name in pushed:
            try:
                (snap / name).write_bytes(local_files[name].read_bytes())
                touched += 1
            except OSError:
                pass
        if touched == len(pushed) and primary in after:
            (snap / '.md5index.json').write_text(json.dumps(after[primary], ensure_ascii=False),
                                                 encoding='utf-8')

    if not args.no_mirror_repo and mirror_dir.is_dir():
        log('==> 同步本地服务端仓：%s' % mirror_dir)
        copied = 0
        for name in pushed:
            try:
                (mirror_dir / name).write_bytes(local_files[name].read_bytes())
                copied += 1
            except OSError as e:
                log('   ⚠ %s 写入失败：%s' % (name, e))
        log('   ✓ %d 张（未提交，记得在服务端仓 git add/commit）' % copied)
    elif not args.no_mirror_repo:
        log('⚠ 本地服务端仓目录不存在，跳过：%s' % mirror_dir)

    now_ts = time.strftime('%Y-%m-%d %H:%M:%S')
    # 与线上本来就一致的表也把基线对齐，否则它每次都会以「候选」身份重复出现
    same_now = {r['table'] for r in results if r['verdict'] == 'SAME'}
    for name, lt in local_tables.items():
        rec = tables.get(name) or {}
        if name in pushed:
            rec = {'sig': lt.sig, 'synced_at': now_ts}
        elif name in same_now:
            rec = {'sig': lt.sig, 'synced_at': 'same-as-remote'}
        else:
            rec.setdefault('sig', lt.sig)
            rec.setdefault('synced_at', 'baseline')
        tables[name] = rec
    state['version'] = 1
    state['last_sync_at'] = now_ts
    state['remote'] = '%s:%s' % (SSH_HOST, REMOTE_BASE)
    save_state(state)
    log('==> 基线已更新：%s' % STATE_FILE)

    _write_report(all_results, pushed, failed, blocked, drift, backup, remote_dirs)
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(list(all_results.values()), ensure_ascii=False, indent=2),
                                       encoding='utf-8')

    if failed:
        log('')
        log('✗ %d 张传输失败：%s' % (len(failed), ', '.join(failed)))
        rc = 3
    if blocked:
        log('')
        log('🔴 被拦下 %d 张（未推）：' % len(blocked))
        for r in blocked:
            log('   %-34s %s' % (r['table'], VERDICT_TEXT.get(r['verdict'], r['verdict'])))
        if args.strict:
            rc = rc or 4

    if pushed and args.restart:
        if not restart_server():
            log('✗ 重启失败，请手工处理')
            rc = rc or 3
    elif pushed:
        log('')
        log('⚠ 表已落盘但游戏服未重启，新数值要重启后才生效：')
        log('    ssh %s "bash %s/RESTART-GAMESERVER.sh"' % (SSH_HOST, REMOTE_BASE))

    log('')
    log('完成：推了 %d 张，失败 %d 张，拦下 %d 张。' % (len(pushed), len(failed), len(blocked)))
    return rc


def _names(raw: str) -> set:
    """'A,B' → {'A.txt','B.txt'}（表名可不带扩展名）。"""
    out = set()
    for n in raw.split(','):
        n = n.strip()
        if n:
            out.add(n if n.endswith('.txt') else n + '.txt')
    return out


def _seed(tables: dict, local_tables: dict, remote_tables: dict):
    for name, lt in local_tables.items():
        tables[name] = {'sig': lt.sig, 'synced_at': 'baseline'}


def _write_report(all_results, pushed, failed, blocked, drift, backup, remote_dirs):
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    path = REPORT_DIR / ('sync_%s.md' % time.strftime('%Y%m%d_%H%M%S'))
    lines = ['# 导表服务端同步报告 %s' % time.strftime('%Y-%m-%d %H:%M:%S'), '',
             '| 项 | 值 |', '|---|---|',
             '| 线上 | `%s:%s` |' % (SSH_HOST, REMOTE_BASE),
             '| 推送目录 | %s |' % ', '.join(remote_dirs),
             '| 备份 | %s |' % (backup.name if backup else '（未写线上，无备份）'),
             '| 已推 | %d 张 |' % len(pushed),
             '| 失败 | %d 张 |' % len(failed),
             '| 拦下 | %d 张 |' % len(blocked),
             '| 语义漂移（未推） | %d 张 |' % len(drift), '',
             '## 语义漂移明细', '', '| 表 | 判定 | 行数(线上→本地) | 说明 |', '|---|---|---|---|']
    for name in sorted(drift):
        r = all_results[name]
        lines.append('| `%s` | %s | %s | %s |' % (name, r['verdict'], r['rows'],
                                                  '<br>'.join(r['notes']).replace('|', '\\|')))
    if pushed:
        lines += ['', '## 本次推送', ''] + ['- `%s`' % n for n in pushed]
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    log('报告：%s' % path)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        log('\n已中断')
        sys.exit(130)
