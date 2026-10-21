#!/usr/bin/env python3
"""按 layers.json 把拆出来的图层拼回场景预览，或打包回图集（默认只出图，不碰真资源）。

三种用法：
  1) 看整体：  scene_compose.py --dir _output/scene/Map1
               按各 Quad 的世界尺寸/位置叠出一张预览，等价于游戏里这几个层的相对关系。
  2) 只看一层：scene_compose.py --dir _output/scene/Map1 --only 前景1 --out /tmp/fg1.png
  3) 打包回图集：scene_compose.py --dir _output/scene/Map1 --pack
               产出 atlas_repacked.png（不写资源）；加 --apply 才真写回（自动备份+台账）。

画面约定：世界单位 → 像素用 --ppu（默认按 --width 反算），y 轴向上。绘制顺序
sortingOrder 升序、同序 z 大的先画，与 Unity 一致。
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def load(dirpath: Path) -> dict:
    mf = dirpath / "layers.json"
    if not mf.exists():
        raise SystemExit(f"🔴 {mf} 不存在，先跑 scene_unpack.py")
    return json.loads(mf.read_text())


def draw_order(layers: list[dict]) -> list[dict]:
    return sorted(layers, key=lambda L: (L["sortingOrder"], -L["position"][2]))


def layer_png(dirpath: Path, name: str) -> Path:
    """优先用 overrides/ 里的同名文件 —— 试改不必覆盖原导出，随时能对比、能回退。"""
    alt = dirpath / "overrides" / name
    return alt if alt.exists() else dirpath / "layers" / name


def compose(dirpath: Path, out: Path, width: int | None, ppu: float | None,
            only: str | None, bg: tuple[int, int, int] | None, margin: float,
            view: tuple[float, float, float, float] | None = None,
            include_flat: bool = False) -> Image.Image:
    man = load(dirpath)
    layers = draw_order(man["layers"])
    if only:
        layers = [L for L in layers if L["object"] == only]
        if not layers:
            raise SystemExit(f"🔴 没有名为 {only} 的图层")
    elif not include_flat:
        # 平躺的地面（旋转 90°）在相机里是斜的，硬塞进 2D 叠层只会误导，默认不画
        layers = [L for L in layers if not L.get("isFlat")]

    if view:
        minx, miny, maxx, maxy = view
    else:
        xs, ys = [], []
        for L in layers:
            w, h = L["worldSize"]
            xs += [L["position"][0] - w / 2, L["position"][0] + w / 2]
            ys += [L["position"][1] - h / 2, L["position"][1] + h / 2]
        minx, maxx, miny, maxy = min(xs) - margin, max(xs) + margin, min(ys) - margin, max(ys) + margin

    if ppu is None:
        ppu = (width or 1920) / (maxx - minx)
    cw, ch = max(1, int(round((maxx - minx) * ppu))), max(1, int(round((maxy - miny) * ppu)))

    canvas = Image.new("RGBA", (cw, ch), (*(bg or (10, 11, 18)), 255) if bg else (0, 0, 0, 0))
    for L in layers:
        im = Image.open(layer_png(dirpath, L["file"])).convert("RGBA")
        w, h = L["worldSize"]
        x0 = (L["position"][0] - w / 2 - minx) * ppu
        y1 = (maxy - (L["position"][1] - h / 2)) * ppu
        tw, th = max(1, int(round(w * ppu))), max(1, int(round(h * ppu)))
        tile = im.resize((tw, th), Image.LANCZOS)
        canvas.alpha_composite(tile, (int(round(x0)), int(round(y1 - th))))

    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(out)
    print(f"预览 {cw}x{ch} (ppu={ppu:.2f}, 世界 {maxx - minx:.2f}x{maxy - miny:.2f}) → {out}")
    return canvas


def pack(dirpath: Path, apply: bool, theme: str, note: str) -> int:
    man = load(dirpath)
    atlas_path = ROOT / man["atlas"]
    aw, ah = man["atlasSize"]
    atlas = Image.open(atlas_path).convert("RGBA")
    if atlas.size != (aw, ah):
        raise SystemExit(f"🔴 图集尺寸变了：{atlas.size} != {(aw, ah)}")

    # 按绘制顺序回贴：后画的（前景）覆盖先画的，与图集里共用行的现状一致
    for L in draw_order(man["layers"]):
        im = Image.open(layer_png(dirpath, L["file"])).convert("RGBA")
        x0, y0, x1, y1 = L["pixelBox"]
        if im.size != (x1 - x0, y1 - y0):
            im = im.resize((x1 - x0, y1 - y0), Image.LANCZOS)
        atlas.paste(im, (x0, y0))  # 硬替换，绝不 alpha_composite（会留旧图残影）

    dst = dirpath / "atlas_repacked.png"
    atlas.save(dst)
    print(f"打包结果（未写回）→ {dst}")
    if not apply:
        print("  要真写回：加 --apply（会自动备份原图 + 写台账）")
        return 0

    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import restyle_pipeline as rp  # noqa: WPS433

    rec = rp.backup_and_replace(atlas_path, dst, theme=theme, variant="scene_pack",
                                note=note or f"{man['prefab']} 分层打包写回", work=str(dirpath.resolve()))
    print(json.dumps(rec or {"skipped": True}, ensure_ascii=False, indent=1))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True, help="scene_unpack.py 的产出目录")
    ap.add_argument("--out", default=None, help="预览输出（默认 <dir>/preview_compose.png）")
    ap.add_argument("--width", type=int, default=1920, help="预览宽度，用来反算 ppu")
    ap.add_argument("--ppu", type=float, default=None, help="直接指定像素/世界单位")
    ap.add_argument("--only", default=None, help="只渲染某个图层（按对象名）")
    ap.add_argument("--bg", default=None, help="背景色 R,G,B；不给则透明")
    ap.add_argument("--margin", type=float, default=0.0, help="四周留白（世界单位）")
    ap.add_argument("--view", default=None,
                    help="取景框 x0,y0,x1,y1（世界单位）；不给则取全图层并集")
    ap.add_argument("--include-flat", action="store_true",
                    help="2D 叠层预览也把平躺的地面层画进来（几何上不成立，仅为了看内容）")
    ap.add_argument("--frame", default=None,
                    help="以某个图层的外框作为取景框（如 天空），背景层常按满屏出图")
    ap.add_argument("--pack", action="store_true", help="把图层打包回图集（默认不写资源）")
    ap.add_argument("--apply", action="store_true", help="配合 --pack：真写回资源")
    ap.add_argument("--theme", default="christmas")
    ap.add_argument("--note", default="")
    args = ap.parse_args()

    d = Path(args.dir)
    d = d if d.is_absolute() else ROOT / d
    if not d.exists():
        raise SystemExit(f"🔴 目录不存在：{d}")

    bg = tuple(int(v) for v in args.bg.split(",")) if args.bg else None
    if args.pack:
        return pack(d, args.apply, args.theme, args.note)

    view = None
    if args.view:
        vals = [float(v) for v in args.view.split(",")]
        if len(vals) != 4:
            raise SystemExit("🔴 --view 需要 x0,y0,x1,y1")
        view = tuple(vals)  # type: ignore[assignment]
    elif args.frame:
        man = load(d)
        hit = [L for L in man["layers"] if L["object"] == args.frame]
        if not hit:
            raise SystemExit(f"🔴 没有名为 {args.frame} 的图层")
        L = hit[0]
        w, h = L["worldSize"]
        view = (L["position"][0] - w / 2, L["position"][1] - h / 2,
                L["position"][0] + w / 2, L["position"][1] + h / 2)

    out = Path(args.out) if args.out else d / ("preview_" + (args.only or "compose") + ".png")
    out = out if out.is_absolute() else ROOT / out
    compose(d, out, args.width, args.ppu, args.only, bg, args.margin, view, args.include_flat)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
