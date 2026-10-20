#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""只读：BI 流水(jl_item) 按 uid 汇总 item16(钻石)/item3(英雄经验)/item17(经验)，30 天窗口。"""
import glob, os, re, sys
from collections import defaultdict

BASE = '/home/java/gameserver/assets/log/jl_item'
UIDS = [int(x) for x in sys.argv[1].split(',')]
reason_re = re.compile(r'the reason=(\d+),\s*itemap=\{([^}]*)\}')
uid_re = re.compile(r'uid=(\d+)')

agg = {u: defaultdict(lambda: [0, 0]) for u in UIDS}
span = {u: ['', ''] for u in UIDS}
files = 0

for d in sorted(glob.glob(os.path.join(BASE, '2026-*'))):
    for f in sorted(glob.glob(os.path.join(d, 'item*.log'))):
        files += 1
        try:
            fh = open(f, 'r', errors='ignore')
        except Exception:
            continue
        for line in fh:
            if 'addItem' not in line:
                continue
            mu = uid_re.search(line)
            if not mu:
                continue
            uid = int(mu.group(1))
            if uid not in agg:
                continue
            mr = reason_re.search(line)
            if not mr:
                continue
            ts = line[:23]
            if not span[uid][0]:
                span[uid][0] = ts
            span[uid][1] = ts
            reason = int(mr.group(1))
            for pair in mr.group(2).split(','):
                pair = pair.strip()
                if '=' not in pair:
                    continue
                k, v = pair.split('=')
                try:
                    k = int(k); v = int(v)
                except ValueError:
                    continue
                a = agg[uid][(k, reason)]
                a[0] += v
                a[1] += 1
        fh.close()

print('files=%d' % files)
for uid in UIDS:
    rows = agg[uid]
    tot = defaultdict(int)
    grants = defaultdict(int)
    for (k, r), (s, c) in rows.items():
        tot[k] += s
        grants[k] += c
    print('\n=== uid=%d  流水窗口 %s ~ %s ===' % (uid, span[uid][0] or '-', span[uid][1] or '-'))
    print('  钻石item16 合计 %d（%d 笔）  英雄经验item3 合计 %d  经验item17 合计 %d' % (
        tot.get(16, 0), grants.get(16, 0), tot.get(3, 0), tot.get(17, 0)))
    if grants.get(16):
        parts = sorted([(r, s, c) for (k, r), (s, c) in rows.items() if k == 16],
                       key=lambda x: -x[1])
        print('  钻石来源 reason: ' + ', '.join('r%d=%d(%d笔)' % p for p in parts))
    if grants.get(28):
        print('  🔴 reason=28(GM_REWARD) %d 笔，item 分布: %s' % (
            grants[28], ', '.join('%d:%d' % (k, s) for (k, r), (s, c) in rows.items() if r == 28)))
