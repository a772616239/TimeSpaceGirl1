#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_aab_release_config.py —— AAB/APK 包内「出包开关」自检（离线、零依赖）。

为什么需要它
------------
CLIBuilder 过去没有「出包配置」这一步，命令行产的包一律沿用开发态设置，
最典型的就是 isOpenGM=1（GM 面板随包发布）。光看构建日志不算证据，必须**解包核验**。

原理（2026-10-12 从线上产物标定）
--------------------------------
GameSettings.settingInfo 是 [System.Serializable]，在场景 level0 的 SerializedFile 里
按**声明顺序**内联序列化；实测每个 bool 占 4 字节（与 int 同对齐），共 12 个 int32 小端：

  logLevel, isDebug, bundleMode, luaBundleMode, isUpdate, isSDK, isSDKLogin,
  isGuide, isOpenGM, isOpenTLog, isOpenBLog, originLan

标定证据：production completed v64 的 AAB（apks/2026-10-12/CLIBuild/011824.aab）
  base/assets/bin/Data/level0 中该 48 字节特征**精确命中 1 次**（offset 3792），
  值 = [0,0,1,1,0,0,1,0,1,0,0,10001] ⇒ isOpenGM=1，即线上包确实带 GM 面板。

口径（profile）
--------------
  dev      = [0,0,1,1,0,0,1,0,1,0,0,10001]  开发态，GM 面板开启（线上 v64 实测值）
  minimal  = [0,0,1,1,0,0,1,0,0,0,0,10001]  最小改动：只把 isOpenGM 置 0（与 dev 只差一位）
  full     = [0,0,1,1,1,0,0,1,0,0,0,10001]  完整「正式包」模板（isGuide/isUpdate 也打开）

用法
----
  python3 scripts/verify_aab_release_config.py <aab|apk> [--expect dev|minimal|full]

退出码：0 = 通过；1 = 不符合期望；2 = 用法/结构错误。
"""
import argparse
import struct
import sys
import zipfile

FIELD_ORDER = [
    "logLevel", "isDebug", "bundleMode", "luaBundleMode", "isUpdate", "isSDK",
    "isSDKLogin", "isGuide", "isOpenGM", "isOpenTLog", "isOpenBLog", "originLan",
]
ORIGIN_LAN = 10001
LEVEL_CANDIDATES = [
    "base/assets/bin/Data/level0",
    "assets/bin/Data/level0",
]


def pattern(is_debug, bundle, lua_bundle, is_update, is_sdk, is_sdk_login,
            is_guide, is_open_gm, tlog=0, blog=0, origin_lan=ORIGIN_LAN, log_level=0):
    vals = [log_level, is_debug, bundle, lua_bundle, is_update, is_sdk, is_sdk_login,
            is_guide, is_open_gm, tlog, blog, origin_lan]
    return b"".join(struct.pack("<i", v) for v in vals)


PROFILES = {
    # logLevel, isDebug, bundle, luaBundle, isUpdate, isSDK, isSDKLogin, isGuide, isOpenGM
    "dev":     pattern(0, 1, 1, 0, 0, 1, 0, 1),
    "minimal": pattern(0, 1, 1, 0, 0, 1, 0, 0),
    "full":    pattern(0, 1, 1, 1, 0, 0, 1, 0),
}
PROFILE_LABEL = {
    "dev": "开发态(带GM)",
    "minimal": "最小改动(只关GM)",
    "full": "完整正式包模板",
}


def decode_at(data, off):
    return dict(zip(FIELD_ORDER, struct.unpack_from("<12i", data, off)))


def load_level0(path):
    z = zipfile.ZipFile(path)
    names = set(z.namelist())
    for cand in LEVEL_CANDIDATES:
        if cand in names:
            return cand, z.read(cand)
    for n in z.namelist():
        if n.endswith("/Data/level0"):
            return n, z.read(n)
    raise KeyError("包内找不到 assets/bin/Data/level0")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("artifact")
    ap.add_argument("--expect", choices=sorted(PROFILES), default=None,
                    help="期望的口径；不给则只打印实际值")
    args = ap.parse_args()

    try:
        entry, data = load_level0(args.artifact)
    except KeyError as e:
        print(f"✗ {e}")
        return 2

    print(f"包内场景文件: {entry}  ({len(data)} B)")

    hits = []
    for name, pat in PROFILES.items():
        i = -1
        while True:
            i = data.find(pat, i + 1)
            if i < 0:
                break
            hits.append((name, i, decode_at(data, i)))

    if not hits:
        print("✗ 未命中任何已知 SettingInfo 特征 —— 布局可能已变（字段增删/顺序调整）。")
        print("  请按本脚本头部注释重新标定。")
        return 2

    for name, off, vals in hits:
        print(f"  命中 [{PROFILE_LABEL[name]}] @ offset {off}: " +
              " ".join(f"{k}={v}" for k, v in vals.items()))

    found = {h[0] for h in hits}

    if args.expect is None:
        if len(found) > 1:
            print(f"⚠ 同时命中多个口径 {sorted(found)}（可能包内存在多份 GameSettings 实例）")
        return 0

    if found == {args.expect}:
        print(f"✓ 通过：包内 SettingInfo = 【{PROFILE_LABEL[args.expect]}】"
              f"（isOpenGM={hits[0][2]['isOpenGM']}）")
        return 0

    if args.expect in found:
        print(f"✗ 失败：期望 {args.expect}，但包内同时命中其它口径 {sorted(found - {args.expect})}")
    else:
        print(f"✗ 失败：期望 {args.expect}，实际命中 {sorted(found)}")
        gm = hits[0][2]["isOpenGM"]
        if gm:
            print("  ⇒ isOpenGM=1：GM 面板会随包发布！")
    return 1


if __name__ == "__main__":
    sys.exit(main())
