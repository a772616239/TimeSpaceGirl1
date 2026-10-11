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
from pathlib import Path

try:
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
# 这些轨道支持 changesNotSentForReview
NON_PROD_TRACKS = {"internal", "alpha", "beta"}


# --------------------------------------------------------------------------- #
# 工具函数
# --------------------------------------------------------------------------- #
def log(msg: str) -> None:
    print(msg, flush=True)


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
        detail = getattr(exc, "reason", "") or str(exc)
        die(
            "创建 edit 失败，最常见原因是 service account 未在 Play Console 授权，"
            f"或未启用 Google Play Android Developer API。\n  原始错误：{detail}",
            3,
        )
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
        log(f"[upload] 开始上传 {aab.name}（{size_mb:.2f} MB），可断点续传，请勿中断…")
        media = MediaFileUpload(str(aab), mimetype="application/octet-stream", resumable=True)
        request = service.edits().bundles().upload(
            packageName=args.package, editId=edit_id, media_body=media
        )
        response = None
        last_pct = -1
        while response is None:
            status, response = request.next_chunk()
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
        service.edits().tracks().update(
            packageName=args.package, editId=edit_id, track=args.track, body=track_body
        ).execute()

        # ---------------- 提交 ----------------
        commit_kwargs = {"packageName": args.package, "editId": edit_id}
        if args.changes_not_sent_for_review:
            if args.track not in NON_PROD_TRACKS:
                die("--changes-not-sent-for-review 仅对 internal/alpha/beta 轨道有效", 2)
            commit_kwargs["changesNotSentForReview"] = True
        service.edits().commit(**commit_kwargs).execute()
        log("")
        log(f"✅ 提交成功：{args.package} -> {args.track} / versionCode {uploaded_vc}")
        if args.track == "production":
            log("   下一步：Play Console 会进入审核，通过后按你设定的放量比例生效。")
        return 0

    except HttpError as exc:
        status = getattr(exc.resp, "status", "?")
        detail = getattr(exc, "reason", "") or str(exc)
        log("")
        log(f"🔴 API 调用失败（HTTP {status}）：{detail}")
        if str(status) == "403":
            log("   403 通常是权限问题：确认 service account 邮箱已在 Play Console")
            log("   → 用户和权限 中被授予「发布到正式版 / 管理测试轨道」权限。")
        elif str(status) == "400":
            log("   400 常见原因：versionCode 已被使用 / versionName 非法 / 应用未启用 Play App Signing。")
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


if __name__ == "__main__":
    sys.exit(main())
