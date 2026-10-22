#!/usr/local/bin/bash
# =============================================================================
# apply-jobs.sh —— 转发到共享实现（2026-10-18 起实现只有一份）
#
# 真正的代码：/Users/wangxufeng/Documents/jenkins-shared/apply-jobs.sh
# 工程差异：  ./.jenkins/jenkins.env （PREFIX / VIEW_NAME / VIEW_DESC / PY ...）
#
# 这个文件只负责把「当前工程」定位出来再原样透传参数。
# 改同步逻辑请改共享库，不要在这里加分支——否则又会分叉成两份。
#
# 用法不变：
#   .jenkins/apply-jobs.sh                 # 同步全部 + 建/更新视图
#   .jenkins/apply-jobs.sh --only TS-xxx   # 只推一个
#   .jenkins/apply-jobs.sh --dry-run       # 只渲染，不推
#   .jenkins/apply-jobs.sh --check         # 只体检（CI 用）
# =============================================================================
set -uo pipefail

PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# 🔴 前置闸门：覆盖 job 配置会**中断正在跑的构建**（2026-10-22 实测）
#    `disableConcurrentBuilds(abortPrevious=false)` 只排队不抢占，但 create-job
#    / 覆盖配置会让同 job 的运行实例被 abort，而且**不留 `Aborted by` 行** ——
#    现场是 #28 把 post-actions 都跑完了才被标 ABORTED。危害不只是浪费时间：
#    翻译链/打包链被拦腰打断时，已经 publish 的半成品会留在磁盘上（#27 那张
#    DIVINE JUDGMENT 的坏图就是这么落盘的）。
#    所以：只在有 RUNNING 构建时**拒绝**，给了 --allow-running 或 ALLOW_RUNNING=1 才放行。
# -----------------------------------------------------------------------------
ONLY_ARG=""
ALLOW_RUNNING="${ALLOW_RUNNING:-0}"
DRY=0
prev=""
for a in "$@"; do
  case "$a" in
    --only) ONLY_ARG="__next__" ;;
    --dry-run|--check) DRY=1 ;;
    --allow-running) ALLOW_RUNNING=1 ;;
    *) [[ "$ONLY_ARG" == "__next__" ]] && ONLY_ARG="$a" || true ;;
  esac
done

if [[ "$DRY" -eq 0 && "$ALLOW_RUNNING" -ne 1 && "$ONLY_ARG" != "__next__" ]]; then
  # shellcheck disable=SC1090
  CREDS="$HOME/.jenkins/.qclaw-creds"
  if [[ -r "$CREDS" ]]; then
    JURL=$(sed -n 's|^JENKINS_URL=||p' "$CREDS" | head -1)
    JUSER=$(sed -n 's|^JENKINS_USER=||p' "$CREDS" | head -1)
    JTOK=$(sed -n 's|^JENKINS_TOKEN=||p' "$CREDS" | head -1)
    JURL="${JURL:-http://localhost:8080}"
    if [[ -n "$JTOK" ]]; then
      if [[ -n "$ONLY_ARG" ]]; then
        TARGETS="$ONLY_ARG"
      else
        TARGETS=$(cd "$PROJ/.jenkins/jobs" && ls -1 *.groovy 2>/dev/null | sed 's/\.groovy$//')
      fi
      BUSY=""
      for j in $TARGETS; do
        st=$(curl -s -m 6 -u "$JUSER:$JTOK" \
          "$JURL/job/$j/api/json?tree=lastBuild[building,number]" 2>/dev/null || true)
        if printf '%s' "$st" | grep -q '"building":true'; then
          NUM=$(printf '%s' "$st" | sed -n 's/.*"number":\([0-9]*\).*/\1/p')
          BUSY="$BUSY $j(#$NUM)"
        fi
      done
      if [[ -n "$BUSY" ]]; then
        echo "🔴 有构建正在跑，覆盖 job 配置会打断它（且不留 Aborted 行，可能留下半成品）："
        for b in $BUSY; do echo "   - $b"; done
        echo "   等它跑完，或确认无妨后重跑：ALLOW_RUNNING=1 $0 $*"
        exit 2
      fi
    fi
  fi
fi

exec /usr/local/bin/bash "/Users/wangxufeng/Documents/jenkins-shared/apply-jobs.sh" \
  --project "$PROJ" "$@"
