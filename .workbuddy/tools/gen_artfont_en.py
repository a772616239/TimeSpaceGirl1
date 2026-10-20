#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
美术字图英文化生成器（ArtFont_zh -> ArtFont_en）

用法:
    python3 gen_artfont_en.py [--only <关键字>] [--preview <目录>]

设计:
  * 纯白字/透明底的 tab 图 -> 整图重建
  * 带背景美术的横幅/插画 -> 先按“逐行中值”擦除原中文字形，再叠加英文（保留原美术）
  * 样式全部由 STYLE 表驱动，便于逐图微调
"""
import os, sys, json, shutil, argparse, random, string
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = '/Users/wangxufeng/Documents/TimeSpaceGirl1/Assets/ManagedResources'
SRC = os.path.join(ROOT, 'ArtFont_zh/AdjutantActivityPanelAtlas')
DST = os.path.join(ROOT, 'ArtFont_en/AdjutantActivityPanelAtlas')

FONT = '/System/Library/Fonts/HelveticaNeue.ttc'
W_BOLD, W_BLACK = 1, 9          # Helvetica Neue Bold / Condensed Black
SHEAR = 0.18                    # 与原繁体中文一致的斜体角度(≈10.2°)

# ---------------------------------------------------------------- 基础工具

_font_cache = {}


def F(size, weight=W_BOLD):
    key = (size, weight)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(FONT, size, index=weight)
    return _font_cache[key]


def text_mask(text, px=300, weight=W_BOLD, shear=SHEAR):
    """渲染文字为 L 掩膜（已斜切、已按墨迹裁切）"""
    f = F(px, weight)
    pad = 120
    w = int(f.getlength(text)) + pad * 2
    h = px * 2 + pad * 2
    img = Image.new('L', (w, h), 0)
    ImageDraw.Draw(img).text((pad, pad), text, font=f, fill=255)
    bb = img.getbbox()
    if bb is None:
        raise ValueError('empty text: %r' % text)
    img = img.crop(bb)
    if abs(shear) > 1e-3:
        w0, h0 = img.size
        new_w = int(w0 + abs(shear) * h0) + 2
        img = img.transform((new_w, h0), Image.AFFINE,
                            (1, -shear, shear * h0 / 2, 0, 1, 0),
                            resample=Image.BICUBIC, fillcolor=0)
        img = img.crop(img.getbbox())
    return img


def fit_mask(text, box, weight=W_BOLD, squeeze=1.0, align='center', vcenter=True):
    """把文字缩放到 box=(x0,y0,x1,y1) 内，返回 (mask, (x,y))"""
    x0, y0, x1, y1 = box
    bw, bh = max(1, x1 - x0), max(1, y1 - y0)
    m = text_mask(text, weight=weight)
    sc = min(bw * squeeze / m.width, bh / m.height)
    w, h = max(1, int(round(m.width * sc))), max(1, int(round(m.height * sc)))
    m = m.resize((w, h), Image.LANCZOS)
    if align == 'center':
        x = x0 + (bw - w) // 2
    elif align == 'right':
        x = x1 - w
    else:
        x = x0
    y = y0 + (bh - h) // 2 if vcenter else y1 - h
    return m, (x, y)


def dilate(mask, r):
    if r <= 0:
        return mask
    a = np.array(mask)
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (r * 2 + 1, r * 2 + 1))
    return Image.fromarray(cv2.dilate(a, k))


def gradient(size, stops):
    """stops: [(pos0..1, (r,g,b)), ...] 竖向渐变"""
    w, h = size
    ys = np.linspace(0, 1, h)
    pos = np.array([s[0] for s in stops], float)
    cols = np.array([s[1] for s in stops], float)
    out = np.zeros((h, 3), float)
    for c in range(3):
        out[:, c] = np.interp(ys, pos, cols[:, c])
    arr = np.repeat(out[:, None, :], w, axis=1)
    return Image.fromarray(arr.astype(np.uint8), 'RGB')


def solid(color, mask, a=255):
    """用掩膜生成纯色 RGBA 图层（尺寸与掩膜一致）"""
    im = Image.new('RGBA', mask.size, color + (0,))
    im.putalpha(mask.point(lambda v: int(v * a / 255)) if a < 255 else mask)
    return im


def styled(text, box, fill, stroke=None, stroke_r=0, glow=None, glow_r=0,
           shadow=None, shadow_off=(0, 0), weight=W_BOLD, squeeze=1.0,
           align='center', alpha=255):
    """
    生成带描边/发光/投影的文字图层。
    fill: (r,g,b) 或 [(pos,(r,g,b)),...] 渐变
    """
    m, (x, y) = fit_mask(text, box, weight=weight, squeeze=squeeze, align=align)
    h = m.height
    r_out = stroke_r if stroke_r > 0 else max(2, int(round(h * 0.055)))
    m_dil = dilate(m, r_out)
    if glow_r <= 0:
        glow_r = max(4, int(round(h * 0.30)))

    pad = int(max(r_out, glow_r) * 3 + 8)
    W, H = m.width + pad * 2, m.height + pad * 2
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))

    def put(img, off=(0, 0)):
        layer.alpha_composite(img, (pad + off[0], pad + off[1]))

    # 外发光
    if glow:
        g = Image.new('L', (W, H), 0)
        g.paste(m_dil, (pad, pad))
        g = g.filter(ImageFilter.GaussianBlur(glow_r))
        put(solid(glow[:3], g, glow[3]))
    # 投影
    if shadow:
        g = Image.new('L', (W, H), 0)
        g.paste(m_dil, (pad, pad))
        g = g.filter(ImageFilter.GaussianBlur(max(1, h // 40)))
        put(solid(shadow[:3], g, shadow[3]), shadow_off)
    # 描边
    if stroke:
        put(solid(stroke, m_dil))
    # 填充
    if isinstance(fill, list):
        grad = gradient((m.width, m.height), fill)
        fi = Image.new('RGBA', m.size, (0, 0, 0, 0))
        fi.paste(grad, (0, 0), m)
        put(fi)
    else:
        put(solid(fill, m))

    if alpha < 255:
        layer.putalpha(layer.getchannel('A').point(lambda v: int(v * alpha / 255)))
    return layer, (x - pad, y - pad)


def stamp(base, layer, pos):
    """支持负偏移与越界裁切的 alpha 合成"""
    x, y = int(pos[0]), int(pos[1])
    sx0, sy0 = max(0, -x), max(0, -y)
    dx, dy = max(0, x), max(0, y)
    w = min(layer.width - sx0, base.width - dx)
    h = min(layer.height - sy0, base.height - dy)
    if w <= 0 or h <= 0:
        return
    part = layer.crop((sx0, sy0, sx0 + w, sy0 + h))
    base.alpha_composite(part, (dx, dy))


# ---------------------------------------------------------------- 擦除原字

def erase_glyphs(img, boxes, bright=150, blur_rows=0):
    """
    在 boxes 内按“逐行背景中值”抹掉亮色字形，保留平涂背景/渐变。
    返回新图（RGBA）。
    """
    arr = np.array(img).astype(np.uint8)
    rgb = arr[:, :, :3].astype(int)
    al = arr[:, :, 3]
    lum = rgb.max(2)

    mask = np.zeros(lum.shape, bool)
    for (x0, y0, x1, y1) in boxes:
        sub = np.zeros_like(mask)
        sub[y0:y1, x0:x1] = True
        mask |= sub
    glyph = (lum > bright) & (al > 120) & mask
    glyph = cv2.dilate(glyph.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)

    out = arr.copy()
    ys, xs = np.nonzero(glyph)
    if len(ys) == 0:
        return img
    y_lo, y_hi = ys.min(), ys.max()
    # 逐行取非字形的中值色（左右各取窗口）
    for y in range(max(0, y_lo - 2), min(lum.shape[0], y_hi + 3)):
        cols = glyph[y]
        if not cols.any():
            continue
        row = arr[y, :, :3].astype(int)
        good = (~glyph[y]) & (al[y] > 200)
        if good.sum() < 20:
            good = al[y] > 200
            if good.sum() < 10:
                continue
        med = np.median(row[good], 0)
        out[y, cols, :3] = med.astype(np.uint8)
    # 轻微竖直平滑，消除行间跳变
    if blur_rows:
        tmp = Image.fromarray(out[:, :, :3]).filter(ImageFilter.GaussianBlur((0, blur_rows)))
        out[:, :, :3] = np.array(tmp)
        out[:, :, :3][~glyph] = arr[:, :, :3][~glyph]
    return Image.fromarray(out, 'RGBA')



def ribbon_polygon(img, x0=240, x1=662, pad=6):
    """用“亮->暗 / 暗->亮”过渡拟合缎带上下边线，返回覆盖多边形的四个角点"""
    lum = np.array(img.convert('RGB')).max(2).astype(int)
    H = lum.shape[0]
    tops, bots = [], []
    for x in range(x0, x1):
        col = lum[:, x]
        t = b = None
        for y in range(3, H - 3):
            if col[y] < 80 and col[y - 3] > 130:
                t = y
                break
        for y in range(H - 4, 2, -1):
            if col[y] < 80 and col[y + 3] > 130:
                b = y
                break
        if t is not None and b is not None and b - t > 40:
            tops.append((x, t))
            bots.append((x, b))

    def robust(pts):
        xs = np.array([p[0] for p in pts], float)
        ys = np.array([p[1] for p in pts], float)
        for _ in range(8):
            k, c = np.polyfit(xs, ys, 1)
            res = np.abs(ys - (k * xs + c))
            keep = res <= np.percentile(res, 80)
            if keep.sum() < 10:
                break
            xs, ys = xs[keep], ys[keep]
        return k, c

    kt, bt = robust(tops)
    kb, bb = robust(bots)
    return [(x0, kt * x0 + bt - pad), (x1, kt * x1 + bt - pad),
            (x1, kb * x1 + bb + pad), (x0, kb * x0 + bb + pad)]


def erase_to_black(img, boxes, cover=None, feather=9):
    """
    横幅场景：
      1) 直接用一条黑色缎带多边形把原中文字形整体盖掉（缎带本身是纯黑，加厚不可见）
      2) 漏在缎带外、压到黄色底上的字形残片（含黑色描边）用 inpaint 抹掉
    cover = (center, (w, h), angle) 旋转矩形
    """
    arr = np.array(img).astype(np.uint8)
    rgb = arr[:, :, :3].astype(int)
    al = arr[:, :, 3]
    lum = rgb.max(2)
    mn = rgb.min(2)

    white = (mn > 150) & (al > 200)
    orange = (rgb[:, :, 0] > 190) & (rgb[:, :, 1] > 60) & (rgb[:, :, 1] < 175) & \
             (rgb[:, :, 2] < 100) & (al > 200)
    glyph = white | orange

    bm = np.zeros(lum.shape, bool)
    for (x0, y0, x1, y1) in boxes:
        bm[y0:y1, x0:x1] = True
    glyph &= bm
    glyph_big = cv2.dilate(glyph.astype(np.uint8),
                           cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (feather * 2 + 1,) * 2)).astype(bool)

    out = arr.copy()
    rmask = np.zeros(lum.shape, np.uint8)
    if cover:
        poly = np.array(cover, np.int32) if isinstance(cover[0], (list, tuple)) \
            else cv2.boxPoints(cover).astype(np.int32)
        cv2.fillPoly(rmask, [poly], 1)
        out[rmask.astype(bool), :3] = (0, 0, 0)

    rest = glyph_big & (rmask == 0)
    if rest.any():
        bgr = cv2.cvtColor(out[:, :, :3], cv2.COLOR_RGB2BGR)
        bgr = cv2.inpaint(bgr, (rest.astype(np.uint8) * 255), 7, cv2.INPAINT_TELEA)
        out[:, :, :3] = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    return Image.fromarray(out, 'RGBA')


# ---------------------------------------------------------------- 通用绘制件

def triangle(draw, tip, tail_x, y0, y1, color):
    draw.polygon([(tail_x, y0), (tip, (y0 + y1) / 2), (tail_x, y1)], fill=color)


def plate_polygon(x0, y0, x1, y1, skew=0.18, right_tail=0):
    """斜切平行四边形（模拟原图深色底板）"""
    dx = (y1 - y0) * skew
    pts = [(x0 + dx, y0), (x1 + dx + right_tail, y0),
           (x1, y1), (x0, y1)]
    return pts


# ---------------------------------------------------------------- 各家族出图

def do_tab_unselected(entry):
    W, H = 152, 120
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    l1, p1 = styled(entry['w1'], (4, 8, 142, 70), (255, 255, 255),
                    weight=W_BLACK, squeeze=entry.get('sq1', 0.94), alpha=164)
    stamp(canvas, l1, p1)
    l2, p2 = styled(entry['w2'], (36, 87, 108, 113), (255, 255, 255),
                    weight=W_BOLD, squeeze=entry.get('sq2', 0.96), alpha=164)
    stamp(canvas, l2, p2)
    d = ImageDraw.Draw(canvas)
    tri = (255, 255, 255, 164)
    triangle(d, 10, 23, 92, 107, tri)      # 左箭头 ◀
    triangle(d, 131, 118, 92, 107, tri)    # 右箭头 ▶
    return canvas


def do_tab_selected(entry):
    W, H = 180, 96
    canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    l1, p1 = styled(entry['w1'], (10, 12, 174, 52), (255, 255, 255),
                    weight=W_BLACK, squeeze=entry.get('sq1', 0.9))
    stamp(canvas, l1, p1)
    l2, p2 = styled(entry['w2'], (10, 50, 174, 90), (255, 255, 255),
                    weight=W_BLACK, squeeze=entry.get('sq2', 0.9))
    stamp(canvas, l2, p2)
    return canvas


def do_banner(entry):
    img = Image.open(os.path.join(SRC, entry['file'])).convert('RGBA')
    cover = entry.get('cover') or ribbon_polygon(img, *entry.get('cover_x', (240, 662)))
    img = erase_to_black(img, entry['erase'], cover=cover)
    for t in entry['texts']:
        lay, pos = styled(t['text'], t['box'], t['fill'],
                          stroke=t.get('stroke', (0, 0, 0)),
                          stroke_r=t.get('stroke_r', 0),
                          shadow=t.get('shadow'),
                          shadow_off=t.get('shadow_off', (0, 0)),
                          weight=t.get('weight', W_BLACK),
                          squeeze=t.get('squeeze', 1.0),
                          glow=t.get('glow'), glow_r=t.get('glow_r', 0))
        stamp(img, lay, pos)
    return img


def do_glow_title(entry):
    """深色底板 + 黄光晕的书法字（shenyutiaozhan / xianqulibao / benqixianqu）"""
    src = Image.open(os.path.join(SRC, entry['file'])).convert('RGBA')
    img = erase_glyphs(src, entry['erase'], bright=entry.get('bright', 150))
    for t in entry['texts']:
        lay, pos = styled(t['text'], t['box'], t['fill'],
                          stroke=t['stroke'], stroke_r=t.get('stroke_r', 0),
                          glow=t.get('glow'), glow_r=t.get('glow_r', 0),
                          weight=t.get('weight', W_BLACK),
                          squeeze=t.get('squeeze', 0.95))
        stamp(img, lay, pos)
    return img


# ---------------------------------------------------------------- 配置表

def B(x0, y0, x1, y1):
    return (x0, y0, x1, y1)

WHITE = (255, 255, 255)
LAV = [(0.0, (198, 145, 236)), (0.32, (250, 245, 252)), (0.72, (232, 236, 248)), (1.0, (186, 226, 232))]
GOLD = [(0.0, (255, 205, 26)), (0.28, (255, 246, 154)), (0.62, (255, 253, 220)), (1.0, (255, 214, 42))]
DARKPURPLE = (32, 24, 96)

TABS = [
    dict(file='tab/cn2-X1_xianquhuodong_yeqian_01_zh.png', kind='tab',
         w1='Season', w2='Pioneer'),
    dict(file='tab/cn2-X1_xianquhuodong_yeqian_02_zh.png', kind='tab',
         w1='Oracle', w2='Challenge', sq1=0.86, sq2=0.86),
    dict(file='tab/cn2-X1_xianquhuodong_yeqian_03_zh.png', kind='tab',
         w1='Sacred', w2='Ritual'),
    dict(file='tab/cn2-X1_xianquhuodong_yeqian_04_zh.png', kind='tab',
         w1='Pioneer', w2='Gift', sq1=0.88),
    dict(file='tab/cn2-X1_xianquhuodong_yeqianxuanzhong_01_zh.png', kind='tabsel',
         w1='Season', w2='Pioneer'),
    dict(file='tab/cn2-X1_xianquhuodong_yeqianxuanzhong_02_zh.png', kind='tabsel',
         w1='Oracle', w2='Challenge', sq1=0.8, sq2=0.8),
    dict(file='tab/cn2-X1_xianquhuodong_yeqianxuanzhong_03_zh.png', kind='tabsel',
         w1='Sacred', w2='Ritual'),
    dict(file='tab/cn2-X1_xianquhuodong_yeqianxuanzhong_04_zh.png', kind='tabsel',
         w1='Pioneer', w2='Gift', sq1=0.82),
]

BANNERS = [
    dict(file='cn2-X1_xianquhuodong_duihuanxianqu_zh.png', kind='banner',
         erase=[B(225, 15, 675, 152)],
         cover=((445, 80), (432, 126), -16),
         texts=[dict(text='Redeem', box=B(258, 42, 452, 138),
                     fill=(246, 108, 18), stroke=(0, 0, 0), stroke_r=7,
                     shadow=(110, 40, 0, 110), shadow_off=(7, 7), squeeze=0.95),
                dict(text='Pioneer!', box=B(452, 42, 655, 138),
                     fill=WHITE, stroke=(0, 0, 0), stroke_r=7,
                     shadow=(70, 70, 70, 110), shadow_off=(7, 7), squeeze=0.95)]),
    dict(file='cn2-X1_xianquhuodong_huoqudaoju_zh.png', kind='banner',
         erase=[B(225, 15, 675, 152)],
         cover=((445, 80), (432, 126), -16),
         texts=[dict(text='Get', box=B(258, 42, 420, 138),
                     fill=(246, 108, 18), stroke=(0, 0, 0), stroke_r=7,
                     shadow=(110, 40, 0, 110), shadow_off=(7, 7), squeeze=0.95),
                dict(text='Items!', box=B(420, 42, 655, 138),
                     fill=WHITE, stroke=(0, 0, 0), stroke_r=7,
                     shadow=(70, 70, 70, 110), shadow_off=(7, 7), squeeze=0.95)]),
    dict(file='cn2-X1_xianquhuodong_yiduihuan_zh.png', kind='banner',
         erase=[B(300, 20, 600, 150)],
         cover=((445, 80), (430, 122), -15),
         texts=[dict(text='Redeemed', box=B(320, 45, 580, 132),
                     fill=(236, 236, 238), stroke=(0, 0, 0), stroke_r=7,
                     shadow=(50, 50, 50, 110), shadow_off=(7, 7), squeeze=0.92)]),
]

GLOW = [
    dict(file='cn2-X1_xianquhuodong_shenyutiaozhan_zh.png', kind='glow',
         erase=[B(80, 70, 640, 330)], bright=150,
         texts=[dict(text='Complete', box=B(96, 82, 520, 180), fill=LAV,
                     stroke=DARKPURPLE, stroke_r=10, glow=(255, 236, 150, 110), glow_r=40),
                dict(text='Enjoy Rewards', box=B(180, 205, 620, 305), fill=LAV,
                     stroke=DARKPURPLE, stroke_r=10, glow=(255, 236, 150, 110), glow_r=40)]),
    dict(file='cn2-X1_xianquhuodong_xianqulibao_zh.png', kind='glow',
         erase=[B(80, 70, 640, 330)], bright=150,
         texts=[dict(text='Buy Packs', box=B(96, 82, 520, 180), fill=LAV,
                     stroke=DARKPURPLE, stroke_r=10, glow=(255, 236, 150, 110), glow_r=40),
                dict(text='Reap Rewards', box=B(180, 205, 620, 305), fill=LAV,
                     stroke=DARKPURPLE, stroke_r=10, glow=(255, 236, 150, 110), glow_r=40)]),
    dict(file='cn2-X1_xianquhuodong_benqixianqu_zh.png', kind='glow',
         erase=[B(140, 90, 860, 220), B(30, 250, 860, 340)], bright=150,
         texts=[dict(text='Complete Oracle Challenge', box=B(160, 100, 830, 215), fill=GOLD,
                     stroke=(38, 30, 150), stroke_r=11, glow=(190, 120, 255, 90), glow_r=34,
                     squeeze=0.94),
                dict(text='Redeem Supreme Pioneer', box=B(160, 245, 850, 340), fill=GOLD,
                     stroke=(38, 30, 150), stroke_r=11, glow=(190, 120, 255, 90), glow_r=34,
                     squeeze=0.94)]),
]

ILLU = [
    dict(file='cn2-X1_xianquhuodong_shenshengyishi01_zh.png', kind='glow',
         erase=[B(50, 570, 720, 700), B(180, 690, 880, 800)], bright=150,
         texts=[dict(text='Begin Sacred Ritual', box=B(70, 585, 700, 690), fill=LAV,
                     stroke=(46, 34, 110), stroke_r=9, glow=(150, 120, 255, 60), glow_r=26),
                dict(text='Get Rare Items', box=B(190, 700, 870, 795), fill=LAV,
                     stroke=(46, 34, 110), stroke_r=9, glow=(150, 120, 255, 60), glow_r=26)]),
]

ALL = TABS + BANNERS + GLOW + ILLU


# ---------------------------------------------------------------- 输出

def guid():
    return ''.join(random.choice('0123456789abcdef') for _ in range(32))


def write_meta(png_path):
    src_meta = os.path.join(SRC, os.path.relpath(png_path, DST).replace('_en.png', '_zh.png')) + '.meta'
    dst_meta = png_path + '.meta'
    if not os.path.exists(src_meta):
        return
    txt = open(src_meta, encoding='utf-8').read()
    out = []
    for line in txt.splitlines():
        if line.startswith('guid:'):
            out.append('guid: ' + guid())
        else:
            out.append(line)
    open(dst_meta, 'w', encoding='utf-8').write('\n'.join(out) + '\n')


def ensure_dir(p):
    if os.path.isdir(p):
        return
    os.makedirs(p)
    src_meta = os.path.join(SRC, os.path.relpath(p, DST)) + '.meta'
    dst_meta = p + '.meta'
    if os.path.exists(src_meta) and not os.path.exists(dst_meta):
        txt = open(src_meta, encoding='utf-8').read()
        out = ['guid: ' + guid() if l.startswith('guid:') else l for l in txt.splitlines()]
        open(dst_meta, 'w', encoding='utf-8').write('\n'.join(out) + '\n')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', default=None)
    ap.add_argument('--preview', default=None, help='额外输出深色底预览图')
    args = ap.parse_args()

    ensure_dir(DST)
    ensure_dir(os.path.join(DST, 'tab'))

    for e in ALL:
        if args.only and args.only not in e['file']:
            continue
        kind = e['kind']
        if kind == 'tab':
            img = do_tab_unselected(e)
        elif kind == 'tabsel':
            img = do_tab_selected(e)
        elif kind == 'banner':
            img = do_banner(e)
        else:
            img = do_glow_title(e)

        out = os.path.join(DST, e['file'].replace('_zh.png', '_en.png'))
        os.makedirs(os.path.dirname(out), exist_ok=True)
        img.save(out)
        write_meta(out)
        print('  ->', os.path.relpath(out, ROOT))

        if args.preview:
            os.makedirs(args.preview, exist_ok=True)
            bg = Image.new('RGBA', img.size, (35, 36, 40, 255))
            bg.alpha_composite(img)
            bg.convert('RGB').save(os.path.join(args.preview, os.path.basename(out)))


if __name__ == '__main__':
    main()
