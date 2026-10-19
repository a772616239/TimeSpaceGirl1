# -*- coding: utf-8 -*-
"""宝箱「被战利品线撞到」弹性回弹的 1:1 预览。

缩放曲线取自引擎里 DOTween 的 EaseManager.Evaluate(OutElastic, amp=1.8, period=auto)，
把真实贴图（战力品标题 + 钻石）按曲线逐帧合成，用来验收「压扁 -> 弹回 -> 抖两下」的手感。
"""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TITLE = os.path.join(ROOT, "Assets/ManagedResources/ArtFont_zh/FightPointPassMainPanelAtlas/cn2-X1_zhandou_zhanlipin_biaoti_zh.png")
DIAMOND = os.path.join(ROOT, "Assets/ManagedResources/Atlas/FightPointPassMainPanelAtlas/cn2-X1_zhandou_zhanlipin.png")
OUT = os.path.join(ROOT, "_output/box_hit")
S = 2  # 2x 像素密度，便于肉眼看边缘

# t=0..0.5s 共 61 点，引擎实测（0.74 压扁 -> OutElastic amp=1.8 回弹）
CURVE = [float(x) for x in (
    "0.7400,0.9009,1.0404,1.1464,1.2130,1.2404,1.2335,1.2001,1.1498,1.0919,1.0350,0.9857,0.9483,0.9247,"
    "0.9150,0.9174,0.9292,0.9470,0.9675,0.9876,1.0051,1.0183,1.0266,1.0301,1.0292,1.0250,1.0187,1.0115,"
    "1.0044,0.9982,0.9935,0.9906,0.9894,0.9897,0.9912,0.9934,0.9959,0.9985,1.0006,1.0023,1.0033,1.0038,"
    "1.0036,1.0031,1.0023,1.0014,1.0005,0.9998,0.9992,0.9988,0.9987,0.9987,0.9989,0.9992,0.9995,0.9998,"
    "1.0001,1.0003,1.0004,1.0005,1.0000"
).split(",")]

DURATION = 0.5

# 预制体实测几何（局部坐标，以「标题+钻石」组合中心为原点）
TITLE_W, TITLE_H = 178.0, 40.0
DIAMOND_W, DIAMOND_H = 96.0, 106.0
TITLE_OFF_Y = 49.6    # 标题中心相对组合中心
DIAMOND_OFF_Y = -16.6 # 钻石中心相对组合中心

BG = (27, 24, 48, 255)


def frame(scale):
    """按缩放系数合成一帧（组合整体绕中心缩放）。"""
    cw, ch = 300, 240
    canvas = Image.new("RGBA", (cw * S, ch * S), BG)
    title = Image.open(TITLE).convert("RGBA")
    diamond = Image.open(DIAMOND).convert("RGBA")

    def paste(img, w, h, cx, cy):
        tw, th = max(1, int(round(w * scale * S))), max(1, int(round(h * scale * S)))
        im = img.resize((tw, th), Image.LANCZOS)
        canvas.alpha_composite(im, (int(round(cw * S / 2 + cx * scale * S - tw / 2)),
                                    int(round(ch * S / 2 - cy * scale * S - th / 2))))

    paste(title, TITLE_W, TITLE_H, 0.0, TITLE_OFF_Y)
    paste(diamond, DIAMOND_W, DIAMOND_H, 0.0, DIAMOND_OFF_Y)
    return canvas


def main():
    os.makedirs(OUT, exist_ok=True)
    fps = 30
    total = int(DURATION * fps) + 1
    frames = []
    for i in range(total):
        idx = int(round(i / (total - 1) * (len(CURVE) - 1)))
        frames.append(frame(CURVE[idx]))
    # 回弹结束停 0.35s，方便看「弹定」后的静止状态
    frames += [frame(1.0)] * 10
    frames[0].save(os.path.join(OUT, "bounce.gif"), save_all=True, append_images=frames[1:],
                   duration=int(1000 / fps), loop=0, disposal=2)

    # 关键帧胶片条
    picks = [0, 1, 2, 5, 9, 14, 23, 45]
    labels = []
    for p in picks:
        t = p / (len(CURVE) - 1) * DURATION
        labels.append((t, CURVE[p]))
    tiles = [frame(s) for _, s in labels]
    tw, th = tiles[0].size
    sheet = Image.new("RGBA", (tw // 2 * len(tiles) + 6 * (len(tiles) + 1), th // 2 + 30), BG)
    d = ImageDraw.Draw(sheet)
    for i, (im, (t, s)) in enumerate(zip(tiles, labels)):
        x = 6 + i * (tw // 2 + 6)
        sheet.alpha_composite(im.resize((tw // 2, th // 2), Image.LANCZOS), (x, 24))
        d.text((x + 4, 6), "%.2fs  x%.2f" % (t, s), fill=(210, 214, 230, 255))
    sheet.convert("RGB").save(os.path.join(OUT, "filmstrip.png"))
    print("ok", sheet.size)


if __name__ == "__main__":
    main()
