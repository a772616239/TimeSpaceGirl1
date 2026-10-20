#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ChatPanel 右侧聊天条目：把 time 行和竖向节奏对齐 leftchat。

症状：右边时间（如 00:00）飘在条目顶边、离气泡很远，左边正常。

根因两条：
  1. Chat/rightchat_prefab.prefab 里 time 节点是 690x0、锚点 (0,0)，高度 0；
     leftchat_prefab 是 690x36.75、锚点 (0,1)。高度 0 时文本以节点中心画，
     半个字跑到条目顶边外面，而且不占行高。
  2. ChatPanel.prefab 的 rightchat 实例把 root VLG 的 Padding.Top 覆盖成 0、
     Spacing 覆盖成 28.7（leftchat 用 32 / 10）。于是时间行贴在 0，气泡却被
     「时间行高 + 28.7」顶到 65.7，两者距离是左边的两倍。

改法：prefab 里 time 补成和 left 一样；实例把 padTop/Spacing 恢复成 32/10，
并把头像组（head/headkuang/defultFrame/lv/vip）按同样的 32 平移量回填，
保证头像的绝对位置和气泡的相对关系跟左边一致。
"""
import re
import sys

RIGHT = 'Assets/ManagedResources/Prefabs/UI/Chat/rightchat_prefab.prefab'
PANEL = 'Assets/ManagedResources/Prefabs/UI/Chat/ChatPanel.prefab'
GUID = '9014b4057edde464ea5efd9c83e3de75'

# --- A. 预制体：time 节点对齐 leftchat_prefab ---
TIME_RT = '3442680152508129844'
TIME_GO = '5371949927213227'
PREFAB_EDITS = [
    (TIME_RT, r'^  m_AnchorMax: \{x: 0, y: 0\}$', '  m_AnchorMax: {x: 0, y: 1}', 'time 锚点 -> 左上'),
    (TIME_RT, r'^  m_AnchoredPosition: \{x: 0, y: 0\}$',
     '  m_AnchoredPosition: {x: 495, y: -50.375}', 'time 位置'),
    (TIME_RT, r'^  m_SizeDelta: \{x: 690, y: 0\}$',
     '  m_SizeDelta: {x: 690, y: 36.749996}', 'time 行高 0 -> 36.75'),
]

# --- B. ChatPanel 实例 override ---
INSTANCE_EDITS = [
    ('317319077920553111', 'm_Padding.m_Top', '0', '32', 'root VLG padTop 0 -> 32'),
    ('317319077920553111', 'm_Spacing', '28.7', '10', 'root VLG spacing 28.7 -> 10'),
    ('3442680152508129844', 'm_SizeDelta.y', '37', '36.749996', 'time 行高 37 -> 36.75'),
    ('3442680152508129844', 'm_AnchoredPosition.y', '-18.5', '-50.375', 'time y'),
    ('1117976682983876306', 'm_AnchoredPosition.y', '-97', '-73', 'head y'),
    ('2930212256518810862', 'm_AnchoredPosition.y', '-97.00002', '-73', 'headkuang y'),
    ('7354208196112873373', 'm_AnchoredPosition.y', '-97', '-73', 'defultFrame y'),
    ('5381870771202033856', 'm_AnchoredPosition.y', '-147.40002', '-122', 'lv y'),
    ('5657506639228924867', 'm_AnchoredPosition.y', '-145.40002', '-126', 'vip y'),
    ('3314921427879938186', 'm_AnchoredPosition.y', '-28.7', '-42', 'contentroot y'),
]


def patch_prefab(dry):
    txt = open(RIGHT, encoding='utf-8').read()
    out, ok, fail = txt, 0, []
    for fid, pat, rep, label in PREFAB_EDITS:
        m = re.search(r'^--- !u!\d+ &%s\n(.*?)(?=^--- |\Z)' % fid, txt, re.S | re.M)
        if not m:
            fail.append(f'{fid} {label}: 找不到块')
            continue
        block = m.group(1)
        if len(re.findall(pat, block, re.M)) != 1:
            fail.append(f'{fid} {label}: 命中次数不对')
            continue
        out = out.replace(block, re.sub(pat, rep, block, count=1, flags=re.M), 1)
        print(f'  OK  {label}')
        ok += 1
    if not dry and not fail:
        open(RIGHT, 'w', encoding='utf-8').write(out)
    return ok, fail


def patch_instance(dry):
    txt = open(PANEL, encoding='utf-8').read()
    m = None
    for mm in re.finditer(r'^--- !u!1001 &(-?\d+)\n(.*?)(?=^--- )', txt, re.S | re.M):
        if GUID in mm.group(2):
            m = mm
            break
    assert m, 'ChatPanel 里找不到 rightchat 实例'
    block = m.group(2)
    new_block, ok, fail = block, 0, []
    for fid, prop, old, new, label in INSTANCE_EDITS:
        pat = (r'(- target: \{fileID: %s, guid: %s, type: 3\}\n'
               r'      propertyPath: %s\n      value: )%s(\n)'
               % (fid, GUID, re.escape(prop), re.escape(old)))
        hits = re.findall(pat, new_block)
        if len(hits) != 1:
            fail.append(f'{label}: 命中 {len(hits)} 次')
            continue
        new_block = re.sub(pat, lambda mm: mm.group(1) + new + mm.group(2), new_block, count=1)
        print(f'  OK  {label}')
        ok += 1
    if not dry and not fail:
        open(PANEL, 'w', encoding='utf-8').write(txt.replace(block, new_block, 1))
    return ok, fail


if __name__ == '__main__':
    dry = '--dry-run' in sys.argv
    print('== rightchat_prefab.prefab ==')
    a, fa = patch_prefab(dry)
    print('== ChatPanel.prefab (rightchat 实例) ==')
    b, fb = patch_instance(dry)
    print(f'\n共 {a + b} 处，失败 {len(fa) + len(fb)} 处')
    for x in fa + fb:
        print('  !!', x)
    sys.exit(1 if (fa or fb) else 0)
