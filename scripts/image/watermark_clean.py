#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""水印清理 —— 抹掉生成图右下角的模型水印（"AI生成 / WORKBUDDY" 之类）。

为什么单独立一个模块
--------------------
去水印是「重绘管线」里唯一必须动像素的手术，也是最容易出事故的一步：

  🔴 羽化混合（feather blend）会把原字的残影按 feather 比例渗回来。
     实测掩码内部 feather 最低只有 0.32 —— 最终图里水印亮度从 120 掉到 86，
     肉眼在深色渐变背景上仍然看得见 "AI生成 WORKBUDDY"。**必须硬替换。**

  🔴 只做膨胀不做阈值放宽时，字的外发光（halo）会留一圈灰边；
     阈值用 bg+10、膨胀 21px 才能吃干抹净（字宽约 120px，这点膨胀不算大）。

做法
----
1. 只在右下角 ROI 里找「明显比局部背景亮」的像素（水印是浅灰白，背景是深色渐变）；
2. 膨胀成硬掩码；
3. 把图缩到 1/8 分辨率，用掩码外的边界值做拉普拉斯扩散，得到一张**低频背景场**；
4. 硬替换回原分辨率，边界处只做 3px 级别的极轻柔化（掩码外像素一个都不许进来）。

之所以用 1/8 低频延拓而不是直接拟合：底图常有淡淡的对角折面和光晕，
低频场能自然延续它们，且不会把水印的灰度当结构抄进去。
"""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageFilter

# 水印区 ROI：右下角，按比例取，避免写死像素坐标
# 🔴 ROI 不能开太大。原先是 x>0.72 / y>0.90 —— 那张 856x2048 的超值底板重绘时，
#    标题「Rebate」的尾部正好落在 0.72W 之后，被当成水印硬替换掉了，字被吃掉一半。
#    实测水印本体在 x 0.918~0.986、y 0.933~0.981（1536x1024 的生成图上），
#    收紧到 0.88 / 0.92 既盖住水印，又给相邻大字留出 ~60px 余量。
ROI_X0_RATIO = 0.88
ROI_Y0_RATIO = 0.92
LUM_DELTA = 10      # 比局部背景中值亮多少算水印
# 🔴 只按「亮」判会误杀正常美术：ChatGPT 出的圣诞图右下角是礼盒/拐杖糖/灯串，
#    亮度 250，被当成水印整片抹掉 11763px（占 ROI 78%），画被挖了个洞。
#    水印是**浅灰白字**（三通道差小），节日装饰是高饱和的红/绿/金 —— 用饱和度分。
SAT_MAX = 60        # max(R,G,B)-min(R,G,B) 上限
# 再加一道兜底：一个角落要是大半个 ROI 都"亮且灰"，那不可能是水印，是画
MAX_COVER = 0.30
# 🔴 光靠亮度+饱和度还是分不开「白雪/白毛边」和「白色水印字」。真正的判据是**形状**：
#    水印是**一行字**，包围盒高度只有 ROI 的 4 成左右；装饰是铺满整片角落的团块。
#    实测：内置模型水印 bbox 高 41% ROI；ChatGPT 圣诞图的礼盒+拐杖糖 100% ROI。
MAX_BBOX_H = 0.55
DILATE_PX = 15      # 膨胀核（奇数），吃掉抗锯齿与外发光；别超 21，否则会咬到邻近的字
DOWNSCALE = 8       # 低频场分辨率
DIFFUSE_ITERS = 1200


def detect_mask(rgb: np.ndarray, verbose: bool = True, force: bool = False) -> np.ndarray:
    """返回 (H,W) bool 掩码：右下角「又亮、又灰、又排成一行」的像素（水印特征），其余不动。

    force=True 跳过所有形状/占比判断（已知这张图确实带水印、且水印不在右下角常规位置时用）。
    """
    h, w, _ = rgb.shape
    y0, x0 = int(h * ROI_Y0_RATIO), int(w * ROI_X0_RATIO)
    roi = rgb[y0:, x0:].astype(np.float32)
    lum = roi.mean(axis=2)
    sat = roi.max(axis=2) - roi.min(axis=2)
    bg = float(np.median(lum))
    cand = (lum > bg + LUM_DELTA) & (sat < SAT_MAX)
    mask = np.zeros((h, w), bool)
    if not cand.any():
        return mask

    def reject(why: str) -> np.ndarray:
        if verbose:
            print(f"  [watermark] 右下角不像水印（{why}）—— 按美术内容保留，不做修复")
        return mask

    if not force:
        if cand.mean() > MAX_COVER:
            return reject(f"{cand.mean():.0%} 的像素都是亮且灰的，超过 {MAX_COVER:.0%} 上限")
        ys, _ = np.where(cand)
        bh_ratio = (ys.max() - ys.min() + 1) / roi.shape[0]
        if bh_ratio > MAX_BBOX_H:
            return reject(f"亮灰像素纵向铺满 {bh_ratio:.0%} 的角落，不是一行字")

    mask[y0:, x0:] = cand
    dilated = Image.fromarray((mask * 255).astype(np.uint8)).filter(
        ImageFilter.MaxFilter(DILATE_PX))
    return np.array(dilated) > 127




def _lowfreq_background(rgb: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """1/8 分辨率上扩散出平滑背景场，再上采样回原尺寸。"""
    h, w, _ = rgb.shape
    sw, sh = max(1, w // DOWNSCALE), max(1, h // DOWNSCALE)
    small = np.array(Image.fromarray(rgb).resize((sw, sh), Image.LANCZOS)).astype(np.float32)
    s_mask = np.array(
        Image.fromarray((mask * 255).astype(np.uint8)).resize((sw, sh), Image.BILINEAR)) > 100

    fill = small.copy()
    fill[s_mask] = small[~s_mask].mean(axis=0)
    for _ in range(DIFFUSE_ITERS):
        avg = (np.roll(fill, 1, 0) + np.roll(fill, -1, 0) +
               np.roll(fill, 1, 1) + np.roll(fill, -1, 1)) / 4.0
        fill[s_mask] = avg[s_mask]
    filled = Image.fromarray(fill.clip(0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.array(filled).astype(np.float32)


def clean(rgb: np.ndarray, mask: np.ndarray | None = None,
          force: bool = False) -> tuple[np.ndarray, np.ndarray]:
    """返回 (清理后的 RGB, 使用的掩码)。掩码为空（没检测到水印）时原样返回。"""
    if mask is None:
        mask = detect_mask(rgb, force=force)
    if not mask.any():
        return rgb.copy(), mask

    out = rgb.astype(np.float32)
    out[mask] = _lowfreq_background(rgb, mask)[mask]     # 🔴 硬替换，不羽化
    soft = np.array(Image.fromarray(out.clip(0, 255).astype(np.uint8))
                    .filter(ImageFilter.GaussianBlur(1.6))).astype(np.float32)
    weight = np.array(Image.fromarray((mask * 255).astype(np.uint8))
                      .filter(ImageFilter.GaussianBlur(3))).astype(np.float32)[..., None] / 255.0
    out = out * (1 - weight) + soft * weight
    return out.clip(0, 255).astype(np.uint8), mask


def residue_level(rgb: np.ndarray) -> dict:
    """量化水印残留：右下角 ROI 的最亮值与对比度。用于验收断言，不靠肉眼。"""
    h, w, _ = rgb.shape
    y0, x0 = int(h * ROI_Y0_RATIO), int(w * ROI_X0_RATIO)
    roi = rgb[y0:, x0:].astype(np.float32).mean(axis=2)
    return {
        "max": float(roi.max()),
        "std": float(roi.std()),
        "p99": float(np.percentile(roi, 99)),
    }
