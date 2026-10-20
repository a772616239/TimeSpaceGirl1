"""把「模型用棋盘格画出上下留白」的生成图，按源 alpha 足迹重新贴回。

模型不会真输出透明，它会画一格棋盘格来表示透明。直接整幅 cover 再用源 alpha 遮，
留白交界处会漏出一条白色棋盘格。所以：先量出生成图里的画区 bbox，再把它等比
cover 进「源 alpha 的可见带」矩形，最后套上源 alpha。

用法：
  python /tmp/refit_band.py --work _output/art_restyle/xxx/christmas
"""
import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path("/Users/wangxufeng/Documents/TimeSpaceGirl1")
sys.path.insert(0, str(REPO / "scripts" / "image"))
import restyle_pipeline as rp  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("--work", required=True)
ap.add_argument("--gen", default=None)
ap.add_argument("--edge", type=int, default=8, help="源 alpha 判可见的阈值")
args = ap.parse_args()

work = Path(args.work).expanduser().resolve()
state = rp.read_state(work)
W, H = state["target"]
base = Path(state["asset"]).stem
suffix = state["theme"]
gen_p = Path(args.gen) if args.gen else work / "inbox" / "gen_web.png"

gen = Image.open(gen_p).convert("RGB")
arr = np.array(gen).astype(np.int16)
gw, gh = gen.size
mx, mn = arr.max(axis=2), arr.min(axis=2)
gray = ((mx - mn) < 14) & (arr.mean(axis=2) > 170)   # 低饱和 + 亮 = 棋盘格
rows = gray.mean(axis=1)
ys = [y for y in range(gh) if rows[y] < 0.5]
y0g, y1g = ys[0], ys[-1] + 1
cols = gray[y0g:y1g].mean(axis=0)
xs = [x for x in range(gw) if cols[x] < 0.5]
x0g, x1g = xs[0], xs[-1] + 1
print(f"生成图 {gw}x{gh}  画区 bbox x {x0g}..{x1g}  y {y0g}..{y1g}")

art = gen.crop((x0g, y0g, x1g, y1g))

src_a = Image.open(work / "src" / "source_alpha.png").convert("L").resize((W, H), Image.LANCZOS)
a = np.array(src_a)
rows_s = (a > args.edge).any(axis=1)
ys_s = np.nonzero(rows_s)[0]
by0, by1 = int(ys_s[0]), int(ys_s[-1]) + 1
print(f"源可见带 y {by0}..{by1}（高 {by1 - by0}）")

fitted = rp.fit_cover(art, (W, by1 - by0))
canvas = Image.new("RGB", (W, H), (17, 17, 25))
canvas.paste(fitted, (0, by0))

out = canvas.convert("RGBA")
out.putalpha(src_a)
alpha_p = work / "out" / f"{base}_{suffix}_{W}x{H}_alpha.png"
out.save(alpha_p)
opaque_p = work / "out" / f"{base}_{suffix}_{W}x{H}.png"
canvas.save(opaque_p)
print("✅", alpha_p)
print("✅", opaque_p)
