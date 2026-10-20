#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""只读：探险/挂机奖励(reason=1) 的按天笔数 + 任意 60s 窗口最大笔数 + item 明细。

用途：给「Mozart 1 分钟 35 笔」这个原始判据做量化复核（口径必须只取 reason=1，
不能把 reason=2 随机掉落、reason=11 任务奖励混算）。
"""
import glob
import os
import re
import sys
from collections import defaultdict

BASE = '/home/java/gameserver/assets/log/jl_item'
UIDS = [int(x) for x in sys.argv[1].split(',')]
uid_re = re.compile(r'uid=(\d+)')
reason_re = re.compile(r'the reason=(\d+),\s*itemap=\{([^}]*)\}')

per_day = {u: defaultdict(int) for u in UIDS}
per_day_items = {u: defaultdict(lambda: defaultdict(int)) for u in UIDS}
stamps = {u: [] for u in UIDS}
files = 0

for d in sorted(glob.glob(os.path.join(BASE, '2026-*'))):
    for f in sorted(glob.glob(os.path.join(d, 'item*.log'))):
        files += 1
        with open(f, 'r', errors='ignore') as fh:
            for line in fh:
                if 'addItem' not in line:
                    continue
                mu = uid_re.search(line)
                if not mu:
                    continue
                uid = int(mu.group(1))
                if uid not in per_day:
                    continue
                mr = reason_re.search(line)
                if not mr or int(mr.group(1)) != 1:
                    continue
                day = line[:10]
                per_day[uid][day] += 1
                for pair in mr.group(2).split(','):
                    if '=' not in pair:
                        continue
                    k, v = pair.split('=')
                    try:
                        per_day_items[uid][day][int(k)] += int(v)
                    except ValueError:
                        pass
                stamps[uid].append(line[:23])

print('files=%d' % files)


def burst(ts):
    """任意 60 秒内最多几笔（按字符串时间已可直接比大小）。"""
    import datetime
    def parse(s):
        return datetime.datetime.strptime(s, '%Y-%m-%d %H:%M:%S.%f')
    times = sorted(parse(t) for t in ts)
    best, j = 0, 0
    for i in range(len(times)):
        while times[i] - times[j] > datetime.timedelta(seconds=60):
            j += 1
        best = max(best, i - j + 1)
    return best


for uid in UIDS:
    days = per_day[uid]
    tot = sum(days.values())
    print('\n=== uid=%d  reason=1 共 %d 笔（%d 天有记录）===' % (uid, tot, len(days)))
    if not tot:
        continue
    top = sorted(days.items(), key=lambda x: -x[1])[:6]
    for day, n in top:
        it = per_day_items[uid][day]
        print('  %s  %3d 笔   item3(英雄经验)=%-10s item17(经验)=%-10s item14(金钱)=%-10s item16(钻石)=%s'
              % (day, n, it.get(3, 0), it.get(17, 0), it.get(14, 0), it.get(16, 0)))
    print('  🚀 任意 60s 窗口最大笔数 = %d' % burst(stamps[uid]))
