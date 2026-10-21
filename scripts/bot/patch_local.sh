#!/usr/bin/env bash
# 给「本地自测服」打机器人补丁：编译 → 打回本地 jar → 重启（launchd）
#
#   ./patch_local.sh            # 编译 + 部署 + 重启
#   ./patch_local.sh compile    # 只编译，不部署
#   ./patch_local.sh deploy     # 只部署（用上次编译产物）+ 重启
#
# 为什么需要单独的脚本：本地服的 jar 和测试服不是同一份构建
# （本地 ~/home/java/gameserver/gameSrv-1.0.0.jar，测试服 /home/java/gameserver/…，
#  两者体积都不一样），拿测试服的补丁 jar 直接覆盖有风险。
# 这里用**本地 jar 当 classpath 基准**编译，再把 20 个 class zip 回本地 jar，
# 只替换机器人相关类，其余字节原样不动。
#
# 关键口径：-implicit:none 必须带，否则 sourcepath 里的 thrift 等依赖会被一起编出来。
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
SRC="$PROJ/TimeSpaceServer/Server_x1tag1.2.2/server_game/serverlogic/src/main/java/com/ljsd/jieling"
GS="${GS_HOME:-$HOME/home/java/gameserver}"
LIB="$GS/lib"
BASE="$GS/gameSrv-1.0.0.jar"
OUT="/tmp/bot_patch/classes_local"
JAR="/tmp/bot_patch/gameSrv-local.jar"
JAVA_HOME_8="${JAVA8:-/usr/local/Cellar/openjdk@8/1.8.0-482/libexec/openjdk.jdk/Contents/Home}"

FILES=(
  bot/BotProfile.java bot/BotConfig.java bot/BotText.java
  bot/DshClient.java bot/BotManager.java bot/BotTask.java
  kefu/Cmd_bot.java
  chat/logic/ChatLogic.java
  thread/ThreadManager.java thread/task/MinuteTask.java
  logic/dao/UserManager.java
)

do_compile() {
  [ -f "$BASE" ] || { echo "FATAL: 找不到 $BASE"; exit 1; }
  [ -d "$LIB" ]  || { echo "FATAL: 找不到 $LIB"; exit 1; }
  rm -rf "$OUT"; mkdir -p "$OUT"
  local args=()
  for f in "${FILES[@]}"; do args+=("$SRC/$f"); done
  "${JAVA_HOME_8}/bin/javac" -nowarn -encoding UTF-8 -source 8 -target 8 \
    -cp "$LIB/*:$BASE" -implicit:none -d "$OUT" "${args[@]}"
  local n
  n=$(find "$OUT" -name '*.class' | wc -l | tr -d ' ')
  echo "编译完成：$n 个 class（正常 20 个；多出来说明 -implicit:none 没生效）"
  [ "$n" -le 25 ] || { echo "FATAL: 产物过多，检查 classpath"; exit 1; }
}

do_deploy() {
  [ -d "$OUT" ] || { echo "FATAL: 还没编译，先 ./patch_local.sh compile"; exit 1; }
  cp "$BASE" "$JAR"
  ( cd "$OUT" && zip -qr "$JAR" com )
  cp "$BASE" "$BASE.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$JAR" "$BASE"
  echo "已替换 $BASE（备份 $BASE.bak-*）"
  bash "$HOME/home/java/start-local.sh" restart gs
  echo "等 60s 起服…"
  for i in $(seq 1 30); do
    if nc -z 127.0.0.1 7916 >/dev/null 2>&1; then echo "GM 7916 已就绪"; break; fi
    sleep 2
  done
}

case "${1:-all}" in
  compile) do_compile ;;
  deploy)  do_deploy ;;
  all)     do_compile; do_deploy ;;
  *) echo "用法：$0 [compile|deploy|all]"; exit 1 ;;
esac
