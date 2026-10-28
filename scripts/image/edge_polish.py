#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""抠图边缘去污 —— 所有「模型画完再贴回去」的 job 共用这一份实现。

为什么要有这个文件
------------------
2026-10-28 用户报了两个现象：**新画的人物边缘一圈杂色**（白边 / 纯红纯黄细弧 / 深色描边）、
以及**以前已经改好的帧又被改了**。前者是「二值掩码压在模型自带的脏边上」，
后者是「没有记录这一帧是按哪版口径贴的，于是每次改逻辑都整包重刷」。

第二个问题的答案是版本账本（见 `EDGE_VER`）；第一个问题的答案就是这个模块。
两个问题都**不是某一个 job 的私有 bug**，而是所有生图链路共有的：
仙境（XZ-Art-Restyle）、时空少女（TS-Art-Restyle / batch_restyle）、
以及借同一条 `restyle_pipeline.py postprocess` 出图的所有任务。
所以实现只能有一份 —— 各 job 各抄一遍必然分叉，最后又是「这里修好了那里没修」。

三个脏边来源（都实测过）
------------------------
1. **白色抗锯齿**：模型在白画布上作画，主体轮廓外必然有 1~3px 由白到色的过渡。
   二值掩码一刀切在过渡带中间 ⇒ 贴回后整圈发白（浅色底上尤其明显）。
2. **纯红/纯黄细弧**：生成端自己压出来的杂边（`role_5015` 的 gen 里 2095 个纯红 +
   2284 个纯黄像素，位置全在衣摆/袖口外侧），不是画的内容。
3. **深色背景板**：模型不听「纯白背景」的招呼，直接把主体画在黑底上，
   掩码一旦退回原帧轮廓，黑底就从轮廓里露出来（用户看到的「黑影」）。

修法只动**颜色**、不动轮廓：把实心核心的颜色向外扩散到边缘带，再把 alpha 轻微羽化。
轮廓（主体的形状/位置）一个像素都不挪 —— 所以切片坐标、图集九宫格全都不受影响。

用法
----
    # 体检：覆盖率 + 边缘杂色像素数（改口径前后对比用，零副作用）
    python3 scripts/image/edge_polish.py --check out/xxx_alpha.png

    # 单张修：显式给 alpha，输出到新文件
    python3 scripts/image/edge_polish.py --apply out/xxx.png --alpha out/xxx_a.png --out /tmp/p.png

    # 代码里（推荐，一行）
    import edge_polish
    im, alpha, note = edge_polish.clean(im, alpha)

改了判据/参数 ⇒ **必须**把 `EDGE_VER` +1，并同步
`xiuxian/art_restyle/refit_frames.MASK_VER` / `repack_scene_frames.CUT_VER`，
否则账本会认为「已按当前口径处理过」，重跑时全部跳过（这类坑踩过一次：
旧账本 → 新口径不生效 → 以为代码没打进去）。
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

# 边缘去污口径版本。任何影响成品的参数/判据变化都必须 +1（写进 state.json 与贴回账本）。
EDGE_VER = "edge-1"

# 满幅判定：alpha 覆盖率高于它就没有「轮廓」可修（整幅插画/底板），一律跳过。
FULL_COV = 0.995


# --------------------------------------------------------------------------- 基础算子
def _shift(a: np.ndarray, dy: int, dx: int) -> np.ndarray:
    """平移（不 wrap），空出来的边用 0 填。扩散/膨胀都靠它，比 scipy 依赖少。"""
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    out[yd, xd] = a[ys, xs]
    return out


_NEIGHBORS8 = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))


def coverage(alpha: Image.Image, thr: int = 40) -> float:
    """不透明像素占比（判「满幅 / 抠图」的唯一口径，别用四角，边缘被啃 3% 会误判）。"""
    return float((np.array(alpha.convert("L")) > thr).mean())


def has_boundary(alpha: Image.Image, full: float = FULL_COV) -> bool:
    """有真实轮廓才值得去边；满幅图（底板/插画/整块纸面）跳过 —— 否则会啃掉画边。"""
    return coverage(alpha) < full


def _band(alpha_arr: np.ndarray, dist: int) -> np.ndarray:
    """轮廓内侧 dist px 的带子（= 不透明，但不在「腐蚀 dist 后的核心」里）。"""
    a = (alpha_arr > 0)
    core = np.array(Image.fromarray((a * 255).astype(np.uint8))
                    .filter(ImageFilter.MinFilter(dist * 2 + 1))) >= 255
    return a & ~core


# --------------------------------------------------------------------------- ① 纯色杂弧
def scrub_hot_pixels(rgb: np.ndarray, alpha: np.ndarray, dist: int = 6,
                     chroma: int = 140, bright: int = 170) -> tuple[np.ndarray, int]:
    """清掉贴着轮廓的「纯红/纯黄细弧」—— 生成端自带的人工色。

    判据取「亮度 ≥ bright 且彩度 ≥ chroma」并只处理**距轮廓 dist px 内**的像素，
    主体内部的红缎带/金饰不在带子里，不会被误伤。
    修法：用「周围非杂色的邻居」逐轮填进去（inpaint），**不动 alpha**。
    """
    a = (alpha > 0)
    band = _band(alpha, dist)
    mx = rgb.max(axis=2) if rgb.ndim == 3 else rgb
    mn = rgb.min(axis=2) if rgb.ndim == 3 else rgb
    hot = band & (mx >= bright) & ((mx - mn) >= chroma)
    if not hot.any():
        return rgb, 0
    cols = rgb.astype(np.float32)
    known = ~hot
    n_hot = int(hot.sum())
    for _ in range(dist * 3):
        if not (hot & ~known).any():
            break
        acc = np.zeros_like(cols)
        cnt = np.zeros(mx.shape, np.float32)
        for dy, dx in _NEIGHBORS8:
            acc += _shift(cols * known[..., None], dy, dx)
            cnt += _shift(known.astype(np.float32), dy, dx)
        fill = hot & ~known & (cnt > 0)
        if not fill.any():
            break
        cols[fill] = acc[fill] / cnt[fill][:, None]
        known |= fill
    return cols, n_hot


def fringe_count(im: Image.Image, alpha: Image.Image, dist: int = 6,
                 chroma: int = 150, bright: int = 200) -> int:
    """成品上还剩多少「贴边的高饱和亮色」—— 验收/回归用的量化指标（不改任何像素）。

    注意判据比 `scrub_hot_pixels` 松一档：这里是**事后**看结果，
    羽化会让半透明像素的合成色变淡，太严会一直报 0 反而看不出回归。
    """
    rgb = np.array(im.convert("RGB")).astype(np.int16)
    a = np.array(alpha.convert("L"))
    band = _band(a, dist)
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    return int((band & (mx >= bright) & ((mx - mn) >= chroma)).sum())


def halo_count(im: Image.Image, alpha: Image.Image, dist: int = 6,
               bright: int = 236, chroma: int = 14) -> int:
    """成品上还剩多少「贴边的近白/浅灰」像素 —— 「人物边缘一圈白边」的量化指标。

    白边和彩边是两种脏：`fringe_count` 抓高饱和杂弧，这个抓低饱和亮带。
    两者都会在游戏里被看成「没抠干净」，但成因不同（白边=模型画布的白抗锯齿，
    彩边=生成端压出来的杂色），所以要分别量、分别回归。
    """
    rgb = np.array(im.convert("RGB")).astype(np.int16)
    a = np.array(alpha.convert("L"))
    band = _band(a, dist)
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    return int((band & (mn >= bright) & ((mx - mn) <= chroma)).sum())


# --------------------------------------------------------------------------- ② 白边/彩边
def polish_edges(im: Image.Image, alpha: Image.Image, ring: int = 3, shrink: int = 1,
                 feather: float = 0.8) -> tuple[Image.Image, Image.Image, str]:
    """切图边缘去污（去白边 / 去彩色毛边）+ 补回抗锯齿。**只改颜色，不动轮廓。**

      ① 清「纯红/纯黄细弧」（`scrub_hot_pixels`，必须在扩散之前：不然杂色会被当主体色扩散整圈）
      ② 向里收 `shrink` px（杂弧有 2~4px 厚，紧贴轮廓那层靠上色盖不住）
      ③ 取「实心核心」= alpha≥245 再腐蚀 `ring` px
      ④ 把核心的**颜色**向外扩散 `ring+feather+5` px（每轮取已填邻居均值）
      ⑤ 核心外、仍可见的那一圈颜色 = 扩散结果 ⇒ 边界只剩主体自身的颜色
      ⑥ alpha 轻微高斯羽化，把二值边缘补成渐变（缩放时不出现台阶）

    🔴 边缘带必须**含 alpha=0 的外侧 1~2px**：羽化会让轮廓外的像素拿到 40~60 的
       半透明值，那些像素如果没被上色，仍是模型图里的纯红/纯黄杂弧 ——
       「明明清了还有一点红」就是这么来的（实测残留 48 像素全是 A≈45 的外侧像素）。
    """
    a = np.array(alpha.convert("L"))
    rgb = np.array(im.convert("RGB")).astype(np.float32)
    rgb, n_hot = scrub_hot_pixels(rgb, a)
    if shrink > 0:
        alpha = alpha.filter(ImageFilter.MinFilter(shrink * 2 + 1))
        a = np.array(alpha)
    core_mask = np.array(alpha.filter(ImageFilter.MinFilter(ring * 2 + 1))) >= 245
    if core_mask.sum() < max(64, a.size * 0.002):
        return im, alpha, "核心太小（<0.2%），跳过去边"
    known = core_mask.copy()
    cols = rgb.copy()
    for _ in range(ring + int(feather) + 5):
        acc = np.zeros_like(cols)
        cnt = np.zeros(a.shape, np.float32)
        for dy, dx in _NEIGHBORS8:
            acc += _shift(cols * known[..., None], dy, dx)
            cnt += _shift(known.astype(np.float32), dy, dx)
        fill = (~known) & (cnt > 0)
        if not fill.any():
            break
        cols[fill] = acc[fill] / cnt[fill][:, None]
        known |= fill
    vis = (a > 0)
    for _ in range(int(feather) + 2):
        vis = vis | _shift(vis, 1, 0) | _shift(vis, -1, 0) | _shift(vis, 0, 1) | _shift(vis, 0, -1)
    band = vis & ~core_mask & known
    band_px = int(band.sum())
    out_rgb = np.where(band[..., None], cols, rgb).round().clip(0, 255).astype(np.uint8)
    soft = Image.fromarray(a).filter(ImageFilter.GaussianBlur(feather))
    return (Image.fromarray(out_rgb, "RGB"), soft,
            f"边缘去污 {band_px}px（外 {ring}px 改上主体色；清掉纯色杂弧 {n_hot}px）+ 羽化 {feather}")


# --------------------------------------------------------------------------- ③ 深色背板
def strip_dark_backdrop(im: Image.Image, alpha: Image.Image,
                        dark_max: int = 28, min_frac: float = 0.04
                        ) -> tuple[Image.Image, Image.Image, str]:
    """把模型自己画的**深色背景板**从 alpha 上挖掉（用户看到的「黑影」）。

    判据与掩码无关：「与画面四边连通 且 接近纯黑 且 面积 > min_frac」⇒ 一定是画出来的背板。
    真正的深色衣饰/发丝是**闭合**的，不会从四边灌进来；
    满幅帧（原画本身就是整张深底插画）由调用方按覆盖率跳过，不会被误伤。

    兜底价值：主体掩码那一路通常已经排掉深底（深色与边框连通 ⇒ 判背景），
    但只要掩码是旧的、或判据失效退回原帧轮廓，黑底就会从轮廓里露出来 —— 这是最后一道闸。
    """
    rgb = np.array(im.convert("RGB")).astype(np.int16)
    dark = rgb.max(axis=2) <= dark_max
    if dark.mean() < min_frac:
        return im, alpha, ""
    h, w = dark.shape
    bg = np.zeros((h, w), bool)
    stack: list[tuple[int, int]] = []
    for x in range(w):
        for y in (0, h - 1):
            if dark[y, x] and not bg[y, x]:
                bg[y, x] = True
                stack.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if dark[y, x] and not bg[y, x]:
                bg[y, x] = True
                stack.append((y, x))
    while stack:
        y, x = stack.pop()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and dark[ny, nx] and not bg[ny, nx]:
                bg[ny, nx] = True
                stack.append((ny, nx))
    frac = float(bg.mean())
    if frac < min_frac:
        return im, alpha, ""
    a = np.array(alpha).copy()
    hit = int(((a > 40) & bg).sum())
    if hit < a.size * 0.003:
        return im, alpha, ""
    # 抠穿护栏：万一主体本身就是连片的深色（黑剑/黑甲）并且贴到边框，直接挖会把主体
    # 也算进去。挖完掉到一半以下就判「不是背板」，原样退回。
    old_cov = float((a > 40).mean())
    new_cov = float(((a > 40) & ~bg).mean())
    if old_cov > 0 and new_cov < old_cov * 0.5:
        return im, alpha, f"深色区 {frac * 100:.0f}% 与主体重叠过多（{old_cov:.2f}→{new_cov:.2f}）→ 跳过"
    a[bg] = 0
    return im, Image.fromarray(a, "L"), f"挖掉深色背景板 {frac * 100:.0f}%（{hit} 像素）"


# --------------------------------------------------------------------------- ④ 合理性护栏
def alpha_sane(cand: Image.Image, ref: Image.Image) -> tuple[bool, str]:
    """候选 alpha 是否可信。两种失效都该退回原帧轮廓（宁可延用老轮廓，也不能毁图）：

    1. **候选 ≈ 满幅，而原画是抠图**（`c ≥ 93%` 且 `ref ≤ 85%`）：说明「按颜色找主体」
       这一路彻底失效 —— 模型把背景也画了（立绘整幅插画、圆形头像画成方块），
       套上去就是 alpha=255，原画透明处全变成模型画的黑底 ⇒「新图加了黑色底框」。
    2. **抠穿**（候选 < 原画的 35%）：浅色主体被灌水连主体一起吃掉。
    """
    c = coverage(cand)
    r = coverage(ref)
    if c >= 0.93 and r <= 0.85:
        return False, (f"新掩码 {c * 100:.0f}% ≈ 满幅，而原画只有 {r * 100:.0f}%（抠图）"
                       f"⇒ 判据失效，模型画了背景")
    if r > 0 and c < r * 0.35:
        return False, f"抠穿（{c * 100:.0f}% vs 原 {r * 100:.0f}%）"
    return True, ""


# --------------------------------------------------------------------------- 一站式入口
def clean(im: Image.Image, alpha: Image.Image, *, backdrop: bool = True
          ) -> tuple[Image.Image, Image.Image, str]:
    """job 唯一需要调的函数：深色背板 → 白边/彩边 → 返回 (RGB, alpha, 说明)。

    满幅图（底板/插画）原样返回 —— 没有轮廓就没有边缘可修，硬做只会啃掉画边。
    """
    if not has_boundary(alpha):
        return im, alpha, ""
    notes: list[str] = []
    if backdrop:
        im, alpha, n1 = strip_dark_backdrop(im, alpha)
        if n1:
            notes.append(n1)
    im, alpha, n2 = polish_edges(im, alpha)
    if n2:
        notes.append(n2)
    return im, alpha, "；".join(notes)


# --------------------------------------------------------------------------- CLI
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="抠图边缘去污（体检 / 单张修）")
    ap.add_argument("png", help="要看的图（RGBA 时 alpha 取自它自己）")
    ap.add_argument("--alpha", default=None, help="单独的 alpha 图（不给则用 png 自己的 A 通道）")
    ap.add_argument("--apply", action="store_true", help="真的修（默认只体检）")
    ap.add_argument("--out", default=None, help="--apply 的输出路径（默认 <png>_polished.png）")
    ap.add_argument("--ring", type=int, default=3)
    ap.add_argument("--feather", type=float, default=0.8)
    a = ap.parse_args(argv)

    png = Path(a.png).expanduser().resolve()
    if not png.is_file():
        print(f"🔴 不存在：{png}")
        return 2
    im = Image.open(png).convert("RGBA")
    alpha = (Image.open(a.alpha).convert("L").resize(im.size, Image.LANCZOS)
             if a.alpha else im.getchannel("A"))
    cov = coverage(alpha)
    fr = fringe_count(im, alpha)
    ha = halo_count(im, alpha)
    print(f"{png.name}: {im.size[0]}x{im.size[1]}  覆盖率 {cov * 100:.1f}%  "
          f"贴边高饱和像素 {fr}  贴边近白像素 {ha}  "
          f"{'（满幅，会跳过）' if not has_boundary(alpha) else ''}")
    if not a.apply:
        print("（体检模式，没有改像素；要修加 --apply）")
        return 0
    out_im, out_a, note = clean(im, alpha)
    out_im = out_im.convert("RGBA")
    out_im.putalpha(out_a)
    dst = Path(a.out).expanduser() if a.out else png.with_name(f"{png.stem}_polished.png")
    out_im.save(dst)
    print(f"✅ {note or '无需处理'}  →  {dst}  贴边高饱和 {fringe_count(out_im, out_a)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
