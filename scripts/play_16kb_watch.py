#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Google Play 16KB 页大小合规巡检（TimeSpaceGirl1 / com.Warera.timespace）。

做三件事：
  1. 查 Play 各轨道现状（production 的 versionCode / status），判断新版是否已上线；
  2. 对最新 AAB 取证 16KB **两层**——
     门槛1：每个 .so 的 ELF PT_LOAD 对齐（`p_align >= 16384`）
     门槛2：各 arm64 库的构建 NDK（Play「旧版 NDK 编译」告警点名的层）
  3. 与上次结果 diff（直接回答「问题还在不在」），邮件汇报。

⚠️ Play Console 的 16KB 告警**没有公开 API**，脚本覆盖不了的那一半只能人工核对：
   Play Console → 发布 → App Bundle 浏览器 → 选择版本 → 「支持的页大小」
   （该告警按 Google 的【已知问题库清单】点名，不随 NDK 版本阈值变化。）

🔴 本脚本会创建/删除一个 Play edit。**切勿与 `play_upload.py` 上传并发运行**：
   已实测一次「上传到 85% 时另一个进程开了 edit」⇒ 上传的 edit 被判 `This Edit has been
   deleted`（HTTP 400 / FAILED_PRECONDITION）而整包失败。上传期间请勿跑本脚本。

用法:
  python3 scripts/play_16kb_watch.py                  # 体检 + 发邮件
  python3 scripts/play_16kb_watch.py --dry-run        # 只打印，不发邮件
  python3 scripts/play_16kb_watch.py --aab <path>     # 指定 AAB（默认取最新）
  python3 scripts/play_16kb_watch.py --no-mail        # 不发邮件

退出码: 0 正常 / 1 门槛1 有回归（存在未对齐 .so） / 2 脚本自身出错
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import subprocess
import sys
import tempfile
import zipfile
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(BASE_DIR)

# 16KB 取证工具在跨仓 main_android（可用环境变量覆盖）
TOOLS_DIR = os.environ.get(
    "PAGE16K_TOOLS_DIR",
    "/Users/wangxufeng/Documents/main_android/Release/tools",
)
PYTHON = sys.executable or "python3"
PKG = "com.Warera.timespace"
SERVICE_ACCOUNT_CANDIDATES = [
    # 🔴 工程本地优先（2026-10-13 起）：见 docs/secrets_setup.md，该目录永不入库
    os.path.join(os.path.dirname(BASE_DIR), ".secrets", "service-account.json"),
    os.path.expanduser("~/.gplay/service-account.json"),   # 兼容回退
]
SERVICE_ACCOUNT = next(
    (p for p in SERVICE_ACCOUNT_CANDIDATES if os.path.isfile(p)),
    SERVICE_ACCOUNT_CANDIDATES[0],
)
ARCH = "arm64-v8a"
STATE_FILE = os.path.join(BASE_DIR, ".play16kb_state.json")

# 已知需上游修复的库（供报告做上下文解释，不参与判定）
KNOWN_FIX_NOTES = {
    "libnative-googlesignin.so": "✅ 2026-10-12 已修复：移除 com.google.signin:google-signin-support:1.0.4 依赖，库已不再进包（commit 72502790b）",
    "libtolua.so": "✅ 2026-10-12 已修复：NDK r28 重编 + LJ_PAGESIZE=16384（commit 2f4e7310f，见 scripts/libtolua16k/）",
    "libFirebaseCppApp-12_8_0": "Firebase 官方预编译 r21e；已升到 12.10.1 换掉文件名，Play 不再点名（仍 r21e 但不在清单内）",
}

# 🔴 Play 的「旧版 NDK 编译」告警按【已知问题库清单】点名，**不是**按 NDK 版本阈值。
#    因此 NDK < r28 ≠ 一定被点名：Unity 自出库（il2cpp/unity/main, r23b）与 crashlytics（r25b）
#    虽 < r28 却从未被点名；而被点名的 5 个全是第三方预编译/自编库。
#
# 2026-10-12 v64 实测修正（重要）：
#   Play 是按【库文件名】点名，文件名含版本号的库**换版本就等于换名字**。
#   - Firebase 12.8.0 → 12.10.1 后，`libFirebaseCppApp-12_8_0.so` 不再存在，
#     Play 告警从 5 个降到 2 个（Firebase ×3 全部消失，尽管实测仍 r21e）。
#   ⇒ 所以这里只盯 **12_8_0** 这个旧名字，不能按 `libFirebaseCppApp` 前缀匹配，
#     否则 12_10_1 会被误判成「仍待上游」。
#
# 保留下方集合 = 「历史被 Play 点名过、需盯回归」的库。
# 报告里 verdict == "ok" 的会显示「✅ 已达标」：
#   - libnative-googlesignin.so  已随 signin-support 1.0.4 依赖移除而彻底消失（commit 72502790b）
#   - libtolua.so                已用 NDK r28 重编（commit 2f4e7310f，见 scripts/libtolua16k/）
PLAY_FLAGGED = {
    "libFirebaseCppAnalytics.so",
    "libFirebaseCppCrashlytics.so",
    "libnative-googlesignin.so",
    "libtolua.so",
}
PLAY_FLAGGED_PREFIXES = ("libFirebaseCppApp-12_8_0",)  # 只匹配被点名过的那个版本名


def is_play_flagged(name: str) -> bool:
    return name in PLAY_FLAGGED or name.startswith(PLAY_FLAGGED_PREFIXES)


def log(msg: str) -> None:
    print(msg, flush=True)


def newest_aab(explicit: str | None) -> str | None:
    if explicit:
        p = os.path.abspath(os.path.expanduser(explicit))
        return p if os.path.isfile(p) else None
    pats = glob.glob(os.path.join(REPO_DIR, "apks", "*", "CLIBuild", "*.aab"))
    if not pats:
        return None
    return max(pats, key=os.path.getmtime)


def read_sidecar(aab: str) -> dict:
    p = os.path.splitext(aab)[0] + ".json"
    try:
        with open(p, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return {}


def probe_version_code(aab: str, sidecar: dict) -> int | None:
    for key in ("versionCode", "version_code", "bundleVersionCode"):
        v = sidecar.get(key)
        try:
            if v is not None:
                return int(v)
        except (TypeError, ValueError):
            pass
    try:
        sys.path.insert(0, BASE_DIR)
        import play_upload as pu  # noqa: PLC0415
        return pu.read_aab_version_code(__import__("pathlib").Path(aab), None)
    except Exception:  # noqa: BLE001
        return None


# --------------------------------------------------------------------------- #
# 1) Play 轨道现状
# --------------------------------------------------------------------------- #
def play_track_status():
    """返回 ([(track, desc), ...], err)。失败时列表为 None。"""
    sys.path.insert(0, BASE_DIR)
    try:
        import play_upload as pu  # noqa: PLC0415
    except Exception as e:  # noqa: BLE001
        return None, f"无法导入 play_upload：{type(e).__name__}: {e}"

    sa = SERVICE_ACCOUNT if os.path.isfile(SERVICE_ACCOUNT) else None
    try:
        sa_path = pu.resolve_service_account(sa)
        service = pu.build_service(sa_path)
        edit = service.edits().insert(body={}, packageName=PKG).execute()
        edit_id = edit["id"]
    except Exception as e:  # noqa: BLE001
        return None, f"Play 认证 / 建 edit 失败：{type(e).__name__}: {e}"

    try:
        resp = service.edits().tracks().list(packageName=PKG, editId=edit_id).execute()
        rows = []
        for t in resp.get("tracks", []):
            rels = t.get("releases", [])
            desc = "; ".join(
                f"{r.get('status')} v{','.join(r.get('versionCodes', []))}" for r in rels
            ) or "(空)"
            rows.append((t.get("track", "?"), desc))
        order = {"production": 0, "beta": 1, "alpha": 2, "internal": 3}
        rows.sort(key=lambda r: order.get(r[0], 9))
        return rows, None
    except Exception as e:  # noqa: BLE001
        return None, f"列轨道失败：{type(e).__name__}: {e}"
    finally:
        try:
            service.edits().delete(packageName=PKG, editId=edit_id).execute()
        except Exception:  # noqa: BLE001
            pass


# --------------------------------------------------------------------------- #
# 2) 16KB 两层取证
# --------------------------------------------------------------------------- #
def run_cmd(cmd: list[str], timeout: int = 240):
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.returncode, (p.stdout or ""), (p.stderr or "")
    except Exception as e:  # noqa: BLE001
        return 1, "", f"{type(e).__name__}: {e}"


def check_elf_alignment(aab: str):
    """门槛1。返回 (summary, ok, tail_lines)。ok=None 表示无法判定。"""
    script = os.path.join(TOOLS_DIR, "verify_16k.py")
    if not os.path.isfile(script):
        return None, None, [f"找不到取证脚本：{script}"]
    rc, out, err = run_cmd([PYTHON, script, aab])
    txt = out + err
    m = re.search(r"SUMMARY:\s*(\d+)\s*ELF checked,\s*(\d+)\s*non-compliant", txt)
    if not m:
        return None, None, [ln for ln in txt.strip().splitlines() if ln.strip()][-6:]
    total, bad = int(m.group(1)), int(m.group(2))
    return f"{total} ELF checked, {bad} non-compliant", (bad == 0), []


def check_ndk_provenance(aab: str):
    """门槛2。返回 (rows, err)，rows = [(name, ndk, verdict)]，verdict ∈ stale/unknown/ok。"""
    script = os.path.join(TOOLS_DIR, "so_meta.py")
    if not os.path.isfile(script):
        return [], f"找不到取证脚本：{script}"

    rows: list[tuple[str, str, str]] = []
    with tempfile.TemporaryDirectory() as td:
        try:
            with zipfile.ZipFile(aab) as z:
                members = [
                    n for n in z.namelist()
                    if f"lib/{ARCH}/" in n and n.endswith(".so")
                ]
                if not members:
                    return [], f"AAB 内未找到 lib/{ARCH}/*.so"
                z.extractall(td, members=members)
        except Exception as e:  # noqa: BLE001
            return [], f"解包 AAB 失败：{type(e).__name__}: {e}"

        for m in sorted(members):
            name = os.path.basename(m)
            rc, out, err = run_cmd([PYTHON, script, os.path.join(td, m)])
            txt = out + err
            # NDK 版本：只从以文件名开头的数据行取（帮助文本里也含 r28 字样）
            ndk = "—"
            for line in txt.splitlines():
                if line.startswith(name):
                    parts = line.split()
                    if len(parts) >= 2:
                        ndk = parts[1]
                    break
            cnt = re.search(r"NDK < r28:\s*(\d+)\s+无法判定:\s*(\d+)", txt)
            if cnt:
                if int(cnt.group(1)) >= 1:
                    verdict = "stale"
                elif int(cnt.group(2)) >= 1:
                    verdict = "unknown"
                else:
                    verdict = "ok"
            elif "旧 NDK" in txt:
                verdict = "stale"
            elif "无法判定" in txt:
                verdict = "unknown"
            else:
                verdict = "ok"
            rows.append((name, ndk, verdict))

    order = {"stale": 0, "unknown": 1, "ok": 2}
    rows.sort(key=lambda r: (order.get(r[2], 3), r[0]))
    return rows, None


# --------------------------------------------------------------------------- #
# 3) 组装报告
# --------------------------------------------------------------------------- #
def load_state() -> dict:
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return {}


def save_state(aab: str, rows: list[tuple[str, str, str]], elf_summary: str | None) -> None:
    try:
        with open(STATE_FILE, "w", encoding="utf-8") as fh:
            json.dump(
                {
                    "checked_at": datetime.now().isoformat(timespec="seconds"),
                    "aab": os.path.basename(aab),
                    "elf": elf_summary,
                    "flagged": sorted([r[0] for r in rows if is_play_flagged(r[0]) and r[2] != "ok"]),
                },
                fh,
                ensure_ascii=False,
                indent=2,
            )
    except Exception:  # noqa: BLE001
        pass


def fix_note(name: str) -> str:
    for key, note in KNOWN_FIX_NOTES.items():
        if name.startswith(key):
            return note
    return ""


def build_report(aab, sidecar, vc, tracks, tracks_err, elf_summary, elf_ok, elf_tail, rows, ndk_err, prev):
    size_mb = os.path.getsize(aab) / 1024 / 1024
    ts = datetime.now().strftime("%Y-%m-%d %H:%M")
    L: list[str] = []
    L.append("【Play 16KB 合规巡检】TimeSpaceGirl1  (%s)" % PKG)
    L.append("时间: %s" % ts)
    L.append("AAB : %s" % os.path.relpath(aab, REPO_DIR))
    L.append("      体积 %.1f MB · versionCode %s" % (size_mb, vc if vc is not None else "未知"))
    L.append("")

    L.append("一、Play 轨道现状（只读查询）")
    if tracks:
        for t, desc in tracks:
            L.append("    %-11s %s" % (t, desc))
    else:
        L.append("    ⚠️ 查询失败：%s" % (tracks_err or "未知原因"))
    L.append("")

    L.append("二、门槛1 · ELF PT_LOAD 对齐（硬性要求，不达标会被拒）")
    if elf_ok is None:
        L.append("    ⚠️ 无法判定：")
        for ln in elf_tail:
            L.append("      %s" % ln)
    else:
        L.append("    %s  %s" % ("✅" if elf_ok else "🔴 回归", elf_summary))
    L.append("")

    L.append("三、门槛2 · 构建 NDK（Play「旧版 NDK 编译」告警点名的层）")
    if ndk_err:
        L.append("    ⚠️ %s" % ndk_err)
    else:
        L.append("    说明：Play 按【已知问题库清单】点名，NDK < r28 ≠ 一定被点名。")
        flagged = [r for r in rows if is_play_flagged(r[0])]
        others = [r for r in rows if not is_play_flagged(r[0]) and r[2] == "stale"]
        unknown_o = [r for r in rows if not is_play_flagged(r[0]) and r[2] == "unknown"]

        L.append("")
        L.append("    ⚠️ Play 会点名（才是要处理的）(%d):" % len(flagged))
        for name, ndk, verdict in flagged:
            tag = "" if verdict != "ok" else "  ✅ 已达标"
            extra = fix_note(name)
            L.append("        - %-38s %s%s%s" % (name, ndk, ("   ← " + extra) if extra else "", tag))
        if not flagged:
            L.append("        （无）")

        if others or unknown_o:
            L.append("")
            L.append("    ℹ️ 其余 NDK 偏旧但 Play 未点名（参照，无需处理）(%d):" % (len(others) + len(unknown_o)))
            for name, ndk, _ in others + unknown_o:
                L.append("        - %-38s %s" % (name, ndk))
        L.append("")
        L.append("    汇总: Play 点名 %d 个 · 阈值偏旧但未点名 %d 个 · 全库 %d 个"
                 % (len(flagged), len(others) + len(unknown_o), len(rows)))
    L.append("")

    # 与上次对比
    L.append("四、与上次对比（回答「问题还在不在」）")
    if not prev:
        L.append("    （首次运行，无基线）")
    else:
        cur = sorted([r[0] for r in rows if is_play_flagged(r[0]) and r[2] != "ok"])
        old = sorted(prev.get("flagged", []))
        if cur == old:
            L.append("    与上次（%s）**完全一致**：仍未解决 %d 个库。" % (prev.get("checked_at", "?")[:16], len(cur)))
        else:
            added = [x for x in cur if x not in old]
            removed = [x for x in old if x not in cur]
            if removed:
                L.append("    🎉 已消失：%s" % ", ".join(removed))
            if added:
                L.append("    🔴 新增：%s" % ", ".join(added))
            if not added and not removed:
                L.append("    无变化")
        if prev.get("elf") and elf_summary and prev["elf"] != elf_summary:
            L.append("    ⚠️ ELF 对齐结论变化：%s → %s" % (prev["elf"], elf_summary))
    L.append("")

    L.append("五、⚠️ 需人工核对（Play Console 无公开 API）")
    L.append("    路径: Play Console → 发布 → App Bundle 浏览器 → 选择版本 → 「支持的页大小」")
    L.append("    说明: 该告警按 Google【已知问题库清单】点名，**按库文件名**，不随 NDK 版本阈值变化。")
    L.append("          v64 实测: Firebase 12.8.0 → 12.10.1 后文件名变了，告警 5 个 → 2 个；")
    L.append("          剩下的 2 个（libnative-googlesignin / libtolua）已在 2026-10-12 修复。")
    L.append("    时限: 门槛2 在 2027-02-01 前只是警告、不阻断发布；门槛1 为硬性要求且已达标。")
    return "\n".join(L)


def decide(aab, vc, tracks, elf_ok, rows):
    """返回 (退出码, 前缀, 摘要)。"""
    if elf_ok is False:
        return 1, "🔴", "门槛1 出现未对齐 .so（回归）"
    flagged = [r for r in rows if is_play_flagged(r[0]) and r[2] != "ok"]
    prod = next((d for t, d in (tracks or []) if t == "production"), "(未知)")
    base = "对齐 %s · production %s" % ("全过" if elf_ok else "待查", prod)
    if flagged:
        return 0, "⚠️", "%s · 门槛2 仍 %d 个库待上游" % (base, len(flagged))
    return 0, "✅", base


# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description="Play 16KB 页大小合规巡检 → 邮件")
    ap.add_argument("--aab", default=None, help="AAB 路径（默认取 apks/ 下最新）")
    ap.add_argument("--dry-run", action="store_true", help="只打印报告，不发邮件、不写状态")
    ap.add_argument("--no-mail", action="store_true", help="不发邮件（写状态）")
    ap.add_argument("--to", default=None, help="覆盖收件人")
    args = ap.parse_args()

    aab = newest_aab(args.aab)
    if not aab:
        log("[ERROR] 找不到 AAB（apks/*/CLIBuild/*.aab）")
        return 2
    log("[env] AAB   : %s" % aab)
    log("[env] tools : %s" % TOOLS_DIR)

    sidecar = read_sidecar(aab)
    vc = probe_version_code(aab, sidecar)

    tracks, tracks_err = play_track_status()
    log("[play] 轨道查询: %s" % ("OK" if tracks else "失败 - %s" % tracks_err))

    elf_summary, elf_ok, elf_tail = check_elf_alignment(aab)
    log("[16k ] 门槛1: %s" % (elf_summary or "无法判定"))

    rows, ndk_err = check_ndk_provenance(aab)
    log("[16k ] 门槛2: %d 库（stale=%d unknown=%d ok=%d）" % (
        len(rows),
        sum(1 for r in rows if r[2] == "stale"),
        sum(1 for r in rows if r[2] == "unknown"),
        sum(1 for r in rows if r[2] == "ok"),
    ))
    log("")

    prev = load_state()
    body = build_report(aab, sidecar, vc, tracks, tracks_err, elf_summary, elf_ok, elf_tail, rows, ndk_err, prev)
    print(body)

    rc, prefix, summary = decide(aab, vc, tracks, elf_ok, rows)

    if args.dry_run:
        log("\n[dry-run] 未发邮件、未写状态。")
        return rc

    save_state(aab, rows, elf_summary)

    if args.no_mail:
        log("\n[mail] 已跳过（--no-mail）")
        return rc

    try:
        sys.path.insert(0, BASE_DIR)
        import server_health_check as shc  # noqa: PLC0415
        subject = "[Play 16KB] %s %s" % (prefix, summary)
        ok, msg = shc.send_email(subject, body, args.to)
        log("\n[mail] %s" % msg)
        if not ok:
            return 2
    except Exception as e:  # noqa: BLE001
        log("\n[mail] 发送异常：%s: %s" % (type(e).__name__, e))
        return 2
    return rc


if __name__ == "__main__":
    sys.exit(main())
