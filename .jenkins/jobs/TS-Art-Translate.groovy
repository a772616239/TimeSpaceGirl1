/**@META
{
  "description": "中文美术字 → 英文版流水线，两族资源共用一条链。① 战令横幅（ArtFont_zh/OperatingPanelAtlas/*_bg_zh.png，884x544）：标题+两行文案烘进图里，走写死的三段版面锚点；② 图集大图（Atlas/<面板>/*.png）：中文标题烘在一块纯色黑板上，走白字核+纯色板自动定位，板内填纯色、板外条带从上方取样。都是「自动圈污染区擦字 → 补底板 → 排白字 → 像素级验收（尺寸/alpha/中文残留/背景未动）→ 写回 ArtFont_en 并补 .meta」，写回路径统一是 ArtFont_en/<同族目录>/<名>_en.png。缺哪张补哪张，已存在的不动。",
  "concurrent": false,
  "params": [
    {"name":"MODE","type":"choice","choices":["batch","one"],"default":"batch","description":"batch=扫描全量（ArtFont_zh 横幅全目录 + 译名表里的 Atlas 白名单），只补缺英文版且译名表里有条目的；one=只做 ASSET 指定的那一张"},
    {"name":"ASSET","type":"string","default":"","description":"MODE=one 时必填：源图相对工程根的路径。横幅如 Assets/ManagedResources/ArtFont_zh/OperatingPanelAtlas/cn2-X1_zhanling_mota_bg_zh.png；图集如 Assets/ManagedResources/Atlas/LaddersTypePanelAtlas/cn2-X1_kuafu_rukou.png"},
    {"name":"FORCE","type":"boolean","default":false,"description":"已有英文版的也重做（会先把旧图备份到 ResBackpack/备份 再覆盖）。改了口径/译名时才勾"},
    {"name":"WRITE","type":"boolean","default":true,"description":"验收通过后写回 Assets/ManagedResources/ArtFont_en/... 并补 .meta。传 false 则只出图、不动工程里的资源（构建页的 compare.png 照样能看）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
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
  echo ""
  echo "🔴 中文是烘进图里的艺术字（带发光/渐变/立体阴影），不是 TMP 文本 —— 只能重出一张图。"
  echo "🔴 两族共用一条链，靠源图所在目录自动分派："
  echo "     ArtFont_zh/**  → artfont 族（884x544 三段横幅，版面锚点写死）"
  echo "     Atlas/**       → atlas 族（中文压在一块纯色黑板上，白字核+纯色板自动定位）"
  echo "🔴 擦字一律按像素判据圈区域，不按矩形硬切 —— 硬切会把暗板/图集装饰切出直边。"
  echo "🔴 板外条带（字越过板沿那几行）用「同行左右背景镜像平铺」补，不带亮度："
  echo "     整条上移会把上方装饰线搬到板沿；inpaint 会吸板内白字、补出一片发亮的糊。"
  echo "🔴 artfont 族第三行「累计返利 __ 倍」不排：已上线的 pata_bg_en / shenyuan_bg_en 都把它删了，留给 UI 动态数字。"
  echo "🔴 写回 ≠ 进包：真机生效还要重打该资源所在 AssetBundle（FrameTool.BuildGameAssetBundles）。"
  echo "🔴 atlas 族写回只是「英文图就位」；客户端真显示英文还要求调用点走 GetPictureFont(...)"
  echo "     ＋ 该 resName 在 ResourcePathConfig.asset 有登记 —— 缺一步都是白图。"
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

    stage('② 生成英文图（擦字 + 补底板 + 排字）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
ONLY=""
[[ -n "${TR_ONLY:-}" ]] && ONLY="--only ${TR_ONLY}"
FORCE_ARG=""
[[ "${FORCE:-false}" == "true" ]] && FORCE_ARG="--force"
# shellcheck disable=SC2086
"$BASH" .jenkins/lib/run_stage.sh --name "生成英文图" \
  --group "美术翻译链" --slug tr-run --timeout 900 --warn-rc 3 \
  -- "$PY" scripts/image/banner_translate.py batch --stage run \
       --run "$TS_RUN_DIR" $ONLY $FORCE_ARG
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
# 断言两族不同口径：artfont = 尺寸/alpha/重建区外零改动/粉色标题零残留/黄色文案零残留/英文白字已落版
#                    atlas   = 尺寸/alpha/重建区外零改动/板内墨迹零残留/板底平整/英文白字已落版/板外条带无残字
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
