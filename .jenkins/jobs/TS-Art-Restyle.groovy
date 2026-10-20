/**@META
{
  "description": "美术资源「换节日风格」流水线（如登录底板 → 圣诞版）。生图交给 provider（manual=人/Agent 出图丢进 inbox；chatgpt_web=用本机 Chrome 登录态驱动 chatgpt.com），其余全部可断言：去水印 → 等比归位到原图尺寸（绝不拉伸）→ 出不透明版与沿用原 alpha 的浮层版 → 像素级验收 → 可选写回资源。每个环节都进 JUnit 与节点图，红绿一眼看清。",
  "concurrent": false,
  "params": [
    {"name":"ASSET","type":"string","default":"Assets/ManagedResources/ArtFont_en/EightDayGiftPanelAtlas/cn2-X1_baridenglu_diban_en.png","description":"要换风格的资源（相对工程根）。目标尺寸取该图自身尺寸"},
    {"name":"THEME","type":"choice","choices":["christmas","newyear","halloween","valentine","summer_surf","provence","thanksgiving","cyber","explore"],"default":"christmas","description":"题材/风格主题（含节日与场景题材：explore=探索寻宝）。风格内容全在 scripts/image/theme_presets.json；新增主题时改完预设要把 key 补进本 job 的 choices 再跑 apply-jobs.sh，否则下拉里选不到"},
    {"name":"PROVIDER","type":"choice","choices":["chatgpt_web","manual"],"default":"chatgpt_web","description":"manual=把出好的图给本 job（GEN_IMAGE 或 inbox）；chatgpt_web=用本机 Chrome 登录态驱动 chatgpt.com 出图"},
    {"name":"CDP_PORT","type":"string","default":"","description":"复用已登录的外部浏览器（AdsPower 的 SunBrowser 等）的调试端口：填了就 --reuse-cdp，不复制本机 Chrome profile（免费额度按账号算，换号就换这里）。端口用 scripts/image/find_browser_cdp.py 反查；留空=用本机 Chrome"},
    {"name":"GEN_IMAGE","type":"string","default":"","description":"provider=manual 时显式指定生成图绝对路径。留空 = 取 _output/art_restyle/<资源>/<主题>/inbox 下最新的图"},
    {"name":"PROMPT_OVERRIDE","type":"text","default":"","description":"覆盖预设提示词（留空=用 theme_presets.json 里的）。用于「同一主题但要改某句话」"},
    {"name":"ALPHA_FROM","type":"string","default":"","description":"alpha 参照图。资源被压成 RGB（丢了透明浮层）时用；支持 git:HEAD:<path> 直接从 git 取原版"},
    {"name":"SOURCE_FROM","type":"string","default":"","description":"改前参照图。默认=资源本身；资源已换过要重跑时填 git:HEAD:<path>，否则对比图会变成「新版 vs 新版」"},
    {"name":"LAYOUT","type":"text","default":"","description":"构图锁（锁文案/角色/空区）。留空=预设里的通用规则：一律保字、只改材质。某张图有特殊要求时填这里，别改 theme_presets.json"},
    {"name":"OUTFIT","type":"text","default":"","description":"覆盖主题预设里的服装句（只改「穿什么」，配色/装饰仍走主题）。留空=用主题默认。角色剪裁/露肤度是设计的一部分时填这里——主题的默认大衣会把舞娘/泳装这类角色裹住，等于改构图"},
    {"name":"COMPOSITION","type":"choice","choices":["lock","free"],"default":"lock","description":"构图自由度：lock=人物姿势/位置/缩放全锁，只换衣服与配色（默认，可预期）；free=允许重设计人物姿势与镜头换吸引力，但文案完整可读、底部 UI 空白区、画布比例与透明边仍锁死（出图需人眼过一遍）"},
    {"name":"POSE","type":"string","default":"","description":"free 模式的姿势。留空=每次从主题候选里随机抽一条（推荐：同一主题连跑也不会每张都是同一个姿势）；数字=指定第 N 条；none=不注入姿势；其它文字=自定义姿势句。🔴 曾经这段是硬编码单条「递礼盒」，导致每张 free 图都抱着礼物"},
    {"name":"HERO_BAND","type":"string","default":"","description":"超长条底板用（如 856x2048）：填英雄带像素高度（如 930）或 auto。生成图只当这条带子贴顶，下方补空卡体；留空=整幅等比 cover（适合比例接近 3:4 的图）"},
    {"name":"BODY_MODE","type":"choice","choices":["auto","source","synthetic"],"default":"auto","description":"HERO_BAND 模式下空卡体怎么来：source=用原资源下半截的明暗结构重上色（几何与原图逐像素对齐，首选）；synthetic=按主题色合成渐变（兜底）；auto=能 source 就 source"},
    {"name":"ALPHA_MODE","type":"choice","choices":["source","keep","free"],"default":"source","description":"alpha 版怎么取：source=沿用源掩膜（只对 lock 构图成立，free 会被自动改成 keep）；keep=整幅不透明；free=整幅不透明+顶边渐隐。COMPOSITION=free 时源掩膜按老姿势抠的，会把人脸/头发裁掉"},
    {"name":"FRAME","type":"choice","choices":["auto","card","gold","none"],"default":"auto","description":"外框：auto=free 构图自动套游戏卡框、lock 不套；card=游戏卡框（亮边+墨带+菱形纹+切角，参考道具槽/英雄卡，画面缩进框内）；gold=旧红金雕花框（游戏里没有这种语言，仅兜底）；none=不套"},
    {"name":"FRAME_RIM","type":"choice","choices":["warm","ivory","violet","none"],"default":"warm","description":"卡框最外那道亮边（跟游戏道具槽一致的「暗带+亮边」）。warm=暖金（配圣诞等暖色主题）；ivory=银白；violet=紫白（跟紫色面板同色系）；none=不画亮边——🔴 深色面板(17,17,25)上墨带跟底色同亮度，框会直接看不见"},
    {"name":"WATERMARK","type":"choice","choices":["auto","off","force"],"default":"auto","description":"去水印。auto=按「亮+灰+排成一行」判据自动修；off=完全不碰像素（生成图本来没水印、或右下角有亮装饰带会被误判成水印时用；掩码为 0 时验收自动跳过这条）；force=已知有水印但判据没认出来"},
    {"name":"WRITE_BACK","type":"boolean","default":true,"description":"替换原图（默认开）：验收通过后把成品写回资源，**原图先搬出工程**到 BACKUP_ROOT（默认 ResBackpack/备份，.meta 不动），再覆盖；写回前先复核哈希，可 restore 回滚。传 false 则只出图、不改工程里的资源"},
    {"name":"BACKUP_ROOT","type":"string","default":"","description":"原图备份根目录。留空=ResBackpack/备份（按资源相对路径镜像，_manifest.jsonl 记台账）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 40, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '40'))
  }

  environment {
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 资源体检与工作区准备') {
      steps {
        script {
          // 显式声明工程根，别依赖共享库退回 $PWD（写清楚比靠默契稳）
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.ART_WORK   = "${env.PROJ}/_output/art_restyle"
          env.ART_ASSET  = params.ASSET
          env.ART_THEME  = params.THEME
          // 工作目录按「资源名/主题」分桶：同一张图的不同节日版本互不覆盖
          def assetName = params.ASSET.split('/').last().replace('.png', '')
          // free 构图单独分桶：同一张图的「锁姿势版」和「重设计版」要能同时留在磁盘上对比
          def compSuffix = params.COMPOSITION == 'free' ? '_free' : ''
          env.ART_COMP   = params.COMPOSITION
          env.ART_WDIR   = "${env.ART_WORK}/${assetName}/${params.THEME}${compSuffix}"
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs" "$TS_RUN_DIR/artifacts"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "资源：$ART_ASSET"
  echo "主题：$ART_THEME   provider：$PROVIDER   构图：$ART_COMP   pose：${POSE:-随机}   去水印：${WATERMARK:-auto}"
  echo "工作目录：$ART_WDIR"
  echo "写回资源：$WRITE_BACK   备份根：${BACKUP_ROOT:-$PROJ/ResBackpack/备份}"
  echo ""
  echo "🔴 尺寸按源图自身的 W×H 归位，用等比 cover + 居中裁切，绝不拉伸（拉伸会让九宫格错位）。"
  echo "🔴 提示词不写死文案：文案由 LAYOUT 构图锁约束为「逐字保持、只改材质」。"
  echo "   换资源时不改这里也行，但别把上一张图的文案硬编码进主题预设（会串图）。"
  echo "🔴 写回时原图不留在工程里：搬到 ResBackpack/备份/<资源相对路径>，Assets 只留当前生效版本；"
  echo "   要回滚跑 restyle_pipeline.py restore --asset <资源>（--list 看有哪些版本）。"
} | tee "$TS_RUN_DIR/context.txt"

# 提示词先落盘，后面 provider 与人工出图都用同一份，避免「job 里跑的和手搓的不是一句话」
PROMPT_FILE="$TS_RUN_DIR/artifacts/prompt.txt"
if [[ -n "${PROMPT_OVERRIDE:-}" ]]; then
  printf '%s\\n' "${PROMPT_OVERRIDE:-}" > "$PROMPT_FILE"
  echo "提示词来源：PROMPT_OVERRIDE 参数（覆盖预设）"
else
  if [[ -n "${LAYOUT:-}" ]]; then
    printf '%s\\n' "${LAYOUT}" > "$TS_RUN_DIR/artifacts/layout.txt"
    "$PY" scripts/image/restyle_pipeline.py prompt --theme "$ART_THEME" --composition "$ART_COMP" --pose "${POSE:-}" --layout "$TS_RUN_DIR/artifacts/layout.txt" --outfit "${OUTFIT:-}" > "$PROMPT_FILE"
    echo "提示词来源：LAYOUT 参数 + scripts/image/theme_presets.json（$ART_THEME / $ART_COMP / pose=${POSE:-随机}${OUTFIT:+ / outfit 已覆盖}）"
  else
    "$PY" scripts/image/restyle_pipeline.py prompt --theme "$ART_THEME" --composition "$ART_COMP" --pose "${POSE:-}" --outfit "${OUTFIT:-}" > "$PROMPT_FILE"
    echo "提示词来源：scripts/image/theme_presets.json（$ART_THEME / $ART_COMP / pose=${POSE:-随机}${OUTFIT:+ / outfit 已覆盖}）"
  fi
fi
echo "--- 提示词开头 ---"
head -3 "$PROMPT_FILE"
''')
      }
    }

    stage('② 资源体检（尺寸 / alpha / 基线）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
EXTRA=""
[[ -n "${ALPHA_FROM:-}"  ]] && EXTRA="$EXTRA --alpha-from \"${ALPHA_FROM}\" "
[[ -n "${SOURCE_FROM:-}" ]] && EXTRA="$EXTRA --source-from \"${SOURCE_FROM}\" "
[[ -n "${LAYOUT:-}"      ]] && EXTRA="$EXTRA --layout \"$TS_RUN_DIR/artifacts/layout.txt\" "
# OUTFIT 是一整句英文，不能塞进 EXTRA（EXTRA 是不加引号展开的，会被按空格拆散）⇒ 直接写在命令行上
# shellcheck disable=SC2086
"$BASH" .jenkins/lib/run_stage.sh --name "资源体检与基线" \
  --group "美术资源链" --slug art-prepare --timeout 300 \
  -- "$PY" scripts/image/restyle_pipeline.py prepare \
       --asset "$ART_ASSET" --theme "$ART_THEME" --work "$ART_WDIR" --composition "$ART_COMP" --pose "${POSE:-}" \
       --outfit "${OUTFIT:-}" $EXTRA
''')
      }
    }

    stage('③ 出图（provider）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 先把「有没有图」这件事判定掉：没有图不是失败，是流程还没走到下一步（黄）
"$BASH" .jenkins/lib/run_stage.sh --name "生成图定位" \
  --group "美术资源链" --slug art-resolve-gen --timeout 300 --warn-rc 3 \
  -- "$BASH" scripts/image/resolve_gen.sh --work "$ART_WDIR" --run "$TS_RUN_DIR" --gen "${GEN_IMAGE:-}"

# 超长条底板只把顶部「英雄带」喂给模型：整幅 856x2048 塞进去，模型会压成很窄一张，角色和字全糊
ART_CROP=0
if [[ "${HERO_BAND:-}" =~ ^[0-9]+$ ]]; then ART_CROP="$HERO_BAND"; fi

if [[ "$PROVIDER" == "chatgpt_web" ]]; then
  # CDP_PORT 有值 ⇒ 接外部已登录浏览器（只连不断），不复制本机 profile
  CDP_ARGS=""
  if [[ -n "${CDP_PORT:-}" ]]; then
    CDP_ARGS="--reuse-cdp --port ${CDP_PORT}"
    echo "复用外部浏览器：CDP 端口 ${CDP_PORT}（换号只换这个参数）"
  fi
  # 🔴 这个 provider 走本机 Chrome 的登录态，出口封了就是 403/超时。
  #    失败只标黄（--warn-ok），因为「网络不可用」不是这份代码的缺陷。
  "$BASH" .jenkins/lib/run_stage.sh --name "chatgpt.com 出图" \
    --group "美术资源链" --slug art-gen-web --timeout 900 --warn-ok \
    -- "$PY" scripts/image/gen_chatgpt_web.py \
         --image "$ART_WDIR/src/source.png" \
         --prompt-file "$TS_RUN_DIR/artifacts/prompt.txt" \
         --out "$ART_WDIR/inbox/gen_web.png" \
         --crop-height "$ART_CROP" $CDP_ARGS
  if [[ -f "$ART_WDIR/inbox/gen_web.png" ]]; then
    cp -f "$ART_WDIR/inbox/gen_web.png" "$TS_RUN_DIR/artifacts/gen.png"
    printf '%s\\n' "$ART_WDIR/inbox/gen_web.png" > "$TS_RUN_DIR/generated.path"
    touch "$TS_RUN_DIR/gen.ready"
  fi
  # 🔴 额度用尽不再只是「页面尾部里的一句话」：driver 命中即退出 rc=4 并落 <out>.fail.json，
  #    这里把它当证据归档，构建页直接看得到站点原文与重置时间。
  #    （python 侧默认会自动换号到 AdsPower/SunBrowser；只有连换号也失败时这个文件才留下来。）
  FAIL_JSON="$ART_WDIR/inbox/gen_web.png.fail.json"
  if [[ -f "$FAIL_JSON" ]]; then
    cp -f "$FAIL_JSON" "$TS_RUN_DIR/artifacts/provider_fail.json" 2>/dev/null || true
    echo "──────────────────────────────────────────────"
    echo "🔴 provider 明确拒绝出图（不是超时，重试无效）："
    cat "$FAIL_JSON"
    echo "──────────────────────────────────────────────"
  fi
fi
''')
      }
    }

    stage('④ 去水印 + 尺寸归位 + 双版本') {
      when { expression { fileExists("${env.TS_RUN_DIR}/gen.ready") } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
GEN_SRC="$(cat "$TS_RUN_DIR/generated.path")"
EXTRA=""
[[ -n "${HERO_BAND:-}" ]] && EXTRA="$EXTRA --hero-band ${HERO_BAND} --body-mode ${BODY_MODE:-auto}"
EXTRA="$EXTRA --alpha-mode ${ALPHA_MODE:-source} --frame ${FRAME:-auto} --frame-rim ${FRAME_RIM:-warm} --watermark ${WATERMARK:-auto}"
"$BASH" .jenkins/lib/run_stage.sh --name "去水印与尺寸归位" \
  --group "美术资源链" --slug art-postprocess --timeout 600 \
  -- "$PY" scripts/image/restyle_pipeline.py postprocess \
       --work "$ART_WDIR" --gen "$GEN_SRC" $EXTRA
''')
      }
    }

    stage('⑤ 像素级验收') {
      when { expression { fileExists("${env.TS_RUN_DIR}/gen.ready") } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# rc=3 表示「硬项都过了，但有一处建议人看一眼」→ 只标黄
"$BASH" .jenkins/lib/run_stage.sh --name "像素级验收" \
  --group "美术资源链" --slug art-verify --timeout 300 --warn-rc 3 \
  -- "$PY" scripts/image/restyle_pipeline.py verify --work "$ART_WDIR"
''')
      }
    }

    stage('⑥ 替换原图（写回 + 原图搬出工程）') {
      // 🔴 布尔参数经 buildWithParameters 进来可能是字符串 "false"，Groovy 里非空字符串为真
      //    ⇒ 直接写 params.WRITE_BACK 会把「没勾」当成「勾了」，20:17 那轮就误覆盖了资源。
      //    统一按字符串比 'true'。
      // 🔴 2026-10-21 起默认**开**：图出完了就该落到资源上（原图进背包，可回滚），
      //    不再要求人每次手勾——#7 那轮就是「图出好了、资源没换」，白看一遍对比图。
      //    不想改工程里的资源时才显式传 false。
      when { expression { (params.WRITE_BACK ?: 'true').toString().toLowerCase() == 'true' && fileExists("${env.TS_RUN_DIR}/gen.ready") } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 🔴 写回顺序：先校验验收结论 → 原图搬进 BACKUP_ROOT → 再覆盖资源 → 复核哈希
BACKUP_DIR="${BACKUP_ROOT:-$PROJ/ResBackpack/备份}"
mkdir -p "$BACKUP_DIR"
echo "原图备份根：$BACKUP_DIR"
EXTRA=""
[[ -n "${BACKUP_ROOT:-}" ]] && EXTRA="$EXTRA --backup-root \"${BACKUP_ROOT}\" "
# 🔴 variant=auto：源 RGB→opaque / RGBA→alpha。以前写死 alpha，RGB 资源（没有透明区）
#    在这一步会假红；写死 opaque 又会把浮层的透明轮廓盖掉。
"$BASH" .jenkins/lib/run_stage.sh --name "替换原图（写回 + 原图入背包）" \
  --group "美术资源链" --slug art-publish --timeout 300 --warn-rc 3 \
  -- "$PY" scripts/image/restyle_pipeline.py publish \
       --work "$ART_WDIR" --variant auto --yes \
       --note "$JOB_NAME #$BUILD_NUMBER" $EXTRA

# 把「原图搬到哪了」写进证据：构建页一眼能看到备份路径与台账，不用去翻目录
"$PY" - "$ART_WDIR/state.json" "$TS_RUN_DIR/artifacts/published.json" <<'PYEOF'
import json, sys, pathlib
st = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
pub = st.get("published") or {}
pathlib.Path(sys.argv[2]).write_text(json.dumps(pub, ensure_ascii=False, indent=2), encoding="utf-8")
if pub:
    print(f"资源      : {pub['asset']}")
    print(f"原图备份  : {pub['backup']}  ({pub['backup_kind']})")
    print(f"写回哈希  : {pub['after_sha256'][:16]}…  {pub['size'][0]}x{pub['size'][1]} {pub['mode']}")
    print(f"回滚      : restyle_pipeline.py restore --asset {pub['asset']}")
PYEOF

if [[ -f "$TS_RUN_DIR/artifacts/published.json" ]] && "$PY" -c "import json,sys;sys.exit(0 if json.load(open('$TS_RUN_DIR/artifacts/published.json')) else 1)"; then
  BAK="$("$PY" -c "import json;print(json.load(open('$TS_RUN_DIR/artifacts/published.json'))['backup'])")"
  "$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
    --name "原图归档" --group "交付" --status pass \
    --detail "原图已搬出工程 → ${BAK#$PROJ/}"
  # 背包里到底存了什么，构建页直接看得到（别让人去猜路径对不对）
  echo "── 原图备份（$BACKUP_DIR） ──"
  find "$BACKUP_DIR" -type f -name '*.png' -newermt '-1 day' 2>/dev/null | sed "s|$PROJ/||" | head -10
  echo "🔴 写回 ≠ 进包：真机生效还要重打该资源所在 AssetBundle（FrameTool.BuildGameAssetBundles）"
  echo "🔴 不满意就回滚：$PY scripts/image/restyle_pipeline.py restore --asset ${ASSET}"
fi
''')
      }
    }

    stage('⑦ 证据与节点图归档') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 图要跟着构建走：构建页直接能看「改前/改后」，不用再去翻目录
"$PY" scripts/image/restyle_pipeline.py graph --work "$ART_WDIR" \
  --out "$TS_RUN_DIR/artifacts/graph.md" || true
if [[ -f "$ART_WDIR/state.json" ]]; then
  cp -f "$ART_WDIR/state.json" "$TS_RUN_DIR/artifacts/state.json" 2>/dev/null || true
fi
for f in "$ART_WDIR"/out/*.png "$ART_WDIR"/out/compare_before_after.jpg; do
  [[ -f "$f" ]] && cp -f "$f" "$TS_RUN_DIR/artifacts/" 2>/dev/null || true
done
{
  echo "本次产物："
  ls -1 "$TS_RUN_DIR/artifacts" 2>/dev/null | sed 's/^/  - /'
} | tee "$TS_RUN_DIR/artifacts/manifest.txt"
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "证据归档" --group "交付" --status pass \
  --detail "artifacts 已就绪（$(ls -1 "$TS_RUN_DIR/artifacts" 2>/dev/null | wc -l | tr -d ' ') 个文件）"
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
# workspace 不做 cleanWs，而 `cp -R` 只增不删 ⇒ 上几次构建的记录会被一起归档，
# 看起来像「同一个环节跑了两遍」（2026-10-12 TS-Client-Resources 踩过）。
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
        if (desc) { currentBuild.description = "${params.THEME} · ${desc}".toString() }

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
