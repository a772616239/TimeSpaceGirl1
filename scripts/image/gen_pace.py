#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_pace.py —— 出图「节奏闸门」+ 会话「保活心跳」。

为什么要这个文件
----------------
2026-10-29 Google 账号被停用（用户："被封号了"）。复盘 `_output/**/inbox/*.meta.json`
的 269 次出图时间戳：**相邻间隔中位数 46 秒、79% 不到 1 分钟、峰值一小时 32 张**
（10-27 13 点 32 张、14 点 20 张）。真人不可能是这个节奏，这是纯自动化的排产签名。

两道闸一起上：

1) **gate() 节奏闸门** —— 按*账号*记账（不是按 job），跨进程 flock 共享一份账：
   · `min_gap`      两张图之间至少隔多久（默认 gemini 180s，带 ±30% 抖动，别用固定节拍）
   · `max_per_hour` 每小时上限（默认 10）
   · `max_per_day`  每天上限（默认 50，撞上了直接把号标成「明天再来」，让换号链换下一个号）
   · `break_every`  连续画 N 张强制歇一次（默认 8 张歇 10 分钟）——人是要离开工位的
   并行构建共用同一个账本 ⇒ 「多开两个 job 就能多画」这条捷径自动失效，
   要提吞吐只能加号（每个号各自限额），这是刻意的。

2) **maybe_heartbeat() 保活心跳** —— 出图期间每 40 分钟（±15% 抖动）在同一个浏览器里
   发一条**纯文本**请求。两个作用：
   · 会话保活：长时间「只建图、不说话」的会话更容易被判成自动化（用户要求的防 GC）
   · 早发现：登录态掉了 / 号被停了，在心跳这一步就报出来，而不是等下一次出图白等 5 分钟
   🔴 心跳失败**不写台账封号**：很多 AdsPower profile 只登录了 ChatGPT 没登录 Google，
     把「这台没 Google」当成「号坏了」会把好号全封掉。心跳只在本地记 `no_google`，24h 内不再戳它。

用法（CLI 主要给 Jenkins / 人工排查用，正常路径由出图脚本内部调用）
------------------------------------------------------------------
    gen_pace.py status                       # 现在各账号的节奏与下次可用时间
    gen_pace.py gate --provider gemini --account adspower:ktmrjhu
    gen_pace.py heartbeat --port 57750 --account adspower:ktmrjhu [--force]
    gen_pace.py reset [--account ...]        # 清掉限速账（不动额度台账）

退出码：0 放行 / 75 等不到窗口（EX_TEMPFAIL，不是失败，是「现在不该画」）/ 1 其他
"""
from __future__ import annotations

import argparse
import contextlib
import json
import os
import random
import subprocess
import sys
import tempfile
import time
from pathlib import Path

try:                                                          # macOS/Linux 走 flock
    import fcntl
except ImportError:                                           # pragma: no cover - Windows
    fcntl = None  # type: ignore[assignment]

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
STATE = Path(os.environ.get("TSG_PACE_STATE")
             or (ROOT / "_output/art_restyle/gen_pace.json"))
EVENTS = Path(os.environ.get("TSG_PACE_EVENTS") or (STATE.parent / "gen_pace_events.jsonl"))
GEN_GEMINI = HERE / "gen_gemini.py"

RC_OK, RC_ERR, RC_WAIT = 0, 1, 75

# 每个 provider 的默认节奏。gemini 是真被告警的那条（Google 账号），给得保守；
# chatgpt 只做轻限速（它不是封号来源，压太狠会把整条链拖成龟速）。
DEFAULTS: dict[str, dict] = {
    "gemini": {"min_gap": 180, "max_per_hour": 10, "max_per_day": 50,
               "break_every": 8, "break_sec": 600},
    "chatgpt": {"min_gap": 30, "max_per_hour": 25, "max_per_day": 120,
                "break_every": 0, "break_sec": 0},
}

# 心跳文案池：**别每次发同一句**——同一串字符每 40 分钟准点出现，本身就是机器签名。
PING_PROMPTS = [
    "你好，随便说一句今天适合做点什么？",
    "帮我想一个三个字的词，关于秋天的。",
    "用一句话说说猫为什么会踩键盘。",
    "给我一句短一点的鼓励的话。",
    "推荐一部适合下雨天看的电影，只说片名。",
    "1 加 1 等于几？只回数字。",
]


# ──────────────────────────────────────────────────────────── 小工具
def log(msg: str) -> None:
    print(f"[pace] {msg}", flush=True)


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or str(raw).strip() == "":
        return default
    try:
        return int(float(str(raw).strip()))
    except ValueError:
        return default


def _env_float(name: str, default: float) -> float:
    raw = os.environ.get(name)
    if raw is None or str(raw).strip() == "":
        return default
    try:
        return float(str(raw).strip())
    except ValueError:
        return default


def _truthy(v: str | None) -> bool:
    return str(v or "").strip().lower() in ("1", "true", "yes", "on")


def config(provider: str = "gemini") -> dict:
    """provider 的生效节奏：内置默认 ← 通用环境变量 ← provider 专属环境变量。"""
    p = provider if provider in DEFAULTS else "gemini"
    cfg = dict(DEFAULTS[p])
    up = p.upper()
    cfg["min_gap"] = _env_int(f"TSG_{up}_MIN_GAP", _env_int("TSG_GEN_MIN_GAP", cfg["min_gap"]))
    cfg["max_per_hour"] = _env_int(f"TSG_{up}_MAX_PER_HOUR",
                                   _env_int("TSG_GEN_MAX_PER_HOUR", cfg["max_per_hour"]))
    cfg["max_per_day"] = _env_int(f"TSG_{up}_MAX_PER_DAY",
                                  _env_int("TSG_GEN_MAX_PER_DAY", cfg["max_per_day"]))
    cfg["break_every"] = _env_int("TSG_GEN_BREAK_EVERY", cfg["break_every"])
    cfg["break_sec"] = _env_int("TSG_GEN_BREAK_SEC", cfg["break_sec"])
    cfg["jitter"] = max(0.0, _env_float("TSG_GEN_JITTER", 0.3))
    cfg["max_wait"] = _env_int("TSG_GEN_MAX_WAIT", 1800)
    cfg["provider"] = p
    # 关闸的两种姿势：TSG_GEN_PACE=off（全程），或命令行 --no-pace（单次）
    cfg["disabled"] = _truthy(os.environ.get("TSG_GEN_PACE_OFF")) or \
        str(os.environ.get("TSG_GEN_PACE", "")).strip().lower() in ("off", "0", "false", "no")
    return cfg


def heartbeat_config() -> dict:
    return {
        "minutes": _env_int("TSG_HB_MINUTES", 40),
        "jitter": max(0.0, _env_float("TSG_HB_JITTER", 0.15)),
        "timeout": _env_int("TSG_HB_TIMEOUT", 150),
        "disabled": _truthy(os.environ.get("TSG_HB_OFF")),
        # 同一个号 24h 内最多戳几次（防「心跳自己变成高频请求」）
        "max_per_day": _env_int("TSG_HB_MAX_PER_DAY", 36),
    }


@contextlib.contextmanager
def locked(timeout: float = 20.0):
    """跨进程互斥。拿不到锁就等，超时就抛 —— 调用方必须能容忍（不能因此停止出图）。"""
    lock_path = Path(str(STATE) + ".lock")
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
                    raise TimeoutError(f"节奏账本锁等待超时（{timeout:.0f}s）")
                time.sleep(0.05)
        yield
    finally:
        try:
            if fcntl:
                fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
        finally:
            fh.close()


def load() -> dict:
    try:
        d = json.loads(STATE.read_text(encoding="utf-8"))
        if isinstance(d.get("accounts"), dict):
            return d
    except Exception:                                         # noqa: BLE001
        pass
    return {"_note": "出图节奏账本（自动维护，可删）。epoch 秒，给人看的时间另记 iso 字段。",
            "accounts": {}}


def save(d: dict) -> None:
    STATE.parent.mkdir(parents=True, exist_ok=True)
    tmp = Path(str(STATE) + ".tmp")
    tmp.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(STATE)


def note_event(rec: dict) -> None:
    """审计流水：加一行 jsonl。写不进去也不能影响出图。"""
    try:
        EVENTS.parent.mkdir(parents=True, exist_ok=True)
        rec = dict(rec)
        rec.setdefault("at", _iso(time.time()))
        rec.setdefault("owner", os.environ.get("TSG_LEASE_OWNER") or f"pid{os.getpid()}")
        with open(EVENTS, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    except Exception:                                         # noqa: BLE001
        pass


def _iso(ts: float) -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.localtime(ts))


def _fmt(sec: float) -> str:
    """人读的等待时长：<90s 就给秒（「0.1 分钟」这种写法看不出到底等多久）。"""
    sec = max(0.0, float(sec))
    if sec < 90:
        return f"{sec:.0f} 秒"
    if sec < 3600:
        return f"{sec / 60:.1f} 分钟"
    return f"{sec / 3600:.1f} 小时"


def _key(provider: str, account: str) -> str:
    acc = (account or "").strip() or "default"
    return f"{provider or 'gemini'}:{acc}"


def _entry(d: dict, key: str) -> dict:
    return d.setdefault("accounts", {}).setdefault(key, {})


def _normalize(e: dict, now: float, cfg: dict) -> dict:
    """把日计数与小时窗口滚到「现在」——所有判定之前先做这一步。"""
    day = time.strftime("%Y-%m-%d", time.localtime(now))
    if e.get("day") != day:
        e["day"] = day
        e["day_count"] = 0
        e["since_break"] = 0
        e["ping_day"] = 0
        e["no_google"] = False if e.get("no_google_day") != day else e.get("no_google", False)
    if not isinstance(e.get("starts"), list):
        e["starts"] = []
    e["starts"] = [float(t) for t in e["starts"] if now - float(t) < 3600]
    return e


def _midnight(now: float) -> float:
    lt = time.localtime(now)
    tomorrow = time.mktime((lt.tm_year, lt.tm_mon, lt.tm_mday, 23, 59, 59, 0, 0, -1))
    return tomorrow + 1


def _wait_needed(e: dict, now: float, cfg: dict) -> tuple[float, str]:
    """还要等多久才能开下一张，以及为什么。0 = 现在就能开。"""
    waits: list[tuple[float, str]] = [(0.0, "")]
    day_count = int(e.get("day_count") or 0)
    if cfg["max_per_day"] and day_count >= cfg["max_per_day"]:
        waits.append((_midnight(now) - now, f"日上限 {cfg['max_per_day']} 张"))
    if cfg["max_per_hour"] and len(e["starts"]) >= cfg["max_per_hour"]:
        # 要等到「窗口里只剩 max-1 条」：第 len-max 早的那条过期
        expired = sorted(e["starts"])[len(e["starts"]) - cfg["max_per_hour"]]
        waits.append((expired + 3600 - now, f"小时上限 {cfg['max_per_hour']} 张"))
    gap = float(cfg["min_gap"])
    why = f"最小间隔 {int(gap)}s"
    if cfg["break_every"] and int(e.get("since_break") or 0) >= cfg["break_every"]:
        if cfg["break_sec"] > gap:
            gap = float(cfg["break_sec"])
            why = f"连画 {e.get('since_break')} 张，强制长休 {int(gap)}s"
    last = e.get("last_start_at")
    if last:
        # 🔴 抖动必须加：固定 180s 的节拍比 46s 更像机器 —— 人不会这么准点
        jit = 1.0 + random.uniform(-cfg["jitter"], cfg["jitter"])
        waits.append((float(last) + gap * jit - now, why))
    wait, reason = max(waits, key=lambda t: t[0])
    return max(0.0, wait), reason


def _record_start(e: dict, now: float, cfg: dict) -> None:
    e["starts"].append(now)
    e["last_start_at"] = now
    e["last_start_iso"] = _iso(now)
    e["day_count"] = int(e.get("day_count") or 0) + 1
    e.setdefault("total", 0)
    e["total"] = int(e["total"]) + 1
    if cfg["break_every"] and int(e.get("since_break") or 0) >= cfg["break_every"]:
        e["since_break"] = 0                       # 这一张是歇过之后画的
    else:
        e["since_break"] = int(e.get("since_break") or 0) + 1


def _ledger():
    try:
        if str(HERE) not in sys.path:
            sys.path.insert(0, str(HERE))
        import provider_ledger as pl
        return pl
    except Exception:                                         # noqa: BLE001
        return None


def _mark_paced_out(key: str, cfg: dict, wait: float, reason: str) -> None:
    """日上限撞了 ⇒ 把这个号在额度台账里标成「明天再来」，让换号链换下一个号。

    🔴 只处理「日上限」这一种。小时上限 / 最小间隔靠等，不该触发换号
       （换号是稀缺动作，为了几分钟的间隔去换号，等于把好号的额度白白摊薄）。
    """
    if not reason.startswith("日上限"):
        return
    pl = _ledger()
    if pl is None:
        return
    # 🔴 账本 key 是「provider:账号」，例如 gemini:adspower:ktmrjhu ——
    #    先剥掉 provider 那一层，台账才认得出 kind=adspower / ident=ktmrjhu。
    rest = key.split(":", 1)[1] if ":" in key else ""
    if ":" not in rest:
        return                                                 # 只有端口、没有账号标识：无从记
    kind, ident = rest.split(":", 1)
    try:
        pl.mark_unusable(kind, ident, note=f"pace-day-cap（{cfg['max_per_day']} 张/天已用满）",
                         cooldown_min=max(1, int(wait // 60) + 1))
        note_event({"action": "pace-out", "key": key, "reason": reason})
    except Exception as e:                                    # noqa: BLE001
        log(f"⚠ 标台账失败（{e}）")


def _mark_banned(key: str) -> None:
    """号被 Google 停用 ⇒ 在额度台账里封 7 天，换号链自然跳过它。

    🔴 和「没登录 Google」必须分开：没登录只是这台浏览器上没登（GPT 还能用），
       停用是号没了（这台浏览器上的两条通道都废了）。
    """
    pl = _ledger()
    if pl is None:
        return
    rest = key.split(":", 1)[1] if ":" in key else ""
    if ":" not in rest:
        return
    kind, ident = rest.split(":", 1)
    if kind not in ("adspower", "sunbrowser", "chrome"):
        return
    try:
        pl.mark_unusable(kind, ident,
                         note="google-account-restricted（Google 账号被停用，7 天内别再用）",
                         cooldown_min=7 * 24 * 60)
        note_event({"action": "account-restricted", "key": key})
    except Exception as e:                                    # noqa: BLE001
        log(f"⚠ 标台账失败（{e}）")


# ──────────────────────────────────────────────────────────── ① 节奏闸门
def gate(provider: str = "gemini", account: str = "", *, max_wait: int | None = None,
         no_pace: bool = False, logf=log) -> int:
    """阻塞到「可以画下一张」，返回 RC_OK；等不到窗口返回 RC_WAIT（75）。

    并行安全：判定与记账在同一把 flock 里完成，所以两个构建不会同时拿到同一个窗口。
    """
    cfg = config(provider)
    if no_pace or cfg["disabled"]:
        if cfg["disabled"]:
            logf("节奏闸门：已关闭（TSG_GEN_PACE=off）—— 注意这会让账号继续跑自动化节拍")
        return RC_OK
    key = _key(cfg["provider"], account)
    limit = cfg["max_wait"] if max_wait is None else max_wait
    t0 = time.time()
    announced = ""
    while True:
        with locked():
            d = load()
            e = _normalize(_entry(d, key), time.time(), cfg)
            now = time.time()
            wait, reason = _wait_needed(e, now, cfg)
            if wait <= 0:
                _record_start(e, now, cfg)
                save(d)
                if time.time() - t0 > 1:
                    logf(f"节奏闸门：{key} 等待 {time.time() - t0:.0f}s 后放行"
                         f"（今日第 {e['day_count']} 张，本小时 {len(e['starts'])} 张）")
                note_event({"action": "gate-pass", "key": key, "waited_s": round(time.time() - t0),
                            "day_count": e["day_count"], "hour": len(e["starts"])})
                return RC_OK
            need_next = wait
        if time.time() - t0 + need_next > limit:
            logf(f"节奏闸门：{key} 还要等 {_fmt(need_next)}（{reason}），"
                 f"超过本次上限 {limit}s ⇒ 本张放弃（不是失败，是「现在不该画」）")
            note_event({"action": "gate-giveup", "key": key, "reason": reason,
                        "need_wait_s": round(need_next)})
            _mark_paced_out(key, cfg, need_next, reason)
            return RC_WAIT
        tick = f"{key}:{reason}"
        if tick != announced:
            logf(f"节奏闸门：{key} 需等 {_fmt(need_next)}（{reason}）—— 这是故意的，"
                 f"账号刚因为跑太快被封过一次")
            announced = tick
        time.sleep(min(need_next, 30.0))


# ──────────────────────────────────────────────────────────── ② 保活心跳
def _ping_once(port: int, timeout: int) -> tuple[int, dict]:
    """在 port 的浏览器里发一条纯文本请求（走 gen_gemini.py --text-ping）。"""
    if not GEN_GEMINI.is_file():
        return RC_ERR, {"error": "gen_gemini.py 不存在"}
    tmpdir = Path(tempfile.mkdtemp(prefix="gen_ping_"))
    out = tmpdir / "ping.json"
    prompt = tmpdir / "ping.txt"
    prompt.write_text(random.choice(PING_PROMPTS) + "\n", encoding="utf-8")
    env = dict(os.environ)
    env["NO_PROXY"] = "127.0.0.1,localhost"
    env["no_proxy"] = "127.0.0.1,localhost"
    cmd = [sys.executable, str(GEN_GEMINI), "--text-ping", "--port", str(port),
           "--prompt-file", str(prompt), "--out", str(out), "--timeout", str(timeout),
           "--no-pace"]
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 90, env=env)
    except subprocess.TimeoutExpired:
        return RC_ERR, {"error": "心跳超时"}
    detail: dict = {}
    for cand in (Path(str(out) + ".ping.json"), Path(str(out) + ".fail.json")):
        try:
            detail = json.loads(cand.read_text(encoding="utf-8"))
            break
        except Exception:                                     # noqa: BLE001
            continue
    for line in (p.stdout or "").strip().splitlines()[-4:]:
        log(f"   | {line}")
    return (RC_OK if p.returncode == 0 else p.returncode), detail


def heartbeat_due(port: int, account: str = "", *, force: bool = False) -> tuple[bool, str]:
    """现在该不该戳一下？→ (该, 原因)。只读，不改账。"""
    hb = heartbeat_config()
    if hb["disabled"]:
        return False, "心跳已关闭（TSG_HB_OFF）"
    key = _key("session", account or f"port:{port}")
    with locked():
        d = load()
        e = _normalize(_entry(d, key), time.time(), {**DEFAULTS["gemini"], "max_per_day": 0,
                                                     "max_per_hour": 0, "break_every": 0})
        if force:
            return True, "强制"
        if e.get("banned"):
            return False, f"这个号已被 Google 停用（{e.get('banned_at') or '?'}）—— 换号"
        if e.get("no_google"):
            return False, "这台浏览器没登录 Google（已跳过 24h）"
        if int(e.get("ping_day") or 0) >= hb["max_per_day"]:
            return False, f"今天心跳已达上限 {hb['max_per_day']} 次"
        last = float(e.get("last_ping_at") or 0)
        if not last:
            return True, "本轮第一次"
        interval = hb["minutes"] * 60 * (1.0 + random.uniform(-hb["jitter"], hb["jitter"]))
        gap = time.time() - last
        if gap >= interval:
            return True, f"距上次心跳 {gap / 60:.0f} 分钟（阈值 {interval / 60:.0f} 分钟）"
        return False, f"距上次心跳 {gap / 60:.0f} 分钟，未到点"


def maybe_heartbeat(port: int | None, account: str = "", *, force: bool = False,
                    logf=log) -> dict:
    """到点就在这个浏览器里发一条纯文本请求。**永不抛异常、永不阻断出图。**

    返回 {"did": bool, "rc": int, "reason": str}
    """
    if not port:
        return {"did": False, "rc": RC_OK, "reason": "没有可用的 CDP 端口"}
    try:
        due, why = heartbeat_due(port, account=account, force=force)
    except Exception as e:                                    # noqa: BLE001
        logf(f"⚠ 心跳判定失败（{e}），跳过")
        return {"did": False, "rc": RC_ERR, "reason": f"判定失败：{e}"}
    if not due:
        return {"did": False, "rc": RC_OK, "reason": why}
    hb = heartbeat_config()
    key = _key("session", account or f"port:{port}")
    # 抢占：同一时刻只允许一个进程戳（并行构建会同时到点）
    with locked():
        d = load()
        e = _normalize(_entry(d, key), time.time(), {**DEFAULTS["gemini"], "max_per_day": 0,
                                                     "max_per_hour": 0, "break_every": 0})
        held = e.get("ping_claim") or {}
        if held and time.time() - float(held.get("at") or 0) < 600 \
                and held.get("owner") != (os.environ.get("TSG_LEASE_OWNER") or f"pid{os.getpid()}"):
            return {"did": False, "rc": RC_OK, "reason": f"另一个进程正在心跳（{held.get('owner')}）"}
        e["ping_claim"] = {"at": time.time(), "owner": os.environ.get("TSG_LEASE_OWNER")
                           or f"pid{os.getpid()}", "port": int(port)}
        save(d)
    logf(f"心跳：{key}（端口 {port}）—— {why}")
    rc, detail = _ping_once(int(port), hb["timeout"])
    with locked():
        d = load()
        e = _normalize(_entry(d, key), time.time(), {**DEFAULTS["gemini"], "max_per_day": 0,
                                                     "max_per_hour": 0, "break_every": 0})
        e.pop("ping_claim", None)
        e["ping_day"] = int(e.get("ping_day") or 0) + 1
        e["last_ping_rc"] = rc
        e["last_ping_iso"] = _iso(time.time())
        if rc == RC_OK:
            e["last_ping_at"] = time.time()
            e["ping_ok"] = int(e.get("ping_ok") or 0) + 1
            e.pop("no_google", None)
        elif rc == 3:
            if str(detail.get("reason") or "") == "account-restricted":
                # 号被 Google 停用：不是「没登录」，不能只是不戳 —— 得把号挑出来。
                e["banned"] = True
                e["banned_at"] = _iso(time.time())
                logf("🔴 心跳：这个 Google 号已被停用（落在 restrictions 页）"
                     f" —— 7 天内别再试这台，换号")
                _mark_banned(key)
            else:
                # 这台没登录 Google（或登录态掉了）。不封号，只是别再戳它 ——
                # 免得每次都要多等 2 分钟。GPT 那条通道照样能用。
                e["no_google"] = True
                e["no_google_day"] = time.strftime("%Y-%m-%d")
                logf("心跳：这台浏览器没有可用的 Google 登录态 → 24h 内不再戳它（不影响 GPT 出图）")
        elif rc == 4:
            logf("心跳：Gemini 返回额度/频率受限 —— 说明账号还在、只是被限了，别急着换号")
        else:
            logf(f"心跳失败 rc={rc}：{(detail.get('message') or '')[:150]}")
        save(d)
    note_event({"action": "heartbeat", "key": key, "rc": rc, "why": why,
                "port": int(port)})
    return {"did": True, "rc": rc, "reason": why}


# ──────────────────────────────────────────────────────────── ③ CLI
def render() -> str:
    d = load()
    now = time.time()
    rows = []
    for key, e in sorted((d.get("accounts") or {}).items()):
        provider = key.split(":", 1)[0]
        if provider == "session":
            continue
        cfg = config(provider)
        e = _normalize(dict(e), now, cfg)
        wait, reason = _wait_needed(e, now, cfg)
        rows.append((key, int(e.get("day_count") or 0), len(e["starts"]), wait, reason,
                     str(e.get("last_start_iso") or "-")))
    lines = ["出图节奏（现在：%s）" % _iso(now), ""]
    if not rows:
        lines.append("  （还没有任何出图记录）")
    else:
        lines.append("  %-26s %-8s %-8s %-12s %s" % ("账号", "今日", "本小时", "下次可画", "原因"))
        for key, day, hour, wait, reason, last in rows:
            lines.append("  %-26s %-8d %-8d %-12s %s" % (
                key, day, hour, ("现在" if wait <= 0 else _fmt(wait)), reason))
    pings = [(k, v) for k, v in (d.get("accounts") or {}).items() if k.startswith("session:")]
    if pings:
        lines += ["", "保活心跳（%d 分钟一次）:" % heartbeat_config()["minutes"]]
        for k, v in sorted(pings):
            tag = ""
            if v.get("banned"):
                tag = "🔴 已被 Google 停用，换号"
            elif v.get("no_google"):
                tag = "（无 Google 登录，已停）"
            lines.append("  %-26s 上次 %-20s rc=%s%s" % (
                k.replace("session:", ""), str(v.get("last_ping_iso") or "-"),
                v.get("last_ping_rc", "-"), tag))
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="出图节奏闸门 + 会话保活心跳")
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("status", help="看各账号节奏与下次可用时间")
    s.add_argument("--json", action="store_true")

    g = sub.add_parser("gate", help="阻塞到可以画下一张（记账）")
    g.add_argument("--provider", default="gemini", choices=sorted(DEFAULTS))
    g.add_argument("--account", default="")
    g.add_argument("--max-wait", type=int, default=None)

    h = sub.add_parser("heartbeat", help="到点就在这个端口发一条纯文本请求")
    h.add_argument("--port", type=int, required=True)
    h.add_argument("--account", default="")
    h.add_argument("--force", action="store_true")

    r = sub.add_parser("reset", help="清限速账（不动额度台账）")
    r.add_argument("--account", default=None)
    r.add_argument("--all", action="store_true")

    a = ap.parse_args(argv)
    if a.cmd == "status":
        print(json.dumps(load(), ensure_ascii=False, indent=2) if a.json else render())
        return RC_OK
    if a.cmd == "gate":
        return gate(a.provider, a.account, max_wait=a.max_wait)
    if a.cmd == "heartbeat":
        res = maybe_heartbeat(a.port, a.account, force=a.force)
        return RC_OK if res["rc"] in (RC_OK, 3, 4) else RC_ERR
    if a.cmd == "reset":
        with locked():
            d = load()
            if a.account:
                d["accounts"].pop(_key("gemini", a.account), None)
                d["accounts"].pop(_key("chatgpt", a.account), None)
            elif a.all:
                d["accounts"] = {}
            save(d)
        print(render())
        return RC_OK
    return RC_ERR


if __name__ == "__main__":
    raise SystemExit(main())
