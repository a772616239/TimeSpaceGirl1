#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""16:9 商店截图（1280×720）：**整幅底图 + 居中标题**（对标平台给的上架样例）。

为什么改成「整幅」
------------------
2026-10-29 用户贴了详情页样例：媒体位就是**一张 16:9 整幅插画、标题压正中**，
没有窗格、没有拼贴。之前的「角色 + 实机竖窗」拼贴版（`--style window`，保留在下面）
已经因为 blurring / black edges / solid colors and gradients 被驳回过一次。

三条硬约束（都是驳回逼出来的，别改回去）
----------------------------------------
1. **不许放大**。`bg_*.png` 原生 1920×1080。砍掉底部黑区后是 1920×842，
   按 16:9 裁成 1497×842 再缩到 1280×720 —— **0.86× 缩小**，全程不放大。
   这条路**不用真机截图**，所以不受「源图只有 598 宽」的限制。
2. **不许有黑边**。`bg_*.png` 底部 22% 是生成时留空的标题区（局部细节 0.1~3.0）。
   标题现在压画面正中，那块空区**直接裁掉**，画布四条边全是插画本身。
3. **不许拉伸**。先按目标比例裁、再等比缩放，全程没有非等比 resize。

只出 3 张：`bg_*.png` 里构图完整、角色不残缺、没有中文 UI 的就这三组。

用法
----
    python3 scripts/aso/fusion_shots169.py                    # 整幅版（默认）
    python3 scripts/aso/fusion_shots169.py --style window     # 旧的拼贴版
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aso_common as C  # noqa: E402
import aso_fusion as F  # noqa: E402

ORDER = ["0102", "2019", "0922"]

# 底图裁切：黑区上沿（占原图高）。0.78 是实测的 —— 0.78 以下局部细节掉到 3 以下。
BG_KEEP_H = 0.78
# 纵向起点：默认贴顶，个别底图顶部是「无云夜空」这种超平滑渐变（局部细节 <3，
# 缩到 1280 后就是一条暗带，和黑边同罪），往下挪一点把云/月亮带进画面。
# 2019 实测：y0=0 顶部细节 6.7、y0=0.05 升到 9.9，底部仍留 10.9（黑区在 0.84 以下）。
BG_TOP = {"0102": 0.00, "2019": 0.05, "0922": 0.00}

# 文字层（全部是画布比例）
CREAM = (243, 235, 214)
FONT_TITLE = "/System/Library/Fonts/Supplemental/Didot.ttc"
FONT_KICKER = "/System/Library/Fonts/Supplemental/Copperplate.ttc"
KICKER_Y = 0.432
KICKER_SIZE = 0.034
TITLE_Y = 0.474
TITLE_SIZE = 0.106
TITLE_MAXW = 0.60
RULE_Y = 0.628
RULE_HALF = 0.155


# ---------------------------------------------------------------- 文案
def _copy(tag: str, locale: str) -> tuple[str, str]:
    for p in (C.load_json(C.ASSETS_DIR / "fusion_pairs.json").get("pairs") or []):
        if str(p.get("tag")) == tag:
            c = (p.get("copy") or {}).get(locale) or {}
            k, t = c.get("kicker") or "", c.get("title") or ""
            return (k.upper(), t.upper()) if locale.startswith("en") else (k, t)
    raise SystemExit(f"fusion_pairs.json 里没有 tag={tag}")


def _font(path: str, size: int, index: int = 0):
    return ImageFont.truetype(path, size, index=index)


# ---------------------------------------------------------------- 整幅版
def bleed_base(tag: str, size: tuple[int, int]) -> tuple[Image.Image, float]:
    """底图 → 16:9 整幅。返回 (图, 缩放比)；<1 表示缩小（不放大）。"""
    W, H = size
    bg = Image.open(C.ROOT / f"data_aso/assets/gen/fusion/bg_{tag}.png").convert("RGB")
    w, h = bg.size
    keep_h = int(h * BG_KEEP_H)          # 砍掉底部留空的黑区
    y0 = int(h * BG_TOP.get(tag, 0.0))
    crop_w = int(keep_h * W / H)         # 按目标比例算宽度（等比，不拉伸）
    x0 = (w - crop_w) // 2
    return bg.crop((x0, y0, x0 + crop_w, y0 + keep_h)).resize((W, H), Image.LANCZOS), W / crop_w


def _tracked(d, text: str, f, tracking: float) -> float:
    return sum(d.textlength(ch, font=f) for ch in text) + tracking * max(0, len(text) - 1)


def draw_center_title(canvas: Image.Image, kicker: str, title: str) -> None:
    """居中标题：字距小标 + 衬线大标 + 菱形分隔线，垫一层柔和黑影。

    字体用 Didot / Copperplate 而不是 Arial Bold：样例是「奇幻 / 古典」的调子，
    无衬线大写压在插画上会像广告贴纸。
    """
    W, H = canvas.size
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)

    if kicker:
        ks = int(H * KICKER_SIZE)
        kf = _font(FONT_KICKER, ks, 2)
        tr = ks * 0.34
        kw = _tracked(d, kicker, kf, tr)
        x = (W - kw) / 2
        for ch in kicker:
            d.text((x, int(H * KICKER_Y)), ch, font=kf, fill=CREAM + (255,))
            x += d.textlength(ch, font=kf) + tr

    if title:
        size, floor = int(H * TITLE_SIZE), int(H * 0.05)
        while size > floor:
            tf = _font(FONT_TITLE, size, 1)
            if d.textlength(title, font=tf) <= W * TITLE_MAXW:
                break
            size -= 2
        tf = _font(FONT_TITLE, size, 1)
        tw = d.textlength(title, font=tf)
        d.text(((W - tw) / 2, int(H * TITLE_Y)), title, font=tf, fill=CREAM + (255,))

    oy = int(H * RULE_Y)
    half = int(W * RULE_HALF)
    d.line([(W / 2 - half, oy), (W / 2 - 16, oy)], fill=CREAM + (190,), width=2)
    d.line([(W / 2 + 16, oy), (W / 2 + half, oy)], fill=CREAM + (190,), width=2)
    d.polygon([(W / 2, oy - 7), (W / 2 + 7, oy), (W / 2, oy + 7), (W / 2 - 7, oy)],
              fill=CREAM + (225,))

    # 阴影只对文字 alpha 做模糊，不是给整张图铺渐变
    alpha = lay.split()[3].filter(ImageFilter.GaussianBlur(max(3, H * 0.010)))
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 205), (0, int(H * 0.004)), alpha)
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(lay)


def build_bleed(tag: str, locale: str, size: tuple[int, int]) -> tuple[Image.Image, dict]:
    base, scale = bleed_base(tag, size)
    canvas = base.convert("RGBA")
    kicker, title = _copy(tag, locale)
    draw_center_title(canvas, kicker, title)
    return canvas.convert("RGB"), {"source_px": int(size[0] / scale), "scale": round(scale, 3)}


# ---------------------------------------------------------------- 旧拼贴版（保留）
BATTLE_CROP = {
    0: (0.160, 0.620),   # 工厂 7x7 网格，598×1296
    1: (0.045, 0.445),   # 红 BOSS 战，720×1280（下方 0.47~0.72 是大片纯紫）
    2: (0.160, 0.620),   # 机械关双线交火，597×1299
}
WIN_X0, WIN_X1, WIN_Y0, WIN_Y1 = 0.28, 0.72, 0.40, 1.03
W_KICKER_Y, W_TITLE_Y, W_TITLE_MAXW = 0.026, 0.060, 0.44
W_TITLE_LINES = {
    "0102": ["7X7.", "POSITION WINS."],
    "2019": ["PLAN BEFORE", "YOU PUSH"],
    "0922": ["BOTH LINES", "MOVE UP"],
}


def _shot_of(tag: str) -> int:
    for p in (C.load_json(C.ASSETS_DIR / "fusion_pairs.json").get("pairs") or []):
        if str(p.get("tag")) == tag:
            return int((p.get("screen") or {}).get("shot") or 0)
    raise SystemExit(f"fusion_pairs.json 里没有 tag={tag}")


def extend_floor(im: Image.Image) -> Image.Image:
    """把底图底部纯黑换成「湿地面反射」（只给旧拼贴版用）。

    等高翻转 ⇒ 不拉伸；亮度 0.95→0.42 衰减 ⇒ 接缝没有硬线；只糊 2.5px ⇒ 不算明显模糊。
    """
    W, H = im.size
    y1 = int(H * 0.78)
    band_h = H - y1
    band = im.crop((0, y1 - band_h, W, y1)).transpose(Image.FLIP_TOP_BOTTOM)
    ramp = np.linspace(0.95, 0.42, band_h, dtype=np.float32)[:, None, None]
    arr = np.asarray(band, np.float32) * ramp
    band = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    band = band.filter(ImageFilter.GaussianBlur(2.5))
    out = im.copy()
    out.paste(band, (0, y1))
    return out


def build_window(tag: str, locale: str, size: tuple[int, int]) -> tuple[Image.Image, dict]:
    W, H = size
    idx = _shot_of(tag)
    item = (C.load_json(C.ASSETS_DIR / "shots.json").get("shots") or [])[idx]
    src = Image.open(C.ROOT / item["src"]).convert("RGB")
    top, bot = BATTLE_CROP[idx]
    shot = src.crop((0, int(src.height * top), src.width, int(src.height * bot)))

    bg = Image.open(C.ROOT / f"data_aso/assets/gen/fusion/bg_{tag}.png").convert("RGB")
    canvas = extend_floor(bg).resize((W, H), Image.LANCZOS).convert("RGBA")
    box = (int(W * WIN_X0), int(H * WIN_Y0), int(W * WIN_X1), int(H * WIN_Y1))
    canvas = F.draw_screen(canvas, box, 0, int(round(0.010 * W)), (255, 201, 120),
                           0.5, None, 0.5, 1.0, None, 1.06, shot_img=shot)

    kicker, _ = _copy(tag, locale)
    lines = W_TITLE_LINES[tag]
    maxw = W * W_TITLE_MAXW
    d = ImageDraw.Draw(canvas)
    size_px, floor = int(H * 0.118), int(H * 0.062)
    while size_px > floor:
        f = F.font_for(locale, size_px)
        if all(d.textlength(ln, font=f) <= maxw for ln in lines):
            break
        size_px -= 2
    y = W_TITLE_Y
    for i, ln in enumerate(lines):
        F.draw_caption(canvas, kicker if i == 0 else "", ln, locale, 1.05,
                       W_KICKER_Y, y, (255, 201, 120),
                       title_ratio=size_px / H, max_w_ratio=W_TITLE_MAXW)
        y += size_px * 1.14 / H
    return canvas.convert("RGB"), {"source_px": shot.width,
                                   "scale": round((W * (WIN_X1 - WIN_X0)) / shot.width, 3)}


# ---------------------------------------------------------------- 验收
def _detail(b: np.ndarray) -> float:
    bl = np.asarray(Image.fromarray(b.astype(np.uint8))
                    .filter(ImageFilter.GaussianBlur(6)), np.float32)
    return float(np.abs(b - bl).mean())


def audit(im: Image.Image, meta: dict) -> dict:
    """验收驳回的五条。拉伸/压缩由构造保证（等比裁切 + PNG 无损），其余实测。

    🔴 黑边必须**分四边 + 两个下角**测，不能只测整块平均值：
    2026-10-29 第一版就是被平均值掩盖过去、被用户当场看出来的。
    """
    a = np.asarray(im.convert("L"), np.float32)
    H, W = a.shape
    zones = {
        "top": a[:int(H * 0.04)],
        "bottom": a[int(H * 0.96):],
        "left": a[:, :int(W * 0.04)],
        "right": a[:, int(W * 0.96):],
        "bot_left": a[int(H * 0.90):, :int(W * 0.22)],
        "bot_right": a[int(H * 0.90):, int(W * 0.78):],
    }
    rec = dict(meta)
    for k, b in zones.items():
        rec[f"detail_{k}"] = round(_detail(b), 2)
    rec["min_edge_detail"] = round(min(v for k, v in rec.items()
                                       if k.startswith("detail_")), 2)
    bl = np.asarray(im.convert("L").filter(ImageFilter.GaussianBlur(3)), np.float32)
    rec["flat_pct"] = round(float((np.abs(a - bl) < 2.0).mean() * 100), 1)
    return rec


def main() -> int:
    ap = argparse.ArgumentParser(description="16:9 商店截图")
    ap.add_argument("--tags", default=",".join(ORDER))
    ap.add_argument("--locale", default="en-US")
    ap.add_argument("--size", default="1280x720")
    ap.add_argument("--style", default="bleed", choices=["bleed", "window"])
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    W, H = (int(x) for x in a.size.lower().split("x"))
    if abs(W / H - 16 / 9) > 0.01:
        print(f"🔴 画布必须是 16:9，当前 {W}x{H}（{W/H:.3f}）")
        return 2

    out = a.out or f"data_aso/derived/B/shots169{'' if a.style == 'bleed' else '_window'}"
    root = C.ROOT / out
    root.mkdir(parents=True, exist_ok=True)
    manifest = {"canvas": [W, H], "ratio": round(W / H, 4), "locale": a.locale,
                "style": a.style, "shots": []}
    build = build_bleed if a.style == "bleed" else build_window

    bad = 0
    for i, tag in enumerate([t.strip() for t in a.tags.split(",") if t.strip()], 1):
        im, meta = build(tag, a.locale, (W, H))
        p = root / f"{i:02d}_{tag}.png"
        im.save(p, optimize=True)
        rec = audit(im, meta)
        rec.update({"order": i, "tag": tag, "file": str(p.relative_to(C.ROOT)),
                    "bytes": p.stat().st_size,
                    "sha1": hashlib.sha1(p.read_bytes()).hexdigest()})
        manifest["shots"].append(rec)

        flag = ""
        if rec["scale"] > 1.02:
            flag += " 🔴放大"
            bad += 1
        if rec["min_edge_detail"] < 4:
            flag += " 🔴边上有黑边"
            bad += 1
        if rec["flat_pct"] > 45:
            flag += " 🔴纯色/渐变过多"
            bad += 1
        print(f"{rec['file']}  {W}x{H}  {rec['bytes']/1024:.0f} KB  "
              f"{rec['scale']:.2f}×  最小边细节 {rec['min_edge_detail']:.1f}  "
              f"平坦像素 {rec['flat_pct']:.1f}%{flag}")

    (root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"\n共 {len(manifest['shots'])} 张 → {root.relative_to(C.ROOT)}")
    if bad:
        print(f"🔴 {bad} 处不合规，别上传")
        return 3
    print("✅ 不放大、四边有细节、无明显纯色块")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
