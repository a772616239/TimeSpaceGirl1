#!/bin/sh
# MAT headless 分析 heap dump（本机 macOS / JDK21）
# 用法: sh scripts/analyze_heapdump.sh <hprof> [报告id...]
# 前置: /tmp/mat 已解压 MemoryAnalyzer 1.16.1
set -e
HPROF="$1"; shift || true
JAVA_HOME=${MAT_JAVA:-/usr/local/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home}
J="$JAVA_HOME/bin/java"
E="/tmp/mat/MemoryAnalyzer.app/Contents/Eclipse"
LAUNCHER=$(ls "$E"/plugins/org.eclipse.equinox.launcher_*.jar | head -1)

REPORTS=${*:-org.eclipse.mat.api:suspects org.eclipse.mat.api:overview org.eclipse.mat.api:top_components}

exec "$J" -Xmx14g -Djava.awt.headless=true \
  --add-exports=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED \
  -cp "$LAUNCHER" org.eclipse.equinox.launcher.Main \
  -application org.eclipse.mat.api.parse \
  -data /tmp/mat/ws -configuration "$E/configuration" \
  "$HPROF" $REPORTS
