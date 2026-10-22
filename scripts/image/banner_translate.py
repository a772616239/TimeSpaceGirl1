#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""战令横幅「中文美术字 → 英文版」流水线。

背景
----
`ArtFont_zh/OperatingPanelAtlas/` 下这批战令横幅（迷雾/爬塔/深渊/魔塔/异端）的标题与
两行文案是**烘进图里**的中文艺术字，不是 TMP 文本。英文版必须重出一张图。

做法（三步，全部可断言）
-----------------------
1. **擦字**：用「亮像素 + 蓝色像素」自动圈出中文标题 / 蓝色光带 / 文案的污染区，
   不按矩形硬切（硬切会把右侧的暗板装饰切出直边）。
2. **补底板**：逐行取「未被污染且够暗」的像素中位色当作该行底色 → 纵向高斯平滑 →
   从干净样张取六边形纹理高频、镜像平铺叠回。这样底板渐变与周边严丝合缝。
3. **排英文**：Arial Bold 白字 + 蓝色辉光，层级与同目录已上线的 `pata_bg_en` /
   `shenyuan_bg_en` 一致（小标题 + 三行大标题）。

三个出图 provider（2026-10-22 新增 chatgpt_web）
---------------------------------------------
出图那一步不可复现、要花额度、还会因为登录态/网络失败 —— 所以它单独摘出来，其余
（提示词、归位、掩膜、验收、写回）全部可断言。这与 `docs/art_restyle_pipeline.md` 的
切法一致：**provider 只负责「把图给我」，不要它顺便决定尺寸、alpha 和落版位置。**

| provider | 做什么 | 用在哪 |
|---|---|---|
| `local`（原行为，仍是默认） | OpenCV 擦字 + 补底板 + PIL 排 Arial 白字，像素断言 6 条 | 884×544 战令横幅；结果可复现、可回归 |
| `chatgpt_web` | 调 `gen_chatgpt_web.py`（Chrome 登录态 / AdsPower 换号链）让 **GPT 重绘这张图**，再本地归位 | 小尺寸美术字块（`glyph` 族，如 180×96 的页签字）；版面/笔画本来就得靠模型画 |
| `manual` | 人把图放进 `--gen-image`，跳过浏览器 | 额度空了、或要手工挑一张 |

**为什么 glyph 族必须走模型**：那类图整张只有 1~3 种颜色（纯白字 + alpha），字身是
手写/斜切的美术字。本地 PIL 能画 Arial，但画不出原图那笔手势 —— 换掉就等于换了画风。
模型重绘能保住笔势，代价是必须回来做三件本地活：抠墨迹 → 归白 + alpha → 归位到原 bbox。

🔴 **喂给模型的参考图既不能是原始透明 PNG，也不能是「深底白字」**：
前者浏览器按白底预览 ⇒ 模型看到一张白纸；后者模型照样交回**白底白字**（2026-10-22 实测，
整张几乎全白，只剩笔画描边，抠出来是一条噪点带）。现在统一给 `inbox/ref_flat.png`：
**白底 + 黑字**，和要的输出同构；颜色无所谓 —— 归位时一律染成纯白，游戏侧靠 tint 上色。

用法
----
    python scripts/image/banner_translate.py scan
    python scripts/image/banner_translate.py run    --asset <zh 相对路径> [--provider chatgpt_web]
    python scripts/image/banner_translate.py run    --asset <zh> --provider manual --gen-image <png>
    python scripts/image/banner_translate.py verify --work <工作目录>
    python scripts/image/banner_translate.py publish --work <工作目录> --yes
    python scripts/image/banner_translate.py batch  [--stage run|verify|publish] [--only a,b] [--force]
                                                   [--provider chatgpt_web] [--cdp-port N]

退出码：0 全通过；3 有「需人看一眼」的项（缺译名 / 已存在跳过 / provider 环境不可用）；
1 硬失败。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import time
import uuid
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
ZH_DIR = ROOT / "Assets/ManagedResources/ArtFont_zh/OperatingPanelAtlas"
ZH_ROOT = ROOT / "Assets/ManagedResources/ArtFont_zh"
EN_DIR = ROOT / "Assets/ManagedResources/ArtFont_en/OperatingPanelAtlas"
ATLAS_ROOT = ROOT / "Assets/ManagedResources/Atlas"
EN_ROOT = ROOT / "Assets/ManagedResources/ArtFont_en"
MAP_FILE = ROOT / "scripts/image/banner_translate_map.json"
WORK_ROOT = ROOT / "_output/art_translate"
BACKUP_ROOT = ROOT / "ResBackpack/备份"
REPORT = ROOT / ".jenkins/lib/stage_report.py"
# 绘图管线（provider = chatgpt_web）的出图通道：Chrome 登录态 / AdsPower 换号链都在这支脚本里
GEN_WEB = HERE / "gen_chatgpt_web.py"
# 出图台账：sha256 → 哪个资源用的。专抓「同一条链把上一张图又交回来」
GEN_LEDGER = WORK_ROOT / "_gen_ledger.json"

FONT_CANDIDATES = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/Supplemental/Arial Black.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]

# 版面锚点：与 zh 原图的三段文字带（约 y=102..198 / 226..264 / 277..315）对齐
TITLE_TOP, TITLE_SIZE = 124, 34
LINE_TOPS = [166, 217, 268, 316]
LINE_SIZES = [54, 54, 52, 46]
LEFT_MARGIN, MAX_WIDTH = 24, 306

# 重建区的横向右界：中文标题最右到 x≈336，再往右是暗板装饰，不能碰
ZONE_RIGHT = 342

# 本流水线只吃战令横幅这一族（884x544、三段文字同一套版面）：
# 别把 *_peitu_zh.png 之类的无字配图卷进来，它们没有文字要翻。
BANNER_GLOB = "*_bg_zh.png"

# --------------------------------------------------------------------------- #
# 家族（family）
# --------------------------------------------------------------------------- #
# artfont：战令横幅，ArtFont_zh/OperatingPanelAtlas/*_bg_zh.png → ArtFont_en/…/*_en.png
#          版面靠上面那组写死的锚点（三段文字、左对齐、右侧不许碰）。
# atlas  ：图集里的入口/横幅大图（Atlas/<面板>/*.png），中文标题烘在一块纯色板上。
#          版面不写死：白字核定文字块，纯色板定填充色，逐列拟合板体上沿，
#          板内填纯色、板外条带从上方取样 —— 这套规则对同族的图都成立。
FAMILY_ARTFONT = "artfont"
FAMILY_ATLAS = "atlas"
# glyph：ArtFont_zh 下的「小型单色美术字块」（页签/竖排标题，如 180x96 的原料收集）。
#   整张只有 1~3 种颜色 = 纯白字 + 抗锯齿 alpha，字身是手写/斜切美术字。
#   这类图**本地排 Arial 会换掉画风**，只能让模型重绘 ⇒ 只支持 provider=chatgpt_web。
FAMILY_GLYPH = "glyph"
# poster：整幅不透明的活动海报（ArtFont_zh/DynamicActivityPanelAtlas/banner，884x856）。
#   画面是插画 + 斜切彩带 + 两行美术字，没有 alpha、没有纯色底板、也没有可写死的版面锚点
#   ⇒ 本地既排不了字也补不了底，只能整幅让模型重绘（同族已上线的
#   cn2-X1_zhutihuodong_liutianmowang_en.png 就是这条路口径）。
FAMILY_POSTER = "poster"
# poster 判据：全幅大图。艺术字块（glyph）上限 700x500，战令横幅是 884x544，
# 海报是 884x856 —— 三条尺寸带互不重叠，所以用尺寸判就够，不必看目录名。
POSTER_MIN = (800, 700)

# 出图 provider：local=本地像素工序（原行为）；chatgpt_web=Chrome/AdsPower 驱动 GPT 重绘；
# manual=人交图（--gen-image），跳过浏览器。三者之后的归位/验收/写回完全同一条。
PROVIDER_LOCAL = "local"
PROVIDER_WEB = "chatgpt_web"
PROVIDER_MANUAL = "manual"
PROVIDERS = [PROVIDER_WEB, PROVIDER_LOCAL, PROVIDER_MANUAL]

# glyph 家族的尺寸上限：超过就不再是「字块」而是整幅图。与 cmd_run 的横幅闸门（600x400）互补。
GLYPH_MAX = (700, 500)
# 「单色」判据：不同 RGB 数量。glyph 实测 2~3 种（254/255 白 + 半透明边），给到 8 仍安全。
GLYPH_MAX_COLORS = 8
# 墨迹强度 → alpha 的映射窗口（0~255）。低于 LO 当背景、高于 HI 当实心字，
# 中间线性过渡就是抗锯齿边 —— 直接用阈值二值化会把笔画边缘啃成锯齿。
GLYPH_INK_LO, GLYPH_INK_HI = 28, 110

ATLAS_PLATE_TOL = 30       # 板体底色容差（实测 std≈1.5，留余量给 PNG 抖动）
ATLAS_CORE_MIN = 190       # 白字核：三通道都不低于它才算字（青/品红描边不算）
ATLAS_CORE_AREA = 200      # 白字零件最小面积，滤掉背景高光
ATLAS_LINE_CLEAN = 175     # 拟合板体上沿时，上沿落在这之下的列视为「被字切断」
ATLAS_STRIP_SAMPLE = 30    # 板外条带从上方多少像素处取样

# poster（整幅重绘族）的「四边背景」闸门：这一圈里没有文字，重绘就会在这里露馅。
# 实测标尺：banner_12 好图 = 平均差 11.3 / 改动 9.4%；同一张的第二版（提示词更严）反而
# 是 26.5 / 17.1% —— 所以上限取 25 / 20%，能把「背景被顺手重画」判出来。
POSTER_EDGE_TOP, POSTER_EDGE_BOTTOM, POSTER_EDGE_SIDE = 40, 30, 40
POSTER_EDGE_MAX = (25.0, 0.20)
# 🔴 但这条闸门有个前提：边圈里得真的是「背景」。异形透明卡（竖版会员卡
# `cn2-X1_zhongshenhuiyuan_peitu`，884x1480）四边 79%~92% 是 alpha=0，剩下的可见像素
# 是卡自己的描边 + 辉光带 —— 整幅重绘必然让它整体位移 1~2px，实测好图也能到 54.2 / 31.1%。
# 所以边圈可见像素占比低于这个数就直接判「不适用」，别拿它开红（改由人眼确认）。
POSTER_EDGE_MIN_OPAQUE = 0.50


# --------------------------------------------------------------------------- #
# 基础工具
# --------------------------------------------------------------------------- #
def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def load_font(size: int) -> ImageFont.FreeTypeFont:
    for p in FONT_CANDIDATES:
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    raise SystemExit("找不到可用粗体字体，请把 Arial Bold.ttf 放到系统字体目录")


def _is_glyph(path: Path) -> bool:
    """小型 + 单色 = 美术字块。两个条件都要，缺一个都会误判。

    只看尺寸会把 180x96 的彩色小图标也吃进来（它们的 alpha 是图标轮廓，不是字）；
    只看颜色数会把 884x544 的纯色横幅吃进来（那批是「暗板 + 白字」，底板只有一个色）。
    """
    try:
        with Image.open(path) as im:
            w, h = im.size
            if w > GLYPH_MAX[0] or h > GLYPH_MAX[1]:
                return False
            rgb = np.asarray(im.convert("RGB"))
            opaque = np.asarray(im.convert("RGBA"))[..., 3] > 8
            if not opaque.any():
                return False
            colors = np.unique(rgb[opaque].reshape(-1, 3), axis=0)
            return len(colors) <= GLYPH_MAX_COLORS
    except Exception:                                            # noqa: BLE001
        return False


def _is_poster(path: Path) -> bool:
    """全幅海报：宽高都超过 glyph 上限，且尺寸落在 884x856 这一档。

    只按尺寸判，不看目录名 —— 以后 banner/ 里加了别的尺寸也不会被误当 884x544 的战令横幅
    （战令横幅是 884x544，高度差 300 多像素，不会误判）。
    """
    try:
        with Image.open(path) as im:
            w, h = im.size
            return w >= POSTER_MIN[0] and h >= POSTER_MIN[1]
    except Exception:                                            # noqa: BLE001
        return False


def family_of(zh: Path) -> str:
    """按源图自身特征分派（不看目录名，避免新增图集时忘了登记）。

    Atlas/**            → atlas（中文压在一块纯色黑板上）
    ArtFont_zh/** 小型单色 → glyph（美术字块，只能模型重绘）
    884x856 全幅海报     → poster（插画 + 彩带，只能整幅重绘）
    其余                → artfont（884x544 三段横幅，版面锚点写死）
    """
    try:
        Path(zh).resolve().relative_to(ATLAS_ROOT)
        return FAMILY_ATLAS
    except ValueError:
        pass
    if _is_glyph(Path(zh)):
        return FAMILY_GLYPH
    if _is_poster(Path(zh)):
        return FAMILY_POSTER
    return FAMILY_ARTFONT


def _pick_family(zh: Path, family: str | None) -> str:
    if family and family != "auto":
        return family
    return family_of(zh)


def en_path_for(zh: Path, family: str | None = None) -> Path:
    """中文源图 → 英文版目标路径：**平铺在族目录根下，丢掉 zh 侧的一切子目录**。

    atlas ：…/Atlas/LaddersTypePanelAtlas/cn2-X1_kuafu_rukou.png
          → …/ArtFont_en/LaddersTypePanelAtlas/cn2-X1_kuafu_rukou_en.png
    artfont / glyph / poster（族目录 = ArtFont_zh 后第一段，子目录一律压平）
          …/ArtFont_zh/OperatingPanelAtlas/x_bg_zh.png        → …/ArtFont_en/OperatingPanelAtlas/x_bg_en.png
          …/ArtFont_zh/DynamicActivityPanelAtlas/tab/y_zh.png → …/ArtFont_en/DynamicActivityPanelAtlas/y_en.png
          …/ArtFont_zh/DynamicActivityPanelAtlas/banner/z_zh.png → …/ArtFont_en/DynamicActivityPanelAtlas/z_en.png

    🔴 **不能再按 zh 相对路径镜像到 en 的子目录**（2026-10-22 的第一版就是这么写的，错的）。
       两条独立原因：
       1) 工程既有 60+ 张 en 图**全部平铺在族目录根**（`ArtFont_en/DynamicActivityPanelAtlas/
          cn2-X1_wmsr_yeqian_01_en.png` 的 zh 原件在 `tab/` 下）—— 客户端按 resName 找图，
          路径只影响 AB 归属，平铺是这条链既定惯例；
       2) 🔴 `resPathList`（ResourcePathConfig）是**手工维护**的目录白名单，`ArtFont_en/
          DynamicActivityPanelAtlas/tab` 根本不在里面 ⇒ 重扫整目录跳过 ⇒ resName 永远不登记
          ⇒ 真机白图。`publish` 现在有闸门拦这种路径（见 `check_target_registered`）。
    """
    fam = _pick_family(zh, family)
    stem = Path(zh).stem
    if fam == FAMILY_ATLAS:
        # 图集里也有带 _zh 后缀的源图（如 cn2-X1_wuxianzhanzhen_02_zh.png）：
        # 口径与 GetPictureFont 的 _zh↔_en 换名一致，en 名必须剥掉 _zh，
        # 否则写回 x_zh_en.png，客户端按 bgEn/GetPictureFont 拼名找不到。
        if stem.endswith("_zh"):
            stem = stem[: -len("_zh")]
        rel = Path(zh).resolve().relative_to(ATLAS_ROOT)   # LaddersTypePanelAtlas/x.png
        return EN_ROOT / rel.parts[0] / (stem + "_en.png")
    if not Path(zh).name.endswith("_zh.png"):
        raise SystemExit(f"不是 _zh.png 命名：{Path(zh).name}")
    new_name = stem[: -len("_zh")] + "_en.png"
    try:
        rel = Path(zh).resolve().relative_to(ZH_ROOT)      # 族目录/…/x_zh.png
    except ValueError:
        return EN_DIR / new_name          # 不在 ArtFont_zh 下（手传的临时图）→ 落回横幅族
    return EN_ROOT / rel.parts[0] / new_name


def res_path_list() -> list[str]:
    """读 `ResourcePathConfig.asset` 的 `resPathList`（目录白名单，手工维护）。"""
    cfg = ROOT / "Assets/ManagedResources/ResConfigs/ResourcePathConfig.asset"
    if not cfg.exists():
        return []
    text = cfg.read_text(encoding="utf-8", errors="replace")
    i = text.find("resPathList:")
    if i < 0:
        return []
    out: list[str] = []
    for line in text[i:].splitlines()[1:]:
        s = line.strip()
        if s.startswith("- Assets/"):
            out.append(s[2:].strip())
        elif s and not s.startswith("-"):
            break
    return out


def res_name_registered(res_name: str) -> bool:
    """resName 是否已进 `resInfoList`。只表示「上一次重扫时它存在」，不代表 AB 是最新的。"""
    cfg = ROOT / "Assets/ManagedResources/ResConfigs/ResourcePathConfig.asset"
    if not cfg.exists():
        return False
    text = cfg.read_text(encoding="utf-8", errors="replace")
    return f"resName: {res_name}\n" in text or f"resName: {res_name}\r" in text


def check_target_registered(target: Path) -> tuple[bool, str]:
    """写回目录必须在 `resPathList` 里，否则这次写回等于白干（重扫跳过整个目录）。

    这是把「静默白图」变成「当场红」的闸门：白图只能靠人眼在真机发现，代价太高。

    🔴 必须**父目录精确匹配**，不能拿前缀/祖先判：`resPathList` 是「一个目录 = 一个 AB」的
       平铺白名单（868 条，`ArtFont_en` 和 `ArtFont_en/DynamicActivityPanelAtlas/tab` 是两条
       独立记录），按祖先判会把 `.../DynamicActivityPanelAtlas/tab` 误判成「已登记」，
       闸门就失效了 —— 第一版就是这么写的，测出来旧错误路径照样放行。
    """
    try:
        rel = target.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return False, f"写回路径不在工程内：{target}"
    want = Path(rel).parent.as_posix()
    if want in res_path_list():
        return True, f"目录已登记：{want}"
    return False, (f"🔴 目标目录 `{want}` 不在 ResourcePathConfig.resPathList 里 —— "
                   f"重扫会整目录跳过，resName 不会登记，真机必然白图。\n"
                   f"   首选修法：别新建子目录，en 图一律平铺在族目录根（`en_path_for` 已经这么算）。\n"
                   f"   确实要新目录：把 `{want}` 加进 resPathList 末尾（别插中间，"
                   f"否则会平移后面所有 resAbNameIndex），再重打 AB。")


def load_map() -> dict:
    if not MAP_FILE.exists():
        return {}
    return json.loads(MAP_FILE.read_text(encoding="utf-8"))


# --------------------------------------------------------------------------- #
# 版面识别
# --------------------------------------------------------------------------- #
def text_bands(a: np.ndarray) -> list[tuple[int, int]]:
    """返回文字行带（y0,y1）。判据：左半区里「够亮且非蓝主导」的像素成行出现。"""
    h, w, _ = a.shape
    sub = a[:, : int(w * 0.55)]
    R, G, B = sub[:, :, 0].astype(int), sub[:, :, 1].astype(int), sub[:, :, 2].astype(int)
    mx = np.maximum(np.maximum(R, G), B)
    blueness = B - np.maximum(R, G)
    hot = ((mx > 145) & (blueness < 45)).mean(axis=1)
    bands, start = [], None
    for y, v in enumerate(hot):
        if v > 0.02 and start is None:
            start = y
        elif v <= 0.02 and start is not None:
            if y - start >= 8:
                bands.append((start, y))
            start = None
    if start is not None:
        bands.append((start, len(hot)))
    return bands


def zone_for(a: np.ndarray) -> tuple[int, int, int, int]:
    bands = text_bands(a)
    if not bands:
        raise SystemExit("没检测到文字行，无法确定重建区")
    y0 = max(0, bands[0][0] - 12)
    y1 = min(a.shape[0], bands[-1][1] + 14)
    return (y0, y1, 0, min(ZONE_RIGHT, a.shape[1]))


def contaminated_mask(a: np.ndarray, zone: tuple[int, int, int, int]) -> np.ndarray:
    """亮像素(白/黄/粉字) + 蓝色像素(光带、蓝斜杠) = 需要重建的污染区。"""
    h, w, _ = a.shape
    R, G, B = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    mx = np.maximum(np.maximum(R, G), B)
    blueness = B - np.maximum(R, G)
    y0, y1, x0, x1 = zone
    z = np.zeros((h, w), bool)
    z[y0:y1, x0:x1] = True
    m = ((mx > 110) | (blueness > 60)) & z
    m = cv2.dilate(m.astype(np.uint8), np.ones((15, 15), np.uint8))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((25, 25), np.uint8))
    m[~z] = 0
    return m


def mirror_tile(tile: np.ndarray, H: int, W: int) -> np.ndarray:
    """镜像平铺，避免出现硬接缝。"""
    rows, y, flip = [], 0, False
    while y < H:
        rows.append(tile[::-1] if flip else tile)
        y += tile.shape[0]
        flip = not flip
    big = np.concatenate(rows, axis=0)[:H]
    cols, x, flip = [], 0, False
    while x < W:
        cols.append(big[:, ::-1] if flip else big)
        x += big.shape[1]
        flip = not flip
    return np.concatenate(cols, axis=1)[:, :W]


# --------------------------------------------------------------------------- #
# 核心：擦字 + 补底板
# --------------------------------------------------------------------------- #
def rebuild_panel(a: np.ndarray) -> tuple[np.ndarray, tuple[int, int, int, int]]:
    zone = zone_for(a)
    y0, y1, x0, x1 = zone
    out = a.astype(float).copy()

    contam = contaminated_mask(a, zone)

    # 逐行底色 = 「未污染且够暗」像素的中位色；整行被污染的用上下行线性补齐
    base = np.zeros((y1 - y0, 3))
    for i, y in enumerate(range(y0, y1)):
        row = a[y, x0:x1]
        ok = (~contam[y, x0:x1]) & (row.max(axis=1) < 110)
        if ok.sum() >= 30:
            base[i] = np.median(row[ok], axis=0)
    for i in range(len(base)):
        if base[i].sum() == 0:
            prev = next((j for j in range(i - 1, -1, -1) if base[j].sum() > 0), None)
            nxt = next((j for j in range(i + 1, len(base)) if base[j].sum() > 0), None)
            if prev is not None and nxt is not None:
                w = (i - prev) / (nxt - prev)
                base[i] = base[prev] * (1 - w) + base[nxt] * w
            elif prev is not None:
                base[i] = base[prev]
            elif nxt is not None:
                base[i] = base[nxt]
    for c in range(3):
        base[:, c] = cv2.GaussianBlur(base[:, c].reshape(-1, 1), (0, 0), 8).ravel()
    patch = np.repeat(base[:, None, :], x1 - x0, axis=1)

    # 六边形纹理：从重建区下方取干净样张，取高频后镜像平铺叠回
    hy0 = min(a.shape[0] - 70, y1 + 8)
    sample = a[hy0 : hy0 + 60, 0 : min(x1, 330)].astype(float)
    detail = sample - cv2.GaussianBlur(sample, (0, 0), 6)
    patch = patch + mirror_tile(detail, y1 - y0, x1 - x0) * 0.75

    # 可分离羽化：只在没有文字的外围渐隐，右界额外收 10px
    alpha = cv2.GaussianBlur(contam[y0:y1, x0:x1].astype(np.float32), (0, 0), 5)
    H, W = alpha.shape
    fy = np.ones(H, np.float32)
    for i in range(8):
        fy[i] = fy[-1 - i] = i / 8
    fx = np.ones(W, np.float32)
    for i in range(W):
        gx = x0 + i
        if gx >= ZONE_RIGHT:
            fx[i] = 0.0
        elif gx > ZONE_RIGHT - 10:
            fx[i] = (ZONE_RIGHT - gx) / 10.0
    alpha = (alpha * fy[:, None] * fx[None, :])[..., None]

    out[y0:y1, x0:x1] = out[y0:y1, x0:x1] * (1 - alpha) + patch * alpha
    return np.clip(out, 0, 255).astype(np.uint8), zone


# --------------------------------------------------------------------------- #
# 排字
# --------------------------------------------------------------------------- #
def fit_font(draw, text: str, max_w: int, start: int, min_size: int = 18):
    size = start
    while size > min_size:
        f = load_font(size)
        box = draw.textbbox((0, 0), text, font=f)
        if box[2] - box[0] <= max_w:
            return f, box
        size -= 1
    f = load_font(min_size)
    return f, draw.textbbox((0, 0), text, font=f)


def draw_text(img: Image.Image, title: str, lines: list[str],
              zone: tuple[int, int, int, int] | None = None) -> Image.Image:
    """白字 + 蓝色辉光。

    zone 给了就把辉光裁在重建区内 —— 辉光模糊半径 9，不裁会溢到 x>342 的暗板装饰上，
    破坏「重建区外像素一个不动」这条验收断言（而且那块本来就不该有字）。
    """
    w, h = img.size
    glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    core = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dg, dc = ImageDraw.Draw(glow), ImageDraw.Draw(core)

    items = [(title, TITLE_SIZE, TITLE_TOP, False)]
    for i, text in enumerate(lines[: len(LINE_SIZES)]):
        items.append((text, LINE_SIZES[i], LINE_TOPS[i], True))

    for text, size, top, is_big in items:
        f, box = fit_font(dc, text, MAX_WIDTH, size)
        x, y = LEFT_MARGIN - box[0], top - box[1]
        if is_big:
            dg.text((x, y), text, font=f, fill=(70, 130, 255, 255))
        dc.text((x, y), text, font=f, fill=(255, 255, 255, 255))

    glow = glow.filter(ImageFilter.GaussianBlur(9))
    if zone is not None:
        y0, y1, x0, x1 = zone
        keep = Image.new("L", (w, h), 0)
        ImageDraw.Draw(keep).rectangle([x0, y0, x1 - 1, y1 - 1], fill=255)
        glow.putalpha(ImageChops.multiply(glow.getchannel("A"), keep))
        core.putalpha(ImageChops.multiply(core.getchannel("A"), keep))

    base = img.convert("RGBA")
    base = Image.alpha_composite(base, glow)
    base = Image.alpha_composite(base, glow)
    return Image.alpha_composite(base, core).convert("RGB")


# --------------------------------------------------------------------------- #
# atlas 家族：白核定位 → 板内填纯色 / 板外条带取样 → 板内居中排字
# --------------------------------------------------------------------------- #
def atlas_white_core(a: np.ndarray) -> np.ndarray:
    """白字核。青/品红描边（R 低或 G 低）不算 —— 只认「三通道都接近纯白」的字芯。"""
    mn = a.min(axis=2)
    core = (mn >= ATLAS_CORE_MIN).astype(np.uint8)
    h, w = core.shape
    box = np.zeros_like(core)
    box[: int(h * 0.25)] = 0
    box[int(h * 0.25): int(h * 0.85), int(w * 0.5):] = 1   # 文字在右半区中段
    core *= box
    n, lab, st, _ = cv2.connectedComponentsWithStats(core, 8)
    keep = np.zeros_like(core)
    for i in range(1, n):
        if st[i][4] >= ATLAS_CORE_AREA:                     # 背景高光也是白的，按面积筛
            keep[lab == i] = 1
    if not keep.any():
        raise SystemExit("没检测到白色字核，无法确定文字块")
    return keep > 0


def atlas_plate(a: np.ndarray, cx0: int, cx1: int):
    """返回 (板体掩膜, 逐列上沿, 逐列下沿, 板底色, 左右界)。

    板体是一块纯色黑（实测 std≈1.5），所以「底色」直接取中位色即可。
    上/下沿都用**未被文字切断的列**拟合直线 —— 被字盖住的列若逐列取极值，会掉到
    字的下方，擦完就会在板体边上留一个缺口。
    """
    mx = a.max(axis=2)
    h, w = mx.shape
    zone_rows = np.zeros_like(mx, bool)
    zone_rows[int(h * 0.15): int(h * 0.80)] = True
    plate = (mx <= ATLAS_PLATE_TOL) & zone_rows

    xs, tops, bots = [], [], []
    for x in range(w):
        col = np.nonzero(plate[:, x])[0]
        if len(col) >= 25:                 # 一根柱子至少 25px 高，滤掉暗角噪点
            xs.append(x)
            tops.append(col.min())
            bots.append(col.max())
    if len(xs) < 60:
        raise SystemExit("没检测到纯色底板，这张可能不属于 atlas 家族")
    xs, tops, bots = np.array(xs), np.array(tops), np.array(bots)

    # 板体是「又高又宽」的一块：右侧暗角也能凑出 25px 的暗柱，按高度把它筛掉
    heights = bots - tops
    keep_h = heights >= max(25, 0.4 * float(np.median(heights)))
    xs, tops, bots = xs[keep_h], tops[keep_h], bots[keep_h]

    # 只保留「覆盖文字块的那一整段」板体：断口超过 10 列的另起一块，别把远处暗角算进来
    center = (cx0 + cx1) // 2
    cuts = np.nonzero(np.diff(xs) > 10)[0]
    seg_starts = np.concatenate([[0], cuts + 1])
    seg_ends = np.concatenate([cuts, [len(xs) - 1]])
    keep = None
    for s, e in zip(seg_starts, seg_ends):
        if xs[s] - 20 <= center <= xs[e] + 20:
            keep = (s, e)
            break
    if keep is None:
        raise SystemExit("板体没有覆盖文字块，这张可能不属于 atlas 家族")
    s, e = keep
    xs, tops, bots = xs[s:e + 1], tops[s:e + 1], bots[s:e + 1]

    clean = tops < ATLAS_LINE_CLEAN        # 被字切断的列上沿会掉到 200 附近
    if clean.sum() < 30:
        raise SystemExit("板体上沿可用列太少，无法拟合")
    kt, bt = np.polyfit(xs[clean], tops[clean], 1)
    kb, bb = np.polyfit(xs, bots, 1)
    grid = np.arange(w)
    top = np.polyval([kt, bt], grid)
    bot = np.polyval([kb, bb], grid)

    yy = np.arange(h)[:, None]
    left, right = int(xs.min()), int(xs.max())
    band = (yy >= top[None, :]) & (yy <= bot[None, :])
    band[:, :left] = False
    band[:, right + 1:] = False

    color = np.median(a[plate & band], axis=0).astype(np.uint8)
    print(f"板体 x {left}..{right}  y {top[left:right+1].min():.0f}..{bot[left:right+1].max():.0f}  "
          f"底色 {tuple(int(v) for v in color)}")
    return band, top, bot, color, left, right


def _edge_scan(row: np.ndarray, x0: int, x1: int, span: int = 20, want: str = "right"):
    """在一行里找「连续 span 个板色像素」的最外侧边界（从窗口外往里扫）。

    从板体中心往外扫是不行的：字身会把连续段截断，量出来的边界就落在字的边缘上，
    框随之缩水，英文字号会被压到原文的一半。
    """
    seg = row[x0:x1]
    idx = np.nonzero(seg)[0]
    if not len(idx):
        return None
    runs, s = [], idx[0]
    for i in range(1, len(idx)):
        if idx[i] != idx[i - 1] + 1:
            runs.append((s, idx[i - 1]))
            s = idx[i]
    runs.append((s, idx[-1]))
    runs = [(a_, b_) for a_, b_ in runs if b_ - a_ + 1 >= span]
    if not runs:
        return None
    return x0 + (runs[-1][1] if want == "right" else runs[0][0])


def _fill_strip_mirror(out: np.ndarray, a: np.ndarray, strip: np.ndarray,
                       x_lo: int, x_hi: int, ctx: int = 60) -> np.ndarray:
    """把 strip 掩膜里的像素用「同一行、字块左右两侧的背景」镜像平铺补上。

    只动 strip 内的像素：板沿以外一个像素都不碰，所以不会在板边上留下矩形接缝。
    """
    rows = np.nonzero(strip.any(axis=1))[0]
    if not len(rows):
        return out
    l0, l1 = max(0, x_lo - ctx), x_lo
    r0, r1 = min(a.shape[1], x_hi + 1), min(a.shape[1], x_hi + 1 + ctx)
    for y in rows:
        src = np.concatenate([a[y, l0:l1][::-1], a[y, r0:r1]])
        if not len(src):
            continue
        span = x_hi - x_lo + 1
        times = span // max(1, len(src)) + 2
        tile = np.concatenate([src if i % 2 == 0 else src[::-1] for i in range(times)])
        tile = np.concatenate([tile, tile])[:span]
        m = strip[y, x_lo:x_hi + 1]
        out[y, x_lo:x_hi + 1][m] = tile[m]
    return out


def rebuild_atlas(a: np.ndarray) -> tuple[np.ndarray, tuple, dict]:
    core = atlas_white_core(a)
    ys, xs = np.nonzero(core)
    cx0, cx1 = max(0, int(xs.min()) - 40), int(xs.max()) + 40
    band, top, bot, color, left, right = atlas_plate(a, cx0, cx1)

    # 板内用大膨胀：要把字的抗锯齿晕一起吃掉，不然板底会留下一圈灰边。
    ink = cv2.dilate(core.astype(np.uint8), np.ones((13, 13), np.uint8)) > 0
    # 板外只留 2px 晕：实测白核越出板沿最多 6px，13×13 的膨胀会把它撑成 13px，
    # 那条带子越宽、横向镜像平铺的纹理就越假（一片横条纹）。
    halo = cv2.dilate(core.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0
    yy = np.arange(a.shape[0])[:, None]
    above = halo & (yy < top[None, :])
    below = ink & ~(yy < top[None, :])

    out = a.copy()
    out[below] = color

    # 板外条带：只补「越过板沿的那几行墨迹」，取样用**同一行、字块左右两侧的背景**镜像平铺。
    # 三条弯路都试过：整条上移 30px 会把上方的装饰亮线搬到板沿（假边）；
    # 反射紧邻列会连字一起反射回来（残字）；inpaint 的边界挨着黑板，会往上渗出一条黑边。
    strip = above.copy()
    strip[:, : int(xs.min()) - 4] = False
    strip[:, int(xs.max()) + 5:] = False
    out = _fill_strip_mirror(out, a, strip, int(xs.min()), int(xs.max()))

    y_top = int(top[left:right + 1].min())
    y_bot = int(bot[left:right + 1].max())
    zone = (max(0, y_top - 18), y_bot, left, right)   # (y0, y1, x0, x1)，含条带

    # 排版区必须落在「文字所在高度上的板体内侧」：板体是斜的（上窄下宽），
    # 拿整块板的左右极值居中排，字就会从上沿的法线方向溢出去。
    # 测边缘一律从板外往里扫、并要求连续 20px 板色 —— 从中心往外扫会被字身截断。
    plate_src = a.max(axis=2) <= ATLAS_PLATE_TOL
    l_rows, r_rows = [], []
    for y in range(y_top + 10, min(a.shape[0] - 1, y_top + 80)):
        lft = _edge_scan(plate_src[y], 0, left + 80, span=20, want="left")
        rgt = _edge_scan(plate_src[y], right - 80, a.shape[1], span=20, want="right")
        if lft is not None and rgt is not None and rgt > lft:
            l_rows.append(lft)
            r_rows.append(rgt)
    if l_rows:
        left_s, right_s = int(np.median(l_rows)), int(np.median(r_rows))
    else:
        left_s, right_s = left, right

    core_w = int(xs.max() - xs.min()) + 1
    box_w = min(right_s - left_s - 32, int(core_w * 1.3))
    cx = (left_s + right_s) // 2
    text_box = (cx - box_w // 2, y_top + 8, cx + box_w // 2, y_bot - 8)
    print(f"排版区 x {text_box[0]}..{text_box[2]} y {text_box[1]}..{text_box[3]}  "
          f"（板内左右界 {left_s}..{right_s}，原文块宽 {core_w}）")

    # 复核用的「板内重建区」：真实板色像素 + 被字覆盖的像素，
    # 不能直接用 band —— band 是上下沿直线之间的矩形，右侧暗角会被算进来，
    # 那样「板底平整」这条会被背景的渐变污染成假红。
    plate_chk = band & (plate_src | ink)
    info = {"plate": plate_chk, "strip": strip, "ink": ink, "color": color,
            "top": top, "core": core, "text_box": text_box}
    return out, zone, info


def _atlas_glyph(text: str, font, skew: float) -> Image.Image:
    """白字芯 + 青色左上偏移 + 品红右下偏移（原图的故障风），偏移量按字高比例走。"""
    b = font.getbbox(text)
    w, h = b[2] + 40, b[3] + 40
    tile = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(tile).text((10 - b[0], 10 - b[1]), text, font=font, fill=(255, 255, 255, 255))
    if skew:
        tile = tile.transform(tile.size, Image.AFFINE, (1, skew, -skew * h / 2, 0, 1, 0),
                              resample=Image.BICUBIC)
    pad = 26
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    alpha = tile.getchannel("A")
    for color, dx, dy in (((255, 80, 225, 235), 5, 6), ((110, 235, 255, 235), -4, -4)):
        layer = Image.new("RGBA", tile.size, (0, 0, 0, 0))
        layer.paste(color, (0, 0), alpha)
        canvas.alpha_composite(layer, (pad + dx, pad + dy))
    canvas.alpha_composite(tile, (pad, pad))
    return canvas


def draw_atlas_text(img: Image.Image, lines: list[str], zone: tuple, skew: float = 0.12):
    """在板体里居中排字。返回 (图, 画上去的掩膜)。"""
    x0, y0, x1, y1 = zone
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    max_w, max_h = x1 - x0, y1 - y0
    gap, size = 2, 200
    font = None
    while size > 12:
        font = load_font(size)
        boxes = [font.getbbox(t) for t in lines]
        ws = [b[2] - b[0] for b in boxes]
        hs = [b[3] - b[1] for b in boxes]
        total = sum(hs) + gap * (len(lines) - 1)
        if max(ws) <= max_w and total <= max_h:
            break
        size -= 1
    boxes = [font.getbbox(t) for t in lines]
    ws = [b[2] - b[0] for b in boxes]
    hs = [b[3] - b[1] for b in boxes]

    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    y = cy - (sum(hs) + gap * (len(lines) - 1)) / 2
    for text, w, h in zip(lines, ws, hs):
        layer.alpha_composite(_atlas_glyph(text, font, skew),
                              (int(cx - w / 2) - 26, int(y) - 26))
        y += h + gap
    out = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    mask = np.asarray(layer.getchannel("A")) > 8
    print(f"排版：{len(lines)} 行，字号 {size}，行宽 {ws}，字块高 {sum(hs) + gap * (len(lines) - 1)}")
    return out, mask


# --------------------------------------------------------------------------- #
# provider = chatgpt_web：提示词 → 出图 → 归位（glyph / artfont / atlas 共用）
# --------------------------------------------------------------------------- #
GLYPH_PROMPT = """\
This is an image-edit task for a mobile-game UI asset. Take the reference image and redo its \
lettering in English.

What the reference shows: hand-drawn ART-FONT lettering, solid black strokes on a plain white \
background, nothing else in the picture.

Chinese text currently in the image: 「{zh}」

Replace it with exactly these English words:
{lines_block}
Layout: {layout_line}

Hard requirements — if any of these is broken the output is unusable:
1. Solid black (#000000) lettering on a plain white (#FFFFFF) background. Exactly two values: \
black strokes, white background. No colour, no gradient, no outline, no glow, no drop shadow, \
no bevel, no emboss, no texture, no noise, no watermark.
2. Keep the original brush style: same stroke weight, same slant/italic angle, same hand-drawn \
feel, same letter shapes. Do NOT replace it with a clean geometric sans-serif.
3. Keep the composition: the lettering covers the same area of the canvas, with the same \
alignment and the same margins. Do not centre it differently, do not shrink it.
4. The background must stay empty white. No frame, no border, no panel, no decoration, \
no extra strokes, no signature.
5. Canvas must keep the same aspect ratio as the reference image.
6. Every Chinese character must be gone. No Chinese / Japanese / Korean glyphs anywhere.
7. Do not add any word or number that is not listed above, and do not repeat the words.

Output one single image.
"""


def _src_ink_bbox(src_im: Image.Image) -> tuple[int, int, int, int]:
    a = np.asarray(src_im.convert("RGBA"))[..., 3]
    ys, xs = np.nonzero(a > 8)
    if not len(xs):
        raise SystemExit("源图 alpha 全透明，量不出字块位置")
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def _flat_ref(src_im: Image.Image, work: Path) -> Path:
    """透明底白字 → **白底黑字**的参考图（上传给模型的那一张）。

    🔴 两个坑都实测过，才定成「黑字白底」：
       ① 直接传原始透明 PNG：聊天窗口按白底预览 ⇒ 模型看到一张白纸，画出来是白底白字；
       ② 传「深底白字」：模型仍然交回一张**白底白字**（2026-10-22 实测 01_zh，整张几乎全白，
          只剩笔画描边的淡灰轮廓，抠出来是一条噪点带）。
       ⇒ 参考图本身就和要的输出同构：白底 + 黑字。颜色不是问题 —— 归位时一律染成纯白，
          游戏侧靠 tint 上色，图里本来就不该带颜色。
    """
    a = src_im.convert("RGBA").getchannel("A")
    gray = a.point(lambda v: 255 - v)              # 不透明处 = 黑
    ref = Image.merge("RGB", (gray, gray, gray))
    ref = ref.resize((src_im.width * 4, src_im.height * 4), Image.LANCZOS)
    out = work / "inbox" / "ref_flat.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    ref.save(out)
    return out


POSTER_PROMPT = """\
This is an image-edit task for a mobile-game event poster. Take the reference artwork and redo its \
baked-in Chinese headline in English.

Chinese text currently in the image: 「{zh}」

Replace it with exactly these lines, keeping their order:
{lines_block}
Layout / styling: {layout_line}

Hard requirements — if any of these is broken the output is unusable:
1. Keep the artwork: illustration, characters, the item icons, glow, lighting, background textures and \
every decorative element must stay as they are. Do not add, remove or move any object.
2. Keep the ribbon / plate that carries the text: same shape, same position, same rotation, same inner \
fill, same bright rim light and same drop shadow.
3. Keep each line's styling exactly like the original line it replaces: same gradient direction, same \
colours, same thick dark outline, same glow, same italic slant, same left alignment, same relative size. \
Only the letters change: Chinese becomes English.
4. Keep the hand-lettered game font look (heavy, slanted, slightly condensed). Do NOT switch to a thin \
geometric sans-serif.
5. Every Chinese character must be gone. No Chinese / Japanese / Korean glyphs anywhere.
6. Do not add any word, number, logo, watermark or signature that is not listed above, and do not repeat \
the words.
7. Canvas keeps the same aspect ratio as the reference image.

Output one single image.
"""


def build_prompt(zh: Path, entry: dict, lines: list[str], title: str, fam: str) -> str:
    """提示词只描述「怎么翻」，不写死版面数值 —— 数值由本地归位负责。"""
    if fam == FAMILY_POSTER:
        body = "\n".join(f"  {i + 1}. {t}" for i, t in enumerate(lines))
        return POSTER_PROMPT.format(
            zh=entry.get("zh_text") or entry.get("note") or zh.stem,
            lines_block=body,
            layout_line=entry.get("gpt_layout") or
            "Same placement as the original: the first line is the big one, the following line(s) sit "
            "under it with the same indent and the same slant.")

    if fam == FAMILY_GLYPH:
        if len(lines) == 1:
            lines_block = f"  - {lines[0]}  (single word, as large as the original)"
        else:
            rows = []
            for i, t in enumerate(lines):
                hint = "the large word" if i == 0 else "smaller, as in the original"
                rows.append(f"  {i + 1}. {t}  ({hint})")
            lines_block = "\n".join(rows)
        layout_line = entry.get("gpt_layout") or (
            "Keep the original arrangement of the letters relative to each other: the first word "
            "is the big one, the following word(s) are smaller and sit on the same baseline / "
            "direction as in the reference. Keep the same rotation/italic angle.")
        return GLYPH_PROMPT.format(zh=entry.get("zh_text") or entry.get("note") or zh.stem,
                                   lines_block=lines_block, layout_line=layout_line)

    # 整幅图（横幅 / 图集大图）：只翻字，别动画面
    text = title if (fam == FAMILY_ARTFONT and title) else ""
    body = "\n".join(f"  - {t}" for t in lines)
    # 🔴 2026-10-22：模板原来写「Rewrite these Chinese strings」却只列英文，
    #    模型得自己 OCR 才知道要替掉哪句，于是顺手把彩带重画了一遍（banner_12 实测
    #    改动 29.9%、平均差 59.2 打红）。译名表里给了 zh_text 就显式写出来。
    zh_src = (entry.get("zh_text") or "").strip()
    src_block = (f"\nChinese text currently baked into the artwork: 「{zh_src}」\n"
                 if zh_src else "\n")
    return f"""\
This is an image-edit task: translate the Chinese text baked into this game UI artwork into English.
{src_block}
Put exactly these English lines where that Chinese text is (same order, same line count):
{body}
{("Small title above: " + text) if text else ""}

Hard requirements:
1. Replace ONLY the text. Keep the artwork, illustration, background, panel, decoration, framing, \
glow and lighting untouched — pixel-identical where there is no text. Same texture, same pattern \
scale, same shading everywhere outside the letters.
2. Keep each line's position, size, weight, colour and effects (glow/gradient/shadow) exactly like \
the original line it replaces. Same left alignment, same margins, same line count.
3. The dark ribbon / plate that carries the text must keep its exact silhouette, position, \
thickness, rotation and inner gradient. Do NOT enlarge, thicken, extend or re-shape it. If the \
English is wider than the Chinese, condense the letters — never grow the ribbon.
4. All Chinese characters must be gone. No Chinese / Japanese / Korean glyphs anywhere.
5. Use clean bold latin capitals, readable at small size, no decorative script that cannot be read.
6. Do not add logos, watermarks, signatures, frames or any extra element.
7. Canvas keeps the same aspect ratio as the reference image.

Output one single image.
"""


def call_provider(args, work: Path, ref: Path, prompt_file: Path, out: Path) -> tuple[int, str]:
    """把「出一张图」这件事交给绘图管线（Chrome/AdsPower + GPT）。

    返回 (rc, 说明)：0=拿到图 / 3=环境不可用（黄，不阻断）/ 1=硬失败。
    🔴 额度、换号、台账、登录态全在 gen_chatgpt_web.py 里，这里**不重复实现** ——
       两套换号链必然漂移（同一件事写两遍，最后两边都不一样）。
    """
    gen = str(getattr(args, "gen_image", "") or "")
    prov = (getattr(args, "provider", "") or PROVIDER_LOCAL).lower()
    if prov == PROVIDER_MANUAL and not gen:
        print("provider=manual 且没给 --gen-image：参考图与提示词已生成，等人出图后重跑"
              "（或把图放进 inbox/gen.png 再用 --gen-image 指过来）", file=sys.stderr)
        return 3, "manual 待出图"
    if gen:
        p = Path(gen)
        if not p.is_file():
            print(f"🔴 --gen-image 不存在：{p}", file=sys.stderr)
            return 1, "gen-image 缺失"
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, out)
        print(f"provider=manual：直接用既有出图 {p.name}")
        return 0, p.name
    if not GEN_WEB.is_file():
        print(f"🔴 找不到出图通道：{GEN_WEB}", file=sys.stderr)
        return 1, "缺少 gen_chatgpt_web.py"

    cmd = [sys.executable, str(GEN_WEB), "--image", str(ref),
           "--prompt-file", str(prompt_file), "--out", str(out)]
    if int(getattr(args, "cdp_port", 0) or 0):
        cmd += ["--reuse-cdp", "--port", str(int(args.cdp_port))]
    if getattr(args, "adspower_profiles", ""):
        cmd += ["--adspower-profiles", str(args.adspower_profiles)]
    if int(getattr(args, "provider_timeout", 0) or 0):
        cmd += ["--timeout", str(int(args.provider_timeout))]
    if getattr(args, "ignore_ledger", False):
        cmd += ["--ignore-ledger"]
    if getattr(args, "no_auto_fallback", False):
        cmd += ["--no-auto-fallback"]

    print("provider=chatgpt_web → " + " ".join(cmd))
    # 外层超时留足余量：gen_chatgpt_web.py 内部有 --timeout 与 --fallback-budget，
    # 这里只是防「脚本卡死不退」，不能比它还小，否则换号链永远走不完。
    budget = int(getattr(args, "provider_timeout", 0) or 0)
    outer = budget * 3 + 900 if budget else 3000
    try:
        r = subprocess.run(cmd, cwd=str(ROOT), timeout=outer)
    except subprocess.TimeoutExpired:
        print("🔴 出图通道超时", file=sys.stderr)
        return 3, "provider 超时"
    if r.returncode == 0 and out.is_file() and out.stat().st_size > 0:
        print(f"✅ 出图：{out.relative_to(ROOT)}（{out.stat().st_size // 1024} KB）")
        return 0, out.name
    # 3 = 不可达 / 未登录 / 人机验证 / 额度用尽 → 这是环境问题，给黄不给红
    print(f"🔴 出图通道失败 rc={r.returncode}（3=环境/额度，见上面 provider 日志）", file=sys.stderr)
    return (3 if r.returncode == 3 else 1), f"provider rc={r.returncode}"


def postprocess_glyph(src_im: Image.Image, gen_im: Image.Image) -> tuple[Image.Image, dict]:
    """模型出的「白字 + 平底」→ 游戏要的「纯白 RGB + alpha」，并归位到源图字块 bbox。

    为什么要归位：模型给的是新画布（常见 1024x1024），字块在里面的位置/大小跟原图无关。
    游戏是拿这张图当 sprite 摆在固定锚点上的，位置一偏，页签就会错开或出框。
    """
    g = np.asarray(gen_im.convert("RGB")).astype(np.float32)
    bg = np.median(g.reshape(-1, 3), axis=0)          # 字是少数派，整幅中位色就是底色
    # 底色平不平：只在**边圈上「几乎等于底色」的像素**里看离散度。
    # 直接把整圈都算进来会被「字贴到画布边」污染（实测纯白底也报 std 40，纯属假红）；
    # 而渐变/纹理底即使挑出近底色的那批，离散度仍然很大 —— 这一条才是有信息量的。
    pad = max(2, min(g.shape[0], g.shape[1]) // 40)
    ring = np.concatenate([g[:pad].reshape(-1, 3), g[-pad:].reshape(-1, 3),
                           g[:, :pad].reshape(-1, 3), g[:, -pad:].reshape(-1, 3)])
    ring_ink = np.abs(ring - bg).max(axis=1)
    near = ring[ring_ink < 12]
    bg_std = float(near.std(axis=0).mean()) if len(near) >= 50 else 0.0
    ink = np.abs(g - bg).max(axis=2)
    alpha = np.clip((ink - GLYPH_INK_LO) / (GLYPH_INK_HI - GLYPH_INK_LO), 0, 1)
    a8 = (alpha * 255).round().astype(np.uint8)

    solid = a8 > 24
    if solid.mean() < 0.01:
        # 白底白字 / 模型只交了张空画布 —— 这种"成功出图"最坑，必须当场判死
        raise SystemExit(f"出图里几乎没有墨迹（{(solid.mean()):.2%}，底色={bg.astype(int)}）："
                         f"多半是白底白字或空画布，重出这张")
    if solid.mean() > 0.6:
        raise SystemExit(f"出图 60% 以上的像素都是墨迹（底色判定失败，底={bg.astype(int)}）")
    ys, xs = np.nonzero(solid)
    if not len(xs):
        raise SystemExit("出图里抠不到墨迹（整张同色？）")
    gb = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    sx0, sy0, sx1, sy1 = _src_ink_bbox(src_im)

    # 等比缩进源图 bbox（contain），不拉到满：模型改了比例时宁可小一圈，也别把字压扁
    crop = Image.fromarray(a8[gb[1]:gb[3], gb[0]:gb[2]])
    tw, th = sx1 - sx0, sy1 - sy0
    s = min(tw / crop.width, th / crop.height)
    nw, nh = max(1, round(crop.width * s)), max(1, round(crop.height * s))
    crop = crop.resize((nw, nh), Image.LANCZOS)

    W, H = src_im.size
    a_out = np.zeros((H, W), np.uint8)
    ox, oy = sx0 + (tw - nw) // 2, sy0 + (th - nh) // 2
    a_out[oy:oy + nh, ox:ox + nw] = np.asarray(crop)

    rgb = np.full((H, W, 3), 255, np.uint8)          # 🔴 一律纯白：颜色由游戏侧 tint 控制
    out = Image.fromarray(np.dstack([rgb, a_out]), "RGBA")

    src_mask = np.asarray(src_im.convert("RGBA"))[..., 3] > 24
    new_mask = a_out > 24
    inter = int((src_mask & new_mask).sum())
    union = int((src_mask | new_mask).sum()) or 1
    stat = {
        "gen_size": list(gen_im.size),
        "gen_bg_rgb": [int(v) for v in bg],
        "gen_bg_std": round(bg_std, 2),
        "gen_bbox": list(gb),
        "src_bbox": [sx0, sy0, sx1, sy1],
        # 主体在出图画布里的占比：太小说明模型只画了个小标记/角落水印，我们却把它放大满 bbox
        "gen_subject_ratio": round(((gb[2] - gb[0]) * (gb[3] - gb[1]))
                                   / float(gen_im.width * gen_im.height), 4),
        "scale": round(s, 4),
        "ink_px": int(new_mask.sum()),
        "src_ink_px": int(src_mask.sum()),
        # 🔴 只做记录，不当红：译文和原文本来就不是同一批字，字形重合度天然只有 0.3~0.5。
        #    拿它当闸门只会天天假红（本地实测 MATERIAL COLLECT vs 原料收集 = 0.35）
        "iou": round(inter / union, 3),
    }
    print(f"归位：出图 {gen_im.size[0]}x{gen_im.size[1]} → 字块 bbox {tw}x{th}（缩放 {s:.1%}）；"
          f"墨迹 {stat['ink_px']} px，源图 {stat['src_ink_px']} px，IoU {stat['iou']}")
    return out, stat


def postprocess_photo(src_im: Image.Image, gen_im: Image.Image) -> tuple[Image.Image, dict]:
    """整幅图（横幅 / 图集大图）：等比 cover 回源尺寸，alpha 与模式沿用源图。

    🔴 不能用 contain：那批图是 full-bleed 的，留边会在面板上露出白框/黑框。
    """
    W, H = src_im.size
    g = gen_im.convert("RGB")
    s = max(W / g.width, H / g.height)
    nw, nh = max(W, round(g.width * s)), max(H, round(g.height * s))
    g = g.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - W) // 2, (nh - H) // 2
    g = g.crop((left, top, left + W, top + H))
    if src_im.mode == "RGBA":
        g = g.convert("RGBA")
        g.putalpha(src_im.getchannel("A"))
    diff = np.abs(np.asarray(src_im.convert("RGB")).astype(int)
                  - np.asarray(g.convert("RGB")).astype(int)).max(axis=2)
    stat = {
        "gen_size": list(gen_im.size),
        "cover_scale": round(s, 4),
        "changed_ratio": round(float((diff > 24).mean()), 4),
        "mean_diff": round(float(diff.mean()), 2),
    }
    print(f"归位：出图 {gen_im.size[0]}x{gen_im.size[1]} → cover {s:.2f} → {W}x{H}；"
          f"改动像素 {stat['changed_ratio']:.1%}，平均差 {stat['mean_diff']}")
    return g, stat


# --------------------------------------------------------------------------- #
# 子命令：scan
# --------------------------------------------------------------------------- #
def cmd_scan(args) -> int:
    mapping = load_map()
    family = getattr(args, "family", "auto") or "auto"
    pool: list[Path] = []
    if family in ("auto", FAMILY_ARTFONT):
        pool += sorted(ZH_DIR.glob(BANNER_GLOB))
    if family in ("auto", FAMILY_GLYPH):
        pool += glyph_targets(mapping)
    if family in ("auto", FAMILY_POSTER):
        pool += poster_targets(mapping)
    if family in ("auto", FAMILY_ATLAS):
        pool += atlas_targets(mapping)
    # 同一张图可能同时被 BANNER_GLOB 与译名表命中（横幅也在表里），去重后再盘
    seen: set[Path] = set()
    pool = [p for p in pool if not (p in seen or seen.add(p))]

    rows, todo, notitle = [], [], []
    for zh in pool:
        en = en_path_for(zh, family)
        entry = mapping.get(zh.name) or {}
        has_en = en.exists()
        has_title = bool(entry.get("title") or entry.get("lines"))
        rows.append(
            {
                "asset": str(zh.relative_to(ROOT)),
                "en": str(en.relative_to(ROOT)),
                "en_exists": has_en,
                "title": entry.get("title", ""),
                "lines": entry.get("lines", []),
                "note": entry.get("note", ""),
            }
        )
        if not has_en:
            (todo if has_title else notitle).append(zh.name)

    if args.json:
        print(json.dumps({"rows": rows, "todo": todo, "no_title": notitle},
                         ensure_ascii=False, indent=2))
    elif args.quiet:
        print(f"共 {len(rows)} 张：已有 {len(rows) - len(todo) - len(notitle)} 张，"
              f"待生成 {len(todo)} 张" + (f"（{'、'.join(todo)}）" if todo else ""))
    else:
        print(f"{'状态':<8}{'资源':<52}{'英文标题'}")
        for r in rows:
            # atlas 家族的条目只有 lines、没有 title（图上本来就只有一块大标语），
            # 判「有没有译名」必须 title/lines 一起看，否则会误标成缺译名。
            text = r["title"] or " / ".join(r["lines"] or [])
            if r["en_exists"]:
                flag = "✅已有"
            elif text:
                flag = "⏳待译"
            else:
                flag = "⚠缺译名"
            print(f"{flag:<8}{Path(r['asset']).name:<52}{text or '—'}")
        print()
        print(f"共 {len(rows)} 张：已有英文版 {len(rows) - len(todo) - len(notitle)} 张，"
              f"待生成 {len(todo)} 张，缺译名 {len(notitle)} 张")
        if notitle:
            print("⚠ 下面这些没有英文版、译名表里也没有条目 —— 多半是纯图无字（peitu 系列），"
                  "确认后不用管；真要翻就在 banner_translate_map.json 补 title/lines：")
            for n in notitle:
                print("   -", n)

    # 环节结论由 job 里的 run_stage.sh 统一登记（这里再登记一次会出现两行同名结论）
    return 3 if (todo and not args.strict_ok) else 0


# --------------------------------------------------------------------------- #
# 子命令：run
# --------------------------------------------------------------------------- #
def work_dir_for(zh: Path, family: str | None = None) -> Path:
    fam = _pick_family(zh, family)
    stem = Path(zh).stem if fam == FAMILY_ATLAS else Path(zh).name[: -len("_zh.png")]
    return WORK_ROOT / stem


def _flatten(im: Image.Image, bg=(28, 30, 44)) -> Image.Image:
    """透明图先合成到深色底再看。

    🔴 不能直接 paste 到浅色画布：RGBA→RGB 是「丢掉 alpha」，透明区的原始 RGB 是白色，
       结果就是白底白字，构建页上什么都看不见（glyph 族 68% 的像素是透明的）。
    """
    im = im.convert("RGBA")
    base = Image.new("RGBA", im.size, tuple(bg) + (255,))
    return Image.alpha_composite(base, im).convert("RGB")


def _compare_sheet(zh_im: Image.Image, en_im: Image.Image, work: Path) -> None:
    """中英对照图（构建页直接能看）。上下排：宽图横幅上下排比左右排更好认。"""
    zh, en = _flatten(zh_im), _flatten(en_im)
    # 小图（字块 152x120）放大后再拼，否则构建页上只有指甲盖大一块
    k = min(4, max(1, 360 // max(1, zh.width)))
    if k > 1:
        zh = zh.resize((zh.width * k, zh.height * k), Image.NEAREST)
        en = en.resize((en.width * k, en.height * k), Image.NEAREST)
    w, h = zh.size
    canvas = Image.new("RGB", (w, h * 2 + 40), (250, 250, 252))
    canvas.paste(zh, (0, 24))
    canvas.paste(en, (0, h + 32))
    d = ImageDraw.Draw(canvas)
    f = load_font(16)
    d.text((8, 4), "ZH (source)", font=f, fill=(30, 30, 40))
    d.text((8, h + 28), "EN (generated)", font=f, fill=(30, 30, 40))
    canvas.save(work / "compare.png")


def check_gen_reuse(gen_path: Path, asset: str) -> tuple[bool, str]:
    """同一张出图被当成两个资源的成品 = driver 串了上一轮的图。

    🔴 2026-10-22 实测：复用 SunBrowser 时第 02 张的 `gen.png` 与第 01 张**逐字节相同**
       （driver 当时按「面积最大」选图，两张同尺寸就选中了上一张），而五条断言全绿 ——
       尺寸对、墨迹量 65%、纯白也对，只有内容哈希能发现。所以这一层必须有：
       断言量的是「图长什么样」，量不出「这张图是不是这次的」。
    """
    try:
        ledger = json.loads(GEN_LEDGER.read_text(encoding="utf-8"))
    except Exception:                                            # noqa: BLE001
        ledger = {}
    digest = sha256(gen_path)
    prev = ledger.get(digest)
    if prev and prev.get("asset") != asset:
        return False, (f"这张出图与「{Path(prev['asset']).name}」那次的成品逐字节相同"
                       f"（{prev.get('at', '?')}）—— 拿回的是上一轮的旧图，拒收")
    ledger[digest] = {"asset": asset, "at": time.strftime("%Y-%m-%d %H:%M:%S")}
    if len(ledger) > 200:                                        # 只留最近 200 张
        ledger = dict(sorted(ledger.items(), key=lambda kv: kv[1].get("at", ""))[-200:])
    try:
        WORK_ROOT.mkdir(parents=True, exist_ok=True)
        GEN_LEDGER.write_text(json.dumps(ledger, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception as e:                                       # noqa: BLE001
        print(f"⚠ 出图台账写不进去（{e}），不影响本次", file=sys.stderr)
    return True, ""


def cmd_run(args) -> int:
    zh = (ROOT / args.asset).resolve() if not Path(args.asset).is_absolute() else Path(args.asset)
    if not zh.exists():
        print(f"源图不存在：{zh}", file=sys.stderr)
        return 1

    fam = _pick_family(zh, getattr(args, "family", None))
    provider = (getattr(args, "provider", "") or PROVIDER_LOCAL).lower()
    if provider not in PROVIDERS:
        print(f"🔴 未知 provider：{provider}（可选 {'/'.join(PROVIDERS)}）", file=sys.stderr)
        return 2

    entry = load_map().get(zh.name, {})
    title = args.title or entry.get("title") or ""
    lines = args.lines.split("|") if args.lines else entry.get("lines") or []
    # `title` 只有本地排字（local + artfont 三段版面）才必需：模型的整幅提示词里标题可有可无，
    # poster / glyph 本来就没有小标题。以前一律要 title，海报会在这一步被判「缺译名」。
    need_title = provider == PROVIDER_LOCAL and fam == FAMILY_ARTFONT
    if not lines or (need_title and not title):
        print(f"⚠ {zh.name} 没有译名：请在 {MAP_FILE.relative_to(ROOT)} 里补 title/lines，"
              f"或用 --title/--lines 传", file=sys.stderr)
        return 3

    with Image.open(zh) as probe:
        size, mode = probe.size, probe.mode

    if provider == PROVIDER_LOCAL:
        if fam == FAMILY_GLYPH:
            print(f"⚠ {zh.name} 是 glyph 族（{size[0]}x{size[1]} 单色美术字块）：本地只能排 Arial，"
                  f"那等于把原图的笔画风格换掉 ⇒ 请用 --provider chatgpt_web", file=sys.stderr)
            return 3
        if fam == FAMILY_POSTER:
            print(f"⚠ {zh.name} 是 poster 族（{size[0]}x{size[1]} 全幅海报）：本地既没有纯色底板可补、"
                  f"也没有可写死的版面锚点 ⇒ 请用 --provider chatgpt_web", file=sys.stderr)
            return 3
        # 尺寸闸门：本地工序按 884x544 的版面锚点走；工程里几张 100x100 的占位图会在补底板时炸形状
        if size[0] < 600 or size[1] < 400:
            print(f"⚠ {zh.name} 尺寸异常（{size[0]}x{size[1]}），不是可翻译的横幅，跳过",
                  file=sys.stderr)
            return 3

    # 🔴 --work 必须绝对化：call_provider 里要 `out.relative_to(ROOT)` 打日志，
    #    传相对路径（如 --work _output/xxx/retry）会抛 ValueError 把整条流程炸在出图之后
    #    （图已经拿到，却白跑一次额度）。2026-10-22 实测踩过。
    work = Path(args.work).resolve() if args.work else work_dir_for(zh, fam)
    work.mkdir(parents=True, exist_ok=True)
    src = work / "src.png"
    shutil.copyfile(zh, src)

    src_im = Image.open(src)
    t0 = time.time()
    zone = None
    extra: dict = {"family": fam, "provider": provider}

    if provider == PROVIDER_LOCAL:
        alpha_orig = src_im.getchannel("A") if src_im.mode == "RGBA" else None
        a = np.asarray(src_im.convert("RGB"))
        if fam == FAMILY_ATLAS:
            panel, zone, info = rebuild_atlas(a)
            Image.fromarray(panel).save(work / "panel.png")
            out, en_mask = draw_atlas_text(Image.fromarray(panel), lines, info["text_box"])
            Image.fromarray((info["plate"] * 255).astype(np.uint8)).save(work / "plate_mask.png")
            Image.fromarray((info["strip"] * 255).astype(np.uint8)).save(work / "strip_mask.png")
            Image.fromarray((en_mask * 255).astype(np.uint8)).save(work / "en_mask.png")
            extra.update({"erase_px": int(info["ink"].sum()), "en_px": int(en_mask.sum()),
                          "plate_rgb": [int(v) for v in info["color"]]})
        else:
            panel, zone = rebuild_panel(a)
            Image.fromarray(panel).save(work / "panel.png")
            out = draw_text(Image.fromarray(panel), title, lines, zone)
        if alpha_orig is not None:
            out = out.convert("RGB")
            out.putalpha(alpha_orig)
    else:
        # ---- 绘图管线：模型只负责「画出来」，尺寸/alpha/落版位置全部由本地归位决定 ----
        prompt = build_prompt(zh, entry, lines, title, fam)
        prompt_file = work / "prompt.txt"
        prompt_file.write_text(prompt, encoding="utf-8")
        if fam == FAMILY_GLYPH:
            ref = _flat_ref(src_im, work)
        else:
            ref = work / "inbox" / "ref.png"
            ref.parent.mkdir(parents=True, exist_ok=True)
            _flatten(src_im).save(ref)
        gen_path = work / "inbox" / "gen.png"
        rc, note = call_provider(args, work, ref, prompt_file, gen_path)
        if rc != 0:
            print(f"⚠ {zh.name}：没拿到出图（{note}），本轮跳过", file=sys.stderr)
            return rc
        ok, why = check_gen_reuse(gen_path, str(zh.relative_to(ROOT)))
        if not ok:
            print(f"🔴 {zh.name}：{why}", file=sys.stderr)
            return 1
        with Image.open(gen_path) as g:
            g.load()
            gen_im = g.copy()
        if fam == FAMILY_GLYPH:
            out, gstat = postprocess_glyph(src_im, gen_im)
            Image.fromarray(np.asarray(out)[..., 3]).save(work / "ink_mask.png")
        else:
            out, gstat = postprocess_photo(src_im, gen_im)
        extra.update({"provider_note": note, "gen": gstat,
                      "prompt_sha256": hashlib.sha256(prompt.encode("utf-8")).hexdigest()[:16]})

    out.save(work / "out.png")
    _compare_sheet(Image.open(src), Image.open(work / "out.png"), work)

    en_path = en_path_for(zh, fam)
    state = {
        "family": fam,
        "provider": provider,
        "asset": str(zh.relative_to(ROOT)),
        "en": str(en_path.relative_to(ROOT)),
        "title": title,
        "lines": lines,
        "zone": list(zone) if zone else None,
        "size": list(size),
        "mode": mode,
        "src_sha256": sha256(src),
        "out_sha256": sha256(work / "out.png"),
        "elapsed": round(time.time() - t0, 2),
        "verified": None,
        "published": None,
        **extra,
    }
    (work / "state.json").write_text(json.dumps(state, ensure_ascii=False, indent=2),
                                     encoding="utf-8")

    print(f"家族   : {fam}   provider: {provider}")
    print(f"源图   : {state['asset']}  {state['size'][0]}x{state['size'][1]} {state['mode']}")
    if zone:
        print(f"重建区 : y {zone[0]}..{zone[1]}  x {zone[2]}..{zone[3]}")
    print(f"译名   : {' / '.join(filter(None, [title]))} {lines}")
    print(f"输出   : {work / 'out.png'}  ({state['elapsed']}s)")
    return 0


# --------------------------------------------------------------------------- #
# 子命令：verify
# --------------------------------------------------------------------------- #
def verify_artfont(work: Path, state: dict) -> tuple[list[tuple[str, bool, str]], list[str]]:
    src = Image.open(work / "src.png")
    out = Image.open(work / "out.png")

    checks: list[tuple[str, bool, str]] = []

    same_size = src.size == out.size
    checks.append(("尺寸一致", same_size, f"{src.size[0]}x{src.size[1]} vs {out.size[0]}x{out.size[1]}"))

    if src.mode == "RGBA":
        sa = np.asarray(src.getchannel("A"))
        oa = np.asarray(out.getchannel("A")) if out.mode == "RGBA" else None
        alpha_ok = oa is not None and np.array_equal(sa, oa)
        checks.append(("alpha 与源图逐像素一致", alpha_ok, "原图透明边必须原样保留"))
    else:
        checks.append(("alpha 与源图逐像素一致", True, "源图无 alpha，跳过"))

    a_src = np.asarray(src.convert("RGB")).astype(int)
    a_out = np.asarray(out.convert("RGB")).astype(int)
    y0, y1, x0, x1 = state["zone"]

    # 背景不许动：重建区之外必须逐像素相同
    outside = np.ones(a_src.shape[:2], bool)
    outside[y0:y1, x0:x1] = False
    diff = np.abs(a_src - a_out).max(axis=2)
    changed = int((diff[outside] > 0).sum())
    checks.append(("重建区外像素未被改动", changed == 0, f"越界改动 {changed} px"))

    # 中文残留：原标题是粉白渐变(R-B>40)，原第二行是黄色(R,G>200 且 B<150)
    zone_rgb = a_out[y0:y1, x0:x1]
    R, G, B = zone_rgb[:, :, 0], zone_rgb[:, :, 1], zone_rgb[:, :, 2]
    pink = int(((R - B > 40) & (zone_rgb.max(axis=2) > 150)).sum())
    yellow = int(((R > 200) & (G > 200) & (B < 150)).sum())
    checks.append(("粉色中文标题无残留", pink < 200, f"粉色像素 {pink}（源图量级上万）"))
    checks.append(("黄色中文文案无残留", yellow < 200, f"黄色像素 {yellow}"))

    # 英文必须真的画上去了：重建区里要有成片的纯白
    white = int((zone_rgb.min(axis=2) > 245).sum())
    checks.append(("英文白字已落版", white > 2000, f"纯白像素 {white}"))
    return checks, []


def verify_atlas(work: Path, state: dict) -> tuple[list[tuple[str, bool, str]], list[str]]:
    """atlas 家族的断言：板外一个像素都不能动、板内不许有残字、板底必须补得平整。"""
    src = Image.open(work / "src.png")
    out = Image.open(work / "out.png")
    a_src = np.asarray(src.convert("RGB")).astype(int)
    a_out = np.asarray(out.convert("RGB")).astype(int)

    checks: list[tuple[str, bool, str]] = []
    same_size = src.size == out.size
    checks.append(("尺寸一致", same_size, f"{src.size[0]}x{src.size[1]} vs {out.size[0]}x{out.size[1]}"))
    if src.mode == "RGBA":
        sa = np.asarray(src.getchannel("A"))
        oa = np.asarray(out.getchannel("A")) if out.mode == "RGBA" else None
        checks.append(("alpha 与源图逐像素一致",
                       oa is not None and np.array_equal(sa, oa), "原图透明边必须原样保留"))
    else:
        checks.append(("alpha 与源图逐像素一致", True, "源图无 alpha，跳过"))

    y0, y1, x0, x1 = state["zone"]
    outside = np.ones(a_src.shape[:2], bool)
    outside[y0:y1, x0:x1] = False
    changed = int((np.abs(a_src - a_out).max(axis=2)[outside] > 0).sum())
    checks.append(("重建区外像素未被改动", changed == 0, f"越界改动 {changed} px"))

    plate = np.asarray(Image.open(work / "plate_mask.png")) > 127
    en = np.asarray(Image.open(work / "en_mask.png")) > 127
    plate_max = int(np.array(state.get("plate_rgb") or [0, 8, 15]).max())

    # 板内、且不在新英文笔画附近的位置，必须全是板底色 —— 亮出一点就是中文残影
    near_en = cv2.dilate(en.astype(np.uint8), np.ones((11, 11), np.uint8)) > 0
    bare = plate & ~near_en
    resid = int(((a_out.max(axis=2) > plate_max + 40) & bare).sum())
    checks.append(("板内中文墨迹零残留", resid < 120, f"越界像素 {resid}（源图字形量级 1.3 万）"))

    flat = a_out[bare]
    flat_std = float(flat.std(axis=0).mean()) if len(flat) else 99.0
    checks.append(("板底补得平整", flat_std < 8.0, f"板内非字区 RGB std {flat_std:.2f}"))

    white = int(((a_out.min(axis=2) > 245) & en).sum())
    checks.append(("英文白字已落版", white > 800, f"新笔画内纯白像素 {white}"))

    # 板外条带：中文墨迹跨过板沿的那一小条，补完不许留白（白=没擦干净的字）。
    # 阈值取 235 而不是 200 —— 条带是照上方 30px 的背景搬的，背景本身有 200~230 的城市亮斑，
    # 拿 200 当线会把背景灯当残字，属于典型假红。
    strip_f = work / "strip_mask.png"
    if strip_f.exists():
        strip = np.asarray(Image.open(strip_f)) > 127
        left_white = int(((a_out.min(axis=2) > 235) & strip).sum())
        checks.append(("板外条带无残字", left_white < 30, f"条带内近白像素 {left_white}"))
    return checks, []


def verify_glyph(work: Path, state: dict) -> tuple[list[tuple[str, bool, str]], list[str]]:
    """glyph 家族的断言：尺寸 / 透明边 / 墨迹量 / 纯白 / 落位。

    🔴 这里**没有**「文字对不对」的闸门：OCR 在手写美术字上不可靠，拿它当红绿只会假红。
       所以最后一条是 warns（构建标黄、提示人眼确认），而不是 checks。
    """
    src = Image.open(work / "src.png").convert("RGBA")
    out = Image.open(work / "out.png").convert("RGBA")
    checks: list[tuple[str, bool, str]] = []
    warns: list[str] = []

    checks.append(("尺寸与源图一致", src.size == out.size,
                   f"{src.size[0]}x{src.size[1]} vs {out.size[0]}x{out.size[1]}"))

    sa = np.asarray(src)[..., 3]
    oa = np.asarray(out)[..., 3]

    # 透明边：源图字块可能贴到画布边缘（152x120 那张底部就贴着），所以不能量整条边环，
    # 改量四角方块 —— 那里在源图里一定是空的，模型若把底画满/加框，四角立刻变实。
    c = max(4, min(out.width, out.height) // 10)
    corners_src = [sa[:c, :c], sa[:c, -c:], sa[-c:, :c], sa[-c:, -c:]]
    corners_out = [oa[:c, :c], oa[:c, -c:], oa[-c:, :c], oa[-c:, -c:]]
    cmax_out = max(int(x.max()) for x in corners_out)
    cmax_src = max(int(x.max()) for x in corners_src)
    checks.append(("四角仍是透明的", cmax_out <= max(16, cmax_src + 16),
                   f"出图四角最大 alpha {cmax_out}（源图 {cmax_src}）—— 变实说明模型把底/框画进来了"))

    n_src, n_out = int((sa > 24).sum()), int((oa > 24).sum())
    ratio = n_out / max(1, n_src)
    checks.append(("字块墨迹量合理", 0.35 <= ratio <= 2.0,
                   f"{n_out} px = 源图的 {ratio:.0%}（源 {n_src} px）"))

    a_out = np.asarray(out)
    op = a_out[..., :3][oa > 10]
    checks.append(("字色为纯白 RGB255", bool(len(op)) and not (op != 255).any(),
                   "颜色由游戏侧 tint 控制，图里不许带彩色/渐变"))

    gen = state.get("gen") or {}
    subject = float(gen.get("gen_subject_ratio") or 0.0)
    checks.append(("出图主体不是一个小标记", subject >= 0.05,
                   f"主体占出图画布 {subject:.1%}（太小 = 模型只画了个角标，放大后就是一团糊）"))

    if gen.get("gen_size") and state.get("size"):
        gw, gh = gen["gen_size"]
        sw, sh = state["size"]
        dev = abs((gw / max(1, gh)) - (sw / max(1, sh))) / max(1e-3, sw / max(1, sh))
        if dev > 0.25:
            warns.append(f"模型改了画布比例（出图 {gw}x{gh} vs 源 {sw}x{sh}）：字块按 bbox 等比缩回，"
                         f"版面可能已经不是原样")
    if gen.get("gen_bg_std") and gen["gen_bg_std"] > 25:
        warns.append(f"出图底色不平（边圈 std {gen['gen_bg_std']}）：墨迹是按「与底色的差」抠的，"
                     f"渐变/纹理底会把一层灰雾一起抠成字，务必看图")
    if gen.get("iou") is not None:
        warns.append(f"字形重合度 IoU {gen['iou']}（只记录，不当红：译文与原文不是同一批字）")
    warns.append("译文需人眼确认（手写美术字没有可靠的 OCR 闸门）")
    return checks, warns


def _visible_mask(src: Image.Image):
    """源图 alpha 掩膜：alpha=0 的像素运行时永远看不见，比较它们的 RGB 没有意义。

    🔴 2026-10-22 `cn2-X1_zhongshenhuiyuan_peitu_zh`（884x1480 竖版会员卡）实测：
       透明区占 17.4%，四边 79%~92% 是 alpha=0；源图透明区 RGB=(0,0,0)，而参考图是
       按 `_flatten` 的 (28,30,44) 深底合成给的模型 ⇒ 出图那圈 RGB 天然差 44 > 24。
       不按 alpha 掩膜，「改动比例」和「四边背景」都会被这圈看不见的像素判红。
       （alpha 本身另有硬项逐像素 lock，所以掩掉不会放走「模型把底画满」这类问题。）
    """
    if src.mode != "RGBA":
        return None
    return np.asarray(src.getchannel("A")) > 8


def verify_photo_gpt(work: Path, state: dict) -> tuple[list[tuple[str, bool, str]], list[str]]:
    """整幅图走模型重绘时的口径：尺寸 / alpha / 「确实改了字」/ 「没被整幅重画」。"""
    src = Image.open(work / "src.png")
    out = Image.open(work / "out.png")
    checks: list[tuple[str, bool, str]] = []
    warns: list[str] = []

    checks.append(("尺寸与源图一致", src.size == out.size,
                   f"{src.size[0]}x{src.size[1]} vs {out.size[0]}x{out.size[1]}"))
    if src.mode == "RGBA":
        same = out.mode == "RGBA" and np.array_equal(np.asarray(src.getchannel("A")),
                                                    np.asarray(out.getchannel("A")))
        checks.append(("alpha 与源图逐像素一致", same, "透明边沿用源图（lock 语义）"))
    else:
        checks.append(("alpha 与源图逐像素一致", True, "源图无 alpha，跳过"))

    a_src = np.asarray(src.convert("RGB")).astype(int)
    a_out = np.asarray(out.convert("RGB")).astype(int)
    diff = np.abs(a_src - a_out).max(axis=2)
    vis = _visible_mask(src)
    if vis is None:
        changed = float((diff > 24).mean())
        mean_diff = float(diff.mean())
        scope = ""
    else:
        changed = float((diff[vis] > 24).mean())
        mean_diff = float(diff[vis].mean())
        scope = f"，按可见区统计（alpha>0 占 {vis.mean():.1%}，透明区不计）"
    checks.append(("文字区域确实重画过", changed >= 0.02,
                   f"改动像素 {changed:.1%}（原样返回说明模型没动手）{scope}"))
    checks.append(("没有整幅重画", changed <= 0.75, f"改动像素 {changed:.1%}（翻译不该重绘背景）{scope}"))
    checks.append(("整体色差可控", mean_diff <= 45, f"平均通道差 {mean_diff:.1f}{scope}"))
    if changed > 0.40:
        warns.append(f"改动像素 {changed:.0%} 偏大：模型可能顺手改了画面，务必看图")
    warns.append("英文是否正确、有没有被裁掉需人眼确认（无 OCR 闸门）")
    return checks, warns


def verify_poster(work: Path, state: dict) -> tuple[list[tuple[str, bool, str]], list[str]]:
    """海报口径 = 整幅重绘的通用口径 + 「彩带区真的动过」+ 「四边背景没被重绘」。

    为什么不再加更硬的闸门：同族已上线的 `cn2-X1_zhutihuodong_liutianmowang_en.png` 与中文版
    逐像素比是 **73.6% 改动 / 平均差 128**（插画和彩带都是模型重画的），拿「背景零改动」当红线
    只会把这类成品全判红。能自动担保的只有「尺寸/alpha/改没改/改得有多狠」，剩下的必须人眼看图。

    🔴 2026-10-22 修正一处口径错配：**「整体平均通道差 ≤45」在这族里不成立**。
       彩带 + 美术字本身就占掉大半张画布，只换字也会把均值抬到 60 上下 ——
       `cn2-X1_jingyinghuodong_banner_12`（884x336，几何底 + 黑色斜切彩带）实测
       改动 29.9% / 平均差 59.2，但**四边纯背景平均差只有 11.3（改动 9.4%）**，
       背景其实一点没动。用整幅均值当硬闸门 = 把「彩带够大」判成「重绘了背景」。
       ⇒ mean_diff 降级为 warn，另立一条更硬也更要害的「四边背景」闸门：
         换字的边界条件是「边框里的背景帧必须原样」，这条测出来的才是它。
    """
    checks, warns = verify_photo_gpt(work, state)
    # 整幅均值在这族里没判别力（见 docstring）：降级成 warn，别当硬闸门
    checks = [c for c in checks if c[0] != "整体色差可控"]
    src_im = Image.open(work / "src.png")
    a_src = np.asarray(src_im.convert("RGB")).astype(int)
    a_out = np.asarray(Image.open(work / "out.png").convert("RGB")).astype(int)
    vis = _visible_mask(src_im)
    h = a_src.shape[0]
    band = slice(0, int(h * 0.45))               # 文字彩带在上半部
    diff = np.abs(a_src[band] - a_out[band]).max(axis=2)
    if vis is not None:
        sub = vis[band]
        ratio = float((diff[sub] > 24).mean()) if sub.any() else 0.0
        band_note = f"（按可见区统计，alpha>0 占 {sub.mean():.0%}）"
    else:
        ratio = float((diff > 24).mean())
        band_note = ""
    checks.append(("彩带文字区确实重画过", ratio >= 0.03,
                   f"上 45% 区域改动像素 {ratio:.1%}（太小说明模型没动字）{band_note}"))

    # 四边背景：这一圈里没有文字，必须原样（模型整幅重渲染时最先在这里露馅）
    # 🔴 透明图（竖版会员卡这类异形卡）四边 79%~92% 是 alpha=0，那圈比对的是
    #    「源图 RGB=0 vs 参考图深底合成出的 RGB」，天然差 40+ ⇒ 必须先掩掉再判。
    full = np.abs(a_src - a_out).max(axis=2)
    edge = np.zeros(full.shape, dtype=bool)
    edge[:POSTER_EDGE_TOP, :] = True
    edge[-POSTER_EDGE_BOTTOM:, :] = True
    edge[:, :POSTER_EDGE_SIDE] = True
    edge[:, -POSTER_EDGE_SIDE:] = True
    ring_total = int(edge.sum())
    opaque_share = 1.0
    if vis is not None:
        opaque_share = int((edge & vis).sum()) / max(1, ring_total)
        edge = edge & vis
    if edge.any():
        edge_mean = float(full[edge].mean())
        edge_changed = float((full[edge] > 24).mean())
    else:
        edge_mean, edge_changed = 0.0, 0.0
    if opaque_share < POSTER_EDGE_MIN_OPAQUE:
        # 边圈里不是「背景」而是卡自身的描边/辉光（异形透明卡）⇒ 这条闸门的前提不成立，
        # 判不适用，别拿它开红（看了图再定，见 POSTER_EDGE_MIN_OPAQUE 的说明）。
        warns.append(
            f"四边背景闸门不适用：源图是异形透明卡，边圈只有 {opaque_share:.0%} 是可见像素"
            f"（其余 alpha=0），可见的那圈是卡自己的描边/辉光，整幅重绘必然整体位移 —— "
            f"实测平均差 {edge_mean:.1f}、改动 {edge_changed:.1%}（仅参考），四边务必人眼看")
    else:
        checks.append(("四边背景未被重绘",
                       edge_mean <= POSTER_EDGE_MAX[0] and edge_changed <= POSTER_EDGE_MAX[1],
                       f"边框（上{POSTER_EDGE_TOP}/下{POSTER_EDGE_BOTTOM}/左右{POSTER_EDGE_SIDE}px）"
                       f"平均差 {edge_mean:.1f}、改动 {edge_changed:.1%}"
                       f"（上限 {POSTER_EDGE_MAX[0]:.0f} / {POSTER_EDGE_MAX[1]:.0%}）"))

    mean_diff = float(full[vis].mean()) if vis is not None else float(full.mean())
    if (state.get("gen") or {}).get("gen_size"):
        warns.append(f"整幅平均通道差 {mean_diff:.1f}（这族只作参考：彩带与美术字占大半画布，"
                     f"只换字也会到 60 上下；上面那条四边背景才是硬闸门）")
    warns.append("整幅海报是模型重绘的：彩带边缘、插画细节会与中文版有细微差别，务必看图确认")
    return checks, warns


def run_verify(work: Path, state: dict):
    """按 provider / family 选口径。provider 决定「谁画的」，family 决定「画的是什么」。"""
    fam = state.get("family") or FAMILY_ARTFONT
    provider = state.get("provider") or PROVIDER_LOCAL
    if provider == PROVIDER_LOCAL:
        return verify_atlas(work, state) if fam == FAMILY_ATLAS else verify_artfont(work, state)
    if fam == FAMILY_GLYPH:
        return verify_glyph(work, state)
    if fam == FAMILY_POSTER:
        return verify_poster(work, state)
    return verify_photo_gpt(work, state)


def cmd_verify(args) -> int:
    work = Path(args.work)
    state = json.loads((work / "state.json").read_text(encoding="utf-8"))
    fam = state.get("family") or FAMILY_ARTFONT
    provider = state.get("provider") or PROVIDER_LOCAL
    checks, warns = run_verify(work, state)

    ok = all(c[1] for c in checks)
    print(f"验收（{fam} / {provider}）：{state['asset']}")
    for name, passed, detail in checks:
        print(f"  {'✅' if passed else '❌'} {name}  —— {detail}")
    for w in warns:
        print(f"  ⚠ {w}")

    state["verified"] = {"ok": ok,
                         "checks": [{"name": n, "pass": p, "detail": d} for n, p, d in checks],
                         "warns": warns}
    (work / "state.json").write_text(json.dumps(state, ensure_ascii=False, indent=2),
                                     encoding="utf-8")
    if args.run:
        failed = [n for n, p, _ in checks if not p]
        if not ok:
            status, detail = "fail", "未过：" + "、".join(failed)
        elif warns:
            # 硬项全过但有「得人看一眼」的项 ⇒ 黄（不是绿）。绿=机器已经能担保，这里担保不了。
            status, detail = "warn", "硬项全过；待人工确认：" + "；".join(warns)
        else:
            status, detail = "pass", "全部通过"
        register(args.run, f"验收·{Path(state['asset']).stem}", status, "美术翻译链", detail)
    return 0 if ok else 1


# --------------------------------------------------------------------------- #
# 子命令：publish
# --------------------------------------------------------------------------- #
def _fresh_meta_ids(text: str) -> str:
    """把 meta 里的 guid 与 spriteID 换成新的。

    🔴 只换 guid 不够：`spriteID` 是 SpriteAtlas 打包变体时的引用键，两份资源共用一个 id
       会互相顶掉（旧版 tab 01/02 就是这么生成的，隐患一直挂着）。两处一起换才干净。
    """
    text = re.sub(r"^guid: .*$", "guid: " + uuid.uuid4().hex, text, count=1, flags=re.M)
    return re.sub(r"^(\s*)spriteID: .*$", lambda m: f"{m.group(1)}spriteID: {uuid.uuid4().hex}",
                  text, count=1, flags=re.M)


def ensure_meta(target: Path, src_hint: Path | None = None) -> str:
    """目标 png 缺 .meta 时，从同族资源复制一份并换新 guid。

    模板必须挑**同族**的：实测同目录 `chaozhijj_diban_en` 与 `zhanling_pata_bg_en` 的导入设置
    差了 filterMode / spriteMeshType / applyGammaDecoding / 平台 override 四项，
    随便抓第一份会让横幅在 Unity 里糊掉或走错压缩口径。

    atlas 家族直接拿**中文源图自己的 .meta** 当模板 —— 同一张图、同一个图集、
    同一套导入设置，不可能更准。
    """
    meta = Path(str(target) + ".meta")
    if meta.exists():
        return "已存在，保持原 guid"

    src_meta = Path(str(src_hint) + ".meta") if src_hint is not None else None
    if src_meta is not None and src_meta.exists():
        text = _fresh_meta_ids(src_meta.read_text(encoding="utf-8"))
        meta.write_text(text, encoding="utf-8")
        return f"按中文源图 {src_meta.name} 模板生成（新 guid/spriteID，导入设置完全一致）"

    stem = target.name[: -len("_en.png")]  # cn2-X1_zhanling_miwu_bg
    family = stem.split("_")[1] if "_" in stem else ""  # zhanling
    patterns = []
    if stem.endswith("_bg"):
        # 横幅优先跟「同族的 bg 类」对齐（pata_bg_en 就是标准样本），
        # 否则会抓到 jiesuo_bt（按钮）那份，filterMode 不一样
        patterns.append((target.parent, f"*{family}*bg_en.png.meta"))
    patterns += [
        (target.parent, f"*{family}*_en.png.meta"),   # 同族英文图
        (target.parent, "*_bg_en.png.meta"),          # 至少同是 bg 类
        (ZH_DIR, "*_bg_zh.png.meta"),                 # 退到中文同族
        (target.parent, "*.png.meta"),                # 兜底
    ]
    template = None
    for folder, pat in patterns:
        hits = [p for p in sorted(folder.glob(pat)) if p != meta]
        if hits:
            template = hits[0]
            break
    if template is None:
        return "⚠ 同目录没有可参照的 .meta，需要 Unity 重新导入生成"

    text = _fresh_meta_ids(template.read_text(encoding="utf-8"))
    meta.write_text(text, encoding="utf-8")
    return f"按 {template.name} 模板生成（新 guid/spriteID）"


def cmd_publish(args) -> int:
    work = Path(args.work)
    state = json.loads((work / "state.json").read_text(encoding="utf-8"))
    if not (state.get("verified") or {}).get("ok") and not args.force:
        print("验收没过，拒绝写回（--force 可强写）", file=sys.stderr)
        return 1

    # 🔴 目标路径**按当前规则重算**，不信 state.json 里的旧值：
    #    规则改过（比如 en 侧改成平铺）之后，旧 state 会把人带回老位置，
    #    出现「图写进去了、但目录不在 resPathList ⇒ 白图」这种只有真机才能发现的错。
    fam = state.get("family") or FAMILY_ARTFONT
    zh = ROOT / state["asset"]
    target = en_path_for(zh, fam)
    state["en"] = str(target.relative_to(ROOT))

    ok_reg, note_reg = check_target_registered(target)
    if not ok_reg:
        print(note_reg, file=sys.stderr)
        return 1

    target.parent.mkdir(parents=True, exist_ok=True)

    backup = None
    if target.exists():
        if not args.force:
            print(f"⚠ 目标已存在，跳过：{state['en']}（--force 覆盖）", file=sys.stderr)
            return 3
        backup = BACKUP_ROOT / Path(state["en"]).relative_to("Assets")
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, backup)

    shutil.copyfile(work / "out.png", target)
    # atlas / glyph / poster：中文源图自己的 .meta 就是最准的模板
    # （同一张图、同一份导入设置）；artfont 横幅仍按「同族 bg_en」挑，见 ensure_meta 注释。
    meta_hint = ROOT / state["asset"] if fam in (FAMILY_ATLAS, FAMILY_GLYPH,
                                                 FAMILY_POSTER) else None
    meta_note = ensure_meta(target, meta_hint)

    res_name = target.stem
    state["published"] = {
        "target": state["en"],
        "res_name": res_name,
        "res_name_registered": res_name_registered(res_name),
        "provider": state.get("provider") or PROVIDER_LOCAL,
        "backup": str(backup.relative_to(ROOT)) if backup else None,
        "sha256": sha256(target),
        "size": target.stat().st_size,
        "meta": meta_note,
    }
    (work / "state.json").write_text(json.dumps(state, ensure_ascii=False, indent=2),
                                     encoding="utf-8")

    print(f"写回 : {state['en']}  ({state['published']['size']} bytes)")
    print(f"目录 : {note_reg}")
    print(f"meta : {meta_note}")
    if not state["published"]["res_name_registered"]:
        print(f"⏳ resName `{res_name}` 还没进 ResourcePathConfig —— 图就位但**客户端找不到**。")
        print(f"   生效动作：重打 `{Path(state['en']).parent.as_posix()}` 所在 AB"
              f"（TS-Resource-Build，REBUILD_AB=true），重扫时 CreateResourcePathConfig 会登记它。")
    else:
        print(f"resName `{res_name}` 已登记（仍需重打 AB 才能把新图打进包）")
    if backup:
        print(f"原图 : 已备份到 {state['published']['backup']}")
    if args.run:
        register(args.run, f"写回·{Path(state['asset']).stem}", "pass", "交付",
                 state["en"])
    return 0


# --------------------------------------------------------------------------- #
# 子命令：batch
# --------------------------------------------------------------------------- #
def atlas_targets(mapping: dict) -> list[Path]:
    """atlas 家族没有「扫全目录」的余地：图集里绝大多数图没有中文要翻。
    译名表就是白名单 —— 表里有 lines 的才做，且源图必须真的存在。"""
    out: list[Path] = []
    for name, entry in mapping.items():
        if name.startswith("_") or not entry.get("lines"):
            continue
        for hit in ATLAS_ROOT.rglob(name):
            out.append(hit)
    return sorted(out)


def glyph_targets(mapping: dict) -> list[Path]:
    """glyph 家族的候选：译名表里给了 title/lines 的条目，到 ArtFont_zh 下找同名文件。

    理由和 atlas 一样：ArtFont_zh 下几千张图，绝大多数是纯图或别族资源，**不能扫全目录**
    （`_is_glyph` 要逐张开图判色，扫全目录要几分钟）。译名表就是白名单。
    """
    out: list[Path] = []
    for name, entry in mapping.items():
        if name.startswith("_") or not (entry.get("lines") or entry.get("title")):
            continue
        for hit in ZH_ROOT.rglob(name):
            if hit.name.endswith("_zh.png") and _is_glyph(hit):
                out.append(hit)
    return sorted(out)


def poster_targets(mapping: dict) -> list[Path]:
    """poster 族同样走白名单（译名表里有 lines 才算）。

    banner/ 下 18 张海报，多数还没译名；扫全目录只会把「缺译名」刷成一片黄。
    """
    out: list[Path] = []
    for name, entry in mapping.items():
        if name.startswith("_") or not (entry.get("lines") or entry.get("title")):
            continue
        for hit in ZH_ROOT.rglob(name):
            if hit.name.endswith("_zh.png") and _is_poster(hit):
                out.append(hit)
    return sorted(out)


def _name_keys(zh: Path) -> set[str]:
    """`--only` 的可接受写法：带扩展名、不带扩展名、去掉 _zh 后缀，三种都认。

    atlas 家族的源图**没有** `_zh` 后缀（cn2-X1_kuafu_rukou.png），
    以前只比 `name[:-len("_zh.png")]`，会把它的名字剁成 cn2-X1_kuafu_ 直接失配，
    于是 ②③④ 全绿但一张图都没做 —— 假绿球。
    """
    keys = {zh.name, zh.stem}
    if zh.name.endswith("_zh.png"):
        keys.add(zh.name[: -len("_zh.png")])
    return keys


def cmd_batch(args) -> int:
    """批量跑一个阶段：run / verify / publish 分开调用，方便在 Jenkins 里各占一个 stage。

    每张图单独登记一条环节结论，构建页一眼看清是哪张红的。
    --asset 直接指定一张（MODE=one），不再走目录扫描 —— 这样 Atlas 家族的图
    也能和战令横幅共用同一条流水线。
    """
    mapping = load_map()
    only = {s.strip() for s in args.only.split(",") if s.strip()} if args.only else None
    family = getattr(args, "family", "auto") or "auto"

    def wanted(zh: Path) -> bool:
        if not only:
            return True
        return bool(_name_keys(zh) & only)

    stage = args.stage

    # ---- 选目标 ---------------------------------------------------------- #
    targets: list[Path] = []
    skipped: list[str] = []
    notitle: list[str] = []
    if args.asset:
        zh = (ROOT / args.asset) if not Path(args.asset).is_absolute() else Path(args.asset)
        zh = zh.resolve()
        if not zh.exists():
            print(f"源图不存在：{zh}", file=sys.stderr)
            return 1
        targets = [zh]
    elif stage == "run":
        pool: list[Path] = []
        if family in ("auto", FAMILY_ARTFONT):
            pool += sorted(ZH_DIR.glob(BANNER_GLOB))
        if family in ("auto", FAMILY_GLYPH):
            pool += glyph_targets(mapping)
        if family in ("auto", FAMILY_POSTER):
            pool += poster_targets(mapping)
        if family in ("auto", FAMILY_ATLAS):
            pool += atlas_targets(mapping)
        seen: set[Path] = set()
        pool = [p for p in pool if not (p in seen or seen.add(p))]
        for zh in pool:
            if not wanted(zh):
                continue
            fam = _pick_family(zh, family)
            if en_path_for(zh, fam).exists() and not args.force:
                skipped.append(zh.name)
                continue
            entry = mapping.get(zh.name) or {}
            if not entry.get("lines") and not entry.get("title"):
                notitle.append(zh.name)
                continue
            targets.append(zh)
    else:
        for stf in sorted(WORK_ROOT.glob("*/state.json")) if WORK_ROOT.exists() else []:
            st = json.loads(stf.read_text(encoding="utf-8"))
            zh_name = Path(st["asset"]).name
            if only and not (_name_keys(Path(zh_name)) & only):
                continue
            zh = ROOT / st["asset"]
            if not zh.exists():
                continue
            if stage == "verify" and (st.get("verified") is None or args.force):
                targets.append(zh)
            elif stage == "publish":
                if not (st.get("verified") or {}).get("ok"):
                    skipped.append(zh_name + "（验收未过）")
                    continue
                fam = st.get("family") or _pick_family(zh, None)
                if en_path_for(zh, fam).exists() and not args.force:
                    skipped.append(zh_name + "（已有英文版）")
                    continue
                targets.append(zh)

    print(f"[{stage}] 目标 {len(targets)} 张；跳过 {len(skipped)} 张；缺译名 {len(notitle)} 张")
    for s in skipped:
        print(f"  ⏭  {s}")
    for s in notitle:
        print(f"  ⚠  {s}（banner_translate_map.json 缺译名）")
    if args.run and notitle:
        register(args.run, "缺译名清单", "warn", "美术翻译链", "、".join(notitle))

    # ---- 逐张执行 -------------------------------------------------------- #
    failures = 0
    for zh in targets:
        fam = _pick_family(zh, family)
        work = work_dir_for(zh, fam)
        stem = zh.stem if fam == FAMILY_ATLAS else zh.name[: -len("_zh.png")]
        print(f"\n── [{stage}] {zh.name}（{fam}）──")
        if stage == "run":
            rc = cmd_run(argparse.Namespace(
                asset=str(zh), title=None, lines=None, work=None, family=fam,
                provider=getattr(args, "provider", PROVIDER_LOCAL),
                gen_image=getattr(args, "gen_image", ""),
                cdp_port=getattr(args, "cdp_port", 0),
                adspower_profiles=getattr(args, "adspower_profiles", ""),
                provider_timeout=getattr(args, "provider_timeout", 0),
                ignore_ledger=getattr(args, "ignore_ledger", False),
                no_auto_fallback=getattr(args, "no_auto_fallback", False)))
            if rc == 3:
                if args.run:
                    register(args.run, f"生成·{stem}", "warn", "美术翻译链",
                             "缺译名 / 尺寸异常 / 出图环境不可用，已跳过")
            elif rc != 0:
                failures += 1
                if args.run:
                    register(args.run, f"生成·{stem}", "fail", "美术翻译链",
                             "没有译名、源图不可用或出图通道硬失败")
        elif stage == "verify":
            rc = cmd_verify(argparse.Namespace(work=str(work), run=args.run))
            if rc != 0:
                failures += 1
        else:
            rc = cmd_publish(argparse.Namespace(work=str(work), yes=True,
                                                force=args.force, run=args.run))
            if rc == 1:
                failures += 1

    return 1 if failures else (3 if notitle else 0)


# --------------------------------------------------------------------------- #
# 环节报告
# --------------------------------------------------------------------------- #
def register(run_dir: str, name: str, status: str, group: str, detail: str) -> None:
    """把结论登记进 .jenkins/lib/stage_report.py；登记失败不影响业务退出码。"""
    if not run_dir:
        return
    try:
        subprocess.run(
            [sys.executable, str(REPORT), "add", "--run", run_dir, "--name", name,
             "--status", status, "--group", group, "--detail", detail],
            cwd=str(ROOT), check=False, capture_output=True, timeout=60,
        )
    except Exception:  # noqa: BLE001 —— 报告失败不能污染流水线结论
        pass


def _add_provider_args(p: argparse.ArgumentParser) -> None:
    """出图 provider 的公共参数（run / batch 共用，免得两处漂移）。"""
    p.add_argument("--provider", default=PROVIDER_LOCAL, choices=PROVIDERS,
                   help="chatgpt_web=Chrome/AdsPower 驱动 GPT 重绘（绘图管线，glyph 族必需）；"
                        "local=本地像素工序（原行为）；manual=用 --gen-image 交现成图")
    p.add_argument("--gen-image", default="", help="provider=manual 时直接用的出图（跳过浏览器）")
    p.add_argument("--cdp-port", type=int, default=0,
                   help="复用已登录浏览器的 CDP 端口（find_browser_cdp.py 反查）")
    p.add_argument("--adspower-profiles", default="",
                   help="换号顺序（逗号分隔的 AdsPower user_id），留空=按台账自动排")
    p.add_argument("--provider-timeout", type=int, default=0,
                   help="等图上限（秒）；0=用 gen_chatgpt_web.py 的默认值")
    p.add_argument("--ignore-ledger", action="store_true", help="忽略额度台账（验证某个号时用）")
    p.add_argument("--no-auto-fallback", action="store_true", help="额度用尽不自动换号")


def main() -> int:
    ap = argparse.ArgumentParser(description="中文美术字 → 英文版（战令横幅 / 图集大图 / 美术字块）")
    sub = ap.add_subparsers(dest="cmd", required=True)

    fam_help = "auto=按源图特征判断（Atlas/→atlas；小型单色字块→glyph；其余 artfont）"

    p = sub.add_parser("scan", help="列出缺英文版的资源")
    p.add_argument("--json", action="store_true")
    p.add_argument("--quiet", action="store_true", help="只打一行汇总（收尾复核用）")
    p.add_argument("--run", default="", help="Jenkins 证据目录（登记环节结论用）")
    p.add_argument("--strict-ok", action="store_true", help="即使有缺失也返回 0")
    p.add_argument("--family", default="auto", choices=["auto", FAMILY_ARTFONT, FAMILY_GLYPH, FAMILY_POSTER, FAMILY_ATLAS],
                   help=fam_help)
    p.set_defaults(func=cmd_scan)

    p = sub.add_parser("run", help="生成一张英文版（不写回工程）")
    p.add_argument("--asset", required=True)
    p.add_argument("--title", default="")
    p.add_argument("--lines", default="", help='用 | 分隔，如 "UNLOCK|ADVANCED|BATTLE PASS"')
    p.add_argument("--work", default="")
    p.add_argument("--family", default="auto", choices=["auto", FAMILY_ARTFONT, FAMILY_GLYPH, FAMILY_POSTER, FAMILY_ATLAS],
                   help=fam_help)
    _add_provider_args(p)
    p.set_defaults(func=cmd_run)

    p = sub.add_parser("verify", help="像素级验收")
    p.add_argument("--work", required=True)
    p.add_argument("--run", default="")
    p.set_defaults(func=cmd_verify)

    p = sub.add_parser("publish", help="写回 ArtFont_en 并补 .meta")
    p.add_argument("--work", required=True)
    p.add_argument("--yes", action="store_true")
    p.add_argument("--force", action="store_true")
    p.add_argument("--run", default="")
    p.set_defaults(func=cmd_publish)

    p = sub.add_parser("batch", help="批量跑一个阶段（run / verify / publish）")
    p.add_argument("--stage", choices=["run", "verify", "publish"], default="run")
    p.add_argument("--only", default="", help="只跑指定资源（逗号分隔，可不带 _zh.png）")
    p.add_argument("--asset", default="", help="只跑这一张（相对工程根，MODE=one 用）")
    p.add_argument("--force", action="store_true", help="已有英文版 / 已验收过也重做")
    p.add_argument("--run", default="")
    p.add_argument("--family", default="auto", choices=["auto", FAMILY_ARTFONT, FAMILY_GLYPH, FAMILY_POSTER, FAMILY_ATLAS],
                   help=fam_help)
    _add_provider_args(p)
    p.set_defaults(func=cmd_batch)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
