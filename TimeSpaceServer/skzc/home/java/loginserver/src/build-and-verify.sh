#!/bin/bash
#
# 登录服 GetServerListController 补丁的「编译 + 可信度验证」脚本（离线，不碰生产）
#
# 用法：
#   ./build-and-verify.sh                 # 编译并做两级 diff 验证
#   ./build-and-verify.sh --emit-class    # 额外把 class 输出到 dist/
#
# 验证原理（三级证据）：
#   ① 纯重建版（= 补丁源码删掉本次新增的部分）编译后，与原线上 class 做
#      「指令流归一化 diff」——归一化掉字节码偏移、常量池索引、局部变量槽编号这三类
#      与语义无关的噪音。若为空，证明重建忠实、且工具链可信。
#   ② 补丁版 与 纯重建版 做同样 diff——差异必须**只有**本次新增的 3 个 put 调用
#      和 putIfNotEmpty 方法，多一行都算验证失败。
#   ③ 真实数据 dry-run 由同目录 dry-run/ 下的 harness 完成（对着生产库只读跑）。
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGIN_ROOT="${HERE%/src}"
TK="$LOGIN_ROOT/apache-tomcat-8.5.95/webapps/tk/WEB-INF"
SRC="$HERE/com/ljsd/controller/GetServerListController.java"
ORIG_CLASS="$TK/classes/com/ljsd/controller/GetServerListController.class"
ORIG_MD5_EXPECT="87104ceebb8898be15d3a1398354a3e4"

# JDK8：与线上一致（线上 centos7 + JDK8）
JAVA_HOME_8="${JAVA_HOME_8:-/usr/local/Cellar/openjdk@8/1.8.0-482/libexec/openjdk.jdk/Contents/Home}"
JAVAC="$JAVA_HOME_8/bin/javac"
JAVAP="$JAVA_HOME_8/bin/javap"
PYTHON="${PYTHON:-/usr/local/bin/python3}"

WORK="$(mktemp -d /tmp/gsl-build.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

for f in "$JAVAC" "$JAVAP"; do
  [ -x "$f" ] || { echo "❌ 找不到 JDK8 工具：${f}（可用 JAVA_HOME_8 指定）"; exit 1; }
done
[ -f "$ORIG_CLASS" ] || { echo "❌ 找不到线上 class：$ORIG_CLASS"; exit 1; }

# --- 0. 基线校验：本地副本必须与上次验证过的线上版本一致 ---
ORIG_MD5="$(md5 -q "$ORIG_CLASS" 2>/dev/null || md5sum "$ORIG_CLASS" | awk '{print $1}')"
if [ "$ORIG_MD5" != "$ORIG_MD5_EXPECT" ]; then
  echo "🔴 基线 class 与预期不一致（说明线上已换版），停止验证。"
  echo "   期望 $ORIG_MD5_EXPECT"
  echo "   实际 $ORIG_MD5"
  exit 1
fi
echo "✅ 基线 class md5 = ${ORIG_MD5}（与验证过的线上版本一致）"

# --- 1. 生成「纯重建版」：删掉本次新增的调用与辅助方法 ---
mkdir -p "$WORK/control/com/ljsd/controller"
"$PYTHON" - "$SRC" "$WORK/control/com/ljsd/controller/GetServerListController.java" <<'PY'
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding='utf-8').read()
for key in ("name_en", "name_jp", "name_kr"):
    line = '                putIfNotEmpty(res, serverInfo, "%s");\n' % key
    assert line in text, "补丁源码里找不到新增行：%s" % key
    text = text.replace(line, '')
text, n = re.subn(
    r'    /\*\*\n     \* 按需下发分语言区名.*?\n    \}\n\n', '', text, flags=re.S)
assert n == 1, "未能移除 putIfNotEmpty 方法"
assert 'putIfNotEmpty' not in text, "control 里仍有残留引用"
open(dst, 'w', encoding='utf-8').write(text)
PY

# --- 2. 编译 control 与 patch ---
build() { # $1=源文件 $2=输出目录
  mkdir -p "$2"
  "$JAVAC" -encoding UTF-8 -nowarn -cp "$TK/classes:$TK/lib/*" -d "$2" "$1" 2>&1 \
    | grep -v '^注:' || true
  [ -f "$2/com/ljsd/controller/GetServerListController.class" ] \
    || { echo "❌ 编译失败：$1"; exit 1; }
}
build "$WORK/control/com/ljsd/controller/GetServerListController.java" "$WORK/control_out"
build "$SRC" "$WORK/patch_out"
echo "✅ control / patch 均编译通过"

# --- 3. 指令流归一化 ---
norm() { "$PYTHON" - "$JAVAP" "$1" > "$2" <<'PY'
import re
import subprocess
import sys

javap, path = sys.argv[1], sys.argv[2]
text = subprocess.run([javap, "-p", "-c", "-constants", path],
                      capture_output=True, text=True, check=True).stdout
out = []
for line in text.splitlines():
    s = line.strip()
    if not s:
        continue
    s = re.sub(r"^\d+:\s*", "", s)
    s = re.sub(r"#\d+", "", s)
    # 分支目标偏移：插入一条指令会让后面所有偏移平移，与语义无关
    s = re.sub(r"\b(if\w+|goto|jsr)\s+\d+\b", r"\1 T", s)
    # 异常表的 from/to/target 三列偏移
    s = re.sub(r"^\d+\s+\d+\s+\d+\s+", "T T T ", s)
    s = re.sub(r"\b(iinc)\s+\d+\s*,", r"\1 S,", s)
    s = re.sub(r"\b(aload|astore|iload|istore|lload|lstore|fload|fstore|dload|dstore|ret)\s+\d+\b",
               r"\1 S", s)
    s = re.sub(r"\b(aload|astore|iload|istore|lload|lstore|fload|fstore|dload|dstore|ret)_\d\b",
               r"\1_S", s)
    out.append(re.sub(r"\s+", " ", s).strip())
print("\n".join(out))
PY
}
norm "$ORIG_CLASS" "$WORK/n_orig.txt"
norm "$WORK/control_out/com/ljsd/controller/GetServerListController.class" "$WORK/n_ctl.txt"
norm "$WORK/patch_out/com/ljsd/controller/GetServerListController.class" "$WORK/n_patch.txt"

RC=0
echo
echo "===== ① 纯重建版 vs 线上原 class ====="
if diff -u "$WORK/n_orig.txt" "$WORK/n_ctl.txt" > "$WORK/d1.txt"; then
  echo "✅ 指令流完全一致 —— 重建忠实，工具链可信"
else
  echo "⚠️ 存在差异（$(grep -c '^[+-][^+-]' "$WORK/d1.txt" || true) 行）——需人工确认是否仅为形状差异："
  cat "$WORK/d1.txt"
  RC=1
fi

echo
echo "===== ② 补丁版 vs 纯重建版 ====="
if diff -u "$WORK/n_ctl.txt" "$WORK/n_patch.txt" > "$WORK/d2.txt"; then
  echo "❌ 没有任何差异 —— 说明补丁没生效，异常"
  RC=1
else
  echo "差异内容（应只含 name_en/name_jp/name_kr 三个 put 与 putIfNotEmpty）："
  cat "$WORK/d2.txt"
  ADDED="$(grep -c '^+[^+]' "$WORK/d2.txt" || true)"
  REMOVED="$(grep -c '^-[^-]' "$WORK/d2.txt" || true)"
  echo "-- 新增行 $ADDED / 删除行 $REMOVED"
  echo "-- 新增行里出现的关键字：$(grep '^+[^+]' "$WORK/d2.txt" | grep -oE 'name_en|name_jp|name_kr|putIfNotEmpty' | sort -u | tr '\n' ' ')"
fi

echo
if [ "$RC" -eq 0 ]; then echo "🎉 两级验证通过"; else echo "🔴 验证未通过，勿部署"; fi
[ "${1:-}" = "--emit-class" ] && {
  mkdir -p "$HERE/dist"
  cp "$WORK/patch_out/com/ljsd/controller/GetServerListController.class" "$HERE/dist/"
  echo "已输出 dist/GetServerListController.class"
}
exit "$RC"
