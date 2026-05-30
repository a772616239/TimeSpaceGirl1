using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using System.Linq;
using GameEditor.GameEditor.PlayerBuilder;
using GameLogic;
using SDK;

namespace GameEditor.FrameTool
{
    public class BuildWindow : EditorWindow
    {
        /// <summary>
        /// 版本文件名
        /// </summary>
        const string VersionsFile = "version";

        GameLogic.Version version;
        string serverPathType;
        string serverUrl;
        string resUrl;
        string logUrl;
        string sdkLodingUrl;
        string payUrl;
        string channel;
        //string subChannel;
        string packageVersion;
        string defaultVersion;

        ChannelType channelType;
        ServerPathType serverPathValue;

        /// <summary>
        /// 导出APK/XCODE工程
        /// </summary>
        bool isBuildPlayer;
        bool isRelease;
        /// <summary>
        /// 是否拷贝AB包到StreamingAssets
        /// </summary>
        bool isCopyABSToStreamingAssets;
        // Add menu named "My Window" to the Window menu
        [MenuItem("Build/BuildWindow")]
        static void Init()
        {

            // Get existing open window or if none, make a new one:
            BuildWindow window = (BuildWindow)EditorWindow.GetWindow(typeof(BuildWindow));
            window.Show();
            window.InitWindow();

        }

        void InitWindow()
        {
            InitSize();
            InitGames();
        }

        /// <summary>
        /// 初始化大小
        /// </summary>
        void InitSize()
        {
            minSize = new Vector2(500, 400);
            maxSize = new Vector2(500, 800);
        }


        /// <summary>
        /// 初始化游戏
        /// </summary>
        void InitGames()
        {
            version = new GameLogic.Version(Resources.Load<TextAsset>(VersionsFile).text);
            serverPathType = version.GetInfo("serverPathType");
            serverUrl = version.GetInfo("serverUrl");
            resUrl = version.GetInfo("resUrl");
            logUrl = version.GetInfo("logUrl");
            sdkLodingUrl = version.GetInfo("sdkLodingUrl");
            payUrl = version.GetInfo("payUrl");
            channel = version.GetInfo("channel");
            //subChannel = version.GetInfo("subChannel");
            packageVersion = version.GetInfo("packageVersion");
            defaultVersion = version.GetInfo("version");

            serverPathValue = (ServerPathType)System.Enum.Parse(typeof(ServerPathType), serverPathType);

            if (string.IsNullOrEmpty(SDKChannelConfigManager.Instance.ChannelType))
            {
                SDKChannelConfigManager.Instance.ChannelType = ChannelType.None.ToString();
            }
            channelType = (ChannelType)System.Enum.Parse(typeof(ChannelType), SDKChannelConfigManager.Instance.ChannelType);

        }

        void OnGUI()
        {
            if (version == null)
            {
                InitGames();
            }

            EditorGUILayout.BeginVertical();
            EditorGUILayout.Space();
            EditorGUILayout.LabelField(string.Format("当前平台:{0}", EditorUserBuildSettings.activeBuildTarget.ToString()));
            EditorGUILayout.Space();
            EditorGUILayout.EndVertical();

            EditorGUILayout.BeginVertical();
            channelType = (ChannelType)EditorGUILayout.EnumPopup("选择渠道", channelType);
            if (channelType.ToString() != SDKChannelConfigManager.Instance.ChannelType)
            {
                SDKChannelConfigManager.Instance.ChannelType = channelType.ToString();
            }
            if (GUILayout.Button("切换渠道", GUILayout.Height(40f)))
            {
                string backupRootPath = Application.dataPath + "/../ChannelBackup/" + SDKChannelConfigManager.Instance.ChannelType;
                if (Directory.Exists(backupRootPath))
                {
                    {//替换GameIcon等文件
                        string backupPath = backupRootPath + "/Assets";
                        string destFilePath = Path.GetDirectoryName(Application.dataPath) + "/Assets";
                        CopyAndReplaceDirectory(backupPath, destFilePath);
                    }

                    {//替换ProjectSettings.asset文件
                     //必须先保存一次。因为可能手动修改未保存，导致下边保存时把手动修改时的参数保存上
                        AssetDatabase.SaveAssets();

                        string backupPath = backupRootPath + "/ProjectSettings/ProjectSettings.asset";
                        string destFilePath = Path.GetDirectoryName(Application.dataPath) + "/ProjectSettings/ProjectSettings.asset";

                        if (File.Exists(backupPath))
                        {
                            File.Copy(backupPath, destFilePath, true);
                        }
                        else
                        {
                            Debug.LogError("未找到对应的ProjectSettingsPath.asset文件");
                        }
                    }

                    AssetDatabase.SaveAssets();
                }

                AssetDatabase.Refresh();
                ShowNotification(new GUIContent("切换渠道完成"));
            }
            EditorGUILayout.Space();
            EditorGUILayout.EndVertical();

            EditorGUILayout.BeginVertical();
            //subChannel = EditorGUILayout.TextField("SubChannel", subChannel);
            serverPathValue = (ServerPathType)EditorGUILayout.EnumPopup("选择服务器", serverPathValue);
            serverPathType = serverPathValue.ToString();
            ServerPathTypeValueAttribute pathInfo = ServerPathManager.Instance[serverPathValue];
            if (pathInfo != null)
            {
                serverUrl = pathInfo.ServerUrl;
                EditorGUILayout.LabelField("ServerUrl:         " + serverUrl);
                resUrl = pathInfo.ResUrl;
                EditorGUILayout.LabelField("ResUrl:             " + resUrl);
                logUrl = pathInfo.LogUrl;
                EditorGUILayout.LabelField("LogUrl:             " + logUrl);
                sdkLodingUrl = pathInfo.SDKLoginUrl;
                EditorGUILayout.LabelField("SDKLoginUrl:     " + sdkLodingUrl);
                payUrl = pathInfo.PayUrl;
                EditorGUILayout.LabelField("PayUrl:             " + payUrl);
                channel = pathInfo.Channel;
                EditorGUILayout.LabelField("channel:           " + channel);
            }

            //EditorGUILayout.LabelField("研发使用dev，正式pc，如有特殊咨询服务器");
            //channel = EditorGUILayout.TextField("Channel", channel);
            EditorGUILayout.LabelField("强更版本号(格式a.bcdef  a.bc代表大版本,def代表本版本强更次数,如大版本1.2.1,第2次强更就是1.21002)");
            packageVersion = EditorGUILayout.TextField("PackageVersion", packageVersion);
            EditorGUILayout.LabelField("热更版本号(等同version,version规则(最后一位是code), 如version1.2.50,code也是50)");
            defaultVersion = EditorGUILayout.TextField("Version", defaultVersion);

            EditorGUILayout.LabelField("<color=#ff0000>以上参数修改后请记得保存Version文件！！！</color>", new GUIStyle());
            if (GUILayout.Button("保存Version文件", GUILayout.Height(40f)))
            {
                SaveVersionFile();
                ShowNotification(new GUIContent("保存Version文件完成"));
            }
            EditorGUILayout.EndVertical();

            isCopyABSToStreamingAssets = EditorGUILayout.BeginToggleGroup("拷贝AssetBundle到流媒体目录(打包到App包体内)", isCopyABSToStreamingAssets);
            if (isCopyABSToStreamingAssets)
            {
                if (GUILayout.Button(@"不打资源
将资源拷贝到StreamingAssets", GUILayout.Height(40f)))
                {
                    FrameTool.CopyAssetBundleToStreamingAssets();
                }
            }
            EditorGUILayout.EndToggleGroup();
            EditorGUILayout.Space();

            isBuildPlayer = EditorGUILayout.BeginToggleGroup(GetBuildTitle(), isBuildPlayer);
            isRelease = EditorGUILayout.Toggle("是否正式包", isRelease);

            if (isBuildPlayer)
            {
                var gameSet = GameObject.FindObjectOfType<GameSettings>();
                if (gameSet != null && gameSet.settingInfo != null)
                {
                    gameSet.settingInfo.bundleMode = true;
                    gameSet.settingInfo.luaBundleMode = true;

                    if (isRelease)
                    {
                        gameSet.settingInfo.isSDK = true;
                        gameSet.settingInfo.isSDKLogin = true;
                        gameSet.settingInfo.isOpenGM = false;
                        gameSet.settingInfo.isGuide = true;
                        gameSet.settingInfo.isUpdate = true;
                        gameSet.settingInfo.isDebug = false;
                    }
                    else
                    {

                    }

                    if (SDKChannelConfigManager.Instance.ChannelType == ChannelType.None.ToString())
                    {//空渠道下不应该用SDK登录
                        gameSet.settingInfo.isSDK = false;
                        gameSet.settingInfo.isSDKLogin = false;
                    }
                }

                if (GUILayout.Button(@"不打资源直接出包
(此按钮勾选拷贝AssetBundle不生效)", GUILayout.Height(40f)))
                {
                    BuildPlayer();
                }
            }

            EditorGUILayout.EndToggleGroup();
            EditorGUILayout.Space();

            if (GUILayout.Button("整体打包资源", GUILayout.Height(40f)))
            {
                if (EditorUtility.DisplayDialog("打包提示", "打包将持续一段时间，确定打包？", "是", "否")) //显示对话框
                {
                    System.DateTime oldTime = System.DateTime.Now;

                    //打包游戏
                    FrameTool.BuildGameAssetBundles();
                    //复制 version.txt 到 AB 包输出目录
                    CopyVersionFileToBuildABs();

                    //拷贝AssetBundle到流媒体目录
                    if (isCopyABSToStreamingAssets)
                    {
                        Debug.Log("整体打包资源 isCopyABSToStreamingAssets:"+isCopyABSToStreamingAssets);
                        FrameTool.CopyAssetBundleToStreamingAssets();
                        //SaveVersionFile();
                    }

                    //是否BuildPlayer
                    if (isBuildPlayer)
                    {
                        Debug.Log("整体打包资源 isBuildPlayer:"+isBuildPlayer);

                        BuildPlayer();

                        //再次复制 version.txt 到 AB 包输出目录（此时版本号已更新）
                        CopyVersionFileToBuildABs();

                        //再次拷贝 Resources 到 StreamingAssets（此时 version.txt 已更新）
                        FrameTool.CopyResourceFiles();

                }
                    Close();

                    System.TimeSpan span = System.DateTime.Now.Subtract(oldTime);
                    Debug.Log("整体打包完毕，本次打包耗时:" + span.TotalSeconds + "秒!");
                }
            }

            if (GUILayout.Button("复制资源到流媒体目录", GUILayout.Height(40f)))
            {
                FrameTool.CopyAssetBundleToStreamingAssets();
            }
            if (GUILayout.Button("单打lua资源", GUILayout.Height(40f)))
            {
                if (EditorUtility.DisplayDialog("打包提示", "单打lua资源将持续一段时间，确定打包？", "是", "否")) //显示对话框
                {
                    if (FrameTool.BuildLuaAssetBundles())
                    {
                        //拷贝AssetBundle到流媒体目录
                        if (isCopyABSToStreamingAssets)
                        {
                            string exportPath = AssetBundle.AssetBundleConfig.GetExportPath(EditorUserBuildSettings.activeBuildTarget);
                            string targetPath = FrameTool.GetStreamingAssetPath(EditorUserBuildSettings.activeBuildTarget);
                            File.Copy(exportPath + "/lzma/luabytes.unity3d", targetPath + "/lzma/luabytes.unity3d", true);
                            File.Copy(exportPath + "/lzma/resconfigs.unity3d", targetPath + "/lzma/resconfigs.unity3d", true);
                            File.Copy(exportPath + "/files.unity3d", targetPath + "/files.unity3d", true);
                            //SaveVersionFile();
                        }

                        //是否BuildPlayer
                        if (isBuildPlayer)
                        {
                            BuildPlayer();
                        }
                        Close();
                    }
                }
            }
            if (GUILayout.Button("资源合法性检查", GUILayout.Height(40f)))
            {
                FrameTool.CheckAssetBundleStates();
            }
            if (GUILayout.Button("查看多依赖资源", GUILayout.Height(40f)))
            {
                FrameTool.AssetsDuplicatedInMultBundlesCache(1);
            }
            if (GUILayout.Button("处理多依赖资源", GUILayout.Height(40f)))
            {
                FrameTool.AssetsDuplicatedInMultBundlesCache(2);
            }
        }

        //打完资源和保存配置时 拷贝version文件到对应打出的资源文件夹
        void CopyVersionFileToBuildABs()
        {
            File.Copy(Application.dataPath + "/Resources/" + VersionsFile + ".txt", AssetBundle.AssetBundleConfig.GetExportPath(EditorUserBuildSettings.activeBuildTarget) + "/" + VersionsFile + ".txt", true);
        }

        void SaveVersionFile()
        {
            var VersionsFilePath = Application.dataPath + "/Resources/" + VersionsFile + ".txt";
            var VersionsFilePath2 = AppConst.PersistentDataPath + VersionsFile + ".txt";

            version.SetInfo("serverPathType", serverPathType);
            version.SetInfo("serverUrl", serverUrl);
            version.SetInfo("resUrl", resUrl);
            version.SetInfo("logUrl", logUrl);
            version.SetInfo("sdkLodingUrl", sdkLodingUrl);
            version.SetInfo("payUrl", payUrl);
            version.SetInfo("channel", channel);
            //version.SetInfo("subChannel", subChannel);

            if (CheckPackageVersion())
            {
                version.SetInfo("packageVersion", packageVersion);
            }

            if (CheckVersion() != -1)
            {
                version.SetInfo("version", defaultVersion);
            }

            System.Text.Encoding utf8 = new System.Text.UTF8Encoding(false);/*System.Text.Encoding.UTF8*/

            string directoryPath = Path.GetDirectoryName(VersionsFilePath);
            if (!Directory.Exists(directoryPath))
                Directory.CreateDirectory(directoryPath);
            File.WriteAllText(VersionsFilePath, version.ToJson(), utf8);

            string directoryPath2 = Path.GetDirectoryName(VersionsFilePath2);
            if (!Directory.Exists(directoryPath2))
                Directory.CreateDirectory(directoryPath2);
            File.WriteAllText(VersionsFilePath2, version.ToJson(), utf8);

            AssetDatabase.Refresh();
        }

        /// <summary>
        /// 热更版本号合法检测
        /// </summary>
        /// <returns>-1不合法</returns>
        int CheckVersion()
        {
            int code;
            string[] arr = defaultVersion.Split('.');
            if (arr.Length != 3 || !int.TryParse(arr[2], out code))
            {
                Debug.LogError("热更版本号格式不正确！！");
                return -1;
            }
            return code;
        }

        /// <summary>
        /// 强更版本号合法检测
        /// </summary>
        /// <returns></returns>
        bool CheckPackageVersion()
        {
            float _value;
            if (!float.TryParse(packageVersion, out _value))
            {
                Debug.LogError("强更版本号格式不正确！！");
                return false;
            }
            else
            {
                return true;
            }
        }

        /// <summary>
        /// 获取是否打包
        /// </summary>
        /// <returns></returns>
        string GetBuildTitle()
        {
            switch (EditorUserBuildSettings.activeBuildTarget)
            {
                case BuildTarget.Android:
                    return "导出APK/Gradle";
                case BuildTarget.iOS:
                    return "导出XCODE工程";
            }
            return "请切换到Android/IOS平台";
        }

        /// <summary>
        /// 导出APK/XCODE工程
        /// </summary>
        void BuildPlayer()
        {
            int code = CheckVersion();
            if (code != -1)
            {
                // 每次打包自增版本号并保存
                code += 1;
                string[] arr = defaultVersion.Split('.');
                defaultVersion = arr[0] + "." + arr[1] + "." + code;
                SaveVersionFile();

                //版本号
                PlayerSettings.bundleVersion = defaultVersion;

                // BundleVersionCode 独立自增并保存
                PlayerSettings.Android.bundleVersionCode++;
                PlayerSettings.iOS.buildNumber = PlayerSettings.Android.bundleVersionCode.ToString();
                
                // 确保 ProjectSettings 的修改被保存落盘
                AssetDatabase.SaveAssets();
            }

            // 在打包前确保 Android/Resources/version.txt 是最新版本
            CopyVersionToAndroidResources();
            
            PlayerBuilder.Export(isRelease);
            
            // 等待一下让文件写入完成
            System.Threading.Thread.Sleep(1000);
            
            // 自动安装 APK 到手机
            InstallAPKToPhone();
        }



        /// <summary>
        /// 文件夹拷贝到指定文件夹,同名的会替换
        /// </summary>
        /// <param name="srcPath"></param>
        /// <param name="dstPath"></param>
        static void CopyAndReplaceDirectory(string srcPath, string dstPath)
        {
            if (!Directory.Exists(dstPath))
            {
                Directory.CreateDirectory(dstPath);
            }

            Directory.CreateDirectory(dstPath);

            foreach (var file in Directory.GetFiles(srcPath))
            {
                Debug.Log(Path.Combine(dstPath, Path.GetFileName(file)));
                File.Copy(file, Path.Combine(dstPath, Path.GetFileName(file)), true);
            }

            foreach (var dir in Directory.GetDirectories(srcPath))
            {
                CopyAndReplaceDirectory(dir, Path.Combine(dstPath, Path.GetFileName(dir)));
            }
        }

        /// <summary>
        /// 拷贝 version.txt 到 Android/Resources 目录（用于打包进 APK）
        /// </summary>
        void CopyVersionToAndroidResources()
        {
            string sourcePath = Application.dataPath + "/Resources/version.txt";
            // Unity 的 Assets/Android/Resources 目录会被自动打包进 APK
            string destDir = Application.dataPath + "/Android/Resources/";
            string destPath = destDir + "version.txt";
            
            UnityEngine.Debug.LogFormat("========== CopyVersionToAndroidResources Start ==========");
            UnityEngine.Debug.LogFormat("Source path: {0}", sourcePath);
            UnityEngine.Debug.LogFormat("Dest dir: {0}", destDir);
            UnityEngine.Debug.LogFormat("Dest path: {0}", destPath);
            
            if (File.Exists(sourcePath))
            {
                // 先读取源文件内容确认版本号
                string content = File.ReadAllText(sourcePath);
                UnityEngine.Debug.LogFormat("Source version.txt content: {0}", content);
                
                if (!Directory.Exists(destDir))
                {
                    UnityEngine.Debug.LogFormat("Creating directory: {0}", destDir);
                    Directory.CreateDirectory(destDir);
                }
                File.Copy(sourcePath, destPath, true);
                
                // 写入后立即读取目标文件验证
                string destContent = File.ReadAllText(destPath);
                UnityEngine.Debug.LogFormat("Copied to: {0}, Content: {1}", destPath, destContent);
                
                UnityEngine.Debug.LogFormat("✅ Successfully copied version.txt to Android project");
                UnityEngine.Debug.LogFormat("========== CopyVersionToAndroidResources End ==========");
                
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh();
            }
            else
            {
                UnityEngine.Debug.LogError("CopyVersionToAndroidResources version.txt not found: " + sourcePath);
                UnityEngine.Debug.LogFormat("========== CopyVersionToAndroidResources FAILED ==========");
            }
        }

        /// <summary>
        /// 自动安装 APK 到手机
        /// </summary>
        void InstallAPKToPhone()
        {
            // 检查 adb 是否可用
            string adbPath = GetADBPath();
            if (!IsADBAvailable())
            {
                UnityEngine.Debug.LogWarning("adb 不可用或没有连接设备，跳过自动安装");
                ShowNotification(new GUIContent("⚠️ adb 不可用，请检查设备连接"));
                return;
            }
            
            // 查找最新的 APK 文件
            string apkPath = FindLatestAPK();
            
            if (string.IsNullOrEmpty(apkPath))
            {
                UnityEngine.Debug.LogWarning("未找到 APK 文件，跳过安装");
                return;
            }
            
            UnityEngine.Debug.LogFormat("准备安装 APK 到手机：{0}", apkPath);
            
            // 检查 adb 是否可用
            System.Diagnostics.ProcessStartInfo startInfo = new System.Diagnostics.ProcessStartInfo
            {
                FileName = adbPath,
                Arguments = $"install -r \"{apkPath}\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            
            try
            {
                using (System.Diagnostics.Process process = System.Diagnostics.Process.Start(startInfo))
                {
                    string output = process.StandardOutput.ReadToEnd();
                    string error = process.StandardError.ReadToEnd();
                    process.WaitForExit();
                    
                    if (process.ExitCode == 0)
                    {
                        UnityEngine.Debug.LogFormat("✅ APK 安装成功：{0}", apkPath);
                        ShowNotification(new GUIContent("✅ APK 安装成功"));
                    }
                    else
                    {
                        UnityEngine.Debug.LogErrorFormat("❌ APK 安装失败：{0}", error);
                        ShowNotification(new GUIContent($"❌ APK 安装失败：{error}"));
                    }
                }
            }
            catch (System.Exception e)
            {
                UnityEngine.Debug.LogErrorFormat("adb install 错误：{0}", e.Message);
                ShowNotification(new GUIContent($"❌ adb 安装错误：{e.Message}"));
            }
        }
        
        /// <summary>
        /// 检查 adb 是否可用且有设备连接
        /// </summary>
        bool IsADBAvailable()
        {
            string adbPath = GetADBPath();
            
            try
            {
                System.Diagnostics.ProcessStartInfo startInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = adbPath,
                    Arguments = "devices",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };
                
                using (System.Diagnostics.Process process = System.Diagnostics.Process.Start(startInfo))
                {
                    string output = process.StandardOutput.ReadToEnd();
                    process.WaitForExit();
                    
                    // 检查输出中是否有设备（除了标题行"Devices"）
                    string[] lines = output.Split('\n');
                    int deviceCount = 0;
                    for (int i = 1; i < lines.Length; i++) // 跳过第一行标题
                    {
                        if (lines[i].Contains("device") && !string.IsNullOrWhiteSpace(lines[i]))
                        {
                            deviceCount++;
                        }
                    }
                    
                    if (deviceCount > 0)
                    {
                        UnityEngine.Debug.LogFormat("检测到 {0} 个已连接设备", deviceCount);
                        return true;
                    }
                    else
                    {
                        return false;
                    }
                }
            }
            catch (System.Exception e)
            {
                UnityEngine.Debug.LogErrorFormat("检查 adb 状态错误：{0}", e.Message);
                return false;
            }
        }
        
        /// <summary>
        /// 获取 adb 路径（优先使用环境变量，否则尝试常见路径）
        /// </summary>
        string GetADBPath()
        {
            // 1. 先尝试直接使用 adb 命令（从 PATH）
            if (IsCommandAvailable("adb"))
            {
                return "adb";
            }
            
            // 2. 尝试 Android SDK 常见路径
            string[] possiblePaths = new string[]
            {
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) + "/Library/android-sdk/platform-tools/adb",
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile) + "/android-sdk/platform-tools/adb",
                "/Users/" + System.Environment.UserName + "/Library/android-sdk/platform-tools/adb",
                "/Users/" + System.Environment.UserName + "/android-sdk/platform-tools/adb",
                Application.dataPath + "/../AndroidSDK/platform-tools/adb",
                Application.dataPath + "/../sdk/platform-tools/adb"
            };
            
            foreach (string path in possiblePaths)
            {
                if (File.Exists(path))
                {
                    UnityEngine.Debug.LogFormat("找到 adb: {0}", path);
                    return path;
                }
            }
            
            // 3. 尝试在 Unity 安装目录中查找
            string unityPath = Application.dataPath.Replace("/Assets", "");
            string[] unityPossiblePaths = new string[]
            {
                unityPath + "/AndroidSDK/platform-tools/adb",
                unityPath + "/sdk/platform-tools/adb"
            };
            
            foreach (string path in unityPossiblePaths)
            {
                if (File.Exists(path))
                {
                    UnityEngine.Debug.LogFormat("找到 adb: {0}", path);
                    return path;
                }
            }
            
            UnityEngine.Debug.LogWarning("未找到 adb 工具，请确保已安装 Android SDK 并配置好 PATH");
            return "adb"; // 返回默认值，让后续错误处理显示友好提示
        }
        
        /// <summary>
        /// 检查命令是否在 PATH 中可用
        /// </summary>
        bool IsCommandAvailable(string command)
        {
            try
            {
                System.Diagnostics.ProcessStartInfo startInfo = new System.Diagnostics.ProcessStartInfo
                {
                    FileName = "which",
                    Arguments = command,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };
                
                using (System.Diagnostics.Process process = System.Diagnostics.Process.Start(startInfo))
                {
                    process.WaitForExit();
                    return process.ExitCode == 0;
                }
            }
            catch
            {
                return false;
            }
        }
        
        /// <summary>
        /// 查找最新的 APK 文件
        /// </summary>
        string FindLatestAPK()
        {
            string apksDir = Application.dataPath + "/../apks/" + System.DateTime.Now.ToString("yyyy-MM-dd") + "/None/";
            
            if (!Directory.Exists(apksDir))
            {
                UnityEngine.Debug.LogWarning("APK 目录不存在：" + apksDir);
                return null;
            }
            
            var apkFiles = System.IO.Directory.GetFiles(apksDir, "*.apk").ToList();
            if (apkFiles.Count == 0)
            {
                UnityEngine.Debug.LogWarning("未找到 APK 文件");
                return null;
            }
            
            // 按修改时间排序，获取最新的 APK
            apkFiles.Sort((a, b) => System.IO.File.GetLastWriteTime(b).CompareTo(System.IO.File.GetLastWriteTime(a)));
            string latestApk = apkFiles[0];
            
            UnityEngine.Debug.LogFormat("找到最新 APK: {0}", latestApk);
            return latestApk;
        }

    }

}
