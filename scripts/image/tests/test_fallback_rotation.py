#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""换号链的离线仿真：不启浏览器、不烧额度，验证「用完即关 → 记台账 → 开下一个」的编排。

为什么要这个仿真：这条链是**唯一**会消耗包月额度的地方，出一次错就是白烧一张图 + 9 分钟。
单元测试覆盖不了它（要 AdsPower + ChatGPT 登录态），所以把 fb / run_on_port / wait_cdp
全部打桩，只验「调度与记账」这部分逻辑，真出图仍然由线上构建兜。

跑法：
    /Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python \
        scripts/image/tests/test_fallback_rotation.py
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
IMAGE_DIR = HERE.parent
ROOT = IMAGE_DIR.parents[1]
sys.path.insert(0, str(IMAGE_DIR))

TMP = ROOT / "_output/art_translate/_tests_fallback"
shutil.rmtree(TMP, ignore_errors=True)
TMP.mkdir(parents=True, exist_ok=True)
os.environ["TSG_LEDGER"] = str(TMP / "ledger.json")
os.environ["TSG_LEDGER_EVENTS"] = str(TMP / "events.jsonl")
os.environ["TSG_LEASE_OWNER"] = "art-translate-58"

import provider_ledger as pl          # noqa: E402
import gen_chatgpt_web as gw          # noqa: E402

FAILS: list[str] = []


def check(cond: bool, msg: str) -> None:
    print(("  ✅ " if cond else "  🔴 ") + msg)
    if not cond:
        FAILS.append(msg)


class FakeFB:
    """假 AdsPower：三个号，谁被 start 过就记下来。"""

    def __init__(self, uids=("a1", "a2", "a3")) -> None:
        self.ports = {u: 61001 + i for i, u in enumerate(uids)}
        self.started: list[str] = []
        self.stopped: list[str] = []

    def adspower_alive(self) -> bool:
        return True

    def adspower_profiles(self, with_state: bool = False):
        return [{"user_id": u, "cookies": 9, "mtime": 0} for u in self.ports]

    def adspower_state(self, uid: str):
        return ("inactive", 0)

    def adspower_start(self, uid: str):
        self.started.append(uid)
        return True, self.ports[uid], "ok"

    def adspower_stop(self, uid: str) -> bool:
        self.stopped.append(uid)
        return True


def make_args() -> argparse.Namespace:
    return argparse.Namespace(
        owner="art-translate-58", port=9333, reuse_cdp=False, no_pin=False,
        ignore_ledger=False, adspower_profiles="", adspower_max_profiles=3,
        fallback_budget=600, keep_browser_on_exhaust=False,
        adspower_stop_when_done=False, auto_fallback=True, lease_ttl=1200,
    )


def run_case(name: str, quota_uids: set[str], pre_leased: list[str] | None = None):
    print(f"\n[{name}]")
    pl.lease_release(owner="art-translate-58")
    for u in list((pl.load().get("accounts") or {})):
        pass
    fb = FakeFB()
    gw._fb = lambda: fb
    gw.wait_cdp = lambda port, deadline: True
    gw.find_sunbrowser_ports = lambda exclude=None: []
    gw.cached_order = lambda kind: []
    gw.load_state = lambda: {}
    gw.save_state = lambda s: None
    gw.record_key = lambda *a, **k: None
    gw.PIN_DIR = TMP / "_pins"
    gw.clear_pin("art-translate-58")      # 每个场景都从「没有钉住」开始

    out = TMP / "gen.png"
    out.parent.mkdir(parents=True, exist_ok=True)

    def fake_run_on_port(args, port, image, prompt_file, out_path, node, pw):
        uid = {v: k for k, v in fb.ports.items()}.get(port, "?")
        if uid in quota_uids:
            Path(str(out_path) + ".fail.json").write_text(json.dumps(
                {"reason": "quota_exhausted", "message": "上限将在 4 小时后重置",
                 "reset": "4 小时后"}), encoding="utf-8")
            return gw.RC_QUOTA
        Path(out_path).write_bytes(b"\x89PNG fake")
        return gw.RC_OK

    gw.run_on_port = fake_run_on_port

    for u in (pre_leased or []):
        pl.lease_claim("adspower", u, owner="someone-else")

    args = make_args()
    rc = gw.try_fallback(args, TMP / "ref.png", TMP / "prompt.txt", out, "node", "pw")
    return rc, fb


def main() -> int:
    # ── 场景 1：第一个号额度用尽 → 关掉、记账、接着开下一个 ──────────────────
    rc, fb = run_case("第一个号额度用尽 → 关掉换下一个", {"a1"})
    check(rc == gw.RC_OK, f"最终拿到图（rc={rc}）")
    check(fb.started[:2] == ["a1", "a2"], f"按序开了 a1 → a2（实际 {fb.started}）")
    check(fb.stopped == ["a1"], f"额度用尽的 a1 立刻被关掉（{fb.stopped}）")
    e = pl.get("adspower", "a1")
    check(bool(e.get("blocked_until")), f"a1 记进台账，恢复时间 {e.get('blocked_until')}")
    pin = gw.load_pin("art-translate-58")
    check(pin.get("id") == "a2", f"本轮钉住成功的那台 a2（{pin.get('id')}）")
    acct = pl.load()["accounts"].get("adspower:a1") or {}
    check("lease" not in acct, "a1 的租约已放掉（别的任务可以等额度恢复后接手）")

    # ── 场景 2：a1 正被别的任务占着 → 不许挤进去，直接开 a2 ────────────────
    pl.LEDGER.unlink(missing_ok=True)
    rc2, fb2 = run_case("a1 被别的任务占着 → 不抢，直接开下一个", set(), pre_leased=["a1"])
    check("a1" not in fb2.started, f"没有去启动被占用的 a1（启动过 {fb2.started}）")
    check(rc2 == gw.RC_OK and fb2.started == ["a2"],
          f"直接用了没被占的 a2（rc={rc2} 启动 {fb2.started}）")

    # ── 场景 3：所有号都额度用尽 → 不关重复开，直接失败并各自记账 ────────────
    pl.LEDGER.unlink(missing_ok=True)
    rc3, fb3 = run_case("全部号额度用尽 → 逐个关掉 + 各自记账", {"a1", "a2", "a3"})
    check(rc3 == gw.RC_QUOTA, f"如实返回额度用尽（rc={rc3}）")
    check(sorted(fb3.stopped) == ["a1", "a2", "a3"],
          f"三台都关了（顺序可以是先钉住那台，实际 {fb3.stopped}）")
    blocked = [u for u in ("a1", "a2", "a3")
               if (pl.load()["accounts"].get(f"adspower:{u}") or {}).get("blocked_until")]
    check(blocked == ["a1", "a2", "a3"], f"三台都记了恢复时间（{blocked}）")

    print()
    if FAILS:
        print(f"🔴 {len(FAILS)} 项失败")
        return 1
    print("✅ 换号链编排正确（用完即关 / 记账 / 换下一个 / 不抢别人的号）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
