
using UnityEngine;
using UnityEditor;
using System.IO;
using System.Text;

/// <summary>
/// 这个是讲lua文件转化为UTF-8格式的工具
/// </summary>
public class SetLuaToUTF8 : EditorWindow
{
   // 常量 //
    private const string EDITOR_VERSION = "v0.01"; // 这个编辑器的版本号 //
    // gui 相关 //
    private Vector2 m_scrollPos; // 记录 gui 界面的滚动 //
    private string m_luaPath = "ManagedResources/~Lua/";       // 文件路径
    private string m_fileSuffix = ".lua";       // 文件后缀
    /// <summary>
    /// 数据目录
    /// </summary>
    static string AppDataPath
    {
        get { return Application.dataPath.ToLower(); }
    }
    [MenuItem("Lua/File to UTF-8 Encoding")]
    static void Init()
    {
        Debug.Log("初始化转化lua文件为UTF-8格式");
        // Get existing open window or if none, make a new one:
        SetLuaToUTF8 window = (SetLuaToUTF8)EditorWindow.GetWindow(typeof(SetLuaToUTF8));
    }
    // UI 按钮显示 //
    void OnGUI()
    {
        m_scrollPos = GUILayout.BeginScrollView(m_scrollPos, GUILayout.Width(Screen.width), GUILayout.Height(Screen.height));
        GUILayout.BeginVertical(); // begin
        //-------------- 调试按钮 --------------//
        // 导出 UI 路径 //
        GUILayout.Label("===========================");
        GUILayout.BeginHorizontal();
        GUILayout.Label("要转化的路径: "); //
        m_luaPath = GUILayout.TextField(m_luaPath, 64);
        GUILayout.EndHorizontal();
        GUILayout.BeginHorizontal();
        GUILayout.Label("文件后缀: "); //
        m_fileSuffix = GUILayout.TextField(m_fileSuffix, 64);
        GUILayout.EndHorizontal();
        if (GUILayout.Button("\n 文件转utf-8格式 \n")) //
        {
            this.Conversion();
        }
        //-------------- end 调试按钮 --------------//
        GUILayout.Space(5);
        GUILayout.Label("工具版本号: " + EDITOR_VERSION); //
        GUILayout.EndVertical(); // end
        GUILayout.EndScrollView();
    }

    // 开始转化
    private void Conversion()
    {
        if (m_luaPath.Equals(string.Empty))
        {
            return;
        }
        if (!IsFolderExists(m_luaPath))
        {
            Debug.LogError("找不到文件夹路径！");
            return;
        }
        string path = AppDataPath + "/" + m_luaPath;
        string[] files = Directory.GetFiles(path, "*", SearchOption.AllDirectories);
        foreach (string file in files)
        {
           if (!file.EndsWith(m_fileSuffix)) continue;
            string strTempPath = file.Replace(@"\", "/");
            Debug.Log("文件路径：" + strTempPath);
            ConvertFileEncoding(strTempPath, null, new UTF8Encoding(false));
        }
        AssetDatabase.Refresh();
        Debug.Log("格式转换完成！");
    }
    /// 检测是否存在文件夹
    private static bool IsFolderExists(string folderPath)
    {
        if (folderPath.Equals(string.Empty))
        {
           return false;
        }
        return Directory.Exists(GetFullPath(folderPath));
    }
    /// 返回Application.dataPath下完整目录

    private static string GetFullPath(string srcName)
    {
        if (srcName.Equals(string.Empty))
        {
            return Application.dataPath;
        }
        if (srcName[0].Equals('/'))
        {
            srcName.Remove(0, 1);
        }
        return Application.dataPath + "/" + srcName;
    }
    /// <summary>
    /// 文件编码转换
    /// </summary>
    /// <param name="sourceFile">源文件</param>
    /// <param name="destFile">目标文件，如果为空，则覆盖源文件</param>
    /// <param name="targetEncoding">目标编码</param>
    private static void ConvertFileEncoding(string sourceFile, string destFile, Encoding targetEncoding)
    {
        destFile = string.IsNullOrEmpty(destFile) ? sourceFile : destFile;
        File.WriteAllText(destFile, File.ReadAllText(sourceFile, Encoding.UTF8), targetEncoding);
    }
}
