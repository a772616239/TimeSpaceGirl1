#!/usr/local/bin/bash
# =============================================================================
# stage_apk.sh —— 把本次打出来的 APK 变成「构建产物」（构建页上能点一下就下载）
#
# 为什么需要这一层
# ----------------
# 2026-10-17 之前，TS-Android-TestPackage 打出了 965MB 的 APK，但 job 的归档只有
# `evidence/**`（一堆 json / log），APK 本体只留了一行路径文本。结果是：
#   - 构建页「Build Artifacts」里**没有任何可下载的安装包**；
#   - 想装机必须先知道 `apks/<date>/CLIBuild/` 这个约定，再去本机磁盘上翻；
#   - 而 `evidence/apk.path` 里写的是**相对路径**，离开工程目录就指不到文件。
# 用户的原话是「生成物我期望是 apk，方便我安装」—— 所以 APK 必须是产物本身，
# 不是产物的一条注释。
#
# 为什么先放 workspace/artifacts/ 再由 post 段 archiveArtifacts
# ------------------------------------------------------------
# archiveArtifacts **只能从 workspace 里取文件**（相对路径）。所以这里做的是
# 「把 APK 摆进 workspace 的固定位置」，真正收进 builds/<n>/archive/ 的是 post 段。
#
# 为什么用 clone 而不是普通 cp（很重要）
# ------------------------------------
# APK 有 ~1GB。普通 `cp` 会实打实再占 1GB（apks/ 一份 + workspace 一份，
# 归档时 Jenkins 还要再复制一份 ⇒ 一次构建 3GB）。macOS 的 APFS 支持 `cp -c`
# （clonefile，写时复制）：**瞬间完成、不额外占盘**。所以顺序是：
#     cp -c（APFS 克隆）→ ln（硬链接）→ cp（真复制，最后的兜底）
# 三种方式产出的都是「一个能正常读的文件」，前两种只是不重复占盘。
#
# 🔴 workspace 不清就归档 = 把历次 APK 全部重新归档一遍
# ------------------------------------------------------
# 本 job 的 post 段不做 cleanWs，`artifacts/` 只增不删 ⇒ 若用 `artifacts/*.apk`
# 归档，第 N 次构建会把前 N-1 个旧 APK 一起塞进本次归档（每个 1GB）。
# 这与 docs/jenkins_ci.md「坑 6」是同一个病。所以每次**先删后放**。
#
# 用法：
#   stage_apk.sh        （无参数；靠环境变量定位）
#
# 环境变量（Pipeline 提供）：
#   TS_RUN_DIR  本次证据目录（里面必须有 apk.path）
#   WORKSPACE   Jenkins 工作区（产物摆到 $WORKSPACE/artifacts/）
#   JOB_NAME / BUILD_NUMBER / JENKINS_URL  仅用于打印可点击的下载地址
#
# 退出码：0 已就位；1 找不到 APK / 拷贝或校验失败；2 用法错误
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PY="${PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
RUN_DIR="${TS_RUN_DIR:-$ROOT/.jenkins/run/$(date +%Y%m%d-%H%M%S)}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    *) echo "stage_apk: 未知参数 ${1}（本脚本不接受参数）" >&2; exit 2 ;;
  esac
done

report() {
  "$PY" "$ROOT/.jenkins/lib/stage_report.py" add --run "$RUN_DIR" \
    --name "$1" --group "交付" --status "$2" --detail "${3:-}" || true
}

# ---- 取本次 APK --------------------------------------------------------------
PATHFILE="$RUN_DIR/apk.path"
if [[ ! -f "$PATHFILE" ]]; then
  report "APK 归为构建产物" fail "缺少 apk.path（构建环节没跑或没产出 APK）"
  echo "🔴 找不到 ${PATHFILE} —— 构建环节没有登记产物" >&2
  exit 1
fi
APK_REL="$(tr -d '\r\n' < "$PATHFILE")"
[[ -n "$APK_REL" ]] || { report "APK 归为构建产物" fail "apk.path 是空的"; exit 1; }

# apk.path 里是**相对工程根**的路径（find_artifact.py 就是这么写的）
case "$APK_REL" in
  /*) APK="$APK_REL" ;;
  *)  APK="$ROOT/$APK_REL" ;;
esac

if [[ ! -f "$APK" ]]; then
  report "APK 归为构建产物" fail "apk.path 指向的文件不存在：${APK_REL}"
  echo "🔴 路径存在但文件不在：${APK}" >&2
  exit 1
fi

SRC_SIZE="$(stat -f%z "$APK")"
if [[ "${SRC_SIZE:-0}" -le 0 ]]; then
  report "APK 归为构建产物" fail "APK 是 0 字节：${APK_REL}"
  echo "🔴 APK 大小为 0，不可能是个能装的包" >&2
  exit 1
fi

NAME="$(basename "$APK")"

# ---- 摆进 workspace/artifacts/（先删后放，理由见文件头）-----------------------
if [[ -z "${WORKSPACE:-}" ]]; then
  report "APK 归为构建产物" fail "WORKSPACE 未设置，无法归档"
  echo "🔴 WORKSPACE 未设置 —— archiveArtifacts 只认 workspace 里的相对路径" >&2
  exit 1
fi

DEST_DIR="$WORKSPACE/artifacts"
rm -rf "$DEST_DIR" 2>/dev/null || true
mkdir -p "$DEST_DIR" || { report "APK 归为构建产物" fail "建不了 ${DEST_DIR}"; exit 1; }

DEST="$DEST_DIR/$NAME"
MODE="cp"
# ① APFS 克隆（瞬间、不增盘）；② 硬链接（同一卷、不增盘）；③ 真复制（兜底）
if cp -c "$APK" "$DEST" 2>/dev/null; then
  MODE="clone"
elif ln "$APK" "$DEST" 2>/dev/null; then
  MODE="hardlink"
else
  rm -f "$DEST"
  if cp -p "$APK" "$DEST" 2>/dev/null; then
    MODE="copy"
  else
    report "APK 归为构建产物" fail "拷贝失败：${NAME}"
    echo "🔴 没能把 APK 放进工作区（三种方式都失败）" >&2
    exit 1
  fi
fi

# 摆错文件比摆不上更危险（会把旧包当新包发出去），所以比一次大小
DST_SIZE="$(stat -f%z "$DEST" 2>/dev/null || echo 0)"
if [[ "$DST_SIZE" != "$SRC_SIZE" ]]; then
  report "APK 归为构建产物" fail "大小不一致 src=${SRC_SIZE} dst=${DST_SIZE}"
  echo "🔴 工作区里的 APK 与源文件大小不一致，拒绝归档" >&2
  exit 1
fi

MD5="$(md5 -q "$DEST" 2>/dev/null || echo '?')"
SIZE_H="$(du -h "$APK" | cut -f1)"

# ---- 稳定下载地址（可反复用、不随构建号变化）---------------------------------
# 为什么不用 userContent 软链：实测 Jenkins 不对外提供软链接 ——
# 把 `userContent/xxx.apk -> /…/apks/…/xxx.apk` 放进去后请求是 **404**（2026-10-17 实测）。
# 改用 Jenkins **原生 permalink** `lastSuccessfulBuild`：它天然就是「永远指向最后一次
# 成功构建」的稳定地址，不用复制文件、不怕构建号变化，且随 buildDiscarder 一起过期
# （不会留下指向已删构建的死链）。
BASE="${JENKINS_URL:-http://localhost:8080}"
# JENKINS_URL 常常自带尾斜杠，直接拼会出 `host//job/…` —— 能访问但打出来难看，
# 也会让人怀疑是不是地址拼错了。统一去掉尾斜杠再拼。
while [[ "$BASE" == */ ]]; do BASE="${BASE%/}"; done
JOBU="$BASE/job/${JOB_NAME:-TS-Android-TestPackage}"
BUILD_URL="$JOBU/${BUILD_NUMBER:-0}"
ART_URL="$BUILD_URL/artifact/artifacts/$NAME"
STABLE_DIR_URL="$JOBU/lastSuccessfulBuild/artifact/artifacts/"

{
  echo "APK_NAME=$NAME"
  echo "APK_PATH=$APK"
  echo "APK_SIZE=$SRC_SIZE"
  echo "APK_SIZE_H=$SIZE_H"
  echo "APK_MD5=$MD5"
  echo "APK_STAGE_MODE=$MODE"
  echo "APK_ARTIFACT_URL=$ART_URL"
  echo "APK_STABLE_URL=$STABLE_DIR_URL"
  echo ""
  echo "本次下载（浏览器点开即下）：$ART_URL"
  echo "稳定地址（永远指向最近一次成功的包）：$STABLE_DIR_URL"
  echo "装机（USB 连着）：adb install -r \"$APK\""
  echo "🔴 手机若已装 Play 版，必须先卸载 —— 本包用 upload key 签名，与 Play 的 app signing key 不同。"
} > "$RUN_DIR/apk.artifact.txt"

cat "$RUN_DIR/apk.artifact.txt"
echo "$NAME" > "$RUN_DIR/apk.name"
echo "$ART_URL" > "$RUN_DIR/apk.url"

report "APK 归为构建产物" pass "${NAME} · ${SIZE_H} · ${MODE} · md5 ${MD5:0:8}"
exit 0
