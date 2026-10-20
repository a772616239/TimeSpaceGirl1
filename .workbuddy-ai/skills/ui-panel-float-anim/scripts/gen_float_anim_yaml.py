#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""不依赖 Unity 直接生成 UI 浮动动画的 .anim / .controller，并把 prefab 的 Animation 换成 Animator。

什么时候用这个而不是 C# 生成器：
  Unity 编辑器正开着工程（Temp/UnityLockfile 被占用）⇒ 不能 batchmode，又不想手点菜单时用这个。

为什么能这么干：
  AnimationClip 的 m_ClipBindingConstant.genericBindings[].path 是**层级路径的 zlib.crc32**，
  attribute 是属性名的 crc32（m_AnchoredPosition.y = 538195251，m_LocalScale 走 attribute=3 的枚举）。
  已在本工程用 UI_effect_DailyRechargePanel_normal.anim 的 5 个样本验证 5/5 命中。
  所以只要曲线数据和哈希算对，手写出来的 clip 和 Unity 写出来的完全等价。

用法：
  python3 gen_float_anim_yaml.py --prefab <prefab> --base <资源名前缀> [--dir Assets/Art/UIAni]
                                 [--out-dir /tmp/x] [--no-prefab]

配置：改下面 CURVES 里的两组曲线（(type, path, [(time, value)...])，type 是 scale 或 float）。
"""
import argparse
import os
import random
import re
import uuid
import zlib

POS_ATTR = 'm_AnchoredPosition.y'
POS_ATTR_HASH = zlib.crc32(POS_ATTR.encode())          # 538195251

# ---------------------------------------------------------------- 曲线配置（按面板改）

BASE_TABS_Y = 156.64
BASE_REWARD_Y = -226.18
BASE_BTN_Y = -600.0
BASE_TIPS_Y = -462.0

CURVES = {
    # 弹入：1.0s，不循环
    'start': [
        ('scale', 'frame', [(0, 1), (0.13333334, 1.2), (0.21666667, 0.95), (0.31666667, 1)]),
        ('scale', 'hero', [(0, 1), (0.06666667, 1.3), (0.26666668, 0.95), (0.36666667, 1)]),
        ('scale', 'frame/tabsContent', [(0.30, 0.85), (0.42, 1.06), (0.52, 1)]),
        ('float', 'frame/tabsContent', [(0.30, BASE_TABS_Y + 20), (0.52, BASE_TABS_Y)]),
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
        ('float', 'frame/tabsContent', [(0, BASE_TABS_Y), (1.5, BASE_TABS_Y + 5), (3, BASE_TABS_Y)]),
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


def float_block(path, keys, attribute, class_id=224):
    out = ['  - curve:', '      serializedVersion: 2', '      m_Curve:']
    for t, v in keys:
        out += ['      - serializedVersion: 3', '        time: %s' % num(t),
                '        value: %s' % num(v), '        inSlope: 0', '        outSlope: 0',
                '        tangentMode: 136', '        weightedMode: 0',
                '        inWeight: 0.33333334', '        outWeight: 0.33333334']
    return out + ['      m_PreInfinity: 2', '      m_PostInfinity: 2', '      m_RotationOrder: 4',
                  '    attribute: %s' % attribute, '    path: %s' % path,
                  '    classID: %d' % class_id, '    script: {fileID: 0}']


def build_clip(name, curves, stop, loop):
    scales = [c for c in curves if c[0] == 'scale']
    floats = [c for c in curves if c[0] == 'float']

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

    if floats:
        out.append('  m_FloatCurves:')
        for _, path, keys in floats:
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
    for _, path, _k in floats:
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
    for _, path, keys in floats:
        out += float_block(path, keys, POS_ATTR)

    out += ['  m_EulerEditorCurves: []', '  m_HasGenericRootTransform: 0',
            '  m_HasMotionFloatCurves: 0', '  m_Events: []', '']
    return '\n'.join(out)


META = ('fileFormatVersion: 2\nguid: %s\nNativeFormatImporter:\n  externalObjects: {}\n'
        '  mainObjectFileID: %d\n  userData: \n  assetBundleName: \n  assetBundleVariant: \n')

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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--prefab', required=True)
    ap.add_argument('--base', required=True, help='资源名前缀，如 cn2-X1_UI_XxxPanel_float')
    ap.add_argument('--dir', default='Assets/Art/UIAni')
    ap.add_argument('--out-dir', default=None, help='先写到别处（不指定则直接落到 --dir 和 --prefab）')
    ap.add_argument('--no-prefab', action='store_true', help='只生成资源，不动 prefab')
    args = ap.parse_args()

    out_dir = args.out_dir or args.dir
    os.makedirs(out_dir, exist_ok=True)

    guids = {k: uuid.uuid4().hex for k in ('start', 'normal', 'ctrl')}

    for key in ('start', 'normal'):
        stop, loop = CLIP_META[key]
        name = '%s_%s' % (args.base, key)
        with open(os.path.join(out_dir, name + '.anim'), 'w', encoding='utf-8') as f:
            f.write(build_clip(name, CURVES[key], stop, loop))
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

    anim = re.search(r'^--- !u!111 &(-?\d+)\n(.*?)(?=^--- |\Z)', prefab, flags=re.M | re.S)
    if not anim:
        raise SystemExit('prefab 里没找到 legacy Animation 组件（!u!111），可能已经改过了')

    old_id = anim.group(1)
    # Animator 必须挂在原来那个 Animation 所在的 GameObject 上（别去猜"根节点"，
    # prefab 里第一个 GameObject 不一定是根，实测会挂错）
    owner = re.search(r'm_GameObject: \{fileID: (-?\d+)\}', anim.group(2))
    if not owner:
        raise SystemExit('Animation 组件没有 m_GameObject 字段')
    owner_go = owner.group(1)

    new_id = random.randint(10 ** 18, 9 * 10 ** 18)
    while str(new_id) in prefab:
        new_id = random.randint(10 ** 18, 9 * 10 ** 18)

    prefab = re.sub(r'--- !u!111 &%s\n.*?(?=^--- |\Z)' % old_id,
                    ANIMATOR_BLOCK % (new_id, owner_go, guids['ctrl']),
                    prefab, count=1, flags=re.S | re.M)
    prefab = prefab.replace('- component: {fileID: %s}' % old_id, '- component: {fileID: %d}' % new_id, 1)

    with open(args.prefab, 'w', encoding='utf-8') as f:
        f.write(prefab)
    print('prefab ->', args.prefab, '(Animation -> Animator, id=%d)' % new_id)


if __name__ == '__main__':
    main()
