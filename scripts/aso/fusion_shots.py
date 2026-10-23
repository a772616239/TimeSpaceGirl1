#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把拼装式置顶图（1024×500）合规化成 Play 手机截图（1024×520）。

    fusion_shots.py --variant B --tags 0102,0715,0823
    fusion_shots.py --variant B --dry-run

为什么需要这一步
----------------
置顶图是 1024×500，长宽比 **2.048**；Play 对 phoneScreenshots 的硬上限是 **2:1**，
超了直接拒。差 12px 而已，所以不是「必须改竖版」，而是「把高度补到 520」——
比例降到 1.969，画面一个像素都不动。

补边不用纯色条（会显出一条硬边，也容易看成「黑边」），而是取图片首/末若干行
做高斯模糊后拉伸填进去，肉眼分辨不出补过。

产物
----
    data_aso/derived/<变体>/<语言>/shot_<NN>.png   1080×1920 会被这里替换成 1024×520

🔴 与 aso_assets.py build 的关系
--------------------------------
`aso_assets.py build` 会把这批 shot_*.png 覆盖成 1080×1920 竖版。
用过本脚本之后**不要再跑 build**，否则横屏方案被打回竖版。
`aso_assets.py preview`（只重画验收页、不动图）可以随便跑。
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aso_common as C  # noqa: E402

SRC_DIR = "fusion_all"          # data_aso/derived/<变体>/fusion_all/<语言>/feature_duo_<tag>.png
DEFAULT_SIZE = (1024, 520)      # 1.969 : 1

# 上线顺序 = 商店页展示顺序，第一张权重最高。
# 文案按 category 轮换，避免 8 张全是「召唤·布阵·碾压」。
DEFAULT_ORDER = [
    "0102",   # combat
    "0715",   # world  —— 神话 vs 未来，换掉一口气
    "0823",   # guild
    "2019",   # combat —— 东方 vs 西方
    "0922",   # combat —— 双机械，冷色
    "1624",   # combat —— 巨拳 × 能量炮
    "1013",   # combat —— 暖冷对撞
    "1821",   # map    —— 收尾换氛围
]


def _pad(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """等比缩放后上下补模糊边，补到目标画布。"""
    tw, th = size
    r = min(tw / im.width, th / im.height)
    n = im.resize((max(1, round(im.width * r)), max(1, round(im.height * r))), Image.LANCZOS)
    if n.size == size:
        return n

    canvas = Image.new("RGB", size, (8, 8, 12))
    pad_v = (th - n.height) // 2
    if pad_v > 0:
        # 顶部：取首 12 行模糊后拉伸；底部：取末 12 行模糊后拉伸。
        # 纯色条会留下硬边，模糊延伸看不出接缝。
        for src_box, dst_y in (
            ((0, 0, n.width, max(2, n.height // 40)), 0),
            ((0, n.height - max(2, n.height // 40), n.width, n.height), th - pad_v),
        ):
            strip = n.crop(src_box).resize((n.width, pad_v), Image.LANCZOS)
            strip = strip.filter(ImageFilter.GaussianBlur(pad_v / 3))
            canvas.paste(strip, (0, dst_y))
        canvas.paste(n, ((tw - n.width) // 2, pad_v))
    else:
        canvas.paste(n, ((tw - n.width) // 2, 0))
    return canvas


def main() -> int:
    ap = argparse.ArgumentParser(description="置顶图 → Play 手机截图（合规 1024×520）")
    ap.add_argument("--variant", default="B")
    ap.add_argument("--locales", default="en-US,ja-JP,zh-CN,zh-TW")
    ap.add_argument("--tags", default="",
                    help="逗号分隔的组号（决定顺序）；留空用内置 DEFAULT_ORDER")
    ap.add_argument("--size", default="1024x520")
    ap.add_argument("--src", default="", help="覆盖源目录（相对 data_aso/derived/<变体>/）")
    ap.add_argument("--dry-run", action="store_true", help="只列文件名与尺寸，不落盘")
    a = ap.parse_args()

    tw, th = (int(x) for x in a.size.lower().split("x"))
    ratio = tw / th
    if ratio > 2.0:
        print(f"🔴 {tw}×{th} 长宽比 {ratio:.3f} > Play 上限 2.0，会被拒")
        return 2

    tags = [t.strip() for t in a.tags.split(",") if t.strip()] or DEFAULT_ORDER
    src_root = C.DERIVED_DIR / a.variant / (a.src or SRC_DIR)
    manifest = {}
    total = 0

    for loc in C.parse_locales(a.locales):
        out_dir = C.DERIVED_DIR / a.variant / loc
        out_dir.mkdir(parents=True, exist_ok=True)
        if not a.dry_run:
            # 先清掉旧的 shot_*：上一轮可能是 9 张竖版，留着会混进上传
            # （Play 每语上限 8 张，多一张就 400）。
            for old in out_dir.glob("shot_*.png"):
                old.unlink()
        for i, tag in enumerate(tags):
            src = src_root / loc / f"feature_duo_{tag}.png"
            if not src.is_file():
                print(f"🔴 缺源图 {src.relative_to(C.ROOT)}")
                return 2
            im = _pad(Image.open(src).convert("RGB"), (tw, th))
            dest = out_dir / f"shot_{i:02d}.png"
            if not a.dry_run:
                im.save(dest, "PNG", optimize=True)
            manifest.setdefault(loc, []).append(
                {"shot": f"shot_{i:02d}.png", "tag": tag,
                 "src": str(src.relative_to(C.ROOT)), "size": [tw, th]})
            total += 1
        print(f"{loc}: {len(tags)} 张  {[f'shot_{i:02d}' for i in range(len(tags))]}")

    if a.dry_run:
        print(f"[dry-run] {total} 张，未落盘")
        return 0

    mf = C.DERIVED_DIR / a.variant / "fusion_shots_manifest.json"
    mf.write_text(json.dumps({
        "_comment": "横屏手机截图方案：由 fusion_shots.py 从 fusion_all 派生，"
                    "尺寸 1024×520（比例 1.969，Play 上限 2.0）。"
                    "🔴 用过本方案后不要再跑 aso_assets.py build，会把 shot_* 覆盖回 1080×1920 竖版。",
        "size": [tw, th], "ratio": round(ratio, 4), "locales": manifest,
    }, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n共 {total} 张 → {C.DERIVED_DIR / a.variant}/<locale>/shot_*.png")
    print(f"清单 → {mf.relative_to(C.ROOT)}")
    print(f"\n下一步：aso_play.py push --variant {a.variant} --images-only "
          f"--image-types phoneScreenshots --shots "
          f"{','.join(str(i) for i in range(len(tags)))} --allow-write --yes --auto-review")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
