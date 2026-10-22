---
name: play-aab-release
description: 为 TimeSpaceGirl1 打包 Android AAB/APK 并上传到 Google Play 后台（默认走 internal 内部测试轨道，正式版 production 需显式抬旗）。当用户提到"打包 AAB""打 APK""上传 Google Play""发版""传正式版/测试轨道""Play Console""aab_release""16KB 合规""Google 登录变新号"等意图时使用。覆盖 versionCode 自增、Unity batchmode 打包、包内出包配置校验、native 16KB/NDK 体检、Play Developer API 上传与轨道发布、APK 交付自检。
---

# Play AAB / APK 发版

把 Unity 工程打成 AAB（发版）或 APK（自测）并（可选）上传 Google Play。
**一键入口是 `scripts/aab_release.sh`。**

> 详细流程／全部踩坑记录：`docs/README.md`、`docs/android_release_runbook.md`、
> `docs/scripts_reference.md`。本文件只给"怎么做 + 别踩什么"。

## 什么时候用

- 用户要「打包」「出包」「打个 aab / apk」「上传 Google Play」「发版」「传正式版 / 内测」
- 用户要排查 Play 上传报错（401 / 403 / 400 version code 已使用 / edit deleted）
- 用户问「为什么登录变成新号了」「16KB 告警怎么回事」

## 🔴 三条红线（先内化，再动手）

1. **绝不自行送审。** 打包、构建、校验、提交 git 都可以；
   **「上传到 production 轨道 + `status=completed`」= 提交审核，必须先问用户同意。**
   已用代码锁死：默认不上传；**默认轨道是 `internal`（内部测试），不是 production**；
   写 production 必须显式 `--production`，非 internal 轨道送审必须显式 `--publish`。
   （2026-10-13 用户要求「不要直接传正式环境，传内部测试的管线」。）
2. **上传期间绝不并发调用任何 Play API**（含 `play_16kb_watch.py`、其它脚本/其它 agent）——
   多进程对同一 App 开 edit 会互删，实测「传 85% 报 `This Edit has been deleted.`」，421MB 白传。
3. **本工程 Unity GUI 不能开着**。但本机其它项目（如 `~/Documents/main_android/Unity`）在跑
   batchmode **不算占用**；`aab_release.sh` 已按 `-projectpath` 精确判定。

## 一键执行

```bash
cd /Users/wangxufeng/Documents/TimeSpaceGirl1

scripts/check_ab_ready.sh                       # 先只读体检包内资源（尤其 Lua）
scripts/aab_release.sh                          # 出包 + 三道包内校验（默认不上传）
scripts/aab_release.sh --dry-run                # 打包 + 只认证列轨道现状（只读）
scripts/aab_release.sh --skip-build             # 复用最近 AAB，跳过 Unity 打包

# ★ 传到 internal 内部测试轨道（默认目标；status 默认 completed，测试员几分钟内可装）
scripts/aab_release.sh --skip-build --upload --yes

# 要发正式版才抬旗：传 production 草稿（不送审）
scripts/aab_release.sh --skip-build --upload --production --status draft --yes

# 🔴 送审 / 上线 —— 必须先取得用户明确同意
scripts/aab_release.sh --skip-build --upload --production --publish --yes

# 正式发布 + 同一版本顺带挂 internal（Jenkins 的 TS-Android-Release 默认就这么做）
scripts/aab_release.sh --skip-build --upload --production --publish --also-track internal --yes
```

## 参数

| 参数 | 说明 |
|---|---|
| `--upload` | 🔴 才会上传；不加则只在本地出包（**默认**） |
| `--internal` | **默认**。传 internal 内部测试轨道（不面向公众、免常规审核、可随时 halt/替换） |
| `--production` | 🔴 才允许写 production 轨道 |
| `--publish` | 🔴 才允许**非 internal 轨道**用 `status=completed/inProgress`（= 送审 / 上线） |
| `--track` | `internal`(**默认**) / `alpha` / `beta` / `production` |
| `--also-track <T>` | 同一版本**同时**挂到另一条轨道（如 `internal`）：同一个 Play edit 内原子提交，**不重复上传、不占新号**（Play 的 versionCode 是 app 级全局的，同号不能传第二遍） |
| `--status` | 不传则按轨道推导：`internal` ⇒ `completed`（立即可测），其余 ⇒ `draft`；可显式 `completed` / `inProgress` / `halted` |
| `--user-fraction` | 灰度比例，仅 `inProgress` 有效 |
| `--notes` | 更新说明 |
| `--key` | 指定 service account JSON（默认 **`<工程>/.secrets/service-account.json`**，回退 `~/.gplay/service-account.json`） |
| `--aab <path>` | 直接指定 AAB，隐含 `--skip-build` |
| `--skip-build` | 跳过 Unity 打包 |
| `--no-bump` | ⚠️ 不动 versionCode（仅调试；Play **各轨道共享同一个号空间**，重复号一律被拒） |
| `--allow-no-lua` | 强行跳过「未发现 Lua bundle」闸门（风险自负） |
| `--yes` / `-y` | 跳过交互确认 |
| `--dry-run` | 只读认证 + 列轨道，不受发布闸门限制 |

退出码：`0` 成功 / `1` 有阻断项 / `2` 参数或环境错误（含被发布闸门拒绝）/ `3` 认证失败 /
`4` API 业务错误 / `5` versionCode 撞车。

## 打 APK 自测（不经过 aab_release.sh）

```bash
/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity \
  -projectpath /Users/wangxufeng/Documents/TimeSpaceGirl1 \
  -batchmode -nographics -executeMethod CLIBuilder.BuildAndroidAPK \
  -logFile /Users/wangxufeng/Documents/TimeSpaceGirl1/build_log_apk_main.txt -quit

scripts/verify_apk_delivery.py apks/<date>/CLIBuild/<HHmmss>.apk --expect minimal
```

⚠️ APK 用 **upload key**（`beauty.keystore` / alias `xing` / DN `O=EMI`）签名，与 Play 的
app signing key 不同 ⇒ **侧载前必须先卸载 Play 版**。只出 `arm64-v8a`。

## 🔴 动手前必查

1. **界面 Unity 关掉**
   ```bash
   pgrep -fl "Unity.app/Contents/MacOS/Unity"    # 只看有没有锁定**本工程**
   ```
   有 `Library/SourceAssetDB-lock` 但无 Editor 进程 = 陈旧锁，删掉即可。

2. **service account 密钥就位**（工程本地 `.secrets/` 优先）
   ```bash
   ls -la .secrets/service-account.json ~/.gplay/service-account.json 2>/dev/null
   ```
   两处都没有，先按 `docs/secrets_setup.md` §3 恢复（换机场景）；要从零申请，
   走 `docs/google_play_upload_setup.md` §1（Cloud 建账号 → Play Console 授权 → 落盘）。
   **建完账号 ≠ 能发布**，必须在 Play Console「用户和权限」里把该邮箱加为发布用户并勾
   「发布到正式版」，否则一律 403。

3. **versionCode 严格递增**
   GUI（`BuildWindow.cs`）会自增，**CLI 的 `CLIBuilder.cs` 只读不自增** ⇒
   `aab_release.sh` 默认调 `scripts/bump_version.py` 补这一步。**别随手加 `--no-bump`**。

4. **AssetBundle 已构建并拷进 StreamingAssets**
   AAB 包内资源**只来自** `Assets/StreamingAssets/Android/`。链路两段式：
   `BuildABs/Android/` → `FrameTool.CopyAssetBundleToStreamingAssets()` → `StreamingAssets/Android/`。
   **任一段没跑，构建不报错，但包里就是旧资源或缺资源。**
   最典型的是 **Lua**，其真实 bundle 名是 **`lzma|luabytes.unity3d`**
   （不带 `lua` 前缀、不在 `lua/` 目录 —— `Assets/StreamingAssets/lua/` 是遗留空目录，别当判据）。
   缺了真机启动即报 `StreamingAssets 路径资源丢失，请重新打包包内资源!`。

   ```bash
   scripts/check_ab_ready.sh      # 只读，逐项报 LuaBytes.meta / BuildConfigs / BuildABs / StreamingAssets / 最新 AAB
   ```
   GUI 侧重建顺序：**先「整体打包资源」→ 再「复制资源到流媒体目录」**；
   只有 Lua 变动时补「单打lua资源」（`FrameTool.BuildLuaAssetBundles()`）。

5. **出包配置会套用（GM 面板）**
   CLI 固定口径 `MinimalGmOff`（`isOpenGM=0`），真源在 `Assets/Editor/ReleaseBuildSettings.cs`。
   套用流程会**落盘场景**，用完 `finally` 还原。

## 关键事实

| 项 | 值 |
|---|---|
| 包名 | `com.Warera.timespace` |
| UnityEngine | `/Applications/Unity/Hub/Editor/6000.6.5f1/Unity.app/Contents/MacOS/Unity` |
| 打包方法 | `CLIBuilder.BuildAndroidAAB` / `CLIBuilder.BuildAndroidAPK` |
| 产物目录 | `apks/{yyyy-MM-dd}/CLIBuild/{HHmmss}.{aab\|apk}`（`apks/` 已 gitignore） |
| 耗时 | 全量 ~10-15 min；增量（缓存完好）APK ~1 min |
| Python | `/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python` |
| Android build-tools | `~/Library/Android/sdk/build-tools/36.0.0`（`aapt2` / `apksigner`） |

## 包内自检三件套（都在 `aab_release.sh` 里自动跑）

| 脚本 | 查什么 |
|---|---|
| `verify_aab_release_config.py <apk\|aab> --expect minimal` | 包内 `SettingInfo` 12 个 int32 特征 ⇒ 有没有带 GM 面板 |
| `verify_aab_native_16kb.py <apk\|aab>` | FAIL：64 位 `.so` 对齐 < 16384；WARN：note < r19 或 `p_align == 0x10000` |
| `verify_apk_delivery.py <apk\|aab> --expect minimal` | 一站式交付自检：版本 / 口径 / 16KB / **`libnative-googlesignin.so` 必须存在** / 签名，并写 `.delivery.json` |

## 报错怎么查

| 现象 | 根因 | 处理 |
|---|---|---|
| `edits.insert` 失败 / 401 | Cloud 未启用 Google Play Android Developer API | `docs/google_play_upload_setup.md` §1.1 |
| 403 `caller does not have permission` | Play Console 未授权该邮箱 / 漏勾「发布到正式版」 | 同上 §1.2；授权后传播要几分钟~几小时 |
| 400 `version code has already been used` | 号重复 | 检查是否误用 `--no-bump` |
| 400 `App bundle was not signed` | Play 应用签名未启用 | Console 启用 Play App Signing |
| 400 `FAILED_PRECONDITION / This Edit has been deleted.` | **并发**调了 Play API | 重跑（会新建 edit）；上传期间别跑巡检脚本 |
| 退出码 5 | versionCode 预检撞车，脚本主动拦截 | 提号后重打包 |
| 退出码 1/2 且提示「拒绝写 production 轨道」 | 没给 `--production` | 闸门在正常工作（默认只传 internal）；要发正式版就显式加 |
| 退出码 1/2 且提示「拒绝把包置为 status=completed」 | 非 internal 轨道没给 `--publish` | 同上；只传草稿用 `--status draft`。**internal 轨道不受此限** |
| `:launcher:mergeExtDexRelease FAILED` | AndroidX 与 AGP 7.4.2 dexer 不兼容 | `docs/unity_android_build_skill.md` §3 双模板 force |
| `Multiple Unity instances cannot open the same project` | 本工程 GUI Unity 占锁 | 关 GUI / 删陈旧 `Library/SourceAssetDB-lock` |
| 前置检查报「未发现 Lua bundle」 | AB 链路断开 | `scripts/check_ab_ready.sh` 定位；GUI 重建 AB |
| 真机报 `StreamingAssets 路径资源丢失…` | 发出的包不含 Lua | 重建 AB 后重打包，别用旧 AAB |
| `TimeoutError: The read operation timed out` | httplib2 60s 超时 vs 100MB 分块 | 已内置修复（300s + 8MB 分块 + 重传）；可用 `PLAY_UPLOAD_TIMEOUT_S` / `PLAY_UPLOAD_CHUNK_MB` / `PLAY_UPLOAD_MAX_RETRIES` 调 |
| AAB 只有约 139MB（正常 421MB） | AB 构建残包 | 重建 AB 再打包 |
| Unity 打印 `libtolua.so is not 16KB-aligned` | **误报**（实测 `p_align=0x4000` 达标，包内一致，Play 未点名） | 忽略，别去"修" |
| 日志有 `Application is shutting down...` 且没产包 | 进程被外部杀掉，`finally` 未执行 | 重跑；先 `git checkout -- Assets/LuaFramework/Scenes/Logo.unity` 清残留 |

## ⚠️ 易误判（别被带偏）

- **线上渠道值 `None`、`isSDK=false` 是正常的**。本作 Google 登录走的是 `not IsSDKLogin` 的
  **账号密码分支**（`LoginPanel.lua:7`）。**渠道为 None 时强行 `isSDK=true`，登录会走不存在的
  渠道 SDK 而全挂**（`ReleaseBuildSettings.Validate()` 已把它写成硬校验）。
- **「上传到 production 就是送审」对 `status=draft` 不成立**；`--changes-not-sent-for-review`
  只对 internal/alpha/beta 有效。
- **别以为「传 internal 能省 versionCode」**：Play 的 production / internal / alpha / beta
  **共享同一个 versionCode 空间**，一个号传过一次就永久占用，换轨道重传同号同样被拒。
- **internal 不是「法外之地」**：它免的是**常规发布审核**（一般几分钟即可装），
  不等于免于 Google Play 政策 —— Google 仍可事后拦截。
- **账号名 = f(登录 SDK 给的 id)**：`GetAcc("go"+id)`，`name = acc[0..12)`、`pw = acc[12..24)`，
  服务端以 `name` 为主键。历史上把 Google Sign-In（21 位数字 `UserId`）换成 Play Games
  （20 字符 `Social.localUser.id`）导致**同一个人变新号**，已回退（`f74ffb436`，**勿再改回去**）。
  判别法：查 `go` 账号的 `pw` 长度，`11` ⇒ 21 位旧 Sign-In，`10` ⇒ 20 字符 PlayGames。

## 边界

- **不要**改 `Packages/manifest.json`、三个 Gradle 模板、`Assets/Editor/CLIBuilder.cs` 的
  `PrepareAndroid()` —— 那些是构建可行性真源，改动会牵动整个打包链。
- 改**出包口径**只改 `ReleaseBuildSettings.cs` 的 `kProfile` / profile 定义。
- `aab_release.sh` 默认会改 `ProjectSettings/ProjectSettings.asset` 的 `AndroidBundleVersionCode`
  （提号），这是**预期行为**，提交时连它一起提交。
- 打包本身**不需要**密钥；密钥只在最后上传阶段用。
- `apks/` 已 gitignore，不要提交产物。

## 相关文档

- `docs/README.md` —— 文档索引 + 全流程脚本地图
- `docs/android_release_runbook.md` —— 端到端发版 runbook + 全部经验（16KB / 账号体系 / 交付自检）
- `docs/scripts_reference.md` —— 每个脚本的用途、参数、退出码
- `docs/unity_android_build_skill.md` —— 构建侧深坑（Gradle / AGP / billing / AndroidX）
- `docs/google_play_upload_setup.md` —— service account 申请、Play 后台授权、错误对照表
- `docs/client_build_chain.md` —— 改 Lua / 配置表 / AB 的正确姿势
