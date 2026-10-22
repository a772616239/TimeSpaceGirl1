/**@META
{
  "description": "**服务器配置表发版**（只碰服务端，不出客户端包）：代码同步 → 导表（xlsx→客户端 Lua + 服务端 txt）→ int 列脏数据归一化（可选）→ **把服务端 txt 增量同步到指定环境**（逐表结构体检、推前整目录备份、推后双向 md5 校验）→ 可选重启服务端让表生效。🔴 这个 job 与客户端打包解耦：`TS-Android-Release` 只管出包，表由这里单独发。同步目标按 SERVER_ENV 从 `scripts/build_envs.json` 的 `tableTargets` 取（现网→gs、测试服→local、正式服已下线→跳过）。MODE=plan 只体检不写任何服务端。",
  "concurrent": false,
  "keep": [30, 30],
  "params": [
    {"name":"SERVER_ENV","type":"choice","choices":["现网-129.226.213.65","测试服","正式服"],"default":"现网-129.226.213.65","description":"把表推到哪套服务端（映射见 scripts/build_envs.json 的 tableTargets）。现网=129.226.213.65 的 gs；测试服=本机 ~/home/java/gameserver；正式服按用户口径也等于 129.226.213.65 ⇒ 同样是 gs（但该条 serverUrl 仍写着已死的 103.151.173.99，只影响出包，不影响推表）"},
    {"name":"MODE","type":"choice","choices":["apply","plan"],"default":"apply","description":"apply=真推（推前整目录 tar.gz 备份、推后 conf/server 与 assets/conf/server 双向 md5 校验、只推自上次同步以来的差异）；plan=只体检，不动任何服务端（改完表想先看会推什么就选它）"},
    {"name":"EXPORT","type":"bool","default":true,"description":"先跑一遍导表（Unity batchmode，约 4 分钟）再同步。默认开：这样推的是**刚导出来的**表。关掉则直接推仓库里现存的 TimeSpaceServer txt（只想补推、不想重导时用）"},
    {"name":"FIX_NUMERIC","type":"bool","default":false,"description":"推前把 int 列服务端解析不了的值就地归一化（Excel 浮点噪声 740.0000000000006 / 越界 9999999999 / 整数列写小数 1.25 ⇒ Java (int) 截断 + int32 夹取）。🔴 一个坏单元格 = 整张表不加载，历史上炸过一次（2026-10-22）。默认关，改了 xlsx 且怀疑有脏数据时勾"},
    {"name":"RESTART","type":"bool","default":false,"description":"推完重启该环境的游戏服让表生效（**线上会踢线**）。不勾 = 表只落盘，服务端仍用内存里的旧值，要等下次重启/维护窗口。MODE=plan 时无效"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 60, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '40'))
  }

  environment {
    // 🔴 打包目录 = 独立 clone（TimeSpaceGirl1-build）：开发目录开着 Unity 也能导表，
    //    同步靠 ①-1 的 ci_sync.sh（fetch + reset + 资产/服务端表/基线镜像）。
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1-build'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 准备与取证') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR    = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.TS_SERVER_ENV = params.SERVER_ENV
          env.TS_MODE       = params.MODE
          env.TS_EXPORT     = params.EXPORT.toString()
          env.TS_FIXNUM     = params.FIX_NUMERIC.toString()
          env.TS_RESTART    = params.RESTART.toString()
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "目标环境：$TS_SERVER_ENV   模式：$TS_MODE   先导表：$TS_EXPORT"
  echo "int 列归一化：$TS_FIXNUM   推完重启：$TS_RESTART"
  echo ""
  echo "🔴 为什么单独一个 job：客户端表（lua/AB）走 git，服务端表（conf/server txt）走"
  echo "   TimeSpaceServer 影子目录，两条路本来没打通。以前「发线上包」顺手推表 ⇒ 出包与"
  echo "   改线上数值耦合在一次操作里，风险不可控。现在表在这里单独发，发包只管客户端。"
  echo "🔴 同步目标不是写死的：按 SERVER_ENV 从 scripts/build_envs.json 的 tableTargets 取。"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('①-1 代码同步（打包目录 pull）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 打包目录无条件向 origin/<分支> 对齐：stash 快照本地残留 → reset --hard
# → 镜像 .secrets/ keystore/ TimeSpaceServer/（服务端表真源）与 table_sync 基线
"$BASH" .jenkins/lib/run_stage.sh --name "代码同步（fetch+reset+资产镜像）" \
  --group "同步" --slug ci-sync --timeout 1800 \
  -- "$BASH" .jenkins/ci_sync.sh
''')
      }
    }

    stage('② 导表（Unity batchmode）') {
      when { expression { params.EXPORT } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 🔴 --sync-tables off：导表完**不要**让 resource_build.sh 自己顺手推表。
#    推不推、推给谁、要不要重启，全部由本 job 后面的环节按参数决定；
#    否则 MODE=plan 也会被这一步偷偷写成真推（2026-10-23 拆 job 时明确）。
# 🔴 不要在这里再套 lock.sh --name unity：resource_build.sh 自己会 exec 自身套同一把锁，
#    外层再套 = 自己等自己（flock 不可重入）。
"$BASH" .jenkins/lib/run_stage.sh --name "导表（xlsx→Lua+txt）" \
  --group "表构建" --slug export-tables --timeout 1800 \
  -- "$BASH" scripts/resource_build.sh --action export --sync-tables off
''')
      }
    }

    stage('③ int 列脏数据归一化（可选）') {
      when { expression { params.FIX_NUMERIC } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 只报告 + 落盘：--fix-numeric 默认只报告，--apply-fix 才改文件。
# 🔴 改的是 TimeSpaceServer 影子目录里的 txt（git 跟踪），跑完记得提交。
"$BASH" .jenkins/lib/run_stage.sh --name "int 列归一化（浮点噪声/越界/小数）" \
  --group "表构建" --slug fix-numeric --timeout 600 \
  -- "$PY" scripts/table_sync.py --fix-numeric --apply-fix
''')
      }
    }

    stage('④ 服务端表同步（表×目标逐个体检）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
ARGS="--env $TS_SERVER_ENV"
if [[ "$TS_MODE" == "apply" ]]; then
  ARGS="$ARGS --apply --yes"
  [[ "$TS_RESTART" == "true" ]] && ARGS="$ARGS --restart"
fi
# shellcheck disable=SC2086  # 参数里不含空格，按词拆分正是本意
"$BASH" .jenkins/lib/run_stage.sh --name "服务端表同步（$TS_SERVER_ENV · $TS_MODE）" \
  --group "表发布" --slug table-sync --timeout 1800 \
  -- "$PY" scripts/table_sync.py $ARGS
''')
      }
    }

    stage('⑤ 结果清单') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
mkdir -p "$TS_RUN_DIR/artifacts"
REPORT="$(ls -t build/table_sync/reports/sync_*.md 2>/dev/null | head -1 || true)"
{
  echo "== 本次同步报告 =="
  echo "${REPORT:-（没有报告：table_sync 没跑到落报告这一步）}"
  echo
  if [[ -n "$REPORT" && -f "$REPORT" ]]; then
    sed -n '1,60p' "$REPORT"
  fi
  echo
  echo "== 影子目录里被改动的表（git 工作区，记得提交）=="
  git status --porcelain -- TimeSpaceServer 2>/dev/null || true
  echo
  echo "== 基线（各目标上次同步到哪个指纹）=="
  if [[ -f build/table_sync/state.json ]]; then
    "$PY" - <<'PYEOF'
import json
st = json.load(open('build/table_sync/state.json', encoding='utf-8'))
for name, rec in (st.get('targets') or {}).items():
    print('  %-6s last_sync_at=%s  记录 %d 张' % (name, rec.get('last_sync_at', '-'), len(rec.get('sig') or {})))
PYEOF
  else
    echo "  （无基线文件）"
  fi
  echo
  echo "🔴 不勾 RESTART 的话表只落盘：服务端要重启/维护窗口后才用新数值。"
} | tee "$TS_RUN_DIR/artifacts/table-sync-report.txt"
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "结果清单" --group "交付" --status pass \
  --detail "已写出 table-sync-report.txt"
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
