#!/usr/bin/env bash
# =============================================================================
# check_ab_ready.sh —— AssetBundle 就绪体检（**只读，不改任何文件**）
#
# 用途：打包前/AB 重建后快速判断「包内资源链路」是否完整，重点看 Lua。
#
# 背景（2026-10-11/12 取证）：
#   AssetBundle 链路是三段式的，任一段没跑，Unity 打包**不会报错**，
#   只会静默把陈旧或缺资源打进包：
#
#     BuildABs/Android/                                   ← AB 构建产物
#        ↑ FrameTool.BuildGameAssetBundles()   （GUI:「整体打包资源」）
#        ↓ FrameTool.CopyAssetBundleToStreamingAssets() （GUI:「复制资源到流媒体目录」）
#     Assets/StreamingAssets/Android/                     ← AAB 包内资源的唯一来源
#        ↑ FrameTool.BuildLuaAssetBundles()    （GUI:「单打lua资源」，只重建 Lua）
#
#   Lua bundle 的真实名字是 **lzma|luabytes.unity3d**（不在 lua/ 目录、不带 lua 前缀）：
#     Assets/ManagedResources/LuaBytes.meta → assetBundleName: lzma/luabytes
#     ⇒ BuildABs/Android/lzma/luabytes.unity3d
#     ⇒ CombinePack 里按 name.Replace("/","|") 变 lzma|luabytes.unity3d
#
# 用法：scripts/check_ab_ready.sh
# 退出码：0 全部就绪 / 1 有阻塞项 / 2 环境错误
# =============================================================================
set -euo pipefail

PROJECT_ROOT="/Users/wangxufeng/Documents/TimeSpaceGirl1"
cd "${PROJECT_ROOT}"

FAIL=0
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
bad()  { printf '\033[1;31m  ✗ %s\033[0m\n' "$*"; FAIL=1; }
mt()   { stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$1" 2>/dev/null || echo "?"; }

# --------------------------------------------------------------------------- #
step "1. LuaBytes 源侧（决定能否产出 luabytes bundle）"
# --------------------------------------------------------------------------- #
META="Assets/ManagedResources/LuaBytes.meta"
if [[ -f "${META}" ]]; then
    BUNDLE_NAME=$(grep -a "assetBundleName" "${META}" | head -1 | awk '{print $2}')
    VARIANT=$(grep -a "assetBundleVariant" "${META}" | head -1 | awk '{print $2}')
    if [[ "${BUNDLE_NAME}" == "lzma/luabytes" && "${VARIANT}" == "unity3d" ]]; then
        ok "LuaBytes.meta 标记正确：${BUNDLE_NAME} / ${VARIANT}"
    else
        bad "LuaBytes.meta 标记异常：name='${BUNDLE_NAME:-空}' variant='${VARIANT:-空}'（应为 lzma/luabytes / unity3d）"
    fi
else
    bad "缺少 ${META}（LuaBytes 目录丢失 → 不可能产出 Lua bundle）"
fi

LUA_SRC=$(find Assets/ManagedResources/LuaBytes -type f ! -name "*.meta" 2>/dev/null | wc -l | tr -d ' ')
if [[ "${LUA_SRC:-0}" -gt 0 ]]; then
    ok "LuaBytes 源文件：${LUA_SRC} 个（目录 mtime $(mt Assets/ManagedResources/LuaBytes)）"
else
    bad "LuaBytes 目录内没有任何 .bytes 源文件（空目录打不出 bundle）"
fi

BC="Assets/ManagedResources/EditorConfigs/BuildConfigs.asset"
if [[ -f "${BC}" ]] && grep -aq "83cf30c5b8fffbb4486da15ecdbd3d40" "${BC}"; then
    ok "BuildConfigs.asset 已登记 LuaBytes（GUID 83cf30c5…，OneFloderOneBundle）"
else
    bad "BuildConfigs.asset 未登记 LuaBytes（MarkGame 不会标记它）"
fi

# --------------------------------------------------------------------------- #
step "2. BuildABs 构建产物（AB 构建是否跑过）"
# --------------------------------------------------------------------------- #
for d in BuildABs/Android BuildABs/Android/lzma BuildABs/Android/lz4 BuildABs/Android/CombinePack; do
    if [[ -d "${d}" ]]; then
        n=$(ls "${d}" 2>/dev/null | wc -l | tr -d ' ')
        ok "${d}：${n} 项（mtime $(mt "${d}")）"
    else
        bad "${d} 不存在（AB 构建未跑或已被清理）"
    fi
done

if [[ -f BuildABs/Android/lzma/luabytes.unity3d ]]; then
    ok "BuildABs 内有 lzma/luabytes.unity3d（$(du -h BuildABs/Android/lzma/luabytes.unity3d | cut -f1)）"
else
    bad "BuildABs 内缺 lzma/luabytes.unity3d（AB 构建没有产出 Lua bundle）"
fi
if [[ -f "BuildABs/Android/CombinePack/lzma|luabytes.unity3d" ]]; then
    ok "CombinePack 内有 lzma|luabytes.unity3d"
else
    bad "CombinePack 内缺 lzma|luabytes.unity3d（这一步缺失 → 拷进 StreamingAssets 也不会有）"
fi

# --------------------------------------------------------------------------- #
step "3. StreamingAssets（AAB 包内资源的唯一来源）"
# --------------------------------------------------------------------------- #
SA="Assets/StreamingAssets/Android"
AB_TOTAL=$(ls "${SA}/"*.unity3d 2>/dev/null | wc -l | tr -d ' ')
if [[ "${AB_TOTAL:-0}" -gt 0 ]]; then
    ok "bundle 总数：${AB_TOTAL}（目录 mtime $(mt "${SA}")）"
else
    bad "${SA} 下没有任何 .unity3d（AAB 会是空壳）"
fi

LUA_HITS=$(ls "${SA}/" 2>/dev/null | grep -c "luabytes" || true)
if [[ "${LUA_HITS:-0}" -gt 0 ]]; then
    ok "Lua bundle 就位（$(ls "${SA}/" | grep "luabytes" | tr '\n' ' ')）"
else
    bad "缺 lzma|luabytes.unity3d ⇒ 打出的 AAB 不含 Lua，真机起不来"
fi

for f in files.unity3d "lzma|resconfigs.unity3d"; do
    if [[ -f "${SA}/${f}" ]]; then
        ok "${f} 就位（$(du -h "${SA}/${f}" | cut -f1)，$(mt "${SA}/${f}")）"
    else
        bad "${SA}/${f} 缺失"
    fi
done

# 陈旧度：StreamingAssets 的最新 bundle 比 CombinePack 的旧 ⇒ 构建过但没拷贝
# 注意用**最新 bundle 文件**的 mtime，而不是目录 mtime —— 目录 mtime 会被
# 无关的 touch/新建文件刷新（实测 StreamingAssets 目录 mtime 比内部 bundle 新 2 个月）
if [[ -d BuildABs/Android/CombinePack && -d "${SA}" ]]; then
    CP_NEW=$(ls -t BuildABs/Android/CombinePack/*.unity3d 2>/dev/null | head -1 || true)
    SA_NEW=$(ls -t "${SA}/"*.unity3d 2>/dev/null | head -1 || true)
    if [[ -n "${CP_NEW}" && -n "${SA_NEW}" ]]; then
        CP_MT=$(stat -f%m "${CP_NEW}" 2>/dev/null || echo 0)
        SA_MT=$(stat -f%m "${SA_NEW}" 2>/dev/null || echo 0)
        if [[ "${CP_MT}" -gt "${SA_MT}" ]]; then
            warn "StreamingAssets 里的 bundle 比 BuildABs/CombinePack 旧："
            warn "  CombinePack 最新 bundle：$(mt "${CP_NEW}")"
            warn "  StreamingAssets 最新 bundle：$(mt "${SA_NEW}")"
            warn "  ⇒ 构建过 AB 但没执行「复制资源到流媒体目录」，包内用的是旧 bundle"
        else
            ok "StreamingAssets 不比 CombinePack 旧（$(mt "${SA_NEW}")）"
        fi
    fi
fi

# --------------------------------------------------------------------------- #
step "4. 最近一次 AAB（若存在，看它到底带没带 Lua）"
# --------------------------------------------------------------------------- #
LATEST_AAB=$(find apks -name "*.aab" -type f -print0 2>/dev/null | xargs -0 ls -t 2>/dev/null | head -1 || true)
if [[ -n "${LATEST_AAB}" ]]; then
    ok "最新 AAB：${LATEST_AAB}（$(du -h "${LATEST_AAB}" | cut -f1)，$(mt "${LATEST_AAB}")）"
    PY="/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python"
    if [[ -x "${PY}" ]]; then
        "${PY}" - "${LATEST_AAB}" <<'PY'
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
hits = [n for n in z.namelist() if "luabytes" in n.lower()]
if hits:
    for n in hits:
        print(f"\033[1;32m  \u2713 AAB \u5185\u542b {n}\033[0m")
else:
    print("\033[1;31m  \u2717 AAB \u5185\u4e0d\u542b\u4efb\u4f55 luabytes bundle\uff08\u65e7\u5305\uff09\033[0m")
PY
    fi
else
    warn "apks/ 下没有 AAB"
fi

# --------------------------------------------------------------------------- #
printf '\n'
if [[ "${FAIL}" -eq 0 ]]; then
    printf '\033[1;32m==> 全部就绪，可以跑 scripts/aab_release.sh 打包上传\033[0m\n'
    exit 0
else
    printf '\033[1;31m==> 存在阻塞项（见上方 ✗）。请在 GUI Unity 的 BuildWindow 里重建 AB\033[0m\n'
    printf '    「整体打包资源」→「复制资源到流媒体目录」（只改过 Lua 则用「单打lua资源」）\n'
    exit 1
fi
