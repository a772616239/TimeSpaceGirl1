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
  handler/player/GetPlayerOneTeamInfo.java
)

do_compile() {
  [ -f "$BASE" ] || { echo "FATAL: 找不到 $BASE"; exit 1; }
  [ -d "$LIB" ]  || { echo "FATAL: 找不到 $LIB"; exit 1; }
  rm -rf "$OUT"; mkdir -p "$OUT"
  local args=()
  for f in "${FILES[@]}"; do args+=("$SRC/$f"); done
  "${JAVA_HOME_8}/bin/javac" -nowarn -encoding UTF-8 -source 8 -target 8 \
    -cp "$LIB/*:$BASE" -implicit:none -d "$OUT" "${args[@]}"
  local n bad
  n=$(find "$OUT" -name '*.class' | wc -l | tr -d ' ')
  # 12 个源文件 = 12 个主类 + 内部类/匿名类（BotManager$1..$6、$ChannelState、$PendingSay 等）。
  # 阈值只能拦「把第三方包一起编出来」这种情况（那会多出几十上百个 com/ljsd 以外的路径），
  # 所以真正判据是**有没有 com/ljsd 之外的 class**，数量上限只是兜底。
  bad=$(find "$OUT" -name '*.class' | grep -cv '/com/ljsd/' || true)
  echo "编译完成：$n 个 class（含内部类），com/ljsd 之外的产物：${bad:-0} 个"
  [ "${bad:-0}" -eq 0 ] || { echo "FATAL: 混进外部包产物，-implicit:none 没生效，检查 classpath"; exit 1; }
  [ "$n" -le 40 ] || { echo "FATAL: 产物过多（$n），检查 classpath"; exit 1; }
}

do_deploy() {
  [ -d "$OUT" ] || { echo "FATAL: 还没编译，先 ./patch_local.sh compile"; exit 1; }
  cp "$BASE" "$JAR"
  ( cd "$OUT" && zip -qr "$JAR" com )
  cp "$BASE" "$BASE.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$JAR" "$BASE"
  echo "已替换 ${BASE}（备份 ${BASE}.bak-*）"

  # 🔴 配置必须跟 class 一起同步。
  # 只换 class 不换 conf 会让本机长期跑「新代码 + 旧语料」：线上早删掉的句子照样在本机说出来
  # （10-23 本机 14:49 还在说 "server feels alive today ngl"，就是 conf 停在 10-21 那版）。
  # 语料和闸门参数都在 conf 里，不同步等于补丁只上了一半。
  local SRC_CONF DST_CONF
  SRC_CONF="$PROJ/TimeSpaceServer/Server_x1tag1.2.2/server_game/conf/bot_config.json"
  DST_CONF="$GS/conf/bot_config.json"
  if [ -f "$SRC_CONF" ]; then
    if cmp -s "$SRC_CONF" "$DST_CONF"; then
      echo "配置已一致，跳过"
    else
      [ -f "$DST_CONF" ] && cp "$DST_CONF" "$DST_CONF.bak-$(date +%Y%m%d-%H%M%S)"
      cp "$SRC_CONF" "$DST_CONF"
      echo "已同步配置 ${DST_CONF}（旧版备份 .bak-*）"
    fi
  else
    echo "WARN: 仓库里没有 $SRC_CONF，配置未同步"
  fi

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
