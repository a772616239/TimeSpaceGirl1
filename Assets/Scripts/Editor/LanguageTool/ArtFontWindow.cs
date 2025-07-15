using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using System.Linq;
using GameEditor.Core;
using GameEditor.GameEditor.PlayerBuilder;
using GameLogic;
using System.Diagnostics;
using ResUpdate;
using System.Threading;
using System;

namespace GameEditor.FrameTool
{
    enum LanguageType {
        ZH,
        EN,
        XX
    };

    public class ArtFontWindow : EditorWindow
    {

        string m_ImportRootPath = Environment.CurrentDirectory + "\\Assets\\ManagedResources";

        string m_ArtFontPath;
        static string[] m_Files;
        static LanguageType m_Language = LanguageType.EN;
        static bool m_ChooseAll;
        static bool[] m_Choose;
        static string m_Bench;
        Dictionary<LanguageType, Dictionary<string, string>> m_Config;
        Dictionary<LanguageType, List<string>> m_ArtFontLists;
        Dictionary<string, string> m_ImportArt;
        Dictionary<string, string> m_UnImportArt;

        private void OnEnable()
        {
            m_ArtFontPath = EditorPrefs.GetString("m_ArtFontPath");
            m_ArtFontLists = new Dictionary<LanguageType, List<string>>();
            m_ImportArt = new Dictionary<string, string>();
            m_UnImportArt = new Dictionary<string, string>();

            m_Config = new Dictionary<LanguageType, Dictionary<string, string>>();
            Dictionary<string, string> en = new Dictionary<string, string>();
            en.Add("path", "ArtFont_enLan");
            en.Add("endStr", "_en");
            en.Add("dicStr", "folder_en");
            en.Add("importDic", "ArtFont_en");
            m_Config.Add(LanguageType.EN, en);
            Dictionary<string, string> xx = new Dictionary<string, string>();
            xx.Add("path", "ArtFont_xxLan");
            xx.Add("endStr", "_xx");
            xx.Add("dicStr", "folder_xx");
            xx.Add("importDic", "ArtFont_xx");
            m_Config.Add(LanguageType.XX, xx);
        }

        // Add menu named "My Window" to the Window menu
        //[MenuItem("LanguageTool/ArtFont/导入资源工具")]
        static void Init()
        {

            // Get existing open window or if none, make a new one:
            ArtFontWindow window = (ArtFontWindow)EditorWindow.GetWindow(typeof(ArtFontWindow));
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
            minSize = new Vector2(600, 400);
            maxSize = new Vector2(600, 650);
        }


        /// <summary>
        /// 初始化游戏
        /// </summary>
        void InitGames()
        {
            LoadDic();
        }

        void OnGUI()
        {
            
            EditorGUILayout.BeginVertical();
            EditorGUILayout.Space();
            
            EditorGUILayout.LabelField("美术本地化路径文件夹：", GUILayout.Width(600f));
            GUILayout.BeginHorizontal();
            //GUILayout.Label("源文件路径：", GUILayout.ExpandWidth(false));
            this.m_ArtFontPath = GUILayout.TextField(m_ArtFontPath, GUILayout.Width(450f));
            if (GUILayout.Button("选择文件夹", GUILayout.ExpandWidth(false)))
            {
                this.m_ArtFontPath = EditorUtility.OpenFolderPanel("Resource path", m_ArtFontPath, Application.dataPath);
                EditorPrefs.SetString("m_ArtFontPath", m_ArtFontPath);
                LoadDic();
            }
            GUILayout.EndHorizontal();

            EditorGUILayout.LabelField("请选择语言：");
            GUILayout.BeginHorizontal();
            //for (int i = 0; i < m_Config.Count; i++)
            //{
                foreach(KeyValuePair<LanguageType, Dictionary<string, string>> config in m_Config)
                {
                    
                    if (EditorGUILayout.ToggleLeft(config.Value["path"], m_Language == config.Key))
                    {
                        if (m_Language != config.Key)
                        {
                            m_Language = config.Key;
                            LoadDic();
                        }
                    }
                }
            //}
            GUILayout.EndHorizontal();

            EditorGUILayout.LabelField("请选择文件夹：");
            if (m_Files != null && m_Files.Length != 0)
            {
                m_ChooseAll = EditorGUILayout.ToggleLeft("全部", m_ChooseAll);
                GUILayout.BeginHorizontal();
                for (int i = 0; i < m_Files.Length; i++)
                {
                    string fileName = Path.GetFileName(m_Files[i]);
                    m_Choose[i] = EditorGUILayout.ToggleLeft(fileName, m_Choose[i] && !m_ChooseAll);

                    if (i % 4 == 3)
                    {
                        GUILayout.EndHorizontal();
                        GUILayout.BeginHorizontal();
                    }
                }
                GUILayout.EndHorizontal();
            }
            else
            {
                EditorGUILayout.LabelField("     未找到文件夹");
            }


            if (GUILayout.Button("导入", GUILayout.Height(50)))
            {
                m_ImportArt.Clear();
                m_UnImportArt.Clear();
                m_ArtFontLists[LanguageType.ZH] = GetAllArtFont(LanguageType.ZH);
                if (m_ChooseAll)
                {
                    for (int i = 0; i < m_Files.Length; i++)
                    {
                        string dirPath = m_Files[i];
                        ImportDirectoryTex(dirPath);
                    }
                }
                else
                {

                    for (int i = 0; i < m_Choose.Length; i++)
                    {
                        if (m_Choose[i])
                        {
                            string dirPath = m_Files[i];
                            ImportDirectoryTex(dirPath);
                        }
                    }
                }
                
                // 刷新导入的资源
                AssetDatabase.Refresh();
                // 检测导入资源的尺寸是否符合要求
                CheckImportFileSize();
                //
                UnityEngine.Debug.LogWarning("导入成功的资源：" + m_ImportArt.Count);
                foreach (KeyValuePair<string, string> v in m_ImportArt)
                {
                    UnityEngine.Debug.Log(String.Format("{0}->{1}", v.Key, v.Value));
                }
                if(m_UnImportArt.Count > 0)
                {
                    UnityEngine.Debug.LogError("导入失败的资源："+ m_UnImportArt.Count);
                    foreach (KeyValuePair<string, string> v in m_UnImportArt)
                    {
                        UnityEngine.Debug.LogError(String.Format("{0}, 失败原因:{1}", v.Key, v.Value));
                    }
                }
            }


        }

        // 加载本地化路径文件夹数据
        private void LoadDic()
        {
            string path = m_ArtFontPath + "/" + m_Config[m_Language]["path"];
            if (!string.IsNullOrEmpty(path) && Directory.Exists(path))
            {
                string[] t_Files = Directory.GetDirectories(path, "*", SearchOption.TopDirectoryOnly);
                List<string> t_l_Files = t_Files.ToList();
                for (int i = 0; i < t_Files.Length; i++)
                {
                    string fileName = Path.GetFileName(t_Files[i]);
                    if (!fileName.StartsWith(m_Config[m_Language]["dicStr"]))
                    {
                        t_l_Files.Remove(t_Files[i]);
                    }
                }
                m_Files = t_l_Files.ToArray();
                m_Choose = new bool[m_Files.Length];
            }
        }

        // 按文件夹导入文件
        private void ImportDirectoryTex(string dirPath)
        {
            string[] t_Files = Directory.GetFiles(dirPath, "*", SearchOption.TopDirectoryOnly);
            for (int i = 0; i < t_Files.Length; i++)
            {
                EditorUtility.DisplayProgressBar(dirPath, string.Format("({0}/{1}):{2}", i, t_Files.Length, t_Files[i]), (float)i / t_Files.Length);
                ImportSingleTex(t_Files[i]);
            }
            EditorUtility.ClearProgressBar();
        }

        // 导入单个文件
        private void ImportSingleTex(string filePath)
        {

            UnityEngine.Debug.Log(string.Format("import file: {0}", filePath));
            if (File.Exists(filePath))
            {
                //CheckFileSize(filePath);
                string o_Name = Path.GetFileName(filePath);
                string fix_Name = CheckFileName(o_Name);
                if (!fix_Name.Equals(o_Name))
                {
                    UnityEngine.Debug.LogWarning(string.Format("file name fixed: {0}->{1}", o_Name, fix_Name));
                }
                string importPath = m_ImportRootPath + "/" + m_Config[m_Language]["importDic"] + "/" + fix_Name;
                if (HasChineseArtFont(fix_Name))
                {

                    if (File.Exists(importPath))
                    {
                        File.Delete(importPath);
                    }
                    if(File.Exists(Path.ChangeExtension(importPath, ".png"))){

                        File.Delete(Path.ChangeExtension(importPath, ".png"));
                    }
                    if (File.Exists(Path.ChangeExtension(importPath, ".jpg")))
                    {
                        File.Delete(Path.ChangeExtension(importPath, ".jpg"));
                    }
                    
                    File.Copy(filePath, importPath);
                    m_ImportArt.Add(filePath, importPath);
                }
                else
                {
                    m_UnImportArt.Add(filePath, "未找到对应的中文路径");
                }
            }
        }

        // 判断在中文资源种是否存在
        private bool HasChineseArtFont(string fileName)
        {

            foreach (string path in m_ArtFontLists[LanguageType.ZH])
            {
                string zhName = Path.GetFileNameWithoutExtension(path);
                zhName = zhName.Substring(0, zhName.Length-3);
                string trName = Path.GetFileNameWithoutExtension(fileName);
                trName = trName.Substring(0, trName.Length-3);
                if (zhName.Equals(trName))
                {
                    return true;
                }
            }
            return false;
        }

        private List<string> GetAllArtFont(LanguageType language)
        {
            string directoryName = "";
            if(language == LanguageType.ZH)
            {
                directoryName = "ArtFont";
            }
            //else if(language == LanguageType.EN)
            //{
            //    directoryName = "ArtFont_en";
            //}
            string dirPath = Environment.CurrentDirectory + "\\Assets\\ManagedResources";
            List<string> flist = new List<string>();
            List<string> dirs = new List<string>(Directory.GetDirectories(dirPath, directoryName, SearchOption.AllDirectories));
            for (int i = 0; i < dirs.Count; i++)
            {
                string[] files = Directory.GetFiles(dirs[i]);
                for (int j = 0; j < files.Length; j++)
                {
                    flist.Add(files[j]);
                }
            }
            return flist;
        }

        // 检测导入文件的大小是否符合要求
        private void CheckImportFileSize()
        {
            int i = 0;
            foreach(KeyValuePair<string, string> v in m_ImportArt)
            {
                i++;
                EditorUtility.DisplayProgressBar("修正导入资源的像素大小", string.Format("({0}/{1}):{2}", i, m_ImportArt.Count, v.Value), (float)i / m_ImportArt.Count);
                CheckFileSize(v.Value);
            }
            EditorUtility.ClearProgressBar();
            AssetDatabase.Refresh();
        }

        // 检测文件大小是否符合要求
        private void CheckFileSize(string filePath)
        {
            if (File.Exists(filePath))
            {
                filePath = filePath.Replace(Environment.CurrentDirectory+"\\", "");
                //> LJ_OptTools.TextureOptUtilities.RemoveBigTexPackageTag(filePath);
                LJ_OptTools.TextureOptUtilities.ExtendTexture(filePath);
            }
            else
            {
                UnityEngine.Debug.LogError("检测文件像素大小失败，未找到文件：" + filePath);
            }
        }

        // 文件名检测返回正确的
        private string CheckFileName(string fileNameExt)
        {
            if (fileNameExt.EndsWith(".png.png")|| fileNameExt.EndsWith(".jpg.jpg"))
            {
                fileNameExt = fileNameExt.Substring(0, fileNameExt.Length - 3);
            }
            string fileName = Path.GetFileNameWithoutExtension(fileNameExt);
            string ext = Path.GetExtension(fileNameExt);
            if (fileName.EndsWith("_zh") || fileName.EndsWith("_en"))
            {
                fileName = fileName.Substring(0, fileName.Length - 3);
            }

            return fileName + m_Config[m_Language]["endStr"] + ext;
        }

    }

}
