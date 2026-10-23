#!/usr/bin/env python3
"""从英雄立绘抽取「角色特征」——不把立绘当 seed，只把它当素材读。

为什么要这一步
--------------
把立绘直接喂给换皮管线（image-to-image）时，模型是「照着这张图重画」：
姿势、服装、镜头甚至构图都被原图锁死，文字 SUBJECT LOCK 与图片信号冲突时
模型又随意取舍 —— 实测 05 被画成白发换装、06 被画成金发。三张并排还是同一个
「居中站立 + 赛博街道纵深」的模子。

正确分工：立绘只负责**提供特征**（发色/发型/主色/武器/服装件/气质），
特征落成结构化文本，再用**纯文生图**按文本造新画面。这样每张可以有自己的
舞台、镜头和姿势，也不会互相污染。

本脚本只做可量化的部分（色板 / 剪影 / 明度），语义字段（武器是什么、服装
分几件、什么气质）由人/AI 读图补进 hero_specs.json 的语义块。

用法
----
    python3 scripts/aso/hero_features.py extract --art <立绘.png> [--json]
    python3 scripts/aso/hero_features.py report            # 批量看 specs 里的 art
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def _top_colors(px: list[tuple[int, int, int]], k: int = 8) -> list[dict]:
    """对像素做中位切分量化，返回主色与占比（只统计不透明像素）。"""
    if not px:
        return []
    tmp = Image.new("RGB", (len(px), 1))
    tmp.putdata(px)
    q = tmp.quantize(colors=k, method=Image.Quantize.MEDIANCUT)
    pal = q.getpalette() or []
    counts = q.getcolors() or []
    total = sum(c for c, _ in counts) or 1
    out = []
    for c, idx in sorted(counts, reverse=True):
        r, g, b = pal[idx * 3: idx * 3 + 3]
        out.append({
            "hex": f"#{r:02X}{g:02X}{b:02X}",
            "rgb": [r, g, b],
            "share": round(c / total, 4),
        })
    return out


def _band_colors(im: Image.Image, y0: float, y1: float, k: int = 5) -> list[dict]:
    """按相对高度切一条横带，取这条带里的主色。"""
    w, h = im.size
    band = im.crop((0, int(h * y0), w, int(h * y1))).convert("RGBA")
    px = [p[:3] for p in band.getdata() if p[3] > 140]
    return _top_colors(px, k)


def _mask_stats(im: Image.Image) -> dict:
    """剪影统计：包围盒、填充率、上下重心。"""
    alpha = im.getchannel("A")
    bbox = alpha.point(lambda v: 255 if v > 60 else 0).getbbox()
    if not bbox:
        return {}
    w, h = im.size
    hist = alpha.histogram()
    solid = sum(hist[61:])
    top = sum(hist[61:])  # 占位
    # 上下半身的不透明像素占比，判断重心（头重 / 脚重）
    half = h // 2
    up = sum(alpha.crop((0, 0, w, half)).histogram()[61:])
    dn = sum(alpha.crop((0, half, w, h)).histogram()[61:])
    tot = up + dn or 1
    return {
        "bbox": list(bbox),
        "bbox_ratio": [round((bbox[2] - bbox[0]) / w, 3), round((bbox[3] - bbox[1]) / h, 3)],
        "fill": round(solid / (w * h), 4),
        "upper_share": round(up / tot, 3),
        "lower_share": round(dn / tot, 3),
        "_": top and None,
    }


def extract(art: Path) -> dict:
    im = Image.open(art).convert("RGBA")
    px = [p[:3] for p in im.getdata() if p[3] > 140]
    return {
        "art": str(art.relative_to(ROOT)) if str(art).startswith(str(ROOT)) else str(art),
        "size": list(im.size),
        "palette": _top_colors(px, 8),
        # 头/上身/下身分带，用来分别读「发色」「服装主色」「下装色」
        "band_head": _band_colors(im, 0.02, 0.24, 5),
        "band_torso": _band_colors(im, 0.28, 0.58, 5),
        "band_legs": _band_colors(im, 0.60, 0.95, 5),
        "silhouette": _mask_stats(im),
    }


def cmd_extract(args) -> int:
    art = Path(args.art)
    if not art.is_absolute():
        art = ROOT / art
    if not art.is_file():
        print(f"立绘不存在：{art}")
        return 2
    data = extract(art)
    print(json.dumps(data, ensure_ascii=False, indent=2))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="立绘特征抽取（色板 / 剪影 / 明度）")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("extract")
    p.add_argument("--art", required=True)
    p.set_defaults(func=cmd_extract)
    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
