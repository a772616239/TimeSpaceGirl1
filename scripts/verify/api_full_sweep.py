#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""服务端「全量接口扫描」—— 发包后把 proto 里每一个 *_REQUEST 都真发一遍。

与 `protocol_selftest.py` 的分工（**别混用**）：
  protocol_selftest.py  6 个横向切面（编解码/端口/双向/鉴权/会话/真登录），证明「这条链路通」
  api_full_sweep.py     逐个接口（373 个）纵向扫一遍，证明「每个接口都还活着」
  两者都复用 `gm_uid_login_probe.py` 的 TEA/帧/Redis 原语，不另写一份实现。

为什么需要它：
  端口在听、登录能进，都不代表**别的接口**没坏。改一个公共 DAO / 加一张表 / 改一处
  proto，坏掉的往往是某个冷门接口，而它要等玩家点到才暴露。发版后扫一遍，坏在发版
  当场，而不是坏在玩家手里。

判定口径（每个接口一条，互相独立）：
  ok          收到 `请求号+1` 的正常回包
  biz-reject  收到 `请求号+1` 的 ErrorResponse（业务参数缺失被拒）——接口存在且走到了业务层
  no-handler  回包是「request unknow commond」——proto 里有、服务端没注册 handler（**真问题**）
  no-reply    超时零回包 —— handler 静默丢弃或线程卡死（**真问题**）
  disconnected 服务端断开连接 —— handler 把连接搞崩了（**真问题**）
  indirect    收到了帧但没有 `请求号+1`（只有推送）—— 判「关注」，要人看一眼

为什么统一发**空 payload**：
  ① 安全：空 payload = 参数全缺，绝大多数写接口会在业务校验处被拒，不会真的买东西/发奖；
  ② 一致：不用为 373 个接口各写一份合法参数（写不完，写完也会随版本腐烂）；
  ③ 目标明确：这一档要证的是「接口还在、还能回话、没把服务端搞崩」，不是业务正确性。
  代价：少数接口用全默认值也能成功（例如签到）。**所以只能拿专用测试号跑。**

退出码：
  0  全 pass（含 skip）
  3  只有 warn（关注项，不判失败）
  1  有 fail
  2  前置失败（proto 解析不到 / 取不到 token / 登录不上 / 目标连不上）

输出：
  - 控制台：人读的逐接口行 + 汇总
  - `CHECK|接口名|pass|fail|warn|skip|说明` 行（与 jenkins-shared/lib/checks_to_junit.py 的协议一致，
    每个接口一个 JUnit testcase ⇒ Jenkins 里有趋势）

用法：
  # 只列清单，不连服务器（改完 proto 先看这里）
  python3 scripts/verify/api_full_sweep.py list --scope 全量

  # 生产服全量扫描（专用测试号）
  python3 scripts/verify/api_full_sweep.py preflight --state /tmp/api.json --host 129.226.213.65 --uid 10000004 --ssh gs
  python3 scripts/verify/api_full_sweep.py sweep     --state /tmp/api.json --host 129.226.213.65 --uid 10000004 --ssh gs --scope 全量
  python3 scripts/verify/api_full_sweep.py postcheck --state /tmp/api.json --host 129.226.213.65 --uid 10000004 --ssh gs
  python3 scripts/verify/api_full_sweep.py report    --state /tmp/api.json --html /tmp/api.html
"""
from __future__ import annotations

import argparse
import json
import os
import re
import socket
import struct
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gm_uid_login_probe import (  # noqa: E402  同目录复用，勿另起一份
    GM_REQUEST,
    LOGIN_REQUEST,
    LOGIN_RESPONSE,
    decrypt,
    pb_string_field,
    redis_get,
)

HEART_BEAT_REQUEST = 1000
GM_RESPONSE = 10607

PASS, WARN, FAIL, SKIP = "pass", "warn", "fail", "skip"
ICON = {PASS: "✅", WARN: "⚠️ ", FAIL: "❌", SKIP: "⏭️ "}

# 单独处理、不进批量扫描的协议号：它们要么是扫描的前置条件，要么会改变会话本身。
SPECIAL_IDS = {
    HEART_BEAT_REQUEST: "心跳（由存活探测覆盖）",
    LOGIN_REQUEST: "登录（由 preflight 覆盖）",
    GM_REQUEST: "GM 命令（会改数据，且生产 debug=false 本来就关）",
}

# 「核心」档：登录后客户端立刻要的那批接口。出问题就是「进不去游戏 / 主界面空」，
# 所以这一档要快、要能随时点。**全部只读**，可以随时对着生产跑。
# 名字必须与 MessageTypeProto.proto 里的枚举**逐字一致**（少一个会在 list 里显式提示，
# 见 build_plan 的 missing 返回——协议改名时这里会立刻暴露，而不是静默少测几个）。
CORE_NAMES = [
    "GET_PLAYERINFO_REQUEST",          # 10600 登录后第一发：整份玩家数据
    "GET_HEROINFO_REQUEST",            # 10602 英雄列表
    "GET_ITEMINFO_REQUEST",            # 10604 背包
    "GET_ALL_MAIL_INFO_REQUEST",       # 10608 邮件
    "GET_SOME_ACTIVITY_INFO_REQUEST",  # 16664 活动
    "GET_ONE_RANK_REQUEST",            # 16662 排行榜统一协议
    "ARENA_INFO_REQUEST",              # 10006 竞技场
    "ARENA_RANK_REQUEST",              # 10008 竞技场排行
    "BLOOD_RANK_REQUEST",              # 10115 血战排行
    "GET_QUESTION_REQUEST",            # 1666 问卷
    "GET_LUCKWHEEL_REQUEST",           # 1670 转盘
]

# 「只读」档：名字看起来不会写库的。**保守判定**——宁可漏掉几个只读接口，
# 也不要把写接口放进「可以随时跑」的那一档。
READ_RE = re.compile(
    r"(^GET_|^QUERY_|^FIND_|^CHECK_|^VIEW_|_INFO_REQUEST$|_LIST_REQUEST$|_RANK_REQUEST$|_RANKING_REQUEST$)"
)
WRITE_HINT_RE = re.compile(
    r"(REWARD|DRAW|TAKE|BUY|RAND|LOTTER|CHARGE|RECEIVE|CLAIM|SIGN|REFRESH|RESET|OPEN|START|END|"
    r"SET|SAVE|DEL|CANCEL|USE|COMPOSE|LEVELUP|UPGRADE|EQUIP|UNLOCK|LOCK|SELECT|CHANGE|REVIVE|RELIVE|"
    r"SUBMIT|SEND|CREATE|JOIN|LEAVE|KICK|FIGHT|CHALLENGE|SWEEP|PASS|EXCHANGE|SELL|COMPLETE|FINISH|"
    r"CONFIRM|APPLY|ENTER|EXIT|MOVE|STORE|RECOVER|CLEAN|FIX|ACTIVATE|ADD|MOD|UPDATE|SPEED|BUILD|"
    r"RENAME|EDIT|COMMENT|LIKE|UPLOAD|PAY|ORDER|ASSIGN|SWITCH|CHOOSE|PUT|PLACE|INVITE|ACCEPT|REFUSE)"
)


# --------------------------------------------------------------------------- #
# 协议清单
# --------------------------------------------------------------------------- #
def parse_message_types(proto_path: str):
    """从 MessageTypeProto.proto 里取全部枚举值。

    为什么读 .proto 而不是读编译产物：.proto 是唯一真源，服务端与客户端都从它生成；
    jar 里的枚举是它的产物，读 jar 还要先解 jar，且拿不到「声明了但没实现」这个信息。
    """
    with open(proto_path, encoding="utf-8", errors="replace") as fh:
        txt = fh.read()
    items = re.findall(r"^\s*([A-Z][A-Z0-9_]*)\s*=\s*(\d+)\s*;", txt, re.M)
    if not items:
        raise RuntimeError(f"{proto_path} 里没解析到任何枚举值")
    out, seen = [], {}
    for name, num in items:
        num = int(num)
        if num in seen:
            raise RuntimeError(f"协议号重复：{num} 同时给了 {seen[num]} 和 {name}")
        seen[num] = name
        out.append((name, num))
    return out


def build_plan(all_items, scope: str, only: str, skip: str):
    """按档位挑出这次要扫的接口。返回 [(name, id)]，顺序即协议号顺序。"""
    reqs = [(n, i) for n, i in all_items if n.endswith("_REQUEST")]
    by_name = {n: i for n, i in all_items}

    if scope == "核心":
        plan = [(n, by_name[n]) for n in CORE_NAMES if n in by_name]
    elif scope == "只读":
        plan = [(n, i) for n, i in reqs if READ_RE.search(n) and not WRITE_HINT_RE.search(n)]
    else:  # 全量
        plan = list(reqs)

    if only:
        want = {x.strip().upper() for x in only.split(",") if x.strip()}
        plan = [(n, i) for n, i in plan if n in want or str(i) in want]
    if skip:
        deny = {x.strip().upper() for x in skip.split(",") if x.strip()}
        plan = [(n, i) for n, i in plan if n not in deny and str(i) not in deny]

    # 特殊协议号不进批量：它们由 preflight / postcheck 单独覆盖。
    plan = [(n, i) for n, i in plan if i not in SPECIAL_IDS]
    return sorted(plan, key=lambda x: x[1])


def missing_core(all_items):
    """「核心」档里对不上 proto 的名字。协议改名时这里会喊出来，避免静默少测。"""
    names = {n for n, _ in all_items}
    return [n for n in CORE_NAMES if n not in names]


# --------------------------------------------------------------------------- #
# 连接（自带缓冲，避免半帧读超时把流读歪）
# --------------------------------------------------------------------------- #
class Closed(Exception):
    pass


class Session:
    """一条已登录的游戏服连接。读侧带缓冲：部分帧到齐一半就超时也不会把后面的帧读歪。"""

    def __init__(self, host, port, uid, token, openid, timeout):
        self.host, self.port = host, port
        self.uid, self.token = uid, token
        self.openid = openid
        self.timeout = timeout
        self.sock = None
        self.buf = bytearray()
        self.sn = 0

    def connect(self):
        self.sock = socket.create_connection((self.host, self.port), timeout=self.timeout)
        self.sock.settimeout(self.timeout)
        self.buf.clear()

    def close(self):
        if self.sock is not None:
            try:
                self.sock.close()
            except OSError:
                pass
            self.sock = None

    # ---- 写 ----
    def send(self, msg_id, payload=b""):
        self.sn += 1
        body = struct.pack(">iiii", self.uid, self.token, msg_id, self.sn) + payload
        self.sock.sendall(_encrypt2(body))

    # ---- 读 ----
    def _fill(self, n, deadline):
        while len(self.buf) < n:
            remain = deadline - time.time()
            if remain <= 0:
                raise TimeoutError()
            self.sock.settimeout(min(remain, 1.0))
            try:
                chunk = self.sock.recv(65536)
            except socket.timeout:
                continue
            if not chunk:
                raise Closed()
            self.buf += chunk

    def frame(self, deadline):
        self._fill(2, deadline)
        msg_len = int.from_bytes(self.buf[:2], "big")
        if msg_len == 0:
            del self.buf[:2]
            return None
        enc_len = (msg_len + 7) // 8 * 8
        self._fill(2 + enc_len, deadline)
        body = bytes(self.buf[2:2 + enc_len])
        del self.buf[:2 + enc_len]
        plain = decrypt(body, msg_len)
        if len(plain) < 16:
            return None
        uid, token, msg_id, sn = struct.unpack(">iiii", plain[:16])
        return (uid, token, msg_id, sn, plain[16:])

    def collect(self, expect_id, timeout, cap=40):
        """收帧直到「等到 expect_id」或超时。返回收到的帧列表（可能为空）。"""
        deadline = time.time() + timeout
        frames = []
        while len(frames) < cap and time.time() < deadline:
            try:
                f = self.frame(deadline)
            except TimeoutError:
                break
            if f is None:
                continue
            frames.append(f)
            if f[2] == expect_id:
                break
        return frames

    def login(self):
        """发 LOGIN_REQUEST 并等 LOGIN_RESPONSE。返回 (ok, detail)。"""
        self.connect()
        self.send(LOGIN_REQUEST, pb_string_field(10, self.openid))
        frames = self.collect(LOGIN_RESPONSE, max(self.timeout, 5.0), cap=60)
        if any(f[2] == LOGIN_RESPONSE for f in frames):
            return True, f"登录成功（uid={self.uid}，登录后 {len(frames)} 帧）"
        got = sorted({f[2] for f in frames})
        return False, f"没收到 LOGIN_RESPONSE（收到 msgId={got or '无'}）"


def _encrypt2(data: bytes) -> bytes:
    """TEA 帧加密：2 字节明文长度 + 8 字节对齐密文。

    直接复用 gm_uid_login_probe 的实现（改 KEY/改对齐只改一处），这里只做转发，
    免得本文件与探针各存一份密钥。
    """
    from gm_uid_login_probe import encrypt2
    return encrypt2(data)


# --------------------------------------------------------------------------- #
# 回包解析：只判断「是不是 ErrorResponse」，不做完整 proto 解码
# --------------------------------------------------------------------------- #
def _varint(buf, i):
    shift = val = 0
    while i < len(buf):
        b = buf[i]
        i += 1
        val |= (b & 0x7F) << shift
        if not b & 0x80:
            return val, i
        shift += 7
        if shift > 63:
            raise ValueError("varint 过长")
    raise ValueError("varint 截断")


def parse_error_response(payload: bytes):
    """把 payload 当 CommonProto.ErrorResponse 解析：{errCode:1 varint, errMsg:2 string}。

    返回 errMsg（可能是空串）；**不是** ErrorResponse 时返回 None。
    判据刻意严格（字段号、wire type、整包刚好读完），避免把正常回包的字节误判成错误。
    """
    if not payload:
        return None
    i, err_code, err_msg = 0, None, None
    try:
        while i < len(payload):
            tag, i = _varint(payload, i)
            field, wire = tag >> 3, tag & 7
            if field == 1 and wire == 0:
                err_code, i = _varint(payload, i)
            elif field == 2 and wire == 2:
                ln, i = _varint(payload, i)
                raw = payload[i:i + ln]
                if len(raw) != ln:
                    return None
                err_msg = raw.decode("utf-8", "replace")
                i += ln
            elif field == 3 and wire == 2:
                ln, i = _varint(payload, i)
                i += ln
            else:
                return None
    except ValueError:
        return None
    if err_code is None and err_msg is None:
        return None
    return err_msg or ""


def rejudge(rid, obs, trace):
    """单个接口的判定。返回 (status, kind, detail)。

    🔴 判定必须以**服务端日志**为准，不能只看「有没有收到 请求号+1 的回包」：
       服务端错误回包用的是 `session.getLastMsgId() + 1`，不是请求号 + 1；
       未注册 handler 时 lastMsgId 还停在上一个请求上，于是回包号完全对不上
       （实测 ADVENTURE_INFO_REQUEST=10016 没有 handler，客户端收到的却是 10009）。
       按回包号认领必然错判，所以「这个接口到底进没进 handler」只认日志里那两行。

    判定表：
      no-handler    日志 `request unknow commond : <rid>`   → fail（proto 有、handler 没注册）
      disconnected  连接被服务端断开                         → fail
      silent        无回包且日志无记录                       → pass（handler 存在但空参数下静默早退）
      exec-no-reply 日志有异常、但没回包                     → pass（接口在，只是异常路径不回包）
      ok            有回包                                  → pass

    所以**判红只有一种**：日志铁证「这个协议号没有 handler」。这是刻意的：
    空 payload 下大量接口抛异常/静默早退是正常的，把那些判红，这个 job 三天就没人看了。
    """
    if obs.get("closed"):
        return FAIL, "disconnected", "服务端断开连接（handler 把连接搞崩了）"
    frames = obs.get("frames") or []
    hit = [f for f in frames if f[2] == rid + 1]
    others = sorted({f[2] for f in frames})

    if trace is not None:
        if rid in trace["unk"]:
            return FAIL, "no-handler", "服务端日志：request unknow commond —— proto 有、handler 没注册"
        if rid in trace["exc"]:
            excs = trace["exc"][rid]
            note = f"服务端异常：{excs[0][:70]}" if excs else "服务端异常（未取到异常文本）"
            if hit:
                return PASS, "ok", f"回包 {len(hit[0][4])} 字节 · {note}"
            return PASS, "exec-no-reply", f"已进 handler、异常后未回包 · {note}"
        if hit:
            return PASS, "ok", f"回包 {len(hit[0][4])} 字节"
        if others:
            return PASS, "frame-other", f"收到 msgId={others[:6]}（非 {rid + 1}），日志无该接口记录"
        # 无回包 + 日志无记录：handler 存在但在空参数下静默早退（抽查 BLESS_INFO /
        # FAMILY_GET_INFO / MAIL_READ 都是这种），不是缺陷。真「没 handler」一定有
        # unknow commond 日志，上面已经拦掉了，所以这里判 pass 并把事实写清楚。
        return PASS, "silent", "无回包、日志无该接口记录（空参数下静默早退）"

    # 降级档：拿不到服务端日志（例如本地自测服没配 ssh），只能按回包判。
    # 此时「无回包」一律不判红 —— 宁可漏报，也不要让这个 job 天天误红。
    if hit:
        err = parse_error_response(hit[0][4])
        if err is not None and "unknow commond" in err:
            return FAIL, "no-handler", "服务端回「request unknow commond」：proto 有、handler 没注册"
        if err is not None:
            return PASS, "biz-reject", f"业务拒绝：{err[:60] or '(空错误文案)'}"
        return PASS, "ok", f"回包 {len(hit[0][4])} 字节"
    if others:
        return PASS, "frame-other", f"收到 msgId={others[:6]}（非 {rid + 1}）"
    return WARN, "no-reply", "无回包（未接日志 oracle，不判红）"


# --------------------------------------------------------------------------- #
# SSH 侧取证（只读）
# --------------------------------------------------------------------------- #
def ssh_run(host, cmd, timeout=40):
    out = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=8", host, cmd],
        capture_output=True, text=True, timeout=timeout,
    )
    if out.returncode != 0:
        raise RuntimeError((out.stderr or "").strip().splitlines()[-1:] or f"ssh rc={out.returncode}")
    return (out.stdout or "").strip()


def proc_baseline(ssh_host):
    """服务端进程的 pid + 启动时间。扫描前后一致 ⇒ 期间没有重启/OOM。"""
    cmd = "ps -eo pid,lstart,args | grep -F 'gameSrv' | grep -v grep | head -1"
    line = ssh_run(ssh_host, cmd)
    if not line:
        raise RuntimeError("服务器上没找到 gameSrv 进程")
    parts = line.split(None, 6)
    pid = parts[0]
    started = " ".join(parts[1:6])
    return {"pid": pid, "started": started, "cmd": parts[6] if len(parts) > 6 else ""}


def log_size(ssh_host, log_file):
    try:
        return int(ssh_run(ssh_host, f"stat -c %s {log_file} 2>/dev/null || echo 0") or 0)
    except Exception:
        return 0


def log_error_delta(ssh_host, log_file, offset):
    """扫描期间新增了多少条 handler 异常。只数增量，不看历史。"""
    if not offset:
        return None
    cmd = (f"tail -c +{offset + 1} {log_file} 2>/dev/null "
           f"| grep -c 'processWithProto Exception' || true")
    try:
        return int(ssh_run(ssh_host, cmd) or 0)
    except Exception:
        return None


EXC_RE = re.compile(r"processWithProto Exception protoID=(\d+)")
UNK_RE = re.compile(r"request unknow commond\s*:\s*(\d+)")
EXC_TEXT_RE = re.compile(r"exception=(.{0,160})")


def fetch_trace(ssh_host, log_file, offset):
    """拉扫描期间的日志增量，得出「哪个接口真进了 handler / 哪个接口没有 handler」。

    这是本脚本的判定 oracle，见 rejudge() 的说明。只回传命中的行（不是整段日志），
    因为扫描期间还有真实玩家在产生日志，整段拉回来可能上百 MB。
    """
    if not ssh_host:
        return None
    cmd = (f"tail -c +{offset + 1} {log_file} 2>/dev/null | "
           f"grep -a -E 'processWithProto Exception protoID=|request unknow commond' || true")
    raw = ssh_run(ssh_host, cmd, timeout=120)
    exc, unk = {}, {}
    for line in raw.splitlines():
        m = EXC_RE.search(line)
        if m:
            rid = int(m.group(1))
            bucket = exc.setdefault(rid, [])
            em = EXC_TEXT_RE.search(line)
            if em:
                txt = em.group(1).strip()
                if txt and txt not in bucket:
                    bucket.append(txt)
            continue
        m = UNK_RE.search(line)
        if m:
            rid = int(m.group(1))
            unk[rid] = unk.get(rid, 0) + 1
    return {"exc": exc, "unk": unk, "lines": len(raw.splitlines())}


# --------------------------------------------------------------------------- #
# 已知缺口（baseline）：proto 里声明、但服务端本来就没实现的接口
# --------------------------------------------------------------------------- #
def load_known_gaps(path):
    """读「已知缺口」清单：命中的判 skip 并写明原因，而不是每次跑都判红。

    与 tests/lua-baseline.json 同一套路：**已知的失败走基线，基线外的新失败才红**。
    否则第一次跑全量就会红在几个历史遗留协议上，然后这个 job 就没人看了。
    """
    if not path or not os.path.isfile(path):
        return {}
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception:
        return {}
    out = {}
    for item in (data.get("gaps") or []):
        for key in (str(item.get("id", "")), str(item.get("name", "")).upper()):
            if key:
                out[key] = item.get("reason", "已知缺口")
    return out


# --------------------------------------------------------------------------- #
# 取 token
# --------------------------------------------------------------------------- #
def fetch_token(args):
    if args.token:
        return int(args.token)
    if args.redis:
        rhost, rport = args.redis.split(":")
        tok = redis_get(f"JL_TOKEN:{args.uid}", rhost, int(rport))
        if tok:
            return int(tok)
        raise RuntimeError(f"Redis 没有 JL_TOKEN:{args.uid}（该号没登录过，token 已过期？）")
    if args.ssh:
        cmd = f"redis-cli GET JL_TOKEN:{args.uid} 2>/dev/null"
        tok = ssh_run(args.ssh, cmd)
        if tok and tok.isdigit():
            return int(tok)
        raise RuntimeError(f"服务器 Redis 没有 JL_TOKEN:{args.uid}")
    raise RuntimeError("未给 --token / --redis / --ssh，取不到会话 token")


def load_state(path):
    if os.path.isfile(path):
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    return {}


def save_state(path, state):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(state, fh, ensure_ascii=False, indent=2)


def emit_check(name, status, detail):
    print(f"{ICON.get(status, '?')} {name:<44} {status:<5} {detail}")
    print(f"CHECK|{name}|{status}|{detail}")


# --------------------------------------------------------------------------- #
# 子命令：list
# --------------------------------------------------------------------------- #
def cmd_list(args):
    items = parse_message_types(args.proto)
    plan = build_plan(items, args.scope, args.only, args.skip)
    print(f"proto：{args.proto}")
    print(f"枚举共 {len(items)} 项，其中 *_REQUEST {sum(1 for n, _ in items if n.endswith('_REQUEST'))} 个")
    print(f"档位：{args.scope} ⇒ 本次 {len(plan)} 个接口\n")
    miss = missing_core(items)
    if miss:
        print(f"⚠️  「核心」档有 {len(miss)} 个名字在 proto 里找不到（协议改名了？）：{', '.join(miss)}\n")
    for name, rid in plan:
        print(f"{rid:>8}  {name}")
    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8") as fh:
            json.dump({"scope": args.scope, "total": len(plan),
                       "interfaces": [{"id": i, "name": n} for n, i in plan]}, fh,
                      ensure_ascii=False, indent=2)
    return 0


# --------------------------------------------------------------------------- #
# 子命令：preflight
# --------------------------------------------------------------------------- #
def cmd_preflight(args):
    state = {"target": f"{args.host}:{args.port}", "uid": args.uid,
             "scope": args.scope, "started_at": time.strftime("%Y-%m-%d %H:%M:%S")}
    rc = 0

    # ① TCP
    t0 = time.time()
    try:
        with socket.create_connection((args.host, args.port), timeout=args.timeout):
            pass
        emit_check("预检-端口可连", PASS, f"{args.host}:{args.port}（{(time.time() - t0) * 1000:.0f}ms）")
    except Exception as e:
        emit_check("预检-端口可连", FAIL, f"{args.host}:{args.port} 连不上：{type(e).__name__}: {e}")
        save_state(args.state, state)
        return 2

    # ② token
    try:
        token = fetch_token(args)
        emit_check("预检-会话token", PASS, f"JL_TOKEN:{args.uid} 取到（{len(str(token))} 位）")
    except Exception as e:
        emit_check("预检-会话token", FAIL, f"{e}")
        save_state(args.state, state)
        return 2

    # ③ 登录
    s = Session(args.host, args.port, args.uid, token, args.openid, args.timeout)
    try:
        ok, detail = s.login()
        emit_check("预检-登录建会话", PASS if ok else FAIL, detail)
        if not ok:
            rc = 2
    except Exception as e:
        emit_check("预检-登录建会话", FAIL, f"{type(e).__name__}: {e}")
        rc = 2
    finally:
        s.close()

    # ④ 进程与日志基线（给了 --ssh 才做）
    if args.ssh:
        try:
            pb = proc_baseline(args.ssh)
            state["proc"] = pb
            state["log_file"] = args.log_file
            state["log_offset"] = log_size(args.ssh, args.log_file)
            emit_check("预检-服务端进程", PASS, f"pid={pb['pid']} 启动于 {pb['started']}")
        except Exception as e:
            emit_check("预检-服务端进程", WARN, f"取不到进程基线：{e}（后面无法判断是否重启）")
    else:
        emit_check("预检-服务端进程", SKIP, "未给 --ssh，跳过进程/日志基线")

    # ⑤ 清单
    items = parse_message_types(args.proto)
    plan = build_plan(items, args.scope, args.only, args.skip)
    state["plan_total"] = len(plan)
    emit_check("预检-接口清单", PASS if plan else FAIL,
               f"档位 {args.scope} ⇒ {len(plan)} 个接口（proto 共 {len(items)} 项枚举）")
    miss = missing_core(items)
    if miss:
        # 只提示不判红：档位本身还是能跑，但「核心」这一档已经不等于「登录必需」了。
        emit_check("预检-核心档完整性", WARN,
                   f"{len(miss)} 个名字在 proto 里找不到：{', '.join(miss[:6])}")
    if not plan:
        rc = 2

    save_state(args.state, state)
    return rc


# --------------------------------------------------------------------------- #
# 子命令：sweep
# --------------------------------------------------------------------------- #
def cmd_sweep(args):
    state = load_state(args.state)
    if not state:
        print("没有 state 文件，先跑 preflight", file=sys.stderr)
        return 2
    token = fetch_token(args)
    items = parse_message_types(args.proto)
    plan = build_plan(items, args.scope, args.only, args.skip)
    if args.limit:
        plan = plan[:args.limit]
    gaps = load_known_gaps(args.known_gaps)

    print(f"目标 {args.host}:{args.port} · uid={args.uid} · 档位 {args.scope} · "
          f"{len(plan)} 个接口 · 单接口超时 {args.timeout:g}s")
    print("口径：每个接口发**空 payload**（参数全缺），只验证「接口在、进得了 handler、不崩服务端」")
    if args.ssh:
        print(f"判定 oracle：服务端日志 {args.log_file}（只看本轮增量）")
    else:
        print("⚠️  没给 --ssh：判定降级为「只看回包」，无回包不判红（区分不了静默丢弃与异常不回包）")
    print()

    s = Session(args.host, args.port, args.uid, token, args.openid, args.timeout)
    ok, detail = s.login()
    if not ok:
        emit_check("扫描-登录", FAIL, detail)
        return 2
    emit_check("扫描-登录", PASS, detail)

    # 日志基线在**扫描开始时**取，而不是沿用 preflight 的：中间还隔着别的阶段，
    # 沿用旧 offset 会把别的环节产生的日志算进本轮。
    log_offset = log_size(args.ssh, args.log_file) if args.ssh else 0

    obs = []           # 逐接口的原始观测
    t_start = time.time()
    aborted = None

    for idx, (name, rid) in enumerate(plan, 1):
        if time.time() - t_start > args.budget:
            aborted = f"总预算 {args.budget:g}s 用完，剩 {len(plan) - idx + 1} 个接口未扫"
            break
        # 每 N 个探一次端口：服务端整体挂了要立刻停，而不是把后面 300 个都记成静默
        if idx > 1 and (idx - 1) % args.probe_every == 0:
            try:
                with socket.create_connection((args.host, args.port), timeout=3):
                    pass
            except Exception as e:
                aborted = f"第 {idx} 个接口前端口已不可连（{e}）——服务端疑似挂了"
                break

        t0 = time.time()
        rec = {"id": rid, "name": name, "frames": [], "closed": False, "err": None}
        try:
            s.send(rid)
            rec["frames"] = s.collect(rid + 1, args.timeout)
        except Closed:
            rec["closed"] = True
            # 断连后必须重建会话，否则后面每个接口都会连带判红
            s.close()
            try:
                ok2, d2 = s.login()
                if not ok2:
                    aborted = f"断连后重登失败：{d2}"
            except Exception as e:
                aborted = f"断连后重登异常：{type(e).__name__}: {e}"
        except Exception as e:
            rec["err"] = f"{type(e).__name__}: {e}"
        rec["ms"] = int((time.time() - t0) * 1000)
        obs.append(rec)
        print(f"   … [{idx:>3}/{len(plan)}] {rid:>7} {name}（{rec['ms']}ms）")
        if aborted:
            break
        if args.gap:
            time.sleep(args.gap)

    s.close()

    # 拉日志增量 → 用日志重判（见 rejudge 的说明）
    trace = None
    if args.ssh:
        try:
            trace = fetch_trace(args.ssh, args.log_file, log_offset)
            print(f"\n服务端日志增量：{trace['lines']} 行可判定记录"
                  f"（{len(trace['exc'])} 个接口有异常、{len(trace['unk'])} 个接口无 handler）")
        except Exception as e:
            print(f"\n⚠️  拉服务端日志失败：{e} —— 判定降级为只看回包", file=sys.stderr)

    rows = []
    counts = {PASS: 0, WARN: 0, FAIL: 0, SKIP: 0}
    for rec in obs:
        status, kind, detail = rejudge(rec["id"], rec, trace)
        gap = gaps.get(str(rec["id"])) or gaps.get(rec["name"])
        if gap and status == FAIL:
            # 已知缺口：不判红，但要留在表里（否则下次就忘了它还在）
            status, kind, detail = SKIP, "known-gap", f"{detail} · 已知缺口：{gap}"
        rows.append({"id": rec["id"], "name": rec["name"], "status": status, "kind": kind,
                     "detail": detail, "ms": rec["ms"]})
        counts[status] += 1

    print()
    for r in rows:
        print(f"{ICON.get(r['status'], '?')} {r['id']:>7} {r['name']:<44} {r['kind']:<14} "
              f"{r['ms']:>5}ms  {r['detail']}")

    # 汇总行：控制台 + JUnit 各一条，方便一眼看总量
    done = len(rows)
    summary = (f"{done}/{len(plan)} 个接口已扫 · 通过 {counts[PASS]} · 关注 {counts[WARN]} · "
               f"失败 {counts[FAIL]} · 跳过 {counts[SKIP]}")
    print()
    emit_check("扫描-汇总", FAIL if counts[FAIL] else (WARN if counts[WARN] else PASS), summary)
    if aborted:
        emit_check("扫描-中断", FAIL, aborted)

    # 逐接口 CHECK 行（JUnit 用；控制台上面已经逐条打过，这里只补机器可读格式）
    for r in rows:
        print(f"CHECK|接口 {r['name']}({r['id']})|{r['status']}|[{r['kind']}] {r['detail']}")

    state["sweep"] = {
        "scope": args.scope, "total": len(plan), "done": done,
        "counts": counts, "aborted": aborted, "rows": rows,
        "seconds": round(time.time() - t_start, 1),
        "finished_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "oracle": "log" if trace is not None else "reply-only",
        "log_offset": log_offset,
        "trace_lines": (trace or {}).get("lines", 0),
    }
    state["log_file"] = args.log_file
    save_state(args.state, state)

    if counts[FAIL] or aborted:
        return 1
    if counts[WARN]:
        return 3
    return 0


# --------------------------------------------------------------------------- #
# 子命令：postcheck
# --------------------------------------------------------------------------- #
def cmd_postcheck(args):
    state = load_state(args.state)
    if not state:
        print("没有 state 文件，先跑 preflight", file=sys.stderr)
        return 2
    rc = 0

    # ① 新连接 + 重登：证明扫描期间服务端没被搞挂（旧连接可能只是因为超时被回收）
    token = fetch_token(args)
    s = Session(args.host, args.port, args.uid, token, "api_sweep_post", args.timeout)
    try:
        ok, detail = s.login()
        emit_check("复核-新连接可登录", PASS if ok else FAIL, detail)
        if not ok:
            rc = 1
        else:
            # ② 心跳：登录后再发一次心跳，确认下行写路径还活着
            s.send(HEART_BEAT_REQUEST)
            frames = s.collect(HEART_BEAT_REQUEST + 1, max(args.timeout, 3.0), cap=10)
            emit_check("复核-心跳回写", PASS if frames else WARN,
                       f"心跳后收到 {len(frames)} 帧" if frames else "心跳无回写（服务端可能在下行卡住）")
            if not frames and rc == 0:
                rc = 3
    except Exception as e:
        emit_check("复核-新连接可登录", FAIL, f"{type(e).__name__}: {e}")
        rc = 1
    finally:
        s.close()

    # ③ 进程未重启
    if args.ssh and state.get("proc"):
        try:
            now = proc_baseline(args.ssh)
            same = (now["pid"] == state["proc"]["pid"]
                    and now["started"] == state["proc"]["started"])
            emit_check("复核-进程未重启", PASS if same else FAIL,
                       f"pid={now['pid']} 启动于 {now['started']}"
                       + ("" if same else f"（扫描前 pid={state['proc']['pid']} / "
                                          f"{state['proc']['started']}）——期间重启过"))
            if not same:
                rc = 1
            state["postcheck_proc"] = now
        except Exception as e:
            emit_check("复核-进程未重启", WARN, f"取不到进程状态：{e}")

        # ④ 扫描期间的 handler 异常增量（用 sweep 自己记的 offset，preflight 的中间隔了别的环节）
        off = (state.get("sweep") or {}).get("log_offset") or state.get("log_offset", 0)
        delta = log_error_delta(args.ssh, state.get("log_file", ""), off)
        if delta is None:
            emit_check("复核-handler异常增量", SKIP, "没有日志基线，跳过")
        else:
            # 空 payload 必然触发一堆业务异常，这**不是**失败判据，只是给人看规模。
            emit_check("复核-handler异常增量", PASS, f"扫描期间新增 {delta} 条 handler 异常日志（空 payload 属预期）")
            state["postcheck_error_delta"] = delta
    else:
        emit_check("复核-进程未重启", SKIP, "未给 --ssh 或没有基线")

    save_state(args.state, state)
    return rc


# --------------------------------------------------------------------------- #
# 子命令：report
# --------------------------------------------------------------------------- #
HTML_HEAD = """<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>服务端全量接口扫描</title>
<style>
:root{--bg:#f7f8fa;--card:#fff;--ink:#1f2329;--muted:#6b7280;--line:#e5e7eb;
--pass:#0f9d58;--warn:#b45309;--fail:#d93025;--accent:#2563eb}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
font:14px/1.6 -apple-system,BlinkMacSystemFont,"PingFang SC","Microsoft YaHei",sans-serif}
.wrap{max-width:1180px;margin:0 auto;padding:28px 20px 60px}
h1{font-size:22px;margin:0 0 4px}
.sub{color:var(--muted);font-size:13px;margin-bottom:20px}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px;margin-bottom:22px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px}
.card .k{color:var(--muted);font-size:12px}
.card .v{font-size:24px;font-weight:600;margin-top:2px}
.v.pass{color:var(--pass)}.v.warn{color:var(--warn)}.v.fail{color:var(--fail)}
table{width:100%;border-collapse:collapse;background:var(--card);
border:1px solid var(--line);border-radius:10px;overflow:hidden}
th,td{text-align:left;padding:8px 12px;border-bottom:1px solid var(--line);
vertical-align:top;font-size:13px}
th{background:#f1f3f5;font-weight:600;color:#374151;position:sticky;top:0}
tr:last-child td{border-bottom:none}
code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px}
.tag{display:inline-block;padding:1px 7px;border-radius:999px;font-size:11px;font-weight:600}
.tag.pass{background:#e6f4ea;color:var(--pass)}
.tag.warn{background:#fef3c7;color:var(--warn)}
.tag.fail{background:#fce8e6;color:var(--fail)}
.tag.skip{background:#eef0f3;color:var(--muted)}
h2{font-size:16px;margin:26px 0 10px}
.dim{color:var(--muted)}
</style></head><body><div class="wrap">
"""


def cmd_report(args):
    state = load_state(args.state)
    if not state:
        print("没有 state 文件", file=sys.stderr)
        return 2
    sw = state.get("sweep") or {}
    rows = sw.get("rows") or []
    counts = sw.get("counts") or {}
    fails = [r for r in rows if r["status"] == FAIL]
    gaps = [r for r in rows if r["kind"] == "known-gap"]
    silent = [r for r in rows if r["kind"] == "silent"]
    execs = [r for r in rows if r["kind"] == "exec-no-reply"]
    replies = [r for r in rows if r["kind"] in ("ok", "biz-reject", "frame-other")]

    out = [HTML_HEAD]
    out.append("<h1>服务端全量接口扫描</h1>")
    out.append(f'<div class="sub">目标 <code>{state.get("target","?")}</code> · '
               f'测试号 <code>{state.get("uid","?")}</code> · 档位 {sw.get("scope","?")} · '
               f'开始 {state.get("started_at","?")} · 结束 {sw.get("finished_at","?")} · '
               f'耗时 {sw.get("seconds","?")}s · 判定 oracle：'
               f'{"服务端日志" if sw.get("oracle") == "log" else "仅回包（降级）"}</div>')
    out.append('<div class="cards">')
    out.append(f'<div class="card"><div class="k">接口总数</div><div class="v">{sw.get("total","?")}</div></div>')
    out.append(f'<div class="card"><div class="k">有回包</div><div class="v pass">{len(replies)}</div></div>')
    out.append(f'<div class="card"><div class="k">执行未回包</div><div class="v warn">{len(execs)}</div></div>')
    out.append(f'<div class="card"><div class="k">静默早退</div><div class="v">{len(silent)}</div></div>')
    out.append(f'<div class="card"><div class="k">无 handler</div><div class="v fail">{len(fails)}</div></div>')
    out.append(f'<div class="card"><div class="k">已知缺口</div><div class="v">{len(gaps)}</div></div>')
    out.append("</div>")

    if sw.get("aborted"):
        out.append(f'<p class="tag fail">扫描中断：{_esc(sw["aborted"])}</p>')

    def table(items, title, note=""):
        out.append(f"<h2>{title} <span class='dim'>{note}</span></h2>")
        if not items:
            out.append('<p class="dim">无</p>')
            return
        out.append("<table><tr><th style='width:90px'>协议号</th><th style='width:300px'>接口</th>"
                   "<th style='width:110px'>判定</th><th>说明</th></tr>")
        for r in items:
            out.append(f"<tr><td><code>{r['id']}</code></td><td>{r['name']}</td>"
                       f"<td><span class='tag {r['status']}'>{r['kind']}</span></td>"
                       f"<td>{_esc(r['detail'])}</td></tr>")
        out.append("</table>")

    table(fails, "🔴 无 handler（proto 声明了，服务端没实现）",
          f"{len(fails)} 个 · 确认是废弃协议就写进 scripts/verify/api_known_gaps.json")
    table(gaps, "已知缺口（已登记，不判红）", f"{len(gaps)} 个")
    table(execs, "执行了但没回包（接口在，异常路径不回包）", f"{len(execs)} 个 · 不影响判定")
    table(silent, "静默早退（无回包、日志无记录）", f"{len(silent)} 个 · 空参数下的正常表现")

    out.append("<h2>全部接口 <span class='dim'>按协议号排序</span></h2>")
    out.append("<table><tr><th style='width:90px'>协议号</th><th style='width:300px'>接口</th>"
               "<th style='width:100px'>判定</th><th style='width:80px'>耗时</th><th>说明</th></tr>")
    for r in rows:
        out.append(f"<tr><td><code>{r['id']}</code></td><td>{r['name']}</td>"
                   f"<td><span class='tag {r['status']}'>{r['kind']}</span></td>"
                   f"<td>{r.get('ms','')}ms</td><td>{_esc(r['detail'])}</td></tr>")
    out.append("</table>")
    out.append('<p class="dim" style="margin-top:24px">口径：每个接口只发空 payload（参数全缺），'
               '验证「接口在、进得了 handler、不崩服务端」。判红只有一种：服务端日志明确回'
               '<code>request unknow commond</code>（该协议号没有 handler）。'
               'biz-reject / 执行未回包 / 静默早退都是空参数下的正常表现，不算失败。</p>')
    out.append("</div></body></html>")

    os.makedirs(os.path.dirname(os.path.abspath(args.html)), exist_ok=True)
    with open(args.html, "w", encoding="utf-8") as fh:
        fh.write("\n".join(out))
    print(f"看板已写出：{args.html}（{len(rows)} 个接口：有回包 {len(replies)} · "
          f"执行未回包 {len(execs)} · 静默 {len(silent)} · 无 handler {len(fails)} · 已知缺口 {len(gaps)}）")
    return 0


def _esc(s):
    return (str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #
DEFAULT_PROTO = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "TimeSpaceServer", "Server_x1tag1.2.2", "proto", "protos", "MessageTypeProto.proto")

DEFAULT_GAPS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "api_known_gaps.json")
DEFAULT_TARGETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "api_targets.json")


def add_conn_args(ap):
    ap.add_argument("--target", default="", help="目标名（见 scripts/verify/api_targets.json）")
    ap.add_argument("--host", default="129.226.213.65", help="游戏服地址")
    ap.add_argument("--port", type=int, default=16081, help="游戏服端口")
    ap.add_argument("--uid", type=int, default=0,
                    help="用哪个号发请求（🔴 必须是专用测试号）。留空 = 取 api_targets.json 的 uid_hint")
    ap.add_argument("--token", default="", help="直接给会话 token，免 Redis/SSH")
    ap.add_argument("--redis", default="", help="本地直连 Redis（如 127.0.0.1:6379）")
    ap.add_argument("--ssh", default="", help="SSH 别名（如 gs），用于取 token / 进程 / 日志")
    ap.add_argument("--openid", default="api_full_sweep", help="登录请求里的 openId（只写会话记录）")
    ap.add_argument("--timeout", type=float, default=1.5,
                    help="单接口等回包的超时（秒）。正常接口 200ms 内就回；"
                         "不回的接口要等满这个值，所以它直接决定整轮时长")


def apply_target(args):
    """把 --target 展开成 host/port/ssh/redis/log_file/uid。

    地址表只放 scripts/verify/api_targets.json 一处：改服务器不改 job、不改脚本。
    """
    name = getattr(args, "target", "") or ""
    if not name:
        return
    if not os.path.isfile(DEFAULT_TARGETS):
        raise SystemExit(f"找不到目标表 {DEFAULT_TARGETS}")
    with open(DEFAULT_TARGETS, encoding="utf-8") as fh:
        data = json.load(fh)
    t = (data.get("targets") or {}).get(name)
    if not t:
        raise SystemExit(f"api_targets.json 里没有目标「{name}」，可选：{list((data.get('targets') or {}))}")
    for key in ("host", "port", "ssh", "redis", "log_file"):
        if t.get(key) not in (None, ""):
            setattr(args, key, t[key])
    if not getattr(args, "uid", 0) and t.get("uid_hint"):
        args.uid = t["uid_hint"]
    print(f"目标「{name}」⇒ {args.host}:{args.port} · ssh={args.ssh or '（无）'} · "
          f"日志={getattr(args, 'log_file', '') or '（无）'}")


def main():
    ap = argparse.ArgumentParser(description="服务端全量接口扫描")
    sub = ap.add_subparsers(dest="cmd", required=True)

    for name, fn, needs_state in (
        ("list", cmd_list, False),
        ("preflight", cmd_preflight, True),
        ("sweep", cmd_sweep, True),
        ("postcheck", cmd_postcheck, True),
        ("report", cmd_report, True),
    ):
        p = sub.add_parser(name)
        p.add_argument("--proto", default=DEFAULT_PROTO, help="MessageTypeProto.proto 路径")
        p.add_argument("--scope", choices=["全量", "只读", "核心"], default="全量")
        p.add_argument("--only", default="", help="只扫这些接口（名字或协议号，逗号分隔）")
        p.add_argument("--skip", default="", help="跳过这些接口（名字或协议号，逗号分隔）")
        if needs_state:
            p.add_argument("--state", required=True, help="状态文件（preflight 写、其余读）")
        if name in ("list",):
            p.add_argument("--json-out", default="")
        if name in ("preflight", "sweep", "postcheck"):
            add_conn_args(p)
        if name in ("preflight",):
            p.add_argument("--log-file", default="/data/srvlog/gameserver.log",
                           help="服务端 stdout 日志（统计扫描期间的 handler 异常增量）")
        if name in ("sweep",):
            p.add_argument("--gap", type=float, default=0.0, help="每个接口之间的间隔（秒）")
            p.add_argument("--limit", type=int, default=0, help="只扫前 N 个（排查用）")
            p.add_argument("--budget", type=float, default=1200.0, help="整轮总预算（秒），超了就中断")
            p.add_argument("--probe-every", type=int, default=50, help="每 N 个接口探一次端口")
            p.add_argument("--log-file", default="/data/srvlog/gameserver.log",
                           help="服务端 stdout 日志（判定 oracle：谁进了 handler、谁没 handler）")
            p.add_argument("--known-gaps", default=DEFAULT_GAPS,
                           help="已知缺口清单（命中的判 skip 并写原因，不判红）")
        if name == "report":
            p.add_argument("--html", required=True, help="输出 HTML 路径")
        p.set_defaults(func=fn)

    args = ap.parse_args()
    apply_target(args)
    if args.cmd in ("preflight", "sweep", "postcheck") and not getattr(args, "uid", 0):
        print("必须给 --uid（或在 api_targets.json 里配 uid_hint）：这是要拿哪个号去发请求",
              file=sys.stderr)
        return 2
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
