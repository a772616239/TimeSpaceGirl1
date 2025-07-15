using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using Object = UnityEngine.Object;
using GameEditor.Core;

namespace GameEditor.AssetBundle
{
    /// <summary>
    /// AssetBundle编辑器配置
    /// </summary>
    public static class AssetBundleConfig
    {
        /// <summary>
        /// 获取导出路径
        /// </summary>
        /// <returns>The export path.</returns>
        /// <param name="target">Target.</param>
        public static string GetExportPath(BuildTarget target)
        {
            string floder = "Other";
            switch (target)
            {
                case BuildTarget.Android:
                    floder = "Android";
                    break;
                case BuildTarget.iOS:
                    floder = "IOS";
                    break;
                case BuildTarget.StandaloneWindows:
                    floder = "Windows";
                    break;
                case BuildTarget.StandaloneWindows64:
                    floder = "Windows";
                    break;
            }
            return Application.dataPath + "/../BuildABs/" + floder;
        }


        /// <summary>
        /// 不压缩资源
        /// </summary>
        public static BuildAssetBundleOptions NoneOptions
        {
            get
            {
                return BuildAssetBundleOptions.DeterministicAssetBundle | BuildAssetBundleOptions.UncompressedAssetBundle;
            }
        }

        /// <summary>
        /// 块压缩
        /// </summary>
        public static BuildAssetBundleOptions LZ4Options
        {
            get
            {
                return BuildAssetBundleOptions.DeterministicAssetBundle | BuildAssetBundleOptions.ChunkBasedCompression;
            }
        }

        /// <summary>
        /// 默认LZMA压缩
        /// </summary>
        public static BuildAssetBundleOptions LZMAOptions
        {
            get
            {
                return BuildAssetBundleOptions.DeterministicAssetBundle;
            }
        }
    }

    public enum CompressType
    {
        //不压缩
        NoCompress,
        //LZ4
        LZ4,
        //LZMA
        LZMA
    }
    /// <summary>
    /// AB文件创建器
    /// </summary>
	public static class AssetBundleBuilder
    {
        /// <summary>
        /// 清空AB文件的标记
        /// </summary>
        public static void ClearMarks()
        {
            string[] names = AssetDatabase.GetAllAssetBundleNames();
            if (names.Length < 1)
                return;
            //int startIndex = 0;
            Debug.Log("清理标记中...");
            for (int i = 0; i < names.Length; i++)
            {
                string name = names[i];
                //EditorUtility.DisplayProgressBar("清理标记中", name, (float)(startIndex + 1) / (float)names.Length);
                AssetDatabase.RemoveAssetBundleName(name, true);
                //startIndex++;
                //if (startIndex >= names.Length)
                //{
                //    EditorUtility.ClearProgressBar();
                //    EditorApplication.update = null;
                //    startIndex = 0;
                //    break;
                //}
            }
            Debug.LogError("清理完毕...");
        }

        /// <summary>
        /// 开始打包
        /// </summary>
        /// <param name="buildTarget"></param>
        public static void BuildAssetBundles(string exportPath, BuildTarget buildTarget, BuildAssetBundleOptions options)
        {
            if (Directory.Exists(exportPath))
            {
                Directory.Delete(exportPath, true);
            }
            Directory.CreateDirectory(exportPath);
            DateTime oldTime = DateTime.Now;
            BuildPipeline.BuildAssetBundles(exportPath, options, buildTarget);
            TimeSpan span = DateTime.Now.Subtract(oldTime);
            Debug.Log("打包完毕，本次打包耗时:" + span.TotalSeconds + "秒!");
        }

        /// <summary>
        /// 混合打包模式
        /// </summary>
        /// <param name="target"></param>
        public static void BuildAssetBundleMix(string exportPath, BuildTarget target)
        {
            BuildAssetBundleMix(exportPath,AssetBundleConfig.LZMAOptions, AssetBundleConfig.LZ4Options, CompressType.LZ4, target);
        }


        /// <summary>
        /// 混合打包模式
        /// </summary>
        /// <param name="mainOptions">主选项</param>
        /// <param name="subOptions">子选项</param>
        /// <param name="subType">子压缩类型</param>
        /// <param name="target">目标平台</param>
        static void BuildAssetBundleMix(string exportPath,BuildAssetBundleOptions mainOptions, BuildAssetBundleOptions subOptions, CompressType subType, BuildTarget target)
        {
            string tmpExportPath = exportPath + "tmp";
            //build一下全部 ，然后build一下LZ4
            BuildAssetBundles(exportPath, target, mainOptions);
            BuildAssetBundleWithType(tmpExportPath, subOptions, target, subType);
            string[] games = Directory.GetDirectories(exportPath);
            for (int i = 0; i < games.Length; i++)
            {
                CombineGame(Path.GetFileName(games[i]), exportPath, tmpExportPath, subType);
            }
            Directory.Delete(tmpExportPath, true);
        }

        /// <summary>
        /// 合并游戏文件夹
        /// </summary>
        /// <param name="game"></param>
        /// <param name="exportPath"></param>
        /// <param name="tmpExportPath"></param>
        /// <param name="subType"></param>
        static void CombineGame(string game, string exportPath, string tmpExportPath, CompressType subType)
        {
            string dstPath = exportPath + "/" + game + "/" + subType.ToString().ToLower();
            string scrPath = tmpExportPath + "/" + game + "/" + subType.ToString().ToLower();
            if(Directory.Exists(dstPath)) Directory.Delete(dstPath, true);
            if(Directory.Exists(scrPath)) Directory.Move(scrPath, dstPath);
        }

        /// <summary>
        /// 根据压缩类型打包
        /// </summary>
        /// <param name="exportPath"></param>
        /// <param name="options"></param>
        /// <param name="target"></param>
        /// <param name="type"></param>
        public static void BuildAssetBundleWithType(string exportPath, BuildAssetBundleOptions options, BuildTarget target, CompressType type)
        {
            string[] assetBundles = AssetDatabase.GetAllAssetBundleNames();
            string flag = type.ToString().ToLower();
            Dictionary<string, AssetBundleBuild> builds = new Dictionary<string, AssetBundleBuild>();
            foreach (var each in assetBundles)
            {
                if (!each.Contains(flag)) continue;
                if (builds.ContainsKey(each)) continue;
                builds.Add(each, AssetBundleBuilder.GetAssetBundleBuild(each));
                CollectABDepdences(each, builds);
            }
            BuildSelectAssetBundles(exportPath, builds, options, target);
        }


        /// <summary>
        /// 收集资源依赖
        /// </summary>
        /// <param name="abName"></param>
        /// <param name="builds"></param>
        static void CollectABDepdences(string abName, Dictionary<string, AssetBundleBuild> builds)
        {
            string[] depdences = AssetDatabase.GetAssetBundleDependencies(abName, true);
            foreach (var each in depdences)
            {
                if (builds.ContainsKey(each)) continue;
                builds.Add(each, GetAssetBundleBuild(each));
            }
        }

        /// <summary>
        /// 清理多余的Manifest
        /// </summary>
        public static void ClearManifest(string path)
        {
            string fileName = Path.GetFileName(path);
            string fullPath = Path.Combine(path, fileName);
            if (File.Exists(fullPath)) File.Delete(fullPath);
            
            //加密AB包资源
            //string[] files = Directory.GetFiles(path, "*.unity3d", SearchOption.AllDirectories);
            //foreach (var each in files)
            //{
            //    File.WriteAllBytes(each, GameCore.XXTEA.Encrypt(File.ReadAllBytes(each)));
            //}
            
            //清理Manifest
            string[] files2 = Directory.GetFiles(path, "*.manifest", SearchOption.AllDirectories);
            string dirName = Path.GetFileName(path);
            foreach (var each in files2)//.Where(s => (Path.GetFileNameWithoutExtension(s)) != dirName))
            {
                File.Delete(each);
            }
        }

        public static AssetBundleBuild GetAssetBundleBuild(string abName) {
            string[] str = abName.Split('.');
            AssetBundleBuild build = new AssetBundleBuild
            {
                assetBundleName = str[0],
                assetBundleVariant = str[1],
                assetNames = AssetDatabase.GetAssetPathsFromAssetBundle(abName)
            };
            return build;
        }


        /// <summary>
        /// 打包指定资源
        /// </summary>
        /// <param name="obj"></param>
        /// <param name="bundleName">包名</param>
        /// <param name="exportPath">输出路径</param>
        /// <param name="buildTarget">输出目标</param>
        public static void BuildAssetBundle(Object obj, string bundleName, string exportPath, BuildAssetBundleOptions options, BuildTarget buildTarget)
        {
            AssetBundleBuild build = new AssetBundleBuild();
            build.assetBundleName = bundleName;
            build.assetBundleVariant = "unity3d";
            build.assetNames = new string[] { AssetDatabase.GetAssetPath(obj) };
            BuildPipeline.BuildAssetBundles(exportPath, new AssetBundleBuild[] { build }, options, buildTarget);
        }




        /// <summary>
        /// 打包指定路径的资源
        /// </summary>
        /// <param name="paths">需要打包的路径</param>
        /// <param name="exportPath">AB包输出路径</param>
        /// <param name="options">打包选项</param>
        /// <param name="buildTarget">打包目标</param>
        public static void BuildSelectAssetBundles(string[] paths,string exportPath,BuildAssetBundleOptions options, BuildTarget buildTarget)
        {
            Dictionary<string, AssetBundleBuild> abBuilds = new Dictionary<string, AssetBundleBuild>();
            for (int i = 0; i < paths.Length; i++)
            {
                string path = paths[i];
                string fullPath = EditorUtil.GetFullPath(path);
                //如果是一个目录
                if (Directory.Exists(fullPath))
                {
                    BuildFloderAssetBundleMap(path, abBuilds);
                }
                //如果是一个资源
                else
                {
                    BuildAssetAssetBundleMap(path, abBuilds);
                }
            }
            BuildSelectAssetBundles(exportPath, abBuilds, options, buildTarget);
        }

        /// <summary>
        /// 打包选中资源
        /// </summary>
        /// <param name="abNames"></param>
        /// <param name="buildTarget"></param>
        public static void BuildSelectAssetBundles(string exportPath, Dictionary<string, AssetBundleBuild> buildMap, BuildAssetBundleOptions options, BuildTarget buildTarget)
        {
            Directory.CreateDirectory(exportPath);
            DateTime oldTime = DateTime.Now;
            AssetBundleBuild[] builds = new AssetBundleBuild[buildMap.Count];
            buildMap.Values.CopyTo(builds, 0);
            Debug.Log("BuildSelectAssetBundles:"+exportPath+"--buildMap:"+buildMap.Count);
            for (int i = 0; i < builds.Length; i++)
            {
                Debug.Log("BuildSelectAssetBundles:"+builds[i].assetBundleName);
            }
            //
            // if (builds.Length==0)
            // {
            //     return;
            // }
            // List<AssetBundleBuild> builds1 = new List<AssetBundleBuild>();
            // builds1.Add(builds[0]);
            var manifest = BuildPipeline.BuildAssetBundles(exportPath, builds.ToArray(), options, buildTarget);
            var exportPathTarget = exportPath+ "/"+FrameTool.FrameTool.CombinePack+ "/";
            Debug.Log("create:"+exportPath);
            Directory.CreateDirectory(exportPathTarget);
            if (manifest != null)
            {
                // 加密 文件前加入128个空字符
                foreach (var name in manifest.GetAllAssetBundles())
                {
                    var uniqueSalt = Encoding.UTF8.GetBytes(name);
                    string oldPath = Path.Combine(exportPath,name);
                    byte[] oldData = File.ReadAllBytes(oldPath);
                    int len = (int)GameLogic.AppConst.EncyptBytesLength;
                    int newOldLen = len + oldData.Length;//定死了,128个空byte
                    var newData = new byte[newOldLen];
                    for (int tb = 0; tb < oldData.Length; tb++)
                    {
                        newData[len + tb] = oldData[tb];
                    }
                    string pn = Path.Combine(exportPathTarget, name.Replace("/","|"));
                    Debug.Log("newPath:"+pn);
                    FileStream fs = File.OpenWrite(pn);//打开写入进去
                    fs.Write(newData, 0, newOldLen);
                    fs.Close();
                }
            }

            TimeSpan span = DateTime.Now.Subtract(oldTime);
            Debug.Log("打包完毕，本次打包耗时:" + span.TotalSeconds + "秒!");
        }

        /// <summary>
        /// 是否标记过了
        /// </summary>
        /// <param name="ai"></param>
        /// <returns></returns>
		public static bool IsMarked(AssetImporter ai)
        {
            return ai != null && !string.IsNullOrEmpty(ai.assetBundleName) && !string.IsNullOrEmpty(ai.assetBundleVariant);
        }

        /// <summary>
        /// 打包选中的文件夹
        /// </summary>
        /// <param name="path"></param>
        /// <param name="abNames"></param>
        public static void BuildFloderAssetBundleMap(string path, Dictionary<string, AssetBundleBuild> buildMap)
        {
            AssetImporter ai = AssetImporter.GetAtPath(path);
            //如果文件夹被标记了
            if (IsMarked(ai) && !buildMap.ContainsKey(ai.assetBundleName))
            {
                AssetBundleBuild build = new AssetBundleBuild();
                build.assetBundleName = ai.assetBundleName;
                build.assetBundleVariant = ai.assetBundleVariant;
                build.assetNames = AssetDatabase.GetAssetPathsFromAssetBundle(ai.assetBundleName + "." + ai.assetBundleVariant);
                buildMap.Add(build.assetBundleName, build);
                string[] dependenceBundles =  AssetDatabase.GetAssetBundleDependencies(ai.assetBundleName+"."+ai.assetBundleVariant, true);
                for (int i = 0; i < dependenceBundles.Length; i++) {
                    string[] strs = dependenceBundles[i].Split('.');
                    if (!buildMap.ContainsKey(strs[0])) {
                        AssetBundleBuild tmpBuild = new AssetBundleBuild();
                        tmpBuild.assetBundleName = strs[0];
                        tmpBuild.assetBundleVariant = strs[1];
                        tmpBuild.assetNames = AssetDatabase.GetAssetPathsFromAssetBundle(dependenceBundles[i]);
                        buildMap.Add(tmpBuild.assetBundleName, tmpBuild);
                    }
                }
            }
            else
            {
                string fullPath = EditorUtil.GetFullPath(path);
                string[] files = Directory.GetFiles(fullPath);
                for (int i = 0; i < files.Length; i++)
                {

                    BuildAssetAssetBundleMap(EditorUtil.GetAssetsPath(files[i]), buildMap);
                }
                string[] directorys = Directory.GetDirectories(fullPath);
                for (int i = 0; i < directorys.Length; i++)
                {
                    BuildFloderAssetBundleMap(EditorUtil.GetAssetsPath(directorys[i]), buildMap);
                }
            }
        }

        /// <summary>
        /// 打包选中的资源
        /// </summary>
        /// <param name="assetPath">资源路径</param>
        /// <param name="abNames"></param>
        public static void BuildAssetAssetBundleMap(string assetPath, Dictionary<string, AssetBundleBuild> buildMap)
        {
            AssetImporter ai = AssetImporter.GetAtPath(assetPath);
            if (IsMarked(ai) && !buildMap.ContainsKey(ai.assetBundleName))
            {
                AssetBundleBuild build = new AssetBundleBuild();
                build.assetBundleName = ai.assetBundleName;
                build.assetBundleVariant = ai.assetBundleVariant;
                build.assetNames = AssetDatabase.GetAssetPathsFromAssetBundle(ai.assetBundleName + "." + ai.assetBundleVariant);
                buildMap.Add(build.assetBundleName, build);
                string[] dependenceBundles = AssetDatabase.GetAssetBundleDependencies(ai.assetBundleName + "." + ai.assetBundleVariant, true);
                for (int i = 0; i < dependenceBundles.Length; i++)
                {
                    string[] strs = dependenceBundles[i].Split('.');
                    if (!buildMap.ContainsKey(strs[0]))
                    {
                        AssetBundleBuild tmpBuild = new AssetBundleBuild();
                        tmpBuild.assetBundleName = strs[0];
                        tmpBuild.assetBundleVariant = strs[1];
                        tmpBuild.assetNames = AssetDatabase.GetAssetPathsFromAssetBundle(dependenceBundles[i]);
                        buildMap.Add(tmpBuild.assetBundleName, tmpBuild);
                    }
                }
            }
        }

        /// <summary>
        /// 标记一个文件夹一个资源包
        /// </summary>
        /// <param name="path">路径</param>
        /// <param name="prefix">AB包路径前缀</param>
        public static void MarkOneFloderOneBundle(string path,CompressType type = CompressType.LZMA)
        {
            string fullPath = EditorUtil.FixedWindowsPath(Application.dataPath + "/" + path);
            if (Directory.Exists(fullPath))
            {
                path = GetAssetBundleName(path, type);// type.ToString() + "/" + path;
                string assetPath = EditorUtil.GetAssetsPath(fullPath);
                AssetImporter ai = AssetImporter.GetAtPath(assetPath);
                ai.SetAssetBundleNameAndVariant(path, "unity3d");
                // MarkOneAssetOneBundleWithFullPath(fullPath, true, path);
            }
            else
            {
                Debug.LogError("标记文件夹出错,不存在的文件路径:" + fullPath);
            }
        }


        /// <summary>
        /// 标记指定路径下的所有子文件夹
        /// </summary>
        /// <param name="path">指定路径</param>
        /// <param name="prefix">AB包路径前缀</param>
        public static void MarkSubFloderOneBundle(string path,CompressType type = CompressType.LZMA)
        {
            string fullPath = EditorUtil.FixedWindowsPath(Application.dataPath + "/" + path);
            if (Directory.Exists(fullPath))
            {
                string[] paths = Directory.GetDirectories(fullPath);
                for (int i = 0; i < paths.Length; i++)
                {
                    string tmpPath = EditorUtil.FixedWindowsPath(paths[i]).Replace(Application.dataPath + "/", string.Empty);
                    MarkOneFloderOneBundle(tmpPath, type);
                }
            }
            else
            {
                Debug.LogError("标记子文件夹出错,不存在的文件路径:" + fullPath);
            }
        }

        /// <summary>
        /// 标记文件夹下的所有指定类型资源
        /// </summary>
        /// <param name="path">路径</param>
        /// <param name="types">类型白名单</param>
        /// <param name="includeChildDirectory">是否包含子文件夹</param>
        /// <param name="prefix">AB包路径前缀</param>
        public static void MarkOneAssetOneBundle(string path, bool includeChildDirectory = false, CompressType type = CompressType.LZMA)
        {
            string fullPath = EditorUtil.FixedWindowsPath(Application.dataPath + "/" + path);
            if (Directory.Exists(fullPath))
            {
                MarkOneAssetOneBundleWithFullPath(fullPath, includeChildDirectory, type);
            }
            else
            {
                Debug.LogError("标记文件夹下的资源出错,不存在的文件路径:" + fullPath);
            }
        }

        /// <summary>
        /// 标记一个文件夹下的资源
        /// </summary>
        /// <param name="path"></param>
        /// <param name="includeChildDirectory">是否包含子文件夹</param>
        public static void MarkOneAssetOneBundleWithFullPath(string path, bool includeChildDirectory, CompressType type = CompressType.LZMA)
        {
            string[] files = Directory.GetFiles(path);
            foreach (var file in files.Where(file => !file.Contains(".meta")))
            {
                string fullPath = EditorUtil.FixedWindowsPath(file);
                string assetPath = EditorUtil.GetAssetsPath(fullPath);
                string extension = Path.GetExtension(fullPath);
                AssetImporter ai = AssetImporter.GetAtPath(assetPath);
                if (ai == null)
                    continue;
                string assetBundlePath = assetPath.Replace("Assets/", "").Replace(extension, string.Empty);
                string assetBundleName = GetAssetBundleName(assetBundlePath, type);// type.ToString() + "/" + assetPath.Replace("Assets/", string.Empty).Replace(extension, string.Empty);
                ai.SetAssetBundleNameAndVariant(assetBundleName, "unity3d");
            }
            if (includeChildDirectory)
            {
                string[] infos = Directory.GetDirectories(path);
                for (int i = 0; i < infos.Length; i++)
                {
                    MarkOneAssetOneBundleWithFullPath(infos[i], includeChildDirectory, type);
                }
            }
        }

        /// <summary>
        /// 获取AB包的名字
        /// </summary>
        /// <param name="path"></param>
        /// <param name="compressType"></param>
        /// <returns></returns>
        public static string GetAssetBundleName(string path, CompressType compressType) {
            
            string assetBundleName = path.Replace(GameLogic.AppConst.GameResName + "/",string.Empty);
            assetBundleName = compressType.ToString() + "/" + assetBundleName;
            //Debug.LogError("path:" + path + " => abname:" + assetBundleName);
            return assetBundleName;
        }
    }
}
