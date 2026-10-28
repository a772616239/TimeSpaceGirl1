/**@META
{
  "description": "**数值迭代优化**（货币化价值带域）：基线度量 → 旋钮寻优（坐标下降，每轮只保留更好的那组）→ 不变式校验 → 可选落表 → 交付导表/推表指引。默认**全程只读**：`PROMOTE=false` 时绝不会动 `data_execl/base_data`。真正的设计问题是「在 +N% 通胀预算内，价值带能推多陡、倒挂能压到多浅」，所以通胀是**硬约束**而不是可以拿陡度去换的权重（R7 就是拿收入换通胀，最后把两年数值空间烧掉）。🔴 没有任何可改进时脚本返回 4，job 标黄而不是红 —— 那是**结论**，不是失败。",
  "concurrent": false,
  "keep": [40, 30],
  "params": [
    {"name":"ROUNDS","type":"string","default":"4","description":"坐标下降轮数。每轮对 slope/band/cap/gap 各试 ±1 步、再翻 mono/cut，一轮约 9 个候选；4 轮约 3-4 分钟（每个候选要真跑一次全表回测）"},
    {"name":"MAX_INFL","type":"string","default":"0.05","description":"通胀预算：全表加权「抽/元」相对父本允许的涨幅。**硬约束**，超了直接判不可行。设 0 就是「只重排、不加总量」模式（会把高位离群件削下来补给低位）"},
    {"name":"SLOPE","type":"string","default":"","description":"价值带目标斜率起点（0.10 = 最高档要比最低档再甜 10%）。留空=沿用账本里上一轮的最优旋钮，让每轮在上一轮基础上继续；填 0 会从「现状即目标」重开"},
    {"name":"BAND_TOL","type":"string","default":"","description":"收敛带下沿（0.20 = 低于目标 20% 才算离群件、才补）。留空用脚本默认。太小吃券粒度会抖动，太大等于不收敛"},
    {"name":"CUT","type":"bool","default":true,"description":"允许削峰（只扣券，绝不扣钻石；且扣到「目标×(1+cap_tol)」为止）。关掉就只剩「加券」，通胀会更容易顶到预算上限"},
    {"name":"MONO","type":"bool","default":true,"description":"目标带是否做单调化（PAVA）。开 = 自动把凹陷档的目标抬到相邻档水平；关 = 保留档位原样，只收敛档内离散"},
    {"name":"PROMOTE","type":"bool","default":false,"description":"🔴 把本轮最优候选**写进** `data_execl/base_data/RechargeCommodityConfig.xlsx`（写前备份到工程外、写后自动复核，未达标项变多会**自动回滚**）。默认关：先看报告"},
    {"name":"PUSH","type":"bool","default":false,"description":"落表后把 xlsx 提交并 push 回当前分支。**必须 push 才能导表**：导表在独立 clone 里跑，会先 reset 到 origin。默认关，改完自己看一眼 diff 再推"},
    {"name":"REANCHOR","type":"bool","default":false,"description":"🔴 落表成功后把当前值立为累计通胀的**新基准**。默认关：累计上限是跨轮粘住的（首次基线 +25%），不自动重置，否则每落一次表就再送 25% 复利空间。只有你对着设计复核、确认这一版就是新起点时才勾"},
    {"name":"TRIGGER_SYNC","type":"bool","default":false,"description":"落表后触发 `TS-Table-Sync`（`MODE=plan`：只体检不写服务端）。🔴 **必须同时勾 PUSH**：导表在独立 clone 里跑、先 reset 到 origin，没 push 会导成旧表（零报错假成功）⇒ 不勾 PUSH 时这一步直接判红。它**不会**替你推线上；要真生效还得去那个 job 里选 apply + 按需 RESTART"},
    {"name":"NOTE","type":"text","default":"","description":"本轮备注，写进账本（`data_execl/numeric_opt/ledger.jsonl`）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 45, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '90', numToKeepStr: '50'))
  }

  environment {
    // 用开发目录：data_execl/base_data 是配置表真源，_output/numeric_opt 是候选产物。
    // 不用打包 clone —— 那边每轮 reset --hard，候选和账本会被冲掉。
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 取证与前提声明') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.NO_RUN_ID   = "opt-${env.BUILD_NUMBER}-${BUILD_ID}"
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs" "$TS_RUN_DIR/artifacts"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "轮数：$ROUNDS   通胀预算：+$MAX_INFL   起点 slope：${SLOPE:-（沿用账本）}"
  echo "削峰：$CUT   单调化：$MONO   落表：$PROMOTE   push：$PUSH   触发同步：$TRIGGER_SYNC   重置锚点：${REANCHOR:-false}"
  echo ""
  echo "🔴 这个 job 优化的是什么（不是「再全表 +20%」）："
  echo "   在固定的通胀预算内，把「买得越多单位越值」这条价值带推陡，"
  echo "   同时收敛档内离散、压掉同族倒挂。收益是结构改善，不是总量放水。"
  echo ""
  echo "🔴 通胀是硬约束，不是权重：超预算的候选直接判不可行。"
  echo "   软权重会让「陡度 +20% 换通胀 +9%」看起来划算，那正是 R7 烧掉"
  echo "   两年数值空间的错觉（同一分钱收入，代价翻倍）。"
  echo ""
  echo "🔴 前提没有变：生产库 209 玩家、无充值流水 ⇒ 全部是同一口径下的相对比较，"
  echo "   不产出「预计月流水」。"
  echo ""
  echo "== 参与优化的表（只有这一张会被改）=="
  md5 -q data_execl/base_data/RechargeCommodityConfig.xlsx 2>/dev/null \
    | sed 's/^/   RechargeCommodityConfig.xlsx md5 = /'
  echo "   其余 8 张表只读（计费点/基金/活动轨道/招财猫/月卡/商店/战令）"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('② 基线度量（8 目标 + 分档中位）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 只读：跑的是父本（工作区），改不动任何东西。rc=1 也可能是「有目标没达成」，
# 那由 ③ 去优化，不该在这里判红 ⇒ --warn-ok。
"$BASH" .jenkins/lib/run_stage.sh --name "基线度量" \
  --group "数值" --slug num-measure --timeout 600 --warn-ok \
  -- "$PY" scripts/numeric_optimize.py measure \
       --json "$TS_RUN_DIR/artifacts/baseline.json"
cp -f "$TS_RUN_DIR/artifacts/baseline.json" "$TS_RUN_DIR/artifacts/" 2>/dev/null || true
''')
      }
    }

    stage('③ 迭代寻优（坐标下降）') {
      steps {
        script {
          // 闸门脚本的细节走 stderr（进构建日志），stdout 只留一个单词给 Jenkins 判断。
          def mode = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || { echo FAIL; exit 0; }
ARGS=(search --rounds "$ROUNDS" --run-id "$NO_RUN_ID" --max-infl "$MAX_INFL")
[[ -n "${SLOPE:-}" ]] && ARGS+=(--slope "$SLOPE")
[[ -n "${BAND_TOL:-}" ]] && ARGS+=(--band-tol "$BAND_TOL")
[[ "${CUT,,}"   == "true" ]] || ARGS+=(--cut false)
[[ "${MONO,,}"  == "true" ]] || ARGS+=(--mono false)
[[ -n "${NOTE:-}" ]] && ARGS+=(--note "$NOTE")
echo "→ numeric_optimize.py ${ARGS[*]}" >&2
"$BASH" .jenkins/lib/lock.sh --name numeric run --who "$JOB_NAME #$BUILD_NUMBER" \
  --timeout 1800 -- "$PY" scripts/numeric_optimize.py "${ARGS[@]}" \
  > "$TS_RUN_DIR/logs/search.txt" 2>&1
rc=$?
# 完整输出进构建日志（人要看每一轮试了什么），stdout 只留判断词
cat "$TS_RUN_DIR/logs/search.txt" >&2
if [[ $rc -eq 4 ]]; then echo NOIMP; exit 0; fi
if [[ $rc -ne 0 ]]; then echo FAIL; exit 0; fi
echo RUN
''').trim()
          env.OPT_MODE = mode
          if (mode == 'FAIL') {
            error('迭代寻优执行失败，见日志（常见原因：表被占用 / openpyxl 缺失 / 沙箱拦了批量删除）')
          }
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
RUN_DIR="_output/numeric_opt/${NO_RUN_ID}"
if [[ -d "$RUN_DIR" ]]; then
  cp -f "$RUN_DIR/report.md"    "$TS_RUN_DIR/artifacts/" 2>/dev/null || true
  cp -f "$RUN_DIR/metrics.json" "$TS_RUN_DIR/artifacts/" 2>/dev/null || true
  [[ -d "$RUN_DIR/best" ]] && cp -R "$RUN_DIR/best" "$TS_RUN_DIR/artifacts/best" 2>/dev/null || true
fi
echo "== 本轮报告（前 60 行）=="
sed -n '1,60p' "$TS_RUN_DIR/artifacts/report.md" 2>/dev/null || echo "（没有 report.md）"
''')
      }
    }

    stage('④ 候选体检（不变式校验，不写表）') {
      when { expression { env.OPT_MODE == 'RUN' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# promote 不带 --apply = 纯体检：逐行逐列比对候选与当前表，
# 只允许 BaseReward / RewardShow 变、只允许券数变。
# 这一关过不去就不许落表（价格/钻石/非券道具/门控 一个都不许动）。
"$BASH" .jenkins/lib/run_stage.sh --name "不变式校验（价格/钻石/非券道具）" \
  --group "数值" --slug num-invariant --timeout 300 \
  -- "$PY" scripts/numeric_optimize.py promote --run "$NO_RUN_ID"
''')
      }
    }

    stage('⑤ 落表（可选）') {
      when { expression { env.OPT_MODE == 'RUN' && params.PROMOTE } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# --apply：先备份到工程外，写后重新度量，未达标项变多就自动回滚。
# --reanchor 只在人显式勾了「这一版当新基准」时才带：累计通胀上限跨轮粘住，
# 落表本身绝不重置它（否则每落一次表就再送 25% 复利空间）。
PARGS=(--run "$NO_RUN_ID" --apply)
[[ "${REANCHOR:-false}" == "true" ]] && PARGS+=(--reanchor)
"$BASH" .jenkins/lib/run_stage.sh --name "落表（备份+复核+自动回滚）" \
  --group "数值" --slug num-promote --timeout 600 \
  -- "$PY" scripts/numeric_optimize.py promote "${PARGS[@]}"

echo "== 工作区改动 =="
git status --porcelain -- data_execl/base_data || true
git diff --stat -- data_execl/base_data || true

if [[ "${PUSH,,}" == "true" ]]; then
  BR="$(git rev-parse --abbrev-ref HEAD)"
  # 只提交这一张表：并行会话共享工作区，git add -A 会把别人的改动带走。
  git add data_execl/base_data/RechargeCommodityConfig.xlsx
  git commit -m "chore(数值): 迭代优化落表 ${NO_RUN_ID}" || echo "（没有可提交的改动）"
  git push origin "$BR"
  echo "已 push 到 $BR —— 导表要在打包 clone 里跑，不 push 它会 reset 掉。"
else
  echo "🔴 没有 push。导表在独立 clone 里跑（先 reset 到 origin），"
  echo "   不 push 的话导出来还是旧值。确认 diff 后勾 PUSH 重跑本 job。"
fi
''')
      }
    }

    stage('⑥ 触发导表体检（可选）') {
      when { expression { env.OPT_MODE == 'RUN' && params.PROMOTE && params.TRIGGER_SYNC } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
# 🔴 没 push 就不许触发：TS-Table-Sync 的导表在独立 clone 里跑，第一步就是
# 向 origin/<分支> reset --hard。没 push 的话它导的是**旧表** —— 全程零报错、
# 结果什么都没变，比报错难查得多。所以这里直接判红，不给你一个假成功。
if [[ "${PUSH:-false}" != "true" ]]; then
  echo "🔴 勾了 TRIGGER_SYNC 但没勾 PUSH，已中止。"
  echo "   导表在独立 clone 里跑，会先 reset --hard 到 origin；"
  echo "   没 push 它导出的是旧表（看起来成功、实际没生效）。"
  echo "   → 要么勾 PUSH 重跑，要么手动去 TS-Table-Sync 里自己跑。"
  exit 1
fi
echo "前置检查通过：改动已 push，导表能读到新表。"
''')
        script {
          // 只触 MODE=plan：体检「会推什么」，绝不动服务端。真推要人去那个 job 里
          // 选 apply，RESTART（会踢线）也要人在维护窗口决定 —— 本 job 不替你拍。
          build job: 'TS-Table-Sync',
                parameters: [string(name: 'MODE', value: 'plan'),
                             booleanParam(name: 'EXPORT', value: true)],
                wait: false
          env.SYNC_FIRED = 'true'
          echo "已触发 TS-Table-Sync（MODE=plan，不等待）。它要跑 Unity 导表约 4 分钟，去那个 job 看结果。"
        }
      }
    }

    stage('⑦ 交付：导表与推表指引') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
{
  echo "== 落表之后还要做什么（表改完是「死的」）=="
  echo "1) 导表：TS-Table-Sync（EXPORT=true）——xlsx → 客户端 Lua + 服务端 txt"
  echo "   或 TS-Resource-Build（EXPORT_TABLES=true），两者都要求改动已 commit+push。"
  echo "2) 推服务端：TS-Table-Sync（MODE=apply + 按需 RESTART）。"
  echo "   🔴 RESTART 会踢线，线上要在维护窗口做，本 job 不替你做。"
  echo "3) 客户端表随 AB/git 走，重新出包才生效。"
  if [[ "${SYNC_FIRED:-false}" == "true" ]]; then
    echo "   （本轮已按 TRIGGER_SYNC 触发 TS-Table-Sync MODE=plan，去那个 job 看体检结论）"
  fi
  echo
  echo "== 账本（最近 8 轮）=="
  "$PY" scripts/numeric_optimize.py ledger --n 8 || true
} | tee "$TS_RUN_DIR/artifacts/next-steps.txt"
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "交付指引" --group "交付" --status pass \
  --detail "已写出 next-steps.txt 与账本"
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
if [[ "${OPT_MODE:-}" == "NOIMP" ]]; then
  echo "无可改进（现状已在通胀预算内接近最优）"
  exit 0
fi
"$PY" .jenkins/lib/stage_report.py desc --run "$TS_RUN_DIR" 2>/dev/null || true
''').trim()
        if (desc) { currentBuild.description = desc }

        def st = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
if [[ "${OPT_MODE:-}" == "NOIMP" ]]; then echo warn; exit 0; fi
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
