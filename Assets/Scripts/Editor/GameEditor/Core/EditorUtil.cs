using System.IO;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using System;
using Object = UnityEngine.Object;
namespace GameEditor.Core
{
    public static class EditorUtil
    {

        /// <summary>
        /// 创建资源
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="assetPath"></param>
        /// <param name="force"></param>
        /// <returns></returns>
        public static T CreateScriptObjectAsset<T>(string assetPath, bool force) where T : ScriptableObject
        {
            string fullPath = GetFullPath(assetPath);
            T t = null;
            if (File.Exists(fullPath))
            {
                if (force)
                {
                    AssetDatabase.DeleteAsset(assetPath);
                    t = ScriptableObject.CreateInstance<T>();
                    AssetDatabase.CreateAsset(t, assetPath);
                }
                else
                    t = AssetDatabase.LoadAssetAtPath<T>(assetPath);
            }
            else
            {
                t = ScriptableObject.CreateInstance<T>();
                AssetDatabase.CreateAsset(t, assetPath);
            }
            return t;
        }

        /// <summary>
        /// 获取相对于父级的路径
        /// </summary>
        /// <param name="parent"></param>
        /// <param name="child"></param>
        /// <returns></returns>
        public static string GetPathToParent(this Transform child, Transform parent)
        {
            if (child == parent)
            {
                return child.name;
            }
            string path = child.name;
            while (child != null && child.parent != null && child.parent != parent)
            {
                path = child.parent.name + "/" + path;
                child = child.parent;
            }
            path = parent.name + "/" + path;
            return path;
        }



        public static bool ShowSureDialog(string content)
        {
            return EditorUtility.DisplayDialog("提示", content, "确定");
        }

        /// <summary>
        /// 显示对话框
        /// </summary>
        /// <param name="content"></param>
        /// <returns></returns>
        public static bool ShowDialog(string content)
        {
            return ShowDialog("提示", content);
        }

        /// <summary>
        /// 显示对话框
        /// </summary>
        /// <param name="content"></param>
        /// <returns></returns>
        public static bool ShowDialog(string title, string content)
        {
            return EditorUtility.DisplayDialog(title, content, "确定", "取消");
        }

        /// <summary>
        /// 
        /// </summary>
        /// <param name="progress">Progress.</param>
        /// <param name="title">Title.</param>
        public static void ShowProgressBar(IShowProgressBar bar, Action action)
        {
            EditorApplication.update = () =>
            {
                EditorUtility.DisplayProgressBar(bar.GetTitle(), bar.GetContent(), bar.GetProgress());
                if (bar.IsFinish())
                {
                    EditorUtility.ClearProgressBar();
                    EditorApplication.update = null;
                    if (action != null)
                        action();
                }
            };
        }

        /// <summary>
        /// 修正windows路径
        /// </summary>
        /// <param name="path"></param>
        /// <returns></returns>
        public static string FixedWindowsPath(string path)
        {
            return path.Replace('\\', '/');
        }

        public static string FixedToWindowsPath(string path)
        {
            return path.Replace('/', '\\');
        }



        /// <summary>
        /// 打开文件系统并选中文件
        /// </summary>
        /// <param name="fullPath">完整的文件路径</param>
        public static void OpenFolderAndSelectFile(string fullPath)
        {
            if (Application.platform == RuntimePlatform.OSXEditor)
            {
                EditorUtility.RevealInFinder(fullPath);
            }
            else
            {
                fullPath = FixedToWindowsPath(fullPath);
                System.Diagnostics.ProcessStartInfo psi = new System.Diagnostics.ProcessStartInfo("Explorer.exe");
                psi.Arguments = "/e,/select," + fullPath;
                System.Diagnostics.Process.Start(psi);
            }

        }


        /// <summary>
        /// 获取资源路径（Asset/aa/bb）
        /// </summary>
        /// <param name="fullPath">系统路径</param>
        /// <returns>资源路径</returns>
        public static string GetAssetsPath(string fullPath)
        {
            fullPath = FixedWindowsPath(fullPath);
            int index = fullPath.LastIndexOf("Assets");
            return fullPath.Substring(index);
        }

        /// <summary>
        /// 获取工程目录
        /// </summary>
        /// <returns></returns>
        public static string GetProjectPath()
        {
            return Application.dataPath.Replace("Assets", string.Empty);
        }


        /// <summary>
        /// 获取系统全路径
        /// </summary>
        /// <param name="assetPath"></param>
        /// <returns></returns>
        public static string GetFullPath(string assetPath)
        {
            int index = Application.dataPath.LastIndexOf("Assets");
            string fullPath = Application.dataPath.Substring(0, index) + assetPath;
            return fullPath;
        }

        /// <summary>
        /// 获取目录下的所有资源,包括子目录
        /// </summary>
        /// <typeparam name="T"></typeparam>
        /// <param name="assetPath"></param>
        /// <returns></returns>
        public static List<T> GetAssets<T>(string assetPath) where T : Object
        {
            List<T> assets = new List<T>();
            string fullPath = GetFullPath(assetPath);
            if (Directory.Exists(fullPath))
            {
                DirectoryInfo directory = new DirectoryInfo(fullPath);
                ListObjects<T>(directory, (asset) =>
                {
                    assets.Add(asset);
                });
            }
            else
            {
                Debug.LogError("目录不存在!");
            }
            return assets;
        }

        /// <summary>
        /// 遍历文件夹下的资源,包括子文件夹
        /// </summary>
        /// <param name="info">Info.</param>
        /// <param name="action">Action.</param>
        public static void ListObjects<T>(string assetPath, Action<T> action) where T : Object
        {
            string fullPath = GetFullPath(assetPath);
            if (Directory.Exists(fullPath))
            {
                DirectoryInfo directory = new DirectoryInfo(fullPath);
                ListObjects(directory, action);
            }
            else
            {
                Debug.LogError("目录不存在!");
            }
        }

        /// <summary>
        /// 获取当前选中的资源路径
        /// </summary>
        /// <returns></returns>
        public static string[] GetSelectAssetPaths()
        {
            List<string> list = new List<string>();
            for (int i = 0; i < Selection.objects.Length; i++)
            {
                list.Add(AssetDatabase.GetAssetPath(Selection.objects[i]));
            }
            return list.ToArray();
        }

        public static void ListObjects<T>(FileSystemInfo info, Action<T> action) where T : Object
        {
            if (info is DirectoryInfo)
            {
                FileSystemInfo[] infos = (info as DirectoryInfo).GetFileSystemInfos();
                for (int i = 0; i < infos.Length; i++)
                {
                    ListObjects<T>(infos[i], action);
                }
            }
            else if (info is FileSystemInfo)
            {
                FileSystemInfo file = info as FileSystemInfo;
                string path = GetAssetsPath(file.FullName);
                T obj = AssetDatabase.LoadAssetAtPath<T>(path);
                if (obj != null && action != null)
                    action(obj);
            }
        }

        /// <summary>
        /// 获取路径下所有指定类型资源
        /// </summary>
        public static List<T> LoadAllAssetsAtPath<T>(string path) where T : UnityEngine.Object
        {
            var files = new List<string>();
            if (!path.Contains("."))
            {

                string p = path[path.Length - 1].ToString();
                if (p == "/")
                {
                    path = path.Substring(0, path.Length - 1);
                }
                if (!Directory.Exists(path))
                    //if(!AssetDatabase.IsValidFolder(path))
                    return new List<T>();
                var addFiles = GetFiles(path, "*", SearchOption.AllDirectories);
                files.AddRange(addFiles);
            }
            else
            {
                files.Add(path);
            }
            var assetList = new List<T>();
            foreach (var file in files)
            {
                var assets = AssetDatabase.LoadAllAssetsAtPath(file);
                foreach (var asset in assets)
                {
                    var t = asset as T;
                    if (t != null)
                        assetList.Add(t);
                }
            }
            return assetList;
        }

        /// <summary>
        /// 获取传入路径下所有指定查找文件夹
        /// </summary>
        public static List<string> GetDirectories(string path, string searchPattern, SearchOption searchOption)
        {
            var files = new List<string>();
            var tempfiles = Directory.GetDirectories(path, searchPattern, searchOption);
            for (int j = 0; j < tempfiles.Length; ++j)
            {
                files.Add(tempfiles[j].Replace("\\", "/"));
            }
            return files;
        }

        /// <summary>
        /// 获取传入路径下所有指定查找文件
        /// </summary>
        public static List<string> GetFiles(string path, string searchPattern, SearchOption searchOption)
        {
            var files = new List<string>();
            var tempfiles = Directory.GetFiles(path, searchPattern, searchOption);
            for (int j = 0; j < tempfiles.Length; ++j)
            {
                if (!tempfiles[j].Contains(".meta"))
                    files.Add(tempfiles[j].Replace("\\", "/"));
            }
            return files;
        }

        /// <summary>
        /// 获取传入路径下所有指定查找文件
        /// </summary>
        public static List<string> GetDirectories(string[] paths, string searchPattern, SearchOption searchOption)
        {
            var files = new List<string>();
            for (int i = 0; i < paths.Length; ++i)
            {
                var tempfiles = GetDirectories(paths[i], searchPattern, searchOption);
                files.AddRange(tempfiles);
            }
            return files;
        }

        /// <summary>
        /// 获取传入路径下所有指定查找文件
        /// </summary>
        public static List<string> GetFiles(string[] paths, string searchPattern, SearchOption searchOption)
        {
            var files = new List<string>();
            for (int i = 0; i < paths.Length; ++i)
            {
                var tempfiles = GetFiles(paths[i], searchPattern, searchOption);
                files.AddRange(tempfiles);
            }
            return files;
        }

    }

    public interface IShowProgressBar
    {
        float GetProgress();
        string GetTitle();
        string GetContent();
        bool IsFinish();
    }

    /// <summary>
    /// 压缩进度类
    /// </summary>
    public class CompressShowProgressBar : IShowProgressBar
    {
        int cur = 0;
        int max = 0;

        public CompressShowProgressBar(int max)
        {
            this.max = max;
        }

        /// <summary>
        /// 进度
        /// </summary>
        /// <returns>The progress.</returns>
        public float GetProgress()
        {
            if (max == 0)
                return 0;
            return 1f * cur / max;
        }

        /// <summary>
        /// 标题
        /// </summary>
        /// <returns>The title.</returns>
        public string GetTitle()
        {
            return "文件压缩";
        }

        /// <summary>
        /// 正文
        /// </summary>
        /// <returns>The content.</returns>
        public string GetContent()
        {
            return string.Format("压缩文件中,当前进度{0}/{1}", cur, max);
        }

        /// <summary>
        /// 是否完成
        /// </summary>
        /// <returns><c>true</c> if this instance is finish; otherwise, <c>false</c>.</returns>
        public bool IsFinish()
        {
            return cur == max;
        }


        public int Cur
        {
            get
            {
                return this.cur;
            }
            set
            {
                cur = value;
            }
        }

    }
}

