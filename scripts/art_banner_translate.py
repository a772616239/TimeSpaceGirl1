"""把战令横幅的中文美术字换成英文版（ArtFont_zh/OperatingPanelAtlas -> ArtFont_en/...）。

思路：
1. 用「亮像素 + 蓝色像素」自动圈出中文标题/光带/文案的污染区（内容驱动，不用矩形硬切）。
2. 用逐行中位色重建底板渐变，再镜像平铺回填六边形纹理，得到干净底板。
3. 在干净底板上排英文文案（白字 + 蓝色辉光），最后贴回原图 alpha。

用法：
    python scripts/art_banner_translate.py \
        --src Assets/ManagedResources/ArtFont_zh/OperatingPanelAtlas/cn2-X1_zhanling_miwu_bg_zh.png \
        --out Assets/ManagedResources/ArtFont_en/OperatingPanelAtlas/cn2-X1_zhanling_miwu_bg_en.png \
        --title "The Mist Plan"

同款横幅（mota_bg / yiduan_bg2）可直接复用，改 --src/--out/--title 即可。
"""
import argparse
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONT_BOLD = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'

ZONE = (92, 336, 0, 342)           # y0,y1,x0,x1 允许重建的范围
CTRL_ROWS = [58, 214, 336]         # 干净色标行
HEX_SRC = (336, 396, 0, 330)       # 六边形纹理样张


def row_median(a, y, x0=0, x1=330):
    row = a[y, x0:x1]
    sel = row[row.max(axis=1) < 110]
    if len(sel) < 20:
        sel = row
    return np.median(sel, axis=0)


def mirror_tile(tile, H, W):
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


def contaminated_mask(a):
    """亮像素(白/黄/粉字) + 蓝色像素(光带、蓝斜杠) 合并成污染区。"""
    h, w, _ = a.shape
    R, G, B = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    mx = np.maximum(np.maximum(R, G), B)
    blueness = B - np.maximum(R, G)
    y0, y1, x0, x1 = ZONE
    zone = np.zeros((h, w), bool)
    zone[y0:y1, x0:x1] = True
    m = ((mx > 110) | (blueness > 60)) & zone
    m = cv2.dilate(m.astype(np.uint8), np.ones((15, 15), np.uint8))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((25, 25), np.uint8))
    m[~zone] = 0
    return m


def rebuild_panel(a):
    y0, y1, x0, x1 = ZONE
    out = a.astype(float).copy()

    # 逐行取“未污染像素”的中位色作为底板基准，再纵向平滑；比三点插值更贴合原渐变
    contam = contaminated_mask(a)
    base = np.zeros((y1 - y0, 3))
    for i, y in enumerate(range(y0, y1)):
        row = a[y, x0:x1]
        dark = row.max(axis=1) < 110
        ok = (~contam[y, x0:x1]) & dark
        if ok.sum() >= 30:
            base[i] = np.median(row[ok], axis=0)
    # 整行都被污染的，用上下相邻行线性补齐
    for i in range(len(base)):
        if base[i].sum() == 0:
            prev = next((j for j in range(i - 1, -1, -1) if base[j].sum() > 0), None)
            nxt = next((j for j in range(i + 1, len(base)) if base[j].sum() > 0), None)
            if prev is not None and nxt is not None:
                w = (i - prev) / (nxt - prev)
                base[i] = base[prev] * (1 - w) + base[nxt] * w
            elif prev is not None:
                base[i] = base[prev]
            else:
                base[i] = base[nxt]
    for c in range(3):
        base[:, c] = cv2.GaussianBlur(base[:, c].reshape(-1, 1), (0, 0), 8).ravel()
    patch = np.repeat(base[:, None, :], x1 - x0, axis=1)

    hy0, hy1, hx0, hx1 = HEX_SRC
    sample = a[hy0:hy1, hx0:hx1].astype(float)
    detail = sample - cv2.GaussianBlur(sample, (0, 0), 6)
    patch = patch + mirror_tile(detail, y1 - y0, x1 - x0) * 0.75

    m = contam[y0:y1, x0:x1].astype(np.float32)
    alpha = cv2.GaussianBlur(m, (0, 0), 5)

    # 区域四边再收一圈，避免出现硬边
    H, W = alpha.shape
    fy = np.ones(H, np.float32)
    for i in range(8):
        fy[i] = fy[-1 - i] = i / 8
    # 右段让位给 inpaint（那一段蓝光带压在蓝色背景上，不能拿暗板去填）
    fx = np.ones(W, np.float32)
    for i in range(W):
        gx = x0 + i
        if gx >= 342:
            fx[i] = 0.0
        elif gx > 332:
            fx[i] = (342 - gx) / 10.0
    alpha = alpha * fy[:, None] * fx[None, :]
    alpha = alpha[..., None]

    out[y0:y1, x0:x1] = out[y0:y1, x0:x1] * (1 - alpha) + patch * alpha
    return np.clip(out, 0, 255).astype(np.uint8)


def fit_font(draw, text, max_w, start, min_size=18):
    size = start
    while size > min_size:
        f = ImageFont.truetype(FONT_BOLD, size)
        box = draw.textbbox((0, 0), text, font=f)
        if box[2] - box[0] <= max_w:
            return f, box
        size -= 1
    f = ImageFont.truetype(FONT_BOLD, min_size)
    return f, draw.textbbox((0, 0), text, font=f)


def draw_text_layer(img, title):
    w, h = img.size
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    core = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dg, dc = ImageDraw.Draw(glow), ImageDraw.Draw(core)

    left, maxw = 24, 330
    items = [(title, 34, 124, 'small'),
             ('UNLOCK', 54, 166, 'big'),
             ('ADVANCED', 54, 217, 'big'),
             ('BATTLE PASS', 52, 268, 'big')]

    for text, size, top, kind in items:
        f, box = fit_font(dc, text, maxw, size)
        x, y = left - box[0], top - box[1]
        if kind == 'big':
            dg.text((x, y), text, font=f, fill=(70, 130, 255, 255))
        dc.text((x, y), text, font=f, fill=(255, 255, 255, 255))

    glow = glow.filter(ImageFilter.GaussianBlur(9))
    base = img.convert('RGBA')
    base = Image.alpha_composite(base, glow)
    base = Image.alpha_composite(base, glow)
    base = Image.alpha_composite(base, core)
    return base.convert('RGB')


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', required=True, help='中文版 png')
    ap.add_argument('--out', required=True, help='英文版输出路径')
    ap.add_argument('--title', default='The Mist Plan', help='小标题，如 The Mist Plan')
    ap.add_argument('--preview', default=None, help='可选：另存一张预览')
    args = ap.parse_args()

    src_im = Image.open(args.src)
    alpha_orig = src_im.getchannel('A') if src_im.mode == 'RGBA' else None
    a = np.asarray(src_im.convert('RGB'))
    panel = rebuild_panel(a)
    img = draw_text_layer(Image.fromarray(panel), args.title)
    if alpha_orig is not None:                     # 原图带透明边，alpha 要保留
        img = img.convert('RGB')
        img.putalpha(alpha_orig)
    img.save(args.out)
    if args.preview:
        img.convert('RGB').save(args.preview)
    print('saved', args.out)
