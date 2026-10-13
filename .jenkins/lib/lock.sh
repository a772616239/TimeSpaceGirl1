#!/usr/local/bin/bash
# =============================================================================
# lock.sh —— 命名互斥锁的 shell 前端
#
# 真正的实现全在 **lock.py**（基于 `flock(2)`：进程退出内核自动释放，
# 因此不存在「崩了就永久锁死」和「陈旧锁判定」，也不需要删除任何文件）。
# 这里只做一层转发，方便 Shell / Pipeline 里以 `lock.sh --name play run -- …`
# 这种更顺手的写法调用，避免每处都重复写 python 绝对路径。
#
# 语义与退出码完全等同 lock.py，重点记住一个：
#     **75 = 拿不到锁（忙）**，调用方应据此判「跳过」而不是「失败」。
#
# 用法：
#   .jenkins/lib/lock.sh --name play run [--timeout 1800] [--who 说明] -- <命令…>
#   .jenkins/lib/lock.sh --name play test      # 探活：空闲 rc=0，忙 rc=75
#   .jenkins/lib/lock.sh --name play status
# =============================================================================
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="${TS_PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
exec "$PY" "$HERE/lock.py" "$@"
