/**@META
{
  "description": "Android 发版全链路（AAB）：发布安全闸门 → 打包环境预检 → 提版本号 → Unity 构建 → 包内三重校验（出包口径 / native 16KB / 交付自检）→ 归档 →（可选）人工审批后上传 Play。默认只出包、不上传、status=draft。",
  "concurrent": false,
  "params": [
    {"name":"EXPECT_PROFILE","type":"choice","choices":["minimal","dev","full"],"default":"minimal","description":"核验口径（包内 12 位开关应等于哪一档）。⚠️ CLI 构建固定 minimal（CLIBuilder.kProfile 硬编码），选 dev/full 只应用于配合 REUSE_AAB 核验 GUI/手工出的包"},
    {"name":"BUMP_VERSION","type":"bool","default":true,"description":"构建前把 versionCode +1。CLI 打包不自增，传 production 必须严格递增"},
    {"name":"REUSE_AAB","type":"string","default":"","description":"复用已有 AAB 的路径（填了就跳过 Unity 构建，只做校验/上传）"},
    {"name":"ALLOW_NO_LUA","type":"bool","default":false,"description":"强行跳过「未发现 Lua bundle」闸门（风险自负，会打出没有 Lua 的废包）"},
    {"name":"UPLOAD","type":"bool","default":false,"description":"🔴 是否上传到 Google Play。默认否。勾上后仍需通过人工审批；是否送审另由 STATUS/PUBLISH 决定"},
    {"name":"TRACK","type":"choice","choices":["production","beta","alpha","internal"],"default":"production","description":"上传轨道"},
    {"name":"STATUS","type":"choice","choices":["draft","inProgress","completed"],"default":"draft","description":"发布状态：draft=草稿（不送审）/ completed=提交审核 = 上线"},
    {"name":"PUBLISH","type":"bool","default":false,"description":"🔴 才允许 STATUS=completed/inProgress。要送审必须先拿到用户明确同意"},
    {"name":"NOTES","type":"string","default":"","description":"更新说明（Play 发布说明）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 150, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '60', numToKeepStr: '40'))
  }

  environment {
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 准备与取证') {
      steps {
        script {
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          // 参数转环境变量下发：避免拼命令字符串带来的引号/空格问题（更新说明里可能有空格）
          env.TS_PROFILE   = params.EXPECT_PROFILE
          env.TS_BUMP      = params.BUMP_VERSION.toString()
          env.TS_REUSE     = params.REUSE_AAB.trim()
          env.TS_ALLOWNOLUA= params.ALLOW_NO_LUA.toString()
          env.TS_TRACK     = params.TRACK
          env.TS_STATUS    = params.STATUS
          env.TS_PUBLISH   = params.PUBLISH.toString()
          env.TS_NOTES     = params.NOTES
          env.TS_BUILD_START = (System.currentTimeMillis() / 1000L).toString()
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "口径：$TS_PROFILE  提版本号：$TS_BUMP  复用 AAB：${TS_REUSE:-（无，将构建）}"
  echo "上传：$UPLOAD  轨道：$TS_TRACK  状态：$TS_STATUS  PUBLISH：$TS_PUBLISH"
  echo "取证：$TS_RUN_DIR"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('② 发布安全闸门') {
      stages {
        stage('送审闸门完好（默认拒绝）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "送审闸门完好性" \
  --group "发布安全" --slug play-gate --timeout 300 \
  -- "$BASH" .jenkins/lib/checks/play_gate.sh
''')
          }
        }
        stage('仓库卫生与 Lua 成对性') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "仓库卫生与 Lua 成对性" \
  --group "发布安全" --slug hygiene --timeout 600 \
  -- "$BASH" .jenkins/lib/checks/repo_hygiene.sh
''')
          }
        }
      }
    }

    stage('③ 打包环境预检') {
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
      }
    }

    stage('④ 提版本号') {
      when { expression { params.BUMP_VERSION && params.REUSE_AAB.trim().isEmpty() } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
before="$("$PY" scripts/bump_version.py --show 2>&1 | tr '\n' ' ')"
"$BASH" .jenkins/lib/run_stage.sh --name "提版本号 versionCode +1" \
  --group "构建" --slug bump --timeout 120 \
  -- "$PY" scripts/bump_version.py --bump || exit $?
after="$("$PY" scripts/bump_version.py --show 2>&1 | tr '\n' ' ')"
printf 'bump 前：%s\nbump 后：%s\n' "$before" "$after" | tee "$TS_RUN_DIR/version.txt"
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "版本号变更" --group "构建" --status pass --detail "$after"
''')
      }
    }

    stage('⑤ 构建 AAB（Unity batchmode）') {
      options { timeout(time: 120, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"

BUILD_ARGS=(--no-bump)
if [[ -n "${TS_REUSE:-}" ]]; then
  BUILD_ARGS=(--no-bump --skip-build --aab "$TS_REUSE")
fi
[[ "$TS_ALLOWNOLUA" == "true" ]] && BUILD_ARGS+=(--allow-no-lua)

echo "→ scripts/aab_release.sh ${BUILD_ARGS[*]}"
# 🔴 纳入 unity 锁：同一 Unity 工程不能有第二个 batchmode 实例，
#    而且 TS-Android-TestPackage / 手工 Unity 都可能同时在跑。
"$BASH" .jenkins/lib/run_stage.sh --name "Unity 构建 AAB" \
  --group "构建" --slug build-aab --timeout 7000 \
  -- "$BASH" .jenkins/lib/lock.sh --name unity run \
       --who "$JOB_NAME #$BUILD_NUMBER" --timeout 1800 -- \
       "$BASH" scripts/aab_release.sh "${BUILD_ARGS[@]}"
''')
      }
    }

    stage('⑥ 定位本次产物') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 🔴 必须限定「本次构建之后」的产物：否则构建失败时会拿上一次的旧包继续校验，
# 一路绿灯但校的是昨天那个包 —— 最危险的假通过。
"$BASH" .jenkins/lib/run_stage.sh --name "定位本次 AAB 产物" \
  --group "构建" --slug locate-aab --timeout 120 \
  -- "$PY" .jenkins/lib/find_artifact.py 'apks/*/CLIBuild/*.aab' \
       --root "$PROJ" --after "$TS_BUILD_START" --out "$TS_RUN_DIR/aab.path"
AAB="$(cat "$TS_RUN_DIR/aab.path")"
echo "$AAB" | tee "$TS_RUN_DIR/aab.resolved"
ls -la "$AAB" "$AAB.release.json" 2>/dev/null || true
''')
      }
    }

    stage('⑦ 包内三重校验') {
      stages {
        stage('出包口径（isOpenGM 等 12 位开关）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path")"
"$BASH" .jenkins/lib/run_stage.sh --name "包内出包口径核验" \
  --group "包内校验" --slug cfg --timeout 300 \
  -- "$PY" scripts/verify_aab_release_config.py "$AAB" --expect "$TS_PROFILE"
''')
          }
        }
        stage('native 16KB / NDK（Play 硬门槛）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path")"
"$BASH" .jenkins/lib/run_stage.sh --name "native 16KB / NDK 体检" \
  --group "包内校验" --slug 16kb --timeout 300 \
  -- "$PY" scripts/verify_aab_native_16kb.py "$AAB"
''')
          }
        }
        stage('交付自检（含 googlesignin 必须在包内）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path")"
"$BASH" .jenkins/lib/run_stage.sh --name "交付自检" \
  --group "包内校验" --slug delivery --timeout 300 \
  -- "$PY" scripts/verify_apk_delivery.py "$AAB" --expect "$TS_PROFILE"
''')
          }
        }
      }
    }

    stage('⑧ 归档取证') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path" 2>/dev/null || true)"
echo "AAB: $AAB"
mkdir -p "$TS_RUN_DIR/artifacts"
for f in "$AAB.release.json" "$AAB.delivery.json"; do
  [[ -f "$f" ]] && cp "$f" "$TS_RUN_DIR/artifacts/" && echo "  已收取证：${f##*/}"
done
# 大包本体（450MB）不进 Jenkins 归档：它就在 apks/ 下，路径记进证据文件即可
{
  echo "AAB=$AAB"
  [[ -f "$AAB" ]] && echo "size=$(stat -f%z "$AAB")" && echo "md5=$(md5 -q "$AAB")"
} | tee "$TS_RUN_DIR/artifacts/artifact.txt"
''')
      }
    }

    stage('⑨ 上传 Google Play（需人工审批）') {
      when { expression { params.UPLOAD } }
      steps {
        script {
          def aab = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
cat "$TS_RUN_DIR/aab.path" 2>/dev/null || true
''').trim()

          // 闸门复核：与 aab_release.sh / play_upload.py 内的两层校验独立，这里是第三层，
          // 目的是把「为什么被拒」在审批之前就讲清楚，而不是等上传脚本报错。
          if (params.STATUS in ['completed', 'inProgress'] && !params.PUBLISH) {
            error("拒绝送审：STATUS=${params.STATUS} 等于「提交审核 / 上线」，必须同时勾选 PUBLISH 表示已获批准。"
                + "只想上传草稿请把 STATUS 保持为 draft。")
          }
          if (!aab) {
            error("找不到本次构建的 AAB（${env.TS_RUN_DIR}/aab.path 为空），无法上传。")
          }

          def msg = """即将上传到 Google Play，请确认：
  AAB      : ${aab}
  口径     : ${params.PROFILE}
  轨道     : ${params.TRACK}
  状态     : ${params.STATUS}${params.STATUS == 'draft' ? '（草稿，不会送审）' : '  🔴 会提交审核 / 上线'}
  送审旗标 : ${params.PUBLISH}
  更新说明 : ${params.NOTES ?: '（空）'}

确认无误请点「确认上传」；不想传点「中止」。"""
          input message: msg, ok: '确认上传'

          sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path")"

UPLOAD_ARGS=(--aab "$AAB" --track "$TS_TRACK" --status "$TS_STATUS" --yes)
[[ "$TS_TRACK" == "production" ]] && UPLOAD_ARGS+=(--allow-production-write)
if [[ "$TS_STATUS" == "completed" || "$TS_STATUS" == "inProgress" ]]; then
  UPLOAD_ARGS+=(--allow-publish)
fi
[[ -n "${TS_NOTES:-}" ]] && UPLOAD_ARGS+=(--release-notes "$TS_NOTES")

echo "→ scripts/play_upload.py ${UPLOAD_ARGS[*]}"
# Play 的 edits 全局排他：并发上传会把对方的 edit 判成 deleted（实测 85% 处 HTTP 400）。
"$BASH" .jenkins/lib/run_stage.sh --name "上传 Google Play" \
  --group "发布" --slug upload --timeout 5400 \
  -- "$BASH" .jenkins/lib/lock.sh --name play run \
       --who "$JOB_NAME #$BUILD_NUMBER" --timeout 1800 -- \
       "$PY" scripts/play_upload.py "${UPLOAD_ARGS[@]}"
''')
        }
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
