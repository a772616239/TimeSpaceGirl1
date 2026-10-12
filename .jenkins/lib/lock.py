#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""跨 job 的命名互斥锁（基于 flock，不依赖任何 Jenkins 插件）。

为什么需要它
------------
两件真实事故决定了必须有**跨 job** 的互斥，而不是各自 job 里 `disableConcurrentBuilds`：

1) **Play API** —— 2026-10-12：`play_upload.py` 正把 421MB 的 AAB 传到 85% 时，另一个进程
   （16KB 巡检）开了新的 Play edit ⇒ 上传中的 edit 被判 `This Edit has been deleted`
   （HTTP 400 / FAILED_PRECONDITION），整包白传。Play 的 `edits` 是**全局排他**的，
   同一开发者账号同时只能有一个活动 edit。
2) **Unity 工程** —— 同一 Unity 工程不能有第二个 batchmode 实例（工程锁
   `Library/SourceAssetDB-lock`），并发打包会直接失败或产出脏包。

`disableConcurrentBuilds` 只能挡住「同一个 job 的自己」，挡不住「两个不同 job 抢同一个共享资源」；
本机 Jenkins 没装 lockable-resources，所以自己实现一把。

为什么用 flock 而不是 `mkdir` 锁
--------------------------------
`mkdir` 方案要靠 `rmdir` 释放，于是必然要处理「谁负责删」「崩了不删就永久锁死」「陈旧锁判定」
三件事，而且**只要文件系统上出现删除动作就多一类误操作风险**。
`flock(2)` 把这三件事都交给内核：进程一退出（含被 kill -9）锁自动释放，
不存在陈旧锁，也不需要删除任何文件。锁文件建一次就一直在，只当握手点用。

代价：flock 是「随打开的文件描述符存活」，所以**必须在持锁期间把命令跑完** ——
这就是 `run` 子命令存在的理由。多步骤的持锁（例如「上传」要跑好几条命令）请把它们
合成一条命令，或用 `lock.sh` 包一层。

用法
----
    lock.py run   --name play [--timeout 1800] [--who 说明] -- <命令...>
    lock.py test  --name play                  # 只试拿一下，立刻释放（探活）
    lock.py status --name play

退出码
------
    0    命令本身成功
    75   拿不到锁（EX_TEMPFAIL，「忙，稍后再试」）—— **Pipeline 里据此判为「跳过」而非失败**
    其他 命令自身的退出码（原样透传）
    64   用法错误

注意 75 是刻意选的：它与本项目脚本的 `1=校验不过 / 2=参数 / 3=认证 / 4=API / 5=撞车`
都不冲突，调用方可以无歧义地区分「被锁挡住」和「真的挂了」。
"""
from __future__ import annotations

import argparse
import fcntl
import os
import subprocess
import sys
import time

EX_TEMPFAIL = 75
EX_USAGE = 64


def repo_root() -> str:
    return os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def lock_path(name: str) -> str:
    d = os.path.join(repo_root(), ".jenkins", "run")
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, "%s.lock" % name)


def try_lock(fh) -> bool:
    try:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except OSError:
        return False


def who_holds(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as fh:
            line = fh.readline().strip()
        return line or "（无归属信息）"
    except OSError:
        return "（读不到归属信息）"


def stamp(fh, who: str) -> None:
    fh.seek(0)
    fh.truncate()
    fh.write("%s\t%s\t%d\n" % (os.getpid(), who, time.time()))
    fh.flush()


def cmd_run(args) -> int:
    path = lock_path(args.name)
    fh = open(path, "a+")            # 锁文件常驻，从不删除
    deadline = time.time() + args.timeout
    waited_msg = False
    while True:
        if try_lock(fh):
            break
        if time.time() >= deadline:
            print("\033[1;33m   ⏭ [%s] 锁被占用（%s），本次跳过\033[0m"
                  % (args.name, who_holds(path)))
            return EX_TEMPFAIL
        if not waited_msg:
            print("\033[1;33m   ⏳ [%s] 锁被占用（%s），排队等待…\033[0m"
                  % (args.name, who_holds(path)))
            waited_msg = True
        time.sleep(5)
    stamp(fh, args.who)
    print("\033[1;32m   🔒 [%s] 锁已获得（%s）\033[0m" % (args.name, args.who))
    try:
        rc = subprocess.call(args.cmd)
    except FileNotFoundError as e:
        print("lock.py: 找不到命令 %s" % (e,), file=sys.stderr)
        return 127
    finally:
        try:
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
        except OSError:
            pass
        fh.close()
    print("\033[1;32m   🔓 [%s] 锁已释放\033[0m" % args.name)
    return rc


def cmd_test(args) -> int:
    path = lock_path(args.name)
    fh = open(path, "a+")
    if not try_lock(fh):
        print("忙（持有者：%s）" % who_holds(path))
        fh.close()
        return EX_TEMPFAIL
    print("空闲")
    fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
    fh.close()
    return 0


def cmd_status(args) -> int:
    path = lock_path(args.name)
    fh = open(path, "a+")
    if try_lock(fh):
        print("空闲")
        fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
        rc = 0
    else:
        print("持有中：%s" % who_holds(path))
        rc = 0
    fh.close()
    return rc


def main() -> int:
    # `--name` 允许出现在任意位置（含子命令之前）：手动先摘出来。
    # 必须在 `--` 处停止扫描，否则会把「要执行的命令自己的 --name 参数」也吃掉。
    argv, name, i = [], None, 0
    raw = sys.argv[1:]
    while i < len(raw):
        a = raw[i]
        if a == "--":
            argv.extend(raw[i:])
            break
        if a == "--name":
            name = raw[i + 1] if i + 1 < len(raw) else None
            i += 2
            continue
        if a.startswith("--name="):
            name = a.split("=", 1)[1]
            i += 1
            continue
        argv.append(a)
        i += 1

    ap = argparse.ArgumentParser(add_help=True, description="命名互斥锁（flock）")
    sub = ap.add_subparsers(dest="sub", required=True)

    r = sub.add_parser("run", help="持锁跑一条命令")
    r.add_argument("--timeout", type=int, default=1800,
                   help="等锁上限秒数（默认 1800；给 0 = 不等，忙就直接跳过）")
    r.add_argument("--who", default="%s/%d" % (os.uname().nodename.split(".")[0], os.getpid()))
    r.add_argument("cmd", nargs=argparse.REMAINDER)
    r.set_defaults(func=cmd_run)

    t = sub.add_parser("test", help="只试探，不执行命令")
    t.set_defaults(func=cmd_test)

    s = sub.add_parser("status", help="看锁状态")
    s.set_defaults(func=cmd_status)

    args = ap.parse_args(argv)
    if not name:
        print("lock.py: 必须给 --name <锁名>", file=sys.stderr)
        return EX_USAGE
    args.name = name

    if args.sub == "run":
        cmd = list(args.cmd)
        if cmd and cmd[0] == "--":
            cmd = cmd[1:]
        if not cmd:
            print("lock.py run: 缺少要执行的命令（用 -- 分隔）", file=sys.stderr)
            return EX_USAGE
        args.cmd = cmd
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
