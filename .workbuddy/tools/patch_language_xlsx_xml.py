#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
在 XML 层把 Language.xlsx 里指定的 (id, 中/英/日) 文本换掉 —— 只动命中的格子和
sharedStrings，不重写整个工作簿。

为什么不用 openpyxl 存盘：openpyxl 重存会把 56 个原本是「空字符串」的格子变成「空单元格」，
并且把整个包重压（1.24MB -> 1.07MB）；虽然没有语义差别，但会让 diff 变成「整表重写」，
出了问题没法用 git diff 定位。这里只改 60 个格子 + 追加 60 条 sharedStrings。

用法：
    python .workbuddy/tools/patch_language_xlsx_xml.py --from-json diff.json [--dry-run]
    diff.json 形如 [{"id":63010089,"old":[zh,en,jp],"new":[zh,en,jp]}, ...]
"""
import argparse
import json
import os
import re
import shutil
import sys
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
XLSX = os.path.join(ROOT, 'data_execl/base_data/Language.xlsx')
COLS = {'C': 0, 'D': 1, 'E': 2}  # 中/英/日


def xml_escape(s):
    return (s.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;'))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--from-json', required=True)
    ap.add_argument('--dry-run', action='store_true')
    args = ap.parse_args()

    plan = json.load(open(args.from_json, encoding='utf-8'))
    want = {int(p['id']): p['new'] for p in plan}

    zin = zipfile.ZipFile(XLSX)
    names = zin.namelist()
    sheet_name = [n for n in names if n.startswith('xl/worksheets/sheet')][0]
    sheet = zin.read(sheet_name).decode('utf-8')
    sst = zin.read('xl/sharedStrings.xml').decode('utf-8')

    # ---- 1. 收集 <si>，定位每格当前指向 ----
    head, rest = sst.split('>', 1)
    si_items = re.findall(r'<si>.*?</si>', rest, re.S)
    if not si_items:
        print('sharedStrings 解析失败')
        return 2

    # ---- 2. 逐行找目标 id ----
    rows = re.findall(r'<row [^>]*r="(\d+)"[^>]*>(.*?)</row>', sheet, re.S)
    print('rows parsed', len(rows))

    replacements = []  # (cell_ref, old_xml, new_index)
    new_si = []
    hits = 0
    for rnum, body in rows:
        mb = re.search(r'<c r="B%s"[^>]*>\s*<v>(\d+)</v>\s*</c>' % rnum, body)
        if not mb:
            continue
        pid = int(mb.group(1))
        if pid not in want:
            continue
        hits += 1
        texts = want[pid]
        for col, idx in COLS.items():
            ref = '%s%s' % (col, rnum)
            mc = re.search(r'<c r="%s"[^>]*(?:/>|>.*?</c>)' % ref, body, re.S)
            if not mc:
                print('  缺格 %s (id %s)' % (ref, pid))
                continue
            new_index = len(si_items) + len(new_si)
            new_si.append('<si><t xml:space="preserve">%s</t></si>' % xml_escape(texts[idx]))
            replacements.append((ref, mc.group(0), new_index))

    print('命中 id 数 %d / %d，待替换格子 %d' % (hits, len(want), len(replacements)))
    if hits != len(want):
        print('!! 有 id 没在表里找到，中止')
        return 2

    # ---- 3. 改 sheet：按 cell ref 精确替换 ----
    for ref, old_xml, new_index in replacements:
        m = re.search(r'<c r="%s"(?P<attrs>[^>]*?)(?:/>|>)' % ref, old_xml)
        attrs = m.group('attrs')
        attrs = re.sub(r'\s+t="[^"]*"', '', attrs)
        attrs = re.sub(r'\s+s="[^"]*"', lambda mm: mm.group(0), attrs)  # 保留样式
        new_xml = '<c r="%s"%s t="s"><v>%d</v></c>' % (ref, attrs, new_index)
        before = sheet.count(old_xml)
        if before != 1:
            print('!! 单元格 %s 匹配 %d 次' % (ref, before))
            return 2
        sheet = sheet.replace(old_xml, new_xml)

    # ---- 4. 改 sharedStrings：追加 + 更新 uniqueCount ----
    sst_new = sst.replace('</sst>', ''.join(new_si) + '</sst>')
    mu = re.search(r'<sst[^>]*uniqueCount="(\d+)"', sst)
    old_u = int(mu.group(1))
    sst_new = sst_new.replace('uniqueCount="%d"' % old_u, 'uniqueCount="%d"' % (old_u + len(new_si)), 1)
    print('uniqueCount %d -> %d（count 不变）' % (old_u, old_u + len(new_si)))

    if args.dry_run:
        print('[DRY-RUN] 未写入')
        return 0

    # ---- 5. 重打包（其他 entry 原样拷贝）----
    tmp = XLSX + '.tmp'
    zout = zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED)
    for n in names:
        info = zin.getinfo(n)
        if n == sheet_name:
            zout.writestr(info, sheet.encode('utf-8'))
        elif n == 'xl/sharedStrings.xml':
            zout.writestr(info, sst_new.encode('utf-8'))
        else:
            zout.writestr(info, zin.read(n))
    zout.close()
    zin.close()
    shutil.move(tmp, XLSX)
    print('已写入 %s' % XLSX)
    return 0


if __name__ == '__main__':
    sys.exit(main())
