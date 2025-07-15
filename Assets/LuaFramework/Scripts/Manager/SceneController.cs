using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using LuaInterface;
using UnityEngine.SceneManagement;
using GameCore;
namespace GameLogic
{
    public class SceneController : Singleton<SceneController>
    {
        public void LoadScene(string name, LuaFunction func = null)
        {
            SceneManager.LoadScene(name);
            if (func != null) func.Call();
        }
    }
}
