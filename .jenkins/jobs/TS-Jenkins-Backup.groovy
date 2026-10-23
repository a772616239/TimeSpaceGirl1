/**@META
{
  "description": "**Jenkins 任务目录自动备份**（每天一次）：把 `~/.jenkins/jobs`（仓库 `a772616239/JenkinJobs`，PRIVATE）里所有 job 的 `config.xml` + `nextBuildNumber` 的未提交改动 add → commit → push。解决「改了 job 但忘了提交，机器一挂配置就没了」这个常年漏洞。只动 job 定义，`builds/` 由 `.gitignore` 挡住、不入库。默认 dry-run 可用 `DRY_RUN` 勾选验证。凭据走 remote URL 内嵌 PAT，不需要账号口令。",
  "cron": "H 5 * * *",
  "concurrent": false,
  "keep": [30, 60],
  "params": [
    {"name":"TYPE","type":"choice","choices":["backup","cfg","chore","fix","feat"],"default":"backup","description":"提交类型（对应 type(scope): 摘要 里的 type）。自动跑用 backup，手工修配置用 cfg"},
    {"name":"SCOPE","type":"string","default":"jenkins-jobs","description":"提交范围（scope）。默认 jenkins-jobs"},
    {"name":"NOTE","type":"string","default":"","description":"附加说明，会接在提交摘要后面： type(scope): 摘要 — NOTE。留空则只有时间戳"},
    {"name":"DRY_RUN","type":"bool","default":false,"description":"只看会提交什么，不 commit 不 push。改动仓之前先勾一次确认"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 10, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '60'))
    disableConcurrentBuilds()
  }

  environment {
    JOB_REPO = '/Users/wangxufeng/.jenkins/jobs'
  }

  stages {

    // ---------------------------------------------------------------------
    // ① 只读体检
    //    git 仓库被自动化改写前必须先确认它处于「可以安全提交」的状态：
    //    - detached HEAD：提交会丢进游离头，push 都推不上去
    //    - rebase/merge/cherry-pick 半途：此时 add/commit 会把冲突标记一起提交
    //    - 远端不可达：PAT 过期 / 断网，早点报错别等到 commit 完才发现
    //    这些检查全是只读的，失败即退出，不留任何副作用。
    // ---------------------------------------------------------------------
    stage('① 体检') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail

echo "运行：$JOB_NAME #$BUILD_NUMBER"
echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
echo "目标：$JOB_REPO"
echo "口径：TYPE=${TYPE} SCOPE=${SCOPE} DRY_RUN=${DRY_RUN}"
echo

cd "$JOB_REPO" || { echo "🔴 目录不存在：$JOB_REPO"; exit 2; }
[[ -d .git ]] || { echo "🔴 $JOB_REPO 不是 git 仓库（缺 .git）"; exit 2; }

BR="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
[[ -n "$BR" ]] || { echo "🔴 处于 detached HEAD，拒绝自动提交（先 checkout 回分支）"; exit 2; }
echo "  分支：$BR"

for d in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD; do
  if [[ -e ".git/$d" ]]; then
    echo "🔴 仓库处于未完成的 $d 状态，拒绝自动提交，人工处理后再跑"
    exit 2
  fi
done

REMOTE_SAFE="$(git remote get-url origin 2>/dev/null | sed -E 's#//[^@/]+@#//***@#')"
echo "  远端：${REMOTE_SAFE:-（无 origin）}"
[[ -n "${REMOTE_SAFE:-}" ]] || { echo "🔴 没有 origin 远端"; exit 2; }

git ls-remote --heads origin "$BR" >/dev/null 2>&1 \
  || { echo "🔴 连不上 origin 或远端没有 $BR 分支（PAT 可能已过期）"; exit 2; }

N_D="$(git status --porcelain | wc -l | tr -d ' ')"
AHEAD="$(git rev-list --count "origin/$BR..$BR" 2>/dev/null || echo 0)"
BEHIND="$(git rev-list --count "$BR..origin/$BR" 2>/dev/null || echo 0)"
echo "  待提交：${N_D} 项   本地领先：${AHEAD}   落后：${BEHIND}"
echo "  最近提交：$(git log -1 --format='%h %ci %s' 2>/dev/null)"
echo "✓ 体检通过"
''')
      }
    }

    // ---------------------------------------------------------------------
    // ② 提交并推送
    //    `.gitignore` 已经挡住 `*/builds`、`*/scm-polling.log`、`.DS_Store`，
    //    所以这里的 add -A 只会捡 job 配置，不会把 2.3G 构建历史拖进仓库。
    //
    //    push 非快进（远端被别的会话推过）时**只允许一次** rebase 重试：
    //    这个仓库平时只有本机和 Jenkins 两边写，一次 rebase 足够；
    //    重试仍失败说明有语义冲突，交给人工，绝不 force。
    // ---------------------------------------------------------------------
    stage('② 提交并推送') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$JOB_REPO" || exit 2

BR="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo master)"

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "DRY_RUN：以下改动不会提交，也不会 push"
  echo "── git status ──"
  git status --short || true
  echo "── 未推送提交 ──"
  git log --oneline "origin/$BR..$BR" 2>/dev/null || true
  exit 0
fi

git add -A .

if git diff --cached --quiet; then
  echo "工作区无变更，无需提交"
  PEND="$(git rev-list --count "origin/$BR..$BR" 2>/dev/null || echo 0)"
  if [[ "${PEND}" == "0" ]]; then
    echo "✓ 远端已是最新，本次无事可做"
    exit 0
  fi
  echo "本地有 ${PEND} 个提交未推送，继续 push"
else
  FILES="$(git diff --cached --name-only | wc -l | tr -d ' ')"
  echo "暂存 ${FILES} 个文件："
  git diff --cached --name-only | sed 's/^/  /'

  TS="$(date '+%Y-%m-%d %H:%M')"
  MSG="${TYPE}(${SCOPE}): Jenkins 任务定义自动备份 ${TS}"
  if [[ -n "${NOTE:-}" ]]; then
    MSG="${MSG} — ${NOTE}"
  fi
  git commit -q -m "$MSG" || { echo "🔴 commit 失败"; exit 1; }
  echo "✓ 已提交 $(git log -1 --format='%h %s')"
fi

push_once () { git push --quiet origin "HEAD:${BR}" 2>&1; }

if push_once; then
  echo "✓ 已推送 origin/${BR}"
else
  echo "push 非快进或被拒，尝试 pull --rebase --autostash 后重试一次"
  if git pull --quiet --rebase --autostash origin "$BR"; then
    if push_once; then
      echo "✓ rebase 后推送成功"
    else
      echo "🔴 rebase 后仍推送失败，放弃（不做 force）"
      exit 1
    fi
  else
    echo "🔴 pull --rebase 失败，可能有冲突，已中止 rebase，请人工处理"
    git rebase --abort 2>/dev/null || true
    exit 1
  fi
fi

PEND="$(git rev-list --count "origin/$BR..$BR" 2>/dev/null || echo 0)"
if [[ "${PEND}" != "0" ]]; then
  echo "🔴 推送后仍有 ${PEND} 个提交未到达远端"
  exit 1
fi
echo "✓ 校验通过：本地与 origin/${BR} 一致"
''')
      }
    }
  }

  post {
    always {
      script {
        def d = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$JOB_REPO" 2>/dev/null || exit 0
BR="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo master)"
H="$(git log -1 --format=%h 2>/dev/null || echo -)"
N="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
U="$(git rev-list --count "origin/$BR..$BR" 2>/dev/null || echo ?)"
printf 'commit %s · 待提交 %s 项 · 未推送 %s' "$H" "$N" "$U"
''').trim()
        if (d) { currentBuild.description = d }
      }
    }
  }
}
