#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""按 IP 归属地批量回填玩家国籍（playerManager.country）。

背景
----
客户端「国家旗帜」功能要求服务端下发 country（两位小写 ISO 码），但线上 205/208
个玩家文档里没有这个字段（只有 3 个玩家在面板里手选过）。服务端也从来没记过 IP：
`PlayerManager.ip` 只在建号时 setIp(ip)，而登录链路传进来的是空串 ⇒ 全服 ip 都是 ""。

所以国籍只能从**旁路日志**反推：
  ① Tomcat 访问日志  /home/java/loginserver/.../localhost_access_log.*.txt
     形如 `1.2.3.4 - - [20/Oct/2026:13:03:31 +0800] "GET /tk/getUserInfo?openId=xxx..." 200 52`
     → openId + IP + 时间（保留 31 天）
  ② 游戏服日志      /data/srvlog/gameserver.log*
     `channelInactive->uid=10000017,...,remoteAddress=/91.235.225.35:44562`
     → uid + IP（轮转保留 ~3 天，但含最近在线）
  openId → uid 走登录库 `user_info`（必须按 serverId 过滤，同一 openId 会挂在多区）。

判定
----
每个玩家的所有 IP 按出现次数加权投票，票最多的国家即归属国；同时记录票数占比
（conflict 时人工可复核）。私网/回环 IP 丢弃；GeoIP 查不到的国家跳过，绝不瞎猜
——客户端 CountryConfig 里有 `xx` 兜底，宁可留空也不写假数据。

数据源
------
GeoLite2-Country.mmdb（P3TERX 的免 key 镜像），首次运行自动下到 ~/.cache/ts-geo/。
第三方 IP 库只有国家级精度，VPN/机场 IP（线上大量 103.151.172.x=HK、103.151.173.x=JP）
会被判成落地国而不是玩家真实所在地 —— 这是 IP 口径的固有误差，报告里单列。

用法
----
  python3 scripts/backfill_player_country.py                 # 只分析，打印 + 出 CSV
  python3 scripts/backfill_player_country.py --apply         # 备份 → 写库 → 写审计
  python3 scripts/backfill_player_country.py --uid 10000017  # 只看一个号
  python3 scripts/backfill_player_country.py --apply --no-backup

依赖: 本机 ssh 已配置 Host gs；pip install geoip2（读 mmdb）。
"""
import argparse
import collections
import csv
import ipaddress
import json
import os
import re
import subprocess
import sys
from datetime import datetime

# ----------------------------------------------------------------------------
# 配置（与 cheat_scan.py 保持同一套环境变量口径）
# ----------------------------------------------------------------------------
SSH_HOST = os.environ.get('GS_SSH_HOST', 'gs')
GAME_DB = os.environ.get('GS_GAME_DB', 'm5_x1_game_10001')
LOGIN_DB = os.environ.get('GS_LOGIN_DB', 'x1_cn_test_login')
SERVER_ID = os.environ.get('GS_SERVER_ID', '10001')
GAME_LOG_GLOB = os.environ.get('GS_GAME_LOG_GLOB', '/data/srvlog/gameserver.log*')
LOGIN_LOG_GLOB = os.environ.get(
    'GS_LOGIN_LOG_GLOB',
    '/home/java/loginserver/apache-tomcat-8.5.95/logs/localhost_access_log.*.txt')

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BASE_DIR)
REPORT_DIR = os.path.join(BASE_DIR, 'logs')
GEO_DIR = os.path.join(os.path.expanduser('~'), '.cache', 'ts-geo')
GEO_MMDB = os.path.join(GEO_DIR, 'GeoLite2-Country.mmdb')
ASN_MMDB = os.path.join(GEO_DIR, 'GeoLite2-ASN.mmdb')
GEO_URL = ('https://github.com/P3TERX/GeoLite.mmdb/raw/download/'
           'GeoLite2-Country.mmdb')
ASN_URL = ('https://github.com/P3TERX/GeoLite.mmdb/raw/download/'
           'GeoLite2-ASN.mmdb')

# 机房 / 机场 ASN：命中即视为「IP 所在地 ≠ 玩家所在地」
# 只影响**判定权重**，不改 IP 本身；全部证据都是这类 IP 的玩家默认跳过（--include-vpn 可强写）
DC_ORG_RE = re.compile(
    r'(vpn|proxy|ikuuu|datacamp|m247|nordvpn|expressvpn|surfshark|cyberghost|'
    r'private internet|zenlayer|vultr|digitalocean|linode|akamai|ovh|hetzner|'
    r'contabo|hostinger|leaseweb|choopa|quadranet|colocrossing|sharktech|'
    r'amazon|google|microsoft|alibaba|tencent|oracle|cloudflare|'
    r'data ?center|datacent|hosting|cloud)',
    re.I)

SSH_TIMEOUT = 240
AUDIT_COLLECTION = 'gm_country_backfill'

# 两位小写字母，与 SetPlayerCountryHandler.COUNTRY_PATTERN 一致
COUNTRY_RE = re.compile(r'^[a-z]{2}$')


# ----------------------------------------------------------------------------
# SSH / Mongo
# ----------------------------------------------------------------------------
def ssh_run(cmd, timeout=SSH_TIMEOUT, stdin_text=None):
    """在 gs 上跑一条命令，返回 stdout；失败返回空串。"""
    try:
        p = subprocess.run(
            ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', SSH_HOST, cmd],
            input=stdin_text, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        sys.stderr.write('[warn] ssh timeout: %s\n' % cmd[:80])
        return ''
    except Exception as e:                                    # noqa: BLE001
        sys.stderr.write('[warn] ssh error: %s\n' % e)
        return ''
    if p.returncode != 0 and (p.stderr or '').strip():
        sys.stderr.write('[warn] ssh rc=%d: %s\n'
                         % (p.returncode, p.stderr.strip()[:200]))
    return p.stdout or ''


def mongo_json(js, db, timeout=SSH_TIMEOUT):
    """把一段 mongo JS 送到服务器执行，函数体需 return 一个可 JSON 化的值。"""
    wrapped = ('var __out=(function(){\n%s\n})();\n'
               'print(JSON.stringify(__out));\n') % js
    cmd = 'cat > /tmp/_ts_country.js && mongo --quiet %s /tmp/_ts_country.js' % db
    try:
        p = subprocess.run(
            ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15', SSH_HOST, cmd],
            input=wrapped, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        sys.stderr.write('[warn] mongo timeout (%s)\n' % db)
        return None
    for line in reversed((p.stdout or '').strip().splitlines()):
        line = line.strip()
        if line.startswith('{') or line.startswith('['):
            try:
                return json.loads(line)
            except ValueError:
                continue
    if p.returncode != 0:
        sys.stderr.write('[warn] mongo rc=%d: %s\n'
                         % (p.returncode, (p.stderr or '')[:300]))
    return None


# ----------------------------------------------------------------------------
# 数据采集
# ----------------------------------------------------------------------------
ACCESS_RE = re.compile(
    r'^(\d+\.\d+\.\d+\.\d+)\s+-\s+-\s+\[(\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2})[^\]]*\]'
    r'\s+"[A-Z]+\s+(\S+)')
OPENID_RE = re.compile(r'[?&]openId=([^&\s]+)')
GAMELOG_RE = re.compile(
    r'channelInactive->uid=(\d+),.*?remoteAddress=/(\d+\.\d+\.\d+\.\d+)')


def fetch_access_log():
    """openId -> [(datetime, ip)]，来自 Tomcat 访问日志（31 天）。"""
    out = ssh_run("grep -h 'openId=' %s 2>/dev/null" % LOGIN_LOG_GLOB)
    result = collections.defaultdict(list)
    bad = 0
    for line in out.splitlines():
        m = ACCESS_RE.match(line)
        if not m:
            bad += 1
            continue
        ip, ts, url = m.groups()
        q = OPENID_RE.search(url)
        if not q:
            continue
        try:
            t = datetime.strptime(ts, '%d/%b/%Y:%H:%M:%S')
        except ValueError:
            continue
        result[q.group(1)].append((t, ip))
    sys.stderr.write('[info] 访问日志: %d 行可解析 / %d 行丢弃，%d 个 openId\n'
                     % (len(out.splitlines()) - bad, bad, len(result)))
    return result


def fetch_gamelog():
    """uid -> [ip]，来自游戏服日志的 remoteAddress（只保留最近 3 天轮转）。"""
    out = ssh_run("zcat -f %s 2>/dev/null | grep -oE "
                  "'channelInactive->uid=[0-9]+,.*remoteAddress=/([0-9]{1,3}\\.){3}[0-9]{1,3}'"
                  % GAME_LOG_GLOB)
    result = collections.defaultdict(set)
    for line in out.splitlines():
        m = GAMELOG_RE.search(line)
        if not m:
            continue
        uid, ip = m.groups()
        if uid != '0':
            result[uid].add(ip)
    sys.stderr.write('[info] 游戏日志: %d 个 uid 有直连 IP\n' % len(result))
    return result


def fetch_uid_openid():
    """openId -> uid（只取本区，同一 openId 会同时挂在 10001/10002）。"""
    data = mongo_json(
        'var o={};'
        'db.user_info.find({serverId:"%s"}).forEach(function(d){'
        '  if(d.openId) o[d.openId]=String(d.uid); });'
        'return o;' % SERVER_ID, LOGIN_DB)
    return data or {}


def fetch_players():
    data = mongo_json(
        'var a=[];'
        'db.user.find({},{"playerManager.country":1,"playerManager.ip":1,'
        '"playerManager.nickName":1,"playerManager.level":1,'
        '"playerManager.loginTime":1}).forEach(function(d){'
        '  var p=d.playerManager||{};'
        '  a.push({uid:String(d._id),'
        '         country:(p.country===undefined?null:p.country),'
        '         ip:(p.ip===undefined?null:p.ip),'
        '         nick:(p.nickName||""),'
        '         level:(p.level||0),'
        '         loginTime:(p.loginTime||0)});});'
        'return a;', GAME_DB)
    return data or []


# ----------------------------------------------------------------------------
# GeoIP
# ----------------------------------------------------------------------------
def _download(url, dest, min_size=1 << 20):
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    sys.stderr.write('[info] 下载 %s → %s\n' % (os.path.basename(dest), dest))
    tmp = dest + '.part'
    p = subprocess.run(['curl', '-sSL', '--max-time', '240', '-o', tmp, url],
                       capture_output=True, text=True)
    if p.returncode != 0 or not os.path.exists(tmp) or os.path.getsize(tmp) < min_size:
        sys.stderr.write('[error] 下载失败 %s: %s\n' % (url, (p.stderr or '')[:200]))
        return False
    os.replace(tmp, dest)
    return True


def ensure_mmdb(path, url):
    if os.path.exists(path) and os.path.getsize(path) > 1 << 20:
        return path
    return path if _download(url, path) else None


class GeoResolver(object):
    """国家 + ASN 两级解析；ASN 库缺失时降级为「不做机房判定」。"""

    def __init__(self, with_asn=True):
        try:
            import geoip2.database
        except ImportError:
            sys.stderr.write('[error] 缺 geoip2：pip install geoip2\n')
            sys.exit(2)
        cpath = ensure_mmdb(GEO_MMDB, GEO_URL)
        if not cpath:
            sys.exit(2)
        self.reader = geoip2.database.Reader(cpath)
        self.asn_reader = None
        if with_asn:
            apath = ensure_mmdb(ASN_MMDB, ASN_URL)
            if apath:
                try:
                    self.asn_reader = geoip2.database.Reader(apath)
                except Exception:                             # noqa: BLE001
                    self.asn_reader = None
        self.cache = {}

    def lookup(self, ip):
        """(国家码小写|None, 国家名, ASN组织名, 是否机房/机场)"""
        if ip in self.cache:
            return self.cache[ip]
        code, name, org, dc = None, '', '', False
        try:
            rec = self.reader.country(ip)
            code = (rec.country.iso_code or '').lower() or None
            name = rec.country.name or ''
        except Exception:                                     # noqa: BLE001
            pass
        if self.asn_reader is not None:
            try:
                a = self.asn_reader.asn(ip)
                org = a.autonomous_system_organization or ''
                dc = bool(DC_ORG_RE.search(org))
            except Exception:                                 # noqa: BLE001
                pass
        self.cache[ip] = (code, name, org, dc)
        return self.cache[ip]


def is_routable(ip):
    try:
        a = ipaddress.ip_address(ip)
    except ValueError:
        return False
    return not (a.is_private or a.is_loopback or a.is_reserved
                or a.is_multicast or a.is_unspecified)


# ----------------------------------------------------------------------------
# 判定
# ----------------------------------------------------------------------------
def build_evidence(players, access, gamelog, uid2oid):
    """uid -> {ip: [次数, 最后时间]}；openId 优先，游戏日志补充直连 IP。"""
    ev = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, None]))
    for oid, lst in access.items():
        uid = uid2oid.get(oid)
        if not uid:
            continue
        for t, ip in lst:
            if not is_routable(ip):
                continue
            slot = ev[uid][ip]
            slot[0] += 1
            if slot[1] is None or t > slot[1]:
                slot[1] = t
    for uid, ips in gamelog.items():
        for ip in ips:
            if not is_routable(ip):
                continue
            slot = ev[uid][ip]
            slot[0] += 1                                  # 直连一次算一票
    return ev


def decide(ip_slots, geo):
    """票数加权投票 → (code, share, vpn_only, 明细)。

    判定顺序：
      1. 有住宅 IP ⇒ **只用住宅 IP 投票**（机房 IP 的落地国会把中国玩家判成 HK/JP）；
      2. 全是机房/机场 IP ⇒ vpn_only=True，国家取票最多的那个，但调用方默认不写；
      3. 一个都解析不出 ⇒ code=None。
    """
    rows = []
    for ip, (cnt, ts) in ip_slots.items():
        code, name, org, dc = geo.lookup(ip)
        rows.append({'ip': ip, 'count': cnt, 'last': ts, 'code': code or '',
                     'country': name, 'asn': org, 'dc': dc})
    residential = [r for r in rows if not r['dc']]
    pool = residential or rows
    votes = collections.defaultdict(int)
    for r in pool:
        if r['code']:
            votes[r['code']] += r['count']
    total = sum(votes.values())
    if not total:
        return None, 0.0, not residential, rows
    code, weight = max(votes.items(), key=lambda kv: (kv[1], kv[0]))
    return code, weight / float(total), not residential, rows


def main():
    ap = argparse.ArgumentParser(description='按 IP 归属地回填玩家国籍')
    ap.add_argument('--apply', action='store_true', help='真正写库（默认只分析）')
    ap.add_argument('--uid', action='append', default=None, help='只处理指定 uid，可重复')
    ap.add_argument('--no-backup', action='store_true', help='--apply 时跳过 mongodump 备份')
    ap.add_argument('--min-share', type=float, default=0.5,
                    help='最高票国家占比低于该值则不写（默认 0.5）')
    ap.add_argument('--include-vpn', action='store_true',
                    help='连「只有机房/机场 IP」的玩家也写（默认跳过，避免 VPN 落地国被当成国籍）')
    ap.add_argument('--no-asn', action='store_true', help='不加载 ASN 库（跳过机房判定）')
    args = ap.parse_args()

    access = fetch_access_log()
    gamelog = fetch_gamelog()
    uid2oid = fetch_uid_openid()
    players = fetch_players()
    if not players:
        sys.stderr.write('[error] 没取到玩家数据，检查 ssh / mongo\n')
        return 2
    geo = GeoResolver(with_asn=not args.no_asn)

    ev = build_evidence(players, access, gamelog, uid2oid)
    targets = [p for p in players if not p['country']]
    if args.uid:
        want = set(args.uid)
        targets = [p for p in players if p['uid'] in want]

    rows = []
    for p in targets:
        slots = ev.get(p['uid']) or {}
        code, share, vpn_only, detail = decide(slots, geo)
        rows.append({
            'uid': p['uid'],
            'nick': p['nick'],
            'level': p['level'],
            'old_country': p['country'] or '',
            'new_country': code or '',
            'share': round(share, 3),
            'ips': len(slots),
            'vpn': 'Y' if (code and vpn_only) else '',
            'asn': '|'.join(sorted({d['asn'] for d in detail if d['asn']})),
            'evidence': '; '.join(
                '%s x%d %s%s' % (d['ip'], d['count'], d['code'] or '?',
                                 ' [DC]' if d['dc'] else '')
                for d in sorted(detail, key=lambda x: -x['count'])),
        })

    ok = [r for r in rows if r['new_country'] and COUNTRY_RE.match(r['new_country'])
          and r['share'] >= args.min_share]
    vpn = [r for r in ok if r['vpn']]
    ready = ok if args.include_vpn else [r for r in ok if not r['vpn']]
    no_ip = [r for r in rows if not r['new_country']]
    low = [r for r in rows if r['new_country'] and r['share'] < args.min_share]

    # ---- 报告 ----
    os.makedirs(REPORT_DIR, exist_ok=True)
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    csv_path = os.path.join(REPORT_DIR, 'country_backfill_%s.csv' % stamp)
    with open(csv_path, 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.DictWriter(f, fieldnames=['uid', 'nick', 'level', 'old_country',
                                          'new_country', 'share', 'ips', 'vpn',
                                          'asn', 'evidence'])
        w.writeheader()
        for r in sorted(rows, key=lambda x: (x['new_country'] or 'zz', x['uid'])):
            w.writerow(r)

    dist = collections.Counter(r['new_country'] for r in ready)
    print('=' * 72)
    print('玩家总数 %d | 缺国籍 %d | 有 IP 证据 %d | 无 IP 证据 %d'
          % (len(players), len(targets), len(ok) + len(low), len(no_ip)))
    print('本次可写 %d 个；跳过：机房/机场 IP %d 个、票数占比 < %.2f %d 个'
          % (len(ready), 0 if args.include_vpn else len(vpn), args.min_share, len(low)))
    print('国家分布: ' + ', '.join('%s:%d' % kv for kv in dist.most_common()))
    print('报告: %s' % csv_path)
    if no_ip:
        print('无 IP 证据（登录记录早于访问日志保留窗口）: %d 个' % len(no_ip))
    if vpn and not args.include_vpn:
        print('机房/机场 IP（VPN 落地国不可当国籍，待人工确认）: %d 个' % len(vpn))
        for r in vpn:
            print('    %s lv%-3s %-14s → %s  %s'
                  % (r['uid'], r['level'], r['nick'][:12], r['new_country'], r['asn'][:40]))
    print('=' * 72)

    if not args.apply:
        for r in ready[:20]:
            print('  %s lv%-3s %-14s → %s (%.2f)  %s'
                  % (r['uid'], r['level'], r['nick'][:12], r['new_country'],
                     r['share'], r['evidence'][:70]))
        if len(ready) > 20:
            print('  ... 其余 %d 条见 CSV' % (len(ready) - 20))
        print('\n[dry-run] 未写库。加 --apply 执行。')
        return 0

    if not ready:
        print('[apply] 没有可写记录')
        return 0

    # ---- 备份 ----
    backup_dir = ''
    if not args.no_backup:
        backup_dir = '/root/ts-country-backup-%s' % stamp
        # 连接串从线上 application.properties 取，脚本里不落密码
        out = ssh_run(
            'URI=$(grep -m1 "^spring.data.mongodb.uri=" '
            '/home/java/gameserver/config/application.properties | cut -d= -f2-); '
            'mongodump --quiet --uri "$URI" --collection user --out %s 2>&1 | tail -3; '
            'du -sh %s' % (backup_dir, backup_dir), timeout=600)
        print('[apply] 备份 → %s\n%s' % (backup_dir, out.strip()))
        if 'user.bson' not in ssh_run('ls %s/%s 2>/dev/null' % (backup_dir, GAME_DB)):
            sys.stderr.write('[error] 备份没生成，中止写库\n')
            return 3

    # ---- 写库 ----
    ops = []
    for r in ready:
        ops.append(
            '{updateOne:{filter:{_id:%s,"playerManager.country":{$in:["",null]}},'
            'update:{$set:{"playerManager.country":"%s"}}}}'
            % (r['uid'], r['new_country']))
    audit = []
    now = int(datetime.now().timestamp() * 1000)
    for r in ready:
        audit.append({
            'uid': int(r['uid']), 'country': r['new_country'],
            'share': r['share'], 'ips': r['ips'], 'vpn': bool(r['vpn']),
            'asn': r['asn'], 'evidence': r['evidence'],
            'method': 'ip-geolite2', 'ts': now,
        })
    js = ('var ops=[%s];\n'
          'var res=db.user.bulkWrite(ops);\n'
          'db.%s.insertMany(%s);\n'
          'return {matched:res.matchedCount,modified:res.modifiedCount};'
          % (','.join(ops), AUDIT_COLLECTION, json.dumps(audit, ensure_ascii=False)))
    out = mongo_json(js, GAME_DB)
    if not out:
        sys.stderr.write('[error] 写库失败\n')
        return 4
    print('[apply] bulkWrite: matched=%s modified=%s（审计写入 %s）'
          % (out.get('matched'), out.get('modified'), AUDIT_COLLECTION))

    # ---- 复核 ----
    check = mongo_json(
        'var n=0;db.user.find({"playerManager.country":{$exists:true,'
        '$nin:["",null]}}).forEach(function(){n++;});'
        'return {withCountry:n,total:db.user.countDocuments({})};', GAME_DB)
    print('[verify] 有国籍 %s / 总 %s' % (check.get('withCountry'), check.get('total')))
    return 0


if __name__ == '__main__':
    sys.exit(main())
