#!/usr/local/bin/bash
# =============================================================================
# play_gate.sh —— 发布闸门「代码级」自检（**只读**，不联网、不上传）
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
# 🔴 2026-10-13 语义再收紧一层：**默认目标轨道是 internal（内部测试），不是 production**。
#    internal 不面向公众、免常规审核、可随时 halt/替换 ⇒ 豁免 --publish；
#    其余轨道（production / beta / alpha）照旧「送审必须显式抬旗」。
#
# 用法：.jenkins/lib/checks/play_gate.sh
# 退出码：0 闸门完好；1 闸门被削弱（危险）；2 环境错误
# =============================================================================
set -uo pipefail

PROJ="${PROJ:-/Users/wangxufeng/Documents/TimeSpaceGirl1}"
cd "$PROJ" || exit 2

SH="scripts/aab_release.sh"
PYF="scripts/play_upload.py"
PY="${PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
FAIL=0
ok()  { printf '   ✓ %s\n' "$1"; }
bad() { printf '   🔴 %s\n' "$1"; FAIL=1; }

for f in "$SH" "$PYF"; do
  [[ -f "$f" ]] || { echo "找不到 $f" >&2; exit 2; }
done

assert_line() { # $1=文件 $2=正则 $3=说明
  if grep -Eq "$2" "$1"; then ok "$3"; else bad "${3}（当前不成立，闸门可能已被改坏）"; fi
}

echo "── ① aab_release.sh 默认值（必须是「不上传 / 内部测试」）────"
assert_line "$SH" '^DO_UPLOAD=0'                     "DO_UPLOAD 默认 0 —— 不加 --upload 不上传"
assert_line "$SH" '^TRACK="internal"'                "TRACK 默认 internal —— 默认传内部测试轨道，不是 production"
assert_line "$SH" '^STATUS_FOR_INTERNAL="completed"' "internal 默认 completed —— 传完测试员即可装"
assert_line "$SH" '^STATUS_FOR_OTHER="draft"'        "其余轨道默认 draft —— 不送审"
assert_line "$SH" '^ALLOW_PROD=0'                    "ALLOW_PROD 默认 0 —— 不加 --production 不写 production"
assert_line "$SH" '^ALLOW_PUBLISH=0'                 "ALLOW_PUBLISH 默认 0 —— 不加 --publish 不送审"
assert_line "$SH" '\-\-upload\)'                     "--upload 旗标存在"
assert_line "$SH" '\-\-internal\)'                   "--internal 旗标存在"
assert_line "$SH" '\-\-production\)'                 "--production 旗标存在"
assert_line "$SH" '\-\-publish\)'                    "--publish 旗标存在"

echo "── ① play_upload.py 默认值 ────────────────────────"
assert_line "$PYF" '"--track", default="internal"'   "--track 默认 internal"
assert_line "$PYF" 'args.status is None'             "--status 缺省时按轨道推导（不再写死 draft/completed）"
assert_line "$PYF" 'allow-production-write'          "--allow-production-write 闸门存在"
assert_line "$PYF" 'allow-publish'                   "--allow-publish 闸门存在"

echo "── ② 行为断言：这些组合必须被闸门拒 ───────────────"
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
probe_refused "--upload --track production（缺 --production）" --upload --track production
probe_refused "--upload --track production --status completed（缺 --production 与 --publish）" \
              --upload --track production --status completed
probe_refused "--upload --production --status completed（缺 --publish）" \
              --upload --production --status completed
probe_refused "--upload --production --status inProgress（缺 --publish）" \
              --upload --production --status inProgress --user-fraction 0.1

echo "── ② 行为断言：这些组合不该被闸门拦 ───────────────"
# 🔴 用「不存在的 --aab」走快速路径：能立刻在「定位产物」一步退出，
#    不启动 Unity、不联网、不碰 Play API。（旧实现会真跑完整校验链，
#    既慢、又隐性依赖 apks/ 里恰好有包。）
PROBE_AAB='/tmp/__play_gate_probe__.aab'
probe_allowed() { # $1=说明，其余=参数
  local desc="$1"; shift
  local out
  out="$(bash "$SH" --skip-build --aab "$PROBE_AAB" "$@" 2>&1 || true)"
  if printf '%s' "$out" | grep -q "$GATE_TAG"; then
    printf '   🔴 %s → **被闸门拦了**（不该拦）\n' "$desc"; FAIL=1
    printf '%s\n' "$out" | tail -3 | sed 's/^/       /'
  else
    printf '   ✓ %s → 未被闸门拦（预期）\n' "$desc"
  fi
}
probe_allowed "--upload（默认 internal + completed，传完即可测）" --upload
probe_allowed "--upload --track internal --status draft" --upload --track internal --status draft
probe_allowed "--upload --production --status draft（草稿允许）" --upload --production --status draft

echo "── ③ play_upload.py 行为断言（不联网：闸门在密钥解析之前）──"
PY_PROBE_AAB="$(mktemp -t play_gate_probe)"
NOKEY='/tmp/__play_gate_no_such_key__.json'
cleanup() { rm -f "$PY_PROBE_AAB"; }
trap cleanup EXIT
# 造一个 ≥1MB 的假 AAB 过体积检查；密钥路径故意不存在 ⇒ 闸门若放行会死于「找不到密钥」，
# 但绝不会联网、更不会上传。
dd if=/dev/zero of="$PY_PROBE_AAB" bs=1024 count=1100 2>/dev/null

py_probe() { # $1=期望 expect_refuse|expect_allow，$2=说明，其余=参数
  local want="$1" desc="$2"; shift 2
  local out rc hit
  out="$("$PY" "$PYF" --aab "$PY_PROBE_AAB" --service-account "$NOKEY" "$@" 2>&1)"; rc=$?
  if printf '%s' "$out" | grep -q "$GATE_TAG"; then hit=1; else hit=0; fi
  if [[ "$want" == "refuse" ]]; then
    if [[ $rc -ne 0 && $hit -eq 1 ]]; then
      printf '   ✓ %s → 被拒（rc=%s）\n' "$desc" "$rc"
    else
      printf '   🔴 %s → 竟然放行（rc=%s），闸门失效\n' "$desc" "$rc"; FAIL=1
      printf '%s\n' "$out" | tail -3 | sed 's/^/       /'
    fi
  else
    if [[ $hit -eq 0 ]]; then
      printf '   ✓ %s → 未被闸门拦（预期；实际死于「找不到密钥」= 已过闸门）\n' "$desc"
    else
      printf '   🔴 %s → 被闸门拦了（不该拦）\n' "$desc"; FAIL=1
      printf '%s\n' "$out" | tail -3 | sed 's/^/       /'
    fi
  fi
}
py_probe refuse "--track production（缺 --allow-production-write）" \
         --track production --yes
py_probe refuse "--track production --status completed（缺 --allow-publish）" \
         --track production --status completed --allow-production-write --yes
py_probe allow  "--track internal --yes（默认内部测试，免 --allow-publish）" \
         --track internal --yes

echo
if [[ $FAIL -eq 0 ]]; then
  echo "✅ 发布闸门完好：默认只传 internal（内部测试），正式版必须显式抬旗"
else
  echo "🔴 发布闸门已被削弱 —— 存在误送审风险，请立刻修回（见 docs/android_release_runbook.md）"
fi
exit $FAIL
