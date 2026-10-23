#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""店面素材派生：竖版截图（1080×1920）+ 置顶大图（1024×500）。

    aso_assets.py fetch  --locales en-US,ja-JP          # 把线上原图抓下来当基线
    aso_assets.py build  --variant B                    # 按 data_aso/assets/shots.json 派生
    aso_assets.py check  --variant B                    # Play 规格体检
    aso_assets.py preview --variant B                   # 打开验收台（真机模拟 + 合规检查 + 文案计数）

为什么不是「换皮」而是「派生」
------------------------------
线上截图是 **1920×1080 横版**，而这游戏是**竖版**（ProjectSettings defaultScreenOrientation=0，
只允许 Portrait）。横版截图在手机商店页会被压成两条黑边的小图 —— 首图面积浪费一半。
所以这里做的是：竖版源图 → 裁掉底部世界聊天 → 归一到 9:16 → 叠一条卖点条。
真要重画（换皮/换风格），走 `aso_art.py` → TS-Art-Restyle，不在这一步做。

`--strict` 会让「源图放大超过 1.6 倍」变成阻断（默认只是标黄）。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import aso_common as C  # noqa: E402

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:  # pragma: no cover
    sys.stderr.write("缺 Pillow：<venv>/bin/pip install pillow\n")
    sys.exit(2)

try:
    import numpy as np
except ImportError:  # pragma: no cover
    sys.stderr.write("缺 numpy：<venv>/bin/pip install numpy\n")
    sys.exit(2)

SHOT_SPEC = C.ASSETS_DIR / "shots.json"
MAX_UPSCALE = 1.6          # 超过就标黄（1.6 倍以上 LANCZOS 也开始发糊）
PLAY_MAX_BYTES = 8 * 1024 * 1024   # Play 单张图片上限 8 MB


# --------------------------------------------------------------------------- #
# 通用
# --------------------------------------------------------------------------- #
def sha1_of(p: Path) -> str:
    h = hashlib.sha1()
    h.update(p.read_bytes())
    return h.hexdigest()


def load_spec() -> dict:
    if not SHOT_SPEC.is_file():
        raise SystemExit(f"缺少素材清单：{SHOT_SPEC}")
    return C.load_json(SHOT_SPEC)


FONT_FACE = {
    # 语言 → (字体文件, TTC 面序号)。🔴 面序号不能省：STHeiti Medium.ttc 的
    # 0 号面是 Heiti TC（繁体字形），简中直接用它会出现繁体骨架；
    # 而各 .ttc 的 0 号面往往是最细的一档，标题就发虚。
    "en-US": ("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 0),
    "ja-JP": ("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", 0),
    "zh-CN": ("/System/Library/Fonts/STHeiti Medium.ttc", 1),   # Heiti SC
    "zh-TW": ("/System/Library/Fonts/STHeiti Medium.ttc", 0),   # Heiti TC
}


def font_for(locale: str, size: int):
    face = FONT_FACE.get(locale)
    if face and Path(face[0]).is_file():
        try:
            return ImageFont.truetype(face[0], size, index=face[1]), face[0]
        except Exception:  # noqa: BLE001
            pass
    for f in C.LOCALES[locale]["fonts"]:
        if Path(f).is_file():
            try:
                return ImageFont.truetype(f, size), f
            except Exception:  # noqa: BLE001
                continue
    return ImageFont.load_default(), ""


def _fit_font(locale: str, text: str, max_w: int, start: int = 66, floor: int = 30):
    """二分/递减到能塞进一行的字号。"""
    size = start
    while size > floor:
        f, path = font_for(locale, size)
        box = f.getbbox(text)
        if box[2] - box[0] <= max_w:
            return f, path, size
        size -= 4
    return font_for(locale, floor)[0], font_for(locale, floor)[1], floor


def cover_resize(im: Image.Image, size: tuple[int, int], focus_y: float) -> Image.Image:
    """等比放大到铺满，再按 focus_y 纵向裁切（0=顶，1=底）。绝不拉伸。"""
    tw, th = size
    sw, sh = im.size
    scale = max(tw / sw, th / sh)
    nw, nh = max(tw, int(round(sw * scale))), max(th, int(round(sh * scale)))
    im = im.resize((nw, nh), Image.LANCZOS)
    left = (nw - tw) // 2
    top = int(round((nh - th) * min(max(focus_y, 0.0), 1.0)))
    top = max(0, min(top, nh - th))
    return im.crop((left, top, left + tw, top + th))


def pad_resize(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """等比装进去，空白用「自身放大模糊+压暗」填 —— 不裁内容，也不留死黑边。"""
    tw, th = size
    bg = cover_resize(im, size, 0.5).filter(ImageFilter.GaussianBlur(28))
    bg = Image.eval(bg, lambda v: int(v * 0.45))
    sw, sh = im.size
    scale = min(tw / sw, th / sh)
    fg = im.resize((max(1, int(sw * scale)), max(1, int(sh * scale))), Image.LANCZOS)
    bg.paste(fg, ((tw - fg.width) // 2, (th - fg.height) // 2))
    return bg



BRAND_CYAN = (86, 232, 226)
BRAND_PINK = (255, 45, 149)
_CJK_LOCALES = ("ja-JP", "zh-CN", "zh-TW")
CARD_INSET_X = 0.048    # 截图卡左右留白（占画布宽）
CARD_TOP = 0.044
CARD_H = 0.715
_BG_CACHE: dict = {}

# 全角标点的步进是 1em，但字形只占左边一小块，右边留白极大 ——
# 直接画出来就是「网格 ，  站位」这种散开的观感。按墨迹宽度收紧步进。
_PUNCT = set("，。、；：！？）」』】》〉…·,.")
# 允许在其「之后」断行的字符：标点 + 日文助词/终助词。
_BREAK_STRONG = set("，。、；：！？）」』】》〉…・ ,.!?;:")
_BREAK_AFTER = _BREAK_STRONG | set("はがをにでとへもやのねよか")


def _draw_cjk_line(d, xy, text: str, font, fill, shadow: tuple | None = None) -> None:
    """按字推进并压缩全角标点步进。PIL 没有 kerning 控制，只能自己走字。"""
    x, y = xy
    em = font.size
    for ch in text:
        if shadow:
            d.text((x + shadow[0], y + shadow[1]), ch, font=font, fill=shadow[2])
        d.text((x, y), ch, font=font, fill=fill)
        adv = d.textlength(ch, font=font)
        if ch in _PUNCT:
            # 全角标点步进 1em，但「，」的墨迹只有 11px（97px 字号下）——
            # getbbox 报的是整字框、量不出留白。压到 0.68em：字距收紧，
            # 又不至于让标点贴住下一个字（压到 0.5em 实测粘连）。
            adv = min(adv, em * 0.68)
        x += adv


def _split_units(text: str) -> list[str]:
    """切成「不许从中间拆开」的最小单元：拉丁词/数字串整体，CJK 一字一个。

    直接按字符宽度累加会在单词中间断行（`Placem|ent`），按空格断又会让
    中文整段算一个词。这里两种都照顾。
    """
    out: list[str] = []
    buf = ""
    for ch in text:
        if ch.isascii() and (ch.isalnum() or ch in "'’.,/%+&-–—:!"):
            buf += ch
        else:
            if buf:
                out.append(buf)
                buf = ""
            out.append(ch)
    if buf:
        out.append(buf)
    return out


def _wrap(d, text: str, font, max_w: float) -> list[str]:
    """断行：拉丁按词，CJK 优先断在标点/助词之后。

    🔴 逐字续行会把词劈开（日文实测「一突きで、後衛は消 / える。」）。
    所以先记下所有「可断点」，超宽时回退到最近的可断点；实在没有才硬断。
    """
    units = _split_units(text)
    lines: list[str] = []
    cur: list[str] = []
    width = 0.0
    for u in units:
        if u.isspace() and not cur:
            continue
        w = d.textlength(u, font=font)
        if cur and width + w > max_w:
            joined = "".join(cur)
            cut = None
            # 标点处的断点优先于助词处的断点：日文里「あと / は仲間…」这种
            # 把助词甩到下一行的断法很丑，而「…抜けば、/ あとは…」是对的。
            for chars, ratio in ((_BREAK_STRONG, 0.45), (_BREAK_AFTER, 0.60)):
                for i in range(len(cur) - 1, 0, -1):
                    if cur[i - 1] and cur[i - 1][-1] in chars:
                        if d.textlength("".join(cur[:i]), font=font) >= max_w * ratio:
                            cut = i
                        break
                if cut:
                    break
            if cut:
                lines.append("".join(cur[:cut]).rstrip())
                cur = cur[cut:]
            else:
                lines.append(joined.rstrip())
                cur = []
            width = d.textlength("".join(cur), font=font)
        cur.append(u)
        width += w
    if "".join(cur).strip():
        lines.append("".join(cur).rstrip())
    for i in range(1, len(lines)):          # 避头尾：不让「，。」落到行首
        while lines[i] and lines[i][0] in "，。、；：！？）」』】%…":
            if len(lines[i - 1]) < 2:
                break
            lines[i - 1] += lines[i][0]
            lines[i] = lines[i][1:]
    return lines


def _fit_block(d, locale: str, text: str, max_w: float, max_lines: int = 2,
               hi: int = 90, lo: int = 44):
    """在 max_lines 行内塞下 text 的最大字号。

    优先找「正好排满 max_lines 行」的字号 —— 四张截图的画布尺寸一样，
    有的句子一行、有的两行，看起来就不是一套东西。统一成两行最整齐。
    """
    fallback = None
    size = hi
    while size >= lo:
        f, _ = font_for(locale, size)
        lines = _wrap(d, text, f, max_w)
        if len(lines) == max_lines:
            return f, lines, size
        if fallback is None and len(lines) < max_lines:
            fallback = (f, lines, size)
        size -= 2
    f, _ = font_for(locale, lo)
    return fallback or (f, _wrap(d, text, f, max_w), lo)


def _lerp(a, b, t: float) -> tuple:
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def _brand_backdrop(size: tuple[int, int]) -> Image.Image:
    """商店页底图：深紫罗兰渐变 + 三颗霓虹光斑。

    🔴 为什么不再用「截图 + 底部黑条」：源图 55%~62% 是按钮行、65% 以下是世界
    聊天，怎么裁都会切到 UI，切完再把下半截刷成纯黑，看着就是「图被裁断了」。
    换成卡片式版式后，切边变成**卡片边界**（本来就该结束），底色由我们自己画，
    不再受源图配色影响，四张图才像一套。
    光斑在 1/4 尺寸上画完再放大：全尺寸高斯会把单张图拖到几秒。
    """
    key = tuple(size)
    if key in _BG_CACHE:
        return _BG_CACHE[key].copy()
    tw, th = size
    top, mid, bot = (10, 9, 20), (30, 18, 56), (8, 7, 16)
    strip = Image.new("RGB", (1, th))
    sd = ImageDraw.Draw(strip)
    for y in range(th):
        t = y / max(1, th - 1)
        sd.point((0, y), fill=_lerp(top, mid, t / 0.62) if t < 0.62
                 else _lerp(mid, bot, (t - 0.62) / 0.38))
    img = strip.resize((tw, th), Image.BILINEAR).convert("RGBA")

    sw, sh = max(2, tw // 4), max(2, th // 4)
    glow = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for cx, cy, rr, col, a in ((0.90, 0.05, 0.62, BRAND_PINK, 92),
                               (0.02, 0.55, 0.50, BRAND_CYAN, 54),
                               (0.55, 1.00, 0.72, (118, 76, 255), 80)):
        R = int(rr * sw)
        gd.ellipse([cx * sw - R, cy * sh - R, cx * sw + R, cy * sh + R], fill=col + (a,))
    glow = glow.filter(ImageFilter.GaussianBlur(max(6, sw * 0.20)))
    img = Image.alpha_composite(img, glow.resize((tw, th), Image.BICUBIC))
    out = img.convert("RGB")
    _BG_CACHE[key] = out
    return out.copy()


def _round_mask(size: tuple[int, int], radius: int) -> Image.Image:
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1],
                                        radius=max(2, radius), fill=255)
    return m


def _neon_gradient(size: tuple[int, int]) -> Image.Image:
    """卡片描边用的品红→青渐变。只露 3~4 px，等于一圈霓虹细边。"""
    w, h = size
    strip = Image.new("RGB", (1, h))
    sd = ImageDraw.Draw(strip)
    for y in range(h):
        sd.point((0, y), fill=_lerp(BRAND_PINK, BRAND_CYAN, y / max(1, h - 1)))
    return strip.resize((w, h), Image.BILINEAR)


def _font_hero(locale: str, size: int):
    """标题字：英文用 Arial Black（游戏海报那种厚度），CJK 用现有重字。"""
    if locale.startswith("en"):
        pth = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
        if Path(pth).is_file():
            try:
                return ImageFont.truetype(pth, size), pth
            except Exception:  # noqa: BLE001
                pass
    return font_for(locale, size)


def _parse_marked(text: str) -> list[list[tuple[str, bool]]]:
    """把 "A *B* C\nD" 解析成逐字符 (字, 是否强调) 的行数组。"""
    out = []
    for ln in text.split("\n"):
        chars, on = [], False
        for ch in ln:
            if ch == "*":
                on = not on
                continue
            chars.append((ch, on))
        out.append(chars)
    return out


def _draw_rich(d, xy, chars, font, fill, accent=None, shadow=None,
               compress_punct: bool = False) -> float:
    """逐字画（这样才能给个别词上主色），返回行宽。"""
    x, y = xy
    em = font.size
    for ch, hot in chars:
        if shadow:
            d.text((x + shadow[0], y + shadow[1]), ch, font=font, fill=shadow[2])
        d.text((x, y), ch, font=font,
               fill=(accent if (hot and accent) else fill))
        adv = d.textlength(ch, font=font)
        if compress_punct and ch in _PUNCT:
            adv = min(adv, em * 0.68)
        x += adv
    return x - xy[0]


def _draw_caption(canvas: Image.Image, top: int, height: int, tw: int,
                  caption: str, kicker: str, locale: str,
                  tint: tuple | None = None, heavy: bool = False) -> None:
    """文案区：左侧竖色条 + 字距拉开的小标 + 主文案。

    caption 里可以用 `\n` 硬断行、用 `*…*` 标出要上主色的关键词 —— 英雄卡靠这个
    做「口号 + 关键词」的游戏味；没有 `\n` 时退回自动断行（商店截图那条路径）。

    2× 超采样再缩回：直接按最终尺寸描字，中/日文的撇捺边缘会发毛，
    字距一拉开更明显。放大一倍画完用 LANCZOS 落回，边缘才干净。
    """
    SS = 2
    pad = int(tw * 0.052)
    W, H = tw * SS, height * SS
    meas = ImageDraw.Draw(Image.new("RGBA", (4, 4)))
    bar_w = max(6, int(tw * 0.0070) * SS)
    text_x = pad * SS + bar_w + int(tw * 0.026) * SS
    max_w = tw * SS - text_x - pad * SS
    cjk = locale in _CJK_LOCALES
    scale = 1.06 if cjk else 1.0
    pick = _font_hero if heavy else font_for

    hard = "\n" in caption
    if hard:
        lines = _parse_marked(caption)
        hi = int(tw * (0.104 if heavy else 0.086) * scale) * SS
        lo = int(tw * 0.044 * scale) * SS
        size = hi
        while size > lo:
            f = pick(locale, size)[0]
            if all(meas.textlength("".join(c for c, _ in ln), font=f) <= max_w for ln in lines):
                break
            size -= 2
        # 🔴 只取 [0]：_font_hero 的第二返回值是字体路径，不是字号（拿它当 hs 会炸在 line_h）
        f_head, hs = pick(locale, size)[0], size
    else:
        f_head, plain, hs = _fit_block(meas, locale, caption, max_w, 2,
                                       hi=int(tw * 0.086 * scale) * SS,
                                       lo=int(tw * 0.044 * scale) * SS)
        lines = _parse_marked("\n".join(plain))
    line_h = int(round(hs * (1.04 if heavy else 1.16)))
    head_h = line_h * len(lines)
    ks = int(tw * 0.0255) * SS
    kgap = int(ks * 0.95)
    block_h = head_h + (ks + kgap if kicker else 0)
    bottom_pad = int(height * SS * 0.13)
    top_y = H - bottom_pad - block_h

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    body = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd, bd = ImageDraw.Draw(shadow), ImageDraw.Draw(body)

    if kicker:
        fk, _ = font_for(locale, ks)
        kc = tint or BRAND_CYAN
        _draw_tracked(bd, (text_x, top_y), kicker.upper(), fk, tuple(kc) + (255,),
                      tracking=ks * 0.18)
    accent = tuple(min(255, int(c + (255 - c) * 0.30)) for c in tint) if tint else None
    y = top_y + (ks + kgap if kicker else 0)
    for ln in lines:
        _draw_rich(sd, (text_x, y + max(2, hs * 0.018)), ln, f_head,
                   (0, 0, 0, 120))
        _draw_rich(bd, (text_x, y), ln, f_head, (255, 255, 255, 255),
                   accent=accent, compress_punct=cjk)
        y += line_h
    shadow = shadow.filter(ImageFilter.GaussianBlur(max(3, hs * 0.075)))

    bar = Image.new("RGBA", (bar_w, max(1, block_h)), (0, 0, 0, 0))
    bd2 = ImageDraw.Draw(bar)
    for i in range(bar.height):
        bd2.line([(0, i), (bar_w, i)],
                 fill=_lerp(tint or BRAND_PINK, BRAND_CYAN,
                            i / max(1, bar.height - 1)) + (255,))
    body.alpha_composite(bar, (pad * SS, top_y))

    region = canvas.crop((0, top, tw, top + height)).convert("RGBA")
    region.alpha_composite(shadow.resize((tw, height), Image.LANCZOS))
    region.alpha_composite(body.resize((tw, height), Image.LANCZOS))
    canvas.paste(region.convert("RGB"), (0, top))


def compose_shot(src_im: Image.Image, size: tuple[int, int], caption: str,
                 locale: str, focus_y: float, kicker: str = "") -> tuple[Image.Image, int]:
    """一张商店截图 = 品牌底图 + 圆角霓虹卡片 + 底部文案区。

    返回 (成品, 卡片下沿 y)，后者给 `--fit pad` 分支沿用。
    """
    tw, th = size
    canvas = _brand_backdrop((tw, th))
    cx = int(tw * CARD_INSET_X)
    cw = tw - 2 * cx
    cy = int(th * CARD_TOP)
    chh = int(th * (CARD_H if caption else 0.86))
    r = max(20, int(cw * 0.034))

    shadow = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    off = int(cw * 0.014)
    ImageDraw.Draw(shadow).rounded_rectangle([cx, cy + off, cx + cw, cy + chh + off],
                                             r, fill=(0, 0, 0, 170))
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(cw * 0.030)))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB")

    canvas.paste(_neon_gradient((cw, chh)), (cx, cy), _round_mask((cw, chh), r))
    inset = max(3, int(cw * 0.0035))
    inner = (cw - 2 * inset, chh - 2 * inset)
    shot = cover_resize(src_im, inner, focus_y)
    # 源图大多 597~720px 宽，进卡片要放大 1.5~1.7 倍，直接 LANCZOS 会发软。
    # 只对「确实放大了」的图补一点 unsharp（半径别大，大了出白边）。
    if src_im.width and inner[0] / src_im.width > 1.25:
        shot = shot.filter(ImageFilter.UnsharpMask(radius=1.5, percent=62, threshold=3))
    canvas.paste(shot, (cx + inset, cy + inset), _round_mask(inner, max(8, r - inset)))

    if caption:
        _draw_caption(canvas, cy + chh, th - (cy + chh), tw, caption, kicker, locale)
    return canvas, cy + chh

    return canvas, content_h


# --------------------------------------------------------------------------- #
# 首图/置顶图排版：AI 只画画面，字一律由这里用真字体压上去
# --------------------------------------------------------------------------- #
# 🔴 为什么字不交给模型：中/日/繁三语的字形 AI 十有八九画错（缺笔画、错字、间距乱），
#    而且每个语言要同一套排版才像一家人。所以生成图一律要求「无字」，
#    标题用系统字体在这里排 —— 换文案不用重新出图，改一个字也不用烧一次额度。
GEN_DIR = C.ASSETS_DIR / "gen"
PROMO = C.ASSETS_DIR / "promo.json"


def _promo() -> dict:
    return C.load_json(PROMO) if PROMO.is_file() else {}


def hero_art(loc: str) -> Path | None:
    """AI 出的竖版底图：优先语言专属，其次通用一张。"""
    for name in (f"hero_{loc}.png", "hero.png"):
        p = GEN_DIR / name
        if p.is_file():
            return p
    return None


def _tracked_w(d, text: str, font, tracking: float) -> float:
    return sum(d.textlength(ch, font=font) for ch in text) + tracking * max(0, len(text) - 1)


def _draw_tracked(d, xy, text: str, font, fill, tracking: float = 0.0, shadow=None):
    """带字距的绘制。PIL 没有 letter-spacing，英文全大写标题不加字距会挤成一坨。"""
    x, y = xy
    for ch in text:
        if shadow:
            d.text((x + 2, y + 3), ch, font=font, fill=shadow)
        d.text((x, y), ch, font=font, fill=fill)
        x += d.textlength(ch, font=font) + tracking


def _accent_bar(im: Image.Image, y: int, x0: int, x1: int) -> Image.Image:
    d = ImageDraw.Draw(im)
    d.rectangle([x0, y, x1, y + 3], fill=(53, 214, 208, 255))
    d.rectangle([x0, y, x0 + 120, y + 3], fill=(255, 45, 149, 255))
    return im


def compose_headline(art: Image.Image, loc: str, spec: dict, kind: str) -> Image.Image:
    """在生成图上压标题。

    hero（1080×1920）：底部 30% 三段式 —— 字距拉开的小标 / 主标题 / 斜线分隔的 tagline。
    feature（1024×500）：底部 20% 两段 —— 主标题 + 细 tagline，左侧竖条强调。
    """
    d0 = spec["locales"].get(loc, {})
    head = d0.get("headline") or ""
    sub = d0.get("subline") or ""
    tag = d0.get("tagline") or ""
    im = art.convert("RGBA")
    w, h = im.size

    if kind == "hero":
        band_h = int(h * 0.30)
        # 底部压深，保证白字在任何底图上都读得清（渐变而不是硬切）
        ov = Image.new("RGBA", (w, band_h), (0, 0, 0, 0))
        od = ImageDraw.Draw(ov)
        for i in range(band_h):
            a = int(235 * min(1.0, (i / max(1, band_h - 1)) ** 1.25))
            od.line([(0, i), (w, i)], fill=(8, 7, 14, a))
        im.alpha_composite(ov, (0, h - band_h))
        d = ImageDraw.Draw(im)

        y = h - int(band_h * 0.16)
        if tag:
            f = font_for(loc, 26)[0]
            tw = _tracked_w(d, tag, f, 3)
            _draw_tracked(d, ((w - tw) / 2, y - 28), tag, f, (150, 158, 186, 255), 3)
            y -= 62
        if sub:
            f = font_for(loc, 40)[0]
            tw = _tracked_w(d, sub, f, 1.5)
            _draw_tracked(d, ((w - tw) / 2, y - 46), sub, f, (53, 214, 208, 255), 1.5)
            y -= 74
        if head:
            f, _, size = _fit_font(loc, head, int(w * 0.88), start=104, floor=56)
            tw = _tracked_w(d, head, f, 2)
            _draw_tracked(d, ((w - tw) / 2, y - size - 10), head, f,
                          (255, 255, 255, 255), 2, shadow=(0, 0, 0, 200))
            y -= size + 26
        _accent_bar(im, y - 6, int(w * 0.30), int(w * 0.70))
    else:
        band_h = int(h * 0.24)
        ov = Image.new("RGBA", (w, band_h), (0, 0, 0, 0))
        od = ImageDraw.Draw(ov)
        for i in range(band_h):
            a = int(225 * min(1.0, (i / max(1, band_h - 1)) ** 1.2))
            od.line([(0, i), (w, i)], fill=(8, 7, 14, a))
        im.alpha_composite(ov, (0, h - band_h))
        d = ImageDraw.Draw(im)
        x0 = int(w * 0.055)
        if tag:
            f = font_for(loc, 17)[0]
            _draw_tracked(d, (x0, h - 34), tag, f, (140, 148, 178, 255), 2.2)
        if head:
            f, _, size = _fit_font(loc, head, int(w * 0.62), start=52, floor=26)
            _draw_tracked(d, (x0, h - 34 - size - 14), head, f, (255, 255, 255, 255), 1.6,
                          shadow=(0, 0, 0, 190))
            d.rectangle([x0 - 14, h - 34 - size - 14, x0 - 10, h - 40], fill=(53, 214, 208, 255))
    return im.convert("RGB")


def cmd_headline(args) -> int:
    """单独跑排版（不重出图）：改文案后即时看效果。"""
    spec = _promo()
    src = Path(args.art).expanduser()
    if not src.is_absolute():
        src = C.ROOT / src
    if not src.is_file():
        print(f"底图不存在：{src}")
        return 2
    im = compose_headline(Image.open(src), args.locale, spec, args.kind)
    out = Path(args.out) if args.out else src.with_name(f"{src.stem}_typed_{args.locale}.png")
    if not out.is_absolute():
        out = C.ROOT / out
    out.parent.mkdir(parents=True, exist_ok=True)
    im.save(out, "PNG", optimize=True)
    print(f"[headline] {src.name} + {args.locale} → {out}  {im.size}")
    return 0


# --------------------------------------------------------------------------- #
# fetch：把线上原图抓下来
# --------------------------------------------------------------------------- #
def cmd_fetch(args) -> int:
    base = Path(args.online_dir) if args.online_dir else _latest_online()
    if not base:
        print("没有 data_aso/online/*/images.json，先跑 aso_play.py list")
        return 2
    images = C.load_json(base / "images.json")
    locales = C.parse_locales(args.locales)
    out_root = base / "assets"
    n = 0
    for loc in locales:
        if loc not in images:
            continue
        for itype, items in images[loc].items():
            if not isinstance(items, list):
                continue
            d = out_root / loc
            d.mkdir(parents=True, exist_ok=True)
            for i, img in enumerate(items):
                url = (img.get("url") or "") + "=w2400"
                if not img.get("url"):
                    continue
                fn = d / f"{'shot' if itype == 'phoneScreenshots' else 'feature'}_{i + 1:02d}.png"
                try:
                    raw = urllib.request.urlopen(url, timeout=45).read()
                    fn.write_bytes(raw)
                    with Image.open(fn) as im:
                        print(f"[fetch] {loc} {itype} #{i} → {fn.name} {im.size}")
                    n += 1
                except Exception as e:  # noqa: BLE001
                    print(f"[fetch] {loc} {itype} #{i} 失败：{e}")
    print(f"[fetch] 共 {n} 张，落在 {out_root}")
    return 0 if n else 1


def _latest_online() -> Path | None:
    if not C.ONLINE_DIR.is_dir():
        return None
    dirs = sorted([p for p in C.ONLINE_DIR.iterdir() if p.is_dir()], key=lambda p: p.name)
    for p in reversed(dirs):
        if (p / "images.json").is_file():
            return p
    return None


# --------------------------------------------------------------------------- #
# build
# --------------------------------------------------------------------------- #
def cmd_build(args) -> int:
    spec = load_spec()
    locales = C.parse_locales(args.locales)
    tw, th = _parse_size(args.size)
    out_root = C.DERIVED_DIR / args.variant
    notes: list[str] = []
    index: dict = {"variant": args.variant, "canvas": [tw, th], "locales": {}}

    for loc in locales:
        d = out_root / loc
        d.mkdir(parents=True, exist_ok=True)
        for old in d.glob("*.png"):
            old.unlink()
        entries = []
        for i, shot in enumerate(spec.get("shots", []), start=1):
            src = C.ROOT / shot["src"]
            if not src.is_file():
                notes.append(f"{loc}: 源图不存在 {shot['src']}")
                continue
            im = Image.open(src).convert("RGB")
            crop_bottom = float(shot.get("crop_bottom") or 0)
            crop_top = float(shot.get("crop_top") or 0)
            if crop_bottom > 0 or crop_top > 0:
                # 顶边也要裁：源图最上面那 5% 是状态栏/回合数，卡片顶边切进去
                # 就会露出半截图标 —— 跟底边切到按钮行是同一个毛病。
                im = im.crop((0, int(im.height * crop_top), im.width,
                              int(im.height * (1 - crop_bottom))))
            upscale = (tw / im.width)
            cap = "" if args.no_caption else (shot.get("captions", {}).get(loc) or "")
            kick = "" if args.no_caption else (shot.get("kickers", {}).get(loc) or "")
            out, content_h = compose_shot(im, (tw, th), cap, loc,
                                          float(shot.get("focus_y", 0.5)), kick)
            if args.fit == "pad":
                # pad 模式：内容区整图装入（不裁），与 caption 条并存
                body = pad_resize(im, (tw, content_h))
                out = Image.new("RGB", (tw, th), (13, 11, 20))
                out.paste(body, (0, 0))
                if content_h < th:
                    band = compose_shot(im, (tw, th), cap, loc, 0.5, kick)[0]
                    out.paste(band.crop((0, content_h, tw, th)), (0, content_h))
            fn = d / f"shot_{i:02d}.png"
            out.save(fn, "PNG", optimize=True)
            entries.append({"file": fn.name, "src": shot["src"], "size": list(out.size),
                            "upscale": round(upscale, 2), "caption": cap,
                            "kicker": kick,
                            "bytes": fn.stat().st_size, "sha1": sha1_of(fn)})
            if upscale > MAX_UPSCALE:
                notes.append(f"{loc} {fn.name}: 源图 {im.width}px 放大到 {tw}px（{upscale:.1f}×），会发糊")

        # 首图（shot_00）：AI 出的竖版底图 + 本地化标题。没有底图就没有首图，
        # 不拿半成品凑数 —— 宁可少一张，也别把没排版的裸图推上去。
        hsrc = hero_art(loc)
        if hsrc:
            him = cover_resize(Image.open(hsrc).convert("RGB"), (tw, th), 0.5)
            him = compose_headline(him, loc, _promo(), "hero")
            fn = d / "shot_00.png"
            him.save(fn, "PNG", optimize=True)
            entries.insert(0, {"file": fn.name, "src": str(hsrc.relative_to(C.ROOT)),
                            "size": list(him.size), "upscale": 1.0, "caption": "",
                            "bytes": fn.stat().st_size, "sha1": sha1_of(fn)})

        # 置顶图
        feat_src = (spec.get("feature") or {}).get(loc) or ""
        fallback = False
        if not feat_src:
            feat_src = (spec.get("feature") or {}).get("zh-CN") or ""
            fallback = True
        if feat_src:
            p = C.ROOT / feat_src
            if p.is_file():
                fs = _parse_size(args.feature_size)
                out = cover_resize(Image.open(p).convert("RGB"), fs, 0.5)
                fn = d / "feature_01.png"
                out.save(fn, "PNG", optimize=True)
                entries.append({"file": fn.name, "src": feat_src, "size": list(out.size),
                                "bytes": fn.stat().st_size, "sha1": sha1_of(fn)})
                if fallback:
                    notes.append(f"{loc}: 没有本地化置顶图，沿用 zh-CN 版（应走 aso_art.py 重绘）")
            else:
                notes.append(f"{loc}: 置顶图源不存在 {feat_src}")
        index["locales"][loc] = entries

    (out_root / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    _write_preview(out_root, locales, notes)

    print(f"[build] {out_root}  画布 {tw}×{th}  fit={args.fit}")
    for loc in locales:
        files = sorted((out_root / loc).glob("*.png"))
        print(f"  {loc}: {len(files)} 张  {[f.name for f in files]}")
    if notes:
        print("\n🟡 提醒：")
        for n in notes:
            print(f"   - {n}")
    return 0


def _parse_size(s: str) -> tuple[int, int]:
    w, _, h = s.lower().partition("x")
    try:
        return int(w), int(h)
    except ValueError:
        raise SystemExit(f"尺寸写法应是 1080x1920，收到：{s}")


# 「某张截图被放大」这种逐图提醒在验收台里会被「合规检查」按张数汇总掉，
# 留着只会同一句话说三遍，所以这里过滤掉，只保留语言级提醒（如置顶图缺本地化）。
_SHOT_NOTE_RE = re.compile(r"shot_\d+\.png")


def _write_preview(out_root: Path, locales: list[str], notes: list[str] | None = None) -> None:
    """生成验收台：一份 HTML，把「图上真机什么样」和「文案还剩几个字」放在同一屏。

    为什么不再是一排缩略图：验收要回答三个具体问题——
      1. 用户在商店页第一屏到底看到什么（真机比例 + 标题 + 短描述）；
      2. 每张图合不合规（尺寸/比例/放大倍数/体积），不合规的是哪一张；
      3. 文案离上限还有多少余量、跟线上 A 差在哪。
    缩略图这三件事一件都答不了，所以重做成带导航、检查项、文案计数和灯箱的结构。
    """
    notes = notes or []
    variant = out_root.name
    idx = C.load_json(out_root / "index.json")
    meta = C.load_variant_meta(variant)
    data: dict = {
        "variant": variant,
        "canvas": idx.get("canvas") or list(C.SHOT_SIZE),
        "featureSize": list(C.FEATURE_SIZE),
        "limits": C.LIMITS,
        "builtAt": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "meta": {k: meta.get(k) for k in ("label", "note", "hypothesis") if meta.get(k)},
        "locales": {},
    }
    for loc in locales:
        try:
            live = C.text_fields(C.load_listing(variant, loc))
        except SystemExit:
            live = {}
        base: dict = {}
        if variant != "A":
            try:
                base = C.text_fields(C.load_listing("A", loc))
            except SystemExit:
                base = {}
        ents = idx["locales"].get(loc, [])
        shots = [e for e in ents if e["file"].startswith("shot")]
        feats = [e for e in ents if e["file"].startswith("feature")]
        data["locales"][loc] = {
            "code": loc,
            "label": C.LOCALES[loc]["label"],
            "shots": shots,
            "feature": feats[0] if feats else None,
            "copy": live,
            "base": base,
            "notes": [n for n in notes
                      if n.startswith(loc) and not _SHOT_NOTE_RE.search(n)],
        }

    html = (
        "<!doctype html><html lang=\"zh-CN\"><head><meta charset=\"utf-8\">"
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
        f"<title>店面验收台 · {variant}</title><style>{_PREVIEW_CSS}</style></head><body>"
        "<aside class=\"side\">"
        "<div class=\"brand\"><span class=\"mark\"></span>"
        "<span><b>店面验收台</b><i>Store Iteration</i></span></div>"
        "<div class=\"pills\">"
        f"<span class=\"pill accent\">变体 {variant}</span>"
        f"<span class=\"pill\">{data['canvas'][0]}×{data['canvas'][1]}</span></div>"
        "<nav id=\"nav\"></nav>"
        "<div class=\"side-foot\">"
        f"<div>生成于 {data['builtAt']}</div>"
        "<div class=\"mono\">data_aso/derived/" + variant + "</div>"
        "<div class=\"tip\">点任意截图看原尺寸 · Esc 关闭</div>"
        "</div></aside>"
        "<main><header class=\"topbar\">"
        "<div><h1>商店页素材与文案</h1>"
        "<p id=\"topmeta\" class=\"sub\"></p></div>"
        "<div id=\"health\" class=\"health\"></div></header>"
        "<div id=\"panels\"></div>"
        "<footer class=\"foot\">A 组为线上基线（只读）· 推送需 ALLOW_WRITE · 送审只能人工点</footer>"
        "</main>"
        "<div id=\"lightbox\" class=\"lightbox\"><img alt=\"\"><span class=\"hint\">Esc / 点击关闭</span></div>"
        f"<script>const DATA={json.dumps(data, ensure_ascii=False)};</script>"
        f"<script>{_PREVIEW_JS}</script></body></html>"
    )
    (out_root / "preview.html").write_text(html, encoding="utf-8")


_PREVIEW_CSS = r"""
:root{
  --bg:#0a0b10;--surface:#12141c;--surface2:#171a24;--surface3:#1d2130;
  --line:rgba(255,255,255,.075);--line2:rgba(255,255,255,.14);
  --text:#e9ebf2;--muted:#8b90a6;--dim:#5f6478;
  --violet:#8b7bff;--cyan:#35d6d0;--amber:#f5b545;--red:#ff6b6b;--green:#4ade80;
  --mono:ui-monospace,SFMono-Regular,"SF Mono",Menlo,monospace;
  --side:252px;
}
*{box-sizing:border-box}
html,body{margin:0;min-height:100%}
body{background:var(--bg);color:var(--text);
  font:14px/1.65 -apple-system,BlinkMacSystemFont,"PingFang SC","Hiragino Sans GB",sans-serif;
  -webkit-font-smoothing:antialiased;display:flex;align-items:flex-start}
body::before{content:"";position:fixed;inset:0;pointer-events:none;z-index:0;
  background:radial-gradient(820px 520px at 4% -8%,rgba(139,123,255,.17),transparent 62%),
             radial-gradient(760px 460px at 100% -4%,rgba(53,214,208,.10),transparent 58%)}
.mono{font-family:var(--mono);font-size:11px}
/* ---------- 侧栏 ---------- */
.side{position:sticky;top:0;flex:0 0 var(--side);width:var(--side);height:100vh;z-index:2;
  padding:22px 16px;display:flex;flex-direction:column;gap:18px;
  background:linear-gradient(180deg,rgba(23,26,36,.92),rgba(10,11,16,.92));
  border-right:1px solid var(--line);backdrop-filter:blur(12px)}
.brand{display:flex;align-items:center;gap:10px;font-size:15px}
.brand .mark{width:26px;height:26px;border-radius:9px;flex:0 0 auto;
  background:conic-gradient(from 210deg,var(--violet),var(--cyan),var(--violet));
  box-shadow:0 0 22px rgba(139,123,255,.45)}
.brand i{display:block;font-style:normal;font-size:10px;letter-spacing:.14em;
  text-transform:uppercase;color:var(--dim)}
.pills{display:flex;flex-wrap:wrap;gap:6px}
.pill{font-size:11px;padding:3px 9px;border-radius:999px;border:1px solid var(--line2);
  color:var(--muted);font-family:var(--mono)}
.pill.accent{color:#cdc7ff;border-color:rgba(139,123,255,.4);background:rgba(139,123,255,.12)}
#nav{display:flex;flex-direction:column;gap:2px;overflow:auto;flex:1}
#nav button{all:unset;cursor:pointer;display:flex;align-items:center;gap:9px;
  padding:9px 11px;border-radius:10px;color:var(--muted);font-size:13px;transition:.16s}
#nav button:hover{background:rgba(255,255,255,.05);color:var(--text)}
#nav button.on{background:rgba(139,123,255,.14);color:#fff;
  box-shadow:inset 0 0 0 1px rgba(139,123,255,.32)}
#nav button .code{font-family:var(--mono);font-size:10px;color:var(--dim);margin-left:auto}
#nav button.on .code{color:#cdc7ff}
#nav .dot{width:6px;height:6px;border-radius:50%;background:var(--green);flex:0 0 auto}
#nav .dot.warn{background:var(--amber)}
.side-foot{font-size:11px;color:var(--dim);line-height:1.8;border-top:1px solid var(--line);padding-top:12px}
.side-foot .tip{color:#4a4f60}
/* ---------- 主区 ---------- */
main{flex:1;min-width:0;padding:26px 30px 60px;position:relative;z-index:1}
.topbar{display:flex;justify-content:space-between;align-items:flex-end;gap:20px;
  padding-bottom:16px;margin-bottom:22px;border-bottom:1px solid var(--line);flex-wrap:wrap}
h1{margin:0;font-size:21px;font-weight:650;letter-spacing:-.01em}
.sub{margin:5px 0 0;font-size:12px;color:var(--dim)}
.health{display:flex;gap:8px}
.chip{display:inline-flex;align-items:center;gap:6px;font-size:11.5px;padding:5px 11px;
  border-radius:9px;border:1px solid var(--line2);color:var(--muted);background:var(--surface)}
.chip b{font-family:var(--mono);font-size:13px;color:var(--text)}
.chip.ok{border-color:rgba(74,222,128,.3);background:rgba(74,222,128,.09)}
.chip.ok b{color:var(--green)}
.chip.warn{border-color:rgba(245,181,69,.32);background:rgba(245,181,69,.1)}
.chip.warn b{color:var(--amber)}
.panel{display:none;animation:fade .22s ease}
.panel.on{display:block}
@keyframes fade{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:none}}
.panel-head{display:flex;justify-content:space-between;align-items:center;gap:16px;margin-bottom:16px;flex-wrap:wrap}
.panel-head h2{margin:0;font-size:16px;font-weight:600;display:flex;align-items:center;gap:9px}
.panel-head h2 .code{font-family:var(--mono);font-size:11px;color:var(--violet);
  background:rgba(139,123,255,.12);border:1px solid rgba(139,123,255,.28);
  padding:2px 8px;border-radius:7px}
.grid2{display:grid;grid-template-columns:minmax(320px,1fr) minmax(280px,.85fr);gap:16px;margin-bottom:16px}
.card{background:linear-gradient(180deg,var(--surface),var(--bg));border:1px solid var(--line);
  border-radius:16px;padding:18px;margin-bottom:16px}
.card>h3{margin:0 0 14px;font-size:12px;font-weight:600;letter-spacing:.05em;
  text-transform:uppercase;color:var(--muted);display:flex;align-items:center;gap:8px}
.card>h3 .count{font-family:var(--mono);font-size:11px;color:var(--dim);text-transform:none;letter-spacing:0}
/* 真机模拟 */
.store-body{display:flex;gap:20px;align-items:flex-start;flex-wrap:wrap}
.phone{width:236px;flex:0 0 auto;border-radius:26px;padding:8px;position:relative;
  background:linear-gradient(160deg,#2a2e3d,#12141c);
  box-shadow:0 22px 48px -18px rgba(0,0,0,.9),inset 0 0 0 1px rgba(255,255,255,.09)}
.phone img{width:100%;display:block;border-radius:19px;aspect-ratio:9/16;object-fit:cover;cursor:zoom-in}
.store-text{flex:1;min-width:210px}
.store-title{font-size:17px;font-weight:600;line-height:1.35}
.store-dev{font-size:12px;color:var(--cyan);margin-top:3px}
.store-meta{font-size:11.5px;color:var(--dim);margin-top:7px;display:flex;gap:10px;flex-wrap:wrap}
.store-short{font-size:12.5px;color:var(--muted);margin-top:11px;line-height:1.6}
.store-btn{margin-top:14px;display:inline-block;font-size:12px;font-weight:600;color:#0a0b10;
  background:linear-gradient(135deg,var(--cyan),#7de8b8);padding:7px 22px;border-radius:999px}
/* 检查项 */
.checklist{display:flex;flex-direction:column;gap:9px}
.check{display:flex;gap:9px;align-items:flex-start;font-size:12.5px;line-height:1.5}
.check .ic{width:15px;height:15px;border-radius:50%;flex:0 0 auto;margin-top:2px;
  display:grid;place-items:center;font-size:9px;font-weight:700}
.check.ok .ic{background:rgba(74,222,128,.16);color:var(--green)}
.check.warn .ic{background:rgba(245,181,69,.16);color:var(--amber)}
.check.bad .ic{background:rgba(255,107,107,.16);color:var(--red)}
.check span{color:var(--muted)}
.check b{color:var(--text);font-weight:600}
/* 截图卡 */
.shots{display:grid;grid-template-columns:repeat(var(--cols,4),minmax(0,1fr));gap:14px}
.shot{position:relative;border-radius:13px;overflow:hidden;border:1px solid var(--line);
  background:#000;transition:.18s;cursor:zoom-in}
.shot:hover{transform:translateY(-3px);border-color:rgba(139,123,255,.45);
  box-shadow:0 16px 34px -16px rgba(139,123,255,.5)}
.shot img{width:100%;display:block;aspect-ratio:9/16;object-fit:cover}
.shot .ord{position:absolute;top:8px;left:8px;z-index:2;font-family:var(--mono);font-size:10px;
  background:rgba(0,0,0,.62);color:#fff;padding:2px 7px;border-radius:6px;
  backdrop-filter:blur(4px);border:1px solid rgba(255,255,255,.14)}
.shot .chips{position:absolute;left:0;right:0;top:0;padding:8px 9px 20px;display:flex;
  flex-wrap:wrap;gap:4px;justify-content:flex-end;
  background:linear-gradient(rgba(0,0,0,.80),transparent 62%)}
.shot .chips i{font-style:normal;font-family:var(--mono);font-size:9.5px;color:#c9cddd;
  background:rgba(255,255,255,.1);padding:1px 5px;border-radius:4px}
.shot .chips i.up{color:#ffd9a0;background:rgba(245,181,69,.22)}
.feature{border-radius:12px;overflow:hidden;border:1px solid var(--line);cursor:zoom-in;
  max-width:920px}
.feature img{width:100%;display:block;aspect-ratio:1024/500;object-fit:cover}
/* 文案 */
.field{padding:14px 0;border-top:1px dashed var(--line)}
.field:first-of-type{border-top:0;padding-top:0}
.field-head{display:flex;justify-content:space-between;align-items:baseline;gap:12px}
.field-head .k{font-size:12px;color:var(--muted);letter-spacing:.03em}
.field-head .n{font-family:var(--mono);font-size:11.5px;color:var(--dim)}
.field-head .n.over{color:var(--red)}
.field-head .n.full{color:var(--amber)}
.bar{height:3px;border-radius:99px;background:rgba(255,255,255,.07);margin:8px 0 11px;overflow:hidden}
.bar>i{display:block;height:100%;border-radius:99px;
  background:linear-gradient(90deg,var(--violet),var(--cyan));transition:width .3s}
.bar.over>i{background:var(--red)}
.field .txt{font-size:13px;line-height:1.72;color:#d7dae6;white-space:pre-wrap;
  word-break:break-word;max-width:86ch}
.field .txt.clamp{max-height:132px;overflow:hidden;
  mask-image:linear-gradient(#000 62%,transparent)}
.field .txt.clamp.open{max-height:none;mask-image:none}
.field .more{all:unset;cursor:pointer;font-size:11.5px;color:var(--violet);margin-top:8px;display:inline-block}
.field .base{font-size:11.5px;color:var(--dim);margin-top:8px;padding-left:10px;
  border-left:2px solid rgba(255,255,255,.1);line-height:1.6}
.field .base b{color:var(--amber);font-weight:500}
/* 提示 */
.note{display:flex;gap:9px;font-size:12.5px;color:var(--muted);padding:7px 0;line-height:1.55}
.note::before{content:"!";flex:0 0 auto;width:15px;height:15px;border-radius:50%;margin-top:2px;
  display:grid;place-items:center;font-size:9px;font-weight:700;
  background:rgba(245,181,69,.16);color:var(--amber)}
.foot{font-size:11px;color:#3f4453;text-align:center;padding-top:10px}
/* 灯箱 */
.lightbox{position:fixed;inset:0;z-index:50;display:none;place-items:center;
  background:rgba(6,7,11,.93);backdrop-filter:blur(6px);cursor:zoom-out;padding:32px}
.lightbox.on{display:grid}
.lightbox img{max-width:100%;max-height:100%;border-radius:8px;
  box-shadow:0 30px 80px -20px #000}
.lightbox .hint{position:fixed;bottom:18px;left:0;right:0;text-align:center;
  font-size:11px;color:var(--dim)}
@media(max-width:1080px){
  body{display:block}
  .side{position:static;width:auto;height:auto;flex-direction:row;flex-wrap:wrap;
    align-items:center;gap:10px;border-right:0;border-bottom:1px solid var(--line)}
  #nav{flex-direction:row;overflow-x:auto;flex:0 0 100%;order:3}
  .side-foot{display:none}
  main{padding:18px 16px 40px}
  .grid2{grid-template-columns:1fr}
  .shots{--cols:2 !important}
}
"""

_PREVIEW_JS = r"""
const D=DATA, $=s=>document.querySelector(s);
const esc=s=>String(s??"").replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const kb=n=>n>=1048576?(n/1048576).toFixed(1)+' MB':Math.round(n/1024)+' KB';
const len=s=>(s||'').length;
const LOCS=Object.keys(D.locales);

/* 单个语言的检查项：只列能自动判定的，不猜 */
function checks(L){
  const out=[];
  const n=L.shots.length;
  out.push(n>=2?{k:'ok',t:`截图数量 <b>${n}</b> 张，满足 Play 最少 2 张`}
               :{k:'bad',t:`截图只有 <b>${n}</b> 张，Play 要求至少 2 张`});
  const badRatio=L.shots.filter(s=>Math.abs(s.size[0]/s.size[1]-9/16)>0.005);
  out.push(badRatio.length?{k:'bad',t:`比例不是 9:16：${badRatio.map(s=>s.file).join('、')}`}
                          :{k:'ok',t:`全部 <b>9:16</b>，手机商店页无黑边`});
  const over=L.shots.filter(s=>s.bytes>8*1024*1024);
  out.push(over.length?{k:'bad',t:`超过 Play 单张 8MB：${over.map(s=>s.file).join('、')}`}
                      :{k:'ok',t:`单张最大 <b>${kb(Math.max(...L.shots.map(s=>s.bytes),0))}</b>，上限 8MB`});
  const up=L.shots.filter(s=>(s.upscale||1)>1.6);
  if(up.length) out.push({k:'warn',t:`<b>${up.length}</b> 张由低分辨率源放大（最高 ${Math.max(...up.map(s=>s.upscale)).toFixed(1)}×），真机会发糊`});
  out.push(L.feature?{k:'ok',t:`置顶图 <b>${L.feature.size[0]}×${L.feature.size[1]}</b>`}
                    :{k:'warn',t:'没有置顶图（featureGraphic），商店页首屏会空一块'});
  const lim=D.limits;
  ['title','shortDescription','fullDescription'].forEach(k=>{
    const v=L.copy[k]||'', n=len(v), mx=lim[k];
    if(!v) return out.push({k:'bad',t:`<b>${k}</b> 是空的`});
    out.push(n>mx?{k:'bad',t:`<b>${k}</b> ${n}/${mx}，超 ${n-mx} 个字符，Play 会直接拒`}
      :n>=mx?{k:'warn',t:`<b>${k}</b> ${n}/${mx} 顶格，加字必须先减字`}
      :{k:'ok',t:`<b>${k}</b> ${n}/${mx}，余 ${mx-n}`});
  });
  return out;
}
function statusOf(L){
  const cs=checks(L);
  return {bad:cs.filter(c=>c.k==='bad').length, warn:cs.filter(c=>c.k==='warn').length, cs};
}

function field(k,label,lim){
  const v=D.locales[ACT].copy[k]||'', n=len(v), p=Math.min(100,n/lim*100);
  const cls=n>lim?'over':(n>=lim?'full':'');
  const b=D.locales[ACT].base[k];
  let base='';
  if(b!==undefined && b!==v){
    const bn=len(b);
    base=`<div class="base">线上 A（${bn} 字）：${esc(b.length>240?b.slice(0,240)+'…':b)}</div>`;
  }
  const long=k==='fullDescription';
  return `<div class="field">
    <div class="field-head"><span class="k">${label}</span>
      <span class="n ${cls}">${n} / ${lim}</span></div>
    <div class="bar ${n>lim?'over':''}"><i style="width:${p}%"></i></div>
    <div class="txt ${long?'clamp':''}" id="t_${k}">${esc(v)||'<em style="color:#5f6478">（空）</em>'}</div>
    ${long&&n>260?`<button class="more" data-t="${k}">展开全文 ↓</button>`:''}
    ${base}</div>`;
}

function shotCard(s,i){
  const up=(s.upscale||1)>1.6;
  return `<div class="shot" data-src="${ACT}/${s.file}" title="${esc(s.file)}">
    <img src="${ACT}/${s.file}" alt="${esc(s.caption||s.file)}">
    <span class="ord">#${i+1}</span>
    <div class="chips"><i class="${up?'up':''}">${s.size[0]}×${s.size[1]}</i>
      <i class="${up?'up':''}">${kb(s.bytes)}</i>
      ${up?`<i class="up">放大 ${s.upscale}×</i>`:''}</div></div>`;
}

let ACT=(()=>{const h=(location.hash||'').replace('#','');return LOCS.includes(h)?h:LOCS[0];})();
function render(){
  const L=D.locales[ACT], st=statusOf(L);
  $('#nav').innerHTML=LOCS.map(l=>{
    const s=statusOf(D.locales[l]);
    const k=s.bad?'bad':(s.warn?'warn':'');
    return `<button data-loc="${l}" class="${l===ACT?'on':''}">
      <span class="dot ${s.bad?'warn':''}" style="${k==='bad'?'background:#ff6b6b':''}"></span>
      ${D.locales[l].label}<span class="code">${l}</span></button>`;}).join('');
  const tot=LOCS.reduce((a,l)=>{const s=statusOf(D.locales[l]);return {b:a.b+s.bad,w:a.w+s.warn};},{b:0,w:0});
  $('#health').innerHTML=`<span class="chip ${tot.b?'warn':'ok'}">问题 <b>${tot.b}</b></span>
    <span class="chip ${tot.w?'warn':''}">提醒 <b>${tot.w}</b></span>
    <span class="chip">语言 <b>${LOCS.length}</b></span>`;
  const nimg=L.shots.length+(L.feature?1:0);
  $('#topmeta').textContent=`${L.label} ${L.code} · ${nimg} 张图 · 画布 ${D.canvas[0]}×${D.canvas[1]} · 变体 ${D.variant}`;
  const first=L.shots[0];
  const html=`
  <div class="panel on">
    <div class="panel-head"><h2>${L.label}<span class="code">${L.code}</span></h2>
      <div class="health"><span class="chip ${st.bad?'warn':'ok'}">问题 <b>${st.bad}</b></span>
      <span class="chip ${st.warn?'warn':''}">提醒 <b>${st.warn}</b></span></div></div>

    <div class="grid2">
      <div class="card"><h3>Play 商店页 · 真机比例</h3>
        <div class="store-body">
          <div class="phone">${first?`<img src="${ACT}/${first.file}" alt="首图">`:''}</div>
          <div class="store-text">
            <div class="store-title">${esc(L.copy.title)||'—'}</div>
            <div class="store-dev">Warera · 策略</div>
            <div class="store-meta"><span>4.6 ★</span><span>1万+ 次下载</span><span>含广告</span></div>
            <div class="store-short">${esc(L.copy.shortDescription)}</div>
            <span class="store-btn">安装</span>
          </div>
        </div></div>
      <div class="card"><h3>合规检查</h3><div class="checklist">
        ${st.cs.map(c=>`<div class="check ${c.k}"><span class="ic">${c.k==='ok'?'✓':(c.k==='warn'?'!':'×')}</span><span>${c.t}</span></div>`).join('')}
      </div></div>
    </div>

    <div class="card"><h3>截图序列<span class="count">${L.shots.length} 张 · 按弹窗顺序</span></h3>
      <div class="shots" style="--cols:${Math.min(L.shots.length,5)||1}">${L.shots.map(shotCard).join('')||'<p class="sub">没有截图</p>'}</div></div>

    ${L.feature?`<div class="card"><h3>置顶图<span class="count">${L.feature.size[0]}×${L.feature.size[1]} · ${kb(L.feature.bytes)}</span></h3>
      <div class="feature" data-src="${ACT}/${L.feature.file}"><img src="${ACT}/${L.feature.file}" alt="置顶图"></div></div>`:''}

    <div class="card"><h3>商店文案<span class="count">Play 上限 30 / 80 / 4000</span></h3>
      ${field('title','标题',D.limits.title)}
      ${field('shortDescription','短描述',D.limits.shortDescription)}
      ${field('fullDescription','长描述',D.limits.fullDescription)}</div>

    ${L.notes.length?`<div class="card"><h3>本语言提醒</h3>
      ${L.notes.map(n=>`<div class="note"><span>${esc(n.replace(L.code+': ',''))}</span></div>`).join('')}</div>`:''}
  </div>`;
  $('#panels').innerHTML=html;
  bind();
}
function bind(){
  $('#nav').querySelectorAll('button').forEach(b=>b.onclick=()=>{
    ACT=b.dataset.loc;
    try{history.replaceState(null,'','#'+ACT)}catch(e){}
    render();});
  document.querySelectorAll('[data-src]').forEach(el=>el.onclick=()=>{
    $('#lightbox').querySelector('img').src=el.dataset.src; $('#lightbox').classList.add('on');});
  document.querySelectorAll('.more').forEach(b=>b.onclick=()=>{
    const t=document.getElementById('t_'+b.dataset.t); t.classList.toggle('open');
    b.textContent=t.classList.contains('open')?'收起 ↑':'展开全文 ↓';});
}
$('#lightbox').onclick=()=>$('#lightbox').classList.remove('on');
addEventListener('keydown',e=>{if(e.key==='Escape')$('#lightbox').classList.remove('on');});
render();
"""


# --------------------------------------------------------------------------- #
# check
# --------------------------------------------------------------------------- #
def cmd_check(args) -> int:
    root = C.DERIVED_DIR / args.variant
    if not root.is_dir():
        print(f"没有派生结果：{root}（先跑 build）")
        return 2
    red, yellow = [], []
    total = 0
    for d in sorted(p for p in root.iterdir() if p.is_dir()):
        if d.name not in C.LOCALES:      # heroes/ 是英雄卡，规格单独查
            continue
        files = sorted(d.glob("*.png"))
        if not files:
            red.append(f"{d.name}: 一张图都没有")
            continue
        shots = [f for f in files if f.name.startswith("shot_")]
        feats = [f for f in files if f.name.startswith("feature_")]
        if len(shots) < 4:
            red.append(f"{d.name}: 手机截图 {len(shots)} 张，Play 至少 4 张才建议上首屏（2 张是硬下限）")
        if len(shots) > 8:
            yellow.append(f"{d.name}: 截图 {len(shots)} 张，Play 上限 8 张")
        if not feats:
            yellow.append(f"{d.name}: 没有置顶大图（Play 要求 1024×500）")
        for f in files:
            total += 1
            with Image.open(f) as im:
                w, h = im.size
                if f in feats:
                    if (w, h) != C.FEATURE_SIZE:
                        red.append(f"{f.parent.name}/{f.name}: 置顶图 {w}×{h}，必须 1024×500")
                else:
                    if min(w, h) < 320 or max(w, h) > 3840:
                        red.append(f"{f.parent.name}/{f.name}: {w}×{h} 超出 Play 的长宽区间")
                    ratio = max(w, h) / min(w, h)
                    if ratio > 2.0:
                        red.append(f"{f.parent.name}/{f.name}: 长宽比 {ratio:.2f} > 2.0，Play 会拒")
                    if abs(ratio - 16 / 9) > 0.02 and abs(ratio - 9 / 16) > 0.02:
                        yellow.append(f"{f.parent.name}/{f.name}: 比例 {ratio:.2f} 非 16:9/9:16")
            if f.stat().st_size > PLAY_MAX_BYTES:
                red.append(f"{f.parent.name}/{f.name}: {f.stat().st_size // 1024 // 1024} MB > 8 MB")
    total += _check_heroes(root, red, yellow)
    print(f"[check] {total} 张图")
    for r in red:
        print(f"  🔴 {r}")
    for y in yellow:
        print(f"  🟡 {y}")
    if not red and not yellow:
        print("  ✅ 全部通过")
    if args.strict and red:
        return 1
    return 0 if not red else 1


# --------------------------------------------------------------------------- #
# 英雄档案卡：工程内立绘 → 店面同级版式
# --------------------------------------------------------------------------- #
def _radial_glow(size: tuple[int, int], center: tuple[float, float],
                 radius: float, color: tuple, alpha: int) -> Image.Image:
    """低分辨率画椭圆再放大模糊：全尺寸高斯在这个尺寸上会慢到不可用。"""
    w, h = size
    sw, sh = max(2, w // 4), max(2, h // 4)
    g = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    cx, cy, r = center[0] / 4, center[1] / 4, max(2.0, radius / 4)
    ImageDraw.Draw(g).ellipse([cx - r, cy - r, cx + r, cy + r], fill=tuple(color) + (alpha,))
    g = g.filter(ImageFilter.GaussianBlur(max(4, r * 0.55)))
    return g.resize((w, h), Image.BICUBIC)


def _vgrad_mask(size: tuple[int, int], y0: float, y1: float, gamma: float = 1.0) -> Image.Image:
    """竖向渐变遮罩：y0 处 0（黑），y1 处 255（白），中间按 gamma 曲线过渡。

    用来做「底部柔化/压深」，代替过去那段 for 循环逐行画线——逐行画出来的
    其实是同一条 alpha 曲线，但只压深不模糊，模型画的**硬横边**会原样留着。
    """
    tw, th = size
    col = Image.new("L", (1, th))
    px = col.load()
    span = max(1e-6, y1 - y0)
    for y in range(th):
        t = (y / max(1, th - 1) - y0) / span
        t = 0.0 if t < 0 else (1.0 if t > 1 else t)
        px[0, y] = int(round((t ** gamma) * 255))
    return col.resize((tw, th), Image.BILINEAR)


def _soft_bottom(im: Image.Image, blur_ratio: float = 0.018,
                 blur_from: float = 0.58, blur_to: float = 0.84,
                 dark_from: float = 0.60, dark_to: float = 1.0,
                 dark_max: int = 214, gamma: float = 1.32) -> Image.Image:
    """底部「先柔化再压深」。

    🔴 只压深不模糊 = 硬横边原样保留。02 那张就是这样：模型把留给文案的底带
    直接画成纯黑，接缝处一行亮度差 13 级，缩略图里看着像一条被裁断的黑条。
    这里先用渐进高斯把那条边糊开（越靠下越糊），再叠一层长渐变 scrim 压深，
    白字才立得住，观感也从「硬接缝」变成「画面自然沉下去」。
    """
    tw, th = im.size
    r = max(2, int(tw * blur_ratio))
    soft = im.filter(ImageFilter.GaussianBlur(r))
    im = Image.composite(soft, im, _vgrad_mask((tw, th), blur_from, blur_to, 1.0))
    dark_col = Image.new("RGB", (tw, th), (9, 8, 15))
    mask = _vgrad_mask((tw, th), dark_from, dark_to, gamma)
    if dark_max < 255:
        mask = mask.point(lambda v: int(v * dark_max / 255))
    return Image.composite(dark_col, im, mask)


def _draw_caption_land(canvas: Image.Image, caption: str, kicker: str,
                       locale: str, tint: tuple) -> None:
    """横版文案：压在**左侧空柱**里（左对齐、上细线 + 小标 + 两行口号）。

    和竖版区别：竖版是「居中 + 底部」，横版左侧只有约 40% 宽度可用，
    所以字号要按列宽自动降，不能沿用竖向的基准。
    """
    W, H = canvas.size
    SS = 2
    big = canvas.resize((W * SS, H * SS), Image.LANCZOS)
    d = ImageDraw.Draw(big)

    mx = int(W * 0.052) * SS
    max_w = int(W * 0.40) * SS
    lines = _parse_marked(caption)

    size = int(W * 0.080)
    lo = int(W * 0.034)
    while size > lo:
        f, _ = _font_hero(locale, size * SS)
        widest = max(sum(d.textlength(ch, font=f) for ch, _ in ln) for ln in lines)
        if widest <= max_w:
            break
        size -= 2
    f_head, _ = _font_hero(locale, size * SS)

    kick_sz = int(W * 0.0195) * SS
    f_kick, _ = font_for(locale, kick_sz)

    line_h = int(size * 1.20) * SS
    gap = int(size * 0.42) * SS
    block_h = gap + kick_sz + int(size * 0.30) * SS + len(lines) * line_h
    bottom = int(H * 0.815) * SS       # 让文案块在左侧空柱里居中，而不是坠到底
    top = bottom - block_h

    # 细渐变线（品红→青），当品牌印记
    rule_w = int(W * 0.052) * SS
    for i in range(rule_w):
        t = i / max(1, rule_w - 1)
        c = tuple(int(BRAND_PINK[k] + (BRAND_CYAN[k] - BRAND_PINK[k]) * t) for k in range(3))
        d.rectangle([mx + i, top, mx + i, top + max(2, SS * 2)], fill=c)

    y = top + gap
    if kicker:
        x = mx
        for ch in kicker:
            d.text((x, y), ch, font=f_kick, fill=(228, 232, 240))
            x += int(f_kick.size * (1.06 if ord(ch) > 0x2E80 else 1.0) * 0.98)
        y += kick_sz + int(size * 0.30) * SS

    for ln in lines:
        _draw_rich(d, (mx, y), ln, f_head, (255, 255, 255), accent=tint,
                   shadow=(0, 0, 0), compress_punct=True)
        y += line_h

    canvas.paste(big.resize((W, H), Image.LANCZOS), (0, 0))


def _land_from_portrait(src: Image.Image, tw: int, th: int) -> Image.Image:
    """竖版底图 → 横版画布（**零额度**兜底）。

    直接裁 16:9 会把腿和武器全切掉，所以只能「延展」。做法：
    主角整幅顶满高度贴右，左边空出来的地方用**主角左缘像素横向拉伸 + 重模糊**铺满。
    关键在「取边界像素」——这样两侧在接缝处的颜色天然连续，
    不会出现一个矩形贴片那种竖直硬边（第一版就是简单贴个模糊底图，缝一眼就能看见）。
    """
    # 竖版底图底部 20% 是「留给文案的暗带」，横过来会变成一条突兀的水平黑边 ⇒ 先切掉。
    # 脚在 74% 高，切到 80% 不会碰到底盘。
    src = src.crop((0, 0, src.width, max(1, int(src.height * 0.80))))

    fw = max(1, int(round(src.width * th / src.height)))
    fg = src.resize((fw, th), Image.LANCZOS).convert("RGB")
    left_w = max(0, tw - fw)

    canvas = Image.new("RGB", (tw, th), (8, 8, 14))
    if left_w:
        col_w = max(2, fw // 60)
        edge = fg.crop((0, 0, col_w, th)).resize((left_w + col_w, th), Image.LANCZOS)
        edge = edge.filter(ImageFilter.GaussianBlur(max(8, left_w / 9)))
        edge = Image.eval(edge, lambda v: int(v * 0.70))
        canvas.paste(edge.crop((0, 0, left_w, th)), (0, 0))

    canvas.paste(fg, (left_w, 0))

    # 交界再糊一道窄带，把可能残留的一像素色差吃掉
    band = max(16, min(120, fw // 12))
    if left_w:
        seam = canvas.crop((left_w - band, 0, left_w + band, th))
        seam = seam.filter(ImageFilter.GaussianBlur(band / 3.2))
        mask = Image.new("L", (band * 2, th), 0)
        md = ImageDraw.Draw(mask)
        for i in range(band * 2):
            k = 1.0 - abs(i - band) / band
            md.line([(i, 0), (i, th)], fill=int(255 * max(0.0, k)))
        canvas.paste(seam, (left_w - band, 0), mask)
    return canvas


def compose_hero_land(card: dict, size: tuple[int, int], caption: str,
                      kicker: str, locale: str) -> Image.Image | None:
    """横版英雄图（1920×1080）：AI 底图铺满 + 左侧压暗成干净空柱 + 左对齐文案。

    优先用**管线原生横版**（gen/land/herocard_<id>.png，构图是另画的）；
    额度不够时退回竖版底图延展（_land_from_portrait），画质略降但版式一致。
    """
    tw, th = size
    tint = tuple(card.get("tint") or BRAND_PINK)
    gen = GEN_DIR / "land" / f"herocard_{card['id']}.png"
    port = GEN_DIR / f"herocard_{card['id']}.png"
    if gen.is_file():
        canvas = cover_resize(Image.open(gen).convert("RGB"), (tw, th), 0.55)
    elif port.is_file():
        canvas = _land_from_portrait(Image.open(port).convert("RGB"), tw, th)
    else:
        return None

    # 左侧空柱：横向 smoothstep 压暗（右缘柔过渡，不留一刀切的黑边）
    xs = np.linspace(0.0, 1.0, tw, dtype=np.float32)[None, :]
    t = np.clip((xs - 0.30) / (0.58 - 0.30), 0.0, 1.0)
    a = (1.0 - (t * t * (3 - 2 * t))) * 228.0
    alpha = np.repeat(a, th, axis=0)
    scrim = Image.fromarray(
        np.dstack([np.full((th, tw), 8, np.uint8),
                   np.full((th, tw), 8, np.uint8),
                   np.full((th, tw), 14, np.uint8),
                   alpha.clip(0, 255).astype(np.uint8)])
    )
    canvas = Image.alpha_composite(canvas.convert("RGBA"), scrim).convert("RGB")
    _draw_caption_land(canvas, caption, kicker, locale, tint)
    return canvas


def compose_hero(art_path: Path, card: dict, size: tuple[int, int], caption: str,
                 kicker: str, locale: str) -> Image.Image:
    """英雄卡：有换皮成品就用成品铺满（AI 画了环境），没有就退回工程立绘 + 品牌底图。"""
    tw, th = size
    tint = tuple(card.get("tint") or BRAND_PINK)
    gen = GEN_DIR / f"herocard_{card['id']}.png"

    if gen.is_file():
        canvas = cover_resize(Image.open(gen).convert("RGB"), (tw, th), 0.5)
        # 文案区先柔化再压深：白字才立得住，接缝也不会留成一条硬边
        canvas = _soft_bottom(canvas)
    else:
        canvas = _brand_backdrop((tw, th)).convert("RGBA")
        art = Image.open(art_path).convert("RGBA")
        bb = art.getchannel("A").getbbox()
        if bb:
            art = art.crop(bb)      # 2048 画布里角色只占中间一块，先按 alpha 收紧
        base_y = int(th * 0.745)
        target_h = base_y - int(th * 0.052)
        k = target_h / art.height
        if art.width * k > tw * 1.30:
            k = (tw * 1.30) / art.width
        art = art.resize((max(1, int(art.width * k)), max(1, int(art.height * k))),
                         Image.LANCZOS)
        x = (tw - art.width) // 2
        y = base_y - art.height
        canvas.alpha_composite(_radial_glow((tw, th), (tw * 0.5, y + art.height * 0.42),
                                            tw * 0.62, tint, 96))
        canvas.alpha_composite(_radial_glow((tw, th), (tw * 0.5, base_y + int(tw * 0.01)),
                                            tw * 0.40, tint, 70))
        feet = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
        ImageDraw.Draw(feet).ellipse([tw * 0.20, base_y - int(tw * 0.030),
                                      tw * 0.80, base_y + int(tw * 0.060)],
                                     fill=(0, 0, 0, 175))
        canvas.alpha_composite(feet.filter(ImageFilter.GaussianBlur(int(tw * 0.034))))
        canvas.alpha_composite(art, (x, y))
        canvas = canvas.convert("RGB")

    lab = Image.new("RGBA", (tw * 2, int(th * 0.06) * 2), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lab)
    f, _ = font_for(locale, int(tw * 0.024) * 2)
    _draw_tracked(ld, (int(tw * 0.055) * 2, 0), f"FILE {card.get('id', '')}",
                  f, BRAND_CYAN + (232,), tracking=int(tw * 0.004) * 2)
    canvas = canvas.convert("RGBA")
    canvas.alpha_composite(lab.resize((tw, int(th * 0.06)), Image.LANCZOS), (0, int(th * 0.042)))

    out = canvas.convert("RGB")
    _draw_caption(out, int(th * 0.775), th - int(th * 0.775), tw, caption, kicker,
                  locale, tint=tint, heavy=True)
    return out


def cmd_heroes(args) -> int:
    spec = C.load_json(C.ASSETS_DIR / "heroes.json")
    locales = C.parse_locales(args.locales)
    land = getattr(args, "orient", "port") == "land"
    tw, th = _parse_size(args.size)
    if land and (tw, th) == (1080, 1920):      # 没显式给尺寸就走横版默认
        tw, th = 1920, 1080
    out_root = C.DERIVED_DIR / args.variant / ("heroes_land" if land else "heroes")
    only = {s.strip() for s in (getattr(args, "ids", "") or "").split(",") if s.strip()}
    n = 0
    for loc in locales:
        d = out_root / loc
        d.mkdir(parents=True, exist_ok=True)
        for h in spec.get("heroes", []):
            if only and h["id"] not in only:
                continue
            cap = (h.get("headlines") or {}).get(loc) or ""
            if loc.startswith("en"):
                cap = cap.upper()
            kick = (h.get("kickers") or {}).get(loc) or ""
            if not cap:
                continue
            if land:
                im = compose_hero_land(h, (tw, th), cap, kick, loc)
                if im is None:
                    print(f"缺横版底图：data_aso/assets/gen/land/herocard_{h['id']}.png")
                    continue
            else:
                src = C.ROOT / h["art"]
                if not src.is_file():
                    print(f"缺图：{h['art']}")
                    continue
                im = compose_hero(src, h, (tw, th), cap, kick, loc)
            fn = d / f"hero_{h['id']}.png"
            im.save(fn, "PNG", optimize=True)
            n += 1
            if land and getattr(args, "feature", False):
                # 置顶图固定 1024×500（2.048:1）。从 16:9 上下各裁一点即可，
                # 别从左右裁 —— 左边是文案区，裁掉就没字了。
                fw, fh = 1024, 500
                im2 = im
                want = fw / fh
                if im2.width / im2.height > want:
                    nw = int(im2.height * want)
                    im2 = im2.crop(((im2.width - nw) // 2, 0, (im2.width + nw) // 2, im2.height))
                else:
                    nh = int(im2.width / want)
                    im2 = im2.crop((0, (im2.height - nh) // 2, im2.width, (im2.height + nh) // 2))
                fd = C.DERIVED_DIR / args.variant / "heroes_feature" / loc
                fd.mkdir(parents=True, exist_ok=True)
                im2.resize((fw, fh), Image.LANCZOS).save(fd / f"hero_{h['id']}.png",
                                                         "PNG", optimize=True)
        print(f"  {loc}: {len(list(d.glob('hero_*.png')))} 张")
    print(f"[heroes] {out_root}  {n} 张  ({tw}x{th})")
    return 0


def _check_heroes(root: Path, red: list, yellow: list) -> int:
    """竖版 heroes/ 与横版 heroes_land/ 都查；两者长宽比都是 16:9，只是方向不同。"""
    total = 0
    for name, label in (("heroes", "9:16"), ("heroes_land", "16:9")):
        d = root / name
        if not d.is_dir():
            continue
        for sub in sorted(p for p in d.iterdir() if p.is_dir()):
            for f in sorted(sub.glob("hero_*.png")):
                total += 1
                with Image.open(f) as im:
                    w, h = im.size
                ratio = max(w, h) / min(w, h)
                if abs(ratio - 16 / 9) > 0.02:
                    red.append(f"{name}/{sub.name}/{f.name}: 比例 {ratio:.3f}，必须 {label}")
                if name == "heroes_land" and w < h:
                    red.append(f"{name}/{sub.name}/{f.name}: 横版目录里放的是竖图 {w}x{h}")
                if f.stat().st_size > PLAY_MAX_BYTES:
                    red.append(f"{name}/{sub.name}/{f.name}: {f.stat().st_size//1024}KB 超过 8MB")
    if not total:
        yellow.append("heroes/: 没有英雄卡（先跑 heroes）")

    # 横版顺带导出的置顶图：Play 要求**精确** 1024×500，差一个像素都会被拒
    fd = root / "heroes_feature"
    if fd.is_dir():
        for sub in sorted(p for p in fd.iterdir() if p.is_dir()):
            for f in sorted(sub.glob("hero_*.png")):
                total += 1
                with Image.open(f) as im:
                    w, h = im.size
                if (w, h) != (1024, 500):
                    red.append(f"heroes_feature/{sub.name}/{f.name}: {w}x{h}，置顶图必须 1024x500")
                if f.stat().st_size > PLAY_MAX_BYTES:
                    red.append(f"heroes_feature/{sub.name}/{f.name}: {f.stat().st_size//1024}KB 超过 8MB")
    return total


def main() -> int:
    ap = argparse.ArgumentParser(description="店面素材派生与体检")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("fetch", help="下载线上原图当基线")
    p.add_argument("--locales", default="")
    p.add_argument("--online-dir", default="")
    p.set_defaults(func=cmd_fetch)

    p = sub.add_parser("build", help="派生竖版截图与置顶图")
    p.add_argument("--variant", required=True)
    p.add_argument("--locales", default="")
    p.add_argument("--size", default="1080x1920")
    p.add_argument("--feature-size", default="1024x500")
    p.add_argument("--fit", choices=["cover", "pad"], default="cover",
                   help="cover=铺满裁切（默认）；pad=整图装入+模糊补边")
    p.add_argument("--no-caption", action="store_true")
    p.set_defaults(func=cmd_build)

    p = sub.add_parser("heroes", help="工程内英雄立绘 → 店面档案卡")
    p.add_argument("--variant", required=True)
    p.add_argument("--locales", default="")
    p.add_argument("--ids", default="", help="只做这几张（逗号分隔）；留空=heroes.json 里全部")
    p.add_argument("--orient", choices=["port", "land"], default="port",
                   help="port=1080x1920 竖版（底部文案）；land=1920x1080 横版（左侧文案，对齐现网）")
    p.add_argument("--feature", action="store_true",
                   help="横版时顺带导出 1024x500 置顶图（Play 固定尺寸）")
    p.add_argument("--size", default="1080x1920")
    p.set_defaults(func=cmd_heroes)

    p = sub.add_parser("check", help="Play 规格体检")
    p.add_argument("--variant", required=True)
    p.add_argument("--strict", action="store_true")
    p.set_defaults(func=cmd_check)

    p = sub.add_parser("headline", help="在生成图上压本地化标题（改文案不重出图）")
    p.add_argument("--art", required=True, help="AI 出的无字底图")
    p.add_argument("--locale", required=True)
    p.add_argument("--kind", choices=["hero", "feature"], default="hero")
    p.add_argument("--out", default="")
    p.set_defaults(func=cmd_headline)

    p = sub.add_parser("preview", help="只看预览（不重建）")
    p.add_argument("--variant", required=True)
    p.set_defaults(func=lambda a: (print(C.DERIVED_DIR / a.variant / "preview.html"), 0)[1])

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
