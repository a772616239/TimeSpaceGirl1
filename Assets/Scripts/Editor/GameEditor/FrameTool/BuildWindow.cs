using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
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

        Version version;
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
            version = new Version(Resources.Load<TextAsset>(VersionsFile).text);
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
                if (gameSet.settingInfo != null)
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
                //版本号
                PlayerSettings.bundleVersion = defaultVersion;

                //热更版本号
                PlayerSettings.Android.bundleVersionCode = code;
                PlayerSettings.iOS.buildNumber = code.ToString();
            }

            PlayerBuilder.Export(isRelease);
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
    }

}
