#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Extract key frames from the final video and build a self-contained storyboard page."""
import os, subprocess, html

ROOT = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "storyboard")
os.makedirs(OUT, exist_ok=True)
SRC = os.path.join(ROOT, "TimeSpaceGirl_promo_30s_9x16.mp4")

SCENES = [
    dict(t=1.90, tc="0.0 – 3.4", title="点名 · 钩子",
         en=["SUMMON", "THEM."],
         cn="终端上线，把历史最强的人拉出来",
         vo="GUAN YU — “If you bore me, you'll feed my blade.”",
         sfx="低频撞击 / 人声 / 终端打字",
         note="前 3 秒必须有人脸 + 人声 + 一个动词。不用 logo 开场。"),
    dict(t=4.90, tc="3.4 – 6.2", title="世界观 · 品牌",
         en=["THE CITY FELL.", "THE LEGENDS WOKE."],
         cn="废墟都市 + LOGO 故障闪入",
         vo="—",
         sfx="转场冲击 / 上翻音",
         note="两句对仗把世界观说完，第 5.5s 立品牌。"),
    dict(t=7.00, tc="6.2 – 8.6", title="阵容快切",
         en=["LEGEND 01 … 06"],
         cn="6 位英雄脸部，每 0.4 秒一刀",
         vo="—",
         sfx="快门 + UI 点击 ×6",
         note="展示“古今中外 + 有男有女”，打破“只有美少女”的预期。"),
    dict(t=10.00, tc="8.6 – 13.4", title="角色铭牌",
         en=["GUAN YU — PHYSICAL · SILENCE & BURST DAMAGE"],
         cn="三张完整铭牌立绘：关羽 / 赵云 / 布鲁图斯",
         vo="GUAN YU — “Satisfying! Again!” / HASSAN — “You're not escaping.” / BRUTUS — “Pierce the void!”",
         sfx="翻卡音 ×3",
         note="二次元用户真正看的是“定位 + 台词”，这段是转化核心。"),
    dict(t=15.60, tc="13.4 – 18.0", title="战斗",
         en=["5 v 5 TURN-BASED", "BUILD. BREAK. WIN."],
         cn="对决构图：我方关羽 vs BOSS 哈桑，三次斩击",
         vo="HASSAN (BOSS) — “If I find no offering, I’ll sacrifice you.”",
         sfx="战斗开场 / 命中 ×3 / 暴击",
         note="伤害数字用金色不用血红；状态字（SILENCE / BURN）证明有策略深度。"),
    dict(t=20.40, tc="18.0 – 22.2", title="掷骰探索",
         en=["ROLL.", "RAID.", "REPEAT."],
         cn="六边形棋盘，骰子掷出，路径逐格点亮，终点宝箱",
         vo="—",
         sfx="开箱 / 抽卡音",
         note="差异化玩法：不是纯挂机，有棋盘 roguelike 的探索感。"),
    dict(t=24.60, tc="22.2 – 25.8", title="挂机 + 十连",
         en=["IDLE 24/7", "SUMMON LEGENDS"],
         cn="收益流水上浮 + 十连翻牌爆金光",
         vo="HASSAN — “The offering is ready. Begin the rite.”",
         sfx="十连音",
         note="覆盖碎片时间需求；ZERO PAYWALLS 用的是官方公告原话。"),
    dict(t=28.40, tc="25.8 – 30.0", title="CTA",
         en=["DOWNLOAD FREE", "GUARANTEED SSR ON DAY 8"],
         cn="群像虚化 + LOGO + 白色下载按钮",
         vo="—",
         sfx="收尾重击 + 淡出",
         note="CTA 不玩悬念，按钮 + 平台信息一次给全。"),
]

def grab(t, name):
    p = os.path.join(OUT, name)
    subprocess.run(["ffmpeg", "-y", "-ss", f"{t}", "-i", SRC, "-frames:v", "1",
                    "-q:v", "2", p], capture_output=True)
    return p

cards = []
for i, s in enumerate(SCENES, 1):
    img = grab(s["t"], f"scene_{i:02d}.jpg")
    en = "".join(f"<span class='en'>{html.escape(x)}</span>" for x in s["en"])
    cards.append(f"""
    <article class="card">
      <div class="shot"><img src="storyboard/{os.path.basename(img)}" alt="scene {i}">
        <span class="tc">{s['tc']}s</span></div>
      <div class="body">
        <div class="kicker">SHOT {i:02d} · {html.escape(s['title'])}</div>
        <div class="copy">{en}</div>
        <p class="cn">{html.escape(s['cn'])}</p>
        <dl>
          <div><dt>VO</dt><dd>{html.escape(s['vo'])}</dd></div>
          <div><dt>SFX</dt><dd>{html.escape(s['sfx'])}</dd></div>
          <div><dt>意图</dt><dd>{html.escape(s['note'])}</dd></div>
        </dl>
      </div>
    </article>""")

page = f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>Time-Space Girl · 30s 竖版广告分镜</title>
<style>
  :root {{
    --ink:#141416; --sub:#6b6b73; --line:#e6e6ea; --bg:#fbfbfc;
    --red:#e4002b; --cyan:#0aa8c8; --card:#ffffff;
  }}
  * {{ box-sizing:border-box; }}
  body {{ margin:0; background:var(--bg); color:var(--ink);
    font-family:"Hiragino Sans GB","PingFang SC",-apple-system,"Helvetica Neue",sans-serif;
    -webkit-font-smoothing:antialiased; }}
  .wrap {{ max-width:1180px; margin:0 auto; padding:56px 28px 80px; }}
  header {{ border-bottom:2px solid var(--ink); padding-bottom:22px; margin-bottom:34px; }}
  .eyebrow {{ font-size:12px; letter-spacing:.22em; color:var(--red); font-weight:700; }}
  h1 {{ font-size:42px; line-height:1.15; margin:10px 0 8px; letter-spacing:-.5px; }}
  h1 em {{ font-style:normal; color:var(--red); }}
  .sub {{ color:var(--sub); font-size:15px; line-height:1.7; max-width:760px; }}
  .meta {{ display:flex; gap:26px; flex-wrap:wrap; margin-top:18px; font-size:13px; color:var(--sub); }}
  .meta b {{ color:var(--ink); font-weight:600; }}
  .bar {{ display:flex; height:44px; border-radius:8px; overflow:hidden; margin:30px 0 8px;
    font-size:11px; color:#fff; font-weight:700; letter-spacing:.06em; }}
  .bar div {{ display:flex; align-items:center; justify-content:center; }}
  .grid {{ display:grid; grid-template-columns:repeat(2,1fr); gap:26px; margin-top:34px; }}
  .card {{ background:var(--card); border:1px solid var(--line); border-radius:14px;
    overflow:hidden; box-shadow:0 1px 2px rgba(0,0,0,.04); }}
  .shot {{ position:relative; background:#000; }}
  .shot img {{ display:block; width:100%; aspect-ratio:9/16; object-fit:cover; }}
  .tc {{ position:absolute; left:12px; top:12px; background:rgba(0,0,0,.62);
    color:#fff; font-size:11px; padding:4px 9px; border-radius:5px; letter-spacing:.06em; }}
  .body {{ padding:18px 20px 20px; }}
  .kicker {{ font-size:11px; letter-spacing:.18em; color:var(--red); font-weight:700; }}
  .copy {{ margin:10px 0 8px; }}
  .en {{ display:block; font-family:"DIN Condensed","Arial Black",Impact,sans-serif;
    font-size:26px; line-height:1.08; letter-spacing:.01em; text-transform:uppercase; }}
  .cn {{ margin:0 0 14px; font-size:13px; color:var(--sub); line-height:1.6; }}
  dl {{ margin:0; border-top:1px solid var(--line); padding-top:12px; font-size:12px; }}
  dl div {{ display:flex; gap:10px; padding:4px 0; }}
  dt {{ width:34px; flex:0 0 34px; color:#9a9aa3; }}
  dd {{ margin:0; color:#3d3d44; line-height:1.6; }}
  footer {{ margin-top:44px; padding-top:18px; border-top:1px solid var(--line);
    font-size:12px; color:var(--sub); line-height:1.8; }}
  @media (max-width:820px) {{ .grid {{ grid-template-columns:1fr; }} h1 {{ font-size:30px; }} }}
</style>
</head>
<body><div class="wrap">
<header>
  <div class="eyebrow">TIME-SPACE GIRL / NEON VALKYRIES · 买量素材</div>
  <h1>30 秒竖版广告分镜<br><em>EVERY LEGEND, REBORN.</em></h1>
  <p class="sub">把“抽卡”重新包装成“用终端把历史最强的人从时间里拉出来”。全片素材取自游戏本体：铭牌立绘、主城、六边形棋盘、骰子、战斗音效、英文 CV。</p>
  <div class="meta">
    <span>规格 <b>1080×1920 / 30fps / 30s</b></span>
    <span>主色 <b>墨黑 · 血红 · 霓虹青</b></span>
    <span>卖点 <b>108 位英雄 · 5v5 · 掷骰探索 · 挂机 · 十连</b></span>
  </div>
</header>

<div class="bar">
  <div style="flex:3.4;background:#141416">HOOK 3.4s</div>
  <div style="flex:2.8;background:#2b2b30">WORLD 2.8s</div>
  <div style="flex:2.4;background:#7a0f22">CAST 2.4s</div>
  <div style="flex:4.8;background:#e4002b">HEROES 4.8s</div>
  <div style="flex:4.6;background:#0aa8c8">COMBAT 4.6s</div>
  <div style="flex:4.2;background:#5b3a8e">BOARD 4.2s</div>
  <div style="flex:3.6;background:#a06a00">IDLE 3.6s</div>
  <div style="flex:4.2;background:#141416">CTA 4.2s</div>
</div>

<div class="grid">{''.join(cards)}</div>

<footer>
  分镜时间轴与成片一致；单帧由成片直接抽帧，非设计稿。<br>
  合规：不使用未验证数值承诺，仅引用游戏内公告已有的 “Zero Paywalls” 与 “Guaranteed SSR on Day 8”；角色镜头一律取面部至胸上，不做性化特写。
</footer>
</div></body></html>"""

open(os.path.join(ROOT, "storyboard.html"), "w").write(page)
print("storyboard.html written")
