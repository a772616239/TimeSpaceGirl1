/**@META
{
  "description": "店面迭代（ASO）：**四语文案闸门 → 截图/置顶图派生（竖版 1080×1920 或横版 1024×520，由 SHOT_MODE 决定）→ 规格体检 → 可选拼装置顶图（左右角色由 TS-Art-Restyle 按特征卡重绘 + 中间压实机画面框）→ 可选调用 TS-Art-Restyle 重绘 → 人眼验收页 → 推送 Play（默认只打印 diff）→ A/B 登记**。默认全程只读；只有勾 ALLOW_WRITE 才会写线上，且写完仍需人工去 Console 点「送审」（本账号是托管式发布，API 无权送审）。",
  "concurrent": false,
  "keep": [30, 30],
  "params": [
    {"name":"MODE","type":"choice","choices":["dry-run（只读体检）","text（只推文案）","images（只换图）","both（文案+图）","art（只出美术需求单）"],"default":"dry-run（只读体检）","description":"干什么。前四种都会先过文案闸门与素材体检；art 只盘点缺哪些图并生成需求单，不碰 Play"},
    {"name":"VARIANT","type":"string","default":"B","description":"要处理的变体目录 data_aso/variants/<VARIANT>"},
    {"name":"BASELINE","type":"string","default":"A","description":"对照基线变体（A = 线上现状快照，别改它）"},
    {"name":"LOCALES","type":"string","default":"","description":"语言子集，逗号分隔：en,ja,zh-CN,zh-TW。留空=四语全做"},
    {"name":"FIT","type":"choice","choices":["cover","pad"],"default":"cover","description":"截图归一方式。cover=铺满裁切（默认，画面满、但会切边）；pad=整图装入+模糊补边（不裁内容、两侧留虚化底）"},
    {"name":"SHOT_MODE","type":"choice","choices":["portrait（竖版 1080×1920）","landscape（横版 1024×520）"],"default":"portrait（竖版 1080×1920）","description":"手机截图走哪条路线。portrait=aso_assets build 从 shots.json 重排 1080×1920；landscape=把拼装置顶图补边到 1024×520（画面一个像素不动，比例 2.048→1.969 才过 Play 的 2:1 上限）。横版要求 fusion 底图已存在，张数与顺序取自 fusion_shots.py 的 DEFAULT_ORDER"},
    {"name":"ALLOW_WRITE","type":"bool","default":false,"description":"🔴 只有勾上才会真的写 Play（edits.listings / edits.images）。不勾=只打印 diff"},
    {"name":"IMAGE_TYPES","type":"choice","choices":["","phoneScreenshots","featureGraphic"],"default":"","description":"只推某一类图。留空=截图与置顶图都推；只换置顶图选 featureGraphic（否则会连带覆盖截图）"},
    {"name":"SHOTS","type":"string","default":"","description":"只推这几张手机截图，逗号分隔序号（如 0,1,2,5）。Play 每语上限 8 张，派生目录常有 9 张，留空则超上限只传前 8 张并告警"},
    {"name":"TRIGGER_ART","type":"bool","default":false,"description":"勾上则按缺图清单触发 TS-Art-Restyle 出图（不等待，产物下一轮用 ingest 收回）"},
    {"name":"ART_THEME","type":"choice","choices":["cyber","christmas","newyear","halloween","valentine","summer_surf","provence","thanksgiving","explore"],"default":"cyber","description":"触发换皮时用的题材。cyber=保持赛博原风味；其余为节日/场景主题"},
    {"name":"ART_PROVIDER","type":"choice","choices":["chatgpt_web","manual"],"default":"chatgpt_web","description":"出图通道，透传给 TS-Art-Restyle"},
    {"name":"FUSION","type":"bool","default":false,"description":"置顶图改走「左右角色 + 实机画面框」拼装版（1024x500）。角色必须由 TS-Art-Restyle 按特征卡重绘；缺底图会直接失败，不会退回立绘拼贴"},
    {"name":"FUSION_PAIR","type":"string","default":"01,02","description":"拼装底图的两位英雄 id（前=左、后=右），对应 data_aso/assets/hero_specs.json。换角色只改这里"},
    {"name":"FUSION_RENDER","type":"bool","default":false,"description":"🔴 重新按特征卡出双人底图：耗账号池额度、实测约 90 秒/张、且必须串行。只重排版面或改文案时不要勾"},
    {"name":"EXP_DAYS","type":"string","default":"14","description":"A/B 窗口天数（单窗口建议 ≥7 天，默认 14）"},
    {"name":"EXP_HYPOTHESIS","type":"text","default":"","description":"本次实验假设（留空=用变体 meta.json 里的 hypothesis）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 45, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '60', numToKeepStr: '60'))
  }

  environment {
    // 🔴 用开发目录而不是打包 clone：data_aso/ 是运营工作区，
    //    derived/reports 这些都是跑一轮生成一轮的产物，不该被 ci_sync 的 reset 冲掉。
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 准备与取证') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR  = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.ASO_VARIANT = params.VARIANT.trim() ?: 'B'
          env.ASO_BASE    = params.BASELINE.trim() ?: 'A'
          env.ASO_LOCALES = params.LOCALES.trim()
          env.ASO_MODE    = params.MODE
          env.ASO_FIT     = params.FIT
          // 横版/竖版二选一。choice 的中文标签只给人看，脚本侧只认这两个词。
          env.ASO_SHOTMODE = params.SHOT_MODE.toString().startsWith('landscape') ? 'landscape' : 'portrait'
          env.ASO_WRITE   = params.ALLOW_WRITE.toString()
          env.ASO_IMGTYPE = params.IMAGE_TYPES.trim()
          env.ASO_SHOTS   = params.SHOTS.trim()
          env.ASO_DAYS    = (params.EXP_DAYS.trim() ?: '14')
          env.ASO_HYPO    = params.EXP_HYPOTHESIS.trim()
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs" "$TS_RUN_DIR/artifacts"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "模式：${ASO_MODE}"
  echo "变体：${ASO_VARIANT}（对照 ${ASO_BASE}）  语言：${ASO_LOCALES:-四语全做}"
  echo "写线上：$( [[ "$ASO_WRITE" == "true" ]] && echo '🔴 会写 Play' || echo '否（只打印 diff）' )"
  echo ""
  echo "🔴 Play 的能力边界（2026-10-23 核对 API 文档）："
  echo "   edits.listings 可改 title/short/full/video；edits.images 可传"
  echo "   phoneScreenshots/featureGraphic/icon 等；但**商店页 A/B 实验没有公开 API**，"
  echo "   建实验和看结论只能在 Console 网页；本 job 负责产出变体 + 登记窗口 + 算读数。"
  echo "🔴 写线上之后仍要人去 Console 点「送审」——托管式发布，commit 带"
  echo "   changesNotSentForReview=true，release 只会挂在待送审状态。"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('② 文案闸门（四语）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
LOC_ARGS=()
[[ -n "${ASO_LOCALES:-}" ]] && LOC_ARGS=(--locales "$ASO_LOCALES")
"$BASH" .jenkins/lib/run_stage.sh --name "文案闸门（长度/串味/夸大）" \
  --group "ASO" --slug aso-lint --timeout 300 \
  -- "$PY" scripts/aso/aso_lint.py --variant "$ASO_VARIANT" \
       --baseline "$ASO_BASE" --json "${LOC_ARGS[@]}"
cp -f data_aso/reports/listing_lint.json "$TS_RUN_DIR/artifacts/" 2>/dev/null || true
''')
      }
    }

    stage('③ 素材派生（截图 + 置顶图）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
LOC_ARGS=()
[[ -n "${ASO_LOCALES:-}" ]] && LOC_ARGS=(--locales "$ASO_LOCALES")

# 先跑 build：它负责两件与截图路线无关的事 ——
#   ① 出 index.json（每个语言的条目表，preview.html / push 都读它）
#   ② 出置顶图（③b 勾了 FUSION 才会被拼装版覆盖）
# 横版路线下它顺带产出的 1080×1920 竖版 shot_* 会在下一步被整批删掉，不留残图。
"$BASH" .jenkins/lib/run_stage.sh --name "素材派生 ${ASO_SHOTMODE}" \
  --group "ASO" --slug aso-assets --timeout 600 \
  -- "$PY" scripts/aso/aso_assets.py build --variant "$ASO_VARIANT" \
       --fit "$ASO_FIT" ${ASO_LOCALES:+--locales "$ASO_LOCALES"}

if [[ "$ASO_SHOTMODE" == "landscape" ]]; then
  # ── 横版手机截图 ────────────────────────────────────────────────────────
  # 置顶图 1024×500 的比例是 2.048，超过 Play 对 phoneScreenshots 的 2:1 上限；
  # 差 12px 而已，补高到 520（1.969）就合规，画面一个像素不动。
  # 张数与顺序全部取自 fusion_shots.py 的 DEFAULT_ORDER —— 和店面顺序同一真源，
  # 不在 Jenkins 里再抄一份清单。
  LOC="${ASO_LOCALES:-en-US,ja-JP,zh-CN,zh-TW}"
  echo "→ 横版路线：置顶图补边 → 1024×520 手机截图"
  # 🔴 拼装必须在「全部组出齐」之后再 promote：--promote 一次只写一组，
  #    批量出图加 --promote 会被脚本直接拒绝（featureGraphic 每语言只允许一张）。
  "$BASH" .jenkins/lib/run_stage.sh --name "横版截图源图（置顶图批量拼装）" \
    --group "ASO" --slug aso-fusion-all --timeout 900 \
    -- "$PY" scripts/aso/aso_fusion.py build --layout duo --variant "$ASO_VARIANT" \
         --pairs shots --by-locale \
         --out "data_aso/derived/$ASO_VARIANT/fusion_all" \
         --locales "$LOC"

  "$BASH" .jenkins/lib/run_stage.sh --name "横版截图合规化（1024×520）" \
    --group "ASO" --slug aso-fusion-shots --timeout 300 \
    -- "$PY" scripts/aso/fusion_shots.py --variant "$ASO_VARIANT" --locales "$LOC"

  # 🔴 上面第一步的 build 会把 feature_01.png 换回「宣传图拼贴」版（它才是 build 的产物）。
  #    横版路线下用户要的是拼装置顶图，这里立刻复原一次 —— 零额度、约 2 秒、不调模型。
  #    （③b 若勾了 FUSION 会再按所选角色组合覆盖，顺序上以后者为准。）
  "$BASH" .jenkins/lib/run_stage.sh --name "复原置顶图（拼装版）" \
    --group "ASO" --slug aso-fusion-restore --timeout 300 \
    -- "$PY" scripts/aso/aso_fusion.py build --layout duo --variant "$ASO_VARIANT" \
         --locales "$LOC" --promote

  # 验收页里的尺寸/体积/哈希是建页时写进去的；截图和置顶图都换了，不重画就是
  # 「图换了数字没换」，看着像改动没生效。
  "$PY" scripts/aso/aso_assets.py preview --variant "$ASO_VARIANT"
else
  echo "（竖版路线：上面 build 出的 1080×1920 就是最终截图）"
fi

"$BASH" .jenkins/lib/run_stage.sh --name "Play 规格体检" \
  --group "ASO" --slug aso-check --timeout 300 \
  -- "$PY" scripts/aso/aso_assets.py check --variant "$ASO_VARIANT"
cp -f "data_aso/derived/$ASO_VARIANT/index.json" "$TS_RUN_DIR/artifacts/" 2>/dev/null || true
''')
      }
    }

    stage('③b 置顶图拼装（双人重绘）') {
      when {
        expression { params.FUSION.toString() == 'true' }
      }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 语言口径：ASO_LOCALES 留空 = 四语全做（aso_assets 的默认），这里要显式补全，
# 否则 aso_fusion 会退回它自己的默认值（只出 en-US），另外三语就没有拼装置顶图。
LOC="${ASO_LOCALES:-en-US,ja-JP,zh-CN,zh-TW}"
export TSG_LEASE_OWNER="$JOB_NAME-$BUILD_NUMBER"

if [[ "${FUSION_RENDER,,}" == "true" ]]; then
  echo "→ 按特征卡重绘双人底图：$FUSION_PAIR  主题 $ART_THEME（约 90s，串行等待）"
  # 🔴 --wait 必须带：本 job 出图独占本机 Chrome 登录态与 inbox/，
  #    并发会串图（#28~#32 里 02/03 的 gen_web.png 落在同一 md5）。
  #    Jenkins 2.568 会静默丢弃 DisableConcurrentBuildsJobProperty，
  #    options{disableConcurrentBuilds()} 也拦不住同时入队 ⇒ 串行只能在调用侧保证。
  "$BASH" .jenkins/lib/run_stage.sh --name "双人底图重绘 $FUSION_PAIR" \
    --group "美术" --slug aso-fusion-render --timeout 1800 \
    -- "$PY" scripts/aso/hero_keyart.py duo --pair "$FUSION_PAIR" \
         --theme "$ART_THEME" --wait
else
  echo "（未勾 FUSION_RENDER：沿用现有双人底图，只重排版面 + 本地压字，零额度）"
fi

"$BASH" .jenkins/lib/run_stage.sh --name "拼装置顶图 $FUSION_PAIR" \
  --group "ASO" --slug aso-fusion --timeout 300 \
  -- "$PY" scripts/aso/aso_fusion.py build --layout duo --variant "$ASO_VARIANT" \
       --locales "$LOC" --promote

# 验收页里的尺寸/体积/哈希是 ③ 建页时写进去的；上面刚把 feature_01.png 换掉了，
# 不重画就会「图换了数字没换」，看着像拼装没生效。
"$PY" scripts/aso/aso_assets.py preview --variant "$ASO_VARIANT"

# 写进 feature_01.png 之后再体检一次：Play 对 featureGraphic 只认 1024×500 一张
"$BASH" .jenkins/lib/run_stage.sh --name "置顶图规格复检" \
  --group "ASO" --slug aso-fusion-check --timeout 300 \
  -- "$PY" scripts/aso/aso_assets.py check --variant "$ASO_VARIANT"

mkdir -p "$TS_RUN_DIR/artifacts/fusion"
cp -f "data_aso/derived/$ASO_VARIANT"/fusion/*.png "$TS_RUN_DIR/artifacts/fusion/" 2>/dev/null || true
echo "拼装图：data_aso/derived/$ASO_VARIANT/fusion/ ；已 promote 到各语言 feature_01.png"
''')
      }
    }

    stage('④ 美术需求单 / 触发换皮') {
      when {
        expression { params.MODE.toString().startsWith('art') || params.TRIGGER_ART.toString() == 'true' }
      }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "缺图盘点" \
  --group "美术" --slug aso-art-plan --timeout 300 \
  -- "$PY" scripts/aso/aso_art.py plan --variant "$ASO_VARIANT" \
       --theme "$ART_THEME" --provider "$ART_PROVIDER" ${ASO_LOCALES:+--locales "$ASO_LOCALES"}

if [[ "${TRIGGER_ART,,}" != "true" ]]; then
  echo "（未勾 TRIGGER_ART：只出需求单，不发起换皮）"
  exit 0
fi
# 缺图清单里每一行都触发一次；同一批用同一个租约 owner，方便并行时认自己人
export TSG_LEASE_OWNER="$JOB_NAME-$BUILD_NUMBER"
SEED="$("$PY" - <<'PYEOF'
import glob, json, os
fs = sorted(glob.glob("data_aso/reports/art_requests/%s-*.json" % os.environ["ASO_VARIANT"]))
if not fs:
    print("")
else:
    d = json.load(open(fs[-1], encoding="utf-8"))
    reqs = [r for r in d["requests"] if r.get("seed")]
    print("\n".join(f'{r["locale"]}|{r["seed"]}' for r in reqs))
PYEOF
)"
if [[ -z "$SEED" ]]; then echo "没有带种子的缺图项，跳过触发"; exit 0; fi
echo "$SEED" | while IFS='|' read -r LOC ASSET; do
  [[ -z "$LOC" ]] && continue
  echo "→ 触发 TS-Art-Restyle：$LOC  seed=$ASSET  主题=$ART_THEME"
  "$PY" scripts/aso/aso_art.py trigger --variant "$ASO_VARIANT" --locale "$LOC" \
      --asset "$ASSET" --theme "$ART_THEME" --provider "$ART_PROVIDER" || \
      echo "   ⚠ 触发失败（不阻断本轮其它环节）"
done
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "触发换皮" --group "美术" --status pass \
  --detail "已按缺图清单发起 TS-Art-Restyle（不等待，产物用 aso_art.py ingest 收回）"
''')
      }
    }

    stage('⑤ 人眼验收页') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
SRC="data_aso/derived/$ASO_VARIANT"
if [[ -f "$SRC/preview.html" ]]; then
  # 整目录归档：验收页用的是相对路径引图（en-US/shot_01.png），
  # 只 cp 那个 html 过去就是一堆 404 —— 曾经这么错过。
  rm -rf "$TS_RUN_DIR/artifacts/preview"
  mkdir -p "$TS_RUN_DIR/artifacts/preview"
  cp -R "$SRC"/. "$TS_RUN_DIR/artifacts/preview/"
  echo "验收页：$SRC/preview.html（整目录已归档，构建页可直接点开）"
  "$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
    --name "验收页" --group "交付" --status pass --detail "preview/ 整目录已归档（含素材）"
else
  echo "🔴 没有 preview.html —— 素材派生没跑成？"
  "$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
    --name "验收页" --group "交付" --status fail --detail "缺 preview.html"
  exit 1
fi
''')
      }
    }

    stage('⑥ 推送 Play（持 Play 锁）') {
      when {
        expression { !params.MODE.toString().startsWith('art') }
      }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
PUSH_ARGS=(push --variant "$ASO_VARIANT")
[[ -n "${ASO_LOCALES:-}" ]] && PUSH_ARGS+=(--locales "$ASO_LOCALES")
[[ "$ASO_WRITE" == "true" ]] && PUSH_ARGS+=(--allow-write --yes)
# 图片类型/截图白名单：Play 每语 phoneScreenshots 上限 8 张，派生目录常有 9 张
[[ -n "${ASO_IMGTYPE:-}" ]] && PUSH_ARGS+=(--image-types "$ASO_IMGTYPE")
[[ -n "${ASO_SHOTS:-}"   ]] && PUSH_ARGS+=(--shots "$ASO_SHOTS")
case "$ASO_MODE" in
  text*)   PUSH_ARGS+=(--text-only) ;;
  images*) PUSH_ARGS+=(--images-only) ;;
  both*)   PUSH_ARGS+=(--with-images) ;;
  *)       PUSH_ARGS+=(--text-only) ;;   # dry-run：只打印 diff
esac
echo "→ scripts/aso/aso_play.py push ${PUSH_ARGS[*]}"
# 🔴 与上传/巡检共用一个 play 锁：并发开 edit 会把对方的 edit 判成 deleted
"$BASH" .jenkins/lib/run_stage.sh --name "推送 Play（${ASO_MODE}）" \
  --group "Play" --slug aso-push --timeout 1800 \
  -- "$BASH" .jenkins/lib/lock.sh --name play run \
       --who "$JOB_NAME #$BUILD_NUMBER" --timeout 900 -- \
       "$PY" scripts/aso/aso_play.py "${PUSH_ARGS[@]}"
''')
      }
    }

    stage('⑦ A/B 登记与快照') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 先存「此刻这一版」的证据（文案全文 + 每张图哈希），否则两周后没人知道当时测的是啥
"$BASH" .jenkins/lib/run_stage.sh --name "证据快照" \
  --group "ASO" --slug aso-snapshot --timeout 300 \
  -- "$PY" scripts/aso/aso_experiment.py snapshot --variant "$ASO_VARIANT"

# 🔴 变量一律用 ${X:-} 取值：Jenkins 里 env.X = "" 可能压根不建这个变量，
#    配合 set -u 就会直接 unbound variable 把整段打断（#2 就死在这）
HYPO="${ASO_HYPO:-}"
if [[ -z "$HYPO" ]]; then
  HYPO="$("$PY" - <<PYEOF
import json, pathlib
p = pathlib.Path("data_aso/variants/${ASO_VARIANT}/meta.json")
print(json.loads(p.read_text(encoding="utf-8")).get("hypothesis", "") if p.is_file() else "")
PYEOF
)"
fi

"$BASH" .jenkins/lib/run_stage.sh --name "A/B 实验登记" \
  --group "ASO" --slug aso-exp --timeout 300 \
  -- "$PY" scripts/aso/aso_experiment.py start --variant "$ASO_VARIANT" \
       --baseline "$ASO_BASE" --element copy --days "$ASO_DAYS" \
       --id "aso-$(date +%Y%m%d)-copy-${ASO_VARIANT}" --force \
       --hypothesis "$HYPO" ${ASO_LOCALES:+--locales "$ASO_LOCALES"}

"$PY" scripts/aso/aso_experiment.py status | tee "$TS_RUN_DIR/logs/experiments.txt" || true
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
# evidence/ 每次重建：workspace 不 cleanWs，而 cp -R 只增不删，
# 上几次构建的 stages/*.json 会被一起归档，看起来像同一环节跑了两遍（TS-Play-Watch 踩过）
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
