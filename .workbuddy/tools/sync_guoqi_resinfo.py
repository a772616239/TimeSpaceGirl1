#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
让 ResourcePathConfig.asset 里的 cn2-guoqi_* 条目与 CountryRankPanelAtlas 实际贴图一致。

为什么需要：
  Util.LoadSprite 是「按资源名查 ResourcePathConfig → 路径索引 + AB 名索引」，
  图集里加了 png 但没登记 ⇒ 运行时 LoadSprite 取不到，旗帜是空白。
  删了 png 却留着条目 ⇒ 脏引用（虽然不至于崩，但会误导后来人）。

做法（幂等、只动 guoqi 这一段）：
  1. 找到 resInfoList 里连续的 cn2-guoqi_* 条目区间
  2. 用目录里的实际 png（排序后）整体重建这一段
  3. 路径索引 / AB 名索引沿用原区间的值（必须指向 CountryRankPanelAtlas）

用法：python3 .workbuddy/tools/sync_guoqi_resinfo.py [--check]
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CFG = os.path.join(ROOT, "Assets/ManagedResources/ResConfigs/ResourcePathConfig.asset")
ATLAS_DIR = os.path.join(ROOT, "Assets/ManagedResources/Atlas/CountryRankPanelAtlas")
PREFIX = "cn2-guoqi_"
ORDER = ["resPathList:", "resAbNameList:", "resInfoList:", "assetBundleList:"]


def section_bounds(lines, name):
    s = next(i for i, l in enumerate(lines) if l.strip() == name)
    e = len(lines)
    for i in range(s + 1, len(lines)):
        if lines[i].strip() in ORDER[ORDER.index(name) + 1:]:
            e = i
            break
    return s, e


def list_items(lines, name):
    s, e = section_bounds(lines, name)
    return [l.strip()[2:] for l in lines[s + 1:e] if l.strip().startswith("- ")]


def guoqi_entries(lines):
    """返回 (起, 止, [(name, ext, pi, ai), ...])，止为开区间。"""
    s, e = section_bounds(lines, "resInfoList:")
    start = None
    out = []
    for i in range(s + 1, e):
        if not lines[i].strip().startswith("- resName:"):
            continue
        name = lines[i].split(":", 1)[1].strip()
        if not name.startswith(PREFIX):
            if start is not None and out:
                break
            continue
        if start is None:
            start = i
        ext = lines[i + 1].split(":", 1)[1].strip()
        pi = int(lines[i + 2].split(":", 1)[1].strip())
        ai = int(lines[i + 3].split(":", 1)[1].strip())
        out.append((name, ext, pi, ai))
    if start is None:
        raise SystemExit("找不到 cn2-guoqi_* 条目，请先确认配置文件结构")
    end = start + len(out) * 4
    return start, end, out


def main():
    check = "--check" in sys.argv
    txt = open(CFG, encoding="utf-8").read()
    lines = txt.split("\n")
    start, end, cur = guoqi_entries(lines)

    pngs = sorted(f[:-4] for f in os.listdir(ATLAS_DIR)
                  if f.endswith(".png") and f.startswith(PREFIX))
    want = list(pngs)  # 已经是完整资源名（含 cn2-guoqi_ 前缀）
    have = [n for n, _, _, _ in cur]
    _, _, pi, ai = cur[0]

    # 索引必须指向 CountryRankPanelAtlas（防呆）
    paths = list_items(lines, "resPathList:")
    abn = list_items(lines, "resAbNameList:")
    assert paths[pi] == "Assets/ManagedResources/Atlas/CountryRankPanelAtlas", paths[pi]
    assert abn[ai] == "lz4/atlas/countryrankpanelatlas", abn[ai]

    missing = [n for n in want if n not in have]
    extra = [n for n in have if n not in want]
    if not missing and not extra and want == have:
        print("✅ 已一致：%d 条 guoqi 资源（索引 path=%d ab=%d）" % (len(have), pi, ai))
        return 0

    print("需要新增 %d 条：%s" % (len(missing), ", ".join(missing) or "-"))
    print("需要移除 %d 条：%s" % (len(extra), ", ".join(extra) or "-"))
    if check:
        return 1

    block = []
    for n in want:
        block += ["  - resName: %s" % n, "    extension: .png",
                  "    resPathIndex: %d" % pi, "    resAbNameIndex: %d" % ai]

    out = lines[:start] + block + lines[end:]
    open(CFG, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print("✅ 已重写 guoqi 段：%d 条" % len(want))
    return 0


if __name__ == "__main__":
    sys.exit(main())
