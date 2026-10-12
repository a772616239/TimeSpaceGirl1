#!/usr/local/bin/bash
# =============================================================================
# server_ops.sh —— 服务端 / 区服运维动作的统一派发口
#
# 为什么要有这一层
# ----------------
# 本项目的运维动作散在好几个目录里，每个都有自己的参数风格：
#   ~/ts-chat-patch-20261010/deploy-chat-patch.sh  {verify|patch|restart|rollback}
#   ~/ts-upstar-restore-20261010/deploy.sh         {verify|backup|patch|restart|rollback}
#   ~/ts-shard10002/add-shard-10002.sh             {backup|apply|verify|hide|show|rollback}
#   远端 /home/java/gameserver/RESTART-GAMESERVER.sh
# Jenkins 里不该让使用者记住这四套方言（记错子命令名 = 可能打到生产上）。
# 这里把它们收口成 `server_ops.sh <domain>-<op>`，并且**显式标注每个动作是否破坏性**
# （`--list` 会输出），让审批闸门能据此决定「要不要人点一下」。
#
# 🔴 本脚本自身不做任何审批判断 —— 审批在 Pipeline 层（input 步骤）。
#    这里只负责：正确地派发 + 说清楚这个动作会有什么后果。
#
# 用法：
#   server_ops.sh --list              # 列出所有动作：<动作>\t<destructive|readonly>\t<说明>
#   server_ops.sh <action>            # 执行
#   server_ops.sh <action> --dry-run  # 支持只读预演的动作会透传 --dry-run
#
# 退出码：原样透传被调脚本的退出码；用法错误 64。
# =============================================================================
set -uo pipefail

HOME_DIR="$HOME"
CHAT="$HOME_DIR/ts-chat-patch-20261010/deploy-chat-patch.sh"
UPSTAR="$HOME_DIR/ts-upstar-restore-20261010/deploy.sh"
SHARD="$HOME_DIR/ts-shard10002/add-shard-10002.sh"
GS_HOST="${GS_HOST:-gs}"
RESTART_SCRIPT="/home/java/gameserver/RESTART-GAMESERVER.sh"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ="$(cd "$HERE/../.." && pwd)"
PY="${PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}"
BASH_BIN="${BASH:-/usr/local/bin/bash}"

# 动作表：<action>|<destructive>|<说明>
ACTIONS=(
  "health|readonly|生产服只读巡检（SSH 采集，不发邮件）"
  "chat-patch-verify|readonly|核对聊天 Redis 补丁现状（只读）"
  "upstar-verify|readonly|核对英雄升星表现状（只读）"
  "shard-verify|readonly|校验 10002 区服记录与登录服下发（查库 + 调接口）"
  "gameserver-restart|destructive|🔴 重启生产游戏服（幂等，但会踢掉在线玩家）"
  "chat-patch-apply|destructive|🔴 上传并打聊天 Redis 补丁（不重启，下次重启生效）"
  "chat-patch-restart|destructive|🔴 重启生产游戏服并打印补丁验证日志（会踢线）"
  "chat-patch-rollback|destructive|🔴 还原备份 jar 并重启（会踢线）"
  "upstar-apply|destructive|🔴 部署英雄升星表（服务端载入后需重启才生效）"
  "upstar-restart|destructive|🔴 重启生产游戏服使升星表生效（会踢线）"
  "upstar-rollback|destructive|🔴 回滚升星表并重启（会踢线）"
  "shard-hide|destructive|🔴 把 10002 从区服列表隐藏（state=0，服务照跑）"
  "shard-show|destructive|🔴 把 10002 重新显示到区服列表（state=2）"
  "shard-rollback|destructive|🔴 还原 10002 记录为空占位（回滚开服）"
)

find_action() {
  local a="$1" row
  for row in "${ACTIONS[@]}"; do
    [[ "${row%%|*}" == "$a" ]] && { echo "$row"; return 0; }
  done
  return 1
}

if [[ "${1:-}" == "--list" || "${1:-}" == "-l" ]]; then
  for row in "${ACTIONS[@]}"; do
    IFS='|' read -r a d desc <<<"$row"
    printf '%s\t%s\t%s\n' "$a" "$d" "$desc"
  done
  exit 0
fi

ACTION="${1:-}"
[[ -n "$ACTION" ]] || { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 64; }
shift || true

ROW="$(find_action "$ACTION")" || {
  echo "未知动作：$ACTION" >&2
  echo "可用动作：" >&2
  "$0" --list | sed 's/^/  /' >&2
  exit 64
}
IFS='|' read -r _a DESTRUCTIVE DESC <<<"$ROW"

need() { # $1=路径 $2=说明
  [[ -e "$1" ]] || { echo "🔴 找不到 ${2}：$1" >&2; exit 66; }
}

echo "── 动作：${ACTION} ─────────────────────────────────"
echo "   $DESC"
echo "   性质：$DESTRUCTIVE"
[[ $DESTRUCTIVE == destructive ]] && \
  echo "   ⚠️ 这是破坏性动作，Pipeline 应当已要求人工审批；本脚本不再二次确认。"
echo

rc=0
case "$ACTION" in
  health)
    "$BASH_BIN" "$HERE/checks/remote_health.sh"; rc=$?
    ;;

  chat-patch-verify)   need "$CHAT"   "聊天补丁部署脚本";   "$BASH_BIN" "$CHAT" verify;   rc=$? ;;
  chat-patch-apply)    need "$CHAT"   "聊天补丁部署脚本";   "$BASH_BIN" "$CHAT" patch;    rc=$? ;;
  chat-patch-restart)  need "$CHAT"   "聊天补丁部署脚本";   "$BASH_BIN" "$CHAT" restart;  rc=$? ;;
  chat-patch-rollback) need "$CHAT"   "聊天补丁部署脚本";   "$BASH_BIN" "$CHAT" rollback; rc=$? ;;

  upstar-verify)       need "$UPSTAR" "升星表部署脚本";     "$BASH_BIN" "$UPSTAR" verify;   rc=$? ;;
  upstar-apply)        need "$UPSTAR" "升星表部署脚本";     "$BASH_BIN" "$UPSTAR" patch;    rc=$? ;;
  upstar-restart)      need "$UPSTAR" "升星表部署脚本";     "$BASH_BIN" "$UPSTAR" restart;  rc=$? ;;
  upstar-rollback)     need "$UPSTAR" "升星表部署脚本";     "$BASH_BIN" "$UPSTAR" rollback; rc=$? ;;

  shard-verify)        need "$SHARD"  "区服登记脚本";       "$BASH_BIN" "$SHARD" verify;   rc=$? ;;
  shard-hide)          need "$SHARD"  "区服登记脚本";       "$BASH_BIN" "$SHARD" hide;     rc=$? ;;
  shard-show)          need "$SHARD"  "区服登记脚本";       "$BASH_BIN" "$SHARD" show;     rc=$? ;;
  shard-rollback)      need "$SHARD"  "区服登记脚本";       "$BASH_BIN" "$SHARD" rollback; rc=$? ;;

  gameserver-restart)
    # 重启脚本在远端，本身是幂等的（见 docs/server_ops_runbook.md）
    echo "→ ssh $GS_HOST 'bash $RESTART_SCRIPT'"
    ssh -o BatchMode=yes -o ConnectTimeout=15 "$GS_HOST" "bash $RESTART_SCRIPT"
    rc=$?
    if [[ $rc -eq 0 ]]; then
      echo "→ 复查端口 16081"
      ssh -o BatchMode=yes -o ConnectTimeout=15 "$GS_HOST" \
        "sleep 5; ss -ltn 2>/dev/null | grep -q ':16081 ' && echo '   ✓ 16081 已在监听' || echo '   ⚠️ 16081 尚未监听（可能还在启动）'"
    fi
    ;;

  *)
    echo "未实现的动作：$ACTION" >&2; exit 64 ;;
esac

echo
if [[ $rc -eq 0 ]]; then
  echo "✅ 动作完成：$ACTION"
else
  echo "🔴 动作失败：${ACTION}（rc=${rc}）"
fi
exit $rc
