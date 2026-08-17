# Unity Android 打包流程（IAP Billing 8+ 升级 + CLI 打包）

> 适用范围：TimeSpaceGirl1 项目（Unity 2022.3.62f2c1）
> 更新时间：2026-08-17（已验证成功：APK 454MB + AAB 421MB，billing 9.0.0）

---

## 1. 项目关键信息

| 项 | 值 |
|---|---|
| 项目路径 | `/Users/wangxufeng/Documents/TimeSpaceGirl1/` |
| Unity 版本 | 2022.3.62f2c1（ProjectSettings/ProjectVersion.txt） |
| 应用 ID | `com.Warera.timespace` |
| versionName / versionCode | 1.2.45 / 62（打包时自动自增） |
| minSdk / targetSdk | 24 / 36 |
| ABI | 仅 arm64-v8a |
| 脚本后端 | IL2CPP |
| keystore | `beauty.keystore`（alias `xing`） |
| 输出目录 | `apks/{yyyy-MM-dd}/CLIBuild/{HHmmss}.apk|.aab` |
| IAP 版本 | com.unity.purchasing 5.4.2（注入 billing 9.0.0） |

---

## 2. 升级 com.unity.purchasing 到 Billing 8.0.0+（Google Play 2026-08-31 要求）

### 2.1 背景
- Google Play 要求所有应用使用 Billing Library 8.0.0+（2026-08-31 截止）
- 旧版 `com.unity.purchasing 5.0.0-pre.6` 注入的是 billing 7.1.1 ❌
- 升级到 `5.4.2`（2026-07-24 发布）注入 billing **9.0.0** ✅

### 2.2 修改文件
1. **`Packages/manifest.json`**
   ```json
   "com.unity.purchasing": "5.4.2",
   ```
2. **`Packages/packages-lock.json`**
   - `com.unity.purchasing` 版本改为 `5.4.2`
   - `com.unity.services.core` 依赖更新为 `1.18.0`（5.4.2 所需）
3. **旧缓存目录重命名**（不删除，保留备份）：
   ```
   Library/PackageCache/com.unity.purchasing@5.0.0-pre.6 → 加 .bak 后缀
   ```
   否则 Unity 可能继续用旧缓存不重新拉取。

### 2.3 兼容性确认
- 5.x 保留 legacy API 向后兼容层：`IStoreListener`, `IStoreController`, `IExtensionProvider`, `ConfigurationBuilder`, `StandardPurchasingModule`, `UnityPurchasing.Initialize` 全部可用
- API 重命名仅影响 5.0.0-pre.1 后新 API（如 `IStoreService.ConnectAsync`→`Connect`），不影响现有代码
- 项目 IAP 代码：`Assets/Scripts/IAP/IAPManager.cs`（有效）、`ShopCoinIAP.cs`（已注释）、`Assets/Source/Generate/IAPManagerWrap.cs`（tolua wrap，无需改）

### 2.4 验证 billing 版本
billing 版本由 IAP 包自动注入，**无需手动改 gradle**：
```
Library/PackageCache/com.unity.purchasing@5.4.2/Plugins/UnityPurchasing/Android/IAPResolver/IAPAndroidDependencies.cs
```
构建日志中看到 `IAPResolver.IAPAndroidDependencies.OnPostGenerateGradleAndroidProject` 被调用即生效。
产物验证：`~/.gradle/caches/modules-2/files-2.1/com.android.billingclient/billing/` 下应有 `9.0.0`。

---

## 3. 核心坑：billing 9.0.0 与 AGP 7.4.2 dexer 不兼容

### 3.1 症状
- Gradle 构建失败：`:launcher:mergeExtDexRelease FAILED`
- 报错：`DexingNoClasspathTransform` + `StackOverflowError` / `D8: java.lang.NullPointerException`
- 根因：billing 9.0.0 传递依赖拉入 `androidx.core:core:1.15.0`，AGP 7.4.2 的 dexer 处理不了新版本 AndroidX

### 3.2 解法（已验证 ✅）：双模板 resolutionStrategy.force
**保留 AGP 7.4.2 + Gradle 7.5.1 不动**，把 AndroidX 强制降级到兼容版本。

**`Assets/Plugins/Android/mainTemplate.gradle`**（unityLibrary 模块）头部加：
```gradle
configurations.all {
    resolutionStrategy {
        force 'androidx.core:core:1.10.1'
        force 'androidx.core:core-ktx:1.10.1'
        force 'androidx.annotation:annotation:1.7.0'
        force 'androidx.collection:collection:1.3.0'
        force 'androidx.lifecycle:lifecycle-common:2.6.2'
        force 'androidx.lifecycle:lifecycle-runtime:2.6.2'
        force 'androidx.lifecycle:lifecycle-viewmodel:2.6.2'
        force 'androidx.lifecycle:lifecycle-livedata-core:2.6.2'
    }
}
```
并在 dependencies 里显式钉住（可选，双保险）：
```gradle
implementation 'androidx.core:core:1.10.1'
implementation 'androidx.annotation:annotation:1.7.0'
```

**`Assets/Plugins/Android/launcherTemplate.gradle`**（launcher 模块）头部加同样的 `configurations.all { resolutionStrategy { force ... } }`。

⚠️ **launcherTemplate.gradle 的关键规则**：
- **不能含 `**DEPS**` 占位符**！Unity 会注入 `implementation project('FirebaseCrashlytics.androidlib')` 等引用，但这些子项目没在 settings.gradle 里 include，报 `Project with path '...' could not be found`
- launcher 只应依赖 `implementation project(':unityLibrary')`

### 3.3 为什么 force 要写两个模板
- `mainTemplate.gradle` 的 force 只对 unityLibrary 模块生效
- 错误发生在 `:launcher:mergeExtDexRelease`，launcher 模块的 build.gradle 由 Unity 生成，归 `launcherTemplate.gradle` 管
- 两个模板都加 force 才能全覆盖

---

## 4. 其他必须保留的配置

### 4.1 `Assets/Plugins/Android/gradleTemplate.properties`
```properties
org.gradle.jvmargs=-Xmx**JVM_HEAP_SIZE**M
org.gradle.parallel=true
org.gradle.caching=true
unityStreamingAssets=**STREAMING_ASSETS**
# Android Resolver Properties Start
android.useAndroidX=true
android.enableJetifier=true
# Android Resolver Properties End
**ADDITIONAL_PROPERTIES**
```
⚠️ 注意：GUI Unity 打开工程时可能重置此文件，打包前需确认 `useAndroidX`/`enableJetifier` 还在。

### 4.2 已验证失败的方案（不要走）
| 方案 | 失败原因 |
|---|---|
| AGP 升级 8.5.2/8.7.4 + Gradle 8.9 | `verifyReleaseResources` 报 missing app_icon/app_name（launcher 有资源但 unityLibrary manifest 跨模块引用）；且 AGP 8.x 需要 NDK 26.1，Unity 自带 NDK 23.1.7779620 冲突；`OnPostGenerateGradleAndroidProject` 回调改文件会被 Unity 重新写入覆盖 |
| 仅 mainTemplate.gradle force | 对 launcher 模块无效，`:launcher:mergeExtDexRelease` 仍失败 |
| launcherTemplate.gradle 含 `**DEPS**` | 子项目引用找不到 |

---

## 5. CLI 打包脚本

### 5.1 `Assets/Editor/CLIBuilder.cs`（完整源码）
```csharp
using UnityEditor;
using UnityEngine;
using System.IO;
using System.Diagnostics;

public class CLIBuilder
{
    static string GetProjectPath()
    {
        return Path.GetDirectoryName(Application.dataPath);
    }

    static void PrepareAndroid()
    {
        // Ensure Android platform
        if (EditorUserBuildSettings.activeBuildTarget != BuildTarget.Android)
        {
            EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android);
        }

        // Configure build settings
        EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;
        EditorUserBuildSettings.exportAsGoogleAndroidProject = false;

        EditorUserBuildSettings.development = false;
        PlayerSettings.SetScriptingBackend(BuildTargetGroup.Android, ScriptingImplementation.IL2CPP);
        PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevel36;
    }

    public static void BuildAndroidAAB()
    {
        UnityEngine.Debug.Log("========== CLIBuilder BuildAndroidAAB Start ==========");
        PrepareAndroid();

        EditorUserBuildSettings.buildAppBundle = true;

        string version = PlayerSettings.bundleVersion;
        int versionCode = PlayerSettings.Android.bundleVersionCode;
        UnityEngine.Debug.Log($"Building AAB - Version: {version}, VersionCode: {versionCode}");

        string dateStr = System.DateTime.Now.ToString("yyyy-MM-dd");
        string timeStr = System.DateTime.Now.ToString("HHmmss");
        string outputDir = $"{GetProjectPath()}/apks/{dateStr}/CLIBuild";

        if (!Directory.Exists(outputDir))
        {
            Directory.CreateDirectory(outputDir);
        }

        string aabPath = $"{outputDir}/{timeStr}.aab";

        // Get active scenes
        string[] scenePaths = EditorBuildSettingsScene.GetActiveSceneList(EditorBuildSettings.scenes);
        UnityEngine.Debug.Log($"Building with {scenePaths.Length} scenes");

        BuildPlayerOptions options = new BuildPlayerOptions
        {
            scenes = scenePaths,
            locationPathName = aabPath,
            target = BuildTarget.Android,
            options = BuildOptions.None
        };

        UnityEngine.Debug.Log($"Starting BuildPipeline.BuildPlayer -> {aabPath}");
        BuildPipeline.BuildPlayer(options);

        if (File.Exists(aabPath))
        {
            FileInfo fi = new FileInfo(aabPath);
            UnityEngine.Debug.Log($"✅ Build SUCCESS! AAB: {aabPath} ({fi.Length / 1024 / 1024:F2} MB)");
        }
        else
        {
            UnityEngine.Debug.LogError($"❌ Build FAILED! No AAB at: {aabPath}");
        }

        UnityEngine.Debug.Log("========== CLIBuilder BuildAndroidAAB End ==========");
        EditorApplication.Exit(0);
    }

    public static void BuildAndroidAPK()
    {
        UnityEngine.Debug.Log("========== CLIBuilder BuildAndroidAPK Start ==========");

        PrepareAndroid();

        EditorUserBuildSettings.buildAppBundle = false;

        string version = PlayerSettings.bundleVersion;
        int versionCode = PlayerSettings.Android.bundleVersionCode;
        UnityEngine.Debug.Log($"Building APK - Version: {version}, VersionCode: {versionCode}");

        // Output path
        string dateStr = System.DateTime.Now.ToString("yyyy-MM-dd");
        string timeStr = System.DateTime.Now.ToString("HHmmss");
        string outputDir = $"{GetProjectPath()}/apks/{dateStr}/CLIBuild";

        if (!Directory.Exists(outputDir))
        {
            Directory.CreateDirectory(outputDir);
        }

        string apkPath = $"{outputDir}/{timeStr}.apk";

        // Get active scenes
        string[] scenePaths = EditorBuildSettingsScene.GetActiveSceneList(EditorBuildSettings.scenes);
        UnityEngine.Debug.Log($"Building with {scenePaths.Length} scenes");

        // Build APK directly
        BuildPlayerOptions options = new BuildPlayerOptions
        {
            scenes = scenePaths,
            locationPathName = apkPath,
            target = BuildTarget.Android,
            options = BuildOptions.None
        };

        UnityEngine.Debug.Log($"Starting BuildPipeline.BuildPlayer -> {apkPath}");
        BuildPipeline.BuildPlayer(options);

        if (File.Exists(apkPath))
        {
            FileInfo fi = new FileInfo(apkPath);
            UnityEngine.Debug.Log($"✅ Build SUCCESS! APK: {apkPath} ({fi.Length / 1024 / 1024:F2} MB)");
        }
        else
        {
            UnityEngine.Debug.LogError($"❌ Build FAILED! No APK at: {apkPath}");
        }

        UnityEngine.Debug.Log("========== CLIBuilder BuildAndroidAPK End ==========");
        EditorApplication.Exit(0);
    }
}
```

⚠️ **注意**：
- `EditorBuildSettingsScene.GetActiveSceneList(EditorBuildSettings.scenes)` 返回值是 `string[]`（不是 `EditorBuildSettingsScene[]`），直接赋值即可
- `BuildPlayerOptions.scenes` 需要 `string[]`

### 5.2 命令行打包命令

**打包 APK：**
```bash
/Applications/Unity/Hub/Editor/2022.3.62f2c1/Unity.app/Contents/MacOS/Unity \
  -projectpath /Users/wangxufeng/Documents/TimeSpaceGirl1 \
  -batchmode -nographics \
  -executeMethod CLIBuilder.BuildAndroidAPK \
  -logFile /Users/wangxufeng/Documents/TimeSpaceGirl1/build_log.txt \
  -quit
```

**打包 AAB：**
```bash
/Applications/Unity/Hub/Editor/2022.3.62f2c1/Unity.app/Contents/MacOS/Unity \
  -projectpath /Users/wangxufeng/Documents/TimeSpaceGirl1 \
  -batchmode -nographics \
  -executeMethod CLIBuilder.BuildAndroidAAB \
  -logFile /Users/wangxufeng/Documents/TimeSpaceGirl1/build_log_aab.txt \
  -quit
```

### 5.3 前置检查（打包前必做）
1. **关闭 GUI Unity**（AppleScript：`osascript -e 'tell application "Unity" to quit'`）
   - GUI 实例占用工程锁（`Library/SourceAssetDB-lock`），batchmode 无法并行
   - 报错：`Multiple Unity instances cannot open the same project`
2. 确认 `launcherTemplate.gradle` / `mainTemplate.gradle` / `gradleTemplate.properties` 三个文件内容完整（GUI 可能重置）
3. 确认 `Assets/Editor/CLIBuilder.cs` 存在
4. 确认 `Packages/manifest.json` 中 `com.unity.purchasing` 为 `5.4.2`

---

## 6. 构建时间线（参考）

| 阶段 | 耗时 |
|---|---|
| Unity 启动 + 脚本编译 | ~1-2 min |
| IL2CPP 编译（4550 步） | ~5-8 min |
| Gradle 构建 | ~2-4 min |
| **总计** | **~10-15 min** |

---

## 7. 产物验证清单

### 7.1 APK 验证
```bash
AAPT="/Applications/Unity/Hub/Editor/2022.3.62f2c1/PlaybackEngines/AndroidPlayer/SDK/build-tools/34.0.0/aapt"
"$AAPT" dump badging "$APK" | grep -E "^package|sdkVersion|targetSdkVersion"
# 期望: package: name='com.Warera.timespace' versionCode='62' versionName='1.2.45'
#       sdkVersion:'24'  targetSdkVersion:'36'

# 签名验证
APKSIGNER=$(find "/Applications/Unity/Hub/Editor/2022.3.62f2c1" -name "apksigner" | head -1)
"$APKSIGNER" verify --print-certs "$APK"
# 期望: Signer #1 certificate DN: O=EMI
```

### 7.2 AAB 验证
```bash
unzip -l "$AAB" | grep -E "BundleConfig|base/manifest"  # 结构完整
unzip -p "$AAB" BUNDLE-METADATA/com.android.tools.build.gradle/app-metadata.properties
# 期望: androidGradlePluginVersion=7.4.2
```

### 7.3 billing 版本验证
```bash
# gradle 缓存（构建实际解析版本）
ls ~/.gradle/caches/modules-2/files-2.1/com.android.billingclient/billing/
# 期望: 9.0.0

# APK/AAB 内含 billing 9.x 特有资源
unzip -l "$APK" | grep -iE "heterodyne|registration_info"
```

### 7.4 AndroidX 降级验证
```bash
ls ~/.gradle/caches/modules-2/files-2.1/androidx.core/core/
# 期望同时有 1.15.0（被拒绝）+ 1.10.1（实际使用），说明 force 生效
```

---

## 8. 常见错误速查

| 错误 | 原因 | 解法 |
|---|---|---|
| `Multiple Unity instances cannot open the same project` | GUI Unity 占用工程 | 关闭 GUI 再 batchmode |
| `:launcher:mergeExtDexRelease FAILED` + StackOverflow/NPE | AndroidX core 1.15.0 与 AGP 7.4.2 dexer 不兼容 | 双模板 force 降级 AndroidX |
| `Project with path 'FirebaseCrashlytics.androidlib' could not be found` | launcherTemplate.gradle 含 `**DEPS**` | 移除 `**DEPS**`，只留 `implementation project(':unityLibrary')` |
| `NDK is not installed` | AGP 8.x 默认要 NDK 26.1，Unity 只有 23.1.7779620 | 别升级 AGP，用 7.4.2 |
| `verifyReleaseResources` missing app_icon/app_name | AGP 8.x 方案 | 放弃 AGP 8.x，回到 7.4.2 |
| gradleTemplate.properties 被重置 | GUI Unity 打开工程时覆盖 | 打包前检查 useAndroidX/Jetifier |
| 构建日志只有 `BUILD FAILED in 6s` 无详情 | 缺少 `--stacktrace` | 用 `-logFile` 全量日志排查 |

---

## 9. 相关环境路径

```bash
# Unity 自带工具
UNITY_ANDROID="/Applications/Unity/Hub/Editor/2022.3.62f2c1/PlaybackEngines/AndroidPlayer"
# Gradle 7.5.1（Unity 自带）: $UNITY_ANDROID/Tools/gradle
# NDK 23.1.7779620: $UNITY_ANDROID/NDK
# JDK 11（Unity 自带）: $UNITY_ANDROID/OpenJDK

# 本机其他 JDK（AGP 8.x 需要 Java 17+，本项目未用）
# JDK 21: /usr/local/Cellar/openjdk@21/21.0.10/libexec/openjdk.jdk/Contents/Home

# Gradle 8.9（本机缓存，AGP 8.x 方案用，已放弃）
# ~/.gradle/wrapper/dists/gradle-8.9-bin/90cnw93cvbtalezasaz0blq0a/gradle-8.9/
```
