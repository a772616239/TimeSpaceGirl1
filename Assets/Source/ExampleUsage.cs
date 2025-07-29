using UnityEngine;
using LuaInterface;
using System.Collections;
using System.Collections.Generic;
using System;
using UnityEngine.UI;
using UnityEngine.SceneManagement;
// 示例：在另一个脚本中使用
public class ExampleUsage : MonoBehaviour
{
    public TextAsset luaScript; // 在Inspector中拖入.lua文件

    void Start()
    {
        LuaScriptRunner runner = gameObject.AddComponent<LuaScriptRunner>();
        runner.ExecuteLuaScript(luaScript);
        runner.CallLuaFunction("MyLuaFunction");

    }
}