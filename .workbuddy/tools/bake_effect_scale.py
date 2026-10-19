#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 effectRoot 下的特效按 0.6 烘焙到资源里。

- FightPointPassMainPanel: UI_Map_XunBaoEffect_hit 的 5 个 PS -> startSize *0.6，
  guangbo 的 Cone radius 也 *0.6（Shape 模式只拿 transform 缩发射形状，粒子尺寸只认 startSize）
- eff_UI_loot_line: PS(huo) 是 Local 模式 -> 缩它自己和 tiaodai2 的 transform
  （Local 按自身 transform 缩放，直径/速度/拖尾长度一起等比缩）
"""
import re
import sys

SCALE = 0.6


def fmt(v):
    s = ("%.6f" % v).rstrip("0").rstrip(".")
    return s if s not in ("", "-0") else "0"


def doc_spans(txt):
    """{fileID: (start, end)}，按 --- !u! 分块。"""
    out = {}
    marks = [(m.start(), m.group(1)) for m in
             re.finditer(r"^--- !u!\d+ &(\d+)\n", txt, re.M)]
    for i, (pos, fid) in enumerate(marks):
        end = marks[i + 1][0] if i + 1 < len(marks) else len(txt)
        out[fid] = (pos, end)
    return out


def scale_startsize(txt, spans, fid, factor):
    start, end = spans[fid]
    block = txt[start:end]
    m = re.search(r"\n    startSize:\n", block)
    if not m:
        raise SystemExit("no startSize in %s" % fid)
    sub_start = m.end()
    nxt = re.search(r"\n    [A-Za-z]", block[sub_start:])
    sub_end = sub_start + (nxt.start() if nxt else len(block) - sub_start)
    sub = block[sub_start:sub_end]

    def mul(mm):
        old = float(mm.group(2))
        new = round(old * factor, 6)
        return mm.group(1) + (mm.group(2) if abs(new - old) < 1e-9 else fmt(new))

    sub2, n1 = re.subn(r"(\n      scalar: )([-\d.eE]+)", mul, sub)
    sub2, n2 = re.subn(r"(\n      minScalar: )([-\d.eE]+)", mul, sub2)
    if n1 != 1:
        raise SystemExit("scalar miss in %s" % fid)
    return txt[:start] + block[:sub_start] + sub2 + block[sub_end:] + txt[end:]


def set_shape_radius(txt, spans, fid, new):
    start, end = spans[fid]
    block = txt[start:end]
    blk2, n = re.subn(r"(\n    radius:\n      value: )([-\d.eE]+)(?=\n)",
                      lambda mm: mm.group(1) + fmt(new), block, count=1)
    if n != 1:
        raise SystemExit("radius miss in %s" % fid)
    return txt[:start] + blk2 + txt[end:]


def scale_transform(txt, go_fid, factor):
    spans = doc_spans(txt)
    for fid, (start, end) in spans.items():
        block = txt[start:end]
        if not re.match(r"--- !u!(4|224) &%s\n" % fid, block):
            continue
        if not re.search(r"\n  m_GameObject: \{fileID: %s\}\n" % go_fid, block):
            continue
        new_block, n = re.subn(
            r"(\n  m_LocalScale: \{x: )([-\d.eE]+)(, y: )([-\d.eE]+)(, z: )([-\d.eE]+)(\})",
            lambda mm: mm.group(1) + fmt(factor) + mm.group(3) + fmt(factor)
                       + mm.group(5) + fmt(factor) + mm.group(7),
            block, count=1)
        if n != 1:
            raise SystemExit("localScale miss on %s" % fid)
        return txt[:start] + new_block + txt[end:]
    raise SystemExit("transform of GO %s not found" % go_fid)


def go_fid_by_name(txt, name):
    for m in re.finditer(r"^--- !u!1 &(\d+)\n", txt, re.M):
        start = m.start()
        end = txt.find("\n--- !u!", m.end())
        block = txt[start:end if end > 0 else len(txt)]
        if re.search(r"\n  m_Name: %s\n" % re.escape(name), block):
            return m.group(1)
    raise SystemExit("GO not found: %s" % name)


def main():
    panel = "Assets/ManagedResources/Prefabs/UI/Fight/FightPointPassMainPanel.prefab"
    loot = "Assets/ManagedResources/Prefabs/X1Effect/UI/eff_UI_loot_line.prefab"

    txt = open(panel, encoding="utf-8").read()
    spans = doc_spans(txt)
    for fid in (
        "6262595084271296476",   # glow
        "8677573233972452975",   # bao
        "1549425064746891353",   # shanguang
        "8043685258292580056",   # glow (1)
        "1557177655414519940",   # guangbo
    ):
        txt = scale_startsize(txt, spans, fid, SCALE)
        spans = doc_spans(txt)
    txt = set_shape_radius(txt, spans, "1557177655414519940", 0.6)
    open(panel, "w", encoding="utf-8").write(txt)
    print("panel ok")

    txt = open(loot, encoding="utf-8").read()
    for name in ("huo", "tiaodai2"):
        txt = scale_transform(txt, go_fid_by_name(txt, name), SCALE)
    open(loot, "w", encoding="utf-8").write(txt)
    print("loot ok")


if __name__ == "__main__":
    sys.exit(main())
