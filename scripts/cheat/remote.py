#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""远端执行层：SSH / Mongo / Redis 的唯一出口。

为什么单独一层：作弊脚本要在「本地 Python」和「线上 CentOS7 的 mongo 2.x shell / 老版
redis-cli」之间来回，转义、超时、编码三大坑都集中在这里处理，上层只跟 dict/list 打交道。

约定：
  - mongo 脚本用「stdin 写临时文件 → mongo 读文件」，避开所有 shell 转义；
  - 脚本函数体 `return` 一个可 JSON 化的值，本层负责解出最后一行 JSON；
  - 所有命令走 BatchMode，不交互；超时默认 180s（全服扫描够用）。
"""
import json
import os
import subprocess
import sys


class RemoteError(RuntimeError):
    pass


class Remote(object):
    """一台游戏服（默认 SSH 别名 `gs`）的执行句柄。"""

    def __init__(self, host=None, game_db=None, login_db=None,
                 redis_db='0', key_prefix=None, ssh_timeout=180):
        self.host = host or os.environ.get('GS_SSH_HOST', 'gs')
        self.game_db = game_db or os.environ.get('GS_GAME_DB', 'm5_x1_game_10001')
        self.login_db = login_db or os.environ.get('GS_LOGIN_DB', 'x1_cn_test_login')
        self.redis_db = redis_db or os.environ.get('GS_REDIS_DB', '0')
        self.key_prefix = key_prefix or os.environ.get('GS_REDIS_PREFIX', '10001:')
        self.timeout = ssh_timeout
        self._seq = 0

    # ---------------------------------------------------------------- shell
    def sh(self, cmd, timeout=None, stdin=None, check=False):
        """在远端跑一条 shell 命令，返回 (rc, stdout, stderr)。"""
        try:
            p = subprocess.run(
                ['ssh', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=15',
                 self.host, cmd],
                input=stdin, capture_output=True, text=True,
                timeout=timeout or self.timeout)
        except subprocess.TimeoutExpired:
            if check:
                raise RemoteError('ssh timeout: %s' % cmd[:120])
            sys.stderr.write('[warn] ssh timeout: %s\n' % cmd[:120])
            return 124, '', 'timeout'
        except OSError as e:
            raise RemoteError('ssh 不可用: %s' % e)
        if check and p.returncode != 0:
            raise RemoteError('ssh rc=%d: %s' % (p.returncode, (p.stderr or '')[:300]))
        return p.returncode, p.stdout or '', p.stderr or ''

    def out(self, cmd, timeout=None):
        """只取 stdout（失败给空串），适合 redis-cli 这类单值命令。"""
        return self.sh(cmd, timeout=timeout)[1].strip()

    # ---------------------------------------------------------------- mongo
    def mongo(self, js, db=None, timeout=None, required=False):
        """执行一段 mongo JS（函数体 return 可 JSON 化对象），返回 Python 对象。"""
        self._seq += 1
        path = '/tmp/_cheat_%d_%d.js' % (os.getpid(), self._seq)
        wrapped = ('var __out=(function(){\n%s\n})();\n'
                   'print(JSON.stringify(__out));\n') % js
        cmd = 'cat > %s && mongo --quiet %s %s; rc=$?; rm -f %s; exit $rc' % (
            path, db or self.game_db, path, path)
        rc, stdout, stderr = self.sh(cmd, timeout=timeout, stdin=wrapped)
        for line in reversed((stdout or '').strip().splitlines()):
            line = line.strip()
            if line.startswith('{') or line.startswith('['):
                try:
                    return json.loads(line)
                except ValueError:
                    continue
        if required:
            raise RemoteError('mongo 无有效输出 rc=%d: %s' % (rc, (stderr or '')[:300]))
        if rc != 0:
            sys.stderr.write('[warn] mongo rc=%d: %s\n' % (rc, (stderr or '')[:300]))
        return None

    def mongo_eval(self, js, db=None, timeout=None):
        """执行无返回值的写脚本（$unset/$set/deleteMany…）。"""
        return self.mongo('var __ok=0;\n' + js + '\nreturn {ok:true};',
                          db=db, timeout=timeout, required=True)

    def export(self, coll, query, dest, db=None):
        """mongoexport 单集合（query 走 queryFile，避免 shell 转义）。"""
        self._seq += 1
        base = '/tmp/_cheat_q_%d_%d.json' % (os.getpid(), self._seq)
        cmd = ('printf %%s %s > %s && mongoexport -d %s -c %s --queryFile %s -o %s; '
               'rc=$?; rm -f %s; exit $rc'
               % ("'%s'" % json.dumps(query, separators=(',', ':')), base,
                  db or self.game_db, coll, base, dest, base))
        rc, _, err = self.sh(cmd)
        return rc == 0, err.strip()

    # ---------------------------------------------------------------- redis
    def redis(self, *args, timeout=60):
        cmd = 'redis-cli -n %s %s' % (self.redis_db, ' '.join(args))
        return self.out(cmd, timeout=timeout)

    def redis_lines(self, *args, timeout=120):
        return [x for x in self.redis(*args, timeout=timeout).splitlines() if x.strip()]

    def rkey(self, name):
        return '%s%s' % (self.key_prefix, name)

    def scan(self, pattern, limit=None):
        args = ['--scan', '--pattern', '"%s"' % pattern]
        keys = self.redis_lines(*args)
        return keys[:limit] if limit else keys

    def zset_members_like(self, key, prefix, count=1000):
        """ZSCAN 按成员前缀捞（复合成员 `uid:heroId` 也能精确命中）。"""
        found, cursor, guard = [], '0', 0
        while True:
            raw = self.redis('ZSCAN', '"%s"' % key, cursor, 'MATCH',
                             '"%s*"' % prefix, 'COUNT', str(count))
            lines = [x.strip() for x in raw.splitlines() if x.strip()]
            cursor = lines[0] if lines else '0'
            for i in range(1, len(lines) - 1, 2):
                found.append(lines[i])
            guard += 1
            if cursor == '0' or guard > 200:
                break
        return sorted(set(found))

    def rank_members(self, uid, patterns=None):
        """一次 SSH 往返扫出该 uid 在所有榜单里的成员。

        为什么不在 Python 里逐 key 调 redis-cli：db0 有 6000+ key、其中 *ARENA* 195 个，
        每次 redis-cli 都是一次进程启动，逐 key 调用会把 20 秒的活拖成 5 分钟。
        这里把整个循环塞进远端一次 shell，只回传命中行（`KEY|member`）。

        ⚠️ 只扫 `*RANK*` / `*ARENA*`：`*RECORD*`（3720 个）是各玩家自己的历史成绩，
        别人不会出现在你的 RECORD 里，清它既无意义又很慢。
        """
        uid = str(uid)
        patterns = patterns or ['%s*RANK*' % self.key_prefix, '%s*ARENA*' % self.key_prefix]
        pcs = ' '.join('"%s"' % p for p in patterns)
        script = ('for p in %s; do '
                  'for k in $(redis-cli -n %s --scan --pattern "$p"); do '
                  '[ "$(redis-cli -n %s TYPE "$k")" = "zset" ] || continue; '
                  'redis-cli -n %s ZRANGE "$k" 0 -1 | grep -E "^%s(:|$)" | '
                  'while read -r m; do echo "$k|$m"; done; '
                  'done; done') % (pcs, self.redis_db, self.redis_db, self.redis_db, uid)
        out = self.sh(script, timeout=180)[1]
        hits = {}
        for line in out.splitlines():
            if '|' not in line:
                continue
            key, member = line.split('|', 1)
            hits.setdefault(key.strip(), []).append(member.strip())
        return hits

    def hgetall(self, key):
        lines = self.redis_lines('HGETALL', '"%s"' % key)
        return dict(zip(lines[0::2], lines[1::2]))

    def all_rank_members(self, patterns=None):
        """把**全部**榜单成员一次抓回（key → [member,...]），用于完整性体检。

        与 `rank_members(uid)` 的区别：不带 uid 前缀过滤，扫全榜。
        同样整段塞进远端一个 shell，避免 ~90 次 redis-cli 进程启动。
        """
        patterns = patterns or ['%s*RANK*' % self.key_prefix,
                                '%s*ARENA*' % self.key_prefix]
        pcs = ' '.join('"%s"' % p for p in patterns)
        script = ('for p in %s; do '
                  'for k in $(redis-cli -n %s --scan --pattern "$p"); do '
                  '[ "$(redis-cli -n %s TYPE "$k")" = "zset" ] || continue; '
                  'redis-cli -n %s ZRANGE "$k" 0 -1 | '
                  'while read -r m; do echo "$k|$m"; done; '
                  'done; done') % (pcs, self.redis_db, self.redis_db, self.redis_db)
        out = self.sh(script, timeout=240)[1]
        members = {}
        for line in out.splitlines():
            if '|' not in line:
                continue
            key, member = line.split('|', 1)
            key, member = key.strip(), member.strip()
            if not key or not member:
                continue
            members.setdefault(key, []).append(member)
        return members

    def zrem_batch(self, pairs, chunk=200):
        """批量 ZREM（按 key 分组，一条 redis-cli 可带多个成员），返回实际删除数。"""
        by_key = {}
        for key, member in pairs:
            by_key.setdefault(key, []).append(member)
        lines = []
        for key, ms in by_key.items():
            for i in range(0, len(ms), chunk):
                args = ' '.join('"%s"' % m for m in ms[i:i + chunk])
                lines.append('redis-cli -n %s ZREM "%s" %s'
                             % (self.redis_db, key, args))
        if not lines:
            return 0
        out = self.sh('\n'.join(lines), timeout=180)[1]
        return sum(int(x.strip()) for x in out.splitlines() if x.strip().isdigit())

    # ---------------------------------------------------------------- 文件
    def read_file(self, path, limit_bytes=None):
        """读远端文本（BI 文件日志用）；不存在返回空串。"""
        cmd = 'test -f %s && head -c %s %s || true' % (
            path, limit_bytes or 20 * 1024 * 1024, path)
        return self.sh(cmd, timeout=180)[1]

    def list_files(self, path, limit=200):
        return [x for x in self.out('ls -1 %s 2>/dev/null | head -%d' % (path, limit),
                                    timeout=60).splitlines() if x.strip()]

    def mkdir(self, path):
        self.sh('mkdir -p %s' % path, timeout=60)


def js_int(v):
    """mongo 里 $numberLong 会被序列化成 {'$numberLong': '...'}。"""
    if isinstance(v, dict):
        v = v.get('$numberLong', v.get('$numberInt', 0))
    try:
        return int(v or 0)
    except (TypeError, ValueError):
        return 0
