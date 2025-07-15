using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace GameEditor.Core.DataConfig
{
    public class DataConfigSetting
    {
        private static string Setting_Key = "data_config_setting";

        public static string execlDir = System.Environment.CurrentDirectory + "/data_execl/base_data";
        public string clientOutputDir = Application.dataPath + "/ManagedResources/~Lua/Config/Data";
        public string serverOutputDir = "";

        public static DataConfigSetting InitSetting()
        {
            //DataConfigSetting setting = null;
            //string settingJson = EditorPrefs.GetString(Setting_Key);
            //if (!string.IsNullOrEmpty(settingJson))
            //{
            //    setting = JsonUtility.FromJson<DataConfigSetting>(settingJson);
            //}
            //else
            //{
            //    setting = new DataConfigSetting();
            //}

            // 删除了本地保存的功能，每次打开时自动设置为本工程的相对路径
            DataConfigSetting setting = new DataConfigSetting();
            return setting;
        }

        public static void SaveSetting(DataConfigSetting setting)
        {
            //if (setting != null)
            //EditorPrefs.SetString(Setting_Key, JsonUtility.ToJson(setting));
            //EditorPrefs.SetString(Setting_Key, null);
        }
    }

    public class DataExcelSetting
    {
        public string excelPath;
        public List<DataSheet> sheets = new List<DataSheet>();

        public DataExcelSetting(string filePath)
        {
            try
            {
                excelPath = filePath.Replace("\\", "/");
                DataSheet sheet = DataHelper.GetSheet(excelPath);
                sheet.name = Path.GetFileNameWithoutExtension(filePath);
                sheets.Add(sheet);

            }
            catch (System.Exception e)
            {
                Debug.LogError("DataConfigExcelTab::AddChildrenExcelSheet->path = " + filePath + " \nmessage = " + e.Message);
            }
        }
    }

}
