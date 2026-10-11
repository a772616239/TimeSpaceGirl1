---
name: play-aab-release
description: 为 TimeSpaceGirl1 打包 Android AAB 并上传到 Google Play 后台。当用户提到"打包 AAB""上传 Google Play""发版""传正式版/测试轨道""Play Console""aab_release"等意图时使用。覆盖 versionCode 自增、Unity batchmode 打包、产物校验、Play Developer API 上传与轨道发布。
---

# Play AAB 发版

把 Unity 工程打成 AAB 并发布到 Google Play。**一键入口是 `scripts/aab_release.sh`。**

## 什么时候用

- 用户要「打包」「出包」「打个 aab」「上传 Google Play」「发版」「传正式版 / 内测」
- 用户要排查 Play 上传报错（403 / 400 version code 已使用 / 签名被拒）

## 一键执行

```bash
cd /Users/wangxufeng/Documents/TimeSpaceGirl1

scripts/aab_release.sh                      # production 全量（默认）
scripts/aab_release.sh --track internal     # 内部测试
scripts/aab_release.sh --dry-run --skip-build   # 只验通路，不打包不上传
scripts/aab_release.sh --no-upload          # 只打包 + 校验
scripts/check_ab_ready.sh                   # 只读体检：包内资源（尤其 Lua）是否就绪
```

## 🔴 动手前必查三条

1. **Unity GUI 必须关闭**
   ```bash
   pgrep -f "Unity.app/Contents/MacOS/Unity"     # 有输出＝被占用，必须先退出
   osascript -e 'tell application "Unity" to quit'
   ```
   注意 Unity **Hub** 在跑是正常的，不算占用。若 `Library/SourceAssetDB-lock` 存在但无 Editor 进程，是陈旧锁，删掉即可。

2. **service account 密钥就位**
   ```bash
   ls -la ~/.gplay/service-account.json
   ```
   没有就别急着跑 —— 先按 `docs/google_play_upload_setup.md` §1 申请（Cloud 建账号 → Play Console 授权 → 落盘）。
   **Cloud 建完账号 ≠ 能发布**，必须在 Play Console「用户和权限」里把 service account 邮箱加为发布用户并勾「发布到正式版」，否则一律 403。

3. **versionCode 必须严格递增**
   `Assets/Editor/CLIBuilder.cs` **只读不自增** versionCode；自增逻辑只在 GUI 的
   `Assets/Scripts/Editor/GameEditor/FrameTool/BuildWindow.cs:449`。
   ⇒ CLI 打包出来的号会一直卡在同一个值，传 production 必被 Play 拒绝。
   `aab_release.sh` 默认已带 `--bump`（调 `scripts/bump_version.py`）补上这一步，**不要随意加 `--no-bump`**。

4. **AssetBundle 必须已构建并拷贝进 StreamingAssets**
   AAB 的包内资源只来自 `Assets/StreamingAssets/Android/`。AB 链路是两段式：
   `BuildABs/Android/` → `FrameTool.CopyAssetBundleToStreamingAssets()` → `StreamingAssets/Android/`。
   **任一段没跑，构建不会报错，但包里就是旧资源或缺资源。**

   最典型的坑是 **Lua**。Lua bundle 的**真实命名**（2026-10-12 取证确认，别被名字误导）：
   ```
   Assets/ManagedResources/LuaBytes.meta  → assetBundleName: lzma/luabytes
                                            assetBundleVariant: unity3d
   ⇒ BuildABs/Android/lzma/luabytes.unity3d
   ⇒ CombinePack 里按 name.Replace("/","|") 变 lzma|luabytes.unity3d
   ```
   ⚠️ **它不带 `lua` 前缀、也不在 `lua/` 子目录**（`Assets/StreamingAssets/lua/` 是遗留空目录，
   与 Lua 字节码无关，别拿它当判据）。判定是否就绪只认**文件名含 `luabytes` 的 bundle**。

   一旦缺失，真机启动即报 `StreamingAssets 路径资源丢失，请重新打包包内资源!`（`AssetBundleLoader`）。
   先跑只读体检，再决定是否重建：
   ```bash
   scripts/check_ab_ready.sh          # 只读；逐项报 LuaBytes.meta / BuildConfigs 登记 / BuildABs / StreamingAssets / 最新 AAB
   ```
   `aab_release.sh` 前置检查也会检测并**直接中止**；确需强行继续要显式加 `--allow-no-lua`。

   GUI 侧重建（`BuildWindow` 的按钮，方法定义见 `Assets/Scripts/Editor/GameEditor/FrameTool/FrameTool.cs`）：
   ```
   「整体打包资源」   FrameTool.BuildGameAssetBundles()            # 全量 AB → BuildABs/Android/（先删该目录）
   「复制资源到流媒体目录」 FrameTool.CopyAssetBundleToStreamingAssets()  # 拷 CombinePack → StreamingAssets/Android（先删该目录）
   「单打lua资源」    FrameTool.BuildLuaAssetBundles()             # 只重建 LuaBytes + ResConfigs（用于只改了 Lua 的场合）
   ```
   顺序：**先「整体打包资源」→ 再「复制资源到流媒体目录」**；只有 Lua 变动时补「单打lua资源」。
   注意「复制资源到流媒体目录」会**整目录删除** `StreamingAssets/Android`，所以它必须在 AB 构建之后跑。

   ⚠️ `Assets/Scripts/Editor/GameEditor/FrameTool/ResourcesCopy.cs` 的「Build/资源拷贝」是另一条
   手动选目录的路径，依赖 `EditorUtility.OpenFolderPanel`，batchmode 用不了，别混淆。

## 关键事实速查

| 项 | 值 |
|---|---|
| 包名 | `com.Warera.timespace` |
| Unity | `/Applications/Unity/Hub/Editor/2022.3.62f2c1/Unity.app/Contents/MacOS/Unity` |
| 打包方法 | `CLIBuilder.BuildAndroidAAB` |
| 产物目录 | `apks/{yyyy-MM-dd}/CLIBuild/{HHmmss}.aab`（体积随 bundles 变，2026-10-11 实测 139 MB，8 月记录曾 421 MB） |
| 耗时 | 约 10-15 分钟 |
| 签名 | `Assets/Scripts/Editor/AutoSignKeystore.cs` 打包前自动注入 `beauty.keystore`，无需手动配 |
| Python 解释器 | `/Users/wangxufeng/.workbuddy/binaries/python/envs/default/bin/python`（已装 google-api-python-client / google-auth） |

## 参数

| 参数 | 说明 |
|---|---|
| `--track` | `production`(默认) / `beta` / `alpha` / `internal` |
| `--status` | `completed`(默认) / `inProgress`(灰度) / `draft` / `halted` |
| `--user-fraction` | 灰度比例，仅 `inProgress` 有效（如 `0.1`） |
| `--notes` | 更新说明 |
| `--skip-build` | 复用最近 AAB，跳过打包 |
| `--no-upload` | 只打包 + 校验 |
| `--dry-run` | 认证 + 列轨道现状，不上传 |
| `--yes` | 跳过交互确认（自动化） |
| `--key` | 指定 service account JSON |
| `--no-bump` | ⚠️ 不动 versionCode |

## 退出码

`play_upload.py`：`0` 成功 / `2` 参数或环境错误 / `3` 认证失败 / `4` API 业务错误 / `5` versionCode 撞车

## 报错怎么查

| 现象 | 根因 | 处理 |
|---|---|---|
| `edits.insert` 就失败 / 401 | Cloud 未启用 Google Play Android Developer API | 见 setup 文档 §1.1 |
| 403 `caller does not have permission` | Play Console 未授权该邮箱 / 漏勾「发布到正式版」 | 见 setup 文档 §1.2；授权后等几分钟~几小时传播 |
| 400 `version code has already been used` | 号重复 | 检查是否误用 `--no-bump` |
| 400 `App bundle was not signed` | Play 应用签名未启用 | Console 启用 Play 应用签名 |
| 退出码 5 | 上传前 versionCode 预检撞车，脚本主动拦截 | 提号后重打包 |
| 日志 `:launcher:mergeExtDexRelease FAILED` | AndroidX 与 AGP 7.4.2 dexer 不兼容 | `docs/unity_android_build_skill.md` §3 双模板 force 降级 |
| 打包报 `Multiple Unity instances cannot open the same project` | GUI Unity 占锁 | 关 GUI / 删陈旧 `Library/SourceAssetDB-lock` |
| 前置检查报「未发现 Lua bundle」 | AB 链路断开：`StreamingAssets/Android` 里没有 `lzma\|luabytes.unity3d` | 跑 `scripts/check_ab_ready.sh` 定位在源侧/构建/拷贝哪一段；GUI 里「整体打包资源」→「复制资源到流媒体目录」 |
| 真机启动报 `StreamingAssets 路径资源丢失，请重新打包包内资源!` | 同上 —— 发出的 AAB 里没有 Lua | 重建 AB 后重打包，别用旧 AAB |
| 上传报 `TimeoutError: The read operation timed out` | `google-auth-httplib2` 给 httplib2 设了 60s 超时，而默认分块 100MB，421MB 走代理单块需 4 分钟 | 已内置修复（超时 300s + 8MB 分块 + 断点续传重试）。若仍需调：`PLAY_UPLOAD_TIMEOUT_S` / `PLAY_UPLOAD_CHUNK_MB` / `PLAY_UPLOAD_MAX_RETRIES` |
| AAB 只有约 139MB（正常 421MB） | **AB 构建本身残包**：只产出了约 3/4 的 bundle（缺 prefabs/texture/spine/audio/atlas） | 重建 AB（`BuildGameAssetBundles` → `CopyAssetBundleToStreamingAssets`），再打包 |

## 边界

- **不要**修改 `Assets/Editor/CLIBuilder.cs`、`Packages/manifest.json`、三个 Gradle 模板 —— 那些是打包侧真源，改动会牵动构建可行性。
- `aab_release.sh` 会改 `ProjectSettings/ProjectSettings.asset` 的 `AndroidBundleVersionCode`（提号），这是**预期行为**，提交时连同一起提交。
- 上传 production 是**外部不可逆动作**，脚本默认要求交互输入 `yes` 确认；只有自动化场景才加 `--yes`。
- 打包本身**不需要**密钥；密钥只在最后上传阶段用。

## 相关文档

- `docs/unity_android_build_skill.md` —— 打包流程与全部坑位（打包侧真源）
- `docs/google_play_upload_setup.md` —— service account 申请、Play 后台授权、错误对照表
