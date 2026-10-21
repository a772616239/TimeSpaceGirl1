import subprocess, numpy as np, os
from faster_whisper import WhisperModel

def load16k(path):
    p = subprocess.run(["ffmpeg","-v","error","-i",path,"-ac","1","-ar","16000","-f","f32le","-"],
                       capture_output=True)
    return np.frombuffer(p.stdout, dtype=np.float32)

m = WhisperModel("medium", device="cpu", compute_type="int8", download_root=".workbuddy-ai/tmp/whisper")
files = ["CV_Translation_Test/cn2-X1_CV_aidisheng_show.mp3",
         "CV_Translation_Test/cn2-X1_CV_aiyinsitan_show.mp3",
         "CV_Translation_Test/cn2-X1_CV_akaliusi_skill01.mp3",
         "CV_Translation_Test/cn2-X1_CV_badun_show.mp3",
         "CV_Translation_Test/cn2-X1_CV_baiqi_show.mp3",
         "CV_Translation_Test/cn2-X1_CV_beimihu_skill01.mp3"]
for f in files:
    audio = load16k(f)
    segs, info = m.transcribe(audio, language="zh", beam_size=5, vad_filter=False)
    txt = "".join(s.text for s in segs).strip()
    print(f"{os.path.basename(f)}\t{round(len(audio)/16000,2)}s\t{txt}", flush=True)
