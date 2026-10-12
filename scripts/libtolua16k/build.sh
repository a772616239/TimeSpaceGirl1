#!/usr/bin/env bash
# =============================================================================
# build.sh —— 重编译 libtolua.so（16KB 页对齐版）并校验
#
# 为什么需要这个脚本
# ------------------
# `Assets/Plugins/Android/libs/arm64-v8a/libtolua.so` 是 ToLua# 运行时，把
# LuaJIT + tolua + cjson + lpeg + pb(protobuf) + luasocket + struct 打包成
# 一个 .so。仓库里只有编译产物、没有源码。
#
# 两个动因：
#   1. Google Play 自 2025-11 起要求新包支持 16KB 页大小，Play 的「旧版 NDK」
#      告警按【已知问题库清单】点名，libtolua.so 在列。
#   2. LuaJIT 的 lj_arch.h 默认 LJ_PAGESIZE=4096，而 JIT 的 mcode 分配器
#      （lj_mcode.c）按该值对齐后调 mprotect，在 16KB 页设备上页粒度不匹配
#      会被内核拒绝 —— 这是会真崩的隐患，不只是告警。
#
# 🔴 血泪教训（2026-10-12，真机实测踩到）
# 第一版修复误用了 alex4814/tolua_runtime（其 LuaJIT 是 2.1.ROLLING 2025-01）。
# 而真机跑的是由 LuaEncoder/luajit_mac/64/luajit 编译的**预编译字节码**
# （Assets/ManagedResources/LuaBytes/*.bytes），那个编码器是 LuaJIT **2.1.0-beta3**。
#
# 两个版本同属 2.1 线、BCDUMP_VERSION 都是 2，所以字节码头 (1b 4c 4a 02) 不会被
# 拒绝 —— 但 **opcode 表在 beta3 与 ROLLING 之间有增删**，加载后执行错指令／
# JIT 出错，表现为**启动即卡死、进不去登录界面**。
#
# ⇒ **运行时 LuaJIT 必须与字节码编码器严格同版本**。
#   本脚本固定 topameng/tolua_runtime（LuaJIT 2.1.0-beta3），并由 verify.py
#   强制双重校验：① 版本串一致 ② 导出符号对原始库零缺失。
#
# 取证：topameng/tolua_runtime 的预编译 Plugins/Android/libs/arm64-v8a/libtolua.so
#       与本工程原库 sha256 完全相同（176274e7…76a2f，667968 字节）
#       ⇒ 原库就是它出的，这是同源重建。
#
# 上游：https://github.com/topameng/tolua_runtime
# 补丁：apply-16k.patch（仅 1 个文件 1 行 + 注释：luajit-2.1/src/lj_arch.h 的 LJ_PAGESIZE）
#
# 用法
# ----
#   scripts/libtolua16k/build.sh                 # 克隆 → 打补丁 → 编译 → 校验
#   scripts/libtolua16k/build.sh --install       # 校验通过后替换进工程（先备份）
#   scripts/libtolua16k/build.sh --src <dir>     # 用已有的 tolua_runtime 检出
#
# 环境变量
# --------
#   ANDROID_NDK_HOME  必需，NDK r28+（首个默认处理 16KB 的 NDK）
#   TOLUA_RT_COMMIT   可选，覆盖上游 pin 住的 commit
#
# 退出码：0 成功 / 1 失败（任一校验不通过即中止，不会覆盖工程内库）
# =============================================================================
set -euo pipefail

# --------------------------------------------------------------------------- #
# 常量
# --------------------------------------------------------------------------- #
PINNED_COMMIT="${TOLUA_RT_COMMIT:-654e0da626328a6c4cf9824c4e50f31109ddae4e}"
REPO_URL="https://github.com/topameng/tolua_runtime"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PATCH_FILE="${SCRIPT_DIR}/apply-16k.patch"

TARGET_SO="${PROJECT_ROOT}/Assets/Plugins/Android/libs/arm64-v8a/libtolua.so"
WORK_SRC="/tmp/tolua_rt_beta3_build"
# 与 ProjectSettings.asset 的 AndroidMinSdkVersion(24) 保持一致
NDK_API_LEVEL="24"
NDK_ABI="arm64-v8a"

# LuaJIT 编成静态库时的目标宏（照抄 topameng 的 build_arm64.sh）
LUAJIT_TARGET_FLAGS="-DLJ_ABI_SOFTFP=0 -DLJ_ARCH_HASFPU=1 -DLUAJIT_ENABLE_GC64=1"

# 🔴 源文件清单：严格照抄上游 android/jni/Android.mk 的 LOCAL_SRC_FILES。
# 注意**不含** bit.c（LuaJIT 自带 lib_bit）、serial.c、unix.c、wsocket.c。
# 少编或多编都会改变导出符号集合，verify.py 会拦住。
TOLUA_SRCS=(
    tolua.c
    int64.c
    uint64.c
    pb.c
    lpeg.c
    struct.c
    cjson/strbuf.c
    cjson/lua_cjson.c
    cjson/fpconv.c
    luasocket/auxiliar.c
    luasocket/buffer.c
    luasocket/except.c
    luasocket/inet.c
    luasocket/io.c
    luasocket/luasocket.c
    luasocket/mime.c
    luasocket/options.c
    luasocket/select.c
    luasocket/tcp.c
    luasocket/timeout.c
    luasocket/udp.c
    luasocket/usocket.c
)

DO_INSTALL=0
SRC_DIR=""

# --------------------------------------------------------------------------- #
# 参数
# --------------------------------------------------------------------------- #
while [[ $# -gt 0 ]]; do
    case "$1" in
        --install) DO_INSTALL=1; shift ;;
        --src)     SRC_DIR="$2"; shift 2 ;;
        -h|--help) sed -n '2,46p' "$0"; exit 0 ;;
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

# host tag：优先 darwin-*，其次 linux-*
PREBUILT="${ANDROID_NDK_HOME}/toolchains/llvm/prebuilt"
if   [[ -d "${PREBUILT}/darwin-x86_64" ]]; then HOST_TAG="darwin-x86_64"
elif [[ -d "${PREBUILT}/darwin-arm64"  ]]; then HOST_TAG="darwin-arm64"
elif [[ -d "${PREBUILT}/linux-x86_64"  ]]; then HOST_TAG="linux-x86_64"
else
    # ⚠️ pipefail 下 `ls | head -1` 会让 ls 吃到 SIGPIPE(141)，必须 `|| true`
    HOST_TAG="$(ls "${PREBUILT}" 2>/dev/null | head -1 || true)"
fi
[[ -n "${HOST_TAG}" ]] || fail "无法确定 NDK host tag（${PREBUILT} 下无可用目录）"

TOOLCHAIN_BIN="${PREBUILT}/${HOST_TAG}/bin"
NDK_CC="${TOOLCHAIN_BIN}/aarch64-linux-android${NDK_API_LEVEL}-clang"
for t in "${NDK_CC}" "${TOOLCHAIN_BIN}/llvm-ar" "${TOOLCHAIN_BIN}/llvm-strip" "${TOOLCHAIN_BIN}/llvm-nm"; do
    [[ -x "${t}" ]] || fail "缺少工具链组件：${t}"
done
ok "LLVM 工具链就位（${HOST_TAG}）"

command -v git  >/dev/null 2>&1 || fail "缺少 git"
command -v make >/dev/null 2>&1 || fail "缺少 make（LuaJIT 用 GNU make 构建）"
command -v clang >/dev/null 2>&1 || fail "缺少本机 clang（用于构建 buildvm 宿主工具）"
ok "git / make / clang 就位"

[[ -f "${PATCH_FILE}" ]] || fail "缺少补丁文件：${PATCH_FILE}"
[[ -f "${SCRIPT_DIR}/verify.py" ]] || fail "缺少校验脚本：${SCRIPT_DIR}/verify.py"
[[ -f "${SCRIPT_DIR}/ref/original-symbols.txt" ]] || fail "缺少符号基准：ref/original-symbols.txt"

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

[[ -f "luajit-2.1/src/lj_arch.h" ]] || fail "源码不完整：缺 luajit-2.1/src/lj_arch.h"
ok "LuaJIT 源码就位"

# --------------------------------------------------------------------------- #
# 2. 打补丁（幂等）
# --------------------------------------------------------------------------- #
step "应用 16KB 补丁"
if grep -q 'LJ_PAGESIZE.*16384' luajit-2.1/src/lj_arch.h 2>/dev/null; then
    ok "补丁已在（LJ_PAGESIZE=16384）"
else
    git apply --check "${PATCH_FILE}" 2>/dev/null \
        || fail "补丁无法干净应用（源码可能已变）。请人工核对 ${PATCH_FILE}"
    git apply "${PATCH_FILE}"
    ok "已应用 ${PATCH_FILE##*/}"
fi
grep -q 'LJ_PAGESIZE.*16384' luajit-2.1/src/lj_arch.h || fail "LJ_PAGESIZE=16384 未生效"

# --------------------------------------------------------------------------- #
# 3. 编译 libluajit.a
#
# ⚠️ LuaJIT 的 Makefile 有个坑：STATIC_CC / TARGET_LD 都是 `$(CROSS)$(CC)`
#    拼接，而 AR/STRIP 是 `$(CROSS)ar`。若同时给 CROSS 和带路径的 CC，
#    会拼成 llvm-/path/to/clang 而报 "Command not found"。
#    ⇒ CROSS 留空、CC 给完整路径，并逐项覆盖 TARGET_LD / TARGET_AR / TARGET_STRIP。
#    另外 HOST_CC 默认继承 CC，必须显式设为**本机** clang，否则 buildvm 会用
#    Android clang 编、无法在本机执行。
# --------------------------------------------------------------------------- #
step "编译 libluajit.a（LuaJIT 2.1.0-beta3, ${NDK_ABI}, API ${NDK_API_LEVEL}）"
cd "${SRC_DIR}/luajit-2.1/src"
make clean >/dev/null 2>&1 || true
make \
    HOST_CC="clang -m64" \
    CC="${NDK_CC}" \
    TARGET_LD="${NDK_CC}" \
    TARGET_AR="${TOOLCHAIN_BIN}/llvm-ar rcus" \
    TARGET_STRIP="${TOOLCHAIN_BIN}/llvm-strip" \
    TARGET_SYS=Linux \
    TARGET_FLAGS="${LUAJIT_TARGET_FLAGS}" \
    >/dev/null
[[ -f libluajit.a ]] || fail "libluajit.a 未生成"
ok "libluajit.a $(stat -f%z libluajit.a) 字节"

# --------------------------------------------------------------------------- #
# 4. 链接 libtolua.so
# --------------------------------------------------------------------------- #
step "链接 libtolua.so"
cd "${SRC_DIR}"
OUT_DIR="${SRC_DIR}/build_out"
mkdir -p "${OUT_DIR}"

"${NDK_CC}" -shared -O2 -std=gnu99 -fPIC \
    -I luajit-2.1/src -I . \
    "${TOLUA_SRCS[@]}" \
    -Wl,--whole-archive luajit-2.1/src/libluajit.a -Wl,--no-whole-archive \
    -Wl,-z,max-page-size=16384 \
    -lm -ldl \
    -o "${OUT_DIR}/libtolua.so"

NEW_SO="${OUT_DIR}/libtolua.so"
[[ -f "${NEW_SO}" ]] || fail "libtolua.so 未生成"
ok "libtolua.so $(stat -f%z "${NEW_SO}") 字节（未 strip）"

# --------------------------------------------------------------------------- #
# 5. 校验（未 strip 时先验一次，早失败早停）
# --------------------------------------------------------------------------- #
step "校验"
"${PYTHON_BIN}" "${SCRIPT_DIR}/verify.py" "${NEW_SO}" \
    || fail "校验未通过，工程内库未被改动"

# --------------------------------------------------------------------------- #
# 6. strip
# --------------------------------------------------------------------------- #
step "剥离调试符号"
cp -f "${NEW_SO}" "${OUT_DIR}/libtolua.unstripped.so"
"${TOOLCHAIN_BIN}/llvm-strip" --strip-unneeded "${NEW_SO}"
ok "strip 后 $(stat -f%z "${NEW_SO}") 字节"

# strip 理论上不改 p_align / 不改动态符号表，但影响面太大不赌，重验一遍
"${PYTHON_BIN}" "${SCRIPT_DIR}/verify.py" "${NEW_SO}" >/dev/null \
    || fail "strip 后校验失败"
ok "strip 后复验通过"

# --------------------------------------------------------------------------- #
# 7. 安装（可选）
# --------------------------------------------------------------------------- #
if [[ "${DO_INSTALL}" -eq 1 ]]; then
    BK="$HOME/ts-tolua-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "${BK}"
    if [[ -f "${TARGET_SO}" ]]; then
        cp -p "${TARGET_SO}" "${BK}/libtolua.old.so"
        ok "旧库已备份：${BK}/libtolua.old.so"
    fi
    cp -f "${NEW_SO}" "${TARGET_SO}"
    ok "已安装到 ${TARGET_SO}"
    printf '\n  sha256 = %s\n' "$(shasum -a 256 "${TARGET_SO}" | awk '{print $1}')"
    printf '\n  下一步：重建 AAB 并校验，例如\n'
    printf '    scripts/aab_release.sh --no-upload --no-bump\n'
    printf '  🔴 上传与提交审核必须经用户确认，脚本不会自动做。\n'
else
    printf '\n  产物：%s\n' "${NEW_SO}"
    printf '  加 --install 可替换进工程（会先备份旧库）\n'
fi

step "完成"
