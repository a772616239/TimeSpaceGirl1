#!/usr/local/bin/bash
# =============================================================================
# local_deploy.sh —— 本地测试服（本机 ~/home/java）一键部署执行口
#
# 目标服：gameSrv-1.0.0.jar @ 127.0.0.1:16081（launchd com.ts.localserver.gameserver）
# 登录服：Tomcat tk @ 127.0.0.1:8081 —— **本脚本不碰**，源码不在本仓库
#
# 为什么要有它：把「编译 → 比差异 → 备份 → 停服 → 注入 → 起服 → 自检」这条
# 只在脑子里跑过、每次都靠手打命令的链路收成一个入口。破坏性和顺序都写死在这里。
#
# 用法：
#   local_deploy.sh info                只读：端口 / pid / launchd / jar 时间 / git HEAD
#   local_deploy.sh precheck            部署前体检：JDK8 / 源码状态 / 编译产物 / lib 一致性
#   local_deploy.sh build               编译 :serverlogic:jar + :serverlogic:copyJars
#   local_deploy.sh diff                编译产物 vs 本地 jar 逐条目 CRC，产出注入清单
#   local_deploy.sh deploy              备份 → 停服 → 注入 → 复核 → 起服（--dry-run 只演不动作）
#   local_deploy.sh health              自检：端口 / 启动行 / 表加载 / 致命关键字 / 协议探测
#   local_deploy.sh rollback [备份名]    还原最近（或指定）备份并重启
#   local_deploy.sh all                 一条龙（等价 job 里点一次构建）
#
# 🔴 部署范围不只是 gameSrv-1.0.0.jar：lib/ 下的 module jar（common / netty /
#    gamecommon / hotfix / fightmanager / tablemanager）同样按逐条目 CRC 同步。
#    只注入主 jar 时，一旦改了某个 module 的方法签名，运行期必炸 NoSuchMethodError
#    （2026-10-20 实测：common 新增 MongoUpdateCacheThreadLocal.clear()I，主 jar 进去了、
#      common jar 没进去 ⇒ 每条消息打死一个逻辑线程 ⇒ 客户端反复重连）。
#
# 环境变量：
#   PROJ           工程根（默认 /Users/wangxufeng/Documents/TimeSpaceGirl1）
#   SRC_DIR        编译源码目录（默认 $PROJ/TimeSpaceServer/Server_x1tag1.2.2/server_game）
#   GS_HOME        本地服目录（默认 $HOME/home/java/gameserver）
#   TS_RUN_DIR     本次证据目录（job 传入；缺省落 .jenkins/run/adhoc-<时间戳>）
#   PY             环节报告 / 差异分析用的 python
#   GRADLE_ARGS    覆盖 gradle 参数（默认 "--offline"，新增依赖时给空串）
#   SKIP_PROTO     1 = 不做协议探测
#   DRY_RUN        1 = deploy 只打印动作不执行
#
# 退出码：0 通过 / 3 需关注（黄球）/ 1 失败 / 2 环境错误
# =============================================================================
set -uo pipefail

CMD="${1:-info}"
[[ $# -gt 0 ]] && shift

PROJ="${PROJ:-/Users/wangxufeng/Documents/TimeSpaceGirl1}"
REPO="${SERVER_REPO:-$PROJ/TimeSpaceServer/Server_x1tag1.2.2}"
SRC_DIR="${SRC_DIR:-$REPO/server_game}"
GS_HOME="${GS_HOME:-$HOME/home/java/gameserver}"
LOCAL_CTL="${LOCAL_CTL:-$HOME/home/java/start-local.sh}"
GS_JAR="$GS_HOME/gameSrv-1.0.0.jar"
GS_LOG="${GS_LOG:-$HOME/home/java/logs/gameserver.log}"
GS_LOG_ALT="$HOME/home/java/logs/run-gs.log"
BACKUP_DIR="$GS_HOME/backup"
SRC_JAR="$SRC_DIR/serverlogic/build/libs/serverlogic-1.0.0.jar"
SRC_LIB="$SRC_DIR/serverlogic/lib"
DIFF_SCRIPT="$PROJ/.jenkins/lib/local_jar_diff.py"
PY="${PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
GRADLE_ARGS="${GRADLE_ARGS---offline}"
DRY_RUN="${DRY_RUN:-0}"
PORT=16081

# 证据目录：job 会传 TS_RUN_DIR（一次构建内 diff/deploy/health 共用一个目录）。
# 手动连着敲 deploy 再 health 时没传变量 —— 若各自新建目录，health 就读不到本轮的
# backup-path.txt / log-baseline.txt，会误报「本轮没有部署」。所以复用 30 分钟内的最近目录。
if [[ -n "${TS_RUN_DIR:-}" ]]; then
  RUN_DIR="$TS_RUN_DIR"
else
  _latest="$(ls -1dt "$PROJ"/.jenkins/run/adhoc-* 2>/dev/null | head -1)"
  _now="$(date +%s)"; _mt=0
  [[ -n "$_latest" ]] && _mt="$(stat -f %m "$_latest" 2>/dev/null || echo 0)"
  if [[ -n "$_latest" && $((_now - _mt)) -lt 1800 ]]; then
    RUN_DIR="$_latest"
  else
    RUN_DIR="$PROJ/.jenkins/run/adhoc-$(date +%Y%m%d-%H%M%S)"
  fi
fi
LOCAL_RUN="$RUN_DIR/local"
mkdir -p "$LOCAL_RUN" "$BACKUP_DIR"

log()  { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m    ✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m    [WARN] %s\033[0m\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
die()  { printf '\033[1;31m[FAIL] %s\033[0m\n' "$*" >&2; exit 1; }
WARNINGS=0

# ---------------------------------------------------------------- 基础设施 --
port_pid() { /usr/sbin/lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | head -1; }

wait_port_free() {
  local port=$1 i=0
  while [[ -n "$(port_pid "$port")" ]] && [[ $i -lt 45 ]]; do i=$((i + 1)); sleep 1; done
  [[ -z "$(port_pid "$port")" ]]
}

wait_port_listen() {
  local port=$1 secs=${2:-150} i=0
  while [[ $i -lt $secs ]]; do
    [[ -n "$(port_pid "$port")" ]] && return 0
    i=$((i + 1)); sleep 1
  done
  return 1
}

# ------------------------------------------------------- 起服 / 重启 -------
# 🔴 为什么不用 `start-local.sh install gs`：
#    `launchctl bootstrap` 在 Jenkins / agent shell 里恒返回 5 (Input/output error)
#    （需要在 Aqua 登录会话里有 launchd 写权限）。而 install 的第一步是 bootout ——
#    一旦 bootout 成功、bootstrap 失败，托管就丢了，且我们自己再也装不回来。
#    所以这里**全程不碰托管状态**：
#      · 托管中  → launchctl kickstart -k（原地重启，托管不变）
#      · 未托管  → kill + 独立会话拉起（agent shell 退出会杀进程组，必须 start_new_session）
#    下次登录 Mac 时 LaunchAgents 里的 plist 会自动 bootstrap，托管自然恢复。

spawn_detached() {
  "$PY" - "$HOME/home/java/run-gs.sh" "$GS_LOG" "$GS_HOME" <<'PYEOF'
import os, subprocess, sys
script, log, cwd = sys.argv[1:4]
# 🔴 这是「部署完自检全绿、构建一结束进程就没了」的真正原因：
#    Jenkins 构建结束时会按 HUDSON_COOKIE / JENKINS_SERVER_COOKIE 标记杀光
#    属于本次构建的进程（ProcessTreeKiller，防泄漏用）。只做 setsid / nohup 不够，
#    因为它是按环境变量找进程的，不看 session。必须把标记变量从子进程环境里摘掉。
STRIP = ('HUDSON_COOKIE', 'JENKINS_SERVER_COOKIE', 'JENKINS_NODE_COOKIE',
         'BUILD_ID', 'BUILD_TAG', 'BUILD_NUMBER', 'BUILD_URL', 'BUILD_DISPLAY_NAME',
         'JOB_NAME', 'JOB_BASE_NAME', 'NODE_NAME', 'EXECUTOR_NUMBER',
         'WORKSPACE', 'WORKSPACE_TMP')
env = {k: v for k, v in os.environ.items() if k not in STRIP}
f = open(log, 'ab')
p = subprocess.Popen(['/bin/bash', script], stdout=f, stderr=subprocess.STDOUT,
                     stdin=subprocess.DEVNULL, start_new_session=True, cwd=cwd, env=env)
print('    spawned pid=%d（独立会话 + 已摘掉 Jenkins 构建标记，不会被 ProcessTreeKiller 收走）' % p.pid)
PYEOF
}

restart_gs() {
  local uid label pid
  uid="$(id -u)"; label="com.ts.localserver.gameserver"
  pid="$(port_pid $PORT)"
  if /bin/launchctl print "gui/$uid/$label" >/dev/null 2>&1; then
    log "launchd 托管中 → kickstart -k 原地重启（托管状态不变）"
    /bin/launchctl kickstart -k "gui/$uid/$label" 2>&1 | sed 's/^/    /'
    if wait_port_listen $PORT 30; then ok "已在 :${PORT} 重新监听"; return 0; fi
    warn "kickstart 后 30s 内没起来，改走 kill + 独立会话启动"
  else
    log "launchd 未托管 → kill + 独立会话启动"
  fi
  if [[ -n "$pid" ]]; then
    kill -TERM "$pid" 2>/dev/null && echo "    SIGTERM → pid=$pid"
    wait_port_free $PORT || die "端口 :${PORT} 45s 内没释放"
  fi
  spawn_detached
  wait_port_listen $PORT 150 || die "独立会话启动后 :${PORT} 150s 内没起来，看 ${GS_LOG}"
  ok "已在 :${PORT} 重新监听（pid=$(port_pid $PORT)）"
  echo "    [info] 本次登录会话内非 launchd 托管（launchctl bootstrap/load 在 agent/Jenkins shell 里恒 rc=5）"
  echo "    [info] 后果：进程崩了不会自动拉起。要恢复托管：双击 ~/home/java/install-autostart.command"
  return 0
}

# 日志基线：launchd 托管写 gameserver.log，独立会话写 run-gs.log，两边都要看，
# 否则「nohup 启动」那种情况会永远读不到启动行（第一版就栽在这）。
write_log_baseline() {
  : > "$LOCAL_RUN/log-baseline.txt"
  local f n
  for f in "$GS_LOG" "$GS_LOG_ALT"; do
    [[ -f "$f" ]] || continue
    n="$(wc -l < "$f" | tr -d ' ')"
    printf '%s|%s\n' "$f" "$n" >> "$LOCAL_RUN/log-baseline.txt"
  done
}

collect_log_after() {
  : > "$LOCAL_RUN/after.log"
  local f n
  while IFS='|' read -r f n; do
    [[ -f "$f" ]] || continue
    tail -n +"$((n + 1))" "$f" >> "$LOCAL_RUN/after.log" 2>/dev/null
  done < "$LOCAL_RUN/log-baseline.txt"
}

java8_home() {
  local c
  for c in "${JAVA_HOME:-}" \
           /usr/local/Cellar/openjdk@8/1.8.0-482/libexec/openjdk.jdk/Contents/Home \
           /Library/Java/JavaVirtualMachines/adoptopenjdk-8.jdk/Contents/Home; do
    [[ -n "$c" && -x "$c/bin/javac" && -f "$c/lib/tools.jar" ]] && { printf '%s' "$c"; return 0; }
  done
  c="$(/usr/libexec/java_home -v 1.8 2>/dev/null || true)"
  [[ -n "$c" && -f "$c/lib/tools.jar" ]] && { printf '%s' "$c"; return 0; }
  return 1
}

git_snapshot() {  # 写到 $LOCAL_RUN/git.txt，同时打印
  {
    echo "仓库：$REPO"
    echo "分支：$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    echo "提交：$(git -C "$REPO" log --oneline -1 2>/dev/null)"
    echo "落后 origin：$(git -C "$REPO" rev-list --count HEAD..@{u} 2>/dev/null || echo '?')"
    echo "--- 未提交改动（源码类）---"
    git -C "$REPO" status --porcelain 2>/dev/null | /usr/bin/grep -E '\.java$' || echo "（无）"
    echo "--- 未提交改动（其他，前 15 条）---"
    git -C "$REPO" status --porcelain 2>/dev/null | /usr/bin/grep -vE '\.java$' | head -15 || true
  } | tee "$LOCAL_RUN/git.txt" | sed 's/^/    /'
}

# ------------------------------------------------------------ lib module 同步 --
# 🔴 为什么需要它：gameSrv-1.0.0.jar 只是 serverlogic 的产物，common / netty /
#    gamecommon / hotfix / fightmanager / tablemanager 是**各自独立的 lib jar**。
#    只注入主 jar ⇒ 改了 module 的方法签名后运行期 NoSuchMethodError。
#    （2026-10-20 案例：common 新增 public static int clear()I，主 jar 部署了、
#      lib/common-1.0.0.jar 还是 10-18 的旧版 ⇒ 每处理一条消息就打死一个 h-N 逻辑线程
#      ⇒ 玩家侧表现「老要重登」。）
#
# 🔴 为什么这些 jar 也不能整包覆盖：gamecommon 的 util/SysUtil.class 是「本地 lib 带补丁、
#    gradle 重建后没有补丁」的版本（补丁丢了会静默少加载配置表）。整包覆盖 = 丢补丁。
#    ⇒ 一律走「逐条目 CRC 差异注入」，并把 SysUtil 显式排除。
#
# 格式：<SRC_DIR 下的构建产物相对路径>|<本地 lib 文件名>|<额外排除正则，可空>
LIB_MODULES=(
  "common/build/libs/common-1.0.0.jar|common-1.0.0.jar|"
  "netty/build/libs/netty-1.0.0.jar|netty-1.0.0.jar|"
  "gamecommon/build/libs/gamecommon-1.0.0-SNAPSHOT.jar|gamecommon-1.0.0-SNAPSHOT.jar|^util/SysUtil\\.class$"
  "hotfix/build/libs/hotfix.jar|hotfix.jar|"
  "fightmanager/build/libs/fightmanager.jar|fightmanager.jar|"
  "tablemanager/build/libs/tablemanager.jar|tablemanager.jar|"
)

lib_plan() {   # 每个 module 产出 <name>.list / staging；总计写入 lib/total.txt
  local rel name excl src dst d n total=0
  mkdir -p "$LOCAL_RUN/lib"
  : > "$LOCAL_RUN/lib/summary.txt"
  for spec in "${LIB_MODULES[@]}"; do
    IFS='|' read -r rel name excl <<< "$spec"
    src="$SRC_DIR/$rel"; dst="$GS_HOME/lib/$name"
    d="$LOCAL_RUN/lib/$name"; mkdir -p "$d"; : > "$d/inject.list"
    if [[ ! -f "$src" ]]; then
      printf '    %-38s %s\n' "$name" "— 无编译产物（gradle 跳过），不动" >> "$LOCAL_RUN/lib/summary.txt"
      continue
    fi
    if [[ ! -f "$dst" ]]; then
      printf '    %-38s %s\n' "$name" "⚠ 本地 lib 缺这个 jar（需整包安装）" >> "$LOCAL_RUN/lib/summary.txt"
      continue
    fi
    local -a exarg=()
    [[ -n "$excl" ]] && exarg=(--exclude "$excl")
    "$PY" "$DIFF_SCRIPT" --src "$src" --dst "$dst" \
      --json "$d/diff.json" --list "$d/inject.list" --staging "$d/staging" \
      ${exarg[@]+"${exarg[@]}"} --quiet || return 1
    n="$(wc -l < "$d/inject.list" | tr -d ' ')"
    total=$((total + n))
    if [[ "$n" -gt 0 ]]; then
      printf '    %-38s 待注入 %s 条\n' "$name" "$n" >> "$LOCAL_RUN/lib/summary.txt"
    else
      printf '    %-38s 一致\n' "$name" >> "$LOCAL_RUN/lib/summary.txt"
    fi
  done
  printf '%s\n' "$total" > "$LOCAL_RUN/lib/total.txt"
  return 0
}

lib_apply() {  # $1 = stamp。全部在副本上做，逐个复核通过后才统一 mv
  local stamp="$1" rel name excl src dst d n tmp i=0
  local -a pending=()
  : > "$LOCAL_RUN/lib/replaced.txt"
  for spec in "${LIB_MODULES[@]}"; do
    IFS='|' read -r rel name excl <<< "$spec"
    d="$LOCAL_RUN/lib/$name"
    [[ -s "$d/inject.list" ]] || continue
    dst="$GS_HOME/lib/$name"
    n="$(wc -l < "$d/inject.list" | tr -d ' ')"
    tmp="$GS_HOME/lib/.$name.$stamp.new"
    cp -p "$dst" "$tmp" || die "复制副本失败：$dst"
    rm -rf "$d/batches"; mkdir -p "$d/batches"
    split -l 40 "$d/inject.list" "$d/batches/b."
    local b nbatch=0
    for b in "$d"/batches/b.*; do
      ( cd "$d/staging" && /usr/bin/zip -u -q "$tmp" -@ < "$b" ) \
        || { rm -f "$tmp"; die "zip -u 失败：${name}（该 jar 未改动）"; }
      nbatch=$((nbatch + 1))
    done
    # 复核：逐条目 CRC 比回编译产物
    local bad
    bad="$("$PY" - "$SRC_DIR/$rel" "$tmp" "$d/inject.list" <<'PYEOF'
import sys, zipfile
src, dst, lst = sys.argv[1:4]
names = [l.strip() for l in open(lst, encoding="utf-8") if l.strip()]
with zipfile.ZipFile(src) as zs, zipfile.ZipFile(dst) as zd:
    have = {i.filename: i.CRC for i in zd.infolist() if not i.is_dir()}
    want = {i.filename: i.CRC for i in zs.infolist() if not i.is_dir()}
print("\n".join(x for x in names if have.get(x) != want.get(x)))
PYEOF
)"
    if [[ -n "$bad" ]]; then
      rm -f "$tmp"
      printf '%s\n' "$bad" | head -5 | sed 's/^/    ✗ /'
      die "$name 有 $(printf '%s\n' "$bad" | wc -l | tr -d ' ') 个条目没注入成功（该 jar 未改动）"
    fi
    ok "${name}：注入 ${n} 条 / ${nbatch} 批，CRC 复核通过"
    pending+=("$tmp|$dst")
    i=$((i + 1))
  done
  # 全部复核通过 → 逐个原子替换
  local pair
  for pair in ${pending[@]+"${pending[@]}"}; do
    tmp="${pair%%|*}"; dst="${pair##*|}"
    mv -f "$tmp" "$dst" || die "mv 替换失败：$dst"
    printf '%s\n' "$dst" >> "$LOCAL_RUN/lib/replaced.txt"
  done
  [[ "$i" -gt 0 ]] && ok "lib module 已同步 ${i} 个 jar"
  return 0
}

lib_report() {  # 只读摘要，diff / precheck / info 共用
  local total
  total="$(cat "$LOCAL_RUN/lib/total.txt" 2>/dev/null || echo 0)"
  if [[ -f "$LOCAL_RUN/lib/summary.txt" ]]; then
    sed 's/^    /    /' "$LOCAL_RUN/lib/summary.txt"
  fi
  printf '%s' "${total:-0}"
}

# ------------------------------------------------------------------- 子命令 --
cmd_info() {
  log "本地测试服现状"
  local pid
  pid="$(port_pid $PORT)"
  if [[ -n "$pid" ]]; then ok "游戏服 :${PORT} 在听 (pid=$pid)"; else warn "游戏服 :${PORT} 未监听"; fi
  if /bin/launchctl print "gui/$(id -u)/com.ts.localserver.gameserver" >/dev/null 2>&1; then
    ok "launchd 托管：loaded（进程退出会被拉起）"
  else
    warn "launchd 托管：NOT loaded —— 崩了不会自动拉起。恢复办法：双击 ~/home/java/install-autostart.command"
    warn "（launchctl bootstrap/load 在 agent 与 Jenkins shell 里恒 rc=5，只能在 Terminal.app 里做）"
  fi
  local lp
  lp="$(port_pid 8081)"
  if [[ -n "$lp" ]]; then ok "登录服 :8081 在听 (pid=$lp)"; else warn "登录服 :8081 未监听"; fi
  if [[ -f "$GS_JAR" ]]; then
    printf '    jar：%s  %s  %s\n' "$(du -h "$GS_JAR" | cut -f1)" \
      "$(date -r "$GS_JAR" '+%Y-%m-%d %H:%M')" "$(unzip -l "$GS_JAR" | tail -1 | awk '{print $2" 条目"}')"
  else
    warn "找不到 $GS_JAR"
  fi
  printf '    日志：%s  %s\n' "$(du -h "$GS_LOG" 2>/dev/null | cut -f1)" \
    "$(wc -l < "$GS_LOG" 2>/dev/null | tr -d ' ') 行"
  echo "    --- git ---"
  git_snapshot
  return 0
}

cmd_precheck() {
  local rc=0 j
  log "① JDK 8"
  if j="$(java8_home)"; then ok "JAVA_HOME=$j"; else warn "找不到 JDK8（含 lib/tools.jar）"; rc=1; fi

  log "② 源码仓库"
  [[ -d "$REPO" ]] || { warn "找不到服务端仓库：$REPO"; return 1; }
  [[ -d "$SRC_DIR" ]] || { warn "找不到 server_game 目录：$SRC_DIR"; return 1; }
  git_snapshot
  if [[ "$SRC_DIR" != "$REPO/server_game" ]]; then
    echo "    --- 实际编译目录（隔离副本）---"
    echo "    $SRC_DIR"
    echo "    HEAD：$(git -C "$SRC_DIR" log --oneline -1 2>/dev/null || echo '?')"
    echo "    未提交改动：$(git -C "$SRC_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ') 项"
  fi
  local dirty
  dirty="$(git -C "$REPO" status --porcelain 2>/dev/null | /usr/bin/grep -cE '\.java$' || true)"
  if [[ "${dirty:-0}" -gt 0 ]]; then
    echo "    [info] 有 ${dirty} 个 .java 未提交 —— 本地工作区模式会把它们一起编进去（想只测已提交代码请选 origin 干净副本）"
  fi
  local behind
  behind="$(git -C "$REPO" rev-list --count HEAD..@{u} 2>/dev/null || echo 0)"
  if [[ "${behind:-0}" -gt 0 ]]; then
    echo "    [info] 本地落后 origin ${behind} 个提交 —— 想测远端最新请用 SOURCE=origin 干净副本"
  fi

  log "③ 本地服目录"
  [[ -f "$GS_JAR" ]] && ok "gameSrv jar 存在（$(date -r "$GS_JAR" '+%m-%d %H:%M')）" \
    || { warn "找不到 $GS_JAR"; rc=1; }
  [[ -x "$LOCAL_CTL" ]] || { warn "找不到本地服控制脚本：$LOCAL_CTL"; rc=1; }
  if [[ -n "$(port_pid ${PORT})" ]]; then ok "游戏服 :${PORT} 在听"; else echo "    [info] 游戏服 :${PORT} 当前未监听（部署后会拉起）"; fi

  log "④ 依赖 lib 一致性（编译产物 vs 本地服）"
  # Class-Path 固定写在本地 jar 的 MANIFEST 里（82 条）。依赖集合变了却不换 MANIFEST，
  # 新依赖不会被加载 ⇒ NoClassDefFoundError 要到运行期才炸。所以这里硬拦。
  if [[ -d "$SRC_LIB" && -d "$GS_HOME/lib" ]]; then
    local a b only_src only_dst
    a="$(ls "$SRC_LIB" 2>/dev/null | /usr/bin/grep '\.jar$' | sort)"
    b="$(ls "$GS_HOME/lib" 2>/dev/null | /usr/bin/grep '\.jar$' | sort)"
    only_src="$(comm -23 <(printf '%s\n' "$a") <(printf '%s\n' "$b") | tr '\n' ' ')"
    only_dst="$(comm -13 <(printf '%s\n' "$a") <(printf '%s\n' "$b") | tr '\n' ' ')"
    if [[ -n "$only_src" ]]; then
      warn "编译侧有、本地 lib 没有：$only_src"
      warn "  ⇒ 依赖变了。MANIFEST 的 Class-Path 是固定表，注入类不会带上新依赖。"
      warn "  ⇒ 请走整包：cd $SRC_DIR && ./package.sh --no-build --mode update，再手工替换"
      rc=1
    else
      ok "依赖集合一致（$(printf '%s\n' "$a" | wc -l | tr -d ' ') 个 jar）"
      [[ -n "$only_dst" ]] && echo "    [info] 本地 lib 多出（无害，历史残留）：$only_dst"
    fi
  else
    warn "缺 lib 目录，跳过一致性检查"
  fi

  log "⑤ lib module jar 内容一致性（集合一致 ≠ 内容一致）"
  # 文件名集合一样但类不同，是最难查的一类：main jar 引用了 module 里新加的方法，
  # 运行期才 NoSuchMethodError。这里提前算出来（deploy 会一并注入）。
  if [[ -d "$GS_HOME/lib" ]]; then
    if lib_plan; then
      cat "$LOCAL_RUN/lib/summary.txt" 2>/dev/null
      local lt
      lt="$(cat "$LOCAL_RUN/lib/total.txt" 2>/dev/null || echo 0)"
      if [[ "${lt:-0}" -gt 0 ]]; then
        echo "    [info] 共 ${lt} 个条目待同步 —— deploy 阶段会一起注入，不必手工处理"
      else
        ok "lib module jar 与编译产物逐条目一致"
      fi
    else
      warn "lib module 差异分析失败（看 $LOCAL_RUN/lib/）"
      rc=1
    fi
  fi
  return $rc
}

cmd_build() {
  local j
  j="$(java8_home)" || die "找不到 JDK8"
  [[ -d "$SRC_DIR" ]] || die "找不到 $SRC_DIR"
  log "编译（${SRC_DIR}）"
  echo "    JAVA_HOME=$j"
  echo "    GRADLE_USER_HOME=$SRC_DIR/.gradle_home  参数：${GRADLE_ARGS:-（无）}"
  local before=0
  [[ -f "$SRC_JAR" ]] && before="$(date -r "$SRC_JAR" +%s)"
  # 🔴 不要写成 `./gradlew ... | tail`：管道后 $? 是 tail 的，编译失败会被读成成功。
  ( cd "$SRC_DIR" && \
    JAVA_HOME="$j" \
    GRADLE_USER_HOME="${GRADLE_USER_HOME:-$SRC_DIR/.gradle_home}" \
    ./gradlew --no-daemon --console=plain $GRADLE_ARGS :serverlogic:jar :serverlogic:copyJars ) \
    > "$LOCAL_RUN/build.log" 2>&1
  local rc=$?
  tail -40 "$LOCAL_RUN/build.log" | sed 's/^/    /'
  [[ $rc -ne 0 ]] && die "gradle 编译失败（rc=${rc}，完整日志 $LOCAL_RUN/build.log）"
  [[ -f "$SRC_JAR" ]] || die "编译成功但找不到产物：$SRC_JAR"
  local after
  after="$(date -r "$SRC_JAR" +%s)"
  if [[ "$after" -le "$before" ]]; then
    echo "    [info] 产物 mtime 未变（gradle 判定源码无改动），沿用 $(date -r "$SRC_JAR" '+%m-%d %H:%M') 的产物"
    echo "    [info] 真改了代码却编不出新产物时，紧接着的差异分析会算出「无变化」并跳过部署 —— 拦住错误部署的是那一道"
  else
    ok "编译产物已更新：$(du -h "$SRC_JAR" | cut -f1)  $(date -r "$SRC_JAR" '+%m-%d %H:%M:%S')"
  fi
  cp -p "$SRC_JAR" "$LOCAL_RUN/serverlogic-build.jar" 2>/dev/null || true
  return 0
}

cmd_diff() {
  [[ -f "$SRC_JAR" ]] || die "没有编译产物：${SRC_JAR}（先跑 build）"
  [[ -f "$GS_JAR" ]]  || die "没有本地 jar：$GS_JAR"
  log "① 主 jar 差异（serverlogic 编译产物 vs 本地 gameSrv）"
  local rc n
  "$PY" "$DIFF_SCRIPT" \
    --src "$SRC_JAR" --dst "$GS_JAR" \
    --json "$LOCAL_RUN/diff.json" \
    --list "$LOCAL_RUN/inject.list" \
    --staging "$LOCAL_RUN/staging"
  rc=$?
  [[ $rc -ne 0 ]] && die "差异分析失败（rc=${rc}）"
  n="$(wc -l < "$LOCAL_RUN/inject.list" | tr -d ' ')"
  echo "    待注入 ${n} 条（清单 $LOCAL_RUN/inject.list）"

  log "② lib module jar 差异（common / netty / gamecommon / hotfix / fightmanager / tablemanager）"
  lib_plan || die "lib module 差异分析失败"
  cat "$LOCAL_RUN/lib/summary.txt" 2>/dev/null || true
  local ln total
  ln="$(cat "$LOCAL_RUN/lib/total.txt" 2>/dev/null || echo 0)"
  ln="${ln:-0}"
  total=$((n + ln))
  echo "  合计待注入：主 jar ${n} 条 + lib module ${ln} 条 = ${total} 条"
  if [[ "$total" -eq 0 ]]; then
    echo "    [info] 代码与本地服完全一致 —— 无需注入（不做重启）"
    return 3
  fi
  if [[ "$n" -eq 0 ]]; then
    echo "    [info] 主 jar 无变化，只同步 lib module —— 但这些类要重启才生效"
  fi
  return 0
}

cmd_deploy() {
  local rc
  # 总是重算一次差异：主 jar 可能没变、只有 lib module 变了（2026-10-20 就是这样），
  # 只看 inject.list 会误判「无变化」而跳过部署，问题原样留在服上。
  cmd_diff; rc=$?
  if [[ $rc -eq 3 ]]; then ok "无变化，跳过部署（不做重启）"; return 0; fi
  [[ $rc -ne 0 ]] && return $rc

  local n ln total
  n="$(wc -l < "$LOCAL_RUN/inject.list" 2>/dev/null | tr -d ' ' || true)"; n="${n:-0}"
  ln="$(cat "$LOCAL_RUN/lib/total.txt" 2>/dev/null || echo 0)"; ln="${ln:-0}"
  total=$((n + ln))
  [[ "$total" -eq 0 ]] && { ok "无变化，跳过部署（不做重启）"; return 0; }

  # ---- 1. 备份 -------------------------------------------------------------
  local stamp bak
  stamp="$(date +%Y%m%d-%H%M%S)"
  bak="$BACKUP_DIR/gameSrv-$stamp.jar"
  log "① 备份当前 jar（主 jar + 将要改动的 lib module）"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "    [dry-run] cp -p \"$GS_JAR\" \"$bak\""
    echo "    [dry-run] 备份 ${ln} 条待同步 lib module 条目 → $BACKUP_DIR/lib-$stamp/"
  else
    cp -p "$GS_JAR" "$bak" || die "备份失败（无备份绝不注入）"
    shasum -a 256 "$bak" | awk '{print $1}' > "$bak.sha256"
    ok "备份主 jar：${bak}（$(du -h "$bak" | cut -f1)）"
    printf '%s\n' "$bak" > "$LOCAL_RUN/backup-path.txt"

    # lib module 只备份真正要动的那些，manifest 供 rollback 逐字还原
    : > "$LOCAL_RUN/lib/backup-manifest.txt"
    if [[ "$ln" -gt 0 ]]; then
      local libbak="$BACKUP_DIR/lib-$stamp" spec rel name excl d
      mkdir -p "$libbak"
      for spec in "${LIB_MODULES[@]}"; do
        IFS='|' read -r rel name excl <<< "$spec"
        d="$LOCAL_RUN/lib/$name"
        [[ -s "$d/inject.list" ]] || continue
        cp -p "$GS_HOME/lib/$name" "$libbak/$name" || die "备份失败：lib/$name"
        printf '%s\n' "$name" >> "$LOCAL_RUN/lib/backup-manifest.txt"
      done
      ok "备份 lib module：$(wc -l < "$LOCAL_RUN/lib/backup-manifest.txt" | tr -d ' ') 个 → ${libbak}"
      printf '%s\n' "$libbak" > "$LOCAL_RUN/lib-backup-path.txt"
    fi

    ls -1 "$BACKUP_DIR"/gameSrv-*.jar 2>/dev/null | sort -r | tail -n +16 | while read -r old; do
      rm -f "$old" "$old.sha256"
    done
    ls -1d "$BACKUP_DIR"/lib-* 2>/dev/null | sort -r | tail -n +6 | while read -r oldd; do
      rm -rf "$oldd"
    done
  fi

  # ---- 2. 日志基线（health 要用；两个日志文件都记）--------------------------
  write_log_baseline
  echo "    日志基线：$(tr '\n' ' ' < "$LOCAL_RUN/log-baseline.txt" | sed 's/|/=行 /g')"

  # ---- 3. 在副本上注入（正式 jar 完全不受影响）----------------------------
  # 🔴 为什么不是「先停服再直接改正式 jar」：
  #    1) zip -u 是就地写。运行中的 JVM 后续懒加载到被改过的条目 ⇒ 一半旧类一半新类
  #       ⇒ LinkageError / NoSuchMethodError，而且现场很难解释。
  #    2) 先停服再改，改到一半失败 = 「服务已停 + jar 半新」，恢复要人肉拼。
  #    副本注入 + mv 原子替换：运行中的进程始终读旧 inode，替换是瞬时的；
  #    失败时正式 jar 一个字节都没动，服务照旧。
  local tmpjar="$GS_HOME/.gameSrv-$stamp.new"
  log "② 主 jar 注入（${n} 个差异条目，zip -u 分批，staging 已 touch 过 mtime）"
  if [[ "$n" -eq 0 ]]; then
    echo "    [info] 主 jar 无差异，跳过"
  elif [[ "$DRY_RUN" == "1" ]]; then
    echo "    [dry-run] cp -p $GS_JAR $tmpjar"
    echo "    [dry-run] cd staging && zip -u -q $tmpjar -@ < inject.list"
  else
    cp -p "$GS_JAR" "$tmpjar" || die "复制副本失败（磁盘满？）"
    local stage="$LOCAL_RUN/staging"
    [[ -d "$stage" ]] || die "staging 目录不存在（diff 没跑成功？）：$stage"
    rm -rf "$LOCAL_RUN/batches"; mkdir -p "$LOCAL_RUN/batches"
    split -l 40 "$LOCAL_RUN/inject.list" "$LOCAL_RUN/batches/b."
    local b nbatch=0
    for b in "$LOCAL_RUN"/batches/b.*; do
      ( cd "$stage" && /usr/bin/zip -u -q "$tmpjar" -@ < "$b" ) \
        || { rm -f "$tmpjar"; die "zip -u 失败（批次 ${b}），正式 jar 未被修改"; }
      nbatch=$((nbatch + 1))
    done
    ok "注入完成（${nbatch} 批）"
  fi

  # ---- 4. 复核副本 ---------------------------------------------------------
  log "③ 主 jar 注入复核（逐条目 CRC 比回编译产物）"
  if [[ "$n" -eq 0 ]]; then
    echo "    [info] 跳过"
  elif [[ "$DRY_RUN" == "1" ]]; then
    echo "    [dry-run] 跳过复核"
  else
    local bad
    bad="$("$PY" - "$SRC_JAR" "$tmpjar" "$LOCAL_RUN/inject.list" <<'PYEOF'
import sys, zipfile
src, dst, lst = sys.argv[1:4]
names = [l.strip() for l in open(lst, encoding="utf-8") if l.strip()]
with zipfile.ZipFile(src) as zs, zipfile.ZipFile(dst) as zd:
    have = {i.filename: i.CRC for i in zd.infolist() if not i.is_dir()}
    want = {i.filename: i.CRC for i in zs.infolist() if not i.is_dir()}
bad = [x for x in names if have.get(x) != want.get(x)]
print("\n".join(bad))
PYEOF
)"
    if [[ -n "$bad" ]]; then
      printf '%s\n' "$bad" | head -10 | sed 's/^/    ✗ /'
      rm -f "$tmpjar"
      die "有 $(printf '%s\n' "$bad" | wc -l | tr -d ' ') 个条目没注入成功（正式 jar 未被修改；常见原因：没 touch，zip 按 mtime 2 秒粒度跳过）"
    fi
    ok "全部 ${n} 条 CRC 与编译产物一致"
  fi

  # ---- 5. lib module 同步（先于主 jar：lib 多方法不碍事，缺方法才炸）--------
  log "④ lib module jar 同步（逐条目注入 → CRC 复核 → 原子替换）"
  if [[ "$ln" -eq 0 ]]; then
    echo "    [info] lib module 无差异，跳过"
  elif [[ "$DRY_RUN" == "1" ]]; then
    echo "    [dry-run] 同步 ${ln} 条：$(tr '\n' ' ' < "$LOCAL_RUN/lib/backup-manifest.txt" 2>/dev/null)"
  else
    lib_apply "$stamp" || die "lib module 同步失败 —— 用 .jenkins/lib/local_deploy.sh rollback 还原"
  fi

  # ---- 6. 原子替换 + 重启 --------------------------------------------------
  log "⑤ 原子替换正式 jar 并重启"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "    [dry-run] mv -f $tmpjar $GS_JAR && 重启游戏服"
  else
    if [[ "$n" -gt 0 ]]; then
      mv -f "$tmpjar" "$GS_JAR" || die "mv 替换失败"
      ok "jar 已替换（$(du -h "$GS_JAR" | cut -f1)）"
    fi
    restart_gs || die "替换成功但重启失败 —— 用 .jenkins/lib/local_deploy.sh rollback 回到备份"
  fi
  return 0
}

cmd_health() {
  local rc=0
  log "① 端口与进程"
  local pid=""
  if [[ "$DRY_RUN" == "1" ]]; then echo "    [dry-run] 跳过"; return 0; fi
  if wait_port_listen $PORT 150; then
    pid="$(port_pid $PORT)"; ok ":${PORT} 在听 (pid=$pid)"
  else
    warn ":${PORT} 150s 内没起来"
    collect_log_after; tail -n 25 "$LOCAL_RUN/after.log" 2>/dev/null | sed 's/^/    | /'
    return 1
  fi

  if [[ ! -f "$LOCAL_RUN/backup-path.txt" ]]; then
    log "② 启动完成标志 —— 本轮没有部署（无差异或演练），跳过日志增量自检"
    echo "    [info] 只做端口/进程与协议连通检查；要看启动质量请先真正部署一版"
    if [[ "${SKIP_PROTO:-0}" != "1" ]] && [[ -f "$PROJ/scripts/verify/protocol_selftest.py" ]]; then
      log "③ 协议连通探测（只读）"
      "$PY" "$PROJ/scripts/verify/protocol_selftest.py" --host 127.0.0.1 --port $PORT \
        --redis 127.0.0.1:6379 --timeout 4 --json-out "$LOCAL_RUN/proto.json" 2>&1 | tail -6 | sed 's/^/    /'
      [[ ${PIPESTATUS[0]} -eq 0 ]] && ok "协议全通" || { warn "协议探测有需关注项/失败"; rc=3; }
    fi
    return $rc
  fi

  log "② 启动完成标志（本轮新增日志）"
  local i=0
  while [[ $i -lt 60 ]]; do
    collect_log_after
    if /usr/bin/grep -aq "Started GameApplication" "$LOCAL_RUN/after.log"; then break; fi
    i=$((i + 1)); sleep 2
  done
  if /usr/bin/grep -aq "Started GameApplication" "$LOCAL_RUN/after.log"; then
    ok "$(/usr/bin/grep -a "Started GameApplication" "$LOCAL_RUN/after.log" | tail -1 \
          | sed -E 's/.*INFO:Started GameApplication in ([0-9.]+) seconds.*/启动耗时 \1s/')"
  else
    warn "60s 内没看到 Started GameApplication（可能还在加载表）"
    rc=3
  fi

  log "③ 配置表加载"
  local tables
  tables="$(/usr/bin/grep -ac "STableManager - INFO:init" "$LOCAL_RUN/after.log" 2>/dev/null || true)"
  tables="${tables:-0}"
  if [[ "${tables:-0}" -ge 250 ]]; then
    ok "${tables} 张表初始化（基线约 280）"
  elif [[ "${tables:-0}" -gt 0 ]]; then
    warn "只加载了 ${tables} 张表（基线约 280）—— 缺表的老坑，查 SysUtil 补丁与 conf 路径"
    rc=3
  else
    warn "一条 STableManager init 都没有"
    rc=3
  fi

  log "④ 致命异常关键字（本轮新增日志）"
  local fatal
  fatal="$(/usr/bin/grep -aE "OutOfMemoryError|Metaspace|BindException|NoSuchMethodError|ClassNotFoundException|NoClassDefFoundError|LinkageError|UnsatisfiedLinkError|Address already in use" \
           "$LOCAL_RUN/after.log" 2>/dev/null | head -8)"
  if [[ -n "$fatal" ]]; then
    printf '%s\n' "$fatal" | sed 's/^/    ✗ /'
    rc=1
  else
    ok "无类版本 / 端口 / 内存类致命异常"
  fi

  log "⑤ ERROR 行统计"
  local errs
  errs="$(/usr/bin/grep -ac "\[ERROR\]" "$LOCAL_RUN/after.log" 2>/dev/null || true)"
  errs="${errs:-0}"
  if [[ "${errs:-0}" -eq 0 ]]; then
    ok "0 条 ERROR"
  else
    warn "${errs} 条 ERROR（前 5 条如下；已知无害项：StoreLogic totalWeight / 缺 json 版本文件）"
    /usr/bin/grep -a "\[ERROR\]" "$LOCAL_RUN/after.log" | tail -5 | cut -c1-190 | sed 's/^/    | /'
    [[ $rc -eq 0 ]] && rc=3
  fi

  if [[ "${SKIP_PROTO:-0}" != "1" ]]; then
    log "⑥ 协议连通探测（codec / tcp / duplex / auth-guard，只读）"
    if [[ -f "$PROJ/scripts/verify/protocol_selftest.py" ]]; then
      "$PY" "$PROJ/scripts/verify/protocol_selftest.py" \
        --host 127.0.0.1 --port $PORT --redis 127.0.0.1:6379 \
        --timeout 4 --json-out "$LOCAL_RUN/proto.json" 2>&1 | tail -12 | sed 's/^/    /'
      local prc=${PIPESTATUS[0]}
      if [[ $prc -eq 0 ]]; then
        ok "协议全通"
      elif [[ $prc -eq 3 ]]; then
        warn "协议有需关注项（见上）"
        [[ $rc -eq 0 ]] && rc=3
      else
        warn "协议探测失败（rc=${prc}）"
        [[ $rc -eq 0 ]] && rc=3
      fi
    else
      warn "找不到 scripts/verify/protocol_selftest.py，跳过"
    fi
  fi

  log "小结"
  echo "    游戏服 pid=${pid}  端口 ${PORT}  日志增量 $(wc -l < "$LOCAL_RUN/after.log" | tr -d ' ') 行"
  echo "    增量日志：$LOCAL_RUN/after.log"
  return $rc
}

cmd_rollback() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    # 文件名 gameSrv-YYYYMMDD-HHMMSS.jar ⇒ 字典序降序 = 时间倒序（别用 ls -t，见备份处注释）
    target="$(ls -1 "$BACKUP_DIR"/gameSrv-*.jar 2>/dev/null | sort -r | head -1)"
  fi
  [[ -n "$target" && -f "$target" ]] || die "没有可用备份（${BACKUP_DIR}）"
  log "回滚到：${target}（$(date -r "$target" '+%Y-%m-%d %H:%M')）"
  if [[ -f "$target.sha256" ]]; then
    local want have
    want="$(cat "$target.sha256")"
    have="$(shasum -a 256 "$target" | awk '{print $1}')"
    [[ "$want" == "$have" ]] && ok "备份校验和一致" || die "备份文件已损坏（sha256 不符）"
  fi
  # 同批次 lib module 备份：gameSrv-<stamp>.jar ⇔ lib-<stamp>/
  local stamp libbak
  stamp="$(basename "$target" .jar)"; stamp="${stamp#gameSrv-}"
  libbak="$BACKUP_DIR/lib-$stamp"
  if [[ -d "$libbak" ]]; then
    ok "找到同批次 lib module 备份：$(ls -1 "$libbak" 2>/dev/null | wc -l | tr -d ' ') 个 jar"
  else
    echo "    [info] 没有同批次 lib 备份（那次部署没改 lib module）"
  fi
  # 与 deploy 顺序对称：先 lib 后主 jar
  if [[ -d "$libbak" ]]; then
    local f
    for f in "$libbak"/*.jar; do
      [[ -f "$f" ]] || continue
      cp -p "$f" "$GS_HOME/lib/$(basename "$f")" || die "还原失败：lib/$(basename "$f")"
    done
    ok "lib module 已还原"
  fi
  # 与 deploy 走同一条替换路径：副本 → 原子 mv → restart_gs（不碰 launchd 托管）
  local tmpjar="$GS_HOME/.gameSrv-rollback-$(date +%Y%m%d-%H%M%S).new"
  cp -p "$target" "$tmpjar" || die "复制备份失败"
  mv -f "$tmpjar" "$GS_JAR" || die "还原失败"
  ok "jar 已还原（$(du -h "$GS_JAR" | cut -f1)）"
  restart_gs || die "还原成功但重启失败"
  write_log_baseline
  return 0
}

cmd_all() {
  cmd_precheck || return $?
  cmd_build || return $?
  local rc
  cmd_diff; rc=$?
  [[ $rc -eq 3 ]] && { ok "无差异，跳过部署"; return 3; }
  [[ $rc -ne 0 ]] && return $rc
  cmd_deploy; rc=$?
  [[ $rc -ne 0 && $rc -ne 3 ]] && return $rc
  cmd_health
}

case "$CMD" in
  info)      cmd_info ;;
  precheck)  cmd_precheck ;;
  build)     cmd_build ;;
  diff)      cmd_diff ;;
  deploy)    cmd_deploy ;;
  health)    cmd_health ;;
  rollback)  cmd_rollback "$@" ;;
  all)       cmd_all ;;
  -h|--help) sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "未知子命令：${CMD}（info|precheck|build|diff|deploy|health|rollback|all）" >&2; exit 2 ;;
esac
rc=$?
if [[ $rc -eq 0 && ${WARNINGS:-0} -gt 0 ]]; then exit 3; fi
exit $rc
