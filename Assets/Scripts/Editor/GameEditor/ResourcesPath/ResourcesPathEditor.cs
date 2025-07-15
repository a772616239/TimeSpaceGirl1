using UnityEditor;
using UnityEngine;
using System.IO;
using System.Collections.Generic;
using ResMgr;
using GameCore;
using GameEditor.Core;
using GameLogic;
using System.Linq;

namespace GameEditor
{
	/// <summary>
	/// 资源路径编辑器类
	/// </summary>
	public static class ResourcesPathEditor
	{
		/// <summary>
		/// 
		/// </summary>
		private const string ResDirName = AppConst.GameResName + "/";
		/// <summary>
		/// 忽略列表
		/// </summary>
		private static StringArrayConfig ignoreConfig;

		/// <summary>
		/// 获取本地资源路径
		/// </summary>
		/// <param name="fullPath"></param>
		/// <returns></returns>
		private static string GetResLocalPath (string fullPath)
		{
			var strindex = fullPath.IndexOf (ResDirName);
			if (strindex == -1)
				return fullPath;
			var localDir = fullPath.Substring (strindex + ResDirName.Length) + "/";
			return localDir;
		}


        static List<string> dirPaths = new List<string>();
        static List<string> abNames = new List<string>();
        static Dictionary<string, ResPathInfo> resPaths = new Dictionary<string, ResPathInfo>();
        static Dictionary<string, AssetBundleInfo> dependences = new Dictionary<string, AssetBundleInfo>();
        /// <summary>
        /// 创建资源配置
        /// </summary>
        /// <param name="game"></param>
        public static void CreateResourcePathConfig (bool isRename)
		{
			dirPaths = new List<string> ();
			abNames = new List<string> ();
            resPaths = new Dictionary<string, ResPathInfo> ();
			dependences = new Dictionary<string, AssetBundleInfo> ();
            InitIgnoreList();

            System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();
            time.Start();

            ForEachDirectories (AppConst.GameResPath, isRename);

            time.Stop();
            Debug.Log(" 耗时：" + time.ElapsedMilliseconds*0.001 + "秒");

            //初始化配置类
            string assetPath = AppConst.GameResPath + "/ResConfigs/ResourcePathConfig.asset";
			string fullPath = EditorUtil.GetFullPath (assetPath);
			ResourcePathConfig configClass = null;
			if (!File.Exists (fullPath)) {
				FileUtils.CreateDirectory (fullPath);
				configClass = ScriptableObject.CreateInstance<ResourcePathConfig> ();
				configClass.Init (dirPaths, abNames, resPaths, dependences);
				AssetDatabase.CreateAsset (configClass, assetPath);
			} else {
				configClass = AssetDatabase.LoadAssetAtPath<ResourcePathConfig> (assetPath);
				configClass.Init (dirPaths, abNames, resPaths, dependences);
			}
			EditorUtility.SetDirty (configClass);
			EditorUtility.ClearProgressBar ();
			AssetDatabase.SaveAssets ();
			AssetDatabase.Refresh ();

		}

        static void GetDirectories(string path, List<string> list)
        {
            string[] directies = Directory.GetDirectories(path, "*", SearchOption.TopDirectoryOnly);
            foreach (var item in directies)
            {
                list.Add(item.Replace("\\", "/"));
                GetDirectories(item, list);
            }
        }

        /// <summary>
        /// 遍历目录
        /// </summary>
        /// <param name="path"></param>
        /// <param name="dirPaths"></param>
        /// <param name="abNames"></param>
        /// <param name="resPaths"></param>
        /// <param name="ai"></param>
        public static void ForEachDirectories (string path, bool isRename)
		{
            List<string> directories = new List<string>();     
            GetDirectories(path, directories);
            for (int i = 0; i < directories.Count; i++)
            {
                string str = directories[i];
                if(str.Length > 32)
                {
                    string a = str.Substring(0, 32);
                    if (a == "Assets/ManagedResources/LuaBytes")
                        continue;
                }
                

                EditorUtility.DisplayProgressBar(string.Format("正在刷新资源配置:({0}/{1})", i, directories.Count), "路径:"+ directories[i], (float)i / directories.Count);

                AssetImporter ai = AssetImporter.GetAtPath(EditorUtil.GetAssetsPath(directories[i]));
                if (IsMarked(ai))
                {
                    if (abNames.IndexOf(ai.assetBundleName) == -1)
                        abNames.Add(ai.assetBundleName);
					
                    if (!dependences.ContainsKey(ai.assetBundleName))
                    {
                        string assetBundleName = ai.assetBundleName + "." + ai.assetBundleVariant;
                        AssetBundleInfo info = new AssetBundleInfo(assetBundleName, AssetDatabase.GetAssetBundleDependencies(assetBundleName, false));
                        dependences.Add(ai.assetBundleName, info);
                        Debug.Log("add ab:"+ai.assetBundleName+"--dependency-"+info.assetBundleName);
                    }
                }
                else
                {
                    ai = null;
                }

                List<string> files = Directory.GetFiles(directories[i], "*", SearchOption.TopDirectoryOnly).Where(s => !s.EndsWith(".meta")).ToList();
                if (files.Count > 0)
                {
                    dirPaths.Add(EditorUtil.GetAssetsPath(directories[i]));
                    for (int j = 0; j < files.Count; j++)
                    {
                        ForEachFiles(files[j], ai, isRename);
                    }
                }
            }
        }

        /// <summary>
        /// 遍历检查资源循环依赖
        /// </summary>
        /// <param name="path"></param>
        /// <param name="dirPaths"></param>
        /// <param name="abNames"></param>
        /// <param name="resPaths"></param>
        /// <param name="ai"></param>
        public static void ForEachCheckDependences()
        {
            System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();
            time.Start();

            InitIgnoreList();
            List<string> directories = new List<string>();
            Dictionary<string, string> dependences = new Dictionary<string, string>();
            List<string> tmpList = new List<string>();

            GetDirectories(AppConst.GameResPath, directories);
            for (int i = 0; i < directories.Count; i++)
            {
                EditorUtility.DisplayProgressBar(string.Format("正在检查:({0}/{1})", i, directories.Count), "路径:" + directories[i], (float)i / directories.Count);

                AssetImporter ai = AssetImporter.GetAtPath(EditorUtil.GetAssetsPath(directories[i]));
                if (IsMarked(ai))
                {
                    if (!dependences.ContainsKey(ai.assetBundleName))
                    {
                        string assetBundleName = ai.assetBundleName + "." + ai.assetBundleVariant;
                        dependences.Add(ai.assetBundleName, assetBundleName);
                        string[] array = AssetDatabase.GetAssetBundleDependencies(assetBundleName, false);
                        if (array.Length > 0)
                        {
                            tmpList.Clear();
                            CheckDependences(assetBundleName, assetBundleName, string.Empty, tmpList);
                        }
                    }
                }
                else
                {
                    ai = null;
                }

                List<string> files = Directory.GetFiles(directories[i], "*", SearchOption.TopDirectoryOnly).Where(s => !s.EndsWith(".meta")).ToList();
                for (int j = 0; j < files.Count; j++)
                {
                    if (ai == null)
                    {
                        ai = AssetImporter.GetAtPath(EditorUtil.GetAssetsPath(files[j]));
                        if (IsMarked(ai))
                        {
                            if (!dependences.ContainsKey(ai.assetBundleName))
                            {
                                string assetBundleName = ai.assetBundleName + "." + ai.assetBundleVariant;
                                dependences.Add(ai.assetBundleName, assetBundleName);
                                string[] array = AssetDatabase.GetAssetBundleDependencies(assetBundleName, false);
                                if (array.Length > 0)
                                {
                                    tmpList.Clear();
                                    CheckDependences(assetBundleName, assetBundleName, string.Empty, tmpList);
                                }
                            }
                        }
                    }

                }
            }
            EditorUtility.ClearProgressBar();

            time.Stop();
            Debug.Log(" 耗时：" + time.ElapsedMilliseconds);
        }

        public static void CheckDependences(string root, string assetBundleName, string log,List<string> list)
        {
            if (list.Contains(assetBundleName)) return;
            string[] array = AssetDatabase.GetAssetBundleDependencies(assetBundleName, false);
            log+=assetBundleName+"=>";
            list.Add(assetBundleName);
            for (int i = 0; i < array.Length; i++) {
                if (array[i] == root)
                {
                    Debug.LogErrorFormat("Error=>存在资源循环依赖:{0}", log + array[i]);
                }
                else {
                    CheckDependences(root, array[i], log, list);
                }
            }
        }


		/// <summary>
		/// 遍历文件
		/// </summary>
		/// <param name="path"></param>
		/// <param name="dirPaths"></param>
		/// <param name="abNames"></param>
		/// <param name="resPaths"></param>
		/// <param name="ai"></param>
		public static void ForEachFiles (string path, AssetImporter ai, bool isRename)
		{
			if (IsIgnore (path))
				return;
			if (ai == null)
				ai = AssetImporter.GetAtPath (EditorUtil.GetAssetsPath(path));
			if (ai == null)
				return;
            if (IsMarked(ai))
            {
                if (abNames.IndexOf(ai.assetBundleName) == -1)
                    abNames.Add(ai.assetBundleName);

                if (!dependences.ContainsKey(ai.assetBundleName))
                {
                    string assetBundleName = ai.assetBundleName + "." + ai.assetBundleVariant;
                    AssetBundleInfo info = new AssetBundleInfo(assetBundleName, AssetDatabase.GetAssetBundleDependencies(assetBundleName, false));
                    dependences.Add(ai.assetBundleName, info);
                }
            }
            string fileName = Path.GetFileNameWithoutExtension (path);
			string extension = Path.GetExtension (path);

			if (resPaths.ContainsKey (fileName)) {
                var info = resPaths[fileName];
                string oldPath = string.Format("{0}/{1}{2}", dirPaths[info.resPathIndex], info.resName, info.extension);
                Debug.LogErrorFormat("资源名重复:{0}=>{1}", path, oldPath);

                if(isRename)
                {
                    string exName = Path.GetExtension(path).Replace(".", "");
                    if (!string.IsNullOrEmpty(exName)) //给资源文件加后缀名规避重复
                    {
                        if (exName != "prefab")//避免给prefab文件更名
                        {
                            string newPath = AssetDatabase.RenameAsset(path, Path.GetFileNameWithoutExtension(path) + "_" + exName);
                            Debug.LogErrorFormat("资源名已修正：{0} 请再次刷新文件路径", path);
                        }
                        else
                        {
                            string newPath = AssetDatabase.RenameAsset(oldPath, Path.GetFileNameWithoutExtension(oldPath)
                                + "_" + Path.GetExtension(oldPath).Replace(".", ""));
                            Debug.LogErrorFormat("资源名已修正：{0} 请再次刷新文件路径", oldPath);
                        }
                    }
                }
                
            }
            else
            { 
				resPaths.Add (fileName, new ResPathInfo (fileName, extension, dirPaths.Count - 1, abNames.Count - 1));
			}
		}

		/// <summary>
		/// 初始化忽略列表
		/// </summary>
		public static void InitIgnoreList ()
		{
			if (ignoreConfig != null)
				return;
			string path = "Assets/ManagedResources/EditorConfigs/IgnoreList.asset";
			StringArrayConfig tmpList = AssetDatabase.LoadAssetAtPath<StringArrayConfig> (path);
			if (tmpList == null) {
				ignoreConfig = ScriptableObject.CreateInstance<StringArrayConfig> ();
				string fullPath = EditorUtil.GetFullPath (path);
				fullPath = Path.GetDirectoryName (fullPath);
				if (!Directory.Exists (fullPath))
					Directory.CreateDirectory (fullPath);
				AssetDatabase.CreateAsset (ignoreConfig, path);
			} else {
				ignoreConfig = tmpList;
			}
		}

		/// <summary>
		/// 是否忽略掉
		/// </summary>
		/// <param name="path"></param>
		/// <returns></returns>
		private static bool IsIgnore (string path)
		{
			if (ignoreConfig == null)
				return false;
			if (ignoreConfig.Configs == null)
				return false;
			for (int i = 0; i < ignoreConfig.Configs.Length; i++)
            {
				if (path.Contains (ignoreConfig.Configs[i]))
                {
                    //Debug.LogError("被忽略掉的资源路径：" + path);
                    return true;
                }					
			}
			return false;
		}

		/// <summary>
		/// 是否标记过
		/// </summary>
		/// <param name="ai"></param>
		/// <returns></returns>
		public static bool IsMarked (AssetImporter ai)
		{
			return ai != null && !string.IsNullOrEmpty (ai.assetBundleName) && !string.IsNullOrEmpty (ai.assetBundleVariant);
		}
	}
}

