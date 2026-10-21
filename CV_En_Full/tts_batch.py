#!/usr/bin/env python3
"""批量英文配音：edge-tts 合成 -> 按原时长对齐(atempo) -> 48k/立体声/192k mp3
输入 lines.csv: file,zh,en,voice,target_dur
输出: CV_En_Full/en/<原文件名>
"""
import asyncio, csv, json, os, subprocess, sys, tempfile
import edge_tts

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTDIR = os.path.join(ROOT, "CV_En_Full", "en")
SRC_DIRS = [os.path.join(ROOT, "Assets/ManagedResources/Audio/CV"),
            os.path.join(ROOT, "Assets/ManagedResources/Audio/Battle")]
TMP = tempfile.mkdtemp(prefix="ttsen_")
SEM = asyncio.Semaphore(6)

def dur_of(p):
    r = subprocess.run(["ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",p],
                       capture_output=True, text=True)
    try: return float(r.stdout.strip())
    except: return 0.0

def find_src(name):
    for d in SRC_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p): return p
    return None

async def synth(text, voice, rate, path, pitch=""):
    async with SEM:
        for attempt in range(3):
            try:
                kw = {"rate": rate}
                if pitch: kw["pitch"] = pitch
                c = edge_tts.Communicate(text, voice, **kw)
                await c.save(path)
                if os.path.exists(path) and os.path.getsize(path) > 1000: return True
            except Exception as e:
                await asyncio.sleep(1.5 * (attempt + 1))
        return False

def trim(src, dst):
    subprocess.run(["ffmpeg","-y","-v","error","-i",src,"-af",
        "silenceremove=start_periods=1:start_duration=0:start_threshold=-45dB:detection=peak,"
        "areverse,silenceremove=start_periods=1:start_duration=0:start_threshold=-45dB:detection=peak,areverse",
        "-ac","1","-ar","48000",dst], check=False)
    return dst

async def one(row):
    name = row["file"]; text = row["en"].strip(); voice = row["voice"]
    target = float(row["target_dur"])
    pitch = row.get("pitch", "") or ""
    if not text:
        return {**row, "status": "empty"}
    raw = os.path.join(TMP, name + ".raw.mp3")
    kw = {"rate": "+0%"}
    if pitch: kw["pitch"] = pitch
    ok = await synth(text, voice, "+0%", raw, pitch)
    if not ok: return {**row, "status": "tts_fail"}
    tr = trim(raw, os.path.join(TMP, name + ".trim.wav"))
    d0 = dur_of(tr)
    used_rate, cur, curd = 0, tr, d0
    # 超长则提速重合成，最多两轮（短句允许更大幅度）
    cap = 45 if target <= 1.5 else 32
    for _ in range(2):
        if curd <= target * 1.03: break
        need = min(int(round((curd / target - 1) * 100)) + 1, cap)
        if need <= used_rate: break
        used_rate = need
        nxt = os.path.join(TMP, f"{name}.r{need}.mp3")
        if await synth(text, voice, f"+{need}%", nxt, pitch):
            cur = trim(nxt, os.path.join(TMP, f"{name}.r{need}.wav"))
            curd = dur_of(cur)
    # 过短（英文比中文短很多）时，轻微放慢重合成一次，让节奏更贴近原声
    if used_rate == 0 and target >= 1.2 and curd < target * 0.75:
        nxt = os.path.join(TMP, f"{name}.slow.mp3")
        if await synth(text, voice, "-15%", nxt, pitch):
            ntr = trim(nxt, os.path.join(TMP, f"{name}.slow.wav"))
            nd = dur_of(ntr)
            if abs(nd - target) < abs(curd - target):
                cur, curd, used_rate = ntr, nd, -15
    atempo = 1.0
    if target > 0 and curd > 0:
        r = curd / target
        hi = 1.35 if target <= 1.5 else 1.18
        if 0.85 <= r <= hi: atempo = max(0.88, min(hi, r))
    out = os.path.join(OUTDIR, name)
    filt = f"atempo={atempo:.4f},aresample=48000" if abs(atempo - 1.0) > 0.004 else "aresample=48000"
    if name.lower().endswith(".wav"):
        enc = ["-c:a","pcm_s16le"]
    else:
        enc = ["-c:a","libmp3lame","-b:a","192k"]
    subprocess.run(["ffmpeg","-y","-v","error","-i",cur,"-af",filt,
                    "-ac","2","-ar","48000"]+enc+[out], check=False)
    return {**row, "out": os.path.basename(out), "tts_dur": round(d0,3),
            "rate": f"+{used_rate}%", "atempo": round(atempo,3),
            "final_dur": round(dur_of(out),3), "status": "ok"}

async def main():
    os.makedirs(OUTDIR, exist_ok=True)
    with open(sys.argv[1], encoding="utf-8") as f:
        rows = [r for r in csv.DictReader(f) if r.get("en","").strip()]
    only = sys.argv[2] if len(sys.argv) > 2 else None
    if only: rows = [r for r in rows if only in r["file"]]
    print(f"jobs {len(rows)}", flush=True)
    res = []
    for i in range(0, len(rows), 12):
        chunk = rows[i:i+12]
        out = await asyncio.gather(*[one(r) for r in chunk])
        res += out
        for o in out:
            if o.get("status") == "ok":
                dev = (o["final_dur"] - float(o["target_dur"])) / float(o["target_dur"]) * 100
                print(f"[{len(res)}/{len(rows)}] {o['file'][:38]:38s} tgt {o['target_dur']:>5} "
                      f"-> {o['final_dur']:>5} ({dev:+.1f}%) {o['voice']}", flush=True)
            else:
                print(f"[{len(res)}/{len(rows)}] {o['file'][:38]:38s} {o.get('status')}", flush=True)
    with open(os.path.join(ROOT,"CV_En_Full","tts_report.csv"),"w",newline="",encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(res[0].keys()))
        w.writeheader(); w.writerows(res)
    print("DONE", flush=True)

if __name__ == "__main__":
    asyncio.run(main())
