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

口径（profile）—— 🔴 **只匹配前 11 个字段，不含 originLan**
--------------------------------------------------------
2026-10-13 起 release 分支的场景把 Inspector originLan 改成了英文 10101（commit `eb063a8db`），
而本脚本原先把 `10001` 写死在特征里 ⇒ 包内一改语言，第 4.5 步就整条误判为「未命中任何已知口径」
并拒绝上传。originLan **本来就不该是口径判据**：
  - 真机首次启动时 `GameSettings.InitGameSettings()`（GameSettings.cs:110-114）会用**设备系统语言**
    覆盖包内的 originLan，只有 Editor 才尊重 Inspector 值 ⇒ 它不影响发行行为；
  - 语言 id 权威表（conf/server/MultiLanguage.txt）：10001=简中 / 10101=English / 10201=日文 / 10301=韩文。
⇒ 现在特征只取**前 11 个 int32**（logLevel…isOpenBLog），第 12 个 originLan 仅解码出来**报告**。

  dev      = [0,0,1,1,0,0,1,0,1,0,0]  开发态，GM 面板开启（线上 v64 实测值）
  minimal  = [0,0,1,1,0,0,1,0,0,0,0]  测试包：只把 isOpenGM 置 0（与 dev 只差一位），**日志全开**
  full     = [0,0,1,1,1,0,0,1,0,0,0]  完整「正式包」模板（isGuide/isUpdate 也打开）
  release  = [4,0,1,1,0,0,1,0,0,0,0]  正式包（2026-10-22 起）：minimal + logLevel=Error（关日志）

用法
----
  python3 scripts/verify_aab_release_config.py <aab|apk> [--expect dev|minimal|release|full]

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
ORIGIN_LAN = 10001  # 仅作历史标定参考；**不参与匹配**（见文件头「口径」说明）
LEVEL_CANDIDATES = [
    "base/assets/bin/Data/level0",
    "assets/bin/Data/level0",
]


def pattern(is_debug, bundle, lua_bundle, is_update, is_sdk, is_sdk_login,
            is_guide, is_open_gm, tlog=0, blog=0, log_level=0):
    """口径特征 = 前 11 个 int32（**不含 originLan**）。

    originLan 随发行区域变化（英文 10101 / 简中 10001 / 日文 10201），且真机上会被
    设备系统语言覆盖，不能作为「出包开关是否套用」的判据。匹配到的 offset 仍是字段 0
    的起点，decode_at() 可从同一 offset 解出含 originLan 的完整 12 字段用于报告。
    """
    vals = [log_level, is_debug, bundle, lua_bundle, is_update, is_sdk, is_sdk_login,
            is_guide, is_open_gm, tlog, blog]
    return b"".join(struct.pack("<i", v) for v in vals)


PROFILES = {
    # logLevel, isDebug, bundle, luaBundle, isUpdate, isSDK, isSDKLogin, isGuide, isOpenGM
    "dev":     pattern(0, 1, 1, 0, 0, 1, 0, 1),
    "minimal": pattern(0, 1, 1, 0, 0, 1, 0, 0),
    "full":    pattern(0, 1, 1, 1, 0, 0, 1, 0),
    # 2026-10-22 起「正式包」= minimal + 关日志：logLevel=4(Error)。
    # 与 minimal 的唯一差别是第 1 个字段（logLevel 0→4），其余 10 位逐位相同。
    "release": pattern(0, 1, 1, 0, 0, 1, 0, 0, log_level=4),
}
PROFILE_LABEL = {
    "dev": "开发态(带GM)",
    "minimal": "测试包(只关GM，日志全开)",
    "full": "完整正式包模板",
    "release": "正式包(关GM + 关日志 logLevel=Error)",
}


def decode_at(data, off):
    # 完整 12 字段（含 originLan）—— 特征只匹配前 11 个，故末尾可能差 4 字节越界
    buf = data[off:off + 48]
    if len(buf) < 48:
        buf = buf + b"\x00" * (48 - len(buf))
    return dict(zip(FIELD_ORDER, struct.unpack("<12i", buf)))


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
