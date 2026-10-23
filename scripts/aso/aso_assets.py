#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""店面素材派生：竖版截图（1080×1920）+ 置顶大图（1024×500）。

    aso_assets.py fetch  --locales en-US,ja-JP          # 把线上原图抓下来当基线
    aso_assets.py build  --variant B                    # 按 data_aso/assets/shots.json 派生
    aso_assets.py check  --variant B                    # Play 规格体检
    aso_assets.py preview --variant B                   # 拼一张 contact sheet（人眼验收用）

为什么不是「换皮」而是「派生」
------------------------------
线上截图是 **1920×1080 横版**，而这游戏是**竖版**（ProjectSettings defaultScreenOrientation=0，
只允许 Portrait）。横版截图在手机商店页会被压成两条黑边的小图 —— 首图面积浪费一半。
所以这里做的是：竖版源图 → 裁掉底部世界聊天 → 归一到 9:16 → 叠一条卖点条。
真要重画（换皮/换风格），走 `aso_art.py` → TS-Art-Restyle，不在这一步做。

`--strict` 会让「源图放大超过 1.6 倍」变成阻断（默认只是标黄）。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aso_common as C  # noqa: E402

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:  # pragma: no cover
    sys.stderr.write("缺 Pillow：<venv>/bin/pip install pillow\n")
    sys.exit(2)

SHOT_SPEC = C.ASSETS_DIR / "shots.json"
MAX_UPSCALE = 1.6          # 超过就标黄（1.6 倍以上 LANCZOS 也开始发糊）
PLAY_MAX_BYTES = 8 * 1024 * 1024   # Play 单张图片上限 8 MB


# --------------------------------------------------------------------------- #
# 通用
# --------------------------------------------------------------------------- #
def sha1_of(p: Path) -> str:
    h = hashlib.sha1()
    h.update(p.read_bytes())
    return h.hexdigest()


def load_spec() -> dict:
    if not SHOT_SPEC.is_file():
        raise SystemExit(f"缺少素材清单：{SHOT_SPEC}")
    return C.load_json(SHOT_SPEC)


def font_for(locale: str, size: int):
    for f in C.LOCALES[locale]["fonts"]:
        if Path(f).is_file():
            try:
                return ImageFont.truetype(f, size), f
            except Exception:  # noqa: BLE001
                continue
    return ImageFont.load_default(), ""


def _fit_font(locale: str, text: str, max_w: int, start: int = 66, floor: int = 30):
    """二分/递减到能塞进一行的字号。"""
    size = start
    while size > floor:
        f, path = font_for(locale, size)
        box = f.getbbox(text)
        if box[2] - box[0] <= max_w:
            return f, path, size
        size -= 4
    return font_for(locale, floor)[0], font_for(locale, floor)[1], floor


def cover_resize(im: Image.Image, size: tuple[int, int], focus_y: float) -> Image.Image:
    """等比放大到铺满，再按 focus_y 纵向裁切（0=顶，1=底）。绝不拉伸。"""
    tw, th = size
    sw, sh = im.size
    scale = max(tw / sw, th / sh)
    nw, nh = max(tw, int(round(sw * scale))), max(th, int(round(sh * scale)))
    im = im.resize((nw, nh), Image.LANCZOS)
    left = (nw - tw) // 2
    top = int(round((nh - th) * min(max(focus_y, 0.0), 1.0)))
    top = max(0, min(top, nh - th))
    return im.crop((left, top, left + tw, top + th))


def pad_resize(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """等比装进去，空白用「自身放大模糊+压暗」填 —— 不裁内容，也不留死黑边。"""
    tw, th = size
    bg = cover_resize(im, size, 0.5).filter(ImageFilter.GaussianBlur(28))
    bg = Image.eval(bg, lambda v: int(v * 0.45))
    sw, sh = im.size
    scale = min(tw / sw, th / sh)
    fg = im.resize((max(1, int(sw * scale)), max(1, int(sh * scale))), Image.LANCZOS)
    bg.paste(fg, ((tw - fg.width) // 2, (th - fg.height) // 2))
    return bg


def compose_shot(src_im: Image.Image, size: tuple[int, int], caption: str,
                 locale: str, focus_y: float) -> tuple[Image.Image, int]:
    """截图画布 = 上方内容区 + 下方卖点条。

    🔴 一开始是把文字**叠在**画面上（渐变遮罩），实测很脏：这游戏的截图底部
    1/3 挂世界聊天，遮罩压不住，文字会和聊天行糊在一起。改成**预留一条实心条**：
    内容区先按 9:(16-band) 归一，再把卖点写在条里，画面一点不被挡。
    返回 (成品, 内容区高度)。
    """
    tw, th = size
    band_h = 0 if not caption else int(round(th * 0.22))
    content_h = th - band_h
    canvas = Image.new("RGB", (tw, th), (13, 11, 20))
    content = cover_resize(src_im, (tw, content_h), focus_y)
    canvas.paste(content, (0, 0))
    if band_h:
        band = Image.new("RGBA", (tw, band_h), (0, 0, 0, 0))
        d = ImageDraw.Draw(band)
        # 从内容底色过渡到深色，避免出现一条生硬的横切线
        for i in range(band_h):
            t = i / max(1, band_h - 1)
            a = int(255 * min(1.0, t * 2.4))
            d.line([(0, i), (tw, i)], fill=(13, 11, 20, a))
        canvas = canvas.convert("RGBA")
        canvas.alpha_composite(band, (0, content_h))
        f, _, _ = _fit_font(locale, caption, int(tw * 0.86))
        d = ImageDraw.Draw(canvas)
        box = d.textbbox((0, 0), caption, font=f)
        tw_, th_ = box[2] - box[0], box[3] - box[1]
        x = (tw - tw_) // 2 - box[0]
        y = content_h + (band_h - th_) // 2 - box[1]
        d.text((x, y), caption, font=f, fill=(255, 255, 255, 255))
        canvas = canvas.convert("RGB")
    return canvas, content_h


# --------------------------------------------------------------------------- #
# fetch：把线上原图抓下来
# --------------------------------------------------------------------------- #
def cmd_fetch(args) -> int:
    base = Path(args.online_dir) if args.online_dir else _latest_online()
    if not base:
        print("没有 data_aso/online/*/images.json，先跑 aso_play.py list")
        return 2
    images = C.load_json(base / "images.json")
    locales = C.parse_locales(args.locales)
    out_root = base / "assets"
    n = 0
    for loc in locales:
        if loc not in images:
            continue
        for itype, items in images[loc].items():
            if not isinstance(items, list):
                continue
            d = out_root / loc
            d.mkdir(parents=True, exist_ok=True)
            for i, img in enumerate(items):
                url = (img.get("url") or "") + "=w2400"
                if not img.get("url"):
                    continue
                fn = d / f"{'shot' if itype == 'phoneScreenshots' else 'feature'}_{i + 1:02d}.png"
                try:
                    raw = urllib.request.urlopen(url, timeout=45).read()
                    fn.write_bytes(raw)
                    with Image.open(fn) as im:
                        print(f"[fetch] {loc} {itype} #{i} → {fn.name} {im.size}")
                    n += 1
                except Exception as e:  # noqa: BLE001
                    print(f"[fetch] {loc} {itype} #{i} 失败：{e}")
    print(f"[fetch] 共 {n} 张，落在 {out_root}")
    return 0 if n else 1


def _latest_online() -> Path | None:
    if not C.ONLINE_DIR.is_dir():
        return None
    dirs = sorted([p for p in C.ONLINE_DIR.iterdir() if p.is_dir()], key=lambda p: p.name)
    for p in reversed(dirs):
        if (p / "images.json").is_file():
            return p
    return None


# --------------------------------------------------------------------------- #
# build
# --------------------------------------------------------------------------- #
def cmd_build(args) -> int:
    spec = load_spec()
    locales = C.parse_locales(args.locales)
    tw, th = _parse_size(args.size)
    out_root = C.DERIVED_DIR / args.variant
    notes: list[str] = []
    index: dict = {"variant": args.variant, "canvas": [tw, th], "locales": {}}

    for loc in locales:
        d = out_root / loc
        d.mkdir(parents=True, exist_ok=True)
        for old in d.glob("*.png"):
            old.unlink()
        entries = []
        for i, shot in enumerate(spec.get("shots", []), start=1):
            src = C.ROOT / shot["src"]
            if not src.is_file():
                notes.append(f"{loc}: 源图不存在 {shot['src']}")
                continue
            im = Image.open(src).convert("RGB")
            crop_bottom = float(shot.get("crop_bottom") or 0)
            if crop_bottom > 0:
                im = im.crop((0, 0, im.width, int(im.height * (1 - crop_bottom))))
            upscale = (tw / im.width)
            cap = "" if args.no_caption else (shot.get("captions", {}).get(loc) or "")
            out, content_h = compose_shot(im, (tw, th), cap, loc,
                                          float(shot.get("focus_y", 0.5)))
            if args.fit == "pad":
                # pad 模式：内容区整图装入（不裁），与 caption 条并存
                body = pad_resize(im, (tw, content_h))
                out = Image.new("RGB", (tw, th), (13, 11, 20))
                out.paste(body, (0, 0))
                if content_h < th:
                    band = compose_shot(im, (tw, th), cap, loc, 0.5)[0]
                    out.paste(band.crop((0, content_h, tw, th)), (0, content_h))
            fn = d / f"shot_{i:02d}.png"
            out.save(fn, "PNG", optimize=True)
            entries.append({"file": fn.name, "src": shot["src"], "size": list(out.size),
                            "upscale": round(upscale, 2), "caption": cap,
                            "bytes": fn.stat().st_size, "sha1": sha1_of(fn)})
            if upscale > MAX_UPSCALE:
                notes.append(f"{loc} {fn.name}: 源图 {im.width}px 放大到 {tw}px（{upscale:.1f}×），会发糊")

        # 置顶图
        feat_src = (spec.get("feature") or {}).get(loc) or ""
        fallback = False
        if not feat_src:
            feat_src = (spec.get("feature") or {}).get("zh-CN") or ""
            fallback = True
        if feat_src:
            p = C.ROOT / feat_src
            if p.is_file():
                fs = _parse_size(args.feature_size)
                out = cover_resize(Image.open(p).convert("RGB"), fs, 0.5)
                fn = d / "feature_01.png"
                out.save(fn, "PNG", optimize=True)
                entries.append({"file": fn.name, "src": feat_src, "size": list(out.size),
                                "bytes": fn.stat().st_size, "sha1": sha1_of(fn)})
                if fallback:
                    notes.append(f"{loc}: 没有本地化置顶图，沿用 zh-CN 版（应走 aso_art.py 重绘）")
            else:
                notes.append(f"{loc}: 置顶图源不存在 {feat_src}")
        index["locales"][loc] = entries

    (out_root / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    _write_preview(out_root, locales)

    print(f"[build] {out_root}  画布 {tw}×{th}  fit={args.fit}")
    for loc in locales:
        files = sorted((out_root / loc).glob("*.png"))
        print(f"  {loc}: {len(files)} 张  {[f.name for f in files]}")
    if notes:
        print("\n🟡 提醒：")
        for n in notes:
            print(f"   - {n}")
    return 0


def _parse_size(s: str) -> tuple[int, int]:
    w, _, h = s.lower().partition("x")
    try:
        return int(w), int(h)
    except ValueError:
        raise SystemExit(f"尺寸写法应是 1080x1920，收到：{s}")


def _write_preview(out_root: Path, locales: list[str]) -> None:
    """拼一张 HTML contact sheet：四个人眼一起看，别一张张点。"""
    rows = []
    for loc in locales:
        cells = "".join(
            f'<figure><img src="{loc}/{f.name}"><figcaption>{f.name}</figcaption></figure>'
            for f in sorted((out_root / loc).glob("*.png")))
        rows.append(f'<section><h2>{loc} · {C.LOCALES[loc]["label"]}</h2>'
                    f'<div class="row">{cells}</div></section>')
    html = f"""<!doctype html><meta charset="utf-8">
<title>店面素材 · {out_root.name}</title>
<style>
body{{background:#111216;color:#e8e8ef;font:14px/1.5 -apple-system,"PingFang SC",sans-serif;margin:24px}}
h2{{font-size:15px;color:#9aa0b4;margin:28px 0 10px;font-weight:600}}
.row{{display:flex;gap:12px;overflow-x:auto;padding-bottom:8px}}
figure{{margin:0;flex:0 0 auto}}
img{{height:360px;border-radius:8px;display:block;background:#000}}
figcaption{{font-size:11px;color:#7b8098;margin-top:6px}}
</style>
<h1 style="font-size:18px">店面素材派生 · {out_root.name}</h1>
{''.join(rows)}
"""
    (out_root / "preview.html").write_text(html, encoding="utf-8")


# --------------------------------------------------------------------------- #
# check
# --------------------------------------------------------------------------- #
def cmd_check(args) -> int:
    root = C.DERIVED_DIR / args.variant
    if not root.is_dir():
        print(f"没有派生结果：{root}（先跑 build）")
        return 2
    red, yellow = [], []
    total = 0
    for d in sorted(p for p in root.iterdir() if p.is_dir()):
        files = sorted(d.glob("*.png"))
        if not files:
            red.append(f"{d.name}: 一张图都没有")
            continue
        shots = [f for f in files if f.name.startswith("shot_")]
        feats = [f for f in files if f.name.startswith("feature_")]
        if len(shots) < 4:
            red.append(f"{d.name}: 手机截图 {len(shots)} 张，Play 至少 4 张才建议上首屏（2 张是硬下限）")
        if len(shots) > 8:
            yellow.append(f"{d.name}: 截图 {len(shots)} 张，Play 上限 8 张")
        if not feats:
            yellow.append(f"{d.name}: 没有置顶大图（Play 要求 1024×500）")
        for f in files:
            total += 1
            with Image.open(f) as im:
                w, h = im.size
                if f in feats:
                    if (w, h) != C.FEATURE_SIZE:
                        red.append(f"{f.parent.name}/{f.name}: 置顶图 {w}×{h}，必须 1024×500")
                else:
                    if min(w, h) < 320 or max(w, h) > 3840:
                        red.append(f"{f.parent.name}/{f.name}: {w}×{h} 超出 Play 的长宽区间")
                    ratio = max(w, h) / min(w, h)
                    if ratio > 2.0:
                        red.append(f"{f.parent.name}/{f.name}: 长宽比 {ratio:.2f} > 2.0，Play 会拒")
                    if abs(ratio - 16 / 9) > 0.02 and abs(ratio - 9 / 16) > 0.02:
                        yellow.append(f"{f.parent.name}/{f.name}: 比例 {ratio:.2f} 非 16:9/9:16")
            if f.stat().st_size > PLAY_MAX_BYTES:
                red.append(f"{f.parent.name}/{f.name}: {f.stat().st_size // 1024 // 1024} MB > 8 MB")
    print(f"[check] {total} 张图")
    for r in red:
        print(f"  🔴 {r}")
    for y in yellow:
        print(f"  🟡 {y}")
    if not red and not yellow:
        print("  ✅ 全部通过")
    if args.strict and red:
        return 1
    return 0 if not red else 1


def main() -> int:
    ap = argparse.ArgumentParser(description="店面素材派生与体检")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("fetch", help="下载线上原图当基线")
    p.add_argument("--locales", default="")
    p.add_argument("--online-dir", default="")
    p.set_defaults(func=cmd_fetch)

    p = sub.add_parser("build", help="派生竖版截图与置顶图")
    p.add_argument("--variant", required=True)
    p.add_argument("--locales", default="")
    p.add_argument("--size", default="1080x1920")
    p.add_argument("--feature-size", default="1024x500")
    p.add_argument("--fit", choices=["cover", "pad"], default="cover",
                   help="cover=铺满裁切（默认）；pad=整图装入+模糊补边")
    p.add_argument("--no-caption", action="store_true")
    p.set_defaults(func=cmd_build)

    p = sub.add_parser("check", help="Play 规格体检")
    p.add_argument("--variant", required=True)
    p.add_argument("--strict", action="store_true")
    p.set_defaults(func=cmd_check)

    p = sub.add_parser("preview", help="只看预览（不重建）")
    p.add_argument("--variant", required=True)
    p.set_defaults(func=lambda a: (print(C.DERIVED_DIR / a.variant / "preview.html"), 0)[1])

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
