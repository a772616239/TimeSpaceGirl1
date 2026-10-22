#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""APK/AAB 交付自检 —— 一条命令回答「这个包能不能拿去测」。

为什么需要它
------------
2026-10-12 走过一个坑：为了绕开 Play 的 16KB 报障，临时把 `libnative-googlesignin.so`
从包里摘掉，打了 `090414.apk` / `093010.apk`。这两个包 sidecar 里写着
`"googlesigninRemoved": true`，**Google 登录必挂** —— 拿它们去验证「老号变新号」
只会得到假结论（一定注册成新号）。当时没有任何脚本会拦这种情况。

本脚本把「一个可交付/可测试的包」必须成立的几件事一次查完：

  1. 版本号（APK 用 aapt2 读真值；AAB 读同级 `.release.json` sidecar）
  2. 包内出包开关（SettingInfo）—— 复用 verify_aab_release_config.py
  3. 包内 native 库 16KB / NDK —— 复用 verify_aab_native_16kb.py
  4. 🔴 **`libnative-googlesignin.so` 必须存在**且 64 位对齐 >= 16384
     （缺了就等于把 Google 登录摘掉，账号派生链会走注册分支）
  5. 签名（APK 且本机有 apksigner 时）

用法：
    verify_apk_delivery.py <apk|aab> [--expect release|minimal|dev|full] [--no-sidecar]

退出码：0 = 可交付；1 = 有阻断项；2 = 用法/工具错误。
"""
import argparse
import glob
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
SIXTY_FOUR = ("arm64-v8a", "x86_64")
GOOGLESIGNIN = "libnative-googlesignin.so"

# aapt2 / apksigner 常见位置（Unity 自带的 Android SDK 也会装在这）
BUILD_TOOLS_GLOBS = [
    os.path.expanduser("~/Library/Android/sdk/build-tools/*"),
    os.path.expanduser("~/Android/sdk/build-tools/*"),
]


def find_tool(name):
    p = shutil.which(name)
    if p:
        return p
    cands = []
    for g in BUILD_TOOLS_GLOBS:
        cands += glob.glob(os.path.join(g, name))
    if not cands:
        return None
    # 取版本号最大的那个
    def key(p):
        m = re.search(r"/(\d+)\.(\d+)\.(\d+)/", p)
        return tuple(int(x) for x in m.groups()) if m else (0, 0, 0)
    return sorted(cands, key=key)[-1]


def load_elf_aligns(d):
    """返回 64 位 ELF 的全部 PT_LOAD p_align；非 64 位 ELF 返回 None。"""
    if d[:4] != b"\x7fELF":
        return None
    if d[4] != 2:
        return None
    e_phoff = struct.unpack_from("<Q", d, 0x20)[0]
    e_phentsize = struct.unpack_from("<H", d, 0x36)[0]
    e_phnum = struct.unpack_from("<H", d, 0x38)[0]
    out = []
    for i in range(e_phnum):
        o = e_phoff + i * e_phentsize
        if struct.unpack_from("<I", d, o)[0] != 1:
            continue
        out.append(struct.unpack_from("<Q", d, o + 0x30)[0])
    return out


def lib_abi(name):
    p = name.split("/")
    for i, seg in enumerate(p[:-1]):
        if seg == "lib" and i + 1 < len(p) - 1:
            return p[i + 1]
    return None


def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.returncode, (r.stdout or "") + (r.stderr or "")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("artifact")
    ap.add_argument("--expect", default=None, choices=["release", "minimal", "dev", "full"],
                    help="期望的出包口径（默认不校验，只打印实际命中）。release=正式包(关GM+关日志) / minimal=测试包(留日志)")
    ap.add_argument("--no-sidecar", action="store_true", help="不写 .delivery.json")
    args = ap.parse_args()

    art = os.path.abspath(args.artifact)
    if not os.path.isfile(art):
        print(f"✗ 找不到文件：{art}")
        return 2
    is_apk = art.lower().endswith(".apk")
    blocks = []          # 阻断项
    warns = []           # 关注项

    print(f"=== 交付自检：{os.path.basename(art)} ({os.path.getsize(art)/1048576:.2f} MB) ===")

    # ---------------- 1. 版本号 ---------------- #
    ver = {}
    if is_apk:
        aapt2 = find_tool("aapt2")
        if aapt2:
            rc, out = run([aapt2, "dump", "badging", art])
            m = re.search(r"versionCode='(\d+)' versionName='([^']*)'", out)
            if m:
                ver = {"versionCode": int(m.group(1)), "versionName": m.group(2)}
                print(f"  [版本] versionCode={ver['versionCode']} versionName={ver['versionName']}")
            else:
                warns.append("aapt2 未能解析出版本号")
        else:
            warns.append("未找到 aapt2，跳过版本号核验")
    else:
        side = art + ".release.json"
        if os.path.isfile(side):
            try:
                j = json.load(open(side, encoding="utf-8"))
                ver = {"versionCode": j.get("versionCode"), "versionName": j.get("versionName")}
                print(f"  [版本] versionCode={ver['versionCode']} versionName={ver['versionName']}"
                      f"  (来自 {os.path.basename(side)})")
            except Exception as e:
                warns.append(f"读取 sidecar 失败：{e}")
        else:
            warns.append("AAB 无同级 .release.json，无法核验版本号")

    # ---------------- 2. 包内 native 库 ---------------- #
    z = zipfile.ZipFile(art)
    libs = {}
    for n in z.namelist():
        if not n.endswith(".so"):
            continue
        abi = lib_abi(n)
        if not abi:
            continue
        d = z.read(n)
        libs[n] = {
            "abi": abi,
            "size": len(d),
            "md5": hashlib.md5(d).hexdigest(),
            "aligns": load_elf_aligns(d),
        }

    if not libs:
        warns.append("包内没有 native 库（纯 Java 应用则正常）")

    for n, info in sorted(libs.items()):
        if info["abi"] in SIXTY_FOUR:
            mn = min(info["aligns"]) if info["aligns"] else 0
            if mn < 16384:
                blocks.append(f"{n} 64 位对齐 {hex(mn)} < 16KB（Play 硬门槛不过）")

    # ---------------- 3. Google 登录 native 库（本次新增的关键闸门） ---------------- #
    gs = {n: i for n, i in libs.items() if os.path.basename(n) == GOOGLESIGNIN}
    gs64 = [n for n in gs if gs[n]["abi"] in SIXTY_FOUR]
    if not gs:
        blocks.append(
            f"包内缺少 {GOOGLESIGNIN} —— Google 登录会挂，"
            "账号派生链走注册分支，测不出真实老号（历史上 090414/093010.apk 就是这个坑）"
        )
        print(f"  [关键库] ✗ 找不到 {GOOGLESIGNIN}")
    elif not gs64:
        blocks.append(f"{GOOGLESIGNIN} 只有 32 位版本，没有 arm64/x86_64（现代设备加载不到）")
    else:
        for n in gs64:
            mn = min(gs[n]["aligns"]) if gs[n]["aligns"] else 0
            flag = "✓" if mn >= 16384 else "✗"
            if mn < 16384:
                blocks.append(f"{n} 对齐 {hex(mn)} < 16KB")
            print(f"  [关键库] {flag} {n}  align={hex(mn)}  md5={gs[n]['md5'][:12]}  {gs[n]['size']} B")

    # ---------------- 4. 复用两个既有校验脚本 ---------------- #
    def delegate(script, extra=()):
        rc, out = run([sys.executable, os.path.join(HERE, script), art, *extra])
        for line in out.rstrip().splitlines():
            print("  " + line)
        return rc

    print("  --- 出包开关（SettingInfo）---")
    cfg_rc = delegate("verify_aab_release_config.py",
                      ("--expect", args.expect) if args.expect else ())
    if cfg_rc != 0:
        blocks.append(f"包内出包开关不符合期望（verify_aab_release_config.py rc={cfg_rc}）")

    print("  --- native 库 16KB / NDK 体检 ---")
    nat_rc = delegate("verify_aab_native_16kb.py")
    if nat_rc != 0:
        blocks.append("native 库 16KB 体检未通过")

    # ---------------- 5. 签名（只有 APK 能查） ---------------- #
    signer = None
    if is_apk:
        apksigner = find_tool("apksigner")
        if apksigner:
            rc, out = run([apksigner, "verify", "--print-certs", art])
            ok = (rc == 0)
            m = re.search(r"certificate SHA-256 digest: ([0-9a-f]+)", out)
            signer = m.group(1) if m else None
            print(f"  [签名] {'✓ v2 通过' if ok else '✗ 校验失败'}  证书 SHA-256={signer}")
            if not ok:
                blocks.append("APK 签名校验失败")
            else:
                print("         注意：这是 **upload key**（beauty.keystore），"
                      "与 Play 的 app signing key 不同 ⇒ 侧载前需先卸载 Play 版")
        else:
            warns.append("未找到 apksigner，跳过签名校验")

    # ---------------- 结论 ---------------- #
    print()
    if blocks:
        print(f"✗ 不可交付：{len(blocks)} 个阻断项")
        for b in blocks:
            print(f"    - {b}")
    else:
        print("✓ 可交付：版本号 / 出包开关 / native 库 / Google 登录关键库 全部通过")
    if warns:
        print(f"⚠️ {len(warns)} 个关注项（不阻断）：")
        for w in warns:
            print(f"    - {w}")

    # ---------------- sidecar ---------------- #
    if not args.no_sidecar:
        payload = {
            "artifact": art,
            "sizeBytes": os.path.getsize(art),
            "kind": "apk" if is_apk else "aab",
            "versionCode": ver.get("versionCode"),
            "versionName": ver.get("versionName"),
            "expectProfile": args.expect,
            "settingInfoCheck": cfg_rc,
            "native16kbCheck": nat_rc,
            "nativeLibs": {os.path.basename(n): {
                "abi": i["abi"], "size": i["size"], "md5": i["md5"],
                "minAlign": min(i["aligns"]) if i["aligns"] else None,
            } for n, i in sorted(libs.items())},
            "googlesigninPresent": bool(gs64),
            "signerCertSha256": signer,
            "verdict": "pass" if not blocks else "fail",
            "blockers": blocks,
            "warnings": warns,
        }
        try:
            with open(art + ".delivery.json", "w", encoding="utf-8") as f:
                json.dump(payload, f, ensure_ascii=False, indent=2)
            print(f"\n  sidecar -> {os.path.basename(art)}.delivery.json")
        except Exception as e:
            print(f"\n  ! 写 sidecar 失败：{e}")

    return 1 if blocks else 0


if __name__ == "__main__":
    sys.exit(main())
