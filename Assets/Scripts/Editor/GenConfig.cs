using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System;

public class GenConfig
{
    public static string SavePath = Application.dataPath + "/GenConfig/";
    public static string CheckOutputPath = Application.dataPath + "/GenConfig/";
    public static string CheckFilePath = Application.dataPath + "/LuaFramework/Resources/";

    static StringBuilder sb = new StringBuilder();
    static string bundleName_Identify = "bundle";
    static string tableName_Identify = "table";
    static string output_Identify = "out";
    static string type_Identify = "type";

    [MenuItem("Assets/Gen Lua Config", false, 10)]
    private static void GenSelectLuaFile()
    {
        //确保鼠标右键选择的是一个Prefab
        var files = Selection.GetFiltered<TextAsset>(SelectionMode.DeepAssets);
        if (files.Length <= 0)
            return;

        for (int i = 0; i < files.Length; i++)
        {
            string text = files[i].ToString();
            GenLuaConfig(text);
        }
    }

    static string[] GetValidLines(string content)
    {
        var lineContent = content.Split(new string[] { "\r\n" }, StringSplitOptions.RemoveEmptyEntries);
        if (lineContent.Length <= 0)
            return lineContent;

        List<string> lineList = new List<string>();
        for (int i = 0; i < lineContent.Length; i++)
        {
            var cells = lineContent[i].Split(new string[] { "," }, StringSplitOptions.RemoveEmptyEntries);
            if (cells.Length > 0)
            {
                lineList.Add(lineContent[i]);
            }
        }

        return lineList.ToArray();
    }

    static void GenLuaConfig(string content)
    {
        sb = new StringBuilder();

        var lineContent = GetValidLines(content);
        if (lineContent.Length <= 0)
            return;

        var bundleName = FindContentString(bundleName_Identify, lineContent);
        var tableName = FindContentString(tableName_Identify, lineContent);
        var outRowIndexs = FindOutPutRows(lineContent);

        var typeLineIndex = FindContentLineIndex(type_Identify, lineContent);
        var typeLineCells = lineContent[typeLineIndex].Split(new string[] { "," }, StringSplitOptions.None);
        var startIndex = typeLineIndex + 1;


        sb.AppendLine(tableName + " =");
        sb.AppendLine("{");
        sb.AppendLine("bundleName = " + " '" + bundleName + "', ");

        int intValue;
        for (int i = startIndex; i < lineContent.Length; i++)
        {
            var cells = lineContent[i].Split(new string[] { "," }, StringSplitOptions.None);
            for (int k = 0; k < outRowIndexs.Length; k++)
            {
                var index = outRowIndexs[k];
                Debug.LogWarning("LineIndex:   " + i + "     cellIndex:   " + index);
                if (!string.IsNullOrEmpty(cells[index]))
                {
                    if (k == 0)
                    {
                        if (int.TryParse(cells[index], out intValue))
                        {
                            sb.Append(" [" + cells[index] + "]");
                        }
                        else
                        {
                            sb.Append(cells[index]);
                        }
                        sb.Append(" = { ");
                    }
                    else
                    {
                        var typeName = typeLineCells[index];
                        sb.Append(typeName + " = ");
                        sb.Append(ProcessCell_Info(cells[index]));
                    }
                }

                if (k == outRowIndexs.Length - 1)
                {
                    sb.AppendLine(" },");
                }
            }
        }

        sb.AppendLine("}");

        if (!Directory.Exists(SavePath))
            Directory.CreateDirectory(SavePath);

        string filePath = SavePath + "Test.lua";
        if (File.Exists(filePath))
            File.Delete(filePath);

        File.WriteAllText(filePath, sb.ToString());
    }

    static string ProcessCell_Info(string content)
    {
        StringBuilder temp = new StringBuilder();
        var split = content.Split(new string[] { "|" }, StringSplitOptions.None);
        for (int i = 0; i < split.Length; i++)
        {
            if (i == 0)
            {
                temp.Append(" { '" + split[i] + "', ");
            }
            else
            {
                temp.Append("'" + split[i] + "', ");
            }

            if (i == split.Length - 1)
            {
                temp.Append("}, ");
            }
        }
        return temp.ToString();
    }

    static int FindContentLineIndex(string findContent, string[] lineContent)
    {
        for (int i = 0; i < lineContent.Length; i++)
        {
            var lineCells = lineContent[i].Split(new string[] { "," }, StringSplitOptions.RemoveEmptyEntries);
            for (int j = 0; j < lineCells.Length; j++)
            {
                if (lineCells[j].Equals(findContent))
                    return i;
            }
        }

        return -1;
    }

    static string FindContentString(string findContent, string[] lineContent)
    {
        for (int i = 0; i < lineContent.Length; i++)
        {
            var lineCells = lineContent[i].Split(new string[] { "," }, StringSplitOptions.RemoveEmptyEntries);
            for (int j = 0; j < lineCells.Length; j++)
            {
                if (lineCells[j].Equals(findContent))
                    return lineCells[j + 1];
            }
        }

        return string.Empty;
    }

    static int[] FindOutPutRows(string[] lineContent)
    {
        List<int> output = new List<int>();
        var index = FindContentLineIndex(output_Identify, lineContent);
        var cells = lineContent[index].Split(new string[] { "," }, StringSplitOptions.None);
        for (int i = 1; i < cells.Length; i++)
        {
            if (!string.IsNullOrEmpty(cells[i]))
            {
                output.Add(i);
            }
        }

        return output.ToArray();
    }

    [MenuItem("Assets/Check Lua Config", false, 11)]
    static void CheckConfigResources()
    {
        //确保鼠标右键选择的是一个Prefab
        var files = Selection.GetFiltered<TextAsset>(SelectionMode.DeepAssets);
        if (files.Length <= 0)
            return;

        if (!Directory.Exists(CheckOutputPath))
            Directory.CreateDirectory(CheckOutputPath);

        string filePath = CheckOutputPath + "Test.lua";
        if (File.Exists(filePath))
            File.Delete(filePath);

        for (int i = 0; i < files.Length; i++)
        {
            string text = files[i].ToString();
            CheckConfig(text);
        }
    }

    static void CheckConfig(string text)
    {
        sb = new StringBuilder();

        var lineContent = GetValidLines(text);
        if (lineContent.Length <= 0)
            return;

        var bundleName = FindContentString(bundleName_Identify, lineContent);
        var tableName = FindContentString(tableName_Identify, lineContent);
        var outRowIndexs = FindOutPutRows(lineContent);

        var typeLineIndex = FindContentLineIndex(type_Identify, lineContent);
        var typeLineCells = lineContent[typeLineIndex].Split(new string[] { "," }, StringSplitOptions.None);
        var startIndex = typeLineIndex + 1;


        sb.AppendLine(tableName + " =");
        sb.AppendLine("{");
        sb.AppendLine("bundleName = " + " '" + bundleName + "', ");

        for (int i = startIndex; i < lineContent.Length; i++)
        {
            var cells = lineContent[i].Split(new string[] { "," }, StringSplitOptions.None);
            for (int k = 0; k < outRowIndexs.Length; k++)
            {
                var index = outRowIndexs[k];
                Debug.LogWarning("LineIndex:   " + i + "     cellIndex:   " + index);
                if (!string.IsNullOrEmpty(cells[index]))
                {
                    if (k == 0)
                    {
                        sb.Append(" Header =" + cells[index]);
                    }
                    else
                    {
                        if (!CheckHasFile(CheckFilePath, cells[index]))
                        {
                            sb.Append( "   " + cells[index]);
                        }
                    }
                }

                if (k == outRowIndexs.Length - 1)
                {
                    sb.AppendLine(" ");
                }
            }
        }

        sb.AppendLine("}");

        string filePath = SavePath + "Test.lua";
        File.AppendAllText(filePath, sb.ToString());
    }

    static bool CheckHasFile(string path, string name)
    {
        string[] files = Directory.GetFiles(path);

        for (int i = 0; i < files.Length; i++)
        {
            if (files[i].Equals(name))
                return true;
        }

        string[] dirs = Directory.GetDirectories(path);
        for (int i = 0; i < dirs.Length; i++)
        {
             return CheckHasFile(dirs[i], name);
        }

        return false;
    }
}
