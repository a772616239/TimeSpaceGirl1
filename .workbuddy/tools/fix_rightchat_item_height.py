#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""修 Fight/rightchat.prefab 的竖向节奏 —— 根因是 contentroot 高度为 0。

背景（Unity 实测，Canvas 990 宽、ForceRebuildLayoutImmediate 后）：
  leftchat  : root h=161.2，contentroot h=136，bg h=136，条目间距 pitch=146.4
  rightchat : root h= 51.6，contentroot h=  0，bg h=140（忽略布局），pitch= 93.2
头像 210 高，pitch 只有 93 → 头像互相叠 117px，看起来就是"都挨在一块了"。

为什么 contentroot 高度是 0：bg 的 LayoutElement 写了 m_IgnoreLayout: 1，
contentroot 的 VerticalLayoutGroup 把它整个跳过，于是 contentroot 的
preferred height = 0，根节点 ContentSizeFitter 再把条目压到 51.6。

所以不能只调 padding / spacing —— 条目盒子本身是塌的。修法：让 bg 重新参与
布局（ignore=0），contentroot 高度就由 bg 撑起来，再把竖向数值镜像成 leftchat。

镜像口径（条目宽 990，内容区 0..840，右对齐）：
  root VLG  padT=30 spacing=-14.82（与 leftchat 完全一致）
  contentroot VLG align=2（右上），bg 宽 690 → 气泡占 150..840
  头像组 y=-55.099976、lv y=-104.099976、vip y=-108.099976（同 leftchat）
  气泡内文右边缘 822（=840-18），左边距 40，宽 631.7483

按 RectTransform / 组件 fileID 定位块改，因为 prefab 里有多个完全相同的
`{x: 68.1, y: -98}`，纯文本替换会打错节点。
"""
import re
import sys

PREFAB = 'Assets/ManagedResources/Prefabs/UI/Fight/rightchat.prefab'

# fileID -> [(块内正则, 替换, 说明)]
EDITS = {
    # 根 VerticalLayoutGroup：竖向节奏对齐 leftchat
    '977446818610704817': [
        (r'^(\s*)m_Top: 0$', r'\g<1>m_Top: 30', 'root VLG padTop 0 -> 30'),
        (r'^(\s*)m_Spacing: 41\.6$', r'\g<1>m_Spacing: -14.82', 'root VLG spacing 41.6 -> -14.82'),
    ],
    # 气泡容器 VLG：右上对齐（leftchat 是左上）
    '3387209740858179257': [
        (r'^(\s*)m_ChildAlignment: 0$', r'\g<1>m_ChildAlignment: 2', 'contentroot VLG align 0 -> 2'),
    ],
    # 气泡底重新参与布局 —— 这是根因修复
    # ⚠️ 7190504374598386358 才是 bg 的 LayoutElement（挂在 GameObject 6095609620052036816 上）；
    #    3386752215025683881 是 content 的，改错了会让 contentroot 高度继续为 0。
    # 光把 ignore 改成 0 还不够：LayoutElement 的 preferred 全是 -1，LayoutUtility 会返回 0，
    # 气泡宽度会塌成 31。所以显式写死 preferred 690x136（= leftchat 的 bg 尺寸）。
    '7190504374598386358': [
        (r'^(\s*)m_IgnoreLayout: 1$', r'\g<1>m_IgnoreLayout: 0', 'bg LayoutElement ignore 1 -> 0'),
        (r'^(\s*)m_PreferredWidth: -1$', r'\g<1>m_PreferredWidth: 690', 'bg preferredWidth -> 690'),
        (r'^(\s*)m_PreferredHeight: -1$', r'\g<1>m_PreferredHeight: 136', 'bg preferredHeight -> 136'),
    ],
    # 气泡底尺寸：宽对齐 contentroot（690），高对齐 leftchat（136）
    '2873976543811907833': [
        (r'^(\s*)m_SizeDelta: \{x: 674, y: 140\}$', r'\g<1>m_SizeDelta: {x: 690, y: 136}', 'bg size 674x140 -> 690x136'),
    ],
    # 气泡内文：右边缘 822（840-18），左边距 40，宽 631.7483；y=-96 让正文落在 leftchat 同一行
    '5233735234743510691': [
        (r'^(\s*)m_AnchoredPosition: \{x: 656, y: -100\}$',
         r'\g<1>m_AnchoredPosition: {x: 672, y: -96}', 'content x 656 -> 672, y -100 -> -96'),
        (r'^(\s*)m_SizeDelta: \{x: 615\.7483, y: 60\}$',
         r'\g<1>m_SizeDelta: {x: 631.7483, y: 60}', 'content width 615.75 -> 631.75'),
    ],
    # 头像组：y 对齐 leftchat 的 -55.099976
    '846769410604143989': [(r'^(\s*)m_AnchoredPosition: \{x: 68\.1, y: -98\}$',
                            r'\g<1>m_AnchoredPosition: {x: 68.1, y: -55.099976}', 'defultFrame y')],
    '2091463781450492099': [(r'^(\s*)m_AnchoredPosition: \{x: 68\.1, y: -98\}$',
                             r'\g<1>m_AnchoredPosition: {x: 68.1, y: -55.099976}', 'head y')],
    '8546920866140404819': [(r'^(\s*)m_AnchoredPosition: \{x: 68\.1, y: -98\.00002\}$',
                             r'\g<1>m_AnchoredPosition: {x: 68.1, y: -55.099976}', 'headkuang y')],
    '3851017052769811695': [(r'^(\s*)m_AnchoredPosition: \{x: 70, y: -148\.40002\}$',
                             r'\g<1>m_AnchoredPosition: {x: 70, y: -104.099976}', 'lv y')],
    '6847006206200029785': [(r'^(\s*)m_AnchoredPosition: \{x: 69, y: -146\.40002\}$',
                             r'\g<1>m_AnchoredPosition: {x: 69, y: -108.099976}', 'vip y')],
    # 时间行：leftchat 是 -48.5
    '2313632523900700004': [(r'^(\s*)m_AnchoredPosition: \{x: 495, y: -50\.5\}$',
                             r'\g<1>m_AnchoredPosition: {x: 495, y: -48.5}', 'time y -50.5 -> -48.5')],
    # contentroot 位置：跟 leftchat 的 -15.18 对齐（运行时被布局驱动，仅保持序列化值一致）
    '2863729194476367660': [(r'^(\s*)m_AnchoredPosition: \{x: 840, y: -41\.6\}$',
                             r'\g<1>m_AnchoredPosition: {x: 840, y: -15.18}', 'contentroot y -41.6 -> -15.18')],
}


def main(dry_run=False):
    txt = open(PREFAB, encoding='utf-8').read()
    out = txt
    ok, fail = 0, []
    for fid, rules in EDITS.items():
        m = re.search(r'^--- !u!\d+ &%s\n(.*?)(?=^--- |\Z)' % fid, txt, re.S | re.M)
        if not m:
            fail.append('%s: 找不到组件块' % fid)
            continue
        block = m.group(1)
        new_block = block
        for pat, rep, label in rules:
            hits = re.findall(pat, new_block, re.M)
            if len(hits) != 1:
                fail.append('%s %s: 命中 %d 次' % (fid, label, len(hits)))
                continue
            new_block = re.sub(pat, rep, new_block, count=1, flags=re.M)
            print('  OK  %-20s %s' % (fid, label))
            ok += 1
        out = out.replace(block, new_block, 1)

    print('\n计划修改 %d 处，失败 %d 处' % (ok, len(fail)))
    for f in fail:
        print('  !!', f)
    if dry_run or fail:
        print('\n[dry-run / 有失败，不落盘]')
        return 1 if fail else 0

    open(PREFAB, 'w', encoding='utf-8').write(out)
    print('已写入 %s' % PREFAB)
    return 0


if __name__ == '__main__':
    sys.exit(main('--dry-run' in sys.argv))
