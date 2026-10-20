#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""打印 UI prefab 的层级树：节点名 / anchoredPosition / sizeDelta / 组件（含脚本名、Animator 控制器）。

给「UI 面板加浮动动画」时用来：
  1) 确认目标节点的层级路径（曲线按路径绑定，大小写敏感）
  2) 取 anchoredPosition.y 作为 baseY（曲线写的是绝对值）
  3) 一眼看出目标节点有没有自带 Animator / LayoutGroup / PlayFlyAnim（决定能不能写位置和缩放）

用法：
  python3 dump_prefab_tree.py <prefab 路径> [--depth 2] [--name 关键字] [--no-scripts]

输出示例：
  frame                    pos(0,-215)   size(0,180)        [RectTransform, CanvasRenderer, PlayFlyAnim]
    rewardBg               pos(0,-226.2) size(1080,355.9)   [RectTransform, CanvasRenderer, HorizontalLayoutGroup]
      rewardDay1           pos(0,0)      size(326,305)      [RectTransform, CanvasRenderer, Image]
"""
import os
import re
import sys
import argparse

CLS = {
    1: 'GameObject', 4: 'Transform', 224: 'RectTransform', 222: 'CanvasRenderer',
    223: 'Canvas', 225: 'CanvasGroup', 95: 'Animator', 111: 'Animation',
    114: 'MonoBehaviour', 198: 'ParticleSystem', 199: 'ParticleSystemRenderer',
    212: 'SpriteRenderer', 20: 'Camera', 82: 'AudioSource', 33: 'MeshRenderer',
    58: 'CircleCollider2D', 61: 'BoxCollider2D', 114: 'MonoBehaviour',
}

# 只放已在本工程核对过的 guid（其余靠扫描 Library/PackageCache 解析，不要凭记忆乱填）
BUILTIN = {
    'fe87c0e1cc204ed48ad3b37840f39efc': 'Image',
    '4e29b1a8efbd4b44bb3f3716e73f07ff': 'Button',
    '30649d3a9faa99c48a7b1166b86bf2a0': 'HorizontalLayoutGroup',
}


def parse_docs(text):
    """把 Unity YAML 拆成 {fileID: (classID, body)}。"""
    objs = {}
    for m in re.finditer(r'^--- !u!(\d+) &(-?\d+)\n(.*?)(?=^--- |\Z)', text, flags=re.M | re.S):
        objs[m.group(2)] = (int(m.group(1)), m.group(3))
    return objs


def field(body, key):
    m = re.search(r'^  %s: (.*)$' % re.escape(key), body, flags=re.M)
    return m.group(1).strip() if m else None


def vec(raw):
    if not raw:
        return '?'
    nums = re.findall(r'[-\d.]+', raw)
    return '(' + ','.join('%g' % float(n) for n in nums[:2]) + ')' if len(nums) >= 2 else raw


def build_guid_index(repo_root, exts=('.cs.meta', '.controller.meta'), force=False):
    """guid -> 相对路径（脚本 + 控制器 + UGUI 组件）。结果缓存 1 小时。

    ⚠ 缓存会「过期成假信息」：刚生成的 controller/clip 在缓存里查不到，界面会显示成
    `Animator(?)` 或 `MB:xxxxxxx`。看到这种就加 --refresh 重建（别以为是 guid 写错了）。
    """
    import glob
    import hashlib
    import json
    import time

    cache = os.path.join('/tmp', 'ui_float_guid_index_%s.json' % hashlib.md5(repo_root.encode()).hexdigest()[:8])
    if not force and os.path.exists(cache) and time.time() - os.path.getmtime(cache) < 3600:
        try:
            with open(cache, encoding='utf-8') as f:
                return json.load(f)
        except (OSError, ValueError):
            pass

    index = {}
    roots = [os.path.join(repo_root, 'Assets')]
    roots += glob.glob(os.path.join(repo_root, 'Library', 'PackageCache', 'com.unity.ugui*'))
    roots += glob.glob(os.path.join(repo_root, 'Packages', 'com.unity.ugui*'))
    for root in roots:
        if not os.path.isdir(root):
            continue
        for dirpath, _, filenames in os.walk(root):
            for fn in filenames:
                if not fn.endswith(exts):
                    continue
                full = os.path.join(dirpath, fn)
                try:
                    with open(full, encoding='utf-8', errors='replace') as f:
                        head = f.read(200)
                except OSError:
                    continue
                m = re.search(r'guid: (\w+)', head)
                if m:
                    index[m.group(1)] = os.path.relpath(full[: -len('.meta')], repo_root)

    try:
        with open(cache, 'w', encoding='utf-8') as f:
            json.dump(index, f)
    except OSError:
        pass
    return index


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('prefab')
    ap.add_argument('--depth', type=int, default=2)
    ap.add_argument('--name', default=None, help='只展开名字包含该关键字的子树')
    ap.add_argument('--no-scripts', action='store_true', help='不解析脚本/控制器名（更快）')
    ap.add_argument('--refresh', action='store_true', help='重建 guid 索引（刚生成的 controller 查不到时用）')
    args = ap.parse_args()

    with open(args.prefab, encoding='utf-8', errors='replace') as f:
        objs = parse_docs(f.read())

    repo_root = os.getcwd()
    guid_index = {} if args.no_scripts else build_guid_index(repo_root, force=args.refresh)

    # GameObject 名 / 组件归属
    names, comps = {}, {}
    for fid, (cls, body) in objs.items():
        if cls == 1:
            names[fid] = field(body, 'm_Name') or '(unnamed)'
        else:
            go = re.search(r'm_GameObject: \{fileID: (-?\d+)\}', body)
            if go:
                comps.setdefault(go.group(1), []).append((cls, fid, body))

    # Transform 树
    tr = {}
    for fid, (cls, body) in objs.items():
        if cls in (4, 224):
            go = re.search(r'm_GameObject: \{fileID: (-?\d+)\}', body)
            father = re.search(r'm_Father: \{fileID: (-?\d+)\}', body)
            tr[fid] = {
                'go': go.group(1) if go else None,
                'father': father.group(1) if father else '0',
                'children': re.findall(r'- \{fileID: (-?\d+)\}', body),
                'body': body,
            }
    go2tr = {v['go']: k for k, v in tr.items() if v['go']}
    roots = [k for k, v in tr.items() if v['father'] == '0' or v['father'] not in tr]

    def describe(cls, body):
        label = CLS.get(cls, 'cls%d' % cls)
        if cls == 114:
            guid = re.search(r'm_Script: \{fileID: \d+, guid: (\w+)', body)
            if guid:
                g = guid.group(1)
                path = guid_index.get(g)
                if path:
                    label = os.path.splitext(os.path.basename(path))[0]
                elif g in BUILTIN:
                    label = BUILTIN[g]
                else:
                    label = 'MB:' + g[:8]
        elif cls == 95:
            guid = re.search(r'm_Controller: \{fileID: \d+, guid: (\w+)', body)
            if guid:
                path = guid_index.get(guid.group(1))
                label = 'Animator(' + (os.path.basename(path) if path else guid.group(1)[:8]) + ')'
        return label

    def walk(tid, depth):
        t = tr.get(tid)
        if not t:
            return
        go = t['go']
        node_name = names.get(go, '?')
        body = t['body']
        labels = [describe(c, b) for c, _, b in comps.get(go, []) if c not in (1, 4, 224)]
        print('%s%-26s pos%-14s size%-16s [%s]' % (
            '  ' * depth, node_name, vec(field(body, 'm_AnchoredPosition')),
            vec(field(body, 'm_SizeDelta')), ', '.join(labels)))
        if depth >= args.depth:
            return
        for child in t['children']:
            walk(child, depth + 1)

    if args.name:
        # 只打印名字命中的节点及其子树（深度从命中节点重新算）
        targets = [tid for tid, t in tr.items() if args.name.lower() in names.get(t['go'], '').lower()]
        for tid in targets:
            walk(tid, 0)
        return

    for root in roots:
        walk(root, 0)


if __name__ == '__main__':
    sys.exit(main())
