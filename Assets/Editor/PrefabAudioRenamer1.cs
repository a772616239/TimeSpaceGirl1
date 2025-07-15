using UnityEditor;
using UnityEngine;
using System.Collections.Generic;
using System.IO;
/// <summary>
/// 文件夹下改名
/// </summary>
public class ResRenamer1 : EditorWindow
{
    private string targetFolder = "Assets/";
    private bool includeSubfolders = true;

    [MenuItem("Tools/重命名工具/批量重命名资源")]
    public static void ShowWindow()
    {
        GetWindow<ResRenamer1>("重命名工具");
    }

    void OnGUI()
    {
        GUILayout.Label("重命名包含X1/x1的预制体和音效", EditorStyles.boldLabel);
        
        EditorGUILayout.Space();
        targetFolder = EditorGUILayout.TextField("目标目录:", targetFolder);
        includeSubfolders = EditorGUILayout.Toggle("包含子目录", includeSubfolders);
        
        EditorGUILayout.Space();
        if (GUILayout.Button("执行重命名", GUILayout.Height(40)))
        {
            RenameAssets();
        }
        
        EditorGUILayout.HelpBox(
            "将重命名包含 'X1' 或 'x1' 的预制体和音效文件\n" +
            "新名称格式: cn2-原文件名\n" +
            "已包含 'cn2-' 的文件会自动跳过",
            MessageType.Info);
    }

    void RenameAssets()
    {
        if (!AssetDatabase.IsValidFolder(targetFolder))
        {
            Debug.LogError($"无效目录: {targetFolder}");
            return;
        }

        // 搜索预制体和音效文件
        List<string> allGuids = new List<string>();
        allGuids.AddRange(AssetDatabase.FindAssets("t:Prefab", new[] { targetFolder }));
        allGuids.AddRange(AssetDatabase.FindAssets("t:AudioClip", new[] { targetFolder }));
        allGuids.AddRange(AssetDatabase.FindAssets("t:AnimationClip", new[] { targetFolder }));
        allGuids.AddRange(AssetDatabase.FindAssets("t:Material", new[] { targetFolder }));
        
        if (includeSubfolders)
        {
            string[] subFolders = Directory.GetDirectories(targetFolder, "*", SearchOption.AllDirectories);
            foreach (string folder in subFolders)
            {
                allGuids.AddRange(AssetDatabase.FindAssets("t:Prefab", new[] { folder }));
                allGuids.AddRange(AssetDatabase.FindAssets("t:AudioClip", new[] { folder }));
                allGuids.AddRange(AssetDatabase.FindAssets("t:AnimationClip", new[] { folder }));
                allGuids.AddRange(AssetDatabase.FindAssets("t:Material", new[] { folder }));
            }
        }

        int renamedCount = 0;
        int skippedCount = 0;
        int errorCount = 0;

        // 移除重复的GUID
        HashSet<string> uniqueGuids = new HashSet<string>(allGuids);

        foreach (string guid in uniqueGuids)
        {
            string path = AssetDatabase.GUIDToAssetPath(guid);
            string fileName = Path.GetFileNameWithoutExtension(path);
            string extension = Path.GetExtension(path);
            
            // 跳过已包含cn2-的文件
            if (fileName.StartsWith("cn2-", System.StringComparison.OrdinalIgnoreCase))
            {
                skippedCount++;
                continue;
            }
            
            // 检查是否包含X1/x1
            if (fileName.IndexOf("X1", System.StringComparison.OrdinalIgnoreCase) >= 0)
            {
                string newName = "cn2-" + fileName;
                
                // 执行重命名
                string error = AssetDatabase.RenameAsset(path, newName);
                
                if (string.IsNullOrEmpty(error))
                {
                    renamedCount++;
                    Debug.Log($"重命名成功: {fileName}{extension} → {newName}{extension}", AssetDatabase.LoadAssetAtPath<Object>(path));
                }
                else
                {
                    errorCount++;
                    Debug.LogError($"重命名失败 {fileName}: {error}");
                }
            }
        }

        AssetDatabase.Refresh();
        ShowNotification(new GUIContent($"完成! 成功: {renamedCount}, 跳过: {skippedCount}, 失败: {errorCount}"));
    }
}