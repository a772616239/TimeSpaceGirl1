#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_aab_manifest_classes.py —— 出包「清单声明的组件 vs dex 实际类」一致性闸门（离线、零依赖）。

为什么需要它
------------
2026-10-19 线上崩溃：
  java.lang.RuntimeException: Unable to instantiate activity
    ComponentInfo{com.Warera.timespace/com.google.games.bridge.NativeBridgeActivity}:
    java.lang.ClassNotFoundException: Didn't find class "com.google.games.bridge.NativeBridgeActivity"

解包 vc69/vc70…vc74 全部产物还原出的事实链（本脚本即从这批产物标定）：

  | 产物                        | 清单声明 NativeBridgeActivity | dex 含该类 |
  |-----------------------------|-------------------------------|------------|
  | 1.2.50_vc69_170356.aab      | 是                            | 否         |
  | 1.2.51_vc70..vc74（aab/apk）| 是                            | 否         |

即：`Assets/Plugins/Android/GooglePlayGamesManifest.androidlib/AndroidManifest.xml:23`
把 `<activity android:name="com.google.games.bridge.NativeBridgeActivity">` 并进了最终清单，
而 `com.google.games:gpgs-plugin-support:0.11.01` 这个 AAR 的 classes.jar **一个类都没进 dex**
（`Lcom/google/games/` 在 dex 字符串池里 0 命中，而同批其他 SDK
play-services-auth / games / nearby / billing / review / firebase 全在）。
清单与代码走了两条互不相干的合并通道（androidlib 清单照并，maven 依赖没落地），
于是「声明了、但类不存在」⇒ 一旦有代码路径启动该 Activity 就是必崩。

这类错配**构建期完全不报错**（dependencies.pb 里甚至还有该坐标），只有解包比对才看得见，
所以做成闸门：任何「清单里声明、dex 里没有」的组件，直接 fail。

判据（保守，避免误报）
----------------------
1. 清单：AAB 取 `base/manifest/AndroidManifest.xml`（protobuf XML），APK 取 `AndroidManifest.xml`
   （binary AXML）。两者都不解析结构，只按 **UTF-8 / UTF-16LE 双编码**扫字符串——
   实测 AAB 用 UTF-8、APK 用 UTF-16LE 存串，只试一种会漏。
2. 候选类名：形如 `a.b.C`（**至少 3 段**）且以 Activity/Service/Receiver/Provider/Application 结尾
   （含 `$` 内部类）。两段名（如 `unityplayer.UnityActivity`）多是 meta-data 键或相对类名，
   不参与判据；排除 android./java./javax./kotlin./dalvik. 这类框架类（框架类本来就不进 dex）。
   二进制清单的串前面常粘着一个「长度/标签字节」（解出来像 `Acom.google...`），
   故对候选做「剥掉前置大写串」的变体还原，任一变体命中即算命中。
3. 命中判据：dex 里出现描述符 `La/b/C;`、路径 `a/b/C` 或裸点号名 `a.b.C` 任一。
4. 退出码：0 = 全部命中；1 = 有缺失（列出清单路径 + 类名 + 提示）。

用法
----
  python3 scripts/verify_aab_manifest_classes.py apks/2026-10-17/CLIBuild/1.2.51_vc74_204554.aab
  python3 scripts/verify_aab_manifest_classes.py apks/2026-10-17/CLIBuild/*.apk   # 可传多个
  python3 scripts/verify_aab_manifest_classes.py --json <artifact>                 # 机读输出
"""

import argparse
import json
import os
import re
import sys
import zipfile

# 组件后缀：Android 只会实例化这些类型的类，其余（meta-data 键、action 名等）不参与判据
COMPONENT_SUFFIX = ("Activity", "Service", "Receiver", "Provider", "Application")
# 框架类：由系统提供，本来就不在 dex 里
FRAMEWORK_PREFIX = ("android.", "java.", "javax.", "kotlin.", "dalvik.")
_FQCN = re.compile(r"[A-Za-z][\w$]*(?:\.[\w$]+)+")


def _unstick(tok):
    """还原被前置「标签字节」粘住的类名。

    protobuf/AXML 的串前面紧跟 1 字节 tag（0x0A/0x12/…/0x7A），其中 0x5A/0x62/0x68/0x6A…
    解成文本就是大写或小写字母，于是 `com.google…` 会变成 `Acom.google…` / `hcom.google…`。
    只可能是 1 个字符，且剥掉后首段仍是合法包名（长度≥3）才剥——否则会把
    `com.google…` 误剥成 `om.google…`。
    """
    if len(tok) > 4 and tok[0].isalpha() and tok[1].islower() and tok[1].isalpha():
        head = tok.split(".")[0]
        if len(head) >= 4:  # 首段比剥后长 1，且剥后仍 ≥3
            return tok[1:]
    return tok


def _manifest_path(names):
    """返回清单在压缩包内的路径，兼容 AAB / APK。"""
    for cand in ("base/manifest/AndroidManifest.xml", "AndroidManifest.xml"):
        if cand in names:
            return cand
    return None


def _dex_bytes(z, names):
    dex = [n for n in names if n.endswith(".dex")]
    return dex, b"".join(z.read(n) for n in dex)


def _strings_from_manifest(raw):
    """清单里的字符串，按 UTF-8（AAB）/ UTF-16LE（APK）各解一遍再并集。"""
    out = []
    try:
        out.append(raw.decode("utf-8", "ignore"))
    except Exception:
        pass
    try:
        out.append(raw.decode("utf-16-le", "ignore"))
    except Exception:
        pass
    try:
        out.append(raw.decode("utf-16-be", "ignore"))  # 兜底：个别工具链写 BE
    except Exception:
        pass
    return out


def in_dex(blob, cls):
    """类是否真的在 dex 里。

    只认 dex 的类型描述符 `La/b/C;`（以及 `La/b/C$` 的内部类前缀）——
    不能用裸路径做子串匹配：`androidx/…` 里天然包含 `ndroidx/…`，会假阳性。
    """
    path = cls.replace(".", "/").encode()
    return (b"L" + path + b";") in blob or (b"L" + path + b"$") in blob


def _unstick(tok, blob):
    """还原被前置「标签字节」粘住的类名。

    protobuf/AXML 的串前面紧跟 1 字节 tag（0x0A/0x12/…/0x7A），其中 0x41/0x59/0x62/0x68/0x6A…
    解成文本就是大写或小写字母，于是 `com.google…` 会变成 `Acom.google…` / `hcom.google…`。
    只可能是 1 个字符 ⇒ 用「剥掉后能否在 dex 里命中」反向确认：命中才剥。
    否则会把 `androidx.startup…` 剥成 `ndroidx.startup…` 这种乱码。
    """
    if len(tok) > 4 and tok[0].isalpha() and tok[1].isalpha():
        if len(tok.split(".")[0]) >= 4 and in_dex(blob, tok[1:]):
            return tok[1:]
    return tok


def declared_components(raw_manifest, blob):
    """从清单字节里抽取「看起来是组件类」的候选名（去重、保序）。"""
    found, seen = [], set()
    for text in _strings_from_manifest(raw_manifest):
        # 二进制清单的串带长度前缀/交错字节，直接按 FQCN 形态做子串扫描最稳
        for m in _FQCN.finditer(text):
            cand = _unstick(m.group(0).strip("."), blob)
            if cand.startswith(FRAMEWORK_PREFIX):
                continue
            if not cand.endswith(COMPONENT_SUFFIX):
                continue
            if cand.count(".") < 2:  # 至少 a.b.C
                continue
            if cand not in seen:
                seen.add(cand)
                found.append(cand)
    return found


def check(path):
    res = {"artifact": path, "size_mb": round(os.path.getsize(path) / 1e6, 1),
           "manifest": None, "dex_files": [], "declared": [], "missing": []}
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        mp = _manifest_path(names)
        if mp is None:
            res["missing"] = ["<manifest not found>"]
            return res
        res["manifest"] = mp
        dex, blob = _dex_bytes(z, names)
        res["dex_files"] = dex
        if not blob:
            res["missing"] = ["<no dex in package>"]
            return res
        comps = declared_components(z.read(mp), blob)
        res["declared"] = comps
        res["missing"] = [c for c in comps if not in_dex(blob, c)]
    return res


def main():
    ap = argparse.ArgumentParser(description="校验清单声明的组件是否真的在 dex 里")
    ap.add_argument("artifacts", nargs="+", help="AAB 或 APK 路径（可多个）")
    ap.add_argument("--json", action="store_true", help="只输出 JSON")
    args = ap.parse_args()

    results, bad = [], 0
    for p in args.artifacts:
        if not os.path.exists(p):
            print(f"[ERR] 文件不存在: {p}", file=sys.stderr)
            bad += 1
            continue
        try:
            r = check(p)
        except Exception as e:  # 损坏包 / 非 zip
            print(f"[ERR] {p}: {e}", file=sys.stderr)
            bad += 1
            continue
        results.append(r)
        if r["missing"]:
            bad += 1

    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
        return 1 if bad else 0

    for r in results:
        print(f"\n=== {os.path.basename(r['artifact'])}  ({r['size_mb']} MB) ===")
        print(f"  manifest : {r['manifest']}")
        print(f"  dex      : {', '.join(r['dex_files']) or '-'}")
        print(f"  声明组件 : {len(r['declared'])} 个")
        for c in r["declared"]:
            mark = "MISSING" if c in r["missing"] else "ok"
            print(f"    [{mark:7s}] {c}")
        if r["missing"]:
            print("  🔴 清单声明但 dex 缺失：")
            for c in r["missing"]:
                print(f"      - {c}")
            print("     根因方向：对应的 AAR/JAR 没进构建（清单走了 androidlib 合并通道，"
                  "依赖却没落到 classpath）。修 AAR 或删清单声明，二选一。")

    if bad:
        print(f"\n🔴 FAIL: {bad} 个包存在「声明了但没有类」的组件")
        return 1
    print("\n✅ PASS: 所有清单声明组件均在 dex 中")
    return 0


if __name__ == "__main__":
    sys.exit(main())
