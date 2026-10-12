# 参考：Android 发版管线（AAB → Google Play）与 AssetBundle 链路

> 从 `MEMORY.md` 拆出（2026-10-12），内容未改动，仅迁址以免主记忆文件过大。原主文件中该段曾重复两遍，此处已合并去重。
> 出海发版、重建资源、排查包体异常时读本文件。

## 工具与产物
- 一键入口 `scripts/aab_release.sh`（提号 → Unity batchmode 打包 → 校验 → 上传）；配套 `scripts/play_upload.py`（Play Developer API v3）、`scripts/bump_version.py`（提号）、`scripts/check_ab_ready.sh`（AB 只读体检，退出码 0/1）。
- 文档 `docs/google_play_upload_setup.md`；项目 skill `.workbuddy/skills/play-aab-release/`。打包侧坑位真源 = `docs/unity_android_build_skill.md`。
- 产物落 `apks/{日期}/CLIBuild/{时间}.aab` + 同名 `.json` sidecar 记 versionCode；`apks/` 已 gitignore。`AutoSignKeystore.cs` 打包前自动注入 keystore，无需手动配。

## 🔴 versionCode
- **CLI 打包不自增 versionCode**：`Assets/Editor/CLIBuilder.cs` 只读，自增只在 GUI 的 `BuildWindow.cs:449` ⇒ CLI 反复打包复用同一个号（实测日志 `VersionCode: 62`），传 production 必被拒。
- `aab_release.sh` 默认调 `bump_version.py --bump` 补上；`play_upload.py` 上传前查轨道现有 versionCode，撞车以退出码 5 拦截。

## 🔴 versionName（`bundleVersion`）长期未推进 —— Play 告警定位的坑
- `bundleVersion` 自 `b2a0037a9`（2026-08-17，`1.2.44 → 1.2.45`）起**再没改过** ⇒ **v62 / v63 / v64 三个包共用同一个 versionName `1.2.45`**（`b2a0037a9`=62、`e07c23190`=63、`2eaecca00`=64）。
- ⇒ **Play Console 的「发布版本名称：1.2.45」不能区分这三个包**，只有括号里的 versionCode（如 `1.2.45 (64)`）能。核对告警所属版本时**必须以 versionCode 为准**。
- 发版时应同时推进 versionName：`bump_version.py --bump-name`（本次未执行，属待改流程缺陷）。

## 认证 / 授权
- 认证 = Google Cloud service account JSON。🔴 **Cloud 建完账号 ≠ 能发布**：必须在 Play Console「用户和权限」把该邮箱加为发布用户并勾「发布到正式版」，否则 API 一律 403。密钥放 `~/.gplay/service-account.json`（仓库外），Cloud 项目 `platinum-loop-468100-k5`。
- 依赖 `google-api-python-client` + `google-auth`（⚠️ PyPI 直连超时，**用清华镜像** `-i https://pypi.tuna.tsinghua.edu.cn/simple`）。本机无 fastlane/Ruby，故走 API 直连。

## 🔴 上传 421MB 大包：必须放宽超时 + 缩小分块（2026-10-12 实测踩坑）
- 三层根因：① `google-auth-httplib2` 硬给 httplib2 设 `timeout=60`；② `MediaFileUpload` 默认 `chunksize=100MB`；③ 走本机代理（`HTTP_PROXY=127.0.0.1:52954`，~400KB/s）单块需 4 分钟 ⇒ 必被 `TimeoutError` 打断。
- `play_upload.py` 已内置：`widen_http_timeout()` 提到 300s **并 clear `.connections`**（httplib2 只在建连时读 timeout，不清缓存复用旧连接仍是 60s）+ `chunksize=8MB` + 断点续传重试（8 次指数退避）+ 异常回滚 edit。
- 可覆盖：`PLAY_UPLOAD_TIMEOUT_S` / `PLAY_UPLOAD_CHUNK_MB` / `PLAY_UPLOAD_MAX_RETRIES`。421MB 实测约 8 分钟。
- 已发版：**production v64**（2026-10-12，421MB，Firebase Unity SDK 12.10.1）；历史 v63（同日，12.8.0，含完整 bundles + Lua）、v62（2026-08-17，421MB）。

## 🔴 Play edit 互斥：上传期间禁止并发调用 Play API（2026-10-12 实测）
- 现象：v64 上传跑到 **85%** 时 `HTTP 400 / FAILED_PRECONDITION / This Edit has been deleted`，整包失败（`play_upload.py` 退出码 4）。
- 根因：**上传过程中另一个进程对该 App 调了 Play API 并 insert 了新 edit**（当时我在跑 `play_16kb_watch.py --dry-run`）⇒ 同一 App 的并发 edit 互相作废，上传绑定的 edit 被判 deleted。
- 处置：直接重跑 `play_upload.py`（会新建 edit 重传）。🔴 **不要用 `aab_release.sh` 重跑** —— 它默认 `--bump`，会再提一次 versionCode 导致号段跳空。
- 规则：**上传/发布进行中，不要跑巡检、dry-run 或任何会 `edits.insert` 的工具**。已写进 `play_16kb_watch.py` 文档头与 `docs/google_play_upload_setup.md §5`。

## Play 16KB 合规巡检（2026-10-12 起）
- 工具 `scripts/play_16kb_watch.py`（轨道现状 + 两层取证 + diff + 邮件）；定时任务 id `ea56e5de-abc2-45c2-abb9-401505a65a96`（每 3 天 10:00）。
- 🔴 报告必须区分「Play 点名」与「仅 NDK 阈值偏旧」：`NDK < r28` ≠ 被点名。v64 实测 < r28 有 12 个，Play 只点名 4 个 + tolua 无法判定；Unity 自出库（il2cpp/unity/main r23b）与 crashlytics（r25b）从不被点名。
- 🔴 Play Console 的 16KB 告警**无公开 API**，只能人工看「发布 → App Bundle 浏览器 → 选择版本 → 支持的页大小」。

## 🔴 AssetBundle 打包链路（出包必读）
三段式，**任一段没跑 Unity 打包都不报错**，只静默把陈旧/缺失资源打进包：
```
BuildABs/Android/                                  ← AssetBundleConfig.GetExportPath(Android)
   ↑ FrameTool.BuildGameAssetBundles()            GUI「整体打包资源」（先删该目录）
   ↓ FrameTool.CopyAssetBundleToStreamingAssets() GUI「复制资源到流媒体目录」（先删该目录）
Assets/StreamingAssets/Android/                    ← AAB 包内资源**唯一来源**
   ↑ FrameTool.BuildLuaAssetBundles()             GUI「单打lua资源」（只重建 Lua，供只改 Lua 时用）
```
- 顺序必须「整体打包资源」→「复制资源到流媒体目录」。`ResourcesCopy.cs` 的「Build/资源拷贝」依赖 `EditorUtility.OpenFolderPanel`，batchmode 不可用，别混淆。
- **可 CLI 调用的全名**（namespace = `GameEditor.FrameTool`）：
  `GameEditor.FrameTool.FrameTool.BuildGameAssetBundles` / `.CopyAssetBundleToStreamingAssets` / `.BuildLuaAssetBundles` / `.MarkGame`
  实测：重建 5.5 分钟（2755 个标记 → 三轮 LZ4/LZMA/None），拷贝 16 秒。末尾 `EditorUtil.OpenFolderAndSelectFile`（`EditorUtility.RevealInFinder`）batchmode 下无碍，退出码 0。
- 🔴 **两方法都会先整目录删目标**（`BuildABs/Android`、`StreamingAssets/Android`），且**两者均被 gitignore、无 git 兜底** ⇒ 动手前**必须备份**（`cp -R` 到仓库外）。
- 🔴 **完整包 2739~2740 个 bundle / 415MB**；低于此数即为残包。2026-10-12 实测旧构建只有 2111 个 / 113MB，**少了 628 个 / 301MB**（prefabs 264、texture 107、spine 104、audio 56、atlas 47、artfont_* 43、font、iconsprite）—— 新的严格是旧的超集（仅旧有 = 0）。这就是「AAB 139MB vs 421MB」的真相：**不是素材被删，也不是漏包，是旧 AB 构建本身只产出了约 3/4 资源**。
- **Lua bundle 真实命名 = `lzma|luabytes.unity3d`**（**不带 lua 前缀、不在 `lua/` 目录**）：`LuaBytes.meta` → `assetBundleName: lzma/luabytes` + `variant: unity3d` → `BuildABs/Android/lzma/luabytes.unity3d` → CombinePack 经 `AssetBundleBuilder.BuildSelectAssetBundles:348` 的 `name.Replace("/","|")` → `lzma|luabytes.unity3d`。同理 `lzma|resconfigs.unity3d`。
  - ⚠️ `Assets/StreamingAssets/lua/`（2026-09-17 创建）是**遗留空目录**，不可当判据。`Packager.cs:156` 的 `lua/lua_*` 命名属**旧 BuildGame 路径**，FrameTool 流程不用。
  - 登记链：`BuildConfigs.asset` 的 `OneFloderOneBundle` 含 GUID `83cf30c5b8fffbb4486da15ecdbd3d40`（= LuaBytes），compressType 2(LZMA)；无此登记则 MarkGame 不会标记。
- **体检**：`scripts/check_ab_ready.sh` 五段（源侧 .meta/BuildConfigs → BuildABs → StreamingAssets → 陈旧度 → 最新 AAB 是否含 luabytes）；`aab_release.sh` 前置闸门检测缺失即中止，`--allow-no-lua` 可强制。
  ⚠️ 陈旧度要比较**最新 bundle 文件** mtime，**不能用目录 mtime**（目录 mtime 会被无关 touch 刷新，实测比内部 bundle 新 2 个月）。
- 🔴 **改 Lua 必须成对提交 `~Lua` 源码 + `LuaBytes` 字节码**（见主记忆「客户端 Lua」章）。AB 重建会经 `MarkGame → CopyLuaFiles() → Packager.EncodeLuaFile()` 重编全部字节码（`LuaEncoder/luajit_mac/64/luajit -b`，无 `-g`）。⚠️ `EncodeLuaFile` 是 `Process.Start` 后**不等待**，但 `CopyLuaFiles` 先删光再全量重编 —— 若某 `.lua` 有语法错误，该文件**静默没有字节码**。已用全部 1456 个 `.lua` 与 LuaBytes 逐一比对验证一次。
  - **已知既有问题**：`~Lua/Modules/Arena/View/ArenaView.lua:192` 语法错误（`return` 后还有语句）⇒ `Modules_Arena_View_ArenaView_64.bytes` 不存在（git 全历史从未有过）。但全树**无任何引用**（死代码），不影响运行。未修 —— 修了会产生新 bundle、需重发版。

## 本机 shell 坑（发版脚本踩过）
- 🔴 **BSD `find` 不支持 `-newermt`**（报 `bad date` 且静默返回空），要用 `-mmin`。
- 🔴 **含中文标点的脚本变量必须写 `${VAR}` 花括号**。
- 🔴 **`set -o pipefail` 下 `cmd | head -1` 必须加 `|| true`**。

## 16 KB 页大小合规（Play 两层告警，2026-10-12 取证）
Play 的 16 KB 告警**是两层、彼此独立**，别混为一谈：

| 层 | 文案特征 | 判定 | 修法 |
|---|---|---|---|
| **门槛 1** 硬对齐 | 「应用不支持 16 KB 页大小」 | 每个 `.so` 的 `PT_LOAD` `p_align ≥ 16384` | 换 16KB 对齐的库 |
| **门槛 2** 旧 NDK | 「**已针对 16 KB 编译，但某些库用旧版 NDK 编译…可能崩溃**」 | Play 的**已知问题库清单**（⚠️ 不是 NDK 版本阈值） | **只能替换/上游重编** |

### v63 实测（`apks/2026-10-12/CLIBuild/002113.aab`）
- **门槛 1：13 个 ELF，0 不合规** —— 全过（`verify_16k.py`，exit 0）。
- **门槛 2 被点名 5 个**（都是第三方预编译/自编库）：
  | .so | NDK | p_align |
  |---|---|---|
  | `libFirebaseCppAnalytics.so` | r21e | 16384 |
  | `libFirebaseCppApp-12_8_0.so` | r21e | 16384 |
  | `libFirebaseCppCrashlytics.so` | r21e | 16384 |
  | `libnative-googlesignin.so` | **r17 / GCC** | 65536 |
  | `libtolua.so` | 无 `.note.android.ident` | 65536 |
- **Unity 自出库未被点名**：`libil2cpp/libunity/libmain` 全是 **r23b**（因为本项目已是 **Unity 2022.3.62f2c1**）。

### 🔴 结论：升 Unity 对这条告警零收益
- 本项目已在 `2022.3.62f2c1` —— **正是跨仓 `main_android` 那份 skill 里「路径 B 想升到的目标版本」**。Unity 侧已达标（`libmain.so` r23b 未被点名，而其 Unity 2020.3 的 r19 `libmain.so` 会被点名）。
- 被点名的 5 个全是 **Unity 永不编译**的第三方库 ⇒ 升引擎一个都不会少，却要付整包重导 + 2740 个 AB 重打 + 全量回归的代价。

### 正确修法（对齐 `main_android` 的路径 A）
- **Firebase Unity SDK `12.8.0 → 12.10.1`**：源在 `Assets/Firebase/m2repository/com/google/firebase/*-unity/12.8.0/`。顺带修 **issue #1259**（12.8.0 在 Android 15/16KB 模式**启动即崩**，崩在 `SWIGRegisterExceptionCallbacks()`）—— 这是真崩溃，不只是告警。
  - ⚠️ C# 与 native 必须**同版本**升级（`DllImport` 名含版本号 `FirebaseCppApp-<ver>`）；本项目**无 HybridCLR**（无 `*.dll.bytes`），故「AOT 补充元数据同步重生成」这条不适用。
- **`libnative-googlesignin.so`**：r17/GCC，比 clang 时代还早，须换新版 Google Sign-In 插件（`Assets/GoogleSignIn/`）。
- **`libtolua.so`**：tolua 开源、**自家可编** ⇒ 用 NDK r28 重编即符合 Play 文案第一方案。

### ✅ 本次执行（2026-10-12，v64 = `apks/2026-10-12/CLIBuild/011824.aab`）
只做路径 A 的第 1 条（升 Firebase），**不碰 Unity 版本**：
- **实际改动**：`12.8.0 → 12.10.1`，替换 managed/iOS/Editor DLL + `m2repository`(.srcaar) + `GeneratedLocalRepo`(.aar)，三处 `Dependencies.xml` 与 `mainTemplate.gradle` 同步，12.8.0 产物全部移入备份 `~/ts-firebase-backup-20261012-011235/`。versionCode 63→64。
- **验证**：包内 `libFirebaseCppApp-12_10_1.so` ✅、`12_8_0` 残留 0 ✅、`verify_16k.py` **13 ELF / 0 不合规** ✅。
- **实测确认了反直觉结论**：`libFirebaseCpp*` 三库升级后 `.note.android.ident` **仍是 r21e**（`so_meta.py` 实测）⇒ **门槛 2 告警不会消失**，本次收益 = 修 issue #1259 真机崩溃。
- ⚠️ **踩坑：`Assets/Firebase/m2repository` 必须存 `.srcaar`，`GeneratedLocalRepo` 才存 `.aar`**。两处都放 `.aar` ⇒ Unity 报 `Found plugins with same names ... Plugins colliding` 构建失败。改名后还须**重写 `.meta`**：`.srcaar` 用 `DefaultImporter`，`GeneratedLocalRepo` 的 `.aar` 用 `PluginImporter` 且 `Android.enabled: 0`（否则被判为 Android 插件再次冲突）。
- Firebase 三个 unity aar 的 pom **无 `<dependencies>`** ⇒ 无传递依赖断链风险。

### 🔴 v64 上线后 Play 实测：告警 **5 → 2**（2026-10-12，推翻旧结论）
用户从 Play Console 收到的告警点名**只剩 2 个库**：
```
base/lib/arm64-v8a/libnative-googlesignin.so
base/lib/arm64-v8a/libtolua.so
```
- ✅ **Firebase 三库（Analytics / App-12_8_0 / Crashlytics）已从名单消失** ⇒ **升 Firebase 确实清掉了 3 个**。
- ⚠️ 但 `so_meta.py` 实测 12.10.1 的 `.note.android.ident` **仍是 r21e** ⇒ 说明 **Play 清单按「库名+版本」判定，不是按 NDK 版本阈值**。（旧结论「升 Firebase 清不掉告警」据此**作废**。）
- 新包（v64）里这 5 个库**全都在**（`zipfile` 精确列举确认）⇒ 告警确实挂在 v64 这一代；**Firebase 三库是被 12.10.1 替换后不再被点名的**。
- **告警所属版本判定**：Console 标注「发布版本名称：**1.2.45**」。但 v62/v63/v64 共用该 versionName（见上节）⇒ 单看名字定不了。**据「Firebase 三库不在名单」反推**：v62 与 v63 里都是 `libFirebaseCppApp-12_8_0.so`，若告警挂它们则三库必被点名；既然不点名 ⇒ **告警挂在 v64**（12_10_1）。✅

### 🔴 两条反直觉的实测结论（决定要不要动手）
1. **清告警 = 换掉被点名的那个库文件本身**（不是升 NDK、不是升 Unity）。`_64.aab` 中 `libFirebaseCppApp-12_10_1.so` 不在清单，而 `12_8_0` 在 ⇒ 换版即清。剩余 2 个同理：要清 `googlesignin` 只能换/删该库，要清 `tolua` 只能重编该库。
2. **Play 的告警挂在「已发布版本」上，概览不会自动刷新。** `main_android` 记忆实测：Console 每条问题都标注「发布版本名称：N」= 线上旧版；新包已修的问题**概览里仍可能显示**。⇒ 核对版本号再决定是否处理。

### 时限与取证工具
- 门槛 2 在 **2027-02-01** 前**只是警告、不阻断发布**（门槛 1 已过）。
- 取证工具在跨仓 `main_android/Release/tools/`：`verify_16k.py`（ELF 对齐，支持 APK/AAB/裸 `.so`）、`so_meta.py`（读 `.note.android.ident` 判 NDK 版本，**不认 AAB，要喂裸 `.so`**）。
- 完整 playbook：`main_android/docs/skills/android-16kb-page-alignment/{SKILL.md,references/*}`。

### 本工程的 Firebase 使用面（决定改动风险）
- **代码零引用**：C# / Lua / Java 全树 `grep -i firebase\|crashlytics`（排除 `Assets/Firebase`）**零命中**；仅 `Assets/google-services.json` 存在。⇒ Firebase 只为 **Crashlytics 自动崩溃上报 + Analytics 自动采集**而装，无 API 调用点。
- 落点：SDK 版本 = **12.8.0**（`Assets/Firebase/m2repository/com/google/firebase/{firebase-app,firebase-analytics,firebase-crashlytics}-unity/12.8.0/`）；`Assets/Firebase/Plugins/x86_64/FirebaseCppApp-12_8_0.dll`；EDM4U 生成的依赖块在 `Assets/Plugins/Android/mainTemplate.gradle`（`Android Resolver Dependencies` 段，4 处 `12.8.0`）。
- 本项目**无 HybridCLR**（无 `*.dll.bytes`）⇒ 升级 Firebase 时不需要重生成 AOT 补充元数据。
- SDK 可下载：`https://dl.google.com/firebase/sdk/unity/firebase_unity_sdk_12.10.1.zip`（HTTP 200 实测可达）。
- 🔴 **`libnative-googlesignin.so` = 活代码，不是死插件**（⚠️ 2026-10-12 曾误判为「零引用可整目录删」，已更正）：
  - 来源 `Assets/GoogleSignIn/Editor/m2repository/com/google/signin/google-signin-support/1.0.4/google-signin-support-1.0.4.aar` → `jni/arm64-v8a/libnative-googlesignin.so`（284752B，r17/GCC）。该 aar 的 `.meta` 虽写 `Android.enabled: 0`，但包里确实有该 so（待查 Unity 实际提取路径）。
  - 调用链（活）：`~Lua/Modules/Login/LoginPanel.lua:109` `Util.AddClick(this.googlebtn, this.OnGoogleLogin)` → `OnGoogleLogin` 置 `LoginPlatform=1`（:1166）→ `ggSignMgr:LoginByPlatformType(1,…)`（:1243）→ `GoogleSignMgr.cs:30` `new SigninSampleScript()` → `Assets/GoogleSignIn/` 插件。
  - ⇒ **不能只删目录**：`Assets/Scripts/Google/SigninSampleScript.cs` 与 `GoogleSignMgr.cs` 依赖 plugin 类型，删插件会**编译失败**；且会**移除 Google 账号登录**（另一条 `platformId==2` 走 `GooglePlayGamesLogin`，按钮是主登录键 `btnLogin`）。要清此库须同时改 Lua（**重编 LuaBytes**）+ C# + 删 `Assets/GoogleSignIn/` + `Assets/Plugins/iOS/GoogleSignIn/`。
- **`libtolua.so`** 来源 = `Assets/Plugins/Android/libs/arm64-v8a/libtolua.so`（裸 so，ToLua# 框架 native 侧，`4d1210554 cathe` 引入，stripped、**无 `.note.android.ident`** ⇒ `so_meta.py` 判「无法判定」）。C# 侧在 `Assets/ToLua/Core/{ToLua.cs,LuaDLL.cs}`。❗**仓库内无 tolua C 源码**（无 `tolua*.c/h`）⇒ 本次**无法用 NDK r28 重编**；且它是 Lua 运行时核心，换版接口不匹配会整机崩，风险最高。
