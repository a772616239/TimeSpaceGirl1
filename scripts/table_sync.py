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

  1. **只推本次导表真正改过的表** —— 与上次同步基线比对；没有基线时用
     `git status` 的工作区差异当基线（影子目录在 git 里），第一次跑只建基线不推表。
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
    python3 scripts/table_sync.py --status                 # 只打印基线与线上概况
    python3 scripts/table_sync.py --apply --restart        # 推完重启游戏服

退出码：0 正常 / 2 参数或环境错误 / 3 同步失败（传输或校验不过）
       4 存在被拦下的表（仅 --strict 时）/ 5 需要 --yes 但未提供

依赖：本机 ssh 已配置 Host gs（~/.ssh/config + tencent-gameserver.pem），
      与 scripts/server_health_check.py 共用同一个别名。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# 配置
# ---------------------------------------------------------------------------
SSH_HOST = os.environ.get('TSG_TABLE_SSH_HOST', 'gs')
SSH_TIMEOUT = 180

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
CACHE_DIR = WORK_DIR / 'remote_cache'

# 人工复核名单：结构体检可能全绿，但语义上必须产品确认才能动线上
REVIEW_ONLY = {
    'Language.txt': '多语言表：线上多 Korean 列，且英文/日文有数千行内容变动，需单独合并',
    'MultiLanguage.txt': '线上有仓库没有的 id（10301），需确认',
    'EncourageTaskConfig.txt': '线上独有 25 条任务（16001~16025），覆盖即删除',
    'EncouragePlanConfig.txt': '线上独有 id=16',
    'RewardItemConfig.txt': '仓库多 103 个 990000+ 段道具，属未发布内容',
}

# 判定等级 → (是否可自动推, 说明)
OK_VERDICTS = {'SAME', 'VALUE_DIFF', 'ROW_ADD', 'COL_GAIN', 'NEW'}
BLOCK_VERDICTS = {'COL_LOSS', 'ROW_LOSS', 'HEADER_DIFF', 'REMOTE_ONLY', 'REVIEW', 'PARSE_FAIL'}

VERDICT_TEXT = {
    'SAME': '一致',
    'VALUE_DIFF': '值差异（同主键）',
    'ROW_ADD': '新增行',
    'COL_GAIN': '本地多列（服务端按名反射注入，需确认实体类）',
    'NEW': '本地新表',
    'COL_LOSS': '🔴 本地列数少于线上（覆盖会丢列）',
    'ROW_LOSS': '🔴 线上有仓库没有的主键（覆盖会删线上数据）',
    'HEADER_DIFF': '🔴 表头字段名/顺序不一致（覆盖会串列）',
    'REMOTE_ONLY': '🔴 线上有、本地没有（本工具永不删线上表）',
    'REVIEW': '🔴 人工复核名单（语义需产品确认）',
    'PARSE_FAIL': '🔴 解析失败（列数不齐）',
}

# 空值字面量：客户端空串 / 服务端 null（2026-10-21 把 "nil" 改成 "null" 那次的教训）
NULL_TOKENS = {'', 'null', 'nil', 'NULL', 'NIL', 'None', '-'}


# ---------------------------------------------------------------------------
# 基础工具
# ---------------------------------------------------------------------------
def log(msg=''):
    print(msg, flush=True)


def run(cmd, timeout=SSH_TIMEOUT, check=False):
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if check and p.returncode != 0:
        raise RuntimeError('命令失败：%s\n%s' % (' '.join(cmd), p.stderr.strip()))
    return p


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
    """归一化单元格：去空白、空值字面量统一为空、数字去尾零（0.0 == 0）。"""
    s = cell.strip()
    if s in NULL_TOKENS:
        return ''
    # 只对「纯数字 + 可选小数」做归一，避免把 "1.0" 这种字符串配置改掉语义
    try:
        if s.replace('.', '', 1).replace('-', '', 1).isdigit():
            f = float(s)
            if f == int(f):
                return str(int(f))
    except (ValueError, OverflowError):
        pass
    return s


# ---------------------------------------------------------------------------
# 表解析与体检
# ---------------------------------------------------------------------------
class Table:
    __slots__ = ('name', 'header', 'types', 'rows', 'dup_keys', 'padding', 'md5', 'err')

    def __init__(self, name):
        self.name = name
        self.header = []
        self.types = []
        self.rows = {}
        self.dup_keys = 0
        self.padding = 0
        self.md5 = ''
        self.err = ''


def parse_txt(name: str, text: str) -> Table:
    t = Table(name)
    lines = [ln.rstrip('\r') for ln in text.split('\n')]
    while lines and not lines[-1].strip():
        lines.pop()
    if len(lines) < 2:
        t.err = '行数不足 2（连表头都不完整）'
        return t

    def cells_of(line):
        cs = [c.strip() for c in line.split('\t')]
        while cs and cs[-1] == '':
            cs.pop()
        return cs

    t.header = cells_of(lines[0])
    t.types = cells_of(lines[1])

    width = len(t.header)
    for idx, line in enumerate(lines[2:], start=3):
        if not line.strip():
            continue
        cs = cells_of(line)
        if len(cs) != width:
            t.err = '第 %d 行有 %d 列，表头 %d 列（列数不齐，解析风险）' % (idx, len(cs), width)
            return t
        key = norm_cell(cs[0])
        # 零值填充行：线上 408 个 txt 里有 95 行这类尾巴，不算内容
        if key == '' or (key == '0' and all(norm_cell(c) in ('', '0') for c in cs[1:])):
            t.padding += 1
            continue
        if key in t.rows:
            t.dup_keys += 1
            continue
        t.rows[key] = cs
    return t


def classify(local: Table, remote: Table, name: str) -> tuple[str, list[str]]:
    """返回 (verdict, 说明列表)。verdict 见 VERDICT_TEXT。"""
    notes = []
    if name in REVIEW_ONLY:
        return 'REVIEW', [REVIEW_ONLY[name]]
    if local.err:
        return 'PARSE_FAIL', ['本地：' + local.err]
    if remote.err:
        return 'PARSE_FAIL', ['线上：' + remote.err]

    lh, rh = local.header, remote.header
    if lh == rh:
        pass
    elif lh and rh and lh == rh[:len(lh)] and len(lh) < len(rh):
        missing = rh[len(lh):]
        return 'COL_LOSS', ['线上 %d 列 / 本地 %d 列，本地缺列：%s' % (len(rh), len(lh), ', '.join(missing))]
    elif lh and rh and rh == lh[:len(rh)] and len(lh) > len(rh):
        notes.append('本地多列：%s（服务端 S*Config 按字段名反射注入，需确认实体类已有该字段）'
                     % ', '.join(lh[len(rh):]))
    else:
        diff = [(i, a, b) for i, (a, b) in enumerate(zip(lh, rh)) if a != b]
        return 'HEADER_DIFF', ['前 %d 个字段名/顺序不一致，首个差异：%s' % (len(diff), diff[:3])]

    lost = [k for k in remote.rows if k not in local.rows]
    added = [k for k in local.rows if k not in remote.rows]
    if lost:
        sample = ', '.join(lost[:6]) + (' …' if len(lost) > 6 else '')
        return 'ROW_LOSS', ['线上有 %d 个主键本地没有（覆盖会删线上数据）：%s' % (len(lost), sample)]

    changed_cells = 0
    changed_rows = []
    common = 0
    for key, lrow in local.rows.items():
        rrow = remote.rows.get(key)
        if rrow is None:
            continue
        common += 1
        n = 0
        for i in range(min(len(lrow), len(rrow))):
            if norm_cell(lrow[i]) != norm_cell(rrow[i]):
                n += 1
        if n:
            changed_cells += n
            changed_rows.append(key)

    if not changed_rows and not added and not notes:
        return 'SAME', ['归一化后逐格一致（字节差异来自换行/尾随空列/0.0 之类）']
    if changed_rows:
        sample = ', '.join(changed_rows[:6]) + (' …' if len(changed_rows) > 6 else '')
        notes.append('%d/%d 行有值变动，共 %d 个单元格（主键样例：%s）'
                     % (len(changed_rows), common, changed_cells, sample))
    if added:
        sample = ', '.join(added[:6]) + (' …' if len(added) > 6 else '')
        notes.append('本地新增 %d 行：%s' % (len(added), sample))
    if local.dup_keys or remote.dup_keys:
        notes.append('重复主键：本地 %d / 线上 %d（只比首次出现）' % (local.dup_keys, remote.dup_keys))
    if local.padding or remote.padding:
        notes.append('零值填充行已忽略：本地 %d / 线上 %d' % (local.padding, remote.padding))

    if changed_rows:
        return 'VALUE_DIFF', notes
    if added:
        return 'ROW_ADD', notes
    return 'COL_GAIN', notes


# ---------------------------------------------------------------------------
# 线上交互
# ---------------------------------------------------------------------------
def remote_path(remote_dir: str) -> str:
    """相对目录（conf/server）→ 线上绝对路径。"""
    return remote_dir if remote_dir.startswith('/') else '%s/%s' % (REMOTE_BASE, remote_dir)


def remote_md5s(remote_dir: str) -> dict:
    script = 'cd %s 2>/dev/null && md5sum *.txt 2>/dev/null' % shlex.quote(remote_path(remote_dir))
    p = ssh(script)
    out = {}
    for line in p.stdout.splitlines():
        parts = line.split()
        if len(parts) == 2:
            out[parts[1]] = parts[0]
    return out


def fetch_remote(remote_dir: str, name: str, want_md5: str) -> Path | None:
    """拉一个线上表到本地缓存（按 md5 命名，重复体检不再下载）。"""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    dest = CACHE_DIR / ('%s__%s' % (want_md5[:12], name))
    if dest.exists() and md5_file(dest) == want_md5:
        return dest
    p = run(['scp', '-q', '%s:%s/%s' % (SSH_HOST, remote_path(remote_dir), name), str(dest)])
    if p.returncode != 0 or not dest.exists():
        log('   ⚠ 拉取失败 %s：%s' % (name, p.stderr.strip()[:200]))
        return None
    if md5_file(dest) != want_md5:
        log('   ⚠ %s 拉取后 md5 不符（线上可能正在改），本次跳过' % name)
        return None
    return dest


def backup_remote(dirs: list[str], dest: Path) -> bool:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    script = 'tar czf - -C %s %s' % (shlex.quote(REMOTE_BASE), ' '.join(shlex.quote(d) for d in dirs))
    with open(dest, 'wb') as f:
        p = subprocess.run(['ssh', '-o', 'BatchMode=yes', SSH_HOST, script],
                           stdout=f, stderr=subprocess.PIPE, timeout=SSH_TIMEOUT)
    if p.returncode != 0 or dest.stat().st_size < 1024:
        return False
    # 备份必须可解，否则等于没备份
    t = run(['tar', 'tzf', str(dest)])
    return t.returncode == 0


def push_one(local_path: Path, remote_dir: str, name: str) -> bool:
    p = run(['scp', '-q', str(local_path), '%s:%s/%s' % (SSH_HOST, remote_path(remote_dir), name)])
    return p.returncode == 0


def restart_server() -> bool:
    log('==> 重启游戏服（RESTART-GAMESERVER.sh）')
    p = ssh('bash %s/RESTART-GAMESERVER.sh 2>&1 | tail -30' % REMOTE_BASE, timeout=300)
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


def git_changed_tables(local_dir: Path) -> set | None:
    """用 git 工作区差异判断「本次导表改过哪些表」；不在 git 里返回 None。"""
    rel = local_dir.relative_to(PROJECT_ROOT).as_posix() if local_dir.is_relative_to(PROJECT_ROOT) else None
    if rel is None:
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
    ap.add_argument('--status', action='store_true', help='只打印基线/线上概况')
    ap.add_argument('--json-out', default='', help='额外写一份结构化结果 JSON')
    args = ap.parse_args()

    local_dir = Path(args.local_dir).resolve()
    mirror_dir = Path(args.mirror_dir).resolve()
    remote_dirs = args.remote_dir or DEFAULT_REMOTE_DIRS

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
    local_md5 = {n: md5_file(p) for n, p in local_files.items()}
    log('本地 txt：%d 个' % len(local_files))

    # ---- 线上快照 --------------------------------------------------------
    log('拉取线上 md5 清单 …')
    remote = {}
    for rd in remote_dirs:
        m = remote_md5s(rd)
        if not m:
            log('✗ 读不到线上目录 %s:%s（ssh 别名或权限问题？）' % (SSH_HOST, rd))
            return 2
        remote[rd] = m
        log('  %-20s %d 个 txt' % (rd, len(m)))
    primary = remote_dirs[0]
    remote_md5 = remote[primary]

    # ---- 基线 ------------------------------------------------------------
    state = load_state()
    tables = state.setdefault('tables', {})
    first_run = not tables

    changed = set()
    bootstrap_src = ''
    if args.only:
        changed = {n.strip() for n in args.only.split(',') if n.strip()}
        bootstrap_src = '--only'
    elif not first_run:
        for name, md in local_md5.items():
            rec = tables.get(name)
            if rec is None or rec.get('local_md5') != md:
                changed.add(name)
        bootstrap_src = '基线差异'
    else:
        git_set = git_changed_tables(local_dir)
        if git_set:
            changed = {n for n in git_set if n in local_md5}
            bootstrap_src = 'git 工作区差异'
        else:
            changed = set()
            bootstrap_src = '首次运行（建基线，不推表）'

    if args.include_drift:
        changed = {n for n in local_md5 if local_md5[n] != remote_md5.get(n)}
        bootstrap_src = '--include-drift 全量漂移'

    drift = {n for n, md in local_md5.items() if remote_md5.get(n) != md}
    remote_only = {n for n in remote_md5 if n not in local_md5}

    log('')
    log('基线状态：%s（%d 张表已记录）' % ('首次运行' if first_run else '已存在', len(tables)))
    log('候选来源：%s → %d 张' % (bootstrap_src, len(changed)))
    log('线上漂移：%d 张本地与线上不同；线上独有 %d 张（永不删除）' % (len(drift), len(remote_only)))

    if args.status:
        log('')
        log('候选表：')
        for n in sorted(changed):
            mark = '一致' if local_md5.get(n) == remote_md5.get(n) else '有差异'
            log('  %-40s %s' % (n, mark))
        return 0

    # ---- 逐表体检 --------------------------------------------------------
    results = []
    for name in sorted(changed):
        lp = local_files.get(name)
        if lp is None:
            continue
        if remote_md5.get(name) == local_md5[name]:
            results.append({'table': name, 'verdict': 'SAME', 'pushable': False,
                            'notes': ['线上已与本地一致，无需推送'], 'rows': '', 'bytes': lp.stat().st_size})
            continue
        if name not in remote_md5:
            results.append({'table': name, 'verdict': 'NEW', 'pushable': True,
                            'notes': ['线上没有这张表（新增）'], 'rows': '', 'bytes': lp.stat().st_size})
            continue

        rpath = fetch_remote(primary, name, remote_md5[name])
        if rpath is None:
            results.append({'table': name, 'verdict': 'PARSE_FAIL', 'pushable': False,
                            'notes': ['线上表拉不下来，本次跳过'], 'rows': '', 'bytes': lp.stat().st_size})
            continue
        lt = parse_txt(name, read_text(lp))
        rt = parse_txt(name, read_text(rpath))
        verdict, notes = classify(lt, rt, name)
        results.append({
            'table': name, 'verdict': verdict,
            'pushable': verdict in OK_VERDICTS,
            'notes': notes,
            'rows': '%d→%d' % (len(rt.rows), len(lt.rows)),
            'bytes': lp.stat().st_size,
        })

    # 线上独有表：只报告，绝不删
    for name in sorted(remote_only):
        results.append({'table': name, 'verdict': 'REMOTE_ONLY', 'pushable': False,
                        'notes': ['线上有、本地导出没有：可能是纯后端表或已下线表，本工具不删除线上文件'],
                        'rows': '', 'bytes': 0})

    pushable = [r for r in results if r['pushable']]
    blocked = [r for r in results if r['verdict'] in BLOCK_VERDICTS]

    if args.force and args.only:
        forced = {n.strip() for n in args.only.split(',') if n.strip()}
        for r in results:
            if r['table'] in forced and not r['pushable']:
                r['pushable'] = True
                r['notes'].append('⚠ --force 点名强推')
                pushable.append(r)
        blocked = [r for r in results if r['verdict'] in BLOCK_VERDICTS and not r['pushable']]

    # ---- 报告 ------------------------------------------------------------
    log('')
    log('-' * 78)
    log('%-34s %-8s %-10s %s' % ('表', '判定', '行数', '说明'))
    log('-' * 78)
    for r in results:
        log('%-34s %-8s %-10s %s' % (r['table'], r['verdict'], r['rows'],
                                     (r['notes'][0] if r['notes'] else '')[:60]))
    log('-' * 78)
    log('可推 %d 张 / 拦下 %d 张 / 线上独有 %d 张' % (len(pushable), len(blocked), len(remote_only)))

    if drift and not changed:
        log('')
        log('ℹ 本次没有检测到改动，但历史漂移 %d 张（多数是未发布内容，不自动推）：' % len(drift))
        for n in sorted(drift)[:12]:
            log('    %s' % n)
        if len(drift) > 12:
            log('    … 另有 %d 张' % (len(drift) - 12))

    # ---- 落地 ------------------------------------------------------------
    rc = 0
    if not args.apply:
        if pushable:
            log('')
            log('（当前是体检模式，未写线上。要推上面「可推」的表：加 --apply）')
        # 体检模式下也把基线对齐到「当前导出」，下次就能精确算出改动
        if first_run:
            log('')
            log('首次运行：%s' % bootstrap_src)
        return 0

    if not pushable:
        log('')
        log('没有可推的表，线上保持不变。')
        if first_run:
            log('基线已建立（%d 张表），下次改表并导表后会自动只推改动的那几张。' % len(local_md5))
            _seed_state(tables, local_md5, remote_md5, changed)
            save_state(state)
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
    log('    备份完成 %.1f MB（已校验可解包）' % (backup.stat().st_size / 1048576))

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

    # ---- 校验 ------------------------------------------------------------
    log('==> 双向 md5 校验')
    for rd in remote_dirs:
        now = remote_md5s(rd)
        bad = [n for n in pushed if now.get(n) != local_md5[n]]
        if bad:
            log('   ✗ %s 校验不过：%s' % (rd, ', '.join(bad)))
            rc = 3
        else:
            log('   ✓ %s  %d/%d 一致' % (rd, len(pushed), len(pushed)))

    # ---- 本地服务端仓 ----------------------------------------------------
    if not args.no_mirror_repo and mirror_dir.is_dir():
        log('==> 同步本地服务端仓：%s' % mirror_dir)
        copied = 0
        for name in pushed:
            dst = mirror_dir / name
            try:
                dst.write_bytes(local_files[name].read_bytes())
                copied += 1
            except OSError as e:
                log('   ⚠ %s 写入失败：%s' % (name, e))
        log('   ✓ %d 张（未提交，记得 git add/commit）' % copied)
    elif not args.no_mirror_repo:
        log('⚠ 本地服务端仓目录不存在，跳过：%s' % mirror_dir)

    # ---- 基线更新 --------------------------------------------------------
    for name in pushed:
        tables[name] = {
            'local_md5': local_md5[name],
            'remote_md5': local_md5[name],
            'synced_at': time.strftime('%Y-%m-%d %H:%M:%S'),
        }
    # 没改的表也补进基线，避免下次被误判成「新增」
    for name, md in local_md5.items():
        tables.setdefault(name, {'local_md5': md, 'remote_md5': remote_md5.get(name, ''),
                                 'synced_at': 'baseline'})
    state['version'] = 1
    state['last_sync_at'] = time.strftime('%Y-%m-%d %H:%M:%S')
    state['remote'] = '%s:%s' % (SSH_HOST, REMOTE_BASE)
    save_state(state)
    log('==> 基线已更新：%s' % STATE_FILE)

    # ---- 报告落盘 --------------------------------------------------------
    _write_report(results, pushed, failed, blocked, drift, backup, remote_dirs)
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')

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


def _seed_state(tables: dict, local_md5: dict, remote_md5: dict, changed: set):
    for name, md in local_md5.items():
        tables[name] = {'local_md5': md, 'remote_md5': remote_md5.get(name, ''),
                        'synced_at': 'baseline'}


def _write_report(results, pushed, failed, blocked, drift, backup, remote_dirs):
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    path = REPORT_DIR / ('sync_%s.md' % time.strftime('%Y%m%d_%H%M%S'))
    lines = ['# 导表服务端同步报告 %s' % time.strftime('%Y-%m-%d %H:%M:%S'), '',
             '| 项 | 值 |', '|---|---|',
             '| 线上 | %s:%s |' % (SSH_HOST, REMOTE_BASE),
             '| 推送目录 | %s |' % ', '.join(remote_dirs),
             '| 备份 | %s |' % (backup.name if backup else '（未写线上，无备份）'),
             '| 已推 | %d 张 |' % len(pushed),
             '| 失败 | %d 张 |' % len(failed),
             '| 拦下 | %d 张 |' % len(blocked),
             '| 历史漂移（未推） | %d 张 |' % len(drift), '',
             '## 逐表判定', '', '| 表 | 判定 | 行数 | 说明 |', '|---|---|---|---|']
    for r in results:
        lines.append('| `%s` | %s | %s | %s |' % (r['table'], r['verdict'], r['rows'],
                                                  '<br>'.join(r['notes']).replace('|', '\\|')))
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    log('报告：%s' % path)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        log('\n已中断')
        sys.exit(130)
