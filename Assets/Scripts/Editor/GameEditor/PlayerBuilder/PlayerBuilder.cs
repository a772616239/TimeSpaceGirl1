using System;
using UnityEngine;
using UnityEditor;
using System.IO;
using GameEditor.Core;
using SDK;
using System.Collections;
using System.Text;
using System.Text.RegularExpressions;

namespace GameEditor.GameEditor.PlayerBuilder
{
    public static class PlayerBuilder
    {
        /// <summary>
        /// 备份文件夹根目录
        /// </summary>
        static string backupRootPath = EditorUtil.GetProjectPath() + "ChannelBackup/";

        public static void Export(bool isRelease)
        {
            if (SDKChannelConfigManager.Instance.ChannelType != ChannelType.None.ToString()
                && !SDKChannelConfigManager.Instance.ChannelType.Contains(EditorUserBuildSettings.activeBuildTarget.ToString()))
            {
                Debug.LogError(string.Format("当前渠道：{0} 和出包平台：{1}不匹配！！！", SDKChannelConfigManager.Instance.ChannelType, EditorUserBuildSettings.activeBuildTarget));
                return;
            }

            ////根据渠道修改设置
            //if (SDKChannelConfigManager.Instance.ChannelType != ChannelType.None.ToString())
            //{
            //    string configPath = backupRootPath + SDKChannelConfigManager.Instance.ChannelType + "/Settings.txt";
            //    if (!File.Exists(configPath))
            //    {
            //        Debug.LogError(string.Format("未找到文件{0}！！！", configPath));
            //        return;
            //    }

            //    string settings = File.ReadAllText(configPath);
            //    string[] settingsArrary = settings.Split('|');
            //    PlayerSettings.applicationIdentifier = settingsArrary[0];
            //    PlayerSettings.productName = settingsArrary[1];
            //    Debug.LogError("渠道参数设置完成！！");
            //}

            switch (EditorUserBuildSettings.activeBuildTarget)
            {
                case BuildTarget.Android:
                    BuildApk();
                    break;
                case BuildTarget.iOS:
                    BuildXCode();
                    break;
                default:
                    Debug.LogError("请切换到Android/IOS平台");
                    break;
            }
        }


        static void BuildApk()
        {
            #region 设置导出文件名称

            string dateString = DateTime.Now.ToString("yyyy-MM-dd");
            string timeString = DateTime.Now.ToString("HHmmss");
            string localPath = string.Format("apks/{0}/{1}/", dateString, SDKChannelConfigManager.Instance.ChannelType);
            string locationPathName = string.Format("{0}{1}", localPath, timeString);

            #endregion

            #region 出包参数设置并出包

            BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions();
            buildPlayerOptions.scenes = EditorBuildSettingsScene.GetActiveSceneList(EditorBuildSettings.scenes);
            buildPlayerOptions.target = BuildTarget.Android;

            if (SDKChannelConfigManager.Instance.ChannelType != ChannelType.None.ToString())
            {
                EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;
                EditorUserBuildSettings.exportAsGoogleAndroidProject = true;
                buildPlayerOptions.locationPathName = locationPathName;
                //buildPlayerOptions.options = BuildOptions.AcceptExternalModificationsToPlayer;
            }
            else
            {
                EditorUserBuildSettings.androidBuildSystem = AndroidBuildSystem.Gradle;
                EditorUserBuildSettings.exportAsGoogleAndroidProject = false;
                buildPlayerOptions.locationPathName = locationPathName + ".apk";
                //buildPlayerOptions.options = BuildOptions.None;
            }

            BuildPipeline.BuildPlayer(buildPlayerOptions);
            string fullPath = EditorUtil.GetProjectPath() + buildPlayerOptions.locationPathName;

            #endregion

            #region 重命名AS工程并把需要的文件替换到AS工程中

            if (SDKChannelConfigManager.Instance.ChannelType != ChannelType.None.ToString())
            {
                string gradleProjectPath = fullPath + "/" + PlayerSettings.productName;

                //是否包含中文
                if (!Regex.IsMatch(PlayerSettings.productName, "^[a-zA-Z0-9]*$")) //(Regex.IsMatch(PlayerSettings.productName, "[\u4e00-\u9fbb]"))
                {
                    //AS工程重命名
                    string newGradleProjectPath = fullPath + "/" + timeString;
                    if (!string.IsNullOrEmpty(newGradleProjectPath))
                    {
                        if (Directory.Exists(gradleProjectPath))
                        {
                            if (Directory.Exists(newGradleProjectPath))
                            {
                                Directory.Delete(newGradleProjectPath);
                            }
                            Directory.Move(gradleProjectPath, newGradleProjectPath);
                            gradleProjectPath = newGradleProjectPath;
                            Debug.Log("GradleProject重命名完成！！");
                        }
                    }
                }


                //替换对应文件到AS工程
                string backupPath = backupRootPath + SDKChannelConfigManager.Instance.ChannelType + "/Gradle";
                //是否有备份文件
                if (Directory.Exists(backupPath))
                {
                    CopyAndReplaceDirectory(backupPath, gradleProjectPath);
                    string buildGradlePath = gradleProjectPath + "/build.gradle";
                    if (File.Exists(buildGradlePath))
                    {//如果有构造的话把版本号改一改

                        //CPU体系结构
                        string ndk_abiFilters = "";
                        string doNotStrips = "";
                        if (PlayerSettings.Android.targetArchitectures != AndroidArchitecture.None)
                        {
                            int tempCount = 1;
                            string targetArchitectures = PlayerSettings.Android.targetArchitectures.ToString();
                            string[] targetArchitecturesArray = targetArchitectures.Split(',');
                            ndk_abiFilters += "		abiFilters ";
                            for (int k = 0; k < targetArchitecturesArray.Length; k++)
                            {
                                string trim = targetArchitecturesArray[k].Trim();
                                if (trim == AndroidArchitecture.ARM64.ToString())
                                {
                                    ndk_abiFilters += "'arm64-v8a'";
                                    doNotStrips += "		doNotStrip '*/arm64-v8a/*.so'";
                                }
                                else if (trim == AndroidArchitecture.ARMv7.ToString())
                                {
                                    ndk_abiFilters += "'armeabi-v7a'";
                                    doNotStrips += "		doNotStrip '*/armeabi-v7a/*.so'";
                                }
                                else if (trim == AndroidArchitecture.X86.ToString())
                                {
                                    ndk_abiFilters += "'x86'";
                                    doNotStrips += "		doNotStrip '*/x86/*.so'";
                                }

                                if (tempCount < targetArchitecturesArray.Length)
                                {
                                    tempCount++;
                                    ndk_abiFilters += ",";
                                    doNotStrips += "\n";
                                }
                            }
                        }

                        string[] array = File.ReadAllLines(buildGradlePath, Encoding.Default);

                        for (int j = 0; j < array.Length; j++)
                        {
                            if (array[j].Contains("versionCode"))
                            {
                                array[j] = string.Format("		versionCode	{0}", PlayerSettings.Android.bundleVersionCode);
                            }
                            if (array[j].Contains("versionName"))
                            {
                                array[j] = string.Format("		versionName '{0}'", PlayerSettings.bundleVersion);
                            }
                            if (array[j].Contains("abiFilters"))
                            {
                                array[j] = ndk_abiFilters;
                            }
                            if (array[j].Contains("doNotStrip"))
                            {
                                array[j] = doNotStrips;
                            }
                        }
                        string str = string.Join("\r\n", array);
                        File.WriteAllText(buildGradlePath, str);
                    }
                    Debug.Log("拷贝文件到AS工程完成！！");
                }
            }

            #endregion

            Debug.Log("包出完啦!!" + DateTime.Now);
            EditorUtil.OpenFolderAndSelectFile(fullPath);
        }

        static void BuildXCode()
        {
            #region 设置导出文件名称

            string dateString = DateTime.Now.ToString("yyyy-MM-dd");
            string timeString = DateTime.Now.ToString("HHmmss");
            string localPath = string.Format("xcodes/{0}/{1}/", dateString, SDKChannelConfigManager.Instance.ChannelType);
            string locationPathName = string.Format("{0}{1}", localPath, timeString);

            #endregion

            BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions();
            buildPlayerOptions.scenes = EditorBuildSettingsScene.GetActiveSceneList(EditorBuildSettings.scenes);
            buildPlayerOptions.locationPathName = locationPathName;
            buildPlayerOptions.target = BuildTarget.iOS;
            buildPlayerOptions.options = BuildOptions.None;

            BuildPipeline.BuildPlayer(buildPlayerOptions);
            string fullPath = EditorUtil.GetProjectPath() + buildPlayerOptions.locationPathName;

            #region 替换文件到xode工程

            string backupPath = backupRootPath + SDKChannelConfigManager.Instance.ChannelType + "/XCode";
            //是否有备份文件
            if (Directory.Exists(backupPath))
            {
                CopyAndReplaceDirectory(backupPath, fullPath);
                Debug.Log("拷贝文件到XCode工程完成！！");
            }
#if UNITY_IOS
            string plistPath = Path.Combine(fullPath, "Info.plist");
            UnityEditor.iOS.Xcode.PlistDocument plist = new UnityEditor.iOS.Xcode.PlistDocument();
            string plistFileText = File.ReadAllText(plistPath);
            plist.ReadFromString(plistFileText);
            UnityEditor.iOS.Xcode.PlistElementDict rootDict = plist.root;

            //修改版本号
            rootDict.SetString("CFBundleShortVersionString", PlayerSettings.bundleVersion);
            rootDict.SetString("CFBundleVersion", PlayerSettings.iOS.buildNumber);

            // 保存修改
            File.WriteAllText(plistPath, plist.WriteToString());
#endif
            #endregion

            Debug.Log("包出完啦!!" + DateTime.Now);
            EditorUtil.OpenFolderAndSelectFile(fullPath);
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
