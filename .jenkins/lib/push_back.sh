#!/usr/local/bin/bash
# =============================================================================
# push_back.sh —— 把本次打包「该进仓的改动」回写到 release 分支
#
# 为什么需要（这条是反复踩过的坑）：
#   CLI 打包的 versionCode 自增由 bump_version.py 完成，它改的是**打包目录**里的
#   ProjectSettings.asset；而打包目录每次 ①-1 都被 ci_sync 的 reset --hard 抹掉。
#   ⇒ 仓库里的 AndroidBundleVersionCode 永远停在旧值，下次构建又 bump 出同一个号，
#     上传 Play 时必被拒（各轨道共享同一个号空间）。所以构建成功后要把这次 bump
#     的结果提交回 release，让仓库跟上「已被 Play 占用」的最大号。
#
# 🔴 只回写**白名单**，绝不 `git add -A`：
#   打包目录里 Unity 重导入会留下大量噪声 —— 2026-10-23 实测一次构建有 17 个脏文件
#   （15 个 *.preset.meta 被删、Assets/CRC/game.asset、LuaBytes/*.bytes、
#    ResourcePathConfig.asset 被改）。这些是构建副产物，不该进仓。
#
# 用法（在打包目录里，构建成功之后跑）：
#   .jenkins/lib/push_back.sh [--branch release] [--dry-run]
#
# 环境变量：BRANCH（默认 release）/ JOB_NAME / BUILD_NUMBER / BUILD_URL
# 退出码：
#   0  已推送 / 本来就没改动（都算成功）
#   2  参数或环境错误（不在 git 仓、origin 不是 GitHub）
#   4  推送失败或 rebase 冲突 —— 调用方用 --warn-rc 4 标黄，
#      **不要判红**：走到这一步包已经打出来（甚至已经传上 Play）了。
# =============================================================================
set -uo pipefail

BRANCH="${BRANCH:-release}"
DRY_RUN=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch) BRANCH="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
        *) echo "🔴 不认识的参数：$1" >&2; exit 2 ;;
    esac
done

fail() { echo "🔴 $*" >&2; exit 2; }

# ---- 防呆：必须在 git 仓里，且 origin 是远端 GitHub 仓库 ---------------------
git rev-parse --git-dir >/dev/null 2>&1 || fail "当前目录不是 git 仓库：$(pwd)"
ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
case "$ORIGIN_URL" in
    *github.com/a772616239/TimeSpaceGirl1*) ;;
    *) fail "origin 不是 GitHub 仓库（${ORIGIN_URL}），拒绝回写" ;;
esac

# ---- 白名单：只有这些文件算「本次打包的改动」--------------------------------
# ProjectSettings.asset  ← bump_version.py 的 versionCode / versionName
# version.txt 四处        ← apply_build_env.py 注入的连服地址（正常 EXIT 会还原，
#                           万一没还原就说明仓库口径该更新，一起回写）
WHITELIST=(
    "ProjectSettings/ProjectSettings.asset"
    "Assets/Resources/version.txt"
    "Assets/StreamingAssets/Android/Resources/version.txt"
    "Assets/Android/Resources/version.txt"
    "AssetBundles/version.txt"
)

echo "→ 回写目标：origin/${BRANCH}（工程 $(pwd)）"
for f in "${WHITELIST[@]}"; do
    [[ -e "$f" ]] || continue
    git add -- "$f" 2>/dev/null || true
done

if git diff --cached --quiet; then
    echo "✅ 白名单里没有改动（versionCode 没变 / version.txt 已还原），无需回写"
    exit 0
fi

echo "→ 待回写："
git diff --cached --stat | sed 's/^/     /'

VC="$(git diff --cached -- ProjectSettings/ProjectSettings.asset \
      | /usr/bin/grep -E '^\+[[:space:]]*AndroidBundleVersionCode:' \
      | /usr/bin/grep -oE '[0-9]+' | head -1 || true)"
[[ -n "$VC" ]] || VC="$(/usr/bin/grep -m1 'AndroidBundleVersionCode:' ProjectSettings/ProjectSettings.asset 2>/dev/null | /usr/bin/grep -oE '[0-9]+' || true)"
[[ -n "$VC" ]] || VC="?"

if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "→ [dry-run] 只演示，不提交不推送（versionCode=${VC}）"
    git reset -q
    exit 0
fi

# ---- 提交（只含白名单）-----------------------------------------------------
MSG="chore(release): 回写 versionCode vc${VC}（${JOB_NAME:-local} #${BUILD_NUMBER:-0}）"
if ! git commit -q -m "$MSG" -m "由 .jenkins/lib/push_back.sh 自动回写：CLI 打包的 versionCode 自增发生在
打包目录，被 ci_sync 的 reset 抹掉后仓库会与 Play 已占用的号脱节。" 2>/dev/null; then
    echo "🔴 提交失败（git commit 返回非 0）"
    git reset -q
    exit 4
fi
echo "✅ 已提交：$(git log -1 --format='%h %s')"

# ---- 把 Unity 重导入的噪声挪走，否则 rebase 会以「工作区不干净」拒绝 --------
# 打包目录不是真源，这些改动下一次 ci_sync 也会被 reset 掉，所以 stash 走即可，
# 不需要 pop 回来。
if ! git stash push -u -m "push_back: 构建噪声 $(date '+%Y%m%d-%H%M%S')" >/dev/null 2>&1; then
    echo "   ⚠ stash 构建噪声失败，退回丢弃（打包目录不是真源）"
    git checkout -- . 2>/dev/null || true
fi

# ---- 推送（被拒则 fetch + rebase 重试）--------------------------------------
PUSHED=0
for attempt in 1 2 3; do
    if git push origin "HEAD:refs/heads/${BRANCH}" 2>&1 | sed 's/^/   /'; then
        PUSHED=1
        break
    fi
    echo "   ⚠ 推送被拒（第 ${attempt} 次），fetch + rebase 到最新 origin/${BRANCH} 后重试"
    git fetch origin "$BRANCH" 2>&1 | sed 's/^/   /' || break
    if ! git rebase "origin/${BRANCH}" 2>&1 | sed 's/^/   /'; then
        git rebase --abort 2>/dev/null || true
        echo "🔴 rebase 冲突，放弃回写：版本号请人工对齐（仓库值要跟上 Play 已占用的最大号）"
        exit 4
    fi
done

if [[ "$PUSHED" -ne 1 ]]; then
    echo "🔴 回写失败：3 次重试仍未推送成功。仓库里的 versionCode 还是旧值，"
    echo "   下次打包前请手动对齐（scripts/bump_version.py --set-code <Play 已占用最大号>）。"
    exit 4
fi

echo "✅ 已回写到 origin/${BRANCH} @ $(git rev-parse --short HEAD)（versionCode=${VC}）"
