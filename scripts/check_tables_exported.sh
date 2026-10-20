#!/bin/bash
#
# 提醒：配置表（xlsx）是否已经导出成 Lua
#
# 判据：data_execl 下最新 xlsx 的 mtime 比 ~Lua/Config/Data 下最新 lua 还新 ⇒ 大概率「改了表没导表」。
# 只作**提醒**（黄球），不阻断：手改 lua、临时试验表都会造成同样现象。
#
# 退出码：0 一致 / 1 可能没导（提醒）/ 2 环境问题
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XLSX_DIR="$ROOT/data_execl/base_data"
LUA_DIR="$ROOT/Assets/ManagedResources/~Lua/Config/Data"

[[ -d "$XLSX_DIR" ]] || { echo "✗ 找不到配置表目录：$XLSX_DIR" >&2; exit 2; }
[[ -d "$LUA_DIR" ]]  || { echo "✗ 找不到导出目录：$LUA_DIR" >&2; exit 2; }

newest_of() { # $1=dir $2=glob
    local newest="" ts=0 t
    while IFS= read -r f; do
        t=$(stat -f%m "$f" 2>/dev/null || echo 0)
        if [[ "${t:-0}" -gt "$ts" ]]; then ts="$t"; newest="$f"; fi
    done < <(find "$1" -type f -name "$2" ! -name "~\$*" 2>/dev/null)
    printf '%s\t%s\n' "$ts" "$newest"
}

IFS=$'\t' read -r XLSX_TS XLSX_F <<< "$(newest_of "$XLSX_DIR" "*.xlsx")"
IFS=$'\t' read -r LUA_TS  LUA_F  <<< "$(newest_of "$LUA_DIR" "*.lua")"

echo "最新 xlsx：$(date -r "${XLSX_TS:-0}" '+%Y-%m-%d %H:%M' 2>/dev/null || echo 未知)（${XLSX_F##*/}）"
echo "最新 lua ：$(date -r "${LUA_TS:-0}"  '+%Y-%m-%d %H:%M' 2>/dev/null || echo 未知)（${LUA_F##*/}）"

if [[ "${XLSX_TS:-0}" -gt "${LUA_TS:-0}" ]]; then
    echo ""
    echo "⚠ 配置表比导出的 lua 新 —— 可能改了 xlsx 但没导表，包里会是旧配置。"
    echo "   确认改过表就勾 EXPORT_TABLES=true 重跑（会先导表再打包）；"
    echo "   若只是临时试验/手改过 lua，忽略此提醒即可。"
    exit 1
fi

echo "✅ 配置表不比导出的 lua 新"
exit 0
