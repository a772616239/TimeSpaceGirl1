#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把通用排行榜底部「我的排名」行（RankList/Record）的国家小旗，摆成和列表 item 一致。

参考 ItemPre（每条榜单行）的既有摆法：
    头像 Head   anchor(0,0.5) pos(290, 16) size 110
    国旗        anchor(0,0.5) pos(400, 41) size 78x54
  ⇒ 国旗相对头像中心的偏移 = (+110, +25)，即「头像右侧、比头像中心略高」。

Record 的头像 anchor(0.5,0.5) pos(-206.8, 6)，所以国旗应为：
    pos = (-206.8 + 110, 6 + 25) = (-96.8, 31)，size 保持 78x54。

Record 的 nameText 是 middle-left + BestFit（文字从 rect 左边缘 417 起排），
78 宽的旗子摆进去会和名字前三个字重叠 ⇒ 名字整体右移 78.5（rect 左边缘 417 -> 495.5），
让出「头像 | 国旗 | 名字」的次序，和 item 行的观感一致。

幂等：已经是目标值就跳过。
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PREFAB = os.path.join(ROOT, "Assets/ManagedResources/Prefabs/UI/Ranking/RankingSingleListPanel.prefab")

FLAG_ANCHOR = "(0.5, 0.5)"
FLAG_POS = ("-96.8", "31")
FLAG_SIZE = ("78", "54")
NAME_X = "707"
NAME_MIN_X = 700.0


def parse(txt):
    docs = re.split(r"^--- !u!(\d+) &(-?\d+)", txt, flags=re.M)
    objs = {}
    i = 1
    while i < len(docs):
        objs[docs[i + 1]] = (int(docs[i]), docs[i + 2] if i + 2 < len(docs) else "")
        i += 3
    return objs


def name_of(objs, go):
    m = re.search(r"m_Name: (.*)", objs[go][1])
    return m.group(1).strip() if m else "?"


def go_of_rt(objs, rt):
    return re.search(r"m_GameObject: \{fileID: (-?\d+)\}", objs[rt][1]).group(1)


def children_rt(objs, rt):
    m = re.search(r"m_Children:\n((?:  - \{fileID: -?\d+\}\n)+)", objs[rt][1])
    return re.findall(r"\{fileID: (-?\d+)\}", m.group(1)) if m else []


def find_path(objs, path):
    roots = [rt for rt, (cls, b) in objs.items() if cls == 224 and "m_Father: {fileID: 0}" in b]
    if not roots:
        return None
    cur = roots[0]
    for seg in path:
        nxt = None
        for c in children_rt(objs, cur):
            if name_of(objs, go_of_rt(objs, c)) == seg:
                nxt = c
                break
        if nxt is None:
            return None
        cur = nxt
    return cur


def set_fields(txt, rid, anchor, pos, size):
    """就地改写某个 RectTransform 的 anchor/pos/size，返回 (新文本, 是否有改动)"""
    pat = re.compile(r"(--- !u!224 &%s\n)(.*?)(?=\n--- )" % re.escape(rid), re.S)
    m = pat.search(txt)
    if m is None:
        raise SystemExit("RectTransform %s not found" % rid)
    body = m.group(2)
    orig = body
    if anchor:
        body = re.sub(r"m_AnchorMin: \{[^}]*\}", "m_AnchorMin: {x: %s, y: %s}" % anchor, body)
        body = re.sub(r"m_AnchorMax: \{[^}]*\}", "m_AnchorMax: {x: %s, y: %s}" % anchor, body)
    if pos:
        body = re.sub(r"m_AnchoredPosition: \{[^}]*\}", "m_AnchoredPosition: {x: %s, y: %s}" % pos, body)
    if size:
        body = re.sub(r"m_SizeDelta: \{[^}]*\}", "m_SizeDelta: {x: %s, y: %s}" % size, body)
    return txt[:m.start(2)] + body + txt[m.end(2):], body != orig


def main():
    txt = open(PREFAB, encoding="utf-8").read()
    objs = parse(txt)
    changed = []

    flag_rt = find_path(objs, ["RankList", "Record", "countryFlag"])
    if flag_rt is None:
        raise SystemExit("RankList/Record/countryFlag not found")
    txt, ch = set_fields(txt, flag_rt, ("0.5", "0.5"), FLAG_POS, FLAG_SIZE)
    if ch:
        changed.append("Record/countryFlag pos=(%s,%s) size=(%s,%s)" % (FLAG_POS + FLAG_SIZE))

    name_rt = find_path(objs, ["RankList", "Record", "nameText"])
    if name_rt is None:
        raise SystemExit("RankList/Record/nameText not found")
    cur_x = float(re.search(r"m_AnchoredPosition: \{x: (-?[\d.]+), y: -?[\d.]+\}",
                            objs[name_rt][1]).group(1))
    if cur_x < NAME_MIN_X:
        txt, ch = set_fields(txt, name_rt, None, (NAME_X, "0"), None)
        changed.append("Record/nameText x %.1f -> %s" % (cur_x, NAME_X))

    if changed:
        open(PREFAB, "w", encoding="utf-8").write(txt)
        print("patched:", "; ".join(changed))
    else:
        print("already up to date: Record flag pos=%s size=%s, nameText x=%s" % (FLAG_POS, FLAG_SIZE, NAME_X))


if __name__ == "__main__":
    main()
