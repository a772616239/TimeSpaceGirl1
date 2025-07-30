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
    public TextAsset textAsset;
    void Start()
    {
       App.LuaMgr.CallLuaFunctionByScript(textAsset.text, "Awake",gameObject);
    }
}