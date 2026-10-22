#!/usr/bin/env python3
"""列出 Unity prefab 的节点树（含 RectTransform 尺寸/锚点），可只打印某子树。

用法:
  python3 scripts/dump_prefab_tree.py <prefab> [--root NAME] [--depth N] [--match NAME]
"""
import re
import sys

CLASS_NAMES = {1: "GameObject", 224: "RectTransform", 4: "Transform"}


def parse(path):
    raw = open(path, encoding="utf-8", errors="replace").read()
    blocks = {}
    for chunk in raw.split("--- !u!"):
        if not chunk.strip():
            continue
        head, _, body = chunk.partition("\n")
        parts = head.split()
        if len(parts) < 2:
            continue
        try:
            cid = int(parts[0])
        except ValueError:
            continue
        m = re.search(r"&(-?\d+)", head)
        fid = int(m.group(1)) if m else 0
        blocks[fid] = {"class": cid, "body": body}
    return blocks


def field(body, name):
    m = re.search(r"^  %s: ?(.*)$" % re.escape(name), body, re.M)
    if not m:
        return None
    return m.group(1).strip()


def obj_ref(body, name):
    m = re.search(r"^  %s: \{fileID: (-?\d+)\}" % re.escape(name), body, re.M)
    if not m:
        return None
    v = int(m.group(1))
    return v if v else None


def vec2(body, name):
    m = re.search(r"^  %s: \{x: ([-\d.e+]+), y: ([-\d.e+]+)\}" % re.escape(name), body, re.M)
    return (float(m.group(1)), float(m.group(2))) if m else None


def parse_children(body):
    m = re.search(r"^  m_Children:\n((?:  - \{fileID: -?\d+\}\n)*)", body, re.M)
    if not m:
        return []
    return [int(x) for x in re.findall(r"fileID: (-?\d+)", m.group(1))]


def main():
    args = sys.argv[1:]
    prefab = args[0]
    root = None
    depth = 99
    show_text = False
    for i, a in enumerate(args):
        if a == "--root":
            root = args[i + 1]
        elif a == "--depth":
            depth = int(args[i + 1])
        elif a == "--text":
            show_text = True

    blocks = parse(prefab)
    gos = {f: b for f, b in blocks.items() if b["class"] == 1}
    trs = {f: b for f, b in blocks.items() if b["class"] in (4, 224)}
    comps = {}
    for f, b in blocks.items():
        go = obj_ref(b["body"], "m_GameObject")
        if go and b["class"] not in (1, 4, 224):
            comps.setdefault(go, []).append((b["class"], b["body"]))

    go_of_tr = {f: obj_ref(b["body"], "m_GameObject") for f, b in trs.items()}
    children = {f: parse_children(b["body"]) for f, b in trs.items()}
    roots = [f for f, b in trs.items() if obj_ref(b["body"], "m_Father") is None]

    def name_of(tr):
        b = gos.get(go_of_tr.get(tr))
        return field(b["body"], "m_Name") if b else "?"

    def line(tr):
        b = trs[tr]
        info = []
        if b["class"] == 224:
            info.append("a%s-%s p%s sd%s pos%s" % (
                vec2(b["body"], "m_AnchorMin"), vec2(b["body"], "m_AnchorMax"),
                field(b["body"], "m_Pivot"), vec2(b["body"], "m_SizeDelta"),
                vec2(b["body"], "m_AnchoredPosition")))
        go = go_of_tr.get(tr)
        if go and field(gos[go]["body"], "m_IsActive") == "0":
            info.append("INACTIVE")
        if show_text:
            for cid, body in comps.get(go, []):
                t = field(body, "m_text")
                if t is not None:
                    info.append("TEXT=%r" % t[:100])
                    for k in ("m_FontSize", "m_LineSpacing", "m_Alignment", "m_OverflowMode",
                              "m_ResizeTextForBestFit", "m_VerticalOverflow"):
                        v = field(body, k)
                        if v:
                            info.append("%s=%s" % (k.replace("m_", ""), v))
                ft = field(body, "m_Font")
                if ft and cid == 114:
                    pass
        return "%s  %s" % (name_of(tr), " | ".join(info))

    def walk(tr, lvl):
        print("%s%s%s" % ("  " * lvl, line(tr), ""))
        if lvl >= depth:
            return
        for k in children.get(tr, []):
            walk(k, lvl + 1)

    def find(tr, target, path=""):
        p = path + "/" + name_of(tr)
        if name_of(tr) == target:
            return tr, p
        for k in children.get(tr, []):
            r = find(k, target, p)
            if r:
                return r
        return None

    start = roots[0] if roots else None
    if root:
        for r in roots:
            hit = find(r, root)
            if hit:
                start = hit[0]
                print("# path:", hit[1])
                break
        if start is None:
            print("root %r not found; roots=%s" % (root, [name_of(r) for r in roots]))
            return
    walk(start, 0)


main()
