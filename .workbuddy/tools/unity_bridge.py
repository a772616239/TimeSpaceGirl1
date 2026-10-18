#!/usr/bin/env python3
"""Unity MCP 直连桥客户端（绕过 Python MCP server，直连 Editor 侧 StdioBridgeHost）。

协议（见 Library/PackageCache/com.coplaydev.unity-mcp*/Editor/Services/Transport/Transports/StdioBridgeHost.cs）：
  连接后 Editor 先发 ASCII 握手 "WELCOME UNITY-MCP 1 FRAMING=1\\n"
  之后每帧 = 8 字节大端长度 + UTF-8 JSON（请求 {"type": <tool>, "params": {...}}）
  响应同样 8 字节大端长度 + JSON

用法：
  python unity_bridge.py ping
  python unity_bridge.py call execute_code '{"action":"execute","code":"return 1+1;"}'
  python unity_bridge.py code '<c# 源码，末尾 return <expr>; 可拿返回值>'
"""
import json
import socket
import sys
import time

HOST = "127.0.0.1"
PORT = 6400
TIMEOUT = 300.0


def _recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("bridge closed mid-frame")
        buf += chunk
    return buf


class Bridge:
    def __init__(self, host=HOST, port=PORT, timeout=TIMEOUT):
        self.sock = socket.create_connection((host, port), timeout=timeout)
        self.sock.settimeout(timeout)
        # 握手行以 \n 结尾，逐字节读到换行为止
        line = b""
        while not line.endswith(b"\n"):
            c = self.sock.recv(1)
            if not c:
                raise ConnectionError("no handshake")
            line += c
        self.handshake = line.decode("ascii", "replace").strip()

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
        return False

    def call(self, cmd_type, params=None):
        payload = json.dumps({"type": cmd_type, "params": params or {}}, ensure_ascii=False).encode("utf-8")
        self.sock.sendall(len(payload).to_bytes(8, "big") + payload)
        header = _recv_exact(self.sock, 8)
        size = int.from_bytes(header, "big")
        body = _recv_exact(self.sock, size)
        return json.loads(body.decode("utf-8"))

    def close(self):
        try:
            self.sock.close()
        except Exception:
            pass


def run_code(code, compiler="auto"):
    with Bridge() as b:
        return b.call("execute_code", {"action": "execute", "code": code, "compiler": compiler})


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    cmd = sys.argv[1]
    if cmd == "ping":
        b = Bridge()
        print("handshake:", b.handshake)
        print(json.dumps(b.call("read_console", {"action": "get", "count": 1}), ensure_ascii=False)[:800])
        b.close()
    elif cmd == "call":
        b = Bridge()
        params = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        print(json.dumps(b.call(sys.argv[2], params), ensure_ascii=False, indent=2))
        b.close()
    elif cmd == "code":
        src = sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read()
        t0 = time.time()
        out = run_code(src)
        out["_elapsed_s"] = round(time.time() - t0, 2)
        print(json.dumps(out, ensure_ascii=False, indent=2))
    elif cmd == "codef":
        with open(sys.argv[2], encoding="utf-8") as fh:
            src = fh.read()
        t0 = time.time()
        out = run_code(src)
        out["_elapsed_s"] = round(time.time() - t0, 2)
        print(json.dumps(out, ensure_ascii=False, indent=2))
    else:
        print("unknown cmd", cmd)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
