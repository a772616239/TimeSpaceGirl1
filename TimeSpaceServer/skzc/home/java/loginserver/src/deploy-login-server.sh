#!/bin/bash
#
# 把补丁后的 GetServerListController.class 部署到线上登录服（腾讯云 gs）
#
# 用途：让 tk/getServerList 开始下发 name_en / name_jp / name_kr，
#      使「新增区服只需写数据、客户端零改动」成立。
#
# 🔴 影响面：换 class 必须重载 tk 应用（秒级，见下），期间 /tk/* 请求会失败。
#    因此本脚本默认只做检查，**必须显式传 --confirm 才会真正动线上**。
#
# 重载机制（本机 Tomcat 8.5.95 离线沙箱实测，非推测）：
#   · 上传新的 .class **不会**触发重载 —— 改动 WEB-INF/classes/** 不是被监视的资源。
#   · 必须先 touch webapps/tk/WEB-INF/web.xml，才会被 HostConfig 后台线程发现并
#     执行 context.reload()（只重载该应用，不重启 Tomcat）。
#   · reload 只重建该应用的 Context/ClassLoader，**不会**从 tk.war 重新解包
#     ⇒ 手工放进去的补丁 class 会保留。
#   · 触发有延迟：后台线程按周期扫描，本机实测 touch 后约 20~40s 才打印重载日志。
#     ⇒ 所以**不能**用「打接口看是否 200」当重载完成的判据（旧 class 期间照样 200，
#        会假报成功）。本脚本改为轮询 catalina.out 里的重载日志行。
#   · 🔴 **绝不要 touch webapps/tk.war**：改 WAR 会走 undeploy + 重新解包，
#        把补丁 class 覆盖回 WAR 里的原版（沙箱实测确认）。
#   · 真机重载耗时参考：同一应用的冷部署实测 3.5~6.2s（TLD/JAR 扫描 ~2.9s +
#        WebContextListener/Mongo 连接池 ~0.6s），reload 省掉解包但省不掉这两项
#        ⇒ 窗口按秒级估计。期间 /tk/* 返回失败，客户端重试即可。
#
# 用法：
#   ./deploy-login-server.sh check            # 只读体检：比对 md5、取基线响应，不改任何东西
#   ./deploy-login-server.sh deploy --confirm # 备份 → 上传 → touch web.xml → 等重载日志 → 验证
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
WEBXML_PATH="$TC/$WEBXML_REL"
WAR_PATH="$TC/webapps/tk.war"
CATALINA_OUT="$TC/logs/catalina.out"
BACKUP_DIR="$TC/backup-gsl-i18n"
LOCAL_BACKUP="$HERE/backup-gsl-i18n"
BASELINE_MD5="d2a576bb00d5e42a6e896af93bd9d312"   # = 10-12 部署的 i18n 版（recommend 收窄前的线上版本）
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
   （影响：重载 tk 应用期间 /tk/* 请求会失败，窗口为秒级，客户端重试即可）"
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

# tk 应用「被重载」的次数：catalina.out 里 HostConfig.reload 行且上下文名为 /tk。
# 只匹配 logger+方法名与 [/tk]（都不是本地化字符串），所以中英文 Tomcat 都适用。
reload_count() {
  remote "grep -a 'HostConfig.reload' '$CATALINA_OUT' 2>/dev/null | grep -a -F '[/tk]' | wc -l" \
    | tr -d ' \r'
}

# 记录 tk.war 的 mtime —— 若它变了，说明有人/某进程触碰了 WAR，会触发重新解包覆盖补丁
war_mtime() { remote "stat -c %Y '$WAR_PATH' 2>/dev/null || true" | tr -d ' \r'; }

# 线上 class 当前 md5
class_md5() { remote "md5sum '$CLASS_PATH' 2>/dev/null | awk '{print \$1}'" | tr -d ' \r'; }

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
    say "tk.war mtime        = $(war_mtime)"
    say "catalina.out 里 /tk 重载次数 = $(reload_count)"
    say "（check 模式不改动任何东西；要部署请用 deploy --confirm）"
    ;;

  deploy)
    need_confirm
    ensure_artifact
    # 防并发：确认没有 unity 打包、其它 agent 正在跑
    say "1/5 备份线上 class"
    TS="$(date +%Y%m%d-%H%M%S)"
    remote "mkdir -p '$BACKUP_DIR' && cp -p '$CLASS_PATH' '$BACKUP_DIR/GetServerListController.class.${TS}.bak' && ls -la '$BACKUP_DIR' | tail -3"
    CUR="$(remote "md5sum '$CLASS_PATH' | awk '{print \$1}'" | tr -d '\r')"
    [ "$CUR" = "$MD5_NEW" ] && die "线上已经是补丁版，中止（避免重复重载）"
    mkdir -p "$LOCAL_BACKUP"
    scp "${SSH_OPTS[@]}" -q "$GS_SSH:$CLASS_PATH" "$LOCAL_BACKUP/GetServerListController.orig.class"
    say "   本地也留一份：$LOCAL_BACKUP/GetServerListController.orig.class"

    say "2/5 上传补丁 class"
    scp "${SSH_OPTS[@]}" -q "$HERE/dist/GetServerListController.class" "$GS_SSH:$CLASS_PATH.part"
    remote "mv '$CLASS_PATH.part' '$CLASS_PATH' && md5sum '$CLASS_PATH'"

    say "3/5 触发重载 tk 应用（touch WEB-INF/web.xml）"
    say "   注：只上传 class 不会触发重载，必须 touch web.xml（本机沙箱实测）"
    N_BEFORE="$(reload_count)"; N_BEFORE="${N_BEFORE:-0}"
    WAR_BEFORE="$(war_mtime)"
    say "   基线：catalina.out 里 /tk 重载次数 = ${N_BEFORE}，tk.war mtime = $WAR_BEFORE"
    remote "touch '$WEBXML_PATH'"

    say "4/5 等 HostConfig 真正重载 /tk（最多 120s；后台线程按周期扫描，会有几十秒延迟）"
    N_AFTER="$N_BEFORE"; waited=0
    while [ "$waited" -lt 120 ]; do
      sleep 3; waited=$((waited + 3))
      N_AFTER="$(reload_count)"; N_AFTER="${N_AFTER:-0}"
      if [ "$N_AFTER" -gt "$N_BEFORE" ]; then
        say "   ✅ 已重载（次数 $N_BEFORE → ${N_AFTER}，约 ${waited}s 后触发）"
        break
      fi
    done
    if [ "$N_AFTER" -le "$N_BEFORE" ]; then
      # 没重载 ⇒ 运行中的仍是旧 class，线上行为没变（无害），但本次部署未生效
      say "   🔴 120s 内未观察到 /tk 重载日志 ⇒ 补丁未生效（线上仍在跑旧 class）"
      remote "cp -p \$(ls -1t '$BACKUP_DIR'/GetServerListController.class.*.bak | head -1) '$CLASS_PATH'"
      die "已把磁盘上的 class 还原为备份；请检查 $CATALINA_OUT 的 HostConfig 日志"
    fi

    # 护栏：确认没人动过 WAR（动 WAR 会 undeploy+重新解包，把补丁覆盖回原版）
    WAR_AFTER="$(war_mtime)"
    CUR_MD5="$(class_md5)"
    if [ "$WAR_AFTER" != "$WAR_BEFORE" ]; then
      say "   ⚠️ tk.war mtime 变了（$WAR_BEFORE → ${WAR_AFTER}）—— 可能被重新解包过，正在复核 class"
    fi
    if [ "$CUR_MD5" != "$MD5_NEW" ]; then
      die "🔴 class 已被覆盖（期望 ${MD5_NEW}，实际 ${CUR_MD5}）——多半是 tk.war 被触碰触发重新解包。
   补丁未生效；磁盘状态已回退到原版。请重跑本脚本，并确保过程中无人 touch tk.war。"
    fi
    say "   ✅ 磁盘 class md5 仍为补丁版，未被 WAR 覆盖"

    say "5/5 轮询接口恢复 + 校验"
    if BODY="$(wait_healthy 90)"; then
      say "   ✅ 接口已恢复"
      echo "$BODY"
    else
      die "🔴 接口在 90s 内未恢复。补丁 class 已在磁盘上且 /tk 已重载，
   请立刻检查 ${CATALINA_OUT}（不要盲目再次 touch web.xml）。"
    fi
    # 🔴 必须用 -E：BSD grep（macOS）在 BRE 下不认反斜杠竖线这个 alternation（GNU 扩展），
    #    会把它当字面量 ⇒ 匹配不到、退出 1 ⇒ 在 pipefail 下整条管道失败，
    #    于是把「有字段」误报成「没写字段」。|| true 再兜一层。
    FOUND="$(printf '%s' "$BODY" | grep -oE 'name_en|name_jp|name_kr' | sort -u | tr '\n' ' ' || true)"
    if [ -n "${FOUND// /}" ]; then
      say "   ✅ 已下发分语言字段：$FOUND"
    else
      say "   ⚠️ 响应里没有 name_en/name_jp/name_kr —— 请确认 server_info 里这几个字段是否已写"
    fi
    # 🔴 本补丁的核心断言：recommend 只允许来自 is_new=1 的新服。
    #    线上当前没有新服 ⇒ 响应里绝不该出现 recommend（老客户端就是被它打死的）。
    if printf '%s' "$BODY" | grep -q '"recommend"'; then
      die "🔴 补丁版仍在下发 recommend —— 补丁未生效或 server_info 里存在 is_new=1 的新服。
   响应：$BODY"
    fi
    say "   ✅ 响应里没有 recommend（recommend 只按新服下发，不再按在线人数兜底）"
    say "部署完成"
    ;;

  verify)
    ensure_artifact
    say "线上 class md5：$(remote "md5sum '$CLASS_PATH' | awk '{print \$1}'" | tr -d '\r')"
    BODY="$(fetch_baseline)"
    [ -n "$BODY" ] || die "接口无响应"
    echo "$BODY" | python3 -m json.tool --no-ensure-ascii 2>/dev/null || echo "$BODY"
    echo
    FOUND="$(printf '%s' "$BODY" | grep -oE 'name_en|name_jp|name_kr' | sort -u | tr '\n' ' ' || true)"
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
    N_BEFORE="$(reload_count)"; N_BEFORE="${N_BEFORE:-0}"
    remote "set -e; B=\$(ls -1t '$BACKUP_DIR'/GetServerListController.class.*.bak | head -1); \
            cp -p \"\$B\" '$CLASS_PATH'; touch '$WEBXML_PATH'; echo restored from \$B; md5sum '$CLASS_PATH'"
    say "等 /tk 重载（最多 120s）"
    N_AFTER="$N_BEFORE"; waited=0
    while [ "$waited" -lt 120 ]; do
      sleep 3; waited=$((waited + 3))
      N_AFTER="$(reload_count)"; N_AFTER="${N_AFTER:-0}"
      [ "$N_AFTER" -gt "$N_BEFORE" ] && { say "   ✅ 已重载（约 ${waited}s 后触发）"; break; }
    done
    [ "$N_AFTER" -gt "$N_BEFORE" ] || die "120s 内未观察到 /tk 重载，请查 $CATALINA_OUT"
    if BODY="$(wait_healthy 90)"; then
      say "✅ 回滚后接口正常"; echo "$BODY"
    else
      die "回滚后接口仍未恢复，请立刻查 $CATALINA_OUT"
    fi
    ;;

  *) echo "用法: $0 {check|deploy --confirm|verify|rollback --confirm}"; exit 2 ;;
esac
