#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""不依赖 Unity 直接生成 UI 浮动动画的 .anim / .controller，并把动画挂到 prefab 上。

什么时候用这个而不是 C# 生成器：
  Unity 编辑器正开着工程（Temp/UnityLockfile 被占用、甚至停在 Play mode 里编译被阻塞）⇒
  不能 batchmode、也点不到菜单时用这个。

为什么能这么干：
  AnimationClip 的 m_ClipBindingConstant.genericBindings[].path 是**层级路径的 zlib.crc32**，
  attribute 是属性名的 crc32（m_AnchoredPosition.y = 538195251，m_Color.a = 304273561，
  m_LocalScale 走 attribute=3 的枚举）。
  已在本工程用 UI_effect_DailyRechargePanel_normal.anim 的 5 个样本验证 5/5 命中。
  所以只要曲线数据和哈希算对，手写出来的 clip 和 Unity 写出来的完全等价。

用法：
  # 用脚本内置的首充配方
  python3 gen_float_anim_yaml.py --prefab <prefab> --base <资源名前缀> [--dir Assets/Art/UIAni]
                                 [--out-dir /tmp/x] [--no-prefab]
  # 用外部 JSON 配方（推荐：换面板时只加一个 json，别改本文件）
  python3 gen_float_anim_yaml.py --prefab <prefab> --base <名字> --config <cfg.json>

JSON 配方格式（值可写表达式吗？不行——只写数字）：
  {
    "clips": {
      "start":  {"stop": 1.0, "loop": false, "curves": [["scale", "frame/BG", [[0, 1], [0.13, 1.2]]]]},
      "normal": {"stop": 3.0, "loop": true,  "curves": [["alpha", "Panel", [[0, 0], [0.27, 0.706]]]]}
    }
  }
  curve 类型：scale（缩放，绑 Transform）、float（m_AnchoredPosition.y，绑 RectTransform）、
             alpha（m_Color.a，绑 UnityEngine.UI.Image）

prefab 补丁的三种情况：
  * 根节点还是 legacy Animation（!u!111）→ 换成 Animator（新 fileID），并改 m_Component 里那条
  * 根节点已经是 Animator（!u!95）→ 只换 m_Controller 的 guid，并把 KeepAnimatorStateOnDisable 置 0
  * 根节点既没 Animation 也没 Animator → 新建 Animator 挂上去（往 m_Component 追加一条 + 文件尾追加组件块）
"""
import argparse
import json
import os
import random
import re
import uuid
import zlib

POS_ATTR = 'm_AnchoredPosition.y'
POS_ATTR_HASH = zlib.crc32(POS_ATTR.encode())          # 538195251
COLOR_ATTR = 'm_Color.a'
COLOR_ATTR_HASH = zlib.crc32(COLOR_ATTR.encode())      # 304273561

# UnityEngine.UI.Image 的 MonoScript 引用（本工程 Panel 上挂的就是它；跟着组件的 m_Script 走）
UI_IMAGE_SCRIPT = '{fileID: 11500000, guid: fe87c0e1cc204ed48ad3b37840f39efc, type: 3}'

# ---------------------------------------------------------------- 曲线配置（首充配方，按面板改）

BASE_TABS_Y = 153.5
BASE_REWARD_Y = -226.18
BASE_BTN_Y = -600.0
BASE_TIPS_Y = -462.0

CURVES = {
    # 弹入：1.0s，不循环
    'start': [
        ('scale', 'frame', [(0, 1), (0.13333334, 1.2), (0.21666667, 0.95), (0.31666667, 1)]),
        ('scale', 'hero', [(0, 1), (0.06666667, 1.3), (0.26666668, 0.95), (0.36666667, 1)]),
        # tabsContent 盖在底图的镂空上，只能"放大"，不能缩小/位移，否则底部会漏出背景（见 docs 坑位 7）
        ('scale', 'frame/tabsContent', [(0.30, 1.0), (0.42, 1.08), (0.52, 1.0)]),
        ('scale', 'frame/rewardBg', [(0.40, 0.88), (0.52, 1.05), (0.62, 1)]),
        ('float', 'frame/rewardBg', [(0.40, BASE_REWARD_Y - 18), (0.62, BASE_REWARD_Y)]),
        ('scale', 'frame/rewardBg/rewardDay1', [(0.50, 0), (0.60, 1.12), (0.70, 1)]),
        ('scale', 'frame/rewardBg/rewardDay2', [(0.58, 0), (0.68, 1.12), (0.78, 1)]),
        ('scale', 'frame/rewardBg/rewardDay3', [(0.66, 0), (0.76, 1.12), (0.86, 1)]),
        ('float', 'frame/rechargeBtn', [(0.72, BASE_BTN_Y - 18), (0.96, BASE_BTN_Y)]),
        ('float', 'frame/tips', [(0.78, BASE_TIPS_Y - 18), (0.96, BASE_TIPS_Y)]),
    ],
    # 循环呼吸：3.0s
    'normal': [
        ('scale', 'frame/BG', [(0, 1), (1.5, 1.02), (3, 1)]),
        ('scale', 'frame/rewardBg', [(0, 1), (1.5, 1.015), (3, 1)]),
        ('float', 'frame/rewardBg', [(0, BASE_REWARD_Y), (1.5, BASE_REWARD_Y - 10), (3, BASE_REWARD_Y)]),
        # 这里故意不动 tabsContent：它下面是镂空，上移 5 会让底部缝隙翻倍（原实现就是踩这个坑）
        ('float', 'frame/rechargeBtn', [(0, BASE_BTN_Y), (0.7333333, BASE_BTN_Y + 3),
                                        (1.5, BASE_BTN_Y), (2.3333333, BASE_BTN_Y + 3), (3, BASE_BTN_Y)]),
        ('float', 'frame/tips', [(0, BASE_TIPS_Y), (1.5, BASE_TIPS_Y - 3), (3, BASE_TIPS_Y)]),
    ],
}

CLIP_META = {          # 时长 / 是否循环
    'start': (1.0, False),
    'normal': (3.0, True),
}

# ---------------------------------------------------------------- 生成


def num(x):
    if abs(x - round(x)) < 1e-9:
        return str(int(round(x)))
    return ('%.6f' % x).rstrip('0').rstrip('.')


def path_hash(path):
    return zlib.crc32(path.encode()) & 0xFFFFFFFF


def scale_block(path, keys):
    out = ['  - curve:', '      serializedVersion: 2', '      m_Curve:']
    for t, v in keys:
        s = num(v)
        out += ['      - serializedVersion: 3', '        time: %s' % num(t),
                '        value: {x: %s, y: %s, z: %s}' % (s, s, s),
                '        inSlope: {x: 0, y: 0, z: 0}', '        outSlope: {x: 0, y: 0, z: 0}',
                '        tangentMode: 0', '        weightedMode: 0',
                '        inWeight: {x: 0.33333334, y: 0.33333334, z: 0.33333334}',
                '        outWeight: {x: 0.33333334, y: 0.33333334, z: 0.33333334}']
    return out + ['      m_PreInfinity: 2', '      m_PostInfinity: 2', '      m_RotationOrder: 4',
                  '    path: %s' % path]


def float_block(path, keys, attribute, class_id=224, script='{fileID: 0}'):
    out = ['  - curve:', '      serializedVersion: 2', '      m_Curve:']
    for t, v in keys:
        out += ['      - serializedVersion: 3', '        time: %s' % num(t),
                '        value: %s' % num(v), '        inSlope: 0', '        outSlope: 0',
                '        tangentMode: 136', '        weightedMode: 0',
                '        inWeight: 0.33333334', '        outWeight: 0.33333334']
    return out + ['      m_PreInfinity: 2', '      m_PostInfinity: 2', '      m_RotationOrder: 4',
                  '    attribute: %s' % attribute, '    path: %s' % path,
                  '    classID: %d' % class_id, '    script: %s' % script]


def build_clip(name, curves, stop, loop):
    scales = [c for c in curves if c[0] == 'scale']
    others = [c for c in curves if c[0] != 'scale']

    out = ['%YAML 1.1', '%TAG !u! tag:unity3d.com,2011:', '--- !u!74 &7400000', 'AnimationClip:',
           '  m_ObjectHideFlags: 0', '  m_CorrespondingSourceObject: {fileID: 0}',
           '  m_PrefabInstance: {fileID: 0}', '  m_PrefabAsset: {fileID: 0}',
           '  m_Name: %s' % name, '  serializedVersion: 6', '  m_Legacy: 0', '  m_Compressed: 0',
           '  m_UseHighQualityCurve: 1', '  m_RotationCurves: []', '  m_CompressedRotationCurves: []',
           '  m_EulerCurves: []', '  m_PositionCurves: []']

    if scales:
        out.append('  m_ScaleCurves:')
        for _, path, keys in scales:
            out += scale_block(path, keys)
    else:
        out.append('  m_ScaleCurves: []')

    if others:
        out.append('  m_FloatCurves:')
        for kind, path, keys in others:
            if kind == 'alpha':
                out += float_block(path, keys, COLOR_ATTR, 114, UI_IMAGE_SCRIPT)
            else:
                out += float_block(path, keys, POS_ATTR)
    else:
        out.append('  m_FloatCurves: []')

    out += ['  m_PPtrCurves: []', '  m_SampleRate: 30', '  m_WrapMode: 0', '  m_Bounds:',
            '    m_Center: {x: 0, y: 0, z: 0}', '    m_Extent: {x: 0, y: 0, z: 0}',
            '  m_ClipBindingConstant:', '    genericBindings:']

    # 顺序必须与曲线顺序一致：先 m_ScaleCurves 再 m_FloatCurves
    for _, path, _k in scales:
        out += ['    - serializedVersion: 2', '      path: %d' % path_hash(path), '      attribute: 3',
                '      script: {fileID: 0}', '      typeID: 4', '      customType: 0', '      isPPtrCurve: 0']
    for kind, path, _k in others:
        if kind == 'alpha':
            out += ['    - serializedVersion: 2', '      path: %d' % path_hash(path),
                    '      attribute: %d' % COLOR_ATTR_HASH, '      script: %s' % UI_IMAGE_SCRIPT,
                    '      typeID: 114', '      customType: 0', '      isPPtrCurve: 0']
        else:
            out += ['    - serializedVersion: 2', '      path: %d' % path_hash(path),
                    '      attribute: %d' % POS_ATTR_HASH, '      script: {fileID: 0}',
                    '      typeID: 224', '      customType: 28', '      isPPtrCurve: 0']
    out.append('    pptrCurveMapping: []')

    out += ['  m_AnimationClipSettings:', '    serializedVersion: 2',
            '    m_AdditiveReferencePoseClip: {fileID: 0}', '    m_AdditiveReferencePoseTime: 0',
            '    m_StartTime: 0', '    m_StopTime: %s' % num(stop), '    m_OrientationOffsetY: 0',
            '    m_Level: 0', '    m_CycleOffset: 0', '    m_HasAdditiveReferencePose: 0',
            '    m_LoopTime: %d' % (1 if loop else 0), '    m_LoopBlend: 0',
            '    m_LoopBlendOrientation: 0', '    m_LoopBlendPositionY: 0',
            '    m_LoopBlendPositionXZ: 0', '    m_KeepOriginalOrientation: 0',
            '    m_KeepOriginalPositionY: 1', '    m_KeepOriginalPositionXZ: 0',
            '    m_HeightFromFeet: 0', '    m_Mirror: 0', '  m_EditorCurves:']

    for _, path, keys in scales:            # 编辑器曲线：缩放拆 x/y/z
        for axis in ('x', 'y', 'z'):
            out += float_block(path, keys, 'm_LocalScale.%s' % axis)
    for kind, path, keys in others:
        if kind == 'alpha':
            out += float_block(path, keys, COLOR_ATTR, 114, UI_IMAGE_SCRIPT)
        else:
            out += float_block(path, keys, POS_ATTR)

    out += ['  m_EulerEditorCurves: []', '  m_HasGenericRootTransform: 0',
            '  m_HasMotionFloatCurves: 0', '  m_Events: []', '']
    return '\n'.join(out)


META = ('fileFormatVersion: 2\nguid: %s\nNativeFormatImporter:\n  externalObjects: {}\n'
        '  mainObjectFileID: %d\n  userData: \n  assetBundleName: \n  assetBundleVariant: \n')


def _read_meta_guid(meta_path):
    """读已有 .meta 的 guid（没有就返回 None）。"""
    if not os.path.exists(meta_path):
        return None
    with open(meta_path, encoding='utf-8') as f:
        m = re.search(r'^guid: (\w+)$', f.read(), flags=re.M)
    return m.group(1) if m else None

ANIMATOR_BLOCK = '''--- !u!95 &%d
Animator:
  serializedVersion: 5
  m_ObjectHideFlags: 0
  m_CorrespondingSourceObject: {fileID: 0}
  m_PrefabInstance: {fileID: 0}
  m_PrefabAsset: {fileID: 0}
  m_GameObject: {fileID: %s}
  m_Enabled: 1
  m_Avatar: {fileID: 0}
  m_Controller: {fileID: 9100000, guid: %s, type: 2}
  m_CullingMode: 0
  m_UpdateMode: 0
  m_ApplyRootMotion: 0
  m_LinearVelocityBlending: 0
  m_StabilizeFeet: 0
  m_WarningMessage: 
  m_HasTransformHierarchy: 1
  m_AllowConstantClipSamplingOptimization: 1
  m_KeepAnimatorStateOnDisable: 0
  m_WriteDefaultValuesOnDisable: 0

'''


def load_config(path):
    with open(path, encoding='utf-8') as f:
        cfg = json.load(f)
    curves, meta = {}, {}
    for key in ('start', 'normal'):
        node = cfg['clips'][key]
        curves[key] = [(c[0], c[1], [tuple(k) for k in c[2]]) for c in node['curves']]
        meta[key] = (float(node['stop']), bool(node['loop']))
    return curves, meta


def _parse_tree(prefab_text):
    """解析 prefab 层级：返回 (names, rt_of_go, father, rt2go, animators)。

    animators 是 [(match, go_id)]，match 对应整块 !u!95。
    只用来选"挂在哪个 GameObject 上"，不追求完整反序列化。
    """
    names, rt_of_go, father, rt2go, animators = {}, {}, {}, {}, []
    for m in re.finditer(r'^--- !u!(\d+) &(-?\d+)\n(.*?)(?=^--- |\Z)',
                         prefab_text, flags=re.M | re.S):
        cls, cid, blk = m.group(1), m.group(2), m.group(3)
        go = re.search(r'^  m_GameObject: \{fileID: (-?\d+)\}', blk, flags=re.M)
        if cls == '1':
            nm = re.search(r'^  m_Name: (.*)$', blk, flags=re.M)
            names[cid] = nm.group(1).strip() if nm else ''
        elif cls == '224':
            f = re.search(r'^  m_Father: \{fileID: (-?\d+)\}', blk, flags=re.M)
            if go:
                rt_of_go[go.group(1)] = cid
                rt2go[cid] = go.group(1)
            father[cid] = f.group(1) if f else '0'
        elif cls == '95':
            animators.append((m, go.group(1) if go else None))
    return names, rt_of_go, father, rt2go, animators


def _go_path(go_id, names, rt_of_go, father, rt2go):
    """GameObject 的层级路径（斜杠分隔，含自身名字）。"""
    parts, rt, guard = [], rt_of_go.get(go_id), 0
    while rt and guard < 64:
        parts.append(names.get(rt2go.get(rt), '?'))
        rt = father.get(rt, '0') if father.get(rt, '0') != '0' else None
        guard += 1
    return '/'.join(reversed(parts))


def check_paths(prefab_text, anim_go, paths):
    """校验每条曲线路径能否从 animator 所在节点解析出来；返回解析不到的路径列表。"""
    names, rt_of_go, father, rt2go, _ = _parse_tree(prefab_text)
    all_paths = {_go_path(g, names, rt_of_go, father, rt2go) for g in rt_of_go}
    base = _go_path(anim_go, names, rt_of_go, father, rt2go)
    missing = []
    for p in paths:
        full = p if base in ('', '?') else base + '/' + p
        if full not in all_paths:
            missing.append((p, full))
    return base, missing


def root_go_id(prefab_text):
    """prefab 根节点的 GameObject fileID（m_Father == 0 的那条 RectTransform 的 m_GameObject）。"""
    names, rt_of_go, father, rt2go, _ = _parse_tree(prefab_text)
    for rt, f in father.items():
        if f == '0' and rt in rt2go:
            return rt2go[rt]
    raise SystemExit('找不到 prefab 根节点')


def resolve_target_go(prefab_text, animator_go=None):
    """动画锚点该是哪个 GameObject：显式 --animator-go 优先，否则根节点。

    🔴 绝不能"取文件里第一个 !u!111 / !u!95"：prefab 文件里组件块的排列顺序与层级无关，
    子面板自带的 Animation / 按钮自带的 CommonButton Animator 常常排在前面。
    锚点错了曲线会全部 Missing（Unity 不报错），所以锚点只由层级决定。
    """
    if not animator_go:
        return root_go_id(prefab_text)
    names, rt_of_go, father, rt2go, _ = _parse_tree(prefab_text)
    want = animator_go.strip('/')
    for go in rt_of_go:
        if _go_path(go, names, rt_of_go, father, rt2go) == want:
            return go
    raise SystemExit('--animator-go=%s 找不到该节点' % want)


def _component_on(prefab_text, go_id, cls):
    """找挂在指定 GameObject 上的某个组件块（cls 是 YAML classID）。"""
    for m in re.finditer(r'^--- !u!%s &(-?\d+)\n(.*?)(?=^--- |\Z)' % cls,
                         prefab_text, flags=re.M | re.S):
        owner = re.search(r'^  m_GameObject: \{fileID: (-?\d+)\}', m.group(2), flags=re.M)
        if owner and owner.group(1) == go_id:
            return m
    return None


def patch_prefab(prefab_text, ctrl_guid, animator_go=None):
    """把动画挂到 prefab：目标节点有 legacy Animation → 换成 Animator；
    目标节点已有 Animator → 只换 controller；两者都没有 → 新增 Animator。"""
    go_id = resolve_target_go(prefab_text, animator_go)

    anim = _component_on(prefab_text, go_id, '111')
    if anim:
        old_id = anim.group(1)
        new_id = random.randint(10 ** 18, 9 * 10 ** 18)
        while str(new_id) in prefab_text:
            new_id = random.randint(10 ** 18, 9 * 10 ** 18)

        prefab_text = re.sub(r'--- !u!111 &%s\n.*?(?=^--- |\Z)' % old_id,
                             ANIMATOR_BLOCK % (new_id, go_id, ctrl_guid),
                             prefab_text, count=1, flags=re.S | re.M)
        prefab_text = prefab_text.replace('- component: {fileID: %s}' % old_id,
                                          '- component: {fileID: %d}' % new_id, 1)
        return prefab_text, 'Animation -> Animator (id=%d)' % new_id

    animator = _component_on(prefab_text, go_id, '95')
    if not animator:
        return add_animator(prefab_text, ctrl_guid, go_id)

    block = animator.group(2)
    new_block, n = re.subn(r'm_Controller: \{fileID: 9100000, guid: \w+, type: 2\}',
                           'm_Controller: {fileID: 9100000, guid: %s, type: 2}' % ctrl_guid,
                           block, count=1)
    if n != 1:
        raise SystemExit('Animator 块里没找到 m_Controller 引用')
    # 面板是缓存复用的，必须禁用后重置回默认状态，否则第二次打开不再弹入
    new_block = re.sub(r'm_KeepAnimatorStateOnDisable: \d',
                       'm_KeepAnimatorStateOnDisable: 0', new_block, count=1)
    prefab_text = prefab_text[:animator.start(2)] + new_block + prefab_text[animator.end(2):]

    names, rt_of_go, father, rt2go, _ = _parse_tree(prefab_text)
    where = _go_path(go_id, names, rt_of_go, father, rt2go)
    return prefab_text, 'Animator(现有) 换 controller -> guid=%s @ %s' % (ctrl_guid, where)


def add_animator(prefab_text, ctrl_guid, go_id):
    """目标节点上既没 legacy Animation 也没 Animator 时，新建一个挂上去。"""
    new_id = random.randint(10 ** 18, 9 * 10 ** 18)
    while str(new_id) in prefab_text:
        new_id = random.randint(10 ** 18, 9 * 10 ** 18)

    # 往该 GameObject 的 m_Component 列表尾部追加一条（顺序不影响引用解析）
    m = re.search(r'^--- !u!1 &%s\n(.*?)(?=^--- |\Z)' % go_id, prefab_text, flags=re.M | re.S)
    if not m:
        raise SystemExit('找不到目标 GameObject 块：%s' % go_id)
    body = m.group(1)
    comps = list(re.finditer(r'^  - component: \{fileID: -?\d+\}\n', body, flags=re.M))
    if not comps:
        raise SystemExit('目标 GameObject 没有 m_Component 列表')
    last = comps[-1]
    body_new = body[:last.end()] + '  - component: {fileID: %d}\n' % new_id + body[last.end():]
    prefab_text = prefab_text[:m.start(1)] + body_new + prefab_text[m.end(1):]

    if not prefab_text.endswith('\n'):
        prefab_text += '\n'
    prefab_text += ANIMATOR_BLOCK % (new_id, go_id, ctrl_guid)

    names, rt_of_go, father, rt2go, _ = _parse_tree(prefab_text)
    where = _go_path(go_id, names, rt_of_go, father, rt2go)
    return prefab_text, '新增 Animator(id=%d, ctrl=%s) @ %s' % (new_id, ctrl_guid, where)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--prefab', required=True)
    ap.add_argument('--base', required=True, help='资源名前缀，如 cn2-X1_UI_XxxPanel_float')
    ap.add_argument('--config', default=None, help='JSON 配方（不传则用本文件内置的首充配方）')
    ap.add_argument('--dir', default='Assets/Art/UIAni')
    ap.add_argument('--out-dir', default=None, help='先写到别处（不指定则直接落到 --dir 和 --prefab）')
    ap.add_argument('--no-prefab', action='store_true', help='只生成资源，不动 prefab')
    ap.add_argument('--animator-go', default=None,
                    help='动画挂到哪个节点（相对 prefab 根的路径，默认根节点）；曲线 path 相对它解析')
    args = ap.parse_args()

    curves, clip_meta = load_config(args.config) if args.config else (CURVES, CLIP_META)

    out_dir = args.out_dir or args.dir
    os.makedirs(out_dir, exist_ok=True)

    # 已有 .meta 就沿用它的 guid：重跑生成器只该改内容，不该换 guid
    # （guid 一变，prefab 里那条 m_Controller 就得跟着换，等于把一次配方微调变成一次引用搬家）
    guids = {}
    for key, suffix in (('start', '_start.anim'), ('normal', '_normal.anim'), ('ctrl', '.controller')):
        meta_path = os.path.join(out_dir, args.base + suffix + '.meta')
        guids[key] = _read_meta_guid(meta_path) or uuid.uuid4().hex

    for key in ('start', 'normal'):
        stop, loop = clip_meta[key]
        name = '%s_%s' % (args.base, key)
        with open(os.path.join(out_dir, name + '.anim'), 'w', encoding='utf-8') as f:
            f.write(build_clip(name, curves[key], stop, loop))
        with open(os.path.join(out_dir, name + '.anim.meta'), 'w', encoding='utf-8') as f:
            f.write(META % (guids[key], 7400000))

    # controller：克隆本工程每日首充那个（结构最稳），只换名字与 motion
    tpl = os.path.join('Assets/Art/EffectsOld/Animation/UI_effect_DailyRechargePanel.controller')
    with open(tpl, encoding='utf-8') as f:
        ctrl = f.read()
    ctrl = (ctrl.replace('m_Name: UI_effect_DailyRechargePanel_start', 'm_Name: start')
                .replace('m_Name: UI_effect_DailyRechargePanel_normal', 'm_Name: normal')
                .replace('m_Name: UI_effect_DailyRechargePanel', 'm_Name: ' + args.base)
                .replace('guid: e6c87232ffb6ad24881b611706d7a3e3', 'guid: ' + guids['start'])
                .replace('guid: 2ecf235ef2c6cc54ca107d1dc2562e41', 'guid: ' + guids['normal']))
    with open(os.path.join(out_dir, args.base + '.controller'), 'w', encoding='utf-8') as f:
        f.write(ctrl)
    with open(os.path.join(out_dir, args.base + '.controller.meta'), 'w', encoding='utf-8') as f:
        f.write(META % (guids['ctrl'], 9100000))

    print('clips  ->', args.base + '_start.anim / _normal.anim')
    print('guids  -> start=%s normal=%s ctrl=%s' % (guids['start'], guids['normal'], guids['ctrl']))

    if args.no_prefab:
        return

    with open(args.prefab, encoding='utf-8') as f:
        prefab = f.read()

    anim_go = resolve_target_go(prefab, args.animator_go)
    prefab, how = patch_prefab(prefab, guids['ctrl'], args.animator_go)

    # 🔴 打完补丁必须校验：曲线 path 是相对 Animator 所在节点解析的，
    # 挂错节点时 Unity 不报错，只是全部变成 Missing。
    all_paths = sorted({c[1] for k in ('start', 'normal') for c in curves[k]})
    base, missing = check_paths(prefab, anim_go, all_paths)
    if missing:
        raise SystemExit('曲线路径解析不到（锚点 %s）：\n  %s'
                         % (base, '\n  '.join('%s -> %s' % x for x in missing)))
    print('bindings ok -> 锚点 %s，%d 条路径全部可解析' % (base, len(all_paths)))

    with open(args.prefab, 'w', encoding='utf-8') as f:
        f.write(prefab)
    print('prefab ->', args.prefab, '(%s)' % how)


if __name__ == '__main__':
    main()
