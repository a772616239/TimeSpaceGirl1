#!/bin/bash
# 验证 MongoBitSetConverter 的双向转换是否正确。
#
# 这个脚本不连数据库，只构造与线上同构的 MappingMongoConverter
# （spring-data-mongodb 1.10.9 + 空 DbRefResolver），
# 覆盖 5 条真实路径：
#   A 全量存档  write(User)
#   B 增量更新  convertToMongoType(missionType)   ← 领奖后最高频
#   C 读新格式（字符串）
#   D 读旧格式（{words:[...], wordsInUse:N}）      ← 上线时线上的样子
#   E 旧数据读入再存回，应自动收敛成新格式
#
# 用法：sh scripts/verify/run_bitset_converter_check.sh
set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/TimeSpaceServer/Server_x1tag1.2.2/server_game/serverlogic/src/main/java"
LIB="$ROOT/TimeSpaceServer/Server_x1tag1.2.2/server_game/serverlogic/lib"
OUT="$(mktemp -d)"

echo "== 编译 =="
javac -encoding UTF-8 -nowarn -source 8 -target 8 \
  -cp "$LIB/*" -d "$OUT" \
  "$SRC/com/ljsd/jieling/db/mongo/MongoBitSetConverter.java" \
  "$ROOT/scripts/verify/VerifyBitSetBasic.java" \
  "$ROOT/scripts/verify/VerifyBitSetNested.java" 2>&1 | grep -vE "^Note:|bootstrap class path" || true

echo "== 基础往返 =="
java -cp "$OUT:$LIB/*" VerifyBitSetBasic
echo
echo "== 嵌套对象（线上结构） =="
java -cp "$OUT:$LIB/*" VerifyBitSetNested
echo
echo "== 全部通过 =="
rm -rf "$OUT"
