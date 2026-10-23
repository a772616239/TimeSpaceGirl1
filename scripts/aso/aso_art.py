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
SEED_DIR = C.ASSETS_DIR / "seeds"
PROMO = C.ASSETS_DIR / "promo.json"


# --------------------------------------------------------------------------- #
# seed：给换皮管线造「构图种子」
# --------------------------------------------------------------------------- #
def _promo() -> dict:
    return C.load_json(PROMO) if PROMO.is_file() else {}


def cmd_seed(args) -> int:
    """造种子图。

    换皮管线的输出尺寸 = 种子图尺寸（`cover_resize` 归位到原图尺寸），
    所以要出 1080×1920 的竖版首图，种子本身就得是 1080×1920。
    宣传图是 1920×1080 的横版，直接喂进去只会得到横版 —— 于是这里先按
    「角色上半 + 游戏画面 inset + 底部留白放标题」拼一张竖版构图给模型当骨架。

    🔴 种子里**不能有字**：模型的 TEXT 段默认要求「保持每个字」，种子里有字它就会
    去描那行字（甚至自己编一句）。所以 crop 一律避开标题条，底部只留纯渐变。
    """
    import aso_assets as A
    from PIL import Image, ImageDraw

    spec = _promo()
    locales = C.parse_locales(args.locales)
    SEED_DIR.mkdir(parents=True, exist_ok=True)
    made = []

    for loc in locales:
        d = spec["locales"].get(loc)
        if not d:
            print(f"[seed] {loc} 没在 promo.json 里配置，跳过")
            continue
        src = C.ROOT / d["art1920"]
        art = Image.open(src).convert("RGB")

        if args.kind == "hero":
            tw, th = spec.get("heroOut", [1080, 1920])
            canvas = Image.new("RGB", (tw, th), (10, 9, 18))
            # 角色：裁左半边全身，铺满上 65%
            char = art.crop(tuple(d["charCrop"]))
            canvas.paste(A.cover_resize(char, (tw, int(th * 0.66)), 0.28), (0, 0))
            # 游戏画面：右下角嵌一块，给模型「有 UI 截图」的语义
            panel = art.crop(tuple(d["panelCrop"]))
            pw, ph = int(tw * 0.70), int(th * 0.22)
            canvas.paste(A.cover_resize(panel, (pw, ph), 0.5), (tw - pw - 40, int(th * 0.66) - 60))
            # 底部纯留白：标题位，绝不写字
            band = Image.new("RGBA", (tw, int(th * 0.30)), (0, 0, 0, 0))
            dd = ImageDraw.Draw(band)
            for i in range(band.height):
                a = int(255 * min(1.0, (i / max(1, band.height - 1)) * 1.6))
                dd.line([(0, i), (tw, i)], fill=(10, 9, 18, a))
            canvas = canvas.convert("RGBA")
            canvas.alpha_composite(band, (0, th - band.height))
            out = canvas.convert("RGB")
        else:  # feature
            tw, th = spec.get("featureOut", [1024, 500])
            crop = tuple(d.get("artCrop") or [0, 0, art.width, int(art.height * 0.70)])
            out = A.cover_resize(art.crop(crop), (tw, th), 0.5)

        fn = SEED_DIR / f"{args.kind}_{loc}_{out.width}x{out.height}.png"
        out.save(fn, "PNG", optimize=True)
        made.append(fn)
        print(f"[seed] {fn.relative_to(C.ROOT)}  {out.size}  {fn.stat().st_size // 1024} KB")

    if not made:
        return 2
    print("\n  下一步：aso_art.py trigger --asset <上面某个种子> --composition design --no-text-layout")
    return 0


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
    # 🔴 不要再往表单里塞 TSG_LEASE_OWNER：TS-Art-Restyle 的参数表里没有这个字段，
    #    Jenkins 会静默忽略，看起来"有租约"其实毫无隔离（2026-10-23 实测，#28~#32
    #    五个并发构建里 owner 全为空，02/03 因此拿到同一张回图）。
    #    并发隔离改由该 job 的 options.disableConcurrentBuilds() 负责。
    form = {
        "ASSET": args.asset,
        "THEME": args.theme,
        "PROVIDER": args.provider,
        "COMPOSITION": args.composition,
        "WRITE_BACK": "false",            # 🔴 商店图绝不写回工程资源
        "WATERMARK": args.watermark,
    }
    if args.layout:
        form["LAYOUT"] = args.layout
    if args.outfit:
        form["OUTFIT"] = args.outfit
    if getattr(args, "frame", ""):
        form["FRAME"] = args.frame
    if getattr(args, "alpha_mode", ""):
        form["ALPHA_MODE"] = args.alpha_mode
    # 🔴 PROMPT_OVERRIDE 走 job 里「整段替换提示词」的分支。路径必须在这里读成文本再塞进表单：
    #    job 只认 PROMPT_OVERRIDE 里的字面文本，传路径会被当成提示词原文粘进去。
    pf = getattr(args, "prompt_file", "") or ""
    if pf:
        p = Path(pf) if Path(pf).is_absolute() else C.ROOT / pf
        if not p.is_file():
            raise SystemExit(f"--prompt-file 不存在：{p}")
        form["PROMPT_OVERRIDE"] = p.read_text(encoding="utf-8").strip()
    if args.cdp_port:
        form["CDP_PORT"] = args.cdp_port

    cmd = ["curl", "-sS", "-D", "-", "-o", "/dev/null", "-w", "\nHTTP_CODE=%{http_code}",
           "-X", "POST", f"{url}/job/{JOB}/buildWithParameters",
           "-u", f"{user}:{token}"]
    for k, v in form.items():
        cmd += ["--data-urlencode", f"{k}={v}"]

    print(f"[trigger] {JOB}（串行由调用侧保证：加 --wait 才会等这一张跑完）")
    for k, v in form.items():
        print(f"   {k} = {v[:110]}")
    if args.dry_run:
        print("\n[dry-run] 未发起请求。去掉 --dry-run 即触发。")
        return 0

    r = subprocess.run(cmd, capture_output=True, text=True, timeout=90)
    head, _, tail = (r.stdout or "").rpartition("HTTP_CODE=")
    code = tail.strip()
    if code not in ("200", "201"):
        print(f"[trigger] 失败 HTTP {code}  {r.stderr.strip()[:300]}")
        if code == "403":
            print("  403 一般是：Jenkins 用户权限 / job 名不对 / 需要 crumb")
        return 4

    loc = ""
    for line in head.splitlines():
        if line.lower().startswith("location:"):
            loc = line.split(":", 1)[1].strip()
    print(f"[trigger] 已排队（HTTP {code}）。产物会落在 _output/art_restyle/…")

    if getattr(args, "wait", False) and loc:
        return _wait_build(url, user, token, loc)
    return 0


# --------------------------------------------------------------------------- #
# --wait：等这一张真的出完再返回
# --------------------------------------------------------------------------- #
_build_cache: dict = {}


def _wait_build(url: str, user: str, token: str, queue_loc: str) -> int:
    """🔴 并发隔离的唯一可靠防线（2026-10-23 实测）。

    为什么不靠 Jenkins 的 disableConcurrentBuilds：
    本机 Jenkins 2.568 在 `POST /job/<n>/config.xml` 时**静默丢弃**
    `<hudson.model.DisableConcurrentBuildsJobProperty/>`（HTTP 200，
    但 /api/json 的 property 里只剩 ParametersDefinitionProperty），
    Declarative `options { disableConcurrentBuilds() }` 也拦不住同时入队的构建。
    而 TS-Art-Restyle 的出图阶段独占「本机 Chrome 登录态 + inbox 目录」，
    并发就会串图：#28~#32 五个构建只差 5 秒，02 与 03 的 inbox/gen_web.png
    落在同一个 md5 上。⇒ 由调用侧一张一张地触发。
    """
    import time
    import urllib.request
    import base64

    auth = base64.b64encode(f"{user}:{token}".encode()).decode()
    base = url.rstrip("/")
    api = queue_loc.rstrip("/") + "/api/json"

    def get(u: str) -> dict:
        req = urllib.request.Request(u, headers={"Authorization": f"Basic {auth}"})
        with urllib.request.urlopen(req, timeout=20) as fh:
            return json.loads(fh.read().decode("utf-8"))

    print("[wait] 等它出队…")
    num = None
    deadline = time.time() + 1800
    while time.time() < deadline:
        try:
            it = get(api)
        except Exception as exc:
            print(f"[wait] 查询队列失败（{exc}），重试")
            time.sleep(5)
            continue
        ex = it.get("executable") or {}
        if ex.get("number"):
            num = ex["number"]
            break
        if it.get("cancelled"):
            print("[wait] 队列项已被取消")
            return 6
        time.sleep(3)

    if num is None:
        print("[wait] 超时：30 分钟还没出队")
        return 7

    print(f"[wait] 构建 #{num} 开跑，等它结束…")
    burl = f"{base}/job/{JOB}/{num}/api/json?tree=building,result"
    while time.time() < deadline:
        try:
            b = get(burl)
        except Exception:
            time.sleep(5)
            continue
        if not b.get("building"):
            res = b.get("result")
            print(f"[wait] 构建 #{num} 结束：{res}")
            return 0 if res == "SUCCESS" else (5 if res == "UNSTABLE" else 8)
        time.sleep(5)
    print("[wait] 超时：构建没在 30 分钟内结束")
    return 7


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

    p = sub.add_parser("seed", help="造换皮管线用的构图种子（竖版首图 / 无字置顶底图）")
    p.add_argument("--kind", choices=["hero", "feature"], required=True)
    p.add_argument("--locales", default="")
    p.set_defaults(func=cmd_seed)

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
    p.add_argument("--prompt-file", default="",
                   help="整段提示词文件（走 job 的 PROMPT_OVERRIDE，完全替换 theme_presets 拼出来的那段）。"
                        "用于「种子只当画布、画面全靠文字描述」的原创立绘，避免模板里的"
                        "『保持同一个角色身份』把新设计又拉回原图")
    p.add_argument("--frame", choices=["none", "auto", "card", "gold"], default="",
                   help="外框。design 构图下 job 的 FRAME=auto 会套游戏卡框，原创立绘要显式 none")
    p.add_argument("--alpha-mode", choices=["source", "keep", "free"], default="",
                   help="alpha 取法。空舞台种子是全幅不透明，原创立绘固定 keep")
    p.add_argument("--cdp-port", default="")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--wait", action="store_true",
                   help="触发后等这一张真的跑完再返回（串行出图必加：本 job 的 inbox 与 "
                        "浏览器登录态不隔离，并发会串图）")
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
