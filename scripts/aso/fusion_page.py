"""10 组置顶图候选验收页：data_aso/derived/<variant>/fusion10.html

为什么单独一页：置顶图候选是「同一版面 × 不同角色组合」，要比的是**角色**，
不是排版。所以一页平铺 10 组、每组四语并排，点开看 1024×500 原图。

用法：
    python3 scripts/aso/fusion_page.py --variant B [--src derived/B/fusion10]
"""
from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aso_common as C  # noqa: E402

LOCALES = [("en-US", "English"), ("ja-JP", "日本語"),
           ("zh-CN", "简体中文"), ("zh-TW", "繁體中文")]

CSS = """
:root{
  --bg:#08090e;--surface:#101219;--surface2:#161923;
  --line:rgba(255,255,255,.07);--line2:rgba(255,255,255,.16);
  --text:#e8eaf2;--muted:#8b90a6;--dim:#5c6175;
  --gold:#f2c76a;--cyan:#56e8e2;--mono:ui-monospace,SFMono-Regular,Menlo,monospace;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);
  font:14px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Hiragino Sans",sans-serif}
.wrap{max-width:1500px;margin:0 auto;padding:34px 30px 90px}
header{padding-bottom:18px;margin-bottom:24px;border-bottom:1px solid var(--line)}
h1{margin:0;font-size:20px;font-weight:650}
.sub{margin:6px 0 0;font-size:12.5px;color:var(--dim)}
.sub b{color:var(--gold);font-weight:600}

.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(440px,1fr));gap:20px}
.card{background:var(--surface);border:1px solid var(--line);border-radius:14px;
  overflow:hidden;transition:border-color .15s}
.card:hover{border-color:var(--line2)}
.hd{display:flex;align-items:baseline;gap:10px;padding:12px 14px 8px}
.tag{font:600 12px/1 var(--mono);color:var(--gold);letter-spacing:.5px}
.names{font-size:12.5px;color:var(--muted)}
.names em{font-style:normal;color:var(--text)}
.note{margin-left:auto;font-size:11.5px;color:var(--dim);max-width:52%;
  text-align:right;line-height:1.4}
.shots{display:flex;flex-direction:column;gap:6px;padding:0 14px 14px}
.row{display:flex;align-items:center;gap:8px}
.row .loc{font:10.5px/1 var(--mono);color:var(--dim);width:34px;flex:none}
.row img{width:100%;border-radius:6px;display:block;cursor:zoom-in;
  border:1px solid rgba(255,255,255,.05)}
.miss{font-size:11.5px;color:#a04a4a;padding:10px 14px}

.lb{position:fixed;inset:0;background:rgba(4,5,9,.94);display:none;
  align-items:center;justify-content:center;z-index:99;padding:34px}
.lb.on{display:flex}
.lb img{max-width:96vw;max-height:88vh;border-radius:8px}
.lb .x{position:absolute;top:20px;right:26px;font:600 24px/1 var(--mono);
  color:var(--muted);cursor:pointer}
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--variant", default="B")
    ap.add_argument("--src", default="")
    ap.add_argument("--out", default="")
    a = ap.parse_args()

    src = Path(a.src) if a.src else (C.DERIVED_DIR / a.variant / "fusion10")
    out = Path(a.out) if a.out else (C.DERIVED_DIR / a.variant / "fusion10.html")
    pairs_p = C.ASSETS_DIR / "fusion_pairs.json"
    specs_p = C.ASSETS_DIR / "hero_specs.json"
    pairs = json.load(open(pairs_p, encoding="utf-8"))["pairs"]
    specs = {h["id"]: h for h in json.load(open(specs_p, encoding="utf-8"))["heroes"]}

    cards, total, missing = [], 0, []
    for p in pairs:
        tag = p["tag"]
        left = specs.get(p["left"], {})
        right = specs.get(p["right"], {})
        rows = []
        for loc, label in LOCALES:
            # 支持两种落盘结构：分语言目录（<src>/<loc>/feature_duo_<tag>.png，推荐）
            # 与平铺（<src>/feature_duo_<loc>_<tag>.png，早期产物）。
            f = src / loc / f"feature_duo_{tag}.png"
            if not f.is_file():
                f = src / f"feature_duo_{loc}_{tag}.png"
            if f.is_file():
                total += 1
                rel = f.relative_to(out.parent) if out.parent in f.parents else f
                rows.append(
                    f'<div class="row"><span class="loc">{loc[:5]}</span>'
                    f'<img src="{html.escape(str(rel))}" loading="lazy" alt="{tag} {loc}"></div>')
            else:
                missing.append(f"{tag}/{loc}")
                rows.append(f'<div class="row"><span class="loc">{loc[:5]}</span>'
                            f'<span class="miss">缺图</span></div>')
        cards.append(f"""<div class="card">
  <div class="hd"><span class="tag">{tag}</span>
    <span class="names"><em>{html.escape(left.get('name', p['left']))}</em>
      <span style="color:var(--dim)">×</span>
      <em>{html.escape(right.get('name', p['right']))}</em></span>
    <span class="note">{html.escape(p.get('note', ''))}</span></div>
  <div class="shots">{''.join(rows)}</div>
</div>""")

    doc = f"""<!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8">
<title>置顶图 10 组候选</title><style>{CSS}</style></head><body><div class="wrap">
<header><h1>Play 置顶图 · 10 组角色组合候选</h1>
<p class="sub">同一版面（<code>fusion.json / duo</code>）与同一套四语文案，只换「管线按特征卡重绘的双人底图」——
比的是角色组合，不是排版。<b>已生成 {total} 张</b>
{'；缺 ' + str(len(missing)) + ' 张：' + html.escape(', '.join(missing[:12])) if missing else '，全部齐'}。
点图看 1024×500 原图。</p></header>
<div class="grid">{''.join(cards)}</div></div>
<div class="lb" id="lb"><span class="x">✕</span><img id="lbi" alt=""></div>
<script>
const lb=document.getElementById('lb'), lbi=document.getElementById('lbi');
document.querySelectorAll('.row img').forEach(im=>im.onclick=()=>{{
  lbi.src=im.src; lb.classList.add('on');}});
lb.onclick=()=>lb.classList.remove('on');
document.addEventListener('keydown',e=>{{if(e.key==='Escape')lb.classList.remove('on')}});
</script></body></html>"""

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(doc, encoding="utf-8")
    try:
        shown = out.relative_to(C.ROOT)
    except ValueError:
        shown = out
    print(f"{shown}  卡片 {len(cards)} 组，图 {total} 张"
          + (f"，缺 {len(missing)} 张" if missing else "，齐全"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
