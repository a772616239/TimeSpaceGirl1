#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""provider = chatgpt_web：用本机 Chrome 的登录态（cookie）驱动 chatgpt.com 出图。

✅ 状态：2026-10-20 端到端跑通（超值底板 856x2048 英雄带，出图 1201x1309，文字保真）。

⚠ 当天上午同一台机器上 chatgpt.com 三路出口 TLS 全超时（出口侧封 OpenAI），
   下午恢复。所以本 provider 依然把「不可达 / 未登录 / 额度用尽」一律判成 rc=3（黄），
   Jenkins 里不阻断整个 job —— 这是环境问题，不是代码缺陷。

🔴 登录态来自**复制**的 Chrome profile（Cookies + Local State + Preferences），
   不要让 Chrome 自己去解密重写：cookie 一旦经 CDP addCookies 重建就会失效
   （Chrome 155 的分片 __Secure-next-auth.session-token.0/.1 重建后不被认），
   实测只有「整份 profile 交给 Chrome 自己读」才进得去。

为什么不用 API
--------------
用户诉求是「用浏览器 cookie 调 chatgpt.com」，走的是包月订阅额度而不是 API 计费。
所以这里刻意不读 OPENAI_API_KEY，只复用一个已登录的 Chrome profile。

流程
----
1. 预检：代理能否真的和 chatgpt.com 完成 TLS 握手（不要等 Chrome 起来才发现被墙）
2. 复制最小 profile（Cookies / Preferences / Local State）到临时目录 —— 不碰用户正在用的 profile
3. 起 Chrome（--remote-debugging-port，必须 --no-sandbox --disable-gpu，本机沙箱里否则起不来）
4. 交给 node driver（playwright-core connectOverCDP）：上传图 → 填提示词 → 等出图 → 取回
5. 无论成败都杀 Chrome、删临时 profile（里面是明文可解的登录态）

用法
----
    gen_chatgpt_web.py --image SRC.png --prompt-file prompt.txt --out gen.png \
        [--proxy http://127.0.0.1:7890] [--profile "Profile 5"] [--timeout 300] [--check-only]

退出码：0 成功 / 1 失败 / 2 用法 / 3 环境不可用（黄，不阻断；含「出图额度已用尽」）
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile
import time
from pathlib import Path

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
CHROME_DATA = Path.home() / "Library/Application Support/Google/Chrome"
HERE = Path(__file__).resolve().parent
DRIVER = HERE / "chatgpt_web_driver.mjs"
RC_OK, RC_FAIL, RC_USAGE, RC_WARN = 0, 1, 2, 3
# 内部信号（都不对外暴露，main 里转成 RC_WARN）：
#   RC_QUOTA   = driver rc=4：账号级额度用尽 → 先尝试自动换号
#   RC_REFUSED = driver rc=5：模型安全策略拒绝 → 重试/换号都没用，必须改提示词
RC_QUOTA = 5
RC_REFUSED = 6


def log(msg: str) -> None:
    print(f"[chatgpt_web] {msg}", flush=True)


def find_sunbrowser_ports(exclude: int | None = None) -> list[int]:
    """反查 AdsPower / SunBrowser 的 CDP 端口（已登录的另一个账号）。

    直接复用 find_browser_cdp.py 的实现（进程 → lsof → 试 /json/version），
    这里只多做一件事：**排除当前正在用的端口**，否则「换号」会连回同一个额度已空的账号。
    """
    try:
        if str(HERE) not in sys.path:
            sys.path.insert(0, str(HERE))
        import find_browser_cdp as fb
    except Exception as e:                                    # noqa: BLE001
        log(f"⚠ 反查端口失败（{e}）")
        return []
    cand: list[tuple[int, int]] = []
    for pid in fb.candidate_pids():
        for port in fb.listening_ports(pid):
            if exclude and port == exclude:
                continue
            info = fb.probe(port)
            if info:
                cand.append((info.get("chatgpt_tabs", 0), port))
    # 优先「已经开着 chatgpt 标签」的，其次端口小（稳定）
    cand.sort(key=lambda t: (-t[0], t[1]))
    return [p for _, p in cand]


def read_fail(out: Path) -> dict:
    """读 driver 落的结构化失败证据 `<out>.fail.json`（reason / message / reset / url）。

    🔴 2026-10-21：额度用尽以前只体现在「页面尾部文本」里，人要自己去控制台里捞。
       现在 driver 命中即退出 rc=4 并落这个文件，这里读出来直接进 Jenkins 摘要与 artifacts。
    """
    p = Path(str(out) + ".fail.json")
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _ledger():
    """额度台账（同目录 provider_ledger.py）。导入失败返回 None —— 台账只是加速器，缺了照样能跑。"""
    try:
        if str(HERE) not in sys.path:
            sys.path.insert(0, str(HERE))
        import provider_ledger as pl
        return pl
    except Exception as e:                                    # noqa: BLE001
        log(f"⚠ 导入 provider_ledger 失败（{e}）：本轮不做额度台账记忆")
        return None


def find_node() -> str | None:
    cand = [os.environ.get("NODE_BIN"), shutil.which("node"),
            "/Users/wangxufeng/.workbuddy/binaries/node/versions/22.22.2-6/bin/node",
            "/usr/local/bin/node"]
    for c in cand:
        if c and Path(c).is_file():
            return c
    return None


def find_playwright_core() -> str | None:
    cand = [os.environ.get("PW_CORE"),
            "/usr/local/lib/node_modules/agent-browser/node_modules/playwright-core",
            "/usr/local/lib/node_modules/playwright-core"]
    for c in cand:
        if c and Path(c, "package.json").is_file():
            return c
    return None


def probe(url_host: str, proxy: str | None, timeout: float = 12.0) -> tuple[bool, str]:
    """显式做一次 CONNECT + TLS 握手。

    只用 HTTP 探活是不够的：这些出口对 chatgpt.com 的典型表现正是
    「CONNECT 200 established，随后 TLS 握手一直不返回」——必须握到手才能算通。
    """
    try:
        if proxy:
            host, port = proxy.replace("http://", "").split(":")[:2]
            sock = socket.create_connection((host, int(port)), timeout=timeout)
            sock.sendall(f"CONNECT {url_host}:443 HTTP/1.1\r\nHost: {url_host}:443\r\n\r\n".encode())
            head = b""
            while b"\r\n\r\n" not in head:
                chunk = sock.recv(1024)
                if not chunk:
                    return False, "代理提前断开"
                head += chunk
            if b" 200 " not in head.split(b"\r\n")[0] + b" ":
                return False, f"CONNECT 被拒：{head.split(b'\r\n')[0].decode(errors='replace')}"
        else:
            sock = socket.create_connection((url_host, 443), timeout=timeout)
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        with ctx.wrap_socket(sock, server_hostname=url_host) as tls:
            tls.settimeout(timeout)
            tls.do_handshake()
            return True, f"TLS 就绪（{tls.version()}）"
    except Exception as e:                                   # noqa: BLE001
        return False, f"{type(e).__name__}: {e}"


def probe_any(proxy: str | None) -> tuple[bool, str]:
    """先试直连（本机 ClashX 的 TUN 模式把 fake-ip 整段接走），不通再试显式代理。

    只试一条路会误判：上午封的是代理出口、直连压根没试；下午通了但 7890 那台
    东京节点仍是死的。两条都试完才下结论。
    """
    ok, detail = probe("chatgpt.com", None)
    if ok:
        return True, f"直连 {detail}"
    ok2, detail2 = probe("chatgpt.com", proxy) if proxy else (False, "未配置代理")
    if ok2:
        return True, f"经 {proxy} {detail2}"
    return False, f"直连 {detail}；代理 {detail2}"



def copy_min_profile(dest: Path, profile: str) -> bool:
    """只复制登录必需的三样东西，别把几个 GB 的 profile 搬来搬去。"""
    src = CHROME_DATA / profile
    if not (src / "Cookies").is_file():
        log(f"🔴 找不到 {src/'Cookies'}")
        return False
    (dest / profile).mkdir(parents=True, exist_ok=True)
    for f in ("Cookies", "Preferences", "Secure Preferences"):
        s = src / f
        if s.is_file():
            # Chrome 运行时会锁 Cookies（-journal/-wal），复制副本即可
            shutil.copy2(s, dest / profile / f)
    ls = CHROME_DATA / "Local State"
    if ls.is_file():
        shutil.copy2(ls, dest / "Local State")
    return True


def wait_cdp(port: int, deadline: float) -> bool:
    import urllib.request
    url = f"http://127.0.0.1:{port}/json/version"
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=1.5) as r:
                if r.status == 200:
                    return True
        except Exception:                                    # noqa: BLE001
            time.sleep(0.5)
    return False


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="用 Chrome 登录态驱动 chatgpt.com 出图")
    ap.add_argument("--image", required=True, help="作为参考图的本地文件")
    ap.add_argument("--prompt-file", required=True, help="提示词文件（restyle_pipeline prompt 的输出）")
    ap.add_argument("--out", required=True, help="生成图落盘路径")
    ap.add_argument("--proxy", default=os.environ.get("CHATGPT_PROXY", ""),
                    help="显式代理（默认空=走系统/TUN；直连不通时才用它）")
    ap.add_argument("--profile", default=os.environ.get("CHROME_PROFILE", "Profile 5"))
    ap.add_argument("--port", type=int, default=9333)
    ap.add_argument("--timeout", type=int, default=360, help="等图上限（秒）")
    ap.add_argument("--attempts", type=int, default=2,
                    help="整轮尝试次数（Chrome 中途掉线时重起一次；不可达/未登录/额度用尽不重试）")
    ap.add_argument("--crop-height", type=int, default=0,
                    help="参考图先从顶部裁到这么高（超长条底板只把「英雄带」喂给模型；0=整幅）")
    ap.add_argument("--reuse-cdp", action="store_true",
                    help="复用已经在跑的 Chrome 调试端口（本机调试用，此时不启动也不关闭 Chrome）")
    ap.add_argument("--grab-existing", action="store_true",
                    help="不发送，直接取当前 chatgpt 对话里已有的生成图。"
                         "图其实已经画好、只是 driver 没认出来时用它，别再烧一次额度")
    # 🔴 额度用尽默认自动换号：先接已开着的 SunBrowser，再让 AdsPower 现开一个 profile。
    #    关掉它（--no-auto-fallback）只在「明确要验证某个账号的额度」时用。
    ap.add_argument("--auto-fallback", dest="auto_fallback", action="store_true", default=True,
                    help="额度用尽时自动换号：已开着的 SunBrowser → AdsPower 现开一个 profile（默认开）")
    ap.add_argument("--no-auto-fallback", dest="auto_fallback", action="store_false",
                    help="额度用尽直接失败，不自动换号")
    ap.add_argument("--adspower-profiles", default=os.environ.get("ADSPOWER_PROFILES", ""),
                    help="指定换号顺序（逗号分隔的 AdsPower user_id），排在最前；留空=自动排"
                         "（上次成功的 → 今天没空的 → chatgpt cookie 多的）")
    ap.add_argument("--adspower-max-profiles", type=int,
                    default=int(os.environ.get("ADSPOWER_MAX_PROFILES", "3")),
                    help="最多现开几个号（默认 3）。每开一个都要等一次完整出图，别贪多")
    ap.add_argument("--fallback-budget", type=int,
                    default=int(os.environ.get("FALLBACK_BUDGET", "960")),
                    help="整条换号链的总时间预算（秒，默认 960=16 分钟）。用完就停，别把 job 拖爆")
    ap.add_argument("--adspower-stop-when-done", action="store_true",
                    help="换号成功后也关掉现开的那个号（默认留着：下次跑直接接入，不用再等启动）")
    ap.add_argument("--ignore-ledger", action="store_true",
                    help="忽略额度台账（provider_ledger.py）。默认会跳过「还没到恢复时间」的号，"
                         "免得每轮都拿同一个空号从头试；要验某个号的额度时加这个开关")
    ap.add_argument("--check-only", action="store_true", help="只做连通性与登录态预检")
    args = ap.parse_args(argv)

    image = Path(args.image).expanduser().resolve()
    prompt_file = Path(args.prompt_file).expanduser().resolve()
    out = Path(args.out).expanduser().resolve()
    for p, what in ((image, "参考图"), (prompt_file, "提示词")):
        if not p.is_file():
            log(f"🔴 {what}不存在：{p}")
            return RC_USAGE
    prompt_file.read_text(encoding="utf-8")

    ok, detail = probe_any(args.proxy or None)
    if not ok:
        # 🔴 这个探测是「本机直连」打的，而 SunBrowser / AdsPower 里的号**自带代理**：
        #    本机出口被封时直连必然 403/超时，浏览器里却照常出图（2026-10-21 实测：
        #    直连 403，CDP 56540 三分钟前刚出过两张）。所以它是提示，不是闸门。
        log(f"⚠ 本机直连 chatgpt.com 不通（{detail}）")
        log("  这只说明本机出口被封，不代表出不了图：浏览器通道自带代理，接着试。")
        log("  若浏览器也失败，driver 会给出它自己的判定（未登录/额度/拒画）。")
    else:
        log(f"连通性 OK：{detail}")
    if args.check_only:
        return RC_OK if ok else RC_WARN

    node, pw = find_node(), find_playwright_core()
    if not node or not pw:
        log(f"🔴 缺少依赖：node={node} playwright-core={pw}")
        return RC_WARN

    # 🔴 Chrome 偶发在等待出图中途整页被关（实测 2026-10-20：driver 报
    #    "Target page, context or browser has been closed"，5 分钟后整轮报废）。
    #    这种是环境抖动、不消耗出图额度，值得自动重起一次；而「不可达/未登录/人机验证/
    #    额度用尽」重试一万次也没用，必须直接返回 RC_WARN。
    attempts = 1 if args.grab_existing else max(1, args.attempts)
    last = RC_FAIL

    # 🔴 台账先行：本机 Chrome 上一轮已经额度用尽、又还没到恢复时间 ⇒ 别再花 3~9 分钟撞一次。
    #    2026-10-21 实测：一轮里 3 个号轮流「额度已用尽」，光等失败就烧掉 9 分钟，
    #    而这件事本来是「上一轮就知道的」。台账记的是**什么时候恢复**，不是「今天空过」。
    pl = _ledger()
    if pl and not args.ignore_ledger and not args.reuse_cdp and not args.grab_existing:
        t = pl.blocked_until("chrome", args.profile)
        if t:
            log(f"↪ 台账：本机 Chrome（{args.profile}）额度封锁到 "
                f"{t:%m-%d %H:%M}（还有 {pl.human_left(t)}），本轮跳过它")
            if args.auto_fallback:
                rc = try_fallback(args, image, prompt_file, out, node, pw)
                if rc == RC_OK:
                    return RC_OK
                if rc == RC_REFUSED:
                    return RC_WARN
            log("🔴 换号链也没拿到图，而本机 Chrome 台账封锁中 —— 本轮不再试它")
            return RC_WARN

    for i in range(1, attempts + 1):
        if i > 1:
            log(f"↻ 第 {i}/{attempts} 次重试（上一次页面/浏览器被关，判定为环境抖动）")
        last = run_once(args, image, prompt_file, out, node, pw)
        if last == RC_OK:
            # 本机 Chrome profile 也记进钥匙缓存：下次同一台机器直接从它开始
            record_key("chrome", args.profile, port=args.port)
            if pl:
                pl.mark_ok("chrome", args.profile)
            return RC_OK
        if last == RC_REFUSED:
            # 被拒是「这张图/这句话不能画」，不是环境问题：不重试、不换号，改 LAYOUT 再说。
            detail = read_fail(out)
            log("🔴 模型安全策略拒绝（重试同一句提示词、换号都不会变）")
            log(f"   站点原文：{detail.get('message') or '站点未给出原文'}")
            log("   处理：改 LAYOUT —— 去掉可能触发的描述（衣着/姿势/身体细节），"
                "强调全年龄向、衣着完整；或换一张参考图")
            return RC_WARN
        if last == RC_QUOTA:
            # 🔴 额度用尽是账号级限制：重试没用，换号才有用。
            #    换号链（见 try_fallback）：① 接入已开着的 SunBrowser → ② 让 AdsPower 现开一个 profile。
            detail = read_fail(out)
            if pl and not args.reuse_cdp:
                # 把「什么时候恢复」写进台账，下一轮直接从换号链起步
                pl.mark_exhausted("chrome", args.profile,
                                  raw=str(detail.get("reset") or ""),
                                  message=str(detail.get("message") or ""))
                t = pl.blocked_until("chrome", args.profile)
                log(f"   台账：chrome:{args.profile} 记额度用尽"
                    f"{'，恢复时间 ' + t.strftime('%m-%d %H:%M') if t else ''}")
            if args.auto_fallback:
                rc = try_fallback(args, image, prompt_file, out, node, pw)
                if rc == RC_OK:
                    return RC_OK
                if rc == RC_REFUSED:
                    return RC_WARN
            log(f"🔴 出图额度已用尽（账号级，重试无效）：{detail.get('message') or '站点未给出原文'}")
            log("   处理：在 AdsPower 里换一个已登录 ChatGPT 的 profile 后重跑，或等额度重置")
            return RC_WARN
        if last in (RC_USAGE, RC_WARN):
            return last
    return last


def try_fallback(args, image: Path, prompt_file: Path, out: Path, node: str, pw: str) -> int:
    """额度用尽后的换号链。这是「一个号画完了就换下一个继续画」的唯一入口。

    ① **已经开着的**另一台 SunBrowser：只连不断，秒级接上（用户手上开着就优先用它）；
    ② **让 AdsPower 现开一个** profile：本进程负责起，失败自己收（用户 2026-10-21 要求）。

    🔴 不搬 cookie、不改登录态：换的只是「连哪个浏览器」。 --reuse-cdp 只连不断，
       不会关掉用户手上的窗口，driver 也优先复用已开的 chatgpt 标签、不抢 tab。
    🔴 必须排除当前端口：否则「换号」会连回同一个额度已空的账号，白跑一轮。
    🔴 现开的号在**成功后默认留着**（下次跑直接走①，不用再等启动）；失败即关，
       免得任务结束时机器上挂着一排浏览器。--adspower-stop-when-done 可改成成功也关。
    """
    fb = _fb()
    if fb is None:
        log("⚠ find_browser_cdp.py 不可用，换号链跳过")
        return RC_QUOTA

    state = load_state()
    deadline = time.time() + max(0, args.fallback_budget)
    tried_ports = {args.port} if args.reuse_cdp else set()
    today = time.strftime("%Y-%m-%d")
    pl = _ledger()

    # ── ① 已经开着的 SunBrowser ────────────────────────────────────────────
    ports = [p for p in find_sunbrowser_ports(exclude=args.port) if p not in tried_ports]
    # 钥匙缓存排前面：上次出过图的端口优先（端口号会变，但同一个号通常连着同一个端口）
    good_ports = [int(x) for x in cached_order("sunbrowser") if x.isdigit()]
    if good_ports:
        ports.sort(key=lambda p: (good_ports.index(p) if p in good_ports else len(good_ports), p))
    for p in ports[:3]:
        if time.time() > deadline:
            log("⚠ 换号预算用完，停止继续尝试")
            return RC_QUOTA
        tried_ports.add(p)
        log(f"↪ 换号 ①／②：接入已开着的 SunBrowser CDP {p}（只连不断）")
        rc = run_on_port(args, p, image, prompt_file, out, node, pw)
        if rc == RC_OK:
            record_key("sunbrowser", p, port=p)
            log(f"✅ 换号成功：SunBrowser {p} 已出图")
            return RC_OK
        record_key("sunbrowser", p, port=p, ok=False, note=f"rc={rc}")
        if rc == RC_REFUSED:
            return rc
        log(f"   SunBrowser {p} 没成（rc={rc}），继续找下一个号")

    # ── ② 让 AdsPower 现开一个 profile ─────────────────────────────────────
    if not fb.adspower_alive():
        log("⚠ AdsPower 本地 API 不可达（客户端没开/端口不对），无法现开新号")
        return RC_QUOTA
    cands = pick_profiles(args, fb, state)
    if not cands:
        log("⚠ AdsPower 里没有可换的 profile（缓存目录里没有启动过的号）")
        return RC_QUOTA

    # 🔴 台账过滤：还没到恢复时间的号**直接不排队**。
    #    以前是「只降权不排除」，于是每轮都拿同一个空号从头试，等一轮失败就得几分钟。
    #    但台账也可能是错的（实测 ktmrjhu 标着当天空过却一次过）⇒ 全被封时按最快恢复的赌一把。
    queue = cands
    if pl and not args.ignore_ledger:
        explicit = [x.strip() for x in (args.adspower_profiles or "").split(",") if x.strip()]
        ordered = pl.order([{"id": c["user_id"], "cookies": int(c.get("cookies") or 0)}
                            for c in cands], "adspower", explicit=explicit)
        by_id = {c["user_id"]: c for c in cands}
        queue = [by_id[r["id"]] for r in ordered]
        blocked = []
        free = []
        for c in queue:
            t = pl.blocked_until("adspower", c["user_id"])
            (blocked if t else free).append((c, t))
        if blocked:
            tail = "、".join(f"{c['user_id']}({pl.human_left(t)})" for c, t in blocked)
            log(f"   台账封锁中、本轮不碰：{tail}")
        if free:
            queue = [c for c, _ in free]
        elif blocked:
            queue = [blocked[0][0]]
            log(f"⚠ 台账里所有号都在封锁期，按最快恢复的 {queue[0]['user_id']} 赌一把（记录可能已过期）")
            log("   如果它其实还有额度，这次就能出图；出来了会自动解封并提到最前")

    log(f"↪ 换号 ②／②：AdsPower 里现开一个（候选 {', '.join(c['user_id'] for c in queue[:args.adspower_max_profiles])}）")

    for c in queue[:args.adspower_max_profiles]:
        if time.time() > deadline:
            log("⚠ 换号预算用完，停止继续尝试")
            return RC_QUOTA
        uid = c["user_id"]
        status, port = fb.adspower_state(uid)
        launched = False
        if status == "missing":
            log(f"   {uid}：AdsPower 不认这个 id（缓存目录残留），跳过")
            continue
        if status == "active" and port:
            log(f"   {uid}：已经开着（CDP {port}），直接接上")
        else:
            log(f"   {uid}：启动 profile …")
            ok, port, msg = fb.adspower_start(uid)
            if not ok:
                if "does not exist" in msg:
                    # 🔴 API 自相矛盾：active 说 Inactive，start 说「不存在」。
                    #    实测 kuh8m7e 就是这种（缓存目录在、账号里已经没有这个 profile）——
                    #    记进台账排最后，别每次都白等一轮启动。
                    log(f"   {uid}：AdsPower 不认这个 id（缓存目录残留，账号里已无此 profile）")
                    state.setdefault("profiles", {}).setdefault(uid, {})["note"] = "ads_missing"
                    save_state(state)
                else:
                    log(f"   {uid} 启动失败：{msg}")
                continue
            launched = True
            log(f"   {uid} 已启动（CDP {port}）")
        if port in tried_ports or not port:
            log(f"   {uid} 的端口 {port} 已经试过，跳过")
            if launched:
                fb.adspower_stop(uid)
            continue
        tried_ports.add(port)
        if not wait_cdp(port, time.time() + 45):
            log(f"   {uid} 的 CDP {port} 没起来")
            if launched:
                fb.adspower_stop(uid)
            continue

        rc = run_on_port(args, port, image, prompt_file, out, node, pw)
        if rc == RC_OK:
            state.setdefault("profiles", {}).setdefault(uid, {})["ok_at"] = today
            state["last_ok_profile"] = uid
            state["updated"] = time.strftime("%Y-%m-%d %H:%M:%S")
            save_state(state)
            record_key("adspower", uid, port=port)
            if pl:
                pl.mark_ok("adspower", uid)
            log(f"✅ 换号成功：AdsPower profile {uid}（CDP {port}）")
            if args.adspower_stop_when_done:
                log(f"   --adspower-stop-when-done：关闭 {uid}")
                fb.adspower_stop(uid)
            return RC_OK
        record_key("adspower", uid, port=port, ok=False, note=f"rc={rc}")
        if rc == RC_REFUSED:
            # 提示词被拒与账号无关，换号也不会变：收掉自己开的号，直接退出
            if launched:
                fb.adspower_stop(uid)
            return rc
        if rc == RC_QUOTA:
            detail = read_fail(out)
            resume = str(detail.get("reset") or "")
            if pl:
                e = pl.mark_exhausted("adspower", uid, raw=resume,
                                      message=str(detail.get("message") or ""))
                log(f"   {uid} 这个号也额度用尽 → 台账记到 {e.get('blocked_until')}"
                    f"（依据 {e.get('reset_basis')}{'，估的' if e.get('reset_estimated') else ''}）")
            else:
                log(f"   {uid} 这个号也额度用尽 → 记下来，明天之前排在最后")
            state.setdefault("profiles", {}).setdefault(uid, {})["quota_date"] = today
            save_state(state)
        else:
            # rc=3=未登录/人机验证/非空对话，rc=1=页面没出图。现开的号不折腾，换下一个
            log(f"   {uid} 不可用（rc={rc}，见上面 driver 日志）→ 换下一个号")
            if pl:
                pl.mark_unusable("adspower", uid, note=f"rc={rc} @ {today}")
            state.setdefault("profiles", {}).setdefault(uid, {})["note"] = f"rc={rc} @ {today}"
            save_state(state)
        if launched:
            fb.adspower_stop(uid)
    return RC_QUOTA


def run_on_port(args, port: int, image: Path, prompt_file: Path, out: Path,
                node: str, pw: str) -> int:
    """把出图跑在指定 CDP 端口上（外部浏览器：只连不断），跑完把 args 还原。"""
    saved = (args.port, args.reuse_cdp)
    args.port, args.reuse_cdp = port, True
    try:
        return run_once(args, image, prompt_file, out, node, pw)
    finally:
        args.port, args.reuse_cdp = saved


def pick_profiles(args, fb, state: dict) -> list[dict]:
    """候选号排序：用户显式指定的 > 上次成功的 > 没在额度记录上挂掉的 > cookie 多的。

    🔴 「今天额度用尽」只降权不排除：额度中途会重置，且记录可能是另一个任务留下的。
    """
    rows = fb.adspower_profiles()
    if not rows:
        return []
    by_id = {r["user_id"]: r for r in rows}
    explicit = [x.strip() for x in (args.adspower_profiles or "").split(",") if x.strip()]
    head = [u for u in explicit if u in by_id]
    # 钥匙缓存（成功出过图的号，最近成功的在前）优先于台账里的 last_ok_profile
    for u in cached_order("adspower"):
        if u in by_id and u not in head:
            head.append(u)
    last_ok = str(state.get("last_ok_profile") or "").strip()
    if last_ok in by_id and last_ok not in head:
        head.append(last_ok)
    prof = state.get("profiles") or {}

    def rank(uid: str):
        """越小越先试：AdsPower 不认的 id 最末；今天额度空过的次末；其余按 cookie 数。"""
        p = prof.get(uid) or {}
        missing = p.get("note") == "ads_missing"
        exhausted = bool(p.get("quota_date")) and p.get("quota_date") == time.strftime("%Y-%m-%d")
        return (missing, exhausted, -by_id[uid]["cookies"])

    rest = [r["user_id"] for r in rows if r["user_id"] not in head]
    rest.sort(key=rank)
    out = []
    for uid in head + rest:
        # 用户显式点名 = 明确要用的号，不受 cookie 数为 0 的影响；
        # cookies=-1 是「库读不出来」，别当成没登录（只有真正数到 0 才跳过）
        if not explicit or uid in explicit or by_id[uid]["cookies"] != 0:
            out.append(by_id[uid])
    return out or rows


def _fb():
    """find_browser_cdp 模块（同目录）；导入失败返回 None，换号链降级为「不换」。"""
    try:
        if str(HERE) not in sys.path:
            sys.path.insert(0, str(HERE))
        import find_browser_cdp as fb
        return fb
    except Exception as e:                                    # noqa: BLE001
        log(f"⚠ 导入 find_browser_cdp 失败（{e}）")
        return None


# 换号台账：哪个 profile 上次成功 / 哪个号哪天额度空了。放 _output（已 gitignore）。
STATE_FILE = Path(__file__).resolve().parents[2] / "_output/art_restyle/provider_state.json"


def load_state() -> dict:
    try:
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    except Exception:                                         # noqa: BLE001
        return {}


def save_state(state: dict) -> None:
    try:
        STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
        STATE_FILE.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")
    except Exception as e:                                    # noqa: BLE001
        log(f"⚠ 换号台账写不进去（{e}），不影响出图")


# ---------------------------------------------------------------- 钥匙缓存（成功过的号）
# 🔴 用户 2026-10-21 要求：每次出图成功就把「成功的钥匙」缓存到 table1.json 所在的目录，
#    下次绘制直接从这儿开始试，别再靠 cookie 数瞎猜。
#    为什么不放 _output：那里是产物目录（会被清理），钥匙要跨任务/跨天复用，得跟脚本走。
#    只存「怎么连上哪个号」的标识（端口 / AdsPower user_id / Chrome profile 名），
#    **不存 cookie、不存密码**——登录态始终留在浏览器自己的 profile 里，这里只是路标。
KEY_CACHE_FILE = HERE / "gen_keys_cache.json"


def load_keys() -> dict:
    try:
        data = json.loads(KEY_CACHE_FILE.read_text(encoding="utf-8"))
        if isinstance(data.get("keys"), dict):
            return data
    except Exception:                                         # noqa: BLE001
        pass
    return {
        "_note": "出图成功过的浏览器/账号钥匙（只有路标，没有 cookie）。自动维护，可手删。",
        "keys": {},
    }


def save_keys(data: dict) -> None:
    try:
        data["updated_at"] = time.strftime("%Y-%m-%d %H:%M:%S")
        KEY_CACHE_FILE.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                                  encoding="utf-8")
    except Exception as e:                                    # noqa: BLE001
        log(f"⚠ 钥匙缓存写不进去（{e}），不影响出图")


def record_key(kind: str, ident, port=None, ok: bool = True, note: str = "") -> None:
    """记一次出图结果：成功就把它顶到最前，失败只累加计数。

    🔴 成功后清掉 quota_date：额度是会重置的，别让「昨天空过」永久压着一个好号。
    """
    data = load_keys()
    k = f"{kind}:{ident}"
    row = data["keys"].setdefault(k, {"kind": kind, "id": str(ident)})
    now = time.strftime("%Y-%m-%d %H:%M:%S")
    if port:
        row["port"] = int(port)
    row["last_at"] = now
    if ok:
        row["ok_at"] = now
        row["ok_count"] = int(row.get("ok_count") or 0) + 1
        row["fails"] = 0
        row.pop("last_fail", None)
        row.pop("quota_date", None)
    else:
        row["fails"] = int(row.get("fails") or 0) + 1
        row["last_fail"] = note or now
        if note.startswith("rc=4") or "quota" in note:
            row["quota_date"] = time.strftime("%Y-%m-%d")
    save_keys(data)


def cached_order(kind: str) -> list[str]:
    """某类钥匙里「成功过、今天没被判额度空」的 id，最近成功的排前面。"""
    today = time.strftime("%Y-%m-%d")
    rows = [r for r in load_keys()["keys"].values()
            if r.get("kind") == kind and r.get("ok_at") and r.get("quota_date") != today]
    rows.sort(key=lambda r: str(r.get("ok_at") or ""), reverse=True)
    return [str(r.get("id")) for r in rows]


def run_once(args, image: Path, prompt_file: Path, out: Path, node: str, pw: str) -> int:
    """一次完整的「复制 profile → 起 Chrome → driver 出图」；失败由 main 决定是否重试。"""
    tmp = Path(tempfile.mkdtemp(prefix="chatgpt_web_"))
    chrome = None
    ref = image
    try:
        # 超长条底板：只把顶部「英雄带」喂给模型（整幅 856x2048 塞进去，模型会把它压成
        # 一张很窄的图，角色和字全糊）。裁切结果落在临时目录，不污染资源。
        if args.crop_height > 0:
            from PIL import Image
            im = Image.open(image).convert("RGB")
            h = min(args.crop_height, im.height)
            if h < im.height:
                ref = tmp / "ref_band.png"
                im.crop((0, 0, im.width, h)).save(ref)
                log(f"参考图取顶部 {im.width}x{h} 英雄带（原图 {im.width}x{im.height}）")

        if args.reuse_cdp:
            log(f"复用已运行的 Chrome（{args.port}）")
            if not wait_cdp(args.port, time.time() + 5):
                log("🔴 该端口上没有 CDP 服务")
                return RC_WARN
        else:
            if not copy_min_profile(tmp, args.profile):
                return RC_WARN
            cmd = [CHROME, f"--remote-debugging-port={args.port}",
                   f"--user-data-dir={tmp}", f"--profile-directory={args.profile}",
                   "--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage",
                   "--no-first-run", "--no-default-browser-check",
                   "--window-size=1440,1200"]
            if args.proxy:
                cmd.append(f"--proxy-server={args.proxy}")
            cmd.append("about:blank")
            log(f"启动 Chrome（profile={args.profile}，proxy={args.proxy or '系统/TUN'}）")
            chrome = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                      start_new_session=True)
            if not wait_cdp(args.port, time.time() + 30):
                log("🔴 Chrome CDP 没起来（常见原因：--no-sandbox 缺失 / GPU 进程崩）")
                return RC_WARN

        out.parent.mkdir(parents=True, exist_ok=True)
        if out.exists():
            out.unlink()
        env = dict(os.environ)
        # 🔴 driver 要连 127.0.0.1，绝不能走 HTTP_PROXY（会 502）
        env["NO_PROXY"] = "127.0.0.1,localhost"
        env["no_proxy"] = "127.0.0.1,localhost"
        if args.reuse_cdp:
            # 复用外部浏览器（AdsPower/SunBrowser 等）时只连不断，别把人家窗口关了
            env["PW_KEEP_BROWSER"] = "1"
        drv_cmd = [node, str(DRIVER), "--cdp", f"http://127.0.0.1:{args.port}",
                   "--image", str(ref), "--prompt-file", str(prompt_file),
                   "--out", str(out), "--timeout", str(args.timeout), "--pw", pw]
        if args.grab_existing:
            drv_cmd.append("--grab-existing")
        drv = subprocess.run(drv_cmd, timeout=args.timeout + 120, env=env)
        if drv.returncode == 0 and out.is_file():
            log(f"✅ 出图：{out}（{out.stat().st_size // 1024} KB）")
            return RC_OK
        if drv.returncode == 4:
            # 🔴 账号级额度用尽：换节点、重试、重开浏览器全都没用 —— 只能换号（或等重置）。
            #    这里不直接判失败，先把「额度用尽」当信号抛给 main，由它决定是否自动接 SunBrowser。
            detail = read_fail(out)
            log("🔴 driver 退出码 4：chatgpt.com 明确返回「出图额度已用尽」")
            log(f"   站点原文：{detail.get('message') or '(未取到)'}")
            if detail.get("reset"):
                log(f"   重置提示：{detail['reset']}")
            return RC_QUOTA
        if drv.returncode == 5:
            # 🔴 模型安全策略拒绝：同一句提示词再发基本还是拒，换号也没用（同一个模型同一套策略）。
            detail = read_fail(out)
            log("🔴 driver 退出码 5：模型判定这张图违反内容/安全策略，拒绝生成")
            log(f"   站点原文：{detail.get('message') or '(未取到)'}")
            return RC_REFUSED
        log(f"🔴 driver 退出码 {drv.returncode}，未拿到图片")
        return RC_WARN if drv.returncode == 3 else RC_FAIL
    except subprocess.TimeoutExpired:
        log("🔴 driver 超时")
        return RC_WARN
    finally:
        if chrome and chrome.poll() is None:
            chrome.terminate()
            try:
                chrome.wait(timeout=8)
            except subprocess.TimeoutExpired:
                chrome.kill()
        shutil.rmtree(tmp, ignore_errors=True)     # 🔴 里面是可解密的登录态，必须删


if __name__ == "__main__":
    sys.exit(main())
