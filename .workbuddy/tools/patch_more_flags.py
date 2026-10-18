#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
给「国家旗帜」在通用排行榜主面板与竞技场主面板补挂点（幂等，纯追加）。

挂点：
  RankingListMainPanel.prefab
      bg/panel/ItemPre/hero/countryFlag      —— 名字后面
      bg/panel/ItemPre/BG1/countryFlagAlt    （不建；只做一处，避免重复）
  ArenaMainPanel.prefab
      content/ArenaMainPanel_ArenaView/bg/challengebox/enemy_{1,2,3}/countryFlag

关键约束（本项目踩过）：
  1. 新节点必须同时写自身 m_Father，并把自己的 fileID 追加进父节点 m_Children，
     否则 Unity 打开后节点不挂在树上（等于没加），且不报错。
  2. Image 组件的 sprite 留空，由 Lua 运行时 Util.LoadSprite 赋值。
  3. 必须 return <表> 的 Lua 约定与 prefab 无关，但脚本要保持幂等。

用法：python3 .workbuddy/tools/patch_more_flags.py [--check]
"""
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GUID_UGUI = "f70555f144d8491a825f0804e09c671c"
FILEID_IMAGE = -765806418
NODE_NAME = "countryFlag"

RANKING = os.path.join(ROOT, "Assets/ManagedResources/Prefabs/UI/Ranking/RankingListMainPanel.prefab")
ARENA = os.path.join(ROOT, "Assets/ManagedResources/Prefabs/UI/Arena/ArenaMainPanel.prefab")

# (prefab, 父路径, 名称, 锚点, pos, size)
# 名字后面：nameText 在 (1,0) 锚点、pivot(1,0)、宽 320、pos(-5,120)，文字左边缘 x=-325。
# 旗帜放名字文本之后（更靠右），即 nameText 右边缘 x=-5 的左侧 → 用同一锚点系，
# 左对齐到 x=-325+名字区，取 -5-320-8 起（在名字左边）会撞头像；
# 故改为「名字紧右侧」：nameText 收窄到 250（左边缘 -255），旗帜放 -5 处向右？
# 实际 hero 右边界是父宽右侧，x=-5 已在最右，右侧没空间。
# ⇒ 采用 nameText 收窄 + 旗帜紧随其后（旗帜在名字右侧、占用原 nameText 的尾段）。
TARGETS = [
    # 通用排行榜主面板：hero/nameText 右边缘 x=-5，右侧到 hero 边界只剩 5px，没空间。
    # 故把 nameText 收窄（320->234，见 NARROW），旗帜放进腾出的右侧空档：
    #   nameText 左对齐、pivot(1,0)、pos(-5,120)、宽 234 ⇒ 占 x -239..-5
    #   旗帜右边缘对齐 -5，宽 78 ⇒ 中心 x = -5-39 = -44，pivot(1,0.5) 取 -5 更直观：
    #   这里用 anchor(1,0)+pivot(1,0.5)，pos x=-5 即右边缘贴 -5，y 与名字同高 +8
    (RANKING, ["bg", "panel", "ItemPre", "hero"], (1, 0), (-5, 158), (78, 54), (1, 0.5)),
    # 竞技场：三个敌人的名字后（名字居中，旗帜放名字右侧）
    (ARENA, ["content", "ArenaMainPanel_ArenaView", "challengebox", "enemy_1"],
     (0.5, 0.5), (172, 20), (86, 58), (0, 0.5)),
    (ARENA, ["content", "ArenaMainPanel_ArenaView", "challengebox", "enemy_2"],
     (0.5, 0.5), (172, 20), (86, 58), (0, 0.5)),
    (ARENA, ["content", "ArenaMainPanel_ArenaView", "challengebox", "enemy_3"],
     (0.5, 0.5), (172, 20), (86, 58), (0, 0.5)),
]


def new_id(seed):
    h = hashlib.md5(("TimeSpaceGirl1/MoreFlags/" + seed).encode()).hexdigest()
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
    m = re.search(r"m_GameObject: \{fileID: (\d+)\}", objs[rt][1])
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
            if go_name(objs, go_of_rt(objs, c)) == seg:
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
        "  - component: {fileID: %s}" % ("%RT%"),
        "  - component: {fileID: %s}" % ("%CR%"),
        "  - component: {fileID: %s}" % ("%IMG%"),
        "  m_Layer: 5", "  m_Name: %s" % name, "  m_TagString: Untagged",
        "  m_Icon: {fileID: 0}", "  m_NavMeshLayer: 0", "  m_StaticEditorFlags: 0",
        "  m_IsActive: 1"]) + "\n"


def block_rt(rid, gid, father, amin, pos, size, pivot):
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
        "  m_AnchorMin: {x: %s, y: %s}" % amin, "  m_AnchorMax: {x: %s, y: %s}" % amin,
        "  m_AnchoredPosition: {x: %s, y: %s}" % pos,
        "  m_SizeDelta: {x: %s, y: %s}" % size,
        "  m_Pivot: {x: %s, y: %s}" % pivot]) + "\n"


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


def patch(prefab, targets, check_only):
    txt = open(prefab, encoding="utf-8").read()
    objs = parse(txt)
    rel = os.path.basename(prefab)
    added = 0
    chunks = []
    attached = []

    for (pf, path, amin, pos, size, pivot) in targets:
        if pf != prefab:
            continue
        father = find(objs, path)
        if not father:
            print("  ⚠️ %s：找不到 %s" % (rel, "/".join(path)))
            continue
        seed = rel + "|" + "/".join(path)
        gid, rtid, crid, imgid = (new_id("go|" + seed), new_id("rt|" + seed),
                                  new_id("cr|" + seed), new_id("img|" + seed))
        if ("--- !u!224 &%s" % rtid) in txt:
            print("  = 已存在：%s/%s" % (rel, "/".join(path)))
            continue
        go = block_go(gid, NODE_NAME).replace("%RT%", rtid).replace("%CR%", crid).replace("%IMG%", imgid)
        chunks.append(go)
        chunks.append(block_rt(rtid, gid, father, amin, pos, size, pivot))
        chunks.append(block_cr(crid, gid))
        chunks.append(block_img(imgid, gid))
        attached.append((father, rtid, "/".join(path)))
        added += 1

    if check_only:
        print("%s：待新增 %d 处" % (rel, added))
        return added

    if not chunks:
        print("%s：无需变更" % rel)
        return 0

    new_txt = txt.rstrip("\n") + "\n" + "".join(chunks)

    # 把每个新节点的 fileID 追加进其父节点的 m_Children
    lines = new_txt.split("\n")
    for father, rtid, label in attached:
        # 定位父 RectTransform 块
        start = None
        for i, l in enumerate(lines):
            if l.strip() == "--- !u!224 &%s" % father:
                start = i
                break
        assert start is not None, father
        end = start + 1
        while end < len(lines) and not lines[end].startswith("--- "):
            end += 1
        ci = None
        for i in range(start, end):
            if lines[i].strip().startswith("m_Children:"):
                ci = i
                break
        assert ci is not None, "父节点 %s 缺 m_Children" % father
        if lines[ci].strip() == "m_Children: []":
            lines[ci] = "  m_Children:\n  - {fileID: %s}" % rtid
        else:
            j = ci + 1
            while j < end and lines[j].startswith("  - {fileID:"):
                j += 1
            lines.insert(j, "  - {fileID: %s}" % rtid)
        print("  + %s/%s" % (rel, label))

    open(prefab, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
    return added


# nameText 收窄：(prefab, 路径, 新宽度) —— 给旗帜腾出右侧空间
NARROW = [
    (RANKING, ["bg", "panel", "ItemPre", "hero", "nameText"], 234),
]


def narrow_text(prefab, targets, check_only):
    """把名字文本收窄，给旗帜腾位置（幂等）。"""
    if check_only:
        return
    txt = open(prefab, encoding="utf-8").read()
    objs = parse(txt)
    lines = txt.split("\n")
    for (pf, path, width) in targets:
        if pf != prefab:
            continue
        rt = find(objs, path)
        if not rt:
            print("  ⚠️ 找不到 %s" % "/".join(path))
            continue
        start = None
        for i, l in enumerate(lines):
            if l.strip() == "--- !u!224 &%s" % rt:
                start = i
                break
        end = start + 1
        while end < len(lines) and not lines[end].startswith("--- "):
            end += 1
        for i in range(start, end):
            if lines[i].strip().startswith("m_SizeDelta:"):
                m = re.search(r"\{x: (-?[\d.]+), y: (-?[\d.]+)\}", lines[i])
                h = m.group(2)
                if m.group(1) != str(width):
                    lines[i] = "  m_SizeDelta: {x: %s, y: %s}" % (width, h)
                    print("  ~ %s 宽度 %s -> %s" % ("/".join(path), m.group(1), width))
                break
    open(prefab, "w", encoding="utf-8", newline="\n").write("\n".join(lines))


def main():
    check_only = "--check" in sys.argv
    total = 0
    for prefab in (RANKING, ARENA):
        narrow_text(prefab, NARROW, check_only)
        total += patch(prefab, TARGETS, check_only)
    print("合计：%d 处" % total)


if __name__ == "__main__":
    main()
