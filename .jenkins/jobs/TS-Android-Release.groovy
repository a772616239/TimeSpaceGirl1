/**@META
{
  "description": "Android 发版全链路（AAB + APK）：发布安全闸门 → 打包环境预检 → 提版本号 → **按 SERVER_ENV 注入连服地址** → Unity 构建 AAB → **同版本号打出测试 APK（同一环境）** → 包内四重校验（服务器环境/出包口径/16KB/交付）→ 归档 → 上传 Play。**默认上传并发布**（UPLOAD=True、AUTO_APPROVE=True、BUILD_APK=True）：默认轨道 internal 内部测试（status=completed，测试员即可安装）；选 production/beta/alpha 时同样上传并发布，其 completed/inProgress 仍需勾 PUBLISH 作为线上最后一道确认。需要停下来点按钮时把 AUTO_APPROVE 设为 False。",
  "concurrent": false,
  "params": [
    {"name":"SERVER_ENV","type":"choice","choices":["正式服","测试服","现网-129.226.213.65"],"default":"正式服","description":"🔴 这个包连哪个服务器（地址表 scripts/build_envs.json：正式服=103.151.173.99 / 测试服=本机 127.0.0.1:8081 / 现网=历史包用的 129.226.213.65）。构建前注入 Assets/Resources/version.txt，EXIT 时（含失败）自动还原；打包后**解包核验**，包里连的不是所选环境就拒绝上传。要回滚/对照旧包选「现网」"},
    {"name":"EXPECT_PROFILE","type":"choice","choices":["release","minimal","dev","full"],"default":"release","description":"🔴 出包口径 **同时是构建口径**（2026-10-22 起下发为 TS_RELEASE_PROFILE）：release=正式包（关 GM + 关日志 logLevel=Error，默认）/ minimal=测试包（关 GM，保留全部日志）/ dev、full=历史口径仅供对照。打包后按同一值解包核验，包里口径不符即拒绝上传"},
    {"name":"BUMP_VERSION","type":"bool","default":true,"description":"构建前把 versionCode +1。CLI 打包不自增；Play 各轨道共享 versionCode 空间，重复号一律被拒"},
    {"name":"BUILD_APK","type":"bool","default":true,"description":"**默认是**：打完 AAB 后接着出一份同 versionCode 的 universal APK（upload key 签名），方便直接装手机测试。APK 失败不阻断 AAB 发版，但会标成关注"},
    {"name":"REUSE_AAB","type":"string","default":"","description":"复用已有 AAB 的路径（填了就跳过 Unity 构建，只做校验/上传）"},
    {"name":"REBUILD_RESOURCES","type":"bool","default":true,"description":"打包前先调 TS-Resource-Build：同步 Lua 字节码 + 处理 AB（按下面的 AB_MODE）。默认开 —— 少了这步，改了配置或 Lua 后打出来的包还是旧资源。只改 C# 代码 / 纯热修可关掉"},
    {"name":"AB_MODE","type":"choice","choices":["重建","复用缓存"],"default":"重建","description":"🔴 资源准备时 AB 怎么处理。**重建**（默认）= 在打包目录重新打一遍 AB（约 5-8 分钟，改了 prefab/图/lua 必须选它）。**复用缓存** = 直接用打包目录上一轮重建的 AB（秒级，省 5-8 分钟）—— 只适用于「资源没动、只改了 C# 或打包参数」，改了资源却选它会被 ④ 的内容哈希闸门判红"},
    {"name":"EXPORT_TABLES","type":"bool","default":false,"description":"调 TS-Resource-Build 时是否**连导表一起做**（xlsx → 客户端 Lua + 服务端 txt）。默认关：导表会用 xlsx 覆盖手改过的 lua，确认改过配置表才勾。改过 xlsx 却忘了导表时，② 的「配置表是否已导」会黄球提醒"},
    {"name":"ALLOW_NO_LUA","type":"bool","default":false,"description":"强行跳过「未发现 Lua bundle」闸门（风险自负，会打出没有 Lua 的废包）"},
    {"name":"UPLOAD","type":"bool","default":true,"description":"是否上传到 Google Play。**默认是**。只出包不传时才取消勾选"},
    {"name":"TRACK","type":"choice","choices":["internal","alpha","beta","production"],"default":"internal","description":"上传轨道。默认 internal=内部测试（不面向公众、免常规审核、几分钟可装）；选 production/beta/alpha 会「上传并发布」，其 completed/inProgress 仍要求勾 PUBLISH"},
    {"name":"STATUS","type":"choice","choices":["completed","draft","inProgress"],"default":"completed","description":"发布状态。默认 completed=上传即发布（internal 测试员可装；线上轨道配合 PUBLISH 即送审上线）。只存草稿不发布才选 draft"},
    {"name":"PUBLISH","type":"bool","default":false,"description":"🔴 线上轨道（production/beta/alpha）的放行旗标：选这些轨道 + STATUS=completed/inProgress 时必须勾选，表示已知晓「会送审 / 上线」。internal 轨道不需要"},
    {"name":"AUTO_APPROVE","type":"bool","default":true,"description":"上传前的审批闸门是否自动放行。**默认是**（无人值守跑通整条链路）。设为 False 则停下来等人在 Jenkins 页面点「确认上传」"},
    {"name":"NOTES","type":"string","default":"","description":"更新说明（Play 发布说明）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 150, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '60', numToKeepStr: '40'))
  }

  environment {
    // 🔴 打包目录 = 独立 clone（TimeSpaceGirl1-build）：开发目录开着 Unity 也能打包，
    //    同步靠 ①-1 的 ci_sync.sh（fetch + reset + 资产镜像），别把开发目录路径改回来。
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1-build'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
    SHARED = '/Users/wangxufeng/Documents/jenkins-shared'
  }

  stages {

    stage('① 准备与取证') {
      steps {
        script {
          // 显式声明工程根，别依赖共享库退回 $PWD（写清楚比靠默契稳）
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
          // 参数转环境变量下发：避免拼命令字符串带来的引号/空格问题（更新说明里可能有空格）
          env.TS_PROFILE   = params.EXPECT_PROFILE
          env.TS_SERVER_ENV= params.SERVER_ENV
          env.TS_BUMP      = params.BUMP_VERSION.toString()
          env.TS_REUSE     = params.REUSE_AAB.trim()
          env.TS_ALLOWNOLUA= params.ALLOW_NO_LUA.toString()
          env.TS_TRACK     = params.TRACK
          env.TS_STATUS    = params.STATUS
          env.TS_PUBLISH   = params.PUBLISH.toString()
          env.TS_AUTOAPPROVE = params.AUTO_APPROVE.toString()
          env.TS_NOTES     = params.NOTES
          env.TS_REBUILD_RES = params.REBUILD_RESOURCES.toString()
          env.TS_AB_MODE   = params.AB_MODE
          env.TS_EXPORT_TABLES = params.EXPORT_TABLES.toString()
          env.TS_BUILD_START = (System.currentTimeMillis() / 1000L).toString()
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs"
{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "工程：$PROJ @ $(git rev-parse --short HEAD 2>/dev/null)"
  echo "口径：$TS_PROFILE  提版本号：$TS_BUMP  复用 AAB：${TS_REUSE:-（无，将构建）}"
  echo "出包环境：$TS_SERVER_ENV（连哪个服，见 scripts/build_envs.json）"
  echo "资源准备：${TS_REBUILD_RES}   AB 处理：${TS_AB_MODE}（复用缓存 = 不重打 AB，直接用打包目录上一轮的）"
  echo "服务端表：本 job 只做只读体检；改表请跑独立 job TS-Table-Sync"
  echo "上传：$UPLOAD  轨道：$TS_TRACK  状态：$TS_STATUS  PUBLISH：$TS_PUBLISH  自动放行审批：$TS_AUTOAPPROVE"
  echo "取证：$TS_RUN_DIR"
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

    stage('② 发布安全闸门') {
      stages {
        stage('送审闸门完好（默认拒绝）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "送审闸门完好性" \
  --group "发布安全" --slug play-gate --timeout 300 \
  -- "$BASH" .jenkins/lib/checks/play_gate.sh
''')
          }
        }
        stage('仓库卫生与 Lua 成对性') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "仓库卫生与 Lua 成对性" \
  --group "发布安全" --slug hygiene --timeout 600 \
  -- "$BASH" .jenkins/lib/checks/repo_hygiene.sh
''')
          }
        }
      }
    }

    stage('②-2 配置表是否已导（提醒）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# rc=1 只作提醒（黄球）：改了 xlsx 没导表时包里会是旧配置，但不该因此判红。
"$BASH" .jenkins/lib/run_stage.sh --name "配置表是否已导" \
  --group "发布安全" --slug tables-exported --timeout 120 --warn-rc 1 \
  -- "$BASH" scripts/check_tables_exported.sh
''')
      }
    }

    stage('③-0 资源准备（调 TS-Resource-Build）') {
      when { expression { params.REBUILD_RESOURCES } }
      steps {
        script {
          def rb = build job: 'TS-Resource-Build', wait: true, propagate: true, parameters: [
            booleanParam(name: 'EXPORT_TABLES', value: params.EXPORT_TABLES),
            booleanParam(name: 'SYNC_BYTES',    value: true),
            // 2026-10-23：REBUILD_AB(bool) → AB_MODE(choice)。AB_MODE=复用缓存 时
            // TS-Resource-Build ④ 只校验打包目录里上一轮的 AB 缓存、不启动 Unity（省 5-8 分钟）。
            // 🔴 传 choice 参数必须用 string()：build 步骤的 parameters 只认
            //    booleanParam/file/password/run/string/text，写 choice(...) 会在
            //    BuildTriggerStep 构造阶段直接抛
            //    「Could not instantiate {…parameters=[…]}」（2026-10-23 #27 实测）。
            //    Jenkins 会在真正触发时按目标 job 的 choices 校验取值。
            string(name: 'AB_MODE',             value: params.AB_MODE),
            string(name: 'SERVER_ENV',          value: params.SERVER_ENV),
            string(name: 'LUA_FILES',           value: '')
          ]
          echo "资源构建完成：TS-Resource-Build #${rb.number}（${rb.result}）"
        }
      }
    }

    // 🔴 2026-10-23 用户口径：**发包 job 不碰服务端表**。
    //    出包与改线上数值是两件事，耦合在一次构建里风险不可控（推表会踢线/改价格）。
    //    表由独立 job `TS-Table-Sync` 发（导表 + 增量同步 + 可选重启）。
    //    这里只留一条**只读**体检：包里连的那套服，其 conf/server 与导出产物差多少张，
    //    差得多就黄球提醒「先跑 TS-Table-Sync」——只提醒，不改任何服务端（rc 恒 0）。
    stage('②-3 服务端表一致性（只读提醒）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "服务端表一致性（只读）" \
  --group "发布安全" --slug table-parity --timeout 900 --warn-ok \
  -- "$PY" scripts/table_sync.py --env "$TS_SERVER_ENV"
''')
      }
    }

    stage('③ 打包环境预检') {
      stages {
        stage('工具链 / Gradle 模板 / 签名 / Unity 占用') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "打包环境预检" \
  --group "打包环境" --slug android-env --timeout 300 \
  -- "$BASH" .jenkins/lib/checks/android_env.sh
''')
          }
        }
        stage('AssetBundle 就绪（Lua 必须在包里）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
"$BASH" .jenkins/lib/run_stage.sh --name "AssetBundle 就绪体检" \
  --group "打包环境" --slug ab-ready --timeout 600 \
  -- "$BASH" scripts/check_ab_ready.sh
''')
          }
        }
      }
    }

    stage('④ 提版本号') {
      when { expression { params.BUMP_VERSION && params.REUSE_AAB.trim().isEmpty() } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
before="$("$PY" scripts/bump_version.py --show 2>&1 | tr '\n' ' ')"
"$BASH" .jenkins/lib/run_stage.sh --name "提版本号 versionCode +1" \
  --group "构建" --slug bump --timeout 120 \
  -- "$PY" scripts/bump_version.py --bump || exit $?
after="$("$PY" scripts/bump_version.py --show 2>&1 | tr '\n' ' ')"
printf 'bump 前：%s\nbump 后：%s\n' "$before" "$after" | tee "$TS_RUN_DIR/version.txt"
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \
  --name "版本号变更" --group "构建" --status pass --detail "$after"
''')
      }
    }

    stage('⑤ 构建 AAB（Unity batchmode）') {
      options { timeout(time: 120, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"

BUILD_ARGS=(--no-bump)
if [[ -n "${TS_REUSE:-}" ]]; then
  BUILD_ARGS=(--no-bump --skip-build --aab "$TS_REUSE")
fi
[[ "$TS_ALLOWNOLUA" == "true" ]] && BUILD_ARGS+=(--allow-no-lua)
# 🔴 出包环境：注入 + 打包后解包核验都由 aab_release.sh 负责（--skip-build 复用旧包时只核验）
[[ -n "${TS_SERVER_ENV:-}" ]] && BUILD_ARGS+=(--server-env "$TS_SERVER_ENV")
# 🔴 出包口径：正式包默认 release（关 GM + 关日志）。必须显式下发，
#    否则 CLIBuilder 会走它自己的默认值 —— 参数就白设了（与 --server-env 同理）。
[[ -n "${TS_PROFILE:-}" ]] && BUILD_ARGS+=(--profile "$TS_PROFILE")

echo "→ scripts/aab_release.sh ${BUILD_ARGS[*]}"
# 🔴 纳入 unity 锁：同一 Unity 工程不能有第二个 batchmode 实例，
#    而且 TS-Android-TestPackage / 手工 Unity 都可能同时在跑。
"$BASH" .jenkins/lib/run_stage.sh --name "Unity 构建 AAB" \
  --group "构建" --slug build-aab --timeout 7000 \
  -- "$BASH" .jenkins/lib/lock.sh --name unity run \
       --who "$JOB_NAME #$BUILD_NUMBER" --timeout 1800 -- \
       "$BASH" scripts/aab_release.sh "${BUILD_ARGS[@]}"
''')
      }
    }

    stage('⑤-2 打包 APK（同版本号，便于真机测试）') {
      when { expression { params.BUILD_APK && params.REUSE_AAB.trim().isEmpty() } }
      options { timeout(time: 120, unit: 'MINUTES') }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"

# 🔴 关键：APK 必须与本次 AAB **同一个 versionCode**。
#    版本号已在 ④ 提过一次，这里必须 --no-bump，否则 APK 会比 AAB 大一号，
#    两者对不上、也没法与 Play 上那个号互相印证。
# 🔴 必须仍然纳 unity 锁：同一 Unity 工程只允许一个 batchmode 实例。
#    AAB 刚构建完、锁已释放，这里再拿一次 —— 期间若有人手工开了编辑器，
#    我们只会等锁（rc=75 超时）而不是把工程搞坏。
echo "→ build_apk.sh --no-bump（复用 ④ 已提的版本号，与 AAB 保持一致）"
# 🔴 同一个出包环境，AAB 与 APK 必须一致：两者是两次独立 Unity 构建，
#    若只给 AAB 注入，APK 会打回工程默认环境 ⇒ 发出去的装机包连错服。
APK_ARGS=(--no-bump)
[[ -n "${TS_SERVER_ENV:-}" ]] && APK_ARGS+=(--server-env "$TS_SERVER_ENV")
# 🔴 口径也必须一致：AAB 是正式包（关日志）、APK 却留日志 = 同一个版本两个口径。
[[ -n "${TS_PROFILE:-}" ]] && APK_ARGS+=(--profile "$TS_PROFILE")
"$BASH" .jenkins/lib/run_stage.sh --name "Unity 构建 APK" \
  --group "构建" --slug build-apk --timeout 7000 \
  -- "$BASH" .jenkins/lib/build_apk.sh "${APK_ARGS[@]}" --who "$JOB_NAME #$BUILD_NUMBER"
''')
      }
      post {
        always {
          script {
            // APK 是「方便测试」的产物，不是发布阻断项：它挂了不该让整条发版链变红，
            // 但要**明确记成关注**并在总结里说出来，不能悄悄吞掉。
            def apkLog = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
cat "$TS_RUN_DIR/apk.path" 2>/dev/null || true
''').trim()
            if (apkLog) {
              env.TS_APK_PATH = apkLog
              echo "✅ 本次同时产出 APK：${apkLog}"
              // 装机包也要过交付自检：出包口径 / 16KB / googlesignin / **签名**。
              // ⑦ 的三重校验只针对 AAB，APK 若不单独校，就是「发出去的测试包没人验过」。
              // 这里用 returnStatus：APK 校验不过只标关注、不阻断 AAB 发版（真正的红线是 Play 包）。
              def apkRc = sh(returnStatus: true, script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
APK="$(cat "$TS_RUN_DIR/apk.path" 2>/dev/null || true)"
[[ -n "$APK" ]] || exit 1
"$BASH" .jenkins/lib/run_stage.sh --name "APK 交付自检（供装机）" \
  --group "包内校验" --slug apk-delivery --timeout 300 \
  -- "$PY" scripts/verify_apk_delivery.py "$APK" --expect "$TS_PROFILE"
''')
              if (apkRc != 0) {
                echo "⚠️ APK 交付自检未通过（rc=${apkRc}）——AAB 发版不受影响，但这份 APK 不建议拿去装机。"
              }
            } else {
              echo "⚠️ 本次没有产出 APK（AAB 已正常出包）。要排查请看 'Unity 构建 APK' 环节日志。"
            }
          }
        }
      }
    }

    stage('⑥ 定位本次产物') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# 🔴 必须限定「本次构建之后」的产物：否则构建失败时会拿上一次的旧包继续校验，
# 一路绿灯但校的是昨天那个包 —— 最危险的假通过。
"$BASH" .jenkins/lib/run_stage.sh --name "定位本次 AAB 产物" \
  --group "构建" --slug locate-aab --timeout 120 \
  -- "$PY" .jenkins/lib/find_artifact.py 'apks/*/CLIBuild/*.aab' \
       --root "$PROJ" --after "$TS_BUILD_START" --out "$TS_RUN_DIR/aab.path"
AAB="$(cat "$TS_RUN_DIR/aab.path")"
echo "$AAB" | tee "$TS_RUN_DIR/aab.resolved"
ls -la "$AAB" "$AAB.release.json" 2>/dev/null || true
''')
      }
    }

    stage('⑦ 包内四重校验（服务器环境 / 出包口径 / 16KB / 交付）') {
      stages {
        stage('服务器环境（这个包连哪个服）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path")"
# 解包读 base/assets/Android/Resources/version.txt，与 SERVER_ENV 对应的地址逐字比对。
# 「注入脚本说改了」不算证据 —— 复用旧包（REUSE_AAB）、手工改过文件忘改回来，
# 都会在这一步被揪出来；发错服比打包失败严重得多，所以这里必须是硬闸门。
# （bash 5 / set -u 下空数组展开安全，SERVER_ENV 留空时脚本只报告不判错）
ENV_ARGS=()
[[ -n "${TS_SERVER_ENV:-}" ]] && ENV_ARGS=(--expect-env "$TS_SERVER_ENV")
"$BASH" .jenkins/lib/run_stage.sh --name "服务器环境核验" \
  --group "包内校验" --slug server-env --timeout 300 \
  -- "$PY" scripts/verify_aab_server_env.py "$AAB" "${ENV_ARGS[@]}"
''')
          }
        }
        stage('出包口径（isOpenGM 等 12 位开关）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path")"
"$BASH" .jenkins/lib/run_stage.sh --name "包内出包口径核验" \
  --group "包内校验" --slug cfg --timeout 300 \
  -- "$PY" scripts/verify_aab_release_config.py "$AAB" --expect "$TS_PROFILE"
''')
          }
        }
        stage('native 16KB / NDK（Play 硬门槛）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path")"
"$BASH" .jenkins/lib/run_stage.sh --name "native 16KB / NDK 体检" \
  --group "包内校验" --slug 16kb --timeout 300 \
  -- "$PY" scripts/verify_aab_native_16kb.py "$AAB"
''')
          }
        }
        stage('交付自检（含 googlesignin 必须在包内）') {
          steps {
            sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path")"
"$BASH" .jenkins/lib/run_stage.sh --name "交付自检" \
  --group "包内校验" --slug delivery --timeout 300 \
  -- "$PY" scripts/verify_apk_delivery.py "$AAB" --expect "$TS_PROFILE"
''')
          }
        }
      }
    }

    stage('⑧ 归档取证') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path" 2>/dev/null || true)"
echo "AAB: $AAB"
mkdir -p "$TS_RUN_DIR/artifacts"
for f in "$AAB.release.json" "$AAB.delivery.json"; do
  if [[ -f "$f" ]]; then
    cp "$f" "$TS_RUN_DIR/artifacts/" && echo "  已收取证：${f##*/}"
  fi
done
# 大包本体（450MB）不进 Jenkins 归档：它就在 apks/ 下，路径记进证据文件即可
{
  echo "AAB=$AAB"
  [[ -f "$AAB" ]] && echo "aab_size=$(stat -f%z "$AAB")" && echo "aab_md5=$(md5 -q "$AAB")"
  # 同版本的测试 APK（BUILD_APK 默认开）也记账，便于拿走直接装机
  APK="$(cat "$TS_RUN_DIR/apk.path" 2>/dev/null || true)"
  if [[ -n "$APK" && -f "$APK" ]]; then
    echo "APK=$APK"
    echo "apk_size=$(stat -f%z "$APK")"
    echo "apk_md5=$(md5 -q "$APK")"
    # 🔴 不要在循环体末尾用 `[[ -f … ]] && cp … && echo …` 这种串：
    #    APK 的 .delivery.json 由本轮**后续**环节才生成，此刻大概率还不存在，
    #    该表达式于是返回 1，而 `set -uo pipefail` 下循环体最后一次求值就是脚本的退出码
    #    ⇒ 整个 ⑧ 变成 exit 1，连累 ⑨ 上传被 skip（2026-10-17 构建 #3 实测）。
    #    一律显式 if + 循环末尾 `|| true`。
    for f in "$APK.release.json" "$APK.delivery.json"; do
      if [[ -f "$f" ]]; then
        cp "$f" "$TS_RUN_DIR/artifacts/" && echo "  已收取证：${f##*/}"
      else
        echo "  （暂无 ${f##*/}，属正常：该 sidecar 由后续环节生成）"
      fi
    done
  else
    echo "APK=（本次未产出）"
  fi
  true
} | tee "$TS_RUN_DIR/artifacts/artifact.txt"
''')
      }
    }

    stage('⑨ 上传 Google Play（AUTO_APPROVE 控制审批）') {
      when { expression { params.UPLOAD } }
      steps {
        script {
          def aab = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
cat "$TS_RUN_DIR/aab.path" 2>/dev/null || true
''').trim()

          // 闸门复核：与 aab_release.sh / play_upload.py 内的两层校验独立，这里是第三层，
          // 目的是把「为什么被拒」在审批之前就讲清楚，而不是等上传脚本报错。
          // internal 内部测试轨道不面向公众、可随时 halt/替换 ⇒ 豁免 PUBLISH。
          // 其余轨道（production / beta / alpha）的 completed/inProgress = 送审 / 上线，
          // 属「对外生效、不可轻易撤回」的动作，必须另勾 PUBLISH。
          if (params.TRACK != 'internal' && params.STATUS in ['completed', 'inProgress'] && !params.PUBLISH) {
            error("拒绝送审：轨道 ${params.TRACK} 上的 STATUS=${params.STATUS} 等于「提交审核 / 上线」，"
                + "必须同时勾选 PUBLISH 表示已获批准。只想上传草稿请把 STATUS 改为 draft。"
                + "（internal 内部测试轨道不受此限。）")
          }
          if (!aab) {
            error("找不到本次构建的 AAB（${env.TS_RUN_DIR}/aab.path 为空），无法上传。")
          }

          def trackNote = params.TRACK == 'internal'
              ? '（内部测试，不面向公众、免常规审核，测试员几分钟内可装）'
              : (params.STATUS == 'draft' ? '（草稿，不会送审）' : '  🔴 会提交审核 / 上线')
          def msg = """即将上传到 Google Play，请确认：
  AAB      : ${aab}
  口径     : ${params.PROFILE}
  轨道     : ${params.TRACK}
  状态     : ${params.STATUS} ${trackNote}
  送审旗标 : ${params.PUBLISH}${params.TRACK == 'internal' ? '（internal 轨道不需要）' : ''}
  更新说明 : ${params.NOTES ?: '（空）'}

确认无误请点「确认上传」；不想传点「中止」。"""

          // 审批闸门：AUTO_APPROVE=True（默认）时直接放行，让整条链路无人值守跑通；
          // 设 False 才真的停下来等人在 Jenkins 页面点按钮。
          // 🔴 上面的送审闸门（TRACK!=internal 且 completed/inProgress 必须 PUBLISH）
          //    与下面这层是**两道独立**的门：自动放行只解掉「点按钮」这一步，
          //    不会替你把线上轨道的 PUBLISH 抬起来。
          if (params.AUTO_APPROVE) {
            echo "⏭ 审批闸门自动放行（AUTO_APPROVE=true）：TRACK=${params.TRACK} / STATUS=${params.STATUS}"
            echo msg
          } else {
            input message: msg, ok: '确认上传'
          }

          sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
AAB="$(cat "$TS_RUN_DIR/aab.path")"

UPLOAD_ARGS=(--aab "$AAB" --track "$TS_TRACK" --status "$TS_STATUS" --yes)
[[ "$TS_TRACK" == "production" ]] && UPLOAD_ARGS+=(--allow-production-write)
# internal 轨道豁免 --allow-publish（内部测试不面向公众、可随时 halt）；其余轨道送审才需要
if [[ "$TS_TRACK" != "internal" && ( "$TS_STATUS" == "completed" || "$TS_STATUS" == "inProgress" ) ]]; then
  UPLOAD_ARGS+=(--allow-publish)
fi
[[ -n "${TS_NOTES:-}" ]] && UPLOAD_ARGS+=(--release-notes "$TS_NOTES")

echo "→ scripts/play_upload.py ${UPLOAD_ARGS[*]}"
# Play 的 edits 全局排他：并发上传会把对方的 edit 判成 deleted（实测 85% 处 HTTP 400）。
"$BASH" .jenkins/lib/run_stage.sh --name "上传 Google Play" \
  --group "发布" --slug upload --timeout 5400 \
  -- "$BASH" .jenkins/lib/lock.sh --name play run \
       --who "$JOB_NAME #$BUILD_NUMBER" --timeout 1800 -- \
       "$PY" scripts/play_upload.py "${UPLOAD_ARGS[@]}"
''')
        }
      }
    }

    stage('⑩ 发版完成通知') {
      // 只有真的落地了才发；演练（DRY_RUN）/ 未上传（UPLOAD=false）不发，
      // 免得收件箱里全是"完成"其实没发。
      when { expression { params.UPLOAD } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ"
# --warn-rc 4：投递失败（凭据/网络/SMTP 拒收）只标黄，不把已经成功的发版判红。
# 这是 2026-10-18 巡检那条 job 踩过的教训：发信抖一下就把整次构建判红，得不偿失。
# 取证目录用 TS_RUN_DIR（与其他环节一致）；🔴 别写 $STAGE_RUN_DIR —— 本 job 从不定义它，
# set -u 下引用未定义变量会在 run_stage 启动前直接炸（2026-10-20 #8 实测：17 环节全过、
# 邮件却没发，整条构建被这个环节判红）。
"$BASH" "$SHARED/lib/run_stage.sh" --name "发版完成邮件" \
  --group "通知" --slug notify --timeout 300 --warn-rc 4 \
  -- "$PY" "$SHARED/lib/notify.py" release \
       --run-dir "$TS_RUN_DIR" --job "$JOB_NAME" --build "$BUILD_NUMBER" \
       --url "$BUILD_URL" --result SUCCESS \
       --field 轨道 "$TS_TRACK" --field 状态 "$TS_STATUS"
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
