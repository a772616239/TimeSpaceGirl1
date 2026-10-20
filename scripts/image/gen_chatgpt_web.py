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
# 内部信号：账号级额度用尽（driver rc=4）。不对外暴露，main 里会转成「自动换号」或 RC_WARN。
RC_QUOTA = 5


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
    # 🔴 额度用尽默认自动换号：本机 Chrome 那个号出完了，就接 AdsPower 的 SunBrowser。
    #    关掉它（--no-auto-fallback）只在「明确要验证某个账号的额度」时用。
    ap.add_argument("--auto-fallback", dest="auto_fallback", action="store_true", default=True,
                    help="额度用尽时自动改用 AdsPower/SunBrowser 里另一个已登录账号（默认开）")
    ap.add_argument("--no-auto-fallback", dest="auto_fallback", action="store_false",
                    help="额度用尽直接失败，不自动换号")
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
        log(f"⚠ chatgpt.com 不可达（{detail}）")
        log("  这不是 cookie 问题：出口到 OpenAI 被封。换节点通了再跑，或改用 provider=manual")
        return RC_WARN
    log(f"连通性 OK：{detail}")
    if args.check_only:
        return RC_OK

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
    for i in range(1, attempts + 1):
        if i > 1:
            log(f"↻ 第 {i}/{attempts} 次重试（上一次页面/浏览器被关，判定为环境抖动）")
        last = run_once(args, image, prompt_file, out, node, pw)
        if last == RC_OK:
            return RC_OK
        if last == RC_QUOTA:
            # 🔴 额度用尽是账号级限制：重试没用，换号才有用。
            #    「换号」= 接上 AdsPower 里另一个已登录 ChatGPT 的 SunBrowser（只连不断）。
            if args.auto_fallback and try_sunbrowser(args, image, prompt_file, out, node, pw):
                return RC_OK
            detail = read_fail(out)
            log(f"🔴 出图额度已用尽（账号级，重试无效）：{detail.get('message') or '站点未给出原文'}")
            log("   处理：在 AdsPower 里换一个已登录 ChatGPT 的 profile 后重跑，或等额度重置")
            return RC_WARN
        if last in (RC_USAGE, RC_WARN):
            return last
    return last


def try_sunbrowser(args, image: Path, prompt_file: Path, out: Path, node: str, pw: str) -> bool:
    """额度用尽时的自动换号：接上 AdsPower 的 SunBrowser（另一个已登录账号）。

    🔴 不搬 cookie、不改登录态：只换「连哪个浏览器」。--reuse-cdp 只连不断，
       不会关掉用户手上的窗口，driver 也优先复用已开的 chatgpt 标签、不抢 tab。
    🔴 必须排除当前端口：否则「换号」会连回同一个额度已空的账号，白跑一轮。
    """
    cur = args.port if args.reuse_cdp else None
    log("↪ 出图额度已用尽，自动查找 SunBrowser（AdsPower 已登录 profile）…")
    ports = find_sunbrowser_ports(exclude=cur)
    if not ports:
        log("⚠ 没找到可用的 SunBrowser（AdsPower 没开 / 该 profile 未开远程调试）")
        return False
    for p in ports[:3]:
        log(f"↪ 改用 SunBrowser CDP {p} 重出（换号，不搬 cookie）")
        args.reuse_cdp = True
        args.port = p
        rc = run_once(args, image, prompt_file, out, node, pw)
        if rc == RC_OK:
            log(f"✅ 换号成功：SunBrowser {p} 已出图")
            return True
        if rc == RC_QUOTA:
            log(f"   SunBrowser {p} 这个号也额度用尽，试下一个")
            continue
        log(f"   SunBrowser {p} 失败（rc={rc}），不再试其它端口")
        return False
    return False


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
