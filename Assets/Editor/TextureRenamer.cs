using UnityEditor;
using UnityEngine;
using System.Collections.Generic;
using System.IO;
using System.Linq;

public class TextureRenamer : EditorWindow
{
    private string targetFolder = "Assets/";
    // private string suffix = "-ver2";
    private string suffix0 = "cn2-";
    private bool previewMode = true;

    [MenuItem("Tools/Safe Texture Renamer")]
    public static void ShowWindow()
    {
        GetWindow<TextureRenamer>("Safe Texture Renamer");
    }

    void OnGUI()
    {
        GUILayout.Label("Safe Texture Renamer", EditorStyles.boldLabel);
        targetFolder = EditorGUILayout.TextField("Target Folder:", targetFolder);
        suffix0 = EditorGUILayout.TextField("Suffix:", suffix0);
        previewMode = EditorGUILayout.Toggle("Preview Mode (Dry Run)", previewMode);

        if (GUILayout.Button("Rename Textures"))
        {
            RenameTexturesInPrefabs();
        }
    }

    void RenameTexturesInPrefabs()
    {
        if (!AssetDatabase.IsValidFolder(targetFolder))
        {
            Debug.LogError("Invalid folder path!");
            return;
        }

        // 获取所有预制体
        string[] prefabGUIDs = AssetDatabase.FindAssets("t:Prefab", new[] { targetFolder });
        if (prefabGUIDs.Length == 0)
        {
            Debug.Log("No prefabs found in the specified folder.");
            return;
        }
        

        // 收集所有需要重命名的纹理
        var textureData = new Dictionary<string, TextureInfo>();
        var prefabPaths = new List<string>();

        foreach (string guid in prefabGUIDs)
        {
            string prefabPath = AssetDatabase.GUIDToAssetPath(guid);
            prefabPaths.Add(prefabPath);
            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(prefabPath);
            
            if (prefab != null)
            {
                CollectTexturesFromPrefab(prefab, textureData);
            }
        }

        if (textureData.Count == 0)
        {
            Debug.Log("No textures found in prefabs.");
            return;
        }

        // 过滤掉已经重命名的纹理
        var texturesToRename = textureData.Values
            .Where(info => !info.CurrentName.StartsWith(suffix0))
            .ToList();

        if (texturesToRename.Count == 0)
        {
            Debug.Log("All textures already renamed.");
            return;
        }

        // 执行重命名操作
        AssetDatabase.StartAssetEditing();
        int renamedCount = 0;
        
        foreach (var textureInfo in texturesToRename)
        {
            if (previewMode)
            {
                Debug.Log($"[PREVIEW] Would rename: {textureInfo.CurrentName} -> {textureInfo.NewName}");
                renamedCount++;
            }
            else
            {
                if (SafeRenameTexture(textureInfo))
                {
                    renamedCount++;
                }
            }
        }
        
        AssetDatabase.StopAssetEditing();
        
        if (!previewMode)
        {
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
        }

        if (previewMode)
        {
            Debug.Log($"[PREVIEW] Would rename {renamedCount} textures. Enable preview mode to apply changes.");
        }
        else
        {
            Debug.Log($"Successfully renamed {renamedCount}/{texturesToRename.Count} textures without breaking references.");
        }
    }

    void CollectTexturesFromPrefab(GameObject prefab, Dictionary<string, TextureInfo> textureData)
    {
        Component[] components = prefab.GetComponentsInChildren<Component>(true);
        
        foreach (Component comp in components)
        {
            if (comp is Renderer renderer)
            {
                ProcessMaterials(renderer.sharedMaterials, textureData);
            }
            else if (comp is UnityEngine.UI.Image uiImage && uiImage.sprite != null)
            {
                AddTextureData(uiImage.sprite.texture, textureData);
            }
            else if (comp is UnityEngine.UI.RawImage rawImage && rawImage.texture != null)
            {
                AddTextureData(rawImage.texture, textureData);
            }
        }
    }

    void ProcessMaterials(Material[] materials, Dictionary<string, TextureInfo> textureData)
    {
        foreach (Material mat in materials)
        {
            if (mat == null) continue;
            
            string[] textureNames = mat.GetTexturePropertyNames();
            
            foreach (string texName in textureNames)
            {
                Texture tex = mat.GetTexture(texName);
                if (tex != null)
                {
                    AddTextureData(tex, textureData);
                }
            }
        }
    }

    void AddTextureData(Texture texture, Dictionary<string, TextureInfo> textureData)
    {
        if (texture == null) return;
        
        string path = AssetDatabase.GetAssetPath(texture);
        if (string.IsNullOrEmpty(path) || 
            AssetDatabase.GetMainAssetTypeAtPath(path) != typeof(Texture2D))
        {
            return;
        }

        string guid = AssetDatabase.AssetPathToGUID(path);
        
        if (!textureData.ContainsKey(guid))
        {
            string currentName = Path.GetFileNameWithoutExtension(path);
            textureData[guid] = new TextureInfo
            {
                GUID = guid,
                Path = path,
                CurrentName = currentName,
                NewName = $"{suffix0}{currentName}"
            };
        }
    }

    bool SafeRenameTexture(TextureInfo textureInfo)
    {
        // 双重检查是否已重命名
        if (textureInfo.CurrentName.StartsWith(suffix0))
        {
            Debug.LogWarning($"Skipped (already renamed): {textureInfo.CurrentName}");
            return false;
        }

        // 检查名称冲突
        string dir = Path.GetDirectoryName(textureInfo.Path);
        string newPath = Path.Combine(dir, textureInfo.NewName + Path.GetExtension(textureInfo.Path));
        
        if (File.Exists(newPath) || Directory.Exists(newPath))
        {
            Debug.LogError($"Skipped (conflict): {textureInfo.CurrentName} -> {textureInfo.NewName}. Target path already exists.");
            return false;
        }

        // 关键操作：保留GUID的重命名
        string error = AssetDatabase.RenameAsset(textureInfo.Path, textureInfo.NewName);
        
        if (string.IsNullOrEmpty(error))
        {
            Debug.Log($"Renamed: {textureInfo.CurrentName} -> {textureInfo.NewName} (GUID: {textureInfo.GUID})");
            return true;
        }
        else
        {
            Debug.LogError($"Failed to rename {textureInfo.CurrentName}: {error}");
            return false;
        }
    }

    private class TextureInfo
    {
        public string GUID;
        public string Path;
        public string CurrentName;
        public string NewName;
    }
}