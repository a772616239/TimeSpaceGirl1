/**@META
{
  "description": "客户端资源链：Lua 源码 → LuaBytes 字节码的同步与一致性核验，外加 AssetBundle 就绪体检。真机跑的是预编译字节码，只改 ~Lua/*.lua 不会有任何报错但真机不生效 —— 这个 job 就是那道防呆。AB 重建仍走 GUI（本 job 只体检不重建，与项目既有约定一致）。",
  "concurrent": false,
  "params": [
    {"name":"ACTION","type":"choice","choices":["check","sync"],"default":"check","description":"check=只检查源码与字节码是否一致（只读）；sync=把改动重编成字节码后再复核一次"},
    {"name":"LUA_FILES","type":"text","default":"","description":"要处理的 lua 文件（每行一个或空格分隔）。留空 = 自动取 git 里已改动/未跟踪的 ~Lua/*.lua"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 30, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '40'))
  }

  environment {
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 准备与取证') {
      steps {
        script {
          // 显式声明工程根，别依赖共享库退回 $PWD（写清楚比靠默契稳）
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.TS_ACTION  = params.ACTION
          env.TS_FILES   = params.LUA_FILES.trim().replaceAll('\\s+', ' ')
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "动作：$TS_ACTION"
  echo "目标 lua：${TS_FILES:-（自动：git 里已改动的 ~Lua/*.lua）}"
  echo ""
  echo "🔴 背景：真机跑 Assets/ManagedResources/LuaBytes/<路径下划线化>_64.bytes，"
  echo "   只有 Editor 才回落到 ~Lua/*.lua。只改源码 = Editor 有效、真机无效且不报错。"
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('② 源码 ↔ 字节码 一致性（改前基线）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
if [[ -n "${TS_FILES:-}" ]]; then
  "$BASH" .jenkins/lib/run_stage.sh --name "字节码一致性（指定文件）" \
    --group "Lua 字节码链" --slug lua-check --timeout 600 \
    -- "$BASH" scripts/lua-bytes-sync.sh --check $TS_FILES
else
  "$BASH" .jenkins/lib/run_stage.sh --name "字节码一致性（git 改动集）" \
    --group "Lua 字节码链" --slug lua-check --timeout 600 \
    -- "$BASH" scripts/lua-bytes-sync.sh --check
fi
''')
      }
    }

    stage('③ 重编字节码（sync）') {
      when { expression { params.ACTION == 'sync' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 🔴 lua-bytes-sync.sh 内部自带「重编后再比一次」的自检，所以它 rc=0 就意味着字节码已同步
if [[ -n "${TS_FILES:-}" ]]; then
  "$BASH" .jenkins/lib/run_stage.sh --name "重编 Lua 字节码（指定文件）" \
    --group "Lua 字节码链" --slug lua-sync --timeout 900 \
    -- "$BASH" scripts/lua-bytes-sync.sh $TS_FILES
else
  "$BASH" .jenkins/lib/run_stage.sh --name "重编 Lua 字节码（git 改动集）" \
    --group "Lua 字节码链" --slug lua-sync --timeout 900 \
    -- "$BASH" scripts/lua-bytes-sync.sh
fi
''')
      }
    }

    stage('④ 重编后复核') {
      when { expression { params.ACTION == 'sync' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
if [[ -n "${TS_FILES:-}" ]]; then
  "$BASH" .jenkins/lib/run_stage.sh --name "重编后复核" \
    --group "Lua 字节码链" --slug lua-recheck --timeout 600 \
    -- "$BASH" scripts/lua-bytes-sync.sh --check $TS_FILES
else
  "$BASH" .jenkins/lib/run_stage.sh --name "重编后复核" \
    --group "Lua 字节码链" --slug lua-recheck --timeout 600 \
    -- "$BASH" scripts/lua-bytes-sync.sh --check
fi
''')
      }
    }

    stage('⑤ AssetBundle 就绪体检') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "AssetBundle 就绪体检" \
  --group "资源链" --slug ab-ready --timeout 600 \
  -- "$BASH" scripts/check_ab_ready.sh
''')
      }
    }

    stage('⑥ 归档变更清单与提交清单') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
mkdir -p "$TS_RUN_DIR/artifacts"
{
  echo "== git 状态（~Lua 与 LuaBytes）=="
  git status --porcelain -- Assets/ManagedResources/~Lua Assets/ManagedResources/LuaBytes || true
  echo
  echo "== 本次应成对提交的文件 =="
  git status --porcelain -- Assets/ManagedResources/~Lua Assets/ManagedResources/LuaBytes \
    | awk '{print $NF}' || true
  echo
  echo "🔴 提交规则：~Lua/*.lua 与对应 LuaBytes/*_64.bytes 必须成对提交，"
  echo "   只提交源码 = 真机不生效（不会有任何报错）。"
} | tee "$TS_RUN_DIR/artifacts/change-list.txt"
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "变更清单" --group "交付" --status pass \
  --detail "已写出 change-list.txt"
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
# workspace 不做 cleanWs，而 `cp -R` 只增不删 ⇒ 上几次构建的 stages/*.json 会被一起归档，
# 看起来像「同一个环节跑了两遍」。实测 2026-10-12 构建#5 的归档里混进了 #3/#4 的记录。
# 只删本 job 自己的 evidence/（$WORKSPACE 已由 Jenkins 设置，且只在非空时动手）。
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
