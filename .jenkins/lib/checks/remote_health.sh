#!/usr/local/bin/bash
# =============================================================================
# remote_health.sh —— 生产服巡检（**只读**）的流水线适配层
#
# 为什么要有这一层，而不是直接在 Pipeline 里跑 server_health_check.py
# ---------------------------------------------------------------------
# `server_health_check.py` 的定位是「人读的邮件」：先打印几十行报告，最后再打一段 JSON。
# 放进 CI 需要三件它本身没提供的东西：
#   1. **机器可判的退出码**（有 🔴 严重项就该让这个环节变红，而不是永远 rc=0）；
#   2. **一句话结论** —— 环节报告里只显示最后一行，所以要单独吐一行摘要；
#   3. **机器可读产物留档**（JSON 落盘），否则趋势图 / 后续对比没有抓手。
#
# 这里只做这三件事，采集逻辑一行都不重写 —— 巡检的权威实现永远是
# `scripts/server_health_check.py`，避免两套口径漂移。
#
# 🔴 默认不发邮件：`--dry-run` 保证只采集。本机已有一个 10:00 的巡检邮件自动化，
#    两边同时发会产生重复邮件，所以邮件开关由 job 参数显式控制（默认关）。
#
# 用法：.jenkins/lib/checks/remote_health.sh [--mail]
# 退出码：0 无严重项；1 有 🔴 严重项；2 采集失败/取不到 JSON
# =============================================================================
set -uo pipefail

PROJ="${PROJ:-/Users/wangxufeng/Documents/TimeSpaceGirl1}"
PY="${PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
RUN_DIR="${TS_RUN_DIR:-/tmp}"
cd "$PROJ" || exit 2

SEND_MAIL=0
[[ "${1:-}" == "--mail" ]] && SEND_MAIL=1

REPORT="$RUN_DIR/health-report.txt"
JSONF="$RUN_DIR/health.json"

ARGS=(--json --no-state)
[[ $SEND_MAIL -eq 1 ]] || ARGS+=(--dry-run)

echo "运行：scripts/server_health_check.py ${ARGS[*]}"
"$PY" scripts/server_health_check.py "${ARGS[@]}" > "$REPORT" 2>&1
PRC=$?

if [[ ! -s "$REPORT" ]]; then
  echo "🔴 采集失败：控制台没有任何输出（脚本 rc=${PRC}）"
  exit 2
fi

# 拆解交给 health_report.py：它用 JSONDecoder.raw_decode 精确吃一个 JSON 对象，
# 不会像「取标记之后的全部文本」那样把尾行（例如 --dry-run 的提示）一起塞进 JSON。
"$PY" .jenkins/lib/checks/health_report.py "$REPORT" "$JSONF"
RC=$?

if [[ $RC -eq 0 ]]; then
  echo
  echo "✅ 生产服无严重异常（报告留档：${REPORT}，JSON：${JSONF}）"
elif [[ $RC -eq 1 ]]; then
  echo
  echo "🔴 生产服发现严重异常（详见 ${REPORT}）"
else
  echo
  echo "🔴 巡检采集/解析失败（脚本 rc=${PRC}，报告 ${REPORT}）"
  tail -20 "$REPORT"
fi
exit $RC
