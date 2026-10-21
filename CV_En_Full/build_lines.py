#!/usr/bin/env python3
"""合并 ASR 结果 + 基频 + 英雄表 -> lines.csv（zh 已填，en/voice 待填）"""
import json, csv, re, os, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
asr = {}
for line in open(os.path.join(ROOT,"CV_En_Full/asr_raw.jsonl"), encoding="utf-8"):
    r = json.loads(line); asr[r["path"]] = r
pitch = json.load(open(os.path.join(ROOT,"CV_En_Full/pitch.json"), encoding="utf-8"))
inv = json.load(open(os.path.join(ROOT,"CV_En_Full/audio_inventory.json"), encoding="utf-8"))

# 传统字 -> 简体（ASR 输出偶发繁体）
TRAD = {"發":"发","嗎":"吗","麼":"么","個":"个","們":"们","來":"来","這":"这","說":"说","會":"会",
        "對":"对","沒":"没","後":"后","無":"无","與":"与","為":"为","還":"还","讓":"让","過":"过",
        "點":"点","麼":"么","樣":"样","時":"时","開":"开","關":"关","頭":"头","見":"见","東":"东",
        "覺":"觉","給":"给","師":"师","義":"义","戰":"战","殺":"杀","聖":"圣","劍":"剑","聲":"声"}

def simp(s):
    return "".join(TRAD.get(ch, ch) for ch in s)

BAD = re.compile(r"(优优独播|MING PAO|字幕|Subtitle|請不吝點贊|点赞|订阅|Amara\.org|感谢观看|謝謝觀看)", re.I)

def is_speech(r):
    t = (r.get("text") or "").strip()
    if not t: return False
    if BAD.search(t): return False
    if r.get("nsp", 0) > 0.62: return False
    if r.get("lp", 0) < -1.1: return False
    return True

def hero_key(name):
    n = name.lower()
    n = re.sub(r"\.(mp3|wav)$", "", n)
    n = n.replace("cn2-x1_", "").replace("cn2-x1", "")
    n = re.sub(r"^(cv|battle)_", "", n)
    n = re.sub(r"_(show|skill0?\d.*|attack.*|normal_hit|normail_hit|hit.*)$", "", n)
    return n

# 英雄表：pinyin key -> 中文名
heroes = {}
import openpyxl
wb = openpyxl.load_workbook(os.path.join(ROOT,"data_execl/base_data/HeroConfig.xlsx"), read_only=True, data_only=True)
ws = wb["HeroConfig"]
for r in ws.iter_rows(min_row=6, values_only=True):
    if not r[1] or not r[52]: continue
    k = str(r[52]).lower().replace("x1_cv_","").replace("_show","")
    heroes[k] = r[4]

rows = []
for it in inv:
    p, name = it["path"], it["name"]
    if "/Audio/CV/" not in p and "/Audio/Battle/" not in p: continue
    if name.startswith("buff"): continue
    a = asr.get(p)
    if not a: continue
    if not is_speech(a): continue
    key = hero_key(name)
    f0 = pitch.get(p, {}).get("f0", 0)
    rows.append({"file": name, "path": p, "key": key, "hero": heroes.get(key, ""),
                 "f0": f0, "gender": "F" if f0 >= 200 else ("M" if f0 > 0 else "?"),
                 "target_dur": it["dur"], "zh": simp(a["text"]), "en": "", "voice": ""})

rows.sort(key=lambda r: (r["key"], r["file"]))
with open(os.path.join(ROOT,"CV_En_Full/lines.csv"), "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader(); w.writerows(rows)
print("lines", len(rows), "M", sum(1 for r in rows if r["gender"]=="M"),
      "F", sum(1 for r in rows if r["gender"]=="F"), "?", sum(1 for r in rows if r["gender"]=="?"))
