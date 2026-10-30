#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""TIME-SPACE GIRL — 30s vertical promo renderer (1080x1920 @30fps)."""
import os, sys, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance
from functools import lru_cache

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(ROOT)
A = os.path.join(ROOT, "assets")
W, H = 1080, 1920
FPS = 30
DUR = 30.0

INK      = (8, 8, 10)
RED      = (228, 0, 43)
DEEPRED  = (104, 0, 16)
CYAN     = (34, 224, 255)
MAGENTA  = (255, 45, 149)
GOLD     = (255, 196, 64)
WHITE    = (255, 255, 255)

F_DIN   = "/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf"
F_BLACK = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
F_BOLD  = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
F_MONO  = "/System/Library/Fonts/Menlo.ttc"
F_CN    = "/System/Library/Fonts/Hiragino Sans GB.ttc"

def clamp(x, a=0.0, b=1.0): return a if x < a else (b if x > b else x)
def seg(t, t0, t1):
    if t1 <= t0: return 1.0 if t >= t1 else 0.0
    return clamp((t - t0) / (t1 - t0))
def lerp(a, b, k): return a + (b - a) * k
def eo(x): return 1 - (1 - x) ** 3
def eio(x): return 3 * x * x - 2 * x * x * x
def over(p): return 1 + 2.4 * (p - 1) ** 3 + 1.3 * (p - 1) ** 2

@lru_cache(maxsize=1200)
def txt(text, font=F_BLACK, size=100, color=WHITE, tracking=0, index=0,
        stroke=0, stroke_fill=(0, 0, 0, 255)):
    f = ImageFont.truetype(font, size, index=index)
    ws = [f.getlength(c) for c in text]
    total = sum(ws) + tracking * max(0, len(text) - 1)
    asc, desc = f.getmetrics()
    pad = stroke * 2 + 6
    img = Image.new("RGBA", (int(total) + pad * 2 + 4, asc + desc + pad * 2 + 4), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    x, y = pad, pad
    for c, w in zip(text, ws):
        if c != " ":
            d.text((x, y), c, font=f, fill=color, stroke_width=stroke, stroke_fill=stroke_fill)
        x += w + tracking
    return img

def blit(base, im, xy, anchor="lt", alpha=1.0, scale=1.0):
    if alpha <= 0: return
    if scale != 1.0:
        im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))), Image.BILINEAR)
    if alpha < 1.0:
        im = im.copy()
        im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
    x, y = xy
    if anchor[0] == "c": x -= im.width // 2
    elif anchor[0] == "r": x -= im.width
    if anchor[1] == "c": y -= im.height // 2
    elif anchor[1] == "b": y -= im.height
    base.alpha_composite(im, (int(x), int(y)))

def radial(size, color, power=2.0, strength=255, cy=None):
    w, h = size
    y, x = np.ogrid[:h, :w]
    cx = w / 2
    cy = h / 2 if cy is None else cy
    d = np.sqrt(((x - cx) / (w * 0.72)) ** 2 + ((y - cy) / (h * 0.72)) ** 2)
    a = np.clip(1 - d, 0, 1) ** power * strength
    img = Image.new("RGBA", size, color + (0,))
    img.putalpha(Image.fromarray(a.astype(np.uint8)))
    return img

@lru_cache(maxsize=1)
def L_scan():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(0, H, 4):
        d.line([(0, y), (W, y)], fill=(0, 0, 0, 15))
    return im

@lru_cache(maxsize=1)
def L_vig():
    w, h = W, H
    y, x = np.ogrid[:h, :w]
    d = np.sqrt(((x - w / 2) / (w * 0.60)) ** 2 + ((y - h / 2) / (h * 0.62)) ** 2)
    a = np.clip((d - 0.58) / 0.55, 0, 1) ** 1.5 * 225
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    im.putalpha(Image.fromarray(a.astype(np.uint8)))
    return im

@lru_cache(maxsize=1)
def L_halftone():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    step = 16
    for yy in range(0, H, step):
        for xx in range(0, W, step):
            d.ellipse([xx - 1.6, yy - 1.6, xx + 1.6, yy + 1.6], fill=(255, 255, 255, 13))
    return im

@lru_cache(maxsize=8)
def grad(w, h, c0, c1, vertical=True):
    base = np.zeros((h, w, 4), np.uint8)
    for i in range(h if vertical else w):
        k = i / max(1, (h - 1) if vertical else (w - 1))
        c = [int(lerp(c0[j], c1[j], k)) for j in range(4)]
        if vertical: base[i, :, :] = c
        else: base[:, i, :] = c
    return Image.fromarray(base, "RGBA")

NOISE = []
def build_noise():
    rng = np.random.default_rng(7)
    for i in range(6):
        n = rng.normal(0, 10, (H // 2, W // 2)).astype(np.int16)
        img = Image.fromarray((128 + n).clip(0, 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)
        NOISE.append(img)

@lru_cache(maxsize=32)
def card(i):
    return Image.open(os.path.join(A, f"card_{i:02d}.png")).convert("RGBA")

@lru_cache(maxsize=64)
def card_full(i, z=1.0, cy=0.0):
    im = card(i); s = (W / im.width) * z
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    if im.height <= H:
        x = max(0, (im.width - W) // 2)
        return im.crop((x, 0, x + W, im.height))
    x = max(0, (im.width - W) // 2)
    y = int((im.height - H) * cy)
    return im.crop((x, y, x + W, y + H))

@lru_cache(maxsize=32)
def card_tall(i):
    """full card scaled to 1080 wide (3234 tall)"""
    im = card(i); s = W / im.width
    return im.resize((W, int(im.height * s)), Image.LANCZOS)

@lru_cache(maxsize=32)
def card_body(i):
    """art below the nameplate (nameplate ends ~0.215h)"""
    im = card(i)
    return im.crop((0, int(im.height * 0.222), im.width, im.height))

@lru_cache(maxsize=32)
def card_face(i):
    """9:16 face crop from the body"""
    im = card_body(i)
    hh = int(im.width / (W / H))
    return im.crop((0, 0, im.width, min(hh, im.height)))

@lru_cache(maxsize=8)
def city(z=1.0, cx=0.5, cy=0.5):
    im = Image.open(os.path.join(PROJ, "Assets/ManagedResources/Atlas/LoginPanelAtlas/cn2-x1_zhujiemian_beijing.png")).convert("RGBA")
    s = max(W / im.width, H / im.height) * z
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    x = int((im.width - W) * cx); y = int((im.height - H) * cy)
    return im.crop((x, y, x + W, y + H))

@lru_cache(maxsize=4)
def board_bg(z=1.0):
    im = Image.open(os.path.join(PROJ, "Assets/ManagedResources/Atlas/MapPanelAtlas/cn2-X1_shikongzhanchang_ditubeijing.png")).convert("RGBA")
    s = max(W / im.width, H / im.height) * z
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    x = int((im.width - W) / 2); y = int((im.height - H) / 2)
    return im.crop((x, y, x + W, y + H))

@lru_cache(maxsize=2)
def dice_icon():
    return Image.open(os.path.join(PROJ, "Assets/ManagedResources/Atlas/TrailMapAtlas/cn2-X1_icon_aoliaoerzhanyi_wupinshaizi.png")).convert("RGBA")

@lru_cache(maxsize=2)
def chest_icon():
    return Image.open(os.path.join(PROJ, "Assets/ManagedResources/Atlas/TrailMapAtlas/cn2-X1_icon_aoliaoerzhanyi_wupinbaoxiang1.png")).convert("RGBA")

@lru_cache(maxsize=2)
def hex_tile():
    im = Image.open(os.path.join(PROJ, "Assets/ManagedResources/Atlas/MapPanelAtlas/cn2-X1_shikongzhanchang_fangzhuan.png")).convert("RGBA")
    return im.crop((288, 20, 592, 202))

# ----------------------------------------------------------------- logo
@lru_cache(maxsize=1)
def logo():
    lw, lh = 940, 460
    im = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    t1 = txt("TIME-SPACE", F_DIN, 84, WHITE, tracking=20)
    t2 = txt("GIRL", F_BLACK, 258, WHITE, tracking=-6)
    sh = txt("GIRL", F_BLACK, 258, (0, 0, 0, 170), tracking=-6)
    im.alpha_composite(t1, (24, 10))
    im.alpha_composite(sh, (36, 112 + 16))
    im.alpha_composite(t2, (24, 112))
    d = ImageDraw.Draw(im)
    # red underline accent (below baseline)
    d.polygon([(24, 398), (826, 372), (826, 396), (24, 422)], fill=RED + (255,))
    d.rectangle([26, 436, 26 + 180, 442], fill=CYAN + (255,))
    return im

def bg_dark(red_glow=1.0, y=1500):
    im = Image.new("RGBA", (W, H), INK + (255,))
    if red_glow > 0:
        im.alpha_composite(radial((W, 1100), RED, 2.0, int(120 * red_glow)), (0, y - 550))
    return im

def top_bottom_shade(im, top=0.55, bottom=0.9, bottom_h=760):
    im.alpha_composite(grad(W, int(H * 0.34), (0, 0, 0, int(255 * top)), (0, 0, 0, 0)), (0, 0))
    im.alpha_composite(grad(W, bottom_h, (0, 0, 0, 0), (0, 0, 0, int(255 * bottom))), (0, H - bottom_h))
    return im

def shake(im, amp, t, seed=0):
    if amp <= 0: return im
    rnd = random.Random(int(t * 60) + seed)
    dx, dy = rnd.uniform(-amp, amp), rnd.uniform(-amp, amp)
    return im.transform(im.size, Image.AFFINE, (1, 0, -dx, 0, 1, -dy), resample=Image.BILINEAR)

def glitch(im, t, strength=1.0, seed=0):
    rnd = random.Random(int(t * 24) + seed)
    out = im.copy()
    for _ in range(int(7 * strength)):
        y = rnd.randrange(0, H - 40)
        hh = rnd.randrange(6, 60)
        dx = rnd.randrange(-70, 70)
        out.paste(im.crop((0, y, W, y + hh)), (dx, y))
    return out

def slash_layer(y0, y1, width=90, color=(255, 255, 255, 255), blur=2):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(-200, y0 - width), (W + 200, y1 - width // 3),
               (W + 200, y1 + width // 3), (-200, y0 + width)], fill=color)
    return im.filter(ImageFilter.GaussianBlur(blur))

def burst(cx, cy, n=14, r0=40, r1=520, color=(255, 255, 255, 255)):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rnd = random.Random(99)
    for i in range(n):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(r0, r1)
        w = rnd.uniform(2, 8)
        d.line([(cx + math.cos(a) * r0, cy + math.sin(a) * r0),
                (cx + math.cos(a) * rr, cy + math.sin(a) * rr)], fill=color, width=int(w))
    return im.filter(ImageFilter.GaussianBlur(1.6))

def speed_lines(t, n=16, alpha=60, color=WHITE):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rnd = random.Random(5)
    for i in range(n):
        x = rnd.randrange(-200, W); y = rnd.randrange(0, H)
        ln = rnd.randrange(200, 700)
        d.line([(x, y), (x + ln, y - ln * 0.35)], fill=color + (alpha,), width=rnd.randrange(1, 3))
    return im

def city_grade(im, warm=1.0):
    im = ImageEnhance.Color(im).enhance(1.22)
    im = ImageEnhance.Contrast(im).enhance(1.1)
    im.alpha_composite(Image.new("RGBA", (W, H), (18, 6, 40, 40)))
    if warm:
        im.alpha_composite(radial((W, 900), (255, 120, 90), 1.5, int(70 * warm)), (0, 780))
    return im

# ----------------------------------------------------------------- scenes
def s1_hook(t):
    z = lerp(1.24, 1.04, eo(seg(t, 0, 3.4)))
    im = card_full(1, z=z, cy=lerp(0.0, 0.05, eo(seg(t, 0, 3.4)))).copy()
    im.alpha_composite(speed_lines(t, 14, 30), (0, 0))
    top_bottom_shade(im, 0.5, 0.96, 940)
    im.alpha_composite(radial((W, 900), RED, 1.6, 95), (0, 1010))

    p = seg(t, 1.5, 2.3)
    if p > 0:
        line = "> 108 LEGENDS LOCATED // COMMANDER VERIFIED"
        s = line[: int(len(line) * p)]
        blit(im, txt(s, F_MONO, 32, CYAN, tracking=1), (78, 1565), alpha=0.95)
        if p >= 1 and int(t * 3) % 2 == 0:
            blit(im, txt("_", F_MONO, 32, CYAN), (80 + txt(line, F_MONO, 32, CYAN, tracking=1).width, 1565))

    p = seg(t, 0.4, 0.9)
    if p > 0:
        k = over(p)
        blit(im, txt("SUMMON", F_BLACK, 166, WHITE, tracking=-4), (76, 1055), "lt",
             alpha=min(1, p * 1.7), scale=lerp(1.3, 1.0, k))
        blit(im, txt("THEM.", F_BLACK, 166, RED, tracking=-4), (76, 1205), "lt",
             alpha=min(1, max(0, p - 0.22) * 1.7), scale=lerp(1.3, 1.0, k))
    if t > 0.85:
        a = seg(t, 0.85, 1.0)
        im.alpha_composite(Image.new("RGBA", (int(300 * a), 9), RED + (255,)), (78, 1018))
    if t < 0.12:
        im.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, int(210 * (1 - t / 0.12)))))
    return im

def s2_world(t):
    z = lerp(1.2, 1.02, eio(seg(t, 0, 2.8)))
    im = city_grade(city(z=z, cx=0.5, cy=0.6).copy())
    top_bottom_shade(im, 0.6, 0.97, 900)

    p1 = seg(t, 0.12, 0.5)
    if p1 > 0:
        blit(im, txt("THE CITY FELL.", F_DIN, 112, WHITE, tracking=6), (78, 560), "lt",
             alpha=p1, scale=lerp(1.05, 1.0, eo(p1)))
    p2 = seg(t, 0.62, 1.0)
    if p2 > 0:
        blit(im, txt("THE LEGENDS WOKE.", F_DIN, 112, RED, tracking=6), (78, 700), "lt",
             alpha=p2, scale=lerp(1.05, 1.0, eo(p2)))

    p3 = seg(t, 1.35, 1.9)
    if p3 > 0:
        lg = glitch(logo(), t, 1.8, 3) if p3 < 0.45 else logo()
        blit(im, lg, (74, 1010), "lt", alpha=min(1, p3 * 1.4), scale=lerp(1.16, 1.0, over(p3)))
        if p3 > 0.55:
            blit(im, txt("CYBER  ·  LEGENDS  ·  WAR", F_DIN, 44, (235, 235, 245, 255), tracking=10),
                 (80, 1490), "lt", alpha=seg(t, 1.85, 2.15))
    if t < 0.1:
        im.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, int(220 * (1 - t / 0.1)))))
    return im

def s3_rollcall(t):
    seq = [(9, CYAN), (2, RED), (3, MAGENTA), (7, CYAN), (4, MAGENTA), (8, CYAN)]
    step = 2.4 / len(seq)
    i = min(len(seq) - 1, int(t / step))
    lt = t - i * step
    idx, col = seq[i]
    z = lerp(1.18, 1.06, seg(lt, 0, step))
    im = card_face(idx).copy()
    s = (W / im.width) * z
    im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    x = max(0, (im.width - W) // 2); y = max(0, (im.height - H) // 2)
    im = im.crop((x, y, x + W, y + H))
    im.alpha_composite(Image.new("RGBA", (W, H), col + (40,)))
    top_bottom_shade(im, 0.45, 0.9, 700)
    d = ImageDraw.Draw(im)
    for k in range(5):
        d.rectangle([70, 1560 + k * 9, 70 + (36 + k * 22), 1560 + k * 9 + 4], fill=col + (210,))
    blit(im, txt(f"LEGEND {i+1:02d}", F_DIN, 38, col, tracking=8), (76, 1500))
    if lt < 0.08:
        im.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, int(150 * (1 - lt / 0.08)))))
    return im

def s4_cards(t):
    seq = [1, 9, 5]
    step = 4.8 / 3
    i = min(2, int(t / step))
    lt = t - i * step
    idx = seq[i]
    z = lerp(1.0, 1.07, eio(seg(lt, 0, step)))
    im = card_full(idx, z=z, cy=lerp(0.0, 0.03, seg(lt, 0, step))).copy()
    col = {1: RED, 9: CYAN, 5: MAGENTA}[idx]
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    off = lerp(320, 0, eo(seg(lt, 0, 0.45)))
    d.polygon([(0, 0), (off, 0), (off - 250, H), (0, H)], fill=col + (64,))
    im.alpha_composite(lay)
    top_bottom_shade(im, 0.5, 0.88, 640)
    if lt < 0.32:
        dx = int(lerp(280, 0, eo(seg(lt, 0, 0.32))))
        im = im.transform(im.size, Image.AFFINE, (1, 0, -dx, 0, 1, 0), resample=Image.BILINEAR)
    blit(im, txt(f"0{i+1}", F_BLACK, 200, (255, 255, 255, 34), tracking=-6), (W - 54, H - 400), "rb")
    if lt < 0.07:
        im.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, int(150 * (1 - lt / 0.07)))))
    return im

def s5_combat(t):
    im = bg_dark(1.0, 1500)
    im.alpha_composite(city(z=1.2, cx=0.5, cy=0.5).copy().filter(ImageFilter.GaussianBlur(6)))
    im.alpha_composite(Image.new("RGBA", (W, H), (10, 0, 18, 205)))
    im.alpha_composite(radial((W, 1200), RED, 1.5, 120), (0, 800))
    im.alpha_composite(speed_lines(t * 1.6, 10, 20), (0, 0))

    def portrait(idx, x, tint, dark, flip=False):
        c = card_tall(idx).crop((190, 600, 890, 600 + 1340))
        c = c.resize((470, 1340), Image.LANCZOS)
        if flip:
            c = c.transpose(Image.FLIP_LEFT_RIGHT)
        lay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        lay.alpha_composite(c, (x, 280))
        lay.alpha_composite(Image.new("RGBA", (W, H), tint + (dark,)))
        lay.alpha_composite(grad(470, 150, (0, 0, 0, 245), (0, 0, 0, 0)), (x, 280))
        return lay

    im.alpha_composite(portrait(1, -40, (0, 0, 0), 60))
    im.alpha_composite(portrait(2, W - 430, (90, 0, 14), 130, flip=True))
    # frame edges
    d = ImageDraw.Draw(im)
    d.rectangle([-40, 280, 430, 1620], outline=(255, 255, 255, 40), width=2)
    d.rectangle([W - 430, 280, W + 40, 1620], outline=(255, 255, 255, 30), width=2)
    im.alpha_composite(grad(320, H, (0, 0, 0, 175), (0, 0, 0, 175), False), (W // 2 - 160, 0))
    top_bottom_shade(im, 0.8, 0.96, 820)

    d = ImageDraw.Draw(im)
    hits = [0.62, 1.62, 2.62]
    dmg = sum(1 for ht in hits if t > ht)
    hp = 1 - dmg * 0.27
    d.rectangle([70, 214, 70 + 400, 214 + 20], fill=(0, 0, 0, 190))
    d.rectangle([70, 214, 70 + int(400 * hp), 214 + 20], fill=RED + (255,))
    d.rectangle([W - 470, 214, W - 70, 214 + 20], fill=(0, 0, 0, 190))
    d.rectangle([W - 470, 214, W - 470 + 400, 214 + 20], fill=CYAN + (255,))
    blit(im, txt("NIGHTMARE // BOSS", F_DIN, 30, (255, 255, 255, 225), tracking=4), (70, 174))
    blit(im, txt("YOUR SQUAD", F_DIN, 30, (255, 255, 255, 225), tracking=4), (W - 470, 174))

    pvs = seg(t, 0.05, 0.35)
    if pvs > 0:
        blit(im, txt("VS", F_BLACK, 158, (255, 255, 255, 240), tracking=-4, stroke=11, stroke_fill=(20, 0, 4, 255)),
             (W // 2, 880), "cc", alpha=pvs, scale=lerp(1.5, 1.0, over(pvs)))

    amp = 0
    for i, ht in enumerate(hits):
        if t >= ht:
            k = t - ht
            amp = max(amp, max(0, 22 * (1 - k / 0.26)))
            a = max(0, 1 - k / 0.55)
            if a > 0:
                im.alpha_composite(slash_layer(880 - 180, 880 + 180, 125, (255, 255, 255, int(235 * min(1, a * 2.2))), 2))
                im.alpha_composite(burst(540, 900, 20, 30, 540, (255, 245, 220, int(210 * a))))
                val = ["-8,420", "-12,960", "-21,377"][i]
                sc = 1 + 0.9 * max(0, 0.16 - k) / 0.16
                blit(im, txt(val, F_BLACK, 128, GOLD, tracking=-2, stroke=10, stroke_fill=(110, 0, 8, 255)),
                     (540, 700 - k * 30), "cc", alpha=min(1, a * 1.8), scale=sc)
                if i == 2:
                    blit(im, txt("CRITICAL", F_BLACK, 50, WHITE, tracking=8, stroke=7, stroke_fill=RED + (255,)),
                         (540, 812), "cc", alpha=min(1, a * 1.6))
    if t > 1.95:
        blit(im, txt("SILENCE", F_DIN, 30, CYAN, tracking=6), (76, 1290), alpha=seg(t, 1.95, 2.2))
    if t > 2.25:
        blit(im, txt("BURN", F_DIN, 30, GOLD, tracking=6), (76, 1336), alpha=seg(t, 2.25, 2.5))
    if t > 2.95:
        blit(im, txt("CHAIN x3", F_BLACK, 40, MAGENTA, tracking=4), (76, 1388), alpha=seg(t, 2.95, 3.15))

    blit(im, txt("5 v 5  TURN-BASED", F_DIN, 58, WHITE, tracking=12), (W // 2, 1712), "cc",
         alpha=seg(t, 0.0, 0.3))
    p2 = seg(t, 3.4, 3.95)
    if p2 > 0:
        blit(im, txt("BUILD. BREAK. WIN.", F_BLACK, 78, WHITE, tracking=-2), (W // 2, 1712), "cc",
             alpha=p2, scale=lerp(1.1, 1.0, eo(p2)))
    return shake(im, amp, t, 11)

def s6_explore(t):
    im = board_bg(z=1.08).copy()
    im.alpha_composite(Image.new("RGBA", (W, H), (6, 0, 20, 110)))
    tw, th = 200, 120
    tile = hex_tile().resize((tw, th), Image.LANCZOS)
    cols, rows = 4, 6
    gx = (W - (cols * (tw - 8) + 8)) // 2
    oy = 340
    cells = []
    for r in range(rows):
        for c in range(cols):
            x = gx + c * (tw - 8) + (0 if r % 2 == 0 else (tw - 8) // 2)
            y = oy + r * int(th * 0.78)
            cells.append((x, y))
    path = [20, 21, 17, 13, 9, 5]
    for i, (x, y) in enumerate(cells):
        tt = tile.copy()
        a = 92
        lit = i in path
        if lit:
            k = seg(t, 0.15 + path.index(i) * 0.13, 0.35 + path.index(i) * 0.13)
            if k > 0:
                a = 118 + int(130 * k)
                tt.alpha_composite(Image.new("RGBA", tt.size, (34, 224, 255, int(58 * k))))
                tt.alpha_composite(Image.new("RGBA", tt.size, (255, 255, 255, int(14 * k))))
        tt.putalpha(tt.getchannel("A").point(lambda v: int(v * a / 255)))
        im.alpha_composite(tt, (int(x), int(y)))
        if lit and t > 0.15 + path.index(i) * 0.13 + 0.1:
            cx, cy = x + tw // 2, y + th // 2
            im.alpha_composite(radial((150, 110), CYAN, 1.2, 90), (cx - 75, cy - 55))

    # reward on the last tile
    lx, ly = cells[path[-1]]
    if t > 1.55:
        k = seg(t, 1.55, 2.0)
        blit(im, chest_icon().resize((150, 138), Image.LANCZOS), (lx + tw // 2, ly - 30), "cc",
             alpha=k, scale=lerp(0.5, 1.0, over(k)))
        blit(im, txt("+1 SSR SHARD", F_BLACK, 44, GOLD, stroke=6, stroke_fill=(90, 0, 10, 255)),
             (lx + tw // 2, ly - 150), "cc", alpha=seg(t, 1.85, 2.1),
             scale=lerp(0.85, 1.0, eo(seg(t, 1.85, 2.1))))

    # dice
    p = seg(t, 0.2, 1.15)
    if p > 0:
        dd = dice_icon().resize((230, 210), Image.LANCZOS)
        yy = lerp(1330, 1180, eo(p))
        bob = math.sin(t * 15) * (18 if p < 1 else 0)
        im.alpha_composite(radial((420, 280), CYAN, 1.3, 75), (W // 2 - 90, int(yy) - 60))
        blit(im, dd, (W // 2 + 130, yy + bob), "cc")

    p = seg(t, 0.1, 0.45)
    if p > 0:
        blit(im, txt("ROLL.", F_BLACK, 128, WHITE, tracking=-2), (76, 1450), "lt", alpha=p, scale=lerp(1.2, 1, over(p)))
        blit(im, txt("RAID.", F_BLACK, 128, RED, tracking=-2), (76, 1566), "lt", alpha=p, scale=lerp(1.2, 1, over(p)))
        blit(im, txt("REPEAT.", F_BLACK, 128, WHITE, tracking=-2), (76, 1682), "lt", alpha=p, scale=lerp(1.2, 1, over(p)))
    blit(im, txt("DICE-DRIVEN RUIN RUNS", F_DIN, 30, (215, 215, 235, 255), tracking=8),
         (78, 1838), alpha=seg(t, 0.6, 0.9))
    return im

def s7_idle(t):
    if t < 1.6:
        im = bg_dark(1.2, 1700)
        im.alpha_composite(speed_lines(t * 0.4, 8, 12), (0, 0))
        # big ghost 24/7
        blit(im, txt("24/7", F_BLACK, 260, (255, 255, 255, 9), tracking=-8), (W - 40, 180), "rt")
        # rewards feed on the right
        feed = [("+12,480", "GOLD", GOLD), ("+36", "EXP", CYAN), ("+1", "SSR SHARD", GOLD),
                ("+900", "GEMS", CYAN), ("+5,200", "GOLD", GOLD)]
        for i, (v, lb, col) in enumerate(feed):
            k = t - i * 0.11
            if k < 0: continue
            y = 1560 - k * 330 + i * 90
            if y < 560: continue
            a = clamp(1.35 - k * 0.6)
            box = Image.new("RGBA", (400, 96), (10, 10, 16, int(190 * a)))
            dd = ImageDraw.Draw(box)
            dd.rectangle([0, 0, 6, 96], fill=col + (int(255 * a),))
            im.alpha_composite(box, (600, int(y)))
            blit(im, txt(v, F_BLACK, 46, col, tracking=0), (622, int(y) + 22), alpha=a)
            blit(im, txt(lb, F_DIN, 30, (230, 230, 240, 255), tracking=6), (622 + txt(v, F_BLACK, 46, col).width + 14, int(y) + 34), alpha=a)
        im.alpha_composite(grad(W, 620, (0, 0, 0, 0), (0, 0, 0, 225)), (0, 1300))
        p = seg(t, 0.05, 0.45)
        blit(im, txt("IDLE", F_BLACK, 150, WHITE, tracking=-3), (72, 700), "lt", alpha=p,
             scale=lerp(1.14, 1, over(p)))
        blit(im, txt("24/7", F_BLACK, 150, RED, tracking=-3), (72, 850), "lt", alpha=p,
             scale=lerp(1.14, 1, over(p)))
        blit(im, txt("LOG OFF. KEEP WINNING.", F_DIN, 46, CYAN, tracking=6), (76, 1040),
             alpha=seg(t, 0.35, 0.65))
        im.alpha_composite(Image.new("RGBA", (140, 8), RED + (255,)), (74, 672))
    else:
        lt = t - 1.6
        im = bg_dark(0.7, 1500)
        im.alpha_composite(radial((W, 1000), (90, 30, 160), 1.6, 110), (0, 600))
        ids = [1, 9, 5, 2, 3, 8, 4, 6, 7, 1]
        cw, ch = 176, 262
        gx, gy = 70, 900
        for i, idx in enumerate(ids):
            k = seg(lt, i * 0.06, i * 0.06 + 0.26)
            if k <= 0: continue
            col = i // 5; row = i % 5
            x = gx + row * (cw + 12); y = gy + col * (ch + 16)
            im.alpha_composite(Image.new("RGBA", (cw, ch), (12, 12, 18, 245)), (x, y))
            full = card_tall(idx)
            src = full.crop((0, 600, W, 600 + int(W * ch / cw)))
            src = src.resize((cw - 6, ch - 6), Image.BILINEAR)
            src.putalpha(Image.fromarray(np.full((ch - 6, cw - 6), 245, np.uint8)))
            im.alpha_composite(src, (x + 3, y + 3))
            if i == 9 and lt > 0.78:
                a = seg(lt, 0.78, 1.0)
                im.alpha_composite(Image.new("RGBA", (cw, ch), GOLD + (int(130 * a),)), (x, y))
        if lt > 0.72:
            a = seg(lt, 0.72, 0.95)
            im.alpha_composite(radial((560, 560), (255, 220, 140), 1.4, int(160 * a)), (260, 780))
        p = seg(lt, 0.12, 0.45)
        blit(im, txt("SUMMON LEGENDS", F_BLACK, 92, WHITE, tracking=-2), (72, 700), "lt", alpha=p,
             scale=lerp(1.08, 1.0, eo(p)))
        blit(im, txt("ZERO PAYWALLS  ·  FULL STORY  ·  PVP", F_DIN, 36, GOLD, tracking=5),
             (76, 820), alpha=seg(lt, 0.4, 0.7))
    top_bottom_shade(im, 0.3, 0.9, 560)
    return im

def s8_cta(t):
    im = bg_dark(1.0, 1250)
    for i, (idx, x, y, z, a) in enumerate([(1, -160, 180, 1.05, 44), (5, 700, 260, 1.0, 36), (9, 240, 20, 1.12, 28)]):
        c = card_full(idx, z=z, cy=0.04).copy().filter(ImageFilter.GaussianBlur(4))
        c.putalpha(c.getchannel("A").point(lambda v: int(v * a / 255)))
        im.alpha_composite(c, (x, y))
    im.alpha_composite(Image.new("RGBA", (W, H), (6, 4, 10, 170)))
    im.alpha_composite(radial((W, 1100), RED, 1.8, 90), (0, 900))
    top_bottom_shade(im, 0.5, 0.95, 780)
    d = ImageDraw.Draw(im)
    m, ln = 54, 90
    for (cx, cy, sx, sy) in [(m, m, 1, 1), (W - m, m, -1, 1), (m, H - m, 1, -1), (W - m, H - m, -1, -1)]:
        d.line([(cx, cy), (cx + ln * sx, cy)], fill=(255, 255, 255, 80), width=2)
        d.line([(cx, cy), (cx, cy + ln * sy)], fill=(255, 255, 255, 80), width=2)

    p = seg(t, 0.0, 0.4)
    blit(im, logo(), (W // 2, 600), "ct", alpha=p, scale=lerp(0.94, 1.0, eo(p)))

    p = seg(t, 0.45, 0.75)
    if p > 0:
        bw, bh = 700, 136
        bx, by = W // 2 - bw // 2, 1190
        pulse = 1 + 0.018 * math.sin(t * 7)
        btn = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
        dd = ImageDraw.Draw(btn)
        dd.rounded_rectangle([0, 0, bw - 1, bh - 1], 22, fill=WHITE + (255,))
        btn2 = btn.resize((int(bw * pulse), int(bh * pulse)), Image.LANCZOS)
        im.alpha_composite(btn2, (bx - (btn2.width - bw) // 2, by - (btn2.height - bh) // 2))
        blit(im, txt("DOWNLOAD FREE", F_BLACK, 62, INK + (255,), tracking=1), (W // 2, by + bh // 2), "cc", alpha=p)
    p = seg(t, 0.85, 1.1)
    blit(im, txt("GUARANTEED SSR ON DAY 8", F_DIN, 36, (240, 240, 250, 255), tracking=6),
         (W // 2, 1392), "cc", alpha=p)
    p = seg(t, 1.05, 1.3)
    if p > 0:
        # play triangle
        tri = Image.new("RGBA", (46, 46), (0, 0, 0, 0))
        ImageDraw.Draw(tri).polygon([(6, 6), (6, 40), (40, 23)], fill=(255, 255, 255, int(255 * p)))
        blit(im, tri, (W // 2 - 190, 1462))
        blit(im, txt("GET IT ON GOOGLE PLAY", F_DIN, 32, (215, 215, 230, 255), tracking=5),
             (W // 2 - 130, 1470), alpha=p)
    if t > 3.3:
        im.alpha_composite(Image.new("RGBA", (W, H), (0, 0, 0, int(255 * seg(t, 3.3, 4.2)))))
    return im

def frame(t):
    if t < 3.4:    im = s1_hook(t)
    elif t < 6.2:  im = s2_world(t - 3.4)
    elif t < 8.6:  im = s3_rollcall(t - 6.2)
    elif t < 13.4: im = s4_cards(t - 8.6)
    elif t < 18.0: im = s5_combat(t - 13.4)
    elif t < 22.2: im = s6_explore(t - 18.0)
    elif t < 25.8: im = s7_idle(t - 22.2)
    else:          im = s8_cta(t - 25.8)

    im.alpha_composite(L_halftone(), (0, 0))
    im.alpha_composite(L_vig(), (0, 0))
    im.alpha_composite(L_scan(), (0, 0))
    n = NOISE[int(t * FPS) % len(NOISE)]
    im.alpha_composite(Image.merge("RGBA", (n, n, n, Image.new("L", (W, H), 12))), (0, 0))
    return im.convert("RGB")

def main():
    build_noise()
    if len(sys.argv) > 1 and sys.argv[1] == "--test":
        ts = [float(x) for x in sys.argv[2:]] or [0.6, 1.9, 4.6, 6.9, 9.5, 14.2, 19.4, 23.6, 27.2]
        for t in ts:
            frame(t).save(os.path.join(ROOT, "frames", f"test_{t:05.2f}.png"))
        print("ok")
        return
    import subprocess
    out = os.path.join(ROOT, "video_noaudio.mp4")
    p = subprocess.Popen([
        "ffmpeg", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}",
        "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-preset", "medium", "-crf", "17",
        "-pix_fmt", "yuv420p", "-movflags", "+faststart", out],
        stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    n = int(DUR * FPS)
    for i in range(n):
        p.stdin.write(frame(i / FPS).tobytes())
        if i % 90 == 0: print(f"{i}/{n}", flush=True)
    p.stdin.close(); p.wait()
    print("done", out)

if __name__ == "__main__":
    main()
