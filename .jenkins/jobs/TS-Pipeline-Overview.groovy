/**@META
{
  "description": "全流程只读总览：把「客户端资源 / 打包环境 / 仓库卫生 / 送审闸门 / 生产服 / 10002 区服 / Play 轨道」一次看完。每个环节都是独立的只读脚本，失败不互相阻断，一次运行拿到全部结论。想动手做什么请用 TS-Android-Release / TS-Server-Ops。",
  "concurrent": true,
  "params": [
    {"name":"SKIP_PLAY","type":"bool","default":false,"description":"跳过「Play 轨道与 16KB」环节。该环节会占用 Play API 排他锁（探不过会自动跳过，不会失败）"},
    {"name":"SKIP_HEALTH","type":"bool","default":false,"description":"跳过「生产服只读巡检」环节（离线 / 不想连生产时勾上）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 25, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '80'))
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
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "触发：${BUILD_CAUSE:-（无 build-user-vars 插件，未记录原因）}"
  echo "用户：${BUILD_USER_ID:-（无 build-user-vars 插件，未记录用户）}"
  echo "构建：${BUILD_TAG:-?} · ${BUILD_URL:-?}"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "主机：$(hostname) · $(sw_vers -productVersion 2>/dev/null || uname -sr)"
  echo "工程：$PROJ"
  echo "分支：$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?') @ $(git rev-parse --short HEAD 2>/dev/null || echo '?')"
  echo "取证：$TS_RUN_DIR"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('② 客户端资源链') {
      stages {
        stage('Lua 源码 ↔ 字节码一致性') {
          steps {
            catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
              sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "Lua 源码↔字节码一致性" \
  --group "客户端资源链" --slug lua-bytes --timeout 600 \
  -- "$BASH" scripts/lua-bytes-sync.sh --check
''')
            }
          }
        }
        stage('AssetBundle 就绪体检') {
          steps {
            catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
              sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "AssetBundle 就绪体检" \
  --group "客户端资源链" --slug ab-ready --timeout 600 \
  -- "$BASH" scripts/check_ab_ready.sh
''')
            }
          }
        }
      }
    }

    stage('③ 打包环境与出包配置') {
      stages {
        stage('工具链 / Gradle 模板 / 签名') {
          steps {
            catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
              sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# rc=1 缺工具/模板被重置/缺 keystore = 真问题，必须红；
# rc=3 「环境就绪但本工程被 Unity 编辑器占用」= 临时状态，总览只标黄（打包 job 里它就是硬阻塞）。
"$BASH" .jenkins/lib/run_stage.sh --name "打包环境预检" \
  --group "打包环境" --slug android-env --timeout 300 --warn-rc 3 \
  -- "$BASH" .jenkins/lib/checks/android_env.sh
''')
            }
          }
        }
      }
    }

    stage('④ 仓库卫生') {
      stages {
        stage('Lua 字节码成对性（硬闸门）') {
          steps {
            catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
              sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "仓库卫生与 Lua 成对性" \
  --group "仓库卫生" --slug hygiene --timeout 600 \
  -- "$BASH" .jenkins/lib/checks/repo_hygiene.sh
''')
            }
          }
        }
      }
    }

    stage('⑤ 送审闸门完好性') {
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "送审闸门完好性" \
  --group "发布安全" --slug play-gate --timeout 300 \
  -- "$BASH" .jenkins/lib/checks/play_gate.sh
''')
        }
      }
    }

    stage('⑥ Play 轨道与 16KB') {
      when { expression { !params.SKIP_PLAY } }
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"

# Play 的 edits 是全局排他的：拿不到锁就「跳过」而不是失败 ——
# 总览是只读巡检，绝不该因为「正好有人在发版」而变红，更不该把上传挤掉。
"$PY" .jenkins/lib/lock.py --name play test >/dev/null 2>&1
if [[ $? -eq 75 ]]; then
  "$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
    --name "Play 轨道与 16KB 巡检" --group "Play" --status skip \
    --detail "Play API 正被占用（有上传/巡检在跑），本次跳过以免干扰"
  echo "⏭ Play API 被占用，跳过本环节（这是预期行为，不是失败）"
  exit 0
fi

"$BASH" .jenkins/lib/run_stage.sh --name "Play 轨道与 16KB 巡检" \
  --group "Play" --slug play-watch --timeout 900 \
  -- "$BASH" .jenkins/lib/lock.sh --name play run --who "$JOB_NAME #$BUILD_NUMBER" --timeout 600 -- \
     "$PY" scripts/play_16kb_watch.py --dry-run
''')
        }
      }
    }

    stage('⑦ 生产服只读巡检') {
      when { expression { !params.SKIP_HEALTH } }
      steps {
        catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
          sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "生产服只读巡检" \
  --group "服务端" --slug remote-health --timeout 600 \
  -- "$BASH" .jenkins/lib/checks/remote_health.sh
''')
        }
      }
    }

    stage('⑧ 本地 10002 区服') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 10002 是内测区服，没开是常态 ⇒ 用 --warn-ok：结论标「关注」，但不把总览变红
"$BASH" .jenkins/lib/run_stage.sh --name "本地 10002 区服状态" \
  --group "服务端" --slug local-shard --timeout 120 --warn-ok \
  -- "$BASH" .jenkins/lib/checks/local_shard.sh
''')
      }
    }

    stage('⑨ 汇总') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$PY" .jenkins/lib/stage_report.py summary --run "$TS_RUN_DIR" \
  --title "全流程只读总览（$JOB_NAME #$BUILD_NUMBER）"
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

        // 「通过但有需要关注」→ 黄球。黄球有信息量，全绿/全红都不足以表达。
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
