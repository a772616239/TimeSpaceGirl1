#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 Fight/rightchat.prefab 的外框几何镜像成 Fight/leftchat.prefab 的口径。

为什么要用脚本改：prefab 里好几个节点有完全相同的 `{x: 68.1, y: -98}`，
纯文本替换会打错节点。这里按 RectTransform 的 fileID 定位块，只改块内的目标行。

镜像口径（条目坐标，条目宽 990）：
  leftchat : root VLG padL=150 -> contentroot 150..840，头像中心 81.9
  rightchat: root VLG padR=150 -> contentroot 150..840，头像中心 908.1 (=990-81.9)
气泡内文：左 18/40，右镜像 40/18。
"""
import re
import sys

PREFAB = 'Assets/ManagedResources/Prefabs/UI/Fight/rightchat.prefab'

# fileID -> [(属性行正则, 新行, 说明)]
EDITS = {
    # 根节点的 VerticalLayoutGroup：竖向节奏对齐 leftchat，右边距 150 保持不变
    '977446818610704817': [
        (r'^    m_Top: 0$', '    m_Top: 30', 'root VLG padTop 0 -> 30'),
        (r'^  m_Spacing: 41\.6$', '  m_Spacing: -14.82', 'root VLG spacing 41.6 -> -14.82'),
    ],
    # 头像：y 对齐 leftchat(-55.1)，x 保持 +68.1（右侧镜像靠 padR + pivot.x=1 得到）
    '846769410604143989': [(r'^  m_AnchoredPosition: \{x: 68\.1, y: -98\}$',
                            '  m_AnchoredPosition: {x: 68.1, y: -55.099976}', 'defultFrame y')],
    '2091463781450492099': [(r'^  m_AnchoredPosition: \{x: 68\.1, y: -98\}$',
                             '  m_AnchoredPosition: {x: 68.1, y: -55.099976}', 'head y')],
    '8546920866140404819': [(r'^  m_AnchoredPosition: \{x: 68\.1, y: -98\.00002\}$',
                             '  m_AnchoredPosition: {x: 68.1, y: -55.099976}', 'headkuang y')],
    '3851017052769811695': [(r'^  m_AnchoredPosition: \{x: 70, y: -148\.40002\}$',
                             '  m_AnchoredPosition: {x: 70, y: -104.099976}', 'lv y')],
    '6847006206200029785': [(r'^  m_AnchoredPosition: \{x: 69, y: -146\.40002\}$',
                             '  m_AnchoredPosition: {x: 69, y: -108.099976}', 'vip y')],
    # 气泡容器：宽度对齐 leftchat 的 690，右边缘 840（=990-150）
    '2863729194476367660': [
        (r'^  m_AnchoredPosition: \{x: 840, y: -41\.6\}$',
         '  m_AnchoredPosition: {x: 840, y: -15.18}', 'contentroot pos'),
        (r'^  m_SizeDelta: \{x: 824, y: 0\}$', '  m_SizeDelta: {x: 690, y: 0}', 'contentroot width 824 -> 690'),
    ],
    # 气泡底：贴住 contentroot 右上角，宽 690（原来是 688.7 居中、顶部还高出 12）
    '2873976543811907833': [
        (r'^  m_AnchoredPosition: \{x: 479\.62827, y: -58\}$',
         '  m_AnchoredPosition: {x: 690, y: 0}', 'bg pos'),
        (r'^  m_SizeDelta: \{x: 688\.7435, y: 140\}$', '  m_SizeDelta: {x: 690, y: 140}', 'bg size'),
        (r'^  m_Pivot: \{x: 0\.5, y: 0\.5\}$', '  m_Pivot: {x: 1, y: 1}', 'bg pivot -> 右上'),
    ],
    # 文本：宽度对齐 leftchat 的 631.75，右边距 40、左边距 18（左是 18/40）
    '5233735234743510691': [
        (r'^  m_AnchoredPosition: \{x: 667\.3093, y: -100\}$',
         '  m_AnchoredPosition: {x: 650, y: -100}', 'content pos'),
        (r'^  m_SizeDelta: \{x: 651\.8118, y: 60\}$', '  m_SizeDelta: {x: 631.7483, y: 60}', 'content width'),
    ],
}


def main(dry_run=False):
    txt = open(PREFAB, encoding='utf-8').read()
    out = txt
    ok, fail = 0, []
    for fid, rules in EDITS.items():
        # 切出该 RectTransform 的文档块
        m = re.search(r'^--- !u!\d+ &%s\n(.*?)(?=^--- |\Z)' % fid, txt, re.S | re.M)
        if not m:
            fail.append(f'{fid}: 找不到 RectTransform 块')
            continue
        block = m.group(1)
        new_block = block
        for pat, rep, label in rules:
            hits = re.findall(pat, new_block, re.M)
            if len(hits) != 1:
                fail.append(f'{fid} {label}: 命中 {len(hits)} 次，跳过')
                continue
            new_block = re.sub(pat, rep, new_block, count=1, flags=re.M)
            print(f'  OK  {fid}  {label}')
            ok += 1
        out = out.replace(block, new_block, 1)

    print(f'\n计划修改 {ok} 处，失败 {len(fail)} 处')
    for f in fail:
        print('  !!', f)
    if dry_run or fail:
        print('\n[dry-run / 有失败，不落盘]')
        return 1 if fail else 0

    open(PREFAB, 'w', encoding='utf-8').write(out)
    print(f'已写入 {PREFAB}')
    return 0


if __name__ == '__main__':
    sys.exit(main('--dry-run' in sys.argv))
