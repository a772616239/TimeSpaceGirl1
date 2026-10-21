#!/usr/bin/env python3
"""汇总报告：条数、时长偏差分布、音色分布、待人工确认项 -> CV_En_Full/report.md"""
import csv, os, json, statistics as st
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__))); os.chdir(ROOT)
lines={r["file"]:r for r in csv.DictReader(open("CV_En_Full/lines.csv",encoding="utf-8"))}
rep=list(csv.DictReader(open("CV_En_Full/tts_report.csv",encoding="utf-8")))
ok=[r for r in rep if r.get("status")=="ok"]
devs=[]
for r in ok:
    t=float(r["target_dur"]); f=float(r["final_dur"])
    if t>0: devs.append((f-t)/t*100)
devs_abs=[abs(d) for d in devs]
in3=sum(1 for d in devs_abs if d<=3); in6=sum(1 for d in devs_abs if d<=6)
voices={}
for r in lines.values(): voices[r["voice"]]=voices.get(r["voice"],0)+1
flag=[r for r in lines.values() if "⚠" in (r.get("note") or "")]
missing=[r for r in lines.values() if not r["en"].strip()]
out=[]
out.append("# CV 英文配音合成报告\n")
out.append(f"- 参与合成：**{len(ok)}** 条（总表 {len(lines)} 条）")
out.append(f"- 时长偏差：中位 {st.median(devs):+.1f}%，|偏差|≤3% 占 {in3/len(devs)*100:.0f}%，≤6% 占 {in6/len(devs)*100:.0f}%")
out.append(f"- 使用音色：{len(voices)} 个")
out.append(f"- 待听音确认（⚠）：{len(flag)} 条")
out.append(f"- 未产出：{len(missing)} 条（识别为空/待听音）\n")
out.append("## 音色分配\n\n| 音色 | 条数 |\n|---|---|")
for v,c in sorted(voices.items(),key=lambda x:-x[1]): out.append(f"| {v} | {c} |")
if flag:
    out.append("\n## 待听音确认\n\n| 文件 | 中文（推断） | 英文 |\n|---|---|---|")
    for r in flag: out.append(f"| {r['file']} | {r['zh'] or '—'} | {r['en'] or '—'} |")
if missing:
    out.append("\n## 未产出（识别为空，保留原声）\n")
    for r in missing: out.append(f"- {r['file']}")
open("CV_En_Full/report.md","w",encoding="utf-8").write("\n".join(out)+"\n")
print("\n".join(out[:8]))
