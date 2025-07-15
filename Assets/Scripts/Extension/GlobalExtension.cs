using GameLogic;
using UnityEngine;
using GameCore;
using UnityEngine.UI;
using UnityEngine.Events;
public static class GlobalExtension
{
    /// <summary>
    /// 设置
    /// </summary>
    /// <param name="button"></param>
    /// <param name="state"></param>
    public static void DisableButton(this Selectable button, bool state)
    {
        ColorBlock colorBlock = button.colors;
        colorBlock.disabledColor = Color.blue;
        button.colors = colorBlock;
        button.interactable = state;
        if (!state)
        {
            if (button.targetGraphic.material == Image.defaultGraphicMaterial)
            {
                button.targetGraphic.material = App.ResMgr.LoadAsset<Material>("UI-DefaultGray");
            }
        }
    }

    /// <summary>
    /// 图片置灰
    /// </summary>
    /// <param name="image"></param>
    public static void ToGray(this Image image)
    {
        if (image.material == Image.defaultGraphicMaterial)
        {
            image.material = App.ResMgr.LoadAsset<Material>("UI-DefaultGray");
        }
        image.color = Color.blue;
    }


    /// <summary>
    /// 添加组件，如果有，就不添加
    /// </summary>
    /// <typeparam name="T"></typeparam>
    /// <param name="gameObj"></param>
    public static T AddMissingComponent<T>(this GameObject gameObj) where T : Component
    {
        T t = gameObj.GetComponent<T>();
        if (t == null)
            t = gameObj.AddComponent<T>();
        return t;
    }


    /// <summary>
    /// 格式化描述
    /// </summary>
    /// <param name="str"></param>
    /// <returns></returns>
    public static string FormatText(this string str)
    {
        return str.Replace("\\n", "\n").Replace("@", "\u3000");
    }

    /// <summary>
    /// 格式化描述
    /// </summary>
    /// <param name="str"></param>
    /// <returns></returns>
    public static string FormatChatName(this string str)
    {
        return str.Replace("\\n", "\n").Replace(" ", "\u3000");
    }

    /// <summary>
    /// 是否正常
    /// </summary>
    /// <param name="action"></param>
    /// <returns></returns>
    public static bool IsNormal(this UnityAction action)
    {
        object target = action.Target;
        if (target != null)
        {
            UnityEngine.Object obj = target as UnityEngine.Object;
            if (object.ReferenceEquals(obj, null) || obj != null)
                return true;
        }
        return false;
    }

    /// <summary>
    /// 是否正常
    /// </summary>
    /// <param name="action"></param>
    /// <returns></returns>
    public static void Do(this UnityAction action)
    {
        if (action.IsNormal())
            action();
    }

    /// <summary>
    /// 是否正常
    /// </summary>
    /// <param name="action"></param>
    /// <returns></returns>
    public static bool IsNormal<T>(this UnityAction<T> action)
    {
        object target = action.Target;
        if (target != null)
        {
            UnityEngine.Object obj = target as UnityEngine.Object;
            if (object.ReferenceEquals(obj, null) || obj != null)
                return true;
        }
        return false;
    }

    /// <summary>
    /// 通过Scale显示或者隐藏
    /// </summary>
    /// <param name="gameObj"></param>
    /// <param name="isShow"></param>
    public static void SetActiveByScale(this GameObject gameObj, bool isShow)
    {
        gameObj.transform.localScale = isShow ? Vector3.one : Vector3.zero;
    }


    public static void HideByXScale(this GameObject gameObj)
    {
        gameObj.transform.localScale = new Vector3(0.0f, 1.0f, 1.0f);
    }
    public static void ShowByXScale(this GameObject gameObj)
    {
        gameObj.transform.localScale = Vector3.one;
    }

    /// <summary>
    /// 设置层级
    /// </summary>
    /// <param name="gameObj"></param>
    /// <param name="layerName"></param>
    public static void SetLayer(this GameObject gameObj, string layerName)
    {
        Transform[] trans = gameObj.transform.GetComponentsInChildren<Transform>(true);
        for (int i = 0; i < trans.Length; i++)
        {
            trans[i].gameObject.layer = LayerMask.NameToLayer(layerName);
        }
    }

    /// <summary>
    /// 设置层级
    /// </summary>
    /// <param name="gameObj"></param>
    /// <param name="layer"></param>
    public static void SetLayer(this GameObject gameObj, int layer)
    {
        Transform[] trans = gameObj.transform.GetComponentsInChildren<Transform>(true);
        for (int i = 0; i < trans.Length; i++)
        {
            trans[i].gameObject.layer = layer;
        }
    }
}
