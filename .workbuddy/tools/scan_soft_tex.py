# -*- coding: utf-8 -*-
"""只按 alpha 的径向衰减曲线给柔边候选打分。

shader 里 RGB 恒为黑（_Color 是纯黑），真正决定形状的只有 _MainTex 的 alpha，
所以这里只看 alpha 从中心到边缘是否平滑衰减。
"""
import math
import os

from PIL import Image

ROOT = "/Users/wangxufeng/Documents/TimeSpaceGirl1/Assets/Art"
DIRS = ["effectTexture", "EffectsOld/Textures"]
N = 48
RINGS = [0.0, 0.2, 0.4, 0.6, 0.8, 0.98]
# 理想的「压暗」形状：中间实、边缘化开
IDEAL = [0.95, 0.90, 0.65, 0.30, 0.06, 0.0]


def ring_profile(im):
    px = im.load()
    buckets = [[] for _ in RINGS]
    cx = cy = (N - 1) / 2.0
    maxr = N / 2.0
    for y in range(N):
        for x in range(N):
            r = math.hypot(x - cx, y - cy) / maxr
            a = px[x, y][3] / 255.0
            # 落到最近的环
            idx = min(range(len(RINGS)), key=lambda i: abs(RINGS[i] - r))
            buckets[idx].append(a)
    return [sum(b) / len(b) if b else 0.0 for b in buckets]


rows = []
for d in DIRS:
    base = os.path.join(ROOT, d)
    if not os.path.isdir(base):
        continue
    for fn in sorted(os.listdir(base)):
        if not fn.lower().endswith(".png"):
            continue
        p = os.path.join(base, fn)
        try:
            im = Image.open(p)
            w, h = im.size
            if w < 64 or h < 64 or w > 2048 or h > 2048:
                continue
            if abs(w / float(h) - 1.0) > 0.3:
                continue
            im = im.convert("RGBA").resize((N, N), Image.BILINEAR)
        except Exception:
            continue
        prof = ring_profile(im)
        if prof[0] < 0.5 or prof[-1] > 0.12:
            continue
        # 单调性：从中心到边缘不应反弹太多
        drops = [prof[i] - prof[i + 1] for i in range(len(prof) - 1)]
        if min(drops) < -0.06:
            continue
        err = sum(abs(prof[i] - IDEAL[i]) for i in range(len(prof))) / len(prof)
        rows.append((err, prof, w, h, d + "/" + fn))

rows.sort(key=lambda r: r[0])
print("candidates=%d" % len(rows))
for err, prof, w, h, path in rows[:36]:
    print("err=%.3f  %dx%d  %s\n        alpha r: %s" % (
        err, w, h, path, " ".join("%.2f" % v for v in prof)))
