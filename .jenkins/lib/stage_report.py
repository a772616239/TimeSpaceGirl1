#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""环节报告库 —— 把「每个环节的结果」变成 Jenkins 画得出来的东西。

为什么需要它
------------
Pipeline 的 stage 图只告诉你「哪个 stage 红了」，但本项目真正的判据是**环节内部的量化结论**：
包内 12 个 int32 是不是 minimal 口径、几个 .so 对齐 < 16384、googlesignin 在不在包里、
生产服几个核心进程在线……这些要么淹没在几百行控制台里，要么只在脚本自己的 JSON 里。

本库做两件事：

1. `add` —— 每个环节跑完登记一条记录（独立小文件，**并行 stage 同时写也不会互相踩**）。
2. `junit` / `summary` / `desc` —— 把记录渲染成 Jenkins 原生的三种可视面：
   - JUnit XML ⇒ 构建页出现「测试结果」表格 + **历史趋势图**（每次构建每环节的红绿曲线）
   - Markdown 摘要 ⇒ 归档成报告，并在左侧构建列表直接当构建描述显示
   - 单行结论 ⇒ 构建描述前缀，一眼看出这次是 12/12 通过还是挂了哪个环节

设计要点
--------
- 记录用「一条记录一个小文件」而不是 append 到单个 JSONL：**并发写不会交错**，
  代价只是渲染时 glob 一下（几十个文件，无感）。
- 状态语义与 Jenkins 对齐：`pass`→绿、`fail`→红（failure）、`warn`→黄（skipped+[WARN]）、
  `skip`→灰（skipped）。JUnit 没有原生「警告」，用 skipped 承载是为了在趋势图上
  **既不冒充绿灯、也不误报失败**。

用法
----
    stage_report.py add --run DIR --name "包内出包口径核验" --status pass \\
                        [--group "包内校验"] [--detail "minimal 口径命中"] \\
                        [--log 相对路径] [--duration 3.2]
    stage_report.py junit   --run DIR --out results.xml [--suite "TS-Android-Release"]
    stage_report.py summary --run DIR [--out stages.md] [--title "..."]
    stage_report.py desc    --run DIR

退出码：0 正常；2 参数/路径错误。
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import re
import sys
import time
import xml.sax.saxutils as sax

STATUSES = ("pass", "fail", "warn", "skip")
BADGE = {"pass": "✅", "fail": "🔴", "warn": "⚠️", "skip": "⏭"}


# --------------------------------------------------------------------------- #
def sanitize(s):
    """把「终端产物」变成能安全放进 XML / JSON / Markdown 表格的纯文本。

    为什么必须做（实测踩过，2026-10-12）：
    环节结论取自被 `tee` 下来的日志的**最后一条非空行**，而日志里带 ANSI 颜色码
    （run_stage.sh 自己打印的、以及各 check 脚本打印的）。ESC(0x1b) 在 **XML 1.0 里
    是非法字符**，直接写进 junit.xml 会让**整份报告**解析失败 —— Jenkins 报
    `Failed to read test report file … invalid XML character (Unicode: 0x1b)`，
    表现是「测试结果」页面整块只剩一条 `[failed-to-read]`，
    而控制台里 junit 步骤**一切正常、一个字都不报**（静默失败，最难查的一种）。
    所以这里把 ANSI 序列 + 其余 C0 控制字符一并去掉。
    （保留 \\t \\n \\r：XML 1.0 允许，Markdown 表格也用得上。）
    """
    if not isinstance(s, str):
        return s
    s = _ANSI.sub("", s)
    return _CTRL.sub("", s)


_ANSI = re.compile(r"\x1b(?:\[[0-9;?]*[ -/]*[@-~]|[@-Z\\-_])")
_CTRL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


# --------------------------------------------------------------------------- #
def _stages_dir(run: str) -> str:
    return os.path.join(run, "stages")


def add(args) -> int:
    run = os.path.abspath(args.run)
    d = _stages_dir(run)
    os.makedirs(d, exist_ok=True)
    if args.status not in STATUSES:
        print("状态必须是 %s 之一" % "/".join(STATUSES), file=sys.stderr)
        return 2
    rec = {
        "name": sanitize(args.name),
        "group": sanitize(args.group) or "默认",
        "status": args.status,
        "detail": sanitize((args.detail or "").strip()),
        "log": sanitize(args.log or ""),
        "duration": float(args.duration or 0.0),
        "ts": time.time(),
    }
    # 唯一文件名 = 免锁并发安全。排序用 ts+纳秒串接。
    fname = "%019d-%08d-%s.json" % (
        int(rec["ts"] * 1000), os.getpid(),
        "".join(c if c.isalnum() or c in "-_" else "_" for c in rec["name"])[:48])
    tmp = os.path.join(d, fname + ".tmp")
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(rec, fh, ensure_ascii=False)
    os.replace(tmp, os.path.join(d, fname))
    print("  [环节] %s %s%s" % (
        BADGE[args.status], args.name,
        ("  —  " + rec["detail"]) if rec["detail"] else ""))
    return 0


def load(run: str) -> list:
    out = []
    for p in sorted(glob.glob(os.path.join(_stages_dir(run), "*.json"))):
        try:
            with open(p, encoding="utf-8") as fh:
                rec = json.load(fh)
        except Exception:  # noqa: BLE001  半截文件直接忽略，不让报告生成挂掉
            continue
        # 兜底清洗：老记录（sanitize 之前写下的）里可能已经混进 ANSI 码，
        # 在这里统一洗掉，这样 junit / summary / desc / status 四个出口都干净。
        for k in ("name", "group", "detail", "log"):
            if isinstance(rec.get(k), str):
                rec[k] = sanitize(rec[k])
        out.append(rec)
    out.sort(key=lambda r: (r.get("ts", 0), r.get("name", "")))
    return out


# --------------------------------------------------------------------------- #
def junit(args) -> int:
    recs = load(args.run)
    if not recs:
        print("没有环节记录，不生成 JUnit（避免用空结果把趋势图冲成 0）", file=sys.stderr)
        return 2

    groups: dict = {}
    for r in recs:
        groups.setdefault(r.get("group") or "默认", []).append(r)

    cases_xml, total_fail, total_skip, total_time = [], 0, 0, 0.0
    for gname, items in groups.items():
        g_fail = sum(1 for r in items if r["status"] == "fail")
        g_skip = sum(1 for r in items if r["status"] in ("warn", "skip"))
        g_time = sum(float(r.get("duration") or 0) for r in items)
        total_fail += g_fail
        total_skip += g_skip
        total_time += g_time
        body = []
        for r in items:
            name = sax.escape(r["name"])
            body.append('    <testcase classname="%s" name="%s" time="%.3f">'
                        % (sax.escape(gname), name, float(r.get("duration") or 0)))
            detail = r.get("detail") or ""
            if r.get("log"):
                detail = (detail + "\n日志: " + r["log"]).strip()
            if detail:
                body.append('      <system-out>%s</system-out>' % sax.escape(detail))
            if r["status"] == "fail":
                body.append('      <failure message="%s">%s</failure>'
                            % (sax.escape(detail or "环节失败"),
                               sax.escape(detail or "")))
            elif r["status"] in ("warn", "skip"):
                tag = "WARN" if r["status"] == "warn" else "SKIP"
                body.append('      <skipped message="[%s] %s"/>'
                            % (tag, sax.escape(detail or "")))
            body.append('    </testcase>')
        cases_xml.append(
            '  <testsuite name="%s" tests="%d" failures="%d" errors="0" skipped="%d" '
            'time="%.3f" timestamp="%s">\n%s\n  </testsuite>'
            % (sax.escape(gname), len(items), g_fail, g_skip, g_time,
               time.strftime("%Y-%m-%dT%H:%M:%S"), "\n".join(body)))

    xml = ('<?xml version="1.0" encoding="UTF-8"?>\n'
           '<testsuites name="%s" tests="%d" failures="%d" errors="0" skipped="%d" time="%.3f">\n%s\n</testsuites>\n'
           % (sax.escape(args.suite or "TS Pipeline"), len(recs), total_fail,
              total_skip, total_time, "\n".join(cases_xml)))
    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        # 最后一道闸：无论上游怎么漏，写盘前再洗一遍，保证绝不出现 XML 非法字符。
        fh.write(sanitize(xml))
    print("JUnit 已写出：%s（%d 个环节，失败 %d，警告/跳过 %d）"
          % (args.out, len(recs), total_fail, total_skip))
    return 0


def render_summary(run: str, title: str) -> str:
    recs = load(run)
    n_pass = sum(1 for r in recs if r["status"] == "pass")
    n_fail = sum(1 for r in recs if r["status"] == "fail")
    n_warn = sum(1 for r in recs if r["status"] == "warn")
    n_skip = sum(1 for r in recs if r["status"] == "skip")

    verdict = "🔴 %d 个环节失败" % n_fail if n_fail else (
        "⚠️ 通过 %d，%d 个需关注" % (n_pass, n_warn + n_skip) if (n_warn + n_skip)
        else "✅ %d 个环节全部通过" % n_pass)

    L = ["# %s" % title, "",
         "**结论：%s**" % verdict, "",
         "| 分组 | 环节 | 结果 | 耗时 | 说明 |", "|---|---|---|---|---|"]
    for r in recs:
        dur = ("%.1fs" % float(r.get("duration") or 0)) if r.get("duration") else "-"
        L.append("| %s | %s | %s %s | %s | %s |"
                 % (r["group"], r["name"], BADGE[r["status"]],
                    {"pass": "通过", "fail": "失败", "warn": "关注", "skip": "跳过"}[r["status"]],
                    dur, (r.get("detail") or "").replace("|", "\\|").replace("\n", " ")))
    L += ["", "统计：通过 %d · 失败 %d · 关注 %d · 跳过 %d" % (n_pass, n_fail, n_warn, n_skip)]
    return "\n".join(L) + "\n"


def summary(args) -> int:
    md = render_summary(args.run, args.title or "流程环节汇总")
    if args.out:
        os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
        with open(args.out, "w", encoding="utf-8") as fh:
            fh.write(md)
        print("摘要已写出：%s" % args.out)
    else:
        sys.stdout.write(md)
    return 0


def desc(args) -> int:
    recs = load(args.run)
    if not recs:
        print("（无环节记录）")
        return 0
    n_pass = sum(1 for r in recs if r["status"] == "pass")
    n_fail = sum(1 for r in recs if r["status"] == "fail")
    n_warn = sum(1 for r in recs if r["status"] == "warn")
    if n_fail:
        worst = [r["name"] for r in recs if r["status"] == "fail"]
        print("🔴 %d/%d 环节失败：%s" % (n_fail, len(recs), "、".join(worst[:4])))
    elif n_warn:
        print("⚠️ %d/%d 环节通过，%d 项需关注" % (n_pass, len(recs), n_warn))
    else:
        print("✅ %d 个环节全部通过" % n_pass)
    return 0


def status(args) -> int:
    """只吐 pass / warn / fail 三个词，给 Pipeline 决定构建球色用。

    为什么需要它：Jenkins 默认只有「红/绿」。但本项目的很多环节天然是「通过但需关注」
    （例如巡检发现可用内存偏低、有未推送提交），把这类判成红色会让人学会忽略红灯。
    有了这个词，Pipeline 可以把构建置为 UNSTABLE（黄球）—— **黄球是有信息量的**：
    它表示「没坏，但值得看一眼」。
    """
    recs = load(args.run)
    if not recs:
        print("pass")
        return 0
    if any(r["status"] == "fail" for r in recs):
        print("fail")
    elif any(r["status"] == "warn" for r in recs):
        print("warn")
    else:
        print("pass")
    return 0


def san(args) -> int:
    """stdin -> stdout 的清洗过滤器：剥掉 ANSI 颜色码与 C0 控制字符。

    给 run_stage.sh 用：环节结论取自日志最后一行，那一行常常带颜色码。
    复用这里同一个 sanitize()，避免在两处各写一份正则（迟早漂移）。
    """
    sys.stdout.write(sanitize(sys.stdin.read()))
    return 0


# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description="环节报告：登记 / JUnit / 摘要 / 单行结论")
    sub = ap.add_subparsers(dest="cmd", required=True)

    n = sub.add_parser("san", help="stdin→stdout 清洗（去 ANSI 与非法控制字符）")
    n.set_defaults(func=san)

    a = sub.add_parser("add", help="登记一个环节结果")
    a.add_argument("--run", required=True)
    a.add_argument("--name", required=True)
    a.add_argument("--status", required=True, choices=STATUSES)
    a.add_argument("--group", default=None)
    a.add_argument("--detail", default=None)
    a.add_argument("--log", default=None)
    a.add_argument("--duration", type=float, default=0.0)
    a.set_defaults(func=add)

    j = sub.add_parser("junit", help="渲染 JUnit XML")
    j.add_argument("--run", required=True)
    j.add_argument("--out", required=True)
    j.add_argument("--suite", default=None)
    j.set_defaults(func=junit)

    s = sub.add_parser("summary", help="渲染 Markdown 摘要")
    s.add_argument("--run", required=True)
    s.add_argument("--out", default=None)
    s.add_argument("--title", default=None)
    s.set_defaults(func=summary)

    d = sub.add_parser("desc", help="输出单行结论（给构建描述用）")
    d.add_argument("--run", required=True)
    d.set_defaults(func=desc)

    st = sub.add_parser("status", help="输出 pass/warn/fail（给构建球色用）")
    st.add_argument("--run", required=True)
    st.set_defaults(func=status)

    args = ap.parse_args()
    # `san` 是纯 stdin/stdout 过滤器，不碰 run 目录
    if args.func is not san and not os.path.isdir(args.run):
        print("run 目录不存在：%s" % args.run, file=sys.stderr)
        return 2
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
