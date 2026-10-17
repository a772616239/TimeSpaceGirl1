/**@META
{
  "description": "出测试用 APK（universal，upload key 签名）：环境预检 → Unity batchmode → 包内三重校验 → **把 APK 本体收成构建产物（构建页可直接下载安装）**。专为「我要拿个包装到手机上测」设计，不做任何上传。侧载前必须先卸载 Play 版（签名不同）。",
  "concurrent": false,
  "keep": [30, 30],
  "artifactKeep": 3,
  "artifactDays": 14,
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
        // 🔴 这一环是「用户要的东西」：把 APK 本体摆进 workspace/artifacts/，
        //    post 段才能真正把它 archive 进构建产物（archiveArtifacts 只认 workspace 相对路径）。
        //    以前只把 evidence/** 归档，APK 只留一行相对路径 ⇒ 构建页没有任何可下载的安装包。
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "APK 收成构建产物" \
  --group "交付" --slug stage-apk --timeout 900 \
  -- "$BASH" .jenkins/lib/stage_apk.sh
''')

        // 取证 sidecar（口径 / 16KB / 签名）继续留在 evidence 里，与 APK 本体一起归档
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
APK="$(cat "$TS_RUN_DIR/apk.path")"
mkdir -p "$TS_RUN_DIR/artifacts"
for f in "$APK.release.json" "$APK.delivery.json"; do
  if [[ -f "$f" ]]; then
    cp "$f" "$TS_RUN_DIR/artifacts/" && echo "  已收取证：${f##*/}"
  fi
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
# 🔴 同一条病根延伸到 APK：若本次构建在 ⑤ 之前就失败了，stage_apk.sh 没跑，
#    $WORKSPACE/artifacts/ 里还留着**上一次**的 APK。此时若照样归档，
#    构建页上会挂着一个「本次构建产出的」旧安装包 —— 比没有产物危险得多。
#    所以：本次没登记 apk.name ⇒ 删掉 artifacts/，宁可不给下载也不给错包。
if [[ -n "${WORKSPACE:-}" ]]; then
  if [[ -z "$(cat "$TS_RUN_DIR/apk.name" 2>/dev/null || true)" ]]; then
    if [[ -d "$WORKSPACE/artifacts" ]]; then
      rm -rf "$WORKSPACE/artifacts"
      echo "⚠️ 本次未产出 APK ⇒ 已清空 artifacts/，不归档任何安装包（避免把旧包当本次产物）"
    fi
  fi
fi
''')

        if (fileExists("${WORKSPACE}/evidence/junit.xml")) {
          junit allowEmptyResults: true, skipPublishingChecks: true, testResults: 'evidence/junit.xml'
        }

        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py desc --run "$TS_RUN_DIR" 2>/dev/null || true
# 构建描述里直接写出 APK 文件名与大小 —— 「这次的产物是个什么包」应当在标题下就看见，
# 而不是点开九个环节的表格去翻一行 artifact.txt。
# 名字与大小都读 stage_apk.sh 写下的 machine-readable 行，不再自己去猜路径。
NAME="$(cat "$TS_RUN_DIR/apk.name" 2>/dev/null || true)"
SZ="$(sed -n 's/^APK_SIZE_H=//p' "$TS_RUN_DIR/apk.artifact.txt" 2>/dev/null | head -1 || true)"
if [[ -n "$NAME" ]]; then
  printf ' · APK %s%s' "$NAME" "${SZ:+ · $SZ}"
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

        // 🔴 归档清单必须含 APK 本体，这是本 job 存在的意义。
        //    以前只写 'evidence/**' ⇒ 构建页「Build Artifacts」里只有 json/log，
        //    965MB 的安装包一个都下不到（只能自己去 apks/ 目录翻）。
        //    两个路径同时归档：artifacts/<name>.apk 是给人下载的，evidence/** 是取证。
        //    数量由 META 的 artifactKeep=3 兜住（LogRotator.artifactNumToKeep），
        //    否则 30 次构建 × 965MB ≈ 29GB 只为存测试包。
        archiveArtifacts allowEmptyArchive: true, artifacts: 'artifacts/*.apk,evidence/**', fingerprint: false
      }
    }
  }
}
