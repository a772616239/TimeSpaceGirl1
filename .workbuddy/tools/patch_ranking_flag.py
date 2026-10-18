#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
给**通用排行榜**（Ranking/RankingSingleListPanel.prefab）的每一行加国家小旗：

  RankList/ScrollParentView/ItemPre/countryFlag   每条榜单行
  RankList/Record/countryFlag                     底部「我的排名」行
  firstHead / secondHead / thirdHead/countryFlag  前三名大立绘区

旗帜位置在头像右侧、玩家名左侧（ItemPre: Head 在 x=250/Size110，Value0 名字左边缘约 x=320）。

纯追加、幂等。
"""
import hashlib
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PREFAB = os.path.join(ROOT, "Assets/ManagedResources/Prefabs/UI/Ranking/RankingSingleListPanel.prefab")
NODE_NAME = "countryFlag"

GUID_UGUI = "f70555f144d8491a825f0804e09c671c"
FILEID_IMAGE = -765806418

# (父节点路径, 旗子 pos, 尺寸)  —— 坐标均为父节点局部坐标
TARGETS = [
    (["RankList", "ScrollParentView", "ItemPre"], (338, 16), (96, 64)),
    (["RankList", "Record"], (150, 0), (96, 64)),
    (["firstHead"], (0, -110), (120, 80)),
    (["secondHead"], (0, -110), (120, 80)),
    (["thirdHead"], (0, -110), (120, 80)),
]


def new_id(seed):
    h = hashlib.md5(("TimeSpaceGirl1/RankingFlag/" + seed).encode()).hexdigest()
    return str(int(h[:15], 16) + 500000000000000000)


def parse(txt):
    docs = re.split(r"^--- !u!(\d+) &(\d+)", txt, flags=re.M)
    objs = {}
    i = 1
    while i < len(docs):
        objs[docs[i + 1]] = [int(docs[i]), docs[i + 2] if i + 2 < len(docs) else ""]
        i += 3
    return objs


def name_of(objs, go):
    m = re.search(r"m_Name: (.*)", objs[go][1])
    return m.group(1).strip() if m else "?"


def children_rt(objs, rt):
    m = re.search(r"m_Children:\n((?:  - \{fileID: \d+\}\n)+)", objs[rt][1])
    if not m:
        return []
    return re.findall(r"\{fileID: (\d+)\}", m.group(1))


def go_of_rt(objs, rt):
    return re.search(r"m_GameObject: \{fileID: (\d+)\}", objs[rt][1]).group(1)


def find_path(objs, path):
    roots = [rt for rt, (cls, b) in objs.items() if cls == 224 and "m_Father: {fileID: 0}" in b]
    if not roots:
        return None
    cur = roots[0]
    for seg in path:
        found = None
        for c in children_rt(objs, cur):
            if name_of(objs, go_of_rt(objs, c)) == seg:
                found = c
                break
        if not found:
            return None
        cur = found
    return cur


def block_go(gid, comps):
    lines = ["--- !u!1 &%s" % gid, "GameObject:", "  m_ObjectHideFlags: 0",
             "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
             "  m_PrefabAsset: {fileID: 0}", "  serializedVersion: 6", "  m_Component:"]
    for _c, cid in comps:
        lines.append("  - component: {fileID: %s}" % cid)
    lines += ["  m_Layer: 5", "  m_Name: %s" % NODE_NAME, "  m_TagString: Untagged",
              "  m_Icon: {fileID: 0}", "  m_NavMeshLayer: 0", "  m_StaticEditorFlags: 0",
              "  m_IsActive: 1"]
    return "\n".join(lines) + "\n"


def block_rt(rid, gid, parent_rt, pos, size):
    return "\n".join([
        "--- !u!224 &%s" % rid, "RectTransform:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
        "  m_LocalRotation: {x: 0, y: 0, z: 0, w: 1}",
        "  m_LocalPosition: {x: 0, y: 0, z: 0}",
        "  m_LocalScale: {x: 1, y: 1, z: 1}",
        "  m_ConstrainProportionsScale: 0", "  m_Children: []",
        "  m_Father: {fileID: %s}" % parent_rt,
        "  m_LocalEulerAnglesHint: {x: 0, y: 0, z: 0}",
        "  m_AnchorMin: {x: 0.5, y: 0.5}", "  m_AnchorMax: {x: 0.5, y: 0.5}",
        "  m_AnchoredPosition: {x: %s, y: %s}" % pos,
        "  m_SizeDelta: {x: %s, y: %s}" % size, "  m_Pivot: {x: 0.5, y: 0.5}"]) + "\n"


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
    txt = open(PREFAB, encoding="utf-8").read()
    objs = parse(txt)
    chunks = []
    attached = []

    for idx, (path, pos, size) in enumerate(TARGETS):
        parent_rt = find_path(objs, path)
        if not parent_rt:
            print("  ⚠️ 找不到父节点：%s，跳过" % "/".join(path))
            continue
        seed = "|".join(path)
        gid = new_id("go|" + seed)
        rtid = new_id("rt|" + seed)
        crid = new_id("cr|" + seed)
        imgid = new_id("img|" + seed)
        if ("--- !u!224 &%s" % rtid) in txt:
            print("  = 已存在：%s" % "/".join(path))
            continue
        chunks.append(block_go(gid, [(224, rtid), (222, crid), (114, imgid)]))
        chunks.append(block_rt(rtid, gid, parent_rt, pos, size))
        chunks.append(block_cr(crid, gid))
        chunks.append(block_img(imgid, gid))
        attached.append((parent_rt, rtid, "/".join(path)))

    if not chunks:
        print("没有需要新增的节点")
        return

    new_txt = txt.rstrip("\n") + "\n" + "".join(chunks)

    # 逐个挂到父节点的 m_Children 末尾
    for parent_rt, rtid, label in attached:
        m = re.search(r"--- !u!224 &%s\nRectTransform:(.*?)m_Father" % parent_rt, new_txt, re.S)
        assert m, parent_rt
        seg = m.group(0)
        if "m_Children: []" in seg:
            seg_new = seg.replace("m_Children: []", "m_Children:\n  - {fileID: %s}" % rtid)
        else:
            seg_new = seg.replace("m_Father", "  - {fileID: %s}\n  m_Father" % rtid, 1)
        new_txt = new_txt.replace(seg, seg_new, 1)
        print("  + %-46s <- countryFlag" % label)

    open(PREFAB, "w", encoding="utf-8", newline="\n").write(new_txt)
    print("完成：新增 %d 个 countryFlag 节点" % len(attached))


if __name__ == "__main__":
    main()
