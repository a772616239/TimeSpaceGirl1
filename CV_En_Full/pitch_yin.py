import subprocess, numpy as np, json, os
def load16k(p):
    r=subprocess.run(["ffmpeg","-v","error","-i",p,"-ac","1","-ar","16000","-f","f32le","-"],capture_output=True)
    return np.frombuffer(r.stdout,dtype=np.float32).copy()

def yin_frame(fr, sr, fmin=60, fmax=400, thr=0.15):
    W=len(fr); tmax=min(int(sr/fmin), W-1); tmin=max(2,int(sr/fmax))
    d=np.zeros(tmax)
    for tau in range(1,tmax):
        diff=fr[:W-tau]-fr[tau:]
        d[tau]=np.dot(diff,diff)
    cmnd=np.ones(tmax)
    run=0.0
    for tau in range(1,tmax):
        run+=d[tau]
        cmnd[tau]=d[tau]*tau/run if run>0 else 1.0
    for tau in range(tmin,tmax):
        if cmnd[tau]<thr:
            while tau+1<tmax and cmnd[tau+1]<cmnd[tau]: tau+=1
            return sr/tau
    seg=cmnd[tmin:tmax]
    if len(seg)==0: return 0.0
    t=int(np.argmin(seg))+tmin
    return sr/t if cmnd[t]<0.35 else 0.0

def f0_of(x, sr=16000):
    win=int(0.04*sr); hop=int(0.02*sr); out=[]
    for i in range(0,len(x)-win,hop):
        fr=x[i:i+win].astype(np.float64)
        if np.sqrt((fr**2).mean())<0.02: continue
        fr=fr-fr.mean()
        f=yin_frame(fr,sr)
        if f>0: out.append(f)
    return float(np.median(out)) if out else 0.0

pitch=json.load(open("CV_En_Full/pitch.json"))
for p,v in pitch.items():
    if "_CV_" in p and "_show" in p:
        v["yin"]=round(f0_of(load16k(p)),1)
json.dump(pitch,open("CV_En_Full/pitch.json","w"),indent=1)
for p,v in sorted(pitch.items()):
    if "_CV_" in p and "_show" in p:
        print(os.path.basename(p), v.get("f0"), "->", v.get("yin"))
