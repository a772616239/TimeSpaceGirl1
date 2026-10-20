#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""UI 美术资源「换节日风格」流水线 —— 确定性部分。

职责边界
--------
本脚本**不生成图片**。生图由 provider 完成（Agent 图像模型 / chatgpt.com / 任何能出图的通道），
产出一张图丢进 work 目录即可。这里只做后面所有可以断言的事：

    prepare     校验源资源、记录基线（尺寸 / 模式 / alpha 覆盖率 / 哈希）
    postprocess 去水印 → 等比 cover 到原图尺寸（绝不拉伸）→ 出「不透明版 + 沿用原 alpha 版」
    verify      像素级验收：尺寸、模式、水印残留、alpha 覆盖率、对比图
    graph       把各环节结果渲染成 mermaid 节点图（Jenkins 侧的可视化补充）
    publish     可选：写回原资源 —— **原图搬出工程**到 ResBackpack/备份，再覆盖，.meta 不动
    restore     从 ResBackpack/备份 回滚（publish 的反向操作，支持 --list 看版本）

为什么生图要摘出去
------------------
生图不可复现、有随机性、还可能因为网络/额度失败；把「不可复现的一步」和「必须可断言的九步」
分开，Jenkins 才能对后者做红绿判定。provider 失败就只红一个节点，不会污染其余证据。

用法
----
    restyle_pipeline.py themes
    restyle_pipeline.py prompt --theme christmas
    restyle_pipeline.py prepare --asset Assets/.../xxx.png --theme christmas
    restyle_pipeline.py postprocess --work DIR --gen DIR/inbox/gen.png
    restyle_pipeline.py verify --work DIR
    restyle_pipeline.py graph --work DIR --out DIR/graph.md
    restyle_pipeline.py publish --work DIR --variant alpha --yes

退出码：0 通过 / 1 失败 / 2 用法错误 / 3 需要人看一眼（黄，不阻断）
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import shutil
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np                                         # noqa: E402
from PIL import Image, ImageDraw, ImageFilter               # noqa: E402

import watermark_clean                                     # noqa: E402

PRESETS = Path(__file__).resolve().parent / "theme_presets.json"
WORK_ROOT = ROOT / "_output" / "art_restyle"
# 🔴 原图搬出工程放这里（.gitignore 已收）：Assets 里只留当前生效版本，
#    历史原件按资源相对路径镜像存放，restore 能原样还回去。
BACKUP_ROOT = ROOT / "ResBackpack" / "备份"

RC_OK, RC_FAIL, RC_USAGE, RC_WARN = 0, 1, 2, 3


# ----------------------------------------------------------------------------- 基础设施
def load_presets() -> dict:
    return json.loads(PRESETS.read_text(encoding="utf-8"))


def theme_of(name: str) -> dict:
    presets = load_presets()
    themes = presets["themes"]
    if name not in themes:
        raise SystemExit(f"未知主题 {name!r}；可选：{', '.join(themes)}")
    return {**presets.get("defaults", {}), **themes[name], "key": name}


def slug_of(path: Path) -> str:
    return path.stem.replace(" ", "_")


# ----------------------------------------------------------------------------- 提示词拼装
# 🔴 提示词不能把文案写死。底板资源每张的文字都不同（8-DAY / 50x Rebate / …），
#    写死一次就会在下一张图上画出上一张的字 —— 这是本管线最贵的错误（废一张图 = 一次额度 + 30 分钟）。
PROMPT_TEMPLATE = """Restyle this mobile-game UI panel asset into {theme_en} style, {frame}.

{heading}
{layout}

TEXT: keep every glyph complete, sharp and readable; restyle the material only - {text_style}.

CHARACTER: {character}

EMPTY BODY: {body}.

MOOD: {decor_sentence}; the upper banner background becomes {banner}. Rich glossy high-contrast mobile-game key art, crisp 2D anime illustration, sharp edges, cinematic lighting, no watermark, no extra text, no logos."""


# 构图自由度。lock = 老行为（姿势/位置/缩放全锁死），free = 允许重设计人物姿势换吸引力。
# 🔴 free 不是「随便画」：它只放开「人」，仍然锁死三件功能约束（文案完整、底部空白区、
#    画布比例与透明边）。放开的是美术，不是 UI 契约。
COMPOSITIONS = {
    "lock": {
        "frame": "keeping the EXACT same composition, layout, proportions, camera framing "
                 "and visual hierarchy as the input image",
        "heading": "LAYOUT_LOCK (must not change):",
        "character": "keep the same pose, position, scale and silhouette; change the outfit into {outfit}.",
    },
    "free": {
        "frame": "re-composing the artwork freely for maximum visual appeal and stopping power, "
                 "while keeping the panel's UI function intact",
        "heading": "FRAME_RULES (functional constraints that must not change):",
        "character": ("redesign the character for far stronger appeal: a new, dynamic, inviting pose "
                      "and a more attractive camera angle - position, crop and scale may all change - "
                      "with an expressive gesture and lively hair/cloth motion{pose_hint}; keep the "
                      "SAME character identity (same face design, same hair color and style, same eye "
                      "color, same art style and rendering quality) so it reads as the same heroine, "
                      "only much more attractive; restyle the outfit into {outfit}."),
    },
}


def build_prompt(name: str, layout: list[str] | None = None, composition: str | None = None) -> str:
    """把「主题字段 + 构图规则」拼成完整 prompt。

    主题只描述风格（配色 / 服装 / 空区 / 装饰），文案一律由 layout 锁死，
    这样同一个主题能套任意底板资源，不会串图。
    composition=free 时只放开人物姿态（见 COMPOSITIONS），文案与版式仍受锁。
    """
    presets = load_presets()
    theme = theme_of(name)
    if "prompt" in theme:            # 兼容：老数据里整段写死的 prompt
        return theme["prompt"]
    key = composition or presets.get("composition_default", "lock")
    if key not in COMPOSITIONS:
        raise SystemExit(f"未知 composition {key!r}；可选：{', '.join(COMPOSITIONS)}")
    comp = COMPOSITIONS[key]
    if layout:
        lines = layout
    else:
        # 老数据只有 layout_default(=lock)，free 缺失时回落到它，但打印警告
        lines = presets.get(f"layout_{key}") or presets.get("layout_default", [])
    return PROMPT_TEMPLATE.format(
        theme_en=theme.get("en", theme["zh"]),
        frame=comp["frame"],
        heading=comp["heading"],
        layout="\n".join(f"{i}) {ln}" if not ln[:2].strip().rstrip(")").isdigit() else ln
                       for i, ln in enumerate(lines, 1)),
        text_style=theme["text_style"],
        character=comp["character"].format(
            outfit=theme["outfit"],
            pose_hint=(". Ideal pose: " + theme["pose_hint"]) if theme.get("pose_hint") else ""),
        body=theme["body"],
        banner=theme["banner"],
        decor_sentence=theme["decor_sentence"],
    )


def work_dir(asset: Path, theme: str, override: str | None = None) -> Path:
    if override:
        return Path(override).expanduser().resolve()
    return WORK_ROOT / slug_of(asset) / theme


def state_path(work: Path) -> Path:
    return work / "state.json"


def read_state(work: Path) -> dict:
    p = state_path(work)
    if not p.exists():
        raise SystemExit(f"{work} 里没有 state.json —— 先跑 prepare")
    return json.loads(p.read_text(encoding="utf-8"))


def write_state(work: Path, state: dict) -> None:
    state_path(work).write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def log(stage: str, msg: str) -> None:
    print(f"[{stage}] {msg}")


def materialize(ref: str, work: Path, tag: str) -> Path:
    """把「参照图」参数解析成真实文件。

    支持 `git:<ref>:<path>` 写法 —— 资源已经被换过一次、工作区里再没有原版时，
    这是唯一能拿到「改前」和「原 alpha」的途径，比让人手动 git show 成临时文件可靠。
    """
    if not ref.startswith("git:"):
        return Path(ref).expanduser()
    _, rev, path = ref.split(":", 2)
    out = work / "src" / f"_{tag}.png"
    import subprocess
    r = subprocess.run(["git", "show", f"{rev}:{path}"], cwd=ROOT, capture_output=True)
    if r.returncode != 0:
        raise SystemExit(f"git show {rev}:{path} 失败：{r.stderr.decode()[:200]}")
    out.write_bytes(r.stdout)
    log("prepare", f"从 git 取回参照图 {rev}:{path} → {out.name}")
    return out


# ----------------------------------------------------------------------------- prepare
def cmd_prepare(args) -> int:
    asset = (ROOT / args.asset).resolve() if not Path(args.asset).is_absolute() else Path(args.asset)
    if not asset.exists():
        log("prepare", f"🔴 源资源不存在：{asset}")
        return RC_FAIL
    theme = theme_of(args.theme)
    work = work_dir(asset, args.theme, args.work)
    (work / "src").mkdir(parents=True, exist_ok=True)
    (work / "out").mkdir(parents=True, exist_ok=True)
    (work / "inbox").mkdir(parents=True, exist_ok=True)

    im = Image.open(asset)
    if im.mode not in ("RGBA", "RGB"):
        log("prepare", f"⚠ 非常规模式 {im.mode}，按 RGBA 处理")

    # 「改前」参照：默认就是资源本身。资源已经被换过一次、要重跑时，
    # 用 --source-from 指 git 里的原版，否则对比图会变成「圣诞版 vs 圣诞版」。
    source_ref = materialize(args.source_from, work, "source_from") if args.source_from else asset
    if not source_ref.is_file():
        log("prepare", f"🔴 --source-from 不存在：{source_ref}")
        return RC_FAIL

    rgba = Image.open(source_ref).convert("RGBA")
    alpha = rgba.getchannel("A")
    hist = alpha.histogram()
    total = rgba.width * rgba.height
    coverage = sum(hist[1:]) / total

    # 🔴 alpha 参照可以另给：资源被压成 RGB（丢了浮层透明度）时，
    #    用 git 里的版本当参照，否则「沿用原 alpha」这个变体就退化成不透明整幅。
    alpha_ref = materialize(args.alpha_from, work, "alpha_from") if args.alpha_from else None
    if alpha_ref is not None:
        if not alpha_ref.is_file():
            log("prepare", f"🔴 --alpha-from 不存在：{alpha_ref}")
            return RC_FAIL
        ref = Image.open(alpha_ref).convert("RGBA")
        if ref.size != rgba.size:
            log("prepare", f"🔴 alpha 参照尺寸 {ref.size} 与资源 {rgba.size} 不一致")
            return RC_FAIL
        alpha = ref.getchannel("A")
        hist = alpha.histogram()
        coverage = sum(hist[1:]) / total

    # 源图落盘一份快照：后续所有比对都以它为准，避免管线中途源文件被改
    snap = work / "src" / "source.png"
    shutil.copy2(source_ref, snap)
    alpha.save(work / "src" / "source_alpha.png")

    # 提示词在这里就定版落盘：provider 出图、Agent 手工出图、事后复盘都用同一份字符串。
    layout = read_layout(args.layout, work)
    composition = getattr(args, "composition", None) or load_presets().get("composition_default", "lock")
    prompt = build_prompt(args.theme, layout, composition)
    (work / "prompt.txt").write_text(prompt + "\n", encoding="utf-8")

    state = {
        "asset": str(asset),
        "asset_rel": str(asset.relative_to(ROOT)) if str(asset).startswith(str(ROOT)) else str(asset),
        "asset_sha256": sha256(asset),
        "asset_meta": str(asset.with_suffix(asset.suffix + ".meta")),
        "theme": args.theme,
        "theme_zh": theme["zh"],
        "target": [rgba.width, rgba.height],
        "source_mode": Image.open(source_ref).mode,
        "source_ref": str(source_ref),
        "alpha_source": str(alpha_ref) if alpha_ref else str(source_ref),
        "alpha_coverage": round(coverage, 6),
        "pixels_partial_alpha": int(sum(hist[1:255])),
        "snapshot": str(snap),
        "work": str(work),
        "prompt_file": str(work / "prompt.txt"),
        "prompt_layout": "custom" if layout else "default",
        "composition": composition,
        "started_at": datetime.now().isoformat(timespec="seconds"),
        "stages": [],
    }
    write_state(work, state)

    print(f"  资源      : {state['asset_rel']}")
    print(f"  尺寸      : {rgba.width}x{rgba.height}  模式 {im.mode}")
    print(f"  alpha     : 透明 {100 * (1 - coverage):.2f}%  半透明 {state['pixels_partial_alpha']} px"
          f"（参照 {state['alpha_source']}）")
    print(f"  主题      : {args.theme}（{theme['zh']}）")
    print(f"  构图      : {composition}（{'人物可重设计' if composition == 'free' else '姿势/版式全锁'}）")
    print(f"  work      : {work}")
    if coverage > 0.999:
        print("  ⚠ 源资源是整幅不透明（没有浮层）。若它本该有透明区，"
              "用 --alpha-from <git 里的原版> 补参照后再出 alpha 变体")
    return RC_OK


# ----------------------------------------------------------------------------- prompt
def read_layout(spec: str | None, work: Path | None = None) -> list[str] | None:
    """--layout 可以是文件路径，也可以直接是多行文本。"""
    if not spec:
        return None
    p = Path(spec).expanduser()
    if p.is_file():
        lines = [ln.strip() for ln in p.read_text(encoding="utf-8").splitlines()]
        return [ln for ln in lines if ln]
    if work is not None:
        # 相对路径也认：先按「相对工程根」再按「相对 work 目录」
        for cand in (ROOT / spec, work / spec):
            if cand.is_file():
                lines = [ln.strip() for ln in cand.read_text(encoding="utf-8").splitlines()]
                return [ln for ln in lines if ln]
    return [ln.strip() for ln in spec.splitlines() if ln.strip()]


def cmd_prompt(args) -> int:
    theme = theme_of(args.theme)
    layout = read_layout(getattr(args, "layout", None))
    composition = getattr(args, "composition", None) or load_presets().get("composition_default", "lock")
    print(f"# theme={args.theme} size={theme.get('size')} quality={theme.get('quality')} "
          f"input_fidelity={theme.get('input_fidelity')} composition={composition}")
    print(build_prompt(args.theme, layout, composition))
    return RC_OK


def cmd_themes(args) -> int:
    presets = load_presets()
    print(f"{'key':12s} {'中文':8s} {'后缀':14s} 说明")
    for key, t in presets["themes"].items():
        print(f"{key:12s} {t['zh']:8s} {t['suffix']:14s} {', '.join(t.get('decoration', [])[:6])}")
    print(f"\n默认出图参数：{presets.get('defaults', {})}")
    return RC_OK


# ----------------------------------------------------------------------------- postprocess
def fit_cover(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """等比放大到刚好覆盖目标尺寸后居中裁切 —— 宽高比零失真（拉伸会让 UI 九宫格错位）。"""
    tw, th = size
    w, h = im.size
    scale = max(tw / w, th / h)
    nw, nh = round(w * scale), round(h * scale)
    im = im.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - tw) // 2, (nh - th) // 2
    return im.crop((left, top, left + tw, top + th))


def hex_rgb(h: str) -> tuple[float, float, float]:
    h = h.lstrip("#")
    return tuple(float(int(h[i:i + 2], 16)) for i in (0, 2, 4))


def _hblur_row(row: np.ndarray, width: int) -> np.ndarray:
    """把一行逐列颜色做横向平滑（保留大范围光晕，抹掉逐像素差异）。"""
    k = np.hanning(max(3, width))
    k = k / k.sum()
    return np.stack([np.convolve(row[:, c], k, mode="same") for c in range(3)], axis=1)


def synthetic_body(band: Image.Image, target: tuple[int, int], colors: list[str]) -> np.ndarray:
    """兜底：用「接缝色 → 主题上色 → 主题下色」合成下半截渐变。

    🔴 接缝色必须先横向平滑。逐列颜色直接纵向拉长 140px 会变成一条条竖光柱 ——
       实测把角色的腿拖成了光带（856x2048 超值底板第一次跑就踩了）。
    """
    W, H = target
    hb = band.height
    n = H - hb
    arr = np.array(band).astype(np.float32)
    seam = _hblur_row(arr[-4:].mean(axis=0), max(3, W // 25))[None, :, :]
    head = np.array(hex_rgb(colors[0]), dtype=np.float32)[None, None, :]
    end = np.array(hex_rgb(colors[-1]), dtype=np.float32)[None, None, :]
    head_n = max(8, min(int(n * 0.10), 120))
    t = np.linspace(0.0, 1.0, n).astype(np.float32)[:, None, None]
    t = t * (3.0 - 2.0 * t)
    body = np.empty((n, W, 3), dtype=np.float32)
    ramp = np.linspace(0.0, 1.0, head_n)[:, None, None]
    body[:head_n] = seam * (1 - ramp) + head * ramp
    body[head_n:] = head * (1 - t[head_n:]) + end * t[head_n:]
    rng = np.random.default_rng(20261020)
    return body + rng.normal(0.0, 1.2, body.shape).astype(np.float32)


def source_body(src_rgb: np.ndarray, hb: int, colors: list[str],
                src_alpha: np.ndarray | None = None) -> np.ndarray:
    """用**原资源下半截的大尺度明暗**调制主题渐变，而不是凭空造渐变。

    这类长条底板的下半截是「给 UI 用的空卡体」：一张自上而下变暗的渐变 + 暗角 + 噪点，
    几何（卡片硬切、暗角位置）跟上半截是配套的。保留它的大结构、换掉颜色，接缝才不会有
    「亮带子 / 黑卡体」的黑白切。

    🔴 只保留**大尺度**明暗（先降采样再放大回来）。逐像素按亮度重映射会把两样东西放大：
       1) 原图透明区 RGB 底下烤进去的**棋盘格**（导出时的透明度预览）；
       2) 点阵/噪点，在 856 宽的卡体上变成花斑。
       2026-10-20 超值底板下半截先出过蓝色花斑、再出过对称竖带，都是这个原因。
    🔴 亮度只拿来当**调制**（±20%），不直接铺满调色板：原卡体亮度区间很窄，
       铺满就成了「一块亮一块黑」，跟主题色也对不上。
    """
    if hb >= src_rgb.shape[0]:
        return np.zeros((0, src_rgb.shape[1], 3), dtype=np.float32)
    body = src_rgb[hb:].astype(np.float32)
    n, w = body.shape[:2]
    if src_alpha is not None:
        a = (src_alpha[hb:].astype(np.float32) / 255.0)[..., None]
        a = np.clip((a - 0.15) / 0.85, 0.0, 1.0)          # 极低 alpha 一律当 0
        mean = (body * a).sum(axis=(0, 1)) / max(float(a.sum()), 1e-3)
        body = body * a + mean[None, None, :] * (1 - a)

    lum = body.mean(axis=2)
    small = np.array(
        Image.fromarray(lum.clip(0, 255).astype(np.uint8))
        .resize((max(1, w // 40), max(1, n // 40)), Image.BOX)
        .resize((w, n), Image.BILINEAR),
        dtype=np.float32)
    lo, hi = np.percentile(small, 10), np.percentile(small, 90)
    t = np.clip((small - lo) / max(hi - lo, 1e-3), 0.0, 1.0)[..., None]

    c0 = np.array(hex_rgb(colors[0]), dtype=np.float32)
    c1 = np.array(hex_rgb(colors[-1]), dtype=np.float32)
    v = np.linspace(0.0, 1.0, n, dtype=np.float32)[:, None, None]
    grad = c0[None, None, :] * (1 - v) + c1[None, None, :] * v
    # 调制幅度压到 ±10%：原卡体底部有一道真实的亮度台阶（发光收边），
    # 调制一强就会在卡体中间留一条横线（2026-10-20 实测 ±20% 时肉眼可见）
    out = grad * (0.90 + 0.20 * t)
    return np.clip(out, 0, 255)


def compose_band(band: Image.Image, body: np.ndarray, blend: int = 0) -> Image.Image:
    """英雄带贴顶，下面接卡体。

    blend>0 时把带子的最后几行**原位**渐隐到卡体色（逐行对齐混合）。
    🔴 绝不能把最后一行往下广播做渐变：那一行是角色的身体，逐列颜色被纵向拉长
       就成了竖条纹光带（这个坑踩过两次，第一次在合成渐变、第二次在接缝渐隐）。
    """
    hb = band.height
    both = np.vstack([np.array(band).astype(np.float32), body.astype(np.float32)])
    n = body.shape[0]
    b = max(0, min(blend, hb, n))
    if b > 2:
        w = (np.linspace(1.0, 0.0, b) ** 1.4).astype(np.float32)[:, None, None]
        both[hb - b:hb] = both[hb - b:hb] * w + both[hb:hb + b] * (1 - w)
    return Image.fromarray(both.clip(0, 255).astype(np.uint8))


def fit_width(im: Image.Image, width: int) -> Image.Image:
    """只按宽度缩放（不动宽高比、不裁任何东西）。超长条底板改用它，避免 cover 横切。"""
    if im.width == width:
        return im
    h = round(im.height * width / im.width)
    return im.resize((width, h), Image.LANCZOS)


# --------------------------------------------------------------------- 边框（frame）
GOLD_DARK = (120, 78, 22)
GOLD_HI = (255, 232, 168)
FRAME_RED = (150, 20, 28)


def _metal_band(d, box, i0, i1, c0, c1, peak_at: float = 0.35) -> None:
    """沿矩形框画一条「金属剖面」色带：越靠近 peak_at 越亮，模拟受光的高光。"""
    w, h = box
    for i in range(i0, i1):
        t = (i - i0) / max(i1 - i0 - 1, 1)
        prof = max(0.0, 1 - abs(t - peak_at) / max(peak_at, 1 - peak_at)) ** 0.6
        c = tuple(int(c0[k] + (c1[k] - c0[k]) * prof) for k in range(3))
        d.rectangle([i, i, w - 1 - i, h - 1 - i], outline=c, width=1)


def _medallion(d, cx: float, cy: float, R: int) -> None:
    """四角徽章：暗底 -> 金环 -> 红心 -> 八角星。"""
    d.ellipse([cx - R - 2, cy - R - 2, cx + R + 2, cy + R + 2], fill=(26, 15, 4, 255))
    d.ellipse([cx - R, cy - R, cx + R, cy + R], fill=(158, 106, 36, 255))
    d.ellipse([cx - R + 4, cy - R + 4, cx + R - 4, cy + R - 4], fill=(212, 158, 66, 255))
    d.ellipse([cx - R + 6, cy - R + 6, cx + R - 6, cy + R - 6], fill=(120, 12, 18, 255))
    pts = []
    for k in range(16):
        ang = math.pi / 2 * (k / 4.0)
        rad = (R - 7) if k % 2 == 0 else (R - 14) * 0.95
        pts.append((cx + rad * math.cos(ang), cy - rad * math.sin(ang)))
    d.polygon(pts, fill=(255, 234, 172, 255), outline=(84, 52, 14, 255))
    d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(255, 252, 238, 255))


def decorate_frame(img: Image.Image, ratio: float = 0.041, inset: bool = True) -> Image.Image:
    """给整幅底板套一圈「红金双层」画框，压住自由构图后硬切的四边。

    为什么需要它：free 构图的人像是整幅矩形的（模型不会给你抠好的透明轮廓），
    如果没有边框，四边就是硬切、上半截跟下半截卡体的接缝也像没画完。
    这一圈框把「硬切」变成「装裱」，边角还有徽章呼应。

    🔴 inset=True（默认）：把画面**缩进框里**（等比 cover 到内框，最多裁掉 1~2%），
       框压在画布边界上而不是压在画面上。overlay（inset=False）会直接盖住画面最外
       一圈 44px —— 这张图的「8-DAY」左边缘和帽子顶部就贴在这个位置上，一盖就变成
       「字被吃掉一角」，所以默认必须 inset。
    🔴 画布尺寸不变（资源槽位固定），只在画布内侧做。
    """
    w, h = img.size
    bw = max(20, int(round(w * ratio)))
    bw = min(bw, w // 6, h // 6)

    if inset:
        inner = (w - 2 * bw, h - 2 * bw)
        art = fit_cover(img.convert("RGB"), inner)
        canvas = Image.new("RGBA", (w, h), (28, 17, 5, 255))
        canvas.paste(art, (bw, bw))
    else:
        canvas = img.convert("RGBA")

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    d.rectangle([0, 0, w - 1, h - 1], outline=(26, 15, 4, 255), width=3)
    _metal_band(d, (w, h), 3, max(4, int(bw * 0.32)), GOLD_DARK, GOLD_HI, peak_at=0.30)
    _metal_band(d, (w, h), int(bw * 0.32), max(5, int(bw * 0.42)), (70, 8, 12), FRAME_RED, 0.5)
    _metal_band(d, (w, h), int(bw * 0.42), int(bw * 0.78), GOLD_DARK, GOLD_HI, peak_at=0.45)
    d.rectangle([bw - 4, bw - 4, w - 1 - bw + 3, h - 1 - bw + 3],
                outline=(30, 18, 5, 255), width=3)
    # 内侧投影：让画面「沉」进框里，不然相接处是死板的平贴
    sh = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sh)
    span = max(12, int(bw * 0.6))
    for i in range(span):
        ds.rectangle([bw + i, bw + i, w - 1 - bw - i, h - 1 - bw - i],
                     outline=(0, 0, 0, int(95 * (1 - i / span) ** 1.5)), width=1)
    out = Image.alpha_composite(out, sh.filter(ImageFilter.GaussianBlur(2.0)))
    # 四角徽章 + 长边中点菱形
    d = ImageDraw.Draw(out)
    m = bw // 2
    R = max(10, int(bw * 0.55))
    for cx, cy in [(m, m), (w - 1 - m, m), (m, h - 1 - m), (w - 1 - m, h - 1 - m)]:
        _medallion(d, cx, cy, R)
    r = max(4, int(bw * 0.20))
    for cx, cy in [(w // 2, m), (w // 2, h - 1 - m)]:
        d.polygon([(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)],
                  fill=(255, 240, 190, 255), outline=(70, 44, 10, 255))
    canvas.alpha_composite(out)
    return canvas.convert(img.mode if img.mode in ("RGB", "RGBA") else "RGBA")



def cmd_postprocess(args) -> int:
    work = Path(args.work).expanduser().resolve()
    state = read_state(work)
    gen_path = Path(args.gen).expanduser().resolve()
    if not gen_path.exists():
        log("postprocess", f"🔴 生成图不存在：{gen_path}")
        return RC_FAIL

    gen = Image.open(gen_path).convert("RGB")
    arr = np.array(gen)
    residue_before = watermark_clean.residue_level(arr)
    wm_mode = "off" if args.no_clean else args.watermark
    if wm_mode == "off":
        cleaned, mask = arr, np.zeros(arr.shape[:2], bool)
        log("postprocess", "跳过水印清理（--watermark off / --no-clean）")
    else:
        cleaned, mask = watermark_clean.clean(arr, force=(wm_mode == "force"))
        log("postprocess", f"水印掩码 {int(mask.sum())} px；"
                          f"清理前右下角最亮 {residue_before['max']:.0f} → "
                          f"清理后 {watermark_clean.residue_level(cleaned)['max']:.0f}")

    target = tuple(state["target"])
    theme = theme_of(state["theme"])
    colors = theme.get("body_colors", ["#101018", "#05050a"])
    hero_raw = str(args.hero_band or "0").strip().lower()

    # 清理后的生成图单独留一份：verify 要拿它量水印残留（在成品上量会被卡体颜色干扰）
    Image.fromarray(cleaned).save(work / "gen_clean.png")

    if hero_raw in ("", "0", "none"):
        flat = fit_cover(Image.fromarray(cleaned), target)
        hb = 0
        body_mode = "-"
        log("postprocess", f"整幅模式：{gen.size[0]}x{gen.size[1]} → 等比 cover 到 "
                           f"{target[0]}x{target[1]}（居中裁切）")
    else:
        # 带状模式：生成图只是「英雄带」（角色 + 文案那一块），下半截空卡体另外补。
        # 超长条底板（856x2048，比例 0.42）整幅 cover 会横向砍掉 37%，角色和文案全废。
        img = Image.fromarray(cleaned)
        if hero_raw == "auto":
            band = fit_width(img, target[0])
        else:
            hb_req = int(hero_raw)
            if hb_req >= target[1]:
                log("postprocess", f"🔴 --hero-band {hb_req} 不小于图高 {target[1]}")
                return RC_FAIL
            # 按 (宽, 带高) 做 cover：只横向裁一点，纵向一格不裁
            band = fit_cover(img, (target[0], hb_req))
        hb = band.height

        snap = work / "src" / "source.png"
        use_source = (args.body_mode in ("auto", "source") and snap.is_file()
                      and Image.open(snap).size == target)
        if use_source:
            # 源快照按 RGBA 读：body 重上色要看 alpha（见 source_body 的棋盘格说明）
            snap_im = Image.open(snap).convert("RGBA")
            body = source_body(np.array(snap_im.convert("RGB")), hb, colors,
                               np.array(snap_im.getchannel("A")))
            body_mode = "source"
        else:
            body = synthetic_body(band, target, colors)
            body_mode = "synthetic"
            if args.body_mode == "source":
                log("postprocess", "⚠ 要 source 卡体但源快照尺寸不符/缺失，回退合成渐变")
        flat = compose_band(band, body, args.blend)
        log("postprocess", f"带状模式：英雄带 {target[0]}x{hb}（cover 到带高，只横向裁）"
                           f" + 下半截 {target[1] - hb}px（{body_mode}，接缝渐隐 {args.blend}px）")

    suffix = state["theme"]
    base = Path(state["asset"]).stem
    out_dir = work / "out"
    opaque_path = out_dir / f"{base}_{suffix}_{target[0]}x{target[1]}.png"
    alpha_path = out_dir / f"{base}_{suffix}_{target[0]}x{target[1]}_alpha.png"

    # 画框：free 构图的人像是整幅矩形，四边是硬切、上下半截的接缝也像没画完，
    # 不套一圈框就是「贴图没处理干净」。lock 构图既有透明轮廓，框可有可无（默认 none）。
    frame_mode = getattr(args, "frame", "none") or "none"
    frame_ratio = float(getattr(args, "frame_ratio", 0.041) or 0.041)
    inset = frame_mode != "gold-overlay"
    if frame_mode in ("gold", "gold-overlay"):
        flat = decorate_frame(flat, ratio=frame_ratio, inset=inset)
        log("postprocess", f"套红金画框：框宽 {max(20, round(flat.width * frame_ratio))}px"
                           f"（{'画面缩进框内' if inset else '压在画面上'}）")
    elif frame_mode == "auto":
        if state.get("composition") == "free":
            flat = decorate_frame(flat, ratio=frame_ratio, inset=True)
            log("postprocess", "套红金画框（auto：free 构图必套，画面缩进框内）")
        else:
            log("postprocess", "不套画框（auto：lock 构图保留原透明轮廓）")
    flat.save(opaque_path)

    # alpha 三种取法，选错就是「人物被裁」这种硬伤：
    #   source（默认）—— 沿用源 alpha。**只对 lock 构图成立**：轮廓没动，掩膜自然贴合。
    #   keep  —— 整幅不透明。free 构图（人物重新摆姿势/改镜头）必须用这个：
    #            源掩膜是按老姿势抠的，套到新人物上会把脸/头发整块切掉（2026-10-20 登录底板
    #            就是这个症状：新人物头比原来高、比原来宽，源掩膜等于一把剪刀）。
    #   free  —— 整幅不透明 + 顶边渐隐 N px（--feather-top），让上沿融进面板背景。
    src_alpha = Image.open(work / "src" / "source_alpha.png").convert("L").resize(target, Image.LANCZOS)
    alpha_mode = getattr(args, "alpha_mode", "source") or "source"
    if alpha_mode == "source" and state.get("composition") == "free":
        log("postprocess", "🔴 free 构图却要用源 alpha —— 源掩膜按老姿势抠的，会把新人物裁掉；"
                           "已自动改用 keep。要沿用源 alpha 请把 alpha-mode 显式写成 source")
        alpha_mode = "keep"
    if alpha_mode == "source":
        alpha_img = src_alpha
    else:
        arr = np.full((target[1], target[0]), 255, dtype=np.uint8)
        feather = max(0, int(getattr(args, "feather_top", 0) or 0))
        if alpha_mode == "free" and feather:
            f = min(feather, target[1])
            ramp = np.clip(np.arange(f, dtype=np.float32) / max(f - 1, 1), 0.0, 1.0)
            arr[:f, :] = (ramp[:, None] * 255).astype(np.uint8)
        alpha_img = Image.fromarray(arr, "L")
    with_alpha = flat.convert("RGBA")
    with_alpha.putalpha(alpha_img)
    with_alpha.save(alpha_path)

    compare_path = out_dir / "compare_before_after.jpg"
    src_flat = Image.open(work / "src" / "source.png").convert("RGBA")
    canvas = Image.new("RGBA", src_flat.size, (24, 26, 38, 255))
    canvas.alpha_composite(src_flat)
    before = canvas.convert("RGB").resize(target, Image.LANCZOS)
    gap = 24
    sheet = Image.new("RGB", (target[0] * 2 + gap, target[1]), (24, 26, 38))
    sheet.paste(before, (0, 0))
    sheet.paste(flat, (target[0] + gap, 0))
    sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS).save(
        compare_path, quality=92)

    state.update({
        "gen_image": str(gen_path),
        "gen_size": list(gen.size),
        "fit_mode": "hero-band" if hb else "cover",
        "hero_band": hb,
        "body_mode": body_mode,
        "alpha_mode": alpha_mode,
        "frame": frame_mode,
        "watermark_mask_px": int(mask.sum()),
        "watermark_max_before": round(residue_before["max"], 2),
        "watermark_max_after": round(watermark_clean.residue_level(cleaned)["max"], 2),
        "outputs": {
            "opaque": str(opaque_path),
            "alpha": str(alpha_path),
            "compare": str(compare_path),
        },
    })
    write_state(work, state)

    how = (f"英雄带 {target[0]}x{hb} + 卡体 {target[1] - hb}px/{body_mode}" if hb
           else "等比 cover + 居中裁切")
    print(f"  生成图    : {gen.size[0]}x{gen.size[1]} → 目标 {target[0]}x{target[1]}（{how}）")
    print(f"  不透明版  : {opaque_path.relative_to(ROOT) if str(opaque_path).startswith(str(ROOT)) else opaque_path}")
    print(f"  alpha 版  : {alpha_path.relative_to(ROOT) if str(alpha_path).startswith(str(ROOT)) else alpha_path}")
    print(f"  对比图    : {compare_path.relative_to(ROOT) if str(compare_path).startswith(str(ROOT)) else compare_path}")
    return RC_OK


# ----------------------------------------------------------------------------- verify
def cmd_verify(args) -> int:
    """断言式的验收：任何一条不达标都返回非 0，别让坏图进资源库。"""
    work = Path(args.work).expanduser().resolve()
    state = read_state(work)
    target = tuple(state["target"])
    outputs = state.get("outputs") or {}
    problems: list[str] = []
    warns: list[str] = []
    results: list[dict] = []

    def check(name: str, ok: bool, detail: str, hard: bool = True) -> None:
        results.append({"name": name, "ok": ok, "detail": detail, "hard": hard})
        if not ok:
            (problems if hard else warns).append(f"{name}: {detail}")
        print(f"  {'✅' if ok else ('🔴' if hard else '⚠ ')} {name} — {detail}")

    for key in ("opaque", "alpha", "compare"):
        p = Path(outputs.get(key, ""))
        check(f"{key} 产出存在", p.is_file(), str(p.name or p), hard=True)

    if Path(outputs.get("opaque", "")).is_file():
        im = Image.open(outputs["opaque"])
        check("不透明版尺寸", im.size == target, f"{im.size[0]}x{im.size[1]} vs 期望 {target[0]}x{target[1]}")

    if Path(outputs.get("alpha", "")).is_file():
        im = Image.open(outputs["alpha"])
        check("alpha 版尺寸", im.size == target, f"{im.size[0]}x{im.size[1]}")
        check("alpha 版模式", im.mode == "RGBA", im.mode)
        alpha = np.array(im.convert("RGBA").getchannel("A"))
        coverage = float((alpha > 0).mean())
        if state["alpha_coverage"] > 0.999:
            # 整幅不透明的资源没有浮层可沿用，此时两个变体必然等价 —— 只提示不算缺陷
            check("alpha 覆盖率与源一致", True, "源为整幅不透明，无浮层可保留", hard=False)
        elif state.get("alpha_mode", "source") != "source":
            # free 构图换了轮廓，覆盖率必然比源高 —— 只要「不低于源」就说明没裁掉人物；
            # 再用「生成图里的人物像素有没有被压成透明」做一次硬校验。
            check("alpha 未裁掉新构图", coverage >= state["alpha_coverage"] - 0.002,
                  f"{coverage:.4f} vs 源 {state['alpha_coverage']:.4f}（keep/free 模式只允许更不透明）")
            gclean = work / "gen_clean.png"
            if gclean.is_file():
                g = np.array(Image.open(gclean).convert("RGB"))
                a_small = np.array(Image.fromarray(alpha).resize(
                    (g.shape[1], g.shape[0]), Image.BILINEAR))
                bright = (g.max(axis=2) > 90) & (g.std(axis=2) > 18)   # 彩色高光=人物/文案
                lost = float((bright & (a_small < 40)).sum()) / max(int(bright.sum()), 1)
                check("人物/文案未被裁成透明", lost < 0.01,
                      f"被裁掉的彩色像素 {100 * lost:.2f}%")
        else:
            check("alpha 覆盖率与源一致", abs(coverage - state["alpha_coverage"]) < 0.002,
                  f"{coverage:.4f} vs 源 {state['alpha_coverage']:.4f}")

    # 水印残留要在「生成图的角落」上量，不能在成品上量：
    # 成品如果是超长条底板，右下角落进卡体/透明渐变区，那里的明暗跟水印毫无关系，
    # 一量就假报警（856x2048 那张就报了 +53）。postprocess 会把清理后的生成图存成 gen_clean.png。
    gclean = work / "gen_clean.png"
    if gclean.is_file():
        g = np.array(Image.open(gclean).convert("RGB")).astype(np.float32)
        gh, gw = g.shape[:2]
        roi = g[int(gh * watermark_clean.ROI_Y0_RATIO):,
                int(gw * watermark_clean.ROI_X0_RATIO):].mean(axis=2)
        mx, med = float(roi.max()), float(np.median(roi))
        spread = float(roi.std())
        area = float((roi > med + 30).mean())
        after = state.get("watermark_max_after")
        # 判据用 std 而不是「最亮 - 中位」：水印是细笔画高对比簇，清掉后 std 会从 40+ 掉到 10 以内；
        # 而平滑渐变角落的「最亮 - 中位」天生就有 60+（梯度本身在变亮），拿它当判据必假报警。
        # 🔴 掩码为 0 时（模型本来就没水印，右下角是礼盒/拐杖糖这类画），这条不能判红：
        #    那是美术内容，std 天然就高。只记录，不卡。
        mask_px = int(state.get("watermark_mask_px") or 0)
        if mask_px == 0:
            check("水印无残留（未检出，跳过）", True,
                  f"右下角 std {spread:.1f} —— 无灰白水印特征，按美术内容保留（最亮 {mx:.0f}）",
                  hard=False)
        else:
            check("水印无残留", spread < 22,
                  f"生成图角落 std {spread:.1f}（最亮 {mx:.0f} / 中位 {med:.0f}，高亮占比 {area:.1%}）"
                  + (f"；清理记录 {after}" if after is not None else "")
                  + f"；掩码 {mask_px}px",
                  hard=area < 0.25)
            if spread >= 22:
                warns.append("生成图角落起伏偏大；若该处本来就有装饰元素可忽略")

    # 带状模式额外验一条：接缝会不会像「两张图硬拼」。判据不是绝对值，而是
    # 跟**原图同一个位置**的跳变比 —— 这类底板本来就是一条直线切开的（卡体顶边），
    # 原图有 60+ 的跳变是设计，不是缺陷。
    if state.get("fit_mode") == "hero-band" and Path(outputs.get("opaque", "")).is_file():
        a2 = np.array(Image.open(outputs["opaque"]).convert("RGB")).astype(np.float32)
        hb = int(state.get("hero_band") or 0)
        src_p = work / "src" / "source.png"
        if 8 < hb < a2.shape[0] - 8:
            rowdiff = np.abs(np.diff(a2.mean(axis=1), axis=0))
            seam = float(rowdiff[hb - 4:hb + 4].max())
            ref = None
            if src_p.is_file():
                sa = np.array(Image.open(src_p).convert("RGB")).astype(np.float32)
                ref = float(np.abs(np.diff(sa.mean(axis=1), axis=0))[hb - 4:hb + 4].max())
            lim = max((ref or 0) * 3.0, 90.0)
            check("接缝跳跃（记录值）", seam <= lim,
                  f"本图 {seam:.0f}"
                  + (f"，原图同位置 {ref:.0f}" if ref is not None else "")
                  + "（这类底板本来就直线切开，数值差来自配色；>90 才需要人看一眼）",
                  hard=False)

    report = {
        "asset": state["asset_rel"],
        "theme": state["theme"],
        "target": list(target),
        "checks": results,
        "problems": problems,
        "warns": warns,
        "finished_at": datetime.now().isoformat(timespec="seconds"),
    }
    (work / "verify.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    if problems:
        print(f"\n🔴 验收不通过 {len(problems)} 项：")
        for p in problems:
            print(f"   - {p}")
        return RC_FAIL
    if warns:
        print(f"\n⚠  验收通过但有 {len(warns)} 处需要人看一眼")
        return RC_WARN
    print("\n✅ 全部验收项通过")
    return RC_OK


# ----------------------------------------------------------------------------- graph
def cmd_graph(args) -> int:
    """把 state.json 里的环节渲染成 mermaid 节点图（构建页归档，配合 JUnit 一起看）。"""
    work = Path(args.work).expanduser().resolve()
    state = read_state(work)
    verify = work / "verify.json"
    vdata = json.loads(verify.read_text(encoding="utf-8")) if verify.exists() else {"checks": []}

    lines = ["```mermaid", "flowchart LR"]
    nodes = [
        ("A", f"prepare<br/>{state['theme_zh']} · {state['target'][0]}x{state['target'][1]}", "done"),
        ("B", f"generate<br/>provider={state.get('provider', 'manual')}", "done" if state.get("gen_image") else "pending"),
        ("C", f"postprocess<br/>去水印 {state.get('watermark_mask_px', 0)} px", "done" if state.get("outputs") else "pending"),
    ]
    hard_ok = all(c["ok"] for c in vdata.get("checks", []) if c.get("hard"))
    nodes.append(("D", f"verify<br/>{sum(1 for c in vdata.get('checks', []) if c['ok'])}/"
                       f"{len(vdata.get('checks', []))} 项通过", "done" if hard_ok and vdata.get("checks") else
                 ("fail" if vdata.get("checks") else "pending")))
    pub = state.get("published") or {}
    nodes.append(("E", f"publish<br/>{pub.get('variant', '')} 写回 · 原图入背包"
                        if pub else "publish<br/>写回资源（未执行）",
                  "done" if pub else "pending"))

    for nid, label, status in nodes:
        lines.append(f'  {nid}["{label}"]')
    lines.append("  A --> B --> C --> D --> E")
    for nid, _, status in nodes:
        lines.append(f"__NODE__{nid}__{status}")      # 占位，下面统一去重着色

    # classDef 每类只写一次（重复写虽然能渲染，但 mermaid 源码可读性会很差）
    style = {
        "done": "fill:#0f2a1a,stroke:#2f9e5f,color:#d8ffe8",
        "fail": "fill:#2a0f14,stroke:#c0392b,color:#ffd9d9",
        "pending": "fill:#1c1c22,stroke:#666,color:#bbb",
    }
    for status, css in style.items():
        lines.append(f"  classDef {status} {css}")
    for status in style:
        members = [n for n in nodes if n[2] == status]
        if members:
            lines.append(f"  class {','.join(m[0] for m in members)} {status}")
    lines = [l for l in lines if not l.startswith("__NODE__")]
    lines.append("```")

    out = Path(args.out).expanduser() if args.out else work / "graph.md"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    print(f"\n节点图已写入 {out}")
    return RC_OK


# ----------------------------------------------------------------------------- publish
def rel_of(path: Path) -> Path:
    """资源相对工程根的路径；工程外文件退回文件名。备份目录按这个层级镜像。"""
    try:
        return path.resolve().relative_to(ROOT)
    except ValueError:
        return Path(path.name)


def backup_root_of(arg: str | None) -> Path:
    return Path(arg).expanduser().resolve() if arg else BACKUP_ROOT


def append_manifest(root: Path, record: dict) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    mf = root / "_manifest.jsonl"
    with mf.open("a", encoding="utf-8") as f:
        f.write(json.dumps(record, ensure_ascii=False) + "\n")
    return mf


def cmd_publish(args) -> int:
    """把验收通过的版本写回资源；**原图被搬出工程**到 ResBackpack/备份（可 restore 回滚）。"""
    work = Path(args.work).expanduser().resolve()
    state = read_state(work)
    outputs = state.get("outputs") or {}
    variant = args.variant
    src = Path(outputs.get(variant, ""))
    if not src.is_file():
        log("publish", f"🔴 变体 {variant} 不存在，先跑 postprocess")
        return RC_FAIL

    asset = Path(state["asset"])
    if not asset.is_file():
        log("publish", f"🔴 资源不存在：{asset}")
        return RC_FAIL

    # 闸门：验收没过就别覆盖资源。覆盖一张 UI 底板是不可逆操作（只能靠备份救）。
    vfile = work / "verify.json"
    if not vfile.exists():
        if not args.force:
            log("publish", f"🔴 没有 verify.json，别拿没验收的图覆盖资源（要跳过加 --force）")
            return RC_FAIL
    else:
        vdata = json.loads(vfile.read_text(encoding="utf-8"))
        bad = vdata.get("problems") or []
        if bad and not args.force:
            log("publish", f"🔴 验收有 {len(bad)} 项硬失败，拒绝写回：")
            for b in bad:
                log("publish", f"   - {b}")
            return RC_FAIL
        log("publish", f"验收结论：硬项全过（{len(vdata.get('checks', []))} 项检查）")

    if not args.yes:
        print(f"将把 {src.name} 覆盖到：{asset}")
        print(f"  原图会搬出工程 → {backup_root_of(args.backup_root) / rel_of(asset)}")
        print("  这是原地改资源，需要 --yes 才执行")
        return RC_USAGE

    before_sha = sha256(asset)
    if before_sha == sha256(src):
        log("publish", "⚠ 资源与产出字节完全相同，本次无需替换（幂等跳过）")
        return RC_OK

    root = backup_root_of(args.backup_root)
    dest = root / rel_of(asset)
    dest.parent.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    if not dest.exists():
        shutil.copy2(asset, dest)
        kind = "原图入背包（首次）"
    elif sha256(dest) == before_sha:
        kind = "原图已在背包（字节一致，未重复写）"
    else:
        # 🔴 背包里那份是**更早的原图**，绝不能被这次的「上次的圣诞版」覆盖掉。
        #    再换一次就另存一版，命名带时间戳与主题，restore 时能挑。
        dest = dest.with_name(f"{dest.stem}__{stamp}_{state['theme']}{dest.suffix}")
        shutil.copy2(asset, dest)
        kind = "追加一版（背包已存有更早原图，不覆盖）"
    if sha256(dest) != before_sha:
        log("publish", f"🔴 备份校验失败，中止（未改动资源）：{dest}")
        return RC_FAIL

    shutil.copy2(src, asset)
    after_sha = sha256(asset)
    if after_sha != sha256(src):
        log("publish", "🔴 写回后哈希不一致，请立刻 restore")
        return RC_FAIL

    im = Image.open(asset)
    record = {
        "at": datetime.now().isoformat(timespec="seconds"),
        "asset": str(rel_of(asset)),
        "theme": state["theme"],
        "variant": variant,
        "backup": str(dest),
        "backup_kind": kind,
        "before_sha256": before_sha,
        "after_sha256": after_sha,
        "size": list(im.size),
        "mode": im.mode,
        "note": args.note or "",
        "work": str(work),
    }
    mf = append_manifest(root, record)
    state["published"] = record
    write_state(work, state)

    print(f"✅ 已写回 {asset.name}（变体 {variant}，{im.size[0]}x{im.size[1]} {im.mode}）")
    print(f"   原图搬出工程 → {dest}")
    print(f"   方式：{kind}")
    print(f"   台账：{mf}")
    print("   .meta 未改动（保持原 textureType / spriteMode / packingTag）")
    print(f"   回滚：restyle_pipeline.py restore --asset {rel_of(asset)}")
    print("   🔴 还需重打该资源所在 AssetBundle 才会进包；Unity 编辑器里刷新一次确认没丢引用")
    return RC_OK


def cmd_restore(args) -> int:
    """从 ResBackpack/备份 把原图还回资源目录（publish 的反向操作）。"""
    asset_arg = args.asset
    asset = (ROOT / asset_arg).resolve() if not Path(asset_arg).is_absolute() else Path(asset_arg)
    root = backup_root_of(args.backup_root)
    rel = rel_of(asset)
    base = root / rel
    cands = [base] if base.is_file() else []
    if base.parent.is_dir():
        cands += sorted(p for p in base.parent.glob(f"{base.stem}__*{base.suffix}") if p.is_file())

    if not cands:
        log("restore", f"🔴 背包里没有 {rel} 的备份（找的是 {base}）")
        return RC_FAIL

    if args.list:
        print(f"{rel} 的备份版本：")
        for p in cands:
            st = p.stat()
            print(f"  {datetime.fromtimestamp(st.st_mtime):%Y-%m-%d %H:%M}  "
                  f"{p.stat().st_size:>9} B  {p.name}")
        return RC_OK

    pick = cands[0]
    if args.version:
        hits = [p for p in cands if args.version in p.name]
        if not hits:
            log("restore", f"🔴 没有名字含 {args.version!r} 的备份；先 --list 看一遍")
            return RC_FAIL
        pick = hits[0]

    if asset.is_file():
        cur = root / f"_replaced/{rel}"
        cur.parent.mkdir(parents=True, exist_ok=True)
        cur = cur.with_name(f"{cur.stem}__{datetime.now():%Y%m%d-%H%M%S}{cur.suffix}")
        shutil.copy2(asset, cur)
        print(f"   当前资源先留档 → {cur}")

    shutil.copy2(pick, asset)
    ok = sha256(asset) == sha256(pick)
    im = Image.open(asset)
    append_manifest(root, {
        "at": datetime.now().isoformat(timespec="seconds"),
        "action": "restore",
        "asset": str(rel),
        "from": str(pick),
        "sha256": sha256(asset),
        "size": list(im.size),
        "note": args.note or "",
    })
    print(f"{'✅' if ok else '🔴'} 已回滚 {asset.name} ← {pick.name}（{im.size[0]}x{im.size[1]} {im.mode}）")
    return RC_OK if ok else RC_FAIL


# ----------------------------------------------------------------------------- CLI
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="UI 资源换节日风格流水线（确定性部分）")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("themes", help="列出内置主题")
    p.set_defaults(func=cmd_themes)

    p = sub.add_parser("prompt", help="打印某主题的出图提示词与参数")
    p.add_argument("--theme", required=True)
    p.add_argument("--layout", default=None, help="构图锁：文件路径或多行文本（默认用预设里的通用规则）")
    p.add_argument("--composition", choices=list(COMPOSITIONS), default=None,
                   help="lock=姿势/版式全锁（默认）；free=允许重设计人物姿势与镜头，只锁文案/空白区/画布")
    p.set_defaults(func=cmd_prompt, key=None)

    p = sub.add_parser("prepare", help="校验源资源并建立工作目录")
    p.add_argument("--asset", required=True, help="相对工程根的资源路径")
    p.add_argument("--theme", required=True)
    p.add_argument("--work", default=None, help="自定义工作目录（默认 _output/art_restyle/<asset>/<theme>）")
    p.add_argument("--alpha-from", default=None,
                   help="alpha 参照图。资源被压成 RGB 丢浮层时用；支持 git:HEAD:<path> 直接从 git 取")
    p.add_argument("--source-from", default=None,
                   help="改前参照图（默认=资源本身）；支持 git:HEAD:<path>")
    p.add_argument("--layout", default=None, help="构图锁：文件路径或多行文本（决定文案怎么保）")
    p.add_argument("--composition", choices=list(COMPOSITIONS), default=None,
                   help="lock=姿势/版式全锁（默认）；free=允许重设计人物姿势与镜头，只锁文案/空白区/画布")
    p.set_defaults(func=cmd_prepare)

    p = sub.add_parser("postprocess", help="去水印 + 尺寸归位 + 出双版本 + 对比图")
    p.add_argument("--work", required=True)
    p.add_argument("--gen", required=True, help="provider 产出的图片")
    p.add_argument("--no-clean", action="store_true", help="跳过水印清理（等价 --watermark off）")
    p.add_argument("--watermark", choices=["auto", "off", "force"], default="auto",
                   help="auto=只在右下角认出「一行灰白字」时才修（默认）；"
                        "off=完全不碰像素（OpenAI 出的图无可见水印，推荐）；"
                        "force=强制按水印修（已知带水印但形状判据没认出来时）")
    p.add_argument("--hero-band", default="0",
                   help="超长条底板用：生成图只当「英雄带」贴顶，下方补空卡体。"
                        "auto=生成图整体当带；数字=带高像素（cover 到该尺寸，只横向裁）；0=整幅 cover")
    p.add_argument("--body-mode", choices=["auto", "source", "synthetic"], default="auto",
                   help="空卡体来源：source=用原资源下半截明暗结构重上色（几何与原图对齐，首选）；"
                        "synthetic=按主题色合成渐变（没有源快照时的兜底）；auto=能 source 就 source")
    p.add_argument("--blend", type=int, default=0,
                   help="接缝渐隐像素：把英雄带最后几行原位融进卡体（0=保持原图那种硬切，默认）")
    p.add_argument("--alpha-mode", choices=["source", "keep", "free"], default="source",
                   help="alpha 版怎么取：source=沿用源掩膜（只对 lock 构图成立，free 会被自动改成 keep）；"
                        "keep=整幅不透明（free 构图默认语义）；free=整幅不透明 + 顶边渐隐")
    p.add_argument("--feather-top", type=int, default=0,
                   help="--alpha-mode free 时顶边渐隐像素（默认 0=不渐隐，避免糊掉贴顶的帽子/头发）")
    p.add_argument("--frame", choices=["none", "auto", "gold", "gold-overlay"], default="none",
                   help="画框：none=不画（默认）；auto=free 构图自动套红金框、lock 不套；"
                        "gold=强制套红金框（画面等比缩进框内，不吃画面边缘）；"
                        "gold-overlay=框直接压在画面最外一圈（会盖掉贴边的文字，慎用）")
    p.add_argument("--frame-ratio", type=float, default=0.041,
                   help="框宽 = 图宽 × 该比例（默认 0.041；1080 宽约 44px）")
    p.set_defaults(func=cmd_postprocess)

    p = sub.add_parser("verify", help="像素级验收")
    p.add_argument("--work", required=True)
    p.set_defaults(func=cmd_verify)

    p = sub.add_parser("graph", help="输出 mermaid 节点图")
    p.add_argument("--work", required=True)
    p.add_argument("--out", default=None)
    p.set_defaults(func=cmd_graph)

    p = sub.add_parser("publish", help="写回原资源（破坏性，需 --yes；原图搬出工程到 ResBackpack/备份）")
    p.add_argument("--work", required=True)
    p.add_argument("--variant", choices=["alpha", "opaque"], default="alpha")
    p.add_argument("--backup-root", default=None,
                   help="备份根目录（默认 ResBackpack/备份，按资源相对路径镜像）")
    p.add_argument("--note", default="", help="台账备注（job 里传 BUILD_TAG，方便追溯哪次构建换的图）")
    p.add_argument("--force", action="store_true", help="跳过验收闸门（没有 verify 或有硬失败也写）")
    p.add_argument("--yes", action="store_true")
    p.set_defaults(func=cmd_publish)

    p = sub.add_parser("restore", help="从 ResBackpack/备份 回滚原图")
    p.add_argument("--asset", required=True, help="相对工程根的资源路径")
    p.add_argument("--backup-root", default=None)
    p.add_argument("--version", default=None, help="挑名字含该子串的备份（时间戳）；缺省取最早的原图")
    p.add_argument("--list", action="store_true", help="只列备份版本，不动资源")
    p.add_argument("--note", default="")
    p.set_defaults(func=cmd_restore)

    args = ap.parse_args(argv)
    if args.cmd == "prompt":
        args.key = args.theme
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
