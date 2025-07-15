using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using GameLogic;
/// <summary>
/// 游戏帮助类
/// </summary>
public class GameHelper {

    public static void AddGameLuaSearchPath(string game)
    {
#if UNITY_EDITOR
        string path = string.Format(Application.dataPath + "/ManagedResources/{0}/~Lua", game);
        App.LuaMgr.AddSearchPath(path);
#endif
    }

    public static void RemoveGameLuaSearchPath(string game) {
#if UNITY_EDITOR
        string path = string.Format(Application.dataPath + "/ManagedResources/{0}/~Lua", game);
        App.LuaMgr.RemoveSearchPath(path);
#endif
    }
}
