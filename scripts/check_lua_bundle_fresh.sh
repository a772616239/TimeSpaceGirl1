#!/bin/bash
#
# 硬判据：LuaBytes 里的字节码是否已经打进 lzma|luabytes.unity3d
#
# 为什么必须有：旧的判据是「最新 bundle 的 mtime >= ResourcePathConfig.asset 的 mtime」，
# 但导表**根本不改** ResourcePathConfig.asset ⇒「字节码更新了、bundle 没重建」这种情况
# 静默放过（2026-10-20 实测：#7 包内还是旧配置，到包内环境校验才暴露）。
# 正确的判据是「bundle 不早于任何一个 LuaBytes/*_64.bytes」。
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
    echo ""
    echo "🔴 字节码比 Lua bundle 新 —— 这份 bundle 里没有最新配置，打进包也不会生效。"
    echo "   修复：scripts/resource_build.sh --action ab --server-env <环境>"
    echo "   或 Jenkins：TS-Resource-Build（REBUILD_AB=true）"
    exit 1
fi

echo "✅ Lua bundle 不早于字节码，包内 Lua 是最新的"
exit 0
