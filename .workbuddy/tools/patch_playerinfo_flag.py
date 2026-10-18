#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
给聊天里点开的玩家信息面板（Popup/PlayerInfoPopup.prefab）加一面「国家小旗」。

位置：tipImage/panel/info/flag —— 挂在昵称 name 的左侧、同级。
幂等：已存在同名节点则跳过。
"""
import hashlib
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PREFAB = os.path.join(ROOT, "Assets/ManagedResources/Prefabs/UI/Popup/PlayerInfoPopup.prefab")
NODE_NAME = "countryFlag"

GUID_UGUI = "f70555f144d8491a825f0804e09c671c"
ATLAS = os.path.join(ROOT, "Assets/ManagedResources/Atlas/CountryRankPanelAtlas")
FILEID_IMAGE = -765806418


def new_id(seed):
    h = hashlib.md5(("TimeSpaceGirl1/PlayerInfoFlag/" + seed).encode()).hexdigest()
    return str(int(h[:15], 16) + 400000000000000000)


def main():
    txt = open(PREFAB, encoding="utf-8").read()
    if "m_Name: %s" % NODE_NAME in txt:
        print("已存在 %s，跳过" % NODE_NAME)
        return

    docs = re.split(r"^--- !u!(\d+) &(\d+)", txt, flags=re.M)
    objs = {}
    i = 1
    while i < len(docs):
        objs[docs[i + 1]] = [int(docs[i]), docs[i + 2] if i + 2 < len(docs) else ""]
        i += 3

    def find_rt(name):
        for fid, (cls, body) in objs.items():
            if cls == 1 and re.search(r"m_Name: " + re.escape(name) + r"$", body.strip(), re.M):
                for c in re.findall(r"component: \{fileID: (\d+)\}", body):
                    if objs[c][0] == 224:
                        return c
        return None

    info_rt = find_rt("info")
    name_rt = find_rt("name")
    assert info_rt and name_rt

    # 昵称锚点在 (0,1)/pos(495,-60)，宽 510 → 旗帜放它左边
    gid = new_id("go")
    rtid = new_id("rt")
    crid = new_id("cr")
    imgid = new_id("img")

    flag_rt = new_id("flag-rt")

    go_block = "\n".join([
        "--- !u!1 &%s" % gid, "GameObject:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  serializedVersion: 6", "  m_Component:",
        "  - component: {fileID: %s}" % flag_rt,
        "  - component: {fileID: %s}" % crid,
        "  - component: {fileID: %s}" % imgid,
        "  m_Layer: 5", "  m_Name: %s" % NODE_NAME, "  m_TagString: Untagged",
        "  m_Icon: {fileID: 0}", "  m_NavMeshLayer: 0", "  m_StaticEditorFlags: 0",
        "  m_IsActive: 1"]) + "\n"

    rt_block = "\n".join([
        "--- !u!224 &%s" % flag_rt, "RectTransform:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
        "  m_LocalRotation: {x: 0, y: 0, z: 0, w: 1}",
        "  m_LocalPosition: {x: 0, y: 0, z: 0}",
        "  m_LocalScale: {x: 1, y: 1, z: 1}",
        "  m_ConstrainProportionsScale: 0", "  m_Children: []",
        "  m_Father: {fileID: %s}" % info_rt,
        "  m_LocalEulerAnglesHint: {x: 0, y: 0, z: 0}",
        "  m_AnchorMin: {x: 0, y: 1}", "  m_AnchorMax: {x: 0, y: 1}",
        "  m_AnchoredPosition: {x: 250, y: -60}",
        "  m_SizeDelta: {x: 120, y: 80}", "  m_Pivot: {x: 0.5, y: 0.5}"]) + "\n"

    cr_block = "\n".join([
        "--- !u!222 &%s" % crid, "CanvasRenderer:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
        "  m_CullTransparentMesh: 0"]) + "\n"

    img_block = "\n".join([
        "--- !u!114 &%s" % imgid, "MonoBehaviour:", "  m_ObjectHideFlags: 0",
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

    new_txt = txt.rstrip("\n") + "\n" + go_block + rt_block + cr_block + img_block

    # 挂到 info 的 m_Children
    m = re.search(r"--- !u!224 &%s\nRectTransform:(.*?)m_Father" % info_rt, new_txt, re.S)
    assert m
    seg = m.group(0)
    if "m_Children: []" in seg:
        seg_new = seg.replace("m_Children: []", "m_Children:\n  - {fileID: %s}" % flag_rt)
    else:
        seg_new = seg.replace("m_Father", "  - {fileID: %s}\n  m_Father" % flag_rt, 1)
    new_txt = new_txt.replace(seg, seg_new, 1)

    open(PREFAB, "w", encoding="utf-8", newline="\n").write(new_txt)
    print("已追加 %s 到 info（fileID %s）" % (NODE_NAME, flag_rt))


if __name__ == "__main__":
    main()
