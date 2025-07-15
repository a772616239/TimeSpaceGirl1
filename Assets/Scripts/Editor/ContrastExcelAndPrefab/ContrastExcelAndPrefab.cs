using GameEditor.Core.DataConfig;
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;
using System.Data;
using Excel;

public class ContrastExcelAndPrefab
{
    static string filePath = DataConfigSetting.execlDir + @"\GuideConfig.xlsx";

    static int type = 2;//行为类型为查找预制
    static int curIndex = 7;//行为类型初始行

    //所在列数
    static int BehaviorType = 12;//行为类型
    static int BehaviorArgs = 13;//行为参数

    [MenuItem("Tools/GuideConfig对比Prefab")]
    public static void StartContrast()
    {
        List<string[]> excelData = FindExcel();
        List<GameObject> allPrefab = FindPrefab();
        List<string> writeList = Contrast(excelData, allPrefab);
        WriteTxt(writeList);
    }

    /// <summary>
    /// 查找表
    /// </summary>
    /// <returns></returns>
    public static List<string[]> FindExcel()
    {
        DataRowCollection dataRowCollection = ReadExcel(filePath);
        List<string[]> excelData = new List<string[]>();
        for (int i = curIndex; i < dataRowCollection.Count; i++)
        {
            if (dataRowCollection[i][BehaviorType] != "")
            {
                if (dataRowCollection[i][BehaviorType].ToString() == type.ToString())
                {
                    //Debug.Log(dataRowCollection[i][BehaviorArgs]);
                    string[] strArray = dataRowCollection[i][BehaviorArgs].ToString().Split(new char[1] { '/' });
                    //Debug.Log(strArray[0]);
                    string address = "";
                    for (int value = 1; value < strArray.Length; value++)
                    {
                        address = address + strArray[value];
                        if (value != strArray.Length - 1)
                            address = address + "/";
                    }
                    //Debug.Log(address);
                    //Debug.Log("-----------------------");
                    string[] list = new string[3];
                    list[0] = dataRowCollection[i][1].ToString();
                    list[1] = strArray[0];
                    list[2] = address;
                    excelData.Add(list);
                }
            }
        }
        //for(int i = 0; i < excelData.Count; i++)
        //{
        //    Debug.Log(excelData[i][0] + "  :  " + excelData[i][1]);
        //}
        return excelData;
    }

    /// <summary>
    /// 查找预制
    /// </summary>
    /// <returns></returns>
    public static List<GameObject> FindPrefab()
    {
        List<GameObject> allPrefab = new List<GameObject>();

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

        return allPrefab;
    }

    /// <summary>
    /// 表与预制对比
    /// </summary>
    /// <param name="excelData"></param>
    /// <param name="allPrefab"></param>
    /// <returns></returns>
    public static List<string> Contrast(List<string[]> excelData, List<GameObject> allPrefab)
    {
        List<string> writeList = new List<string>();
        writeList.Add("ID        预制名       位置");
        for (int excelIndex = 0; excelIndex < excelData.Count; excelIndex++)
        {
            for(int prefabIndex = 0; prefabIndex < allPrefab.Count; prefabIndex++)
            {
                if (allPrefab[prefabIndex].transform.name == excelData[excelIndex][1])
                {
                    //Debug.Log(excelData[excelIndex][2]);
                    Transform item = allPrefab[prefabIndex].transform.Find(excelData[excelIndex][2]);
                    if (item)
                    {
                        //Debug.Log(item.name);
                    }
                    else
                    {
                        writeList.Add(excelData[excelIndex][0] + "    " + excelData[excelIndex][1] + "    " + excelData[excelIndex][2]);
                    }
                }
            }
        }
        return writeList;
    }

    /// <summary>
    /// 写入Txt
    /// </summary>
    /// <param name="writeList"></param>
    public static void WriteTxt(List<string> writeList)
    {
        string txTPath = Application.dataPath + "\\引导表对比预制体.txt";
        string[] str = writeList.ToArray();
        // 判断文件是否存在，不存在则创建，否则清空重新写入
        if (!File.Exists(txTPath))
        {
            FileStream fs = new FileStream(txTPath, FileMode.Append);
            StreamWriter sw = new StreamWriter(fs);
            for (int v = 0; v < writeList.Count; v++)
            {
                sw.WriteLine(writeList[v]);
            }
            sw.Close();
        }
        else
        {
            File.WriteAllText(txTPath, string.Empty);
            File.WriteAllLines(txTPath, str);
        }
        Debug.Log("路径：" + txTPath);
    }

    //通过表的索引，返回一个DataRowCollection表数据对象
    private static DataRowCollection ReadExcel(string _path, int _sheetIndex = 0)
    {
        FileStream stream = File.Open(_path, FileMode.Open, FileAccess.Read, FileShare.Read);
        IExcelDataReader excelReader = ExcelReaderFactory.CreateOpenXmlReader(stream);
        DataSet result = excelReader.AsDataSet();
        return result.Tables[_sheetIndex].Rows;
    }

    //通过表的名字，返回一个DataRowCollection表数据对象
    private static DataRowCollection ReadExcel(string _path, string _sheetName)
    {
        FileStream stream = File.Open(_path, FileMode.Open, FileAccess.Read, FileShare.Read);
        IExcelDataReader excelReader = ExcelReaderFactory.CreateOpenXmlReader(stream);
        DataSet result = excelReader.AsDataSet();
        return result.Tables[_sheetName].Rows;
    }
}


