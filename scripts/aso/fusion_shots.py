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
import hashlib
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aso_common as C  # noqa: E402

SRC_DIR = "fusion_all"          # data_aso/derived/<变体>/fusion_all/<语言>/feature_duo_<tag>.png
DEFAULT_SIZE = (1024, 520)      # 1.969 : 1

# 上线顺序 = 商店页展示顺序，第一张权重最高。
# 前三张全是战斗（核心玩法），后三张换口味（副本地图 / 主城 / 世界地图）。
# 只列有合格画面素材的 6 组 —— 0823（公会徽章太空）和 1624（battle.png 像战斗准备）不上。
DEFAULT_ORDER = [
    "0102",   # #0 七乘七战斗，角色最多
    "2019",   # #1 红 BOSS，视觉冲击
    "1013",   # #3 雪原遭遇战
    "0922",   # #2 机械关双线交火
    "0715",   # #4 霓虹主城
    "1821",   # #7 世界关卡地图
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


def _caption(tag: str, locale: str) -> str:
    """该组该语言的底部文案（写进 index.json，供验收页显示）。取不到就留空。"""
    pf = C.ASSETS_DIR / "fusion_pairs.json"
    if not pf.is_file():
        return ""
    for p in (C.load_json(pf).get("pairs") or []):
        if str(p.get("tag")) == tag:
            return ((p.get("copy") or {}).get(locale) or {}).get("title", "")
    return ""


def _patch_index(variant: str, manifest: dict, size: tuple[int, int]) -> None:
    """把横版截图的真实 size/bytes/sha1 写回 index.json。

    不做这步，`aso_assets.py check` 会拿旧的 1080×1920 记录去体检（判定不一致），
    `preview.html` 也会显示竖版的尺寸与哈希 —— 看着像「换了图没生效」。
    feature_01 条目原样保留（置顶图没动）。
    """
    idx_path = C.DERIVED_DIR / variant / "index.json"
    if not idx_path.is_file():
        print(f"（没有 {idx_path.relative_to(C.ROOT)}，跳过 index 同步）")
        return
    idx = json.loads(idx_path.read_text(encoding="utf-8"))
    idx["canvas"] = [size[0], size[1]]
    idx.setdefault("_shot_source", "fusion_shots.py（横版 1024×520，源自 fusion_all）")
    for loc, items in manifest.items():
        old = idx["locales"].get(loc, [])
        # 非 shot 的条目（feature_01 等）原样保留；按文件名去重 ——
        # 旧版本曾把 feature_01 写进两个位置，这里顺手修掉历史脏数据。
        extra, seen = [], set()
        for e in old:
            if e["file"].startswith("shot_") or e["file"] in seen:
                continue
            seen.add(e["file"])
            extra.append(e)
        entries = []
        for it in items:
            p = C.DERIVED_DIR / variant / loc / it["shot"]
            entries.append({
                "file": it["shot"],
                "src": it["src"],
                "size": list(size),
                "upscale": 1.0,
                "caption": it.get("caption", ""),
                "bytes": p.stat().st_size,
                "sha1": hashlib.sha1(p.read_bytes()).hexdigest(),
            })
        # 截图在前、置顶图在后，与 aso_assets 的写法一致
        idx["locales"][loc] = entries + extra
    idx_path.write_text(json.dumps(idx, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"index 已同步 → {idx_path.relative_to(C.ROOT)}（canvas {size[0]}×{size[1]}）")


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

    # 🔴 画面框必须各不相同（2026-10-24 用户两次指出「截屏重复」）。
    # 校验 fusion_pairs.json 里每个 tag 的 screen.shot，重复就直接拒绝：
    # 靠眼睛在 1024×500 缩略图上查不出来，只能机器拦。
    pairs_file = C.ASSETS_DIR / "fusion_pairs.json"
    if pairs_file.is_file():
        screen_of = {str(p["tag"]): (p.get("screen") or {}).get("shot")
                     for p in (C.load_json(pairs_file).get("pairs") or [])}
        seen: dict = {}
        for t in tags:
            s = screen_of.get(t)
            if s is None:
                continue
            seen.setdefault(s, []).append(t)
        dup = {k: v for k, v in seen.items() if len(v) > 1}
        if dup:
            print("🔴 画面框截图重复，Play 商店页会像同一张图刷了 8 遍：")
            for s, ts in dup.items():
                print(f"   shots.json #{s} 被 {', '.join(ts)} 共用")
            print("   到 fusion_pairs.json 里改 screen.shot（可用 #0~#7 共 8 条不同素材）")
            return 2

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
                 "src": str(src.relative_to(C.ROOT)), "size": [tw, th],
                 "caption": _caption(tag, loc)})
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
    _patch_index(a.variant, manifest, (tw, th))
    print(f"\n下一步：aso_play.py push --variant {a.variant} --images-only "
          f"--image-types phoneScreenshots --shots "
          f"{','.join(str(i) for i in range(len(tags)))} --allow-write --yes --auto-review")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
