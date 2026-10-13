#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
提升 Unity 工程的 Android versionCode / versionName。

背景（本项目关键坑）：
    GUI 打包走 Assets/Scripts/Editor/GameEditor/FrameTool/BuildWindow.cs:449，
    那里会 `PlayerSettings.Android.bundleVersionCode++` 自动自增；
    而 CLI 的 Assets/Editor/CLIBuilder.cs **只读不自增**。
    于是用 CLI 打出多个包时 versionCode 全都是同一个值（当前 62），
    传到 Google Play production 轨道必然被拒（要求严格递增）。
    本脚本就是补这个洞：在 CLI 打包前把号提上去。

直接改 ProjectSettings/ProjectSettings.asset 里的 `AndroidBundleVersionCode: N`，
该字段是 Unity 纯文本 YAML 里的一个整数，改动可被 Unity 正常读取，
也随时能 `git checkout` 回滚。

用法：
    # 看当前版本
    python3 scripts/bump_version.py --show

    # versionCode +1（最常用）
    python3 scripts/bump_version.py --bump

    # 直接设成指定值
    python3 scripts/bump_version.py --set-code 70

    # 同时把 versionName 的 patch 位 +1（1.2.45 -> 1.2.46）
    python3 scripts/bump_version.py --bump --bump-name

退出码：0 成功 / 2 失败
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PS_ASSET = PROJECT_ROOT / "ProjectSettings" / "ProjectSettings.asset"

RE_CODE = re.compile(r"^(\s*AndroidBundleVersionCode:\s*)(\d+)(\s*)$", re.MULTILINE)
RE_NAME = re.compile(r"^(\s*bundleVersion:\s*)(\S+)(\s*)$", re.MULTILINE)


def die(msg: str) -> None:
    sys.stderr.write(f"[ERROR] {msg}\n")
    sys.exit(2)


def read_current(text: str) -> tuple[int | None, str | None]:
    m_code = RE_CODE.search(text)
    m_name = RE_NAME.search(text)
    code = int(m_code.group(2)) if m_code else None
    name = m_name.group(2) if m_name else None
    return code, name


def bump_name(name: str) -> str:
    """versionName 末位 +1：1.2.45 -> 1.2.46"""
    parts = name.split(".")
    if not parts:
        return name
    try:
        parts[-1] = str(int(parts[-1]) + 1)
    except ValueError:
        return name
    return ".".join(parts)


def main() -> int:
    ap = argparse.ArgumentParser(description="提升 Unity Android versionCode / versionName")
    ap.add_argument("--show", action="store_true", help="只显示当前版本")
    ap.add_argument("--bump", action="store_true", help="versionCode +1")
    ap.add_argument("--set-code", type=int, default=None, help="把 versionCode 设为指定值")
    ap.add_argument("--bump-name", action="store_true", help="同时把 versionName 末位 +1")
    ap.add_argument("--set-name", default=None, help="把 versionName 设为指定值")
    args = ap.parse_args()

    if not PS_ASSET.is_file():
        die(f"找不到 {PS_ASSET}")

    text = PS_ASSET.read_text(encoding="utf-8")
    cur_code, cur_name = read_current(text)
    if cur_code is None:
        die("在 ProjectSettings.asset 中未找到 AndroidBundleVersionCode 字段，文件结构可能已变")

    if args.show or not (args.bump or args.set_code is not None or args.bump_name or args.set_name):
        print(f"versionName (bundleVersion)   = {cur_name}")
        print(f"versionCode (AndroidBundleVersionCode) = {cur_code}")
        if not args.show:
            print("（未指定动作，仅显示。用 --bump 或 --set-code 修改）")
        return 0

    new_code = cur_code
    if args.set_code is not None:
        new_code = args.set_code
    elif args.bump:
        new_code = cur_code + 1

    new_name = cur_name
    if args.set_name:
        new_name = args.set_name
    elif args.bump_name and cur_name:
        new_name = bump_name(cur_name)

    if new_code <= cur_code:
        die(f"新 versionCode {new_code} 未大于当前 {cur_code}，Google Play 会拒绝。请给更大的值。")

    new_text = RE_CODE.sub(lambda m: f"{m.group(1)}{new_code}{m.group(3)}", text, count=1)
    if new_name and new_name != cur_name:
        new_text = RE_NAME.sub(lambda m: f"{m.group(1)}{new_name}{m.group(3)}", new_text, count=1)

    PS_ASSET.write_text(new_text, encoding="utf-8")

    print(f"versionCode : {cur_code} -> {new_code}")
    if new_name != cur_name:
        print(f"versionName : {cur_name} -> {new_name}")
    print(f"已写回 {PS_ASSET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
