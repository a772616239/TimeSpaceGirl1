#!/usr/bin/env bash
# =============================================================================
# aab_release.sh —— 一键：提版本号 → Unity 打 AAB → 校验 → 上传 Google Play
#
# 用法：
#   scripts/aab_release.sh                          # 全流程，目标 production 全量
#   scripts/aab_release.sh --track internal         # 传内部测试轨道
#   scripts/aab_release.sh --dry-run                # 打包 + 只认证列现状，不上传
#   scripts/aab_release.sh --skip-build             # 复用最近一个 AAB，跳过 Unity 打包
#   scripts/aab_release.sh --no-upload              # 只打包 + 校验
#   scripts/aab_release.sh --no-bump                # 不动 versionCode（仅调试用！）
#
# 说明：
#   - 默认会先把 AndroidBundleVersionCode +1（CLI 打包本身不自增，详见
#     scripts/bump_version.py 头部注释），再打包。
#   - production 轨道要求 versionCode 严格递增，否则提交必被 Play 拒绝。
#   - 密钥默认读 ~/.gplay/service-account.json，可用 --key 覆盖。
#     申请与授权步骤见 docs/google_play_upload_setup.md
# =============================================================================
set -euo pipefail

PROJECT_ROOT="/Users/wangxufeng/Documents/TimeSpaceGirl1"
UNITY_BIN="/Applications/Unity/Hub/Editor/2022.3.62f2c1/Unity.app/Contents/MacOS/Unity"
VENV_PY="/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python"
BUILD_LOG="${PROJECT_ROOT}/build_log_aab_main.txt"
PACKAGE_NAME="com.Warera.timespace"

TRACK="production"
STATUS="completed"
USER_FRACTION=""
NOTES=""
KEY=""
DO_BUMP=1
SKIP_BUILD=0
DO_UPLOAD=1
DRY_RUN=0
ASSUME_YES=0

# --------------------------------------------------------------------------- #
# 参数解析
# --------------------------------------------------------------------------- #
while [[ $# -gt 0 ]]; do
    case "$1" in
        --track)          TRACK="$2"; shift 2 ;;
        --status)         STATUS="$2"; shift 2 ;;
        --user-fraction)  USER_FRACTION="$2"; shift 2 ;;
        --notes)          NOTES="$2"; shift 2 ;;
        --key)            KEY="$2"; shift 2 ;;
        --package)        PACKAGE_NAME="$2"; shift 2 ;;
        --aab)            EXPLICIT_AAB="$2"; SKIP_BUILD=1; shift 2 ;;
        --no-bump)        DO_BUMP=0; shift ;;
        --skip-build)     SKIP_BUILD=1; shift ;;
        --no-upload)      DO_UPLOAD=0; shift ;;
        --dry-run)        DRY_RUN=1; shift ;;
        --yes|-y)         ASSUME_YES=1; shift ;;
        -h|--help)        sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "未知参数：$1（用 --help 查看用法）" >&2; exit 2 ;;
    esac
done

step()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
fail()  { printf '\033[1;31m  ✗ %s\033[0m\n' "$*" >&2; exit 1; }

cd "$PROJECT_ROOT"

# --------------------------------------------------------------------------- #
# 0. 前置检查
# --------------------------------------------------------------------------- #
step "前置检查"

[[ -x "$UNITY_BIN" ]] || fail "Unity 编辑器不存在：$UNITY_BIN"
ok "Unity 编辑器就位 (2022.3.62f2c1)"

[[ -f "${PROJECT_ROOT}/Assets/Editor/CLIBuilder.cs" ]] || fail "缺少 Assets/Editor/CLIBuilder.cs"
ok "CLIBuilder.cs 就位"

if pgrep -f "Unity.app/Contents/MacOS/Unity" >/dev/null 2>&1; then
    fail "检测到 Unity 编辑器正在运行，会锁定工程导致 batchmode 失败。
     请先关闭 GUI Unity：osascript -e 'tell application \"Unity\" to quit'"
fi
ok "无 Unity 编辑器占用工程"

# GUI Unity 可能重置这些模板，打包前必须确认
for f in mainTemplate.gradle launcherTemplate.gradle gradleTemplate.properties; do
    p="${PROJECT_ROOT}/Assets/Plugins/Android/${f}"
    [[ -f "$p" ]] || fail "缺少 Assets/Plugins/Android/${f}（GUI Unity 可能重置了它，见 docs/unity_android_build_skill.md 第 4 节）"
done
grep -q "androidx.core:core:1.10.1" "${PROJECT_ROOT}/Assets/Plugins/Android/mainTemplate.gradle" \
    || warn "mainTemplate.gradle 未发现 AndroidX 降级 force 代码，billing 9.x 可能触发 mergeExtDexRelease 失败"
grep -q "androidx.core:core:1.10.1" "${PROJECT_ROOT}/Assets/Plugins/Android/launcherTemplate.gradle" \
    || warn "launcherTemplate.gradle 未发现 AndroidX 降级 force 代码（launcher 模块会失败）"
if grep -q '\*\*DEPS\*\*' "${PROJECT_ROOT}/Assets/Plugins/Android/launcherTemplate.gradle"; then
    fail "launcherTemplate.gradle 含 **DEPS** 占位符，会导致子项目引用找不到，请移除"
fi
grep -q "useAndroidX=true" "${PROJECT_ROOT}/Assets/Plugins/Android/gradleTemplate.properties" \
    || warn "gradleTemplate.properties 缺少 android.useAndroidX=true"
ok "Gradle 模板检查通过"

PURCHASING=$(grep -o '"com.unity.purchasing": *"[^"]*"' Packages/manifest.json | head -1 || true)
ok "IAP 包版本：${PURCHASING:-未找到}"

# --------------------------------------------------------------------------- #
# 1. 提升 versionCode
# --------------------------------------------------------------------------- #
if [[ "$SKIP_BUILD" -eq 1 ]]; then
    step "跳过打包（--skip-build）"
else
    if [[ "$DO_BUMP" -eq 1 ]]; then
        step "提升 versionCode"
        "$VENV_PY" scripts/bump_version.py --bump
        ok "versionCode 已自增"
    else
        step "跳过 versionCode 自增（--no-bump）"
        warn "production 轨道要求 versionCode 严格递增，若与历史重复提交会被拒绝"
    fi

    # ----------------------------------------------------------------------- #
    # 2. Unity batchmode 打包
    # ----------------------------------------------------------------------- #
    step "Unity batchmode 打包 AAB（约 10-15 分钟）"
    rm -f "${PROJECT_ROOT}/Library/SourceAssetDB-lock" 2>/dev/null || true
    BUILD_T0=$(date +%s)
    if ! "$UNITY_BIN" \
        -projectpath "$PROJECT_ROOT" \
        -batchmode -nographics \
        -executeMethod CLIBuilder.BuildAndroidAAB \
        -logFile "$BUILD_LOG" \
        -quit
    then
        warn "Unity 返回非 0 退出码，检查日志尾部："
        tail -40 "$BUILD_LOG" >&2 || true
        fail "打包失败，完整日志：$BUILD_LOG"
    fi
    BUILD_T1=$(date +%s)
    ok "Unity 进程结束，耗时 $((BUILD_T1 - BUILD_T0)) 秒"

    if ! grep -q "✅ Build SUCCESS" "$BUILD_LOG"; then
        warn "日志中未找到成功标记，尾部内容："
        tail -40 "$BUILD_LOG" >&2 || true
        fail "打包未成功，完整日志：$BUILD_LOG"
    fi
    ok "日志确认 Build SUCCESS"
fi

# --------------------------------------------------------------------------- #
# 3. 定位产物
# --------------------------------------------------------------------------- #
step "定位 AAB 产物"
if [[ -n "${EXPLICIT_AAB:-}" ]]; then
    AAB="$EXPLICIT_AAB"
else
    # 注意：macOS 的 BSD find 不支持 -newermt（会报 "bad date"），必须用 -mmin
    AAB=$(find "${PROJECT_ROOT}/apks" -name "*.aab" -type f -mmin -360 -print0 2>/dev/null \
          | xargs -0 ls -t 2>/dev/null | head -1 || true)
    if [[ -z "$AAB" ]]; then
        AAB=$(find "${PROJECT_ROOT}/apks" -name "*.aab" -type f -print0 2>/dev/null \
              | xargs -0 ls -t 2>/dev/null | head -1 || true)
    fi
fi
[[ -n "$AAB" && -f "$AAB" ]] || fail "找不到 AAB 产物，检查 apks/ 目录"
AAB_SIZE_MB=$(( $(stat -f%z "$AAB") / 1024 / 1024 ))
ok "AAB: $AAB (${AAB_SIZE_MB} MB)"
[[ "$AAB_SIZE_MB" -gt 50 ]] || warn "AAB 体积偏小（${AAB_SIZE_MB} MB），确认构建是否完整（历史正常值约 420 MB）"

# --------------------------------------------------------------------------- #
# 4. 产物校验
# --------------------------------------------------------------------------- #
step "产物校验"
unzip -l "$AAB" | grep -qE "BundleConfig" && ok "BundleConfig.pb 存在" || warn "缺少 BundleConfig.pb"
unzip -l "$AAB" | grep -q "base/manifest" && ok "base/manifest 存在" || warn "缺少 base/manifest"
AGP=$(unzip -p "$AAB" BUNDLE-METADATA/com.android.tools.build.gradle/app-metadata.properties 2>/dev/null \
      | grep -i androidGradlePluginVersion || true)
[[ -n "$AGP" ]] && ok "$AGP" || warn "未读到 AGP 版本（bundle 元数据可能被裁剪）"
BILLING=$(ls ~/.gradle/caches/modules-2/files-2.1/com.android.billingclient/billing/ 2>/dev/null | tr '\n' ' ' || true)
ok "Gradle 缓存中的 billing 版本：${BILLING:-未找到}"
ANDROIDX=$(ls ~/.gradle/caches/modules-2/files-2.1/androidx.core/core/ 2>/dev/null | tr '\n' ' ' || true)
ok "Gradle 缓存中的 androidx.core：${ANDROIDX:-未找到}（期望同时有被拒的 1.15.0 与生效的 1.10.1）"

# 写 sidecar（供上传脚本直接读 versionCode），并回显版本信息
"$VENV_PY" - "$AAB" <<'PY'
import datetime, json, pathlib, re, sys
aab = pathlib.Path(sys.argv[1])
ps = pathlib.Path("ProjectSettings") / "ProjectSettings.asset"
t = ps.read_text(encoding="utf-8")
mc = re.search(r"AndroidBundleVersionCode:\s*(\d+)", t)
mn = re.search(r"bundleVersion:\s*(\S+)", t)
code = int(mc.group(1)) if mc else None
name = mn.group(1) if mn else None
meta = {
    "aab": str(aab),
    "versionCode": code,
    "versionName": name,
    "generatedAt": datetime.datetime.now().isoformat(timespec="seconds"),
}
pathlib.Path(str(aab) + ".json").write_text(
    json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
)
print(f"  versionName = {name}")
print(f"  versionCode = {code}")
print(f"  sidecar     = {aab}.json")
PY
ok "版本信息与 sidecar 就绪"

# --------------------------------------------------------------------------- #
# 5. 上传
# --------------------------------------------------------------------------- #
if [[ "$DO_UPLOAD" -eq 0 ]]; then
    step "跳过上传（--no-upload）"
    ok "产物就绪：$AAB"
    exit 0
fi

step "上传 Google Play（track=$TRACK, status=$STATUS）"
UPLOAD_ARGS=(--aab "$AAB" --package "$PACKAGE_NAME" --track "$TRACK" --status "$STATUS")
[[ -n "$USER_FRACTION" ]] && UPLOAD_ARGS+=(--user-fraction "$USER_FRACTION")
[[ -n "$NOTES" ]]         && UPLOAD_ARGS+=(--release-notes "$NOTES")
[[ -n "$KEY" ]]           && UPLOAD_ARGS+=(--service-account "$KEY")
[[ "$DRY_RUN" -eq 1 ]]    && UPLOAD_ARGS+=(--dry-run)
[[ "$ASSUME_YES" -eq 1 ]] && UPLOAD_ARGS+=(--yes)

set +e
"$VENV_PY" scripts/play_upload.py "${UPLOAD_ARGS[@]}"
RC=$?
set -e

if [[ "$RC" -ne 0 ]]; then
    case "$RC" in
        3) fail "认证失败：检查 service account 密钥与 Play Console 授权（见 docs/google_play_upload_setup.md）" ;;
        4) fail "Play API 业务错误：见上方 HTTP 错误详情" ;;
        5) fail "versionCode 校验失败：号没有提上去，检查 scripts/bump_version.py" ;;
        *) fail "上传失败，退出码 $RC" ;;
    esac
fi

step "全流程完成"
ok "AAB: $AAB"
ok "已发布到轨道：$TRACK（$STATUS）"
