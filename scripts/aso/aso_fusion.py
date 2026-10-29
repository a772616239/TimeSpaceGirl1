#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""拼装式店面图（Play featureGraphic）：重绘双人底图 + 实机画面框 + 本地压字。

为什么是「拼装」而不是让 AI 画整张
------------------------------------
让 AI 直接画「角色 + 游戏画面 + 标题」的整张店面图，三件事都会失控：角色会漂移、
游戏画面是编的（一眼假）、中/日/繁的字形必错。所以把三件事拆开，各自用最可靠的手段：

| 层 | 来源 | 为什么 |
|---|---|---|
| 左右角色 | `hero_keyart.py duo` → TS-Art-Restyle 按**特征卡**重绘 | 不拿立绘当参考图，画风/光源才能和背景统一 |
| 中间画面 | 真实机截图（`shots.json`，按 `band` 取战斗横条） | 「这是真游戏」的可信度只能靠真图 |
| 文字 | 本地真字体渲染 | 模型画中/日/繁必错；改文案不该重出图 |

🔴 **不能拿工程里的现成立绘直接贴**（`Assets/.../Jingtailihui/`，1024~2048 自带 alpha）。
2026-10-23 试过，用户当场否决：立绘和背景不同光源、不同画风，贴上去一眼剪贴画。
立绘只用来**抽特征**（`hero_features.py` → `hero_specs.json`），不参与成像。
代码里保留的 `heroes` 分支只是没有底图时的本地预览兜底，`--promote` 时会直接拒绝。

关键取巧点（整个方案成立的原因）
--------------------------------
双人底图的中段 60% 是被**要求留空**的，这块随后被实机画面框整块盖住 ⇒
「角色由管线重绘」与「中间是真游戏画面」同时成立，而**不需要抠图** ——
管线只出整幅不透明图，chroma key 抠不干净，这条路绕开了它。

层次（从下到上）
----------------
1. 底图 —— `hero_keyart.py duo` 出的 1920×1080（角色被左右边缘裁切、中段与底部留空）。
   没底图时才退到程序化氛围底 + 立绘。
2. 画面框 —— 圆角 + 双描边 + 外发光，框内铺实机截图（cover 裁切 + 屏内暗角 + 暖/冷调统一）。
3. 标题带 —— 底部黑渐变 scrim + 字距拉开的小标 + 带描边/发光/渐变的大标题。

🔴 红线：文字一律本地真字体压。模型画中文/日文字形必错，而且改文案不该重出图。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aso_common as C  # noqa: E402

FUSION_SPEC = C.ASSETS_DIR / "fusion.json"
LIHUI_DIR = C.ROOT / "Assets" / "ManagedResources" / "Texture" / "Jingtailihui"
LIHUI_TPL = "cn2-Jingtailihui_{}.png"

SS = 2          # 超采样倍数：1024×500 内部按 2048×1000 画，描边/羽化才够细

FONT_FACE = {
    "en-US": ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
    "ja-JP": ("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", 0),
    "zh-CN": ("/System/Library/Fonts/STHeiti Medium.ttc", 1),   # Heiti SC
    "zh-TW": ("/System/Library/Fonts/STHeiti Medium.ttc", 0),   # Heiti TC
}

_cache: dict[tuple, object] = {}


def font_for(locale: str, size: int):
    key = ("font", locale, size)
    if key not in _cache:
        face = FONT_FACE.get(locale) or (None, 0)
        f = None
        if face[0] and Path(face[0]).is_file():
            try:
                f = ImageFont.truetype(face[0], size, index=face[1])
            except Exception:  # noqa: BLE001
                f = None
        if f is None:
            for p in C.LOCALES[locale]["fonts"]:
                if Path(p).is_file():
                    try:
                        f = ImageFont.truetype(p, size)
                        break
                    except Exception:  # noqa: BLE001
                        continue
        _cache[key] = f or ImageFont.load_default()
    return _cache[key]


# ---------------------------------------------------------------- 素材

def load_lihui(name: str) -> Image.Image:
    """读立绘并按 alpha 收紧。画布里角色只占中间一块，不收会白占空白。"""
    key = ("lihui", name)
    if key not in _cache:
        p = LIHUI_DIR / LIHUI_TPL.format(name)
        if not p.is_file():
            raise SystemExit(f"找不到立绘：{p}")
        im = Image.open(p).convert("RGBA")
        bb = im.getchannel("A").getbbox()
        _cache[key] = im.crop(bb) if bb else im
    return _cache[key]


def _shot_image(idx: int, band: tuple[float, float] | None = None) -> Image.Image:
    """实机截图：按 shots.json 的 crop_bottom 切掉按钮行与世界聊天。

    商店页上挂着中文世界聊天是最掉价的粗糙感，所以框内只留战斗画面。

    `band` 再在剩下的图里取一段纵向区间（y0~y1，比例）当「战斗特写」：
    竖版截图整幅塞进横框只会被缩成一条没人看得清的小图，直接取战斗区横条
    再放大铺满，框里才有「画面」而不是「缩略图」。
    """
    key = ("shot", idx, band)
    if key not in _cache:
        spec = C.load_json(C.ASSETS_DIR / "shots.json")
        shots = spec.get("shots") or []
        item = shots[idx % len(shots)]
        src = C.ROOT / item["src"]
        im = Image.open(src).convert("RGB")
        top = int(im.height * float(item.get("crop_top") or 0))
        bot = int(im.height * (1.0 - float(item.get("crop_bottom") or 0)))
        im = im.crop((0, top, im.width, max(top + 8, bot)))
        if band:
            h = im.height
            im = im.crop((0, int(h * band[0]), im.width, max(int(h * band[0]) + 8,
                                                            int(h * band[1]))))
        _cache[key] = im
    return _cache[key]


def _hex(s: str) -> tuple[int, int, int]:
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


# ---------------------------------------------------------------- 底层氛围

def _backdrop(size: tuple[int, int], tint: tuple, glow: tuple,
              atmo: Image.Image | None = None) -> Image.Image:
    """氛围底：有 atmo 图就用它虚化压暗当底，没有才退化成纯程序化渐变。

    🔴 纯程序化渐变做出来的底一定是「一块纯色」，角色贴上去永远像剪贴画。
    真实作业法是拿**同一张实机截图**放大模糊 + 压暗当背景：色温、光源方向、
    饱和度都和框内画面同源，画面才像「一张图」而不是「一张图贴在另一张上」。
    """
    W, H = size
    ys = np.linspace(0.0, 1.0, H, dtype=np.float32)[:, None]
    xs = np.linspace(0.0, 1.0, W, dtype=np.float32)[None, :]

    if atmo is not None:
        blur_r = max(8, int(W * 0.009))
        base = _cover(atmo.convert("RGB"), (W, H), 0.34)
        base = base.filter(ImageFilter.GaussianBlur(blur_r))
        # 双色调（duotone）：虚化后的截图本身是灰蓝色，直接压暗只会得到「一块脏灰」，
        # 和暖色角色完全不在一个色温里。把亮度重映射到「深紫黑 → 暗红」两色之间，
        # 背景就一定是暖的、暗的，也只保留大块明暗关系（细节被模糊掉了，正好当氛围）。
        rgb = np.asarray(base, np.float32) / 255.0
        lum = (rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114)[..., None]
        lum = np.clip(lum ** 1.15, 0.0, 1.0)
        # 暗端紫黑、亮端霓虹紫蓝：游戏本身就是 neon cyberpunk，冷底 + 暖角色才有对比。
        # （早期试过暗红底：框内战术网格是青绿色，和暗红底直接打架，整张图发土。）
        dark_c = np.array([8, 6, 18], np.float32)
        light_c = np.array([58, 30, 96], np.float32) + np.array(tint, np.float32) * 0.06
        img = dark_c + (light_c - dark_c) * lum
        img *= (1.0 - 0.22 * (ys[..., None] ** 1.4))
    else:
        top = np.array([18, 14, 30], np.float32)
        mid = np.array([10, 9, 18], np.float32)
        bot = np.array([6, 5, 10], np.float32)
        t = ys[..., None]
        img = np.where(t < 0.55,
                       top + (mid - top) * (t / 0.55),
                       mid + (bot - mid) * ((t - 0.55) / 0.45))

    # 中央偏上的大光池。🔴 颜色别用角色的 rim 高光色（粉白）：大面积加高亮色
    # 会把整块暗红底洗成脏灰，实测就是这么灰的。用「暖光色 × 低强度」只提一点空气感。
    d2 = ((xs - 0.5) / 0.62) ** 2 + ((ys - 0.42) / 0.75) ** 2
    wc = np.array(glow, np.float32) * 0.80 + np.array(tint, np.float32) * 0.20
    pool = np.exp(-d2 * 1.9)[..., None] * (wc * 0.30)
    img = img + pool

    # 斜向光带：三条不同相位/宽度的，营造体积感而不是脏
    beams = np.zeros((H, W), dtype=np.float32)
    for k, (off, wid, amp) in enumerate(((0.06, 0.055, 1.0), (0.30, 0.030, 0.55),
                                         (-0.22, 0.038, 0.40))):
        u = xs * 0.42 + ys * 0.58 - 0.62 + off
        beams += (np.exp(-(u ** 2) / (2 * wid ** 2)) * amp).astype(np.float32)
    beams = np.repeat(beams[..., None], 3, axis=2) * (np.array(glow, np.float32) * 0.16)

    img = img + beams

    # 噪点：极低幅度，只为了不出现 8bit 色带
    rng = np.random.default_rng(7)
    img = img + rng.normal(0.0, 2.2, (H, W, 1)).astype(np.float32)

    # 暗角
    d3 = ((xs - 0.5) / 0.62) ** 2 + ((ys - 0.5) / 0.72) ** 2
    vig = 1.0 - np.clip(d3 * 0.52, 0.0, 0.66)
    img = img * vig[..., None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")


def _radial(size: tuple[int, int], center: tuple[float, float], radius: float,
            color: tuple, alpha: int) -> Image.Image:
    """低分辨率画圆再放大模糊：全尺寸高斯在这个尺寸上慢到不可用。"""
    W, H = size
    sw, sh = max(4, W // 6), max(4, H // 6)
    g = Image.new("L", (sw, sh), 0)
    cx, cy, r = center[0] / 6, center[1] / 6, max(2.0, radius / 6)
    ImageDraw.Draw(g).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    g = g.filter(ImageFilter.GaussianBlur(max(3, r * 0.55))).resize((W, H), Image.BICUBIC)
    layer = Image.new("RGBA", (W, H), tuple(color) + (alpha,))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.paste(layer, (0, 0), g)
    return out


# ---------------------------------------------------------------- 画面框

def _rounded(box: tuple[int, int, int, int], radius: int, size: tuple[int, int]) -> Image.Image:
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=radius, fill=255)
    return m


def _cover(im: Image.Image, size: tuple[int, int], focus_y: float = 0.5,
           focus_x: float = 0.5, zoom: float = 1.0) -> Image.Image:
    """铺满裁切。focus_x/focus_y 决定取景重心，zoom>1 再往里推一档。

    zoom 是为了让「同一张实机截图」在不同组里给出不同景别（全景 / 中景 / 特写）：
    干净的合规真机截图只有 3 张，10 组要不撞画面只能靠景别和重心拉开差异。
    """
    tw, th = size
    k = max(tw / im.width, th / im.height) * max(1.0, float(zoom))
    nw, nh = max(tw, int(round(im.width * k))), max(th, int(round(im.height * k)))
    im = im.resize((nw, nh), Image.LANCZOS)
    x = int(round((nw - tw) * min(1.0, max(0.0, focus_x))))
    y = int(round((nh - th) * min(1.0, max(0.0, focus_y))))
    y = max(0, min(y, nh - th))
    x = max(0, min(x, nw - tw))
    return im.crop((x, y, x + tw, y + th))


def draw_screen(canvas: Image.Image, box: tuple[int, int, int, int], shot_idx: int,
                radius: int, glow: tuple, focus_y: float = 0.42,
                band: tuple[float, float] | None = None,
                focus_x: float = 0.5, zoom: float = 1.0,
                screen_warm: tuple[float, float, float] | None = None,
                screen_contrast: float = 1.08,
                shot_img: Image.Image | None = None) -> Image.Image:
    """框内实机画面：cover 裁切 + 屏内暗角 + 顶部一条高光（玻璃感）+ 双层描边。

    顺序很关键：**先贴画面再画描边**，否则描边会被画面盖掉一半；
    外发光要在画面之下，否则会糊住画面内容。

    `shot_img` 给定时直接用这张图当框内画面（跳过 `shots.json` 的取景），
    16:9 商店截图路线要靠它自己控制「只留战斗区」的裁切。
    """
    W, H = canvas.size
    x0, y0, x1, y1 = box
    mask = _rounded(box, radius, (W, H))

    # 外发光（画在画面之下）
    halo = mask.filter(ImageFilter.GaussianBlur(max(6, int(W * 0.010))))
    layer = Image.new("RGBA", (W, H), tuple(glow) + (110,))
    canvas.paste(layer, (0, 0), halo.point(lambda v: int(v * 0.46)))

    src = shot_img if shot_img is not None else _shot_image(shot_idx, band)
    shot = _cover(src, (x1 - x0, y1 - y0), focus_y,
                  focus_x, zoom).convert("RGBA")

    # 放大兜底锐化：16:9 路线（1920×1080）下画面框比真机截图还大，Lanczos 放大后
    # UI 边缘会「糊一层」，商店页放大看就是廉价感。只在**真的放大过**时补一次
    # UnsharpMask；1024×520 那条老路线是缩小，ratio < 1 不触发，产物一个字节不变。
    up = (x1 - x0) / max(1, src.width)
    if up > 1.05:
        shot = shot.convert("RGB").filter(
            ImageFilter.UnsharpMask(radius=1.4, percent=68, threshold=2)).convert("RGBA")

    # 屏内暗角：四角压深，中间提亮，让画面「陷」进框里
    sw, sh = shot.size
    sx = np.linspace(-1, 1, sw, dtype=np.float32)[None, :]
    sy = np.linspace(-1, 1, sh, dtype=np.float32)[:, None]
    vig = 1.0 - np.clip((sx ** 2 * 0.34 + sy ** 2 * 0.46), 0, 1) ** 1.35 * 0.62
    arr = np.asarray(shot.convert("RGB"), np.float32) * vig[..., None]
    # 框内外色温必须一致：截图是蓝冷调，直接放进暖色背景里会像「另一张图贴上去」。
    # 乘一个暖增益 + 提对比，画面立刻落进同一个色系。
    # ⚠️ 暖增益只对「本身偏蓝」的截图成立（老 3 张都是青蓝工厂/红 BOSS）。雪地/城市这种
    # 中性偏冷的画面再乘暖增益会整片发红（2026-10-23 用户给的冬季城市关踩到）⇒ 用
    # screen.warm 逐张给，缺省才用它。
    warm = np.array(screen_warm or (1.04, 0.99, 0.94), np.float32)
    arr = arr * warm
    arr = (arr - 118.0) * float(screen_contrast) + 118.0
    shot = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

    # 顶部玻璃高光：一条极淡的横向亮带，模拟屏幕反光
    gl = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    gd = ImageDraw.Draw(gl)
    gd.rectangle([0, 0, sw, max(2, int(sh * 0.16))], fill=(255, 255, 255, 30))
    shot.alpha_composite(gl.filter(ImageFilter.GaussianBlur(max(2, sh * 0.02))))

    canvas.paste(shot, (x0, y0), _rounded((0, 0, sw, sh), radius, (sw, sh)))

    # 描边：外圈 3px 亮线 + 内圈 1px 暗线（内暗线负责把边框和画面「掰开」）
    d = ImageDraw.Draw(canvas)
    lw = max(2, int(W * 0.0022))
    d.rounded_rectangle(box, radius=radius, outline=tuple(glow) + (238,), width=lw)
    d.rounded_rectangle([box[0] + lw, box[1] + lw, box[2] - lw, box[3] - lw],
                        radius=max(2, radius - lw), outline=(8, 6, 14, 190), width=1)

    # 四角角标：小三角，装饰性但成本极低，比整圈花边干净
    s = int(W * 0.016)
    for cx, cy, sx_, sy_ in ((box[0], box[1], 1, 1), (box[2], box[1], -1, 1),
                             (box[0], box[3], 1, -1), (box[2], box[3], -1, -1)):
        d.polygon([(cx, cy), (cx + sx_ * s, cy), (cx, cy + sy_ * s)],
                  fill=tuple(glow) + (215,))
    return canvas


# ---------------------------------------------------------------- 立绘

def _rim(alpha: Image.Image, color: tuple, width: int = 2) -> Image.Image:
    """轮廓光：alpha 与其腐蚀版的差集，就是内侧 1~2px 的边。

    比「往外描一圈」自然：外描边会让角色边缘变粗发脏，内发光才像被背景灯打着。
    """
    er = alpha.filter(ImageFilter.MinFilter(width * 2 + 1))
    edge = ImageChops.subtract(alpha, er)
    edge = edge.filter(ImageFilter.GaussianBlur(0.6))
    layer = Image.new("RGBA", alpha.size, tuple(color) + (255,))
    out = Image.new("RGBA", alpha.size, (0, 0, 0, 0))
    out.paste(layer, (0, 0), edge.point(lambda v: int(v * 0.85)))
    return out


def place_hero(canvas: Image.Image, name: str, side: str, x: float, h: float,
               base: float, dim: float = 0.0, rim: tuple | None = None,
               accent: tuple = (255, 90, 120), feather: float = 0.14) -> Image.Image:
    """把立绘摆进画布。

    side/x 决定**内侧边缘**落点：right 是右缘、left 是左缘，x 是画布比例。
    角色宽度由 h（相对画布高）和立绘自身宽高比决定，所以「角色会伸到哪」是结果不是输入
    —— 想控制占宽就换 h，或换一张更瘦的立绘（见 layout 注释）。

    base > 1 表示腿伸出画布，露出来的自然就是上半身，不用去猜腰在哪。
    """
    W, H = canvas.size
    art = load_lihui(name)
    th = max(1, int(round(h * H)))
    tw = max(1, int(round(art.width * th / art.height)))
    art = art.resize((tw, th), Image.LANCZOS)

    ax = int(round(x * W))
    px = ax if side == "right" else ax - tw     # x 是**内侧边缘**：right 取左缘、left 取右缘
    py = int(round(base * H)) - th

    # 底部羽化：角色脚部淡出，不会在画布边缘留一条硬切
    if feather > 0:
        a = art.getchannel("A")
        fh = max(2, int(th * feather))
        col = Image.new("L", (1, th), 255)
        cp = col.load()
        for i in range(fh):
            cp[0, th - 1 - i] = int(255 * (i / fh) ** 0.75)
        art.putalpha(ImageChops.multiply(a, col.resize((tw, th), Image.BILINEAR)))

    # 背光由 build() 统一在**画面框之下**打，这里不再重复 —— 否则角色身上会叠两层光过曝
    if rim is not None:
        art.alpha_composite(_rim(art.getchannel("A"), rim, max(2, int(W * 0.0018))))

    if dim > 0:
        dark = Image.new("RGBA", art.size, (8, 6, 14, int(255 * dim)))
        art.alpha_composite(Image.composite(dark, Image.new("RGBA", art.size, (0, 0, 0, 0)),
                                            art.getchannel("A")))

    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.alpha_composite(art, (px, py))
    canvas.alpha_composite(layer)
    return canvas


# ---------------------------------------------------------------- 标题

def _vgrad(size: tuple[int, int], y0: float, y1: float, invert: bool = False,
           gamma: float = 1.0) -> Image.Image:
    W, H = size
    col = Image.new("L", (1, H))
    px = col.load()
    span = max(1e-6, y1 - y0)
    for y in range(H):
        t = (y / max(1, H - 1) - y0) / span
        t = 0.0 if t < 0 else (1.0 if t > 1 else t)
        v = int(round((t ** gamma) * 255))
        px[0, y] = 255 - v if invert else v
    return col.resize((W, H), Image.BILINEAR)


def _text_mask(size: tuple[int, int], xy: tuple[int, int], text: str, font,
               stroke: int = 0) -> Image.Image:
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).text(xy, text, font=font, fill=255,
                           stroke_width=stroke, stroke_fill=255)
    return m


def _tracked_w(d, text: str, font, tracking: float) -> float:
    return sum(d.textlength(ch, font=font) for ch in text) + tracking * max(0, len(text) - 1)


def draw_caption(canvas: Image.Image, kicker: str, title: str, locale: str,
                 bar: float, kicker_y: float, title_y: float, accent: tuple,
                 title_ratio: float = 0.118, max_w_ratio: float = 0.88) -> None:
    """底部标题带：黑渐变 scrim → 字距小标 → 带描边/发光/纵向渐变的大标题。

    参考图那种「小标在上、大字在下」的双层结构最好用：
    小标负责说清是什么（品类/规模），大字负责给一个记得住的动作。

    `bar` 传 >1 表示**不要 scrim**（只压字）——16:9 商店截图路线把标题放到画面顶部，
    底下是角色与背景的实拍细节，再铺一层黑渐变就又变成 Play 明令禁止的
    「solid colors and gradients」了。
    `title_ratio` 是标题字号占画布高的比例，顶部标题要留出角色头部，比底部标题小一号。
    """
    W, H = canvas.size
    d = ImageDraw.Draw(canvas)

    # scrim：从 bar 位置渐入全黑，gamma 让过渡集中在下半段，上缘不显脏
    if bar <= 1.0:
        scrim = Image.new("RGBA", (W, H), (4, 3, 8, 255))
        canvas.alpha_composite(Image.composite(
            scrim, Image.new("RGBA", (W, H), (0, 0, 0, 0)), _vgrad((W, H), bar * 0.94, 1.0, gamma=1.55)))

    # ---- kicker：字距拉开的细标
    if kicker:
        ks = int(H * 0.052)
        kf = font_for(locale, ks)
        tr = ks * 0.16
        kw = _tracked_w(d, kicker, kf, tr)
        x = (W - kw) / 2
        y = int(H * kicker_y)
        for ch in kicker:
            d.text((x, y), ch, font=kf, fill=(240, 243, 250, 255),
                   stroke_width=max(1, int(ks * 0.10)), stroke_fill=(0, 0, 0, 170))
            x += d.textlength(ch, font=kf) + tr

    # ---- 主标题：先缩到能放进 88% 宽
    if not title:
        return
    ty = int(H * title_y)
    size = int(H * title_ratio)
    floor = int(H * title_ratio * 0.52)
    max_w = W * max_w_ratio
    while size > floor:
        f = font_for(locale, size)
        if d.textlength(title, font=f) <= max_w:
            break
        size -= 2
    f = font_for(locale, size)
    tw = d.textlength(title, font=f)
    tx = (W - tw) / 2
    asc, desc = f.getmetrics()
    stroke = max(2, int(size * 0.070))

    mask = _text_mask((W, H), (int(tx), ty), title, f, stroke)

    # 外发光（accent）+ 硬投影（黑，偏移 2~3px），两者都在字面之下
    halo = mask.filter(ImageFilter.GaussianBlur(max(3, size * 0.16)))
    hl = Image.new("RGBA", (W, H), tuple(accent) + (255,))
    canvas.alpha_composite(Image.composite(hl, Image.new("RGBA", (W, H), (0, 0, 0, 0)),
                                           halo.point(lambda v: int(v * 0.55))))
    sh = mask.filter(ImageFilter.GaussianBlur(max(1, size * 0.030)))
    sl = Image.new("RGBA", (W, H), (0, 0, 0, 235))
    canvas.alpha_composite(Image.composite(sl, Image.new("RGBA", (W, H), (0, 0, 0, 0)), sh),
                           (0, max(2, int(size * 0.045))))

    # 字面：上白下浅灰的纵向渐变 + 黑色描边（描边先铺，字面后压）
    ys = np.linspace(0.0, 1.0, H, dtype=np.float32)[:, None, None]
    ramp = np.array([255, 255, 255], np.float32) + (
        np.array([184, 188, 204], np.float32) - np.array([255, 255, 255], np.float32)) * ys
    rgba = np.concatenate([np.repeat(ramp, W, axis=1),
                           np.full((H, W, 1), 255.0, np.float32)], axis=2)
    body = Image.fromarray(rgba.astype(np.uint8), "RGBA")
    canvas.alpha_composite(Image.composite(Image.new("RGBA", (W, H), (10, 8, 16, 255)),
                                           Image.new("RGBA", (W, H), (0, 0, 0, 0)),
                                           _text_mask((W, H), (int(tx), ty), title, f, stroke)))
    canvas.alpha_composite(Image.composite(body, Image.new("RGBA", (W, H), (0, 0, 0, 0)),
                                           _text_mask((W, H), (int(tx), ty), title, f, 0)))


# ---------------------------------------------------------------- 组装

def _category_copy(grp: dict) -> dict:
    """按 pair 的 category 从 fusion_copy.json 取四语文案。

    返回 {locale: {"kicker":..., "title":...}}；没有 category 或文件缺失时返回 {}，
    build 会回落到 fusion.json 的 copy —— 老的候选目录不受影响。
    """
    cat = grp.get("category")
    if not cat:
        return {}
    p = C.ASSETS_DIR / "fusion_copy.json"
    if not p.is_file():
        return {}
    block = (C.load_json(p).get("categories") or {}).get(cat) or {}
    return {k: v for k, v in block.items()
            if not k.startswith("_") and isinstance(v, dict)}


def build(layout_key: str, locale: str, size: tuple[int, int],
          overrides: dict | None = None,
          require_bg: bool = False,
          copy_override: dict | None = None) -> Image.Image:
    """出一张拼装店面图。

    require_bg=True 时，缺「管线重绘的双人底图」直接报错，**不允许退回立绘拼贴**。
    立绘拼贴只是本地预览兜底：现成立绘和背景不同光源/不同画风，贴上去一眼剪贴画，
    早被用户否决过。上线路径必须是 AI 按特征卡重画的底图。
    """
    spec = C.load_json(FUSION_SPEC)
    lay = dict(spec["layouts"][layout_key])
    if overrides:
        for k, v in overrides.items():
            if v is None:
                continue
            if k == "screen" and isinstance(v, dict):
                # 逐字段合并：每组只覆盖「取哪张截图、取哪一段、景别多重」，
                # 描边色 / 圆角 / 氛围底仍沿用版面默认，免得 10 组各写一遍。
                lay["screen"] = {**(lay.get("screen") or {}), **v}
            else:
                lay[k] = v
    copy = (spec.get("copy") or {}).get(locale) or {}
    if copy_override:
        # 文案要跟画面走：战斗/主城/公会/地图各一套（见 fusion_copy.json），
        # 全组死用一句「召唤·布阵·碾压」会文不对图。
        copy = {**copy, **{k: v for k, v in copy_override.items() if v}}
    title = copy.get("title") or ""
    kicker = copy.get("kicker") or ""
    if locale.startswith("en"):
        title, kicker = title.upper(), kicker.upper()

    W, H = size
    big = (W * SS, H * SS)

    screen = lay.get("screen") or {}
    glow = _hex(screen.get("glow") or "#FF5A3C")
    heroes = lay.get("heroes") or []
    tint = _hex((heroes[0].get("rim") if heroes else None) or "#FF5A3C")

    atmo = None
    if screen.get("atmo"):
        ap = C.ROOT / screen["atmo"]
        if ap.is_file():
            atmo = Image.open(ap).convert("RGB")
    if atmo is None:
        atmo = _shot_image(int(screen.get("shot") or 0))
    canvas = _backdrop(big, tint, glow, atmo=atmo)

    # 底图分支：有「管线按特征卡重绘的双人横版底图」就直接铺满，不再贴工程立绘。
    # 这是首选路径 —— 角色是重绘的、和背景同光源同画风，不会有剪贴感。
    bg_path = lay.get("bg")
    if bg_path and (C.ROOT / bg_path).is_file():
        canvas = _cover(Image.open(C.ROOT / bg_path).convert("RGB"), big, 0.5).convert("RGBA")
        heroes = []                     # 底图里已经有角色，别再叠立绘
    elif require_bg:
        raise SystemExit(
            f"🔴 缺双人底图 {bg_path or '(fusion.json 没写 bg)'}\n"
            f"   先跑：scripts/aso/hero_keyart.py duo --pair <左,右> --wait\n"
            f"   --promote 只认管线按特征卡重绘的底图；工程立绘拼贴不得上商店页。")

    # 角色背光先垫在最底下（角色自己要盖在框之上，但光要透到框边外）
    for h in heroes:
        if h.get("dim", 0) >= 0.5:
            continue
        art = load_lihui(h["art"])
        th_ = max(1, int(round(h["h"] * big[1])))
        tw_ = max(1, int(round(art.width * th_ / art.height)))
        ax = int(round(h["x"] * big[0]))
        cx = ax + tw_ * 0.5 if h["side"] == "right" else ax - tw_ * 0.5
        # 🔴 背光统一用画面框的描边色。角色 rim 是各自的局部高光色（淡青/淡粉/橙），
        # 拿它铺大面积会把底洗成灰；两三种互相冲突的暖光叠在一起更是直接变土褐。
        bgl = glow
        canvas.alpha_composite(_radial(big, (cx, h["base"] * big[1] - th_ * 0.55),
                                       tw_ * 0.95, bgl, 52))

    frame = [int(round(v * (W if i % 2 == 0 else H) * SS)) for i, v in enumerate(lay["frame"])]
    canvas = draw_screen(canvas, tuple(frame), int(screen.get("shot") or 0),
                         int(round(screen.get("radius", 0.01) * W * SS)), glow,
                         float(screen.get("focus", 0.42)),
                         tuple(screen["band"]) if screen.get("band") else None,
                         float(screen.get("focus_x", 0.5)),
                         float(screen.get("zoom", 1.0)),
                         tuple(screen["warm"]) if screen.get("warm") else None,
                         float(screen.get("contrast", 1.08)))

    # 立绘：远的（dim 大）先画，近的后画 ⇒ 有前后景的叠压关系
    for h in sorted(heroes, key=lambda o: -o.get("dim", 0)):
        place_hero(canvas, h["art"], h["side"], h["x"], h["h"], h["base"],
                   dim=h.get("dim", 0.0), rim=_hex(h["rim"]) if h.get("rim") else None,
                   accent=_hex(h["rim"]) if h.get("rim") else glow)

    t = lay["title"]
    draw_caption(canvas, kicker, title, locale, t["bar"], t["kicker_y"], t["title_y"], glow)

    return canvas.convert("RGB").resize((W, H), Image.LANCZOS)


def _patch_index(variant: str, promoted: dict[str, Path]) -> None:
    """把 promote 后的 feature_01.png 真实 size/bytes/sha1 写回 index.json。

    不刷这一步的话，验收页上显示的仍然是 aso_assets build 当时那张图的字节数与哈希 ——
    图换了、数字没换，看起来像「拼装没生效」。
    """
    idx_p = C.DERIVED_DIR / variant / "index.json"
    if not idx_p.is_file():
        return
    idx = C.load_json(idx_p)
    for loc, path in promoted.items():
        ents = (idx.get("locales") or {}).get(loc)
        if not isinstance(ents, list):
            continue
        ent = next((e for e in ents if str(e.get("file", "")).startswith("feature_")), None)
        if ent is None:
            ent = {"file": path.name, "caption": ""}
            ents.append(ent)
        ent["file"] = path.name
        ent["src"] = f"data_aso/assets/gen/fusion/bg (拼装 · {variant}/{loc})"
        ent["size"] = list(Image.open(path).size)
        ent["upscale"] = 1.0
        ent["bytes"] = path.stat().st_size
        ent["sha1"] = hashlib.sha1(path.read_bytes()).hexdigest()
    idx_p.write_text(json.dumps(idx, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description="拼装式店面图")
    ap.add_argument("action", choices=["build", "list"])
    ap.add_argument("--layout", default="duo")
    ap.add_argument("--locales", default="en-US")
    ap.add_argument("--size", default="1024x500")
    ap.add_argument("--variant", default="B")
    ap.add_argument("--out", default="")
    ap.add_argument("--tag", default="")
    ap.add_argument("--bg", default="",
                    help="覆盖 fusion.json 里的底图路径。批量出多组角色组合时用："
                         "每组一张 bg_<tag>.png，不必反复改配置。")
    ap.add_argument("--pair", default="",
                    help="从 fusion_pairs.json 取该组（tag）的底图、框内取景与文案分类，"
                         "一次出齐四语。10 组的差异就靠这里的 shot/band/zoom 拉开。")
    ap.add_argument("--pairs", default="",
                    help="批量出图：逗号分隔的 tag（0102,2019,...）、all、或 shots。"
                         "all = 所有未标 _retired 的组；shots = fusion_shots.py 的 DEFAULT_ORDER"
                         "（= 手机截图真要用的那几张，单一真源，不会和商店页顺序脱节）。"
                         "循环收在脚本里，Jenkins 不用再写 shell for，日志也能一次看全。")
    ap.add_argument("--by-locale", action="store_true",
                    help="按语言分子目录：<out>/<locale>/feature_duo_<tag>.png。"
                         "交图/上传时不会拿错语言；不加则平铺成 feature_duo_<locale>_<tag>.png。")
    ap.add_argument("--promote", action="store_true",
                    help="写进 derived/<变体>/<语言>/feature_01.png（= aso_assets build 用的同一个文件名）。"
                         "这样 preview.html / index.json / aso_play.py push 都不用改，也不会出现两张置顶图。"
                         "开启时缺管线底图直接报错，不退回立绘拼贴。")
    a = ap.parse_args()

    spec = C.load_json(FUSION_SPEC)
    if a.action == "list":
        for k, v in spec["layouts"].items():
            print(f"{k}: {v.get('_note', '')[:60]}")
            for h in v.get("heroes", []):
                print(f"   {h['side']:5s} {h['art']:14s} x={h['x']:.3f} h={h['h']:.2f}")
        return 0

    tw, th = (int(x) for x in a.size.lower().split("x"))
    if a.promote and (tw, th) != (1024, 500):
        print(f"🔴 --promote 只接受 1024x500（Play 对 featureGraphic 是死规定），当前 {tw}x{th}")
        return 2

    # ── 要出几组 ────────────────────────────────────────────────────────────
    # --pairs 批量 / --pair 单组 / 都不给就按 fusion.json 的默认角色组合出一张。
    # 循环放在脚本里而不是 Jenkins 的 shell for：出图一组 90~126s，shell 循环里
    # 任何一组失败都难定位，而且日志被拆成 N 段、看不出「这批到底出了几张」。
    spec_p = C.ASSETS_DIR / "fusion_pairs.json"
    pairs_all: list[dict] = []
    if spec_p.is_file():
        pairs_all = C.load_json(spec_p).get("pairs") or []

    tags: list[str] = []
    if a.pairs:
        want = a.pairs.strip()
        if want.lower() in ("shots", "shot"):
            # 与手机截图共用一个真源：fusion_shots.py 的 DEFAULT_ORDER 就是上线顺序。
            # 两边各写一份清单迟早会脱节（出了 8 组、商店页只用 6 组，剩下 2 组白烧额度）。
            try:
                import fusion_shots as FS
                tags = list(FS.DEFAULT_ORDER)
            except Exception as e:  # noqa: BLE001
                print(f"🔴 --pairs shots 需要 fusion_shots.py 可导入：{e}")
                return 2
        elif want.lower() in ("all", "*"):
            tags = [str(p["tag"]) for p in pairs_all if not p.get("_retired")]
        else:
            tags = [t.strip() for t in want.split(",") if t.strip()]
    elif a.pair:
        tags = [a.pair]

    if a.promote and len(tags) > 1:
        print(f"🔴 --promote 一次只能写一组（featureGraphic 每语言只允许一张），"
              f"当前要出 {len(tags)} 组：{','.join(tags)}")
        print("   批量出图请去掉 --promote，产物落在 "
              "<out>/<locale>/feature_<layout>_<tag>.png，再挑一张单独 --promote。")
        return 2
    if a.tag and len(tags) > 1:
        print(f"🔴 --tag 是单组的文件名后缀，和 --pairs 批量出图冲突（{len(tags)} 组会互相覆盖）")
        return 2

    grp_by_tag = {str(p["tag"]): p for p in pairs_all}
    if tags:
        missing = [t for t in tags if t not in grp_by_tag]
        if missing:
            print(f"🔴 fusion_pairs.json 里没有 tag={','.join(missing)}；"
                  f"现有：{','.join(sorted(grp_by_tag))}")
            return 2
        retired = [t for t in tags if grp_by_tag[t].get("_retired")]
        if retired:
            print(f"⚠️  {','.join(retired)} 标了 _retired（画面素材不合格，不上手机截图）。"
                  f"仍按请求出图；置顶图可用，手机截图请确认 fusion_shots.py 的 order 里没有它。")

    root = Path(a.out) if a.out else (C.DERIVED_DIR / a.variant / "fusion")
    root.mkdir(parents=True, exist_ok=True)

    promoted: dict[str, Path] = {}
    for gi, tag in enumerate(tags or [""], 1):
        ov: dict = {}
        cat_copy: dict = {}
        if a.bg:
            ov["bg"] = a.bg
        if tag:
            grp = grp_by_tag[tag]
            ov["bg"] = f"data_aso/assets/gen/fusion/bg_{tag}.png"
            if grp.get("screen"):
                ov["screen"] = grp["screen"]
            # 文案：pair 自己写 copy > category 指向 fusion_copy.json > fusion.json 的默认四语
            cat_copy = _category_copy(grp)
            if grp.get("copy"):
                cat_copy = {**cat_copy, **grp["copy"]}
        use_tag = a.tag or tag
        if len(tags) > 1:
            g = grp_by_tag[tag]
            shot_no = (g.get("screen") or {}).get("shot")
            head = f"\n[{gi}/{len(tags)}] tag={tag}"
            if shot_no is not None:
                head += f"  shot#{shot_no}"
            note = (g.get("note") or "").strip()
            if note:
                head += f"  {note[:44]}"
            print(head)
        sfx = f"_{use_tag}" if use_tag else ""
        for loc in C.parse_locales(a.locales):
            cov = cat_copy.get(loc) if cat_copy else None
            im = build(a.layout, loc, (tw, th), overrides=ov or None,
                       require_bg=a.promote or bool(ov.get("bg")), copy_override=cov)
            if a.by_locale:
                # 目录即语言：<out>/<locale>/feature_duo_<tag>.png。
                # 和 aso_assets build 的 derived/<变体>/<locale>/feature_01.png 同构，
                # 交图/上传时不会拿错语言。
                p = root / loc / f"feature_{a.layout}{sfx}.png"
                p.parent.mkdir(parents=True, exist_ok=True)
            else:
                p = root / f"feature_{a.layout}_{loc}{sfx}.png"
            im.save(p, optimize=True)
            try:
                shown = p.relative_to(C.ROOT)
            except ValueError:
                shown = p
            print(f"{shown}  {im.size[0]}x{im.size[1]}  {p.stat().st_size / 1024:.0f} KB")
            if a.promote:
                dest = C.DERIVED_DIR / a.variant / loc / "feature_01.png"
                dest.parent.mkdir(parents=True, exist_ok=True)
                # 同名覆盖，先把别的 feature_* 清掉：Play 的 featureGraphic 只收一张，
                # 目录里留两张会在 push 时上传两次，第二次必定 400。
                for old in dest.parent.glob("feature_*.png"):
                    if old.name != dest.name:
                        old.unlink()
                im.convert("RGB").save(dest, "PNG", optimize=True)
                promoted[loc] = dest
                print(f"  → 已写入 {dest.relative_to(C.ROOT)}（{dest.stat().st_size / 1024:.0f} KB）")

    if len(tags) > 1:
        print(f"\n共出 {len(tags)} 组 × {len(C.parse_locales(a.locales))} 语言"
              f" → {root.relative_to(C.ROOT) if root.is_relative_to(C.ROOT) else root}")
    if promoted:
        _patch_index(a.variant, promoted)
        print("\n下一步：aso_assets.py check --variant %s 复检规格" % a.variant)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
