/**@META
{
  "description": "服务端「代码发包正式服」全链路：预检（工作区/工具链/生产状态）→ **切 release 分支**（独立 worktree，主工作区零影响）→ JDK8 编译 → 产物校验 → **与线上 jar 逐条目 CRC 比对**（只注差异类，不整包覆盖）→ 人工审批 → 线上备份 → **配置表一起发（调 TS-Table-Sync：导表 + 增量同步，推完不重启）** → 注入 + 重启（新代码与新表同时生效）→ 上线自检 → **协议连通自检**（本地直连验证编解码/通道/鉴权/会话，端口在听 ≠ 协议通）→ **回写发布记录（提交+tag+push）** → 发布看板 → **异步触发 TS-Server-Health**。默认 DEPLOY=false：只构建+比对+记录，一个字节都不碰生产。历史上「package.sh 全量包覆盖线上 jar」已被证伪（会回退线上未上线改动、带走 conf/assets），本 job 固定以线上 jar 为基线做类级注入。",
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
    {"name":"SYNC_TABLES","type":"bool","default":true,"description":"🔴 发版前把**服务端配置表**一起发到线上（调 `TS-Table-Sync`：导表 → 增量同步 → 不重启）。默认开：服务器发版 = 代码 + 表 一次上完。表在 ⑨ 重启前推完，重启后新代码与新表同时生效（只踢一次线）。关掉则本次只发代码，表留在原样"},
    {"name":"PROTO_CHECK","type":"bool","default":true,"description":"发完包是否跑「协议连通自检」（编解码/端口/双向通道/鉴权/会话）：验证 TEA 帧、回包编码、鉴权没被绕过。端口在听 ≠ 协议通，这一步补的就是这个缺口"},
    {"name":"PROTO_LOGIN","type":"bool","default":false,"description":"🔴 协议自检是否做「真登录 + GM 命令」。默认关：生产上会用真实账号的 token 建会话，该号在线会被顶掉。只在指定了 PROTO_OPERATOR 且确认该号不在线时打开"},
    {"name":"PROTO_OPERATOR","type":"string","default":"","description":"PROTO_LOGIN=true 时用哪个 uid 发起（留空则该用例跳过）"},
    {"name":"HEALTH_AFTER","type":"bool","default":true,"description":"跑完是否异步触发 TS-Server-Health（生产服每日巡检同一个 job）。异步、不阻塞本次发布，结果去那个 job 看"},
    {"name":"API_TEST_AFTER","type":"bool","default":true,"description":"打包完成后是否自动跑**全量接口测试**（触发 TS-Api-Test：把 proto 里 372 个接口逐个真发一遍）。异步、不阻塞发布。用专用测试号发空参数请求，会顶掉该号的在线会话"},
    {"name":"API_TEST_SCOPE","type":"choice","choices":["全量","核心","只读"],"default":"全量","description":"接口测试的档位：全量=372 个全扫（约 6~9 分钟）；核心=主界面必需 11 个（约 30 秒）；只读=不写库的那批。拿不准就用全量"},
    {"name":"ALLOW_DIRTY","type":"bool","default":false,"description":"主工作区有未提交改动时是否继续。默认否（发布必须基于一次明确提交）。勾上后脏改动**不参与构建**，只在记录里列出来"},
    {"name":"PUSH_BRANCH","type":"bool","default":true,"description":"打包成功后把 release 分支 + 发布记录 + tag 一次原子推到 origin（演练也推：记录要能追溯）。连跑多次演练嫌远端分支多时关掉"},
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
          env.SR_SYNC_TABLES     = params.SYNC_TABLES.toString()
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
          // 发包后的两条收尾：协议自检（本地直连验证各协议）+ 异步触发生产巡检
          env.SR_PROTO_CHECK     = params.PROTO_CHECK.toString()
          env.SR_PROTO_LOGIN     = params.PROTO_LOGIN.toString()
          env.SR_PROTO_OPERATOR  = params.PROTO_OPERATOR.trim()
          env.SR_HEALTH_AFTER    = params.HEALTH_AFTER.toString()
          // 打包后的第三件事：全量接口测试（异步触发 TS-Api-Test）
          env.SR_API_AFTER       = params.API_TEST_AFTER.toString()
          env.SR_API_SCOPE       = params.API_TEST_SCOPE

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
  echo "协议自检   ：PROTO_CHECK=$SR_PROTO_CHECK  PROTO_LOGIN=$SR_PROTO_LOGIN  OPERATOR=${SR_PROTO_OPERATOR:-（未指定）}"
  echo "跑完巡检   ：HEALTH_AFTER=$SR_HEALTH_AFTER（异步触发 TS-Server-Health）"
  echo "接口测试   ：API_TEST_AFTER=$SR_API_AFTER  SCOPE=$SR_API_SCOPE（异步触发 TS-Api-Test）"
  echo "推送记录   ：$SR_PUSH（打包成功即推分支+tag，不区分演练/上线）"
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
   演练模式（DEPLOY=false）：只切 release 分支、编译、与线上比对、写记录并推送。
   生产服 /home/java 不会被写入；release 分支 + 记录 + tag 会推到 origin（PUSH_BRANCH=false 则不推）。
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
  配置表    : ${params.SYNC_TABLES ? '一起发（调 TS-Table-Sync：导表 + 增量同步，推完不重启，随本次重启生效）' : '不发（本次只动代码）'}
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

    // 🔴 2026-10-23 用户口径：**服务器发版 = 代码 + 配置表，一次发完**。
    //    所以这里直接调 `TS-Table-Sync`（它自带导表 → 增量同步 → 逐表结构体检），
    //    而不是让人另外去点一个 job。
    //    位置很关键：在 ⑧ 备份之后、⑨ 注入+重启之前 —— 表先落盘，重启时新代码与新表
    //    同时生效，而且**只踢一次线**。因此这里固定 RESTART=false，重启交给 ⑨ 统一做。
    //    propagate=true：表没同步成功就不许重启（宁可停在旧版本，也不要半新半旧）。
    stage('⑧-2 服务端配置表同步（调 TS-Table-Sync）') {
      when { expression { params.DEPLOY && params.ACTION == 'release' && params.SYNC_TABLES } }
      options { timeout(time: 40, unit: 'MINUTES') }
      steps {
        script {
          def tb = build job: 'TS-Table-Sync', wait: true, propagate: true, parameters: [
            string(name: 'SERVER_ENV',  value: '现网-129.226.213.65'),
            string(name: 'MODE',        value: 'apply'),
            booleanParam(name: 'EXPORT',      value: true),
            booleanParam(name: 'FIX_NUMERIC', value: false),
            booleanParam(name: 'RESTART',     value: false)
          ]
          echo "✅ 配置表已同步到线上：TS-Table-Sync #${tb.number}（${tb.result}）；重启由 ⑨ 统一执行"
        }
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

    stage('⑩-2 协议连通自检（发完包验证各协议）') {
      when { expression { params.DEPLOY && params.PROTO_CHECK } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
mkdir -p "$SR_RUN_DIR/release/proto"
# 为什么单独一档：⑩ 上线自检只证明「进程在、端口在听」，
# 证明不了 TEA 密钥/2 字节长度前缀/8 字节对齐/回包编码这几层还是对的。
# 客户端遇到这几层出错的表现是「连上就断」，而服务端日志只有一行 decode error。
ARGS=(--host 129.226.213.65 --port 16081 --ssh gs
      --json-out "$SR_RUN_DIR/release/proto/protocol.json")
# 真登录用例默认关闭：会拿真实账号的 token 建会话，该号在线就被顶掉。
if [[ "$SR_PROTO_LOGIN" == "true" && -n "$SR_PROTO_OPERATOR" ]]; then
  ARGS+=(--operator "$SR_PROTO_OPERATOR" --allow-login)
  echo "⚠️ 启用真登录用例：operator=$SR_PROTO_OPERATOR（该号若在线会被顶下线）"
fi
# --warn-rc 3：只有「关注项」不该把已经注入成功的发布判红（与 ⑩ 同口径）
"$BASH" "$SHARED/lib/run_stage.sh" --name "协议连通自检（编解码/通道/鉴权/会话）" \
  --group "发布" --slug proto --timeout 300 --warn-rc 3 \
  -- "$PY" scripts/verify/protocol_selftest.py "${ARGS[@]}"
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

    stage('⑬ 触发生产巡检（TS-Server-Health）') {
      when { expression { params.HEALTH_AFTER } }
      steps {
        script {
          // 同机同 Jenkins，直接 build 下游 job：不在这里写死 URL/token，
          // 权限走 Jenkins 自身的授权模型，也省掉「谁有权限触发」这一层扯皮。
          // wait:false —— 巡检要 SSH 采集、可能发信，不该把已经发完的包堵在这里。
          def hb = build job: 'TS-Server-Health',
            parameters: [booleanParam(name: 'SEND_MAIL', value: false),
                         string(name: 'TO', value: '')],
            wait: false, propagate: false
          def tag = ''
          try { tag = "#${hb.number}" } catch (ignored) { tag = '' }
          echo "已异步触发 TS-Server-Health ${tag}（不阻塞本次发布，结果去那个 job 看）"
          env.HEALTH_TAG = tag
          sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$PY" "$SHARED/lib/stage_report.py" add --run "$SR_RUN_DIR" \
  --name "触发生产巡检" --group "交付" --status pass \
  --detail "TS-Server-Health 已异步触发${HEALTH_TAG:-}（结果去该 job 看）"
''')
        }
      }
    }

    // 打完包之后的第三件事：**全量接口测试**。
    // 为什么放在这里、为什么是异步：
    //   ⑩ 上线自检只证明「进程在、端口在听」，⑩-2 协议自检只证明「这条链路通」，
    //   两者都回答不了「那 372 个接口里有没有哪个已经悄悄没了 handler」。
    //   发版当场扫一遍，坏在发版当场，而不是坏在玩家点到那个面板的时候。
    //   wait:false —— 全量档要 6~9 分钟，不该把已经发完的包堵在这里；
    //   结果去 TS-Api-Test 看，页面固定地址见该 job 的看板。
    stage('⑬-2 触发全量接口测试（TS-Api-Test）') {
      when { expression { params.API_TEST_AFTER } }
      steps {
        script {
          def at = build job: 'TS-Api-Test',
            parameters: [string(name: 'TARGET', value: '现网-129.226.213.65'),
                         string(name: 'SCOPE',  value: env.SR_API_SCOPE),
                         string(name: 'UID',    value: ''),
                         string(name: 'TIMEOUT', value: '1.5'),
                         string(name: 'BUDGET',  value: '900')],
            wait: false, propagate: false
          def tag = ''
          try { tag = "#${at.number}" } catch (ignored) { tag = '' }
          echo "已异步触发 TS-Api-Test ${tag}（档位 ${env.SR_API_SCOPE}，不阻塞本次发布）"
          env.API_TAG = tag
          sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 演练档要写明「测的是当前线上，不是本次构建产物」，否则看板会误导人
NOTE="TS-Api-Test 已异步触发${API_TAG:-}（档位 ${SR_API_SCOPE}）"
if [[ "$SR_DEPLOY" != "true" ]]; then
  NOTE="$NOTE；本次是演练，测的是当前线上，不是本次构建产物"
fi
"$PY" "$SHARED/lib/stage_report.py" add --run "$SR_RUN_DIR" \
  --name "触发全量接口测试" --group "交付" --status pass --detail "$NOTE"
''')
        }
      }
    }

    stage('⑭ 完成通知') {
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
        def pushed = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" -c "import json,sys;print(json.load(open(sys.argv[1],encoding='utf-8')).get('pushed',''))" \
  "$SR_RUN_DIR/release/meta.json" 2>/dev/null || true
''').trim()
        def state = params.DEPLOY ? '🔴 已上线' : '演练'
        def marks = []
        if (br)    { marks << br }
        if (params.ACTION == 'release') { marks << "注入 ${sel} 条" }
        marks << state
        // 记录去向要写进描述：光有分支名不够，得知道它在不在远端
        if (pushed == 'True' || pushed == 'true') { marks << '记录已推 origin' }
        else if (params.PUSH_BRANCH) { marks << '记录仅本地' }
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
