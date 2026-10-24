#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Play 商店撞名初查：抓搜索页，抽出「应用标题 + 包名」，看有没有同名。

用法：
    python3 play_name_scan.py "Starhost" "群星列阵" ...
    python3 play_name_scan.py --hl ja --gl JP "群星の陣"

判定：标题（忽略大小写、去掉空格与 ®™）与候选**完全相等** ⇒ 撞名；
      否则只算「联想结果」，不影响注册，但要注意是否抢走搜索词。
不解析 JS 数据块，只吃 SSR 出来的 <a href="/store/apps/details?id=..."> 标题，
够用且不会被 Google 前端改版打穿。
"""
from __future__ import annotations

import argparse
import html
import re
import subprocess
import sys
import urllib.parse

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/120.0 Safari/537.36")

LINK_RE = re.compile(
    r'<a[^>]+href="/store/apps/details\?id=([A-Za-z0-9_.]+)[^"]*"[^>]*>(.*?)</a>',
    re.S,
)
TAG_RE = re.compile(r"<[^>]+>")


def norm(s: str) -> str:
    s = html.unescape(s or "")
    s = re.sub(r"[®™©]", "", s)
    s = re.sub(r"[\s\u3000]+", "", s)
    return s.strip().lower()


def fetch(q: str, hl: str, gl: str) -> str:
    url = ("https://play.google.com/store/search?q=" + urllib.parse.quote(q)
           + f"&c=apps&hl={hl}&gl={gl}")
    out = subprocess.run(["curl", "-sL", "-A", UA, url],
                         capture_output=True, text=True, timeout=60)
    return out.stdout


def scan(q: str, hl: str, gl: str, limit: int = 30) -> tuple[bool, list[tuple[str, str]]]:
    body = fetch(q, hl, gl)
    hits: list[tuple[str, str]] = []
    seen: set[str] = set()
    for pkg, inner in LINK_RE.findall(body):
        title = html.unescape(TAG_RE.sub(" ", inner)).strip()
        title = re.sub(r"\s+", " ", title)
        if not title or pkg in seen:
            continue
        seen.add(pkg)
        hits.append((title, pkg))
        if len(hits) >= limit:
            break
    exact = any(norm(t) == norm(q) for t, _ in hits)
    return exact, hits


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="+")
    ap.add_argument("--hl", default="en", help="界面语言，如 zh-CN / zh-TW / ja / de")
    ap.add_argument("--gl", default="US", help="国家码，如 CN / TW / JP / DE")
    ap.add_argument("--show", type=int, default=8, help="每个词打印前 N 条联想结果")
    a = ap.parse_args()

    bad = 0
    for q in a.names:
        exact, hits = scan(q, a.hl, a.gl)
        flag = "🔴 撞名" if exact else "🟢 无同名"
        print(f"\n[{q}]  {flag}   (hl={a.hl} gl={a.gl}, 抓到 {len(hits)} 条)")
        for t, p in hits[: a.show]:
            mark = " ← 同名" if norm(t) == norm(q) else ""
            print(f"    {t}  [{p}]{mark}")
        if exact:
            bad += 1
    print()
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
