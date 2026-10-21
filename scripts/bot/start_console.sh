#!/usr/bin/env bash
# 虚拟玩家可视化控制台启停
#
#   ./start_console.sh start     后台启动，日志在 scripts/bot/logs/console.log
#   ./start_console.sh stop
#   ./start_console.sh status    健康检查（打 /api/snapshot 看能不能连上 Redis/GM）
#   ./start_console.sh restart
#   ./start_console.sh fg        前台跑（调试用）
#
# 说明：控制台需要 thrift 包（走 GM 通道执行 bot 命令）。脚本会优先挑
# ~/.workbuddy-ai/binaries/python/envs/default 这个隔离环境，其次 $PYTHON，最后 python3。
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HERE/logs"
LOG="$LOG_DIR/console.log"
PID_FILE="$LOG_DIR/console.pid"
PORT="${TS_CONSOLE_PORT:-18766}"

mkdir -p "$LOG_DIR"

pick_python() {
  if [ -n "${PYTHON:-}" ]; then echo "$PYTHON"; return; fi
  local cand="/Users/wangxufeng/.workbuddy-ai/binaries/python/envs/default/bin/python"
  if [ -x "$cand" ] && "$cand" -c "import thrift" >/dev/null 2>&1; then echo "$cand"; return; fi
  if python3 -c "import thrift" >/dev/null 2>&1; then echo python3; return; fi
  echo python3
}
PY="$(pick_python)"

running() { [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; }

case "${1:-start}" in
  start)
    if running; then echo "already running pid=$(cat "$PID_FILE")"; exit 0; fi
    nohup "$PY" "$HERE/bot_console.py" >>"$LOG" 2>&1 &
    echo $! >"$PID_FILE"
    sleep 1
    echo "started pid=$(cat "$PID_FILE")  python=$PY  log=$LOG"
    echo "open http://127.0.0.1:$PORT/"
    ;;
  fg)
    exec "$PY" "$HERE/bot_console.py"
    ;;
  stop)
    if running; then kill "$(cat "$PID_FILE")" && echo "stopped"; rm -f "$PID_FILE"; else echo "not running"; fi
    ;;
  restart)
    "$0" stop; sleep 1; "$0" start
    ;;
  status)
    if running; then echo "pid=$(cat "$PID_FILE") python=$PY"; else echo "not running"; fi
    curl -s -m 4 "http://127.0.0.1:$PORT/api/snapshot" \
      | python3 -c "import sys,json;d=json.load(sys.stdin);s=d.get('status') or {};print('server',d.get('serverId'),'online',d.get('onlineNum'),'bots',len(s.get('bots') or []),'chats',len(d.get('chats') or []),'bridge',bool(d.get('bridge')),'gm',d.get('gm',{}).get('ok'))" 2>/dev/null \
      || echo "(no response)"
    ;;
  *)
    echo "usage: $0 {start|stop|restart|status|fg}"; exit 1;;
esac
