/**@META
{
  "description": "服务端 / 区服运维动作统一入口：把散在 ~/ts-*-2026*、~/ts-shard10002、远端 RESTART-GAMESERVER.sh 的几套子命令方言，收口成一个下拉框。破坏性动作（重启、打补丁、隐藏区服）会先要求人工审批 + 手打动作名确认。",
  "concurrent": false,
  "params": [
    {"name":"ACTION","type":"choice","choices":["health","chat-patch-verify","upstar-verify","shard-verify","gameserver-restart","chat-patch-apply","chat-patch-restart","chat-patch-rollback","upstar-apply","upstar-restart","upstar-rollback","shard-hide","shard-show","shard-rollback"],"default":"health","description":"要执行的动作。verify/health 类只读；其余为破坏性（会踢线或改动生产），需审批"},
    {"name":"CONFIRM","type":"string","default":"","description":"🔴 破坏性动作必须在这里原样再打一遍动作名（例如 gameserver-restart），防止下拉框手滑"},
    {"name":"REASON","type":"string","default":"","description":"本次操作原因（会写进构建描述与证据文件，便于事后追溯）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 45, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '90', numToKeepStr: '80'))
  }

  environment {
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 参数与影响说明') {
      steps {
        script {
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.TS_ACTION  = params.ACTION
          def disruptive = ['gameserver-restart',
                            'chat-patch-apply', 'chat-patch-restart', 'chat-patch-rollback',
                            'upstar-apply', 'upstar-restart', 'upstar-rollback',
                            'shard-hide', 'shard-show', 'shard-rollback']
          env.TS_DESTRUCTIVE = disruptive.contains(params.ACTION) ? 'true' : 'false'
          if (env.TS_DESTRUCTIVE == 'true' && params.CONFIRM.trim() != params.ACTION) {
            error("拒绝执行破坏性动作：请在 CONFIRM 里原样再打一遍动作名（应为 '${params.ACTION}'，"
                + "当前为 '${params.CONFIRM.trim()}'）。这是防止下拉框手滑的最后一道。")
          }
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs"

ROW="$("$BASH" .jenkins/lib/server_ops.sh --list | awk -F'\\t' -v a="$TS_ACTION" '$1==a')"
DESC="$(printf '%s' "$ROW" | cut -f3)"
KIND="$(printf '%s' "$ROW" | cut -f2)"

{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "动作：$TS_ACTION"
  echo "性质：$KIND"
  echo "说明：$DESC"
  echo "原因：${REASON:-（未填写）}"
  echo "确认：${CONFIRM:-（无，只读动作不需要）}"
} | tee "$TS_RUN_DIR/context.txt"

if [[ "$KIND" == "destructive" ]]; then
  echo
  echo "🔴🔴 这是破坏性动作：$DESC"
fi
''')
      }
    }

    stage('② 人工审批（破坏性动作）') {
      when { expression { env.TS_DESTRUCTIVE == 'true' } }
      steps {
        script {
          def row = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$BASH" .jenkins/lib/server_ops.sh --list | awk -F'\\t' -v a="$TS_ACTION" '$1==a' | cut -f3
''').trim()
          input message: """即将对【生产环境】执行破坏性动作，请确认：

  动作：${params.ACTION}
  说明：${row}
  原因：${params.REASON ?: '（未填写）'}

后果提示：重启类动作会踢掉当前在线玩家；隐藏区服会让玩家在选服界面看不到该区。
确认无误请点「确认执行」；不想动点「中止」。""", ok: '确认执行'
        }
      }
    }

    stage('③ 执行动作') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "执行：$TS_ACTION" \
  --group "运维动作" --slug ops --timeout 2400 \
  -- "$BASH" .jenkins/lib/server_ops.sh "$TS_ACTION"
''')
      }
    }

    stage('④ 留证') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
mkdir -p "$TS_RUN_DIR/artifacts"
{
  echo "动作：$TS_ACTION"
  echo "性质：$( "$BASH" .jenkins/lib/server_ops.sh --list | awk -F'\\t' -v a="$TS_ACTION" '$1==a{print $2}' )"
  echo "原因：${REASON:-（未填写）}"
  echo "执行人：${BUILD_USER_ID:-unknown}"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "构建：$JOB_NAME #$BUILD_NUMBER"
} | tee "$TS_RUN_DIR/artifacts/ops-record.txt"
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "操作留证" --group "交付" --status pass --detail "$TS_ACTION"
''')
      }
    }
  }

  post {
    always {
      script {
        sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" 2>/dev/null || true
mkdir -p "$TS_RUN_DIR/logs"
"$PY" .jenkins/lib/stage_report.py junit --run "$TS_RUN_DIR" \
  --out "$TS_RUN_DIR/junit.xml" --suite "$JOB_NAME" || true
"$PY" .jenkins/lib/stage_report.py summary --run "$TS_RUN_DIR" \
  --out "$TS_RUN_DIR/summary.md" --title "$JOB_NAME #$BUILD_NUMBER" || true
# 每次都重建本 job 的 evidence/：
# workspace 不做 cleanWs，而 `cp -R` 只增不删 ⇒ 上几次构建的 stages/*.json 会被一起归档，
# 看起来像「同一个环节跑了两遍」。实测 2026-10-12 构建#5 的归档里混进了 #3/#4 的记录。
# 只删本 job 自己的 evidence/（$WORKSPACE 已由 Jenkins 设置，且只在非空时动手）。
if [[ -n "${WORKSPACE:-}" && -d "$WORKSPACE/evidence" ]]; then
  rm -rf "$WORKSPACE/evidence"
fi
mkdir -p "$WORKSPACE/evidence"
cp -R "$TS_RUN_DIR/." "$WORKSPACE/evidence/" 2>/dev/null || true
''')

        if (fileExists("${WORKSPACE}/evidence/junit.xml")) {
          junit allowEmptyResults: true, skipPublishingChecks: true, testResults: 'evidence/junit.xml'
        }

        def marks = "${params.ACTION}"
        if (env.TS_DESTRUCTIVE == 'true') { marks = "🔴 ${marks}" }
        if (params.REASON?.trim()) { marks = "${marks} · ${params.REASON.trim()}" }
        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py desc --run "$TS_RUN_DIR" 2>/dev/null || true
''').trim()
        currentBuild.description = (desc ? "${desc} | " : "") + marks

        def st = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py status --run "$TS_RUN_DIR" 2>/dev/null || echo pass
''').trim()
        if (st == 'warn' && currentBuild.currentResult == 'SUCCESS') {
          currentBuild.result = 'UNSTABLE'
        }

        archiveArtifacts allowEmptyArchive: true, artifacts: 'evidence/**', fingerprint: false
      }
    }
  }
}
