using System.IO;
using UnityEngine;
namespace GameEditor.Core.DataConfig
{
    public class DataToTxtExporter
    {
        public static void Export(DataSheet sheet,DataConfigSetting setting)
        {
            if (string.IsNullOrEmpty(setting.serverOutputDir))
                return;
            if(!Directory.Exists(setting.serverOutputDir))
            {
                Directory.CreateDirectory(setting.serverOutputDir);
            }
            if (sheet == null || sheet.fields.Count == 0)
                return;
            int count = 0;
            for (int i = 0; i < sheet.fields.Count; i++)
            {
                DataField dfInfo = sheet.fields[i];
                if (dfInfo.exportType == DataFieldExportType.None
                    || dfInfo.exportType == DataFieldExportType.Client
                    || dfInfo.exportType == DataFieldExportType.Unexport)
                {
                    continue;
                }
                count++;
            }
            if(count <= 0)
            {
                Debug.LogError("后端没有数据导出");
                return;
            }

            string filePath = string.Format("{0}/{1}.txt", setting.serverOutputDir, sheet.name);
            if(File.Exists(filePath))
            {
                File.Delete(filePath);
            }

            FileStream fs = new FileStream(filePath, FileMode.Create);
            StreamWriter sw = new StreamWriter(fs);

            // 🔴 2026-10-20 修：旧写法是「每个字段后面都跟一个 \t」再 WriteLine，
            // 于是**每一行都以 TAB 结尾**（等于多挂一个空列）。后果：任何一次导表，
            // 服务端仓里 288 个 txt 都会变成逐行「有差异」，真改动被整文件 diff 淹掉；
            // 按列数校验的解析器还会被这个空列多算一列。
            // 改成「字段之间」插分隔符，首尾不留 TAB。
            var cells = new System.Collections.Generic.List<string>();

            foreach(DataField df in sheet.fields)
            {
                if (df.exportType == DataFieldExportType.None
                    || df.exportType == DataFieldExportType.Client
                    || df.exportType == DataFieldExportType.Unexport)
                {
                    continue;
                }
                cells.Add(df.name);
            }
            sw.WriteLine(string.Join("\t", cells));

            cells.Clear();
            foreach (DataField df in sheet.fields)
            {
                if (df.exportType == DataFieldExportType.None
                    || df.exportType == DataFieldExportType.Client
                    || df.exportType == DataFieldExportType.Unexport)
                {
                    continue;
                }
                cells.Add(df.FieldTypeStr);
            }
            sw.WriteLine(string.Join("\t", cells));
            foreach (var line in sheet.lines)
            {
                cells.Clear();
                for(int i =0;i<sheet.fields.Count;i++)
                {
                    DataField field = sheet.fields[i];
                    if (field.exportType == DataFieldExportType.None
                        || field.exportType == DataFieldExportType.Client
                        || field.exportType == DataFieldExportType.Unexport)
                    {
                        continue;
                    }


                    var cell = line[i];

                    // 🔴 2026-10-22：int 列按类型归一化（截断 + int32 夹取）。
                    // xlsx 里常有 Excel 浮点噪声文本（740.0000000000006 / 499.99999999999994）
                    // 和越界值（9999999999），服务端 Integer.parseInt 会抛 NumberFormatException
                    // 并中断整张表加载。详见 DataHelper.GetServerValByType。
                    cells.Add(DataHelper.GetServerValByType(cell, field.defaultContent, field));
                    
                }
                sw.WriteLine(string.Join("\t", cells));
            }
            sw.Close();
            fs.Close();
        }
    }
}
