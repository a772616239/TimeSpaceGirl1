# libtolua.so 16KB 重编译工具

重编译 `Assets/Plugins/Android/libs/arm64-v8a/libtolua.so`，使其满足 Google Play
的 16KB 页大小要求，**同时保证与现有 Lua 字节码完全兼容**。

```bash
export ANDROID_NDK_HOME=/path/to/android-ndk-r28
scripts/libtolua16k/build.sh              # 编译 + 4 项校验
scripts/libtolua16k/build.sh --install    # 校验通过后替换进工程（自动备份旧库）
```

## 为什么需要

`libtolua.so` 是 ToLua# 运行时，把 **LuaJIT + tolua + cjson + lpeg + pb(protobuf)
+ luasocket + struct** 打包成一个 `.so`。仓库里只有编译产物、没有源码。

需要重编的两个原因：

| # | 问题 | 后果 |
|---|------|------|
| 1 | Play「旧版 NDK 编译」告警按【已知问题库清单】点名，libtolua.so 在列 | 告警（2027-02 前不阻断发布） |
| 2 | `luajit-2.1/src/lj_arch.h` 默认 `LJ_PAGESIZE=4096`，而 JIT 的 mcode 分配器（`lj_mcode.c`）按该值对齐后调 `mprotect` | **16KB 页设备上被内核拒绝 ⇒ 真崩** |

> ⚠️ 注意：原库的 `PT_LOAD p_align = 0x10000`（64KB），**本来就远超 16KB**。
> 所以门槛1（硬对齐）从来不是它的问题，真正要修的是上面的第 2 条运行时隐患。

## 🔴 血泪教训：运行时 LuaJIT 必须与字节码编码器同版本

2026-10-12 真机实测踩到的坑，**这个工具的第一版就是这么翻车的**：

真机跑的是**预编译字节码**（`Assets/ManagedResources/LuaBytes/*.bytes`，2910 个），
由 `LuaEncoder/luajit_mac/64/luajit` 生成，那是 **LuaJIT 2.1.0-beta3**。

第一版修复用了 `alex4814/tolua_runtime`，它的 LuaJIT 子模块是 **2.1.ROLLING (2025-01)**。
两个版本同属 2.1 线、`BCDUMP_VERSION` 都是 2，所以字节码头 `1b 4c 4a 02`
**不会被拒绝** —— 但 **opcode 表在 beta3 与 ROLLING 之间有增删**，加载后执行错指令
／JIT 出错，真机表现是**启动即卡死、进不去登录界面**。

⇒ 本工具因此固定在 `topameng/tolua_runtime`（LuaJIT **2.1.0-beta3**），
并由 `verify.py` 的 **④ 号校验**强制比对「`.so` 内版本串 == LuaEncoder 版本」，
下次再换错版本会**在校验阶段就被拦下**，不会流到包里。

**别用 `alex4814/tolua_runtime`。** 它更新了 LuaJIT 与 cjson，与本工程不匹配。

### 同源取证

```
topameng/tolua_runtime 的 Plugins/Android/libs/arm64-v8a/libtolua.so
  sha256 = 176274e75a380e97c209deacc63e372a3c9adc066d6ff59c671e62ebeb376a2f  (667968 字节)
本工程原库 libtolua.so
  sha256 = 176274e75a380e97c209deacc63e372a3c9adc066d6ff59c671e62ebeb376a2f  (667968 字节)
```
⇒ 原库就是它出的，这是**同源重建**，不是换个上游凑合。

## 上游与补丁

- 上游：<https://github.com/topameng/tolua_runtime>
  pin 在 commit `654e0da626328a6c4cf9824c4e50f31109ddae4e`（可用 `TOLUA_RT_COMMIT` 覆盖）
- 补丁：`apply-16k.patch` —— **只改 1 个文件 1 行 + 注释**：
  `luajit-2.1/src/lj_arch.h` 的 `LJ_PAGESIZE` `4096 → 16384`

## 构建流程与两个坑

`build.sh` 做的事：克隆 → 打补丁 → 编 `libluajit.a` → 链接 `libtolua.so` → 校验 → strip。

### 坑 1：LuaJIT Makefile 的 `CROSS` 会与 `CC` 拼接

Makefile 里是：
```make
STATIC_CC  = $(CROSS)$(CC)
TARGET_LD  = $(CROSS)$(CC)
TARGET_AR  = $(CROSS)ar rcus
TARGET_STRIP = $(CROSS)strip
```
如果同时给 `CROSS=/path/llvm-` 和 `CC=/path/clang`，会拼成
`/path/llvm-/path/clang` 报 `Command not found`。

⇒ 正确姿势：**`CROSS` 留空、`CC` 给完整路径**，并逐项覆盖
`TARGET_LD` / `TARGET_AR` / `TARGET_STRIP`。

### 坑 2：`HOST_CC` 默认继承 `CC`

`HOST_CC= $(CC)`。若不显式设置，`buildvm` 会被 Android clang 编出来、本机跑不了。

⇒ 必须显式 `HOST_CC="clang -m64"`（本机编译器）。

### 源文件清单

严格照抄上游 `android/jni/Android.mk` 的 `LOCAL_SRC_FILES`，写在 `build.sh` 的
`TOLUA_SRCS` 数组里。**不含** `bit.c`（LuaJIT 自带 `lib_bit`）、`serial.c`、
`unix.c`、`wsocket.c` —— 少编或多编都会改变导出符号集合，校验 ③ 会拦住。

`libluajit.a` 用 `-Wl,--whole-archive` 整体链入（对应 Android.mk 的
`LOCAL_WHOLE_STATIC_LIBRARIES`）。

## 校验（4 项全硬性）

`verify.py` 可单独跑：`verify.py <libtolua.so>`

| # | 项 | 判据 |
|---|----|------|
| ① | 16KB 页对齐 | 所有 `PT_LOAD` 的 `p_align` ≥ 16384 |
| ② | NDK 版本 | `.note.android.ident` ≥ r28（识别 `Android.r28130041008` 与旧式 `Android (13004108)`） |
| ③ | 导出符号 | 对 `ref/original-symbols.txt`（原库 380 个动态 `T` 符号）**零缺失**；新增不判失败但会列出 |
| ④ | LuaJIT 版本 | `.so` 内版本串 == `LuaEncoder/luajit_mac/64/luajit -v` 的版本 |

`build.sh` 在 **install 之前和 strip 之后**各跑一次；任一项不过即中止，**不会覆盖工程内库**。

### `ref/` 基准文件

- `original-symbols.txt` —— 原库（= 上游预编译产物）的 380 个动态导出符号，校验 ③ 的基准
- `expected-luajit-version.txt` —— `LuaJIT 2.1.0-beta3`，LuaEncoder 跑不了时的回退基准

## 已知非问题

- **Firebase / crashlytics / Unity 自出库**（r21e / r23b / r25b）从未被 Play 点名，
  不要因为「NDK < r28」就去动它们。
- **Play 点名是按【库文件名】匹配的**，与 NDK 版本阈值无关。文件名含版本号的库
  （如 `libFirebaseCppApp-12_8_0.so`）一换版本就等于换了名字 —— Firebase
  12.8.0→12.10.1 就是这么让告警从 5 个降到 2 个的（这些库实测仍是 r21e）。
- **升 Unity 引擎解决不了 16KB**：引擎只管 `libunity`/`libil2cpp`/`libmain`/`burst`，
  这些早已合规。

## 相关

- 发版管线：`scripts/aab_release.sh`、`scripts/play_upload.py`
- 16KB 巡检：`scripts/play_16kb_watch.py`
- 取证工具（跨仓）：`main_android/Release/tools/{verify_16k,so_meta}.py`
