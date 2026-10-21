#!/usr/bin/env python3
"""把英文音频的响度对齐到对应中文原声（mean_volume 匹配，防止削波）。"""
import os, re, subprocess, sys, tempfile
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.chdir(ROOT)
EN="CV_En_Full/en"
SRC=["Assets/ManagedResources/Audio/CV","Assets/ManagedResources/Audio/Battle"]
def vol(p):
    r=subprocess.run(["ffmpeg","-i",p,"-af","volumedetect","-f","null","-"],capture_output=True,text=True)
    m=re.search(r"mean_volume:\s*(-?[\d.]+) dB",r.stderr); x=re.search(r"max_volume:\s*(-?[\d.]+) dB",r.stderr)
    if not m: return None,None
    return float(m.group(1)), float(x.group(1)) if x else -99.0
def src_of(name):
    for d in SRC:
        p=os.path.join(d,name)
        if os.path.exists(p): return p
    return None
n=0; skipped=0
for f in sorted(os.listdir(EN)):
    new=os.path.join(EN,f); orig=src_of(f)
    if not orig: skipped+=1; continue
    om,ox=vol(orig); nm,nx=vol(new)
    if om is None or nm is None: skipped+=1; continue
    gain=om-nm
    if nx+gain > -0.3: gain=-0.3-nx
    if abs(gain)<0.8: continue
    tmp=new+".tmp"+os.path.splitext(f)[1]
    enc=["-c:a","pcm_s16le"] if f.lower().endswith(".wav") else ["-c:a","libmp3lame","-b:a","192k"]
    subprocess.run(["ffmpeg","-y","-v","error","-i",new,"-af",f"volume={gain:.2f}dB",
                    "-ac","2","-ar","48000"]+enc+[tmp],check=False)
    if os.path.exists(tmp):
        os.replace(tmp,new); n+=1
print(f"normalized {n}, skipped {skipped}")
