#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成「国家排行榜」相关的 Unity uGUI prefab（纯文本 YAML，无需打开 Unity）。

产出：
  Assets/ManagedResources/Prefabs/UI/CountryRank/CountryRankPanel.prefab        国家排行榜弹窗
  Assets/ManagedResources/Prefabs/UI/CountryRank/CountryFlagSelectPopup.prefab  国家旗帜选择弹窗

约定（照抄仓库现有 prefab）：
  - 面板根节点：RectTransform + Canvas(RenderMode=2) + GraphicRaycaster
  - 子孙节点：RectTransform + CanvasRenderer + Image / Text
  - 文本统一用 LanguageText（可多语言，TextField 由 Lua 赋值），描边用 OutlineAndShadow
  - 图片 sprite 统一留空，由 Lua 用 Util.LoadSprite(name) 运行时赋值（与项目现有习惯一致）
    但底板/装饰这类静态件直接在 prefab 里写 sprite，减少 Lua 侧开销

用法：python3 .workbuddy/tools/gen_country_rank_prefab.py
"""
import hashlib
import os
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PREFAB_DIR = os.path.join(ROOT, "Assets/ManagedResources/Prefabs/UI/CountryRank")
ATLAS_SPRITE_DIR = os.path.join(ROOT, "Assets/ManagedResources/Atlas/CountryRankPanelAtlas")

# ------------------------------------------------------------------ 常量
GUID_UGUI = "f70555f144d8491a825f0804e09c671c"          # UnityEngine.UI 程序集
FILEID_IMAGE = -765806418                                # Image
FILEID_TEXT = 708705254                                  # Text
FILEID_BUTTON = 1392445389                               # Button
FILEID_RAYCASTER = 11500000                              # 自定义脚本统一 fileID
GUID_RAYCASTER = "dc42784cf147c0c48a680349fa168899"      # UGUI GraphicRaycaster
GUID_LANGUAGE_TEXT = "ebfe0e44da74fbd44b1b744995de2324"  # Assets/Scripts/UI/LanguageText.cs
GUID_OUTLINE_SHADOW = "23268c41913a3c94497afd2305edc03f" # Assets/Scripts/UI/OutlineAndShadow.cs
GUID_EMPTY_RAYCAST = "e459a084d8e15a240b58db751097122b"  # Assets/Scripts/UI/EmptyRaycast.cs
GUID_FONT = "d86d8a727ce12394cb7af8a758dd3ec7"           # OPPOSans-M-2.ttf
FILEID_SPRITE = 21300000                                 # 单张 sprite 子资源
FILEID_FONT = 12800000                                   # 字体子资源

# uGUI 组件在 prefab 里是 MonoBehaviour，fileID 由 UnityEngine.UI 程序集内部的
# 固定 localID 决定（Unity 的 classic script id）；上面三个常量即 Image/Text/Button。
# Canvas / CanvasRenderer / RectTransform 是引擎原生 class id。
CLS_GAMEOBJECT = 1
CLS_TRANSFORM = 4
CLS_CANVASRENDERER = 222
CLS_CANVAS = 223
CLS_RECTTRANSFORM = 224


# ------------------------------------------------------------------ sprite guid 索引
def sprite_guid(sprite_name):
    """读取 Atlas 目录下同名 png 的 meta guid。"""
    meta = os.path.join(ATLAS_SPRITE_DIR, sprite_name + ".png.meta")
    if not os.path.exists(meta):
        raise KeyError("找不到 sprite meta: %s" % meta)
    with open(meta, encoding="utf-8") as f:
        for line in f:
            if line.startswith("guid:"):
                return line.split(":", 1)[1].strip()
    raise KeyError("meta 里没有 guid: %s" % meta)


def make_guid(seed):
    """由名字派生稳定的 GUID（32 位 hex），保证重复生成结果一致。"""
    h = hashlib.md5(("TimeSpaceGirl1/CountryRank/" + seed).encode("utf-8")).hexdigest()
    return h


_next_fileid = [114000000000000000]


def new_fileid():
    _next_fileid[0] += 7919
    return str(_next_fileid[0])


# ------------------------------------------------------------------ 节点模型
class Node:
    def __init__(self, name, x=0, y=0, w=100, h=100,
                 anchor_min=(0.5, 0.5), anchor_max=(0.5, 0.5), pivot=(0.5, 0.5),
                 scale=1.0, active=True):
        self.name = name
        self.children = []
        self.go_id = new_fileid()
        self.rt_id = new_fileid()
        self.cr_id = new_fileid() if True else None
        self.x, self.y, self.w, self.h = x, y, w, h
        self.anchor_min = anchor_min
        self.anchor_max = anchor_max
        self.pivot = pivot
        self.scale = scale
        self.active = active
        self.components = []   # list of (kind, payload)
        self.parent = None

    def add(self, child):
        child.parent = self
        self.children.append(child)
        return child

    # ---- 组件挂载
    def image(self, sprite=None, color=(1, 1, 1, 1), raycast=True, img_type=0,
              fill_method=4, fill_amount=1, preserve_aspect=False, empty_raycast=False):
        self.components.append(("image", dict(
            sprite=sprite, color=color, raycast=raycast, img_type=img_type,
            fill_method=fill_method, fill_amount=fill_amount,
            preserve_aspect=preserve_aspect, empty_raycast=empty_raycast)))
        return self

    def text(self, content="", size=32, color=(1, 1, 1, 1), align=3, font_style=1,
             outline=True, raycast=False, best_fit=False, min_size=10, max_size=60,
             line_spacing=1, language=True):
        self.components.append(("text", dict(
            content=content, size=size, color=color, align=align, font_style=font_style,
            outline=outline, raycast=raycast, best_fit=best_fit, min_size=min_size,
            max_size=max_size, line_spacing=line_spacing, language=language)))
        return self

    def button(self, target_sprite=None):
        self.components.append(("button", dict(target_sprite=target_sprite)))
        return self


# ------------------------------------------------------------------ YAML 发射
def fnum(v):
    if isinstance(v, float):
        if abs(v - round(v)) < 1e-6:
            return str(int(round(v)))
        s = ("%.7f" % v).rstrip("0").rstrip(".")
        return s if s else "0"
    return str(v)


def vec(spec):
    if isinstance(spec, dict):
        return " ".join("{%s: %s}" % (k, fnum(v)) for k, v in spec.items())
    return spec


def color_str(c):
    return "{r: %s, g: %s, b: %s, a: %s}" % tuple(fnum(v) for v in c)


def emit(obj_id, cls, body):
    return "--- !u!%d &%s\n%s\n" % (cls, obj_id, body)


def gen_gameobject(node):
    comps = [(CLS_RECTTRANSFORM, node.rt_id)]
    if node.cr_id:
        comps.append((CLS_CANVASRENDERER, node.cr_id))
    if node.name == "__root__canvas":
        comps.append((CLS_CANVAS, node.canvas_id))
        comps.append((114, node.raycaster_id))
    for i, (kind, _payload) in enumerate(node.components):
        comps.append((114, node.comp_ids[i]))
    lines = []
    lines.append("GameObject:")
    lines.append("  m_ObjectHideFlags: 0")
    lines.append("  m_CorrespondingSourceObject: {fileID: 0}")
    lines.append("  m_PrefabInstance: {fileID: 0}")
    lines.append("  m_PrefabAsset: {fileID: 0}")
    lines.append("  serializedVersion: 6")
    lines.append("  m_Component:")
    for cls, fid in comps:
        lines.append("  - component: {fileID: %s}" % fid)
    lines.append("  m_Layer: 5")
    lines.append("  m_Name: %s" % node.name)
    lines.append("  m_TagString: Untagged")
    lines.append("  m_Icon: {fileID: 0}")
    lines.append("  m_NavMeshLayer: 0")
    lines.append("  m_StaticEditorFlags: 0")
    lines.append("  m_IsActive: %d" % (1 if node.active else 0))
    return emit(node.go_id, CLS_GAMEOBJECT, "\n".join(lines))


def gen_recttransform(node, is_root=False):
    children = "".join("\n  - {fileID: %s}" % c.rt_id for c in node.children)
    if children:
        children_block = "  m_Children:%s\n" % children
    else:
        children_block = "  m_Children: []\n"
    father = "0" if is_root or node.parent is None else node.parent.rt_id
    root_order = 0 if (is_root or node.parent is None) else node.parent.children.index(node)
    lines = []
    lines.append("RectTransform:")
    lines.append("  m_ObjectHideFlags: 0")
    lines.append("  m_CorrespondingSourceObject: {fileID: 0}")
    lines.append("  m_PrefabInstance: {fileID: 0}")
    lines.append("  m_PrefabAsset: {fileID: 0}")
    lines.append("  m_GameObject: {fileID: %s}" % node.go_id)
    lines.append("  m_LocalRotation: {x: 0, y: 0, z: 0, w: 1}")
    lines.append("  m_LocalPosition: {x: %s, y: %s, z: 0}" % (fnum(node.x), fnum(node.y)))
    lines.append("  m_LocalScale: {x: %s, y: %s, z: %s}" %
                 (fnum(node.scale), fnum(node.scale), fnum(node.scale)))
    lines.append("  m_ConstrainProportionsScale: 0")
    lines.append(children_block.rstrip("\n"))
    lines.append("  m_Father: {fileID: %s}" % father)
    lines.append("  m_LocalEulerAnglesHint: {x: 0, y: 0, z: 0}")
    lines.append("  m_AnchorMin: {x: %s, y: %s}" % (fnum(node.anchor_min[0]), fnum(node.anchor_min[1])))
    lines.append("  m_AnchorMax: {x: %s, y: %s}" % (fnum(node.anchor_max[0]), fnum(node.anchor_max[1])))
    lines.append("  m_AnchoredPosition: {x: %s, y: %s}" % (fnum(node.x), fnum(node.y)))
    lines.append("  m_SizeDelta: {x: %s, y: %s}" % (fnum(node.w), fnum(node.h)))
    lines.append("  m_Pivot: {x: %s, y: %s}" % (fnum(node.pivot[0]), fnum(node.pivot[1])))
    return emit(node.rt_id, CLS_RECTTRANSFORM, "\n".join(lines))


def gen_canvasrenderer(node):
    lines = ["CanvasRenderer:", "  m_ObjectHideFlags: 0",
             "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
             "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % node.go_id,
             "  m_CullTransparentMesh: 0"]
    return emit(node.cr_id, CLS_CANVASRENDERER, "\n".join(lines))


def gen_canvas(node):
    lines = ["Canvas:", "  m_ObjectHideFlags: 0",
             "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
             "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % node.go_id,
             "  m_Enabled: 1", "  serializedVersion: 3", "  m_RenderMode: 2",
             "  m_Camera: {fileID: 0}", "  m_PlaneDistance: 100", "  m_PixelPerfect: 0",
             "  m_ReceivesEvents: 1", "  m_OverrideSorting: 1", "  m_OverridePixelPerfect: 0",
             "  m_SortingBucketNormalizedSize: 0", "  m_VertexColorAlwaysGammaSpace: 0",
             "  m_AdditionalShaderChannelsFlag: 0", "  m_UpdateRectTransformForStandalone: 0",
             "  m_SortingLayerID: 0", "  m_SortingOrder: 0", "  m_TargetDisplay: 0"]
    return emit(node.canvas_id, CLS_CANVAS, "\n".join(lines))


def gen_raycaster(node):
    lines = ["MonoBehaviour:", "  m_ObjectHideFlags: 0",
             "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
             "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % node.go_id,
             "  m_Enabled: 1", "  m_EditorHideFlags: 0",
             "  m_Script: {fileID: 11500000, guid: %s, type: 3}" % GUID_RAYCASTER,
             "  m_Name: ", "  m_EditorClassIdentifier: ",
             "  m_IgnoreReversedGraphics: 1", "  m_BlockingObjects: 0",
             "  m_BlockingMask:", "    serializedVersion: 2", "    m_Bits: 3895"]
    return emit(node.raycaster_id, 114, "\n".join(lines))


RELATED = ("    m_TypeName: UnityEngine.UI.MaskableGraphic+CullStateChangedEvent, " +
           "UnityEngine.UI, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null")


def gen_image(node, fid, p):
    sprite = "{fileID: 0}"
    if p["sprite"]:
        sprite = "{fileID: %d, guid: %s, type: 3}" % (FILEID_SPRITE, p["sprite"])
    lines = ["MonoBehaviour:", "  m_ObjectHideFlags: 0",
             "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
             "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % node.go_id,
             "  m_Enabled: 1", "  m_EditorHideFlags: 0",
             "  m_Script: {fileID: %d, guid: %s, type: 3}" % (FILEID_IMAGE, GUID_UGUI),
             "  m_Name: ", "  m_EditorClassIdentifier: ", "  m_Material: {fileID: 0}",
             "  m_Color: %s" % color_str(p["color"]),
             "  m_RaycastTarget: %d" % (1 if p["raycast"] else 0),
             "  m_OnCullStateChanged:", "    m_PersistentCalls:", "      m_Calls: []",
             RELATED,
             "  m_Sprite: %s" % sprite,
             "  m_Type: %d" % p["img_type"],
             "  m_PreserveAspect: %d" % (1 if p["preserve_aspect"] else 0),
             "  m_FillCenter: 1", "  m_FillMethod: %d" % p["fill_method"],
             "  m_FillAmount: %s" % fnum(p["fill_amount"]),
             "  m_FillClockwise: 1", "  m_FillOrigin: 0", "  m_UseSpriteMesh: 0"]
    return emit(fid, 114, "\n".join(lines))


def gen_text(node, fid, p):
    lines = ["MonoBehaviour:", "  m_ObjectHideFlags: 0",
             "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
             "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % node.go_id,
             "  m_Enabled: 1", "  m_EditorHideFlags: 0"]
    if p["language"]:
        lines.append("  m_Script: {fileID: 11500000, guid: %s, type: 3}" % GUID_LANGUAGE_TEXT)
    else:
        lines.append("  m_Script: {fileID: %d, guid: %s, type: 3}" % (FILEID_TEXT, GUID_UGUI))
    lines += ["  m_Name: ", "  m_EditorClassIdentifier: ", "  m_Material: {fileID: 0}",
              "  m_Color: %s" % color_str(p["color"]),
              "  m_RaycastTarget: %d" % (1 if p["raycast"] else 0),
              "  m_OnCullStateChanged:", "    m_PersistentCalls:", "      m_Calls: []",
              RELATED,
              "  m_FontData:",
              "    m_Font: {fileID: %d, guid: %s, type: 3}" % (FILEID_FONT, GUID_FONT),
              "    m_FontSize: %d" % p["size"],
              "    m_FontStyle: %d" % p["font_style"],
              "    m_BestFit: %d" % (1 if p["best_fit"] else 0),
              "    m_MinSize: %d" % p["min_size"],
              "    m_MaxSize: %d" % p["max_size"],
              "    m_Alignment: %d" % p["align"],
              "    m_AlignByGeometry: 0",
              "    m_RichText: 1",
              "    m_HorizontalOverflow: 1",
              "    m_VerticalOverflow: 1",
              "    m_LineSpacing: %s" % fnum(p["line_spacing"]),
              "  m_Text: %s" % p["content"]]
    if p["language"]:
        lines.append("  LanguageIndex: 0")
    out = emit(fid, 114, "\n".join(lines))
    if p["outline"]:
        out += emit(new_fileid(), 114, "\n".join([
            "MonoBehaviour:", "  m_ObjectHideFlags: 0",
            "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
            "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % node.go_id,
            "  m_Enabled: 1", "  m_EditorHideFlags: 0",
            "  m_Script: {fileID: 11500000, guid: %s, type: 3}" % GUID_OUTLINE_SHADOW,
            "  m_Name: ", "  m_EditorClassIdentifier: ",
            "  m_OutlineColor: {r: 0, g: 0, b: 0, a: 1}",
            "  m_OutlineDistance: {x: 1, y: -1}",
            "  m_ShadowColor: {r: 0, g: 0, b: 0, a: 0.784}",
            "  m_ShadowDistance: {x: 1, y: -1}",
            "  m_UseGraphicAlpha: 1"]))
    return out


def gen_button(node, fid, p, target_fid):
    lines = ["MonoBehaviour:", "  m_ObjectHideFlags: 0",
             "  m_CorrespondingSourceObject: {fileID: 0}", "  m_PrefabInstance: {fileID: 0}",
             "  m_PrefabAsset: {fileID: 0}", "  m_GameObject: {fileID: %s}" % node.go_id,
             "  m_Enabled: 1", "  m_EditorHideFlags: 0",
             "  m_Script: {fileID: %d, guid: %s, type: 3}" % (FILEID_BUTTON, GUID_UGUI),
             "  m_Name: ", "  m_EditorClassIdentifier: ", "  m_Navigation:",
             "    m_Mode: 3", "    m_SelectOnUp: {fileID: 0}", "    m_SelectOnDown: {fileID: 0}",
             "    m_SelectOnLeft: {fileID: 0}", "    m_SelectOnRight: {fileID: 0}",
             "  m_Transition: 3",
             "  m_Colors:",
             "    m_NormalColor: {r: 1, g: 1, b: 1, a: 1}",
             "    m_HighlightedColor: {r: 0.9607843, g: 0.9607843, b: 0.9607843, a: 1}",
             "    m_PressedColor: {r: 0.78431374, g: 0.78431374, b: 0.78431374, a: 1}",
             "    m_DisabledColor: {r: 0.78431374, g: 0.78431374, b: 0.78431374, a: 0.5019608}",
             "    m_ColorMultiplier: 1", "    m_FadeDuration: 0.1",
             "  m_SpriteState:",
             "    m_HighlightedSprite: {fileID: 0}",
             "    m_PressedSprite: {fileID: 0}",
             "    m_DisabledSprite: {fileID: 0}",
             "  m_AnimationTriggers:",
             "    m_NormalTrigger: Normal",
             "    m_HighlightedTrigger: Highlighted",
             "    m_PressedTrigger: Pressed",
             "    m_DisabledTrigger: Disabled",
             "  m_Interactable: 1",
             "  m_TargetGraphic: {fileID: %s}" % target_fid,
             "  m_OnClick:",
             "    m_PersistentCalls:",
             "      m_Calls: []",
             "    m_TypeName: UnityEngine.UI.Button+ButtonClickedEvent, UnityEngine.UI, "
             "Version=1.0.0.0, Culture=neutral, PublicKeyToken=null"]
    return emit(fid, 114, "\n".join(lines))


def assign_comp_ids(node):
    """给每个组件的 MonoBehaviour 预先分配 fileID。"""
    node.comp_ids = [new_fileid() for _ in node.components]


def emit_node(node, out, is_root=False):
    assign_comp_ids(node)
    out.append(gen_gameobject(node))
    out.append(gen_recttransform(node, is_root))
    if node.cr_id:
        out.append(gen_canvasrenderer(node))
    if is_root:
        out.append(gen_canvas(node))
        out.append(gen_raycaster(node))
    image_fid = None
    for i, (kind, payload) in enumerate(node.components):
        fid = node.comp_ids[i]
        if kind == "image":
            out.append(gen_image(node, fid, payload))
            image_fid = fid
        elif kind == "text":
            out.append(gen_text(node, fid, payload))
            image_fid = image_fid or fid
        elif kind == "button":
            out.append(gen_button(node, fid, payload, image_fid or node.rt_id))
    for child in node.children:
        emit_node(child, out)


# ------------------------------------------------------------------ 布局定义
W_PANEL, H_PANEL = 940, 1440          # 排行榜面板
W_SELECT, H_SELECT = 940, 1120        # 旗帜选择面板
ROW_W, ROW_H = 920, 104
ROW_GAP = 8
TEXT_GOLD = (1.0, 0.839, 0.0, 1.0)
TEXT_WHITE = (0.941, 0.937, 0.980, 1.0)
TEXT_DIM = (0.588, 0.549, 0.706, 1.0)


def root_node(name):
    n = Node(name, 0, 0, 1080, 2160, anchor_min=(0, 0), anchor_max=(1, 1))
    n.canvas_id = new_fileid()
    n.raycaster_id = new_fileid()
    return n


def build_rank_row(parent, y, is_first=False):
    """一条排行条目（ItemPre 模板）。"""
    row = parent.add(Node("ItemPre", 0, y, ROW_W, ROW_H,
                          anchor_min=(0.5, 1), anchor_max=(0.5, 1), pivot=(0.5, 1)))
    row.image(sprite=sprite_guid("cn2-x1_guojiapaihang_tiaomu"), raycast=True)

    # 名次牌（1/2/3 用奖牌图，其余显示数字文本；Lua 控制显隐）
    medal = row.add(Node("medal", 14, 8, 88, 88, anchor_min=(0, 1), anchor_max=(0, 1),
                         pivot=(0, 1)))
    medal.image(sprite=sprite_guid("cn2-x1_guojiapaihang_paiming_01"), raycast=False)

    # 名次数字（无奖牌时用）
    rank_num = row.add(Node("rankNum", 8, 0, 100, ROW_H, anchor_min=(0, 0.5),
                            anchor_max=(0, 0.5), pivot=(0, 0.5)))
    rank_num.text("1", size=34, align=4, color=TEXT_WHITE)

    # 旗帜
    flag = row.add(Node("flag", 130, -0.5, 108, 72, anchor_min=(0, 0.5),
                        anchor_max=(0, 0.5), pivot=(0, 0.5)))
    flag.image(sprite=sprite_guid("cn2-guoqi_cn"), raycast=False, preserve_aspect=True)

    # 玩家/国家名
    name = row.add(Node("nameText", 262, 14, 420, 40, anchor_min=(0, 0.5),
                        anchor_max=(0, 0.5), pivot=(0, 0.5)))
    name.text("中国", size=32, align=3, color=TEXT_WHITE)

    # 副标题（国家名 / 等级）
    sub = row.add(Node("subText", 262, -22, 420, 30, anchor_min=(0, 0.5),
                       anchor_max=(0, 0.5), pivot=(0, 0.5)))
    sub.text("", size=22, align=3, color=TEXT_DIM)

    # 分数
    score = row.add(Node("scoreText", -34, 0, 300, 60, anchor_min=(1, 0.5),
                         anchor_max=(1, 0.5), pivot=(1, 0.5)))
    score.text("0", size=32, align=5, color=TEXT_GOLD)

    # 整行点击热区
    hit = row.add(Node("hitArea", 0, 0, ROW_W, ROW_H, anchor_min=(0, 0.5),
                       anchor_max=(1, 0.5), pivot=(0.5, 0.5),
                       ), )
    hit.image(raycast=True, color=(0, 0, 0, 0))
    return row


def build_rank_panel():
    root = root_node("CountryRankPanel")

    # 背景遮罩
    mask = root.add(Node("mask", 0, 0, 0, 0, anchor_min=(0, 0), anchor_max=(1, 1)))
    mask.image(raycast=True, color=(0.02, 0.015, 0.03, 0.86))

    # 主面板
    board = root.add(Node("board", 0, 0, W_PANEL, H_PANEL))
    board.image(sprite=sprite_guid("cn2-x1_guojiapaihang_diban"), raycast=True)

    # 标题条
    banner = board.add(Node("titleBanner", 0, -66, 560, 132,
                            anchor_min=(0.5, 1), anchor_max=(0.5, 1), pivot=(0.5, 0.5)))
    banner.image(sprite=sprite_guid("cn2-x1_guojiapaihang_biaoti"), raycast=False)

    title = board.add(Node("title", 0, -68, 460, 56,
                           anchor_min=(0.5, 1), anchor_max=(0.5, 1), pivot=(0.5, 0.5)))
    title.text("国家排行榜", size=40, align=4, color=TEXT_GOLD)

    # 关闭按钮
    close = board.add(Node("btnClose", -28, -30, 88, 88, anchor_min=(1, 1),
                           anchor_max=(1, 1), pivot=(1, 1)))
    close.image(sprite=sprite_guid("cn2-x1_guojiapaihang_guanbi"), raycast=True)
    close.button()

    # 页签
    tabs = board.add(Node("tabBox", 0, -210, 540, 92, anchor_min=(0.5, 1),
                          anchor_max=(0.5, 1), pivot=(0.5, 0.5)))
    for i, (node_name, label) in enumerate((("tabAll", "全服排行"), ("tabLocal", "本国排行"))):
        tab = tabs.add(Node(node_name, -134 + i * 268, 0, 248, 92,
                            anchor_min=(0.5, 0.5), anchor_max=(0.5, 0.5), pivot=(0.5, 0.5)))
        tab.image(sprite=sprite_guid("cn2-x1_guojiapaihang_yetan_xuanzhong" if i == 0
                                     else "cn2-x1_guojiapaihang_yetan_weixuanzhong"))
        tab.button()
        txt = tab.add(Node("text", 0, 0, 220, 46, anchor_min=(0.5, 0.5),
                           anchor_max=(0.5, 0.5), pivot=(0.5, 0.5)))
        txt.text(label, size=30, align=4,
                 color=(0.09, 0.07, 0.04, 1.0) if i == 0 else TEXT_DIM)

    # 列表区
    scroll = board.add(Node("scroll", 0, -56, 960, 976, anchor_min=(0.5, 0.5),
                            anchor_max=(0.5, 0.5), pivot=(0.5, 0.5)))
    list_root = scroll.add(Node("ScrollParentView", 0, 0, 960, 976,
                                anchor_min=(0.5, 0.5), anchor_max=(0.5, 0.5),
                                pivot=(0.5, 0.5)))
    build_rank_row(list_root, 0, True)

    # 我的排名
    mine = board.add(Node("myRank", 0, 24, ROW_W, 116, anchor_min=(0.5, 0),
                          anchor_max=(0.5, 0), pivot=(0.5, 0)))
    mine.image(sprite=sprite_guid("cn2-x1_guojiapaihang_wode"), raycast=False)
    m_title = mine.add(Node("title", 34, 0, 160, 44, anchor_min=(0, 0.5),
                            anchor_max=(0, 0.5), pivot=(0, 0.5)))
    m_title.text("我的排名", size=24, align=3, color=(1.0, 0.886, 0.588, 1.0))
    m_rank = mine.add(Node("rankText", 170, 0, 130, 48, anchor_min=(0, 0.5),
                           anchor_max=(0, 0.5), pivot=(0, 0.5)))
    m_rank.text("--", size=32, align=3, color=TEXT_WHITE)
    m_flag = mine.add(Node("flag", 302, 0, 108, 72, anchor_min=(0, 0.5),
                           anchor_max=(0, 0.5), pivot=(0, 0.5)))
    m_flag.image(raycast=False, preserve_aspect=True)
    m_name = mine.add(Node("nameText", 434, 0, 240, 44, anchor_min=(0, 0.5),
                           anchor_max=(0, 0.5), pivot=(0, 0.5)))
    m_name.text("", size=30, align=3, color=TEXT_WHITE)
    m_score = mine.add(Node("scoreText", -34, 0, 260, 60, anchor_min=(1, 0.5),
                            anchor_max=(1, 0.5), pivot=(1, 0.5)))
    m_score.text("0", size=32, align=5, color=TEXT_GOLD)

    # 切换国家按钮（右上角小按钮）
    pick = board.add(Node("btnPickCountry", -140, -44, 186, 72,
                          anchor_min=(1, 1), anchor_max=(1, 1), pivot=(1, 1)))
    pick.image(sprite=sprite_guid("cn2-x1_guojiapaihang_yetan_weixuanzhong"))
    pick.button()
    pick_txt = pick.add(Node("text", 0, 0, 140, 36, anchor_min=(0.5, 0.5),
                             anchor_max=(0.5, 0.5), pivot=(0.5, 0.5)))
    pick_txt.text("选择国家", size=22, align=4, color=TEXT_GOLD)
    return root


def build_select_popup():
    root = root_node("CountryFlagSelectPopup")

    mask = root.add(Node("mask", 0, 0, 0, 0, anchor_min=(0, 0), anchor_max=(1, 1)))
    mask.image(raycast=True, color=(0.02, 0.015, 0.03, 0.86))

    board = root.add(Node("board", 0, 0, W_SELECT, H_SELECT))
    board.image(sprite=sprite_guid("cn2-x1_guojiapaihang_xuanze_diban"), raycast=True)

    title = board.add(Node("title", 0, -70, 560, 52, anchor_min=(0.5, 1),
                           anchor_max=(0.5, 1), pivot=(0.5, 0.5)))
    title.text("选择你的国家", size=36, align=4, color=TEXT_GOLD)

    tip = board.add(Node("tip", 0, -116, 700, 36, anchor_min=(0.5, 1),
                         anchor_max=(0.5, 1), pivot=(0.5, 0.5)))
    tip.text("默认按设备地区自动选择，可随时修改", size=22, align=4, color=TEXT_DIM)

    close = board.add(Node("btnClose", -28, -26, 84, 84, anchor_min=(1, 1),
                           anchor_max=(1, 1), pivot=(1, 1)))
    close.image(sprite=sprite_guid("cn2-x1_guojiapaihang_guanbi"), raycast=True)
    close.button()

    # 旗帜网格容器（Lua 用 GuoqiGrid 动态填充格子）
    grid = board.add(Node("grid", 0, -15, 860, 810, anchor_min=(0.5, 0.5),
                          anchor_max=(0.5, 0.5), pivot=(0.5, 0.5)))

    # 单个旗帜格子模板（隐藏，由 Lua 克隆）
    cell = grid.add(Node("cellPre", 0, 0, 190, 176, anchor_min=(0.5, 0.5),
                         anchor_max=(0.5, 0.5), pivot=(0.5, 0.5), active=False)
    )
    cell.image(raycast=True, color=(0, 0, 0, 0))
    cell.button()
    cell_flag = cell.add(Node("flag", 0, 20, 132, 88, anchor_min=(0.5, 0.5),
                              anchor_max=(0.5, 0.5), pivot=(0.5, 0.5)))
    cell_flag.image(raycast=False, preserve_aspect=True)
    cell_name = cell.add(Node("nameText", 0, -52, 180, 34, anchor_min=(0.5, 0.5),
                              anchor_max=(0.5, 0.5), pivot=(0.5, 0.5)))
    cell_name.text("", size=22, align=4, color=TEXT_WHITE)
    cell_sel = cell.add(Node("selected", 0, 20, 176, 176, anchor_min=(0.5, 0.5),
                             anchor_max=(0.5, 0.5), pivot=(0.5, 0.5), active=False))
    cell_sel.image(sprite=sprite_guid("cn2-x1_guojiapaihang_qizhi_xuanzhong"), raycast=False)

    # 底部当前选择
    cur = board.add(Node("current", 0, 24, 700, 96, anchor_min=(0.5, 0),
                         anchor_max=(0.5, 0), pivot=(0.5, 0)))
    cur.image(sprite=sprite_guid("cn2-x1_guojiapaihang_wode"), raycast=False)
    cur_flag = cur.add(Node("flag", 34, 0, 108, 72, anchor_min=(0, 0.5),
                            anchor_max=(0, 0.5), pivot=(0, 0.5)))
    cur_flag.image(raycast=False, preserve_aspect=True)
    cur_name = cur.add(Node("nameText", 166, 0, 400, 48, anchor_min=(0, 0.5),
                            anchor_max=(0, 0.5), pivot=(0, 0.5)))
    cur_name.text("", size=32, align=3, color=TEXT_GOLD)
    return root


# ------------------------------------------------------------------ 输出
def write_prefab(root, name):
    os.makedirs(PREFAB_DIR, exist_ok=True)
    out = ["%YAML 1.1", "%TAG !u! tag:unity3d.com,2011:"]
    emit_node(root, out, is_root=True)
    body = "\n".join(x.rstrip("\n") + "\n" for x in out)
    path = os.path.join(PREFAB_DIR, name + ".prefab")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)
    # 写 meta（固定 guid，重复生成稳定）
    meta_path = path + ".meta"
    guid = make_guid(name)
    if not os.path.exists(meta_path):
        with open(meta_path, "w", encoding="utf-8", newline="\n") as f:
            f.write("fileFormatVersion: 2\nguid: %s\nPrefabImporter:\n  externalObjects: {}\n"
                    "  userData: \n  assetBundleName: \n  assetBundleVariant: \n" % guid)
    print("  %-40s %6d bytes" % (name + ".prefab", len(body)))


def main():
    _next_fileid[0] = 114000000000000000
    write_prefab(build_rank_panel(), "CountryRankPanel")
    _next_fileid[0] = 214000000000000000
    write_prefab(build_select_popup(), "CountryFlagSelectPopup")


if __name__ == "__main__":
    main()
