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

为什么不用 AI 擦字/生图
----------------------
`connect_cloud_service` 拿不到临时凭证，图像处理 skill 的云端通道也不可用；
本项目「翻译图片 skill」并不存在（市场搜索接口 404）。纯本地 OpenCV/PIL 可控、可重跑、
可断言，比一次性的云端结果更适合进 CI。

用法
----
    python scripts/image/banner_translate.py scan
    python scripts/image/banner_translate.py run    --asset <zh 相对路径>
    python scripts/image/banner_translate.py verify --work <工作目录>
    python scripts/image/banner_translate.py publish --work <工作目录> --yes
    python scripts/image/banner_translate.py batch  [--only a,b] [--no-write] [--force]

退出码：0 全通过；3 有「需人看一眼」的项（缺译名 / 已存在跳过）；1 硬失败。
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
ZH_DIR = ROOT / "Assets/ManagedResources/ArtFont_zh/OperatingPanelAtlas"
EN_DIR = ROOT / "Assets/ManagedResources/ArtFont_en/OperatingPanelAtlas"
MAP_FILE = ROOT / "scripts/image/banner_translate_map.json"
WORK_ROOT = ROOT / "_output/art_translate"
BACKUP_ROOT = ROOT / "ResBackpack/备份"
REPORT = ROOT / ".jenkins/lib/stage_report.py"

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


def en_path_for(zh_path: Path) -> Path:
    """cn2-X1_zhanling_miwu_bg_zh.png → ArtFont_en/OperatingPanelAtlas/cn2-X1_zhanling_miwu_bg_en.png"""
    name = zh_path.name
    if not name.endswith("_zh.png"):
        raise SystemExit(f"不是 _zh.png 命名：{name}")
    return EN_DIR / (name[: -len("_zh.png")] + "_en.png")


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
# 子命令：scan
# --------------------------------------------------------------------------- #
def cmd_scan(args) -> int:
    mapping = load_map()
    rows, todo, notitle = [], [], []
    for zh in sorted(ZH_DIR.glob(BANNER_GLOB)):
        en = en_path_for(zh)
        entry = mapping.get(zh.name) or {}
        has_en = en.exists()
        has_title = bool(entry.get("title"))
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
            if r["en_exists"]:
                flag = "✅已有"
            elif r["title"]:
                flag = "⏳待译"
            else:
                flag = "⚠缺译名"
            print(f"{flag:<8}{Path(r['asset']).name:<52}{r['title'] or '—'}")
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
def work_dir_for(zh: Path) -> Path:
    return WORK_ROOT / zh.name[: -len("_zh.png")]


def cmd_run(args) -> int:
    zh = (ROOT / args.asset).resolve() if not Path(args.asset).is_absolute() else Path(args.asset)
    if not zh.exists():
        print(f"源图不存在：{zh}", file=sys.stderr)
        return 1

    entry = load_map().get(zh.name, {})
    title = args.title or entry.get("title") or ""
    lines = args.lines.split("|") if args.lines else entry.get("lines") or []
    if not title or not lines:
        print(f"⚠ {zh.name} 没有译名：请在 {MAP_FILE.relative_to(ROOT)} 里补 title/lines，"
              f"或用 --title/--lines 传", file=sys.stderr)
        return 3

    # 尺寸闸门：这批横幅都是 884x544。工程里有几张同名占位图只有 100x100，
    # 直接跑会在补底板时炸出形状不匹配，所以先挡掉（rc=3 只标黄，不算失败）。
    with Image.open(zh) as probe:
        if probe.size[0] < 600 or probe.size[1] < 400:
            print(f"⚠ {zh.name} 尺寸异常（{probe.size[0]}x{probe.size[1]}），不是可翻译的横幅，跳过",
                  file=sys.stderr)
            return 3

    work = Path(args.work) if args.work else work_dir_for(zh)
    work.mkdir(parents=True, exist_ok=True)
    src = work / "src.png"
    shutil.copyfile(zh, src)

    src_im = Image.open(src)
    alpha_orig = src_im.getchannel("A") if src_im.mode == "RGBA" else None
    a = np.asarray(src_im.convert("RGB"))

    t0 = time.time()
    panel, zone = rebuild_panel(a)
    (work / "panel.png").write_bytes(b"")  # 占位，下面覆盖
    Image.fromarray(panel).save(work / "panel.png")
    out = draw_text(Image.fromarray(panel), title, lines, zone)
    if alpha_orig is not None:
        out = out.convert("RGB")
        out.putalpha(alpha_orig)
    out.save(work / "out.png")

    # 中英对照图（构建页直接能看）
    zh_im = Image.open(src).convert("RGB")
    en_im = Image.open(work / "out.png").convert("RGB")
    w, h = zh_im.size
    canvas = Image.new("RGB", (w * 2 + 16, h + 34), (250, 250, 252))
    canvas.paste(zh_im, (0, 34))
    canvas.paste(en_im, (w + 16, 34))
    d = ImageDraw.Draw(canvas)
    f = load_font(18)
    d.text((10, 8), "ZH (source)", font=f, fill=(30, 30, 40))
    d.text((w + 26, 8), "EN (generated)", font=f, fill=(30, 30, 40))
    canvas.save(work / "compare.png")

    state = {
        "asset": str(zh.relative_to(ROOT)),
        "en": str(en_path_for(zh).relative_to(ROOT)),
        "title": title,
        "lines": lines,
        "zone": list(zone),
        "size": list(src_im.size),
        "mode": src_im.mode,
        "src_sha256": sha256(src),
        "out_sha256": sha256(work / "out.png"),
        "elapsed": round(time.time() - t0, 2),
        "verified": None,
        "published": None,
    }
    (work / "state.json").write_text(json.dumps(state, ensure_ascii=False, indent=2),
                                     encoding="utf-8")

    print(f"源图   : {state['asset']}  {state['size'][0]}x{state['size'][1]} {state['mode']}")
    print(f"重建区 : y {zone[0]}..{zone[1]}  x {zone[2]}..{zone[3]}")
    print(f"译名   : {title} / {' | '.join(lines)}")
    print(f"输出   : {work / 'out.png'}  ({state['elapsed']}s)")
    return 0


# --------------------------------------------------------------------------- #
# 子命令：verify
# --------------------------------------------------------------------------- #
def cmd_verify(args) -> int:
    work = Path(args.work)
    state = json.loads((work / "state.json").read_text(encoding="utf-8"))
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

    ok = all(c[1] for c in checks)
    print(f"验收：{state['asset']}")
    for name, passed, detail in checks:
        print(f"  {'✅' if passed else '❌'} {name}  —— {detail}")

    state["verified"] = {"ok": ok, "checks": [{"name": n, "pass": p, "detail": d}
                                              for n, p, d in checks]}
    (work / "state.json").write_text(json.dumps(state, ensure_ascii=False, indent=2),
                                     encoding="utf-8")
    if args.run:
        failed = [n for n, p, _ in checks if not p]
        register(args.run, f"验收·{Path(state['asset']).stem}", "pass" if ok else "fail",
                 "美术翻译链", "全部通过" if ok else "未过：" + "、".join(failed))
    return 0 if ok else 1


# --------------------------------------------------------------------------- #
# 子命令：publish
# --------------------------------------------------------------------------- #
def ensure_meta(target: Path) -> str:
    """目标 png 缺 .meta 时，从同族资源复制一份并换新 guid。

    模板必须挑**同族**的：实测同目录 `chaozhijj_diban_en` 与 `zhanling_pata_bg_en` 的导入设置
    差了 filterMode / spriteMeshType / applyGammaDecoding / 平台 override 四项，
    随便抓第一份会让横幅在 Unity 里糊掉或走错压缩口径。
    """
    meta = Path(str(target) + ".meta")
    if meta.exists():
        return "已存在，保持原 guid"

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

    text = template.read_text(encoding="utf-8")
    text = re.sub(r"^guid: .*$", "guid: " + uuid.uuid4().hex, text, count=1, flags=re.M)
    meta.write_text(text, encoding="utf-8")
    return f"按 {template.name} 模板生成（新 guid）"


def cmd_publish(args) -> int:
    work = Path(args.work)
    state = json.loads((work / "state.json").read_text(encoding="utf-8"))
    if not (state.get("verified") or {}).get("ok") and not args.force:
        print("验收没过，拒绝写回（--force 可强写）", file=sys.stderr)
        return 1

    target = ROOT / state["en"]
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
    meta_note = ensure_meta(target)

    state["published"] = {
        "target": state["en"],
        "backup": str(backup.relative_to(ROOT)) if backup else None,
        "sha256": sha256(target),
        "size": target.stat().st_size,
        "meta": meta_note,
    }
    (work / "state.json").write_text(json.dumps(state, ensure_ascii=False, indent=2),
                                     encoding="utf-8")

    print(f"写回 : {state['en']}  ({state['published']['size']} bytes)")
    print(f"meta : {meta_note}")
    if backup:
        print(f"原图 : 已备份到 {state['published']['backup']}")
    if args.run:
        register(args.run, f"写回·{Path(state['asset']).stem}", "pass", "交付",
                 state["en"])
    return 0


# --------------------------------------------------------------------------- #
# 子命令：batch
# --------------------------------------------------------------------------- #
def cmd_batch(args) -> int:
    """批量跑一个阶段：run / verify / publish 分开调用，方便在 Jenkins 里各占一个 stage。

    每张图单独登记一条环节结论，构建页一眼看清是哪张红的。
    """
    mapping = load_map()
    only = {s.strip() for s in args.only.split(",") if s.strip()} if args.only else None

    def wanted(zh: Path) -> bool:
        if not only:
            return True
        return zh.name in only or zh.name[: -len("_zh.png")] in only

    stage = args.stage

    # ---- 选目标 ---------------------------------------------------------- #
    targets: list[Path] = []
    skipped: list[str] = []
    notitle: list[str] = []
    if stage == "run":
        for zh in sorted(ZH_DIR.glob(BANNER_GLOB)):
            if not wanted(zh):
                continue
            if en_path_for(zh).exists() and not args.force:
                skipped.append(zh.name)
                continue
            if not (mapping.get(zh.name) or {}).get("title"):
                notitle.append(zh.name)
                continue
            targets.append(zh)
    else:
        for work in sorted(WORK_ROOT.glob("*/state.json")) if WORK_ROOT.exists() else []:
            st = json.loads(work.read_text(encoding="utf-8"))
            zh_name = Path(st["asset"]).name
            if not wanted(Path(zh_name)):
                continue
            zh = ZH_DIR / zh_name
            if not zh.exists():
                continue
            if stage == "verify" and (st.get("verified") is None or args.force):
                targets.append(zh)
            elif stage == "publish":
                if not (st.get("verified") or {}).get("ok"):
                    skipped.append(zh_name + "（验收未过）")
                    continue
                if en_path_for(zh).exists() and not args.force:
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
        work = work_dir_for(zh)
        stem = zh.name[: -len("_zh.png")]
        print(f"\n── [{stage}] {zh.name} ──")
        if stage == "run":
            rc = cmd_run(argparse.Namespace(asset=str(zh), title=None, lines=None,
                                            work=None))
            if rc == 3:
                if args.run:
                    register(args.run, f"生成·{stem}", "warn", "美术翻译链",
                             "缺译名或尺寸异常，已跳过")
            elif rc != 0:
                failures += 1
                if args.run:
                    register(args.run, f"生成·{stem}", "fail", "美术翻译链",
                             "没有译名或源图不可用")
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


def main() -> int:
    ap = argparse.ArgumentParser(description="战令横幅中文美术字 → 英文版")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("scan", help="扫描 ArtFont_zh，列出缺英文版的资源")
    p.add_argument("--json", action="store_true")
    p.add_argument("--quiet", action="store_true", help="只打一行汇总（收尾复核用）")
    p.add_argument("--run", default="", help="Jenkins 证据目录（登记环节结论用）")
    p.add_argument("--strict-ok", action="store_true", help="即使有缺失也返回 0")
    p.set_defaults(func=cmd_scan)

    p = sub.add_parser("run", help="生成一张英文版（不写回工程）")
    p.add_argument("--asset", required=True)
    p.add_argument("--title", default="")
    p.add_argument("--lines", default="", help='用 | 分隔，如 "UNLOCK|ADVANCED|BATTLE PASS"')
    p.add_argument("--work", default="")
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
    p.add_argument("--force", action="store_true", help="已有英文版 / 已验收过也重做")
    p.add_argument("--run", default="")
    p.set_defaults(func=cmd_batch)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
