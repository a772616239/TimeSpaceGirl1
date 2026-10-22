#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""出图账号额度台账（quota ledger）——「这个号用完了」要能被下一次运行读到。

要解决的事
----------
ChatGPT 免费额度按账号算，一个号画完了就换下一个。以前只有
`gen_chatgpt_web.py` 里的 `provider_state.json`，而且口径是**只降权不排除**：

  * 只记 `quota_date`（哪一天空过），**不记什么时候恢复** ⇒ 明天 16:54 才恢复的号，
    今天每一次运行都还会再试一遍（实测一轮白烧 9 分钟：3 个号轮流「额度已用尽」）；
  * 台账只影响排序，`--adspower-max-profiles 3` 一卡，排最后的号永远轮不到；
  * 反过来又踩过另一个坑：台账标了 `quota_date=2026-10-21` 的 ktmrjhu 其实还有额度，
    一次过。**说明台账只能是「优先级」，绝不能是「否决权」**。

所以这里的口径是：

| 场景 | 行为 |
|---|---|
| 账号 `blocked_until` 还没到 | 排到最后，**不消耗启动/出图时间** |
| 所有账号都被封锁 | 按最快恢复的那个**赌一把**（记录可能是别的任务写错的/额度提前重置） |
| 账号成功出过图 | 立刻 `mark-ok` 解封并提到最前（钥匙缓存也会记住端口） |
| 站点给了恢复时间 | 解析成绝对时间存 `blocked_until`（中/英/日/「N 小时后」/「明日 HH:MM」都能认） |
| 站点没给 | 存 `now + 6h` 并标 `estimated: true`，别拿 24h 去堵一整天 |

状态机
------
    unknown ──try──> ok
       │             │
       │             └─quota──> exhausted(blocked_until) ──到期──> unknown
       └──rc=1/3──> unusable(cooldown 默认 120 分钟) ──到期──> unknown

「占用」（lease）—— 并发绘制全靠它
----------------------------------
台账只回答「这个号还有没有额度」，回答不了「**现在有没有别人正在用**」。两个任务同时
挑中同一个 AdsPower profile 时，AdsPower 的 `browser/start` 会把**同一个**调试端口交回来，
于是两边连进同一个 ChatGPT 标签页：后发的提示词覆盖前一条、拿回的是对方的图，而且两边
都会撞「额度用尽」并各写一条台账（2026-10-22 实测：同一个号被提示两次额度为空）。

所以每个通道在被使用前都要先 `claim` 一个带 TTL 的租约：

    adspower:ktmrjhu   lease={owner: jenkins-TS-Art-Translate-58, heartbeat, ttl}
    cdp:60273          （已开着的 SunBrowser，按端口登记）
    chrome:Profile 5   （本机 Chrome 登录态副本）

  * 别人持有且没到期 ⇒ 这个通道**不排队**（并行任务各自拿不同的号，谁也不等谁）；
  * 自己持有 ⇒ 续约（同一轮 batch 的第 2 张图接着用同一台浏览器，不重复启动）；
  * 进程/构建结束 ⇒ `release`；异常退出的残留靠 TTL 过期（默认 20 分钟）自动回收；
  * 台账里同一个号既有额度又有空闲租约才叫「可并行」。

用法
----
    PY=scripts/image/provider_ledger.py

    $PY list                                  # 人看的台账（含 AdsPower 实时状态时加 --live）
    $PY list --json                           # 机器可读
    $PY pick --max 2                          # 台账感知的候选顺序（blocked/被占用的排最后）
    $PY switch --max 1                        # 真的开下一个号并打印 CDP_PORT
    $PY mark-ok --kind adspower --id ktmrjhu
    $PY mark-exhausted --kind adspower --id k1hiv2p8 --raw "明日の 16:54"
    $PY mark-unusable --kind adspower --id k12w7kmd --note "rc=1"
    $PY reset --id k1hiv2p8 | --all
    $PY lease-list                            # 现在谁占着哪台浏览器
    $PY lease-claim --id ktmrjhu --owner job-58
    $PY lease-release --owner job-58           # 释放该 owner 的全部租约
    $PY events --tail 20                       # 浏览器开关/额度事件的审计流水
    $PY check                                 # 自检（解析器用例 + 台账一致性 + 租约语义）

退出码：0 正常 / 1 自检失败 / 2 用法错误 / 3 有账号不可用（switch 时全被封）
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import json
import os
import re
import socket
import sys
import time
from pathlib import Path

try:                                                          # macOS/Linux 走 flock
    import fcntl
except ImportError:                                           # pragma: no cover - Windows
    fcntl = None  # type: ignore[assignment]

HERE = Path(__file__).resolve().parent
# 测试用 TSG_LEDGER 指到临时文件，别污染真台账（同 table1 的 TSG_TABLE1 口径）
LEDGER = Path(os.environ.get("TSG_LEDGER")
              or (Path(__file__).resolve().parents[2] / "_output/art_restyle/quota_ledger.json"))
# 审计流水（只追加）：谁在什么时候开/关/用尽了哪台浏览器。jsonl 便于 grep，坏一行不影响别人。
EVENTS = Path(os.environ.get("TSG_LEDGER_EVENTS")
              or (LEDGER.parent / "browser_events.jsonl"))

# 站点没给恢复时间时的兜底：free 额度是「每日」口径，6 小时是个不堵一整天、又不会
# 每次都白试的折中。宁可早点再试一次，也别把一个其实已经恢复的号锁 24 小时。
DEFAULT_BLOCK_HOURS = 6
# rc=1/rc=3（未登录 / 人机验证 / 页面没出图）不是额度问题，短冷却就行
DEFAULT_UNUSABLE_MINUTES = 120

OK, EXHAUSTED, UNUSABLE, UNKNOWN = "ok", "exhausted", "unusable", "unknown"
CN = {OK: "可用", EXHAUSTED: "额度用尽", UNUSABLE: "不可用", UNKNOWN: "未验证"}

# 租约 TTL：一次出图最长 3~8 分钟，留足余量；异常退出的残留最多占这么久。
LEASE_TTL = int(os.environ.get("TSG_LEASE_TTL", "1200"))
# 台账是**多个任务共享**的文件：读-改-写必须串行，否则并发时后写的整体覆盖前写的
# （并行绘制的第一颗钉子就是它：两边各 mark 一次，先写的封锁直接消失）。
LOCK_TIMEOUT = float(os.environ.get("TSG_LEDGER_LOCK_TIMEOUT", "20"))


# ── 时间与解析 ───────────────────────────────────────────────────────────────

def now() -> dt.datetime:
    return dt.datetime.now()


def _iso(t: dt.datetime) -> str:
    return t.strftime("%Y-%m-%dT%H:%M:%S")


def _parse_iso(s: str | None) -> dt.datetime | None:
    if not s:
        return None
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            return dt.datetime.strptime(str(s), fmt)
        except ValueError:
            continue
    return None


_RE_HOURS = re.compile(r"(\d{1,2})\s*(?:時間|小时|個小時|时间|h\b|hours?\b)")
_RE_TOMORROW = re.compile(
    r"(?:明日|明天|tomorrow)[^\d]{0,12}(\d{1,2})\s*[:：]\s*(\d{2})", re.I)
_RE_ABOUT = re.compile(r"(?:約|约|about|around)[^\d]{0,6}(\d{1,2})\s*[:：]\s*(\d{2})", re.I)


def parse_reset(text: str, base: dt.datetime | None = None) -> tuple[dt.datetime | None, str]:
    """从站点原文/提示里解析「什么时候恢复」。

    返回 (时间, 依据)；依据 ∈ {"hours","tomorrow","clock","none"}。
    站点文案各语言混着来（实测中文界面 + 日文界面 + 英文界面都遇过），所以三类都认。
    """
    base = base or now()
    t = (text or "").strip()
    if not t:
        return None, "none"

    m = _RE_HOURS.search(t)
    if m:
        return base + dt.timedelta(hours=int(m.group(1))), "hours"

    m = _RE_TOMORROW.search(t)
    if m:
        hh, mm = int(m.group(1)), int(m.group(2))
        if 0 <= hh < 24 and 0 <= mm < 60:
            return (base + dt.timedelta(days=1)).replace(
                hour=hh, minute=mm, second=0, microsecond=0), "tomorrow"

    # 「約 16:54」这种只有时刻没有日期的：取下一次出现的那个时刻
    m = _RE_ABOUT.search(t)
    if m:
        hh, mm = int(m.group(1)), int(m.group(2))
        if 0 <= hh < 24 and 0 <= mm < 60:
            cand = base.replace(hour=hh, minute=mm, second=0, microsecond=0)
            if cand <= base:
                cand += dt.timedelta(days=1)
            return cand, "clock"

    return None, "none"


# ── 台账读写 ─────────────────────────────────────────────────────────────────

def load(path: Path | None = None) -> dict:
    p = path or LEDGER
    if not p.is_file():
        return {"version": 1, "accounts": {}, "last_switch": None}
    try:
        raw = p.read_text(encoding="utf-8").strip()
        if not raw:
            return {"version": 1, "accounts": {}, "last_switch": None}
        data = json.loads(raw)
    except Exception as e:                                   # noqa: BLE001
        print(f"⚠ 台账读不出来（{e}），按空台账继续：{p}", file=sys.stderr)
        return {"version": 1, "accounts": {}, "last_switch": None}
    data.setdefault("accounts", {})
    return data


def save(data: dict, path: Path | None = None) -> None:
    p = path or LEDGER
    p.parent.mkdir(parents=True, exist_ok=True)
    data["updated"] = now().strftime("%Y-%m-%d %H:%M:%S")
    tmp = p.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(p)


def key_of(kind: str, ident: str) -> str:
    return f"{kind}:{ident}"


# ── 并发底座：文件锁 + owner 身份 ────────────────────────────────────────────
#
# 台账从「一个人看」变成「几个 Jenkins 构建同时改」之后，最贵的坑是丢更新：
#   A 读到 {ktmrjhu: 可用} → B 读到同一份 → A 写「ktmrjhu 额度用尽」→ B 写「ktmrjhu 可用」
#   ⇒ 封锁被抹掉，下一轮又拿空号去撞 9 分钟。所有读-改-写都必须走 locked()。

def _host() -> str:
    return socket.gethostname().split(".")[0]


def owner_default() -> str:
    """本次运行的 owner 标识。

    Jenkins 里由 job 传 `TSG_LEASE_OWNER=$JOB_NAME-$BUILD_NUMBER`：一条构建里每张图都是
    独立进程，用 pid 当 owner 的话第 2 张图就续不上第 1 张的租约了。
    """
    o = (os.environ.get("TSG_LEASE_OWNER") or "").strip()
    return o or f"{_host()}:{os.getpid()}"


def _tagged(owner: str) -> bool:
    """带 tag 的 owner（构建号）没有稳定 pid 可查 ⇒ 只能靠 TTL 判活。"""
    return bool((os.environ.get("TSG_LEASE_OWNER") or "").strip())


def _pid_alive(pid: int) -> bool:
    try:
        os.kill(int(pid), 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except Exception:                                         # noqa: BLE001
        return True


@contextlib.contextmanager
def locked(timeout: float | None = None):
    """跨进程互斥（flock）。拿不到锁就等，超时才抛 —— 出图本身几分钟，20 秒不算长。"""
    timeout = LOCK_TIMEOUT if timeout is None else timeout
    lock_path = Path(str(LEDGER) + ".lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    fh = open(lock_path, "a+")
    t0 = time.time()
    try:
        while True:
            try:
                if fcntl:
                    fcntl.flock(fh.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError:
                if time.time() - t0 > timeout:
                    raise TimeoutError(f"台账锁等待超时（{timeout:.0f}s）：{lock_path}")
                time.sleep(0.05)
        yield
    finally:
        try:
            if fcntl:
                fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
        finally:
            fh.close()


def lease_live(lease: dict | None, base: dt.datetime | None = None) -> bool:
    """租约还有效吗：TTL 内 +（无 tag 的 owner 还要）进程还活着。"""
    if not lease:
        return False
    base = base or now()
    hb = _parse_iso(lease.get("heartbeat") or lease.get("at"))
    ttl = int(lease.get("ttl") or LEASE_TTL)
    if not hb or (base - hb).total_seconds() > ttl:
        return False
    if not lease.get("tagged") and lease.get("host") == _host() and lease.get("pid"):
        return _pid_alive(int(lease["pid"]))
    return True


def _lease_claim_in(d: dict, kind: str, ident: str, owner: str, ttl: int,
                    note: str) -> tuple[bool, dict]:
    e = _entry(d, kind, ident)
    cur = e.get("lease") or {}
    if cur and cur.get("owner") != owner and lease_live(cur):
        return False, {"held_by": cur.get("owner"), "heartbeat": cur.get("heartbeat"),
                       "ttl": cur.get("ttl"), "note": cur.get("note") or ""}
    t = now()
    e["lease"] = {
        "owner": owner,
        "pid": os.getpid(),
        "host": _host(),
        "tagged": _tagged(owner),
        "at": (cur.get("at") if cur.get("owner") == owner else _iso(t)),
        "heartbeat": _iso(t),
        "ttl": int(ttl),
        "note": (note or "")[:120],
    }
    return True, dict(e["lease"])


def lease_claim(kind: str, ident: str, owner: str | None = None, ttl: int | None = None,
                note: str = "", data: dict | None = None, path: Path | None = None
                ) -> tuple[bool, dict]:
    """抢一个通道的独占权。→ (拿到没有, 租约/占用者信息)。

    拿到了说明「从现在到 TTL 到期，这台浏览器只有我在用」—— 并行绘制的正确性就靠这句。
    """
    owner = owner or owner_default()
    ttl = int(ttl or LEASE_TTL)
    if data is not None:
        return _lease_claim_in(data, kind, ident, owner, ttl, note)
    with locked():
        d = load(path)
        ok, info = _lease_claim_in(d, kind, ident, owner, ttl, note)
        if ok:
            save(d, path)
    return ok, info


def lease_release(kind: str | None = None, ident: str | None = None,
                  owner: str | None = None, data: dict | None = None,
                  path: Path | None = None) -> int:
    """释放租约：给 (kind,id) 就释放那一个；只给 owner 就释放它的全部。返回释放个数。"""
    owner = owner or owner_default()

    def _do(d: dict) -> int:
        n = 0
        for k, e in (d.get("accounts") or {}).items():
            ks, _, ki = k.partition(":")
            if kind and ks != kind:
                continue
            if ident and ki != ident:
                continue
            l = e.get("lease") or {}
            if owner and l.get("owner") != owner:
                continue
            if l:
                e.pop("lease", None)
                n += 1
        return n

    if data is not None:
        return _do(data)
    with locked():
        d = load(path)
        n = _do(d)
        if n:
            save(d, path)
    return n


def leases(data: dict | None = None, base: dt.datetime | None = None) -> list[dict]:
    """当前**有效**的占用（过期的既不列也不删 —— 下次 claim 自然覆盖）。"""
    d = data if data is not None else load()
    base = base or now()
    out = []
    for k, e in (d.get("accounts") or {}).items():
        l = e.get("lease") or {}
        if l and lease_live(l, base):
            out.append({"key": k, "kind": e.get("kind") or k.split(":", 1)[0],
                        "id": e.get("id") or k.split(":", 1)[-1], **l})
    out.sort(key=lambda r: str(r.get("heartbeat") or ""), reverse=True)
    return out


def lease_holders(data: dict | None = None, base: dt.datetime | None = None) -> dict[str, str]:
    """{key: owner}，只含有效租约 —— pick/order 用它把「别人正在用」的号摘掉。"""
    return {r["key"]: str(r.get("owner")) for r in leases(data, base)}


def note_event(kind: str, ident: str, action: str, owner: str | None = None,
               detail: str = "", data: dict | None = None, path: Path | None = None) -> None:
    """写一条审计流水：台账里留最近 200 条，另加一行 jsonl（跨轮次可 grep）。"""
    rec = {"at": _iso(now()), "kind": kind, "id": ident, "action": action,
           "owner": owner or owner_default(), "detail": (detail or "")[:300]}
    try:
        EVENTS.parent.mkdir(parents=True, exist_ok=True)
        with open(EVENTS, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except Exception:                                         # noqa: BLE001
        pass
    if data is None:
        return
    ev = data.setdefault("events", [])
    ev.append(rec)
    if len(ev) > 200:
        del ev[:-200]


def get(kind: str, ident: str, data: dict | None = None) -> dict:
    d = data if data is not None else load()
    return (d.get("accounts") or {}).get(key_of(kind, ident)) or {}


def _entry(data: dict, kind: str, ident: str) -> dict:
    return (data.setdefault("accounts", {})).setdefault(
        key_of(kind, ident), {"kind": kind, "id": ident, "state": UNKNOWN})


# ── 状态写入 ─────────────────────────────────────────────────────────────────
#
# 🔴 每个写入函数都走 _write()：进程内直接用传进来的 data；落到磁盘时**先锁再读再改再写**。
#    并行绘制时「各自 load 一份、各自 save」必然丢更新（封锁被另一个任务的旧副本抹掉）。

def _write(kind: str, ident: str, apply_fn, data: dict | None = None,
           path: Path | None = None) -> dict:
    if data is not None:
        e = _entry(data, kind, ident)
        apply_fn(data, e)
        return e
    with locked():
        d = load(path)
        e = _entry(d, kind, ident)
        apply_fn(d, e)
        save(d, path)
    return e


def mark_ok(kind: str, ident: str, note: str = "", data: dict | None = None,
            path: Path | None = None) -> dict:
    def _apply(_d: dict, e: dict) -> None:
        t = now()
        e.update({"state": OK, "blocked_until": None, "blocked_raw": "",
                  "fail_streak": 0, "last_ok_at": _iso(t), "last_try_at": _iso(t),
                  "ok_count": int(e.get("ok_count") or 0) + 1})
        if note:
            e["note"] = note
    return _write(kind, ident, _apply, data, path)


def mark_exhausted(kind: str, ident: str, raw: str = "", message: str = "",
                   reset_at: dt.datetime | None = None, data: dict | None = None,
                   path: Path | None = None) -> dict:
    """额度用尽：记下**什么时候恢复**（这是这套台账存在的唯一理由）。"""
    def _apply(d: dict, e: dict) -> None:
        t = now()
        when, how = (reset_at, "explicit") if reset_at else parse_reset(raw or message, t)
        estimated = False
        if when is None:
            when = t + dt.timedelta(hours=DEFAULT_BLOCK_HOURS)
            how, estimated = "default", True
        e.update({"state": EXHAUSTED, "blocked_until": _iso(when),
                  "blocked_raw": (raw or message)[:200],
                  "reset_basis": how, "reset_estimated": estimated,
                  "fail_streak": int(e.get("fail_streak") or 0) + 1, "last_try_at": _iso(t)})
        if message:
            e["message"] = message[:300]
        # 「额度用尽」是这条链上最贵的信息：顺手写进审计流水（谁、哪个号、到几点恢复）
        note_event(kind, ident, "quota_exhausted",
                   detail=f"until={e['blocked_until']} basis={how} raw={e['blocked_raw'][:80]}",
                   data=d)
    return _write(kind, ident, _apply, data, path)


def mark_unusable(kind: str, ident: str, note: str = "", cooldown_min: int | None = None,
                  data: dict | None = None, path: Path | None = None) -> dict:
    """未登录 / 人机验证 / 页面没出图：不是额度问题，给个短冷却，别整轮反复开它。"""
    def _apply(d: dict, e: dict) -> None:
        t = now()
        mins = DEFAULT_UNUSABLE_MINUTES if cooldown_min is None else max(0, cooldown_min)
        e.update({"state": UNUSABLE, "blocked_until": _iso(t + dt.timedelta(minutes=mins)),
                  "reset_basis": f"cooldown{mins}m", "reset_estimated": True,
                  "fail_streak": int(e.get("fail_streak") or 0) + 1, "last_try_at": _iso(t)})
        if note:
            e["note"] = note[:200]
        note_event(kind, ident, "unusable", detail=note or "", data=d)
    return _write(kind, ident, _apply, data, path)


def clear(kind: str, ident: str, data: dict | None = None, path: Path | None = None) -> dict:
    def _apply(_d: dict, e: dict) -> None:
        e.update({"state": UNKNOWN, "blocked_until": None, "blocked_raw": "", "fail_streak": 0})
        e.pop("note", None)
    return _write(kind, ident, _apply, data, path)


def set_note(kind: str, ident: str, note: str) -> dict:
    """只改备注（ads_missing 之类），不动额度状态。锁内读改写，避免抹掉别处刚写的封锁。"""
    def _apply(_d: dict, e: dict) -> None:
        e["note"] = note[:200]
    return _write(kind, ident, _apply)


def set_last_switch(kind: str, ident: str, port: int | None) -> None:
    with locked():
        d = load()
        d["last_switch"] = {"at": now().strftime("%Y-%m-%d %H:%M:%S"), "kind": kind,
                            "id": ident, "port": port}
        save(d)


# ── 判据 ─────────────────────────────────────────────────────────────────────

def blocked_until(kind: str, ident: str, data: dict | None = None,
                  base: dt.datetime | None = None) -> dt.datetime | None:
    """还在封锁期就返回解封时间，否则 None。"""
    base = base or now()
    e = get(kind, ident, data)
    t = _parse_iso(e.get("blocked_until"))
    return t if t and t > base else None


def is_blocked(kind: str, ident: str, data: dict | None = None,
               base: dt.datetime | None = None) -> bool:
    return blocked_until(kind, ident, data, base) is not None


def human_left(t: dt.datetime | None, base: dt.datetime | None = None) -> str:
    if not t:
        return "-"
    base = base or now()
    sec = int((t - base).total_seconds())
    if sec <= 0:
        return "已到期"
    h, m = sec // 3600, (sec % 3600) // 60
    return f"{h}h{m:02d}m" if h else f"{m}m"


def sort_key(kind: str, ident: str, data: dict | None = None, cookies: int = 0,
             base: dt.datetime | None = None) -> tuple:
    """越小越先试。blocked 排最末（但仍在候选里，等「全都被封」的回退逻辑去捡）。"""
    base = base or now()
    e = get(kind, ident, data)
    blocked = blocked_until(kind, ident, data, base) is not None
    missing = (e.get("note") == "ads_missing")
    unusable = (e.get("state") == UNUSABLE and blocked)
    return (blocked, unusable, missing, -cookies)


def order(rows: list[dict], kind: str, explicit: list[str] | None = None,
          data: dict | None = None, base: dt.datetime | None = None,
          owner: str | None = None) -> list[dict]:
    """把候选按「台账感知」重排：显式指定 > 未封锁且没被别人占 > cookie 多 > 封锁中的。"""
    data = data if data is not None else load()
    base = base or now()
    holders = lease_holders(data, base)
    owner = owner or owner_default()
    by_id = {r["id"]: r for r in rows}
    head: list[dict] = []
    for u in (explicit or []):
        if u in by_id and by_id[u] not in head:
            head.append(by_id[u])

    def taken(r) -> bool:
        who = holders.get(key_of(kind, r["id"]))
        return bool(who) and who != owner

    def k(r):
        t = blocked_until(kind, r["id"], data, base)
        return (taken(r), t is not None, t or dt.datetime.max,
                *sort_key(kind, r["id"], data, r.get("cookies", 0), base)[1:])

    rest = sorted([r for r in rows if r not in head], key=k)
    return head + rest


def pick(rows: list[dict], kind: str, explicit: list[str] | None = None, max_n: int = 3,
         force: bool = False, data: dict | None = None, base: dt.datetime | None = None,
         owner: str | None = None, respect_leases: bool = True) -> list[dict]:
    """返回最多 max_n 个候选（附 `blocked_until` / `leased_by` 字段）。

    🔴 全部被封时**不返回空**：挑最快恢复的那个赌一把（`gamble=True`）。
       台账可能是别的任务写错的（实测 ktmrjhu 标了当天空过却一次过），一票否决会白丢额度。
    🔴 被别人占用的号**不参与赌博**：那台浏览器里有另一个任务正在出图，抢过来只会串图。
       只有「没人占用但可能没额度」才值得赌。
    """
    data = data if data is not None else load()
    base = base or now()
    owner = owner or owner_default()
    holders = lease_holders(data, base)
    rows = order(rows, kind, explicit, data, base, owner=owner)
    marked = []
    for r in rows:
        t = blocked_until(kind, r["id"], data, base)
        who = holders.get(key_of(kind, r["id"]))
        marked.append({**r, "blocked_until": _iso(t) if t else None,
                       "leased_by": who if (who and who != owner) else None})
    if force:
        return [{**r, "blocked_until": None, "forced": True} for r in marked[:max_n]]
    usable = [r for r in marked
              if r["blocked_until"] is None and (not respect_leases or not r["leased_by"])]
    if usable:
        return usable[:max_n]
    gamble = [r for r in marked
              if (not respect_leases or not r["leased_by"]) and r["blocked_until"]][:1]
    return [{**r, "gamble": True} for r in gamble]


# ── 渲染 ─────────────────────────────────────────────────────────────────────

def render(data: dict | None = None, base: dt.datetime | None = None, live: bool = False) -> str:
    data = data if data is not None else load()
    base = base or now()
    rows = []
    live_state: dict[str, tuple[str, int]] = {}
    if live:
        try:
            sys.path.insert(0, str(HERE))
            import find_browser_cdp as fb
            live_state = {r["user_id"]: (r.get("status", "?"), int(r.get("port") or 0))
                          for r in fb.adspower_profiles(with_state=True)}
        except Exception as e:                               # noqa: BLE001
            rows.append(f"(AdsPower 实时状态取不到：{e})")

    accounts = data.get("accounts") or {}
    if not accounts:
        rows.append("台账是空的：还没有任何账号被记录过（第一次出图后自动建档）。")
        return "\n".join(rows)

    def sort_k(item):
        k, e = item
        t = _parse_iso(e.get("blocked_until"))
        return (t is None, t or dt.datetime.max, -int(e.get("ok_count") or 0), k)

    head = f"{'账号':<22}{'类型':<10}{'状态':<10}{'解封':<22}{'剩余':<9}{'成功':<5}{'连败':<5}{'占用':<22}备注"
    rows += [head, "-" * min(120, len(head) + 20)]
    holders = lease_holders(data, base)
    for k, e in sorted(accounts.items(), key=sort_k):
        t = _parse_iso(e.get("blocked_until"))
        t = t if t and t > base else None
        ident = e.get("id") or k.split(":", 1)[-1]
        if (e.get("kind") == "asset"):        # 资源路径太长，表格里只显示文件名
            ident = Path(str(ident)).name
        state = CN.get(e.get("state") or UNKNOWN, e.get("state") or UNKNOWN)
        if e.get("state") == EXHAUSTED and not t:
            state = "已到期(待验)"
        when = t.strftime("%m-%d %H:%M") if t else "-"
        if e.get("reset_estimated") and t:
            when += "?"
        note = (e.get("note") or "")[:40]
        if e.get("kind") == "adspower" and ident in live_state:
            st, port = live_state[ident]
            note = f"{note} 浏览器:{st}{('/' + str(port)) if port else ''}".strip()
        who = holders.get(k) or "-"
        rows.append(f"{ident:<22}{e.get('kind',''):<10}{state:<10}{when:<22}"
                    f"{human_left(t, base):<9}{int(e.get('ok_count') or 0):<5}"
                    f"{int(e.get('fail_streak') or 0):<5}{who:<22}{note}")
    # 只统计能画图的通道（adspower/chrome/cdp）；asset: 是「这张图归哪一轮」的占位，不算通道。
    chan = {k: e for k, e in accounts.items()
            if (e.get("kind") or k.split(":", 1)[0]) in ("adspower", "chrome", "cdp")}
    held = sum(1 for k in chan if holders.get(k))
    free = sum(1 for k, e in chan.items()
               if not holders.get(k) and not blocked_until(
                   e.get("kind") or k.split(":", 1)[0],
                   e.get("id") or k.split(":", 1)[-1], data, base))
    rows += ["", f"可并行绘制：{free} 路（{held} 个通道正被占用；一个通道同一时刻只允许一路）"]
    last = data.get("last_switch")
    if last:
        rows += [f"上次切换：{last.get('at')} → {last.get('kind')}:{last.get('id')}"
                 f"（CDP {last.get('port') or '-'}）"]
    return "\n".join(rows)


# ── 自检（Jenkins 判红绿用）─────────────────────────────────────────────────

def selfcheck(data: dict | None = None) -> tuple[bool, list[str]]:
    msgs: list[str] = []
    ok = True
    base = dt.datetime(2026, 10, 21, 18, 0, 0)
    cases = [
        ("上限将在 21 小时后重置", "hours", 21 * 60),
        ("上限は 22 時間後にリセットされます", "hours", 22 * 60),
        ("明日の 16:54 に無料枠が回復します", "tomorrow", 22 * 60 + 54),
        ("明天 08:30 恢复", "tomorrow", 14 * 60 + 30),
        ("reset at 3 hours", "hours", 3 * 60),
    ]
    for text, want_basis, want_min in cases:
        when, basis = parse_reset(text, base)
        got = int((when - base).total_seconds() // 60) if when else -1
        if basis != want_basis or got != want_min:
            ok = False
            msgs.append(f"✗ 解析失败：{text!r} → {basis}/{got}min，期望 {want_basis}/{want_min}min")
        else:
            msgs.append(f"✓ {text!r} → {basis} +{got}min")
    if parse_reset("", base)[0] is not None:
        ok = False
        msgs.append("✗ 空文本不该解析出时间")

    d = data if data is not None else load()
    for k, e in (d.get("accounts") or {}).items():
        st = e.get("state")
        if st not in (OK, EXHAUSTED, UNUSABLE, UNKNOWN):
            ok = False
            msgs.append(f"✗ {k} 状态非法：{st}")
        if st in (EXHAUSTED, UNUSABLE) and not e.get("blocked_until"):
            ok = False
            msgs.append(f"✗ {k} 是 {st} 但没有 blocked_until（下次会被当成可用）")
        if e.get("blocked_until") and st == OK:
            ok = False
            msgs.append(f"✗ {k} 状态 ok 却还挂着封锁时间")
    msgs.append(f"台账账号 {len(d.get('accounts') or {})} 个")

    # 排序/挑选的纯函数用例（不落盘）：这是「跳过硬封锁、全封才赌一把」的核心判据
    b = dt.datetime(2026, 10, 21, 18, 0, 0)
    fake = {"accounts": {
        key_of("adspower", "a_ok"): {"kind": "adspower", "id": "a_ok", "state": OK},
        key_of("adspower", "b_exp"): {"kind": "adspower", "id": "b_exp", "state": EXHAUSTED,
                                      "blocked_until": _iso(b + dt.timedelta(hours=5))},
        key_of("adspower", "c_old"): {"kind": "adspower", "id": "c_old", "state": EXHAUSTED,
                                      "blocked_until": _iso(b - dt.timedelta(hours=1))},
    }}
    rows = [{"id": "b_exp", "cookies": 90}, {"id": "a_ok", "cookies": 10},
            {"id": "c_old", "cookies": 5}]
    got = [r["id"] for r in pick(rows, "adspower", max_n=2, data=fake, base=b)]
    if got != ["a_ok", "c_old"]:
        ok = False
        msgs.append(f"✗ pick 排除封锁失败：{got}，期望 ['a_ok','c_old']（封锁的 b_exp 不该进前两位）")
    else:
        msgs.append("✓ pick 跳过未到期封锁的号，到期的那只自动放回")

    allblocked = {"accounts": {
        key_of("adspower", "x"): {"state": EXHAUSTED, "blocked_until": _iso(b + dt.timedelta(hours=9))},
        key_of("adspower", "y"): {"state": EXHAUSTED, "blocked_until": _iso(b + dt.timedelta(hours=2))}}}
    g = pick([{"id": "x", "cookies": 50}, {"id": "y", "cookies": 40}], "adspower",
             max_n=2, data=allblocked, base=b)
    if not (len(g) == 1 and g[0]["id"] == "y" and g[0].get("gamble")):
        ok = False
        msgs.append(f"✗ 全封锁时该按最快恢复的赌一把，实际 {[r['id'] for r in g]}")
    else:
        msgs.append("✓ 全封锁时只挑最快恢复的一个赌一把（台账可能是错的）")

    f = pick(rows, "adspower", max_n=2, force=True, data=fake, base=b)
    if len(f) != 2 or any(r["blocked_until"] for r in f):
        ok = False
        msgs.append("✗ --force 应无视封锁且清掉 blocked_until")
    else:
        msgs.append("✓ --force 无视封锁")

    if is_blocked("adspower", "c_old", fake, b):
        ok = False
        msgs.append("✗ 已过期的封锁仍被判为 blocked")

    # ── 租约语义（并行绘制的唯一防线）───────────────────────────────────────
    # ① 别人占着 ⇒ 不进候选；② 自己占着 ⇒ 可以续；③ 过期 ⇒ 自动放回。
    b2 = dt.datetime(2026, 10, 21, 18, 0, 0)
    d2: dict = {"accounts": {}}
    got_a, info_a = lease_claim("adspower", "L1", owner="jobA", data=d2)
    got_b, info_b = lease_claim("adspower", "L1", owner="jobB", data=d2)
    if not (got_a and not got_b and info_b.get("held_by") == "jobA"):
        ok = False
        msgs.append(f"✗ 租约没挡住第二个占用者：A={got_a} B={got_b} {info_b}")
    else:
        msgs.append("✓ 同一通道第二个任务拿不到租约（并行时不会挤进同一台浏览器）")
    got_a2, _ = lease_claim("adspower", "L1", owner="jobA", data=d2)
    if not got_a2:
        ok = False
        msgs.append("✗ 持有者自己续约失败")
    rows2 = [{"id": "L1", "cookies": 99}, {"id": "L2", "cookies": 1}]
    lease_claim("adspower", "L1", owner="jobA", data=d2)
    got = pick(rows2, "adspower", max_n=3, data=d2, base=b2, owner="jobB")
    if [r["id"] for r in got] != ["L2"]:
        ok = False
        msgs.append(f"✗ 被占用的通道仍被派给别的任务：{[r['id'] for r in got]}")
    else:
        msgs.append("✓ 别的任务拿不到被占用的通道，直接派下一个号")
    # 过期租约（heartbeat 早于 ttl）要能自动放回
    d2["accounts"][key_of("adspower", "L1")]["lease"]["heartbeat"] = _iso(
        b2 - dt.timedelta(hours=2))
    if lease_live(d2["accounts"][key_of("adspower", "L1")]["lease"], b2):
        ok = False
        msgs.append("✗ 过期租约仍判为有效（异常退出的残留会永久占号）")
    else:
        msgs.append("✓ 过期租约自动失效（进程被 kill 最多占满 TTL）")
    if lease_release(owner="jobA", data=d2) != 1:
        ok = False
        msgs.append("✗ lease_release 没按 owner 释放")
    else:
        msgs.append("✓ 按 owner 一次性释放全部租约")
    return ok, msgs


# ── CLI ──────────────────────────────────────────────────────────────────────

def _rows_from(*, live: bool, profiles: str) -> list[dict]:
    sys.path.insert(0, str(HERE))
    import find_browser_cdp as fb
    explicit = [x.strip() for x in (profiles or "").split(",") if x.strip()]
    rows = fb.adspower_profiles(with_state=live)
    out = [{"id": r["user_id"], "cookies": int(r.get("cookies") or 0),
            "status": r.get("status"), "port": r.get("port")} for r in rows]
    if explicit:
        known = {r["id"] for r in out}
        out = out + [{"id": u, "cookies": 0, "status": "?", "port": 0}
                     for u in explicit if u not in known]
    return out


def cmd_switch(args) -> int:
    sys.path.insert(0, str(HERE))
    import find_browser_cdp as fb
    data = load()
    rows = _rows_from(live=True, profiles=args.profiles)
    cands = pick(rows, "adspower", explicit=[x.strip() for x in (args.profiles or "").split(",") if x.strip()],
                 max_n=args.max, force=args.force, data=data)
    if not cands:
        print("🔴 没有可换的账号（AdsPower 缓存目录里没有启动过的 profile）")
        return 3
    if not fb.adspower_alive():
        print("🔴 AdsPower 本地 API 不可达（客户端没开 / 端口不是 50325）")
        return 3
    print(f"候选（台账感知）：{', '.join(c['id'] for c in cands)}")
    for c in cands:
        uid = c["id"]
        if c.get("gamble"):
            print(f"⚠ 所有账号都在封锁期，按最快恢复的 {uid} 赌一把（台账可能过期）")
        if c.get("blocked_until"):
            print(f"   {uid} 台账封锁到 {c['blocked_until']}，强制尝试")
        st, port = fb.adspower_state(uid)
        if st == "missing":
            set_note("adspower", uid, "ads_missing")
            print(f"   {uid}：AdsPower 不认这个 id（缓存残留），跳过")
            continue
        launched = False
        if st == "active" and port:
            print(f"   {uid}：已经开着（CDP {port}）")
        else:
            print(f"   {uid}：启动 …")
            ok, port, msg = fb.adspower_start(uid)
            if not ok:
                print(f"   {uid} 启动失败：{msg}")
                if "does not exist" in msg:
                    set_note("adspower", uid, "ads_missing")
                continue
            launched = True
        set_last_switch("adspower", uid, port)
        print()
        print(f"✅ 已切到 adspower:{uid}  CDP 端口 {port}")
        print(f"   CDP_PORT={port}    # 丢给下游任务（TS-Art-Restyle 的同名参数）")
        print(f"   验活：python3 scripts/image/gen_chatgpt_web.py --image X --prompt-file Y "
              f"--out /tmp/probe.png --reuse-cdp --port {port} --check-only")
        if args.stop_when_done and launched:
            fb.adspower_stop(uid)
            print(f"   --stop-when-done：已关闭 {uid}")
        return 0
    return 3


def cmd_use_chrome(args) -> int:
    """切到「本机 Google Chrome 登录态」这条通道（另一条是 AdsPower 指纹浏览器）。

    Chrome 这条没什么可「启动」的：gen_chatgpt_web.py 自己复制 profile 起浏览器。
    这里只做两件事——报告它还有没有额度、把台账的封锁按需清掉，然后给出可直接粘的命令。
    """
    ident = args.profile
    t = blocked_until("chrome", ident)
    if t and not args.force:
        print(f"🔴 chrome:{ident} 台账记着额度封锁到 {t:%Y-%m-%d %H:%M}（还有 {human_left(t)}）")
        print("   本机 Chrome 与 AdsPower 号共用同一份「谁还有额度」的判断；这条通道现在不可用。")
        print("   要强制试一次：加 --force（会解封并如实记录下一次结果）")
        return 3
    if t:
        clear("chrome", ident)
        print(f"⚠ 已按 --force 解封 chrome:{ident}（下次结果会覆盖这条记录）")
    e = get("chrome", ident)
    print(f"✅ 用本机 Chrome 通道：chrome:{ident}   状态={CN.get(e.get('state') or UNKNOWN)}"
          f"   上次成功={e.get('last_ok_at') or '-'}")
    print()
    # 行首、无缩进无注释：Jenkins 侧直接 grep '^CHROME_PROFILE=' 取值（profile 名可能带空格）
    print(f"CHROME_PROFILE={ident}")
    print("   丢给下游任务：TS-Art-Restyle 不填 CDP_PORT 时就用本机 Chrome 的这个 profile")
    print("   命令行：")
    print(f"   python3 scripts/image/gen_chatgpt_web.py --image <图> --prompt-file <提示词> "
          f"--out <输出> --profile \"{ident}\"")
    set_last_switch("chrome", ident, None)
    return 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="出图账号额度台账")
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("list", help="打印台账（--live 附带 AdsPower 实时状态）")
    p.add_argument("--json", action="store_true")
    p.add_argument("--live", action="store_true")
    p.set_defaults(func=lambda a: (print(json.dumps(load(), ensure_ascii=False, indent=2))
                                   if a.json else print(render(live=a.live))) or 0)

    p = sub.add_parser("pick", help="台账感知的候选顺序（不启动浏览器）")
    p.add_argument("--profiles", default="", help="显式排序（逗号分隔 user_id）")
    p.add_argument("--max", type=int, default=3)
    p.add_argument("--force", action="store_true", help="忽略封锁时间")
    p.set_defaults(func=lambda a: _cmd_pick(a))

    p = sub.add_parser("switch", help="真的切到下一个可用账号（会启动 AdsPower profile）")
    p.add_argument("--profiles", default="")
    p.add_argument("--max", type=int, default=1)
    p.add_argument("--force", action="store_true")
    p.add_argument("--stop-when-done", action="store_true")
    p.set_defaults(func=cmd_switch)

    p = sub.add_parser("use-chrome", help="切到本机 Google Chrome 通道（另一条是 AdsPower）")
    p.add_argument("--profile", default=os.environ.get("CHROME_PROFILE", "Profile 5"))
    p.add_argument("--force", action="store_true", help="台账说它额度空了也照样解封")
    p.set_defaults(func=cmd_use_chrome)

    for name, help_ in (("mark-ok", "标记可用（出图成功）"),
                        ("mark-exhausted", "标记额度用尽（可从原文解析恢复时间）"),
                        ("mark-unusable", "标记不可用（未登录/验证码，短冷却）")):
        p = sub.add_parser(name, help=help_)
        p.add_argument("--kind", default="adspower", choices=["adspower", "chrome"])
        p.add_argument("--id", required=True, help="AdsPower user_id 或 Chrome profile 名")
        p.add_argument("--raw", default="", help="站点原文（解析恢复时间用）")
        p.add_argument("--message", default="")
        p.add_argument("--note", default="")
        p.add_argument("--reset", default="", help="显式恢复时间 YYYY-MM-DDTHH:MM:SS")
        p.add_argument("--cooldown", type=int, default=None, help="mark-unusable 的冷却分钟")
        p.set_defaults(func=_cmd_mark, mark=name)

    p = sub.add_parser("reset", help="清掉封锁（--id 单个 / --all 全部）")
    p.add_argument("--id", default="")
    p.add_argument("--kind", default="adspower", choices=["adspower", "chrome"])
    p.add_argument("--all", action="store_true")
    p.set_defaults(func=_cmd_reset)

    p = sub.add_parser("check", help="自检：解析器用例 + 台账一致性")
    p.set_defaults(func=lambda a: _cmd_check())

    p = sub.add_parser("lease-list", help="现在谁占着哪台浏览器（并行绘制看这个）")
    p.set_defaults(func=_cmd_lease_list)

    p = sub.add_parser("lease-claim", help="手工抢一个通道的独占权（调试用）")
    p.add_argument("--kind", default="adspower",
                   choices=["adspower", "chrome", "cdp", "asset"])
    p.add_argument("--id", required=True)
    p.add_argument("--owner", default="")
    p.add_argument("--ttl", type=int, default=0)
    p.set_defaults(func=_cmd_lease_claim)

    p = sub.add_parser("lease-release", help="释放租约（--owner 全放 / 指定 --kind --id）")
    p.add_argument("--kind", default="",
                   choices=["", "adspower", "chrome", "cdp", "asset"])
    p.add_argument("--id", default="")
    p.add_argument("--owner", default="")
    p.set_defaults(func=_cmd_lease_release)

    p = sub.add_parser("events", help="浏览器开/关/额度用尽的审计流水")
    p.add_argument("--tail", type=int, default=20)
    p.set_defaults(func=_cmd_events)

    args = ap.parse_args(argv)
    return args.func(args)


def _cmd_lease_list(_a) -> int:
    rows = leases()
    if not rows:
        print("当前没有任何通道被占用（可并行路数 = 台账里没封锁的号数）")
        return 0
    for r in rows:
        print(f"{r['kind']}:{r['id']:<14} owner={r.get('owner')}  心跳={r.get('heartbeat')}"
              f"  TTL={r.get('ttl')}s  备注={r.get('note') or '-'}")
    return 0


def _cmd_lease_claim(a) -> int:
    ok, info = lease_claim(a.kind, a.id, owner=a.owner or None, ttl=a.ttl or None)
    if ok:
        print(f"✅ 拿到 {a.kind}:{a.id}（owner={info.get('owner')}，TTL {info.get('ttl')}s）")
        return 0
    print(f"🔴 {a.kind}:{a.id} 正被 {info.get('held_by')} 占用"
          f"（心跳 {info.get('heartbeat')}，TTL {info.get('ttl')}s）")
    return 3


def _cmd_lease_release(a) -> int:
    n = lease_release(kind=a.kind or None, ident=a.id or None, owner=a.owner or None)
    print(f"已释放 {n} 个租约")
    return 0


def _cmd_events(a) -> int:
    try:
        lines = EVENTS.read_text(encoding="utf-8").splitlines()
    except Exception:                                         # noqa: BLE001
        print(f"还没有审计流水（{EVENTS}）")
        return 0
    for line in lines[-max(1, a.tail):]:
        print(line)
    return 0


def _cmd_pick(a) -> int:
    rows = _rows_from(live=False, profiles=a.profiles)
    explicit = [x.strip() for x in (a.profiles or "").split(",") if x.strip()]
    data = load()
    base = now()
    cands = pick(rows, "adspower", explicit, a.max, a.force, data=data, base=base)
    if not cands:
        print("（没有候选）")
        return 3
    for i, c in enumerate(cands, 1):
        t = _parse_iso(c.get("blocked_until"))
        tag = "🔴 全被封，按最快恢复的赌一把" if c.get("gamble") else "✅ 可用"
        left = f"  解封 {t.strftime('%m-%d %H:%M')}（还有 {human_left(t, base)}）" if t else ""
        print(f"{i}. {c['id']:<12} cookie={c.get('cookies', 0):<4}{tag}{left}")
    blocked = [r for r in order(rows, "adspower", explicit, data, base)
               if r["id"] not in {c["id"] for c in cands}
               and blocked_until("adspower", r["id"], data, base)]
    if blocked:
        tail = "、".join(f"{r['id']}({human_left(blocked_until('adspower', r['id'], data, base), base)})"
                        for r in blocked)
        print(f"   封锁中、这次不会碰：{tail}")
    return 0


def _cmd_mark(a) -> int:
    kind, ident = a.kind, a.id
    if a.mark == "mark-ok":
        e = mark_ok(kind, ident, note=a.note)
    elif a.mark == "mark-exhausted":
        reset = _parse_iso(a.reset) if a.reset else None
        e = mark_exhausted(kind, ident, raw=a.raw, message=a.message, reset_at=reset)
    else:
        e = mark_unusable(kind, ident, note=a.note or a.message, cooldown_min=a.cooldown)
    print(f"{kind}:{ident} → {e.get('state')}  blocked_until={e.get('blocked_until') or '-'}"
          f"  依据={e.get('reset_basis', '-')}{'(估)' if e.get('reset_estimated') else ''}")
    return 0


def _cmd_reset(a) -> int:
    if a.all:
        with locked():
            d = load()
            n = 0
            for _k, e in (d.get("accounts") or {}).items():
                e.update({"state": UNKNOWN, "blocked_until": None, "blocked_raw": "",
                          "fail_streak": 0})
                e.pop("note", None)
                n += 1
            save(d)
        print(f"已清空封锁：{n} 个账号")
        return 0
    if not a.id:
        print("要么 --id <账号>，要么 --all")
        return 2
    e = clear(a.kind, a.id)
    print(f"{a.kind}:{a.id} → {e.get('state')}（封锁已清）")
    return 0


def _cmd_check() -> int:
    ok, msgs = selfcheck()
    print("\n".join(msgs))
    print("✅ 台账自检通过" if ok else "🔴 台账自检失败")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
