#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the 30s promo soundtrack (BGM + VO + SFX) and mux with the rendered video."""
import os, subprocess, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(ROOT)
UI = os.path.join(PROJ, "Assets/ManagedResources/Audio/UI")
BGM = os.path.join(PROJ, "Assets/ManagedResources/Audio/BGM/cn2-x1_battle_BGM_NightCity.mp3")
CV = os.path.join(PROJ, "CV_En_Full/en")

# (file, at_seconds, gain, extra_trim)
SFX = [
    (os.path.join(UI, "n1_ui_sound_skill_boom.mp3"),      0.02, 0.85, None),
    (os.path.join(UI, "n1_ui_sound_normal_click.mp3"),    0.45, 0.35, None),
    (os.path.join(UI, "n1_ui_sound_skill_power.mp3"),     3.30, 0.55, None),
    (os.path.join(UI, "n1_ui_sound_normal_click.mp3"),    4.42, 0.30, None),
    (os.path.join(UI, "n1_ui_sound_skill_boom.mp3"),      5.58, 0.75, None),
    (os.path.join(UI, "n1_ui_sound_normal_click.mp3"),    6.20, 0.45, None),
    (os.path.join(UI, "n1_ui_sound_normal_click.mp3"),    6.60, 0.45, None),
    (os.path.join(UI, "n1_ui_sound_normal_click.mp3"),    7.00, 0.45, None),
    (os.path.join(UI, "n1_ui_sound_normal_click.mp3"),    7.40, 0.45, None),
    (os.path.join(UI, "n1_ui_sound_normal_click.mp3"),    7.80, 0.45, None),
    (os.path.join(UI, "n1_ui_sound_normal_click.mp3"),    8.20, 0.45, None),
    (os.path.join(UI, "n1_ui_sound_flashcard_once.mp3"),  8.62, 0.55, None),
    (os.path.join(UI, "n1_ui_sound_flashcard_once.mp3"), 10.22, 0.55, None),
    (os.path.join(UI, "n1_ui_sound_flashcard_once.mp3"), 11.82, 0.55, None),
    (os.path.join(UI, "n1_ui_sound_battle_start.wav"),   13.35, 0.65, "1.9"),
    (os.path.join(UI, "n1_ui_sound_battle_hit.mp3"),     14.02, 0.80, "0.9"),
    (os.path.join(UI, "n1_ui_sound_battle_hit.mp3"),     15.02, 0.80, "0.9"),
    (os.path.join(UI, "n1_ui_sound_battle_hit.mp3"),     16.02, 0.85, "0.9"),
    (os.path.join(UI, "n1_ui_sound_battle_dead_.mp3"),   16.10, 0.55, "1.2"),
    (os.path.join(UI, "n1_ui_sound_box_open.mp3"),       18.60, 0.55, "1.6"),
    (os.path.join(UI, "n1_ui_sound_flashcard_once.mp3"), 19.90, 0.60, "1.4"),
    (os.path.join(UI, "n1_ui_sound_skill_power.mp3"),    22.15, 0.55, None),
    (os.path.join(UI, "n1_ui_sound_flashcard_ten.mp3"),  23.75, 0.70, "2.2"),
    (os.path.join(UI, "n1_ui_sound_skill_boom.mp3"),     25.78, 0.90, None),
    (os.path.join(UI, "n1_ui_sound_normal_click.mp3"),   26.45, 0.45, None),
]

# (file, at_seconds, gain)  — 只用 CV_En_Full/en 里实际存在的配音
VO = [
    (os.path.join(CV, "cn2-X1_CV_guanyu_show.mp3"),      0.95, 1.40),  # If you bore me, you'll feed my blade.
    (os.path.join(CV, "cn2-X1_CV_guanyu_skill01.mp3"),   9.30, 1.40),  # Satisfying! Again!
    (os.path.join(CV, "cn2-X1_CV_hasang_skill01.mp3"),  10.95, 1.35),  # You can't escape.
    (os.path.join(CV, "cn2-X1_CV_bulutusi_skill02.mp3"), 12.25, 1.40),  # Pierce the void!
    (os.path.join(CV, "cn2-X1_CV_hasang_show.mp3"),     14.60, 1.40),  # If I find no offering, I'll sacrifice you.
    (os.path.join(CV, "cn2-X1_CV_hasang_skill02.mp3"),  23.35, 1.35),  # The offering is ready. Begin the rite.
]

def ms(x): return int(round(x * 1000))

def main():
    inputs, filters, mix = [], [], []
    idx = 0

    # BGM
    inputs += ["-i", BGM]
    filters.append(
        f"[{idx}:a]atrim=47.5:77.6,asetpts=PTS-STARTPTS,"
        f"afade=t=in:st=0:d=0.45,afade=t=out:st=28.3:d=1.7,volume=0.50[bgm]")
    idx += 1

    sfx_labels = []
    for (f, at, g, tr) in SFX:
        inputs += ["-i", f]
        chain = f"[{idx}:a]"
        if tr:
            chain += f"atrim=0:{tr},"
        chain += f"asetpts=PTS-STARTPTS,volume={g},adelay={ms(at)}|{ms(at)}[s{idx}]"
        filters.append(chain)
        sfx_labels.append(f"[s{idx}]")
        idx += 1

    vo_labels = []
    for (f, at, g) in VO:
        inputs += ["-i", f]
        filters.append(f"[{idx}:a]asetpts=PTS-STARTPTS,volume={g},adelay={ms(at)}|{ms(at)}[v{idx}]")
        vo_labels.append(f"[v{idx}]")
        idx += 1

    # sfx bus
    filters.append("".join(sfx_labels) + f"amix=inputs={len(sfx_labels)}:normalize=0,volume=1.0[sfx]")
    # vo bus (split: one for ducking key, one for the mix)
    filters.append("".join(vo_labels) + f"amix=inputs={len(vo_labels)}:normalize=0,apad=whole_dur=30,asplit=2[vo][vokey]")
    # duck bgm under VO
    filters.append("[bgm][vokey]sidechaincompress=threshold=0.045:ratio=3.2:attack=25:release=420:makeup=1[bgmd]")
    filters.append("[bgmd][sfx][vo]amix=inputs=3:normalize=0,apad=whole_dur=30,acompressor=threshold=0.06:ratio=2.6:attack=12:release=220:makeup=1.35,"
                   "loudnorm=I=-14:TP=-1.0:LRA=9,alimiter=limit=0.97,"
                   "atrim=0:30,afade=t=out:st=29.2:d=0.8[aout]")

    out = os.path.join(ROOT, "audio_mix.m4a")
    cmd = ["ffmpeg", "-y"] + inputs + ["-filter_complex", ";".join(filters),
           "-map", "[aout]", "-c:a", "aac", "-b:a", "192k", "-ar", "48000", out]
    print(" ".join(cmd)[:400], "...")
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-3000:]); sys.exit(1)
    print("audio ->", out)

    vid = os.path.join(ROOT, "video_noaudio.mp4")
    final = os.path.join(ROOT, "TimeSpaceGirl_promo_30s_9x16.mp4")
    r = subprocess.run(["ffmpeg", "-y", "-i", vid, "-i", out, "-c:v", "copy",
                        "-c:a", "aac", "-b:a", "192k", "-shortest",
                        "-movflags", "+faststart", final], capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-3000:]); sys.exit(1)
    print("final ->", final)

if __name__ == "__main__":
    main()
