/**@META
{
  "description": "美术资源「套外框」——纯确定性像素工序，**不调 AI 出图**。给一张已定稿的 UI 图套上游戏自己的卡框语言（亮边 + 墨带 + 菱形网纹 + 45° 切角，参考道具槽/英雄卡/对话框），画面等比缩进框内、画布尺寸不变。紫框=亮边选 violet。像素回归验收（尺寸不变 / 亮边成环 / 四角硬切 / 内框=原图等比缩进 / 框带含网纹）全进 JUnit，可选写回资源（原图先入背包，可 restore）。",
  "concurrent": false,
  "params": [
    {"name":"ASSET","type":"string","default":"Assets/ManagedResources/ArtFont_en/SevenDayCarnivalPanelV2Atlas/cn2-X1_qiri_biaoti_en.png","description":"要套框的资源（相对工程根）。框只画在画布内侧，尺寸不变"},
    {"name":"STYLE","type":"choice","choices":["card","gold"],"default":"card","description":"card=游戏卡框（亮边+墨带+菱形纹+切角，游戏里到处是这套语言，默认）；gold=旧红金雕花框（圆徽章+鎏金剖面，游戏里找不到这套语言，仅兜底）"},
    {"name":"RIM","type":"choice","choices":["violet","warm","ivory","none"],"default":"violet","description":"卡框最外那道亮边（跟道具槽一致的「暗带+亮边」）：violet=紫白（紫色面板同色系，默认）；warm=暖金（圣诞等暖色主题）；ivory=银白；none=不画亮边——🔴 深色面板(17,17,25)上墨带跟底色同亮度，框会直接看不见"},
    {"name":"RATIO","type":"string","default":"0.022","description":"框宽 = 短边 × 该比例。默认 0.022（1080x568 → 16px，与换风格管线 postprocess 的 card 口径一致）；想更明显用 0.028~0.032。越界（<0.005 或 >0.08）工具直接拒绝"},
    {"name":"HAIRLINE","type":"boolean","default":false,"description":"带内侧再加一道细线。默认关：亮边+内细线挤在窄带里会变成相框式双线"},
    {"name":"WRITE_BACK","type":"boolean","default":true,"description":"替换原图（默认开）：验收通过后把成品写回资源，原图先搬出工程到 BACKUP_ROOT（.meta 不动），可 restore 回滚。传 false 只出图不改工程"},
    {"name":"BACKUP_ROOT","type":"string","default":"","description":"原图备份根目录。留空=ResBackpack/备份（按资源相对路径镜像，_manifest.jsonl 记台账）"},
    {"name":"COMPRESS","type":"choice","choices":["auto","lossless","off"],"default":"auto","description":"交付前压体积：auto=无损优先，超过原图体积才降位深；lossless=只重编码；off=跳过。框带是平涂+网纹，降位深过头会出摩尔纹"},
    {"name":"COMPRESS_MAX_DIFF","type":"string","default":"8","description":"降位深允许的最大通道差（0-255）。默认 8"},
    {"name":"FORCE","type":"boolean","default":false,"description":"已经套过框的图也照样再套一层。默认关：工具会判「外沿已是暗描边+亮边」并拒绝，避免画面被再缩 0.96、框带叠框带却一声不报"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 15, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '40'))
  }

  environment {
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 参数与上下文') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR  = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.FRAME_ASSET = params.ASSET
          // 工作目录按资源名分桶：同一张图不同「样式/色板/带宽」的样张要能并存对比
          def assetName = params.ASSET.split('/').last().replace('.png', '')
          env.FRAME_WDIR = "${env.PROJ}/_output/art_frame/${assetName}"
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs" "$TS_RUN_DIR/artifacts"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "资源：$FRAME_ASSET"
  echo "样式：${STYLE:-card}   亮边：${RIM:-violet}   带宽比例：${RATIO:-0.022}   写回：${WRITE_BACK:-true}"
  echo "产出目录：$FRAME_WDIR"
  echo ""
  echo "🔴 这是确定性像素工序，不调用任何 AI 出图：构图/人物/文案全部保持，只加一道外框。"
  echo "🔴 框的画法是「画面等比缩进框内」（缩 ~0.96、四周各让出一圈框带），不是把框盖在画面上——"
  echo "   贴边的艺术字才不会被框咬掉字角。"
  echo "🔴 重跑前请先 restore：已经在框上再套一层，等于画面再缩一圈、框带叠框带。工具默认拦这一步。"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('② 套框 + 像素验收') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
EXTRA=""
[[ "${FORCE:-false}" == "true" ]] && EXTRA="$EXTRA --force"
[[ "${HAIRLINE:-false}" == "true" ]] && EXTRA="$EXTRA --hairline"
# rc=3 = 「这张图已经套过框，拒绝叠加」→ 标黄，不该把整条流水线染红
"$BASH" .jenkins/lib/run_stage.sh --name "套框与像素验收" \
  --group "美术资源链" --slug art-frame --timeout 600 --warn-rc 3 \
  -- "$PY" scripts/image/frame_draw.py \
       --asset "$FRAME_ASSET" --style "${STYLE:-card}" --rim "${RIM:-violet}" \
       --ratio "${RATIO:-0.022}" --compress "${COMPRESS:-auto}" \
       --compress-max-diff "${COMPRESS_MAX_DIFF:-8}" $EXTRA

if [[ -f "$FRAME_WDIR/frame.json" ]]; then
  cp -f "$FRAME_WDIR/frame.json" "$TS_RUN_DIR/artifacts/frame.json"
  for f in "$FRAME_WDIR"/*.png "$FRAME_WDIR"/compare_frame.jpg; do
    [[ -f "$f" ]] && cp -f "$f" "$TS_RUN_DIR/artifacts/" || true
  done
fi
''')
      }
    }

    stage('③ 写回资源（原图入背包）') {
      // 🔴 布尔参数经 buildWithParameters 进来可能是字符串 "false"，Groovy 里非空字符串为真
      //    ⇒ 一律按字符串比 'true'（TS-Art-Restyle 就因此误覆盖过资源）。
      when { expression { (params.WRITE_BACK ?: 'true').toString().toLowerCase() == 'true' && fileExists("${env.FRAME_WDIR}/frame.json") } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
BACKUP_DIR="${BACKUP_ROOT:-$PROJ/ResBackpack/备份}"
mkdir -p "$BACKUP_DIR"
echo "原图备份根：$BACKUP_DIR"
EXTRA=""
[[ -n "${BACKUP_ROOT:-}" ]] && EXTRA="$EXTRA --backup-root \"${BACKUP_ROOT}\" "
# 只写回、不重新绘制：绘制那一步的产物已经在 ② 里过验收，这里失败就该单独红
"$BASH" .jenkins/lib/run_stage.sh --name "写回资源（原图入背包）" \
  --group "美术资源链" --slug art-frame-publish --timeout 300 --warn-rc 3 \
  -- "$PY" scripts/image/frame_draw.py \
       --asset "$FRAME_ASSET" --style "${STYLE:-card}" --rim "${RIM:-violet}" \
       --ratio "${RATIO:-0.022}" --publish-only --note "$JOB_NAME #$BUILD_NUMBER" $EXTRA

echo "🔴 写回 ≠ 进包：真机生效还要重打该资源所在 AssetBundle（FrameTool.BuildGameAssetBundles）"
echo "🔴 不满意就回滚：$PY scripts/image/restyle_pipeline.py restore --asset $FRAME_ASSET --list"
''')
      }
    }

    stage('④ 证据归档') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 台账核对：这次套框有没有落进 _manifest.jsonl、表1 有没有 touch 到该资源
"$PY" - "$TS_RUN_DIR/artifacts/frame_ledger.txt" "$FRAME_ASSET" <<'PYEOF' || true
import json, sys, pathlib
out = []
mf = pathlib.Path("ResBackpack/备份/_manifest.jsonl")
asset = sys.argv[2]
if mf.is_file():
    for line in mf.read_text(encoding="utf-8").splitlines()[-200:]:
        try:
            r = json.loads(line)
        except Exception:
            continue
        if r.get("asset") == asset:
            out.append(f"{r.get('at')} {r.get('op','?')} "
                       f"{r.get('style','')}/{r.get('rim','')} ratio={r.get('ratio','')} "
                       f"write_back={r.get('write_back')}")
text = "\\n".join(out[-8:]) or "(台账里没有这张图的记录)"
pathlib.Path(sys.argv[1]).write_text(text + "\\n", encoding="utf-8")
print(text)
PYEOF

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
        if (desc) { currentBuild.description = "${params.STYLE} ${params.RIM} ratio ${params.RATIO} · ${desc}".toString() }

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
