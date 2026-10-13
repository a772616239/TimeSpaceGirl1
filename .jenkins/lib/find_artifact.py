#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""定位「这次构建产出的」构件（AAB / APK / sidecar）。

为什么不用 `ls -t | head -1`
---------------------------
两个都很实际的原因：
1. `ls -t ... | head -1` 在 `set -o pipefail` 下会因为 head 提前退出把 ls 打成
   SIGPIPE(141)，于是整条命令「看起来失败了」（本项目踩过，见 docs/scripts_reference.md）。
2. 更重要的：`ls -t` 拿的是「当前最新的」，**不保证是本次构建产出的**。
   如果 Unity 因为前置检查失败没出包，`ls -t` 会兴高采烈地把上一次的旧包交出来，
   后面的校验环节于是全绿 —— 校验的是昨天那个包。这是最危险的一类假通过。
   所以这里强制用 `--after <构建开始时间>` 过滤：**本次没产出就报错，而不是回退到旧包**。

用法：
    find_artifact.py <glob> --after <epoch秒> [--out <写路径的文件>] [--allow-stale]

退出码：0 找到并打印路径；1 没找到（本次未产出）；2 用法错误
"""
from __future__ import annotations

import argparse
import glob
import os
import sys


def main() -> int:
    ap = argparse.ArgumentParser(description="按 mtime 定位本次构建产出的构件")
    ap.add_argument("pattern", help="相对工程根的 glob，例如 'apks/*/CLIBuild/*.aab'")
    ap.add_argument("--root", default=".", help="工程根（默认当前目录）")
    ap.add_argument("--after", type=float, default=0.0,
                    help="只认 mtime >= 该 epoch 秒的产物（构建开始时间）")
    ap.add_argument("--out", default=None, help="把结果同时写进这个文件")
    ap.add_argument("--allow-stale", action="store_true",
                    help="找不到本次产物时，允许退回最新旧产物（**默认禁止**）")
    args = ap.parse_args()

    os.chdir(args.root)
    allm = glob.glob(args.pattern)
    if not allm:
        print("找不到任何匹配 %s 的文件" % args.pattern, file=sys.stderr)
        return 1

    fresh = [p for p in allm if os.path.getmtime(p) >= args.after]
    if fresh:
        pick = max(fresh, key=os.path.getmtime)
    elif args.allow_stale:
        pick = max(allm, key=os.path.getmtime)
        print("⚠️ 本次构建没有新产物，回退到最新旧产物：%s" % pick, file=sys.stderr)
    else:
        print("🔴 本次构建没有产出匹配 %s 的新文件（拒绝回退到旧产物，避免校验错对象）"
              % args.pattern, file=sys.stderr)
        newest = max(allm, key=os.path.getmtime)
        print("   （现存最新的是 %s，mtime=%s）"
              % (newest, int(os.path.getmtime(newest))), file=sys.stderr)
        return 1

    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(pick + "\n")
    print(pick)
    return 0


if __name__ == "__main__":
    sys.exit(main())
