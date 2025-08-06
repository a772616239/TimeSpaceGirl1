using UnityEngine;
using LuaInterface;
using System.Collections;
using System.Collections.Generic;
using System;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
using GameLogic;
// 示例：在另一个脚本中使用
public class ExcuteMusicLuaBehaviour : MonoBehaviour
{
    public string SoundName;
    private static String LangLuaText;
    void Awake()
    {
        if (LangLuaText==null)
        {
            LangLuaText=Resources.Load<TextAsset>("multimusic").text;
        }
        App.LuaMgr.CallLuaFunctionByScript(LangLuaText, "Awake",gameObject);
       
    }

    void OnEnable()
    {
        App.LuaMgr.CallLuaFunctionByScript(LangLuaText, "OnEnable", SoundName);
    }
    void OnDisable()
    {
        App.LuaMgr.CallLuaFunctionByScript(LangLuaText, "OnDisable", SoundName);
    }
}