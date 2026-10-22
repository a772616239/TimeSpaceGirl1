/**@META
{
  "description": "包内资源构建：**导表（xlsx→客户端 Lua + 服务端 txt）→ 同步 Lua 字节码 → 处理 AssetBundle（重建 / 复用上一轮缓存）并复制到 StreamingAssets → 新鲜度硬闸门 + 就绪体检**。这三步长期是人肉 GUI 点按钮，Jenkins 只能体检不能执行 ⇒ 改了 xlsx 忘了导表、导了表忘了重建 AB，包照打不误、真机才暴露。本 job 把它们收成可被别的 job 调用的一环（TS-Android-Release 的「资源准备」就是调它）。🔴 AB 处理会决定 StreamingAssets 里的 version.txt 快照，所以必须传 SERVER_ENV。**AB_MODE=复用缓存** 不启动 Unity，直接用打包目录上一轮重建的 AB（秒级），只适用于「资源没动、只想重新出包」。",
  "concurrent": false,
  "keep": [30, 30],
  "params": [
    {"name":"EXPORT_TABLES","type":"bool","default":true,"description":"导表：遍历 data_execl/base_data 下全部 xlsx，客户端表出 Lua、服务端表出 txt（纯后端表跳过，避免写空 txt）。等价于 DataConfig 面板的 Export All"},
    {"name":"SYNC_BYTES","type":"bool","default":true,"description":"把改动的 ~Lua/*.lua 重编成 LuaBytes/*_64.bytes（真机读的是字节码）"},
    {"name":"AB_MODE","type":"choice","choices":["重建","复用缓存","跳过"],"default":"重建","description":"AssetBundle 怎么处理。**重建** = GUI「整体打包资源」+「复制资源到流媒体目录」，约 5-8 分钟（改了 prefab / 图 / lua 必须选它）。**复用缓存** = 不启动 Unity，直接用打包目录上一轮重建的 Assets/StreamingAssets/Android（只对齐包内环境快照 + 校验缓存指纹，约 10 秒）—— 只适用于「资源没动、只想重出一版包」；缓存不完整、或字节码在上次重建之后变过（内容哈希不同）会被 ④ 直接判红，不会静默打旧配置。**跳过** = 完全不碰 AB（只导表/同步字节码，包内资源保持原样）"},
    {"name":"SERVER_ENV","type":"choice","choices":["正式服","测试服","现网-129.226.213.65"],"default":"正式服","description":"🔴 重建/复用 AB 都会对齐 Assets/Resources 与 StreamingAssets 快照里的 version.txt，快照里的 serverUrl 才是打进包里的值 ⇒ 这里选错，包就连错服。脚本结束自动还原工程里的 Assets/Resources/version.txt"},
    {"name":"LUA_FILES","type":"text","default":"","description":"只同步指定 lua（每行一个或空格分隔）。留空 = 自动取 git 里已改动/未跟踪的 ~Lua/*.lua"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 90, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '40'))
  }

  environment {
    // 🔴 打包目录 = 独立 clone（TimeSpaceGirl1-build）：开发目录开着 Unity 也能导表/重建 AB，
    //    同步靠 ①-1 的 ci_sync.sh（fetch + reset + 资产镜像），别把开发目录路径改回来。
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1-build'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 准备与取证') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR   = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          env.TS_EXPORT    = params.EXPORT_TABLES.toString()
          env.TS_SYNC      = params.SYNC_BYTES.toString()
          env.TS_AB_MODE   = params.AB_MODE
          env.TS_SERVER_ENV= params.SERVER_ENV
          env.TS_FILES     = params.LUA_FILES.trim().replaceAll('\\s+', ' ')
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "导表：${TS_EXPORT}   同步字节码：${TS_SYNC}   AB 处理：${TS_AB_MODE}"
  echo "出包环境（决定 StreamingAssets 里 version.txt 快照）：${TS_SERVER_ENV}"
  echo "目标 lua：${TS_FILES:-（自动：git 里已改动的 ~Lua/*.lua）}"
  echo ""
  echo "🔴 为什么要这个 job：导表与 AB 重建以前只能人肉点 GUI，Jenkins 只体检不执行 ⇒"
  echo "   改了 xlsx 忘了导表 / 导了表忘了重建 AB，包照打不误，到真机才发现配置没生效。"
  echo "🔴 为什么 AB 必须带环境：CopyAssetBundleToStreamingAssets 会把 Assets/Resources"
  echo "   整目录快照到 StreamingAssets，快照里的 serverUrl 才是真正打进包里的值。"
  if [[ "${TS_AB_MODE}" == "复用缓存" ]]; then
    echo "🔴 复用缓存：本轮**不重建** AB，包内资源 = 打包目录上一轮重建的"
    echo "   Assets/StreamingAssets/Android（gitignore，跨 ci_sync 的 reset 存活）。"
    echo "   ⇒ 只适用于「资源没动、只想重出一版包」；改了 prefab/图/lua 请选「重建」。"
    echo "   ⇒ ④ 会校验缓存完整性与字节码内容哈希，缓存不完整或字节码变过直接判红。"
  elif [[ "${TS_AB_MODE}" == "跳过" ]]; then
    echo "⚠ 跳过 AB：完全不碰包内资源（既不重建也不校验），出包资源保持原样。"
  fi
} | tee "$TS_RUN_DIR/context.txt"
''')
      }
    }

    stage('①-1 代码同步（打包目录 pull）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 打包目录无条件向 origin/<分支> 对齐：stash 快照本地残留 → reset --hard → 镜像 .secrets/服务端仓
"$BASH" .jenkins/lib/run_stage.sh --name "代码同步（fetch+reset+资产镜像）" \
  --group "同步" --slug ci-sync --timeout 1800 \
  -- "$BASH" .jenkins/ci_sync.sh
''')
      }
    }

    stage('② 导表（Unity batchmode）') {
      when { expression { params.EXPORT_TABLES } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 🔴 不要在这里再套 `lock.sh --name unity`：resource_build.sh 自己会 exec 自身套同一把锁
#    （见其头部 TSG_INNER 说明）。外层再套一层 = 自己等自己，flock 不可重入 ⇒ 必然死锁。
#    实测 2026-10-21：TS-Resource-Build #9/#10 都卡在「重建 AB」，等满 2400s 判 rc=75，
#    连带 TS-Android-Release #15/#16 一起失败（stage ③-0 propagate）。
"$BASH" .jenkins/lib/run_stage.sh --name "导表（xlsx→Lua+txt）" \
  --group "资源构建" --slug export-tables --timeout 1800 \
  -- "$BASH" scripts/resource_build.sh --action export
''')
      }
    }

    stage('③ 同步 Lua 字节码') {
      when { expression { params.SYNC_BYTES } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
if [[ -n "${TS_FILES:-}" ]]; then
  "$BASH" .jenkins/lib/run_stage.sh --name "重编 Lua 字节码（指定文件）" \
    --group "资源构建" --slug lua-sync --timeout 900 \
    -- "$BASH" scripts/lua-bytes-sync.sh $TS_FILES
else
  "$BASH" .jenkins/lib/run_stage.sh --name "重编 Lua 字节码（git 改动集）" \
    --group "资源构建" --slug lua-sync --timeout 900 \
    -- "$BASH" scripts/lua-bytes-sync.sh
fi
''')
      }
    }

    stage('④ 重建 AssetBundle') {
      when { expression { params.AB_MODE == '重建' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 🔴 同上：resource_build.sh 内部已自带 unity 锁，这里不能再套一层（会死锁）。
"$BASH" .jenkins/lib/run_stage.sh --name "重建 AB + 复制到 StreamingAssets" \
  --group "资源构建" --slug rebuild-ab --timeout 2400 \
  -- "$BASH" scripts/resource_build.sh --action ab --server-env "$TS_SERVER_ENV"
''')
      }
    }

    // 🔴 2026-10-23 新增：不重建 AB，复用打包目录上一轮重建的产物。
    //    为什么值得单列一个阶段而不是「重建 AB 不勾」：不勾 = 什么都不做，包里资源是什么
    //    完全没人知道（可能少了 luabytes、可能是导表前的旧 lua）。这一档会**校验**缓存：
    //    存在性（bundle 数 / luabytes / files / resconfigs）+ 指纹（哪次重建产出、字节码内容
    //    哈希有没有变），不满足就判红。省掉 5-8 分钟，但不会省掉正确性。
    stage('④ 复用上一轮 AB 缓存（不重建）') {
      when { expression { params.AB_MODE == '复用缓存' } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 不启动 Unity ⇒ 只秒级：对齐包内环境快照 + 校验缓存指纹（scripts/ab_cache.py verify）
"$BASH" .jenkins/lib/run_stage.sh --name "复用 AB 缓存（校验指纹，不重建）" \
  --group "资源构建" --slug reuse-ab --timeout 600 \
  -- "$BASH" scripts/resource_build.sh --action reuse --server-env "$TS_SERVER_ENV"
''')
      }
    }

    stage('⑤ 一致性闸门与就绪体检') {
      stages {
        stage('Lua bundle 新鲜度（硬闸门）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# rc=1 = 字节码比 bundle 新 ⇒ 这份 bundle 里没有最新配置，必须重建 AB。
"$BASH" .jenkins/lib/run_stage.sh --name "Lua bundle 新鲜度" \
  --group "资源构建" --slug lua-fresh --timeout 300 \
  -- "$BASH" scripts/check_lua_bundle_fresh.sh
''')
          }
        }
        stage('AB 就绪体检') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "AssetBundle 就绪体检" \
  --group "资源构建" --slug ab-ready --timeout 600 \
  -- "$BASH" scripts/check_ab_ready.sh
''')
          }
        }
      }
    }

    stage('⑥ 变更清单') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
mkdir -p "$TS_RUN_DIR/artifacts"
{
  echo "== 本次资源构建会产生的改动（~Lua / LuaBytes / 服务端 txt / StreamingAssets）=="
  git status --porcelain -- Assets/ManagedResources/~Lua Assets/ManagedResources/LuaBytes \
      Assets/StreamingAssets/Android TimeSpaceServer 2>/dev/null || true
  echo
  echo "== Lua bundle =="
  ls -lh "Assets/StreamingAssets/Android/lzma|luabytes.unity3d" 2>/dev/null || echo "（无）"
  echo
  echo "== AB 缓存指纹（$TS_AB_MODE）=="
  if [[ -f build/ab_cache/manifest.json ]]; then
    cat build/ab_cache/manifest.json
  else
    echo "（无指纹：本轮既没重建也没校验过缓存）"
  fi
  echo
  echo "== 包内环境快照 =="
  /usr/bin/grep -o '"serverUrl":"[^"]*"' "Assets/StreamingAssets/Android/Resources/version.txt" 2>/dev/null || echo "（无）"
  echo
  echo "🔴 提交规则：~Lua/*.lua 与对应 LuaBytes/*_64.bytes 必须成对提交。"
} | tee "$TS_RUN_DIR/artifacts/resource-change-list.txt"
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "变更清单" --group "交付" --status pass \
  --detail "已写出 resource-change-list.txt"
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
