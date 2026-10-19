#!/usr/bin/env python3
"""GM「以玩家UID重登」链路探针（只读 + 会在 Redis 写一条 JL_TOKEN，仅用于本地自测服）。

流程与真实客户端完全一致：
  明文 = [uid:4BE][token:4BE][msgId:4BE][sn:4BE][GMCommand protobuf]
  TEA(32 轮, 固定 KEY) + 2 字节长度前缀（服务端 TeaDecoder 读法）
  msgId: GM_REQUEST=10606 / GM_RESPONSE=10607

用法:
  python3 scripts/verify/gm_uid_login_probe.py --operator 10000002 --target 10000004
  可选 --host/--port/--redis 覆盖默认 127.0.0.1:16081 / 127.0.0.1:6379

判定:
  - 返回 "uid#token" 且 uid == target  → 功能可用
  - 返回 "玩家不存在:xxx"              → 目标号在游戏库没有存档
  - 返回 "In a formal setting"         → 服务端 debug=false（生产服就是这个表现）
"""
import argparse
import socket
import struct
import sys

TEA_KEY = [0x789F5645, 0xF68BD5A4, 0x81963FFA, 0x458FAC58]
DELTA = 0x9E3779B9
ROUNDS = 32
MASK = 0xFFFFFFFF

GM_REQUEST = 10606
GM_RESPONSE = 10607
LOGIN_REQUEST = 11100
LOGIN_RESPONSE = 11101


def _s32(x):
    """模拟 C# 的 int32：溢出截断 + 有符号（`>>` 必须是算术右移）。"""
    x &= MASK
    return x - 0x100000000 if x & 0x80000000 else x


def _enc_block(y, z):
    k = TEA_KEY
    y, z, s = _s32(y), _s32(z), 0
    for _ in range(ROUNDS):
        s = _s32(s + DELTA)
        y = _s32(y + (_s32((z << 4) + k[0]) ^ _s32(z + s) ^ _s32((z >> 5) + k[1])))
        z = _s32(z + (_s32((y << 4) + k[2]) ^ _s32(y + s) ^ _s32((y >> 5) + k[3])))
    return y & MASK, z & MASK


def _dec_block(y, z):
    k = TEA_KEY
    y, z, s = _s32(y), _s32(z), _s32(0xC6EF3720)
    for _ in range(ROUNDS):
        z = _s32(z - (_s32((y << 4) + k[2]) ^ _s32(y + s) ^ _s32((y >> 5) + k[3])))
        y = _s32(y - (_s32((z << 4) + k[0]) ^ _s32(z + s) ^ _s32((z >> 5) + k[1])))
        s = _s32(s - DELTA)
    return y & MASK, z & MASK


def encrypt2(data: bytes) -> bytes:
    total = (len(data) + 7) // 8 * 8 + 2
    buf = bytearray(total)
    buf[2:2 + len(data)] = data
    buf[0] = (len(data) >> 8) & 0xFF
    buf[1] = len(data) & 0xFF
    for m in range(2, total, 8):
        y = int.from_bytes(buf[m:m + 4], "big")
        z = int.from_bytes(buf[m + 4:m + 8], "big")
        y, z = _enc_block(y, z)
        buf[m:m + 4] = y.to_bytes(4, "big")
        buf[m + 4:m + 8] = z.to_bytes(4, "big")
    return bytes(buf)


def decrypt(data: bytes, plain_len: int) -> bytes:
    buf = bytearray(data)
    for m in range(0, len(buf), 8):
        y = int.from_bytes(buf[m:m + 4], "big")
        z = int.from_bytes(buf[m + 4:m + 8], "big")
        y, z = _dec_block(y, z)
        buf[m:m + 4] = y.to_bytes(4, "big")
        buf[m + 4:m + 8] = z.to_bytes(4, "big")
    return bytes(buf[:plain_len])


def pb_string_field(field_no: int, value: str) -> bytes:
    raw = value.encode("utf-8")
    return bytes([(field_no << 3) | 2, len(raw)]) + raw


def pb_parse_strings(payload: bytes):
    """极简 protobuf 解析：只取 length-delimited 字段，返回 {field_no: bytes}。"""
    out, i = {}, 0
    while i < len(payload):
        tag = payload[i]
        i += 1
        field_no, wire = tag >> 3, tag & 7
        if wire == 0:  # varint
            while i < len(payload) and payload[i] & 0x80:
                i += 1
            i += 1
        elif wire == 2:
            ln = payload[i]
            i += 1
            out[field_no] = payload[i:i + ln]
            i += ln
        elif wire == 5:
            i += 4
        elif wire == 1:
            i += 8
        else:
            break
    return out


def redis_get(key: str, host: str, port: int):
    with socket.create_connection((host, port), timeout=3) as s:
        cmd = f"*2\r\n$3\r\nGET\r\n${len(key)}\r\n{key}\r\n".encode()
        s.sendall(cmd)
        data = s.recv(4096)
    if data.startswith(b"$-1"):
        return None
    # $<len>\r\n<value>\r\n
    head, _, rest = data.partition(b"\r\n")
    return rest.rstrip(b"\r\n").decode()


def recv_exact(s, n):
    buf = b""
    while len(buf) < n:
        chunk = s.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("socket closed")
        buf += chunk
    return buf


def recv_frame(s):
    """服务端下行帧：2 字节大端明文长度 + TEA 加密体（8 字节对齐），与客户端 encrypt2 对称。"""
    head = recv_exact(s, 2)
    msg_len = struct.unpack(">H", head)[0]
    if msg_len == 0:
        return None
    enc_len = (msg_len + 7) // 8 * 8
    raw = recv_exact(s, enc_len)
    plain = decrypt(raw, msg_len)
    if len(plain) < 16:
        return None
    uid, token, msg_id, sn = struct.unpack(">iiii", plain[:16])
    return uid, token, msg_id, sn, plain[16:]


def send_packet(s, uid, token, msg_id, sn, payload):
    body = struct.pack(">iiii", uid, token, msg_id, sn) + payload
    s.sendall(encrypt2(body))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=16081)
    ap.add_argument("--redis", default="127.0.0.1:6379")
    ap.add_argument("--operator", type=int, required=True, help="用哪个已登录 uid 的 token 发起请求")
    ap.add_argument("--target", type=int, required=True, help="要以哪个 uid 重登")
    ap.add_argument("--openid", default="gm_probe", help="登录请求里带的 openId（仅用于写会话记录）")
    args = ap.parse_args()

    rhost, rport = args.redis.split(":")
    token = redis_get(f"JL_TOKEN:{args.operator}", rhost, int(rport))
    if not token:
        print(f"❌ Redis 没有 JL_TOKEN:{args.operator}（该号没登录过）")
        return 2
    token = int(token)

    with socket.create_connection((args.host, args.port), timeout=5) as s:
        s.settimeout(5)
        # 1) 先登录：服务端在 LOGIN_REQUEST 里用 uid+token 校验 Redis 并绑定 session
        send_packet(s, args.operator, token, LOGIN_REQUEST, 1, pb_string_field(10, args.openid))
        login_ok = False
        for _ in range(20):
            try:
                f = recv_frame(s)
            except (socket.timeout, ConnectionError) as e:
                print(f"❌ 登录阶段无响应: {e}")
                return 3
            if f and f[2] == LOGIN_RESPONSE:
                login_ok = True
                break
        if not login_ok:
            print("❌ 没收到 LOGIN_RESPONSE")
            return 3

        # 2) 发 GM 命令
        cmd = f"40#{args.target}#0"
        send_packet(s, args.operator, token, GM_REQUEST, 2, pb_string_field(1, cmd))
        for _ in range(40):
            try:
                f = recv_frame(s)
            except (socket.timeout, ConnectionError) as e:
                print(f"❌ GM 阶段无响应: {e}")
                return 4
            if not f or f[2] != GM_RESPONSE:
                continue
            info = pb_parse_strings(f[4]).get(2, b"").decode("utf-8", "replace")
            print(f"请求: {cmd}  (operator={args.operator})")
            print(f"响应: msgId={f[2]} info='{info}'")
            if info.startswith(f"{args.target}#"):
                print("✅ 通过：服务端已签发 uid#token，客户端可按此重登")
                return 0
            print("⚠️ 返回了非预期内容（见 info）")
            return 1
        print("❌ 未收到 GM_RESPONSE")
        return 4


if __name__ == "__main__":
    sys.exit(main())
