"""战斗语音单独识别：逐条 + VAD，避免打包时的时间戳串位。"""
import subprocess, numpy as np, json, os, time
from faster_whisper import WhisperModel
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.chdir(ROOT)
OUT="CV_En_Full/asr_battle.jsonl"
done=set()
if os.path.exists(OUT):
    for l in open(OUT,encoding="utf-8"):
        try: done.add(json.loads(l)["path"])
        except: pass
inv=[x for x in json.load(open("CV_En_Full/audio_inventory.json",encoding="utf-8"))
     if "/Audio/Battle/" in x["path"] and x["path"] not in done]
inv.sort(key=lambda x:x["path"])
print("todo",len(inv),flush=True)
def load16k(p):
    r=subprocess.run(["ffmpeg","-v","error","-i",p,"-ac","1","-ar","16000","-f","f32le","-"],capture_output=True)
    return np.frombuffer(r.stdout,dtype=np.float32).copy()
m=WhisperModel("medium",device="cpu",compute_type="int8",cpu_threads=10,download_root=".workbuddy-ai/tmp/whisper")
fout=open(OUT,"a",encoding="utf-8"); t0=time.time()
for i,c in enumerate(inv,1):
    a=load16k(c["path"])
    ss=list(m.transcribe(a,language="zh",beam_size=5,vad_filter=True,
                         vad_parameters=dict(min_silence_duration_ms=300),
                         condition_on_previous_text=False)[0])
    txt="".join(s.text for s in ss).strip()
    fout.write(json.dumps({"path":c["path"],"dur":c["dur"],"text":txt},ensure_ascii=False)+"\n")
    if i%10==0:
        fout.flush(); print(f"{i}/{len(inv)} {time.time()-t0:.0f}s",flush=True)
fout.close(); print("DONE",flush=True)
