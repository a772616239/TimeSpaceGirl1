using GameCore;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Threading;
using UnityEditor;
using UnityEngine;

namespace GameEditor.Core.DataConfig
{

    public class ConfigExportWindow:EditorWindow
    {
        static string m_ExcelPath;
        static string m_Bench;
        static string[] m_Files;
        static bool[] m_Choose;
        static string shellPath;

        [MenuItem("Data Config/Export")]
        private static void ShowConfigWin()
        {
            m_ExcelPath = EditorPrefs.GetString("m_ExcelPath");
            m_Bench = EditorPrefs.GetString("m_Bench");

            LoadDic();

            var win = GetWindow<ConfigExportWindow>();
            win.titleContent = new GUIContent("Export");
            win.Show();
        }


        private static void LoadDic()
        {

            if (!string.IsNullOrEmpty(m_ExcelPath) && Directory.Exists(m_ExcelPath))
            {
                m_Files = Directory.GetDirectories(m_ExcelPath, "*", SearchOption.TopDirectoryOnly);
                m_Choose = new bool[m_Files.Length];

                for (int i = 0; i < m_Files.Length; i++)
                {
                    m_Choose[i] = m_Files[i] == m_Bench;
                }
            }
        }
        private static void SaveLocalConfig()
        {
            for (int i = 0; i < m_Files.Length; i++)
            {
                if (m_Choose[i])
                {
                    m_Bench = m_Files[i];
                    break;
                }
            }
            // 保存数据
            EditorPrefs.SetString("m_ExcelPath", m_ExcelPath);
            EditorPrefs.SetString("m_Bench", m_Bench);
        }



        public static void OpenDirectory(string path)
        {
            if (string.IsNullOrEmpty(path)) return;

            if (!Directory.Exists(path))
            {
                UnityEngine.Debug.LogError("No Directory: " + path);
                return;
            }

            //Application.dataPath 只能在主线程中获取
            int lastIndex = Application.dataPath.LastIndexOf("/");
            shellPath = Application.dataPath.Substring(0, lastIndex) + "/Shell/";

            // 新开线程防止锁死
            Thread newThread = new Thread(new ParameterizedThreadStart(CmdOpenDirectory));
            newThread.Start(path);
        }

        private static void CmdOpenDirectory(object obj)
        {
            Process p = new Process();
#if UNITY_EDITOR_WIN
            p.StartInfo.FileName = "cmd.exe";
            p.StartInfo.Arguments = "/c start " + obj.ToString();
#elif UNITY_EDITOR_OSX
	p.StartInfo.FileName = "bash";
	string shPath = shellPath + "openDir.sh";
	p.StartInfo.Arguments = shPath + " " + obj.ToString();
#endif
            //UnityEngine.Debug.Log(p.StartInfo.Arguments);
            p.StartInfo.UseShellExecute = false;
            p.StartInfo.RedirectStandardInput = true;
            p.StartInfo.RedirectStandardOutput = true;
            p.StartInfo.RedirectStandardError = true;
            p.StartInfo.CreateNoWindow = true;
            p.Start();

            p.WaitForExit();
            p.Close();
        }


        private void OnGUI()
        {

            EditorGUILayout.BeginVertical();
            EditorGUILayout.Space();
            EditorGUILayout.LabelField("数据表svn工程路径：");

            EditorGUILayout.BeginHorizontal();
            m_ExcelPath = EditorGUILayout.TextField("", m_ExcelPath);
            if (GUILayout.Button("重新加载", GUILayout.Width(60f)))
            {
                LoadDic();
            }
            if (GUILayout.Button("打开目录", GUILayout.Width(60f)))
            {
                OpenDirectory(m_ExcelPath);
            }
            EditorGUILayout.EndHorizontal();

            EditorGUILayout.Space();
            EditorGUILayout.LabelField("请选择分支：");
            if(m_Files != null && m_Files.Length != 0)
            {
                for (int i = 0; i < m_Files.Length; i++)
                {
                    m_Choose[i] = EditorGUILayout.ToggleLeft(m_Files[i], m_Choose[i]);
                }
            }
            else { 
                EditorGUILayout.LabelField("未找到分支");
            }
            EditorGUILayout.EndVertical();


            if (GUILayout.Button("一键导表", GUILayout.Height(40f)))
            {
                SaveLocalConfig();
                // 导表
                DataConfigWindow.excelALLConfig(false, m_Bench + "/base_data");
            }
            if (GUILayout.Button("快速导表", GUILayout.Height(40f)))
            {
                // 保存数据
                SaveLocalConfig();
                // 导表
                DataConfigWindow.excelALLConfig(true, m_Bench + "/base_data");
            }
            
        }
    }


    public class DataConfigWindow : EditorWindow
    {
        [MenuItem("Data Config/Window")]
        private static void ShowConfigWin()
        {
            var win = GetWindow<DataConfigWindow>();
            win.titleContent = new GUIContent("Data Config");
            win.Show();
        }

        //true表示正在使用,false没有使用
        private static bool IsFileInUse(string fileName)
        {
            bool inUse = true;
            FileStream fs = null;
            try
            {
                fs = new FileStream(fileName, FileMode.Open, FileAccess.Read, FileShare.None);        
                inUse = false;
            }
            catch { }
            finally
            {
                if (fs != null) fs.Close();
            }
            return inUse;
        }
 
        public static void excelALLConfig(bool isIncrement, string path)
        {
            if(path == "")
            {
                path = DataConfigSetting.execlDir;
            }

            if (!string.IsNullOrEmpty(path) && Directory.Exists(path))
            {
                string[] files = Directory.GetFiles(path, "*.*", SearchOption.AllDirectories);
                DataConfigSetting setting = new DataConfigSetting();

                object lockObj = new object();
                string FilePath = null;
                int count = 0;
                int total = 0;
                System.Diagnostics.Stopwatch time = new System.Diagnostics.Stopwatch();

                Dictionary<string, string> record = new Dictionary<string, string>();
                Dictionary<string, string> newRecord = new Dictionary<string, string>();
                for (int i = 0; i < DataConfigMD5Record.Instance.Keys.Length; i++)
                {
                    record[DataConfigMD5Record.Instance.Keys[i]] = DataConfigMD5Record.Instance.Values[i];
                }

                time.Start();
                EditorUtility.DisplayProgressBar("Loading", "正在导表：", 0f);

                EditorApplication.update = () =>
                {
                    if (count < total)
                    {
                        EditorUtility.DisplayProgressBar(string.Format("Loading({0}/{1})", count, total), "正在导表：" + FilePath, (float)count / total);
                    }
                    else
                    {
                        EditorApplication.update = null;

                        int i = 0;
                        DataConfigMD5Record.Instance.Keys = new string[newRecord.Count];
                        DataConfigMD5Record.Instance.Values = new string[newRecord.Count];

                        foreach (var kvp in newRecord)
                        {
                            DataConfigMD5Record.Instance.Keys[i] = kvp.Key;
                            DataConfigMD5Record.Instance.Values[i] = kvp.Value;
                            i++;
                        }

                        foreach (var kvp in record)
                        {
                            string luaName = Path.GetFileNameWithoutExtension(kvp.Key);
                            string luaPath = string.Format("{0}/{1}.lua", setting.clientOutputDir, luaName);
                            if (File.Exists(luaPath))
                            {
                                UnityEngine.Debug.LogError("有表被移除！正在清理Lua文件：" + luaName);
                                File.Delete(luaPath);
                            }
                        }
                        EditorUtility.SetDirty(DataConfigMD5Record.Instance);
                        AssetDatabase.SaveAssets();

                        EditorUtility.ClearProgressBar();
                        AssetDatabase.Refresh();

                        time.Stop();
                        UnityEngine.Debug.LogError("耗时：" + time.ElapsedMilliseconds);

                        EditorUtil.ShowSureDialog("配置表数据导入完毕!");
                    }
                };

                for (int i = 0; i < files.Length; i++)
                {
                    var item = files[i];
                    if (item.Contains("~"))
                    {
                        continue;
                    }
                    ThreadPool.QueueUserWorkItem(q =>
                    {
                        if (IsFileInUse(item))
                        {
                            UnityEngine.Debug.LogError("该表正在编辑，无法导出！：" + item);
                            lock (lockObj)
                            {
                                if (record.ContainsKey(item))
                                {
                                    newRecord[item] = record[item];
                                    record.Remove(item);
                                }
                                count++;
                            }
                            return;
                        }

                        string crc = FileToCRC32.GetFileCRC32(item);
                        bool isChanged = !record.ContainsKey(item) || record[item] != crc;          
                        if (!isIncrement || (isIncrement && isChanged))
                        {
                            lock (lockObj)
                            {
                                FilePath = item;
                            }
                            exportSheet(setting, item, isIncrement);
                        }
                        lock (lockObj)
                        {
                            newRecord[item] = crc;
                            if (record.ContainsKey(item))
                            {
                                record.Remove(item);
                            }
                            count++;
                        }
                    });
                    total++;
                }
            }
        }

        [MenuItem("Data Config/一键导表")]
        public static void ExcelALLConfig()
        {
            excelALLConfig(false, DataConfigSetting.execlDir);
        }

        [MenuItem("Data Config/变化导表")]
        public static void ExcelChangeConfig()
        {
            excelALLConfig(true, DataConfigSetting.execlDir);
        }

        private static void exportSheet(DataConfigSetting setting, string path, bool isIncrement)
        {
            string fileExt = Path.GetExtension(path).ToLower();
            if (fileExt == ".xlsx" || fileExt == ".xls")
            {
                DataSheet sheet = DataHelper.GetSheet(path);

                bool isServer = true;
                foreach (DataField df in sheet.fields)
                {
                    if (df.exportType == DataFieldExportType.Client || df.exportType == DataFieldExportType.All)
                    {
                        isServer = false;
                        break;
                    }
                }

                if (!isServer)
                {
                    try
                    {
                        if (DataToOptimizeLuaExporter.CheckIsExport(sheet))
                        {
                            if (isIncrement)
                            {
                                UnityEngine.Debug.Log("该表有改动！正在导表：" + sheet.name);
                            }
                            new DataToOptimizeLuaExporter(sheet, setting).Export();
                        }
                        else
                        {
                            UnityEngine.Debug.LogError("前端没有数据导出");
                        }
                    }
                    catch (System.Exception e)
                    {
                        UnityEngine.Debug.LogError("该表有问题：" + sheet.name);
                        UnityEngine.Debug.LogError(e);
                    }
                }
                else
                {
                    UnityEngine.Debug.Log("该表为纯后端表，无需导出！" + sheet.name);
                }
            }
        }

        public enum TabType
        {
            Setting = 0,
            Excel = 1,
           // Check = 2,
        }
        public string[] TabNames = new string[]
        {
            "Setting",
            "Excel",
           // "Check",
        };

        public DataConfigExcelTab excelTab = null;
        public DataConfigSettingTab settingTab = null;
        private TabType tabType = TabType.Setting;
        const float k_ToolbarPadding = 15;

        public List<DataExcelSetting> excels = null;
        public DataConfigSetting setting = null;
        public static DataConfigWindow window = null;
        void Awake()
        {
            window = this;

            setting = DataConfigSetting.InitSetting();
            settingTab = new DataConfigSettingTab();
            excelTab = new DataConfigExcelTab(this);
        }

        void OnDestroy()
        {
            window = null;
        }

        void OnGUI()
        {
            if(excels == null)
            {
                excels = new List<DataExcelSetting>();
                if (!string.IsNullOrEmpty(DataConfigSetting.execlDir) && Directory.Exists(DataConfigSetting.execlDir))
                {
                    string[] files = Directory.GetFiles(DataConfigSetting.execlDir, "*.*", SearchOption.AllDirectories);
                    EditorUtility.DisplayProgressBar("Loading", "loading excel", 0f);
                    for(int i =0;i<files.Length;i++)
                    {
                        EditorUtility.DisplayProgressBar("Loading", "loading excel:"+files[i], ((float)i)/files.Length);
                        string fileExt = Path.GetExtension(files[i]).ToLower();
                        if (fileExt == ".xlsx" || fileExt == ".xls")
                        {
                            DataExcelSetting eSetting = new DataExcelSetting(files[i]);
                            excels.Add(eSetting);
                        }
                    }
                    EditorUtility.ClearProgressBar();
                }
                excels.Sort((x, y) => { return x.excelPath.CompareTo(y.excelPath); });

                excelTab.InitExcelTreeView();
            }
            GUILayout.BeginHorizontal();
            {
                GUILayout.Space(k_ToolbarPadding);
                float toolbarWidth = position.width - k_ToolbarPadding * 4;
                tabType = (TabType)GUILayout.Toolbar((int)tabType, TabNames, "LargeButton", GUILayout.Width(toolbarWidth));
            }
            GUILayout.EndHorizontal();
            Rect contentRect = new Rect(2, 40, position.width-4, position.height - 60);
            if (tabType == TabType.Setting)
            {
                settingTab.OnGUI(contentRect);
            } else if (tabType == TabType.Excel)
            {
                excelTab.OnGUI(contentRect);
            }
        }

        public void OnSettingChanged()
        {
            DataConfigSetting.SaveSetting(setting);
            excels = null;
        }
    }
}
