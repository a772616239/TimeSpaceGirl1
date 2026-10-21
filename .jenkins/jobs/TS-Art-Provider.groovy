/**@META
{
  "description": "出图账号「换浏览器 / 换号」与额度台账（只读状态 + 一键切到下一个可用号）。台账记的是**额度什么时候恢复**，不是「今天空过」：还没到恢复时间的号下一轮直接不排队，用完一个就切下一个，不再每次都从第一个号开始重试（实测一轮白烧 9 分钟）。status=看台账与实时浏览器；pick=只算顺序不启动；switch=真的开/接下一个号并打印 CDP_PORT；reset=解封；check=台账自检（解析器 + 排序判据）。",
  "concurrent": false,
  "params": [
    {"name":"ACTION","type":"choice","choices":["status","pick","switch","chrome","reset","check"],"default":"status","description":"status=台账+实时浏览器（只读）；pick=按台账算候选顺序但不启动任何浏览器；switch=真的切到下一个可用的 AdsPower 号（会启动 profile）并打印 CDP_PORT；chrome=切到本机 Google Chrome 通道（不填 CDP_PORT 的那条）；reset=清掉封锁（RESET_ID）；check=台账自检"},
    {"name":"PROFILES","type":"string","default":"","description":"显式换号顺序（逗号分隔的 AdsPower user_id，如 ktmrjhu,kvrvx5h）：排最前，不受自动排序影响。留空=按台账+上次成功+cookie 数自动排。🔴 号池有 6 个但换号链默认只看 3 个——要全试就把 6 个都写进来"},
    {"name":"MAX_OPEN","type":"string","default":"1","description":"最多同时给出几个候选（默认 1）。switch 时只切第一个成功的，后面的等下一次"},
    {"name":"FORCE","type":"boolean","default":false,"description":"无视台账封锁（只在「就是要验某个号的额度」时开）。默认跳过还没到恢复时间的号"},
    {"name":"STOP_WHEN_DONE","type":"boolean","default":false,"description":"切成功后就把它关掉。默认**留着**：下次出图任务直接接入这个窗口，不用再等一次启动"},
    {"name":"RESET_ID","type":"string","default":"all","description":"ACTION=reset 时清哪个号：AdsPower user_id，或 all=全部解封"},
    {"name":"CHROME_PROFILE","type":"string","default":"Profile 5","description":"本机 Google Chrome 的 profile 名（台账里记作 chrome:<名字>）。它和 AdsPower 号一起参与「下一个用谁」"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 10, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '60', numToKeepStr: '80'))
  }

  environment {
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 上下文与台账') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.LEDGER_ACTION = (params.ACTION ?: 'status').toString()
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs" "$TS_RUN_DIR/artifacts"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "动作：$LEDGER_ACTION   显式号序：${PROFILES:-（自动）}   最多候选：${MAX_OPEN:-1}   忽略封锁：${FORCE:-false}"
  echo ""
  echo "为什么有这个 job：ChatGPT 出图额度按账号算，一个号画完就得换下一个。"
  echo "旧口径只记「哪天空过」、而且只降权不排除 ⇒ 每个任务都要拿同一个空号从头撞一遍，"
  echo "实测一轮 3 个号轮流「额度已用尽」白烧 9 分钟。现在记的是**什么时候恢复**。"
} | tee "$TS_RUN_DIR/context.txt"

# 台账快照（不论动作是什么，都先把「进来时长什么样」留证）
"$PY" scripts/image/provider_ledger.py list --json > "$TS_RUN_DIR/artifacts/ledger_before.json" 2>/dev/null || true
''')
      }
    }

    stage('② 执行动作') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
LOG="$TS_RUN_DIR/logs/provider.log"
EXTRA=""
[[ "${PROFILES:-}" != "" ]] && EXTRA="$EXTRA --profiles ${PROFILES}"
[[ "${FORCE:-false}" == "true" ]] && EXTRA="$EXTRA --force"

case "$LEDGER_ACTION" in
  status)
    "$BASH" .jenkins/lib/run_stage.sh --name "台账与实时浏览器" \
      --group "出图账号" --slug provider-status --timeout 180 --warn-rc 3 \
      -- "$PY" scripts/image/provider_ledger.py list --live 2>&1 | tee "$LOG"
    ;;
  pick)
    "$BASH" .jenkins/lib/run_stage.sh --name "候选排序（不启动）" \
      --group "出图账号" --slug provider-pick --timeout 120 --warn-rc 3 \
      -- "$PY" scripts/image/provider_ledger.py pick --max "${MAX_OPEN:-1}" $EXTRA 2>&1 | tee "$LOG"
    ;;
  switch)
    # rc=3 = 全世界的号都在封锁期/AdsPower 没开 ⇒ 标黄，不是流水线坏了
    "$BASH" .jenkins/lib/run_stage.sh --name "切到下一个可用号" \
      --group "出图账号" --slug provider-switch --timeout 300 --warn-rc 3 \
      -- "$PY" scripts/image/provider_ledger.py switch --max "${MAX_OPEN:-1}" \
           $( [[ "${STOP_WHEN_DONE:-false}" == "true" ]] && echo --stop-when-done ) $EXTRA \
      2>&1 | tee "$LOG"
    ;;
  chrome)
    # 本机 Google Chrome 那条通道：不启动任何东西，只判「它还有没有额度」并给出命令
    "$BASH" .jenkins/lib/run_stage.sh --name "切到本机 Chrome 通道" \
      --group "出图账号" --slug provider-chrome --timeout 60 --warn-rc 3 \
      -- "$PY" scripts/image/provider_ledger.py use-chrome \
           --profile "${CHROME_PROFILE:-Profile 5}" \
           $( [[ "${FORCE:-false}" == "true" ]] && echo --force ) \
      2>&1 | tee "$LOG"
    ;;
  reset)
    "$BASH" .jenkins/lib/run_stage.sh --name "解封账号" \
      --group "出图账号" --slug provider-reset --timeout 60 --warn-rc 3 \
      -- "$PY" scripts/image/provider_ledger.py reset \
           $( [[ "${RESET_ID:-all}" == "all" ]] && echo --all || echo "--id ${RESET_ID}" ) \
      2>&1 | tee "$LOG"
    ;;
  check)
    "$BASH" .jenkins/lib/run_stage.sh --name "台账自检" \
      --group "出图账号" --slug provider-check --timeout 120 \
      -- "$PY" scripts/image/provider_ledger.py check 2>&1 | tee "$LOG"
    ;;
  *)
    echo "未知动作：$LEDGER_ACTION"; exit 2 ;;
esac
''')
      }
    }

    stage('③ 结论与下一步') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$PY" scripts/image/provider_ledger.py list --json > "$TS_RUN_DIR/artifacts/ledger_after.json" 2>/dev/null || true
"$PY" scripts/image/provider_ledger.py list > "$TS_RUN_DIR/artifacts/ledger_after.txt" 2>/dev/null || true

# 把 switch 打印的 CDP_PORT 抠出来，拼一条可以直接粘进 TS-Art-Restyle 的参数
PORT=$(grep -oE 'CDP_PORT=[0-9]+' "$TS_RUN_DIR/logs/provider.log" 2>/dev/null | tail -1 | cut -d= -f2 || true)
CHROME=$(grep -E '^CHROME_PROFILE=' "$TS_RUN_DIR/logs/provider.log" 2>/dev/null | tail -1 | cut -d= -f2- | sed 's/[[:space:]]*$//' || true)
SQ="'"
{
  echo "## 台账（本次动作后）"
  echo '```'
  cat "$TS_RUN_DIR/artifacts/ledger_after.txt" 2>/dev/null || echo "(读不到)"
  echo '```'
  if [[ -n "$PORT" ]]; then
    echo ""
    echo "## 下一个出图任务直接用这个号"
    echo '```'
    echo "TS-Art-Restyle：CDP_PORT=$PORT"
    echo "# 或者命令行："
    echo "$PY scripts/image/gen_chatgpt_web.py --image <图> --prompt-file <提示词> --out <输出> \\\\"
    echo "     --reuse-cdp --port $PORT"
    echo '```'
  elif [[ -n "$CHROME" ]]; then
    echo ""
    echo "## 下一个出图任务走本机 Google Chrome"
    echo '```'
    echo "TS-Art-Restyle：CDP_PORT 留空即可（默认就用本机 Chrome 的 $CHROME）"
    echo "$PY scripts/image/gen_chatgpt_web.py --image <图> --prompt-file <提示词> --out <输出> --profile ${SQ}${CHROME}${SQ}"
    echo '```'
  else
    echo ""
    echo "（本次没有切换浏览器：status/pick/check 都不启动任何窗口）"
  fi
} > "$TS_RUN_DIR/artifacts/NEXT_STEPS.md"

"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "结论与下一步" --group "交付" --status pass \
  --detail "台账快照与下一步参数已归档"
cat "$TS_RUN_DIR/artifacts/NEXT_STEPS.md"
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
if [[ -n "${WORKSPACE:-}" && -d "$WORKSPACE/evidence" ]]; then rm -rf "$WORKSPACE/evidence"; fi
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
        if (desc) { currentBuild.description = "${params.ACTION} · ${desc}".toString() }

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
