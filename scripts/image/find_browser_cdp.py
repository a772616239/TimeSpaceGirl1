#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""找出「已经登录好的外部浏览器」的 CDP 端口（AdsPower / SunBrowser / 手动 Chrome）。

为什么需要这个
--------------
ChatGPT 的出图额度是**按账号**算的，一天的图出完了就得换号。最省事的换号方式是
让用户在指纹浏览器（AdsPower 的 SunBrowser）里登录另一个号，我们把 driver 接上去即可。

但拿端口不容易：
  * AdsPower 启动的 SunBrowser **命令行里没有** --remote-debugging-port（它 bind 一个随机
    高位端口），所以 `pgrep -fl 9333` 这类办法一无所获；
  * 免费版调不了 `/api/v1/user/list`（返回 "This feature is only available in paid
    subscriptions"），拿不到 profile 的 debug_port。
⇒ 只能从进程 + 监听端口反查：找 SunBrowser 进程 → lsof 出它 LISTEN 的端口 →
   逐个访问 /json/version 试出 CDP。

用法
----
    python3 scripts/image/find_browser_cdp.py                 # 打印「best」端口
    python3 scripts/image/find_browser_cdp.py --json          # 机器可读
    python3 scripts/image/find_browser_cdp.py --require-chatgpt   # 只认已开 chatgpt 页的端口

找到后：
    gen_chatgpt_web.py --image ... --prompt-file ... --out ... --reuse-cdp --port <端口>

退出码：0 找到 / 1 没找到
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.request

# 认这些进程名/命令行片段：AdsPower 的两个品牌（全球版/国内版）+ 它自带的 Chromium
PATTERNS = ("SunBrowser", "adspower", "AdsPower")
LOCAL = "127.0.0.1"


def sh(cmd: list[str]) -> str:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        return r.stdout
    except Exception:                                        # noqa: BLE001
        return ""


def candidate_pids() -> list[int]:
    """pgrep -fl 拿 pid（沙箱里 ps 不可用，但 pgrep/lsof 可用）。"""
    out = sh(["pgrep", "-fl", "|".join(PATTERNS)])
    pids: list[int] = []
    for line in out.splitlines():
        head = line.strip().split(" ", 1)[0]
        if head.isdigit():
            pids.append(int(head))
    return pids


def listening_ports(pid: int) -> list[int]:
    out = sh(["lsof", "-nP", "-p", str(pid), "-a", "-iTCP", "-sTCP:LISTEN"])
    ports: list[int] = []
    for line in out.splitlines()[1:]:
        parts = line.split()
        if not parts:
            continue
        addr = parts[-2] if len(parts) >= 2 else ""      # 形如 127.0.0.1:64757
        if ":" not in addr:
            continue
        p = addr.rsplit(":", 1)[1]
        if p.isdigit() and int(p) not in ports:
            ports.append(int(p))
    return ports


def get_json(port: int, path: str, timeout: float = 2.0):
    try:
        with urllib.request.urlopen(f"http://{LOCAL}:{port}{path}", timeout=timeout) as r:
            if r.status != 200:
                return None
            return json.loads(r.read().decode("utf-8", "replace"))
    except Exception:                                        # noqa: BLE001
        return None


def probe(port: int) -> dict | None:
    ver = get_json(port, "/json/version")
    if not isinstance(ver, dict) or "Browser" not in ver:
        return None
    pages = get_json(port, "/json/list") or []
    urls = [t.get("url", "") for t in pages if t.get("type") == "page"]
    return {
        "port": port,
        "browser": ver.get("Browser"),
        "pages": len(urls),
        "chatgpt_tabs": sum(1 for u in urls if "chatgpt.com" in u),
        "urls": urls[:12],
    }


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="反查 AdsPower/SunBrowser 的 CDP 端口")
    ap.add_argument("--json", action="store_true", help="输出 JSON")
    ap.add_argument("--require-chatgpt", action="store_true", help="只接受已打开 chatgpt.com 的端口")
    ap.add_argument("--all", action="store_true", help="列出全部候选，不只 best")
    args = ap.parse_args(argv)

    pids = candidate_pids()
    if not pids:
        print("没找到 AdsPower/SunBrowser 进程 —— 先在 AdsPower 里把浏览器打开", file=sys.stderr)
        return 1

    found, seen = [], set()
    for pid in pids:
        for port in listening_ports(pid):
            if port in seen:
                continue
            seen.add(port)
            info = probe(port)
            if info:
                info["pid"] = pid
                found.append(info)

    if args.require_chatgpt:
        found = [f for f in found if f["chatgpt_tabs"] > 0]
    if not found:
        print("进程在，但没试出 CDP 端口（可能该 profile 关掉了远程调试）", file=sys.stderr)
        return 1

    # best：优先「已开着 chatgpt.com 标签」的那个，其次端口最小（稳定）
    found.sort(key=lambda f: (-f["chatgpt_tabs"], f["port"]))
    best = found[0]

    if args.json:
        print(json.dumps({"best": best, "all": found} if args.all else best,
                         ensure_ascii=False, indent=2))
    else:
        print(f"best  port={best['port']}  {best['browser']}  页面 {best['pages']}  "
              f"chatgpt 标签 {best['chatgpt_tabs']}")
        if args.all:
            for f in found:
                print(f"  - {f['port']:6d}  {f['browser']}  tabs={f['pages']} "
                      f"chatgpt={f['chatgpt_tabs']}")
        print(f"\n用：--reuse-cdp --port {best['port']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
