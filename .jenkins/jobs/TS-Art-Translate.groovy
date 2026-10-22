/**@META
{
  "description": "中文美术字 → 英文版流水线，四族资源共用一条链。① 战令横幅（ArtFont_zh/OperatingPanelAtlas/*_bg_zh.png，884x544）：标题+两行文案烘进图里，走写死的三段版面锚点；② 图集大图（Atlas/<面板>/*.png）：中文标题烘在一块纯色黑板上，走白字核+纯色板自动定位；③ 美术字块（ArtFont_zh/** 小型单色图，如 180x96 的页签）：只有纯白字 + alpha，本地排字会换掉笔画风格 ⇒ 必须交给模型重绘；④ 活动海报（**/banner/*_zh.png，884x856 不透明）：插画+斜切彩带+两行美术字，没有纯色底板可补也没锚点可写死 ⇒ 整幅交给模型重绘，再等比 cover 回原尺寸。出图方式由 PROVIDER 决定：chatgpt_web（默认，Chrome 登录态 / AdsPower 换号链驱动 chatgpt.com 出图）/ local（纯 OpenCV+PIL，可复现）/ manual（人交图）。无论谁画的，归位（尺寸/alpha/字块 bbox）、验收（尺寸/透明边/墨迹量/纯白/落位）、写回 ArtFont_en + .meta 都是同一套本地硬断言（写回一律平铺在族目录根，且校验目标目录在 resPathList 白名单里，否则当场 rc=1 —— 未登记的目录重扫会整目录跳过，是「图就位但真机白图」的唯一成因）。缺哪张补哪张，已存在的不动。译文对不对需要人眼看：glyph 与整幅图重绘都会把验收标黄（硬项全过但无 OCR 闸门）。",
  "concurrent": false,
  "params": [
    {"name":"MODE","type":"choice","choices":["batch","one"],"default":"batch","description":"batch=扫描全量（ArtFont_zh 横幅全目录 + 译名表里的 Atlas/glyph/poster 白名单），只补缺英文版且译名表里有条目的；one=只做 ASSET 指定的那一张"},
    {"name":"ASSET","type":"string","default":"","description":"MODE=one 时必填：源图相对工程根的路径。横幅如 Assets/ManagedResources/ArtFont_zh/OperatingPanelAtlas/cn2-X1_zhanling_mota_bg_zh.png；图集如 Assets/ManagedResources/Atlas/LaddersTypePanelAtlas/cn2-X1_kuafu_rukou.png；字块如 Assets/ManagedResources/ArtFont_zh/DynamicActivityPanelAtlas/tab/cn2-X1_zhutihuodong_yuanliaoshouji_01_zh.png；海报如 Assets/ManagedResources/ArtFont_zh/DynamicActivityPanelAtlas/banner/cn2-X1_ciyuanyinqing_banner_zh.png"},
    {"name":"PROVIDER","type":"choice","choices":["chatgpt_web","local","manual"],"default":"chatgpt_web","description":"出图方式。chatgpt_web=参考绘图管线：打开 Chrome/AdsPower 用 GPT 重绘（消耗包月额度，额度用尽自动换号）；local=原来的纯本地像素工序（只能做横幅/图集大图，字块/海报会被跳过）；manual=人把图放进 GEN_IMAGE（留空则输出提示词等人出图）"},
    {"name":"GEN_IMAGE","type":"string","default":"","description":"PROVIDER=manual 时显式指定出图（相对工程根或绝对路径）；留空则只生成参考图与提示词，不写回"},
    {"name":"CDP_PORT","type":"string","default":"","description":"复用已在运行的已登录浏览器（AdsPower/SunBrowser）的调试端口，find_browser_cdp.py 反查。留空=用本机 Chrome 的登录态副本"},
    {"name":"ADSPOWER_PROFILES","type":"string","default":"","description":"换号顺序（逗号分隔的 AdsPower user_id，排最前）。留空=按额度台账自动排。🔴 号池有 6 个但换号链默认只试 3 个，要覆盖就得显式写这里"},
    {"name":"FORCE","type":"boolean","default":false,"description":"已有英文版的也重做（会先把旧图备份到 ResBackpack/备份 再覆盖）。改了口径/译名时才勾"},
    {"name":"WRITE","type":"boolean","default":true,"description":"验收通过后写回 Assets/ManagedResources/ArtFont_en/... 并补 .meta。传 false 则只出图、不动工程里的资源（构建页的 compare.png 照样能看）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    // 出图那一步要等模型（单张 3~8 分钟，额度用尽还要换号），30 分钟装不下两张 —— 宽到 75
    timeout(time: 75, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '60', numToKeepStr: '40'))
  }

  environment {
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 环境与清单体检') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.TR_ONLY = ''
          if (params.MODE == 'one') {
            def asset = (params.ASSET ?: '').trim()
            if (!asset) {
              error('MODE=one 时必须填 ASSET')
            }
            // 路径写错 / 指到别的目录时，②③④ 会因为「目标 0 张」全绿 —— 假绿球。
            // 所以先在这里把源图存在性钉死，再谈翻译。
            if (!fileExists("${env.PROJ}/${asset}")) {
              error("ASSET 不存在：${asset}\n（要相对工程根的完整路径，如 Assets/ManagedResources/Atlas/LaddersTypePanelAtlas/cn2-X1_kuafu_rukou.png）")
            }
            // 两种命名都要认：战令横幅带 _zh.png，Atlas 图集里的图没有后缀。
            def base = asset.replaceAll('^.*/', '').replaceAll('\\.png$', '')
            if (base.endsWith('_zh')) {
              base = base.substring(0, base.length() - 3)
            }
            env.TR_ONLY = base
          }
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs" "$TS_RUN_DIR/artifacts"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "模式：$MODE   ${TR_ONLY:+只做 $TR_ONLY   }强制重做：$FORCE   写回资源：$WRITE"
  echo "出图：${PROVIDER}${CDP_PORT:+  CDP=${CDP_PORT}}${ADSPOWER_PROFILES:+  号序=${ADSPOWER_PROFILES}}"
  echo ""
  echo "🔴 中文是烘进图里的艺术字（带发光/渐变/立体阴影），不是 TMP 文本 —— 只能重出一张图。"
  echo "🔴 四族共用一条链，靠源图自身特征自动分派（尺寸带互不重叠）："
  echo "     ArtFont_zh/** 884x544 横幅 → artfont 族（三段文字，版面锚点写死）"
  echo "     Atlas/**                   → atlas 族（中文压在一块纯色黑板上，白字核+纯色板自动定位）"
  echo "     ArtFont_zh/** 小型单色图   → glyph 族（纯白字+alpha 的页签/竖排标题，只能模型重绘）"
  echo "     **/banner/*.png 884x856    → poster 族（插画+彩带+两行字，整幅重绘后 cover 回原尺寸）"
  echo "🔴 出图那一步不可复现、要花额度 ⇒ 单独摘出去：provider 只负责「把图给我」，"
  echo "     尺寸 / alpha / 字块落位 / 验收 / 写回全部是本地硬断言（与 TS-Art-Restyle 同一套切法）。"
  echo "🔴 喂给模型的参考图是「合成到深底的版本」：原始 PNG 是白字+透明底，"
  echo "     浏览器按白底预览 ⇒ 模型看到一张白纸，画出来必然是白底白字。"
  echo "🔴 模型出的图要**归位**：等比缩进源图字块 bbox（不是拉伸、不是整幅 cover），再抠墨迹 → 纯白 + alpha。"
  echo "🔴 擦字一律按像素判据圈区域，不按矩形硬切 —— 硬切会把暗板/图集装饰切出直边。"
  echo "🔴 artfont 族第三行「累计返利 __ 倍」不排：已上线的 pata_bg_en / shenyuan_bg_en 都把它删了，留给 UI 动态数字。"
  echo "🔴 写回路径：**平铺在族目录根**（ArtFont_en/<族目录>/<名>_en.png），zh 侧的 tab/ banner/ 子目录一律压平。"
  echo "     既有 60+ 张 en 图全是这个布局；而 ArtFont_en/DynamicActivityPanelAtlas/tab 这种子目录"
  echo "     根本不在 ResourcePathConfig.resPathList（868 条手工白名单，一个目录=一个 AB）里 ⇒"
  echo "     重扫整目录跳过 ⇒ resName 不登记 ⇒ 图就位了也白图。publish 现在会当场拦下这种路径。"
  echo "🔴 写回 ≠ 进包：真机生效还要重打该资源所在 AssetBundle（FrameTool.BuildGameAssetBundles）。"
  echo "     publish 会顺手查 resName 是否已在 resInfoList，没登记就打 ⏳ 提示该重打哪个目录。"
  echo "🔴 字块写回只是「英文图就位」；客户端真显示英文还要求调用点走 GetPictureFont(...)"
  echo "     ＋ 该 resName 在 ResourcePathConfig.asset 有登记 —— 缺一步都是白图。"
  echo "🔴 译文对不对没有自动闸门（手写美术字 OCR 不可靠）⇒ 出图族的验收会标黄，必须人眼看 compare.png。"
} | tee "$TS_RUN_DIR/context.txt"
''')
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 这里是「开工前的盘点」，永远算通过（--strict-ok）：
# 有活要干不是缺陷，本轮的最终颜色交给 ⑤ 的「收尾清单」定。
"$BASH" .jenkins/lib/run_stage.sh --name "开工盘点" \
  --group "美术翻译链" --slug tr-scan --timeout 120 \
  -- "$PY" scripts/image/banner_translate.py scan --strict-ok
''')
      }
    }

    stage('② 生成英文图（出图 + 归位）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
ONLY=""
[[ -n "${TR_ONLY:-}" ]] && ONLY="--only ${TR_ONLY}"
FORCE_ARG=""
[[ "${FORCE:-false}" == "true" ]] && FORCE_ARG="--force"
# 出图方式：chatgpt_web 要开浏览器等模型，单张 3~8 分钟 ⇒ 给到 2400s（与 TS-Art-Restyle 一致）
PROV_ARGS="--provider ${PROVIDER:-chatgpt_web}"
[[ -n "${GEN_IMAGE:-}" ]] && PROV_ARGS="${PROV_ARGS} --gen-image ${GEN_IMAGE}"
[[ -n "${CDP_PORT:-}" ]] && PROV_ARGS="${PROV_ARGS} --cdp-port ${CDP_PORT}"
[[ -n "${ADSPOWER_PROFILES:-}" ]] && PROV_ARGS="${PROV_ARGS} --adspower-profiles ${ADSPOWER_PROFILES}"
# shellcheck disable=SC2086
"$BASH" .jenkins/lib/run_stage.sh --name "生成英文图" \
  --group "美术翻译链" --slug tr-run --timeout 2400 --warn-rc 3 \
  -- "$PY" scripts/image/banner_translate.py batch --stage run \
       --run "$TS_RUN_DIR" $ONLY $FORCE_ARG $PROV_ARGS
''')
      }
    }

    stage('③ 像素级验收') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
ONLY=""
[[ -n "${TR_ONLY:-}" ]] && ONLY="--only ${TR_ONLY}"
FORCE_ARG=""
[[ "${FORCE:-false}" == "true" ]] && FORCE_ARG="--force"
# 断言口径按「provider 出的图 × family 的画法」两维选：
#   local + artfont = 尺寸/alpha/重建区外零改动/粉色标题零残留/黄色文案零残留/英文白字已落版
#   local + atlas   = 尺寸/alpha/重建区外零改动/板内墨迹零残留/板底平整/英文白字已落版/板外条带无残字
#   chatgpt_web + glyph = 尺寸/四角仍透明/墨迹量/纯白 RGB255/主体不是小标记（字形 IoU 只记录）
#   chatgpt_web + poster = 尺寸/alpha/确实重画过/没有整幅重画/色差可控/上 45% 彩带区动过
#   chatgpt_web + 整幅图 = 尺寸/alpha/确实重画过/没有整幅重画/色差可控
# 最后一条「译文对不对」没有自动闸门 ⇒ 出图族登记 warn，构建标黄，等人看 compare.png。
# shellcheck disable=SC2086
"$BASH" .jenkins/lib/run_stage.sh --name "像素级验收" \
  --group "美术翻译链" --slug tr-verify --timeout 300 \
  -- "$PY" scripts/image/banner_translate.py batch --stage verify \
       --run "$TS_RUN_DIR" $ONLY $FORCE_ARG
''')
      }
    }

    stage('④ 写回资源（ArtFont_en + .meta）') {
      // 布尔参数经 buildWithParameters 进来可能是字符串 "false"，
      // Groovy 里非空字符串为真 ⇒ 统一按字符串比 'true'（TS-Art-Restyle 踩过这个坑）
      when { expression { (params.WRITE ?: 'true').toString().toLowerCase() == 'true' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
ONLY=""
[[ -n "${TR_ONLY:-}" ]] && ONLY="--only ${TR_ONLY}"
FORCE_ARG=""
[[ "${FORCE:-false}" == "true" ]] && FORCE_ARG="--force"
# shellcheck disable=SC2086
"$BASH" .jenkins/lib/run_stage.sh --name "写回英文版资源" \
  --group "交付" --slug tr-publish --timeout 300 --warn-rc 3 \
  -- "$PY" scripts/image/banner_translate.py batch --stage publish \
       --run "$TS_RUN_DIR" $ONLY $FORCE_ARG
''')
      }
    }

    stage('⑤ 收尾复核与证据归档') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 收尾再盘一次：还有没翻的横幅就标黄（这才是「本轮有没有干完」的结论），
# 全齐了就绿。WRITE=false 时图只落在 _output，这里自然会黄。
"$BASH" .jenkins/lib/run_stage.sh --name "收尾清单" \
  --group "交付" --slug tr-left --timeout 120 --warn-rc 3 \
  -- "$PY" scripts/image/banner_translate.py scan --quiet

# 中英对照图要跟着构建走：构建页直接能看「这张翻成什么样」，不用去翻 _output
shopt -s nullglob
for d in "$PROJ"/_output/art_translate/*/; do
  name="$(basename "$d")"
  for f in compare.png out.png state.json; do
    [[ -f "$d$f" ]] && cp -f "$d$f" "$TS_RUN_DIR/artifacts/${name}__${f}" 2>/dev/null || true
  done
done
shopt -u nullglob
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
# workspace 不做 cleanWs，而 cp -R 只增不删 ⇒ 上几次的证据会被一起归档，
# 看起来像「同一个环节跑了两遍」，所以每次都重建 evidence/
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
        if (desc) { currentBuild.description = "${params.MODE} · ${desc}".toString() }

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
