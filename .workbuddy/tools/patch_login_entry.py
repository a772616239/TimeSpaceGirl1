#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
给启动页（Login/LoginPanel.prefab）追加「国家排行」入口按钮节点。

为什么不像别处那样整包重生成 prefab：LoginPanel 是线上核心界面、7k+ 行，
整包重生成风险不可控。这里做**纯追加**：
  - 新增 3 个 GameObject 子树（按钮 / 图标 / 文字）
  - 只在 btns 容器的 m_Children 末尾追加一个 fileID
已存在则跳过（幂等）。
"""
import os
import re
import hashlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PREFAB = os.path.join(ROOT, "Assets/ManagedResources/Prefabs/UI/Login/LoginPanel.prefab")
NODE_NAME = "btnCountryRank"

GUID_UGUI = "f70555f144d8491a825f0804e09c671c"
GUID_LANGUAGE_TEXT = "ebfe0e44da74fbd44b1b744995de2324"
GUID_OUTLINE_SHADOW = "23268c41913a3c94497afd2305edc03f"
GUID_FONT = "d86d8a727ce12394cb7af8a758dd3ec7"
ATLAS = os.path.join(ROOT, "Assets/ManagedResources/Atlas/CountryRankPanelAtlas")

FILEID_IMAGE = -765806418
FILEID_TEXT = 708705254
FILEID_BUTTON = 1392445389


def sprite_guid(name):
    with open(os.path.join(ATLAS, name + ".png.meta"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("guid:"):
                return line.split(":", 1)[1].strip()
    raise KeyError(name)


def new_id(seed):
    h = hashlib.md5(("TimeSpaceGirl1/LoginEntry/" + seed).encode()).hexdigest()
    return str(int(h[:15], 16) + 300000000000000000)


def parse(txt):
    docs = re.split(r"^--- !u!(\d+) &(\d+)", txt, flags=re.M)
    objs, order = {}, []
    i = 1
    while i < len(docs):
        fid = docs[i + 1]
        objs[fid] = [int(docs[i]), docs[i + 2] if i + 2 < len(docs) else ""]
        order.append(fid)
        i += 3
    return objs, order


def go_rect_of(objs, name):
    for fid, (cls, body) in objs.items():
        if cls == 1 and re.search(r"m_Name: " + re.escape(name) + r"$", body.strip(), re.M):
            for c in re.findall(r"component: \{fileID: (\d+)\}", body):
                if objs[c][0] == 224:
                    return c
    return None


def block_gameobject(gid, name, components):
    lines = ["--- !u!1 &%s" % gid, "GameObject:", "  m_ObjectHideFlags: 0",
             "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
             "  m_PrefabAsset: {fileID: 0}", "  serializedVersion: 6", "  m_Component:"]
    for _cls, cid in components:
        lines.append("  - component: {fileID: %s}" % cid)
    lines += ["  m_Layer: 5", "  m_Name: %s" % name, "  m_TagString: Untagged",
              "  m_Icon: {fileID: 0}", "  m_NavMeshLayer: 0", "  m_StaticEditorFlags: 0",
              "  m_IsActive: 1"]
    return "\n".join(lines) + "\n"


def block_rect(rid, gid, parent_rt, children, pos, size, root_order,
               anchor_min=(0, 1), anchor_max=(0, 1), pivot=(0.5, 0.5)):
    if children:
        kids = "\n" + "".join("\n  - {fileID: %s}" % c for c in children)
    else:
        kids = " []"
    lines = ["--- !u!224 &%s" % rid, "RectTransform:", "  m_ObjectHideFlags: 0",
             "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
             "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
             "  m_LocalRotation: {x: 0, y: 0, z: 0, w: 1}",
             "  m_LocalPosition: {x: 0, y: 0, z: 0}",
             "  m_LocalScale: {x: 1, y: 1, z: 1}",
             "  m_ConstrainProportionsScale: 0",
             "  m_Children:%s" % kids,
             "  m_Father: {fileID: %s}" % parent_rt,
             "  m_LocalEulerAnglesHint: {x: 0, y: 0, z: 0}",
             "  m_AnchorMin: {x: %s, y: %s}" % anchor_min,
             "  m_AnchorMax: {x: %s, y: %s}" % anchor_max,
             "  m_AnchoredPosition: {x: %s, y: %s}" % pos,
             "  m_SizeDelta: {x: %s, y: %s}" % size,
             "  m_Pivot: {x: %s, y: %s}" % pivot]
    if root_order is not None:
        lines.insert(9, "  m_RootOrder: %d" % root_order)
    return "\n".join(lines) + "\n"


def block_canvasrenderer(cid, gid):
    return "\n".join(["--- !u!222 &%s" % cid, "CanvasRenderer:", "  m_ObjectHideFlags: 0",
                      "  m_CorrespondingSourceObject: {fileID: 0}",
                      "  m_PrefabInstance: {fileID: 0}", "  m_PrefabAsset: {fileID: 0}",
                      "  m_GameObject: {fileID: %s}" % gid, "  m_CullTransparentMesh: 0"]) + "\n"


def block_image(cid, gid, sprite, raycast=1, color="{r: 1, g: 1, b: 1, a: 1}"):
    return "\n".join([
        "--- !u!114 &%s" % cid, "MonoBehaviour:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
        "  m_Enabled: 1", "  m_EditorHideFlags: 0",
        "  m_Script: {fileID: %d, guid: %s, type: 3}" % (FILEID_IMAGE, GUID_UGUI),
        "  m_Name: ", "  m_EditorClassIdentifier: ", "  m_Material: {fileID: 0}",
        "  m_Color: %s" % color, "  m_RaycastTarget: %d" % raycast,
        "  m_OnCullStateChanged:", "    m_PersistentCalls:", "      m_Calls: []",
        "    m_TypeName: UnityEngine.UI.MaskableGraphic+CullStateChangedEvent, "
        "UnityEngine.UI, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null",
        "  m_Sprite: {fileID: 21300000, guid: %s, type: 3}" % sprite,
        "  m_Type: 0", "  m_PreserveAspect: 0", "  m_FillCenter: 1", "  m_FillMethod: 4",
        "  m_FillAmount: 1", "  m_FillClockwise: 1", "  m_FillOrigin: 0",
        "  m_UseSpriteMesh: 0"]) + "\n"


def block_button(cid, gid, target_cid):
    return "\n".join([
        "--- !u!114 &%s" % cid, "MonoBehaviour:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
        "  m_Enabled: 1", "  m_EditorHideFlags: 0",
        "  m_Script: {fileID: %d, guid: %s, type: 3}" % (FILEID_BUTTON, GUID_UGUI),
        "  m_Name: ", "  m_EditorClassIdentifier: ", "  m_Navigation:",
        "    m_Mode: 3", "    m_SelectOnUp: {fileID: 0}", "    m_SelectOnDown: {fileID: 0}",
        "    m_SelectOnLeft: {fileID: 0}", "    m_SelectOnRight: {fileID: 0}",
        "  m_Transition: 3", "  m_Colors:",
        "    m_NormalColor: {r: 1, g: 1, b: 1, a: 1}",
        "    m_HighlightedColor: {r: 0.9607843, g: 0.9607843, b: 0.9607843, a: 1}",
        "    m_PressedColor: {r: 0.78431374, g: 0.78431374, b: 0.78431374, a: 1}",
        "    m_DisabledColor: {r: 0.78431374, g: 0.78431374, b: 0.78431374, a: 0.5019608}",
        "    m_ColorMultiplier: 1", "    m_FadeDuration: 0.1",
        "  m_SpriteState:", "    m_HighlightedSprite: {fileID: 0}",
        "    m_PressedSprite: {fileID: 0}", "    m_DisabledSprite: {fileID: 0}",
        "  m_AnimationTriggers:", "    m_NormalTrigger: Normal",
        "    m_HighlightedTrigger: Highlighted", "    m_PressedTrigger: Pressed",
        "    m_DisabledTrigger: Disabled", "  m_Interactable: 1",
        "  m_TargetGraphic: {fileID: %s}" % target_cid, "  m_OnClick:",
        "    m_PersistentCalls:", "      m_Calls: []",
        "    m_TypeName: UnityEngine.UI.Button+ButtonClickedEvent, UnityEngine.UI, "
        "Version=1.0.0.0, Culture=neutral, PublicKeyToken=null"]) + "\n"


def block_text(cid, gid, content, size=22, color="{r: 1, g: 0.839, b: 0, a: 1}"):
    return "\n".join([
        "--- !u!114 &%s" % cid, "MonoBehaviour:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
        "  m_Enabled: 1", "  m_EditorHideFlags: 0",
        "  m_Script: {fileID: 11500000, guid: %s, type: 3}" % GUID_LANGUAGE_TEXT,
        "  m_Name: ", "  m_EditorClassIdentifier: ", "  m_Material: {fileID: 0}",
        "  m_Color: %s" % color, "  m_RaycastTarget: 0",
        "  m_OnCullStateChanged:", "    m_PersistentCalls:", "      m_Calls: []",
        "    m_TypeName: UnityEngine.UI.MaskableGraphic+CullStateChangedEvent, "
        "UnityEngine.UI, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null",
        "  m_FontData:",
        "    m_Font: {fileID: 12800000, guid: %s, type: 3}" % GUID_FONT,
        "    m_FontSize: %d" % size, "    m_FontStyle: 1", "    m_BestFit: 0",
        "    m_MinSize: 10", "    m_MaxSize: 40", "    m_Alignment: 4",
        "    m_AlignByGeometry: 0", "    m_RichText: 1",
        "    m_HorizontalOverflow: 1", "    m_VerticalOverflow: 1",
        "    m_LineSpacing: 1", "  m_Text: %s" % content, "  LanguageIndex: 0"]) + "\n"


def block_outline(cid, gid):
    return "\n".join([
        "--- !u!114 &%s" % cid, "MonoBehaviour:", "  m_ObjectHideFlags: 0",
        "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
        "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % gid,
        "  m_Enabled: 1", "  m_EditorHideFlags: 0",
        "  m_Script: {fileID: 11500000, guid: %s, type: 3}" % GUID_OUTLINE_SHADOW,
        "  m_Name: ", "  m_EditorClassIdentifier: ",
        "  m_OutlineColor: {r: 0, g: 0, b: 0, a: 1}",
        "  m_OutlineDistance: {x: 1, y: -1}",
        "  m_ShadowColor: {r: 0, g: 0, b: 0, a: 0.784}",
        "  m_ShadowDistance: {x: 1, y: -1}",
        "  m_UseGraphicAlpha: 1"]) + "\n"


def main():
    txt = open(PREFAB, encoding="utf-8").read()
    if "m_Name: %s" % NODE_NAME in txt:
        print("已存在 %s，跳过" % NODE_NAME)
        return

    objs, order = parse(txt)
    btns_rt = go_rect_of(objs, "btns")
    assert btns_rt, "找不到 btns 容器"
    btns_body = objs[btns_rt][1]
    existing_children = re.findall(r"\{fileID: (\d+)\}", btns_body.split("m_Father")[0])
    root_order = len(existing_children)

    # 按钮放在客服按钮下方（客服在 y=-496，尺寸 106x92）
    btn_id = new_id("btn-rt")
    icon_go = new_id("icon-go")
    icon_rt = new_id("icon-rt")
    icon_cr = new_id("icon-cr")
    icon_img = new_id("icon-img")
    txt_go = new_id("text-go")
    txt_rt = new_id("text-rt")
    txt_cr = new_id("text-cr")
    txt_comp = new_id("text-comp")
    txt_outline = new_id("text-outline")

    btn_rt = new_id("btn-rt2")
    btn_cr = new_id("btn-cr")
    btn_img = new_id("btn-img")
    btn_comp = new_id("btn-comp")

    chunks = []
    # 按钮本体
    chunks.append(block_gameobject(btn_id, NODE_NAME, [(224, btn_rt), (222, btn_cr),
                                                       (114, btn_img), (114, btn_comp)]))
    chunks.append(block_rect(btn_rt, btn_id, btns_rt, [icon_rt, txt_rt],
                             (94.02606, -598), (106, 92), root_order))
    chunks.append(block_canvasrenderer(btn_cr, btn_id))
    chunks.append(block_image(btn_img, btn_id, sprite_guid("cn2-x1_guojiapaihang_rukou")))
    chunks.append(block_button(btn_comp, btn_id, btn_img))

    # 图标（复用同一张图，铺满按钮；文字在下方单独排）
    chunks.append(block_gameobject(icon_go, "icon", [(224, icon_rt), (222, icon_cr),
                                                     (114, icon_img)]))
    chunks.append(block_rect(icon_rt, icon_go, btn_rt, [], (0, 8), (76, 76), 0,
                             anchor_min=(0.5, 0.5), anchor_max=(0.5, 0.5)))
    chunks.append(block_canvasrenderer(icon_cr, icon_go))
    chunks.append(block_image(icon_img, icon_go, sprite_guid("cn2-x1_guojiapaihang_rukou"), raycast=0))

    # 文字
    chunks.append(block_gameobject(txt_go, "Text", [(224, txt_rt), (222, txt_cr),
                                                    (114, txt_comp), (114, txt_outline)]))
    chunks.append(block_rect(txt_rt, txt_go, btn_rt, [], (0, -30), (140, 28), 1,
                             anchor_min=(0.5, 0.5), anchor_max=(0.5, 0.5)))
    chunks.append(block_canvasrenderer(txt_cr, txt_go))
    chunks.append(block_text(txt_comp, txt_go, "国家排行"))
    chunks.append(block_outline(txt_outline, txt_go))

    new_txt = txt.rstrip("\n") + "\n" + "".join(chunks)

    # 把新按钮挂到 btns 的 m_Children 末尾
    m = re.search(r"--- !u!224 &%s\nRectTransform:(.*?)m_Father" % btns_rt, new_txt, re.S)
    assert m, "定位 btns RectTransform 失败"
    seg = m.group(0)
    if "m_Children: []" in seg:
        seg_new = seg.replace("m_Children: []", "m_Children:\n  - {fileID: %s}" % btn_rt)
    else:
        seg_new = seg.replace("m_Father", "  - {fileID: %s}\n  m_Father" % btn_rt, 1)
    new_txt = new_txt.replace(seg, seg_new, 1)

    open(PREFAB, "w", encoding="utf-8", newline="\n").write(new_txt)
    print("已追加 %s（fileID %s）到 btns，rootOrder=%d" % (NODE_NAME, btn_rt, root_order))


if __name__ == "__main__":
    main()
