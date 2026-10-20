/**@META
{
  "description": "**全量功能自动化（总入口）**：一次跑完「客户端 Lua 逻辑回归 + 三组设备用例（login/battle/func）」，一份报告看全貌。Lua 那部分**不需要设备**，所以哪怕本机起不了模拟器、也没插真机，这个 job 仍然有真实产出（绿/红都有意义）；设备那部分按体检结果跳过（黄球），不会假装通过。",
  "cron": "H 5 * * *",
  "concurrent": false,
  "keep": [30, 40],
  "artifactKeep": 10,
  "artifactDays": 14,
  "params": [
    {"name":"GROUPS","type":"string","default":"全部","description":"跑哪几组设备用例：全部 / login / battle / func，或逗号组合（login,battle）。留空或不认识的组会被跳过并写明"},
    {"name":"SKIP_LUA","type":"bool","default":false,"description":"跳过 Lua 逻辑回归（只想看设备用例时用）"},
    {"name":"APK","type":"string","default":"","description":"测哪个包；留空 = apks/ 下最新"},
    {"name":"TARGET","type":"choice","choices":["auto","已连接设备","本地模拟器","远程 adb"],"default":"auto","description":"设备从哪来"},
    {"name":"SERIAL","type":"string","default":"","description":"指定序列号 / host:5555"},
    {"name":"CASE_SCALE","type":"string","default":"1","description":"用例 wait/timeout 放大倍数（慢机器用 2~3）"},
    {"name":"REVERSE_PORTS","type":"string","default":"8081:8081,16081:16081","description":"端口反向"},
    {"name":"PACKAGE","type":"string","default":"","description":"包名，留空从 APK 读"},
    {"name":"ACTIVITY","type":"string","default":"","description":"入口 Activity，留空从 APK 读"},
    {"name":"AVD_NAME","type":"string","default":"ts-smoke-api33","description":"本地模拟器 AVD"},
    {"name":"SYSTEM_IMAGE","type":"string","default":"system-images;android-33;google_apis;x86_64","description":"系统镜像"},
    {"name":"UNINSTALL_FIRST","type":"bool","default":false,"description":"装前先卸载（签名不同时必须，会清本地数据）"},
    {"name":"KEEP_DEVICE","type":"bool","default":false,"description":"跑完不关设备"},
    {"name":"ALLOW_NO_DEVICE","type":"bool","default":true,"description":"没设备时记黄跳过；False 则判红"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 150, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '40'))
  }

  environment {
    PROJ  = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY    = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH  = '/usr/local/bin/bash'
    ANDROID_DEVICE = '/Users/wangxufeng/Documents/jenkins-shared/lib/android/device.sh'
    CASE_RUN       = '/Users/wangxufeng/Documents/jenkins-shared/lib/android/case_run.py'
    TEST_STAGES    = '/Users/wangxufeng/Documents/jenkins-shared/lib/test_job_stages.sh'
    TEST_RUNNER    = '/Users/wangxufeng/Documents/jenkins-shared/lib/test_runner.py'
  }

  stages {

    stage('① 准备与取证') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.TS_TARGET  = params.TARGET
          env.TS_SERIAL  = params.SERIAL
          env.TS_APK     = params.APK
          env.CASE_SCALE = params.CASE_SCALE
          env.TS_UNINSTALL = params.UNINSTALL_FIRST.toString()
          env.TS_KEEP      = params.KEEP_DEVICE.toString()
          env.TS_ALLOW_NO_DEVICE = params.ALLOW_NO_DEVICE.toString()
          env.GROUP = params.GROUPS
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" context
''')
      }
    }

    stage('② Lua 逻辑回归（无需设备）') {
      when { expression { params.SKIP_LUA == false } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
"$BASH" .jenkins/lib/run_stage.sh --name "Lua 逻辑回归" \
  --group "客户端逻辑" --slug lua --timeout 900 --warn-rc 3,4 \
  -- "$PY" "$TEST_RUNNER" run --project "$PROJ" --suite lua \
     --run-dir "$TS_RUN_DIR"
''')
      }
    }

    stage('③ 定位被测包') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" resolve
''')
      }
    }

    stage('④ 环境体检') {
      steps {
        script {
          def rc = sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" probe
''')
          env.DEVICE_OK = (rc == 0 && fileExists("${env.TS_RUN_DIR}/device.probe-ok")) ? 'true' : 'false'
          if (env.DEVICE_OK != 'true') {
            echo '⚠️ 本机没有可用设备 —— 设备用例全部跳过。Lua 那部分的结果仍然有效。'
          }
        }
      }
    }

    stage('⑤ 设备就绪') {
      when { expression { env.DEVICE_OK == 'true' } }
      options { timeout(time: 20, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" up
''')
      }
    }

    stage('⑥ 装包与启动') {
      when { expression { env.DEVICE_OK == 'true' } }
      options { timeout(time: 30, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" install
''')
      }
    }

    stage('⑦ 跑各组用例') {
      when { expression { env.DEVICE_OK == 'true' } }
      options { timeout(time: 90, unit: 'MINUTES') }
      steps {
        // 一次跑多组：**每组一行结论**（都进 summary），但不要一组失败就中断 ——
        // 全部跑完再一次性报红，省得修一组跑一遍。
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
RAW="${GROUPS:-全部}"
[[ "$RAW" == "全部" || -z "$RAW" ]] && RAW="login,battle,func"
FAILED=0
IFS=',' read -r -a GROUPS_ARR <<< "$RAW"
for g in "${GROUPS_ARR[@]}"; do
  g="$(printf '%s' "$g" | tr -d ' ')"
  [[ -z "$g" ]] && continue
  if [[ ! -d "$PROJ/tests/cases/$g" ]]; then
    "$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
      --name "用例组 $g" --group "功能用例" --status skip \
      --detail "没有这个组：tests/cases/$g 不存在" >/dev/null 2>&1 || true
    echo "⚠️ 跳过不存在的组：$g"
    continue
  fi
  if ! GROUP="$g" "$BASH" "$TEST_STAGES" cases; then
    FAILED=1
  fi
done
exit $FAILED
''')
      }
    }
  }

  post {
    always {
      script {
        sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" down
''')
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
            testResults: 'evidence/junit.xml,evidence/lua/junit.xml,evidence/cases/junit.xml'
        }

        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py desc --run "$TS_RUN_DIR" 2>/dev/null | tr -d '\\n' || true
LUA="$(grep 'CHECK|Lua 汇总' "$TS_RUN_DIR/lua/checks.txt" 2>/dev/null | head -1 || true)"
# 只取「14/15 通过」这一小段（BSD 的 cut 不认多字节分隔符，用 sed 按字面量截）
if [[ -n "$LUA" ]]; then printf ' · Lua %s' "$(printf '%s' "$LUA" | cut -d'|' -f4 | sed 's/ ·.*//')"; fi
DEV="$(cat "$TS_RUN_DIR/device.info" 2>/dev/null || true)"
if [[ -n "$DEV" ]]; then printf ' · %s' "$DEV"; fi
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
          artifacts: 'evidence/lua/checks.txt,evidence/lua/junit.xml,evidence/cases/**/*.png,evidence/cases/**/*.txt,evidence/cases/junit.xml,evidence/summary.md',
          fingerprint: false
      }
    }
  }
}
