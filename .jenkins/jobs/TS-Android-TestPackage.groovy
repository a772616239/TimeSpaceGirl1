/**@META
{
  "description": "出测试用 APK（universal，upload key 签名）：环境预检 → Unity batchmode → 包内三重校验 → 归档。专为「我要拿个包装到手机上测」设计，不做任何上传。侧载前必须先卸载 Play 版（签名不同）。",
  "concurrent": false,
  "params": [
    {"name":"BUMP_VERSION","type":"bool","default":false,"description":"是否把 versionCode +1。测试包一般不用，保持与线上同号便于对照"},
    {"name":"EXPECT_PROFILE","type":"choice","choices":["minimal","dev","full"],"default":"minimal","description":"核验口径。CLI/CLIBuilder 固定 minimal（只关 GM）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 120, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '30'))
  }

  environment {
    PROJ  = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY    = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH  = '/usr/local/bin/bash'
    UNITY = '/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity'
  }

  stages {

    stage('① 准备与取证') {
      steps {
        script {
          env.TS_RUN_DIR    = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.TS_PROFILE    = params.EXPECT_PROFILE
          env.TS_BUMP       = params.BUMP_VERSION.toString()
          env.TS_BUILD_START= (System.currentTimeMillis() / 1000L).toString()
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "口径：$TS_PROFILE（CLIBuilder 固定 minimal）提版本号：$TS_BUMP"
  echo "用途：出测试 APK（侧载前须先卸载 Play 版 —— 签名不同）"
  echo "取证：$TS_RUN_DIR"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('② 打包环境预检') {
      stages {
        stage('工具链 / Gradle 模板 / 签名 / Unity 占用') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "打包环境预检" \
  --group "打包环境" --slug android-env --timeout 300 \
  -- "$BASH" .jenkins/lib/checks/android_env.sh
''')
          }
        }
        stage('AssetBundle 就绪（Lua 必须在包里）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "AssetBundle 就绪体检" \
  --group "打包环境" --slug ab-ready --timeout 600 \
  -- "$BASH" scripts/check_ab_ready.sh
''')
          }
        }
        stage('仓库卫生与 Lua 成对性') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "仓库卫生与 Lua 成对性" \
  --group "打包环境" --slug hygiene --timeout 600 \
  -- "$BASH" .jenkins/lib/checks/repo_hygiene.sh
''')
          }
        }
      }
    }

    stage('③ 构建 APK（Unity batchmode）') {
      options { timeout(time: 100, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
BUMP_ARG=""
[[ "$TS_BUMP" == "true" ]] || BUMP_ARG="--no-bump"
"$BASH" .jenkins/lib/build_apk.sh $BUMP_ARG --who "$JOB_NAME #$BUILD_NUMBER"
''')
      }
    }

    stage('④ 包内三重校验') {
      stages {
        stage('出包口径（isOpenGM 等 12 位开关）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
APK="$(cat "$TS_RUN_DIR/apk.path")"
"$BASH" .jenkins/lib/run_stage.sh --name "包内出包口径核验" \
  --group "包内校验" --slug cfg --timeout 300 \
  -- "$PY" scripts/verify_aab_release_config.py "$APK" --expect "$TS_PROFILE"
''')
          }
        }
        stage('native 16KB / NDK') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
APK="$(cat "$TS_RUN_DIR/apk.path")"
"$BASH" .jenkins/lib/run_stage.sh --name "native 16KB / NDK 体检" \
  --group "包内校验" --slug 16kb --timeout 300 \
  -- "$PY" scripts/verify_aab_native_16kb.py "$APK"
''')
          }
        }
        stage('交付自检（这包能不能拿去测）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
APK="$(cat "$TS_RUN_DIR/apk.path")"
"$BASH" .jenkins/lib/run_stage.sh --name "交付自检" \
  --group "包内校验" --slug delivery --timeout 300 \
  -- "$PY" scripts/verify_apk_delivery.py "$APK" --expect "$TS_PROFILE"
''')
          }
        }
      }
    }

    stage('⑤ 归档与交付说明') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
APK="$(cat "$TS_RUN_DIR/apk.path")"
mkdir -p "$TS_RUN_DIR/artifacts"
for f in "$APK.release.json" "$APK.delivery.json"; do
  [[ -f "$f" ]] && cp "$f" "$TS_RUN_DIR/artifacts/" && echo "  已收取证：${f##*/}"
done
VER="$("$PY" scripts/bump_version.py --show 2>/dev/null | tr '\n' ' ')"
{
  echo "APK  : $APK"
  echo "大小 : $(stat -f%z "$APK") B"
  echo "md5  : $(md5 -q "$APK")"
  echo "版本 : $VER"
  echo ""
  echo "侧载：adb install -r \"$APK\""
  echo "🔴 若手机已装 Play 版，必须先卸载 —— 本包用 upload key（beauty.keystore）签名，"
  echo "   与 Play 的 app signing key 不同，签名不匹配会装不上去。"
} | tee "$TS_RUN_DIR/artifacts/artifact.txt"
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "归档与交付说明" --group "交付" --status pass \
  --detail "$(basename "$APK") · $(du -h "$APK" | cut -f1)"
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

        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py desc --run "$TS_RUN_DIR" 2>/dev/null || true
''').trim()
        if (desc) { currentBuild.description = desc }

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
