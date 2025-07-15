using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
using UnityEditor;
using System.IO;
using GameCore;
using GameLogic;
using GameEditor.Core;
namespace GameEditor
{
    public class UITools
    {
        [MenuItem("Assets/UITools/一键设置Font")]
        public static void OneKeyChangeFont()
        {
            Font font1 = AssetDatabase.LoadAssetAtPath<Font>(AppConst.GameResPath + "/Platform/Fonts/FZYH/FZYH.ttf");
            Font font2 = AssetDatabase.LoadAssetAtPath<Font>(AppConst.GameResPath + "/Platform/Fonts/FZZCH/FZZCH.ttf");
            List<GameObject> prefabs = EditorUtil.GetAssets<GameObject>(AppConst.GameResPath);
            GameObject gameObj = null;
            string path;
            for (int i = 0; i < prefabs.Count; i++)
            {
                gameObj = prefabs[i];
                path = AssetDatabase.GetAssetPath(gameObj);
                Text[] texts = gameObj.GetComponentsInChildren<Text>(true);
                bool fix = false;
                foreach (var each in texts)
                {
                    if (each.font == font1)
                    {
                        fix = true;
                        each.font = font2;
                        Debug.LogErrorFormat("字体修正,{0}====>{1}", path, each.transform.GetPathToParent(gameObj.transform));
                    }
                }
                if (fix)
                    EditorUtility.SetDirty(gameObj);
            }
            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
        }
    }

}
