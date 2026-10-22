#!/bin/bash
#
# 包内资源构建执行器：导表 / 重建 AssetBundle（供 Jenkins TS-Resource-Build 调用，也可手工跑）
#
# 为什么单独成脚本：导表与 AB 重建长期是「人肉 GUI 点按钮」的环节，Jenkins 只能体检不能执行。
# 这个脚本把「注入出包环境 → Unity batchmode → 还原」收成一条命令，job 里只负责取证与可视化。
#
# 用法：
#   scripts/resource_build.sh --action export                  # 全量导表（= 面板 Export All）
#   scripts/resource_build.sh --action export --sync-tables plan   # 导表 + 只体检服务端表漂移
#   scripts/resource_build.sh --action export --sync-tables off    # 导表但不碰线上服
#   scripts/resource_build.sh --action ab --server-env 正式服   # 重建 AB + 复制到 StreamingAssets
#   scripts/resource_build.sh --action reuse --server-env 正式服   # 不重建，复用上一轮 AB 缓存（秒级）
#   scripts/resource_build.sh --action all  --server-env 正式服  # 先导表再重建 AB（两次 Unity 启动）
#
# 🔴 --action reuse（2026-10-23 新增）：**不启动 Unity**，直接把打包目录里上一轮重建的
#    Assets/StreamingAssets/Android 当作包内资源（它 gitignore，跨 ci_sync 的 reset 存活）。
#    只做两件事：① 按 --server-env 对齐包内快照 version.txt（apply_build_env 顺带做的）；
#    ② 用 scripts/ab_cache.py verify 校验「这份缓存能不能复用」——缓存不完整、或字节码在
#    上次重建之后变过（内容哈希不同）→ 直接 rc=3 拦住，因为这两种情况打出来的包
#    要么起不来、要么配置是旧的，而且**运行期不会报任何错**。
#    适用场景：只改了 C# / 打包参数 / 环境，资源没动，只想快速重出一版包。
#
# 🔴 --sync-tables（默认 apply）：导表成功后调用 scripts/table_sync.py，把「本次导表改动的
#    服务端 txt」增量推到两套服务端：本机测试服 ~/home/java/gameserver 与线上服
#    gs:/home/java/gameserver（各含 conf/server + assets/conf/server）。只推一边等于没改。
#    为什么默认开：客户端 lua 与服务端 txt 同源，但服务端那两份从来没被推过 ⇒ 客户端显示
#    一套、服务端校验另一套。为什么不整目录 rsync：Language 会丢 Korean 列、
#    EncourageTaskConfig 会删线上 25 条任务、30+ 张是未发布内容 —— 详见 docs/table_sync_skill.md。
#    工具只推「基线差异」里的表，且逐张过结构体检（列丢失/行丢失/nil 空值一律拦下），
#    第一次跑只建基线不推表。同步失败不拖垮导表（除非加 --sync-strict）。
#
# 🔴 为什么 AB 要带 --server-env：CopyAssetBundleToStreamingAssets 会把 Assets/Resources/
#    整目录快照到 StreamingAssets/Android/Resources（含 version.txt）。快照里的 serverUrl
#    才是真正打进包里的值 —— 不在这里注入，包就会连到「上次谁改的那条地址」。
#
# 退出码：0 成功 / 2 参数或环境错误 / 3 Unity 执行失败或 AB 缓存不可复用
#
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

UNITY_BIN="/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity"
VENV_PY="/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python"
STAMP="$(date '+%Y%m%d-%H%M%S')"

# python 解释器兜底：venv 不在（换机/新环境）就退回系统 python3，别让整条链路直接死
py_bin() {
    if [[ -x "$VENV_PY" ]]; then printf '%s' "$VENV_PY"; else command -v python3 || true; fi
}

ACTION="all"
SERVER_ENV=""
SYNC_TABLES="apply"     # off | plan | apply
SYNC_STRICT=0
SYNC_RESTART=0

# 🔴 2026-10-21 修：必须在解析参数**之前**留存原始 argv。
# 旧写法把 ORIG_ARGS=("$@") 放在 while 之后，那时 $@ 已被 shift 掏空 ⇒ 下面
# 「exec 自身套 unity 锁」重入时 args 为空，ACTION 回落成默认 all、SERVER_ENV 变空：
#   · `--action export` 实际跑成 all（导表完又白重建一次 AB，+10 分钟；
#     实测 TS-Resource-Build #13/#14 都是这样）
#   · `--action ab --server-env 测试服` 丢掉环境注入 ⇒ AB 里打包的是工程
#     当前 version.txt 的口径，不是请求的那个服（正是 job 自己警告的"连错服"）
ORIG_ARGS=("$@")

while [[ $# -gt 0 ]]; do
    case "$1" in
        --action)     ACTION="${2:-}"; shift 2 ;;
        --server-env) SERVER_ENV="${2:-}"; shift 2 ;;
        --sync-tables) SYNC_TABLES="${2:-}"; shift 2 ;;
        --sync-strict) SYNC_STRICT=1; shift ;;
        --sync-restart) SYNC_RESTART=1; shift ;;
        -h|--help)    /usr/bin/sed -n '2,30p' "$0"; exit 0 ;;
        *) echo "未知参数：$1" >&2; exit 2 ;;
    esac
done
case "$ACTION" in
    export|ab|reuse|all) ;;
    *) echo "✗ --action 只能是 export / ab / reuse / all（收到：${ACTION}）" >&2; exit 2 ;;
esac
case "$SYNC_TABLES" in
    off|plan|apply) ;;
    *) echo "✗ --sync-tables 只能是 off / plan / apply（收到：${SYNC_TABLES}）" >&2; exit 2 ;;
esac

# reuse 不启动 Unity（只读缓存 + 改 version.txt），所以不要求 Unity 存在
if [[ "$ACTION" != "reuse" ]]; then
    [[ -x "$UNITY_BIN" ]] || { echo "✗ 找不到 Unity：$UNITY_BIN" >&2; exit 2; }
fi

# 🔴 2026-10-21 修：整个执行体（注入→Unity→还原→快照核验）必须在 unity 锁内跑。
#    注入/还原原来裸奔在锁外 —— 并行 job（如 TS-Android-TestPackage）在同一工作区
#    注入自己的环境后，本脚本的 EXIT restore（备份基准=自己的口径）会把对方的注入值
#    覆盖掉：#15 实锤，包里打出的是本脚本的口径而不是测试包请求的口径。
#    做法：首跑时 exec 自身套锁重入（TSG_INNER 防递归）；.jenkins 不存在（纯手工环境）
#    时退回旧行为，只是不再有跨 job 互斥。
if [[ -z "${TSG_INNER:-}" && -x "$ROOT/.jenkins/lib/lock.sh" ]]; then
    exec env TSG_INNER=1 /usr/local/bin/bash "$ROOT/.jenkins/lib/lock.sh" --name unity run \
        --who "resource-build/$$/$ACTION" --timeout 3600 -- \
        /usr/local/bin/bash "$0" "${ORIG_ARGS[@]}"
fi

# 🔴 2026-10-20 修：旧判定有两处错，等于**从来没拦过**。
#   ① pgrep -f "Unity.*-projectPath $ROOT" 区分大小写，而 Unity Hub 拉起 GUI 时命令行是
#      小写 `-projectpath`（本机实测 PID 72958）⇒ 永远不命中；
#   ② 前置条件 `[[ ! -f Library/SourceAssetDB-lock ]]` 恰好在该文件**存在**时把检查整个跳过，
#      而那个 lock 正是「编辑器持有本工程」的产物 ⇒ 条件写反了。
# 后果：GUI 开着照样往下跑，两个实例争同一个 Library，最坏写坏库。
# 现在：只要命令行里带 -projectpath <本工程> 的 Unity 进程在（GUI 或别人的 batchmode），一律拒绝。
# ⚠️ 必须限定到**本工程**：本机常年有其它项目的 Unity 在跑，无条件 pgrep 会误伤。
# ⚠️ reuse 例外：它压根不启动 Unity（只读缓存 + 改 version.txt），不该被编辑器占工程挡住 ——
#    这条路径的存在意义之一就是「开发目录开着编辑器时也能秒出一版包」。
if [[ "$ACTION" != "reuse" ]]; then
    UNITY_LIST=$(pgrep -fl "Unity.app/Contents/MacOS/Unity" 2>/dev/null || true)
    UNITY_BUSY=$(printf '%s\n' "$UNITY_LIST" | grep -iF -- "-projectpath $ROOT" || true)
    if [[ -n "$UNITY_BUSY" ]]; then
        echo "✗ 本工程的 Unity 进程正在运行，batchmode 会争抢 Library：${UNITY_BUSY%%$'\n'*}" >&2
        printf '%s\n' "$UNITY_BUSY" >&2
        echo "  请先关闭 GUI Unity：osascript -e 'tell application \"Unity\" to quit'" >&2
        exit 2
    fi
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

# 🔴 导表后同步服务端表到线上服（2026-10-22 新增）。
#    只在「刚导过表」时跑（--action ab / reuse 没有新产物，跑了也没意义）。
#    同步失败默认不拖垮导表：导表产物已经在本地，线上没推只是「还是旧的」，
#    这个信息由工具自己打印，构建仍算成功；要让它变成构建失败就加 --sync-strict。
if [[ "$RC" -eq 0 && ( "$ACTION" == "export" || "$ACTION" == "all" ) && "$SYNC_TABLES" != "off" ]]; then
    PY_BIN="$(py_bin)"
    [[ -x "$PY_BIN" ]] || PY_BIN="$(command -v python3 || true)"
    if [[ -z "$PY_BIN" ]]; then
        echo "⚠ 找不到 python3，跳过服务端表同步" >&2
    else
        echo ""
        echo "==> 服务端表同步（table_sync --${SYNC_TABLES}）"
        SYNC_ARGS=""
        [[ "$SYNC_TABLES" == "apply" ]] && SYNC_ARGS="$SYNC_ARGS --apply"
        [[ "$SYNC_RESTART" -eq 1 ]] && SYNC_ARGS="$SYNC_ARGS --restart"
        [[ "$SYNC_STRICT" -eq 1 ]] && SYNC_ARGS="$SYNC_ARGS --strict"
        # shellcheck disable=SC2086  # 参数里不含空格，按词拆分正是本意
        "$PY_BIN" scripts/table_sync.py $SYNC_ARGS
        SYNC_RC=$?
        if [[ "$SYNC_RC" -eq 0 ]]; then
            echo "✅ 服务端表同步完成"
        else
            echo "⚠ 服务端表同步返回 ${SYNC_RC}（导表产物不受影响，明细见 build/table_sync/reports/）" >&2
            [[ "$SYNC_STRICT" -eq 1 ]] && RC="$SYNC_RC"
        fi
    fi
fi

if [[ "$RC" -eq 0 && ( "$ACTION" == "ab" || "$ACTION" == "all" ) ]]; then
    run_unity BuildAllABs ab || RC=$?
    if [[ "$RC" -eq 0 ]]; then
        echo "✅ AB 重建完成"
        # 🔴 清理 StreamingAssets 里 Unity 残留的临时文件（.filename.XXXXXX）：
        #    macOS 上 CopyAssetBundleToStreamingAssets 的 atomic-write 会留下 . 前缀临时文件，
        #    FileUtils.CopyDir 已修（跳过 . 前缀），但保险起见在这里也清一遍。
        find "$ROOT/Assets/StreamingAssets" -name ".*" -type f ! -name ".DS_Store" -delete 2>/dev/null || true
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
        # 记录缓存指纹：下一次 --action reuse 靠它判断「这份缓存是哪次重建的、字节码有没有变」。
        # 失败不拖垮本次构建（产物已经好了），只是下次复用会退化成「只能看文件在不在」。
        PY_BIN="$(py_bin)"
        if [[ -n "$PY_BIN" ]]; then
            "$PY_BIN" scripts/ab_cache.py record --server-env "$SERVER_ENV" --mode rebuild \
                || echo "⚠ 记录 AB 缓存指纹失败（不影响本次产物，只影响下次「复用缓存」的判定精度）" >&2
        else
            echo "⚠ 找不到 python3，跳过 AB 缓存指纹记录" >&2
        fi
    fi
fi

# 🔴 --action reuse：不重建，只把「上一轮的 AB 缓存」确认成可以进包的状态。
#    为什么要有这一步而不是「什么都不做」：复用缓存最容易出的两种错都**不报错**——
#    ① 缓存不完整（少了 luabytes / resconfigs）⇒ 包能装上但起不来；
#    ② 缓存里的 Lua 是旧的（导过表/同步过字节码之后没重建）⇒ 改了配置真机不生效。
#    两者都由 scripts/ab_cache.py verify 判（存在性 + 指纹 + 字节码内容哈希）。
if [[ "$RC" -eq 0 && "$ACTION" == "reuse" ]]; then
    echo ""
    echo "==> 复用上一轮 AB 缓存（不启动 Unity，不重打 bundle）"
    PY_BIN="$(py_bin)"
    if [[ -z "$PY_BIN" ]]; then
        echo "✗ 找不到 python3，无法校验 AB 缓存（拒绝在没校验的情况下出包）" >&2
        RC=3
    else
        "$PY_BIN" scripts/ab_cache.py verify --server-env "$SERVER_ENV"
        VERIFY_RC=$?
        if [[ "$VERIFY_RC" -eq 0 ]]; then
            echo "✅ AB 缓存可复用（包内资源就是上面这份，未重打）"
        else
            echo "✗ AB 缓存不可复用（见上方 ✗）。要么选 AB_MODE=重建，要么确认后选 跳过" >&2
            RC=3
        fi
    fi
fi

exit "$RC"
