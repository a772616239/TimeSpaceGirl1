#!/usr/bin/env python3
"""清理世界频道里测试注入的假消息。

为什么需要：`bot fake` 和早期版本的 `bot fake`（硬编码 senderId=10000004）
会把测试发言写进世界队列，客户端里看起来就是「某个真实号在说话」，
而且机器人回复它的那几条也会一起留着，越积越像刷屏。

清理范围：
  1. 指定 uid 发的消息（默认 99990001 假玩家号 + 10000004 旧版冒用的真实号）
  2. 这些消息之后 FOLLOW_SEC 秒内的机器人消息（uid >= 90000000 且不是指定 uid）

⚠️ 只改 Redis 队列，服务端内存里还有一份 MessageCache。要立刻生效得重启游戏服
   （重启会重新从 Redis 加载），否则等进程重启自然生效。

用法：
    python3 clean_fake_chat.py --dry-run          # 只看要删什么
    python3 clean_fake_chat.py                    # 真删
    python3 clean_fake_chat.py --uids 10000004    # 只清某个 uid
    python3 clean_fake_chat.py --redis-port 16379 --server-id 10001

    # 走隧道连测试服时
    TS_REDIS_PORT=16379 TS_SERVER_ID=10001 python3 clean_fake_chat.py --dry-run
"""
import argparse
import base64
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from bot_console import parse_chat_info  # noqa: E402

DEFAULT_UIDS = [99990001, 10000004]
BOT_UID_MIN = 90000000
FOLLOW_SEC = 180


def rcli(port, *args):
    return subprocess.check_output(["redis-cli", "-p", str(port)] + list(args), text=True).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--redis-port", type=int,
                    default=int(os.environ.get("TS_REDIS_PORT", "6379")))
    ap.add_argument("--server-id", default=os.environ.get("TS_SERVER_ID", "10001"))
    ap.add_argument("--uids", default=",".join(str(u) for u in DEFAULT_UIDS),
                    help="要清理的发送者 uid，逗号分隔")
    ap.add_argument("--follow-sec", type=int, default=FOLLOW_SEC,
                    help="假消息之后多少秒内的机器人回复也一并删")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    drop_uids = {int(x) for x in args.uids.split(",") if x.strip()}
    key = "%s:CHAT_QUEUE:world" % args.server_id

    raw = rcli(args.redis_port, "lrange", key, "0", "-1")
    lines = [l for l in raw.split("\n") if l.strip()]
    if not lines:
        print("队列为空：%s" % key)
        return 0

    parsed = []
    for line in lines:
        parts = line.split("#", 2)
        if len(parts) < 3:
            continue
        try:
            info = parse_chat_info(base64.b64decode(parts[2]))
        except Exception:
            continue
        msg = info.get("msg") or ""
        if msg.startswith("0|"):
            msg = msg[2:]
        parsed.append({
            "mid": int(parts[0]) if parts[0].isdigit() else 0,
            "uid": info.get("senderId") or 0,
            "name": info.get("senderName") or "",
            "text": msg,
            "times": info.get("times") or 0,
            "raw": line,
        })

    targets = [p for p in parsed if p["uid"] in drop_uids]
    fake_times = [p["times"] for p in targets]
    # 机器人紧跟着的回话也一起删，否则清完假消息会留下机器人自言自语
    followers = []
    if args.follow_sec > 0:
        for p in parsed:
            if p["uid"] < BOT_UID_MIN or p["uid"] in drop_uids:
                continue
            if any(0 <= (p["times"] - t) <= args.follow_sec * 1000 for t in fake_times):
                followers.append(p)

    seen, to_drop = set(), []
    for p in targets + followers:
        if p["mid"] in seen:
            continue
        seen.add(p["mid"])
        to_drop.append(p)
    to_drop.sort(key=lambda x: x["mid"])

    print("队列 %s 共 %d 条，待删 %d 条（假消息 %d + 机器人跟话 %d）"
          % (key, len(parsed), len(to_drop), len(targets), len(followers)))
    for p in to_drop:
        print("  mid %-4s uid=%-9s %-12s %s"
              % (p["mid"], p["uid"], p["name"], p["text"][:48]))

    if not to_drop:
        return 0
    if args.dry_run:
        print("\n[dry-run] 未删除。去掉 --dry-run 执行。")
        return 0

    removed = 0
    for p in to_drop:
        out = rcli(args.redis_port, "lrem", key, "0", p["raw"])
        removed += int(out or 0)
    left = rcli(args.redis_port, "llen", key)
    print("\n已删除 %d 条，剩余 %s 条。" % (removed, left))
    print("⚠️ 服务端内存里还有一份 MessageCache，重启游戏服后客户端才会看不到。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
