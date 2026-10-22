#!/usr/local/bin/bash
# =============================================================================
# ci_sync.sh —— Jenkins 打包目录（TimeSpaceGirl1-build）的代码同步
#
# 背景：打包类 job（TS-Android-Release / TS-Android-TestPackage / TS-Resource-Build）
#   的 PROJ 已从开发目录切到独立打包目录 TimeSpaceGirl1-build，目的是
#   **开发目录开着 Unity 编辑器时也能打包**（两个 Unity 实例各锁各的工程，
#   resource_build.sh / android_env.sh 的占用检查都按 -projectpath 精确匹配，互不误伤）。
#
# 打包目录不是人的工作区，同步口径 = 「无条件向 origin/<分支> 对齐」：
#   1) git fetch origin <分支>
#   2) 工作区若有改动（上次构建/导表的残留），先 git stash 快照（可恢复，不丢弃）
#      再 reset --hard —— 打包目录的本地改动一律不是真源，真源在 origin 与开发目录
#   3) 从开发目录镜像不入库资产：.secrets/ keystore/ TimeSpaceServer/
#      build/table_sync/state.json（表同步基线）
#      （凭据、独立服务端仓、同步账本 git 都拉不到；开发目录是真源，镜像保持同状态）
#
# 🔴 防呆：只允许在打包目录里跑（.jenkins/run/.CI_BUILD_DIR 标记 + origin 必须是 GitHub）。
#    误在开发目录执行会 reset --hard 掉未提交工作 —— 必须挡死。
#
# 🔴 Library / BuildABs / StreamingAssets 不在本脚本职责内：
#    Library 首次从开发目录播种后由打包目录自己维护（Unity 增量）；
#    AB 过期由 check_ab_ready.sh 闸门拦住，重跑 TS-Resource-Build 在打包目录重建。
#
# 用法（在打包目录里）：.jenkins/ci_sync.sh
#   环境变量：BRANCH（默认 release） / DEV_PROJ（默认开发目录绝对路径）
# 退出码：0 成功 / 2 防呆拒绝 / 3 fetch 失败 / 4 reset 失败
# =============================================================================
set -uo pipefail

DEV_PROJ="${DEV_PROJ:-/Users/wangxufeng/Documents/TimeSpaceGirl1}"
BRANCH="${BRANCH:-release}"
CI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "🔴 $*" >&2; exit 2; }

# ---- 防呆 1：必须在打包目录（有标记） ---------------------------------------
[[ -f "$CI/.jenkins/run/.CI_BUILD_DIR" ]] || \
  fail "本脚本只能在 Jenkins 打包目录里跑（缺 .jenkins/run/.CI_BUILD_DIR 标记）。当前目录：$CI"

# ---- 防呆 2：origin 必须是远端仓库，不是开发目录 -----------------------------
ORIGIN_URL="$(git -C "$CI" remote get-url origin 2>/dev/null || true)"
case "$ORIGIN_URL" in
  *github.com/a772616239/TimeSpaceGirl1*) ;;
  *) fail "origin 不是 GitHub 仓库（${ORIGIN_URL}），拒绝同步" ;;
esac

# ---- ① fetch ---------------------------------------------------------------
cd "$CI" || exit 2
if ! git fetch origin "$BRANCH" --prune 2>&1 | sed 's/^/   /'; then
  echo "🔴 git fetch origin ${BRANCH} 失败" >&2
  exit 3
fi
REMOTE_HEAD="$(git rev-parse --short "origin/$BRANCH")"
LOCAL_HEAD="$(git rev-parse --short HEAD)"
echo "→ origin/$BRANCH = ${REMOTE_HEAD}（本地 = ${LOCAL_HEAD}）"

# ---- ② 脏工作区 → stash 快照 → reset ---------------------------------------
DIRTY="$(git status --porcelain -uno)"
if [[ -n "$DIRTY" ]]; then
  STAMP="$(date '+%Y%m%d-%H%M%S')"
  echo "→ 打包目录有 ${DIRTY} 行本地改动（上次构建/导表残留），先 stash 快照再重置"
  printf '%s\n' "$DIRTY" | head -20 | sed 's/^/     /'
  if ! git stash push -m "ci_sync auto-snapshot $STAMP" >/dev/null 2>&1; then
    echo "🔴 git stash 失败，放弃重置（保留现场人工排查）" >&2
    exit 4
  fi
  echo "   已存入 stash：$(git stash list | head -1)"
fi
if ! git reset --hard "origin/$BRANCH" >/dev/null 2>&1; then
  echo "🔴 git reset --hard origin/${BRANCH} 失败" >&2
  exit 4
fi
echo "✅ 代码已对齐 origin/$BRANCH @ $(git rev-parse --short HEAD)"

# ---- ③ 从开发目录镜像不入库资产 ---------------------------------------------
if [[ ! -d "$DEV_PROJ" ]]; then
  echo "⚠️ 开发目录不存在（${DEV_PROJ}），跳过资产镜像" >&2
  exit 0
fi
echo "→ 镜像不入库资产（真源：${DEV_PROJ}）"
rsync -a --delete "$DEV_PROJ/.secrets/"  "$CI/.secrets/"  && echo "   ✓ .secrets/"
rsync -a --delete "$DEV_PROJ/keystore/"  "$CI/keystore/"  && echo "   ✓ keystore/"
rsync -a --inplace "$DEV_PROJ/TimeSpaceServer/" "$CI/TimeSpaceServer/" \
  && echo "   ✓ TimeSpaceServer/（独立服务端仓，随开发目录同状态；--inplace 直写，
            不带 --delete：CI 目录不是真源，残留旧文件无害且沙箱拦 unlink）"

# ---- ④ 镜像「表同步基线」（否则打包 clone 永远是首次运行、一张表都推不出去） ----
# 🔴 2026-10-23 实测：build/table_sync/state.json 是 gitignore 的，打包 clone 里没有；
#    table_sync 首次运行只建基线不推表，于是「Jenkins 发线上包」这条路上表永远同步不出去
#    （客户端是新表、服务端还是旧表）。基线只是「上次同步到哪个指纹」的账本，
#    和 txt 一样以开发目录为真源；--update 保证只前移不回退（CI 自己推过的那次更可信）。
if [[ -f "$DEV_PROJ/build/table_sync/state.json" ]]; then
  mkdir -p "$CI/build/table_sync"
  rsync -a --update "$DEV_PROJ/build/table_sync/state.json" "$CI/build/table_sync/state.json" \
    && echo "   ✓ build/table_sync/state.json（表同步基线）"
else
  echo "   ⚠ 开发目录没有表同步基线（${DEV_PROJ}/build/table_sync/state.json），
       打包目录首次跑 table_sync 只会建基线、不推表" >&2
fi

echo "✅ 同步完成：$(git -C "$CI" log -1 --format='%h %s (%ci)')"
