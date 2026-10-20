#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""道具/货币 id ↔ 名称：**唯一的权威来源是服务端配置表**。

为什么单独一层：2026-10-18 的误封把 `itemMap["3"]`（英雄经验）当成钻石，
并拿 `itemMap["17"]`（玩家经验，中位数 200）当「钻石基线」，得出「62.8 万倍」。
根因不是判据松，而是「id → 名字」被写死在扫描脚本里、且从未与配置表核对过。

权威映射（`conf/server/ItemConfig.txt` 的 `Name` 列是 langId，去 `Language.txt` 查中文）：
    3  → 英雄经验      14 → 金钱        16 → 钻石
    17 → 玩家经验      79 → 挂机产出道具

用法：
    names, src = load_names(remote)     # remote 可省略（只用本地 conf）
    label(16, names)                    # → '钻石'
"""
import os

# 兜底：仅在读不到配置表时使用。**新增 id 请改配置表，不要改这里。**
FALLBACK = {
    3: '英雄经验',
    14: '金钱',
    16: '钻石',
    17: '经验',          # 玩家等级累计经验（表名就是「经验」）
    19: '紫晶卡',
    20: '会员招募卡',
    79: '情报',
}

# 关键货币常量（名字来自配置表，id 是服务端 itemMap 的键）
DIAMOND = 16
GOLD = 14
HERO_EXP = 3
PLAYER_EXP = 17
CURRENCY_IDS = (3, 4, 7, 8, 14, 16, 17, 19, 20, 79)

REMOTE_CONF = '/home/java/gameserver/conf/server'

# 本地 conf 的候选目录（相对本文件向上找仓库根）
_LOCAL_CANDIDATES = (
    os.environ.get('GS_CONF_DIR') or '',
    'TimeSpaceServer/skzc/home/java/gameserver/conf/server',
    'TimeSpaceServer/Server_x1tag1.2.2/server_game/conf/server',
)

_CACHE = {}


def _decode(raw):
    for enc in ('utf-8', 'utf-8-sig', 'gbk'):
        try:
            return raw.decode(enc)
        except (UnicodeDecodeError, LookupError):
            continue
    return raw.decode('utf-8', 'replace')


def _read_local(conf_dir):
    item_p = os.path.join(conf_dir, 'ItemConfig.txt')
    lang_p = os.path.join(conf_dir, 'Language.txt')
    if not (os.path.isfile(item_p) and os.path.isfile(lang_p)):
        return None
    with open(item_p, 'rb') as fh:
        item = _decode(fh.read())
    with open(lang_p, 'rb') as fh:
        lang = _decode(fh.read())
    return item, lang


def _read_remote(remote):
    try:
        item = remote.read_file('%s/ItemConfig.txt' % REMOTE_CONF, limit_bytes=8 << 20)
        lang = remote.read_file('%s/Language.txt' % REMOTE_CONF, limit_bytes=8 << 20)
    except Exception:
        return None
    if not item or not lang:
        return None
    return item, lang


def parse_language(text):
    """langId → 中文名。表头两行（列名 + 类型），列序 id/Chinese/English/Japanese/Korean。"""
    out = {}
    for i, line in enumerate(text.splitlines()):
        if i < 2 or not line.strip():
            continue
        cols = line.split('\t')
        if len(cols) < 2:
            continue
        try:
            out[int(cols[0])] = cols[1].strip()
        except ValueError:
            continue
    return out


def parse_item_config(text):
    """itemId → 中文名（Name 列是 langId，查不到就当没有）。"""
    lang_ids = {}
    for i, line in enumerate(text.splitlines()):
        if i < 2 or not line.strip():
            continue
        cols = line.split('\t')
        if len(cols) < 2:
            continue
        try:
            iid, name = int(cols[0]), int(cols[1])
        except ValueError:
            continue
        lang_ids[iid] = name
    return lang_ids


def _repo_root():
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.abspath(os.path.join(here, '..', '..'))


def load_names(remote=None, verbose=False):
    """返回 (names: {item_id: 中文名}, source: 'local'|'remote'|'fallback')。

    读表只做一次（进程内缓存）；fallback 不缓存，下次调用还会重试读表。
    """
    if _CACHE.get('names'):
        return _CACHE['names'], _CACHE['source']
    root = _repo_root()
    for cand in _LOCAL_CANDIDATES:
        if not cand:
            continue
        conf_dir = cand if os.path.isabs(cand) else os.path.join(root, cand)
        got = _read_local(conf_dir)
        if got:
            names = _build(*got)
            if verbose:
                print('[currency] 本地配置表：%s → %d 项' % (conf_dir, len(names)))
            _CACHE.update(names=names, source='local')
            return names, 'local'
    if remote is not None:
        got = _read_remote(remote)
        if got:
            names = _build(*got)
            if verbose:
                print('[currency] 远端配置表：%s → %d 项' % (REMOTE_CONF, len(names)))
            _CACHE.update(names=names, source='remote')
            return names, 'remote'
    if verbose:
        print('[currency] ⚠️ 读不到配置表，退回内置兜底（可能与线上不一致）')
    return dict(FALLBACK), 'fallback'


def _build(item_text, lang_text):
    lang = parse_language(lang_text)
    ids = parse_item_config(item_text)
    names = {}
    for iid, lang_id in ids.items():
        name = lang.get(lang_id)
        if name:
            names[iid] = name
    if not names:                      # 表结构变了：至少保证关键货币不空
        return dict(FALLBACK)
    for iid, name in FALLBACK.items():  # 兜底补齐表里缺的关键项
        names.setdefault(iid, name)
    return names


def label(item_id, names=None, with_id=True):
    """`label(16)` → '钻石(16)'。names 为 None 时用内置兜底。"""
    names = names or FALLBACK
    name = names.get(int(item_id)) or '未知道具'
    return '%s(%d)' % (name, item_id) if with_id else name


def describe(profile, names=None):
    """把 profile 里的货币字段拼成人话，顺序固定，便于对照日志。"""
    names = names or FALLBACK
    parts = []
    for key, iid in (('diamond', DIAMOND), ('gold', GOLD),
                     ('heroExp', HERO_EXP), ('exp', PLAYER_EXP)):
        if key in profile:
            parts.append('%s=%s' % (label(iid, names, with_id=False), _fmt(profile[key])))
    return '  '.join(parts)


def _fmt(v):
    try:
        return '{:,}'.format(int(v))
    except (TypeError, ValueError):
        return str(v)


if __name__ == '__main__':
    import sys
    n, src = load_names(verbose=True)
    print('source=%s  条目=%d' % (src, len(n)))
    for iid in CURRENCY_IDS:
        print('  item%-3d %s' % (iid, n.get(iid, '未知道具')))
    sys.exit(0 if src != 'fallback' else 1)
