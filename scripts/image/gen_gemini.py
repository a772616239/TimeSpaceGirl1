#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_gemini.py —— 用 gemini.google.com 的登录态出图（Nano Banana / 图像生成）。

和 gen_chatgpt_web.py 是兄弟：**接口、退出码、失败落盘格式完全一致**，
所以 xz_restyle.py 只需要换一个脚本路径（GEN_PROVIDER=gemini），
上层的 prepare/postprocess/verify/publish/compress/patch_build 一个字都不用改。

用法
----
    gen_gemini.py --image ref.png --prompt-file p.txt --out gen.png
    gen_gemini.py --image ref.png --prompt-file p.txt --out gen.png --reuse-cdp --port 61261
    gen_gemini.py --check-only            # 只做连通性 + 登录态预检
    gen_gemini.py --text-ping --port 61261 --prompt-file hello.txt --out ping.json
                                          # 纯文本心跳：不建图，只发一句话等一句回复

退出码（与 chatgpt 版对齐）
    0 拿到图 / 3 需要登录或被拦（可重试）/ 4 额度用尽（换号或等）/ 5 模型拒绝（换号无用）/ 1 其他

🔴 2026-10-30 起每次生成前都过 `gen_pace.py` 的节奏闸门（按账号的最小间隔/小时上限/日上限）。
   Google 账号是因为跑太快被封的：实测相邻两张间隔中位数 46 秒、峰值一小时 32 张。
   想改节奏看 TSG_* 环境变量（gen_pace.py 顶部注释），**别直接把闸门删掉**。

为什么不复用 gen_chatgpt_web.py 的换号链
----------------------------------------
那条链绑死了 chatgpt.com 的 cookie 判据（find_browser_cdp 里数 chatgpt_tabs）与 AdsPower 台账口径。
Gemini 这边是另一套登录态（Google 账号），混在一起会把「有 chatgpt 登录的号」当成可用号，
结果连上去才发现 gemini 没登录。所以这里只做「挑一个开着 gemini 标签的端口」，换号交给上层重试。
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
DRIVER = HERE / "gemini_web_driver.mjs"
PW_DIRS = [
    Path("/Users/wangxufeng/.workbuddy/binaries/node/workspace/node_modules/playwright-core"),
    Path.home() / "node_modules/playwright-core",
]

RC_OK, RC_LOGIN, RC_QUOTA, RC_REFUSED, RC_FAIL = 0, 3, 4, 5, 1
# 7 = 台账说这个号还在冷却期内 ⇒ 不开新对话（与 gen_chatgpt_web 的 _GEM_RC 对齐）
RC_BLOCKED = 7


def log(*a: object) -> None:
    print(*a, flush=True)


def find_node() -> str | None:
    for c in (os.environ.get("NODE_BIN"), shutil.which("node"),
              "/Users/wangxufeng/.workbuddy/binaries/node/versions/22.22.2-6/bin/node",
              "/usr/local/bin/node"):
        if c and Path(c).is_file():
            return c
    return None


def find_pw() -> str | None:
    for d in PW_DIRS:
        if (d / "index.js").is_file():
            return str(d)
    return None


def probe(port: int) -> dict | None:
    """读 /json/version：能读到才算真活着（端口开着但 CDP 不响应的情况很常见）。"""
    import urllib.error
    import urllib.request
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/json/version", timeout=4) as r:
            return json.loads(r.read())
    except (urllib.error.URLError, OSError, json.JSONDecodeError):
        return None


def cdp_pages(port: int) -> list[str]:
    import urllib.request
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/json", timeout=4) as r:
            return [t.get("url", "") for t in json.loads(r.read())]
    except Exception:
        return []


def listen_ports() -> list[int]:
    """列出 Chrome / SunBrowser 正在监听的本地端口（CDP 端口只会开在这两类进程上）。

    🔴 别用「9200-9400 + 50000-65000 逐个探」：本机上是 1.5 万次 HTTP 探测，
       冷启动十几秒起步，而且碰到「端口开着但不响应 CDP」的会把超时全吃掉。
       lsof 一次就够，拿到候选再逐个 /json/version 验证。
    """
    try:
        out = subprocess.run(["lsof", "-nP", "-iTCP", "-sTCP:LISTEN"],
                             capture_output=True, text=True, timeout=20).stdout
    except Exception:
        return []
    ports: list[int] = []
    for line in out.splitlines()[1:]:
        parts = line.split()
        if len(parts) < 9:
            continue
        cmd = " ".join(parts[:2]).lower()
        # 🔴 lsof 的 COMMAND 列只给 9 个字符：AdsPower 的浏览器显示成 `SunBrowse`，
        #    所以只能按前缀匹配，不能写全名（写 "sunbrowser" 会一个都匹配不上）。
        if not any(cmd.startswith(k) for k in ("sunbrow", "chrome", "chromium", "ads")):
            continue
        name = parts[8]
        if ":" not in name:
            continue
        try:
            p = int(name.rsplit(":", 1)[1])
        except ValueError:
            continue
        if p not in ports:
            ports.append(p)
    return ports


def auto_ports() -> list[int]:
    """挑端口：优先「tab 里已经开着 gemini」的，其次端口小的（稳定）。

    🔴 不要用 connectOverCDP(http://...) 那种「连上去再说」的判断 —— AdsPower 的
       /json/version 会把人指到一个没监听的端口上。这里只用 HTTP 探活 + 看 tab 列表。
    """
    seed = os.environ.get("CDP_PORTS", "")
    cand: list[int] = [int(x) for x in seed.replace(",", " ").split() if x.strip().isdigit()]
    for p in listen_ports():
        if p not in cand and probe(p):
            cand.append(p)
    if not cand:                      # lsof 也没给出东西：退回粗扫（少见，只在权限受限时）
        for p in list(range(9200, 9400)) + list(range(50000, 65000, 7)):
            if probe(p):
                cand.append(p)
    scored = []
    for p in cand:
        urls = cdp_pages(p)
        g = sum(1 for u in urls if "gemini.google.com" in u)
        scored.append((g, p))
    scored.sort(key=lambda t: (-t[0], t[1]))
    return [p for _, p in scored]


def read_fail(out: Path) -> dict:
    p = Path(str(out) + ".fail.json")
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}


def run_driver(args, ref: Path | None, prompt_file: Path, out: Path, node: str, pw: str,
               port: int, text_ping: bool = False) -> int:
    out.parent.mkdir(parents=True, exist_ok=True)
    out.unlink(missing_ok=True)
    Path(str(out) + ".fail.json").unlink(missing_ok=True)
    env = dict(os.environ)
    # 🔴 driver 连 127.0.0.1，绝不能走 HTTP_PROXY（会 502）
    env["NO_PROXY"] = "127.0.0.1,localhost"
    env["no_proxy"] = "127.0.0.1,localhost"
    env["PW_KEEP_BROWSER"] = "1"          # 窗口是用户自己的浏览器，只断不关
    cmd = [node, str(DRIVER), "--cdp", f"http://127.0.0.1:{port}",
           "--prompt-file", str(prompt_file), "--out", str(out),
           "--timeout", str(args.timeout), "--pw", pw]
    if text_ping:
        cmd.append("--text-ping")
    if ref:
        cmd += ["--image", str(ref)]
    log(f"   driver: gemini_web_driver  port={port}"
        f"  {'文本心跳' if text_ping else 'ref=' + (ref.name if ref else '(无，纯文生图)')}")
    return supervise(cmd, args.timeout + 120, port, out, env)


def supervise(cmd: list[str], timeout_s: int, port: int, out: Path, env: dict | None = None) -> int:
    """跑 node 驱动，同时盯 CDP 端口。

    🔴 2026-10-26 事故：18:38 那台 53912 的浏览器被关掉（`port=53912 closed=True`），
       但 driver 在轮询循环里只等图、不查连接，硬等满 `--timeout 300` 才发现没图 ——
       整条队列白躺 5 分钟（18:38:18 → 18:43:32）才换下一台。
       这里在父进程侧每 3s 探一次 /json/version，端口连续两次不可达就杀子进程、按 rc=3
       （需要登录/被拦）上报，让上层立刻把这个端口标 unusable 并换号。
    """
    try:
        p = subprocess.Popen(cmd, env=env if env is not None else dict(os.environ))
    except OSError as e:
        log(f"   🔴 driver 起不来：{e}")
        return RC_FAIL
    deadline = time.time() + timeout_s
    miss = 0
    while True:
        try:
            return p.wait(timeout=3)
        except subprocess.TimeoutExpired:
            pass
        if time.time() > deadline:
            log(f"   🔴 driver 超时（{timeout_s}s）→ 杀掉")
            p.kill()
            p.wait()
            return RC_FAIL
        if probe(port):
            miss = 0
            continue
        miss += 1
        if miss >= 2:
            log(f"   🔴 端口 {port} 已断开（浏览器被关/崩了）→ 立刻收工，不再空等超时")
            p.kill()
            p.wait()
            try:
                Path(str(out) + ".fail.json").write_text(
                    json.dumps({"reason": "browser-closed", "port": port,
                                "message": f"CDP 端口 {port} 在等图期间消失（浏览器被关闭或崩溃）",
                                "at": time.strftime("%Y-%m-%dT%H:%M:%S")}, ensure_ascii=False, indent=2),
                    encoding="utf-8")
            except OSError:
                pass
            return RC_LOGIN
        time.sleep(1)


def map_rc(rc: int, out: Path) -> int:
    if rc == 0 and out.is_file():
        log(f"   ✅ 出图 {out.name}（{out.stat().st_size // 1024} KB）")
        return RC_OK
    detail = read_fail(out)
    msg = (detail.get("message") or "").replace("\n", " ")[:180]
    if rc == 4:
        log("   🔴 gemini 返回额度/频率受限")
        log(f"      站点原文：{msg or '(未取到)'}")
        if detail.get("reset"):
            log(f"      重置提示：{detail['reset']}")
        return RC_QUOTA
    if rc == 5:
        log("   🔴 模型拒绝生成（换号无用：同一套策略）")
        log(f"      站点原文：{msg or '(未取到)'}")
        return RC_REFUSED
    if rc == 3:
        # 🔴 「号被停用」和「未登录」的处置完全不同：前者换号（重登也没用），后者重登。
        #    驱动会落 reason=account-restricted（落在 myaccount.google.com/restrictions 页）。
        if str(detail.get("reason") or "") == "account-restricted":
            log("   🔴 Google 账号已被停用/受限（不是登录态问题，重登救不回来）")
            log("      处置：这个号别再用 —— 换号，并把出图节奏降下来（gen_pace.py 那两道闸）")
            log(f"      站点原文：{msg or '(未取到)'}")
            return RC_LOGIN
        log("   ⚠ 需要登录 / 被拦（换一个已登录 Google 的浏览器再试）")
        log(f"      站点原文：{msg or '(未取到)'}")
        return RC_LOGIN
    log(f"   🔴 driver rc={rc}，未拿到图")
    if msg:
        log(f"      {msg}")
    return RC_FAIL


def _ledger_block(account: str) -> tuple[object, str]:
    """(解封时间 or None, 说明)。台账读不出来一律当作「没封锁」，绝不因台账故障停画。"""
    kind = account.split(":", 1)[0]
    ident = account.split(":", 1)[1] if ":" in account else ""
    if kind not in ("adspower", "chrome", "sunbrowser") or not ident:
        return None, "不是账号标识，无封锁可查"
    try:
        if str(HERE) not in sys.path:
            sys.path.insert(0, str(HERE))
        import provider_ledger as pl
        t = pl.blocked_until(kind, ident)
        return (t, "") if t else (None, "台账未封锁")
    except Exception as e:                                    # noqa: BLE001
        return None, f"台账不可读（{e}）"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--image", default="", help="参考图（i2i 换皮必给；不给就是纯文生图）")
    ap.add_argument("--prompt-file", default="", help="提示词文件")
    ap.add_argument("--out", default="", help="生成图落盘路径")
    ap.add_argument("--port", type=int, default=int(os.environ.get("CDP_PORT") or 0))
    ap.add_argument("--reuse-cdp", action="store_true", help="复用已开着的浏览器（默认就是复用）")
    ap.add_argument("--timeout", type=int, default=300, help="等图上限（秒）")
    ap.add_argument("--check-only", action="store_true", help="只做连通性与登录态预检")
    ap.add_argument("--text-ping", dest="text_ping", action="store_true",
                    help="纯文本心跳：不建图，只发一句话等一句回复（会话保活用，见 gen_pace.py）")
    ap.add_argument("--account", default=os.environ.get("TSG_ACCOUNT", ""),
                    help="限速记账用的账号标识（如 adspower:ktmrjhu）。留空按端口记")
    ap.add_argument("--no-pace", action="store_true", help="本次跳过节奏闸门（只在人工验证时用）")
    ap.add_argument("--ignore-ledger", action="store_true",
                    help="无视额度台账的封锁（人工确认台账记错了才用；"
                         "冷却期里新建对话正是被 Google 判「绕过用量限制」的动作）")
    ap.add_argument("--max-ports", type=int, default=3, help="一次最多试几个端口")
    args = ap.parse_args()

    # 🔴 冷却期内的号**不许新建对话** —— 连端口都不用找，直接退出。
    #    2026-10-30 复盘 992694856@qq.com：Google 的判罚原文是「试图绕过滥用保护」，
    #    触发它的正是「撞了上限 → 再开一个新对话要一次」。这条闸门就是拦这个动作。
    acct0 = (args.account or "").strip()
    if acct0 and not args.ignore_ledger:
        t, why = _ledger_block(acct0)
        if t:
            log(f"   ⛔ {acct0} 台账封锁到 {t:%m-%d %H:%M} ⇒ 不开新对话")
            log("      冷却期里再要一次，Google 记的就是「绕过用量限制」（判罚原文）")
            return RC_BLOCKED
        if why and why != "台账未封锁":
            log(f"   ⚠ {why}")

    node = find_node()
    if not node:
        log("🔴 找不到 node（换皮驱动需要 node 跑 playwright-core）")
        return RC_FAIL
    pw = find_pw()
    if not pw:
        log("🔴 找不到 playwright-core（npm i playwright-core 或设 PW_DIR）")
        return RC_FAIL
    if not DRIVER.is_file():
        log(f"🔴 缺驱动 {DRIVER}")
        return RC_FAIL

    ports = [args.port] if args.port else auto_ports()[: args.max_ports]
    if not ports:
        log("🔴 没找到任何可用的 CDP 端口：先打开一个已登录 Google 的 Chrome/AdsPower 窗口")
        return RC_LOGIN

    if args.check_only:
        for p in ports:
            urls = cdp_pages(p)
            g = [u for u in urls if "gemini.google.com" in u]
            log(f"  port {p}: CDP OK，tab {len(urls)} 个，gemini {'✓ ' + g[0][:70] if g else '✗ 未开'}")
        log(f"  驱动 {DRIVER.name}  pw={pw}")
        return RC_OK

    if not args.prompt_file or not args.out:
        log("🔴 需要 --prompt-file 与 --out")
        return RC_FAIL
    prompt_file = Path(args.prompt_file)
    out = Path(args.out)
    ref = Path(args.image) if args.image else None

    # ── 纯文本心跳：只发一句话，不建图 ────────────────────────────────────
    # 🔴 心跳**自己不过闸**：它就是用来「占位养会话」的，被限速等于没用。
    #    但它也不记账（不占用出图额度窗口），只记在 gen_pace 的 session 名下。
    if args.text_ping:
        rc = run_driver(args, None, prompt_file, out, node, pw, ports[0], text_ping=True)
        if rc == 0:
            log("   ✅ 心跳：有回复")
            return RC_OK
        if rc == 4:
            log("   ⚠ 心跳：Gemini 返回额度/频率受限（账号还在，只是被限了）")
            return RC_QUOTA
        if rc == 3:
            log("   ⚠ 心跳：需要登录（这台浏览器没有可用的 Google 登录态）")
            return RC_LOGIN
        return RC_FAIL

    # ── 节奏闸门 + 到点心跳（两者都不该阻断出图，失败就降级继续） ────────────
    # 顺序有讲究：**先心跳后过闸**。心跳是 5~30 秒的轻请求，过闸可能要等几分钟；
    # 反过来会先把出图的时间窗口占掉，再花几十秒去聊天，白白拉长等待。
    account = (args.account or "").strip() or f"port:{ports[0]}"

    # 没带账号标识（直接命令行 --port 11451 这种）：按端口反查是哪个 AdsPower 号，
    # 再拿它去过封锁检查。不反查就等于「同一台机器上的号换个端口就变成新号」，
    # 封锁和限速一起失效 —— 2026-10-30 封号就是这么发生的。
    if account.startswith("port:") and not args.ignore_ledger:
        try:
            if str(HERE) not in sys.path:
                sys.path.insert(0, str(HERE))
            import find_browser_cdp as fbc
            uid = fbc.adspower_uid_for_port(ports[0])
            if uid:
                account = f"adspower:{uid}"
                log(f"   端口 {ports[0]} → adspower:{uid}（限速与封锁按这个号记）")
        except Exception as e:                                # noqa: BLE001
            log(f"   ⚠ 端口反查账号失败（{e}）")

    # 🔴 冷却期内的号**不许新建对话** —— 不是「不记账」，是连 Gemini 页面都不打开。
    if not getattr(args, "ignore_ledger", False):
        t, why = _ledger_block(account)
        if t:
            log(f"   ⛔ {account} 台账封锁到 {t:%m-%d %H:%M} ⇒ 不开新对话")
            log("      冷却期里再要一次，Google 记的就是「绕过用量限制」（判罚原文）")
            return RC_BLOCKED

    try:
        if str(HERE) not in sys.path:
            sys.path.insert(0, str(HERE))
        import gen_pace as gp
        gp.maybe_heartbeat(ports[0], account=account, logf=log)
        if gp.gate("gemini", account, no_pace=args.no_pace, logf=log) == gp.RC_WAIT:
            log("   ⏸ 节奏闸门：本张不等了（这个号的今日/本小时节奏已用满），交给上层换号或下一轮")
            return RC_FAIL
    except Exception as e:                                    # noqa: BLE001
        log(f"   ⚠ 节奏闸门不可用（{e}）—— 本轮按不限速跑")

    last = RC_FAIL
    for p in ports:
        rc = run_driver(args, ref, prompt_file, out, node, pw, p)
        last = map_rc(rc, out)
        if last in (RC_OK,):
            return last
        # 额度用尽 / 模型拒绝：换端口也没用，直接抛给上层
        if last in (RC_QUOTA, RC_REFUSED):
            return last
        log(f"   ↪ 端口 {p} 没成，换下一个")
    return last


if __name__ == "__main__":
    raise SystemExit(main())
