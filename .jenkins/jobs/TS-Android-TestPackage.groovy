/**@META
{
  "description": "出测试用 APK（universal，upload key 签名）：环境预检 → **按 SERVER_ENV 注入连服地址** → Unity batchmode → 包内四重校验（服务器环境/出包口径/16KB/交付）→ **把 APK 本体收成构建产物（构建页可直接下载安装）** → **发一封结果邮件（版本号 + 下载地址）**。**每天 03:00 自动跑一次夜间包**，代码同步环节无条件拉到 origin/release 最新。专为「我要拿个包装到手机上测」设计，不做任何上传（不传 Play）。侧载前必须先卸载 Play 版（签名不同）。",
  "cron": "0 3 * * *",
  "concurrent": false,
  "keep": [30, 30],
  "artifactKeep": 3,
  "artifactDays": 14,
  "params": [
    {"name":"SERVER_ENV","type":"choice","choices":["测试服","正式服","现网-129.226.213.65"],"default":"现网-129.226.213.65","description":"🔴 这个包连哪个服务器（地址表 scripts/build_envs.json：测试服=本机 127.0.0.1:8081 / 正式服=103.151.173.99 / 现网=历史包用的 129.226.213.65）。**默认现网=柯测试服**：夜里出的包早上直接装真机就能连，不用人守着起本机测试服。构建前注入 Assets/Resources/version.txt，EXIT 时（含失败）自动还原；打包后解包核验，不符则本环节失败。⚠️ 选「测试服」时包连 127.0.0.1，真机必须先 adb reverse tcp:8081 tcp:8081 与 tcp:16081 tcp:16081（构建日志会提示）"},
    {"name":"BUMP_VERSION","type":"bool","default":false,"description":"是否把 versionCode +1。测试包一般不用，保持与线上同号便于对照"},
    {"name":"EXPECT_PROFILE","type":"choice","choices":["minimal","release","dev","full"],"default":"minimal","description":"出包口径（**同时是构建口径**，2026-10-22 起下发为 --profile → TS_RELEASE_PROFILE）：minimal=测试包（关 GM，**保留全部日志**，默认）/ release=正式包（关 GM + 关日志）。打包后按同一值解包核验"},
    {"name":"SEND_MAIL","type":"bool","default":true,"description":"出完（或失败）发一封结果邮件：版本号 / 连服 / 下载地址（稳定地址 + 本次构建地址）/ 失败环节。夜间定时靠它把结果送到手上；手动跑不想收信就取消勾选"},
    {"name":"MAIL_TO","type":"string","default":"","description":"收件人（逗号分隔）。留空 = 共享库默认收件人（jenkins-shared/lib/notify.py 的 NOTIFY_TO，当前是 772616239@qq.com）"}
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
    // 🔴 打包目录 = 独立 clone（TimeSpaceGirl1-build）：开发目录开着 Unity 也能打包，
    //    同步靠 ①-1 的 ci_sync.sh（fetch + reset + 资产镜像），别把开发目录路径改回来。
    PROJ  = '/Users/wangxufeng/Documents/TimeSpaceGirl1-build'
    PY    = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH  = '/usr/local/bin/bash'
    UNITY = '/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity'
    // 发信器在共享库里（多候选授权码 / 465→587 / 失败分类重试只有这一份实现）
    SHARED = '/Users/wangxufeng/Documents/jenkins-shared'
  }

  stages {

    stage('① 准备与取证') {
      steps {
        script {
          // 显式声明工程根，别依赖共享库退回 $PWD（写清楚比靠默契稳）
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR    = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.TS_PROFILE    = params.EXPECT_PROFILE
          env.TS_SERVER_ENV = params.SERVER_ENV
          env.TS_BUMP       = params.BUMP_VERSION.toString()
          env.TS_MAIL_TO    = params.MAIL_TO.trim()
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
  echo "口径：$TS_PROFILE（测试包默认 minimal=保留日志；正式包走 release=关日志） 提版本号：$TS_BUMP"
  echo "出包环境：$TS_SERVER_ENV（连哪个服，见 scripts/build_envs.json）"
  echo "用途：出测试 APK（侧载前须先卸载 Play 版 —— 签名不同）"
  echo "定时：每天 03:00（cron 0 3 * * *）；本链路上传动作一律没有，不传 Play"
  echo "邮件：${TS_MAIL_TO:-共享库默认收件人}（SEND_MAIL 关掉则不发）"
  echo "取证：$TS_RUN_DIR"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('①-1 代码同步（打包目录 pull）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 打包目录无条件向 origin/<分支> 对齐：stash 快照本地残留 → reset --hard → 镜像 .secrets/服务端仓
"$BASH" .jenkins/lib/run_stage.sh --name "代码同步（fetch+reset+资产镜像）" \
  --group "同步" --slug ci-sync --timeout 1800 \
  -- "$BASH" .jenkins/ci_sync.sh
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
# 🔴 连服环境由 build_apk.sh 在 Unity 启动前注入、EXIT 时还原（测试服=本机 127.0.0.1）
ENV_ARGS=()
[[ -n "${TS_SERVER_ENV:-}" ]] && ENV_ARGS=(--server-env "$TS_SERVER_ENV")
# 🔴 口径：测试包默认 minimal（关 GM，**保留全部日志**，方便在真机上看 trace）。
#    ⚠️ build_apk.sh 自身默认是 release（关日志），所以这里必须显式下发，不能靠默认值。
PROFILE_ARGS=(--profile "${TS_PROFILE:-minimal}")
"$BASH" .jenkins/lib/build_apk.sh $BUMP_ARG "${ENV_ARGS[@]}" "${PROFILE_ARGS[@]}" --who "$JOB_NAME #$BUILD_NUMBER"
''')
      }
    }

    stage('④ 包内四重校验') {
      stages {
        stage('服务器环境（这个包连哪个服）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
APK="$(cat "$TS_RUN_DIR/apk.path")"
# 解包读 assets/Android/Resources/version.txt。测错环境的包比没有包更浪费时间：
# 装上去连不上/连到正式服才发现，所以这里做成硬闸门而不是提示。
# （bash 5 / set -u 下空数组展开安全；SERVER_ENV 留空时脚本只报告不判错）
ENV_ARGS=()
[[ -n "${TS_SERVER_ENV:-}" ]] && ENV_ARGS=(--expect-env "$TS_SERVER_ENV")
"$BASH" .jenkins/lib/run_stage.sh --name "服务器环境核验" \
  --group "包内校验" --slug server-env --timeout 300 \
  -- "$PY" scripts/verify_aab_server_env.py "$APK" "${ENV_ARGS[@]}"
''')
          }
        }
        stage('本机回环地址（这包发出去能不能连）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
APK="$(cat "$TS_RUN_DIR/apk.path")"
# ⚠️ 警告不是闸门：rc=3（回环地址）标黄不阻断——包能连哪里是口径问题，由人判断；
#   但 rc=1（包结构坏/读不到 version.txt）没有 --warn-ok 兜着，直接红灯。
"$BASH" .jenkins/lib/run_stage.sh --name "本机回环地址警告" \
  --group "包内校验" --slug loopback-warn --timeout 120 --warn-rc 3 \
  -- "$PY" scripts/verify_apk_loopback.py "$APK"
''')
          }
        }
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
  if [[ "${TS_SERVER_ENV:-}" == "测试服" ]]; then
    echo "ℹ️ 测试服口径 = http://192.168.3.82:8081/（局域网直连，无需 adb reverse），"
    echo "   真机需与本机同一局域网；并确认本机 start-local.sh status 里 8081/16081 都在 LISTEN。"
  fi
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

        // ⑥ 结果邮件 —— 故意放 post 而不是 stage：
        //    夜间包**失败时更**需要这封信（「没出包，因为 ③ 红了」），而 stage 在失败后会被 skip，
        //    只有 post.always 一定能跑到。主题/正文全部由 .jenkins/lib/notify_package.py
        //    从取证目录读事实拼出来（版本 / 连服 / 下载地址 / 失败环节），job 里不写措辞。
        if (params.SEND_MAIL) {
          script {
            // 定时还是手动：拿不到 cause 就按手动算，绝不能因为取 cause 失败而丢掉这封信
            def trig = '手动'
            try {
              if (currentBuild.getBuildCauses('hudson.triggers.TimerTrigger$TimerTriggerCause')) {
                trig = '定时'
              }
            } catch (ignored) { }
            env.TS_MAIL_RESULT  = currentBuild.currentResult
            env.TS_MAIL_TRIGGER = trig
            env.TS_MAIL_ENV     = params.SERVER_ENV

            def rc = sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" 2>/dev/null || true
TO_ARGS=()
[[ -n "${TS_MAIL_TO:-}" ]] && TO_ARGS=(--to "$TS_MAIL_TO")
DRY_ARGS=()
# 想先看正文不投递：TS_MAIL_DRYRUN=1（写进 job 环境或临时改一行都行）
[[ "${TS_MAIL_DRYRUN:-0}" == "1" ]] && DRY_ARGS=(--dry-run)
BR="$(git -C "$PROJ" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
[[ "$BR" == "HEAD" ]] && BR="release（detached）"
"$PY" .jenkins/lib/notify_package.py \
  --run-dir "$TS_RUN_DIR" --job "$JOB_NAME" --build "$BUILD_NUMBER" \
  --url "$BUILD_URL" --result "$TS_MAIL_RESULT" --env "$TS_MAIL_ENV" \
  --trigger "$TS_MAIL_TRIGGER" --branch "$BR" \
  "${TO_ARGS[@]}" "${DRY_ARGS[@]}"
''')
            // 发信失败不改球色：包已经出好了，红球会让人以为包不能用
            if (rc != 0) {
              echo "⚠️ 结果邮件没发出去（rc=${rc}）—— 包本身不受影响，原因见上一段输出"
            }
          }
        } else {
          echo "SEND_MAIL=false ⇒ 本次不发结果邮件"
        }
      }
    }
  }
}
