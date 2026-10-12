# libtolua.so 16KB 改造工具

重编译 `Assets/Plugins/Android/libs/arm64-v8a/libtolua.so`，使其满足 Google Play
的 16KB 页大小要求。

## 为什么需要

`libtolua.so` 是 ToLua# 运行时，把 **LuaJIT + tolua + cjson + lpeg + pb(protobuf)
+ luasocket + struct + bit** 全部打包进一个 `.so`。仓库里只有编译产物、没有源码。

存在两个问题：

| # | 问题 | 后果 |
|---|------|------|
| 1 | 原库由 NDK r17 时代工具链编译，ELF `PT_LOAD p_align` 不满足 16KB | Play 硬性门槛，2025-11 后新包会被拒 |
| 2 | LuaJIT `lj_arch.h` 默认 `LJ_PAGESIZE=4096` | JIT 的 mcode 分配器按 4096 对齐后调 `mprotect`，在 16KB 页设备上被内核拒绝 → **真崩**，不只是告警 |

第 2 条是这条链上真正的隐患：即使对齐过了，没改 `LJ_PAGESIZE` 也会在 16KB 设备上
出现 JIT 代码页无法生效的崩溃。

## 上游与补丁

- 上游：<https://github.com/alex4814/tolua_runtime>（pin 在 `build.sh` 的 `PINNED_COMMIT`）
- 补丁：`apply-16k.patch`（改动仅 2 个文件、3 行 + 注释）

```
cmake/luajit2.cmake   + if (ANDROID) set(LUAJIT_XCFLAGS "... -DLJ_PAGESIZE=16384") endif ()
CMakeLists.txt        + luasocket/src/mime.c     （否则 luaopen_mime_core 缺失）
CMakeLists.txt        + ${PROTOBUF_SRC} → pb.c   （否则 luaopen_pb 缺失）
```

后两条是上游 `CMakeLists.txt` 自身的疏漏：`PROTOBUF_SRC` 定义了却没进
`add_library` 的源列表，`LUASOCKET_SRC` 漏了 `mime.c`。不补的话新库会少两个
`luaopen_*`，Lua 侧 `require` 直接失败。

## 用法

```bash
export ANDROID_NDK_HOME=/path/to/android-ndk-r28     # 必须 r28+
scripts/libtolua16k/build.sh                         # 克隆 → 打补丁 → 编译 → 校验
scripts/libtolua16k/build.sh --install               # 校验通过后替换进工程（先备份旧库）
scripts/libtolua16k/build.sh --src /path/to/checkout # 复用已有检出
```

`build.sh` 只在**全部校验通过**后才会 `--install`；任一项不过就直接中止，
不会覆盖工程内的库。

单独跑校验：

```bash
python3 scripts/libtolua16k/verify.py <new.so> [old.so]
```

## 校验项

硬性：

1. ELF `PT_LOAD` 最小 `p_align >= 16384` — Play 门槛1
2. `.note.android.ident` 里 NDK `>= r28`

兼容性（防重编后运行时缺符号）：

3. 旧库导出的 `luaopen_*` 必须全在 — Lua 侧 `require` 入口
4. 旧库导出的 `tolua_*` 必须全在 — C# P/Invoke 入口
5. 旧库导出的 `lua_*` / `luaL_*` 必须全在 — ToLua 运行时 API
6. 未定义符号只应来自 libc / libm / libdl

第 5 项有一份 `KNOWN_SAFE_REMOVALS` 免检名单（当前只有 `lua_getexdata` /
`lua_setexdata`，已确认本仓 C# 与 Lua 零引用）。**只允许往里加已 grep 确认零引用的
符号** —— 未登记的新增缺失仍会判失败，这道闸门在下次重编时依然有效。

## 已知的非问题

重编后旧库有 **110 个 `T` 符号不再导出**，全部是 luasocket / LuaJIT 内部实现
（`socket_*` / `opt_*` / `auxiliar_*` / `timeout_*` / `buffer_*` / `inet_*` …）。

这不是功能缺失：它们仍以 **local 符号**链入本库（`nm` 里是 `t`），只是不再出现在
动态符号表里 —— 新版工具链收紧了可见性。这些函数是通过 `luaL_Reg` 函数指针表注册
给 Lua 的，不依赖动态符号查找；且已 grep 确认 C#(`*.cs`) 与 Lua(`~Lua/`) 全仓零引用。

另外 LuaJIT 版本从 `2.1.0-beta3`(2017) 升到 `2.1.ROLLING`(2025-01)，多了一个
`luaopen_string_buffer`（新版 lpeg 自带），属向后兼容的新增。

## 复现记录

| 日期 | 版本 | 结果 |
|------|------|------|
| 2026-10-12 | NDK r28 + `LJ_PAGESIZE=16384` | 667,968 → 791,672 字节（已 strip）；门槛1/2 全过；AAB 内 `libtolua.so` 为 r28 |

产物哈希（stripped, arm64-v8a）：
`311fcf3a196aaea11ee1024c454b54ca18422cf48b4f5c695c0744187f8122e7`

## 相关

- `scripts/play_16kb_watch.py` — 对最新 AAB 做 16KB 两层巡检
- `scripts/aab_release.sh` — 打包 / 校验 / 上传（上传需人工确认）
