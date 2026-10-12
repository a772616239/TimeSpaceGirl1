#!/usr/local/bin/bash
# =============================================================================
# local_shard.sh —— 本地新区服 10002「庇护所九号」状态体检（**只读**）
#
# 10002 是本机 Mac 上用 frp 内网穿透对外提供的一个内测区服，它跟远端生产服是两套东西，
# 所以巡检/概览里要单独看它一眼。这个脚本只「看」，不 start/stop（起停另有 shard.sh）。
#
# 为什么复用 `~/ts-shard10002/shard.sh status` 而不是自己 pgrep：
# 那个脚本是 10002 的权威运维入口（它知道 JAR 名、端口、日志路径、以及 macOS 上
# 「必须走 detach.sh 而不能用 nohup」这类本机专属坑）。这里只做编排与结论化。
#
# 用法：.jenkins/lib/checks/local_shard.sh
# 退出码：0 在跑且端口在听；1 没跑或端口没听；2 环境错误（脚本目录不存在）
# =============================================================================
set -uo pipefail

SHARD="${SHARD:-$HOME/ts-shard10002}"
PORT="${SHARD_PORT:-16081}"
[[ -d "$SHARD" ]] || { echo "找不到 10002 区服目录：$SHARD" >&2; exit 2; }

FAIL=0
echo "── 进程 / 端口 ────────────────────────────────────"

if [[ -x "$SHARD/shard.sh" ]]; then
  "$SHARD/shard.sh" status 2>&1 | sed 's/^/   /' || true
else
  echo "   · $SHARD/shard.sh 不可用"
fi

# 游戏服进程（JAR 名与生产服同名，靠 cwd 区分不了，这里只看有没有）
if pgrep -f "gameSrv-1.0.0.jar" >/dev/null 2>&1; then
  echo "   ✓ 本机有 gameSrv 进程：$(pgrep -f 'gameSrv-1.0.0.jar' | tr '\n' ' ')"
else
  echo "   ✗ 本机没有 gameSrv 进程 —— 10002 未在运行"
  FAIL=1
fi

# 端口是否在监听（用 lsof，macOS 上比 ss 可靠）
if command -v lsof >/dev/null 2>&1; then
  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "   ✓ 端口 ${PORT} 正在监听"
  else
    echo "   ✗ 端口 ${PORT} 未监听"
    FAIL=1
  fi
fi

echo "── 内网穿透（frp）────────────────────────────────"
if pgrep -f "frpc" >/dev/null 2>&1; then
  echo "   ✓ frpc 在跑：$(pgrep -f frpc | tr '\n' ' ')"
else
  echo "   ✗ frpc 没在跑 —— 外网连不上 10002"
  FAIL=1
fi

echo "── 登录库区服记录的本地备份 ───────────────────────"
# 权威记录在远端登录库 `x1_cn_test_login.server_info` 的 `_id:2`：
# state=0/-1 → 不下发（隐藏）；state=2 → 显示。
# 这里**故意不查远端**，保持本脚本纯本机、秒级、可离线跑；只陈列本机备份，
# 让人一眼看出最近有没有动过。要看线上真实 state，用：
#   ~/ts-shard10002/add-shard-10002.sh status
shopt -s nullglob
BACKUPS=("$SHARD"/server_info_id2*.json)
shopt -u nullglob
if [[ ${#BACKUPS[@]} -eq 0 ]]; then
  echo "   · 没有 server_info_id2*.json 备份"
else
  echo "   本机备份 ${#BACKUPS[@]} 份（新→旧，最多列 6）："
  ls -1t "${BACKUPS[@]}" | head -6 | while IFS= read -r f; do
    printf '       %s  (%s)\n' "${f##*/}" "$(stat -f%Sm -t '%Y-%m-%d %H:%M' "$f")"
  done
  for f in "${BACKUPS[@]}"; do
    if [[ "${f##*/}" == *hidden-backup* ]]; then
      echo "   · 存在 hidden-backup ⇒ 用过 add-shard-10002.sh hide"
      break
    fi
  done
fi

echo
if [[ $FAIL -eq 0 ]]; then
  echo "✅ 10002 区服在跑，端口与穿透正常"
else
  echo "⚠️ 10002 区服有项不满足（若本次不打算开 10002，可忽略）"
fi
exit $FAIL
