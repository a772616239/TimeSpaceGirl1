#!/usr/bin/env python3
"""手工实跑：两个「构建」同时开画，验证不会挤进同一个 AdsPower 号。

为什么要有这个脚本：单元测试（test_browser_pool.py / test_fallback_rotation.py）
里的 AdsPower 是假的；2026-10-22 那个线上症状（两个任务同时跑 ⇒ 同一个 profile 被
反复打开、两边各报一次「额度用尽」）恰恰出在**真的** `browser/start`：它对着一个
已经运行的 profile 再 start 一次，会把同一个 debug_port 原样交回来。这条只有在真
客户端上跑一遍才认。

它做什么：
  ① 起两个子进程，各带一个不同的 owner（模拟 build #A / #B），同时冲进
     `gen_chatgpt_web.try_fallback` 的第 ② 步（AdsPower 现开一个 profile）；
  ② 抢租约、`adspower_state` / `adspower_start` / `adspower_stop`、台账全是**真代码**；
  ③ 断言两边拿到的 user_id 不同（= 一人一台浏览器，不再共享同一个 ChatGPT 标签页）。

它不做什么（刻意打桩，避免误伤）：
  · `run_on_port`（真正画画那一步）打桩成立刻返回 rc=3 ⇒ **不画画、不消耗额度**；
    返回 3 走的是「不可用」分支，所以浏览器会被当场关掉、租约被释放，收尾自净。
  · `find_sunbrowser_ports` 打桩成空表 ⇒ 不去接用户手上已经开着的浏览器。
  · `load_state` / `save_state` / `record_key` 打桩成空操作 ⇒ 不往真
    `provider_state.json` 里写「rc=3」，免得污染下一轮换号排序。
  · 台账指到临时文件（`TSG_LEDGER`）⇒ 真 `quota_ledger.json` 一个字节都不动。

前置条件：AdsPower 客户端开着（本地 API 127.0.0.1:50325）。

跑法：
  /Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python \\
      scripts/image/tests/live_parallel_claim.py
  # 指定号池（默认取台账里没封锁的前两个）：
  ... live_parallel_claim.py --profiles k12w7kmd,k19wnpan
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = ROOT / "scripts" / "image"
WORK = ROOT / "_output/art_translate/_tests/live_parallel"


# ── 子进程：真的走一遍换号链第 ② 步 ─────────────────────────────────────────
def run_worker(owner: str, profiles: str, tag: str) -> int:
    sys.path.insert(0, str(HERE))
    import gen_chatgpt_web as gw                     # noqa: E402
    import provider_ledger as pld                    # noqa: E402

    lines: list[str] = []

    def _log(msg: str) -> None:
        lines.append(str(msg))
        print(f"[{tag}] {msg}", flush=True)

    gw.log = _log                                    # 收日志（下面要解析抢到了哪个号）

    def _fake_draw(args, port, image, prompt_file, out, node, pw):
        _log(f"   （打桩）假装在 CDP {port} 上画了一张 → rc=3，不消耗额度")
        time.sleep(1.0)                              # 留一点重叠窗口，逼出并发争抢
        return gw.RC_WARN

    gw.run_on_port = _fake_draw
    gw.find_sunbrowser_ports = lambda exclude=None: []       # 不碰用户开着的那台
    gw.load_state = lambda: {}
    gw.save_state = lambda state: {}
    gw.record_key = lambda *a, **k: None

    image = WORK / "src.png"
    prompt = WORK / "prompt.txt"
    out = WORK / f"out_{tag}.png"

    args = argparse.Namespace(
        keep_browser_on_exhaust=False,
        no_pin=True,
        port=0,
        reuse_cdp=False,
        fallback_budget=180,
        ignore_ledger=False,
        adspower_profiles=profiles,
        adspower_max_profiles=3,                     # 允许「别人抢走了就换下一个」
        adspower_stop_when_done=True,
    )
    started = time.time()
    rc = gw.try_fallback(args, image, prompt, out, "node", "pw",
                         pl=pld, owner=owner, pin={})
    print(json.dumps({
        "tag": tag, "owner": owner, "rc": rc,
        "secs": round(time.time() - started, 1),
        "launched": _launched_uids(lines),
        "skipped": [l.strip() for l in lines if "不抢别人的浏览器" in l],
    }, ensure_ascii=False), flush=True)
    return 0


def _launched_uids(lines: list[str]) -> list[str]:
    """从日志里抠出「这个进程实际用上了哪几个号」。"""
    out = []
    for l in lines:
        for pat in ("已启动（CDP", "已经开着（CDP"):
            if pat in l:
                uid = l.strip().split()[0]
                if uid and uid not in out:
                    out.append(uid)
    return out


# ── 父进程：并发拉起两个 worker，比对结果 ───────────────────────────────────
def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--profiles", default="", help="逗号分隔；空则自动取台账里可用前两个")
    ap.add_argument("--worker", default="", help=argparse.SUPPRESS)
    ap.add_argument("--owner", default="", help=argparse.SUPPRESS)
    ap.add_argument("--tag", default="", help=argparse.SUPPRESS)
    a = ap.parse_args()
    if a.worker:
        return run_worker(a.owner, a.profiles, a.tag)

    sys.path.insert(0, str(HERE))
    import provider_ledger as pld
    import find_browser_cdp as fb

    if not fb.adspower_alive():
        print("🔴 AdsPower 本地 API 不可达（客户端没开），这个实跑做不了")
        return 2

    profiles = a.profiles
    if not profiles:
        acc = (pld.load().get("accounts") or {})
        ids = [str(e.get("id")) for k, e in acc.items()
               if e.get("kind") == "adspower" and not e.get("blocked_until")]
        profiles = ",".join(ids[:2])
    if len([x for x in profiles.split(",") if x.strip()]) < 2:
        print(f"🔴 至少要有两个号才能验证并发，当前：{profiles or '(空)'}")
        return 2

    WORK.mkdir(parents=True, exist_ok=True)
    for name in ("src.png", "prompt.txt"):
        (WORK / name).write_bytes(b"x" if name.endswith(".png") else b"test prompt")
    tmp_ledger = WORK / "ledger.json"
    tmp_events = WORK / "events.jsonl"
    if tmp_ledger.exists():
        tmp_ledger.unlink()

    env = {**os.environ,
           "TSG_LEDGER": str(tmp_ledger),
           "TSG_LEDGER_EVENTS": str(tmp_events),
           "TSG_LEASE_TTL": "300"}
    me, py = Path(__file__).resolve(), sys.executable
    print(f"号池：{profiles}　台账：{tmp_ledger}")

    procs = []
    for tag, owner in (("A", "live-A"), ("B", "live-B")):
        p = subprocess.Popen([py, str(me), "--worker", "1", "--owner", owner,
                              "--tag", tag, "--profiles", profiles],
                             env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True)
        procs.append((tag, p, []))
        time.sleep(0.4)                              # 错开 0.4s 起跑，仍然大幅重叠

    results = {}
    for tag, p, _ in procs:
        out, _ = p.communicate(timeout=420)
        for line in out.splitlines():
            print(f"  | {line}")
            if line.startswith('{"tag"'):
                results[tag] = json.loads(line)

    # 收尾自净：万一哪个子进程死在半路，把它开起来的号关掉
    for tag, r in results.items():
        for uid in r.get("launched") or []:
            st, _p = fb.adspower_state(uid)
            if st == "active":
                print(f"  🧹 兜底关闭 {uid}（{tag} 没自己关）")
                fb.adspower_stop(uid)

    print("\n" + "=" * 60)
    ok = True
    if len(results) != 2:
        print(f"🔴 只有一个 worker 报回结果（{list(results)}）")
        ok = False
    else:
        la, lb = results["A"].get("launched") or [], results["B"].get("launched") or []
        print(f"A 用到的号：{la or '(无)'}　rc={results['A']['rc']}　{results['A']['secs']}s")
        print(f"B 用到的号：{lb or '(无)'}　rc={results['B']['rc']}　{results['B']['secs']}s")
        if not la or not lb:
            print("🔴 有 worker 一个号都没开起来（看上面日志里的启动失败原因）")
            ok = False
        else:
            first_a, first_b = la[0], lb[0]
            if first_a == first_b:
                print(f"🔴 两个任务抢到了同一个号 {first_a} —— 这就是要修的那个 bug")
                ok = False
            else:
                print(f"✅ 两个任务各拿一台：A={first_a}／B={first_b}（互不干扰）")
            if results["B"].get("skipped"):
                print(f"✅ B 撞到 A 的租约并让开了：{results['B']['skipped'][0]}")
    print("=" * 60)
    print("✅ 实跑通过：并发时不会挤进同一个 AdsPower 号" if ok else "🔴 实跑不通过（见上）")
    if ok:
        shutil.rmtree(WORK, ignore_errors=True)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
