/**@META
{
  "description": "ASO 关键词周期（每 3 日）：**挖词打分出关键词策略 → 受控派生新变体文案 → 增量文案闸门 → 与历史轮次比对 → 可选写入 Play 并送审 → 快照 + A/B 窗口登记 + 记入账本**。默认全程只读：不勾 PUBLISH 绝不会碰线上。🔴 该包（com.Warera.timespace）是「提交即自动送审」模式，没有「写而不送审」的中间态，所以发布闸门用 PUBLISH=review + CONFIRM_PACKAGE 精确输入包名双确认。",
  "concurrent": false,
  "cron": "H 0,6,12,18 * * *",
  "keep": [40, 40],
  "params": [
    {"name":"CYCLE_DAYS","type":"string","default":"3","description":"周期天数。cron 每 6 小时探一次，闸门卡满 N×24h 才真跑 ⇒ 实际间隔 N 天 + 0~6h，比 Jenkins 的 */3 日字段可靠（后者跨月会抖成 1~3 天）"},
    {"name":"SITE","type":"string","default":"","description":"站点名：换到别的包时填 data_aso/sites/<SITE>（如 capybara）。留空 = 本工程主站点《时空美少女》。脚本侧只认 ASO_SITE，包名由该站点的 site.json 决定"},
    {"name":"FORCE","type":"bool","default":false,"description":"无视周期闸门立刻跑一轮（人工触发时用）"},
    {"name":"BASELINE","type":"string","default":"A","description":"实验对照基线。A = 线上历史快照，只记分不改它"},
    {"name":"PARENT","type":"string","default":"","description":"派生父本（真正被改的那一版）。留空=自动取最新 treatment（当前是 B）。🔴 不要填 A：A 自带 zh-TW 简体混排等已知缺陷，派生出来会继承一片红"},
    {"name":"LOCALES","type":"string","default":"","description":"语言子集：en,ja,zh-CN,zh-TW。留空=四语全做"},
    {"name":"EMIT","type":"bool","default":true,"description":"允许根据 rewrite_rules.json 派生新变体目录。规则未启用时不会产生任何变更（正常，rc=4）"},
    {"name":"FULLTEXT","type":"bool","default":false,"description":"🔴 把 data_aso/keywords/fulltext/<语言>.txt 整体写进变体长描述。长描述改一个词没用（线上只用了 14%~53% 字数），所以走「成品整体替换」，不做替换对。成品必须先通过体检（≤4000 字、字符集正确），否则脚本拒绝落盘"},
    {"name":"ELEMENT","type":"choice","choices":["copy","screenshots","feature","icon"],"default":"copy","description":"本轮动的元素。本 job 只改文案 ⇒ 保持 copy；一次只测一个元素，否则读不出是谁的效果"},
    {"name":"READOUT_DAYS","type":"string","default":"14","description":"A/B 读数窗口天数（≥7 天。3 天的节奏只用于推进，不够下结论）"},
    {"name":"IGNORE_EXP_WINDOW","type":"bool","default":false,"description":"🔴 无视「上一个实验还没到期」强行推进。会把两个变量混在一个窗口里，正常别勾"},
    {"name":"PUBLISH","type":"choice","choices":["none（只设计，不碰 Play）","review（写入线上并自动送审）"],"default":"none（只设计，不碰 Play）","description":"🔴 选 review 会真的提交到 Play 并立即进入审核队列（该包不支持「写而不送审」）"},
    {"name":"CONFIRM_PACKAGE","type":"string","default":"","description":"选择 review 时必须精确输入包名 com.Warera.timespace，否则拒绝发布（防手滑）"},
    {"name":"NOTE","type":"text","default":"","description":"本轮备注，写进账本"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '120', numToKeepStr: '80'))
  }

  environment {
    // 用开发目录：data_aso/ 是运营工作区（变体、快照、账本都在里面），
    // 不该被打包 clone 的 reset 冲掉。
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 周期闸门与取证') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.ASO_SITE   = params.SITE.trim()
          env.ASO_DATA   = env.ASO_SITE ? "data_aso/sites/${env.ASO_SITE}" : "data_aso"
          env.CYCLE_ID   = sh(returnStdout: true,
                              script: 'date +%Y%m%d-%H%M').trim()
          env.ASO_BASE   = params.BASELINE.trim() ?: 'A'
          env.ASO_PARENT = params.PARENT.trim()
          env.ASO_LOCALE = params.LOCALES.trim()
          env.ASO_EMIT   = params.EMIT.toString()
          env.ASO_FULLTEXT = params.FULLTEXT.toString()
          env.ASO_ELEMENT = params.ELEMENT.toString()
          env.ASO_DAYS   = params.READOUT_DAYS.trim() ?: '14'
          env.ASO_PUBLISH = params.PUBLISH.toString().startsWith('review') ? 'review' : 'none'
          env.ASO_CONFIRM = params.CONFIRM_PACKAGE.trim()
          env.ASO_NOTE    = params.NOTE.trim()
        }
        script {
          // gate 的详细输出走 stderr（进构建日志），stdout 只留一个单词给 Jenkins 判断。
          def mode = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || { echo FAIL; exit 0; }
mkdir -p "$TS_RUN_DIR/logs" "$TS_RUN_DIR/artifacts"
FORCE_FLAG=""
[[ "${FORCE,,}" == "true" ]] && FORCE_FLAG="--force"
"$PY" scripts/aso/aso_keyword_cycle.py gate --days "$CYCLE_DAYS" $FORCE_FLAG \
  > "$TS_RUN_DIR/logs/gate.txt" 2>&1
rc=$?
cat "$TS_RUN_DIR/logs/gate.txt" >&2
if [[ $rc -eq 3 ]]; then echo SKIP; exit 0; fi
if [[ $rc -ne 0 ]]; then echo FAIL; exit 0; fi
echo RUN
''').trim()
          env.CYCLE_MODE = mode
          if (mode == 'FAIL') {
            error('周期闸门脚本执行失败，见日志')
          }
          sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "周期：${CYCLE_ID}（闸门结果 ${CYCLE_MODE}，设定 ${CYCLE_DAYS} 天）"
  echo "站点：${ASO_SITE:-（主站点）}　数据根：${ASO_DATA:-data_aso}"
  echo "基线：${ASO_BASE}　父本：${ASO_PARENT:-自动}　语言：${ASO_LOCALE:-四语全做}"
  echo "发布：$( [[ "$ASO_PUBLISH" == "review" ]] && echo '🔴 会写入 Play 并自动送审' || echo '否（只设计）' )"
  echo ""
  echo "🔴 三条能力边界（2026-10-23 核对，别按印象改）："
  echo "   1. edits.listings 可改 title/short/full；但**商店页 A/B 实验没有公开 API**，"
  echo "      建实验、看结论只能在 Console 网页 ⇒ 本 job 只做「顺序窗口对比 + 窗口登记 + 读 CSV」。"
  echo "   2. 该包是托管式发布，「提交即自动送审」⇒ 不存在「写上线但不送审」的中间态，"
  echo "      所以 PUBLISH 只有 none / review 两档，没有 draft。"
  echo "   3. 3 天一轮只用于推进节奏；读数需要 ≥7 天且 ≥1000 次商店页访问，"
  echo "      所以上一个实验没到期时本 job 会拒绝换版（除非勾 IGNORE_EXP_WINDOW）。"
} | tee "$TS_RUN_DIR/context.txt"
''')
        }
      }
    }

    stage('② 线上 listing 取证') {
      when { expression { env.CYCLE_MODE == 'RUN' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 只读导出：开一个 edit 会话读 listings/images，退出时删掉（不留脏 edit）。
# 认证/权限失败不该把整轮打断 —— 策略仍可从本地变体算，标黄即可。
"$BASH" .jenkins/lib/run_stage.sh --name "线上 listing 导出" \
  --group "Play" --slug aso-online --timeout 600 --warn-ok \
  -- "$BASH" .jenkins/lib/lock.sh --name play run \
       --who "$JOB_NAME #$BUILD_NUMBER" --timeout 300 -- \
       "$PY" scripts/aso/aso_play.py list

# online/ 下每次导出一个时间戳目录。历史真源是 snapshots/，这里只留最近 20 份。
ls -1dt "${ASO_DATA:-data_aso}"/online/*/ 2>/dev/null | tail -n +21 | while read -r d; do
  echo "清理旧线上导出：$d"; rm -rf "$d"
done || true
cp -f "${ASO_DATA:-data_aso}"/online/$(ls -1t "${ASO_DATA:-data_aso}"/online | head -1)/listings.json \
      "$TS_RUN_DIR/artifacts/online-listings.json" 2>/dev/null || true
''')
      }
    }

    stage('②b 长描述体检') {
      // 不论闸门是否放行都跑：这是只读检查，且查的是**线上**。
      // zh-TW 线上长描述整篇是简体字 ⇒ 繁体搜索词一个都匹配不到，
      // 这类问题不该等 3 天一轮才发现，每 6 小时的哨兵就该看得见。
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
LF=()
[[ -n "${ASO_LOCALE:-}" ]] && LF=(--locales "$ASO_LOCALE")
# rc=1 = 有字符集问题（这就是要报的），不当失败，标黄即可
"$BASH" .jenkins/lib/run_stage.sh --name "长描述体检" \
  --group "ASO" --slug aso-audit --timeout 120 --warn-ok \
  -- "$PY" scripts/aso/aso_keyword_cycle.py audit "${LF[@]}"
''')
      }
    }

    stage('③ 关键词策略与元数据设计') {
      when { expression { env.CYCLE_MODE == 'RUN' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
ARGS=(plan --baseline "$ASO_BASE" --cycle "$CYCLE_ID" --days "$CYCLE_DAYS")
[[ -n "${ASO_PARENT:-}" ]] && ARGS+=(--parent "$ASO_PARENT")
[[ -n "${ASO_LOCALE:-}" ]] && ARGS+=(--locales "$ASO_LOCALE")
[[ "${ASO_EMIT,,}" == "true" ]] && ARGS+=(--emit-variant auto)
[[ "${ASO_FULLTEXT,,}" == "true" ]] && ARGS+=(--with-fulltext)
[[ "${IGNORE_EXP_WINDOW,,}" == "true" ]] && ARGS+=(--no-block-on-open-exp)
echo "→ aso_keyword_cycle.py ${ARGS[*]}"
# rc=4 = 没有命中任何已启用的改写规则 ⇒ 只出策略不派生变体，这不是失败，标黄。
"$BASH" .jenkins/lib/run_stage.sh --name "关键词策略与元数据设计" \
  --group "ASO" --slug aso-plan --timeout 600 --warn-rc 4 \
  -- "$PY" scripts/aso/aso_keyword_cycle.py "${ARGS[@]}"

cp -f "${ASO_DATA:-data_aso}/keywords/$CYCLE_ID/strategy.md" "$TS_RUN_DIR/artifacts/" 2>/dev/null || true
cp -f "${ASO_DATA:-data_aso}/keywords/$CYCLE_ID/strategy.json" "$TS_RUN_DIR/artifacts/" 2>/dev/null || true
''')
        script {
          // 把「派生出的变体 / 实际父本 / 阻断条数」抽成环境变量，供后续阶段判断。
          def meta = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ"
export STRAT="${ASO_DATA:-data_aso}/keywords/${CYCLE_ID}/strategy.json"
"$PY" - <<'PYEOF'
import json, os, pathlib
p = pathlib.Path(os.environ["STRAT"])
d = json.loads(p.read_text(encoding="utf-8")) if p.is_file() else {}
print("|".join([
    d.get("emit_variant") or "",
    d.get("parent") or "",
    str(len(d.get("publish_blockers") or [])),
    (d.get("hypothesis") or "").replace("|", "/"),
]))
PYEOF
''').trim()
          def parts = meta.split('\\|')
          env.ASO_TARGET = parts.length > 0 ? parts[0] : ''
          env.ASO_PARENT_USED = parts.length > 1 ? parts[1] : ''
          env.ASO_BLOCKERS = parts.length > 2 ? parts[2] : '0'
          env.ASO_HYPO = parts.length > 3 ? parts[3] : ''
          echo "派生变体：${env.ASO_TARGET ?: '(无)'}　父本：${env.ASO_PARENT_USED}　阻断：${env.ASO_BLOCKERS}"
        }
      }
    }

    stage('④ 增量文案闸门') {
      when { expression { env.CYCLE_MODE == 'RUN' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 🔴 用增量口径（新增红），不是 aso_lint 的绝对口径。
# 原因：父本可能自带历史债（A 的 zh-TW 长描述是简体混排），
# 拿绝对口径判「本轮改动」会把父本的锅算到本轮头上，于是永远发不出去。
# 🔴 变量一律 ${X:-} 取值：Jenkins 里 env.X = "" 可能压根不建这个变量，
# 配合 set -u 就会 unbound（#1 就死在这）。
CHECK="${ASO_TARGET:-${ASO_PARENT_USED:-}}"
if [[ -z "$CHECK" ]]; then
  echo "🔴 既没有派生变体也没有父本，无法检查"
  exit 1
fi
echo "→ 检查变体 ${CHECK}（父本 ${ASO_PARENT_USED:-无}）"
"$BASH" .jenkins/lib/run_stage.sh --name "增量文案闸门" \
  --group "ASO" --slug aso-lint-gate --timeout 300 \
  -- "$PY" scripts/aso/aso_keyword_cycle.py lint-gate \
       --variant "$CHECK" --parent "${ASO_PARENT_USED:-}" \
       ${ASO_LOCALE:+--locales "$ASO_LOCALE"}

# 存档绝对口径的问题清单，便于人眼比对
"$PY" scripts/aso/aso_lint.py --variant "$CHECK" \
  --baseline "$ASO_BASE" --json >/dev/null 2>&1 || true
cp -f "${ASO_DATA:-data_aso}/reports/listing_lint.json" "$TS_RUN_DIR/artifacts/" 2>/dev/null || true
''')
      }
    }

    stage('⑤ 写入 Play 并送审') {
      when { expression { env.CYCLE_MODE == 'RUN' && env.ASO_PUBLISH == 'review' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"

if [[ -z "${ASO_TARGET:-}" ]]; then
  echo "🔴 本轮没有派生任何变体，没东西可发布。"
  echo "   先确认 rewrite_rules.json 的 enabled 与替换对（命中 0 处就不会派生）。"
  exit 1
fi
# 包名从站点配置读，不写死：换站点（SITE=capybara）时这个闸门必须跟着换，
# 否则要么拦住正确包，要么放过错误包。
PKG="$("$PY" -c 'import sys; sys.path.insert(0,"scripts/aso"); import aso_common as C; print(C.PACKAGE)')"
if [[ "${ASO_CONFIRM:-}" != "$PKG" ]]; then
  echo "🔴 拒绝发布：CONFIRM_PACKAGE=「${ASO_CONFIRM:-}」与包名 ${PKG} 不符。"
  echo "   要真发布，把 CONFIRM_PACKAGE 精确填成 ${PKG}。"
  exit 1
fi
if [[ "${ASO_BLOCKERS:-0}" != "0" ]]; then
  echo "🔴 拒绝发布：strategy.json 里还有 ${ASO_BLOCKERS} 条阻断（实验未到期 / 规则未启用）。"
  echo "   强行推进会混淆变量；确认要这么做就勾 IGNORE_EXP_WINDOW 重跑。"
  exit 1
fi

echo "🔴 即将写入线上变体 ${ASO_TARGET} 并**自动送审**（该包没有「写而不送审」的中间态）。"
echo "   文案改动："
"$PY" - <<PYEOF
import json, pathlib
p = pathlib.Path("${ASO_DATA:-data_aso}/keywords/${CYCLE_ID}/strategy.json")
d = json.loads(p.read_text(encoding="utf-8")) if p.is_file() else {}
for c in (d.get("changes") or []):
    print("   -", c)
PYEOF

"$BASH" .jenkins/lib/run_stage.sh --name "写入 Play（自动送审）" \
  --group "Play" --slug aso-publish --timeout 1200 \
  -- "$BASH" .jenkins/lib/lock.sh --name play run \
       --who "$JOB_NAME #$BUILD_NUMBER" --timeout 600 -- \
       "$PY" scripts/aso/aso_play.py push --variant "$ASO_TARGET" --text-only \
       --allow-write --yes --auto-review

echo "PUBLISHED=1" > "$TS_RUN_DIR/logs/published.flag"
''')
      }
    }

    stage('⑥ 快照 / A-B 窗口登记 / 记入账本') {
      when { expression { env.CYCLE_MODE == 'RUN' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
V="${ASO_TARGET:-${ASO_PARENT_USED:-${ASO_BASE:-A}}}"
PUBLISHED=0
[[ -f "$TS_RUN_DIR/logs/published.flag" ]] && PUBLISHED=1

# ① 证据快照：把「此刻要上的那一版」的文案全文 + 每张图哈希存下来。
#    没有这一步，两周后没人知道当时测的到底是什么。
"$BASH" .jenkins/lib/run_stage.sh --name "证据快照" \
  --group "ASO" --slug aso-snapshot --timeout 300 \
  -- "$PY" scripts/aso/aso_experiment.py snapshot --variant "$V"

# ② A/B 窗口登记：只有真发布了才开新窗口，否则登记一个不存在的变体等于骗自己。
ELEMENT="$ASO_ELEMENT"
[[ -n "${ASO_TARGET:-}" ]] && ELEMENT="copy"   # 本 job 的派生只改文案
if [[ "$PUBLISHED" == "1" ]]; then
  "$BASH" .jenkins/lib/run_stage.sh --name "A/B 窗口登记" \
    --group "ASO" --slug aso-exp --timeout 300 \
    -- "$PY" scripts/aso/aso_experiment.py start --variant "$ASO_TARGET" \
         --baseline "$ASO_BASE" --element "$ELEMENT" --days "$ASO_DAYS" \
         --id "aso-${CYCLE_ID}-${ELEMENT}-${ASO_TARGET}" --force \
         --hypothesis "${ASO_HYPO:-周期 ${CYCLE_ID} 关键词策略派生的元数据变体}"
  STATUS="published"
elif [[ -n "${ASO_TARGET:-}" ]]; then
  echo "（未发布：变体 ${ASO_TARGET} 已派生但只在本地，不开实验窗口）"
  STATUS="designed"
else
  echo "（未派生变体：本轮只有策略报告）"
  STATUS="blocked"
fi

# ③ 账本：记录本轮动作、关键词池、结论，下一轮用它判断「是不是在重复测同一件事」
"$PY" scripts/aso/aso_keyword_cycle.py record --cycle "$CYCLE_ID" \
  --variant "$V" --baseline "$ASO_BASE" --element "$ELEMENT" \
  --status "$STATUS" --publish "$ASO_PUBLISH" \
  --days "$CYCLE_DAYS" --hypothesis "${ASO_HYPO:-}" --note "${ASO_NOTE:-}"

"$PY" scripts/aso/aso_keyword_cycle.py ledger | tee "$TS_RUN_DIR/artifacts/ledger.txt" || true
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
# evidence/ 每次重建：workspace 不 cleanWs，cp -R 只增不删，
# 上几次的 stages/*.json 会被一起归档，看起来像同一环节跑了两遍。
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
if [[ "${CYCLE_MODE:-}" == "SKIP" ]]; then echo "周期未到（跳过）"; exit 0; fi
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
