#!/usr/local/bin/bash
# =============================================================================
# android_env.sh —— Android 打包环境预检（**只读**）
#
# 回答：「这台机器现在能不能出一个正式的 Android 包」。
# 把「打包跑到一半才发现 Unity 不在 / 模板被 GUI 重置了 / keystore 没了」提前到 3 秒内暴露。
#
# 用法：.jenkins/lib/checks/android_env.sh
# 退出码：0 全部就绪；
#         1 有阻塞项（缺工具/模板被重置/缺 keystore —— **真问题**）；
#         2 环境错误（工程目录找不到）；
#         3 环境本身就绪，但本工程正被 Unity 编辑器占用（**临时状态**，不是缺陷）。
#   为什么要分出 3：总览 job 只该为此标黄（人开着编辑器是常态），
#   而打包 job 什么都不加 ⇒ rc=3 直接当硬阻塞（此时打包必失败，早点报早省事）。
# =============================================================================
set -uo pipefail

PROJ="${PROJ:-/Users/wangxufeng/Documents/TimeSpaceGirl1}"
UNITY="${UNITY:-/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity}"
PY="${PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"

# ── 工具链定位（Unity 6 起必须优先看 Unity.app 自带的那套）────────────────────
# Unity 6 默认使用「内嵌 SDK / JDK / NDK」——EditorPrefs 里
#   SdkUseEmbedded=1 / JdkUseEmbedded=1 / NdkUseEmbedded=1
# 所以真正参与打包的是 Unity.app 自带的工具链，而不是用户自装的
# ~/Library/Android/sdk。后者版本常常落后：本机实测只有 build-tools 35.0.1、
# platforms android-34/35，而本工程 targetSdk=36（CLIBuilder.PrepareAndroid）
# 需要 build-tools 36.0.0 + platforms/android-36 —— 内嵌 SDK 恰好两者都有。
# 旧版检查写死"用户 SDK/36.0.0"，在 Unity 6 下必然误报阻塞。
# 反推 Unity 安装根：…/<ver>/Unity.app/Contents/MacOS/Unity -> …/<ver>
UNITY_ROOT="$(cd "$(dirname "$UNITY")/../../.." 2>/dev/null && pwd || true)"
APLAYER="${UNITY_ROOT:+$UNITY_ROOT/PlaybackEngines/AndroidPlayer}"

# 在候选根目录下取版本号最高的子目录（sort -V），并探活其中的 $2
pick_dir() {
  [[ -n "$1" && -d "$1" ]] || return 1
  local v
  v="$(ls -1 "$1" 2>/dev/null | sort -V | tail -1 || true)"
  [[ -n "$v" && -e "$1/$v/$2" ]] || return 1
  printf '%s' "$1/$v"
}

# 显式传入且可用则尊重之；否则「内嵌 SDK → 用户 SDK」依次回落
if [[ -z "${BT:-}" || ! -e "${BT}/aapt2" ]]; then
  BT="$(pick_dir "${APLAYER:+$APLAYER/SDK/build-tools}" aapt2 || true)"
  [[ -n "$BT" ]] || BT="$(pick_dir "$HOME/Library/Android/sdk/build-tools" aapt2 || true)"
fi
BT="${BT:-$HOME/Library/Android/sdk/build-tools/36.0.0}"
BT_KIND="用户 SDK"
case "$BT" in "${APLAYER:-__none__}"/*) BT_KIND="Unity 内嵌 SDK" ;; esac

# JDK 同理：优先 Unity 内嵌（Unity 6 自带 Temurin 17），回落系统 java
JDK="${JDK:-${APLAYER:+$APLAYER/OpenJDK/bin/java}}"
[[ -n "$JDK" && -x "$JDK" ]] || JDK="$(command -v java || true)"
JDK_VER="$([[ -x "$JDK" ]] && "$JDK" -version 2>&1 | head -1 || echo '未找到')"

# targetSdk=36 ⇒ 需要同一套 SDK 里的 android-36 platform
SDK_PLATFORMS="${APLAYER:+$APLAYER/SDK/platforms}"

[[ -d "$PROJ" ]] || { echo "找不到工程目录：$PROJ" >&2; exit 2; }
cd "$PROJ" || exit 2

FAIL=0
SOFT=0
pass() { printf '   ✓ %s\n' "$1"; }
bad()  { printf '   ✗ %s\n' "$1"; FAIL=1; }
soft() { printf '   ⚠ %s\n' "$1"; SOFT=1; }
chk()  { if eval "$2" >/dev/null 2>&1; then pass "$1  ${3:-}"; else bad "$1  ${3:-}"; fi; }

echo "── 工具链 ─────────────────────────────────────────"
chk "Unity 可执行"        "[ -x \"$UNITY\" ]"              "$UNITY"
chk "python venv"        "[ -x \"$PY\" ]"                 "$PY"
chk "aapt2"              "[ -x \"$BT/aapt2\" ]"           "$BT  [$BT_KIND]"
chk "apksigner"          "[ -x \"$BT/apksigner\" ]"
chk "jdk (打包+签名)"      "[ -x \"$JDK\" ]"               "$JDK_VER"
chk "platform android-36" "[ -d \"${SDK_PLATFORMS:-/nonexistent}/android-36\" ]" \
                          "${SDK_PLATFORMS:-<无>}（targetSdk=36 需要）"

echo "── 出包配置真源 ───────────────────────────────────"
chk "ReleaseBuildSettings.cs" "[ -f Assets/Editor/ReleaseBuildSettings.cs ]"
chk "CLIBuilder.cs"           "[ -f Assets/Editor/CLIBuilder.cs ]"
check_profiles() {
  grep -q "MinimalGmOff" Assets/Editor/ReleaseBuildSettings.cs &&
  grep -q "Dev"          Assets/Editor/ReleaseBuildSettings.cs &&
  grep -q "FullTemplate" Assets/Editor/ReleaseBuildSettings.cs
}
chk "三口径齐备(Dev/MinimalGmOff/FullTemplate)" "check_profiles"

echo "── Gradle 模板（GUI 打开工程会重置，必查）──────────"
chk "launcherTemplate.gradle"   "[ -f Assets/Plugins/Android/launcherTemplate.gradle ]"
chk "mainTemplate.gradle"       "[ -f Assets/Plugins/Android/mainTemplate.gradle ]"
chk "gradleTemplate.properties" "[ -f Assets/Plugins/Android/gradleTemplate.properties ]"
check_nodeps() { ! grep -q '\*\*DEPS\*\*' Assets/Plugins/Android/launcherTemplate.gradle; }
chk "launcherTemplate 无未展开 **DEPS**" "check_nodeps"
check_androidx() { grep -q 'androidx.core' Assets/Plugins/Android/mainTemplate.gradle; }
chk "mainTemplate 含 AndroidX 降级 force" "check_androidx"

echo "── 签名 ───────────────────────────────────────────"
if [[ -f beauty.keystore ]]; then
  pass "beauty.keystore  $(stat -f%z beauty.keystore) B"
else
  bad "beauty.keystore 缺失（打出的包无法签名）"
fi

echo "── Unity 工程占用（只认本工程，不误伤别的项目）──────"
UNITY_BUSY="$(pgrep -fl "Unity.app/Contents/MacOS/Unity" 2>/dev/null | grep -F -- "-projectpath $PROJ" || true)"
if [[ -z "$UNITY_BUSY" ]]; then
  pass "本工程无 Unity 实例占用"
else
  soft "本工程已有 Unity 在跑（并发打包会污染产物）"
  echo "$UNITY_BUSY" | sed 's/^/       /'
fi

echo "── 当前版本号 ─────────────────────────────────────"
if [[ -f scripts/bump_version.py ]]; then
  "$PY" scripts/bump_version.py --show 2>&1 | sed 's/^/   /'
else
  bad "scripts/bump_version.py 不存在"
fi

echo
if [[ $FAIL -eq 0 && $SOFT -eq 0 ]]; then
  echo "✅ 打包环境就绪"
  exit 0
elif [[ $FAIL -eq 0 ]]; then
  echo "⚠️  打包环境本身就绪，但本工程被 Unity 占用 ⇒ 打包类环节现在做不了（关掉编辑器即可）"
  exit 3
else
  echo "🔴 打包环境有阻塞项（见上方 ✗）"
  exit 1
fi
