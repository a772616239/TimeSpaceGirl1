#!/usr/bin/env bash
# =============================================================================
# aab_release.sh —— 一键：提版本号 → Unity 打 AAB → 校验 → 上传 Google Play
#
# 用法：
#   scripts/aab_release.sh                          # 默认：只打包 + 校验，**不上传**
#   scripts/aab_release.sh --dry-run                # 打包 + 只认证列现状（只读）
#   scripts/aab_release.sh --skip-build             # 复用最近一个 AAB，跳过 Unity 打包
#   scripts/aab_release.sh --no-bump                # 不动 versionCode（仅调试用！）
#
# 🔴 上传是显式动作，且**默认目标轨道是 internal（内部测试），不是 production**
#    （2026-10-13 用户要求「不要直接传正式环境，传内部测试的管线」）：
#     --upload      才会上传；不加则只在本地出包
#     --internal    默认。传 Google Play 内部测试轨道，测试员几分钟内可装
#     --production  才允许写 production 轨道（= 正式版）；不带则一律拒绝
#     --publish     才允许**非 internal 轨道**用 status=completed/inProgress（= 送审 + 上线）
#   发布状态按轨道推导：internal ⇒ completed（内部测试不面向公众，免 --publish）；
#   其余轨道 ⇒ draft（不送审，需人工在 Console 发布）。四个旗标只由人显式敲出，
#   脚本之间不互相传递。
#
#   例：scripts/aab_release.sh --upload                             # 传 internal（默认，立即可测）
#       scripts/aab_release.sh --upload --production --status draft  # 传 production 草稿
#       scripts/aab_release.sh --upload --production --publish       # 正式发布（需先获批准！）
#
# 前置检查里有一道 AssetBundle 闸门：若 StreamingAssets 里找不到任何 Lua bundle
# 会直接中止（因为这样打出的 AAB 真机起不来）。确认要发不含 Lua 的包时加
# --allow-no-lua 强制继续。
#
# 说明：
#   - 默认会先把 AndroidBundleVersionCode +1、bundleVersion 末位 +1（CLI 打包本身
#     不自增，详见 scripts/bump_version.py 头部注释）。产物名形如
#     apks/{日期}/CLIBuild/1.2.50_vc69_175432.aab —— 文件名直接带 versionCode。
#   - 🔴 Play 的**所有轨道共享同一个 versionCode 空间**：一个号上传过一次就永久占用，
#     换个轨道重传同一个号同样会被拒。所以无论传 internal 还是 production，
#     versionCode 都必须递增。
#   - 密钥默认读 ~/.gplay/service-account.json，可用 --key 覆盖。
#     申请与授权步骤见 docs/google_play_upload_setup.md
# =============================================================================
set -euo pipefail

PROJECT_ROOT="/Users/wangxufeng/Documents/TimeSpaceGirl1"
UNITY_BIN="/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity"
VENV_PY="/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python"
BUILD_LOG="${PROJECT_ROOT}/build_log_aab_main.txt"
PACKAGE_NAME="com.Warera.timespace"

TRACK="internal"        # 🔴 默认 internal（内部测试轨道）；production 需 --production 显式抬旗
STATUS=""               # 🔴 空 = 按轨道推导，见下方「默认发布状态」
STATUS_FOR_INTERNAL="completed"  # internal：传完测试员即可装（内部测试不面向公众 ⇒ 免 --publish）
STATUS_FOR_OTHER="draft"         # 其余轨道：只存草稿（不送审）；送审另需 --publish
USER_FRACTION=""
NOTES=""
KEY=""
DO_BUMP=1
SKIP_BUILD=0
DO_UPLOAD=0             # 🔴 默认不上传（2026-10-12 起）；上传需显式 --upload
ALLOW_PROD=0            # production 写入放行（--production）
ALLOW_PUBLISH=0         # 送审/上线放行（--publish）
DRY_RUN=0
ASSUME_YES=0
ALLOW_NO_LUA=0

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
        # 🔴 轨道 / 闸门旗标：必须由人显式敲出来，脚本之间不互相传递
        --upload)         DO_UPLOAD=1; shift ;;
        --internal)       TRACK="internal"; shift ;;      # 内部测试轨道（默认）
        --production)     ALLOW_PROD=1; TRACK="production"; shift ;;
        --publish)        ALLOW_PUBLISH=1; shift ;;
        --no-upload)      DO_UPLOAD=0; shift ;;   # 保留兼容；现已是默认
        --dry-run)        DRY_RUN=1; shift ;;
        --allow-no-lua)   ALLOW_NO_LUA=1; shift ;;
        --yes|-y)         ASSUME_YES=1; shift ;;
        # 用法段 = 从第 3 行到下一个 `# ===…` 分隔线之前（不要再写死行号）
        -h|--help)        awk 'NR>=3 && /^# =====/{exit} NR>=3{print}' "$0"; exit 0 ;;
        *) echo "未知参数：${1}（用 --help 查看用法）" >&2; exit 2 ;;
    esac
done

step()  { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()    { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
fail()  { printf '\033[1;31m  ✗ %s\033[0m\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------- #
# 默认发布状态（按轨道推导，仅在未显式给 --status 时生效）
#
#   internal  ⇒ completed：内部测试轨道不面向公众、免常规审核、可随时 halt/替换；
#              而草稿在 internal 上等于「没传」（测试员根本看不到）⇒ 默认直接可测。
#   其余轨道  ⇒ draft：production 的 completed = 送审 + 上线，必须由人另抬 --publish。
# --------------------------------------------------------------------------- #
if [[ -z "$STATUS" ]]; then
    if [[ "$TRACK" == "internal" ]]; then
        STATUS="$STATUS_FOR_INTERNAL"
    else
        STATUS="$STATUS_FOR_OTHER"
    fi
fi

# --------------------------------------------------------------------------- #
# 🔴 发布闸门自检（fail fast，把拒绝理由直接讲清楚）
#
# 背景：2026-10-12 用户明确要求「不要帮我送审，我要自己看一下」。此前默认值就是
# completed（= 直接送审 + 上线），任何一次漏传参数都会造成误送审。
# 2026-10-13 再收紧一层：默认轨道从 production 改成 **internal（内部测试管线）**，
# 正式版必须显式抬 --production。
# ⇒ 默认拒绝：要上传加 --upload，要写 production 加 --production，
#   要送审/上线（completed / inProgress）加 --publish —— 但 internal 豁免
#   --publish（它天生就是给内部测试员装的，不面向公众）。
# --------------------------------------------------------------------------- #
if [[ "$DRY_RUN" -eq 0 && "$DO_UPLOAD" -eq 1 ]]; then
    if [[ "$TRACK" == "production" && "$ALLOW_PROD" -eq 0 ]]; then
        fail "拒绝写 production 轨道：默认只传 internal，要发正式版请显式加 --production
    （只想看现状请用 --dry-run）。"
    fi
    if [[ "$TRACK" != "internal" ]] \
       && [[ "$STATUS" == "completed" || "$STATUS" == "inProgress" ]] \
       && [[ "$ALLOW_PUBLISH" -eq 0 ]]; then
        fail "拒绝把包置为 status=${STATUS}（= 提交审核 / 上线）：请显式加 --publish。
    只想上传成草稿请用 --status draft。"
    fi
fi

cd "$PROJECT_ROOT"

# --------------------------------------------------------------------------- #
# 0. 前置检查
# --------------------------------------------------------------------------- #
step "前置检查"

[[ -x "$UNITY_BIN" ]] || fail "Unity 编辑器不存在：$UNITY_BIN"
# 版本号从路径反推（.../Hub/Editor/<version>/Unity.app/...），别再写死 —— 写死的那次
# 升到 6000.6.5f1 后这句一直骗人地打印旧版本。
UNITY_VER=$(printf '%s' "$UNITY_BIN" | sed -nE 's|.*/Hub/Editor/([^/]+)/.*|\1|p')
ok "Unity 编辑器就位 (${UNITY_VER:-未知版本} @ $UNITY_BIN)"

[[ -f "${PROJECT_ROOT}/Assets/Editor/CLIBuilder.cs" ]] || fail "缺少 Assets/Editor/CLIBuilder.cs"
ok "CLIBuilder.cs 就位"

# ⚠️ 必须限定到**本工程**：本机常年有其它项目（如 ~/Documents/main_android/Unity）在跑
# Unity batchmode，旧版无条件 pgrep 会把它误判成「本工程被 GUI Unity 占用」而中止发版。
# 只认命令行里带 `-projectpath <本工程>` 的 Unity 进程。
UNITY_LIST=$(pgrep -fl "Unity.app/Contents/MacOS/Unity" 2>/dev/null || true)
if printf '%s\n' "$UNITY_LIST" | grep -qF -- "-projectpath ${PROJECT_ROOT}"; then
    fail "检测到 Unity 编辑器正在运行（且锁定了本工程），会导致 batchmode 失败。
     请先关闭 GUI Unity：osascript -e 'tell application \"Unity\" to quit'
     命中进程：
$(printf '%s\n' "$UNITY_LIST" | grep -F -- "-projectpath ${PROJECT_ROOT}")"
fi
if [[ -n "$UNITY_LIST" ]]; then
    ok "无本工程 Unity 占用（其它项目 ${UNITY_LIST%%$'\n'*}… 的 Unity 已忽略）"
else
    ok "无 Unity 编辑器占用工程"
fi

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
# 0.5 AssetBundle 就绪检查
#
# 背景（2026-10-11 实测踩到）：AssetBundle 构建产物与 StreamingAssets 是两套东西，
# 而且链路是「BuildABs/Android/ → CopyAssetBundleToStreamingAssets() → StreamingAssets/Android」。
# 只要 AB 构建或拷贝任一步没跑，AAB 就会带着陈旧/缺失的 bundle 发出去，而且
# 构建过程不会有任何报错。最典型的是 Lua。
#
# Lua bundle 的**真实命名**（2026-10-12 从 CRC 清单与代码取证确认）：
#   Assets/ManagedResources/LuaBytes.meta → assetBundleName: lzma/luabytes
#                                           assetBundleVariant: unity3d
#   落盘 BuildABs/Android/lzma/luabytes.unity3d
#   进 CombinePack 后按 name.Replace("/","|") 变成 lzma|luabytes.unity3d
#   （见 AssetBundleBuilder.BuildSelectAssetBundles:348）
# ⇒ 它**不带 lua 前缀、也不在 lua/ 子目录**，所以旧的「按 lua| 段匹配」规则是错的。
# 判定改为：存在文件名含 luabytes 的 bundle。
# --------------------------------------------------------------------------- #
AB_TOTAL=$(ls "${PROJECT_ROOT}/Assets/StreamingAssets/Android/"*.unity3d 2>/dev/null | wc -l | tr -d ' ')
if [[ "${AB_TOTAL:-0}" -eq 0 ]]; then
    fail "Assets/StreamingAssets/Android 下没有任何 .unity3d bundle。
     AssetBundle 尚未构建或拷贝，无法出包。见 docs/ 中 AB 构建链路说明。"
fi
ok "StreamingAssets bundle 数：${AB_TOTAL}"

# Lua bundle 检测：真实名字是 lzma|luabytes.unity3d（见上方说明）。
# 用 contains "luabytes" 而非段匹配 —— 该名字里既没有 lua| 段也不在 lua/ 目录，
# 而「乱(luan)」这类贴图名不会命中 luabytes，故不会误报。
LUA_HITS=$(ls "${PROJECT_ROOT}/Assets/StreamingAssets/Android/" 2>/dev/null | grep -c "luabytes" || true)
LUA_DIR_FILES=$(find "${PROJECT_ROOT}/Assets/StreamingAssets/lua" -type f ! -name "*.meta" 2>/dev/null | wc -l | tr -d ' ')
if [[ "${LUA_HITS:-0}" -eq 0 ]]; then
    warn "🔴 未发现 Lua bundle（期望 lzma|luabytes.unity3d）！"
    warn "   检查项1：StreamingAssets/Android 下文件名含 luabytes 的 bundle = ${LUA_HITS:-0} 个"
    warn "   检查项2：StreamingAssets/lua/ 下非 meta 文件 = ${LUA_DIR_FILES:-0} 个"
    warn "   检查项3：LuaBytes.meta 的 assetBundleName、BuildConfigs.asset 登记（可运行"
    warn "           scripts/check_ab_ready.sh 一键体检）"
    warn "   ⇒ 这样打出的 AAB 不含 Lua 字节码，真机会起不来（AssetBundleLoader 会报"
    warn "      \"StreamingAssets 路径资源丢失，请重新打包包内资源!\"）。"
    warn "   ⇒ 先在 GUI Unity（BuildWindow「整体打包资源」）依次跑："
    warn "      FrameTool.BuildGameAssetBundles() → CopyAssetBundleToStreamingAssets()"
    warn "      （若只改了 Lua，用「单打lua资源」BuildLuaAssetBundles()）"
    if [[ "$ALLOW_NO_LUA" -eq 0 ]]; then
        fail "已中止。若你确认本次就是要发不含 Lua 的包，请加 --allow-no-lua 强制继续。"
    else
        warn "已按 --allow-no-lua 强制继续（风险自负）。"
    fi
else
    ok "Lua bundle 就绪（luabytes bundle ${LUA_HITS:-0} 个）"
fi

# AB 陈旧度：bundle 比资源配置表还旧 ⇒ bundle 与配置可能不同步
CFG_MTIME=$(stat -f%m "${PROJECT_ROOT}/Assets/ManagedResources/ResConfigs/ResourcePathConfig.asset" 2>/dev/null || echo 0)
# ⚠️ 必须带 `|| true`：set -o pipefail 下 `ls -t ... | head -1` 会让 head 提前退出、
# ls 收到 SIGPIPE 返回 141，pipefail 将其视为失败，set -e 随即中止整个脚本。
# bundle 数越多越容易触发（实测 2112 个时侥幸通过，2740 个时必现）。
NEWEST_AB=$(ls -t "${PROJECT_ROOT}/Assets/StreamingAssets/Android/"*.unity3d 2>/dev/null | head -1 || true)
if [[ -n "$NEWEST_AB" ]]; then
    AB_MTIME=$(stat -f%m "$NEWEST_AB" 2>/dev/null || echo 0)
    if [[ "${CFG_MTIME:-0}" -gt "${AB_MTIME:-0}" ]]; then
        warn "bundle 比 ResourcePathConfig.asset 旧（$(date -r "${AB_MTIME}" '+%Y-%m-%d %H:%M') < $(date -r "${CFG_MTIME}" '+%Y-%m-%d %H:%M')）"
        warn "   ⇒ 资源配置已更新但 AB 未重建，bundle 与配置可能不同步。"
    else
        ok "bundle 时间不早于资源配置表"
    fi
fi

# --------------------------------------------------------------------------- #
# 1. 提升 versionCode
# --------------------------------------------------------------------------- #
if [[ "$SKIP_BUILD" -eq 1 ]]; then
    step "跳过打包（--skip-build）"
else
    if [[ "$DO_BUMP" -eq 1 ]]; then
        step "提升 versionCode / versionName"
        # 🔴 两个一起提：Play 轨道只认 versionCode 递增，但 versionName 会长期重复，
        # 导致「1.2.45」这种名字在 Play Console 上对应好几个包，核对告警属于哪一版时
        # 只能靠 versionCode。让 name 与 code 同步前进，人眼才能对上。
        # （历史缺陷：2026-10-12 那次发版只提了 code、没提 name，见 REF-android-release.md）
        "$VENV_PY" scripts/bump_version.py --bump --bump-name
        ok "versionCode / versionName 已自增"
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
# 4.5 包内「出包开关」自检（离线解包核验，不是看构建日志）
#
# 背景（2026-10-12）：CLIBuilder 过去没有「出包配置」这一步，命令行产的包一律沿用
# 开发态设置 ⇒ isOpenGM=1，GM 面板随包发布。已从线上 v64 产物取证确认。
# 修复后命令行会走 ReleaseBuildSettings.PrepareSceneForBuild（开场景→套配置→落盘）。
# 这里对**产出物本身**复核，防止「改完代码但没生效」这类静默失败。
# 口径由 CLIBuilder 的 kProfile 决定，默认 MinimalGmOff（只关 GM，其余位与线上逐位一致）。
# --------------------------------------------------------------------------- #
step "包内出包开关自检（期望口径 minimal = 只关 GM）"
if ! "$VENV_PY" scripts/verify_aab_release_config.py "$AAB" --expect minimal; then
    fail "包内配置不是期望口径（isOpenGM 仍为 1？）—— 拒绝上传。构建日志：$BUILD_LOG"
fi
ok "包内 isOpenGM=0，出包配置核验通过"

# --------------------------------------------------------------------------- #
# 4.6 包内 native 库 16KB / NDK 体检
#
# 背景（2026-10-12）：回退 Google Sign-In 时带回了 google-signin-support:1.0.4 里的
# libnative-googlesignin.so —— 它是 NDK r17 编的，被 Play 报「某些库使用旧版 Android NDK」。
# 该库 p_align=0x10000 本来满足硬门槛，所以旧检查（只看对齐）拦不住 ⇒ 增设本步。
# 已用 NDK r28c 重编该库（scripts/ 外的复现脚本见记忆），此处只做**产物侧**复核。
# --------------------------------------------------------------------------- #
step "包内 native 库 16KB / NDK 体检"
if ! "$VENV_PY" scripts/verify_aab_native_16kb.py "$AAB"; then
    fail "包内存在未达 16KB 对齐的 64 位 native 库（Play 硬门槛不过）—— 拒绝上传"
fi
ok "16KB 硬门槛通过（上面 ⚠️ 列表为 Play 软告警候选，需人工确认）"

# --------------------------------------------------------------------------- #
# 5. 上传
# --------------------------------------------------------------------------- #
if [[ "$DO_UPLOAD" -eq 0 ]]; then
    step "跳过上传（默认行为；要上传请显式加 --upload）"
    ok "产物就绪：$AAB"
    ok "下一步（传内部测试轨道 internal，默认）：scripts/aab_release.sh --skip-build --upload --yes"
    ok "（只有要发正式版才需要抬旗：… --skip-build --upload --production --status draft --yes）"
    exit 0
fi

step "上传 Google Play（track=${TRACK}, status=${STATUS}）"
UPLOAD_ARGS=(--aab "$AAB" --package "$PACKAGE_NAME" --track "$TRACK" --status "$STATUS")
[[ -n "$USER_FRACTION" ]] && UPLOAD_ARGS+=(--user-fraction "$USER_FRACTION")
[[ -n "$NOTES" ]]         && UPLOAD_ARGS+=(--release-notes "$NOTES")
[[ -n "$KEY" ]]           && UPLOAD_ARGS+=(--service-account "$KEY")
[[ "$DRY_RUN" -eq 1 ]]    && UPLOAD_ARGS+=(--dry-run)
[[ "$ASSUME_YES" -eq 1 ]] && UPLOAD_ARGS+=(--yes)
# 闸门旗标一路透传给 play_upload.py（它自己也会再拒一次，双保险）
[[ "$ALLOW_PROD" -eq 1 ]]    && UPLOAD_ARGS+=(--allow-production-write)
[[ "$ALLOW_PUBLISH" -eq 1 ]] && UPLOAD_ARGS+=(--allow-publish)

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
if [[ "$TRACK" == "internal" ]]; then
    ok "已发布到轨道：internal（内部测试，免常规审核，测试员几分钟内即可安装）"
elif [[ "$STATUS" == "draft" ]]; then
    ok "已上传到轨道：${TRACK}（草稿，**未送审**，可在 Play Console 自行检查后手动发布）"
else
    ok "已提交到轨道：${TRACK}（${STATUS}）"
fi
