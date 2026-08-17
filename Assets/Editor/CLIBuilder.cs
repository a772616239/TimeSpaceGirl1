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
