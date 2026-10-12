using System;
using System.Text;
using GameLogic;
using SDK;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

/// <summary>
/// 「正式包」出包配置的**唯一真源**：编辑器打包面板（BuildWindow）与命令行打包
/// （CLIBuilder）共用同一份逻辑，避免两处漂移。
///
/// 背景（2026-10-12 事故）：
///   原实现只把这段配置写在 BuildWindow.OnGUI 里，且只改**内存中**已打开场景的对象。
///   命令行入口 CLIBuilder 完全没有这一步 ⇒ 命令行出的一律是「开发态」包：
///   isOpenGM=1（带 GM 面板）、channel=None（空渠道回落 isSDK=false）、isGuide=0。
///   已从线上产物取证：production completed v64（apks/2026-10-12/CLIBuild/011824.aab）
///   的 level0 里 SettingInfo 实测为 [0,0,1,1,0,0,1,0,1,0,0,10001] ⇒ isOpenGM=1，
///   也就是说 GM 面板确实随线上包发布了。详见 docs/ 与项目记忆。
///
/// 为什么命令行必须「开场景 + 落盘」：
///   batchmode 下没有已打开的场景，BuildPipeline.BuildPlayer 会**从磁盘读**场景文件，
///   此时修改内存对象毫无意义。所以必须先 OpenScene → 改 → SaveScene，打完再还原。
/// </summary>
public static class ReleaseBuildSettings
{
    /// <summary>GameSettings 所在的场景（已登记在 EditorBuildSettings 里，索引 0）。</summary>
    public const string LogoScenePath = "Assets/LuaFramework/Scenes/Logo.unity";

    /// <summary>
    /// 出包开关快照，用于打包后把场景还原成开发态。
    /// </summary>
    public class Snapshot
    {
        public bool bundleMode, luaBundleMode, isSDK, isSDKLogin, isOpenGM, isGuide, isUpdate, isDebug;

        public static Snapshot Capture(GameSettings g)
        {
            var i = g.settingInfo;
            return new Snapshot
            {
                bundleMode = i.bundleMode,
                luaBundleMode = i.luaBundleMode,
                isSDK = i.isSDK,
                isSDKLogin = i.isSDKLogin,
                isOpenGM = i.isOpenGM,
                isGuide = i.isGuide,
                isUpdate = i.isUpdate,
                isDebug = i.isDebug,
            };
        }

        public void RestoreTo(GameSettings g)
        {
            var i = g.settingInfo;
            i.bundleMode = bundleMode;
            i.luaBundleMode = luaBundleMode;
            i.isSDK = isSDK;
            i.isSDKLogin = isSDKLogin;
            i.isOpenGM = isOpenGM;
            i.isGuide = isGuide;
            i.isUpdate = isUpdate;
            i.isDebug = isDebug;
        }
    }

    /// <summary>
    /// channel 是否配了「真实渠道」。空串与 "None" 都视为没有渠道。
    /// （比原实现多认一个「空串」：空渠道下若仍 isSDK=true，登录会走 SDK 分支而 SDK 又不存在。）
    /// </summary>
    public static bool IsRealChannel()
    {
        var ch = SDKChannelConfigManager.Instance.ChannelType;
        return !string.IsNullOrEmpty(ch) && ch != ChannelType.None.ToString();
    }

    /// <summary>
    /// 找到场景里的 GameSettings。用 includeInactive=true：该组件的 m_Enabled 在场景里是 0，
    /// 且不排除其宿主 GameObject 处于非激活状态的可能。
    /// </summary>
    public static GameSettings FindGameSettings()
    {
        return UnityEngine.Object.FindObjectOfType<GameSettings>(true);
    }

    /// <summary>
    /// 出包开关的三种口径。
    /// 之所以要分档：编辑器那个「是否正式包」勾选会**一次改 6 个开关**，其中 isGuide / isUpdate
    /// 会改变现有玩家的运行时行为（GuideManager 会把服务端引导数据读回、并开启热更检查）。
    /// 对已经在线运营的包，需要能只修「GM 面板随包发布」这一个缺陷而不动其它位。
    /// </summary>
    public enum ReleaseProfile
    {
        /// <summary>开发态：只强制 bundle 模式 + 空渠道回落。等价于编辑器勾选框未勾选。</summary>
        Dev = 0,
        /// <summary>
        /// 最小改动：只把 isOpenGM / isDebug 置 0，其余位一律保持场景原值。
        /// 用于「与线上包逐位一致、只差 GM」的修复型发版。
        /// </summary>
        MinimalGmOff = 1,
        /// <summary>完整「正式包」模板：与编辑器勾选「是否正式包」完全一致。</summary>
        FullTemplate = 2,
    }

    /// <summary>
    /// 按口径套用出包配置（**只改内存对象**，由调用方决定是否落盘）。
    /// </summary>
    public static void ApplyProfile(GameSettings gameSet, ReleaseProfile profile)
    {
        if (gameSet == null || gameSet.settingInfo == null)
            throw new InvalidOperationException("场景里找不到 GameSettings（或 settingInfo 为空），无法套用出包配置");

        var i = gameSet.settingInfo;
        i.bundleMode = true;
        i.luaBundleMode = true;

        switch (profile)
        {
            case ReleaseProfile.Dev:
                if (!IsRealChannel())
                {
                    // 空渠道下不应该用 SDK 登录
                    i.isSDK = false;
                    i.isSDKLogin = false;
                }
                break;

            case ReleaseProfile.MinimalGmOff:
                // 只关 GM 与调试开关，其它位（isGuide/isUpdate/isSDK/isSDKLogin）保持场景原值，
                // 以便与线上包逐位对齐。
                i.isOpenGM = false;
                i.isDebug = false;
                break;

            case ReleaseProfile.FullTemplate:
                i.isSDK = true;
                i.isSDKLogin = true;
                i.isOpenGM = false;
                i.isGuide = true;
                i.isUpdate = true;
                i.isDebug = false;
                if (!IsRealChannel())
                {
                    i.isSDK = false;
                    i.isSDKLogin = false;
                }
                break;
        }
    }

    /// <summary>
    /// 兼容入口：编辑器 BuildWindow 的「是否正式包」勾选 → FullTemplate / Dev。
    /// 语义与原 BuildWindow.OnGUI 完全一致，仅多认一个「空串渠道」（见 IsRealChannel）。
    /// </summary>
    public static void Apply(GameSettings gameSet, bool isRelease)
    {
        ApplyProfile(gameSet, isRelease ? ReleaseProfile.FullTemplate : ReleaseProfile.Dev);
    }

    /// <summary>把开关值排版成一行，供日志/自检取证用。</summary>
    public static string Describe(GameSettings g)
    {
        var i = g.settingInfo;
        var sb = new StringBuilder();
        sb.Append("logLevel=").Append((int)i.logLevel);
        sb.Append(" isDebug=").Append(i.isDebug ? 1 : 0);
        sb.Append(" bundleMode=").Append(i.bundleMode ? 1 : 0);
        sb.Append(" luaBundleMode=").Append(i.luaBundleMode ? 1 : 0);
        sb.Append(" isUpdate=").Append(i.isUpdate ? 1 : 0);
        sb.Append(" isSDK=").Append(i.isSDK ? 1 : 0);
        sb.Append(" isSDKLogin=").Append(i.isSDKLogin ? 1 : 0);
        sb.Append(" isGuide=").Append(i.isGuide ? 1 : 0);
        sb.Append(" isOpenGM=").Append(i.isOpenGM ? 1 : 0);
        sb.Append(" isOpenTLog=").Append(i.isOpenTLog ? 1 : 0);
        sb.Append(" isOpenBLog=").Append(i.isOpenBLog ? 1 : 0);
        sb.Append(" originLan=").Append(i.originLan);
        sb.Append(" channel=").Append(SDKChannelConfigManager.Instance.ChannelType);
        return sb.ToString();
    }

    /// <summary>
    /// 正式包的硬性自检。返回 false 表示配置不正确，调用方**必须中止打包**。
    /// 这里只校验「一票否决」的项：GM 面板、调试开关、bundle 模式、渠道与 isSDK 的一致性。
    /// </summary>
    public static bool Validate(GameSettings g, ReleaseProfile profile, out string error)
    {
        var i = g.settingInfo;
        error = null;
        if (i.isOpenGM)
        {
            error = "isOpenGM 仍为 true —— GM 面板会随包发布";
            return false;
        }
        if (i.isDebug)
        {
            error = "isDebug 仍为 true";
            return false;
        }
        if (!i.bundleMode || !i.luaBundleMode)
        {
            error = "bundleMode / luaBundleMode 未开启（真机读不到 AssetBundle 与 Lua 字节码）";
            return false;
        }
        // 渠道与 isSDK 的一致性只在会改动 isSDK 的口径下校验；
        // MinimalGmOff 故意不动 isSDK，保持与线上包一致。
        if (profile == ReleaseProfile.FullTemplate)
        {
            if (IsRealChannel() && !i.isSDK)
            {
                error = "配了真实渠道但 isSDK=false";
                return false;
            }
            if (!IsRealChannel() && i.isSDK)
            {
                error = "渠道为空但 isSDK=true（登录会走不存在的渠道 SDK）";
                return false;
            }
        }
        return true;
    }

    /// <summary>打包时会话里的快照（batchmode 用）。</summary>
    private static Snapshot s_pending;

    /// <summary>
    /// 命令行（batchmode）专用：打开 Logo 场景 → 套用正式包配置 → **落盘**。
    /// 返回 false 表示前置校验失败，调用方应中止打包。
    /// 成功后请务必在打完包时调用 <see cref="RestoreScene"/> 还原场景。
    /// </summary>
    public static bool PrepareSceneForBuild(ReleaseProfile profile, out string appliedDescription)
    {
        appliedDescription = null;

        UnityEngine.Debug.Log($"[ReleaseBuildSettings] 打开场景 {LogoScenePath} 以套用出包配置（口径={profile}）...");
        Scene scene = EditorSceneManager.OpenScene(LogoScenePath, OpenSceneMode.Single);
        if (!scene.IsValid())
        {
            UnityEngine.Debug.LogError($"[ReleaseBuildSettings] 打开场景失败：{LogoScenePath}");
            return false;
        }

        GameSettings gameSet = FindGameSettings();
        if (gameSet == null)
        {
            UnityEngine.Debug.LogError($"[ReleaseBuildSettings] 场景 {LogoScenePath} 中找不到 GameSettings");
            return false;
        }

        s_pending = Snapshot.Capture(gameSet);
        UnityEngine.Debug.Log($"[ReleaseBuildSettings] 套用前: {Describe(gameSet)}");

        ApplyProfile(gameSet, profile);

        string error;
        if (!Validate(gameSet, profile, out error))
        {
            UnityEngine.Debug.LogError($"[ReleaseBuildSettings] ❌ 出包配置校验失败：{error}");
            // 校验失败也要还原，避免把错误配置留在工程里
            s_pending.RestoreTo(gameSet);
            s_pending = null;
            return false;
        }

        appliedDescription = Describe(gameSet);
        UnityEngine.Debug.Log($"[ReleaseBuildSettings] 套用后({profile}): {appliedDescription}");

        EditorSceneManager.MarkSceneDirty(scene);
        if (!EditorSceneManager.SaveScene(scene))
        {
            UnityEngine.Debug.LogError($"[ReleaseBuildSettings] ❌ 场景落盘失败：{LogoScenePath}（batchmode 下 BuildPlayer 读磁盘，必须落盘）");
            return false;
        }
        // 故意不调用 AssetDatabase.Refresh()：SaveScene 已落盘，而 Refresh 可能触发重导入/
        // 域重载 —— 那会丢掉静态快照导致场景还原不了，也可能打断随后的 BuildPlayer。
        UnityEngine.Debug.Log($"[ReleaseBuildSettings] 场景已落盘（这是 BuildPlayer 真正会读到的内容）");
        return true;
    }

    /// <summary>把场景还原成打包前的开发态设置。</summary>
    public static void RestoreScene()
    {
        if (s_pending == null)
        {
            return;
        }
        try
        {
            GameSettings gameSet = FindGameSettings();
            if (gameSet == null || gameSet.settingInfo == null)
            {
                UnityEngine.Debug.LogWarning("[ReleaseBuildSettings] 还原时找不到 GameSettings，场景可能仍停留在正式包配置");
                return;
            }
            s_pending.RestoreTo(gameSet);
            Scene scene = SceneManager.GetActiveScene();
            if (scene.IsValid())
            {
                EditorSceneManager.MarkSceneDirty(scene);
                EditorSceneManager.SaveScene(scene);
            }
            UnityEngine.Debug.Log($"[ReleaseBuildSettings] 场景已还原为开发态: {Describe(gameSet)}");
        }
        catch (Exception e)
        {
            UnityEngine.Debug.LogError($"[ReleaseBuildSettings] 还原场景失败: {e}");
        }
        finally
        {
            s_pending = null;
        }
    }
}
