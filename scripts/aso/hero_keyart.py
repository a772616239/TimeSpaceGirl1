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
    """只画「画布 + 地平线 + 光池 + 留空区」，**不画人**。

    唯一目的是给模型一个正确的画幅与地面高度，并把留给文案的区域压成全暗空区，
    让商店图的文案有地方压。任何人物/道具都不许出现在这里，否则等于又拿图当参考。

    竖版：底部 24% 留空（Play 手机轮播，文案压在下面）。
    横版：左侧 42% 留空（现网 1920×1080 那套，文案压在左边）+ 底部 10%。
    """
    W, H = size
    land = W > H
    rng = random.Random(f"plate-{h['id']}")           # 同 id 恒定，重跑不漂

    pal = [hex2rgb(c) for c in (h.get("palette_src") or ["#12121c"])]
    base = pal[0]
    accent = hex2rgb(h.get("accent") or "#7fe9ff")
    black = (7, 8, 12)

    horizon = 0.74 if land else 0.66
    # 天空：顶部压到近黑 → 地平线附近略微提亮（给主角身后的分离度）
    sky_hi = mix(base, black, 0.62)
    sky_lo = mix(base, accent, 0.22)
    im = _vgrad([(0.0, sky_hi), (horizon * 0.72, mix(sky_hi, sky_lo, 0.55)),
                 (horizon, sky_lo), (horizon + 0.045, mix(base, black, 0.55)),
                 (0.80, black), (1.0, black)], H).resize((W, H), Image.BILINEAR)
    im = im.convert("RGB")

    # 地平线光池：主角站位处一团很淡的点光（不是道具，只是明暗结构）
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    cx = W * (0.70 if land else 0.50)
    cy = H * horizon
    rad = np.sqrt(((xx - cx) / (W * (0.34 if land else 0.62))) ** 2
                  + ((yy - cy) / (H * 0.30)) ** 2)
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
        bw = int(W * rng.uniform(0.05, 0.11) if land else W * rng.uniform(0.09, 0.19))
        if land:
            bx = int(W * rng.uniform(0.50, 0.98) - bw * 0.4)   # 只落在右半边，别闯进文案区
        else:
            bx = int(W * rng.choice([rng.uniform(-0.04, 0.16), rng.uniform(0.72, 1.0)]) - bw * 0.4)
        bh = int(H * rng.uniform(0.16, 0.40))
        by = int(H * horizon) - bh
        d.rectangle([bx, by, bx + bw, by + bh], fill=(*mix(base, black, 0.78), 225))
    far = far.filter(ImageFilter.GaussianBlur(W * (0.016 if land else 0.028)))
    im = Image.alpha_composite(im.convert("RGBA"), far).convert("RGB")

    # 地面：地平线以下压暗，并留一条极淡的反光带。
    # 🔴 渐变必须按「地面自己的高度」归一化，再直接从地平线贴下去。
    #    之前的写法是按整幅 H 生成渐变再裁下半段 ⇒ 裁切点正好落到近黑端，
    #    地平线处出现一条亮度差几十级的硬切边（横版地平线更低，这条边更明显）。
    top = int(H * horizon)
    gh = H - top
    fl = _vgrad([(0.0, mix(sky_lo, black, 0.20)),
                 (0.30, mix(base, black, 0.80)),
                 (1.0, black)], gh).resize((W, gh), Image.BILINEAR)
    im.paste(fl, (0, top))

    arr = np.array(im).astype(np.float32)

    # 留空区 ①：底部。竖版从 0.70H 起压到近黑；横版只要最底 10%
    y0, y1 = (0.90, 0.96) if land else (0.70, 0.79)
    t = np.clip((yy / H - y0) / (y1 - y0), 0.0, 1.0)
    k = (t * t * (3 - 2 * t)) * 0.985            # smoothstep
    for i in range(3):
        arr[..., i] = arr[..., i] * (1 - k) + black[i] * k

    # 留空区 ②：横版还要把左 42% 压成干净的空柱（右缘做柔过渡，避免出现一刀切的黑边）
    if land:
        x0, x1 = 0.30, 0.46
        tx = np.clip((xx / W - x0) / (x1 - x0), 0.0, 1.0)
        kx = (1.0 - tx * tx * (3 - 2 * tx)) * 0.93
        for i in range(3):
            arr[..., i] = arr[..., i] * (1 - kx) + black[i] * kx

    # 四角渐晕：把注意力收到主体一侧，同时让四沿更沉
    cx_v = W * (0.66 if land else 0.50)
    vx = (np.abs(xx - cx_v) / (W * (0.72 if land else 0.5))) ** 2.4
    vy = (np.abs(yy - H * 0.46) / (H * 0.60)) ** 2.4
    vig = np.clip((vx + vy) * 0.55, 0.0, 0.92)
    for i in range(3):
        arr[..., i] = arr[..., i] * (1 - vig) + black[i] * vig
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8))


def _orient(size: str) -> tuple[int, int, str, str]:
    """'1080x1920' → (W, H, 'port', '')；'1920x1080' → (W, H, 'land', '_land')。

    文件名 / 工作目录 / 产物目录都靠这个后缀分流，横竖两套互不覆盖。
    """
    W, Hs = (int(x) for x in size.lower().split("x"))
    return W, Hs, ("land" if W > Hs else "port"), ("_land" if W > Hs else "")


def cmd_plates(args) -> int:
    specs = load_specs()
    ids = [i.strip() for i in (args.ids.split(",") if args.ids else specs.keys())]
    W, Hs, _tag, sfx = _orient(args.size)
    PLATE_DIR.mkdir(parents=True, exist_ok=True)
    for hid in ids:
        if hid not in specs:
            print(f"🔴 没有这个英雄：{hid}")
            return 2
        im = build_plate(specs[hid], (W, Hs))
        p = PLATE_DIR / f"stage_{hid}{sfx}.png"
        im.save(p)
        keep = "左侧 42% + 底部 10%" if sfx else "底部 24%"
        print(f"[plate] {p.relative_to(C.ROOT)}  {im.size[0]}x{im.size[1]}  "
              f"（不含人物，仅画布/地平线/光池/{keep}留空）")
    return 0


# -------------------------------------------------------------------------- 出图
def cmd_render(args) -> int:
    specs = load_specs()
    ids = [i.strip() for i in (args.ids.split(",") if args.ids else specs.keys())]
    PROMPT_DIR.mkdir(parents=True, exist_ok=True)
    W, Hs, orient, sfx = _orient(args.size)

    missing = [i for i in ids if not (PLATE_DIR / f"stage_{i}{sfx}.png").is_file()]
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
        pf = PROMPT_DIR / f"keyart_{hid}{sfx}.txt"
        pf.write_text(HP.render(specs[hid], plate=True, orient=orient) + "\n", encoding="utf-8")
        todo.append((hid, PLATE_DIR / f"stage_{hid}{sfx}.png", pf))
        print(f"[render] {hid} 提示词 {pf.relative_to(C.ROOT)}  "
              f"{len(pf.read_text(encoding='utf-8'))} 字符  [{orient} {W}x{Hs}]")

    if args.dry_run:
        print("\n[dry-run] 未触发 Jenkins。下面是 01 的完整提示词：\n")
        print(todo[0][2].read_text(encoding="utf-8"))
        return 0

    py = sys.executable
    fail = []
    for n, (hid, plate, pf) in enumerate(todo, 1):
        work = C.ROOT / f"_output/art_restyle/stage_{hid}{sfx}/{args.theme}_design"
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
    print("  下一步：hero_keyart.py collect --size " + args.size)
    return 0


# -------------------------------------------------------------------------- 双人店面底图
FUSION_DIR = C.ROOT / "data_aso/assets/gen/fusion"


def build_plate_duo(a: dict, b: dict, size: tuple[int, int] = (1920, 1080)) -> Image.Image:
    """双人横版空舞台板：地平线 + 左右两团光池 + 中间压暗 + 底部 26% 纯黑。

    和单人板的区别只有「留空区」的位置：单人横版留左侧 42%，双人版两侧都要站人，
    所以留空区挪到**中间 20%~80% + 底部 26%**——中间之后会被实机截图整块盖掉。
    """
    W, H = size
    pal = [hex2rgb(c) for c in (a.get("palette_src") or ["#12121c"])]
    pa = hex2rgb(a.get("accent") or "#7fe9ff")
    pb = hex2rgb(b.get("accent") or "#ff7ac0")
    black = (7, 7, 12)
    horizon = 0.78

    sky_hi = mix(pal[0], black, 0.66)
    sky_lo = mix(pal[0], black, 0.42)
    im = _vgrad([(0.0, sky_hi), (horizon * 0.80, sky_lo),
                 (horizon, mix(sky_lo, black, 0.45)),
                 (horizon + 0.04, black), (1.0, black)], H).resize((W, H), Image.BILINEAR)
    arr = np.array(im.convert("RGB")).astype(np.float32)

    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    # 左右各一团很淡的站位光（分别用两人自己的 accent），只是明暗结构不是道具
    for cx, col in ((W * 0.07, pa), (W * 0.93, pb)):
        rad = np.sqrt(((xx - cx) / (W * 0.20)) ** 2 + ((yy - H * horizon * 0.86) / (H * 0.34)) ** 2)
        g = (np.clip(1.0 - rad, 0.0, 1.0) ** 2.2) * 0.20
        for i in range(3):
            arr[..., i] = arr[..., i] * (1 - g) + col[i] * g

    # 中间压暗：告诉模型这块「什么都不该画」，也省得它在那里堆细节
    mx = np.clip(1.0 - np.abs(xx / W - 0.5) / 0.34, 0.0, 1.0) ** 1.5
    arr *= (1.0 - 0.45 * mx[..., None])
    # 底部 26% 纯黑
    by = np.clip((yy / H - 0.74) / 0.10, 0.0, 1.0)[..., None]
    arr = arr * (1 - by) + np.array(black, np.float32) * by

    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGB")


def cmd_duo(args) -> int:
    """左右双角色横版底图：空舞台板 → 特征卡提示词 → Jenkins → 收进 gen/fusion/。

    和单人 render 走同一条管线（TS-Art-Restyle），区别只有提示词与工作目录：
    中间 60% 的空白之后会被实机截图整块盖住，所以「角色由管线按特征卡重绘」
    与「中间是真实游戏画面」两件事可以同时成立，不需要抠图。
    """
    specs = load_specs()
    try:
        a_id, b_id = [s.strip() for s in args.pair.split(",")]
    except ValueError:
        print("🔴 --pair 要写成 01,02")
        return 2
    for i in (a_id, b_id):
        if i not in specs:
            print(f"🔴 没有这个英雄：{i}")
            return 2
    W, Hs = (int(v) for v in args.size.lower().split("x"))
    tag = f"{a_id}{b_id}"

    PLATE_DIR.mkdir(parents=True, exist_ok=True)
    PROMPT_DIR.mkdir(parents=True, exist_ok=True)
    plate = PLATE_DIR / f"stage_duo_{tag}.png"
    build_plate_duo(specs[a_id], specs[b_id], (W, Hs)).save(plate)
    print(f"[plate] {plate.relative_to(C.ROOT)}  {W}x{Hs}  （左右站位光 + 中间压暗 + 底部 26% 留空）")

    pf = PROMPT_DIR / f"duo_{tag}.txt"
    pf.write_text(HP.render_duo(specs[a_id], specs[b_id], plate=True) + "\n", encoding="utf-8")
    print(f"[render] 提示词 {pf.relative_to(C.ROOT)}  {len(pf.read_text(encoding='utf-8'))} 字符")

    if args.dry_run:
        print("\n[dry-run] 未触发 Jenkins。完整提示词：\n")
        print(pf.read_text(encoding="utf-8"))
        return 0

    work = C.ROOT / f"_output/art_restyle/stage_duo_{tag}/{args.theme}_design"
    cmd = [sys.executable, str(Path(__file__).resolve().parent / "aso_art.py"), "trigger",
           "--asset", str(plate.relative_to(C.ROOT)),
           "--theme", args.theme,
           "--composition", "design",
           "--prompt-file", str(pf.relative_to(C.ROOT)),
           "--frame", "none",
           "--alpha-mode", "keep",
           "--watermark", "auto"]
    if args.wait:
        cmd.append("--wait")
    print(f"\n===== duo {a_id}+{b_id} → Jenkins =====")
    r = subprocess.run(cmd, text=True)
    # 同单人版：不看 rc 看产物（出图前那道「生成图定位」必然 rc=3）
    hit = [p for p in work.glob("out/*.png") if not p.stem.endswith("_alpha")]
    if not hit:
        print(f"🔴 没有产物：{work}/out/   (rc={r.returncode})")
        return 4

    FUSION_DIR.mkdir(parents=True, exist_ok=True)
    dst = FUSION_DIR / f"bg_{tag}.png"
    dst.write_bytes(sorted(hit)[-1].read_bytes())
    print(f"[out] ✅ {dst.relative_to(C.ROOT)}  {dst.stat().st_size // 1024} KB")
    print(f"  下一步：aso_fusion.py build --layout duo （fusion.json 的 bg 指向这张）")
    return 0


def cmd_collect(args) -> int:
    """把管线成品收进 data_aso/assets/gen/（横版进 gen/land/），供 aso_assets.py heroes 压文案。"""
    specs = load_specs()
    ids = [i.strip() for i in (args.ids.split(",") if args.ids else specs.keys())]
    _W, _H, _tag, sfx = _orient(args.size)
    gen = C.ROOT / "data_aso/assets/gen" / ("land" if sfx else "")
    gen.mkdir(parents=True, exist_ok=True)
    miss = []
    for hid in ids:
        work = C.ROOT / f"_output/art_restyle/stage_{hid}{sfx}/{args.theme}_design/out"
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
          f"python3 scripts/aso/aso_assets.py heroes --variant B"
          + (" --orient land" if sfx else ""))
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
    p.add_argument("--size", default="1080x1920", help="1920x1080 = 横版，落到 gen/land/")
    p.add_argument("--theme", default="cyber")
    p.set_defaults(func=cmd_collect)

    p = sub.add_parser("duo", help="左右双角色横版底图（特征卡重绘 → gen/fusion/bg_<a><b>.png）")
    p.add_argument("--pair", required=True, help="两个英雄 id，逗号分隔，如 01,02（前=左，后=右）")
    p.add_argument("--size", default="1920x1080")
    p.add_argument("--theme", default="cyber")
    p.add_argument("--wait", action="store_true", help="等这一张真的出完再返回")
    p.add_argument("--dry-run", action="store_true")
    p.set_defaults(func=cmd_duo)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
