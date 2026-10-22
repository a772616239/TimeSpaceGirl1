/**@META
{
  "description": "**服务端全量接口测试**：把 proto 里每一个 *_REQUEST（当前 372 个）都真发一遍，逐个判定「接口在不在、进没进 handler、有没有把服务端搞崩」。判定 oracle 是**服务端日志**而不是回包号——因为错误回包用的是 lastMsgId+1，未注册 handler 时回包号完全对不上（实测 10016 的回包是 10009），按回包认领必然错判。判红只有一种：日志明确 `request unknow commond`（proto 声明了、服务端没 handler）。每个接口一条 JUnit 用例（有趋势），另出 HTML 看板。TS-Server-Release 打完包会自动异步触发本 job。",
  "concurrent": false,
  "keep": [60, 80],
  "artifactKeep": 12,
  "artifactDays": 30,
  "params": [
    {"name":"TARGET","type":"choice","choices":["现网-129.226.213.65","本地自测服-127.0.0.1"],"default":"现网-129.226.213.65","description":"扫哪个服。地址表在 scripts/verify/api_targets.json（改地址只改那里）"},
    {"name":"SCOPE","type":"choice","choices":["全量","只读","核心"],"default":"全量","description":"全量=372 个 *_REQUEST 全扫（约 6~9 分钟）；只读=保守筛出的不写库接口（约 1 分钟）；核心=登录后主界面必需的那 11 个（约 30 秒，随时可点）"},
    {"name":"UID","type":"string","default":"","description":"🔴 用哪个号发请求。留空 = 取 api_targets.json 里的 uid_hint（现网 10000004）。**必须是专用测试号**：请求都发空 payload，但少数接口用默认值也会成功（签到/领奖之类），会改这个号的数据"},
    {"name":"TIMEOUT","type":"string","default":"1.5","description":"单接口等回包的超时（秒）。正常接口 200ms 内就回；不回的要等满这个值，所以它直接决定整轮时长"},
    {"name":"BUDGET","type":"string","default":"900","description":"整轮总预算（秒）。超了就中断并把剩下的记成未扫，避免一个卡住的接口把构建挂死"},
    {"name":"ONLY","type":"string","default":"","description":"只扫这些接口（协议名或协议号，逗号分隔），排查单个接口时用"},
    {"name":"SKIP","type":"string","default":"","description":"跳过这些接口（协议名或协议号，逗号分隔）。危险接口临时排除用"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 45, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '60', numToKeepStr: '80'))
  }

  environment {
    PROJ   = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY     = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH   = '/usr/local/bin/bash'
    SHARED = '/Users/wangxufeng/Documents/jenkins-shared'
    SWEEP  = 'scripts/verify/api_full_sweep.py'
  }

  stages {

    stage('① 参数与影响说明') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.STAGE_RUN_DIR      = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.TS_RUN_DIR         = env.STAGE_RUN_DIR
          env.API_STATE          = "${env.STAGE_RUN_DIR}/api/state.json"
          env.API_UID            = params.UID.trim()
          env.API_ONLY           = params.ONLY.trim()
          env.API_SKIP           = params.SKIP.trim()
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$STAGE_RUN_DIR/api" "$STAGE_RUN_DIR/logs"
{
  echo "运行       ：$JOB_NAME #$BUILD_NUMBER"
  echo "时间       ：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "目标       ：$TARGET"
  echo "档位       ：$SCOPE"
  echo "测试号     ：${API_UID:-（用目标表里的 uid_hint）}"
  echo "单接口超时 ：${TIMEOUT}s   总预算：${BUDGET}s"
  echo "收窄       ：ONLY='${API_ONLY}' SKIP='${API_SKIP}'"
  echo "工程       ：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "证据目录   ：$STAGE_RUN_DIR"
} | tee "$STAGE_RUN_DIR/context.txt"
cat <<'EOS'

  ============================================================================
   口径：每个接口发**空 payload**（参数全缺），验证「接口在、进得了 handler、
   不崩服务端」。判红只有一种：服务端日志明确 request unknow commond（该协议号
   没有 handler）。biz-reject / 执行未回包 / 静默早退都是空参数下的正常表现。

   🔴 会改数据：少数接口用默认值也能成功（签到/领奖之类），所以**只能拿专用测试号**
      跑。用真人号 = 直接把那个号的数据改掉。
   🔴 会顶号：登录会建立会话，该号若在线会被顶下线。
  ============================================================================

EOS
''')
      }
    }

    stage('② 环境预检（端口 / token / 登录 / 进程基线）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
ARGS=(--state "$API_STATE" --target "$TARGET" --scope "$SCOPE")
[[ -n "${API_UID:-}" ]] && ARGS+=(--uid "$API_UID")
[[ -n "${API_ONLY:-}" ]] && ARGS+=(--only "$API_ONLY")
[[ -n "${API_SKIP:-}" ]] && ARGS+=(--skip "$API_SKIP")
"$BASH" "$SHARED/lib/run_stage.sh" --name "环境预检（端口/token/登录/进程基线）" \
  --group "预检" --slug api-preflight --timeout 300 \
  -- "$PY" "$SWEEP" preflight "${ARGS[@]}"
''')
      }
    }

    stage('③ 全量接口扫描') {
      options { timeout(time: 30, unit: 'MINUTES') }
      steps {
        script {
          // catchError：扫描红了（有接口没 handler）也必须往下跑完 ④⑤，
          // 否则最需要看的报告和趋势反而不生成 —— 测试 job 的第一职责是出证据。
          catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
ARGS=(--state "$API_STATE" --target "$TARGET" --scope "$SCOPE"
      --timeout "$TIMEOUT" --budget "$BUDGET")
[[ -n "${API_UID:-}" ]] && ARGS+=(--uid "$API_UID")
[[ -n "${API_ONLY:-}" ]] && ARGS+=(--only "$API_ONLY")
[[ -n "${API_SKIP:-}" ]] && ARGS+=(--skip "$API_SKIP")
# --warn-rc 3：只有「关注项」时不该把整轮判红（与其它 job 同口径）
"$BASH" "$SHARED/lib/run_stage.sh" --name "全量接口扫描（$SCOPE 档）" \
  --group "接口" --slug api-sweep --timeout 1800 --warn-rc 3 \
  -- "$PY" "$SWEEP" sweep "${ARGS[@]}"
''')
          }
        }
      }
    }

    stage('④ 存活复核（新连接 / 心跳 / 进程未重启）') {
      steps {
        script {
          // 扫描可能已经把服务端搞挂 —— 这一步就是专门证明「没搞挂」的，
          // 所以不管 ③ 红绿都要跑。
          catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
ARGS=(--state "$API_STATE" --target "$TARGET" --scope "$SCOPE")
[[ -n "${API_UID:-}" ]] && ARGS+=(--uid "$API_UID")
"$BASH" "$SHARED/lib/run_stage.sh" --name "存活复核（新连接/心跳/进程未重启）" \
  --group "复核" --slug api-postcheck --timeout 300 \
  -- "$PY" "$SWEEP" postcheck "${ARGS[@]}"
''')
          }
        }
      }
    }

    stage('⑤ 报告（JUnit + 看板）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$STAGE_RUN_DIR/api"

# 每个接口一条 JUnit 用例：Jenkins 的「测试结果趋势」才看得出「这个接口是哪一版坏的」。
# CHECK 行来自各阶段日志（run_stage 会 tee 到 logs/<slug>.log），去重后再转。
grep -h '^CHECK|' "$STAGE_RUN_DIR"/logs/*.log 2>/dev/null | awk '!seen[$0]++' \
  > "$STAGE_RUN_DIR/api/checks.txt" || true
CHECKS=$(grep -c '^CHECK|' "$STAGE_RUN_DIR/api/checks.txt" 2>/dev/null || echo 0)
echo "收集到 $CHECKS 条断言"
# rc=2 = 没有断言（不写空文件，避免把趋势图冲成 0）——只提示，不判红
"$PY" "$SHARED/lib/checks_to_junit.py" --checks "$STAGE_RUN_DIR/api/checks.txt" \
  --out "$STAGE_RUN_DIR/api/junit.xml" --suite "$JOB_NAME" || true

"$PY" "$SWEEP" report --state "$API_STATE" --html "$STAGE_RUN_DIR/api/report.html"

# 固定地址：方便收藏/回看最近一次（与 TS-Server-Release / TestPackage 同一套路）
mkdir -p "$HOME/.jenkins/userContent"
cp -f "$STAGE_RUN_DIR/api/report.html" \
      "$HOME/.jenkins/userContent/TS-Api-Test-latest.html" 2>/dev/null || true
echo "看板固定地址：http://localhost:8080/userContent/TS-Api-Test-latest.html"

"$PY" "$SHARED/lib/stage_report.py" add --run "$STAGE_RUN_DIR" \
  --name "报告归档" --group "交付" --status pass \
  --detail "断言 $CHECKS 条 · 看板 api/report.html"
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
# ① 阶段就炸掉时 STAGE_RUN_DIR 还没设，别让 post 再炸一次（那会把真实原因盖掉）
[[ -n "${STAGE_RUN_DIR:-}" ]] || exit 0
mkdir -p "$STAGE_RUN_DIR/logs"
"$PY" "$SHARED/lib/stage_report.py" junit --run "$STAGE_RUN_DIR" \
  --out "$STAGE_RUN_DIR/junit.xml" --suite "$JOB_NAME" || true
"$PY" "$SHARED/lib/stage_report.py" summary --run "$STAGE_RUN_DIR" \
  --out "$STAGE_RUN_DIR/summary.md" --title "$JOB_NAME #$BUILD_NUMBER" || true
# workspace 不做 cleanWs，cp -R 只增不删 ⇒ 上次的 stages/*.json 会混进来
if [[ -n "${WORKSPACE:-}" && -d "$WORKSPACE/evidence" ]]; then
  rm -rf "$WORKSPACE/evidence"
fi
mkdir -p "$WORKSPACE/evidence"
cp -R "$STAGE_RUN_DIR/." "$WORKSPACE/evidence/" 2>/dev/null || true
''')

        // 环节表 + 逐接口用例：两个文件都发，前者回答「哪一步红了」，后者回答「哪个接口坏了」
        if (fileExists("${WORKSPACE}/evidence/api/junit.xml")) {
          junit allowEmptyResults: true, skipPublishingChecks: true,
            testResults: 'evidence/junit.xml,evidence/api/junit.xml'
        } else if (fileExists("${WORKSPACE}/evidence/junit.xml")) {
          junit allowEmptyResults: true, skipPublishingChecks: true,
            testResults: 'evidence/junit.xml'
        }

        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" "$SHARED/lib/stage_report.py" desc --run "$STAGE_RUN_DIR" 2>/dev/null || true
SUM="$(grep '^CHECK|扫描-汇总' "$STAGE_RUN_DIR/api/checks.txt" 2>/dev/null | head -1 || true)"
if [[ -n "$SUM" ]]; then
  printf ' · %s' "$(printf '%s' "$SUM" | cut -d'|' -f4)"
fi
''').trim()
        if (desc) { currentBuild.description = "${desc} · ${params.SCOPE} · ${params.TARGET}" }

        def st = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" "$SHARED/lib/stage_report.py" status --run "$STAGE_RUN_DIR" 2>/dev/null || echo pass
''').trim()
        if (st == 'warn' && currentBuild.currentResult == 'SUCCESS') {
          currentBuild.result = 'UNSTABLE'
        }

        archiveArtifacts allowEmptyArchive: true,
          artifacts: 'evidence/api/**,evidence/summary.md,evidence/context.txt,evidence/logs/**',
          fingerprint: false
      }
    }
  }
}
