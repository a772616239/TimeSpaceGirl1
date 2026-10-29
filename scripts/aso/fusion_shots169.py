#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""16:9 商店截图（1280×720）：底图 + 底置实机竖窗 + 顶置标题。

为什么单独一个脚本，而不是给 `fusion_shots.py` 加参数
--------------------------------------------------------
`fusion_shots.py` 是「1024×520 补边 + 台账」的后处理，取景与版面全在 `fusion.json`。
16:9 这条路线有三条硬约束是那个版面表达不了的（框比例要跟 band 联动、标题要挪到顶部
且不许铺 scrim、框要压出画布底边），硬塞进 `duo` 只会把两条路线互相拖死。

三条硬约束（都是 2026-10-29 那次「未过审」逼出来的）
------------------------------------------------------
1. **不许放大**。Play 的驳回原文是「no obvious blurring, stretching, compression」。
   真机截图源最大只有 720×1280（其余 597~598 宽），1920 画布下画面框要 845px ⇒ 1.41× 放大，
   放大后的 UI 边缘就是「明显模糊」。**1280×720 画布下同一个框只要 563px < 598 ⇒ 是缩小**，
   框里每个像素都是原生的。所以画布定死 1280×720（Play 对 16:9 的建议下限就是它）。
2. **不许有黑边**。`bg_*.png` 底部 22% 是纯黑（局部细节 0.1~3.0，其它区域 16~26），
   原版面把标题压在那块黑上 = Play 说的「black edges」+「solid colors and gradients」。
   现做法：画面框从 y=0.40 一路压出画布底边，中间那块黑被实机画面整块盖住；
   左右两角留的是角色衣摆（有细节），不是空背景。
3. **不许拉伸**。框内一律 `_cover` 等比裁切，band 跨度按「框宽 ÷ 框比例」反算，
   不做任何非等比缩放。

只出三张是素材上限，不是偷懒
----------------------------
`shots.json` 里 8 张只有 3 张是真机竖版高清图（598×1296 / 720×1280 / 597×1299），
另外 5 张是 334~412px 的场景小图，放大到 563px 就是 1.4~1.7× 放大 —— 正是这次被驳回的
那个毛病。Play 要求「3 张及以上」，**宁可 3 张全清晰，也不要 6 张一半模糊**。
补齐第 4~6 张的唯一办法是真机重打 1080×1920 截图（源分辨率就是天花板）。

用法
----
    python3 scripts/aso/fusion_shots169.py                 # 出全部 3 张，英文
    python3 scripts/aso/fusion_shots169.py --tags 0102,2019
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aso_common as C  # noqa: E402
import aso_fusion as F  # noqa: E402

# 上线顺序 = 商店页展示顺序。三张全是战斗（核心玩法），
# 且都是真机竖版高清图 —— 这是能出 16:9 而不放大的全部素材。
ORDER = ["0102", "2019", "0922"]

# 每张源图的「战斗区」上下界（占源图高的比例）。
# 🔴 下界卡在技能条/聊天面板之上：那两块是纯色大色块 + 中文 UGC，
#    进商店页既触发「solid colors」又会让英文页出现中文。
BATTLE_CROP = {
    0: (0.160, 0.620),   # c9588e7f  工厂 7x7 网格，598×1296（0.16 以上是天空，留着框里发空）
    1: (0.045, 0.445),   # MuMu      红 BOSS 战，720×1280（下方 0.47~0.72 是大片纯紫）
    2: (0.160, 0.620),   # 39a68891  机械关双线交火，597×1299
}

# 版面（全部是画布比例）
WIN_X0, WIN_X1 = 0.28, 0.72      # 框宽 0.44 × 1280 = 563px < 598（源宽）⇒ 只缩小
WIN_Y0 = 0.40                    # 压到画布底边以下，盖掉底图那块纯黑
WIN_Y1 = 1.03                    # >1 ⇒ 框底边落在画布外，看不到「被切断的边」
KICKER_Y = 0.026
TITLE_Y = 0.060
TITLE_SIZE = 0.118               # 首行字号（占画布高），两行共用同一个字号
TITLE_MAXW = 0.44                # 🔴 两行都必须 ≤0.50 画布宽，否则会压到左右角色脸上

# 标题折成两行：单人两行的宽度才塞得进「两个角色之间的天空缝隙」，
# 一行写死「7X7. POSITION WINS.」在 1280 宽下必然横穿右边角色的脸。
TITLE_LINES = {
    "0102": ["7X7.", "POSITION WINS."],
    "2019": ["PLAN BEFORE", "YOU PUSH"],
    "0922": ["BOTH LINES", "MOVE UP"],
}


def _spec() -> dict:
    return C.load_json(C.ASSETS_DIR / "shots.json")


def battle_img(shot_idx: int) -> Image.Image:
    """该组的实机画面：只留战斗区，等比裁切到框比例（不拉伸）。"""
    item = (_spec().get("shots") or [])[shot_idx]
    im = Image.open(C.ROOT / item["src"]).convert("RGB")
    top, bot = BATTLE_CROP[shot_idx]
    return im.crop((0, int(im.height * top), im.width, int(im.height * bot)))


def extend_floor(im: Image.Image) -> Image.Image:
    """把底图底部那块纯黑换成「湿地面反射」。

    `bg_*.png` 底部 22% 是生成时留空的标题区（局部细节 0.1~3.0，其它区域 16~26），
    画面框只能盖住中间，**左右两个下角会留下纯黑三角** —— 这就是 Play 判的 black edges。
    补法：取黑区上方等高的一条，垂直翻转 + 压暗 + 轻微模糊，当霓虹夜街的湿地面反射。
    等高翻转 ⇒ 不拉伸；内容是真实画面 ⇒ 不是纯色/渐变；只糊 2px ⇒ 不是「明显模糊」。
    """
    W, H = im.size
    y1 = int(H * 0.78)                 # 黑区上沿
    band_h = H - y1
    band = im.crop((0, y1 - band_h, W, y1)).transpose(Image.FLIP_TOP_BOTTOM)
    # 亮度沿深度衰减：接缝处 0.95（几乎不断层）→ 底部 0.42（远处更暗）。
    # 不加这层渐变，接缝就是一条横贯全图的硬线，比黑边还难看。
    ramp = np.linspace(0.95, 0.42, band_h, dtype=np.float32)[:, None, None]
    arr = np.asarray(band, np.float32) * ramp
    band = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    band = band.filter(ImageFilter.GaussianBlur(2.5))
    out = im.copy()
    out.paste(band, (0, y1))
    return out


def _copy(tag: str, locale: str) -> tuple[str, str]:
    for p in (C.load_json(C.ASSETS_DIR / "fusion_pairs.json").get("pairs") or []):
        if str(p.get("tag")) == tag:
            c = (p.get("copy") or {}).get(locale) or {}
            k, t = c.get("kicker") or "", c.get("title") or ""
            return (k.upper(), t.upper()) if locale.startswith("en") else (k, t)
    return "", ""


def render(tag: str, locale: str, size: tuple[int, int]) -> Image.Image:
    W, H = size
    spec = C.load_json(F.FUSION_SPEC)
    lay = spec["layouts"]["duo169"]

    bg = Image.open(C.ROOT / f"data_aso/assets/gen/fusion/bg_{tag}.png").convert("RGB")
    # 先在 1920×1080 原尺寸补底（反射带要按原始比例取），再缩到画布。
    bg = extend_floor(bg)
    canvas = bg.resize((W, H), Image.LANCZOS).convert("RGBA")

    shot = battle_img(_shot_of(tag))
    box = (int(W * WIN_X0), int(H * WIN_Y0), int(W * WIN_X1), int(H * WIN_Y1))
    canvas = F.draw_screen(canvas, box, 0, int(round(0.010 * W)),
                           F._hex(lay["screen"].get("glow") or "#FFC978"),
                           0.5, None, 0.5, 1.0, None, 1.06, shot_img=shot)

    kicker, _ = _copy(tag, locale)
    accent = F._hex(lay["screen"].get("glow") or "#FFC978")
    _draw_title(canvas, kicker, TITLE_LINES[tag], locale, accent)
    return canvas.convert("RGB")


def _draw_title(canvas: Image.Image, kicker: str, lines: list[str],
                locale: str, accent: tuple) -> None:
    """顶部两行标题：先求「两行都塞得进 0.50 宽」的统一字号，再逐行压字。"""
    W, H = canvas.size
    d = ImageDraw.Draw(canvas)
    maxw = W * TITLE_MAXW
    size, floor = int(H * TITLE_SIZE), int(H * 0.062)
    while size > floor:
        f = F.font_for(locale, size)
        if all(d.textlength(ln, font=f) <= maxw for ln in lines):
            break
        size -= 2
    y = TITLE_Y
    for i, ln in enumerate(lines):
        F.draw_caption(canvas, kicker if i == 0 else "", ln, locale, 1.05,
                       KICKER_Y, y, accent,
                       title_ratio=size / H, max_w_ratio=TITLE_MAXW)
        y += size * 1.14 / H


def _shot_of(tag: str) -> int:
    for p in (C.load_json(C.ASSETS_DIR / "fusion_pairs.json").get("pairs") or []):
        if str(p.get("tag")) == tag:
            return int((p.get("screen") or {}).get("shot") or 0)
    raise SystemExit(f"fusion_pairs.json 里没有 tag={tag}")


def _audit(im: Image.Image, shot: Image.Image, box_w: int) -> dict:
    """验收三个驳回点：放大倍数、黑边、整体细节。

    🔴 黑边要按**四个角和整条底边**分别测，不能只测「底部 20% 的平均值」：
    画面框只盖住中间，底部左右两个三角仍然是底图的纯黑（实测均值 2.0、细节 0.06），
    但被框内画面一平均就掩盖过去了 —— 2026-10-29 就是这么漏掉、被用户当场看出来的。
    """
    a = np.asarray(im.convert("L"), np.float32)
    H, W = a.shape

    def detail(b: np.ndarray) -> float:
        bl = np.asarray(Image.fromarray(b.astype(np.uint8))
                        .filter(ImageFilter.GaussianBlur(6)), np.float32)
        return float(np.abs(b - bl).mean())

    zones = {
        "bottom": a[int(H * 0.92):],
        "bot_left": a[int(H * 0.90):, :int(W * 0.22)],
        "bot_right": a[int(H * 0.90):, int(W * 0.78):],
    }
    rec = {"window_px": box_w, "source_px": shot.width,
           "scale": round(box_w / shot.width, 3)}
    for k, b in zones.items():
        rec[f"detail_{k}"] = round(detail(b), 2)
        rec[f"mean_{k}"] = round(float(b.mean()), 1)
    rec["bottom_min_detail"] = min(rec["detail_bottom"], rec["detail_bot_left"],
                                   rec["detail_bot_right"])
    return rec


def main() -> int:
    ap = argparse.ArgumentParser(description="16:9 商店截图（1280×720）")
    ap.add_argument("--tags", default=",".join(ORDER))
    ap.add_argument("--locale", default="en-US")
    ap.add_argument("--size", default="1280x720")
    ap.add_argument("--out", default="data_aso/derived/B/shots169")
    a = ap.parse_args()

    W, H = (int(x) for x in a.size.lower().split("x"))
    if abs(W / H - 16 / 9) > 0.01:
        print(f"🔴 画布必须是 16:9，当前 {W}x{H}（{W/H:.3f}）")
        return 2

    root = C.ROOT / a.out
    root.mkdir(parents=True, exist_ok=True)
    manifest = {"canvas": [W, H], "ratio": round(W / H, 4), "locale": a.locale, "shots": []}

    bad = 0
    for i, tag in enumerate([t.strip() for t in a.tags.split(",") if t.strip()], 1):
        shot = battle_img(_shot_of(tag))
        im = render(tag, a.locale, (W, H))
        p = root / f"{i:02d}_{tag}.png"
        im.save(p, optimize=True)
        rec = _audit(im, shot, int(W * (WIN_X1 - WIN_X0)))
        rec.update({"order": i, "tag": tag, "file": str(p.relative_to(C.ROOT)),
                    "bytes": p.stat().st_size,
                    "sha1": hashlib.sha1(p.read_bytes()).hexdigest()})
        manifest["shots"].append(rec)

        flag = ""
        if rec["scale"] > 1.02:
            flag += " 🔴放大"
            bad += 1
        if rec["bottom_min_detail"] < 4:
            flag += " 🔴底部/角上像黑边"
            bad += 1
        print(f"{rec['file']}  {W}x{H}  {rec['bytes']/1024:.0f} KB  "
              f"框 {rec['window_px']}px / 源 {rec['source_px']}px = {rec['scale']:.2f}×  "
              f"底边细节 {rec['detail_bottom']:.1f} / 左下 {rec['detail_bot_left']:.1f} / "
              f"右下 {rec['detail_bot_right']:.1f}{flag}")

    (root / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"\n共 {len(manifest['shots'])} 张 → {root.relative_to(C.ROOT)}")
    if bad:
        print(f"🔴 {bad} 处不合规，别上传")
        return 3
    print("✅ 放大倍数 ≤1.02、底部无黑边")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
