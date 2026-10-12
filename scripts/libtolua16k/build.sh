#!/usr/bin/env bash
# =============================================================================
# build.sh —— 重编译 libtolua.so（16KB 页对齐版）并校验
#
# 为什么需要这个脚本
# ------------------
# `Assets/Plugins/Android/libs/arm64-v8a/libtolua.so` 是 ToLua# 运行时，把
# LuaJIT + tolua + cjson + lpeg + pb(protobuf) + luasocket + struct + bit
# 全部打包进一个 .so。仓库里只有编译产物、没有源码。
#
# Google Play 自 2025-11 起要求新包支持 16KB 页大小，Play 的「旧版 NDK」告警
# 按【已知问题库清单】点名，libtolua.so 在列。原库由 NDK r17 era 工具链编译，
# 且 LuaJIT 的 lj_arch.h 默认 LJ_PAGESIZE=4096 —— JIT 的 mcode 分配器按该值
# 对齐后调 mprotect，在 16KB 页设备上会被内核拒绝，属于会真崩的隐患。
#
# 上游：https://github.com/alex4814/tolua_runtime
# 补丁：同目录 apply-16k.patch（改动仅 2 个文件、共 3 行 + 注释）
#
# 用法
# ----
#   scripts/libtolua16k/build.sh                 # 克隆 → 打补丁 → 编译 → 校验
#   scripts/libtolua16k/build.sh --install       # 校验通过后替换进工程
#   scripts/libtolua16k/build.sh --src <dir>     # 用已有的 tolua_runtime 检出
#
# 环境变量
# --------
#   ANDROID_NDK_HOME  必需，NDK r28+（首个默认处理 16KB 的 NDK）
#   TOLUA_RT_COMMIT   可选，覆盖上游 commit（默认见下方 PINNED_COMMIT）
#
# 退出码：0 成功 / 1 失败（任一校验不通过即中止，不会覆盖工程内库）
# =============================================================================
set -euo pipefail

# --------------------------------------------------------------------------- #
# 常量
# --------------------------------------------------------------------------- #
PINNED_COMMIT="${TOLUA_RT_COMMIT:-71eec6d24f416f943948c5c6d2a04d598a348563}"
REPO_URL="https://github.com/alex4814/tolua_runtime"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PATCH_FILE="${SCRIPT_DIR}/apply-16k.patch"

TARGET_SO="${PROJECT_ROOT}/Assets/Plugins/Android/libs/arm64-v8a/libtolua.so"
WORK_SRC="/tmp/tolua_rt_build"
NDK_ABI="arm64-v8a"
# 与 ProjectSettings.asset 的 AndroidMinSdkVersion(24) 保持一致。
# 注意：NDK r28 起 libc 桩按 API 聚合，21 也能链过，但显式对齐 minSdk 更诚实。
NDK_API_LEVEL="24"

DO_INSTALL=0
SRC_DIR=""

# --------------------------------------------------------------------------- #
# 参数
# --------------------------------------------------------------------------- #
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) DO_INSTALL=1; shift ;;
        --src)     SRC_DIR="$2"; shift 2 ;;
        -h|--help) sed -n '2,32p' "$0"; exit 0 ;;
        *) echo "未知参数：$1" >&2; exit 2 ;;
    esac
done

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*"; }
fail() { printf '\033[1;31m  ✗ %s\033[0m\n' "$*" >&2; exit 1; }

# --------------------------------------------------------------------------- #
# 0. 前置检查
# --------------------------------------------------------------------------- #
step "前置检查"

[[ -n "${ANDROID_NDK_HOME:-}" ]] || fail "未设置 ANDROID_NDK_HOME（需要 NDK r28+）"
[[ -d "${ANDROID_NDK_HOME}" ]]   || fail "ANDROID_NDK_HOME 指向的目录不存在：${ANDROID_NDK_HOME}"

NDK_SOURCE_PROPS="${ANDROID_NDK_HOME}/source.properties"
[[ -f "${NDK_SOURCE_PROPS}" ]] || fail "找不到 ${NDK_SOURCE_PROPS}，无法确认 NDK 版本"
NDK_VER="$(grep -E '^Pkg\.Revision' "${NDK_SOURCE_PROPS}" | head -1 | awk -F'= *' '{print $2}')"
NDK_MAJOR="${NDK_VER%%.*}"
[[ "${NDK_MAJOR}" =~ ^[0-9]+$ ]] || fail "无法解析 NDK 版本：${NDK_VER}"
if [[ "${NDK_MAJOR}" -lt 28 ]]; then
    fail "NDK r${NDK_MAJOR} 过低。16KB 支持需要 r28+（当前 ${NDK_VER}）"
fi
ok "NDK r${NDK_MAJOR}（${NDK_VER}）"

command -v cmake >/dev/null 2>&1 || fail "缺少 cmake"
command -v ninja >/dev/null 2>&1 || fail "缺少 ninja（可 pip install ninja）"
ok "cmake / ninja 就位"

[[ -f "${PATCH_FILE}" ]] || fail "缺少补丁文件：${PATCH_FILE}"
[[ -f "${SCRIPT_DIR}/verify.py" ]] || fail "缺少校验脚本：${SCRIPT_DIR}/verify.py"

TOOLCHAIN_BIN="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/darwin-x86_64/bin"
[[ -x "${TOOLCHAIN_BIN}/llvm-strip" ]] || fail "缺少 ${TOOLCHAIN_BIN}/llvm-strip"
ok "LLVM 工具链就位"

# 优先用工程既有 venv 的 python，回落系统 python3
PYTHON_BIN="${PYTHON:-}"
if [[ -z "${PYTHON_BIN}" ]]; then
    _venv_py="${HOME}/.workbuddy/binaries/python/envs/default/bin/python"
    if [[ -x "${_venv_py}" ]]; then PYTHON_BIN="${_venv_py}"; else PYTHON_BIN="python3"; fi
fi
command -v "${PYTHON_BIN}" >/dev/null 2>&1 || fail "找不到 python：${PYTHON_BIN}"
ok "python: ${PYTHON_BIN}"

# --------------------------------------------------------------------------- #
# 1. 准备源码
# --------------------------------------------------------------------------- #
if [[ -n "${SRC_DIR}" ]]; then
    step "使用已有源码：${SRC_DIR}"
    [[ -d "${SRC_DIR}" ]] || fail "目录不存在：${SRC_DIR}"
else
    step "准备上游源码（${REPO_URL}）"
    if [[ -d "${WORK_SRC}/.git" ]]; then
        ok "复用已有检出：${WORK_SRC}"
    else
        rm -rf "${WORK_SRC}"
        # --depth 1 只取主仓尖端；子模块仍需单独初始化
        git clone --depth 1 "${REPO_URL}" "${WORK_SRC}"
        ok "已克隆"
    fi
    SRC_DIR="${WORK_SRC}"
fi

cd "${SRC_DIR}"

if [[ -d ".git" ]]; then
    git -c advice.detachedHead=false fetch --depth 1 origin "${PINNED_COMMIT}" 2>/dev/null || true
    if git cat-file -e "${PINNED_COMMIT}" 2>/dev/null; then
        git -c advice.detachedHead=false checkout -q "${PINNED_COMMIT}"
        ok "已切到 pin 住的 commit ${PINNED_COMMIT:0:9}"
    else
        warn "取不到 pin 住的 commit，沿用当前 HEAD：$(git rev-parse --short HEAD 2>/dev/null || echo '?')"
    fi
fi

# 子模块是必需的：luajit-2.1 / cjson / lpeg / luasocket
if [[ ! -f "luajit-2.1/src/lj_arch.h" ]]; then
    step "初始化子模块"
    git submodule update --init --recursive --depth 1
fi
[[ -f "luajit-2.1/src/lj_arch.h" ]] || fail "子模块不完整：缺 luajit-2.1/src/lj_arch.h"
ok "子模块就位"

# --------------------------------------------------------------------------- #
# 2. 打补丁（幂等）
# --------------------------------------------------------------------------- #
step "应用 16KB 补丁"
if grep -q 'LJ_PAGESIZE=16384' cmake/luajit2.cmake 2>/dev/null; then
    ok "补丁已在（LJ_PAGESIZE=16384）"
else
    git apply --check "${PATCH_FILE}" 2>/dev/null \
        || fail "补丁无法干净应用（源码可能已变）。请人工核对 ${PATCH_FILE}"
    git apply "${PATCH_FILE}"
    ok "已应用 ${PATCH_FILE##*/}"
fi

# 三重确认：三条关键改动都在
grep -q 'LJ_PAGESIZE=16384'            cmake/luajit2.cmake || fail "LJ_PAGESIZE 注入缺失"
grep -q 'luasocket/src/mime.c'          CMakeLists.txt      || fail "mime.c 缺失"
grep -q '\${PROTOBUF_SRC}'              CMakeLists.txt      || fail "pb.c (PROTOBUF_SRC) 缺失"
ok "三条关键改动全部确认"

# --------------------------------------------------------------------------- #
# 3. 编译
# --------------------------------------------------------------------------- #
step "CMake 配置 + 编译（${NDK_ABI}, API ${NDK_API_LEVEL}）"
BUILD_DIR="./Build/android/${NDK_ABI}"
INSTALL_DIR="./Plugins/Android/${NDK_ABI}"

cmake \
    -B "${BUILD_DIR}" \
    -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK_HOME}/build/cmake/android.toolchain.cmake" \
    -DCMAKE_BUILD_TYPE=Release \
    -DANDROID_ABI="${NDK_ABI}" \
    -DANDROID_PLATFORM="${NDK_API_LEVEL}" \
    >/dev/null

cmake --build "${BUILD_DIR}" --config Release

mkdir -p "${INSTALL_DIR}"
cp -f "${BUILD_DIR}/libtolua.so" "${INSTALL_DIR}/libtolua.so"
NEW_SO="${INSTALL_DIR}/libtolua.so"
ok "编译产出：$(basename "${NEW_SO}") $(stat -f%z "${NEW_SO}") 字节"

# --------------------------------------------------------------------------- #
# 4. 校验
# --------------------------------------------------------------------------- #
step "校验"
"${PYTHON_BIN}" "${SCRIPT_DIR}/verify.py" "${NEW_SO}" "${TARGET_SO}" \
    || fail "校验未通过，工程内库未被改动"

# --------------------------------------------------------------------------- #
# 5. strip + 安装（可选）
# --------------------------------------------------------------------------- #
step "剥离调试符号"
"${TOOLCHAIN_BIN}/llvm-strip" --strip-unneeded "${NEW_SO}"
ok "strip 后 $(stat -f%z "${NEW_SO}") 字节"

if [[ "${DO_INSTALL}" -eq 1 ]]; then
    # 再加一道：strip 后重新验门槛1（strip 理论上不改 p_align，但不赌）
    "${PYTHON_BIN}" "${SCRIPT_DIR}/verify.py" "${NEW_SO}" "${TARGET_SO}" >/dev/null \
        || fail "strip 后校验失败，未安装"
    BK="$HOME/ts-tolua-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${BK}"
    if [[ -f "${TARGET_SO}" ]]; then
        cp -p "${TARGET_SO}" "${BK}/libtolua.old.so"
        ok "旧库已备份：${BK}/libtolua.old.so"
    fi
    cp -f "${NEW_SO}" "${TARGET_SO}"
    ok "已安装到 ${TARGET_SO}"
    printf '\n  下一步：重建 AAB 并校验，例如\n'
    printf '    scripts/aab_release.sh --no-upload --no-bump\n'
    printf '  🔴 上传与提交审核必须经用户确认，脚本不会自动做。\n'
else
    printf '\n  产物：%s\n' "${NEW_SO}"
    printf '  加 --install 可替换进工程（会先备份旧库）\n'
fi

step "完成"
