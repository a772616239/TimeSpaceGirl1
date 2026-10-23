"""英雄特征卡 → 空舞台板 → Jenkins「TS-Art-Restyle」出图。

为什么需要这一层（2026-10-23 踩过的坑）：
    换皮管线（restyle）本质是「照着种子改」，provider 一定会把 ASSET 当参考图上传。
    直接拿英雄立绘当种子，模型就把姿势/服装/发色一起锁死——实测 05 被画成白发机甲、
    06 被画成金发，等于换了个人。文案再好也救不回来。

现在的分工：
    hero_features.py  从立绘**量化**出配色（发色/主色/点缀）
    hero_specs.json   语义特征卡：只写「她是什么」，不写原图的姿势/镜头
    hero_keyart.py    plates → 生成**不含人物**的空舞台板（只有画布/地平线/光池/底部留空）
                      render → 用特征卡渲染纯文字提示词，交给 Jenkins 出图
    aso_assets.py heroes → 把成品压上四语文案

即：立绘只贡献「特征」，画面 100% 由文字重画。种子只提供尺寸与地平线，不提供角色。

用法：
    python3 scripts/aso/hero_keyart.py plates                    # 建全部空舞台板
    python3 scripts/aso/hero_keyart.py plates --ids 01,03
    python3 scripts/aso/hero_keyart.py render --ids 01 --dry-run
    python3 scripts/aso/hero_keyart.py render --ids 01 02 03 05 06 --wait
"""
from __future__ import annotations

import argparse
import json
import random
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aso_common as C  # noqa: E402
import hero_prompt as HP  # noqa: E402

SPEC = C.ROOT / "data_aso/assets/hero_specs.json"
PLATE_DIR = C.ROOT / "data_aso/assets/seeds"
PROMPT_DIR = C.ROOT / "data_aso/assets/prompts"


# --------------------------------------------------------------------------- 色
def hex2rgb(s: str) -> tuple[int, int, int]:
    s = s.lstrip("#")
    if len(s) == 3:
        s = "".join(c * 2 for c in s)
    return int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16)


def mix(a, b, t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))  # type: ignore[return-value]


def _vgrad(stops: list[tuple[float, tuple[int, int, int]]], h: int) -> Image.Image:
    """按 (位置0~1, 颜色) 排好序的停靠点，生成 1×h 的竖向渐变列。"""
    col = Image.new("RGB", (1, h))
    px = col.load()
    stops = sorted(stops, key=lambda s: s[0])
    for y in range(h):
        t = y / max(1, h - 1)
        lo, hi = stops[0], stops[-1]
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                lo, hi = stops[i], stops[i + 1]
                break
        span = max(1e-6, hi[0] - lo[0])
        px[0, y] = mix(lo[1], hi[1], (t - lo[0]) / span)
    return col


def load_specs() -> dict:
    d = json.loads(SPEC.read_text(encoding="utf-8"))
    return {h["id"]: h for h in d["heroes"]}


# ---------------------------------------------------------------------- 空舞台板
def build_plate(h: dict, size: tuple[int, int] = (1080, 1920)) -> Image.Image:
    """只画「画布 + 地平线 + 光池 + 底部留空」，**不画人**。

    唯一目的是给模型一个正确的画幅与地面高度，并把底部 24% 留成全暗空区，
    让商店图的文案有地方压。任何人物/道具都不许出现在这里，否则等于又拿图当参考。
    """
    W, H = size
    rng = random.Random(f"plate-{h['id']}")           # 同 id 恒定，重跑不漂

    pal = [hex2rgb(c) for c in (h.get("palette_src") or ["#12121c"])]
    base = pal[0]
    accent = hex2rgb(h.get("accent") or "#7fe9ff")
    black = (7, 8, 12)

    horizon = 0.66
    # 天空：顶部压到近黑 → 地平线附近略微提亮（给主角身后的分离度）
    sky_hi = mix(base, black, 0.62)
    sky_lo = mix(base, accent, 0.22)
    im = _vgrad([(0.0, sky_hi), (horizon * 0.72, mix(sky_hi, sky_lo, 0.55)),
                 (horizon, sky_lo), (horizon + 0.045, mix(base, black, 0.55)),
                 (0.80, black), (1.0, black)], H).resize((W, H), Image.BILINEAR)
    im = im.convert("RGB")

    # 地平线光池：主角站位处一团很淡的点光（不是道具，只是明暗结构）
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx, cy = W * 0.5, H * horizon
    rad = np.sqrt(((xx - cx) / (W * 0.62)) ** 2 + ((yy - cy) / (H * 0.30)) ** 2)
    glow = np.clip(1.0 - rad, 0.0, 1.0) ** 2.1
    glow *= 0.16
    arr = np.array(im).astype(np.float32)
    for i in range(3):
        arr[..., i] = arr[..., i] * (1 - glow) + accent[i] * glow
    im = Image.fromarray(arr.clip(0, 255).astype(np.uint8))

    # 远景剪影：几根大而虚的竖块，只做纵深暗示（重模糊 ⇒ 读作「远处建筑」，不是角色）
    far = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(far)
    for i in range(5):
        bw = int(W * rng.uniform(0.09, 0.19))
        bx = int(W * rng.choice([rng.uniform(-0.04, 0.16), rng.uniform(0.72, 1.0)]) - bw * 0.4)
        bh = int(H * rng.uniform(0.16, 0.40))
        by = int(H * horizon) - bh
        d.rectangle([bx, by, bx + bw, by + bh], fill=(*mix(base, black, 0.78), 225))
    far = far.filter(ImageFilter.GaussianBlur(W * 0.028))
    im = Image.alpha_composite(im.convert("RGBA"), far).convert("RGB")

    # 地面：地平线以下压暗，并留一条极淡的反光带
    fl = _vgrad([(0.0, mix(sky_lo, black, 0.45)), (0.35, mix(base, black, 0.82)),
                 (1.0, black)], H).resize((W, H), Image.BILINEAR)
    top = int(H * horizon)
    band = Image.new("RGB", (W, H - top), black)
    band.paste(fl.crop((0, top, W, H)), (0, 0))
    im.paste(band, (0, top))

    # 底部 24% 空区：从 0.72H 起用 smoothstep 压到近黑，保证没有任何亮块压在文案区
    y0, y1 = 0.70, 0.79
    t = np.clip((yy / H - y0) / (y1 - y0), 0.0, 1.0)
    k = (t * t * (3 - 2 * t)) * 0.985            # smoothstep
    arr = np.array(im).astype(np.float32)
    for i in range(3):
        arr[..., i] = arr[..., i] * (1 - k) + black[i] * k
    im = Image.fromarray(arr.clip(0, 255).astype(np.uint8))

    # 四角渐晕：把注意力收到中间，同时让上下沿更沉
    vx = (np.abs(xx - W / 2) / (W / 2)) ** 2.4
    vy = (np.abs(yy - H * 0.46) / (H * 0.60)) ** 2.4
    vig = np.clip((vx + vy) * 0.55, 0.0, 0.92)
    arr = np.array(im).astype(np.float32)
    for i in range(3):
        arr[..., i] = arr[..., i] * (1 - vig) + black[i] * vig
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8))


def cmd_plates(args) -> int:
    specs = load_specs()
    ids = [i.strip() for i in (args.ids.split(",") if args.ids else specs.keys())]
    W, Hs = (int(x) for x in args.size.lower().split("x"))
    PLATE_DIR.mkdir(parents=True, exist_ok=True)
    for hid in ids:
        if hid not in specs:
            print(f"🔴 没有这个英雄：{hid}")
            return 2
        im = build_plate(specs[hid], (W, Hs))
        p = PLATE_DIR / f"stage_{hid}.png"
        im.save(p)
        print(f"[plate] {p.relative_to(C.ROOT)}  {im.size[0]}x{im.size[1]}  "
              f"（不含人物，仅画布/地平线/光池/底部留空）")
    return 0


# -------------------------------------------------------------------------- 出图
def cmd_render(args) -> int:
    specs = load_specs()
    ids = [i.strip() for i in (args.ids.split(",") if args.ids else specs.keys())]
    PROMPT_DIR.mkdir(parents=True, exist_ok=True)

    missing = [i for i in ids if not (PLATE_DIR / f"stage_{i}.png").is_file()]
    if missing:
        print(f"[render] 缺空舞台板 {missing}，先建")
        rc = cmd_plates(argparse.Namespace(ids=",".join(missing), size=args.size))
        if rc:
            return rc

    todo = []
    for hid in ids:
        if hid not in specs:
            print(f"🔴 没有这个英雄：{hid}")
            return 2
        pf = PROMPT_DIR / f"keyart_{hid}.txt"
        pf.write_text(HP.render(specs[hid], plate=True) + "\n", encoding="utf-8")
        todo.append((hid, PLATE_DIR / f"stage_{hid}.png", pf))
        print(f"[render] {hid} 提示词 {pf.relative_to(C.ROOT)}  "
              f"{len(pf.read_text(encoding='utf-8'))} 字符")

    if args.dry_run:
        print("\n[dry-run] 未触发 Jenkins。下面是 01 的完整提示词：\n")
        print(todo[0][2].read_text(encoding="utf-8"))
        return 0

    py = sys.executable
    fail = []
    for n, (hid, plate, pf) in enumerate(todo, 1):
        work = C.ROOT / f"_output/art_restyle/stage_{hid}/{args.theme}_design"
        cmd = [py, str(Path(__file__).resolve().parent / "aso_art.py"), "trigger",
               "--asset", str(plate.relative_to(C.ROOT)),
               "--theme", args.theme,
               "--composition", "design",   # 只借它的「画布/安全边锁」语义，提示词由 --prompt-file 全量覆盖
               "--prompt-file", str(pf.relative_to(C.ROOT)),
               "--frame", "none",           # 🔴 design 下 job 的 FRAME=auto 会套游戏卡框
               "--alpha-mode", "keep",      # 空舞台种子整幅不透明
               "--watermark", "auto"]
        if args.wait:
            cmd.append("--wait")
        print(f"\n===== [{n}/{len(todo)}] {hid} → Jenkins =====")
        r = subprocess.run(cmd, text=True)
        # 🔴 不看 rc 看产物：本 job 在出图前先做一次「生成图定位」，那一步必然 rc=3
        #    （图还没生成），于是整轮永远是 UNSTABLE。rc 只说明有警告，不说明没出图。
        hit = [p for p in work.glob("out/*.png") if not p.stem.endswith("_alpha")]
        if hit:
            print(f"[out] {hid} ✅ {hit[0].relative_to(C.ROOT)}  {hit[0].stat().st_size // 1024} KB")
        else:
            fail.append(hid)
            if not r.returncode:
                print(f"[out] {hid} 🔴 构建没报错但没有产物：{work}/out/")

    if fail:
        print(f"\n🔴 没有产出：{fail}")
        return 4
    print(f"\n[render] {len(todo)} 张已出图"
          + ("（已逐张等完成）" if args.wait else "（未等，注意别并发：inbox 不隔离）"))
    print("  下一步：hero_keyart.py collect   → 落到 data_aso/assets/gen/herocard_<id>.png")
    return 0


def cmd_collect(args) -> int:
    """把管线成品收进 data_aso/assets/gen/，供 aso_assets.py heroes 压四语文案。"""
    specs = load_specs()
    ids = [i.strip() for i in (args.ids.split(",") if args.ids else specs.keys())]
    gen = C.ROOT / "data_aso/assets/gen"
    gen.mkdir(parents=True, exist_ok=True)
    miss = []
    for hid in ids:
        work = C.ROOT / f"_output/art_restyle/stage_{hid}/{args.theme}_design/out"
        hit = sorted(p for p in work.glob("*.png") if not p.stem.endswith("_alpha"))
        if not hit:
            miss.append(hid)
            continue
        dst = gen / f"herocard_{hid}.png"
        dst.write_bytes(hit[-1].read_bytes())
        print(f"[collect] {hid} ← {hit[-1].name}  → {dst.relative_to(C.ROOT)}"
              f"  {dst.stat().st_size // 1024} KB")
    if miss:
        print(f"🔴 这些还没有成品：{miss}")
        return 4
    print(f"\n[collect] {len(ids)} 张就位。跑四语卡："
          f"python3 scripts/aso/aso_assets.py heroes --variant B")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="特征卡 → 空舞台板 → Jenkins 出图")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("plates", help="生成空舞台板（不含人物）")
    p.add_argument("--ids", default="")
    p.add_argument("--size", default="1080x1920")
    p.set_defaults(func=cmd_plates)

    p = sub.add_parser("render", help="渲染提示词并触发 Jenkins 出图")
    p.add_argument("--ids", default="")
    p.add_argument("--size", default="1080x1920")
    p.add_argument("--theme", default="cyber")
    p.add_argument("--wait", action="store_true", help="逐张等完成（必须：inbox 与浏览器登录态不隔离）")
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(func=cmd_render)

    p = sub.add_parser("collect", help="管线成品 → data_aso/assets/gen/herocard_<id>.png")
    p.add_argument("--ids", default="")
    p.add_argument("--theme", default="cyber")
    p.set_defaults(func=cmd_collect)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
