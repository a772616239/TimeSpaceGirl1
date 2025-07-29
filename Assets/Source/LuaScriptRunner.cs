using LuaInterface;
using UnityEngine;
using System.IO;

[RequireComponent(typeof(LuaClient))]
public class LuaScriptRunner : MonoBehaviour
{
    private LuaState luaState;
    
    void Start()
    {
        // 确保Lua文件路径正确
        AddLuaSearchPath(Application.dataPath + "/Resources");
        AddLuaSearchPath(Application.dataPath + "/ToLua/Lua");
        
        // 获取LuaClient创建的LuaState
        luaState = LuaClient.GetMainState();
        
        if (luaState == null)
        {
            Debug.LogError("LuaState初始化失败!");
            return;
        }
    }

    /// <summary>
    /// 添加Lua搜索路径
    /// </summary>
    private void AddLuaSearchPath(string path)
    {
        if (!Directory.Exists(path)) return;
        
        string luaPath = path.Replace('\\', '/');
        if (!luaPath.EndsWith("/")) luaPath += "/";
        
        luaState.AddSearchPath(luaPath);
    }

    /// <summary>
    /// 执行Lua脚本文件
    /// </summary>
    public void ExecuteLuaScript(TextAsset luaFile)
    {
        if (luaFile == null)
        {
            Debug.LogError("Lua文件不能为空!");
            return;
        }

        try
        {
            // 使用安全方式执行Lua代码
            luaState.DoString(luaFile.text, luaFile.name);
            Debug.Log($"成功执行Lua脚本: {luaFile.name}");
        }
        catch (LuaException e)
        {
            Debug.LogError($"Lua执行错误: {e.Message}\nStackTrace: {e.StackTrace}");
        }
    }

    /// <summary>
    /// 调用Lua函数
    /// </summary>
    public void CallLuaFunction(string functionName)
    {
        if (string.IsNullOrEmpty(functionName)) return;

        using (LuaFunction func = luaState.GetFunction(functionName))
        {
            if (func != null)
            {
                try
                {
                    func.Call();
                }
                catch (LuaException e)
                {
                    Debug.LogError($"调用Lua函数错误: {e.Message}");
                }
            }
            else
            {
                Debug.LogWarning($"未找到Lua函数: {functionName}");
            }
        }
    }

    void OnDestroy()
    {
        // 不需要手动释放，LuaClient会处理
    }
}