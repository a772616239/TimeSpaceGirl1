#!/usr/bin/env python3
"""服务端「协议连通自检」——发包后用真实客户端字节流验证各协议是否正常。

与 `gm_uid_login_probe.py` 的关系：**复用它的 TEA/帧/Redis 原语**，不复制一份实现
（改密钥、改对齐只改一处）。本脚本只负责「按矩阵跑一遍 + 出结论」。

为什么不是「上线自检」里那几个端口 grep：
  端口在听 ≠ 协议通。`ss -ltn` 看到 16081 只能证明 netty 起来了，
  证明不了 TEA 密钥/2 字节长度前缀/8 字节对齐/回包编码这几层还是对的。
  这几层一错，客户端表现就是「连上就断」，而服务端日志只有一行 decode error。

检查矩阵（每项独立，互不阻断）：

  codec        TEA 帧编解码往返自检（纯本地数学，随机 20 帧）——防密钥/对齐回归
  tcp          游戏服端口 TCP 可连（网络层）
  duplex       发心跳帧后服务端**是否真的往回写字节**（下行编码器 + 通道双向通）
  auth-guard   未登录直接发 GM_REQUEST，不得拿到 GM_RESPONSE（鉴权没被绕过）
  session      登录态存储可读（SSH 只读数 JL_TOKEN:* 键）
  login-e2e    真登录 + GM 命令（**默认关闭**，开了会用某个真实账号的 token 建会话，
               若该号在线会被顶掉。生产环境别默认开）

判定与退出码：
  pass 全通 / skip 未启用 / warn 要人看一眼（不判失败）/ fail 硬失败
  rc=0 全 pass 或含 skip；rc=1 有 fail；rc=3 只有 warn

输出两种格式：
  - 人读的行（进 Jenkins 控制台）
  - `CHECK|name|status|detail` 行（与 jenkins-shared/lib/checks_to_junit.py 的协议一致）

用法：
  生产（默认，不碰任何账号）：
    python3 scripts/verify/protocol_selftest.py --host 129.226.213.65 --port 16081 --ssh gs
  本地服（等同昨天手工跑的那套）：
    python3 scripts/verify/protocol_selftest.py --host 127.0.0.1 --port 16081 \
        --redis 127.0.0.1:6379 --operator 10000002 --target 10000004 --allow-login
"""
import argparse
import json
import os
import random
import socket
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gm_uid_login_probe import (  # noqa: E402  同目录复用，勿另起一份
    GM_REQUEST,
    GM_RESPONSE,
    LOGIN_REQUEST,
    LOGIN_RESPONSE,
    encrypt2,
    decrypt,
    pb_parse_strings,
    pb_string_field,
    recv_exact,
    recv_frame,
    redis_get,
    send_packet,
)

HEART_BEAT_REQUEST = 1000
HEART_BEAT_RESPONSE = 1001

PASS, WARN, SKIP, FAIL = "pass", "warn", "skip", "fail"
ICON = {PASS: "✅", WARN: "⚠️ ", SKIP: "⏭️ ", FAIL: "❌"}


class Report:
    """收集各项结论。顺序即执行顺序，看控制台就能对上矩阵。"""

    def __init__(self):
        self.rows = []

    def add(self, name, status, detail):
        self.rows.append({"name": name, "status": status, "detail": detail})
        print(f"{ICON.get(status, '?')} {name:<12} {status:<4} {detail}")

    def worst(self):
        if any(r["status"] == FAIL for r in self.rows):
            return FAIL
        if any(r["status"] == WARN for r in self.rows):
            return WARN
        return PASS

    def rc(self):
        return {PASS: 0, SKIP: 0, WARN: 3, FAIL: 1}[self.worst()]


def split_frame(blob):
    """encrypt2 的输出 = 2 字节明文长度 + 8 字节对齐密文。拆开才能自校验。"""
    return blob[:2], blob[2:]


def check_codec(rep):
    """纯本地：加密 → 拆帧 → 解密，必须回到原文。防的是「改了 KEY / 改了 padding」。"""
    lengths = [16, 17, 23, 24, 100, 1000] + [random.randint(16, 4096) for _ in range(14)]
    for n in lengths:
        payload = bytes(random.getrandbits(8) for _ in range(n))
        prefix, body = split_frame(encrypt2(payload))
        plain_len = int.from_bytes(prefix, "big")
        if plain_len != n:
            rep.add("codec", FAIL, f"长度前缀不符：写入 {n} 读回 {plain_len}")
            return
        if len(body) % 8 != 0:
            rep.add("codec", FAIL, f"密文长度 {len(body)} 不是 8 的倍数")
            return
        if decrypt(body, plain_len) != payload:
            rep.add("codec", FAIL, f"{n} 字节往返后内容不一致")
            return
    rep.add("codec", PASS, f"{len(lengths)} 帧往返一致（16B~4KB，含随机长度）")


def check_tcp(rep, host, port, timeout):
    t0 = time.time()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            pass
        rep.add("tcp", PASS, f"{host}:{port} 可连（{(time.time() - t0) * 1000:.0f}ms）")
    except Exception as e:
        rep.add("tcp", FAIL, f"{host}:{port} 连不上：{type(e).__name__}: {e}")


def check_duplex(rep, host, port, timeout):
    """发一个心跳帧，看服务端有没有**往回写字节**。

    服务端 TeaDecoder 对 length==0 的包直接 return（日志写「empty heartbeat package」），
    所以这里发的是带 16 字节包头 + 空 payload 的合法帧（length=16，非 0）。
    判定：
      收到任何字节   → 通道双向通（下行编码器 + socket 写路径都活着）
      对端直接关闭   → warn：连接被拒，常见于未登录会话被踢，不判失败但要看
      一个字节都没有 → fail：服务端收包但不处理，通常是解码线程卡死/OOM 后僵死
    """
    t0 = time.time()
    try:
        with socket.create_connection((host, port), timeout=timeout) as s:
            s.settimeout(timeout)
            send_packet(s, 0, 0, HEART_BEAT_REQUEST, 1, b"")
            try:
                head = recv_exact(s, 2)
            except ConnectionError:
                rep.add("duplex", WARN, f"服务端收包后直接断开（{(time.time() - t0) * 1000:.0f}ms），未登录会话被拒")
                return
            except socket.timeout:
                rep.add("duplex", FAIL, f"{timeout}s 内零字节返回：服务端收了心跳却不写回，疑似解码/回包线程卡死")
                return
            rep.add("duplex", PASS,
                    f"服务端有回写（首 2 字节 = {head.hex()}，{(time.time() - t0) * 1000:.0f}ms）")
    except Exception as e:
        rep.add("duplex", FAIL, f"心跳阶段异常：{type(e).__name__}: {e}")


def check_auth_guard(rep, host, port, timeout):
    """未登录直接用 GM_REQUEST，绝不能拿到 GM_RESPONSE —— 那是提权漏洞。"""
    try:
        with socket.create_connection((host, port), timeout=timeout) as s:
            s.settimeout(timeout)
            send_packet(s, 0, 0, GM_REQUEST, 1, pb_string_field(1, "1#0#0"))
            deadline = time.time() + timeout
            while time.time() < deadline:
                try:
                    f = recv_frame(s)
                except socket.timeout:
                    break
                except ConnectionError:
                    rep.add("auth-guard", PASS, "未登录 GM 请求被断开（期望行为）")
                    return
                if f and f[2] == GM_RESPONSE:
                    info = pb_parse_strings(f[4]).get(2, b"").decode("utf-8", "replace")
                    rep.add("auth-guard", FAIL, f"未登录竟拿到 GM_RESPONSE（info='{info}'）——鉴权缺口")
                    return
            # 没回包就是期望结果：静默丢弃和主动断开都算「没被绕过」。
            # 别在这里报 warn —— 告警必须对应真实后果，收不到回包恰恰是安全的那种。
            # 服务端是不是还活着由 duplex 那一项负责证明，两项职责不重叠。
            rep.add("auth-guard", PASS, "未登录 GM 请求未获回包（静默丢弃/断开），鉴权未被绕过")
    except Exception as e:
        rep.add("auth-guard", WARN, f"未登录 GM 请求异常：{type(e).__name__}: {e}")


def redis_count_via_ssh(ssh_host, pattern="JL_TOKEN:*"):
    """SSH 到服务器上只读数键。不取任何值，只要条数。"""
    cmd = f"redis-cli --scan --pattern '{pattern}' 2>/dev/null | wc -l"
    out = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", ssh_host, cmd],
                         capture_output=True, text=True, timeout=40)
    if out.returncode != 0:
        raise RuntimeError((out.stderr or "").strip() or f"ssh rc={out.returncode}")
    return int((out.stdout or "0").strip() or 0)


def check_session(rep, args):
    if not args.ssh:
        rep.add("session", SKIP, "未给 --ssh，跳过登录态存储检查")
        return
    try:
        n = redis_count_via_ssh(args.ssh)
    except Exception as e:
        rep.add("session", WARN, f"SSH 取 JL_TOKEN 条数失败：{e}")
        return
    if n >= 1:
        rep.add("session", PASS, f"JL_TOKEN 共 {n} 条（登录态写入链路在工作）")
    else:
        rep.add("session", WARN, "JL_TOKEN 为 0 条：可能只是没人登录，也可能登录态没落库")


def fetch_token(args):
    """取 operator 的会话 token：本地直连 Redis，或 SSH 到服务器上取。"""
    if args.token:
        return int(args.token)
    if args.redis:
        rhost, rport = args.redis.split(":")
        tok = redis_get(f"JL_TOKEN:{args.operator}", rhost, int(rport))
        if tok:
            return int(tok)
        raise RuntimeError(f"Redis 没有 JL_TOKEN:{args.operator}")
    if args.ssh:
        cmd = f"redis-cli GET JL_TOKEN:{args.operator} 2>/dev/null"
        out = subprocess.run(["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", args.ssh, cmd],
                             capture_output=True, text=True, timeout=40)
        tok = (out.stdout or "").strip()
        if tok and tok.isdigit():
            return int(tok)
        raise RuntimeError(f"服务器 Redis 没有 JL_TOKEN:{args.operator}")
    raise RuntimeError("未给 --token / --redis / --ssh，取不到会话 token")


def check_login_e2e(rep, args):
    """真登录 + GM 命令。生产默认不开（会建会话，可能顶掉在线玩家）。"""
    if not args.allow_login:
        rep.add("login-e2e", SKIP, "未启用 --allow-login（生产默认不建会话，避免顶号）")
        return
    if not args.operator:
        rep.add("login-e2e", SKIP, "未给 --operator")
        return
    target = args.target or args.operator
    try:
        token = fetch_token(args)
    except Exception as e:
        rep.add("login-e2e", WARN, f"取 token 失败：{e}")
        return
    try:
        with socket.create_connection((args.host, args.port), timeout=args.timeout) as s:
            s.settimeout(args.timeout)
            send_packet(s, args.operator, token, LOGIN_REQUEST, 1, pb_string_field(10, args.openid))
            logged_in = False
            for _ in range(20):
                try:
                    f = recv_frame(s)
                except socket.timeout:
                    break
                except ConnectionError:
                    break
                if f and f[2] == LOGIN_RESPONSE:
                    logged_in = True
                    break
            if not logged_in:
                rep.add("login-e2e", FAIL, f"uid={args.operator} 没收到 LOGIN_RESPONSE（token 可能已过期）")
                return

            cmd = f"40#{target}#0"
            send_packet(s, args.operator, token, GM_REQUEST, 2, pb_string_field(1, cmd))
            for _ in range(40):
                try:
                    f = recv_frame(s)
                except (socket.timeout, ConnectionError):
                    break
                if not f or f[2] != GM_RESPONSE:
                    continue
                info = pb_parse_strings(f[4]).get(2, b"").decode("utf-8", "replace")
                if info.startswith(f"{target}#"):
                    rep.add("login-e2e", PASS, f"登录+GM 全通：{cmd} → '{info[:40]}'")
                elif "formal setting" in info:
                    # 生产 debug=false 的固定表现：协议通、GM 业务关闭。判 pass 但写明。
                    rep.add("login-e2e", PASS, f"登录通、GM 协议通但业务关闭（生产 debug=false）：'{info[:40]}'")
                else:
                    rep.add("login-e2e", WARN, f"回包非预期：'{info[:60]}'")
                return
            rep.add("login-e2e", FAIL, "登录成功但 GM 无回包")
    except Exception as e:
        rep.add("login-e2e", FAIL, f"链路异常：{type(e).__name__}: {e}")


def main():
    ap = argparse.ArgumentParser(description="服务端协议连通自检")
    ap.add_argument("--host", default="129.226.213.65", help="游戏服地址")
    ap.add_argument("--port", type=int, default=16081, help="游戏服端口")
    ap.add_argument("--timeout", type=float, default=5.0, help="单步超时（秒）")
    ap.add_argument("--ssh", default="", help="SSH 别名（如 gs），用于只读取会话 token/计数")
    ap.add_argument("--redis", default="", help="本地直连 Redis（如 127.0.0.1:6379），给了就不走 ssh")
    ap.add_argument("--operator", type=int, default=0, help="login-e2e 用哪个 uid 发起")
    ap.add_argument("--target", type=int, default=0, help="login-e2e 要以哪个 uid 重登（缺省同 operator）")
    ap.add_argument("--token", default="", help="直接给会话 token，免 Redis")
    ap.add_argument("--openid", default="jenkins_probe", help="登录请求里的 openId（仅写会话记录）")
    ap.add_argument("--allow-login", action="store_true", help="允许真登录（生产慎用：可能顶号）")
    ap.add_argument("--json-out", default="", help="把结论写成 JSON")
    args = ap.parse_args()

    print(f"目标 {args.host}:{args.port} · 超时 {args.timeout}s · "
          f"登录用例 {'启用' if args.allow_login else '关闭'}")

    rep = Report()
    check_codec(rep)
    check_tcp(rep, args.host, args.port, args.timeout)
    check_duplex(rep, args.host, args.port, args.timeout)
    check_auth_guard(rep, args.host, args.port, args.timeout)
    check_session(rep, args)
    check_login_e2e(rep, args)

    print()
    for r in rep.rows:
        print(f"CHECK|{r['name']}|{r['status']}|{r['detail']}")
    summary = {s: sum(1 for r in rep.rows if r["status"] == s) for s in (PASS, WARN, SKIP, FAIL)}
    print()
    print(f"结论：{rep.worst()} — 通过 {summary[PASS]} · 关注 {summary[WARN]} · "
          f"跳过 {summary[SKIP]} · 失败 {summary[FAIL]}")

    if args.json_out:
        os.makedirs(os.path.dirname(os.path.abspath(args.json_out)), exist_ok=True)
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump({"target": f"{args.host}:{args.port}", "verdict": rep.worst(),
                       "counts": summary, "checks": rep.rows}, fh, ensure_ascii=False, indent=2)
    return rep.rc()


if __name__ == "__main__":
    sys.exit(main())
