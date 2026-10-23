#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把「缺的图」交给 TS-Art-Restyle 画，再把成品收回店面派生目录。

三段式，各自可单独跑
--------------------
    plan     盘点还缺什么图（本地化置顶图 / 换风格的截图底图），出需求单
    trigger  以表单字段触发 TS-Art-Restyle（🔴 不能用 json=，参数会全取默认）
    ingest   把出好的图收进 data_aso/derived/<变体>/<语言>/ 并归一到 1024×500

为什么不让本 job 自己画
------------------------
生图有额度、会换号、可能要人眼过。TS-Art-Restyle 已经有完整的出图/去水印/验收/换号链
（含浏览器租约），店面迭代 job 只负责「要什么图」+「收回来的图怎么归位」——
两条流水线各管各的，谁卡住都不拖累对方。

前置：TS-Art-Restyle 的 ASSET 是**相对工程根**的路径（`restyle_pipeline.cmd_prepare`
就是 `ROOT / args.asset`），所以 `时空美少女物料/...` 这种商店物料可以直接喂，
不必先塞进 Assets/。目标尺寸取该图自身尺寸 ⇒ 想要 1024×500 就用 1024×500 的种子图。
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aso_common as C  # noqa: E402
import aso_assets as A  # noqa: E402

CREDS = Path.home() / ".jenkins" / ".qclaw-creds"
JOB = "TS-Art-Restyle"
REQ_DIR = C.ASO_ROOT / "reports" / "art_requests"


# --------------------------------------------------------------------------- #
# plan
# --------------------------------------------------------------------------- #
def cmd_plan(args) -> int:
    spec = A.load_spec()
    derived = C.DERIVED_DIR / args.variant
    missing = []
    for loc in C.parse_locales(args.locales):
        feat = derived / loc / "feature_01.png"
        src_hint = (spec.get("feature") or {}).get(loc) or ""
        if not feat.is_file() or not src_hint:
            missing.append({
                "locale": loc,
                "kind": "featureGraphic",
                "size": "1024x500",
                "seed": src_hint or (spec.get("feature") or {}).get("zh-CN", ""),
                "why": f"{loc} 没有本地化置顶图，现在沿用 zh-CN 版",
            })
    for loc in C.parse_locales(args.locales):
        if not list((derived / loc).glob("shot_*.png")):
            missing.append({"locale": loc, "kind": "phoneScreenshots", "size": "1080x1920",
                            "seed": "", "why": "还没有竖版截图，先跑 aso_assets.py build"})

    req = {
        "created": datetime.now().isoformat(timespec="seconds"),
        "variant": args.variant,
        "theme": args.theme,
        "provider": args.provider,
        "requests": missing,
        "how": [
            f"python3 scripts/aso/aso_art.py trigger --variant {args.variant} "
            f"--theme {args.theme} --provider {args.provider} "
            f"--locale <语言> --asset '<需求单里的 seed>'",
            "TS-Art-Restyle 跑完后，用 ingest 把 outputs 里的成品收回：",
            "python3 scripts/aso/aso_art.py ingest --variant "
            f"{args.variant} --locale <语言> --gen <成品.png>",
        ],
    }
    REQ_DIR.mkdir(parents=True, exist_ok=True)
    out = REQ_DIR / f"{args.variant}-{datetime.now():%Y%m%d-%H%M%S}.json"
    out.write_text(json.dumps(req, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if not missing:
        print("[plan] 四语素材齐全，没有要画的图")
        return 0
    print(f"[plan] 缺 {len(missing)} 项 → {out}")
    for m in missing:
        print(f"  - {m['locale']:6} {m['kind']:16} {m['size']:10} seed={Path(m['seed']).name or '(无)'}")
        print(f"      {m['why']}")
    print("\n  下一步：aso_art.py trigger … 见需求单里的 how")
    return 0


# --------------------------------------------------------------------------- #
# trigger
# --------------------------------------------------------------------------- #
def _creds() -> tuple[str, str, str]:
    if not CREDS.is_file():
        raise SystemExit(f"没有 Jenkins 凭据：{CREDS}")
    vals = {}
    for line in CREDS.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.strip().startswith("#"):
            k, _, v = line.partition("=")
            vals[k.strip()] = v.strip()
    return (vals.get("JENKINS_URL", "http://localhost:8080"),
            vals.get("JENKINS_USER", ""), vals.get("JENKINS_TOKEN", ""))


def cmd_trigger(args) -> int:
    url, user, token = _creds()
    owner = os.environ.get("TSG_LEASE_OWNER") or f"ASO-{datetime.now():%Y%m%d-%H%M%S}"
    form = {
        "ASSET": args.asset,
        "THEME": args.theme,
        "PROVIDER": args.provider,
        "COMPOSITION": args.composition,
        "WRITE_BACK": "false",            # 🔴 商店图绝不写回工程资源
        "WATERMARK": args.watermark,
        "TSG_LEASE_OWNER": owner,         # 并行租约必须能认出自己人
    }
    if args.layout:
        form["LAYOUT"] = args.layout
    if args.outfit:
        form["OUTFIT"] = args.outfit
    if args.cdp_port:
        form["CDP_PORT"] = args.cdp_port

    cmd = ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code}",
           "-X", "POST", f"{url}/job/{JOB}/buildWithParameters",
           "-u", f"{user}:{token}"]
    for k, v in form.items():
        cmd += ["--data-urlencode", f"{k}={v}"]

    print(f"[trigger] {JOB}  租约 owner={owner}")
    for k, v in form.items():
        print(f"   {k} = {v[:110]}")
    if args.dry_run:
        print("\n[dry-run] 未发起请求。去掉 --dry-run 即触发。")
        return 0

    r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    code = (r.stdout or "").strip()
    if code in ("200", "201"):
        print(f"[trigger] 已排队（HTTP {code}）。产物会落在 _output/art_restyle/…")
        return 0
    print(f"[trigger] 失败 HTTP {code}  {r.stderr.strip()[:300]}")
    if code == "403":
        print("  403 一般是：Jenkins 用户权限 / job 名不对 / 需要 crumb")
    return 4


# --------------------------------------------------------------------------- #
# ingest
# --------------------------------------------------------------------------- #
def cmd_ingest(args) -> int:
    src = Path(args.gen).expanduser().resolve()
    if not src.is_file():
        print(f"成品不存在：{src}")
        return 2
    from PIL import Image
    dst_dir = C.DERIVED_DIR / args.variant / args.locale
    dst_dir.mkdir(parents=True, exist_ok=True)
    if args.kind == "feature":
        size = C.FEATURE_SIZE
        dst = dst_dir / "feature_01.png"
    else:
        raise SystemExit("目前只收 feature 图；截图请改 shots.json 后跑 aso_assets.py build")
    im = A.cover_resize(Image.open(src).convert("RGB"), size, 0.5)
    im.save(dst, "PNG", optimize=True)
    print(f"[ingest] {src.name} → {dst}  {im.size}  {dst.stat().st_size // 1024} KB")
    rc = A.cmd_check(argparse.Namespace(variant=args.variant, strict=False))
    return rc


def main() -> int:
    ap = argparse.ArgumentParser(description="缺图盘点 / 触发 TS-Art-Restyle / 回收成品")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("plan")
    p.add_argument("--variant", required=True)
    p.add_argument("--locales", default="")
    p.add_argument("--theme", default="cyber")
    p.add_argument("--provider", default="chatgpt_web")
    p.set_defaults(func=cmd_plan)

    p = sub.add_parser("trigger")
    p.add_argument("--variant", default="B")
    p.add_argument("--locale", default="")
    p.add_argument("--asset", required=True, help="种子图（相对工程根，1024x500 的商店物料即可）")
    p.add_argument("--theme", default="cyber")
    p.add_argument("--provider", choices=["chatgpt_web", "manual"], default="chatgpt_web")
    p.add_argument("--composition", choices=["lock", "free", "design"], default="lock")
    p.add_argument("--watermark", choices=["auto", "off", "force"], default="auto")
    p.add_argument("--layout", default="", help="构图锁：保住原有文案与 UI 空区")
    p.add_argument("--outfit", default="")
    p.add_argument("--cdp-port", default="")
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(func=cmd_trigger)

    p = sub.add_parser("ingest")
    p.add_argument("--variant", required=True)
    p.add_argument("--locale", required=True)
    p.add_argument("--gen", required=True)
    p.add_argument("--kind", choices=["feature"], default="feature")
    p.set_defaults(func=cmd_ingest)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
