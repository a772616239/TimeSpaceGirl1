using UnityEngine;
using LuaInterface;
using System.Collections;
using System.Collections.Generic;
using System;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using GameLogic;
// 示例：在另一个脚本中使用
public class ExcuteLuaBehaviour : MonoBehaviour
{
    public string SoundName;
    private static String LangLuaText;
    public bool IsOnceAudio;
    bool IsPlayFirst = false;

    void Awake()
    {
        if (LangLuaText==null)
        {
            LangLuaText=Resources.Load<TextAsset>("multilang").text;
        }
        //App.LuaMgr.CallLuaFunctionByScript(LangLuaText, "Awake",gameObject);
    }
    void OnEnable()
    {
        if (IsOnceAudio)
        {
            if (!IsPlayFirst)
            {
                IsPlayFirst = true;
                App.LuaMgr.CallLuaFunctionByScript(LangLuaText, "OnEnable", SoundName);
            }
            return;
        }
        App.LuaMgr.CallLuaFunctionByScript(LangLuaText, "OnEnable", SoundName);
    }
}