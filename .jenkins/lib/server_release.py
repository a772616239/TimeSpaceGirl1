#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""服务端发布辅助（只算数，不下命令）—— jar 清单 / 逐条目差异 / 发布记录 / 发布看板。

为什么单独一个 python 文件
--------------------------
`server_release.sh` 负责「什么时候该做什么」（顺序、闸门、SSH），本文件负责「算什么」：
① 把 jar 拆成 `{条目名: CRC32}`；② 用**同名同 CRC** 判定「线上到底差哪些条目」；
③ 把结论落成机器可读的 JSON + 人可读的 Markdown；④ 生成发布看板 HTML。

🔴 为什么判据是逐条目 CRC，而不是 jar 的 md5 / 体积
---------------------------------------------------
线上 jar 是「以线上为基线、逐类注入」攒出来的（`zip -u` 只改被注入的条目），
它的 md5 与任何一次编译产物都不可能相等。体积也不可靠：`zip -X` 会剥 extra field、
`zip -u` 会重写中央目录，包体变小是正常的。
只有「逐条目 CRC 比对」能把「本次要改的条目」与「jar 容器差异」区分开（2026-10-18 实测定论）。

🔴 为什么「仅线上存在」的条目只报不删
------------------------------------
线上 jar 里有编译产物里根本没有的条目（如 `logback-boot.xml`，是 package.sh 从
deploy-overlay 注入的）。「本地没有」≠「该死」，删掉就等于把日志配置打回默认。
所以这类条目一律进报告，永不进注入清单。

用法
----
    server_release.py manifest  <jar> <out.tsv>
    server_release.py diff      --local A.jar --remote B.jar --outdir DIR --name gameSrv \\
                                [--include "com/ljsd/*"] [--exclude "META-INF/*,*/*.properties"]
    server_release.py verify-selected --local A.jar --remote B.jar --selected sel.json
    server_release.py record    --run DIR --stamp 20261019-2013 [--rollback]
    server_release.py html      --run DIR --out FILE

退出码：0 正常；2 参数/路径错；3 「没有差异」（对发布流程是「需关注」，不是失败）。
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import sys
import time
import zipfile

# 默认排除：这些条目**永远不注入**。
#   META-INF/*            —— 注入 MANIFEST 会改写 Class-Path，等于顺手换了整条依赖链；
#   application*.properties —— build 里那份是 src 的开发配置（server.id=70001、远程 Mongo），
#                             线上那份是 deploy-overlay 的生产配置，注入即连错库；
#   *.xml / *.yml         —— 保守起见资源类不进自动注入（走 package 模式）。
DEFAULT_EXCLUDE = "META-INF/*,application*.properties,*.properties,*.xml,*.yml,*.yaml"


# --------------------------------------------------------------------------- #
def md5(path: str) -> str:
    h = hashlib.md5()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def entries(path: str) -> dict:
    """{条目名: CRC32}。目录条目（以 / 结尾）不计。"""
    with zipfile.ZipFile(path) as z:
        return {i.filename: i.CRC for i in z.infolist() if not i.is_dir()}


def split_csv(s: str) -> list:
    return [x.strip() for x in (s or "").replace(" ", ",").split(",") if x.strip()]


def keep(name: str, includes: list, excludes: list) -> bool:
    if any(fnmatch.fnmatchcase(name, p) for p in excludes):
        return False
    if includes and not any(fnmatch.fnmatchcase(name, p) for p in includes):
        return False
    return True


def pkg_of(name: str) -> str:
    """把条目归到一个「看得懂的包」上，用于看板的分组统计。

    com/ljsd/jieling/handler/foo/Bar.class -> com.ljsd.jieling.handler
    com/ljsd/protocols/xxx.proto           -> com.ljsd.protocols
    """
    d = os.path.dirname(name)
    if not d:
        return "(根目录)"
    parts = d.split("/")
    if len(parts) >= 4 and parts[0] == "com":
        return ".".join(parts[:4])
    return ".".join(parts[:3]) if len(parts) > 3 else ".".join(parts)


# --------------------------------------------------------------------------- #
def cmd_manifest(args) -> int:
    e = entries(args.jar)
    with open(args.out, "w", encoding="utf-8") as fh:
        for name in sorted(e):
            fh.write("%08x\t%s\n" % (e[name], name))
    print("%s: %d 个条目 -> %s" % (os.path.basename(args.jar), len(e), args.out))
    return 0


def cmd_diff(args) -> int:
    L, R = entries(args.local), entries(args.remote)
    changed = sorted(n for n in L.keys() & R.keys() if L[n] != R[n])
    only_local = sorted(L.keys() - R.keys())
    only_prod = sorted(R.keys() - L.keys())

    includes, excludes = split_csv(args.include), split_csv(args.exclude)
    cand = changed + only_local
    selected = [n for n in cand if keep(n, includes, excludes)]
    excluded = [n for n in cand if n not in set(selected)]

    sel_class = [n for n in selected if n.endswith(".class")]
    sel_res = [n for n in selected if not n.endswith(".class")]

    groups: dict = {}
    for n in selected:
        k = pkg_of(n)
        groups[k] = groups.get(k, 0) + 1

    rec = {
        "name": args.name,
        "local": {"path": args.local, "entries": len(L), "md5": md5(args.local),
                  "bytes": os.path.getsize(args.local)},
        "remote": {"path": args.remote, "entries": len(R), "md5": md5(args.remote),
                   "bytes": os.path.getsize(args.remote)},
        "changed": changed, "only_local": only_local, "only_prod": only_prod,
        "selected": selected, "excluded": excluded,
        "selected_class": sel_class, "selected_res": sel_res,
        "groups": dict(sorted(groups.items(), key=lambda kv: -kv[1])),
        "include": includes, "exclude": excludes,
        "counts": {
            "changed": len(changed), "only_local": len(only_local),
            "only_prod": len(only_prod), "selected": len(selected),
            "excluded": len(excluded),
            "selected_class": len(sel_class), "selected_res": len(sel_res),
        },
    }
    os.makedirs(args.outdir, exist_ok=True)
    jp = os.path.join(args.outdir, "%s.diff.json" % args.name)
    mp = os.path.join(args.outdir, "%s.diff.md" % args.name)
    with open(jp, "w", encoding="utf-8") as fh:
        json.dump(rec, fh, ensure_ascii=False, indent=2)

    c = rec["counts"]
    L_ = ["### %s" % args.name, "",
          "| 指标 | 值 |", "|---|---|",
          "| 本地条目 / 线上条目 | %d / %d |" % (len(L), len(R)),
          "| 变更（同名不同 CRC） | **%d** |" % c["changed"],
          "| 仅本地新增 | %d |" % c["only_local"],
          "| 仅线上存在（只报不删） | %d |" % c["only_prod"],
          "| **本次将注入** | **%d**（class %d + 资源 %d） |"
          % (c["selected"], c["selected_class"], c["selected_res"]),
          "| 被排除规则挡掉 | %d |" % c["excluded"],
          "| 本地 md5 / 体积 | `%s` / %.1f MB |" % (rec["local"]["md5"][:12], rec["local"]["bytes"] / 1048576),
          "| 线上 md5 / 体积 | `%s` / %.1f MB |" % (rec["remote"]["md5"][:12], rec["remote"]["bytes"] / 1048576),
          ""]
    if rec["groups"]:
        L_ += ["**注入条目的包分布**（前 8）", "", "| 包 | 条目数 |", "|---|---|"]
        L_ += ["| `%s` | %d |" % (k, v) for k, v in list(rec["groups"].items())[:8]]
        L_ += [""]
    for title, items in (("将注入条目（前 40）", selected),
                         ("被排除（前 20）", excluded),
                         ("仅线上存在（前 20，不会删除）", only_prod)):
        if not items:
            continue
        L_ += ["**%s**" % title, "", "| # | 条目 |", "|---|---|"]
        L_ += ["| %d | `%s` |" % (i + 1, n) for i, n in enumerate(items[:40])]
        if len(items) > 40:
            L_ += ["| … | 其余 %d 条见 JSON |" % (len(items) - 40)]
        L_ += [""]
    with open(mp, "w", encoding="utf-8") as fh:
        fh.write("\n".join(L_))

    print("%s：变更 %d · 新增 %d · 仅线上 %d · 将注入 %d（class %d + 资源 %d）· 排除 %d"
          % (args.name, c["changed"], c["only_local"], c["only_prod"],
             c["selected"], c["selected_class"], c["selected_res"], c["excluded"]))
    return 0 if selected else 3


def cmd_verify_selected(args) -> int:
    """注入后复核：selected 里的每个条目，线上 CRC 必须与本地一致。"""
    with open(args.selected, encoding="utf-8") as fh:
        sel = json.load(fh)["selected"]
    L, R = entries(args.local), entries(args.remote)
    bad = [n for n in sel if n not in R or R[n] != L[n]]
    if bad:
        print("🔴 注入后仍有 %d/%d 个条目与本地不一致：" % (len(bad), len(sel)))
        for n in bad[:20]:
            print("   - %s" % n)
        return 1
    print("✅ 注入后复核通过：%d 个条目 CRC 与本地编译产物逐一相同" % len(sel))
    return 0


# --------------------------------------------------------------------------- #
def _load_json(path: str, default=None):
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:  # noqa: BLE001
        return default


def cmd_record(args) -> int:
    """写发布记录（md + json）并重建 INDEX.md。

    记录必须**可独立读懂**：光有构建号没用，半年后要能回答
    「这条 release 分支对应哪个提交、注入了哪些条目、上线后自检过没过、谁批的」。
    """
    run = os.path.abspath(args.run)
    meta = _load_json(os.path.join(run, "release", "meta.json"), {}) or {}
    ddir = os.path.join(run, "release", "diff")
    diffs = []
    if os.path.isdir(ddir):
        for f in sorted(os.listdir(ddir)):
            if f.endswith(".diff.json"):
                d = _load_json(os.path.join(ddir, f))
                if d:
                    diffs.append(d)
    health = _load_json(os.path.join(run, "release", "health.json"), {}) or {}
    stages = []
    sdir = os.path.join(run, "stages")
    if os.path.isdir(sdir):
        for f in sorted(os.listdir(sdir)):
            if f.endswith(".json"):
                s = _load_json(os.path.join(sdir, f))
                if s:
                    stages.append(s)

    rec = {
        "stamp": args.stamp,
        "kind": "rollback" if args.rollback else "release",
        "generated_at": time.strftime("%Y-%m-%d %H:%M:%S %z"),
        "job": meta.get("job"), "build": meta.get("build"), "build_url": meta.get("build_url"),
        "operator": meta.get("operator"),
        "repo": meta.get("repo"), "source_branch": meta.get("source_branch"),
        "release_branch": meta.get("release_branch"),
        "source_commit": meta.get("source_commit"), "commit_subject": meta.get("commit_subject"),
        "dirty_count": meta.get("dirty_count"), "dirty_files": meta.get("dirty_files", []),
        "deployed": meta.get("deployed"), "restart": meta.get("restart"),
        "target": meta.get("target", "正式服 129.226.213.65 (/home/java)"),
        "notes": meta.get("notes", ""),
        "jars": [],
        "totals": {"selected": 0, "changed": 0, "only_local": 0, "only_prod": 0, "excluded": 0},
        "health": health,
        "stages": [{"name": s.get("name"), "group": s.get("group"),
                    "status": s.get("status"), "detail": s.get("detail")} for s in stages],
    }
    for d in diffs:
        c = d["counts"]
        rec["jars"].append({"name": d["name"], "counts": c,
                            "local_md5": d["local"]["md5"], "remote_md5": d["remote"]["md5"]})
        for k in rec["totals"]:
            rec["totals"][k] += c.get(k, 0)

    L = ["# 服务端发布记录 · %s" % args.stamp, "",
         "> 由 Jenkins `%s #%s` 自动生成，勿手改（改就改 `server_release.sh record`）。"
         % (rec["job"] or "?", "?" if rec["build"] in (None, "") else rec["build"]), "",
         "| 项 | 值 |", "|---|---|",
         "| 类型 | %s |" % ("回滚" if args.rollback else "发布"),
         "| 目标 | %s |" % rec["target"],
         "| release 分支 | `%s` |" % (rec["release_branch"] or "-"),
         "| 源分支 | `%s` |" % (rec["source_branch"] or "-"),
         "| 源提交 | `%s` %s |" % ((rec["source_commit"] or "-")[:12], rec["commit_subject"] or ""),
         "| 工作区脏项 | %s |" % (rec["dirty_count"] or 0),
         "| 是否上线 | %s |" % ("是" if rec["deployed"] else "否（演练 / 只构建）"),
         "| 重启范围 | %s |" % (rec["restart"] or "-"),
         "| 生成时间 | %s |" % rec["generated_at"],
         "| 构建链接 | %s |" % (rec["build_url"] or "-"),
         "| 操作人 | %s |" % (rec["operator"] or "-"),
         ""]
    if rec["notes"]:
        L += ["**发布说明**：%s" % rec["notes"], ""]
    L += ["## 注入条目统计", "", "| jar | 变更 | 新增 | 仅线上 | 将注入 | 排除 |", "|---|---|---|---|---|---|"]
    for j in rec["jars"]:
        L.append("| `%s` | %d | %d | %d | %d | %d |" % (
            j["name"], j["counts"]["changed"], j["counts"]["only_local"],
            j["counts"]["only_prod"], j["counts"]["selected"], j["counts"]["excluded"]))
    t = rec["totals"]
    L.append("| **合计** | %d | %d | %d | **%d** | %d |"
             % (t["changed"], t["only_local"], t["only_prod"], t["selected"], t["excluded"]))
    L += ["", "## 上线自检", ""]
    if health:
        L += ["| 检查 | 结果 |", "|---|---|"]
        for k, v in health.get("checks", {}).items():
            L.append("| %s | %s |" % (k, v))
        L.append("")
        L.append("判据：%s" % health.get("verdict", "-"))
    else:
        L.append("（本次未上线，无自检数据）")
    L += ["", "## 环节明细", "", "| 分组 | 环节 | 结果 | 说明 |", "|---|---|---|---|"]
    badge = {"pass": "✅", "fail": "🔴", "warn": "⚠️", "skip": "⏭"}
    for s in rec["stages"]:
        L.append("| %s | %s | %s | %s |" % (s["group"], s["name"],
                                            badge.get(s["status"], "?"),
                                            (s["detail"] or "").replace("|", "\\|")[:120]))
    L += ["", "---", "",
          "回滚：`server_release.sh rollback`（默认取生产上最新备份）或指定本记录 `*.json` 里的 `backup_dir`。", ""]

    # 落盘位置：release 分支内（随分支提交、可追溯）+ 运行证据目录各一份
    outdir = args.outdir or os.path.join(run, "release")
    os.makedirs(outdir, exist_ok=True)
    mp = os.path.join(outdir, "%s.md" % args.stamp)
    jp = os.path.join(outdir, "%s.json" % args.stamp)
    with open(mp, "w", encoding="utf-8") as fh:
        fh.write("\n".join(L))
    with open(jp, "w", encoding="utf-8") as fh:
        json.dump(rec, fh, ensure_ascii=False, indent=2)

    # INDEX.md 每次从 JSON 全量重建：追加式写法会在并行/重跑时写重，重建永远幂等
    rows = []
    for f in sorted(os.listdir(outdir)):
        if f.endswith(".json") and f[:-5] != "INDEX":
            r = _load_json(os.path.join(outdir, f), {}) or {}
            if not r.get("stamp"):
                continue
            rows.append("| [%s](%s.md) | %s | `%s` | %s | %s | %d |" % (
                r.get("stamp"), r.get("stamp"),
                "回滚" if r.get("kind") == "rollback" else "发布",
                (r.get("release_branch") or "-").replace("release/", ""),
                (r.get("source_commit") or "-")[:8],
                "是" if r.get("deployed") else "否",
                (r.get("totals") or {}).get("selected", 0)))
    if rows:
        idx = ["# 服务端发布台账", "",
               "> 每次 `TS-Server-Release` 自动追加；按时间倒序看下面的表即可知道「哪次动了什么」。", "",
               "| 记录 | 类型 | release 分支 | 源提交 | 上线 | 注入条目 |", "|---|---|---|---|---|---|"]
        idx += sorted(rows, reverse=True)
        with open(os.path.join(outdir, "INDEX.md"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(idx) + "\n")

    print("发布记录：%s" % mp)
    print("机器可读：%s" % jp)
    return 0


# --------------------------------------------------------------------------- #
CSS = """
:root{--bg:#f6f7f9;--card:#fff;--ink:#1c2029;--dim:#6b7280;--line:#e5e7eb;
--ok:#12805c;--okbg:#e7f6ef;--warn:#9a6700;--warnbg:#fff6e0;--bad:#b42318;--badbg:#fdecea;
--skip:#5b6472;--skipbg:#eef0f3;--blue:#1d4ed8;--bluebg:#e8efff}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
font:14px/1.6 -apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif}
.wrap{max-width:1180px;margin:0 auto;padding:28px 22px 60px}
h1{font-size:22px;margin:0 0 4px;letter-spacing:.2px}
.sub{color:var(--dim);font-size:13px;margin-bottom:20px}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px;margin:18px 0 22px}
.kpi{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
.kpi .k{color:var(--dim);font-size:12px;margin-bottom:6px}
.kpi .v{font-size:24px;font-weight:650;line-height:1.15}
.kpi .n{color:var(--dim);font-size:12px;margin-top:4px}
.kpi.ok .v{color:var(--ok)}.kpi.warn .v{color:var(--warn)}.kpi.bad .v{color:var(--bad)}
.card{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:18px 20px;margin:16px 0}
.card h2{font-size:15px;margin:0 0 12px;font-weight:650}
.card h2 .hint{font-weight:400;color:var(--dim);font-size:12px;margin-left:8px}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{text-align:left;padding:7px 10px;border-bottom:1px solid var(--line);vertical-align:top}
th{color:var(--dim);font-weight:600;font-size:12px;background:#fbfbfc}
tr:last-child td{border-bottom:none}
code{background:#f2f3f5;padding:1px 5px;border-radius:4px;font-size:12px}
.chip{display:inline-block;padding:1px 8px;border-radius:999px;font-size:12px;font-weight:600;white-space:nowrap}
.pass{background:var(--okbg);color:var(--ok)}.fail{background:var(--badbg);color:var(--bad)}
.warnb{background:var(--warnbg);color:var(--warn)}.skipb{background:var(--skipbg);color:var(--skip)}
.bar{display:flex;height:10px;border-radius:6px;overflow:hidden;background:#eef0f3;margin:6px 0 2px}
.bar span{display:block;height:100%}
.legend{color:var(--dim);font-size:12px;margin-top:4px}
.foot{color:var(--dim);font-size:12px;margin-top:26px;text-align:center}
.mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
.flow{display:flex;flex-wrap:wrap;gap:6px;align-items:center}
.step{border:1px solid var(--line);border-radius:8px;padding:5px 9px;background:#fdfdfe;font-size:12px}
.arrow{color:#c3c8d0}
"""


def cmd_html(args) -> int:
    """把一次运行渲染成一页看板（自包含，无外链）。

    为什么不用 Jenkins 插件：本机没装 htmlpublisher；而且「一页看完」比在
    构建页里翻 12 个 stage 的日志更接近「强可视化」的诉求。
    页面同时归档进 evidence/ 和 userContent（固定地址，可收藏）。
    """
    run = os.path.abspath(args.run)
    meta = _load_json(os.path.join(run, "release", "meta.json"), {}) or {}
    health = _load_json(os.path.join(run, "release", "health.json"), {}) or {}
    stages = []
    sdir = os.path.join(run, "stages")
    if os.path.isdir(sdir):
        for f in sorted(os.listdir(sdir)):
            if f.endswith(".json"):
                s = _load_json(os.path.join(sdir, f))
                if s:
                    stages.append(s)
    stages.sort(key=lambda s: (s.get("ts", 0), s.get("name", "")))

    diffs = []
    ddir = os.path.join(run, "release", "diff")
    if os.path.isdir(ddir):
        for f in sorted(os.listdir(ddir)):
            if f.endswith(".diff.json"):
                d = _load_json(os.path.join(ddir, f))
                if d:
                    diffs.append(d)

    n_pass = sum(1 for s in stages if s.get("status") == "pass")
    n_warn = sum(1 for s in stages if s.get("status") == "warn")
    n_fail = sum(1 for s in stages if s.get("status") == "fail")
    sel_total = sum(d["counts"]["selected"] for d in diffs)
    chg_total = sum(d["counts"]["changed"] for d in diffs)
    new_total = sum(d["counts"]["only_local"] for d in diffs)

    if not stages:
        verdict, vclass = "未开始 / 无环节记录", ""
    elif n_fail:
        verdict, vclass = "%d 个环节失败" % n_fail, "bad"
    elif n_warn:
        verdict, vclass = "%d 个环节通过 · %d 项需关注" % (n_pass, n_warn), "warn"
    else:
        verdict, vclass = "%d 个环节全部通过" % n_pass, "ok"

    def esc(x):
        return (str(x) if x is not None else "").replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

    H = ["<!DOCTYPE html><html lang='zh-CN'><head><meta charset='utf-8'>",
         "<meta name='viewport' content='width=device-width,initial-scale=1'>",
         "<title>服务端发布看板 · %s</title><style>%s</style></head><body><div class='wrap'>" % (esc(meta.get("stamp", "")), CSS),
         "<h1>服务端发布看板</h1>",
         "<div class='sub'>%s #%s · %s · 目标：%s</div>" % (
             esc(meta.get("job", "-")), esc(meta.get("build", "-")),
             esc(health.get("finished_at") or meta.get("started_at") or "-"),
             esc(meta.get("target", "正式服")))]

    H.append("<div class='kpis'>")
    H.append("<div class='kpi %s'><div class='k'>结论</div><div class='v'>%s</div><div class='n'>%d 环节 · 通过 %d / 关注 %d / 失败 %d</div></div>"
             % (vclass, esc(verdict), len(stages), n_pass, n_warn, n_fail))
    H.append("<div class='kpi'><div class='k'>release 分支</div><div class='v mono' style='font-size:15px'>%s</div><div class='n'>源提交 <code>%s</code></div></div>"
             % (esc((meta.get("release_branch") or "-").replace("release/", "")),
                esc((meta.get("source_commit") or "-")[:8])))
    H.append("<div class='kpi'><div class='k'>将注入条目</div><div class='v'>%d</div><div class='n'>变更 %d · 新增 %d · 仅线上 %d</div></div>"
             % (sel_total, chg_total, new_total,
                sum(d["counts"]["only_prod"] for d in diffs)))
    H.append("<div class='kpi %s'><div class='k'>上线</div><div class='v'>%s</div><div class='n'>重启：%s</div></div>"
             % ("ok" if meta.get("deployed") else "",
                "已上线" if meta.get("deployed") else "未上线",
                esc(meta.get("restart", "-"))))
    H.append("</div>")

    # 环节流水线
    H.append("<div class='card'><h2>环节流水线<span class='hint'>按执行顺序；黄=需关注，红=失败，灰=跳过</span></h2><div class='flow'>")
    for i, s in enumerate(stages):
        st = s.get("status") or "skip"
        cls = {"pass": "pass", "fail": "fail", "warn": "warnb", "skip": "skipb"}.get(st, "skipb")
        if i:
            H.append("<span class='arrow'>→</span>")
        H.append("<span class='step'><span class='chip %s'>%s</span> %s</span>"
                 % (cls, {"pass": "✓", "fail": "✗", "warn": "!", "skip": "–"}.get(st, "–"), esc(s.get("name"))))
    H.append("</div></div>")

    # 环节表格
    H.append("<div class='card'><h2>环节明细</h2><table><thead><tr><th>分组</th><th>环节</th><th>结果</th><th>耗时</th><th>说明</th></tr></thead><tbody>")
    for s in stages:
        st = s.get("status") or "skip"
        cls = {"pass": "pass", "fail": "fail", "warn": "warnb", "skip": "skipb"}.get(st, "skipb")
        word = {"pass": "通过", "fail": "失败", "warn": "关注", "skip": "跳过"}.get(st, st)
        H.append("<tr><td>%s</td><td>%s</td><td><span class='chip %s'>%s</span></td><td>%s</td><td>%s</td></tr>"
                 % (esc(s.get("group")), esc(s.get("name")), cls, word,
                    ("%.1fs" % float(s.get("duration") or 0)) if s.get("duration") else "-",
                    esc(s.get("detail"))))
    H.append("</tbody></table></div>")

    # 差异
    if diffs:
        H.append("<div class='card'><h2>与线上逐条目差异<span class='hint'>判据=同名同 CRC；仅线上存在的条目永不删除</span></h2>")
        for d in diffs:
            c = d["counts"]
            tot = max(c["selected"] + c["excluded"], 1)
            H.append("<div style='margin-bottom:16px'><div style='font-weight:600;margin-bottom:6px' class='mono'>%s</div>" % esc(d["name"]))
            H.append("<div class='bar'><span style='width:%.1f%%;background:#12805c'></span><span style='width:%.1f%%;background:#c3c8d0'></span></div>"
                     % (100.0 * c["selected"] / tot, 100.0 * c["excluded"] / tot))
            H.append("<div class='legend'>将注入 <b>%d</b>（class %d · 资源 %d） · 被排除 %d · 仅线上 %d</div>"
                     % (c["selected"], c["selected_class"], c["selected_res"], c["excluded"], c["only_prod"]))
            if d.get("groups"):
                H.append("<table style='margin-top:8px'><thead><tr><th>包</th><th>条目数</th></tr></thead><tbody>")
                for k, v in list(d["groups"].items())[:8]:
                    H.append("<tr><td class='mono'>%s</td><td>%d</td></tr>" % (esc(k), v))
                H.append("</tbody></table>")
            H.append("</div>")
        H.append("</div>")

    # 自检
    if health:
        H.append("<div class='card'><h2>上线自检<span class='hint'>%s</span></h2><table><thead><tr><th>检查</th><th>结果</th></tr></thead><tbody>"
                 % esc(health.get("verdict", "")))
        for k, v in (health.get("checks") or {}).items():
            H.append("<tr><td>%s</td><td>%s</td></tr>" % (esc(k), esc(v)))
        H.append("</tbody></table></div>")

    H.append("<div class='foot'>证据目录 <code>%s</code> · 发布记录 <code>server_game/deploy/releases/</code></div>"
             % esc(run))
    H.append("</div></body></html>")

    os.makedirs(os.path.dirname(os.path.abspath(args.out)) or ".", exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        fh.write("\n".join(H))
    print("看板已写出：%s" % args.out)
    return 0


# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description="服务端发布辅助（清单/差异/记录/看板）")
    sub = ap.add_subparsers(dest="cmd", required=True)

    m = sub.add_parser("manifest", help="导出 jar 条目 CRC 清单")
    m.add_argument("jar")
    m.add_argument("out")
    m.set_defaults(func=cmd_manifest)

    d = sub.add_parser("diff", help="逐条目比对本地构建与线上 jar")
    d.add_argument("--local", required=True)
    d.add_argument("--remote", required=True)
    d.add_argument("--outdir", required=True)
    d.add_argument("--name", required=True)
    d.add_argument("--include", default="")
    d.add_argument("--exclude", default=DEFAULT_EXCLUDE)
    d.set_defaults(func=cmd_diff)

    v = sub.add_parser("verify-selected", help="注入后复核 selected 条目的 CRC")
    v.add_argument("--local", required=True)
    v.add_argument("--remote", required=True)
    v.add_argument("--selected", required=True)
    v.set_defaults(func=cmd_verify_selected)

    r = sub.add_parser("record", help="生成发布记录与台账")
    r.add_argument("--run", required=True)
    r.add_argument("--stamp", required=True)
    r.add_argument("--outdir", default=None)
    r.add_argument("--rollback", action="store_true")
    r.set_defaults(func=cmd_record)

    h = sub.add_parser("html", help="生成发布看板 HTML")
    h.add_argument("--run", required=True)
    h.add_argument("--out", required=True)
    h.set_defaults(func=cmd_html)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
