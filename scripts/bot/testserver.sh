#!/usr/bin/env bash
# 测试服联调：SSH 隧道 + 本地控制台
#
#   ./testserver.sh up        建隧道（GM / Redis 正向，DSH 反向，单连接三条转发）
#   ./testserver.sh fg        前台挂隧道（另开一个终端窗口常驻，最可靠）
#   ./testserver.sh down      断隧道
#   ./testserver.sh status    探活（隧道 / Redis PING / 反向回连 / 控制台）
#   ./testserver.sh console   起控制台（自动带上隧道端口和 serverId）
#   ./testserver.sh open      探活 + 起控制台 + 打印地址
#
# 为什么需要三条转发：
#   测试服 129.226.213.65 上 7916(GM) 和 6379(Redis) 都只监听 127.0.0.1，外网进不去；
#   而 DSH 桥接必须跑在有模型的机器（本机 Mac）上，游戏服要能回连 ⇒ 反向转发把
#   测试服的 127.0.0.1:18765 打到本机 18765。
#
#   本机 17916 ──正向──▶ 测试服 127.0.0.1:7916   (bot 命令)
#   本机 16379 ──正向──▶ 测试服 127.0.0.1:6379   (在线数/聊天队列/BOT_STATUS)
#   测试服 18765 ◀─反向── 本机 127.0.0.1:18765  (DSH 桥接)
#
# 注意：三条转发放在【一个】ssh 连接里，不要拆成三个后台 ssh。
#   拆开时进程容易在父 shell 退出后被回收，出现「pid 还在但端口不通」的假活；
#   单连接下 ExitOnForwardFailure=yes 能保证任何一条转发失败就整体退出，状态可判。
#
#   还有一层坑：某些环境（IDE 里跑的 AI 会话、被托管的子 shell）会在命令返回后
#   回收它拉起的后台进程，`up` 报 ok 但 3 秒后端口就 down。这种情况用 `fg`
#   在前台挂着（另开一个终端窗口，或 tmux/screen 里跑），进程跟着那个终端活。
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HERE/logs"
mkdir -p "$LOG_DIR"

SSH_HOST="${TS_SSH_HOST:-gs}"
GM_LOCAL="${TS_GM_PORT:-17916}"
REDIS_LOCAL="${TS_REDIS_PORT:-16379}"
BRIDGE_LOCAL="${TS_BRIDGE_PORT:-18765}"
CONSOLE_PORT="${TS_CONSOLE_PORT:-18766}"
PID_FILE="$LOG_DIR/tunnel.pid"
LOG="$LOG_DIR/tunnel.log"

tunnel_alive() { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }
probe() { nc -z -G 2 127.0.0.1 "$1" >/dev/null 2>&1 && echo up || echo down; }

TUNNEL_ARGS=(
  -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3
  -L "${GM_LOCAL}:127.0.0.1:7916"
  -L "${REDIS_LOCAL}:127.0.0.1:6379"
  -R "${BRIDGE_LOCAL}:127.0.0.1:${BRIDGE_LOCAL}"
)

case "${1:-status}" in
  up)
    if tunnel_alive && [ "$(probe "$GM_LOCAL")" = up ]; then
      echo "隧道已在跑 (pid $(cat "$PID_FILE"))"; exit 0
    fi
    echo "建立隧道 → $SSH_HOST"
    ssh "${TUNNEL_ARGS[@]}" "$SSH_HOST" >>"$LOG" 2>&1 &
    echo $! >"$PID_FILE"
    sleep 2
    if tunnel_alive && [ "$(probe "$GM_LOCAL")" = up ]; then
      echo "  ok pid=$(cat "$PID_FILE")  gm:$GM_LOCAL redis:$REDIS_LOCAL bridge:$BRIDGE_LOCAL"
    else
      echo "  失败或被父 shell 回收（gm 端口 $(probe "$GM_LOCAL")）"
      tail -3 "$LOG" 2>/dev/null
      rm -f "$PID_FILE"
      echo "  → 改用 ./testserver.sh fg 在另一个终端窗口前台挂着"
      exit 1
    fi
    ;;
  fg)
    echo "前台挂隧道（Ctrl-C 结束）→ $SSH_HOST"
    echo "  gm:$GM_LOCAL → 127.0.0.1:7916   redis:$REDIS_LOCAL → 127.0.0.1:6379"
    echo "  测试服 127.0.0.1:${BRIDGE_LOCAL} ← 本机 ${BRIDGE_LOCAL}（DSH 桥接）"
    exec ssh "${TUNNEL_ARGS[@]}" "$SSH_HOST"
    ;;
  down)
    if tunnel_alive; then kill "$(cat "$PID_FILE")" && echo "隧道已断"; else echo "隧道未运行"; fi
    rm -f "$PID_FILE"
    ;;
  status)
    echo "隧道（pid $(cat "$PID_FILE" 2>/dev/null || echo -)）："
    echo "  gm     :$GM_LOCAL    $(probe "$GM_LOCAL")"
    echo "  redis  :$REDIS_LOCAL $(probe "$REDIS_LOCAL")"
    if [ "$(probe "$REDIS_LOCAL")" = up ]; then
      echo -n "  redis PING: "; redis-cli -p "$REDIS_LOCAL" ping 2>/dev/null || echo fail
      echo -n "  在线键: "; redis-cli -p "$REDIS_LOCAL" keys 'ONLINE_NUM:*' 2>/dev/null | tr '\n' ' '; echo
    fi
    # 反向隧道要问测试服自己：本机 18765 本来就是桥接本体，探本地端口说明不了问题
    echo -n "  反向回连(测试服→本机桥接): "
    ssh -o ConnectTimeout=6 "$SSH_HOST" 'curl -s --noproxy "*" -m 4 http://127.0.0.1:18765/health' 2>/dev/null \
      | head -c 120 || true
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
    echo "usage: $0 {up|fg|down|status|console|open}"; exit 1;;
esac
