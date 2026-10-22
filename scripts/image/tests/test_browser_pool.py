#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""并行绘制的并发正确性测试（不碰真台账、不启浏览器）。

跑法：
    /Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python \
        scripts/image/tests/test_browser_pool.py

覆盖的四件事，正是 2026-10-22 用户报的三个问题：
  1. 同一个 AdsPower profile 只能被一个任务开画（房租约）——多人抢只成功一个；
  2. 抢不到的人**换一个号**继续画，不是等、也不是挤进去（并行，不串图）；
  3. 额度用尽的号立刻关浏览器 + 记台账（用假 fb 验调用顺序与参数）；
  4. 多进程同时写台账不会丢更新（以前的 read/write 直接覆盖会抹掉封锁）。
"""
from __future__ import annotations

import json
import multiprocessing as mp
import os
import shutil
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
IMAGE_DIR = HERE.parent
ROOT = IMAGE_DIR.parents[1]
sys.path.insert(0, str(IMAGE_DIR))

# 🔴 临时目录必须落在工程内：沙箱 shell 打不开 /tmp（/var/folders 同理），
#    写不进去时 save() 静默失败，测试会变成「全都成功」的假绿。
TMP = ROOT / "_output/art_translate/_tests"
# 🔴 这里**不能**做 rmtree/mkdir：macOS 上 multiprocessing 默认 spawn，子进程会重新导入
#    本模块，模块级清目录会把父进程刚写的台账抹掉（表现成「8 个进程丢了 1 条」的假 bug）。
#    清理与建目录一律放 main()。
os.environ["TSG_LEDGER"] = str(TMP / "ledger.json")
os.environ["TSG_LEDGER_EVENTS"] = str(TMP / "events.jsonl")
os.environ.pop("TSG_LEASE_OWNER", None)

import provider_ledger as pl          # noqa: E402
import gen_chatgpt_web as gw          # noqa: E402

FAILS: list[str] = []


def check(cond: bool, msg: str) -> None:
    print(("  ✅ " if cond else "  🔴 ") + msg)
    if not cond:
        FAILS.append(msg)


# ── 1. 跨进程抢同一个号：只允许一个成功 ──────────────────────────────────────

def _grab(uid: str, owner: str, out_q) -> None:
    ok, info = pl.lease_claim("adspower", uid, owner=owner, note="test")
    if ok:
        time.sleep(0.5)                       # 拿着不放一会儿，模拟正在出图
        pl.lease_release("adspower", uid, owner=owner)
    out_q.put((owner, ok, info.get("held_by")))


def test_mutual_exclusion() -> None:
    print("\n[1] 两个任务同时抢 ktmrjhu")
    q = mp.Queue()
    procs = [mp.Process(target=_grab, args=("ktmrjhu", f"job{i}", q)) for i in (1, 2)]
    for p in procs:
        p.start()
    got = [q.get(timeout=15) for _ in procs]
    for p in procs:
        p.join(timeout=15)
    winners = [g for g in got if g[1]]
    check(len(winners) == 1, f"只有一个任务拿到租约（实际 {got}）")
    loser = [g for g in got if not g[1]]
    check(bool(loser) and loser[0][2], f"失败那方看得到占用者（{loser}）")


# ── 2. 抢不到的人换下一个号，而不是排队干等 ──────────────────────────────────

def test_pick_next() -> None:
    print("\n[2] 被占用的号不进候选，直接派下一个")
    d = {"accounts": {}}
    pl.lease_claim("adspower", "taken", owner="jobA", data=d)
    rows = [{"id": "taken", "cookies": 99}, {"id": "other", "cookies": 3}]
    got = [r["id"] for r in pl.pick(rows, "adspower", max_n=3, data=d, owner="jobB")]
    check(got == ["other"], f"只派没被占的那个（{got}）")
    got_a = [r["id"] for r in pl.pick(rows, "adspower", max_n=3, data=d, owner="jobA")]
    check("taken" in got_a, f"持有者自己还能拿到自己的号（{got_a}）")


# ── 3. 额度用尽：关浏览器 + 记台账 + 放租约 ─────────────────────────────────

class FakeFB:
    def __init__(self) -> None:
        self.stopped: list[str] = []

    def adspower_stop(self, uid: str) -> bool:
        self.stopped.append(uid)
        return True

    def adspower_profiles(self, with_state: bool = False):
        return []

    def adspower_state(self, uid: str):
        return ("inactive", 0)


def test_quota_closes_browser() -> None:
    print("\n[3] 额度用尽 → 关浏览器 + 台账封锁 + 放租约")
    ok, _ = pl.lease_claim("adspower", "k19wnpan", owner="jobC")
    check(ok, "先拿到租约")
    fb = FakeFB()
    gw._release_and_maybe_close(fb, pl, "jobC", "adspower", "k19wnpan", 62001, "quota_exhausted")
    check(fb.stopped == ["k19wnpan"], f"调了 adspower_stop（{fb.stopped}）")
    check("lease" not in (pl.load()["accounts"].get("adspower:k19wnpan") or {}),
          "租约已释放（别的任务可以接着用这个号——等额度恢复）")
    e = pl.mark_exhausted("adspower", "k19wnpan", raw="上限将在 3 小时后重置")
    check(bool(e.get("blocked_until")), f"台账记下恢复时间（{e.get('blocked_until')}）")


# ── 4. 多进程写台账不丢更新 ────────────────────────────────────────────────

def _mark(uid: str) -> None:
    pl.mark_exhausted("adspower", uid, raw="上限将在 2 小时后重置")


def test_no_lost_update() -> None:
    print("\n[4] 8 个进程同时写台账，封锁一个都不能丢")
    uids = [f"acc{i}" for i in range(8)]
    procs = [mp.Process(target=_mark, args=(u,)) for u in uids]
    for p in procs:
        p.start()
    for p in procs:
        p.join(timeout=20)
    data = pl.load()
    missing = [u for u in uids if not data["accounts"].get(f"adspower:{u}", {}).get("blocked_until")]
    check(not missing, f"8 条封锁全在（丢的：{missing}）")


# ── 5. 「钉住的浏览器」按 owner 分文件 ─────────────────────────────────────

def test_pin_per_owner() -> None:
    print("\n[5] 每轮 build 各自钉一台，互不覆盖")
    gw.PIN_DIR = TMP / "_pins"
    gw.save_pin("jenkins-TS-Art-Translate-58", "adspower", "ktmrjhu", 62001)
    gw.save_pin("jenkins-TS-Art-Translate-59", "adspower", "k1hiv2p8", 62002)
    a = gw.load_pin("jenkins-TS-Art-Translate-58")
    b = gw.load_pin("jenkins-TS-Art-Translate-59")
    check(a.get("id") == "ktmrjhu" and b.get("id") == "k1hiv2p8", f"A={a.get('id')} B={b.get('id')}")
    gw.clear_pin("jenkins-TS-Art-Translate-58")
    check(not gw.load_pin("jenkins-TS-Art-Translate-58"), "清掉 A 不影响 B")
    check(gw.load_pin("jenkins-TS-Art-Translate-59").get("id") == "k1hiv2p8", "B 还在")


def main() -> int:
    shutil.rmtree(TMP, ignore_errors=True)
    TMP.mkdir(parents=True, exist_ok=True)
    test_mutual_exclusion()
    test_pick_next()
    test_quota_closes_browser()
    test_no_lost_update()
    test_pin_per_owner()
    print()
    if FAILS:
        print(f"🔴 {len(FAILS)} 项失败：")
        for f in FAILS:
            print(f"   - {f}")
        return 1
    print("✅ 全部通过（并发租约 / 换号 / 用完即关 / 台账不丢更新 / 按 owner 钉号）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
