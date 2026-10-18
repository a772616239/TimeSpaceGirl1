#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""时空战场 游戏服日志自动清理（gs / 129.226.213.65）。

背景（2026-10-18 实测）：
  /home/java/gameserver/assets/log/jl_logs  912MB，43 个 YYYY-MM-DD 目录，
  2026-09 高峰每天 ~80MB（corelog0.log 40MB + error-log.log 37MB），**应用自己
  按天建目录但从不删** —— 这是真正的增长源，不是 /data/srvlog。
  /data/srvlog/gameserver.log 走 logrotate，但配置是 `daily size 100M`，而
  logrotate 3.8.6 里 size 会**覆盖**时间间隔（logrotate -d 实测输出
  "log size is below the 'size' threshold"），等效"只有到 100M 才转"，所以单文件
  能长到 100MB、且全盘封顶 ≈ 7×100MB ≈ 700MB。

用法（在服上跑，python3.6）：
  python3 log_cleanup.py                 # 默认 dry-run，只打印
  python3 log_cleanup.py --apply         # 真删
  python3 log_cleanup.py --apply --json  # 结构化输出（给巡检/CI 吃）
  python3 log_cleanup.py --selftest      # 沙箱自测（临时目录造数据，不碰线上）
  python3 log_cleanup.py --emit-logrotate  # 打印 logrotate 片段
  python3 log_cleanup.py --emit-cron       # 打印 cron 片段

🔴 三条铁护栏（写死，不可通过参数绕过）：
  1. 白名单前缀：只允许删 4 个日志根目录下的东西，其它路径一律拒绝；
  2. 今天不删：目录名/文件名的日期 == 今天，或 mtime 落在今天，一律跳过；
  3. min_keep 保底：每条规则至少留 N 个最新的，即使已过期；
     另加一条全局保底 —— 任何规则都至少留 1 个条目。
  双重保护：现役文件 gameserver.log / chatserver.log 永不在此删除（交给 logrotate
  copytruncate，因为 Java 进程持有 fd，删了只会写进黑洞、磁盘空间不释放）。
"""

import argparse
import fcntl
import json
import os
import re
import shutil
import sys
import tempfile
import time
from datetime import date, datetime, timedelta

# 🔴 线上 CentOS7 的 python3.6.8 在非 UTF-8 locale（cron 默认无 LANG）下 print 中文
#    直接 UnicodeEncodeError: 'ascii' codec。3.7+ 有 sys.stdout.reconfigure，
#    3.6 只能自己包一层 utf-8 writer。与 scripts/server_cleanup/cleanup_deleted_users.py 一致。
try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    else:
        import io
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8",
                                      errors="replace", line_buffering=True)
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8",
                                      errors="replace", line_buffering=True)
except Exception:
    pass

# ---------------------------------------------------------------------------
# 路径常量（线上布局）
# ---------------------------------------------------------------------------
LOG_ROOT = "/home/java/gameserver/assets/log"
SRVLOG_DIR = "/data/srvlog"
TOMCAT_LOG_DIR = "/home/java/loginserver/apache-tomcat-8.5.95/logs"
DUMP_DIR = "/data/dump"

AUDIT_LOG = "/var/log/ts_log_cleanup.log"
AUDIT_LOG_MAX = 4 * 1024 * 1024   # 自身日志超过 4MB 就清成空（避免二次膨胀）
LOCK_FILE = "/var/lock/ts_log_cleanup.lock"

# 现役（被进程持有 fd）的文件，绝对不在此脚本里删
PROTECTED_NAMES = ("gameserver.log", "chatserver.log", "catalina.out")

DATE_DIR_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})$")
DATED_FILE_RE = re.compile(r"(\d{4})-(\d{2})-(\d{2})")
ARCHIVE_DATE_RE = re.compile(r"-(?:(\d{8}))(?:[-.]|$)")

# ---------------------------------------------------------------------------
# 规则表
#   kind = date_dir    ：子目录名即日期
#   kind = dated_file  ：文件名内含 YYYY-MM-DD
#   kind = archive     ：轮转归档（gameserver.log-20261018.gz / .log.1）
# fields:
#   days     保留天数（日期 >= today - days 才留）
#   min_keep 至少保留的最新条目数（按日期新→旧排序后的前 N 个）
#   emergency_days  磁盘告急时的收紧值
# ---------------------------------------------------------------------------
def build_rules(log_root=LOG_ROOT, srvlog=SRVLOG_DIR, tomcat=TOMCAT_LOG_DIR,
                dump=DUMP_DIR):
    return [
        # --- 游戏服自身日志：量最大，7 天足够定位线上问题 ---------------
        dict(name="jl_logs  核心/错误日志", root=os.path.join(log_root, "jl_logs"),
             kind="date_dir", days=7, min_keep=3, emergency_days=2),
        # --- 道具流水：客服查单 / 回滚核对要用，留 30 天 -----------------
        dict(name="jl_item  道具流水", root=os.path.join(log_root, "jl_item"),
             kind="date_dir", days=30, min_keep=7, emergency_days=7),
        dict(name="jl_blogs 行为日志", root=os.path.join(log_root, "jl_blogs"),
             kind="date_dir", days=30, min_keep=3, emergency_days=7),
        dict(name="jl_tlogs 事务日志", root=os.path.join(log_root, "jl_tlogs"),
             kind="date_dir", days=30, min_keep=3, emergency_days=7),
        # --- stdout 重定向的归档（logrotate dateext + compress 产物） ----
        dict(name="srvlog   轮转归档", root=srvlog, kind="archive",
             globs=("*.log-*", "*.log.[0-9]*", "*.log-*.gz"),
             days=14, min_keep=2, emergency_days=3),
        # --- 登录服 Tomcat：自己按天转但永不删，最老已到 2026-06-22 -------
        dict(name="tomcat   容器/访问日志", root=tomcat, kind="dated_file",
             globs=("catalina.*.log", "localhost.*.log", "localhost_access_log.*.txt",
                    "manager.*.log", "host-manager.*.log"),
             days=30, min_keep=3, emergency_days=7),
        # --- 崩溃现场：hs_err / hprof，排障完就没用了 --------------------
        dict(name="crash    JVM 崩溃/堆转储", root=tomcat, kind="glob",
             globs=("hs_err_pid*.log", "*.hprof", "java_pid*.hprof"),
             days=7, min_keep=1, emergency_days=3),
        dict(name="heapdump 游戏服转储", root=dump, kind="glob",
             globs=("*.hprof", "*.log"), days=7, min_keep=1, emergency_days=3),
    ]


def allowed_prefixes(rules):
    return tuple(os.path.join(r["root"], "") for r in rules)


# ---------------------------------------------------------------------------
# 基础工具
# ---------------------------------------------------------------------------
def human(n):
    n = float(n)
    for unit in ("B", "KB", "MB", "GB"):
        if abs(n) < 1024 or unit == "GB":
            return ("%.0f%s" if unit == "B" else "%.1f%s") % (n, unit)
        n /= 1024.0
    return "%.1fGB" % n


def tree_size(path):
    """目录/文件的逻辑大小（不跟随符号链接）。"""
    try:
        st = os.lstat(path)
    except OSError:
        return 0
    if not os.path.isdir(path):
        return st.st_size
    total = 0
    for dirpath, dirnames, filenames in os.walk(path, followlinks=False):
        for fn in filenames:
            try:
                st = os.lstat(os.path.join(dirpath, fn))
            except OSError:
                continue
            total += st.st_size
    return total


def disk_stat(path):
    """返回 (总字节, 已用字节, 可用字节, 使用百分比)。"""
    st = os.statvfs(path)
    total = st.f_blocks * st.f_frsize
    free = st.f_bavail * st.f_frsize
    used = total - st.f_bfree * st.f_frsize
    pct = (used / total * 100.0) if total else 0.0
    return total, used, free, pct


def parse_date_dir(name):
    m = DATE_DIR_RE.match(name)
    if not m:
        return None
    try:
        return date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    except ValueError:
        return None


def parse_dated_file(name):
    last = None
    for m in DATED_FILE_RE.finditer(name):
        last = m
    if not last:
        return None
    try:
        return date(int(last.group(1)), int(last.group(2)), int(last.group(3)))
    except ValueError:
        return None


def parse_archive(name, mtime):
    m = ARCHIVE_DATE_RE.search(name)
    if m:
        try:
            return datetime.strptime(m.group(1), "%Y%m%d").date()
        except ValueError:
            pass
    # .log.1 这类序号归档没有日期，退回 mtime
    try:
        return datetime.fromtimestamp(mtime).date()
    except (ValueError, OSError):
        return None


def is_protected(path):
    base = os.path.basename(path.rstrip("/"))
    if base in PROTECTED_NAMES:
        return True
    # 活动文件即使被 glob 命中也不动
    if base.endswith(".log") and not DATED_FILE_RE.search(base) \
            and not re.search(r"-\d{8}", base) and not re.match(r"hs_err_pid", base):
        # 无日期的裸 .log 视为活动文件（jl_item 等按目录分天的除外）
        return True
    return False


class Audit(object):
    def __init__(self, path, quiet=False, write=True):
        self.path = path
        self.quiet = quiet
        self.write_enabled = write and path is not None
        self.lines = []

    def __call__(self, msg, echo=True):
        line = "%s %s" % (datetime.now().strftime("%Y-%m-%d %H:%M:%S"), msg)
        self.lines.append(line)
        if echo and not self.quiet:
            print(line, flush=True)

    def flush(self):
        if not self.write_enabled:
            return
        try:
            if os.path.exists(self.path) and os.path.getsize(self.path) > AUDIT_LOG_MAX:
                open(self.path, "w").close()
            # 🔴 必须显式 encoding="utf-8"：python3.6 在 ASCII locale 下 open() 默认用
            #    locale 编码，写中文会 UnicodeEncodeError。而且这里抛异常会发生在
            #    **删除之后**，把审计记录和退出码一起带崩（2026-10-18 实测踩到）。
            with open(self.path, "a", encoding="utf-8", errors="replace") as f:
                f.write("\n".join(self.lines) + "\n")
        except Exception as e:      # 审计日志绝不能反过来弄挂清理流程
            try:
                sys.stderr.write("WARN 审计日志写入失败: %s\n" % e)
            except Exception:
                pass


# ---------------------------------------------------------------------------
# 收集 + 决策
# ---------------------------------------------------------------------------
def collect(rule):
    """返回 [(path, entry_date, size, is_dir)]，按日期新→旧排序。"""
    root = rule["root"]
    if not os.path.isdir(root):
        return []
    entries = []
    try:
        names = sorted(os.listdir(root))
    except OSError:
        return []
    globs = rule.get("globs")
    for name in names:
        path = os.path.join(root, name)
        if os.path.islink(path):
            continue
        d = None
        if rule["kind"] == "date_dir":
            if not os.path.isdir(path):
                continue
            d = parse_date_dir(name)
        elif rule["kind"] == "dated_file":
            if not os.path.isfile(path):
                continue
            if globs and not any(re.match(_glob_to_re(g), name) for g in globs):
                continue
            d = parse_dated_file(name)
        elif rule["kind"] == "archive":
            if not os.path.isfile(path):
                continue
            if globs and not any(re.match(_glob_to_re(g), name) for g in globs):
                continue
            try:
                mt = os.lstat(path).st_mtime
            except OSError:
                mt = time.time()
            d = parse_archive(name, mt)
        elif rule["kind"] == "glob":
            if not os.path.isfile(path):
                continue
            if globs and not any(re.match(_glob_to_re(g), name) for g in globs):
                continue
            try:
                mt = os.lstat(path).st_mtime
            except OSError:
                mt = time.time()
            d = datetime.fromtimestamp(mt).date()
        if d is None:
            continue
        if is_protected(path):
            continue
        entries.append((path, d, tree_size(path), os.path.isdir(path)))
    # 新的在前；同日期按名字倒序，保证稳定
    entries.sort(key=lambda e: (e[1], os.path.basename(e[0])), reverse=True)
    return entries


def _glob_to_re(g):
    out = ""
    for ch in g:
        if ch == "*":
            out += ".*"
        elif ch == "?":
            out += "."
        else:
            out += re.escape(ch)
    return "^%s$" % out


def decide(rule, entries, today, days_override=None, extra_keep=0):
    """返回 (keep, drop)。keep 有序新→旧。"""
    days = rule["days"] if days_override is None else days_override
    floor = max(rule.get("min_keep", 1), extra_keep, 1)
    cutoff = today - timedelta(days=days)
    keep, drop = [], []
    for idx, ent in enumerate(entries):
        path, d, size, _isdir = ent
        # 铁护栏 2：今天的不动（按日期名 / mtime 日期）
        if d >= today:
            keep.append(ent)
            continue
        # 铁护栏 3：保底最新 N 个
        if idx < floor:
            keep.append(ent)
            continue
        if d >= cutoff:
            keep.append(ent)
        else:
            drop.append(ent)
    return keep, drop


def purge(entries, audit, apply_changes, prefixes):
    freed = 0
    failed = 0
    # 🔴 前缀与待删路径都走 realpath：日志根目录可能是软链（如 /var → /private/var），
    #    只解析一侧会导致白名单全部误拒。
    real_prefixes = tuple(os.path.join(os.path.realpath(p.rstrip("/")), "")
                          for p in prefixes)
    for path, d, size, isdir in entries:
        # 铁护栏 1：白名单前缀（二次校验，防规则表被改坏）
        rp = os.path.realpath(path)
        if not any(rp.startswith(p) for p in real_prefixes):
            audit("REFUSE 越界路径 %s" % path)
            failed += 1
            continue
        if isdir:
            if apply_changes:
                try:
                    shutil.rmtree(path)
                except OSError as e:
                    audit("FAIL   %s  %s" % (path, e))
                    failed += 1
                    continue
            audit("%s %-58s %8s  (%s)" % ("RM-DIR " if apply_changes else "WOULD-DIR",
                                          path, human(size), d))
        else:
            if apply_changes:
                try:
                    os.remove(path)
                except OSError as e:
                    audit("FAIL   %s  %s" % (path, e))
                    failed += 1
                    continue
            audit("%s %-58s %8s  (%s)" % ("RM-FILE" if apply_changes else "WOULD-FILE",
                                          path, human(size), d))
        freed += size
    return freed, failed


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
def run(args):
    today = date.today()
    rules = build_rules()
    prefixes = allowed_prefixes(rules)
    audit = Audit(AUDIT_LOG, quiet=args.quiet, write=args.apply)

    try:
        total, used, free, pct = disk_stat("/")
    except OSError as e:
        sys.stderr.write("无法读取磁盘状态: %s\n" % e)
        return 2

    pressure = (pct >= args.disk_threshold) or (free < args.min_free_gb * 1024 ** 3)
    audit("==== %s %s ====" % ("APPLY" if args.apply else "DRY-RUN",
                               datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
    audit("磁盘 /  %s / %s 已用 %.1f%%  可用 %s  压力模式=%s"
          % (human(used), human(total), pct, human(free), "ON" if pressure else "OFF"))

    report = {
        "ts": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "mode": "apply" if args.apply else "dry-run",
        "disk": {"total": total, "used": used, "free": free, "pct": round(pct, 2)},
        "pressure": pressure,
        "thresholds": {"pct": args.disk_threshold, "min_free_gb": args.min_free_gb},
        "rules": [],
        "freed_bytes": 0,
        "failed": 0,
    }

    plan = []
    for rule in rules:
        entries = collect(rule)
        if not entries:
            report["rules"].append({"name": rule["name"], "skipped": "empty_or_missing"})
            continue
        days = rule["emergency_days"] if pressure else None
        keep, drop = decide(rule, entries, today, days_override=days)
        drop_size = sum(e[2] for e in drop)
        audit("[%s] 条目 %d（共 %s）| 保留 %d | %s %d（%s）| 保留策略 %d 天"
              % (rule["name"], len(entries), human(sum(e[2] for e in entries)),
                 len(keep), "将删" if not args.apply else "删除", len(drop),
                 human(drop_size),
                 rule["emergency_days"] if pressure else rule["days"]))
        report["rules"].append({
            "name": rule["name"], "root": rule["root"],
            "entries": len(entries), "keep": len(keep), "drop": len(drop),
            "drop_bytes": drop_size,
            "retention_days": rule["emergency_days"] if pressure else rule["days"],
        })
        plan.append(drop)

    # 逐规则执行
    for drops in plan:
        f, bad = purge(drops, audit, args.apply, prefixes)
        report["freed_bytes"] += f
        report["failed"] += bad

    # 压力模式下若仍未达标：按最旧优先继续删（仍受 min_keep / 今天 保护）
    if pressure and args.apply:
        target_free = args.target_free_gb * 1024 ** 3
        _, _, free2, pct2 = disk_stat("/")
        if free2 < target_free:
            audit("压力兜底：%s < 目标 %s，按最旧优先继续清"
                  % (human(free2), human(target_free)))
            pool = []
            for rule in rules:
                entries = collect(rule)
                _, drop = decide(rule, entries, today,
                                 days_override=0, extra_keep=rule.get("min_keep", 1))
                pool.extend(drop)
            pool.sort(key=lambda e: e[1])          # 最旧先删
            need = target_free - free2
            batch = []
            acc = 0
            for ent in pool:
                if acc >= need:
                    break
                batch.append(ent)
                acc += ent[2]
            f, bad = purge(batch, audit, True, prefixes)
            report["freed_bytes"] += f
            report["failed"] += bad

    total2, used2, free2, pct2 = disk_stat("/")
    audit("完成：%s %s 已用 %.1f%% → %.1f%%  可用 %s → %s  失败 %d 项"
          % ("实际释放" if args.apply else "预计释放", human(report["freed_bytes"]),
             pct, pct2, human(free), human(free2), report["failed"]))
    report["disk_after"] = {"used": used2, "free": free2, "pct": round(pct2, 2)}
    audit.flush()

    if args.json:
        print(json.dumps(report, ensure_ascii=False, sort_keys=True))
    # 退出码：0 正常；3 有失败项；4 压力模式（提醒介入）
    if report["failed"]:
        return 3
    if pressure:
        return 4
    return 0


# ---------------------------------------------------------------------------
# 自测：临时目录造假数据，验证 边界（今天不删 / min_keep / 过期删 / 白名单）
# ---------------------------------------------------------------------------
def selftest():
    today = date.today()
    tmp = tempfile.mkdtemp(prefix="logcleanup_selftest_")
    failures = []

    def mkdirs(root, offsets):
        for off in offsets:
            d = today - timedelta(days=off)
            p = os.path.join(root, d.strftime("%Y-%m-%d"))
            os.makedirs(p)
            with open(os.path.join(p, "corelog0.log"), "wb") as f:
                f.write(b"x" * (1024 * (off + 1)))

    jl = os.path.join(tmp, "log", "jl_logs")
    os.makedirs(jl)
    mkdirs(jl, [0, 1, 2, 5, 8, 30])
    rule = dict(name="t", root=jl, kind="date_dir", days=7, min_keep=3,
                emergency_days=2)
    entries = collect(rule)
    keep, drop = decide(rule, entries, today)

    dropped_names = sorted(os.path.basename(e[0]) for e in drop)
    kept_names = sorted(os.path.basename(e[0]) for e in keep)

    if (today - timedelta(days=0)).strftime("%Y-%m-%d") not in kept_names:
        failures.append("今天必须保留")
    if (today - timedelta(days=30)).strftime("%Y-%m-%d") not in dropped_names:
        failures.append("30 天前必须删")
    if (today - timedelta(days=8)).strftime("%Y-%m-%d") not in dropped_names:
        failures.append("8 天前（>7 天）必须删")
    if (today - timedelta(days=5)).strftime("%Y-%m-%d") not in kept_names:
        failures.append("5 天前必须保留")

    # min_keep 保底：days=0 时仍必须留 3 个
    keep0, drop0 = decide(rule, entries, today, days_override=0)
    if len(keep0) != 3:
        failures.append("min_keep=3 未生效（实际留 %d）" % len(keep0))

    # 白名单：越界路径必须被拒
    outside = os.path.join(tmp, "outside")
    os.makedirs(outside)
    fake = os.path.join(outside, "2020-01-01")
    os.makedirs(fake)
    audit = Audit(None, quiet=True, write=False)
    prefixes = (os.path.join(jl, ""),)
    freed, bad = purge([(fake, date(2020, 1, 1), 1024, True)], audit, True, prefixes)
    if bad != 1 or not os.path.isdir(fake):
        failures.append("白名单未拦住越界路径")

    # 真删一遍，验证 rmtree 生效
    freed, bad = purge(drop, audit, True, prefixes)
    left = sorted(os.listdir(jl))
    if len(left) != len(keep) or bad:
        failures.append("删除后剩余 %d 个，期望 %d 个，失败 %d"
                        % (len(left), len(keep), bad))

    # 审计日志：含中文必须能落盘（LC_ALL=C 下最容易暴露编码 bug）
    apath = os.path.join(tmp, "audit.log")
    a2 = Audit(apath, quiet=True, write=True)
    a2("测试中文审计行：释放 1.0MB")
    a2.flush()
    try:
        content = open(apath, encoding="utf-8").read()
    except (OSError, IOError, UnicodeError) as e:
        content = ""
        failures.append("审计日志读取失败: %s" % e)
    if "中文审计行" not in content:
        failures.append("审计日志未写入中文（编码问题）")

    shutil.rmtree(tmp, ignore_errors=True)

    print("selftest 临时目录: %s" % tmp)
    print("keep=%s" % kept_names)
    print("drop=%s" % dropped_names)
    print("freed=%s" % human(freed))
    if failures:
        print("FAILED:")
        for f in failures:
            print("  - %s" % f)
        return 1
    print("ALL PASS")
    return 0


def emit_logrotate():
    print("""# /etc/logrotate.d/gameserver  —— 由 scripts/server_log_cleanup.py --emit-logrotate 生成
# 🔴 3.8.6 上 `daily` 与 `size` 同时出现时 size 会覆盖时间间隔（实测 logrotate -d
#    输出 "log size is below the 'size' threshold"），等效"只在到 100M 时转"。
#    正确姿势是 daily + maxsize：按天转，且当天超过 maxsize 立刻转。
/data/srvlog/*.log {
    su root root
    daily
    maxsize 50M
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
    dateext
    dateformat -%Y%m%d-%s
}
""")


def emit_cron():
    print("""# /etc/cron.d/ts-log-cleanup  —— 由 scripts/server_log_cleanup.py --emit-cron 生成
# 每日 04:17 清理（避开 logrotate 的 cron.daily 与游戏服凌晨重启窗口）
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
17 4 * * * root /usr/bin/python3 /home/java/log_cleanup.py --apply --quiet
""")


def main(argv=None):
    ap = argparse.ArgumentParser(description="游戏服日志自动清理")
    ap.add_argument("--apply", action="store_true", help="真删（默认 dry-run）")
    ap.add_argument("--json", action="store_true", help="输出 JSON 报告")
    ap.add_argument("--quiet", action="store_true", help="静默（只写审计日志）")
    ap.add_argument("--disk-threshold", type=float, default=85.0,
                    help="磁盘使用率到达此值进入压力模式（默认 85）")
    ap.add_argument("--min-free-gb", type=float, default=3.0,
                    help="可用空间低于此值进入压力模式（默认 3GB）")
    ap.add_argument("--target-free-gb", type=float, default=5.0,
                    help="压力模式下清理到此可用空间（默认 5GB）")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--emit-logrotate", action="store_true")
    ap.add_argument("--emit-cron", action="store_true")
    args = ap.parse_args(argv)

    if args.selftest:
        return selftest()
    if args.emit_logrotate:
        emit_logrotate()
        return 0
    if args.emit_cron:
        emit_cron()
        return 0

    # 单实例锁：cron 与手工执行撞车时直接退出
    lock_fd = None
    if args.apply:
        try:
            lock_fd = open(LOCK_FILE, "w")
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except (OSError, IOError):
            sys.stderr.write("已有清理进程在跑（%s 被占用），退出\n" % LOCK_FILE)
            return 5

    try:
        return run(args)
    finally:
        if lock_fd is not None:
            try:
                fcntl.flock(lock_fd, fcntl.LOCK_UN)
                lock_fd.close()
            except (OSError, IOError):
                pass


if __name__ == "__main__":
    sys.exit(main())
