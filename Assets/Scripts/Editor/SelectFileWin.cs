/// <summary>
/// 当前文件夹中所有需要导入的spine文件列表
/// </summary>

using UnityEngine;
using UnityEditor;
using System.IO;
using System.Collections;
using System.Collections.Generic;

public class FileSelectVal
{
    public bool stateVal;
}

public class SelectFileWin : EditorWindow
{
    private Vector2 scrollViewPos = new Vector2(0,0);       // 列表的位置
    private Dictionary<string, FileSelectVal> fileSelectState = new Dictionary<string, FileSelectVal>();           // Dictionary<Spine名字，是否导入> 
    public Dictionary<string, FileSelectVal> FileSelectState { get { return this.fileSelectState; } }
    private Dictionary<string, List<string>> fileDict = new Dictionary<string, List<string>>();                    // Dictionary<Spine名字，List<相同Spine包含的文件>>
    public Dictionary<string, List<string>> FileDict { get { return this.fileDict; } }

    public List<string> spinePrefabPathList = new List<string>();

#region 设置界面数据 同名(不包含后缀名)的文件只留一个
    /// <summary>
    /// 设置界面数据
    /// </summary>
    public void SetSelectFileWinData(string _resources_folder_path)
    {
        fileSelectState.Clear();
        fileDict.Clear();
        if (Directory.Exists(_resources_folder_path))
        {            
            string[] spineFiles = Directory.GetFiles(_resources_folder_path);
            for (int i = 0; i < spineFiles.Length; i++)
            {
                FileInfo spineFilesInfo = new FileInfo(spineFiles[i]);
                string fileName = Path.GetFileNameWithoutExtension(spineFilesInfo.FullName);
                fileName = fileName.LastIndexOf(".") > 0 ? fileName.Substring(0, fileName.LastIndexOf(".")) : fileName;
                if (!this.fileSelectState.ContainsKey(fileName))
                {
                    FileSelectVal selectVal = new FileSelectVal();
                    selectVal.stateVal = false;
                    this.fileSelectState.Add(fileName, selectVal);
                    this.fileDict.Add(fileName, new List<string>() { spineFiles[i] });
                } else
                {                    
                    this.fileDict[fileName].Add(spineFiles[i]);
                }                
            }

            if (spineFiles.Length <= 0)
            {
                EditorUtility.DisplayDialog("提 示", "选定的源文件夹中没有文件！", "确 定");
            }
        }
        else {
            EditorWindow.GetWindow<SelectFileWin>().Close();
            EditorUtility.DisplayDialog("提 示","请选择正确的源文件夹路径！","确 定"); 
        }
    }
    #endregion

#region OnGUI
    private void OnGUI()
    {
        EditorGUILayout.BeginVertical();
        scrollViewPos = EditorGUILayout.BeginScrollView(scrollViewPos, false,false);
        IDictionaryEnumerator selectFolderDictEnum = this.fileSelectState.GetEnumerator();
        while (selectFolderDictEnum.MoveNext())
        {           
            GUILayout.Space(10);
            FileSelectVal val = (FileSelectVal)selectFolderDictEnum.Value;
            bool stateVal = GUILayout.Toggle(val.stateVal, selectFolderDictEnum.Key.ToString());
            val.stateVal = stateVal;
        }
        GUILayout.Space(10);
        GUILayout.BeginHorizontal();
        IDictionaryEnumerator allFolderDictEnum = this.fileSelectState.GetEnumerator();
        if (GUILayout.Button("全选"))
        {
            while (allFolderDictEnum.MoveNext())
            {
                FileSelectVal val = (FileSelectVal)allFolderDictEnum.Value;
                val.stateVal = true;
            }
        }
        GUILayout.Space(10);
        if (GUILayout.Button("取消全选"))
        {
            while (allFolderDictEnum.MoveNext())
            {
                FileSelectVal val = (FileSelectVal)allFolderDictEnum.Value;
                val.stateVal = false;
            }
        }
        GUILayout.EndHorizontal();
        EditorGUILayout.EndScrollView();
        EditorGUILayout.EndVertical();


        GUILayout.Space(20);
        if (GUILayout.Button("确 定"))
        {
            EditorWindow.GetWindow<SelectFileWin>().Close();
        }      
    }
#endregion
}
