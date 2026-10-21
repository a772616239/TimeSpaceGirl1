#!/usr/bin/env python3
"""把 CV_En_Full/en 里的英文音频替换进工程（先备份中文原声）。
用法: python deploy.py apply|revert [--dirs cv,battle]
"""
import os, sys, shutil, json
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.chdir(ROOT)
EN="CV_En_Full/en"; BAK="CV_En_Full/zh_backup"
DIRS={"cv":"Assets/ManagedResources/Audio/CV","battle":"Assets/ManagedResources/Audio/Battle"}
def targets(which):
    for k,d in DIRS.items():
        if which and k not in which: continue
        for f in sorted(os.listdir(d)):
            if f.lower().endswith((".mp3",".wav")) and os.path.exists(os.path.join(EN,f.replace(".wav",".mp3"))):
                yield os.path.join(d,f), os.path.join(EN,f.replace(".wav",".mp3"))
def apply(which):
    n=0
    for dst,src in targets(which):
        os.makedirs(BAK,exist_ok=True)
        b=os.path.join(BAK,os.path.basename(dst))
        if not os.path.exists(b): shutil.copy2(dst,b)
        shutil.copy2(src,dst); n+=1
    print("deployed",n)
def revert(which):
    n=0
    for dst,_ in targets(which):
        b=os.path.join(BAK,os.path.basename(dst))
        if os.path.exists(b): shutil.copy2(b,dst); n+=1
    print("reverted",n)
if __name__=="__main__":
    cmd=sys.argv[1]; which=sys.argv[2] if len(sys.argv)>2 else ""
    {"apply":apply,"revert":revert}[cmd](which)
