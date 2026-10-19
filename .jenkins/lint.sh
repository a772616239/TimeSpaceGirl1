#!/usr/local/bin/bash
# =============================================================================
# lint.sh —— 推送前的三道静态检查
#
# 为什么值得单独做一个
# --------------------
# 1) **Groovy 是运行时语言**：语法错误不会在渲染 config.xml 时暴露，只有跑起来才炸，
#    而且 Pipeline 的语法错误报得又晚又迷惑。
#    Jenkins 自带 `/pipeline-model-converter/validate`，能做 Groovy **语法**校验。
#
#    ⚠️ 诚实说明**它查不到什么**：实测它**不校验 DSL 结构与步骤名**——
#       `when` 写在 `steps` 里、`echoNope "x"` 这种它都判「validated」。
#       所以它只能挡语法错，挡不住「用了不存在的步骤 / 放错位置」。
#       那类问题只能靠**真跑一次只读 job** 来发现（见 docs/jenkins_ci.md 的验收清单）。
#
# 2) **`$VAR` 后紧跟全角标点 = 未定义变量**：本项目红线。`set -u` 下
#    `"…${STATUS}）"` 会把全角括号的字节并进变量名 ⇒ `unbound variable`，
#    而且报错位置指向的行看起来完全正常，极难定位。这个坑已实际踩过多次
#    （2026-10-12 一天内就踩了两次：`.jenkins` 里的脚本 + `server_health_check` 的适配层）。
#    所以把审计做成脚本，改完 .sh 顺手跑一遍。
#
# 3) **用了「插件才提供的环境变量」= 未定义变量**：同一类坑的另一副面孔。
#    `BUILD_CAUSE` / `BUILD_USER_ID` 之类来自 build-user-vars 插件，本机**没装**
#    ⇒ `set -u` 下裸引用直接 unbound。实测（2026-10-12）：`TS-Pipeline-Overview`
#    首个能跑起来的构建就死在 `$BUILD_CAUSE: unbound variable`，
#    而且因为 ① 阶段是致命阶段，后面 8 个阶段全被 skip。
#    这台机器上「Jenkins 核心自带、可裸用」的只有：
#      BUILD_NUMBER/BUILD_ID/BUILD_TAG/BUILD_URL/BUILD_DISPLAY_NAME/JOB_NAME/
#      WORKSPACE/WORKSPACE_TMP/NODE_NAME/EXECUTOR_NUMBER/GIT_*（有 git 插件时）
#    其余一律要求写 `:-` 兜底。**这不是完整证明**（静态看不出运行时环境），
#    所以真跑一次只读 job 仍然是必需的验收步骤。
#
# 4) **`junit` 的 testResults 必须是「相对 workspace」的路径**：给绝对路径时
#    `fileExists` 为真、步骤也会执行，但 glob 匹配不到任何文件，日志只说
#    「No test report files were found. Configuration error?」，
#    于是**测试结果表格与趋势图永远空白 —— 静默失败，最坏的一种**。
#    实测（2026-10-12，TS-Pipeline-Overview #3）：testResults 原本写成
#    `${rd}/junit.xml`（绝对），改成 `evidence/junit.xml`（相对）后才真正收录。
#    做法：post 段本来就会 `cp -R "$TS_RUN_DIR/." "$WORKSPACE/evidence/"`，
#    所以直接指向 `evidence/junit.xml` 即可，不用额外拷贝。
#
# 用法：
#   .jenkins/lint.sh                 # 四道检查全跑
#   .jenkins/lint.sh TS-Server-Ops   # 只 lint 指定 job（①②④ 仍然全量跑）
#
# 退出码：0 全通过；1 有失败；2 环境错误
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
JOBS_DIR="$HERE/jobs"
PY="${TS_PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
FAIL=0

# --------------------------------------------------------------------------- #
# 检查一：shell 花括号审计（本地，不需要网络）
# --------------------------------------------------------------------------- #
echo "── ① shell 花括号审计（\$VAR 后紧跟全角字符）──────────"
AUDIT_OUT="$("$PY" - "$ROOT" <<'PY'
import re, sys, os, glob
root = sys.argv[1]
pat = re.compile(r'(?<!\\)\$([A-Za-z_][A-Za-z0-9_]*|\d)\s*(?=[^\x00-\x7f])')
hits = []
targets = (glob.glob(os.path.join(root, '.jenkins', '**', '*.sh'), recursive=True)
           + glob.glob(os.path.join(root, 'scripts', '*.sh')))
# 🔴 必须排除 .jenkins/run/：那是运行态目录（含服务端发布 job 的 git worktree，
#    里面是被检出的**别人的** package.sh 等脚本）。审计别人的代码只会产生假红，
#    而假红会训练人忽略红灯（2026-10-13 的教训）。
targets = [t for t in targets if '/.jenkins/run/' not in t.replace(os.sep, '/')]
for f in sorted(targets):
    try:
        lines = open(f, encoding='utf-8').read().splitlines()
    except OSError:
        continue
    for i, line in enumerate(lines, 1):
        code = line.split('#', 1)[0] if line.lstrip().startswith('#') else line
        if line.lstrip().startswith('#'):
            continue
        for m in pat.finditer(code):
            hits.append("%s:%d  $%s 后紧跟全角字符 → 必须写成 ${%s}\n      %s"
                        % (os.path.relpath(f, root), i, m.group(1), m.group(1), line.strip()[:140]))
for h in hits:
    print(h)
sys.exit(1 if hits else 0)
PY
)"
if [[ $? -eq 0 ]]; then
  echo "   ✓ 没有发现会变成 unbound variable 的写法"
else
  printf '%s\n' "$AUDIT_OUT" | sed 's/^/   /'
  echo "   🔴 有未加花括号的变量引用（见上）"
  FAIL=1
fi

# --------------------------------------------------------------------------- #
# 检查二：插件提供的环境变量审计（本地，不需要网络）
# --------------------------------------------------------------------------- #
echo
echo "── ② Jenkins 集成陷阱审计（插件变量 / junit 路径）──"
PLUGIN_OUT="$("$PY" - "$ROOT" <<'PY'
import re, sys, os, glob

root = sys.argv[1]

# 来自 build-user-vars 插件（本机未安装）。等价的名字以后还会冒出来，按前缀凑。
PLUGIN_VARS = re.compile(r'BUILD_CAUSE|BUILD_USER[A-Z_]*')
# $VAR / ${VAR} 后面紧跟 ':' 说明写了 `:-` 兜底 ⇒ 安全
REF = re.compile(r'\$\{?(%s)(?![:\w])' % PLUGIN_VARS.pattern)

# junit testResults 必须是相对 workspace 的路径
JUNIT = re.compile(r'''junit\b[^\n]*?testResults:\s*(['"])(.*?)\1''')

targets = (sorted(glob.glob(os.path.join(root, '.jenkins', 'jobs', '*.groovy')))
           + sorted(glob.glob(os.path.join(root, '.jenkins', 'lib', '**', '*.sh'), recursive=True)))

hits = []
for f in targets:
    try:
        lines = open(f, encoding='utf-8').read().splitlines()
    except OSError:
        continue
    for i, line in enumerate(lines, 1):
        if line.lstrip().startswith('#'):
            continue
        for m in REF.finditer(line):
            hits.append("%s:%d  $%s 裸引用（该变量来自本机未安装的插件）\n"
                        "      改法：${%s:-（无）}\n      %s"
                        % (os.path.relpath(f, root), i, m.group(1), m.group(1), line.strip()[:140]))
        for m in JUNIT.finditer(line):
            pat = m.group(2)
            if pat.startswith('/') or any(v in pat for v in ('${rd}', '${PROJ}', '${WORKSPACE}', '$rd')):
                hits.append("%s:%d  junit testResults 是绝对路径：%s\n"
                            "      改法：指向工作区内的相对路径（post 段已 cp 到 evidence/）\n"
                            "      否则 fileExists 为真、步骤会跑，但 glob 匹配不到 ⇒ 测试结果表格静默空白\n"
                            "      %s"
                            % (os.path.relpath(f, root), i, pat, line.strip()[:140]))
for h in hits:
    print(h)
sys.exit(1 if hits else 0)
PY
)"
if [[ $? -eq 0 ]]; then
  echo "   ✓ 没有裸引用插件变量、junit 用相对路径"
else
  printf '%s\n' "$PLUGIN_OUT" | sed 's/^/   /'
  echo "   🔴 有 Jenkins 集成陷阱（见上）"
  FAIL=1
fi

# --------------------------------------------------------------------------- #
# 检查三：Jenkins 声明式语法校验（需要网络 + 凭据）
# --------------------------------------------------------------------------- #
echo
echo "── ③ Jenkins 声明式 Pipeline 语法校验 ──────────────"

if [[ -z "${JENKINS_URL:-}" || -z "${JENKINS_USER:-}" || -z "${JENKINS_TOKEN:-}" ]]; then
  CRED="$HOME/.jenkins/.qclaw-creds"
  if [[ -f "$CRED" ]]; then
    set -a; . "$CRED"; set +a
  else
    echo "   找不到凭据（环境变量或 ${CRED}）→ 跳过（不判失败）"
    echo; echo "结果：①花括号审计 / ②插件变量审计 $( [[ $FAIL -eq 0 ]] && echo 通过 || echo 失败 )；③语法校验 跳过"
    exit $FAIL
  fi
fi
JENKINS_URL="${JENKINS_URL%/}"

CRUMB="$(curl -s --max-time 10 -u "$JENKINS_USER:$JENKINS_TOKEN" \
         "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)" 2>/dev/null)"
if [[ "$CRUMB" != *:* ]]; then
  echo "   🔴 取不到 crumb，认证可能失效：$CRUMB"
  exit 2
fi

FILES=()
if [[ $# -gt 0 ]]; then
  for n in "$@"; do
    f="$JOBS_DIR/$n.groovy"
    [[ -f "$f" ]] || { echo "没有这个定义：$f" >&2; exit 2; }
    FILES+=("$f")
  done
else
  while IFS= read -r f; do [[ -n "$f" ]] && FILES+=("$f"); done \
    < <(ls -1 "$JOBS_DIR"/*.groovy 2>/dev/null || true)
fi
[[ ${#FILES[@]} -gt 0 ]] || { echo "没有可校验的定义" >&2; exit 2; }

OKN=0
for f in "${FILES[@]}"; do
  name="$(basename "$f" .groovy)"
  body="$("$PY" - "$f" <<'PY'
import re, sys
raw = open(sys.argv[1], encoding='utf-8').read()
m = re.search(r"/\*\*@META\s*(?P<meta>.*?)\s*META\*/", raw, re.S)
print((raw[:m.start()] + raw[m.end():]).strip() if m else raw)
PY
)"
  resp="$(printf '%s' "$body" | curl -s --max-time 30 -X POST \
            -u "$JENKINS_USER:$JENKINS_TOKEN" -H "$CRUMB" \
            --data-urlencode "jenkinsfile@-" \
            "$JENKINS_URL/pipeline-model-converter/validate" 2>/dev/null)"
  if printf '%s' "$resp" | grep -q 'successfully validated'; then
    printf '   \033[1;32m✓\033[0m %-30s 语法通过\n' "$name"
    OKN=$((OKN + 1))
  else
    printf '   \033[1;31m✗\033[0m %-30s 校验失败\n' "$name"
    printf '%s\n' "$resp" | sed 's/^/        /' | head -12
    FAIL=1
  fi
done
echo "   （${OKN} 个通过；注意校验器不检查步骤名与 DSL 结构，那类问题要真跑一次）"

echo
if [[ $FAIL -eq 0 ]]; then
  echo "✅ lint 全部通过"
else
  echo "🔴 lint 有失败项"
fi
exit $FAIL
