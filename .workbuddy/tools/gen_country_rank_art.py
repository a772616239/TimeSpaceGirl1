#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成「国家排行榜」所需的全部美术资源（纯 PIL 绘制，不依赖任何外部素材）。

画风对齐游戏现有 UI（取样自 Assets/ManagedResources/Atlas/X1PublicAtlas）：
  - 底板深紫 #1d162a ~ #261a3b，金色选中 #ffcc00，青色高光 #00d0e8
  - 切角（chamfer）多边形、细亮边 #797979、斜向排线暗纹
  - 圆角小旗 + 斜切金边（用户选定的旗帜造型）

产物写到 Assets/ManagedResources/Atlas/CountryRankPanelAtlas/：
  cn2-x1_guojiapaihang_*.png   面板件（标题条 / 条目底板 / 名次牌 / 页签…）
  cn2-guoqi_<iso>.png          国家旗帜（圆角小旗 + 斜切金边）

用法： python3 .workbuddy/tools/gen_country_rank_art.py [--preview]
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "Assets/ManagedResources/Atlas/CountryRankPanelAtlas")

# ---------------------------------------------------------------- 调色板（取自现有 UI）
NAVY_DEEP = (17, 13, 26, 255)       # #110d1a 描边/深底
NAVY = (29, 22, 42, 255)            # #1d162a 面板底
NAVY_LIGHT = (38, 26, 59, 255)      # #261a3b 面板亮部
PURPLE = (159, 90, 253, 255)        # #9f5afd 紫光
PURPLE_DIM = (94, 53, 150, 255)
GOLD = (255, 204, 0, 255)           # #ffcc00
GOLD_DEEP = (176, 126, 0, 255)
GOLD_PALE = (255, 236, 150, 255)
CYAN = (0, 208, 232, 255)           # #00d0e8
CYAN_DIM = (0, 96, 108, 255)
STEEL = (121, 121, 121, 255)        # #797979 细亮边
STEEL_LIGHT = (176, 178, 186, 255)
WHITE = (255, 255, 255, 255)
SILVER = (198, 208, 220, 255)
BRONZE = (200, 122, 60, 255)


def ensure_dir(p):
    os.makedirs(p, exist_ok=True)


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def chamfer_points(w, h, cut, corners=(1, 1, 1, 1)):
    """切角矩形：corners = (左上, 右上, 右下, 左下) 是否切角。"""
    tl, tr, br, bl = corners
    c = cut
    pts = []
    pts.append((c if tl else 0, 0))
    pts.append((w - (c if tr else 0), 0))
    if tr:
        pts.append((w, c))
    pts.append((w, h - (c if br else 0)))
    if br:
        pts.append((w - c, h))
    pts.append((c if bl else 0, h))
    if bl:
        pts.append((0, h - c))
    pts.append((0, c if tl else 0))
    return pts


def fill_poly(draw, pts, color):
    draw.polygon(pts, fill=color)


def vgradient(size, top, bottom, cut=None, corners=(1, 1, 1, 1)):
    """竖向渐变 + 切角裁切，返回 RGBA 图。"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = y / max(1, h - 1)
        col = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(4))
        d.line([(0, y), (w, y)], fill=col)
    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    cc = cut if cut is not None else 0
    md.polygon(chamfer_points(w, h, cc, corners), fill=255)
    img.putalpha(mask)
    return img


def diagonal_hatch(size, step=14, color=(255, 255, 255, 14), width=3):
    """斜向排线暗纹（现有 UI 常见装饰）。"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x in range(-h, w + h, step):
        d.line([(x, h), (x + h, 0)], fill=color, width=width)
    return img


def stroke_poly(size, pts, color, width=3):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.line(pts + [pts[0]], fill=color, width=width, joint="curve")
    return img


def corner_ticks(size, color, length=26, width=4, cut=0, inset=8):
    """四角短亮线（科技感 UI 常见）。"""
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    o = inset
    d.line([(o, o + length), (o, o), (o + length, o)], fill=color, width=width)
    d.line([(w - o - length, o), (w - o, o), (w - o, o + length)], fill=color, width=width)
    d.line([(w - o - length, h - o), (w - o, h - o), (w - o, h - o - length)], fill=color, width=width)
    d.line([(o, h - o - length), (o, h - o), (o + length, h - o)], fill=color, width=width)
    return img


def paste_alpha(base, layer):
    base.alpha_composite(layer)
    return base


# ================================================================ 面板件
def make_title_banner(w=560, h=132):
    """标题条：中间金色渐变牌 + 两侧斜切翼 + 深色描边。"""
    img = canvas(w, h)
    cut = 26
    # 外框（深色+亮边）
    outer = vgradient((w, h), (44, 30, 66, 255), (24, 18, 36, 255), cut=cut,
                      corners=(1, 1, 1, 1))
    img.alpha_composite(outer)
    # 内部渐变（暗紫）
    inner = vgradient((w - 8, h - 8), (58, 40, 92, 255), (30, 22, 46, 255), cut=cut - 4)
    img.alpha_composite(inner, (4, 4))
    # 斜向排线
    hatch = diagonal_hatch((w - 24, h - 24), step=16, color=(255, 255, 255, 12), width=2)
    img.alpha_composite(hatch, (12, 12))
    # 中央金色菱形装饰
    d = ImageDraw.Draw(img)
    cx, cy = w // 2, h // 2
    # 上下细金线
    d.line([(60, cy + 34), (w - 60, cy + 34)], fill=(255, 204, 0, 120), width=2)
    # 亮边描边
    outline = stroke_poly((w, h), chamfer_points(w - 2, h - 2, cut - 1), (150, 110, 210, 210), 2)
    img.alpha_composite(outline, (1, 1))
    # 四角金饰
    for sx, sy in ((0, 0), (1, 0), (0, 1), (1, 1)):
        bx = 10 if sx == 0 else w - 42
        by = 8 if sy == 0 else h - 26
        d.polygon([(bx, by), (bx + 32, by), (bx + 22, by + 6), (bx + 8, by + 6)],
                  fill=(255, 204, 0, 200))
    return img


def make_row_plate(w=920, h=104, kind="normal"):
    """排行条目底板。kind: normal / self / top1 / top2 / top3"""
    img = canvas(w, h)
    cut = 16
    if kind == "normal":
        base = vgradient((w, h), (40, 30, 58, 235), (24, 18, 36, 235), cut=cut)
        edge = (108, 92, 150, 170)
        accent = (150, 110, 210, 160)
    elif kind == "self":
        base = vgradient((w, h), (92, 68, 24, 245), (52, 38, 12, 245), cut=cut)
        edge = GOLD
        accent = GOLD
    elif kind == "top1":
        base = vgradient((w, h), (96, 72, 18, 245), (44, 32, 8, 245), cut=cut)
        edge = GOLD
        accent = GOLD_PALE
    elif kind == "top2":
        base = vgradient((w, h), (72, 78, 92, 245), (30, 34, 44, 245), cut=cut)
        edge = SILVER
        accent = SILVER
    else:  # top3
        base = vgradient((w, h), (92, 58, 30, 245), (38, 24, 14, 245), cut=cut)
        edge = BRONZE
        accent = (238, 168, 110, 255)
    img.alpha_composite(base)
    # 左侧强调条（斜切）
    d = ImageDraw.Draw(img)
    d.polygon([(0, 0), (10, 0), (0, h)], fill=accent)
    # 亮边
    img.alpha_composite(stroke_poly((w, h), chamfer_points(w - 2, h - 2, cut - 1), edge, 2), (1, 1))
    # 右侧斜向排线
    hatch = diagonal_hatch((170, h - 12), step=12, color=(255, 255, 255, 16), width=2)
    mask = Image.new("L", (170, h - 12), 0)
    ImageDraw.Draw(mask).polygon([(40, 0), (170, 0), (170, h - 12), (0, h - 12)], fill=255)
    hatch.putalpha(Image.composite(hatch.getchannel("A"), Image.new("L", hatch.size, 0), mask))
    img.alpha_composite(hatch, (w - 180, 6))
    return img


def make_rank_badge(n, size=88):
    """名次牌：1/2/3 金银铜，其余钢色六边形。"""
    s = size
    img = canvas(s, s)
    d = ImageDraw.Draw(img)
    if n == 1:
        c1, c2, edge = (255, 214, 64, 255), (150, 96, 0, 255), GOLD_PALE
    elif n == 2:
        c1, c2, edge = (222, 232, 244, 255), (92, 106, 124, 255), WHITE
    elif n == 3:
        c1, c2, edge = (232, 150, 88, 255), (110, 58, 24, 255), (255, 206, 160, 255)
    else:
        c1, c2, edge = (78, 84, 104, 255), (32, 36, 48, 255), STEEL
    # 六边形底
    r = s * 0.46
    cx = cy = s / 2
    hexpts = [(cx + r * math.cos(math.radians(90 + 60 * i)),
               cy - r * math.sin(math.radians(90 + 60 * i))) for i in range(6)]
    for y in range(s):
        t = y / max(1, s - 1)
        col = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))
        d.line([(0, y), (s, y)], fill=col)
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).polygon(hexpts, fill=255)
    img.putalpha(mask)
    img.alpha_composite(stroke_poly((s, s), hexpts, edge, 3))
    return img


def make_tab_chip(w=248, h=92, state="normal"):
    img = canvas(w, h)
    cut = 18
    if state == "on":
        base = vgradient((w, h), (255, 214, 64, 255), (196, 132, 0, 255), cut=cut)
        edge = (255, 246, 190, 255)
        tick = (255, 255, 255, 210)
    else:
        base = vgradient((w, h), (44, 32, 64, 235), (22, 16, 34, 235), cut=cut)
        edge = (118, 100, 158, 190)
        tick = (150, 130, 200, 120)
    img.alpha_composite(base)
    img.alpha_composite(stroke_poly((w, h), chamfer_points(w - 2, h - 2, cut - 1), edge, 2), (1, 1))
    d = ImageDraw.Draw(img)
    d.line([(cut + 10, h - 12), (w - cut - 10, h - 12)], fill=tick, width=2)
    return img


def make_entry_icon(size=112):
    """登录页入口按钮：地球 + 小旗。"""
    s = size
    img = canvas(s, s)
    d = ImageDraw.Draw(img)
    cx = cy = s / 2
    r = s * 0.38
    # 外圈（金色细环）
    d.ellipse([cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3], outline=(255, 204, 0, 235), width=3)
    # 地球本体：暗紫球 + 青色经纬
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(38, 26, 59, 255), outline=(0, 208, 232, 220), width=3)
    # 经线（椭圆）
    for k in (0.55, 0.9):
        d.ellipse([cx - r * k, cy - r, cx + r * k, cy + r], outline=(0, 208, 232, 150), width=2)
    # 纬线
    for dy in (-0.55, 0.0, 0.55):
        rr = r * math.sqrt(max(0.0, 1 - dy * dy))
        d.line([(cx - rr, cy + dy * r), (cx + rr, cy + dy * r)], fill=(0, 208, 232, 150), width=2)
    # 球面高光
    hl = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([cx - r * 0.72, cy - r * 0.8, cx + r * 0.1, cy - r * 0.15],
                               fill=(255, 255, 255, 34))
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    hl.putalpha(Image.composite(hl.getchannel("A"), Image.new("L", (s, s), 0), mask))
    img.alpha_composite(hl)

    # 右上角小旗（圆角小旗 + 斜切金边，与排行旗帜同语言）
    fw, fh = int(s * 0.52), int(s * 0.36)
    fx, fy = s - fw - 2, 0
    img.alpha_composite(compose_flag(build_cn, fw, fh), (fx, fy))
    return img


def make_close_button(size=96):
    s = size
    img = canvas(s, s)
    d = ImageDraw.Draw(img)
    # 斜切方底
    pts = chamfer_points(s - 4, s - 4, 16)
    grad = vgradient((s - 4, s - 4), (52, 38, 74, 245), (26, 20, 38, 245), cut=16)
    img.alpha_composite(grad, (2, 2))
    img.alpha_composite(stroke_poly((s - 4, s - 4), pts, (150, 130, 190, 220), 2), (2, 2))
    d = ImageDraw.Draw(img)
    m = 30
    d.line([(m, m), (s - m, s - m)], fill=(238, 236, 246, 255), width=7)
    d.line([(s - m, m), (m, s - m)], fill=(238, 236, 246, 255), width=7)
    return img


def make_self_plate(w=920, h=116):
    """底部「我的排名」条：金色切角 + 内外双描边。"""
    img = canvas(w, h)
    cut = 20
    base = vgradient((w, h), (104, 78, 20, 248), (48, 34, 10, 248), cut=cut)
    img.alpha_composite(base)
    img.alpha_composite(stroke_poly((w, h), chamfer_points(w - 2, h - 2, cut - 1), GOLD, 3), (1, 1))
    inner = stroke_poly((w - 16, h - 16), chamfer_points(w - 16, h - 16, cut - 8),
                        (255, 236, 150, 90), 2)
    img.alpha_composite(inner, (8, 8))
    hatch = diagonal_hatch((w - 30, h - 30), step=18, color=(255, 214, 64, 16), width=3)
    img.alpha_composite(hatch, (15, 15))
    return img


def make_scroll_mask(w=900, h=1000):
    """滚动区遮罩：顶部/底部渐隐（作为 Image 的 alpha 用）。"""
    img = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    d = ImageDraw.Draw(img)
    fade = 90
    for i in range(fade):
        a = int(255 * i / fade)
        d.line([(0, i), (w, i)], fill=(255, 255, 255, a))
        d.line([(0, h - 1 - i), (w, h - 1 - i)], fill=(255, 255, 255, a))
    return img


def make_panel_board(w=940, h=1440):
    """排行榜主面板底板：深紫渐变 + 四角切角 + 亮边 + 顶部紫光带 + 斜排线。"""
    img = canvas(w, h)
    cut = 34
    base = vgradient((w, h), (40, 29, 60, 246), (16, 12, 24, 250), cut=cut)
    img.alpha_composite(base)
    # 顶部紫色光带（斜切）
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(90):
        a = int(58 * (1 - i / 90.0))
        gd.line([(0, 14 + i), (w, 14 + i)], fill=(159, 90, 253, a))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(chamfer_points(w, h, cut), fill=255)
    glow.putalpha(Image.composite(glow.getchannel("A"), Image.new("L", (w, h), 0), mask))
    img.alpha_composite(glow)
    # 底部暗压
    dark = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dark)
    for i in range(240):
        a = int(90 * (i / 240.0))
        dd.line([(0, h - 1 - i), (w, h - 1 - i)], fill=(8, 6, 14, a))
    dark.putalpha(Image.composite(dark.getchannel("A"), Image.new("L", (w, h), 0), mask))
    img.alpha_composite(dark)
    # 斜排线暗纹
    hatch = diagonal_hatch((w, h), step=26, color=(255, 255, 255, 7), width=3)
    hatch.putalpha(Image.composite(hatch.getchannel("A"), Image.new("L", (w, h), 0), mask))
    img.alpha_composite(hatch)
    # 亮边
    img.alpha_composite(stroke_poly((w, h), chamfer_points(w - 2, h - 2, cut - 1),
                                    (150, 110, 210, 210), 2), (1, 1))
    # 内描边（更细）
    ins = 10
    img.alpha_composite(stroke_poly((w - ins * 2, h - ins * 2),
                                    chamfer_points(w - ins * 2, h - ins * 2, cut - ins + 2),
                                    (255, 204, 0, 46), 2), (ins, ins))
    return img


def make_select_board(w=940, h=1120):
    """旗帜选择弹窗底板。"""
    img = canvas(w, h)
    cut = 28
    base = vgradient((w, h), (44, 32, 66, 248), (18, 14, 28, 250), cut=cut)
    img.alpha_composite(base)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).polygon(chamfer_points(w, h, cut), fill=255)
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(70):
        a = int(52 * (1 - i / 70.0))
        gd.line([(0, 12 + i), (w, 12 + i)], fill=(0, 208, 232, a))
    glow.putalpha(Image.composite(glow.getchannel("A"), Image.new("L", (w, h), 0), mask))
    img.alpha_composite(glow)
    img.alpha_composite(stroke_poly((w, h), chamfer_points(w - 2, h - 2, cut - 1),
                                    (0, 208, 232, 170), 2), (1, 1))
    return img


def make_flag_selected(w=176, h=176):
    """旗帜选中框：金色棱形高亮框（叠在旗帜下方）。"""
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    pad = 6
    # 外发光
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rounded_rectangle([pad - 2, pad - 2, w - pad + 1, h - pad + 1], radius=16,
                         outline=(255, 214, 64, 90), width=8)
    glow = glow.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(glow)
    # 主边框
    d.rounded_rectangle([pad, pad, w - pad - 1, h - pad - 1], radius=14,
                        outline=(255, 214, 64, 255), width=4)
    # 四角切角小三角
    for cx, cy, dx, dy in ((pad, pad, 1, 1), (w - pad, pad, -1, 1),
                           (pad, h - pad, 1, -1), (w - pad, h - pad, -1, -1)):
        d.polygon([(cx, cy), (cx + dx * 26, cy), (cx, cy + dy * 26)], fill=(255, 236, 150, 255))
    # 右下角对勾
    d.line([(w - 52, h - 34), (w - 38, h - 20), (w - 18, h - 48)], fill=(255, 236, 150, 255), width=6)
    return img


# ================================================================ 旗帜
FLAG_W, FLAG_H = 132, 88


def make_flag_frame(w=FLAG_W, h=FLAG_H):
    """圆角小旗底框：深描边 + 斜切金边 + 右侧切角。"""
    img = canvas(w, h)
    pad = 3
    iw, ih = w - pad * 2, h - pad * 2
    # 外描边（深色圆角矩形）
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=11, fill=NAVY_DEEP)
    # 内层（金边）
    d.rounded_rectangle([pad, pad, w - pad - 1, h - pad - 1], radius=9, fill=GOLD)
    # 裁剪出旗面区域（比金边再内缩，形成斜切金边）
    art = Image.new("RGBA", (iw - 8, ih - 8), (0, 0, 0, 0))
    # 斜切：右上/左下切角
    d2 = ImageDraw.Draw(art)
    d2.rounded_rectangle([0, 0, art.width - 1, art.height - 1], radius=6, fill=(0, 0, 0, 255))
    return img, art, (pad + 4, pad + 4)


def compose_flag(art_builder, w=FLAG_W, h=FLAG_H):
    """把旗面画进「圆角小旗 + 斜切金边」的框里。"""
    img = canvas(w, h)
    pad = 3
    # 深色外描边
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=12, fill=(10, 8, 16, 255))
    # 金色边框层
    d.rounded_rectangle([pad, pad, w - 1 - pad, h - 1 - pad], radius=10, fill=GOLD)
    # 金边斜切高光（左上亮、右下暗）
    gd = ImageDraw.Draw(img)
    gd.line([(pad + 4, pad + 2), (w - pad - 26, pad + 2)], fill=GOLD_PALE, width=2)
    gd.line([(pad + 26, h - pad - 3), (w - pad - 4, h - pad - 3)], fill=GOLD_DEEP, width=2)

    # 旗面
    inset = pad + 5
    aw, ah = w - inset * 2, h - inset * 2
    art = Image.new("RGBA", (aw, ah), (0, 0, 0, 0))
    ad = ImageDraw.Draw(art)
    ad.rounded_rectangle([0, 0, aw - 1, ah - 1], radius=6, fill=(255, 255, 255, 255))
    art = art_builder(aw, ah, art)

    # 切角遮罩（右上、左下各切一刀 → 旗帜动感）
    mask = Image.new("L", (aw, ah), 0)
    md = ImageDraw.Draw(mask)
    c = 10
    md.polygon([(0, 0), (aw - c, 0), (aw, c), (aw, ah), (c, ah), (0, ah - c)], fill=255)
    art.putalpha(Image.composite(art.getchannel("A"), Image.new("L", (aw, ah), 0), mask))
    img.alpha_composite(art, (inset, inset))

    # 斜向高光（玻璃质感）
    gloss = Image.new("RGBA", (aw, ah), (0, 0, 0, 0))
    ImageDraw.Draw(gloss).polygon([(0, 0), (aw * 0.62, 0), (0, ah * 0.78)],
                                  fill=(255, 255, 255, 26))
    gloss.putalpha(Image.composite(gloss.getchannel("A"), Image.new("L", (aw, ah), 0), mask))
    img.alpha_composite(gloss, (inset, inset))

    # 内阴影边（旗面压深 1px 描边）
    img.alpha_composite(stroke_poly((aw, ah), [(0, 0), (aw - c, 0), (aw, c), (aw, ah), (c, ah), (0, ah - c)],
                                    (10, 8, 16, 150), 2), (inset, inset))
    return img


def hbands(colors):
    """横条纹旗。"""
    def build(w, h, art):
        d = ImageDraw.Draw(art)
        n = len(colors)
        for i, col in enumerate(colors):
            y0 = int(round(h * i / n))
            y1 = int(round(h * (i + 1) / n))
            d.rectangle([0, y0, w, y1], fill=col)
        return art
    return build


def vbands(colors):
    """竖条纹旗。"""
    def build(w, h, art):
        d = ImageDraw.Draw(art)
        n = len(colors)
        for i, col in enumerate(colors):
            x0 = int(round(w * i / n))
            x1 = int(round(w * (i + 1) / n))
            d.rectangle([x0, 0, x1, h], fill=col)
        return art
    return build


def star_points(cx, cy, r_out, r_in, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180.0 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def build_cn(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(206, 44, 54))
    s = h * 0.26
    d.polygon(star_points(w * 0.16, h * 0.30, s, s * 0.42), fill=(255, 214, 0))
    for i, (fx, fy) in enumerate([(0.30, 0.13), (0.36, 0.24), (0.36, 0.38), (0.30, 0.50)]):
        ss = h * 0.085
        d.polygon(star_points(w * fx, h * fy, ss, ss * 0.42), fill=(255, 214, 0))
    return art


def build_tw(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(206, 44, 54))
    d.rectangle([0, 0, w * 0.52, h * 0.52], fill=(24, 60, 140))
    # 白日（简化为圆 + 12 道芒）
    cx, cy, r = w * 0.26, h * 0.26, h * 0.17
    for i in range(12):
        a = math.radians(i * 30)
        d.line([(cx + r * 1.05 * math.cos(a), cy + r * 1.05 * math.sin(a)),
                (cx + r * 1.62 * math.cos(a), cy + r * 1.62 * math.sin(a))],
               fill=(255, 255, 255), width=3)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 255, 255))
    return art


def build_hk(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(206, 44, 54))
    cx, cy = w / 2, h / 2
    r = h * 0.24
    # 紫荆花：五片花瓣
    for i in range(5):
        a = math.radians(-90 + i * 72)
        px, py = cx + r * math.cos(a), cy + r * math.sin(a)
        d.ellipse([px - r * 0.46, py - r * 0.46, px + r * 0.46, py + r * 0.46], fill=(255, 255, 255))
    d.ellipse([cx - r * 0.2, cy - r * 0.2, cx + r * 0.2, cy + r * 0.2], fill=(206, 44, 54))
    return art


def build_jp(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    r = h * 0.30
    d.ellipse([w / 2 - r, h / 2 - r, w / 2 + r, h / 2 + r], fill=(188, 0, 45))
    return art


def build_kr(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    cx, cy = w / 2, h / 2
    r = h * 0.24
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(205, 46, 58))
    d.pieslice([cx - r, cy - r, cx + r, cy + r], 180, 360, fill=(0, 71, 160))
    d.ellipse([cx - r * 0.5, cy - r, cx + r * 0.5, cy], fill=(205, 46, 58))
    d.ellipse([cx - r * 0.5, cy, cx + r * 0.5, cy + r], fill=(0, 71, 160))
    for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        bx = cx + dx * r * 1.95 - 10
        by = cy + dy * r * 1.5 - 4
        for k in range(3):
            d.line([(bx, by + k * 4), (bx + 20, by + k * 4)], fill=(20, 20, 20), width=2)
    return art


def build_us(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    stripes = 13
    for i in range(stripes):
        if i % 2 == 0:
            y0 = int(h * i / stripes)
            y1 = int(h * (i + 1) / stripes)
            d.rectangle([0, y0, w, y1], fill=(178, 34, 52))
    d.rectangle([0, 0, w * 0.42, h * 0.54], fill=(22, 45, 96))
    for r_ in range(4):
        for c_ in range(5):
            x = 8 + c_ * (w * 0.42 - 16) / 5 + (w * 0.042 if r_ % 2 else 0)
            y = 8 + r_ * (h * 0.54 - 16) / 4
            s = 3.2
            d.polygon(star_points(x, y, s, s * 0.42), fill=(255, 255, 255))
    return art


def build_gb(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(1, 33, 105))
    # 对角线（简化：白 + 红）
    d.line([(0, 0), (w, h)], fill=(255, 255, 255), width=max(4, int(h * 0.22)))
    d.line([(w, 0), (0, h)], fill=(255, 255, 255), width=max(4, int(h * 0.22)))
    d.line([(0, 0), (w, h)], fill=(200, 16, 46), width=max(2, int(h * 0.11)))
    d.line([(w, 0), (0, h)], fill=(200, 16, 46), width=max(2, int(h * 0.11)))
    d.rectangle([0, 0, w * 0.5, h * 0.54], fill=(1, 33, 105))
    d.line([(0, 0), (w * 0.5, h * 0.54)], fill=(255, 255, 255), width=2)
    d.line([(w * 0.5, 0), (0, h * 0.54)], fill=(255, 255, 255), width=2)
    d.line([(0, h * 0.27), (w * 0.5, h * 0.27)], fill=(255, 255, 255), width=max(3, int(h * 0.16)))
    d.line([(w * 0.25, 0), (w * 0.25, h * 0.54)], fill=(255, 255, 255), width=max(3, int(h * 0.16)))
    d.line([(0, h * 0.27), (w * 0.5, h * 0.27)], fill=(200, 16, 46), width=max(2, int(h * 0.08)))
    d.line([(w * 0.25, 0), (w * 0.25, h * 0.54)], fill=(200, 16, 46), width=max(2, int(h * 0.08)))
    return art


def build_de(w, h, art):
    return hbands([(20, 20, 20), (221, 0, 0), (255, 206, 0)])(w, h, art)


def build_fr(w, h, art):
    return vbands([(0, 35, 149), (250, 250, 250), (237, 41, 57)])(w, h, art)


def build_it(w, h, art):
    return vbands([(0, 146, 70), (250, 250, 250), (206, 43, 55)])(w, h, art)


def build_es(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(198, 11, 30))
    d.rectangle([0, h * 0.25, w, h * 0.75], fill=(255, 196, 0))
    d.ellipse([w * 0.28, h * 0.40, w * 0.36, h * 0.60], fill=(198, 11, 30))
    return art


def build_ru(w, h, art):
    return hbands([(250, 250, 250), (0, 57, 166), (213, 43, 30)])(w, h, art)


def build_br(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(0, 155, 58))
    d.polygon([(w / 2, h * 0.12), (w * 0.9, h / 2), (w / 2, h * 0.88), (w * 0.1, h / 2)],
              fill=(254, 223, 0))
    r = h * 0.21
    d.ellipse([w / 2 - r, h / 2 - r, w / 2 + r, h / 2 + r], fill=(0, 39, 118))
    return art


def build_ca(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    d.rectangle([0, 0, w * 0.26, h], fill=(215, 20, 26))
    d.rectangle([w * 0.74, 0, w, h], fill=(215, 20, 26))
    d.polygon([(w / 2, h * 0.20), (w * 0.58, h * 0.62), (w * 0.42, h * 0.62)], fill=(215, 20, 26))
    return art


def build_au(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(0, 36, 125))
    for x, y in ((w * 0.66, h * 0.42), (w * 0.84, h * 0.62), (w * 0.74, h * 0.80), (w * 0.60, h * 0.68)):
        d.polygon(star_points(x, y, 5, 2.1), fill=(250, 250, 250))
    d.rectangle([0, 0, w * 0.42, h * 0.5], fill=(0, 36, 125))
    d.line([(0, 0), (w * 0.42, h * 0.5)], fill=(250, 250, 250), width=3)
    d.line([(w * 0.42, 0), (0, h * 0.5)], fill=(250, 250, 250), width=3)
    return art


def build_mx(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, int(w / 3), h], fill=(0, 104, 71))
    d.rectangle([int(w / 3), 0, int(w * 2 / 3), h], fill=(250, 250, 250))
    d.rectangle([int(w * 2 / 3), 0, w, h], fill=(206, 17, 38))
    d.ellipse([w / 2 - h * 0.10, h / 2 - h * 0.10, w / 2 + h * 0.10, h / 2 + h * 0.10],
              fill=(140, 100, 40))
    return art


def build_ar(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(117, 170, 219))
    d.rectangle([0, h / 3, w, h * 2 / 3], fill=(250, 250, 250))
    d.ellipse([w / 2 - h * 0.09, h / 2 - h * 0.09, w / 2 + h * 0.09, h / 2 + h * 0.09],
              fill=(247, 179, 43))
    return art


def build_sg(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(237, 57, 56))
    d.rectangle([0, 0, w, h / 2], fill=(237, 57, 56))
    d.rectangle([0, h / 2, w, h], fill=(250, 250, 250))
    cx, cy, r = w * 0.22, h * 0.26, h * 0.16
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(250, 250, 250))
    d.ellipse([cx - r + 5, cy - r, cx + r + 5, cy + r], fill=(237, 57, 56))
    for x, y in ((w * 0.34, h * 0.16), (w * 0.40, h * 0.26), (w * 0.34, h * 0.36),
                 (w * 0.28, h * 0.26)):
        d.polygon(star_points(x, y, 3.4, 1.4), fill=(250, 250, 250))
    return art


def build_th(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(247, 212, 177))
    d.rectangle([0, h * 0.17, w, h * 0.83], fill=(166, 27, 41))
    d.rectangle([0, h * 0.34, w, h * 0.66], fill=(36, 26, 82))
    return art


def build_vn(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(218, 37, 29))
    d.polygon(star_points(w / 2, h / 2, h * 0.28, h * 0.115), fill=(255, 255, 0))
    return art


def build_id(w, h, art):
    return hbands([(206, 17, 38), (250, 250, 250)])(w, h, art)


def build_my(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    for i in range(14):
        if i % 2 == 0:
            d.rectangle([0, h * i / 14, w, h * (i + 1) / 14], fill=(204, 28, 43))
    d.rectangle([0, 0, w * 0.46, h * 0.5], fill=(1, 0, 102))
    d.rectangle([0, 0, w * 0.46, h * 0.5], fill=(1, 0, 102))
    cx, cy, r = w * 0.2, h * 0.25, h * 0.13
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 204, 0))
    d.ellipse([cx - r + 5, cy - r, cx + r + 5, cy + r], fill=(1, 0, 102))
    d.polygon(star_points(w * 0.31, h * 0.25, 6, 2.5), fill=(255, 204, 0))
    return art


def build_ph(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(0, 56, 168))
    d.rectangle([0, 0, w, h / 2], fill=(0, 56, 168))
    d.rectangle([0, h / 2, w, h], fill=(206, 17, 38))
    d.polygon([(w * 0.22, h * 0.12), (w * 0.26, h * 0.12), (w * 0.36, h * 0.5),
               (w * 0.26, h * 0.5)], fill=(250, 250, 250))
    d.ellipse([w * 0.12, h * 0.16, w * 0.2, h * 0.3], fill=(252, 209, 22))
    return art


def build_in(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(255, 153, 51))
    d.rectangle([0, h / 3, w, h * 2 / 3], fill=(250, 250, 250))
    d.rectangle([0, h * 2 / 3, w, h], fill=(19, 136, 8))
    cx, cy, r = w / 2, h / 2, h * 0.13
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(0, 0, 128), width=2)
    for i in range(24):
        a = math.radians(i * 15)
        d.line([(cx + r * 0.18 * math.cos(a), cy + r * 0.18 * math.sin(a)),
                (cx + r * 0.92 * math.cos(a), cy + r * 0.92 * math.sin(a))],
               fill=(0, 0, 128), width=1)
    return art


def build_tr(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(227, 10, 23))
    cx, cy, r = w * 0.42, h / 2, h * 0.24
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(250, 250, 250))
    d.ellipse([cx - r + 7, cy - r, cx + r + 7, cy + r], fill=(227, 10, 23))
    d.polygon(star_points(w * 0.60, h / 2, h * 0.14, h * 0.056), fill=(250, 250, 250))
    return art


def build_sa(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(0, 122, 61))
    d.rectangle([0, h * 0.72, w, h * 0.80], fill=(250, 250, 250))
    d.rectangle([w * 0.14, h * 0.34, w * 0.86, h * 0.36], fill=(250, 250, 250))
    d.rectangle([w * 0.14, h * 0.44, w * 0.74, h * 0.46], fill=(250, 250, 250))
    return art


def build_ae(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    d.rectangle([0, 0, w, h / 3], fill=(0, 115, 47))
    d.rectangle([0, h * 2 / 3, w, h], fill=(0, 0, 0))
    d.rectangle([0, 0, w * 0.26, h], fill=(255, 0, 0))
    return art


# ---------------------------------------------------------------- 欧洲逐国 / 补充国家
# 背景：最早只画了一面「欧洲其他(eu)」代表整个欧洲，玩家无法表达自己是哪国人。
# 这里按国家逐个补旗。132x88 的尺寸下细节不可辨，一律用「色块 + 关键符号」的简化画法，
# 与既有旗帜（gb/us/br 等）保持同一抽象层级。

def ratio_bands(colors, ratios, vertical=False):
    """按比例分条（用于拉脱维亚 2:1:2、哥伦比亚 2:1:1 这类非等分旗）。"""
    def build(w, h, art):
        d = ImageDraw.Draw(art)
        tot = float(sum(ratios))
        acc = 0.0
        for col, r in zip(colors, ratios):
            if vertical:
                d.rectangle([w * acc / tot, 0, w * (acc + r) / tot, h], fill=col)
            else:
                d.rectangle([0, h * acc / tot, w, h * (acc + r) / tot], fill=col)
            acc += r
        return art
    return build


def nordic(bg, cross, inner=None, vx=0.36, t=0.26, it=0.13):
    """北欧十字旗；inner 再叠一层内十字（挪威 / 冰岛）。"""
    def build(w, h, art):
        d = ImageDraw.Draw(art)
        d.rectangle([0, 0, w, h], fill=bg)
        bt = t * h
        d.rectangle([0, h / 2 - bt / 2, w, h / 2 + bt / 2], fill=cross)
        d.rectangle([vx * w - bt / 2, 0, vx * w + bt / 2, h], fill=cross)
        if inner is not None:
            bi = it * h
            d.rectangle([0, h / 2 - bi / 2, w, h / 2 + bi / 2], fill=inner)
            d.rectangle([vx * w - bi / 2, 0, vx * w + bi / 2, h], fill=inner)
        return art
    return build


def shield(d, cx, cy, sw, sh, fill, edge=None):
    """盾牌形（下方收尖），东欧三国旗上放国徽用。"""
    pts = [(cx - sw / 2, cy - sh / 2), (cx + sw / 2, cy - sh / 2),
           (cx + sw / 2, cy + sh * 0.08), (cx, cy + sh / 2), (cx - sw / 2, cy + sh * 0.08)]
    d.polygon(pts, fill=fill)
    if edge is not None:
        d.line(pts + [pts[0]], fill=edge, width=1)


def crescent(d, cx, cy, r, fill, bg):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill)
    d.ellipse([cx - r * 0.72, cy - r, cx + r * 1.28, cy + r], fill=bg)


def build_gr(w, h, art):
    """希腊：蓝白 9 条 + 左上蓝底白十字。"""
    d = ImageDraw.Draw(art)
    blue, white = (13, 94, 175), (250, 250, 250)
    n = 9
    d.rectangle([0, 0, w, h], fill=blue)
    for i in range(1, n, 2):
        d.rectangle([0, h * i / n, w, h * (i + 1) / n], fill=white)
    cw, ch = w * 0.37, h * 5 / 9
    d.rectangle([0, 0, cw, ch], fill=blue)
    t = ch / 5 * 1.6
    d.rectangle([0, ch / 2 - t / 2, cw, ch / 2 + t / 2], fill=white)
    d.rectangle([cw / 2 - t / 2, 0, cw / 2 + t / 2, ch], fill=white)
    return art


def build_nl(w, h, art):
    return hbands([(174, 28, 40), (250, 250, 250), (33, 70, 139)])(w, h, art)


def build_be(w, h, art):
    return vbands([(20, 20, 20), (253, 218, 36), (239, 51, 64)])(w, h, art)


def build_lu(w, h, art):
    return hbands([(239, 51, 64), (250, 250, 250), (0, 161, 222)])(w, h, art)


def build_ch(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(213, 43, 30))
    t = h * 0.22
    d.rectangle([w / 2 - t / 2, h * 0.16, w / 2 + t / 2, h * 0.84], fill=(250, 250, 250))
    d.rectangle([w * 0.30, h / 2 - t / 2, w * 0.70, h / 2 + t / 2], fill=(250, 250, 250))
    return art


def build_at(w, h, art):
    return hbands([(237, 41, 57), (250, 250, 250), (237, 41, 57)])(w, h, art)


def build_se(w, h, art):
    return nordic((0, 106, 167), (254, 204, 0))(w, h, art)


def build_no(w, h, art):
    return nordic((186, 12, 47), (250, 250, 250), inner=(0, 32, 91), t=0.30, it=0.15)(w, h, art)


def build_dk(w, h, art):
    return nordic((200, 16, 46), (250, 250, 250), t=0.22)(w, h, art)


def build_fi(w, h, art):
    return nordic((250, 250, 250), (0, 53, 128), t=0.24)(w, h, art)


def build_is(w, h, art):
    return nordic((2, 82, 156), (250, 250, 250), inner=(215, 40, 40), t=0.30, it=0.15)(w, h, art)


def build_pl(w, h, art):
    return hbands([(250, 250, 250), (220, 20, 60)])(w, h, art)


def build_pt(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(218, 41, 28))
    d.rectangle([0, 0, w * 0.40, h], fill=(0, 102, 0))
    cx, cy = w * 0.40, h / 2
    r = h * 0.26
    d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 204, 0), width=max(2, int(h * 0.06)))
    d.rectangle([cx - r * 0.42, cy - r * 0.45, cx + r * 0.42, cy + r * 0.45], fill=(250, 250, 250))
    d.rectangle([cx - r * 0.42, cy - r * 0.14, cx + r * 0.42, cy + r * 0.14], fill=(206, 17, 38))
    return art


def build_ie(w, h, art):
    return vbands([(22, 155, 98), (250, 250, 250), (255, 136, 62)])(w, h, art)


def build_cz(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    d.rectangle([0, h / 2, w, h], fill=(215, 20, 26))
    d.polygon([(0, 0), (w * 0.46, h / 2), (0, h)], fill=(17, 69, 126))
    return art


def build_hu(w, h, art):
    return hbands([(206, 41, 57), (250, 250, 250), (67, 111, 77)])(w, h, art)


def build_ro(w, h, art):
    return vbands([(0, 43, 127), (252, 209, 22), (206, 17, 38)])(w, h, art)


def build_bg(w, h, art):
    return hbands([(250, 250, 250), (0, 150, 110), (214, 38, 42)])(w, h, art)


def build_ua(w, h, art):
    return hbands([(0, 87, 183), (255, 215, 0)])(w, h, art)


def build_sk(w, h, art):
    d = ImageDraw.Draw(art)
    hbands([(250, 250, 250), (11, 78, 162), (238, 28, 37)])(w, h, art)
    shield(d, w * 0.38, h * 0.52, w * 0.22, h * 0.58, (238, 28, 37), edge=(250, 250, 250))
    d.rectangle([w * 0.36, h * 0.34, w * 0.40, h * 0.68], fill=(250, 250, 250))
    d.rectangle([w * 0.32, h * 0.44, w * 0.44, h * 0.48], fill=(250, 250, 250))
    return art


def build_si(w, h, art):
    d = ImageDraw.Draw(art)
    hbands([(250, 250, 250), (0, 92, 163), (238, 28, 37)])(w, h, art)
    shield(d, w * 0.38, h * 0.50, w * 0.20, h * 0.54, (0, 92, 163), edge=(250, 250, 250))
    d.polygon([(w * 0.38, h * 0.34), (w * 0.46, h * 0.62), (w * 0.30, h * 0.62)],
              fill=(250, 250, 250))
    return art


def build_hr(w, h, art):
    d = ImageDraw.Draw(art)
    hbands([(255, 0, 0), (250, 250, 250), (0, 45, 161)])(w, h, art)
    cx, cy, sw, sh = w * 0.38, h * 0.52, w * 0.20, h * 0.56
    shield(d, cx, cy, sw, sh, (250, 250, 250), edge=(255, 0, 0))
    # 红白棋盘格（简化为 4x4）
    cell = sw / 4
    for r_ in range(4):
        for c_ in range(4):
            if (r_ + c_) % 2 == 0:
                d.rectangle([cx - sw / 2 + c_ * cell, cy - sh / 2 + r_ * cell * 0.9,
                             cx - sw / 2 + (c_ + 1) * cell, cy - sh / 2 + (r_ + 1) * cell * 0.9],
                            fill=(255, 0, 0))
    return art


def build_rs(w, h, art):
    d = ImageDraw.Draw(art)
    hbands([(198, 54, 60), (12, 64, 118), (250, 250, 250)])(w, h, art)
    shield(d, w * 0.38, h * 0.50, w * 0.20, h * 0.54, (198, 54, 60), edge=(250, 250, 250))
    d.rectangle([w * 0.36, h * 0.36, w * 0.40, h * 0.64], fill=(250, 250, 250))
    d.rectangle([w * 0.33, h * 0.44, w * 0.43, h * 0.47], fill=(250, 250, 250))
    return art


def build_lt(w, h, art):
    return hbands([(253, 185, 19), (0, 106, 68), (193, 39, 45)])(w, h, art)


def build_lv(w, h, art):
    return ratio_bands([(157, 34, 53), (250, 250, 250), (157, 34, 53)], [2, 1, 2])(w, h, art)


def build_ee(w, h, art):
    return hbands([(0, 114, 206), (20, 20, 20), (250, 250, 250)])(w, h, art)


def build_by(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(0, 170, 60))
    d.rectangle([0, 0, w, h * 0.66], fill=(204, 0, 0))
    # 左侧织带（红底白菱形）
    sw = w * 0.14
    d.rectangle([0, 0, sw, h], fill=(250, 250, 250))
    step = h / 5
    for i in range(5):
        y = i * step + step / 2
        d.polygon([(sw / 2, y - step * 0.34), (sw * 0.86, y), (sw / 2, y + step * 0.34),
                   (sw * 0.14, y)], fill=(204, 0, 0))
    return art


def build_md(w, h, art):
    d = ImageDraw.Draw(art)
    vbands([(0, 70, 174), (247, 212, 0), (204, 9, 47)])(w, h, art)
    shield(d, w / 2, h * 0.52, w * 0.16, h * 0.46, (247, 212, 0), edge=(120, 80, 30))
    d.ellipse([w / 2 - 4, h * 0.46, w / 2 + 4, h * 0.56], fill=(120, 80, 30))
    return art


def build_al(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(229, 0, 20))
    cx, cy = w / 2, h / 2
    d.polygon([(cx - 2, cy - h * 0.20), (cx - w * 0.20, cy - h * 0.30),
               (cx - w * 0.13, cy + h * 0.04), (cx - 2, cy + h * 0.02)], fill=(20, 20, 20))
    d.polygon([(cx + 2, cy - h * 0.20), (cx + w * 0.20, cy - h * 0.30),
               (cx + w * 0.13, cy + h * 0.04), (cx + 2, cy + h * 0.02)], fill=(20, 20, 20))
    d.polygon([(cx - w * 0.06, cy - h * 0.18), (cx + w * 0.06, cy - h * 0.18),
               (cx, cy + h * 0.22)], fill=(20, 20, 20))
    return art


def build_ba(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(0, 31, 120))
    d.polygon([(w * 0.16, 0), (w * 0.74, 0), (w * 0.16, h)], fill=(247, 207, 0))
    for i in range(6):
        f = i / 6.0
        x = w * 0.16 + (w * 0.58) * f + w * 0.06
        y = h * f
        d.polygon(star_points(x, y, 5, 2.2), fill=(250, 250, 250))
    return art


def build_mk(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(214, 0, 0))
    cx, cy = w / 2, h / 2
    d.ellipse([cx - h * 0.22, cy - h * 0.22, cx + h * 0.22, cy + h * 0.22], fill=(247, 224, 0))
    for i in range(8):
        a = math.radians(i * 45)
        d.line([(cx + h * 0.18 * math.cos(a), cy + h * 0.18 * math.sin(a)),
                (cx + h * 0.95 * math.cos(a), cy + h * 0.95 * math.sin(a))],
               fill=(247, 224, 0), width=max(2, int(h * 0.09)))
    return art


def build_ge(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    t = h * 0.16
    d.rectangle([0, h / 2 - t / 2, w, h / 2 + t / 2], fill=(255, 0, 0))
    d.rectangle([w / 2 - t / 2, 0, w / 2 + t / 2, h], fill=(255, 0, 0))
    for fx, fy in ((0.22, 0.24), (0.78, 0.24), (0.22, 0.76), (0.78, 0.76)):
        cx, cy = w * fx, h * fy
        s = h * 0.10
        d.rectangle([cx - s, cy - h * 0.028, cx + s, cy + h * 0.028], fill=(255, 0, 0))
        d.rectangle([cx - w * 0.03, cy - s, cx + w * 0.03, cy + s], fill=(255, 0, 0))
    return art


def build_am(w, h, art):
    return hbands([(217, 0, 18), (0, 51, 160), (242, 168, 0)])(w, h, art)


def build_az(w, h, art):
    d = ImageDraw.Draw(art)
    hbands([(0, 151, 195), (227, 19, 51), (0, 151, 57)])(w, h, art)
    cx, cy = w * 0.44, h / 2
    crescent(d, cx, cy, h * 0.13, (250, 250, 250), (227, 19, 51))
    d.polygon(star_points(cx + h * 0.17, cy, h * 0.075, h * 0.030), fill=(250, 250, 250))
    return art


def build_mt(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    d.rectangle([w / 2, 0, w, h], fill=(207, 20, 43))
    cx, cy, s = w * 0.24, h * 0.26, h * 0.09
    d.rectangle([cx - s / 2, cy - s, cx + s / 2, cy + s], fill=(150, 150, 150))
    d.rectangle([cx - s, cy - s / 2, cx + s, cy + s / 2], fill=(150, 150, 150))
    return art


def build_cy(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    d.polygon([(w * 0.40, h * 0.30), (w * 0.56, h * 0.34), (w * 0.62, h * 0.52),
               (w * 0.44, h * 0.58), (w * 0.34, h * 0.44)], fill=(78, 145, 60))
    d.line([(w * 0.32, h * 0.70), (w * 0.44, h * 0.66)], fill=(78, 145, 60), width=2)
    d.line([(w * 0.56, h * 0.66), (w * 0.68, h * 0.70)], fill=(78, 145, 60), width=2)
    return art


def build_nz(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(0, 36, 125))
    for x, y in ((w * 0.66, h * 0.40), (w * 0.84, h * 0.60), (w * 0.72, h * 0.80), (w * 0.58, h * 0.64)):
        d.polygon(star_points(x, y, 6.4, 2.6), fill=(250, 250, 250))
        d.polygon(star_points(x, y, 4.4, 1.8), fill=(200, 16, 46))
    d.rectangle([0, 0, w * 0.42, h * 0.5], fill=(0, 36, 125))
    d.line([(0, 0), (w * 0.42, h * 0.5)], fill=(250, 250, 250), width=3)
    d.line([(w * 0.42, 0), (0, h * 0.5)], fill=(250, 250, 250), width=3)
    return art


def build_za(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h * 0.5], fill=(224, 60, 49))
    d.rectangle([0, h * 0.5, w, h], fill=(0, 35, 149))
    # 中央 Y 形绿带（白/金描边）
    d.rectangle([0, h * 0.5 - h * 0.20, w, h * 0.5 + h * 0.20], fill=(250, 250, 250))
    d.rectangle([0, h * 0.5 - h * 0.155, w, h * 0.5 + h * 0.155], fill=(255, 184, 28))
    d.rectangle([0, h * 0.5 - h * 0.12, w, h * 0.5 + h * 0.12], fill=(0, 122, 77))
    # 左侧三角（白/金/绿）
    d.polygon([(0, 0), (w * 0.40, h / 2), (0, h)], fill=(250, 250, 250))
    d.polygon([(0, h * 0.06), (w * 0.36, h / 2), (0, h * 0.94)], fill=(255, 184, 28))
    d.polygon([(0, h * 0.12), (w * 0.32, h / 2), (0, h * 0.88)], fill=(0, 122, 77))
    return art


def build_eg(w, h, art):
    d = ImageDraw.Draw(art)
    hbands([(206, 17, 38), (250, 250, 250), (20, 20, 20)])(w, h, art)
    cx, cy = w / 2, h / 2
    d.polygon([(cx, cy - h * 0.14), (cx + w * 0.05, cy + h * 0.06),
               (cx - w * 0.05, cy + h * 0.06)], fill=(196, 150, 30))
    d.rectangle([cx - w * 0.09, cy + h * 0.02, cx + w * 0.09, cy + h * 0.07], fill=(196, 150, 30))
    return art


def build_il(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    blue = (0, 56, 184)
    d.rectangle([0, h * 0.10, w, h * 0.22], fill=blue)
    d.rectangle([0, h * 0.78, w, h * 0.90], fill=blue)
    cx, cy, r = w / 2, h / 2, h * 0.20
    up = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
          for a in (-90, 30, 150, -90)]
    dn = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
          for a in (90, 210, 330, 90)]
    d.line(up, fill=blue, width=2)
    d.line(dn, fill=blue, width=2)
    return art


def build_cl(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(250, 250, 250))
    d.rectangle([0, h * 0.5, w, h], fill=(218, 41, 28))
    d.rectangle([0, 0, w * 0.34, h * 0.5], fill=(0, 57, 166))
    d.polygon(star_points(w * 0.17, h * 0.25, h * 0.13, h * 0.052), fill=(250, 250, 250))
    return art


def build_co(w, h, art):
    return ratio_bands([(252, 209, 22), (0, 56, 147), (206, 17, 38)], [2, 1, 1])(w, h, art)


def build_pe(w, h, art):
    return vbands([(217, 16, 35), (250, 250, 250), (217, 16, 35)])(w, h, art)


def build_pk(w, h, art):
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(1, 65, 28))
    d.rectangle([0, 0, w * 0.26, h], fill=(250, 250, 250))
    crescent(d, w * 0.58, h / 2, h * 0.22, (250, 250, 250), (1, 65, 28))
    d.polygon(star_points(w * 0.68, h * 0.42, h * 0.09, h * 0.036), fill=(250, 250, 250))
    return art


def build_mo(w, h, art):
    """中国澳门：绿底 + 白色三瓣莲花 + 桥/水纹 + 五角星。

    132x88 下只能表达「绿底 + 白花 + 金星」这个识别特征，花瓣用三片高椭圆，
    彼此留空隙（否则糊成一个白团），桥面用一条细横线带过。
    """
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(0, 120, 90))
    cx, base = w / 2, h * 0.72
    # (中心偏移, 半宽, 高度)
    for dx, rx, hh in ((-0.155, 0.058, 0.30), (0.0, 0.070, 0.38), (0.155, 0.058, 0.30)):
        px = cx + w * dx
        d.ellipse([px - w * rx, base - h * hh, px + w * rx, base], fill=(250, 250, 250))
    # 桥面 + 水纹
    d.line([(cx - w * 0.28, base + h * 0.06), (cx + w * 0.28, base + h * 0.06)],
           fill=(250, 250, 250), width=3)
    d.line([(cx - w * 0.18, base + h * 0.15), (cx + w * 0.18, base + h * 0.15)],
           fill=(250, 250, 250), width=2)
    # 五角星（一大 + 两侧小）
    d.polygon(star_points(cx, h * 0.16, h * 0.080, h * 0.032), fill=(255, 222, 0))
    for dx in (-0.135, 0.135):
        d.polygon(star_points(cx + w * dx, h * 0.24, h * 0.048, h * 0.019), fill=(255, 222, 0))
    return art


def build_xx(w, h, art):
    """未选择国家：灰底问号旗（占位，避免名字旁空一块）。"""
    d = ImageDraw.Draw(art)
    d.rectangle([0, 0, w, h], fill=(62, 64, 76))
    # 斜向暗纹，与整体 UI 一致
    for i in range(-h, w + h, 14):
        d.line([(i, h), (i + h, 0)], fill=(52, 54, 66), width=3)
    cx, cy = w / 2, h / 2
    q = (196, 198, 210)
    lw = 5
    # 问号：上半弧 + 竖笔 + 圆点
    d.arc([cx - h * 0.17, cy - h * 0.34, cx + h * 0.17, cy + h * 0.04],
          150, 30, fill=q, width=lw)
    d.line([(cx, cy + h * 0.04), (cx, cy + h * 0.20)], fill=q, width=lw)
    d.ellipse([cx - 4, cy + h * 0.28, cx + 4, cy + h * 0.36], fill=q)
    return art


FLAGS = {
    "cn": build_cn, "tw": build_tw, "hk": build_hk, "mo": build_mo, "jp": build_jp,
    "kr": build_kr, "us": build_us, "gb": build_gb, "de": build_de, "fr": build_fr,
    "it": build_it, "es": build_es, "ru": build_ru, "br": build_br, "ca": build_ca,
    "au": build_au, "mx": build_mx, "ar": build_ar, "sg": build_sg, "th": build_th,
    "vn": build_vn, "id": build_id, "my": build_my, "ph": build_ph, "in": build_in,
    "tr": build_tr, "sa": build_sa, "ae": build_ae,
    # 欧洲逐国（取代原先的「欧洲其他 eu」）
    "gr": build_gr, "nl": build_nl, "be": build_be, "lu": build_lu, "ch": build_ch,
    "at": build_at, "se": build_se, "no": build_no, "dk": build_dk, "fi": build_fi,
    "is": build_is, "ie": build_ie, "pt": build_pt, "pl": build_pl, "cz": build_cz,
    "hu": build_hu, "ro": build_ro, "bg": build_bg, "ua": build_ua, "sk": build_sk,
    "si": build_si, "hr": build_hr, "rs": build_rs, "lt": build_lt, "lv": build_lv,
    "ee": build_ee, "by": build_by, "md": build_md, "al": build_al, "ba": build_ba,
    "mk": build_mk, "ge": build_ge, "am": build_am, "az": build_az, "mt": build_mt,
    "cy": build_cy,
    # 其他常见国家/地区
    "nz": build_nz, "za": build_za, "eg": build_eg, "il": build_il, "cl": build_cl,
    "co": build_co, "pe": build_pe, "pk": build_pk,
    "xx": build_xx,
}


# ================================================================ 输出
def save(img, name):
    path = os.path.join(OUT_DIR, name + ".png")
    img.save(path, "PNG", optimize=True)
    print("  %-46s %s" % (name + ".png", img.size))
    return path


def generate(flags_only=False):
    ensure_dir(OUT_DIR)
    if not flags_only:
        print("生成面板件：")
        save(make_panel_board(), "cn2-x1_guojiapaihang_diban")
        save(make_select_board(), "cn2-x1_guojiapaihang_xuanze_diban")
        save(make_flag_selected(), "cn2-x1_guojiapaihang_qizhi_xuanzhong")
        save(make_title_banner(), "cn2-x1_guojiapaihang_biaoti")
        save(make_row_plate(kind="normal"), "cn2-x1_guojiapaihang_tiaomu")
        save(make_row_plate(kind="self"), "cn2-x1_guojiapaihang_tiaomu_ziji")
        save(make_row_plate(kind="top1"), "cn2-x1_guojiapaihang_tiaomu_1")
        save(make_row_plate(kind="top2"), "cn2-x1_guojiapaihang_tiaomu_2")
        save(make_row_plate(kind="top3"), "cn2-x1_guojiapaihang_tiaomu_3")
        save(make_self_plate(), "cn2-x1_guojiapaihang_wode")
        save(make_tab_chip(state="on"), "cn2-x1_guojiapaihang_yetan_xuanzhong")
        save(make_tab_chip(state="normal"), "cn2-x1_guojiapaihang_yetan_weixuanzhong")
        save(make_entry_icon(), "cn2-x1_guojiapaihang_rukou")
        save(make_close_button(), "cn2-x1_guojiapaihang_guanbi")
        for n in (1, 2, 3):
            save(make_rank_badge(n), "cn2-x1_guojiapaihang_paiming_%02d" % n)
        save(make_rank_badge(0), "cn2-x1_guojiapaihang_paiming_00")

    print("生成国家旗帜：")
    for iso, builder in sorted(FLAGS.items()):
        save(compose_flag(builder), "cn2-guoqi_" + iso)


# ================================================================ 预览图（给用户看效果）
def render_preview(path):
    W, H = 1080, 1920
    bg = Image.new("RGBA", (W, H), (14, 12, 20, 255))
    # 背景：复用主界面背景图（若存在）
    mainbg = os.path.join(ROOT, "Assets/ManagedResources/Atlas/LoginPanelAtlas/cn2-x1_zhujiemian_beijing.png")
    if os.path.exists(mainbg):
        im = Image.open(mainbg).convert("RGB")
        scale = max(W / im.width, H / im.height)
        im = im.resize((int(im.width * scale) + 1, int(im.height * scale) + 1), Image.LANCZOS)
        left = (im.width - W) // 2
        top = (im.height - H) // 2
        bg = im.crop((left, top, left + W, top + H)).convert("RGBA")
    # 压暗
    shade = Image.new("RGBA", (W, H), (10, 8, 18, 170))
    bg.alpha_composite(shade)

    d = ImageDraw.Draw(bg)

    # ---------------- 面板主体
    pw, ph = 940, 1440
    px = (W - pw) // 2
    py = 250
    panel = vgradient((pw, ph), (36, 26, 54, 246), (18, 14, 28, 250), cut=34)
    bg.alpha_composite(panel, (px, py))
    bg.alpha_composite(stroke_poly((pw, ph), chamfer_points(pw - 2, ph - 2, 33), (150, 110, 210, 200), 2),
                       (px + 1, py + 1))

    # 顶部标题条
    banner = make_title_banner(560, 132)
    bg.alpha_composite(banner, ((W - 560) // 2, py - 66))

    # 关闭按钮
    close = make_close_button(96)
    bg.alpha_composite(close, (px + pw - 110, py + 12))

    # 页签
    chip_on = make_tab_chip(248, 92, "on")
    chip_off = make_tab_chip(248, 92, "normal")
    tabs = ["全服排行", "本国排行"]
    tx = px + 40
    for i, t in enumerate(tabs):
        img = chip_on if i == 0 else chip_off
        bg.alpha_composite(img, (tx + i * 262, py + 96))

    # 列表
    row_x = px + 26
    row_w = pw - 52
    top = py + 214
    rows = [
        ("1", "cn", "中国", "1,284,900", 1),
        ("2", "us", "美国", "1,180,420", 2),
        ("3", "jp", "日本", "1,096,330", 3),
        ("4", "kr", "韩国", "1,002,180", 0),
        ("5", "tw", "中国台湾", "948,560", 0),
        ("6", "de", "德国", "902,140", 0),
        ("7", "fr", "法国", "877,300", 0),
        ("8", "gb", "英国", "851,020", 0),
        ("9", "br", "巴西", "795,480", 0),
        ("10", "th", "泰国", "742,660", 0),
        ("11", "sg", "新加坡", "701,240", 0),
        ("12", "ru", "俄罗斯", "668,900", 0),
    ]
    flags_cache = {iso: compose_flag(FLAGS[iso]) for iso in set(r[1] for r in rows)}

    row_h = 104
    gap = 10
    font_cn = ImageFontLoader(size=34)
    font_num = ImageFontLoader(size=30)
    font_small = ImageFontLoader(size=26)

    for i, (rank, iso, name, score, medal) in enumerate(rows):
        y = top + i * (row_h + gap)
        kind = "normal" if medal == 0 else ("top%d" % medal)
        plate = make_row_plate(row_w, row_h, kind)
        bg.alpha_composite(plate, (row_x, y))
        # 名次
        if medal:
            badge = make_rank_badge(medal, 88)
            bg.alpha_composite(badge, (row_x + 14, y + 8))
        else:
            d.text((row_x + 42, y + row_h / 2), _fit(str(rank), font_num),
                   font=font_num, fill=(206, 202, 224, 255), anchor="mm")
        # 旗帜
        f = flags_cache[iso]
        bg.alpha_composite(f, (row_x + 108, y + (row_h - f.height) // 2))
        # 国家名
        d.text((row_x + 268, y + row_h / 2 - 12), name, font=font_cn, fill=(240, 238, 250, 255),
               anchor="lm")
        d.text((row_x + 268, y + row_h / 2 + 22), "ROLE · LV.120", font=font_small,
               fill=(150, 140, 180, 255), anchor="lm")
        # 战力
        d.text((row_x + row_w - 34, y + row_h / 2), score, font=font_num,
               fill=(255, 214, 64, 255) if medal else (222, 220, 236, 255), anchor="rm")

    # 我的排名
    selfy = py + ph - 150 - 24
    self_plate = make_self_plate(row_w, 116)
    bg.alpha_composite(self_plate, (row_x, selfy))
    d.text((row_x + 34, selfy + 58), "我的排名", font=font_small, fill=(255, 226, 150, 255), anchor="lm")
    d.text((row_x + 168, selfy + 58), "第 37 名", font=font_cn, fill=(255, 255, 255, 255), anchor="lm")
    f = flags_cache["cn"]
    bg.alpha_composite(f, (row_x + 300, selfy + (116 - f.height) // 2))
    d.text((row_x + 452, selfy + 58), "中国", font=font_cn, fill=(240, 238, 250, 255), anchor="lm")
    d.text((row_x + row_w - 34, selfy + 58), "612,480", font=font_num, fill=(255, 214, 64, 255),
           anchor="rm")

    # 底部说明
    d.text((W / 2, py + ph + 40), "国家排行榜 · 启动页入口弹窗（预览）", font=font_small,
           fill=(190, 184, 214, 255), anchor="mm")

    # ---------------- 左侧：登录页入口按钮示意
    icon = make_entry_icon(112)
    btn_w, btn_h = 220, 132
    btn = vgradient((btn_w, btn_h), (52, 38, 74, 250), (24, 18, 36, 250), cut=22)
    bx, by = 40, H - 300
    bg.alpha_composite(btn, (bx, by))
    bg.alpha_composite(stroke_poly((btn_w, btn_h), chamfer_points(btn_w - 2, btn_h - 2, 21), GOLD, 3),
                       (int(bx + 1), int(by + 1)))
    bg.alpha_composite(icon, (int(bx + btn_w / 2 - 56), int(by + 12)))
    d.text((int(bx + btn_w / 2), int(by + 108)), "国家排行", font=ImageFontLoader(size=26),
           fill=(255, 214, 64, 255), anchor="mm")

    # ---------------- 右侧：旗帜一览
    fx0, fy0 = 40, 120
    d.text((fx0, fy0 - 40), "旗帜图标（圆角小旗 + 斜切金边）", font=ImageFontLoader(size=24),
           fill=(200, 196, 226, 255), anchor="lm")
    cols = 4
    for i, iso in enumerate(sorted(FLAGS.keys())[:16]):
        cx = fx0 + (i % cols) * 150
        cy = fy0 + (i // cols) * 110
        bg.alpha_composite(flags_cache.get(iso) or compose_flag(FLAGS[iso]), (cx, cy))

    bg.convert("RGB").save(path, "JPEG", quality=92)
    print("预览图：", path)


def _fit(s, font):
    return s


def ImageFontLoader(size=34):
    from PIL import ImageFont
    for p in ("/System/Library/Fonts/Hiragino Sans GB.ttc",
              "/System/Library/Fonts/PingFang.ttc",
              "/System/Library/Fonts/STHeiti Medium.ttc"):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size=size)
            except Exception:
                continue
    return ImageFont.load_default()


def main():
    generate(flags_only="--flags-only" in sys.argv)
    if "--preview" in sys.argv:
        out = os.path.join(ROOT, "_output/country_rank_preview.jpg")
        ensure_dir(os.path.dirname(out))
        render_preview(out)


if __name__ == "__main__":
    main()
