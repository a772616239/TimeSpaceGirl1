#!/usr/bin/env python
"""把「压在网点晕圈上的英文美术字」补成真正不透明（改 alpha，不只是 RGB）。

为什么要这一步：texie 这族底板是「笔刷 + 网点晕散」的异形轮廓，网点本身带
alpha≈102。模型把英文画进这块晕圈时，文字像素会继承底板的 alpha ⇒ 交付图里
字看着发灰、网点透过来（RGB 明明是 (252,100,107) 的亮红，合成到深底上却成暗红）。
RGB 怎么调都没用，必须把「字所在像素」的 alpha 抬到 255。

做法：字 = 红色墨迹（含暗红描边）膨胀 2px；这块 alpha 置 255；其余原样保留源图
alpha（带外逐像素锁死）。字母内部的中空（O/Q 的counter）保持底板 alpha，仍读作洞。
顺带清掉字带外那些 <150px 的红色碎笔画。

产出一张 RGBA PNG + `<stem>.band.json` 边车（`{"alpha_band":[x0,y0,x1,y1]}`），
这样管线会按「本地确定性合成」验收：带外 alpha 逐像素锁死、带内允许重建。

用法：
  python scripts/image/letter_alpha_fix.py \
      --asset Assets/ManagedResources/ArtFont_zh/font/xxx_zh.png \
      --out /tmp/composed/xxx.png
（读取该资产在 _output/art_translate/<名>/out.png 的当前成果）
"""
from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "_output" / "art_translate"


def _dilate(mask: np.ndarray, r: int) -> np.ndarray:
    im = Image.fromarray((mask * 255).astype(np.uint8))
    return np.asarray(im.filter(ImageFilter.MaxFilter(2 * r + 1))) > 128


def _reachable(mask: np.ndarray) -> np.ndarray:
    """mask 中与画布边界 4 连通可达的像素"""
    h, w = mask.shape
    seen = np.zeros_like(mask, bool)
    dq: deque[tuple[int, int]] = deque()
    for y in range(h):
        for x in (0, w - 1):
            if mask[y, x] and not seen[y, x]:
                seen[y, x] = True
                dq.append((y, x))
    for x in range(w):
        for y in (0, h - 1):
            if mask[y, x] and not seen[y, x]:
                seen[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                dq.append((ny, nx))
    return seen


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", required=True, help="源图（ArtFont_zh/...）相对仓库根路径")
    ap.add_argument("--out", required=True, help="输出 RGBA PNG（会同时写 .band.json）")
    ap.add_argument("--work-dir", default="", help="默认 _output/art_translate/<资产名>")
    args = ap.parse_args()

    src_path = ROOT / args.asset
    if args.work_dir:
        work = Path(args.work_dir)
    else:
        # 工作目录名是「去掉末尾 _zh 后缀」的那个（注意 "_zh" 也出现在 zhitianxinzhang 里，
        # 只能用 removesuffix，不能 replace）
        base = src_path.stem[:-3] if src_path.stem.endswith("_zh") else src_path.stem
        canda = [WORK / src_path.stem, WORK / base]
        work = next((c for c in canda if (c / "out.png").is_file()), canda[0])
    out_path = Path(args.out)

    src = Image.open(src_path).convert("RGBA")
    cur = Image.open(work / "out.png").convert("RGBA")
    if cur.size != src.size:
        raise SystemExit(f"尺寸不一致：{cur.size} vs {src.size}")
    sa = np.asarray(src.getchannel("A")).astype(int)
    oa = np.asarray(cur.getchannel("A")).astype(np.uint8)
    rgb = np.asarray(cur.convert("RGB")).astype(np.uint8).copy()
    R, G, B = (rgb[..., i].astype(int) for i in range(3))

    red = (R > 95) & (R - G > 25) & (R - B > 22) & (sa > 8)
    letter = _dilate(red, 2)

    # 清掉碎笔画（远小于一个字母连通块）
    seen = np.zeros_like(red)
    cleaned = 0
    h, w = red.shape
    for sy, sx in zip(*np.where(red)):
        if seen[sy, sx]:
            continue
        dq = deque([(sy, sx)])
        seen[sy, sx] = True
        comp = []
        while dq:
            cy, cx = dq.popleft()
            comp.append((cy, cx))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < h and 0 <= nx < w and red[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    dq.append((ny, nx))
        if len(comp) < 150:
            px = np.array(comp)
            y0, y1 = max(0, px[:, 0].min() - 4), min(h - 1, px[:, 0].max() + 4)
            x0, x1 = max(0, px[:, 1].min() - 4), min(w - 1, px[:, 1].max() + 4)
            ring = [rgb[cy, cx] for cy in range(y0, y1 + 1) for cx in range(x0, x1 + 1)
                    if not red[cy, cx] and oa[cy, cx] > 8]
            if ring:
                col = np.median(np.array(ring, dtype=np.float32), axis=0).astype(np.uint8)
                for cy, cx in comp:
                    rgb[cy, cx] = col
                cleaned += len(comp)

    new_a = oa.copy()
    new_a[letter] = 255

    ys, xs = np.where(letter)
    b = [max(0, int(xs.min()) - 6), max(0, int(ys.min()) - 6),
         min(w - 1, int(xs.max()) + 6), min(h - 1, int(ys.max()) + 6)]

    res = Image.fromarray(rgb, "RGB").convert("RGBA")
    res.putalpha(Image.fromarray(new_a, "L"))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    res.save(out_path)
    side = out_path.with_name(out_path.stem + ".band.json")
    side.write_text(json.dumps({"alpha_band": b}, ensure_ascii=False), encoding="utf-8")

    A = np.asarray(res.getchannel("A")).astype(int)
    sub_s = sa[b[1]:b[3] + 1, b[0]:b[2] + 1]
    sub_o = A[b[1]:b[3] + 1, b[0]:b[2] + 1]
    outside = np.ones(sa.shape, bool)
    outside[b[1]:b[3] + 1, b[0]:b[2] + 1] = False
    print(f"碎笔画清除 {cleaned} px | 字块 {int(letter.sum())} px | band {b}")
    print(f"带内 alpha>250: {(sub_s > 250).mean():.1%} → {(sub_o > 250).mean():.1%}"
          f" | 带内 alpha<100: {(sub_s < 100).mean():.1%} → {(sub_o < 100).mean():.1%}")
    print(f"带外 alpha 与源图一致: {np.array_equal(sa[outside], A[outside])}")
    print("写出", out_path, "+", side.name)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
