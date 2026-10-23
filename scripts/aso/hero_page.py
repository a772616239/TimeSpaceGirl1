"""英雄卡验收页：data_aso/derived/<variant>/heroes.html

为什么不并进 preview.html：那张是**商店截图**的验收台（Play 规格、A/B 文案计数、
灯箱），塞进 24 张 9:16 英雄卡会把它的节奏打散。这里单独一页，一个英雄一行，
四语并排 —— 改文案/换底图后一眼看出哪一版不对。

用法：
    python3 scripts/aso/hero_page.py --variant B
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import aso_common as C  # noqa: E402

LOCALES = [("en-US", "English"), ("ja-JP", "日本語"),
           ("zh-CN", "简体中文"), ("zh-TW", "繁體中文")]

CSS = """
:root{
  --bg:#0a0b10;--surface:#12141c;--surface2:#171a24;--surface3:#1d2130;
  --line:rgba(255,255,255,.075);--line2:rgba(255,255,255,.14);
  --text:#e9ebf2;--muted:#8b90a6;--dim:#5f6478;
  --cyan:#56e8e2;--pink:#ff2d95;--mono:ui-monospace,SFMono-Regular,Menlo,monospace;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);
  font:14px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI","PingFang SC","Hiragino Sans",sans-serif;
  -webkit-font-smoothing:antialiased}
a{color:inherit}
.wrap{max-width:1560px;margin:0 auto;padding:38px 34px 90px}

header{display:flex;align-items:flex-end;gap:18px;flex-wrap:wrap;
  padding-bottom:20px;margin-bottom:26px;border-bottom:1px solid var(--line)}
h1{margin:0;font-size:21px;letter-spacing:.2px;font-weight:650}
.sub{margin:6px 0 0;font-size:12.5px;color:var(--dim)}
.chips{display:flex;gap:8px;margin-left:auto;flex-wrap:wrap}
.chip{font:11px/1 var(--mono);padding:7px 11px;border-radius:999px;
  border:1px solid var(--line2);color:var(--muted);background:var(--surface)}
.chip b{color:var(--cyan);font-weight:600}

.hero{background:var(--surface);border:1px solid var(--line);border-radius:18px;
  padding:22px 24px 26px;margin-bottom:20px}
.hhead{display:flex;align-items:baseline;gap:12px;margin-bottom:16px;flex-wrap:wrap}
.hid{font:600 12px/1 var(--mono);color:#0a0b10;background:var(--cyan);
  padding:6px 9px;border-radius:7px;letter-spacing:.4px}
.hname{font-size:16px;font-weight:620}
.hrole{font-size:11.5px;color:var(--dim);font-family:var(--mono);letter-spacing:.5px}
.hmeta{margin-left:auto;font:11px/1 var(--mono);color:var(--dim)}

.grid{display:grid;grid-template-columns:repeat(var(--cols,4),minmax(0,1fr));gap:18px}
.cell{min-width:0}
.phone{position:relative;border-radius:22px;overflow:hidden;
  border:1px solid var(--line2);
  box-shadow:0 18px 40px -22px rgba(0,0,0,.9),0 0 0 1px rgba(0,0,0,.5) inset;
  background:#000;cursor:zoom-in;transition:transform .18s ease,border-color .18s ease}
.phone:hover{transform:translateY(-4px);border-color:rgba(86,232,226,.5)}
.phone img{display:block;width:100%;aspect-ratio:var(--ar,9/16);object-fit:cover}
.loc{display:flex;align-items:center;gap:7px;margin:9px 2px 0;
  font:10.5px/1 var(--mono);color:var(--dim);letter-spacing:.5px}
.loc i{font-style:normal;width:6px;height:6px;border-radius:50%;background:var(--pink)}
.loc em{font-style:normal;color:var(--muted)}

#lb{position:fixed;inset:0;background:rgba(4,5,9,.94);display:none;
  align-items:center;justify-content:center;z-index:99;padding:30px;cursor:zoom-out}
#lb.on{display:flex}
#lb img{max-height:92vh;max-width:min(52vw,560px);border-radius:14px;
  box-shadow:0 30px 90px rgba(0,0,0,.8)}
#lb .cap{position:absolute;bottom:22px;left:0;right:0;text-align:center;
  font:11.5px/1 var(--mono);color:var(--dim);letter-spacing:.6px}

footer{margin-top:34px;padding-top:18px;border-top:1px solid var(--line);
  font-size:11.5px;color:var(--dim);line-height:1.9}
code{font-family:var(--mono);font-size:11.5px;color:var(--muted);
  background:var(--surface2);padding:2px 6px;border-radius:5px}

@media (max-width:1180px){.grid{grid-template-columns:repeat(2,minmax(0,1fr))}}
.feature{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px;margin-top:6px}
.feature .cell{border:1px solid var(--line2);border-radius:12px;overflow:hidden;background:#000}
.feature img{display:block;width:100%;aspect-ratio:1024/500;object-fit:cover}
@media (max-width:620px){.wrap{padding:22px 16px 60px}.grid{grid-template-columns:1fr}}
"""

JS = """
const lb=document.getElementById('lb'),lbi=lb.querySelector('img'),
      lbc=lb.querySelector('.cap');
document.querySelectorAll('.phone').forEach(p=>{
  p.addEventListener('click',()=>{
    lbi.src=p.dataset.src; lbc.textContent=p.dataset.cap;
    lb.classList.add('on');
  });
});
lb.addEventListener('click',()=>lb.classList.remove('on'));
document.addEventListener('keydown',e=>{if(e.key==='Escape')lb.classList.remove('on')});
"""


def build(variant: str, orient: str = "port") -> Path:
    spec = C.load_json(C.ASSETS_DIR / "heroes.json")
    land = orient == "land"
    sub = "heroes_land" if land else "heroes"
    out = C.DERIVED_DIR / variant / ("heroes_land.html" if land else "heroes.html")
    root = C.DERIVED_DIR / variant
    heroes = spec.get("heroes", [])

    rows, total = [], 0
    for h in heroes:
        hid = h["id"]
        cells = []
        for loc, label in LOCALES:
            p = root / sub / loc / f"hero_{hid}.png"
            if not p.is_file():
                continue
            total += 1
            kb = p.stat().st_size // 1024
            cells.append(f"""
        <div class="cell">
          <div class="phone" data-src="{sub}/{loc}/hero_{hid}.png"
               data-cap="FILE {hid} · {loc} · {kb}KB">
            <img src="{sub}/{loc}/hero_{hid}.png" alt="hero {hid} {loc}" loading="lazy">
          </div>
          <div class="loc"><i></i><em>{label}</em> · {loc} · {kb}KB</div>
        </div>""")
        if not cells:
            continue
        role = (h.get("role") or "").upper()
        rows.append(f"""
    <section class="hero">
      <div class="hhead">
        <span class="hid">FILE {hid}</span>
        <span class="hname">{h.get('name', '')}</span>
        <span class="hrole">{role}</span>
        <span class="hmeta">{'1920×1080 · 16:9' if land else '1080×1920 · 9:16'}</span>
      </div>
      <div class="grid">{''.join(cells)}
      </div>
    </section>""")

    html = f"""<!DOCTYPE html>
<html lang="zh-CN"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>英雄卡验收 · {variant}</title>
<style>{CSS}</style>
</head><body>
<div class="wrap" style="--cols:{2 if land else 4};--ar:{'16/9' if land else '9/16'}">
  <header>
    <div>
      <h1>英雄卡验收 · 变体 {variant} · {'横版 16:9（对齐现网 1920×1080）' if land else '竖版 9:16'}</h1>
      <p class="sub">底图由 <b>TS-Art-Restyle</b> 按「特征卡 + 空舞台板」重画（立绘只贡献特征，不作种子）；
        文案本地压真字体，四语同版式。</p>
    </div>
    <div class="chips">
      <span class="chip"><b>{total}</b> 张</span>
      <span class="chip">{'1920×1080' if land else '1080×1920'}</span>
      <span class="chip">{'16:9' if land else '9:16'}</span>
      <span class="chip"><b>4</b> 语言</span>
    </div>
  </header>
  {''.join(rows)}
  <footer>
    规格：最短边 ≥320 / 最长边 ≤3840 / 长宽比 ≤2:1 / 单张 ≤8MB —— 本页全部
    {'16:9 1920×1080（横版，与线上 phoneScreenshots 一致）' if land else '9:16 1080×1920'}。<br>
    重建：<code>python3 scripts/aso/hero_keyart.py render --ids … --size {'1920x1080' if land else '1080x1920'} --wait</code> →
    <code>collect --size {'1920x1080' if land else '1080x1920'}</code> →
    <code>aso_assets.py heroes --variant {variant}{' --orient land --feature' if land else ''}</code> → 本页。<br>
    体检：<code>python3 scripts/aso/aso_assets.py check --variant {variant}</code>
  </footer>
</div>
<div id="lb"><img alt="preview"><div class="cap"></div></div>
<script>{JS}</script>
</body></html>
"""
    out.write_text(html, encoding="utf-8")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="英雄卡验收页")
    ap.add_argument("--variant", default="B")
    ap.add_argument("--orient", choices=["port", "land"], default="port")
    a = ap.parse_args()
    p = build(a.variant, a.orient)
    print(f"[hero_page] {p}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
