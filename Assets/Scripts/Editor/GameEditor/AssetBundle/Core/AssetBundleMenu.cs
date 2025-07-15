using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;
using System.IO;
using GameEditor.Core;
namespace GameEditor.AssetBundle
{
    public static class AssetBundleMenu
    {
		[MenuItem("AssetBundle/ClearMarks", false, 1)]
        public static void ClearMarks()
        {
            AssetBundleBuilder.ClearMarks();
            AssetDatabase.Refresh();
            EditorUtil.ShowSureDialog("标记清理完毕!");
        }

        /// <summary>
        /// 整体打包IOS
        /// </summary>
        [MenuItem("AssetBundle/Build/IOS/None", false, 1)]
        public static void BuildIOS()
        {
            BuildAssetBundles(BuildTarget.iOS, AssetBundleConfig.NoneOptions);
        }

        /// <summary>
        /// 整体打包IOS
        /// </summary>
        [MenuItem("AssetBundle/Build/IOS/LZ4", false, 2)]
        public static void BuildIOSLZ4()
        {
            BuildAssetBundles(BuildTarget.iOS, AssetBundleConfig.LZ4Options);
        }

        /// <summary>
        /// 整体打包IOS
        /// </summary>
        [MenuItem("AssetBundle/Build/IOS/LZMA", false, 3)]
        public static void BuildIOSLZMA()
        {
            BuildAssetBundles(BuildTarget.iOS, AssetBundleConfig.LZMAOptions);
        }

        /// <summary>
        /// 整体打包Android,混合模式
        /// </summary>
        [MenuItem("AssetBundle/Build/IOS/Mix", false, 4)]
        public static void BuildIOSMix()
        {
            string exportPath = AssetBundleConfig.GetExportPath(BuildTarget.iOS);
            AssetBundleBuilder.BuildAssetBundleMix(exportPath,BuildTarget.iOS);
        }

        /// <summary>
        /// 整体打包Android
        /// </summary>
        [MenuItem("AssetBundle/Build/Android/None", false, 1)]
        public static void BuildAndroid()
        {
            BuildAssetBundles(BuildTarget.Android, AssetBundleConfig.NoneOptions);
        }

        /// <summary>
        /// 整体打包Android
        /// </summary>
        [MenuItem("AssetBundle/Build/Android/LZ4", false, 2)]
        public static void BuildAndroidLZ4()
        {
            BuildAssetBundles(BuildTarget.Android, AssetBundleConfig.LZ4Options);
        }

        /// <summary>
        /// 整体打包Android
        /// </summary>
        [MenuItem("AssetBundle/Build/Android/LZMA", false, 3)]
        public static void BuildAndroidLZMA()
        {
            BuildAssetBundles(BuildTarget.Android, AssetBundleConfig.LZMAOptions);
        }

        /// <summary>
        /// 整体打包Android,混合模式
        /// </summary>
        [MenuItem("AssetBundle/Build/Android/Mix", false,4)]
        public static void BuildAndroidMix()
        {
            string exportPath = AssetBundleConfig.GetExportPath(BuildTarget.Android);
            AssetBundleBuilder.BuildAssetBundleMix(exportPath,BuildTarget.Android);
        }

        /// <summary>
        /// 整体打包Windows64
        /// </summary>
        [MenuItem("AssetBundle/Build/Windows64/None", false, 1)]
        public static void BuildWindows64()
        {
            BuildAssetBundles(BuildTarget.StandaloneWindows64, AssetBundleConfig.NoneOptions);
        }

        /// <summary>
        /// 整体打包Windows64
        /// </summary>
        [MenuItem("AssetBundle/Build/Windows64/LZ4", false, 2)]
        public static void BuildWindows64LZ4()
        {
            BuildAssetBundles(BuildTarget.StandaloneWindows64, AssetBundleConfig.LZ4Options);
        }

        /// <summary>
        /// 整体打包Windows64
        /// </summary>
        [MenuItem("AssetBundle/Build/Windows64/LZMA", false, 3)]
        public static void BuildWindows64LZMA()
        {
            BuildAssetBundles(BuildTarget.StandaloneWindows64, AssetBundleConfig.LZMAOptions);
        }

        /// <summary>
        /// 整体打包Android,混合模式
        /// </summary>
        [MenuItem("AssetBundle/Build/Windows64/Mix", false, 4)]
        public static void BuildWindows64Mix()
        {
            string exportPath = AssetBundleConfig.GetExportPath(BuildTarget.StandaloneWindows64);
            AssetBundleBuilder.BuildAssetBundleMix(exportPath,BuildTarget.StandaloneWindows64);
        }

        /// <summary>
        /// 打包选中资源IOS
        /// </summary>
        [MenuItem("Assets/BuildAB/IOS/None", false, 1)]
        public static void BuildSelectIOS()
        {
            BuildSelectAssetBundles(AssetBundleConfig.NoneOptions, BuildTarget.iOS);
        }

        /// <summary>
        /// 打包选中资源IOS
        /// </summary>
        [MenuItem("Assets/BuildAB/IOS/LZ4", false, 2)]
        public static void BuildSelectIOSLZ4()
        {
            BuildSelectAssetBundles(AssetBundleConfig.LZ4Options, BuildTarget.iOS);
        }

        /// <summary>
        /// 打包选中资源IOS
        /// </summary>
        [MenuItem("Assets/BuildAB/IOS/LZMA", false, 3)]
        public static void BuildSelectIOSLZMA()
        {
            BuildSelectAssetBundles(AssetBundleConfig.LZMAOptions, BuildTarget.iOS);
        }

        /// <summary>
        /// 打包选中资源Android
        /// </summary>
        [MenuItem("Assets/BuildAB/Android/None", false, 1)]
        public static void BuildSelectAndroid()
        {
            BuildSelectAssetBundles(AssetBundleConfig.NoneOptions, BuildTarget.Android);
        }


        /// <summary>
        /// 打包选中资源Android
        /// </summary>
        [MenuItem("Assets/BuildAB/Android/LZ4", false, 2)]
        public static void BuildSelectAndroidLZ4()
        {
            BuildSelectAssetBundles(AssetBundleConfig.LZ4Options, BuildTarget.Android);
        }

        /// <summary>
        /// 打包选中资源Android
        /// </summary>
        [MenuItem("Assets/BuildAB/Android/LZMA", false, 3)]
        public static void BuildSelectAndroidLZMA()
        {
            BuildSelectAssetBundles(AssetBundleConfig.LZMAOptions, BuildTarget.Android);
        }

        /// <summary>
        /// 打包选中资源Windows64
        /// </summary>
        [MenuItem("Assets/BuildAB/Windows64/None", false, 1)]
        public static void BuildSelectWindows64()
        {
            BuildSelectAssetBundles(AssetBundleConfig.NoneOptions, BuildTarget.StandaloneWindows64);
        }

        /// <summary>
        /// 打包选中资源Windows64
        /// </summary>
        [MenuItem("Assets/BuildAB/Windows64/LZ4", false, 2)]
        public static void BuildSelectWindows64LZ4()
        {
            BuildSelectAssetBundles(AssetBundleConfig.LZ4Options, BuildTarget.StandaloneWindows64);
        }

        /// <summary>
        /// 打包选中资源Windows64
        /// </summary>
        [MenuItem("Assets/BuildAB/Windows64/LZMA", false, 3)]
        public static void BuildSelectWindows64LZMA()
        {
            BuildSelectAssetBundles(AssetBundleConfig.LZMAOptions, BuildTarget.StandaloneWindows64);
        }

        /// <summary>
        /// 整体打包AB
        /// </summary>
        /// <param name="buildTarget"></param>
        /// <param name="options"></param>
        public static void BuildAssetBundles(BuildTarget buildTarget, BuildAssetBundleOptions options)
        {
            string exportPath = AssetBundleConfig.GetExportPath(buildTarget);
            AssetBundleBuilder.BuildAssetBundles(exportPath, buildTarget, options);
            AssetBundleBuilder.ClearManifest(exportPath);
            AssetDatabase.Refresh();
            EditorUtil.OpenFolderAndSelectFile(exportPath);
        }

        /// <summary>
        /// 打包指定资源
        /// </summary>
        /// <param name="buildOptions"></param>
        /// <param name="buildTarget"></param>
        public static void BuildSelectAssetBundles(BuildAssetBundleOptions buildOptions,BuildTarget buildTarget) {
            string[] paths = EditorUtil.GetSelectAssetPaths();
            string exportPath = AssetBundleConfig.GetExportPath(buildTarget) + "/Select";
            AssetBundleBuilder.BuildSelectAssetBundles(paths,exportPath, buildOptions, buildTarget);
            AssetBundleBuilder.ClearManifest(exportPath);
            AssetDatabase.Refresh();
            EditorUtil.OpenFolderAndSelectFile(exportPath);
        }

      



    }
}
