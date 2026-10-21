import subprocess, numpy as np, json, os, sys, time
from faster_whisper import WhisperModel

import re as _re
_SKIP = _re.compile(r"(hit|impact|explosion|gore|bash|cyber|amb|snd_|mothership|button|window|gate|switch|stop|open|close|enter|lottery_show)", _re.I)
inv = [x for x in json.load(open("CV_En_Full/audio_inventory.json"))
       if not _SKIP.search(x["name"].split("/")[-1])]
print("targets", len(inv), flush=True)
out_path = "CV_En_Full/asr_raw.jsonl"
done = set()
if os.path.exists(out_path):
    for line in open(out_path):
        try: done.add(json.loads(line)["path"])
        except: pass

def load16k(path):
    p = subprocess.run(["ffmpeg","-v","error","-i",path,"-ac","1","-ar","16000","-f","f32le","-"],
                       capture_output=True)
    return np.frombuffer(p.stdout, dtype=np.float32)

m = WhisperModel("medium", device="cpu", compute_type="int8", cpu_threads=10,
                 download_root=".workbuddy-ai/tmp/whisper")
fout = open(out_path, "a")
t0=time.time()
for i, item in enumerate(inv):
    p = item["path"]
    if p in done: continue
    audio = load16k(p)
    if len(audio) < 1600:
        fout.write(json.dumps({"path":p,"dur":item["dur"],"text":"","nsp":1.0,"lp":0.0},ensure_ascii=False)+"\n"); fout.flush(); continue
    segs, info = m.transcribe(audio, language="zh", beam_size=5, vad_filter=False,
                              condition_on_previous_text=False)
    segs = list(segs)
    text = "".join(s.text for s in segs).strip()
    nsp = max([s.no_speech_prob for s in segs], default=1.0)
    alp = min([s.avg_logprob for s in segs], default=-9.0)
    fout.write(json.dumps({"path":p,"dur":item["dur"],"text":text,"nsp":round(nsp,3),
                           "lp":round(alp,3),"langp":round(info.language_probability,3)},
                          ensure_ascii=False)+"\n")
    fout.flush()
    if i % 20 == 0:
        print(f"[{i}/{len(inv)}] {os.path.basename(p)} -> {text[:30]}  ({time.time()-t0:.0f}s)", flush=True)
fout.close()
print("DONE", flush=True)
