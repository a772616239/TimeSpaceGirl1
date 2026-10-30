#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gen_pace 的离线测试：不启浏览器、不烧额度，只验「节奏闸门」与「保活心跳」的调度。

为什么要单独测这个：限速一旦写错是**双向**坑 ——
  · 放宽了：又回到 46 秒一张、峰值 32 张/小时那个被封号的节奏；
  · 收死了：构建全在等窗口，看着像「出图挂了」。
而且它是并行构建共用的账本，并发正确性只能靠这种离线仿真验（线上验一次就是一张图的额度）。

跑法：
    /Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python \
        scripts/image/tests/test_gen_pace.py
"""
from __future__ import annotations

import json
import os
import shutil
import sys
import threading
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
IMAGE_DIR = HERE.parent
ROOT = IMAGE_DIR.parents[1]
sys.path.insert(0, str(IMAGE_DIR))

TMP = ROOT / "_output/art_translate/_tests_pace"
os.environ["TSG_PACE_STATE"] = str(TMP / "gen_pace.json")
os.environ["TSG_PACE_EVENTS"] = str(TMP / "events.jsonl")

import gen_pace as gp          # noqa: E402

_ORIG_LEDGER = gp._ledger       # 打桩用，测完要还原（后续场景还要读真台账口径）
FAILS: list[str] = []


def check(cond: bool, msg: str) -> None:
    print(("  ✅ " if cond else "  🔴 ") + msg)
    if not cond:
        FAILS.append(msg)


def quiet(_m: str) -> None:
    pass


def reset(**env) -> None:
    """每个场景从干净账本开始，并显式给一套小参数（别让测试跑成真实的 3 分钟/张）。"""
    for k in list(os.environ):
        if k.startswith("TSG_GEN_") or k.startswith("TSG_GEMINI_") or k.startswith("TSG_HB_"):
            os.environ.pop(k, None)
    Path(os.environ["TSG_PACE_STATE"]).unlink(missing_ok=True)
    os.environ["TSG_GEN_JITTER"] = "0"
    os.environ.update({k: str(v) for k, v in env.items()})


class FakeLedger:
    def __init__(self) -> None:
        self.calls: list[tuple[str, str, str, int]] = []

    def mark_unusable(self, kind, ident, note="", cooldown_min=None, **_kw):
        self.calls.append((kind, ident, note, cooldown_min or 0))
        return {}


def case_gap_and_limits() -> None:
    print("\n[最小间隔 / 小时上限 / 日上限]")
    reset(TSG_GEMINI_MIN_GAP="1", TSG_GEMINI_MAX_PER_HOUR="10", TSG_GEMINI_MAX_PER_DAY="10")
    t0 = time.time()
    check(gp.gate("gemini", "adspower:t1", logf=quiet) == gp.RC_OK, "第一张立即放行")
    check(time.time() - t0 < 0.5, f"第一张没白等（{time.time() - t0:.2f}s）")
    t1 = time.time()
    check(gp.gate("gemini", "adspower:t1", logf=quiet) == gp.RC_OK, "第二张放行")
    waited = time.time() - t1
    check(waited >= 0.9, f"第二张等满最小间隔（实测 {waited:.2f}s ≥ 0.9s）")

    reset(TSG_GEMINI_MIN_GAP="0", TSG_GEMINI_MAX_PER_HOUR="2", TSG_GEMINI_MAX_PER_DAY="10")
    for _ in range(2):
        gp.gate("gemini", "adspower:t2", logf=quiet)
    rc = gp.gate("gemini", "adspower:t2", max_wait=1, logf=quiet)
    check(rc == gp.RC_WAIT, f"第 3 张撞小时上限 → RC_WAIT(75)（rc={rc}）")
    st = gp.load()["accounts"]["gemini:adspower:t2"]
    check(len(st["starts"]) == 2, f"被拦下的那张**不记账**（starts={len(st['starts'])}）")

    # 不同账号各自记账：并行构建换号不算绕过，但也不该互相堵
    check(gp.gate("gemini", "adspower:t3", logf=quiet) == gp.RC_OK,
          "另一个账号不受 t2 的小时上限影响（额度按账号算）")


def case_day_cap_marks_ledger() -> None:
    print("\n[日上限 → 台账标「明天再来」，让换号链接手]")
    reset(TSG_GEMINI_MIN_GAP="0", TSG_GEMINI_MAX_PER_HOUR="99", TSG_GEMINI_MAX_PER_DAY="2")
    fake = FakeLedger()
    gp._ledger = lambda: fake
    for _ in range(2):
        gp.gate("gemini", "adspower:t4", logf=quiet)
    rc = gp.gate("gemini", "adspower:t4", max_wait=1, logf=quiet)
    check(rc == gp.RC_WAIT, f"第 3 张撞日上限 → RC_WAIT（rc={rc}）")
    check(len(fake.calls) == 1, f"记了一次台账（{fake.calls}）")
    if fake.calls:
        kind, ident, note, cd = fake.calls[0]
        check((kind, ident) == ("adspower", "t4"), f"记在正确的号上（{kind}:{ident}）")
        check("pace-day-cap" in note, f"note 说明原因（{note}）")
        check(cd >= 60, f"冷却到明天（{cd} 分钟）")

    # 小时上限**不该**触发换号：为几分钟的间隔换号会把好号额度摊薄
    reset(TSG_GEMINI_MIN_GAP="0", TSG_GEMINI_MAX_PER_HOUR="1", TSG_GEMINI_MAX_PER_DAY="99")
    fake2 = FakeLedger()
    gp._ledger = lambda: fake2
    gp.gate("gemini", "adspower:t5", logf=quiet)
    gp.gate("gemini", "adspower:t5", max_wait=1, logf=quiet)
    check(not fake2.calls, f"小时上限只等不换号（台账调用 {fake2.calls}）")
    gp._ledger = _ORIG_LEDGER


def case_break() -> None:
    print("\n[连画 N 张强制长休]")
    reset(TSG_GEMINI_MIN_GAP="0", TSG_GEMINI_MAX_PER_HOUR="99", TSG_GEMINI_MAX_PER_DAY="99",
          TSG_GEN_BREAK_EVERY="2", TSG_GEN_BREAK_SEC="2")
    gp.gate("gemini", "adspower:t6", logf=quiet)
    gp.gate("gemini", "adspower:t6", logf=quiet)
    t = time.time()
    gp.gate("gemini", "adspower:t6", logf=quiet)
    waited = time.time() - t
    check(waited >= 1.9, f"第 3 张前强制歇 2s（实测 {waited:.2f}s）")
    t = time.time()
    gp.gate("gemini", "adspower:t6", logf=quiet)
    check(time.time() - t < 0.5, "歇过之后下一张立刻放行（计数器已归零）")


def case_parallel() -> None:
    print("\n[并发：四个构建同时要窗口，不许同时拿到]")
    reset(TSG_GEMINI_MIN_GAP="1", TSG_GEMINI_MAX_PER_HOUR="99", TSG_GEMINI_MAX_PER_DAY="99")
    t0 = time.time()
    order: list[float] = []
    lock = threading.Lock()

    def worker() -> None:
        gp.gate("gemini", "adspower:tp", logf=quiet)
        with lock:
            order.append(time.time() - t0)

    ths = [threading.Thread(target=worker) for _ in range(4)]
    for th in ths:
        th.start()
    for th in ths:
        th.join()
    order.sort()
    gaps = [b - a for a, b in zip(order, order[1:])]
    check(len(order) == 4, f"四张都放行了（{len(order)}）")
    check(all(g >= 0.85 for g in gaps), f"相邻两张间隔都 ≥ 最小间隔（{['%.2f' % g for g in gaps]}）")
    st = gp.load()["accounts"]["gemini:adspower:tp"]
    check(st["day_count"] == 4, f"账本记满四张（day_count={st['day_count']}）")


def case_heartbeat() -> None:
    print("\n[40 分钟文本心跳]")
    # 🔴 抖动关掉再测节拍：生产上 40 分钟会 ±15%（34~46 分钟），
    #    「41 分钟该不该戳」这种断言在有抖动时是随机的 —— 第一版测试就栽在这。
    reset(TSG_HB_JITTER="0")
    port = 57750
    due, why = gp.heartbeat_due(port, account="adspower:hb1")
    check(due, f"本轮第一次就该戳（{why}）")

    calls: list[int] = []

    def fake_ping(p, timeout):
        calls.append(p)
        return 0, {"reply": "好的"}

    gp._ping_once = fake_ping
    r = gp.maybe_heartbeat(port, account="adspower:hb1", logf=quiet)
    check(r["did"] and r["rc"] == 0, f"第一个心跳发出去了（{r}）")
    check(calls == [port], f"戳在指定的端口上（{calls}）")

    r2 = gp.maybe_heartbeat(port, account="adspower:hb1", logf=quiet)
    check(not r2["did"], f"没到点不再戳（{r2['reason']}）")
    check(len(calls) == 1, f"只发了一次请求（{len(calls)}）")

    # 把上次心跳推到 41 分钟前 → 又该戳了
    st = gp.load()
    st["accounts"]["session:adspower:hb1"]["last_ping_at"] = time.time() - 41 * 60
    gp.STATE.write_text(json.dumps(st, ensure_ascii=False), encoding="utf-8")
    due2, why2 = gp.heartbeat_due(port, account="adspower:hb1")
    check(due2, f"41 分钟后又到点（{why2}）")
    check("40 分钟" in why2, f"阈值就是 40 分钟（{why2}）")

    # 抖动是**功能**：固定 40 分钟准点发文本，本身也是机器签名。抽 40 次应出现多个阈值。
    reset(TSG_HB_JITTER="0.15")
    seen = set()
    for _ in range(40):
        st = gp.load()
        e = st["accounts"].setdefault("session:adspower:j1", {})
        e["last_ping_at"] = time.time() - 40 * 60
        gp.STATE.write_text(json.dumps(st, ensure_ascii=False), encoding="utf-8")
        _due, why = gp.heartbeat_due(port, account="adspower:j1")
        seen.add(why.split("阈值 ")[-1].rstrip(" 分钟）") if "阈值" in why else why)
    check(len(seen) > 1, f"心跳间隔有抖动，不是准点节拍（抽到 {len(seen)} 种阈值）")

    # 没登录 Google 的浏览器：一次失败就别再戳，别把 GPT 出图拖成每张多等 2 分钟
    def ping_login_fail(p, timeout):
        calls.append(p)
        return 3, {"message": "需要登录"}

    gp._ping_once = ping_login_fail
    r3 = gp.maybe_heartbeat(port, account="adspower:hb2", logf=quiet)
    check(r3["did"] and r3["rc"] == 3, f"登录态没了会如实上报（{r3}）")
    r4 = gp.maybe_heartbeat(port, account="adspower:hb2", logf=quiet)
    check(not r4["did"] and "Google" in r4["reason"], f"之后不再戳这台（{r4['reason']}）")

    # 号被停用（restrictions 页）：不是「没登录」，要记进台账封 7 天，换号链自然跳过
    fake = FakeLedger()
    gp._ledger = lambda: fake

    def ping_restricted(p, timeout):
        return 3, {"reason": "account-restricted", "message": "账号已被停用",
                   "url": "https://myaccount.google.com/restrictions/280"}

    gp._ping_once = ping_restricted
    r5 = gp.maybe_heartbeat(port, account="adspower:hb4", logf=quiet)
    check(r5["did"] and r5["rc"] == 3, f"停用会如实上报（{r5['rc']}）")
    check(len(fake.calls) == 1 and fake.calls[0][:2] == ("adspower", "hb4"),
          f"记进台账的是号本身（{fake.calls}）")
    if fake.calls:
        check(fake.calls[0][3] >= 7 * 24 * 60, f"封 7 天（{fake.calls[0][3]} 分钟）")
        check("restricted" in fake.calls[0][2], f"note 写明原因（{fake.calls[0][2]}）")
    r6 = gp.maybe_heartbeat(port, account="adspower:hb4", logf=quiet)
    check(not r6["did"] and "停用" in r6["reason"], f"停用的号之后不再戳（{r6['reason']}）")
    gp._ledger = _ORIG_LEDGER

    # 心跳总量上限：防「心跳自己变成高频请求」
    reset(TSG_HB_MAX_PER_DAY="1")
    gp._ping_once = fake_ping
    gp.maybe_heartbeat(port, account="adspower:hb3", logf=quiet)
    st = gp.load()
    st["accounts"]["session:adspower:hb3"]["last_ping_at"] = time.time() - 3 * 3600
    gp.STATE.write_text(json.dumps(st, ensure_ascii=False), encoding="utf-8")
    due3, why3 = gp.heartbeat_due(port, account="adspower:hb3")
    check(not due3, f"撞日上限后即使到点也不戳（{why3}）")


def case_off_switch() -> None:
    print("\n[关闸开关]")
    reset(TSG_GEMINI_MIN_GAP="5")
    gp.gate("gemini", "adspower:off1", logf=quiet)
    t = time.time()
    gp.gate("gemini", "adspower:off1", logf=quiet, no_pace=True)
    check(time.time() - t < 0.3, "no_pace 单次跳过（人工验证用）")
    t = time.time()
    gp.gate("gemini", "adspower:off1", logf=quiet)     # 没记账的那次不算，仍要等
    check(time.time() - t >= 4.5, f"跳过的那次不记账，下一次照旧要等（{time.time() - t:.1f}s）")

    reset(TSG_GEMINI_MIN_GAP="5", TSG_GEN_PACE="off")
    t = time.time()
    for _ in range(3):
        gp.gate("gemini", "adspower:off2", logf=quiet)
    check(time.time() - t < 0.5, "TSG_GEN_PACE=off 全程关闸")


def main() -> int:
    shutil.rmtree(TMP, ignore_errors=True)
    TMP.mkdir(parents=True, exist_ok=True)
    case_gap_and_limits()
    case_day_cap_marks_ledger()
    case_break()
    case_parallel()
    case_heartbeat()
    case_off_switch()
    print()
    if FAILS:
        print(f"🔴 {len(FAILS)} 项失败：")
        for f in FAILS:
            print("   -", f)
        return 1
    print("✅ 节奏闸门与保活心跳调度正确（按账号记账 / 小时与日上限 / 长休 / 并发串行 / 40 分钟节拍）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
