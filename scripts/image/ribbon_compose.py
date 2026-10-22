#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""细长彩带美术字横幅：确定性英文重排（不走模型、不烧额度、逐字节可回归）。

为什么需要它
------------
`ArtFont_zh/font/` 那批 512x256 特写横幅（HERO-SKILL + 中文技能名）走
`provider=chatgpt_web` 时，模型会把首/末字母画到彩带外，被 `postprocess_photo`
的 alpha lock 啃掉（实测连续 4 次：TEMPTATIO / REATH OF TEMPTATIO）。
单行 20 字符在 307px 实心区上物理不成立，两行能救，但仍是「抽卡」——每次出图
都可能把金色渐变画成平涂、把彩带画成箭头。这条链路需要一条确定性退路。

为什么不用魔棒抠掉中文字
------------------------
魔棒（flood-fill 容差）在这张图上分不开描边：中文是「金牌面 + 近黑厚描边」，
描边色与底板色只差 10~15，实测 **68.6% 的描边环被判成底板**，于是金色字被擦掉、
描边留成一圈「中文鬼影」；同时金字是被描边围死的孤岛，单点播种只覆盖带内 61%，
剩下 39% 是没被播种的底板碎片。抠不干净，也不需要抠干净 ——

    彩带底板是「逐行纯色渐变 + 网点高频」，把整条文字带按底板重画一遍，
    与「把字抠掉再补洞」在视觉上完全等价，而且不用做任何分割。

所以真正的做法是**整带重建**：逐行取暗色像素中位色当基准，用上方干净带的镜像
高频纹理补回网点，边缘羽化后盖掉整条带；再在带内按字号自适应排英文，颜色从源图
金牌面/描边里取。带外一个像素不动。

用法
----
    python scripts/image/ribbon_compose.py \
        --asset Assets/ManagedResources/ArtFont_zh/font/cn2-x1_texie_aijiyanhou_01_zh.png \
        --lines "BREATH OF|TEMPTATION" --out /tmp/composed.png --preview /tmp/preview.png

产物可直接喂回管线做验收/写回（provider=manual 会跳过浏览器）：

    python scripts/image/banner_translate.py run --asset <zh> --provider manual \
        --gen-image /tmp/composed.png --force
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]

# 字体候选：优先 condensed 重型（贴游戏里美术字的窄重手感），最后兜 Arial
STROKE_RATIO = 0.11

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/System/Library/Fonts/Supplemental/Impact.ttf",
    "/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
]


FONT_OVERRIDE = ""


def load_font(size: int) -> ImageFont.FreeTypeFont:
    cands = [FONT_OVERRIDE] if FONT_OVERRIDE else FONT_CANDIDATES
    for p in cands:
        if p and Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def ribbon_box(alpha: np.ndarray, thr: int = 128) -> tuple[int, int, int, int]:
    ys, xs = np.nonzero(alpha > thr)
    if not len(xs):
        raise SystemExit("alpha 全透明，不是彩带图")
    return int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())


def analyze(arr: np.ndarray, tol: int = 14) -> dict:
    """求底板基准色 / 墨迹 bbox / 金牌面与描边色。"""
    A = arr[..., 3]
    R, G, B = (arr[..., 0].astype(int), arr[..., 1].astype(int),
               arr[..., 2].astype(int))
    rx0, rx1, ry0, ry1 = ribbon_box(A)

    # 逐行基准色：行内「够暗」像素的中位色（暗色一定是底板，不会是金/白字）
    base = np.zeros((arr.shape[0], 3), np.float32)
    for y in range(ry0, ry1 + 1):
        row = arr[y, rx0 : rx1 + 1, :3].astype(np.float32)
        dark = row[row.max(axis=1) < 120]
        if len(dark) >= 20:
            base[y] = np.median(dark, axis=0)

    diff = np.abs(arr[..., :3].astype(np.float32) - base[:, None, :]).max(axis=2)

    gold = (A > 150) & (R > 170) & (G > 110) & (B < 150) & (R >= B + 50)
    gy, gx = np.nonzero(gold)
    if not len(gx):
        raise SystemExit("没找到金牌面（这脚本只服务「金色美术字 + 暗彩带」这一族）")

    # 墨迹 = 金牌面 ∪ 「金牌面外一圈里与底板色不同的像素」。
    # 🔴 不能拿全图「与基准色差 > tol」当墨迹：彩带两侧的箭头、亮边、网点都满足，
    #    bbox 会涨到整条彩带（实测 x[75,414] y[60,206]），重建区把装饰一起盖掉。
    ring = cv2.dilate(gold.astype(np.uint8), np.ones((21, 21), np.uint8)).astype(bool)
    ink = gold | (ring & (diff > tol) & (A > 8))
    ink = cv2.morphologyEx(ink.astype(np.uint8), cv2.MORPH_CLOSE,
                           np.ones((5, 5), np.uint8)).astype(bool)
    ink = cv2.morphologyEx(ink.astype(np.uint8), cv2.MORPH_OPEN,
                           np.ones((3, 3), np.uint8)).astype(bool)
    ink[:ry0] = False
    ink[ry1 + 1 :] = False
    ink[:, :rx0] = False
    ink[:, rx1 + 1 :] = False

    gold_rgb = np.median(arr[gy, gx, :3], axis=0)

    # 描边色：金牌面外环里最暗的 15%（中位色会被底板拉平，等于取不到描边）
    halo = cv2.dilate(gold.astype(np.uint8), np.ones((11, 11), np.uint8)).astype(bool) & ~gold & (A > 150)
    if halo.sum() > 50:
        hs = arr[halo][:, :3].astype(np.float32)
        luma = hs @ np.array([0.299, 0.587, 0.114], np.float32)
        cut = np.quantile(luma, 0.15)
        stroke_rgb = np.median(hs[luma <= cut], axis=0)
    else:
        stroke_rgb = np.array([12, 12, 12], np.float32)

    iy, ix = np.nonzero(ink)

    # 实心板列范围：墨迹行区间内 alpha>=200 的占比 >=70% 的最长连续列段。
    # 彩带两端是网点/半透明外缘，字排进去会被网点糊掉。
    iy0_, iy1_ = int(iy.min()), int(iy.max())
    # 别看「最长连续段」：网点会在中间打洞，连续段会被切碎（实测只剩 110px）。
    # 取合格列的 min/max 即可，中间的洞本来也在实心板范围内。
    colfrac = (arr[iy0_:iy1_ + 1, :, 3] >= 150).mean(axis=0)
    xs_ok = np.nonzero(colfrac >= 0.60)[0]
    plate_cols = (int(xs_ok.min()), int(xs_ok.max())) if len(xs_ok) else None

    return {
        "ribbon": (rx0, rx1, ry0, ry1),
        "ink": (int(ix.min()), int(ix.max()), int(iy.min()), int(iy.max())),
        "base": base,
        "gold_rgb": gold_rgb,
        "stroke_rgb": stroke_rgb,
        "ink_mask": ink,
        "plate_cols": plate_cols,
        "gold_px": int(gold.sum()),
    }


def rebuild_band(arr: np.ndarray, info: dict, pad: int = 3,
                 texture: str = 'strip') -> tuple[np.ndarray, tuple[int, int, int, int]]:
    """把整条文字带按彩带底板重建，返回 (新像素, 重建带 x0,y0,x1,y1)。

    🔴 三次踩坑换来的口径（2026-10-22 实测，别再走回去）：
      1. **魔棒（flood-fill 容差）抠不干净**：中文是「金牌面 + 近黑厚描边」，描边色与
         底板只差 10~15，68.6% 的描边环被判成底板；金字又是被描边围死的孤岛，单点播种
         只覆盖带内 61%。抠不干净，也不需要抠干净 —— 底板是纯色 + 网点，整带重画等价。
      2. **alpha 必须一起重建**：这批彩带的网点纹理一半编码在 alpha 里（底板 224、
         金字 255）。只抹 RGB 会留「中文形状的 alpha 鬼影」——浅底上一眼就是残字。
      3. **别用「逐行中位色」合成底板**：底板以纯黑为主、夹杂亮颗粒，中位常落在亮颗粒上
         （实测取到 20~23，而周边纯黑是 0），结果带内比周围亮一截、露出矩形。
         正解是**直接克隆彩带左右两端的真实像素条**（RGB + alpha 一起），色调/网点
         全部来自原图，不需要调参。
    """
    rx0, rx1, ry0, ry1 = info["ribbon"]
    ix0, ix1, iy0, iy1 = info["ink"]
    x0 = max(rx0 + 2, ix0 - 10)
    x1 = min(rx1 - 1, ix1 + 10)
    y0 = max(ry0 + 2, iy0 - pad)
    y1 = min(ry1 - 1, iy1 + pad)
    h, w = y1 - y0 + 1, x1 - x0 + 1

    out = arr.astype(np.float32).copy()

    # ① 真实底板样本：重建带左右两侧的窄条（同一段 y），RGB 与 alpha 都取
    lw = max(0, min(20, x0 - (rx0 + 1)))
    rw = max(0, min(20, (rx1 - 1) - x1))
    left = arr[y0:y1 + 1, x0 - lw:x0, :] if lw else np.zeros((h, 0, 4), np.uint8)
    right = arr[y0:y1 + 1, x1 + 1:x1 + 1 + rw, :] if rw else np.zeros((h, 0, 4), np.uint8)
    strip = np.concatenate([left, right], axis=1).astype(np.float32)
    if texture == 'strip' and strip.shape[1] >= 10:
        patch = mirror_tile(strip[..., :3], h, w)
        apatch = mirror_tile(strip[..., 3:4], h, w)[..., 0]
    else:
        # ② 兜底：带子窄到没有左右留白，用逐行非墨迹像素的低分位色（不是中位）
        ink = info.get("ink_mask")
        base = np.zeros((h, 3), np.float32)
        ra = np.zeros(h, np.float32)
        for i, y in enumerate(range(y0, y1 + 1)):
            seg = arr[y, x0:x1 + 1].astype(np.float32)
            keep = (~ink[y, x0:x1 + 1]) if ink is not None else np.ones(w, bool)
            keep &= seg[:, 3] > 150
            if keep.sum() >= 20:
                base[i] = np.percentile(seg[keep, :3], 20, axis=0)
                ra[i] = np.median(seg[keep, 3])
            elif i:
                base[i], ra[i] = base[i - 1], ra[i - 1]
        for c in range(3):
            base[:, c] = cv2.GaussianBlur(base[:, c].reshape(-1, 1), (0, 0), 6).ravel()
        patch = np.repeat(base[:, None, :], w, axis=1)
        apatch = np.repeat(ra[:, None], w, axis=1)

    # ③ 羽化：四周 6px 渐隐 + 乘「源图彩带不透明度」掩膜（重建区是矩形，彩带在带子
    #    上下收窄，不乘会在大块透明区里画出实心矩形）。
    fy = np.ones(h, np.float32)
    fx = np.ones(w, np.float32)
    f = 6
    for i in range(min(f, h // 2)):
        fy[i] = fy[-1 - i] = (i + 0.5) / f
    for i in range(min(f, w // 2)):
        fx[i] = fx[-1 - i] = (i + 0.5) / f
    ribbon_w = np.clip((arr[y0:y1 + 1, x0:x1 + 1, 3].astype(np.float32) - 40.0) / 120.0, 0, 1)
    ribbon_w = cv2.GaussianBlur(ribbon_w, (0, 0), 1.5)
    a = (fy[:, None] * fx[None, :] * ribbon_w)[..., None]

    out[y0:y1 + 1, x0:x1 + 1, :3] = out[y0:y1 + 1, x0:x1 + 1, :3] * (1 - a) + patch * a

    # ④ alpha **只在墨迹区**重建：字以外的 alpha 低值像素是彩带网点（透背景的孔），
    #    整带盖成 224 会把孔填实 ⇒ 带内平均 alpha 从 188 抬到 216（Δ+28），
    #    浅色底上就是一块更实的矩形。墨迹区内则必须改：金字 alpha 是 255，
    #    不改会在字形位置留下「中文形状的实心残影」。
    ink = info.get("ink_mask")
    if ink is not None:
        ai = cv2.GaussianBlur(ink[y0:y1 + 1, x0:x1 + 1].astype(np.float32), (0, 0), 1.5)
        aw = (ai * ribbon_w)
        # 填充值按「逐行加权均值」取，等于让该行墨迹区的 alpha 总量守恒 ⇒ 带内平均
        # alpha 与源图的差天然 ≈0（验收闸门 ±8 从「靠运气」变成「构造成立」）。
        src_a = arr[y0:y1 + 1, x0:x1 + 1, 3].astype(np.float32)
        wsum = aw.sum(axis=1) + 1e-6
        apatch = ((aw * src_a).sum(axis=1) / wsum)[:, None].repeat(w, axis=1)
    else:
        aw = a[..., 0]
    out[y0:y1 + 1, x0:x1 + 1, 3] = (out[y0:y1 + 1, x0:x1 + 1, 3] * (1 - aw)
                                    + apatch * aw)
    return np.clip(out, 0, 255), (x0, y0, x1, y1)


def mirror_tile(tile: np.ndarray, H: int, W: int) -> np.ndarray:
    rows, y, flip = [], 0, False
    while y < H:
        rows.append(tile[::-1] if flip else tile)
        y += tile.shape[0]
        flip = not flip
    big = np.concatenate(rows, axis=0)[:H]
    cols, x, flip = [], 0, False
    while x < W:
        cols.append(big[:, ::-1] if flip else big)
        x += big.shape[1]
        flip = not flip
    return np.concatenate(cols, axis=1)[:, :W]


def _line_layer(text: str, size: int, gold: tuple, stroke: tuple):
    """把一行字渲染成紧贴墨迹的 RGBA 图层（带描边），返回图层与实际墨迹尺寸。"""
    f = load_font(size)
    sw = max(1, round(size * STROKE_RATIO))
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    b = probe.textbbox((0, 0), text, font=f, stroke_width=sw)
    w, h = b[2] - b[0], b[3] - b[1]
    layer = Image.new("RGBA", (max(1, w), max(1, h)), (0, 0, 0, 0))
    ImageDraw.Draw(layer).text((-b[0], -b[1]), text, font=f, fill=gold + (255,),
                               stroke_width=sw, stroke_fill=stroke + (255,))
    return layer, f, w, h, sw


def draw_lines(img: Image.Image, lines: list[str], info: dict,
               band: tuple[int, int, int, int],
               gap_ratio: float = 0.22, squash_min: float = 0.78) -> Image.Image:
    """在重建带内排英文：**按宽度定字号**，纵向压缩不低于 squash_min。

    🔴 只按高度定字号会得到「又小又空」的结果（实测两行只占 47% 宽度）；
       只按宽度定字号则会纵向溢出。正解是「宽度优先 + 允许有限纵向压缩」：
       美术字本来就偏高，压到 0.78 与源图直立的方块字视觉重量对得上。
    """
    x0, y0, x1, y1 = band
    W, H = x1 - x0 + 1, y1 - y0 + 1
    # 可排字范围收在「实心板」内：逐列统计带内 alpha>=200 的占比，取 >=70% 的连续区间。
    # 🔴 直接按 band 宽度排会把字母压到彩带外缘的网点上（实测 TEMPTATION 占 99% 带宽，
    #    首尾字母压在 half-tone 上，笔画一进网点就糊）。
    if info.get("plate_cols") is not None:
        px0, px1 = info["plate_cols"]
        x0, W = max(x0, px0), min(x1, px1) - max(x0, px0) + 1
    gold = tuple(int(v) for v in info["gold_rgb"])
    stroke = tuple(int(v) for v in info["stroke_rgb"])
    n = len(lines)
    line_h = max(8, int(H / (n + (n - 1) * gap_ratio)))

    out = img.convert("RGBA")
    for i, text in enumerate(lines):
        pick = None
        for size in range(12, 260):
            layer, f, w, h, sw = _line_layer(text, size, gold, stroke)
            if w > W - 2:
                break
            sy = min(1.0, line_h / h)
            if sy < squash_min:
                continue
            pick = (size, layer, w, h, sw, sy)
        if pick is None:                       # 连 12px 都放不下（极端长文案）
            layer, f, w, h, sw = _line_layer(text, 12, gold, stroke)
            size, sy = 12, min(1.0, line_h / h)
        else:
            size, layer, w, h, sw, sy = pick
        if sy < 1.0:
            layer = layer.resize((w, max(1, round(h * sy))), Image.LANCZOS)
            h = round(h * sy)
        left = x0 + (W - w) // 2
        top = y0 + i * (line_h + int(line_h * gap_ratio)) + (line_h - h) // 2
        out.alpha_composite(layer, (left, max(y0, top)))
        print(f"  第{i + 1}行 {text!r}: 字号 {size}px 宽 {w}px({w / W:.0%} 带宽) "
              f"纵向压缩 {sy:.2f} 描边 {sw}px @({left},{top})")
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", required=True, help="中文源图（zh）路径，相对仓库根或绝对路径")
    ap.add_argument("--lines", required=True, help='英文行，用 | 分隔；例 "BREATH OF|TEMPTATION"')
    ap.add_argument("--out", required=True)
    ap.add_argument("--preview", default="", help="可选：白底放大预览图")
    ap.add_argument("--tol", type=int, default=14, help="墨迹判定容差（与行基准色的最大通道差）")
    ap.add_argument("--keep-alpha", action="store_true", help="alpha 逐像素沿用源图（默认重建）")
    ap.add_argument("--font", default="", help="指定 ttf 路径（默认按 FONT_CANDIDATES 顺序）")
    ap.add_argument("--texture", default="strip", choices=["strip", "flat"],
                    help="底板重建方式：strip=克隆带子左右真实像素条（默认）；flat=逐行低分位纯色")
    args = ap.parse_args()
    global FONT_OVERRIDE
    FONT_OVERRIDE = args.font

    p = Path(args.asset)
    p = p if p.is_absolute() else ROOT / p
    im = Image.open(p).convert("RGBA")
    arr = np.asarray(im)
    info = analyze(arr, tol=args.tol)
    rx0, rx1, ry0, ry1 = info["ribbon"]
    ix0, ix1, iy0, iy1 = info["ink"]
    print(f"源图 {im.size[0]}x{im.size[1]}  彩带 x[{rx0},{rx1}] y[{ry0},{ry1}]")
    print(f"墨迹 x[{ix0},{ix1}] y[{iy0},{iy1}]  金牌面 {info['gold_px']}px  "
          f"金={tuple(int(v) for v in info['gold_rgb'])} 描边={tuple(int(v) for v in info['stroke_rgb'])}")

    plane, band = rebuild_band(arr, info, texture=args.texture)
    out = Image.fromarray(plane.astype(np.uint8), "RGBA")
    print(f"重建带 x[{band[0]},{band[2]}] y[{band[1]},{band[3]}]")
    out = draw_lines(out, [s for s in args.lines.split("|") if s.strip()], info, band)

    # alpha：默认沿用「重建后」的 alpha（网点纹理与英文墨迹都在里面）；
    # --keep-alpha 才逐像素回填源图 alpha（会留下中文形状的 alpha 鬼影，仅供对比）。
    if args.keep_alpha:
        out = out.convert("RGB").convert("RGBA")
        out.putalpha(im.getchannel("A"))
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out)
    print(f"写出 {args.out}")
    side = Path(args.out).with_name(Path(args.out).stem + ".band.json")
    side.write_text(json.dumps({"alpha_band": [int(v) for v in band],
                                "source": str(p), "lines": args.lines},
                               ensure_ascii=False), encoding="utf-8")
    print(f"边车 {side}（alpha_band={list(band)}）")

    if args.preview:
        bg = Image.new("RGBA", out.size, (255, 255, 255, 255))
        Image.alpha_composite(bg, out).convert("RGB") \
            .resize((out.width * 2, out.height * 2), Image.LANCZOS).save(args.preview)
        print(f"预览 {args.preview}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
