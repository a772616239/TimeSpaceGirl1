/**@META
{
  "description": "**客户端 Lua 逻辑回归**（headless luajit，**不需要设备、不需要 Unity**）：把 `scripts/lua-tests/` 下每个 `test_*.lua` 跑一遍，统一判定、统一出 JUnit（有趋势）。用例自带假节点驱动真源码，覆盖挂机气泡 / 技能条 / 排行榜国旗 / 绑定倒计时 / 公告回调 / 多语言区服名等。已知失败走 `tests/lua-baseline.json` 基线（黄球+原因），基线外的新失败直接红。",
  "cron": "H 4 * * *",
  "concurrent": true,
  "keep": [30, 60],
  "artifactKeep": 10,
  "artifactDays": 14,
  "params": [
    {"name":"ONLY","type":"string","default":"","description":"只跑指定文件（逗号分隔，如 test_rank_head_flag.lua）。留空 = 全部"},
    {"name":"GROUP","type":"choice","choices":["全部","挂机","战斗","榜单","登录","功能","多语言"],"default":"全部","description":"按 tests/tests.json 里的分组筛选。改完某块功能可以只跑那一组，秒级反馈"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '60'))
  }

  environment {
    PROJ  = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY    = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH  = '/usr/local/bin/bash'
    TEST_RUNNER = '/Users/wangxufeng/Documents/jenkins-shared/lib/test_runner.py'
  }

  stages {

    stage('① 准备与取证') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "范围：${GROUP:-全部}${ONLY:+（只跑 $ONLY）}"
  echo "口径：headless luajit，不依赖 Unity / 不依赖设备"
  echo "基线：tests/lua-baseline.json（已知失败记黄，基线外记红）"
  echo "取证：$TS_RUN_DIR"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('② Lua 逻辑回归') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
ONLY_ARGS=()
[[ -n "${ONLY:-}" ]] && ONLY_ARGS=(--only "$ONLY")
GROUP_ARGS=()
[[ -n "${GROUP:-}" && "${GROUP}" != "全部" ]] && GROUP_ARGS=(--group "$GROUP")
"$BASH" .jenkins/lib/run_stage.sh --name "Lua 逻辑回归" \
  --group "客户端逻辑" --slug lua --timeout 900 --warn-rc 3,4 \
  -- "$PY" "$TEST_RUNNER" run --project "$PROJ" --suite lua \
     --run-dir "$TS_RUN_DIR" "${ONLY_ARGS[@]}" "${GROUP_ARGS[@]}"
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
if [[ -n "${WORKSPACE:-}" && -d "$WORKSPACE/evidence" ]]; then
  rm -rf "$WORKSPACE/evidence"
fi
mkdir -p "$WORKSPACE/evidence"
cp -R "$TS_RUN_DIR/." "$WORKSPACE/evidence/" 2>/dev/null || true
''')

        if (fileExists("${WORKSPACE}/evidence/junit.xml")) {
          junit allowEmptyResults: true, skipPublishingChecks: true,
            testResults: 'evidence/junit.xml,evidence/lua/junit.xml'
        }

        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py desc --run "$TS_RUN_DIR" 2>/dev/null | tr -d '\\n' || true
SUM="$(grep 'CHECK|Lua 逻辑回归 汇总' "$TS_RUN_DIR/lua/checks.txt" 2>/dev/null | head -1 || true)"
if [[ -n "$SUM" ]]; then
  printf ' · %s' "$(printf '%s' "$SUM" | cut -d'|' -f4)"
fi
''').trim()
        if (desc) { currentBuild.description = desc }

        def st = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py status --run "$TS_RUN_DIR" 2>/dev/null || echo pass
''').trim()
        if (st == 'warn' && currentBuild.currentResult == 'SUCCESS') {
          currentBuild.result = 'UNSTABLE'
        }

        archiveArtifacts allowEmptyArchive: true,
          artifacts: 'evidence/lua/*.log,evidence/lua/checks.txt,evidence/lua/junit.xml,evidence/summary.md',
          fingerprint: false
      }
    }
  }
}
