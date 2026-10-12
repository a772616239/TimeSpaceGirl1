#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 `server_health_check.py` 的控制台输出拆成「机器可用的 JSON + 人读摘要 + 退出码」。

为什么不能靠文本切分
--------------------
`server_health_check.py` 的输出顺序是：报告正文 → `=== JSON ===` → JSON → **后面还可能跟着别的行**
（例如 `--dry-run` 的 `[dry-run] 未发送邮件。`）。
所以「取 `=== JSON ===` 之后的全部内容」这种朴素做法会把尾行一起塞进 JSON 文件里，
得到一个 99% 正确、解析时才发现坏掉的产物 —— 这类"半个产物"最容易被误当成采集失败。
这里改用 `json.JSONDecoder.raw_decode()` 从第一个 `{` 起精确吃掉一个完整 JSON 对象，
尾行原样忽略。

用法：health_report.py <检查脚本的控制台输出文件> <JSON 落盘路径>
退出码：0 无严重项；1 有 🔴 严重项；2 找不到/解析不出 JSON
"""
from __future__ import annotations

import json
import sys


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    src, dst = sys.argv[1], sys.argv[2]

    with open(src, encoding="utf-8", errors="replace") as fh:
        text = fh.read()

    marker = text.rfind("=== JSON ===")
    if marker < 0:
        print("🔴 输出里找不到 `=== JSON ===` 标记（采集可能根本没成功）", file=sys.stderr)
        return 2
    seg = text[marker:]
    brace = seg.find("{")
    if brace < 0:
        print("🔴 JSON 标记之后没有对象起始 `{`", file=sys.stderr)
        return 2

    try:
        obj, _end = json.JSONDecoder().raw_decode(seg[brace:])
    except json.JSONDecodeError as e:
        print("🔴 JSON 解析失败：%s" % e, file=sys.stderr)
        print(seg[brace:brace + 800], file=sys.stderr)
        return 2

    with open(dst, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, ensure_ascii=False, indent=2)

    probs = obj.get("problems") or []
    warns = obj.get("warnings") or []

    print("主机 %s (%s) · %s" % (obj.get("hostname", "?"), obj.get("ip", "?"),
                                (obj.get("timestamp") or "")[:19]))
    print("核心服务在线 %s/%s · 日志系统级错误 %s · 业务级错误 %s"
          % (obj.get("up_core", "?"), obj.get("core_total", "?"),
             obj.get("log_sys_errors", "?"), obj.get("log_biz_errors", "?")))
    for p in probs:
        print("   🔴 %s" % p)
    for w in warns:
        print("   ⚠️ %s" % w)
    print("结论：%s" % obj.get("headline", ""))
    # 最后一行是给环节报告用的「一句话结论」
    print("__SUMMARY__ %s | 严重 %d | 关注 %d | 核心 %s/%s"
          % (obj.get("headline", ""), len(probs), len(warns),
             obj.get("up_core", "?"), obj.get("core_total", "?")))
    return 0 if not probs else 1


if __name__ == "__main__":
    sys.exit(main())
