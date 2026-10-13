#!/usr/local/bin/bash
# =============================================================================
# play_gate.sh —— 送审闸门「代码级」自检（**只读**，不联网、不上传）
#
# 为什么要专门为「闸门本身」写一条检查
# ------------------------------------
# 2026-10-12 的真实事故：用户明确要求「不要帮我送审」，包还是被传成了 `completed`
# （= 提交审核 + 面向全量）。事后查明根因**不是纪律松，而是默认值就是发布**：
# `play_upload.py --status` 默认 `completed`、`aab_release.sh` 的 `STATUS` 默认 `completed`
# 且 `DO_UPLOAD=1` —— 三个入口只要有一个漏传参数就直接送审。
#
# 修复是把默认值改成「拒绝」，但那属于**代码里的约定**，随时可能被
# 「顺手改回去」「合并冲突选错一边」「回滚别的东西时误伤」悄悄削弱 ——
# 而闸门一旦失效，下一次误送审不会有任何征兆。
#
# 所以这里把约定变成**可执行断言**：
#   ① 默认值断言（纯文本，快）
#   ② 行为断言（真的跑一遍参数组合，看是否被拒）—— 断言的是行为而不是文本，
#      「注释里写了拒绝但代码放行」这种最能骗过 review 的情况会被②抓住。
#
# 用法：.jenkins/lib/checks/play_gate.sh
# 退出码：0 闸门完好；1 闸门被削弱（危险）；2 环境错误
# =============================================================================
set -uo pipefail

PROJ="${PROJ:-/Users/wangxufeng/Documents/TimeSpaceGirl1}"
cd "$PROJ" || exit 2

SH="scripts/aab_release.sh"
PYF="scripts/play_upload.py"
FAIL=0
ok()  { printf '   ✓ %s\n' "$1"; }
bad() { printf '   🔴 %s\n' "$1"; FAIL=1; }

for f in "$SH" "$PYF"; do
  [[ -f "$f" ]] || { echo "找不到 $f" >&2; exit 2; }
done

assert_line() { # $1=文件 $2=正则 $3=说明
  if grep -Eq "$2" "$1"; then ok "$3"; else bad "${3}（当前不成立，闸门可能已被改坏）"; fi
}

echo "── ① aab_release.sh 默认值（必须全部是「拒绝」）────"
assert_line "$SH" '^DO_UPLOAD=0'     "DO_UPLOAD 默认 0 —— 不加 --upload 不上传"
assert_line "$SH" '^STATUS="draft"'  "STATUS 默认 draft —— 不加参数只出草稿"
assert_line "$SH" '^ALLOW_PROD=0'    "ALLOW_PROD 默认 0 —— 不加 --production 不写 production"
assert_line "$SH" '^ALLOW_PUBLISH=0' "ALLOW_PUBLISH 默认 0 —— 不加 --publish 不送审"
assert_line "$SH" '\-\-upload\)'     "--upload 旗标存在"
assert_line "$SH" '\-\-production\)' "--production 旗标存在"
assert_line "$SH" '\-\-publish\)'    "--publish 旗标存在"

echo "── ① play_upload.py 默认值 ────────────────────────"
assert_line "$PYF" '"--status", default="draft"' "--status 默认 draft"
assert_line "$PYF" 'allow-production-write'      "--allow-production-write 闸门存在"
assert_line "$PYF" 'allow-publish'               "--allow-publish 闸门存在"

echo "── ② 行为断言：这些组合必须被拒 ───────────────────"
GATE_TAG='拒绝'
probe_refused() { # $1=说明，其余=参数
  local desc="$1"; shift
  local out rc
  out="$(bash "$SH" --skip-build "$@" 2>&1)"; rc=$?
  if [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q "$GATE_TAG"; then
    printf '   ✓ %s → 被拒（rc=%s）\n' "$desc" "$rc"
  elif [[ $rc -ne 0 ]]; then
    printf '   ⚠️ %s → 非 0 退出，但不是被闸门拒的（先看别的前置检查）\n' "$desc"
    printf '%s\n' "$out" | tail -3 | sed 's/^/       /'
    FAIL=1
  else
    printf '   🔴 %s → **竟然放行了**（rc=0），闸门失效\n' "$desc"; FAIL=1
  fi
}
probe_refused "--upload --status completed（缺 --production）" --upload --status completed
probe_refused "--upload --production --status completed（缺 --publish）" \
              --upload --production --status completed

echo "── ② 行为断言：这个组合不该被闸门拦（只到前置检查）──"
OUT="$(bash "$SH" --skip-build --upload --production --status draft 2>&1 || true)"
if printf '%s' "$OUT" | grep -q "$GATE_TAG"; then
  bad "--upload --production --status draft 被闸门拦了（不该拦，草稿是允许的）"
else
  ok "--upload --production --status draft 未被闸门拦（预期行为）"
fi

echo
if [[ $FAIL -eq 0 ]]; then
  echo "✅ 送审闸门完好：默认拒绝，送审必须显式抬旗"
else
  echo "🔴 送审闸门已被削弱 —— 存在误送审风险，请立刻修回（见 docs/android_release_runbook.md）"
fi
exit $FAIL
