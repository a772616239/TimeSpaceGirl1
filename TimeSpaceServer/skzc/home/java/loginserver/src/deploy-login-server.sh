#!/bin/bash
#
# 把补丁后的 GetServerListController.class 部署到线上登录服（腾讯云 gs）
#
# 用途：让 tk/getServerList 开始下发 name_en / name_jp / name_kr，
#      使「新增区服只需写数据、客户端零改动」成立。
#
# 🔴 影响面：换 class 必须重载 tk 应用（约 1~3 秒），期间登录请求会失败。
#    因此本脚本默认只做检查，**必须显式传 --confirm 才会真正动线上**。
#
# 用法：
#   ./deploy-login-server.sh check            # 只读体检：比对 md5、取基线响应，不改任何东西
#   ./deploy-login-server.sh deploy --confirm # 备份 → 上传 → 重载 → 轮询验证（失败自动回滚）
#   ./deploy-login-server.sh verify           # 只读：打接口确认返回正常、分语言字段是否出现
#   ./deploy-login-server.sh rollback --confirm  # 还原 class 并重载
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GS_SSH="${GS_SSH:-gs}"
SSH_OPTS=(-o ConnectTimeout=15 -o BatchMode=yes)

TC="/home/java/loginserver/apache-tomcat-8.5.95"
CLASS_REL="webapps/tk/WEB-INF/classes/com/ljsd/controller/GetServerListController.class"
WEBXML_REL="webapps/tk/WEB-INF/web.xml"
CLASS_PATH="$TC/$CLASS_REL"
BACKUP_DIR="$TC/backup-gsl-i18n"
LOCAL_BACKUP="$HERE/backup-gsl-i18n"
BASELINE_MD5="87104ceebb8898be15d3a1398354a3e4"
# 客户端硬编码 channel=pc / plat=android / sub_channel=1；server_version 用线上真实版本号
URL="http://127.0.0.1:8080/tk/getServerList?openId=deploy-check&channel=pc&plat=android&sub_channel=1&server_version=1.26001"

MODE="${1:-check}"
CONFIRM=0
for a in "$@"; do [ "$a" = "--confirm" ] && CONFIRM=1; done

say() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { echo "❌ $*" >&2; exit 1; }
remote() { ssh "${SSH_OPTS[@]}" "$GS_SSH" "$@"; }

need_confirm() {
  [ "$CONFIRM" -eq 1 ] || die "这是会上线/动线上部署的操作，请显式加 --confirm
   （影响：重载 tk 应用期间约 1~3 秒内登录请求会失败）"
}

# 确保本地产物存在且是最新编译
ensure_artifact() {
  local out="$HERE/dist/GetServerListController.class"
  if [ ! -f "$out" ]; then
    say "本地缺少 dist/GetServerListController.class，先跑 build-and-verify.sh --emit-class"
    "$HERE/build-and-verify.sh" --emit-class >/dev/null 2>&1 || die "编译或验证失败，禁止部署"
  fi
  [ -f "$out" ] || die "仍拿不到补丁 class"
  MD5_NEW="$(md5 -q "$out" 2>/dev/null || md5sum "$out" | awk '{print $1}')"
  say "本地产物 md5 = $MD5_NEW"
}

remote_state() { # 打印线上当前 class 的 md5 与备份情况
  remote "md5sum '$CLASS_PATH' 2>/dev/null | awk '{print \$1}'; \
          ls -1 '$BACKUP_DIR' 2>/dev/null | tail -3"
}

fetch_baseline() { # 从云服本机打接口（不经过公网），拿到当前真实响应
  remote "curl -s --max-time 15 '$URL'"
}

wait_healthy() { # 轮询直到接口恢复正常；$1 = 最多等几秒
  local limit="${1:-90}" waited=0 body=""
  while [ "$waited" -lt "$limit" ]; do
    body="$(fetch_baseline || true)"
    if echo "$body" | grep -q '"serverList"'; then
      echo "$body"
      return 0
    fi
    sleep 3
    waited=$((waited + 3))
  done
  return 1
}

case "$MODE" in
  check)
    ensure_artifact
    say "线上当前 class："
    remote "ls -la '$CLASS_PATH'; md5sum '$CLASS_PATH'"
    CUR="$(remote "md5sum '$CLASS_PATH' | awk '{print \$1}'" | tr -d '\r')"
    say "线上 md5 = $CUR"
    if [ "$CUR" = "$MD5_NEW" ]; then
      say "👉 线上已经是补丁版，无需再部署"
    elif [ "$CUR" = "$BASELINE_MD5" ]; then
      say "👉 线上是已知基线版，可以部署"
    else
      say "⚠️ 线上 md5 既不是基线也不是补丁版 —— 线上可能已被别人改过，先弄清楚再动"
    fi
    say "接口当前响应："
    fetch_baseline
    echo
    say "（check 模式不改动任何东西；要部署请用 deploy --confirm）"
    ;;

  deploy)
    need_confirm
    ensure_artifact
    # 防并发：确认没有 unity 打包、其它 agent 正在跑
    say "1/5 备份线上 class"
    remote "mkdir -p '$BACKUP_DIR' && cp -p '$CLASS_PATH' '$BACKUP_DIR/GetServerListController.class.\$(date +%Y%m%d-%H%M%S).bak' && ls -la '$BACKUP_DIR' | tail -3"
    CUR="$(remote "md5sum '$CLASS_PATH' | awk '{print \$1}'" | tr -d '\r')"
    [ "$CUR" = "$MD5_NEW" ] && die "线上已经是补丁版，中止（避免重复重载）"
    mkdir -p "$LOCAL_BACKUP"
    scp "${SSH_OPTS[@]}" -q "$GS_SSH:$CLASS_PATH" "$LOCAL_BACKUP/GetServerListController.orig.class"
    say "   本地也留一份：$LOCAL_BACKUP/GetServerListController.orig.class"

    say "2/5 上传补丁 class"
    scp "${SSH_OPTS[@]}" -q "$HERE/dist/GetServerListController.class" "$GS_SSH:$CLASS_PATH.part"
    remote "mv '$CLASS_PATH.part' '$CLASS_PATH' && md5sum '$CLASS_PATH'"

    say "3/5 触发重载 tk 应用（touch web.xml，约 1~3 秒）"
    remote "touch '$WEBXML_REL'"

    say "4/5 轮询接口直到恢复（最多 90s）"
    if BODY="$(wait_healthy 90)"; then
      say "   ✅ 接口已恢复"
      echo "$BODY"
    else
      say "   🔴 接口在 90s 内未恢复，自动回滚"
      remote "cp -p \$(ls -1t '$BACKUP_DIR'/GetServerListController.class.*.bak | head -1) '$CLASS_PATH' && touch '$WEBXML_REL'"
      die "已回滚，请检查 $TC/logs/catalina.out"
    fi

    say "5/5 校验分语言字段是否下发"
    echo "$BODY" | grep -o 'name_en\|name_jp\|name_kr' | sort -u | sed 's/^/   发现字段：/' || \
      say "   （当前 server_info 里还没写分语言字段，所以不下发 —— 属正常）"
    say "部署完成"
    ;;

  verify)
    ensure_artifact
    say "线上 class md5：$(remote "md5sum '$CLASS_PATH' | awk '{print \$1}'" | tr -d '\r')"
    BODY="$(fetch_baseline)"
    [ -n "$BODY" ] || die "接口无响应"
    echo "$BODY" | python3 -m json.tool --no-ensure-ascii 2>/dev/null || echo "$BODY"
    echo
    FOUND="$(echo "$BODY" | grep -o 'name_en\|name_jp\|name_kr' | sort -u | tr '\n' ' ' || true)"
    if [ -n "$FOUND" ]; then
      say "✅ 已下发分语言字段：$FOUND"
    else
      say "ℹ️ 响应里没有分语言字段 —— 线上 server_info 尚未写 name_en/name_jp"
    fi
    ;;

  rollback)
    need_confirm
    say "回滚到最近一次备份"
    remote "ls -1t '$BACKUP_DIR'/GetServerListController.class.*.bak 2>/dev/null | head -1"
    remote "set -e; B=\$(ls -1t '$BACKUP_DIR'/GetServerListController.class.*.bak | head -1); \
            cp -p \"\$B\" '$CLASS_PATH'; touch '$WEBXML_REL'; echo restored from \$B; md5sum '$CLASS_PATH'"
    if BODY="$(wait_healthy 90)"; then
      say "✅ 回滚后接口正常"; echo "$BODY"
    else
      die "回滚后接口仍未恢复，请立刻查 $TC/logs/catalina.out"
    fi
    ;;

  *) echo "用法: $0 {check|deploy --confirm|verify|rollback --confirm}"; exit 2 ;;
esac
