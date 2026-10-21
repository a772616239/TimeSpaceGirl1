/**@META
{
  "description": "美术资源「底部紫色虚化」——纯确定性像素工序，**不调 AI 出图**。把一张已定稿大图的下沿做「渐进高斯模糊 + 过渡到紫色 + 末行 alpha 收到 0」，让横幅溶进紫色面板而不是一条硬切线。像素回归验收（带以上零改动 / 带内变虚变紫 / 底边不再硬切）全进 JUnit，可选写回资源（原图先入背包，可 restore）。",
  "concurrent": false,
  "params": [
    {"name":"ASSET","type":"string","default":"Assets/ManagedResources/Atlas/FindTreasureMainPanelAtlas/cn2-X1_xunluo_peitu.png","description":"要虚化的资源（相对工程根）。只处理下沿，上方像素一个都不动"},
    {"name":"PX","type":"string","default":"130","description":"虚化带宽（像素）。130 ≈ 436 高的 30%；超过图高一半会被工具直接拒绝（那不是化边是毁图）"},
    {"name":"RIM","type":"choice","choices":["violet","ivory","warm"],"default":"violet","description":"虚化落在哪个色系（复用卡框色板）：violet=紫（紫色面板，默认）；ivory=冷银白；warm=暖金"},
    {"name":"WRITE_BACK","type":"boolean","default":true,"description":"替换原图（默认开）：验收通过后把成品写回资源，原图先搬出工程到 BACKUP_ROOT（.meta 不动），可 restore 回滚。传 false 只出图不改工程"},
    {"name":"BACKUP_ROOT","type":"string","default":"","description":"原图备份根目录。留空=ResBackpack/备份（按资源相对路径镜像，_manifest.jsonl 记台账）"},
    {"name":"COMPRESS","type":"choice","choices":["auto","lossless","off"],"default":"auto","description":"交付前压体积：auto=无损优先，超过原图体积才降位深；lossless=只重编码；off=跳过。虚化把细节抹掉了，通常会比原图小，但渐变区怕位深掉太狠"},
    {"name":"COMPRESS_MAX_DIFF","type":"string","default":"6","description":"降位深允许的最大通道差（0-255）。默认 6——虚化带是平滑渐变，调到 8 以上容易在紫色过渡里看出台阶"},
    {"name":"FORCE","type":"boolean","default":false,"description":"已经虚化过的图也照样再叠一层。默认关：工具会判「底边已经是软的」并拒绝，避免跑第二次紫色越叠越重、细节越叠越糊却一声不报"}
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
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.FADE_ASSET  = params.ASSET
          // 工作目录按资源名分桶：同一张图不同带宽/色系的样张能并存对比
          def assetName = params.ASSET.split('/').last().replace('.png', '')
          env.FADE_WDIR = "${env.PROJ}/_output/art_fade/${assetName}"
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs" "$TS_RUN_DIR/artifacts"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "资源：$FADE_ASSET"
  echo "带宽：${PX:-130}px   色系：${RIM:-violet}   写回：${WRITE_BACK:-true}   压缩：${COMPRESS:-auto}"
  echo "产出目录：$FADE_WDIR"
  echo ""
  echo "🔴 这是确定性像素工序，不调用任何 AI 出图：构图/人物/文案全部保持，只改下沿。"
  echo "🔴 所以它没有「额度」和「随机性」两个失败源，可反复重跑——但重跑前请 restore："
  echo "   已经在虚化带上再叠一层，只会紫色更重、细节更糊。工具默认拦这一步。"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('② 底部虚化 + 像素验收') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
EXTRA=""
[[ "${FORCE:-false}" == "true" ]] && EXTRA="$EXTRA --force"
# rc=3 = 「这张图已经虚化过，拒绝叠加」→ 标黄，不该把整条流水线染红
"$BASH" .jenkins/lib/run_stage.sh --name "底部虚化与像素验收" \
  --group "美术资源链" --slug art-fade --timeout 600 --warn-rc 3 \
  -- "$PY" scripts/image/bottom_fade.py \
       --asset "$FADE_ASSET" --px "${PX:-130}" --rim "${RIM:-violet}" \
       --compress "${COMPRESS:-auto}" --compress-max-diff "${COMPRESS_MAX_DIFF:-6}" $EXTRA

if [[ -f "$FADE_WDIR/fade.json" ]]; then
  cp -f "$FADE_WDIR/fade.json" "$TS_RUN_DIR/artifacts/fade.json"
  for f in "$FADE_WDIR"/*.png "$FADE_WDIR"/compare_fade.jpg; do
    [[ -f "$f" ]] && cp -f "$f" "$TS_RUN_DIR/artifacts/" || true
  done
fi
''')
      }
    }

    stage('③ 写回资源（原图入背包）') {
      // 🔴 布尔参数经 buildWithParameters 进来可能是字符串 "false"，Groovy 里非空字符串为真
      //    ⇒ 一律按字符串比 'true'（TS-Art-Restyle 20:17 那轮就因此误覆盖过资源）。
      when { expression { (params.WRITE_BACK ?: 'true').toString().toLowerCase() == 'true' && fileExists("${env.FADE_WDIR}/fade.json") } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
BACKUP_DIR="${BACKUP_ROOT:-$PROJ/ResBackpack/备份}"
mkdir -p "$BACKUP_DIR"
echo "原图备份根：$BACKUP_DIR"
EXTRA=""
[[ -n "${BACKUP_ROOT:-}" ]] && EXTRA="$EXTRA --backup-root \"${BACKUP_ROOT}\" "
# 只写回、不重新加工：加工那一步的产物已经在 ② 里过验收，这里失败就该单独红
"$BASH" .jenkins/lib/run_stage.sh --name "写回资源（原图入背包）" \
  --group "美术资源链" --slug art-fade-publish --timeout 300 --warn-rc 3 \
  -- "$PY" scripts/image/bottom_fade.py \
       --asset "$FADE_ASSET" --px "${PX:-130}" --rim "${RIM:-violet}" \
       --publish-only --note "$JOB_NAME #$BUILD_NUMBER" $EXTRA

echo "🔴 写回 ≠ 进包：真机生效还要重打该资源所在 AssetBundle（FrameTool.BuildGameAssetBundles）"
echo "🔴 不满意就回滚：$PY scripts/image/restyle_pipeline.py restore --asset $FADE_ASSET --list"
''')
      }
    }

    stage('④ 证据归档') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 表1 里这条图有没有记过 soft_bottom：顺手核对，省得下次换主题时又踩「底部太虚放不下元素」
"$PY" - "$TS_RUN_DIR/artifacts/table1_flags.txt" <<'PYEOF' || true
import json, sys, pathlib
sys.path.insert(0, "scripts/image")
import table1
data = table1.load()
name = "cn2-X1_xunluo_peitu.png"
out = []
for it in data["items"]:
    sb = it.get("soft_bottom")
    if sb:
        out.append(f"{pathlib.Path(it['asset']).name}: soft_bottom {sb.get('soft_px')}px "
                   f"({sb.get('mid_band_mean')} -> {sb.get('band_mean')} 高频)")
    ops = it.get("post_ops") or []
    if ops:
        out.append(f"{pathlib.Path(it['asset']).name}: post_ops=" +
                   ",".join(o.get("op", "?") for o in ops[-4:]))
text = "\\n".join(out) or "(表1 里没有 soft_bottom / post_ops 记录)"
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
        if (desc) { currentBuild.description = "${params.RIM} ${params.PX}px · ${desc}".toString() }

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
