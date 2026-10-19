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
import os
import re
import socket
import sys
import time

HOST = "127.0.0.1"
# 🔴 端口不是固定的：每次进 Play / 重载程序集 StdioBridgeHost 会顺延（6400 → 6401 → …）。
#    所以默认自动探测，别把 6400 写死（写死会在重进 Play 后连不上）。
PORT = None
PORT_RANGE = (6400, 6401, 6402, 6403, 6404, 6405)
TIMEOUT = 300.0
# 握手后到发第一帧之间的静默期（秒）：0 会让桥偶发直接断开，见 Bridge.__init__ 注释
HANDSHAKE_SETTLE = 0.3

_EDITOR_LOG = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "Logs", "Editor.log")


def _port_from_log():
    """从 Logs/Editor.log 尾部倒着找最后一次『StdioBridgeHost started on port N』。

    🔴 只扫固定 400KB 会失效：日志一多那条记录就被挤出窗口，detect_port 退化成
       “试探连接”，而 StdioBridgeHost 会把 New connection 之前的客户端判成 stale
       并 Close ⇒ 那条白扔的试探连接会让紧随其后的真连接被一起打死（现象：握手拿到
       了，发帧后 0.00s 断，报 bridge closed mid-frame）。所以这里分块倒读。
    """
    try:
        with open(_EDITOR_LOG, "rb") as fh:
            fh.seek(0, os.SEEK_END)
            pos = fh.tell()
            tail = b""
            while pos > 0:
                step = min(1 << 20, pos)
                pos -= step
                fh.seek(pos)
                tail = fh.read(step) + tail
                hits = re.findall(rb"StdioBridgeHost started on port (\d+)", tail)
                if hits:
                    return int(hits[-1])
                if len(tail) > (8 << 20):   # 8MB 还找不到就别找了
                    break
    except OSError:
        return None
    return None


_PORT_CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".unity_bridge_port")


def _port_from_cache():
    try:
        with open(_PORT_CACHE) as fh:
            return int(fh.read().strip())
    except (OSError, ValueError):
        return None


def _save_port(port):
    try:
        with open(_PORT_CACHE, "w") as fh:
            fh.write(str(port))
    except OSError:
        pass


def _candidate_ports():
    """log → 上次成功的缓存 → 全范围。去重保序。"""
    seen, out = set(), []
    for p in (_port_from_log(), _port_from_cache()) + tuple(PORT_RANGE):
        if p is not None and p not in seen:
            seen.add(p)
            out.append(p)
    return out



def _recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("bridge closed mid-frame")
        buf += chunk
    return buf


class Bridge:
    def __init__(self, host=HOST, port=None, timeout=TIMEOUT):
        # port=None ⇒ 自动探测（Editor 重进 Play 后端口会变）
        # 🔴 探测一律用“真连接”去试，绝不先开一条试探连接再关：那条连接会被
        #    StdioBridgeHost 当成 stale client，新连接一进来就被连带 Close。
        ports = [port] if port else _candidate_ports()
        last_err = None
        for p in ports:
            try:
                self.sock = socket.create_connection((host, p), timeout=timeout)
            except OSError as exc:
                last_err = exc
                continue
            self.sock.settimeout(timeout)
            # 握手行以 \n 结尾，逐字节读到换行为止
            line = b""
            try:
                while not line.endswith(b"\n"):
                    c = self.sock.recv(1)
                    if not c:
                        raise ConnectionError("no handshake")
                    line += c
            except (ConnectionError, OSError) as exc:
                last_err = exc
                try:
                    self.sock.close()
                except Exception:
                    pass
                continue
            self.port = p
            self.handshake = line.decode("ascii", "replace").strip()
            _save_port(p)
            # 🔴 握手后立刻发帧会被 StdioBridgeHost 直接 Close（实测 0.00s 断开，
            #    手工在两眼之间 sleep 0.3s 就能成功）⇒ 这里必须等一下，别省。
            time.sleep(HANDSHAKE_SETTLE)
            return
        raise ConnectionError("no StdioBridgeHost reachable on %s (%s)" % (ports, last_err))

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
