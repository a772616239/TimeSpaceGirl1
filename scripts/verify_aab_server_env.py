#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_aab_server_env.py —— 核验 AAB/APK 里**实际连的服务器**是哪一个（离线、零依赖）

为什么需要它
------------
`scripts/apply_build_env.py` 负责在 Unity 启动前把 serverUrl 写进
`Assets/Resources/version.txt`，但「脚本说改了」和「包里确实是那个值」是两件事：
Unity 可能读的是 Library 里的旧 TextAsset 缓存，也可能打包中途有人手工改了文件。
本项目对出包口径（isOpenGM / 16KB）一直是**解包核验**，这条同样要落到产物上。

原理
----
Unity 把 `Assets/Resources/version.txt` 当 TextAsset 原样打进包，且**不是**塞在
SerializedFile 里，而是以独立文件的形式存在（实测路径）：

  AAB : base/assets/Android/Resources/version.txt
  APK : assets/Android/Resources/version.txt

所以直接 `unzip -p` 出来解析 JSON 即可，不需要解析 Unity 资源格式。

用法
----
  python3 scripts/verify_aab_server_env.py <aab|apk> --expect-env 正式服
  python3 scripts/verify_aab_server_env.py <aab|apk> --expect-server-url http://127.0.0.1:8081/
  python3 scripts/verify_aab_server_env.py <aab|apk>              # 只报告，不判错

比对口径
--------
  serverUrl 严格相等（这是「连哪个服」的唯一判据）；
  resUrl 严格相等（热更资源站，填错就是启动后拉不到 AB）；
  其余字段（channel/serverPathType/subChannel…）只报告不判错 —— 它们不影响连服。

退出码：0 通过（或只报告）；1 不符；2 用法/读不到包内文件
"""
import argparse
import json
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENVS_FILE = ROOT / "scripts" / "build_envs.json"

# 包内可能的路径（AAB 带 base/ 前缀）
CANDIDATE_PATHS = [
    "base/assets/Android/Resources/version.txt",
    "assets/Android/Resources/version.txt",
]


def die(msg: str, code: int = 2) -> "None":
    print(f"❌ {msg}", file=sys.stderr)
    sys.exit(code)


def load_envs() -> dict:
    if not ENVS_FILE.is_file():
        die(f"缺少环境表：{ENVS_FILE}")
    data = json.loads(ENVS_FILE.read_text(encoding="utf-8"))
    return {k: v for k, v in (data.get("envs") or {}).items() if not k.startswith("_")}


def read_version_from_package(path: Path) -> tuple:
    """返回 (包内 JSON dict, 命中的路径)。"""
    if not path.is_file():
        die(f"找不到产物：{path}")
    try:
        with zipfile.ZipFile(path) as z:
            names = set(z.namelist())
            for cand in CANDIDATE_PATHS:
                if cand in names:
                    raw = z.read(cand).decode("utf-8", errors="replace")
                    try:
                        obj = json.loads(raw)
                    except json.JSONDecodeError as e:
                        die(f"{cand} 不是合法 JSON：{e}")
                    if not isinstance(obj, dict):
                        die(f"{cand} 顶层不是对象")
                    return obj, cand
    except zipfile.BadZipFile:
        die(f"{path} 不是 zip/aab/apk：文件损坏或格式不对")
    die(f"包内找不到 version.txt（找过 {', '.join(CANDIDATE_PATHS)}）—— 打包时 Resources 目录漏了？")


def main() -> int:
    p = argparse.ArgumentParser(
        description="核验 AAB/APK 包内实际连接的服务器（读 scripts/build_envs.json）")
    p.add_argument("artifact", help="AAB 或 APK 路径")
    p.add_argument("--expect-env", default="", help="期望环境名（build_envs.json 的 key）")
    p.add_argument("--expect-server-url", default="", help="直接给期望的 serverUrl（覆盖 --expect-env）")
    args = p.parse_args()

    artifact = Path(args.artifact)
    cur, hit = read_version_from_package(artifact)

    server_url = str(cur.get("serverUrl"))
    res_url = str(cur.get("resUrl"))
    print(f"  包内文件：{hit}")
    print(f"  serverUrl      = {server_url}")
    print(f"  resUrl         = {res_url}")
    print(f"  channel        = {cur.get('channel')}")
    print(f"  serverPathType = {cur.get('serverPathType')}")

    envs = load_envs()
    matched = [n for n, c in envs.items() if str(c.get("serverUrl")) == server_url]
    print(f"  对应环境       = {'、'.join(matched) if matched else '（不在环境表里）'}")

    expect_url = args.expect_server_url
    expect_name = args.expect_env
    if not expect_url and expect_name:
        if expect_name not in envs:
            print(f"❌ 期望环境 `{expect_name}` 不在 {ENVS_FILE.name} 里，可选：", file=sys.stderr)
            for n in envs:
                print(f"     - {n}", file=sys.stderr)
            return 2
        expect_url = str(envs[expect_name].get("serverUrl"))
        expect_res = envs[expect_name].get("resUrl")
    else:
        expect_res = None

    if not expect_url:
        print("  （未给期望值，只报告不判错）")
        return 0

    ok = True
    if server_url == expect_url:
        print(f"  ✓ serverUrl 与期望一致（{expect_name or expect_url}）")
    else:
        print(f"  ✗ serverUrl 不符：包内 {server_url} ≠ 期望 {expect_url}"
              f"{f'（环境 {expect_name}）' if expect_name else ''}")
        ok = False

    if expect_res is not None:
        if res_url == str(expect_res):
            print(f"  ✓ resUrl 与期望一致（{expect_res}）")
        else:
            print(f"  ✗ resUrl 不符：包内 {res_url} ≠ 期望 {expect_res}")
            ok = False

    if not ok:
        print("❌ 这个包连的不是期望的服务器 —— 拒绝用它发版/交付", file=sys.stderr)
        return 1
    print("✅ 服务器环境核验通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
