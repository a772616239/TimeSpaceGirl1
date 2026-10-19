#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
给「竞技场 - 竞技排行」面板的榜单行补挂国家小旗节点（幂等，纯追加）。

挂点（ArenaMainPanel.prefab）：
  content/ArenaMainPanel_RankingSingleList/RankList/ScrollParentView/ItemPre/countryFlag
  content/ArenaMainPanel_RankingSingleList/RankList/Record/countryFlag

坐标来源（均为行内「从左边算」的局部坐标，父节点 anchor 取 (0, 0.5)）：
  ItemPre: name 文本盒 x 319..645（width 326，align=MiddleLeft），y=52；
           右侧 Value1 已 inactive，旗帜放 649..727，不压名字也不压分数。
  Record : nameText 文本盒 x 377..639，y=4；
           右侧 infoGo 的子节点（arenaScore）左边缘 ≈ 752 ⇒ 同样落在 649..727。

关键约束（本项目踩过）：
  1. 新节点必须同时写自身 m_Father，并把自己的 fileID 追加进父节点 m_Children，
     否则 Unity 打开后节点不挂在树上（等于没加），且不报错。
  2. Image 的 sprite 留空，运行时由 Util.LoadSprite 赋值。
  3. m_RaycastTarget 保持 0：点击仍穿透给行的 ClickBtn（打开玩家信息），不抢射线。
  4. 幂等：以「父节点下已存在同名子节点 / 该 fileID 已在文件里」双重判据跳过。

用法：python3 .workbuddy/tools/patch_arena_rank_flag.py [--check]
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PREFAB = os.path.join(ROOT, "Assets/ManagedResources/Prefabs/UI/Arena/ArenaMainPanel.prefab")
GUID_UGUI = "f70555f144d8491a825f0804e09c671c"
FILEID_IMAGE = -765806418
NODE_NAME = "countryFlag"

BASE = ["content", "ArenaMainPanel_RankingSingleList", "RankList"]

# (父路径, pos, size)
TARGETS = [
    # 榜单行（每条玩家）
    (BASE + ["ScrollParentView", "ItemPre"], (688, 52), (78, 54)),
    # 底部「我的排名」行
    (BASE + ["Record"], (688, 4), (78, 54)),
]


def new_id(seed):
    h = hashlib.md5(("TimeSpaceGirl1/ArenaRankFlag/" + seed).encode()).hexdigest()
    return str(int(h[:15], 16) + 600000000000000000)


def parse(txt):
    docs = re.split(r"^--- !u!(\d+) &(-?\d+)", txt, flags=re.M)
    objs = {}
    i = 1
    while i < len(docs):
        objs[docs[i + 1]] = (int(docs[i]), docs[i + 2] if i + 2 < len(docs) else "")
        i += 3
    return objs


def go_name(objs, go):
    m = re.search(r"m_Name: (.*)", objs[go][1])
    return m.group(1).strip() if m else "?"


def go_of_rt(objs, rt):
    m = re.search(r"m_GameObject: \{fileID: (-?\d+)\}", objs[rt][1])
    return m.group(1) if m else None


def kids(objs, rt):
    m = re.search(r"m_Children:\n((?:  - \{fileID: -?\d+\}\n)+)", objs[rt][1])
    return re.findall(r"\{fileID: (-?\d+)\}", m.group(1)) if m else []


def find(objs, path):
    roots = [rt for rt, (c, b) in objs.items() if c == 224 and "m_Father: {fileID: 0}" in b]
    if not roots:
        return None
    cur = roots[0]
    for seg in path:
        found = None
        for c in kids(objs, cur):
            g = go_of_rt(objs, c)
            if g and go_name(objs, g) == seg:
                found = c
                break
        if not found:
            return None
        cur = found
    return cur


def block_go(gid, name):
    return "\n".join([
        "--- !u!1 &%s" % gid, "GameObject:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  serializedVersion: 6", "  m_Component:",
        "  - component: {fileID: %RT%}",
        "  - component: {fileID: %CR%}",
        "  - component: {fileID: %IMG%}",
        "  m_Layer: 5", "  m_Name: %s" % name, "  m_TagString: Untagged",
        "  m_Icon: {fileID: 0}", "  m_NavMeshLayer: 0", "  m_StaticEditorFlags: 0",
        "  m_IsActive: 1"]) + "\n"


def block_rt(rid, gid, father, pos, size):
    return "\n".join([
        "--- !u!224 &%s" % rid, "RectTransform:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
        "  m_LocalRotation: {x: 0, y: 0, z: 0, w: 1}",
        "  m_LocalPosition: {x: 0, y: 0, z: 0}",
        "  m_LocalScale: {x: 1, y: 1, z: 1}",
        "  m_ConstrainProportionsScale: 0", "  m_Children: []",
        "  m_Father: {fileID: %s}" % father,
        "  m_LocalEulerAnglesHint: {x: 0, y: 0, z: 0}",
        "  m_AnchorMin: {x: 0, y: 0.5}", "  m_AnchorMax: {x: 0, y: 0.5}",
        "  m_AnchoredPosition: {x: %s, y: %s}" % pos,
        "  m_SizeDelta: {x: %s, y: %s}" % size,
        "  m_Pivot: {x: 0.5, y: 0.5}"]) + "\n"


def block_cr(cid, gid):
    return "\n".join([
        "--- !u!222 &%s" % cid, "CanvasRenderer:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
        "  m_CullTransparentMesh: 0"]) + "\n"


def block_img(cid, gid):
    return "\n".join([
        "--- !u!114 &%s" % cid, "MonoBehaviour:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
        "  m_Enabled: 1", "  m_EditorHideFlags: 0",
        "  m_Script: {fileID: %d, guid: %s, type: 3}" % (FILEID_IMAGE, GUID_UGUI),
        "  m_Name: ", "  m_EditorClassIdentifier: ", "  m_Material: {fileID: 0}",
        "  m_Color: {r: 1, g: 1, b: 1, a: 1}", "  m_RaycastTarget: 0",
        "  m_OnCullStateChanged:", "    m_PersistentCalls:", "      m_Calls: []",
        "    m_TypeName: UnityEngine.UI.MaskableGraphic+CullStateChangedEvent, "
        "UnityEngine.UI, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null",
        "  m_Sprite: {fileID: 0}", "  m_Type: 0", "  m_PreserveAspect: 1",
        "  m_FillCenter: 1", "  m_FillMethod: 4", "  m_FillAmount: 1",
        "  m_FillClockwise: 1", "  m_FillOrigin: 0", "  m_UseSpriteMesh: 0"]) + "\n"


def main():
    check_only = "--check" in sys.argv
    txt = open(PREFAB, encoding="utf-8").read()
    objs = parse(txt)
    chunks, attached, added = [], [], 0

    for (path, pos, size) in TARGETS:
        father = find(objs, path)
        label = "/".join(path)
        if not father:
            print("  [miss] 找不到 %s" % label)
            continue
        existing = [go_name(objs, go_of_rt(objs, c)) for c in kids(objs, father)]
        if NODE_NAME in existing:
            print("  [skip] 已存在 %s/%s" % (label, NODE_NAME))
            continue
        seed = "/".join(path)
        gid, rtid, crid, imgid = (new_id("go|" + seed), new_id("rt|" + seed),
                                  new_id("cr|" + seed), new_id("img|" + seed))
        go = (block_go(gid, NODE_NAME).replace("%RT%", rtid)
              .replace("%CR%", crid).replace("%IMG%", imgid))
        chunks += [go, block_rt(rtid, gid, father, pos, size),
                   block_cr(crid, gid), block_img(imgid, gid)]
        attached.append((father, rtid, label))
        added += 1

    if check_only:
        print("待新增 %d 处" % added)
        return 0
    if not chunks:
        print("无需变更")
        return 0

    lines = (txt.rstrip("\n") + "\n" + "".join(chunks)).split("\n")
    for father, rtid, label in attached:
        start = None
        for i, l in enumerate(lines):
            if l.strip() == "--- !u!224 &%s" % father:
                start = i
                break
        assert start is not None, father
        end = start + 1
        while end < len(lines) and not lines[end].startswith("--- "):
            end += 1
        ci = next(i for i in range(start, end) if lines[i].strip().startswith("m_Children:"))
        if lines[ci].strip() == "m_Children: []":
            lines[ci] = "  m_Children:\n  - {fileID: %s}" % rtid
        else:
            j = ci + 1
            while j < end and lines[j].startswith("  - {fileID:"):
                j += 1
            lines.insert(j, "  - {fileID: %s}" % rtid)
        print("  + %s/countryFlag" % label)

    open(PREFAB, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    print("完成：新增 %d 处" % added)
    return 0


if __name__ == "__main__":
    sys.exit(main())
