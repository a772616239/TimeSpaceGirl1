#!/usr/bin/env python3
"""生成中英交替试听：每个英雄一段 中文->英文->中文->英文 的 mp3。"""
import json, os, subprocess, csv, sys
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
OUT="CV_En_Full/preview"; os.makedirs(OUT,exist_ok=True)
rows=[json.loads(l) for l in open("CV_En_Full/asr_raw.jsonl",encoding="utf-8")]
srcs={}
for r in rows:
    n=os.path.basename(r["path"])
    if "/Audio/CV/" in r["path"]:
        stem=n.replace("cn2-X1_CV_","").rsplit(".",1)[0]
        srcs.setdefault(stem.split("_")[0],[]).append((stem,r["path"],r["dur"]))
heroes=sorted(srcs)
sel=sys.argv[1:] or heroes[:12]
for h in sel:
    items=sorted(srcs.get(h,[]),key=lambda x:x[0])
    parts=[];filters=[]
    for stem,p,d in items:
        en=os.path.join("CV_En_Full/en",os.path.basename(p).replace(".wav",".mp3"))
        if not os.path.exists(en): continue
        parts += [p,en]; 
    if not parts: continue
    cmd=["ffmpeg","-y","-v","error"]
    for p in parts: cmd+=["-i",p]
    n=len(parts)
    fc="".join(f"[{i}:a]aresample=48000,apad=pad_dur=0.25[a{i}];" for i in range(n))
    fc+="".join(f"[a{i}]" for i in range(n))+f"concat=n={n}:v=0:a=1[out]"
    cmd+=["-filter_complex",fc,"-map","[out]","-ac","2","-ar","48000","-b:a","192k",os.path.join(OUT,f"{h}_cn_en.mp3")]
    subprocess.run(cmd,check=False)
print("preview ->",OUT)
