#!/usr/bin/env bash
# DSH 桥接服务启停（本地/测试服）
#
#   ./start_bridge.sh start     后台启动，日志在 scripts/bot/logs/bridge.log
#   ./start_bridge.sh stop      停止
#   ./start_bridge.sh status    健康检查
#   ./start_bridge.sh restart
#
# 环境变量透传给 dsh_bridge.py（DSH_PROVIDER / DSH_MODEL / DSH_TIMEOUT ...）。
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HERE/logs"
LOG="$LOG_DIR/bridge.log"
PID_FILE="$LOG_DIR/bridge.pid"
PY="${PYTHON:-python3}"

mkdir -p "$LOG_DIR"

health() {
  curl -s -m 3 "http://127.0.0.1:${DSH_BRIDGE_PORT:-18765}/health" || echo "(no response)"
}

running() {
  [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

case "${1:-start}" in
  start)
    if running; then
      echo "already running pid=$(cat "$PID_FILE")"
      exit 0
    fi
    nohup "$PY" "$HERE/dsh_bridge.py" >>"$LOG" 2>&1 &
    echo $! >"$PID_FILE"
    sleep 1
    echo "started pid=$(cat "$PID_FILE")  log=$LOG"
    health; echo
    ;;
  stop)
    if running; then
      kill "$(cat "$PID_FILE")" && echo "stopped pid=$(cat "$PID_FILE")"
      rm -f "$PID_FILE"
    else
      echo "not running"
    fi
    ;;
  restart)
    "$0" stop
    sleep 1
    "$0" start
    ;;
  status)
    if running; then echo "pid=$(cat "$PID_FILE")"; else echo "not running"; fi
    health; echo
    ;;
  *)
    echo "usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
