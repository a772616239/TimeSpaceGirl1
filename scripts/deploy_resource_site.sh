#!/usr/bin/env bash
# deploy_resource_site.sh —— 把本地 AB 铺到资源站 :81（客户端热更/多语言文本的 CDN 根）
#
# 为什么需要：`resUrl` = http://129.226.213.65:81/，客户端按
#   {resUrl}{packageVersion}/{PlatformPath}/version.txt
# 去取版本文件（ResourcesUpdateManager.cs:322）。站点根目录在服务器上是
#   /www/wwwroot/res
# 每次换包（packageVersion 变了）都要新建一档目录，**不要覆盖老档**——
# 还在跑老包的玩家仍要从老目录取资源。
#
# 用法：
#   scripts/deploy_resource_site.sh --dry-run          # 只看要传什么（默认就是 dry-run）
#   scripts/deploy_resource_site.sh --apply            # 真传
#   scripts/deploy_resource_site.sh --apply --pkg 1.26002
#   scripts/deploy_resource_site.sh --apply --host gs --root /www/wwwroot/res
#
# 退出码：0 成功；2 用法/前置条件错；3 上传失败；4 上传后自检失败
#
# 详见 docs/resource_site_ops.md
set -uo pipefail

PROJ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$PROJ/Assets/StreamingAssets/Android"
HOST="gs"                      # ~/.ssh/config 里的别名
ROOT="/www/wwwroot/res"
PKG=""                         # 空 = 从包内 version.txt 读 packageVersion
APPLY=0

die() { printf '❌ %s\n' "$1" >&2; exit "${2:-2}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)   APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    --host)    HOST="${2:?--host 需要一个值}"; shift ;;
    --root)    ROOT="${2:?--root 需要一个值}"; shift ;;
    --pkg)     PKG="${2:?--pkg 需要一个值}"; shift ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) die "未知参数：$1" ;;
  esac
  shift
done

[ -d "$SRC" ] || die "找不到 AB 目录：$SRC（先跑 TS-Resource-Build 重建 AB）"
[ -f "$SRC/Resources/version.txt" ] || die "找不到包内 version.txt：$SRC/Resources/version.txt"

if [ -z "$PKG" ]; then
  PKG="$(/usr/bin/python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["packageVersion"])' \
        "$SRC/Resources/version.txt" 2>/dev/null)"
fi
[ -n "$PKG" ] || die "取不到 packageVersion（version.txt 里没有这个字段？）"

DEST="$ROOT/$PKG/Android"
echo "源目录 : $SRC"
echo "目标   : $HOST:$DEST"
echo "版本档 : $PKG"
echo "模式   : $([ "$APPLY" = 1 ] && echo 真传 || echo dry-run)"
echo

RSYNC_ARGS=(-a --partial --no-inc-recursive --exclude='*.meta')
[ "$APPLY" = 1 ] || RSYNC_ARGS+=(--dry-run)

# .meta 是 Unity 编辑器元数据，运行时不读，传上去纯浪费一半的文件数
rsync "${RSYNC_ARGS[@]}" --stats "$SRC/" "$HOST:$DEST/" || die "rsync 失败" 3

if [ "$APPLY" != 1 ]; then
  echo
  echo "ℹ️ 以上是 dry-run，确认无误后加 --apply 真传。"
  exit 0
fi

# CDN 根必须有一份 version.txt —— 客户端第一个请求就是它
scp -q "$SRC/Resources/version.txt" "$HOST:$DEST/version.txt" || die "上传 version.txt 失败" 3

echo
echo "=== 服务器本机自检 ==="
ssh "$HOST" "set -e
  printf 'version.txt : '; curl -s -m 5 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:81/$PKG/Android/version.txt
  printf 'files.unity3d: '; curl -s -m 5 -o /dev/null -w '%{http_code} %{size_download}B\n' http://127.0.0.1:81/$PKG/Android/files.unity3d
  printf '文件数/体积 : '; echo \"\$(find $DEST -type f | wc -l) 个 / \$(du -sh $DEST | cut -f1)\"
" || die "自检失败（看 /www/wwwlogs/res81.error.log）" 4

echo
echo "=== 外网自检 ==="
code="$(curl -s --noproxy '*' -m 8 -o /dev/null -w '%{http_code}' "http://129.226.213.65:81/$PKG/Android/version.txt" || true)"
if [ "$code" = "200" ]; then
  echo "✅ 外网可达：http://129.226.213.65:81/$PKG/Android/version.txt"
else
  echo "⚠️ 外网返回 $code —— 服务器本机通、外网不通，基本就是腾讯云安全组没放行 TCP:81。"
  echo "   判定：ssh $HOST 'curl -m 6 -o /dev/null -w \"%{http_code}\" http://129.226.213.65:8080/' 若是 200，"
  echo "   说明 hairpin 正常、就是按端口拦的。去控制台「安全组 → 入站规则」加 TCP:81 0.0.0.0/0。"
  echo "   详见 docs/resource_site_ops.md 第 4.1 节。"
fi
