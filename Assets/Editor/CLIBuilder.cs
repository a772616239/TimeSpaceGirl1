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
    /// CLI 口径名 → 枚举。两侧**命名本来就不一致**：CLI 侧（build_apk.sh / aab_release.sh /
    /// Jenkins 的 EXPECT_PROFILE）统一用 release / minimal / dev / full，而枚举成员叫
    /// Release / <b>MinimalGmOff</b> / Dev / <b>FullTemplate</b>。
    ///
    /// 🔴 只靠 Enum.TryParse 会出事（2026-10-23 实测）：TS_RELEASE_PROFILE="minimal" 解析失败
    ///    ⇒ 静默回落 Release ⇒ 测试包被打成「关日志的正式包」⇒ 包内核验判
    ///    「期望 minimal，实际命中 release」整轮 FAILURE（TS-Android-TestPackage #20 / #21）。
    ///    这个 bug 的症状是「参数明明传了、日志也印了口径、产物却是另一套」，极难靠读脚本看出来。
    /// </summary>
    static bool TryParseCliProfile(string raw, out ReleaseBuildSettings.ReleaseProfile profile)
    {
        switch ((raw ?? string.Empty).Trim().ToLowerInvariant())
        {
            case "minimal": profile = ReleaseBuildSettings.ReleaseProfile.MinimalGmOff; return true;
            case "full":    profile = ReleaseBuildSettings.ReleaseProfile.FullTemplate; return true;
            case "release": profile = ReleaseBuildSettings.ReleaseProfile.Release;      return true;
            case "dev":     profile = ReleaseBuildSettings.ReleaseProfile.Dev;          return true;
        }
        profile = ReleaseBuildSettings.ReleaseProfile.Release;
        return false;
    }

    /// <summary>
    /// 命令行出包口径。**由环境变量 TS_RELEASE_PROFILE 决定**（release / minimal / dev / full），
    /// 下发方：scripts/aab_release.sh --profile、.jenkins/lib/build_apk.sh --profile。
    ///
    /// 口径语义（2026-10-22 用户定调：正式服分正式包与测试包）：
    ///   release  = 正式包：关 GM + 关日志（logLevel=Error，Log/LogWarning 静默，仅 LogError 输出）
    ///   minimal  = 测试包：关 GM，**保留全部日志**
    ///   dev/full = 历史口径，仅供对照/排查
    ///
    /// 🔴 默认取 release：漏传时宁可打出「没日志」的正式包，也不能把日志随正式包发出去。
    ///    测试包 job 必须显式传 minimal —— 漏传的后果（测试包没日志）当场就能发现，
    ///    而正式包带日志发出去则几乎不可能被发现。
    /// </summary>
    static ReleaseBuildSettings.ReleaseProfile ResolveProfile()
    {
        const ReleaseBuildSettings.ReleaseProfile kDefault = ReleaseBuildSettings.ReleaseProfile.Release;
        string raw = System.Environment.GetEnvironmentVariable("TS_RELEASE_PROFILE");
        if (string.IsNullOrEmpty(raw))
        {
            UnityEngine.Debug.Log($"[CLIBuilder] 未设置 TS_RELEASE_PROFILE，使用默认口径 {kDefault}");
            return kDefault;
        }

        // 先按 CLI 口径名映射（minimal/full 与枚举名不同名），再退回枚举原名/数字的常规解析。
        ReleaseBuildSettings.ReleaseProfile parsed;
        bool ok = TryParseCliProfile(raw, out parsed);
        if (!ok)
        {
            ok = System.Enum.TryParse(raw, true, out parsed)
                 && System.Enum.IsDefined(typeof(ReleaseBuildSettings.ReleaseProfile), parsed);
        }
        if (ok)
        {
            UnityEngine.Debug.Log($"[CLIBuilder] 出包口径 = {parsed}（来自 TS_RELEASE_PROFILE={raw}）");
            return parsed;
        }

        UnityEngine.Debug.LogWarning($"[CLIBuilder] TS_RELEASE_PROFILE=\"{raw}\" 不是合法口径，回落 {kDefault}");
        return kDefault;
    }

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

        ReleaseBuildSettings.ReleaseProfile kProfile = ResolveProfile();

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
