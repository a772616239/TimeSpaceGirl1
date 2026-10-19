#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把挂机宝箱的三档箱体（boxRoot/UI_effect_GuaJi_Box_01..03）整体缩到 SCALE。

结构（探针实测）：
  boxRoot                              <- 1080x1280 容器，不动
    UI_effect_GuaJi_Box_01/02/03       <- 三档箱体容器（同一位置，按状态只亮一个）  <- 改这里
      UI_effect_Box_01  100x100
        bg_ray      560x500  Image    <- 背后光晕
        xiangti _01 196x233 / 249x244 / 344x253  Image  <- 箱体本体
        yinying     432x133  Image    <- 影子
        Effect (1)/(2)                <- 额外粒子
    UI_effect_GuaJi_Box_BaoDian        <- 开箱爆点粒子，由 bake_baodian_scale.py 单独烘焙

为什么改容器而不是改每个 Image：容器 100x100 且子节点都在 (0,0) 附近，缩容器 = 箱体/光/影
一起等比缩，pivot 不动所以箱子原地变小。BaoDian 容器本身仍保持 1（它的 world position 被
FightPointMapOnHook.SetEffect 当战利品线 DOMove 的终点）。

可重复跑：已经是目标值就跳过，不等于 FROM（当前倍率）也不是目标值就报错（防止误缩第二遍）。
"""
import re
import sys

SCALE = 0.49          # 目标倍率
FROM = 0.7            # 当前资源里的倍率（上次烘焙的结果）
PANEL = "Assets/ManagedResources/Prefabs/UI/Fight/FightPointPassMainPanel.prefab"
ROOT = "boxRoot"
TARGETS = ["UI_effect_GuaJi_Box_01", "UI_effect_GuaJi_Box_02", "UI_effect_GuaJi_Box_03"]


def fmt(v):
    s = ("%.7f" % v).rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def doc_spans(txt):
    out = {}
    marks = [(m.start(), m.group(1), m.group(2)) for m in
             re.finditer(r"^--- !u!(\d+) &(\d+)\n", txt, re.M)]
    for i, (pos, cls, fid) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(txt)
        out[fid] = (cls, pos, end)
    return out


def go_names(txt, spans):
    names = {}
    for fid, (cls, s, e) in spans.items():
        if cls != "1":
            continue
        m = re.search(r"^  m_Name: (.*)$", txt[s:e], re.M)
        names[fid] = m.group(1) if m else ""
    return names


def build_tree(txt, spans, names):
    rt_of_go, kids, go_of_rt = {}, {}, {}
    for fid, (cls, s, e) in spans.items():
        if cls not in ("4", "224"):
            continue
        block = txt[s:e]
        g = re.search(r"\n  m_GameObject: \{fileID: (\d+)\}", block)
        if not g:
            continue
        go_of_rt[fid] = g.group(1)
        rt_of_go[g.group(1)] = fid
        seg = block.split("m_Children:")[1].split("m_Father:")[0] if "m_Children:" in block else ""
        kids[fid] = re.findall(r"- \{fileID: (\d+)\}", seg)
    return rt_of_go, kids, go_of_rt


def set_local_scale(txt, spans, rt_fid, target, label):
    cls, s, e = spans[rt_fid]
    block = txt[s:e]
    m = re.search(r"(\n  m_LocalScale: \{x: )([-\d.eE]+)(, y: )([-\d.eE]+)(, z: )([-\d.eE]+)(\})", block)
    if not m:
        raise SystemExit("localScale 缺失 %s" % rt_fid)
    old = float(m.group(2))
    if abs(old - target) < 1e-6:
        print("skip   %-24s 已经是 %s" % (label, fmt(old)))
        return txt
    if abs(old - FROM) > 1e-5:
        raise SystemExit("%s 的 scale 是 %s，不是期望的当前值 %s，人工确认后再跑"
                         % (label, fmt(old), fmt(FROM)))
    new = fmt(target)
    block = (block[:m.start()] + m.group(1) + new + m.group(3) + new
             + m.group(5) + new + m.group(7) + block[m.end():])
    print("scale  %-24s %s -> %s" % (label, fmt(old), new))
    return txt[:s] + block + txt[e:]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else PANEL
    txt = open(path, encoding="utf-8").read()

    for name in TARGETS:
        spans = doc_spans(txt)
        names = go_names(txt, spans)
        rt_of_go, _, _ = build_tree(txt, spans, names)
        hit = [k for k, v in names.items() if v == name]
        if len(hit) != 1:
            raise SystemExit("节点 %s 命中 %d 个（应为 1）" % (name, len(hit)))
        txt = set_local_scale(txt, spans, rt_of_go[hit[0]], SCALE, name)

    open(path, "w", encoding="utf-8").write(txt)
    print("done: %d 档箱体 -> %s 倍" % (len(TARGETS), SCALE))


if __name__ == "__main__":
    sys.exit(main())
