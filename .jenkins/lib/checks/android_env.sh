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
UNITY="${UNITY:-/Applications/Unity/Hub/Editor/2022.3.62f2c1/Unity.app/Contents/MacOS/Unity}"
PY="${PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
BT="${BT:-$HOME/Library/Android/sdk/build-tools/36.0.0}"

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
chk "aapt2"              "[ -x \"$BT/aapt2\" ]"           "$BT"
chk "apksigner"          "[ -x \"$BT/apksigner\" ]"
chk "jdk (签名用)"        "command -v java"

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
