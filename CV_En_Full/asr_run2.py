import subprocess, numpy as np, json, os, time, re
from faster_whisper import WhisperModel
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.chdir(ROOT)
out_path = "CV_En_Full/asr_raw.jsonl"
done = set()
if os.path.exists(out_path):
    for line in open(out_path, encoding="utf-8"):
        try: done.add(json.loads(line)["path"])
        except: pass
_SKIP = re.compile(r"(hit|impact|explosion|gore|bash|cyber|amb|snd_|mothership|button|window|gate|switch|stop|open|close|enter|lottery_show)", re.I)
inv = [x for x in json.load(open("CV_En_Full/audio_inventory.json", encoding="utf-8"))
       if not _SKIP.search(x["name"].split("/")[-1]) and x["path"] not in done]
inv.sort(key=lambda x: (0 if "/Audio/CV/" in x["path"] else 1, x["path"]))
print("todo", len(inv), flush=True)
def load16k(p):
    r = subprocess.run(["ffmpeg","-v","error","-i",p,"-ac","1","-ar","16000","-f","f32le","-"], capture_output=True)
    return np.frombuffer(r.stdout, dtype=np.float32).copy()
m = WhisperModel("medium", device="cpu", compute_type="int8", cpu_threads=8,
                 download_root=".workbuddy-ai/tmp/whisper")
fout = open(out_path, "a", encoding="utf-8"); t0=time.time()
for i, c in enumerate(inv, 1):
    a = load16k(c["path"])
    ss = list(m.transcribe(a, language="zh", beam_size=5, vad_filter=False,
                           condition_on_previous_text=False)[0])
    fout.write(json.dumps({"path":c["path"],"dur":c["dur"],
                           "text":"".join(s.text for s in ss).strip(),
                           "nsp":round(max([s.no_speech_prob for s in ss], default=1.0),3),
                           "lp":round(min([s.avg_logprob for s in ss], default=-9.0),3)},
                          ensure_ascii=False)+"\n")
    if i % 10 == 0:
        fout.flush(); print(f"{i}/{len(inv)} {time.time()-t0:.0f}s", flush=True)
fout.close(); print("DONE", flush=True)
