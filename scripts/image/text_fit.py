"""出图族的「字完整性」判定与修补：lock 前 refit + OCR 译文闸门（2026-10-22 复盘）。

为什么单独成文件：`banner_translate.py` 同一时间被并行会话改（alpha_band 边车 /
本地合成器），把这一组自洽的判定与修补逻辑独立出来，两边改动不打架，也方便单测。

两个教训（都是实测，别再犯）：

1. 「文字落在实心 alpha 之外的比例」**不能**当闸门。
   实测 6 张人眼合格的 512x256 特写横幅：baiqi 15.7% / shiba 9.0% / aijiyanhou 26.6%
   / zhende 11.0% / zhitianxinzhang 28.6%；而被 alpha lock 啃掉半截字母的 #30 是 20.8%
   —— 区间完全重叠（笔刷底板边缘本来就参差、还有半透明接缝和网点）。零判别力。

2. 真判据是**逐像素**的：`ink & (alpha <= 8)`。
   笔画落在 alpha=0 上 = 运行时永远看不见 = 被切。这个量只能在 **lock 之前**算
   （lock 之后像素已经没了），所以在 `postprocess_photo` 之前先把字带压窄。
"""
from __future__ import annotations

import re
import subprocess
import tempfile
from difflib import SequenceMatcher
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

# 文字 ink 落在透明区的比例上限；超过它才算「会被切」
LOST_INK_RATIO = 0.004
# 字带横向最多压到它；再往下压字会糊成一团，不如让人改 LAYOUT 重出
REFIT_MIN_SCALE = 0.80

# OCR 相似度分档：≥PASS 认为一致；<FAIL 认为模型换了词；中间只给黄
OCR_PASS = 0.55
OCR_FAIL = 0.35


# --------------------------------------------------------------------------- #
# 一、lock 前的越界检测与修补
# --------------------------------------------------------------------------- #
def ink_mask(rgb: np.ndarray) -> np.ndarray:
    """把「像字的笔画」抠出来：亮像素 或 高饱和像素。

    不需要精确字形分割，只要能量「有多少笔画落在看不见的区域」：
      - 深色笔刷底板上，蓝渐变字 / 白字都算「亮」；
      - 亮底（图集纯色板）上底板自己也算 ink，但它整块落在 alpha 内，
        对「越界像素数」没有贡献 ⇒ 不会误判。
    """
    a = rgb.astype(np.int16)
    lum = a.mean(axis=2)
    sat = a.max(axis=2) - a.min(axis=2)
    return (lum > 110) | (sat > 45)


def cover_to(gen_im: Image.Image, W: int, H: int) -> Image.Image:
    """等比 cover 到 WxH（与 postprocess_photo 同一套算法，别在这里另发明一套）。"""
    g = gen_im
    s = max(W / g.width, H / g.height)
    nw, nh = max(W, round(g.width * s)), max(H, round(g.height * s))
    g = g.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - W) // 2, (nh - H) // 2
    return g.crop((left, top, left + W, top + H))


def refit_covered(src_im: Image.Image, gen_im: Image.Image) -> tuple[Image.Image, dict]:
    """在 lock 之前把越界的字带横向压窄，让每根笔画都落在 alpha>8 的可见区内。

    返回 (已 cover 好的图, info)。info["ok"] 是给 verify 用的硬结论。

    🔴 为什么必须在 lock 之前：`putalpha(源图 A)` 会把落在 alpha=0 上的笔画无条件
       啃掉，lock 之后补不回来（#14 末字母 S、#27 末字母 N 都是这么没的）。
    🔴 为什么只压「字带」而不是整幅：整幅缩会把笔刷底板一起缩，底板轮廓与源图
       alpha 错位 ⇒ 面板上多出一圈暗边。字带只占几十行，压窄后腾出来的列右邻
       「新文字右边缘列」是同一块底板色，而且那一带本来就基本是 alpha=0
       （正因为它在轮廓外，字才会被切），所以横向复制补满是肉眼不可见的。
    🔴 已归位好的成品（RGBA 且尺寸等于源图）不碰：那是本地合成器的输出，
       文字位置是确定性算出来的，不存在越界；压它反而会破坏 alpha_band 契约。
    """
    W, H = src_im.size
    if gen_im.mode == "RGBA" and gen_im.size == (W, H):
        return gen_im, {"ok": True, "skipped": "已归位成品（RGBA 同尺寸），不做 refit"}

    g = cover_to(gen_im.convert("RGB"), W, H) if gen_im.size != (W, H) else gen_im.convert("RGB")
    if src_im.mode != "RGBA":
        return g, {"ok": True, "skipped": "源图无 alpha（不透明），lock 语义不适用"}

    alpha = np.asarray(src_im.getchannel("A"))
    arr = np.asarray(g).copy()
    ink = ink_mask(arr)
    total = int(ink.sum())
    lost_mask = ink & (alpha <= 8)
    lost = int(lost_mask.sum())
    info: dict = {"ink_px": total, "lost_px": lost,
                  "lost_ratio": round(lost / max(1, total), 4),
                  "scale": 1.0, "applied": False}
    if not total or lost / total <= LOST_INK_RATIO:
        info.update(ok=True, detail=f"笔画落在透明区 {lost} px（{lost / max(1, total):.2%}），未越界")
        return g, info

    # 🔴 只压「真的有笔画掉在外面」的那几行，不要拿整幅 bbox：
    #    笔刷底板的高光/网点也是亮像素，算进 bbox 会把整幅都当成字带，
    #    一压就把底板一起拉窄（实测：压完越界像素一个都没少）。
    rows = np.where(lost_mask.any(axis=1))[0]
    ry0, ry1 = max(0, int(rows.min()) - 3), min(H - 1, int(rows.max()) + 3)
    sub_ink = ink[ry0:ry1 + 1]
    cols = np.where(sub_ink.any(axis=0))[0]
    x0, x1 = int(cols.min()), int(cols.max())
    band = arr[ry0:ry1 + 1, x0:x1 + 1]
    bh, bw = band.shape[0], band.shape[1]
    bg = np.median(band[~ink_mask(band)], axis=0) if (~ink_mask(band)).any() else np.median(
        band.reshape(-1, 3), axis=0)

    for k in [round(0.98 - 0.02 * i, 2) for i in range(9)]:      # 0.98 → 0.82
        nw = max(1, int(round(bw * k)))
        new = np.asarray(Image.fromarray(band).resize((nw, bh), Image.LANCZOS))
        canvas = arr.copy()
        canvas[ry0:ry1 + 1, x0:x0 + nw] = new
        if x0 + nw <= x1:
            # 腾出来的列填「这块底板的背景色中位数」，不能拿新文字边缘列复制 ——
            # 那一列本身就是笔画，横向复制会在轮廓外刷出一条亮条（实测踩过）。
            canvas[ry0:ry1 + 1, x0 + nw:x1 + 1] = bg.astype(np.uint8)
        ink2 = ink_mask(canvas)
        lost2 = int((ink2 & (alpha <= 8)).sum())
        tot2 = max(1, int(ink2.sum()))
        if lost2 / tot2 <= LOST_INK_RATIO:
            info.update(applied=True, scale=k, lost_px_after=lost2,
                        lost_ratio_after=round(lost2 / tot2, 4), row_band=[ry0, ry1],
                        ok=True,
                        detail=f"字带横向压到 {k:.0%} 后完全落版"
                               f"（压前 {lost} px / {lost / total:.2%} 落在透明区）")
            print(f"🔧 文字越界 {lost} px（{lost / total:.2%} 落在透明区，行带 y{ry0}..{ry1}）"
                  f"⇒ 字带横向压到 {k:.0%} 后落版（残余 {lost2} px）")
            return Image.fromarray(canvas), info

    info.update(ok=False,
                detail=f"压到 {REFIT_MIN_SCALE:.0%} 仍有笔画落在透明区"
                       f"（压前 {lost} px / {lost / total:.2%}，行带 y{ry0}..{ry1}）"
                       f"⇒ 只能改 LAYOUT 重出")
    print(f"🔴 文字越界 {lost} px（{lost / total:.2%} 落在透明区）；"
          f"压到 {REFIT_MIN_SCALE:.0%} 还进不去 ⇒ 判红，别硬压")
    return g, info


# --------------------------------------------------------------------------- #
# 二、OCR 译文闸门
# --------------------------------------------------------------------------- #
def has_tesseract() -> bool:
    try:
        r = subprocess.run(["tesseract", "--version"], capture_output=True, timeout=10)
        return r.returncode == 0
    except Exception:                                              # noqa: BLE001
        return False


def ocr_read(im: Image.Image) -> str | None:
    """读图上的拉丁字母。None = 本机没装 tesseract（闸门降级成 warn）。

    🔴 预处理是固定的：先 flatten 到**黑底**（透明区不能当白纸，否则白字消失），
       再取灰度反相（字变黑、底变白），最后 `--psm 6`（按块识别）。
       2026-10-22 实测 `cn2-x1_texie_mozhate_01_en` 读出 `HERO-SKILL / AVE VERUM / CoRPUS`。
    """
    if not has_tesseract():
        return None
    if im.mode != "RGBA":
        im = im.convert("RGBA")
    flat = Image.alpha_composite(Image.new("RGBA", im.size, (0, 0, 0, 255)), im).convert("L")
    tmp = Path(tempfile.mkstemp(suffix=".png")[1])
    try:
        ImageOps.invert(flat).save(tmp)
        r = subprocess.run(["tesseract", str(tmp), "stdout", "--psm", "6"],
                           capture_output=True, text=True, timeout=60)
        return " ".join(r.stdout.split())
    except Exception as e:                                          # noqa: BLE001
        print(f"⚠ OCR 执行失败（{e}），本轮跳过 OCR 闸门")
        return None
    finally:
        tmp.unlink(missing_ok=True)


def _norm(s: str) -> str:
    return re.sub(r"[^A-Z0-9]", "", s.upper())


def text_score(expected: list[str], read: str) -> tuple[float, str]:
    """译名字面 vs OCR 结果的相似度（0~1）：在 OCR 串里滑窗找「最长匹配段」。

    🔴 为什么用「模糊」而不是全等：美术字（发光/描边/渐变压扁）本来就读不准 ——
       实测合格品 baiqi 读出 `ECH°CS OF BLOOD`、zhitianxinzhang 读出 `TELIA FUBU`
       （真值 Tenka Fubu）。全等匹配会把合格品全判红。
       实测分档（窗口法）：合格品 0.78 / 0.85 / 0.86 / 0.93 / 1.00 / 1.00，
       而 #27 的 `DIVINE JUDGMENT` vs `Ave Verum Corpus` 只有 0.29 ⇒ 分得很开。
    🔴 为什么用「滑窗」而不是逐词：OCR 会把两行连成一段、也会把小字标签
       （HERO-SKILL）塞在前面，逐词比对会被这些无关 token 稀释。
    """
    exp = _norm(" ".join(expected or []))
    if not exp:
        return 1.0, "没有译名可比"
    got = _norm(read or "")
    if not got:
        return 0.0, "OCR 一个字都没读出来"
    if len(got) < len(exp):
        s = SequenceMatcher(None, exp, got).ratio()
    else:
        s = max(SequenceMatcher(None, exp, got[i:i + len(exp)]).ratio()
                for i in range(len(got) - len(exp) + 1))
    return round(float(s), 3), f"期望 `{exp}` / OCR `{got}`"
