#!/usr/bin/env python3
"""把成品图按**真机显示尺寸**贴回面板底，再出一张并排对比图 + 边角特写。

为什么需要它（2026-10-20 踩过）：资源是 1080×1644，但游戏里只显示成 567px 宽，
在 1080 上看着清楚的边框，缩到真机就是 1px 的灰线，甚至跟纯黑底同亮度直接消失。
所以**任何边框/描边/细线类改动，都必须按真机比例看一遍**，不能拿 1:1 原图验收。

用法
----
    # 两张图并排（改前 / 改后），底下叠 8 张日卡占位
    python3 scripts/image/preview_ingame.py before.png after.png \
        --disp 567 --bg 17,17,25 --cards 2x4 --top 383 --out /tmp/cmp.jpg

    # 只要边角特写（3 倍最近邻，看切角/亮边有没有毛刺）
    python3 scripts/image/preview_ingame.py after.png --zoom 3 --out /tmp/corner.jpg

面板底色的量法：截图里取边框外 2~3px 的像素中位数（八日礼包面板 = 17,17,25）。
卡片占位是为了复现「左右两边被内容盖住、只剩上下边露出来」的真实观感。
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

DEFAULT_BG = (17, 17, 25)
CARD_FILL = (162, 129, 214)
CARD_EDGE = (108, 82, 158)


def parse_color(text: str) -> tuple[int, int, int]:
    parts = [p.strip() for p in text.replace("#", "").split(",")]
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("颜色要写成 R,G,B")
    return tuple(int(p) for p in parts)  # type: ignore[return-value]


def draw_cards(img: Image.Image, spec: str, top: int, fill, edge) -> None:
    """在图上叠 rows x cols 张占位卡（模拟日卡把画面下半截盖住）。"""
    rows, _, cols = spec.lower().partition("x")
    rows, cols = int(rows), int(cols or rows)
    w, h = img.size
    gap = max(3, round(w * 0.011))
    cw = (w - gap * (cols - 1)) // cols
    ch = min(round(cw * 1.2), (h - top - gap * (rows - 1)) // max(rows, 1))
    d = ImageDraw.Draw(img)
    for r in range(rows):
        for c in range(cols):
            x0 = c * (cw + gap)
            y0 = top + r * (ch + gap)
            d.rectangle([x0, y0, x0 + cw, y0 + ch], fill=fill, outline=edge, width=2)


def to_display(path: Path, disp: int, bg, cards: str | None, top: int) -> Image.Image:
    im = Image.open(path).convert("RGB")
    h = round(im.height * disp / im.width)
    panel = Image.new("RGB", (disp, h), bg)
    panel.paste(im.resize((disp, h), Image.LANCZOS), (0, 0))
    if cards:
        draw_cards(panel, cards, top, CARD_FILL, CARD_EDGE)
    return panel


def main() -> int:
    ap = argparse.ArgumentParser(description="真机尺寸下的边框观感对比")
    ap.add_argument("images", nargs="+", help="成品图路径，按顺序从左到右")
    ap.add_argument("--disp", type=int, default=567, help="真机显示宽度（默认 567，八日礼包实测）")
    ap.add_argument("--bg", type=parse_color, default=DEFAULT_BG, help="面板底色 R,G,B（默认 17,17,25）")
    ap.add_argument("--cards", default=None, help="叠占位卡，如 2x4（rows x cols）；不填不叠")
    ap.add_argument("--top", type=int, default=None, help="占位卡起始 y（显示坐标）；默认 45%% 图高")
    ap.add_argument("--zoom", type=int, default=0, help=">0 时只出左上角特写，倍率即该值（最近邻）")
    ap.add_argument("--zoom-box", default="240x150", help="特写取景框（显示坐标），默认 240x150")
    ap.add_argument("--scale", type=float, default=1.45, help="并排图整体放大倍数（默认 1.45）")
    ap.add_argument("--out", required=True, help="输出 jpg 路径")
    args = ap.parse_args()

    paths = [Path(p).expanduser() for p in args.images]
    for p in paths:
        if not p.is_file():
            raise SystemExit(f"找不到图：{p}")

    out = Path(args.out).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)

    first = Image.open(paths[0])
    top = args.top if args.top is not None else round(args.disp * first.height / first.width * 0.45)
    panels = [to_display(p, args.disp, args.bg, args.cards, top) for p in paths]

    if args.zoom:
        bw, bh = (int(v) for v in args.zoom_box.lower().split("x"))
        tiles = [p.crop((0, 0, min(bw, p.width), min(bh, p.height)))
                  .resize((bw * args.zoom, bh * args.zoom), Image.NEAREST) for p in panels]
        sheet = Image.new("RGB", (sum(t.width for t in tiles) + 6 * len(tiles), tiles[0].height),
                          args.bg)
        x = 0
        for t in tiles:
            sheet.paste(t, (x, 0))
            x += t.width + 6
    else:
        w = int(args.disp * args.scale)
        tiles = [p.resize((w, round(p.height * args.scale)), Image.LANCZOS) for p in panels]
        sheet = Image.new("RGB", (sum(t.width for t in tiles) + 12 * (len(tiles) + 1),
                                   tiles[0].height + 12), args.bg)
        x = 12
        for t in tiles:
            sheet.paste(t, (x, 6))
            x += t.width + 12

    sheet.save(out, quality=94)
    print(f"✅ {out}  {sheet.width}x{sheet.height}  （display {args.disp}px, bg {args.bg}）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
