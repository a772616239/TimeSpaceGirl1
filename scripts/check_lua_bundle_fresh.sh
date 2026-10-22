#!/bin/bash
#
# 硬判据：LuaBytes 里的字节码是否已经打进 lzma|luabytes.unity3d
#
# 为什么必须有：旧的判据是「最新 bundle 的 mtime >= ResourcePathConfig.asset 的 mtime」，
# 但导表**根本不改** ResourcePathConfig.asset ⇒「字节码更新了、bundle 没重建」这种情况
# 静默放过（2026-10-20 实测：#7 包内还是旧配置，到包内环境校验才暴露）。
# 正确的判据是「bundle 不早于任何一个 LuaBytes/*_64.bytes」。
#
# ⚠️ 2026-10-23 补：mtime 判据在**复用 AB 缓存**（AB_MODE=复用缓存）下会误报 ——
#    ci_sync 的 git reset --hard 会把改动过的文件重新检出（内容不变、mtime 变新）。
#    所以 mtime 判「过期」时再问一次内容哈希（scripts/ab_cache.py fresh-check），
#    指纹对得上就放行。判「不过期」时行为不变。
#
# 退出码：0 一致 / 1 不一致（需要重建 AB） / 2 环境问题
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BYTES_DIR="$ROOT/Assets/ManagedResources/LuaBytes"
BUNDLE="$ROOT/Assets/StreamingAssets/Android/lzma|luabytes.unity3d"

[[ -d "$BYTES_DIR" ]] || { echo "✗ 找不到 LuaBytes 目录：$BYTES_DIR" >&2; exit 2; }
[[ -f "$BUNDLE" ]] || {
    echo "✗ 找不到 $BUNDLE" >&2
    echo "  ⇒ StreamingAssets 里没有 Lua bundle，先重建 AB（scripts/resource_build.sh --action ab）" >&2
    exit 1
}

NEWEST=""
NEWEST_TS=0
while IFS= read -r f; do
    ts=$(stat -f%m "$f" 2>/dev/null || echo 0)
    if [[ "${ts:-0}" -gt "$NEWEST_TS" ]]; then
        NEWEST_TS="$ts"
        NEWEST="$f"
    fi
done < <(find "$BYTES_DIR" -type f -name "*_64.bytes" 2>/dev/null)

BUNDLE_TS=$(stat -f%m "$BUNDLE" 2>/dev/null || echo 0)
BYTES_COUNT=$(find "$BYTES_DIR" -type f -name "*_64.bytes" 2>/dev/null | wc -l | tr -d ' ')

echo "字节码：${BYTES_COUNT} 个，最新 $(date -r "$NEWEST_TS" '+%Y-%m-%d %H:%M' 2>/dev/null || echo 未知)（${NEWEST##*/}）"
echo "bundle：$(date -r "$BUNDLE_TS" '+%Y-%m-%d %H:%M')（$(ls -lh "$BUNDLE" | awk '{print $5}')）"

if [[ "${NEWEST_TS:-0}" -gt "${BUNDLE_TS:-0}" ]]; then
    # 🔴 mtime 只是**代理指标**，会被 git reset 骗：ci_sync 每次把改动过的文件重新检出，
    #    内容一模一样但 mtime 变新 ⇒ 判「bundle 过期」。复用 AB 缓存（AB_MODE=复用缓存）
    #    时这条误报会天天出现，所以再问一次**内容哈希**（ab_cache.py 的指纹）：
    #    指纹里的 bundle sha256 == 现在这份，且当时的字节码哈希 == 现在的字节码哈希，
    #    就说明 bundle 里装的正是这版字节码，mtime 差异纯属检出造成。
    echo ""
    echo "mtime 判据：字节码比 bundle 新，再核一次内容哈希…"
    PY_BIN="/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python"
    [[ -x "$PY_BIN" ]] || PY_BIN="$(command -v python3 || true)"
    if [[ -n "$PY_BIN" ]] && "$PY_BIN" "$ROOT/scripts/ab_cache.py" fresh-check; then
        echo "✅ 内容一致（mtime 差异来自 git 检出，不是配置没进 bundle）"
        exit 0
    fi
    echo ""
    echo "🔴 字节码比 Lua bundle 新 —— 这份 bundle 里没有最新配置，打进包也不会生效。"
    echo "   修复：scripts/resource_build.sh --action ab --server-env <环境>"
    echo "   或 Jenkins：TS-Resource-Build（AB_MODE=重建）"
    exit 1
fi

echo "✅ Lua bundle 不早于字节码，包内 Lua 是最新的"
exit 0
