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

**没开着的 profile 也能用**（2026-10-21 新增，用户要求「这个号额度空了就让 AdsPower 开另一个」）
------------------------------------------------------------------------------------------------
`user/list` 要付费，但 `browser/active` / `browser/start` / `browser/stop` 免费可用
（实测 AdsPower Global 7.7.18 + 免费版）。profile 的 user_id 从本地缓存目录反推：
    ~/Library/Application Support/adspower_global/cwd_global/source/cache/<user_id>_<hash>/
这个目录只有**被启动过**的 profile 才有 —— 对「换号」来说反而是好事：能从没登录过
ChatGPT 的空 profile 里挑，只会白起一个浏览器。挑之前先数一遍该 profile 的 chatgpt
cookie 条数（只读 sqlite，不解密），条数为 0 的直接排到最后。

🔴 本地 API 按秒限流，超了**不是** HTTP 429，而是 200 + `{"code":-1,"msg":"Too many
   request per second..."}`，所以 api_get() 既限速又按文案重试。

用法
----
    python3 scripts/image/find_browser_cdp.py                 # 打印「best」端口
    python3 scripts/image/find_browser_cdp.py --json          # 机器可读
    python3 scripts/image/find_browser_cdp.py --require-chatgpt   # 只认已开 chatgpt 页的端口
    python3 scripts/image/find_browser_cdp.py --profiles      # 列出 AdsPower 里的候选号（含 cookie 数）
    python3 scripts/image/find_browser_cdp.py --launch k1hiv2p8   # 现开一个 profile 并打印端口
    python3 scripts/image/find_browser_cdp.py --stop k1hiv2p8     # 关掉（自己起的自己收）

找到后：
    gen_chatgpt_web.py --image ... --prompt-file ... --out ... --reuse-cdp --port <端口>

退出码：0 找到 / 1 没找到
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

# 认这些进程名/命令行片段：AdsPower 的两个品牌（全球版/国内版）+ 它自带的 Chromium
PATTERNS = ("SunBrowser", "adspower", "AdsPower")
LOCAL = "127.0.0.1"

# ── AdsPower 本地 API ────────────────────────────────────────────────────────
# 7.7.18 默认监听 50325；装了国内版/改了端口就用 ADSPOWER_API 覆盖。
ADSPOWER_API = os.environ.get("ADSPOWER_API", "http://127.0.0.1:50325").rstrip("/")
ADSPOWER_CACHE = (Path.home() / "Library/Application Support/adspower_global"
                  / "cwd_global" / "source" / "cache")
# 服务端 1 req/s；留点余量，否则拿到的全是 "Too many request per second"
API_MIN_INTERVAL = float(os.environ.get("ADSPOWER_API_INTERVAL", "1.15"))
# cache 目录名 = <user_id>_<hash>，user_id 是 6~16 位小写字母数字
_PROFILE_DIR = re.compile(r"^([a-z0-9]{6,16})_[a-z0-9]+$")
_last_call = 0.0


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


# ── AdsPower 本地 API（免费版可用：active / start / stop；user/list 要付费） ──

def api_get(path: str, timeout: float = 25.0, retries: int = 3) -> dict:
    """调本地 API，返回原始 JSON（code=0 成功；失败也返回，让上层读到 msg 原文）。

    🔴 限流是「200 + code=-1」而不是 429 —— 只看 HTTP 状态会把它当成功。
    """
    global _last_call
    url = f"{ADSPOWER_API}/{path.lstrip('/')}"
    body: dict = {"code": -1, "msg": "unreachable"}
    for i in range(retries):
        wait = API_MIN_INTERVAL - (time.time() - _last_call)
        if wait > 0:
            time.sleep(wait)
        try:
            with urllib.request.urlopen(url, timeout=timeout) as r:
                body = json.loads(r.read().decode("utf-8", "replace"))
        except Exception as e:                               # noqa: BLE001
            return {"code": -1, "msg": f"{type(e).__name__}: {e}"}
        finally:
            _last_call = time.time()
        if body.get("code") == 0:
            return body
        if "Too many request" in str(body.get("msg", "")) and i + 1 < retries:
            time.sleep(1.4)
            continue
        return body
    return body


def adspower_alive() -> bool:
    """AdsPower 客户端是否在线（不在线就别指望能开号）。"""
    return api_get("status", timeout=4, retries=1).get("code") == 0


def adspower_state(user_id: str) -> tuple[str, int]:
    """→ (status, debug_port)。status ∈ Active / Inactive / missing（API 不认识这个 id）。"""
    b = api_get(f"api/v1/browser/active?user_id={user_id}", timeout=10)
    if b.get("code") != 0:
        msg = str(b.get("msg", ""))
        return ("missing" if "does not exist" in msg else "error"), 0
    data = b.get("data") or {}
    port = int(data.get("debug_port") or 0)
    if not port and isinstance(data.get("ws"), dict):
        m = re.search(r":(\d+)/devtools/", str(data["ws"].get("puppeteer", "")))
        port = int(m.group(1)) if m else 0
    return str(data.get("status") or "").lower() or "unknown", port


def adspower_start(user_id: str) -> tuple[bool, int, str]:
    """启一个 profile → (ok, debug_port, 说明)。已经开着时 API 会直接回同一个端口。"""
    b = api_get(f"api/v1/browser/start?user_id={user_id}", timeout=90)
    if b.get("code") != 0:
        return False, 0, str(b.get("msg") or "启动失败")
    data = b.get("data") or {}
    port = int(data.get("debug_port") or 0)
    if not port and isinstance(data.get("ws"), dict):
        m = re.search(r":(\d+)/devtools/", str(data["ws"].get("puppeteer", "")))
        port = int(m.group(1)) if m else 0
    if not port:
        return False, 0, "启动成功但没拿到 debug_port"
    return True, port, "ok"


def adspower_stop(user_id: str) -> bool:
    b = api_get(f"api/v1/browser/stop?user_id={user_id}", timeout=45)
    return b.get("code") == 0


# ── profile 发现：付费版才有的 user/list，用本地缓存目录反推 ──────────────

def adspower_profile_dirs() -> dict[str, Path]:
    """{user_id: 缓存目录}。只包含**被启动过**的 profile —— 也正是我们要的候选集。"""
    out: dict[str, Path] = {}
    try:
        for d in ADSPOWER_CACHE.iterdir():
            if not d.is_dir():
                continue
            m = _PROFILE_DIR.match(d.name)
            if m and (d / "Default").is_dir():
                out.setdefault(m.group(1), d)
    except Exception:                                        # noqa: BLE001
        return {}
    return out


def pid_on_port(port: int) -> int | None:
    """谁在监听这个 CDP 端口。lsof 在沙箱里可用（ps 不一定）。"""
    out = sh(["lsof", "-nP", f"-iTCP:{port}", "-sTCP:LISTEN", "-t"])
    for line in out.splitlines():
        s = line.strip()
        if s.isdigit():
            return int(s)
    return None


_PORT_UID_CACHE: dict[int, str | None] = {}


def adspower_uid_for_port(port: int) -> str | None:
    """CDP 端口 → AdsPower 的 user_id（认不出来返回 None）。

    为什么需要这个：换号链 ①「接入已经开着的 SunBrowser」手里只有端口，台账就把它记成
    `cdp:<port>` —— 同一个号换个端口号就成了「另一个号」，它的额度封锁 / 7 天停用标记
    **全部不生效**。2026-10-30 被封的 992694856@qq.com 就是这么继续被用了 12 张
    （事件流水里是 cdp:50609，历史记录里是同一个 profile 的 15 个新对话）。

    判定顺序（都不猜，只认证据）：
      ① lsof 找出监听端口的 pid，再看它打开的文件里有没有
         `adspower_global/cwd_global/source/cache/<user_id>_<hash>/`
      ② 退一步读各 profile 根目录的 `DevToolsActivePort`（浏览器启动时自己写的端口）
    """
    if port in _PORT_UID_CACHE:
        return _PORT_UID_CACHE[port]
    uid: str | None = None
    pid = pid_on_port(port)
    if pid:
        out = sh(["lsof", "-p", str(pid), "-Fn"])
        for line in out.splitlines():
            if "cwd_global/source/cache/" not in line:
                continue
            tail = line.rsplit("cwd_global/source/cache/", 1)[-1]
            m = _PROFILE_DIR.match(tail.split("/", 1)[0])
            if m:
                uid = m.group(1)
                break
    if not uid:
        for u, d in adspower_profile_dirs().items():
            try:
                first = (d / "DevToolsActivePort").read_text(
                    encoding="utf-8", errors="replace").splitlines()[:1]
            except Exception:                                # noqa: BLE001
                continue
            if first and first[0].strip().isdigit() and int(first[0].strip()) == port:
                uid = u
                break
    _PORT_UID_CACHE[port] = uid
    return uid


def chatgpt_cookie_count(profile_dir: Path) -> int:
    """数该 profile 里 chatgpt.com 的 cookie 条数（只读，不解密内容）。

    >0 ≈ 这个号登录过 ChatGPT；=0 基本等于「拉起来也得先手动登录」，排最后。
    🔴 用 mode=ro 打开，绝不动用户的 cookie 库；DB 被 Chrome 独占时退化成拷副本。
    """
    src = profile_dir / "Default" / "Cookies"
    if not src.is_file():
        return -1
    sql = ("select count(*) from cookies where host_key like '%chatgpt.com%' "
           "or host_key like '%openai.com%'")
    for path, cleanup in ((src, False), (None, True)):
        try:
            if cleanup:                       # 第二次：拷到临时文件再读（WAL 被锁时）
                import shutil
                import tempfile
                tmp = Path(tempfile.mkdtemp(prefix="ck_")) / "Cookies"
                shutil.copy2(src, tmp)
                for extra in ("Cookies-wal", "Cookies-journal"):
                    if (src.parent / extra).is_file():
                        shutil.copy2(src.parent / extra, tmp.parent / extra)
                path = tmp
            con = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=2.0)
            try:
                return int(con.execute(sql).fetchone()[0])
            finally:
                con.close()
        except Exception:                                    # noqa: BLE001
            continue
    return -1


def adspower_profiles(with_state: bool = False) -> list[dict]:
    """候选 profile 列表，按「值得先试」排序。

    排序键：chatgpt cookie 越多越靠前（登录态越完整），其次最近改过的目录（刚用过≈还活着）。
    with_state=True 时额外逐个调 active（每个 1.1s，别在批量场景里开）。
    """
    dirs = adspower_profile_dirs()
    rows: list[dict] = []
    for uid, d in dirs.items():
        try:
            mtime = d.stat().st_mtime
        except OSError:
            mtime = 0.0
        rows.append({"user_id": uid, "dir": d, "cookies": chatgpt_cookie_count(d),
                     "mtime": mtime})
    rows.sort(key=lambda r: (-r["cookies"], -r["mtime"]))
    if with_state:
        for r in rows:
            status, port = adspower_state(r["user_id"])
            r["status"], r["port"] = status, port
    return rows


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="反查 AdsPower/SunBrowser 的 CDP 端口")
    ap.add_argument("--json", action="store_true", help="输出 JSON")
    ap.add_argument("--require-chatgpt", action="store_true", help="只接受已打开 chatgpt.com 的端口")
    ap.add_argument("--all", action="store_true", help="列出全部候选，不只 best")
    ap.add_argument("--profiles", action="store_true",
                    help="列出 AdsPower 里可换的号（user_id / chatgpt cookie 数 / 是否在跑）")
    ap.add_argument("--launch", metavar="USER_ID", help="现开一个 AdsPower profile 并打印 CDP 端口")
    ap.add_argument("--stop", metavar="USER_ID", help="关掉一个 AdsPower profile")
    args = ap.parse_args(argv)

    if args.profiles:
        if not adspower_alive():
            print(f"AdsPower 本地 API 不可达（{ADSPOWER_API}）—— 先打开 AdsPower 客户端",
                  file=sys.stderr)
            return 1
        rows = adspower_profiles()
        if not rows:
            print(f"{ADSPOWER_CACHE} 下没有候选 profile（AdsPower 里先手动开一次那个号）",
                  file=sys.stderr)
            return 1
        print(f"AdsPower {ADSPOWER_API} 候选号 {len(rows)} 个（按值得先试排序）：")
        for r in rows:
            status, port = adspower_state(r["user_id"])
            flag = "✅" if r["cookies"] > 0 else "⚠"
            print(f"  {flag} {r['user_id']:<10} chatgpt_cookie={r['cookies']:<4} "
                  f"{status}{f' 端口 {port}' if port else ''}")
        return 0

    if args.launch:
        ok, port, msg = adspower_start(args.launch)
        if not ok:
            print(f"启动失败：{msg}", file=sys.stderr)
            return 1
        print(f"{args.launch} 已启动，CDP {port}")
        print(f"用：--reuse-cdp --port {port}")
        return 0

    if args.stop:
        ok = adspower_stop(args.stop)
        print(f"{args.stop} 已关闭" if ok else f"{args.stop} 关闭失败")
        return 0 if ok else 1


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
