#!/usr/local/bin/bash
# =============================================================================
# resolve_gen.sh —— 把「本次要处理的那张生成图」定位出来
#
# 为什么单独一个脚本：provider=manual 时，图要么由参数显式给，要么由人/Agent
# 丢进 inbox。这个「找图」的规则一进 Jenkinsfile 就会写成三行内联 shell，
# 到处复制。收口在这里，本地也能一条命令复现 job 的行为。
#
# 用法：
#   resolve_gen.sh --work DIR --run DIR [--gen /path/to/img.png]
#
# 规则（按优先级）：
#   1) --gen 给的路径存在 → 用它
#   2) <work>/inbox 下按 mtime 最新的 png/jpg/webp
#   3) 都没有 → rc=3（黄，不是红：说明「图还没准备好」，属于流程正常中间态）
#
# 成功时副作用：
#   $RUN/artifacts/gen.png     本次处理的生成图副本（归档用，避免 inbox 被后续覆盖）
#   $RUN/generated.path        源路径，便于回溯
#   $RUN/gen.ready             标记文件，Pipeline 用它 gate 后续 stage
# =============================================================================
set -uo pipefail

WORK=""; RUN=""; GEN=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --work) WORK="$2"; shift 2 ;;
    --run)  RUN="$2";  shift 2 ;;
    --gen)  GEN="$2";  shift 2 ;;
    *) echo "resolve_gen: 未知参数 $1" >&2; exit 2 ;;
  esac
done

[[ -n "$WORK" && -n "$RUN" ]] || { echo "resolve_gen: 需要 --work 与 --run" >&2; exit 2; }
mkdir -p "$RUN/artifacts"

SRC=""
if [[ -n "$GEN" ]]; then
  if [[ -f "$GEN" ]]; then
    SRC="$GEN"
  else
    echo "指定的生成图不存在：$GEN" >&2
  fi
fi

if [[ -z "$SRC" ]]; then
  # BSD find 没有 -newermt，用 ls -t 取最新（inbox 只放少量图，够用）
  SRC="$(ls -t "$WORK"/inbox/*.png "$WORK"/inbox/*.jpg "$WORK"/inbox/*.jpeg "$WORK"/inbox/*.webp 2>/dev/null | head -1)"
fi

if [[ -z "$SRC" || ! -f "$SRC" ]]; then
  echo ""
  echo "还没有可处理的生成图。两条路："
  echo "  A) provider=manual：拿提示词去任意图像模型出图，把结果丢进"
  echo "     $WORK/inbox/"
  echo "     提示词：scripts/image/restyle_pipeline.py prompt --theme <主题>"
  echo "  B) provider=chatgpt_web：把 PROVIDER 改成 chatgpt_web（需 chatgpt.com 可达）"
  exit 3
fi

cp -f "$SRC" "$RUN/artifacts/gen.png"
printf '%s\n' "$SRC" > "$RUN/generated.path"
touch "$RUN/gen.ready"
echo "使用生成图：$SRC"
# 报告一下尺寸，肉眼就能判断是不是把缩略图/预览图错丢进来了
"${PY:-/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python}" - "$SRC" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1])
print(f"  尺寸 {im.size[0]}x{im.size[1]}  模式 {im.mode}  {im.size[0]*im.size[1]//1000}k px")
PY
exit 0
