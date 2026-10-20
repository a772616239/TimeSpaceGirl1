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

RUN_DIR="${TS_RUN_DIR:-$PROJ/.jenkins/run/adhoc-$(date +%Y%m%d-%H%M%S)}"
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
  echo "    [info] 本次登录会话内非 launchd 托管（launchctl bootstrap 在 Jenkins shell 里恒 rc=5）"
  echo "    [info] 后果：进程崩了不会自动拉起；重新登录 Mac 时 LaunchAgents 里的 plist 会自动恢复托管"
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

# ------------------------------------------------------------------- 子命令 --
cmd_info() {
  log "本地测试服现状"
  local pid
  pid="$(port_pid $PORT)"
  if [[ -n "$pid" ]]; then ok "游戏服 :${PORT} 在听 (pid=$pid)"; else warn "游戏服 :${PORT} 未监听"; fi
  if /bin/launchctl print "gui/$(id -u)/com.ts.localserver.gameserver" >/dev/null 2>&1; then
    ok "launchd 托管：loaded（进程退出会被拉起）"
  else
    warn "launchd 托管：NOT loaded（当前是独立会话进程；本次登录会话内不会自动拉起，重新登录后 plist 自动恢复托管）"
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
  log "差异分析（编译产物 vs 本地服 jar）"
  local rc
  "$PY" "$DIFF_SCRIPT" \
    --src "$SRC_JAR" --dst "$GS_JAR" \
    --json "$LOCAL_RUN/diff.json" \
    --list "$LOCAL_RUN/inject.list" \
    --staging "$LOCAL_RUN/staging"
  rc=$?
  [[ $rc -ne 0 ]] && die "差异分析失败（rc=${rc}）"
  local n
  n="$(wc -l < "$LOCAL_RUN/inject.list" | tr -d ' ')"
  echo "  待注入 ${n} 条（清单 $LOCAL_RUN/inject.list）"
  if [[ "$n" -eq 0 ]]; then
    echo "    [info] 代码与本地服完全一致 —— 无需注入（不做重启）"
    return 3
  fi
  return 0
}

cmd_deploy() {
  local rc
  if [[ ! -s "$LOCAL_RUN/inject.list" ]]; then
    cmd_diff || { rc=$?; [[ $rc -eq 3 ]] && { ok "无变化，跳过部署（不做重启）"; return 0; }; return $rc; }
  fi
  local n
  n="$(wc -l < "$LOCAL_RUN/inject.list" | tr -d ' ')"
  [[ "$n" -eq 0 ]] && { ok "无变化，跳过部署（不做重启）"; return 0; }

  # ---- 1. 备份 -------------------------------------------------------------
  local stamp bak
  stamp="$(date +%Y%m%d-%H%M%S)"
  bak="$BACKUP_DIR/gameSrv-$stamp.jar"
  log "① 备份当前 jar"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "    [dry-run] cp -p \"$GS_JAR\" \"$bak\""
  else
    cp -p "$GS_JAR" "$bak" || die "备份失败（无备份绝不注入）"
    shasum -a 256 "$bak" | awk '{print $1}' > "$bak.sha256"
    ok "备份：${bak}（$(du -h "$bak" | cut -f1)）"
    printf '%s\n' "$bak" > "$LOCAL_RUN/backup-path.txt"
    ls -1 "$BACKUP_DIR"/gameSrv-*.jar 2>/dev/null | sort -r | tail -n +16 | while read -r old; do
      rm -f "$old" "$old.sha256"
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
  log "② 在副本上注入 ${n} 个差异条目（zip -u 分批，staging 已 touch 过 mtime）"
  if [[ "$DRY_RUN" == "1" ]]; then
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
  log "③ 注入复核（逐条目 CRC 比回编译产物）"
  if [[ "$DRY_RUN" == "1" ]]; then
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

  # ---- 5. 原子替换 + 重启 --------------------------------------------------
  log "④ 原子替换正式 jar 并重启"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "    [dry-run] mv -f $tmpjar $GS_JAR && 重启游戏服"
  else
    mv -f "$tmpjar" "$GS_JAR" || die "mv 替换失败"
    ok "jar 已替换（$(du -h "$GS_JAR" | cut -f1)）"
    restart_gs || die "替换成功但重启失败 —— 用 $BASH .jenkins/lib/local_deploy.sh rollback 回到备份"
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
