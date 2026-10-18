#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""打印 Unity prefab 的节点层级（带 RectTransform 关键坐标），用于改布局前确认结构。

用法：python3 .workbuddy/tools/prefab_tree.py <prefab> [--props]
"""
import re
import sys


def parse(path):
    txt = open(path, encoding="utf-8").read()
    docs = re.split(r"^--- !u!(\d+) &(-?\d+)", txt, flags=re.M)
    objs = {}
    i = 1
    while i < len(docs):
        objs[docs[i + 1]] = (int(docs[i]), docs[i + 2] if i + 2 < len(docs) else "")
        i += 3
    return objs


def main():
    path = sys.argv[1]
    show_props = "--props" in sys.argv
    objs = parse(path)

    def cls(oid):
        return objs[oid][0]

    def go_name(go):
        m = re.search(r"m_Name: (.*)", objs[go][1])
        return m.group(1).strip() if m else "?"

    def go_of_rt(rt):
        m = re.search(r"m_GameObject: \{fileID: (\d+)\}", objs[rt][1])
        return m.group(1) if m else None

    def kids(rt):
        m = re.search(r"m_Children:\n((?:  - \{fileID: -?\d+\}\n)+)", objs[rt][1])
        return re.findall(r"\{fileID: (-?\d+)\}", m.group(1)) if m else []

    def props(rt):
        b = objs[rt][1]
        def vec(k):
            m = re.search(r"%s: \{x: (-?[\d.]+), y: (-?[\d.]+)\}" % k, b)
            return ms(m) if m else None
        def ms(m):
            def f(x):
                x = float(x)
                return int(x) if abs(x - round(x)) < 1e-6 else round(x, 1)
            return (f(m.group(1)), f(m.group(2)))
        amin, amax = vec("m_AnchorMin"), vec("m_AnchorMax")
        pos, size, piv = vec("m_AnchoredPosition"), vec("m_SizeDelta"), vec("m_Pivot")
        return "a=%s..%s pos=%s size=%s piv=%s" % (amin, amax, pos, size, piv)

    roots = [rt for rt, (c, b) in objs.items()
             if c == 224 and "m_Father: {fileID: 0}" in b]
    out = []

    def walk(rt, depth):
        go = go_of_rt(rt)
        line = "  " * depth + (go_name(go) if go else "?")
        if show_props:
            line += "   " + props(rt)
        out.append(line)
        for c in kids(rt):
            walk(c, depth + 1)

    print(path.split("/")[-1])
    for r in roots:
        walk(r, 0)
    print("\n".join(out))


if __name__ == "__main__":
    main()
