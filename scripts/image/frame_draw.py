#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""外框绘制 —— 给已定稿的 UI 图套一道「游戏自己的」卡框。纯确定性像素工序，不经过 AI 出图。

为什么单独抽一个工具
--------------------
框原本只是 `restyle_pipeline.py postprocess --frame card` 的一个可选后处理：必须跟着「换风格出图」
一条链路走，也就必须烧一次模型额度、换一张新图。而实际需求常常是**反过来的**：

    这张图的内容已经定了（甚至是手动改过的），只需要给它加/换一道框。

那种需求下走生图链路是错的（拿到的不是「原图 + 框」）。所以这里把「画框」拆成独立工序：
同一份绘制代码、同一套色板，但输入输出只有像素，可反复重跑、可断言。

与管线的关系
------------
像素实现复用 `restyle_pipeline.frame_card / decorate_frame`（**不另写一份**：边框语言的分级差一点，
跟游戏里道具槽/英雄卡就对不上了）。写回复用 `restyle_pipeline.backup_and_replace`
（原图先进背包、再覆盖、可 restore）。

用法
----
    frame_draw.py --asset Assets/.../xxx.png                     # 只出图，不碰资源
    frame_draw.py --asset ... --rim violet --ratio 0.028         # 紫框、加粗
    frame_draw.py --asset ... --style gold                       # 旧红金框（兜底）
    frame_draw.py --asset ... --write-back                       # 验收通过后写回资源
    frame_draw.py --asset ... --hairline                         # 带内侧细线

退出码：0 通过 / 1 失败 / 2 用法错误 / 3 需人看一眼（已经套过框，拒绝叠加）
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import numpy as np                                          # noqa: E402
from PIL import Image                                       # noqa: E402

import restyle_pipeline as rp                               # noqa: E402

OUT_ROOT = ROOT / "_output" / "art_frame"
RC_OK, RC_FAIL, RC_USAGE, RC_NEED_EYE = 0, 1, 2, 3

# 与 postprocess 里 card 的默认口径一致
DEFAULT_RATIO_CARD = 0.022
DEFAULT_RATIO_GOLD = 0.041
CHAMFER_RATIO = 0.028        # frame_card 里切角 = 短边 × 0.028
INK = (18, 16, 24)           # 墨带底色，用来判「这条带是不是框」


def log(msg: str) -> None:
    print(f"[frame] {msg}")


def geometry(w: int, h: int, ratio: float) -> tuple[int, int, int]:
    """复算 frame_card 的几何：带宽 / 切角 / 亮边宽。只用来做断言，绘制仍走管线那份。"""
    short = min(w, h)
    bw = max(16, int(round(short * ratio)))
    bw = min(bw, short // 8)
    c = max(16, int(round(short * CHAMFER_RATIO)))
    rw = max(3, int(round(bw * 0.30)))
    rw = min(rw, max(3, bw // 3))
    return bw, c, rw


def _ring_pixels(arr: np.ndarray, inset: int) -> np.ndarray:
    """取距画布外沿 inset px 的那一圈像素（四条边，不含角，避开切角干扰）。"""
    h, w = arr.shape[:2]
    m = max(0, min(inset, min(h, w) // 2 - 1))
    q = max(8, min(h, w) // 8)
    parts = [
        arr[m, q:w - q], arr[h - 1 - m, q:w - q],
        arr[q:h - q, m], arr[q:h - q, w - 1 - m],
    ]
    return np.concatenate(parts, axis=0).astype(np.float32)


def looks_framed(im: Image.Image) -> bool:
    """判这张图是不是已经套过框（幂等守卫）。

    🔴 不判的后果不是「报错」而是「悄悄变丑」：再套一次框，画面会被再缩 0.96 并再裁一圈，
    框带叠框带 —— 而每一步都算成功。所以外沿特征一旦成立就拒绝，除非显式 --force。

    判据（两条同时成立）：最外 1px 是暗描边（<40）且其内侧 2..5px 有一圈亮边（>110）。
    正常资源的外沿要么是画面（多半有亮部），要么是透明边，两者都不会同时满足。
    """
    a = np.asarray(im.convert("RGB"))
    edge = _ring_pixels(a, 0).mean()
    inner = _ring_pixels(a, min(3, min(im.size) // 4)).mean()
    return bool(edge < 40 and inner > 110)


def draw(im: Image.Image, style: str, rim: str, ratio: float, hairline: bool) -> Image.Image:
    """画框：card=游戏卡框（亮边+墨带+菱形纹+切角），gold=旧红金框。"""
    if style == "gold":
        return rp.decorate_frame(im, ratio=ratio, inset=True)
    return rp.frame_card(im, band_ratio=ratio, rim=rim, hairline=hairline)


def check(im0: Image.Image, im1: Image.Image, style: str, rim: str,
          ratio: float) -> tuple[list[dict], list[str]]:
    """像素级验收：尺寸/模式不变、框真的画上了、画面是缩进而不是被盖住。"""
    checks: list[dict] = []
    problems: list[str] = []
    w0, h0 = im0.size
    w1, h1 = im1.size

    def add(name: str, ok: bool, detail: str) -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})
        if not ok:
            problems.append(f"{name}：{detail}")

    add("尺寸未变", (w0, h0) == (w1, h1), f"{w0}x{h0} → {w1}x{h1}")
    add("色彩模式未变", im0.mode == im1.mode, f"{im0.mode} → {im1.mode}")

    a0 = np.asarray(im0.convert("RGB")).astype(np.float32)
    a1 = np.asarray(im1.convert("RGB")).astype(np.float32)

    # ① 外沿 1px 暗描边：撑住轮廓，不然缩放时亮边会糊成灰
    edge = _ring_pixels(a1, 0).mean()
    add("外沿 1px 暗描边", edge < 40, f"均值亮度 {edge:.0f}")

    if style == "gold":
        # 红金框的断言只做到「画面变了 + 尺寸没变」：它是兜底样式，不值得为它写一套几何断言
        diff = float(np.abs(a0 - a1).mean())
        add("画面已改动", diff > 1.0, f"平均通道差 {diff:.2f}")
        return checks, problems

    bw, c, rw = geometry(w1, h1, ratio)
    add("框宽合理", 16 <= bw <= min(w1, h1) // 8, f"{bw}px（短边 {min(w1, h1)} × {ratio}）")

    # ② 亮边成环：最外暗描边里侧那圈必须够亮（🔴 深色面板上墨带跟底色同亮度，没有亮边等于没框）
    rim_l = _ring_pixels(a1, max(1, rw // 2)).mean()
    add("亮边存在且够亮", rim_l >= 110, f"rim 圈均值亮度 {rim_l:.0f}（要求 ≥110）")
    add("亮边与暗描边有对比", rim_l - edge >= 70, f"差 {rim_l - edge:.0f}（要求 ≥70）")

    # ③ 四角切角：角上是墨带不是画面（取 (0,0) 起 c×c 的三角）
    corner = a1[2:min(c, h1 // 2), 2:min(c, w1 // 2)]
    tri = np.triu(np.ones(corner.shape[:2], bool), 0)[:, ::-1]
    corner_mean = float(corner[tri].mean()) if tri.any() else 255.0
    add("四角为硬切角（角上是墨带不是画面）", corner_mean < 90, f"切角区均值 {corner_mean:.0f}")

    # ④ 画面是「缩进框内」而不是被框盖住：内框起点处应是暗槽 (6,4,10)，再进 2px 就是画面
    mid = h1 // 2
    groove = a1[mid, max(0, bw - 2)]
    add("内框暗槽存在", groove.mean() < 30, f"({int(groove[0])},{int(groove[1])},{int(groove[2])})")
    inside = a1[mid, min(w1 - 1, bw + 2)]
    add("内框里是画面", float(np.abs(inside - groove).max()) > 12,
        f"画面像素 ({int(inside[0])},{int(inside[1])},{int(inside[2])})")

    # ⑤ 框带里有菱形网纹（引的是道具槽 diwen 的纹理；纯色带＝框没画对）
    band = _ring_pixels(a1, max(1, bw // 2)).reshape(-1, 1, 3)
    hf = float(np.abs(np.diff(band[:, :, 0].reshape(1, -1), axis=1)).mean())
    add("框带含网纹（非纯色）", hf > 0.2, f"相邻像素差 {hf:.2f}")

    # ⑥ 改动只发生在框带与画面重排：内框中心区应与「原图 cover 到内框」逐像素基本一致
    iw, ih = w1 - 2 * bw, h1 - 2 * bw
    ref = np.asarray(rp.fit_cover(im0.convert("RGB"), (iw, ih))).astype(np.float32)
    got = a1[bw:bw + ih, bw:bw + iw]
    mx, my = iw // 5, ih // 5
    core = float(np.abs(ref[my:ih - my, mx:iw - mx] - got[my:ih - my, mx:iw - mx]).mean())
    add("内框内容=原图等比缩进", core < 6.0, f"中心区平均通道差 {core:.2f}（要求 <6）")
    return checks, problems


def compare_sheet(im0: Image.Image, im1: Image.Image, out: Path) -> Path:
    """改前 / 改后 上下叠，中间留 40px 底衬（面板色），方便看框是不是一圈都到位。"""
    pad = 40
    sheet = Image.new("RGB", (max(im0.width, im1.width), im0.height + im1.height + pad), (17, 17, 25))
    sheet.paste(im0.convert("RGB"), (0, 0))
    sheet.paste(im1.convert("RGB"), (0, im0.height + pad))
    sheet.save(out, quality=92)
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="给已定稿 UI 图套外框（确定性，无 AI 出图）")
    ap.add_argument("--asset", required=True, help="要套框的资源（相对工程根或绝对路径）")
    ap.add_argument("--style", choices=["card", "gold"], default="card",
                    help="card=游戏卡框（亮边+墨带+菱形纹+切角，默认）；gold=旧红金雕花框（兜底）")
    ap.add_argument("--rim", choices=list(rp.CARD_RIMS), default="violet",
                    help="亮边色板：violet=紫白（紫色面板，默认）；warm=暖金（圣诞等暖主题）；"
                         "ivory=银白；none=不画亮边（🔴 深色底上框会看不见）")
    ap.add_argument("--ratio", type=float, default=0.0,
                    help=f"带宽 = 短边 × 该比例；0=按样式默认（card {DEFAULT_RATIO_CARD} / gold {DEFAULT_RATIO_GOLD}）")
    ap.add_argument("--hairline", action="store_true", help="带内侧再加一道细线（默认关，容易变相框双线）")
    ap.add_argument("--out", default="", help="产出目录，默认 _output/art_frame/<资源名>")
    ap.add_argument("--write-back", action="store_true", help="验收通过后写回资源（原图进背包）")
    ap.add_argument("--backup-root", default="", help="原图备份根，默认 ResBackpack/备份")
    ap.add_argument("--compress", choices=["auto", "lossless", "off"], default="auto",
                    help="交付前压体积（目标=资源当前体积）；默认 auto")
    ap.add_argument("--compress-max-diff", type=int, default=8,
                    help="降位深允许的最大通道差（默认 8；框带是平涂+网纹，掉太狠会出摩尔纹）")
    ap.add_argument("--note", default="", help="写回台账备注")
    ap.add_argument("--dry-run", action="store_true", help="只算指标，不落盘不写回")
    ap.add_argument("--force", action="store_true", help="已经套过框也照样再套（默认拒绝，避免叠框）")
    ap.add_argument("--publish-only", action="store_true",
                    help="只把上一次已经验收过的产出写回资源（不重新绘制）——"
                         "让 Jenkins 把「绘制」和「写回」拆成两个 stage，红球能指到具体环节")
    args = ap.parse_args(argv)

    asset = Path(args.asset).expanduser()
    if not asset.is_absolute():
        asset = ROOT / asset
    if not asset.is_file():
        log(f"🔴 资源不存在：{asset}")
        return RC_USAGE

    style = args.style
    ratio = float(args.ratio) if args.ratio > 0 else (
        DEFAULT_RATIO_GOLD if style == "gold" else DEFAULT_RATIO_CARD)
    if not (0.005 <= ratio <= 0.08):
        log(f"🔴 --ratio {ratio} 越界（0.005~0.08）：再小看不见，再大就是在框上放一张小图")
        return RC_USAGE

    im0 = Image.open(asset)
    im0.load()
    if min(im0.size) < 64:
        log(f"🔴 资源太小（{im0.width}x{im0.height}）：框会吃掉大半画面，拒绝")
        return RC_USAGE

    out_dir = Path(args.out).expanduser() if args.out else OUT_ROOT / asset.stem
    if not out_dir.is_absolute():
        # 🔴 相对路径按工程根解析：Path.relative_to() 只做字符串前缀比较，不认 cwd
        out_dir = (ROOT / out_dir).resolve()
    suffix = "rgb" if im0.mode == "RGB" else "alpha"
    tag = f"{style}_{args.rim if style == 'card' else 'gold'}_{int(round(ratio * 1000))}"
    out_png = out_dir / f"{asset.stem}_frame_{tag}_{im0.width}x{im0.height}_{suffix}.png"

    if args.publish_only:
        if not out_png.is_file():
            log(f"🔴 没有可写回的产出，先跑一次绘制：{out_png}")
            return RC_USAGE
        log(f"只写回：{rp.rel_of(out_png)} → {rp.rel_of(asset)}")
        try:
            pub = rp.backup_and_replace(
                asset, out_png, theme=f"frame_{tag}", note=args.note or f"frame {tag}",
                backup_root=args.backup_root or None, variant=suffix,
                work=str(out_dir), register_table=False)
        except RuntimeError as e:
            log(f"🔴 写回失败：{e}")
            return RC_FAIL
        if pub is None:
            log("幂等：资源与产出字节相同，无需写回")
            return RC_OK
        log(f"✅ 已写回 {asset.name}")
        log(f"   原图 → {pub['backup']}")
        log(f"   方式：{pub['backup_kind']}")
        log(f"   回滚：restyle_pipeline.py restore --asset {rp.rel_of(asset)}")
        log("   🔴 写回 ≠ 进包：还要重打该资源所在 AssetBundle")
        return RC_OK

    if not args.force and looks_framed(im0):
        log("🟡 这张图外沿已经是「暗描边 + 亮边」＝已经套过框。")
        log("   再套一次会把画面再缩 0.96、框带叠框带，而且每一步都算成功（静默变丑）。")
        log("   → 要换框请先 restore 回原图；确实要叠第二层加 --force")
        return RC_NEED_EYE

    log(f"资源：{rp.rel_of(asset)}  {im0.width}x{im0.height} {im0.mode}")
    log(f"样式：{style}  亮边：{args.rim}  带宽：{bw_hint(im0.size, ratio)}px  "
        f"切角：{geometry(im0.width, im0.height, ratio)[1]}px")

    im1 = draw(im0.copy(), style, args.rim, ratio, args.hairline)
    checks, problems = check(im0, im1, style, args.rim, ratio)
    for c in checks:
        log(f"  {'✅' if c['ok'] else '🔴'} {c['name']} — {c['detail']}")

    if args.dry_run:
        log("dry-run：不落盘")
        return RC_OK if not problems else RC_FAIL

    out_dir.mkdir(parents=True, exist_ok=True)
    im1.save(out_png)
    cmp_jpg = compare_sheet(im0, im1, out_dir / "compare_frame.jpg")
    log(f"产出：{out_png.relative_to(ROOT)}")
    log(f"对比：{cmp_jpg.relative_to(ROOT)}")

    # 压体积放在验收之后：验收断言「内框中心区与原图逐像素一致」，量化会全局动像素
    compress_report = None
    if args.compress != "off":
        from png_compress import compress_file
        compress_report = compress_file(
            out_png, target_kb=asset.stat().st_size / 1024.0,
            max_diff=args.compress_max_diff, mode=args.compress, log=log)
        log(f"压缩：{compress_report['bytes_in'] / 1024:.0f}KB → "
            f"{compress_report['bytes_out'] / 1024:.0f}KB")

    record = {
        "at": datetime.now().isoformat(timespec="seconds"),
        "asset": str(rp.rel_of(asset)),
        "op": "frame",
        "style": style,
        "rim": args.rim if style == "card" else None,
        "ratio": ratio,
        "hairline": bool(args.hairline),
        "size": list(im0.size),
        "mode": im0.mode,
        "checks": checks,
        "problems": problems,
    }

    if problems:
        (out_dir / "frame.json").write_text(
            json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        log(f"🔴 验收 {len(problems)} 项不过，拒绝写回")
        return RC_FAIL

    if args.write_back:
        try:
            pub = rp.backup_and_replace(
                asset, out_png, theme=f"frame_{tag}", note=args.note or f"frame {tag}",
                backup_root=args.backup_root or None, variant=suffix,
                work=str(out_dir), register_table=False)
        except RuntimeError as e:
            log(f"🔴 写回失败：{e}")
            return RC_FAIL
        if pub is None:
            log("幂等：资源与产出字节相同，无需写回")
        else:
            record["published"] = pub
            log(f"✅ 已写回 {asset.name}")
            log(f"   原图 → {pub['backup']}")
            log(f"   方式：{pub['backup_kind']}")
            log(f"   回滚：restyle_pipeline.py restore --asset {rp.rel_of(asset)}")
            log("   🔴 写回 ≠ 进包：还要重打该资源所在 AssetBundle")

    record["outputs"] = {"png": str(out_png), "compare": str(cmp_jpg)}
    if compress_report:
        record["compress"] = {k: compress_report.get(k) for k in
                              ("mode", "bits", "bytes_in", "bytes_out", "max_diff")}
    (out_dir / "frame.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # 台账：任何一次套框都留记录（哪张图、什么样式、带宽多少、哈希前后）
    try:
        mf = rp.append_manifest(rp.backup_root_of(args.backup_root or None), {
            "at": record["at"], "op": "frame", "asset": record["asset"],
            "style": style, "rim": args.rim, "ratio": ratio,
            "write_back": bool(args.write_back),
        })
        log(f"台账：{mf.relative_to(ROOT) if str(mf).startswith(str(ROOT)) else mf}")
    except Exception as e:  # noqa: BLE001
        log(f"⚠ 台账写入失败（绘制本身已完成）：{type(e).__name__}: {e}")
    return RC_OK


def bw_hint(size: tuple[int, int], ratio: float) -> int:
    return geometry(size[0], size[1], ratio)[0]


if __name__ == "__main__":
    raise SystemExit(main())
