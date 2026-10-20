#!/bin/bash
#
# 包内资源构建执行器：导表 / 重建 AssetBundle（供 Jenkins TS-Resource-Build 调用，也可手工跑）
#
# 为什么单独成脚本：导表与 AB 重建长期是「人肉 GUI 点按钮」的环节，Jenkins 只能体检不能执行。
# 这个脚本把「注入出包环境 → Unity batchmode → 还原」收成一条命令，job 里只负责取证与可视化。
#
# 用法：
#   scripts/resource_build.sh --action export                  # 全量导表（= 面板 Export All）
#   scripts/resource_build.sh --action ab --server-env 正式服   # 重建 AB + 复制到 StreamingAssets
#   scripts/resource_build.sh --action all  --server-env 正式服  # 先导表再重建 AB（两次 Unity 启动）
#
# 🔴 为什么 AB 要带 --server-env：CopyAssetBundleToStreamingAssets 会把 Assets/Resources/
#    整目录快照到 StreamingAssets/Android/Resources（含 version.txt）。快照里的 serverUrl
#    才是真正打进包里的值 —— 不在这里注入，包就会连到「上次谁改的那条地址」。
#
# 退出码：0 成功 / 2 参数或环境错误 / 3 Unity 执行失败
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

UNITY_BIN="/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity"
VENV_PY="/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python"
STAMP="$(date '+%Y%m%d-%H%M%S')"

ACTION="all"
SERVER_ENV=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --action)     ACTION="${2:-}"; shift 2 ;;
        --server-env) SERVER_ENV="${2:-}"; shift 2 ;;
        -h|--help)    /usr/bin/sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "未知参数：$1" >&2; exit 2 ;;
    esac
done

case "$ACTION" in
    export|ab|all) ;;
    *) echo "✗ --action 只能是 export / ab / all（收到：${ACTION}）" >&2; exit 2 ;;
esac

[[ -x "$UNITY_BIN" ]] || { echo "✗ 找不到 Unity：$UNITY_BIN" >&2; exit 2; }

# 🔴 2026-10-20 修：旧判定有两处错，等于**从来没拦过**。
#   ① pgrep -f "Unity.*-projectPath $ROOT" 区分大小写，而 Unity Hub 拉起 GUI 时命令行是
#      小写 `-projectpath`（本机实测 PID 72958）⇒ 永远不命中；
#   ② 前置条件 `[[ ! -f Library/SourceAssetDB-lock ]]` 恰好在该文件**存在**时把检查整个跳过，
#      而那个 lock 正是「编辑器持有本工程」的产物 ⇒ 条件写反了。
# 后果：GUI 开着照样往下跑，两个实例争同一个 Library，最坏写坏库。
# 现在：只要命令行里带 -projectpath <本工程> 的 Unity 进程在（GUI 或别人的 batchmode），一律拒绝。
# ⚠️ 必须限定到**本工程**：本机常年有其它项目的 Unity 在跑，无条件 pgrep 会误伤。
UNITY_LIST=$(pgrep -fl "Unity.app/Contents/MacOS/Unity" 2>/dev/null || true)
UNITY_BUSY=$(printf '%s\n' "$UNITY_LIST" | grep -iF -- "-projectpath $ROOT" || true)
if [[ -n "$UNITY_BUSY" ]]; then
    echo "✗ 本工程的 Unity 进程正在运行，batchmode 会争抢 Library：${UNITY_BUSY%%$'\n'*}" >&2
    printf '%s\n' "$UNITY_BUSY" >&2
    echo "  请先关闭 GUI Unity：osascript -e 'tell application \"Unity\" to quit'" >&2
    exit 2
fi

restore_env() {
    if [[ -n "$SERVER_ENV" ]]; then
        "$VENV_PY" scripts/apply_build_env.py restore >/dev/null 2>&1 || true
    fi
}
trap restore_env EXIT INT TERM

if [[ -n "$SERVER_ENV" ]]; then
    "$VENV_PY" scripts/apply_build_env.py apply "$SERVER_ENV" \
        || { echo "✗ 注入出包环境失败：$SERVER_ENV" >&2; exit 2; }
fi

run_unity() { # $1 = executeMethod 后缀, $2 = 日志名
    local method="$1"
    local tag="$2"
    # ⚠️ 别写成一行 `local method="$1" tag="$2" log="...${tag}..."`：
    # 同一句里的展开发生在赋值之前，set -u 下 ${tag} 会 unbound（2026-10-20 首次跑踩到）。
    local log="build_log_resource_${tag}_${STAMP}.txt"
    echo "==> Unity batchmode：${method}（日志 ${log}）"
    rm -f "$ROOT/Library/SourceAssetDB-lock" 2>/dev/null || true
    "$UNITY_BIN" -batchmode -quit \
        -projectPath "$ROOT" \
        -executeMethod "GameEditor.Core.DataConfig.BatchResourceBuild.${method}" \
        -logFile "$ROOT/${log}"
    local rc=$?
    echo "   Unity 退出码：${rc}"
    if [[ "$rc" -ne 0 ]]; then
        echo "✗ ${method} 失败，日志尾部：" >&2
        tail -20 "$ROOT/${log}" >&2 || true
        return 3
    fi
    return 0
}

RC=0
if [[ "$ACTION" == "export" || "$ACTION" == "all" ]]; then
    run_unity ExportTables export || RC=$?
    [[ "$RC" -eq 0 ]] && echo "✅ 导表完成（明细 Logs/batch_resource_build.log）"
fi

if [[ "$RC" -eq 0 && ( "$ACTION" == "ab" || "$ACTION" == "all" ) ]]; then
    run_unity BuildAllABs ab || RC=$?
    if [[ "$RC" -eq 0 ]]; then
        echo "✅ AB 重建完成"
        BUNDLE="$ROOT/Assets/StreamingAssets/Android/lzma|luabytes.unity3d"
        if [[ -f "$BUNDLE" ]]; then
            echo "   luabytes bundle：$(ls -lh "$BUNDLE" | awk '{print $5}')  $(date -r "$BUNDLE" '+%Y-%m-%d %H:%M')"
        else
            echo "✗ 重建后仍找不到 lzma|luabytes.unity3d" >&2
            RC=3
        fi
        SNAP="$ROOT/Assets/StreamingAssets/Android/Resources/version.txt"
        if [[ -f "$SNAP" ]]; then
            echo "   包内环境快照：$(/usr/bin/grep -o '"serverUrl":"[^"]*"' "$SNAP" || echo '（读不到 serverUrl）')"
        fi
    fi
fi

exit "$RC"
