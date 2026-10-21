#!/usr/bin/env python3
"""DSH 桥接服务 —— 把「本机 DSH headless」包成一个秒回不了的 HTTP 接口。

为什么要有这一层
----------------
* 游戏服（Java）不能直接起 dsh：一次冷启动 + 推理实测 **60~70 秒**，还是 node 进程，
  内存/崩溃都得跟游戏服隔离。
* dsh 的 CLI 是「一次性会话」：`node apps/cli/lib/bin.js --profile headless --json <task>`，
  每次一个新进程，stdout 是 NDJSON 事件流，最终答复在 `{"type":"final","text":...}`。
* 聊天回复天然并发很低（一两个机器人），所以这里**串行排队**，绝不并发拉起多个 dsh。

接口
----
    POST /reply   {"prompt": "...", "maxChars": 40}
      -> {"text": "lol fr", "source": "dsh|fallback|fallback-error|fallback-timeout", "elapsedMs": 1234}

    GET  /health  -> {"ok": true, "busy": false, "queue": 0, "dshOk": true, ...}

失败策略（重要）
----------------
DSH 现在实测会上游 400（workbuddy 源被拦），也可能超时。**任何失败都必须给一句话回去**，
否则游戏里的机器人就成了哑巴。降级语料和 Java 侧 BotText 的兜底是同一套风格：
短、口语、you→u。

启动
----
    python3 scripts/bot/dsh_bridge.py                # 前台，默认 127.0.0.1:18765
    nohup python3 scripts/bot/dsh_bridge.py >/tmp/dsh_bridge.log 2>&1 &

环境变量
--------
    DSH_BRIDGE_PORT   默认 18765
    DSH_BRIDGE_HOST   默认 127.0.0.1
    DSH_BIN           dsh 的 bin.js 路径
    DSH_PROFILE       默认 headless
    DSH_TIMEOUT       单次调用超时秒数，默认 180
    DSH_WORKDIR       dsh 进程 cwd（默认临时目录，配合 read-only 权限档）
    DSH_PERMISSION    read-only / workspace-write / danger-full-access，默认 read-only
"""

from __future__ import annotations

import json
import os
import queue
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# --------------------------------------------------------------------------- 配置

NODE = shutil.which("node") or "/usr/local/bin/node"
DSH_BIN = os.environ.get(
    "DSH_BIN",
    "/Applications/DSH/deepseek-harness/apps/cli/lib/bin.js",
)
DSH_PROFILE = os.environ.get("DSH_PROFILE", "headless")
DSH_TIMEOUT = int(os.environ.get("DSH_TIMEOUT", "180"))
DSH_WORKDIR = os.environ.get("DSH_WORKDIR") or os.path.join(tempfile.gettempdir(), "dsh_bot_work")
DSH_PERMISSION = os.environ.get("DSH_PERMISSION", "read-only")
HOST = os.environ.get("DSH_BRIDGE_HOST", "127.0.0.1")
PORT = int(os.environ.get("DSH_BRIDGE_PORT", "18765"))

# ---- 模型侧（2026-10-21 实测钉死）------------------------------------------------
# headless profile 默认 provider=workbuddy / model=hy3，实测恒定 400：
#   workbuddy upstream client (http 400): 请求被拦截，请重新发送
# 换 provider=workbuddy-ai + 屏蔽 CN 变体（WORKBUDDY_AUTH_FILE 指向不存在的路径）
# 之后同一句话立刻成功。原因是两个变体共用顺序 syncAll，headless 跑完即退，
# 排在后面的 AI 变体还没同步完就被查询 —— 与 TD 仓库 deepseek_harness.py 的结论一致。
DSH_PROVIDER = os.environ.get("DSH_PROVIDER", "workbuddy-ai")
DSH_MODEL = os.environ.get("DSH_MODEL", "hy3")
DSH_SUPPRESS_CN = os.environ.get("DSH_SUPPRESS_CN", "1") not in ("0", "off", "false")
# CN 变体的凭据文件，屏蔽时指到不存在的路径
WORKBUDDY_CN_AUTH = os.environ.get(
    "WORKBUDDY_CN_AUTH", os.path.expanduser("~/Library/Application Support/WorkBuddy/auth.json")
)

MAX_QUEUE = 4

EN_FALLBACK = [
    "lol", "fr", "same", "gg", "nice", "u right", "idk tbh", "ya lol",
    "thats wild", "no way", "same here", "true", "big mood", "im in",
    "u too", "haha yea", "on god", "how u get that", "nice pull", "rip",
    "wait what", "for real?", "lmao", "fair", "ikr", "gg wp", "grats",
]
ZH_FALLBACK = [
    "哈哈哈", "真的假的", "同感", "可以啊", "我也想", "牛", "笑死", "确实",
    "带我一个", "太强了", "我也在打", "慢慢来", "稳", "这就去", "厉害了",
]

SLANG = [
    (r"\byou're\b", "ur"), (r"\byoure\b", "ur"), (r"\byou are\b", "ur"),
    (r"\byour\b", "ur"), (r"\byou\b", "u"), (r"\bplease\b", "pls"),
    (r"\bthanks\b", "thx"), (r"\bbecause\b", "cuz"), (r"\bpeople\b", "ppl"),
    (r"\bthough\b", "tho"), (r"\bokay\b", "ok"), (r"\bgoing to\b", "gonna"),
    (r"\bwant to\b", "wanna"), (r"\bgot to\b", "gotta"), (r"\bright now\b", "rn"),
    (r"\bto be honest\b", "tbh"), (r"\bi don'?t know\b", "idk"),
    (r"\boh my god\b", "omg"), (r"\bby the way\b", "btw"),
    (r"\bnever mind\b", "nvm"), (r"\bas soon as possible\b", "asap"),
]

CJK_RE = re.compile(r"[\u4e00-\u9fa5]")


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def has_cjk(s: str) -> bool:
    return bool(CJK_RE.search(s or ""))


def slangify(s: str) -> str:
    out = s
    for pat, rep in SLANG:
        out = re.sub(pat, rep, out, flags=re.IGNORECASE)
    return out


def truncate(s: str, max_chars: int) -> str:
    if len(s) <= max_chars:
        return s
    cut = s[:max_chars]
    sp = cut.rfind(" ")
    if sp > max_chars // 2:
        cut = cut[:sp]
    return cut.strip()


def sanitize(raw: str, max_chars: int) -> str:
    """和 Java 侧 BotText.sanitize 同口径：取第一行、去前缀引号、口语化、截断。"""
    if not raw:
        return ""
    s = raw.strip()
    s = s.split("\n", 1)[0].strip()
    # 先剥包裹引号，再剥前缀：模型常输出 "\"reply: xxx\"" 这种双层壳
    s = s.strip("\"'`“”‘’")
    s = re.sub(r"(?i)^(reply|answer|bot|assistant|output)\s*[:：]\s*", "", s)
    s = s.strip("\"'`“”‘’")
    s = re.sub(r"<[^>]{0,40}>", "", s)
    s = re.sub(r"\s+", " ", s).strip()
    if not has_cjk(s):
        s = slangify(s)
    s = truncate(s, max_chars)
    s = re.sub(r"[\s,;:，；：、]+$", "", s)
    return s.strip()


def fallback(last_text: str) -> str:
    bank = ZH_FALLBACK if has_cjk(last_text) else EN_FALLBACK
    return bank[int(time.time() * 1000) % len(bank)]


# --------------------------------------------------------------------------- DSH 调用

def extract_last_message(prompt: str) -> str:
    m = re.search(r"LAST MESSAGE:\s*(.+)", prompt or "")
    if not m:
        return ""
    line = m.group(1).strip()
    if ":" in line:
        line = line.split(":", 1)[1].strip()
    return line


def ensure_patch() -> str:
    """写一份模型叠加层（DSH 的 --patch 启动器旗标），返回路径。

    只在内容变化时重写，避免每次调用都改文件时间戳。
    """
    os.makedirs(DSH_WORKDIR, exist_ok=True)
    path = os.path.join(DSH_WORKDIR, "model_patch.yml")
    body = (
        "- id: agent-default-model\n"
        "  config:\n"
        f"    provider: {DSH_PROVIDER}\n"
        f"    model: {DSH_MODEL}\n"
    )
    try:
        if not os.path.isfile(path) or open(path, encoding="utf-8").read() != body:
            with open(path, "w", encoding="utf-8") as f:
                f.write(body)
    except Exception as e:  # noqa: BLE001
        log(f"写模型叠加层失败: {e}")
    return path


def run_dsh(prompt: str, timeout: int) -> tuple[str, str]:
    """跑一次 dsh headless，返回 (final_text, status)。

    status: ok / error / timeout / empty
    """
    if not os.path.isfile(DSH_BIN):
        return "", "missing-bin"
    os.makedirs(DSH_WORKDIR, exist_ok=True)
    env = dict(os.environ)
    env["DSH_PERMISSION_MODE"] = DSH_PERMISSION
    # 会话里继承的 NODE_OPTIONS / PYTHONPATH 等会绑到宿主 broker，必须摘干净
    for k in ("NODE_OPTIONS", "PYTHONPATH", "BASH_ENV", "CODEBUDDY_SESSION_ID"):
        env.pop(k, None)
    if DSH_SUPPRESS_CN:
        # 把 CN 变体的桌面凭据指到不存在的路径 ⇒ 它判为未登录、目录隐藏，
        # workbuddy-ai 成为 syncAll 的第一个变体，请求前就已同步完（见文件头注释）
        env["WORKBUDDY_AUTH_FILE"] = "/nonexistent/workbuddy-cn-auth.json"

    cmd = [NODE, DSH_BIN, "--profile", DSH_PROFILE]
    patch = ensure_patch()
    if patch:
        cmd += ["--patch", patch]
    cmd += ["--json", prompt]
    t0 = time.time()
    try:
        proc = subprocess.run(
            cmd,
            cwd=DSH_WORKDIR,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        log(f"dsh 超时 {timeout}s")
        return "", "timeout"
    except Exception as e:  # noqa: BLE001
        log(f"dsh 启动失败: {e}")
        return "", "error"

    out = proc.stdout.decode("utf-8", "ignore")
    err = proc.stderr.decode("utf-8", "ignore").strip()
    final_text = ""
    reason = ""
    for line in out.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except Exception:  # noqa: BLE001
            continue
        if ev.get("type") == "final":
            final_text = ev.get("text") or ""
        elif ev.get("type") == "status" and ev.get("phase") == "turn_end":
            r = ev.get("reason") or {}
            if r.get("kind") == "error":
                reason = str((r.get("error") or {}).get("message", ""))[:200]
    cost = time.time() - t0
    if final_text.strip():
        log(f"dsh ok {cost:.1f}s -> {final_text.strip()[:60]!r}")
        return final_text, "ok"
    log(f"dsh 空回复 rc={proc.returncode} {cost:.1f}s reason={reason or err[:160]}")
    return "", "error"


# --------------------------------------------------------------------------- 串行队列

class Worker:
    """单线程串行跑 dsh。队列满了就直接降级，绝不让请求堆到把内存吃穿。"""

    def __init__(self) -> None:
        self.q: "queue.Queue[tuple[str, int, dict]]" = queue.Queue(maxsize=MAX_QUEUE)
        self.busy = False
        self.last_status = "idle"
        self.ok_count = 0
        self.fail_count = 0
        t = threading.Thread(target=self._loop, name="dsh-worker", daemon=True)
        t.start()

    def submit(self, prompt: str, max_chars: int, box: dict) -> bool:
        try:
            self.q.put_nowait((prompt, max_chars, box))
            return True
        except queue.Full:
            return False

    def _loop(self) -> None:
        while True:
            prompt, max_chars, box = self.q.get()
            self.busy = True
            try:
                text, status = run_dsh(prompt, DSH_TIMEOUT)
                clean = sanitize(text, max_chars)
                if clean:
                    box["text"] = clean
                    box["source"] = "dsh"
                    self.ok_count += 1
                else:
                    box["text"] = fallback(extract_last_message(prompt))
                    box["source"] = "fallback-timeout" if status == "timeout" else "fallback-error"
                    self.fail_count += 1
                self.last_status = status
            except Exception as e:  # noqa: BLE001
                log(f"worker 异常: {e}")
                box["text"] = fallback(extract_last_message(prompt))
                box["source"] = "fallback-error"
                self.fail_count += 1
            finally:
                box["done"] = True
                self.busy = False
                self.q.task_done()


WORKER = Worker()


# --------------------------------------------------------------------------- HTTP

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args) -> None:  # 静音默认访问日志
        return

    def _send(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/health"):
            self._send(200, {
                "ok": True,
                "busy": WORKER.busy,
                "queue": WORKER.q.qsize(),
                "lastStatus": WORKER.last_status,
                "okCount": WORKER.ok_count,
                "failCount": WORKER.fail_count,
                "dshBin": DSH_BIN,
                "dshBinExists": os.path.isfile(DSH_BIN),
                "provider": DSH_PROVIDER,
                "model": DSH_MODEL,
                "suppressCn": DSH_SUPPRESS_CN,
            })
        else:
            self._send(404, {"error": "not found"})

    def do_POST(self) -> None:  # noqa: N802
        if not self.path.startswith("/reply"):
            self._send(404, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(length) if length else b"{}"
            req = json.loads(raw.decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            self._send(400, {"error": f"bad json: {e}"})
            return

        prompt = (req.get("prompt") or "").strip()
        max_chars = int(req.get("maxChars") or 40)
        if not prompt:
            self._send(400, {"error": "empty prompt"})
            return

        t0 = time.time()
        box: dict = {"done": False}
        if not WORKER.submit(prompt, max_chars, box):
            # 队列满：立刻给兜底，不让游戏服那边干等
            self._send(200, {
                "text": fallback(extract_last_message(prompt)),
                "source": "fallback-busy",
                "elapsedMs": int((time.time() - t0) * 1000),
            })
            return

        # 最长等到 dsh 超时 + 30s（游戏服侧 readTimeout=200s，这里留足余量）
        deadline = time.time() + DSH_TIMEOUT + 30
        while not box.get("done") and time.time() < deadline:
            time.sleep(0.05)
        if not box.get("done"):
            box["text"] = fallback(extract_last_message(prompt))
            box["source"] = "fallback-timeout"
        self._send(200, {
            "text": box.get("text") or fallback(extract_last_message(prompt)),
            "source": box.get("source", "fallback"),
            "elapsedMs": int((time.time() - t0) * 1000),
        })


def main() -> None:
    if "--once" in sys.argv:
        idx = sys.argv.index("--once")
        prompt = " ".join(sys.argv[idx + 1:]) or "say hi"
        text, status = run_dsh(prompt, DSH_TIMEOUT)
        print(json.dumps({"status": status, "text": sanitize(text, 40), "raw": text[:200]},
                         ensure_ascii=False))
        return

    srv = ThreadingHTTPServer((HOST, PORT), Handler)
    log(f"dsh bridge listening on http://{HOST}:{PORT}  bin={DSH_BIN} profile={DSH_PROFILE} "
        f"model={DSH_PROVIDER}/{DSH_MODEL} suppressCn={DSH_SUPPRESS_CN} timeout={DSH_TIMEOUT}s")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        log("bye")


if __name__ == "__main__":
    main()
