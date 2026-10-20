#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给「UI 面板加浮动动画」做开工前体检：把"能不能写位置/缩放/透明度"自动判出来。

判据全部来自 prefab 本身（不用打开 Unity）：

| 标记 | 判据 | 后果 |
|---|---|---|
| INACTIVE | `GameObject.m_IsActive: 0` | 曲线永不求值；若写了 `0 → 1` 的弹入，运行时被 SetActive 打开会卡在 0 |
| MASK | Image 无 sprite（`m_Sprite: {fileID: 0}`）+ 锚点四边拉伸 | 全屏底色，缩放会四周露边 ⇒ 只能写 `m_Color.a` |
| OWN_ANIM | 该节点自带 `!u!95 Animator`（按钮常见 CommonButton） | 父子两级写同一属性结果不可靠 ⇒ 只写它 clip 没写的通道 |
| LEGACY | 该节点自带 legacy `!u!111 Animation` | 同上，且**绝不能选它当动画锚点**（文件里第一个 111 往往在子页上） |
| LAYOUT_CHILD | 父节点挂 H/V/GridLayoutGroup | 位置每帧被重算 ⇒ 只写 scale |
| LAYOUT | 自身挂 LayoutGroup | 同上（自身的 anchoredPosition 也被接管） |
| SCROLL_DESC | 祖先里有 ScrollRect | 位置由滚动/布局写 ⇒ 不写位置 |
| PLAYFLY | 挂 `PlayFlyAnim` | DOTween 在写位置 ⇒ 不写位置 |
| CODE_POS | `--lua` 里出现 `<名字>.transform.localPosition =` 之类 | 代码会覆盖 ⇒ 插空容器再写位移 |

用法：
  python3 audit_panel.py <prefab> [--depth 3] [--lua XxxPanel.lua] [--only-risky] [--no-scripts]

示例（只看有风险的节点）：
  python3 audit_panel.py Assets/ManagedResources/Prefabs/UI/Expert/ExpertPanel.prefab \\
      --depth 4 --lua Assets/ManagedResources/~Lua/Modules/Expert/ExpertPanel.lua --only-risky
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dump_prefab_tree as dpt  # noqa: E402  复用 YAML/guid 解析

# 位置由父级布局组接管的组件
POS_LAYOUT = {'HorizontalLayoutGroup', 'VerticalLayoutGroup', 'GridLayoutGroup'}
SIZE_LAYOUT = {'ContentSizeFitter', 'AspectRatioFitter', 'LayoutElement'}
SCROLL = {'ScrollRect'}

FLAG_ORDER = ['INACTIVE', 'MASK', 'OWN_ANIM', 'LEGACY', 'LAYOUT',
              'LAYOUT_CHILD', 'SCROLL_DESC', 'PLAYFLY', 'CODE_POS']

ADVICE = {
    'INACTIVE': '不写 start 曲线（未激活），只能写 normal',
    'MASK': '无 sprite 的四边拉伸实色块 ⇒ 默认只写 m_Color.a，不写缩放',
    'OWN_ANIM': '只写它 clip 没写的通道（按钮一般只写位置）',
    'LEGACY': '别当锚点；通道同 OWN_ANIM',
    'LAYOUT': '位置被布局组接管 ⇒ 只写 scale',
    'LAYOUT_CHILD': '父节点有布局组 ⇒ 只写 scale，不写位置',
    'SCROLL_DESC': '在 ScrollRect 下 ⇒ 不写位置',
    'PLAYFLY': 'PlayFlyAnim 在写位置 ⇒ 只写 scale/alpha',
    'CODE_POS': 'Lua 写死位置 ⇒ 插空容器承接位移，或只写 scale',
}


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def vec_of(body, key):
    m = re.search(r'^  %s: \{x: ([-\d.e]+), y: ([-\d.e]+)' % key, body, flags=re.M)
    return (num(m.group(1)), num(m.group(2))) if m else (None, None)


def color_of(body):
    m = re.search(r'^  m_Color: \{r: ([-\d.e]+), g: ([-\d.e]+), b: ([-\d.e]+), a: ([-\d.e]+)\}',
                  body, flags=re.M)
    return tuple(num(x) for x in m.groups()) if m else None


def script_name(body, guid_index):
    g = re.search(r'm_Script: \{fileID: \d+, guid: (\w+)', body)
    if not g:
        return None
    guid = g.group(1)
    path = guid_index.get(guid)
    if path:
        return os.path.basename(path)[:-3] if path.endswith('.cs') else os.path.basename(path)
    return dpt.BUILTIN.get(guid)


def scan_lua(paths):
    """从 Lua 里捞出「写死位置」的节点名，用于 CODE_POS。"""
    names = set()
    pat = re.compile(r'([A-Za-z_]\w*)\s*\.\s*(?:transform\s*\.\s*)?'
                     r'(localPosition|anchoredPosition|anchoredPosition3D|localScale|SetActive)')
    for p in paths:
        try:
            with open(p, encoding='utf-8', errors='replace') as f:
                for line in f:
                    if line.lstrip().startswith('--'):
                        continue
                    m = pat.search(line)
                    if m:
                        names.add(m.group(1))
        except OSError:
            pass
    return names


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('prefab')
    ap.add_argument('--depth', type=int, default=3)
    ap.add_argument('--lua', action='append', default=[], help='面板 Lua，用来发现代码写死的位置')
    ap.add_argument('--only-risky', action='store_true')
    ap.add_argument('--no-scripts', action='store_true', help='不解析脚本名（跳过 15s 的 guid 索引）')
    ap.add_argument('--refresh', action='store_true', help='重建 guid 索引（刚生成的 controller 查不到时用）')
    args = ap.parse_args()

    with open(args.prefab, encoding='utf-8', errors='replace') as f:
        objs = dpt.parse_docs(f.read())

    guid_index = {} if args.no_scripts else dpt.build_guid_index(os.getcwd(), force=args.refresh)
    lua_names = scan_lua(args.lua)

    names, comps = {}, {}
    for fid, (cls, body) in objs.items():
        if cls == 1:
            names[fid] = dpt.field(body, 'm_Name') or '(unnamed)'
        else:
            go = re.search(r'm_GameObject: \{fileID: (-?\d+)\}', body)
            if go:
                comps.setdefault(go.group(1), []).append((cls, fid, body))

    tr = {}
    for fid, (cls, body) in objs.items():
        if cls in (4, 224):
            go = re.search(r'm_GameObject: \{fileID: (-?\d+)\}', body)
            fa = re.search(r'm_Father: \{fileID: (-?\d+)\}', body)
            tr[fid] = {'go': go.group(1) if go else None,
                       'father': fa.group(1) if fa else '0',
                       'children': re.findall(r'- \{fileID: (-?\d+)\}', body),
                       'body': body}
    rt_of_go = {v['go']: k for k, v in tr.items() if v['go']}
    roots = [k for k, v in tr.items() if v['father'] == '0' or v['father'] not in tr]

    comp_names = {}
    for go, items in comps.items():
        out = []
        for cls, _fid, body in items:
            if cls == 114:
                out.append(script_name(body, guid_index) or 'MonoBehaviour')
            elif cls == 95:
                g = re.search(r'm_Controller: \{fileID: \d+, guid: (\w+)', body)
                out.append('Animator(%s)' % (os.path.basename(guid_index.get(g.group(1), '?'))
                                             if g else '?'))
            elif cls == 111:
                out.append('Animation(legacy)')
            elif cls not in (1, 4, 224, 222):
                out.append(dpt.CLS.get(cls, 'cls%d' % cls))
        comp_names[go] = out

    def path_of(rt, cache={}):
        if rt in cache:
            return cache[rt]
        t = tr[rt]
        fa = t['father']
        name = names.get(t['go'], '?')
        cache[rt] = name if fa not in tr else path_of(fa) + '/' + name
        return cache[rt]

    def anc(rt, key):
        cur = tr[rt]['father']
        while cur in tr:
            if key <= set(comp_names.get(tr[cur]['go'], [])):
                return True
            cur = tr[cur]['father']
        return False

    ctx = {'anchor': None}

    def flags_of(rt):
        go = tr[rt]['go']
        body = tr[rt]['body']
        cs = comp_names.get(go, [])
        out = set()
        if (dpt.field(objs[go][1], 'm_IsActive') or '1') == '0':
            out.add('INACTIVE')
        # 锚点自己当然有 Animator，不算风险
        if any(c.startswith('Animator(') for c in cs) and go != ctx['anchor']:
            out.add('OWN_ANIM')
        if 'Animation(legacy)' in cs:
            out.add('LEGACY')
        if POS_LAYOUT & set(cs):
            out.add('LAYOUT')
        fa = tr[rt]['father']
        if fa in tr and POS_LAYOUT & set(comp_names.get(tr[fa]['go'], [])):
            out.add('LAYOUT_CHILD')
        # 严格祖先里有 ScrollRect 才算（ScrollRect 自己的 rect 没人写）
        if anc(rt, SCROLL):
            out.add('SCROLL_DESC')
        if 'PlayFlyAnim' in cs:
            out.add('PLAYFLY')
        if names.get(go) in lua_names:
            out.add('CODE_POS')
        # 无 sprite 的拉伸实色块：自身没有实色图，靠 Image.color 铺满 rect
        img = [b for cls, _f, b in comps.get(go, []) if cls == 114
               and script_name(b, guid_index) == 'Image']
        if img:
            spr = re.search(r'm_Sprite: \{fileID: (-?\d+)', img[0])
            amin = vec_of(body, 'm_AnchorMin')
            amax = vec_of(body, 'm_AnchorMax')
            stretch = all(v is not None and abs(v) < 1e-4 for v in amin) and \
                all(v is not None and abs(v - 1) < 1e-4 for v in amax)
            if spr and spr.group(1) == '0' and stretch:
                out.add('MASK')
        return out

    def tree_flags(rt, acc=None):
        """子节点上的 INACTIVE/MASK 会连带影响父级写法，向上冒泡只提示，不改父级结论。"""
        return flags_of(rt)

    # ---- 锚点 ----
    root_go = tr[roots[0]]['go'] if roots else None
    ctx['anchor'] = root_go
    anim_on_go, legacy_on_go, legacy_paths = {}, {}, []
    for go, items in comps.items():
        for cls, _fid, body in items:
            if cls == 95:
                g = re.search(r'm_Controller: \{fileID: \d+, guid: (\w+)', body)
                anim_on_go[go] = os.path.basename(guid_index.get(g.group(1), '?')) if g else '?'
            elif cls == 111:
                legacy_on_go[go] = True
    for go in legacy_on_go:
        if go in rt_of_go:
            legacy_paths.append(path_of(rt_of_go[go]))

    print('prefab : %s' % args.prefab)
    print('根节点 : %s' % (names.get(root_go, '?')))
    if root_go in anim_on_go:
        print('锚点   : 根节点已有 Animator(%s) ⇒ 只换 m_Controller，别新建' % anim_on_go[root_go])
    elif root_go in legacy_on_go:
        print('锚点   : 根节点是 legacy Animation ⇒ 换成 Animator（同 GO 不能共存）')
    else:
        print('锚点   : 根节点没有任何动画组件 ⇒ 新增 Animator（m_Component 追一条 + 文件尾追 !u!95）')
    other = [('Animator(%s)' % v) + ' @ ' + path_of(rt_of_go[g])
             for g, v in anim_on_go.items() if g != root_go and g in rt_of_go]
    if other:
        print('⚠ 其它节点上的 Animator（%d 个，别当锚点）：%s' % (len(other), ', '.join(other[:6])))
    if legacy_paths:
        print('⚠ 其它节点上的 legacy Animation（%d 个，别当锚点）：%s'
              % (len(legacy_paths), ', '.join(legacy_paths[:6])))
    print()

    # ---- 树 ----
    rows = []

    def walk(rt, depth):
        t = tr.get(rt)
        if not t:
            return
        go = t['go']
        fl = tree_flags(rt)
        body = t['body']
        pos = dpt.vec(dpt.field(body, 'm_AnchoredPosition'))
        size = dpt.vec(dpt.field(body, 'm_SizeDelta'))
        cs = [c for c in comp_names.get(go, []) if c not in ('CanvasRenderer',)]
        line = '%-58s pos%-14s size%-14s [%s]' % ('  ' * depth + names.get(go, '?'), pos, size,
                                                  ', '.join(cs) or '-')
        if fl:
            line += '  <<' + '|'.join(f for f in FLAG_ORDER if f in fl) + '>>'
        if not args.only_risky:
            print(line)
        if fl:
            rows.append((path_of(rt), pos, sorted(fl), names.get(go, '?'), len(t['children'])))
        if depth >= args.depth:
            return
        for c in t['children']:
            walk(c, depth + 1)

    for r in roots:
        walk(r, 0)

    # ---- 汇总 ----
    print('\n风险汇总（%d 个节点）：' % len(rows))
    if not rows:
        print('  无 —— 可以直接按配方写')
        return 0
    for path, pos, fl, _nm, nchild in rows:
        parts = []
        for f in fl:
            if f == 'MASK':
                parts.append('无 sprite 的拉伸实色块，缩放会连边缘一起缩、露出场景底 ⇒ 只写 alpha'
                             if not nchild else
                             '无 sprite 的拉伸实色块（有子节点，可能整屏遮罩）⇒ 默认只写 alpha；'
                             '确需缩放压到 ±1.5% 并实拍复核')
            else:
                parts.append(ADVICE[f])
        adv = '；'.join(parts)
        print('  %-52s pos%-13s %s' % (path, pos, ','.join(fl)))
        print('      ⇒ %s' % adv)
    print('\n提示：曲线里的 y 是绝对值，取上面的 pos.y 当 baseY（正常写出后应回读 prefab 复核）。')
    return 0


if __name__ == '__main__':
    sys.exit(main())
