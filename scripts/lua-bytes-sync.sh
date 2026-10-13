#!/bin/bash
#
# 把 ~Lua/**/*.lua 的改动同步重编到 LuaBytes/<路径下划线化>_64.bytes
#
# 为什么必须有这个脚本：
#   真机跑的是预编译字节码（GameSettings.cs 在 !isEditor 时强制 luaBundleMode=true，
#   读 Assets/ManagedResources/LuaBytes/<路径下划线化>_64.bytes），只有 Editor 回落 ~Lua/*.lua。
#   ⇒ 只改源码 = Editor 有效、真机无效。本项目历史上反复出现「只提交源码没重编字节码」。
#
# 用法：
#   scripts/lua-bytes-sync.sh              # 自动处理 git 里已改动/未跟踪的 ~Lua/*.lua
#   scripts/lua-bytes-sync.sh <a.lua> ...  # 只处理指定文件（路径可在 ~Lua 内，也可给全路径）
#   scripts/lua-bytes-sync.sh --check      # 只检查是否有源码与字节码不同步，不写文件
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LUA_ROOT="$ROOT/Assets/ManagedResources/~Lua"
BYTES_ROOT="$ROOT/Assets/ManagedResources/LuaBytes"
ENCODER_DIR="$ROOT/LuaEncoder/luajit_mac/64"
ENCODER="$ENCODER_DIR/luajit"

[ -x "$ENCODER" ] || { echo "❌ 找不到编码器：$ENCODER"; exit 1; }

# ~Lua/Common/functions.lua -> Assets/ManagedResources/LuaBytes/Common_functions_64.bytes
bytes_path_of() {
  local rel="${1#"$LUA_ROOT"/}"
  rel="${rel%.lua}"
  rel="${rel//\//_}"
  echo "$BYTES_ROOT/${rel}_64.bytes"
}

encode() { # $1 = lua 绝对路径
  local src="$1" dst
  dst="$(bytes_path_of "$src")"
  [ -f "$src" ] || { echo "   ⚠️ 跳过（源不存在）：$src"; return 0; }
  # 必须带 LUA_PATH 且在编码器目录下执行；不能加 -g（会写入源码绝对路径且不剥离）
  ( cd "$ENCODER_DIR" && LUA_PATH="./?.lua;;" "$ENCODER" -b "$src" "$dst" )
  printf '   %-58s -> %s  (%s B)\n' "${src#"$ROOT"/}" "${dst#"$ROOT"/}" "$(wc -c < "$dst" | tr -d ' ')"
}

collect_changed() {
  git -C "$ROOT" status --porcelain -- "Assets/ManagedResources/~Lua" \
    | awk '{ $1=""; sub(/^ /,""); print }' \
    | grep '\.lua$' || true
}

CHECK_ONLY=0
TARGETS=()
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=1 ;;
    *) TARGETS+=("$arg") ;;
  esac
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  while IFS= read -r rel; do
    [ -n "$rel" ] && TARGETS+=("$ROOT/$rel")
  done < <(collect_changed)
else
  # 显式传入的相对路径必须转成绝对路径：encode() 会 cd 到编码器目录执行
  NORM=()
  for t in "${TARGETS[@]}"; do
    if [ -f "$t" ]; then NORM+=("$(cd "$(dirname "$t")" && pwd)/$(basename "$t")")
    elif [ -f "$ROOT/$t" ]; then NORM+=("$ROOT/$t")
    elif [ -f "$LUA_ROOT/$t" ]; then NORM+=("$LUA_ROOT/$t")
    else NORM+=("$t"); fi
  done
  TARGETS=("${NORM[@]}")
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "✅ ~Lua 下没有改动，无需重编"
  exit 0
fi

echo "待处理 ${#TARGETS[@]} 个 lua 文件："

if [ "$CHECK_ONLY" -eq 1 ]; then
  STALE=0
  TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
  for src in "${TARGETS[@]}"; do
    [ -f "$src" ] || continue
    dst="$(bytes_path_of "$src")"
    if [ ! -f "$dst" ]; then
      echo "   🔴 缺字节码：${dst#"$ROOT"/}"
      STALE=1
      continue
    fi
    ( cd "$ENCODER_DIR" && LUA_PATH="./?.lua;;" "$ENCODER" -b "$src" "$TMP/x.bytes" )
    if cmp -s "$TMP/x.bytes" "$dst"; then
      echo "   ✅ 已同步：${src#"$ROOT"/}"
    else
      echo "   🔴 不同步：${src#"$ROOT"/}（需重编 ${dst#"$ROOT"/}）"
      STALE=1
    fi
  done
  exit "$STALE"
fi

for src in "${TARGETS[@]}"; do
  encode "$src"
done

echo
echo "自检（重编后再比一次，应全部「已同步」）："
"$0" --check "${TARGETS[@]}"
