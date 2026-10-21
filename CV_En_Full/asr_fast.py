import subprocess, numpy as np, json, os, time, re
from faster_whisper import WhisperModel, BatchedInferencePipeline

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(ROOT)
out_path = "CV_En_Full/asr_raw.jsonl"
done = set()
if os.path.exists(out_path):
    for line in open(out_path, encoding="utf-8"):
        try: done.add(json.loads(line)["path"])
        except: pass

_SKIP = re.compile(r"(hit|impact|explosion|gore|bash|cyber|amb|snd_|mothership|button|window|gate|switch|stop|open|close|enter|lottery_show)", re.I)
inv = [x for x in json.load(open("CV_En_Full/audio_inventory.json", encoding="utf-8"))
       if not _SKIP.search(x["name"].split("/")[-1])]
inv = [x for x in inv if x["path"] not in done]
inv.sort(key=lambda x: x["dur"])
print("todo", len(inv), flush=True)

def load16k(path):
    p = subprocess.run(["ffmpeg","-v","error","-i",path,"-ac","1","-ar","16000","-f","f32le","-"], capture_output=True)
    a = np.frombuffer(p.stdout, dtype=np.float32).copy()
    return a

m = WhisperModel("medium", device="cpu", compute_type="int8", cpu_threads=12,
                 download_root=".workbuddy-ai/tmp/whisper")
pipe = BatchedInferencePipeline(model=m)
fout = open(out_path, "a", encoding="utf-8")
t0 = time.time(); n = 0
B = 8
for i in range(0, len(inv), B):
    chunk = inv[i:i+B]
    audios = [load16k(c["path"]) for c in chunk]
    try:
        segs, infos = pipe.transcribe(audios, language="zh", batch_size=len(audios),
                                      beam_size=5, vad_filter=False)
        per = {k: [] for k in range(len(chunk))}
        ok = True
        for s in segs:
            sid = getattr(s, "id", None)
            if sid is None: ok = False; break
            per[sid].append(s)
        if not ok: raise RuntimeError("no id")
        for k, c in enumerate(chunk):
            ss = per[k]
            text = "".join(x.text for x in ss).strip()
            nsp = max([x.no_speech_prob for x in ss], default=1.0)
            alp = min([x.avg_logprob for x in ss], default=-9.0)
            fout.write(json.dumps({"path":c["path"],"dur":c["dur"],"text":text,"nsp":round(nsp,3),
                                   "lp":round(alp,3)}, ensure_ascii=False)+"\n")
            n += 1
    except Exception as e:
        for c, audio in zip(chunk, audios):
            ss, info = m.transcribe(audio, language="zh", beam_size=5, vad_filter=False,
                                    condition_on_previous_text=False)
            ss = list(ss)
            text = "".join(x.text for x in ss).strip()
            nsp = max([x.no_speech_prob for x in ss], default=1.0)
            alp = min([x.avg_logprob for x in ss], default=-9.0)
            fout.write(json.dumps({"path":c["path"],"dur":c["dur"],"text":text,"nsp":round(nsp,3),
                                   "lp":round(alp,3)}, ensure_ascii=False)+"\n")
            n += 1
    fout.flush()
    print(f"{n}/{len(inv)}  {time.time()-t0:.0f}s", flush=True)
fout.close(); print("DONE", flush=True)
