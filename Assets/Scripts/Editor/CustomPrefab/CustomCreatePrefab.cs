using UnityEditor;
using UnityEngine;
/// <summary>
/// 创建自定义组件
/// @author Ganchong
/// </summary>
public class CustomCreatePrefab : MonoBehaviour {
	/// <summary>
	/// 自定义预设根目录
	/// </summary>
	static string CustomPrefabMainPath = "Assets/CustomPrefab/";

    /// <summary>
    /// 创建页签容器
    /// </summary>
    [MenuItem("GameObject/CustomCreate/GetAllPrePos #&t", false, 10)]
    static void CreateTapContent0001(MenuCommand menuCommand)
    {
        //CreateTemplate("TapContent.Prefab", menuCommand);
        GameObject go = menuCommand.context as GameObject;
        string allPosStr = "";
        foreach (Transform child in go.transform)
        {
            if (child.transform.localPosition.x < 0)
            {
                allPosStr = allPosStr + "'" + child.transform.localPosition.x + "#" + child.transform.localPosition.y + "\n";
            }
            else
            {
                allPosStr = allPosStr + child.transform.localPosition.x + "#" + child.transform.localPosition.y + "\n";
            }
        }
            Debug.Log(allPosStr);
    }


    /// <summary>
    /// 创建页签容器
    /// </summary>
    [MenuItem("GameObject/CustomCreate/TapContent #&t",false,10)]
    static void CreateTapContent(MenuCommand menuCommand)
    {
        CreateTemplate("TapContent.Prefab", menuCommand);
    }


    /// <summary>
    /// 创建按钮1
    /// </summary>
    [MenuItem("GameObject/CustomCreate/ButtonBlue", false, 10)]
    static void CreateButton01(MenuCommand menuCommand)
    {
        CreateTemplate("Button01.Prefab", menuCommand);
    }

    /// <summary>
    /// 创建按钮2
    /// </summary>
    [MenuItem("GameObject/CustomCreate/ButtonYellow", false, 10)]
    static void CreateButton02(MenuCommand menuCommand)
    {
        CreateTemplate("Button02.Prefab", menuCommand);
    }

    /// <summary>
    /// 创建按钮3
    /// </summary>
    [MenuItem("GameObject/CustomCreate/ButtonGreen", false, 10)]
    static void CreateButton03(MenuCommand menuCommand)
    {
        CreateTemplate("Button03.Prefab", menuCommand);
    }

    /// <summary>
    /// 创建按钮4
    /// </summary>
    [MenuItem("GameObject/CustomCreate/ButtonOrange", false, 10)]
    static void CreateButton04(MenuCommand menuCommand)
    {
        CreateTemplate("Button04.Prefab", menuCommand);
    }

    /// <summary>
    /// 创建按钮10
    /// </summary>
    [MenuItem("GameObject/CustomCreate/Button10", false, 10)]
    static void CreateButton10(MenuCommand menuCommand)
    {
        CreateTemplate("Button10.Prefab", menuCommand);
    }

    /// <summary>
    /// 创建按钮11
    /// </summary>
    [MenuItem("GameObject/CustomCreate/Button11", false, 10)]
    static void CreateButton11(MenuCommand menuCommand)
    {
        CreateTemplate("Button11.Prefab", menuCommand);
    }



    /// <summary>
    /// 创建标题1
    /// </summary>
    [MenuItem("GameObject/CustomCreate/Title01", false, 10)]
    static void CreateTitle01(MenuCommand menuCommand)
    {
        CreateTemplate("Title01.Prefab", menuCommand);
    }


    /// <summary>
    /// 创建标题2
    /// </summary>
    [MenuItem("GameObject/CustomCreate/Title02", false, 10)]
    static void CreateTitle02(MenuCommand menuCommand)
    {
        CreateTemplate("Title02.Prefab", menuCommand);
    }

    /// <summary>
    /// 创建圆角头像
    /// </summary>
    [MenuItem("GameObject/CustomCreate/CircleHead", false, 10)]
    static void CreateCircleHead(MenuCommand menuCommand)
    {
        CreateTemplate("CircleHead.Prefab", menuCommand);
    }



    /// <summary>
    /// 创建模版
    /// </summary>
    /// <param name="name"></param>
    static GameObject CreateTemplate(string name, MenuCommand menuCommand)
    {
        GameObject go = GameObject.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>(CustomPrefabMainPath + name));
        GameObjectUtility.SetParentAndAlign(go, menuCommand.context as GameObject);
        Undo.RegisterCreatedObjectUndo(go, "Create " + go.name);
        Transform parent = Selection.activeTransform;
        go.transform.SetParent(parent);
        go.transform.localScale = Vector3.one;
        go.transform.localPosition = Vector3.zero;
        go.name = go.name.Replace("(Clone)", "");
        Selection.activeObject = go;
        return go;
    }
}
