#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""额度封锁的回归测试：解析恢复时刻 / 冷却期不许新建对话 / 端口 → 账号归一。

为什么单独测这个（2026-10-30 那次封号的教训）：
  · 站点给的是「22:54までお待ちください」——时刻前面没有「約」，四类正则全不认，
    于是落到 6 小时兜底：22:40 撞上限被记成 04:40 恢复，白等一夜；
  · 换号链 ① 只知道端口，台账把它记成 cdp:<端口> ⇒ 同一个号换个端口就是「新号」，
    它自己的封锁标记全失效 —— 封号那天它就是这样继续被用了 12 张；
  · 全部号都被封锁时旧逻辑「赌一把」，而那正是 Google 判「绕过用量限制」的动作。

跑法：
    /Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python \
        scripts/image/tests/test_ledger_guard.py
"""
from __future__ import annotations

import datetime as dt
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
IMAGE_DIR = HERE.parent
ROOT = IMAGE_DIR.parents[1]
sys.path.insert(0, str(IMAGE_DIR))

TMP = Path(tempfile.mkdtemp(prefix="guard_test_"))
os.environ["TSG_LEDGER"] = str(TMP / "ledger.json")
os.environ.pop("TSG_ALLOW_GAMBLE", None)

import provider_ledger as pl     # noqa: E402

PY = sys.executable
FAILS: list[str] = []


def check(cond: bool, msg: str) -> None:
    print(("  ✅ " if cond else "  🔴 ") + msg)
    if not cond:
        FAILS.append(msg)


def seed_blocked(uid: str, hours: float = 3.0) -> None:
    when = (dt.datetime.now() + dt.timedelta(hours=hours)).strftime("%Y-%m-%dT%H:%M:%S")
    (TMP / "ledger.json").write_text(json.dumps({"version": 1, "accounts": {
        f"adspower:{uid}": {"kind": "adspower", "id": uid, "state": "exhausted",
                            "blocked_until": when, "reset_basis": "until"}}},
        ensure_ascii=False), encoding="utf-8")


def case_parse_reset() -> None:
    print("\n[站点恢复时刻解析]")
    base = dt.datetime(2026, 10, 30, 22, 40, 0)
    cases = [
        # 真实判罚原文（日文界面）：抓不到 22:54 就只能按 6h 兜底
        ("画像生成の上限に達しました。さらに利用するには、無料のPlusトライアルを開始するか、"
         "22:54までお待ちください。", "until", 14),
        ("上限已用完，22:54 之后恢复", "until", 14),
        ("limit reached, resets at 22:54", "clock", 14),
        ("上限は 2 時間後にリセットされます", "hours", 120),
        ("明日の 16:54 に無料枠が回復します", "tomorrow", 18 * 60 + 14),
        # 比例不是时间
        ("3:4 竖构图，注意上限", "none", -1),
    ]
    for text, want_basis, want_min in cases:
        when, basis = pl.parse_reset(text, base)
        got = int((when - base).total_seconds() // 60) if when else -1
        check(basis == want_basis and got == want_min,
              f"{text[:38]!r} → {basis}/{got}min（期望 {want_basis}/{want_min}min）")

    print("\n[兜底必须是 6 小时，不是 120 分钟]")
    check(pl.DEFAULT_BLOCK_HOURS == 6, f"DEFAULT_BLOCK_HOURS={pl.DEFAULT_BLOCK_HOURS}")
    check(pl.DEFAULT_BLOCK_HOURS * 60 != pl.DEFAULT_UNUSABLE_MINUTES,
          "额度兜底(6h) 与 rc=1/3 冷却(120m) 是两个口径，别混")


def case_pick_no_gamble() -> None:
    print("\n[全封锁时默认不赌]")
    base = dt.datetime.now()
    data = {"accounts": {
        "adspower:x": {"state": "exhausted",
                       "blocked_until": (base + dt.timedelta(hours=9)).strftime("%Y-%m-%dT%H:%M:%S")},
        "adspower:y": {"state": "exhausted",
                       "blocked_until": (base + dt.timedelta(hours=2)).strftime("%Y-%m-%dT%H:%M:%S")}}}
    rows = [{"id": "x", "cookies": 50}, {"id": "y", "cookies": 40}]
    check(pl.pick(rows, "adspower", max_n=2, data=data, base=base) == [],
          "默认返回空（冷却期内的号不许开新对话）")
    g = pl.pick(rows, "adspower", max_n=2, data=data, base=base, allow_gamble=True)
    check(len(g) == 1 and g[0]["id"] == "y" and g[0].get("gamble"),
          "allow_gamble=True 才挑最快恢复的硬试（人工逃生口）")


def case_port_identity() -> None:
    print("\n[端口 → 账号归一]")
    import gen_chatgpt_web as gw

    class FakeFB:
        @staticmethod
        def adspower_uid_for_port(_p):
            return "kvrvx5h"

    check(gw._profile_for_port(FakeFB, 51245) == "kvrvx5h",
          "优先用 adspower_uid_for_port（离线、准）")

    class LegacyFB:
        @staticmethod
        def adspower_profiles():
            return [{"user_id": "abc"}]

        @staticmethod
        def adspower_state(_u):
            return "Active", 55555

    check(gw._profile_for_port(LegacyFB, 55555) == "abc",
          "退路仍可用 AdsPower API 反查")
    check(gw._profile_for_port(FakeFB, 0) == "", "端口为 0 直接返回空，不乱猜")


def case_gen_gemini_blocked() -> None:
    print("\n[gen_gemini：封锁期拒绝开新对话]")
    seed_blocked("demo1", 3)
    p = TMP / "p.txt"
    p.write_text("你好\n", encoding="utf-8")
    r = subprocess.run([PY, str(IMAGE_DIR / "gen_gemini.py"),
                        "--account", "adspower:demo1",
                        "--prompt-file", str(p), "--out", str(TMP / "o.png"),
                        "--port", "59999"],
                       capture_output=True, text=True, timeout=120)
    check(r.returncode == 7, f"退出码 7（封锁），实际 {r.returncode}")
    check("不开新对话" in (r.stdout + r.stderr), "日志里说清了为什么不出图")


def case_entry_guard() -> None:
    print("\n[gen_chatgpt_web：--reuse-cdp 指向被封锁的号 → 不画]")
    import gen_chatgpt_web as gw

    seed_blocked("kvrvx5h", 7 * 24)
    orig = gw._profile_for_port
    gw._profile_for_port = lambda _fb, _p: "kvrvx5h"      # 假装 59999 是这个号
    try:
        img = TMP / "x.png"
        img.write_bytes(b"\x89PNG\r\n\x1a\n")             # 只要能过 is_file()
        rc = gw.main(["--image", str(img), "--prompt-file", str(TMP / "p.txt"),
                      "--out", str(TMP / "out.png"), "--reuse-cdp", "--port", "59999",
                      "--timeout", "5"])
    finally:
        gw._profile_for_port = orig
    check(rc == gw.RC_WARN, f"返回 RC_WARN（{gw.RC_WARN}），实际 {rc}")
    check(not (TMP / "out.png").exists(), "没有落任何图（连对话都没开）")


def case_render_folds_junk() -> None:
    print("\n[台账渲染：端口冒充账号的垃圾行必须折叠]")
    data = {"accounts": {
        # 旧口径：端口当账号
        "cdp:49951": {"kind": "cdp", "id": "49951", "state": "unknown"},
        # 端口被当成 adspower uid 写进去（AdsPower uid 一定是字母数字混排）
        "adspower:54808": {"kind": "adspower", "id": "54808", "state": "unknown"},
        # 真账号
        "adspower:ktmrjhu": {"kind": "adspower", "id": "ktmrjhu", "state": "ok",
                             "ok_count": 14},
        # 仍被封的旧口径条目要照旧显示（不能「明明在封锁却看不见」）
        "cdp:60001": {"kind": "cdp", "id": "60001", "state": "exhausted",
                      "blocked_until": "2099-01-01T00:00:00"},
    }}
    txt = pl.render(data=data)
    check("49951" not in txt, "cdp:<端口> 被折叠")
    check("54808" not in txt, "adspower:<纯数字端口> 被折叠")
    check("ktmrjhu" in txt, "真账号还在")
    check("60001" in txt, "仍被封的旧条目不被藏起来")
    check("条历史垃圾记录已折叠" in txt, "折叠数量有一行说明")
    full = pl.render(data=data, all_rows=True)
    check("49951" in full and "54808" in full, "--all 能展开全部")


def main() -> int:
    print(f"临时目录：{TMP}")
    case_parse_reset()
    case_pick_no_gamble()
    case_port_identity()
    case_gen_gemini_blocked()
    case_entry_guard()
    case_render_folds_junk()
    print()
    if FAILS:
        print(f"🔴 {len(FAILS)} 项失败：")
        for m in FAILS:
            print("   -", m)
        return 1
    print("✅ 额度封锁口径正确（恢复时刻 / 6h 兜底 / 默认不赌 / 前端归一 / 入口拦截 / 垃圾行折叠）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
