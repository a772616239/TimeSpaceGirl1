#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ab_cache.py —— AssetBundle 缓存指纹：记录 / 校验「上一轮重建的 AB 能不能直接复用」

为什么需要这一层
----------------
`TS-Resource-Build` 支持「不重建 AB，直接复用上一轮产物」后，包内资源的唯一来源就是
`Assets/StreamingAssets/Android/`（gitignore，跨 ci_sync 的 reset 存活）。复用省掉 5~8 分钟，
但也会把**旧 Lua** 打进包 —— 而这个错**不会报任何错**，只在真机上表现为「改了配置没生效」。

所以复用前必须能回答三个问题，本脚本就是这三个答案的唯一实现：

  1. 缓存还在不在、完不完整？（bundle 数、Lua bundle、files/resconfigs）
  2. 这份缓存是**哪次重建**产出的？（git HEAD / 时间 / 环境 / bundle sha256）
  3. 从那之后**字节码变过没有**？（LuaBytes 全量内容哈希）

为什么用**内容哈希**而不是 mtime
    ci_sync 的 `git reset --hard` 会把改动过的文件重新检出（mtime 变新、内容可能一模一样），
    纯 mtime 判据（`check_lua_bundle_fresh.sh`）在这种场景下必然误报「bundle 过期」。
    内容哈希只在**真的改了字节码**时才变，这才是「包内 Lua 是否最新」的正确判据。

指纹文件：`build/ab_cache/manifest.json`（gitignore，和 `build/table_sync/` 同性质的本机账本）

用法
----
    python scripts/ab_cache.py record --server-env 正式服        # AB 重建成功后写指纹
    python scripts/ab_cache.py verify --server-env 正式服        # 复用前校验（0 可用 / 1 拦住）
    python scripts/ab_cache.py fresh-check                       # 内容哈希判据（0 一致 / 1 不一致）

退出码：0 通过 / 1 不通过（复用会打出错包） / 2 环境错误
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SA_DIR = ROOT / "Assets" / "StreamingAssets" / "Android"
LUA_BYTES_DIR = ROOT / "Assets" / "ManagedResources" / "LuaBytes"
VERSION_SNAPSHOT = SA_DIR / "Resources" / "version.txt"
ENVS_FILE = ROOT / "scripts" / "build_envs.json"
MANIFEST = ROOT / "build" / "ab_cache" / "manifest.json"

LUA_BUNDLE = "lzma|luabytes.unity3d"
# AAB 里缺任何一个，游戏都起不来或没有资源索引（与 check_ab_ready.sh 的口径一致）
REQUIRED_BUNDLES = ["files.unity3d", "lzma|resconfigs.unity3d", LUA_BUNDLE]

OK, WARN, BAD = "ok", "warn", "bad"


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def iso(ts: float) -> str:
    return datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S") if ts else ""


def git(*args: str) -> str:
    try:
        out = subprocess.run(["git", "-C", str(ROOT), *args],
                             capture_output=True, text=True, timeout=20)
        return out.stdout.strip() if out.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def lua_bytes_fingerprint() -> dict:
    """LuaBytes 全量内容指纹：`<相对路径>\0<sha256>\n` 逐行喂给 sha256。"""
    if not LUA_BYTES_DIR.is_dir():
        return {"hash": "", "count": 0, "newest_ts": 0}
    files = sorted(p for p in LUA_BYTES_DIR.rglob("*.bytes") if p.is_file())
    h = hashlib.sha256()
    newest = 0
    for p in files:
        rel = p.relative_to(LUA_BYTES_DIR).as_posix()
        h.update(rel.encode("utf-8"))
        h.update(b"\0")
        h.update(sha256_file(p).encode("ascii"))
        h.update(b"\n")
        newest = max(newest, int(p.stat().st_mtime))
    return {"hash": "sha256:" + h.hexdigest(), "count": len(files), "newest_ts": newest}


def bundles() -> list[Path]:
    if not SA_DIR.is_dir():
        return []
    return sorted(p for p in SA_DIR.glob("*.unity3d") if p.is_file())


def snapshot_env() -> dict:
    try:
        return json.loads(VERSION_SNAPSHOT.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}


def expected_server_url(env_name: str) -> str:
    try:
        data = json.loads(ENVS_FILE.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return ""
    cfg = (data.get("envs") or {}).get(env_name) or {}
    return str(cfg.get("serverUrl") or "")


def load_manifest() -> dict:
    try:
        data = json.loads(MANIFEST.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


class Report:
    def __init__(self) -> None:
        self.items: list[tuple[str, str]] = []

    def ok(self, msg: str) -> None:
        self.items.append((OK, msg))

    def warn(self, msg: str) -> None:
        self.items.append((WARN, msg))

    def bad(self, msg: str) -> None:
        self.items.append((BAD, msg))

    def dump(self) -> int:
        icon = {OK: "  ✓", WARN: "  !", BAD: "  ✗"}
        for level, msg in self.items:
            for i, line in enumerate(msg.splitlines()):
                print(f"{icon[level] if i == 0 else '   '} {line}")
        return 1 if any(l == BAD for l, _ in self.items) else 0


def cmd_record(args) -> int:
    b = SA_DIR / LUA_BUNDLE
    if not b.is_file():
        print(f"✗ 找不到 {b.relative_to(ROOT)}，无法记录 AB 缓存指纹", file=sys.stderr)
        return 2
    fp = lua_bytes_fingerprint()
    stat = b.stat()
    all_bundles = bundles()
    manifest = {
        "version": 1,
        "recorded_at": datetime.now().strftime("%Y-%m-%dT%H:%M:%S%z"),
        "mode": args.mode,
        "server_env": args.server_env,
        "git_head": git("rev-parse", "--short", "HEAD"),
        "git_branch": git("rev-parse", "--abbrev-ref", "HEAD"),
        "lua_bytes_hash": fp["hash"],
        "lua_bytes_count": fp["count"],
        "bundle": {
            "name": LUA_BUNDLE,
            "size": stat.st_size,
            "sha256": sha256_file(b),
            "mtime": iso(stat.st_mtime),
        },
        "bundle_count": len(all_bundles),
        "newest_bundle_mtime": iso(max((p.stat().st_mtime for p in all_bundles), default=0)),
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    tmp = MANIFEST.with_suffix(".tmp")
    tmp.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    tmp.replace(MANIFEST)
    print(f"  已记录 AB 缓存指纹：{MANIFEST.relative_to(ROOT)}")
    print(f"     bundle {manifest['bundle_count']} 个，Lua bundle {stat.st_size / 1048576:.1f} MB，"
          f"字节码 {fp['count']} 个 @ {manifest['git_head'] or '?'}")
    return 0


def cmd_verify(args) -> int:
    r = Report()

    # ---- 1. 缓存存在性 -----------------------------------------------------
    if not SA_DIR.is_dir():
        r.bad(f"缓存不存在：{SA_DIR.relative_to(ROOT)}（打包目录还没重建过 AB）")
        return r.dump()

    all_bundles = bundles()
    if all_bundles:
        newest = max(p.stat().st_mtime for p in all_bundles)
        r.ok(f"bundle 总数 {len(all_bundles)}，最新 {iso(newest)}")
    else:
        r.bad(f"{SA_DIR.relative_to(ROOT)} 下没有任何 .unity3d（复用会打出空包）")

    for name in REQUIRED_BUNDLES:
        p = SA_DIR / name
        if p.is_file():
            r.ok(f"{name} 就位（{p.stat().st_size / 1048576:.1f} MB，{iso(p.stat().st_mtime)}）")
        else:
            r.bad(f"{name} 缺失（复用这份缓存打出的包起不来 / 没有资源索引）")

    # ---- 2. 指纹比对 -------------------------------------------------------
    man = load_manifest()
    bundle_path = SA_DIR / LUA_BUNDLE
    if not man:
        r.warn(f"没有缓存指纹（{MANIFEST.relative_to(ROOT)} 不存在）：可能是首次复用，"
               "只能按「文件在不在」判断，无法确认缓存来自哪次重建")
    else:
        r.ok(f"缓存指纹：{man.get('recorded_at', '?')} 由 {man.get('mode', '?')} 产出"
             f"（环境 {man.get('server_env') or '未注入'}，HEAD {man.get('git_head') or '?'}）")

        rec = man.get("bundle") or {}
        if bundle_path.is_file() and rec.get("sha256"):
            actual = sha256_file(bundle_path)
            if actual == rec["sha256"]:
                r.ok("Lua bundle 与指纹一致（就是那次重建产出的那份）")
            else:
                r.warn("Lua bundle 与指纹不一致：缓存被别的构建覆盖过或手工替换过，"
                       "无法用指纹判断它含哪版字节码")

        fp = lua_bytes_fingerprint()
        if not fp["hash"]:
            r.warn("找不到 LuaBytes 目录，跳过字节码比对")
        elif not man.get("lua_bytes_hash"):
            r.warn("指纹里没有字节码哈希（旧版脚本写的），跳过比对")
        elif fp["hash"] == man["lua_bytes_hash"]:
            r.ok(f"字节码与上次重建时一致（{fp['count']} 个，内容哈希相同）")
        else:
            r.bad(f"字节码在 AB 重建之后变过（指纹 {man.get('lua_bytes_count')} 个 → 现在 {fp['count']} 个，"
                  "内容哈希不同）\n"
                  "     复用这份缓存 ⇒ 包里还是旧 Lua，改了配置不会生效。\n"
                  "     要把这些改动带进包：AB_MODE=重建（约 5-8 分钟）。\n"
                  "     确认「这批字节码改动与本包无关」才用 AB_MODE=跳过 强行出包。")

        # ---- 3. 代码漂移（只提醒，不拦） ----------------------------------
        head_now = git("rev-parse", "--short", "HEAD")
        head_rec = man.get("git_head") or ""
        if head_now and head_rec and head_now != head_rec:
            diff = git("diff", "--name-only", f"{head_rec}..HEAD", "--", "Assets")
            changed = [ln for ln in diff.splitlines()
                       if ln and not ln.startswith("Assets/StreamingAssets/")]
            if changed:
                shown = "\n".join(f"       {ln}" for ln in changed[:10])
                more = f"\n       …另有 {len(changed) - 10} 个" if len(changed) > 10 else ""
                r.warn(f"上次 AB 重建之后 Assets 下有 {len(changed)} 个文件改动"
                       f"（{head_rec} → {head_now}）：\n{shown}{more}\n"
                       "       纯 C# / 纯代码改动不影响 AB；动了 prefab / 图 / lua 就必须重建。")
            else:
                r.ok(f"上次重建之后 Assets 下无文件改动（{head_rec} → {head_now}）")

    # ---- 4. 包内环境快照 ---------------------------------------------------
    if args.server_env:
        want = expected_server_url(args.server_env)
        snap = snapshot_env()
        got = str(snap.get("serverUrl") or "")
        if not got:
            r.warn(f"读不到 AB 快照的 serverUrl（{VERSION_SNAPSHOT.relative_to(ROOT)}）")
        elif want and got != want:
            r.warn(f"快照 serverUrl={got} 与所选环境「{args.server_env}」({want}) 不一致："
                   "apply_build_env 应该已经补过；若本步之后还有别的 job 改过工程，打包前再确认一次")
        else:
            r.ok(f"包内环境快照 serverUrl={got}（{args.server_env}）")

    return r.dump()


def cmd_fresh_check(_args) -> int:
    """内容哈希判据：这份 Lua bundle 里到底有没有当前这版字节码。"""
    bundle_path = SA_DIR / LUA_BUNDLE
    man = load_manifest()
    fp = lua_bytes_fingerprint()
    if not bundle_path.is_file() or not man or not fp["hash"]:
        print("  （无指纹/无 bundle，退回 mtime 判据）")
        return 1
    rec = man.get("bundle") or {}
    if rec.get("sha256") and sha256_file(bundle_path) != rec["sha256"]:
        print("  （bundle 与指纹不符，退回 mtime 判据）")
        return 1
    if not man.get("lua_bytes_hash") or man["lua_bytes_hash"] != fp["hash"]:
        print("  （字节码内容哈希与指纹不同 ⇒ bundle 里不是当前这版字节码）")
        return 1
    print(f"  ✓ 内容哈希判据通过：这份 bundle 就是由当前这 {fp['count']} 个字节码打出来的")
    print(f"    指纹 {man.get('recorded_at', '?')} @ {man.get('git_head') or '?'}"
          f"（mtime 判据会因 git reset 重写文件而误报，这里以内容为准）")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="AssetBundle 缓存指纹：记录 / 校验 / 内容哈希判据")
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser("record", help="AB 重建成功后记录缓存指纹")
    sp.add_argument("--server-env", default="", help="本次出包环境（只作记录）")
    sp.add_argument("--mode", default="rebuild", help="产出方式（rebuild / 其它）")
    sp.set_defaults(func=cmd_record)

    sp = sub.add_parser("verify", help="复用缓存前校验（rc=1 表示不能复用）")
    sp.add_argument("--server-env", default="", help="要出包的环境（用于核对包内快照）")
    sp.set_defaults(func=cmd_verify)

    sp = sub.add_parser("fresh-check", help="内容哈希判据（rc=1 表示 bundle 不含当前字节码）")
    sp.set_defaults(func=cmd_fresh_check)

    args = p.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
