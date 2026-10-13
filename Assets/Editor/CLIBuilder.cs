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

    /// <summary>
    /// 命令行出包默认口径：最小改动 —— 只关 GM（isOpenGM/isDebug=0），
    /// 其余开关与线上包逐位一致（用户 2026-10-12 明确选择，避免给现有玩家推新手引导/热更）。
    /// 需要与编辑器「是否正式包」完全一致时改用 ReleaseProfile.FullTemplate。
    /// </summary>
    static readonly ReleaseBuildSettings.ReleaseProfile kProfile = ReleaseBuildSettings.ReleaseProfile.MinimalGmOff;

    /// <summary>
    /// 命令行出包共用流程：套用正式包配置 → 打 AAB/APK → 还原场景。
    /// 关键：一定要走 ReleaseBuildSettings.PrepareSceneForBuild，否则命令行产物会沿用
    /// 开发态设置（isOpenGM=1 等），参见 ReleaseBuildSettings 头部说明。
    /// </summary>
    static void BuildAndroid(bool buildAppBundle)
    {
        string kind = buildAppBundle ? "AAB" : "APK";
        UnityEngine.Debug.Log($"========== CLIBuilder BuildAndroid{kind} Start ==========");

        PrepareAndroid();
        EditorUserBuildSettings.buildAppBundle = buildAppBundle;

        string version = PlayerSettings.bundleVersion;
        int versionCode = PlayerSettings.Android.bundleVersionCode;
        UnityEngine.Debug.Log($"Building {kind} - Version: {version}, VersionCode: {versionCode}, profile={kProfile}");

        string dateStr = System.DateTime.Now.ToString("yyyy-MM-dd");
        string timeStr = System.DateTime.Now.ToString("HHmmss");
        string outputDir = $"{GetProjectPath()}/apks/{dateStr}/CLIBuild";

        if (!Directory.Exists(outputDir))
        {
            Directory.CreateDirectory(outputDir);
        }

        // 🔴 产物名必须带 versionCode：Play 轨道只认 versionCode 递增，而 versionName
        // 会长期重复（1.2.45/46/47 都可能对应同一个 name）。命名形如
        //   1.2.50_vc69_175432.aab
        // 让「哪个包是哪一号」在文件系统层面就能分辨，不用再去翻 sidecar。
        // 注意：所有消费方（aab_release.sh / play_16kb_watch.py / verify_*）都是按
        // mtime 取最新的，不解析文件名，所以加前缀不会破坏既有链路。
        string safeVersionName = System.Text.RegularExpressions.Regex.Replace(
            version ?? "0", @"[^0-9A-Za-z._-]", "_");
        string outPath = $"{outputDir}/{safeVersionName}_vc{versionCode}_{timeStr}.{(buildAppBundle ? "aab" : "apk")}";

        // 🔴 出包配置：与编辑器 BuildWindow 共用同一份逻辑（口径可选）
        string applied;
        bool ok = ReleaseBuildSettings.PrepareSceneForBuild(kProfile, out applied);
        if (!ok)
        {
            UnityEngine.Debug.LogError($"❌ {kind} 出包配置未通过自检，已中止打包（不会产出错误的包）");
            ReleaseBuildSettings.RestoreScene();
            UnityEngine.Debug.Log($"========== CLIBuilder BuildAndroid{kind} Aborted ==========");
            EditorApplication.Exit(1);
            return;
        }

        bool built = false;
        try
        {
            string[] scenePaths = EditorBuildSettingsScene.GetActiveSceneList(EditorBuildSettings.scenes);
            UnityEngine.Debug.Log($"Building with {scenePaths.Length} scenes");

            BuildPlayerOptions options = new BuildPlayerOptions
            {
                scenes = scenePaths,
                locationPathName = outPath,
                target = BuildTarget.Android,
                options = BuildOptions.None
            };

            UnityEngine.Debug.Log($"Starting BuildPipeline.BuildPlayer -> {outPath}");
            BuildPipeline.BuildPlayer(options);

            built = File.Exists(outPath);
            if (built)
            {
                FileInfo fi = new FileInfo(outPath);
                UnityEngine.Debug.Log($"✅ Build SUCCESS! {kind}: {outPath} ({fi.Length / 1024 / 1024:F2} MB)");
                WriteReleaseSidecar(outPath, kProfile.ToString(), applied);
            }
            else
            {
                UnityEngine.Debug.LogError($"❌ Build FAILED! No {kind} at: {outPath}");
            }
        }
        finally
        {
            // 不论成功失败都还原场景，避免把正式包配置留在工程里
            ReleaseBuildSettings.RestoreScene();
        }

        UnityEngine.Debug.Log($"========== CLIBuilder BuildAndroid{kind} End (built={built}) ==========");
        EditorApplication.Exit(built ? 0 : 1);
    }

    /// <summary>
    /// 把本次实际生效的出包开关写到产物旁边的 sidecar，作为「构建输入」的取证。
    /// 注意：这只是构建侧记录；包内真实值请用 scripts/verify_aab_release_config.py 解包核验。
    /// </summary>
    static void WriteReleaseSidecar(string outPath, string profile, string applied)
    {
        try
        {
            string json = "{\n" +
                          "  \"artifact\": " + JsonStr(outPath) + ",\n" +
                          "  \"versionName\": " + JsonStr(PlayerSettings.bundleVersion) + ",\n" +
                          "  \"versionCode\": " + PlayerSettings.Android.bundleVersionCode + ",\n" +
                          "  \"profile\": " + JsonStr(profile) + ",\n" +
                          "  \"releaseSettings\": " + JsonStr(applied) + "\n" +
                          "}\n";
            File.WriteAllText(outPath + ".release.json", json);
            UnityEngine.Debug.Log($"[ReleaseBuildSettings] sidecar -> {outPath}.release.json");
        }
        catch (System.Exception e)
        {
            UnityEngine.Debug.LogWarning($"[ReleaseBuildSettings] 写 sidecar 失败: {e.Message}");
        }
    }

    static string JsonStr(string s)
    {
        if (s == null)
        {
            return "null";
        }
        return "\"" + s.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
    }

    public static void BuildAndroidAAB()
    {
        BuildAndroid(true);
    }

    public static void BuildAndroidAPK()
    {
        BuildAndroid(false);
    }
}
