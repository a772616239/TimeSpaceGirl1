#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""底部紫色虚化 —— 纯确定性像素加工，**不经过任何 AI 出图**。

为什么单独做一个工具
--------------------
这是「一张已经定稿的图，只需要下沿化开」的需求：渐变 + 高斯模糊 + alpha 收边，
每一步都可以写成确定的算法。走 restyle_pipeline 的生图链路要烧一次模型额度，
而且出来的**是另一张图**（构图、人物、文案全都变了）——拿到的不是「原来的图 + 虚化」。

与管线的关系
------------
像素实现复用 `restyle_pipeline._bottom_fade_rgb / _bottom_fade_alpha`（同一份代码，
不另写一遍：那种暖紫渐变的分级差一点就会在紫色面板上看出色阶）。
写回复用 `restyle_pipeline.backup_and_replace`（原图先进背包、再覆盖、可 restore）。

用法
----
    bottom_fade.py --asset Assets/.../xxx.png                  # 只出图，不碰资源
    bottom_fade.py --asset Assets/.../xxx.png --px 130          # 指定虚化带宽
    bottom_fade.py --asset Assets/.../xxx.png --write-back      # 验收通过后写回资源
    bottom_fade.py --asset ... --rim ivory                      # 换色板（默认 violet）
    bottom_fade.py --asset ... --dry-run                        # 只算不落盘

退出码：0 通过 / 1 失败 / 2 用法错误 / 3 需人看一眼（已是虚化过的图，拒绝叠加）
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

OUT_ROOT = ROOT / "_output" / "art_fade"
RC_OK, RC_FAIL, RC_USAGE, RC_NEED_EYE = 0, 1, 2, 3


def log(msg: str) -> None:
    print(f"[fade] {msg}")


def looks_faded(im: Image.Image) -> bool:
    """判断这张图是不是已经被虚化过一次（幂等守卫）。

    🔴 不判的话，重跑一次 job 就在虚化带上**再叠一次**：紫色越叠越重、细节越叠越糊，
       而且每次都不报错 —— 这种「跑第二次就坏」的工序比直接失败更危险。
       判据用「末行 alpha 已经收到 0」：正常资源底边是硬切（255），虚化过的必然是 0。
       RGB 资源没有 alpha 可用，退回看末行是否已经明显偏低频（模糊后水平梯度很小）。
    """
    if im.mode == "RGBA":
        al = np.asarray(im.getchannel("A"), dtype=np.float32)
        return bool(al[-1].mean() < 4.0)
    g = np.asarray(im.convert("L"), dtype=np.float32)
    edge = g[-2:, :]
    return bool(np.abs(np.diff(edge, axis=1)).mean() < 2.0)


def apply_fade(im: Image.Image, px: int, rim: str) -> Image.Image:
    """RGB 侧渐变模糊 + alpha 侧收边；源是 RGB 就还回 RGB（别把资源模式改了）。"""
    src_mode = im.mode
    rgb, used = rp._bottom_fade_rgb(im.convert("RGBA"), px, rim)
    if src_mode == "RGB":
        # 没有 alpha 通道的资源：虚化只做颜色与模糊，不加透明（否则导入口径会变）
        return rgb.convert("RGB")
    alpha = rp._bottom_fade_alpha(im.convert("RGBA").getchannel("A"), used)
    rgb.putalpha(alpha)
    return rgb


def check(im0: Image.Image, im1: Image.Image, px: int) -> tuple[list[dict], list[str]]:
    """像素级验收：尺寸/模式不变、只动底部带、带内确实变虚变紫。"""
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

    a0 = np.asarray(im0.convert("RGB"), dtype=np.float32)
    a1 = np.asarray(im1.convert("RGB"), dtype=np.float32)
    y0 = max(0, h0 - px)
    # ① 带外必须一个像素都不动 —— 虚化是局部工序，动到上面就是事故
    above = float(np.abs(a0[:y0] - a1[:y0]).max()) if y0 > 0 else 0.0
    add("虚化带以上零改动", above == 0.0, f"最大通道差 {above:.0f}")

    # ② 带内确实变紫：蓝通道相对红通道抬升（紫色 = 红蓝高、绿低）
    band0, band1 = a0[y0:], a1[y0:]
    b_r0 = float((band0[..., 2] - band0[..., 0]).mean())
    b_r1 = float((band1[..., 2] - band1[..., 0]).mean())
    add("带内转向紫色相", b_r1 > b_r0 + 6, f"(B-R) 均值 {b_r0:.1f} → {b_r1:.1f}")

    # ③ 带内确实变虚：高频能量下降
    lap0 = float(np.abs(np.diff(band0.mean(axis=2), axis=1)).mean())
    lap1 = float(np.abs(np.diff(band1.mean(axis=2), axis=1)).mean())
    add("带内高频能量下降", lap1 < lap0, f"{lap0:.1f} → {lap1:.1f}")

    # ④ 底边不再硬切
    if im0.mode == "RGBA":
        al = np.asarray(im1.getchannel("A"), dtype=np.float32)
        add("底边 alpha 收到 0", float(al[-1].mean()) < 4.0,
            f"末行 alpha 均值 {al[-1].mean():.1f}（源 {np.asarray(im0.getchannel('A'))[-1].mean():.0f}）")
        above_al = float(np.abs(
            np.asarray(im0.getchannel("A"), dtype=np.float32)[:y0]
            - al[:y0]).max()) if y0 > 0 else 0.0
        add("带以上 alpha 未动", above_al == 0.0, f"最大差 {above_al:.0f}")
    return checks, problems


def compare_sheet(im0: Image.Image, im1: Image.Image, out: Path) -> Path:
    """改前 / 改后 并排，各留 40px 底衬，方便看下沿是不是真的化开了。"""
    pad = 40
    sheet = Image.new("RGBA", (im0.width, im0.height * 2 + pad), (17, 17, 25, 255))
    for i, im in enumerate((im0, im1)):
        sheet.alpha_composite(im.convert("RGBA"), (0, i * (im0.height + pad) - (0 if i == 0 else 0)))
    sheet.convert("RGB").save(out, quality=92)
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="底部紫色虚化（确定性，无 AI 出图）")
    ap.add_argument("--asset", required=True, help="要处理的大图（相对工程根或绝对路径）")
    ap.add_argument("--px", type=int, default=130, help="虚化带宽（像素，默认 130）")
    ap.add_argument("--rim", choices=[k for k in rp.CARD_RIMS if k != "none"], default="violet",
                    help="色板（复用卡框色板；默认 violet）")
    ap.add_argument("--out", default="", help="产出目录，默认 _output/art_fade/<资源名>")
    ap.add_argument("--write-back", action="store_true", help="验收通过后写回资源（原图进背包）")
    ap.add_argument("--backup-root", default="", help="原图备份根，默认 ResBackpack/备份")
    ap.add_argument("--compress", choices=["auto", "lossless", "off"], default="auto",
                    help="交付前压体积（目标=资源当前体积，别比原图大）；默认 auto")
    ap.add_argument("--compress-max-diff", type=int, default=6,
                    help="降位深允许的最大通道差（默认 6；虚化带是平滑渐变，位深掉太狠会出台阶）")
    ap.add_argument("--note", default="", help="写回台账备注")
    ap.add_argument("--dry-run", action="store_true", help="只算指标，不落盘不写回")
    ap.add_argument("--force", action="store_true",
                    help="已经虚化过也照样再叠一层（默认拒绝，避免跑第二次就越叠越糊）")
    ap.add_argument("--publish-only", action="store_true",
                    help="只把上一次已经验收过的产出写回资源（不重新加工）——让 Jenkins 把"
                         "「加工」和「写回」拆成两个 stage，写回失败不和加工失败混在一个红灯里")
    args = ap.parse_args(argv)

    asset = Path(args.asset).expanduser()
    if not asset.is_absolute():
        asset = ROOT / asset
    if not asset.is_file():
        log(f"🔴 资源不存在：{asset}")
        return RC_USAGE
    px = int(args.px)
    if px <= 0:
        log("🔴 --px 必须 > 0")
        return RC_USAGE

    im0 = Image.open(asset)
    im0.load()
    if px >= im0.height // 2:
        log(f"🔴 虚化带 {px}px 超过图高的一半（{im0.height}px）——那是在毁图，不是化边")
        return RC_USAGE

    if not args.publish_only and not args.force and looks_faded(im0):
        log("🟡 这张图的底边已经是软的（末行 alpha≈0），判定为「已经虚化过」。")
        log("   再跑一次会在原虚化带上再叠一层：紫色更重、细节更糊，而且不会报错。")
        log("   → 要重做请先 restore 回原图；确实要叠第二层加 --force")
        return RC_NEED_EYE

    out_dir = Path(args.out).expanduser() if args.out else OUT_ROOT / asset.stem
    suffix = "rgb" if im0.mode == "RGB" else "alpha"
    out_png = out_dir / f"{asset.stem}_fade_{im0.width}x{im0.height}_{suffix}.png"

    if args.publish_only:
        if not out_png.is_file():
            log(f"🔴 没有可写回的产出，先跑一次加工：{out_png}")
            return RC_USAGE
        log(f"只写回：{rp.rel_of(out_png)} → {rp.rel_of(asset)}")
        try:
            pub = rp.backup_and_replace(
                asset, out_png, theme="fade", note=args.note or f"bottom_fade {px}px/{args.rim}",
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
        log(f"完成：{asset.name} ← {Path(pub['backup']).name}")
        return RC_OK

    log(f"资源：{rp.rel_of(asset)}  {im0.width}x{im0.height} {im0.mode}  alpha 覆盖率 "
        f"{100 * (np.asarray(im0.convert('RGBA'))[:, :, 3] > 8).mean():.1f}%")
    log(f"虚化：末 {px}px（{100 * px / im0.height:.0f}% 高度）+ {args.rim} 紫，"
        f"高斯半径 {max(1.0, px / 12.0):.0f}px")

    im1 = apply_fade(im0.copy(), px, args.rim)
    checks, problems = check(im0, im1, px)
    for c in checks:
        log(f"  {'✅' if c['ok'] else '🔴'} {c['name']} — {c['detail']}")

    if args.dry_run:
        log("dry-run：不落盘")
        return RC_OK if not problems else RC_FAIL

    out_dir.mkdir(parents=True, exist_ok=True)
    im1.save(out_png)
    cmp_jpg = compare_sheet(im0, im1, out_dir / "compare_fade.jpg")
    log(f"产出：{out_png.relative_to(ROOT)}")
    log(f"对比：{cmp_jpg.relative_to(ROOT)}")

    # 压体积放在验收之后：验收要断言「带以上一个像素都没动」，量化会全局动像素，
    # 先压再验就永远验不过（也会让人误以为虚化动了画面别处）。
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
        "op": "bottom_fade",
        "px": px,
        "rim": args.rim,
        "size": list(im0.size),
        "mode": im0.mode,
        "checks": checks,
        "problems": problems,
    }

    if problems:
        (out_dir / "fade.json").write_text(
            json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        log(f"🔴 验收 {len(problems)} 项不过，拒绝写回")
        return RC_FAIL

    if args.write_back:
        try:
            pub = rp.backup_and_replace(
                asset, out_png, theme="fade", note=args.note or f"bottom_fade {px}px/{args.rim}",
                backup_root=args.backup_root or None, variant=suffix,
                work=str(out_dir), register_table=False)
        except RuntimeError as e:
            log(f"🔴 写回失败：{e}")
            return RC_FAIL
        if pub is None:
            log("幂等：资源与产出字节相同，无需写回")
        else:
            record["published"] = pub
            log(f"✅ 已写回 {asset.name}；原图 → {Path(pub['backup']).relative_to(ROOT) if str(pub['backup']).startswith(str(ROOT)) else pub['backup']}")
            log(f"   方式：{pub['backup_kind']}")
            log(f"   回滚：restyle_pipeline.py restore --asset {rp.rel_of(asset)}")
            log("   🔴 写回 ≠ 进包：还要重打该资源所在 AssetBundle")
            log(f"完成：{asset.name} ← {Path(pub['backup']).name}")

    record["outputs"] = {"png": str(out_png), "compare": str(cmp_jpg)}
    if compress_report:
        record["compress"] = {k: compress_report.get(k) for k in
                              ("mode", "bits", "bytes_in", "bytes_out", "max_diff")}
    (out_dir / "fade.json").write_text(
        json.dumps(record, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    # 台账：任何一次虚化都留下记录（谁、多少像素、哪张图、哈希前8位）
    try:
        mf = rp.append_manifest(rp.backup_root_of(args.backup_root or None), {
            "at": record["at"], "op": "bottom_fade", "asset": record["asset"],
            "px": px, "rim": args.rim, "write_back": bool(args.write_back),
        })
        log(f"台账：{mf.relative_to(ROOT) if str(mf).startswith(str(ROOT)) else mf}")
    except Exception as e:  # noqa: BLE001
        log(f"⚠ 台账写入失败（加工本身已完成）：{type(e).__name__}: {e}")
    return RC_OK


if __name__ == "__main__":
    raise SystemExit(main())
