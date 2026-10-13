#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""游戏服（时空战场 gs / 129.226.213.65）每日巡检 → 邮件报告。

参考 TD 项目 utils/email_utils.send_email 的实现：
  QQ 邮箱 SMTP SSL 465 → 失败回退 587 STARTTLS，授权码取自 .env 的 EMAIL_PASSWORD。

用法:
  python3 scripts/server_health_check.py              # 采集 + 发邮件
  python3 scripts/server_health_check.py --dry-run    # 只打印报告，不发邮件
  python3 scripts/server_health_check.py --to a@b.com # 覆盖收件人
  python3 scripts/server_health_check.py --json       # 额外输出结构化 JSON

依赖: 本机 ssh 已配置 Host gs 别名（~/.ssh/config + tencent-gameserver.pem）。
"""
import argparse
import json
import os
import re
import socket
import smtplib
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

# ----------------------------------------------------------------------------
# 配置
# ----------------------------------------------------------------------------
SSH_HOST = os.environ.get('GS_SSH_HOST', 'gs')
SSH_TIMEOUT = 60

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATE_FILE = os.path.join(BASE_DIR, '.server_health_state.json')

# 邮件（与 TD config/config.py 的 email 段一致）
SMTP_SERVER = 'smtp.qq.com'
SMTP_PORT = 465
SENDER_EMAIL = '772616239@qq.com'
RECIPIENTS = ['772616239@qq.com']
ENV_CANDIDATES = [
    os.path.expanduser('~/.gs_health.env'),           # 本机独立凭据（可选，推荐）
    '/Volumes/S/TD/.env',                             # 实盘机权威 .env
    '/Users/wangxufeng/TD-recovery/.env',
    '/Users/wangxufeng/TD-salvage-20260911/.env',     # 注：此处口令可能已过期，会自动跳过
]

# 核心程序（挂了 → 🔴 严重）
CORE_PROCS = [
    ('gameserver',   r'gameSrv-1\.0\.0\.jar',            '游戏服 gameSrv-1.0.0.jar'),
    ('loginserver',  r'org\.apache\.catalina\.startup\.Bootstrap', '登录服 Tomcat 8.5.95'),
    ('mongodb',      r'(^|/)mongod\b',                   'MongoDB'),
    ('redis',        r'redis-server',                    'Redis'),
]
# 期望运行（挂了 → ⚠️ 提示；nginx 已配置开机自启 chkconfig on）
SERVICE_PROCS = [
    ('nginx',        r'nginx: master|nginx/sbin/nginx',  'Nginx (listen 80)'),
    ('x-ui',         r'x-ui/x-ui|/x-ui\b',               'x-ui 面板'),
    ('xray',         r'xray-linux|xray/xray|/xray\b',    'Xray 代理'),
    ('fail2ban',     r'fail2ban-server',                 'Fail2Ban'),
    ('postfix',      r'/master -w|postfix',              'Postfix'),
    ('BT-Panel',     r'BT-Panel',                        '宝塔面板'),
]
# 按需运行（仅陈述状态，不算异常）
OPTIONAL_PROCS = [
    ('chatserver',   r'chatserver-1\.0\.0\.jar',         '聊天服 chatserver-1.0.0.jar'),
    ('xxljob',       r'xxl-job-admin-2\.4\.0\.jar',      'XXL-Job 调度中心'),
    ('mihomo',       r'mihomo',                          'Mihomo/Clash'),
]

# 系统级错误关键字（命中才算故障；其余 ERROR 视为业务级噪音）
SYS_ERR_PATTERNS = (
    'OutOfMemory|OOMKilled|GC overhead|Connection refused|Connection reset|'
    'MongoTimeout|SocketTimeout|StackOverflow|Too many open files|No space left|'
    'Communications link failure|Failed to connect|UnknownHost|'
    'Address already in use|Cannot allocate memory'
)

# 期望监听的端口（核心端口缺失 → 🔴）
EXPECTED_PORTS = [
    (8080,  '登录服 HTTP',   True),
    (16081, '游戏服',        True),
    (27017, 'MongoDB',       True),
    (6379,  'Redis(本地)',   True),
    (8888,  'x-ui 面板',     False),
    (443,   'Xray 代理',     False),
    (22,    'SSH',           True),
]

# 告警阈值
MEM_AVAIL_WARN_MB = 600      # 可用内存低于此值 → 告警
DISK_USED_WARN_PCT = 85      # 磁盘使用率高于此值 → 告警
CRASH_LOOKBACK_DAYS = 7      # 近 N 天内的 JVM 崩溃文件算"近期"
JVM_RSS_OVER_XMX = 1.5       # 常驻内存超过 -Xmx 的倍数才告警（RSS 含堆外，故放宽）
GAME_LOG = '/data/srvlog/gameserver.log'
MONGO_CONF = '/home/java/gameserver/config/application.properties'
PUBLIC_IP = '129.226.213.65'  # 腾讯云公网 IP（内网 10.3.0.15）


# ----------------------------------------------------------------------------
# 远端采集
# ----------------------------------------------------------------------------
REMOTE_SCRIPT = r'''
echo "@@@HOST"
hostname
hostname -I 2>/dev/null | awk '{print $1}'
echo "@@@UPTIME"
uptime
echo "@@@CORES"
grep -c ^processor /proc/cpuinfo
echo "@@@MEM"
free -m
echo "@@@DISK"
df -h -x tmpfs -x devtmpfs
echo "@@@PS"
ps -eo pid,etime,rss,pcpu,vsz,args --sort=-rss
echo "@@@PORTS"
ss -lnt
echo "@@@CONN"
ss -s
echo "@@@MONGOCFG"
grep -c 'authSource=admin' ''' + MONGO_CONF + r''' 2>/dev/null || echo 0
echo "@@@CRASH"
find /data/dump /home/java -maxdepth 3 \( -name 'hs_err_pid*.log' -o -name '*.hprof' \) -printf '%T@ %p\n' 2>/dev/null
echo "@@@LOGERR"
tail -n 3000 ''' + GAME_LOG + r''' 2>/dev/null | grep -c -iE 'ERROR|Exception' || echo 0
echo "@@@LOGSYS"
tail -n 3000 ''' + GAME_LOG + r''' 2>/dev/null | grep -icE "''' + SYS_ERR_PATTERNS + r'''" || echo 0
echo "@@@LOGTOP"
tail -n 3000 ''' + GAME_LOG + r''' 2>/dev/null | grep -iE 'ERROR|Exception' | sed -E 's/[0-9]+/N/g' | cut -c1-110 | sort | uniq -c | sort -rn | head -5
echo "@@@GAMEINST"
pgrep -c -f 'gameSrv-1\.0\.0\.jar' 2>/dev/null || echo 0
echo "@@@LOGSIZE"
du -sh /data/srvlog 2>/dev/null
echo "@@@END"
'''


def run_remote(host, script, timeout=SSH_TIMEOUT):
    """通过 ssh 在服务器上执行 bash 脚本，返回 (rc, stdout, stderr)。"""
    cmd = ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10',
           '-o', 'StrictHostKeyChecking=accept-new', host, 'bash -s']
    try:
        p = subprocess.run(cmd, input=script, capture_output=True, text=True,
                           timeout=timeout)
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return -1, '', 'ssh 连接超时(%ss)' % timeout
    except Exception as e:  # noqa: BLE001
        return -1, '', 'ssh 执行失败: %s' % e


def split_sections(raw):
    """按 @@@NAME 标记切分远端输出。"""
    out = {}
    cur = None
    buf = []
    for line in raw.splitlines():
        m = re.match(r'^@@@([A-Z]+)\s*$', line.strip())
        if m:
            if cur:
                out[cur] = '\n'.join(buf).strip('\n')
            cur = m.group(1)
            buf = []
            continue
        if cur:
            buf.append(line)
    if cur:
        out[cur] = '\n'.join(buf).strip('\n')
    return out


# ----------------------------------------------------------------------------
# 解析
# ----------------------------------------------------------------------------
def parse_ps(text):
    """解析 ps -eo pid,etime,rss,pcpu,vsz,args --sort=-rss。"""
    rows = []
    for line in text.splitlines():
        line = line.rstrip()
        if not line:
            continue
        parts = line.split(None, 5)
        if len(parts) < 6 or not parts[0].isdigit():
            continue
        pid, etime, rss, pcpu, vsz, args = parts
        try:
            rows.append({
                'pid': int(pid), 'etime': etime, 'rss_kb': int(rss),
                'cpu': float(pcpu), 'vsz_kb': int(vsz), 'args': args,
            })
        except ValueError:
            continue
    return rows


def human_etime(etime):
    """01:13:32 / 27:25 / 3-04:05:06 → 中文可读时长。"""
    m = re.match(r'^(?:(\d+)-)?(\d+):(\d+)(?::(\d+))?$', etime.strip())
    if not m:
        return etime
    days = int(m.group(1) or 0)
    a, b = int(m.group(2)), int(m.group(3))
    c = m.group(4)
    if c is None:                 # MM:SS
        secs = a * 60 + b
    else:                          # HH:MM:SS
        secs = a * 3600 + b * 60 + int(c)
    secs += days * 86400
    d, rem = divmod(secs, 86400)
    h, rem = divmod(rem, 3600)
    mi, _ = divmod(rem, 60)
    if d:
        return '%d天%d小时' % (d, h)
    if h:
        return '%d小时%d分' % (h, mi)
    return '%d分' % mi


def match_proc(rows, pattern):
    rx = re.compile(pattern)
    for r in rows:
        if rx.search(r['args']):
            return r
    return None


def parse_mem(text):
    for line in text.splitlines():
        if line.startswith('Mem:'):
            f = line.split()
            return {'total': int(f[1]), 'used': int(f[2]),
                    'free': int(f[3]), 'avail': int(f[6])}
    return None


def parse_load(text):
    m = re.search(r'load average:\s*([\d.]+),\s*([\d.]+),\s*([\d.]+)', text)
    if m:
        return [float(m.group(i)) for i in (1, 2, 3)]
    return None


def parse_uptime_str(text):
    m = re.search(r'up\s+(.+?),\s+\d+\s+users?', text)
    if m:
        return m.group(1).strip()
    m = re.search(r'up\s+(.+?),\s+load average', text)
    return m.group(1).strip() if m else '?'


def parse_ports(text):
    """ss -lnt → {port: local_addr}"""
    ports = {}
    for line in text.splitlines():
        f = line.split()
        if len(f) < 4 or f[0] not in ('LISTEN',):
            continue
        addr = f[3]
        m = re.search(r':(\d+)$', addr)
        if m:
            ports[int(m.group(1))] = addr
    return ports


def parse_disks(text):
    disks = []
    for line in text.splitlines()[1:]:
        f = line.split()
        if len(f) < 6:
            continue
        try:
            pct = int(f[4].rstrip('%'))
        except ValueError:
            continue
        disks.append({'fs': f[0], 'size': f[1], 'used': f[2],
                      'avail': f[3], 'pct': pct, 'mnt': f[5]})
    return disks


def parse_conn(text):
    m = re.search(r'TCP:\s+(\d+)\s+\((\d+)', text)
    if m:
        return {'tcp_total': int(m.group(1)), 'tcp_estab': int(m.group(2))}
    return {}


def parse_crash(text, now_ts):
    items = []
    for line in text.splitlines():
        f = line.split(None, 1)
        if len(f) != 2:
            continue
        try:
            ts = float(f[0])
        except ValueError:
            continue
        age_days = (now_ts - ts) / 86400.0
        items.append({'path': f[1].strip(), 'age_days': age_days,
                      'time': datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M')})
    items.sort(key=lambda x: x['age_days'])
    return items


# ----------------------------------------------------------------------------
# 状态比对（重启检测）
# ----------------------------------------------------------------------------
def load_state():
    try:
        with open(STATE_FILE, 'r', encoding='utf-8') as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return {}


def save_state(data):
    try:
        with open(STATE_FILE, 'w', encoding='utf-8') as fh:
            json.dump(data, fh, ensure_ascii=False, indent=2)
    except Exception:  # noqa: BLE001
        pass


# ----------------------------------------------------------------------------
# 报告渲染
# ----------------------------------------------------------------------------
def render(sec, prev_state):
    now_local = datetime.now()
    now_srv = datetime.now(timezone.utc) + timedelta(hours=8)   # 服务器本地时间(CST)
    rows = parse_ps(sec.get('PS', ''))
    mem = parse_mem(sec.get('MEM', ''))
    load = parse_load(sec.get('UPTIME', ''))
    cores = int((sec.get('CORES') or '0').strip() or 0)
    disks = parse_disks(sec.get('DISK', ''))
    ports = parse_ports(sec.get('PORTS', ''))
    conn = parse_conn(sec.get('CONN', ''))
    host_line = (sec.get('HOST') or '').splitlines()
    hostname = host_line[0].strip() if host_line else '?'
    ip = PUBLIC_IP or (host_line[1].strip() if len(host_line) > 1 else '?')
    inner_ip = host_line[1].strip() if len(host_line) > 1 else ''
    uptime_str = parse_uptime_str(sec.get('UPTIME', ''))

    problems = []      # 🔴
    warnings = []      # ⚠️

    # ---- 程序检查 ----
    def check_group(group, severity):
        out = []
        for key, pat, desc in group:
            r = match_proc(rows, pat)
            if r:
                out.append({'key': key, 'desc': desc, 'up': True, 'pid': r['pid'],
                            'etime': r['etime'], 'rss_mb': r['rss_kb'] / 1024.0,
                            'cpu': r['cpu']})
            else:
                out.append({'key': key, 'desc': desc, 'up': False})
                if severity == 'core':
                    problems.append('核心程序未运行：%s' % desc)
                elif severity == 'service':
                    warnings.append('服务未运行：%s' % desc)
        return out

    core = check_group(CORE_PROCS, 'core')
    svc = check_group(SERVICE_PROCS, 'service')
    opt = check_group(OPTIONAL_PROCS, 'none')

    # 重启检测
    cur_pids = {i['key']: i['pid'] for i in core + svc + opt if i['up']}
    restarted = []
    if prev_state.get('pids'):
        for k, pid in cur_pids.items():
            old = prev_state['pids'].get(k)
            if old and old != pid:
                restarted.append(k)
        if restarted:
            warnings.append('自上次巡检后发生重启：%s' % ', '.join(restarted))

    # ---- 端口检查 ----
    port_rows = []
    for port, desc, required in EXPECTED_PORTS:
        ok = port in ports
        port_rows.append({'port': port, 'desc': desc, 'up': ok, 'required': required})
        if not ok and required:
            problems.append('核心端口未监听：%d (%s)' % (port, desc))
        elif not ok:
            warnings.append('端口未监听：%d (%s)' % (port, desc))

    # ---- 资源 ----
    if mem and mem['avail'] < MEM_AVAIL_WARN_MB:
        warnings.append('可用内存偏低：%d MB（告警线 %d MB）' % (mem['avail'], MEM_AVAIL_WARN_MB))
    for d in disks:
        if d['mnt'] in ('/', '/data') and d['pct'] >= DISK_USED_WARN_PCT:
            warnings.append('磁盘 %s 使用率 %d%%（挂载 %s）' % (d['fs'], d['pct'], d['mnt']))
    if cores and load and load[0] > cores * 2:
        warnings.append('1分钟负载 %.2f 偏高（%d 核）' % (load[0], cores))

    # 游戏服 JVM 堆占用（Xmx1280m；RSS 含堆外，故按倍数阈值）
    gm = next((i for i in core if i['key'] == 'gameserver' and i['up']), None)
    if gm and gm['rss_mb'] > 1280 * JVM_RSS_OVER_XMX:
        warnings.append('游戏服 JVM 常驻 %.0f MB，显著超过 -Xmx1280m（疑似堆外泄漏）' % gm['rss_mb'])

    # 游戏服多实例（端口抢占风险）
    try:
        game_inst = int((sec.get('GAMEINST') or '0').strip().splitlines()[-1])
    except (ValueError, IndexError):
        game_inst = -1
    if game_inst > 1:
        problems.append('游戏服存在 %d 个实例（应为 1，会抢占端口）' % game_inst)

    # Mongo 配置
    try:
        mongo_cfg = int((sec.get('MONGOCFG') or '0').strip().splitlines()[-1])
    except (ValueError, IndexError):
        mongo_cfg = -1
    if mongo_cfg != 2:
        warnings.append('MongoDB 连接串 authSource=admin 出现 %d 次（应为 2）' % mongo_cfg)

    # 崩溃文件
    crashes = parse_crash(sec.get('CRASH', ''), time.time())
    recent = [c for c in crashes if c['age_days'] <= CRASH_LOOKBACK_DAYS]
    if recent:
        warnings.append('近 %d 天内发现 %d 个 JVM 崩溃/堆转储文件' % (CRASH_LOOKBACK_DAYS, len(recent)))

    # 游戏日志错误：区分系统级故障与业务级噪音
    def _last_int(key):
        try:
            return int((sec.get(key) or '0').strip().splitlines()[-1])
        except (ValueError, IndexError):
            return -1

    log_err = _last_int('LOGERR')
    log_sys = _last_int('LOGSYS')
    log_top = [ln.strip() for ln in (sec.get('LOGTOP') or '').splitlines() if ln.strip()]
    if log_sys > 0:
        warnings.append('gameserver.log 尾部 3000 行含 %d 条系统级故障关键字（连接/超时/OOM 类）' % log_sys)

    # ---- 汇总 ----
    if problems:
        headline = '🔴 发现 %d 项严重异常' % len(problems)
    elif warnings:
        headline = '⚠️ 基本正常，%d 项需关注' % len(warnings)
    else:
        headline = '✅ 全部正常'

    up_core = sum(1 for i in core if i['up'])
    L = []
    L.append('游戏服巡检报告')
    L.append('=' * 46)
    L.append('巡检时间: %s (北京)  /  %s (服务器CST)' % (
        now_local.strftime('%Y-%m-%d %H:%M:%S'), now_srv.strftime('%Y-%m-%d %H:%M')))
    L.append('主机    : %s  (%s)' % (hostname, ip + ('  内网 ' + inner_ip if inner_ip else '')))
    L.append('总体状态: %s' % headline)
    L.append('核心程序: %d/%d 在线' % (up_core, len(core)))
    L.append('')

    L.append('一、系统概览')
    L.append('-' * 46)
    L.append('  运行时长: %s' % uptime_str)
    if load:
        L.append('  系统负载: 1min %.2f / 5min %.2f / 15min %.2f  (%d 核)' % (
            load[0], load[1], load[2], cores))
    if mem:
        pct = mem['used'] * 100.0 / mem['total'] if mem['total'] else 0
        L.append('  内存    : %d MB 总 / %d MB 已用 (%.0f%%) / %d MB 可用%s' % (
            mem['total'], mem['used'], pct, mem['avail'],
            '   ⚠️ 偏低' if mem['avail'] < MEM_AVAIL_WARN_MB else ''))
    if conn:
        L.append('  网络连接: TCP 总 %d / 已建立 %d' % (conn.get('tcp_total', 0),
                                                        conn.get('tcp_estab', 0)))
    for d in disks:
        if d['mnt'] in ('/', '/data'):
            L.append('  磁盘 %-6s: %s 总 / %s 已用 (%d%%) / %s 可用' % (
                d['mnt'], d['size'], d['used'], d['pct'], d['avail']))
    L.append('')

    def proc_block(title, group, mark_up, mark_down):
        L.append(title)
        L.append('-' * 46)
        for i in group:
            if i['up']:
                L.append('  %s %-13s PID %-7d 运行 %-10s 常驻 %7.0f MB  CPU %5.1f%%' % (
                    mark_up, i['key'], i['pid'], human_etime(i['etime']),
                    i['rss_mb'], i['cpu']))
            else:
                L.append('  %s %-13s 未运行   (%s)' % (mark_down, i['key'], i['desc']))
        L.append('')

    proc_block('二、核心程序', core, '✅', '❌')
    proc_block('三、服务组件', svc, '✅', '⚠️')
    proc_block('四、按需程序', opt, '✅', '➖')

    L.append('五、端口监听')
    L.append('-' * 46)
    for p in port_rows:
        L.append('  %s %-6d %s' % ('✅' if p['up'] else ('❌' if p['required'] else '⚠️'),
                                   p['port'], p['desc']))
    L.append('')

    L.append('六、资源占用 Top 5 (按常驻内存)')
    L.append('-' * 46)
    for r in rows[:5]:
        cmd = r['args']
        cmd = cmd if len(cmd) <= 58 else cmd[:55] + '...'
        L.append('  %7.0f MB  CPU %5.1f%%  PID %-7d %s' % (
            r['rss_kb'] / 1024.0, r['cpu'], r['pid'], cmd))
    L.append('')

    L.append('七、日志与崩溃')
    L.append('-' * 46)
    if crashes:
        for c in crashes[:5]:
            flag = '⚠️近7天' if c['age_days'] <= CRASH_LOOKBACK_DAYS else '历史'
            L.append('  [%s] %s  (%s)' % (flag, c['path'], c['time']))
    else:
        L.append('  无 JVM 崩溃文件 / 堆转储')
    L.append('  gameserver.log 尾部 3000 行: 业务级错误 %s 条 / 系统级故障 %s 条' % (
        log_err if log_err >= 0 else '?', log_sys if log_sys >= 0 else '?'))
    if log_top:
        L.append('  业务错误 Top:')
        for t in log_top[:3]:
            L.append('    %s' % t[:96])
    L.append('  MongoDB authSource=admin 命中: %s (应为 2)' % (
        mongo_cfg if mongo_cfg >= 0 else '读取失败'))
    L.append('  游戏服实例数: %s (应为 1)' % (game_inst if game_inst >= 0 else '?'))
    L.append('')

    L.append('八、异常与建议')
    L.append('-' * 46)
    if not problems and not warnings:
        L.append('  无异常。')
    else:
        if problems:
            L.append('  🔴 严重:')
            for p in problems:
                L.append('     - %s' % p)
        if warnings:
            L.append('  ⚠️ 关注:')
            for w in warnings:
                L.append('     - %s' % w)
    if recent:
        L.append('')
        L.append('  建议: JVM 崩溃文件请下载 hs_err 日志定位根因，确认是否 OOM（-Xmx1280m）。')
    if log_sys > 0:
        L.append('')
        L.append('  建议: 存在系统级故障关键字，请查看 /data/srvlog/gameserver.log 确认连接/超时来源。')
    if gm is None:
        L.append('')
        L.append('  建议: 游戏服未运行，可用 /home/java/gameserver/RESTART-GAMESERVER.sh 干净重启。')
    nginx_down = any(i['key'] == 'nginx' and not i['up'] for i in svc)
    if nginx_down:
        L.append('')
        L.append('  建议: Nginx 已设为开机自启但当前未运行，如不需要可 chkconfig nginx off 消除告警。')
    L.append('')
    L.append('-' * 46)
    L.append('本邮件由 scripts/server_health_check.py 自动发送（参考 TD 项目 email_utils）。')

    body = '\n'.join(L)
    summary = {
        'problems': problems, 'warnings': warnings, 'restarted': restarted,
        'headline': headline, 'up_core': up_core, 'core_total': len(core),
        'hostname': hostname, 'ip': ip,
        'log_biz_errors': log_err, 'log_sys_errors': log_sys,
        'timestamp': now_local.strftime('%Y-%m-%d %H:%M:%S'),
    }
    state = {'last_run': now_local.isoformat(), 'pids': cur_pids}
    return body, summary, state


# ----------------------------------------------------------------------------
# 邮件（参考 TD utils/email_utils.send_email）
# ----------------------------------------------------------------------------
def load_email_passwords():
    """按优先级收集候选授权码，返回 [(pwd, source), ...]（去重）。"""
    out = []
    seen = set()

    def _add(pwd, src):
        pwd = (pwd or '').strip().strip('"').strip("'")
        if pwd and pwd not in seen:
            seen.add(pwd)
            out.append((pwd, src))

    _add(os.environ.get('EMAIL_PASSWORD', ''), 'env:EMAIL_PASSWORD')
    for path in ENV_CANDIDATES:
        try:
            with open(path, 'r', encoding='utf-8') as fh:
                for line in fh:
                    line = line.strip()
                    if line.startswith('EMAIL_PASSWORD='):
                        _add(line.split('=', 1)[1], path)
                        break
        except Exception:  # noqa: BLE001
            continue
    return out


def _build_msg(subject, targets, body):
    msg = MIMEMultipart()
    msg['From'] = 'Lily <%s>' % SENDER_EMAIL
    msg['To'] = ', '.join(targets)
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'plain', 'utf-8'))
    return msg


def send_email(subject, body, to_email=None):
    """QQ SMTP SSL 465 发送；逐个候选授权码验证，全失败再回退 587 STARTTLS。

    与 TD utils/email_utils.send_email 同构，额外增加了「多候选口令自动跳过失效口令」。
    """
    targets = [to_email] if isinstance(to_email, str) else (to_email or RECIPIENTS)
    cands = load_email_passwords()
    if not cands:
        return False, '未找到 EMAIL_PASSWORD（env 与各 .env 均无）'

    errs = []
    cipher = '（未验证）'
    # 1) 465 SSL
    for pwd, src in cands:
        try:
            srv = smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT, timeout=20)
            srv.login(SENDER_EMAIL, pwd)
            srv.sendmail(SENDER_EMAIL, targets, _build_msg(subject, targets, body).as_string())
            srv.quit()
            return True, '已发送至 %s（凭据来源: %s）' % (targets, src)
        except smtplib.SMTPAuthenticationError:
            cipher = src
            errs.append('465 口令失效(%s)' % src)
            continue
        except Exception as e:  # noqa: BLE001
            errs.append('465 %s: %s' % (type(e).__name__, e))
            break

    # 2) 587 STARTTLS 回退
    for pwd, src in cands:
        try:
            srv = smtplib.SMTP(SMTP_SERVER, 587, timeout=20)
            srv.starttls()
            srv.login(SENDER_EMAIL, pwd)
            srv.send_message(_build_msg(subject, targets, body))
            srv.quit()
            return True, '已通过 587 回退发送至 %s（凭据来源: %s）' % (targets, src)
        except smtplib.SMTPAuthenticationError:
            errs.append('587 口令失效(%s)' % src)
            continue
        except Exception as e:  # noqa: BLE001
            errs.append('587 %s: %s' % (type(e).__name__, e))
            break

    return False, '发送失败: ' + ' / '.join(errs) + (('  [最后尝试来源 %s]' % cipher) if cipher != '（未验证）' else '')


# ----------------------------------------------------------------------------
def save_report(body):
    """把报告留档到 scripts/logs/YYYY-MM-DD.log，便于事后取证。"""
    d = os.path.join(BASE_DIR, 'logs')
    try:
        os.makedirs(d, exist_ok=True)
        path = os.path.join(d, datetime.now().strftime('%Y-%m-%d') + '.log')
        with open(path, 'a', encoding='utf-8') as fh:
            fh.write('\n' + '=' * 60 + '\n')
            fh.write(body + '\n')
        return path
    except Exception:  # noqa: BLE001
        return ''


def main():
    ap = argparse.ArgumentParser(description='游戏服每日巡检 → 邮件')
    ap.add_argument('--dry-run', action='store_true', help='只打印报告，不发邮件')
    ap.add_argument('--to', help='覆盖收件人邮箱')
    ap.add_argument('--json', action='store_true', help='额外输出 JSON 摘要')
    ap.add_argument('--host', default=SSH_HOST, help='SSH 主机别名/IP')
    ap.add_argument('--no-state', action='store_true', help='不读写状态文件')
    args = ap.parse_args()

    rc, out, err = run_remote(args.host, REMOTE_SCRIPT)
    if rc != 0 and not out.strip():
        print('[ERROR] 无法连接 %s: %s' % (args.host, err.strip() or 'rc=%s' % rc),
              file=sys.stderr)
        return 2

    sec = split_sections(out)
    if 'END' not in sec and not sec.get('PS'):
        print('[ERROR] 采集失败，远端输出异常：\n%s' % out[:2000], file=sys.stderr)
        return 3

    prev = {} if args.no_state else load_state()
    body, summary, state = render(sec, prev)
    print(body)

    if args.json:
        print('\n=== JSON ===')
        print(json.dumps(summary, ensure_ascii=False, indent=2))

    if not args.no_state:
        save_state(state)

    if args.dry_run:
        print('\n[dry-run] 未发送邮件。')
        return 0

    prefix = '🔴' if summary['problems'] else ('⚠️' if summary['warnings'] else '✅')
    subject = '[游戏服巡检] %s %s %d/%d核心在线' % (
        summary['hostname'], summary['timestamp'][:16],
        summary['up_core'], summary['core_total'])
    if summary['problems']:
        subject = '%s [异常%d] %s' % (prefix, len(summary['problems']), subject)
    elif summary['warnings']:
        subject = '%s [关注%d] %s' % (prefix, len(summary['warnings']), subject)
    else:
        subject = '%s %s' % (prefix, subject)

    ok, msg = send_email(subject, body, args.to)
    log_path = save_report(
        '状态: %s\n邮件: %s\n\n%s' % (summary['headline'], msg, body))
    print('\n[邮件] %s' % msg)
    if log_path:
        print('[留档] %s' % log_path)
    return 0 if ok else 4


if __name__ == '__main__':
    sys.exit(main())
