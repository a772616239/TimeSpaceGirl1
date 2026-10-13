#!/usr/local/bin/bash
# =============================================================================
# build_apk.sh —— 走 Unity batchmode 出测试用 APK（universal），并登记环节结论
#
# 为什么不直接调 Unity 而要这一层
# ------------------------------
# 直接在 Pipeline 里调 `Unity -batchmode …` 会丢掉三件对 CI 很重要的事：
#   1. **Unity 的日志不进环节结论** —— batchmode 全程只往 `-logFile` 写，stdout 几乎是空的，
#      所以环节结论若只看 stdout 就只剩一句无用的「rc=0」。这里从 Unity 日志里摘出
#      `Build SUCCESS / FAILED / Exception / error CS` 作为结论。
#   2. **`unity` 锁** —— 同一 Unity 工程不能有第二个 batchmode 实例（工程锁会打架），
#      必须与 AAB 构建、与任何人手工起的 Unity 串行。
#   3. **产物必须是本次的** —— 配 `.jenkins/lib/find_artifact.py --after <开始时间>`，
#      构建失败时绝不回退到上一次的旧包（否则校验环节会去校一个旧包并且全绿）。
#
# 用法：build_apk.sh [--no-bump] [--who 说明]
# 退出码：0 出包成功；其余 = Unity 的退出码（CLIBuilder 失败时是 1）
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
PROJ="${PROJ:-$ROOT}"
PY="${PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
BASH_BIN="${BASH:-/usr/local/bin/bash}"
UNITY="${UNITY:-/Applications/Unity/Hub/Editor/2022.3.62f2c1/Unity.app/Contents/MacOS/Unity}"
RUN_DIR="${TS_RUN_DIR:-$ROOT/.jenkins/run/$(date +%Y%m%d-%H%M%S)}"

DO_BUMP=1
WHO="$(hostname -s)/$$"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-bump) DO_BUMP=0; shift ;;
    --who)     WHO="$2"; shift 2 ;;
    *) echo "build_apk: 未知参数 $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$RUN_DIR/logs"
cd "$PROJ" || exit 2

# ---- 提版本号（可选）--------------------------------------------------------
if [[ $DO_BUMP -eq 1 && -f scripts/bump_version.py ]]; then
  before="$("$PY" scripts/bump_version.py --show 2>&1 | tr '\n' ' ')"
  "$PY" scripts/bump_version.py --bump >/dev/null 2>&1 || true
  after="$("$PY" scripts/bump_version.py --show 2>&1 | tr '\n' ' ')"
  printf 'bump 前：%s\nbump 后：%s\n' "$before" "$after" | tee "$RUN_DIR/version.txt"
fi

START=$(date +%s)
LOG="$RUN_DIR/logs/unity-apk.log"

# 🔴 口径说明：CLIBuilder 里 `kProfile` 硬编码为 MinimalGmOff（只关 GM，其余与线上逐位一致）。
#    这里不提供口径开关 —— 命令行产物必须与线上口径一致，出别的口径应当是显式改代码的决定，
#    不该是一个手滑就能点出来的下拉框。
echo "→ Unity batchmode 出 APK（CLIBuilder.BuildAndroidAPK / 口径 MinimalGmOff）"
echo "   🔒 需要 unity 锁（与 AAB 构建、手工 Unity 串行）"

"$BASH_BIN" "$HERE/lock.sh" --name unity run --who "$WHO" --timeout 1800 -- \
  "$UNITY" -projectpath "$PROJ" -batchmode -nographics \
  -executeMethod CLIBuilder.BuildAndroidAPK \
  -logFile "$LOG" -quit
RC=$?

DUR=$(( $(date +%s) - START ))

# ---- 从 Unity 日志里摘结论 --------------------------------------------------
KEY="$(grep -aE 'Build SUCCESS|Build FAILED|Aborted|Exception|error CS|CLIBuilder BuildAndroid' "$LOG" 2>/dev/null \
       | tail -1 | cut -c1-190 || true)"
[[ -n "$KEY" ]] || KEY="（Unity 日志无关键行，见 ${LOG}）"

if [[ $RC -eq 0 && "$KEY" != *"Build SUCCESS"* ]]; then
  # Unity 退出码 0 但日志里没有 SUCCESS：可能是被 -quit 提前截断，标成「关注」而不是通过
  echo "⚠️ Unity 退出码为 0，但日志里没找到 'Build SUCCESS' —— 标为关注"
  STATUS="warn"
elif [[ $RC -eq 0 ]]; then
  STATUS="pass"
else
  STATUS="fail"
fi

"$PY" "$ROOT/.jenkins/lib/stage_report.py" add --run "$RUN_DIR" \
  --name "Unity 构建 APK" --group "构建" --status "$STATUS" \
  --detail "$KEY" --duration "$DUR" --log "$LOG" || true

if [[ $RC -ne 0 ]]; then
  echo "🔴 APK 构建失败（rc=${RC}）。Unity 日志尾部："
  tail -25 "$LOG" 2>/dev/null
  exit "$RC"
fi

# ---- 定位本次产物 -----------------------------------------------------------
if ! "$PY" "$HERE/find_artifact.py" 'apks/*/CLIBuild/*.apk' \
      --root "$PROJ" --after "$START" --out "$RUN_DIR/apk.path" >/dev/null; then
  "$PY" "$ROOT/.jenkins/lib/stage_report.py" add --run "$RUN_DIR" \
    --name "定位本次 APK 产物" --group "构建" --status fail \
    --detail "构建声称成功，但没有找到本次新产出的 .apk" || true
  echo "🔴 没有找到本次产出的 APK"
  exit 1
fi

APK="$(cat "$RUN_DIR/apk.path")"
echo "✅ 本次产物：$APK"
ls -la "$APK" "$APK.release.json" 2>/dev/null || true
"$PY" "$ROOT/.jenkins/lib/stage_report.py" add --run "$RUN_DIR" \
  --name "定位本次 APK 产物" --group "构建" --status pass \
  --detail "$(basename "$APK") · $(stat -f%z "$APK") B" || true
exit 0
