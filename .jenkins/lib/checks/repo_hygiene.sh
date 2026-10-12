#!/usr/local/bin/bash
# =============================================================================
# repo_hygiene.sh —— 仓库卫生检查（**只读**）
#
# 这个脚本只把一件事判成**失败**：**Lua 源码改了但对应字节码没跟着改**。
# 原因是本项目反复踩过同一个坑 —— 真机跑的是预编译字节码（`LuaBytes/*_64.bytes`），
# 只改 `~Lua/*.lua` 在 Editor 有效、真机无效，而且**不会有任何报错**，只是行为不对。
# 这种「静默不生效」比崩溃更难查，所以值得一条硬闸门。
#
# 其余项目（未提交、未推送、字节码反向不一致）只做提示，不影响退出码 ——
# 出包时工作区有杂物是常态，把常态判成红只会让人学会忽略红灯。
#
# 用法：.jenkins/lib/checks/repo_hygiene.sh
# 退出码：0 无硬性问题；1 存在「Lua 源码/字节码未成对」；2 环境错误
# =============================================================================
set -uo pipefail

PROJ="${PROJ:-/Users/wangxufeng/Documents/TimeSpaceGirl1}"
cd "$PROJ" || exit 2
git rev-parse --git-dir >/dev/null 2>&1 || { echo "不是 git 仓库" >&2; exit 2; }

LUA_REL="Assets/ManagedResources/~Lua"
BYTES_REL="Assets/ManagedResources/LuaBytes"
PAIR_BAD=0

echo "── 工作区状态 ─────────────────────────────────────"
CHANGED="$(git status --porcelain 2>/dev/null | grep -v '^?? \.workbuddy/' || true)"
N_CHANGED="$(printf '%s' "$CHANGED" | grep -c . || true)"
if [[ "$N_CHANGED" -eq 0 ]]; then
  echo "   ✓ 工作区干净"
else
  echo "   · 未提交 ${N_CHANGED} 项（提示，不阻断）："
  printf '%s\n' "$CHANGED" | head -10 | sed 's/^/       /'
  [[ "$N_CHANGED" -gt 10 ]] && echo "       … 其余 $((N_CHANGED - 10)) 项省略"
fi

echo "── 与上游的差距 ───────────────────────────────────"
BR="$(git rev-parse --abbrev-ref HEAD)"
UP="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -z "$UP" ]]; then
  echo "   · 分支 ${BR} 没有上游跟踪（提示）"
else
  AHEAD="$(git rev-list --count "$UP"..HEAD 2>/dev/null || echo 0)"
  BEHIND="$(git rev-list --count HEAD.."$UP" 2>/dev/null || echo 0)"
  echo "   · ${BR} → ${UP}：领先 ${AHEAD}，落后 ${BEHIND}（提示，不阻断）"
fi

echo "── 🔴 Lua 源码 ↔ 字节码 成对性（硬闸门）────────────"
# 命名规则：~Lua/Common/functions.lua → LuaBytes/Common_functions_64.bytes
# （把路径里的 / 换成 _，去掉 .lua，加 _64.bytes）
LUA_CHANGED="$(git status --porcelain -- "$LUA_REL" 2>/dev/null \
               | awk '{print $NF}' | grep '\.lua$' || true)"
LUA_N="$(printf '%s' "$LUA_CHANGED" | grep -c . || true)"

if [[ "$LUA_N" -eq 0 ]]; then
  echo "   ✓ 没有改动的 ~Lua 源文件，无需成对"
else
  echo "   改动/新增的 lua 共 ${LUA_N} 个："
  while IFS= read -r src; do
    [[ -n "$src" ]] || continue
    rel="${src#"$LUA_REL"/}"; rel="${rel%.lua}"; rel="${rel//\//_}"
    bytes="$BYTES_REL/${rel}_64.bytes"
    if [[ ! -f "$bytes" ]]; then
      echo "       🔴 缺字节码：$src"
      echo "          期望：$bytes"
      PAIR_BAD=1
    elif git status --porcelain -- "$bytes" 2>/dev/null | grep -q .; then
      echo "       ✓ 成对：${src}  ↔  ${bytes##*/}"
    else
      echo "       🔴 字节码未同步：${src} 已改，但 ${bytes##*/} 没改"
      PAIR_BAD=1
    fi
  done <<<"$LUA_CHANGED"
fi

# 反向可疑：字节码改了但源码没改（多半是手工改字节码，或重编了不该编的）
BYTES_CHANGED="$(git status --porcelain -- "$BYTES_REL" 2>/dev/null \
                 | awk '{print $NF}' | grep '_64\.bytes$' || true)"
if [[ -n "$BYTES_CHANGED" ]]; then
  while IFS= read -r b; do
    [[ -n "$b" ]] || continue
    rel="${b#"$BYTES_REL"/}"; rel="${rel%_64.bytes}"
    src="$LUA_REL/${rel//_/\/}.lua"
    [[ -f "$src" ]] || continue
    if ! git status --porcelain -- "$src" 2>/dev/null | grep -q .; then
      echo "   ⚠️ 字节码改了但源码没改：${b##*/}（源 ${src#"$PROJ"/}）"
    fi
  done <<<"$BYTES_CHANGED"
fi

echo "── 权威复核：lua-bytes-sync.sh --check ─────────────"
if [[ -x scripts/lua-bytes-sync.sh ]]; then
  TMPLOG="$(mktemp -t hygiene)"
  if scripts/lua-bytes-sync.sh --check >"$TMPLOG" 2>&1; then
    echo "   ✓ 已改动 lua 的字节码与源码逐字节一致"
  else
    sed 's/^/       /' "$TMPLOG" | head -20
    PAIR_BAD=1
  fi
else
  echo "   · scripts/lua-bytes-sync.sh 不可用，跳过权威复核（提示）"
fi

echo
if [[ $PAIR_BAD -eq 0 ]]; then
  echo "✅ 仓库卫生检查通过"
else
  echo "🔴 存在 Lua 源码/字节码不成对 —— 真机上这些改动不会生效"
fi
exit $PAIR_BAD
