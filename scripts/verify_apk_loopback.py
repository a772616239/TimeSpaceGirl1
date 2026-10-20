#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""检查 APK 包内 version.txt 的 serverUrl 是不是本机回环地址。

为什么存在：测试包会被分发到别的设备，127.0.0.1/localhost 只有「跑在打包机本机」
才连得回来（还得先 adb reverse）。带回环地址出包 = 白打一版（2026-10-21 实测：
测试服口径曾被定义为 127.0.0.1:8081，包分发出去谁也连不上）。

退出码约定（配合 run_stage.sh --warn-rc 3 出黄灯，不阻断流水线）：
    0  serverUrl 不是回环地址
    3  serverUrl 是回环地址（⚠️ 需关注）
    1  包结构异常（读不到 version.txt / JSON 解析失败 —— 这是真问题，红灯）

用法：verify_apk_loopback.py <apk路径>
"""
from __future__ import annotations

import ipaddress
import json
import sys
import zipfile
from urllib.parse import urlparse

VERSION_PATH = "assets/Android/Resources/version.txt"
LOOPBACK_HOSTS = {"127.0.0.1", "localhost", "0.0.0.0", "::1", "[::1]"}


def main() -> int:
    if len(sys.argv) != 2:
        print(f"用法: {sys.argv[0]} <apk路径>", file=sys.stderr)
        return 1
    apk = sys.argv[1]

    try:
        with zipfile.ZipFile(apk) as zf:
            raw = zf.read(VERSION_PATH).decode("utf-8", errors="replace")
    except KeyError:
        print(f"❌ 包内没有 {VERSION_PATH}（结构异常，走红灯）", file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001
        print(f"❌ 读包失败：{exc}", file=sys.stderr)
        return 1

    try:
        cfg = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"❌ {VERSION_PATH} 不是合法 JSON：{exc}", file=sys.stderr)
        return 1

    server_url = cfg.get("serverUrl") or ""
    host = urlparse(server_url).hostname or ""

    print(f"包内 serverUrl = {server_url or '（空）'}")

    # 回环判断：显式名单 + IPv4/IPv6 回环段兜底（127.0.0.0/8 全段都是回环）
    is_loopback = host in LOOPBACK_HOSTS
    if not is_loopback:
        try:
            is_loopback = ipaddress.ip_address(host).is_loopback  # type: ignore[arg-type]
        except ValueError:
            pass

    if is_loopback:
        print(f"⚠️ serverUrl 指向本机回环地址（{host}）—— 测试包会被分发到别的设备，"
              f"回环地址只有打包机自己连得上，这包大概率白打。"
              f"确认口径：scripts/build_envs.json 的对应环境是否该改成局域网/远端 IP。")
        return 3

    print(f"✅ serverUrl 不是回环地址（{host}），包可分发")
    return 0


if __name__ == "__main__":
    sys.exit(main())
