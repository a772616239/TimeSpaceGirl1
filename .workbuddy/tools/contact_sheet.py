# -*- coding: utf-8 -*-
"""把柔边候选的 alpha 通道排成一张对比图（棋盘底，便于看边缘是否化开）。"""
import os

from PIL import Image, ImageDraw

ROOT = "/Users/wangxufeng/Documents/TimeSpaceGirl1/Assets/Art"
CANDIDATES = [
    "EffectsOld/Textures/cn2-tex_lizi_002.png",
    "effectTexture/cn2-x1_normal_py_a00192.png",
    "effectTexture/cn2-D_lm_tex_275.png",
    "effectTexture/cn2-normal069.png",
    "EffectsOld/Textures/cn2-tex_Aglow_z_01.png",
    "effectTexture/cn2-x1_fx_tex_0031.png",
    "effectTexture/cn2-T_ZJ_003.png",
    "EffectsOld/Textures/cn2-tex_UI_effect_jiefeng_jieyin.png",
    "effectTexture/cn2-D_lm_tex_206.png",
    "effectTexture/cn2-D_lm_tex_312.png",
]
CELL = 220
COLS = 5
ROWS = (len(CANDIDATES) + COLS - 1) // COLS
W, H = CELL * COLS, CELL * ROWS + 34 * ROWS
sheet = Image.new("RGB", (W, H), (24, 24, 28))
draw = ImageDraw.Draw(sheet)

# 棋盘底
def checker(size, step=20):
    im = Image.new("RGB", (size, size), (58, 58, 64))
    d = ImageDraw.Draw(im)
    for y in range(0, size, step):
        for x in range(0, size, step):
            if (x // step + y // step) % 2:
                d.rectangle([x, y, x + step - 1, y + step - 1], fill=(84, 84, 92))
    return im

for i, rel in enumerate(CANDIDATES):
    p = os.path.join(ROOT, rel)
    c = i % COLS
    r = i // COLS
    x0, y0 = c * CELL, r * (CELL + 34)
    if not os.path.exists(p):
        draw.text((x0 + 8, y0 + 8), "MISSING " + rel, fill=(255, 80, 80))
        continue
    im = Image.open(p).convert("RGBA").resize((CELL, CELL), Image.LANCZOS)
    bg = checker(CELL)
    # 用黑色填充 alpha，模拟「黑块」的真实观感
    black = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 255))
    black.putalpha(im.getchannel("A"))
    bg.paste(black, (0, 0), black)
    sheet.paste(bg, (x0, y0))
    draw.rectangle([x0, y0, x0 + CELL - 1, y0 + CELL - 1], outline=(120, 120, 130))
    draw.text((x0 + 6, y0 + CELL + 8), "%d. %s" % (i + 1, os.path.basename(rel)[:30]), fill=(225, 225, 235))

out = "/Users/wangxufeng/Documents/TimeSpaceGirl1/_output/soft_tex_candidates.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
sheet.save(out)
print(out, sheet.size)
