#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""adb 探测/校准工具：把「点一下 → 截一张 → 人看图 → 再点一下」压成一次批处理。

为什么需要它
------------
手工调设备用例时，每一步都截图再看图，两个代价都很高：
  ① **慢**：一次 adb 往返 + 一次模型读图，单步 3~8 秒，一条 10 步的用例 1 分钟；
  ② **贵**：一张 1080×2340 的截图读进上下文约 1.5k tokens，看 10 张就是 1.5 万。

关键观察：**判「点了有没有反应」不需要看图**，只需要知道「画面变了多少」。
所以本工具在 host 侧一次跑完整串动作，每步只输出一行文字（变化率 + 包围盒 + 大小 + 前台），
最后把所有截图拼成一张联系表（contact sheet）——**一次读图覆盖 N 步**。

用法
----
    # 1) 跑一串动作，只要文字结论
    python3 scripts/android_probe.py seq --plan plan.json --out /tmp/probe

    # 2) 只拼图（已有截图时）
    python3 scripts/android_probe.py montage --out /tmp/probe/sheet.png /tmp/probe/*.png

    # 3) 单图指纹（做金标准比对，不需要人看）
    python3 scripts/android_probe.py sig /tmp/probe/01_bag.png

plan.json
---------
    {"steps": [
      {"shot": "00_home"},
      {"tap": [390, 2150], "wait": 2.5, "shot": "01_bag"},
      {"key": "BACK", "wait": 1.5},
      {"tap": [250, 2150], "wait": 2.5, "shot": "02_hero"}
    ]}

支持的动作：tap / swipe / key / text / shell / wait / shot。
每个 step 都可以带 "wait"（执行后等待秒数）和 "shot"（截图名，可省略）。

退出码：0 全部动作执行完 / 1 有 adb 失败 / 2 用法错误
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time

try:
    from PIL import Image, ImageChops, ImageDraw, ImageFont
except ImportError:  # pragma: no cover
    sys.exit("需要 Pillow：pip install pillow（或用 ~/.workbuddy-ai/binaries/python/envs/default/bin/python）")

ADB = os.environ.get("ADB") or "adb"
SERIAL = os.environ.get("SERIAL") or ""
PKG = os.environ.get("PACKAGE") or ""


# --------------------------------------------------------------------------- #
def adb(*args, timeout=60, binary=False):
    cmd = [ADB] + (["-s", SERIAL] if SERIAL else []) + [str(a) for a in args]
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    if binary:
        return p.returncode, p.stdout
    return p.returncode, (p.stdout or b"").decode("utf-8", "replace")


def screencap(path):
    rc, data = adb("exec-out", "screencap", "-p", binary=True, timeout=60)
    if rc != 0 or len(data) < 5000:
        raise RuntimeError("截图失败（rc=%s, %d 字节）" % (rc, len(data)))
    with open(path, "wb") as fh:
        fh.write(data)
    return len(data)


def focus_line():
    _, out = adb("shell", "dumpsys", "window", timeout=20)
    for ln in out.splitlines():
        if "mCurrentFocus" in ln:
            return ln.strip().split("u0 ")[-1].rstrip("}")[:60]
    return "?"


def pid_of():
    _, out = adb("shell", "pidof", PKG, timeout=15) if PKG else (1, "")
    return out.strip()


SHRINK_W = 135  # 1/8 宽：1080 → 135。见 change_ratio 的说明


def change_ratio(a_path, b_path, shrink=SHRINK_W):
    """两张图的变化率 + 变化区域包围盒（坐标按原图还原）。

    为什么要缩小：城市背景有粒子/呼吸光效，**全分辨率逐像素比**时每两帧就有 5~8% 的
    像素在动 ⇒ 和「面板真的打开了」分不开。缩到 1/8 宽再比，等于对 8×8 的块取均值，
    高频特效被平均掉（噪声降到 1~2%），而布局级变化（面板/弹窗/场景切换）仍是 30%+。
    包围盒按比例放大回原图坐标，方便直接拿去量位置。
    """
    a = Image.open(a_path).convert("L")
    b = Image.open(b_path).convert("L")
    if a.size != b.size:
        return 1.0, (0, 0) + b.size
    ow, oh = a.size
    h = max(1, int(round(oh * shrink / ow)))
    a = a.resize((shrink, h), Image.LANCZOS)
    b = b.resize((shrink, h), Image.LANCZOS)
    d = ImageChops.difference(a, b)
    mask = d.point(lambda v: 255 if v > 18 else 0)
    bbox = mask.getbbox()
    hist = mask.histogram()
    changed = hist[255] if len(hist) > 255 else 0
    ratio = changed / float(shrink * h)
    if bbox:
        sx, sy = ow / float(shrink), oh / float(h)
        bbox = (int(bbox[0] * sx), int(bbox[1] * sy), int(bbox[2] * sx), int(bbox[3] * sy))
    return ratio, bbox


def dhash(path, size=16):
    """差值哈希：同样的界面 → 同样的串，用来做「金标准」比对，不用人看图。"""
    im = Image.open(path).convert("L").resize((size + 1, size), Image.LANCZOS)
    px = list(im.getdata())
    bits = []
    for row in range(size):
        base = row * (size + 1)
        for col in range(size):
            bits.append("1" if px[base + col] > px[base + col + 1] else "0")
    return "%016x%016x%016x%016x" % tuple(
        int("".join(bits[i:i + 16]), 2) for i in range(0, 64, 16))


def hamming(a, b):
    return sum(x != y for x, y in zip(a, b))


# --------------------------------------------------------------------------- #
def cmd_seq(args):
    plan = json.load(open(args.plan, encoding="utf-8"))
    steps = plan.get("steps") or plan if isinstance(plan, list) else plan.get("steps") or []
    if not steps:
        print("plan 里没有 steps", file=sys.stderr)
        return 2
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)

    print("%-18s %-8s %-22s %-7s %s" % ("shot", "change", "bbox", "size", "focus / note"))
    print("-" * 96)

    prev = None
    by_name = {}
    rc_all = 0
    shots = []
    for i, st in enumerate(steps):
        note = ""
        if "tap" in st:
            x, y = st["tap"]
            rc, o = adb("shell", "input", "tap", int(x), int(y))
            note = "tap(%s,%s)" % (x, y)
            rc_all |= rc
        elif "swipe" in st:
            x1, y1, x2, y2 = st["swipe"][:4]
            ms = st.get("ms", 300)
            rc, o = adb("shell", "input", "swipe", x1, y1, x2, y2, ms)
            note = "swipe(%s,%s)->(%s,%s)" % (x1, y1, x2, y2)
            rc_all |= rc
        elif "key" in st:
            rc, o = adb("shell", "input", "keyevent", st["key"])
            note = "key %s" % st["key"]
            rc_all |= rc
        elif "text" in st:
            rc, o = adb("shell", "input", "text", str(st["text"]).replace(" ", "%s"))
            note = "text"
            rc_all |= rc
        elif "shell" in st:
            rc, o = adb("shell", st["shell"])
            note = "shell"
            rc_all |= rc
        elif "probe" in st:
            # 自适应单测：点一下 → 看变化 → 只有「真的变了」才按 BACK 收尾。
            # 为什么需要：BACK 在主城会弹「退出游戏」确认框，之后所有点击都被它吃掉；
            # 所以「没打开面板」时**绝不能**按 BACK。
            x, y = st["probe"]
            name = st.get("shot") or ("probe_%d_%d" % (x, y))
            base = by_name.get(st.get("vs")) if st.get("vs") else prev
            if not base:
                rc, _ = adb("shell", "input", "tap", int(x), int(y))
                time.sleep(float(st.get("wait") or 2.5))
                p = os.path.join(out, "%s.png" % name)
                size = screencap(p)
                shots.append((name, p))
                by_name[name] = p
                print("%-18s %-8s %-22s %-7s tap(%s,%s)（无基线）" % (
                    name, "-", "-", "%dKB" % (size // 1024), x, y))
                prev = p
                continue
            rc, _ = adb("shell", "input", "tap", int(x), int(y))
            time.sleep(float(st.get("wait") or 2.5))
            p = os.path.join(out, "%s.png" % name)
            size = screencap(p)
            shots.append((name, p))
            by_name[name] = p
            ratio, bbox = change_ratio(base, p)
            thresh = float(st.get("thresh") or 15)
            # ⚠️ 变化率只是「提示」，不是判定：主城背景动效大，实测同屏两帧也能差 36~60%，
            #    异屏（弹窗/面板）反而只有 30~36% —— 两者区间重叠，阈值分不开。
            #    真正判断「是不是换了界面」只能看联系表；这里只把可疑的标出来。
            print("%-18s %-8s %-22s %-7s tap(%s,%s) → %s" % (
                name, "%.1f%%" % (ratio * 100),
                "(%d,%d,%d,%d)" % bbox if bbox else "-",
                "%dKB" % (size // 1024), x, y,
                "变化明显（看联系表确认）" if ratio * 100 >= thresh else "几乎没变"))
            # 只有显式要求才按 BACK：BACK 在主城/面板上可能弹「退出游戏」或「提示」，
            # 一弹就把后面所有点击吃掉（2026-10-23 实测连点把游戏退出过两次）。
            if st.get("back"):
                adb("shell", "input", "keyevent", "4")
                time.sleep(float(st.get("back_wait") or 1.6))
                bp = os.path.join(out, "%s_back.png" % name)
                screencap(bp)
                shots.append((name + "_back", bp))
                by_name[name + "_back"] = bp
                r2, _ = change_ratio(p, bp)
                print("%-18s %-8s %-22s %-7s BACK 后" % (
                    name + "_back", "%.1f%%" % (r2 * 100), "-", "-"))
                prev = bp
            else:
                prev = p
            continue
        elif "wait" in st and "shot" not in st:
            time.sleep(float(st["wait"]))
            continue

        if st.get("wait"):
            time.sleep(float(st["wait"]))

        if st.get("shot"):
            name = st["shot"]
            path = os.path.join(out, "%s.png" % name)
            size = screencap(path)
            shots.append((name, path))
            # vs 指定基线（不写则和上一张比）：判「这个点击相对静止态有没有反应」必须用基线
            base = by_name.get(st["vs"]) if st.get("vs") else prev
            if base:
                ratio, bbox = change_ratio(base, path)
                chg = "%.1f%%" % (ratio * 100)
                bb = "(%d,%d,%d,%d)" % bbox if bbox else "-"
            else:
                chg, bb = "-", "-"
            by_name[name] = path
            vs_tag = ("vs %s · " % st["vs"]) if st.get("vs") else ""
            print("%-18s %-8s %-22s %-7s %s" % (
                name, chg, bb, "%dKB" % (size // 1024),
                vs_tag + (note + " · " if note else "") + focus_line()))
            prev = path

    print("-" * 96)
    print("截图 %d 张 → %s" % (len(shots), out))
    if args.montage and shots:
        mp = os.path.join(out, args.montage)
        make_montage([p for _, p in shots], mp, cols=args.cols)
        print("联系表 → %s（一次看图覆盖 %d 步）" % (mp, len(shots)))
    return 0 if rc_all == 0 else 1


def cmd_montage(args):
    if not args.files:
        print("没给图片", file=sys.stderr)
        return 2
    make_montage(args.files, args.out, cols=args.cols)
    print("联系表 → %s（%d 张）" % (args.out, len(args.files)))
    return 0


def make_montage(paths, out, cols=3, thumb_w=300):
    ims = []
    for p in paths:
        try:
            im = Image.open(p).convert("RGB")
        except Exception:  # noqa: BLE001
            continue
        h = int(im.size[1] * thumb_w / im.size[0])
        ims.append((os.path.basename(p), im.resize((thumb_w, h), Image.LANCZOS)))
    if not ims:
        return
    th = max(im.size[1] for _, im in ims)
    rows = (len(ims) + cols - 1) // cols
    pad, label_h = 8, 22
    W = cols * thumb_w + (cols + 1) * pad
    H = rows * (th + label_h) + (rows + 1) * pad
    sheet = Image.new("RGB", (W, H), (24, 24, 28))
    draw = ImageDraw.Draw(sheet)
    font = None
    for fp in ("/System/Library/Fonts/Supplemental/Arial.ttf",
               "/System/Library/Fonts/Helvetica.ttc"):
        if os.path.isfile(fp):
            try:
                font = ImageFont.truetype(fp, 15)
                break
            except Exception:  # noqa: BLE001
                pass
    for idx, (name, im) in enumerate(ims):
        r, c = divmod(idx, cols)
        x = pad + c * (thumb_w + pad)
        y = pad + r * (th + label_h + pad)
        sheet.paste(im, (x, y + label_h))
        draw.text((x + 2, y + 2), name, fill=(180, 230, 180), font=font)
    os.makedirs(os.path.dirname(os.path.abspath(out)) or ".", exist_ok=True)
    sheet.save(out)


def cmd_sig(args):
    for p in args.files:
        im = Image.open(p)
        print("%-40s %dx%d  %s" % (os.path.basename(p), im.size[0], im.size[1], dhash(p)))
    if len(args.files) == 2:
        print("hamming=%d / 256" % hamming(dhash(args.files[0]), dhash(args.files[1])))
    return 0


# --------------------------------------------------------------------------- #
def main():
    global SERIAL, PKG
    ap = argparse.ArgumentParser(description="adb 探测/校准工具")
    sub = ap.add_subparsers(dest="cmd", required=True)

    s1 = sub.add_parser("seq", help="批量执行动作 + 每步变化率")
    s1.add_argument("--plan", required=True)
    s1.add_argument("--out", required=True)
    s1.add_argument("--montage", default="sheet.png", help="联系表文件名（留空则不拼）")
    s1.add_argument("--cols", type=int, default=3)

    s2 = sub.add_parser("montage", help="把多张截图拼成一张联系表")
    s2.add_argument("--out", required=True)
    s2.add_argument("--cols", type=int, default=3)
    s2.add_argument("files", nargs="+")

    s3 = sub.add_parser("sig", help="算图片指纹（dHash）")
    s3.add_argument("files", nargs="+")

    args = ap.parse_args()
    SERIAL = os.environ.get("SERIAL") or SERIAL
    PKG = os.environ.get("PACKAGE") or PKG
    if args.cmd == "seq":
        return cmd_seq(args)
    if args.cmd == "montage":
        return cmd_montage(args)
    return cmd_sig(args)


if __name__ == "__main__":
    sys.exit(main())
