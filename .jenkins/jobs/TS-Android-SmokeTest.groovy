/**@META
{
  "description": "**已打包好的 APK 装机冒烟**：定位包 → 环境体检（能不能跑模拟器 / 有没有真机）→ 起设备或复用已连设备 → 装包 + 端口反向 + 启动 → 等 N 秒看它崩不崩 → 截图与 logcat 归档。**只测不打包**：包从哪来由你给（默认取 apks/ 下最新的一份）。本机没有硬件虚拟化时会明确记「跳过」而不是假绿；换台机器/真机/远程模拟器，同一套 job 直接能跑。",
  "concurrent": false,
  "keep": [30, 40],
  "artifactKeep": 10,
  "artifactDays": 14,
  "params": [
    {"name":"APK","type":"string","default":"","description":"测哪个包。绝对路径，或相对工程根的路径（如 apks/2026-10-20/CLIBuild/1.2.51_vc77_021047.apk）。**留空 = 取 apks/ 下 mtime 最新的 .apk**；🔴 不会回退到旧包，找不到就失败"},
    {"name":"TARGET","type":"choice","choices":["auto","已连接设备","本地模拟器","远程 adb"],"default":"auto","description":"auto = 有已连设备就复用，没有才起本地模拟器；已连接设备 = 只用 adb devices 里 state=device 的（真机/已在跑的模拟器）；本地模拟器 = 本机起 headless emulator（需要硬件虚拟化）；远程 adb = adb connect 另一台机器上的模拟器"},
    {"name":"SERIAL","type":"string","default":"","description":"指定设备序列号（如 0000020c0d3e53c9）或远程地址（host:5555）。留空 = 自动挑第一台"},
    {"name":"AVD_NAME","type":"string","default":"ts-smoke-api33","description":"本地模拟器用哪个 AVD。不存在时会用 SYSTEM_IMAGE 自动创建（需要 JDK 17+ 的 avdmanager）"},
    {"name":"SYSTEM_IMAGE","type":"string","default":"system-images;android-33;google_apis;x86_64","description":"建 AVD 用的系统镜像。**Apple Silicon 要换成 arm64-v8a**；没有硬件虚拟化的机器装了也起不来"},
    {"name":"SMOKE_SECONDS","type":"string","default":"30","description":"启动后观察多久再下结论（秒）。太短会漏掉「进登录页才崩」，太长只是白等；默认 30"},
    {"name":"REVERSE_PORTS","type":"string","default":"8081:8081,16081:16081","description":"端口反向（设备 tcp:A → 本机 tcp:B，逗号分隔）。测试服的包连 127.0.0.1:8081，不做反向会一直转圈登录。连正式服的包可以留空"},
    {"name":"PACKAGE","type":"string","default":"","description":"包名。留空 = 从 APK 里读（aapt2 dump badging）；读不出来才需要手填"},
    {"name":"ACTIVITY","type":"string","default":"","description":"入口 Activity。留空 = 从 APK 的 launchable-activity 读；没有就退回 monkey 启动"},
    {"name":"UNINSTALL_FIRST","type":"bool","default":false,"description":"装之前先卸载。**签名不同（Play 版 vs upload key）时必须开**，但会清掉本地数据（账号数据在服务端）。默认关：装不上会直接告诉你原因，不会默默删你的包"},
    {"name":"KEEP_DEVICE","type":"bool","default":false,"description":"跑完不关模拟器 / 不断开远程设备。排查问题时开，跑完可以自己 adb 进去看现场"},
    {"name":"ALLOW_NO_DEVICE","type":"bool","default":true,"description":"本机既没有设备也起不了模拟器时：True = 记「跳过」并置黄球（诚实：没测，不是通过）；False = 直接判红（适合接了定时任务、缺设备本身就是要报警的场景）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 120, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '40'))
  }

  environment {
    PROJ  = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY    = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH  = '/usr/local/bin/bash'
    // 共享实现：装包/冒烟这套逻辑与工程无关，只有包名/端口是工程的
    ANDROID_DEVICE = '/Users/wangxufeng/Documents/jenkins-shared/lib/android/device.sh'
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
          env.TS_SECONDS = params.SMOKE_SECONDS
          env.TS_ALLOW_NO_DEVICE = params.ALLOW_NO_DEVICE.toString()
          env.TS_UNINSTALL = params.UNINSTALL_FIRST.toString()
          env.TS_KEEP      = params.KEEP_DEVICE.toString()
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs" "$TS_RUN_DIR/smoke"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "设备目标：${TS_TARGET}${TS_SERIAL:+（${TS_SERIAL}）}"
  echo "被测包：${TS_APK:-（apks/ 下最新）}"
  echo "观察时长：${TS_SECONDS}s"
  echo "用途：已打包 APK 的装机冒烟（只测不打包；不涉及上传）"
  echo "取证：$TS_RUN_DIR"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('② 定位被测包') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
APK_ARGS=()
[[ -n "${TS_APK:-}" ]] && APK_ARGS=(--apk "$TS_APK")
"$BASH" .jenkins/lib/run_stage.sh --name "定位被测包" \
  --group "被测对象" --slug resolve --timeout 120 \
  -- "$BASH" "$ANDROID_DEVICE" resolve "${APK_ARGS[@]}" \
     --run-dir "$TS_RUN_DIR" --project "$PROJ"
''')
      }
    }

    stage('③ 环境体检（这台机器能不能跑）') {
      steps {
        script {
          // 为什么要有这一步：本机没有硬件虚拟化（kern.hv_support=0，常见于 macOS 跑在虚拟机里），
          // 起不了模拟器。硬跑只会得到一个看不懂的 emulator 报错；先体检，才能给出
          // 「差什么、怎么补、或者换哪条路」。
          // rc=3 = 环境不具备（不是缺陷）→ 由 ALLOW_NO_DEVICE 决定记黄还是记红。
          def rc = sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
WARN_ARGS=()
[[ "${TS_ALLOW_NO_DEVICE:-true}" == "true" ]] && WARN_ARGS=(--warn-rc 3)
SERIAL_ARGS=()
[[ -n "${TS_SERIAL:-}" ]] && SERIAL_ARGS=(--serial "$TS_SERIAL")
"$BASH" .jenkins/lib/run_stage.sh --name "设备与环境体检" \
  --group "环境" --slug probe --timeout 180 "${WARN_ARGS[@]}" \
  -- "$BASH" "$ANDROID_DEVICE" probe --target "${TS_TARGET:-auto}" "${SERIAL_ARGS[@]}" \
     --avd "${AVD_NAME:-ts-smoke-api33}" --image "${SYSTEM_IMAGE:-}" \
     --run-dir "$TS_RUN_DIR" --project "$PROJ"
''')
          env.DEVICE_OK = (rc == 0 && fileExists("${env.TS_RUN_DIR}/device.probe-ok")) ? 'true' : 'false'
          if (env.DEVICE_OK != 'true') {
            echo '⚠️ 本机没有可用设备 —— 后面的「装包 / 启动 / 冒烟」会跳过。'
            echo '   这不是「通过」，只是「没测」；构建会置黄球。补设备的三条路见本次日志的「补齐清单」。'
          }
        }
      }
    }

    stage('④ 设备就绪（起模拟器 / 连设备）') {
      when { expression { env.DEVICE_OK == 'true' } }
      options { timeout(time: 20, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
SERIAL_ARGS=()
[[ -n "${TS_SERIAL:-}" ]] && SERIAL_ARGS=(--serial "$TS_SERIAL")
"$BASH" .jenkins/lib/run_stage.sh --name "设备就绪" \
  --group "环境" --slug device-up --timeout 900 \
  -- "$BASH" "$ANDROID_DEVICE" up --target "${TS_TARGET:-auto}" "${SERIAL_ARGS[@]}" \
     --avd "${AVD_NAME:-ts-smoke-api33}" --image "${SYSTEM_IMAGE:-}" \
     --boot-timeout "${BOOT_TIMEOUT:-300}" \
     --run-dir "$TS_RUN_DIR" --project "$PROJ"
''')
      }
    }

    stage('⑤ 装包与启动') {
      when { expression { env.DEVICE_OK == 'true' } }
      options { timeout(time: 30, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
PKG_ARGS=()
[[ -n "${PACKAGE:-}" ]]  && PKG_ARGS=(--package "$PACKAGE")
[[ -n "${ACTIVITY:-}" ]] && PKG_ARGS+=(--activity "$ACTIVITY")
UN_ARGS=()
[[ "${TS_UNINSTALL:-false}" == "true" ]] && UN_ARGS=(--uninstall-first)
"$BASH" .jenkins/lib/run_stage.sh --name "装包与启动" \
  --group "装机" --slug install --timeout 1500 \
  -- "$BASH" "$ANDROID_DEVICE" install "${PKG_ARGS[@]}" "${UN_ARGS[@]}" \
     --reverse "${REVERSE_PORTS:-}" \
     --run-dir "$TS_RUN_DIR" --project "$PROJ"
''')
      }
    }

    stage('⑥ 冒烟断言') {
      when { expression { env.DEVICE_OK == 'true' } }
      options { timeout(time: 20, unit: 'MINUTES') }
      steps {
        // 🔴 这里不加 --warn-ok：崩了就是崩了，必须红。
        //    「进程没了 / FATAL EXCEPTION / 前台不是本包」都是真缺陷，不是环境问题。
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
"$BASH" .jenkins/lib/run_stage.sh --name "冒烟断言" \
  --group "冒烟" --slug smoke --timeout 900 \
  -- "$BASH" "$ANDROID_DEVICE" smoke --seconds "${TS_SECONDS:-30}" \
     --reverse "${REVERSE_PORTS:-}" \
     --run-dir "$TS_RUN_DIR" --project "$PROJ"
''')
      }
    }
  }

  post {
    always {
      // 收尾必须放在 post.always：⑥ 失败时后面的 stage 会被跳过，
      // 而模拟器不关就会一直占着内存/端口，下一次构建直接起不来。
      script {
        sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" 2>/dev/null || exit 0
KEEP_ARGS=()
[[ "${TS_KEEP:-false}" == "true" ]] && KEEP_ARGS=(--keep)
"$BASH" .jenkins/lib/run_stage.sh --name "收尾（关模拟器 / 断设备）" \
  --group "收尾" --slug device-down --timeout 120 --warn-ok \
  -- "$BASH" "$ANDROID_DEVICE" down "${KEEP_ARGS[@]}" \
     --reverse "${REVERSE_PORTS:-}" \
     --run-dir "${TS_RUN_DIR:-$PWD/.android-smoke}" --project "$PROJ"
''')

        sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" 2>/dev/null || true
mkdir -p "$TS_RUN_DIR/logs"
"$PY" .jenkins/lib/stage_report.py junit --run "$TS_RUN_DIR" \
  --out "$TS_RUN_DIR/junit.xml" --suite "$JOB_NAME" || true
"$PY" .jenkins/lib/stage_report.py summary --run "$TS_RUN_DIR" \
  --out "$TS_RUN_DIR/summary.md" --title "$JOB_NAME #$BUILD_NUMBER" || true
# 每次重建本 job 的 evidence/：workspace 不 cleanWs，cp -R 只增不删，
# 否则上几次的截图/logcat 会被一起归档，看起来像「同一轮跑了两遍」。
if [[ -n "${WORKSPACE:-}" && -d "$WORKSPACE/evidence" ]]; then
  rm -rf "$WORKSPACE/evidence"
fi
mkdir -p "$WORKSPACE/evidence"
cp -R "$TS_RUN_DIR/." "$WORKSPACE/evidence/" 2>/dev/null || true
''')

        // 两张表一起发：环节表（哪一步红了）+ 冒烟断言表（崩没崩、画面出没出）
        if (fileExists("${WORKSPACE}/evidence/junit.xml")) {
          junit allowEmptyResults: true, skipPublishingChecks: true, testResults: 'evidence/junit.xml,evidence/smoke/junit.xml'
        }

        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py desc --run "$TS_RUN_DIR" 2>/dev/null | tr -d '\n' || true
# 构建描述里直接写出「哪个包 / 哪台设备 / 几条断言过」——
# 否则要展开六行环节表才知道这次到底测了什么。
APK="$(cat "$TS_RUN_DIR/apk.path" 2>/dev/null || true)"
DEV="$(cat "$TS_RUN_DIR/device.info" 2>/dev/null || true)"
PASS="$(grep -c '|pass|' "$TS_RUN_DIR/smoke/checks.txt" 2>/dev/null || true)"
FAILC="$(grep -c '|fail|' "$TS_RUN_DIR/smoke/checks.txt" 2>/dev/null || true)"
if [[ -n "$APK" ]]; then printf ' · %s' "${APK##*/}"; fi
if [[ -n "$DEV" ]]; then printf ' · %s' "$DEV"; fi
if [[ -n "$PASS" || -n "$FAILC" ]]; then printf ' · 断言 %s 过 %s 败' "${PASS:-0}" "${FAILC:-0}"; fi
''').trim()
        if (desc) { currentBuild.description = desc }

        def st = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py status --run "$TS_RUN_DIR" 2>/dev/null || echo pass
''').trim()
        if (st == 'warn' && currentBuild.currentResult == 'SUCCESS') {
          currentBuild.result = 'UNSTABLE'
        }

        // 截图是这套 job 最值钱的产物：一张图就能回答「画面到底出没出来」。
        // logcat 一起归档，免得复现时还要去翻机器上的设备。
        archiveArtifacts allowEmptyArchive: true,
          artifacts: 'evidence/smoke/*.png,evidence/smoke/*.txt,evidence/summary.md,evidence/junit.xml,evidence/smoke/junit.xml',
          fingerprint: false
      }
    }
  }
}
