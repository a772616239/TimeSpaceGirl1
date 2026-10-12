#!/usr/bin/env python3
"""比对原版 / 补丁版 tk/getServerList 的响应，输出「语义级」差异。

输入两个 JSON 文件（Mongo BasicDBObject.toString() 的输出，本身即合法 JSON）。
判定标准：
  serverList 里每条记录按 server_id 归位，逐字段比对；
  只允许「补丁版比原版多出 name_en / name_jp / name_kr」这一种差异，
  其余任何字段增删改都视为回归。
"""
import json
import sys


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def index_by_server_id(obj):
    return {str(s.get("server_id")): s for s in obj.get("serverList", [])}


def main():
    a = load(sys.argv[1])          # 原版
    b = load(sys.argv[2])          # 补丁版
    label_a = sys.argv[3] if len(sys.argv) > 3 else "原版"
    label_b = sys.argv[4] if len(sys.argv) > 4 else "补丁版"
    allowed_new = {"name_en", "name_jp", "name_kr"}
    problems = []

    print("=== 顶层字段 ===")
    for key in sorted(set(a) | set(b)):
        va, vb = a.get(key, "<缺失>"), b.get(key, "<缺失>")
        if key == "serverList":
            continue
        if va == vb:
            print("  %-14s 一致" % key)
        else:
            print("  %-14s ⚠️  %s -> %s" % (key, va, vb))
            problems.append("顶层字段 %s 发生变化" % key)

    sa, sb = index_by_server_id(a), index_by_server_id(b)
    print()
    print("=== serverList（%d 条 vs %d 条）===" % (len(sa), len(sb)))
    if set(sa) != set(sb):
        problems.append("下发的区服集合发生变化：%s vs %s" % (sorted(sa), sorted(sb)))
        print("  ⚠️ 区服集合不同：原版 %s / 补丁版 %s" % (sorted(sa), sorted(sb)))

    for sid in sorted(set(sa) & set(sb)):
        ra, rb = sa[sid], sb[sid]
        added = {k: rb[k] for k in rb if k not in ra}
        removed = [k for k in ra if k not in rb]
        changed = {k: (ra[k], rb[k]) for k in ra if k in rb and ra[k] != rb[k]}
        illegal_added = {k: v for k, v in added.items() if k not in allowed_new}
        if removed:
            problems.append("server_id=%s 丢字段 %s" % (sid, removed))
        if changed:
            problems.append("server_id=%s 字段被改 %s" % (sid, changed))
        if illegal_added:
            problems.append("server_id=%s 多出非预期字段 %s" % (sid, illegal_added))
        if added:
            print("  server_id=%-6s name=%-14s 新增 %s"
                  % (sid, ra.get("name"), json.dumps(added, ensure_ascii=False)))
        else:
            print("  server_id=%-6s name=%-14s 无变化（老记录应命中此分支）" % (sid, ra.get("name")))

    missed = set(sb) - set(sa)
    if missed:
        problems.append("补丁版多出区服 %s" % sorted(missed))

    print()
    if problems:
        print("🔴 发现 %d 处问题：" % len(problems))
        for p in problems:
            print("   - " + p)
        return 1
    print("✅ 语义比对通过：除 %s 外无任何差异" % "/".join(sorted(allowed_new)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
