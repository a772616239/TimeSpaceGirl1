#!/bin/bash
#
# GetServerListController 补丁的「真实数据 dry-run」——不启动 Tomcat、不写任何数据。
#
#   ./run-dry-run.sh local   # 本地隔离库：自建 gsl_dryrun，覆盖新字段的四种形态
#   ./run-dry-run.sh prod    # 云服对生产库只读：证明对存量记录零回归
#
# 两种模式都跑「原版 class」与「补丁版 class」各一次，再用 compare.py 做语义比对。
# 判定标准：补丁版相对原版只允许在 serverList 的条目上多出 name_en / name_jp / name_kr。
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_ROOT="${HERE%/dry-run}"
LOGIN_ROOT="${SRC_ROOT%/src}"
TK="$LOGIN_ROOT/apache-tomcat-8.5.95/webapps/tk/WEB-INF"
ORIG_CLASSES="$TK/classes"
LIBS="$TK/lib/*"

JAVA_HOME_8="${JAVA_HOME_8:-/usr/local/Cellar/openjdk@8/1.8.0-482/libexec/openjdk.jdk/Contents/Home}"
JAVAC="$JAVA_HOME_8/bin/javac"
JAVA="$JAVA_HOME_8/bin/java"
PYTHON="${PYTHON:-/usr/local/bin/python3}"
MONGO="${MONGO:-/usr/local/opt/mongodb-community@4.4/bin/mongo}"

GS_SSH="${GS_SSH:-gs}"
REMOTE_DIR="${REMOTE_DIR:-/tmp/gsl-dr}"
WORK="${WORK:-/tmp/gsl-dryrun}"
SSH_OPTS=(-o ConnectTimeout=15 -o BatchMode=yes)

MODE="${1:-}"

die() { echo "❌ $*" >&2; exit 1; }

# ---------- 公共：编译 harness + 取补丁 class ----------
prepare() {
  mkdir -p "$WORK/harness"
  "$JAVAC" -encoding UTF-8 -nowarn -cp "$ORIG_CLASSES:$LIBS" -d "$WORK/harness" \
    "$HERE/GslProbe.java" 2>&1 | grep -v '^注:' || true
  [ -f "$WORK/harness/GslProbe.class" ] || die "harness 编译失败"

  mkdir -p "$WORK/patch/com/ljsd/controller"
  if [ -f "$SRC_ROOT/dist/GetServerListController.class" ]; then
    cp "$SRC_ROOT/dist/GetServerListController.class" "$WORK/patch/com/ljsd/controller/"
  else
    die "缺少补丁 class，请先跑 ../build-and-verify.sh --emit-class"
  fi
  echo "✅ harness 与补丁 class 就绪"
}

run_pair() { # $1=描述 $2=properties 文件 $3=输出前缀，其后为 GslProbe 的 5 个业务参数
  local label="$1" props="$2" out="$3"
  shift 3
  "$JAVA" -Dfile.encoding=UTF-8 -Xmx256m \
      -cp "$WORK/harness:$ORIG_CLASSES:$LIBS" GslProbe "$props" "$@" "$out.orig.json" \
      > "$out.orig.log" 2> "$out.orig.err"
  "$JAVA" -Dfile.encoding=UTF-8 -Xmx256m \
      -cp "$WORK/harness:$WORK/patch:$ORIG_CLASSES:$LIBS" GslProbe "$props" "$@" "$out.patch.json" \
      > "$out.patch.log" 2> "$out.patch.err"

  local lo lp
  lo="$(grep 'GetServerListController <=' "$out.orig.err" | head -1 || true)"
  lp="$(grep 'GetServerListController <=' "$out.patch.err" | head -1 || true)"
  echo "  [$label] 原版:   ${lo:-<未打印>}"
  echo "  [$label] 补丁版: ${lp:-<未打印>}"
  [ -n "$lo" ] || die "原版没打印出加载位置，harness 可能没跑到"
  [ -n "$lp" ] || die "补丁版没打印出加载位置，harness 可能没跑到"
  if [ "$lo" = "$lp" ]; then
    die "两次运行加载的是同一个 class，classpath 顺序有问题"
  fi
  if grep -qE 'Exception|NullPointer' "$out.orig.err"; then
    echo "  ⚠️ 原版运行有异常输出（前 5 行）："
    head -5 "$out.orig.err"
  fi
  [ -s "$out.orig.json" ] || die "原版没有产出响应体"
  [ -s "$out.patch.json" ] || die "补丁版没有产出响应体"
}

# ---------- 模式一：本地隔离库 ----------
mode_local() {
  prepare
  [ -x "$MONGO" ] || die "找不到 mongo 客户端：${MONGO}（可用 MONGO= 指定）"

  echo "=== 1) 建本地隔离库 gsl_dryrun.server_info（只动这个新库） ==="
  "$MONGO" --quiet "127.0.0.1:27017/gsl_dryrun" --eval '
    db.server_info.drop();
    db.server_info.insertMany([
      // ① 老记录：只有中文名，一个分语言字段都没有 —— 必须与改动前逐字节一致
      {"_id":1,"channel":"pc","sub_channel":"1","plat":"android","server_id":"1",
       "name":"霓虹序曲","state":"2","open_time":"1700000000000","server_version":"1.26001",
       "ip":"1.1.1.1","port":"16081"},
      // ② 齐备：中/英/日都有
      {"_id":2,"channel":"pc","sub_channel":"1","plat":"android","server_id":"2",
       "name":"庇护所九号","name_en":"Shelter No. 9","name_jp":"シェルター9号",
       "state":"2","open_time":"1700000000000","server_version":"1.26001","is_new":"1",
       "ip":"2.2.2.2","port":"16081"},
      // ③ 空串守卫：name_en 是空串、name_jp 缺失 —— 两个都不该下发
      {"_id":3,"channel":"pc","sub_channel":"1","plat":"android","server_id":"3",
       "name":"空字串测试服","name_en":"","state":"2","open_time":"1700000000000",
       "server_version":"1.26001","ip":"3.3.3.3","port":"16081"},
      // ④ 只有韩文 —— 应只下发 name_kr
      {"_id":4,"channel":"pc","sub_channel":"1","plat":"android","server_id":"4",
       "name":"韩文测试服","name_kr":"한국어 테스트","state":"2","open_time":"1700000000000",
       "server_version":"1.26001","ip":"4.4.4.4","port":"16081"},
      // ⑤ server_version="0" 兜底记录：真实语义是「仅当没有任何同版本区服时才可见」，
      //    所以本用例里它应当**被排除**（已存在 1.26001 的服），用于验证该门控没被改动
      {"_id":5,"channel":"pc","sub_channel":"1","plat":"android","server_id":"5",
       "name":"版本兜底服","name_en":"Version Fallback","state":"2","open_time":"1700000000000",
       "server_version":"0","is_banreg":"0","ip":"5.5.5.5","port":"16081"},
      // ⑥ state=0 隐藏 —— 必须仍然不下发（回归守卫）
      {"_id":6,"channel":"pc","sub_channel":"1","plat":"android","server_id":"6",
       "name":"已隐藏服","name_en":"Hidden","state":"0","open_time":"1700000000000",
       "server_version":"1.26001","ip":"6.6.6.6","port":"16081"}
    ]);
    print("gsl_dryrun.server_info 文档数 = " + db.server_info.count());
  ' | tail -1
  cat > "$WORK/local.properties" <<'EOF'
mongodb_url = mongodb://127.0.0.1:27017/?&authSource=admin
mongodb_name = gsl_dryrun
mongodb_maximumNumberOfConnections = 10
mongodb_connectTimeout = 10000
mongodb_maxWaitTime = 5000
mongodb_threadsAllowedToBlockForConnectionMultiplier = 5
mongodb_maxConnectionIdleTime = 0
mongodb_maxConnectionLifeTime = 0
mongodb_socketTimeout = 0
mongodb_socketKeepAlive = true
redis_host = 127.0.0.1
redis_port = 6479
redis_password =
redis_maxTotal = 4
redis_minIdle = 1
redis_maxWaitMillis = 20
redis_maxIdle = 2
redis_testOnBorrow = false
isTestLan = 1
openAdultCheck = false
EOF

  echo
  echo "=== 2) 分别跑原版 / 补丁版 ==="
  run_pair "本地隔离库" "$WORK/local.properties" "$WORK/local" \
    "probe-openid" "pc" "1" "android" "1.26001"

  echo
  echo "=== 3) 语义比对 ==="
  set +e
  "$PYTHON" "$HERE/compare.py" "$WORK/local.orig.json" "$WORK/local.patch.json" "原版" "补丁版"
  local rc=$?
  set -e

  echo
  echo "--- 补丁版响应（格式化）---"
  "$PYTHON" -c "import json,sys;print(json.dumps(json.load(open(sys.argv[1],encoding='utf-8')),ensure_ascii=False,indent=1))" \
    "$WORK/local.patch.json"
  return $rc
}

# ---------- 模式二：云服对生产库只读 ----------
mode_prod() {
  prepare
  echo "=== 1) 上传 harness / 补丁 class 到 ${GS_SSH}:${REMOTE_DIR}（不改动线上部署目录） ==="
  ssh "${SSH_OPTS[@]}" "$GS_SSH" "rm -rf '$REMOTE_DIR'; mkdir -p '$REMOTE_DIR/harness' '$REMOTE_DIR/patch/com/ljsd/controller' '$REMOTE_DIR/out'"
  scp "${SSH_OPTS[@]}" -q "$WORK"/harness/GslProbe*.class "$GS_SSH:$REMOTE_DIR/harness/"
  scp "${SSH_OPTS[@]}" -q "$WORK/patch/com/ljsd/controller/GetServerListController.class" \
      "$GS_SSH:$REMOTE_DIR/patch/com/ljsd/controller/"

  local TC="/home/java/loginserver/apache-tomcat-8.5.95"
  local PROPS="$TC/config/x1/application.properties"
  local CP_BASE="$REMOTE_DIR/harness:$TC/webapps/tk/WEB-INF/classes:$TC/webapps/tk/WEB-INF/lib/*"
  local OPENID="probe-openid"

  echo "=== 2) 只读跑原版 / 补丁版（对生产 Mongo 只 find，对生产 Redis 只 get/hgetAll） ==="
  ssh "${SSH_OPTS[@]}" "$GS_SSH" bash -s <<EOF
set -e
cd '$REMOTE_DIR/out'
java -Dfile.encoding=UTF-8 -Xmx128m -cp "$CP_BASE" GslProbe "$PROPS" "$OPENID" pc 1 android 1.26001 orig.json > orig.log 2> orig.err
java -Dfile.encoding=UTF-8 -Xmx128m -cp "$REMOTE_DIR/patch:$CP_BASE" GslProbe "$PROPS" "$OPENID" pc 1 android 1.26001 patch.json > patch.log 2> patch.err
echo "--- 加载到的 class ---"
grep 'GetServerListController <=' orig.err | head -1
grep 'GetServerListController <=' patch.err | head -1
echo "--- 异常计数（原版 / 补丁版）---"
echo "orig=\$(grep -cE 'Exception|NullPointer' orig.err || true) patch=\$(grep -cE 'Exception|NullPointer' patch.err || true)"
ls -la orig.json patch.json
EOF

  scp "${SSH_OPTS[@]}" -q "$GS_SSH:$REMOTE_DIR/out/orig.json" "$WORK/prod.orig.json"
  scp "${SSH_OPTS[@]}" -q "$GS_SSH:$REMOTE_DIR/out/patch.json" "$WORK/prod.patch.json"

  echo
  echo "=== 3) 语义比对（应完全一致：生产库里还没有 name_en/name_jp 数据）==="
  set +e
  "$PYTHON" "$HERE/compare.py" "$WORK/prod.orig.json" "$WORK/prod.patch.json" "原版" "补丁版"
  local rc=$?
  set -e

  echo
  echo "--- 生产响应体（补丁版，前 1500 字符）---"
  head -c 1500 "$WORK/prod.patch.json"; echo
  return $rc
}

case "$MODE" in
  local) mode_local ;;
  prod)  mode_prod ;;
  *) echo "用法: $0 {local|prod}"; exit 2 ;;
esac
