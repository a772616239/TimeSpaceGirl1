using System;
using System.IO;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using GameEditor;
using GameEditor.Core;


public static class AtlasTool {

    [MenuItem("Assets/Atlas/FormatImageName")]
    public static void FomartImageName() {
        try
        {
            string path = AssetDatabase.GetAssetPath(Selection.activeObject);
            string atlasName = Path.GetFileName(path);
            atlasName = atlasName.Replace("Atlas", string.Empty);
            EditorUtil.ListObjects<Texture2D>(path, (tex2d) => {
                string tex2dPath = AssetDatabase.GetAssetPath(tex2d);
                string tex2dName = Path.GetFileName(tex2dPath);
                if(!tex2dName.StartsWith(atlasName)){
                    //int idx = tex2dName.IndexOf("_");         
                    //if (idx >= 0)
                    //{
                    //    tex2dName = atlasName + "_" + tex2dName.Substring(idx + 1);
                    //}
                    //else
                    {
                        tex2dName = atlasName + "_" + tex2dName;
                    }
                    string str = AssetDatabase.RenameAsset(tex2dPath, tex2dName);
                    if (!string.IsNullOrEmpty(str)) Debug.LogError(str);
                }
            });
            
        }
        catch (Exception e)
        {
            Debug.LogErrorFormat("FomartImageNameError:{0}", e.ToString());
        }
    }
}
