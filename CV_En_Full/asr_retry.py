"""对识别为空/可疑的条目做二次识别（更高 beam + 温度回退 + 上下文提示）。"""
import subprocess, numpy as np, json, os, sys
from faster_whisper import WhisperModel
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.chdir(ROOT)
rows=[json.loads(l) for l in open("CV_En_Full/asr_raw.jsonl",encoding="utf-8")]
by={r["path"]:r for r in rows}
targets=[p for p,r in by.items() if not r["text"].strip()]
targets+= [p for p in sys.argv[1:] if p in by]
def load16k(p):
    r=subprocess.run(["ffmpeg","-v","error","-i",p,"-ac","1","-ar","16000","-f","f32le","-"],capture_output=True)
    return np.frombuffer(r.stdout,dtype=np.float32).copy()
m=WhisperModel("medium",device="cpu",compute_type="int8",cpu_threads=8,download_root=".workbuddy-ai/tmp/whisper")
out={}
for p in targets:
    a=load16k(p)
    best=""
    for t in (0.0,0.4,0.8):
        segs=list(m.transcribe(a,language="zh",beam_size=10,vad_filter=False,
                 condition_on_previous_text=False,temperature=t,
                 initial_prompt="以下是游戏角色的中文台词，可能是喊叫、咒语或诗句。")[0])
        txt="".join(s.text for s in segs).strip()
        if len(txt)>len(best): best=txt
    out[os.path.basename(p)]=best
    print(f"{os.path.basename(p):40s} {best}", flush=True)
json.dump(out,open("CV_En_Full/asr_retry.json","w"),ensure_ascii=False,indent=1)
