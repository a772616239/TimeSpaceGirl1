#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""只读：从 /root/incident_* 快照里抽取玩家货币口径（16=钻石 3=英雄经验 17=经验 14=金钱）。"""
import glob, json, os

TARGETS = [10000240, 10000153, 10000198, 10000034, 10000016, 10000015, 10000194, 10000013]
found = {}

for path in glob.glob('/root/incident_*/**/*.json', recursive=True):
    if os.path.getsize(path) < 200:
        continue
    if 'itemLog' in os.path.basename(path) or 'heroLog' in path or 'fight' in path:
        continue
    try:
        d = json.load(open(path, 'r', errors='ignore'))
    except Exception:
        continue
    docs = d if isinstance(d, list) else [d]
    for u in docs:
        if not isinstance(u, dict):
            continue
        uid = u.get('_id')
        if not isinstance(uid, (int, float)):
            continue
        uid = int(uid)
        if uid not in TARGETS:
            continue
        im = (u.get('itemManager') or {}).get('itemMap') or {}
        pm = u.get('playerManager') or {}

        def g(k):
            v = im.get(str(k)) or {}
            return int(v.get('itemNum') or 0)
        prev = found.get(uid)
        rec = {'uid': uid, 'nick': pm.get('nickName', ''), 'level': int(pm.get('level') or 0),
               'force': int(pm.get('maxForce') or 0), 'dia': g(16), 'hero_exp': g(3),
               'exp': g(17), 'gold': g(14), 'src': os.path.relpath(path, '/root')}
        if not prev or os.path.getmtime(path) > prev.get('_mt', 0):
            rec['_mt'] = os.path.getmtime(path)
            found[uid] = rec

print('uid         nick            lv   force     dia16    heroExp3     exp17        gold14      src')
for uid in TARGETS:
    r = found.get(uid)
    if not r:
        print('%-10d %s' % (uid, '<无 user 快照>'))
        continue
    print('%-10d %-15s %-4d %-9d %-8d %-12d %-12d %-12d %s' % (
        uid, (r['nick'] or '-')[:15], r['level'], r['force'], r['dia'],
        r['hero_exp'], r['exp'], r['gold'], r['src']))
