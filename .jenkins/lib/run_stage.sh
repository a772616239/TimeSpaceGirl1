#!/usr/local/bin/bash
# =============================================================================
# run_stage.sh —— 跑一个环节，并把结果登记进环节报告
#
# 为什么需要它：Pipeline 里每个 stage 都要「跑脚本 → 抓输出 → 判红绿 → 登记结论」，
# 如果每个 stage 手写一遍，迟早会出现「stage 绿了但结论没登记」或反过来的漂移。
# 这里把这段约定收口成一个入口，job 定义里就能一个环节写一行。
#
# 用法：
#   run_stage.sh --name "AB 就绪体检" [--group "客户端资源链"] [--warn-ok] \
#                [--warn-rc 3] [--slug ab-ready] [--timeout 600] -- <命令...>
#
# 语义：
#   - 命令 rc=0            -> pass
#   - 命令 rc 命中 --warn-rc -> warn（以 0 退出，只提示不阻断）
#   - 命令 rc!=0 且有 --warn-ok -> warn（以 0 退出，只提示不阻断）
#   - 其余 rc!=0           -> fail（本脚本以相同 rc 退出，Pipeline 会变红）
#   - --timeout 用 `timeout` 兜底，避免某个环节把 executor 挂死
#
# 为什么有 --warn-rc（而不只用 --warn-ok）：
#   有些检查要区分「环境坏了」（必须红）和「环境好的但有临时状态」（只该黄）——
#   例如 android_env.sh：rc=1 = 缺 keystore/模板被重置（真问题），
#   rc=3 = 一切就绪但本工程被 Unity 编辑器占用（打包暂时做不了，不是缺陷）。
#   总览 job 用 --warn-rc 3 标黄；打包 job 什么都不加，rc=3 就是硬阻塞。
#
# 环境变量：
#   TS_RUN_DIR  本次运行的证据目录（由 Pipeline 传入；缺省则 ./run/<epoch>）
#   TS_PY       环节报告用的 python（缺省用工程 venv）
#   TS_REPORT   环节报告脚本路径（缺省 .jenkins/lib/stage_report.py）
#
# 退出码：与所跑命令一致；登记环节报告本身失败**不会**改变业务退出码。
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PY="${TS_PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
REPORT="${TS_REPORT:-$ROOT/.jenkins/lib/stage_report.py}"
RUN_DIR="${TS_RUN_DIR:-$ROOT/.jenkins/run/$(date +%Y%m%d-%H%M%S)}"

NAME=""; GROUP=""; SLUG=""; TIMEOUT=""; WARN_OK=0; WARN_RCS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)    NAME="$2";    shift 2 ;;
    --group)   GROUP="$2";   shift 2 ;;
    --slug)    SLUG="$2";    shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --warn-ok) WARN_OK=1;    shift ;;
    --warn-rc) WARN_RCS="$2"; shift 2 ;;
    --)        shift; break ;;
    *) echo "run_stage: 未知参数 $1" >&2; exit 2 ;;
  esac
done

[[ -n "$NAME" ]] || { echo "run_stage: 必须给 --name" >&2; exit 2; }
[[ $# -gt 0 ]]  || { echo "run_stage: 必须给要执行的命令（用 -- 分隔）" >&2; exit 2; }

[[ -n "$SLUG" ]] || SLUG="$(printf '%s' "$NAME" \
  | tr ' ' '-' | sed 's/[^0-9A-Za-z_-]//g' | cut -c1-48)"
[[ -n "$SLUG" ]] || SLUG="stage"

LOGDIR="$RUN_DIR/logs"; mkdir -p "$LOGDIR"
LOG="$LOGDIR/$SLUG.log"

printf '\n\033[1;36m┌─ 环节：%s\033[0m\n' "$NAME"
printf '   \033[0;90m$ %s\033[0m\n' "$*"

start=$(date +%s)
if [[ -n "$TIMEOUT" ]]; then
  set +e
  # macOS 无 GNU timeout；有 gtimeout 就用，没有就自己兜（不引入依赖）
  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$TIMEOUT" "$@" 2>&1 | tee "$LOG"
  else
    "$@" 2>&1 | tee "$LOG"
  fi
  rc=${PIPESTATUS[0]}
else
  set +e
  "$@" 2>&1 | tee "$LOG"
  rc=${PIPESTATUS[0]}
fi
end=$(date +%s); dur=$((end - start))

# 结论摘要：取日志里最后一条非空行；过长则截断（原始全文在 ${LOG}）
# 🔴 必须先洗掉 ANSI 颜色码：日志带颜色，而 ESC(0x1b) 是 XML 1.0 非法字符，
#    漏进 junit.xml 会让**整份测试报告**解析失败（实测 2026-10-12：Jenkins 只留一条
#    [failed-to-read]，控制台却一字不报）。清洗复用 stage_report.py 的 sanitize()，
#    避免两处各写一份正则。
DETAIL="$(grep -v '^[[:space:]]*$' "$LOG" 2>/dev/null | tail -1 \
          | "$PY" "$REPORT" san 2>/dev/null | cut -c1-180 || true)"
[[ -n "$DETAIL" ]] || DETAIL="(无输出)"

# --warn-rc 支持逗号分隔（如 --warn-rc 3,4）
is_warn_rc() {
  local r="$1" x
  [[ -n "$WARN_RCS" ]] || return 1
  local IFS=','
  for x in $WARN_RCS; do
    [[ "$x" == "$r" ]] && return 0
  done
  return 1
}

if [[ $rc -eq 0 ]]; then
  STATUS="pass"
elif is_warn_rc "$rc" || [[ $WARN_OK -eq 1 ]]; then
  STATUS="warn"
  DETAIL="rc=${rc} · $DETAIL"
else
  STATUS="fail"
  DETAIL="rc=${rc} · $DETAIL"
fi

LOGREL="${LOG#"$ROOT"/}"
if ! "$PY" "$REPORT" add --run "$RUN_DIR" --name "$NAME" --group "${GROUP:-默认}" \
      --status "$STATUS" --detail "$DETAIL" --log "$LOGREL" --duration "$dur"; then
  printf '\033[1;33m   ! 环节报告登记失败（不影响业务结论）\033[0m\n' >&2
fi

if [[ "$STATUS" == "pass" ]]; then
  printf '\033[1;32m└─ ✓ %s（%ss）\033[0m\n' "$NAME" "$dur"
elif [[ "$STATUS" == "warn" ]]; then
  printf '\033[1;33m└─ ! %s 需关注（%ss）\033[0m\n' "$NAME" "$dur"
else
  printf '\033[1;31m└─ ✗ %s 失败 rc=%s（%ss，日志 %s）\033[0m\n' "$NAME" "$rc" "$dur" "$LOG"
fi

if [[ "$STATUS" == "pass" || "$STATUS" == "warn" ]]; then
  exit 0
fi
exit "$rc"
