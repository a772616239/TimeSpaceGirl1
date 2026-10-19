/**@META
{
  "description": "服务端「代码发包正式服」全链路：预检（工作区/工具链/生产状态）→ **切 release 分支**（独立 worktree，主工作区零影响）→ JDK8 编译 → 产物校验 → **与线上 jar 逐条目 CRC 比对**（只注差异类，不整包覆盖）→ 人工审批 → 线上备份 → 注入 + 重启 → 上线自检 → **回写发布记录（提交+tag+push）** → 发布看板。默认 DEPLOY=false：只构建+比对+记录，一个字节都不碰生产。历史上「package.sh 全量包覆盖线上 jar」已被证伪（会回退线上未上线改动、带走 conf/assets），本 job 固定以线上 jar 为基线做类级注入。",
  "concurrent": false,
  "keep": [90, 60],
  "artifactKeep": 12,
  "artifactDays": 45,
  "params": [
    {"name":"ACTION","type":"choice","choices":["release","rollback"],"default":"release","description":"release=出包发布（切分支/编译/差异/注入/自检/记录）；rollback=按最近一次备份恢复并重启（同样需要 DEPLOY=true + 手打确认）"},
    {"name":"SOURCE_BRANCH","type":"string","default":"x1-tag-1.2.2","description":"release 分支从哪个分支切出来（服务端仓库 Server_x1tag1.2.2 的分支名）"},
    {"name":"RELEASE_BRANCH","type":"string","default":"","description":"指定 release 分支名。留空=自动 release/x1-<版本>-<YYYYMMDD-HHmm>。已有同名分支会被拒绝（防止重跑污染记录）"},
    {"name":"DEPLOY","type":"bool","default":false,"description":"🔴 是否真的动生产：勾上才会 备份→注入→重启。默认不勾 = 演练（只切分支+编译+差异+记录，生产零改动）"},
    {"name":"CONFIRM","type":"string","default":"","description":"🔴 DEPLOY 勾上后必须在这里原样输入「正式服」（回滚时输入「回滚」），防止下拉框/手滑"},
    {"name":"AUTO_APPROVE","type":"bool","default":false,"description":"部署前审批闸门是否自动放行。默认否 = 停在页面上等人点「确认部署」；设 true 才会无人值守跑完"},
    {"name":"ONLY_CLASSES","type":"string","default":"","description":"只注入匹配这些 glob 的条目（逗号分隔，如 com/ljsd/jieling/handler/*）。留空 = 注入全部差异。热修口径用它收窄"},
    {"name":"EXCLUDE_CLASSES","type":"string","default":"","description":"额外排除的 glob（逗号分隔）。留空使用默认排除：META-INF/*、application*.properties、*.properties、*.xml（这些**永不**自动注入）"},
    {"name":"RESTART","type":"choice","choices":["gameserver","none","all"],"default":"gameserver","description":"注入后重启什么。gameserver=只重启游戏服（会踢线，约 40s）；none=只落地不生效（等下次重启）；all=另外拉起 chatserver（该服默认没跑，谨慎）"},
    {"name":"ALLOW_DIRTY","type":"bool","default":false,"description":"主工作区有未提交改动时是否继续。默认否（发布必须基于一次明确提交）。勾上后脏改动**不参与构建**，只在记录里列出来"},
    {"name":"PUSH_BRANCH","type":"bool","default":true,"description":"真上线时把 release 分支 + 发布记录 + tag 推到 origin。演练一律不推（不留垃圾分支）"},
    {"name":"ROLLBACK_DIR","type":"string","default":"","description":"ACTION=rollback 时指定备份目录（如 /home/java/gameserver/deploy-staging/20261019-2013/backup）。留空 = 取生产上最新的那个"},
    {"name":"NOTES","type":"string","default":"","description":"本次发布说明（会写进发布记录、构建描述与看板）"},
    {"name":"SEND_MAIL","type":"bool","default":false,"description":"是否在结束后发一封完成邮件（默认不发）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 60, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '90', numToKeepStr: '60'))
  }

  environment {
    PROJ   = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY     = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH   = '/usr/local/bin/bash'
    SHARED = '/Users/wangxufeng/Documents/jenkins-shared'
    SR_SRC = '/Users/wangxufeng/Documents/TimeSpaceGirl1/TimeSpaceServer/Server_x1tag1.2.2'
  }

  stages {

    stage('① 参数与影响说明') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.STAGE_RUN_DIR      = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.SR_RUN_DIR         = env.STAGE_RUN_DIR
          env.SR_SRC_REPO        = env.SR_SRC
          env.SR_SOURCE_BRANCH   = params.SOURCE_BRANCH.trim()
          env.SR_RELEASE_BRANCH  = params.RELEASE_BRANCH.trim()
          env.SR_DEPLOY          = params.DEPLOY.toString()
          env.SR_RESTART         = params.RESTART
          env.SR_ONLY            = params.ONLY_CLASSES.trim()
          env.SR_EXCLUDE         = params.EXCLUDE_CLASSES.trim()
          env.SR_ALLOW_DIRTY     = params.ALLOW_DIRTY.toString()
          env.SR_PUSH            = params.PUSH_BRANCH.toString()
          env.SR_NOTES           = params.NOTES
          env.SR_ROLLBACK_DIR    = params.ROLLBACK_DIR.trim()
          env.SR_JOB             = env.JOB_NAME
          env.SR_BUILD           = env.BUILD_NUMBER
          env.SR_URL             = env.BUILD_URL
          env.SR_OPERATOR        = "${env.BUILD_USER_ID ?: 'jenkins'}"
          env.SR_ACTION          = params.ACTION
          env.SR_AUTO_APPROVE    = params.AUTO_APPROVE.toString()

          // 🔴 闸门一：动生产必须手打确认词。放在最前面，避免跑完 6 个环节才被拒。
          if (params.ACTION == 'rollback') {
            if (!params.DEPLOY || params.CONFIRM.trim() != '回滚') {
              echo "（回滚模式：DEPLOY=${params.DEPLOY} / CONFIRM='${params.CONFIRM.trim()}'）"
              if (params.DEPLOY) {
                error("拒绝回滚：DEPLOY=true 时必须在 CONFIRM 里原样输入「回滚」，当前为 '${params.CONFIRM.trim()}'。")
              }
            }
          } else if (params.DEPLOY && params.CONFIRM.trim() != '正式服') {
            error("拒绝上线：DEPLOY=true 时必须在 CONFIRM 里原样输入「正式服」，"
                + "当前为 '${params.CONFIRM.trim()}'。这是防手滑的最后一道。")
          }
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$SR_RUN_DIR/logs" "$SR_RUN_DIR/release"

REPO_HEAD="$(git -C "$SR_SRC_REPO" rev-parse --short "$SR_SOURCE_BRANCH" 2>/dev/null || echo '?')"
REPO_SUB="$(git -C "$SR_SRC_REPO" log -1 --format=%s "$SR_SOURCE_BRANCH" 2>/dev/null || echo '?')"
DIRTY="$(git -C "$SR_SRC_REPO" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"

MODE="演练（只构建+比对+记录）"
[[ "$SR_DEPLOY" == "true" ]] && MODE="🔴 真上线（备份→注入→重启）"
[[ "$SR_ACTION" == "rollback" ]] && MODE="🔴 回滚（恢复备份→重启）"

{
  echo "运行       ：$JOB_NAME #$BUILD_NUMBER"
  echo "时间       ：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "动作       ：$SR_ACTION / $MODE"
  echo "服务端仓库 ：$SR_SRC_REPO"
  echo "源分支     ：$SR_SOURCE_BRANCH @ $REPO_HEAD  ($REPO_SUB)"
  echo "工作区脏项 ：$DIRTY 项（ALLOW_DIRTY=$SR_ALLOW_DIRTY）"
  echo "release分支：${SR_RELEASE_BRANCH:-（自动生成）}"
  echo "注入口径   ：ONLY='${SR_ONLY:-全部差异}' EXCLUDE='${SR_EXCLUDE:-默认排除}'"
  echo "重启范围   ：$SR_RESTART"
  echo "审批       ：AUTO_APPROVE=$SR_AUTO_APPROVE  DEPLOY=$SR_DEPLOY"
  echo "推送分支   ：$SR_PUSH"
  echo "说明       ：${SR_NOTES:-（空）}"
  echo "证据目录   ：$SR_RUN_DIR"
} | tee "$SR_RUN_DIR/context.txt"
''')
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 只读提示：把「这次会动什么」摆在最前面，比事后解释有效
if [[ "$SR_DEPLOY" == "true" ]]; then
  cat <<'EOS'

  ============================================================================
   🔴 本次会写生产：/home/java/gameserver（gameSrv jar + lib/gamecommon）
      流程：备份 → 按差异注入 class → 重启 → 自检。重启会踢掉在线玩家。
  ============================================================================

EOS
else
  cat <<'EOS'

  ----------------------------------------------------------------------------
   演练模式（DEPLOY=false）：只切 release 分支、编译、与线上比对、写记录。
   生产服 /home/java 不会被写入；不会在远端产生 release 分支。
  ----------------------------------------------------------------------------

EOS
fi
''')
      }
    }

    stage('② 发布前预检') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" "$SHARED/lib/run_stage.sh" --name "发布前预检（仓库/工具链/生产状态）" \
  --group "预检" --slug preflight --timeout 300 --warn-rc 3 \
  -- "$BASH" .jenkins/lib/server_release.sh preflight
''')
      }
    }

    stage('③ 切 release 分支（独立 worktree）') {
      when { expression { params.ACTION == 'release' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 🔴 worktree 而不是 checkout：服务端主工作区常年被并行会话改着，
#    在主工作区切分支会把人家的 WIP 一起带走；独立 worktree 让
#    「release 分支 = 编译产物」这句话成立，且主工作区零影响。
"$BASH" "$SHARED/lib/run_stage.sh" --name "切 release 分支并记录源提交" \
  --group "发布记录" --slug branch --timeout 600 \
  -- "$BASH" .jenkins/lib/server_release.sh branch
''')
      }
    }

    stage('④ 编译（JDK8 + gradle）') {
      when { expression { params.ACTION == 'release' } }
      options { timeout(time: 30, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" "$SHARED/lib/run_stage.sh" --name "编译 serverlogic / chatserver（JDK8）" \
  --group "构建" --slug build --timeout 1800 \
  -- "$BASH" .jenkins/lib/server_release.sh build
''')
      }
    }

    stage('⑤ 产物校验') {
      when { expression { params.ACTION == 'release' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" "$SHARED/lib/run_stage.sh" --name "产物校验（完整性/字节码/注入边界）" \
  --group "构建" --slug verify --timeout 300 \
  -- "$BASH" .jenkins/lib/server_release.sh verify
''')
      }
    }

    stage('⑥ 与线上逐条目差异') {
      when { expression { params.ACTION == 'release' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# rc=3 = 本次没有任何差异（可能是重复发布）⇒ 黄球而不是红球
"$BASH" "$SHARED/lib/run_stage.sh" --name "与线上 jar 逐条目 CRC 比对" \
  --group "差异" --slug diff --timeout 600 --warn-rc 3 \
  -- "$BASH" .jenkins/lib/server_release.sh diff
''')
      }
    }

    stage('⑦ 部署审批闸门') {
      when { expression { params.DEPLOY } }
      steps {
        script {
          def sel = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
cat "$SR_RUN_DIR/release/meta.json" 2>/dev/null >/dev/null || true
"$PY" -c "import json,sys;d=json.load(open(sys.argv[1],encoding='utf-8'));print(d.get('selected_total','?'))" \
  "$SR_RUN_DIR/release/meta.json" 2>/dev/null || echo "?"
''').trim()
          def br = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
cat "$SR_RUN_DIR/release/release_branch.txt" 2>/dev/null || echo "（未切分支/回滚模式）"
''').trim()
          def conn = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
sed -n 's/^conn=//p' "$SR_RUN_DIR/release/remote-before.txt" 2>/dev/null || true
''').trim()

          def msg = """即将对【生产服 129.226.213.65 / home/java】执行写操作，请确认：

  动作      : ${params.ACTION == 'rollback' ? '回滚到备份' : '按差异注入 class'}
  release分支: ${br}
  注入条目  : ${sel} 个（gameSrv / gamecommon / chatserver 分别见差异报告）
  重启范围  : ${params.RESTART}${params.RESTART == 'none' ? '（只落地，不生效）' : '（会踢线）'}
  在线连接  : ${conn ?: '?'} 条（重启时这些玩家会被断开）
  发布说明  : ${params.NOTES ?: '（空）'}

确认无误请点「确认部署」；不想动点「中止」。"""

          if (params.AUTO_APPROVE) {
            echo "⏭ 审批闸门自动放行（AUTO_APPROVE=true）"
            echo msg
          } else {
            input message: msg, ok: '确认部署'
          }
        }
      }
    }

    stage('⑧ 线上备份') {
      when { expression { params.DEPLOY && params.ACTION == 'release' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" "$SHARED/lib/run_stage.sh" --name "线上备份（jar + config + MD5SUMS）" \
  --group "发布" --slug backup --timeout 600 \
  -- "$BASH" .jenkins/lib/server_release.sh backup
''')
      }
    }

    stage('⑨ 注入差异条目 + 重启') {
      when { expression { params.DEPLOY && params.ACTION == 'release' } }
      options { timeout(time: 25, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 命名锁：同一时刻只允许一次服务端写操作（手工 deploy 也应自觉取这把锁）
"$BASH" "$SHARED/lib/run_stage.sh" --name "注入差异条目并重启" \
  --group "发布" --slug deploy --timeout 1500 \
  -- "$BASH" .jenkins/lib/lock.sh --name gameserver run \
       --who "$JOB_NAME #$BUILD_NUMBER" --timeout 900 -- \
       "$BASH" .jenkins/lib/server_release.sh deploy
''')
      }
    }

    stage('⑨-2 回滚（恢复备份 + 重启）') {
      when { expression { params.DEPLOY && params.ACTION == 'rollback' } }
      options { timeout(time: 25, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" "$SHARED/lib/run_stage.sh" --name "回滚：恢复备份并重启" \
  --group "发布" --slug rollback --timeout 1500 \
  -- "$BASH" .jenkins/lib/lock.sh --name gameserver run \
       --who "$JOB_NAME #$BUILD_NUMBER" --timeout 900 -- \
       "$BASH" .jenkins/lib/server_release.sh rollback
''')
      }
    }

    stage('⑩ 上线自检') {
      when { expression { params.DEPLOY } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" "$SHARED/lib/run_stage.sh" --name "上线自检（实例/端口/认证/OOM/注入复核）" \
  --group "发布" --slug health --timeout 900 \
  -- "$BASH" .jenkins/lib/server_release.sh health
''')
      }
    }

    stage('⑪ 回写发布记录（提交 + tag + push）') {
      when { expression { params.ACTION == 'release' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" "$SHARED/lib/run_stage.sh" --name "回写发布记录并按需推送" \
  --group "发布记录" --slug record --timeout 600 --warn-ok \
  -- "$BASH" .jenkins/lib/server_release.sh record
''')
      }
    }

    stage('⑫ 发布看板') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" "$SHARED/lib/run_stage.sh" --name "生成发布看板 HTML" \
  --group "交付" --slug dashboard --timeout 180 \
  -- "$PY" .jenkins/lib/server_release.py html \
       --run "$SR_RUN_DIR" --out "$SR_RUN_DIR/release/release-report.html"
# 固定地址：方便收藏/回看最近一次（与 TestPackage 的 APK 固定链接同一套路）
mkdir -p "$HOME/.jenkins/userContent"
cp -f "$SR_RUN_DIR/release/release-report.html" \
      "$HOME/.jenkins/userContent/TS-Server-Release-latest.html" 2>/dev/null || true
echo "看板固定地址：http://localhost:8080/userContent/TS-Server-Release-latest.html"
''')
      }
    }

    stage('⑬ 完成通知') {
      when { expression { params.SEND_MAIL } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# --warn-rc 4：发信抖一下不该把已经成功的发布判红
"$BASH" "$SHARED/lib/run_stage.sh" --name "发布结果邮件" \
  --group "通知" --slug notify --timeout 300 --warn-rc 4 \
  -- "$PY" "$SHARED/lib/notify.py" release \
       --run-dir "$SR_RUN_DIR" --job "$JOB_NAME" --build "$BUILD_NUMBER" \
       --url "$BUILD_URL" --result "${SR_RESULT_HINT:-SUCCESS}" \
       --field 动作 "$SR_ACTION" --field 上线 "$SR_DEPLOY" --field 重启 "$SR_RESTART"
''')
      }
    }
  }

  post {
    always {
      script {
        // worktree 必须无条件回收：它是整棵仓库的检出（含 1.7 万文件），漏一次就白占几百 MB
        sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" 2>/dev/null || true
[[ -n "${SR_RUN_DIR:-}" ]] && "$BASH" .jenkins/lib/server_release.sh cleanup >/dev/null 2>&1 || true
''')

        sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" 2>/dev/null || true
mkdir -p "$SR_RUN_DIR/logs"
"$PY" "$SHARED/lib/stage_report.py" junit --run "$SR_RUN_DIR" \
  --out "$SR_RUN_DIR/junit.xml" --suite "$JOB_NAME" || true
"$PY" "$SHARED/lib/stage_report.py" summary --run "$SR_RUN_DIR" \
  --out "$SR_RUN_DIR/summary.md" --title "$JOB_NAME #$BUILD_NUMBER" || true
# 看板在 post 再刷一次：此时 health/record 都已落盘，页面数据才是完整的
# （⑫ 里生成的那份会少「回写记录」「上线自检」两条环节）
"$PY" .jenkins/lib/server_release.py html --run "$SR_RUN_DIR" \
  --out "$SR_RUN_DIR/release/release-report.html" >/dev/null 2>&1 || true
mkdir -p "$HOME/.jenkins/userContent"
cp -f "$SR_RUN_DIR/release/release-report.html" \
      "$HOME/.jenkins/userContent/TS-Server-Release-latest.html" 2>/dev/null || true
# workspace 不 cleanWs，而 cp -R 只增不删 ⇒ 上几次构建的 stages/*.json 会一起归档（坑 6）
if [[ -n "${WORKSPACE:-}" && -d "$WORKSPACE/evidence" ]]; then
  rm -rf "$WORKSPACE/evidence"
fi
mkdir -p "$WORKSPACE/evidence"
cp -R "$SR_RUN_DIR/." "$WORKSPACE/evidence/" 2>/dev/null || true
# 构建产物与线上基线 jar 不进归档：都可复现，md5 已写进 diff/*.json 与发布记录。
# 不剔掉的话每次构建归档 34MB，12 份保留 ≈ 400MB（纯浪费）。
rm -f "$WORKSPACE"/evidence/release/build/*.jar "$WORKSPACE"/evidence/release/stage/*.tgz 2>/dev/null || true
rm -f "$WORKSPACE"/evidence/release/remote/*.jar 2>/dev/null || true
rm -rf "$WORKSPACE"/evidence/release/worktree 2>/dev/null || true
# 运行目录同样清理（它是「取证目录」而不是 jar 仓库）
rm -f "$SR_RUN_DIR"/release/build/*.jar "$SR_RUN_DIR"/release/remote/*.jar 2>/dev/null || true
rm -f "$SR_RUN_DIR"/release/stage/*.tgz 2>/dev/null || true
''')

        if (fileExists("${WORKSPACE}/evidence/junit.xml")) {
          junit allowEmptyResults: true, skipPublishingChecks: true, testResults: 'evidence/junit.xml'
        }

        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" "$SHARED/lib/stage_report.py" desc --run "$SR_RUN_DIR" 2>/dev/null || true
''').trim()
        def br = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
cat "$SR_RUN_DIR/release/release_branch.txt" 2>/dev/null | sed 's|release/||'
''').trim()
        def sel = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" -c "import json,sys;print(json.load(open(sys.argv[1],encoding='utf-8')).get('selected_total','?'))" \
  "$SR_RUN_DIR/release/meta.json" 2>/dev/null || echo "?"
''').trim()
        def state = params.DEPLOY ? '🔴 已上线' : '演练'
        def marks = []
        if (br)    { marks << br }
        if (params.ACTION == 'release') { marks << "注入 ${sel} 条" }
        marks << state
        if (params.NOTES?.trim()) { marks << params.NOTES.trim() }
        currentBuild.description = (desc ? "${desc} | " : "") + marks.join(' · ')

        def st = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" "$SHARED/lib/stage_report.py" status --run "$SR_RUN_DIR" 2>/dev/null || echo pass
''').trim()
        if (st == 'warn' && currentBuild.currentResult == 'SUCCESS') {
          currentBuild.result = 'UNSTABLE'
        }

        archiveArtifacts allowEmptyArchive: true,
          artifacts: 'evidence/**', fingerprint: false
      }
    }
  }
}
