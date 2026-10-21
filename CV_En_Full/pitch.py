import subprocess, numpy as np, json, os
def load16k(path):
    p = subprocess.run(["ffmpeg","-v","error","-i",path,"-ac","1","-ar","16000","-f","f32le","-"],capture_output=True)
    return np.frombuffer(p.stdout, dtype=np.float32)

def median_f0(x, sr=16000, fmin=60, fmax=400):
    win=int(0.04*sr); hop=int(0.02*sr)
    if len(x)<win: return 0.0
    f0s=[]
    for i in range(0, len(x)-win, hop):
        fr=x[i:i+win].astype(np.float64)
        if np.sqrt((fr**2).mean()) < 0.01: continue
        fr=fr-fr.mean()
        ac=np.correlate(fr,fr,mode='full')[win-1:]
        lo=int(sr/fmax); hi=int(sr/fmin)
        if hi>=len(ac): continue
        seg=ac[lo:hi]
        if len(seg)==0: continue
        peak=int(np.argmax(seg))+lo
        if ac[peak] <= 0: continue
        f0s.append(sr/peak)
    if not f0s: return 0.0
    return float(np.median(f0s))

inv=json.load(open("CV_En_Full/audio_inventory.json"))
res={}
for it in inv:
    if "/Audio/CV/" not in it["path"] and "battle" not in it["name"].lower(): continue
    x=load16k(it["path"])
    res[it["path"]]={"dur":it["dur"],"f0":round(median_f0(x),1)}
json.dump(res,open("CV_En_Full/pitch.json","w"),indent=1)
vals=[v["f0"] for v in res.values() if v["f0"]>0]
print(len(res), "measured", len(vals), "median", round(float(np.median(vals)),1))
