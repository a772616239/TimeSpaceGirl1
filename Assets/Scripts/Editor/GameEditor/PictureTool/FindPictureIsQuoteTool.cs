
using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;
using UnityEngine.UI;

/// <summary>
/// 查找图片引用
/// </summary>

namespace GameEditor.Core
{
    public class FindPictureIsQuoteTool
    {
        [MenuItem("Tools/N1图片相关/查找预制体无引用资源")]
        public static void StartFint()
        {
            //写入
            string txtPath = Application.dataPath + "\\N1无用图片.txt";
            string[] str = GetList().ToArray();
            // 判断文件是否存在，不存在则创建，否则清空重新写入
            if (!File.Exists(txtPath))
            {
                FileStream fs = new FileStream(txtPath, FileMode.Append);
                StreamWriter sw = new StreamWriter(fs);
                for (int i = 0; i < str.Length; i++)
                {
                    sw.WriteLine(str[i]);
                }
                sw.Close();
            }
            else
            {
                File.WriteAllText(txtPath, string.Empty);
                File.WriteAllLines(txtPath, str);
            }
            Debug.Log("路径：" + txtPath);
        }

        [MenuItem("Tools/N1图片相关/删除预制体无引用资源")]
        public static void DelectPicture()
        {
            string allPath = Application.dataPath + "\\ManagedResources\\Atlas";//无图片字路径
            DirectoryInfo folder = new DirectoryInfo(allPath);
            DirectoryInfo[] infos = folder.GetDirectories();

            List<string> str = GetList();

            //删除
            for (int i = 0; i < infos.Length; i++)
            {
                EditorUtility.DisplayProgressBar("删除中", "删除中:" + (float)i + "/" + infos.Length, (float)i / infos.Length);
                //每个文件夹路径
                string path = allPath + "\\" + infos[i].Name;
                if (Directory.Exists(path))
                {
                    DirectoryInfo direction = new DirectoryInfo(path);
                    FileInfo[] files = direction.GetFiles("*", SearchOption.AllDirectories);
                    for (int j = 0; j < files.Length; j++)
                    {
                        if (files[j].Name.EndsWith(".meta"))
                        {
                            continue;
                        }
                        if (files[j].Name.Substring(0, 2) == "N1" || files[j].Name.Substring(0, 2) == "n1")
                        {
                            for (int v = 1; v < str.Count; v++)
                            {
                                if (str[v] == files[j].Name.Substring(0, files[j].Name.Length - 4))
                                {
                                    File.Delete(path + "//" + files[j].Name);
                                }
                            }
                        }
                    }
                }
            }
            EditorUtility.ClearProgressBar();
        }

        public static List<string> GetList()
        {
            List<string> allPng = new List<string>();//所有图片列表
            List<GameObject> allPrefab = new List<GameObject>();//所有预制列表

            string allPath = Application.dataPath + "\\ManagedResources\\Atlas";//无图片字路径
            DirectoryInfo folder = new DirectoryInfo(allPath);
            DirectoryInfo[] infos = folder.GetDirectories();

            for (int i = 0; i < infos.Length; i++)
            {
                EditorUtility.DisplayProgressBar("获取图片", "获取图片中:" + (float)i + "/" + infos.Length, (float)i / infos.Length);
                //每个文件夹路径
                string path = allPath + "\\" + infos[i].Name;
                if (Directory.Exists(path))
                {
                    DirectoryInfo direction = new DirectoryInfo(path);
                    FileInfo[] files = direction.GetFiles("*", SearchOption.AllDirectories);
                    for (int j = 0; j < files.Length; j++)
                    {
                        if (files[j].Name.EndsWith(".meta"))
                        {
                            continue;
                        }
                        if (files[j].Name.Substring(0, 2) == "N1" || files[j].Name.Substring(0, 2) == "n1")
                        {
                            allPng.Add(files[j].Name.Substring(0, files[j].Name.Length - 4));
                        }
                    }
                }
            }
            EditorUtility.ClearProgressBar();

            //查找所有预制
            var resourcesPath = Application.dataPath;
            var absolutePaths = System.IO.Directory.GetFiles(resourcesPath, "*.prefab", System.IO.SearchOption.AllDirectories);
            for (int i = 0; i < absolutePaths.Length; i++)
            {
                EditorUtility.DisplayProgressBar("获取预制体", "获取预制体中:" + (float)i + "/" + absolutePaths.Length, (float)i / absolutePaths.Length);

                string path = "Assets" + absolutePaths[i].Remove(0, resourcesPath.Length);
                path = path.Replace("\\", "/");
                GameObject prefab = AssetDatabase.LoadAssetAtPath(path, typeof(GameObject)) as GameObject;
                if (prefab != null)
                {
                    allPrefab.Add(prefab);
                }
            }
            EditorUtility.ClearProgressBar();

            List<string> allQuoteStr = new List<string>();//所有引用图片资源列表
            //查找预制引用的图片资源
            for (int i = 0; i < allPrefab.Count; i++)
            {
                EditorUtility.DisplayProgressBar("查找中", "查找中:" + (float)i + "/" + allPrefab.Count, (float)i / allPrefab.Count);
                Image[] imgArr = allPrefab[i].GetComponentsInChildren<Image>();

                foreach (var item in imgArr)
                {
                    if (item.sprite)
                    {
                        string name = item.sprite.name;
                        if (name != null)
                        {
                            if (name.Substring(0, 2) == "N1" || name.Substring(0, 2) == "n1")
                            {
                                allQuoteStr.Add(name);
                            }
                        }
                    }
                }
            }
            EditorUtility.ClearProgressBar();

            List<string> str = new List<string>();
            for (int i = 0; i < allPng.Count; i++)
            {
                bool state = true;
                for (int j = 0; j < allQuoteStr.Count; j++)
                {
                    if (allPng[i] == allQuoteStr[j])
                    {
                        state = false;
                    }
                }
                if (state)
                {
                    str.Add(allPng[i]);
                }
            }

            return str;
        }
    }
}