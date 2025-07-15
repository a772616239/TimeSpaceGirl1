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

            foreach(DataField df in sheet.fields)
            {
                if (df.exportType == DataFieldExportType.None
                    || df.exportType == DataFieldExportType.Client
                    || df.exportType == DataFieldExportType.Unexport)
                {
                    continue;
                }
                sw.Write(df.name + "\t");
            }
            sw.WriteLine();

            foreach (DataField df in sheet.fields)
            {
                if (df.exportType == DataFieldExportType.None
                    || df.exportType == DataFieldExportType.Client
                    || df.exportType == DataFieldExportType.Unexport)
                {
                    continue;
                }
                sw.Write(df.FieldTypeStr + "\t");
            }
            sw.WriteLine();
            foreach (var line in sheet.lines)
            {
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
            
                    sw.Write(DataHelper.GetValByDefault(cell,field.defaultContent,field.fieldType) + "\t");
                    
                }
                sw.WriteLine();
            }
            sw.Close();
            fs.Close();
        }
    }
}
