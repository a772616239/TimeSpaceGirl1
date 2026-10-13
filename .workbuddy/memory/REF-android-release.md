# 参考：Android 发版管线（AAB → Google Play）与 AssetBundle 链路

> 从 `MEMORY.md` 拆出（2026-10-12），内容未改动，仅迁址以免主记忆文件过大。原主文件中该段曾重复两遍，此处已合并去重。
> 出海发版、重建资源、排查包体异常时读本文件。

## 工具与产物
- 一键入口 `scripts/aab_release.sh`（提号 → Unity batchmode 打包 → 校验 → 上传）；配套 `scripts/play_upload.py`（Play Developer API v3）、`scripts/bump_version.py`（提号）、`scripts/check_ab_ready.sh`（AB 只读体检，退出码 0/1）。
- 文档 `docs/google_play_upload_setup.md`；项目 skill `.workbuddy/skills/play-aab-release/`。打包侧坑位真源 = `docs/unity_android_build_skill.md`。
- 产物落 `apks/{日期}/CLIBuild/{时间}.aab` + 同名 `.json` sidecar 记 versionCode；`apks/` 已 gitignore。`AutoSignKeystore.cs` 打包前自动注入 keystore，无需手动配。
- **APK 打包入口**：`Assets/Editor/CLIBuilder.cs:81 BuildAndroidAPK()`（`EditorUserBuildSettings.buildAppBundle = false` ⇒ **universal APK**，本工程仅 arm64）。CLI：
  `Unity -projectpath <root> -batchmode -nographics -executeMethod CLIBuilder.BuildAndroidAPK -logFile build_log_apk_main.txt -quit`
  产物与 AAB 同目录（`apks/<date>/CLIBuild/<HHmmss>.apk`）；v66 实测 **454MB / 1m44s / `UNITY_EXIT=0`**（v65 为 2m9s）。
  - 🔍 版本核对：`aapt dump badging <apk> | head -1` → `package: name='com.Warera.timespace' versionCode='66' versionName='1.2.47'`。
  - ⚠️ **APK 用 upload key 签名**（`beauty.keystore` / alias `xing`，证书 DN `O=EMI`，SHA-256 `8ed07291…94b0`）—— 与 Play 的 **app signing key 不是同一个**（Play App Signing 会重签 AAB）⇒ 侧载到已装 Play 版的机器上会签名冲突，**须先卸载**。
  - 签名 scheme：**仅 v2**（`v1=false` 属正常 —— AGP 在 minSdk ≥ 24 时默认关闭 v1/JAR 签名）。
  - `apks/` 在 `.gitignore:38`；APK 打包日志 `build_log_apk_main.txt` 已由通配规则 `build_log_*_main.txt` 覆盖（`6fd42bd93`）。

## 🔴 versionCode
- **CLI 打包不自增 versionCode**：`Assets/Editor/CLIBuilder.cs` 只读，自增只在 GUI 的 `BuildWindow.cs:449` ⇒ CLI 反复打包复用同一个号（实测日志 `VersionCode: 62`），传 production 必被拒。
- `aab_release.sh` 默认调 `bump_version.py --bump` 补上；`play_upload.py` 上传前查轨道现有 versionCode，撞车以退出码 5 拦截。

## 🔴 versionName（`bundleVersion`）长期未推进 —— Play 告警定位的坑
- `bundleVersion` 自 `b2a0037a9`（2026-08-17，`1.2.44 → 1.2.45`）起**再没改过** ⇒ **v62 / v63 / v64 三个包共用同一个 versionName `1.2.45`**（`b2a0037a9`=62、`e07c23190`=63、`2eaecca00`=64）。
- ⇒ **Play Console 的「发布版本名称：1.2.45」不能区分这三个包**，只有括号里的 versionCode（如 `1.2.45 (64)`）能。核对告警所属版本时**必须以 versionCode 为准**。
- 发版时应同时推进 versionName：`bump_version.py --bump-name`（本次未执行，属待改流程缺陷）。

## 认证 / 授权
- 认证 = Google Cloud service account JSON。🔴 **Cloud 建完账号 ≠ 能发布**：必须在 Play Console「用户和权限」把该邮箱加为发布用户并勾「发布到正式版」，否则 API 一律 403。密钥**优先放工程本地 `.secrets/service-account.json`**（回退 `~/.gplay/service-account.json`，仓库外），Cloud 项目 `platinum-loop-468100-k5`。布局 / 优先级 / 换机恢复见 `docs/secrets_setup.md`。
- 依赖 `google-api-python-client` + `google-auth`（⚠️ PyPI 直连超时，**用清华镜像** `-i https://pypi.tuna.tsinghua.edu.cn/simple`）。本机无 fastlane/Ruby，故走 API 直连。

## 🔴 上传 421MB 大包：必须放宽超时 + 缩小分块（2026-10-12 实测踩坑）
- 三层根因：① `google-auth-httplib2` 硬给 httplib2 设 `timeout=60`；② `MediaFileUpload` 默认 `chunksize=100MB`；③ 走本机代理（`HTTP_PROXY=127.0.0.1:52954`，~400KB/s）单块需 4 分钟 ⇒ 必被 `TimeoutError` 打断。
- `play_upload.py` 已内置：`widen_http_timeout()` 提到 300s **并 clear `.connections`**（httplib2 只在建连时读 timeout，不清缓存复用旧连接仍是 60s）+ `chunksize=8MB` + 断点续传重试（8 次指数退避）+ 异常回滚 edit。
- 可覆盖：`PLAY_UPLOAD_TIMEOUT_S` / `PLAY_UPLOAD_CHUNK_MB` / `PLAY_UPLOAD_MAX_RETRIES`。421MB 实测约 8 分钟。
- 已发版：**production `completed v64`**（2026-10-12，421MB，Firebase Unity SDK 12.10.1）；历史 v63（同日，12.8.0，含完整 bundles + Lua）、v62（2026-08-17，421MB）。
- **v65（2026-10-12 09:00）**：421MB，含 googlesignin 依赖移除 + `libtolua.so` r28 重编。已按用户指令上传到 **production 轨道但 `status=draft`（不送审）**。🔴 **但它有致命缺陷**：`libtolua.so` 用了 `alex4814` 的 LuaJIT 2.1.ROLLING，与字节码编码器 2.1.0-beta3 错配 ⇒ **真机启动即卡死**（详见 `2026-10-12.md` 事故节）。**已被 v66 顶掉**，不要再发布它。
- **v66（2026-10-12 09:45）—— 当前 production 轨道上的 draft**：421MB，`versionCode 66` / `versionName 1.2.47`。
  - 内容：`libtolua.so` 回归 **LuaJIT 2.1.0-beta3**（topameng 树）重编（`c0c9388a2`）+ `androidx.fragment 1.6.2 / activity 1.7.2`（`7cc5a3afd`）。
  - 校验全过：门槛1 **12/12**；门槛2 `libtolua.so` = **r28**、googlesignin 不在包内；`libtolua.so` sha256 = 工程版 `b3460bf8…165c`；包内 `androidx.fragment_fragment.version = 1.6.2`、`androidx.activity_activity.version = 1.7.2`。
  - **Play API 实测**：`production draft v66; completed v64`（`beta/alpha` 空，`internal completed v61`）⇒ 线上正式版仍是 **v64**，**v66 未送审**。
  - 🔴 **首次上传失败于 Play 侧 HTTP 503 打在 `edits().commit()` 上**（421MB 白传）⇒ 已修 `play_upload.py`（`b1876534b`，见下节），重试即成功。
  - APK 同内容已另出：`apks/2026-10-12/CLIBuild/093010.apk`（454MB / 1m44s，`apksigner verify` Verifies / v2、`aapt dump badging` 确认 `66 / 1.2.47`）。

## 🔴 `play_upload.py` 的重试盲区：commit 一次 503 就白传整包（2026-10-12 实测踩坑 → 已修 `b1876534b`）
- 现象：v66 上传到 production/draft，421MB 传完、Play 返回 `versionCode=66`、`tracks().update()` 也成功，但**最后 `edits().commit()` 撞上 `HTTP 503 UNAVAILABLE`** ⇒ 脚本走 except 分支回滚了未提交的 edit，轨道状态毫无变化。
- 根因：**只有「上传分块」那一段有断点续传重试**，`tracks().update()` 与 `edits().commit()` 都是裸调用。
- 修复：新增 `execute_with_retry(factory, label, max_retries)` —— 对 `RETRYABLE_HTTP_STATUS = {408,429,500,502,503,504}` 与网络层异常做指数退避（上限 `UPLOAD_MAX_RETRIES`）。请求对象由 factory **每次新建**（googleapiclient 的请求是一次性的，不能复用）。
- 兜底：新增 `track_has_version(service, pkg, track, vc)` —— 503 有可能发生在服务端**已受理**之后，此时 edit 已被消费、重试 commit 会报「edit 不存在」，**不能据此判失败**；回查轨道确认版本确实挂上即判成功，避免再白传 421MB。
- 附带订正：commit 成功后的提示语原本无条件说「会进入审核」，现改为只在 `status=completed` 时提示，`draft` 明确说明「只保存草稿，需人工在 Console 发布」。


## 🔴 Play edit 互斥：上传期间禁止并发调用 Play API（2026-10-12 实测）
- 现象：v64 上传跑到 **85%** 时 `HTTP 400 / FAILED_PRECONDITION / This Edit has been deleted`，整包失败（`play_upload.py` 退出码 4）。
- 根因：**上传过程中另一个进程对该 App 调了 Play API 并 insert 了新 edit**（当时我在跑 `play_16kb_watch.py --dry-run`）⇒ 同一 App 的并发 edit 互相作废，上传绑定的 edit 被判 deleted。
- 处置：直接重跑 `play_upload.py`（会新建 edit 重传）。🔴 **不要用 `aab_release.sh` 重跑** —— 它默认 `--bump`，会再提一次 versionCode 导致号段跳空。
- 规则：**上传/发布进行中，不要跑巡检、dry-run 或任何会 `edits.insert` 的工具**。已写进 `play_16kb_watch.py` 文档头与 `docs/google_play_upload_setup.md §5`。

## 轨道与发布状态：默认 internal，不送审靠 draft（2026-10-12 / 10-13）
- Play Developer API 的 `release.status` 合法值 = `{draft, inProgress, halted, completed}`（= `play_upload.py` 的 `VALID_STATUS`）。
- 🔴 **2026-10-13：默认轨道由 `production` 改为 `internal`**（用户要求「不要直接传正式环境，传内部测试的管线」）。
  - `TRACK="internal"`；`STATUS` 按轨道推导（internal ⇒ `completed`，其余 ⇒ `draft`）。
  - internal 豁免 `--publish`：它不面向公众、免常规审核（上传后几分钟即可装）、可随时 halt/替换；
    **草稿在 internal 上等于「没传」**（测试员看不到），所以默认就该是 completed。
  - production / beta / alpha 不变：仍须 `--publish` 才能 completed/inProgress。
  - `.jenkins/lib/checks/play_gate.sh` 已同步（新增「默认 internal」文本断言 + 「internal 免 publish」行为断言，
    并把 probe 改成走不存在的 `--aab` 快速路径，不再依赖 `apks/` 里有包）。
- 🔑 **production 轨道上唯一的不送审姿势 = `--status draft`**：上传后只是「草稿」，**不进 Google 审核**，要人工在 Play Console 点发布才生效。
- ⛔ `--changes-not-sent-for-review`（即 `changesNotSentForReview=true`）**只对 internal/alpha/beta 有效**，传 production 会被脚本 `die`（`play_upload.py` 内有硬校验）。
- ✅ 已修：`aab_release.sh` 末尾的结论文案现在按轨道分支打印（internal / draft / 其它），不再对 draft 说「会进入审核」。
- 🔴 **Play 各轨道共享同一个 versionCode 空间** —— 一个号传过一次就永久占用，换轨道重传同号同样被拒。「传 internal 省号」是错觉。
  - 撞车判定必须是 **app 级全局**：`play_upload.py` 用 `all_track_version_codes()`（全部轨道全局最大值）判定，
    **不能只看目标轨道** —— 2026-10-13 实测踩到：internal 当前最大才 v61，vc69 会通过本地检查、
    白跑 437MB / 约 8 分钟整包上传，到 Play 才被拒（`Version code N has already been used`）。
- 🔁 **复用已上传号 = track promotion（2026-10-13 新增 `--reuse-version-code N`）**：不传任何文件，
  只把 app **已上传过**的号写进目标轨道。用于「已在 production 的同一版包也挂到 internal」这类需求。
  - 与 `--aab` 互斥（`--aab` 已改为可选）；复用前用 `app_bundle_version_codes()`（`bundles().list()`）
    查号在不在池里，不在则 rc=5。🔴 必须用 `bundles().list()` 而非 `tracks().list` —— 后者只反映
    各轨道**当前**发布，老号滚掉就看不到；要复用的号可能已滚掉却仍在池里。
  - 因为不产生新上传 ⇒ **不受「必须严格递增」约束**（该号本就是已用过的）。
  - 实测命令：`play_upload.py --reuse-version-code 69 --track internal --yes`（vc69 已挂上 internal）
- 复核现状（只读内容，但会 `edits.insert`）：`play_upload.py --dry-run`，看 `[tracks]` 段 —— draft 与 completed 并存时形如 `production  draft v69; completed v68`。⚠️ **上传/发布进行中不要跑**（见上节 edit 互斥）。⚠️ 若目标是**已在轨道上**的 versionCode，dry-run 会以「版本号撞车」失败退出（预期行为，说明号确实上去了）。
- 完整命令：`scripts/aab_release.sh --skip-build --aab <path>.aab --upload --yes`（→ internal，默认）
  / `scripts/aab_release.sh --skip-build --aab <path>.aab --upload --production --status draft --yes`（→ production 草稿）
  / `play_upload.py --reuse-version-code <N> --track internal --yes`（复用已上传号，不传文件）
- **2026-10-13 轨道实测**：`production completed v69`（已上线）/ `internal completed v69`（复用挂上）/ beta·alpha 空；
  app bundle 池 = `[1,6,24,26,27,61,64,65,66,67,68,69]` ⇒ **下一个新号必须 ≥ 70**。

## Play 16KB 合规巡检（2026-10-12 起）
- 工具 `scripts/play_16kb_watch.py`（轨道现状 + 两层取证 + diff + 邮件）；定时任务 id `ea56e5de-abc2-45c2-abb9-401505a65a96`（每 3 天 10:00）。
- 🔴 报告必须区分「Play 点名」与「仅 NDK 阈值偏旧」：`NDK < r28` ≠ 被点名。v66 实测 < r28 有 **11 个**，Play 一个都没点名；Unity 自出库（il2cpp/unity/main r23b）与 crashlytics（r25b）从不被点名。
- 🔴 **点名是按【库文件名】、不看 NDK 版本阈值**。文件名含版本号的库换版本 = 换名字 ⇒ Firebase `12.8.0 → 12.10.1` 就是把告警从 5 个降到 2 个的原因（这些库实测仍 r21e）。⚠️ 所以 `PLAY_FLAGGED_PREFIXES` 只能匹配**被点名过的那个版本名**（`libFirebaseCppApp-12_8_0`），不能用 `libFirebaseCppApp` 前缀，否则 12_10_1 会被误报成「仍待上游」（已在 `6bc70fbec` 修正）。
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
- **`libnative-googlesignin.so`**：✅ **2026-10-12 已修**（commit `72502790b`）—— 不必换插件：根因在 gradle 的 `implementation 'com.google.signin:google-signin-support:1.0.4'`，删掉该依赖 + `GoogleSignInSupportDependencies.xml` 即可（插件自身的 `.meta` 写 `Android.enabled: 0` **不是**阻止它的原因）。
- **`libtolua.so`**：✅ **2026-10-12 已修**（commit `2f4e7310f` + `291ee8644`）—— 用 NDK r28 重编即符合 Play 文案第一方案，工具链见 `scripts/libtolua16k/`。

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
  - 来源 `Assets/GoogleSignIn/Editor/m2repository/com/google/signin/google-signin-support/1.0.4/google-signin-support-1.0.4.aar` → `jni/arm64-v8a/libnative-googlesignin.so`（284752B，r17/GCC）。🔑 **它进包的真实通道 = gradle `implementation` 依赖**（EDM4U 生成的 `mainTemplate.gradle` 那一行），**不是**插件 `.meta` 的 `Android.enabled: 0`（那个不生效）—— 该 aar 的 `.meta` 写了 `Android.enabled: 0` 也照样进包。
  - 调用链（活）：`~Lua/Modules/Login/LoginPanel.lua:109` `Util.AddClick(this.googlebtn, this.OnGoogleLogin)` → `OnGoogleLogin` 置 `LoginPlatform=1`（:1166）→ `ggSignMgr:LoginByPlatformType(1,…)`（:1243）→ `GoogleSignMgr.cs:30` `new SigninSampleScript()` → `Assets/GoogleSignIn/` 插件。
  - ⇒ **不能只删目录**：`Assets/Scripts/Google/SigninSampleScript.cs` 与 `GoogleSignMgr.cs` 依赖 plugin 类型，删插件会**编译失败**；且会**移除 Google 账号登录**（另一条 `platformId==2` 走 `GooglePlayGamesLogin`，按钮是主登录键 `btnLogin`）。要清此库须同时改 Lua（**重编 LuaBytes**）+ C# + 删 `Assets/GoogleSignIn/` + `Assets/Plugins/iOS/GoogleSignIn/`。
  - ✅ **2026-10-12 实际解法（比上面这条轻得多，commit `72502790b`）**：不用动 Lua、也不用删插件目录 —— 只要**断掉 gradle 那条 `implementation`**（`mainTemplate.gradle` + `GoogleSignInSupportDependencies.xml` + `AndroidResolverDependencies.xml`），该 so 就不进包了。再把 `GoogleSignMgr.cs` 的 Android 分支改走 `GooglePlayGamesLogin`（**保留 `LoginPlatform=1` 与 `"go"` 前缀** ⇒ Lua 与老玩家凭据零影响）。`Assets/GoogleSignIn/` 目录保留（iOS 路径与编辑器内 `SigninSampleScript` 仍在用）。
- **`libtolua.so`** 来源 = `Assets/Plugins/Android/libs/arm64-v8a/libtolua.so`（裸 so，ToLua# 框架 native 侧，`4d1210554 cathe` 引入）。C# 侧在 `Assets/ToLua/Core/{ToLua.cs,LuaDLL.cs}`。❗**仓库内无 tolua C 源码** ⇒ 要靠上游 **`topameng/tolua_runtime`**（**不是** alex4814！）重编，工具链已固化在 `scripts/libtolua16k/`。🔴 原库就是 topameng 仓库的预编译产物（sha256 完全一致），**LuaJIT 必须是 2.1.0-beta3**，换版本会导致真机卡死。

## 🔴 清掉最后 2 个被点名的库（2026-10-12，最终落在 v66）

被 Play 点名的最后 2 个库都处理完了。**核心认知**：`libtolua.so` 这条不只是一个告警，
`LJ_PAGESIZE` 不改在 16KB 设备上是**真崩溃**。

### `libnative-googlesignin.so`（commit `72502790b`）
- 真因：`Assets/Plugins/Android/mainTemplate.gradle` 里 EDM4U 生成的
  `implementation 'com.google.signin:google-signin-support:1.0.4'` —— 该 aar 的
  `jni/arm64-v8a/libnative-googlesignin.so` 由 NDK r17 编译。**不是**插件 `.meta` 的
  `Android.enabled: 0` 挡住的（那个不生效）。
- 改法：删该 implementation 行 + 删 `Assets/GoogleSignIn/Editor/GoogleSignInSupportDependencies.xml`
  （声明源头）+ `ProjectSettings/AndroidResolverDependencies.xml` 里的同名 package；
  `GoogleSignMgr.cs` 的 Android 分支改走 `GooglePlayGamesLogin`。
- 🔑 **保持 `LoginPlatform=1` 与 `"go"` 账号前缀不变** ⇒ `LoginPanel.lua` 一行没改、
  `PlayerPrefs.lastLoginPlatform` 语义不变、老玩家已存凭据照常走 `RequestUser`。
- ⚠️ 更正旧结论：该 so **不是**「零引用死插件」（见下节调用链），直接删目录会编译失败。

### `libtolua.so` —— ⚠️ 第一版方案已作废，见下方「v66 重编」
`libtolua.so` = 一整个 ToLua# 运行时（LuaJIT + tolua + cjson + lpeg + pb(protobuf)
+ luasocket + struct + bit 打成一个 .so），仓库无源码。
- 🔴 **真因是 LuaJIT 的 `LJ_PAGESIZE`**：`luajit-2.1/src/lj_arch.h` 默认 `4096`。
  JIT 的 mcode 分配器按该值对齐后调 `mprotect`，在 16KB 页设备上地址/长度不满足内核
  要求 ⇒ **JIT 代码页无法生效 → 崩溃**。必须改成 `16384`（在 4KB 设备上同样满足，
  只多占一点 mcode 内存）。
- 🔴 **另一条重要更正**：原库 `PT_LOAD Align = 0x10000`（**64KB**），**本来就远超 16KB**
  ⇒ **门槛1（硬对齐）从来不是 `libtolua.so` 的问题**。要修的只有 ①Play 点名 ②`LJ_PAGESIZE`
  的 JIT 运行时隐患 —— **这两件事都不需要动 LuaJIT 版本**。
- ❌ **已作废的第一版**（`2f4e7310f` / `291ee8644`）：用了 `alex4814/tolua_runtime`
  （LuaJIT **2.1.ROLLING**）⇒ **运行时版本与字节码编码器错配，真机启动即卡死**。
  详见 `2026-10-12.md` 的事故节与 `scripts/libtolua16k/README.md` 的「血泪教训」。
- ⚠️ alex4814 那棵树自身也有疏漏（`PROTOBUF_SRC` 没进 `add_library`、`LUASOCKET_SRC`
  漏 `mime.c` ⇒ 少 `luaopen_pb` / `luaopen_mime_core`）—— 但 topameng 树**没有这个问题**，
  其 `Android.mk` 源文件清单本来就是齐的，所以换回 topameng 后补丁缩为「改 1 文件 1 行」。

### ✅ v66 的 `libtolua.so` 重编（commit `c0c9388a2`，正确方案）
- **上游 = `topameng/tolua_runtime`（pin `654e0da6`）**，LuaJIT **2.1.0-beta3**。
  🔑 **判定依据**：该仓库预编译的 `Plugins/Android/libs/arm64-v8a/libtolua.so` 与本工程
  原库 **sha256 完全相同** = `176274e75a380e97c209deacc63e372a3c9adc066d6ff59c671e62ebeb376a2f`
  （667,968 字节）⇒ 原库就是它出的，**不是** alex4814。
- 改动仅 1 处：`luajit-2.1/src/lj_arch.h` 的 `LJ_PAGESIZE` 4096 → 16384。
- 构建：NDK r28 / API 24（`aarch64-linux-android24-clang`）+ `-Wl,-z,max-page-size=16384`；
  源文件清单严格照抄上游 `android/jni/Android.mk`（不含 `bit.c`/`serial.c`/`unix.c`）。
- 校验**与旧库逐项对齐**：LuaJIT 版本 = `2.1.0-beta3`；动态导出 **T 符号旧 380 / 新 380，
  缺失 0、新增 0**；`luaopen_*` 18/18 完全一致；门槛1 4 个 `PT_LOAD p_align` 全 = 16384；
  门槛2 `.note.android.ident` = r28。
- 体积 667,968 → **736,544 字节**（stripped）；`sha256 b3460bf8424bded12eceb3efb887f8adad8bde6e88b9dea54e483a78ed12165c`。
- 工具链 `scripts/libtolua16k/` 已推倒重写（`759542803`）：`build.sh` / `verify.py`
  （**4 项硬性**：①`p_align≥16384` ②NDK≥r28 ③导出符号对 `ref/original-symbols.txt` 380 个
  零缺失 ④**.so 内 LuaJIT 版本 == `LuaEncoder` 版本**）/ `apply-16k.patch` / `ref/` / `README.md`。
  🔑 **③④ 两道闸门正是为防本次事故**；用事故版（ROLLING）回测 → **2/4，被 ③④ 精确拦下**。
- **LuaJIT Makefile 两个坑**：① `STATIC_CC`/`TARGET_LD` 是 `$(CROSS)$(CC)` 拼接 ⇒ `CROSS`
  必须留空、`CC` 给完整路径并逐项覆盖 `TARGET_LD`/`TARGET_AR`/`TARGET_STRIP`；
  ② `HOST_CC = $(CC)` ⇒ 必须显式设本机 clang，否则 `buildvm` 被 Android clang 编、跑不了。
- 备份 `~/ts-tolua-backup-20261012/`：`libtolua.arm64-v8a.old.so`（原始 beta3 产物）、
  `libtolua.arm64-v8a.api21.so`、`libtolua.arm64-v8a.rolling.so`（**事故版，勿用**）。

### v65 产物（🔴 已作废，仅存历史）
- AAB `apks/2026-10-12/CLIBuild/085541.aab`（421.2 MB，`versionCode 65` / `versionName 1.2.46`）。
  versionName 从 `1.2.45` 提到 `1.2.46` —— 它自 `b2a0037a9`（2026-08-17）起没动过，
  导致 v62/v63/v64 在 Play 告警里都显示「1.2.45」、无法区分。
- googlesignin 部分**有效**（该修复保留）；`libtolua.so` 部分**因版本错配作废**。
- 🔴 **这个包是真机卡死的，不要再发布**；其 Play `draft` 已被 v66 顶掉。

---

## 出包配置（GM 面板）修复 —— 2026-10-12（`297b9ba9f` / `f74ffb436` / `a08c02d38`）

### 根因
编辑器「是否正式包」那段配置**只写在 `BuildWindow.OnGUI`（`BuildWindow.cs:204-234`）**里，
且只改**内存中已打开场景**的对象；命令行入口 `CLIBuilder` 完全没有这一步
⇒ 命令行产物一律沿用工程当下的**开发态**设置（`isOpenGM=1`）。

### 关键事实（已取证）
- `versionCode 64`（线上 completed）＝ `apks/2026-10-12/CLIBuild/011824.aab`，**是 `CLIBuilder` 打的**
  ⇒ 线上包一直带 GM 面板。
- 渠道 `SDKChannelConfig.txt` = `None` 是**线上实际值、是正常的**：本作 Google 登录走
  `not IsSDKLogin` 的账号密码分支（`LoginPanel.lua:7`）。**渠道为 None 时强行 `isSDK=true` 会把登录打挂。**
- 口径由用户拍板选 **最小改动（只关 GM）**，不动 `isGuide/isUpdate`（会改现有玩家行为）。

### 实现
- `Assets/Editor/ReleaseBuildSettings.cs`（新）＝出包配置**唯一真源**
  `ReleaseProfile{Dev, MinimalGmOff, FullTemplate}` + `ApplyProfile / FindGameSettings(includeInactive) /
  Validate / Describe / PrepareSceneForBuild / RestoreScene`。
- `CLIBuilder.BuildAndroid(bool)`：`kProfile = MinimalGmOff`；
  **`OpenScene(Logo.unity, Single)` → 套配置 → `MarkSceneDirty`+`SaveScene`（必须落盘，
  batchmode 下 BuildPlayer 读磁盘、改内存无效）→ `BuildPlayer` → `finally` 还原场景**；
  自检不过 `Exit(1)` 且**不产包**；写 `<aab>.release.json` sidecar。
  ⚠️ 故意**不调 `AssetDatabase.Refresh()`**（可能触发域重载，会丢静态快照并打断 BuildPlayer）。
- `BuildWindow.cs` 的内联块 → 调用同一份逻辑（编辑器行为不变）。

### 🔑 包内自检法（`scripts/verify_aab_release_config.py`，可复用）
- 场景 `base/assets/bin/Data/level0` 是 TypeTree 被裁剪的 SerializedFile ⇒ **搜不到字段名，但能按值搜**。
- `SettingInfo` 12 字段**按声明顺序内联**，**每个 bool 占 4 字节**（与 int 同对齐），全小端：
  `logLevel, isDebug, bundleMode, luaBundleMode, isUpdate, isSDK, isSDKLogin, isGuide,
   isOpenGM, isOpenTLog, isOpenBLog, originLan` ⇒ 48 字节特征。
- 口径向量（`originLan=10001`）：
  - `dev`     = `[0,0,1,1,0,0,1,0,1,0,0,10001]`（v64 实测）
  - `minimal` = `[0,0,1,1,0,0,1,0,0,0,0,10001]`（只关 GM；与 dev **只差 1 字节**）
  - `full`    = `[0,0,1,1,1,0,0,1,0,0,0,10001]`
- 命中位置 **offset 3792，全文件唯一**。`--expect dev|minimal|full`，返回码 0/1/2。
- `aab_release.sh` 已加**第 4.5 步**：`--expect minimal`，不过就拒绝上传。

### 实测结果（`apks/2026-10-12/CLIBuild/110317.aab`）
- `versionCode 67` / `versionName 1.2.48` / 421.4 MB / 构建 132 秒。
- 构建日志实证「套用前 isOpenGM=1 → 套用后(MinimalGmOff) isOpenGM=0，其余 11 位逐位不变」，
  且打完**场景已还原**（`git status` 干净）。
- 包内自检：命中 `minimal` @ 3792 → 通过。
- **与线上 v64 的 `level0` 逐字节对比：3840 B 全等，仅 offset 3824 差 1 字节（`01`→`00`）。**
- 16KB：门槛1 **13 ELF / 0 non-compliant ✅**；门槛2 软告警回到 4 个（含回退带回的 `libnative-googlesignin.so` r17）。
- 上传：`production / draft / versionCode 67`（**未送审**）。

## 🔴 16KB「旧版 NDK」软告警 —— 根因、修法与可复用闸门（2026-10-12 闭环）

### Play 的 16KB 检查是**两层**，别只看对齐
- **门槛1（硬性）**：每个 64 位 `.so` 的 `PT_LOAD p_align ≥ 16384`。
- **门槛2（软告警）**：Play 报「您的应用已针对 16 KB 设备进行编译，但其中某些库是使用**旧版 Android NDK**编译的」并**点名具体库**。
- 🔴 **`p_align = 0x10000`（64KB）也算达标**，所以只看对齐的旧工具（`play_16kb_watch.py`）**拦不住门槛2** —— 这正是 2026-10-12 漏网的原因。

### 判定依据（实测反推，13 个 .so 全量比对）
`.so` 的 **`.note.android.ident`** 段（`NT_ANDROID_IDENT`，desc 首 4 字节是版本串长度，随后是 `rNN` + 构建号）：
| 库 | `.note.android.ident` | `p_align` | `.comment` | Play 点名 |
|---|---|---|---|---|
| `libnative-googlesignin.so`（旧） | **r17** | **0x10000** | 含 `GCC: (GNU) 4.9.x` | ✅ 点名 |
| libFirebaseCppAnalytics/App/Crashlytics | r21e | 0x4000 | clang 9（App 那条也含 GCC） | ❌ |
| libcrashlytics* / datastore | r25b / r25c | 0x4000 | clang 14 | ❌ |
| libil2cpp / libmain / libunity | r23b | 0x4000 | clang 12 | ❌ |
| libtolua | r28 | 0x4000 | LLD 19 | ❌ |
⇒ **Play 不是简单按「版本 < r28」判定**（r21e/r23b 都没被点名）。实测能**唯一**区分点名/未点名的是
「`p_align == 0x10000`」与「note < r19」；单独的 `.comment` 含 GCC **会误伤**（libFirebaseCppApp r21e）。

### 修法：用 NDK r28+ 重编该 `.so`（不是删库、不是改登录方式）
- 该 `.so` 来自 `com.google.signin:google-signin-support:1.0.4` 的 aar（`jni/<abi>/libnative-googlesignin.so`），
  **是 C# `GoogleSignInImpl` P/Invoke 的唯一实现**（`DllImport("native-googlesignin")`），不能删。
  真正的 Google 身份（21 位数字 `sub`）来自 Java 侧 `GoogleSignInAccount.getId()`，**重编不影响账号派生**。
- 源码：`googlesamples/google-signin-unity` @ master 的 **`native-googlesignin/`**（CMake 工程，恰好就是 1.0.4；
  Java 侧 6 个方法签名已用 `javap` 与 aar 内 `classes.jar` 逐一比对一致）。
- NDK：`https://dl.google.com/android/repository/android-ndk-r28c-darwin.zip`（908 MB；本机 `sdkmanager` 要 JDK 17，**直接下 zip 更快**）。
- 🔴 **本机 `/usr/local/bin/cmake` 是 4.x，会拒绝 `cmake_minimum_required(VERSION 3.4.1)` ⇒ 别走 CMake，直调 clang++**：
  ```bash
  TC=<ndk>/toolchains/llvm/prebuilt/darwin-x86_64/bin
  $TC/aarch64-linux-android21-clang++ -shared -fPIC -O2 -std=c++11 -DNDEBUG \
     -o libnative-googlesignin.so src/main/cpp/{google_signin,google_signin_bridge,google_signin_user,jni}.cc \
     -static-libstdc++ -llog -Wl,-z,max-page-size=16384 -Wl,-z,common-page-size=16384 \
     -Wl,-soname,libnative-googlesignin.so
  $TC/llvm-strip libnative-googlesignin.so
  ```
  （32 位 ABI 不要加 max-page-size 那两个 flag；本工程只发 arm64-v8a。）
- **验收基线（必须逐项过）**：20 个导出全等（19 个 `GoogleSignIn_*` + `JNI_OnLoad`）、
  `DT_NEEDED` 全等（`liblog/libm/libdl/libc`，**仍静态 libc++、不引入 `libc++_shared.so`**）、SONAME 全等、
  `.note.android.ident` = r28c、`p_align = 0x4000`。
- 回填 aar：只替换 `jni/<abi>/libnative-googlesignin.so` 三条目，其余（`AndroidManifest.xml`/`classes.jar`/`R.txt`）
  逐字节不动；**必须同步更新同目录 `.aar.md5` / `.aar.sha1` 侧车**（该 aar 走**本地 maven repo**，
  声明在 `Assets/GoogleSignIn/Editor/GoogleSignInSupportDependencies.xml`，改完不更新侧车可能被 EDM4U 判为不一致）。
- 复核：**把重打后 AAB 里的该 `.so` 抠出来与本地产物比 md5** —— 相同即证明 Gradle 用的确实是打完补丁的 aar
  （2026-10-12 实测 `9f681d525c5533c9bae45ac2b73931ee`，逐字节一致）。

### 🔑 新增闸门 `scripts/verify_aab_native_16kb.py`（离线、不走 Play API）
- **FAIL**：任何 64 位 `.so` 的 LOAD 对齐 < 16384。
- **WARN**：命中「note < r19」或「64 位库 `p_align == 0x10000`」（`.comment` 含 GCC 只作附注，避免误伤）。
- 已接入 `aab_release.sh` **第 4.6 步**。回放旧包 `110317.aab` 时**恰好只报出 `libnative-googlesignin` 一个**。

## 遗留
- ✅ `aab_release.sh:85` 的 Unity 占用检查过宽 —— **已修**（2026-10-12）：改为只在命令行含
  `-projectpath ${PROJECT_ROOT}` 时命中，其它项目（如 `~/Documents/main_android/Unity`）在跑 batchmode 不再误中止。
- ⚠️ 上传并发纪律：**上传期间不要调任何 Play API**，否则 edit 互删（`This Edit has been deleted.`）。
- ⚠️ Firebase/il2cpp/unity 厂商库长期是 r21e/r23b（Play 不点名，也**无法由我们重编**）；若将来被点名，只能等厂商升级。
- ⚠️ 换 NDK 版本会**同时改 note 与对齐**，重编后务必用上面「验收基线」逐项比对，别只看 r28 字样。


## 🔴 发布闸门：默认拒绝，三旗标显式放行（2026-10-12 起，`2479709ae`）
背景：用户红线「不要帮我送审，我要自己看一下」。真因是**默认值就是发布**，不是纪律问题。

| 动作 | 命令 | 必须显式给出的旗标 |
|---|---|---|
| 只出包（默认） | `scripts/aab_release.sh` | 无（`DO_UPLOAD=0`） |
| 上传到 production 草稿 | `scripts/aab_release.sh --skip-build --upload --production --status draft --yes` | `--upload` + `--production` |
| **提交审核 / 上线** | `scripts/aab_release.sh --upload --production --publish` | 再加 `--publish`（需事先获批准！） |
| 只读看现状 | `scripts/aab_release.sh --dry-run` | 无（`--dry-run` 不受闸门限制） |

- `play_upload.py`：`--status` 默认 `draft`；新增 `--allow-production-write` / `--allow-publish`。
  **两层各自独立校验，脚本之间不传递旗标**（shell 会透传，但 python 自己也会再拒一次 = 双保险）。
- 拒绝对 production 写入（无 `--allow-production-write`）与拒绝 `completed/inProgress`（无 `--allow-publish`）都是退出码 **2**。

## ⚠️ Unity 的 `libtolua.so is not 16KB-aligned` 是**误报**，不要去"修"
`Unity 2022.3.62` 每次 Android 打包都会打印这条。**实测该库完全达标**：
- 4 个 `PT_LOAD` 全 `p_align = 0x4000`（自写 ELF 解析 + `/usr/bin/objdump -p` 双向确认，`align 2**14`）。
- **产物侧**（直接解 `092806.aab` / `113650.aab` / `093010.apk` 的 zip）里 `libtolua.so` md5 与源文件一致
  （`868a74d9b757…`），align 同样 `0x4000`；AGP 的 `stripped_native_libs` 也没改对齐。
- 旁证：Play 两轮 16KB 报障**从未点名 libtolua**（只点过 `libnative-googlesignin.so`）。
⇒ Unity 自检口径有 bug（`0x4000` 恰等于阈值却被判未对齐）。**16KB 是否合规格一律以包内 zip 的 .so 为准**，
   用 `scripts/verify_aab_native_16kb.py`，不要被 Unity 日志牵着走。

## ⚠️ CLI 打包崩溃会残留场景改动（已知缺陷）
`CLIBuilder` 用 `try/finally` 还原 `Assets/LuaFramework/Scenes/Logo.unity`；**若进程被硬杀**
（2026-10-12 11:57 那次停在 `Building Gradle project` 后 `Application is shutting down...`），
`finally` 跑不到 ⇒ 场景残留 `isOpenGM: 1→0`，工作区变脏。
**起包前先 `git status` 看该文件**，脏了就 `git checkout -- Assets/LuaFramework/Scenes/Logo.unity` 清回基线。
（不改也只会让下次 build 的"快照基线"变成 GM-off，功能无害，但仓库会一直脏。）

## ⚠️ 测试用 APK 的坑
`090414.apk` / `093010.apk` 是 `versionCode 66` + `buildAppBundle=false`，且 sidecar 标了
`"googlesigninRemoved": true`（当时为绕 Play 报障把这个 .so 从包内摘掉）
⇒ **Google 登录必挂**，拿它测账号派生只会得到假结论。测登录/账号必须用**含 r28c 版
`libnative-googlesignin.so`** 的新包（`versionCode 68` 起）。

## 🔑 APK 交付自检 `scripts/verify_apk_delivery.py`（2026-10-12，`68313d686`）
一条命令回答「这个包能不能拿去测」。校验项：版本号 / SettingInfo 口径 / native 16KB /
**`libnative-googlesignin.so` 必须存在且有 64 位版本** / 签名；结果落盘为
`<artifact>.delivery.json`。
- ⚠️ 历史 `090414.apk`、`093010.apk` 为绕 Play 报障**把该 .so 从包内摘掉**
  （sidecar `"googlesigninRemoved": true`）⇒ Google 登录必挂，拿它测账号只会得到假结论。
- **最新可测包：`apks/2026-10-12/CLIBuild/121249.apk`**
  （v68 / 1.2.49 / 454MB / arm64-v8a / isOpenGM=0 / googlesignin r28c，已过 `verify_apk_delivery.py`）。

## 🔴 账号体系：账号名 = f(登录 SDK 给的 id)，换 SDK 就等于换号
- 派生链：`LoginPanel.lua:1243` → `GoogleSignMgr.cs` 按 `platformId` 取 id →
  `GetAcc("go"|"pl"|"gt"|"r2gt" + id)`：**`name = acc[0..12)`、`pw = acc[12..24)`**
  → `tk/registerUser` + `tk/userLogin`。**服务端以 name 为账号主键**
  （`user_register_info._id = name`）；`openId` 是服务端生成的 32hex，1:1 绑定 name。
  - 前缀：`go`=Google(1)、`pl`=Play(2)、`gt`=游客(3)、**`r2gt`=Editor 游客**。登录库约 290 条。
- 🔴 **事故与修复**：`72502790b` 把 Android `platformId==1` 从 `SigninSampleScript`
  （返回 Google Sign-In `UserId`＝**21 位数字**）换成 `GooglePlayGamesLogin`
  （返回 `Social.localUser.id`＝**20 字符**）⇒ 同账号 id 变了 ⇒ 自动建新号。
  **已于 `f74ffb436` 回退为 Google Sign-In**（该库 `p_align=0x10000`，不破 16KB 硬门槛；
  它带回的「旧版 NDK」软告警已由 `ca46e0e49` 用 NDK r28c 重编该 .so 修掉）。**勿再改回去。**
  - 判别法（不用跑客户端）：查 `go` 账号的 **pw 长度**：`11 ⇒ 21 位旧 Sign-In`，`10 ⇒ 20 字符 PlayGames`。
- **影响面**：`LoginPanel.lua:1226` 判定 `lastPlt == LoginPlatform && user ~= defaultOpenIdkey`
  才走 `RequestUser` 用旧凭据 ⇒ **PlayerPrefs 完好的老玩家不受影响**；
  **清数据/重装/换设备/新装 ⇒ 走注册分支 ⇒ 100% 变新号**。
- 两区老号别搞混：**10002 的 lv24 老号账号名是 `r2gtB27C2057`（Editor 游客号）**，
  与真机 Google 号是两套体系；10001 库里没有它。
