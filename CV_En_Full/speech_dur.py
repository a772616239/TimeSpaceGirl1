import subprocess, json, os, tempfile
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.chdir(ROOT)
inv=json.load(open("CV_En_Full/audio_inventory.json",encoding="utf-8"))
tmp=tempfile.mktemp(suffix=".wav")
def speech_dur(p):
    subprocess.run(["ffmpeg","-y","-v","error","-i",p,"-af",
        "silenceremove=start_periods=1:start_duration=0:start_threshold=-45dB:detection=peak,"
        "areverse,silenceremove=start_periods=1:start_duration=0:start_threshold=-45dB:detection=peak,areverse",
        "-ac","1","-ar","16000",tmp],capture_output=True)
    r=subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",tmp],capture_output=True,text=True)
    try: return float(r.stdout.strip())
    except: return 0.0
n=0
for it in inv:
    if "/Audio/CV/" not in it["path"] and "/Audio/Battle/" not in it["path"]: continue
    d=speech_dur(it["path"])
    it["speech_dur"]=round(d,3) if d>0.1 else it["dur"]
    n+=1
    if n%50==0: print(n,flush=True)
json.dump(inv,open("CV_En_Full/audio_inventory.json","w",encoding="utf-8"),ensure_ascii=False,indent=1)
print("done",n)
