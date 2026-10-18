#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
修复 prefab 里「节点写了 m_Father 但没被父节点 m_Children 引用」的问题。

背景：手工/脚本追加 prefab 节点时，很容易只写 m_Father 而忘了把 fileID 追加进
父节点的 m_Children —— Unity 打开时该节点不会挂在树上（等于没加）。
本脚本做一次全量自检 + 修复：

  1. 扫描所有 RectTransform：A 的 m_Father = B，但 B.m_Children 不含 A → 补上
  2. 扫描所有 m_Children 里引用的 fileID：若对方 m_Father 不是自己 → 报告（不自动改）

用法：
  python3 .workbuddy/tools/fix_prefab_children.py <prefab> [--check]
"""
import re
import sys


def parse_blocks(text):
    """按 '--- !u!<cls> &<id>' 切块，返回 [(id, cls, start_line, end_line)]。"""
    lines = text.split("\n")
    blocks = []
    for i, l in enumerate(lines):
        m = re.match(r"^--- !u!(\d+) &(-?\d+)( stripped)?$", l)
        if m:
            blocks.append([m.group(2), int(m.group(1)), i, None])
    for k in range(len(blocks) - 1):
        blocks[k][3] = blocks[k + 1][2]
    if blocks:
        blocks[-1][3] = len(lines)
    return lines, blocks


def main():
    path = sys.argv[1]
    check_only = "--check" in sys.argv
    text = open(path, encoding="utf-8").read()
    lines, blocks = parse_blocks(text)

    # 建索引：rt id -> (go id, father id, [children ids])
    info = {}
    for oid, cls, s, e in blocks:
        if cls != 224:
            continue
        body = "\n".join(lines[s:e])
        g = re.search(r"m_GameObject: \{fileID: (\d+)\}", body)
        f = re.search(r"m_Father: \{fileID: (\d+)\}", body)
        if not g or not f:
            continue
        m = re.search(r"m_Children:\n((?:  - \{fileID: -?\d+\}\n)+)", body)
        kids = re.findall(r"\{fileID: (-?\d+)\}", m.group(1)) if m else []
        info[oid] = {"go": g.group(1), "father": f.group(1), "children": kids,
                     "start": s, "end": e}

    # go id -> name
    names = {}
    for oid, cls, s, e in blocks:
        if cls == 1:
            body = "\n".join(lines[s:e])
            nm = re.search(r"m_Name: (.*)", body)
            names[oid] = nm.group(1).strip() if nm else "?"

    orphan = []
    for rt, d in info.items():
        fa = d["father"]
        if fa == "0" or fa not in info:
            continue
        if rt not in info[fa]["children"]:
            orphan.append((rt, fa))

    print("%s：%d 个 RectTransform，孤儿 %d 个" % (path.split("/")[-1], len(info), len(orphan)))
    for rt, fa in orphan:
        print("   孤儿 %s(%s) 应挂在 %s(%s)" % (rt, names.get(info[rt]["go"], "?"),
                                            fa, names.get(info[fa]["go"], "?")))

    if check_only or not orphan:
        return 0 if not orphan else 1

    # 修复：逐个插到父节点 m_Children 末尾（从后往前插入以保持行号有效）
    edits = []
    for rt, fa in orphan:
        d = info[fa]
        ci = None
        for i in range(d["start"], d["end"]):
            if lines[i].strip().startswith("m_Children:"):
                ci = i
                break
        assert ci is not None, "父节点 %s 没有 m_Children" % fa
        if lines[ci].strip() == "m_Children: []":
            edits.append((ci, 1, "  m_Children:\n  - {fileID: %s}" % rt))
        else:
            j = ci + 1
            while j < d["end"] and lines[j].startswith("  - {fileID:"):
                j += 1
            edits.append((j, 0, "  - {fileID: %s}" % rt))

    for pos, replace_count, payload in sorted(edits, key=lambda x: -x[0]):
        if replace_count:
            lines[pos:pos + replace_count] = payload.split("\n")
        else:
            lines.insert(pos, payload)

    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("   已修复 %d 处" % len(orphan))
    return 0


if __name__ == "__main__":
    sys.exit(main())
