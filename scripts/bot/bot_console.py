#!/usr/bin/env python3
"""虚拟玩家可视化控制台 —— 一个页面看清机器人「在不在、说了什么、回得多快」。

数据从三个地方拿，全部只读，不改游戏服任何状态：
  1. Redis  `serverId:BOT_STATUS`  ← 游戏服 BotTask 每 15 秒写的运行快照（开关/在线/指标/事件）
  2. Redis  `serverId:CHAT_QUEUE:world` ← 世界频道最近消息（protobuf，本文件自己解）
  3. 本机 DSH 桥接 `/health`        ← provider/model/排队/成功失败数
操作类按钮走 GM thrift（`bot on/off/reload/say/announce/fake/reply`），复用 scripts/gm_client.py。

为什么不用 redis-py / protobuf 库：
  部署到测试服时不想为了一个看板再装依赖。Redis 走裸 RESP（40 行），
  ChatInfo 走手写 varint 解码（字段号见 proto/protos/ChatProto.proto），
  唯一的第三方依赖是 GM 用的 thrift（scripts/gm_client.py 已经依赖它）。

启动：
    scripts/bot/start_console.sh            # 推荐（会挑带 thrift 的解释器）
    python3 scripts/bot/bot_console.py      # 直接跑，默认 127.0.0.1:18766

环境变量：
    TS_REDIS_HOST / TS_REDIS_PORT     默认 127.0.0.1:6379
    TS_GM_HOST / TS_GM_PORT           默认 127.0.0.1:7916（线上要开 ssh 隧道）
    TS_SERVER_ID                      默认自动从 ONLINE_NUM:* 探测
    TS_BRIDGE_URL                     默认 http://127.0.0.1:18765
    TS_CONSOLE_PORT                   默认 18766
    TS_CHAT_LIMIT                     世界频道显示条数，默认 60
"""

from __future__ import annotations

import json
import os
import socket
import struct
import sys
import time
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

REDIS_HOST = os.environ.get("TS_REDIS_HOST", "127.0.0.1")
REDIS_PORT = int(os.environ.get("TS_REDIS_PORT", "6379"))
GM_HOST = os.environ.get("TS_GM_HOST", "127.0.0.1")
GM_PORT = int(os.environ.get("TS_GM_PORT", "7916"))
BRIDGE_URL = os.environ.get("TS_BRIDGE_URL", "http://127.0.0.1:18765")
CONSOLE_HOST = os.environ.get("TS_CONSOLE_HOST", "127.0.0.1")
CONSOLE_PORT = int(os.environ.get("TS_CONSOLE_PORT", "18766"))
SERVER_ID = os.environ.get("TS_SERVER_ID", "").strip()
CHAT_LIMIT = int(os.environ.get("TS_CHAT_LIMIT", "60"))

# gm_client 依赖 thrift，导入失败时只禁用「操作按钮」，看板照常能看
try:
    sys.path.insert(0, os.path.join(ROOT, "scripts"))
    import gm_client  # noqa: E402

    GM_OK = True
    GM_ERR = ""
except Exception as e:  # noqa: BLE001
    gm_client = None
    GM_OK = False
    GM_ERR = str(e)


def log(msg: str) -> None:
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


# --------------------------------------------------------------------------- Redis（裸 RESP）

class Redis:
    """够用就行的 RESP 客户端：GET / LRANGE / KEYS / TTL。"""

    def __init__(self, host: str, port: int, timeout: float = 3.0) -> None:
        self.host = host
        self.port = port
        self.timeout = timeout

    def _connect(self) -> socket.socket:
        s = socket.create_connection((self.host, self.port), timeout=self.timeout)
        s.settimeout(self.timeout)
        return s

    def cmd(self, *args):
        payload = f"*{len(args)}\r\n".encode()
        for a in args:
            b = a if isinstance(a, bytes) else str(a).encode()
            payload += f"${len(b)}\r\n".encode() + b + b"\r\n"
        s = self._connect()
        try:
            s.sendall(payload)
            return _read_reply(s.makefile("rb"))
        finally:
            s.close()

    def get(self, key: str):
        v = self.cmd("GET", key)
        return v.decode("utf-8", "ignore") if isinstance(v, bytes) else v

    def lrange(self, key: str, start: int, end: int):
        v = self.cmd("LRANGE", key, start, end)
        return v if isinstance(v, list) else []

    def keys(self, pattern: str):
        v = self.cmd("KEYS", pattern)
        return [x.decode("utf-8", "ignore") for x in v] if isinstance(v, list) else []


def _read_reply(f):
    line = f.readline()
    if not line:
        return None
    t, body = line[:1], line[1:-2]
    if t == b"+":
        return body.decode("utf-8", "ignore")
    if t == b"-":
        raise RuntimeError(body.decode("utf-8", "ignore"))
    if t == b":":
        return int(body)
    if t == b"$":
        n = int(body)
        if n < 0:
            return None
        data = f.read(n)
        f.read(2)
        return data
    if t == b"*":
        n = int(body)
        if n < 0:
            return None
        return [_read_reply(f) for _ in range(n)]
    return None


REDIS = Redis(REDIS_HOST, REDIS_PORT)


def detect_server_id() -> str:
    if SERVER_ID:
        return SERVER_ID
    try:
        keys = REDIS.keys("ONLINE_NUM:*")
        if keys:
            return keys[0].split(":", 1)[1]
    except Exception:  # noqa: BLE001
        pass
    return "10001"


# --------------------------------------------------------------------------- protobuf 解码

def _varint(buf: bytes, i: int):
    shift = result = 0
    while True:
        b = buf[i]
        i += 1
        result |= (b & 0x7F) << shift
        if not b & 0x80:
            return result, i
        shift += 7


def parse_chat_info(data: bytes) -> dict:
    """按 proto/protos/ChatProto.proto 解 ChatInfo 里我们关心的字段。"""
    out = {}
    i, n = 0, len(data)
    while i < n:
        key, i = _varint(data, i)
        field, wire = key >> 3, key & 7
        if wire == 0:  # varint
            val, i = _varint(data, i)
        elif wire == 1:  # 64-bit
            val = struct.unpack("<Q", data[i:i + 8])[0]
            i += 8
        elif wire == 2:  # length-delimited
            ln, i = _varint(data, i)
            raw = data[i:i + ln]
            i += ln
            try:
                val = raw.decode("utf-8")
            except UnicodeDecodeError:
                val = raw
        elif wire == 5:  # 32-bit
            val = struct.unpack("<I", data[i:i + 4])[0]
            i += 4
        else:
            break

        if field == 1:
            out["senderId"] = val
        elif field == 2:
            out["senderName"] = val
        elif field == 3:
            out["level"] = val
        elif field == 5:
            out["vip"] = val
        elif field == 6:
            out["times"] = val
        elif field == 7:
            out["msg"] = val
        elif field == 8:
            out["head"] = val
        elif field == 9:
            out["frame"] = val
        elif field == 10:
            out["soulVal"] = val
        elif field == 11:
            out["messageId"] = val
        elif field == 13:
            out["messageType"] = val
        elif field == 14:
            out["itemId"] = val
        elif field == 15:
            out["type"] = val
        elif field == 22:
            out.setdefault("chatparms", []).append(val)
        elif field == 25:
            out["serverId"] = val
        elif field == 26:
            out["serverName"] = val
        elif field == 28:
            out["country"] = val
    return out


def strip_world_prefix(msg: str) -> str:
    """客户端协议："<type>|<content>"，type=0 是普通聊天。"""
    if not msg:
        return ""
    bar = msg.find("|")
    if bar < 0:
        return msg
    head = msg[:bar]
    if head and all(c.isdigit() or c == "#" for c in head):
        return msg[bar + 1:]
    return msg


# --------------------------------------------------------------------------- 数据聚合

def read_chats(sid: str, limit: int) -> list:
    """世界频道最近 N 条，解成前端直接渲染的结构。"""
    try:
        raw = REDIS.lrange(f"{sid}:CHAT_QUEUE:world", -limit, -1)
    except Exception as e:  # noqa: BLE001
        log(f"读聊天队列失败: {e}")
        return []
    out = []
    for item in raw:
        try:
            text = item.decode("utf-8", "ignore")
            mid, ts, b64 = text.split("#", 2)
            import base64

            info = parse_chat_info(base64.b64decode(b64))
            out.append({
                "messageId": int(mid),
                "ts": int(ts),
                "uid": info.get("senderId", 0),
                "name": info.get("senderName", "?"),
                "text": strip_world_prefix(info.get("msg", "")),
                "level": info.get("level", 0),
                "vip": info.get("vip", 0),
                "country": info.get("country", ""),
                "soulVal": info.get("soulVal", 0),
                "isBot": int(info.get("senderId", 0)) >= 90000000,
            })
        except Exception:  # noqa: BLE001
            continue
    out.sort(key=lambda x: x["messageId"])
    return out


def read_status(sid: str):
    try:
        raw = REDIS.get(f"{sid}:BOT_STATUS")
        return json.loads(raw) if raw else None
    except Exception as e:  # noqa: BLE001
        log(f"读 BOT_STATUS 失败: {e}")
        return None


def read_bridge():
    try:
        with urllib.request.urlopen(f"{BRIDGE_URL}/health", timeout=2) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception:  # noqa: BLE001
        return None


def snapshot() -> dict:
    sid = detect_server_id()
    status = read_status(sid)
    online = None
    try:
        online = REDIS.get(f"ONLINE_NUM:{sid}")
    except Exception:  # noqa: BLE001
        pass
    return {
        "ok": True,
        "now": int(time.time() * 1000),
        "serverId": sid,
        "onlineNum": int(online) if online not in (None, "") else None,
        "status": status,
        "statusFresh": bool(status) and (time.time() * 1000 - status.get("ts", 0) < 60000),
        "bridge": read_bridge(),
        "chats": read_chats(sid, CHAT_LIMIT),
        "gm": {"ok": GM_OK, "err": GM_ERR, "host": GM_HOST, "port": GM_PORT},
        "redis": {"host": REDIS_HOST, "port": REDIS_PORT},
    }


# --------------------------------------------------------------------------- 动作（GM）

def gm(cmd: str):
    if not GM_OK:
        return {"ok": False, "error": f"thrift 不可用: {GM_ERR}"}
    try:
        code, msg = gm_client.call(cmd, host=GM_HOST, port=GM_PORT)
        return {"ok": True, "cmd": cmd, "code": code, "msg": msg}
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "cmd": cmd, "error": str(e)}


def do_action(action: str, payload: dict) -> dict:
    a = (action or "").strip().lower()
    if a in ("on", "off", "reload", "status", "reply"):
        return gm(f"bot {a}")
    if a == "say":
        text = (payload.get("text") or "").strip()
        if not text:
            return {"ok": False, "error": "文本为空"}
        return gm(f"bot say {text}")
    if a == "announce":
        hero = str(payload.get("heroId") or "").strip()
        return gm(f"bot announce {hero}".strip())
    if a == "fake":
        name = (payload.get("name") or "Tester").strip()
        text = (payload.get("text") or "").strip()
        if not text:
            return {"ok": False, "error": "文本为空"}
        return gm(f"bot fake {name} {text}")
    return {"ok": False, "error": f"未知动作 {action}"}


# --------------------------------------------------------------------------- HTTP

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # 静音访问日志
        return

    def _json(self, code: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _file(self, path: str, ctype: str) -> None:
        try:
            with open(path, "rb") as f:
                body = f.read()
        except OSError:
            self._json(404, {"error": "not found"})
            return
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):  # noqa: N802
        if self.path.startswith("/api/snapshot"):
            try:
                self._json(200, snapshot())
            except Exception as e:  # noqa: BLE001
                self._json(500, {"ok": False, "error": str(e)})
            return
        if self.path in ("/", "/index.html", "/console.html"):
            self._file(os.path.join(HERE, "console.html"), "text/html; charset=utf-8")
            return
        self._json(404, {"error": "not found"})

    def do_POST(self):  # noqa: N802
        if not self.path.startswith("/api/action"):
            self._json(404, {"error": "not found"})
            return
        try:
            n = int(self.headers.get("Content-Length") or 0)
            payload = json.loads(self.rfile.read(n).decode("utf-8") or "{}")
        except Exception as e:  # noqa: BLE001
            self._json(400, {"ok": False, "error": f"bad json: {e}"})
            return
        res = do_action(payload.get("action", ""), payload)
        log(f"action {payload.get('action')} -> {res.get('ok')} {res.get('cmd', '')}")
        self._json(200, res)


def main() -> None:
    sid = detect_server_id()
    log(f"console on http://{CONSOLE_HOST}:{CONSOLE_PORT}  server={sid} redis={REDIS_HOST}:{REDIS_PORT} "
        f"gm={GM_HOST}:{GM_PORT} bridge={BRIDGE_URL} gmOk={GM_OK}")
    if not GM_OK:
        log(f"⚠️ GM 不可用（{GM_ERR}），看板可用但操作按钮会报错；用 scripts/bot/start_console.sh 启动会自动选带 thrift 的解释器")
    srv = ThreadingHTTPServer((CONSOLE_HOST, CONSOLE_PORT), Handler)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        log("bye")


if __name__ == "__main__":
    main()
