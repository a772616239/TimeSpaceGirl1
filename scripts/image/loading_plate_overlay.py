#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""LoadingPanel 角色图「铭牌贴片（nameplate overlay）」多语言管线。

背景
----
`Atlas/LoginPanelAtlas/cn2-X1_loading_01..09_zh.png` 是 9 张 684×2048 的登录角色图，
图上的「定位标签 + 角色台词」是**烘进图里的中文美术字**：

    大号中文名（艺术字）  +  小号英文名（本来就在图上）
    朱红斜条：定位标签（物理输出 · 群伤减益）
    斜条下方：台词（我会成为众人眼中的明星。）

按老办法要给每个语言重出一张 684×2048 ≈1.6MB 的大图，9 张 × 4 语言 ≈ 57MB，
而**底图里 96% 的像素（角色立绘/建筑/霓虹）跟语言完全无关**。

做法
----
底图只留一份（中文原图，零改动）；每个语言只出一张**覆盖中文文案区的小贴片**：

    LoadingPanel 的 pic(底图)  +  [lang] 铭牌贴片（≈290×110，几十 KB）

贴片自己带「补好的背景 + 译文」，只有被擦过的像素那几条带子是 opaque 的，
其余全透明 —— 叠上去除了字换了语言，看不出任何接缝。

三个环节
--------
1. **只擦字，不重绘红条**。红条是纯朱红平行四边形（实测高 44px、倾角 14.9°），
   它本身跟语言无关，原样保留，连右端那三条装饰斜线和红色引号都不碰。
2. **两处原地补**：
   - 红条内：把「偏离红条中位色 > 70」的像素（中文白字 + 深色描边 + 投影）整片用红条
     中位色填掉。**不能用 inpaint** —— 红条左端只有 10px 余量，半径 6 的 inpaint 会把
     条外背景渗进来，红条左端被"洗白"。
   - 台词带：整条重建成「红条色 → 带外 3px 真实背景」的线性过渡。**不能只擦白字** ——
     中文台词是白字 + 深色描边，只抓白会留下一圈深影；也**不能整带垂直插值** ——
     带子上沿紧贴红条，取不到干净背景参考，会把红条高光拉进来、发红发亮还带竖条纹。
3. **排字**：标签用 Arial Bold 白字（红底），台词用深棕字 + 1px 浅米描边（亮底），
   按实测倾角跟随斜排；超宽自动降字号（`fit_font`）。

🔴 **贴片 bbox 由「实际墨迹」反推，不由版面几何推**。斜排 15° + 纵向拉伸之后，大字
   的左上角会跑到 `name_box` 的左外侧（h/2·sinθ）和上外侧（w·sinθ + h/2·cosθ）——
   按 `name_box` / 红条几何算出来的贴片会把这两块裁掉，表现就是预览里字母顶一道
   齐刷刷的直线（05 的 BRUTUS 曾切掉顶部 46px、左边 16px，03 切 26px、07 切 41px）。
   现在的口径：
   - 贴片 = 红条 ∪ 台词带 ∪ `name_box` ∪ `small_box` ∪ 擦除区 ∪ 三条线的墨迹，再外扩
     `PLATE_PAD`，并夹在 684×2048 内；
   - 大字另外受 `NAME_HEADROOM`（名字区上沿 = `name_box` 顶 - 92）约束，超出就降字号，
     保证英文大字不会顶到画板上沿；
   - `geom.json` 里的 `ink_clip_px` = 墨迹被画板边界削掉的像素，`verify` 会卡它必须为 0。

🔴 中文名不翻、也不覆盖：九张图里中文名旁边本来就挂着英文名（Caesar / GuanYu /
   Mozart …），盖掉中文名反而丢了设计层级。贴片只碰红条与台词两行。

🔴 版面参数逐张登记（`DEFAULT_LAYOUT` / `loading_plate_layout.json`）。九张图的背景色、
   红条长度都不一样，**自动检测在这批图上是不可靠的**（试过严格红阈值、宽松红阈值、
   白字连通域三种口径，都会在别的图上抓错块），所以改成实测后写死。`measure` 子命令
   负责实测单张，把输出贴进 layout json 即可。

用法
----
    python scripts/image/loading_plate_overlay.py scan
    python scripts/image/loading_plate_overlay.py measure --asset cn2-X1_loading_04_zh
    python scripts/image/loading_plate_overlay.py run --asset cn2-X1_loading_04_zh --lang en
    python scripts/image/loading_plate_overlay.py verify --asset cn2-X1_loading_04_zh --lang en
    python scripts/image/loading_plate_overlay.py publish --asset cn2-X1_loading_04_zh --lang en

`publish` 做三件事（幂等，可重复跑）：
    1. 贴片落 `Atlas/LoginPanelAtlas/<asset>_plate_<lang>.png` + 同族 `.meta`（换新 guid）
    2. 在 `ResourcePathConfig.asset` 的 `resInfoList` 末尾追加登记（复用同目录的
       resPathIndex / resAbNameIndex，**不动** resPathList / resAbNameList / assetBundleList）
    3. 把归一化 anchor 写进 `~Lua/Modules/Message/LoadingPlateGeom.lua`
🔴 写回 ≠ 进包：真机生效还要重打 LoginPanelAtlas 所在 AssetBundle。

产物（`_output/art_translate_loading/<asset>/`）：
    overlay_<lang>.png   贴片本体（RGBA）
    preview_<lang>.png   底图 + 贴片合成预览（肉眼验收）
    mask_<lang>.png      擦除区可视化（验收）
    geom.json            贴片在底图中的归一化位置（给 prefab 的 anchor 用）

退出码：0 全通过；3 有需人看一眼的项（缺译名）；1 硬失败。
"""
from __future__ import annotations

import argparse
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

SRC_DIR = os.path.join(ROOT, "Assets/ManagedResources/Atlas/LoginPanelAtlas")
OUT_ROOT = os.path.join(ROOT, "_output/art_translate_loading")
MAP_PATH = os.path.join(HERE, "loading_plate_map.json")

# 标签行/台词行用窄体：英文比中文长一倍（「物理输出 · 沉默爆发」9 字 vs
# "PHYSICAL · SILENCE & BURST DAMAGE" 31 字符），红条可用宽度是死的，用正体 fit 下来
# 字号只有 13px、贴在 44px 高的条子里明显偏空。Arial Narrow Bold 同宽能大 ~18%。
FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/Library/Fonts/Arial Bold.ttf",
]

# 大号角色名用超粗压缩体：中文原名是方正超粗黑（2 个字就占 157×125），
# 英文 6~9 个字母要用同样宽度放下，只能用 Impact 这类压缩体，否则要么字高砍半、要么窜出画板。
NAME_FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Impact.ttf",
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf",
]

FEATHER = 10          # 贴片 alpha 羽化宽度
# 译文可能存在的语言。贴片 bbox 要对**这几种取并集**：`LoadingPlateGeom.lua` 一张图
# 只存一组 anchor，运行时按图号取（见 LoadingPanel.ApplyLangPlate），没有按语言分表 ——
# 贴片 bbox 一旦随译文长度变，换语言就整体错位/被裁。
LANGS = ("en", "jp", "kr")
BAR_PAD = 6           # 红条内擦字范围外扩（把描边/发光一起吞掉）
BAND_TOP_INSET = 7    # 台词带的上沿往红条里吃的像素数：中文台词的句号比带子上沿还高
NAME_BLEED = 17       # 大字擦除外扩：白描边 ≈8px + 青/品红错位 ≈6px + 抗锯齿
NAME_HEADROOM = 92    # 名字区上沿到 name_box 顶边的余量：斜排大字越宽抬得越高，这条是硬上限
NAME_LIFT = 14        # 英文大字整体上移，躲开斜条右端（斜条右端比左端高 100+px）
PLATE_PAD = 6         # 贴片边界相对「几何区 ∪ 墨迹」再外扩的像素，别让字贴着裁切线
QUOTE_LIFT = 7        # 台词行整体上移的像素（包裹模式下离条芯下缘的微调）

# 实测版面（cn2-X1_loading_04_zh，684×2048）。红条是平行四边形：
#   上边线 y = top_y_at_x_left + slope*(x - x_left)，高恒为 bar_h。
DEFAULT_LAYOUT = {
    "x_left": 222,
    "x_right": 500,
    "top_y_at_x_left": 316.8,
    "slope": -0.2667,      # dy/dx → 倾角 14.93°
    "bar_h": 44.0,
    "quote_x_left": 214,
    "quote_x_right": 577,   # 台词右端到「。」为止（x≈575）；再往右是设计好的红色引号，留着
    "quote_h": 50.0,       # 红条下边线往下的台词带高度

    # 大号角色名（含右侧本来就在图上的小号英文名）的覆盖区，**逐张实测**（九张的
    # 字数不同、大字基线高低差 80px，红条更是各有各的颜色，没有任何一种自动检测
    # 能同时在这些漫画网点背景上稳定圈字 —— 宽/高、明/暗、局部中位色偏差三种口径全试过）。
    #   name_box = 中文大字的外接框（`loading_plate_layout.json` 逐张覆盖）
    #   small_box 由 derive_small_box() 按大字推出来，**这里绝不能给默认值** ——
    #   留了 04 的默认框会让九张共用凯撒的坐标，小字整词漏擦。
    "name_box": [227, 162, 408, 278],
    "name_stretch": 1.2,                # 英文字纵向拉伸，补中英文的字高差（见 name_layer 注释）
    "name_fill": [89, 25, 0],           # 字芯 RGB（原字采样）
    "name_stroke": [250, 250, 250],     # 白描边 RGB
    "name_stroke_w": 4,
    "name_glitch": [[21, 250, 249], [221, 92, 70]],   # 青 / 品红错位层 RGB
    "name_angle": None,                 # None = 沿用红条倾角
}


# --------------------------------------------------------------------------- #
# 基础
# --------------------------------------------------------------------------- #
def read_bgr(path: str) -> np.ndarray:
    img = cv2.imdecode(np.fromfile(path, dtype=np.uint8), cv2.IMREAD_COLOR)
    if img is None:
        raise SystemExit(f"读不了图：{path}")
    return img


def load_map() -> dict:
    if not os.path.exists(MAP_PATH):
        return {}
    with open(MAP_PATH, encoding="utf-8") as f:
        return json.load(f)


def layout_for(asset: str) -> dict:
    """取某张图的版面参数：DEFAULT_LAYOUT 打底，`loading_plate_layout.json` 逐张覆盖。"""
    lay_path = os.path.join(HERE, "loading_plate_layout.json")
    overrides = json.load(open(lay_path, encoding="utf-8")) if os.path.exists(lay_path) else {}
    layout = dict(DEFAULT_LAYOUT)
    layout.update(overrides.get(asset, {}))
    return layout


def top_y(layout: dict, x: float) -> float:
    return layout["top_y_at_x_left"] + layout["slope"] * (x - layout["x_left"])


def bot_y(layout: dict, x: float) -> float:
    return top_y(layout, x) + layout["bar_h"]


def poly_bar(layout: dict, pad: float = BAR_PAD) -> np.ndarray:
    x0 = layout["x_left"] - pad
    x1 = layout["x_right"] + pad
    return np.array([
        [x0, top_y(layout, x0) - pad],
        [x1, top_y(layout, x1) - pad],
        [x1, bot_y(layout, x1) + pad],
        [x0, bot_y(layout, x0) + pad],
    ], dtype=np.float32)


def poly_quote(layout: dict, pad: float = 4) -> np.ndarray:
    x0 = layout["quote_x_left"] - pad
    x1 = layout["quote_x_right"] + pad
    return np.array([
        [x0, bot_y(layout, x0)],
        [x1, bot_y(layout, x1)],
        [x1, bot_y(layout, x1) + layout["quote_h"] + pad],
        [x0, bot_y(layout, x0) + layout["quote_h"] + pad],
    ], dtype=np.float32)


# --------------------------------------------------------------------------- #
# 填充
# --------------------------------------------------------------------------- #
def fill_quote_band(img: np.ndarray, layout: dict, bar_color: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """把台词带整条重建成「红条下边缘 → 背景」的过渡。

    为什么不能只擦白字：中文台词是**白字 + 深色描边**，只抓 mn>130 的白会把描边整圈留下
    （实测右端「明星。」只剩一圈深影）。为什么不能直接垂直插值：带子上沿紧贴红条，
    取不到干净背景参考，会把红条高光拉进来发红发亮、还带竖条纹。

    所以带子两端各给一个**已知**参考：上沿 = 红条自身的颜色，下沿 = 带外 3px 的真实背景，
    中间线性过渡。红条下边缘本来就是「红 → 背景」的过渡，这样重建出来没有接缝。
    """
    H, W = img.shape[:2]
    out = img.astype(np.float32).copy()
    qh = int(round(layout["quote_h"]))
    xs = np.arange(max(0, int(layout["quote_x_left"])), min(W, int(layout["quote_x_right"])))
    if xs.size == 0:
        return img, np.zeros((H, W), np.uint8)

    y0 = np.clip(np.round(bot_y(layout, xs) - BAND_TOP_INSET).astype(int), 0, H - 1)
    y1 = np.clip(np.round(bot_y(layout, xs) + qh).astype(int), 0, H - 1)
    yref = np.clip(y1 + 3, 0, H - 1)

    c0 = np.broadcast_to(bar_color.astype(np.float32), (xs.size, 3))
    c1 = img[yref, xs].astype(np.float32)
    span = np.maximum((y1 - y0).astype(np.float32), 1)

    mask = np.zeros((H, W), np.uint8)
    for r in range(qh + BAND_TOP_INSET + 1):
        ys = y0 + r
        ok = (ys <= y1) & (ys < H)
        if not ok.any():
            continue
        t = np.clip(r / span, 0, 1)[:, None]
        out[ys[ok], xs[ok]] = c0[ok] * (1 - t[ok]) + c1[ok] * t[ok]
        mask[ys[ok], xs[ok]] = 255
    return np.clip(out, 0, 255).astype(np.uint8), mask


# --------------------------------------------------------------------------- #
# 排字
# --------------------------------------------------------------------------- #
def load_font(size: int):
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def load_name_font(size: int):
    for p in NAME_FONT_CANDIDATES:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return load_font(size)


def text_size(font, s: str):
    box = font.getbbox(s)
    return box[2] - box[0], box[3] - box[1]


def fit_font(text: str, max_w: int, max_h: int, start: int, loader=load_font):
    size = max(9, start)
    while size > 8:
        f = loader(size)
        w, h = text_size(f, text)
        if w <= max_w and h <= max_h:
            return f
        size -= 1
    return loader(9)


def text_layer(text: str, font, fill=(255, 255, 255, 255), stroke=2,
               stroke_fill=(110, 16, 8, 255)):
    w, h = text_size(font, text)
    pad = stroke + 3
    layer = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((pad, pad), text, font=font, fill=fill,
           stroke_width=stroke, stroke_fill=stroke_fill)
    return layer


def line_layer(text: str, font, fill=(255, 255, 255, 255), stroke=2,
               stroke_fill=(110, 16, 8, 255)):
    """单行文字图层，返回 (图层, 墨迹 alpha 外接框, 墨迹中心)。

    🔴 回传**墨迹真实 bbox** 而不是图层尺寸：图层左右各留了 `stroke+4` 的空白，
       直接拿图层宽度做对齐会让每一行整体偏左/偏右 4~6px，且描边宽度一变就跟着变。
    🔴 用 `anchor="lm"` 画 + 按 bbox 对齐，而不是老写法 `rotate(expand=True)` 后按
       外接框中心对齐：斜排时外接框的空白边会被当成内容，实测整体下漂 20~30px，
       标签直接压到条外面。
    """
    asc, desc = font.getmetrics()
    pad = stroke + 4
    probe = Image.new("RGBA", (10, 10))
    d0 = ImageDraw.Draw(probe)
    bbox = d0.textbbox((0, 0), text, font=font, anchor="lm", stroke_width=stroke)
    lw = int(bbox[2] - bbox[0]) + pad * 2 + 2
    lh = int(max(asc + desc, bbox[3] - bbox[1])) + pad * 2 + 2
    layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((pad - bbox[0], lh / 2), text, font=font, anchor="lm", fill=fill,
           stroke_width=stroke, stroke_fill=stroke_fill)
    bb = layer.split()[3].getbbox() or (0, 0, lw, lh)
    return layer, bb, ((bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2)


def layer_ink_quad(lay: Image.Image, anchor, ang: float, target) -> np.ndarray:
    """图层**墨迹**四角经「绕 anchor 旋转 + 平移」后在底图坐标系里的位置。

    用来反推贴片 bbox。🔴 必须用墨迹 bbox（alpha 外接框），不能用图层尺寸：
       图层四周有 stroke+14 的透明留白，按图层算会把贴片撑大 30~40px，
       而按几何（name_box / 红条）算又会把斜排溢出的那截字裁掉 —— 两头都不对。
    """
    bb = lay.split()[3].getbbox() or (0, 0, lay.width, lay.height)
    corners = np.array([[bb[0], bb[1]], [bb[2], bb[1]],
                        [bb[2], bb[3]], [bb[0], bb[3]]], np.float32)
    M = cv2.getRotationMatrix2D(anchor, ang, 1.0)
    M[0, 2] += target[0] - anchor[0]
    M[1, 2] += target[1] - anchor[1]
    return cv2.transform(corners[None], M)[0]


def paste_rotated(dst: Image.Image, lay: Image.Image, anchor, ang: float, target) -> Image.Image:
    """把 `lay` 绕自身 `anchor` 点旋转 `ang` 度，使该点正好落到 `target`（dst 坐标）。

    一次仿射搞定「旋转 + 平移」：`p' = R(p - c) + target`。PIL 的 AFFINE 系数是
    「输出坐标 → 输入坐标」的反向映射，所以传逆矩阵。

    🔴 左对齐的斜排行**必须拿「墨迹左中点」当 anchor**：拿外接框中心当 anchor、再把中心
       放到「带子左端的中心」上，等于把整行沿斜方向平移了 `(w/2)·sinθ` —— 行越宽、
       倾角越大，左端垂得越深（369px 宽的台词在 15° 时垂 47px，直接掉出带子、
       被贴片下边缘整段裁掉，预览里就是台词开头几个词凭空消失）。
    """
    M = cv2.getRotationMatrix2D(anchor, ang, 1.0)
    M[0, 2] += target[0] - anchor[0]
    M[1, 2] += target[1] - anchor[1]
    Mi = cv2.invertAffineTransform(M)
    warped = lay.transform(dst.size, Image.AFFINE,
                           (Mi[0, 0], Mi[0, 1], Mi[0, 2],
                            Mi[1, 0], Mi[1, 1], Mi[1, 2]),
                           resample=Image.BICUBIC)
    return Image.alpha_composite(dst, warped)


def name_layer(text: str, font, layout: dict):
    """大号角色名的故障风艺术字：彩色错位层 → 白粗描边 → 深色字芯。

    原图的观感是「深棕字芯 + 白粗描边 + 青/品红左右错位」，错位层必须**先画**，
    后画的白描边+字芯把它盖住大半，只在偏移方向的外侧漏出几像素 —— 这才是故障风，
    反过来画就成了一圈描边阴影。

    返回 (图层, 锚点)。锚点取**字形左中点**：斜排时只有按左中点定位，才不会因为
    英文词比中文长而整体漂移（按 bbox 中心定位实测偏下 17~30px，压到红条上）。
    """
    fill = tuple(layout["name_fill"]) + (255,)
    stroke = tuple(layout["name_stroke"]) + (255,)
    sw = int(layout["name_stroke_w"])

    st = float(layout.get("name_stretch") or 1.0)
    asc, desc = font.getmetrics()
    tw = font.getbbox(text)[2]
    pad = sw + 14
    lw = int(tw) + pad * 2 + 16
    lh = int((asc + desc) * max(1.0, st)) + pad * 2 + 16
    layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    anchor = (pad, lh / 2)

    for col, (dx, dy) in zip(layout["name_glitch"], ((6, 4), (-5, -4))):
        d.text((anchor[0] + dx, anchor[1] + dy), text, font=font, anchor="lm",
               fill=tuple(col) + (215,))
    d.text(anchor, text, font=font, anchor="lm", fill=fill,
           stroke_width=sw, stroke_fill=stroke)

    # 🔴 纵向拉伸：中文 2 个字就占 115×95，同样宽度下英文 6 个字母只能排到 45~55 高，
    #    视觉重量差一半（中文信息密度是拉丁字母的两倍多）。按 name_stretch 把字形纵向
    #    拉长 1.1~1.3 倍，既保住「大字」的冲击力，又不用把英文撑到超出画板。
    if abs(st - 1.0) > 0.01:
        # 绕锚点所在的水平线拉伸，锚点位置保持不动
        new_h = int(round(lh * st))
        layer = layer.resize((lw, new_h), Image.LANCZOS)
        anchor = (anchor[0], anchor[1] * st)
    return layer, anchor


def derive_small_box(layout: dict, name: str, W: int) -> list:
    """推右侧小号英文名的擦除框（`small_box`）。

    🔴 不逐张手写：实测这行小字跟中文大字**几乎同一行**（y 带落在大字 y 带内，
      个别图低调 10~20px），目测标定时按「大红字基线下方一点」去估，会把 y 估高 20px，
       结果整词漏擦 —— 贴片上就会留半截 "nyu"/"ssan"。
       ⇒ y 一律用大字的 y 带 ±20，x 从大字右边界往右按字母数推。
    """
    nb = layout["name_box"]
    letters = max(4, len(name or ""))
    # 每字母 ~32px：实测这行小字每个字母占 23~30px（斜体 + 大小写混排，Brutus 这种小写多
    # 的比 Mozart 宽 40px），取 32 才不会留下 "tus"/"an" 这种尾巴。宽度宁多勿少 ——
    # 多擦 40px 只是背景略平，漏擦就是一截白字留在贴片上，一眼假。
    return [nb[2] - 12, nb[1] - 20,
            min(W - 4, nb[2] + max(150, letters * 32)), nb[3] + 20]


def name_max_w(layout: dict, W: int) -> int:
    """英文大字的宽度上限。

    按「原中文大字宽度 × name_w_scale(1.75)」算，不用「贴片可用宽度」：后者会让 2 字图
    （关羽/海伦/贞德）被撑到跟 4 字图一样宽，GUANYU 直接压满整个画面上半部分，
    视觉重心全变了。1.75 倍是「英文明显比中文宽、又不越过红条起点太多」的实测值
    （放到 1.9 时，长名字的右端会横穿到斜条上方，大字底边压在标签行上）。
    """
    nb = layout["name_box"]
    return max(120, min(int((nb[2] - nb[0]) * float(layout.get("name_w_scale") or 1.75)),
                        W - int(nb[0]) - 34))


def _chain(idx: np.ndarray, lo: int, hi: int) -> np.ndarray:
    """把坐标序列按 [lo,hi) 这个区间反复折叠（反射），越界也能拿到合法坐标。"""
    span = hi - lo
    if span <= 1:
        return np.full_like(idx, lo)
    t = (idx - lo) % (2 * span)
    t = np.where(t >= span, 2 * span - 1 - t, t)
    return lo + t


def _mirror_patch(img: np.ndarray, box: tuple, d: str) -> np.ndarray:
    """把 box 的内容用「跨边镜像」造出来：L/R/U/D 四个方向各取一块等大补丁。"""
    x0, y0, x1, y1 = box
    ys, xs = np.arange(y0, y1), np.arange(x0, x1)
    if d == "L":
        return img[ys[:, None], _chain(xs, 0, x0)[None, :]]
    if d == "R":
        return img[ys[:, None], _chain(xs, x1, img.shape[1])[None, :]]
    if d == "U":
        return img[_chain(ys, 0, y0)[:, None], xs[None, :]]
    return img[_chain(ys, y1, img.shape[0])[:, None], xs[None, :]]


def _strip_score(img: np.ndarray, box: tuple, d: str) -> float | None:
    """给某个方向的「镜源条带」打分：越干净（细节少、没有高亮文字）越小。

    🔴 不能按「离得近」挑方向：九张图里台词行永远在大字正下方、小号英文名永远在右侧，
       从 D 或 R 取值必然把白字一起镜像进贴片（实测直接看到反写的 "Alexander"）。
       所以按条带的高频能量 + 高亮占比挑，选出来基本都落在没字的一侧。
    """
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    H, W = img.shape[:2]
    if d == "L":
        s = img[y0:y1, max(0, x0 - w):x0]
    elif d == "R":
        s = img[y0:y1, x1:min(W, x1 + w)]
    elif d == "U":
        s = img[max(0, y0 - h):y0, x0:x1]
    else:
        s = img[y1:min(H, y1 + h), x0:x1]
    if s.shape[0] < 10 or s.shape[1] < 10:
        return None
    hp = float(np.abs(s.astype(np.float32) - cv2.GaussianBlur(s, (0, 0), 4)).mean())
    bright = float(np.percentile(s.max(axis=2), 99.5))
    return hp + 0.35 * bright


def mirror_fill(img: np.ndarray, mask: np.ndarray) -> np.ndarray:
    """在 mask 内用「最干净方向的跨边镜像」重建背景，返回整幅图（mask 外原样）。

    🔴 为什么不再用纯多尺度 inpaint：mask 是针对整块大字的矩形（130×110 起步），
       降到 1/16 后洞里只剩几个像素，inpaint 只能给出一块**平滑色块** —— 在网点/碎三角
       这种高频漫画底上，那块平滑区一眼就是「贴上去的补丁」（实测 03 图上是一整片平紫）。
       镜像取的是**同图真实纹理**，高频完全对得上；大色调再用 inpaint 的结果校正
       （见下方 low-freq 重组），既不会有色差、也不会像纯 inpaint 那样糊。

    🔴 镜像会带来「对称」破绽，所以只取高频、丢掉低频：
       `mirror - blur(mirror) + blur(inpaint)` —— 大块形状由 inpaint 定，颗粒由镜像给。
    """
    ys, xs = np.nonzero(mask)
    if ys.size == 0:
        return img
    box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    low = multiscale_fill(img, mask, levels=4).astype(np.float32)

    cands = [(s, d) for d in ("L", "R", "U", "D")
             for s in [_strip_score(img, box, d)] if s is not None]
    if not cands:
        return np.clip(low, 0, 255).astype(np.uint8)
    cands.sort()
    d = cands[0][1]

    x0, y0, x1, y1 = box
    patch = _mirror_patch(img, box, d).astype(np.float32)
    pad = 24
    ty0, ty1 = max(0, y0 - pad), min(img.shape[0], y1 + pad)
    tx0, tx1 = max(0, x0 - pad), min(img.shape[1], x1 + pad)
    big = np.zeros((ty1 - ty0, tx1 - tx0, 3), np.float32)
    big[y0 - ty0:y1 - ty0, x0 - tx0:x1 - tx0] = patch
    big_hi = big - cv2.GaussianBlur(big, (0, 0), 18)
    lowc = low[ty0:ty1, tx0:tx1]
    res = np.clip(cv2.GaussianBlur(lowc, (0, 0), 18) + big_hi, 0, 255)

    out = img.astype(np.float32).copy()
    out[ty0:ty1, tx0:tx1] = res
    out = np.where((mask > 0)[..., None], out, img.astype(np.float32))
    return np.clip(out, 0, 255).astype(np.uint8)


def grow_mask(img: np.ndarray, m: np.ndarray, grow: int = 30,
              thr_min: float = 50.0) -> np.ndarray:
    """把手写的字框**向外补到真正盖住笔画**，只允许长出 `grow` 像素。

    🔴 手标 name_box 永远会差十几二十像素：中文大字是斜排 + 白描边 + 青/品红错位，
       目测框底边常常压掉最后一笔的一小截。那一截留在图上，镜像回填会把它当纹理
       一起搬进来，贴片里就出现半个残字。
    🔴 不能放开自动圈字（试过：阈值口径一松就吃到漫画网点，框直接涨到窗口边界），
       所以这里**用窗限制 + 只跟种子框相连的连通域**，最多外扩 `grow` 像素。
    """
    H, W = img.shape[:2]
    ys, xs = np.nonzero(m)
    if ys.size == 0:
        return m
    x0, y0 = max(0, int(xs.min()) - grow), max(0, int(ys.min()) - grow)
    x1, y1 = min(W, int(xs.max()) + grow), min(H, int(ys.max()) + grow)
    ring = cv2.dilate(m, np.ones((grow * 2 + 1,) * 2, np.uint8)) - m

    med = cv2.medianBlur(img, 31).astype(np.float32)
    det = np.abs(img.astype(np.float32) - med).max(axis=2)
    v = det[y0:y1, x0:x1][ring[y0:y1, x0:x1] > 0]
    thr = max(thr_min, float(np.percentile(v, 96))) if v.size else thr_min
    extra = ((det > thr) & (ring > 0)).astype(np.uint8) * 255
    extra = cv2.morphologyEx(extra, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))

    near = cv2.dilate(m, np.ones((7, 7), np.uint8))
    n, lab = cv2.connectedComponents(extra, 8)[:2]
    keep = np.zeros((H, W), np.uint8)
    for j in range(1, n):
        comp = (lab == j).astype(np.uint8) * 255
        if (comp & near).any():
            keep |= comp
    out = cv2.bitwise_or(m, keep)
    return cv2.dilate(out, np.ones((3, 3), np.uint8))


def erase_name(img: np.ndarray, layout: dict) -> tuple[np.ndarray, np.ndarray]:
    """擦掉大号中文名（`name_box`）和右侧小号英文名（`small_box`），背景用镜像回填。

    🔴 这里**不做像素级字检测、直接整块矩形擦**。九张图的底子是漫画网点/笔触/霓虹，
       任何「宽/高、明/暗、局部中位色偏差」的口径都会把背景纹理一起抓进来（三种口径
       全试过，ratio 0.25~0.5，等于整块擦还多带噪声）；而框内除了字就是背景，
       整块擦 + 回填反而最干净。框是一张张实测出来写进 layout 的（再用 grow_mask 兜一圈）。

    🔴 回填后必须**羽化混合**：低分辨率上采样时块状会扩散到框边界，
       直接贴会在字周围留一圈多边形硬接缝（实测能看到斜的浅色块轮廓）。
    """
    H, W = img.shape[:2]
    m = np.zeros((H, W), np.uint8)
    for key in ("name_box", "small_box"):
        b = layout.get(key)
        if not b:
            continue
        x0, y0, x1, y1 = [int(v) for v in b]
        m[max(0, y0):min(H, y1), max(0, x0):min(W, x1)] = 255
    if not m.any():
        return img, np.zeros((H, W), np.uint8)

    # 只对大字那一段做外扩：small_box 本身已经按字母数放宽过，再涨会吃掉右边插画
    nb = layout.get("name_box")
    if nb:
        m_big = np.zeros((H, W), np.uint8)
        m_big[max(0, int(nb[1])):min(H, int(nb[3])),
              max(0, int(nb[0])):min(W, int(nb[2]))] = 255
        grown = grow_mask(img, m_big, grow=30)
        m = cv2.bitwise_or(m, grown)

    filled = mirror_fill(img, m)
    a = cv2.GaussianBlur(m, (19, 19), 0).astype(np.float32) / 255.0
    a = np.clip(a * 1.3, 0, 1)[..., None]
    out = img.astype(np.float32) * (1 - a) + filled.astype(np.float32) * a
    return np.clip(out, 0, 255).astype(np.uint8), m


def multiscale_fill(img: np.ndarray, mask: np.ndarray, levels: int = 5) -> np.ndarray:
    """mask 内用金字塔逐级回填，mask 外原样返回。

    大号艺术字几乎填满整块浅色斜板，mask 面积大到 TELEA 在原始分辨率上会糊成一片。
    降到 1/16~1/32 后洞只剩几十像素，低分辨率 inpaint 能准确抓到「板 → 插画」的大色调，
    再逐级上采样、**只回填 mask 内** —— mask 外与底图逐像素一致，羽化边界一定看不出来。
    """
    cur, curm = img.astype(np.float32), (mask > 0).astype(np.float32)
    pyr = [(cur, curm)]
    for _ in range(levels):
        if cur.shape[0] < 48 or cur.shape[1] < 48:
            break
        cur = cv2.pyrDown(cur)
        curm = cv2.pyrDown(curm)
        pyr.append((cur, curm))

    res = cv2.inpaint(pyr[-1][0].astype(np.uint8),
                      (pyr[-1][1] > 0.02).astype(np.uint8), 3,
                      cv2.INPAINT_TELEA).astype(np.float32)
    for lvl in range(len(pyr) - 2, -1, -1):
        img_l, m_l = pyr[lvl]
        up = cv2.pyrUp(res, dstsize=(img_l.shape[1], img_l.shape[0]))
        res = np.where(m_l[..., None] > 0.02, up, img_l)
    return np.clip(res, 0, 255).astype(np.uint8)


# --------------------------------------------------------------------------- #
# tagbg：条带底图（tagbg/tag1..4.png）。原来的纯色红/黑条上直接排英文标签太素，
# 换成用户提供的故障风贴图；九张按原条色系各配一张（layout 里逐张写 tagbg 字段）。
# --------------------------------------------------------------------------- #
TAGBG_STYLE = {
    # 标签字色按条芯颜色定：tag2 是浅紫白芯 → 深字浅描边；其余深芯 → 白字深描边
    "tag1": {"fill": (255, 255, 255), "stroke": (40, 8, 60)},
    "tag2": {"fill": (56, 24, 88), "stroke": (250, 248, 255)},
    "tag3": {"fill": (255, 255, 255), "stroke": (70, 8, 4)},
    "tag4": {"fill": (255, 255, 255), "stroke": (6, 24, 70)},
}


def load_tagbg(name: str) -> Image.Image:
    p = os.path.join(SRC_DIR, "tagbg", f"{name}.png")
    if not os.path.exists(p):
        raise SystemExit(f"tagbg 不存在：{p}")
    return Image.open(p).convert("RGBA")


def tagbg_geom(im: Image.Image) -> dict:
    """量主成分（条带本体）的质心与中线角。

    🔴 逐张现算、不写死：四张贴图构图不同（箭头尾/故障碎块的占比都不一样），
       质心和中线角各不相同，写死任何一张的值都会让其余三张错位。
    """
    a = np.array(im.split()[3])
    n, lab, st, cent = cv2.connectedComponentsWithStats((a > 200).astype(np.uint8), 8)
    mx = 1 + int(np.argmax(st[1:, cv2.CC_STAT_AREA]))
    ys, xs = np.nonzero(lab == mx)
    cols = np.unique(xs)
    mid = [(c, (ys[xs == c].min() + ys[xs == c].max()) / 2) for c in cols[::8]]
    k, _ = np.polyfit(np.array([p[0] for p in mid]), np.array([p[1] for p in mid]), 1)
    ext = np.array([ys[xs == c].max() - ys[xs == c].min() for c in cols[::5]])
    return {"cx": float(cent[mx][0]), "cy": float(cent[mx][1]),
            "angle": float(np.degrees(np.arctan(-k))),
            "T": float(np.median(ext))}   # 条芯竖向厚度（含倾角的列高中位数）


def place_tagbg(layout: dict, tilt: float, W: int, H: int):
    """缩放/旋转/摆位 tagbg，返回 (图, 左上角落点, 覆盖四边形)。

    - 🔴 缩放取「宽度需求」和「厚度需求」的较大者：
      宽度 = 条长 × tagbg_scale（默认 1.30），保证左端箭头尾、右端故障碎块在条长之外；
      厚度 = 条芯半厚 ≥ tagbg_wrap_half（默认 64px）——台词行中心在条带中心线下方
      47px、半高 18px，条芯必须同时包住标签行和台词行（用户要求 tagbg「包裹住
      下面的文字」），不够厚就横向等比放大。四张图原生厚度差很多（283~347px），
      按宽度统一缩会让最扁的 tag1 包不住台词。
    - 角度 = 条带倾角 − 贴图自带倾角：四张贴图倾角 8.5°~13.6° 各不同，不补这个
      差值，条芯和字会差出 2°~6.5°。
    - 摆位 = 主成分质心对准条带中心线中点（tagbg_dx/dy 可逐张微调）。
      dy 默认 +14：带心下移让台词行落进条芯、标签行留在上半段；再往下会顶到
      台词带下缘外，再往上条芯上沿会吃到大字底部。
    - 覆盖四边形交给 plate_box 并入贴片 bbox，否则贴图超出贴片被裁。
    """
    im = load_tagbg(layout["tagbg"])
    g0 = tagbg_geom(im)
    bar_len = layout["x_right"] - layout["x_left"]
    scale_w = bar_len * float(layout.get("tagbg_scale", 1.30)) / im.width
    scale_t = 2 * float(layout.get("tagbg_wrap_half", 64)) / max(g0["T"], 1.0)
    scale = max(scale_w, scale_t)
    im = im.resize((max(1, int(im.width * scale)), max(1, int(im.height * scale))),
                   Image.LANCZOS)
    delta = tilt - tagbg_geom(im)["angle"]
    if abs(delta) > 0.05:
        im = im.rotate(delta, resample=Image.BICUBIC, expand=True)
    g = tagbg_geom(im)          # rotate(expand) 会换画布，质心按变换后的图重算
    bar_cx = (layout["x_left"] + layout["x_right"]) / 2
    bar_cy = top_y(layout, bar_cx) + layout["bar_h"] / 2
    px = int(round(bar_cx - g["cx"] + float(layout.get("tagbg_dx", 0))))
    py = int(round(bar_cy - g["cy"] + float(layout.get("tagbg_dy", 14))))
    quad = np.array([[px, py], [px + im.width, py],
                     [px + im.width, py + im.height], [px, py + im.height]],
                    np.float32)
    return im, (px, py), quad


# --------------------------------------------------------------------------- #
# 排版（只排字，不碰底图）
# --------------------------------------------------------------------------- #
def build_lines(asset: str, lang: str, layout: dict, W: int, H: int,
                q_fill=(255, 255, 255), q_stroke=(0, 0, 0),
                t_fill=(255, 255, 255), t_stroke=(112, 16, 8)):
    """按版面排三条线（大字 / 标签 / 台词），返回 [(图层, 锚点, 角度, 底图落点)]。

    只排字、不碰底图像素：同一份结果既用来画贴片，也用来反推贴片 bbox（见 `plate_box`）。
    颜色不影响墨迹外接框，所以量 bbox 时用默认色即可。

    🔴 落点一律是**底图坐标**（不是贴片坐标）：贴片 bbox 要靠墨迹反推，而墨迹位置又
       跟贴片原点无关 —— 先定落点、再定画布，顺序反过来就会自己咬自己。
    """
    entry = load_map().get(asset, {})
    tag = entry.get(f"tag_{lang}") or ""
    quote = entry.get(f"quote_{lang}") or ""
    name = entry.get(f"name_{lang}") or ""
    tilt = float(np.degrees(np.arctan(-layout["slope"])))
    items = []

    # 3z) 大号角色名：Impact 超粗压缩体 + 故障风错位
    if name:
        nb = [int(v) for v in layout["name_box"]]
        # 🔴 宽度上限按**画板右边界**算，不按 small_box 算：小号英文名先被擦掉，那块横向
        #    空间是空的；按 small_box 算会让 9 张的英文宽度从 245 到 415 不等、字号差一倍
        #    （GUANYU 挤成小字、BRUTUS 撑成大字）。改成「高 145 + 不越出画板」双约束，
        #    九张的英文字高就统一了。
        max_w = name_max_w(layout, W)
        # 整行上移 NAME_LIFT：红条是斜的，右端抬得比左端高 100+px，英文比中文宽之后
        # 右端会顶到条上；上移一点点就能让整行稳稳落在条上方的空白带里。
        tgt = (nb[0], (nb[1] + nb[3]) / 2 - NAME_LIFT)
        ang = tilt if layout.get("name_angle") is None else float(layout["name_angle"])
        # 🔴 缩到「旋转后真的不越出**名字区**」为止。fit_font 只管**没旋转**的墨迹
        #    宽高，斜排 15° 之后整行右端会再抬高 w·sinθ，宽一个字母就多抬 10+px ——
        #    05 的 BRUTUS 就这么顶出画板上沿 8px，03/07 顶出 26/41px。
        #    NAME_HEADROOM 就是这条硬上限（名字区上沿 = name_box 顶 - 92），
        #    以前只在算贴片 bbox 时用过、没约束字本身，所以字照样往外长。
        top_limit = nb[1] - NAME_HEADROOM
        start = 230
        while True:
            font = fit_font(name, max_w, 145, start=start, loader=load_name_font)
            lay, anchor = name_layer(name, font, layout)
            q = layer_ink_quad(lay, anchor, ang, tgt)
            over = max(top_limit - q[:, 1].min(),
                       -q[:, 0].min(), q[:, 0].max() - (W - 1),
                       -q[:, 1].min(), q[:, 1].max() - (H - 1))
            if over <= 0 or font.size <= 24:
                break
            start = max(24, font.size - max(1, int(round(over))))
        items.append((lay, anchor, ang, tgt))

    # 3a) 定位标签：贴着条带左端进一点，垂直居中于条带
    if tag:
        tx = layout["x_left"] + 12
        font = fit_font(tag, int(layout["x_right"] - tx - 12),
                        int(layout["bar_h"] * 0.62), start=int(layout["bar_h"] * 0.52))
        # tagbg 上字要有 1px 描边才压得住故障纹理（tag2 浅芯是深字浅描边）
        lay, bb, ink_c = line_layer(tag, font, fill=tuple(t_fill) + (255,), stroke=1,
                                    stroke_fill=tuple(t_stroke) + (255,))
        # 左中点对齐：标签左端钉在条带左端的中心线上
        items.append((lay, (bb[0], ink_c[1]), tilt,
                      (tx, top_y(layout, tx) + layout["bar_h"] / 2)))

    # 3b) 台词：红条下边线往下 quote_h 的带子，左端对齐
    if quote:
        qx_left = layout["quote_x_left"] + 10
        font = fit_font(quote, int(layout["quote_x_right"] - qx_left - 8),
                        int(layout["quote_h"] * 0.72), start=int(layout["quote_h"] * 0.56))
        # 描边只给 1px：描边过粗会把 20px 的字芯整个包住、看起来变成白字。
        lay, bb, ink_c = line_layer(quote, font, fill=tuple(q_fill) + (255,), stroke=1,
                                    stroke_fill=tuple(q_stroke) + (255,))
        # 左中点对齐（见 paste_rotated 注释）：台词左端钉在带子左端的中心线上。
        # QUOTE_LIFT=2：包裹模式下台词贴着条芯下缘，用户微调整体上移 2px。
        items.append((lay, (bb[0], ink_c[1]), tilt,
                      (qx_left, bot_y(layout, qx_left) + layout["quote_h"] / 2 - QUOTE_LIFT)))
    return items


def plate_box(asset: str, layout: dict, W: int, H: int, changed: np.ndarray | None = None,
              extra: list | None = None):
    """贴片 bbox（底图像素）＝ 红条 ∪ 台词带 ∪ 擦除区 ∪ **所有语言**的墨迹，再外扩 PLATE_PAD。

    🔴 必须对 `LANGS` 全部取并集，不能只按当前语言算：`LoadingPlateGeom.lua` 一张图
       只存一组 anchor，运行时按图号取（LoadingPanel.ApplyLangPlate），没有按语言分表。
       bbox 跟着译文长度变，换语言就整体错位或被裁。所以小字擦除框也按「最长译名」
       推（见 render），保证擦除区同样与语言无关。

    🔴 墨迹要按**旋转后**的四边形算（`layer_ink_quad`）：斜排 15° + 纵向拉伸后，
       大字的左上角会跑到 name_box 的左外侧（h/2·sinθ）和上外侧（w·sinθ + h/2·cosθ）。
       按几何推的贴片会把这两块裁掉 —— 实测 05 的 BRUTUS 顶部被切 46px、左边 16px
       （字母顶是一道齐刷刷的直线），03 切 26px、07 切 41px。
    """
    pb, pq = poly_bar(layout), poly_quote(layout)
    pts = [pb, pq]
    for key in ("name_box", "small_box"):
        b = layout.get(key)
        if b:
            bx0, by0, bx1, by1 = [float(v) for v in b]
            pts.append(np.array([[bx0, by0], [bx1, by0], [bx1, by1], [bx0, by1]], np.float32))
    if changed is not None:
        ys_c, xs_c = np.nonzero(changed)     # grow_mask 可能长出 name_box 30px
        if ys_c.size:
            pts.append(np.array([[xs_c.min(), ys_c.min()], [xs_c.max() + 1, ys_c.min()],
                                 [xs_c.max() + 1, ys_c.max() + 1], [xs_c.min(), ys_c.max() + 1]],
                                np.float32))
    for lang in LANGS:
        for lay, anchor, ang, tgt in build_lines(asset, lang, layout, W, H):
            pts.append(layer_ink_quad(lay, anchor, ang, tgt))
    if extra:
        pts.extend(extra)          # tagbg 覆盖四边形等额外区域
    allp = np.vstack(pts)
    return (max(0, int(np.floor(allp[:, 0].min())) - PLATE_PAD),
            max(0, int(np.floor(allp[:, 1].min())) - PLATE_PAD),
            min(W, int(np.ceil(allp[:, 0].max())) + PLATE_PAD),
            min(H, int(np.ceil(allp[:, 1].max())) + PLATE_PAD))


# --------------------------------------------------------------------------- #
# 主流程
# --------------------------------------------------------------------------- #
def render(asset: str, lang: str, layout: dict) -> dict:
    src = os.path.join(SRC_DIR, f"{asset}.png")
    if not os.path.exists(src):
        raise SystemExit(f"底图不存在：{src}")

    img = read_bgr(src)
    H, W = img.shape[:2]
    entry = load_map().get(asset, {})
    tag = entry.get(f"tag_{lang}") or ""
    quote = entry.get(f"quote_{lang}") or ""
    name = entry.get(f"name_{lang}") or ""

    # 小字的擦除框跟着大字推（见 derive_small_box），不依赖 layout 里手写的值。
    # 🔴 按**所有语言里最长的译名**推：擦除框一变，贴片 bbox 就跟着变，而 anchor 是
    #    一张图一组（不按语言分表），所以这块必须与语言无关。
    names = [entry.get(f"name_{l}") or "" for l in LANGS]
    longest = max(names, key=len) if any(names) else ""
    if longest and not layout.get("small_box"):
        layout = dict(layout)
        layout["small_box"] = derive_small_box(layout, longest, W)

    pb, pq = poly_bar(layout), poly_quote(layout)

    # --- 1) 红条内中文标签：用红条自身的中位色原地填掉 ---------------------- #
    # 不用 inpaint：红条左端只有 10px 余量，半径 6 的 inpaint 会把条外背景渗进来，
    # 结果就是红条左端被"洗白"。红条本身是纯色，中位色填充既准又不会渗边。
    #
    # 🔴 mask 不能只抓白字：中文标签是白字 + 深色描边，只抓白会留下一圈深影
    #    （在贴片上能明显看出「物理输出 · 群伤减益」的深色轮廓）。这里改成
    #    「偏离红条中位色 > 45」，把字、描边、投影一起圈进来；红条自身的渐变只差 15 左右。
    bar_region = np.zeros((H, W), np.uint8)
    cv2.fillPoly(bar_region, [pb.astype(np.int32)], 255)
    bar_region_er = cv2.erode(bar_region, np.ones((3, 3), np.uint8))   # 内缩，别吃条边缘

    keep0 = (bar_region_er > 0)
    bar_color = (np.median(img[keep0].reshape(-1, 3), axis=0).astype(np.uint8)
                 if keep0.any() else np.array([25, 55, 240], np.uint8))

    # layout 里配了 tagbg 且本语言有标签译文 → 整条条带换成故障风贴图；
    # 否则走原路：条内偏离条色的像素（中文标签 + 描边 + 投影）用条色填掉。
    use_tagbg = bool(layout.get("tagbg") and tag)
    if use_tagbg:
        # 🔴 条要整条擦：dilate 19 把条边缘的过渡带一起吃掉，否则贴图边缘会露出
        #    一圈旧条色的边。擦除排在台词带/名字都重建完之后（镜像取材方向此时
        #    上下都已是干净背景，见下方 mirror_fill 调用处）。
        m_bar = cv2.dilate(bar_region, np.ones((19, 19), np.uint8))
    else:
        dev = np.abs(img.astype(np.int16) - bar_color.astype(np.int16)).max(axis=2)
        m_bar = (((dev > 70) & (bar_region_er > 0))).astype(np.uint8) * 255
        m_bar = cv2.morphologyEx(m_bar, cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
        m_bar = cv2.dilate(m_bar, np.ones((3, 3), np.uint8))
        m_bar = (m_bar & bar_region_er).astype(np.uint8)

    # --- 2) 台词行：整带重建（条色 → 背景色）------------------------------ #
    clean = img.copy()
    if not use_tagbg:
        clean[m_bar > 0] = bar_color
    clean, m_quote = fill_quote_band(clean, layout, bar_color)

    # --- 2b) 大号角色名 + 小英文名：多尺度回填 ------------------------------ #
    m_name = np.zeros((H, W), np.uint8)
    if name:
        clean, m_name = erase_name(clean, layout)

    if use_tagbg:
        # 台词带/名字都重建完再擦条：mirror_fill 的取材方向（上=名字区、下=台词带）
        # 此时都已是重建过的干净背景，不会把中文原稿镜像进来
        clean = mirror_fill(clean, m_bar)

    changed = (((m_bar > 0) | (m_quote > 0) | (m_name > 0))
               .astype(np.uint8) * 255)

    # --- 2c) 台词字色自适应 ------------------------------------------------- #
    # 🔴 九张图的台词底不是一回事：04 是浅色斜带（中文原稿就是深棕字压亮底），
    #    01/02/07 这几张是深色插画底（中文原稿是白字 + 深描边）。写死深棕字在深底上
    #    直接看不清（实测 01/02 的英文台词前半句融进背景）。按「带子内背景像素的中位
    #    亮度」分档：亮底 → 深字浅描边，暗底 → 白字深描边。layout 里可以逐张覆盖。
    qm = np.zeros((H, W), np.uint8)
    cv2.fillPoly(qm, [pq.astype(np.int32)], 255)
    band_px = img[(qm > 0) & (img.max(axis=2) < 205)]
    band_lum = (float(np.median(band_px.astype(np.float32) @
                                np.array([0.299, 0.587, 0.114], np.float32)))
                if band_px.size else 128.0)
    if "quote_fill" in layout:
        q_fill, q_stroke = tuple(layout["quote_fill"]), tuple(layout["quote_stroke"])
    elif band_lum > 140:
        q_fill, q_stroke = (44, 26, 30), (250, 246, 240)      # 亮底：深字浅描边
    else:
        q_fill, q_stroke = (252, 250, 246), (24, 14, 20)      # 暗底：白字深描边
    if use_tagbg:
        # 台词行落进 tagbg 条芯里（包裹模式）：字色跟条芯走，不再按底图亮度自适应——
        # 04 这类亮底图换了 tag3 深红条芯后，深棕字会直接消失
        st = TAGBG_STYLE[layout["tagbg"]]
        q_fill, q_stroke = st["fill"], st["stroke"]

    # --- 3) 排版：先在**底图坐标**里算三条线的落点，拿到各自的墨迹范围 ----- #
    tilt = float(np.degrees(np.arctan(-layout["slope"])))
    t_fill, t_stroke = (255, 255, 255), (112, 16, 8)
    tag_place = None
    if use_tagbg:
        st = TAGBG_STYLE[layout["tagbg"]]
        t_fill, t_stroke = st["fill"], st["stroke"]
        tag_place = place_tagbg(layout, tilt, W, H)
    ink_items = build_lines(asset, lang, layout, W, H, q_fill, q_stroke, t_fill, t_stroke)

    # --- 4) 贴片画布 = 几何区 ∪ 擦除区 ∪ 三条线的墨迹（全语言并集）-------- #
    x0, y0, x1, y1 = plate_box(asset, layout, W, H, changed,
                               extra=[tag_place[2]] if tag_place else None)
    pw, ph = x1 - x0, y1 - y0

    # 墨迹被**画板**边界（不是贴片边界）削掉多少：>0 说明这行字本身超出了 684×2048
    # 的画板，贴片再大也救不回来，只能改字号或缩短文案。写进 geom 供 verify 卡。
    ink_clip = 0
    for lay, anchor, ang, tgt in ink_items:
        q = layer_ink_quad(lay, anchor, ang, tgt)
        ink_clip = max(ink_clip,
                       int(max(0, -q[:, 0].min())), int(max(0, q[:, 0].max() - (W - 1))),
                       int(max(0, -q[:, 1].min())), int(max(0, q[:, 1].max() - (H - 1))))

    plate = Image.fromarray(cv2.cvtColor(clean[y0:y1, x0:x1], cv2.COLOR_BGR2RGB)).convert("RGBA")
    # tagbg 先压到重建过的底上，译文字再压到 tagbg 上（顺序反了字会被贴图盖住）
    tag_lay = None
    if tag_place:
        tag_im, (tpx, tpy), _ = tag_place
        lay_full = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        lay_full.alpha_composite(tag_im, (tpx, tpy))
        tag_lay = lay_full.crop((x0, y0, x1, y1))
        plate = Image.alpha_composite(plate, tag_lay)
    ink = Image.new("RGBA", plate.size, (0, 0, 0, 0))     # 译文单独一层，最后取 alpha
    # 落点从底图坐标换算成贴片坐标再画（同一个仿射：绕锚点旋转 + 平移到落点）
    for lay, anchor, ang, tgt in ink_items:
        ink = paste_rotated(ink, lay, anchor, ang, (tgt[0] - x0, tgt[1] - y0))

    plate = Image.alpha_composite(plate, ink)
    text_a = np.array(ink.split()[3])

    # --- 4) alpha：只在「擦过的像素」「tagbg」和「新画的字」上不透明 --------- #
    a = changed[y0:y1, x0:x1].copy()
    a = cv2.GaussianBlur(a, (FEATHER * 2 + 1, FEATHER * 2 + 1), 0)
    if tag_lay is not None:
        a = np.maximum(a, np.array(tag_lay.split()[3]))
    a = np.maximum(a, np.array(text_a))
    a = cv2.GaussianBlur(a, (3, 3), 0)
    plate.putalpha(Image.fromarray(a))

    # --- 5) 落盘 ------------------------------------------------------------ #
    out_dir = os.path.join(OUT_ROOT, asset)
    os.makedirs(out_dir, exist_ok=True)
    plate_path = os.path.join(out_dir, f"overlay_{lang}.png")
    plate.save(plate_path)

    if os.environ.get("PLATE_DEBUG"):
        # 只含译文的那一层（透明底）：排字/定位出问题时直接看它，不用去预览图上猜
        ink.save(os.path.join(out_dir, "debug_ink.png"))

    preview = Image.fromarray(cv2.cvtColor(clean, cv2.COLOR_BGR2RGB)).convert("RGBA")
    preview.alpha_composite(plate, (x0, y0))
    preview_path = os.path.join(out_dir, f"preview_{lang}.png")
    preview.convert("RGB").save(preview_path)

    vis = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    hot = changed > 0
    vis[hot] = (vis[hot] * 0.35 + np.array([0, 255, 0]) * 0.65).astype(np.uint8)
    mask_path = os.path.join(out_dir, f"mask_{lang}.png")
    Image.fromarray(vis).save(mask_path)

    geom = {
        "asset": asset,
        "lang": lang,
        "image_wh": [W, H],
        "plate_bbox": [x0, y0, pw, ph],
        "anchor_min": [round(x0 / W, 6), round(1 - y1 / H, 6)],
        "anchor_max": [round(x1 / W, 6), round(1 - y0 / H, 6)],
        # 墨迹被画板边界削掉的像素数（0 = 三条线都完整落在 684×2048 内）
        "ink_clip_px": ink_clip,
        "layout": {k: (round(v, 4) if isinstance(v, float) else v) for k, v in layout.items()},
    }
    with open(os.path.join(out_dir, "geom.json"), "w", encoding="utf-8") as f:
        json.dump(geom, f, ensure_ascii=False, indent=2)

    return {
        "asset": asset, "lang": lang, "plate": plate_path, "preview": preview_path,
        "mask": mask_path, "size": [pw, ph], "bytes": os.path.getsize(plate_path),
        "source_bytes": os.path.getsize(src), "geom": geom,
        "has_tag": bool(tag), "has_quote": bool(quote),
    }


# --------------------------------------------------------------------------- #
# 发布（落工程 + 登记 + 生成 lua 锚点表）
# --------------------------------------------------------------------------- #
ATLAS_DIR = SRC_DIR
RES_CONFIG = os.path.join(ROOT, "Assets/ManagedResources/ResConfigs/ResourcePathConfig.asset")
LUA_GEOM = os.path.join(ROOT, "Assets/ManagedResources/~Lua/Modules/Message/LoadingPlateGeom.lua")

LUA_GEOM_TPL = """-- 由 scripts/image/loading_plate_overlay.py publish 自动生成，勿手改。
-- 铭牌贴片在底图中的归一化锚点（anchorMin / anchorMax），运行时挂到 LoadBg/pic 的子节点上。
-- 一张图只存一组：bbox = 版面几何 ∪ **所有语言**译文的墨迹并集（见 plate_box），
-- 所以每种语言的贴片尺寸完全一致，运行时不用按语言分表。
return {{
{body}}}
"""


def _new_guid() -> str:
    import uuid
    return uuid.uuid4().hex


def _ensure_meta(png_path: str) -> str:
    """复制同族 .meta 换新 guid。图片导入设置必须与底图完全一致，否则 filterMode /
    spriteMeshType / 平台 override 任一不同，贴片和底图的缩放采样就会差半个像素。

    已存在就**原样保留**：反复 publish 每次都换 guid 会让 git 里这个文件一直显示 modified，
    而且 guid 一换，任何按 guid 引用的地方（编辑器里的引用）就断了。
    """
    meta = png_path + ".meta"
    if os.path.exists(meta):
        return meta

    tpl_path = os.path.join(ATLAS_DIR, "cn2-X1_loading_04_zh.png.meta")
    with open(tpl_path, encoding="utf-8") as f:
        txt = f.read()
    import re
    txt = re.sub(r"^guid: [0-9a-f]{32}$", f"guid: {_new_guid()}", txt, count=1, flags=re.M)
    with open(meta, "w", encoding="utf-8") as f:
        f.write(txt)
    return meta


def _register_resource(res_name: str) -> bool:
    """在 resInfoList 末尾追加一条登记，返回是否新增。

    复用同目录底图的 resPathIndex / resAbNameIndex —— 贴片跟底图同一个目录、同一个
    AssetBundle，所以**不需要**动 resPathList / resAbNameList / assetBundleList
    （往这三个列表中间插一条会把几千个 index 全部平移）。
    """
    with open(RES_CONFIG, encoding="utf-8") as f:
        txt = f.read()
    if f"resName: {res_name}\n" in txt:
        return False

    marker = "  assetBundleList:"
    pos = txt.find(marker)
    if pos < 0:
        raise SystemExit("ResourcePathConfig 里找不到 assetBundleList，登记失败")

    # 从同族底图那条取出 index，避免写死
    import re
    m = re.search(r"- resName: cn2-X1_loading_0\d_zh\n"
                  r"    extension: \.png\n"
                  r"    resPathIndex: (\d+)\n"
                  r"    resAbNameIndex: (\d+)\n", txt)
    if not m:
        raise SystemExit("ResourcePathConfig 里找不到 loading_0x_zh 的登记，无法复用 index")
    path_idx, ab_idx = m.group(1), m.group(2)

    entry = (f"  - resName: {res_name}\n"
             f"    extension: .png\n"
             f"    resPathIndex: {path_idx}\n"
             f"    resAbNameIndex: {ab_idx}\n")
    txt = txt[:pos] + entry + txt[pos:]
    with open(RES_CONFIG, "w", encoding="utf-8") as f:
        f.write(txt)
    return True


def _write_lua_geom(geom: dict) -> None:
    """把 anchor 写进 lua 表（同一张图反复 publish 只更新自己那一行）。"""
    base = geom["asset"][:-3] if geom["asset"].endswith("_zh") else geom["asset"]
    mnx, mny = geom["anchor_min"]
    mxx, mxy = geom["anchor_max"]
    line = (f'    ["{base}"] = {{ minX = {mnx}, minY = {mny}, '
            f'maxX = {mxx}, maxY = {mxy} }},\n')

    rows = {}
    if os.path.exists(LUA_GEOM):
        with open(LUA_GEOM, encoding="utf-8") as f:
            for ln in f:
                ln_s = ln.strip()
                if ln_s.startswith('["'):
                    key = ln_s[2:ln_s.index('"', 2)]
                    rows[key] = ln if ln.endswith("\n") else ln + "\n"
    rows[base] = line

    body = "".join(rows[k] for k in sorted(rows))
    os.makedirs(os.path.dirname(LUA_GEOM), exist_ok=True)
    with open(LUA_GEOM, "w", encoding="utf-8", newline="\n") as f:
        f.write(LUA_GEOM_TPL.format(body=body))


def publish(asset: str, lang: str, layout: dict, force: bool = False) -> int:
    res = render(asset, lang, layout)
    base = asset[:-3] if asset.endswith("_zh") else asset
    res_name = f"{base}_plate_{lang}"
    dst = os.path.join(ATLAS_DIR, f"{res_name}.png")

    if os.path.exists(dst) and not force:
        print(f"[skip] {os.path.relpath(dst, ROOT)} 已存在；要覆盖加 --force", file=sys.stderr)
        return 3

    import shutil
    shutil.copyfile(res["plate"], dst)
    meta = _ensure_meta(dst)
    added = _register_resource(res_name)
    _write_lua_geom(res["geom"])

    print(f"[publish] {os.path.relpath(dst, ROOT)}  {os.path.getsize(dst)/1024:.1f}KB")
    print(f"           meta {os.path.relpath(meta, ROOT)}")
    print(f"           ResourcePathConfig resInfoList {'已追加' if added else '已存在'}")
    print(f"           lua  {os.path.relpath(LUA_GEOM, ROOT)}")
    print("🔴 写回 ≠ 进包：真机生效还要重打 LoginPanelAtlas 所在 AssetBundle")
    return 0


# --------------------------------------------------------------------------- #
# 子命令
# --------------------------------------------------------------------------- #
def measure(asset: str) -> int:
    """实测红条几何：严格朱红阈值 + 最大连通域 + 列高过滤，只用于标定。"""
    img = read_bgr(os.path.join(SRC_DIR, f"{asset}.png"))
    b, g, r = img[:, :, 0].astype(int), img[:, :, 1].astype(int), img[:, :, 2].astype(int)
    m = ((r > 215) & (g < 95) & (b < 70) & ((r - g) > 150) & ((r - b) > 170)).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    if n < 2:
        print(f"{asset}: 没找到红条", file=sys.stderr)
        return 1
    idx = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    mm = (lab == idx).astype(np.uint8)
    cols = []
    for x in range(mm.shape[1]):
        ys = np.nonzero(mm[:, x])[0]
        if len(ys) < 6:
            continue
        h = ys.max() - ys.min()
        if 38 <= h <= 52:                     # 红条本体高 44；装饰斜线只有 29
            cols.append((x, float(ys.min()), float(ys.max())))
    if len(cols) < 30:
        print(f"{asset}: 红条列太少（{len(cols)}），测不出来", file=sys.stderr)
        return 1
    arr = np.array(cols)
    k, bb = np.polyfit(arr[:, 0], arr[:, 1], 1)
    k2, bb2 = np.polyfit(arr[:, 0], arr[:, 2], 1)
    x0, x1 = float(arr[:, 0].min()), float(arr[:, 0].max())
    print(json.dumps({
        "x_left": round(x0, 1),
        "x_right": round(x1, 1),
        "top_y_at_x_left": round(float(k * x0 + bb), 1),
        "slope": round(float(k), 4),
        "bar_h": round(float((k2 * x0 + bb2) - (k * x0 + bb)), 1),
        "tilt_deg": round(float(np.degrees(np.arctan(-k))), 2),
    }, ensure_ascii=False, indent=2))
    return 0


def scan() -> int:
    m = load_map()
    files = sorted(f[:-4] for f in os.listdir(SRC_DIR)
                   if f.startswith("cn2-X1_loading_0") and f.endswith("_zh.png"))
    print(f"底图 {len(files)} 张")
    miss = 0
    for a in files:
        e = m.get(a, {})
        langs = [l for l in ("en", "jp", "kr") if e.get(f"tag_{l}") and e.get(f"quote_{l}")]
        print(f"  {a:28s} 译文 {','.join(langs) if langs else '（缺）'}")
        if not langs:
            miss += 1
    print(f"\n缺译文 {miss} 张；译名唯一真源：{os.path.relpath(MAP_PATH, ROOT)}")
    return 0


def verify(asset: str, lang: str) -> int:
    out_dir = os.path.join(OUT_ROOT, asset)
    pp = os.path.join(out_dir, f"overlay_{lang}.png")
    hp = os.path.join(out_dir, "geom.json")
    if not os.path.exists(pp):
        print(f"缺贴片：{pp}", file=sys.stderr)
        return 1
    plate = Image.open(pp)
    geom = json.load(open(hp, encoding="utf-8"))
    src = os.path.join(SRC_DIR, f"{asset}.png")
    sw, sh = Image.open(src).size
    W, H = geom["image_wh"]
    bx, by, bw, bh = geom["plate_bbox"]
    al = np.array(plate.split()[3])
    checks = [
        ("底图尺寸与登记一致", (W, H) == (sw, sh)),
        ("贴片宽高与 bbox 一致", plate.size == (bw, bh)),
        # 贴片由「几何 ∪ 墨迹 ∪ tagbg 覆盖」反推：包裹模式（tagbg 同时包住标签行和
        # 台词行）后实测 17~27%。这条只是防呆（别退化成整图覆盖），不是设计约束。
        ("贴片占底图 < 30% 面积", (bw * bh) / (W * H) < 0.30),
        ("贴片体积 < 底图 30%", os.path.getsize(pp) < os.path.getsize(src) * 0.30),
        ("anchor 落在底图内", 0 <= geom["anchor_min"][0] < geom["anchor_max"][0] <= 1),
        # 🔴 最重要的一条：三条线的墨迹必须完整落在画板内。>0 说明字被裁了，
        #    表现就是预览里字母顶/尾齐刷刷一条直线（05 的 BRUTUS 曾切掉 46px）。
        ("文字未越出画板（未被裁切）", geom.get("ink_clip_px", 0) == 0),
        ("alpha 有透明区（能叠）", al.min() == 0),
        ("alpha 有不透明主体", al.max() == 255),
        ("不透明像素占比 < 70%", (al > 200).mean() < 0.7),   # 不透明区 = 擦除框+条+带，03 实测 60.6%
    ]
    ok = True
    for name, cond in checks:
        print(f"  {'PASS' if cond else 'FAIL'}  {name}")
        ok = ok and cond
    return 0 if ok else 1


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("scan")

    m = sub.add_parser("measure")
    m.add_argument("--asset", required=True)

    r = sub.add_parser("run")
    r.add_argument("--asset")
    r.add_argument("--all", action="store_true")
    r.add_argument("--lang", default="en")

    v = sub.add_parser("verify")
    v.add_argument("--asset", required=True)
    v.add_argument("--lang", default="en")

    p = sub.add_parser("publish")
    p.add_argument("--asset", required=True)
    p.add_argument("--lang", default="en")
    p.add_argument("--force", action="store_true")

    args = ap.parse_args()

    if args.cmd == "scan":
        return scan()
    if args.cmd == "measure":
        return measure(args.asset)
    if args.cmd == "verify":
        return verify(args.asset, args.lang)
    if args.cmd == "publish":
        return publish(args.asset, args.lang, layout_for(args.asset), force=args.force)
    if args.cmd == "run":
        assets = []
        if args.all:
            assets = sorted(f[:-4] for f in os.listdir(SRC_DIR)
                            if f.startswith("cn2-X1_loading_0") and f.endswith("_zh.png"))
        elif args.asset:
            assets = [args.asset]
        else:
            ap.error("要么 --asset，要么 --all")

        rc = 0
        for a in assets:
            e = load_map().get(a, {})
            if not (e.get(f"tag_{args.lang}") or e.get(f"quote_{args.lang}")):
                print(f"[skip] {a}：没有 {args.lang} 译文", file=sys.stderr)
                rc = 3
                continue
            res = render(a, args.lang, layout_for(a))
            ratio = res["bytes"] / max(1, res["source_bytes"])
            print(f"[ok] {a} {args.lang}  贴片 {res['size'][0]}×{res['size'][1]} "
                  f"{res['bytes']/1024:.1f}KB（底图 {res['source_bytes']/1024:.0f}KB，{ratio*100:.1f}%）")
            print(f"     贴片 {os.path.relpath(res['plate'], ROOT)}")
            print(f"     预览 {os.path.relpath(res['preview'], ROOT)}")
            print(f"     擦除 {os.path.relpath(res['mask'], ROOT)}")
        return rc
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
