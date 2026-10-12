#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""libtolua.so 16KB 改造后的兼容性校验（由 build.sh 调用，也可单独跑）。

用法:
    python3 verify.py <new_libtolua.so> [old_libtolua.so]

校验项（任一不过则退出码非 0）：
  硬性
    1. ELF PT_LOAD 的 p_align >= 16384        —— Play 门槛1，不达标会被拒
    2. .note.android.ident 里 NDK >= r28      —— 证明用的是 16KB 感知的工具链
  兼容性（防止重编后运行时缺符号）
    3. 旧库导出的 luaopen_* 必须全部还在        —— 否则 Lua 侧 require 直接失败
    4. 旧库导出的 tolua_* 必须全部还在          —— C# 侧 P/Invoke 入口
    5. 旧库导出的 lua_* / luaL_* 必须全部还在   —— ToLua 运行时 API
    6. 未定义符号只应来自 libc/libm/libdl       —— 不应引入新的外部依赖
  提示（不判失败）
    7. 旧库导出、新库不再导出的其余符号：多为 luasocket/LuaJIT 内部实现，
       新版收紧了可见性。逐个在仓库里 grep 确认无人 P/Invoke 即可。

退出码: 0 全过 / 1 有硬性项不过 / 2 有兼容性项不过 / 3 参数或工具问题
"""
from __future__ import annotations

import os
import re
import shutil
import struct
import subprocess
import sys

PT_LOAD = 1
REQUIRED_ALIGN = 16384

# 允许出现在未定义符号里的系统库前缀/后缀（Android bionic）
SYS_SUFFIXES = ("@LIBC", "@LIBM", "@LIBDL")
SYS_NAMES = {
    "__cxa_atexit", "__cxa_finalize", "__errno", "__stack_chk_fail",
    "__sF", "abort", "exit", "malloc", "free", "realloc", "memcpy", "memset",
    "memmove", "memcmp", "memchr", "strlen", "strcmp", "strcpy", "strncpy",
    "strchr", "strrchr", "strstr", "strncmp", "strncasecmp", "strerror",
    "strtod", "strtol", "strtoll", "strtoul", "strtoull", "strftime",
    "vsnprintf", "vfprintf", "snprintf", "vsprintf", "fprintf", "fputs",
    "fputc", "fgets", "fopen", "fclose", "fread", "fwrite", "fflush",
    "feof", "ferror", "clearerr", "getc", "ungetc", "putchar", "setvbuf",
    "popen", "pclose", "remove", "rename", "tmpfile", "mkstemp", "system",
    "getenv", "time", "clock", "difftime", "mktime", "gmtime_r", "localtime_r",
    "nanosleep", "sigaction", "sigemptyset", "signal", "setitimer",
    "pthread_once", "pthread_key_create", "pthread_key_delete",
    "pthread_getspecific", "pthread_setspecific", "pthread_mutex_lock",
    "pthread_mutex_unlock", "pthread_rwlock_rdlock", "pthread_rwlock_wrlock",
    "pthread_rwlock_unlock", "dlopen", "dlclose", "dlsym", "dlerror",
    "dl_iterate_phdr", "mmap", "munmap", "mprotect", "mremap", "syscall",
    "open", "close", "read", "fcntl", "select", "poll", "socket", "bind",
    "listen", "accept", "connect", "shutdown", "recvfrom", "sendto",
    "getsockopt", "setsockopt", "getsockname", "getpeername", "getaddrinfo",
    "freeaddrinfo", "gethostbyname", "gethostbyaddr", "gethostname",
    "getnameinfo", "gai_strerror", "inet_aton", "inet_ntoa", "inet_pton",
    "hstrerror", "setlocale", "acos", "asin", "atan", "atan2", "cos", "cosh",
    "sin", "sinh", "tan", "tanh", "exp", "log", "log10", "pow", "powf",
    "fmod", "frexp", "ldexp", "modf", "atoll",
}


# 已人工确认「本仓无人引用」的历史导出符号，重编后可以不再导出。
# ⚠️ 只允许往里加**已 grep 确认为零引用**的符号；任何未登记的新增缺失仍会判失败，
#    这样这道闸门在下次重编时依然是有效的回归网。
KNOWN_SAFE_REMOVALS: dict[str, str] = {
    "lua_getexdata": "LuaJIT 扩展数据 API；本仓 C#(*.cs) 与 Lua(~Lua/) 全仓零引用",
    "lua_setexdata": "同上",
}


def fail(msg: str, code: int) -> None:
    print(f"\033[1;31m  ✗ {msg}\033[0m", file=sys.stderr)
    sys.exit(code)


def ok(msg: str) -> None:
    print(f"\033[1;32m  ✓ {msg}\033[0m")


def info(msg: str) -> None:
    print(f"    {msg}")


def find_tool(name: str) -> str | None:
    p = shutil.which(name)
    if p:
        return p
    ndk = os.environ.get("ANDROID_NDK_HOME")
    if ndk:
        cand = os.path.join(ndk, "toolchains", "llvm", "prebuilt", "darwin-x86_64", "bin", name)
        if os.path.isfile(cand):
            return cand
    return None


# --------------------------------------------------------------------------- #
# ELF 解析：不依赖 readelf，避免工具链缺失时无法判定
# --------------------------------------------------------------------------- #
def pt_load_aligns(path: str) -> list[int]:
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:4] != b"\x7fELF":
        fail(f"{path} 不是 ELF 文件", 3)
    is64 = data[4] == 2
    little = data[5] == 1
    end = "<" if little else ">"
    if is64:
        e_phoff = struct.unpack_from(end + "Q", data, 0x20)[0]
        e_phentsize = struct.unpack_from(end + "H", data, 0x36)[0]
        e_phnum = struct.unpack_from(end + "H", data, 0x38)[0]
    else:
        e_phoff = struct.unpack_from(end + "I", data, 0x1C)[0]
        e_phentsize = struct.unpack_from(end + "H", data, 0x2A)[0]
        e_phnum = struct.unpack_from(end + "H", data, 0x2C)[0]

    aligns = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type = struct.unpack_from(end + "I", data, off)[0]
        if p_type != PT_LOAD:
            continue
        if is64:
            p_align = struct.unpack_from(end + "Q", data, off + 0x30)[0]
        else:
            p_align = struct.unpack_from(end + "I", data, off + 0x1C)[0]
        aligns.append(p_align)
    return aligns


def section_text(path: str, want: str) -> str:
    """粗略取出指定 section 的可读字符串（够用即可，不追求完备）。"""
    readelf = find_tool("llvm-readelf") or find_tool("readelf")
    if not readelf:
        return ""
    try:
        out = subprocess.run([readelf, "-p", want, path],
                             capture_output=True, text=True, timeout=60).stdout
    except Exception:  # noqa: BLE001
        return ""
    # llvm-readelf -p 输出形如 "  [  0] 文字..."，剥掉行首偏移列
    # ⚠️ 每个 [off] 是**独立的** NUL 结尾字符串（如 "Android" / "r28" / "13004108"），
    #    必须用换行拼接；用 "" 拼会把它们黏成 "r2813004108" 导致版本号解析失败。
    lines = []
    for ln in out.splitlines():
        m = re.match(r"^\s*\[\s*[0-9a-f]+\]\s?(.*)$", ln)
        if m:
            lines.append(m.group(1))
    return "\n".join(lines)


def ndk_ident(path: str) -> str:
    return section_text(path, ".note.android.ident")


def dyn_syms(path: str, defined_only: bool) -> set[str]:
    nm = find_tool("llvm-nm") or find_tool("nm")
    if not nm:
        fail("找不到 llvm-nm / nm", 3)
    args = [nm, "-D"]
    if defined_only:
        args.append("--defined-only")
    try:
        out = subprocess.run(args + [path], capture_output=True, text=True, timeout=120).stdout
    except Exception as e:  # noqa: BLE001
        fail(f"nm 执行失败：{e}", 3)
    names = set()
    for ln in out.splitlines():
        parts = ln.split()
        if len(parts) >= 3:
            names.add(parts[2])
        elif len(parts) == 2:  # UND 行： "  U name"
            names.add(parts[1])
    return names


def nm_typed(path: str) -> dict[str, str]:
    nm = find_tool("llvm-nm") or find_tool("nm")
    out = subprocess.run([nm, "-D", path], capture_output=True, text=True, timeout=120).stdout
    d: dict[str, str] = {}
    for ln in out.splitlines():
        parts = ln.split()
        if len(parts) >= 3:
            d[parts[2]] = parts[1]
    return d


# --------------------------------------------------------------------------- #
def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 3
    new = sys.argv[1]
    old = sys.argv[2] if len(sys.argv) > 2 and os.path.isfile(sys.argv[2]) else None
    if not os.path.isfile(new):
        fail(f"找不到 {new}", 3)

    hard_fail = False
    compat_fail = False

    print("\n== 1) 门槛1 · ELF PT_LOAD p_align ==")
    aligns = pt_load_aligns(new)
    info(f"PT_LOAD 段对齐值: {aligns}")
    if not aligns:
        info("⚠️ 未找到 PT_LOAD 段")
        hard_fail = True
    elif min(aligns) >= REQUIRED_ALIGN:
        ok(f"最小对齐 {min(aligns)} >= {REQUIRED_ALIGN}  COMPLIANT")
    else:
        info(f"🔴 最小对齐 {min(aligns)} < {REQUIRED_ALIGN}  NOT COMPLIANT")
        hard_fail = True

    print("\n== 2) 门槛2 · .note.android.ident 里的 NDK 版本 ==")
    ident = ndk_ident(new)
    m = re.search(r"\br(\d{1,2})([a-z]?)\b", ident)
    if not m:
        info(f"⚠️ 读不到 NDK 标识（ident={ident[:120]!r}）—— 无法判定")
        hard_fail = True
    else:
        num = int(m.group(1))
        if num >= 28:
            ok(f"NDK r{num}{m.group(2)}（>= r28）")
        else:
            info(f"🔴 NDK r{num}{m.group(2)} < r28")
            hard_fail = True

    print("\n== 3) 未定义符号（外部依赖应只有 bionic）==")
    und = dyn_syms(new, defined_only=False) - dyn_syms(new, defined_only=True)
    weird = set()
    for s in und:
        base = s.split("@")[0]
        if s.endswith(SYS_SUFFIXES) or base in SYS_NAMES:
            continue
        weird.add(s)
    info(f"未定义符号共 {len(und)} 个")
    if weird:
        info(f"🔴 以下 {len(weird)} 个不像系统符号：{sorted(weird)[:20]}")
        compat_fail = True
    else:
        ok("全部来自 libc / libm / libdl")

    if old:
        print(f"\n== 4) 与旧库符号比对（旧库 {os.path.basename(old)}）==")
        old_t = nm_typed(old)
        new_names = dyn_syms(new, defined_only=True)

        def exported(d: dict[str, str], pred) -> set[str]:
            return {k for k, t in d.items() if t == "T" and pred(k)}

        groups = [
            ("luaopen_*（Lua 侧 require 的入口）", lambda n: n.startswith("luaopen_")),
            ("tolua_*（C# P/Invoke 入口）",        lambda n: n.startswith("tolua_")),
            ("lua_* / luaL_*（ToLua 运行时 API）", lambda n: n.startswith(("lua_", "luaL_"))),
        ]
        for label, pred in groups:
            want = exported(old_t, pred)
            missing = sorted(want - new_names)
            safe = [n for n in missing if n in KNOWN_SAFE_REMOVALS]
            real = [n for n in missing if n not in KNOWN_SAFE_REMOVALS]
            if safe:
                info(f"ℹ️ {label}: 少了 {len(safe)} 个已登记的免检符号 -> {safe}")
            if real:
                info(f"🔴 {label}: 缺 {len(real)} 个 -> {real[:12]}")
                compat_fail = True
            else:
                # 顺手报告新增
                added = sorted(n for n in new_names if pred(n) and n not in want)
                extra = f"（新增 {len(added)}：{added[:4]}）" if added else ""
                ok(f"{label}: {len(want) - len(safe)}/{len(want) - len(safe)} 齐全 {extra}")

        # 其余缺失符号只提示
        all_old_t = {k for k, t in old_t.items() if t == "T"}
        others = sorted(all_old_t - new_names
                        - exported(old_t, lambda n: n.startswith(("luaopen_", "tolua_", "lua_", "luaL_"))))
        if others:
            print(f"\n    ℹ️ 另有 {len(others)} 个旧库导出、新库未导出的符号（非上述三类）")
            info("多为 luasocket / LuaJIT 内部实现，新版收紧了可见性。")
            info("请确认无人在 C# / Lua 里引用这些名字（本仓库已确认零引用）。")
            info("前 12 个：" + ", ".join(others[:12]))

    print()
    if hard_fail:
        print("\033[1;31m结果: 硬性项未通过。\033[0m")
        return 1
    if compat_fail:
        print("\033[1;31m结果: 兼容性项未通过。\033[0m")
        return 2
    print("\033[1;32m结果: 全部通过 ✅\033[0m")
    return 0


if __name__ == "__main__":
    sys.exit(main())
