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
exec /usr/local/bin/bash "/Users/wangxufeng/Documents/jenkins-shared/apply-jobs.sh" \
  --project "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" "$@"
