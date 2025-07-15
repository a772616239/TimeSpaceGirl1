
using UnityEngine;
using UnityEditor;

public static class LanguageText_Hierachy
{


    //注册到Assets目录下
    [MenuItem("GameObject/UI/LanguageText", false, 8)]
    public static void CreateLanguageText()
    {
        // GameObject.Instantiate()

        ////实际的项目中 资源可能放在别的路径，根据项目自行选择加载方式和路径
        //GameObject obj = Resources.Load<GameObject>("cube");
        //选中了几个就在这几个物体的子目录下创建相应的东西
        for (int i = 0; i < Selection.transforms.Length; i++)
        {
            GameObject newObj = new GameObject("Text");
            newObj.transform.SetParent(Selection.transforms[i]);
            newObj.AddComponent<LanguageText>();
        }
    }


    //[InitializeOnLoadMethod]
    //static void StartInitializeOnLoadMethod()
    //{
    //    EditorApplication.hierarchyWindowItemOnGUI += OnHierarchyGUI;//hierarchy面板绘制GUI的委托，可以自己添加gui委托
    //}

    //static void OnHierarchyGUI(int instanceID, Rect selectionRect)//Unity hierarchy绘制的时候传递的2个参数
    //{
    //    if (Event.current != null && Event.current.button == 1 && Event.current.type <= EventType.MouseUp) //右键，点击向上
    //    {
    //        Vector2 mousePosition = Event.current.mousePosition;
    //        EditorUtility.DisplayPopupMenu(new Rect(mousePosition.x, mousePosition.y, 0, 0), "Assets/", null);//在鼠标的位置弹出菜单，菜单的路径

    //    }
    //}

}