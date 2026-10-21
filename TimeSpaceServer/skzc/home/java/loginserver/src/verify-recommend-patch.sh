#!/bin/bash
#
# 「recommend 只认新服」补丁的编译 + 可信度验证（离线，不碰生产）
#
# 背景：线上 tk/getServerList 会在 `state==2 且 ONLINE_NUM>0`（Redis 在线人数）时，把
#       「在线人数最多的服」塞进 recommend。客户端 LoginPanel.SetServerList 只要看到
#       recommend 且账号没有 lastServer（新号 / 有角色记录但 loginTime 缺失），就会走进
#       `for i = 1, #myServerList do if this.serverList[i].level > ...` 这个用错维度的分支
#       （serverList 是区服维度，没有 level 字段）→ nil > 0 抛异常 →
#       SetServerList 在给 SocketAddress 赋值前中断 → 登录必报
#       “RequestSocketLogin failed: SocketAddress is nil or empty”。
#       测试服没人上线 ⇒ 永不下发 recommend ⇒ 永远不复现，所以线下看包像“服务端没问题”。
#       本补丁把 recommend 收窄为「只按 is_new=1 的新服下发」，去掉在线人数兜底。
#
# 用法：
#   ./verify-recommend-patch.sh                # 只验证
#   ./verify-recommend-patch.sh --emit-class   # 验证并把 class 输出到 dist/
#
# 验证方法（对照组 = 用同一套 javac/同参数重编「HEAD 那版源码」，不是拿别处的旧 class 比，
#          以免混入「谁编译的 / 带不带调试信息」这类噪音）：
#   ① 对照组源码必须来自 git HEAD 的同一路径，且包含 putIfNotEmpty 与推荐兜底（确认对的是 i18n 版）
#   ② 归一化指令流 diff：删除行只允许涉及 maxNum / maxNumServerId / recommend，
#      新增行只允许涉及 recommend / newServerList
#   ③ 补丁 class 里不得再存在 maxNumServerId 的任何引用
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../../../../../.." && pwd)"
REL_SRC="TimeSpaceServer/skzc/home/java/loginserver/src/com/ljsd/controller/GetServerListController.java"
LOGIN_ROOT="${HERE%/src}"
TK="$LOGIN_ROOT/apache-tomcat-8.5.95/webapps/tk/WEB-INF"
SRC="$HERE/com/ljsd/controller/GetServerListController.java"

JAVA_HOME_8="${JAVA_HOME_8:-/usr/local/Cellar/openjdk@8/1.8.0-482/libexec/openjdk.jdk/Contents/Home}"
JAVAC="$JAVA_HOME_8/bin/javac"
JAVAP="$JAVA_HOME_8/bin/javap"
PYTHON="${PYTHON:-/usr/local/bin/python3}"

WORK="$(mktemp -d /tmp/gsl-rcm.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

say() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { echo "❌ $*" >&2; exit 1; }

for f in "$JAVAC" "$JAVAP"; do
  [ -x "$f" ] || die "找不到 JDK8 工具：${f}（可用 JAVA_HOME_8 指定）"
done
[ -f "$SRC" ] || die "找不到补丁源码：$SRC"

# --- ① 取对照组源码 = git HEAD 版本 ---
mkdir -p "$WORK/ctl/com/ljsd/controller"
git -C "$REPO" show "HEAD:$REL_SRC" > "$WORK/ctl/com/ljsd/controller/GetServerListController.java" \
  || die "取不到 HEAD 版源码（$REL_SRC）"
CTL_SRC="$WORK/ctl/com/ljsd/controller/GetServerListController.java"
grep -q 'putIfNotEmpty' "$CTL_SRC" || die "对照组源码里没有 putIfNotEmpty —— HEAD 不是 i18n 版，核对分支"
grep -q 'maxNumServerId' "$CTL_SRC" || die "对照组源码里没有 maxNumServerId 兜底 —— 对照版本不对"
say "✅ 对照组 = HEAD（$(git -C "$REPO" rev-parse --short HEAD)）i18n 版源码"
grep -q 'maxNumServerId' "$SRC" && die "补丁源码里还有 maxNumServerId —— 补丁没改干净"
say "✅ 补丁源码已无 maxNumServerId"

# --- ② 编译对照 / 补丁 ---
build() { # $1=源码 $2=输出目录
  mkdir -p "$2"
  "$JAVAC" -encoding UTF-8 -nowarn -cp "$TK/classes:$TK/lib/*" -d "$2" "$1" 2>&1 \
    | grep -vE '^(注|Note):' || true
  [ -f "$2/com/ljsd/controller/GetServerListController.class" ] || die "编译失败：$1"
}
build "$CTL_SRC" "$WORK/ctl_out"
build "$SRC"     "$WORK/patch_out"
CTL_CLASS="$WORK/ctl_out/com/ljsd/controller/GetServerListController.class"
NEW_CLASS="$WORK/patch_out/com/ljsd/controller/GetServerListController.class"
say "✅ 均编译通过；补丁 class md5 = $(md5 -q "$NEW_CLASS" 2>/dev/null || md5sum "$NEW_CLASS" | awk '{print $1}')"

# --- 归一化指令流 ---
norm() { "$PYTHON" - "$JAVAP" "$1" > "$2" <<'PY'
import re, subprocess, sys
javap, path = sys.argv[1], sys.argv[2]
text = subprocess.run([javap, "-p", "-c", "-constants", path],
                      capture_output=True, text=True, check=True).stdout
out = []
for line in text.splitlines():
    s = line.strip()
    if not s:
        continue
    s = re.sub(r"^\d+:\s*", "", s)                          # 字节码偏移
    s = re.sub(r"#\d+", "", s)                              # 常量池索引
    s = re.sub(r"\b(if\w+|goto|jsr)\s+\d+\b", r"\1 T", s)   # 分支目标偏移
    s = re.sub(r"^\d+\s+\d+\s+\d+\s+", "T T T ", s)         # 异常表偏移
    s = re.sub(r"\b(iinc)\s+\d+\s*,", r"\1 S,", s)
    s = re.sub(r"\b(aload|astore|iload|istore|lload|lstore|fload|fstore|dload|dstore|ret)\s+\d+\b",
               r"\1 S", s)
    s = re.sub(r"\b(aload|astore|iload|istore|lload|lstore|fload|fstore|dload|dstore|ret)_\d\b",
               r"\1_S", s)
    out.append(re.sub(r"\s+", " ", s).strip())
print("\n".join(out))
PY
}

norm "$CTL_CLASS" "$WORK/n_ctl.txt"
norm "$NEW_CLASS" "$WORK/n_new.txt"

say "② 归一化指令流 diff（对照 → 补丁）"
if diff -u "$WORK/n_ctl.txt" "$WORK/n_new.txt" > "$WORK/d.txt"; then
  die "没有任何差异 —— 补丁没生效"
fi
cat "$WORK/d.txt"

say "③ 断言：diff 只删不增、且删除点恰好 3 处"
"$PYTHON" - "$WORK/d.txt" <<'PY'
import sys
removed = added = hunks = 0
for line in open(sys.argv[1], encoding='utf-8'):
    line = line.rstrip('\n')
    if line.startswith('@@'):
        hunks += 1
    elif line[:3] in ('---', '+++'):
        continue
    elif line.startswith('-'):
        removed += 1
    elif line.startswith('+'):
        added += 1
print("  hunk=%d 删除行=%d 新增行=%d" % (hunks, removed, added))
bad = []
if added:
    bad.append("出现新增指令（本补丁应当是纯删除 + 分支收窄）：%d 行" % added)
if hunks != 3:
    bad.append("删除点应为 3 处（maxNum 变量声明 / 在线人数比较块 / recommend 兜底分支），实际 %d 处" % hunks)
if bad:
    print("🔴 " + "；".join(bad))
    sys.exit(1)
print("✅ 纯删除型改动，命中预期 3 处（变量声明 / 在线人数比较 / recommend 兜底）")
PY

say "④ 断言：类的外部形状（字段 / 方法签名）完全没变，只改了方法体"
"$JAVAP" -p "$CTL_CLASS" | sed 's/[[:space:]]*$//' > "$WORK/m_ctl.txt"
"$JAVAP" -p "$NEW_CLASS" | sed 's/[[:space:]]*$//' > "$WORK/m_new.txt"
if diff -u "$WORK/m_ctl.txt" "$WORK/m_new.txt" > "$WORK/mdiff.txt"; then
  say "   ✅ 成员列表逐行一致（$(grep -c '' "$WORK/m_new.txt") 行）"
else
  cat "$WORK/mdiff.txt"
  die "类成员列表发生变化 —— 补丁不应增删字段/方法"
fi

if [ "${1:-}" = "--emit-class" ]; then
  mkdir -p "$HERE/dist"
  cp "$NEW_CLASS" "$HERE/dist/"
  say "已输出 dist/GetServerListController.class（md5 $(md5 -q "$HERE/dist/GetServerListController.class" 2>/dev/null || md5sum "$HERE/dist/GetServerListController.class" | awk '{print $1}')）"
fi

echo
say "🎉 recommend 收窄补丁验证通过"
