#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
apply_build_env.py —— 打包前把「连哪个服务器」写进包内默认配置（Assets/Resources/version.txt）

为什么需要这一层
----------------
出包连哪个服**完全由 `Assets/Resources/version.txt` 的 serverUrl/resUrl 决定**，
而这条链路历史上从来没人动过它：CLIBuilder / aab_release.sh / build_apk.sh 都不碰这个文件，
所以「打正式服包还是测试服包」过去只能靠人肉改文件 + 记得改回来，漏一次就是发错服。

现在把地址收进 `scripts/build_envs.json`（唯一真源），由本脚本在 **Unity 启动之前**注入：

    python scripts/apply_build_env.py apply 正式服    # 注入（首次会备份原文件）
    python scripts/apply_build_env.py restore         # 还原（删备份）
    python scripts/apply_build_env.py show            # 看当前生效环境

🔴 为什么必须在 Unity 启动前注入，而不是在 CLIBuilder 里改
    batchmode 启动时会重新导入 Resources 下的 TextAsset，启动后再改文件，
    包内拿到的仍是旧内容（除非再 ImportAsset 一次，多一次踩坑机会）。
    在进程外面改文件 = Unity 一启动看到的就是目标值，没有任何缓存时序问题。
    ⇒ 所以注入/还原都由 shell 层做，CLIBuilder 一行都不用改（不重编、不引入新风险）。

🔴 还原的三种保护
    1. 备份只在**第一次 apply** 时创建（`.workbuddy/tmp/build-env/version.txt.orig`），
       后续 apply 一律基于这份基准改 ⇒ 连续 apply 两个环境也不会累加漂移。
    2. restore 是字节级整文件覆盖并删除备份 ⇒ 还原后与 git HEAD 逐字节一致（git status 干净）。
    3. 调用方（aab_release.sh / build_apk.sh）都挂了 `trap ... EXIT`，
       打包失败/中断也会还原，不会把「正式服地址」留在工程里被下次打包误用。

退出码：0 成功；2 用法错 / 环境名不存在
"""
import argparse
import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION_FILE = ROOT / "Assets" / "Resources" / "version.txt"
ENVS_FILE = ROOT / "scripts" / "build_envs.json"
BACKUP_DIR = ROOT / ".workbuddy" / "tmp" / "build-env"
BACKUP_FILE = BACKUP_DIR / "version.txt.orig"

# 只有这些字段会被环境表覆盖；其余（serverPathType/subChannel/packageVersion/version）原样保留
ENV_FIELDS = ["serverUrl", "resUrl", "logUrl", "sdkLodingUrl", "payUrl", "channel"]

# 输出时的 key 顺序，与工程原文件保持一致（不是 JSON 规范要求，纯粹为了 diff 好看）
FIELD_ORDER = [
    "sdkLodingUrl", "payUrl", "serverUrl", "logUrl", "serverPathType",
    "resUrl", "subChannel", "channel", "packageVersion", "version",
]


def die(msg: str, code: int = 2) -> "None":
    print(f"❌ {msg}", file=sys.stderr)
    sys.exit(code)


def load_envs() -> dict:
    if not ENVS_FILE.is_file():
        die(f"缺少环境表：{ENVS_FILE}")
    try:
        data = json.loads(ENVS_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        die(f"环境表不是合法 JSON（{ENVS_FILE}）：{e}")
    envs = data.get("envs") or {}
    if not envs:
        die(f"环境表里没有任何 envs：{ENVS_FILE}")
    # 下划线开头的是注释，不算可选环境
    return {k: v for k, v in envs.items() if not k.startswith("_")}


def read_version_file(path: Path) -> dict:
    try:
        obj = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        die(f"找不到包内配置文件：{path}")
    except json.JSONDecodeError as e:
        die(f"{path} 不是合法 JSON：{e}")
    return obj if isinstance(obj, dict) else die(f"{path} 顶层不是对象")


def dump_version(obj: dict) -> str:
    """按工程原有的 key 顺序、单行、`", "` 分隔输出（与 #版本文件原始形态一致）。"""
    ordered = {}
    for k in FIELD_ORDER:
        if k in obj:
            ordered[k] = obj[k]
    for k, v in obj.items():  # 未被列进 FIELD_ORDER 的字段追加在后面，不丢数据
        if k not in ordered:
            ordered[k] = v
    return json.dumps(ordered, ensure_ascii=False, separators=(", ", ":"))


def cmd_envs(_args) -> int:
    envs = load_envs()
    data = json.loads(ENVS_FILE.read_text(encoding="utf-8"))
    print(f"可选环境（{ENVS_FILE.name}，default={data.get('default')}）：")
    for name, cfg in envs.items():
        print(f"  - {name:<20} serverUrl={cfg.get('serverUrl')}  resUrl={cfg.get('resUrl')}")
    return 0


def cmd_show(_args) -> int:
    cur = read_version_file(VERSION_FILE)
    print(f"当前工程：{VERSION_FILE.relative_to(ROOT)}")
    print(f"  serverUrl = {cur.get('serverUrl')}")
    print(f"  resUrl    = {cur.get('resUrl')}")
    print(f"  channel   = {cur.get('channel')}")
    print(f"  serverPathType = {cur.get('serverPathType')}")

    matched = []
    for name, cfg in load_envs().items():
        if all(str(cur.get(k)) == str(cfg[k]) for k in ENV_FIELDS if k in cfg):
            matched.append(name)
    print(f"  匹配环境：{'、'.join(matched) if matched else '（不在环境表里 —— 手工改过或旧值）'}")

    if BACKUP_FILE.is_file():
        print(f"  ⚠️ 存在未还原的备份：{BACKUP_FILE.relative_to(ROOT)}（说明上次注入没走到 restore）")
    return 0


def cmd_apply(args) -> int:
    envs = load_envs()
    name = args.env
    if name not in envs:
        print(f"❌ 环境名 `{name}` 不在 {ENVS_FILE.name} 里。可选：", file=sys.stderr)
        for n in envs:
            print(f"     - {n}", file=sys.stderr)
        return 2

    # 基准 = 备份（如果有，说明这是第二次 apply）；否则先备份当前文件
    if BACKUP_FILE.is_file():
        base = read_version_file(BACKUP_FILE)
        print(f"  基准取上次的备份：{BACKUP_FILE.relative_to(ROOT)}")
    else:
        base = read_version_file(VERSION_FILE)
        if args.dry_run:
            print(f"  [dry-run] 将备份原配置 → {BACKUP_FILE.relative_to(ROOT)}")
        else:
            BACKUP_DIR.mkdir(parents=True, exist_ok=True)
            shutil.copy2(VERSION_FILE, BACKUP_FILE)
            print(f"  已备份原配置 → {BACKUP_FILE.relative_to(ROOT)}")

    cfg = envs[name]
    applied = {}
    for k in ENV_FIELDS:
        if k in cfg:                      # 环境表没写的字段保持原值（比如 logUrl 不配就沿用 null）
            base[k] = cfg[k]
            applied[k] = cfg[k]

    text = dump_version(base)
    if args.dry_run:
        print(f"  [dry-run] 将写入 {VERSION_FILE.relative_to(ROOT)}：")
        print(f"  {text}")
        return 0

    VERSION_FILE.write_text(text, encoding="utf-8")
    print(f"✅ 已注入环境 `{name}`：")
    for k, v in applied.items():
        print(f"     {k} = {v}")
    print(f"   文件：{VERSION_FILE.relative_to(ROOT)}（{len(text)} 字节）")
    if name == "测试服":
        print("   ⚠️ 真机装这个包要先让手机的 127.0.0.1 指向电脑：")
        print("      adb reverse tcp:8081 tcp:8081   # 登录/列表 8081")
        print("      adb reverse tcp:16081 tcp:16081 # 游戏服 16081")
    return 0


def cmd_restore(_args) -> int:
    if not BACKUP_FILE.is_file():
        print("  无需还原（没有备份，工程文件未被本脚本改过）")
        return 0
    shutil.copy2(BACKUP_FILE, VERSION_FILE)
    BACKUP_FILE.unlink()
    cur = read_version_file(VERSION_FILE)
    print(f"✅ 已还原 {VERSION_FILE.relative_to(ROOT)}：serverUrl={cur.get('serverUrl')}")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(
        description="打包前注入/还原「连哪个服务器」（读 scripts/build_envs.json）")
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("apply", help="注入指定环境（首次会备份原文件）")
    sp.add_argument("env", help="环境名，必须是 build_envs.json 里的 key")
    sp.add_argument("--dry-run", action="store_true", help="只打印将写入的内容")
    sp.set_defaults(func=cmd_apply)

    sp = sub.add_parser("restore", help="从备份还原工程文件")
    sp.set_defaults(func=cmd_restore)

    sp = sub.add_parser("show", help="显示当前生效环境")
    sp.set_defaults(func=cmd_show)

    sp = sub.add_parser("envs", help="列出可选环境")
    sp.set_defaults(func=cmd_envs)

    args = p.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
