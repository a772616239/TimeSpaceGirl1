using System;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEngine;

namespace GameEditor.Core.DataConfig
{
    /// <summary>
    /// 临时批处理入口：只导挂机奖励相关的三张表，同时输出客户端 Lua 与服务端 txt。
    /// 与 DataConfig 面板 Excel 页签的 Export 按钮行为一致，但不弹对话框、同步执行。
    /// 因为 batchmode 下 Debug.Log 抓不到，这里额外写一份明细日志到 Logs/batch_export_detail.log。
    /// </summary>
    public static class BatchExportRewardTables
    {
        static readonly string[] Tables = { "MainLevelConfig", "RewardGroup", "RewardItemConfig" };

        static string logPath = "Logs/batch_export_detail.log";

        static void L(string msg)
        {
            try
            {
                File.AppendAllText(logPath, msg + Environment.NewLine, Encoding.UTF8);
            }
            catch { }
            Debug.Log("[BatchExport] " + msg);
        }

        public static void Run()
        {
            File.WriteAllText(logPath, "", Encoding.UTF8);

            var setting = new DataConfigSetting();
            L("excelDir=" + DataConfigSetting.execlDir);
            L("clientDir=" + setting.clientOutputDir);
            L("serverDir=" + setting.serverOutputDir);

            int ok = 0;
            foreach (var name in Tables)
            {
                string path = Path.Combine(DataConfigSetting.execlDir, name + ".xlsx");
                if (!File.Exists(path))
                {
                    L("MISSING " + path);
                    continue;
                }

                try
                {
                    DataSheet sheet = DataHelper.GetSheet(path);
                    if (sheet == null)
                    {
                        L(name + " -> GetSheet 返回 null");
                        continue;
                    }
                    sheet.name = name;
                    L(name + " -> fields=" + sheet.fields.Count + " lines=" + sheet.lines.Count);

                    if (DataToOptimizeLuaExporter.CheckIsExport(sheet))
                    {
                        new DataToOptimizeLuaExporter(sheet, setting).Export();
                        L(name + " -> Lua OK");
                    }
                    else
                    {
                        L(name + " -> 前端无字段，跳过 Lua");
                    }

                    DataToTxtExporter.Export(sheet, setting);
                    L(name + " -> Txt OK");
                    ok++;
                }
                catch (Exception e)
                {
                    L(name + " -> EXCEPTION " + e.GetType().Name + ": " + e.Message);
                    L(e.StackTrace);
                }
            }

            AssetDatabase.Refresh();
            L("DONE tables=" + ok);
        }
    }
}
