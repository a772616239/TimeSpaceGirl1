#!/usr/local/bin/bash
# =============================================================================
# apply-jobs.sh —— 把 .jenkins/jobs/*.groovy 同步成 Jenkins 里的 Pipeline job
#
# 为什么这么做：job 的参数、触发器、脚本全部写在仓库里的定义文件里（单一真源），
# 这个脚本只负责「推上去」。好处是**改 job 不需要点 Jenkins 界面，也不需要重启**
# （走 REST 的 createItem / config.xml，热生效），并且改动进 git、可 review、可回滚。
#
# 用法：
#   .jenkins/apply-jobs.sh                    # 同步全部 job + 建/更新视图
#   .jenkins/apply-jobs.sh --list             # 只列出定义文件与解析到的参数
#   .jenkins/apply-jobs.sh --only TS-Android-Release   # 只同步一个（可多次）
#   .jenkins/apply-jobs.sh --dry-run          # 只渲染，不推
#   .jenkins/apply-jobs.sh --no-view          # 不动视图
#
# 凭据：按优先级取 环境变量 JENKINS_URL/USER/TOKEN → ~/.jenkins/.qclaw-creds
#
# 退出码：0 全部成功；1 有 job 失败；2 环境/用法错误。
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
JOBS_DIR="$HERE/jobs"
RENDER="$HERE/lib/render_job.py"
PY="${TS_PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
VIEW_NAME="时空美少女 · 全流程"
VIEW_TAG="TS-"

ONLY=(); DRY=0; DO_VIEW=1; LIST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --only)    ONLY+=("$2"); shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --no-view) DO_VIEW=0; shift ;;
    --list)    LIST=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
done

# ---- 凭据 -------------------------------------------------------------------
if [[ -z "${JENKINS_URL:-}" || -z "${JENKINS_USER:-}" || -z "${JENKINS_TOKEN:-}" ]]; then
  CRED="$HOME/.jenkins/.qclaw-creds"
  if [[ -f "$CRED" ]]; then
    set -a; . "$CRED"; set +a
  else
    echo "找不到凭据：既没有环境变量，也没有 $CRED" >&2; exit 2
  fi
fi
JENKINS_URL="${JENKINS_URL%/}"

[[ -x "$PY" ]] || { echo "找不到 python：$PY" >&2; exit 2; }
[[ -d "$JOBS_DIR" ]] || { echo "找不到 job 目录：$JOBS_DIR" >&2; exit 2; }

# ---- 收集定义文件 ------------------------------------------------------------
FILES=()
if [[ ${#ONLY[@]} -gt 0 ]]; then
  for n in "${ONLY[@]}"; do
    f="$JOBS_DIR/$n.groovy"
    [[ -f "$f" ]] || { echo "没有这个 job 定义：$f" >&2; exit 2; }
    FILES+=("$f")
  done
else
  # 用 ls 排序而不是 glob，避免空目录时 glob 字面量漏过去
  while IFS= read -r f; do [[ -n "$f" ]] && FILES+=("$f"); done \
    < <(ls -1 "$JOBS_DIR"/*.groovy 2>/dev/null || true)
fi
[[ ${#FILES[@]} -gt 0 ]] || { echo "${JOBS_DIR} 下没有任何 .groovy 定义" >&2; exit 2; }

TMP="$HERE/run/rendered"
mkdir -p "$TMP"

# ---- --list ------------------------------------------------------------------
if [[ $LIST -eq 1 ]]; then
  printf '%-28s %-22s %s\n' "JOB" "TRIGGER" "参数"
  printf '%-28s %-22s %s\n' "----------------------------" "----------------------" "----"
  for f in "${FILES[@]}"; do
    name="$(basename "$f" .groovy)"
    meta="$($PY "$RENDER" "$f" >/dev/null 2>&1 && echo ok || echo bad)"
    if [[ "$meta" != "ok" ]]; then printf '%-28s %s\n' "$name" "🔴 元数据/脚本有问题"; continue; fi
    cron="$($PY - "$f" <<'PY'
import json, re, sys
raw = open(sys.argv[1], encoding='utf-8').read()
m = re.search(r"/\*\*@META\s*(.*?)\s*META\*/", raw, re.S)
meta = json.loads(m.group(1))
ps = ",".join(p["name"] for p in (meta.get("params") or []))
print("%s\t%s" % (meta.get("cron") or "-", ps or "-"))
PY
)"
    printf '%-28s %-22s %s\n' "$name" "${cron%%$'\t'*}" "${cron##*$'\t'}"
  done
  exit 0
fi

# ---- crumb -------------------------------------------------------------------
CRUMB_HDR=""
if [[ $DRY -eq 0 ]]; then
  CRUMB="$(curl -s --max-time 10 -u "$JENKINS_USER:$JENKINS_TOKEN" \
           "$JENKINS_URL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22:%22,//crumb)")"
  if [[ "$CRUMB" != *:* ]]; then
    echo "🔴 拿不到 CSRF crumb，认证可能失效：$CRUMB" >&2; exit 2
  fi
  CRUMB_HDR="-H $CRUMB"
  echo "✓ 已连接 ${JENKINS_URL} （用户 ${JENKINS_USER}）"
fi

# ---- 推送 --------------------------------------------------------------------
# 🔴 Content-Type 必须带 charset=UTF-8，否则中文字段会让 Jenkins 直接 500。
#    机理（实测，2026-10-12）：`POST /job/<n>/config.xml` 在服务端走的是
#    `AbstractItem.doConfigDotXml` → `req.getReader()`；Servlet 规范规定
#    Content-Type 未声明 charset 时 `getCharacterEncoding()` 返回 null，
#    容器按 **ISO-8859-1** 解码 ⇒ 中文描述变成乱码单字节 ⇒ SAX 报
#    「invalid XML character (Unicode: 0x94)」⇒ HTTP 500。
#    而 `POST /createItem` 走 `req.getInputStream()`（交给 XML 解析器自认 UTF-8 声明），
#    **所以「首次创建成功、第二次更新全 500」这个假象会骗人** —— 别据此判断请求头没问题。
CT_HDR='Content-Type: application/xml; charset=UTF-8'
FAILED=0
OKN=0
for f in "${FILES[@]}"; do
  name="$(basename "$f" .groovy)"
  xml="$TMP/$name.xml"
  if ! $PY "$RENDER" "$f" > "$xml"; then
    echo "🔴 渲染失败：$name" >&2; FAILED=$((FAILED+1)); continue
  fi
  size=$(wc -c < "$xml" | tr -d ' ')

  if [[ $DRY -eq 1 ]]; then
    printf '  [dry-run] %-28s → %s bytes\n' "$name" "$size"; OKN=$((OKN+1)); continue
  fi

  # 先试更新（已存在），404 再创建。比「先查 existence」少一次往返且无竞态。
  code="$(curl -s -o /dev/null -w '%{http_code}' -X POST --max-time 30 \
            -u "$JENKINS_USER:$JENKINS_TOKEN" $CRUMB_HDR \
            -H "$CT_HDR" --data-binary "@$xml" \
            "$JENKINS_URL/job/$name/config.xml")"
  if [[ "$code" == "404" ]]; then
    code="$(curl -s -o /dev/null -w '%{http_code}' -X POST --max-time 30 \
              -u "$JENKINS_USER:$JENKINS_TOKEN" $CRUMB_HDR \
              -H "$CT_HDR" --data-binary "@$xml" \
              "$JENKINS_URL/createItem?name=$name")"
    verb="创建"
  else
    verb="更新"
  fi

  if [[ "$code" == "200" ]]; then
    printf '  \033[1;32m✓\033[0m %-28s %s成功\n' "$name" "$verb"; OKN=$((OKN+1))
  else
    printf '  \033[1;31m✗\033[0m %-28s HTTP %s\n' "$name" "$code"; FAILED=$((FAILED+1))
  fi
done

# ---- 视图 --------------------------------------------------------------------
if [[ $DO_VIEW -eq 1 && $DRY -eq 0 ]]; then
  vxml="$TMP/view.xml"
  {
    echo '<?xml version="1.1" encoding="UTF-8"?>'
    echo '<hudson.model.ListView>'
    echo "  <name>$VIEW_NAME</name>"
    echo '  <filterExecutors>false</filterExecutors>'
    echo '  <filterQueue>false</filterQueue>'
    echo '  <properties class="hudson.model.View$PropertyList"/>'
    echo '  <jobNames>'
    echo '    <comparator class="hudson.util.CaseInsensitiveComparator"/>'
    for f in "${FILES[@]}"; do
      echo "    <string>$(basename "$f" .groovy)</string>"
    done
    echo '  </jobNames>'
    echo '  <jobFilters/>'
    echo '  <columns>'
    echo '    <hudson.views.StatusColumn/>'
    echo '    <hudson.views.WeatherColumn/>'
    echo '    <hudson.views.JobColumn/>'
    echo '    <hudson.views.LastSuccessColumn/>'
    echo '    <hudson.views.LastFailureColumn/>'
    echo '    <hudson.views.LastDurationColumn/>'
    echo '    <hudson.views.BuildButtonColumn/>'
    echo '  </columns>'
    echo '  <recurse>false</recurse>'
    echo '</hudson.model.ListView>'
  } > "$vxml"

  VURL="$JENKINS_URL/view/$(printf '%s' "$VIEW_NAME" | $PY -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read().strip()))')"
  code="$(curl -s -o /dev/null -w '%{http_code}' -X POST --max-time 30 \
            -u "$JENKINS_USER:$JENKINS_TOKEN" $CRUMB_HDR \
            -H "$CT_HDR" --data-binary "@$vxml" "$VURL/config.xml")"
  if [[ "$code" == "404" ]]; then
    code="$(curl -s -o /dev/null -w '%{http_code}' -X POST --max-time 30 \
              -u "$JENKINS_USER:$JENKINS_TOKEN" $CRUMB_HDR \
              -H "$CT_HDR" --data-binary "@$vxml" \
              "$JENKINS_URL/createView?name=$(printf '%s' "$VIEW_NAME" | $PY -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.stdin.read().strip()))')")"
  fi
  if [[ "$code" == "200" ]]; then
    printf '  \033[1;32m✓\033[0m 视图 %s 已就绪\n' "$VIEW_NAME"
  else
    printf '  \033[1;33m!\033[0m 视图创建/更新返回 HTTP %s（job 本身不受影响）\n' "$code"
  fi
fi

echo
echo "完成：成功 ${OKN}，失败 $FAILED"
[[ $FAILED -eq 0 ]] || exit 1
exit 0
