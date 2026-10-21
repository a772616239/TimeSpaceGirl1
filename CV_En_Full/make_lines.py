#!/usr/bin/env python3
"""合并 ASR/翻译/基频/音色 -> lines.csv（供 tts_batch.py 使用）"""
import json, os, csv, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cast import pick
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.chdir(ROOT)
asr={}
for l in open("CV_En_Full/asr_raw.jsonl",encoding="utf-8"):
    r=json.loads(l); asr[r["path"]]=r
pitch=json.load(open("CV_En_Full/pitch.json",encoding="utf-8"))
inv=json.load(open("CV_En_Full/audio_inventory.json",encoding="utf-8"))
tr=json.load(open("CV_En_Full/translations_cv.json",encoding="utf-8"))
if os.path.exists("CV_En_Full/translations_battle.json"):
    tr.update(json.load(open("CV_En_Full/translations_battle.json",encoding="utf-8")))

def stem_of(name):
    s=name.rsplit(".",1)[0]
    s=re.sub(r"^cn2-[xX]1_","",s)
    s=re.sub(r"^(CV|Battle)_","",s,flags=re.I)
    return s

# 先按英雄聚合基频中位数，性别按角色统一（避免短句误判）
from statistics import median
hero_f0={}
for it in inv:
    st=stem_of(it["name"])
    f=pitch.get(it["path"],{}).get("yin") or pitch.get(it["path"],{}).get("f0",0)
    if f: hero_f0.setdefault(st.split("_")[0],[]).append(f)
hero_f0={k:median(v) for k,v in hero_f0.items()}

rows=[]
for it in inv:
    p,name=it["path"],it["name"]
    if "/Audio/CV/" not in p and "/Audio/Battle/" not in p: continue
    if name.startswith("buff"): continue
    stem=stem_of(name)
    if "/Audio/Battle/" in p: stem="battle__"+stem
    if stem not in tr: continue
    zh,en,note=tr[stem]
    hero=stem.split("_")[0]
    f0=round(hero_f0.get(hero,0),1)
    gender="F" if f0>=235 else "M"
    voice,pit=pick(hero, gender, f0)
    rows.append({"file":name,"stem":stem,"zh":zh,"en":en,"voice":voice,
                 "pitch":f"{pit:+d}Hz" if pit else "",
                 "target_dur":it.get("speech_dur") or it["dur"],"f0":f0,"gender":gender,"note":note})
rows.sort(key=lambda r:(r["stem"]))
with open("CV_En_Full/lines.csv","w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=["file","stem","zh","en","voice","pitch","target_dur","f0","gender","note"])
    w.writeheader(); w.writerows(rows)
todo=[r for r in rows if not r["en"].strip()]
print("lines",len(rows),"待翻译/待听音",len(todo))
for r in todo[:20]: print("  ",r["stem"])
