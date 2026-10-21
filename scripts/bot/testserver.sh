#!/usr/bin/env bash
# 测试服联调：三条 SSH 隧道 + 本地控制台
#
#   ./testserver.sh up        建隧道（GM / Redis 正向，DSH 反向）
#   ./testserver.sh down      断隧道
#   ./testserver.sh status    探活（隧道 / Redis PING / 桥接 / 控制台）
#   ./testserver.sh console   起控制台（自动带上隧道端口和 serverId）
#   ./testserver.sh open      探活 + 起控制台 + 打印地址
#
# 为什么需要三条：
#   测试服 129.226.213.65 上 7916(GM) 和 6379(Redis) 都只监听 127.0.0.1，外网进不去；
#   而 DSH 桥接必须跑在有模型的机器（本机 Mac）上，游戏服要能回连 ⇒ 反向隧道把
#   测试服的 127.0.0.1:18765 打到本机 18765。
#
#   本机 17916 ──正向──▶ 测试服 127.0.0.1:7916   (bot 命令)
#   本机 16379 ──正向──▶ 测试服 127.0.0.1:6379   (在线数/聊天队列/BOT_STATUS)
#   测试服 18765 ◀─反向── 本机 127.0.0.1:18765  (DSH 桥接)
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HERE/logs"
mkdir -p "$LOG_DIR"

SSH_HOST="${TS_SSH_HOST:-gs}"
GM_LOCAL="${TS_GM_PORT:-17916}"
REDIS_LOCAL="${TS_REDIS_PORT:-16379}"
BRIDGE_LOCAL="${TS_BRIDGE_PORT:-18765}"
CONSOLE_PORT="${TS_CONSOLE_PORT:-18766}"

start_one() { # name, extra ssh args...
  local name="$1"; shift
  local pidf="$LOG_DIR/tunnel-$name.pid"
  if [ -f "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; then
    echo "  $name 已在跑 (pid $(cat "$pidf"))"; return 0
  fi
  ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 "$@" "$SSH_HOST" \
    >>"$LOG_DIR/tunnel-$name.log" 2>&1 &
  echo $! >"$pidf"
  sleep 0.6
  if kill -0 "$(cat "$pidf")" 2>/dev/null; then echo "  $name ok (pid $(cat "$pidf"))"; else echo "  $name 失败，看 $LOG_DIR/tunnel-$name.log"; fi
}

stop_one() {
  local name="$1"; local pidf="$LOG_DIR/tunnel-$name.pid"
  if [ -f "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; then
    kill "$(cat "$pidf")" 2>/dev/null && echo "  $name 已断"; rm -f "$pidf"
  else
    echo "  $name 未运行"
  fi
}

probe() { nc -z -G 2 127.0.0.1 "$1" >/dev/null 2>&1 && echo up || echo down; }

case "${1:-status}" in
  up)
    echo "建立隧道 → $SSH_HOST"
    start_one gm    -L "${GM_LOCAL}:127.0.0.1:7916"
    start_one redis -L "${REDIS_LOCAL}:127.0.0.1:6379"
    start_one bridge -R "${BRIDGE_LOCAL}:127.0.0.1:${BRIDGE_LOCAL}"
    ;;
  down)
    echo "断开隧道"
    stop_one gm; stop_one redis; stop_one bridge
    ;;
  status)
    echo "隧道："
    echo "  gm     :$GM_LOCAL    $(probe "$GM_LOCAL")"
    echo "  redis  :$REDIS_LOCAL $(probe "$REDIS_LOCAL")"
    echo "  bridge :$BRIDGE_LOCAL $(probe "$BRIDGE_LOCAL")"
    if [ "$(probe "$REDIS_LOCAL")" = up ]; then
      echo -n "  redis PING: "; redis-cli -p "$REDIS_LOCAL" ping 2>/dev/null || echo fail
      echo -n "  在线键: "; redis-cli -p "$REDIS_LOCAL" keys 'ONLINE_NUM:*' 2>/dev/null | tr '\n' ' '; echo
    fi
    echo -n "  桥接健康: "; curl -s --noproxy '*' -m 3 "http://127.0.0.1:$BRIDGE_LOCAL/health" || echo "(无)"
    echo
    echo -n "  控制台   :$CONSOLE_PORT $(probe "$CONSOLE_PORT")"
    echo
    ;;
  console)
    TS_GM_PORT="$GM_LOCAL" TS_REDIS_PORT="$REDIS_LOCAL" TS_BRIDGE_URL="http://127.0.0.1:$BRIDGE_LOCAL" \
      "$HERE/start_console.sh" start
    echo "→ http://127.0.0.1:$CONSOLE_PORT/"
    ;;
  open)
    "$0" up
    "$0" status
    "$0" console
    ;;
  *)
    echo "usage: $0 {up|down|status|console|open}"; exit 1;;
esac
