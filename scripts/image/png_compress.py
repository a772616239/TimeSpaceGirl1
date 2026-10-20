#!/usr/bin/env python3
"""PNG 体积压缩：先无损重编码，压不下去再逐级降位深，并用量化误差兜底。

为什么单独一个模块（而不是塞进 publish）：
  · 「换风格」出的图是 32bit RGBA 全彩，比原资源大 1.5~2 倍是常态——生成模型会往
    画面里塞雪花、灯串、光斑这类高频细节，颜色数从 10 万涨到 34 万，尺寸一样但体积翻倍。
  · 这种膨胀不是「画错了」，是**交付前该做的一步**：游戏资源按体积算包体，不按好不好看算。
  · 但压缩必须可断言：每一档都量「体积」和「不透明区的最大通道差」，超预算就退回上一档。

档位（auto 模式按顺序尝试，取第一个满足目标的）：
  0. 无损：PIL optimize 重编码（像素完全不变）
  1~4. 降位深 7/6/5/4 bit（每通道保留 128/64/32/16 级）—— 对 anime 平涂几乎不可见，
       但对渐变天空/发光晶体要盯 max_diff，所以每一档都实测。

用法：
    from png_compress import compress_file
    rep = compress_file(src, target_kb=685, max_diff=8)
    print(rep["saved_pct"])
"""
from __future__ import annotations

import io
import os
from pathlib import Path

import numpy as np
from PIL import Image


def _encode(img: Image.Image) -> bytes:
    buf = io.BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def _posterize(img: Image.Image, bits: int) -> Image.Image:
    """把每个通道压到 bits 位再拉回 0..255，alpha 原样不动。

    🔴 不要用 Image.quantize 做这件事：它对 RGBA 只支持 FASTOCTREE，
       256 色调色板会把发光/渐变打出明显色块（实测平均差 22，肉眼可见）。
       降位深是「均匀削精度」，对平涂 anime 几乎无损，对渐变也只是轻微台阶。
    """
    step = 256 >> bits
    chans = []
    for ch in img.split():
        arr = np.asarray(ch).astype(np.int16)
        arr = (np.round(arr / step) * step).clip(0, 255).astype(np.uint8)
        chans.append(Image.fromarray(arr))
    return Image.merge(img.mode, chans)


def _max_diff(a: Image.Image, b: Image.Image) -> int:
    """只在不透明区比较——透明区的 RGB 是垃圾值，拿它算误差没有意义。"""
    aa = np.asarray(a.convert("RGBA")).astype(np.int16)
    bb = np.asarray(b.convert("RGBA")).astype(np.int16)
    mask = aa[:, :, 3] > 8
    if not mask.any():
        return 0
    return int(np.abs(aa[:, :, :3] - bb[:, :, :3])[mask].max())


def compress_file(src: str | Path, dst: str | Path | None = None,
                  target_kb: float | None = None, max_diff: int = 8,
                  mode: str = "auto", log=print) -> dict:
    """压缩一张 PNG，返回报告 dict（含体积、档位、误差、节省比例）。

    target_kb=None 表示只做无损重编码；给了目标就允许降位深去够到它。
    mode="lossless" 时永远只做无损；mode="off" 直接原样返回。
    """
    src = Path(src)
    dst = Path(dst) if dst else src
    raw = src.read_bytes()
    size0 = len(raw)
    report = {"src": str(src), "dst": str(dst), "bytes_in": size0, "mode": mode}

    if mode == "off":
        if dst != src:
            dst.write_bytes(raw)
        report.update(bytes_out=size0, level="off", saved_pct=0.0, max_diff=0)
        return report

    # 🔴 保住源模式：RGB 图被无条件转成 RGBA 再存回去，等于给资源凭空加一个 alpha 通道，
    #    Unity 的纹理导入/压缩口径跟着变（体积也会变大），而且肉眼完全看不出来。
    #    只有调色板/带透明表的图才需要展开成真彩。
    im = Image.open(io.BytesIO(raw))
    if im.mode not in ("RGB", "RGBA", "L", "LA"):
        keep_alpha = "A" in im.getbands() or "transparency" in im.info
        im = im.convert("RGBA" if keep_alpha else "RGB")
    im.load()

    # 0) 无损
    best_bytes = _encode(im)
    best_level = "lossless"
    best_diff = 0

    if mode == "auto" and target_kb and len(best_bytes) / 1024 > target_kb:
        # 1~4) 逐级降位深；每档都实测体积与误差，超预算立刻停
        for bits in (7, 6, 5, 4):
            cand = _posterize(im, bits)
            data = _encode(cand)
            d = _max_diff(im, cand)
            log(f"  · {bits}bit: {len(data)/1024:.1f} KB, 最大通道差 {d}")
            if d > max_diff:
                log(f"    ↳ 超过误差预算 {max_diff}，不再往下压")
                break
            if len(data) < len(best_bytes):
                best_bytes, best_level, best_diff = data, f"{bits}bit", d
            if len(data) / 1024 <= target_kb:
                break

    # 压完反而更大 → 保留原文件（不为了「压过」而变大）
    if len(best_bytes) >= size0:
        report.update(bytes_out=size0, level="none(原样保留)", max_diff=0,
                      saved_pct=0.0)
        if dst != src:
            dst.write_bytes(raw)
        return report

    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(best_bytes)
    report.update(bytes_out=len(best_bytes), level=best_level, max_diff=best_diff,
                  saved_pct=round(100 * (1 - len(best_bytes) / size0), 1))
    return report


def describe(rep: dict) -> str:
    return ("压缩 %s：%.1f KB → %.1f KB（-%s%%，档位 %s，最大通道差 %d）"
            % (Path(rep["src"]).name, rep["bytes_in"] / 1024, rep["bytes_out"] / 1024,
               rep["saved_pct"], rep["level"], rep["max_diff"]))


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="PNG 体积压缩")
    ap.add_argument("path")
    ap.add_argument("--out", default=None)
    ap.add_argument("--target-kb", type=float, default=None)
    ap.add_argument("--max-diff", type=int, default=8)
    ap.add_argument("--mode", choices=["auto", "lossless", "off"], default="auto")
    a = ap.parse_args()
    print(describe(compress_file(a.path, a.out, a.target_kb, a.max_diff, a.mode)))
