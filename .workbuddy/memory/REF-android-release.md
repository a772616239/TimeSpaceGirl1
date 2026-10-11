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

## 认证 / 授权
- 认证 = Google Cloud service account JSON。🔴 **Cloud 建完账号 ≠ 能发布**：必须在 Play Console「用户和权限」把该邮箱加为发布用户并勾「发布到正式版」，否则 API 一律 403。密钥放 `~/.gplay/service-account.json`（仓库外），Cloud 项目 `platinum-loop-468100-k5`。
- 依赖 `google-api-python-client` + `google-auth`（⚠️ PyPI 直连超时，**用清华镜像** `-i https://pypi.tuna.tsinghua.edu.cn/simple`）。本机无 fastlane/Ruby，故走 API 直连。

## 🔴 上传 421MB 大包：必须放宽超时 + 缩小分块（2026-10-12 实测踩坑）
- 三层根因：① `google-auth-httplib2` 硬给 httplib2 设 `timeout=60`；② `MediaFileUpload` 默认 `chunksize=100MB`；③ 走本机代理（`HTTP_PROXY=127.0.0.1:52954`，~400KB/s）单块需 4 分钟 ⇒ 必被 `TimeoutError` 打断。
- `play_upload.py` 已内置：`widen_http_timeout()` 提到 300s **并 clear `.connections`**（httplib2 只在建连时读 timeout，不清缓存复用旧连接仍是 60s）+ `chunksize=8MB` + 断点续传重试（8 次指数退避）+ 异常回滚 edit。
- 可覆盖：`PLAY_UPLOAD_TIMEOUT_S` / `PLAY_UPLOAD_CHUNK_MB` / `PLAY_UPLOAD_MAX_RETRIES`。421MB 实测约 8 分钟。
- 已发版：**production v63**（2026-10-12，421MB，含完整 bundles + Lua）；线上历史 v62（2026-08-17，421MB）。

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
