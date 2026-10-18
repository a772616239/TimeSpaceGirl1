#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把「国家排行」新增的贴图 / prefab 注册进 ResourcePathConfig.asset。

做法：**只追加**，不改动任何既有索引
  - resPathList   末尾追加两个目录 → 新索引 = 原长度
  - resAbNameList 末尾追加两个 AB   → 新索引 = 原长度
  - resInfoList   末尾追加每条资源（resName/extension/resPathIndex/resAbNameIndex）
  - assetBundleList 末尾追加两个 AB 依赖条目

为什么不能整体重跑 ResourcesPathEditor：那会重排全部索引并可能重命名重名资源，
产生巨大的无意义 diff；追加式改动等价且可 review。
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CFG = os.path.join(ROOT, "Assets/ManagedResources/ResConfigs/ResourcePathConfig.asset")
ATLAS_DIR = "Assets/ManagedResources/Atlas/CountryRankPanelAtlas"
PREFAB_DIR = "Assets/ManagedResources/Prefabs/UI/CountryRank"
AB_ATLAS = "lz4/atlas/countryrankpanelatlas"
AB_PREFAB = "lz4/prefabs/ui/countryrank"

ORDER = ["resPathList:", "resAbNameList:", "resInfoList:", "assetBundleList:"]


def section_bounds(lines, name):
    s = None
    for i, l in enumerate(lines):
        if l.strip() == name:
            s = i
            break
    assert s is not None, name
    e = len(lines)
    for i in range(s + 1, len(lines)):
        if lines[i].strip() in ORDER[ORDER.index(name) + 1:]:
            e = i
            break
    return s, e


def list_items(lines, name):
    s, e = section_bounds(lines, name)
    return [l.strip()[2:] for l in lines[s + 1:e] if l.strip().startswith("- ")]


def res_names(lines):
    s, e = section_bounds(lines, "resInfoList:")
    out = []
    for l in lines[s + 1:e]:
        m = re.match(r"\s+- resName: (\S+)", l)
        if m:
            out.append(m.group(1))
    return out


def main():
    txt = open(CFG, encoding="utf-8").read()
    lines = txt.split("\n")
    paths = list_items(lines, "resPathList:")
    abn = list_items(lines, "resAbNameList:")
    exists = set(res_names(lines))

    # ---- 待注册资源
    sprites = sorted(f[:-4] for f in os.listdir(os.path.join(ROOT, ATLAS_DIR))
                     if f.endswith(".png"))
    prefabs = sorted(f[:-7] for f in os.listdir(os.path.join(ROOT, PREFAB_DIR))
                     if f.endswith(".prefab"))

    todo_paths = [x for x in (ATLAS_DIR, PREFAB_DIR) if x not in paths]
    todo_abs = [x for x in (AB_ATLAS, AB_PREFAB) if x not in abn]
    path_idx = {}
    for x in todo_paths:
        path_idx[x] = len(paths) + len(path_idx)
    for x in (ATLAS_DIR, PREFAB_DIR):
        if x in paths:
            path_idx[x] = paths.index(x)
    ab_idx = {}
    for x in todo_abs:
        ab_idx[x] = len(abn) + len(ab_idx)
    for x in (AB_ATLAS, AB_PREFAB):
        if x in abn:
            ab_idx[x] = abn.index(x)

    dup = [n for n in sprites + prefabs if n in exists]
    assert not dup, "资源名重复，需改名：%s" % dup

    new_infos = []
    for n in sprites:
        new_infos.append((n, ".png", path_idx[ATLAS_DIR], ab_idx[AB_ATLAS]))
    for n in prefabs:
        new_infos.append((n, ".prefab", path_idx[PREFAB_DIR], ab_idx[AB_PREFAB]))

    out = list(lines)

    # 1) assetBundleList 末尾追加
    s, e = section_bounds(out, "assetBundleList:")
    add_ab = []
    for name in todo_abs:
        add_ab.append("  - assetBundleName: %s.unity3d" % name)
        add_ab.append("    dependences: []")
    if add_ab:
        # 找到该段最后一个非空行
        last = e - 1
        while last > s and not out[last].strip():
            last -= 1
        out[last + 1:last + 1] = add_ab

    # 2) resInfoList 末尾追加
    s, e = section_bounds(out, "resInfoList:")
    add_info = []
    for n, ext, pi, ai in new_infos:
        add_info.append("  - resName: %s" % n)
        add_info.append("    extension: %s" % ext)
        add_info.append("    resPathIndex: %d" % pi)
        add_info.append("    resAbNameIndex: %d" % ai)
    if add_info:
        last = e - 1
        while last > s and not out[last].strip():
            last -= 1
        out[last + 1:last + 1] = add_info

    # 3) resAbNameList 末尾追加
    s, e = section_bounds(out, "resAbNameList:")
    if todo_abs:
        last = e - 1
        while last > s and not out[last].strip():
            last -= 1
        out[last + 1:last + 1] = ["  - %s" % x for x in todo_abs]

    # 4) resPathList 末尾追加
    s, e = section_bounds(out, "resPathList:")
    if todo_paths:
        last = e - 1
        while last > s and not out[last].strip():
            last -= 1
        out[last + 1:last + 1] = ["  - %s" % x for x in todo_paths]

    open(CFG, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print("追加路径 %d：%s" % (len(todo_paths), todo_paths))
    print("追加 AB   %d：%s" % (len(todo_abs), todo_abs))
    print("注册资源  %d 条（贴图 %d / prefab %d）" % (len(new_infos), len(sprites), len(prefabs)))
    for n, ext, pi, ai in new_infos:
        print("   %-52s path=%d ab=%d" % (n + ext, pi, ai))


if __name__ == "__main__":
    main()
