/**@META
{
  "description": "本地测试服（本机 ~/home/java，游戏服 127.0.0.1:16081）一键部署最新服务端代码：源码体检 → JDK8 编译 → 逐条目比差异 → 备份 → 停服 → 注入 → CRC 复核 → 起服 → 自检。只动本机，不碰生产服。默认参数点一次构建就是「把当前代码跑到本地服上」。",
  "concurrent": false,
  "params": [
    {"name":"SOURCE","type":"choice","choices":["本地工作区","origin 干净副本"],"default":"本地工作区","description":"编译哪份源码。本地工作区=含未提交改动（最贴近手上这版）；origin 干净副本=git worktree 拉 origin 分支，不受并行会话 WIP 影响"},
    {"name":"FETCH","type":"bool","default":true,"description":"选 origin 干净副本时先 git fetch；本地工作区模式下只做只读提示，不会 merge/pull"},
    {"name":"SKIP_BUILD","type":"bool","default":false,"description":"跳过编译，直接用 serverlogic/build/libs 里上一次的产物（只在刚编译过、只想重跑部署时用）"},
    {"name":"GRADLE_ARGS","type":"string","default":"--offline","description":"gradle 额外参数。默认 --offline（快、不依赖网络）；新增了依赖时请留空"},
    {"name":"SKIP_VERIFY","type":"bool","default":false,"description":"跳过部署后的自检（端口/启动行/表加载/致命异常/协议探测）。不建议跳过"},
    {"name":"DRY_RUN","type":"bool","default":false,"description":"仅演练：打印备份/停服/注入/起服每一步要做什么，不真的动本地服"},
    {"name":"NOTES","type":"string","default":"","description":"本次部署测什么（写进构建描述与报告，便于事后追溯）"}
  ]
}
META*/
pipeline {
  agent any

  options {
    timestamps()
    timeout(time: 60, unit: 'MINUTES')
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '50'))
  }

  environment {
    PROJ = '/Users/wangxufeng/Documents/TimeSpaceGirl1'
    PY   = '/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python'
    BASH = '/usr/local/bin/bash'
  }

  stages {

    stage('① 参数与影响说明') {
      steps {
        script {
          env.STAGE_PROJECT_ROOT = env.PROJ
          env.TS_RUN_DIR = "${env.PROJ}/.jenkins/run/${env.BUILD_TAG}"
        }
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/logs"

{
  echo "运行：$JOB_NAME #$BUILD_NUMBER"
  echo "时间：$(date '+%Y-%m-%d %H:%M:%S %z')"
  echo "目标：本地测试服  游戏服 127.0.0.1:16081  登录服 127.0.0.1:8081（本 job 不动登录服）"
  echo "源码：$SOURCE"
  echo "参数：SKIP_BUILD=$SKIP_BUILD  GRADLE_ARGS=${GRADLE_ARGS:-（空）}  SKIP_VERIFY=$SKIP_VERIFY  DRY_RUN=$DRY_RUN"
  echo "说明：${NOTES:-（未填写）}"
} | tee "$TS_RUN_DIR/context.txt"

echo
echo "这个 job 会做的事："
echo "  1) 编译 serverlogic（JDK8 + gradle，产物 serverlogic-1.0.0.jar）"
echo "  2) 与本地服 gameSrv-1.0.0.jar 逐条目比 CRC，只取变化的类"
echo "     lib 下 common/netty/gamecommon/hotfix/fightmanager/tablemanager 同样逐条目比，一起注入"
echo "  3) 备份当前 jar 到 ~/home/java/gameserver/backup/（lib module 备份在 backup/lib-<时间戳>/）"
echo "  4) 停服 → zip -u 注入（先 lib 后主 jar）→ 逐条目 CRC 复核 → 原子 mv → launchd 重新拉起"
echo "  5) 自检端口/启动行/表加载/致命异常/协议连通"
echo
echo "影响面：本机测试号会掉线一次（重启游戏服）；生产服 129.226.213.65 完全不涉及。"
echo "回滚：$BASH .jenkins/lib/local_deploy.sh rollback   （或本 job 的 evidence/artifacts/local-deploy.md 里照抄）"
''')
      }
    }

    stage('② 源码就绪与部署前体检') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2

if [[ "$SOURCE" == "origin 干净副本" ]]; then
  REPO="$PROJ/TimeSpaceServer/Server_x1tag1.2.2"
  WT="$TS_RUN_DIR/src-origin"
  BR="$(git -C "$REPO" rev-parse --abbrev-ref HEAD)"
  echo "→ 准备 origin 干净副本：origin/$BR → $WT"
  if [[ "$FETCH" == "true" ]]; then
    git -C "$REPO" fetch origin "$BR" 2>&1 | sed 's/^/    /'
  fi
  rm -rf "$WT"
  git -C "$REPO" worktree add --detach "$WT" "origin/$BR" 2>&1 | sed 's/^/    /' || exit 1
  echo "$WT" > "$TS_RUN_DIR/worktree.txt"
  echo "    HEAD = $(git -C "$WT" log --oneline -1)"
  echo "$WT/server_game" > "$TS_RUN_DIR/src-dir.txt"
else
  echo "$PROJ/TimeSpaceServer/Server_x1tag1.2.2/server_game" > "$TS_RUN_DIR/src-dir.txt"
fi
# 🔴 每个 sh 都是新 shell，export 传不过去 ⇒ 用文件把源码目录传给后续 stage
export SRC_DIR="$(cat "$TS_RUN_DIR/src-dir.txt")"
echo "    编译目录：$SRC_DIR"

# 体检的 rc=3 = 「有需要人看一眼的事」（例如依赖集合变了）⇒ 黄球，不阻断编译
"$BASH" .jenkins/lib/run_stage.sh --name "部署前体检" --group "本地测试服" --slug local-precheck --timeout 300 --warn-rc 3 \\
  -- "$BASH" .jenkins/lib/local_deploy.sh precheck
''')
      }
    }

    stage('③ 编译最新代码') {
      when { expression { return params.SKIP_BUILD != true } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
[[ -f "$TS_RUN_DIR/src-dir.txt" ]] && export SRC_DIR="$(cat "$TS_RUN_DIR/src-dir.txt")"
"$BASH" .jenkins/lib/run_stage.sh --name "编译 serverlogic" --group "本地测试服" --slug local-build --timeout 1800 \\
  -- "$BASH" .jenkins/lib/local_deploy.sh build
''')
      }
    }

    stage('④ 差异分析') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
[[ -f "$TS_RUN_DIR/src-dir.txt" ]] && export SRC_DIR="$(cat "$TS_RUN_DIR/src-dir.txt")"
# rc=3 = 代码与本地服完全一致（无需注入）⇒ 黄球，不阻断后续（后续会自己跳过）
"$BASH" .jenkins/lib/run_stage.sh --name "逐条目差异" --group "本地测试服" --slug local-diff --timeout 600 --warn-rc 3 \\
  -- "$BASH" .jenkins/lib/local_deploy.sh diff
rc=$?
if [[ $rc -ne 0 ]]; then
  echo "LD_NO_DIFF=true" > "$TS_RUN_DIR/no-diff.flag"
fi
exit $rc
''')
      }
    }

    stage('⑤ 部署（备份→停服→注入→复核→起服）') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
[[ -f "$TS_RUN_DIR/src-dir.txt" ]] && export SRC_DIR="$(cat "$TS_RUN_DIR/src-dir.txt")"
# Jenkins 的 bool 参数是 "true"/"false"，脚本层只认 1/0 —— 别用 export X="$(... $X ...)" 自赋值
LD_DRY=0
[[ "$DRY_RUN" == "true" ]] && LD_DRY=1
export DRY_RUN="$LD_DRY"
"$BASH" .jenkins/lib/run_stage.sh --name "注入并重启本地服" --group "本地测试服" --slug local-deploy --timeout 1200 --warn-rc 3 \\
  -- "$BASH" .jenkins/lib/local_deploy.sh deploy
''')
      }
    }

    stage('⑥ 部署后自检') {
      when { expression { return params.SKIP_VERIFY != true && params.DRY_RUN != true } }
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
[[ -f "$TS_RUN_DIR/src-dir.txt" ]] && export SRC_DIR="$(cat "$TS_RUN_DIR/src-dir.txt")"
# rc=3 = 起来了但有需要人看一眼的事（ERROR 行 / 表数量偏低 / 协议探测告警）
"$BASH" .jenkins/lib/run_stage.sh --name "部署后自检" --group "本地测试服" --slug local-health --timeout 600 --warn-rc 3 \\
  -- "$BASH" .jenkins/lib/local_deploy.sh health
''')
      }
    }

    stage('⑦ 部署报告') {
      steps {
        sh(script: '''#!/usr/local/bin/bash
set -uo pipefail
cd "$PROJ" || exit 2
mkdir -p "$TS_RUN_DIR/artifacts" "$TS_RUN_DIR/local"
OUT="$TS_RUN_DIR/artifacts/local-deploy.md"
JAR="$HOME/home/java/gameserver/gameSrv-1.0.0.jar"

{
  echo "# 本地测试服部署报告"
  echo
  echo "- 构建：$JOB_NAME #$BUILD_NUMBER  ($(date '+%Y-%m-%d %H:%M:%S %z'))"
  echo "- 源码：$SOURCE"
  echo "- 说明：${NOTES:-（未填写）}"
  echo
  echo "## 源码版本"
  echo '```'
  sed 's/^/  /' "$TS_RUN_DIR/local/git.txt" 2>/dev/null || echo "  （无）"
  echo '```'
  echo
  echo "## 差异与注入"
  echo '```'
  "$PY" - "$TS_RUN_DIR/local/diff.json" <<'PYEOF' 2>/dev/null || echo "（无 diff.json）"
import json,sys
d=json.load(open(sys.argv[1]))
c=d["counts"]
print("  编译产物 %d 条 / 本地 jar %d 条" % (c["src"], c["dst"]))
print("  变更 %d · 新增 %d · 排除 %d · 仅本地保留 %d ⇒ 注入 %d" % (
    c["changed"], c["new"], c["excluded"], c["local_only"], c["inject"]))
for n in d["new"]:
    print("    [新增] " + n)
PYEOF
  echo '```'
  echo
  echo "## 部署动作"
  echo '```'
  echo "  备份：$(cat "$TS_RUN_DIR/local/backup-path.txt" 2>/dev/null || echo '（无，未执行）')"
  echo "  当前 jar：$(ls -l "$JAR" 2>/dev/null | awk '{print $5" B  "$6" "$7" "$8}')"
  echo "  服务状态："
  sed 's/^/    /' "$TS_RUN_DIR/logs/local-health.log" 2>/dev/null | tail -20 || echo "    （未跑自检）"
  echo '```'
  echo
  echo "## 回滚"
  echo '```bash'
  echo "  $BASH .jenkins/lib/local_deploy.sh rollback            # 最近一份备份"
  echo "  $BASH .jenkins/lib/local_deploy.sh rollback <jar 路径>  # 指定备份"
  echo '```'
} > "$OUT"

cp "$OUT" "$HOME/.jenkins/userContent/TS-Local-Deploy-latest.md" 2>/dev/null || true
sed -n '1,12p' "$OUT"
"$PY" .jenkins/lib/stage_report.py add --run "$TS_RUN_DIR" \\
  --name "部署报告" --group "交付" --status pass --detail "artifacts/local-deploy.md"
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
# 🔴 origin 模式的 worktree 必须回收；否则远端分支一多，本地攒一堆源码副本
if [[ -f "$TS_RUN_DIR/worktree.txt" ]]; then
  WT="$(cat "$TS_RUN_DIR/worktree.txt")"
  REPO="$PROJ/TimeSpaceServer/Server_x1tag1.2.2"
  git -C "$REPO" worktree remove --force "$WT" 2>/dev/null || rm -rf "$WT"
  git -C "$REPO" worktree prune 2>/dev/null || true
  echo "已回收 worktree：$WT"
fi
"$PY" .jenkins/lib/stage_report.py junit --run "$TS_RUN_DIR" \\
  --out "$TS_RUN_DIR/junit.xml" --suite "$JOB_NAME" || true
"$PY" .jenkins/lib/stage_report.py summary --run "$TS_RUN_DIR" \\
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

        def marks = "本地测试服 · ${params.SOURCE}"
        if (params.DRY_RUN) { marks = "${marks} · 演练" }
        if (params.NOTES?.trim()) { marks = "${marks} · ${params.NOTES.trim()}" }
        def desc = sh(returnStdout: true, script: '''#!/usr/local/bin/bash
cd "$PROJ" 2>/dev/null || true
"$PY" .jenkins/lib/stage_report.py desc --run "$TS_RUN_DIR" 2>/dev/null || true
''').trim()
        currentBuild.description = (desc ? "${desc} | " : "") + marks

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
