#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""店面迭代（ASO）公共件：语言、规格上限、变体目录、Play 客户端。

设计原则
--------
1. **文案与素材都是「变体 × 语言」的二维矩阵**，落盘为纯 JSON/PNG，脚本只做校验与搬运，
   不在代码里写字面量 —— 改文案不该改代码。
2. **所有写线上动作都必须过三道闸门**：`--allow-write`（允许写）→ `--yes`（跳过确认）→
   上游 job 的 `DRY_RUN` 参数。默认路径永远是只读。
3. Play 的 service account 权限是「发布」，**不含**商店信息编辑时，
   `edits.listings` / `edits.images` 会返回 403 ⇒ 由 `hint_for_403()` 直接指出要补哪一项。

Play 侧事实（2026-10-23 核对官方 API 文档）
------------------------------------------------
- `edits.listings.update`：可改 `title` / `shortDescription` / `fullDescription` / `video`
- `edits.images.upload`：`imageType` 枚举 = phoneScreenshots / sevenInchScreenshots /
  tenInchScreenshots / tvScreenshots / wearScreenshots / icon / featureGraphic / tvBanner
- **商店页 A/B 实验（store listing experiments）没有公开 API** ⇒ 变体只能逐个上、按窗口比，
  见 `aso_experiment.py` 的说明。
"""
from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASO_ROOT = ROOT / "data_aso"
VARIANTS_DIR = ASO_ROOT / "variants"
ONLINE_DIR = ASO_ROOT / "online"
EXPERIMENTS_DIR = ASO_ROOT / "experiments"
DERIVED_DIR = ASO_ROOT / "derived"
ASSETS_DIR = ASO_ROOT / "assets"

PACKAGE = "com.Warera.timespace"

# Play 的硬上限（按 Unicode 码位计；中文/日文都是 1 字 1 位）
LIMITS = {"title": 30, "shortDescription": 80, "fullDescription": 4000}

# 四语：Play 侧 locale 码 ⇄ 本地物料目录 ⇄ 该语言优先字体
LOCALES = {
    "en-US": {
        "label": "英语",
        "material_dirs": ["时空美少女物料/en", "时空美少女物料"],
        "fonts": ["/System/Library/Fonts/Supplemental/Arial Bold.ttf",
                  "/System/Library/Fonts/Helvetica.ttc"],
    },
    "ja-JP": {
        "label": "日语",
        "material_dirs": ["时空美少女物料/jp", "时空美少女物料"],
        "fonts": ["/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc",
                  "/System/Library/Fonts/Hiragino Sans GB.ttc"],
    },
    "zh-CN": {
        "label": "简中",
        "material_dirs": ["时空美少女物料/zh", "时空美少女物料"],
        # 本机没有 PingFang.ttc（macOS 15 起移走了），实测可用的是 STHeiti / Hiragino Sans GB
        "fonts": ["/System/Library/Fonts/STHeiti Medium.ttc",
                  "/System/Library/Fonts/Hiragino Sans GB.ttc"],
    },
    "zh-TW": {
        "label": "繁中",
        "material_dirs": ["时空美少女物料/tw", "时空美少女物料"],
        "fonts": ["/System/Library/Fonts/STHeiti Medium.ttc",
                  "/System/Library/Fonts/Hiragino Sans GB.ttc"],
    },
}
LOCALE_CODES = list(LOCALES)
LOCALE_ALIASES = {
    "en": "en-US", "en-us": "en-US", "en_us": "en-US",
    "ja": "ja-JP", "jp": "ja-JP", "ja-jp": "ja-JP", "ja_jp": "ja-JP",
    "zh": "zh-CN", "cn": "zh-CN", "zh-cn": "zh-CN", "zh_cn": "zh-CN",
    "tw": "zh-TW", "zh-tw": "zh-TW", "zh_tw": "zh-TW", "zh-hant": "zh-TW",
}

# 截图/置顶图的交付规格
SHOT_SIZE = (1080, 1920)        # 9:16
FEATURE_SIZE = (1024, 500)      # Play 要求的置顶大图
ICON_SIZE = (512, 512)


# --------------------------------------------------------------------------- #
# Play 客户端：直接复用 scripts/play_upload.py 的认证与错误解析，别写第二份
# --------------------------------------------------------------------------- #
def load_pu():
    """把 scripts/play_upload.py 当模块导入（它不是包，只能按路径加载）。"""
    path = ROOT / "scripts" / "play_upload.py"
    spec = importlib.util.spec_from_file_location("play_upload", path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules.setdefault("play_upload", mod)
    spec.loader.exec_module(mod)  # type: ignore[union-attr]
    return mod


def play_service(explicit_key: str | None = None, quiet: bool = False):
    """认证并返回 androidpublisher v3 客户端。"""
    pu = load_pu()
    sa = pu.resolve_service_account(explicit_key)
    if not quiet:
        pu.log(f"[aso] 密钥：{sa}")
    return pu.build_service(sa)


def hint_for_403(err_text: str) -> str:
    """把 403 变成「该补哪一项权限」的人话。"""
    t = err_text.lower()
    if "permission" in t or "denied" in t:
        return (
            "Play Console 侧缺商店信息编辑权限：\n"
            "  Play Console → 用户和权限 → 找到 service account 邮箱 →\n"
            "  「应用信息 → 编辑商店信息」勾上（原来只给了「正式版→发布」）。\n"
            "  改权限后等 5~15 分钟再跑。"
        )
    if "accessnotconfigured" in t or "has not been used in project" in t:
        return "Cloud 项目没启用 Google Play Android Developer API（见 google_play_upload_setup.md §1.1）。"
    return "见 docs/google_play_upload_setup.md §5 错误对照表。"


# --------------------------------------------------------------------------- #
# 变体 / 语言
# --------------------------------------------------------------------------- #
def norm_locale(x: str) -> str:
    k = x.strip()
    if k in LOCALES:
        return k
    v = LOCALE_ALIASES.get(k.lower())
    if not v:
        raise SystemExit(f"未知语言代码：{x}（可选 {', '.join(LOCALE_CODES)}）")
    return v


def parse_locales(spec: str | None) -> list[str]:
    """'en,ja' / 'en-US,ja-JP' / '' ⇒ 语言列表；空 = 全部四语。"""
    if not spec or spec.strip() in ("", "all", "*"):
        return list(LOCALE_CODES)
    return [norm_locale(p) for p in spec.split(",") if p.strip()]


def list_variants() -> list[str]:
    if not VARIANTS_DIR.is_dir():
        return []
    return sorted(p.name for p in VARIANTS_DIR.iterdir()
                  if p.is_dir() and not p.name.startswith(("_", ".")))


def variant_dir(variant: str) -> Path:
    d = VARIANTS_DIR / variant
    if not d.is_dir():
        raise SystemExit(
            f"变体目录不存在：{d}\n现有变体：{', '.join(list_variants()) or '(空)'}"
        )
    return d


def load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"文件不存在：{path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"JSON 语法错误 {path}:{exc.lineno}:{exc.colno} — {exc.msg}")


def load_variant_meta(variant: str) -> dict:
    p = variant_dir(variant) / "meta.json"
    return load_json(p) if p.is_file() else {}


def load_listing(variant: str, locale: str) -> dict:
    d = variant_dir(variant)
    p = d / f"{locale}.json"
    if not p.is_file():
        raise SystemExit(f"缺少 {variant} 的 {locale} 文案：{p}")
    data = load_json(p)
    data.setdefault("language", locale)
    return data


def iter_listings(variant: str, locales: list[str] | None = None):
    for loc in (locales or LOCALE_CODES):
        p = VARIANTS_DIR / variant / f"{loc}.json"
        if p.is_file():
            yield loc, load_json(p)


def text_fields(listing: dict) -> dict[str, str]:
    """只取 Play 认识的四个字段，其余（注释/笔记）不进入上传体。"""
    return {k: (listing.get(k) or "").strip()
            for k in ("title", "shortDescription", "fullDescription", "video")}


def char_count(s: str) -> int:
    """Play 按字符数计。emoji 是一个码位，但显示更宽 —— 这里只做真实码位计数。"""
    return len(s)


def print_table(rows: list[list[str]], headers: list[str]) -> None:
    widths = [max(_disp_w(h), *(_disp_w(r[i]) for r in rows)) if rows else _disp_w(h)
              for i, h in enumerate(headers)]
    line = "  ".join(h + " " * (widths[i] - _disp_w(h)) for i, h in enumerate(headers))
    print(line)
    print("  ".join("-" * w for w in widths))
    for r in rows:
        print("  ".join((r[i] if i < len(r) else "") + " " * (widths[i] - _disp_w(r[i] if i < len(r) else ""))
                        for i in range(len(headers))))


def _disp_w(s: str) -> int:
    """终端显示宽度：CJK 算 2。"""
    import unicodedata
    w = 0
    for ch in s:
        w += 2 if unicodedata.east_asian_width(ch) in ("W", "F") else 1
    return w
