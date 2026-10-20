/**@META
{
  "description": "**功能点（背包/邮件/商店）自动化**（用例组 `func`）：定位包 → 体检 → 起/连设备 → 装包 → 跑 `tests/cases/func/*.json` 里的用例。功能点用例依赖各面板入口坐标与打开锚点日志，默认全是 draft（只记跳过）。加一个新功能 = 在 tests/cases/func/ 里加一个 JSON，不用新建 job。崩溃判红、环境不具备判黄。",
  "concurrent": false,
  "keep": [30, 40],
  "artifactKeep": 10,
  "artifactDays": 14,
  "params": [
    {"name":"APK","type":"string","default":"","description":"测哪个包：绝对路径 / 相对工程根；留空 = apks/ 下 mtime 最新的 .apk（不回退旧包）"},
    {"name":"TARGET","type":"choice","choices":["auto","已连接设备","本地模拟器","远程 adb"],"default":"auto","description":"设备从哪来：auto = 有已连设备就复用，没有才起本地模拟器"},
    {"name":"SERIAL","type":"string","default":"","description":"指定序列号或远程地址 host:5555。留空 = 自动挑第一台"},
    {"name":"CASES","type":"string","default":"","description":"只跑指定用例 id（逗号分隔，如 00_launch_only）。留空 = 跑本组全部"},
    {"name":"CALIBRATE","type":"bool","default":false,"description":"**校准模式**：不判断言，只重启 + 出 3 张截图（3/8/15s）+ 落 logcat，用来量坐标、找日志锚点。draft 用例也会跑；跑完去 Build Artifacts 里看 cases/<id>/*.png"},
    {"name":"CASE_SCALE","type":"string","default":"1","description":"把用例里的 wait/timeout 按倍数放大（慢机器/慢模拟器用 2 或 3）"},
    {"name":"REVERSE_PORTS","type":"string","default":"8081:8081,16081:16081","description":"端口反向（设备→本机）。测试服的包连 127.0.0.1:8081，不做反向会一直转圈登录"},
    {"name":"PACKAGE","type":"string","default":"","description":"包名，留空从 APK 读（aapt2）"},
    {"name":"ACTIVITY","type":"string","default":"","description":"入口 Activity，留空从 APK 读"},
    {"name":"AVD_NAME","type":"string","default":"ts-smoke-api33","description":"本地模拟器 AVD 名"},
    {"name":"SYSTEM_IMAGE","type":"string","default":"system-images;android-33;google_apis;x86_64","description":"建 AVD 用的镜像（Apple Silicon 换 arm64-v8a）"},
    {"name":"UNINSTALL_FIRST","type":"bool","default":false,"description":"装前先卸载。签名不同（Play 版 vs upload key）时必须开，但会清本地数据"},
    {"name":"KEEP_DEVICE","type":"bool","default":false,"description":"跑完不关模拟器 / 不断远程设备，方便接着手工看现场"},
    {"name":"ALLOW_NO_DEVICE","type":"bool","default":true,"description":"本机没设备时：True = 记黄并跳过（诚实：没测）；False = 判红（接了定时任务时用）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 90, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '40'))
  }

  environment {
    PROJ  = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY    = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH  = '/usr/local/bin/bash'
    ANDROID_DEVICE = '/Users/wangxufeng/Documents/jenkins-shared/lib/android/device.sh'
    CASE_RUN       = '/Users/wangxufeng/Documents/jenkins-shared/lib/android/case_run.py'
    TEST_STAGES    = '/Users/wangxufeng/Documents/jenkins-shared/lib/test_job_stages.sh'
    GROUP          = 'func'
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
          env.TS_CASES   = params.CASES
          env.TS_CALIBRATE = params.CALIBRATE.toString()
          env.CASE_SCALE = params.CASE_SCALE
          env.TS_UNINSTALL = params.UNINSTALL_FIRST.toString()
          env.TS_KEEP      = params.KEEP_DEVICE.toString()
          env.TS_ALLOW_NO_DEVICE = params.ALLOW_NO_DEVICE.toString()
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" context
''')
      }
    }

    stage('② 定位被测包') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" resolve
''')
      }
    }

    stage('③ 环境体检') {
      steps {
        script {
          def rc = sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" probe
''')
          env.DEVICE_OK = (rc == 0 && fileExists("${env.TS_RUN_DIR}/device.probe-ok")) ? 'true' : 'false'
          if (env.DEVICE_OK != 'true') {
            echo '⚠️ 本机没有可用设备 —— 装包与用例会跳过。这不是「通过」，是「没测」（黄球）。'
          }
        }
      }
    }

    stage('④ 设备就绪') {
      when { expression { env.DEVICE_OK == 'true' } }
      options { timeout(time: 20, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" up
''')
      }
    }

    stage('⑤ 装包与启动') {
      when { expression { env.DEVICE_OK == 'true' } }
      options { timeout(time: 30, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" install
''')
      }
    }

    stage('⑥ 跑功能用例组') {
      when { expression { env.DEVICE_OK == 'true' } }
      options { timeout(time: 60, unit: 'MINUTES') }
      steps {
        // 不加 --warn-ok：用例失败就是失败（warn-rc 3 只放行「全部未校准」）
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
"$BASH" "$TEST_STAGES" cases
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
            testResults: 'evidence/junit.xml,evidence/cases/junit.xml'
        }

        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py desc --run "$TS_RUN_DIR" 2>/dev/null | tr -d '\\n' || true
APK="$(cat "$TS_RUN_DIR/apk.path" 2>/dev/null || true)"
DEV="$(cat "$TS_RUN_DIR/device.info" 2>/dev/null || true)"
SUM="$(grep 'CHECK|用例汇总' "$TS_RUN_DIR/cases/checks.txt" 2>/dev/null | head -1 || true)"
if [[ -n "$APK" ]]; then printf ' · %s' "${APK##*/}"; fi
if [[ -n "$DEV" ]]; then printf ' · %s' "$DEV"; fi
if [[ -n "$SUM" ]]; then printf ' · %s' "$(printf '%s' "$SUM" | cut -d'|' -f4)"; fi
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
          artifacts: 'evidence/cases/**/*.png,evidence/cases/**/*.txt,evidence/cases/junit.xml,evidence/summary.md',
          fingerprint: false
      }
    }
  }
}
