#!/usr/local/bin/bash
# =============================================================================
# server_release.sh —— 服务端「代码发包正式服」的唯一执行口
#
# 为什么要有这一层
# ----------------
# 这套流程以前是人肉拼命令：git 切分支 → gradlew 编译 → 比线上 jar → 备份 →
# `zip -u` 注入 → 重启 → 看日志。每一步都有坑，且顺序不能错：
#
#   • 在**脏工作区**编译 ⇒ 产物不属于任何提交，release 分支就成了一张空头支票；
#   • 用 `package.sh` 全量包覆盖线上 jar ⇒ 顺手把线上**没上线的改动**回退，
#     还会带走 conf/ 与 assets 的运行时数据（2026-10-18 已定论，见 deploy/DEPLOY-STEPS.md）；
#   • 不看逐条目 CRC 就注入 ⇒ 不知道到底改了哪些类，回滚时也无从判断；
#   • 先覆盖后备份 ⇒ 出事只能重装。
#
# 所以顺序被固化成：预检 → 切 release 分支（独立 worktree）→ 编译 → 与线上逐条目 diff
#   → 人工审批 → 备份 → 按差异注入 → 重启 → 自检 → 回写发布记录。
#
# 🔴 红线
#   1. 本脚本**不做**审批判断 —— 审批在 Pipeline 层（input 步骤）。
#   2. `SR_DEPLOY=true` 才会碰生产；其余情况只读 + 本地构建。
#   3. 注入基线永远是**线上 jar**，只 `zip -u` 差异条目；MANIFEST / *.properties
#      永不注入（默认 exclude 覆盖），避免顺手换依赖链或把开发配置推上去。
#   4. 编译在 `git worktree` 里做：主工作区（并行会话在改）一个字节都不动。
#
# 子命令（Pipeline 只调这些）
#   preflight  只读预检：仓库/工作区/工具链/生产状态 → rc 0 通过 / 3 关注 / 1 失败
#   branch     建 release 分支 + 独立 worktree，记录源提交
#   build      worktree 内 JDK8 + gradle 编译（serverlogic / chatserver / gamecommon）
#   verify     产物校验：完整性 / 字节码 major / 注入边界 / 依赖集合
#   diff       与线上 jar 逐条目 CRC 比对 → 注入清单
#   backup     线上备份（jar + config + MD5SUMS）
#   deploy     按差异注入 + 重启
#   health     上线自检（实例/端口/认证/OOM/注入条目 CRC 复核）
#   record     写发布记录 + 台账，提交 release 分支并打 tag（必要时 push）
#   rollback   恢复最近一次备份并重启
#   cleanup    删除 worktree（分支与记录保留）
#
# 环境变量（全部由 job 下发，缺省值只够本地手工试跑）
#   SR_RUN_DIR*        本次证据目录（必填）
#   SR_SRC_REPO        服务端仓库（缺省 <工程>/TimeSpaceServer/Server_x1tag1.2.2）
#   SR_SOURCE_BRANCH   源分支（缺省 x1-tag-1.2.2）
#   SR_RELEASE_BRANCH  指定 release 分支名（缺省按时间自动生成）
#   SR_DEPLOY          true 才碰生产
#   SR_RESTART         gameserver | none | all
#   SR_ONLY/SR_EXCLUDE 注入条目的 include/exclude glob（逗号分隔）
#   SR_ALLOW_DIRTY     主工作区脏时是否继续（脏项不参与构建，只记录）
#   SR_PUSH            是否把 release 分支/记录推到 origin
#   SR_ROLLBACK_DIR    指定回滚用的备份目录（缺省取生产上最新那个）
#
# 退出码：0 通过；3 需关注（脏工作区/无差异/未重启…）；1 失败；64 用法错。
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
HELPER="$HERE/server_release.py"
PY="${PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
BASH_BIN="${BASH:-/usr/local/bin/bash}"

SR_RUN_DIR="${SR_RUN_DIR:?必须传 SR_RUN_DIR（本次证据目录）}"
SR_SRC_REPO="${SR_SRC_REPO:-$PROJ/TimeSpaceServer/Server_x1tag1.2.2}"
SR_SOURCE_BRANCH="${SR_SOURCE_BRANCH:-x1-tag-1.2.2}"
SR_RELEASE_BRANCH="${SR_RELEASE_BRANCH:-}"
SR_DEPLOY="${SR_DEPLOY:-false}"
SR_RESTART="${SR_RESTART:-gameserver}"
SR_ONLY="${SR_ONLY:-}"
SR_EXCLUDE="${SR_EXCLUDE:-}"
SR_ALLOW_DIRTY="${SR_ALLOW_DIRTY:-false}"
SR_PUSH="${SR_PUSH:-true}"
SR_NOTES="${SR_NOTES:-}"
SR_ROLLBACK_DIR="${SR_ROLLBACK_DIR:-}"

# 生产常量（与 docs/server_ops_runbook.md 一致；改路径只改这里）
GS_HOST="${GS_HOST:-gs}"
GS_DIR="/home/java/gameserver"
GS_JAR="$GS_DIR/gameSrv-1.0.0.jar"
GS_GC="$GS_DIR/lib/gamecommon-1.0.0-SNAPSHOT.jar"
CH_DIR="/home/java/chatserver"
CH_JAR="$CH_DIR/chatserver-1.0.0.jar"
STAGING="$GS_DIR/deploy-staging"
JAVA8_CANDIDATES=(
  /usr/local/Cellar/openjdk@8/1.8.0-482/libexec/openjdk.jdk/Contents/Home
  /Library/Java/JavaVirtualMachines/adoptopenjdk-8.jdk/Contents/Home
)

RELRUN="$SR_RUN_DIR/release"
WT="$RELRUN/worktree"
META="$RELRUN/meta.json"
mkdir -p "$RELRUN" "$RELRUN/diff" "$RELRUN/remote" "$RELRUN/build" "$RELRUN/stage"

WARN=0
warn() { printf '\033[1;33m[WARN] %s\033[0m\n' "$*"; WARN=1; }
info() { printf '\033[1;36m==> %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m[FAIL] %s\033[0m\n' "$*"; exit 1; }

# meta.json 的读写：发布记录、看板、回滚全都读它 ⇒ 失败时也必须留下一半
meta_set() {  # meta_set key=value ...
  "$PY" - "$META" "$@" <<'PYEOF'
import json, os, sys
path, pairs = sys.argv[1], sys.argv[2:]
d = {}
if os.path.exists(path):
    try:
        d = json.load(open(path, encoding="utf-8"))
    except Exception:
        d = {}
for p in pairs:
    k, _, v = p.partition("=")
    if v.lower() in ("true", "false"):
        d[k] = (v.lower() == "true")
    elif v.lstrip("-").isdigit():
        d[k] = int(v)
    else:
        d[k] = v
tmp = path + ".tmp"
json.dump(d, open(tmp, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
os.replace(tmp, path)
PYEOF
}
meta_get() { "$PY" -c 'import json,sys;print(json.load(open(sys.argv[1],encoding="utf-8")).get(sys.argv[2],""))' "$META" "$1" 2>/dev/null; }
jcount()   { "$PY" -c 'import json,sys;print(json.load(open(sys.argv[1]))["counts"]["selected"])' "$1" 2>/dev/null || echo 0; }

# 所有远端动作都走 `ssh gs bash -s` + **带引号的 heredoc**：
# 双引号拼 ssh 命令时 `\$` 的转义层数/`$(())` 嵌套极易出错（踩过），heredoc 一次讲清。
rsh() { ssh -o BatchMode=yes -o ConnectTimeout="${RTO:-20}" "$GS_HOST" "bash -s"; }

# 本次到底会不会重启生产？（决定「长连接」是告警还是仅供参考）
#   🔴 演练（SR_DEPLOY=false）与 RESTART=none 都不会踢线 ⇒ 长连接一律只当信息行。
#      早期版本不区分，结果：线上哪怕只有 1 条心跳连接，演练也会被染成 UNSTABLE（黄球），
#      而黄球一多就没人看颜色了 —— 告警必须与「真会造成的后果」对齐。
will_restart() {
  [[ "${SR_ACTION:-release}" == "rollback" ]] && return 0
  [[ "${SR_DEPLOY,,}" == "true" && "${SR_RESTART,,}" != "none" ]]
}

# 生产状态只读探测：预检与「回滚模式」都要用，抽出来免得两份口径漂移
probe_remote() {
  local remote_out=""
  RTO=12
  if remote_out="$(rsh <<'REMOTE'
echo "jar_md5=$(md5sum /home/java/gameserver/gameSrv-1.0.0.jar 2>/dev/null | cut -d' ' -f1)"
echo "jar_bytes=$(stat -c%s /home/java/gameserver/gameSrv-1.0.0.jar 2>/dev/null)"
echo "gc_md5=$(md5sum /home/java/gameserver/lib/gamecommon-1.0.0-SNAPSHOT.jar 2>/dev/null | cut -d' ' -f1)"
echo "gs_pid=$(pgrep -cf gameSrv-1.0.0.jar)"
echo "chat_pid=$(pgrep -cf chatserver-1.0.0.jar)"
echo "port=$(ss -ltn 2>/dev/null | grep -c ':16081 ')"
echo "conn=$(ss -tn state established 2>/dev/null | grep -c ':16081 ')"
echo "mem_avail=$(free -m | awk '/^Mem:/{print $7}')"
echo "disk_avail=$(df -m / | awk 'NR==2{print $4}')"
echo "restart_sh=$([ -f /home/java/gameserver/RESTART-GAMESERVER.sh ] && echo 1 || echo 0)"
echo "backups=$(ls -d /home/java/gameserver/deploy-staging/*/backup 2>/dev/null | wc -l)"
REMOTE
)"; then
    printf '%s\n' "$remote_out" | sed 's/^/   /'
    local conn mem disk rsh_
    conn="$(printf '%s\n' "$remote_out" | sed -n 's/^conn=//p')"
    mem="$(printf '%s\n'  "$remote_out" | sed -n 's/^mem_avail=//p')"
    disk="$(printf '%s\n' "$remote_out" | sed -n 's/^disk_avail=//p')"
    rsh_="$(printf '%s\n' "$remote_out" | sed -n 's/^restart_sh=//p')"
    # 🔴 长连接：只有真会重启才算警告（会踢玩家）；演练/不重启只是参考信息
    if [[ "${conn:-0}" -gt 0 ]]; then
      if will_restart; then
        warn "生产服当前 ${conn} 条 16081 长连接 —— 重启会踢线（先确认是否可以）"
      else
        echo "   [info] 生产服当前 ${conn} 条 16081 长连接（本次不重启，不影响）"
      fi
    fi
    [[ "${mem:-9999}" -lt 400 ]] && warn "生产服可用内存仅 ${mem} MB（重启窗口紧张，盯一下）"
    [[ "${disk:-9999}" -lt 1024 ]] && warn "生产服根盘可用 ${disk} MB（<1G，注入/备份可能失败）"
    [[ "${rsh_:-0}" != "1" ]] && warn "生产服缺少 RESTART-GAMESERVER.sh，重启环节会失败"
    printf '%s\n' "$remote_out" > "$RELRUN/remote-before.txt"
    return 0
  fi
  warn "SSH 到生产服失败（${GS_HOST}）—— 若本次只构建不上线，可忽略"
  return 1
}

# --------------------------------------------------------------------------- #
cmd_preflight() {
  local rc=0

  # 回滚不需要仓库/编译：只看生产是否可达、有没有可用的备份
  if [[ "${SR_ACTION:-release}" == "rollback" ]]; then
    info "回滚模式：只检查生产服连通性与可用备份（不需要仓库与编译）"
    probe_remote || rc=1
    local nb
    nb="$(sed -n 's/^backups=//p' "$RELRUN/remote-before.txt" 2>/dev/null)"
    if [[ "${nb:-0}" -eq 0 && -z "$SR_ROLLBACK_DIR" ]]; then
      warn "生产上找不到任何备份目录（deploy-staging/*/backup）—— 无法回滚"
      rc=1
    fi
    meta_set "stamp=$(date +%Y%m%d-%H%M)" "source_branch=rollback" "deployed=false" \
             "job=${SR_JOB:-}" "build=${SR_BUILD:-}" "build_url=${SR_URL:-}" \
             "operator=${SR_OPERATOR:-}" "notes=$SR_NOTES" \
             "target=正式服 $GS_HOST:/home/java"
    [[ $rc -eq 0 && $WARN -eq 1 ]] && return 3
    return $rc
  fi

  info "1/6 仓库与分支"
  [[ -d "$SR_SRC_REPO" ]] || die "找不到服务端仓库：$SR_SRC_REPO"
  git -C "$SR_SRC_REPO" rev-parse --verify "$SR_SOURCE_BRANCH" >/dev/null 2>&1 \
    || die "源分支不存在：$SR_SOURCE_BRANCH"
  local head subject
  head="$(git -C "$SR_SRC_REPO" rev-parse "$SR_SOURCE_BRANCH")"
  subject="$(git -C "$SR_SRC_REPO" log -1 --format=%s "$head" | tr -d '\n')"
  echo "   源分支 $SR_SOURCE_BRANCH = ${head:0:12} $subject"

  info "2/6 源码工作区是否干净（🔴 脏 ⇒ 产物不属于任何提交）"
  # 🔴 必须把「构建残留」从「源码改动」里摘出来再判：
  #    这个仓把 gradle 缓存（server_game/.gradle_home，11918 个文件）和 dist/ 也纳入了版本管理，
  #    所以**每跑一次编译**都会冒出十几项脏 —— 若一律当源码脏，发布会永远过不去。
  #    构建残留只报告不阻断；真正需要先提交的是源码。
  local dirty_all dirty_build dirty_src dirty_count ignore_re
  ignore_re='^server_game/\.gradle_home/|^server_game/dist/|^server_game/dist\.bak\.|/build/|^proto/tools/protobuf-2\.5\.0/|^server_game/[^/]+/lib/[^/]+\.jar$'
  dirty_all="$(git -C "$SR_SRC_REPO" status --porcelain | cut -c4-)"
  dirty_build="$(printf '%s\n' "$dirty_all" | /usr/bin/grep -E "$ignore_re" | /usr/bin/grep -c . || true)"
  dirty_src="$(printf '%s\n' "$dirty_all" | /usr/bin/grep -v -E "$ignore_re" | /usr/bin/grep -c . || true)"
  dirty_count="${dirty_src:-0}"
  echo "   源码改动 ${dirty_src:-0} 项 · 构建残留（gradle 缓存 / dist / lib jar）${dirty_build:-0} 项"
  if [[ "${dirty_src:-0}" -gt 0 ]]; then
    echo "   源码未提交改动（前 10）："
    printf '%s\n' "$dirty_all" | /usr/bin/grep -v -E "$ignore_re" | head -10 | sed 's/^/     /'
    if [[ "$SR_ALLOW_DIRTY" == "true" ]]; then
      warn "源码有 ${dirty_src} 项未提交改动；按 ALLOW_DIRTY 继续 —— 这些改动**不参与构建**，只在记录里留痕"
    else
      echo "   🔴 发布必须基于一次明确的提交。先提交/暂存，或勾 ALLOW_DIRTY（不参与构建，仅记录）。"
      rc=1
    fi
  else
    echo "   源码干净 ✓（构建产物 = 源分支最新提交）"
  fi

  info "3/6 与远端的关系"
  local ahead behind
  behind="$(git -C "$SR_SRC_REPO" rev-list --count "origin/$SR_SOURCE_BRANCH..$SR_SOURCE_BRANCH" 2>/dev/null || echo '?')"
  ahead="$(git -C "$SR_SRC_REPO" rev-list --count "$SR_SOURCE_BRANCH..origin/$SR_SOURCE_BRANCH" 2>/dev/null || echo '?')"
  echo "   本地领先 origin/${SR_SOURCE_BRANCH}：${behind}；落后：$ahead"
  [[ "${ahead}" != "0" && "${ahead}" != "?" ]] && warn "源分支落后远端 ${ahead} 个提交（先 fetch/合并再发更稳）"

  info "4/6 工具链（JDK8 / gradle wrapper / 缓存）"
  local jh=""
  local c
  for c in "${JAVA8_CANDIDATES[@]}"; do
    if [[ -x "$c/bin/javac" && -f "$c/lib/tools.jar" ]]; then jh="$c"; break; fi
  done
  [[ -n "$jh" ]] || die "找不到 JDK 8（需要 lib/tools.jar）。构建必须 JDK8：gradle 4.8 + source 1.8"
  echo "   JAVA_HOME=$jh"
  "$jh/bin/java" -version 2>&1 | head -1 | sed 's/^/   /'
  [[ -f "$SR_SRC_REPO/server_game/gradlew" ]] || die "缺少 gradlew"
  [[ -d "$SR_SRC_REPO/server_game/.gradle_home/wrapper/dists" ]] \
    || warn "缺少 gradle wrapper 缓存（.gradle_home/wrapper/dists），首次构建会联网下载"
  [[ -f "$HELPER" ]] || die "缺少 $HELPER"

  info "5/6 生产服连通性（只读）"
  probe_remote || true

  info "6/6 落 meta"
  meta_set "stamp=$(date +%Y%m%d-%H%M)" \
           "source_branch=$SR_SOURCE_BRANCH" \
           "source_commit=$head" \
           "commit_subject=$subject" \
           "dirty_count=${dirty_count:-0}" \
           "deployed=false" \
           "job=${SR_JOB:-}" "build=${SR_BUILD:-}" "build_url=${SR_URL:-}" \
           "operator=${SR_OPERATOR:-}" "notes=$SR_NOTES" \
           "target=正式服 $GS_HOST:/home/java"
  "$PY" - "$META" "${dirty_count:-0}" $'\n'"$(printf '%s\n' "$dirty_all" | /usr/bin/grep -v -E "$ignore_re")" <<'PYEOF'
import json, sys
p, _cnt, blob = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(p, encoding="utf-8"))
d["dirty_files"] = [x for x in blob.splitlines() if x.strip()][:50]
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PYEOF

  if [[ $rc -eq 0 ]]; then
    if [[ $WARN -eq 1 ]]; then
      echo "   预检通过（含关注项，见上面 [WARN]）"
      return 3
    fi
    echo "   预检通过 ✓"
  fi
  return $rc
}

# --------------------------------------------------------------------------- #
cmd_branch() {
  local stamp ver br
  stamp="$(meta_get stamp)"; [[ -n "$stamp" ]] || stamp="$(date +%Y%m%d-%H%M)"
  ver="${SR_SOURCE_BRANCH#x1-tag-}"
  br="${SR_RELEASE_BRANCH:-release/x1-$ver-$stamp}"

  info "切 release 分支：${br}（从 ${SR_SOURCE_BRANCH}，独立 worktree）"
  if git -C "$SR_SRC_REPO" rev-parse --verify "$br" >/dev/null 2>&1; then
    die "分支已存在：${br}（同一分钟重复构建？换 RELEASE_BRANCH 或等一分钟）"
  fi
  if [[ -e "$WT" ]]; then
    git -C "$SR_SRC_REPO" worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"
  fi

  # 🔴 worktree 而不是 checkout：主工作区正被并行会话改着，切分支会把人家 WIP 一起带走。
  #    独立 worktree 让「release 分支 = 编译产物」成立，且主工作区零影响。
  git -C "$SR_SRC_REPO" worktree add -b "$br" "$WT" "$SR_SOURCE_BRANCH" 2>&1 | tail -3 | sed 's/^/   /' \
    || die "worktree 创建失败"

  local commit
  commit="$(git -C "$WT" rev-parse HEAD)"
  if [[ -n "$(git -C "$WT" status --porcelain)" ]]; then
    die "release worktree 不干净，拒绝继续（$(git -C "$WT" status --porcelain | wc -l | tr -d ' ') 项）"
  fi
  echo "   worktree：$WT"
  echo "   分支：$br @ ${commit:0:12}"
  meta_set "release_branch=$br" "source_commit=$commit" "worktree=$WT"
  echo "$br" > "$RELRUN/release_branch.txt"
  return 0
}

# --------------------------------------------------------------------------- #
cmd_build() {
  local jh="" c
  for c in "${JAVA8_CANDIDATES[@]}"; do
    if [[ -x "$c/bin/javac" && -f "$c/lib/tools.jar" ]]; then jh="$c"; break; fi
  done
  [[ -n "$jh" ]] || die "找不到 JDK 8"
  [[ -d "$WT" ]] || die "worktree 不存在（先跑 branch）"

  info "编译（worktree 内，JDK8 + gradle 4.8）"
  export JAVA_HOME="$jh"
  # 复用主仓库 gradle 缓存：不联网、不重复下载；--no-daemon 不留常驻进程
  export GRADLE_USER_HOME="$SR_SRC_REPO/server_game/.gradle_home"
  cd "$WT/server_game" || die "进入 worktree/server_game 失败"

  # 🔴 只编译真正部署的两个模块：根目录 `gradle build` 会带上 worldserver 等不部署的模块
  sh ./gradlew --no-daemon --console=plain :serverlogic:jar :chatserver:jar 2>&1 | tail -40
  local rc=${PIPESTATUS[0]}
  [[ ${rc} -eq 0 ]] || die "gradle 构建失败（rc=${rc}）"

  local sl="$WT/server_game/serverlogic/build/libs/serverlogic-1.0.0.jar"
  local ch="$WT/server_game/chatserver/build/libs/chatserver-1.0.0.jar"
  local gc="$WT/server_game/gamecommon/build/libs/gamecommon-1.0.0-SNAPSHOT.jar"
  [[ -f "$sl" ]] || die "未产出 $sl"
  [[ -f "$gc" ]] || die "未产出 gamecommon jar（协议类都在里面，缺了必 NoSuchMethodError）"

  # 复制到证据目录：worktree 收尾会被删，而 diff / 注入 / 复核都还要用
  cp -f "$sl" "$RELRUN/build/serverlogic-1.0.0.jar"
  cp -f "$gc" "$RELRUN/build/gamecommon-1.0.0-SNAPSHOT.jar"
  [[ -f "$ch" ]] && cp -f "$ch" "$RELRUN/build/chatserver-1.0.0.jar"

  local f
  for f in "$RELRUN/build"/*.jar; do
    printf '   %-44s %8s  md5=%s\n' "$(basename "$f")" "$(du -h "$f" | cut -f1)" "$(md5 -q "$f")"
  done
  meta_set "built_at=$(date '+%Y-%m-%d %H:%M:%S')"
  return 0
}

# --------------------------------------------------------------------------- #
cmd_verify() {
  local rc=0 f last

  info "产物校验（完整性 / 字节码版本 / 注入边界）"
  for f in "$RELRUN/build"/*.jar; do
    last="$(unzip -t "$f" 2>&1 | tail -1)"
    if [[ "$last" == *"No errors"* ]]; then
      echo "   ✓ $(basename "$f") 完整性 OK"
    else
      echo "   🔴 $(basename "$f") 完整性失败：$last"
      rc=1
    fi
  done

  # 字节码 major 必须 52（Java 8）：本地产物与线上 class 必须同源
  local cls major badv=0 checked=0
  # 🔴 不要在这里接 `| head -20`：pipefail 下 head 提前退出会让 awk 收 SIGPIPE，
  #    日志里冒出 "awk: write error on /dev/stdout"，看着像失败其实是假红。用 awk 自己计数。
  for cls in $(unzip -l "$RELRUN/build/serverlogic-1.0.0.jar" | /usr/bin/awk '$NF ~ /\.class$/ && ++n <= 20 {print $NF}'); do
    major="$(unzip -p "$RELRUN/build/serverlogic-1.0.0.jar" "$cls" 2>/dev/null \
             | /usr/bin/od -An -tu1 -j6 -N2 | /usr/bin/awk '{print $2}')"
    checked=$((checked+1))
    [[ "$major" == "52" ]] || { echo "   🔴 字节码版本异常：$cls major=$major"; badv=$((badv+1)); }
  done
  if [[ $badv -eq 0 ]]; then
    echo "   ✓ 抽样 ${checked} 个 class，major 全为 52（Java 8，可与线上 class 混用）"
  else
    rc=1
  fi

  # 注入边界：MANIFEST/properties 必须在排除名单里（否则等于顺手换依赖链 / 连错库）
  if [[ "$SR_EXCLUDE" == *"META-INF"* || -z "$SR_EXCLUDE" ]]; then
    echo "   ✓ MANIFEST / application*.properties 不在注入范围（默认排除）"
  else
    echo "   ⚠️ EXCLUDE 未覆盖 META-INF：MANIFEST 会被注入（改写 Class-Path，慎用）"
  fi

  local libn
  libn="$(ls "$WT/server_game/serverlogic/lib"/*.jar 2>/dev/null | wc -l | tr -d ' ')"
  echo "   本地 serverlogic/lib：${libn} 个 jar（与线上 MANIFEST 的 Class-Path 条数在 diff 环节核对）"
  meta_set "lib_jars=${libn:-0}"
  return $rc
}

# --------------------------------------------------------------------------- #
cmd_diff() {
  info "取线上 jar 基线（只读下载，用于逐条目比对）"
  scp -q -o ConnectTimeout=20 "$GS_HOST:$GS_JAR" "$RELRUN/remote/gameSrv-1.0.0.jar" \
    || die "下载线上 gameSrv jar 失败 —— 不知道基线就不能发布"
  scp -q -o ConnectTimeout=20 "$GS_HOST:$GS_GC" "$RELRUN/remote/gamecommon-1.0.0-SNAPSHOT.jar" \
    || warn "下载线上 gamecommon jar 失败，协议类差异无法比对（🔴 高危）"
  if ssh -o BatchMode=yes -o ConnectTimeout=20 "$GS_HOST" "test -f $CH_JAR"; then
    scp -q -o ConnectTimeout=20 "$GS_HOST:$CH_JAR" "$RELRUN/remote/chatserver-1.0.0.jar" \
      || warn "下载 chatserver jar 失败"
  else
    echo "   线上没有 chatserver jar（该服当前不跑聊天服），跳过"
  fi

  local rc_any=0 extra=()
  [[ -n "$SR_ONLY" ]]    && extra+=(--include "$SR_ONLY")
  [[ -n "$SR_EXCLUDE" ]] && extra+=(--exclude "$SR_EXCLUDE")

  "$PY" "$HELPER" diff --local "$RELRUN/build/serverlogic-1.0.0.jar" \
       --remote "$RELRUN/remote/gameSrv-1.0.0.jar" --outdir "$RELRUN/diff" --name gameSrv "${extra[@]}" | sed 's/^/   /'
  [[ ${PIPESTATUS[0]} -eq 3 ]] && rc_any=3

  # 🔴 协议类不在主 jar 里（在 lib/gamecommon），改 proto 必须两个包一起上
  if [[ -f "$RELRUN/remote/gamecommon-1.0.0-SNAPSHOT.jar" ]]; then
    "$PY" "$HELPER" diff --local "$RELRUN/build/gamecommon-1.0.0-SNAPSHOT.jar" \
         --remote "$RELRUN/remote/gamecommon-1.0.0-SNAPSHOT.jar" --outdir "$RELRUN/diff" --name gamecommon "${extra[@]}" | sed 's/^/   /'
    [[ ${PIPESTATUS[0]} -eq 3 ]] && rc_any=3
  fi
  if [[ -f "$RELRUN/build/chatserver-1.0.0.jar" && -f "$RELRUN/remote/chatserver-1.0.0.jar" ]]; then
    "$PY" "$HELPER" diff --local "$RELRUN/build/chatserver-1.0.0.jar" \
         --remote "$RELRUN/remote/chatserver-1.0.0.jar" --outdir "$RELRUN/diff" --name chatserver "${extra[@]}" | sed 's/^/   /'
    [[ ${PIPESTATUS[0]} -eq 3 ]] && rc_any=3
  fi

  local total=0 f
  for f in "$RELRUN/diff"/*.diff.json; do
    [[ -f "$f" ]] || continue
    total=$(( total + $(jcount "$f") ))
  done
  meta_set "selected_total=$total"
  echo "   合计将注入：${total} 个条目"

  # overlay 漂移：application.properties / logback-boot.xml 是 package.sh 从 deploy-overlay
  # 注入到线上 jar 的，类级注入**不会**更新它们 —— 不一致必须显式说出来
  local ov lo ro
  for ov in application.properties logback-boot.xml; do
    lo="$WT/server_game/deploy-overlay/gameserver-jar/$ov"
    [[ -f "$lo" ]] || continue
    ro="$(unzip -p "$RELRUN/remote/gameSrv-1.0.0.jar" "$ov" 2>/dev/null | md5 -q)"
    lo="$(md5 -q "$lo")"
    if [[ "$ro" == "$lo" ]]; then
      echo "   ✓ overlay/${ov} 与线上一致"
    else
      warn "overlay/${ov} 与线上 jar 内不一致（类级注入不更新它；要生效需 package 模式或单独注入该文件）"
    fi
  done

  [[ "${total:-0}" -eq 0 ]] && rc_any=3
  return $rc_any
}

# --------------------------------------------------------------------------- #
cmd_backup() {
  local stamp; stamp="$(meta_get stamp)"
  info "线上备份（🔴 覆盖之前必须先有回滚基线）"
  local out
  RTO=30
  out="$(rsh <<REMOTE
set -e
D='$STAGING/$stamp/backup'
mkdir -p "\$D"
cp -a '$GS_JAR' "\$D/" 2>/dev/null || true
cp -a '$GS_GC'  "\$D/" 2>/dev/null || true
[ -f '$CH_JAR' ] && cp -a '$CH_JAR' "\$D/" 2>/dev/null || true
if [ -d '$GS_DIR/config' ]; then
  mkdir -p "\$D/config"
  cp -a '$GS_DIR/config/'*.properties "\$D/config/" 2>/dev/null || true
fi
( cd "\$D" && find . -maxdepth 1 -type f | sed 's|^\./||' | xargs md5sum > MD5SUMS 2>/dev/null ) || true
echo "\$D"
ls -lh "\$D"
REMOTE
)" || die "线上备份失败（磁盘满/权限？绝不能在无备份时注入）"
  local dir
  dir="$(printf '%s\n' "$out" | head -1)"
  printf '%s\n' "$out" | tail -n +2 | sed 's/^/   /'
  echo "$dir" > "$RELRUN/backup.path"
  echo "   备份目录：$dir"
  meta_set "backup_dir=$dir"
  return 0
}

# --------------------------------------------------------------------------- #
# 注入单个 jar：本地抽差异条目 → 传 → 服务器 zip -u → 完整性自检
inject_one() {
  local name="$1" local_jar="$2" remote_jar="$3"
  local dj="$RELRUN/diff/$name.diff.json"
  [[ -f "$dj" ]] || { echo "   （${name} 无差异记录，跳过）"; return 0; }
  local sel; sel="$(jcount "$dj")"
  [[ "${sel:-0}" -gt 0 ]] || { echo "   （${name} 无需注入）"; return 0; }

  info "注入 ${name}：${sel} 个条目"
  local sdir="$RELRUN/stage/$name" list="$RELRUN/stage/$name.list"
  rm -rf "$sdir"; mkdir -p "$sdir"
  "$PY" -c 'import json,sys;print("\n".join(json.load(open(sys.argv[1]))["selected"]))' "$dj" > "$list"

  # 只从本地编译产物里抽选中的条目（🔴 用 python 的 zipfile，别用 `unzip @清单`：
  # macOS 自带的 Info-ZIP 6.00 **不支持** @filelist，会报 "filename not matched" 并 rc=11）
  "$PY" - "$local_jar" "$list" "$sdir" <<'PYEOF' || die "抽取 ${name} 条目失败"
import os, sys, zipfile
jar, lst, out = sys.argv[1], sys.argv[2], sys.argv[3]
keep = [l.strip() for l in open(lst, encoding="utf-8") if l.strip()]
with zipfile.ZipFile(jar) as z:
    names = set(z.namelist())
    missing = [k for k in keep if k not in names]
    for k in keep:
        if k not in names:
            continue
        dst = os.path.join(out, k)
        os.makedirs(os.path.dirname(dst) or out, exist_ok=True)
        with z.open(k) as src, open(dst, "wb") as fh:
            fh.write(src.read())
print("   本地抽取 %d 个条目" % (len(keep) - len(missing)))
if missing:
    sys.stderr.write("   🔴 本地 jar 里缺 %d 个条目：%s\n" % (len(missing), ", ".join(missing[:5])))
    sys.exit(1)
PYEOF
  # 🔴 必须 touch：zip 按 mtime（2 秒粒度）判断是否更新，同秒文件会被静默跳过
  find "$sdir" -type f -exec touch {} + 2>/dev/null || true
  tar -czf "$RELRUN/stage/$name.tgz" -C "$sdir" . || die "打包 staged 条目失败"

  local stamp; stamp="$(meta_get stamp)"
  scp -q -o ConnectTimeout=25 "$RELRUN/stage/$name.tgz" "$GS_HOST:$STAGING/$stamp/" \
    || die "上传 staged 条目失败（${name}）"

  local out
  RTO=45
  out="$(rsh <<REMOTE
set -e
B='$STAGING/$stamp'
rm -rf "\$B/$name"; mkdir -p "\$B/$name"
tar -xzf "\$B/$name.tgz" -C "\$B/$name"
cd "\$B/$name"
find . -type f -exec touch {} +
find . -type f | sed 's|^\./||' | sort > /tmp/inject.list
echo "   服务器侧收到条目：\$(wc -l < /tmp/inject.list)"
split -l 80 /tmp/inject.list /tmp/inject.part.
for p in /tmp/inject.part.*; do
  /usr/bin/zip -u -q '$remote_jar' \$(cat \$p) || { echo "   🔴 zip -u 失败（批次 \$p）"; exit 1; }
done
rm -f /tmp/inject.part.* /tmp/inject.list
/usr/bin/unzip -t '$remote_jar' >/dev/null 2>&1 && echo "   ✓ 注入后 unzip -t OK" || { echo "   🔴 注入后 jar 完整性失败"; exit 1; }
REMOTE
)" || { printf '%s\n' "$out" | sed 's/^/   /'; die "${name} 注入失败"; }
  printf '%s\n' "$out"
  return 0
}

cmd_deploy() {
  [[ "$SR_DEPLOY" == "true" ]] || { echo "   DEPLOY=false：只构建 + 比对 + 记录，不碰生产"; return 0; }
  info "开始注入（基线 = 线上 jar，只改差异条目）"

  inject_one gameSrv "$RELRUN/build/serverlogic-1.0.0.jar" "$GS_JAR"
  if [[ -f "$RELRUN/build/gamecommon-1.0.0-SNAPSHOT.jar" ]]; then
    inject_one gamecommon "$RELRUN/build/gamecommon-1.0.0-SNAPSHOT.jar" "$GS_GC"
  fi
  local chsel=0
  [[ -f "$RELRUN/diff/chatserver.diff.json" ]] && chsel="$(jcount "$RELRUN/diff/chatserver.diff.json")"
  if [[ "${chsel:-0}" -gt 0 ]]; then
    inject_one chatserver "$RELRUN/build/chatserver-1.0.0.jar" "$CH_JAR"
  fi

  meta_set "deployed=true" "deployed_at=$(date '+%Y-%m-%d %H:%M:%S')" "restart=$SR_RESTART"

  # 重启前的日志行号：health 只看「本次重启之后」新增的那一段，避免历史错误混进判据
  if [[ "$SR_RESTART" == "gameserver" || "$SR_RESTART" == "all" ]]; then
    local before
    before="$(rsh <<'REMOTE'
wc -l < /data/srvlog/gameserver.log 2>/dev/null || echo 0
REMOTE
)"
    echo "${before:-0}" > "$RELRUN/log_offset"

    info "重启 gameserver（RESTART-GAMESERVER.sh 自带停服/端口/自检，约 40s）"
    ssh -o BatchMode=yes -o ConnectTimeout=25 "$GS_HOST" \
      "bash /home/java/gameserver/RESTART-GAMESERVER.sh" 2>&1 | tail -30
    local rc=${PIPESTATUS[0]}
    [[ ${rc} -eq 0 ]] || die "重启脚本返回 ${rc}（⚠️ 立刻看健康检查与 /data/srvlog/gameserver.log）"
  else
    warn "按 RESTART=none：只落地不重启 —— 新 class 要等下次重启才生效（游戏服不热更 jar）"
  fi

  if [[ "$SR_RESTART" == "all" && "${chsel:-0}" -gt 0 ]]; then
    info "重启 chatserver（该服默认没跑；若本来没跑，这里会把它拉起来）"
    RTO=30
    rsh <<'REMOTE' | sed 's/^/   /'
pkill -f chatserver-1.0.0.jar 2>/dev/null; sleep 2
mkdir -p /data/dump /data/srvlog
cd /home/java/chatserver || exit 1
nohup java -server -Xms512m -Xmx512m -Xss512k \
  -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=256m \
  -XX:+UseParallelGC -XX:ParallelGCThreads=2 \
  -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/data/dump/chatserver_%p.hprof \
  -XX:+ExitOnOutOfMemoryError -Dfile.encoding=UTF-8 \
  -jar chatserver-1.0.0.jar >> /data/srvlog/chatserver.log 2>&1 &
sleep 3
echo "chatserver 实例数：$(pgrep -cf chatserver-1.0.0.jar)"
REMOTE
  fi
  return 0
}

# --------------------------------------------------------------------------- #
cmd_health() {
  local rc=0 audited=0 bad=0
  info "上线自检（实例=1 · 16081 在听 · 认证/绑定/OOM 全 0 · 注入条目 CRC 一致）"

  # ① 注入后复核：把线上 jar 再拉回来逐条目比 CRC —— 「真的改了」的唯一硬证据
  if [[ "$SR_DEPLOY" == "true" ]]; then
    local f name sel local_jar remote_path
    for f in "$RELRUN/diff"/*.diff.json; do
      [[ -f "$f" ]] || continue
      name="$(basename "$f" .diff.json)"
      sel="$(jcount "$f")"
      [[ "${sel:-0}" -gt 0 ]] || continue
      case "$name" in
        gameSrv)    remote_path="$GS_JAR"; local_jar="$RELRUN/build/serverlogic-1.0.0.jar" ;;
        gamecommon) remote_path="$GS_GC";  local_jar="$RELRUN/build/gamecommon-1.0.0-SNAPSHOT.jar" ;;
        chatserver) remote_path="$CH_JAR"; local_jar="$RELRUN/build/chatserver-1.0.0.jar" ;;
        *) continue ;;
      esac
      if scp -q -o ConnectTimeout=20 "$GS_HOST:$remote_path" "$RELRUN/remote/after-$name.jar" 2>/dev/null; then
        if "$PY" "$HELPER" verify-selected --local "$local_jar" \
             --remote "$RELRUN/remote/after-$name.jar" --selected "$f" | sed 's/^/   /'; then
          audited=$((audited+1))
        else
          bad=$((bad+1))
        fi
      else
        warn "拉回 ${name} 失败，无法复核注入结果"
        bad=$((bad+1))
      fi
    done
  else
    echo "   （未上线：跳过注入复核）"
  fi

  # ② 运行时状态
  local off; off="$(cat "$RELRUN/log_offset" 2>/dev/null || echo 0)"
  local out=""
  RTO=20
  # 🔴 行号必须作为**远端命令的一部分**传进去（`ssh host "OFF=n bash -s"`）：
  #    写在本地 `OFF=n rsh` 前缀里只对本地 ssh 进程生效，远端 heredoc 里读不到（踩过）。
  out="$(ssh -o BatchMode=yes -o ConnectTimeout=20 "$GS_HOST" "OFF=${off:-0} bash -s" <<'REMOTE'
echo "instances=$(pgrep -cf gameSrv-1.0.0.jar)"
echo "port=$(ss -ltn 2>/dev/null | grep -c ':16081 ')"
echo "conns=$(ss -tn state established 2>/dev/null | grep -c ':16081 ')"
echo "chat_instances=$(pgrep -cf chatserver-1.0.0.jar)"
W=$(tail -n +$((OFF + 1)) /data/srvlog/gameserver.log 2>/dev/null)
echo "log_lines=$(printf '%s' "$W" | wc -l | tr -d ' ')"
echo "auth_failed=$(printf '%s' "$W" | grep -c 'Authentication failed')"
echo "bind_error=$(printf '%s' "$W" | grep -ci 'already in use\|BindException')"
echo "oom=$(printf '%s' "$W" | grep -c 'OutOfMemoryError')"
echo "error_lines=$(printf '%s' "$W" | grep -c ' ERROR ')"
echo "jar_md5=$(md5sum /home/java/gameserver/gameSrv-1.0.0.jar | cut -d' ' -f1)"
REMOTE
)" || { warn "SSH 采集运行时状态失败"; rc=1; }
  printf '%s\n' "$out" | sed 's/^/   /'

  local instances port conns auth bind oom err
  instances="$(printf '%s\n' "$out" | sed -n 's/^instances=//p')"
  port="$(printf '%s\n'      "$out" | sed -n 's/^port=//p')"
  conns="$(printf '%s\n'     "$out" | sed -n 's/^conns=//p')"
  auth="$(printf '%s\n'      "$out" | sed -n 's/^auth_failed=//p')"
  bind="$(printf '%s\n'      "$out" | sed -n 's/^bind_error=//p')"
  oom="$(printf '%s\n'       "$out" | sed -n 's/^oom=//p')"
  err="$(printf '%s\n'       "$out" | sed -n 's/^error_lines=//p')"

  [[ "${instances:-0}" -eq 1 ]] || { warn "gameserver 实例数不是 1（实际 ${instances:-?}）"; rc=1; }
  [[ "${port:-0}" -ge 1 ]]      || { warn "16081 未监听"; rc=1; }
  [[ "${auth:-1}" -eq 0 ]]      || { warn "出现 Authentication failed（Mongo 串是否含 authSource=admin？）"; rc=1; }
  [[ "${bind:-1}" -eq 0 ]]      || { warn "端口被占用 / BindException"; rc=1; }
  [[ "${oom:-1}" -eq 0 ]]       || { warn "出现 OutOfMemoryError"; rc=1; }
  [[ "${err:-0}" -gt 5 ]]       && warn "重启后 ERROR 行数 ${err}（>5，值得看一眼日志）"

  # ③ 落 health.json（发布记录与看板都读它）
  "$PY" - "$RELRUN/health.json" "$rc" "${instances:-?}" "${port:-?}" "${conns:-0}" \
        "${auth:-?}" "${bind:-?}" "${oom:-?}" "${err:-?}" "$audited" "$bad" <<'PYEOF'
import json, sys, time
path, rc = sys.argv[1], int(sys.argv[2])
inst, port, conns, auth, bind, oom, err, audited, bad = sys.argv[3:12]
checks = {
    "gameserver 实例数（应为 1）": inst,
    "16081 监听（应 ≥1）": port,
    "当前在线连接数": conns,
    "Authentication failed（应 0）": auth,
    "端口占用 / BindException（应 0）": bind,
    "OutOfMemoryError（应 0）": oom,
    "本次重启后 ERROR 行数": err,
    "注入条目 CRC 复核通过的 jar 数": audited,
    "注入条目 CRC 复核失败的 jar 数（应 0）": bad,
}
d = {"finished_at": time.strftime("%Y-%m-%d %H:%M:%S %z"), "checks": checks,
     "verdict": "🔴 有硬指标不达标，见上表" if rc else "✅ 实例 / 端口 / 认证 / OOM / 注入复核全部达标"}
json.dump(d, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PYEOF
  return $rc
}

# --------------------------------------------------------------------------- #
cmd_record() {
  local stamp; stamp="$(meta_get stamp)"
  local br wt
  br="$(meta_get release_branch)"
  wt="$(meta_get worktree)"; wt="${wt:-$WT}"

  if [[ ! -d "$wt" ]]; then
    warn "worktree 不存在（${wt}）：记录只写进证据目录，不提交分支"
    "$PY" "$HELPER" record --run "$SR_RUN_DIR" --stamp "$stamp" 2>&1 | sed 's/^/   /'
    return 0
  fi

  local rdir="$wt/server_game/deploy/releases"
  mkdir -p "$rdir"
  info "写发布记录：server_game/deploy/releases/$stamp.md"
  "$PY" "$HELPER" record --run "$SR_RUN_DIR" --stamp "$stamp" --outdir "$rdir" 2>&1 | sed 's/^/   /' \
    || { warn "记录生成失败"; return 0; }
  meta_set "record_dir=$rdir"
  cp -f "$rdir/$stamp.md" "$RELRUN/record.md" 2>/dev/null || true
  cp -f "$rdir/$stamp.json" "$RELRUN/record.json" 2>/dev/null || true

  # 只 add 记录文件（🔴 绝不 git add -A：这个仓有并行会话在改源码）
  git -C "$wt" add "server_game/deploy/releases/$stamp.md" \
                   "server_game/deploy/releases/$stamp.json" \
                   "server_game/deploy/releases/INDEX.md" 2>/dev/null
  local state="演练"
  [[ "$SR_DEPLOY" == "true" ]] && state="已上线"
  local msg="chore(release): ${stamp} 服务端发布记录（注入 $(meta_get selected_total) 条 · ${state}）"
  if git -C "$wt" commit -q -m "$msg" -- "server_game/deploy/releases"; then
    local cm; cm="$(git -C "$wt" rev-parse --short HEAD)"
    echo "   记录提交：$cm"
    meta_set "record_commit=$cm"
    if git -C "$wt" tag -a "rel-${stamp}" -m "服务端发布 ${stamp}：$(meta_get commit_subject)" 2>/dev/null; then
      echo "   标签：rel-$stamp"
    fi
  else
    warn "记录提交失败（可能无变化）"
  fi

  # 推送只在真上线时做（演练不该在远端留一堆分支）；推送失败只标黄
  if [[ "$SR_DEPLOY" == "true" && "$SR_PUSH" == "true" ]]; then
    info "推送 release 分支与标签到 origin"
    if git -C "$wt" push -q -u origin "$br" 2>&1 | sed 's/^/   /'; then
      if git -C "$wt" push -q origin "rel-$stamp" 2>&1 | sed 's/^/   /'; then
        meta_set "pushed=true"
        echo "   已推送：$br / rel-$stamp"
      else
        warn "标签推送失败（分支已推；可手工 git push origin rel-${stamp}）"
      fi
    else
      warn "分支推送失败（网络/凭据？分支与标签已在本地，可手工 push）"
    fi
  else
    echo "   跳过推送（DEPLOY=${SR_DEPLOY} / PUSH=${SR_PUSH}）：记录在本地分支与证据目录里"
  fi
  return 0
}

# --------------------------------------------------------------------------- #
cmd_rollback() {
  [[ "$SR_DEPLOY" == "true" ]] || { echo "   DEPLOY=false：回滚同样需要显式授权 → 跳过"; return 0; }
  info "回滚：恢复最近一次备份的 jar 并重启"
  local bdir="$SR_ROLLBACK_DIR"
  if [[ -z "$bdir" ]]; then
    bdir="$(rsh <<REMOTE
ls -dt $STAGING/*/backup 2>/dev/null | head -1
REMOTE
)"
  fi
  [[ -n "$bdir" ]] || die "找不到任何备份目录（$STAGING/*/backup）"
  echo "   备份目录：$bdir"

  RTO=40
  rsh <<REMOTE | sed 's/^/   /' || die "恢复备份失败"
set -e
cd '$bdir'
[ -f MD5SUMS ] && md5sum -c MD5SUMS 2>/dev/null | tail -5 || true
for f in *.jar; do
  case "\$f" in
    gameSrv-*)    cp -a "\$f" '$GS_JAR' ;;
    gamecommon-*) cp -a "\$f" '$GS_GC' ;;
    chatserver-*) cp -a "\$f" '$CH_JAR' ;;
  esac
  echo "已恢复 \$f"
done
if [ -d config ]; then cp -a config/*.properties '$GS_DIR/config/' && echo "已恢复 config/*.properties"; fi
REMOTE

  local before
  before="$(rsh <<'REMOTE'
wc -l < /data/srvlog/gameserver.log 2>/dev/null || echo 0
REMOTE
)"
  echo "${before:-0}" > "$RELRUN/log_offset"
  ssh -o BatchMode=yes -o ConnectTimeout=25 "$GS_HOST" \
    "bash /home/java/gameserver/RESTART-GAMESERVER.sh" 2>&1 | tail -20
  meta_set "deployed=true" "rolled_back=true" "backup_dir=$bdir" "restart=gameserver"
  return 0
}

# --------------------------------------------------------------------------- #
cmd_cleanup() {
  info "清理 worktree（构建产物已复制到证据目录；主工作区从头到尾没被碰过）"
  git -C "$SR_SRC_REPO" worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"
  git -C "$SR_SRC_REPO" worktree prune >/dev/null 2>&1 || true
  echo "   已清理：${WT}（分支保留，它是发布记录的一部分）"
  return 0
}

# --------------------------------------------------------------------------- #
case "${1:-}" in
  preflight) cmd_preflight ;;
  branch)    cmd_branch ;;
  build)     cmd_build ;;
  verify)    cmd_verify ;;
  diff)      cmd_diff ;;
  backup)    cmd_backup ;;
  deploy)    cmd_deploy ;;
  health)    cmd_health ;;
  record)    cmd_record ;;
  rollback)  cmd_rollback ;;
  cleanup)   cmd_cleanup ;;
  ""|-h|--help)
    sed -n '2,52p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "未知子命令：$1" >&2
    echo "可用：preflight branch build verify diff backup deploy health record rollback cleanup" >&2
    exit 64
    ;;
esac
