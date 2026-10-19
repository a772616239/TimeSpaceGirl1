#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""在 Python 里 1:1 复刻 UIShineSweep 的合成效果，用来在动 Unity 之前先把
光带宽度/倾角/裁剪范围调好。

裁剪方式与运行时一致：不用贴图 alpha（这张「战利品」钻石外面烤了一层灰阴影，
按 alpha 裁会把阴影一起点亮，脏），而是用一个旋转 45° 的白方块做 Mask ——
等价于一个菱形裁剪，正好贴合钻石的轮廓。

输出 _output/shine_sim/sheet*.png
"""
import math
import os

import numpy as np
from PIL import Image

ROOT = "/Users/wangxufeng/Documents/TimeSpaceGirl1"
DIAMOND = os.path.join(
    ROOT, "Assets/ManagedResources/Atlas/FightPointPassMainPanelAtlas/cn2-X1_zhandou_zhanlipin.png")
OUT = os.path.join(ROOT, "_output/shine_sim")

# --- 与 UIShineSweep 默认值对应 ---
ANGLE = float(os.environ.get("ANGLE", 30))
WIDTH_FACTOR = float(os.environ.get("WIDTH_FACTOR", 0.30))
LENGTH_FACTOR = float(os.environ.get("LENGTH_FACTOR", 3.0))
MAX_ALPHA = float(os.environ.get("MAX_ALPHA", 0.8))
SIGMA = float(os.environ.get("SIGMA", 0.045))
MASK_W = float(os.environ.get("MASK_W", 0.68))
MASK_H = float(os.environ.get("MASK_H", 0.72))
SUFFIX = os.environ.get("SUFFIX", "")


def streak_sprite(w=64, h=128):
    ys = (np.arange(h) + 0.5) / h
    xs = (np.arange(w) + 0.5) / w
    taper = np.clip(ys / 0.30, 0, 1) * np.clip((1.0 - ys) / 0.30, 0, 1)
    taper = taper * taper * (3 - 2 * taper)
    d = (xs - 0.5) * 2.0
    band = np.exp(-(d * d) / SIGMA)
    a = np.clip(band[None, :] * taper[:, None], 0, 1)
    rgba = np.zeros((h, w, 4), np.float32)
    rgba[..., 0:3] = 1.0
    rgba[..., 3] = a
    return Image.fromarray((rgba * 255).astype(np.uint8), "RGBA")


def smoothstep(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def render(progress, base_rgba, sprite):
    h, w = base_rgba.shape[:2]
    band_w = h * WIDTH_FACTOR
    band_len = h * LENGTH_FACTOR
    half_span = math.hypot(w, h) * 0.5
    travel = half_span + band_w * 0.5
    x = (-travel) + (2 * travel) * smoothstep(progress)

    fade = min(np.interp(progress, [0, 0.16], [0, 1]), np.interp(progress, [0.76, 1.0], [1, 0]))

    pad = int(max(band_w, band_len) + max(w, h))
    cw, ch = w + pad * 2, h + pad * 2
    sp = sprite.resize((max(1, int(round(band_w))), max(1, int(round(band_len)))), Image.BILINEAR)
    sp = sp.rotate(-ANGLE, expand=True, resample=Image.BILINEAR)

    layer = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    layer.alpha_composite(sp, (int(round(pad + w * 0.5 + x - sp.width / 2)),
                               int(round(pad + h * 0.5 - sp.height / 2))))

    lay = np.asarray(layer, np.float32) / 255.0

    # 菱形裁剪：|dx|/a + |dy|/b <= 1
    yy, xx = np.mgrid[0:ch, 0:cw]
    dx = (xx + 0.5 - (pad + w * 0.5)) / (w * MASK_W * 0.5)
    dy = (yy + 0.5 - (pad + h * 0.5)) / (h * MASK_H * 0.5)
    inside = (np.abs(dx) + np.abs(dy)) <= 1.0
    lay[..., 3] *= inside * MAX_ALPHA * fade

    base = np.zeros((ch, cw, 4), np.float32)
    base[pad:pad + h, pad:pad + w] = base_rgba

    out_a = lay[..., 3] + base[..., 3] * (1 - lay[..., 3])
    out_rgb = lay[..., 0:3] * lay[..., 3:4] + base[..., 0:3] * base[..., 3:4] * (1 - lay[..., 3:4])
    out_rgb = np.where(out_a[..., None] > 1e-5, out_rgb / np.maximum(out_a[..., None], 1e-5), 0)
    out = np.concatenate([out_rgb, out_a[..., None]], axis=2)
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    base = Image.open(DIAMOND).convert("RGBA")
    sprite = streak_sprite()
    base_rgba = np.asarray(base, np.float32) / 255.0

    phases = [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0]
    tiles = []
    for i, p in enumerate(phases):
        img = render(p, base_rgba, sprite)
        img.save(os.path.join(OUT, "f%s_%02d.png" % (SUFFIX, i)))
        tiles.append(img.crop((int(img.width / 2 - base.width / 2 - 26), int(img.height / 2 - base.height / 2 - 26),
                               int(img.width / 2 + base.width / 2 + 26), int(img.height / 2 + base.height / 2 + 26))))

    pad = 6
    tw = sum(t.width for t in tiles) + pad * (len(tiles) + 1)
    th = max(t.height for t in tiles) + pad * 2
    sheet = Image.new("RGBA", (tw, th), (24, 22, 40, 255))
    x = pad
    for t in tiles:
        sheet.alpha_composite(t, (x, pad))
        x += t.width + pad
    sheet.save(os.path.join(OUT, "sheet%s.png" % SUFFIX))
    print("ok", sheet.size)


if __name__ == "__main__":
    main()
