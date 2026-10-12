#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Google Play AAB 上传器 —— 走 Play Developer API v3（androidpublisher）。

用途：把 Unity 打出的 .aab 上传到 Google Play，并发布到指定轨道（默认 production）。

依赖：
    google-api-python-client, google-auth
    （本机已装在 /Users/wangxufeng/.workbuddy/binaries/python/envs/default）

认证：
    需要 Google Cloud service account 的 JSON 密钥，且该 service account 的邮箱
    已在 Play Console → 用户和权限 中被授予「发布到正式版」权限。
    密钥路径优先级：--service-account > $GOOGLE_PLAY_SERVICE_ACCOUNT > ~/.gplay/service-account.json
    申请与授权步骤见 docs/google_play_upload_setup.md

用法示例：
    # 先干跑：只认证 + 列出各轨道现状，不上传
    python3 scripts/play_upload.py --aab apks/2026-10-11/CLIBuild/120000.aab --dry-run

    # 正式上传并发布到 production（全量）
    python3 scripts/play_upload.py --aab <path>.aab --track production --status completed --yes

    # 分阶段放量 10%
    python3 scripts/play_upload.py --aab <path>.aab --track production --status inProgress --user-fraction 0.1 --yes

退出码：
    0 成功 / 2 参数或环境错误 / 3 认证失败 / 4 API 业务错误 / 5 版本号校验失败
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

try:
    import httplib2
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    from googleapiclient.http import MediaFileUpload
except ImportError:  # pragma: no cover
    sys.stderr.write(
        "[FATAL] 缺少依赖。请用项目 venv 运行：\n"
        "  /Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python scripts/play_upload.py ...\n"
        "或先安装：\n"
        "  <venv>/bin/pip install google-api-python-client google-auth\n"
    )
    sys.exit(2)

SCOPE = "https://www.googleapis.com/auth/androidpublisher"
DEFAULT_PACKAGE = "com.Warera.timespace"
DEFAULT_SA_CANDIDATES = [
    Path.home() / ".gplay" / "service-account.json",
]
# 允许的 release status
VALID_STATUS = {"draft", "inProgress", "halted", "completed"}

# --------------------------------------------------------------------------- #
# 大包上传健壮性参数（2026-10-12 实测踩坑后加入）
#
# 根因链：
#   1. google-auth-httplib2 构造 AuthorizedHttp 时，会给底层 httplib2.Http
#      设 timeout=60（已实测确认 service._http.http.timeout == 60）。
#   2. googleapiclient 的 MediaFileUpload 默认 chunksize = 100 MB。
#   3. 421 MB 的 AAB 走本地代理（实测 ~400 KB/s）时，单块需 4 分钟以上，
#      60 秒读超时必然先触发，抛 "TimeoutError: The read operation timed out"。
#   4. 当时只捕获 HttpError，超时异常直接冒泡成 traceback，退出码 1，
#      且未回滚 edit —— 留下脏状态。
#
# ⇒ 三处一起改：放大读超时、缩小分块、断点续传重试；并补异常回滚。
#   可用环境变量覆盖：PLAY_UPLOAD_TIMEOUT_S / PLAY_UPLOAD_CHUNK_MB / PLAY_UPLOAD_MAX_RETRIES
# --------------------------------------------------------------------------- #
UPLOAD_HTTP_TIMEOUT_S = int(os.environ.get("PLAY_UPLOAD_TIMEOUT_S", "300"))
UPLOAD_CHUNK_BYTES = int(os.environ.get("PLAY_UPLOAD_CHUNK_MB", "8")) * 1024 * 1024
UPLOAD_MAX_RETRIES = int(os.environ.get("PLAY_UPLOAD_MAX_RETRIES", "8"))
# 断点续传失败后值得重试的状态码（4xx 中只有 408/429 值得）
RETRYABLE_HTTP_STATUS = {408, 429, 500, 502, 503, 504}
# 这些轨道支持 changesNotSentForReview
NON_PROD_TRACKS = {"internal", "alpha", "beta"}


# --------------------------------------------------------------------------- #
# 工具函数
# --------------------------------------------------------------------------- #
def log(msg: str) -> None:
    print(msg, flush=True)


def format_http_error(exc) -> str:
    """把 HttpError 拆成人话：HTTP 状态 + API status + reason + message。

    只取 exc.reason / str(exc) 会丢掉真正的诊断字段，403 的两种成因
    （API 未启用 vs Play Console 未授权）在 reason 上完全不同，必须区分。
    """
    status = getattr(getattr(exc, "resp", None), "status", "?")
    reason_field = ""
    api_status = ""
    message = ""
    reasons: list[str] = []

    content = getattr(exc, "content", None)
    if content:
        try:
            body = json.loads(content.decode("utf-8", "replace"))
            err = body.get("error", {})
            message = err.get("message", "") or ""
            api_status = err.get("status", "") or ""
            for e in err.get("errors", []) or []:
                if e.get("reason"):
                    reasons.append(e["reason"])
            if not reasons and err.get("details"):
                for d in err["details"]:
                    if d.get("reason"):
                        reasons.append(d["reason"])
        except Exception:  # noqa: BLE001
            pass

    if not message:
        message = getattr(exc, "reason", "") or str(exc)
    reason_field = ", ".join(dict.fromkeys(reasons)) if reasons else "-"

    return (
        f"HTTP {status}"
        + (f" / {api_status}" if api_status else "")
        + f" / reason={reason_field}\n     message: {message}"
    )


def hint_for_error(text: str) -> str:
    """按 API reason / message 给出准确的下一步动作。"""
    low = text.lower()
    if "accessnotconfigured" in low or "has not been used in project" in low or "is disabled" in low:
        return (
            "Google Play Android Developer API 在该 Cloud 项目里尚未启用。\n"
            "   → 打开 https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com 点「启用」"
        )
    if "permission" in low or "forbidden" in low or "permission_denied" in low:
        return (
            "service account 未在 Play Console 获得发布权限（Cloud 侧建号 ≠ 能发布）。\n"
            "   → Play Console →「用户和权限」→ 邀请新用户，填该 service account 邮箱，\n"
            "     勾选「发布到正式版、排除设备并使用 Google Play 应用签名」\n"
            "   → 授权后权限传播需几分钟～数小时，稍后重试\n"
            "   详见 docs/google_play_upload_setup.md §1.2"
        )
    if "versioncode" in low or "already been used" in low:
        return "versionCode 重复。用 scripts/aab_release.sh（默认 --bump）重新提号打包。"
    if "not signed" in low or "signature" in low:
        return "签名相关失败。确认 Play Console 已启用 Play 应用签名，且 AutoSignKeystore.cs 生效。"
    if "edit has been deleted" in low or "failed_precondition" in low:
        return (
            "Play 的 edit 会话已被删除（未提交的 edit 有生命周期，且同一 App 的并发 edit 会互相作废）。\n"
            "   → 2026-10-12 实测：上传到 85% 时另一个进程对该 App 开了新 edit ⇒ 本 edit 被判 deleted。\n"
            "   → 上传期间**不要**并发调用 Play API（如 16KB 巡检脚本 play_16kb_watch.py）。\n"
            "   → 直接重跑本脚本即可（会新建 edit 并重传）。"
        )
    return "详见 docs/google_play_upload_setup.md §5 错误对照表。"


def die(msg: str, code: int = 2) -> None:
    sys.stderr.write(f"[ERROR] {msg}\n")
    sys.exit(code)


def resolve_service_account(explicit: str | None) -> Path:
    """按优先级找到 service account JSON。"""
    if explicit:
        p = Path(explicit).expanduser()
        if not p.is_file():
            die(f"--service-account 指向的文件不存在：{p}", 2)
        return p

    env = os.environ.get("GOOGLE_PLAY_SERVICE_ACCOUNT")
    if env:
        p = Path(env).expanduser()
        if p.is_file():
            return p
        die(f"$GOOGLE_PLAY_SERVICE_ACCOUNT 指向的文件不存在：{p}", 2)

    for cand in DEFAULT_SA_CANDIDATES:
        if cand.is_file():
            return cand

    die(
        "找不到 service account 密钥。请任选其一：\n"
        "  1) 把密钥放到 ~/.gplay/service-account.json\n"
        "  2) 设置环境变量 GOOGLE_PLAY_SERVICE_ACCOUNT=/abs/path/key.json\n"
        "  3) 传 --service-account /abs/path/key.json\n"
        "申请步骤见 docs/google_play_upload_setup.md",
        2,
    )
    raise SystemExit(2)  # 不可达，仅为类型收敛


def widen_http_timeout(service, timeout_s: int) -> None:
    """放大底层 httplib2 的读超时，并清掉已缓存连接。

    google-auth-httplib2 在构造 AuthorizedHttp 时给 httplib2.Http 设了
    timeout=60（实测 service._http.http.timeout == 60），对 100 MB 级分块
    来说太短。httplib2 只在**建立连接时**读取 self.timeout 并把连接缓存进
    .connections，所以必须同时清空缓存，否则复用的旧连接仍带 60s 超时。
    """
    targets = []
    outer = getattr(service, "_http", None)
    if outer is not None:
        targets.append(outer)
        inner = getattr(outer, "http", None)
        if inner is not None:
            targets.append(inner)
    for obj in targets:
        try:
            obj.timeout = timeout_s
        except Exception:  # noqa: BLE001
            pass
        conns = getattr(obj, "connections", None)
        if conns is not None:
            try:
                conns.clear()
            except Exception:  # noqa: BLE001
                try:
                    obj.connections = {}
                except Exception:  # noqa: BLE001
                    pass


def is_retryable_upload_error(exc: BaseException) -> bool:
    """判断上传中断是否值得重试（断点续传语义下重试是安全的）。"""
    if isinstance(exc, HttpError):
        try:
            return int(getattr(exc.resp, "status", 0)) in RETRYABLE_HTTP_STATUS
        except (TypeError, ValueError):
            return False
    # 网络层：读超时、连接重置、代理断流等（TimeoutError 是 OSError 子类）
    if isinstance(exc, OSError):
        return True
    try:
        return isinstance(exc, httplib2.HttpLib2Error)
    except Exception:  # noqa: BLE001
        return False


def http_status_of(exc: BaseException) -> int:
    """取 HttpError 的 HTTP 状态码，取不到返回 0。"""
    try:
        return int(getattr(getattr(exc, "resp", None), "status", 0) or 0)
    except (TypeError, ValueError):
        return 0


def execute_with_retry(request_factory, label: str, max_retries: int = UPLOAD_MAX_RETRIES):
    """对 Play 编辑类 API（tracks.update / edits.commit）加可重试。

    背景：原先只给「上传分块」加了断点续传重试，`tracks().update()` 与
    `edits().commit()` 都是裸调用。2026-10-12 一次 HTTP 503 恰好打在 commit 上，
    整个 edit 按设计被回滚 —— 421 MB 白传一遍。

    这类调用在失败（未被子受理）的前提下重发是安全的；`request_factory` 每次
    重试都新建请求对象（googleapiclient 的请求是一次性的，不能复用）。
    """
    attempt = 0
    while True:
        try:
            return request_factory().execute()
        except Exception as exc:  # noqa: BLE001
            status = http_status_of(exc)
            retryable = isinstance(exc, HttpError) and status in RETRYABLE_HTTP_STATUS
            retryable = retryable or isinstance(exc, OSError)
            if not retryable or attempt >= max_retries:
                raise
            attempt += 1
            wait = min(2 ** attempt, 30)
            log(
                f"[{label}] 第 {attempt}/{max_retries} 次失败"
                f"（HTTP {status or '网络'} {type(exc).__name__}），{wait}s 后重试…"
            )
            time.sleep(wait)


def track_has_version(service, package: str, track: str, version_code: str) -> bool:
    """回查轨道，确认某个 versionCode 是否已挂上。

    用于 commit 结果不确定时兜底：503 有可能发生在服务端**已受理**之后，此时
    edit 已被消费，重试 commit 会报「edit 不存在」—— 不能据此判定失败。
    """
    try:
        edit_id = service.edits().insert(packageName=package, body={}).execute()["id"]
    except Exception:  # noqa: BLE001
        return False
    try:
        resp = service.edits().tracks().list(
            packageName=package, editId=edit_id
        ).execute()
        for t in resp.get("tracks", []):
            if t.get("track") != track:
                continue
            for rel in t.get("releases", []):
                if version_code in [str(v) for v in rel.get("versionCodes", [])]:
                    return True
        return False
    except Exception:  # noqa: BLE001
        return False
    finally:
        try:
            service.edits().delete(packageName=package, editId=edit_id).execute()
        except Exception:  # noqa: BLE001
            pass


def build_service(sa_path: Path):
    """构造 androidpublisher v3 客户端。"""
    try:
        creds = service_account.Credentials.from_service_account_file(
            str(sa_path), scopes=[SCOPE]
        )
    except Exception as exc:  # noqa: BLE001
        die(f"读取 service account 密钥失败（{sa_path}）：{exc}", 3)

    sa_email = ""
    try:
        sa_email = service_account.Credentials.from_service_account_file(
            str(sa_path)
        ).service_account_email
    except Exception:  # noqa: BLE001
        pass

    log(f"[auth] service account: {sa_email or '(未知)'}")
    if sa_email:
        log(f"[auth] 确认该邮箱已在 Play Console → 用户和权限 中被授予「发布到正式版」")
    try:
        service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    except Exception as exc:  # noqa: BLE001
        die(f"初始化 Play API 客户端失败：{exc}", 3)
    widen_http_timeout(service, UPLOAD_HTTP_TIMEOUT_S)
    log(
        f"[auth] 上传参数：分块 {UPLOAD_CHUNK_BYTES // 1048576} MB / "
        f"读超时 {UPLOAD_HTTP_TIMEOUT_S}s / 最多重试 {UPLOAD_MAX_RETRIES} 次"
    )
    return service


def read_aab_version_code(aab_path: Path, override: int | None) -> int | None:
    """尽力取出 AAB 的 versionCode，取不到返回 None。

    顺序：显式覆盖 > 构建包装脚本写的同名 .json sidecar > bundletool > ProjectSettings.asset
    """
    if override is not None:
        return override

    sidecar = Path(str(aab_path) + ".json")
    if sidecar.is_file():
        try:
            data = json.loads(sidecar.read_text(encoding="utf-8"))
            if data.get("versionCode"):
                return int(data["versionCode"])
        except Exception:  # noqa: BLE001
            pass

    # bundletool（若用户装过）
    import shutil
    import subprocess  # noqa: PLC0415

    bt = shutil.which("bundletool")
    if bt:
        try:
            out = subprocess.run(
                [bt, "dump", "manifest", f"--bundle={aab_path}"],
                capture_output=True,
                text=True,
                timeout=120,
            )
            if out.returncode == 0:
                import re  # noqa: PLC0415

                m = re.search(r'versionCode="?(\d+)"?', out.stdout)
                if m:
                    return int(m.group(1))
        except Exception:  # noqa: BLE001
            pass

    # 兜底：读工程设置（CLI 打包不会自增，值与工程一致）
    ps = Path(__file__).resolve().parent.parent / "ProjectSettings" / "ProjectSettings.asset"
    if ps.is_file():
        import re  # noqa: PLC0415

        m = re.search(r"AndroidBundleVersionCode:\s*(\d+)", ps.read_text(encoding="utf-8", errors="ignore"))
        if m:
            return int(m.group(1))
    return None


def current_track_version_codes(service, pkg: str, edit_id: str, track: str) -> list[int]:
    """返回某轨道当前所有 revision 里出现过的 versionCode。"""
    try:
        resp = service.edits().tracks().list(packageName=pkg, editId=edit_id).execute()
    except HttpError as exc:
        log(f"[warn] 读取轨道列表失败（不影响上传）：{exc}")
        return []
    codes: list[int] = []
    for t in resp.get("tracks", []):
        if t.get("track") != track:
            continue
        for rel in t.get("releases", []):
            for vc in rel.get("versionCodes", []):
                try:
                    codes.append(int(vc))
                except (TypeError, ValueError):
                    pass
    return codes


# --------------------------------------------------------------------------- #
# 主流程
# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(
        description="上传 AAB 到 Google Play 并发布到指定轨道",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--aab", required=True, help="AAB 文件路径")
    ap.add_argument("--package", default=DEFAULT_PACKAGE, help=f"应用包名（默认 {DEFAULT_PACKAGE}）")
    ap.add_argument("--track", default="production",
                    help="目标轨道：production / beta / alpha / internal（默认 production）")
    ap.add_argument("--status", default="completed", choices=sorted(VALID_STATUS),
                    help="发布状态（默认 completed=全量）")
    ap.add_argument("--user-fraction", type=float, default=None,
                    help="分阶段放量比例 0~1，仅 status=inProgress 时有效")
    ap.add_argument("--release-notes", default=None,
                    help="更新说明正文；不传则用内置默认文案")
    ap.add_argument("--release-notes-lang", default="zh-CN",
                    help="更新说明语言标签（默认 zh-CN）")
    ap.add_argument("--service-account", default=None, help="service account JSON 路径")
    ap.add_argument("--version-code", type=int, default=None, help="手动指定 versionCode（覆盖自动探测）")
    ap.add_argument("--dry-run", action="store_true", help="只认证并列出现状，不上传不提交")
    ap.add_argument("--yes", action="store_true", help="跳过交互确认（CI 用）")
    ap.add_argument("--changes-not-sent-for-review", action="store_true",
                    help="提交但不送审（仅 internal/alpha/beta 有效）")
    args = ap.parse_args()

    aab = Path(args.aab).expanduser().resolve()
    if not aab.is_file():
        die(f"AAB 不存在：{aab}", 2)
    size_mb = aab.stat().st_size / 1024 / 1024
    if aab.stat().st_size < 1024 * 1024:
        die(f"AAB 体积异常（{size_mb:.2f} MB），疑似构建未完成：{aab}", 2)

    if args.status == "inProgress" and args.user_fraction is None:
        die("status=inProgress 必须同时指定 --user-fraction（如 0.1）", 2)
    if args.user_fraction is not None and not (0.0 < args.user_fraction <= 1.0):
        die("--user-fraction 必须在 (0, 1] 区间", 2)

    sa_path = resolve_service_account(args.service_account)
    log(f"[env] package      : {args.package}")
    log(f"[env] aab          : {aab}  ({size_mb:.2f} MB)")
    log(f"[env] track        : {args.track}")
    log(f"[env] status       : {args.status}" + (f"  userFraction={args.user_fraction}" if args.user_fraction else ""))
    log(f"[env] key          : {sa_path}")
    log("")

    service = build_service(sa_path)

    # ---------------- 打开 edit（一个 edit 是一组原子改动） ----------------
    try:
        edit = service.edits().insert(body={}, packageName=args.package).execute()
    except HttpError as exc:
        detail = format_http_error(exc)
        log("")
        log(f"🔴 创建 edit 失败：{detail}")
        log(f"   诊断：{hint_for_error(detail)}")
        sys.exit(3)
    edit_id = edit["id"]
    log(f"[edit] editId = {edit_id}")

    try:
        # ---------------- 现状：各轨道版本 ----------------
        try:
            tracks_resp = service.edits().tracks().list(packageName=args.package, editId=edit_id).execute()
        except HttpError as exc:
            tracks_resp = {}
            log(f"[warn] 列轨道失败：{exc}")
        log("[tracks] 当前轨道现状：")
        for t in tracks_resp.get("tracks", []):
            rels = t.get("releases", [])
            desc = "; ".join(
                f"{r.get('status')} v{','.join(r.get('versionCodes', []))}" for r in rels
            ) or "(空)"
            log(f"  - {t.get('track'):<12} {desc}")

        existing = current_track_version_codes(service, args.package, edit_id, args.track)
        probe_vc = read_aab_version_code(aab, args.version_code)
        if probe_vc is not None:
            log(f"[check] 待上传 AAB 的 versionCode（探测值）= {probe_vc}")
        if existing:
            log(f"[check] 目标轨道 {args.track} 已有 versionCode = {sorted(existing)}")

        if probe_vc is not None and existing:
            if probe_vc <= max(existing):
                log("")
                log(f"🔴 版本号撞车：待传 {probe_vc} <= 轨道已有最大 {max(existing)}。")
                log("   production 轨道要求 versionCode 严格递增，否则提交会被 Play 拒绝。")
                log("   本项目的 CLI 打包不会自增 versionCode（自增逻辑只在 GUI 的")
                log("   Assets/Scripts/Editor/GameEditor/FrameTool/BuildWindow.cs:449）。")
                log("   请用 scripts/aab_release.sh（默认带 --bump）或先手动调高")
                log("   ProjectSettings.asset 里的 AndroidBundleVersionCode。")
                return 5

        if args.dry_run:
            log("")
            log("[dry-run] 未上传、未提交。删除 edit 后退出。")
            try:
                service.edits().delete(packageName=args.package, editId=edit_id).execute()
            except HttpError:
                pass
            return 0

        # ---------------- 交互确认 ----------------
        if not args.yes:
            log("")
            log("⚠️  即将把上述 AAB 发布到轨道 "
                f"『{args.track}』，状态 {args.status}"
                + (f"，放量 {args.user_fraction:.0%}" if args.user_fraction else "")
                + "。")
            if args.track == "production":
                log("    production = 正式版，将进入 Google 审核并面向全部用户。")
            ans = input("    确认继续？输入 yes 回车：").strip().lower()
            if ans != "yes":
                log("[abort] 用户取消。删除 edit 后退出。")
                try:
                    service.edits().delete(packageName=args.package, editId=edit_id).execute()
                except HttpError:
                    pass
                return 0

        # ---------------- 上传 bundle ----------------
        log("")
        log(
            f"[upload] 开始上传 {aab.name}（{size_mb:.2f} MB），"
            f"分块 {UPLOAD_CHUNK_BYTES // 1048576} MB，可断点续传，请勿中断…"
        )
        media = MediaFileUpload(
            str(aab),
            mimetype="application/octet-stream",
            resumable=True,
            chunksize=UPLOAD_CHUNK_BYTES,
        )
        request = service.edits().bundles().upload(
            packageName=args.package, editId=edit_id, media_body=media
        )
        response = None
        last_pct = -1
        attempt = 0
        while response is None:
            try:
                status, response = request.next_chunk()
            except Exception as exc:  # noqa: BLE001
                # 断点续传语义：服务端已确认的字节保留，再次调用 next_chunk()
                # 会从最后一个已提交偏移继续，无需重传整个文件。
                if not is_retryable_upload_error(exc) or attempt >= UPLOAD_MAX_RETRIES:
                    raise
                attempt += 1
                wait = min(2 ** attempt, 30)
                log(
                    f"[upload] 第 {attempt}/{UPLOAD_MAX_RETRIES} 次中断"
                    f"（{type(exc).__name__}: {exc}），{wait}s 后从断点续传…"
                )
                time.sleep(wait)
                continue
            attempt = 0
            if status:
                pct = int(status.progress() * 100)
                if pct != last_pct and pct % 5 == 0:
                    log(f"[upload] {pct}%")
                    last_pct = pct
        uploaded_vc = int(response.get("versionCode", probe_vc or 0))
        log(f"[upload] ✅ 上传完成，Play 返回 versionCode = {uploaded_vc}")

        if existing and uploaded_vc <= max(existing):
            die(
                f"上传后的 versionCode {uploaded_vc} 仍 <= 轨道已有最大 {max(existing)}，"
                "Play 会在提交阶段拒绝。请提升 versionCode 后重新打包。",
                5,
            )

        # ---------------- 绑定到轨道 ----------------
        notes_text = args.release_notes or "问题修复与体验优化。"
        release = {
            "status": args.status,
            "versionCodes": [str(uploaded_vc)],
            "releaseNotes": [{"language": args.release_notes_lang, "text": notes_text}],
        }
        if args.status == "inProgress" and args.user_fraction is not None:
            release["userFraction"] = args.user_fraction

        track_body = {"track": args.track, "releases": [release]}
        log(f"[track] 写入轨道 {args.track}：status={args.status} versionCodes={release['versionCodes']}")
        execute_with_retry(
            lambda: service.edits().tracks().update(
                packageName=args.package, editId=edit_id, track=args.track, body=track_body
            ),
            "track",
        )

        # ---------------- 提交 ----------------
        commit_kwargs = {"packageName": args.package, "editId": edit_id}
        if args.changes_not_sent_for_review:
            if args.track not in NON_PROD_TRACKS:
                die("--changes-not-sent-for-review 仅对 internal/alpha/beta 轨道有效", 2)
            commit_kwargs["changesNotSentForReview"] = True
        try:
            execute_with_retry(
                lambda: service.edits().commit(**commit_kwargs), "commit"
            )
        except HttpError as exc:
            # 503 可能发生在服务端已受理之后——edit 已被消费，重试会报 edit 不存在。
            # 回查轨道确认版本确实挂上了就当成功，避免误判成失败去重传 421MB。
            if track_has_version(service, args.package, args.track, str(uploaded_vc)):
                log("[commit] 回查确认版本已在轨道上 —— 视为提交成功（首次响应为 503）")
            else:
                raise
        log("")
        log(f"✅ 提交成功：{args.package} -> {args.track} / versionCode {uploaded_vc}")
        if args.track == "production":
            log("   提示：「会进入审核」仅适用于 status=completed；status=draft 只保存草稿，需人工在 Console 发布。")
        return 0

    except HttpError as exc:
        detail = format_http_error(exc)
        log("")
        log(f"🔴 API 调用失败：{detail}")
        log(f"   诊断：{hint_for_error(detail)}")
        try:
            service.edits().delete(packageName=args.package, editId=edit_id).execute()
            log("[cleanup] 已回滚未提交的 edit。")
        except HttpError:
            pass
        return 4
    except KeyboardInterrupt:
        log("")
        log("[abort] 收到中断，回滚 edit…")
        try:
            service.edits().delete(packageName=args.package, editId=edit_id).execute()
            log("[cleanup] 已回滚。")
        except HttpError:
            pass
        return 130
    except Exception as exc:  # noqa: BLE001
        # 网络层异常（读超时/连接断）此前不在这里，会直接冒泡成 traceback
        # 并留下未回滚的 edit —— 2026-10-12 实测踩到，故补上兜底。
        log("")
        log(f"🔴 上传过程异常终止：{type(exc).__name__}: {exc}")
        log("   若为网络超时，重跑本脚本即可（会重新发起上传，Play 侧 edit 会自动过期）。")
        try:
            service.edits().delete(packageName=args.package, editId=edit_id).execute()
            log("[cleanup] 已回滚未提交的 edit。")
        except Exception:  # noqa: BLE001
            log("[cleanup] edit 回滚失败（大概率已过期），不影响下次重跑。")
        return 4


if __name__ == "__main__":
    sys.exit(main())
