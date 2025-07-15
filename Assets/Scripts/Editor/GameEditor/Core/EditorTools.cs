using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
namespace GameEditor.Core
{
    public class EditorTools
    {
        [MenuItem("Tools/清理EditorPrefs")]
        public static void ClearAll()
        {
            EditorPrefs.DeleteAll();
            AssetDatabase.Refresh();
            Debug.Log("清理结束");
        }
        /// <summary>
        /// 查找并删除资源目录下空文件夹以及对应的mate文件
        /// </summary>
        [MenuItem("Tools/清理空文件夹")]
        public static void ClearEmptyFolder()
        {
            DirectoryInfo TheMainFolder = new DirectoryInfo(Application.dataPath);
            List<string> EmptyFolderName;
            bool isOver = false;
            while (!isOver)
            {
                EmptyFolderName = new List<string>();
                FindEmptyFolder(TheMainFolder, ref EmptyFolderName);
                if (EmptyFolderName.Count == 0)
                {
                    isOver = true;
                    break;
                }
                foreach (var item in EmptyFolderName)
                {
                    Debug.Log(item);
                }
            }
            AssetDatabase.Refresh();
            Debug.Log("清理结束");
        }

        [MenuItem("Tools/清除本地持久化数据")]
        public static void ClearPerrrrPath()
        {
            if (Directory.Exists(Application.persistentDataPath))
                Directory.Delete(Application.persistentDataPath, true);
            PlayerPrefs.DeleteAll();
            PlayerPrefs.Save();
            Debug.Log("清除本地持久化数据结束");
        }

        public static void FindEmptyFolder(DirectoryInfo _Folder, ref List<string> _PathList)
        {
            if (_Folder == null)
                return;
            DirectoryInfo[] dirInfos = _Folder.GetDirectories();
            FileInfo[] fileInfos = _Folder.GetFiles();
            if (dirInfos == null || dirInfos.Length == 0)
            {
                if (fileInfos == null || fileInfos.Length == 0)
                {
                    string FolderPath = _Folder.FullName;
                    string MatePath = _Folder.FullName.Substring(0, _Folder.FullName.Length - (_Folder.Name.Length + 1)) + "\\" + _Folder.Name + ".meta";
                    _PathList.Add(FolderPath);
                    _PathList.Add(MatePath);
                    Directory.Delete(FolderPath);
                    File.Delete(MatePath);
                }
            }
            else
            {
                foreach (var item in dirInfos)
                {
                    FindEmptyFolder(item, ref _PathList);
                }
            }
        }

        [MenuItem("Tools/Find Build Crash prefabs")]
        public static void FindCrashMissingPrefabs()
        {
            string[] allassetpaths = AssetDatabase.GetAllAssetPaths();
            EditorUtility.DisplayProgressBar("Bundle Crash Find", "Finding...", 0f);
            int len = allassetpaths.Length;
            int index = 0;
            foreach (var filePath in allassetpaths)
            {
                EditorUtility.DisplayProgressBar("Bundle Crash Find", filePath, (index + 0f) / (len + 0f));
                if (filePath.EndsWith(".prefab"))
                {
                    GameObject fileObj = PrefabUtility.LoadPrefabContents(filePath);
                    if (fileObj)
                    {
                        Component[] cps = fileObj.GetComponentsInChildren<Component>(true);
                        foreach (var cp in cps)
                        {
                            if (cp)
                            {
                                PrefabInstanceStatus _type = PrefabUtility.GetPrefabInstanceStatus(cp.gameObject);
                                if (_type == PrefabInstanceStatus.MissingAsset)
                                {
                                    //string nodePath = PsdToUguiEx.CopyLuJin(null)+"/"+ fileObj.name;
                                    Debug.LogError("Crash Bundle Missing Prefab:Path=" + filePath + " Name:" + fileObj.name + " ComponentName:" + cp);
                                }
                            }
                        }
                    }
                    PrefabUtility.UnloadPrefabContents(fileObj);
                }
                index++;
            }
            EditorUtility.ClearProgressBar();
        }


        [MenuItem("Tools/批量修改.lua文件的编码格式为Utf-8")]
        public static void ChangeLuasEncoding()
        {
            System.Text.UTF8Encoding utf8 = new System.Text.UTF8Encoding(false);

            string[] allassetpaths = AssetDatabase.GetAllAssetPaths();
            EditorUtility.DisplayProgressBar("资源查找并替换编码", "查找中...", 0f);
            for (int i = 0; i < allassetpaths.Length; i++)
            {
                if (allassetpaths[i].EndsWith(".lua"))
                {
                    string content = File.ReadAllText(allassetpaths[i]);
                    File.WriteAllText(allassetpaths[i], content, utf8);
                    EditorUtility.DisplayProgressBar("资源查找并替换编码", allassetpaths[i], i / (float)allassetpaths.Length);
                }
            }

            EditorUtility.ClearProgressBar();
            Debug.LogError("资源编码替换完成！！！");
            AssetDatabase.Refresh();
        }
    }
}
