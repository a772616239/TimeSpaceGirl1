#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify.py —— libtolua.so 重编产物的校验闸门（4 项硬性）

用法：
    verify.py <new.so> [--project-root <仓库根>]

为什么是这 4 项
---------------
①② 是「合规」：Google Play 自 2025-11 起要求 16KB 页支持。
③④ 是「不炸」—— 2026-10-12 真机实测踩过的坑：

    第一版修复把运行时 LuaJIT 从 2.1.0-beta3 换成了 2.1.ROLLING，
    而真机跑的是 LuaEncoder 用 beta3 编的**预编译字节码**。
    两者 BCDUMP_VERSION 都是 2（字节码头 1b 4c 4a 02 不会被拒），
    但 opcode 表有增删 ⇒ 加载后执行错指令，启动即卡死、进不了登录界面。

所以：
  ① ELF PT_LOAD p_align ≥ 16384      —— 硬门槛
  ② .note.android.ident 里 NDK ≥ r28  —— 证明用的是 16KB 感知工具链
  ③ 导出符号对原始库零缺失            —— 防少编源文件 / 可见性收紧
  ④ .so 内 LuaJIT 版本 == LuaEncoder 版本 —— 防版本错配（本次事故的直接防线）

退出码：0 全过 / 1 有硬性项失败
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ALIGN_MIN = 16384
NDK_MIN = 28


# --------------------------------------------------------------------------- #
# 工具查找
# --------------------------------------------------------------------------- #
def _ndk_bin() -> Path | None:
    ndk = os.environ.get("ANDROID_NDK_HOME") or os.environ.get("ANDROID_NDK_ROOT")
    if not ndk:
        return None
    prebuilt = Path(ndk) / "toolchains" / "llvm" / "prebuilt"
    if not prebuilt.is_dir():
        return None
    for tag in ("darwin-x86_64", "darwin-arm64", "linux-x86_64", "linux-arm64"):
        b = prebuilt / tag / "bin"
        if b.is_dir():
            return b
    for child in sorted(prebuilt.iterdir()):
        b = child / "bin"
        if b.is_dir():
            return b
    return None


def find_tool(name: str) -> str:
    """优先 NDK 的 llvm-<name>，回落 PATH 上的同名工具。"""
    nb = _ndk_bin()
    if nb:
        for cand in (nb / f"llvm-{name}", nb / name):
            if cand.is_file() and os.access(cand, os.X_OK):
                return str(cand)
    for cand in (f"llvm-{name}", name):
        p = shutil.which(cand)
        if p:
            return p
    return ""


def run(argv: list[str]) -> str:
    try:
        p = subprocess.run(argv, capture_output=True, text=True, check=False)
        return p.stdout or ""
    except OSError:
        return ""


# --------------------------------------------------------------------------- #
# 输出
# --------------------------------------------------------------------------- #
def ok(msg: str) -> None:
    print(f"  \033[1;32m✓ {msg}\033[0m")


def bad(msg: str) -> None:
    print(f"  \033[1;31m✗ {msg}\033[0m")


def info(msg: str) -> None:
    print(f"    {msg}")


# --------------------------------------------------------------------------- #
# ① PT_LOAD 对齐
# --------------------------------------------------------------------------- #
def check_align(so: Path, readelf: str) -> bool:
    print(f"\n[①] 16KB 页对齐（PT_LOAD p_align ≥ {ALIGN_MIN}）")
    if not readelf:
        bad("找不到 readelf，无法校验")
        return False
    out = run([readelf, "-l", str(so)])
    aligns: list[int] = []
    for ln in out.splitlines():
        parts = ln.split()
        # 形如:  LOAD  0x000000 0x0 0x0 0x2a9d0 0x2a9d0 R   0x4000
        if len(parts) >= 2 and parts[0] == "LOAD":
            try:
                aligns.append(int(parts[-1], 16))
            except ValueError:
                continue
    if not aligns:
        bad("未解析到任何 LOAD 段")
        return False
    info(f"PT_LOAD 段数 = {len(aligns)}，p_align = {[hex(a) for a in aligns]}")
    worst = min(aligns)
    if worst >= ALIGN_MIN:
        ok(f"最小 p_align = {hex(worst)}（{worst}）≥ {ALIGN_MIN}")
        return True
    bad(f"最小 p_align = {hex(worst)}（{worst}）< {ALIGN_MIN}")
    return False


# --------------------------------------------------------------------------- #
# ② NDK 版本
# --------------------------------------------------------------------------- #
def check_ndk(so: Path, readelf: str) -> bool:
    print(f"\n[②] NDK 版本（.note.android.ident ≥ r{NDK_MIN}）")
    if not readelf:
        bad("找不到 readelf，无法校验")
        return False
    out = run([readelf, "-p", ".note.android.ident", str(so)])
    # 行形如 "  [  0] Android (13004108) clang version ..."
    body = "".join(re.sub(r"^\s*\[\s*\d+\]\s?", "", ln) for ln in out.splitlines() if ln.strip())
    # 两种常见格式：
    #   Android.r2813004108                   ← NDK r27+ 新格式（r28 = 28.0.13004108）
    #   Android (13004108) clang version ...  ← 旧格式
    # 注意：新格式里 "r28" 后面紧跟数字，所以**不能**用 \b 收尾。
    m = re.search(r"Android[.\s]*r(\d{2})", body)
    if m:
        rver = int(m.group(1))
    else:
        m2 = re.search(r"Android\s*\((\d{8})\)", body)
        if not m2:
            bad(f"读不到 NDK 标识（ident 片段：{body[:80]!r}）")
            return False
        rver = int(m2.group(1)) // 10000
    if rver >= NDK_MIN:
        ok(f"NDK r{rver}（≥ r{NDK_MIN}）")
        return True
    bad(f"NDK r{rver} < r{NDK_MIN}")
    return False


# --------------------------------------------------------------------------- #
# ③ 导出符号
# --------------------------------------------------------------------------- #
def defined_symbols(so: Path, nm: str) -> set[str]:
    out = run([nm, "-D", "--defined-only", str(so)])
    syms = set()
    for ln in out.splitlines():
        parts = ln.split()
        if len(parts) >= 3 and parts[1] in ("T", "W", "i"):
            syms.add(parts[2])
    return syms


def check_symbols(so: Path, nm: str, ref_file: Path) -> bool:
    print("\n[③] 导出符号（对原始库零缺失）")
    if not nm:
        bad("找不到 nm，无法校验")
        return False
    if not ref_file.is_file():
        bad(f"缺少符号基准：{ref_file}")
        return False
    ref = {s.strip() for s in ref_file.read_text(encoding="utf-8").splitlines() if s.strip()}
    cur = defined_symbols(so, nm)
    missing = sorted(ref - cur)
    added = sorted(cur - ref)
    info(f"基准 {len(ref)} 个 / 新库 {len(cur)} 个")
    if missing:
        bad(f"缺失 {len(missing)} 个符号：{missing[:15]}")
        if len(missing) > 15:
            info(f"（其余 {len(missing) - 15} 个省略）")
        return False
    ok(f"{len(ref)}/{len(ref)} 全部在（新增 {len(added)}：{added[:6] if added else '无'}）")
    return True


# --------------------------------------------------------------------------- #
# ④ LuaJIT 版本一致性
# --------------------------------------------------------------------------- #
VER_RE = re.compile(r"LuaJIT\s+(\d+\.\d+\.\d+[\w.\-]*)")


def so_luajit_version(so: Path) -> str | None:
    p = subprocess.run(["strings", str(so)], capture_output=True, text=True, check=False)
    found = {m.group(1) for m in (VER_RE.search(l) for l in (p.stdout or "").splitlines()) if m}
    if not found:
        return None
    if len(found) > 1:
        info(f"注：.so 内含多个 LuaJIT 版本串 {sorted(found)}，取最短匹配")
    return sorted(found, key=len)[0]


def encoder_version(project_root: Path) -> str | None:
    """跑 LuaEncoder 的 luajit -v，取真机字节码实际使用的版本。"""
    for rel in ("LuaEncoder/luajit_mac/64/luajit", "LuaEncoder/luajit_mac/32/luajit"):
        exe = project_root / rel
        if exe.is_file() and os.access(exe, os.X_OK):
            p = subprocess.run([str(exe), "-v"], capture_output=True, text=True, check=False)
            m = VER_RE.search(p.stdout or "")
            if m:
                return m.group(1)
    return None


def check_luajit(so: Path, project_root: Path, ref_dir: Path) -> bool:
    print("\n[④] LuaJIT 版本一致性（必须与字节码编码器同版本）")
    so_ver = so_luajit_version(so)
    if not so_ver:
        bad("读不到 .so 内的 LuaJIT 版本串")
        return False

    enc_ver = encoder_version(project_root)
    if enc_ver:
        info(f"LuaEncoder 编码器版本 = {enc_ver}")
    else:
        fallback = ref_dir / "expected-luajit-version.txt"
        if fallback.is_file():
            m = VER_RE.search(fallback.read_text(encoding="utf-8"))
            enc_ver = m.group(1) if m else None
            info(f"（LuaEncoder 不可用，改用基准文件）期望 = {enc_ver}")
    if not enc_ver:
        bad("无法确定编码器版本（既跑不了 LuaEncoder，也没有 ref 基准文件）")
        return False

    info(f"新库内 LuaJIT 版本 = {so_ver}")
    if so_ver == enc_ver:
        ok(f"版本一致：{so_ver} —— 字节码兼容")
        return True
    bad(f"🔴 版本错配！新库 {so_ver} ≠ 编码器 {enc_ver}")
    info("  这样编出的库加载现有 LuaBytes 字节码会执行错指令，真机启动即卡死。")
    info("  见本脚本头部「血泪教训」。")
    return False


# --------------------------------------------------------------------------- #
def main() -> int:
    ap = argparse.ArgumentParser(description="libtolua.so 重编产物校验")
    ap.add_argument("so", help="待校验的 libtolua.so")
    ap.add_argument("--project-root", default=None,
                    help="仓库根目录（默认由本脚本位置推导：scripts/libtolua16k/ -> ../..）")
    args = ap.parse_args()

    so = Path(args.so).expanduser().resolve()
    if not so.is_file():
        print(f"[FATAL] 文件不存在：{so}", file=sys.stderr)
        return 1

    script_dir = Path(__file__).resolve().parent
    project_root = Path(args.project_root).resolve() if args.project_root else script_dir.parent.parent
    ref_dir = script_dir / "ref"

    readelf = find_tool("readelf")
    nm = find_tool("nm")

    print(f"== 校验 {so.name} ==")
    print(f"   体积 {so.stat().st_size} 字节")
    print(f"   readelf: {readelf or '(未找到)'}")
    print(f"   nm     : {nm or '(未找到)'}")

    results = [
        check_align(so, readelf),
        check_ndk(so, readelf),
        check_symbols(so, nm, ref_dir / "original-symbols.txt"),
        check_luajit(so, project_root, ref_dir),
    ]

    passed = sum(1 for r in results if r)
    print(f"\n== 结果：{passed}/{len(results)} 通过 ==")
    if passed == len(results):
        print("  \033[1;32m全部通过\033[0m")
        return 0
    print("  \033[1;31m存在失败项，不要安装此产物\033[0m")
    return 1


if __name__ == "__main__":
    sys.exit(main())
